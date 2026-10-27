/**
 * 设备服务：设备注册表、属性读写、状态快照（供触发器做差分比对）
 * 路径：entry/src/main/ets/service/DeviceService.ets
 */
import { DeviceState, DeviceAttr } from '../model/DeviceModel';

export class DeviceService {
  devices: DeviceState[] = [];
  private snapshot: Map<string, number> = new Map<string, number>();

  load(list: DeviceState[]): void {
    this.devices = list;
    this.captureSnapshot();
  }

  find(id: string): DeviceState | undefined {
    return this.devices.find((d: DeviceState) => d.id === id);
  }

  findOrThrow(id: string): DeviceState {
    const d = this.find(id);
    if (d === undefined) {
      throw new Error(`设备不存在: ${id}`);
    }
    return d;
  }

  /** 写入并返回是否真的发生了变化，避免同值重复触发规则 */
  setAttr(id: string, attr: string, value: number): boolean {
    const d = this.find(id);
    if (d === undefined || !d.online) {
      return false;
    }
    const before = d.readAttr(attr);
    const ok = d.writeAttr(attr, value);
    return ok && Math.abs(before - d.readAttr(attr)) > 0.001;
  }

  setPower(id: string, on: boolean): boolean {
    return this.setAttr(id, DeviceAttr.Power, on ? 1 : 0);
  }

  toggle(id: string): boolean {
    const d = this.find(id);
    if (d === undefined || d.isSensor()) {
      return false;
    }
    return this.setAttr(id, DeviceAttr.Power, d.power ? 0 : 1);
  }

  /** 记录当前所有"可触发属性"的值，供下一轮差分 */
  captureSnapshot(): void {
    this.snapshot.clear();
    this.devices.forEach((d: DeviceState) => {
      this.snapshot.set(`${d.id}.${DeviceAttr.Power}`, d.readAttr(DeviceAttr.Power));
      this.snapshot.set(`${d.id}.${DeviceAttr.Level}`, d.level);
      this.snapshot.set(`${d.id}.${DeviceAttr.Value}`, d.value);
    });
  }

  previous(key: string): number {
    const v = this.snapshot.get(key);
    return v === undefined ? Number.NaN : v;
  }

  onlineCount(): number {
    return this.devices.filter((d: DeviceState) => d.online).length;
  }

  activeCount(): number {
    return this.devices.filter((d: DeviceState) => d.power && !d.isSensor()).length;
  }
}
