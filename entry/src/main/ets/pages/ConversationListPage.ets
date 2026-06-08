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
import UserDatabaseHelper, { ConversationSummaryFromDB } from './utils/UserDatabaseHelper';
import { promptAction } from '@kit.ArkUI';

const TAG: string = '[ConversationListPage] ';

/**
 * 会话列表页面。
 * 显示所有聊天会话，点击可进入聊天详情页。
 * 类似微信的"微信"页面。
 *
 * @author wangyifan & qinweiming
 */
@Component
export struct ConversationListPage {
  /** 会话列表摘要（直接从数据库加载，包含最新消息信息） */
  @State conversationSummaries: ConversationSummaryFromDB[] = [];

  /** 连接状态 */
  @State connectStatus: boolean = ClientCoreSDK.getInstance().connectedToServer;
  /** 心跳状态 */
  @State keepAliveStatus: boolean = false;

  /** 当前登录用户名 */
  @StorageProp('currentUsername') @Watch('onCurrentUsernameChanged') currentUsername: string = '';
  /** 用户头像首字母 */
  @State avatarText: string = 'U';
  /** 用户头像路径 */
  @State avatarPath: string = '';
  /** 头像刷新触发器 */
  @StorageLink('avatarRefreshTrigger') @Watch('onAvatarRefreshTriggered') avatarRefreshTrigger: number = 0;


  /** 会话列表刷新触发器（由父组件 MainPage 控制） */
  @Link @Watch('onRefreshTriggered') refreshTrigger: number;
  /** 会话管理器 */
  private conversationManager: ConversationManager | null = null;

  /** 上下文 */
  private context: common.UIAbilityContext | null = null;

  /** 字体缩放管理器 */
  private fontScaleManager: FontScaleManager | null = null;

  /** 添加好友对话框控制器 */
  private addFriendDialogController?: CustomDialogController;

  /** 事件回调 */
  private loginCompleteEventCallback?: Function;
  private disconnectedEventCallback?: Function;
  private keepAliveEventCallback?: Function;
  private kickoutEventCallback?: Function;
  private loginSuccessEventCallback?: Function;

  /**
   * 组件即将出现时调用。
   */
  async aboutToAppear(): Promise<void> {
    // 初始化上下文
    this.context = getContext(this) as common.UIAbilityContext;

    // 初始化会话管理器（保留用于置顶、删除等功能）
    this.conversationManager = ConversationManager.getInstance(this.context);
    
    // 设置当前用户，用于按用户隔离会话列表
    if (this.currentUsername && this.currentUsername.length > 0) {
      this.conversationManager.setCurrentUser(this.currentUsername);
    }

    // === 关键修改：直接从数据库加载会话列表 ===
    await this.loadConversationsFromDatabase();

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
    
    // 注册登录成功事件监听
    if (this.context) {
      this.context.eventHub.on('loginSuccess', this.loginSuccessEventCallback = (username: string) => {
        console.info(TAG + 'Login success event received, username: ' + username);
        // 手动更新 currentUsername（虽然 @Watch 会自动触发，但这里确保同步）
        this.currentUsername = username;
        // 设置当前用户到会话管理器
        if (this.conversationManager) {
          this.conversationManager.setCurrentUser(username);
        }
        // 设置头像文字
        this.avatarText = username.charAt(0).toUpperCase();
        // 重新加载会话列表
        this.loadConversationsFromDatabase();
      });
    }
  }

  /**
   * 组件即将消失时调用。
   */
  aboutToDisappear(): void {
    this.removeEvents();
    // 取消登录成功事件监听
    if (this.context && this.loginSuccessEventCallback) {
      this.context.eventHub.off('loginSuccess', this.loginSuccessEventCallback);
    }
  }

  /**
   * 页面显示时调用。
   * === 关键修改：从详情页返回时也重新加载会话列表 ===
   */
  /**
   * 头像刷新触发器变化时的回调。
   */
  onAvatarRefreshTriggered(): void {
    this.loadUserAvatar();
  }

  /**
   * 会话列表刷新触发器变化时的回调。
   * 由父组件 MainPage 的 onPageShow 触发。
   */
  onRefreshTriggered(): void {
    console.info(TAG + '刷新触发器变化，触发值=' + this.refreshTrigger);
    // 从详情页返回时重新加载会话列表，确保数据是最新的
    if (this.currentUsername && this.currentUsername.length > 0) {
      this.loadConversationsFromDatabase();
    }
  }

  /**
   * 当前登录用户名变化时的回调。
   */
  onCurrentUsernameChanged(): void {
    // 当用户切换账号时，更新会话管理器的当前用户并重新加载会话列表
    if (this.conversationManager && this.currentUsername && this.currentUsername.length > 0) {
      this.conversationManager.setCurrentUser(this.currentUsername);
      this.loadConversationsFromDatabase();
    }
  }

