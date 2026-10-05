# MoonBit 官方异步生态与 yue 消息循环共存调研

> 调研日期:2026-10-02。调研环境:Ubuntu 24.04 + X11 + XFCE,moon 0.1.20260920 (914d7da)。
> 本文只调研不改主链路;实验代码在 `experiment/async_coexist/`,实验均在临时目录完成、不依赖本地主仓改动(依赖取 mooncakes 线上 `NoahLiu/moonbit-libyue@0.5.9`)。
> 配套实验记录见 `experiment/async_coexist/README.md`。

## 1. 结论速览(TL;DR)

1. **官方 async 包就是唯一正解**:`moonbitlang/async`(mooncakes 最新 0.22.4,下载 55.9 万,2026-09-24 发布;GitHub 活跃至 2026-10-02)。语言级 `async fn` 语法 + 结构化并发(`with_task_group`/`spawn_bg`),执行器为**单线程协作式**,IO 由内部**专用 waiter 线程** + epoll(Linux)/kqueue(macOS)/IOCP(Windows) + 线程池承担。`moonbitlang/core` 内建库**没有** async/promise 模块,异步能力全部在这个包里(已核实 core 全部 61 个模块列表)。
2. **官方已内置 GUI 集成通道,且方向与『pump』设想相反**:0.21.0(2026-08-19)起新增 `moonbitlang/async/external_loop_integration` 子包,提供 `ExternalEventLoop` trait(`poll(timeout?)` / `get_wakeup_callback_for_foreign_thread()` / `terminate()`)与 `@async.set_external_event_loop()`。模式是 **async 当家、GUI 主循环作为 poll 回调挂进去**;而原设想的「GUI run() 当家、定时器/空闲 pump async 单步」**在公共 API 层面不成立**——驱动入口 `with_event_loop` 在 `internal/` 包里,外部不可 import,公共面没有「单步 pump async」的函数。
3. **不集成时只有『伪共存』(已实测)**:async 与 yue 可同进程链接互不冲突,但 `yue.run()` 阻塞期间 async 调度器完全冻结(timer 全部停摆),`run()` 返回后才恢复。
4. **四批方案总体成立,需要三处校准**:①『pump』改为『单步 poll 实现 ExternalEventLoop』;②shim 三接口与 trait 三方法一一对应,数量与命名方向正确,但 Linux 有一个实测出来的 clamp 坑、Windows 不能复用 `PostTask` 路线做唤醒;③批次 1(共存验证)无需动 shim 已可全部完成(本文实验 2/3 即是)。
5. **一个此前未列入的额外卖点**:ExternalEventLoop 模式下所有 MoonBit 代码仍跑在主线程(官方 `integration.mbt` 文档明确),因此 **async 任务里可以直接改 GUI,无需 dispatch 回主线程**——这是相对 Python(Electron 除外)等方案的实际优势。

## 2. 生态盘点(mooncakes + GitHub,检索日期 2026-10-02)

检索方式:mooncakes registry 搜索 API(`https://mooncakes.io/api/v0/search?kw=...`,关键词 async/executor/event loop/promise/future/coroutine/task)+ GitHub 仓库核对 + 本地 `moon add` 实测。

| 包 | 版本 | 下载 | 形态 | 对 yue 集成的意义 |
|---|---|---|---|---|
| **moonbitlang/async**(官方) | 0.22.4 | 559,259 | `async fn` 语法 + TaskGroup 结构化并发 + 完整 IO 栈 | **集成底座,唯一选择** |
| moonbitlang/async/external_loop_integration | (随主包) | — | `ExternalEventLoop` trait | **GUI 共存的官方通道**(0.21.0 引入) |
| moonbitlang/async 子包 socket/tls/http/websocket/fs/process/shell/pipe/stdio/signal/gzip/aqueue/cond_var/semaphore/mutex/io/os_error/types/raw_fd | (随主包) | — | 异步 IO 与同步原语 | 批次 4 示例素材(异步 HTTP/文件/子进程开箱即用) |
| peter-jerry-ye/async | 0.2.1 | 145 | Promise/Resolver + 泛型 event loop + channel + stream,提供与 `async fn` 的 `spawn`/`t.await` 互转 | 早于官方 runtime 的社区件;仅作回调↔async 桥接参考,不作底座 |
| nuskey8/oneshot | 0.1.0 | 19 | async oneshot channel | 官方生态补充件(官方主包未带 oneshot) |
| moonbit-community/window(winit port;wzzc-dev fork / Milky2018 分发) | 0.5.x / 0.6.1 | 9,175 / 6,684 | winit 移植,提供 `EventLoop::pump_app_events(...)` 宿主循环集成 API | 社区 GUI 侧同类实践:GUI 库提供「单步泵」是通行做法(与 winit `pump_events` 同型) |
| bobzhang/taskflow | 0.3.4 | 51 | (无描述) | 非异步运行时,不相关 |

