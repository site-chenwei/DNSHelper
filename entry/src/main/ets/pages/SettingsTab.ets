
import { DnsCacheManager } from '../utils/DnsCacheManager';
import common from '@ohos.app.ability.common';
import { promptAction } from '@kit.ArkUI';

@Component
export default struct SettingsTab {
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageLink('cacheTTL') cacheTTL: number = 600;
  @StorageLink('cacheSize') cacheSize: number = 100;

  @State inputTTL: string = '';
  @State inputSize: string = '';

  aboutToAppear(): void {
    // 初始化输入框状态
    this.inputTTL = this.cacheTTL.toString();
    this.inputSize = this.cacheSize.toString();
  }

  saveConfig(): void {
    const ttl = parseInt(this.inputTTL);
    const size = parseInt(this.inputSize);
    
    if (!isNaN(ttl) && !isNaN(size) && ttl > 0 && size > 0) {
       DnsCacheManager.getInstance().updateConfig(getContext(this) as common.UIAbilityContext, ttl, size);
       promptAction.showToast({ message: '配置已保存' });
    }
  }

  @Builder
  InputCell(title: string, value: string, onChange: (val: string) => void) {
    Row() {
      Text(title)
        .fontSize($r('app.float.text_size_body'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      TextInput({ text: value })
        .textAlign(TextAlign.End)
        .fontSize($r('app.float.text_size_body'))
        .fontColor($r('app.color.text_secondary'))
        .backgroundColor(Color.Transparent)
        .height('100%')
        .width('50%')
        .type(InputType.Number)
        .onChange(onChange)
    }
    .width('100%')
    .height($r('app.float.list_item_height'))
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  ActionCell(title: string, color: ResourceColor, onClick: () => void) {
    Row() {
      Text(title)
        .fontSize($r('app.float.text_size_body'))
        .fontColor(color)
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .height($r('app.float.list_item_height'))
    .backgroundColor($r('app.color.card_background'))
    .onClick(onClick)
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Text('设置')
          .fontSize($r('app.float.text_size_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height(44)
      .margin({ top: 10, bottom: 10 })

      List() {
        ListItem() {
          Text('DNS 缓存策略')
            .fontSize($r('app.float.text_size_small'))
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 16, bottom: 8 })
        }

        ListItem() {
          Column() {
            this.InputCell('缓存时长 (秒)', this.inputTTL, (value) => this.inputTTL = value)
            Divider()
              .color($r('app.color.divider_color'))
              .strokeWidth(0.5)
              .padding({ left: 16 })
            this.InputCell('缓存容量 (条)', this.inputSize, (value) => this.inputSize = value)
            Divider()
              .color($r('app.color.divider_color'))
              .strokeWidth(0.5)
              .padding({ left: 16 })
            this.ActionCell('保存配置', $r('app.color.brand_color'), () => this.saveConfig())
          }
          .width('100%')
          .borderRadius(12)
          .clip(true)
          .backgroundColor($r('app.color.card_background'))
        }
        .padding({ left: 16, right: 16 })

        ListItem() {
          Column() {
            this.ActionCell('清空缓存', $r('app.color.functional_red'), () => {
              DnsCacheManager.getInstance().clear();
              promptAction.showToast({ message: '缓存已清空' });
            })
          }
          .width('100%')
          .borderRadius(12)
          .clip(true)
          .backgroundColor($r('app.color.card_background'))
          .margin({ top: 20 })
        }
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topSafeHeight })
    .backgroundColor($r('app.color.page_grouped_background'))
  }
}