  /**
   * 从数据库加载会话列表。
   * 
   * === 关键修复：考虑置顶状态并正确排序 ===
   * 1. 从数据库加载会话列表摘要（按时间倒序）
   * 2. 根据ConversationManager的置顶状态重新排序
   * 3. 置顶会话排在最前面，且置顶会话之间按时间倒序排列
   * 4. 普通会话也按时间倒序排列
   */
  async loadConversationsFromDatabase(): Promise<void> {
    console.info(TAG + '=== loadConversationsFromDatabase 开始 ===');
    
    // 如果当前用户未登录，清空列表并返回
    if (!this.currentUsername || this.currentUsername.length === 0) {
      console.info(TAG + '当前用户未登录，清空会话列表');
      this.conversationSummaries = [];
      return;
    }
    
    // === 关键：先清空数组，触发 UI 刷新 ===
    this.conversationSummaries = [];
    
    try {
      // 获取数据库实例
      const dbHelper = UserDatabaseHelper.getInstance(this.context!);
      await dbHelper.initDatabase();
      
      // === 关键：直接从数据库查询会话列表摘要（按时间倒序） ===
      const summaries = await dbHelper.getConversationListFromMessages(this.currentUsername);
      
      console.info(TAG + '从数据库加载会话列表，数量=' + summaries.length);
      
      // === 关键修复：根据置顶状态重新排序 ===
      const sortedSummaries = this.sortSummariesByPinnedStatus(summaries);
      
      // === 关键：赋值为全新的数组实例，确保 UI 更新 ===
      this.conversationSummaries = [...sortedSummaries];
      
      console.info(TAG + '✅ 会话列表排序完成，最终数量=' + sortedSummaries.length);
      
      // 打印会话摘要信息（调试用）
      for (let i = 0; i < sortedSummaries.length; i++) {
        const summary = sortedSummaries[i];
        const isPinned = this.isPinned(summary.friendUid);
        console.info(TAG + `[${i}] ${isPinned ? '📌' : '  '} uid=${summary.friendUid}` +
          `, time=${new Date(summary.lastMessageTime).toLocaleString()}` +
          `, msg=${summary.lastMessage.length > 20 ? summary.lastMessage.substring(0, 20) + '...' : summary.lastMessage}`);
      }
    } catch (err) {
      console.error(TAG + '❌ 加载会话列表失败: ' + JSON.stringify(err));
      this.conversationSummaries = [];
    }
    
    console.info(TAG + '=== loadConversationsFromDatabase 完成 ===');
  }
  