版本时间线(本地 registry 索引 `~/.moon/registry/index/user/moonbitlang/async.index`,79 个版本):2025-07-16 首发 0.1.0;**external_loop_integration 于 0.21.0(2026-08-19)引入**(逐版本 zip 检出核实);最新 0.22.4(2026-09-24)。**迭代节奏约每周一版,README 自称 experimental**——版本策略见 §8 风险。

另核实:`FuncRef[T]` 为**语言内建类型**(无需 import,本地 `moon check`/`moon run` 通过验证)——它是 wakeup 回调的载体,详 §5。

## 3. moonbitlang/async 执行器模型(源码剖析)

以下均出自 0.22.4 源码(本地解包 `~/.moon/registry/cache/moonbitlang/async/0.22.4.zip`,与 GitHub main 分支一致)。

### 3.1 API 形态

- **语言语法**:`async fn` 定义异步函数,调用处**隐式 await**(无 `await` 关键字)。入口写法 `async fn main { ... }`(官方示例 `examples/tcp_ping_pong/main.mbt`)。本地实测 moon 0.1.20260920 直接支持,无需 feature flag。
- **结构化并发**:所有任务必须 spawn 在 `TaskGroup` 里,`with_task_group(async (TaskGroup[X]) -> X) -> X` 返回时组内任务全部结束(`src/pkg.generated.mbti:46`)。`spawn`(返回 `Task[X]` 可 cancel/wait)、`spawn_bg`(后台,可 `no_wait=true` 不阻塞组退出)、`spawn_loop`(常驻循环,带重试策略)。
- **同步原语**:`Mutex`(async acquire)、`CondVar`、`Queue`(MPMC,背压策略)、`Semaphore`。
- **定时**:`sleep(ms)`、`Timer`(可 refresh/cancel)、`with_timeout`/`with_timeout_opt`。
- **取消**:粘性取消,`handle_cancellation`/`protect_from_cancel`/`is_being_cancelled`。
- **无 Future/Promise 抽象**——直接以 `async () -> X` 函数值 + `Task[X]` 句柄表达;core 亦无 promise(已核实)。

### 3.2 谁驱动 poll:执行器结构

入口链:`async fn main` →(工具链注入)`@async.run_async_main`(`src/integration.mbt:20-33`)→ `@event_loop.with_event_loop`(`src/internal/event_loop/event_loop.mbt:126-164`,**internal 包**)。

`with_event_loop` 的常规模式(`run_forever`,`event_loop.mbt:349-370`):

```
while 还有活着的协程:
  timeout = 有立即可跑任务 ? 0 : 有 timer ? 距最近到期(ms) : -1
  n = event_bus.wait(timeout)         # 主线程在此阻塞(epoll/kqueue/IOCP 事件在 bus 里)
  handle_timers()
  处理 n 个 IO 完成事件
  coroutine.reschedule()              # 跑所有就绪协程(单线程,协作式)
```

关键分工:

- **主线程**:跑全部协程(MoonBit 代码)与 timer;
- **waiter 线程**(`bus.spawn_waiter`,`event_loop.mbt:378-383`):独立线程跑 epoll/kqueue/IOCP,事件写入 event bus,并可通过注册的 wakeup 回调唤醒主线程;
- **线程池**(`thread_pool.c`,41KB C 实现):承担阻塞型 IO(磁盘文件、DNS、Tls 等),完成后往 bus 投事件。

