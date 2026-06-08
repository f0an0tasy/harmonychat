import { ClientCoreSDK, Protocal } from "mobileimsdk/Index";
import IMClientManager from "../../IMClientManager";
import MsgSendStatus from "../constants/MsgSendStatus";
import UIEvent from "../constants/UIEvent";
import Message from "./Message";
import UserDatabaseHelper from "../utils/UserDatabaseHelper";
import { common } from '@kit.AbilityKit';
import ConversationManager from "./ConversationManager";

const TAG: string = '[MessagesProvider] ';

/**
 * 聊天消息的缓存数据管理提供者（集中管理所有的聊天消息和指令，消息来源为网络层通信数据包和本地发出的包
 * ，消息显示方式通过MessagesDataSource与UI界面进行解偶显示）。
 *
 * 【改造说明】
 * 原实现使用单一数组存储所有消息，现已改造为按好友UID分组存储（Map<uid, Message[]>），
 * 支持多会话消息管理，类似微信的聊天列表功能。
 * 
 * 【持久化说明】
 * 新增数据库持久化支持，消息会保存到本地RDB数据库，应用重启后自动加载历史消息。
 *
 * 代码参考自IM产品RainbowChat：http://www.52im.net/thread-19-1-1.html
 *
 * @author wangyifan & qinweiming
 */
export default class MessagesProvider {

  /** 聊天界面中，消息的显示时间间隔（单位：毫秒）：默认是2分钟内的消息只在第一条消息上显示时间，否则会再次显示时间 */
  // 参考资料：http://www.52im.net/thread-3008-1-1.html#40
  private static readonly CHATTING_MESSAGE_SHOW_TIME_INTERVAL: number = 2 * 60 * 1000;
  
  /** 默认加载的消息数量 */
  private static readonly DEFAULT_LOAD_LIMIT: number = 50;
  
  /** 分页加载时每次加载的数量 */
  private static readonly PAGE_LOAD_LIMIT: number = 20;

  /** 
   * 按好友UID分组存储消息（Map<uid, Array<Message>>）。
   * key: 好友UID
   * value: 与该好友的聊天消息列表
   */
  private messagesMap: Map<string, Array<Message>> = new Map();

  /** 
   * 当前聊天对象的好友UID。
   * 用于确定当前显示的是哪个好友的聊天消息。
   */
  private currentFriendUid: string = '';
  
  /** 
   * 当前登录用户UID。
   * 用于数据库操作的用户隔离。
   */
  private currentUser: string = '';
  
  /** 
   * 是否已从数据库加载过消息的标记（Map<friendUid, boolean>）。
   * 避免重复加载。
   */
  private loadedFromDb: Map<string, boolean> = new Map();
  
  /** 
   * 是否还有更多历史消息可加载（Map<friendUid, boolean>）。
   */
  private hasMoreMessages: Map<string, boolean> = new Map();
  
  /** 数据库帮助类实例 */
  private dbHelper: UserDatabaseHelper | null = null;

  /**
   * 设置当前聊天对象。
   * 切换到与指定好友的聊天会话。
   *
   * @param friendUid 好友UID
   */
  switchToFriend(friendUid: string): void {
    this.currentFriendUid = friendUid;
    // 如果该好友还没有消息列表，创建一个空列表
    if (!this.messagesMap.has(friendUid)) {
      this.messagesMap.set(friendUid, []);
    }
  }
  
  /**
   * 设置当前登录用户。
   * 用于数据库操作的用户隔离。
   * 
   * @param uid 当前用户UID
   * @param context 应用上下文（用于获取数据库实例）
   */
  setCurrentUser(uid: string, context?: common.UIAbilityContext): void {
    this.currentUser = uid;
    if (context) {
      this.dbHelper = UserDatabaseHelper.getInstance(context);
    }
    // 切换用户时清空所有缓存
    this.messagesMap.clear();
    this.loadedFromDb.clear();
    this.hasMoreMessages.clear();
    console.info(TAG + 'Current user set to: ' + uid);
  }
  
