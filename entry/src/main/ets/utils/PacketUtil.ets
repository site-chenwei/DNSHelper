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
    view.setUint16(udpOffset + 6, 0); // UDP Checksum (initial 0)

    // Copy Payload
    const payloadArray = new Uint8Array(payload);
    uint8Array.set(payloadArray, udpOffset + udpHeaderLength);

    // Calculate UDP Checksum (Pseudo Header + UDP Header + Data)
    // Pseudo Header: SrcIP(4) + DstIP(4) + Zero(1) + Protocol(1) + UDP Length(2)
    const pseudoHeader = new Uint8Array(12);
    const phView = new DataView(pseudoHeader.buffer);
    phView.setUint32(0, PacketUtil.ipToInt(srcIp));
    phView.setUint32(4, PacketUtil.ipToInt(dstIp));
    phView.setUint8(8, 0);
    phView.setUint8(9, 17);
    phView.setUint16(10, udpHeaderLength + payload.byteLength);

    let sum = 0;
    // Sum Pseudo Header
    for (let i = 0; i < pseudoHeader.length; i += 2) {
      sum += (pseudoHeader[i] << 8) | pseudoHeader[i + 1];
    }
    // Sum UDP Header + Payload
    const udpData = uint8Array.subarray(udpOffset);
    for (let i = 0; i < udpData.length; i += 2) {
      if (i + 1 < udpData.length) {
        sum += (udpData[i] << 8) | udpData[i + 1];
      } else {
        sum += (udpData[i] << 8); // Pad with zero byte at end
      }
    }

    while (sum > 0xFFFF) {
      sum = (sum & 0xFFFF) + (sum >> 16);
    }
    const checksum = ~sum & 0xFFFF;
    // If checksum is 0, it should be 0xFFFF (but 0 is allowed in UDP/IPv4 to mean 'no checksum')
    // However, some strict implementations might require it. Let's stick to calculated value.
    view.setUint16(udpOffset + 6, checksum === 0 ? 0xFFFF : checksum);

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

  // 解析 IPv6 头部
  static parseIpv6(buffer: ArrayBuffer): Ipv6Packet | null {
    if (buffer.byteLength < 40) return null;
    const view = new DataView(buffer);
    const firstWord = view.getUint32(0);
    const version = (firstWord >> 28) & 0x0F;

    if (version !== 6) return null;

    const trafficClass = (firstWord >> 20) & 0xFF;
    const flowLabel = firstWord & 0xFFFFF;
    const payloadLength = view.getUint16(4);
    const nextHeader = view.getUint8(6);
    const hopLimit = view.getUint8(7);

    const srcIpBytes = new Uint8Array(buffer.slice(8, 24));
    const dstIpBytes = new Uint8Array(buffer.slice(24, 40));

    return {
      version,
      trafficClass,
      flowLabel,
      payloadLength,
      nextHeader,
      hopLimit,
      srcIp: PacketUtil.bytesToIpv6(srcIpBytes),
      dstIp: PacketUtil.bytesToIpv6(dstIpBytes),
      payload: buffer.slice(40, 40 + payloadLength)
    };
  }

  // 构建 IPv6 + UDP 包
  static buildIpv6UdpPacket(srcIp: string, dstIp: string, srcPort: number, dstPort: number, payload: ArrayBuffer): ArrayBuffer {
    const ipHeaderLength = 40;
    const udpHeaderLength = 8;
    const payloadLength = udpHeaderLength + payload.byteLength;
    const totalLength = ipHeaderLength + payloadLength;

    const buffer = new ArrayBuffer(totalLength);
    const view = new DataView(buffer);
    const uint8Array = new Uint8Array(buffer);

    // --- Build IPv6 Header ---
    // Version (6) + Traffic Class (0) + Flow Label (0)
    view.setUint32(0, 0x60000000);
    // Payload Length
    view.setUint16(4, payloadLength);
    // Next Header (17 = UDP)
    view.setUint8(6, 17);
    // Hop Limit
    view.setUint8(7, 64);
    
    // Src IP
    const srcIpBytes = PacketUtil.ipv6ToBytes(srcIp);
    uint8Array.set(srcIpBytes, 8);
    
    // Dst IP
    const dstIpBytes = PacketUtil.ipv6ToBytes(dstIp);
    uint8Array.set(dstIpBytes, 24);

    // --- Build UDP Header ---
    const udpOffset = ipHeaderLength;
    view.setUint16(udpOffset + 0, srcPort);
    view.setUint16(udpOffset + 2, dstPort);
    view.setUint16(udpOffset + 4, payloadLength);
    view.setUint16(udpOffset + 6, 0); // UDP Checksum (initial 0)

    // Copy Payload
    const payloadArray = new Uint8Array(payload);
    uint8Array.set(payloadArray, udpOffset + udpHeaderLength);

    // Calculate UDP Checksum for IPv6
    // Pseudo Header: SrcIP(16) + DstIP(16) + UDP Length(4) + NextHeader(4)
    // Actually Pseudo Header structure for IPv6:
    // Source Address (16)
    // Destination Address (16)
    // UDP Length (4)
    // Zeros (3) + Next Header (1)
    
    let sum = 0;
    
    // Sum Src IP
    for (let i = 0; i < srcIpBytes.length; i += 2) {
      sum += (srcIpBytes[i] << 8) | srcIpBytes[i + 1];
    }
    // Sum Dst IP
    for (let i = 0; i < dstIpBytes.length; i += 2) {
      sum += (dstIpBytes[i] << 8) | dstIpBytes[i + 1];
    }
    
    // Sum UDP Length
    sum += payloadLength;
    
    // Sum Next Header (UDP=17)
    sum += 17;

    // Sum UDP Header + Payload
    const udpData = uint8Array.subarray(udpOffset);
    for (let i = 0; i < udpData.length; i += 2) {
      if (i + 1 < udpData.length) {
        sum += (udpData[i] << 8) | udpData[i + 1];
      } else {
        sum += (udpData[i] << 8); // Pad with zero byte at end
      }
    }

    while (sum > 0xFFFF) {
      sum = (sum & 0xFFFF) + (sum >> 16);
    }
    const checksum = ~sum & 0xFFFF;
    view.setUint16(udpOffset + 6, checksum === 0 ? 0xFFFF : checksum);

    return buffer;
  }

  static bytesToIpv6(bytes: Uint8Array): string {
    const parts: string[] = [];
    for (let i = 0; i < bytes.length; i += 2) {
      const part = (bytes[i] << 8) | bytes[i + 1];
      parts.push(part.toString(16));
    }
    return parts.join(':');
  }

  static ipv6ToBytes(ipv6: string): Uint8Array {
    // Handle simplified IPv6 (::)
    let fullIpv6 = ipv6;
    if (ipv6.includes('::')) {
      const parts = ipv6.split('::');
      const left = parts[0] ? parts[0].split(':') : [];
      const right = parts[1] ? parts[1].split(':') : [];
      const missing = 8 - (left.length + right.length);
      const zeros: string[] = new Array<string>(missing).fill('0');
      fullIpv6 = [...left, ...zeros, ...right].join(':');
    }
    
    const parts = fullIpv6.split(':');
    const bytes = new Uint8Array(16);
    for (let i = 0; i < 8; i++) {
      const val = parseInt(parts[i] || '0', 16);
      bytes[i * 2] = (val >> 8) & 0xFF;
      bytes[i * 2 + 1] = val & 0xFF;
    }
    return bytes;
  }
}

export interface Ipv6Packet {
  version: number;
  trafficClass: number;
  flowLabel: number;
  payloadLength: number;
  nextHeader: number;
  hopLimit: number;
  srcIp: string;
  dstIp: string;
  payload: ArrayBuffer;
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
