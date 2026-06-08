import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import ToolKits from './utils/ToolKits';
import UserDatabaseHelper from './utils/UserDatabaseHelper';
import IMClientManager from '../IMClientManager';
import PreferenceManager from './utils/PreferenceManager';
import FontScaleManager, { FONT_SCALE_OPTIONS, FontScaleOption } from './utils/FontScaleManager';
import { AvatarSendManager } from './utils/AvatarCacheManager';
import { ChatInputView } from './components/ChatInputView';

const TAG: string = '[MineComponent] ';

/**
 * 修改密码对话框控制器
 */
@CustomDialog
struct ChangePasswordDialog {
  controller: CustomDialogController;
  /** 数据库助手 */
  userDbHelper: UserDatabaseHelper | null = null;
  /** 修改成功回调 */
  onSuccess: () => void = () => {};
  
  /** 当前登录用户名（从 AppStorage 获取） */
  @StorageProp('currentUsername') username: string = '';
  /** 输入框内容 */
  @State currentPassword: string = '';
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  /** 错误提示 */
  @State errorMsg: string = '';
  /** 是否正在处理 */
  @State isProcessing: boolean = false;

  /**
   * 执行修改密码。
   */
  async doChangePassword(): Promise<void> {
    // 清空错误信息
    this.errorMsg = '';
    
    // 验证输入
    if (ToolKits.isEmpty(this.currentPassword, true)) {
      this.errorMsg = '请输入当前密码';
      return;
    }
    
    if (ToolKits.isEmpty(this.newPassword, true)) {
      this.errorMsg = '请输入新密码';
      return;
    }
    
    if (this.newPassword.length < 6) {
      this.errorMsg = '新密码长度不能少于6位';
      return;
    }
    
    if (this.newPassword !== this.confirmPassword) {
      this.errorMsg = '两次输入的新密码不一致';
      return;
    }
    
    if (this.currentPassword === this.newPassword) {
      this.errorMsg = '新密码不能与当前密码相同';
      return;
    }
    
    // 验证当前密码
    if (this.userDbHelper) {
      this.isProcessing = true;
      try {
        const isValid = await this.userDbHelper.checkUser(this.username, this.currentPassword);
        if (!isValid) {
          this.errorMsg = '当前密码错误';
          this.isProcessing = false;
          return;
        }
        
        // 更新密码
        const success = await this.userDbHelper.updatePassword(this.username, this.newPassword);
        this.isProcessing = false;
        
        if (success) {
          // 关闭对话框
          this.controller.close();
          // 调用成功回调
          this.onSuccess();
        } else {
          this.errorMsg = '密码修改失败，请重试';
        }
      } catch (err) {
        this.isProcessing = false;
        this.errorMsg = '操作失败：' + JSON.stringify(err);
        console.error(TAG + 'Change password error: ' + JSON.stringify(err));
      }
    }
  }

  build() {
    Column() {
      // 标题
      Text('修改密码')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 20 })

      // 当前密码输入框
      TextInput({ placeholder: '当前密码', text: this.currentPassword })
        .type(InputType.Password)
        .height(44)
        .width('100%')
        .backgroundColor('#f5f5f5')
        .borderRadius(8)
        .onChange((value: string) => {
          this.currentPassword = value;
        })
        .margin({ bottom: 12 })

      // 新密码输入框
      TextInput({ placeholder: '新密码（至少6位）', text: this.newPassword })
        .type(InputType.Password)
        .height(44)
        .width('100%')
        .backgroundColor('#f5f5f5')
        .borderRadius(8)
        .onChange((value: string) => {
          this.newPassword = value;
        })
        .margin({ bottom: 12 })

      // 确认新密码输入框
      TextInput({ placeholder: '确认新密码', text: this.confirmPassword })
        .type(InputType.Password)
        .height(44)
        .width('100%')
        .backgroundColor('#f5f5f5')
        .borderRadius(8)
        .onChange((value: string) => {
          this.confirmPassword = value;
        })
        .margin({ bottom: 12 })

      // 错误提示
      if (this.errorMsg) {
        Text(this.errorMsg)
          .fontSize(12)
          .fontColor('#ff0000')
          .width('100%')
          .margin({ bottom: 12 })
      }

