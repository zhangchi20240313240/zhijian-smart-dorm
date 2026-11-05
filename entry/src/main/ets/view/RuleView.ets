import { Rule } from '../model/RuleModel';
import { DormStore } from '../viewmodel/DormStore';
import { RuleCard } from '../components/RuleCard';

@Component
export struct RuleView {
  @Consume('store') store: DormStore;

  private autoRules(): Rule[] {
    return this.store.rules.filter((r: Rule) => r.sceneId.length === 0);
  }

  private scenes(): Rule[] {
    return this.store.rules.filter((r: Rule) => r.sceneId.length > 0);
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Row() {
          Column({ space: 2 }) {
            Text('规则中心').fontSize(20).fontWeight(FontWeight.Bold)
            Text(`${this.autoRules().length} 条自动化 · ${this.scenes().length} 个场景`)
              .fontSize(12).fontColor('#7C8595')
          }.alignItems(HorizontalAlign.Start)
          Blank()
          Button('新建')
            .fontSize(13)
            .height(32)
            .backgroundColor('#2E5BFF')
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/RuleEditorPage', params: { ruleId: '' } });
            })
        }
        .width('100%')

        Text('自动化规则').fontSize(13).fontColor('#7C8595').width('100%')
        ForEach(this.autoRules(), (item: Rule) => {
          RuleCard({ rule: item })
        }, (item: Rule) => `${item.id}-${item.enabled}-${item.fireCount}`)

        Text('手动场景').fontSize(13).fontColor('#7C8595').width('100%')
        ForEach(this.scenes(), (item: Rule) => {
          RuleCard({ rule: item })
        }, (item: Rule) => `${item.id}-${item.enabled}`)
      }
      .padding(16)
      .width('100%')
    }
    .backgroundColor('#F1F3F5')
    .width('100%')
    .height('100%')
  }
}
