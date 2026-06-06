/*
 * Copyright (C) 2024  即时通讯网(52im.net) & Jack Jiang.
 * The MobileIMSDK-鸿蒙Next客户端 Project. All rights reserved.
 *
 * 联系邮件：jack.jiang@52im.net
 * 联系微信：hellojackjiang
 * 联系QQ： 413980957
 * 技术社区：http://www.52im.net
 */

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import IMClientManager from '../../IMClientManager';
import UIEvent from '../constants/UIEvent';

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
 * @author Jack Jiang
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
      // 加载普通会话列表
      const savedList = await this.preferences.get(KEY_FRIEND_LIST, '[]');
      const listStr = savedList as string;
      this.conversations = JSON.parse(listStr) as string[];
      
      // 加载置顶会话列表
      const savedPinnedList = await this.preferences.get(KEY_PINNED_FRIENDS, '[]');
      const pinnedListStr = savedPinnedList as string;
      this.pinnedConversations = JSON.parse(pinnedListStr) as string[];
      
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
      // 保存普通会话列表
      await this.preferences.put(KEY_FRIEND_LIST, JSON.stringify(this.conversations));
      // 保存置顶会话列表
      await this.preferences.put(KEY_PINNED_FRIENDS, JSON.stringify(this.pinnedConversations));
      await this.preferences.flush();
      console.info(TAG + 'Conversations saved: ' + this.conversations.length + ' items, pinned: ' + this.pinnedConversations.length + ' items');
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
   * @returns 好友UID数组
   */
  private getMergedConversations(): string[] {
    return [...this.pinnedConversations, ...this.conversations];
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
   * @param friendUid 好友UID
   * @returns true表示操作成功
   */
  public async togglePin(friendUid: string): Promise<boolean> {
    // 检查会话是否存在
    if (!this.hasConversation(friendUid) && !this.pinnedConversations.includes(friendUid)) {
      console.info(TAG + 'Conversation not found: ' + friendUid);
      return false;
    }

    const isCurrentlyPinned = this.isPinned(friendUid);
    
    if (isCurrentlyPinned) {
      // 取消置顶：从置顶列表移到普通列表
      const pinnedIndex = this.pinnedConversations.indexOf(friendUid);
      if (pinnedIndex !== -1) {
        this.pinnedConversations.splice(pinnedIndex, 1);
        // 添加到普通列表开头（按最新消息时间排序）
        this.conversations.unshift(friendUid);
      }
    } else {
      // 置顶：从普通列表移到置顶列表
      const normalIndex = this.conversations.indexOf(friendUid);
      if (normalIndex !== -1) {
        this.conversations.splice(normalIndex, 1);
      }
      // 添加到置顶列表开头
      this.pinnedConversations.unshift(friendUid);
    }

    // 保存到 Preferences
    await this.saveConversations();
    
    // 通知UI更新
    this.notifyConversationListUpdated();

    console.info(TAG + 'Conversation pin toggled: ' + friendUid + ', now pinned: ' + !isCurrentlyPinned);
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
   * @param friendUid 好友UID
   * @returns true表示添加成功，false表示已存在
   */
  public async addConversation(friendUid: string): Promise<boolean> {
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

    // 通知UI更新
    this.notifyConversationListUpdated();

    console.info(TAG + 'Conversation added: ' + friendUid);
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
   * @param friendUid 好友UID
   * @param lastMessage 最后一条消息内容
   * @param lastMessageTime 最后一条消息时间戳
   */
  public updateConversationSummary(friendUid: string, lastMessage: string, lastMessageTime: number): void {
    // 如果会话不存在，自动添加
    if (!this.hasConversation(friendUid)) {
      this.addConversation(friendUid);
    }

    // 更新摘要信息
    const summary = this.conversationSummaries.get(friendUid);
    if (summary) {
      summary.lastMessage = lastMessage;
      summary.lastMessageTime = lastMessageTime;
    } else {
      this.conversationSummaries.set(friendUid, {
        friendUid: friendUid,
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
        unreadCount: 0
      });
    }

    // 根据置顶状态，将该会话移动到对应列表的最前面
    const isPinned = this.isPinned(friendUid);
    
    if (isPinned) {
      // 置顶会话：移动到置顶列表最前面
      const pinnedIndex = this.pinnedConversations.indexOf(friendUid);
      if (pinnedIndex > 0) {
        this.pinnedConversations.splice(pinnedIndex, 1);
        this.pinnedConversations.unshift(friendUid);
      }
    } else {
      // 普通会话：移动到普通列表最前面
      const normalIndex = this.conversations.indexOf(friendUid);
      if (normalIndex > 0) {
        this.conversations.splice(normalIndex, 1);
        this.conversations.unshift(friendUid);
      }
    }

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
}