  /**
   * 获取当前登录用户。
   */
  getCurrentUser(): string {
    return this.currentUser;
  }
  
  /**
   * 从数据库加载与指定好友的消息。
   * 在打开聊天详情页时调用。
   * 
   * @param friendUid 好友UID
   * @param currentUser 当前用户UID
   * @returns Promise<boolean> true表示加载成功
   */
  async initFromDatabase(friendUid: string, currentUser: string): Promise<boolean> {
    // 检查是否已加载过
    if (this.loadedFromDb.get(friendUid) === true) {
      console.info(TAG + 'Messages already loaded from DB for: ' + friendUid);
      return true;
    }
    
    // 确保当前用户已设置
    if (!this.currentUser) {
      this.currentUser = currentUser;
    }
    
    if (!this.dbHelper) {
      const context = AppStorage.get('uiAbilityContext') as common.UIAbilityContext;
      if (context) {
        this.dbHelper = UserDatabaseHelper.getInstance(context);
      }
    }
    
    if (!this.dbHelper) {
      console.error(TAG + 'DatabaseHelper is null, cannot load messages');
      return false;
    }
    
    try {
      // 从数据库加载最近的消息
      const messages = await this.dbHelper.queryMessages(
        friendUid, 
        currentUser, 
        MessagesProvider.DEFAULT_LOAD_LIMIT, 
        0
      );
      
      if (messages.length > 0) {
        // 设置消息时间显示逻辑
        for (let i = 0; i < messages.length; i++) {
          const previousMessage = i > 0 ? messages[i - 1] : undefined;
          MessagesProvider.setMessageShowTopTime(messages[i], previousMessage);
        }
        
        // 存入内存
        this.messagesMap.set(friendUid, messages);
        
        // 检查是否还有更多消息
        const totalCount = await this.dbHelper.getMessageCount(friendUid, currentUser);
        this.hasMoreMessages.set(friendUid, totalCount > messages.length);
      } else {
        // 没有历史消息
        this.messagesMap.set(friendUid, []);
        this.hasMoreMessages.set(friendUid, false);
      }
      
      // 标记已加载
      this.loadedFromDb.set(friendUid, true);
      
      console.info(TAG + 'Messages loaded from DB: ' + messages.length + ' for: ' + friendUid);
      return true;
    } catch (err) {
      console.error(TAG + 'Failed to load messages from DB: ' + JSON.stringify(err));
      return false;
    }
  }
  
  /**
   * 加载更早的历史消息（分页加载）。
   * 当用户滚动到顶部时调用。
   * 
   * @param friendUid 好友UID
   * @param currentUser 当前用户UID
   * @returns Promise<Message[]> 新加载的消息数组
   */
  async loadMoreMessages(friendUid: string, currentUser: string): Promise<Message[]> {
    // 检查是否还有更多消息
    if (this.hasMoreMessages.get(friendUid) === false) {
      console.info(TAG + 'No more messages to load for: ' + friendUid);
      return [];
    }
    
    if (!this.dbHelper) {
      const context = AppStorage.get('uiAbilityContext') as common.UIAbilityContext;
      if (context) {
        this.dbHelper = UserDatabaseHelper.getInstance(context);
      }
    }
    
    if (!this.dbHelper) {
      console.error(TAG + 'DatabaseHelper is null, cannot load more messages');
      return [];
    }
    
    try {
      // 获取当前最早的消息时间戳
      const messages = this.messagesMap.get(friendUid);
      if (!messages || messages.length === 0) {
        return [];
      }
      
      const oldestTimestamp = messages[0].date;
      
      // 查询更早的消息
      const olderMessages = await this.dbHelper.queryMessagesBefore(
        friendUid,
        currentUser,
        oldestTimestamp,
        MessagesProvider.PAGE_LOAD_LIMIT
      );
      
      if (olderMessages.length === 0) {
        this.hasMoreMessages.set(friendUid, false);
        return [];
      }
      
      // 设置消息时间显示逻辑
      for (let i = 0; i < olderMessages.length; i++) {
        const previousMessage = i > 0 ? olderMessages[i - 1] : undefined;
        MessagesProvider.setMessageShowTopTime(olderMessages[i], previousMessage);
      }
      
      // 将旧消息插入到数组头部
      const newMessages = [...olderMessages, ...messages];
      
      // 重新计算第一条消息的时间显示
      if (newMessages.length > 0) {
        newMessages[0].showTopTime = true;
      }
      
      // 更新内存中的消息列表
      this.messagesMap.set(friendUid, newMessages);
      
      // 检查是否还有更多
      if (olderMessages.length < MessagesProvider.PAGE_LOAD_LIMIT) {
        this.hasMoreMessages.set(friendUid, false);
      }
      
      console.info(TAG + 'Older messages loaded: ' + olderMessages.length);
      return olderMessages;
    } catch (err) {
      console.error(TAG + 'Failed to load more messages: ' + JSON.stringify(err));
      return [];
    }
  }
  
