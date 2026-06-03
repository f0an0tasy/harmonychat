// @keepTs
// @ts-nocheck
/**
 * 登陆结果响应信息DTO类。
 *
 * @author Jack Jiang( http://www.52im.net/thread-2792-1-1.html )
 * @version 1.0
 */
export default class PLoginInfoResponse {
    /** 错误码：0表示认证成功，否则是用户自定的错误码（该码应该是>1024的整数） */
    code: number;
    /**
     * 客户端首次登陆时间（此时间为形如“1624333553769”的Java时间戳），此值不设置则默认应置为0。
     *
     * 此时间由服务端设置，且直到客户端主动登陆，此时间不会被更新或重置（重连时也不会重置）。
     *
     * 此时间目前的唯一用途：用于多端登陆时互踢的依据，防止在客户端未收到服务端“踢出”指令的情况下，再次自动重连过来（通过此时间就可以判断出此客
     * 户端登陆时间之后又有新的端登陆，从而拒绝此次重连，防止后登陆的端被之前这个“老”的端在它的网络恢复后错误地挤出“新”登陆的）。
     *
     * 本次互踢思路，请见我在此帖中的回复：<a href="http://www.52im.net/thread-2879-1-1.html">http://www.52im.net/thread-2879-1-1.html</a>
     */
    firstLoginTime: number;
    constructor(code: number, firstLoginTime: number);
}
