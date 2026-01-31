import { DEFAULT_DNS_LIST, DnsInfo, DnsType } from '../model/DnsInfo';
import { DnsDataManager } from '../utils/DnsDataManager';
import { promptAction, router } from '@kit.ArkUI';
import { DnsTag, CommonDeleteButton, CommonNavigationTitle } from '../component/CommonComponents';

@Component
export default struct ConfigTab {
  @StorageLink('dnsList') dnsList: DnsInfo[] = [];
  @StorageLink('currentDnsId') currentDnsId: string = '';
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  // 记录当前处于左滑打开状态的 item ID
  @State swipingItemId: string = '';

  async aboutToAppear() {
    await DnsDataManager.getInstance().init(getContext(this));
  }


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

                        DnsTag({
                          type: item.type || DnsType.UDP,
                          isDefault: item.isDefault
                        })
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
                        .width($r('app.float.icon_size_secondary'))
                        .height($r('app.float.icon_size_secondary'))
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
            .swipeAction(item.id === this.currentDnsId ? undefined : {
              end: {
                builder: () => {
                  CommonDeleteButton({
                    onClickHandler: async () => {
                      await DnsDataManager.getInstance().removeDns(item.id);
                      promptAction.showToast({ message: '删除成功' });
                    }
                  })
                },
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
        .padding({ top: 16, left: 16, right: 16, bottom: 16 })
        .backgroundColor($r('app.color.start_window_background'))
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.start_window_background'))
    }
    .title(() => {
      CommonNavigationTitle({ title: 'DNS列表' })
    })
    .titleMode(NavigationTitleMode.Mini)
    .menus(this.NavigationMenus())
    .width('100%')
    .height('100%')
    .padding({ top: this.topSafeHeight })
    .hideBackButton(true)
    .backgroundColor($r('app.color.tab_bar_background'))
  }
}