  /**
   * 检查是否还有更多历史消息可加载。
   * @param friendUid 好友UID
   * @returns true表示还有更多消息
   */
  hasMoreHistoryMessages(friendUid: string): boolean {
    return this.hasMoreMessages.get(friendUid) === true;
  }

  /**
   * 获取当前聊天对象的好友UID。
   *
   * @returns 当前好友UID
   */
  getCurrentFriendUid(): string {
    return this.currentFriendUid;
  }

  /**
   * 加入一条新消息到指定好友的消息列表。
   *
   * @param friendUid 好友UID
   * @param m 消息对象
   */
  putMessageToFriend(friendUid: string, m: Message): void {
    // 获取或创建该好友的消息列表
    let messages = this.messagesMap.get(friendUid);
    if (!messages) {
      messages = [];
      this.messagesMap.set(friendUid, messages);
    }

    // 设置消息时间显示逻辑
    let previousMessage: Message | undefined = undefined;
    if (messages.length > 0) {
      previousMessage = messages[messages.length - 1];
    }
    MessagesProvider.setMessageShowTopTime(m, previousMessage);

    // 将新消息对象放入数据模型
    messages.push(m);

    // 异步保存到数据库
    this.saveMessageToDatabase(friendUid, m);

    // === 关键修复：更新会话列表摘要 ===
    const conversationManager = ConversationManager.getInstance();
    conversationManager.updateConversationSummary(
      friendUid,
      m.content,
      m.date
    );
    console.info(TAG + '✅ 会话摘要已更新: friendUid=' + friendUid + ', time=' + m.date);

    // 通知应用层更新UI（传递好友UID和消息索引）
    IMClientManager.getInstance().getEmitter().emit(UIEvent.UIEVENT_messageAdded, {
      friendUid: friendUid,
      index: messages.length - 1
    });
  }
  
