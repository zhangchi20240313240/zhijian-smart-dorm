import { LogEntry, LogLevel } from '../service/LogService';
import { DormStore } from '../viewmodel/DormStore';

@Component
export struct LogView {
  @Consume('store') store: DormStore;
  @StorageLink('logVersion') logVersion: number = 0;
  @State filter: string = 'all';

  private color(level: LogLevel): string {
    if (level === LogLevel.Fire) {
      return '#0E9F6E';
    }
    if (level === LogLevel.Suppressed) {
      return '#E08A00';
    }
    if (level === LogLevel.Error) {
      return '#D64545';
    }
    return '#7C8595';
  }

  private label(level: LogLevel): string {
    if (level === LogLevel.Fire) {
      return '执行';
    }
    if (level === LogLevel.Suppressed) {
      return '抑制';
    }
    if (level === LogLevel.Error) {
      return '异常';
    }
    return '记录';
  }

  private visible(): LogEntry[] {
    if (this.filter === 'all') {
      return this.store.logService.entries;
    }
    return this.store.logService.entries.filter((e: LogEntry) => e.level === this.filter);
  }

  @Builder
  chip(text: string, key: string) {
    Text(text)
      .fontSize(12)
      .fontColor(this.filter === key ? '#FFFFFF' : '#5B6472')
      .backgroundColor(this.filter === key ? '#2E5BFF' : '#FFFFFF')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(14)
      .onClick(() => {
        this.filter = key;
      })
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('运行记录').fontSize(20).fontWeight(FontWeight.Bold)
        Blank()
        Text(`执行 ${this.store.logService.fireCount()} · 抑制 ${this.store.logService.suppressedCount()}`)
          .fontSize(11).fontColor('#7C8595')
      }.width('100%')

      Row({ space: 8 }) {
        this.chip('全部', 'all')
        this.chip('执行', LogLevel.Fire)
        this.chip('抑制', LogLevel.Suppressed)
      }.width('100%')

      List({ space: 8 }) {
        ForEach(this.visible(), (item: LogEntry) => {
          ListItem() {
            Row({ space: 10 }) {
              Column() {
                Text(item.timeText).fontSize(12).fontColor('#5B6472')
                Text(this.label(item.level)).fontSize(10).fontColor(this.color(item.level))
              }.width(52).alignItems(HorizontalAlign.Start)

              Column({ space: 3 }) {
                Text(item.ruleName).fontSize(13).fontWeight(FontWeight.Medium)
                Text(item.message).fontSize(12).fontColor('#7C8595')
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }
            .padding(12)
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .border({ width: { left: 3 }, color: this.color(item.level) })
          }
        }, (item: LogEntry) => item.id)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .padding(16)
    .width('100%')
    .height('100%')
    .backgroundColor('#F1F3F5')
  }
}
