import { DeviceState, DeviceType } from '../model/DeviceModel';
import { DormStore } from '../viewmodel/DormStore';

/**
 * 场景平面图：Canvas 绘制房间与设备点位，点击命中后弹出设备控制面板
 */
@Component
export struct SceneView {
  @Consume('store') store: DormStore;
  @State selectedId: string = '';
  @StorageLink('devicesVersion') devicesVersion: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private draw(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    this.ctx.clearRect(0, 0, w, h);
    this.ctx.fillStyle = '#F7F8FB';
    this.ctx.fillRect(0, 0, w, h);

    // 墙体
    this.ctx.strokeStyle = '#C9D1E0';
    this.ctx.lineWidth = 3;
    this.ctx.strokeRect(10, 10, w - 20, h - 20);
    this.ctx.beginPath();
    this.ctx.moveTo(w * 0.60, 10);
    this.ctx.lineTo(w * 0.60, h * 0.62);
    this.ctx.stroke();

    this.ctx.font = '12vp sans-serif';
    this.ctx.fillStyle = '#B4BCCB';
    this.ctx.fillText('客厅', 18, 28);
    this.ctx.fillText('卧室', w * 0.60 + 12, 28);

    this.store.deviceService.devices.forEach((d: DeviceState) => {
      const active = d.power && !d.isSensor();
      this.ctx.beginPath();
      this.ctx.arc(d.posX, d.posY, d.id === this.selectedId ? 16 : 13, 0, Math.PI * 2);
      this.ctx.fillStyle = d.isSensor() ? '#E3E8F2' : (active ? '#2E5BFF' : '#FFFFFF');
      this.ctx.fill();
      this.ctx.lineWidth = 2;
      this.ctx.strokeStyle = d.isSensor() ? '#C2CBDB' : (active ? '#2E5BFF' : '#C2CBDB');
      this.ctx.stroke();

      this.ctx.fillStyle = active ? '#FFFFFF' : '#7C8595';
      this.ctx.font = '11vp sans-serif';
      this.ctx.fillText(d.name.substring(0, 2), d.posX - 11, d.posY + 4);
    });
  }

  private hitTest(x: number, y: number): string {
    let hit = '';
    let best = 28;
    this.store.deviceService.devices.forEach((d: DeviceState) => {
      const dist = Math.sqrt((x - d.posX) * (x - d.posX) + (y - d.posY) * (y - d.posY));
      if (dist < best) {
        best = dist;
        hit = d.id;
      }
    });
    return hit;
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('宿舍平面图').fontSize(18).fontWeight(FontWeight.Bold)
        Blank()
        Text('点击设备进行控制').fontSize(11).fontColor('#7C8595')
      }.width('100%')

      Stack() {
        Canvas(this.ctx)
          .width('100%')
          .height(360)
          .onReady(() => this.draw())
          .onClick((event: ClickEvent) => {
            const id = this.hitTest(event.x, event.y);
            if (id.length > 0) {
              this.selectedId = id;
              this.draw();
            }
          })
      }
      .width('100%')
      .borderRadius(18)
      .clip(true)

      if (this.selectedId.length > 0) {
        this.panel(this.store.deviceService.findOrThrow(this.selectedId))
      }
    }
    .padding(16)
    .width('100%')
    .height('100%')
    .backgroundColor('#F1F3F5')
  }

  @Builder
  panel(d: DeviceState) {
    Column({ space: 10 }) {
      Row() {
        Text(d.name).fontSize(16).fontWeight(FontWeight.Bold)
        Blank()
        Text(d.isSensor() ? `读数 ${d.value}${d.unit}` : (d.power ? '运行中' : '已关闭'))
          .fontSize(12).fontColor(d.power ? '#0E9F6E' : '#9AA3B2')
      }.width('100%')

      if (!d.isSensor()) {
        Row({ space: 10 }) {
          Text('开').fontSize(12).fontColor('#7C8595')
          Slider({ value: d.level, min: 0, max: 100, step: 5 })
            .layoutWeight(1)
            .onChange((v: number) => {
              this.store.setLevel(d.id, v);
            })
          Text(`${d.level}%`).fontSize(12).width(40)
        }.width('100%')
        if (d.type === DeviceType.AirConditioner) {
          Row({ space: 8 }) {
            Text('目标温度').fontSize(12).fontColor('#7C8595')
            Blank()
            Counter() {
              Text(`${d.targetTemp} ℃`).fontSize(14)
            }
            .onInc(() => this.store.deviceService.setAttr(d.id, 'targetTemp', d.targetTemp + 1))
            .onDec(() => this.store.deviceService.setAttr(d.id, 'targetTemp', d.targetTemp - 1))
          }.width('100%')
        }
      }
    }
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .width('100%')
  }
}
