// @keepTs
// @ts-nocheck
import Protocal from "../o/z";
/**
 * QoS机制中提供对已收到包进行有限生命周期存储并提供重复性判断的定时器。
 *
 * 【原理是】：当收到需QoS机制支持消息包时，会把它的唯一特征码（即指纹id）存放于本类的“已收到”消息队列中，寿命约为
 *  {@link MESSAGES_VALID_TIME}指明的时间，每当{@link CHECH_INTERVAL}定时检查间隔到来时会对其存活期进行检查，
 *  超期将被移除，否则允许其继续存活。理论情况下，一个包的最大寿命不可能超过2倍的 {@link #CHECH_INTERVAL}时长。
 *
 * 【补充说明】：“超期”即意味着对方要么已收到应答包（这是QoS机制正常情况下的表现）而无需再次重传、要么是
 * 已经达到QoS机制的重试极限而无可能再收到重复包（那么在本类列表中该表也就没有必要再记录了）。总之，“超期”是队列中
 * 这些消息包的正常生命周期的终止，无需过多解读。
 *
 * 【本类存在的意义在于】：极端情况下QoS机制中存在因网络丢包导致应答包的丢失而触发重传机制从而导致消息重复，而本
 * 类将维护一个有限时间段内收到的所有需要QoS支持的消息的指纹列表且提供“重复性”判断机制，从而保证应用层绝不会因为QoS
 * 的重传机制而导致重复收到消息的情况。
 *
 * 当前MobileIMSDK的QoS机制支持全部的C2C、C2S、S2C共3种消息交互场景下的消息送达质量保证.
 *
 * 【注意】：本定时器的启停，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
 *
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 */
export default class QoS4ReciveDaemon {
    /** 本类的全局单例 */
    private static instance;
    /** true表示开启 Debug信息的输出，否则关闭。默认为true. */
    static DEBUG: boolean;
    private static readonly CHECH_INTERVAL;
    /** 一个消息放到在列表中（用于判定重复时使用）的生存时长（单位：毫秒），默认10分钟 */
    private static readonly MESSAGES_VALID_TIME;
    /** 保存setInverval(...)定时器id（此id方便用于关闭定时时使用）*/
    private _intervalId;
    private readonly recievedMessages;
    private _excuting;
    /**
     * 获得本类的全局单例。
     *
     * @returns QoS4ReciveDaemon 单例
     */
    static getInstance(): QoS4ReciveDaemon;
    /**
     * 执行业务逻辑（此函数由框架内部调用，开发者无需使用）。
     */
    private excute;
    /**
     * 启动定时器。
     *
     * 无论本方法调用前线程是否已经在运行中，都会尝试首先调用 {@link stop()}方法，以便确保线程被启动前是真正处
     * 于停止状态，这也意味着可无害调用本方法。
  
     * 本线程的启停，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
     *
     * @param immediately true表示立即执行线程作业，否则直到 {@link CHECH_INTERVAL}执行间隔的到来才进行首次作业的执行
     */
    startup(immediately: boolean): void;
    /**
     * 无条件中断本线程的运行。
     *
     * 本线程的启停，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
     */
    stop(): void;
    /**
     * 向列表中加入一个包的特征指纹。
     * 注意：本方法只会将指纹码推入，而不是将整个Protocal对象放入列表中。
     *
     * 本方法的调用，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
     *
     * @param p Protocal对象
     */
    addRecievedProtocal(p: Protocal): void;
    /**
     * 向列表中加入一个包的特征指纹。
     *
     * 本方法的调用，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
     *
     * @param fingerPrintOfProtocal 消息包的特纹特征码（理论上是唯一的）
     */
    addRecieved(fingerPrintOfProtocal: string): void;
    private putImpl;
    /**
     * 指定指纹码的Protocal是否已经收到过.
     *
     * 此方法用于QoS机制中在防止因网络丢包导致对方未收到应答时而再次发送消息从而导致消息重复时的判断依赖.
     *
     * @param fingerPrintOfProtocal 消息包的特纹特征码（理论上是唯一的）
     * @return true表示是，否则不是
     */
    hasRecieved(fingerPrintOfProtocal: string): boolean;
    /**
     * 清空缓存队列。
     *
     * 调用此方法可以防止在客户端不退出的情况下退出登陆MobileIMSDK时没有清除队列缓存，导致此时换用另一账号时发生数据交叉。
     */
    clear(): void;
    /**
     * 当前“已收到消息”队列列表的大小.
     *
     * @return 列表大小
     */
    size(): number;
}
