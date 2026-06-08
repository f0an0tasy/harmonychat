import Message from "../../model/Message";

/**
 * 系统消息UI组件。
 *
 * @author wangyifan & qinweiming
 */
@Preview
@Component
export struct MsgView_system {
  message?: Message;

  build() {
    if(this.message) {
      Row() {
        Text(this.message.content)
          .fontColor('#979ca6')
          .backgroundColor('#e5e7ec')
          .fontSize(13)
          .padding({
            top: 5,
            left: 15,
            bottom: 5,
            right: 15
          })
          .borderRadius(12)
          .textAlign(TextAlign.Center)
      }
      .width("100%")
      .justifyContent(FlexAlign.Center)
    }
  }
}