import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import ToolKits from './utils/ToolKits';
import UserDatabaseHelper from './utils/UserDatabaseHelper';

const TAG: string = '[RegisterPage] ';

/**
 * 注册界面。
 * 实现用户注册功能，将账号密码存储到本地数据库。
 *
 * @author wangyifan & qinweiming
 */
@Entry({ routeName: 'RegisterPage' })
@Component
struct RegisterPage {

  /** 用户名 */
  @State username: string = '';
  /** 密码 */
  @State password: string = '';
  /** 确认密码 */
  @State confirmPassword: string = '';
  
  /** 密码输入框是否处于焦点状态 */
  @State passwordFocused: boolean = false;
  /** 确认密码输入框是否处于焦点状态 */
  @State confirmPwdFocused: boolean = false;
  
  /** 是否正在注册中 */
  @State isRegistering: boolean = false;

  /** 用户数据库助手 */
  private userDbHelper: UserDatabaseHelper | null = null;

  /**
   * 生命周期中只被调用一次。
   */
  aboutToAppear() {
    // 初始化数据库助手
    let context = getContext(this) as common.UIAbilityContext;
    this.userDbHelper = UserDatabaseHelper.getInstance(context);
  }

  /**
   * 执行注册。
   */
  async doRegister(): Promise<void> {
    // 1. 用户名校验
    if (ToolKits.isEmpty(this.username, true)) {
      ToolKits.showToast('用户名不能为空！');
      return;
    }
    
    if (this.username.length < 3) {
      ToolKits.showToast('用户名长度不能小于3位！');
      return;
    }
    
    // 2. 密码校验
    if (ToolKits.isEmpty(this.password, true)) {
      ToolKits.showToast('密码不能为空！');
      return;
    }
    
    if (this.password.length < 6) {
      ToolKits.showToast('密码长度不能小于6位！');
      return;
    }
    
    // 3. 确认密码校验
    if (this.password !== this.confirmPassword) {
      ToolKits.showToast('两次输入的密码不一致！');
      return;
    }
    
    // 开始注册
    this.isRegistering = true;
    
    if (this.userDbHelper) {
      try {
        // 检查用户名是否已存在
        const exists = await this.userDbHelper.isUserExists(this.username);
        
        if (exists) {
          this.isRegistering = false;
          ToolKits.showAlertDialog('该用户名已被注册，请更换用户名！', '知道了', undefined, () => {}, '', undefined, () => {});
          return;
        }
        
        // 添加新用户
        const rowId = await this.userDbHelper.addUser(this.username, this.password);
        
        this.isRegistering = false;
        
        if (rowId > 0) {
          // 注册成功
          ToolKits.showAlertDialog('注册成功！请使用新账号登录。', '去登录', undefined, () => {
            // 返回登录页面
            router.back();
          }, '', undefined, () => {
            // 清空输入框
            this.username = '';
            this.password = '';
            this.confirmPassword = '';
          });
        } else {
          ToolKits.showToast('注册失败，请重试！');
        }
      } catch (err) {
        this.isRegistering = false;
        console.error(TAG + 'Register failed: ' + JSON.stringify(err));
        ToolKits.showToast('注册失败，请重试！');
      }
    } else {
      this.isRegistering = false;
      ToolKits.showToast('数据库未初始化');
    }
  }

  /**
   * 返回登录页面。
   */
  goBackToLogin() {
    router.back();
  }

