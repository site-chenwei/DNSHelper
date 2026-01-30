export enum DnsType {
  UDP = 'UDP',
  DOT = 'DOT',
  DOH = 'DOH',
  DOQ = 'DOQ'
}

export class DnsInfo {
  id: string;
  name: string;
  primaryDns: string;
  isDefault: boolean;
  type: DnsType;
  preferHttp3: boolean; // 新增字段：是否优先使用 HTTP/3

  constructor(name: string, primaryDns: string, isDefault: boolean = false, type: DnsType = DnsType.UDP, id?: string, preferHttp3: boolean = false) {
    this.id = id ? id : (Math.random().toString(36).slice(2, 9) + Date.now().toString(36));
    this.name = name;
    this.primaryDns = primaryDns;
    this.isDefault = isDefault;
    this.type = type;
    this.preferHttp3 = preferHttp3;
  }
}

export const DEFAULT_DNS_LIST: DnsInfo[] = [
  new DnsInfo('Ali DNS (DoH)', 'https://dns.alidns.com/dns-query', true, DnsType.DOH, 'dns_ali'),
  new DnsInfo('114 DNS', '114.114.114.114', true, DnsType.UDP, 'dns_114'),
  new DnsInfo('DNSPod', '119.29.29.29', true, DnsType.UDP, 'dns_dnspod'),
  new DnsInfo('Baidu DNS', '180.76.76.76', true, DnsType.UDP, 'dns_baidu')
];
