import { LocalDataSender, ClientCoreSDK, ErrorCode, Protocal } from "mobileimsdk/Index";
import IMClientManager from "../../IMClientManager";
import Message from "../model/Message";
import ToolKits from "../utils/ToolKits";
import UserDatabaseHelper from "../utils/UserDatabaseHelper";
import ConversationManager from "../model/ConversationManager";
import { common } from '@kit.AbilityKit';

const TAG: string = '[ChatInputView] ';

/**
 * 消息数据封装对象。
 * 用于将消息内容和头像ID一起发送。
 */
interface MessageData {
  /** 消息内容 */
  content: string;
  /** 发送者头像ID（1-11，可选） */
  avatarId?: number;
}

/**
 * 聊天界面输入区组件。
 *
 * 【改造说明】
 * 原实现包含"对方ID"输入框，现已移除。
 * friendUid 通过组件参数传入，不再需要手动输入。
 *
 * @author wangyifan & qinweiming
 */
@Component
export struct ChatInputView {
  /** 当前聊天对象的好友UID（从父组件传入） */
  @Prop friendUid: string = '';

  /** 消息输入内容 */
  @State messageInput: string = '';

  /** 数据库助手 */
  private userDbHelper: UserDatabaseHelper | null = null;

  /** 上下文 */
  private context: common.UIAbilityContext | null = null;
  
  /** 缓存的头像ID（内存缓存） */
  private static cachedAvatarId: number = 0;

  /**
   * 重置缓存的头像ID，用于用户更换头像后清除缓存
   */
  static resetCachedAvatarId(): void {
    ChatInputView.cachedAvatarId = 0;
    console.info(TAG + '头像缓存已重置');
  }

  /**
   * 组件即将出现时调用。
   */
  aboutToAppear(): void {
    try {
      this.context = getContext(this) as common.UIAbilityContext;
      this.userDbHelper = UserDatabaseHelper.getInstance(this.context);
    } catch (err) {
      console.error(TAG + 'Failed to get context: ' + JSON.stringify(err));
    }
  }

