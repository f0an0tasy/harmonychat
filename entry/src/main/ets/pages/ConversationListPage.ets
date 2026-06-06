/*
 * Copyright (C) 2024  即时通讯网(52im.net) & Jack Jiang.
 * The MobileIMSDK-鸿蒙Next客户端 Project. All rights reserved.
 *
 * 联系邮件：jack.jiang@52im.net
 * 联系微信：hellojackjiang
 * 联系QQ： 413980957
 * 技术社区：http://www.52im.net
 */

import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ErrorCode, ClientCoreSDK, PKickoutInfo } from 'mobileimsdk/Index';
import { ConversationItem } from './components/ConversationItem';
import { AddFriendDialog } from './components/AddFriendDialog';
import ConversationManager from './model/ConversationManager';
import IMClientManager from '../IMClientManager';
import UIEvent from './constants/UIEvent';
import ToolKits from './utils/ToolKits';
import FontScaleManager from './utils/FontScaleManager';
import { promptAction } from '@kit.ArkUI';

const TAG: string = '[ConversationListPage] ';

/**
 * 会话列表页面。
 * 显示所有聊天会话，点击可进入聊天详情页。
 * 类似微信的"微信"页面。
 *
 * @author Jack Jiang
 */
@Entry
@Component
export struct ConversationListPage {
  /** 会话列表（好友UID数组） */
  @State conversations: string[] = [];

  /** 连接状态 */
  @State connectStatus: boolean = ClientCoreSDK.getInstance().connectedToServer;
  /** 心跳状态 */
  @State keepAliveStatus: boolean = false;

  /** 当前登录用户名 */
  @StorageProp('currentUsername') currentUsername: string = '';
  /** 用户头像首字母 */
  @State avatarText: string = 'U';
  /** 用户头像路径 */
  @State avatarPath: string = '';
  /** 头像刷新触发器 */
  @StorageLink('avatarRefreshTrigger') @Watch('onAvatarRefreshTriggered') avatarRefreshTrigger: number = 0;

  /** 会话管理器 */
  private conversationManager: ConversationManager | null = null;

  /** 上下文 */
  private context: common.UIAbilityContext | null = null;

  /** 字体缩放管理器 */
  private fontScaleManager: FontScaleManager | null = null;

  /** 添加好友对话框控制器 */
  private addFriendDialogController?: CustomDialogController;

  /** 事件回调 */
  private conversationListUpdatedCallback?: Function;
  private loginCompleteEventCallback?: Function;
  private disconnectedEventCallback?: Function;
  private keepAliveEventCallback?: Function;
  private kickoutEventCallback?: Function;

  /**
   * 组件即将出现时调用。
   */
  async aboutToAppear(): Promise<void> {
    // 初始化上下文
    this.context = getContext(this) as common.UIAbilityContext;

    // 初始化会话管理器
    this.conversationManager = ConversationManager.getInstance(this.context);

    // 加载会话列表
    await this.loadConversations();

    // 设置头像文字
    if (this.currentUsername && this.currentUsername.length > 0) {
      this.avatarText = this.currentUsername.charAt(0).toUpperCase();
    }

    // 加载用户头像
    this.loadUserAvatar();

    // 添加事件监听
    this.addEvents();

    // 初始化字体缩放管理器
    if (this.context) {
      this.fontScaleManager = FontScaleManager.getInstance(this.context);
    }
  }

  /**
   * 组件即将消失时调用。
   */
  aboutToDisappear(): void {
    this.removeEvents();
  }

  /**
   * 页面显示时调用。
   */
  onPageShow(): void {
    this.loadUserAvatar();
  }

  /**
   * 头像刷新触发器变化时的回调。
   */
  onAvatarRefreshTriggered(): void {
    this.loadUserAvatar();
  }

  /**
   * 加载会话列表。
   */
  async loadConversations(): Promise<void> {
    if (this.conversationManager) {
      this.conversations = await this.conversationManager.loadConversations();
      console.info(TAG + 'Conversations loaded: ' + this.conversations.length);
    }
  }

  /**
   * 加载用户头像。
   */
  async loadUserAvatar(): Promise<void> {
    // 头像加载逻辑（与 ChatComponent 保持一致）
    // 暂时使用默认头像
    this.avatarPath = '';
  }

