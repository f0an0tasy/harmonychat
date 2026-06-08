import { ConversationListPage } from './ConversationListPage';
import { MineComponent } from './MineComponent';
import ToolKits from './utils/ToolKits';
import FontScaleManager from './utils/FontScaleManager';
import UserDatabaseHelper from './utils/UserDatabaseHelper';
import { common } from '@kit.AbilityKit';

const TAG: string = '[MainPage] ';

/**
 * 主页面（底部Tab容器）。
 * 包含"聊天"和"我的"两个Tab。
 *
 * @author wangyifan & qinweiming
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
  
  /** 会话列表刷新触发器（用于触发 ConversationListPage 刷新） */
  @State conversationRefreshTrigger: number = 0;

  /**
   * 组件即将出现时调用。
   * 在此处读取并应用用户的字体缩放设置。
   */
  async aboutToAppear(): Promise<void> {
    // 初始化上下文
    this.context = getContext(this) as common.UIAbilityContext;
    
    // 初始化头像刷新触发器
    AppStorage.set<number>('avatarRefreshTrigger', 0);
    
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
          
          // 加载用户的头像ID
          const userDbHelper = UserDatabaseHelper.getInstance(this.context);
          const savedAvatarId = await userDbHelper.getUserAvatarId(currentUsername);
          AppStorage.set<number>('currentUserAvatarId', savedAvatarId);
          console.info(TAG + `Avatar ID loaded for user ${currentUsername}: ${savedAvatarId}`);
        } catch (err) {
          console.error(TAG + 'Failed to apply font scale or load avatar: ' + JSON.stringify(err));
          // 设置默认头像ID
          AppStorage.set<number>('currentUserAvatarId', 1);
        }
      } else {
        // 如果没有当前用户名，设置默认头像ID
        AppStorage.set<number>('currentUserAvatarId', 1);
      }
    }
  }

  /**
   * 界面显示时被调用。
   * 从详情页返回时会触发此方法，强制刷新会话列表。
   */
  onPageShow(): void {
    // 设置全面屏状态栏颜色
    ToolKits.setStatusBarColor(getContext(this), ToolKits.chat_page_title_color, ToolKits.chat_page_title_background_color);
    
    // 从详情页返回时强制刷新会话列表
    // 通过更新触发器来通知 ConversationListPage 刷新
    this.conversationRefreshTrigger = Date.now();
    console.info(TAG + 'onPageShow triggered, refreshing conversation list, trigger=' + this.conversationRefreshTrigger);
  }

  build() {
    Tabs({ barPosition: BarPosition.End }) {
      // 聊天Tab（会话列表）
      TabContent() {
        ConversationListPage({ 
          refreshTrigger: $conversationRefreshTrigger 
        })
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
