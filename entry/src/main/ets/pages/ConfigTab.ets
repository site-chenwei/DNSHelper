
import { DEFAULT_DNS_LIST, DnsInfo, DnsType } from '../model/DnsInfo';
import { DnsDataManager } from '../utils/DnsDataManager';
import { promptAction, router } from '@kit.ArkUI';

@Component
export default struct ConfigTab {
  @StorageLink('dnsList') dnsList: DnsInfo[] = [];
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;

  async aboutToAppear() {
    await DnsDataManager.getInstance().init(getContext(this));
  }

  @Builder
  DeleteButton(id: string) {
    Row() {
      Text('删除')
        .fontColor(Color.White)
        .fontSize(16)
    }
    .width(80)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.functional_red'))
    .onClick(async () => {
      await DnsDataManager.getInstance().removeDns(id);
      promptAction.showToast({ message: '删除成功' });
    })
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Text('配置列表')
          .fontSize($r('app.float.text_size_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        
        Row() {
          Blank()
          Button('添加')
            .onClick(() => {
              router.pushUrl({ url: 'pages/DnsEditPage' });
            })
            .fontSize($r('app.float.text_size_body'))
            .fontColor($r('app.color.brand_color'))
            .backgroundColor(Color.Transparent)
            .padding({ right: 0 })
        }
        .width('100%')
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .margin({ top: 10, bottom: 10 })

      List({ space: 12 }) {
        ForEach(this.dnsList, (item: DnsInfo) => {
          ListItem() {
            Column() {
              Row() {
                Text(item.name)
                  .fontSize($r('app.float.text_size_body'))
                  .fontColor($r('app.color.text_primary'))
                  .fontWeight(FontWeight.Medium)

                if (item.isDefault) {
                  Text('默认')
                    .fontSize($r('app.float.text_size_micro'))
                    .fontColor($r('app.color.brand_color'))
                    .backgroundColor($r('app.color.badge_background'))
                    .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                    .borderRadius(4)
                    .margin({ left: 8 })
                }

                Text(item.type || DnsType.UDP)
                  .fontSize($r('app.float.text_size_micro'))
                  .fontColor($r('app.color.text_secondary'))
                  .backgroundColor($r('app.color.badge_background'))
                  .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                  .borderRadius(4)
                  .margin({ left: 8 })
                
                Blank()
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Row() {
                Text(item.primaryDns)
                  .fontSize($r('app.float.text_size_small'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .margin({ top: 6 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
            .alignItems(HorizontalAlign.Start)
            .onClick(() => {
              if (item.isDefault) {
                promptAction.showToast({ message: '默认DNS服务不支持编辑' });
              } else {
                router.pushUrl({
                  url: 'pages/DnsEditPage',
                  params: {
                    id: item.id
                  }
                })
              }
            })
          }
          .swipeAction({ end: this.DeleteButton(item.id) })
          .clip(true)
          .borderRadius(12)
        }, (item: DnsInfo) => item.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_grouped_background'))
    .padding({ top: this.topSafeHeight })
  }
}