      // 按钮区域
      Row() {
        // 取消按钮
        Button('取消')
          .width('45%')
          .height(40)
          .backgroundColor('#f5f5f5')
          .fontColor('#333333')
          .onClick(() => {
            this.controller.close();
          })

        Blank().width('10%')

        // 确认按钮
        Button(this.isProcessing ? '处理中...' : '确认')
          .width('45%')
          .height(40)
          .backgroundColor('#0A59F7')
          .fontColor(Color.White)
          .enabled(!this.isProcessing)
          .onClick(() => {
            this.doChangePassword();
          })
      }
      .width('100%')
    }
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }
}

/**
 * 字体大小调节对话框。
 */
@CustomDialog
struct FontScaleDialog {
  controller: CustomDialogController;
  /** 字体缩放管理器 */
  fontScaleManager: FontScaleManager | null = null;
  /** 初始选中的档位索引 */
  initialIndex: number = 1;
  /** 设置成功回调 */
  onSuccess: () => void = () => {};
  
  /** 当前登录用户名（从 AppStorage 获取） */
  @StorageProp('currentUsername') currentUsername: string = '';
  /** 当前选中的档位索引 */
  @State selectedIndex: number = 1;
  /** 是否正在处理 */
  @State isProcessing: boolean = false;

  /**
   * 组件即将出现时调用。
   */
  aboutToAppear(): void {
    // 使用传入的初始索引
    this.selectedIndex = this.initialIndex;
  }

  /**
   * 选择字体大小档位。
   */
  async onSelectScale(index: number): Promise<void> {
    if (this.isProcessing) {
      return;
    }
    
    this.selectedIndex = index;
    this.isProcessing = true;
    
    try {
      const scale = FONT_SCALE_OPTIONS[index].scale;
      
      // 保存设置
      if (this.fontScaleManager && this.currentUsername) {
        await this.fontScaleManager.saveFontScale(this.currentUsername, scale);
        
        // 应用字体缩放
        this.fontScaleManager.applyFontScale(scale);
        
        // 关闭对话框
        this.controller.close();
        
        // 调用成功回调
        this.onSuccess();
        
        // 显示提示
        ToolKits.showToast(`字体大小已调整为"${FONT_SCALE_OPTIONS[index].label}"`);
      }
    } catch (err) {
      console.error(TAG + 'Failed to set font scale: ' + JSON.stringify(err));
      ToolKits.showToast('设置失败，请重试');
    }
    
    this.isProcessing = false;
  }

  build() {
    Column() {
      // 标题
      Text('字体大小调节')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 16 })

