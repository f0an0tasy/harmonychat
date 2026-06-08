import { promptAction, window, KeyboardAvoidMode } from "@kit.ArkUI";
import { Callback } from "@ohos.base";
import { common } from "@kit.AbilityKit";
import { ClientCoreSDK } from "mobileimsdk";
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

const TAG: string = '[ToolKits] ';

/**
 * 工具类。
 *
 * @author wangyifan & qinweiming
 */
export default class ToolKits {

  /** 聊天界面全面屏状态栏背景色 */
  static readonly chat_page_title_background_color = '#ffffff';//'#fafafa';//#2e3746';//'#2e3746';
  /** 聊天界面全面屏状态栏文本颜色 */
  static readonly chat_page_title_color = '#000000';//#ffffff';

  /**
   * 退出系统。
   *
   * @param context UIAbilityContext上下文对象
   */
  static exitSystem(context: common.UIAbilityContext) {
    // let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    context.terminateSelf();
  }

  /**
   * 设置全面屏状态栏颜色。
   *
   * @param context 上下文对象
   * @param statusBarContentColor 状态栏文本颜色
   * @param statusBarColor 状态栏背景色
   */
  static setStatusBarColor(context: common.BaseContext, statusBarContentColor: string, statusBarColor: string) {
    // window.getLastWindow(context).then((windowClass: window.Window) => { // 这种方式获得window对象时，在page首次启动后，为啥在onPageShow里调用setStatusBarColor没效果？
      try {
        let windowClass = AppStorage.get<window.Window>('window')

        windowClass?.setWindowSystemBarProperties({
          statusBarContentColor: statusBarContentColor,//color,
          statusBarColor: statusBarColor,
          // navigationBarColor: '#0000ff',
          // navigationBarContentColor: '#fff00f'
        });
      } catch (exception) {
        ClientCoreSDK.Log.error(TAG+ 'Failed to set the system bar properties. Cause: ' + JSON.stringify(exception));
      }
    // });
  }

  /**
   * 收起软键盘。
   *
   * @param context 上下文对象
   */
  static hideSoftInputMethod(context: UIContext) {
    // 收起软键盘，官方资料：https://developer.huawei.com/consumer/cn/doc/best-practices-V5/bpta-keyboard-layout-adapt-V5#section19809195110316
    context.getFocusController().clearFocus();
  }

  /**
   * 设置输入法软键盘避让模式为RESIZE（表示当输入显示时，压缩窗体高度，而不是使用默认的OFFSET模式将窗体整体上推）。
   * 详见官方资料：https://developer.huawei.com/consumer/cn/doc/best-practices-V5/bpta-keyboard-layout-adapt-V5#section08221814182316
   *
   * @param toRESIZE true表示设置为KeyboardAvoidMode.RESIZE模式，否则还原为系统默认的 KeyboardAvoidMode.OFFSET模式
   */
  static setKeyboardAvoidModeToRESIZE(context: UIContext, toRESIZE: boolean) {
    context.setKeyboardAvoidMode(toRESIZE ? KeyboardAvoidMode.RESIZE : KeyboardAvoidMode.OFFSET);

    // window.getLastWindow(context).then(currentWindow => {
    //   currentWindow?.getUIContext().setKeyboardAvoidMode(toRESIZE ? KeyboardAvoidMode.RESIZE : KeyboardAvoidMode.OFFSET);
    // });

    // AppStorage.get<window.Window>('window')?.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
  }

  /**
   * Check obj is empty
   *
   * @param {object} obj
   * @return {boolean} true(empty)
   */
  static isEmpty(obj: object | string, trimString: boolean = false): boolean {
    return obj === undefined
      || obj === null
      || obj === ''
      || (trimString? ((typeof obj === 'string') ? (obj as string).trim() === '' : false) : false);
  }

  /**
   * 返回本地用户UID.
   *
   * @returns local uid
   */
  static getLocalUserUid(): string | undefined {
    return ClientCoreSDK.getInstance().currentLoginInfo?.loginUserId
  }

  /**
   * 显示奶油提示。
   *
   * @param message 提示内容
   * @param duration 持续时间（单位：毫秒），默认1500
   */
  static showToast(message: string | Resource, duration: number = 1500) {
    promptAction.showToast({
      message: message,
      duration: duration,
      // 软键盘弹出时，防止Toast上抬，详见: https://developer.huawei.com/consumer/cn/doc/best-practices-V5/bpta-keyboard-layout-adapt-V5#section381324419328
      showMode: promptAction.ToastShowMode.TOP_MOST,
      // backgroundBlurStyle: BlurStyle.Thin
    });
  }

