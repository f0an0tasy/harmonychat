// @keepTs
// @ts-nocheck
/**
 * MobileIMSDK核心框架预设的敏感度模式.
 *
 * 对于客户端而言，此模式决定了用户与服务端网络会话的健康模式，原则上超敏感客户端的体验越好。
 *
 * 重要说明：客户端本模式的设定必须要与服务端的模式设制保持一致，否则可能因参数的不一致而导致IM算法的不匹配，进而出现不可预知的问题。
 *
 * @author Jack Jiang
 */
export default class SenseMode {
    /**
     * 此模式下：
     * - KeepAlive心跳问隔为3秒；
     * - 5秒后未收到服务端心跳反馈即认为连接已断开（相当于连续1个心跳间隔+2秒链路延迟容忍时间后仍未收到服务端反馈）。
     */
    static readonly MODE_3S: number;
    /**
     * 此模式下：
     * - KeepAlive心跳问隔为5秒；
     * - 8秒后未收到服务端心跳反馈即认为连接已断开（相当于连续1个心跳间隔+3秒链路延迟容忍时间后仍未收到服务端反馈）。
     */
    static readonly MODE_5S: number;
    /**
     * 此模式下：
     * - KeepAlive心跳问隔为10秒；
     * - 15秒后未收到服务端心跳反馈即认为连接已断开（相当于连续1个心跳间隔+5秒链路延迟容忍时间后仍未收到服务端反馈）。
     */
    static readonly MODE_10S: number;
    /**
     * 此模式下：
     * - KeepAlive心跳问隔为15秒；
     * - 20秒后未收到服务端心跳反馈即认为连接已断开（相当于连续1个心跳间隔+5秒链路延迟容忍时间后仍未收到服务端反馈）。
     */
    static readonly MODE_15S: number;
    /**
     * 此模式下：
     * - KeepAlive心跳问隔为30秒；
     * - 35秒后未收到服务端心跳反馈即认为连接已断开（相当于连续1个心跳间隔+5秒链路延迟容忍时间后仍未收到服务端反馈）。
     */
    static readonly MODE_30S: number;
    /**
     * 此模式下：
     * - KeepAlive心跳问隔为60秒；
     * - 65秒后未收到服务端心跳反馈即认为连接已断开（相当于连续1个心跳间隔+5秒链路延迟容忍时间后仍未收到服务端反馈）。
     */
    static readonly MODE_60S: number;
    /**
     * 此模式下：
     * - KeepAlive心跳问隔为120秒；
     * - 125秒后未收到服务端心跳反馈即认为连接已断开（相当于连续1个心跳间隔+5秒链路延迟容忍时间后仍未收到服务端反馈）。
     */
    static readonly MODE_120S: number;
    /**
     * 设置MobileIMSDK即时通讯核心框架预设的敏感度模式（默认为 {@link MBSenseMode#MODE_15S} ）。
     *
     * 请在登陆前调用，否则将不起效.
     *
     * 重要说明：客户端本模式的设定必须要与服务端的模式设制保持一致，否则可能因参数的不一致而导致IM算法的不匹配，进而出现不可预知的问题。
     *
     * @param senseMode 常量定义详见{@link SenseMode}
     */
    static setSenseMode(senseMode: number): void;
}
