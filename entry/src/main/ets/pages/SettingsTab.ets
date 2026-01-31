import { router } from '@kit.ArkUI';
import { SettingsItem, CommonNavigationTitle } from '../component/CommonComponents';
import { DnsInfo } from '../model/DnsInfo';

@Component
export default struct SettingsTab {
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @StorageLink('backupDnsList') backupDnsList: DnsInfo[] = [];
  @StorageLink('currentBackupDnsId') currentBackupDnsId: string = '';

  getBackupDnsSummary(): string {
    if (!this.backupDnsList || this.backupDnsList.length === 0) {
      return '未配置';
    }
    const selected = this.backupDnsList.find(d => d.id === this.currentBackupDnsId);
    if (selected) {
      return selected.name;
    }
    return this.backupDnsList[0].name;
  }

  build() {
    Navigation() {
      Column() {
        List({ space: 12 }) {
          ListItem() {
            SettingsItem({
              title: '备用服务器配置',
              value: this.getBackupDnsSummary(),
              onClickHandler: () => {
                router.pushUrl({ url: 'pages/BackupDnsPage' });
              }
            })
          }
          ListItem() {
             Text('当主服务器解析失败时会使用备用服务器进行解析')
               .fontSize($r('app.float.text_size_micro'))
               .fontColor($r('app.color.text_tertiary'))
               .width('100%')
               .padding({ left: 16, right: 16 })
           }
          ListItem() {
            SettingsItem({
              title: '关于',
              onClickHandler: () => {
                router.pushUrl({ url: 'pages/VersionInfoPage' });
              }
            })
          }
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor($r('app.color.start_window_background'))
    }
    .title(() => {
      CommonNavigationTitle({ title: '设置' })
    })
    .titleMode(NavigationTitleMode.Mini)
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.tab_bar_background'))
    .padding({ top: this.topSafeHeight })
  }
}
