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
import { ClientCoreSDK } from 'mobileimsdk/Index';

const TAG: string = '[AvatarCacheManager] ';

/**
 * 头像缓存管理器。
 * 用于缓存从消息中接收到的其他用户的头像Base64数据。
 * 
 * 功能说明：
 * 1. 当收到消息中携带 avatarBase64 时，更新缓存
 * 2. 提供 getAvatar() 方法供 UI 组件获取头像
 * 3. 通过 EventHub 发送头像更新事件，通知 UI 刷新
 * 
 * @author Jack Jiang
 */
export default class AvatarCacheManager {
  /** 本类的全局单例 */
  private static instance: AvatarCacheManager;
  
  /** 头像缓存：Map<uid, base64> */
  private cache: Map<string, string> = new Map();
  
  /** EventHub 引用（用于发送头像更新事件） */
  private eventHub?: common.EventHub;
  
  /**
   * 获得本类的全局单例。
   * 
   * @returns AvatarCacheManager单例
   */
  static getInstance(): AvatarCacheManager {
    if (!AvatarCacheManager.instance) {
      AvatarCacheManager.instance = new AvatarCacheManager();
    }
    return AvatarCacheManager.instance;
  }
  
  private constructor() {
  }
  
  /**
   * 初始化 EventHub 引用。
   * 在 IMClientManager 初始化时调用。
   * 
   * @param eventHub EventHub对象
   */
  init(eventHub: common.EventHub): void {
    this.eventHub = eventHub;
  }
  
  /**
   * 更新用户头像缓存。
   * 当收到消息中携带 avatarBase64 时调用。
   * 
   * @param uid 用户UID
   * @param base64 头像Base64字符串
   * @returns boolean true表示缓存已更新，false表示无变化
   */
  updateAvatar(uid: string, base64: string): boolean {
    if (!uid || !base64) {
      return false;
    }
    
    const cachedBase64 = this.cache.get(uid);
    
    // 如果缓存中的值与新值相同，则无需更新
    if (cachedBase64 === base64) {
      console.info(TAG + `Avatar cache not changed for uid: ${uid}`);
      return false;
    }
    
    // 更新缓存
    this.cache.set(uid, base64);
    console.info(TAG + `Avatar cache updated for uid: ${uid}, base64 length: ${base64.length}`);
    
    // 发送头像更新事件，通知 UI 刷新
    if (this.eventHub) {
      this.eventHub.emit('avatarUpdated', uid);
      console.info(TAG + `Avatar update event emitted for uid: ${uid}`);
    }
    
    return true;
  }
  
  /**
   * 获取用户头像Base64。
   * 
   * @param uid 用户UID
   * @returns string | undefined 返回Base64字符串，undefined表示无缓存
   */
  getAvatar(uid: string): string | undefined {
    return this.cache.get(uid);
  }
  
  /**
   * 检查是否存在指定用户的头像缓存。
   * 
   * @param uid 用户UID
   * @returns boolean true表示存在缓存
   */
  hasAvatar(uid: string): boolean {
    return this.cache.has(uid);
  }
  
  /**
   * 清空所有缓存。
   * 在退出登录时调用。
   */
  clear(): void {
    this.cache.clear();
    console.info(TAG + 'Avatar cache cleared');
  }
  
  /**
   * 删除指定用户的头像缓存。
   * 
   * @param uid 用户UID
   */
  removeAvatar(uid: string): void {
    this.cache.delete(uid);
    console.info(TAG + `Avatar cache removed for uid: ${uid}`);
  }
}

/**
 * 头像发送管理器。
 * 用于管理发送消息时的头像携带逻辑。
 * 
 * 功能说明：
 * 1. 维护上次发送的头像Base64，避免每次消息都携带
 * 2. 仅在头像变化时才携带，减少网络开销
 * 3. 提供重置方法，在用户修改头像后调用
 * 
 * @author Jack Jiang
 */
export class AvatarSendManager {
  /** 上次发送的头像Base64 */
  private static lastSentAvatarBase64: string = '';
  
  /**
   * 获取上次发送的头像Base64。
   * 
   * @returns string 上次发送的头像Base64
   */
  static getLastSentAvatarBase64(): string {
    return AvatarSendManager.lastSentAvatarBase64;
  }
  
  /**
   * 更新上次发送的头像Base64。
   * 
   * @param base64 新的头像Base64
   */
  static updateLastSentAvatarBase64(base64: string): void {
    AvatarSendManager.lastSentAvatarBase64 = base64;
    console.info(TAG + `Last sent avatar updated, length: ${base64.length}`);
  }
  
  /**
   * 重置上次发送的头像Base64。
   * 在用户修改头像后调用，确保下次发送消息时携带新头像。
   */
  static resetLastSentAvatarBase64(): void {
    AvatarSendManager.lastSentAvatarBase64 = '';
    console.info(TAG + 'Last sent avatar reset');
  }
  
  /**
   * 检查是否需要携带头像。
   * 
   * @param currentBase64 当前的头像Base64
   * @returns boolean true表示需要携带
   */
  static shouldSendAvatar(currentBase64: string): boolean {
    // 如果当前头像为空，不需要携带
    if (!currentBase64 || currentBase64.length === 0) {
      return false;
    }
    
    // 如果与上次发送的头像不同，需要携带
    return AvatarSendManager.lastSentAvatarBase64 !== currentBase64;
  }
}
