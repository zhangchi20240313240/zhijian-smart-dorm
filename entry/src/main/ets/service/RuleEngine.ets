/**
 * 规则引擎：触发匹配 → 条件判定 → 优先级排序 → 冲突消解 → 冷却校验 → 动作执行
 * 路径：entry/src/main/ets/service/RuleEngine.ets
 */
import { DeviceState, DeviceType } from '../model/DeviceModel';
import { Rule, Trigger, Condition, Action, ActionKind, CompareOp, TriggerKind } from '../model/RuleModel';
import { DeviceService } from './DeviceService';
import { EnvironmentService, envReadAttr } from './EnvironmentService';
import { LogService, LogLevel, MetricsService } from './LogService';

export enum FireResult {
  Fired = 'fired',
  Cooling = 'cooling',
  ConditionFailed = 'condition',
  Suppressed = 'suppressed',
  Disabled = 'disabled'
}

export class RuleVerdict {
  ruleId: string = '';
  ruleName: string = '';
  priority: number = 0;
  result: FireResult = FireResult.Fired;
  reason: string = '';

  constructor(ruleId: string, ruleName: string, priority: number, result: FireResult, reason: string) {
    this.ruleId = ruleId;
    this.ruleName = ruleName;
    this.priority = priority;
    this.result = result;
    this.reason = reason;
  }
}

export class CycleReport {
  tick: number = 0;
  checked: number = 0;
  fired: number = 0;
  suppressed: number = 0;
  verdicts: RuleVerdict[] = [];
}

class Candidate {
  rule: Rule;
  index: number;

  constructor(rule: Rule, index: number) {
    this.rule = rule;
    this.index = index;
  }
}

export class RuleEngine {
  private deviceService: DeviceService;
  private envService: EnvironmentService;
  private logService: LogService;
  private metrics: MetricsService;
  private tickCount: number = 0;

  constructor(ds: DeviceService, env: EnvironmentService, log: LogService, metrics: MetricsService) {
    this.deviceService = ds;
    this.envService = env;
    this.logService = log;
    this.metrics = metrics;
  }

  /** 统一的比较语义，供触发与条件共用 */
  evaluate(left: number, op: CompareOp, right: number): boolean {
    switch (op) {
      case CompareOp.Gt: return left > right;
      case CompareOp.Gte: return left >= right;
      case CompareOp.Lt: return left < right;
      case CompareOp.Lte: return left <= right;
      case CompareOp.Eq: return Math.abs(left - right) < 0.001;
      case CompareOp.Neq: return Math.abs(left - right) >= 0.001;
      default: return false;
    }
  }

  private clock(): string {
    return this.clock();
  }

  /** 读取任意来源（设备 / 环境）的属性值 */
  readSource(sourceId: string, attr: string): number {
    if (sourceId === 'env') {
      return envReadAttr(this.envService.state, this.envService.isPresence(this.deviceService.devices), attr);
    }
    const d = this.deviceService.find(sourceId);
    return d === undefined ? Number.NaN : d.readAttr(attr);
  }

  matchTrigger(rule: Rule, changed: Set<string>, manualId: string): boolean {
    if (rule.triggers.length === 0) {
      return false;
    }
    for (let i = 0; i < rule.triggers.length; i++) {
      const t: Trigger = rule.triggers[i];
      if (t.kind === TriggerKind.Manual) {
        if (manualId === rule.id) {
          return true;
        }
        continue;
      }
      if (t.kind === TriggerKind.Time) {
        if (t.atMinute === Math.floor(this.envService.state.minuteOfDay)) {
          return true;
        }
        continue;
      }
      if (!changed.has(`${t.sourceId}.${t.attr}`)) {
        continue;
      }
      const now = this.readSource(t.sourceId, t.attr);
      if (this.evaluate(now, t.op, t.value)) {
        return true;
      }
    }
    return false;
  }

