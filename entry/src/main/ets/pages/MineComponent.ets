/*
 * Copyright (C) 2024  即时通讯网(52im.net) & Jack Jiang.
 * The MobileIMSDK-鸿蒙Next客户端 Project. All rights reserved.
 *
 * 联系邮件：jack.jiang@52im.net
 * 联系微信：hellojackjiang
 * 联系QQ： 413980957
 * 技术社区：http://www.52im.net
 */

import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import ToolKits from './utils/ToolKits';
import UserDatabaseHelper from './utils/UserDatabaseHelper';
import IMClientManager from '../IMClientManager';
import PreferenceManager from './utils/PreferenceManager';
import FontScaleManager, { FONT_SCALE_OPTIONS, FontScaleOption } from './utils/FontScaleManager';
import { AvatarSendManager } from './utils/AvatarCacheManager';

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
 * 我的页面组件。
 *
 * @author Jack Jiang
 */
@Component
export struct MineComponent {
  /** 当前登录用户名 */
  @StorageProp('currentUsername') currentUsername: string = '';
  /** 用户头像首字母 */
  @State avatarText: string = '';
  /** 用户头像路径 */
  @State avatarPath: string = '';
  /** 图片组件刷新key（用于强制刷新Image组件） */
  @State imageKey: number = 0;
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
    
    // 加载已有头像
    await this.loadUserAvatar();
  }
  
  /**
   * 加载用户头像。
   */
  async loadUserAvatar(): Promise<void> {
    if (!this.userDbHelper || !this.currentUsername) {
      return;
    }
    
    try {
      const savedAvatarPath = await this.userDbHelper.getUserAvatar(this.currentUsername);
      if (savedAvatarPath && ToolKits.isFileExists(savedAvatarPath)) {
        this.avatarPath = savedAvatarPath;
        console.info(TAG + 'Avatar loaded: ' + savedAvatarPath);
      } else {
        this.avatarPath = '';
        console.info(TAG + 'No custom avatar found, using default');
      }
    } catch (err) {
      console.error(TAG + 'Failed to load avatar: ' + JSON.stringify(err));
      this.avatarPath = '';
    }
  }
  
  /**
   * 选择并保存头像。
   */
  async selectAndSaveAvatar(): Promise<void> {
    console.info(TAG + '=== 开始选择头像 ===');
    
    if (!this.context || !this.userDbHelper || !this.currentUsername) {
      console.error(TAG + '❌ 初始化失败：context=' + !!this.context + 
        ', userDbHelper=' + !!this.userDbHelper + 
        ', currentUsername=' + this.currentUsername);
      ToolKits.showToast('初始化失败，请重试');
      return;
    }
    
    if (this.isLoadingAvatar) {
      console.warn(TAG + '⚠️ 正在加载中，请稍候');
      return;
    }
    
    this.isLoadingAvatar = true;
    
    try {
      // 创建PhotoViewPicker实例
      console.info(TAG + '创建 PhotoViewPicker 实例');
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      
      // 设置选择选项
      const photoSelectOptions: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };
      
      // 打开图片选择器
      console.info(TAG + '打开图片选择器');
      const photoSelectResult: photoAccessHelper.PhotoSelectResult = await photoPicker.select(photoSelectOptions);
      
      // 检查是否选择了图片
      if (!photoSelectResult.photoUris || photoSelectResult.photoUris.length === 0) {
        this.isLoadingAvatar = false;
        console.info(TAG + '⚠️ 未选择图片');
        return;
      }
      
      const selectedUri = photoSelectResult.photoUris[0];
      console.info(TAG + '✅ 已选择图片，URI: ' + selectedUri);
      
      // 复制图片到私有目录
      console.info(TAG + '开始复制图片到私有目录...');
      const newPath = await ToolKits.copyImageToPrivateDir(selectedUri, this.currentUsername, this.context);
      console.info(TAG + '复制结果：' + (newPath ? '成功，路径=' + newPath : '失败'));
      
      if (!newPath) {
        this.isLoadingAvatar = false;
        console.error(TAG + '❌ 图片复制失败');
        ToolKits.showToast('图片保存失败，请重试');
        return;
      }
      
      // 验证文件是否存在且大小>0
      const fileExists = ToolKits.isFileExists(newPath);
      console.info(TAG + '验证文件存在：' + fileExists);
      
      if (!fileExists) {
        this.isLoadingAvatar = false;
        console.error(TAG + '❌ 复制后的文件不存在');
        ToolKits.showToast('图片保存失败，请重试');
        return;
      }
      
      // 删除旧头像（如果存在且与新头像不同）
      if (this.avatarPath && this.avatarPath !== newPath && ToolKits.isFileExists(this.avatarPath)) {
        console.info(TAG + '删除旧头像：' + this.avatarPath);
        ToolKits.deleteFile(this.avatarPath);
      }
      
      // 保存新头像路径到数据库
      console.info(TAG + '调用 updateUserAvatar，用户名=' + this.currentUsername + ', 路径=' + newPath);
      const success = await this.userDbHelper.updateUserAvatar(this.currentUsername, newPath);
      console.info(TAG + '数据库更新结果：' + (success ? '成功' : '失败'));
      
      this.isLoadingAvatar = false;
      
      if (success) {
        // 更新UI显示 - 强制刷新
        console.info(TAG + '更新UI显示，旧路径=' + this.avatarPath + ', 新路径=' + newPath);
        
        // 更新头像路径
        this.avatarPath = newPath;
        
        // 更新imageKey，强制Image组件重新渲染
        this.imageKey++;
        console.info(TAG + '更新imageKey: ' + this.imageKey);
        
        // 重置头像发送缓存，确保下次发送消息时携带新头像
        console.info(TAG + '重置 AvatarSendManager 缓存');
        AvatarSendManager.resetLastSentAvatarBase64();
        
        ToolKits.showToast('头像设置成功');
        console.info(TAG + '✅ 头像更新完成，最终路径: ' + this.avatarPath);
      } else {
        console.error(TAG + '❌ 数据库更新失败');
        ToolKits.showToast('头像保存失败，请重试');
      }
    } catch (err) {
      this.isLoadingAvatar = false;
      console.error(TAG + '❌ 选择头像异常: ' + JSON.stringify(err));
      ToolKits.showToast('选择图片失败，请重试');
    }
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
        // 清除登录状态
        AppStorage.delete('currentUsername');
        
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
          if (this.avatarPath && this.avatarPath.length > 0) {
            // 显示自定义头像
            Image('file://' + this.avatarPath)
              .width(70)
              .height(70)
              .borderRadius(35)
              .objectFit(ImageFit.Cover)
              .key(`avatar_${this.imageKey}`) // 使用动态key强制刷新
              .onError(() => {
                // 图片加载失败时，降级显示默认头像
                console.error(TAG + '头像加载失败，降级显示默认头像，路径: ' + this.avatarPath);
                this.avatarPath = '';
              })
          } else {
            // 显示默认头像（首字母）
            Circle()
              .width(70)
              .height(70)
              .fill('#0A59F7')
            
            Text(this.avatarText)
              .fontSize(32)
              .fontColor(Color.White)
          }
          
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
          this.selectAndSaveAvatar();
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
