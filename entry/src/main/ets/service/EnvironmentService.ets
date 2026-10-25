/**
 * 环境仿真服务：用一阶惯性模型近似室内温湿度与光照，为规则引擎提供可变化的环境输入。
 * 路径：entry/src/main/ets/service/EnvironmentService.ets
 */
import { DeviceState, DeviceType } from '../model/DeviceModel';

export class EnvState {
  temperature: number = 28.6;
  humidity: number = 61;
  lux: number = 145;
  outdoorTemp: number = 33;
  minuteOfDay: number = 19 * 60 + 20;  // 19:20
  comfort: number = 100;

  constructor() {
  }

  clockText(): string {
    const h = Math.floor(this.minuteOfDay / 60);
    const m = Math.floor(this.minuteOfDay % 60);
    return `${h < 10 ? '0' : ''}${h}:${m < 10 ? '0' : ''}${m}`;
  }
}

/** 环境属性的读取入口，供规则条件复用 */
export function envReadAttr(env: EnvState, presence: boolean, attr: string): number {
  if (attr === 'temperature') {
    return env.temperature;
  }
  if (attr === 'humidity') {
    return env.humidity;
  }
  if (attr === 'lux') {
    return env.lux;
  }
  if (attr === 'outdoorTemp') {
    return env.outdoorTemp;
  }
  if (attr === 'minute') {
    return env.minuteOfDay;
  }
  if (attr === 'presence') {
    return presence ? 1 : 0;
  }
  return env.comfort;
}

export class EnvironmentService {
  state: EnvState = new EnvState();

  private findDevice(devices: DeviceState[], id: string): DeviceState | undefined {
    return devices.find((d: DeviceState) => d.id === id);
  }

  /**
   * 推进 dtMin 分钟的仿真。室内温度向室外温度缓慢泄漏，空调/加热器在其上叠加调节量，
   * 湿度受加湿器与除湿影响，光照由太阳高度角与窗帘开合、灯具亮度共同决定。
   */
  simulateStep(devices: DeviceState[], dtMin: number): void {
    const env = this.state;
    env.minuteOfDay = (env.minuteOfDay + dtMin) % 1440;

    // 1. 室外温度：以 14:00 为峰值的日周期曲线
    const dayAngle = (env.minuteOfDay - 840) / 1440 * 2 * Math.PI;
    env.outdoorTemp = 28 + 5 * Math.cos(dayAngle);

    // 2. 室内温度：先向室外泄漏，再由空调/加热修正
    env.temperature += (env.outdoorTemp - env.temperature) * 0.010 * dtMin;
    const ac = this.findDevice(devices, 'ac.living');
    if (ac !== undefined && ac.power && ac.online) {
      const diff = env.temperature - ac.targetTemp;
      if (diff > 0) {
        const cool = 0.075 * dtMin * (0.6 + ac.level / 160);
        env.temperature -= Math.min(diff, cool);
      } else if (diff < -0.3) {
        const heat = 0.055 * dtMin * (0.6 + ac.level / 160);
        env.temperature += Math.min(-diff, heat);
      }
    }

    // 3. 湿度：自然回归 55%，加湿器增湿，制冷除湿
    env.humidity += (55 - env.humidity) * 0.010 * dtMin;
    const hum = this.findDevice(devices, 'hum.desk');
    if (hum !== undefined && hum.power && hum.online) {
      env.humidity += 0.30 * dtMin * hum.level / 100;
    }
    if (ac !== undefined && ac.power && ac.online) {
      env.humidity -= 0.10 * dtMin;
    }
    env.humidity = Math.max(25, Math.min(90, env.humidity));

    // 4. 光照：太阳高度角 × 窗帘开合 + 室内灯具
    const sunAngle = (env.minuteOfDay - 720) / 1440 * 2 * Math.PI;
    const daylight = Math.max(0, Math.cos(sunAngle)) * 780;
    const curtain = this.findDevice(devices, 'curtain.window');
    const openRatio = curtain !== undefined ? curtain.level / 100 : 0.4;
    let lux = daylight * (0.18 + 0.82 * openRatio);
    const mainLight = this.findDevice(devices, 'light.main');
    if (mainLight !== undefined && mainLight.power && mainLight.online) {
      lux += 190 * mainLight.level / 100;
    }
    const bedLight = this.findDevice(devices, 'light.bed');
    if (bedLight !== undefined && bedLight.power && bedLight.online) {
      lux += 70 * bedLight.level / 100;
    }
    env.lux = Math.round(lux);

    env.temperature = Math.round(env.temperature * 10) / 10;
    env.humidity = Math.round(env.humidity);
    env.comfort = this.computeComfort(env, this.isPresence(devices));
  }

  /** 舒适度：温度 25±1 ℃、湿度 50±10 % 为满分，光线不足且有人时额外扣分 */
  computeComfort(env: EnvState, presence: boolean): number {
    const tempPenalty = Math.max(0, Math.abs(env.temperature - 25) - 1) * 6;
    const humPenalty = Math.max(0, Math.abs(env.humidity - 50) - 10) * 1.2;
    let luxPenalty = 0;
    if (presence && env.lux < 120) {
      luxPenalty = (120 - env.lux) / 10;
    }
    const score = 100 - tempPenalty - humPenalty - luxPenalty;
    return Math.max(0, Math.min(100, Math.round(score)));
  }

  isPresence(devices: DeviceState[]): boolean {
    const pir = devices.find((d: DeviceState) => d.id === 'sensor.pir');
    return pir !== undefined && pir.value > 0;
  }

  /** Mock：手动触发一次"有人/无人"切换，模拟人体传感器上报 */
  setPresence(devices: DeviceState[], present: boolean): void {
    const pir = devices.find((d: DeviceState) => d.id === 'sensor.pir');
    if (pir !== undefined) {
      pir.value = present ? 1 : 0;
    }
    const door = devices.find((d: DeviceState) => d.id === 'sensor.door');
    if (door !== undefined) {
      door.value = present ? 0 : 1;
    }
  }

  /** 按当前时间与设备状态重算一次派生量，用于页面首次渲染 */
  refresh(devices: DeviceState[]): void {
    this.state.comfort = this.computeComfort(this.state, this.isPresence(devices));
    const curtain = devices.find((d: DeviceState) => d.id === 'curtain.window');
    if (curtain !== undefined && curtain.type !== DeviceType.Sensor) {
      // 保持设备与环境的弱一致：窗帘全关时室内光照不应高于 260 lx
      if (curtain.level === 0 && this.state.lux > 260) {
        this.state.lux = 260;
      }
    }
  }
}
