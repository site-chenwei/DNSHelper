
import { DEFAULT_DNS_LIST, DnsInfo, DnsType } from '../model/DnsInfo';
import { DnsDataManager } from '../utils/DnsDataManager';
import { promptAction, router } from '@kit.ArkUI';

@Component
export default struct ConfigTab {
  @StorageLink('dnsList') dnsList: DnsInfo[] = [];
  @StorageLink('currentDnsId') currentDnsId: string = '';
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  // 记录当前处于左滑打开状态的 item ID
  @State swipingItemId: string = '';

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
        Text('DNS 列表')
          .fontSize($r('app.float.text_size_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        
        Row() {
          Blank()
          Button() {
            Image($r('app.media.ic_add'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.brand_color'))
          }
          .onClick(() => {
            router.pushUrl({ url: 'pages/DnsEditPage' });
          })
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
            Row() {
              // 选择按钮区域
              Column() {
                Radio({ value: item.id, group: 'dnsGroup' })
                  .checked(item.id === this.currentDnsId)
                  .radioStyle({ checkedBackgroundColor: $r('app.color.brand_color') })
                  .onChange((isChecked: boolean) => {
                    if (isChecked) {
                      DnsDataManager.getInstance().setCurrentDnsId(item.id);
                    }
                  })
              }
              .justifyContent(FlexAlign.Center)
              .padding({ left: 16, right: 8 })

              // 内容区域
              Column() {
                Row() {
                  Column() {
                    Row() {
                      Text(item.name)
                        .fontSize($r('app.float.text_size_body'))
                        .fontColor($r('app.color.text_primary'))
                        .fontWeight(FontWeight.Medium)

                      Text(item.type || DnsType.UDP)
                        .fontSize($r('app.float.text_size_micro'))
                        .fontColor($r('app.color.text_secondary'))
                        .backgroundColor($r('app.color.badge_background'))
                        .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                        .borderRadius(4)
                        .margin({ left: 8 })
                    }
                    .alignItems(VerticalAlign.Center)

                    Text(item.primaryDns)
                      .fontSize($r('app.float.text_size_small'))
                      .fontColor($r('app.color.text_secondary'))
                      .margin({ top: 6 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  
                  if (!item.isDefault && this.swipingItemId !== item.id) {
                    Image($r('app.media.ic_public_edit'))
                      .width(20)
                      .height(20)
                      .fillColor($r('app.color.icon_secondary'))
                      .onClick(() => {
                        router.pushUrl({
                          url: 'pages/DnsEditPage',
                          params: {
                            id: item.id
                          }
                        })
                      })
                      .padding({ left: 4 }) // Adjust padding for icon
                  }
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
              }
              .layoutWeight(1)
              .padding({ top: 16, bottom: 16, right: 16 })
              .justifyContent(FlexAlign.Center)
            }
            .width('100%')
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
            .onClick(() => {
              // 点击整个卡片（非删除区）切换选中
              DnsDataManager.getInstance().setCurrentDnsId(item.id);
            })
          }
          .swipeAction({ 
            end: {
              builder: this.DeleteButton(item.id),
              onStateChange: (state: SwipeActionState) => {
                if (state === SwipeActionState.EXPANDED) {
                  this.swipingItemId = item.id;
                } else if (state === SwipeActionState.COLLAPSED) {
                  if (this.swipingItemId === item.id) {
                    this.swipingItemId = '';
                  }
                }
              }
            }
          })
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
