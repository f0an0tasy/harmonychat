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
import { common } from '@kit.AbilityKit';

const TAG: string = '[ChatInputView] '

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
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 */
@Component
export struct ChatInputView {
  // @Link message: string;

  @State messageInput: string = '';
  @State receiverInput: string = '';
  
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

  // 发送消息实现方法
  async doSendMessage(): Promise<void> {
    if(this.messageInput.length > 0 && this.receiverInput.length > 0) {
      if(this.receiverInput === ClientCoreSDK.getInstance().currentLoginInfo?.loginUserId) {
        ToolKits.showToast('不能给自已发送消息哦！');
        return;
      }

      // 先生成指纹码
      let fingerPring: string = Protocal.genFingerPrint();
      
      // === 头像携带逻辑 ===
      let avatarBase64: string = '';
      try {
        // 获取当前用户的头像路径
        const currentUsername = ToolKits.getLocalUserUid();
        console.info(TAG + '=== 开始准备发送消息 ===');
        console.info(TAG + '当前用户: ' + currentUsername);
        console.info(TAG + '接收者: ' + this.receiverInput);
        console.info(TAG + '消息内容: ' + this.messageInput);
        
        if (currentUsername && this.userDbHelper) {
          const avatarPath = await this.userDbHelper.getUserAvatar(currentUsername);
          console.info(TAG + '头像路径: ' + (avatarPath || '无'));
          
          if (avatarPath) {
            const fileExists = ToolKits.isFileExists(avatarPath);
            console.info(TAG + '头像文件是否存在: ' + fileExists);
            
            if (fileExists) {
              // 读取头像并转换为 Base64
              console.info(TAG + '开始读取头像文件...');
              const base64 = await ToolKits.readImageToBase64(avatarPath);
              
              if (base64) {
                // 每次发送消息都携带头像
                avatarBase64 = base64;
                console.info(TAG + '✅ 头像读取成功，Base64长度: ' + base64.length);
                console.info(TAG + 'Base64前100字符: ' + base64.substring(0, 100));
              } else {
                console.error(TAG + '❌ 头像读取失败，Base64为空');
              }
            } else {
              console.warn(TAG + '⚠️ 头像文件不存在: ' + avatarPath);
            }
          } else {
            console.info(TAG + 'ℹ️ 用户未设置头像');
          }
        } else {
          console.warn(TAG + '⚠️ 无法获取当前用户或数据库助手');
        }
      } catch (err) {
        console.error(TAG + '❌ 获取头像失败: ' + JSON.stringify(err));
      }
      
      // === 构建消息内容 ===
      let messageContent: string;
      if (avatarBase64 && avatarBase64.length > 0) {
        // 如果需要携带头像，使用 JSON 格式封装
        const messageData: MessageData = {
          content: this.messageInput,
          avatarBase64: avatarBase64
        };
        messageContent = JSON.stringify(messageData);
        console.info(TAG + '✅ 消息已封装为JSON格式');
        console.info(TAG + 'JSON总长度: ' + messageContent.length);
        console.info(TAG + 'JSON前200字符: ' + messageContent.substring(0, 200));
        console.info(TAG + '包含avatarBase64字段: ' + (messageContent.indexOf('"avatarBase64"') !== -1));
      } else {
        // 否则直接发送原始消息
        messageContent = this.messageInput;
        console.info(TAG + 'ℹ️ 消息为纯文本格式（无头像）');
      }
      
      // 发送消息
      console.info(TAG + '开始发送消息...');
      let code = LocalDataSender.getInstance().sendCommonDataPlain(messageContent, this.receiverInput, true, fingerPring);
      if(code === ErrorCode.COMMON_CODE_OK) {
        ClientCoreSDK.Log.info("✅ 数据已成功发出！");

        // 用于ui显示的消息对象（注意：UI显示使用原始消息内容，不包含头像数据）
        let m: Message = Message.createChatMsgEntity_OUTGO_TEXT(this.messageInput, fingerPring);
        // 将消息对象放入全局消息数据缓存中（以备聊天ui列表中显示之）
        IMClientManager.getInstance().getMessageProvider().putMessage(m);
        // 清空输入框
        this.messageInput = '';
        console.info(TAG + '=== 消息发送完成 ===');
      } else {
        console.error(TAG + '❌ 消息发送失败，错误码: ' + code);
        ToolKits.showToast("数据发送失败。错误码是："+code+"！");
      }
    } else {
      ToolKits.showToast('接收者id或发送内容为空，本次消息发送没有继续!');
      ClientCoreSDK.Log.error(TAG+ "msg.len="+this.messageInput.length+",receiverUid.len="+this.receiverInput.length)
    }
  }

  build() {

    Row() {
      TextInput({
        placeholder: "对方ID", text: $$this.receiverInput
      })
        .backgroundColor('#f5f7fa')
        .width(56)
        .height(34)
        // .onChange((msg: string) => {
        //   this.message = msg
        // })
        .fontSize(13)
        .borderRadius(8)
        .padding({ left: 6, right: 6 })
        .placeholderFont({ size: 14 })
        .placeholderColor('#a1a7af')

      TextInput({
        placeholder: "请输入聊天内容，按发送键提交", text: $$this.messageInput
      })
        .backgroundColor('#f5f7fa')
        .width(100)// .layoutWeight(8)
        .height(34)
        // .onChange((msg: string) => {
        //   this.message = msg
        // })
        .fontSize(13)
        .layoutWeight(1)
        .borderRadius(8)
        .margin({ left: 10, right: 10 })
        .padding({ left: 10, right: 10 })
        .placeholderFont({ size: 14 })
        .placeholderColor('#a1a7af')

      Button("提交", { type: ButtonType.Normal, stateEffect: true })
        .width(44)
        .height(34)
        .borderRadius(8)
        .padding(0)
        .fontSize(14)
        .backgroundColor('#00de7a')
        .fontWeight(500)// .margin(4)
        .onClick(() => {
          // let MsgIn: MsgInput = new MsgInput()
          // MsgIn.id = this.MsgArray.length.toString()
          // MsgIn.role = "user"
          // MsgIn.content = this.message
          // this.MsgArray.push(MsgIn)
          // this.httpData(this.MsgArray)

          // this.message = "";

          // ClientCoreSDK.Log.info('对方uid='+this.receiverInput+', 消息='+this.messageInput);

          // 发送消息
          this.doSendMessage();
        })
    }
    .height(54)
    .width('100%')
    .backgroundColor("#ffffff") //ffffff
    .padding({ left: 10, right: 10 })
    .alignItems(VerticalAlign.Center)

    // .shadow({
    //   radius: 30, // 模糊半径
    //   color: "#0d000000", // 阴影颜色
    //   offsetX: 0, // X轴偏移量
    //   offsetY: -5 // Y轴偏移量
    // })
  }
}