  /**
   * 异步保存消息到数据库。
   * @param friendUid 好友UID
   * @param message 消息对象
   */
  private async saveMessageToDatabase(friendUid: string, message: Message): Promise<void> {
    console.info('[saveMessageToDatabase] 开始执行');
    console.info('[saveMessageToDatabase] friendUid=' + friendUid);
    console.info('[saveMessageToDatabase] m.content=' + message.content);
    console.info('[saveMessageToDatabase] m.date=' + message.date);
    const currentUser = AppStorage.get<string>('currentUsername');
    console.info('[saveMessageToDatabase] currentUser=' + (currentUser || 'null'));
    console.info('[saveMessageToDatabase] dbHelper=' + (this.dbHelper ? '存在' : 'null'));
    
    if (!this.currentUser) {
      // 尝试从ClientCoreSDK获取当前用户
      const uid = ClientCoreSDK.getInstance().currentLoginInfo?.loginUserId;
      if (uid) {
        this.currentUser = uid;
        console.info('[saveMessageToDatabase] 从ClientCoreSDK获取currentUser=' + uid);
      } else {
        console.warn(TAG + 'Cannot save message: no current user');
        return;
      }
    }
    
    if (!this.dbHelper) {
      const context = AppStorage.get('uiAbilityContext') as common.UIAbilityContext;
      if (context) {
        this.dbHelper = UserDatabaseHelper.getInstance(context);
        console.info('[saveMessageToDatabase] dbHelper已初始化');
      }
    }
    
    if (!this.dbHelper) {
      console.warn(TAG + 'DatabaseHelper is null, cannot save message');
      return;
    }
    
    try {
      console.info('[saveMessageToDatabase] 准备调用 insertMessage...');
      const rowId = await this.dbHelper.insertMessage(message, this.currentUser);
      console.info('[saveMessageToDatabase] insertMessage 返回 rowId=' + rowId);
      if (rowId === -1) {
        console.error('[saveMessageToDatabase] 插入失败！');
      }
    } catch (err) {
      console.error(TAG + 'Failed to save message to DB: ' + JSON.stringify(err));
    }
  }

  /**
   * 加入一条新消息到当前好友的消息列表。
   *
   * @param m 消息对象
   */
  putMessage(m: Message): void {
    // 根据消息发送者确定好友UID
    let friendUid: string;
    if (m.isOutgoing()) {
      // 发出的消息，优先使用message.to字段，其次使用currentFriendUid
      if (m.to && m.to.length > 0) {
        friendUid = m.to;
      } else {
        friendUid = this.currentFriendUid;
      }
    } else {
      // 收到的消息，好友UID就是发送者
      friendUid = m.senderId;
    }

    // === 关键修复：验证friendUid的有效性 ===
    if (!UserDatabaseHelper.isValidFriendUid(friendUid)) {
      console.error(TAG + '❌ Cannot determine valid friendUid for message');
      console.error(TAG + '消息详情: senderId=' + m.senderId + ', isOutgoing=' + m.isOutgoing());
      console.error(TAG + 'message.to=' + (m.to || 'undefined'));
      console.error(TAG + 'currentFriendUid=' + this.currentFriendUid);
      console.error(TAG + 'friendUid=' + friendUid);
      console.error(TAG + '消息将被丢弃，不会存入数据库');
      return;
    }

    console.info(TAG + '✅ friendUid验证通过: ' + friendUid);
    this.putMessageToFriend(friendUid, m);
  }

  /**
   * 获得指定好友的消息数据缓存集合。
   *
   * @param friendUid 好友UID
   * @returns 消息数据缓存集合
   */
  getMessagesOfFriend(friendUid: string): Array<Message> {
    let messages = this.messagesMap.get(friendUid);
    if (!messages) {
      messages = [];
      this.messagesMap.set(friendUid, messages);
    }
    return messages;
  }

  /**
   * 获得当前好友的消息数据缓存集合。
   *
   * @returns 消息数据缓存集合
   */
  getMessages(): Array<Message> {
    if (this.currentFriendUid) {
      return this.getMessagesOfFriend(this.currentFriendUid);
    }
    // 兼容旧代码：如果没有设置当前好友，返回空数组
    return [];
  }

  /**
   * 获取所有有消息记录的好友UID列表。
   *
   * @returns 好友UID数组
   */
  getAllFriendUids(): string[] {
    return Array.from(this.messagesMap.keys());
  }

