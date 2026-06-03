// @keepTs
// @ts-nocheck
/**
 * MobileIMSDK核心框架级的协议类型.
 * 这些协议类型由框架算法决定其意义和用途，不建议用户自行使用，用户自定义协议类型请参见 {@link Protocal} 类中的 typeu 字段。
 * 可参考API文档：http://docs.52im.net/extend/docs/api/mobileimsdk/server_tcp/net/x52im/mobileimsdk/server/protocal/Protocal.html
 */
export default class ProtocalType {
    /** 由客户端发出 - 协议类型：客户端登陆 */
    static readonly FROM_CLIENT_TYPE_OF_LOGIN: number;
    /** 由客户端发出 - 协议类型：心跳包 */
    static readonly FROM_CLIENT_TYPE_OF_KEEP$ALIVE: number;
    /** 由客户端发出 - 协议类型：发送通用数据 */
    static readonly FROM_CLIENT_TYPE_OF_COMMON$DATA: number;
    /** 由客户端发出 - 协议类型：客户端退出登陆 */
    static readonly FROM_CLIENT_TYPE_OF_LOGOUT: number;
    /** 由客户端发出 - 协议类型：QoS保证机制中的消息应答包（目前只支持客户端间的QoS机制哦） */
    static readonly FROM_CLIENT_TYPE_OF_RECIVED: number;
    /** 由客户端发出 - 协议类型：C2S时的回显指令（此指令目前仅用于测试时） */
    static readonly FROM_CLIENT_TYPE_OF_ECHO: number;
    /** 由服务端发出 - 协议类型：响应客户端的登陆 */
    static readonly FROM_SERVER_TYPE_OF_RESPONSE$LOGIN: number;
    /** 由服务端发出 - 协议类型：响应客户端的心跳包 */
    static readonly FROM_SERVER_TYPE_OF_RESPONSE$KEEP$ALIVE: number;
    /** 由服务端发出 - 协议类型：反馈给客户端的错误信息 */
    static readonly FROM_SERVER_TYPE_OF_RESPONSE$FOR$ERROR: number;
    /** 由服务端发出 - 协议类型：反馈回显指令给客户端 */
    static readonly FROM_SERVER_TYPE_OF_RESPONSE$ECHO: number;
    /** 由服务端发出 - 协议类型：向客户端发出“重复登陆被踢”指令 */
    static readonly FROM_SERVER_TYPE_OF_KICKOUT: number;
}
