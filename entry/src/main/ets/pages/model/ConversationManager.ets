import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import IMClientManager from '../../IMClientManager';
import UIEvent from '../constants/UIEvent';
import UserDatabaseHelper, { ConversationSummaryFromDB } from '../utils/UserDatabaseHelper';

const TAG: string = '[ConversationManager] ';
const PREFERENCES_NAME: string = 'ConversationStore';
const KEY_FRIEND_LIST: string = 'friend_list';
const KEY_PINNED_FRIENDS: string = 'pinned_friends';

/**
 * 会话摘要信息。
 * 用于在会话列表中显示每个会话的概要信息。
 */
export interface ConversationSummary {
  /** 好友UID */
  friendUid: string;
  /** 最后一条消息内容 */
  lastMessage: string;
  /** 最后一条消息时间戳 */
  lastMessageTime: number;
  /** 未读消息数量（暂未实现） */
  unreadCount: number;
}

/**
 * 会话列表管理类。
 * 负责管理会话列表的存储、加载、添加、删除等操作。
 * 使用 Preferences 持久化存储好友UID列表。
 *
 * @author wangyifan & qinweiming
 */
export default class ConversationManager {
  /** 单例实例 */
  private static instance: ConversationManager | null = null;

  /** Preferences 实例 */
  private preferences?: preferences.Preferences;

  /** 上下文 */
  private context?: common.UIAbilityContext;

  /** 会话列表（好友UID数组） */
  private conversations: string[] = [];

  /** 置顶会话列表（好友UID数组） */
  private pinnedConversations: string[] = [];

  /** 会话摘要信息Map */
  private conversationSummaries: Map<string, ConversationSummary> = new Map();

  /** 当前登录用户UID */
  private currentUser: string = '';

  /** 私有构造函数 */
  private constructor() {}

  /**
   * 获取单例实例。
   * @param context 应用上下文（首次调用时必须提供）
   * @returns ConversationManager 实例
   */
  public static getInstance(context?: common.UIAbilityContext): ConversationManager {
    if (ConversationManager.instance === null) {
      ConversationManager.instance = new ConversationManager();
      if (context) {
        ConversationManager.instance.context = context;
        ConversationManager.instance.initPreferences();
      }
    }
    return ConversationManager.instance;
  }

  /**
   * 设置当前登录用户UID。
   * 用于按用户隔离存储会话列表。
   * @param uid 当前用户UID
   */
  public setCurrentUser(uid: string): void {
    if (this.currentUser !== uid) {
      this.currentUser = uid;
      console.info(TAG + 'Current user set to: ' + uid);
      // 切换用户时清空内存中的会话列表，等待下次加载
      this.conversations = [];
      this.pinnedConversations = [];
      this.conversationSummaries.clear();
    }
  }

  /**
   * 获取当前登录用户UID。
   * @returns 当前用户UID
   */
  public getCurrentUser(): string {
    return this.currentUser;
  }

  /**
   * 获取存储键（按当前用户隔离）。
   * @param baseKey 基础键名
   * @returns 完整的存储键
   */
  private getStorageKey(baseKey: string): string {
    if (this.currentUser && this.currentUser.length > 0) {
      return `${baseKey}_${this.currentUser}`;
    } else {
      // 未设置当前用户时使用默认键（例如未登录状态）
      return baseKey;
    }
  }

  /**
   * 初始化 Preferences。
   */
  private async initPreferences(): Promise<void> {
    if (!this.context) {
      console.error(TAG + 'Context is null, cannot init preferences');
      return;
    }

    try {
      this.preferences = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      console.info(TAG + 'Preferences initialized successfully');
    } catch (err) {
      console.error(TAG + 'Failed to init preferences: ' + JSON.stringify(err));
    }
  }

