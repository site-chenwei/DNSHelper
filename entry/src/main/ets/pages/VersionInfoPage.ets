import { router } from '@kit.ArkUI';
import { CommonNavigationTitle } from '../component/CommonComponents';

@Entry
@Component
struct VersionInfoPage {
  @State appName: string = 'DNS助手';
  @State versionName: string = '1.0.0';
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;

  @Builder
  NavigationTitle() {
    CommonNavigationTitle({ title: '关于' })
  }

  build() {
    Navigation() {
      Column() {
        Blank().height(60)

        Image($r('app.media.startIcon'))
          .width($r('app.float.app_icon_size_large'))
          .height($r('app.float.app_icon_size_large'))
          .borderRadius(16)
          .margin({ bottom: 16 })

        Text(this.appName)
          .fontSize($r('app.float.text_size_large_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8 })

        Text(`Version ${this.versionName}`)
          .fontSize($r('app.float.text_size_body'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ bottom: 40 })

      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .backgroundColor($r('app.color.start_window_background'))
    }
    .title(this.NavigationTitle())
    .titleMode(NavigationTitleMode.Mini)
    .backgroundColor($r('app.color.tab_bar_background'))
    .padding({ top: this.topSafeHeight })
  }
}