      // 预览区域
      Column() {
        // 预览字母 A
        Text('A')
          .fontSize(48 * FONT_SCALE_OPTIONS[this.selectedIndex].scale)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
        
        // 当前档位描述
        Text(FONT_SCALE_OPTIONS[this.selectedIndex].description)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 8 })
      }
      .width('100%')
      .height(100)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#f5f5f5')
      .borderRadius(8)
      .margin({ bottom: 16 })

      // 档位选择列表
      Column({ space: 8 }) {
        ForEach(FONT_SCALE_OPTIONS, (option: FontScaleOption, index: number) => {
          Row() {
            // 选中指示器
            Radio({ value: option.label, group: 'fontScaleGroup' })
              .checked(this.selectedIndex === index)
              .onChange((isChecked: boolean) => {
                if (isChecked) {
                  this.selectedIndex = index;
                }
              })
              .width(20)
              .height(20)

            // 档位名称
            Text(option.label)
              .fontSize(16)
              .fontColor('#333333')
              .margin({ left: 12 })
              .layoutWeight(1)

            // 缩放比例
            Text(`${(option.scale * 100).toFixed(0)}%`)
              .fontSize(14)
              .fontColor('#999999')
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.selectedIndex === index ? '#e6f7ff' : Color.White)
          .borderRadius(8)
          .onClick(() => {
            this.selectedIndex = index;
          })
        }, (option: FontScaleOption) => option.label)
      }
      .width('100%')

      // 按钮区域
      Row() {
        // 取消按钮
        Button('取消')
          .width('45%')
          .height(40)
          .backgroundColor('#f5f5f5')
          .fontColor('#333333')
          .onClick(() => {
            this.controller.close();
          })

        Blank().width('10%')

        // 确认按钮
        Button(this.isProcessing ? '应用中...' : '确认')
          .width('45%')
          .height(40)
          .backgroundColor('#0A59F7')
          .fontColor(Color.White)
          .enabled(!this.isProcessing)
          .onClick(() => {
            this.onSelectScale(this.selectedIndex);
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .width('85%')
  }
}

/**
 * 头像选择器对话框。
 */
@CustomDialog
struct AvatarPickerDialog {
  controller: CustomDialogController;
  /** 数据库助手 */
  userDbHelper: UserDatabaseHelper | null = null;
  /** 设置成功回调 */
  onSuccess: () => void = () => {};
  
  /** 当前登录用户名（从 AppStorage 获取） */
  @StorageProp('currentUsername') username: string = '';
  /** 当前选中的头像ID */
  @State selectedAvatarId: number = 1;
  /** 是否正在处理 */
  @State isProcessing: boolean = false;
  /** 错误提示 */
  @State errorMsg: string = '';

  /**
   * 组件即将出现时调用。
   */
  async aboutToAppear(): Promise<void> {
    // 加载当前用户的头像ID
    if (this.userDbHelper && this.username) {
      try {
        const currentAvatarId = await this.userDbHelper.getUserAvatarId(this.username);
        this.selectedAvatarId = currentAvatarId;
        console.info('[AvatarPickerDialog] 当前头像ID: ' + currentAvatarId);
      } catch (err) {
        console.error('[AvatarPickerDialog] 加载头像ID失败: ' + JSON.stringify(err));
      }
    }
  }

  /**
   * 选择头像。
   */
  async selectAvatar(avatarId: number): Promise<void> {
    this.selectedAvatarId = avatarId;
  }

  /**
   * 保存头像设置。
   */
  async saveAvatar(): Promise<void> {
    if (!this.userDbHelper || !this.username) {
      this.errorMsg = '初始化失败，请重试';
      return;
    }

    // 验证头像ID范围
    if (this.selectedAvatarId < 1 || this.selectedAvatarId > 11) {
      this.errorMsg = '头像ID无效';
      return;
    }

    this.isProcessing = true;
    this.errorMsg = '';

    try {
      const success = await this.userDbHelper.updateUserAvatarId(this.username, this.selectedAvatarId);
      this.isProcessing = false;
      
      if (success) {
        // === 关键修复：同步更新AppStorage中的头像ID ===
        AppStorage.setOrCreate('currentUserAvatarId', this.selectedAvatarId);
        console.info('[AvatarPickerDialog] ✅ 头像ID已同步到AppStorage: ' + this.selectedAvatarId);
        
        // 关闭对话框
        this.controller.close();
        // 调用成功回调
        this.onSuccess();
        // 显示成功提示
        ToolKits.showToast('头像设置成功');
      } else {
        this.errorMsg = '头像保存失败，请重试';
      }
    } catch (err) {
      this.isProcessing = false;
      this.errorMsg = '操作失败：' + JSON.stringify(err);
      console.error('[AvatarPickerDialog] Save avatar error: ' + JSON.stringify(err));
    }
  }

  build() {
    Column() {
      // 标题
      Text('选择头像')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 20 })

      // 头像预览
      Column() {
        // 当前选中的头像预览
        Image($r('app.media.avatar_' + this.selectedAvatarId))
          .width(80)
          .height(80)
          .borderRadius(40)
          .objectFit(ImageFit.Cover)
          .border({ width: 3, color: '#0A59F7' })
        
        Text('头像 ' + this.selectedAvatarId)
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 8 })
      }
      .width('100%')
      .height(120)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#f5f5f5')
      .borderRadius(12)
      .margin({ bottom: 16 })

      // 头像网格
      Grid() {
        ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (avatarId: number) => {
          GridItem() {
            Column() {
              // 头像图片
              Image($r('app.media.avatar_' + avatarId))
                .width(60)
                .height(60)
                .borderRadius(30)
                .objectFit(ImageFit.Cover)
                .border({ width: this.selectedAvatarId === avatarId ? 3 : 1, color: this.selectedAvatarId === avatarId ? '#0A59F7' : '#e0e0e0' })
              
              // 头像编号
              Text(avatarId.toString())
                .fontSize(12)
                .fontColor('#666666')
                .margin({ top: 4 })
            }
            .width('100%')
            .height(90)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.selectAvatar(avatarId);
            })
          }
        })
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsTemplate('1fr 1fr 1fr')
      .columnsGap(12)
      .rowsGap(12)
      .width('100%')
      .height(280)
      .margin({ bottom: 16 })

      // 错误提示
      if (this.errorMsg) {
        Text(this.errorMsg)
          .fontSize(12)
          .fontColor('#ff0000')
          .width('100%')
          .margin({ bottom: 12 })
      }

      // 按钮区域
      Row() {
        // 取消按钮
        Button('取消')
          .width('45%')
          .height(40)
          .backgroundColor('#f5f5f5')
          .fontColor('#333333')
          .onClick(() => {
            this.controller.close();
          })

        Blank().width('10%')

        // 确认按钮
        Button(this.isProcessing ? '保存中...' : '确认')
          .width('45%')
          .height(40)
          .backgroundColor('#0A59F7')
          .fontColor(Color.White)
          .enabled(!this.isProcessing)
          .onClick(() => {
            this.saveAvatar();
          })
      }
      .width('100%')
    }
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .width('90%')
  }
}

