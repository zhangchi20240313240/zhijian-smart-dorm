import { DeviceState, DeviceType, DeviceAttr } from '../model/DeviceModel';
import { DormStore } from '../viewmodel/DormStore';

@Component
export struct DeviceCard {
  @ObjectLink device: DeviceState;
  @Consume('store') store: DormStore;

  private iconText(): string {
    switch (this.device.type) {
      case DeviceType.Light: return '☀';
      case DeviceType.AirConditioner: return '❄';
      case DeviceType.Curtain: return '▤';
      case DeviceType.Humidifier: return '≋';
      case DeviceType.Fan: return '✳';
      case DeviceType.Socket: return '⌁';
      default: return '◎';
    }
  }

  private subtitle(): string {
    if (this.device.isSensor()) {
      return `${this.device.value}${this.device.unit}`;
    }
    if (!this.device.power) {
      return '已关闭';
    }
    if (this.device.type === DeviceType.AirConditioner) {
      return `制冷 ${this.device.targetTemp}℃`;
    }
    if (this.device.type === DeviceType.Curtain) {
      return `开合 ${this.device.level}%`;
    }
    if (this.device.type === DeviceType.Fan) {
      return `风速 ${this.device.level}%`;
    }
    return `亮度 ${this.device.level}%`;
  }

  build() {
    Column({ space: 6 }) {
      Row() {
        Text(this.iconText())
          .fontSize(20)
          .fontColor(this.device.power ? '#2E5BFF' : '#9AA3B2')
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.device.power })
          .onChange((on: boolean) => {
            this.store.deviceService.setAttr(this.device.id, DeviceAttr.Power, on ? 1 : 0);
            this.store.tick();
          })
          .enabled(!this.device.isSensor())
      }
      .width('100%')

      Text(this.device.name)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1B1F27')
      Text(this.subtitle())
        .fontSize(12)
        .fontColor('#7C8595')
    }
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .width('100%')
    .backgroundColor(this.device.power ? '#EEF2FF' : '#FFFFFF')
    .borderRadius(14)
    .onClick(() => {
      this.store.toggleDevice(this.device.id);
    })
  }
}