  build() {
    Stack() {
      GridRow({ columns: 4 }) {
        GridCol({ span: 4, offset: 0 }) {
          Column() {
            // Logo
            Image($r('app.media.startIcon1'))
              .width(this.passwordFocused || this.confirmPwdFocused ? 45 : 96)
              .aspectRatio(1)
              .margin({ top: 40 })
              .border({ width: 1, radius: 22, color: '#eceef1' })
              .animation({ duration: 250, curve: Curve.EaseOut, iterations: 1, playMode: PlayMode.Normal })
            
            // 标题
            Row() {
              Text('注册新账号')
                .fontSize(28)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .lineHeight(40)
                .fontWeight(FontWeight.Medium)
            }
            .margin({ top: 20 })

            // 输入区域
            Column() {
              this.TextLine({ bottom: 5 })
              
              // 用户名输入框
              Row() {
                Text('用户名')
                  .fontColor('#0e1a26')
                  .fontWeight(500)
                  .width(60)
                TextInput({ text: $$this.username, placeholder: '请输入用户名（至少3位）' })
                  .inputStyle()
                  .margin({ right: 5 })
              }
              .height(52)

              this.TextLine({})

              // 密码输入框
              Row() {
                Text('密码')
                  .fontColor('#0e1a26')
                  .fontWeight(500)
                  .width(60)
                TextInput({ text: $$this.password, placeholder: '请输入密码（至少6位）' })
                  .inputStyle()
                  .type(InputType.Password)
                  .margin({ right: 5 })
                  .passwordIcon({ onIconSrc: $r('app.media.login_showpass_on'), offIconSrc: $r('app.media.login_showpass_off') })
                  .onFocus(() => {
                    this.passwordFocused = true;
                  })
                  .onBlur(() => {
                    this.passwordFocused = false;
                  })
              }
              .height(52)
              .margin({ top: 5 })

              this.TextLine({})

              // 确认密码输入框
              Row() {
                Text('确认密码')
                  .fontColor('#0e1a26')
                  .fontWeight(500)
                  .width(60)
                TextInput({ text: $$this.confirmPassword, placeholder: '请再次输入密码' })
                  .inputStyle()
                  .type(InputType.Password)
                  .margin({ right: 5 })
                  .passwordIcon({ onIconSrc: $r('app.media.login_showpass_on'), offIconSrc: $r('app.media.login_showpass_off') })
                  .onFocus(() => {
                    this.confirmPwdFocused = true;
                  })
                  .onBlur(() => {
                    this.confirmPwdFocused = false;
                  })
              }
              .height(52)
              .margin({ top: 5 })

              this.TextLine({})
            }
            .width('100%')
            .margin({ top: 30 })

            // 注册按钮
            Button({
              type: ButtonType.Normal,
              stateEffect: true
            }) {
              Row() {
                if (this.isRegistering) {
                  LoadingProgress().width(24).height(24).margin({ right: 5 }).color(0xFFFFFF)
                }
                Text(this.isRegistering ? '正在注册...' : '注册')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
            }
            .borderRadius(20)
            .width('100%')
            .backgroundColor('#0A59F7')
            .height(40)
            .margin({ top: 30 })
            .enabled(!this.isRegistering)
            .onClick(() => {
              // 收起软键盘
              ToolKits.hideSoftInputMethod(this.getUIContext());
              // 开始注册
              this.doRegister();
            })

            // 返回登录按钮
            Button({ type: ButtonType.Normal }) {
              Text('已有账号？返回登录')
                .fontSize(14)
                .fontColor('#0A59F7')
            }
            .backgroundColor(Color.Transparent)
            .margin({ top: 15 })
            .onClick(() => {
              this.goBackToLogin();
            })

            Blank()

            // 底部版权信息
            Column() {
              Text('Copyright © 2024 即时通讯网 / 52im.net')
                .fontSize(12)
                .fontColor('#a0a2a6')
                .lineHeight(14)
            }
            .margin({ bottom: 32 })
          }
          .width('100%')
          .height('100%')
          .padding({ left: 12, right: 12 })
        }
      }
      .padding({ left: 16, right: 16 })
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    // 适配流海屏
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  TextLine(margin: Margin) {
    Line()
      .height(0.5)
      .width('100%')
      .backgroundColor('#d0d2d6')
      .padding({ left: 12, right: 12 })
      .margin(margin)
  }
}

@Extend(TextInput)
function inputStyle() {
  .width('100%')
    .height('100%')
    .layoutWeight(1)
    .maxLength(20)
    .fontColor('#353535')
    .placeholderColor('#a1a7af')
    .backgroundColor(Color.Transparent)
}
