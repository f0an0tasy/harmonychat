// @keepTs
// @ts-nocheck
/**
 * 与服务端通信中断后的自动登陆（重连）定时器管理类。
 *
 * 鉴于无线网络的不可靠性和特殊性，移动端的即时通讯经常存在网络通信断断续续的状况，可能的原因有（但不限于）：无线网
 * 络信号不稳定、WiFi与2G/3G/4G/5G等同开情况下的网络切换、手机系统的省电策略等。这就使得即时通信框架拥有对上层透明且
 * 健壮的健康度探测和自动治愈机制非常有必要。
 *
 * 本类的存在使得MobileIMSDK框架拥有通信自动治愈的能力。
 *
 * 注意：自动登陆（重连）只可能发生在登陆成功后与服务端的网络通信断开时。
 *
 * 本线程的启停，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
 *
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 * @version 1.0
 * @see LocalDataSender.SendLoginDataAsync
 */
export default class AutoReLoginDaemon {
    private static instance;
    /** true表示开启自动重连线程的 Debug信息的输出，否则关闭。默认为true. */
    static DEBUG: boolean;
    /**
     * 自动重新登陆时间间隔（单位：毫秒），默认3000毫秒。
     * 此参数只会影响断线后与服务器连接的即时性，不受任何配置参数的影响。请基于重连（重登陆）即时性和手机能耗上作出权衡。
     * 除非对MobileIMSDK的整个即时通讯算法非常了解，否则请勿尝试单独设置本参数。如需调整心跳频率请见 SenseMode.setSenceMode()。
     *
     * @see SenceMode.setSenseMode()
     */
    static AUTO_RE$LOGIN_INTERVAL: number;
    /** 本次执行是否还未完成 */
    private _excuting;
    /** 保存setInverval(...)定时器id（此id方便用于关闭定时器时使用）*/
    private _intervalId;
    /**
     * 获得本类的全局单例。
     *
     * @returns AutoReLoginDaemon单例
     */
    static getInstance(): AutoReLoginDaemon;
    /**
     * 执行业务逻辑（此函数由框架内部调用，开发者无需使用）。
     *
     * @see doSendLogin()
     * @see onSendLogin()
     */
    private excute;
    /**
     * 发送登陆指令（此函数由框架内部调用，开发者无需使用）。
     *
     * @return 返回指令发送结果码（见 {@link ErrorCode} 对象中的常量定义）
     */
    private doSendLogin;
    /**
     * 登陆指令发出后的回调处理（此函数由框架内部调用，开发者无需使用）。
     *
     * @param code 前一步的指令发送结果码
     * @see doSendLogin()
     */
    private onSendLogin;
    /**
     * 启动自动登陆。
     * 无论本方法调用前线程是否已经在运行中，都会尝试首先调用 {@link stop()}方法，以便确保线程被启动前是真正处于停止状态，这也意味着可无害调用本方法。
     * 本线程的启停，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
     *
     * @param immediately true表示立即执行线程作业，否则直到 {@link AUTO_RE$LOGIN_INTERVAL} 执行间隔的到来才进行首次作业的执行
     */
    start(immediately: boolean): void;
    /**
     * 无条件中断本线程的运行。
     * 本线程的启停，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
     */
    stop(): void;
}
