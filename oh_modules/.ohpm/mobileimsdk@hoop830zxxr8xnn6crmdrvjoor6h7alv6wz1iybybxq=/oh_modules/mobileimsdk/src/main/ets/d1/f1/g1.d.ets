// @keepTs
// @ts-nocheck
import { Configure } from "./k1";
export declare class Logger {
    private configure;
    private loggerModel;
    private strategies;
    constructor();
    setConfigure(configure: Configure): void;
    debug(message: string): void;
    info(message: string): void;
    warn(message: string): void;
    error(message: string): void;
    fatal(message: string): void;
}
