// @keepTs
// @ts-nocheck
import Protocal from "../o/z";
/**
 * QoS机制中提供消息送达质量保证的定时器实现类。
 *
 * 本类是QoS机制的核心，目的是加强保证TCP协议在应用层的可靠性和送达率。
 *
 * TCP理论上能从底层保证数据的可靠性，但应用层的代码和场景中存在网络本身和网络之外的各种不可靠性，
 * MobileIMSDK中的QoS送达保证机制，将加强TCP的可靠性，确保消息，无法从哪一个层面和维度，都会给
 * 开发者提供两种结果：要么明确被送达（即收到ACK应答包，见
 *  {@link net.x52im.mobileimsdk.android.event.MessageQoSEvent#messagesBeReceived(String)}）、要行明确
 *  未被送达（见{@link net.x52im.mobileimsdk.android.event.MessageQoSEvent#messagesLost(ArrayList)}）。从理论上，保证消息的百分百送达率。
 *
 * 【一个有趣的问题】：TCP协议为什么还需要消息送达保证机制？它不是可靠的吗？
 * 是的，TCP是可靠的，但那是在底层协议这一层。但对于应用层来说，TCP并不能解决消息的百分百可靠性。
 * 原因有可能是：
 *   1）客户端意外崩溃导致TCP缓冲区消息丢失；
 *   2）网络拥堵，导致TCP反复重传并指数退避，导致长时间无法送达的也应在送达超时时间内被判定为无法送达（对于应用层
 *      来说tcp传的太慢，用户不可能等的了这么久，否则体验会很差）；
 *   3）中间路由故障，tcp本身是无法感知的，这种情况下tcp做传输重试也会出现2）中的情况，这也应算是事实上的无法送达；
 *   4）其它更多情况。
 *
 * 当前MobileIMSDK的QoS机制支持全部的C2C、C2S、S2C共3种消息交互场景下的消息送达质量保证.
 *
 * 注意：本线程的启停，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
 *
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 */
export default class QoS4SendDaemon {
    /** 本类的全局单例 */
    private static instance;
    /** true表示开启 Debug信息的输出，否则关闭。默认为true. */
    static DEBUG: boolean;
    private static readonly CHECH_INTERVAL;
    private static readonly MESSAGES_JUST$NOW_TIME;
    private static readonly QOS_TRY_COUNT;
    /** 本Map表目前用于缓存一段时间内的已发送消息，<key=String, value=Protocal> */
    private readonly sentMessages;
    /** 本Map表目前仅用于QoS重传判断是否是“刚刚”发出的消息之用（别无它用），<key=String, value=long> */
    private readonly sendMessagesTimestamp;
    /** 本次执行是否还未完成（内部变量，开发者无需理会） */
    private _excuting;
    /** 保存setInverval(...)定时器id（此id方便用于关闭定时器时使用）*/
    private _intervalId;
    /**
     * 获得本类的全局单例。
     *
     * @returns QoS4SendDaemon 单例
     */
    static getInstance(): QoS4SendDaemon;
    /**
     * 执行业务逻辑（此函数由框架内部调用，开发者无需使用）。
     *
     * @see onRetryCheck()
     * @see doRetryCheck()
     */
    private excute;
    /**
     * 重传检查（此函数由框架内部调用，开发者无需使用）。
     *
     * @param lostMessages 被判定为丢包的数组对象引用
     * @return 已被判定为“消息未送达”的消息列表
     */
    private doRetryCheck;
    /**
     * 重传检查完成后的回调处理（此函数由框架内部调用，开发者无需使用）。
     *
     * @param al 已被判定为“消息未送达”的消息列表
     */
    private onRetryCheck;
    /**
     * 将未送达信息反馈给消息监听者。
     *
     * @param lostMessages 已被判定为“消息未送达”的消息列表
     */
    notifyMessageLost(lostMessages: Protocal[]): void;
    /**
     * 启动线程。
     *
     * 无论本方法调用前线程是否已经在运行中，都会尝试首先调用 {@link stop()}方法，以便确保线程被启动前是真正处于停止状态，这也
     * 意味着可无害调用本方法。
     *
     * 注意：本线程的启停，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
     *
     * @param immediately true表示立即执行线程作业，否则直到 {@link #CHECH_INTERVAL}执行间隔的到来才进行首次作业的执行
     */
    startup(immediately: boolean): void;
    /**
     * 无条件中断本线程的运行。
     *
     * 注意：本线程的启停，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
     */
    stop(): void;
    /**
     * 该包是否已存在于队列中。
     *
     * @param fingerPrint {String} 消息包的特纹特征码（理论上是唯一的）
     * @return true表示是，否则不是
     */
    exist(fingerPrint: string): boolean;
    /**
     * 推入一个消息包的指纹特征码.
     * 注意：本方法只会将指纹码推入，而不是将整个Protocal对象放入列表中。
     *
     * @param p Protocal对象
     */
    put(p: Protocal): void;
    /**
     * 移除一个消息包.
     *
     * 此操作是在步异线程中完成，目的是尽一切可能避免可能存在的阻塞本类中的守护线程.
     *
     * @param fingerPrint 消息包的特纹特征码（理论上是唯一的）
     */
    remove(fingerPrint: string): void;
    /**
     * 清空缓存队列。
     *
     * 调用此方法可以防止在APP不退出的情况下退出登陆MobileIMSDK时没有清除队列缓存，导致此时换用另一账号时发生数据交叉。
     */
    clear(): void;
    /**
     * 队列大小.
     *
     * @return 队列大小
     */
    size(): number;
}
