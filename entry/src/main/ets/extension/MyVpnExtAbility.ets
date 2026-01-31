import { VpnExtensionAbility, vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { socket } from '@kit.NetworkKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';
import { PacketUtil } from '../utils/PacketUtil';
import wifiManager from '@ohos.wifiManager';
import connection from '@ohos.net.connection';
import commonEventManager from '@ohos.commonEventManager';

import { DnsType, DnsTargetConfig } from '../model/DnsInfo';
import { util } from '@kit.ArkTS';

const TAG = '[MyVpnExtAbility]';

export default class MyVpnExtAbility extends VpnExtensionAbility {
  private vpnConnection: vpnExtension.VpnConnection | undefined = undefined;
  private tunFd: number = -1;
  private isRunning: boolean = false;
  private dnsTargets: DnsTargetConfig[] = [];
  private backupDnsList: string[] = [];
  private dnsRequestCount: number = 0;
  private rcpSession: rcp.Session | undefined = undefined;
  private lastPublishTime: number = 0;
  private publishTimer: number = -1;

  onCreate(want: Want) {
    console.info(TAG, 'onCreate');
    this.handleWant(want);
  }

  private handleWant(want: Want) {
    if (want.parameters) {
      if (want.parameters['dnsConfigList']) {
        try {
          const jsonStr = want.parameters['dnsConfigList'] as string;
          this.dnsTargets = JSON.parse(jsonStr) as DnsTargetConfig[];
        } catch (e) {
          console.error(TAG, 'Failed to parse dnsConfigList: ' + JSON.stringify(e));
        }
      }

      if (want.parameters['backupDnsList']) {
        this.backupDnsList = want.parameters['backupDnsList'] as string[];
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
        dnsAddresses: ["10.1.10.2"],
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
        // 初始化 RCP Session
        if (!this.rcpSession) {
          this.rcpSession = rcp.createSession();
        }
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
    if (this.publishTimer !== -1) {
      clearTimeout(this.publishTimer);
      this.publishTimer = -1;
    }
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

    this.dnsTargets.forEach(target => {
      // Prioritize explicit type, but keep backward compatibility for URL detection
      if (target.type === DnsType.DOH) {
        this.sendDohQuery(target.address, dnsPayload, sessionMap);
      } else if (target.type === DnsType.DOT) {
        this.sendDotQuery(target.address, dnsPayload, sessionMap);
      } else {
        // UDP
        this.sendUdpQuery(target.address, dnsPayload, socketV4);
      }
    });

    // 故障转移逻辑：2秒后如果未收到响应，则使用备用服务器
    if (this.backupDnsList.length > 0) {
      setTimeout(() => {
        if (sessionMap.has(transId)) {
          this.backupDnsList.forEach(backupTarget => {
            this.sendUdpQuery(backupTarget, dnsPayload, socketV4);
          });
        }
      }, 2000);
    }
  }

  private sendUdpQuery(dnsTarget: string, dnsPayload: ArrayBuffer, socketV4: socket.UDPSocket) {
    if (!dnsTarget.includes(':')) {
      socketV4.send({
        address: { address: dnsTarget, port: 53, family: 1 },
        data: dnsPayload
      }).catch((err: BusinessError) => {
      });
    }
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

  private async sendDohQuery(dohUrl: string, dnsPayload: ArrayBuffer, sessionMap: Map<number, SessionInfo>) {
    try {
      if (!this.rcpSession) {
        // 创建 Session 配置
        const sessionConfig: rcp.SessionConfiguration = {
          requestConfiguration: {
            security: {
              remoteValidation: 'skip' // 忽略证书验证（可选，视需求而定）
            }
          }
        };

        // 如果明确优先使用 HTTP/3，我们可以在这里尝试设置相关参数
        // 目前 rcp 主要依靠自动协商 (Alt-Svc)，但我们可以确保 connection pool 复用
        this.rcpSession = rcp.createSession(sessionConfig);
      }

      const request = new rcp.Request(dohUrl, 'POST');
      request.content = dnsPayload;
      request.headers = {
        'content-type': 'application/dns-message',
        'accept': 'application/dns-message'
      };

      // rcp 会根据服务端支持情况自动协商 HTTP/3 (QUIC) 或降级使用 HTTP/2 / HTTP/1.1
      const response = await this.rcpSession.fetch(request);

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
    const now = Date.now();
    const THROTTLE_INTERVAL = 500; // 500ms 限流

    if (now - this.lastPublishTime >= THROTTLE_INTERVAL) {
      this.doPublishDnsCount();
      this.lastPublishTime = now;
      if (this.publishTimer !== -1) {
        clearTimeout(this.publishTimer);
        this.publishTimer = -1;
      }
    } else {
      if (this.publishTimer === -1) {
        this.publishTimer = setTimeout(() => {
          this.doPublishDnsCount();
          this.lastPublishTime = Date.now();
          this.publishTimer = -1;
        }, THROTTLE_INTERVAL - (now - this.lastPublishTime));
      }
    }
  }

  private doPublishDnsCount() {
    const options: commonEventManager.CommonEventPublishData = {
      parameters: {
        'count': this.dnsRequestCount
      }
    };
    commonEventManager.publish('site.chenwei.dns.event.DNS_COUNT_UPDATE', options, (err) => {
      if (err) {
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
