import { DnsInfo } from '../model/DnsInfo';
import { DnsDataManager } from '../utils/DnsDataManager';
import common from '@ohos.app.ability.common';
import { vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';

@Component
struct SettingsItem {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop showArrow: boolean = true;
  onClickHandler?: () => void;

  build() {
    Row() {
      Text(this.title)
        .fontSize($r('app.float.text_size_body'))
        .fontColor($r('app.color.text_primary'))
      
      Blank()

      Text(this.value)
        .fontSize($r('app.float.text_size_body'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ right: 4 })

      if (this.showArrow) {
        Path()
          .commands('M10 6 L16 12 L10 18') // Simple arrow
          .fill(Color.Transparent)
          .stroke($r('app.color.text_secondary')) // Use secondary text color
          .strokeWidth(2)
          .width(12)
          .height(24)
          .opacity(0.3)
      }
    }
    .width('100%')
    .height($r('app.float.list_item_height'))
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
    .onClick(() => {
      if (this.onClickHandler) this.onClickHandler();
    })
  }
}

@Component
export default struct StartTab {
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageLink('isRunning') isRunning: boolean = false;
  @StorageProp('currentDnsId') @Watch('updateCurrentDnsName') currentDnsId: string = '';
  @StorageLink('dnsList') @Watch('updateCurrentDnsName') dnsList: DnsInfo[] = [];
  @State currentDnsName: string = '请选择 DNS';
  @State buttonScale: number = 1;

  aboutToAppear() {
    // DnsDataManager 已经在 EntryAbility 中初始化，这里无需重复初始化
    this.updateCurrentDnsName();
  }

  aboutToDisappear() {
  }

  updateCurrentDnsName() {
    console.info(`updateCurrentDnsName: currentDnsId=${this.currentDnsId}, dnsList.length=${this.dnsList.length}`);
    const dns = this.dnsList.find(i => i.id === this.currentDnsId);
    if (dns) {
      this.currentDnsName = dns.name;
      console.info(`Found DNS: ${dns.name}`);
    } else {
      this.currentDnsName = '请选择 DNS';
      console.info(`DNS not found for ID: ${this.currentDnsId}`);
    }
  }

  async toggleRunning() {
    if (!this.currentDnsId && !this.isRunning) {
      // 如果没有选中且尝试启动，先尝试默认选中第一个
      if (this.dnsList.length > 0) {
        await DnsDataManager.getInstance().setCurrentDnsId(this.dnsList[0].id);
      } else {
        // TODO: 提示用户添加配置
        return;
      }
    }

    // 简单的缩放动画效果
    animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
      this.buttonScale = 0.9;
    });
    setTimeout(() => {
      animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
        this.buttonScale = 1;
      });
    }, 100);

    if (this.isRunning) {
      await this.stopVpn();
    } else {
      await this.startVpn();
    }
  }

  async startVpn() {
    const selectedDns = this.dnsList.find(d => d.id === this.currentDnsId);
    let dnsIps: string[] = ['223.5.5.5'];
    if (selectedDns) {
      dnsIps = [selectedDns.primaryDns];
    }

    const want: Want = {
      deviceId: "",
      bundleName: 'site.chenwei.dns',
      abilityName: 'MyVpnExtAbility',
      parameters: {
        dnsList: dnsIps
      }
    };

    try {
      await vpnExtension.startVpnExtensionAbility(want);
      // Note: startVpnExtensionAbility is async but returns promise.
      // Real connection state depends on VpnExtensionAbility lifecycle.
      // Here we optimistically set isRunning.
      AppStorage.setOrCreate('isRunning', true);
    } catch (e) {
      console.error('Start VPN failed: ' + JSON.stringify(e));
    }
  }

  async stopVpn() {
    const want: Want = {
      deviceId:"",
      bundleName: 'site.chenwei.dns',
      abilityName: 'MyVpnExtAbility'
    };
    try {
      await vpnExtension.stopVpnExtensionAbility(want);
      AppStorage.setOrCreate('isRunning', false);
    } catch (e) {
      console.error('Stop VPN failed: ' + JSON.stringify(e));
    }
  }

  showDnsSelector() {
    if (this.dnsList.length === 0) {
      return;
    }

    const dnsNames = this.dnsList.map(d => d.name);
    const selectedIndex = this.dnsList.findIndex(d => d.id === this.currentDnsId);

    TextPickerDialog.show({
      range: dnsNames,
      selected: selectedIndex >= 0 ? selectedIndex : 0,
      onAccept: (value: TextPickerResult) => {
        let index: number;
        if (Array.isArray(value.index)) {
          index = value.index[0];
        } else {
          index = value.index;
        }

        console.info(`DNS Selector onAccept: index=${index}, value=${JSON.stringify(value)}`);

        if (index >= 0 && index < this.dnsList.length) {
          const selectedId = this.dnsList[index].id;
          console.info(`Switching DNS to: ${selectedId}`);
          
          // 使用 DnsDataManager 修改选中状态，不直接修改 @StorageProp
          DnsDataManager.getInstance().setCurrentDnsId(selectedId).then(() => {
             // 状态更新后，AppStorage 会通知 @StorageProp 更新，触发 @Watch
             // 但为了更好的交互体验，可以手动调用一次 UI 刷新（虽然 @Watch 应该会处理）
             console.info('DnsDataManager set completed');
          });
        }
      }
    });
  }

  build() {
    Column() {
      // 顶部标题区域
      Stack({ alignContent: Alignment.Center }) {
        Text('DNS Helper')
          .fontSize($r('app.float.text_size_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height(44)
      .margin({ top: 10, bottom: 10 })

      // 中间大按钮区域
      Column() {
        Button() {
          Image(this.isRunning ? $r('app.media.startIcon') : $r('app.media.startIcon')) 
            .width(80)
            .height(80)
            .fillColor(Color.White)
        }
        .width(180)
        .height(180)
        .borderRadius(90)
        .backgroundColor(this.isRunning ? $r('app.color.brand_color') : $r('app.color.button_inactive_bg'))
        .shadow({ radius: 20, color: this.isRunning ? 'rgba(0,122,255,0.4)' : $r('app.color.card_shadow'), offsetY: 10 })
        .scale({ x: this.buttonScale, y: this.buttonScale })
        .onClick(() => {
          this.toggleRunning();
        })

        Text(this.isRunning ? '已保护' : '点击启动')
          .fontSize($r('app.float.text_size_sub_title'))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)
          .margin({ top: 30 })
        
        Text(this.isRunning ? 'VPN 服务运行中' : '未连接')
          .fontSize($r('app.float.text_size_small'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 8 })
      }
      .flexGrow(1)
      .justifyContent(FlexAlign.Center)

      // 底部功能列表
      Column() {
        List() {
          ListItem() {
            Column() {
              SettingsItem({
                title: '当前策略',
                value: this.currentDnsName,
                showArrow: true,
                onClickHandler: () => {
                  this.showDnsSelector();
                }
              })
            }
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
            .clip(true)
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_grouped_background'))
    .padding({ top: this.topSafeHeight })
  }
}