  /**
   * 显示对话框.
   *
   * @param message 文本显示内容
   * @param primaryButtonText 主按钮文本
   * @param primaryButtonTextColor 主按钮文本颜色
   * @param primaryAction  主按钮Action
   * @param secondaryButtonText 次按钮文本
   * @param secondaryButtonTextColor 次按钮文本颜色
   * @param secondaryAction 次按钮Action
   */
  static showAlertDialog(message: ResourceStr
    , primaryButtonText: string, primaryButtonTextColor: ResourceColor | undefined, primaryAction: Callback<void>
    , secondaryButtonText: string, secondaryButtonTextColor: ResourceColor | undefined, secondaryAction: Callback<void>) {
    AlertDialog.show(
      {
        message: message,
        autoCancel: false,
        alignment: DialogAlignment.Center,
        offset:{ dx: 0, dy: 0 } ,
        // gridCount: 4,
        primaryButton: primaryButtonText ? {
          value: primaryButtonText,
          action: primaryAction,
          fontColor: primaryButtonTextColor
        } : undefined,
        secondaryButton: secondaryButtonText ? {
          value: secondaryButtonText,
          action: secondaryAction,
          fontColor: secondaryButtonTextColor//$r('sys.color.ohos_id_color_badge_red')
        } : undefined
      });
  }

  /**
   * 仿照微信中的消息时间显示逻辑，将时间戳（单位：毫秒）转换为友好的显示格式.
   *
   * 1）7天之内的日期显示逻辑是：今天、昨天(-1d)、前天(-2d)、星期？（只显示总计7天之内的星期数，即<=-4d）；
   * 2）7天之外（即>7天）的逻辑：直接显示完整日期时间。

   * @param timestamp 时间戳（单位：毫秒），形如：1550789954260
   * @param mustIncludeTime true表示输出的格式里一定会包含“时间:分钟”
   * ，否则不包含（参考微信，不包含时分的情况，用于首页“消息”中显示时）
   * @param timeWithSegmentStr 本参数仅在mustIncludeTime=true时有生效，表示在时间字符串前带上“上午”、“下午”、“晚上”这样的描述
   *
   * @return 输出格式形如：“刚刚”、“10:30”、“昨天 12:04”、“前天 20:51”、“星期二”、“2019/2/21 12:09”等形式
   * @author wangyifan & qinweiming
   */
  static getTimeStringAutoShort2(timestamp: number, mustIncludeTime: boolean, timeWithSegmentStr: boolean): string {
    // 当前时间
    let currentDate: Date = new Date();
    // 目标判断时间
    let srcDate: Date = new Date(timestamp);

    let currentYear: number = currentDate.getFullYear();
    let currentMonth: number = (currentDate.getMonth()+1);
    let currentDateD: number = currentDate.getDate();

    let srcYear: number = srcDate.getFullYear();
    let srcMonth: number = (srcDate.getMonth()+1);
    let srcDateD: number = srcDate.getDate();

    let ret: string = '';

    // 要额外显示的时间分钟
    let timeExtraStr = '';
    if(mustIncludeTime) {
      // let timeExtraStr = (mustIncludeTime ? " " + _formatDate(srcDate, "hh:mm") : "");
      timeExtraStr = " "+ToolKits.getTimeHH24Human(srcDate, timeWithSegmentStr);
    }

    // 当年
    if(currentYear === srcYear) {
      let currentTimestamp: number = currentDate.getTime();
      let srcTimestamp: number = timestamp;
      // 相差时间（单位：毫秒）
      let deltaTime: number = (currentTimestamp-srcTimestamp);

      // 当天（月份和日期一致才是）
      if(currentMonth === srcMonth && currentDateD === srcDateD) {
        // // 时间相差60秒以内
        // if(deltaTime < 60 * 1000)
        //     ret = "刚刚";
        // // 否则当天其它时间段的，直接显示“时:分”的形式
        // else
        //     ret = _formatDate(srcDate, "hh:mm");

        // 当天只需要显示时间分钟，且必须显示“上午”、“下午”这样的时间段描述
        ret = ToolKits.getTimeHH24Human(srcDate, true);
      }
      // 当年 && 当天之外的时间（即昨天及以前的时间）
      else {
        // 昨天（以“现在”的时候为基准-1天）
        let yesterdayDate:Date = new Date();
        yesterdayDate.setDate(yesterdayDate.getDate()-1);

        // 前天（以“现在”的时候为基准-2天）
        let beforeYesterdayDate: Date = new Date();
        beforeYesterdayDate.setDate(beforeYesterdayDate.getDate()-2);

        // 用目标日期的“月”和“天”跟上方计算出来的“昨天”进行比较，是最为准确的（如果用时间戳差值
        // 的形式，是不准确的，比如：现在时刻是2019年02月22日1:00、而srcDate是2019年02月21日23:00，
        // 这两者间只相差2小时，直接用“deltaTime/(3600 * 1000)” > 24小时来判断是否昨天，就完全是扯蛋的逻辑了）
        if(srcMonth === (yesterdayDate.getMonth()+1) && srcDateD === yesterdayDate.getDate()) {
          ret = "昨天"+timeExtraStr;// -1d
        }
        // “前天”判断逻辑同上
        else if(srcMonth === (beforeYesterdayDate.getMonth()+1) && srcDateD === beforeYesterdayDate.getDate()) {
          ret = "前天" + timeExtraStr; // -2d
        } else{
          // 跟当前时间相差的小时数
          let deltaHour: number = (deltaTime/(3600 * 1000));

          // 如果小于或等 7*24小时就显示星期几
          if (deltaHour <= 7*24){
            let weekday = new Array<string>(7);
            weekday[0]="星期日";
            weekday[1]="星期一";
            weekday[2]="星期二";
            weekday[3]="星期三";
            weekday[4]="星期四";
            weekday[5]="星期五";
            weekday[6]="星期六";

            // 取出当前是星期几
            let weedayDesc: string = weekday[srcDate.getDay()];
            ret = weedayDesc + timeExtraStr;
          }
          // 否则直接显示完整日期时间
          else
            ret = ToolKits.formatDate(srcDate, "M月d日")+timeExtraStr;
        }
      }
    }
    // 往年
    else{
      ret = ToolKits.formatDate(srcDate, "yy年M月d日")+timeExtraStr;
    }

    return ret;
  }

