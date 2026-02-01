import { DnsInfo, DnsType } from '../model/DnsInfo';
import { DnsDataManager } from '../utils/DnsDataManager';
import { promptAction, router } from '@kit.ArkUI';
import { DnsTag, CommonNavigationTitle } from '../component/CommonComponents';

@Component
export default struct ConfigTab {
  @StorageLink('dnsList') dnsList: DnsInfo[] = [];
  @StorageLink('selectedDnsIds') selectedDnsIds: string[] = [];
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;

  async aboutToAppear() {
    await DnsDataManager.getInstance().init(getContext(this));
  }

  @Builder
  NavigationTitle() {
    CommonNavigationTitle({ title: 'DNS列表' })
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
      .padding({ right: $r('app.float.space_lg') })
    }
    .height('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Navigation() {
      Column() {
        Row() {
          Image($r('app.media.ic_dns_filled'))
            .width(16)
            .height(16)
            .fillColor($r('app.color.text_secondary'))
            .margin({ right: $r('app.float.space_sm') })
          Text('支持多选，将并发请求所有选中的DNS服务')
            .fontSize($r('app.float.text_size_small'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .padding({ left: $r('app.float.space_lg'), right: $r('app.float.space_lg'), top: $r('app.float.space_lg')})
        .alignItems(VerticalAlign.Center)

        List({ space: 12 }) {
          ForEach(this.dnsList, (item: DnsInfo) => {
            ListItem() {
              Row() {
                Column() {
                  Checkbox({ name: 'checkbox_' + item.id })
                    .select(this.selectedDnsIds.includes(item.id))
                    .selectedColor($r('app.color.brand_color'))
                    .hitTestBehavior(HitTestMode.None)
                }
                .justifyContent(FlexAlign.Center)
                .padding({ left: $r('app.float.space_lg'), right: $r('app.float.space_sm') })

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
                      .margin({ top: $r('app.float.space_xs') })
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .maxLines(1)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    if (!this.selectedDnsIds.includes(item.id)) {
                      Row() {
                        if (!item.isDefault) {
                          Image($r('app.media.ic_public_edit'))
                            .width($r('app.float.icon_size_secondary'))
                            .height($r('app.float.icon_size_secondary'))
                            .fillColor($r('app.color.brand_color'))
                            .onClick(() => {
                              router.pushUrl({
                                url: 'pages/DnsEditPage',
                                params: {
                                  id: item.id
                                }
                              })
                            })
                            .margin({ right: $r('app.float.space_lg') })
                        }
                        
                        Image($r('app.media.ic_public_delete'))
                          .width($r('app.float.icon_size_secondary'))
                          .height($r('app.float.icon_size_secondary'))
                          .fillColor($r('app.color.functional_red'))
                          .onClick(async () => {
                             await DnsDataManager.getInstance().removeDns(item.id);
                             promptAction.showToast({ message: '删除成功' });
                          })
                      }
                      .padding({ left: $r('app.float.space_xs') })
                    }
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                }
                .layoutWeight(1)
                .padding({ top: $r('app.float.space_lg'), bottom: $r('app.float.space_lg'), right: $r('app.float.space_lg') })
                .justifyContent(FlexAlign.Center)
              }
              .width('100%')
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)
              .onClick(() => {
                // 点击整个卡片（非删除区）切换选中
                DnsDataManager.getInstance().toggleDnsId(item.id);
              })
            }
            .clip(true)
            .borderRadius(12)
          }, (item: DnsInfo) => JSON.stringify(item) + '_' + (this.selectedDnsIds.includes(item.id) ? 'selected' : 'unselected'))
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ top: $r('app.float.space_lg'), left: $r('app.float.space_lg'), right: $r('app.float.space_lg'), bottom: $r('app.float.space_lg') })
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