/**
 * 我的页面组件。
 *
 * @author wangyifan & qinweiming
 */
@Component
export struct MineComponent {
  /** 当前登录用户名（使用 @StorageLink 双向绑定，并监听变化） */
  @StorageLink('currentUsername') @Watch('onCurrentUsernameChanged') currentUsername: string = '';
  /** 用户头像首字母 */
  @State avatarText: string = '';
  /** 用户头像ID（1-11） */
  @State avatarId: number = 1;
  /** 是否正在加载头像 */
  @State isLoadingAvatar: boolean = false;
  
  /** 数据库助手 */
  private userDbHelper: UserDatabaseHelper | null = null;
  /** 字体缩放管理器 */
  private fontScaleManager: FontScaleManager | null = null;
  /** 上下文 */
  private context: common.UIAbilityContext | null = null;
  
  /** 修改密码对话框控制器 */
  private changePasswordDialogController: CustomDialogController | null = null;
  /** 字体大小调节对话框控制器 */
  private fontScaleDialogController: CustomDialogController | null = null;
  /** 头像选择器对话框控制器 */
  private avatarPickerDialogController: CustomDialogController | null = null;
  /** 登录成功事件回调 */
  private loginSuccessEventCallback?: Function;

  /**
   * 当前登录用户名变化时的回调。
   */
  onCurrentUsernameChanged(): void {
    console.info(TAG + 'Current username changed to: ' + this.currentUsername);
    // 更新头像文字
    if (this.currentUsername && this.currentUsername.length > 0) {
      this.avatarText = this.currentUsername.charAt(0).toUpperCase();
    } else {
      this.avatarText = 'U';
    }
    // 重新加载用户头像ID
    this.loadUserAvatarId();
  }

  /**
   * 生命周期初始化。
   */
  async aboutToAppear() {
    // 初始化上下文和数据库助手
    this.context = getContext(this) as common.UIAbilityContext;
    this.userDbHelper = UserDatabaseHelper.getInstance(this.context);
    this.fontScaleManager = FontScaleManager.getInstance(this.context);
    
    // 设置头像文字（用户名首字母）
    if (this.currentUsername && this.currentUsername.length > 0) {
      this.avatarText = this.currentUsername.charAt(0).toUpperCase();
    } else {
      this.avatarText = 'U';
    }
    
    // 加载用户头像ID
    await this.loadUserAvatarId();
    
    // 注册登录成功事件监听
    if (this.context) {
      this.context.eventHub.on('loginSuccess', this.loginSuccessEventCallback = (username: string) => {
        console.info(TAG + 'Login success event received, username: ' + username);
        // 手动更新 currentUsername（虽然 @StorageLink 会自动更新，但这里确保同步）
        this.currentUsername = username;
        // 更新头像文字
        this.avatarText = username.charAt(0).toUpperCase();
        // 重新加载用户头像ID
        this.loadUserAvatarId();
      });
    }
  }
  
  /**
   * 生命周期销毁。
   */
  aboutToDisappear(): void {
    // 取消登录成功事件监听
    if (this.context && this.loginSuccessEventCallback) {
      this.context.eventHub.off('loginSuccess', this.loginSuccessEventCallback);
    }
  }
  
