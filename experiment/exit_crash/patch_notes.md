# 退出段错误(GTK focus-out 重入)调研笔记

> 调研日期:2026-10-02。环境:Ubuntu 24.04 + X11 + XFCE,libyue v0.15.6-mbt.19
> (vendor/libyue/BUILD_INFO),moon 0.1.x,产物 `_build/native/debug/`。
> 本目录为调研产物,未改动 yue/、shim/、docs/、examples/ 主链路;合入真修复时
> 请按 AGENTS.md 规则 7 同批补写 docs/zh/adaptation.md(文末附记档草稿)。

## 一、结论(TL;DR)

**根因:程序「主动 quit()」(菜单退出/回调内 quit,窗口不经 delete-event 销毁)时,
窗口与全部控件被 `shim` 的句柄注册表 `ViewStore`(id→scoped_refptr 的函数内 static
unordered_map,永不主动清理)持有,一直活到进程 `exit()` 的静态析构期才销毁。
析构期 `nu::Window::~Window → PlatformDestroy → g_object_run_dispose` 销毁 GTK 窗口
时,GTK 把焦点从待销毁的可聚焦控件上移走,同步(不需要消息循环)派发
focus-out-event → libyue `OnFocusOut` → `on_focus_out.Emit` 重入 MoonBit 回调
(button_t 的 bind_focus: `repaint()`)→ 再入 FFI `yue_mbt_view_schedule_paint` →
`ViewStore::get` 对「正在析构中的 unordered_map」做 `find` → 段错误。**

即 adaptation.md:80 记录的 `OnFocusOut → Store<Responder>::get` 栈,触发前提是
「quit 时窗口还活着 + 窗口内有可聚焦控件持有焦点」。偶发性来自 unordered_map
析构的哈希桶顺序:回调重入时 map 处于析构中段,`find` 落在尚完整的链段则「碰巧
不崩」,踩到已摘/将释放的桶则崩(实测崩溃率 1/20 ~ 2/30)。

## 二、证据链

### 2.1 复现(定向探针,全部命令实跑)

复现脚本与本目录探针:
- `repro.sh` / `repro2.sh`:启动 exe → wmctrl 关窗(wmctrl -ic)→ 记退出码。
- `gdbcatch.sh`:gdb -batch 循环跑直到 SIGSEGV,打全栈。
- `probe_exit/`:8 个 button_t,700ms 后程序内 `focus()` 到 3 号,1500ms 后
  **主动 `@yue.quit()`**(复刻「菜单退出/回调内 quit」路径)。
- `probe_exit_nofocus/`:同上但不显式 focus()。
- `probe_exit_labelsonly/`:同上但子控件全用 label_t(不可聚焦)。

实测数据(X11 真机,DISPLAY=:0.0):

| 场景 | 命令 | 结果 |
|---|---|---|
| hello(wmctrl 关窗 ×10)| `repro.sh hello.exe 10` | rc=0 × 10 |
| hello(moon run ×3)| `timeout 20 moon run examples/hello --target native` + wmctrl -ic | rc=0 × 3 |
| hello-themed(有 input_t/button_t,wmctrl 关窗)| `repro.sh 20` / `repro2.sh 15` | rc=0 × 35 |
| probe_exit(focus→主动 quit)| `timeout 10 $EXE` × 20 | **rc=139 × 1 / 20** |
| probe_exit(gdb 第 7 次命中)| `gdbcatch.sh`(断 SIGSEGV + bt 40)| **抓到全栈,见 2.2** |
| probe_exit_nofocus(主动 quit,不显式 focus)| × 30 / × 60 | 崩 2/30、1/60(栈未抓到:gdb 下 ×70 不复现,时序敏感;apport core 属 root 无法读取)|
| probe_exit_labelsonly(纯 label,主动 quit)| × 60 | rc=0 × 60 |

对照结论:**关窗路径(wmctrl -ic / 点 X)不崩;主动 quit + 窗口内有可聚焦控件才崩**;
nofocus 版也偶崩,推断同链——窗口挂出后 XFCE 交 X 焦点,GTK 自动把窗口内部焦点
交给第一个 can_focus 子控件(0 号 button_t),此推断未获直接栈证,以「栈未捕获」
如实记录;labelsonly 全绿把「可聚焦子控件存在」与崩溃强关联。

