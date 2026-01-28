import dataPreferences from '@ohos.data.preferences';
import { DEFAULT_DNS_LIST, DnsInfo } from '../model/DnsInfo';
import common from '@ohos.app.ability.common';
import vpnExtension from '@ohos.net.vpnExtension';
import Want from '@ohos.app.ability.Want';

const PREFERENCES_NAME = 'dns_helper_store';
const KEY_DNS_LIST = 'dns_list';
const KEY_IS_INITIALIZED = 'is_initialized';
const KEY_CURRENT_DNS_ID = 'current_dns_id';
const KEY_IS_RUNNING = 'is_running';

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

  // ... (getDnsList implementation remains same) ...

  public async getDnsList(context: common.Context): Promise<DnsInfo[]> {
    const preferences = await this.getPreferences(context);

    // 检查是否已初始化
    const isInitialized = await preferences.get(KEY_IS_INITIALIZED, false);

    if (!isInitialized) {
      // 首次初始化
      await this.saveDnsList(context, DEFAULT_DNS_LIST);
      await preferences.put(KEY_IS_INITIALIZED, true);
      // 默认选中第一个
      if (DEFAULT_DNS_LIST.length > 0) {
        await preferences.put(KEY_CURRENT_DNS_ID, DEFAULT_DNS_LIST[0].id);
        AppStorage.setOrCreate('currentDnsId', DEFAULT_DNS_LIST[0].id);
      }
      await preferences.flush();
      return DEFAULT_DNS_LIST;
    }

    const dnsListJson = await preferences.get(KEY_DNS_LIST, '');
    
    let list: DnsInfo[] = [];
    if (!dnsListJson || dnsListJson === '[]' || dnsListJson === '') {
      list = [];
    } else {
      try {
        list = JSON.parse(dnsListJson.toString()) as DnsInfo[];
      } catch (e) {
        console.error('Failed to parse DNS list:', e);
        list = [];
      }
    }
    AppStorage.setOrCreate('dnsList', list);
    
    // 加载其他状态
    const currentDnsId = await preferences.get(KEY_CURRENT_DNS_ID, '');
    AppStorage.setOrCreate('currentDnsId', currentDnsId);

    const isRunning = await preferences.get(KEY_IS_RUNNING, false);
    AppStorage.setOrCreate('isRunning', isRunning);

    return list;
  }

  public async saveDnsList(context: common.Context, dnsList: DnsInfo[]): Promise<void> {
    const preferences = await this.getPreferences(context);
    await preferences.put(KEY_DNS_LIST, JSON.stringify(dnsList));
    await preferences.flush();
    AppStorage.setOrCreate('dnsList', dnsList);
  }

  // ... (add/update/remove implementations) ...

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
    
    // 如果删除的是当前选中的，清除选中状态
    const currentId = AppStorage.get<string>('currentDnsId');
    if (currentId === id) {
       await this.setCurrentDnsId(context, '');
       // 如果正在运行，停止运行
       await this.setIsRunning(context, false);
    }
  }

  public async setCurrentDnsId(context: common.Context, id: string): Promise<void> {
    const preferences = await this.getPreferences(context);
    await preferences.put(KEY_CURRENT_DNS_ID, id);
    await preferences.flush();
    AppStorage.setOrCreate('currentDnsId', id);

    // 如果正在运行，重启 VPN 以应用新配置
    const isRunning = AppStorage.get<boolean>('isRunning');
    if (isRunning && id) {
       // 通过重启 Extension 来更新配置
       await this.setIsRunning(context, false);
       // 给予一点时间让 Extension 完全停止
       setTimeout(async () => {
         await this.setIsRunning(context, true);
       }, 500);
    }
  }

  public async setIsRunning(context: common.Context, isRunning: boolean): Promise<void> {
    const preferences = await this.getPreferences(context);
    
    if (isRunning) {
      const currentId = AppStorage.get<string>('currentDnsId');
      if (!currentId) {
        throw new Error("请先选择 DNS");
      }
      
      const dns = await this.getDnsById(context, currentId);
      if (!dns) {
        throw new Error("无效的 DNS 配置");
      }
      
      // 启动 VPN Extension
      const want: Want = {
        bundleName: "site.chenwei.dns",
        abilityName: "MyVpnExtAbility",
        parameters: {
          dnsList: [dns.primaryDns, dns.secondaryDns].filter(d => d)
        }
      };
      
      try {
        console.info('Attempting to start VPN Extension with Want:', JSON.stringify(want));
        
        // 添加 5 秒超时机制，防止模拟器环境下卡死
        const startPromise = vpnExtension.startVpnExtensionAbility(want);
        const timeoutPromise = new Promise<void>((_, reject) => {
          setTimeout(() => reject(new Error("Start VPN Extension timed out (5s). Emulator might not support VPN.")), 5000);
        });

        await Promise.race([startPromise, timeoutPromise]);
        
        console.info('VPN Extension start command sent successfully');
      } catch (err) {
        console.error('Failed to start VPN Extension:', err);
        throw new Error(`Start VPN Failed: ${JSON.stringify(err)}`);
      }

    } else {
      // 停止 VPN Extension
      const want: Want = {
        bundleName: "site.chenwei.dns",
        abilityName: "MyVpnExtAbility"
      };
      
      try {
        await vpnExtension.stopVpnExtensionAbility(want);
        console.info('Stopped VPN Extension Ability');
      } catch (err) {
         console.error('Failed to stop VPN Extension:', err);
         // 可能是已经停止了，不抛出异常
      }
    }
    
    await preferences.put(KEY_IS_RUNNING, isRunning);
    await preferences.flush();
    AppStorage.setOrCreate('isRunning', isRunning);
  }
}
