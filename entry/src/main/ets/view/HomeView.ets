import { DeviceState } from '../model/DeviceModel';
import { Rule } from '../model/RuleModel';
import { DormStore } from '../viewmodel/DormStore';
import { DeviceCard } from '../components/DeviceCard';

@Component
export struct HomeView {
  @Consume('store') store: DormStore;
  @StorageLink('envTemp') envTemp: number = 0;
  @StorageLink('envHum') envHum: number = 0;
  @StorageLink('envLux') envLux: number = 0;
  @StorageLink('comfort') comfort: number = 0;
  @StorageLink('clockText') clockText: string = '--:--';
  @StorageLink('activeCount') activeCount: number = 0;
  @StorageLink('todayWh') todayWh: number = 0;
  @StorageLink('devicesVersion') devicesVersion: number = 0;
  @StorageLink('presence') presence: boolean = true;

  private scenes(): Rule[] {
    return this.store.rules.filter((r: Rule) => r.sceneId.length > 0);
  }

  @Builder
  envCell(label: string, value: string) {
    Column({ space: 2 }) {
      Text(value).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1B1F27')
      Text(label).fontSize(11).fontColor('#7C8595')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        // 顶部问候 + 仿真时钟
        Row() {
          Column({ space: 2 }) {
            Text('下午好，302 宿舍')
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1B1F27')
            Text(`仿真时间 ${this.clockText} · ${this.activeCount} 台设备运行中`)
              .fontSize(12).fontColor('#7C8595')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text(this.presence ? '有人' : '无人')
            .fontSize(11)
            .fontColor(this.presence ? '#0E9F6E' : '#9AA3B2')
            .backgroundColor(this.presence ? '#E8F8F1' : '#F1F3F5')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(10)
        }
        .width('100%')

        // 环境卡
        Column({ space: 14 }) {
          Row() {
            Column({ space: 4 }) {
              Text(`${this.envTemp}`)
                .fontSize(40).fontWeight(FontWeight.Bold).fontColor('#1B1F27')
              Text(`室内温度 ℃ · 舒适度 ${this.comfort}`)
                .fontSize(12).fontColor('#7C8595')
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Stack() {
              Progress({ value: this.comfort, total: 100, type: ProgressType.Ring })
                .width(64).height(64)
                .color('#2E5BFF')
                .backgroundColor('#E6EBF7')
                .style({ strokeWidth: 7 })
              Text(`${this.comfort}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#2E5BFF')
            }
          }
          .width('100%')

          Divider().color('#EEF1F6')
          Row() {
            this.envCell('湿度 %', `${this.envHum}`)
            this.envCell('光照 lx', `${this.envLux}`)
            this.envCell('今日 kWh', `${(this.todayWh / 1000).toFixed(2)}`)
          }
          .width('100%')
        }
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(20)

        // 场景快捷
        Row({ space: 10 }) {
          ForEach(this.scenes(), (item: Rule) => {
            Column({ space: 6 }) {
              Text(item.name.substring(0, 2)).fontSize(15).fontWeight(FontWeight.Medium)
              Text(item.name).fontSize(11).fontColor('#7C8595')
            }
            .layoutWeight(1)
            .padding({ top: 12, bottom: 12 })
            .backgroundColor('#F4F6FB')
            .borderRadius(14)
            .onClick(() => {
              this.store.runScene(item.id);
            })
          }, (item: Rule) => item.id)
        }
        .width('100%')

        // 设备网格
        Row() {
          Text('设备').fontSize(16).fontWeight(FontWeight.Bold)
          Blank()
          Text(`全部 ${this.store.deviceService.devices.length}`).fontSize(12).fontColor('#7C8595')
        }
        .width('100%')

        Grid() {
          ForEach(this.store.deviceService.devices.filter((d: DeviceState) => !d.isSensor()),
            (item: DeviceState) => {
              GridItem() {
                DeviceCard({ device: item })
              }
            }, (item: DeviceState) => `${item.id}-${item.power}-${item.level}`)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(10)
        .rowsGap(10)
        .height(320)
      }
      .padding({ left: 16, right: 16, top: 12, bottom: 24 })
    }
    .scrollBar(BarState.Off)
    .backgroundColor('#F1F3F5')
    .width('100%')
    .height('100%')
  }
}
