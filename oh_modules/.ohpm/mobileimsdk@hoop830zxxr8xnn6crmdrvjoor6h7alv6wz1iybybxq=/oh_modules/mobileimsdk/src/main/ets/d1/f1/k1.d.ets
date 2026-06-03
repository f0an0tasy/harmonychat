// @keepTs
// @ts-nocheck
import { LogLevel } from "./h1";
declare class cheesestruct {
    types: Array<String>;
    filename?: string;
}
declare class defaultsstruct {
    appenders: string;
    level: LogLevel;
}
export declare class Configure {
    cheese: cheesestruct;
    defaults: defaultsstruct;
    constructor(types: Array<string>, filename: string, appenders: string, level: LogLevel);
}
export {};