  /**
   * 获取指定好友的最后一条消息。
   * 
   * === 关键修复：确保返回时间戳最大的消息 ===
   * 因为消息数组可能未按时间排序（例如分页加载时），所以需要遍历查找时间戳最大的消息。
   *
   * @param friendUid 好友UID
   * @returns 最后一条消息，如果没有则返回undefined
   */
  getLastMessageOfFriend(friendUid: string): Message | undefined {
    const messages = this.messagesMap.get(friendUid);
    if (!messages || messages.length === 0) {
      return undefined;
    }
    
    // === 关键修复：遍历查找时间戳最大的消息 ===
    // 不能直接返回数组最后一项，因为数组可能未按时间排序
    let latestMessage: Message | undefined = undefined;
    let maxTimestamp: number = 0;
    
    for (const msg of messages) {
      if (msg.date > maxTimestamp) {
        maxTimestamp = msg.date;
        latestMessage = msg;
      }
    }
    
    if (latestMessage) {
      console.info(TAG + 'getLastMessageOfFriend: friendUid=' + friendUid + 
        ', maxTime=' + maxTimestamp + ' (' + new Date(maxTimestamp).toLocaleString() + ')' +
        ', content=' + (latestMessage.content.length > 20 ? latestMessage.content.substring(0, 20) + '...' : latestMessage.content));
    }
    
    return latestMessage;
  }

  /**
   * 获取指定好友的消息数量。
   *
   * @param friendUid 好友UID
   * @returns 消息数量
   */
  getMessageCountOfFriend(friendUid: string): number {
    const messages = this.messagesMap.get(friendUid);
    return messages ? messages.length : 0;
  }

  /**
   * 添加一条系统消息到指定好友的消息列表。
   *
   * @param friendUid 好友UID
   * @param content 消息内容
   */
  addSystemMessageToFriend(friendUid: string, content: string): void {
    let m: Message = Message.createChatMsgEntity_INCOME_SYSTEAMINFO('0', content, 0);
    this.putMessageToFriend(friendUid, m);
  }

  /**
   * 为新添加的好友创建系统消息（用于会话列表显示）。
   * === 关键修复：添加好友时插入系统消息到数据库 ===
   * 
   * @param friendUid 好友UID
   * @param content 系统消息内容
   * @returns Promise<boolean> true表示创建成功
   */
  async addSystemMessageForFriend(friendUid: string, content: string): Promise<boolean> {
    console.info(TAG + '=== addSystemMessageForFriend 开始 ===');
    console.info(TAG + '参数: friendUid=' + friendUid + ', content=' + content);
    
    if (!this.currentUser) {
      // 尝试从ClientCoreSDK获取当前用户
      const uid = ClientCoreSDK.getInstance().currentLoginInfo?.loginUserId;
      if (uid) {
        this.currentUser = uid;
        console.info(TAG + '从ClientCoreSDK获取currentUser=' + uid);
      } else {
        console.error(TAG + '❌ Cannot add system message: no current user');
        return false;
      }
    }
    
    if (!this.dbHelper) {
      const context = AppStorage.get('uiAbilityContext') as common.UIAbilityContext;
      if (context) {
        this.dbHelper = UserDatabaseHelper.getInstance(context);
        console.info(TAG + 'dbHelper已初始化');
      }
    }
    
    if (!this.dbHelper) {
      console.error(TAG + '❌ DatabaseHelper is null, cannot add system message');
      return false;
    }
    
    try {
      // 创建系统消息对象
      const timestamp = Date.now();
      const message = Message.createChatMsgEntity_INCOME_SYSTEAMINFO('0', content, timestamp);
      message.senderId = friendUid; // 设置发送者为好友UID
      
      console.info(TAG + '准备插入系统消息到数据库');
      console.info(TAG + 'friendUid=' + friendUid);
      console.info(TAG + 'currentUser=' + this.currentUser);
      console.info(TAG + 'timestamp=' + timestamp);
      console.info(TAG + 'content=' + content);
      
      // 直接插入到数据库
      const rowId = await this.dbHelper.insertMessage(message, this.currentUser);
      
      if (rowId === -1) {
        console.error(TAG + '❌ 系统消息插入失败');
        return false;
      }
      
      console.info(TAG + '✅ 系统消息插入成功，rowId=' + rowId);
      
      // 更新会话摘要
      const conversationManager = ConversationManager.getInstance();
      conversationManager.updateConversationSummary(
        friendUid,
        content,
        timestamp
      );
      
      console.info(TAG + '=== addSystemMessageForFriend 完成 ===');
      return true;
    } catch (err) {
      console.error(TAG + '❌ Failed to add system message: ' + JSON.stringify(err));
      return false;
    }
  }

