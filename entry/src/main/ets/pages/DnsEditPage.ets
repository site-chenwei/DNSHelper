import { DnsInfo, DnsType } from '../model/DnsInfo';
import { router } from '@kit.ArkUI';
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
  @State selectedType: DnsType = DnsType.UDP;
  @State isEditMode: boolean = false;
  @State currentId: string = '';
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;

  isValidIp(ip: string): boolean {
    if (this.selectedType === DnsType.DOH) {
      return ip.startsWith('https://') || ip.startsWith('http://');
    }
    const ipv4Regex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    return ipv4Regex.test(ip);
  }

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
        this.selectedType = dns.type || DnsType.UDP;
      }
    }
  }

  @Builder
  InputCell(title: string, placeholder: string, value: string, onChange: (val: string) => void) {
    Row() {
      Text(title)
        .width(80)
        .fontSize($r('app.float.text_size_body'))
        .fontColor($r('app.color.text_primary'))
      
      TextInput({ text: value, placeholder: placeholder })
        .textAlign(TextAlign.Start)
        .fontSize($r('app.float.text_size_body'))
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_secondary'))
        .backgroundColor(Color.Transparent)
        .height('100%')
        .layoutWeight(1)
        .onChange(onChange)
    }
    .width('100%')
    .height($r('app.float.list_item_height'))
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  SelectCell(title: string, value: string, options: string[], onSelect: (val: string) => void) {
    Row() {
      Text(title)
        .width(80)
        .fontSize($r('app.float.text_size_body'))
        .fontColor($r('app.color.text_primary'))
      
      Select(options.map((v): DropdownOption => ({ value: v })))
        .selected(options.indexOf(value))
        .value(value)
        .font({ size: $r('app.float.text_size_body') })
        .selectedOptionFont({ size: $r('app.float.text_size_body') })
        .optionFont({ size: $r('app.float.text_size_body') })
        .backgroundColor(Color.Transparent)
        .onSelect((index: number, val: string) => onSelect(val))
        .height('100%')
        .layoutWeight(1)
    }
    .width('100%')
    .height($r('app.float.list_item_height'))
    .padding({ left: 16, right: 0 })
    .backgroundColor($r('app.color.card_background'))
  }

  async save() {
    if (this.name && this.primaryDns) {
      if (!this.isValidIp(this.primaryDns)) {
        promptAction.showToast({ message: 'DNS 格式不正确' });
        return;
      }

      if (this.isEditMode) {
        const dns = new DnsInfo(this.name, this.primaryDns, false, this.selectedType);
        dns.id = this.currentId; // 保持 ID 不变
        await DnsDataManager.getInstance().updateDns(dns);
        promptAction.showToast({ message: '修改成功' });
      } else {
        const dns = new DnsInfo(this.name, this.primaryDns, false, this.selectedType);
        await DnsDataManager.getInstance().addDns(dns);
        promptAction.showToast({ message: '添加成功' });
      }
      router.back();
    } else {
      promptAction.showToast({ message: '请填写完整信息' });
    }
  }

  build() {
    Column() {
      // 标题栏
      Stack({ alignContent: Alignment.Center }) {
        // 返回按钮
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.icon_secondary'))
        }
        .width(56)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.back();
        })
        .position({ x: 0, y: 0 })
        .zIndex(1)

        // 标题
        Text(this.isEditMode ? '编辑 DNS' : '添加 DNS')
          .fontSize($r('app.float.text_size_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)

        // 保存按钮
        Row() {
          Button('完成')
            .onClick(() => this.save())
            .fontSize($r('app.float.text_size_body'))
            .fontColor($r('app.color.brand_color'))
            .backgroundColor(Color.Transparent)
            .padding({ right: 16 })
        }
        .height('100%')
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
        .position({ x: '100%', y: 0 })
        .markAnchor({ x: '100%', y: 0 })
        .zIndex(1)
      }
      .width('100%')
      .height(44)
      .margin({ top: 10, bottom: 10 })

      List() {
        ListItem() {
          Column() {
            this.InputCell('名称', '请输入服务名称', this.name, (value) => this.name = value)
            Divider()
              .color($r('app.color.divider_color'))
              .strokeWidth(0.5)
              .padding({ left: 16 })
            
            this.SelectCell('类型', this.selectedType, Object.values(DnsType), (value) => this.selectedType = value as DnsType)
            Divider()
              .color($r('app.color.divider_color'))
              .strokeWidth(0.5)
              .padding({ left: 16 })
            
            this.InputCell('DNS', '请输入DNS地址', this.primaryDns, (value) => this.primaryDns = value)
          }
          .width('100%')
          .borderRadius(12)
          .clip(true)
          .backgroundColor($r('app.color.card_background'))
        }
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_grouped_background'))
    .padding({ top: this.topSafeHeight })
  }
}
