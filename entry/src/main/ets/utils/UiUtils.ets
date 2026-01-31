import { DnsType } from '../model/DnsInfo';

export class UiUtils {
  static getDnsTypeColor(type: string): ResourceColor {
    switch (type) {
      case DnsType.UDP:
        return $r('app.color.dns_type_udp');
      case DnsType.DOH:
        return $r('app.color.dns_type_doh');
      case DnsType.DOT:
        return $r('app.color.dns_type_dot');
      default:
        return $r('app.color.dns_type_udp');
    }
  }

  static getDnsTypeBgColor(type: string): ResourceColor {
    switch (type) {
      case DnsType.UDP:
        return $r('app.color.dns_type_udp_bg');
      case DnsType.DOH:
        return $r('app.color.dns_type_doh_bg');
      case DnsType.DOT:
        return $r('app.color.dns_type_dot_bg');
      default:
        return $r('app.color.dns_type_udp_bg');
    }
  }
}

export class Validator {
  static isValidIp(ip: string, type: DnsType): boolean {
    if (type === DnsType.DOH) {
      return ip.startsWith('https://') || ip.startsWith('http://');
    }
    const ipv4Regex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    
    if (type === DnsType.DOT) {
      // DOT 支持 IPv4 或域名
      const domainRegex = /^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$/;
      return ipv4Regex.test(ip) || domainRegex.test(ip);
    }

    return ipv4Regex.test(ip);
  }
}
