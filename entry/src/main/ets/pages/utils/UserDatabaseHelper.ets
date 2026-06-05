/*
 * Copyright (C) 2024  即时通讯网(52im.net) & Jack Jiang.
 * The MobileIMSDK-鸿蒙Next客户端 Project. All rights reserved.
 *
 * 联系邮件：jack.jiang@52im.net
 * 联系微信：hellojackjiang
 * 联系QQ： 413980957
 * 技术社区：http://www.52im.net
 */

import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const TAG: string = '[UserDatabaseHelper] ';

/**
 * 用户数据库管理类。
 * 使用关系型数据库（RDB）存储用户账号和密码信息。
 *
 * @author Jack Jiang
 */
export default class UserDatabaseHelper {
  // 数据库配置
  private readonly DB_NAME: string = 'User.db';
  private readonly DB_VERSION: number = 2; // 升级到版本2，支持头像路径
  private readonly TABLE_NAME: string = 'Users';
  
  // RDB存储实例
  private rdbStore: relationalStore.RdbStore | null = null;
  // 上下文
  private context: common.UIAbilityContext;
  // 单例实例
  private static instance: UserDatabaseHelper | null = null;
  
  // 头像缓存：username -> avatarPath
  private avatarCache: Map<string, string | null> = new Map();
  
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
      
      // 检查并升级数据库（添加avatar_path字段）
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
   * 表结构：id (主键自增), username (唯一), password, avatar_path
   */
  private async createUserTable(): Promise<void> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot create table');
      return;
    }
    
    // SQL建表语句（包含avatar_path字段）
    const createTableSql = `
      CREATE TABLE IF NOT EXISTS ${this.TABLE_NAME} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        avatar_path TEXT
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
   * 升级数据库。
   * 检查avatar_path字段是否存在，不存在则添加。
   */
  private async upgradeDatabase(): Promise<void> {
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot upgrade database');
      return;
    }
    
    try {
      // 查询表结构，检查avatar_path字段是否存在
      const tableInfoSql = `PRAGMA table_info(${this.TABLE_NAME})`;
      const resultSet = await this.rdbStore.querySql(tableInfoSql);
      
      let hasAvatarPath = false;
      while (resultSet.goToNextRow()) {
        const columnName = resultSet.getString(resultSet.getColumnIndex('name'));
        if (columnName === 'avatar_path') {
          hasAvatarPath = true;
          break;
        }
      }
      resultSet.close();
      
      // 如果avatar_path字段不存在，则添加
      if (!hasAvatarPath) {
        const alterTableSql = `ALTER TABLE ${this.TABLE_NAME} ADD COLUMN avatar_path TEXT`;
        await this.rdbStore.executeSql(alterTableSql);
        console.info(TAG + 'Database upgraded: avatar_path column added');
      } else {
        console.info(TAG + 'Database already has avatar_path column');
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
      
      // 插入新用户
      const valueBucket: relationalStore.ValuesBucket = {
        'username': username,
        'password': password
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
   * 更新用户头像路径。
   * @param username 用户名
   * @param avatarPath 头像图片的本地路径
   * @returns Promise<boolean> true表示更新成功，false表示失败
   */
  public async updateUserAvatar(username: string, avatarPath: string): Promise<boolean> {
    console.info(TAG + '=== updateUserAvatar 开始 ===');
    console.info(TAG + '参数：username=' + username + ', avatarPath=' + avatarPath);
    
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
        console.info(TAG + '提示：请确保用户已注册或登录');
        return false;
      }
      
      // 更新头像路径
      console.info(TAG + '准备执行数据库更新...');
      const valueBucket: relationalStore.ValuesBucket = {
        'avatar_path': avatarPath
      };
      
      const predicates = new relationalStore.RdbPredicates(this.TABLE_NAME);
      predicates.equalTo('username', username);
      
      console.info(TAG + '执行 SQL: UPDATE ' + this.TABLE_NAME + ' SET avatar_path=? WHERE username=?');
      const rowCount = await this.rdbStore.update(valueBucket, predicates);
      const success = rowCount > 0;
      
      console.info(TAG + '数据库更新执行完成');
      console.info(TAG + '影响行数：' + rowCount);
      console.info(TAG + '更新结果：' + (success ? '✅ 成功' : '❌ 失败'));
      
      // 更新成功后，清除该用户的头像缓存
      if (success) {
        console.info(TAG + '清除头像缓存：' + username);
        this.clearAvatarCache(username);
        console.info(TAG + '✅ 头像缓存已清除');
      }
      
      console.info(TAG + '=== updateUserAvatar 完成 ===');
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
   * 获取用户头像路径。
   * @param username 用户名
   * @returns Promise<string | null> 返回头像路径，null表示用户不存在或未设置头像
   */
  public async getUserAvatar(username: string): Promise<string | null> {
    // 先检查缓存
    if (this.avatarCache.has(username)) {
      return this.avatarCache.get(username) ?? null;
    }
    
    if (this.rdbStore === null) {
      console.error(TAG + 'RdbStore is null, cannot get user avatar');
      return null;
    }
    
    try {
      const predicates = new relationalStore.RdbPredicates(this.TABLE_NAME);
      predicates.equalTo('username', username);
      
      const resultSet = await this.rdbStore.query(predicates, ['avatar_path']);
      
      if (resultSet.rowCount > 0 && resultSet.goToFirstRow()) {
        const avatarPath = resultSet.getString(resultSet.getColumnIndex('avatar_path'));
        resultSet.close();
        // 如果头像路径为空字符串，返回null
        const result = avatarPath && avatarPath.length > 0 ? avatarPath : null;
        // 存入缓存
        this.avatarCache.set(username, result);
        return result;
      }
      
      resultSet.close();
      // 用户不存在，缓存null
      this.avatarCache.set(username, null);
      return null;
    } catch (err) {
      console.error(TAG + 'Failed to get user avatar: ' + JSON.stringify(err));
      return null;
    }
  }
  
  /**
   * 清除头像缓存。
   * @param username 用户名，如果不传则清除所有缓存
   */
  public clearAvatarCache(username?: string): void {
    if (username) {
      this.avatarCache.delete(username);
    } else {
      this.avatarCache.clear();
    }
  }
}
