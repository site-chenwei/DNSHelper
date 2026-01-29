import { DnsInfo, DEFAULT_DNS_LIST } from '../model/DnsInfo';
import common from '@ohos.app.ability.common';
import dataPreferences from '@ohos.data.preferences';

export class DnsDataManager {
  private static instance: DnsDataManager;
  private preferences: dataPreferences.Preferences | null = null;

  public static getInstance(): DnsDataManager {
    if (!DnsDataManager.instance) {
      DnsDataManager.instance = new DnsDataManager();
    }
    return DnsDataManager.instance;
  }

  async init(context: common.Context) {
    // 初始化 Preferences
    try {
      this.preferences = await dataPreferences.getPreferences(context, 'dns_helper_prefs');
    } catch (e) {
      console.error('Failed to get preferences', JSON.stringify(e));
      // 如果初始化失败，使用默认值回退
      AppStorage.setOrCreate('dnsList', DEFAULT_DNS_LIST);
      AppStorage.setOrCreate('currentDnsId', '');
      return;
    }

    // 从 Preferences 加载 DNS 列表
    let dnsList: DnsInfo[] = [];
    try {
      const jsonStr = await this.preferences.get('saved_dns_list', '') as string;
      if (jsonStr) {
        dnsList = JSON.parse(jsonStr) as DnsInfo[];
      }
    } catch (e) {
      console.error('Failed to parse dns list', JSON.stringify(e));
    }

    // 如果为空或加载失败，使用默认值
    if (dnsList.length === 0) {
      dnsList = [...DEFAULT_DNS_LIST]; // 克隆默认列表
      this.saveDnsListToPrefs(dnsList);
    }
    AppStorage.setOrCreate('dnsList', dnsList);

    // 加载当前 DNS ID
    let currentId = '';
    try {
      currentId = await this.preferences.get('saved_dns_id', '') as string;
    } catch (e) {
      console.error('Failed to load current id', JSON.stringify(e));
    }

    // 验证 ID 有效性
    const isValid = currentId && dnsList.some(d => d.id === currentId);
    console.info(`DnsDataManager init: loadedId=${currentId}, isValid=${isValid}`);

    if (!isValid && dnsList.length > 0) {
      currentId = dnsList[0].id;
      console.info(`DnsDataManager init: resetting to first DNS: ${currentId}`);
      this.saveCurrentIdToPrefs(currentId);
    }
    AppStorage.setOrCreate('currentDnsId', currentId);
  }

  private async saveDnsListToPrefs(list: DnsInfo[]) {
    if (!this.preferences) return;
    try {
      await this.preferences.put('saved_dns_list', JSON.stringify(list));
      await this.preferences.flush();
    } catch (e) {
      console.error('Failed to save dns list', JSON.stringify(e));
    }
  }

  private async saveCurrentIdToPrefs(id: string) {
    if (!this.preferences) return;
    try {
      await this.preferences.put('saved_dns_id', id);
      await this.preferences.flush();
    } catch (e) {
      console.error('Failed to save current id', JSON.stringify(e));
    }
  }

  getDnsList(): DnsInfo[] {
    return AppStorage.get<DnsInfo[]>('dnsList') || DEFAULT_DNS_LIST;
  }

  async addDns(dns: DnsInfo) {
    const list = this.getDnsList();
    list.push(dns);
    AppStorage.setOrCreate('dnsList', list);
    await this.saveDnsListToPrefs(list);
  }

  async updateDns(dns: DnsInfo) {
    let list = this.getDnsList();
    const index = list.findIndex(item => item.id === dns.id);
    if (index !== -1) {
      list[index] = dns;
      AppStorage.setOrCreate('dnsList', list);
      await this.saveDnsListToPrefs(list);
    }
  }

  async removeDns(id: string) {
    let list = this.getDnsList();
    list = list.filter(item => item.id !== id);
    AppStorage.setOrCreate('dnsList', list);
    await this.saveDnsListToPrefs(list);

    // 如果删除了当前选中的 DNS，尝试切换到第一个，或者置空
    const currentId = AppStorage.get<string>('currentDnsId');
    if (currentId === id) {
      if (list.length > 0) {
        await this.setCurrentDnsId(list[0].id);
      } else {
        await this.setCurrentDnsId('');
      }
    }
  }
  
  async setCurrentDnsId(id: string) {
      AppStorage.setOrCreate('currentDnsId', id);
      await this.saveCurrentIdToPrefs(id);
  }
}
