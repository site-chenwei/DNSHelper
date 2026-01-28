
import { DnsCacheManager } from '../utils/DnsCacheManager';
import common from '@ohos.app.ability.common';

@Component
export default struct SettingsTab {
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageLink('cacheTTL') cacheTTL: number = 600;
  @StorageLink('cacheSize') cacheSize: number = 100;

  @State inputTTL: string = '';
  @State inputSize: string = '';

  aboutToAppear() {
    DnsCacheManager.getInstance().init(getContext(this) as common.UIAbilityContext);
    this.inputTTL = this.cacheTTL.toString();
    this.inputSize = this.cacheSize.toString();
  }

  saveConfig() {
    const ttl = parseInt(this.inputTTL);
    const size = parseInt(this.inputSize);
    
    if (!isNaN(ttl) && !isNaN(size) && ttl > 0 && size > 0) {
       DnsCacheManager.getInstance().updateConfig(getContext(this) as common.UIAbilityContext, ttl, size);
       // Show toast or hint (omitted for brevity)
    }
  }

  build() {
    Column() {
      Text('设置')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 20, top: 20, bottom: 20 })

      List() {
        ListItem() {
           Column({ space: 10 }) {
             Text('DNS 缓存配置')
               .fontSize(16)
               .fontWeight(FontWeight.Medium)
               .width('100%')
             
             Row() {
               Text('缓存时长 (秒)')
                 .layoutWeight(1)
               TextInput({ text: this.inputTTL })
                 .width(100)
                 .type(InputType.Number)
                 .onChange((value) => this.inputTTL = value)
             }
             .width('100%')

             Row() {
               Text('缓存容量 (条)')
                 .layoutWeight(1)
               TextInput({ text: this.inputSize })
                 .width(100)
                 .type(InputType.Number)
                 .onChange((value) => this.inputSize = value)
             }
             .width('100%')

             Button('保存配置')
               .width('100%')
               .margin({ top: 10 })
               .onClick(() => this.saveConfig())
             
             Button('清空缓存')
               .width('100%')
               .backgroundColor('#FF3B30')
               .margin({ top: 10 })
               .onClick(() => {
                 DnsCacheManager.getInstance().clear();
               })
           }
           .padding(16)
           .backgroundColor(Color.White)
           .borderRadius(16)
        }
        .padding({ left: 20, right: 20 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topSafeHeight })
    .backgroundColor('#F2F2F7')
  }
}