  /**
   * 添加事件监听。
   */
  addEvents(): void {
    // 会话列表更新事件
    IMClientManager.getInstance().getEmitter().on(
      UIEvent.UIEVENT_conversationListUpdated,
      this.conversationListUpdatedCallback = () => {
        this.refreshConversationList();
      }
    );

    // 掉线重连完成
    IMClientManager.getInstance().getEmitter().on(
      UIEvent.UIEVENT_onIMAfterLoginComplete,
      this.loginCompleteEventCallback = (code: number) => {
        if (code === ErrorCode.COMMON_CODE_OK) {
          this.refreshConnecteStatus();
        }
      }
    );

    // 掉线了
    IMClientManager.getInstance().getEmitter().on(
      UIEvent.UIEVENT_onIMDisconnected,
      this.disconnectedEventCallback = () => {
        this.refreshConnecteStatus();
      }
    );

    // 心跳了一次
    IMClientManager.getInstance().getEmitter().on(
      UIEvent.UIEVENT_onIMPing,
      this.keepAliveEventCallback = () => {
        this.keepAliveStatus = true;
        setTimeout(() => {
          this.keepAliveStatus = false;
        }, 500);
      }
    );

    // 被踢了
    IMClientManager.getInstance().getEmitter().on(
      UIEvent.UIEVENT_onKickout,
      this.kickoutEventCallback = (kickoutInfo: PKickoutInfo) => {
        this.beKickout(kickoutInfo);
      }
    );
  }

  /**
   * 取消事件监听。
   */
  removeEvents(): void {
    IMClientManager.getInstance().getEmitter().off(
      UIEvent.UIEVENT_conversationListUpdated,
      this.conversationListUpdatedCallback
    );
    IMClientManager.getInstance().getEmitter().off(
      UIEvent.UIEVENT_onIMAfterLoginComplete,
      this.loginCompleteEventCallback
    );
    IMClientManager.getInstance().getEmitter().off(
      UIEvent.UIEVENT_onIMDisconnected,
      this.disconnectedEventCallback
    );
    IMClientManager.getInstance().getEmitter().off(
      UIEvent.UIEVENT_onIMPing,
      this.keepAliveEventCallback
    );
    IMClientManager.getInstance().getEmitter().off(
      UIEvent.UIEVENT_onKickout,
      this.kickoutEventCallback
    );
  }

  /**
   * 刷新会话列表。
   */
  refreshConversationList(): void {
    if (this.conversationManager) {
      this.conversations = [...this.conversationManager.getConversations()];
    }
  }

  /**
   * 刷新连接状态。
   */
  refreshConnecteStatus(): void {
    this.connectStatus = ClientCoreSDK.getInstance().connectedToServer;
  }

  /**
   * 被踢的处理逻辑。
   */
  beKickout(kickoutInfo: PKickoutInfo): void {
    IMClientManager.getInstance().releaseMobileIMSDK();

    let alertContent: string = '';
    if (kickoutInfo.code === PKickoutInfo.KICKOUT_FOR_DUPLICATE_LOGIN) {
      alertContent = '账号已在其它地方登陆，当前会话已断开，请退出后重新登陆！';
    } else if (kickoutInfo.code === PKickoutInfo.KICKOUT_FOR_ADMIN) {
      alertContent = '已被管理员强行踢出聊天，当前会话已断开！';
    } else {
      alertContent = '你已被踢出聊天，当前会话已断开（kickoutInfo=' + JSON.stringify(kickoutInfo) + '）！';
    }

    ClientCoreSDK.Log.error(TAG + alertContent);

    let primaryAction: Callback<void> = () => {
      this.switchToLoginPage();
    };

    let secondaryAction: Callback<void> = () => {
      let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      ToolKits.exitSystem(context);
    };

    ToolKits.showAlertDialog(
      alertContent,
      '重新登录',
      undefined,
      primaryAction,
      '退出应用',
      $r('sys.color.ohos_id_color_badge_red'),
      secondaryAction
    );
  }

