import StartTab from './StartTab';
import ConfigTab from './ConfigTab';
import SettingsTab from './SettingsTab';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State bottomSafeHeight: number = 0;
  private controller: TabsController = new TabsController();

  aboutToAppear(): void {
    window.getLastWindow(getContext(this)).then(currentWindow => {
      let bottom = currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect;
      this.bottomSafeHeight = px2vp(bottom.height);

      let top = currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect;
      AppStorage.setOrCreate('topSafeHeight', px2vp(top.height));

      currentWindow.on('avoidAreaChange', async (data) => {
        if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          this.bottomSafeHeight = px2vp(data.area.bottomRect.height);
        } else if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate('topSafeHeight', px2vp(data.area.topRect.height));
        }
      })
    })
  }

  @Builder
  TabBuilder(title: string, targetIndex: number, selectedImg: Resource, normalImg: Resource) {
    Column() {
      Image(this.currentIndex === targetIndex ? selectedImg : normalImg)
        .size({ width: 24, height: 24 })
        .objectFit(ImageFit.Contain)
      Text(title)
        .fontColor(this.currentIndex === targetIndex ? $r('app.color.brand_color') : $r('app.color.text_secondary'))
        .fontSize($r('app.float.text_size_small'))
        .fontWeight(500)
    }
    .width('100%')
    .height(56 + this.bottomSafeHeight)
    .padding({ bottom: this.bottomSafeHeight + 5, top: 5 })
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor($r('app.color.tab_bar_background'))
    .border({ width: { top: 0.5 }, color: $r('app.color.divider_color') })
    .onClick(() => {
      this.currentIndex = targetIndex;
      this.controller.changeIndex(this.currentIndex);
    })
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
        TabContent() {
          StartTab()
        }
        .tabBar(this.TabBuilder('启动', 0, $r('app.media.startIcon'), $r('app.media.startIcon')))

        TabContent() {
          ConfigTab()
        }
        .tabBar(this.TabBuilder('配置', 1, $r('app.media.startIcon'), $r('app.media.startIcon')))

        TabContent() {
          SettingsTab()
        }
        .tabBar(this.TabBuilder('设置', 2, $r('app.media.startIcon'), $r('app.media.startIcon')))
      }
      .scrollable(false)
      .barMode(BarMode.Fixed)
      .barHeight(56 + this.bottomSafeHeight)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
