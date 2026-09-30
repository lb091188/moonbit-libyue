# launcher 实战反馈 · 对库的借鉴清单(feature/async-pump 归档)

来源:sess_b3475d75(坦克游戏 launcher,以 moonbit-libyue@0.5.8 做 GUI + moonbitlang/async 集成,
debug/release 全链路自动化验收通过)。本文只收录**对库本身有价值**的发现,游戏侧细节不展开。

## 一、async pump:现成参考实现,直接吸收

- **`yue_pump.c`(~50 行)实战通过**:Linux `g_main_context_iteration`(libyue UI 泵即
  MessagePumpGlib/默认主上下文)+ `g_main_context_wakeup`;Windows `MsgWaitForMultipleObjectsEx
  + PeekMessage` + `PostThreadMessage`。与我们 research 文档的对照表一致,设计可定稿。
- **wakeup 回调运行在 async 辅助线程 → 必须纯 C 实现,不得触碰 MoonBit GC/闭包**(跨线程调
  MoonBit 回调是雷);头文件手工声明所需 glib/Win32 符号。
- **官方 C stub 模板**:`~/.moon/cache/deps/v1/sources/moonbitlang/async/<ver>/src/external_loop_integration/internal/external_loop_test/main.mbt`
  (4 个 extern "C" + Cond 通知),`yue/async` 的 event_loop.mbt 照此骨架。
- **UI 回调(同步世界)→ async 的命令桥**:Mutex+Array+Cond(200ms 轮询)可用但糙;官方推荐
  `@async.CondVar`/`@async.Queue`。集成后 MoonBit 代码全主线程,桥的负担应大减——
  `yue/async` 文档要给出官方姿势。
- **上游 async 坑(0.22.1 实测)**:`with_task_group` cancel 后永不退出(spawn 收尸任务遗留
  挂死),绕法:任务内 try_wait 轮询自收尸或 C stub SIGTERM;`@process` Windows 终止信号仅
  SIGBREAK、`Process::cancel()` 不杀子进程须 `cancel_handler=graceful_cancel(...)`;
  管道 `read_until` 会挂死 → 日志走文件重定向 + 500ms 尾部轮询。示例选型避开这些模式。

## 二、库 bug(待复现与修复,按严重度排序)

1. **退出段错误(最严重)**:GUI 退出时 GTK 拆控件,焦点输入框触发 focus-out 回调,引用的
   C++ 对象已析构 → 段错误(gdb 实证)。用户被迫 C stub `_exit()` 跳过静态析构绕过。
   我们 hello/showcase 退出没炸大概率是场景未覆盖(带焦点输入框的窗口)。
   方向:quit 路径先解绑/失效化事件回调再拆控件(shim 或 fork 层)。
2. **bind_node 重挂在 Windows 命中错乱**:remove+add 子节点致鼠标命中测试错乱(点击劫持/
   失效,某操作直接 exit -1,Windows CI 实证);安全绕法 display:none 显隐。
   与 9-24 回退链的「原生 HWND 混排同步层」同区。至少入档 adaptation Windows 小节 +
   组件文档明示「Windows 上显隐用 display:none,勿 remove/add」。
3. **`set_attributed_text` 不自发重绘**:文本更新后画面不动,须手动 `schedule_paint`。
   查 yue 侧是否统一补(schedule_paint 应随文本变更自动触发)。
4. **bind_label 宽度不随文本**:set_text 后停在挂载时宽度,长文本截断,需强制重排。
   label 尺寸自适应缺自动 invalidate。

## 三、API 改进(向后兼容地补)

- **bind 族类型不对称**:`bind_node` 只收 `Signal[T]` 不收 Store(要手动 `Store::signal()`)。
  统一为两者皆收。
- **Store API 面弱**:set 不去重、subscribe 注册时不回调初始值、无退订。对照 Signal 的
  batch/computed 补齐。
- **stderr 被吞**:GUI 进程 stderr 消失,诊断只能写文件。调查 libyue/平台层原因,至少
  文档记绕法(文件重定向)。
- **table_t 排序裸奔**:排序要用户自己订阅 Store 排回写。组件库内置 sortable 列头(roadmap)。
- **FileDialog 模态阻塞非 async**:yue/async 集成的后续 async 化候选。
- **组件缺口(真实桌面应用画像)**:launcher 用到配置页/启停/日志滚动/剪贴板复制/战绩表格——
  「自动滚动的日志视图」值得进组件库 roadmap。

## 四、测试手法(对 CI 冒烟有直接价值)

- **环境变量驱动的自演脚本**(SF_AUTOSTART 模式)取代 xdotool 坐标点击——坐标漂移不可靠,
  自动模式下程序自己走完验收路径并以退出码报告。我们 xvfb 冒烟可升级为此模式
  (hello 自演:开窗→点按钮→quit,rc=0 即过,比「存活 20 秒」断言更强)。
- **自动化前置清理**:`pkill -x <精确名>` / `fuser -k <端口>/tcp`(注意 `pkill -f` 会自杀);
  改代码后必须重 build 再测。
- xdotool 截图配套:`xdotool search --name <标题>` + `import -window`。

## 落位

- 一 → 更新 experiment/async-pump-research.md 的实施草案(shim 设计可定稿);
- 二 → 逐项复现后进 master 修复批次(退出段错误优先);
- 三 → TODO.md 候选池;四 → CI 冒烟升级候选(独立小批)。