  /**
   * 切换到登陆界面。
   */
  switchToLoginPage(): void {
    IMClientManager.getInstance().initMobileIMSDK(
      getContext(this).getApplicationContext(),
      getContext(this).eventHub
    );
    router.replaceUrl({ url: 'pages/LoginPage' });
  }

  /**
   * 打开添加好友对话框。
   */
  showAddFriendDialog(): void {
    // 使用 bindSheet 方式显示添加好友面板
    this.isShowAddFriendSheet = true;
  }

  /**
   * 跳转到聊天详情页。
   */
  goToChatDetail(friendUid: string): void {
    // 切换到该好友的消息
    IMClientManager.getInstance().getMessageProvider().switchToFriend(friendUid);
    // 跳转到聊天详情页
    router.pushUrl({
      url: 'pages/ChatDetailPage',
      params: { friendUid: friendUid }
    });
  }

  /**
   * 获取最后一条消息内容。
   */
  getLastMessage(friendUid: string): string {
    if (this.conversationManager) {
      return this.conversationManager.getLastMessage(friendUid);
    }
    return '';
  }

  /**
   * 获取最后一条消息时间。
   */
  getLastMessageTime(friendUid: string): number {
    if (this.conversationManager) {
      return this.conversationManager.getLastMessageTime(friendUid);
    }
    return 0;
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        // 左侧：连接状态指示器
        Row() {
          if (this.connectStatus) {
            // 连接正常
            Row()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(this.keepAliveStatus ? '#00de7a' : '#00de7a')
              .opacity(this.keepAliveStatus ? 1.0 : 0.6)
          } else {
            // 连接断开
            Row()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor('#ff0000')
          }
        }
        .width(20)
        .height(20)
        .justifyContent(FlexAlign.Center)

        // 中间：标题
        Text('聊天')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 右侧：添加好友按钮
        Row() {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(24)
            .fontColor(['#333333'])
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showAddFriendDialog();
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 8 })
      .backgroundColor(Color.White)

      // 分割线
      Divider()
        .width('100%')
        .height(1)
        .color('#F0F0F0')

      // 会话列表
      if (this.conversations.length > 0) {
        List() {
          ForEach(this.conversations, (uid: string, index: number) => {
            ListItem() {
              Column() {
                ConversationItem({
                  friendUid: uid,
                  lastMessage: this.getLastMessage(uid),
                  lastMessageTime: this.getLastMessageTime(uid),
                  isPinned: this.isPinned(uid)
                })

                // 分割线
                Divider()
                  .width('100%')
                  .height(1)
                  .color('#F0F0F0')
                  .margin({ left: 76 })
              }
            }
            .onClick(() => {
              this.goToChatDetail(uid);
            })
            .swipeAction({
              end: {
                builder: () => this.buildSwipeMenu(uid),
                actionAreaDistance: 120
              }
            })
          }, (uid: string) => uid)
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#FAFAFA')
        .listDirection(Axis.Vertical)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      } else {
        // 空状态
        Column() {
          SymbolGlyph($r('sys.symbol.message'))
            .fontSize(64)
            .fontColor(['#CCCCCC'])
            .margin({ bottom: 16 })

          Text('暂无会话')
            .fontSize(16)
            .fontColor('#999999')

          Text('点击右上角 + 添加好友开始聊天')
            .fontSize(14)
            .fontColor('#CCCCCC')
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#FAFAFA')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .bindSheet($$this.isShowAddFriendSheet, this.AddFriendSheetBuilder(), {
      height: 280,
      backgroundColor: Color.White,
      dragBar: false
    })
  }

  // 添加好友面板显示状态
  @State isShowAddFriendSheet: boolean = false;
  @State addFriendInputUid: string = '';

  /**
   * 添加好友面板构建器。
   */
  @Builder
  AddFriendSheetBuilder() {
    Column() {
      // 标题
      Text('添加好友')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 20, bottom: 20 })

