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
      console.info(TAG, 'VPN already started');
      return;
    }

    try {
      this.vpnConnection = vpnExtension.createVpnConnection(this.context);
      console.info(TAG, 'VpnConnection created');

      // 1. 获取当前物理网络的 DNS 服务器 IP 列表
      let targetDnsList: string[] = [];
      
      // 策略A: 自动探测物理网络 DNS (拦截运营商 DNS)
      try {
        const net = await connection.getDefaultNet();
        const props = await connection.getConnectionProperties(net);
        if (props.dnses && props.dnses.length > 0) {
           for (const dns of props.dnses) {
             if (dns.address && dns.family === 1) { // IPv4
               targetDnsList.push(dns.address);
               console.info(TAG, `Detected physical network DNS: ${dns.address}`);
             }
           }
        }
      } catch (e) {
        console.warn(TAG, `Failed to get physical network DNS: ${JSON.stringify(e)}`);
      }
      
      // 策略B: 补充常见公共 DNS (防止系统 fallback 到备用公共 DNS)
      // 精简列表，避免触发 -105 (路由条目过多或冲突)
      const commonPublicDns = [
        "114.114.114.114", // 114
        "8.8.8.8",         // Google
        "223.5.5.5"        // Ali
      ];
      
      // 合并去重
      targetDnsList = Array.from(new Set([...targetDnsList, ...commonPublicDns]));
      
      // 限制路由条目总数，防止 -105 错误
      if (targetDnsList.length > 5) {
          console.warn(TAG, `Too many DNS routes (${targetDnsList.length}), truncating to 5`);
          targetDnsList = targetDnsList.slice(0, 5);
      }
      
      console.info(TAG, `Final VPN DNS List: ${JSON.stringify(targetDnsList)}`);
      
      // 如果探测失败且列表为空（极少见），至少保留一个兜底
      if (targetDnsList.length === 0) {
          targetDnsList.push("114.114.114.114");
      }

      const vpnIp = "10.1.10.1";
      // 将 VPN 声明的 DNS 地址设置为探测到的第一个 DNS，或者 114
      // 这主要用于告知系统 VPN 的首选 DNS
      const primaryDnsIp = targetDnsList[0]; 

      // 生成路由表：为每一个目标 DNS 生成一条 /32 路由
      const routes: vpnExtension.RouteInfo[] = [];
      for (const ip of targetDnsList) {
        const route: vpnExtension.RouteInfo = {
           interface: 'vpn-tun',
           destination: {
             address: {
               address: ip,
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
        };
        routes.push(route);
      }

      // Configure VPN
      const config: vpnExtension.VpnConfig = {
        addresses: [{
          address: { address: vpnIp, family: 1 },
          prefixLength: 32
        }],
        mtu: 1400,
        dnsAddresses: targetDnsList, // 告诉系统：我有这些 DNS，请优先用我
        routes: routes,
        blockedApplications: ["site.chenwei.dns"]
      };

      console.info(TAG, `Creating VPN interface with config: ${JSON.stringify(config)}`);
      this.tunFd = await this.vpnConnection.create(config);
      console.info(TAG, `VPN interface created, fd: ${this.tunFd}`);

      if (this.tunFd > 0) {
        this.isRunning = true;
        // 启动数据包处理循环（对应官方示例中的 vpn_client.startVpn 逻辑）
        // 官方示例使用 C++ 实现 (vpn_client.startVpn)，这里我们使用 ArkTS 实现
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

    // Prepare Relay Socket (UDP)
    const relaySocket = socket.constructUDPSocketInstance();
    const bindIp = await this.getPhysicalIp();
    console.info(TAG, `Binding relay socket to ${bindIp}`);

    try {
      await relaySocket.bind({ address: bindIp, port: 0, family: 1 });
      // Try protect if available (requires socket fd, which is not exposed in ArkTS socket object easily, relying on bind IP)
      // If vpnConnection.protect(fd) was possible with ArkTS socket, we would do it here.
    } catch (e) {
      console.error(TAG, 'Failed to bind relay socket: ' + JSON.stringify(e));
      // Fallback
      try {
        await relaySocket.bind({ address: '0.0.0.0', port: 0, family: 1 });
      } catch (e2) {
      }
    }

    const sessionMap = new Map<number, SessionInfo>();

    relaySocket.on('message', (value) => {
        // Handle DNS Response from Upstream
        const respPayload = value.message;
        console.info(TAG, `Received DNS response from upstream, len: ${respPayload.byteLength}`);
        if (respPayload.byteLength < 2) return;
        const view = new DataView(respPayload);
        const transId = view.getUint16(0);

      const session = sessionMap.get(transId);
      if (session) {
        // Cache
        if (session.cacheKey) {
          DnsCacheManager.getInstance().put(session.cacheKey, respPayload);
        }

        console.info(TAG, `Processing response for transId: ${transId}, srcIp: ${session.srcIp}, dstIp: ${session.dstIp}`);

        // Build IP Packet back to TUN
        const ipPacket = PacketUtil.buildIpv4UdpPacket(
          session.dstIp, // Src IP (10.1.10.2) - DNS Server IP
          session.srcIp, // Dst IP (10.1.10.1) - Client IP
          session.dstPort, // Src Port (53)
          session.srcPort, // Dst Port (Client Port)
          respPayload
        );

        if (this.tunFd > 0 && this.isRunning) {
          fs.write(this.tunFd, ipPacket).then((writeLen) => {
               console.info(TAG, `Wrote DNS response to TUN, len: ${writeLen}`);
          }).catch((e: BusinessError) => {
            if (String(e.code) !== '13900010') { // Ignore EIO
              console.error(TAG, 'Write TUN failed: ' + JSON.stringify(e));
            }
          });
        }
        sessionMap.delete(transId);
      } else {
         console.warn(TAG, `No session found for transId: ${transId}`);
      }
    });

    const buffer = new ArrayBuffer(4096);
    let errorCount = 0;

    while (this.isRunning && this.tunFd > 0) {
      try {
        const readLen = await fs.read(this.tunFd, buffer);
        if (readLen > 0) {
          errorCount = 0; // Reset error count on success
          const packetData = buffer.slice(0, readLen);

          // 调试日志：确认有包进入
          // console.info(TAG, `Read packet len: ${readLen}`);

          const ipv4 = PacketUtil.parseIpv4(packetData);
          if (ipv4 && ipv4.protocol === 17) { // UDP
            const udp = PacketUtil.parseUdp(ipv4.payload);
            if (udp && udp.dstPort === 53) {
              console.info(TAG, 'Captured DNS Request');
              // It's a DNS Request
              const dnsPayload = udp.payload;
              const view = new DataView(dnsPayload);
              const transId = view.getUint16(0);

              // Parse Question for Cache
                    const question = PacketUtil.parseDnsQuestion(dnsPayload);
                    let cacheKey = '';
                    if (question) {
                        cacheKey = DnsCacheManager.getInstance().getCacheKey(question.qname, question.qtype);
                        /* 暂时禁用缓存，排查 -105 问题
                        const cached = DnsCacheManager.getInstance().get(cacheKey);
                        if (cached) {
                            console.info(TAG, 'DNS Cache Hit');
                            // Cache Hit
                            const newPayload = PacketUtil.updateDnsTransactionId(cached, transId);
                            const ipPacket = PacketUtil.buildIpv4UdpPacket(
                                ipv4.dstIp, // Src IP (10.1.10.2)
                                ipv4.srcIp, // Dst IP (10.1.10.1)
                                udp.dstPort, // 53
                                udp.srcPort,
                                newPayload
                            );
                            fs.write(this.tunFd, ipPacket).catch(() => {});
                            continue;
                        }
                        */
                    }

              // Store Session
              sessionMap.set(transId, {
                srcIp: ipv4.srcIp,
                srcPort: udp.srcPort,
                dstIp: ipv4.dstIp,
                dstPort: udp.dstPort,
                cacheKey: cacheKey
              });

              // Forward to Upstream
                    this.currentDnsList.forEach(dnsIp => {
                        console.info(TAG, `Forwarding DNS query to ${dnsIp}`);
                        relaySocket.send({
                            address: { address: dnsIp, port: 53, family: 1 },
                            data: dnsPayload
                        }).catch((err: BusinessError) => {
                             console.error(TAG, `Forward DNS failed: ${JSON.stringify(err)}`);
                        });
                    });
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
}
