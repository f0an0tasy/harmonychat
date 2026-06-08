import { common } from '@kit.AbilityKit';
import { ClientCoreSDK } from 'mobileimsdk/Index';

const TAG: string = '[AvatarCacheManager] ';

/**
 * 头像缓存管理器。
 * 用于缓存从消息中接收到的其他用户的头像ID。
 * 
 * 功能说明：
 * 1. 当收到消息中携带 avatarId 时，更新缓存
 * 2. 提供 getAvatar() 方法供 UI 组件获取头像ID
 * 3. 通过 EventHub 发送头像更新事件，通知 UI 刷新
 * 
 * @author wangyifan & qinweiming
 */
export default class AvatarCacheManager {
  /** 本类的全局单例 */
  private static instance: AvatarCacheManager;
  
  /** 头像缓存：Map<uid, avatarId> */
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
   * 当收到消息中携带 avatarId 时调用。
   * 
   * @param uid 用户UID
   * @param avatarId 头像ID字符串（1-11）
   * @returns boolean true表示缓存已更新，false表示无变化
   */
  updateAvatar(uid: string, avatarId: string): boolean {
    console.info(TAG + `=== updateAvatar 被调用 ===`);
    console.info(TAG + `uid: ${uid}`);
    console.info(TAG + `avatarId: ${avatarId}`);
    
    if (!uid || !avatarId) {
      console.error(TAG + `❌ 参数无效：uid=${uid}, avatarId=${avatarId ? '有值' : '空'}`);
      return false;
    }
    
    // 验证avatarId格式
    const avatarIdNum = parseInt(avatarId, 10);
    if (isNaN(avatarIdNum) || avatarIdNum < 1 || avatarIdNum > 11) {
      console.error(TAG + `❌ avatarId无效：${avatarId}，应为1-11的数字`);
      return false;
    }
    
    const cachedAvatarId = this.cache.get(uid);
    console.info(TAG + `缓存中是否已有该用户头像: ${cachedAvatarId ? '是' : '否'}`);
    
    // 如果缓存中的值与新值相同，则无需更新
    if (cachedAvatarId === avatarId) {
      console.info(TAG + `✅ 头像缓存无变化，uid: ${uid}`);
      return false;
    }
    
    // 更新缓存
    this.cache.set(uid, avatarId);
    console.info(TAG + `✅ 头像缓存已更新，uid: ${uid}, avatarId: ${avatarId}`);
    
    // 打印当前缓存内容
    console.info(TAG + `当前缓存大小: ${this.cache.size}`);
    this.cache.forEach((value: string, key: string) => {
      console.info(TAG + `缓存项 - uid: ${key}, avatarId: ${value}`);
    });
    
    // 发送头像更新事件，通知 UI 刷新
    if (this.eventHub) {
      console.info(TAG + `准备发送头像更新事件...`);
      try {
        this.eventHub.emit('avatarUpdated', uid);
        console.info(TAG + `✅ 头像更新事件已发送，uid: ${uid}`);
      } catch (err) {
        console.error(TAG + `❌ 发送头像更新事件失败: ${JSON.stringify(err)}`);
      }
    } else {
      console.error(TAG + `❌ EventHub未初始化，无法发送事件`);
    }
    
    return true;
  }
  
  /**
   * 获取用户头像ID。
   * 
   * @param uid 用户UID
   * @returns string | undefined 返回头像ID字符串（1-11），undefined表示无缓存
   */
  getAvatar(uid: string): string | undefined {
    const avatarId = this.cache.get(uid);
    
    // 打印获取日志（仅在调试时启用）
    // if (avatarId) {
    //   console.info(TAG + `getAvatar: uid=${uid}, 找到缓存，avatarId=${avatarId}`);
    // } else {
    //   console.info(TAG + `getAvatar: uid=${uid}, 未找到缓存`);
    // }
    
    return avatarId;
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
 * 1. 维护上次发送的头像ID，避免每次消息都携带
 * 2. 仅在头像变化时才携带，减少网络开销
 * 3. 提供重置方法，在用户修改头像后调用
 * 
 * @author wangyifan & qinweiming
 */
export class AvatarSendManager {
  /** 上次发送的头像ID */
  private static lastSentAvatarId: number = 0;
  
  /**
   * 获取上次发送的头像ID。
   * 
   * @returns number 上次发送的头像ID（0表示未发送过）
   */
  static getLastSentAvatarId(): number {
    return AvatarSendManager.lastSentAvatarId;
  }
  
  /**
   * 更新上次发送的头像ID。
   * 
   * @param avatarId 新的头像ID
   */
  static updateLastSentAvatarId(avatarId: number): void {
    AvatarSendManager.lastSentAvatarId = avatarId;
    console.info(TAG + `Last sent avatar updated, avatarId: ${avatarId}`);
  }
  
  /**
   * 重置上次发送的头像ID。
   * 在用户修改头像后调用，确保下次发送消息时携带新头像。
   */
  static resetLastSentAvatarBase64(): void {
    AvatarSendManager.lastSentAvatarId = 0;
    console.info(TAG + 'Last sent avatar reset');
  }
  
  /**
   * 检查是否需要携带头像。
   * 
   * @param currentAvatarId 当前的头像ID
   * @returns boolean true表示需要携带
   */
  static shouldSendAvatar(currentAvatarId: number): boolean {
    // 如果当前头像ID无效，不需要携带
    if (currentAvatarId < 1 || currentAvatarId > 11) {
      return false;
    }
    
    // 如果与上次发送的头像不同，需要携带
    return AvatarSendManager.lastSentAvatarId !== currentAvatarId;
  }
}
