import { DormStore } from '../viewmodel/DormStore';

/**
 * 统计页：能耗柱状图 + 舒适度曲线，纯 Canvas 绘制，无第三方图表库
 */
@Component
export struct StatisticsView {
  @Consume('store') store: DormStore;
  @StorageLink('todayWh') todayWh: number = 0;
  @StorageLink('comfort') comfort: number = 0;
  @StorageLink('lastSavedAt') lastSavedAt: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private draw(): void {
    const w = this.ctx.width;
    const h = 180;
    const energy = this.store.metrics.energySeries;
    const comfort = this.store.metrics.comfortSeries;
    this.ctx.clearRect(0, 0, w, h);
    if (energy.length < 2) {
      this.ctx.fillStyle = '#9AA3B2';
      this.ctx.font = '12vp sans-serif';
      this.ctx.fillText('正在采样…', 12, 24);
      return;
    }
    const maxWh = Math.max(...energy, 1);
    const barW = (w - 40) / energy.length * 0.55;
    // 能耗柱
    energy.forEach((v: number, i: number) => {
      const x = 20 + i * (w - 40) / energy.length;
      const bh = v / maxWh * 120;
      this.ctx.fillStyle = 'rgba(46,91,255,0.18)';
      this.ctx.fillRect(x, h - 30 - bh, barW, bh);
    });
    // 舒适度折线
    this.ctx.beginPath();
    comfort.forEach((v: number, i: number) => {
      const x = 20 + i * (w - 40) / comfort.length;
      const y = h - 30 - (v / 100) * 120;
      if (i === 0) {
        this.ctx.moveTo(x, y);
      } else {
        this.ctx.lineTo(x, y);
      }
    });
    this.ctx.strokeStyle = '#0E9F6E';
    this.ctx.lineWidth = 2;
    this.ctx.stroke();
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Text('能耗与舒适度').fontSize(20).fontWeight(FontWeight.Bold).width('100%')

        Column({ space: 10 }) {
          Row() {
            Column({ space: 2 }) {
              Text(`${(this.todayWh / 1000).toFixed(2)}`).fontSize(30).fontWeight(FontWeight.Bold)
              Text('今日累计用电 kWh').fontSize(11).fontColor('#7C8595')
            }.alignItems(HorizontalAlign.Start)
            Blank()
            Column({ space: 2 }) {
              Text(`${this.comfort}`).fontSize(30).fontWeight(FontWeight.Bold).fontColor('#0E9F6E')
              Text('实时舒适度').fontSize(11).fontColor('#7C8595')
            }.alignItems(HorizontalAlign.End)
          }.width('100%')

          Canvas(this.ctx)
            .width('100%')
            .height(180)
            .onReady(() => this.draw())
        }
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(18)

        Column({ space: 8 }) {
          Text('数据恢复').fontSize(15).fontWeight(FontWeight.Bold)
          Text(`最近一次本地快照：${this.lastSavedAt > 0 ? new Date(this.lastSavedAt).toLocaleString() : '暂无'}`)
            .fontSize(12).fontColor('#7C8595')
          Text(`设备 ${this.store.deviceService.devices.length} 台 · 规则 ${this.store.rules.length} 条 · 日志 ${this.store.logService.entries.length} 条`)
            .fontSize(12).fontColor('#7C8595')
          Button('立即保存快照')
            .height(38)
            .fontSize(13)
            .backgroundColor('#EAF0FF')
            .fontColor('#2E5BFF')
            .onClick(() => {
              this.store.save();
            })
        }
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .width('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
      }
      .padding(16)
      .width('100%')
    }
    .backgroundColor('#F1F3F5')
    .width('100%')
    .height('100%')
  }
}
