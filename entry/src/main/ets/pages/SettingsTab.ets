
@Component
export default struct SettingsTab {
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Text('设置')
          .fontSize($r('app.float.text_size_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height(44)
      .margin({ top: 10, bottom: 10 })

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
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topSafeHeight })
    .backgroundColor($r('app.color.page_grouped_background'))
  }
}
