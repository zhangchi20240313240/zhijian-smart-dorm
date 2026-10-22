/**
 * 设备数据模型
 * 路径：entry/src/main/ets/model/DeviceModel.ets
 */
export enum DeviceType {
  Light = 'light',
  AirConditioner = 'ac',
  Curtain = 'curtain',
  Humidifier = 'humidifier',
  Fan = 'fan',
  Socket = 'plug',
  Sensor = 'sensor'
}

export enum DeviceAttr {
  Power = 'power',
  Level = 'level',
  TargetTemp = 'targetTemp',
  Mode = 'mode',
  Value = 'value'
}

export interface DeviceJson {
  id: string;
  name: string;
  type: string;
  room: string;
  online: boolean;
  power: boolean;
  level: number;
  targetTemp: number;
  value: number;
  unit: string;
  posX: number;
  posY: number;
}

/**
 * 单个设备的状态快照。所有可被规则读写的量都收敛到 readAttr / writeAttr，
 * 规则引擎因此不需要知道设备的具体品类，只面向"属性"编程。
 */
@Observed
export class DeviceState {
  id: string = '';
  name: string = '';
  type: DeviceType = DeviceType.Light;
  room: string = '';
  online: boolean = true;
  power: boolean = false;
  level: number = 0;        // 亮度 / 开合度 / 风速，统一 0—100
  targetTemp: number = 26;  // 空调目标温度，16—30 ℃
  value: number = 0;        // 传感器读数
  unit: string = '';
  ratedWatt: number = 0;    // 额定功率，用于能耗估算
  posX: number = 0;         // 平面图坐标（vp）
  posY: number = 0;

  constructor(id: string, name: string, type: DeviceType, room: string,
              posX: number, posY: number, ratedWatt: number, unit: string = '') {
    this.id = id;
    this.name = name;
    this.type = type;
    this.room = room;
    this.posX = posX;
    this.posY = posY;
    this.ratedWatt = ratedWatt;
    this.unit = unit;
  }

  isSensor(): boolean {
    return this.type === DeviceType.Sensor;
  }

  /** 读属性：power 归一化为 0/1，便于与其他数值属性统一比较 */
  readAttr(attr: string): number {
    if (attr === DeviceAttr.Power) {
      return this.power ? 1 : 0;
    }
    if (attr === DeviceAttr.Level) {
      return this.level;
    }
    if (attr === DeviceAttr.TargetTemp) {
      return this.targetTemp;
    }
    return this.value;
  }

  /** 写属性：统一做上下界裁剪，非法写入返回 false 由调用方记入日志 */
  writeAttr(attr: string, v: number): boolean {
    if (!this.online || this.isSensor()) {
      return false;
    }
    if (attr === DeviceAttr.Power) {
      this.power = v > 0;
      if (this.power && this.level === 0) {
        this.level = 60;
      }
      return true;
    }
    if (attr === DeviceAttr.Level) {
      this.level = Math.max(0, Math.min(100, Math.round(v)));
      this.power = this.level > 0;
      return true;
    }
    if (attr === DeviceAttr.TargetTemp) {
      this.targetTemp = Math.max(16, Math.min(30, Math.round(v)));
      return true;
    }
    return false;
  }

  /** 当前实际功率，用于能耗累计 */
  currentWatt(): number {
    if (this.isSensor()) {
      return 0;
    }
    if (!this.power) {
      return this.online ? 0.6 : 0;
    }
    if (this.type === DeviceType.Light) {
      return this.ratedWatt * this.level / 100;
    }
    if (this.type === DeviceType.Fan) {
      return this.ratedWatt * (30 + 70 * this.level / 100) / 100;
    }
    return this.ratedWatt;
  }

  toJson(): DeviceJson {
    const j: DeviceJson = {
      id: this.id, name: this.name, type: this.type, room: this.room,
      online: this.online, power: this.power, level: this.level,
      targetTemp: this.targetTemp, value: this.value, unit: this.unit,
      posX: this.posX, posY: this.posY
    };
    return j;
  }

  static fromJson(j: DeviceJson): DeviceState {
    const d = new DeviceState(j.id, j.name, j.type as DeviceType, j.room, j.posX, j.posY, 0, j.unit);
    d.online = j.online;
    d.power = j.power;
    d.level = j.level;
    d.targetTemp = j.targetTemp;
    d.value = j.value;
    return d;
  }
}