      // 输入框
      TextInput({
        placeholder: '请输入好友UID',
        text: $$this.addFriendInputUid
      })
        .fontSize(16)
        .fontColor('#333333')
        .placeholderFont({ size: 16 })
        .placeholderColor('#999999')
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .height(48)
        .width('90%')
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 20 })

      // 按钮区
      Row() {
        Button('取消')
          .fontSize(16)
          .fontColor('#666666')
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .height(44)
          .layoutWeight(1)
          .onClick(() => {
            this.isShowAddFriendSheet = false;
            this.addFriendInputUid = '';
          })

        Blank().width(16)

        Button('添加')
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor('#0A59F7')
          .borderRadius(8)
          .height(44)
          .layoutWeight(1)
          .onClick(async () => {
            await this.doAddFriend();
          })
      }
      .width('90%')
    }
    .width('100%')
    .padding({ bottom: 30 })
  }

  /**
   * 执行添加好友操作。
   */
  async doAddFriend(): Promise<void> {
    const friendUid = this.addFriendInputUid.trim();

    if (!friendUid || friendUid.length === 0) {
      ToolKits.showToast('请输入好友UID');
      return;
    }

    const currentUid = ClientCoreSDK.getInstance().currentLoginInfo?.loginUserId;
    if (friendUid === currentUid) {
      ToolKits.showToast('不能添加自己为好友');
      return;
    }

    if (this.conversationManager && this.conversationManager.hasConversation(friendUid)) {
      ToolKits.showToast('该好友已在会话列表中');
      return;
    }

    try {
      if (this.conversationManager) {
        const added = await this.conversationManager.addConversation(friendUid);
        if (added) {
          ToolKits.showToast('添加成功');
          this.isShowAddFriendSheet = false;
          this.addFriendInputUid = '';

          // 自动跳转到聊天详情页
          setTimeout(() => {
            this.goToChatDetail(friendUid);
          }, 500);
        }
      }
    } catch (err) {
      console.error(TAG + 'Failed to add friend: ' + JSON.stringify(err));
      ToolKits.showToast('添加失败');
    }
  }

  /**
   * 检查会话是否置顶。
   */
  isPinned(uid: string): boolean {
    if (this.conversationManager) {
      return this.conversationManager.isPinned(uid);
    }
    return false;
  }

  /**
   * 构建左滑菜单。
   */
  @Builder
  buildSwipeMenu(uid: string) {
    Row() {
      // 置顶按钮
      Button(this.isPinned(uid) ? '取消置顶' : '置顶')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor('#F4B942')
        .borderRadius(0)
        .width(70)
        .height('100%')
        .onClick(() => {
          this.togglePin(uid);
        })

      // 删除按钮
      Button('删除')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor('#FF3B30')
        .borderRadius(0)
        .width(70)
        .height('100%')
        .onClick(() => {
          this.confirmDelete(uid);
        })
    }
    .height('100%')
  }

  /**
   * 置顶/取消置顶会话。
   */
  async togglePin(uid: string): Promise<void> {
    if (this.conversationManager) {
      const success = await this.conversationManager.togglePin(uid);
      if (success) {
        const isPinned = this.conversationManager.isPinned(uid);
        ToolKits.showToast(isPinned ? '已置顶' : '已取消置顶');
        // 刷新会话列表
        this.refreshConversationList();
      }
    }
  }

  /**
   * 确认删除会话。
   */
  confirmDelete(uid: string): void {
    promptAction.showDialog({
      title: '删除会话',
      message: `确定删除与 ${uid} 的聊天记录吗？`,
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '删除', color: '#FF3B30' }
      ]
    }).then((result) => {
      if (result.index === 1) {
        // 用户点击了删除按钮
        this.deleteConversation(uid);
      }
    }).catch((err: Error) => {
      console.error(TAG + 'Dialog error: ' + err.message);
    });
  }

  /**
   * 删除会话。
   */
  async deleteConversation(uid: string): Promise<void> {
    try {
      // 删除会话记录
      if (this.conversationManager) {
        const success = await this.conversationManager.removeConversation(uid);
        if (success) {
          // 删除该好友的所有聊天消息
          IMClientManager.getInstance().getMessageProvider().deleteMessagesByFriendUid(uid);
          
          ToolKits.showToast('删除成功');
          // 刷新会话列表
          this.refreshConversationList();
        }
      }
    } catch (err) {
      console.error(TAG + 'Failed to delete conversation: ' + JSON.stringify(err));
      ToolKits.showToast('删除失败');
    }
  }
}