也就是说:**执行器由 `async fn main` 隐式启动并独占调用线程**,这是它与 GUI `run()` 冲突的根源。

### 3.3 ExternalEventLoop:官方 GUI 集成通道

`src/external_loop_integration/external_loop.mbt`(0.21.0+,trait 定义 + 完整契约文档):

```moonbit
pub(open) trait ExternalEventLoop {
  fn poll(Self, timeout? : Int) -> Unit raise
  fn get_wakeup_callback_for_foreign_thread(Self) -> FuncRef[() -> Unit]
  fn terminate(Self) -> Unit raise
}
```

官方文档原话点明目标场景:"some programs, such as GUI programs, have their own event loop…In this case, moonbitlang/async supports running its event loop in a dedicated thread internally and integrate with the user-provided loop."

接线方式(`@async.set_external_event_loop`,根包 re-export 自 `integration.mbt:36-55`):

```moonbit
async fn main {
  @yue_async.install()   // 内部:GUI 初始化 + set_external_event_loop(必须在任何实际 async 代码之前)
  @async.with_task_group(root => { ... })
}
```

约束(官方文档 + 源码注释,均已在实验中踩证):

- **`set_external_event_loop` 必须在事件循环启动前调用**:`fn init` 里,或 `async fn main` 开头(未跑任何实际 async 代码前);重复调用或启动后调用直接 `abort`(`event_loop.mbt:115-123`)。
- **`poll(timeout?)` 三种超时语义**:`Some(0)` 不得等待;`Some(t>0)` 至多 t 毫秒(轻微超时允许,但影响 async timer 精度);`None` 无限等。poll 返回后 async **无条件**检查自己的事件,再进入下一轮 poll。
- **poll 内不做重活**:官方建议 GUI 事件经 `@async.CondVar`/`@async.Queue` 送回 async 世界(实验 2b 实证重活的代价,§7.2)。
- **wakeup 回调在 waiter 专用线程被调用,只准直接调 C FFI,严禁任何 MoonBit 引用计数操作**——错过唤醒可能死锁(“MISSED WAKEUP MAY RESULT IN PROGRAM DEAD LOCK”)。实现上 shim 导出纯 C 函数、MoonBit 侧以 `extern "C" fn` 包成 `FuncRef` 返回(官方测试同款写法,`src/external_loop_integration/internal/external_loop_test/main.mbt`)。
- **terminate 时机**:async main 返回之后才调用,GUI 清理代码放这里而不是 async main 尾部。
- **所有 MoonBit 代码仍跑在主线程**;async 只把等待部分放专用线程;async 仍可能改主线程状态(如 signal mask)。

外部循环驱动循环(`run_with_external_loop`,`event_loop.mbt:374-407`,native):

```
waiter = bus.spawn_waiter(wakeup_callback=extloop 的 wakeup 回调)   # 起 IO waiter 线程
while 还有活着的协程:
  timeout = 有就绪任务 ? Some(0) : 有 timer ? Some(到期ms) : None
  extloop.poll(timeout?)               # ← GUI 主循环的一轮迭代(等待+派发)
  handle_timers()
  n = waiter.get_events(); 处理 n 个 IO 事件   # 非阻塞取 waiter 线程产出的事件
  coroutine.reschedule()
cleanup()
```

与 `run_forever` 的差别只有一个:**「等待」这一步从 async 自己的 bus.wait 换成了 GUI 循环的 poll**,async 的 IO 就绪改由 waiter 线程经 wakeup 回调把 GUI 的 poll 提前唤醒。**GUI 与 async 的定时器/IO 在同一主线程上交替执行,天然串行一致,无数据竞争。**

官方参考实现(测试用 MainLoop,`external_loop_test/external_loop.c`):Linux/macOS 用非阻塞 pipe + `poll(2)` 等待、`write` 唤醒;Windows 用两个 auto-reset Event + `WaitForMultipleObjects`、`SetEvent` 唤醒。**这份 C 文件就是 shim 三接口的官方模板**。

## 4. yue 消息循环现状(三平台实现核对)