  /** 所有附加条件同时成立才算命中（AND 语义） */
  matchConditions(rule: Rule): boolean {
    for (let i = 0; i < rule.conditions.length; i++) {
      const c: Condition = rule.conditions[i];
      const value = this.readSource(c.sourceId, c.attr);
      if (Number.isNaN(value) || !this.evaluate(value, c.op, c.value)) {
        return false;
      }
    }
    return true;
  }

  /**
   * 冲突消解：按优先级从高到低排序，同一"设备.属性"只能被一条规则占用，
   * 低优先级规则的目标被占用时整条规则抑制，并在日志中留下可追溯的记录。
   */
  private resolve(candidates: Candidate[],
                  rejected: Map<string, string>): Candidate[] {
    candidates.sort((a: Candidate, b: Candidate) => {
      if (b.rule.priority !== a.rule.priority) {
        return b.rule.priority - a.rule.priority;
      }
      return a.index - b.index;
    });
    const claimed: Map<string, string> = new Map<string, string>();
    const accepted: Candidate[] = [];
    for (let i = 0; i < candidates.length; i++) {
      const c = candidates[i];
      let conflict = '';
      for (let k = 0; k < c.rule.actions.length; k++) {
        const key = c.rule.actions[k].targetKey();
        if (key.length === 0) {
          continue;
        }
        const owner = claimed.get(key);
        if (owner !== undefined && owner !== c.rule.id) {
          const act = c.rule.actions[k];
          const dev = this.deviceService.find(act.targetId);
          const name = dev !== undefined ? dev.name : act.targetId;
          conflict = `${name}${this.attrText(act.attr)} 已被「${owner}」占用`;
          break;
        }
      }
      if (conflict.length > 0) {
        rejected.set(c.rule.id, conflict);
        continue;
      }
      for (let k = 0; k < c.rule.actions.length; k++) {
        const key = c.rule.actions[k].targetKey();
        if (key.length > 0) {
          claimed.set(key, c.rule.id);
        }
      }
      accepted.push(c);
    }
    return accepted;
  }

  /** 顺序执行动作，delay 以仿真时间累加，notify 走系统通知 */
  private execute(rule: Rule, clock: string): string[] {
    const done: string[] = [];
    let delaySec = 0;
    for (let i = 0; i < rule.actions.length; i++) {
      const a: Action = rule.actions[i];
      if (a.kind === ActionKind.Delay) {
        delaySec += a.seconds;
        done.push(`延时 ${a.seconds}s`);
        continue;
      }
      if (a.kind === ActionKind.Notify) {
        done.push(`通知「${a.message}」`);
        continue;
      }
      const target = this.deviceService.find(a.targetId);
      if (target === undefined || !target.online) {
        done.push(`${a.targetId} 离线，动作跳过`);
        continue;
      }
      this.deviceService.setAttr(a.targetId, a.attr, a.value);
      done.push(this.actionText(target, a));
    }
    this.logService.append(clock, LogLevel.Fire, rule.name,
      `执行 ${done.join('；')}${delaySec > 0 ? `，共延时 ${delaySec}s` : ''}`);
    return done;
  }

  private attrText(attr: string): string {
    if (attr === 'power') {
      return '开关';
    }
    if (attr === 'level') {
      return '档位';
    }
    if (attr === 'targetTemp') {
      return '目标温度';
    }
    return '读数';
  }

  /** 把动作翻译成人类可读的一句话，写入日志 */
  private actionText(d: DeviceState, a: Action): string {
    if (a.attr === 'power') {
      return a.value > 0 ? `打开${d.name}` : `关闭${d.name}`;
    }
    if (a.attr === 'targetTemp') {
      return `${d.name}目标温度→${a.value}℃`;
    }
    if (d.type === DeviceType.Fan) {
      return `${d.name}风速→${a.value}%`;
    }
    if (d.type === DeviceType.Curtain) {
      return `${d.name}开合→${a.value}%`;
    }
    return `${d.name}亮度→${a.value}%`;
  }

