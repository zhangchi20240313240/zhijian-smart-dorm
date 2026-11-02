/**
 * Mock 数据：12 台设备、5 条自动化规则、4 个手动场景。首次启动时注入，之后由本地快照恢复。
 * 路径：entry/src/main/ets/mock/MockSeed.ets
 */
import { DeviceState, DeviceType } from '../model/DeviceModel';
import {
  Rule, Trigger, Condition, Action, CompareOp, TriggerKind, ActionKind
} from '../model/RuleModel';

export function buildDevices(): DeviceState[] {
  const list: DeviceState[] = [];
  list.push(new DeviceState('light.main', '主灯', DeviceType.Light, '客厅', 62, 58, 96));
  list.push(new DeviceState('light.bed', '床头灯', DeviceType.Light, '卧室', 246, 58, 12));
  list.push(new DeviceState('ac.living', '空调', DeviceType.AirConditioner, '客厅', 26, 128, 1100));
  list.push(new DeviceState('curtain.window', '窗帘', DeviceType.Curtain, '客厅', 156, 22, 5));
  list.push(new DeviceState('hum.desk', '加湿器', DeviceType.Humidifier, '卧室', 206, 214, 30));
  list.push(new DeviceState('fan.desk', '风扇', DeviceType.Fan, '卧室', 258, 156, 22));
  list.push(new DeviceState('plug.study', '学习插座', DeviceType.Socket, '书桌', 58, 246, 65));
  list.push(new DeviceState('sensor.pir', '人体传感器', DeviceType.Sensor, '客厅', 132, 104, 0, ''));
  list.push(new DeviceState('sensor.door', '门磁', DeviceType.Sensor, '玄关', 246, 262, 0, ''));
  list.push(new DeviceState('sensor.temp', '温度', DeviceType.Sensor, '客厅', 96, 128, 0, '℃'));
  list.push(new DeviceState('sensor.hum', '湿度', DeviceType.Sensor, '客厅', 96, 152, 0, '%'));
  list.push(new DeviceState('sensor.lux', '光照', DeviceType.Sensor, '客厅', 128, 62, 0, 'lx'));

  const temp = list.find((d: DeviceState) => d.id === 'sensor.temp');
  if (temp !== undefined) {
    temp.value = 28.6;
  }
  const hum = list.find((d: DeviceState) => d.id === 'sensor.hum');
  if (hum !== undefined) {
    hum.value = 61;
  }
  const lux = list.find((d: DeviceState) => d.id === 'sensor.lux');
  if (lux !== undefined) {
    lux.value = 145;
  }
  const pir = list.find((d: DeviceState) => d.id === 'sensor.pir');
  if (pir !== undefined) {
    pir.value = 1;
  }
  const curtain = list.find((d: DeviceState) => d.id === 'curtain.window');
  if (curtain !== undefined) {
    curtain.level = 45;
    curtain.power = true;
  }
  return list;
}