来源:主仓 shim(`shim/yue_mbt.cpp:250-3541`)、头文件(`vendor/libyue/include/nativeui/message_loop.h:17-55`,全静态方法、声明线程安全)、fork 源码三平台实现文件(GitHub lb091188/yue@master,`nativeui/{gtk,mac,win}/message_loop_*`)。

| 平台 | `Run()` | PostTask | 定时器 | 单步迭代可用原语 | 跨线程唤醒可用原语 |
|---|---|---|---|---|---|
| Linux | `gtk_main()` | `g_idle_add_full`(默认 GMainContext) | `g_timeout_add_full` | `g_main_context_prepare/query/check/dispatch` 四步(默认上下文;**`g_main_context_iteration` 无超时参数,须用四步版**)+ `g_poll` | `g_main_context_wakeup`(内建唤醒 fd,任意线程,纯 C) |
| macOS | `[NSApp run]` | `dispatch_async(main_queue)` | `dispatch_after` / `CFRunLoopTimer`(kCFRunLoopCommonModes) | `-[NSApp nextEventMatchingMask:untilDate:inMode:dequeue:]` + `sendEvent:` + `updateWindows`(untilDate 直接表达超时) | `CFRunLoopSourceSignal` + `CFRunLoopWakeUp(CFRunLoopGetMain())` |
| Windows | `GetMessage` 循环 | **`SetTimeout(USER_TIMER_MINIMUM)`(≈10ms 起步延迟)** | TimerHost(SetTimer 挂 message-only 窗口) | `MsgWaitForMultipleObjectsEx(QS_ALLINPUT, timeout)` + `PeekMessage/Translate/Dispatch` 一轮 | `PostMessageW`(到 message-only 窗口;库内已有同类基建,shim `yue_mbt.cpp:761` 起 singleinstance 即用) |

要点:

1. 三平台消息源**全部挂主线程默认上下文**(GLib default context / NSApplication 主 runloop / 线程消息队列),因此「不进 `Run()`,改为手动单步迭代」在三个平台都有官方原语支持。
2. `yue/app.mbt` 现有 `post_task/post_delayed_task/set_timeout/set_timer/clear_timeout` 的语义在外部循环模式下**全部保持有效**(它们只是往主线程上下文挂源,实验 2 的 GUI 源即同类),API 无需破坏性变更。
3. Windows 的 `PostTask` 走 `SetTimeout(USER_TIMER_MINIMUM)`,**天然 ≥10ms 延迟**——async 的 wakeup 绝不能复用这条路线(要求即时),必须 `PostMessageW` 直投(§8 接口设想)。

## 5. 共存问题本质与其它语言的成熟做法

本质:**一个线程同一时刻只能阻塞在一个等待点上**。GUI 库的 `run()` 与 async 执行器的驱动循环都要「当家的那个等待」,谁阻塞住线程,另一个就冻结。解法自古三条路:

1. **同线程互嵌(单等待点融合)**——把一个循环的等待/派发做成另一个循环的「一步」。GUI 库提供单步泵,或执行器接受外部 poll 回调。代表:
   - **GLib/GTK 官方**:GMainContext 本身就是为此设计的事件总线,`g_main_context_iteration`/`g_main_context_wakeup` 是官方嵌入门;glib 甚至内建了基于 GSource 的 futures 执行器(`GMainContext` spawn),理念与 `ExternalEventLoop` 同源。
   - **winit `pump_events`**:为嵌入宿主循环(游戏引擎、Electron 类壳)设计的单步泵;MoonBit 社区 window 包已 port 此 API(`EventLoop::pump_app_events`)。
   - **Electron**(与本场景最同构):Chromium 消息循环与 Node libuv 同线程共存——Electron 把 uv loop 的 poll 挂进自定义 MessagePump。**`ExternalEventLoop` 正是这个模式**:async 的等待(waiter 线程的 fd)把 GUI 的 poll 当作自己的 MessagePump。
   - **Swift/macOS**:async main 由 runtime 与主线程 runloop 集成(main actor),第三方事件源用 CFRunLoopSource + CFRunLoopWakeUp 唤醒,与 trait 契约一一对应。
