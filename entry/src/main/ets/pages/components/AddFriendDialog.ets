/*
 * Copyright (C) 2024  即时通讯网(52im.net) & Jack Jiang.
 * The MobileIMSDK-鸿蒙Next客户端 Project. All rights reserved.
 *
 * 联系邮件：jack.jiang@52im.net
 * 联系微信：hellojackjiang
 * 联系QQ： 413980957
 * 技术社区：http://www.52im.net
 */

import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import ConversationManager from '../model/ConversationManager';
import UserDatabaseHelper from '../utils/UserDatabaseHelper';
import ToolKits from '../utils/ToolKits';
import { ClientCoreSDK } from 'mobileimsdk/Index';

const TAG: string = '[AddFriendDialog] ';

/**
 * 添加好友对话框控制器。
 * 用于控制对话框的打开和关闭。
 */
export class AddFriendDialogController {
  private dialogController?: CustomDialogController;

  /**
   * 设置对话框控制器。
   */
  setController(controller: CustomDialogController): void {
    this.dialogController = controller;
  }

  /**
   * 打开对话框。
   */
  open(): void {
    if (this.dialogController) {
      this.dialogController.open();
    }
  }

  /**
   * 关闭对话框。
   */
  close(): void {
    if (this.dialogController) {
      this.dialogController.close();
    }
  }
}

/**
 * 添加好友对话框组件。
 * 用于输入好友UID并添加到会话列表。
 *
 * @author Jack Jiang
 */
@CustomDialog
export struct AddFriendDialog {
  /** 对话框控制器 */
  controller: CustomDialogController;

  /** 输入的好友UID */
  @State inputUid: string = '';

  /** 是否正在处理 */
  @State isProcessing: boolean = false;

  /** 数据库助手 */
  private userDbHelper: UserDatabaseHelper | null = null;

  /** 上下文 */
  private context: common.UIAbilityContext | null = null;

  /** 添加成功回调 */
  onAddSuccess?: (friendUid: string) => void;

  /**
   * 组件即将出现时调用。
   */
  aboutToAppear(): void {
    try {
      this.context = getContext(this) as common.UIAbilityContext;
      this.userDbHelper = UserDatabaseHelper.getInstance(this.context);
    } catch (err) {
      console.error(TAG + 'Failed to get context: ' + JSON.stringify(err));
    }
  }

  /**
   * 验证并添加好友。
   */
  async doAddFriend(): Promise<void> {
    // 清理输入（去除首尾空格）
    const friendUid = this.inputUid.trim();

    // 验证输入
    if (!friendUid || friendUid.length === 0) {
      ToolKits.showToast('请输入好友UID');
      return;
    }

    // 不能添加自己
    const currentUid = ClientCoreSDK.getInstance().currentLoginInfo?.loginUserId;
    if (friendUid === currentUid) {
      ToolKits.showToast('不能添加自己为好友');
      return;
    }

    // 检查是否已存在
    const conversationManager = ConversationManager.getInstance(this.context!);
    if (conversationManager.hasConversation(friendUid)) {
      ToolKits.showToast('该好友已在会话列表中');
      return;
    }

    this.isProcessing = true;

    try {
      // 检查用户是否存在（本地数据库）
      if (this.userDbHelper) {
        const exists = await this.userDbHelper.isUserExists(friendUid);
        if (!exists) {
          // 用户不存在，给出提示但仍然允许添加（可能是服务端用户）
          ToolKits.showToast('本地用户不存在，但仍可添加');
        }
      }

      // 添加到会话列表
      const added = await conversationManager.addConversation(friendUid);
      if (added) {
        ToolKits.showToast('添加成功');
        this.controller.close();

        // 调用成功回调
        if (this.onAddSuccess) {
          this.onAddSuccess(friendUid);
        }
      } else {
        ToolKits.showToast('添加失败，好友已存在');
      }
    } catch (err) {
      console.error(TAG + 'Failed to add friend: ' + JSON.stringify(err));
      ToolKits.showToast('添加失败：' + JSON.stringify(err));
    } finally {
      this.isProcessing = false;
    }
  }

  build() {
    Column() {
      // 标题
      Text('添加好友')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ bottom: 20 })

      // 输入框
      TextInput({
        placeholder: '请输入好友UID',
        text: $$this.inputUid
      })
        .fontSize(16)
        .fontColor('#333333')
        .placeholderFont({ size: 16 })
        .placeholderColor('#999999')
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .height(48)
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 20 })

      // 按钮区
      Row() {
        // 取消按钮
        Button('取消')
          .fontSize(16)
          .fontColor('#666666')
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .height(44)
          .layoutWeight(1)
          .onClick(() => {
            this.controller.close();
          })

        Blank().width(16)

        // 确认按钮
        Button('添加')
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor(this.isProcessing ? '#CCCCCC' : '#0A59F7')
          .borderRadius(8)
          .height(44)
          .layoutWeight(1)
          .enabled(!this.isProcessing)
          .onClick(() => {
            this.doAddFriend();
          })
      }
      .width('100%')
    }
    .width('80%')
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius(16)
  }
}
