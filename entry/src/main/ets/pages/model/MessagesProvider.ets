/*
 * Copyright (C) 2024  即时通讯网(52im.net) & Jack Jiang.
 * The MobileIMSDK-鸿蒙Next客户端 Project. All rights reserved.
 *
 * 联系邮件：jack.jiang@52im.net
 * 联系微信：hellojackjiang
 * 联系QQ： 413980957
 * 技术社区：http://www.52im.net
 */

import { ClientCoreSDK, Protocal } from "mobileimsdk/Index";
import IMClientManager from "../../IMClientManager";
import MsgSendStatus from "../constants/MsgSendStatus";
import UIEvent from "../constants/UIEvent";
import Message from "./Message";

/**
 * 聊天消息的缓存数据管理提供者（集中管理所有的聊天消息和指令，消息来源为网络层通信数据包和本地发出的包
 * ，消息显示方式通过MessagesDataSource与UI界面进行解偶显示）。
 *
 * 【改造说明】
 * 原实现使用单一数组存储所有消息，现已改造为按好友UID分组存储（Map<uid, Message[]>），
 * 支持多会话消息管理，类似微信的聊天列表功能。
 *
 * 代码参考自IM产品RainbowChat：http://www.52im.net/thread-19-1-1.html
 *
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 */
export default class MessagesProvider {

  /** 聊天界面中，消息的显示时间间隔（单位：毫秒）：默认是2分钟内的消息只在第一条消息上显示时间，否则会再次显示时间 */
  // 参考资料：http://www.52im.net/thread-3008-1-1.html#40
  private static readonly CHATTING_MESSAGE_SHOW_TIME_INTERVAL: number = 2 * 60 * 1000;

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

    // 通知应用层更新UI（传递好友UID和消息索引）
    IMClientManager.getInstance().getEmitter().emit(UIEvent.UIEVENT_messageAdded, {
      friendUid: friendUid,
      index: messages.length - 1
    });
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
      // 发出的消息，好友UID从消息内容或当前聊天对象获取
      friendUid = this.currentFriendUid;
    } else {
      // 收到的消息，好友UID就是发送者
      friendUid = m.senderId;
    }

    if (!friendUid) {
      console.error('[MessagesProvider] Cannot determine friendUid for message');
      return;
    }

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
   * @param friendUid 好友UID
   * @returns 最后一条消息，如果没有则返回undefined
   */
  getLastMessageOfFriend(friendUid: string): Message | undefined {
    const messages = this.messagesMap.get(friendUid);
    if (messages && messages.length > 0) {
      return messages[messages.length - 1];
    }
    return undefined;
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
  updateMessageSendStatusOfFriend(friendUid: string, fingerPrint: string, sendStatus: MsgSendStatus): void {
    const messages = this.messagesMap.get(friendUid);
    if (!messages) {
      return;
    }

    for (let i = 0; i < messages.length; i++) {
      let m = messages[i];
      if (m && m.isOutgoing() && m.fingerPrintOfProtocal === fingerPrint) {
        m.sendStatus = sendStatus;
        IMClientManager.getInstance().getEmitter().emit(UIEvent.UIEVENT_messageUpdate, {
          friendUid: friendUid,
          index: i
        });
      }
    }
  }

  /**
   * 更新当前好友的指定指纹码的消息的发送状态（更新单条消息）。
   *
   * @param fingerPrint 消息指纹码（消息id）
   * @param sendStatus 发送状态，see {@link MsgSendStatus}
   */
  updateMessageSendStatus(fingerPrint: string, sendStatus: MsgSendStatus): void {
    // 遍历所有好友的消息列表查找该消息
    this.messagesMap.forEach((messages, friendUid) => {
      for (let i = 0; i < messages.length; i++) {
        let m = messages[i];
        if (m && m.isOutgoing() && m.fingerPrintOfProtocal === fingerPrint) {
          m.sendStatus = sendStatus;
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
  updateMessagesSendStatusOfFriend(friendUid: string, protocals: Protocal[], sendStatus: MsgSendStatus): void {
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
  updateMessagesSendStatus(protocals: Protocal[], sendStatus: MsgSendStatus): void {
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
  }

  /**
   * 清空所有消息。
   */
  clear(): void {
    this.messagesMap.clear();
    this.currentFriendUid = '';
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