### 2.2 崩溃全栈(gdb 实录,probe_exit.exe)

```
#0  yue_mbt::Store<nu::Responder>::get(void*)                       ← 崩点:find 踩析构中的 map
#1  yue_mbt_view_schedule_paint()
#2  _M0..yue3yue26ffi__view__schedule__paint
#3  ViewLike::schedule_paint(Container)              yue/view.mbt:276
#4  button_t 内层(on_focus_out→repaint)             yue/components.mbt:2480
#5  bind_focus 的 on_focus_out                       yue/components.mbt:592
#6  ViewLike::on_focus_out wrapped                   yue/methods.mbt:152
#7  ViewLike::on_focus_out                           yue/methods.mbt:154
#8  yue_mbt_view_on_focus_out 的蹦床 lambda          shim/yue_mbt.cpp:5721-5727
#9  nu::OnFocusOut(GtkWidget*, GdkEventFocus*, View*)  libyue view_gtk.cc:106-108
#10-16 glib 信号派发(g_closure_invoke/g_signal_emit)
#17 gtk_widget_send_focus_change                     ← 销毁期同步派发 focus-out
#18-25 GTK dispose 链(g_object_run_dispose)
#26 nu::Window::PlatformDestroy()                    window_gtk.cc:208-213
#27 nu::Window::~Window()                            window.cc:38-44
#29 std::unordered_map<long, scoped_refptr<nu::Responder>>::~unordered_map()   ← ViewStore 正在析构
#30 __run_exit_handlers (exit.c:108)                 ← main 已返回,静态析构期
#31 __GI_exit / #33 _start
```

### 2.3 每一环的源码出处(本仓库 + fork v0.15.6-mbt.19 源码)

1. **quit 不销毁任何东西**:`shim/yue_mbt.cpp:253-255`
   `yue_mbt_quit() = nu::MessageLoop::Quit()`(仅 `gtk_main_quit`,fork
   message_loop_gtk.cc:31-33)。窗口/控件只被 ViewStore 持有。
