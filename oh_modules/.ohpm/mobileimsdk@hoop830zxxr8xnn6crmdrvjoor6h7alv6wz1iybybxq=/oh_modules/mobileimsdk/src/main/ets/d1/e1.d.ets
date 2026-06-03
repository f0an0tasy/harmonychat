// @keepTs
// @ts-nocheck
import { Configure } from "./f1/k1";
import { Logger } from "./f1/g1";
import { LogLevel } from "./f1/h1";
export declare class LogUtils {
    private level;
    private logger;
    constructor();
    getLogger(): Logger;
    getConfigure(): Configure;
    setLevel(level: LogLevel): void;
}
declare const _default: LogUtils;
export default _default;
