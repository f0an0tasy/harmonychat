// @keepTs
// @ts-nocheck
import { common } from '@kit.AbilityKit';
import { Logger } from "./d1/f1/g1";
import PLoginInfo from "./o/p/r";
/**
 * MobileIMSDK框架的核心入口类。
 * 本类主要提供一些全局参数的读取和设置。
 *
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 * @version 1.0
 */
export default class ClientCoreSDK {
    /** 本类的全局单例 */
    private static instance;
    /** 全局日志对象 */
    static readonly Log: Logger;
    /** 要连接的WebSockcet服务端地址和端口，形如：“ws://192.168.0.113:3000/websocket” */ static websocketUrl: string;
    /** true表示开启MobileIMSDK Debug信息的输出，否则关闭。默认为true. */
    static DEBUG: boolean;
    /**
     * 是否在登陆成功后掉线时自动重新登陆线程中实质性发起登陆请求，true表示将在线程运行周期中正常发起，否则不发起（即关闭实质性的重新登陆请求）。
     * 什么样的场景下，需要设置本参数为false？比如：上层应用可以在自已的节电逻辑中控制当网络长时断开时就不需要实质性发起登陆请求了，因为 网络请求是非常耗电的。
     * 本参数的设置将实时生效。
     */
    static autoReLogin: boolean;
    /**
     * 当调用 {@link init()}方法后本字段将被置为true，调用{@link release()}时将被重新置为false.
     * 参数由框架自动设置。
     */
    private _init;
    /**
     * 是否已成功连接到服务器（当然，前提是已成功发起过登陆请求后）.
     *
     * 此“成功”意味着可以正常与服务端通信（可以近似理解为Socket正常建立），“不成功”意味着不能与服务端通信.不成功的因素有很多：比如网络不可
     * 用、网络状况很差导致的掉线、心跳超时等.
     *
     * 本参数是整个MobileIMSDK框架中唯一可作为判断与MobileIMSDK服务器的通信是否正常的准确依据。
     *
     * 本参数将在收到服务端的登陆请求反馈后被设置为true，在与服务端的通信无法正常完成时被设置为false。
     *
     * 那么MobileIMSDK如何判断与服务端的通信是否正常呢？ 判断方法如下：
     * 1）登陆请求被正常反馈即意味着通信正常（包括首次登陆时和断掉后的自动重新时）；
     * 2）首次登陆或断线后自动重连时登陆请求被发出后，没有收到服务端反馈时即意味着不正常；
     * 3）与服务端通信正常后，在规定的超时时间内没有收到心跳包的反馈后即意味着与服务端的通信又中断了（即所谓的掉线）。
     *
     * 本参数由框架自动设置。
     */
    connectedToServer: boolean;
    /**
     * 当且仅当用户从登陆界面成功登陆后设置本字段为true，系统退出（登陆）时设置为false。
     * 本参数由框架自动设置。
     */
    loginHasInit: boolean;
    /**
     * 保存提交到服务端的用户登陆信息，可能是登陆用户名、任意不重复的id等，具体意义由业务层决定。
     *
     * 本字段在登陆信息成功发出后就会被设置，将在掉线后自动重连时使用。
     * 因不保证服务端正确收到和处理了该用户的登陆信息，所以本字段因只在{@link connectedToServer}==true 时才有意义.
     * 本参数由框架自动设置。
     */
    currentLoginInfo?: PLoginInfo;
    /** EventHub订阅器对象 */
    private eventHub?;
    /** 本地手机网络对象（用于监听本地移动网络状态变化） */
    private phoneNetCon?;
    /**
     * 获得本类的全局单例。
     *
     * @returns ClientCoreSDK单例
     */
    static getInstance(): ClientCoreSDK;
    /**
     * 初始化核心库.
     * 注意：不同于MobileIMSDK的iOS和Java客户端，本方法需要由开发者调用，以确保MobileIMSDK核心已被初始化完成。
     *
     * 本方法被调用后， {@link isInitialed()}将返回true，否则返回false。
     *
     * 注意：因鸿蒙系统在处理网络变动广播事件的特殊性，本方法应在MobileIMSDK的登陆信息被发出前已被开发者调用完成。且越早被调用越好（
     * 如放在EntryAbility的onCreate()方法中或者登陆LoginPage的onCreate()方法中）
     */
    init(eventHub: common.EventHub): void;
    /**
     * 释放MobileIMSDK框架资源统一方法。
     *
     * 本方法建议在退出登陆（或退出APP时）时调用。调用时将尝试关闭所有MobileIMSDK框架的后台守护线程并同设置核心框架init=false、
     * {@link loginHasInit}=false、{@link connectedToServer}=false。
     *
     * @see AutoReLoginDaemon.stop()
     * @see QoS4SendDaemon.stop()
     * @see KeepAliveDaemon.stop()
     * @see QoS4ReciveDaemon.stop()
     * @see LocalSocketProvider.closeLocalSocket()
     */
    release(): void;
    /**
     * 用于首次登陆成功后，保存服务端返回的登陆时间（此时间将会随着完整登陆信息，在掉线重连时再次提交到服务端，服务端可据此时间精确判定在多端、网
     * 络复杂性的情况下的互踢逻辑）。
     *
     * @param firstLoginTime 服务端返回的首次登陆时间（此时间为形如“1624333553769”的Java时间戳）
     */
    saveFirstLoginTime(a1: number): void;
    /**
     * 返回EventHub订阅器对象。
     *
     * @returns EventHub订阅器对象
     */
    getEventHub(): common.EventHub;
    /**
     * 订阅本地移动网络状态变化。
     *
     * 接收本地网络状态变更的目的在于解决当正常的连接因本地网络改变（比如：网络断开了后，又连上了）而无法再次正常发送数据的问题（即使网络恢复后）
     * ，解决的方法是：当检测到本地网络断开后就立即关停本地Socket，这样当下次重新登陆或尝试发送数据时就会重新建立Socket从而达到重置Socket的目
     * 的，Socket重置后也就解决了这个问题。
     */
    private useNetworkRegister;
    /**
     * 取消订阅本地移动网络状态变化。
     */
    private unUseNetworkRegister;
    /**
     * MobileIMSDK的核心框架是否已经初始化.
     * 当调用 {@link ClientCoreSDK.init()}方法后本字段将被置为true，调用{@link release()}时将被重新置为false.
     * 本参数由框架自动设置。
     */
    isInitialed(): boolean;
}
