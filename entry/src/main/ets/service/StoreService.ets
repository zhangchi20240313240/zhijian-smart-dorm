/**
 * 持久化服务：整包快照写入 Preferences，冷启动时整体恢复
 * 路径：entry/src/main/ets/service/StoreService.ets
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class StoreService {
  private static readonly STORE_NAME: string = 'zhijian_store';
  private static readonly KEY_SNAPSHOT: string = 'snapshot_v1';
  private static readonly KEY_SAVED_AT: string = 'saved_at';
  private store: preferences.Preferences | undefined = undefined;

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.store !== undefined) {
      return;
    }
    this.store = await preferences.getPreferences(
      context, StoreService.STORE_NAME);
  }

  /** 写入整包 JSON 后立即 flush，保证进程被杀死时数据不丢 */
  async save(json: string): Promise<boolean> {
    if (this.store === undefined) {
      return false;
    }
    await this.store.put(StoreService.KEY_SNAPSHOT, json);
    await this.store.put(StoreService.KEY_SAVED_AT, Date.now());
    await this.store.flush();
    return true;
  }

  async load(): Promise<string> {
    if (this.store === undefined) {
      return '';
    }
    const raw = await this.store.get(StoreService.KEY_SNAPSHOT, '');
    return raw as string;
  }

  async savedAt(): Promise<number> {
    if (this.store === undefined) {
      return 0;
    }
    const v = await this.store.get(StoreService.KEY_SAVED_AT, 0);
    return v as number;
  }

  async clear(): Promise<void> {
    if (this.store === undefined) {
      return;
    }
    await this.store.delete(StoreService.KEY_SNAPSHOT);
    await this.store.flush();
  }
}
