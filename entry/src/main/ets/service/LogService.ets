/**
 * 运行日志与能耗统计
 * 路径：entry/src/main/ets/service/LogService.ets
 */
export enum LogLevel {
  Info = 'info',
  Fire = 'fire',
  Suppressed = 'suppressed',
  Error = 'error'
}

export interface LogJson {
  id: string;
  timeText: string;
  level: string;
  ruleName: string;
  message: string;
}

export class LogEntry {
  id: string = '';
  timeText: string = '';
  level: LogLevel = LogLevel.Info;
  ruleName: string = '';
  message: string = '';

  constructor(id: string, timeText: string, level: LogLevel, ruleName: string, message: string) {
    this.id = id;
    this.timeText = timeText;
    this.level = level;
    this.ruleName = ruleName;
    this.message = message;
  }

  toJson(): LogJson {
    const j: LogJson = {
      id: this.id, timeText: this.timeText, level: this.level,
      ruleName: this.ruleName, message: this.message
    };
    return j;
  }

  static fromJson(j: LogJson): LogEntry {
    return new LogEntry(j.id, j.timeText, j.level as LogLevel, j.ruleName, j.message);
  }
}

export class LogService {
  readonly MAX_KEEP: number = 200;
  entries: LogEntry[] = [];
  private seq: number = 0;

  append(clock: string, level: LogLevel, ruleName: string, message: string): LogEntry {
    this.seq++;
    const e = new LogEntry(`L${this.seq}`, clock, level, ruleName, message);
    this.entries.unshift(e);
    if (this.entries.length > this.MAX_KEEP) {
      this.entries = this.entries.slice(0, this.MAX_KEEP);
    }
    return e;
  }

  fireCount(): number {
    return this.entries.filter((e: LogEntry) => e.level === LogLevel.Fire).length;
  }

  suppressedCount(): number {
    return this.entries.filter((e: LogEntry) => e.level === LogLevel.Suppressed).length;
  }

  clear(): void {
    this.entries = [];
  }
}

/** 能耗与舒适度曲线：每 5 个仿真分钟采样一次，保留最近 24 个点 */
export class MetricsService {
  energyWh: number = 0;
  todayWh: number = 0;
  comfortSeries: number[] = [];
  energySeries: number[] = [];
  private bucketWh: number = 0;

  accumulate(watt: number, minutes: number): void {
    const wh = watt * minutes / 60;
    this.energyWh += wh;
    this.todayWh += wh;
    this.bucketWh += wh;
  }

  sample(comfort: number): void {
    this.energySeries.push(Math.round(this.bucketWh * 100) / 100);
    this.comfortSeries.push(comfort);
    this.bucketWh = 0;
    if (this.comfortSeries.length > 24) {
      this.comfortSeries.shift();
      this.energySeries.shift();
    }
  }

  averageComfort(): number {
    if (this.comfortSeries.length === 0) {
      return 0;
    }
    let sum = 0;
    this.comfortSeries.forEach((v: number) => {
      sum += v;
    });
    return Math.round(sum / this.comfortSeries.length);
  }
}