  /**
   * 发送消息。
   */
  async doSendMessage(): Promise<void> {
    // 验证输入
    if (this.messageInput.length === 0) {
      ToolKits.showToast('请输入消息内容');
      return;
    }

    // === 关键修复：验证friendUid的有效性 ===
    if (!UserDatabaseHelper.isValidFriendUid(this.friendUid)) {
      console.error(TAG + '❌ 无效的friendUid: "' + this.friendUid + '"');
      ToolKits.showToast('对方ID无效，无法发送消息');
      return;
    }
    
    console.info(TAG + '✅ friendUid验证通过: ' + this.friendUid);

    // 不能给自己发消息
    if (this.friendUid === ClientCoreSDK.getInstance().currentLoginInfo?.loginUserId) {
      ToolKits.showToast('不能给自己发送消息哦！');
      return;
    }

    // 生成消息指纹码
    let fingerPrint: string = Protocal.genFingerPrint();

    // === 头像ID携带逻辑（优先从AppStorage同步读取） ===
    let avatarId: number = 0; // 0表示不携带头像
    try {
      const currentUsername = ToolKits.getLocalUserUid();
      console.info(TAG + '=== 开始准备发送消息 ===');
      console.info(TAG + '当前用户: ' + currentUsername);
      console.info(TAG + '接收者: ' + this.friendUid);
      console.info(TAG + '消息内容: ' + this.messageInput);

      // === 关键修复：优先从AppStorage同步读取头像ID ===
      const cachedAvatarIdFromAppStorage = AppStorage.get<number>('currentUserAvatarId');
      if (cachedAvatarIdFromAppStorage && cachedAvatarIdFromAppStorage >= 1 && cachedAvatarIdFromAppStorage <= 11) {
        avatarId = cachedAvatarIdFromAppStorage;
        console.info(TAG + '✅ 从AppStorage同步读取头像ID: ' + avatarId);
      } else if (currentUsername && this.userDbHelper) {
        // AppStorage中没有值，从数据库获取（异步查询）
        console.info(TAG + 'AppStorage中无头像ID，从数据库获取...');
        avatarId = await this.userDbHelper.getUserAvatarId(currentUsername);
        console.info(TAG + '从数据库获取到头像ID: ' + avatarId);
        
        // 将获取到的头像ID存入AppStorage，供下次使用
        if (avatarId >= 1 && avatarId <= 11) {
          AppStorage.setOrCreate('currentUserAvatarId', avatarId);
          console.info(TAG + '✅ 头像ID已存入AppStorage: ' + avatarId);
        } else {
          avatarId = 0; // 无效的头像ID，不携带
          console.warn(TAG + '⚠️ 获取到无效的头像ID: ' + avatarId + '，将不携带头像');
        }
      } else {
        console.warn(TAG + '⚠️ 无法获取当前用户信息或数据库助手');
      }
    } catch (err) {
      console.error(TAG + '❌ 获取头像ID失败: ' + JSON.stringify(err));
      avatarId = 0; // 出错时不携带头像
    }

    // === 构建消息内容 ===
    let messageContent: string;
    if (avatarId >= 1 && avatarId <= 11) {
      const messageData: MessageData = {
        content: this.messageInput,
        avatarId: avatarId
      };
      messageContent = JSON.stringify(messageData);
      console.info(TAG + '✅ 消息已封装为JSON格式（包含头像ID）');
      console.info(TAG + `JSON总长度: ${messageContent.length} 字符`);
      console.info(TAG + `消息内容长度: ${this.messageInput.length} 字符`);
      console.info(TAG + `头像ID: ${avatarId}`);
    } else {
      messageContent = this.messageInput;
      console.info(TAG + 'ℹ️ 消息为纯文本格式（无头像ID）');
    }

    // 发送消息
    console.info(TAG + '开始发送消息...');
    let code = LocalDataSender.getInstance().sendCommonDataPlain(
      messageContent,
      this.friendUid,
      true,
      fingerPrint
    );

    if (code === ErrorCode.COMMON_CODE_OK) {
      ClientCoreSDK.Log.info('✅ 数据已成功发出！');

      // 创建UI显示的消息对象（携带头像ID和接收者UID）
      let m: Message = Message.createChatMsgEntity_OUTGO_TEXT(
        this.messageInput, 
        fingerPrint, 
        avatarId >= 1 && avatarId <= 11 ? avatarId : undefined,
        this.friendUid  // 传入接收者UID，用于数据库持久化
      );

      // 将消息放入全局消息数据缓存
      IMClientManager.getInstance().getMessageProvider().putMessage(m);

      // 清空输入框
      this.messageInput = '';
      console.info(TAG + '=== 消息发送完成 ===');
    } else {
      console.error(TAG + '❌ 消息发送失败，错误码: ' + code);
      ToolKits.showToast('数据发送失败。错误码是：' + code + '！');
    }
  }

  build() {
    Row() {
      // 消息输入框
      TextInput({
        placeholder: '请输入聊天内容，按发送键提交',
        text: $$this.messageInput
      })
        .backgroundColor('#f5f7fa')
        .height(40)
        .fontSize(14)
        .layoutWeight(1)
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .placeholderFont({ size: 14 })
        .placeholderColor('#a1a7af')
        .margin({ right: 10 })

      // 发送按钮
      Button('发送', { type: ButtonType.Normal, stateEffect: true })
        .width(60)
        .height(40)
        .borderRadius(8)
        .padding(0)
        .fontSize(15)
        .backgroundColor('#00de7a')
        .fontWeight(500)
        .onClick(() => {
          this.doSendMessage();
        })
    }
    .height(56)
    .width('100%')
    .backgroundColor('#ffffff')
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
  }
}
