// @keepTs
// @ts-nocheck
/**
 * 一个简单的基于setInterval()的定时器实现类，目的是封装和简化setInterval的使用而已。
 *
 * @author Jack Jiang(http://www.52im.net/thread-2792-1-1.html)
 */
export default class SimpleTimer {
    /** 保存setInverval(...)定时器id（此id方便用于关闭定时器时使用）*/
    private _intervalId;
    /** 定时间隔，单位：毫秒 */
    private interval;
    /** 需要定时执行的任务 */
    doActionCallback: Function;
    constructor(interval: number, doActionCallback: Function);
    private execute;
    /**
     * 启动线程。
     * <p>
     * 无论本方法调用前线程是否已经在运行中，都会尝试首先调用 {@link stop()}方法，以便确保线程被启动前是真正处
     * 于停止状态，这也意味着可无害调用本方法。
     *
     * @param immediately true表示立即执行线程作业，否则直到 {@link interval}执行间隔的到来才进行首次作业的执行。
     * @see onStart()
     */
    start(immediately: boolean): void;
    /**
     * 定时器开启后额外要做的事情。默认代码中什么也不做，子类可重写本方法。
     *
     * @see start(boolean)
     */
    protected onStart(): void;
    /**
     * 无条件中断本线程的运行。
     *
     * @see onStop()
     */
    stop(): void;
    /**
     * 定时器停止后额外要做的事情。默认代码中什么也不做，子类可重写本方法。
     *
     * @see stop()
     */
    protected onStop(): void;
}
