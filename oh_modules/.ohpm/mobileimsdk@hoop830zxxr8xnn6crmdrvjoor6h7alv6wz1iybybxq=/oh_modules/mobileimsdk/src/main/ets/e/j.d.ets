// @keepTs
// @ts-nocheck
import { webSocket } from '@kit.NetworkKit';
import { AsyncCallback } from '@kit.BasicServicesKit';
/**
 * 本地 Socket 实例封装实用类。
 * <br>
 * 本类提供存取本地Socket通信对象引用的方便方法，封装了Socket有效性判断以及异常处理等，以便确保调用者通过
 * 方法 {@link getLocalSocket()}拿到的Socket对象是健康有效的。
 * <p>
 * 依据作者对MobileIMSDK API的设计理念，本类将以单例的形式提供给调用者使用。
 *
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 * @version 1.0
 */
export default class LocalSocketProvider {
    /** true表示开启Socket操作的 Debug信息的输出，否则关闭。默认为true. */
    static DEBUG: boolean;
    /** 本类的全局单例 */
    private static instance;
    /** 本地WebSocket对象引用 */
    private localSocket?;
    private readyState;
    connectionDoneCallback?: AsyncCallback<boolean>;
    /**
     * 获得本类的全局单例。
     *
     * @returns LocalSocketProvider单例
     */
    static getInstance(): LocalSocketProvider;
    /**
     * 重置并新建一个全新的WebSocket对象。
     *
     * @return 新建的全新Socket对象引用
     */
    resetLocalSocket(): webSocket.WebSocket | undefined;
    /**
     * 尝试发起连接并获取WebSocket。
     *
     * 标准HTML5的WebSocket API文档请见：https://developer.mozilla.org/zh-CN/docs/Web/API/WebSocket
     * 鸿蒙的WebSocket API文档请见：https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-websocket-V5
     *
     * @return boolean 表示连接已发起完成
     */
    private tryConnectToHost;
    /**
     * 本类中的WebSocket对象是否是健康的。
     *
     * @return true表示是健康的，否则不是
     */
    isLocalSocketReady(): boolean;
    /**
     * 获得本地WebSocket的实例引用.
     * <p>
     * 本方法内封装了WebSocket有效性判断以及异常处理等，以便确保调用者通过本方法拿到的WebSocket对象是健康有效的。
     *
     * @return 如果该实例正常则返回它的引用，否则返回undefined
     * @see isLocalSocketReady()
     * @see resetLocalSocket()
     */
    getLocalSocket(): webSocket.WebSocket | undefined;
    /**
     * 强制关闭本地WebSocket。
     * 一旦调用本方法后，再次调用{@link #getLocalSocket()}将会返回一个全新的WebSocket对象引用。
     *
     * 本方法通常在两个场景下被调用：
     * 1) 真正需要关闭WebSocket时（如所在的浏览器退出时）；
     * 2) 当调用者检测到网络发生变动后希望重置以便获得健康的WebSocket引用对象时。
     *
     * @param silentClose true表示close前会清掉为此socket实例设置的各种回调，确保close时不会触发这些回调（比如：在
     * 掉线重连场景下，close掉前一个旧的失效socket就不会错误地触发这些回调，而且还因为close是异步的，从而会引发一系列不可预测的行为）。
     */
    closeLocalSocket(silentClose: boolean): void;
}
