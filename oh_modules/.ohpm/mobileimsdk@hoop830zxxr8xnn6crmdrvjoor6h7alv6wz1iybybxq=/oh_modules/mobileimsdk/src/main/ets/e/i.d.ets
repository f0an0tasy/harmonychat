// @keepTs
// @ts-nocheck
import Protocal from "../o/z";
import PLoginInfo from "../o/p/r";
/**
 * 数据发送处理实用类。
 * 本类是MobileIMSDK框架的唯一提供数据发送的公开实用类。
 *
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 * @version 1.0
 */
export default class LocalDataSender {
    /** 本类的全局单例 */
    private static instance;
    /** true表示开启数据发送的 Debug信息的输出，否则关闭。默认为true. */
    static DEBUG: boolean;
    /**
     * 获得本类的全局单例。
     *
     * @returns LocalDataSender单例
     */
    static getInstance(): LocalDataSender;
    /**
     * 发送登陆(连接)信息给服务端。
     *
     * @param loginInfo登陆信息各字段定义见：http://docs.52im.net/extend/docs/api/mobileimsdk/server_tcp/net/x52im/mobileimsdk/server/protocal/c/PLoginInfo.html
     * @return 0表示数据发出成功，否则返回的是错误码，see {@link ErrorCode}
     * @see sendLoginImpl()
     */
    sendLogin(loginInfo: PLoginInfo | undefined): number;
    /**
     * 发送登陆指令的真正实现函数。
     * 提示：本函数由 {@link sendLogin()}函数调用，一般不单使用。
     *
     * 【注意】：本库的客户端启动入口就是登陆过程触发的，因而要使本库能正常工作，请确保首先进行登陆操作（其内部实现包括：WebSocket首次连接建立、认证指令发出）。
     *
     * @param loginInfo 登陆信息各字段定义见：http://docs.52im.net/extend/docs/api/mobileimsdk/server_tcp/net/x52im/mobileimsdk/server/protocal/c/PLoginInfo.html
     * @return 0表示数据发出成功，否则返回的是错误码，see {@link ErrorCode}
     */
    private sendLoginImpl;
    /**
     * 发送注销登陆信息.
     *
     * 【注意】：此方法的调用将被本库理解为退出库的使用，本方法将会额外调用资源释放方法{@link MBCore#release()}，以保证资源释放。
     * 【提示】：本方法调用后，除非再次进行登陆过程，否则核心库将处于初始未初始化状态。
     *
     * @return 0表示数据发出成功，否则返回的是错误码，see {@link ErrorCode}
     */
    sendLoginout(): number;
    /**
     * 发送Keep Alive心跳包.
     *
     * @return 0表示数据发出成功，否则返回的是错误码，see {@link ErrorCode}
     */
    sendKeepAlive(): number;
    /**
     * 通用数据的发送根方法。
     *
     * @param dataContentWidthStr 要发送的数据内容（字符串方式组织）
     * @param to_user_id 要发送到的目标用户id
     * @param QoS true表示需QoS机制支持，不则不需要
     * @param fingerPrint QoS机制中要用到的指纹码（即消息包唯一id），可设为null，生成方法见 {@link Protocal.genFingerPrint()}
     * @param typeu 应用层专用字段——用于应用层存放聊天、推送等场景下的消息类型。注意：此值为-1时表示未定义。MobileIMSDK框架中，本字段为保留字段，不参与框架的核心算法，专留作应用层自行定义和使用
     * @return 0表示数据发出成功，否则返回的是错误码，see {@link ErrorCode}
     * @see sendCommonData(Protocal)
     * @see ProtocalFactory.createCommonData(string, string, string, boolean, string, number)
     */
    sendCommonDataPlain(dataContentWidthStr: string, to_user_id: string, QoS?: boolean, fingerPrint?: string, typeu?: number): number;
    /**
     * 通用数据协议包的发送根方法。
     *
     * @param p 要发送的内容（MobileIMSDK框架的“协议”DTO对象组织形式）
     * @return 0表示数据发出成功，否则返回的是错误码，see {@link ErrorCode}
     * @see send()
     */
    sendCommonData(p: Protocal): number;
    /**
     * 发送数据到服务端.
     *
     * 【注意】：直接调用此方法将无法支持QoS质量保证哦！
     * 【提示】：本函数由本类中的 sendXXXX() 函数调用，一般不单开放给外部类使用。
     *
     * @param dataWithString {@link Protocal} 对象转成JSON后的字符串
     * @return 0表示数据发出成功，否则返回的是错误码 {@link ErrorCode}
     */
    private send;
    /**
     * 发送一条WebSocket消息。
     *
     * *********************************************************************************************
     * 特别说明：想要确切知道本方法的数据发送成功与否怎么办？
     *  1）通过 #resultCallback 参数指明的观察者接收数据发送结果，可以准确得知数据是否发送成功（准确地是说是数据是否被成功写入tcp缓冲区）；
     *  2）通过本方法的返回值，可以准确得知数据是否发送失败，但理论上无法百分百得知数据是否发送成功（准确地是说是数据是否被成功写入tcp缓冲区），
     *      因为websocket api的异步特性，是否成功需通过 #resultCallback 参数指明的观察者来得到结果。
     *
     * 我的建议：
     *  1）当你的场景下，需要准确得知发送结果时，请使用 #resultCallback 参数来获取发送结果；
     *  2）当你的场景下，不一定需要准确得到发送结果时，可以直接用返回值（代码写起来比用观察者回调的方式要简单嘛），主流的im比如qq、微信、以及基于
     *      MobileIMSDK的im产品RainbowChat，由于存在消息送达保证机制，所以应用层只管发送，至于能不能准确获得发送结果，没有关系，因为在没有收到
     *      对方的ACK应答时，界面上的消息发送进度指示（菊花）会一直在转，余下的逻辑由QoS机制去判定消息被收到或没收到，不会受本方法的发送结果影响。
     *
     * @param ws 鸿蒙的WebSocket对象引用
     * @param dataWithString 要发送的数据文本
     * @param resultCallback 数据发送结果回调。对于WebSocket来说，通过此异步回调通知，可以真正知道数据发送是否成功
     * @return false表示数据发送时出错了（发送失败），理论上说true只代表没有发送失败但不代表一定发送成功（严格意义上的
     *         发送成功与否的结果，请使用 #resultCallback 参数设置观察者来实现结果通知，因为鸿蒙的WebSocket数据发送是异步实现的）
     */
    private sendAsync;
    /**
     * SDK前置检查。
     *
     * @returns true表示sdk已被初始化，否则未初始化
     */
    private checkBeforeSend;
    /**
     * SDK是否已存在登录UID（存在即表示已成功登录过了）。
     *
     * @returns SDK是否已存在登录UID
     */
    private hasLoginUserId;
}
