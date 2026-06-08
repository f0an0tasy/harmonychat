import { AbilityConstant, common, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import IMClientManager from '../IMClientManager';
import { ClientCoreSDK } from "mobileimsdk";
import UserDatabaseHelper from '../pages/utils/UserDatabaseHelper';

const TAG: string = '[EntryAbility] '

/**
 * 入口Ability实现类。
 *
 * @author wangyifan & qinweiming
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    ClientCoreSDK.Log.debug(TAG+ 'Ability onCreate');

    // init MobileIMSDK first
    // 提示：在不退出APP的情况下退出登陆后再重新登陆时，请确保调用本方法一次，不然会报code=203错误哦！
    IMClientManager.getInstance().initMobileIMSDK(this.context.getApplicationContext(), this.context.eventHub);
    
    // 初始化用户数据库
    this.initUserDatabase();
  }
  
  /**
   * 初始化用户数据库。
   */
  async initUserDatabase(): Promise<void> {
    try {
      let dbHelper = UserDatabaseHelper.getInstance(this.context);
      await dbHelper.initDatabase();
      ClientCoreSDK.Log.info(TAG + 'User database initialized successfully');
    } catch (err) {
      ClientCoreSDK.Log.error(TAG + 'Failed to initialize user database: ' + JSON.stringify(err));
    }
  }

  onDestroy(): void {
    ClientCoreSDK.Log.debug(TAG+ 'Ability onDestroy');

    // 释放IM核心占用的资源
    IMClientManager.getInstance().releaseMobileIMSDK();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    ClientCoreSDK.Log.debug(TAG+ 'Ability onWindowStageCreate');

    AppStorage.set<window.WindowStage>('windowStage', windowStage);
    AppStorage.set<window.Window>('window', windowStage.getMainWindowSync());// 获取应用主窗口
    AppStorage.set<common.UIAbilityContext>('uiAbilityContext', this.context);

    windowStage.loadContent('pages/SplashPage', (err) => {
      if (err.code) {
        ClientCoreSDK.Log.error(TAG+ 'Failed to load the content. Cause: %{public}s'+ (JSON.stringify(err) ?? ''));
        return;
      }
      ClientCoreSDK.Log.debug(TAG+ 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    ClientCoreSDK.Log.debug(TAG+ 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    ClientCoreSDK.Log.debug(TAG+ 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    ClientCoreSDK.Log.debug(TAG+ 'Ability onBackground');
  }
}
