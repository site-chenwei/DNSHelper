import { AppStorageV2 } from '@kit.ArkUI';

@ComponentV2
export struct HdsNavigation {
  @Param title: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @BuilderParam content: () => void = this.defaultBuilder;
  @BuilderParam navDestination: (name: string, param: Object) => void = this.defaultBuilder;
  @BuilderParam menus: () => void = this.defaultMenusBuilder;

  @Builder defaultBuilder() {}
  @Builder defaultMenusBuilder() {}

  build() {
    Navigation(this.pathStack) {
      this.content()
    }
    .title(this.title)
    .titleMode(NavigationTitleMode.Mini)
    .navDestination(this.navDestination)
    .menus(this.menus)
    .height('100%')
    .width('100%')
    .backgroundColor($r('app.color.page_background'))
    .hideTitleBar(this.title === '')
  }
}

@ComponentV2
export struct HdsNavDestination {
  @Param title: string = '';
  @BuilderParam content: () => void = this.defaultBuilder;
  @BuilderParam menus: () => void = this.defaultMenusBuilder;

  @Builder defaultBuilder() {}
  @Builder defaultMenusBuilder() {}

  build() {
    NavDestination() {
      this.content()
    }
    .title(this.title)
    .menus(this.menus)
    .backgroundColor($r('app.color.page_background'))
  }
}

@ComponentV2
export struct HdsListItemCard {
  @BuilderParam content: () => void = this.defaultBuilder;
  @Event onClick: () => void = () => {};

  @Builder defaultBuilder() {}

  build() {
    ListItem() {
      Column() {
        this.content()
      }
      .width('100%')
      .padding($r('app.float.space_lg'))
      .backgroundColor($r('app.color.card_background'))
      .borderRadius($r('app.float.card_radius'))
    }
    .width('100%')
    .padding({ left: $r('app.float.space_lg'), right: $r('app.float.space_lg'), bottom: $r('app.float.space_md') })
    .onClick(() => {
      this.onClick();
    })
  }
}

@ComponentV2
export struct HdsTabs {
  @BuilderParam content: () => void = this.defaultBuilder;
  @Param controller: TabsController = new TabsController();
  @Event onChange: (index: number) => void = () => {};

  @Builder defaultBuilder() {}

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
      this.content()
    }
    .scrollable(false)
    .barMode(BarMode.Fixed)
    .onChange((index: number) => {
      this.onChange(index);
    })
    .backgroundColor($r('app.color.page_background'))
  }
}
