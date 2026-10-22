/**
 * 规则数据模型：触发（Trigger）— 条件（Condition）— 动作（Action）
 * 路径：entry/src/main/ets/model/RuleModel.ets
 */
export enum CompareOp {
  Gt = 'gt',
  Gte = 'gte',
  Lt = 'lt',
  Lte = 'lte',
  Eq = 'eq',
  Neq = 'neq'
}

export enum TriggerKind {
  Device = 'device',  // 设备属性变化
  Time = 'time',      // 定时
  Manual = 'manual'   // 手动执行
}

export enum ActionKind {
  SetAttr = 'set',
  Delay = 'delay',
  Notify = 'notify'
}

export interface TriggerJson {
  kind: string;
  sourceId: string;
  attr: string;
  op: string;
  value: number;
  atMinute: number;
}

export interface ConditionJson {
  sourceId: string;
  attr: string;
  op: string;
  value: number;
}

export interface ActionJson {
  kind: string;
  targetId: string;
  attr: string;
  value: number;
  seconds: number;
  message: string;
}

export interface RuleJson {
  id: string;
  name: string;
  enabled: boolean;
  priority: number;
  cooldownSec: number;
  triggers: TriggerJson[];
  conditions: ConditionJson[];
  actions: ActionJson[];
  lastFiredAt: number;
  fireCount: number;
}

/** 触发条件。sourceId 为设备 id；Time 类型的 atMinute 表示当天第几分钟 */
export class Trigger {
  kind: TriggerKind = TriggerKind.Device;
  sourceId: string = '';
  attr: string = '';
  op: CompareOp = CompareOp.Eq;
  value: number = 0;
  atMinute: number = -1;

  constructor(kind: TriggerKind, sourceId: string, attr: string,
              op: CompareOp, value: number, atMinute: number = -1) {
    this.kind = kind;
    this.sourceId = sourceId;
    this.attr = attr;
    this.op = op;
    this.value = value;
    this.atMinute = atMinute;
  }

  toJson(): TriggerJson {
    const j: TriggerJson = {
      kind: this.kind, sourceId: this.sourceId, attr: this.attr,
      op: this.op, value: this.value, atMinute: this.atMinute
    };
    return j;
  }

  static fromJson(j: TriggerJson): Trigger {
    return new Trigger(j.kind as TriggerKind, j.sourceId, j.attr,
      j.op as CompareOp, j.value, j.atMinute);
  }
}

/** 附加条件，全部满足（AND）才执行动作 */
export class Condition {
  sourceId: string = '';   // 设备 id 或 'env'
  attr: string = '';
  op: CompareOp = CompareOp.Lt;
  value: number = 0;

  constructor(sourceId: string, attr: string, op: CompareOp, value: number) {
    this.sourceId = sourceId;
    this.attr = attr;
    this.op = op;
    this.value = value;
  }

  toJson(): ConditionJson {
    const j: ConditionJson = {
      sourceId: this.sourceId, attr: this.attr, op: this.op, value: this.value
    };
    return j;
  }

  static fromJson(j: ConditionJson): Condition {
    return new Condition(j.sourceId, j.attr, j.op as CompareOp, j.value);
  }
}

/** 动作。set 写设备属性，delay 等待，notify 发通知 */
export class Action {
  kind: ActionKind = ActionKind.SetAttr;
  targetId: string = '';
  attr: string = '';
  value: number = 0;
  seconds: number = 0;
  message: string = '';

  constructor(kind: ActionKind, targetId: string = '', attr: string = '',
              value: number = 0, seconds: number = 0, message: string = '') {
    this.kind = kind;
    this.targetId = targetId;
    this.attr = attr;
    this.value = value;
    this.seconds = seconds;
    this.message = message;
  }

  /** 动作用"目标键"标识，供冲突消解比较 */
  targetKey(): string {
    return this.kind === ActionKind.SetAttr ? `${this.targetId}.${this.attr}` : '';
  }

  toJson(): ActionJson {
    const j: ActionJson = {
      kind: this.kind, targetId: this.targetId, attr: this.attr,
      value: this.value, seconds: this.seconds, message: this.message
    };
    return j;
  }

  static fromJson(j: ActionJson): Action {
    return new Action(j.kind as ActionKind, j.targetId, j.attr, j.value, j.seconds, j.message);
  }
}

@Observed
export class Rule {
  id: string = '';
  name: string = '';
  enabled: boolean = true;
  priority: number = 5;       // 1—9，数值越大越优先
  cooldownSec: number = 60;   // 冷却时间，防止抖动反复触发
  triggers: Trigger[] = [];
  conditions: Condition[] = [];
  actions: Action[] = [];
  lastFiredAt: number = 0;    // 毫秒时间戳
  fireCount: number = 0;
  sceneId: string = '';

  constructor(id: string, name: string, priority: number = 5) {
    this.id = id;
    this.name = name;
    this.priority = priority;
  }

  inCooldown(nowMs: number): boolean {
    return this.cooldownSec > 0 && this.lastFiredAt > 0 &&
      (nowMs - this.lastFiredAt) < this.cooldownSec * 1000;
  }

  toJson(): RuleJson {
    const j: RuleJson = {
      id: this.id, name: this.name, enabled: this.enabled,
      priority: this.priority, cooldownSec: this.cooldownSec,
      triggers: this.triggers.map((t: Trigger) => t.toJson()),
      conditions: this.conditions.map((c: Condition) => c.toJson()),
      actions: this.actions.map((a: Action) => a.toJson()),
      lastFiredAt: this.lastFiredAt, fireCount: this.fireCount
    };
    return j;
  }

  static fromJson(j: RuleJson): Rule {
    const r = new Rule(j.id, j.name, j.priority);
    r.enabled = j.enabled;
    r.cooldownSec = j.cooldownSec;
    r.lastFiredAt = j.lastFiredAt;
    r.fireCount = j.fireCount;
    r.triggers = j.triggers.map((t: TriggerJson) => Trigger.fromJson(t));
    r.conditions = j.conditions.map((c: ConditionJson) => Condition.fromJson(c));
    r.actions = j.actions.map((a: ActionJson) => Action.fromJson(a));
    return r;
  }
}