  /**
   * 添加一条系统消息到当前好友的消息列表。
   *
   * @param content 消息内容
   */
  addSystemMessage(content: string): void {
    if (this.currentFriendUid) {
      this.addSystemMessageToFriend(this.currentFriendUid, content);
    }
  }

  /**
   * 更新指定好友的指定指纹码的消息的发送状态（更新单条消息）。
   *
   * @param friendUid 好友UID
   * @param fingerPrint 消息指纹码（消息id）
   * @param sendStatus 发送状态，see {@link MsgSendStatus}
   */
  updateMessageSendStatusOfFriend(friendUid: string, fingerPrint: string, sendStatus: number): void {
    const messages = this.messagesMap.get(friendUid);
    if (!messages) {
      return;
    }

    for (let i = 0; i < messages.length; i++) {
      let m = messages[i];
      if (m && m.isOutgoing() && m.fingerPrintOfProtocal === fingerPrint) {
        m.sendStatus = sendStatus;
        
        // 异步更新数据库中的状态
        this.updateMessageStatusInDatabase(fingerPrint, sendStatus);
        
        IMClientManager.getInstance().getEmitter().emit(UIEvent.UIEVENT_messageUpdate, {
          friendUid: friendUid,
          index: i
        });
      }
    }
  }
  
  /**
   * 异步更新数据库中的消息状态。
   */
  private async updateMessageStatusInDatabase(fingerPrint: string, sendStatus: number): Promise<void> {
    if (!this.currentUser || !this.dbHelper) {
      return;
    }
    
    try {
      await this.dbHelper.updateMessageStatus(fingerPrint, sendStatus, this.currentUser);
    } catch (err) {
      console.error(TAG + 'Failed to update message status in DB: ' + JSON.stringify(err));
    }
  }

  /**
   * 更新当前好友的指定指纹码的消息的发送状态（更新单条消息）。
   *
   * @param fingerPrint 消息指纹码（消息id）
   * @param sendStatus 发送状态，see {@link MsgSendStatus}
   */
  updateMessageSendStatus(fingerPrint: string, sendStatus: number): void {
    // 遍历所有好友的消息列表查找该消息
    this.messagesMap.forEach((messages, friendUid) => {
      for (let i = 0; i < messages.length; i++) {
        let m = messages[i];
        if (m && m.isOutgoing() && m.fingerPrintOfProtocal === fingerPrint) {
          m.sendStatus = sendStatus;
          
          // 异步更新数据库中的状态
          this.updateMessageStatusInDatabase(fingerPrint, sendStatus);
          
          IMClientManager.getInstance().getEmitter().emit(UIEvent.UIEVENT_messageUpdate, {
            friendUid: friendUid,
            index: i
          });
        }
      }
    });
  }

  /**
   * 更新指定好友的指定指纹码的消息的发送状态（更新多条消息）。
   *
   * @param friendUid 好友UID
   * @param protocals 原始消息报文对象数组
   * @param sendStatus 发送状态
   */
  updateMessagesSendStatusOfFriend(friendUid: string, protocals: Protocal[], sendStatus: number): void {
    const messages = this.messagesMap.get(friendUid);
    if (!messages) {
      return;
    }

    let updateIndexes: number[] = [];

    for (let mi = 0; mi < messages.length; mi++) {
      let m = messages[mi];
      for (let i = 0; i < protocals.length; i++) {
        let p = protocals[i];
        if (m && m.isOutgoing() && m.fingerPrintOfProtocal === p.fp) {
          m.sendStatus = sendStatus;
          updateIndexes.push(mi);
          break;
        }
      }
    }

    if (updateIndexes.length > 0) {
      IMClientManager.getInstance().getEmitter().emit(UIEvent.UIEVENT_messagesUpdate, {
        friendUid: friendUid,
        indexes: updateIndexes
      });
    }
  }

