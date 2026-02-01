import StartTab from './StartTab';
import ConfigTab from './ConfigTab';
import SettingsTab from './SettingsTab';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State @Watch('onIndexChange') currentIndex: number = 0;
  @State bottomSafeHeight: number = 0;
  private controller: TabsController = new TabsController();

  onIndexChange() {
    this.controller.changeIndex(this.currentIndex);
  }

  aboutToAppear(): void {
    window.getLastWindow(getContext(this)).then(currentWindow => {
      let bottom = currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect;
      this.bottomSafeHeight = px2vp(bottom.height);
      AppStorage.setOrCreate('bottomSafeHeight', px2vp(bottom.height));

      let top = currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect;
      AppStorage.setOrCreate('topSafeHeight', px2vp(top.height));

      currentWindow.on('avoidAreaChange', async (data) => {
        if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          this.bottomSafeHeight = px2vp(data.area.bottomRect.height);
          AppStorage.setOrCreate('bottomSafeHeight', px2vp(data.area.bottomRect.height));
        } else if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate('topSafeHeight', px2vp(data.area.topRect.height));
        }
      })
    })
  }

  @Builder
  TabBuilder(title: string, targetIndex: number, selectedImg: Resource, normalImg: Resource) {
    Column() {
      Column() {
        Image(this.currentIndex === targetIndex ? selectedImg : normalImg)
          .size({ width: $r('app.float.icon_size_primary'), height: $r('app.float.icon_size_primary') })
          .objectFit(ImageFit.Contain)
          .fillColor(this.currentIndex === targetIndex ? $r('app.color.brand_color') : $r('app.color.text_secondary'))
        Text(title)
          .fontColor(this.currentIndex === targetIndex ? $r('app.color.brand_color') : $r('app.color.text_secondary'))
          .fontSize($r('app.float.text_size_small'))
          .fontWeight($r('app.integer.font_weight_medium'))
          .margin({ top: $r('app.float.space_xs') })
      }
      .width('100%')
      .height($r('app.float.tab_bar_height'))
      .padding({ top: $r('app.float.tab_bar_padding'), bottom: this.bottomSafeHeight })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(56 + this.bottomSafeHeight)
    .padding({ bottom: this.bottomSafeHeight + 4, top: $r('app.float.tab_bar_padding') })
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor($r('app.color.tab_bar_background'))
    .border({ width: { top: $r('app.float.tab_bar_border_width') }, color: $r('app.color.divider_color') })
    .onClick(() => {
      this.currentIndex = targetIndex;
      this.controller.changeIndex(this.currentIndex);
    })
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
        TabContent() {
          StartTab({ currentIndex: this.currentIndex })
        }
        .tabBar(this.TabBuilder('启动', 0, $r('app.media.ic_home_filled'), $r('app.media.ic_home')))

        TabContent() {
          ConfigTab()
        }
        .tabBar(this.TabBuilder('DNS', 1, $r('app.media.ic_dns_filled'), $r('app.media.ic_dns')))

        TabContent() {
          SettingsTab()
        }
        .tabBar(this.TabBuilder('设置', 2, $r('app.media.ic_settings_filled'), $r('app.media.ic_settings')))
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