  /**
   * 加载用户头像ID。
   */
  async loadUserAvatarId(): Promise<void> {
    if (!this.userDbHelper || !this.currentUsername) {
      return;
    }
    
    try {
      const savedAvatarId = await this.userDbHelper.getUserAvatarId(this.currentUsername);
      this.avatarId = savedAvatarId;
      // 更新 AppStorage 中的全局头像ID，以便其他组件同步更新
      AppStorage.set('currentUserAvatarId', savedAvatarId);
      console.info(TAG + 'Avatar ID loaded: ' + savedAvatarId);
      // 重置 ChatInputView 中的头像缓存，确保下次发送消息时使用新头像
      ChatInputView.resetCachedAvatarId();
      // 发送头像更新事件，通知聊天界面刷新自己的头像
      IMClientManager.getInstance().getEmitter().emit('avatarUpdated', this.currentUsername);
      console.info(TAG + '头像更新事件已发送，uid: ' + this.currentUsername);
    } catch (err) {
      console.error(TAG + 'Failed to load avatar ID: ' + JSON.stringify(err));
      this.avatarId = 1; // 默认头像ID
      AppStorage.set('currentUserAvatarId', 1);
    }
  }
  
  /**
   * 显示头像选择器对话框。
   */
  showAvatarPickerDialog() {
    this.avatarPickerDialogController = new CustomDialogController({
      builder: AvatarPickerDialog({
        userDbHelper: this.userDbHelper,
        onSuccess: () => {
          // 头像设置成功，重新加载头像ID
          this.loadUserAvatarId();
          // 重置头像发送缓存，确保下次发送消息时携带新头像
          AvatarSendManager.resetLastSentAvatarBase64();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    this.avatarPickerDialogController.open();
  }

  /**
   * 退出登录。
   */
  doLogout() {
    // 显示确认对话框
    ToolKits.showAlertDialog(
      '确定要退出登录吗？',
      '确定',
      undefined,
      () => {
        // 发送登出事件，通知其他页面清空数据
        if (this.context) {
          this.context.eventHub.emit('logout');
          console.info(TAG + 'Logout event emitted');
        }
        
        // 清除登录状态
        AppStorage.delete('currentUsername');
        AppStorage.delete('currentUserAvatarId');
        
        // 释放IM资源
        IMClientManager.getInstance().releaseMobileIMSDK();
        
        // 跳转到登录页
        IMClientManager.getInstance().initMobileIMSDK(getContext(this).getApplicationContext(), getContext(this).eventHub);
        router.replaceUrl({ url: 'pages/LoginPage' });
      },
      '取消',
      $r('sys.color.ohos_id_color_text_secondary'),
      () => {}
    );
  }

  /**
   * 显示修改密码对话框。
   */
  showChangePasswordDialog() {
    this.changePasswordDialogController = new CustomDialogController({
      builder: ChangePasswordDialog({
        userDbHelper: this.userDbHelper,
        onSuccess: () => {
          // 密码修改成功，提示重新登录
          ToolKits.showAlertDialog(
            '密码修改成功，请重新登录',
            '重新登录',
            undefined,
            () => {
              // 清除登录状态
              AppStorage.delete('currentUsername');
              
              // 释放IM资源
              IMClientManager.getInstance().releaseMobileIMSDK();
              
              // 跳转到登录页
              IMClientManager.getInstance().initMobileIMSDK(getContext(this).getApplicationContext(), getContext(this).eventHub);
              router.replaceUrl({ url: 'pages/LoginPage' });
            },
            '',
            undefined,
            () => {}
          );
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    this.changePasswordDialogController.open();
  }

  /**
   * 显示暂未开放提示。
   */
  showNotAvailable() {
    ToolKits.showToast('该功能暂未开放');
  }

  /**
   * 显示字体大小调节对话框。
   */
  async showFontScaleDialog() {
    if (!this.fontScaleManager || !this.currentUsername) {
      ToolKits.showToast('初始化失败，请重试');
      return;
    }

    // 获取当前用户的字体缩放设置
    const currentScale = await this.fontScaleManager.getFontScale(this.currentUsername);
    const currentIndex = this.fontScaleManager.getScaleIndex(currentScale);

    this.fontScaleDialogController = new CustomDialogController({
      builder: FontScaleDialog({
        fontScaleManager: this.fontScaleManager,
        initialIndex: currentIndex,
        onSuccess: () => {
          // 字体设置成功后的回调
          console.info(TAG + 'Font scale changed successfully');
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    this.fontScaleDialogController.open();
  }

  build() {
    Column() {
      // 顶部用户信息区域
      Column() {
        // 头像区域（可点击）
        Stack() {
          // 显示内置头像资源
          Image($r('app.media.avatar_' + this.avatarId))
            .width(70)
            .height(70)
            .borderRadius(35)
            .objectFit(ImageFit.Cover)
            .onError(() => {
              // 如果内置资源加载失败，显示默认头像（首字母）
              console.error(TAG + '内置头像资源加载失败，降级显示默认头像，avatarId: ' + this.avatarId);
            })
          
          // 加载提示
          if (this.isLoadingAvatar) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color(Color.White)
          }
        }
        .width(70)
        .height(70)
        .margin({ top: 40, bottom: 12 })
        .onClick(() => {
          this.showAvatarPickerDialog();
        })
        .enabled(!this.isLoadingAvatar)

        // 用户名
        Text(this.currentUsername || '未登录')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .margin({ bottom: 8 })

        // 账号标识
        Text('HarmonyChat 用户')
          .fontSize(14)
          .fontColor('#999999')
          .margin({ bottom: 20 })
      }
      .width('100%')
      .backgroundColor(Color.White)
      .padding({ bottom: 20 })

      // 功能列表
      List() {
        // 修改密码
        ListItem() {
          this.MenuItemBuilder('修改密码', $r('sys.symbol.lock'))
        }
        .onClick(() => {
          this.showChangePasswordDialog();
        })

        // 分割线
        ListItem() {
          Divider().height(0.5).color('#f0f0f0')
        }

        // 推送通知（占位）
        ListItem() {
          this.MenuItemBuilder('推送通知', $r('sys.symbol.bell'))
        }
        .onClick(() => {
          this.showNotAvailable();
        })

        // 分割线
        ListItem() {
          Divider().height(0.5).color('#f0f0f0')
        }

        // 字体大小调节
        ListItem() {
          this.MenuItemBuilder('字体大小', $r('sys.symbol.textformat'))
        }
        .onClick(() => {
          this.showFontScaleDialog();
        })

        // 分割线
        ListItem() {
          Divider().height(0.5).color('#f0f0f0')
        }

        // 菜单设置（占位）
        ListItem() {
          this.MenuItemBuilder('菜单设置', $r('sys.symbol.list_bullet'))
        }
        .onClick(() => {
          this.showNotAvailable();
        })

        // 分割线
        ListItem() {
          Divider().height(0.5).color('#f0f0f0')
        }

        // 清除缓存（占位）
        ListItem() {
          this.MenuItemBuilder('清除缓存', $r('sys.symbol.trash'))
        }
        .onClick(() => {
          this.showNotAvailable();
        })

        // 分割线
        ListItem() {
          Divider().height(0.5).color('#f0f0f0')
        }

        // 隐私协议（占位）
        ListItem() {
          this.MenuItemBuilder('隐私协议', $r('sys.symbol.doc_text'))
        }
        .onClick(() => {
          this.showNotAvailable();
        })

        // 分割线
        ListItem() {
          Divider().height(0.5).color('#f0f0f0')
        }

        // 关于（占位）
        ListItem() {
          this.MenuItemBuilder('关于', $r('sys.symbol.info_circle'))
        }
        .onClick(() => {
          this.showNotAvailable();
        })
      }
      .width('100%')
      .backgroundColor(Color.White)
      .margin({ top: 12 })
      .listDirection(Axis.Vertical)
      .scrollBar(BarState.Off)

      // 退出登录按钮
      Button('退出登录')
        .width('90%')
        .height(44)
        .backgroundColor('#ff4d4f')
        .fontColor(Color.White)
        .fontSize(16)
        .borderRadius(8)
        .margin({ top: 30 })
        .onClick(() => {
          this.doLogout();
        })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  /**
   * 菜单项构建器。
   */
  @Builder
  MenuItemBuilder(title: string, icon: Resource) {
    Row() {
      // 左侧图标
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor(['#333333'])
        .margin({ right: 12 })

      // 标题
      Text(title)
        .fontSize(16)
        .fontColor('#333333')
        .layoutWeight(1)

      // 右侧箭头
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor(['#cccccc'])
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
  }
}