  /**
   * 获取仅包含“时间:分钟”部分的字符串，24小时制，且可以显示“上午”、“下午”、“晚上”这样的描述。
   *
   * @param srcDateObj 原始日期对象
   * @param timeWithSegmentStr 表示在时间字符串前带上“上午”、“下午”、“晚上”这样的描述
   * @return 如果成功则返回结果，否则返回空字符串""（不是null）
   */
  static getTimeHH24Human(srcDateObj: Date, timeWithSegmentStr: boolean): string {
    let ret: string = '';
    try {
      let timePattern: string = 'hh:mm';
      // 原始的时间分钟字符串
      let timeStr: string = ToolKits.formatDate(srcDateObj, timePattern);

      // 时间段描述（形如：“上午”、“下午”、“晚上”这样的描述），只在中文语言下生效
      let timeSegmentStr: string = '';
      if(timeWithSegmentStr)
        timeSegmentStr = ToolKits.getTimeSegmentStr(timeStr);

      // 组合成最终的人性化时间分钟字符串形式
      ret = timeSegmentStr+timeStr;
    } catch (e) {
      ClientCoreSDK.Log.warn("【DEBUG-getTimeHH24Human】计算出错："+ JSON.stringify(e) +" 【NO】");
    }

    return ret;
  }

  /**
   * 将一个两位24小时时间的转换为上午、下午这样的描述。
   *
   * @param hh24 两位的24小时制时间的小时部分
   * @return 如果成功转换则返回形如：“凌晨”、“上午”等，否则返回空字符串（不是null）
   * @since 3.1
   */
  static getTimeSegmentStr(hh24: string): string {
    let ret: string = '';
    if (hh24 && hh24.length >= 2) {
      try {
        // 取出“小时”部分
        let a = parseInt(hh24.substring(0, 2));
        if (a >= 0 && a <= 6) {
          ret = "凌晨";
        } else if (a > 6 && a <= 12) {
          ret = "上午";
        } else if (a > 12 && a <= 13) {
          ret = "中午";
        } else if (a > 13 && a <= 18) {
          ret = "下午";
        } else if (a > 18 && a <= 24) {
          ret = "晚上";
        }
      } catch (e) {
        ClientCoreSDK.Log.warn("【DEBUG-getTimeSegmentStr】计算出错：" + JSON.stringify(e) + " 【NO】");
      }
    }

    return ret;
  }

