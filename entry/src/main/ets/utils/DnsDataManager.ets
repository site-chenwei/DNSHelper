import { DnsInfo, DEFAULT_DNS_LIST, DEFAULT_BACKUP_DNS_LIST } from '../model/DnsInfo';
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

    // 加载备用 DNS 列表
    let backupDnsList: DnsInfo[] = [];
    try {
      const jsonStr = await this.preferences.get('saved_backup_dns_list', '') as string;
      if (jsonStr) {
        backupDnsList = JSON.parse(jsonStr) as DnsInfo[];
      }
    } catch (e) {
      console.error('Failed to parse backup dns list', JSON.stringify(e));
    }

    // 确保默认备用 DNS 存在且位于首位
    const defaultBackup = DEFAULT_BACKUP_DNS_LIST[0];
    const existsIndex = backupDnsList.findIndex(d => d.id === defaultBackup.id);
    if (existsIndex === -1) {
      backupDnsList.unshift(defaultBackup);
      this.saveBackupDnsListToPrefs(backupDnsList);
    }
    
    AppStorage.setOrCreate('backupDnsList', backupDnsList);

    // 加载当前选中的备用 DNS ID
    let currentBackupId = '';
    try {
      currentBackupId = await this.preferences.get('saved_backup_dns_id', '') as string;
    } catch (e) {
      console.error('Failed to load current backup id', JSON.stringify(e));
    }

    // 验证 ID 有效性，如果无效且列表不为空，默认选中第一个（通常是阿里DNS）
    const isBackupValid = currentBackupId && backupDnsList.some(d => d.id === currentBackupId);
    if (!isBackupValid && backupDnsList.length > 0) {
      currentBackupId = backupDnsList[0].id;
      this.saveCurrentBackupIdToPrefs(currentBackupId);
    }
    AppStorage.setOrCreate('currentBackupDnsId', currentBackupId);
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

  private async saveBackupDnsListToPrefs(list: DnsInfo[]) {
    if (!this.preferences) return;
    try {
      await this.preferences.put('saved_backup_dns_list', JSON.stringify(list));
      await this.preferences.flush();
    } catch (e) {
      console.error('Failed to save backup dns list', JSON.stringify(e));
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

  private async saveCurrentBackupIdToPrefs(id: string) {
    if (!this.preferences) return;
    try {
      await this.preferences.put('saved_backup_dns_id', id);
      await this.preferences.flush();
    } catch (e) {
      console.error('Failed to save current backup id', JSON.stringify(e));
    }
  }

  async setCurrentBackupDnsId(id: string) {
    AppStorage.setOrCreate('currentBackupDnsId', id);
    await this.saveCurrentBackupIdToPrefs(id);
  }

  getBackupDnsList(): DnsInfo[] {
    return AppStorage.get<DnsInfo[]>('backupDnsList') || [];
  }

  async addBackupDns(dns: DnsInfo) {
    const list = this.getBackupDnsList();
    list.push(dns);
    AppStorage.setOrCreate('backupDnsList', list);
    await this.saveBackupDnsListToPrefs(list);
  }

  async updateBackupDns(dns: DnsInfo) {
    let list = this.getBackupDnsList();
    const index = list.findIndex(item => item.id === dns.id);
    if (index !== -1) {
      list[index] = dns;
      AppStorage.setOrCreate('backupDnsList', list);
      await this.saveBackupDnsListToPrefs(list);
    }
  }

  async removeBackupDns(id: string) {
    let list = this.getBackupDnsList();
    list = list.filter(item => item.id !== id);
    AppStorage.setOrCreate('backupDnsList', list);
    await this.saveBackupDnsListToPrefs(list);

    // 如果删除了当前选中的备用 DNS，尝试切换到第一个
    const currentBackupId = AppStorage.get<string>('currentBackupDnsId');
    if (currentBackupId === id) {
      if (list.length > 0) {
        await this.setCurrentBackupDnsId(list[0].id);
      } else {
        await this.setCurrentBackupDnsId('');
      }
    }
  }
}
