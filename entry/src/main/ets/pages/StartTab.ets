
@Component
export default struct StartTab {
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;

  build() {
    Column() {
      Text('启动页')
        .fontSize($r('app.float.text_size_large_title'))
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topSafeHeight })
    .justifyContent(FlexAlign.Center)
  }
}
