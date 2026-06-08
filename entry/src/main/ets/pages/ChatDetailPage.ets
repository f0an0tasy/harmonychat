import { ErrorCode, ClientCoreSDK, PKickoutInfo } from 'mobileimsdk/Index';
import { ChatInputView } from './components/ChatInputView';
import { MsgView_normal } from './components/msg_view/NormalMsgView';
import { MsgView_system } from './components/msg_view/SystemMsgView';
import Message from './model/Message';
import MsgType from './constants/MsgType';
import MessagesDataSource from './model/MessagesDataSource';
import IMClientManager from '../IMClientManager';
import UIEvent from './constants/UIEvent';
import { router } from '@kit.ArkUI';
import ToolKits from './utils/ToolKits';
import { common } from '@kit.AbilityKit';
import { MsgTimeView } from './components/msg_view/MsgTimeView';
import UserDatabaseHelper from './utils/UserDatabaseHelper';

// 定义事件数据接口
interface MessageAddedEventData {
  friendUid: string;
  index: number;
}

interface MessageUpdatedEventData {
  friendUid: string;
  index: number;
}

interface MessagesUpdatedEventData {
  friendUid: string;
  indexes: number[];
}

const TAG: string = '[ChatDetailPage] ';

/**
 * 聊天详情页面。
 * 显示与指定好友的聊天消息列表。
 * 从会话列表点击进入，通过路由参数传递 friendUid。
 *
 * @author wangyifan & qinweiming
 */
@Entry
@Component
struct ChatDetailPage {
  /** 聊天列表的滚动条组件 */
  private scroller: Scroller = new Scroller();

  /** 当前聊天对象的好友UID（从路由参数获取） */
  private friendUid: string = '';
  
  /** 当前登录用户UID */
  private currentUser: string = '';

  /** 连接状态 */
  @State connectStatus: boolean = ClientCoreSDK.getInstance().connectedToServer;
  /** 心跳状态 */
  @State keepAliveStatus: boolean = false;
  
  /** 是否正在加载更多消息 */
  @State isLoadingMore: boolean = false;
  /** 是否还有更多历史消息 */
  @State hasMoreMessages: boolean = true;
  /** 是否已从数据库加载过消息 */
  private isInitializedFromDb: boolean = false;
  /** 是否是首次进入页面（用于控制初始滚动） */
  private isFirstEnter: boolean = true;

  /** 聊天消息列表数据源 */
  messagesDataSource: MessagesDataSource = new MessagesDataSource();

  /** 事件回调 */
  private meessageAddedEventCallback?: Function;
  private meessageUpdateEventCallback?: Function;
  private meessagesUpdateEventCallback?: Function;
  private loginCompleteEventCallback?: Function;
  private disconnectedEventCallback?: Function;
  private keepAliveEventCallback?: Function;
  private kickoutEventCallback?: Function;

