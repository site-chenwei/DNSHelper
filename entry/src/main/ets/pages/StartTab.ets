import { DnsInfo } from '../model/DnsInfo';
import { DnsDataManager } from '../utils/DnsDataManager';
import { SettingsItem } from '../component/CommonComponents';
import common from '@ohos.app.ability.common';
import { vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import commonEventManager from '@ohos.commonEventManager';

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
        .width($r('app.float.wave_size'))
        .height($r('app.float.wave_size'))
        .fill($r('app.color.brand_color'))
        .scale({ x: this.waveScale1, y: this.waveScale1 })
        .opacity(this.waveOpacity1)

      Circle()
        .width($r('app.float.wave_size'))
        .height($r('app.float.wave_size'))
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
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @StorageLink('isRunning') @Watch('onRunningChange') isRunning: boolean = false;
  @StorageLink('vpnStartTime') vpnStartTime: number = 0;
  @State durationStr: string = '00:00:00';
  private timerId: number = -1;
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
    if (this.isRunning) {
      this.startTimer();
    }
  }

  aboutToDisappear() {
    if (this.subscriber) {
      commonEventManager.unsubscribe(this.subscriber);
    }
    this.stopTimer();
  }

  onRunningChange() {
    if (this.isRunning) {
      if (this.vpnStartTime <= 0) {
        this.vpnStartTime = Date.now();
      }
      this.startTimer();
    } else {
      this.stopTimer();
      this.vpnStartTime = 0;
    }
  }

  startTimer() {
    this.stopTimer();
    this.updateDuration();
    this.timerId = setInterval(() => {
      this.updateDuration();
    }, 1000);
  }

  stopTimer() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  updateDuration() {
    if (this.vpnStartTime <= 0) {
      this.durationStr = '00:00:00';
      return;
    }
    const diff = Math.floor((Date.now() - this.vpnStartTime) / 1000);
    if (diff < 0) {
      this.durationStr = '00:00:00';
      return;
    }
    const h = Math.floor(diff / 3600);
    const m = Math.floor((diff % 3600) / 60);
    const s = diff % 60;
    this.durationStr = `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
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

    // 获取备用 DNS 列表 (仅 UDP)
    const backupList = DnsDataManager.getInstance().getBackupDnsList();
    const currentBackupId = AppStorage.get<string>('currentBackupDnsId');
    let backupIps: string[] = [];

    if (currentBackupId) {
      const selectedBackup = backupList.find(d => d.id === currentBackupId);
      if (selectedBackup && selectedBackup.type === 'UDP') {
        backupIps = [selectedBackup.primaryDns];
      }
    }

    // 如果没有选中的（理论上应该有），或者是选中的不是UDP，或者其他异常情况
    // 降级策略：如果 backupIps 为空，但 backupList 有 UDP 节点，默认使用第一个 UDP 节点
    if (backupIps.length === 0 && backupList.length > 0) {
       const firstUdp = backupList.find(d => d.type === 'UDP');
       if (firstUdp) {
         backupIps = [firstUdp.primaryDns];
       }
    }

    const want: Want = {
      deviceId: "",
      bundleName: 'site.chenwei.dns',
      abilityName: 'MyVpnExtAbility',
      parameters: {
        dnsList: dnsIps,
        dnsType: selectedDns ? selectedDns.type : 'UDP',
        preferHttp3: selectedDns ? (selectedDns.preferHttp3 || false) : false,
        backupDnsList: backupIps
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
      // Stack({ alignContent: Alignment.Center }) {
      //   Text('DNS Helper')
      //     .fontSize($r('app.float.text_size_title'))
      //     .fontWeight(FontWeight.Bold)
      //     .fontColor($r('app.color.text_primary'))
      //     .textAlign(TextAlign.Center)
      // }
      // .width('100%')
      // .height(44)
      // .margin({ top: 10, bottom: 10 })

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
              .width($r('app.float.start_icon_size'))
              .height($r('app.float.start_icon_size'))
              .fillColor($r('app.color.text_white'))
          }
          .width($r('app.float.start_button_size'))
          .height($r('app.float.start_button_size'))
          .borderRadius($r('app.float.start_button_radius'))
          .backgroundColor(this.isRunning ? $r('app.color.brand_color') : $r('app.color.button_inactive_bg'))
          .shadow({ radius: 20, color: this.isRunning ? $r('app.color.brand_shadow_active') : $r('app.color.card_shadow'), offsetY: 10 })
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
          .margin({ top: 8 })
        
        Text(this.isRunning ? `已运行 ${this.durationStr}` : '未连接')
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
                  this.showDnsSelector();
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
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: this.topSafeHeight })
  }
}