export function buildRules(): Rule[] {
  const rules: Rule[] = [];

  // R1 回家自动亮灯：门磁打开 + 光照不足
  const r1 = new Rule('rule.home', '回家自动亮灯', 8);
  r1.cooldownSec = 120;
  r1.triggers.push(new Trigger(TriggerKind.Device, 'sensor.door', 'value', CompareOp.Eq, 1));
  r1.conditions.push(new Condition('sensor.lux', 'value', CompareOp.Lt, 160));
  r1.conditions.push(new Condition('env', 'presence', CompareOp.Eq, 1));
  r1.actions.push(new Action(ActionKind.SetAttr, 'light.main', 'power', 1));
  r1.actions.push(new Action(ActionKind.SetAttr, 'light.main', 'level', 70));
  r1.actions.push(new Action(ActionKind.SetAttr, 'curtain.window', 'level', 65));
  rules.push(r1);

  // R2 高温自动制冷：温度超过 28 ℃ 且有人
  const r2 = new Rule('rule.cool', '高温自动制冷', 7);
  r2.cooldownSec = 300;
  r2.triggers.push(new Trigger(TriggerKind.Device, 'sensor.temp', 'value', CompareOp.Gte, 28));
  r2.conditions.push(new Condition('env', 'presence', CompareOp.Eq, 1));
  r2.conditions.push(new Condition('sensor.hum', 'value', CompareOp.Lt, 75));
  r2.actions.push(new Action(ActionKind.SetAttr, 'ac.living', 'power', 1));
  r2.actions.push(new Action(ActionKind.SetAttr, 'ac.living', 'targetTemp', 25));
  r2.actions.push(new Action(ActionKind.SetAttr, 'fan.desk', 'level', 60));
  r2.actions.push(new Action(ActionKind.Notify, '', '', 0, 0, '已开启制冷，目标 25 ℃'));
  rules.push(r2);

  // R3 无人节能：人体传感器由 1 变 0
  const r3 = new Rule('rule.away', '无人节能', 9);
  r3.cooldownSec = 60;
  r3.triggers.push(new Trigger(TriggerKind.Device, 'sensor.pir', 'value', CompareOp.Eq, 0));
  r3.actions.push(new Action(ActionKind.SetAttr, 'light.main', 'power', 0));
  r3.actions.push(new Action(ActionKind.SetAttr, 'ac.living', 'power', 0));
  r3.actions.push(new Action(ActionKind.SetAttr, 'fan.desk', 'power', 0));
  r3.actions.push(new Action(ActionKind.Delay, '', '', 0, 30));
  r3.actions.push(new Action(ActionKind.Notify, '', '', 0, 0, '房间无人，已关闭用电设备'));
  rules.push(r3);

  // R4 23:30 助眠
  const r4 = new Rule('rule.sleep', '23:30 助眠', 6);
  r4.cooldownSec = 0;
  r4.triggers.push(new Trigger(TriggerKind.Time, '', '', CompareOp.Eq, 0, 23 * 60 + 30));
  r4.actions.push(new Action(ActionKind.SetAttr, 'light.main', 'power', 0));
  r4.actions.push(new Action(ActionKind.SetAttr, 'light.bed', 'level', 25));
  r4.actions.push(new Action(ActionKind.SetAttr, 'curtain.window', 'level', 0));
  r4.actions.push(new Action(ActionKind.SetAttr, 'ac.living', 'targetTemp', 27));
  rules.push(r4);

  // R5 亮度自适应：与 R1、R3 争用 light.main.power，用于演示冲突消解
  const r5 = new Rule('rule.lux', '亮度自适应', 4);
  r5.cooldownSec = 180;
  r5.triggers.push(new Trigger(TriggerKind.Device, 'sensor.lux', 'value', CompareOp.Lt, 120));
  r5.conditions.push(new Condition('env', 'presence', CompareOp.Eq, 1));
  r5.actions.push(new Action(ActionKind.SetAttr, 'light.main', 'power', 1));
  r5.actions.push(new Action(ActionKind.SetAttr, 'light.main', 'level', 45));
  rules.push(r5);

  // R6 湿度不足加湿
  const r6 = new Rule('rule.hum', '干燥自动加湿', 3);
  r6.cooldownSec = 600;
  r6.triggers.push(new Trigger(TriggerKind.Device, 'sensor.hum', 'value', CompareOp.Lt, 40));
  r6.conditions.push(new Condition('env', 'presence', CompareOp.Eq, 1));
  r6.actions.push(new Action(ActionKind.SetAttr, 'hum.desk', 'power', 1));
  r6.actions.push(new Action(ActionKind.SetAttr, 'hum.desk', 'level', 60));
  rules.push(r6);

  // 手动场景
  const s1 = new Rule('scene.home', '回家模式', 5);
  s1.sceneId = 'scene.home';
  s1.cooldownSec = 0;
  s1.triggers.push(new Trigger(TriggerKind.Manual, '', '', CompareOp.Eq, 0));
  s1.actions.push(new Action(ActionKind.SetAttr, 'light.main', 'level', 75));
  s1.actions.push(new Action(ActionKind.SetAttr, 'ac.living', 'targetTemp', 26));
  s1.actions.push(new Action(ActionKind.SetAttr, 'curtain.window', 'level', 80));
  s1.actions.push(new Action(ActionKind.Notify, '', '', 0, 0, '欢迎回家'));
  rules.push(s1);

  const s2 = new Rule('scene.away', '离家模式', 5);
  s2.sceneId = 'scene.away';
  s2.cooldownSec = 0;
  s2.triggers.push(new Trigger(TriggerKind.Manual, '', '', CompareOp.Eq, 0));
  s2.actions.push(new Action(ActionKind.SetAttr, 'light.main', 'power', 0));
  s2.actions.push(new Action(ActionKind.SetAttr, 'light.bed', 'power', 0));
  s2.actions.push(new Action(ActionKind.SetAttr, 'ac.living', 'power', 0));
  s2.actions.push(new Action(ActionKind.SetAttr, 'curtain.window', 'level', 0));
  s2.actions.push(new Action(ActionKind.SetAttr, 'plug.study', 'power', 0));
  rules.push(s2);

  const s3 = new Rule('scene.sleep', '睡眠模式', 5);
  s3.sceneId = 'scene.sleep';
  s3.cooldownSec = 0;
  s3.triggers.push(new Trigger(TriggerKind.Manual, '', '', CompareOp.Eq, 0));
  s3.actions.push(new Action(ActionKind.SetAttr, 'light.main', 'power', 0));
  s3.actions.push(new Action(ActionKind.SetAttr, 'light.bed', 'level', 20));
  s3.actions.push(new Action(ActionKind.SetAttr, 'curtain.window', 'level', 0));
  s3.actions.push(new Action(ActionKind.SetAttr, 'ac.living', 'targetTemp', 27));
  s3.actions.push(new Action(ActionKind.Delay, '', '', 0, 20));
  s3.actions.push(new Action(ActionKind.Notify, '', '', 0, 0, '晚安，设备已进入低功耗'));
  rules.push(s3);

  const s4 = new Rule('scene.study', '自习模式', 5);
  s4.sceneId = 'scene.study';
  s4.cooldownSec = 0;
  s4.triggers.push(new Trigger(TriggerKind.Manual, '', '', CompareOp.Eq, 0));
  s4.actions.push(new Action(ActionKind.SetAttr, 'light.main', 'level', 100));
  s4.actions.push(new Action(ActionKind.SetAttr, 'plug.study', 'power', 1));
  s4.actions.push(new Action(ActionKind.SetAttr, 'fan.desk', 'level', 40));
  s4.actions.push(new Action(ActionKind.SetAttr, 'ac.living', 'targetTemp', 26));
  rules.push(s4);

  return rules;
}