  /**
   * 对Date的扩展，将 Date 转化为指定格式的String。
   *
   *  月(M)、日(d)、小时(h)、分(m)、秒(s)、季度(q) 可以用 1-2 个占位符，
   *  年(y)可以用 1-4 个占位符，毫秒(S)只能用 1 个占位符(是 1-3 位的数字)。
   *
   *  【示例】：
   *  common.formatDate(new Date(), 'yyyy-MM-dd hh:mm:ss.S') ==> 2006-07-02 08:09:04.423
   *  common.formatDate(new Date(), 'yyyy-M-d h:m:s.S')      ==> 2006-7-2 8:9:4.18
   *  common.formatDate(new Date(), 'hh:mm:ss.S')            ==> 08:09:04.423
   *
   *  @param date Date对象
   *  @param fmt 格式字符串
   *  @param 格式化的字符串
   */
  static formatDate(date: Date, fmt: string) {
    // let o = {
    //   "M+": date.getMonth() + 1, //月份
    //   "d+": date.getDate(), //日
    //   "h+": date.getHours(), //小时
    //   "m+": date.getMinutes(), //分
    //   "s+": date.getSeconds(), //秒
    //   "q+": Math.floor((date.getMonth() + 3) / 3), //季度
    //   "S": date.getMilliseconds() //毫秒
    // };

     let map = new Map<String, Number>();
     map.set("M+", date.getMonth() + 1); // 月份
     map.set("d+", date.getDate()); // 日
     map.set("h+", date.getHours()); // 小时
     map.set("m+", date.getMinutes()); // 分
     map.set("s+", date.getSeconds()); // 秒
     map.set("q+", Math.floor((date.getMonth() + 3) / 3)); // 季度
     map.set("S", date.getMilliseconds()); // 毫秒

    // if (/(y+)/.test(fmt))
    //   fmt = fmt.replace(RegExp.$1, (date.getFullYear() + "").substr(4 - RegExp.$1.length));

     let yearMatcher = /(y+)/.exec(fmt);
     if (yearMatcher && yearMatcher.length > 0) {
       let match = yearMatcher[0];
       fmt = fmt.replace(match, (date.getFullYear() + "").substr(4 - match.length));
     }

    // for (let k in o) {
    //   if (new RegExp("(" + k + ")").test(fmt)) {
    //     fmt = fmt.replace(RegExp.$1, (RegExp.$1.length == 1) ? (o[k]) : (("00" + o[k]).substr(("" + o[k]).length)));
    //   }
    // }

     map.forEach((value, key) => {
       let matcher = new RegExp(`(${key})`).exec(fmt!);
       if (matcher && matcher.length > 0) {
         let match = matcher[0];
         let replaceValue = '';
         if ((match.length == 1)) {
           replaceValue = `${value}`;
         } else {
           replaceValue = (("00" + value).substr(("" + value).length))
         }
         fmt = fmt!.replace(match, replaceValue);
       }
     });

    return fmt;
  }

