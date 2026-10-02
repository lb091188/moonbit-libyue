# async 共存调研实验(async_coexist)

`docs/zh/async-research.md` 的配套可复现实验。**调研产物,不属于主链路**:`lab/` 是独立 moonbit 模块(依赖取 mooncakes 线上 `moonbitlang/async@0.22.4` 与 `NoahLiu/moonbit-libyue@0.5.9`),主仓构建/测试不受影响。

复现环境:Ubuntu 24.04 + X11 + XFCE,moon 0.1.20260920 (914d7da)。

## 实验一览

| 实验 | 位置 | 命令(在 `lab/` 下) | 验证什么 |
|---|---|---|---|
| 1 基础 | `lab/cmd/basic` | `moon run --target native cmd/basic` | `async fn main` 语法、执行器自动驱动、sleep 精度 |
| 2 外部循环共存 | `lab/cmd/fake_gui` | `moon run --target native cmd/fake_gui` | `ExternalEventLoop` 三机制:poll 超时驱动 async timer、waiter 线程跨线程唤醒 poll、GUI 事件在 poll 内处理、terminate 时机 |
| 2b poll 重活代价 | `lab/cmd/fake_gui_busy` | `moon run --target native cmd/fake_gui_busy` | poll 每轮 busy 200ms → async 定时器漂移(官方「poll 不做重活」实证) |
| 3 yue 伪共存 | `lab/cmd/yue_pseudo` | `timeout 60 moon run --target native cmd/yue_pseudo` | yue(线上 0.5.9)×async 同进程:链接共存 OK;`run()` 阻塞期间 async 冻结、返回后恢复 |
| 4 GLib 单步迭代 | `glib_step/` | 见下 | 默认 GMainContext 四步 API 实现带超时的单步 poll + `g_main_context_wakeup` 跨线程唤醒;**实测 query 覆盖 timeout 的坑与 clamp 修法** |

实验 2/2b 的 `fake_gui_loop.c` 是自建的「模拟 GUI 主循环」C stub(非阻塞 pipe 唤醒源),结构对照官方测试模板 `moonbitlang/async/src/external_loop_integration/internal/external_loop_test/external_loop.c`(Linux pipe + poll;Windows 双 Event + WaitForMultipleObjects)——它同时就是未来 shim 三接口(`poll`/`wakeup`/`terminate`)的原型。

## 实验 4 编译运行(纯 C,需 glib 开发包)

```sh
cd glib_step
gcc -o glib_step glib_step.c $(pkg-config --cflags --libs glib-2.0 gthread-2.0) -lpthread
./glib_step
```

## 首测轮关键输出(2026-10-02,/tmp 首测;仓库内复现轮见调研文档 §6)

实验 2(事件条数因 wakeup 时机非确定而略有出入,结构一致):

```
[gui] event #1 handled in poll at +1ms
[async] connecting at +101ms
[gui] event #2 handled in poll at +101ms
[async] connected (waiter woke poll) at +101ms
[async] server accepted at +101ms
[gui] event #3 handled in poll at +101ms
[gui] event #4 handled in poll at +151ms
[async] sleep(300) fired at +301ms
[gui] event #5 handled in poll at +501ms
[async] main end at +601ms
[gui] terminate at +601ms
```

实验 4 未 clamp 的第一版(违反 poll(timeout) 契约的直接证据):

```
[+ 251ms] GUI timeout source dispatched (in poll iteration)   ← poll(100) 却等了 251ms
[+ 251ms] poll(100) returned
[+ 301ms] waker thread calling g_main_context_wakeup
[+ 301ms] poll(100) returned
(随后挂死:无源时 query 把 wait 置 -1 无限等,外部上限 1000ms 失效)
```

clamp 修正后全绿:

```
[+ 100ms] poll(100) returned
[+ 200ms] poll(100) returned
[+ 250ms] GUI timeout source dispatched
[+ 250ms] poll(1000) returned after GUI event
[+ 300ms] waker thread calling g_main_context_wakeup
[+ 300ms] poll(1000) returned after cross-thread wakeup
[+ 300ms] poll(0) returned immediately
[+ 300ms] done
```

## 结论去向

所有结论与四批方案校准建议见 `docs/zh/async-research.md`(§6 实验记录、§7 方案校准、§8 风险清单)。
