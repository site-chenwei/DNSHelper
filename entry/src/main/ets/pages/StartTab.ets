import { DnsInfo, DnsTargetConfig, AppState } from '../model/DnsInfo';
import { DnsDataManager } from '../utils/DnsDataManager';
import { SettingsItem } from '../component/CommonComponents';
import { vpnExtension } from '@kit.NetworkKit';
import { Want } from '@kit.AbilityKit';
import commonEventManager from '@ohos.commonEventManager';
import { AppStorageV2 } from '@kit.ArkUI';

@ComponentV2
struct WaveView {
  @Local waveScale1: number = 1;
  @Local waveOpacity1: number = 0;
  @Local waveScale2: number = 1;
  @Local waveOpacity2: number = 0;
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
    this.waveScale1 = 1;
    this.waveOpacity1 = 0.4;
    this.waveScale2 = 1;
    this.waveOpacity2 = 0.4;

    animateTo({
      duration: 3000,
      curve: Curve.EaseOut,
      iterations: -1,
      playMode: PlayMode.Normal
    }, () => {
      this.waveScale1 = 1.35;
      this.waveOpacity1 = 0;
    })

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

@ComponentV2
struct TimerDisplay {
  @Param isRunning: boolean = false;
  @Param vpnStartTime: number = 0;
  @Local durationStr: string = '00:00:00';
  private timerId: number = -1;

  @Monitor('isRunning')
  onRunningChange() {
    if (this.isRunning) {
      this.startTimer();
    } else {
      this.stopTimer();
    }
  }

  aboutToAppear() {
    if (this.isRunning) {
      this.startTimer();
    }
  }

  aboutToDisappear() {
    this.stopTimer();
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
    // Reset duration string if needed, or keep last value?
    // User logic reset it on stop
    if (!this.isRunning) {
       this.durationStr = '00:00:00'; // Logic from original
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
    this.durationStr =
      `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }

  build() {
    Text(this.isRunning ? `已运行 ${this.durationStr}` : '未连接')
      .fontSize($r('app.float.text_size_small'))
      .fontColor($r('app.color.text_secondary'))
      .margin({ top: $r('app.float.space_sm') })
  }
}

@ComponentV2
export default struct StartTab {
  @Local topSafeHeight: number = AppStorageV2.connect(Number, 'topSafeHeight', () => 0)!;
  @Local bottomSafeHeight: number = AppStorageV2.connect(Number, 'bottomSafeHeight', () => 0)!;
  @Local appState: AppState = AppStorageV2.connect(AppState, 'appState', () => new AppState())!;
  
  @Local selectedDnsIds: string[] = AppStorageV2.connect(Array, 'selectedDnsIds', () => [])!;
  @Local dnsList: DnsInfo[] = AppStorageV2.connect(Array, 'dnsList', () => [])!;
  @Local currentBackupDnsId: string = AppStorageV2.connect(String, 'currentBackupDnsId', () => '')!;

  @Local buttonScale: number = 1;
  @Local dnsCount: number = 0;
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;
  
  @Param currentIndex: number = 0;
  @Event onIndexChange: (index: number) => void = () => {};

  aboutToAppear() {
    // DnsDataManager 已经在 EntryAbility 中初始化，这里无需重复初始化
    this.subscribeToDnsStats();
    // No need to manually start timer here, TimerDisplay handles it
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

  getDnsName(): string {
    if (this.selectedDnsIds.length === 0) {
      return '请选择 DNS';
    } else if (this.selectedDnsIds.length === 1) {
      const dns = this.dnsList.find(i => i.id === this.selectedDnsIds[0]);
      return dns ? dns.name : '未知 DNS';
    } else {
      return `已启用 ${this.selectedDnsIds.length} 个服务`;
    }
  }

  async toggleRunning() {
    if (this.selectedDnsIds.length === 0 && !this.appState.isRunning) {
      // 如果没有选中且尝试启动，先尝试默认选中第一个
      if (this.dnsList.length > 0) {
        await DnsDataManager.getInstance().toggleDnsId(this.dnsList[0].id);
      } else {
        // TODO: 提示用户添加配置
        return;
      }
    }

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

    if (this.appState.isRunning) {
      await this.stopVpn();
    } else {
      await this.startVpn();
    }
  }

  async startVpn() {
    const selectedDnsItems = this.dnsList.filter(d => this.selectedDnsIds.includes(d.id));

    // 构建多 DNS 配置列表
    const dnsConfigList: DnsTargetConfig[] = selectedDnsItems.map((item): DnsTargetConfig => ({
      address: item.primaryDns,
      type: item.type || 'UDP',
      preferHttp3: item.preferHttp3 || false
    }));

    // 获取备用 DNS 列表 (仅 UDP)
    const backupList = DnsDataManager.getInstance().getBackupDnsList();
    const currentBackupId = this.currentBackupDnsId;
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
        dnsConfigList: JSON.stringify(dnsConfigList),
        backupDnsList: backupIps
      }
    };

    try {
      await vpnExtension.startVpnExtensionAbility(want);
      // Note: startVpnExtensionAbility is async but returns promise.
      // Real connection state depends on VpnExtensionAbility lifecycle.
      // Here we optimistically set isRunning.
      this.appState.isRunning = true;
      if (this.appState.vpnStartTime <= 0) {
         this.appState.vpnStartTime = Date.now();
      }
    } catch (e) {
      console.error('Start VPN failed: ' + JSON.stringify(e));
    }
  }

  async stopVpn() {
    const want: Want = {
      deviceId: "",
      bundleName: 'site.chenwei.dns',
      abilityName: 'MyVpnExtAbility'
    };
    try {
      await vpnExtension.stopVpnExtensionAbility(want);
      this.appState.isRunning = false;
      this.appState.vpnStartTime = 0;
    } catch (e) {
      console.error('Stop VPN failed: ' + JSON.stringify(e));
    }
  }

  build() {
    Column() {
      // 中间大按钮区域
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          if (this.appState.isRunning) {
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
          .backgroundColor(this.appState.isRunning ? $r('app.color.brand_color') : $r('app.color.button_inactive_bg'))
          .shadow({
            radius: 20,
            color: this.appState.isRunning ? $r('app.color.brand_shadow_active') : $r('app.color.card_shadow'),
            offsetY: 10
          })
          .scale({ x: this.buttonScale, y: this.buttonScale })
          .onClick(() => {
            this.toggleRunning();
          })
        }
        .width(260)
        .height(260)
        .alignContent(Alignment.Center)

        Text(this.appState.isRunning ? '已保护' : '点击启动')
          .fontSize($r('app.float.text_size_sub_title'))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)
          .margin({ top: $r('app.float.space_sm') })

        TimerDisplay({
            isRunning: this.appState.isRunning,
            vpnStartTime: this.appState.vpnStartTime
        })
      }
      .flexGrow(1)
      .justifyContent(FlexAlign.Center)

      Column() {
        List() {
          HdsListItemCard() {
            Column() {
              SettingsItem({
                title: 'DNS 服务',
                value: this.getDnsName(),
                showArrow: true,
                onClickHandler: () => {
                  this.onIndexChange(1);
                }
              })

              if (this.appState.isRunning) {
                Divider().color($r('app.color.divider_color')).strokeWidth(0.5).margin({ left: $r('app.float.space_lg'), right: $r('app.float.space_lg') })

                SettingsItem({
                  title: '已处理请求',
                  value: this.dnsCount.toString(),
                  showArrow: false
                })
              }
            }
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: $r('app.float.space_lg'), right: $r('app.float.space_lg'), bottom: $r('app.float.space_lg') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: this.topSafeHeight })
  }
}
