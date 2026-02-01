import { DnsType } from '../model/DnsInfo';
import { UiUtils } from '../utils/UiUtils';

@ComponentV2
export struct SettingsItem {
  @Param title: string = '';
  @Param value: string = '';
  @Param showArrow: boolean = true;
  @Param icon: ResourceStr | undefined = undefined;
  onClickHandler?: () => void;

  build() {
    Row() {
      if (this.icon) {
        Image(this.icon)
          .width($r('app.float.icon_size_secondary'))
          .height($r('app.float.icon_size_secondary'))
          .margin({ right: $r('app.float.space_md') })
          .fillColor($r('app.color.text_primary'))
      }

      Text(this.title)
        .fontSize($r('app.float.text_size_body'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      if (this.value) {
        Text(this.value)
          .fontSize($r('app.float.text_size_small'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ right: $r('app.float.space_xs') })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '50%' })
      }

      if (this.showArrow) {
        Image($r('app.media.ic_arrow_right'))
          .width($r('app.float.icon_size_secondary'))
          .height($r('app.float.icon_size_secondary'))
          .fillColor($r('app.color.icon_secondary'))
      }
    }
    .width('100%')
    .height($r('app.float.list_item_height'))
    .onClick(() => {
      if (this.onClickHandler) this.onClickHandler();
    })
  }
}

@ComponentV2
export struct CommonDeleteButton {
  onClickHandler?: () => void;

  build() {
    Row() {
      Text('删除')
        .fontColor($r('app.color.text_white'))
        .fontSize($r('app.float.text_size_body'))
    }
    .width(80)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.functional_red'))
    .onClick(() => {
      if (this.onClickHandler) this.onClickHandler();
    })
  }
}

@ComponentV2
export struct CommonNavigationTitle {
  @Param title: string = '';

  build() {
    Row() {
      Text(this.title)
        .fontSize($r('app.float.text_size_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: $r('app.float.space_lg') })
  }
}

@ComponentV2
export struct DnsTag {
  @Param type: string = DnsType.UDP;
  @Param isDefault: boolean = false;

  build() {
    Row() {
      Text(this.type)
        .fontSize($r('app.float.text_size_tag'))
        .fontColor(UiUtils.getDnsTypeColor(this.type))
        .backgroundColor(UiUtils.getDnsTypeBgColor(this.type))
        .padding({
          left: $r('app.float.space_xs'),
          right: $r('app.float.space_xs')
        })
        .textVerticalAlign(TextVerticalAlign.CENTER)
        .height(16)
        .borderRadius(4)
        .margin({ left: $r('app.float.space_sm') })

      if (this.isDefault) {
        Text('默认')
          .fontSize($r('app.float.text_size_tag'))
          .fontColor($r('app.color.brand_color'))
          .backgroundColor($r('app.color.status_active_bg'))
          .padding({
            left: $r('app.float.space_xs'),
            right: $r('app.float.space_xs')
          })
          .textVerticalAlign(TextVerticalAlign.CENTER)
          .height(16)
          .borderRadius(4)
          .margin({ left: $r('app.float.space_sm') })
      } else {
        Text('自定义')
          .fontSize($r('app.float.text_size_tag'))
          .fontColor($r('app.color.tag_custom_text'))
          .backgroundColor($r('app.color.tag_custom_bg'))
          .padding({
            left: $r('app.float.space_xs'),
            right: $r('app.float.space_xs')
          })
          .textVerticalAlign(TextVerticalAlign.CENTER)
          .height(16)
          .borderRadius(4)
          .margin({ left: $r('app.float.space_sm') })
      }
    }
    .alignItems(VerticalAlign.Center)
  }
}

@ComponentV2
export struct InputCell {
  @Param title: string = '';
  @Param placeholder: string = '';
  @Param value: string = '';
  @Event onChange: (value: string) => void = () => {};

  build() {
    Row() {
      Text(this.title)
        .width(80)
        .fontSize($r('app.float.text_size_body'))
        .fontColor($r('app.color.text_primary'))

      TextInput({ text: this.value, placeholder: this.placeholder })
        .textAlign(TextAlign.Start)
        .fontSize($r('app.float.text_size_body'))
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_secondary'))
        .backgroundColor(Color.Transparent)
        .height('100%')
        .layoutWeight(1)
        .onChange((val) => {
          this.onChange(val);
        })
    }
    .width('100%')
    .height($r('app.float.list_item_height'))
  }
}

@ComponentV2
export struct SwitchCell {
  @Param title: string = '';
  @Param isOn: boolean = false;
  @Event onChange: (isOn: boolean) => void = () => {};

  build() {
    Row() {
      Text(this.title)
        .fontSize($r('app.float.text_size_body'))
        .fontColor($r('app.color.text_primary'))

      Blank()

      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor($r('app.color.brand_color'))
        .switchPointColor($r('app.color.text_white'))
        .onChange((isOn) => {
          this.onChange(isOn);
        })
    }
    .width('100%')
    .height($r('app.float.list_item_height'))
  }
}

interface DropdownOption {
  value: ResourceStr;
  icon?: ResourceStr;
}

@ComponentV2
export struct SelectCell {
  @Param title: string = '';
  @Param value: string = '';
  @Param options: string[] = [];
  @Event onSelect: (val: string) => void = () => {};

  build() {
    Row() {
      Text(this.title)
        .width(80)
        .fontSize($r('app.float.text_size_body'))
        .fontColor($r('app.color.text_primary'))

      Select(this.options.map((v): DropdownOption => ({ value: v })))
        .selected(this.options.indexOf(this.value))
        .value(this.value)
        .font({ size: $r('app.float.text_size_body') })
        .fontColor($r('app.color.text_primary'))
        .selectedOptionFont({ size: $r('app.float.text_size_body') })
        .selectedOptionFontColor($r('app.color.brand_color'))
        .selectedOptionBgColor($r('app.color.status_active_bg'))
        .optionFont({ size: $r('app.float.text_size_body') })
        .optionFontColor($r('app.color.text_primary'))
        .menuBackgroundColor($r('app.color.card_background'))
        .backgroundColor(Color.Transparent)
        .onSelect((index: number, val: string) => {
          this.onSelect(val);
        })
        .height('100%')
        .layoutWeight(1)
    }
    .width('100%')
    .height($r('app.float.list_item_height'))
  }
}