2. **双线程 + 消息代理**——async 跑副线程,动 GUI 一律 `post_task` 回主线程。代表:Tauri(tokio + tao,channel 互投)、PyGObject 常见做法(asyncio loop 副线程 + `run_coroutine_threadsafe`)。缺点:UI 更新路径绕、跨线程心智负担重。**MoonBit 当前无稳定用户级线程 API**(官方 async 的线程全在 C 层),这条路短期走不通,也不必走。
3. **协作轮询(pump)**——GUI 当家,定时器/空闲源驱动 async 单步。问题:①需要执行器暴露单步入口(moonbitlang/async 公共 API 没有);②timer 精度退化为 pump 周期;③空闲时 CPU 占用或响应迟滞二选一。**这正是原设想的方向,应放弃**(除非官方未来暴露 pump API)。

结论:**官方 ExternalEventLoop 即路线 1 的官方化**,yue 只需提供三平台单步 poll + 唤醒 + 清理,即完成与 Swift/GLib/winit/Electron 同级的集成。

## 6. 实验记录(全部可复现,代码见 `experiment/async_coexist/`)

### 6.1 实验 1:async fn main 基础验证

`moon run --target native cmd/basic`。结果(moon 0.1.20260920):

```
main start / main resumed at +0ms
tick 1..5 at +100..+501ms(每 100ms 一档,精度 ±1ms)
main end
```

结论:`async fn main` 语法直接可用,执行器自动驱动,`sleep` 精度好。

### 6.2 实验 2:ExternalEventLoop 三机制共存验证(核心)

自建「模拟 GUI 循环」:非阻塞 pipe 作唤醒源(C stub `fake_gui_loop.c`)+ `FakeGui` 实现 trait 三方法;场景覆盖 async timer、TCP 连接就绪(waiter 线程唤醒)、外部线程投 GUI 事件。`moon run --target native cmd/fake_gui`,本仓实验目录复现实测输出:

```
[gui] event #1 handled in poll at +0ms       ← waiter 线程启动即完成一次唤醒
[async] connecting at +100ms                 ← sleep(100):poll(timeout=100) 驱动
[gui] event #2 handled in poll at +100ms     ← connect 就绪,waiter 线程唤醒了 poll
[async] connected (waiter woke poll) at +100ms
[async] server accepted at +100ms
[gui] event #3 handled in poll at +150ms     ← GUI 事件源(post_event 150ms)在 poll 内处理
[async] sleep(300) fired at +300ms           ← async timer 精度正常
[gui] event #4 handled in poll at +500ms     ← GUI 事件源(post_event 500ms)
[async] main end at +600ms
[gui] terminate at +600ms                    ← terminate 在 main 返回后
```

(wakeup 时机非确定,各轮事件条数略有出入,时间线结构不变;首测轮另见 `experiment/async_coexist/README.md`。)

结论:**poll 超时驱动 async timer、waiter 跨线程唤醒 poll、GUI 事件 poll 内处理、terminate 时机**四项机制全部按官方契约工作。

### 6.3 实验 2b:poll 内干重活的代价(官方警告实证)

poll 每轮固定 busy 200ms(模拟 GUI 事件处理慢),观察 `sleep(100*i)`:

```
[async] sleep(100) fired at +700ms (expect +100ms)
[async] sleep(200) fired at +700ms (expect +200ms)
[async] sleep(300) fired at +700ms (expect +300ms)
[async] sleep(400) fired at +1000ms (expect +400ms)
[async] sleep(500) fired at +1000ms (expect +500ms)
```

结论:**GUI 侧回调耗时直接成为 async 定时器的最大延迟**(漂移最高 7 倍)。yue/async 子包的文档与示例必须强调:回调薄进薄出,重活 `spawn_bg` 丢回 async 世界。

### 6.4 实验 3:yue×async 同进程「伪共存」边界(线上 yue 0.5.9 + async 0.22.4)

依赖 mooncakes 线上包(未用本地主仓),async main 内调 `@yue.run()`:

```
[async] main start +0ms
[async] entering yue.run() +52ms
[yue]  set_timeout fired at +352ms        ← GLib 定时器照常
[yue]  quitting at +1253ms                ← 1.2s 定时到,quit()
[async] yue.run() returned +1253ms
[async] tick 1 at +1453ms                 ← 冻结的 async 在 run() 返回后恢复
...tick 6 at +2455ms(main end +2455ms)
```

