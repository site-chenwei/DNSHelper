import { DnsInfo, DnsType } from '../model/DnsInfo';
import { SelectOptions, router } from '@kit.ArkUI';
import { DnsDataManager } from '../utils/DnsDataManager';
import { promptAction } from '@kit.ArkUI';

interface DropdownOption {
  value: ResourceStr;
  icon?: ResourceStr;
}

@Entry
@Component
struct DnsEditPage {
  @State name: string = '';
  @State primaryDns: string = '';
  @State secondaryDns: string = '';
  @State selectedType: DnsType = DnsType.PURE;
  @State isEditMode: boolean = false;
  @State currentId: string = '';
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;

  async aboutToAppear() {
    DnsDataManager.getInstance().init(getContext(this));
    const params = router.getParams() as Record<string, Object>;
    if (params && params['id']) {
      this.isEditMode = true;
      this.currentId = params['id'] as string;
      const list = DnsDataManager.getInstance().getDnsList();
      const dns = list.find(d => d.id === this.currentId);
      if (dns) {
        this.name = dns.name;
        this.primaryDns = dns.primaryDns;
        this.secondaryDns = dns.secondaryDns;
        this.selectedType = dns.type || DnsType.PURE;
      }
    }
  }

  build() {
    Column() {
      // 标题栏
      Column() {
        Stack({ alignContent: Alignment.Start }) {
          // 标题
          Text(this.isEditMode ? '编辑 DNS' : '添加 DNS')
            .width('100%')
            .textAlign(TextAlign.Center)
            .fontSize($r('app.float.text_size_large_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          // 返回按钮
          Row() {
            Path()
              .commands('M14 6 L8 12 L14 18')
              .fill(Color.Transparent)
              .stroke($r('app.color.text_primary'))
              .strokeWidth(2)
              .width(12)
              .height(24)
          }
          .width(56)
          .height(56)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            router.back();
          })
          .zIndex(1)
        }
        .height(56)
        .width('100%')
      }
      .width('100%')
      .padding({ top: this.topSafeHeight })
      .backgroundColor($r('app.color.start_window_background'))
      .shadow({ radius: 2, color: '#1a000000', offsetY: 1 })
      .zIndex(10)

      Column() {
        TextInput({ placeholder: '服务名称', text: this.name })
          .onChange((value: string) => {
            this.name = value;
          })
          .margin({ bottom: 12 })
          .width('100%')

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
        .width('100%')
        .margin({ bottom: 12 })
        .justifyContent(FlexAlign.Start)

        TextInput({ placeholder: '主 DNS', text: this.primaryDns })
          .onChange((value: string) => {
            this.primaryDns = value;
          })
          .margin({ bottom: 12 })
          .width('100%')

        TextInput({ placeholder: '备用 DNS (可选)', text: this.secondaryDns })
          .onChange((value: string) => {
            this.secondaryDns = value;
          })
          .margin({ bottom: 20 })
          .width('100%')

        Button('保存')
          .onClick(async () => {
            if (this.name && this.primaryDns) {
              if (this.isEditMode) {
                const dns = new DnsInfo(this.name, this.primaryDns, this.secondaryDns, false, this.selectedType);
                dns.id = this.currentId; // 保持 ID 不变
                await DnsDataManager.getInstance().updateDns(dns);
                promptAction.showToast({ message: '修改成功' });
              } else {
                const dns = new DnsInfo(this.name, this.primaryDns, this.secondaryDns, false, this.selectedType);
                await DnsDataManager.getInstance().addDns(dns);
                promptAction.showToast({ message: '添加成功' });
              }
              router.back();
            } else {
              promptAction.showToast({ message: '请填写完整信息' });
            }
          })
          .width('100%')
          .backgroundColor($r('app.color.brand_color'))
      }
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
