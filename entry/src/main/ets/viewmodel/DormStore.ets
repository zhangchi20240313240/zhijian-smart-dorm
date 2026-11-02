/**
 * 应用状态中枢：装配各服务、驱动仿真时钟、维护持久化快照
 * 路径：entry/src/main/ets/viewmodel/DormStore.ets
 */
import { common } from '@kit.AbilityKit';
import { DeviceState, DeviceJson } from '../model/DeviceModel';
import { Rule, RuleJson } from '../model/RuleModel';
import { DeviceService } from '../service/DeviceService';
import { EnvironmentService } from '../service/EnvironmentService';
import { LogService, LogEntry, LogJson, LogLevel, MetricsService } from '../service/LogService';
import { RuleEngine, CycleReport } from '../service/RuleEngine';
import { StoreService } from '../service/StoreService';
import { buildDevices, buildRules } from '../mock/MockSeed';

interface SnapshotJson {
  version: number;
  savedAt: number;
  minuteOfDay: number;
  devices: DeviceJson[];
  rules: RuleJson[];
  logs: LogJson[];
  todayWh: number;
  comfortSeries: number[];
  energySeries: number[];
}

export class DormStore {
  static readonly instance: DormStore = new DormStore();

  deviceService: DeviceService = new DeviceService();
  envService: EnvironmentService = new EnvironmentService();
  logService: LogService = new LogService();
  metrics: MetricsService = new MetricsService();
  engine: RuleEngine = new RuleEngine(this.deviceService, this.envService, this.logService, this.metrics);
  store: StoreService = new StoreService();

  rules: Rule[] = [];
  private timerId: number = -1;
  private saveTimer: number = -1;
  private restored: boolean = false;

  async init(context: common.UIAbilityContext): Promise<void> {
    await this.store.init(context);
    const raw = await this.store.load();
    if (raw.length > 0) {
      this.restore(raw);
      this.restored = true;
      this.logService.append(this.envService.state.clockText(), LogLevel.Info,
        '系统', `已从本地恢复 ${this.deviceService.devices.length} 台设备、${this.rules.length} 条规则`);
    } else {
      this.deviceService.load(buildDevices());
      this.rules = buildRules();
      this.logService.append(this.envService.state.clockText(), LogLevel.Info,
        '系统', '首次启动，已写入 12 台 Mock 设备与 9 条规则');
    }
    this.envService.refresh(this.deviceService.devices);
    this.syncAppStorage();
  }

  isRestored(): boolean {
    return this.restored;
  }

  start(): void {
    if (this.timerId >= 0) {
      return;
    }
    this.timerId = setInterval(() => {
      this.tick();
    }, 3000);
  }

