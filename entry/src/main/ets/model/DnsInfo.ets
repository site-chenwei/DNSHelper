export enum DnsType {
  PURE = '纯DNS',
  UDP = 'UDP',
  TCP = 'TCP',
  DOT = 'DOT',
  DOH = 'DOH',
  DOQ = 'DOQ',
  DOH3 = 'DOH3'
}

export class DnsInfo {
  id: string;
  name: string;
  primaryDns: string;
  isDefault: boolean;
  type: DnsType;

  constructor(name: string, primaryDns: string, isDefault: boolean = false, type: DnsType = DnsType.PURE, id?: string) {
    this.id = id ? id : (Math.random().toString(36).slice(2, 9) + Date.now().toString(36));
    this.name = name;
    this.primaryDns = primaryDns;
    this.isDefault = isDefault;
    this.type = type;
  }
}

export const DEFAULT_DNS_LIST: DnsInfo[] = [
  new DnsInfo('114 DNS', '114.114.114.114', true, DnsType.PURE, 'dns_114'),
  new DnsInfo('Google DNS', '8.8.8.8', true, DnsType.PURE, 'dns_google'),
  new DnsInfo('Ali DNS', '223.5.5.5', true, DnsType.PURE, 'dns_ali'),
  new DnsInfo('DNSPod', '119.29.29.29', true, DnsType.PURE, 'dns_dnspod'),
  new DnsInfo('Cloudflare', '1.1.1.1', true, DnsType.PURE, 'dns_cloudflare'),
  new DnsInfo('Quad9', '9.9.9.9', true, DnsType.PURE, 'dns_quad9'),
  new DnsInfo('Baidu DNS', '180.76.76.76', true, DnsType.PURE, 'dns_baidu'),
  new DnsInfo('Google IPv6', '2001:4860:4860::8888', true, DnsType.PURE, 'dns_google_v6')
];
