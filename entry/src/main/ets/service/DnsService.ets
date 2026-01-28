import dataPreferences from '@ohos.data.preferences';
import { DEFAULT_DNS_LIST, DnsInfo } from '../model/DnsInfo';
import common from '@ohos.app.ability.common';

const PREFERENCES_NAME = 'dns_helper_store';
const KEY_DNS_LIST = 'dns_list';

export class DnsService {
  private static instance: DnsService;
  private preferences: dataPreferences.Preferences | null = null;

  private constructor() {
  }

  public static getInstance(): DnsService {
    if (!DnsService.instance) {
      DnsService.instance = new DnsService();
    }
    return DnsService.instance;
  }

  private async getPreferences(context: common.Context): Promise<dataPreferences.Preferences> {
    if (!this.preferences) {
      this.preferences = await dataPreferences.getPreferences(context, PREFERENCES_NAME);
    }
    return this.preferences;
  }

  public async getDnsList(context: common.Context): Promise<DnsInfo[]> {
    const preferences = await this.getPreferences(context);
    const dnsListJson = await preferences.get(KEY_DNS_LIST, '');
    
    let list: DnsInfo[] = [];
    if (!dnsListJson || dnsListJson === '[]' || dnsListJson === '') {
      // 如果没有数据，初始化默认数据
      await this.saveDnsList(context, DEFAULT_DNS_LIST);
      list = DEFAULT_DNS_LIST;
    } else {
      try {
        list = JSON.parse(dnsListJson.toString()) as DnsInfo[];
      } catch (e) {
        console.error('Failed to parse DNS list:', e);
        list = DEFAULT_DNS_LIST;
      }
    }
    AppStorage.setOrCreate('dnsList', list);
    return list;
  }

  public async saveDnsList(context: common.Context, dnsList: DnsInfo[]): Promise<void> {
    const preferences = await this.getPreferences(context);
    await preferences.put(KEY_DNS_LIST, JSON.stringify(dnsList));
    await preferences.flush();
    AppStorage.setOrCreate('dnsList', dnsList);
  }

  public async addDns(context: common.Context, dns: DnsInfo): Promise<void> {
    const list = await this.getDnsList(context);
    list.push(dns);
    await this.saveDnsList(context, list);
  }

  public async updateDns(context: common.Context, dns: DnsInfo): Promise<void> {
    const list = await this.getDnsList(context);
    const index = list.findIndex(item => item.id === dns.id);
    if (index !== -1) {
      list[index] = dns;
      await this.saveDnsList(context, list);
    }
  }

  public async getDnsById(context: common.Context, id: string): Promise<DnsInfo | undefined> {
    const list = await this.getDnsList(context);
    return list.find(item => item.id === id);
  }

  public async removeDns(context: common.Context, id: string): Promise<void> {
    let list = await this.getDnsList(context);
    list = list.filter(item => item.id !== id);
    await this.saveDnsList(context, list);
  }
}
