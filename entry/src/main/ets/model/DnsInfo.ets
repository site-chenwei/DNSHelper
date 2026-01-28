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
  secondaryDns: string;
  isDefault: boolean;
  type: DnsType;

  constructor(name: string, primaryDns: string, secondaryDns: string = '', isDefault: boolean = false, type: DnsType = DnsType.PURE) {
    this.id = Math.random().toString(36).slice(2, 9) + Date.now().toString(36);
    this.name = name;
    this.primaryDns = primaryDns;
    this.secondaryDns = secondaryDns;
    this.isDefault = isDefault;
    this.type = type;
  }
}

export const DEFAULT_DNS_LIST: DnsInfo[] = [
  new DnsInfo('114 DNS', '114.114.114.114', '114.114.115.115', true, DnsType.PURE),
  new DnsInfo('Google DNS', '8.8.8.8', '8.8.4.4', true, DnsType.PURE),
  new DnsInfo('Ali DNS', '223.5.5.5', '223.6.6.6', true, DnsType.PURE),
  new DnsInfo('DNSPod', '119.29.29.29', '', true, DnsType.PURE)
];