  /** 手动执行（场景按钮）：跳过触发匹配，仍做条件与冷却校验 */
  runManual(rule: Rule, nowMs: number): RuleVerdict {
    if (!rule.enabled) {
      return new RuleVerdict(rule.id, rule.name, rule.priority,
        FireResult.Disabled, '规则已停用');
    }
    if (rule.inCooldown(nowMs)) {
      return new RuleVerdict(rule.id, rule.name, rule.priority,
        FireResult.Cooling, '冷却中');
    }
    if (!this.matchConditions(rule)) {
      return new RuleVerdict(rule.id, rule.name, rule.priority,
        FireResult.ConditionFailed, '条件不满足');
    }
    this.execute(rule, this.clock());
    rule.lastFiredAt = nowMs;
    rule.fireCount++;
    return new RuleVerdict(rule.id, rule.name, rule.priority,
      FireResult.Fired, '已执行');
  }

  /**
   * 一轮仿真：推进环境 → 差分出变化属性 → 收集候选 → 消解 → 执行
   */
  runCycle(rules: Rule[], nowMs: number): CycleReport {
    const report = new CycleReport();
    this.tickCount++;
    report.tick = this.tickCount;

    // 1. 推进一分钟仿真并差分设备状态
    const before: Map<string, number> = new Map<string, number>();
    this.deviceService.devices.forEach((d: DeviceState) => {
      before.set(`${d.id}.power`, d.power ? 1 : 0);
      before.set(`${d.id}.level`, d.level);
      before.set(`${d.id}.value`, d.value);
    });
    this.envService.simulateStep(this.deviceService.devices, 1);
    const changed: Set<string> = new Set<string>();
    this.deviceService.devices.forEach((d: DeviceState) => {
      if (before.get(`${d.id}.power`) !== (d.power ? 1 : 0)) {
        changed.add(`${d.id}.power`);
      }
      if (before.get(`${d.id}.level`) !== d.level) {
        changed.add(`${d.id}.level`);
      }
      if (before.get(`${d.id}.value`) !== d.value) {
        changed.add(`${d.id}.value`);
      }
    });

    // 2. 收集候选
    const candidates: Candidate[] = [];
    for (let i = 0; i < rules.length; i++) {
      const r = rules[i];
      if (!r.enabled) {
        continue;
      }
      report.checked++;
      if (!this.matchTrigger(r, changed, '')) {
        continue;
      }
      if (!this.matchConditions(r)) {
        report.verdicts.push(new RuleVerdict(r.id, r.name, r.priority,
          FireResult.ConditionFailed, '触发命中但条件不满足'));
        continue;
      }
      if (r.inCooldown(nowMs)) {
        report.verdicts.push(new RuleVerdict(r.id, r.name, r.priority,
          FireResult.Cooling, `冷却中（${r.cooldownSec}s）`));
        continue;
      }
      candidates.push(new Candidate(r, i));
    }

    // 3. 消解 + 执行
    const rejected: Map<string, string> = new Map<string, string>();
    const accepted = this.resolve(candidates, rejected);
    candidates.forEach((c: Candidate) => {
      const reason = rejected.get(c.rule.id);
      if (reason !== undefined) {
        report.suppressed++;
        this.logService.append(this.clock(), LogLevel.Suppressed,
          c.rule.name, `优先级冲突：${reason}，本轮动作已抑制`);
        report.verdicts.push(new RuleVerdict(c.rule.id, c.rule.name,
          c.rule.priority, FireResult.Suppressed, reason));
      }
    });
    accepted.forEach((c: Candidate) => {
      this.execute(c.rule, this.clock());
      c.rule.lastFiredAt = nowMs;
      c.rule.fireCount++;
      report.fired++;
      report.verdicts.push(new RuleVerdict(c.rule.id, c.rule.name,
        c.rule.priority, FireResult.Fired, '已执行'));
    });

    // 4. 能耗与曲线采样
    let watt = 0;
    this.deviceService.devices.forEach((d: DeviceState) => {
      watt += d.currentWatt();
    });
    this.metrics.accumulate(watt, 1);
    if (this.tickCount % 5 === 0) {
      this.metrics.sample(this.envService.state.comfort);
    }
    this.deviceService.captureSnapshot();
    return report;
  }
}
