import { Rule, Trigger, TriggerKind, CompareOp } from '../model/RuleModel';
import { DormStore } from '../viewmodel/DormStore';
import { DeviceState } from '../model/DeviceModel';

export function opText(op: CompareOp): string {
  switch (op) {
    case CompareOp.Gt: return '>';
    case CompareOp.Gte: return '≥';
    case CompareOp.Lt: return '<';
    case CompareOp.Lte: return '≤';
    case CompareOp.Eq: return '=';
    default: return '≠';
  }
}

export function attrLabel(attr: string): string {
  if (attr === 'power') {
    return '开关';
  }
  if (attr === 'level') {
    return '档位';
  }
  if (attr === 'targetTemp') {
    return '目标温度';
  }
  return '';
}

export function triggerText(t: Trigger): string {
  if (t.kind === TriggerKind.Time) {
    const h = Math.floor(t.atMinute / 60);
    const m = t.atMinute % 60;
    return `${h < 10 ? '0' : ''}${h}:${m < 10 ? '0' : ''}${m} 定时触发`;
  }
  if (t.kind === TriggerKind.Manual) {
    return '手动执行';
  }
  return `${t.sourceId} ${attrLabel(t.attr)} ${opText(t.op)} ${t.value}`;
}

/** 设备 id → 中文名，供列表展示；找不到时退回 id */
export function deviceLabel(devices: DeviceState[], id: string): string {
  const d = devices.find((item: DeviceState) => item.id === id);
  return d === undefined ? id : d.name;
}

@Component
export struct RuleCard {
  @ObjectLink rule: Rule;
  @Consume('store') store: DormStore;

  private summary(): string {
    if (this.rule.triggers.length === 0) {
      return '未设置触发';
    }
    const t = this.rule.triggers[0];
    if (t.kind === TriggerKind.Device) {
      const name = deviceLabel(this.store.deviceService.devices, t.sourceId);
      const label = attrLabel(t.attr);
      const prefix = label.length > 0 ? `${name} ${label}` : name;
      return `${prefix} ${opText(t.op)} ${t.value}`;
    }
    return triggerText(t);
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(`P${this.rule.priority}`)
          .fontSize(11)
          .fontColor('#2E5BFF')
          .backgroundColor('#EAF0FF')
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .borderRadius(6)
        Text(this.rule.name).fontSize(15).fontWeight(FontWeight.Medium).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.rule.enabled })
          .onChange(() => {
            this.store.toggleRule(this.rule.id);
          })
      }
      .width('100%')

      Text(this.summary()).fontSize(12).fontColor('#7C8595')
      Row({ space: 12 }) {
        Text(`动作 ${this.rule.actions.length} 项`).fontSize(11).fontColor('#9AA3B2')
        Text(`冷却 ${this.rule.cooldownSec}s`).fontSize(11).fontColor('#9AA3B2')
        Blank()
        Text(`已执行 ${this.rule.fireCount} 次`).fontSize(11).fontColor('#9AA3B2')
      }
      .width('100%')
    }
    .padding(14)
    .width('100%')
    .backgroundColor(this.rule.enabled ? '#FFFFFF' : '#F7F8FA')
    .borderRadius(16)
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/RuleEditorPage',
        params: { ruleId: this.rule.id }
      });
    })
  }
}