  /**
   * 将选择的图片复制到应用私有目录。
   * 
   * @param uri 图片的URI（从PhotoViewPicker获取）
   * @param username 用户名（用于命名文件）
   * @param context 应用上下文
   * @returns Promise<string | null> 返回复制后的本地路径，null表示失败
   */
  static async copyImageToPrivateDir(uri: string, username: string, context: common.UIAbilityContext): Promise<string | null> {
    console.info(TAG + '=== copyImageToPrivateDir 开始 ===');
    console.info(TAG + '参数：uri=' + uri);
    console.info(TAG + '参数：username=' + username);
    console.info(TAG + '参数：filesDir=' + context.filesDir);
    
    try {
      // 创建avatars目录（如果不存在）
      const avatarsDir = context.filesDir + '/avatars';
      console.info(TAG + '目标目录：' + avatarsDir);
      
      // 检查目录是否存在，不存在则创建
      try {
        console.info(TAG + '检查目录是否存在...');
        const stat = fs.statSync(avatarsDir);
        console.info(TAG + '目录状态：isDirectory=' + stat.isDirectory());
        
        if (!stat.isDirectory()) {
          // 如果存在同名文件但不是目录，先删除
          console.info(TAG + '存在同名文件但不是目录，删除并重新创建');
          fs.rmdirSync(avatarsDir);
          fs.mkdirSync(avatarsDir);
          console.info(TAG + '✅ 目录已创建');
        } else {
          console.info(TAG + '✅ 目录已存在');
        }
      } catch (err) {
        // 目录不存在，创建它
        console.info(TAG + '目录不存在，创建目录...');
        fs.mkdirSync(avatarsDir, true);
        console.info(TAG + '✅ 目录已创建');
      }
      
      // 生成新文件名：{username}_avatar_{timestamp}.jpg（加入时间戳避免缓存）
      const timestamp = Date.now();
      const newFileName = `${username}_avatar_${timestamp}.jpg`;
      const destPath = `${avatarsDir}/${newFileName}`;
      console.info(TAG + '目标文件路径：' + destPath);
      
      // 打开源文件（URI）
      console.info(TAG + '打开源文件（URI）...');
      const srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      console.info(TAG + '✅ 源文件已打开，fd=' + srcFile.fd);
      
      // 创建目标文件
      console.info(TAG + '创建目标文件...');
      const destFile = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      console.info(TAG + '✅ 目标文件已创建，fd=' + destFile.fd);
      
      // 复制数据
      console.info(TAG + '开始复制数据...');
      const bufferSize = 4096;
      let buffer = new ArrayBuffer(bufferSize);
      let readLen = fs.readSync(srcFile.fd, buffer);
      let totalBytes = 0;
      
      while (readLen > 0) {
        // 如果读取的数据小于缓冲区大小，只写入实际读取的数据
        if (readLen < bufferSize) {
          const writeBuffer = buffer.slice(0, readLen);
          fs.writeSync(destFile.fd, writeBuffer);
        } else {
          fs.writeSync(destFile.fd, buffer);
        }
        totalBytes += readLen;
        readLen = fs.readSync(srcFile.fd, buffer);
      }
      
      console.info(TAG + '✅ 数据复制完成，总字节数：' + totalBytes);
      
      // 关闭文件
      fs.closeSync(srcFile);
      fs.closeSync(destFile);
      console.info(TAG + '✅ 文件已关闭');
      
      // 验证文件是否创建成功
      const fileExists = ToolKits.isFileExists(destPath);
      console.info(TAG + '验证文件存在：' + fileExists);
      
      if (!fileExists) {
        console.error(TAG + '❌ 文件创建失败，目标文件不存在');
        return null;
      }
      
      // 获取文件大小
      const stat = fs.statSync(destPath);
      console.info(TAG + '✅ 文件大小：' + stat.size + ' bytes');
      
      if (stat.size === 0) {
        console.error(TAG + '❌ 文件大小为0，复制失败');
        return null;
      }
      
      console.info(TAG + '=== copyImageToPrivateDir 完成 ===');
      console.info(TAG + '✅ Image copied successfully to: ' + destPath);
      return destPath;
    } catch (err) {
      console.error(TAG + '❌ Failed to copy image: ' + JSON.stringify(err));
      if (err instanceof Error) {
        console.error(TAG + '错误堆栈: ' + err.stack);
      }
      return null;
    }
  }

  /**
   * 检查文件是否存在。
   * 
   * @param filePath 文件路径
   * @returns boolean true表示文件存在
   */
  static isFileExists(filePath: string): boolean {
    try {
      const stat = fs.statSync(filePath);
      return stat.isFile();
    } catch (err) {
      return false;
    }
  }

  /**
   * 删除文件。
   * 
   * @param filePath 文件路径
   * @returns boolean true表示删除成功
   */
  static deleteFile(filePath: string): boolean {
    try {
      fs.unlinkSync(filePath);
      return true;
    } catch (err) {
      console.error(TAG + 'Failed to delete file: ' + JSON.stringify(err));
      return false;
    }
  }

  /**
   * 读取图片文件并转换为Base64字符串。
   * 用于发送消息时携带头像数据。
   * 
   * @param filePath 图片文件路径
   * @returns Promise<string | null> 返回Base64字符串，null表示失败
   */
  static async readImageToBase64(filePath: string): Promise<string | null> {
    console.info(TAG + '=== readImageToBase64 开始 ===');
    console.info(TAG + '文件路径: ' + filePath);
    
    try {
      // 检查文件是否存在
      if (!ToolKits.isFileExists(filePath)) {
        console.error(TAG + '❌ 图片文件不存在: ' + filePath);
        return null;
      }
      console.info(TAG + '✅ 文件存在');

      // 打开文件
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      console.info(TAG + '✅ 文件已打开');
      
      // 获取文件大小
      const stat = fs.statSync(filePath);
      const fileSize = stat.size;
      console.info(TAG + '文件大小: ' + fileSize + ' bytes');
      
      // 限制文件大小（最大 5MB）
      const MAX_SIZE = 5 * 1024 * 1024;
      if (fileSize > MAX_SIZE) {
        console.warn(TAG + `⚠️ 图片文件过大 (${fileSize} bytes)，最大限制 ${MAX_SIZE} bytes`);
        fs.closeSync(file);
        return null;
      }
      
      // 读取文件内容
      const buffer = new ArrayBuffer(fileSize);
      const readLen = fs.readSync(file.fd, buffer);
      console.info(TAG + '✅ 文件已读取，读取字节数: ' + readLen);
      fs.closeSync(file);
      console.info(TAG + '✅ 文件已关闭');
      
      // 转换为Base64
      // 使用 util.Base64Helper 进行编码
      console.info(TAG + '开始转换为Base64...');
      const util = await import('@kit.ArkTS');
      const base64Helper = new util.util.Base64Helper();
      const uint8Array = new Uint8Array(buffer);
      const base64String = base64Helper.encodeToStringSync(uint8Array);
      
      console.info(TAG + `✅ 图片已转换为Base64`);
      console.info(TAG + `Base64长度: ${base64String.length} 字符`);
      console.info(TAG + `Base64前100字符: ${base64String.substring(0, 100)}`);
      console.info(TAG + '=== readImageToBase64 完成 ===');
      return base64String;
    } catch (err) {
      console.error(TAG + '❌ 读取图片转Base64失败: ' + JSON.stringify(err));
      return null;
    }
  }

