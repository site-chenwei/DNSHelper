
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
    Button() {
      Text('删除')
        .fontColor(Color.White)
        .fontSize(12)
    }
    .width(60)
    .height(40)
    .type(ButtonType.Normal)
    .borderRadius(20)
    .backgroundColor(Color.Red)
    .margin({ left: 10 })
    .onClick(async () => {
      await DnsDataManager.getInstance().removeDns(id);
      promptAction.showToast({ message: '删除成功' });
    })
  }

  build() {
    Column() {
      Row() {
        Text('配置页')
          .fontSize($r('app.float.text_size_large_title'))
          .fontWeight(FontWeight.Bold)
        
        Blank()

        Button('添加')
          .onClick(() => {
            router.pushUrl({ url: 'pages/DnsEditPage' });
          })
          .fontSize($r('app.float.text_size_sub_title'))
          .fontColor($r('app.color.brand_color'))
          .backgroundColor(Color.Transparent)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 20 })
      .alignItems(VerticalAlign.Center)

      List({ space: 10 }) {
        ForEach(this.dnsList, (item: DnsInfo) => {
          ListItem() {
            Column() {
              Row() {
                Text(item.name)
                  .fontSize($r('app.float.text_size_sub_title'))
                  .fontColor($r('app.color.text_primary'))
                  .fontWeight(500)

                Text(item.type || DnsType.PURE)
                  .fontSize($r('app.float.text_size_micro'))
                  .fontColor($r('app.color.text_secondary'))
                  .backgroundColor($r('app.color.start_window_background'))
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .borderRadius(4)
                  .margin({ left: 8 })

                if (item.isDefault) {
                  Text('默认')
                    .fontSize($r('app.float.text_size_micro'))
                    .fontColor($r('app.color.brand_color'))
                    .backgroundColor($r('app.color.start_window_background'))
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(4)
                    .margin({ left: 8 })
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.Start)

              Row() {
                Text('主: ' + item.primaryDns)
                  .fontSize($r('app.float.text_size_small'))
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ right: 16 })
                if (item.secondaryDns) {
                  Text('备: ' + item.secondaryDns)
                    .fontSize($r('app.float.text_size_small'))
                    .fontColor($r('app.color.text_secondary'))
                }
              }
              .width('100%')
              .margin({ top: 4 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.start_window_background'))
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
        }, (item: DnsInfo) => item.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topSafeHeight })
  }
}
