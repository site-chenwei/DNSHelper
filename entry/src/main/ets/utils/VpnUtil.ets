import vpnExtension from '@ohos.net.vpnExtension';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';
import socket from '@ohos.net.socket';
import fs from '@ohos.file.fs';
import { PacketUtil } from './PacketUtil';
import { DnsCacheManager } from './DnsCacheManager';

// 手动定义接口以解决 SDK 类型导出问题
interface NetAddress {
  address: string;
  family?: number;
  port?: number;
}

interface LinkAddress {
  address: NetAddress;
  prefixLength: number;
}

interface Route {
  interface: string;
  destination: NetAddress;
  prefixLength: number;
}

interface VpnConfig {
  addresses: LinkAddress[];
  routes?: Route[];
  dnsAddresses?: string[];
  mtu?: number;
  isAcceptIPv4?: boolean;
  isAcceptIPv6?: boolean;
  isLegacy?: boolean;
  isBlocking?: boolean;
}

interface VpnConnection {
  create(config: VpnConfig): Promise<number>;
  destroy(): Promise<void>;
  protect(socketFd: number): Promise<void>;
  on(type: 'stateChange', callback: (state: boolean) => void): void;
}

interface SessionInfo {
  srcIp: string;
  srcPort: number;
  dstIp: string;
  dstPort: number;
  cacheKey: string;
}

export class VpnUtil {
  private static vpnConnection: VpnConnection | null = null;
  private static fd: number = -1;
  private static isRunning: boolean = false;
  private static tunIp: string = "10.1.10.1";

  // 注意：此方法现在应在 VpnExtensionAbility 中调用，context 必须是 VpnExtensionContext
  public static async startVpn(context: common.Context, dnsList: string[]): Promise<void> {
    console.error('VpnUtil.startVpn called with DNS:', JSON.stringify(dnsList));
    
    try {
      if (VpnUtil.vpnConnection) {
        await VpnUtil.stopVpn(context);
      }

      // 使用类型断言适配，假设 context 已经是 VpnExtensionContext
      VpnUtil.vpnConnection = vpnExtension.createVpnConnection(context as Object as vpnExtension.VpnExtensionContext) as Object as VpnConnection;
      
      const netAddr: NetAddress = {
        address: VpnUtil.tunIp,
        family: 1 // 1 for IPv4
      };

      const linkAddress: LinkAddress = {
        address: netAddr,
        prefixLength: 24
      };

      const route: Route = {
        interface: "vpn0",
        destination: netAddr,
        prefixLength: 32
      };

      // 这里我们将系统 DNS 设置为 VPN 接口地址
      // 这样系统发出的 DNS 请求会被路由到 VPN 接口，我们才能在应用层截获
      const config: VpnConfig = {
        addresses: [linkAddress],
        mtu: 1400,
        dnsAddresses: [VpnUtil.tunIp], 
        isAcceptIPv4: true,
        isAcceptIPv6: false,
        routes: [route]
      };

      VpnUtil.fd = await VpnUtil.vpnConnection.create(config);
      console.info('VPN created successfully, fd:', VpnUtil.fd);
      
      VpnUtil.isRunning = true;
      // 启动转发循环
      VpnUtil.startDnsRelayLoop(dnsList);
      
    } catch (err) {
      const error = err as BusinessError;
      console.error(`Failed to start VPN. Code: ${error.code}, Message: ${error.message}`);
      VpnUtil.vpnConnection = null;
      throw new Error(`VPN Start Failed: ${error.message}`);
    }
  }

  public static async stopVpn(context: common.Context): Promise<void> {
    console.info('Stopping VPN...');
    VpnUtil.isRunning = false;
    
    if (VpnUtil.vpnConnection) {
      try {
        await VpnUtil.vpnConnection.destroy();
        console.info('VPN destroyed');
      } catch (err) {
        const error = err as BusinessError;
        console.error(`Failed to stop VPN. Code: ${error.code}, Message: ${error.message}`);
      }
      VpnUtil.vpnConnection = null;
      VpnUtil.fd = -1;
    }
  }

