import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const TAG: string = '[FontScaleManager] ';
const PREFERENCES_NAME: string = 'font_scale_pref';

/**
 * 字体缩放档位配置。
 */
export interface FontScaleOption {
  label: string;      // 显示名称
  scale: number;      // 缩放比例
  description: string; // 描述
}

/**
 * 预设的字体缩放档位。
 */
export const FONT_SCALE_OPTIONS: FontScaleOption[] = [
  { label: '小', scale: 0.85, description: '适合视力较好的用户' },
  { label: '标准', scale: 1.0, description: '系统默认大小' },
  { label: '大', scale: 1.2, description: '适合中老年用户' },
  { label: '特大', scale: 1.4, description: '适合视力较弱的用户' }
];

/**
 * 字体缩放管理类。
 * 负责存储、读取和应用用户的字体缩放设置。
 * 使用 Preferences 存储，键名格式：fontScale_${username}。
 *
 * @author wangyifan & qinweiming
 */
export default class FontScaleManager {
  private preferences?: preferences.Preferences;
  private context: common.UIAbilityContext;
  private static instance: FontScaleManager;

  private constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.initPreference();
  }

  /**
   * 获取单例实例。
   */
  public static getInstance(context: common.UIAbilityContext): FontScaleManager {
    if (!FontScaleManager.instance) {
      FontScaleManager.instance = new FontScaleManager(context);
    }
    return FontScaleManager.instance;
  }

  /**
   * 初始化 Preferences。
   */
  private async initPreference(): Promise<void> {
    try {
      this.preferences = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      console.info(TAG + 'Font scale preferences initialized');
    } catch (err) {
      console.error(TAG + 'Failed to init preferences: ' + JSON.stringify(err));
    }
  }

  /**
   * 确保 preferences 已初始化。
   */
  private async ensurePreferences(): Promise<void> {
    if (!this.preferences) {
      await this.initPreference();
    }
  }

  /**
   * 保存用户的字体缩放设置。
   * 
   * @param username 用户名
   * @param scale 缩放比例（0.85, 1.0, 1.2, 1.4 等）
   */
  public async saveFontScale(username: string, scale: number): Promise<void> {
    await this.ensurePreferences();
    if (!this.preferences) {
      console.error(TAG + 'Preferences not initialized');
      return;
    }

    try {
      const key = `fontScale_${username}`;
      await this.preferences.put(key, scale);
      await this.preferences.flush();
      console.info(TAG + `Font scale saved: ${key} = ${scale}`);
    } catch (err) {
      console.error(TAG + 'Failed to save font scale: ' + JSON.stringify(err));
    }
  }

  /**
   * 获取用户的字体缩放设置。
   * 
   * @param username 用户名
   * @returns 缩放比例，默认为 1.0
   */
  public async getFontScale(username: string): Promise<number> {
    await this.ensurePreferences();
    if (!this.preferences) {
      console.error(TAG + 'Preferences not initialized, returning default scale');
      return 1.0;
    }

    try {
      const key = `fontScale_${username}`;
      const scale = await this.preferences.get(key, 1.0) as number;
      console.info(TAG + `Font scale loaded: ${key} = ${scale}`);
      return scale;
    } catch (err) {
      console.error(TAG + 'Failed to get font scale: ' + JSON.stringify(err));
      return 1.0;
    }
  }

  /**
   * 应用字体缩放到全局。
   * 使用 ApplicationContext.setFontSizeScale 方法设置应用字体大小缩放比例。
   * 该设置会应用于应用程序的所有页面和所有文本控件。
   * 
   * @param scale 缩放比例
   */
  public applyFontScale(scale: number): void {
    try {
      // 确保缩放比例在合理范围内
      const validScale = Math.max(0.5, Math.min(2.0, scale));
      
      // 获取 ApplicationContext 并设置字体缩放
      const applicationContext = this.context.getApplicationContext();
      applicationContext.setFontSizeScale(validScale);
      
      console.info(TAG + `Font scale applied: ${validScale}`);
    } catch (err) {
      console.error(TAG + 'Failed to apply font scale: ' + JSON.stringify(err));
    }
  }

  /**
   * 获取当前字体缩放档位的索引。
   * 
   * @param scale 当前缩放比例
   * @returns 档位索引，如果没有匹配则返回 1（标准）
   */
  public getScaleIndex(scale: number): number {
    for (let i = 0; i < FONT_SCALE_OPTIONS.length; i++) {
      if (Math.abs(FONT_SCALE_OPTIONS[i].scale - scale) < 0.01) {
        return i;
      }
    }
    return 1; // 默认返回"标准"
  }

  /**
   * 根据档位索引获取缩放比例。
   * 
   * @param index 档位索引
   * @returns 缩放比例
   */
  public getScaleByIndex(index: number): number {
    if (index >= 0 && index < FONT_SCALE_OPTIONS.length) {
      return FONT_SCALE_OPTIONS[index].scale;
    }
    return 1.0; // 默认返回标准
  }
}
