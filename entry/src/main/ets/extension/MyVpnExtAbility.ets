import VpnExtensionAbility from '@ohos.app.ability.VpnExtensionAbility';
import Want from '@ohos.app.ability.Want';
import { VpnUtil } from '../utils/VpnUtil';

export default class MyVpnExtAbility extends VpnExtensionAbility {
  onCreate(want: Want) {
    console.error('MyVpnExtAbility onCreate TRIGGERED! Want:', JSON.stringify(want));
    // 从 want 中获取参数，例如 DNS 服务器列表
    const dnsList = want.parameters?.['dnsList'] as string[];
    
    if (dnsList && dnsList.length > 0) {
      // 这里的 this.context 就是 VpnExtensionContext
      VpnUtil.startVpn(this.context, dnsList).catch((err: Error) => {
        console.error('Failed to start VPN in Extension:', err);
      });
    }
  }

  onDestroy() {
    console.info('MyVpnExtAbility onDestroy');
    VpnUtil.stopVpn(this.context).catch((err: Error) => {
      console.error('Failed to stop VPN in Extension:', err);
    });
  }
}
