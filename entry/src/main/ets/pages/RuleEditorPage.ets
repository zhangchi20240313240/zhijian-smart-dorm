import { Rule, Trigger, Condition, Action, TriggerKind, CompareOp, ActionKind } from '../model/RuleModel';
import { DormStore } from '../viewmodel/DormStore';
import { triggerText, opText } from '../components/RuleCard';

@Component
export struct RuleEditorPage {
  @Consume('store') store: DormStore;
  @State draft: Rule = new Rule('', '新规则', 5);
  @State saved: boolean = false;
  private ruleId: string = '';

  aboutToAppear(): void {
    const param = this.getUIContext().getRouter().getParams() as Record<string, string>;
    if (param !== undefined && param.ruleId !== undefined) {
      this.ruleId = param.ruleId;
    }
    const exist = this.store.rules.find((r: Rule) => r.id === this.ruleId);
    this.draft = exist !== undefined ? exist : this.buildNewRule();
  }

  private buildNewRule(): Rule {
    const r = new Rule(`rule.${Date.now()}`, '新规则', 5);
    r.cooldownSec = 60;
    r.triggers.push(new Trigger(TriggerKind.Device, 'sensor.pir', 'value', CompareOp.Eq, 1));
    r.conditions.push(new Condition('sensor.lux', 'value', CompareOp.Lt, 120));
    r.actions.push(new Action(ActionKind.SetAttr, 'light.main', 'power', 1));
    r.actions.push(new Action(ActionKind.SetAttr, 'light.main', 'level', 60));
    return r;
  }

  @Builder
  sectionTitle(title: string, count: number) {
    Row() {
      Text(title).fontSize(14).fontWeight(FontWeight.Bold)
      Text(` ${count}`).fontSize(11).fontColor('#9AA3B2')
      Blank()
      Text('+ 添加').fontSize(12).fontColor('#2E5BFF')
    }.width('100%')
  }

  @Builder
  triggerRow(t: Trigger, index: number) {
    Row({ space: 8 }) {
      Text(triggerText(t)).fontSize(13).layoutWeight(1)
      Text('删除').fontSize(11).fontColor('#D64545')
        .onClick(() => {
          this.draft.triggers.splice(index, 1);
          this.draft.triggers = this.draft.triggers.slice();
        })
    }
    .padding(12)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  conditionRow(c: Condition, index: number) {
    Row({ space: 8 }) {
      Text(`${c.sourceId} ${c.attr} ${opText(c.op)} ${c.value}`).fontSize(13).layoutWeight(1)
      Text('删除').fontSize(11).fontColor('#D64545')
        .onClick(() => {
          this.draft.conditions.splice(index, 1);
          this.draft.conditions = this.draft.conditions.slice();
        })
    }
    .padding(12)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  actionRow(a: Action, index: number) {
    Row({ space: 8 }) {
      Text(a.kind === ActionKind.SetAttr ? `设置 ${a.targetId}.${a.attr} = ${a.value}`
        : (a.kind === ActionKind.Delay ? `延时 ${a.seconds}s` : `通知「${a.message}」`))
        .fontSize(13).layoutWeight(1)
      Text('删除').fontSize(11).fontColor('#D64545')
        .onClick(() => {
          this.draft.actions.splice(index, 1);
          this.draft.actions = this.draft.actions.slice();
        })
    }
    .padding(12)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('‹').fontSize(24).fontColor('#1B1F27')
          .onClick(() => this.getUIContext().getRouter().back())
        Text('规则编辑').fontSize(17).fontWeight(FontWeight.Bold).layoutWeight(1)
        Text(this.saved ? '已保存' : '未保存').fontSize(11).fontColor(this.saved ? '#0E9F6E' : '#9AA3B2')
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column({ space: 14 }) {
          TextInput({ text: this.draft.name, placeholder: '规则名称' })
            .height(46)
            .borderRadius(12)
            .onChange((v: string) => {
              this.draft.name = v;
            })

          this.sectionTitle('触发', this.draft.triggers.length)
          ForEach(this.draft.triggers, (t: Trigger, i: number) => {
            this.triggerRow(t, i)
          }, (t: Trigger) => `${t.sourceId}${t.attr}${i0(t)}`)

          this.sectionTitle('条件', this.draft.conditions.length)
          ForEach(this.draft.conditions, (c: Condition, i: number) => {
            this.conditionRow(c, i)
          }, (c: Condition) => `${c.sourceId}${c.attr}`)

          this.sectionTitle('动作', this.draft.actions.length)
          ForEach(this.draft.actions, (a: Action, i: number) => {
            this.actionRow(a, i)
          }, (a: Action) => `${a.targetId}${a.attr}`)

          Column({ space: 10 }) {
            Row() {
              Text('优先级').fontSize(13)
              Blank()
              Text(`${this.draft.priority}`).fontSize(14).fontColor('#2E5BFF')
            }.width('100%')
            Slider({ value: this.draft.priority, min: 1, max: 9, step: 1 })
              .onChange((v: number) => {
                this.draft.priority = v;
              })
            Row() {
              Text('冷却时间').fontSize(13)
              Blank()
              Counter() {
                Text(`${this.draft.cooldownSec}s`).fontSize(13)
              }
              .onInc(() => {
                this.draft.cooldownSec += 30;
              })
              .onDec(() => {
                this.draft.cooldownSec = Math.max(0, this.draft.cooldownSec - 30);
              })
            }.width('100%')
          }
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)

          Text('优先级数值越大越先执行；多个规则同时控制同一设备属性时，低优先级动作会被抑制并记入日志。')
            .fontSize(11).fontColor('#9AA3B2').width('100%')
        }
        .padding({ left: 16, right: 16, bottom: 100 })
      }
      .layoutWeight(1)

      Row({ space: 10 }) {
        Button('试运行')
          .layoutWeight(1)
          .height(44)
          .backgroundColor('#EAF0FF')
          .fontColor('#2E5BFF')
          .onClick(() => {
            const verdict = this.store.engine.runManual(this.draft, Date.now());
            this.getUIContext().getPromptAction().showToast({
              message: verdict.result === 'fired' ? `执行成功：${verdict.reason}` : `未执行：${verdict.reason}`
            });
          })
        Button('保存')
          .layoutWeight(1)
          .height(44)
          .backgroundColor('#2E5BFF')
          .onClick(() => {
            this.store.updateRule(this.draft);
            this.saved = true;
            this.getUIContext().getPromptAction().showToast({ message: '规则已保存' });
          })
      }
      .padding({ left: 16, right: 16, top: 10, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F1F3F5')
  }
}

function i0(t: Trigger): string {
  return `${t.value}`;
}