  /**
   * 加载会话列表（从 Preferences）。
   * 应用启动时调用。
   */
  public async loadConversations(): Promise<string[]> {
    if (!this.preferences) {
      await this.initPreferences();
    }

    if (!this.preferences) {
      console.error(TAG + 'Preferences is null, cannot load conversations');
      return [];
    }

    try {
      // 加载普通会话列表（按当前用户隔离）
      const friendListKey = this.getStorageKey(KEY_FRIEND_LIST);
      const savedList = await this.preferences.get(friendListKey, '[]');
      const listStr = savedList as string;
      let loadedConversations = JSON.parse(listStr) as string[];
      
      // 加载置顶会话列表（按当前用户隔离）
      const pinnedListKey = this.getStorageKey(KEY_PINNED_FRIENDS);
      const savedPinnedList = await this.preferences.get(pinnedListKey, '[]');
      const pinnedListStr = savedPinnedList as string;
      let loadedPinnedConversations = JSON.parse(pinnedListStr) as string[];
      
      // 过滤掉当前用户自己的UID（防止历史数据混入）
      if (this.currentUser && this.currentUser.length > 0) {
        loadedConversations = loadedConversations.filter(uid => uid !== this.currentUser);
        loadedPinnedConversations = loadedPinnedConversations.filter(uid => uid !== this.currentUser);
      }
      
      // 去重（确保每个UID在列表中只出现一次，虽然正常情况下不会重复）
      loadedConversations = Array.from(new Set(loadedConversations));
      loadedPinnedConversations = Array.from(new Set(loadedPinnedConversations));
      
      this.conversations = loadedConversations;
      this.pinnedConversations = loadedPinnedConversations;
      
      // 从数据库加载会话摘要
      await this.loadConversationSummariesFromDatabase();
      
      console.info(TAG + 'Conversations loaded: ' + this.conversations.length + ' items, pinned: ' + this.pinnedConversations.length + ' items');
      
      // 返回合并后的列表（置顶在前，普通在后）
      return this.getMergedConversations();
    } catch (err) {
      console.error(TAG + 'Failed to load conversations: ' + JSON.stringify(err));
      this.conversations = [];
      this.pinnedConversations = [];
      return [];
    }
  }
  
  /**
   * 从数据库加载会话摘要信息。
   */
  private async loadConversationSummariesFromDatabase(): Promise<void> {
    if (!this.currentUser || this.currentUser.length === 0) {
      return;
    }
    
    if (!this.context) {
      return;
    }
    
    try {
      const dbHelper = UserDatabaseHelper.getInstance(this.context);
      await dbHelper.initDatabase();
      
      const summaries = await dbHelper.getConversationListFromMessages(this.currentUser);
      
      // 更新会话摘要Map
      for (const summary of summaries) {
        this.conversationSummaries.set(summary.friendUid, {
          friendUid: summary.friendUid,
          lastMessage: summary.lastMessage,
          lastMessageTime: summary.lastMessageTime,
          unreadCount: summary.unreadCount
        });
        
        // 如果会话列表中没有该好友，自动添加
        if (!this.hasConversation(summary.friendUid) && summary.friendUid !== this.currentUser) {
          this.conversations.push(summary.friendUid);
        }
      }
      
      console.info(TAG + 'Conversation summaries loaded from DB: ' + summaries.length);
    } catch (err) {
      console.error(TAG + 'Failed to load conversation summaries from DB: ' + JSON.stringify(err));
    }
  }

  /**
   * 保存会话列表（到 Preferences）。
   */
  private async saveConversations(): Promise<void> {
    if (!this.preferences) {
      await this.initPreferences();
    }

    if (!this.preferences) {
      console.error(TAG + 'Preferences is null, cannot save conversations');
      return;
    }

    try {
      // 过滤掉当前用户自己的UID（防止意外添加）
      let conversationsToSave = this.conversations.filter(uid => uid !== this.currentUser);
      let pinnedConversationsToSave = this.pinnedConversations.filter(uid => uid !== this.currentUser);
      
      // 去重（确保每个UID在列表中只出现一次）
      conversationsToSave = Array.from(new Set(conversationsToSave));
      pinnedConversationsToSave = Array.from(new Set(pinnedConversationsToSave));
      
      // 保存普通会话列表（按当前用户隔离）
      const friendListKey = this.getStorageKey(KEY_FRIEND_LIST);
      await this.preferences.put(friendListKey, JSON.stringify(conversationsToSave));
      // 保存置顶会话列表（按当前用户隔离）
      const pinnedListKey = this.getStorageKey(KEY_PINNED_FRIENDS);
      await this.preferences.put(pinnedListKey, JSON.stringify(pinnedConversationsToSave));
      await this.preferences.flush();
      console.info(TAG + 'Conversations saved: ' + conversationsToSave.length + ' items, pinned: ' + pinnedConversationsToSave.length + ' items');
    } catch (err) {
      console.error(TAG + 'Failed to save conversations: ' + JSON.stringify(err));
    }
  }

  /**
   * 获取会话列表。
   * 返回合并后的列表（置顶在前，普通在后）。
   * @returns 好友UID数组
   */
  public getConversations(): string[] {
    return this.getMergedConversations();
  }

