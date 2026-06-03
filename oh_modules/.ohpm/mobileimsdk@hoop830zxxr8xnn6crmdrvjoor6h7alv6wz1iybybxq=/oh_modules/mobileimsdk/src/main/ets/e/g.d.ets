// @keepTs
// @ts-nocheck
/**
 * 用于保持与服务端通信活性的Keep alive心跳机制实现类（含 心跳包发送定时器 + 心跳超时检查定时器）。
 *
 * Keep alive的技术实现原理：
 * 1、心跳包发送定时器：独立定时向服务端发送心跳包，不参与其它更多逻辑；
 * 2、心跳超时检查定时器：独立检查服务端发过来的心跳响应超时时间，不参与其它更多逻辑，工作逻辑是定时检查，当
 *    {@link lastGetKeepAliveResponseFromServerTimstamp}超过{@link NETWORK_CONNECTION_TIME_OUT}
 *    超时阀值，将认为网络不同——随即让SDK进入掉线处理逻辑；
 * 3、服务端心跳响应：服务端回过来的心跳响应时，将更新本类中的 {@link lastGetKeepAliveResponseFromServerTimstamp}
 *    字段，用于更新"最近一次服务端的心跳响应包时间"，以便"2"中判断心跳响应超时的依据。
 *
 * Keep alive的目的有2个：
 * 1、防止NAT路由算法导致的端口老化：
 *    路由器的NAT路由算法存在所谓的“端口老化”概念，请参见文章：http://www.52im.net/thread-209-1-1.html。
 * 2、即时探测由于网络状态的变动而导致的通信中断</u>（进而自动触发自动治愈机制）：
 *     此种情况可的原因有（但不限于）：无线网络信号不稳定、WiFi与2G/3G/4G/5G等同开情况下的网络切换、网络连接正常但宽
 *     带欠费被停机、手机系统的省电策略等。
 *
 * 本线程的启停，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
 *
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 * @version 1.0
 */
export default class KeepAliveDaemon {
    /** 本类的全局单例 */
    private static instance;
    /** true表示开启心跳连线程的 Debug信息的输出，否则关闭。默认为true. */
    static DEBUG: boolean;
    /**
     * Keep Alive 心跳发送时间间隔（单位：毫秒），默认5000毫秒（即5秒）.
     *
     * 心跳间隔越短则保持会话活性的健康度更佳，但将使得在大量客户端连接情况下服务端因此而增加负载，且手机将消耗更多电量和流量，所以此间隔需要权
     * 衡（建议为：大于3秒 且 小于270秒(即4分半钟) ）！
     *
     * 说明：此参数用于设定客户端发送到服务端的心跳间隔，心跳包的作用是用来保持与服务端的会话活性（更准确的说是为了避免客户端因路由器的NAT算法而
     * 导致路由器端口老化，相关知识见此文：http://www.52im.net/thread-281-1-1.html）.
     *
     * * 参定此参数的同时，也需要相应设置服务端的ServerLauncher.SESION_RECYCLER_EXPIRE参数。
     */
    static KEEP_ALIVE_INTERVAL: number;
    /**
     * 收到服务端响应心跳包的超时间时间（单位：毫秒），默认（5 * 1000 + 3000）＝ 8000 毫秒（即8秒）.
  
     * 超过这个时间客户端将判定与服务端的网络连接已断开（此间隔建议为(KEEP_ALIVE_INTERVAL * 1) + 3 秒），
     * 没有上限，但不可太长，否则将不能即时反映出与服务器端的连接断开（比如掉掉线时），请从
     * 能忍受的反应时长和即时性上做出权衡。
     *
     * 本参数除与{@link KEEP_ALIVE_INTERVAL}有关联外，不受其它设置影响。
     */
    static NETWORK_CONNECTION_TIME_OUT: number;
    /**
     * 心跳包超时检查定时器的运行间隔时间（单位：毫秒），默认（2 * 1000）＝ 2000 毫秒（即2秒）.
     *
     * 此时间将决定断网感应灵敏度。建议设置值的范围为1~5秒内。
     */
    static NETWORK_CONNECTION_TIME_OUT_CHECK_INTERVAL: number;
    /** 网络断开事件观察者 */
    networkConnectionLostCallback?: Callback<void>;
    /** 记录最近一次服务端的心跳响应包时间 */
    private lastGetKeepAliveResponseFromServerTimstamp;
    /** 心跳包发送定时器的本次执行是否还未完成（具体指的是一次完整的心跳发送逻辑的执行） */
    private keepAliveTaskExcuting;
    /** 心跳包发送定时器是否停止整个定时心跳循环 */
    private keepAliveWillStop;
    /** 保存setInverval(...)定时器id（此id方便用于关闭定时器时使用） */
    private _intervalId;
    /** 心跳包响应超时检查的独立定时器 */
    private keepAliveTimeoutTimer?;
    /**
     * 获得本类的全局单例。
     *
     * @returns KeepAliveDaemon 单例
     */
    static getInstance(): KeepAliveDaemon;
    constructor();
    /**
     * 执行业务逻辑（此函数由框架内部调用，开发者无需使用）。
     *
     * @see doKeepAlive()
     * @see onKeepAlive()
     */
    private excute;
    /**
     * 发送心跳指令（此函数由框架内部调用，开发者无需使用）。
     *
     * @return 返回指令发送结果码
     */
    private doKeepAlive;
    /**
     * 心跳指令发送完成后的回调处理（此函数由框架内部调用，开发者无需使用）。
     *
     * @param code 前一步的指令发送结果码
     */
    private onKeepAlive;
    /**
     * 心跳包响应超时检查。
     */
    private doTimeoutCheck;
    /**
     * 是否是首先执行Keep Alive心跳包发送。
     *
     * @return true表示是，false表示不是
     */
    private isInitialedForKeepAlive;
    /**
     * 心跳线程算法已判定需要与服务器的“通信通道”断开，调用此方法将进入框架的“通信通道”断开处理逻辑。
     *
     * 注意：本方法，目前属于MobileIMSDK框架算法的一部分，暂时无需也不建议由应用层开发者自行调用。
     */
    notifyConnectionLost(): void;
    /**
     * 启动线程。
     *
     * 无论本方法调用前线程是否已经在运行中，都会尝试首先调用 {@link #stop()}方法，以便确保线程被启动前是真正处
     * 于停止状态，这也意味着可无害调用本方法。
     *
     * 注意：本线程的启停，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
     *
     * @param immediately true表示立即执行线程作业，否则直到 {@link #KEEP_ALIVE_INTERVAL}执行间隔的到来才进行首次作业的执行。
     */
    start(immediately: boolean): void;
    /**
     * 无条件中断本线程的运行。
     *
     * 注意：本线程的启停，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
     */
    stop(): void;
    /**
     * 收到服务端反馈的心跳包时调用此方法：作用是更新服务端最后的响应时间戳.
     *
     * 注意：本方法的调用，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
     */
    updateGetKeepAliveResponseFromServerTimstamp(): void;
}