  private static async startDnsRelayLoop(upstreamDnsList: string[]) {
    console.info('Starting DNS Relay Loop...');
    const bufferSize = 4096;
    const buffer = new ArrayBuffer(bufferSize);

    // 创建用于转发的 UDP Socket
    const relaySocket = socket.constructUDPSocketInstance();
    // 保护 Socket 不走 VPN
    if (VpnUtil.vpnConnection) {
      try {
         // 注意：protect 需要 socket fd，但 ArkTS socket API 可能未直接暴露 fd
         // 如果无法 protect，此方案会死循环。
         // 目前假设系统默认路由不走 VPN（因为我们只配置了 10.1.10.1/32 的路由）
         // 只要 upstreamDnsList 不是 10.1.10.1，且没有 default route，就应该没事
      } catch (e) {
        console.error('Failed to protect socket:', e);
      }
    }
    
    relaySocket.bind({ address: '0.0.0.0', port: 0, family: 1 });

    // 监听响应
    // 简单的 Session Map: Key=TransactionID (DNS Header前2字节), Value={srcIp, srcPort, dstIp, dstPort, cacheKey}
    const sessionMap = new Map<number, SessionInfo>();

    relaySocket.on('message', (value) => {
       const respPayload = value.message;
       if (respPayload.byteLength < 2) return;
       const view = new DataView(respPayload);
       const transId = view.getUint16(0);
       
       const session = sessionMap.get(transId);
       if (session) {
         // 存入缓存
         if (session.cacheKey) {
            // 需要将响应包的 Transaction ID 归一化 (比如存为 0) 吗？
            // 不，缓存里应该存 Payload，取出来的时候改 ID。
            // 这里我们存原始 Payload，但在取出时必须替换 ID。
            DnsCacheManager.getInstance().put(session.cacheKey, respPayload);
         }

         // 构建响应包
         // Src: 10.1.10.1 (session.dstIp), Dst: Sys (session.srcIp)
         // SrcPort: 53 (session.dstPort), DstPort: SysPort (session.srcPort)
         const ipPacket = PacketUtil.buildIpv4UdpPacket(
           session.dstIp, 
           session.srcIp, 
           session.dstPort, 
           session.srcPort, 
           respPayload
         );
         
         // 写入 TUN
         if (VpnUtil.fd > 0 && VpnUtil.isRunning) {
           fs.write(VpnUtil.fd, ipPacket).catch((e: Error) => console.error('Write TUN failed:', e));
         }
         
         // 移除 session (简单的最快响应机制)
         sessionMap.delete(transId);
       }
    });

    while (VpnUtil.isRunning && VpnUtil.fd > 0) {
      try {
        const readLen = await fs.read(VpnUtil.fd, buffer);
        if (readLen > 0) {
          const packetData = buffer.slice(0, readLen);
          const ipv4 = PacketUtil.parseIpv4(packetData);
          
          if (ipv4 && ipv4.protocol === 17) { // UDP
             const udp = PacketUtil.parseUdp(ipv4.payload);
             if (udp && udp.dstPort === 53) {
               // 这是一个 DNS 请求
               const dnsPayload = udp.payload;
               if (dnsPayload.byteLength >= 12) {
                 const view = new DataView(dnsPayload);
                 const transId = view.getUint16(0);
                 
                 // 尝试解析 Question 以查询缓存
                 const question = PacketUtil.parseDnsQuestion(dnsPayload);
                 let cacheKey = '';
                 
                 if (question) {
                   cacheKey = DnsCacheManager.getInstance().getCacheKey(question.qname, question.qtype);
                   const cachedResponse = DnsCacheManager.getInstance().get(cacheKey);
                   
                   if (cachedResponse) {
                     console.info(`DNS Cache Hit: ${question.qname}`);
                     // 缓存命中！直接构造响应包
                     // 必须修改 Transaction ID 为当前请求的 ID
                     const newPayload = PacketUtil.updateDnsTransactionId(cachedResponse, transId);
                     
                     const ipPacket = PacketUtil.buildIpv4UdpPacket(
                       ipv4.dstIp, // Src IP (10.1.10.1)
                       ipv4.srcIp, // Dst IP (Sys)
                       udp.dstPort, // Src Port (53)
                       udp.srcPort, // Dst Port
                       newPayload
                     );
                     
                     if (VpnUtil.fd > 0) {
                        fs.write(VpnUtil.fd, ipPacket).catch((e: Error) => console.error('Write Cache TUN failed:', e));
                     }
                     continue; // 跳过转发
                   }
                 }

                 // 记录 Session
                 sessionMap.set(transId, {
                   srcIp: ipv4.srcIp,
                   srcPort: udp.srcPort,
                   dstIp: ipv4.dstIp,
                   dstPort: udp.dstPort,
                   cacheKey: cacheKey
                 });
                 
                 // 并发转发
                 upstreamDnsList.forEach(dnsIp => {
                   const sendOptions: socket.UDPSendOptions = {
                     address: { address: dnsIp, port: 53, family: 1 },
                     data: dnsPayload // 透传 Payload
                   };
                   relaySocket.send(sendOptions);
                 });
               }
             }
          }
        }
      } catch (e) {
        // console.debug('Read loop error or timeout:', e);
        // 避免死循环占用 CPU，稍作休眠
        await new Promise<void>(resolve => setTimeout(resolve, 10));
      }
    }
    
    relaySocket.close();
  }
}
