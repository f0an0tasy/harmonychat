import Message from "../../model/Message";
import ToolKits from "../../utils/ToolKits";

/**
 * 聊天消息时间显示组件。
 *
 * @author wangyifan & qinweiming
 */
@Component
export struct MsgTimeView {
  message?: Message;

  build() {
    // 需要显示消息时间的才显示，否则不需要显示
    if (this.message?.showTopTime) {
      Text(ToolKits.getTimeStringAutoShort2(this.message.date, true, true))
        .fontSize(12)
        .fontColor('#979ca6')
        .margin({bottom: 13})
    }
  }
}

