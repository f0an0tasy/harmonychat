/*
 * Copyright (C) 2024  即时通讯网(52im.net) & Jack Jiang.
 * The MobileIMSDK-鸿蒙Next客户端 Project. All rights reserved.
 *
 * 联系邮件：jack.jiang@52im.net
 * 联系微信：hellojackjiang
 * 联系QQ： 413980957
 * 技术社区：http://www.52im.net
 */

import Message from "../../model/Message";
import MsgType from "../../constants/MsgType";
import { MsgContentView_text } from "../msg_content_view/MsgContentView_text";
import MsgSendStatus from "../../constants/MsgSendStatus";
import ToolKits from "../../utils/ToolKits";
import UserDatabaseHelper from "../../utils/UserDatabaseHelper";
import { common } from '@kit.AbilityKit';

const TAG: string = '[NormalMsgView] ';

/**
 * 普通聊天消息UI组件。
 *
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 */
@Component
export struct MsgView_normal {
  message?: Message;
  
  /** 头像路径（自定义头像） */
  @State avatarPath: string = '';
  /** 发送者首字母（用于默认头像） */
  @State avatarText: string = 'U';
  /** 数据库助手 */
  private userDbHelper: UserDatabaseHelper | null = null;
  /** 上下文 */
  private context: common.UIAbilityContext | null = null;
  
  /**
   * 组件即将出现时调用。
   */
  async aboutToAppear(): Promise<void> {
    // 初始化上下文和数据库助手
    try {
      this.context = getContext(this) as common.UIAbilityContext;
      this.userDbHelper = UserDatabaseHelper.getInstance(this.context);
    } catch (err) {
      console.error(TAG + 'Failed to get context: ' + JSON.stringify(err));
    }
    
    // 设置发送者首字母
    if (this.message && this.message.senderDisplayName && this.message.senderDisplayName.length > 0) {
      this.avatarText = this.message.senderDisplayName.charAt(0).toUpperCase();
    } else if (this.message && this.message.senderId && this.message.senderId.length > 0) {
      this.avatarText = this.message.senderId.charAt(0).toUpperCase();
    }
    
    // 加载头像
    await this.loadAvatar();
  }
  
  /**
   * 加载发送者头像。
   */
  async loadAvatar(): Promise<void> {
    if (!this.userDbHelper || !this.message || !this.message.senderId) {
      return;
    }
    
    try {
      const savedAvatarPath = await this.userDbHelper.getUserAvatar(this.message.senderId);
      if (savedAvatarPath && ToolKits.isFileExists(savedAvatarPath)) {
        this.avatarPath = savedAvatarPath;
        console.info(TAG + 'Avatar loaded for ' + this.message.senderId + ': ' + savedAvatarPath);
      } else {
        this.avatarPath = '';
      }
    } catch (err) {
      console.error(TAG + 'Failed to load avatar: ' + JSON.stringify(err));
      this.avatarPath = '';
    }
  }

  build() {
    Row() {
      if (this.message) {
        // 如果是收到的消息，则头像在最左边显示
        if(this.message.isOutgoing() === false) {
          this.AvatarImage(false)
        }

        // 消息气泡外层父布局
        Column() {
          // 昵称显示
          this.NicknameText(this.message.senderDisplayName, this.message.isOutgoing());

          // 特别说明：当此组件为Row()时，将导致文本超长时尾部挤出屏幕的问题，这或许是鸿蒙的bug，使用Flex()则能解决问题，参考资料：https://developer.huawei.com/consumer/cn/forum/topic/0204138991096490058
          Flex({direction: FlexDirection.Row, wrap: FlexWrap.NoWrap, justifyContent:(this.message.isOutgoing() ? FlexAlign.End : FlexAlign.Start)}) {

            // 消息状态图标的显示：只有“发出”的消息需要显示哦
            this.SendStatusIcon(this.message)

            // 消息内容子组件（按消息类型调用对应的子组件实现）
            if (this.message.msgType === MsgType.TYPE_TEXT) {
              // 注：设置layoutWeight(1)能解决超长挤出屏幕的问题，但占满所有空间，这不是预期想要的
              MsgContentView_text({ message: this.message })
            } else {
              // TODO: 更多消息类型待实现哦！！
              // TODO: 更多消息类型待实现哦！！
              // TODO: 更多消息类型待实现哦！！
            }
          }
        }
        .messageBubbleOutsideStyle(this.message.isOutgoing())

        // 如果是发出的消息，则头像在最右边显示
        if(this.message.isOutgoing() === true) {
          this.AvatarImage(true)
        }
      }
    }
    .width("100%").alignItems(VerticalAlign.Top)
  }

  @Builder
  NicknameText(nickname: string, isOutgoing: boolean) {
    Text(nickname)// .backgroundColor('#009900')
      .fontColor('#979ca6')
      .fontSize(11)
      .margin(isOutgoing ? { bottom: 4, right: 12 }: { bottom: 4, left: 12 })
      .visibility(isOutgoing ? Visibility.None : Visibility.Visible)
  }

  @Builder
  AvatarImage(isOutgoing: boolean) {
    Stack() {
      if (this.avatarPath && this.avatarPath.length > 0) {
        // 显示自定义头像
        Image('file://' + this.avatarPath)
          .width(40)
          .height(40)
          .borderRadius(20)
          .objectFit(ImageFit.Cover)
      } else {
        // 显示默认头像（首字母）
        Circle()
          .width(40)
          .height(40)
          .fill(isOutgoing ? '#0A59F7' : '#07C160')
        
        Text(this.avatarText)
          .fontSize(18)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
      }
    }
    .width(40)
    .height(40)
    .margin({ left: 8, right: 8 })
  }

  @Builder
  SendStatusIcon(message: Message) {
    // 只有“发出”的消息有消息状态ui的显示
    if (message.isOutgoing() === true) {
      // 发送失败
      if (message.sendStatus === MsgSendStatus.sendFaild) {
        Image($r('app.media.ic_warn'))
          .fillColor($r('sys.color.ohos_id_color_badge_red'))//'#ff453a')
          .width(19)
          .height(19)
          .margin({top:3, right: 7})
          .onClick(() => {
            ToolKits.showToast('本条消息没成功送达！')
          })
      }
      // 发送中
      else if (message.sendStatus === MsgSendStatus.sending) {
        Progress({ value: 0, total: 100, type: ProgressType.Ring })
          .color(Color.Grey).value(19).width(19)
          .style({strokeWidth: 2, scaleCount: 15, scaleWidth: 5, status: ProgressStatus.LOADING })
          .margin({top:5, right: 7})
          .onClick(() => {
            ToolKits.showToast('消息发送中...')
          })
      }
      // 发送成功
      else {
        // 啥也不显示
      }
    }
  }
}

// 消息气泡外层父布局的样式设置
@Extend(Column)
function messageBubbleOutsideStyle(isOutgoing: boolean) {
  .layoutWeight(1)
  .alignItems(isOutgoing ? HorizontalAlign.End : HorizontalAlign.Start)
  // 气泡末端距离手机两侧的间距，目的是让消息气泡的末端要空出一个头像+头像两边间距的空白距离，ui上好看一点
  .margin(isOutgoing ? { left: 40 + 8 + 8 } : { right: 40 + 8 + 8 })
}