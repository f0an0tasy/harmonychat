import { LogLevel } from "./h1";
export declare class LoggerModel {
    private domain;
    private prefix;
    private format;
    constructor(prefix: string);
    debug(...args: any[]): void;
    info(...args: any[]): void;
    warn(...args: any[]): void;
    error(...args: any[]): void;
    fatal(...args: any[]): void;
    isLoggable(prefix: string, level: LogLevel): boolean;
}
