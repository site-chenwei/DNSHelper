import { DnsInfo, DnsType } from '../model/DnsInfo';
import { DnsDataManager } from '../utils/DnsDataManager';
import { promptAction, router } from '@kit.ArkUI';
import { CommonDeleteButton, CommonNavigationTitle, DnsTag } from '../component/CommonComponents';

@Entry
@Component
struct BackupDnsPage {
  @StorageLink('backupDnsList') backupDnsList: DnsInfo[] = [];
  @StorageLink('currentBackupDnsId') currentBackupDnsId: string = '';
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;

  async aboutToAppear() {
    DnsDataManager.getInstance().init(getContext(this));
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
        router.pushUrl({
          url: 'pages/DnsEditPage',
          params: { isBackup: true }
        });
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
      if (this.backupDnsList.length === 0) {
        Column() {
          Image($r('app.media.ic_dns'))
            .width($r('app.float.empty_icon_size'))
            .height($r('app.float.empty_icon_size'))
            .opacity(0.1)
            .margin({ bottom: 20 })
          Text('暂无备用 DNS')
            .fontSize($r('app.float.text_size_body'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.start_window_background'))
      } else {
        List({ space: 12 }) {
          ForEach(this.backupDnsList, (item: DnsInfo) => {
            ListItem() {
              Row() {
                // 选中状态指示器
                Radio({ value: item.id, group: 'backupDnsGroup' })
                  .checked(item.id === this.currentBackupDnsId)
                  .radioStyle({ checkedBackgroundColor: $r('app.color.brand_color') })
                  .onChange((isChecked: boolean) => {
                    if (isChecked) {
                      DnsDataManager.getInstance().setCurrentBackupDnsId(item.id);
                    }
                  })
                  .margin({ right: 12 })

                Column() {
                  Row() {
                    Text(item.name)
                      .fontSize($r('app.float.text_size_body'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))

                    DnsTag({
                      type: item.type,
                      isDefault: item.isDefault
                    })
                  }
                  .margin({ bottom: 4 })

                  Text(item.primaryDns)
                    .fontSize($r('app.float.text_size_small'))
                    .fontColor($r('app.color.text_secondary'))
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (!item.isDefault) {
                  Image($r('app.media.ic_public_edit'))
                    .width($r('app.float.icon_size_secondary'))
                    .height($r('app.float.icon_size_secondary'))
                    .fillColor($r('app.color.icon_secondary'))
                    .onClick(() => {
                      router.pushUrl({
                        url: 'pages/DnsEditPage',
                        params: {
                          id: item.id,
                          isBackup: true
                        }
                      });
                    })
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)
              .onClick(() => {
                DnsDataManager.getInstance().setCurrentBackupDnsId(item.id);
              })
            }
            .swipeAction(item.isDefault ? undefined : {
              end: () => {
                CommonDeleteButton({
                  onClickHandler: async () => {
                    await DnsDataManager.getInstance().removeBackupDns(item.id);
                    promptAction.showToast({ message: '删除成功' });
                  }
                })
              }
            })
          }, (item: DnsInfo) => item.id)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, top: 16, })
        .backgroundColor($r('app.color.start_window_background'))
      }
    }
    .title(() => {
      CommonNavigationTitle({ title: '备用 DNS' })
    })
    .menus(this.NavigationMenus())
    .titleMode(NavigationTitleMode.Mini)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.tab_bar_background'))
    .padding({ top: this.topSafeHeight })
  }
}