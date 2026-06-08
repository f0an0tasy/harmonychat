/**
 * 会话列表项组件。
 * 显示单个会话的信息，包括头像、好友UID、最后一条消息、时间等。
 *
 * @author wangyifan & qinweiming
 */
@Component
export struct ConversationItem {
  /** 好友UID */
  @Prop friendUid: string = '';
  /** 最后一条消息内容 */
  @Prop lastMessage: string = '';
  /** 最后一条消息时间戳 */
  @Prop lastMessageTime: number = 0;
  /** 是否置顶 */
  @Prop isPinned: boolean = false;
  /** 最后一条消息发送者的头像ID（1-11），用于显示内置头像 */
  @Prop avatarId: number = 1;

  /**
   * 格式化时间显示。
   * 今天显示时:分，昨天显示"昨天"，更早显示月-日。
   */
  private formatTime(timestamp: number): string {
    if (timestamp === 0) {
      return '';
    }

    const date = new Date(timestamp);
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);
    const messageDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());

    if (messageDate.getTime() === today.getTime()) {
      // 今天，显示时:分
      const hours = date.getHours().toString().padStart(2, '0');
      const minutes = date.getMinutes().toString().padStart(2, '0');
      return `${hours}:${minutes}`;
    } else if (messageDate.getTime() === yesterday.getTime()) {
      // 昨天
      return '昨天';
    } else {
      // 更早，显示月-日
      const month = (date.getMonth() + 1).toString().padStart(2, '0');
      const day = date.getDate().toString().padStart(2, '0');
      return `${month}-${day}`;
    }
  }

  /**
   * 获取头像显示文字（好友UID首字母）。
   */
  private getAvatarText(): string {
    if (this.friendUid && this.friendUid.length > 0) {
      return this.friendUid.charAt(0).toUpperCase();
    }
    return 'U';
  }

  /**
   * 截断过长的消息内容。
   */
  private truncateMessage(message: string): string {
    if (!message) {
      return '';
    }
    // 最多显示20个字符
    if (message.length > 20) {
      return message.substring(0, 20) + '...';
    }
    return message;
  }

  build() {
    Row() {
      // 左侧头像
      // === 关键修改：根据 avatarId 显示内置头像或字母头像 ===
      if (this.avatarId >= 1 && this.avatarId <= 11) {
        // 显示内置头像
        Image($r('app.media.avatar_' + this.avatarId))
          .width(48)
          .height(48)
          .borderRadius(24)
          .objectFit(ImageFit.Cover)
      } else {
        // 回退到字母头像
        Row() {
          Text(this.getAvatarText())
            .fontSize(20)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
        }
        .width(48)
        .height(48)
        .borderRadius(24)
        .backgroundColor('#0A59F7')
        .justifyContent(FlexAlign.Center)
      }

      // 中间内容区
      Column() {
        // 好友UID（带置顶图标）
        Row() {
          Text(this.friendUid)
            .fontSize(16)
            .fontColor('#333333')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          
          // 置顶图标
          if (this.isPinned) {
            SymbolGlyph($r('sys.symbol.pin'))
              .fontSize(14)
              .fontColor(['#F4B942'])
              .margin({ left: 4 })
          }
        }
        .width('100%')

        // 最后一条消息
        Text(this.truncateMessage(this.lastMessage))
          .fontSize(14)
          .fontColor('#999999')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .justifyContent(FlexAlign.Center)

      // 右侧时间
      Text(this.formatTime(this.lastMessageTime))
        .fontSize(12)
        .fontColor('#CCCCCC')
        .margin({ left: 8 })
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.isPinned ? '#F5F5F5' : Color.White)
  }
}