结论:①**同进程链接共存无冲突**(GTK/GLib 与 async 的 epoll/线程池互不干扰,prebuild 链接传播正常)——批次 1 的「能否共存」问题闭环;②但 `run()` 阻塞期间 async 全冻结,**timer 在冻结后按剩余周期重新计**而非立即补发(tick1 于返回后 +200ms 触发)——伪共存只适合「GUI 阶段性独占」的场景;③`post_task`/`set_timeout` 从 async 侧调用无障碍(MessageLoop 全静态、线程安全)。

### 6.5 实验 4:GLib 四步单步迭代可行性(纯 C,shim 前置验证)

对默认 GMainContext 用 `prepare → query → g_poll → check → dispatch` 实现 `poll(timeout)` 契约,场景:250ms 的 GUI 源 + 后台线程 300ms 时 `g_main_context_wakeup`。**第一版实测发现关键坑:`g_main_context_query` 会用内部源最近到期时间覆盖传入的 timeout 上限**(poll(100) 实际等了 251ms;无源时被置 -1 无限等,导致后续轮次挂死)。按外部上限 clamp 后(`wait = min(queried, my_timeout)`,且 queried<0 时用 my_timeout)全绿:

```
[+100ms] poll(100) returned               ← 外部上限生效
[+200ms] poll(100) returned
[+250ms] GUI timeout source dispatched     ← poll(1000) 被 GUI 源提前唤醒
[+250ms] poll(1000) returned after GUI event
[+300ms] waker thread calling g_main_context_wakeup
[+300ms] poll(1000) returned after cross-thread wakeup   ← 跨线程唤醒成功
[+300ms] poll(0) returned immediately      ← 非阻塞模式正确
```

结论:Linux 侧 shim `poll` 接口完全可行,但**必须 clamp**(此坑将直接写进批次 2 实现要点)。

## 7. 四批落地方案校准

原设想:①共存验证 → ②shim 三接口 → ③`yue/async` 子包 → ④异步示例。总体框架成立,校准如下。

### 批次 1:共存验证 —— ✅ 方向对,且本调研已替它完成大半

- 原设想的验证目标(两循环能否同进程、互不破坏)已由实验 3/4 闭环:**能共存,但 run() 阻塞即冻结 async;真共存必须走 ExternalEventLoop**。
- **校准**:批次 1 剩余工作从「验证可行性」缩为「沉淀判据」——把实验 2/2b/3/4 的断言改造成 `experiment/async_coexist/` 的可重跑脚本,作为后续批次的回归基线(本次已沉淀,见实验目录 README)。
- 注意:真正的「yue 真循环 × async」联测必须等批次 2 的接口,批次 1 无法也不需要提前做。

### 批次 2:shim 三接口 —— ✅ 三接口数量/职责对,方向要换、细节要补

原设想按「pump」理解三接口(主循环驱动 async)。校准后的**唯一正确方向**:三接口就是 `ExternalEventLoop` trait 三方法的 C ABI 投影:

| shim 接口(C ABI) | 对应 trait 方法 | Linux 实现 | macOS 实现 | Windows 实现 |
|---|---|---|---|---|
| `yue_mbt_loop_poll(int timeout_ms)`(−1=无限等,0=不等) | `poll(timeout?)` | 默认 GMainContext 四步迭代,**query 结果按外部上限 clamp**(§6.5 实测坑) | `NSApp nextEventMatchingMask:untilDate:` + `sendEvent:` + `updateWindows`(untilDate 由 timeout 换算) | `MsgWaitForMultipleObjectsEx(QS_ALLINPUT, timeout)` + `PeekMessage` 泵一轮 |
| `yue_mbt_loop_wakeup(void)` | `get_wakeup_callback_for_foreign_thread` | `g_main_context_wakeup(default)`(纯 C、任意线程、官方内建唤醒 fd) | `CFRunLoopSourceSignal` + `CFRunLoopWakeUp(CFRunLoopGetMain())` | `PostMessageW(message-only 窗口, 自定义 WM_APP 消息)`——**严禁复用 `yue_mbt_post_task`(其底层 SetTimeout 有 ≥10ms 延迟,§4)** |
| `yue_mbt_loop_terminate(void)` | `terminate` | 多为 no-op( GTK 默认上下文随进程回收);可留作未来状态复位 | 同左 | 同左 |

