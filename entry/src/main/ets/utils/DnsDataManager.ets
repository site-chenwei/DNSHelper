import { DnsInfo, DEFAULT_DNS_LIST } from '../model/DnsInfo';
import common from '@ohos.app.ability.common';

export class DnsDataManager {
  private static instance: DnsDataManager;

  public static getInstance(): DnsDataManager {
    if (!DnsDataManager.instance) {
      DnsDataManager.instance = new DnsDataManager();
    }
    return DnsDataManager.instance;
  }

  async init(context: common.Context) {
    // Ensure persistence
    PersistentStorage.persistProp('dnsList', DEFAULT_DNS_LIST);
    PersistentStorage.persistProp('currentDnsId', '');
    PersistentStorage.persistProp('hasInitializedDns', false);

    const hasInitialized = AppStorage.get<boolean>('hasInitializedDns');
    const currentList = AppStorage.get<DnsInfo[]>('dnsList');

    if (!hasInitialized) {
      // 首次运行或数据迁移：
      // 1. 如果列表为空（旧数据残留导致），强制恢复默认列表
      // 2. 如果列表已有数据（全新安装自动加载默认值，或老用户数据），仅标记已初始化
      if (!currentList || currentList.length === 0) {
        AppStorage.setOrCreate('dnsList', DEFAULT_DNS_LIST);
      }
      AppStorage.setOrCreate('hasInitializedDns', true);
    }
  }

  getDnsList(): DnsInfo[] {
    return AppStorage.get<DnsInfo[]>('dnsList') || DEFAULT_DNS_LIST;
  }

  async addDns(dns: DnsInfo) {
    const list = this.getDnsList();
    list.push(dns);
    AppStorage.setOrCreate('dnsList', list);
  }

  async updateDns(dns: DnsInfo) {
    let list = this.getDnsList();
    const index = list.findIndex(item => item.id === dns.id);
    if (index !== -1) {
      list[index] = dns;
      AppStorage.setOrCreate('dnsList', list);
    }
  }

  async removeDns(id: string) {
    let list = this.getDnsList();
    list = list.filter(item => item.id !== id);
    AppStorage.setOrCreate('dnsList', list);
  }
  
  async setCurrentDnsId(id: string) {
      AppStorage.setOrCreate('currentDnsId', id);
  }
}
