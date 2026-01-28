import dataPreferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

const CACHE_PREF_NAME = 'dns_cache_config';
const KEY_CACHE_TTL = 'cache_ttl';
const KEY_CACHE_SIZE = 'cache_size';

export interface CacheEntry {
  response: ArrayBuffer;
  expireAt: number;
}

export class DnsCacheManager {
  private static instance: DnsCacheManager;
  private cache: Map<string, CacheEntry> = new Map();
  private ttl: number = 600; // 默认 10 分钟
  private maxSize: number = 100; // 默认 100 条
  private preferences: dataPreferences.Preferences | null = null;

  private constructor() {}

  public static getInstance(): DnsCacheManager {
    if (!DnsCacheManager.instance) {
      DnsCacheManager.instance = new DnsCacheManager();
    }
    return DnsCacheManager.instance;
  }

  public async init(context: common.Context) {
    this.preferences = await dataPreferences.getPreferences(context, CACHE_PREF_NAME);
    this.ttl = await this.preferences.get(KEY_CACHE_TTL, 600) as number;
    this.maxSize = await this.preferences.get(KEY_CACHE_SIZE, 100) as number;
    AppStorage.setOrCreate('cacheTTL', this.ttl);
    AppStorage.setOrCreate('cacheSize', this.maxSize);
  }

  public async updateConfig(context: common.Context, ttl: number, size: number) {
    this.ttl = ttl;
    this.maxSize = size;
    
    // Trim cache if needed
    if (this.cache.size > this.maxSize) {
      this.cache.clear(); // 简单处理：清空
    }

    if (this.preferences) {
      await this.preferences.put(KEY_CACHE_TTL, ttl);
      await this.preferences.put(KEY_CACHE_SIZE, size);
      await this.preferences.flush();
    }
    
    AppStorage.setOrCreate('cacheTTL', this.ttl);
    AppStorage.setOrCreate('cacheSize', this.maxSize);
  }

  public get(key: string): ArrayBuffer | null {
    const entry = this.cache.get(key);
    if (!entry) return null;

    if (Date.now() > entry.expireAt) {
      this.cache.delete(key);
      return null;
    }

    return entry.response;
  }

  public put(key: string, response: ArrayBuffer) {
    // 简单的 LRU 策略：如果满了，删除第一个（Map 的迭代顺序是插入顺序）
    if (this.cache.size >= this.maxSize) {
      const keys = this.cache.keys();
      const result = keys.next();
      if (!result.done) {
         const firstKey: string = result.value;
         this.cache.delete(firstKey);
      }
    }

    this.cache.set(key, {
      response,
      expireAt: Date.now() + (this.ttl * 1000)
    });
  }

  public getCacheKey(qname: string, qtype: number): string {
    return `${qname}|${qtype}`;
  }
  
  public clear() {
    this.cache.clear();
  }
}
