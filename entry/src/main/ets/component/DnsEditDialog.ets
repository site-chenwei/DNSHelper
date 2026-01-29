import { DnsInfo, DnsType } from '../model/DnsInfo';

interface DropdownOption {
  value: ResourceStr;
  icon?: ResourceStr;
}

@CustomDialog
export default struct DnsEditDialog {
  controller: CustomDialogController;
  onConfirm: (dns: DnsInfo) => void = () => {};
  
  @State name: string = '';
  @State primaryDns: string = '';
  @State selectedType: DnsType = DnsType.PURE;

  build() {
    Column() {
      Text('添加 DNS 服务')
        .fontSize($r('app.float.text_size_title'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 20 })

      TextInput({ placeholder: '服务名称', text: this.name })
        .onChange((value: string) => {
          this.name = value;
        })
        .margin({ bottom: 12 })
        .width('90%')

      Row() {
        Text('类型：')
          .fontSize($r('app.float.text_size_body'))
        Select(Object.values(DnsType).map((value: string): DropdownOption => {
          return { value: value };
        }))
          .selected(Object.values(DnsType).indexOf(this.selectedType))
          .value(this.selectedType)
          .font({ size: $r('app.float.text_size_body') })
          .selectedOptionFont({ size: $r('app.float.text_size_body') })
          .optionFont({ size: $r('app.float.text_size_body') })
          .onSelect((index: number, value: string) => {
            this.selectedType = value as DnsType;
          })
          .height(40)
          .layoutWeight(1)
      }
      .width('90%')
      .margin({ bottom: 12 })
      .justifyContent(FlexAlign.Start)

      TextInput({ placeholder: 'DNS', text: this.primaryDns })
        .onChange((value: string) => {
          this.primaryDns = value;
        })
        .margin({ bottom: 20 })
        .width('90%')

      Row() {
        Button('取消')
          .onClick(() => {
            this.controller.close();
          })
          .backgroundColor(Color.White)
          .fontColor($r('app.color.text_secondary'))
          .width('40%')
          .margin({ right: 10 })

        Button('确定')
          .onClick(() => {
            if (this.name && this.primaryDns) {
              const dns = new DnsInfo(this.name, this.primaryDns, false, this.selectedType);
              this.onConfirm(dns);
              this.controller.close();
            }
          })
          .width('40%')
      }
      .margin({ bottom: 20 })
    }
    .backgroundColor($r('app.color.page_background'))
    .borderRadius(12)
    .width('90%')
  }
}
