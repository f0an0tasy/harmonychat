import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import Message from '../model/Message';
import MsgType from '../constants/MsgType';
import MsgSendStatus from '../constants/MsgSendStatus';

const TAG: string = '[UserDatabaseHelper] ';

/**
 * 会话摘要信息（用于会话列表显示）。
 */
export interface ConversationSummaryFromDB {
  /** 好友UID */
  friendUid: string;
  /** 最后一条消息内容 */
  lastMessage: string;
  /** 最后一条消息时间戳 */
  lastMessageTime: number;
  /** 最后一条消息类型 */
  lastMessageType: number;
  /** 未读消息数量 */
  unreadCount: number;
  /** 最后一条消息发送者的头像ID（1-11），用于会话列表头像显示 */
  lastAvatarId?: number;
}

/**
 * 用户数据库管理类。
 * 使用关系型数据库（RDB）存储用户账号和密码信息。
 * 同时存储聊天消息记录。
 *
 * @author wangyifan & qinweiming
 */
export default class UserDatabaseHelper {
  // 数据库配置
  private readonly DB_NAME: string = 'User.db';
  private readonly DB_VERSION: number = 4; // 升级到版本4，支持聊天消息表
  private readonly TABLE_NAME: string = 'Users';
  private readonly TABLE_MESSAGES: string = 'ChatMessages';
  
  // RDB存储实例
  private rdbStore: relationalStore.RdbStore | null = null;
  // 上下文
  private context: common.UIAbilityContext;
  // 单例实例
  private static instance: UserDatabaseHelper | null = null;
  
  // 头像缓存：username -> avatarId
  private avatarIdCache: Map<string, number> = new Map();
  
  /**
   * 私有构造函数，实现单例模式。
   */
  private constructor(context: common.UIAbilityContext) {
    this.context = context;
  }
  
  /**
   * 获取单例实例。
   * @param context 应用上下文
   * @returns UserDatabaseHelper 实例
   */
  public static getInstance(context: common.UIAbilityContext): UserDatabaseHelper {
    if (UserDatabaseHelper.instance === null) {
      UserDatabaseHelper.instance = new UserDatabaseHelper(context);
    }
    return UserDatabaseHelper.instance;
  }
  
  /**
   * 初始化数据库。
   * 创建数据库和用户表。
   */
  public async initDatabase(): Promise<void> {
    try {
      // 配置数据库创建参数
      const config: relationalStore.StoreConfig = {
        name: this.DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1
      };
      
      // 创建或打开数据库
      this.rdbStore = await relationalStore.getRdbStore(this.context, config);
      console.info(TAG + 'Database created/opened successfully: ' + this.DB_NAME);
      
      // 创建用户表
      await this.createUserTable();
      
      // 创建消息表
      await this.createMessagesTable();
      
      // 检查并升级数据库（添加avatar_id字段）
      await this.upgradeDatabase();
    } catch (err) {
      console.error(TAG + 'Failed to initialize database: ' + JSON.stringify(err));
      if (err instanceof Error) {
        throw err;
      } else {
        throw new Error(JSON.stringify(err));
      }
    }
  }
  
