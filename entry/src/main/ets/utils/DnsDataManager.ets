import { DnsInfo, AppState, DEFAULT_DNS_LIST, DEFAULT_BACKUP_DNS_LIST } from '../model/DnsInfo';
import common from '@ohos.app.ability.common';
import dataPreferences from '@ohos.data.preferences';
import { promptAction, AppStorageV2 } from '@kit.ArkUI';

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
    // 初始化 AppState
    AppStorageV2.connect(AppState, 'appState', () => new AppState());

    // 初始化 Preferences
    try {
      this.preferences = await dataPreferences.getPreferences(context, 'dns_helper_prefs');
    } catch (e) {
      console.error('Failed to get preferences', JSON.stringify(e));
      // 如果初始化失败，使用默认值回退
      AppStorageV2.connect(Array, 'dnsList', () => DEFAULT_DNS_LIST);
      AppStorageV2.connect(String, 'currentDnsId', () => '');
      return;
    }

    // 从 Preferences 加载 DNS 列表
    let dnsList: DnsInfo[] = [];
    try {
      const jsonStr = await this.preferences.get('saved_dns_list', '') as string;
      if (jsonStr) {
        // Need to reconstruct objects for @ObservedV2 to work if they were plain objects
        const rawList = JSON.parse(jsonStr) as DnsInfo[];
        dnsList = rawList.map(d => new DnsInfo(d.name, d.primaryDns, d.isDefault, d.type, d.preferHttp3));
      }
    } catch (e) {
      console.error('Failed to parse dns list', JSON.stringify(e));
    }

    // 如果为空或加载失败，使用默认值
    if (dnsList.length === 0) {
      dnsList = DEFAULT_DNS_LIST.map(d => new DnsInfo(d.name, d.primaryDns, d.isDefault, d.type, d.preferHttp3)); // Clone default list
      this.saveDnsListToPrefs(dnsList);
    }

    AppStorageV2.connect(Array, 'dnsList', () => dnsList);

    // 加载当前选中的 DNS IDs
    let selectedIds: string[] = [];
    try {
      const jsonStr = await this.preferences.get('saved_selected_dns_ids', '') as string;
      if (jsonStr) {
        selectedIds = JSON.parse(jsonStr) as string[];
      }
    } catch (e) {
      console.error('Failed to load selected ids', JSON.stringify(e));
    }

    // 验证 IDs 有效性 (移除不存在的)
    if (selectedIds.length > 0) {
      const validIds = selectedIds.filter(id => dnsList.some(d => d.id === id));
      if (validIds.length !== selectedIds.length) {
         selectedIds = validIds;
         this.saveSelectedDnsIdsToPrefs(selectedIds);
      }
    }
    
    // 如果没有选中的，默认选中第一个
    if (selectedIds.length === 0 && dnsList.length > 0) {
      selectedIds = [dnsList[0].id];
      this.saveSelectedDnsIdsToPrefs(selectedIds);
    }
    
    AppStorageV2.connect(Array, 'selectedDnsIds', () => selectedIds);
    // 为了兼容旧代码（如果有遗漏），保留 currentDnsId 为第一个选中的 ID
    AppStorageV2.connect(String, 'currentDnsId', () => selectedIds.length > 0 ? selectedIds[0] : '');

    // 加载备用 DNS 列表
    let backupDnsList: DnsInfo[] = [];
    try {
      const jsonStr = await this.preferences.get('saved_backup_dns_list', '') as string;
      if (jsonStr) {
        const rawList = JSON.parse(jsonStr) as DnsInfo[];
        backupDnsList = rawList.map(d => new DnsInfo(d.name, d.primaryDns, d.isDefault, d.type, d.preferHttp3));
      }
    } catch (e) {
      console.error('Failed to parse backup dns list', JSON.stringify(e));
    }

    // 确保默认备用 DNS 存在且位于首位
    const defaultBackup = DEFAULT_BACKUP_DNS_LIST[0];
    const existsIndex = backupDnsList.findIndex(d => (d.id === defaultBackup.id || d.primaryDns === defaultBackup.primaryDns));
    if (existsIndex === -1) {
      backupDnsList.unshift(new DnsInfo(defaultBackup.name, defaultBackup.primaryDns, defaultBackup.isDefault, defaultBackup.type, defaultBackup.preferHttp3));
      this.saveBackupDnsListToPrefs(backupDnsList);
    }
    
    AppStorageV2.connect(Array, 'backupDnsList', () => backupDnsList);

    // 加载当前选中的备用 DNS ID
    let currentBackupId = '';
    try {
      currentBackupId = await this.preferences.get('saved_current_backup_dns_id', '') as string;
    } catch (e) {
      console.error('Failed to load current backup id', JSON.stringify(e));
    }
    
    // 如果没有选中的，默认选中第一个
    if (!currentBackupId && backupDnsList.length > 0) {
      currentBackupId = backupDnsList[0].id;
      this.saveCurrentBackupDnsIdToPrefs(currentBackupId);
    }
    
    AppStorageV2.connect(String, 'currentBackupDnsId', () => currentBackupId);
  }

  // 获取 DNS 列表
  getDnsList(): DnsInfo[] {
    return AppStorageV2.connect(Array, 'dnsList', () => [])!;
  }
  
  // 获取备用 DNS 列表
  getBackupDnsList(): DnsInfo[] {
    return AppStorageV2.connect(Array, 'backupDnsList', () => [])!;
  }

  // 保存 DNS 列表到 Preferences
  private async saveDnsListToPrefs(dnsList: DnsInfo[]) {
    if (this.preferences) {
      try {
        await this.preferences.put('saved_dns_list', JSON.stringify(dnsList));
        await this.preferences.flush();
      } catch (e) {
        console.error('Failed to save dns list', JSON.stringify(e));
      }
    }
  }

  // 添加 DNS
  async addDns(dns: DnsInfo) {
    const list = this.getDnsList();
    list.push(dns);
    AppStorageV2.connect(Array, 'dnsList', () => list);
    await this.saveDnsListToPrefs(list);
  }

  // 更新 DNS
  async updateDns(dns: DnsInfo, oldId: string) {
    const list = this.getDnsList();
    const index = list.findIndex(d => d.id === oldId);
    if (index !== -1) {
      list[index] = dns;
      AppStorageV2.connect(Array, 'dnsList', () => list);
      await this.saveDnsListToPrefs(list);
    }
  }
  
  // 删除 DNS
  async deleteDns(id: string) {
    let list = this.getDnsList();
    list = list.filter(d => d.id !== id);
    AppStorageV2.connect(Array, 'dnsList', () => list);
    await this.saveDnsListToPrefs(list);
    
    // 如果删除的是当前选中的，取消选中
    let selectedIds = AppStorageV2.connect(Array, 'selectedDnsIds', () => []) as string[];
    if (selectedIds.includes(id)) {
        selectedIds = selectedIds.filter(selectedId => selectedId !== id);
        AppStorageV2.connect(Array, 'selectedDnsIds', () => selectedIds);
        this.saveSelectedDnsIdsToPrefs(selectedIds);
    }
  }

  // 保存选中的 DNS IDs 到 Preferences
  private async saveSelectedDnsIdsToPrefs(ids: string[]) {
    if (this.preferences) {
      try {
        await this.preferences.put('saved_selected_dns_ids', JSON.stringify(ids));
        await this.preferences.flush();
      } catch (e) {
        console.error('Failed to save selected ids', JSON.stringify(e));
      }
    }
  }

  // 设置当前选中的 DNS IDs
  async setSelectedDnsIds(ids: string[]) {
    AppStorageV2.connect(Array, 'selectedDnsIds', () => ids);
    await this.saveSelectedDnsIdsToPrefs(ids);
    
    // 为了兼容旧代码，更新 currentDnsId
    const currentId = ids.length > 0 ? ids[0] : '';
    AppStorageV2.connect(String, 'currentDnsId', () => currentId);
  }
  
  // 保存备用 DNS 列表到 Preferences
  private async saveBackupDnsListToPrefs(dnsList: DnsInfo[]) {
    if (this.preferences) {
      try {
        await this.preferences.put('saved_backup_dns_list', JSON.stringify(dnsList));
        await this.preferences.flush();
      } catch (e) {
        console.error('Failed to save backup dns list', JSON.stringify(e));
      }
    }
  }
  
  // 添加备用 DNS
  async addBackupDns(dns: DnsInfo) {
    const list = this.getBackupDnsList();
    list.push(dns);
    AppStorageV2.connect(Array, 'backupDnsList', () => list);
    await this.saveBackupDnsListToPrefs(list);
  }
  
  // 更新备用 DNS
  async updateBackupDns(dns: DnsInfo, oldId: string) {
    const list = this.getBackupDnsList();
    const index = list.findIndex(d => d.id === oldId);
    if (index !== -1) {
      list[index] = dns;
      AppStorageV2.connect(Array, 'backupDnsList', () => list);
      await this.saveBackupDnsListToPrefs(list);
    }
  }
  
  // 删除备用 DNS
  async deleteBackupDns(id: string) {
    let list = this.getBackupDnsList();
    list = list.filter(d => d.id !== id);
    AppStorageV2.connect(Array, 'backupDnsList', () => list);
    await this.saveBackupDnsListToPrefs(list);
    
    // 如果删除的是当前选中的，重置为第一个
    const currentId = AppStorageV2.connect(String, 'currentBackupDnsId', () => '')!;
    if (currentId === id && list.length > 0) {
      this.setCurrentBackupDnsId(list[0].id);
    }
  }
  
  // 保存当前选中的备用 DNS ID 到 Preferences
  private async saveCurrentBackupDnsIdToPrefs(id: string) {
    if (this.preferences) {
      try {
        await this.preferences.put('saved_current_backup_dns_id', id);
        await this.preferences.flush();
      } catch (e) {
        console.error('Failed to save current backup id', JSON.stringify(e));
      }
    }
  }
  
  // 设置当前选中的备用 DNS ID
  async setCurrentBackupDnsId(id: string) {
    AppStorageV2.connect(String, 'currentBackupDnsId', () => id);
    await this.saveCurrentBackupDnsIdToPrefs(id);
  }
}
