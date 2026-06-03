/*
 * Copyright (C) 2024  即时通讯网(52im.net) & Jack Jiang.
 * The MobileIMSDK-鸿蒙Next客户端 Project. All rights reserved.
 *
 * 联系邮件：jack.jiang@52im.net
 * 联系微信：hellojackjiang
 * 联系QQ： 413980957
 * 技术社区：http://www.52im.net
 */

import { ChatComponent } from './ChatComponent';
import { MineComponent } from './MineComponent';
import ToolKits from './utils/ToolKits';
import FontScaleManager from './utils/FontScaleManager';
import { common } from '@kit.AbilityKit';

const TAG: string = '[MainPage] ';

/**
 * 主页面（底部Tab容器）。
 * 包含"聊天"和"我的"两个Tab。
 *
 * @author Jack Jiang
 */
@Entry
@Component
struct MainPage {
  /** 当前选中的Tab索引 */
  @State currentIndex: number = 0;
  
  /** Tab标签列表 */
  private tabLabels: string[] = ['聊天', '我的'];
  
  /** 字体缩放管理器 */
  private fontScaleManager: FontScaleManager | null = null;
  /** 上下文 */
  private context: common.UIAbilityContext | null = null;

  /**
   * 组件即将出现时调用。
   * 在此处读取并应用用户的字体缩放设置。
   */
  async aboutToAppear(): Promise<void> {
    // 初始化上下文
    this.context = getContext(this) as common.UIAbilityContext;
    
    // 初始化头像刷新触发器
    AppStorage.setOrCreate<number>('avatarRefreshTrigger', 0);
    
    // 初始化字体缩放管理器并应用用户设置
    if (this.context) {
      this.fontScaleManager = FontScaleManager.getInstance(this.context);
      
      // 获取当前登录用户名
      const currentUsername = AppStorage.get<string>('currentUsername');
      if (currentUsername && this.fontScaleManager) {
        try {
          // 读取用户保存的字体缩放设置
          const fontScale = await this.fontScaleManager.getFontScale(currentUsername);
          
          // 应用字体缩放
          this.fontScaleManager.applyFontScale(fontScale);
          
          console.info(TAG + `Font scale applied for user ${currentUsername}: ${fontScale}`);
        } catch (err) {
          console.error(TAG + 'Failed to apply font scale: ' + JSON.stringify(err));
        }
      }
    }
  }

  /**
   * 界面显示时被调用。
   */
  onPageShow(): void {
    // 设置全面屏状态栏颜色
    ToolKits.setStatusBarColor(getContext(this), ToolKits.chat_page_title_color, ToolKits.chat_page_title_background_color);
  }

  build() {
    Tabs({ barPosition: BarPosition.End }) {
      // 聊天Tab
      TabContent() {
        ChatComponent()
      }
      .tabBar(this.TabBuilder(0))

      // 我的Tab
      TabContent() {
        MineComponent()
      }
      .tabBar(this.TabBuilder(1))
    }
    .barHeight(56)
    .barBackgroundColor(Color.White)
    .onChange((index: number) => {
      this.currentIndex = index;
      
      // 当切换到聊天Tab时，通知刷新头像
      if (index === 0) {
        // 通过AppStorage发送头像刷新事件
        AppStorage.set<number>('avatarRefreshTrigger', Date.now());
      }
    })
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    // 适配流海屏（顶部状态栏透明并穿过，并透过底部上划操作区）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /**
   * Tab标签构建器。
   */
  @Builder
  TabBuilder(index: number) {
    Column() {
      // 图标
      if (index === 0) {
        // 聊天图标
        SymbolGlyph($r('sys.symbol.message'))
          .fontSize(24)
          .fontColor([this.currentIndex === index ? '#0A59F7' : '#999999'])
      } else {
        // 我的图标
        SymbolGlyph($r('sys.symbol.person'))
          .fontSize(24)
          .fontColor([this.currentIndex === index ? '#0A59F7' : '#999999'])
      }
      
      // 文字标签
      Text(this.tabLabels[index])
        .fontSize(12)
        .fontColor(this.currentIndex === index ? '#0A59F7' : '#999999')
        .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