  /**
   * 创建用户表。
   * 表结构：id (主键自增), username (唯一), password, avatar_id
   */
  private async createUserTable(): Promise<void> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot create table');
      return;
    }
    
    // SQL建表语句（包含avatar_id字段）
    const createTableSql = `
      CREATE TABLE IF NOT EXISTS ${this.TABLE_NAME} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        avatar_id INTEGER DEFAULT 1
      )
    `;
    
    try {
      await this.rdbStore.executeSql(createTableSql);
      console.info(TAG + 'User table created successfully');
    } catch (err) {
      console.error(TAG + 'Failed to create user table: ' + JSON.stringify(err));
      if (err instanceof Error) {
        throw err;
      } else {
        throw new Error(JSON.stringify(err));
      }
    }
  }
  
  /**
   * 创建聊天消息表。
   * 表结构：
   * - id: 自增主键
   * - uid: 当前登录用户UID（用于多账号隔离）
   * - friend_uid: 对方用户ID
   * - is_outgoing: 是否自己发送的消息（1=是，0=否）
   * - msg_type: 消息类型
   * - content: 消息内容
   * - timestamp: 消息时间戳（毫秒）
   * - send_status: 发送状态
   * - finger_print: 消息指纹码
   * - sender_id: 发送者ID
   * - sender_name: 发送者昵称
   * - avatar_id: 发送者头像ID
   */
  private async createMessagesTable(): Promise<void> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot create messages table');
      return;
    }
    
    // SQL建表语句
    const createTableSql = `
      CREATE TABLE IF NOT EXISTS ${this.TABLE_MESSAGES} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        friend_uid TEXT NOT NULL,
        is_outgoing INTEGER NOT NULL,
        msg_type INTEGER NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        send_status INTEGER DEFAULT 0,
        finger_print TEXT,
        sender_id TEXT NOT NULL,
        sender_name TEXT,
        avatar_id INTEGER DEFAULT 1
      )
    `;
    
    // 创建索引（用于加速按会话查询）
    const createIndexSql = `
      CREATE INDEX IF NOT EXISTS idx_messages_uid_friend_time 
      ON ${this.TABLE_MESSAGES} (uid, friend_uid, timestamp DESC)
    `;
    
    // 创建指纹码索引（用于去重检查）
    const createFingerPrintIndexSql = `
      CREATE INDEX IF NOT EXISTS idx_messages_finger_print 
      ON ${this.TABLE_MESSAGES} (finger_print)
    `;
    
    try {
      await this.rdbStore.executeSql(createTableSql);
      await this.rdbStore.executeSql(createIndexSql);
      await this.rdbStore.executeSql(createFingerPrintIndexSql);
      console.info(TAG + 'Messages table created successfully');
    } catch (err) {
      console.error(TAG + 'Failed to create messages table: ' + JSON.stringify(err));
      if (err instanceof Error) {
        throw err;
      } else {
        throw new Error(JSON.stringify(err));
      }
    }
  }
  
  /**
   * 升级数据库。
   * 检查avatar_id字段是否存在，不存在则添加。
   * 同时迁移旧的avatar_path数据（如果存在）。
   */
  private async upgradeDatabase(): Promise<void> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot upgrade database');
      return;
    }
    
    try {
      // 查询表结构，检查字段是否存在
      const tableInfoSql = `PRAGMA table_info(${this.TABLE_NAME})`;
      const resultSet = await this.rdbStore.querySql(tableInfoSql);
      
      let hasAvatarId = false;
      let hasAvatarPath = false;
      while (resultSet.goToNextRow()) {
        const columnName = resultSet.getString(resultSet.getColumnIndex('name'));
        if (columnName === 'avatar_id') {
          hasAvatarId = true;
        }
        if (columnName === 'avatar_path') {
          hasAvatarPath = true;
        }
      }
      resultSet.close();
      
      // 如果avatar_id字段不存在，则添加
      if (!hasAvatarId) {
        const alterTableSql = `ALTER TABLE ${this.TABLE_NAME} ADD COLUMN avatar_id INTEGER DEFAULT 1`;
        await this.rdbStore.executeSql(alterTableSql);
        console.info(TAG + 'Database upgraded: avatar_id column added');
      } else {
        console.info(TAG + 'Database already has avatar_id column');
      }
      
      // 如果旧的avatar_path字段存在，可以在这里迁移数据或删除
      // 简单起见，我们保留旧字段但不使用它
      if (hasAvatarPath) {
        console.info(TAG + 'Database has old avatar_path column (will be ignored)');
      }
    } catch (err) {
      console.error(TAG + 'Failed to upgrade database: ' + JSON.stringify(err));
    }
  }
  
  /**
   * 添加新用户。
   * @param username 用户名
   * @param password 密码
   * @returns Promise<number> 返回插入的行号，-1表示用户名已存在
   */
  public async addUser(username: string, password: string): Promise<number> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot add user');
      return -1;
    }
    
    try {
      // 先检查用户名是否已存在
      const exists = await this.isUserExists(username);
      if (exists) {
        console.info(TAG + 'Username already exists: ' + username);
        return -1;
      }
      
      // 插入新用户（avatar_id默认为1）
      const valueBucket: relationalStore.ValuesBucket = {
        'username': username,
        'password': password,
        'avatar_id': 1
      };
      
      const rowId = await this.rdbStore.insert(this.TABLE_NAME, valueBucket);
      console.info(TAG + 'User added successfully, rowId: ' + rowId);
      return rowId;
    } catch (err) {
      console.error(TAG + 'Failed to add user: ' + JSON.stringify(err));
      return -1;
    }
  }
  
  /**
   * 验证用户名和密码是否匹配。
   * @param username 用户名
   * @param password 密码
   * @returns Promise<boolean> true表示验证成功，false表示失败
   */
  public async checkUser(username: string, password: string): Promise<boolean> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot check user');
      return false;
    }
    
    try {
      // 查询条件：用户名和密码都匹配
      const predicates = new relationalStore.RdbPredicates(this.TABLE_NAME);
      predicates.equalTo('username', username);
      predicates.equalTo('password', password);
      
      const resultSet = await this.rdbStore.query(predicates);
      const count = resultSet.rowCount;
      
      // 关闭结果集
      resultSet.close();
      
      const isValid = count > 0;
      console.info(TAG + 'User check result: ' + isValid);
      return isValid;
    } catch (err) {
      console.error(TAG + 'Failed to check user: ' + JSON.stringify(err));
      return false;
    }
  }
  
  /**
   * 检查用户名是否已存在。
   * @param username 用户名
   * @returns Promise<boolean> true表示已存在，false表示不存在
   */
  public async isUserExists(username: string): Promise<boolean> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot check user exists');
      return false;
    }
    
    try {
      // 查询条件：用户名匹配
      const predicates = new relationalStore.RdbPredicates(this.TABLE_NAME);
      predicates.equalTo('username', username);
      
      const resultSet = await this.rdbStore.query(predicates);
      const count = resultSet.rowCount;
      
      // 关闭结果集
      resultSet.close();
      
      const exists = count > 0;
      console.info(TAG + 'User exists check: ' + exists);
      return exists;
    } catch (err) {
      console.error(TAG + 'Failed to check user exists: ' + JSON.stringify(err));
      return false;
    }
  }
  
  /**
   * 获取所有用户数量（用于调试）。
   * @returns Promise<number> 用户数量
   */
  public async getUserCount(): Promise<number> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot get user count');
      return 0;
    }
    
    try {
      const predicates = new relationalStore.RdbPredicates(this.TABLE_NAME);
      const resultSet = await this.rdbStore.query(predicates);
      const count = resultSet.rowCount;
      resultSet.close();
      return count;
    } catch (err) {
      console.error(TAG + 'Failed to get user count: ' + JSON.stringify(err));
      return 0;
    }
  }
  
  /**
   * 更新用户密码。
   * @param username 用户名
   * @param newPassword 新密码
   * @returns Promise<boolean> true表示更新成功，false表示失败
   */
  public async updatePassword(username: string, newPassword: string): Promise<boolean> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot update password');
      return false;
    }
    
    try {
      // 先检查用户是否存在
      const exists = await this.isUserExists(username);
      if (!exists) {
        console.info(TAG + 'User does not exist: ' + username);
        return false;
      }
      
      // 更新密码
      const valueBucket: relationalStore.ValuesBucket = {
        'password': newPassword
      };
      
      const predicates = new relationalStore.RdbPredicates(this.TABLE_NAME);
      predicates.equalTo('username', username);
      
      const rowCount = await this.rdbStore.update(valueBucket, predicates);
      const success = rowCount > 0;
      console.info(TAG + 'Password update result: ' + success + ', rows affected: ' + rowCount);
      return success;
    } catch (err) {
      console.error(TAG + 'Failed to update password: ' + JSON.stringify(err));
      return false;
    }
  }
  
  /**
   * 获取用户密码（用于验证旧密码）。
   * @param username 用户名
   * @returns Promise<string | null> 返回密码，null表示用户不存在
   */
  public async getUserPassword(username: string): Promise<string | null> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot get user password');
      return null;
    }
    
    try {
      const predicates = new relationalStore.RdbPredicates(this.TABLE_NAME);
      predicates.equalTo('username', username);
      
      const resultSet = await this.rdbStore.query(predicates, ['password']);
      
      if (resultSet.rowCount > 0 && resultSet.goToFirstRow()) {
        const password = resultSet.getString(resultSet.getColumnIndex('password'));
        resultSet.close();
        return password;
      }
      
      resultSet.close();
      return null;
    } catch (err) {
      console.error(TAG + 'Failed to get user password: ' + JSON.stringify(err));
      return null;
    }
  }
  
  /**
   * 更新用户头像ID。
   * @param username 用户名
   * @param avatarId 头像ID（1-11）
   * @returns Promise<boolean> true表示更新成功，false表示失败
   */
  public async updateUserAvatarId(username: string, avatarId: number): Promise<boolean> {
    console.info(TAG + '=== updateUserAvatarId 开始 ===');
    console.info(TAG + '参数：username=' + username + ', avatarId=' + avatarId);
    
    // 验证avatarId范围
    if (avatarId < 1 || avatarId > 11) {
      console.error(TAG + '❌ avatarId超出范围(1-11): ' + avatarId);
      return false;
    }
    
    if (this.rdbStore === null) {
      console.error(TAG + '❌ RdbStore is null, cannot update avatar');
      return false;
    }
    
    try {
      // 先检查用户是否存在
      console.info(TAG + '检查用户是否存在...');
      const exists = await this.isUserExists(username);
      console.info(TAG + '用户存在检查结果：' + exists);
      
      if (!exists) {
        console.error(TAG + '❌ User does not exist: ' + username);
        return false;
      }
      
      // 更新头像ID
      console.info(TAG + '准备执行数据库更新...');
      const valueBucket: relationalStore.ValuesBucket = {
        'avatar_id': avatarId
      };
      
      const predicates = new relationalStore.RdbPredicates(this.TABLE_NAME);
      predicates.equalTo('username', username);
      
      console.info(TAG + '执行 SQL: UPDATE ' + this.TABLE_NAME + ' SET avatar_id=? WHERE username=?');
      const rowCount = await this.rdbStore.update(valueBucket, predicates);
      const success = rowCount > 0;
      
      console.info(TAG + '数据库更新执行完成');
      console.info(TAG + '影响行数：' + rowCount);
      console.info(TAG + '更新结果：' + (success ? '✅ 成功' : '❌ 失败'));
      
      // 更新成功后，清除该用户的头像缓存
      if (success) {
        console.info(TAG + '清除头像缓存：' + username);
        this.clearAvatarIdCache(username);
        console.info(TAG + '✅ 头像缓存已清除');
      }
      
      console.info(TAG + '=== updateUserAvatarId 完成 ===');
      return success;
    } catch (err) {
      console.error(TAG + '❌ Failed to update avatar: ' + JSON.stringify(err));
      if (err instanceof Error) {
        console.error(TAG + '错误堆栈: ' + err.stack);
      }
      return false;
    }
  }
  
  /**
   * 获取用户头像ID。
   * @param username 用户名
   * @returns Promise<number> 返回头像ID（1-11），若无记录则返回1
   */
  public async getUserAvatarId(username: string): Promise<number> {
    // 先检查缓存
    if (this.avatarIdCache.has(username)) {
      return this.avatarIdCache.get(username) ?? 1;
    }
    
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot get user avatar');
      return 1;
    }
    
    try {
      const predicates = new relationalStore.RdbPredicates(this.TABLE_NAME);
      predicates.equalTo('username', username);
      
      const resultSet = await this.rdbStore.query(predicates, ['avatar_id']);
      
      if (resultSet.rowCount > 0 && resultSet.goToFirstRow()) {
        const avatarId = resultSet.getLong(resultSet.getColumnIndex('avatar_id'));
        resultSet.close();
        // 确保avatarId在有效范围内
        const result = (avatarId >= 1 && avatarId <= 11) ? avatarId : 1;
        // 存入缓存
        this.avatarIdCache.set(username, result);
        return result;
      }
      
      resultSet.close();
      // 用户不存在，缓存默认值1
      this.avatarIdCache.set(username, 1);
      return 1;
    } catch (err) {
      console.error(TAG + 'Failed to get user avatar: ' + JSON.stringify(err));
      return 1;
    }
  }
  
  /**
   * 清除头像ID缓存。
   * @param username 用户名，如果不传则清除所有缓存
   */
  public clearAvatarIdCache(username?: string): void {
    if (username) {
      this.avatarIdCache.delete(username);
    } else {
      this.avatarIdCache.clear();
    }
  }
  
  // ==================== 旧方法（保留但不再使用） ====================
  
  /**
   * @deprecated 已废弃，请使用 updateUserAvatarId
   * 更新用户头像路径。
   */
  public async updateUserAvatar(username: string, avatarPath: string): Promise<boolean> {
    console.warn(TAG + '⚠️ updateUserAvatar 已废弃，请使用 updateUserAvatarId');
    return false;
  }
  
  /**
   * @deprecated 已废弃，请使用 getUserAvatarId
   * 获取用户头像路径。
   */
  public async getUserAvatar(username: string): Promise<string | null> {
    console.warn(TAG + '⚠️ getUserAvatar 已废弃，请使用 getUserAvatarId');
    return null;
  }
  
  /**
   * @deprecated 已废弃，请使用 clearAvatarIdCache
   * 清除头像缓存。
   */
  public clearAvatarCache(username?: string): void {
    console.warn(TAG + '⚠️ clearAvatarCache 已废弃，请使用 clearAvatarIdCache');
  }
  
  // ==================== 聊天消息相关方法 ====================
  
  /**
   * 插入一条消息到数据库。
   * @param message 消息对象
   * @param currentUser 当前登录用户UID
   * @returns Promise<number> 返回插入的行ID，-1表示失败
   */
  public async insertMessage(message: Message, currentUser: string): Promise<number> {
    console.info('[insertMessage] 开始执行');
    console.info('[insertMessage] currentUser=' + currentUser);
    console.info('[insertMessage] friend_uid=' + (message.isOutgoing() ? message.to : message.senderId));
    console.info('[insertMessage] content=' + message.content);
    console.info('[insertMessage] timestamp=' + message.date);
    
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot insert message');
      return -1;
    }
    
    try {
      // 检查消息是否已存在（通过fingerPrint去重）
      if (message.fingerPrintOfProtocal && message.fingerPrintOfProtocal.length > 0) {
        const exists = await this.messageExists(message.fingerPrintOfProtocal, currentUser);
        if (exists) {
          console.info(TAG + 'Message already exists, skip insert: ' + message.fingerPrintOfProtocal);
          return -1;
        }
      }
      
      // 确定好友UID
      const friendUid = message.isOutgoing() ? 
        this.getFriendUidFromMessage(message, currentUser) : message.senderId;
      
      // === 关键修复：验证friendUid的有效性 ===
      if (!UserDatabaseHelper.isValidFriendUid(friendUid)) {
        console.error(TAG + '❌ 无效的friendUid，拒绝插入数据库: "' + friendUid + '"');
        console.error(TAG + '消息详情: senderId=' + message.senderId + ', isOutgoing=' + message.isOutgoing());
        console.error(TAG + '当前用户: ' + currentUser);
        return -1;
      }
      
      console.info(TAG + '✅ friendUid验证通过: ' + friendUid);
      
      const valueBucket: relationalStore.ValuesBucket = {
        'uid': currentUser,
        'friend_uid': friendUid,
        'is_outgoing': message.isOutgoing() ? 1 : 0,
        'msg_type': message.msgType,
        'content': message.content,
        'timestamp': message.date,
        'send_status': message.sendStatus ?? MsgSendStatus.sending,
        'finger_print': message.fingerPrintOfProtocal ?? '',
        'sender_id': message.senderId,
        'sender_name': message.senderDisplayName ?? '',
        'avatar_id': message.avatarId ?? 1
      };
      
      console.info('[insertMessage] 准备执行 SQL 插入...');
      const rowId = await this.rdbStore.insert(this.TABLE_MESSAGES, valueBucket);
      console.info('[insertMessage] SQL 执行完成，rowId=' + rowId);
      if (rowId === -1) {
        console.error('[insertMessage] 插入失败，可能参数有误');
      }
      console.info(TAG + 'Message inserted, rowId: ' + rowId);
      return rowId;
    } catch (err) {
      console.error(TAG + 'Failed to insert message: ' + JSON.stringify(err));
      return -1;
    }
  }
  
  /**
   * 验证friendUid是否有效。
   * @param friendUid 好友UID
   * @returns true表示有效，false表示无效
   */
  public static isValidFriendUid(friendUid: string | null | undefined): boolean {
    if (!friendUid || typeof friendUid !== 'string') {
      return false;
    }
    // 过滤空字符串、单个字符（如'0'、'U'等异常值）、长度小于2的值
    if (friendUid.length < 2) {
      return false;
    }
    // 过滤纯数字0或特殊字符
    if (friendUid === '0' || friendUid === 'U') {
      return false;
    }
    return true;
  }

  /**
   * 清理数据库中的无效消息记录。
   * 删除friend_uid为异常值（空字符串、'0'、'U'、长度<2等）的消息。
   * @param currentUser 当前用户UID
   * @returns Promise<number> 返回删除的记录数
   */
  public async cleanInvalidMessages(currentUser: string): Promise<number> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot clean invalid messages');
      return 0;
    }

    try {
      console.info(TAG + '=== 开始清理无效消息记录 ===');
      console.info(TAG + '当前用户: ' + currentUser);
      
      // 查询无效消息数量
      const countSql = `
        SELECT COUNT(*) as count
        FROM ${this.TABLE_MESSAGES}
        WHERE uid = ? AND (
          friend_uid IS NULL 
          OR friend_uid = '' 
          OR friend_uid = '0' 
          OR friend_uid = 'U'
          OR length(friend_uid) < 2
        )
      `;
      
      const countResultSet = await this.rdbStore.querySql(countSql, [currentUser]);
      let invalidCount = 0;
      if (countResultSet.goToFirstRow()) {
        invalidCount = countResultSet.getLong(countResultSet.getColumnIndex('count'));
      }
      countResultSet.close();
      
      console.info(TAG + '发现无效消息记录数: ' + invalidCount);
      
      if (invalidCount === 0) {
        console.info(TAG + '无需清理，数据库中没有无效消息记录');
        return 0;
      }
      
      // 删除无效消息
      const deleteSql = `
        DELETE FROM ${this.TABLE_MESSAGES}
        WHERE uid = ? AND (
          friend_uid IS NULL 
          OR friend_uid = '' 
          OR friend_uid = '0' 
          OR friend_uid = 'U'
          OR length(friend_uid) < 2
        )
      `;
      
      await this.rdbStore.executeSql(deleteSql, [currentUser]);
      
      console.info(TAG + '✅ 已清理 ' + invalidCount + ' 条无效消息记录');
      console.info(TAG + '=== 清理完成 ===');
      
      return invalidCount;
    } catch (err) {
      console.error(TAG + '❌ 清理无效消息失败: ' + JSON.stringify(err));
      return 0;
    }
  }

  /**
   * 从消息对象推断好友UID（用于发出的消息）。
   */
  private getFriendUidFromMessage(message: Message, currentUser: string): string {
    // 优先使用message.to字段（推荐方式）
    if (message.to && message.to.length > 0) {
      return message.to;
    }
    
    // 如果senderId不是当前用户，则senderId就是好友
    if (message.senderId !== currentUser) {
      return message.senderId;
    }
    
    // 否则无法确定，返回空字符串（需要调用方保证传入正确的friendUid）
    // 注意：返回空字符串会导致插入无效数据，调用方必须验证
    console.warn(TAG + '⚠️ 无法从消息对象推断好友UID，返回空字符串');
    console.warn(TAG + '消息详情: senderId=' + message.senderId + ', to=' + (message.to || 'undefined'));
    return '';
  }
  
  /**
   * 检查消息是否已存在（通过fingerPrint）。
   * @param fingerPrint 消息指纹码
   * @param currentUser 当前用户UID
   * @returns Promise<boolean> true表示已存在
   */
  public async messageExists(fingerPrint: string, currentUser: string): Promise<boolean> {
    if (this.rdbStore === null) {
      return false;
    }
    
    try {
      const predicates = new relationalStore.RdbPredicates(this.TABLE_MESSAGES);
      predicates.equalTo('uid', currentUser);
      predicates.equalTo('finger_print', fingerPrint);
      
      const resultSet = await this.rdbStore.query(predicates);
      const count = resultSet.rowCount;
      resultSet.close();
      
      return count > 0;
    } catch (err) {
      console.error(TAG + 'Failed to check message exists: ' + JSON.stringify(err));
      return false;
    }
  }
  
  /**
   * 分页查询与某好友的聊天记录。
   * @param friendUid 好友UID
   * @param currentUser 当前用户UID
   * @param limit 查询数量限制
   * @param offset 偏移量（用于分页）
   * @returns Promise<Message[]> 消息数组（按时间升序排列）
   */
  public async queryMessages(
    friendUid: string, 
    currentUser: string, 
    limit: number = 50, 
    offset: number = 0
  ): Promise<Message[]> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot query messages');
      return [];
    }
    
    try {
      const predicates = new relationalStore.RdbPredicates(this.TABLE_MESSAGES);
      predicates.equalTo('uid', currentUser);
      predicates.equalTo('friend_uid', friendUid);
      predicates.orderByDesc('timestamp'); // 按时间降序（最新的在前）
      predicates.limitAs(limit);
      predicates.offsetAs(offset);
      
      const resultSet = await this.rdbStore.query(predicates);
      const messages: Message[] = [];
      
      // 从后往前遍历，因为结果是降序的，但我们需要升序返回
      const rowCount = resultSet.rowCount;
      for (let i = rowCount - 1; i >= 0; i--) {
        resultSet.goToRow(i);
        const message = this.parseMessageFromResultSet(resultSet);
        if (message) {
          messages.push(message);
        }
      }
      
      resultSet.close();
      console.info(TAG + 'Messages queried: ' + messages.length + ' for friend: ' + friendUid);
      return messages;
    } catch (err) {
      console.error(TAG + 'Failed to query messages: ' + JSON.stringify(err));
      return [];
    }
  }
  
  /**
   * 查询更早的消息（用于分页加载）。
   * @param friendUid 好友UID
   * @param currentUser 当前用户UID
   * @param beforeTimestamp 查询此时间戳之前的消息
   * @param limit 查询数量限制
   * @returns Promise<Message[]> 消息数组（按时间升序排列）
   */
  public async queryMessagesBefore(
    friendUid: string,
    currentUser: string,
    beforeTimestamp: number,
    limit: number = 20
  ): Promise<Message[]> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot query messages');
      return [];
    }
    
    try {
      const predicates = new relationalStore.RdbPredicates(this.TABLE_MESSAGES);
      predicates.equalTo('uid', currentUser);
      predicates.equalTo('friend_uid', friendUid);
      predicates.lessThan('timestamp', beforeTimestamp);
      predicates.orderByDesc('timestamp');
      predicates.limitAs(limit);
      
      const resultSet = await this.rdbStore.query(predicates);
      const messages: Message[] = [];
      
      // 从后往前遍历，转为升序
      const rowCount = resultSet.rowCount;
      for (let i = rowCount - 1; i >= 0; i--) {
        resultSet.goToRow(i);
        const message = this.parseMessageFromResultSet(resultSet);
        if (message) {
          messages.push(message);
        }
      }
      
      resultSet.close();
      console.info(TAG + 'Older messages queried: ' + messages.length);
      return messages;
    } catch (err) {
      console.error(TAG + 'Failed to query older messages: ' + JSON.stringify(err));
      return [];
    }
  }
  
  /**
   * 从ResultSet解析Message对象。
   */
  private parseMessageFromResultSet(resultSet: relationalStore.ResultSet): Message | null {
    try {
      const senderId = resultSet.getString(resultSet.getColumnIndex('sender_id'));
      const senderName = resultSet.getString(resultSet.getColumnIndex('sender_name'));
      const timestamp = resultSet.getLong(resultSet.getColumnIndex('timestamp'));
      const content = resultSet.getString(resultSet.getColumnIndex('content'));
      const msgType = resultSet.getLong(resultSet.getColumnIndex('msg_type'));
      const avatarId = resultSet.getLong(resultSet.getColumnIndex('avatar_id'));
      const fingerPrint = resultSet.getString(resultSet.getColumnIndex('finger_print'));
      const sendStatus = resultSet.getLong(resultSet.getColumnIndex('send_status'));
      
      const message = new Message(senderId, senderName, timestamp, content, msgType, avatarId);
      message.fingerPrintOfProtocal = fingerPrint;
      message.sendStatus = sendStatus;
      
      return message;
    } catch (err) {
      console.error(TAG + 'Failed to parse message: ' + JSON.stringify(err));
      return null;
    }
  }
  
  /**
   * 删除与某好友的所有消息。
   * @param friendUid 好友UID
   * @param currentUser 当前用户UID
   * @returns Promise<boolean> true表示删除成功
   */
  public async deleteMessagesByFriend(friendUid: string, currentUser: string): Promise<boolean> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot delete messages');
      return false;
    }
    
    try {
      const predicates = new relationalStore.RdbPredicates(this.TABLE_MESSAGES);
      predicates.equalTo('uid', currentUser);
      predicates.equalTo('friend_uid', friendUid);
      
      const rowCount = await this.rdbStore.delete(predicates);
      console.info(TAG + 'Messages deleted: ' + rowCount + ' for friend: ' + friendUid);
      return true;
    } catch (err) {
      console.error(TAG + 'Failed to delete messages: ' + JSON.stringify(err));
      return false;
    }
  }
  
  /**
   * 清空当前用户的所有消息。
   * @param currentUser 当前用户UID
   * @returns Promise<boolean> true表示删除成功
   */
  public async deleteAllMessages(currentUser: string): Promise<boolean> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot delete all messages');
      return false;
    }
    
    try {
      const predicates = new relationalStore.RdbPredicates(this.TABLE_MESSAGES);
      predicates.equalTo('uid', currentUser);
      
      const rowCount = await this.rdbStore.delete(predicates);
      console.info(TAG + 'All messages deleted: ' + rowCount + ' for user: ' + currentUser);
      return true;
    } catch (err) {
      console.error(TAG + 'Failed to delete all messages: ' + JSON.stringify(err));
      return false;
    }
  }
  
  /**
   * 更新消息发送状态。
   * @param fingerPrint 消息指纹码
   * @param sendStatus 发送状态
   * @param currentUser 当前用户UID
   * @returns Promise<boolean> true表示更新成功
   */
  public async updateMessageStatus(
    fingerPrint: string, 
    sendStatus: number,
    currentUser: string
  ): Promise<boolean> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot update message status');
      return false;
    }
    
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'send_status': sendStatus
      };
      
      const predicates = new relationalStore.RdbPredicates(this.TABLE_MESSAGES);
      predicates.equalTo('uid', currentUser);
      predicates.equalTo('finger_print', fingerPrint);
      
      const rowCount = await this.rdbStore.update(valueBucket, predicates);
      const success = rowCount > 0;
      console.info(TAG + 'Message status updated: ' + success + ', rows: ' + rowCount);
      return success;
    } catch (err) {
      console.error(TAG + 'Failed to update message status: ' + JSON.stringify(err));
      return false;
    }
  }
  
  /**
   * 获取会话列表摘要（从消息表聚合查询）。
   * 返回每个会话的最新一条消息信息。
   * @param currentUser 当前用户UID
   * @returns Promise<ConversationSummaryFromDB[]> 会话摘要数组
   */
  /**
   * 从消息记录中获取会话列表摘要。
   * 使用 INNER JOIN 子查询确保获取每个会话的真正最新消息（基于 MAX(timestamp)）。
   * 
   * @param currentUser 当前用户UID
   * @returns Promise<ConversationSummaryFromDB[]> 会话摘要数组
   */
  public async getConversationListFromMessages(currentUser: string): Promise<ConversationSummaryFromDB[]> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot get conversation list');
      return [];
    }
    
    try {
      console.info(TAG + '=== 开始查询会话列表摘要 ===');
      console.info(TAG + '当前用户: ' + currentUser);
      
      // === 关键修复：头像显示逻辑 ===
      // 1. 获取所有有消息的会话的最新消息（无论谁发送）
      // 2. 对于每个会话，使用子查询获取对方最新消息的 avatar_id
      // 3. 如果没有对方消息，则使用 COALESCE 返回默认值 1
      // 
      // 这样确保：
      // - 所有有消息的会话都能显示（即使只有自己发的消息）
      // - 头像只使用对方发送的最新消息的 avatar_id
      // - 如果对方从未发过消息，则显示默认头像（avatar_id = 1）
      
      const querySql = `
        SELECT 
          m1.friend_uid,
          m1.content as last_msg_content,
          m1.timestamp as last_msg_time,
          m1.msg_type,
          m1.send_status,
          COALESCE(
            (SELECT m2.avatar_id 
             FROM ${this.TABLE_MESSAGES} m2 
             WHERE m2.uid = ? 
               AND m2.friend_uid = m1.friend_uid 
               AND m2.is_outgoing = 0 
             ORDER BY m2.timestamp DESC 
             LIMIT 1
            ), 
            1
          ) as last_avatar_id
        FROM ${this.TABLE_MESSAGES} m1
        INNER JOIN (
          SELECT friend_uid, MAX(timestamp) as max_time
          FROM ${this.TABLE_MESSAGES}
          WHERE uid = ? 
            AND friend_uid IS NOT NULL 
            AND friend_uid != '' 
            AND friend_uid != '0' 
            AND friend_uid != 'U'
            AND length(friend_uid) >= 2
          GROUP BY friend_uid
        ) m2 ON m1.friend_uid = m2.friend_uid AND m1.timestamp = m2.max_time
        WHERE m1.uid = ?
        ORDER BY m1.timestamp DESC
      `;
      
      const resultSet = await this.rdbStore.querySql(querySql, [currentUser, currentUser, currentUser]);
      const summaries: ConversationSummaryFromDB[] = [];
      
      while (resultSet.goToNextRow()) {
        const friendUid = resultSet.getString(resultSet.getColumnIndex('friend_uid'));
        const content = resultSet.getString(resultSet.getColumnIndex('last_msg_content'));
        const timestamp = resultSet.getLong(resultSet.getColumnIndex('last_msg_time'));
        const msgType = resultSet.getLong(resultSet.getColumnIndex('msg_type'));
        const avatarId = resultSet.getLong(resultSet.getColumnIndex('last_avatar_id'));
        
        // 二次验证（虽然SQL已过滤，但这里再检查一次确保安全）
        if (!UserDatabaseHelper.isValidFriendUid(friendUid)) {
          console.warn(TAG + '⚠️ 跳过无效的friendUid: ' + friendUid);
          continue;
        }
        
        summaries.push({
          friendUid: friendUid,
          lastMessage: content,
          lastMessageTime: timestamp,
          lastMessageType: msgType,
          unreadCount: 0, // 未读数暂不实现
          lastAvatarId: (avatarId >= 1 && avatarId <= 11) ? avatarId : 1 // 确保头像ID在有效范围内
        });
        
        console.info(TAG + '✅ 会话摘要: friendUid=' + friendUid + 
          ', time=' + timestamp + 
          ', avatarId=' + avatarId +
          ', content=' + (content.length > 20 ? content.substring(0, 20) + '...' : content));
      }
      
      resultSet.close();
      console.info(TAG + '=== 会话列表摘要查询完成，共 ' + summaries.length + ' 条 ===');
      return summaries;
    } catch (err) {
      console.error(TAG + 'Failed to get conversation list: ' + JSON.stringify(err));
      return [];
    }
  }
  
  /**
   * 获取与某好友的消息总数。
   * @param friendUid 好友UID
   * @param currentUser 当前用户UID
   * @returns Promise<number> 消息总数
   */
  public async getMessageCount(friendUid: string, currentUser: string): Promise<number> {
    if (this.rdbStore === null) {
      return 0;
    }
    
    try {
      const predicates = new relationalStore.RdbPredicates(this.TABLE_MESSAGES);
      predicates.equalTo('uid', currentUser);
      predicates.equalTo('friend_uid', friendUid);
      
      const resultSet = await this.rdbStore.query(predicates);
      const count = resultSet.rowCount;
      resultSet.close();
      
      return count;
    } catch (err) {
      console.error(TAG + 'Failed to get message count: ' + JSON.stringify(err));
      return 0;
    }
  }
}
