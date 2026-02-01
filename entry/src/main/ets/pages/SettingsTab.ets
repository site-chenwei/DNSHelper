import { router } from '@kit.ArkUI';
import { SettingsItem, CommonNavigationTitle } from '../component/CommonComponents';
import { DnsInfo } from '../model/DnsInfo';
import { AppStorageV2 } from '@kit.ArkUI';

@ComponentV2
export default struct SettingsTab {
  @Local topSafeHeight: number = AppStorageV2.connect(Number, 'topSafeHeight', () => 0)!;
  @Local bottomSafeHeight: number = AppStorageV2.connect(Number, 'bottomSafeHeight', () => 0)!;
  @Local backupDnsList: DnsInfo[] = AppStorageV2.connect(Array, 'backupDnsList', () => [])!;
  @Local currentBackupDnsId: string = AppStorageV2.connect(String, 'currentBackupDnsId', () => '')!;
  @Local navPathStack: NavPathStack = AppStorageV2.connect(NavPathStack, 'navPathStack', () => new NavPathStack())!;

  getBackupDnsSummary(): string {
    if (!this.backupDnsList || this.backupDnsList.length === 0) {
      return '未配置';
    }
    const selected = this.backupDnsList.find(d => d.id === this.currentBackupDnsId);
    if (selected) {
      return selected.name;
    }
    // Fallback if ID not found but list has items
    if (this.backupDnsList.length > 0) {
       return this.backupDnsList[0].name;
    }
    return '未配置';
  }

  @Builder
  NavigationTitle() {
    CommonNavigationTitle({ title: '设置' })
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        this.NavigationTitle()
      }
      .width('100%')
      .padding({ top: this.topSafeHeight })
      .backgroundColor($r('app.color.tab_bar_background'))

      List({ space: 12 }) {
        HdsListItemCard({
          onClick: () => {
            this.navPathStack.pushPath({ name: 'BackupDnsPage' });
          }
        }) {
          SettingsItem({
            title: '备用服务器',
            value: this.getBackupDnsSummary(),
            showArrow: true
          })
        }

        ListItem() {
           Text('当主服务器解析失败时会使用备用服务器进行解析')
             .fontSize($r('app.float.text_size_micro'))
             .fontColor($r('app.color.text_tertiary'))
             .width('100%')
             .padding({ left: $r('app.float.space_lg'), right: $r('app.float.space_lg') })
         }

        HdsListItemCard({
          onClick: () => {
            this.navPathStack.pushPath({ name: 'VersionInfoPage' });
          }
        }) {
          SettingsItem({
            title: '关于',
            showArrow: true
          })
        }
      }
      .padding({ left: $r('app.float.space_lg'), right: $r('app.float.space_lg'), top: $r('app.float.space_lg'), bottom: $r('app.float.space_lg') })
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }
}