  /**
   * 获取合并后的会话列表（置顶在前，普通在后）。
   * === 关键修复：按最新消息时间倒序排列 ===
   * @returns 好友UID数组
   */
  private getMergedConversations(): string[] {
    console.info(TAG + '=== getMergedConversations 开始 ===');
    
    // === 关键修复：对置顶会话按时间倒序排序 ===
    const sortedPinned = this.sortConversationsByTime([...this.pinnedConversations]);
    console.info(TAG + '置顶会话排序后: ' + sortedPinned.join(', '));
    
    // === 关键修复：对普通会话按时间倒序排序 ===
    const sortedNormal = this.sortConversationsByTime([...this.conversations]);
    console.info(TAG + '普通会话排序后: ' + sortedNormal.join(', '));
    
    // 合并：置顶在前，普通在后
    const result = [...sortedPinned, ...sortedNormal];
    console.info(TAG + '合并后列表: ' + result.join(', '));
    console.info(TAG + '=== getMergedConversations 完成 ===');
    
    return result;
  }
  
  /**
   * 按最新消息时间倒序排列会话列表。
   * @param conversations 会话UID数组
   * @returns 排序后的会话UID数组
   */
  private sortConversationsByTime(conversations: string[]): string[] {
    return conversations.sort((a, b) => {
      const timeA = this.getLastMessageTime(a);
      const timeB = this.getLastMessageTime(b);
      // 按时间倒序：时间大的排前面
      return timeB - timeA;
    });
  }

  /**
   * 检查会话是否置顶。
   * @param friendUid 好友UID
   * @returns true表示已置顶
   */
  public isPinned(friendUid: string): boolean {
    return this.pinnedConversations.includes(friendUid);
  }

  /**
   * 置顶/取消置顶会话。
   * === 性能优化：只负责内存状态更新和持久化，不触发 UI 刷新 ===
   * UI 刷新由 ConversationListPage 直接处理，避免全量数据库查询。
   * @param friendUid 好友UID
   * @returns true表示操作成功
   */
  public async togglePin(friendUid: string): Promise<boolean> {
    console.info(TAG + '=== togglePin 开始（优化版） ===');
    console.info(TAG + '参数: friendUid=' + friendUid);
    console.info(TAG + '当前 conversations: ' + JSON.stringify(this.conversations));
    console.info(TAG + '当前 pinnedConversations: ' + JSON.stringify(this.pinnedConversations));
    
    // === 关键修复：如果会话不存在，自动添加 ===
    if (!this.hasConversation(friendUid) && !this.pinnedConversations.includes(friendUid)) {
      console.info(TAG + '会话不存在，自动添加到列表');
      await this.addConversationSilent(friendUid);
      console.info(TAG + '自动添加完成，重新检查状态');
      console.info(TAG + '添加后 conversations: ' + JSON.stringify(this.conversations));
      console.info(TAG + '添加后 pinnedConversations: ' + JSON.stringify(this.pinnedConversations));
    }

    const isCurrentlyPinned = this.isPinned(friendUid);
    console.info(TAG + '当前置顶状态: ' + isCurrentlyPinned);
    
    if (isCurrentlyPinned) {
      // 取消置顶：从置顶列表移到普通列表
      const pinnedIndex = this.pinnedConversations.indexOf(friendUid);
      if (pinnedIndex !== -1) {
        this.pinnedConversations.splice(pinnedIndex, 1);
        // 添加到普通列表（稍后会重新排序）
        this.conversations.push(friendUid);
        console.info(TAG + '从置顶列表移除，添加到普通列表');
      }
    } else {
      // 置顶：从普通列表移到置顶列表
      const normalIndex = this.conversations.indexOf(friendUid);
      if (normalIndex !== -1) {
        this.conversations.splice(normalIndex, 1);
        console.info(TAG + '从普通列表移除');
      }
      // 添加到置顶列表（稍后会重新排序）
      this.pinnedConversations.push(friendUid);
      console.info(TAG + '添加到置顶列表');
    }

    // === 关键修复：保存前先重新排序 ===
    this.pinnedConversations = this.sortConversationsByTime([...this.pinnedConversations]);
    this.conversations = this.sortConversationsByTime([...this.conversations]);
    console.info(TAG + '重新排序完成');
    console.info(TAG + '置顶列表: ' + this.pinnedConversations.join(', '));
    console.info(TAG + '普通列表: ' + this.conversations.join(', '));
    
    // 保存到 Preferences
    await this.saveConversations();
    
    // === 性能优化：不调用 notifyConversationListUpdated()，由 ConversationListPage 直接更新 UI ===
    // this.notifyConversationListUpdated();

    console.info(TAG + '置顶操作完成，新状态: ' + !isCurrentlyPinned);
    console.info(TAG + '=== togglePin 完成 ===');
    return true;
  }
  