  /**
   * 根据置顶状态重新排序会话列表。
   * === 关键修复：置顶会话排在最前面，且都按时间倒序 ===
   * @param summaries 会话摘要数组
   * @returns 排序后的会话摘要数组
   */
  sortSummariesByPinnedStatus(summaries: ConversationSummaryFromDB[]): ConversationSummaryFromDB[] {
    console.info(TAG + '=== sortSummariesByPinnedStatus 开始 ===');
    
    // 分离置顶和普通会话
    const pinnedSummaries: ConversationSummaryFromDB[] = [];
    const normalSummaries: ConversationSummaryFromDB[] = [];
    
    for (const summary of summaries) {
      if (this.isPinned(summary.friendUid)) {
        pinnedSummaries.push(summary);
      } else {
        normalSummaries.push(summary);
      }
    }
    
    console.info(TAG + '置顶会话数量: ' + pinnedSummaries.length);
    console.info(TAG + '普通会话数量: ' + normalSummaries.length);
    
    // 置顶会话和普通会话都已经是按时间倒序（从数据库查询时已排序）
    // 所以直接合并即可：置顶在前，普通在后
    const result = [...pinnedSummaries, ...normalSummaries];
    
    console.info(TAG + '=== sortSummariesByPinnedStatus 完成 ===');
    return result;
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
      if (this.conversationSummaries.length > 0) {
        List() {
          ForEach(this.conversationSummaries, (summary: ConversationSummaryFromDB, index: number) => {
            ListItem() {
              Column() {
                ConversationItem({
                  friendUid: summary.friendUid,
                  lastMessage: summary.lastMessage,
                  lastMessageTime: summary.lastMessageTime,
                  isPinned: this.isPinned(summary.friendUid),
                  avatarId: summary.lastAvatarId ?? 1 // 使用最新消息的头像ID，默认为1
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
              this.goToChatDetail(summary.friendUid);
            })
            .swipeAction({
              end: {
                builder: () => this.buildSwipeMenu(summary.friendUid),
                actionAreaDistance: 120
              }
            })
          }, (summary: ConversationSummaryFromDB) => {
            // === 关键：key 必须包含 lastMessageTime 和 lastMessage，确保 UI 正确更新 ===
            return summary.friendUid + '_' + summary.lastMessageTime + '_' + summary.lastMessage;
          })
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
   * === 性能优化：先更新 UI，再异步持久化 ===
   * 1. 立即更新本地 conversationSummaries 数组并重新排序
   * 2. 触发 UI 刷新，用户立即看到效果
   * 3. 异步调用持久化，不阻塞 UI
   */
  async togglePin(uid: string): Promise<void> {
    console.info(TAG + '=== togglePin 被调用（优化版） ===');
    console.info(TAG + '参数: uid=' + uid);
    
    if (!this.conversationManager) {
      console.error(TAG + '❌ conversationManager 为 null，无法执行置顶操作');
      ToolKits.showToast('操作失败');
      return;
    }
    
    // === 第1步：立即更新本地 UI ===
    const isCurrentlyPinned = this.isPinned(uid);
    const newPinnedState = !isCurrentlyPinned;
    console.info(TAG + '当前置顶状态: ' + isCurrentlyPinned + ', 新状态: ' + newPinnedState);
    
    // 立即更新 conversationSummaries 数组并重新排序
    const newSummaries = this.applyLocalPinSort(uid, newPinnedState);
    this.conversationSummaries = [...newSummaries];
    console.info(TAG + '✅ UI 已立即更新');
    
    // === 第2步：立即显示 toast 提示 ===
    ToolKits.showToast(newPinnedState ? '已置顶' : '已取消置顶');
    
    // === 第3步：异步持久化（不等待完成） ===
    console.info(TAG + '开始异步持久化...');
    this.conversationManager.togglePin(uid).then(success => {
      if (success) {
        console.info(TAG + '✅ 持久化成功');
      } else {
        console.error(TAG + '❌ 持久化失败');
        // 持久化失败时回滚 UI（可选）
        ToolKits.showToast('保存失败，请重试');
      }
    }).catch((err: Error) => {
      console.error(TAG + '❌ 持久化异常: ' + err.message);
      ToolKits.showToast('保存失败，请重试');
    });
    
    console.info(TAG + '=== togglePin 完成（UI 已更新，持久化异步进行） ===');
  }
  
  /**
   * 应用本地置顶排序。
   * === 性能优化：不查询数据库，直接在内存中重新排序 ===
   * @param uid 要操作的会话 UID
   * @param newPinnedState 新的置顶状态
   * @returns 排序后的会话摘要数组
   */
  private applyLocalPinSort(uid: string, newPinnedState: boolean): ConversationSummaryFromDB[] {
    console.info(TAG + '=== applyLocalPinSort 开始 ===');
    
    // 分离置顶和普通会话
    const pinnedSummaries: ConversationSummaryFromDB[] = [];
    const normalSummaries: ConversationSummaryFromDB[] = [];
    
    for (const summary of this.conversationSummaries) {
      if (summary.friendUid === uid) {
        // 目标会话：使用新的置顶状态
        if (newPinnedState) {
          pinnedSummaries.push(summary);
        } else {
          normalSummaries.push(summary);
        }
      } else {
        // 其他会话：保持原有置顶状态
        if (this.isPinned(summary.friendUid)) {
          pinnedSummaries.push(summary);
        } else {
          normalSummaries.push(summary);
        }
      }
    }
    
    // 分别按时间倒序排序（最新的在上面）
    pinnedSummaries.sort((a, b) => b.lastMessageTime - a.lastMessageTime);
    normalSummaries.sort((a, b) => b.lastMessageTime - a.lastMessageTime);
    
    // 合并：置顶在前，普通在后
    const result = [...pinnedSummaries, ...normalSummaries];
    
    console.info(TAG + '置顶会话数量: ' + pinnedSummaries.length);
    console.info(TAG + '普通会话数量: ' + normalSummaries.length);
    console.info(TAG + '=== applyLocalPinSort 完成 ===');
    
    return result;
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
   * === 关键修复：确保删除数据库中的消息记录 ===
   */
  async deleteConversation(uid: string): Promise<void> {
    console.info(TAG + '=== deleteConversation 开始 ===');
    console.info(TAG + '参数: uid=' + uid);
    
    try {
      // 删除会话记录
      if (this.conversationManager) {
        console.info(TAG + '准备从 ConversationManager 中删除会话');
        const success = await this.conversationManager.removeConversation(uid);
        console.info(TAG + 'ConversationManager.removeConversation 返回: ' + success);
        
        if (success) {
          // === 关键修复：删除数据库中的消息记录 ===
          console.info(TAG + '准备删除数据库中的消息记录');
          const dbHelper = UserDatabaseHelper.getInstance(this.context!);
          await dbHelper.initDatabase();
          const dbSuccess = await dbHelper.deleteMessagesByFriend(uid, this.currentUsername);
          console.info(TAG + '数据库删除结果: ' + dbSuccess);
          
          // 同时清理内存中的消息缓存
          console.info(TAG + '清理内存中的消息缓存');
          IMClientManager.getInstance().getMessageProvider().deleteMessagesByFriendUid(uid);
          
          ToolKits.showToast('删除成功');
          
          // 刷新会话列表
          console.info(TAG + '刷新会话列表');
          await this.loadConversationsFromDatabase();
          
          console.info(TAG + '✅ 删除成功');
        } else {
          console.error(TAG + '❌ ConversationManager.removeConversation 失败');
          ToolKits.showToast('删除失败');
        }
      } else {
        console.error(TAG + '❌ conversationManager 为 null');
        ToolKits.showToast('删除失败');
      }
    } catch (err) {
      console.error(TAG + '❌ Failed to delete conversation: ' + JSON.stringify(err));
      ToolKits.showToast('删除失败');
    }
    
    console.info(TAG + '=== deleteConversation 完成 ===');
  }
}
