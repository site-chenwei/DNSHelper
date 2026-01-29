import { VpnExtensionAbility, vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import { socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';
import { PacketUtil } from '../utils/PacketUtil';
import { DnsCacheManager } from '../utils/DnsCacheManager';
import wifiManager from '@ohos.wifiManager';
import connection from '@ohos.net.connection';

const TAG = '[MyVpnExtAbility]';

export default class MyVpnExtAbility extends VpnExtensionAbility {
  private vpnConnection: vpnExtension.VpnConnection | undefined = undefined;
  private tunFd: number = -1;
  private isRunning: boolean = false;
  private currentDnsList: string[] = ['223.5.5.5', '223.6.6.6'];

  onCreate(want: Want) {
    console.info(TAG, 'onCreate');
    this.handleWant(want);
  }

  onRequest(want: Want, startId: number) {
    console.info(TAG, 'onRequest', want);
    // this.handleWant(want);
  }

  private handleWant(want: Want) {
    if (want.parameters && want.parameters['dnsList']) {
      const dnsList = want.parameters['dnsList'] as string[];
      if (dnsList && dnsList.length > 0) {
        this.currentDnsList = dnsList;
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
      // 在 Extension 中也需要初始化缓存管理器
      await DnsCacheManager.getInstance().init(this.context);
      this.vpnConnection = vpnExtension.createVpnConnection(this.context);
      console.info(TAG, 'VPN 连接已创建');
      const config: vpnExtension.VpnConfig = {
        addresses: [{
          address: { address: "10.1.10.1", family: 1 },
          prefixLength: 32
        }, {
          address: { address: "fd00::1", family: 2 },
          prefixLength: 128
        }],
        mtu: 1400,
        dnsAddresses: ["10.1.10.2", "fd00::2"], // 告诉系统：我有这些 DNS，请优先用我
        routes: [{
          interface: 'vpn-tun',
          destination: {
            address: {
              address: "10.1.10.2",
              family: 1,
              port: 53
            },
            prefixLength: 32
          },
          gateway: {
            address: '0.0.0.0',
            family: 1,
            port: 0
          },
          hasGateway: false,
          isDefaultRoute: false
        }, {
          interface: 'vpn-tun',
          destination: {
            address: {
              address: "fd00::2",
              family: 2,
              port: 53
            },
            prefixLength: 128
          },
          gateway: {
            address: '::',
            family: 2,
            port: 0
          },
          hasGateway: false,
          isDefaultRoute: false
        }],
        blockedApplications: ["site.chenwei.dns"]
      };

      console.info(TAG, `Creating VPN interface with config: ${JSON.stringify(config)}`);
      this.tunFd = await this.vpnConnection.create(config);
      console.info(TAG, `VPN interface created, fd: ${this.tunFd}`);

      if (this.tunFd > 0) {
        this.isRunning = true;
        this.startPacketLoop();
      }

    } catch (err) {
      const error = err as BusinessError;
      console.error(TAG, `Failed to start VPN: ${error.code} - ${error.message}`);
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

    // Prepare Relay Socket (UDP IPv6)
    const relaySocketV6 = socket.constructUDPSocketInstance();
    try {
      await relaySocketV6.bind({ address: '::', port: 0, family: 2 });
    } catch (e) {
      console.error(TAG, 'Failed to bind IPv6 relay socket: ' + JSON.stringify(e));
    }

    const sessionMap = new Map<number, SessionInfo>();

    const handleResponse = (value: socket.SocketMessageInfo) => {
      const respPayload = value.message;
      if (respPayload.byteLength < 2) {
        return;
      }
      const view = new DataView(respPayload);
      const transId = view.getUint16(0);

      const session = sessionMap.get(transId);
      if (session) {
        if (session.cacheKey) {
          DnsCacheManager.getInstance().put(session.cacheKey, respPayload);
        }

        console.info(TAG, `Processing response for transId: ${transId}, isIpv6: ${session.isIpv6}`);

        let ipPacket: ArrayBuffer;
        if (session.isIpv6) {
          ipPacket = PacketUtil.buildIpv6UdpPacket(
            session.dstIp, session.srcIp, session.dstPort, session.srcPort, respPayload
          );
        } else {
          ipPacket = PacketUtil.buildIpv4UdpPacket(
            session.dstIp, session.srcIp, session.dstPort, session.srcPort, respPayload
          );
        }

        if (this.tunFd > 0 && this.isRunning) {
          fs.write(this.tunFd, ipPacket).catch((e: BusinessError) => {
            if (String(e.code) !== '13900010') {
              console.error(TAG, 'Write TUN failed: ' + JSON.stringify(e));
            }
          });
        }
        sessionMap.delete(transId);
      }
    };

    relaySocket.on('message', handleResponse);
    relaySocketV6.on('message', handleResponse);

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
              this.handleDnsQuery(udp.payload, ipv4.srcIp, ipv4.dstIp, udp.srcPort, udp.dstPort, false, sessionMap,
                relaySocket, relaySocketV6);
            }
          } else {
            const ipv6 = PacketUtil.parseIpv6(packetData);
            if (ipv6 && ipv6.nextHeader === 17) { // UDP
              const udp = PacketUtil.parseUdp(ipv6.payload);
              if (udp && udp.dstPort === 53) {
                this.handleDnsQuery(udp.payload, ipv6.srcIp, ipv6.dstIp, udp.srcPort, udp.dstPort, true, sessionMap,
                  relaySocket, relaySocketV6);
              }
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
    isIpv6: boolean, sessionMap: Map<number, SessionInfo>, socketV4: socket.UDPSocket, socketV6: socket.UDPSocket) {
    const view = new DataView(dnsPayload);
    const transId = view.getUint16(0);
    const question = PacketUtil.parseDnsQuestion(dnsPayload);
    let cacheKey = '';

    if (question) {
      cacheKey = DnsCacheManager.getInstance().getCacheKey(question.qname, question.qtype);
      const cached = DnsCacheManager.getInstance().get(cacheKey);
      if (cached) {
        console.info(TAG, 'DNS Cache Hit');
        const newPayload = PacketUtil.updateDnsTransactionId(cached, transId);
        let ipPacket: ArrayBuffer;
        if (isIpv6) {
          ipPacket = PacketUtil.buildIpv6UdpPacket(dstIp, srcIp, dstPort, srcPort, newPayload);
        } else {
          ipPacket = PacketUtil.buildIpv4UdpPacket(dstIp, srcIp, dstPort, srcPort, newPayload);
        }
        fs.write(this.tunFd, ipPacket).catch(() => {
        });
        return;
      }
    }

    sessionMap.set(transId, {
      srcIp,
      srcPort,
      dstIp,
      dstPort,
      cacheKey,
      isIpv6
    });

    this.currentDnsList.forEach(dnsIp => {
      const isDnsIpv6 = dnsIp.includes(':');
      const targetSocket = isDnsIpv6 ? socketV6 : socketV4;
      const family = isDnsIpv6 ? 2 : 1;

      targetSocket.send({
        address: { address: dnsIp, port: 53, family: family },
        data: dnsPayload
      }).catch((err: BusinessError) => {
        // console.error(TAG, `Forward DNS failed: ${JSON.stringify(err)}`);
      });
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
  cacheKey: string;
  isIpv6: boolean;
}
