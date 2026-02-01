import { DnsInfo, DnsType } from '../model/DnsInfo';
import { DnsDataManager } from '../utils/DnsDataManager';
import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { DnsTag } from '../component/CommonComponents';
import { HdsListItemCard } from '../component/HdsComponents';

@ComponentV2
export default struct ConfigTab {
  @Local dnsList: DnsInfo[] = AppStorageV2.connect(Array, 'dnsList', () => [])!;
  @Local selectedDnsIds: string[] = AppStorageV2.connect(Array, 'selectedDnsIds', () => [])!;
  @Local topSafeHeight: number = AppStorageV2.connect(Number, 'topSafeHeight', () => 0)!;
  @Local bottomSafeHeight: number = AppStorageV2.connect(Number, 'bottomSafeHeight', () => 0)!;
  @Local navPathStack: NavPathStack = AppStorageV2.connect(NavPathStack, 'navPathStack', () => new NavPathStack())!;

  async aboutToAppear() {
    await DnsDataManager.getInstance().init(getContext(this));
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('DNS 配置')
          .fontSize($r('app.float.text_size_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        
        Blank()

        Image($r('app.media.ic_public_add'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.brand_color'))
          .onClick(() => {
            this.navPathStack.pushPath({ name: 'DnsEditPage', param: { isBackup: false } });
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: $r('app.float.space_lg'), right: $r('app.float.space_lg') })
      .margin({ top: this.topSafeHeight })

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
      .padding({ left: $r('app.float.space_lg'), right: $r('app.float.space_lg'), top: $r('app.float.space_sm')})
      .alignItems(VerticalAlign.Center)

      List({ space: 12 }) {
        ForEach(this.dnsList, (item: DnsInfo) => {
          HdsListItemCard({
            onClick: () => {
              DnsDataManager.getInstance().toggleDnsId(item.id);
            }
          }) {
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
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  if (!item.isDefault) {
                    Column() {
                      Image($r('app.media.ic_public_delete'))
                        .width($r('app.float.icon_size_secondary'))
                        .height($r('app.float.icon_size_secondary'))
                        .fillColor($r('app.color.functional_red'))
                        .onClick(() => {
                          promptAction.showDialog({
                            title: '删除确认',
                            message: `确定要删除 ${item.name} 吗？`,
                            buttons: [
                              { text: '取消', color: '#000000' },
                              { text: '删除', color: '#FF0000' }
                            ]
                          }).then((resp) => {
                            if (resp.index === 1) {
                              DnsDataManager.getInstance().deleteDns(item.id);
                            }
                          });
                        })
                    }
                  }
                  .alignItems(VerticalAlign.Center)
                }
              }
              .width('100%')
              .padding({ top: $r('app.float.space_lg'), bottom: $r('app.float.space_lg'), right: $r('app.float.space_lg') })
            }
            .width('100%')
          }
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
}
