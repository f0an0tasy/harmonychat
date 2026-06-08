import Message from "../../model/Message";
import MsgType from "../../constants/MsgType";
import { MsgContentView_text } from "../msg_content_view/MsgContentView_text";
import MsgSendStatus from "../../constants/MsgSendStatus";
import ToolKits from "../../utils/ToolKits";
import UserDatabaseHelper from "../../utils/UserDatabaseHelper";
import AvatarCacheManager from "../../utils/AvatarCacheManager";
import IMClientManager from "../../../IMClientManager";
import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';

const TAG: string = '[NormalMsgView] ';

/**
 * 普通聊天消息UI组件。
 *
 * @author wangyifan & qinweiming
 */
@Component
export struct MsgView_normal {
  message?: Message;
  
  /** 头像ID（1-11，从消息或缓存中获取） */
  @State avatarId: number = 1;
  /** 当前用户头像ID（从AppStorage同步） */
  @StorageLink('currentUserAvatarId') @Watch('onCurrentUserAvatarIdChanged') currentUserAvatarId: number = 1;
  /** 发送者首字母（用于默认头像） */
  @State avatarText: string = 'U';
  /** 头像加载是否失败 */
  @State avatarLoadFailed: boolean = false;
  /** 数据库助手 */
  private userDbHelper: UserDatabaseHelper | null = null;
  /** 上下文 */
  private context: common.UIAbilityContext | null = null;
  /** 头像更新事件回调 */
  private avatarUpdateEventCallback?: Function;
  
  /**
   * 组件即将出现时调用。
   */
  async aboutToAppear(): Promise<void> {
    console.info(TAG + '=== NormalMsgView aboutToAppear ===');
    
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
    
    console.info(TAG + '消息发送者ID: ' + (this.message ? this.message.senderId : '空'));
    console.info(TAG + '消息发送者显示名: ' + (this.message ? this.message.senderDisplayName : '空'));
    
    // 加载头像
    await this.loadAvatar();
    
    // 订阅头像更新事件
    this.addAvatarUpdateEvent();
  }
  
  /**
   * 组件即将消失时调用。
   */
  aboutToDisappear(): void {
    // 取消订阅头像更新事件
    this.removeAvatarUpdateEvent();
  }
  
  /**
   * 订阅头像更新事件。
   */
  addAvatarUpdateEvent(): void {
    console.info(TAG + '订阅头像更新事件');
    try {
      const emitter = IMClientManager.getInstance().getEmitter();
      if (emitter) {
        this.avatarUpdateEventCallback = (uid: string) => {
          console.info(TAG + `收到头像更新事件，uid: ${uid}`);
          // 如果更新的头像属于当前消息的发送者，重新加载头像
          if (this.message && this.message.senderId === uid) {
            console.info(TAG + `✅ 头像属于当前消息发送者，重新加载...`);
            this.loadAvatarFromCache();
          } else {
            console.info(TAG + `ℹ️ 头像不属于当前消息发送者，忽略`);
          }
        };
        emitter.on('avatarUpdated', this.avatarUpdateEventCallback);
        console.info(TAG + '✅ 头像更新事件订阅成功');
      } else {
        console.error(TAG + '❌ 无法获取EventHub');
      }
    } catch (err) {
      console.error(TAG + '❌ 订阅头像更新事件失败: ' + JSON.stringify(err));
    }
  }
  
  /**
   * 取消订阅头像更新事件。
   */
  removeAvatarUpdateEvent(): void {
    console.info(TAG + '取消订阅头像更新事件');
    try {
      if (this.avatarUpdateEventCallback) {
        const emitter = IMClientManager.getInstance().getEmitter();
        if (emitter) {
          emitter.off('avatarUpdated', this.avatarUpdateEventCallback);
          console.info(TAG + '✅ 头像更新事件取消订阅成功');
        }
      }
    } catch (err) {
      console.error(TAG + '❌ 取消订阅头像更新事件失败: ' + JSON.stringify(err));
    }
  }
  
