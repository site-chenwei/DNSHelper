export enum DnsType {
  UDP = 'UDP',
  DOT = 'DOT',
  DOH = 'DOH'
}

export interface DnsTargetConfig {
  address: string;
  type: string;
  preferHttp3: boolean;
}

@ObservedV2
export class DnsInfo {
  @Trace id: string;
  @Trace name: string;
  @Trace primaryDns: string;
  @Trace isDefault: boolean;
  @Trace type: DnsType;
  @Trace preferHttp3: boolean; // 新增字段：是否优先使用 HTTP/3

  constructor(name: string, primaryDns: string, isDefault: boolean = false, type: DnsType = DnsType.UDP,
    preferHttp3: boolean = false) {
    this.id = primaryDns;
    this.name = name;
    this.primaryDns = primaryDns;
    this.isDefault = isDefault;
    this.type = type;
    this.preferHttp3 = preferHttp3;
  }
}

@ObservedV2
export class AppState {
  @Trace isRunning: boolean = false;
  @Trace vpnStartTime: number = 0;
}

export const DEFAULT_DNS_LIST: DnsInfo[] = [
  new DnsInfo('阿里 DOH', 'https://dns.alidns.com/dns-query', true, DnsType.DOH, false),
  new DnsInfo('阿里 DOT', 'dns.alidns.com', true, DnsType.DOT, false),
  new DnsInfo('腾讯 DOH', 'https://doh.pub/dns-query', true, DnsType.DOH, false),
  new DnsInfo('腾讯 DOT', 'dot.pub', true, DnsType.DOT, false),
  new DnsInfo('关圣 DOH', 'https://2026.dns1.top/dns-query', true, DnsType.DOH, false),
];

export const DEFAULT_BACKUP_DNS_LIST: DnsInfo[] = [
  new DnsInfo('阿里 DNS', '223.5.5.5', true, DnsType.UDP, false)
];
