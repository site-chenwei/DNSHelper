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

  getDnsTypeColor(type: string): ResourceColor {
    switch (type) {
      case DnsType.UDP:
        return '#0A59F7'; // 活力蓝
      case DnsType.DOQ:
        return '#F76560'; // 珊瑚红
      case DnsType.DOH:
        return '#13C2C2'; // 明亮青
      case DnsType.DOT:
        return '#722ED1'; // 优雅紫
      default:
        return '#0A59F7';
    }
  }

  getDnsTypeBgColor(type: string): ResourceColor {
    switch (type) {
      case DnsType.UDP:
        return '#E6F7FF'; // 浅蓝背景
      case DnsType.DOQ:
        return '#FFF1F0'; // 浅红背景
      case DnsType.DOH:
        return '#E6FFFB'; // 浅青背景
      case DnsType.DOT:
        return '#F9F0FF'; // 浅紫背景
      default:
        return '#E6F7FF';
    }
  }

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

  @Builder
  NavigationTitle() {
    Row() {
      Text('DNS列表')
        .fontSize($r('app.float.text_size_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }
    .padding({ left: 16 })
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  /*@Builder
  NavigationMenus() {
    Row() {
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
      .padding({ right: 16 })
    }
    .height('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }*/
  @Builder
  NavigationMenus() {
    Row() {
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
      .padding({ right: 16 })
    }
    .height('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Navigation() {
      Column() {
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
                          .fontColor(this.getDnsTypeColor(item.type || DnsType.UDP))
                          .backgroundColor(this.getDnsTypeBgColor(item.type || DnsType.UDP))
                          .padding({
                            left: 6,
                            right: 6
                          })
                          .textVerticalAlign(TextVerticalAlign.CENTER)
                          .height(16)
                          .borderRadius(4)
                          .margin({ left: 8 })
                      }
                      .alignItems(VerticalAlign.Center)

                      Text(item.primaryDns)
                      .fontSize($r('app.float.text_size_small'))
                      .fontColor($r('app.color.text_secondary'))
                      .margin({ top: 6 })
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .maxLines(1)
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
        .padding({ top: 16, left: 16, right: 16 })
        .margin({ top: 10 })
        .backgroundColor($r('app.color.start_window_background'))
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.start_window_background'))
    }
    .title(this.NavigationTitle())
    .titleMode(NavigationTitleMode.Mini)
    .menus(this.NavigationMenus())
    .width('100%')
    .height('100%')
    .padding({ top: this.topSafeHeight })
    .hideBackButton(true)
    .backgroundColor($r('app.color.tab_bar_background'))
  }
}