2. **句柄注册表永不清理、活到 exit**:`shim/include/yue_mbt_internal.h:34-53`
   `Store<T>` 为函数内 static unordered_map,只有 put/get,无 erase/clear;
  MoonBit 侧仅持 int64 句柄,GC 不触发 C++ 释放 → 控件析构唯一时机 =
   exit 静态析构(#29 帧即该 map 的析构函数)。
3. **析构即销毁 GTK 窗口**:`nu::Window::~Window()`(window.cc:38)→
   `PlatformDestroy()`(window_gtk.cc:208)→ `gtk_widget_destroy` →
   `g_object_run_dispose`(#25-26 帧)。
4. **销毁期同步派发 focus-out**:GTK 在 dispose 时用
   `gtk_widget_send_focus_change`(#17 帧)把焦点从待销毁控件移走,
   同步 emit focus-out-event——不需要消息循环存活(gtk_main 已退)。
5. **libyue 直连裸指针回调**:fork view_gtk.cc:329-330
   `g_signal_connect(view, "focus-out-event", G_CALLBACK(OnFocusOut), this)`,
   OnFocusOut(view_gtk.cc:106-108)直接 `view->on_focus_out.Emit(view)`,
   无「消息循环已退出」守卫。
6. **shim 蹦床无守卫地重入 MoonBit**:`shim/yue_mbt.cpp:5721-5727`
   `[invoke, closure](nu::View*) { return invoke(closure) != 0; }`。
7. **MoonBit 回调再入 FFI**:button_t 的 bind_focus(components.mbt:578-598,
   590-593 行 on_focus_out → `repaint()`)→ `ViewLike::schedule_paint`
   (view.mbt:276)→ `yue_mbt_view_schedule_paint`(yue_mbt.cpp:5706-5711)
   → `CastToView` → `Store<Responder>::get`(yue_mbt_internal.h:49-52)
   对**正在析构中的同一张 map** 做 `find` → UB → SIGSEGV。
   (Emit 前拷贝 slots 的机制 signal.h:79-85 保证断言链本身一致,但救不了
   map 半亡时的 find。)

### 2.4 两条退出路径的分岔(为什么关窗不崩)

- **关窗路径**(wmctrl -ic / 点 X):WM 发 delete-event → fork `OnDelete`
  (window_gtk.cc:55-62)→ `window->Close()` → `NotifyWindowClosed()`
  (emit on_close → MoonBit → quit)→ `PlatformDestroy()` **当场销毁窗口**。
  此后 exit 静态析构期各 `~View` 的 PlatformDestroy 全是 no-op(view_ 已空,
  前置 gdb 观测:关窗后 ~View 仍执行 12 次但不再有 focus-out)。
  销毁瞬间的 focus-out 也有(gdb 抓到 2 次,栈顶均为
  `gtk_widget_send_focus_change`,一次源自 focus() 转移、一次源自 OnDelete),
  但发生在主循环存活期,一切健全 → 安全。实测 75+ 次零崩。
- **主动 quit 路径**(菜单 CmdOrCtrl+Q、定时/按钮回调内 quit:
  examples/showcase/main.mbt:299、probe-click:150、probe-bind:62 等):
  on_close 不跑,窗口未销毁、焦点未清 → 一路活到 exit 静态析构 → 本笔记
  第一节的链。

### 2.5 「偶发」的机制

`~unordered_map` 先逐节点销毁(每销毁一个 scoped_refptr 可能触发一次
`~View → gtk_widget_destroy`,窗口项先析构时 GTK 递归销毁整棵子树并派发
focus-out),最后才释放桶数组。回调重入 `find` 时:
- 落在尚未清理的桶/链段 → 命中或 miss,行为「正常」→ 不崩;
- 目标节点已摘或桶数组状态不一致 → 读悬垂指针 → 崩。

哈希桶顺序由句柄 id 的哈希决定,同版本二进制固定,但**哪一项的析构先触发
窗口销毁、以及 window 相对 button 项的先后**,取决于容器内插入序(应用侧
创建序)与桶布局——不同应用、不同退出时焦点位置 → 表现为「偶发」。
adaptation.md:80 当时在 probe-collapse2 抓到一次后难再现,即此概率事件
(探针退出走的正是主动 quit 路径);hello 全 label 无 can_focus 子控件,
根本不满足触发前提。

## 三、修复方案

> 推荐 **A(shim 止血,可立即合入)+ B(fork 根治,随下次 vendor 重发)**。
> 两者叠加双保险;单独 A 即可消除本仓所有 MoonBit 应用的该崩溃。

### 方案 A:shim `yue_mbt_quit` 退出前统一断信号(推荐立即合入)

时机:quit() 仍在 UI 线程、消息循环健全时,遍历 ViewStore 把所有视图的
应用层信号全部 `DisconnectAll()`(signal.h:49-51,清空 slots)。此后 exit 期
`OnFocusOut → Emit` 空槽直接返回,不再重入 MoonBit/FFI,整条链消失。
进程即将退出,断信号不损失任何用户可感知语义。跨平台生效(Windows 的
WM_KILLFUSD 同构风险一并覆盖),无需 `#if`。

线程前提:约定 quit() 在 UI 线程调用(yue 层所有既有调用点——菜单/快捷键/
控件回调/定时器——均满足;Signal 的 vector 非线程安全,若未来允许后台线程
调 quit 需另行评审)。

diff(基于 shim/yue_mbt.cpp:253-255,`<cstring>`/view.h/window.h 均已被
现有代码使用,无新 include):

```diff
--- a/shim/yue_mbt.cpp
+++ b/shim/yue_mbt.cpp
@@ void yue_mbt_quit(void) {
-void yue_mbt_quit(void) {
-  nu::MessageLoop::Quit();
-}
+void yue_mbt_quit(void) {
+  // 主动 quit 的进程,窗口与控件要活到 exit 静态析构期才销毁;销毁瞬间
+  // GTK 会同步派发 focus-out 等事件,经 on_focus_out 蹦床重入已处于析构
+  // 中的句柄注册表与 MoonBit 运行时,偶发段错误(见 experiment/exit_crash/
+  // patch_notes.md)。消息循环尚健全时统一断开全部视图的应用层信号,让
+  // exit 期的信号 Emit 空转。
+  for (auto &kv : yue_mbt::ViewStore::map()) {
+    auto *v = static_cast<nu::View *>(kv.second.get());
+    v->on_focus_in.DisconnectAll();
+    v->on_focus_out.DisconnectAll();
+    v->on_size_changed.DisconnectAll();
+    v->on_drag_leave.DisconnectAll();
+    v->on_mouse_down.DisconnectAll();
+    v->on_mouse_up.DisconnectAll();
+    v->on_mouse_move.DisconnectAll();
+    v->on_mouse_enter.DisconnectAll();
+    v->on_mouse_leave.DisconnectAll();
+    v->on_key_down.DisconnectAll();
+    v->on_key_up.DisconnectAll();
+    v->on_capture_lost.DisconnectAll();
+    if (std::strcmp(v->GetClassName(), nu::Window::kClassName) == 0) {
+      auto *w = static_cast<nu::Window *>(v);
+      w->on_focus.DisconnectAll();
+      w->on_blur.DisconnectAll();
+    }
+  }
+  nu::MessageLoop::Quit();
+}
```

要点:
- `static_cast<nu::View*>` 安全:ViewStore 的 put 实参全为 View 派生对象
  (与既有 CastToView 同款假设,yue_mbt_internal.h:76-82)。
- Window 识别用 `GetClassName()`/`kClassName`(window.h:43),不依赖 RTTI。
- on_close 故意不断:quit 常在 on_close 回调链内被调,Emit 已持 slots 拷贝
  (signal.h:79-85)不断亦安全,且窗口销毁不会二次 Emit,少动一个正在使用
  中的信号。
- 关窗路径同样受益(OnDelete→Close→PlatformDestroy 销毁窗口引发的
  focus-out Emit 也不再进 MoonBit,虽然该路径本就安全)。

### 方案 B:fork 根治(follow-up,随下次 vendor-* 重发)

病灶在 libyue:消息循环退出后,GTK 回调仍可同步进入并 Emit 到应用层。
给 `State` 加 quitting 标志(fork state.h;shim 的 `g_state` 即主线程
State,且为 new 出的泄漏对象,exit 期保证存活——yue_mbt.cpp:236-237),
`MessageLoop::Run/Quit`(GTK 版)维护之,`OnFocusIn/OnFocusOut` 开头短路。

diff(基于 fork lb091188/yue v0.15.6-mbt.19):

```diff
--- a/nativeui/state.h
+++ b/nativeui/state.h
@@ class NATIVEUI_EXPORT State {
  public:
   State();
   ~State();
 
   static State* GetCurrent();
 
   // Internal: Get the state created for the main thread.
   static State* GetMain();
+
+  // Internal: whether the message loop is quitting. After Quit() the teardown
+  // may still synchronously dispatch GTK focus events into views; guards in
+  // gtk event handlers use this to stop re-entering host callbacks with
+  // half-destructed objects.
+  bool is_quitting() const { return is_quitting_; }
+  void set_quitting(bool quitting) { is_quitting_ = quitting; }
 
   // Return the instance of App.
   App* GetApp() { return &app_; }
@@ private:
+  bool is_quitting_ = false;
   (加在既有私有成员区,位置示意)
```

```diff
--- a/nativeui/gtk/message_loop_gtk.cc
+++ b/nativeui/gtk/message_loop_gtk.cc
@@ #include "nativeui/message_loop.h"
 #include <gtk/gtk.h>
+#include "nativeui/state.h"
@@ void MessageLoop::Run() {
-  gtk_main();
+  if (State* s = State::GetMain())
+    s->set_quitting(false);
+  gtk_main();
 }
 
 // static
 void MessageLoop::Quit() {
+  if (State* s = State::GetMain())
+    s->set_quitting(true);
   gtk_main_quit();
 }
```

```diff
--- a/nativeui/gtk/view_gtk.cc
+++ b/nativeui/gtk/view_gtk.cc
@@ #include "nativeui/gtk/util/widget_util.h" (include 区,示意)
+#include "nativeui/state.h"
@@ gboolean OnFocusIn(GtkWidget* widget, GdkEventFocus* event, View* view) {
+  if (State* s = State::GetMain(); s && s->is_quitting())
+    return FALSE;
   return view->on_focus_in.Emit(view);
 }
 
 gboolean OnFocusOut(GtkWidget* widget, GdkEventFocus* event, View* view) {
+  if (State* s = State::GetMain(); s && s->is_quitting())
+    return FALSE;
   return view->on_focus_out.Emit(view);
 }
```

(若 fork 编译器不支持 if 初始化,拆成两行;Run 里重置 false 保证
「quit 后再 Run」语义不被污染。GetMain 用主线程 State:quit 可能来自
任意线程,而 focus 回调恒在主线程。)

落地动作:fork 提交补丁打 tag v0.15.6-mbt.21 → GitHub Actions 出三平台
预编译库 → 本仓 scripts/prepare.py `LIBYUE_VERSION` 升版 + vendor/libyue
更新(prepare.py:36 处常量)。可与 TODO.md 已排队的 fork 根修
(Windows hit-test 错乱、浏览器按需化)合批省一次重发。

### 方案 C:MoonBit 层标志位(仅备选,不推荐单独使用)

yue/app.mbt 的 quit() 置全局 `quitting` 标志,components.mbt 的
bind_focus 等回调开头短路。改动同样小,但:(a) 只挡 focus→repaint 这一条
链,同类重入(其它 signal、未来新控件)挡不住;(b) 仍把「exit 期安全执行
MoonBit 闭包 invoke」当前提,而这个前提本身脆弱(崩点虽在 get,下次可能
更早)。仅当 A、B 都无法立即落地时作临时规避。

## 四、修复验证清单(合入方案 A 后执行)

1. `moon check && moon test` 全仓零错误零警告(提交门槛)。
2. 定向回归:`moon build experiment/exit_crash/probe_exit --target native`
   后裸跑 `timeout 10 $EXE` × 50,应 0 崩(修前基线 1/20);probe_exit_nofocus
   × 60 应 0 崩(修前 1~2/30)。
3. 路径回归:hello / hello-themed / showcase 各 wmctrl 关窗 × 10 正常退出
   (关窗路径行为不变)。
4. gdb 抽查 1 次:quit 后 exit 期 `OnFocusOut` 断点不再命中(修前必命中,
   Emit 空槽,或方案 B 下根本不进 OnFocusOut)。
5. 真机(用户执行):showcase Ctrl+Q 菜单退出 × 10、托盘退出 × 5,观察
   无段错误报告(dmesg / coredump 无新条目)。

## 五、adaptation.md 记档草稿(真修复合入时抄录,小节:Linux/Ubuntu/XFCE)

> **退出段错误(主动 quit 路径, GTK focus-out 重入)已根治**:程序主动
> `quit()`(菜单退出/回调内 quit,窗口不经 delete-event)时,窗口与控件被
> shim 句柄注册表(ViewStore,函数内 static map,永不主动清理)持有,活到
> exit 静态析构期才销毁;析构期 `~Window → g_object_run_dispose` 销毁 GTK
> 窗口时,GTK 同步派发 focus-out(button_t 等可聚焦控件),经 libyue
> OnFocusOut → shim 蹦床重入已半亡的 MoonBit/FFI,`Store<Responder>::get`
> 对正在析构的 map 做 find → 偶发段错误(1/20~2/30,桶顺序决定踩不踩)。
> 关窗路径(OnDelete→Close→当场销毁)不触发。修复:quit 时消息循环健全期
> 统一断开全部视图应用层信号(DisconnectAll),exit 期 Emit 空转;fork 侧
> (≥ mbt.21)另有 State::is_quitting 守卫双保险。复现工具:
> `experiment/exit_crash/probe_exit`(focus→主动 quit,修前 1/20 崩)。
> 教训:**「永不清理的句柄注册表」把控件析构全部推迟到 exit 静态析构期,
> 与 GTK 销毁期同步派发事件叠加,任何信号回调都可能变成 exit 期重入**;
> 给退出路径加「主动有序拆除」(或至少断信号)是这类封装的必备件。

## 六、本目录文件

- `patch_notes.md`:本文。
- `repro.sh` / `repro2.sh`:wmctrl 关窗路径复现器(关窗路径回归用)。
- `gdbcatch.sh`:gdb 循环抓 SIGSEGV 全栈(默认探针可换参)。
- `probe_exit/`:定向复现探针(button_t + focus + 主动 quit)。
- `probe_exit_nofocus/`:不显式 focus 对照(仍偶崩,栈未捕获)。
- `probe_exit_labelsonly/`:纯 label 对照(不崩,锁定可聚焦控件前提)。