  /**
   * 加载发送者头像。
   */
  async loadAvatar(): Promise<void> {
    console.info(TAG + '=== 开始加载头像 ===');
    
    if (!this.userDbHelper || !this.message || !this.message.senderId) {
      console.warn(TAG + '⚠️ 无法加载头像：数据库助手或消息为空');
      return;
    }
    
    console.info(TAG + '发送者ID: ' + this.message.senderId);
    
    // 如果是当前用户自己发出的消息，使用 AppStorage 中的 currentUserAvatarId
    if (this.message.isOutgoing()) {
      console.info(TAG + '✅ 当前用户自己发出的消息，使用 currentUserAvatarId: ' + this.currentUserAvatarId);
      this.avatarId = this.currentUserAvatarId;
      return;
    }
    
    // 首先检查消息本身是否包含头像ID
    if (this.message.avatarId && this.message.avatarId >= 1 && this.message.avatarId <= 11) {
      this.avatarId = this.message.avatarId;
      console.info(TAG + '✅ 从消息中获取头像ID: ' + this.message.avatarId);
      return;
    }
    
    console.info(TAG + '消息中无头像ID或无效，尝试从缓存获取...');
    
    // 从缓存中加载头像ID
    const cachedAvatarIdStr = AvatarCacheManager.getInstance().getAvatar(this.message.senderId);
    console.info(TAG + '从缓存获取头像: ' + (cachedAvatarIdStr ? '成功，avatarId=' + cachedAvatarIdStr : '无'));
    
    if (cachedAvatarIdStr) {
      const cachedAvatarId = parseInt(cachedAvatarIdStr, 10);
      if (!isNaN(cachedAvatarId) && cachedAvatarId >= 1 && cachedAvatarId <= 11) {
        this.avatarId = cachedAvatarId;
        console.info(TAG + '✅ 头像已从缓存加载，avatarId: ' + cachedAvatarId);
        return;
      } else {
        console.warn(TAG + '⚠️ 缓存中的头像ID无效: ' + cachedAvatarIdStr);
      }
    }
    
    // 如果缓存中没有，尝试从本地数据库加载（仅对本地用户有效）
    console.info(TAG + '缓存中无头像，尝试从本地数据库加载...');
    try {
      const savedAvatarId = await this.userDbHelper.getUserAvatarId(this.message.senderId);
      console.info(TAG + '本地数据库头像ID: ' + savedAvatarId);
      
      if (savedAvatarId >= 1 && savedAvatarId <= 11) {
        this.avatarId = savedAvatarId;
        console.info(TAG + '✅ 头像已从本地数据库加载，avatarId: ' + savedAvatarId);
      } else {
        this.avatarId = 1; // 默认头像ID
        console.info(TAG + 'ℹ️ 本地无有效头像ID，使用默认头像ID: 1');
      }
    } catch (err) {
      console.error(TAG + '❌ 加载头像失败: ' + JSON.stringify(err));
      this.avatarId = 1; // 默认头像ID
    }
  }
  
  /**
   * 当 currentUserAvatarId 变化时触发。
   */
  onCurrentUserAvatarIdChanged(): void {
    if (this.message && this.message.isOutgoing()) {
      console.info(TAG + 'currentUserAvatarId 变化，更新头像ID: ' + this.currentUserAvatarId);
      this.avatarId = this.currentUserAvatarId;
    }
  }
  
  /**
   * 从缓存中重新加载头像。
   */
  loadAvatarFromCache(): void {
    console.info(TAG + '=== 从缓存重新加载头像 ===');
    
    if (!this.message || !this.message.senderId) {
      console.warn(TAG + '⚠️ 无法重新加载：消息为空');
      return;
    }
    
    console.info(TAG + '发送者ID: ' + this.message.senderId);
    
    // 如果是当前用户自己发出的消息，使用 AppStorage 中的 currentUserAvatarId
    if (this.message.isOutgoing()) {
      console.info(TAG + '✅ 当前用户自己发出的消息，使用 currentUserAvatarId: ' + this.currentUserAvatarId);
      this.avatarId = this.currentUserAvatarId;
      return;
    }
    
    const cachedAvatarIdStr = AvatarCacheManager.getInstance().getAvatar(this.message.senderId);
    console.info(TAG + '从缓存获取头像: ' + (cachedAvatarIdStr ? '成功，avatarId=' + cachedAvatarIdStr : '无'));
    
    if (cachedAvatarIdStr) {
      const cachedAvatarId = parseInt(cachedAvatarIdStr, 10);
      if (!isNaN(cachedAvatarId) && cachedAvatarId >= 1 && cachedAvatarId <= 11) {
        this.avatarId = cachedAvatarId;
        console.info(TAG + '✅ 头像已从缓存重新加载，avatarId: ' + cachedAvatarId);
      } else {
        console.warn(TAG + '⚠️ 缓存中的头像ID无效: ' + cachedAvatarIdStr);
      }
    } else {
      console.warn(TAG + '⚠️ 缓存中仍无头像');
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
      if (this.avatarLoadFailed) {
        // 如果内置资源加载失败，显示默认头像（首字母）
        Column() {
          Text(this.avatarText)
            .fontSize(18)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor(isOutgoing ? '#0A59F7' : '#07C160')
        .justifyContent(FlexAlign.Center)
      } else {
        // 显示内置头像资源
        Image($r('app.media.avatar_' + this.avatarId))
          .width(40)
          .height(40)
          .borderRadius(20)
          .objectFit(ImageFit.Cover)
          .onComplete(() => {
            console.info(TAG + '✅ 内置头像资源加载成功，avatarId: ' + this.avatarId);
          })
          .onError(() => {
            console.error(TAG + '❌ 内置头像资源加载失败，avatarId: ' + this.avatarId);
            this.avatarLoadFailed = true;
          })
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