  /**
   * 组件即将出现时调用。
   */
  async aboutToAppear(): Promise<void> {
    // 获取路由参数
    const params = router.getParams() as Record<string, Object>;
    if (params && params['friendUid']) {
      this.friendUid = params['friendUid'] as string;
      console.info(TAG + 'friendUid from params: ' + this.friendUid);
    }

    // 获取当前登录用户
    this.currentUser = ClientCoreSDK.getInstance().currentLoginInfo?.loginUserId ?? '';
    
    // 初始化数据库
    const context = getContext(this) as common.UIAbilityContext;
    const dbHelper = UserDatabaseHelper.getInstance(context);
    await dbHelper.initDatabase();
    
    // 设置MessagesProvider的当前用户
    IMClientManager.getInstance().getMessageProvider().setCurrentUser(this.currentUser, context);

    // 设置数据源的好友UID并初始化
    if (this.friendUid) {
      this.messagesDataSource.setFriendUid(this.friendUid);
      // 切换到该好友的消息
      IMClientManager.getInstance().getMessageProvider().switchToFriend(this.friendUid);
      
      // 从数据库加载历史消息
      if (!this.isInitializedFromDb) {
        const loaded = await IMClientManager.getInstance().getMessageProvider()
          .initFromDatabase(this.friendUid, this.currentUser);
        if (loaded) {
          this.isInitializedFromDb = true;
          // 更新是否有更多消息的状态
          this.hasMoreMessages = IMClientManager.getInstance().getMessageProvider()
            .hasMoreHistoryMessages(this.friendUid);
          // 刷新数据源
          this.messagesDataSource.notifyDataReload();
          
          // 滚动到最新消息（底部）
          // 使用 setTimeout 确保 UI 渲染完成后再滚动
          setTimeout(() => {
            this.scrollToBottom();
          }, 100);
        }
      }
    }

    // 添加事件监听
    this.addEvents();

    // 添加一条系统消息（仅在首次打开时）
    const messages = IMClientManager.getInstance().getMessageProvider().getMessagesOfFriend(this.friendUid);
    if (messages.length === 0) {
      IMClientManager.getInstance().getMessageProvider().addSystemMessage('与 ' + this.friendUid + ' 的聊天');
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
    // 设置键盘避让模式
    ToolKits.setKeyboardAvoidModeToRESIZE(this.getUIContext(), true);
    // 设置状态栏颜色
    ToolKits.setStatusBarColor(
      getContext(this),
      ToolKits.chat_page_title_color,
      ToolKits.chat_page_title_background_color
    );

    // 刷新消息列表
    this.messagesDataSource.notifyDataReload();
    
    // 首次进入页面时滚动到底部
    if (this.isFirstEnter) {
      this.isFirstEnter = false;
      // 使用 setTimeout 确保 UI 渲染完成后再滚动
      setTimeout(() => {
        this.scrollToBottom();
      }, 150);
    }
  }

  /**
   * 页面隐藏时调用。
   */
  onPageHide(): void {
    ToolKits.setKeyboardAvoidModeToRESIZE(this.getUIContext(), false);
  }

  /**
   * 添加事件监听。
   */
  addEvents(): void {
    // 增加了聊天消息
    IMClientManager.getInstance().getEmitter().on(
      UIEvent.UIEVENT_messageAdded,
      this.meessageAddedEventCallback = (data: MessageAddedEventData) => {
        // 只刷新当前好友的消息
        if (data && data.friendUid === this.friendUid) {
          this.messagesDataSource.notifyDataAdd(data.index);
          this.scrollToBottom();
        }
      }
    );

    // 更新了聊天消息（单条）
    IMClientManager.getInstance().getEmitter().on(
      UIEvent.UIEVENT_messageUpdate,
      this.meessageUpdateEventCallback = (data: MessageUpdatedEventData) => {
        if (data && data.friendUid === this.friendUid) {
          this.messagesDataSource.notifyDataChange(data.index);
        }
      }
    );

    // 更新了聊天消息（多条）
    IMClientManager.getInstance().getEmitter().on(
      UIEvent.UIEVENT_messagesUpdate,
      this.meessagesUpdateEventCallback = (data: MessagesUpdatedEventData) => {
        if (data && data.friendUid === this.friendUid) {
          this.messagesDataSource.notifyDataReload();
        }
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
    IMClientManager.getInstance().getEmitter().off(UIEvent.UIEVENT_messageAdded, this.meessageAddedEventCallback);
    IMClientManager.getInstance().getEmitter().off(UIEvent.UIEVENT_messageUpdate, this.meessageUpdateEventCallback);
    IMClientManager.getInstance().getEmitter().off(UIEvent.UIEVENT_messagesUpdate, this.meessagesUpdateEventCallback);
    IMClientManager.getInstance().getEmitter().off(UIEvent.UIEVENT_onIMAfterLoginComplete, this.loginCompleteEventCallback);
    IMClientManager.getInstance().getEmitter().off(UIEvent.UIEVENT_onIMDisconnected, this.disconnectedEventCallback);
    IMClientManager.getInstance().getEmitter().off(UIEvent.UIEVENT_onIMPing, this.keepAliveEventCallback);
    IMClientManager.getInstance().getEmitter().off(UIEvent.UIEVENT_onKickout, this.kickoutEventCallback);
  }

  /**
   * 滚动消息列表到最底部。
   */
  scrollToBottom(): void {
    this.scroller.scrollEdge(Edge.Bottom);
  }
  
  /**
   * 加载更多历史消息。
   * 当滚动到顶部时调用。
   */
  async loadMoreMessages(): Promise<void> {
    if (this.isLoadingMore || !this.hasMoreMessages) {
      return;
    }
    
    this.isLoadingMore = true;
    console.info(TAG + 'Loading more messages...');
    
    try {
      const olderMessages = await IMClientManager.getInstance().getMessageProvider()
        .loadMoreMessages(this.friendUid, this.currentUser);
      
      if (olderMessages.length > 0) {
        // 刷新数据源
        this.messagesDataSource.notifyDataReload();
        
        // 保持滚动位置（可选：滚动到加载前的第一条消息位置）
        // 这里简单处理，让用户看到新加载的消息
      }
      
      // 更新是否有更多消息的状态
      this.hasMoreMessages = IMClientManager.getInstance().getMessageProvider()
        .hasMoreHistoryMessages(this.friendUid);
      
      console.info(TAG + 'Loaded ' + olderMessages.length + ' older messages, hasMore: ' + this.hasMoreMessages);
    } catch (err) {
      console.error(TAG + 'Failed to load more messages: ' + JSON.stringify(err));
    } finally {
      this.isLoadingMore = false;
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
   * 返回上一页。
   */
  goBack(): void {
    router.back();
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        // 返回按钮
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor(['#333333'])
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.goBack();
        })

        // 连接状态指示器
        Row() {
          if (this.connectStatus) {
            Row()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(this.keepAliveStatus ? '#00de7a' : '#00de7a')
              .opacity(this.keepAliveStatus ? 1.0 : 0.6)
          } else {
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

        // 标题（好友UID）
        Text(this.friendUid || '聊天')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 占位（保持标题居中）
        Row()
          .width(60)
          .height(40)
      }
      .width('100%')
      .height(56)
      .backgroundColor(Color.White)

      // 分割线
      Divider()
        .width('100%')
        .height(1)
        .color('#F0F0F0')

      // 聊天消息列表
      Column() {
        List({ scroller: this.scroller }) {
          LazyForEach(this.messagesDataSource, (m: Message, index: number) => {
            ListItem() {
              Column() {
                // 消息时间
                MsgTimeView({ message: m })

                // 消息内容
                if (m.msgType === MsgType.TYPE_SYSTEAM$INFO) {
                  MsgView_system({ message: m })
                } else if (m.msgType === MsgType.TYPE_TEXT) {
                  MsgView_normal({ message: m })
                } else {
                  // TODO: 更多消息类型支持
                }
              }
            }
            .margin({ top: index === 0 ? 15 : 0, bottom: 15 })
          }, (m: Message) => MessagesDataSource.messageItemKey(m))
        }
        .onTouch((event: TouchEvent) => {
          ToolKits.hideSoftInputMethod(this.getUIContext());
        })
        .onSizeChange((oldValue: SizeOptions, newValue: SizeOptions) => {
          let oldHeight = oldValue.height ?? 0;
          let newHeight = newValue.height ?? 0;
          let toBeSmall = (newHeight > 0 && newHeight < oldHeight);
          if (toBeSmall) {
            this.scrollToBottom();
          }
        })
        .onScrollIndex((start: number, end: number) => {
          // 当第一个可见项索引为0时，尝试加载更多消息
          if (start === 0 && !this.isLoadingMore && this.hasMoreMessages) {
            this.loadMoreMessages();
          }
        })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .listDirection(Axis.Vertical)
      }
      .backgroundColor('#f0f2f6')
      .layoutWeight(1)

      // 底部消息输入区（传入 friendUid）
      ChatInputView({ friendUid: this.friendUid })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
