# async 消息泵融合 · 调研记录(feature/async-pump 起点)

调研日期:2026-09-30。对象:`moonbitlang/async@0.22.4`(mooncakes 拉取源码为准)。
结论先行:**官方原生支持外部事件循环集成,GUI 场景被官方文档点名,MVP 走此正道,不走 Timer 轮询**。

## 官方集成通道

- `@async.set_external_event_loop`(native 专用,须在 async 启动前调用,如 `fn init`):
  设置用户自定义事件循环后,async 自身的事件循环(epoll/kqueue 等待部分)挪到**专属线程**,
  **全部 MoonBit 代码仍留在主线程**——与 GUI 主线程要求天然契合。
- 官方文档原话:"some programs, such as GUI programs, have their own event loop,
  and that event loop sometimes must be run in the main thread. In this case,
  `moonbitlang/async` supports running its event loop in a dedicated thread
  internally and integrate with the user-provided loop."
- trait:`@external_loop_integration.ExternalEventLoop`,仅三个方法:
  1. `poll(timeout?)`——主等待函数,即 GUI 泵的**单步迭代**。三种超时语义:
     `Some(0)` 非阻塞立即返回 / `Some(t)` 至多等 t 毫秒 / `None` 无限等待。
     官方建议重活不要在 poll 内直接做,经 `@async.CondVar`/`@async.Queue` 送回 async 侧。
  2. `get_wakeup_callback_for_foreign_thread()`——跨线程唤醒:专属线程有 async 事件时
     唤醒被阻塞的 poll;**漏唤醒会死锁**(官方大写警告)。
  3. `terminate()`——退出清理。

## yue 侧对应原语(shim 需补的探测接口)

| trait 方法 | GTK(Linux 主链路) | Windows | macOS |
|---|---|---|---|
| poll 单步 | `g_main_context_iteration(NULL, may_block)` | `PeekMessage`/`MsgWaitForMultipleObjectsEx` | `CFRunLoopRunInSingleMode`(待核) |
| 跨线程唤醒 | `g_main_context_wakeup(NULL)` | `PostMessage`/`PostThreadMessage` | `CFRunLoopWakeUp`(待核) |
| terminate | wakeup 即可 | 同左 | 同左 |

均为 shim 一行级接口,按 AGENTS 既有「libyue 未暴露由 shim 补」流程走
(`shim/yue_mbt.cpp` → `yue_mbt.h` → `yue/ffi.mbt` extern → `yue/async` 子包)。

## 已知约束与风险

- 官方 async 的 native 后端**仅 Linux/macOS**(README 明示;Windows IOCP 列于特性但未支持):
  Windows 侧 `yue/async` 须 cfg 排除或降级(Timer 轮询兜底或干脆不支持),策略实施时定。
- 库自标实验性("API is subject to future change"),`yue/async` 的依赖声明要留版本弹性。
- 官方文档提示集成后 async 仍可能改主线程状态(如 signal mask),与 libyue Lifetime 的
  初始化时序交互需真机验证。
- 链接共存(async 的 C runtime/pthread/epoll 与 yue 静态库)未完成验证:/tmp 探针模块
  646 个 check 错误是**临时模块 prebuild 未跑通**(消费方项目根无原生层产物路径,ffi_*
  符号未绑),非符号冲突;实施第一批先在仓库环境把共存验证做掉。

## 探针代码(/tmp 荒废前留档)

```moonbit
// 链接共存探针:不启用 async event loop,仅引入符号与 GUI 同链
fn main {
  let q = @async.Queue::new()  // async 侧符号
  let _w = @yue.mount_window(
    [ @yue.label("async + yue coexist probe", style=[("margin", 20.0)]),
      @yue.button("quit", on_click=fn() { @yue.quit() }) ],
    title="probe", size=Some((360.0, 140.0)), center=true,
    on_close=fn(_w) { @yue.quit() },
  )
  ignore(q)
  @yue.run()
}
```

## 实施批次草案

1. **共存验证**:仓库内(或修通 prebuild 的临时模块)yue+async 同链编译、GUI 冒烟。
2. **shim 三接口**:iterate/wakeup/terminate,GTK 先行,`nm` 验符号,Linux 真机冒烟。
3. **`yue/async` 子包**:`GuiLoop` 实现 `ExternalEventLoop` + `set_external_event_loop` 引导,
   与 `@yue.mount_window`/`run` 的驱动权交接方式实测定型(主循环由 async event_loop 编排)。
4. **示例与文档**:`examples/` 加异步示例(HTTP 拉数据刷新图表),三步走完再议 Windows/macOS。
