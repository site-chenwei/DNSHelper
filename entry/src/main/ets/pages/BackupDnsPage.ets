import { DnsInfo, DnsType } from '../model/DnsInfo';
import { DnsDataManager } from '../utils/DnsDataManager';
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { DnsTag } from '../component/CommonComponents';
import { HdsNavDestination, HdsListItemCard } from '../component/HdsComponents';

@ComponentV2
export default struct BackupDnsPage {
  @Local backupDnsList: DnsInfo[] = AppStorageV2.connect(Array, 'backupDnsList', () => [])!;
  @Local currentBackupDnsId: string = AppStorageV2.connect(String, 'currentBackupDnsId', () => '')!;
  @Local navPathStack: NavPathStack = AppStorageV2.connect(NavPathStack, 'navPathStack', () => new NavPathStack())!;

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
        this.navPathStack.pushPath({
          name: 'DnsEditPage',
          param: { isBackup: true }
        });
      })
      .backgroundColor(Color.Transparent)
      .padding({ right: $r('app.float.space_lg') })
    }
    .height('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    HdsNavDestination({ title: '备用 DNS', menus: this.NavigationMenus }) {
      if (this.backupDnsList.length === 0) {
        Column() {
          Image($r('app.media.ic_dns'))
            .width($r('app.float.empty_icon_size'))
            .height($r('app.float.empty_icon_size'))
            .opacity(0.1)
            .margin({ bottom: $r('app.float.space_xl') })
          Text('暂无备用 DNS')
            .fontSize($r('app.float.text_size_body'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.backupDnsList, (item: DnsInfo) => {
            HdsListItemCard({
              onClick: () => {
                DnsDataManager.getInstance().setCurrentBackupDnsId(item.id);
              }
            }) {
              Row() {
                Radio({ value: item.id, group: 'backupDnsGroup' })
                  .checked(item.id === this.currentBackupDnsId)
                  .radioStyle({ checkedBackgroundColor: $r('app.color.brand_color') })
                  .onChange((isChecked: boolean) => {
                    if (isChecked) {
                      DnsDataManager.getInstance().setCurrentBackupDnsId(item.id);
                    }
                  })
                  .margin({ right: $r('app.float.space_md') })

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
                  .margin({ bottom: $r('app.float.space_xs') })

                  Text(item.primaryDns)
                    .fontSize($r('app.float.text_size_small'))
                    .fontColor($r('app.color.text_secondary'))
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (!item.isDefault && item.id !== this.currentBackupDnsId) {
                  Row() {
                    Image($r('app.media.ic_public_edit'))
                      .width($r('app.float.icon_size_secondary'))
                      .height($r('app.float.icon_size_secondary'))
                      .fillColor($r('app.color.brand_color'))
                      .onClick(() => {
                        this.navPathStack.pushPath({
                          name: 'DnsEditPage',
                          param: {
                            id: item.id,
                            isBackup: true
                          }
                        });
                      })
                    
                    Image($r('app.media.ic_public_delete'))
                      .width($r('app.float.icon_size_secondary'))
                      .height($r('app.float.icon_size_secondary'))
                      .fillColor($r('app.color.functional_red'))
                      .margin({ left: $r('app.float.space_lg') })
                      .onClick(async () => {
                        await DnsDataManager.getInstance().removeBackupDns(item.id);
                        promptAction.showToast({ message: '删除成功' });
                      })
                  }
                }
              }
            }
          }, (item: DnsInfo) => item.id + '_' + (item.id === this.currentBackupDnsId ? 'selected' : 'unselected'))
        }
        .width('100%')
        .height('100%')
      }
    }
  }
}
