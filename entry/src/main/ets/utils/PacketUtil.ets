import { util } from '@kit.ArkTS';

export interface DnsQuestion {
  qname: string;
  qtype: number;
  qclass: number;
}

export class PacketUtil {
  // 解析 DNS Question (仅支持单 Question)
  static parseDnsQuestion(payload: ArrayBuffer): DnsQuestion | null {
    if (payload.byteLength < 12) return null;
    const view = new DataView(payload);
    
    // DNS Header is 12 bytes
    const qdCount = view.getUint16(4);
    if (qdCount === 0) return null;

    let offset = 12;
    const parts: string[] = [];
    
    // Parse QNAME
    while (offset < payload.byteLength) {
      const length = view.getUint8(offset);
      offset++;
      
      if (length === 0) break; // End of name
      
      if ((length & 0xC0) === 0xC0) {
        // Compression pointer (not supported in simple parser for Question, 
        // usually Question doesn't use compression in request)
        return null;
      }
      
      if (offset + length > payload.byteLength) return null;
      
      // Read label
      const labelBytes = new Uint8Array(payload.slice(offset, offset + length));
      let label = "";
      for(let i=0; i<labelBytes.length; i++) {
        label += String.fromCharCode(labelBytes[i]);
      }
      parts.push(label);
      offset += length;
    }
    
    if (offset + 4 > payload.byteLength) return null;
    
    const qtype = view.getUint16(offset);
    const qclass = view.getUint16(offset + 2);
    
    return {
      qname: parts.join('.'),
      qtype,
      qclass
    };
  }

  // 修改 DNS Transaction ID
  static updateDnsTransactionId(payload: ArrayBuffer, newId: number): ArrayBuffer {
    if (payload.byteLength < 2) return payload;
    const newBuffer = payload.slice(0); // Clone
    const view = new DataView(newBuffer);
    view.setUint16(0, newId);
    return newBuffer;
  }

  // 解析 IPv4 头部
  static parseIpv4(buffer: ArrayBuffer): Ipv4Packet | null {
    const view = new DataView(buffer);
    const versionAndIhl = view.getUint8(0);
    const version = versionAndIhl >> 4;
    const ihl = versionAndIhl & 0x0F;
    const headerLength = ihl * 4;

    if (version !== 4) return null;

    const totalLength = view.getUint16(2);
    const protocol = view.getUint8(9);
    const srcIp = PacketUtil.intToIp(view.getUint32(12));
    const dstIp = PacketUtil.intToIp(view.getUint32(16));

    return {
      version,
      headerLength,
      totalLength,
      protocol,
      srcIp,
      dstIp,
      payload: buffer.slice(headerLength, totalLength)
    };
  }

  // 解析 UDP 头部
  static parseUdp(buffer: ArrayBuffer): UdpPacket | null {
    if (buffer.byteLength < 8) return null;
    const view = new DataView(buffer);
    const srcPort = view.getUint16(0);
    const dstPort = view.getUint16(2);
    const length = view.getUint16(4);
    
    return {
      srcPort,
      dstPort,
      length,
      payload: buffer.slice(8, length)
    };
  }

  // 构建 IPv4 + UDP 包
  static buildIpv4UdpPacket(srcIp: string, dstIp: string, srcPort: number, dstPort: number, payload: ArrayBuffer): ArrayBuffer {
    const ipHeaderLength = 20;
    const udpHeaderLength = 8;
    const totalLength = ipHeaderLength + udpHeaderLength + payload.byteLength;
    
    const buffer = new ArrayBuffer(totalLength);
    const view = new DataView(buffer);
    const uint8Array = new Uint8Array(buffer);

    // --- Build IP Header ---
    // Version (4) + IHL (5) = 0x45
    view.setUint8(0, 0x45);
    // TOS
    view.setUint8(1, 0);
    // Total Length
    view.setUint16(2, totalLength);
    // Identification (random)
    view.setUint16(4, Math.floor(Math.random() * 65535));
    // Flags + Fragment Offset
    view.setUint16(6, 0);
    // TTL
    view.setUint8(8, 64);
    // Protocol (17 = UDP)
    view.setUint8(9, 17);
    // Checksum (initially 0)
    view.setUint16(10, 0);
    // Src IP
    view.setUint32(12, PacketUtil.ipToInt(srcIp));
    // Dst IP
    view.setUint32(16, PacketUtil.ipToInt(dstIp));

    // Calculate IP Checksum
    const ipChecksum = PacketUtil.calculateChecksum(uint8Array.subarray(0, ipHeaderLength));
    view.setUint16(10, ipChecksum);

    // --- Build UDP Header ---
    const udpOffset = ipHeaderLength;
    view.setUint16(udpOffset + 0, srcPort);
    view.setUint16(udpOffset + 2, dstPort);
    view.setUint16(udpOffset + 4, udpHeaderLength + payload.byteLength);
    view.setUint16(udpOffset + 6, 0); // UDP Checksum (optional for IPv4, set to 0)

    // Copy Payload
    const payloadArray = new Uint8Array(payload);
    uint8Array.set(payloadArray, udpOffset + udpHeaderLength);

    // Optional: Calculate UDP Checksum (pseudo-header + udp header + payload)
    // For simplicity, we can leave it as 0 in IPv4 which means "no checksum".
    // Most clients accept this.

    return buffer;
  }

  static calculateChecksum(data: Uint8Array): number {
    let sum = 0;
    for (let i = 0; i < data.length; i += 2) {
      if (i + 1 < data.length) {
        sum += (data[i] << 8) | data[i + 1];
      } else {
        sum += (data[i] << 8);
      }
    }
    
    while (sum > 0xFFFF) {
      sum = (sum & 0xFFFF) + (sum >> 16);
    }
    
    return ~sum & 0xFFFF;
  }

  static ipToInt(ip: string): number {
    const parts = ip.split('.').map(Number);
    return ((parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]) >>> 0;
  }

  static intToIp(int: number): string {
    return [
      (int >>> 24) & 0xFF,
      (int >>> 16) & 0xFF,
      (int >>> 8) & 0xFF,
      int & 0xFF
    ].join('.');
  }
}

export interface Ipv4Packet {
  version: number;
  headerLength: number;
  totalLength: number;
  protocol: number;
  srcIp: string;
  dstIp: string;
  payload: ArrayBuffer;
}

export interface UdpPacket {
  srcPort: number;
  dstPort: number;
  length: number;
  payload: ArrayBuffer;
}