  /**
   * @deprecated 已废弃，请使用头像ID方案
   * 将Base64字符串转换为可用于Image组件显示的Data URL格式。
   * 
   * @param base64 Base64字符串
   * @param mimeType MIME类型，默认为 image/jpeg
   * @returns string Data URL格式的字符串
   */
  static base64ToDataURL(base64: string, mimeType: string = 'image/jpeg'): string {
    console.info(TAG + '=== base64ToDataURL ===');
    console.info(TAG + '输入Base64长度: ' + (base64 ? base64.length : 0));
    console.info(TAG + 'MIME类型: ' + mimeType);
    
    if (!base64 || base64.length === 0) {
      console.error(TAG + '❌ Base64为空');
      return '';
    }
    
    const dataUrl = `data:${mimeType};base64,${base64}`;
    console.info(TAG + '✅ Data URL已生成');
    console.info(TAG + 'Data URL前100字符: ' + dataUrl.substring(0, 100));
    return dataUrl;
  }

  /**
   * 压缩图片并转换为Base64字符串。
   * 用于发送消息时携带头像数据，确保Base64长度不超过限制。
   * 
   * @param imagePath 图片文件路径
   * @param maxWidth 最大宽度，默认200像素
   * @param maxHeight 最大高度，默认200像素
   * @param quality JPEG质量（0-100），默认40
   * @param maxBase64Length Base64最大长度，默认45000字符
   * @returns Promise<string | null> 返回Base64字符串，null表示失败
   */
  static async compressImageToBase64(
    imagePath: string,
    maxWidth: number = 200,
    maxHeight: number = 200,
    quality: number = 40,
    maxBase64Length: number = 45000
  ): Promise<string | null> {
    console.info(TAG + '=== compressImageToBase64 开始 ===');
    console.info(TAG + `参数：imagePath=${imagePath}`);
    console.info(TAG + `参数：maxWidth=${maxWidth}, maxHeight=${maxHeight}`);
    console.info(TAG + `参数：quality=${quality}, maxBase64Length=${maxBase64Length}`);
    
    try {
      // 检查文件是否存在
      if (!ToolKits.isFileExists(imagePath)) {
        console.error(TAG + '❌ 图片文件不存在: ' + imagePath);
        return null;
      }
      console.info(TAG + '✅ 文件存在');

      // 创建ImageSource
      console.info(TAG + '创建ImageSource...');
      const imageSource = image.createImageSource(imagePath);
      
      // 获取原图信息
      const imageInfo = await imageSource.getImageInfo();
      console.info(TAG + `原图尺寸：${imageInfo.size.width}x${imageInfo.size.height}`);
      
      // 计算缩放比例
      let targetWidth = imageInfo.size.width;
      let targetHeight = imageInfo.size.height;
      
      if (targetWidth > maxWidth || targetHeight > maxHeight) {
        const widthRatio = maxWidth / targetWidth;
        const heightRatio = maxHeight / targetHeight;
        const ratio = Math.min(widthRatio, heightRatio);
        
        targetWidth = Math.round(targetWidth * ratio);
        targetHeight = Math.round(targetHeight * ratio);
        console.info(TAG + `缩放后尺寸：${targetWidth}x${targetHeight}`);
      } else {
        console.info(TAG + '原图尺寸已在限制内，无需缩放');
      }
      
      // 创建PixelMap（指定目标尺寸）
      console.info(TAG + '创建PixelMap...');
      const decodingOptions: image.DecodingOptions = {
        desiredSize: { width: targetWidth, height: targetHeight },
        editable: true
      };
      const pixelMap = await imageSource.createPixelMap(decodingOptions);
      console.info(TAG + '✅ PixelMap创建成功');
      
      // 释放ImageSource
      imageSource.release();
      
      // 创建ImagePacker
      console.info(TAG + '创建ImagePacker...');
      const imagePacker = image.createImagePacker();
      
      // 编码为JPEG
      console.info(TAG + `编码为JPEG，质量=${quality}...`);
      const packOpts: image.PackingOption = {
        format: 'image/jpeg',
        quality: quality
      };
      
      const packedData = await imagePacker.packing(pixelMap, packOpts);
      console.info(TAG + `✅ 编码完成，数据大小：${packedData.byteLength} bytes`);
      
      // 释放资源
      imagePacker.release();
      pixelMap.release();
      
      // 转换为Base64
      console.info(TAG + '转换为Base64...');
      const util = await import('@kit.ArkTS');
      const base64Helper = new util.util.Base64Helper();
      const uint8Array = new Uint8Array(packedData);
      let base64String = base64Helper.encodeToStringSync(uint8Array);
      
      console.info(TAG + `✅ Base64转换完成，长度：${base64String.length} 字符`);
      
      // 检查Base64长度是否超过限制
      if (base64String.length > maxBase64Length) {
        console.warn(TAG + `⚠️ Base64长度(${base64String.length})超过限制(${maxBase64Length})，进一步压缩...`);
        
        // 进一步降低质量
        let currentQuality = quality;
        while (base64String.length > maxBase64Length && currentQuality > 10) {
          currentQuality -= 10;
          console.info(TAG + `降低质量至 ${currentQuality}...`);
          
          // 重新解码和编码
          const newImageSource = image.createImageSource(packedData);
          const newPixelMap = await newImageSource.createPixelMap({ editable: true });
          const newImagePacker = image.createImagePacker();
          const newPackOpts: image.PackingOption = {
            format: 'image/jpeg',
            quality: currentQuality
          };
          
          const newPackedData = await newImagePacker.packing(newPixelMap, newPackOpts);
          newImagePacker.release();
          newPixelMap.release();
          newImageSource.release();
          
          const newUint8Array = new Uint8Array(newPackedData);
          base64String = base64Helper.encodeToStringSync(newUint8Array);
          
          console.info(TAG + `新Base64长度：${base64String.length} 字符`);
        }
        
        if (base64String.length > maxBase64Length) {
          console.error(TAG + `❌ 即使质量降至${currentQuality}，Base64长度仍超过限制`);
          return null;
        }
      }
      
      console.info(TAG + `✅ 最终Base64长度：${base64String.length} 字符`);
      console.info(TAG + '=== compressImageToBase64 完成 ===');
      return base64String;
    } catch (err) {
      console.error(TAG + '❌ 压缩图片失败: ' + JSON.stringify(err));
      if (err instanceof Error) {
        console.error(TAG + '错误堆栈: ' + err.stack);
      }
      return null;
    }
  }

