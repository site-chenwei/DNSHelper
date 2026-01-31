import { DnsInfo, DEFAULT_DNS_LIST, DEFAULT_BACKUP_DNS_LIST } from '../model/DnsInfo';
import common from '@ohos.app.ability.common';
import dataPreferences from '@ohos.data.preferences';
import { promptAction } from '@kit.ArkUI';

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
    
    AppStorage.setOrCreate('selectedDnsIds', selectedIds);
    // 为了兼容旧代码（如果有遗漏），保留 currentDnsId 为第一个选中的 ID
    AppStorage.setOrCreate('currentDnsId', selectedIds.length > 0 ? selectedIds[0] : '');

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
    const existsIndex = backupDnsList.findIndex(d => (d.id === defaultBackup.id || d.primaryDns === defaultBackup.primaryDns));
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

    // 验证 ID 有效性
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

  private async saveSelectedDnsIdsToPrefs(ids: string[]) {
    if (!this.preferences) return;
    try {
      await this.preferences.put('saved_selected_dns_ids', JSON.stringify(ids));
      await this.preferences.flush();
    } catch (e) {
      console.error('Failed to save selected ids', JSON.stringify(e));
    }
  }

  // private async saveCurrentIdToPrefs(id: string) { ... } // Deprecated

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

  async updateDns(dns: DnsInfo, originalId?: string) {
    let list = this.getDnsList();
    const targetId = originalId || dns.id;
    const index = list.findIndex(item => item.id === targetId);
    if (index !== -1) {
      list[index] = dns;
      AppStorage.setOrCreate('dnsList', list);
      await this.saveDnsListToPrefs(list);

      // 如果修改了 IP (ID 变化)，且当前选中项包含旧 ID，需要更新选中项
      if (targetId !== dns.id) {
        const selectedIds = AppStorage.get<string[]>('selectedDnsIds') || [];
        if (selectedIds.includes(targetId)) {
          const newSelectedIds = selectedIds.map(id => id === targetId ? dns.id : id);
          await this.setSelectedDnsIds(newSelectedIds);
        }
      }
    }
  }

  async removeDns(id: string) {
    let list = this.getDnsList();
    list = list.filter(item => item.id !== id);
    AppStorage.setOrCreate('dnsList', list);
    await this.saveDnsListToPrefs(list);

    // 如果删除了选中的 DNS，从选中列表中移除
    const selectedIds = AppStorage.get<string[]>('selectedDnsIds') || [];
    if (selectedIds.includes(id)) {
      const newSelectedIds = selectedIds.filter(sid => sid !== id);
      // 如果全部删完了，且还有列表项，默认选中第一个
      if (newSelectedIds.length === 0 && list.length > 0) {
        newSelectedIds.push(list[0].id);
      }
      await this.setSelectedDnsIds(newSelectedIds);
    }
  }
  
  async setSelectedDnsIds(ids: string[]) {
      AppStorage.setOrCreate('selectedDnsIds', ids);
      // Update compatibility field
      AppStorage.setOrCreate('currentDnsId', ids.length > 0 ? ids[0] : '');
      await this.saveSelectedDnsIdsToPrefs(ids);
  }

  async toggleDnsId(id: string) {
      const selectedIds = AppStorage.get<string[]>('selectedDnsIds') || [];
      let newSelectedIds: string[];
      if (selectedIds.includes(id)) {
          // If it's the only one, don't allow deselecting
          if (selectedIds.length === 1) {
              promptAction.showToast({ message: '至少需要启用一个DNS服务' });
              return; 
          }
          newSelectedIds = selectedIds.filter(sid => sid !== id);
      } else {
          newSelectedIds = [...selectedIds, id];
      }
      await this.setSelectedDnsIds(newSelectedIds);
  }

  // Deprecated wrapper
  async setCurrentDnsId(id: string) {
      await this.setSelectedDnsIds([id]);
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

  async updateBackupDns(dns: DnsInfo, originalId?: string) {
    let list = this.getBackupDnsList();
    const targetId = originalId || dns.id;
    const index = list.findIndex(item => item.id === targetId);
    if (index !== -1) {
      list[index] = dns;
      AppStorage.setOrCreate('backupDnsList', list);
      await this.saveBackupDnsListToPrefs(list);

      // 如果修改了 IP (ID 变化)，且当前选中项是旧 ID，需要更新选中项
      if (targetId !== dns.id) {
        const currentBackupId = AppStorage.get<string>('currentBackupDnsId');
        if (currentBackupId === targetId) {
          await this.setCurrentBackupDnsId(dns.id);
        }
      }
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
