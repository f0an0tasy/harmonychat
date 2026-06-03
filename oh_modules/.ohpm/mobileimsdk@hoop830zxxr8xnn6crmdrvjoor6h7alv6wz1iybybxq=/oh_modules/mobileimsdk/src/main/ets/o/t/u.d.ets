// @keepTs
// @ts-nocheck
/**
 * 错误信息DTO类。
 *
 * @author Jack Jiang( http://www.52im.net/thread-2792-1-1.html )
 * @version 1.0
 */
export default class PErrorResponse {
    errorCode: number;
    errorMsg: string;
    constructor(errorCode: number, errorMsg: string);
}
