import { DnsType } from '../model/DnsInfo';

export class UiUtils {
  static getDnsTypeColor(type: string): ResourceColor {
    switch (type) {
      case DnsType.UDP:
        return $r('app.color.dns_type_udp');
      case DnsType.DOQ:
        return $r('app.color.dns_type_doq');
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
      case DnsType.DOQ:
        return $r('app.color.dns_type_doq_bg');
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
    return ipv4Regex.test(ip);
  }
}
