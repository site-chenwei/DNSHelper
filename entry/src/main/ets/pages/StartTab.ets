import { DnsInfo } from '../model/DnsInfo';
import { DnsDataManager } from '../utils/DnsDataManager';
import common from '@ohos.app.ability.common';
import { vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import commonEventManager from '@ohos.commonEventManager';

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
        Image($r('app.media.ic_arrow_right'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.icon_secondary'))
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
struct WaveView {
  @State waveScale1: number = 1;
  @State waveOpacity1: number = 0;
  @State waveScale2: number = 1;
  @State waveOpacity2: number = 0;
  private animationTimeoutId: number = -1;

  aboutToAppear() {
    this.startWaveAnimation();
  }

  aboutToDisappear() {
    if (this.animationTimeoutId !== -1) {
      clearTimeout(this.animationTimeoutId);
      this.animationTimeoutId = -1;
    }
  }

  startWaveAnimation() {
    // 初始状态
    this.waveScale1 = 1;
    this.waveOpacity1 = 0.4;
    this.waveScale2 = 1;
    this.waveOpacity2 = 0.4;
    
    // 第一圈波纹
    animateTo({
      duration: 3000,
      curve: Curve.EaseOut,
      iterations: -1,
      playMode: PlayMode.Normal
    }, () => {
      this.waveScale1 = 1.35;
      this.waveOpacity1 = 0;
    })

    // 第二圈波纹，延迟1.5秒启动
    this.animationTimeoutId = setTimeout(() => {
      animateTo({
        duration: 3000,
        curve: Curve.EaseOut,
        iterations: -1,
        playMode: PlayMode.Normal
      }, () => {
        this.waveScale2 = 1.35;
        this.waveOpacity2 = 0;
      })
    }, 1500)
  }

  build() {
    Stack() {
      Circle()
        .width(180)
        .height(180)
        .fill($r('app.color.brand_color'))
        .scale({ x: this.waveScale1, y: this.waveScale1 })
        .opacity(this.waveOpacity1)

      Circle()
        .width(180)
        .height(180)
        .fill($r('app.color.brand_color'))
        .scale({ x: this.waveScale2, y: this.waveScale2 })
        .opacity(this.waveOpacity2)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
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
  @State dnsCount: number = 0;
  
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;
  @Link currentIndex: number;

  aboutToAppear() {
    // DnsDataManager 已经在 EntryAbility 中初始化，这里无需重复初始化
    this.updateCurrentDnsName();
    this.subscribeToDnsStats();
  }

  aboutToDisappear() {
    if (this.subscriber) {
      commonEventManager.unsubscribe(this.subscriber);
    }
  }

  subscribeToDnsStats() {
    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: ['site.chenwei.dns.event.DNS_COUNT_UPDATE']
    };
    commonEventManager.createSubscriber(subscribeInfo, (err, subscriber) => {
      if (err) {
        console.error(`Create subscriber failed: ${JSON.stringify(err)}`);
        return;
      }
      this.subscriber = subscriber;
      commonEventManager.subscribe(subscriber, (err, data) => {
        if (err) {
          console.error(`Subscribe failed: ${JSON.stringify(err)}`);
          return;
        }
        if (data.event === 'site.chenwei.dns.event.DNS_COUNT_UPDATE') {
          const count = data.parameters ? data.parameters['count'] as number : 0;
          this.dnsCount = count;
        }
      });
    });
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

    // 弹性缩放动画
    animateTo({ duration: 300, curve: Curve.Friction }, () => {
      this.buttonScale = 0.85;
    });
    setTimeout(() => {
      // Curve.Spring 不是枚举值，如果需要弹簧效果，建议使用 FastOutSlowIn 或 cubicBezier 自定义
      // 或者使用 interpolatingSpring 物理动画，但这里为了兼容性使用 FastOutSlowIn 模拟回弹
      animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
        this.buttonScale = 1;
      });
    }, 150);

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
        Stack({ alignContent: Alignment.Center }) {
          // 呼吸波纹层 - 使用条件渲染控制挂载/卸载
          if (this.isRunning) {
            WaveView()
              .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
          }
          
          Button() {
            Image($r('app.media.ic_power')) 
              .width(80)
              .height(80)
              .fillColor(Color.White)
          }
          .width(180)
          .height(180)
          .borderRadius(90)
          .backgroundColor(this.isRunning ? $r('app.color.brand_color') : $r('app.color.button_inactive_bg'))
          .shadow({ radius: 20, color: this.isRunning ? 'rgba(17, 184, 130, 0.4)' : $r('app.color.card_shadow'), offsetY: 10 })
          .scale({ x: this.buttonScale, y: this.buttonScale })
          .onClick(() => {
            this.toggleRunning();
          })
        }
        .width(260) // 给波纹扩散留出空间
        .height(260)
        .alignContent(Alignment.Center)

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
                title: 'DNS 服务',
                value: this.currentDnsName,
                showArrow: true,
                onClickHandler: () => {
                  this.currentIndex = 1; // 切换到 DNS Tab
                }
              })
              
              if (this.isRunning) {
                Divider().color($r('app.color.divider_color')).strokeWidth(0.5).margin({ left: 16, right: 16 })

                SettingsItem({
                  title: '已处理请求',
                  value: this.dnsCount.toString(),
                  showArrow: false
                })
              }
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
