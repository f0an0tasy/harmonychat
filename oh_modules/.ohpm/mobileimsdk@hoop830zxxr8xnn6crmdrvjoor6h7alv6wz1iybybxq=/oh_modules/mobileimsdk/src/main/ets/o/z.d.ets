// @keepTs
// @ts-nocheck
/**
 * 协议报文对象.
 *
 * @author Jack Jiang( http://www.52im.net/thread-2792-1-1.html )
 * @version 1.0
 * @see ProtocalType
 */
export default class Protocal {
    /**
     * 意义：协议类型。
     * 注意：本字段为框架专用字段，本字段的使用涉及IM核心层算法的表现，如无必要请避免应用层使用此字段。
     * 补充：理论上应用层不参与本字段的定义，可将其视为透明，如需定义应用层的消息类型，请使用typeu字段并配合dataContent一起使用。
     */
    type: number;
    /**
     * 意义：协议数据内容。
     * 说明：本字段用于MobileIMSDK框架中时，可能会存放一些指令内容。当本字段用于应用层时，由用户自行定义和使用其内容。
     */
    dataContent: string;
    /**
     * 意义：消息发出方的id（当用户登陆时，此值可不设置）
     * 说明：为“-1”表示未设定、为“0”表示来自Server。
     */
    from: string;
    /**
     * 意义：消息接收方的id（当用户退出时，此值可不设置）
     * 说明：为“-1”表示未设定、为“0”表示发给Server。
     */
    to: string;
    /**
     * 意义：用于消息的指纹特征码（理论上全局唯一）.
     * 注意：本字段为框架专用字段，请勿用作其它用途。
     */
    fp: string;
    /**
     * 意义：true表示本包需要进行QoS质量保证，否则不需要.<br>
     * 默认：false */
    QoS: boolean;
    /**
     * 意义：应用层专用字段——用于应用层存放聊天、推送等场景下的消息类型。
     * 注意：此值为-1时表示未定义。MobileIMSDK_X框架中，本字段为保留字段，不参与框架的核心算法，专留用应用层自行定义和使用。
     */
    typeu: number;
    /** 本字段仅用于客户端QoS逻辑时（表示丢包重试次数），本字段不用于网络传输时！ */
    retryCount: number;
    /**
     * 服务端发出或转发此消息时的时间（此字段仅在 <code>{@link ServerLauncher.serverTimestamp} == true</code> 时被服务端自动设置）。
     * <p>
     * 此时间为形如“1624333553769”的Java时间戳，此值不设置则默认为-1。
     * <p>
     * <b>本段的用途</b>：<font color="red">本字段不参与MobileIMSDK核心框架的任何算法</font>，本字段的存与否与框架算法无任何关系，仅仅提
     * 供给应用层供开发者使用，开发者可以利用此字段来构造消息的排序逻辑等，别无他用。
     */
    sm: number;
    /**
     * 创建Protocal对象的方法。
     *
     * @param type 协议类型
     * @param dataContent 协议数据内容
     * @param from 消息发出方的id（当用户登陆时，此值可不设置）
     * @param to 消息接收方的id（当用户退出时，此值可不设置）
     * @param QoS 是否需要QoS支持，true表示是，否则不需要
     * @param fingerPrint 协议包的指纹特征码，当 QoS字段=true时且本字段为null时方法中将自动生成指纹码否则使用本参数指定的指纹码
     * @param typeu 应用层专用字段——用于应用层存放聊天、推送等场景下的消息类型，不需要设置时请填-1即可
     * @return 新的Protocal对象
     */
    constructor(type: number, dataContent: string, from: string, to: string, QoS: boolean, fingerPrint: string | undefined, typeu: number);
    /**
     * 将本对象转换成JSON字符串.
     *
     * @return 本对象的JSON字串形式
     */
    toGsonString(): string;
    /**
     * Protocal深度对象克隆方法实现（深拷贝）。
     *
     * @return 克隆完成后的新对象
     */
    clone(): Protocal;
    /**
     * 返回QoS需要的消息包的指纹特征码.
  
     * 重要说明：使用系统时间戳作为指纹码，则意味着只在Protocal生成的环境中可能唯一.
     * 它存在重复的可能性有2种：
     * 		1) 比如在客户端生成时如果生成过快的话（时间戳最小单位是1毫秒，如1毫秒内生成多个指纹码），理论上是有重复可能性；
     * 		2) 不同的客户端因为系统时间并不完全一致，理论上也是可能存在重复的，所以唯一性应是：好友+指纹码才对.
     *
     * 目前使用的UUID能保证全局唯一，但它有36位长（加上分隔符32+4），在流量敏感的场景下，建议可考虑适当优化此生成算法。
     *
     * @return 指纹特征码
     */
    static genFingerPrint(): string;
}
