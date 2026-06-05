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
      const savedList = await this.preferences.get(KEY_FRIEND_LIST, '[]');
      const listStr = savedList as string;
      this.conversations = JSON.parse(listStr) as string[];
      console.info(TAG + 'Conversations loaded: ' + this.conversations.length + ' items');
      return this.conversations;
    } catch (err) {
      console.error(TAG + 'Failed to load conversations: ' + JSON.stringify(err));
      this.conversations = [];
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
      await this.preferences.put(KEY_FRIEND_LIST, JSON.stringify(this.conversations));
      await this.preferences.flush();
      console.info(TAG + 'Conversations saved: ' + this.conversations.length + ' items');
    } catch (err) {
      console.error(TAG + 'Failed to save conversations: ' + JSON.stringify(err));
    }
  }

  /**
   * 获取会话列表。
   * @returns 好友UID数组
   */
  public getConversations(): string[] {
    return this.conversations;
  }

  /**
   * 检查好友是否已在会话列表中。
   * @param friendUid 好友UID
   * @returns true表示已存在
   */
  public hasConversation(friendUid: string): boolean {
    return this.conversations.includes(friendUid);
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
    const index = this.conversations.indexOf(friendUid);
    if (index === -1) {
      console.info(TAG + 'Conversation not found: ' + friendUid);
      return false;
    }

    this.conversations.splice(index, 1);
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

    // 将该会话移动到列表最前面（最新消息的会话在最上面）
    const index = this.conversations.indexOf(friendUid);
    if (index > 0) {
      this.conversations.splice(index, 1);
      this.conversations.unshift(friendUid);
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
    this.conversationSummaries.clear();
    await this.saveConversations();
    this.notifyConversationListUpdated();
  }
}