  /**
   * 更新指定指纹码的消息的发送状态（更新多条消息）。
   *
   * @param protocals 原始消息报文对象数组
   * @param sendStatus 发送状态
   */
  updateMessagesSendStatus(protocals: Protocal[], sendStatus: number): void {
    // 遍历所有好友的消息列表
    this.messagesMap.forEach((messages, friendUid) => {
      let updateIndexes: number[] = [];

      for (let mi = 0; mi < messages.length; mi++) {
        let m = messages[mi];
        for (let i = 0; i < protocals.length; i++) {
          let p = protocals[i];
          if (m && m.isOutgoing() && m.fingerPrintOfProtocal === p.fp) {
            m.sendStatus = sendStatus;
            updateIndexes.push(mi);
            break;
          }
        }
      }

      if (updateIndexes.length > 0) {
        IMClientManager.getInstance().getEmitter().emit(UIEvent.UIEVENT_messagesUpdate, {
          friendUid: friendUid,
          indexes: updateIndexes
        });
      }
    });
  }

  /**
   * 清空指定好友的所有消息。
   *
   * @param friendUid 好友UID
   */
  clearFriendMessages(friendUid: string): void {
    this.messagesMap.delete(friendUid);
    // 同时删除数据库中的消息
    this.deleteMessagesFromDatabase(friendUid);
  }

  /**
   * 删除指定好友的所有消息（别名方法，语义更清晰）。
   *
   * @param friendUid 好友UID
   */
  deleteMessagesByFriendUid(friendUid: string): void {
    this.clearFriendMessages(friendUid);
    console.info(TAG + 'Messages deleted for friend: ' + friendUid);
  }
  
  /**
   * 异步删除数据库中的消息。
   */
  private async deleteMessagesFromDatabase(friendUid: string): Promise<void> {
    if (!this.currentUser || !this.dbHelper) {
      return;
    }
    
    try {
      await this.dbHelper.deleteMessagesByFriend(friendUid, this.currentUser);
      console.info(TAG + 'Messages deleted from DB for friend: ' + friendUid);
    } catch (err) {
      console.error(TAG + 'Failed to delete messages from DB: ' + JSON.stringify(err));
    }
  }

  /**
   * 清空所有消息。
   */
  clear(): void {
    this.messagesMap.clear();
    this.currentFriendUid = '';
    this.loadedFromDb.clear();
    this.hasMoreMessages.clear();
    // 注意：不清空数据库，下次登录同一账号可自动加载
  }

  /**
   * 为当前的消息对象，设置是否显示消息时间标识。
   *
   * 此时间显示逻辑是与微信保持一致的：即只显示2分钟内聊天消息的时间标识，参考资料：http://www.52im.net/thread-3008-1-1.html#40
   *
   * @param theMessage 当前消息对象，不可为null
   * @param previousMessage 当前消息的自然时间的上一条消息，此消息可为空（此为空即表示当前消息就是消息集合中的第一条消息）
   */
  private static setMessageShowTopTime(theMessage: Message, previousMessage: Message | undefined): void {
    if (theMessage) {
      if (previousMessage === undefined) {
        theMessage.showTopTime = true;
        return;
      }

      if (theMessage.date - previousMessage.date > MessagesProvider.CHATTING_MESSAGE_SHOW_TIME_INTERVAL)
        theMessage.showTopTime = true;
    }
  }
}
