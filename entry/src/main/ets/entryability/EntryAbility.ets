import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DormStore } from '../viewmodel/DormStore';

const DOMAIN: number = 0x0001;
const TAG: string = 'YuJian';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onCreate');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    // 先恢复本地快照，再加载首页，避免首帧闪回默认数据
    await DormStore.instance.init(this.context);
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
      DormStore.instance.start();
    });
  }

  onForeground(): void {
    DormStore.instance.start();
  }

  onBackground(): void {
    DormStore.instance.stop();
    DormStore.instance.save();
  }

  onDestroy(): void {
    DormStore.instance.stop();
    DormStore.instance.save();
  }
}
