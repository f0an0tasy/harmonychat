// @keepTs
// @ts-nocheck
/**
 * 错误码常量表.
 * 建议0~1024范围内的错误码作为MobileIMSDK核心框架保留，业务层请使用>1024的码表示！
 */
export default class ErrorCode {
    /** 一切正常 */
    static readonly COMMON_CODE_OK: number;
    /** 客户端尚未登陆 */
    static readonly COMMON_NO_LOGIN: number;
    /** 未知错误 */
    static readonly COMMON_UNKNOW_ERROR: number;
    /** 数据发送失败 */
    static readonly COMMON_DATA_SEND_FAILD: number;
    /** 无效的 {@link Protocal}对象 */
    static readonly COMMON_INVALID_PROTOCAL: number;
    /** 与服务端的连接已断开 */
    static readonly BREOKEN_CONNECT_TO_SERVER: number;
    /** 与服务端的网络连接失败 */
    static readonly BAD_CONNECT_TO_SERVER: number;
    /** 客户端SDK尚未初始化 */
    static readonly CLIENT_SDK_NO_INITIALED: number;
    /** 本地网络不可用（未打开） */
    static readonly LOCAL_NETWORK_NOT_WORKING: number;
    /** 要连接的服务端网络参数未设置 */
    static readonly TO_SERVER_NET_INFO_NOT_SETUP: number;
    /** 客户端尚未登陆，请重新登陆 */
    static readonly RESPONSE_FOR_UNLOGIN: number;
}
