// @keepTs
// @ts-nocheck
/**
 * 向客户端发出的“被踢”指令包内容的DTO类。
 *
 * @author Jack Jiang( http://www.52im.net/thread-2792-1-1.html )
 */
export default class PKickoutInfo {
    /** 被踢原因编码：因重复登陆被踢 */
    static readonly KICKOUT_FOR_DUPLICATE_LOGIN: number;
    /** 被踢原因编码：被管理员强行踢出 */
    static readonly KICKOUT_FOR_ADMIN: number;
    /** 被踢原因编码 */
    code: number;
    /** 被踢原因描述 */
    reason: string;
    /**
     * 构造方法。
     *
     * @param code 被踢原因编码（本参数不可为空）
     * @param reason 被踢原因描述（本参数可为空）
     */
    constructor(code: number, reason: string);
}