实现红线(全部源自官方契约 + 实测):

1. `wakeup` 必须**纯 C、线程安全、不碰任何 MoonBit 对象/引用计数**(waiter 专用线程调用;错过唤醒=死锁);
2. `poll` 返回前把本轮 GUI 事件派发完(MessageLoop 的 idle/timeout 源在四步 dispatch 中自然执行,`post_task`/`set_timeout` 语义不变);
3. `poll` 的 GUI 事件回调必须薄(§6.3 漂移实证);
4. 遵循 FFI 规范:`shim/yue_mbt.cpp` 机械转换 + `shim/include/yue_mbt.h` 声明 + `yue/ffi.mbt` extern 三段式;无新链接参数(GLib/CF/User32 均已在链接面);
5. `run()` **保持不变**(非 async 用户不受影响);不提供「手动 pump async」的接口(公共 API 不存在,勿造)。

**落地状态(2026-10-05)**:三接口已实现并合入主链路——`shim/yue_mbt.cpp` 的 `yue_mbt_loop_poll/_wakeup/_terminate`(三平台按上表),`yue/app.mbt` 的 `loop_poll/loop_wakeup/loop_terminate` 薄封装(只暴露 GUI 侧原语,trait 实现留给批次 3 的独立 async 模块,主模块不引入 async 依赖),白盒冒烟 `yue/loop_wbtest.mbt`。Windows 真机验证(moon 0.1.20260904 + MSVC 19.44):shim 增量重编通过、`moon test yue` 67/67、唤醒后 `loop_poll(0)` 返回 1(唤醒消息确被取走);Linux/macOS 待 CI 与真机。实现细节与验证记录回写 `docs/zh/adaptation.md`「外部事件循环」小节。**新发现版本矩阵约束**:async 0.22.4 需 moon ≥ 0.1.20260920(在 0.1.20260904 下其内部源码 `eprintln` 编译失败),0.21.2 可用——批次 3 版本区间据此收窄。

### 批次 3:`yue/async` 子包 —— 形态校准

- **内容**:`YueLoop`(实现 `ExternalEventLoop`,三方法直通 shim 三接口)+ `install()`(GUI 初始化 + `@async.set_external_event_loop`,**必须在 `async fn main` 开头、任何实际 async 代码之前调用**——官方 abort 红线)+ 桥接糖(官方建议的 GUI 事件 → `CondVar`/`Queue` 封装,如 `on_click_async`)+ 退出惯例(如「全部窗口关闭 → task group 返回」的 helper)。
- **依赖隔离(新增注意点)**:mooncakes 依赖是**模块级**的——`yue` 模块一旦 import `moonbitlang/async`,只用 GUI 的用户也会拉取并解析该依赖。两个候选:①主模块不依赖 async,`yue/async` 做成**独立发布的小模块**(如 `NoahLiu/moonbit-libyue-async`,依赖主模块,单向箭头);②接受模块级依赖、靠链接裁剪。**①更符合「最薄依赖」原则,但发布流程翻倍;此决策留给批次 3 落地时定,需实测 moon 对未使用依赖的链接裁剪行为**(已列入待验证清单)。
- **quit 语义翻转要写进文档**:`run()` 退场,程序生命周期 = async main 返回;`quit()` 语义变为「请求主循环停止迭代」由 `terminate` 收尾。
- 版本约束:`moonbitlang/async >= 0.21.0`(external_loop_integration 引入线),建议同时声明上限 `< 0.23`(API experimental,一年 79 版)。

### 批次 4:异步示例 —— 素材就绪,补一条主线卖点