  /**
   * 静默添加会话（不通知 UI）。
   * 用于 togglePin 内部自动添加会话时使用。
   * @param friendUid 好友UID
   * @returns true表示添加成功
   */
  private async addConversationSilent(friendUid: string): Promise<boolean> {
    console.info(TAG + '=== addConversationSilent 开始 ===');
    
    // 不能添加自己
    if (friendUid === this.currentUser) {
      console.info(TAG + 'Cannot add self as conversation: ' + friendUid);
      return false;
    }

    if (this.hasConversation(friendUid)) {
      console.info(TAG + 'Conversation already exists: ' + friendUid);
      return false;
    }

    // 添加到列表开头
    this.conversations.unshift(friendUid);

    // 初始化会话摘要
    this.conversationSummaries.set(friendUid, {
      friendUid: friendUid,
      lastMessage: '',
      lastMessageTime: 0,
      unreadCount: 0
    });

    // 保存到 Preferences
    await this.saveConversations();
    
    // === 不创建系统消息，不通知 UI ===

    console.info(TAG + 'Conversation added (silent): ' + friendUid);
    console.info(TAG + '=== addConversationSilent 完成 ===');
    return true;
  }

  /**
   * 检查好友是否已在会话列表中。
   * @param friendUid 好友UID
   * @returns true表示已存在
   */
  public hasConversation(friendUid: string): boolean {
    return this.conversations.includes(friendUid) || this.pinnedConversations.includes(friendUid);
  }

  /**
   * 添加会话（好友）。
   * === 关键修复：添加好友时插入系统消息到数据库 ===
   * @param friendUid 好友UID
   * @returns true表示添加成功，false表示已存在或添加了自己
   */
  public async addConversation(friendUid: string): Promise<boolean> {
    console.info(TAG + '=== addConversation 开始 ===');
    console.info(TAG + '参数: friendUid=' + friendUid);
    
    // 不能添加自己
    if (friendUid === this.currentUser) {
      console.info(TAG + 'Cannot add self as conversation: ' + friendUid);
      return false;
    }

    if (this.hasConversation(friendUid)) {
      console.info(TAG + 'Conversation already exists: ' + friendUid);
      return false;
    }

    // 添加到列表开头（最新会话在最上面）
    this.conversations.unshift(friendUid);

    // 初始化会话摘要
    this.conversationSummaries.set(friendUid, {
      friendUid: friendUid,
      lastMessage: '',
      lastMessageTime: 0,
      unreadCount: 0
    });

    // 保存到 Preferences
    await this.saveConversations();

    // === 关键修复：为新添加的好友创建系统消息 ===
    console.info(TAG + '准备为新好友创建系统消息');
    try {
      const messageProvider = IMClientManager.getInstance().getMessageProvider();
      const success = await messageProvider.addSystemMessageForFriend(
        friendUid, 
        '你们已经成为好友，开始聊天吧'
      );
      if (success) {
        console.info(TAG + '✅ 系统消息创建成功');
      } else {
        console.error(TAG + '❌ 系统消息创建失败');
      }
    } catch (err) {
      console.error(TAG + '❌ 创建系统消息异常: ' + JSON.stringify(err));
    }

    // 通知UI更新
    this.notifyConversationListUpdated();

    console.info(TAG + 'Conversation added: ' + friendUid);
    console.info(TAG + '=== addConversation 完成 ===');
    return true;
  }

  /**
   * 删除会话。
   * @param friendUid 好友UID
   * @returns true表示删除成功
   */
  public async removeConversation(friendUid: string): Promise<boolean> {
    let removed = false;
    
    // 从普通列表删除
    const normalIndex = this.conversations.indexOf(friendUid);
    if (normalIndex !== -1) {
      this.conversations.splice(normalIndex, 1);
      removed = true;
    }
    
    // 从置顶列表删除
    const pinnedIndex = this.pinnedConversations.indexOf(friendUid);
    if (pinnedIndex !== -1) {
      this.pinnedConversations.splice(pinnedIndex, 1);
      removed = true;
    }

    if (!removed) {
      console.info(TAG + 'Conversation not found: ' + friendUid);
      return false;
    }

    this.conversationSummaries.delete(friendUid);

    await this.saveConversations();
    this.notifyConversationListUpdated();

    console.info(TAG + 'Conversation removed: ' + friendUid);
    return true;
  }