  /**
   * @deprecated 已废弃，请使用头像ID方案
   * 压缩头像并转换为Base64字符串（强压缩方案）。
   * 专门用于发送消息时携带头像数据，确保Base64长度控制在10KB以内。
   * 
   * 压缩策略：
   * 1. 目标分辨率：100x100像素
   * 2. JPEG质量：40%
   * 3. 如果Base64长度仍超过12000，则进一步降低质量至30%或缩小尺寸至80x80
   * 
   * @param imagePath 图片文件路径
   * @returns Promise<string> 返回Base64字符串，空字符串表示失败
   */
  static async compressAvatarToBase64(imagePath: string): Promise<string> {
    console.info(TAG + '=== compressAvatarToBase64 开始（强压缩方案）===');
    console.info(TAG + `文件路径: ${imagePath}`);
    
    try {
      // 检查文件是否存在
      if (!ToolKits.isFileExists(imagePath)) {
        console.error(TAG + '❌ 头像文件不存在: ' + imagePath);
        return '';
      }
      
      // 获取原文件大小
      const stat = fs.statSync(imagePath);
      const originalFileSize = stat.size;
      console.info(TAG + `原文件大小: ${originalFileSize} bytes (${(originalFileSize / 1024).toFixed(2)} KB)`);
      
      // 创建ImageSource
      console.info(TAG + '创建ImageSource...');
      const imageSource = image.createImageSource(imagePath);
      
      // 获取原图信息
      const imageInfo = await imageSource.getImageInfo();
      console.info(TAG + `原图尺寸：${imageInfo.size.width}x${imageInfo.size.height}`);
      
      // 第一次压缩：100x100，质量40
      let targetWidth = 100;
      let targetHeight = 100;
      let quality = 40;
      
      console.info(TAG + `第一次压缩：${targetWidth}x${targetHeight}，质量${quality}...`);
      
      // 创建PixelMap（使用RGB_565格式节省内存）
      const decodingOptions: image.DecodingOptions = {
        desiredSize: { width: targetWidth, height: targetHeight },
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGB_565
      };
      const pixelMap = await imageSource.createPixelMap(decodingOptions);
      console.info(TAG + '✅ PixelMap创建成功');
      
      // 释放ImageSource
      imageSource.release();
      
      // 创建ImagePacker
      const imagePacker = image.createImagePacker();
      
      // 编码为JPEG
      const packOpts: image.PackingOption = {
        format: 'image/jpeg',
        quality: quality
      };
      
      let packedData = await imagePacker.packing(pixelMap, packOpts);
      console.info(TAG + `✅ 第一次编码完成，数据大小：${packedData.byteLength} bytes`);
      
      // 转换为Base64
      const util = await import('@kit.ArkTS');
      const base64Helper = new util.util.Base64Helper();
      let uint8Array = new Uint8Array(packedData);
      let base64String = base64Helper.encodeToStringSync(uint8Array);
      
      console.info(TAG + `第一次压缩后Base64长度：${base64String.length} 字符`);
      
      // 检查Base64长度是否超过12000（12KB）
      if (base64String.length > 12000) {
        console.warn(TAG + `⚠️ Base64长度(${base64String.length})超过12000，进行二次压缩...`);
        
        // 释放资源
        imagePacker.release();
        pixelMap.release();
        
        // 第二次压缩：降低质量至30%
        quality = 30;
        console.info(TAG + `第二次压缩：质量降至${quality}...`);
        
        const imageSource2 = image.createImageSource(imagePath);
        const pixelMap2 = await imageSource2.createPixelMap({
          desiredSize: { width: targetWidth, height: targetHeight },
          editable: true,
          desiredPixelFormat: image.PixelMapFormat.RGB_565
        });
        imageSource2.release();
        
        const imagePacker2 = image.createImagePacker();
        const packOpts2: image.PackingOption = {
          format: 'image/jpeg',
          quality: quality
        };
        
        packedData = await imagePacker2.packing(pixelMap2, packOpts2);
        console.info(TAG + `✅ 第二次编码完成，数据大小：${packedData.byteLength} bytes`);
        
        uint8Array = new Uint8Array(packedData);
        base64String = base64Helper.encodeToStringSync(uint8Array);
        
        console.info(TAG + `第二次压缩后Base64长度：${base64String.length} 字符`);
        
        imagePacker2.release();
        pixelMap2.release();
        
        // 如果仍然超过12000，进行第三次压缩：缩小尺寸至80x80
        if (base64String.length > 12000) {
          console.warn(TAG + `⚠️ Base64长度(${base64String.length})仍超过12000，进行第三次压缩...`);
          
          targetWidth = 80;
          targetHeight = 80;
          console.info(TAG + `第三次压缩：${targetWidth}x${targetHeight}，质量${quality}...`);
          
          const imageSource3 = image.createImageSource(imagePath);
          const pixelMap3 = await imageSource3.createPixelMap({
            desiredSize: { width: targetWidth, height: targetHeight },
            editable: true,
            desiredPixelFormat: image.PixelMapFormat.RGB_565
          });
          imageSource3.release();
          
          const imagePacker3 = image.createImagePacker();
          const packOpts3: image.PackingOption = {
            format: 'image/jpeg',
            quality: quality
          };
          
          packedData = await imagePacker3.packing(pixelMap3, packOpts3);
          console.info(TAG + `✅ 第三次编码完成，数据大小：${packedData.byteLength} bytes`);
          
          uint8Array = new Uint8Array(packedData);
          base64String = base64Helper.encodeToStringSync(uint8Array);
          
          console.info(TAG + `第三次压缩后Base64长度：${base64String.length} 字符`);
          
          imagePacker3.release();
          pixelMap3.release();
        }
      } else {
        // 释放资源
        imagePacker.release();
        pixelMap.release();
      }
      
      // 最终检查
      if (base64String.length > 15000) {
        console.error(TAG + `❌ 最终Base64长度(${base64String.length})仍超过15000，放弃携带头像`);
        return '';
      }
      
      console.info(TAG + `✅ 最终Base64长度：${base64String.length} 字符`);
      console.info(TAG + `压缩比：${((1 - base64String.length / (originalFileSize * 1.37)) * 100).toFixed(1)}%`);
      console.info(TAG + '=== compressAvatarToBase64 完成 ===');
      
      return base64String;
    } catch (err) {
      console.error(TAG + '❌ 压缩头像失败: ' + JSON.stringify(err));
      if (err instanceof Error) {
        console.error(TAG + '错误堆栈: ' + err.stack);
      }
      return '';
    }
  }
}