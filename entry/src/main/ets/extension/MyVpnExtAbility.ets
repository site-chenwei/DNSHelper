import { VpnExtensionAbility, vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { socket, http } from '@kit.NetworkKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';
import { PacketUtil } from '../utils/PacketUtil';
import wifiManager from '@ohos.wifiManager';
import connection from '@ohos.net.connection';
import commonEventManager from '@ohos.commonEventManager';

import { DnsType } from '../model/DnsInfo';
import { util } from '@kit.ArkTS';

const TAG = '[MyVpnExtAbility]';

export default class MyVpnExtAbility extends VpnExtensionAbility {
  private vpnConnection: vpnExtension.VpnConnection | undefined = undefined;
  private tunFd: number = -1;
  private isRunning: boolean = false;
  private currentDnsList: string[] = ['223.5.5.5', '223.6.6.6'];
  private currentDnsType: string = DnsType.UDP;
  private preferHttp3: boolean = false;
  private dnsRequestCount: number = 0;

  onCreate(want: Want) {
    console.info(TAG, 'onCreate');
    this.handleWant(want);
  }

  onRequest(want: Want, startId: number) {
    console.info(TAG, 'onRequest', want);
    // this.handleWant(want);
  }

  private handleWant(want: Want) {
    if (want.parameters) {
      if (want.parameters['dnsList']) {
        const dnsList = want.parameters['dnsList'] as string[];
        if (dnsList && dnsList.length > 0) {
          this.currentDnsList = dnsList;
        }
      }
      if (want.parameters['dnsType']) {
        this.currentDnsType = want.parameters['dnsType'] as string;
      }
      if (want.parameters['preferHttp3']) {
        this.preferHttp3 = want.parameters['preferHttp3'] as boolean;
      }
    }
    this.startVpn();
  }

  onDestroy() {
    console.info(TAG, 'onDestroy');
    this.stopVpn();
  }

  private async startVpn() {
    if (this.vpnConnection) {
      console.info(TAG, 'VPN 已启动');
      return;
    }

    try {
      this.vpnConnection = vpnExtension.createVpnConnection(this.context);
      console.info(TAG, 'VPN 连接已创建');
      const config: vpnExtension.VpnConfig = {
        addresses: [{
          address: { address: "10.1.10.1", family: 1 },
          prefixLength: 24
        }],
        dnsAddresses: ["10.1.10.2"], // 告诉系统：我有这些 DNS，请优先用我
        routes: [{
          interface: 'vpn-tun',
          destination: {
            address: { address: "10.1.10.2", family: 1 },
            prefixLength: 32
          },
          gateway: { address: '0.0.0.0' },
          hasGateway: false,
          isDefaultRoute: false
        }],
        blockedApplications: ["site.chenwei.dns"]
      };

      console.info(TAG, `创建 VPN 接口配置: ${JSON.stringify(config)}`);
      this.tunFd = await this.vpnConnection.create(config);
      console.info(TAG, `VPN 接口已创建, fd: ${this.tunFd}`);

      if (this.tunFd > 0) {
        this.isRunning = true;
        this.startPacketLoop();
      }

    } catch (err) {
      const error = err as BusinessError;
      console.error(TAG, `启动 VPN 失败: ${error.code} - ${error.message}`);
      this.destroyVpn();
    }
  }

  private async stopVpn() {
    this.isRunning = false;
    this.destroyVpn();
  }

  private async destroyVpn() {
    if (this.vpnConnection) {
      try {
        await this.vpnConnection.destroy();
        console.info(TAG, 'VpnConnection destroyed');
      } catch (err) {
        console.error(TAG, 'Error destroying VpnConnection: ' + JSON.stringify(err));
      }
      this.vpnConnection = undefined;
    }
    if (this.tunFd > 0) {
      try {
        fs.closeSync(this.tunFd);
      } catch (e) {
        // ignore
      }
      this.tunFd = -1;
    }
  }

  private async startPacketLoop() {
    console.info(TAG, 'Starting packet loop');

    // Prepare Relay Socket (UDP IPv4)
    const relaySocket = socket.constructUDPSocketInstance();
    const bindIp = await this.getPhysicalIp();
    console.info(TAG, `Binding relay socket to ${bindIp}`);

    try {
      await relaySocket.bind({ address: bindIp, port: 0, family: 1 });
    } catch (e) {
      console.error(TAG, 'Failed to bind relay socket: ' + JSON.stringify(e));
      try {
        await relaySocket.bind({ address: '0.0.0.0', port: 0, family: 1 });
      } catch (e2) {
      }
    }

    // Prepare Relay Socket (UDP IPv6) - REMOVED


    const sessionMap = new Map<number, SessionInfo>();

    const handleResponse = (value: socket.SocketMessageInfo) => {
      this.processDnsResponse(value.message, sessionMap);
    };

    relaySocket.on('message', handleResponse);

    const buffer = new ArrayBuffer(4096);
    let errorCount = 0;

    while (this.isRunning && this.tunFd > 0) {
      try {
        const readLen = await fs.read(this.tunFd, buffer);
        if (readLen > 0) {
          errorCount = 0; // Reset error count on success
          const packetData = buffer.slice(0, readLen);

          const ipv4 = PacketUtil.parseIpv4(packetData);
          if (ipv4 && ipv4.protocol === 17) { // UDP
            const udp = PacketUtil.parseUdp(ipv4.payload);
            if (udp && udp.dstPort === 53) {
              this.handleDnsQuery(udp.payload, ipv4.srcIp, ipv4.dstIp, udp.srcPort, udp.dstPort, sessionMap,
                relaySocket);
            }
          }
        }
      } catch (e) {
        // 自适应退避策略：避免日志刷屏
        errorCount++;
        const delay = Math.min(200, 20 * errorCount);
        await new Promise<void>(resolve => setTimeout(resolve, delay));
      }
    }
  }

  private handleDnsQuery(dnsPayload: ArrayBuffer, srcIp: string, dstIp: string, srcPort: number, dstPort: number,
    sessionMap: Map<number, SessionInfo>, socketV4: socket.UDPSocket) {
    const view = new DataView(dnsPayload);
    const transId = view.getUint16(0);

    // 统计 DNS 请求
    this.dnsRequestCount++;
    this.publishDnsCount();

    sessionMap.set(transId, {
      srcIp,
      srcPort,
      dstIp,
      dstPort
    });

    this.currentDnsList.forEach(dnsTarget => {
      // Prioritize explicit type, but keep backward compatibility for URL detection
      if (this.currentDnsType === DnsType.DOH || dnsTarget.startsWith('http://') || dnsTarget.startsWith('https://')) {
        this.sendDohQuery(dnsTarget, dnsPayload, sessionMap);
      } else if (this.currentDnsType === DnsType.DOT) {
        this.sendDotQuery(dnsTarget, dnsPayload, sessionMap);
      } else if (this.currentDnsType === DnsType.DOQ) {
        this.sendDoqQuery(dnsTarget, dnsPayload, sessionMap);
      } else {
        // UDP
        if (!dnsTarget.includes(':')) {
          socketV4.send({
            address: { address: dnsTarget, port: 53, family: 1 },
            data: dnsPayload
          }).catch((err: BusinessError) => {
            // console.error(TAG, `Forward DNS failed: ${JSON.stringify(err)}`);
          });
        }
      }
    });
  }

  private async sendDotQuery(dnsTarget: string, dnsPayload: ArrayBuffer, sessionMap: Map<number, SessionInfo>) {
    let tlsSocket: socket.TLSSocket | undefined;
    try {
      tlsSocket = socket.constructTLSSocketInstance();
      const len = dnsPayload.byteLength;
      const tcpPayload = new Uint8Array(2 + len);
      const view = new DataView(tcpPayload.buffer);
      view.setUint16(0, len, false);
      tcpPayload.set(new Uint8Array(dnsPayload), 2);

      const connectOptions: socket.TLSConnectOptions = {
        address: {
          address: dnsTarget,
          port: 853,
          family: 1
        },
        secureOptions: {
          // verifyRemote: false // Skip verification for simplicity/compatibility
        }
      };

      tlsSocket.on('message', (value) => {
        // Simple handling: assume full response in one packet
        if (value.message.byteLength > 2) {
           const respPayload = value.message.slice(2);
           this.processDnsResponse(respPayload, sessionMap);
        }
        tlsSocket?.close();
      });
      
      tlsSocket.on('error', (err) => {
        console.error(TAG, `DOT Socket error: ${JSON.stringify(err)}`);
        tlsSocket?.close();
      });

      await tlsSocket.connect(connectOptions);
      await tlsSocket.send(tcpPayload.buffer);
    } catch (e) {
      console.error(TAG, `DOT failed: ${JSON.stringify(e)}`);
      if (tlsSocket) {
          tlsSocket.close();
      }
    }
  }

  private async sendDoqQuery(dnsTarget: string, dnsPayload: ArrayBuffer, sessionMap: Map<number, SessionInfo>) {
     console.error(TAG, 'DOQ not supported yet');
  }

  private async sendDohQuery(dohUrl: string, dnsPayload: ArrayBuffer, sessionMap: Map<number, SessionInfo>) {
    try {
      // 如果启用 HTTP/3 优先，使用 rcp
      if (this.preferHttp3) {
        const session = rcp.createSession();
        const request = new rcp.Request(dohUrl, 'POST');
        request.content = dnsPayload;
        request.headers = {
          'content-type': 'application/dns-message',
          'accept': 'application/dns-message'
        };
        
        // rcp 会根据服务端支持情况自动协商 HTTP/3 (QUIC)
        const response = await session.fetch(request);

        if (response.statusCode === 200 && response.body) {
           let resultBuffer: ArrayBuffer;
           if (typeof response.body === 'string') {
                console.warn(TAG, 'DoH response is string, unexpected');
                return;
           } else {
                resultBuffer = response.body as ArrayBuffer;
           }
           this.processDnsResponse(resultBuffer, sessionMap);
        } else {
           console.error(TAG, `DoH (rcp) failed: ${response.statusCode}`);
        }
        session.close();
        return;
      }

      // 否则使用默认 http 模块 (HTTP/1.1 or HTTP/2)
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(dohUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/dns-message',
          'Accept': 'application/dns-message'
        },
        extraData: dnsPayload,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });

      if (response.responseCode === 200 && response.result instanceof ArrayBuffer) {
        this.processDnsResponse(response.result as ArrayBuffer, sessionMap);
      }
      httpRequest.destroy();
    } catch (err) {
      console.error(TAG, `DoH 查询失败: ${JSON.stringify(err)}`);
    }
  }

  private processDnsResponse(respPayload: ArrayBuffer, sessionMap: Map<number, SessionInfo>) {
    if (respPayload.byteLength < 2) {
      return;
    }
    const view = new DataView(respPayload);
    const transId = view.getUint16(0);

    const session = sessionMap.get(transId);
    if (session) {
      console.info(TAG, `处理响应 transId: ${transId}`);

      const ipPacket = PacketUtil.buildIpv4UdpPacket(
        session.dstIp, session.srcIp, session.dstPort, session.srcPort, respPayload
      );

      if (this.tunFd > 0 && this.isRunning) {
        fs.write(this.tunFd, ipPacket).catch((e: BusinessError) => {
          if (String(e.code) !== '13900010') {
            console.error(TAG, '写入 TUN 失败: ' + JSON.stringify(e));
          }
        });
      }
      sessionMap.delete(transId);
    }
  }

  private publishDnsCount() {
    // 简单的限流，防止频繁发送事件，实际生产中可以按时间或数量聚合
    // 但为了演示实时性，这里每次都发
    const options: commonEventManager.CommonEventPublishData = {
      parameters: {
        'count': this.dnsRequestCount
      }
    };
    commonEventManager.publish('site.chenwei.dns.event.DNS_COUNT_UPDATE', options, (err) => {
      if (err) {
        // console.error(TAG, 'Publish DNS count failed');
      }
    });
  }

  // Helper to get Physical IP for binding
  private async getPhysicalIp(): Promise<string> {
    try {
      if (wifiManager.isWifiActive()) {
        const info = await wifiManager.getLinkedInfo();
        return this.int2Ip(info.ipAddress);
      }
    } catch (e) {
    }
    try {
      const net = await connection.getDefaultNet();
      const props = await connection.getConnectionProperties(net);
      for (const addr of props.linkAddresses) {
        if (addr.address.family === 1 && !addr.address.address.startsWith('10.1.10') &&
          !addr.address.address.startsWith('127.')) {
          return addr.address.address;
        }
      }
    } catch (e) {
    }
    return '0.0.0.0';
  }

  private int2Ip(intIp: number): string {
    const buffer = new ArrayBuffer(4);
    const view = new DataView(buffer);
    view.setInt32(0, intIp, true);
    const bytes = new Uint8Array(buffer);
    const ip = [bytes[0], bytes[1], bytes[2], bytes[3]].join('.');
    // Heuristic fix for endianness
    if (ip.startsWith("185.97.") || (!ip.startsWith("192.") && !ip.startsWith("10.") && !ip.startsWith("172."))) {
      return [bytes[3], bytes[2], bytes[1], bytes[0]].join('.');
    }
    return ip;
  }
}

interface SessionInfo {
  srcIp: string;
  srcPort: number;
  dstIp: string;
  dstPort: number;
}