  stop(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /** 每个计时周期推进 1 个仿真分钟 */
  tick(): CycleReport {
    const report = this.engine.runCycle(this.rules, Date.now());
    this.syncSensors();
    this.syncAppStorage();
    this.scheduleSave();
    return report;
  }

  /** 环境量回写到传感器设备，使触发器与页面显示同源 */
  syncSensors(): void {
    const env = this.envService.state;
    const t = this.deviceService.find('sensor.temp');
    if (t !== undefined) {
      t.value = env.temperature;
    }
    const h = this.deviceService.find('sensor.hum');
    if (h !== undefined) {
      h.value = env.humidity;
    }
    const l = this.deviceService.find('sensor.lux');
    if (l !== undefined) {
      l.value = env.lux;
    }
  }

  toggleDevice(id: string): void {
    this.deviceService.toggle(id);
    this.envService.refresh(this.deviceService.devices);
    this.syncAppStorage();
    this.scheduleSave();
  }

  setLevel(id: string, value: number): void {
    this.deviceService.setAttr(id, 'level', value);
    this.envService.refresh(this.deviceService.devices);
    this.syncAppStorage();
    this.scheduleSave();
  }

  setPresence(present: boolean): void {
    this.envService.setPresence(this.deviceService.devices, present);
    this.logService.append(this.envService.state.clockText(), LogLevel.Info, '传感器', present ? '检测到人体' : '未检测到人体');
    this.tick();
  }

  runScene(ruleId: string): void {
    const rule = this.rules.find((r: Rule) => r.id === ruleId);
    if (rule !== undefined) {
      this.engine.runManual(rule, Date.now());
      this.syncAppStorage();
      this.scheduleSave();
    }
  }

  toggleRule(ruleId: string): void {
    const rule = this.rules.find((r: Rule) => r.id === ruleId);
    if (rule !== undefined) {
      rule.enabled = !rule.enabled;
      this.syncAppStorage();
      this.scheduleSave();
    }
  }

  updateRule(rule: Rule): void {
    const idx = this.rules.findIndex((r: Rule) => r.id === rule.id);
    if (idx >= 0) {
      this.rules[idx] = rule;
      this.logService.append(this.envService.state.clockText(), LogLevel.Info, '规则', `已保存「${rule.name}」`);
      this.syncAppStorage();
      this.scheduleSave();
    }
  }

  /** 页面展示用：把最新状态推到 AppStorage，由 @StorageLink 驱动刷新 */
  syncAppStorage(): void {
    const env = this.envService.state;
    AppStorage.setOrCreate('envTemp', env.temperature);
    AppStorage.setOrCreate('envHum', env.humidity);
    AppStorage.setOrCreate('envLux', env.lux);
    AppStorage.setOrCreate('comfort', env.comfort);
    AppStorage.setOrCreate('clockText', env.clockText());
    AppStorage.setOrCreate('activeCount', this.deviceService.activeCount());
    AppStorage.setOrCreate('onlineCount', this.deviceService.onlineCount());
    AppStorage.setOrCreate('todayWh', Math.round(this.metrics.todayWh * 10) / 10);
    AppStorage.setOrCreate('fireCount', this.logService.fireCount());
    AppStorage.setOrCreate('devicesVersion', Date.now());
    AppStorage.setOrCreate('logVersion', this.logService.entries.length);
    AppStorage.setOrCreate('presence', this.envService.isPresence(this.deviceService.devices));
  }

  /** 800 ms 防抖，避免每个 tick 都写盘 */
  private scheduleSave(): void {
    if (this.saveTimer >= 0) {
      clearTimeout(this.saveTimer);
    }
    this.saveTimer = setTimeout(() => {
      this.save();
    }, 800);
  }

  async save(): Promise<void> {
    const snap: SnapshotJson = {
      version: 1,
      savedAt: Date.now(),
      minuteOfDay: this.envService.state.minuteOfDay,
      devices: this.deviceService.devices.map((d: DeviceState) => d.toJson()),
      rules: this.rules.map((r: Rule) => r.toJson()),
      logs: this.logService.entries.slice(0, 60).map((e: LogEntry) => e.toJson()),
      todayWh: this.metrics.todayWh,
      comfortSeries: this.metrics.comfortSeries,
      energySeries: this.metrics.energySeries
    };
    await this.store.save(JSON.stringify(snap));
    AppStorage.setOrCreate('lastSavedAt', snap.savedAt);
  }

  restore(json: string): void {
    try {
      const snap = JSON.parse(json) as SnapshotJson;
      this.deviceService.load(snap.devices.map((d: DeviceJson) => DeviceState.fromJson(d)));
      this.rules = snap.rules.map((r: RuleJson) => Rule.fromJson(r));
      this.logService.entries = snap.logs.map((l: LogJson) => LogEntry.fromJson(l));
      this.envService.state.minuteOfDay = snap.minuteOfDay;
      this.metrics.todayWh = snap.todayWh;
      this.metrics.comfortSeries = snap.comfortSeries;
      this.metrics.energySeries = snap.energySeries;
    } catch (err) {
      this.deviceService.load(buildDevices());
      this.rules = buildRules();
      this.logService.append('--:--', LogLevel.Error, '系统', '快照损坏，已回退到默认配置');
    }
  }
}