- 素材(官方子包开箱即用):`@async/http` 拉 JSON 刷 Label、`@async/fs` 读文件显进度、`@async/process`/`shell` 跑命令回显终端、`websocket` 实时流。
- 模板:`async fn main { @yue_async.install(); with_task_group(...) }`。
- **主线卖点(写进 README 示例文案)**:所有 MoonBit 代码在主线程,async 回调**直接改 UI、无需 dispatch**——对照 Tauri/PyGObject 的跨线程回投,这是 MoonBit 方案的结构性优势(实验 2 已证同一主线程交替执行)。
- 示例必须演示「重活 spawn_bg、回调薄」的正确姿势(§6.3 反面教材可作对比示例)。

### 方案时序校准小结

原批次顺序 1→2→3→4 保持;唯一变化是批次 1 收口提前(本调研已完成其可完成部分),批次 2 的实现方向从 pump 改为 ExternalEventLoop 投影,批次 3 增加依赖隔离决策点。

## 8. 风险与待验证清单(后续批次逐项消化)

| # | 项 | 现状/证据 | 处置建议 |
|---|---|---|---|
| 1 | 官方 API experimental、高频迭代 | README 声明 + 一年 79 版(§2) | 版本区间锁定;升级走单独批次;CI 加依赖版本巡检 |
| 2 | wakeup 纯 C 红线 | 官方契约 + 死锁警告 | shim 直出 C 函数,MoonBit 侧 `extern "C" fn` 包 `FuncRef`,严禁闭包捕获 |
| 3 | poll 重活 → async 定时器漂移 | 实验 2b(7 倍漂移) | 文档红线 + 示例正确姿势 |
| 4 | GLib query 覆盖 timeout | 实验 4(挂死复现) | shim 内 clamp;写进批次 2 验收用例 |
| 5 | Windows PostTask ≥10ms | 源码 SetTimeout(USER_TIMER_MINIMUM)(§4) | wakeup 走 PostMessageW 独立路线 |
| 6 | signal handler 抢占 | yue `signals.mbt` 与 `@async/signal` 均装 sigaction,后装者赢;官方文档提示 async 会改主线程 signal mask | 批次 3 实测冲突矩阵;必要时 yue/async 文档声明「信号处理二选一」 |
| 7 | 模态对话框/嵌套循环 | `gtk_main` 嵌套计数 vs 手动四步迭代语义差异未验;libyue 模态对话框实现未核对 | 批次 2 Linux 联测时专项验证(对话框开着时 poll 行为) |
| 8 | 未使用依赖的链接裁剪 | 未测(§7 批次 3) | 批次 3 前用最小工程实测产物体积/符号 |
| 9 | deadlock 检测误报 | `run_forever` 的 check_dead_lock 对长期挂起任务会触发(源码 §3.2);GUI「等用户输入」类任务形态相似 | GUI 常驻任务用 `spawn_bg(no_wait=true)`(官方外部循环测试同款用法);必要时 `set_deadlock_handler` 降噪 |
| 10 | timer 冻结恢复语义 | 实验 3:run() 冻结后 timer 按剩余周期重计,非立即补发 | 伪共存模式下文档明示;async 模式不受影响 |

## 9. 引用与复现

- 官方源码:moonbitlang/async 0.22.4(本地解包于实验时;关键文件 `src/external_loop_integration/external_loop.mbt`、`src/internal/event_loop/event_loop.mbt`、`src/integration.mbt`、`src/pkg.generated.mbti`、`examples/tcp_ping_pong/main.mbt`);GitHub https://github.com/moonbitlang/async
- libyue fork 消息循环:`nativeui/gtk/message_loop_gtk.cc`、`nativeui/mac/message_loop_mac.mm`、`nativeui/win/message_loop_win.cc`(lb091188/yue@master);主仓 `vendor/libyue/include/nativeui/message_loop.h`、`shim/yue_mbt.cpp:250,3519-3541`
- mooncakes registry:版本索引 `~/.moon/registry/index/user/moonbitlang/async.index`;搜索 API `mooncakes.io/api/v0/search`
- 实验:全部在 `/tmp` 临时模块完成(moon add moonbitlang/async@0.22.4 + NoahLiu/moonbit-libyue@0.5.9),沉淀于本仓 `experiment/async_coexist/`(复现命令见其 README)
