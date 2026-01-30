@Component
export default struct SettingsTab {
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;

  @Builder
  NavigationTitle() {
    Row() {
      Text('设置')
        .fontSize($r('app.float.text_size_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 16 })
  }

  build() {
    Column() {
      Navigation() {
        Column() {
          Image($r('app.media.startIcon')) // Placeholder icon if available, or just text
            .width(100)
            .height(100)
            .opacity(0.1)
            .margin({ bottom: 20 })

          Text('暂无设置项')
            .fontSize($r('app.float.text_size_body'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.start_window_background'))
      }
      .title(this.NavigationTitle())
      .titleMode(NavigationTitleMode.Mini)
      .hideBackButton(true)
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.tab_bar_background'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.tab_bar_background'))
    .padding({ top: this.topSafeHeight })
  }
}
