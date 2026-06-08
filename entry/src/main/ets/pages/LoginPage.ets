import { common, Want } from '@kit.AbilityKit';
import { router, window, KeyboardAvoidMode } from '@kit.ArkUI';
import { LoginInputView } from './components/LoginInputView';
import ToolKits from './utils/ToolKits';
import IMClientManager from '../IMClientManager';
import UIEvent from './constants/UIEvent';
import { LocalDataSender, PLoginInfo, ErrorCode } from 'mobileimsdk/Index';
import UserDatabaseHelper from './utils/UserDatabaseHelper';

const TAG: string = '[LoginPage] ';

/**
 * 登陆界面。
 * 实现真正的账号密码验证，支持注册功能。
 *
 * @author wangyifan & qinweiming
 */
@Entry({ routeName: 'LoginPage' })
@Component
struct LoginPage {

  /** 登陆超时时间定义（单位：毫秒）*/
  readonly RETRY_DELAY: number = 6000;

  /** 密码输入框是否处于焦点状态（用于优化当输入法软键盘处于显示状态时，输入法软键盘会档住"登录"按钮的问题，优化方法就是自动缩小界面上方的Logo图片大小）*/
  @State passwordFocused: boolean = false;

  /** 登录名 */
  @State loginName: string = '';
  /** 登录密码 */
  @State loginPassword: string = '';

  /** 是否正在登录中（true表示是，否则不是） */
  @State @Watch('watchLoginingStatus') isLogining: boolean = false;

  /** 保存登录超时定时器id（此id方便用于关闭定时器时使用） */
  private loginingTimerId: number = -1;

  /** 登录成功后的回调 */
  private onLoginSucessObserver: Function = (code: number) => {};

  /** 用户数据库助手 */
  private userDbHelper: UserDatabaseHelper | null = null;

  /**
   * 生命周期中只被调用一次，类似于iOS中的viewDidLoad、Android中的onCreate.
   */
  aboutToAppear() {
    // 初始化数据库助手
    let context = getContext(this) as common.UIAbilityContext;
    this.userDbHelper = UserDatabaseHelper.getInstance(context);
    
    this.onLoginSucessObserver = (code: number) => {
      // * 已收到服务端登陆反馈则当然应立即取消显示登陆进度提示等
      this.isLogining = false;

      // 服务端返回的登陆结果值：登陆成功
      if(code == ErrorCode.COMMON_CODE_OK) {

        // TODO: -> 友情提示：登陆MobileIMSDK服务器成功后的事情在此实现即可！
        
        // 保存当前登录用户名到全局存储（使用 setOrCreate 确保值被正确设置）
        AppStorage.setOrCreate('currentUsername', this.loginName);
        
        // === 关键修复：登录成功后预加载用户头像ID到AppStorage ===
        (async () => {
          try {
            if (this.userDbHelper) {
              await this.userDbHelper.initDatabase();
              
              // 预加载用户头像ID并存入AppStorage
              const avatarId = await this.userDbHelper.getUserAvatarId(this.loginName);
              AppStorage.setOrCreate('currentUserAvatarId', avatarId);
              console.info(TAG + '✅ 用户头像ID已预加载到AppStorage: ' + avatarId);
              
              // 清理数据库中的无效消息
              const cleanedCount = await this.userDbHelper.cleanInvalidMessages(this.loginName);
              if (cleanedCount > 0) {
                console.info(TAG + '✅ 登录成功后清理了 ' + cleanedCount + ' 条无效消息记录');
              }
            }
          } catch (err) {
            console.error(TAG + '❌ 登录成功后初始化失败: ' + JSON.stringify(err));
            // 失败时设置默认头像ID
            AppStorage.setOrCreate('currentUserAvatarId', 1);
          }
        })();
        
        // 发送登录成功事件，通知其他页面刷新数据
        let context = getContext(this) as common.UIAbilityContext;
        context.eventHub.emit('loginSuccess', this.loginName);
        console.info(TAG + 'Login success event emitted for user: ' + this.loginName);

        // 进入主界面（底部Tab容器页）
        router.replaceUrl({ url: 'pages/MainPage'});
      }
      // 登陆失败
      else {
        // 显示提示框
        ToolKits.showAlertDialog('Sorry，登录失败，错误码='+ code, '知道了', undefined, () =>{}, '', undefined, () =>{});
      }
    };
  }

