import { HdsNavDestination } from '../component/HdsComponents';
import { AppStorageV2 } from '@kit.ArkUI';

@ComponentV2
export default struct VersionInfoPage {
  @Local appName: string = 'DNS助手';
  @Local versionName: string = '1.0.0';

  build() {
    HdsNavDestination({ title: '关于' }) {
      Column() {
        Blank().height(60)

        Image($r('app.media.icon_modern'))
          .width($r('app.float.app_icon_size_large'))
          .height($r('app.float.app_icon_size_large'))
          .borderRadius(16)
          .margin({ bottom: $r('app.float.space_lg') })

        Text(this.appName)
          .fontSize($r('app.float.text_size_large_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: $r('app.float.space_sm') })

        Text(`Version ${this.versionName}`)
          .fontSize($r('app.float.text_size_body'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ bottom: $r('app.float.space_huge') })

      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
    }
  }
}
