// @keepTs
// @ts-nocheck
import Protocal from "./z";
import PKeepAliveResponse from "./t/v";
import PKeepAlive from "./p/q";
import PErrorResponse from "./t/u";
import PLoginInfo from "./p/r";
import PLoginInfoResponse from "./t/x";
import PKickoutInfo from "./t/w";
/**
 * MobileIMSDK框架的协议工厂类。
 *
 * 理论上这些协议都是框架内部要用到的，应用上层可以无需理解和理会之。
 *
 * @author Jack Jiang( http://www.52im.net/thread-2792-1-1.html )
 * @version 1.0
 */
export default class ProtocalFactory {
    private static create;
    /**
     * 将JSON文本反射成Java对象。
     *
     * 本方法主要由MobileIMSDK框架内部使用。
     *
     * @param dataContentOfProtocal 对象json文本
     * @param clazz 要反射成的对象
     * @return 反射完成的{@link Protocal}报文对象
     */
    static parse<T>(dataContentOfProtocal: string): T;
    /**
     * 本方法主要由MobileIMSDK框架内部使用。
     *
     * @param dataContentOfProtocal
     * @return PKeepAliveResponse对象
     */
    static parsePKeepAliveResponse(dataContentOfProtocal: string): PKeepAliveResponse;
    /**
     * 创建用户心跳包报文对象（该对象由客户端发出）.
     *
     * 本方法主要由MobileIMSDK框架内部使用。
     *
     * @param from_user_id
     * @return 新建的{@link Protocal}报文对象
     */
    static createPKeepAlive(from_user_id: string): Protocal;
    /**
     * 本方法主要由MobileIMSDK框架内部使用。
     *
     * @param dataContentOfProtocal
     * @return PKeepAlive对象
     */
    static parsePKeepAlive(dataContentOfProtocal: string): PKeepAlive;
    /**
     * 解析错误响应消息报文对象（该对象由客户端接收）.
     *
     * 本方法主要由MobileIMSDK框架内部使用。
     *
     * @param dataContentOfProtocal
     * @return PErrorResponse对象
     */
    static parsePErrorResponse(dataContentOfProtocal: string): PErrorResponse;
    /**
     * 创建用户注消登陆消息报文对象（该对象由客户端发出）.
     *
     * 本方法主要由MobileIMSDK框架内部使用。
     *
     * @param user_id
     * @return 新建的Protocal报文对象
     */
    static createPLoginoutInfo(user_id: string): Protocal;
    /**
     * 创建用户登陆消息报文对象（该对象由客户端发出）.
     *
     * 本方法主要由MobileIMSDK框架内部使用。
     *
     * @param loginInfo 登陆信息对象，详见 {@link PLoginInfo}
     * @return 新建的{@link Protocal}报文对象
     */
    static createPLoginInfo(loginInfo: PLoginInfo): Protocal;
    /**
     * 解析用户登陆消息报文对象（该对象由服务端接收）.
     *
     * 本方法主要由MobileIMSDK框架内部使用。
     *
     * @param dataContentOfProtocal
     * @return PLoginInfo对象
     */
    static parsePLoginInfo(dataContentOfProtocal: string): PLoginInfo;
    /**
     * 解析用户登陆响应消息报文对象（该对象由客户端接收）.
     *
     * 本方法主要由MobileIMSDK框架内部使用。
     *
     * @param dataContentOfProtocal
     * @return PLoginInfoResponse对象
     */
    static parsePLoginInfoResponse(dataContentOfProtocal: string): PLoginInfoResponse;
    /**
     * 通用消息的Protocal报文对象新建方法。
     *
     * @param dataContent 要发送的消息内容
     * @param from_user_id 发送人的user_id
     * @param to_user_id 接收人的user_id
     * @param QoS 是否需要QoS支持，true表示需要，否则不需要
     * @param fingerPrint 消息指纹特征码，为null则表示由系统自动生成指纹码，否则使用本参数指明的指纹码
     * @param typeu 可选参数，应用层专用字段——用于应用层存放聊天、推送等场景下的消息类型，不需要设置时请填-1或不填即可
     * @return 新建的{@link Protocal}报文对象
     */
    static createCommonData(dataContent: string, from_user_id: string, to_user_id: string, QoS: boolean, fingerPrint: string | undefined, typeu?: number): Protocal;
    /**
     * 客户端from_user_id向to_user_id发送一个QoS机制中需要的“收到消息应答包”(无bridge标识).
     *
     * 本方法主要由MobileIMSDK框架内部使用。
     *
     * @param from_user_id 发起方
     * @param to_user_id 接收方
     * @param recievedMessageFingerPrint 已收到的消息包指纹码
     * @return 新建的{@link Protocal}报文对象
     */
    static createRecivedBack(from_user_id: string, to_user_id: string, recievedMessageFingerPrint: string): Protocal;
    /**
     * 创建用户被踢包报文对象（该对象由服务端发出）.
     *
     * 本方法主要由MobileIMSDK框架内部使用。
     *
     * @param to_user_id 接收方
     * @param code 被踢原因编码（本参数不可为空），see {@link PKickoutInfo} 中的常量定义，自定义被踢原因请使用>100的值
     * @param reason 被踢原因描述（本参数可为空）
     * @return 新建的{@link Protocal}报文对象
     */
    static createPKickout(to_user_id: string, code: number, reason: string): Protocal;
    /**
     * 解析用户被踢消息报文对象（该对象由客户端接收）.
     *
     * 本方法主要由MobileIMSDK框架内部使用。
     *
     * @param dataContentOfProtocal
     * @return PKickoutInfo对象
     */
    static parsePKickoutInfo(dataContentOfProtocal: string): PKickoutInfo;
}