  /**
   * 登陆。
   * 先进行本地数据库验证，验证通过后再连接IM服务器。
   */
  async doLogin(): Promise<void> {
    // 输入检查
    if (ToolKits.isEmpty(this.loginName, true)) {
      ToolKits.showToast('登录账号不能为空!');
      return;
    }
    
    if (ToolKits.isEmpty(this.loginPassword, true)) {
      ToolKits.showToast('登录密码不能为空!');
      return;
    }

    // 进行本地数据库验证
    if (this.userDbHelper) {
      try {
        const isValid = await this.userDbHelper.checkUser(this.loginName, this.loginPassword);
        
        if (!isValid) {
          // 本地验证失败，提示用户
          ToolKits.showAlertDialog('用户名或密码错误，请重新输入或前往注册！', '知道了', undefined, () => {}, '', undefined, () => {});
          return;
        }
        
        // 本地验证成功，继续进行IM服务器登录
        console.info(TAG + 'Local authentication passed, connecting to IM server...');
        this.doLoginImpl(this.loginName, this.loginPassword);
      } catch (err) {
        console.error(TAG + 'Database check failed: ' + JSON.stringify(err));
        ToolKits.showToast('登录验证失败，请重试');
      }
    } else {
      ToolKits.showToast('数据库未初始化');
    }
  }

  /*
   * 真正的登陆信息发送实现方法。
   */
  doLoginImpl(loginUserId: string, loginToken: string) {
    // * 立即显示登陆处理进度提示等（并将同时启动超时检查线程）
    this.isLogining = true;

    // * 将要提交的登陆信息对象
    let loginInfo: PLoginInfo = new PLoginInfo();
    loginInfo.loginUserId = loginUserId;
    loginInfo.loginToken = loginToken;

    // * 发送登陆数据包(提交登陆名和密码)
    let code: number = LocalDataSender.getInstance().sendLogin(loginInfo);
    if(code == ErrorCode.COMMON_CODE_OK) {
      ToolKits.showToast('登录请求已发出。。。');
    } else {
      ToolKits.showToast('登录请求发送失败，错误码：'+ code);
      // * 登陆信息没有成功发出时当然无条件取消显示登陆进度条
      this.isLogining = false;
    }
  }

  /**
   * Watch登录状态的改变。
   */
  watchLoginingStatus(): void {
    if(this.isLogining) {
      // * 设置好服务端反馈的登陆结果观察者（当客户端收到服务端反馈过来的登陆消息时将被通知）【2】
      IMClientManager.getInstance().getEmitter().on(UIEvent.UIEVENT_onIMAfterLoginComplete, this.onLoginSucessObserver);

      // 开启登录超时计时器
      this.startLoginTimer();
    } else {
      //## try to bug FIX ! 20160810：此observer本身执行完成才设置为nil，解决之前过早被nil而导致有时怎么也无法跳过登陆界面的问题
      // * 取消设置好服务端反馈的登陆结果观察者（当客户端收到服务端反馈过来的登陆消息时将被通知）【1】
      IMClientManager.getInstance().getEmitter().off(UIEvent.UIEVENT_onIMAfterLoginComplete)

      // 关闭登录超时计时器
      this.stopLoginTimer();
    }
  }

  /**
   * 开启登录超时计时器。
   */
  startLoginTimer() {
    // 先确保清除之前的计时器
    this.stopLoginTimer();
    // 登陆超时计时器
    this.loginingTimerId = setTimeout(() => {
      this.onLoginTimeout();
    }, this.RETRY_DELAY);
  }

