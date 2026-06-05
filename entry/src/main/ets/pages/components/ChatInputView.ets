/*
 * Copyright (C) 2024  即时通讯网(52im.net) & Jack Jiang.
 * The MobileIMSDK-鸿蒙Next客户端 Project. All rights reserved.
 *
 * 联系邮件：jack.jiang@52im.net
 * 联系微信：hellojackjiang
 * 联系QQ： 413980957
 * 技术社区：http://www.52im.net
 */

import { LocalDataSender, ClientCoreSDK, ErrorCode, Protocal } from "mobileimsdk/Index";
import IMClientManager from "../../IMClientManager";
import Message from "../model/Message";
import ToolKits from "../utils/ToolKits";
import UserDatabaseHelper from "../utils/UserDatabaseHelper";
import ConversationManager from "../model/ConversationManager";
import { common } from '@kit.AbilityKit';

const TAG: string = '[ChatInputView] ';

/**
 * 消息数据封装对象。
 * 用于将消息内容和头像Base64一起发送。
 */
interface MessageData {
  /** 消息内容 */
  content: string;
  /** 发送者头像Base64（可选，仅在需要时携带） */
  avatarBase64?: string;
}

/**
 * 聊天界面输入区组件。
 *
 * 【改造说明】
 * 原实现包含"对方ID"输入框，现已移除。
 * friendUid 通过组件参数传入，不再需要手动输入。
 *
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 */
@Component
export struct ChatInputView {
  /** 当前聊天对象的好友UID（从父组件传入） */
  @Prop friendUid: string = '';

  /** 消息输入内容 */
  @State messageInput: string = '';

  /** 数据库助手 */
  private userDbHelper: UserDatabaseHelper | null = null;

  /** 上下文 */
  private context: common.UIAbilityContext | null = null;

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
   * 发送消息。
   */
  async doSendMessage(): Promise<void> {
    // 验证输入
    if (this.messageInput.length === 0) {
      ToolKits.showToast('请输入消息内容');
      return;
    }

    if (!this.friendUid || this.friendUid.length === 0) {
      ToolKits.showToast('未指定聊天对象');
      return;
    }

    // 不能给自己发消息
    if (this.friendUid === ClientCoreSDK.getInstance().currentLoginInfo?.loginUserId) {
      ToolKits.showToast('不能给自己发送消息哦！');
      return;
    }

    // 生成消息指纹码
    let fingerPrint: string = Protocal.genFingerPrint();

    // === 头像携带逻辑 ===
    let avatarBase64: string = '';
    try {
      const currentUsername = ToolKits.getLocalUserUid();
      console.info(TAG + '=== 开始准备发送消息 ===');
      console.info(TAG + '当前用户: ' + currentUsername);
      console.info(TAG + '接收者: ' + this.friendUid);
      console.info(TAG + '消息内容: ' + this.messageInput);

      if (currentUsername && this.userDbHelper) {
        const avatarPath = await this.userDbHelper.getUserAvatar(currentUsername);
        console.info(TAG + '头像路径: ' + (avatarPath || '无'));

        if (avatarPath) {
          const fileExists = ToolKits.isFileExists(avatarPath);
          console.info(TAG + '头像文件是否存在: ' + fileExists);

          if (fileExists) {
            // 压缩头像并转换为 Base64
            console.info(TAG + '开始压缩头像文件...');
            const base64 = await ToolKits.compressImageToBase64(
              avatarPath,
              200,  // maxWidth
              200,  // maxHeight
              40,   // quality
              45000 // maxBase64Length
            );

            if (base64 && base64.length > 0) {
              avatarBase64 = base64;
              console.info(TAG + '✅ 头像压缩成功，Base64长度: ' + base64.length);
            } else {
              console.error(TAG + '❌ 头像压缩失败，Base64为空');
            }
          }
        }
      }
    } catch (err) {
      console.error(TAG + '❌ 获取头像失败: ' + JSON.stringify(err));
    }

    // === 构建消息内容 ===
    let messageContent: string;
    if (avatarBase64 && avatarBase64.length > 0) {
      const messageData: MessageData = {
        content: this.messageInput,
        avatarBase64: avatarBase64
      };
      messageContent = JSON.stringify(messageData);
      console.info(TAG + '✅ 消息已封装为JSON格式');
    } else {
      messageContent = this.messageInput;
      console.info(TAG + 'ℹ️ 消息为纯文本格式（无头像）');
    }

    // 发送消息
    console.info(TAG + '开始发送消息...');
    let code = LocalDataSender.getInstance().sendCommonDataPlain(
      messageContent,
      this.friendUid,
      true,
      fingerPrint
    );

    if (code === ErrorCode.COMMON_CODE_OK) {
      ClientCoreSDK.Log.info('✅ 数据已成功发出！');

      // 创建UI显示的消息对象
      let m: Message = Message.createChatMsgEntity_OUTGO_TEXT(this.messageInput, fingerPrint);

      // 将消息放入全局消息数据缓存
      IMClientManager.getInstance().getMessageProvider().putMessage(m);

      // 更新会话摘要
      const conversationManager = ConversationManager.getInstance(this.context!);
      conversationManager.updateConversationSummary(
        this.friendUid,
        this.messageInput,
        Date.now()
      );

      // 清空输入框
      this.messageInput = '';
      console.info(TAG + '=== 消息发送完成 ===');
    } else {
      console.error(TAG + '❌ 消息发送失败，错误码: ' + code);
      ToolKits.showToast('数据发送失败。错误码是：' + code + '！');
    }
  }

  build() {
    Row() {
      // 消息输入框
      TextInput({
        placeholder: '请输入聊天内容，按发送键提交',
        text: $$this.messageInput
      })
        .backgroundColor('#f5f7fa')
        .height(40)
        .fontSize(14)
        .layoutWeight(1)
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .placeholderFont({ size: 14 })
        .placeholderColor('#a1a7af')
        .margin({ right: 10 })

      // 发送按钮
      Button('发送', { type: ButtonType.Normal, stateEffect: true })
        .width(60)
        .height(40)
        .borderRadius(8)
        .padding(0)
        .fontSize(15)
        .backgroundColor('#00de7a')
        .fontWeight(500)
        .onClick(() => {
          this.doSendMessage();
        })
    }
    .height(56)
    .width('100%')
    .backgroundColor('#ffffff')
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
  }
}
