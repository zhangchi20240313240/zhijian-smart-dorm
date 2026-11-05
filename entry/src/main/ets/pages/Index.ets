import { DormStore } from '../viewmodel/DormStore';
import { HomeView } from '../view/HomeView';
import { SceneView } from '../view/SceneView';
import { RuleView } from '../view/RuleView';
import { LogView } from '../view/LogView';
import { StatisticsView } from '../view/StatisticsView';

@Entry
@Component
struct Index {
  @Provide('store') store: DormStore = DormStore.instance;
  @State currentIndex: number = 0;

  @Builder
  tabBar(title: string, icon: string, index: number) {
    Column({ space: 3 }) {
      Text(icon)
        .fontSize(19)
        .fontColor(this.currentIndex === index ? '#2E5BFF' : '#9AA3B2')
      Text(title)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? '#2E5BFF' : '#9AA3B2')
    }
    .width('100%')
    .height(52)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        HomeView()
      }.tabBar(this.tabBar('总览', '◉', 0))

      TabContent() {
        SceneView()
      }.tabBar(this.tabBar('场景', '▣', 1))

      TabContent() {
        RuleView()
      }.tabBar(this.tabBar('规则', '⚙', 2))

      TabContent() {
        LogView()
      }.tabBar(this.tabBar('记录', '≡', 3))

      TabContent() {
        StatisticsView()
      }.tabBar(this.tabBar('统计', '◫', 4))
    }
    .barHeight(56)
    .barMode(BarMode.Fixed)
    .onChange((index: number) => {
      this.currentIndex = index;
    })
    .backgroundColor('#F1F3F5')
    .width('100%')
    .height('100%')
  }
}