  /**
   * 更新会话摘要信息。
   * 当收到新消息或发送消息时调用。
   * 
   * === 关键修复：添加时间戳比较逻辑 + 自动重新排序 ===
   * 只有当新消息时间戳 > 当前保存的时间戳时才更新，避免旧消息覆盖新消息。
   * 更新后自动重新排序置顶和普通列表。
   * 
   * @param friendUid 好友UID
   * @param lastMessage 最后一条消息内容
   * @param lastMessageTime 最后一条消息时间戳
   */
  public updateConversationSummary(friendUid: string, lastMessage: string, lastMessageTime: number): void {
    console.info(TAG + '=== updateConversationSummary 开始 ===');
    console.info(TAG + '参数: friendUid=' + friendUid + ', time=' + lastMessageTime + ', content=' + 
      (lastMessage.length > 20 ? lastMessage.substring(0, 20) + '...' : lastMessage));
    
    // 如果会话不存在，自动添加
    if (!this.hasConversation(friendUid)) {
      console.info(TAG + '会话不存在，自动添加');
      this.addConversation(friendUid);
    }

    // 获取当前摘要
    const summary = this.conversationSummaries.get(friendUid);
    
    // === 关键修复：时间戳比较逻辑 ===
    if (summary) {
      const currentTime = summary.lastMessageTime;
      console.info(TAG + '当前保存的时间戳: ' + currentTime + ' (' + new Date(currentTime).toLocaleString() + ')');
      console.info(TAG + '新消息时间戳: ' + lastMessageTime + ' (' + new Date(lastMessageTime).toLocaleString() + ')');
      
      // 只有当新消息时间戳 > 当前保存的时间戳时才更新
      if (lastMessageTime > currentTime) {
        console.info(TAG + '✅ 新消息时间戳更大，更新摘要');
        summary.lastMessage = lastMessage;
        summary.lastMessageTime = lastMessageTime;
      } else {
        console.info(TAG + '⚠️ 新消息时间戳不大于当前时间戳，跳过更新（避免旧消息覆盖新消息）');
      }
    } else {
      console.info(TAG + '当前无摘要，创建新摘要');
      this.conversationSummaries.set(friendUid, {
        friendUid: friendUid,
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
        unreadCount: 0
      });
    }

    // === 关键修复：更新后重新排序，而不是简单移动 ===
    const isPinned = this.isPinned(friendUid);
    console.info(TAG + '会话置顶状态: ' + isPinned);
    
    // 重新排序置顶列表和普通列表
    this.pinnedConversations = this.sortConversationsByTime([...this.pinnedConversations]);
    this.conversations = this.sortConversationsByTime([...this.conversations]);
    console.info(TAG + '重新排序完成');
    console.info(TAG + '置顶列表: ' + this.pinnedConversations.join(', '));
    console.info(TAG + '普通列表: ' + this.conversations.join(', '));

    console.info(TAG + '=== updateConversationSummary 完成 ===');
    
    // 通知UI更新
    this.notifyConversationListUpdated();
  }

  /**
   * 获取会话摘要信息。
   * @param friendUid 好友UID
   * @returns 会话摘要信息
   */
  public getConversationSummary(friendUid: string): ConversationSummary | undefined {
    return this.conversationSummaries.get(friendUid);
  }

  /**
   * 获取最后一条消息内容。
   * @param friendUid 好友UID
   * @returns 最后一条消息内容
   */
  public getLastMessage(friendUid: string): string {
    const summary = this.conversationSummaries.get(friendUid);
    return summary ? summary.lastMessage : '';
  }

  /**
   * 获取最后一条消息时间。
   * @param friendUid 好友UID
   * @returns 最后一条消息时间戳
   */
  public getLastMessageTime(friendUid: string): number {
    const summary = this.conversationSummaries.get(friendUid);
    return summary ? summary.lastMessageTime : 0;
  }

  /**
   * 通知会话列表已更新。
   */
  private notifyConversationListUpdated(): void {
    IMClientManager.getInstance().getEmitter().emit(UIEvent.UIEVENT_conversationListUpdated);
  }

  /**
   * 清空所有会话。
   */
  public async clearAll(): Promise<void> {
    this.conversations = [];
    this.pinnedConversations = [];
    this.conversationSummaries.clear();
    await this.saveConversations();
    this.notifyConversationListUpdated();
  }

  /**
   * 清空内存缓存（不持久化）。
   * 用于登录后强制从数据库重新加载。
   */
  public clearCache(): void {
    console.info(TAG + '=== 清空会话管理器内存缓存 ===');
    this.conversations = [];
    this.pinnedConversations = [];
    this.conversationSummaries.clear();
    console.info(TAG + '✅ 内存缓存已清空');
  }
}