  /**
   * 关闭登录超时计时器。
   */
  stopLoginTimer() {
    if(this.loginingTimerId != -1) {
      clearTimeout(this.loginingTimerId);
      this.loginingTimerId = -1;
    }
  }

  /**
   * 登录超时后要执行的逻辑。
   */
  onLoginTimeout() {
    // * 清除登录状态等
    this.isLogining = false;

    // 确认Action
    let confrimAction: Callback<void> = () => {
      // 重试
      this.doLogin();
    };

    // 退出Action
    let cancelAction: Callback<void> = () => {
      // 取消登陆中的状态
      this.isLogining = false;
    };

    // 显示超时提示窗
    ToolKits.showAlertDialog('登录超时，可能是网络故障或服务器无法连接，是否重试？', '重试！', undefined, confrimAction, '取消', $r('sys.color.ohos_id_color_badge_red'), cancelAction);
  }

  /**
   * 联系作者。
   */
  doContactAuthor() {
    try {
      let want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: 'http://www.52im.net/'
      }
      let context = getContext(this) as common.UIAbilityContext;
      context.startAbility(want)
      console.info(`explicit start ability succeed`)
    } catch (error) {
      console.info(`explicit start ability failed with ${error.code}`)
    }
  }

  /**
   * 跳转到注册页面。
   */
  goToRegister() {
    router.pushUrl({ url: 'pages/RegisterPage' });
  }

  build() {
    Stack() {
      GridRow({ columns: 4 }) {
        GridCol({ span: 4, offset: 0  }) {
          Column() {
            Image($r('app.media.startIcon1'))
              .width(this.passwordFocused? 45 : 96)
              .aspectRatio(1)
              .margin({ top: 56 })
              .border({width: 1, radius: 22, color: '#eceef1'})
              .animation({ duration: 250, curve: Curve.EaseOut, iterations: 1, playMode: PlayMode.Normal })
            Row() {
              Text('HarmonyChat')
                .fontSize(30)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .lineHeight(40)
                .fontWeight(FontWeight.Medium)
              Text('鸿蒙')
                .fontFamily('HarmonyHeiTi')
                .fontColor(Color.White)
                .fontSize(13)
                .fontWeight(500)
                .backgroundColor(Color.Black)
                .padding({top:4, bottom:4, left: 6, right: 6})
                .borderRadius(6)
                .margin({left: 5})
            }
            .margin({ top: 20 })

            Row() {
              Text('基于MoibleIMSDK的鸿蒙端聊天程序')
                .fontSize(14)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .lineHeight(19)
              Text('v1.0')
                .fontSize(12)
                .fontColor('#a0a2a6')
                .lineHeight(19)
                .margin({left: 5})
            }
            .margin({ top: 4 })

            // 输入区组件
            LoginInputView({
              loginName: this.loginName,
              loginPassword: this.loginPassword,
              passwordFocused: this.passwordFocused
            })

            // 登录按钮
            Button({
              type: ButtonType.Normal,
              stateEffect: true
            }) {
              Row() {
                // 正在登陆则显示一个进度条
                if(this.isLogining) {
                  LoadingProgress().width(24).height(24).margin({ right: 5 }).color(0xFFFFFF)
                }

                Text(this.isLogining  ? '正在登录 ...' : '登录')
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
            .enabled(!this.isLogining)
            .onClick(() => {
              // 收起软键盘
              ToolKits.hideSoftInputMethod(this.getUIContext());
              // 开始登录
              this.doLogin();
            })

            // 去注册按钮
            Button({ type: ButtonType.Normal }) {
              Text('还没有账号？去注册')
                .fontSize(14)
                .fontColor('#0A59F7')
            }
            .backgroundColor(Color.Transparent)
            .margin({ top: 15 })
            .onClick(() => {
              this.goToRegister();
            })

            Blank()

            Text('Developed by Fan&Qin')
              .fontSize(12)
              .fontColor('#a0a2a6')
              .lineHeight(14)
              .width('100%')
              .textAlign(TextAlign.Center)
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
    // 适配流海屏（顶部状态栏透明并穿过，并透过底部上划操作区）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
