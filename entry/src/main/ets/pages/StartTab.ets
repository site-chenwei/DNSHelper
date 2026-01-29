import { DnsInfo } from '../model/DnsInfo';
import { DnsDataManager } from '../utils/DnsDataManager';
import common from '@ohos.app.ability.common';
import { vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';

@Component
export default struct StartTab {
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageLink('isRunning') isRunning: boolean = false;
  @StorageProp('currentDnsId') @Watch('updateCurrentDnsName') currentDnsId: string = '';
  @StorageLink('dnsList') @Watch('updateCurrentDnsName') dnsList: DnsInfo[] = [];
  @State currentDnsName: string = '请选择 DNS';
  @State buttonScale: number = 1;

  aboutToAppear() {
    DnsDataManager.getInstance().init(getContext(this));
    this.updateCurrentDnsName();
  }

  updateCurrentDnsName() {
    const dns = this.dnsList.find(i => i.id === this.currentDnsId);
    this.currentDnsName = dns ? dns.name : '请选择 DNS';
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
    let dnsIps: string[] = ['223.5.5.5', '223.6.6.6'];
    if (selectedDns) {
      dnsIps = [selectedDns.primaryDns];
      if (selectedDns.secondaryDns) {
        dnsIps.push(selectedDns.secondaryDns);
      }
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
        const index = value.index as number; // 确保类型安全
        if (index >= 0 && index < this.dnsList.length) {
          const selectedId = this.dnsList[index].id;
          DnsDataManager.getInstance().setCurrentDnsId(selectedId);
        }
      }
    });
  }

  build() {
    Column() {
      // 顶部标题区域
      Row() {
        Text('DNS Helper')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text(this.isRunning ? 'Running' : 'Stopped')
          .fontSize(14)
          .fontColor(this.isRunning ? '#007AFF' : '#8E8E93')
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.isRunning ? '#E5F2FF' : '#F2F2F7')
          .padding({
            left: 12,
            right: 12,
            top: 6,
            bottom: 6
          })
          .borderRadius(16)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20 })
      .alignItems(VerticalAlign.Center)

      // 中间大按钮区域
      Column() {
        Button() {
          Image(this.isRunning ? $r('app.media.startIcon') : $r('app.media.startIcon')) // 这里应该用不同的图标，暂用同一个
            .width(60)
            .height(60)
            .fillColor(Color.White)
        }
        .width(160)
        .height(160)
        .borderRadius(80)
        .backgroundColor(this.isRunning ? '#007AFF' : '#E5E5EA') // 蓝色 vs 灰色
        .shadow({ radius: 20, color: this.isRunning ? 'rgba(0,122,255,0.4)' : 'rgba(0,0,0,0.1)', offsetY: 10 })
        .scale({ x: this.buttonScale, y: this.buttonScale })
        .onClick(() => {
          this.toggleRunning();
        })

        Text(this.isRunning ? '已激活' : '点击启动')
          .fontSize(16)
          .fontColor('#8E8E93')
          .margin({ top: 24 })
      }
      .flexGrow(1)
      .justifyContent(FlexAlign.Center)

      // 底部卡片区域
      Column({ space: 12 }) {
        // 策略组卡片
        Row() {
          Column() {
            Text('当前策略')
              .fontSize(12)
              .fontColor('#8E8E93')
              .margin({ bottom: 4 })
            Text(this.currentDnsName)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Text('切换 >')
            .fontSize(14)
            .fontColor('#007AFF')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White) // 这里应该适配深色模式，但在 ArkTS 中通常用系统资源或特定颜色
        .borderRadius(16)
        .shadow({ radius: 10, color: 'rgba(0,0,0,0.05)', offsetY: 4 })
        .onClick(() => {
          this.showDnsSelector();
        })

        // 简单的网络信息卡片 (静态模拟)
        Row() {
          Column() {
            Text('出站模式')
              .fontSize(12)
              .fontColor('#8E8E93')
              .margin({ bottom: 4 })
            Text('直接连接')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          // 模拟一些图标或数据
          Text('WIFI')
            .fontSize(14)
            .fontColor('#8E8E93')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(16)
        .shadow({ radius: 10, color: 'rgba(0,0,0,0.05)', offsetY: 4 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topSafeHeight })
    .backgroundColor('#F2F2F7') // 浅灰背景，Surge 风格
  }
}
