// @keepTs
// @ts-nocheck
/**
 * Socket事件名定义。
 *
 * MobileIMSDK 鸿蒙版客户端框架中，各种网络事件是通过事件通知的方法抛出，从而与主逻辑解耦，机制上与Andriod端的机制EventBus等类似，
 * 与socket.io、小程序、uniapp中的事件通知实现思路也都是一致的。
 *
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 */
export default class SocketEvent {
    /** 网络事件：登录连接或掉线重连响应反馈 */
    static readonly SOCKET_EVENT_ON_LOGIN_RESPONSE: string;
    /** 网络事件：网络断开(掉线了) */
    static readonly SOCKET_EVENT_ON_LINK_CLOSE: string;
    /** 网络事件：收到新的消息 */
    static readonly SOCKET_EVENT_ON_RECIEVE_MESSAGE: string;
    /** 网络事件：服务端反馈的错误信息（这种错误出现即表示连接不可恢复，SDK框架将会自动进入重连动作） */
    static readonly SOCKET_EVENT_ON_ERROR_RESPONSE: string;
    /** 网络事件：发出的消息没有成功被送达（没有收到应答确认包） */
    static readonly SOCKET_EVENT_MESSAGE_LOST: string;
    /** 网络事件：发出的消息已成功被送达（收到应答确认包） */
    static readonly SOCKET_EVENT_MESSAGE_BE_RECIEVED: string;
    /** 网络事件：正在尝试掉线重连动作 */
    static readonly SOCKET_EVENT_RECONNECT_ATTEMPT: string;
    /** 网络事件：心跳包（客户端发出的） */
    static readonly SOCKET_EVENT_PING: string;
    /** 网络事件：心跳包（客户端收到的） */
    static readonly SOCKET_EVENT_PONG: string;
    /** 网络事件：客户端已被强行踢出 */
    static readonly SOCKET_EVENT_KICKOUT: string;
}
