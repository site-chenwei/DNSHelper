import { DnsInfo, DnsType } from '../model/DnsInfo';
import { router } from '@kit.ArkUI';
import { DnsDataManager } from '../utils/DnsDataManager';
import { promptAction } from '@kit.ArkUI';
import { CommonNavigationTitle, InputCell, SelectCell, SwitchCell } from '../component/CommonComponents';
import { Validator } from '../utils/UiUtils';

@Entry
@Component
struct DnsEditPage {
  @State name: string = '';
  @State primaryDns: string = '';
  @State selectedType: DnsType = DnsType.UDP;
  @State preferHttp3: boolean = false;
  @State isEditMode: boolean = false;
  @State isBackupMode: boolean = false;
  @State currentId: string = '';
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;

  async aboutToAppear() {
    DnsDataManager.getInstance().init(getContext(this));
    const params = router.getParams() as Record<string, Object>;

    if (params) {
      if (params['isBackup']) {
        this.isBackupMode = params['isBackup'] as boolean;
      }

      if (params['id']) {
        this.isEditMode = true;
        this.currentId = params['id'] as string;

        let list: DnsInfo[] = [];
        if (this.isBackupMode) {
          list = DnsDataManager.getInstance().getBackupDnsList();
        } else {
          list = DnsDataManager.getInstance().getDnsList();
        }

        const dns = list.find(d => d.id === this.currentId);
        if (dns) {
          this.name = dns.name;
          this.primaryDns = dns.primaryDns;
          this.selectedType = dns.type || DnsType.UDP;
          this.preferHttp3 = dns.preferHttp3 || false;
        }
      } else if (this.isBackupMode) {
        // 添加模式且是备用 DNS，默认选中 UDP
        this.selectedType = DnsType.UDP;
      }
    }
  }

  async save() {
    if (this.name && this.primaryDns) {
      if (!Validator.isValidIp(this.primaryDns, this.selectedType)) {
        promptAction.showToast({ message: 'DNS 格式不正确' });
        return;
      }

      if (this.isEditMode) {
        const dns = new DnsInfo(this.name, this.primaryDns, false, this.selectedType, this.preferHttp3);
        if (this.isBackupMode) {
          await DnsDataManager.getInstance().updateBackupDns(dns, this.currentId);
        } else {
          await DnsDataManager.getInstance().updateDns(dns, this.currentId);
        }
        promptAction.showToast({ message: '修改成功' });
      } else {
        const dns = new DnsInfo(this.name, this.primaryDns, false, this.selectedType, this.preferHttp3);
        if (this.isBackupMode) {
          await DnsDataManager.getInstance().addBackupDns(dns);
        } else {
          await DnsDataManager.getInstance().addDns(dns);
        }
        promptAction.showToast({ message: '添加成功' });
      }
      router.back();
    } else {
      promptAction.showToast({ message: '请填写完整信息' });
    }
  }

  @Builder
  NavigationTitle() {
    CommonNavigationTitle({ title: this.isEditMode ? '编辑 DNS' : '添加 DNS' })
  }

  @Builder
  NavigationMenus() {
    Row() {
      Button('完成')
        .onClick(() => this.save())
        .fontSize($r('app.float.text_size_body'))
        .fontColor($r('app.color.brand_color'))
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
        List() {
          ListItem() {
            Column() {
              InputCell({
                title: '名称',
                placeholder: '请输入服务名称',
                value: $name
              })
              Divider()
                .color($r('app.color.divider_color'))
                .strokeWidth(0.5)
                .padding({ left: 16 })

              if (!this.isBackupMode) {
                SelectCell({
                  title: '类型',
                  value: this.selectedType,
                  options: Object.values(DnsType),
                  onSelect: (value) => this.selectedType = value as DnsType
                })

                if (this.selectedType === DnsType.DOH) {
                  Divider()
                    .color($r('app.color.divider_color'))
                    .strokeWidth(0.5)
                    .padding({ left: 16 })
                  SwitchCell({
                    title: '优先使用 HTTP/3',
                    isOn: $preferHttp3
                  })
                }
              } else {
                SelectCell({
                  title: '类型',
                  value: 'UDP',
                  options: ['UDP'],
                  onSelect: () => {}
                })
              }

              Divider()
                .color($r('app.color.divider_color'))
                .strokeWidth(0.5)
                .padding({ left: 16 })

              InputCell({
                title: 'DNS',
                placeholder: '请输入DNS地址',
                value: $primaryDns
              })
            }
            .width('100%')
            .borderRadius(12)
            .clip(true)
            .backgroundColor($r('app.color.card_background'))
          }
          .padding({ left: 16, right: 16 })
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ top: 16 })
        .padding({ bottom: 16 })
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
    .backgroundColor($r('app.color.tab_bar_background'))
    .padding({ top: this.topSafeHeight })
  }
}
