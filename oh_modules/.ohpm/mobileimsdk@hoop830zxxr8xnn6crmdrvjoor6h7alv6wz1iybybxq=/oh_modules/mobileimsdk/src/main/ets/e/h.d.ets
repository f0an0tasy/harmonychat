// @keepTs
// @ts-nocheck
import Protocal from "../o/z";
/**
 * 数据接收辅助类（因鸿蒙的websocket的数据接收不需要像经典的BIO那样需开发者自已启动单独
 * 的线程，所以本类就简化成了一个辅助类，只是类命名为了兼容性，作了保留，请勿困惑）。
 *
 * 主要工作是将收到的数据进行解析并按MobileIMSDK框架的协议进行调度和处理。
 * 本类是MobileIMSDK框架数据接收处理的唯一实现类，也是整个框架算法最为关键的部分。
 *
 * 注意：本线程的启停，目前属于MobileIMSDK算法的一部分，暂时无需也不建议由应用层自行调用。
 *
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 */
export default class LocalDataReciever {
    /** 本类的全局单例 */
    private static instance;
    /** true表示开启 Debug信息的输出，否则关闭。默认为true. */
    static DEBUG: boolean;
    /**
     * 获得本类的全局单例。
     *
     * @returns LocalDataReciever 单例
     */
    static getInstance(): LocalDataReciever;
    /**
     * 处理通过WebSocket收到的原始数据包，将根据定义的协议类型进入相应的处理逻辑。
     *
     * @param pFromServer 解析出的MobileIMSDK原始协议包
     */
    handleProtocal(pFromServer: Protocal): void;
    /**
     * 收到通用数据时的处理逻辑。
     *
     * @param pFromServer 原始协议包
     */
    private onRecievedCommonData;
    /**
     * 收到服务端的心跳响应包时的处理逻辑。
     */
    private onServerResponseKeepAlive;
    /**
     * 收到ACK消息应答时的处理逻辑。
     *
     * @param pFromServer 原始协议包
     */
    private onMessageRecievedACK;
    /**
     * 收到登陆响应包的处理逻辑。
     *
     * @param pFromServer 原始协议包
     */
    private onServerResponseLogined;
    /**
     * 收到服务端的错误信息包时的处理逻辑。
     *
     * @param pFromServer 原始协议包
     */
    private onServerResponseError;
    /**
     * 收到服务端发回来过的“重复登录被踢”消息时的处理逻辑。
     *
     * @param pFromServer 原始协议包
     */
    private onKickout;
    /**
     * 登陆服务端成功后的处理逻辑。
     */
    private fireConnectedToServer;
    /**
     * 与服务端断开连接后的处理逻辑。
     */
    private fireDisconnectedToServer;
    /**
     * 发送消息应答指令。
     *
     * @param pFromServer 原始协议包
     */
    private sendRecievedBack;
}
