import IMClientManager from "../../IMClientManager";
import { BasicDataSource } from "../common/LazyDataSource";
import Message from "./Message";
import AvatarCacheManager from "../../pages/utils/AvatarCacheManager";
import { ClientCoreSDK } from 'mobileimsdk/Index';

/**
 * 聊天界面（ChatDetailPage.ets）中的List列表对应的数据源实现类（负责聊天消息数据的UI显示）。
 *
 * 注意：本类中的数据来源为全局消息缓存管理类 MessageProvider 中缓存消息集合的对象引用（浅拷贝），相当于共用同一个缓存，无需单
 * 独维护数据，实现了聊天消息数据的管理（MessageProvider负责）和UI界面显示（MessagesDataSource负责）的解偶。
 *
 * 支持多好友消息分组存储，每个好友有独立的消息列表。
 *
 * @author wangyifan & qinweiming
 * @since 2.0
 */
export default class MessagesDataSource extends BasicDataSource<Message> {

  /** 当前好友的UID */
  private friendUid: string = '';

  /** 引用全局消息缓存管理类 MessageProvider 中指定好友的消息集合（浅拷贝）*/
  private messages: Array<Message> = [];

  /**
   * 设置当前好友UID并刷新数据源
   * @param uid 好友UID
   */
  setFriendUid(uid: string): void {
    this.friendUid = uid;
    this.refreshMessages();
  }

  /**
   * 刷新消息引用（从MessagesProvider获取最新消息）
   */
  refreshMessages(): void {
    if (this.friendUid) {
      this.messages = IMClientManager.getInstance().getMessageProvider().getMessagesOfFriend(this.friendUid);
    } else {
      this.messages = [];
    }
  }

  notifyDataReload(): void {
    this.refreshMessages();
    super.notifyDataReload();
  }

  totalCount(): number {
    return this.messages.length
  }

  getData(index: number): Message {
    return this.messages[index]
  }

  /**
   * 在List中使用LazyForEach时，响应式ui需要key变化才会更新，本方法就是按可变的内容计算key，从而在DataSource更新时，
   * 能让ui感知到，不然UI是不会刷新显示的。
   *
   * @param m 消息对象
   * @returns 计算出的key
   */
  static messageItemKey(m: Message) {
    // 优化点：给更新的消息对象加个最近更新时间戳，这应该是个更通用的key计算项，不然一旦变更内容多了，这个key的计算就不那么优雅了
    
    // 获取当前用户ID
    const currentUserId = ClientCoreSDK.getInstance().currentLoginInfo?.loginUserId;
    let avatarHash: string;
    
    // 如果消息是当前用户发出的，使用 AppStorage 中的 currentUserAvatarId
    if (currentUserId && m.senderId === currentUserId) {
      const currentAvatarId = AppStorage.get<number>('currentUserAvatarId') ?? 1;
      avatarHash = currentAvatarId.toString();
    } else {
      // 否则使用缓存中的头像ID
      const avatarBase64 = AvatarCacheManager.getInstance().getAvatar(m.senderId);
      avatarHash = avatarBase64 ? avatarBase64.length.toString() : '0';
    }
    
    const key = `${m.msgType}-${m.fingerPrintOfProtocal}-${m.sendStatus}-${avatarHash}`;
    
    // 打印key计算日志（仅在调试时启用）
    // console.info(`[MessagesDataSource] messageItemKey: senderId=${m.senderId}, avatarHash=${avatarHash}, key=${key}`);
    
    return key;
  }
}
