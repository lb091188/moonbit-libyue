// App 宿主：把「窗口 + 事件循环 + 控件树 + 输入法通道 + 上屏」收成一处，
// 分层依据方案 §2 包表（App/Window、脏区重绘、命中测试、组件宿主同在 `yue/core`）。
//
// 一条重要的分层约束：`yue/input` 已经依赖 `yue/core`，所以本包**不能**反向依赖
// input（会成环）。编辑器与宿主的接缝因此做成控件回调形态——`on_key` /
// `on_commit` / `on_preedit` / `im_context` / `im_cursor` 五者由持有 Editor 的
// 控件自己实现，宿主只负责按焦点投递与喂系统输入法通道。这正是 G5b 记档的
// `TextEditorHost` 收口形态（四签名 process_key/commit/preedit/set_cursor_rect
// 逐一对应，只是从「一个 host 对象」换成「焦点控件的回调表」）。
//
// 三条既有纪律在这里继续成立（见 adaptation 的 G2/G4/G5 条）：时基必须先
// `Loop::start`；置脏必须 `@win.wake()` 否则睡在 `wait` 里的循环不会醒；
// 输入法每拍只喂**已提交**文本，`im_reset` 只在逻辑焦点换控件那一瞬调一次
// （每拍调会一直打断组合，见 `Window::im_reset` 注释）。

///|
pub(all) struct App {
  window : @win.Window
  sched : Loop
  root : Widget
  focus : FocusStack
  /// 本窗的浮层宿主（图层挂在 root 上；多窗时浮层开在当前窗的那层）
  host : OverlayHost
  /// 注册表里的窗号（见 host.mbt）
  mut wid : Int
  /// 主窗：注册表里的第一扇，关掉它即整体退出
  mut primary : Bool
  /// 已拆过窗（close_window/shutdown 幂等）
  mut closed : Bool
  mut dirty : Bool
  mut running : Bool
  /// 上一次投递给焦点控件的组合串（相同内容不重复投递，避免每拍置脏）
  mut last_preedit : (String, Int)
  /// 上一轮输入法服务的控件焦点 id（0 = 无）；换焦点时用来清掉旧控件的组合串
  mut ime_focus : Int
  /// 悬停归属与按下捕获（控件 id，-1 = 无）。按下后到松手之前，移动与抬起
  /// 都投给被按下的控件（`Widget::dispatch_pointer_to`），指针离开它也不会
  /// 卡住按下态，拖选/拖动插入点才有依据
  mut hover_id : Int
  mut capture : Int
  /// 已下发给窗口的光标形状（只在变了时再走一次 FFI）
  mut cursor_kind : Int
}

///|
/// 单调时钟（毫秒）。声明式组件的双击判定等要它；无后端时返回 0。
pub fn now_ms() -> Int64 { @win.now_ms() }

///|
/// 系统深浅偏好（"dark" / "light" / ""）与系统主色（"#rrggbb" / ""）：
/// 窗口层只读探针的转发（与 `local_ymd` 同理，示例与集成层不必引用平台包）。
pub fn sys_color_scheme() -> String {
  @win.sys_color_scheme()
}

///|
pub fn sys_accent() -> String {
  @win.sys_accent()
}

///|
/// 本地时区的今天 (年, 月, 日)。平台给不出时返回 (0, 0, 0)——组件层据此退回
/// 自己的兜底值，本层不猜日期。
pub fn local_ymd() -> (Int, Int, Int) {
  let v = @win.local_date()
  if v <= 0L {
    (0, 0, 0)
  } else {
    let iv = v.to_int()
    (iv / 10000, iv % 10000 / 100, iv % 100)
  }
}

///|
/// 装进程级挂钩（多窗形态只有一套）：重绘请求广播给所有在窗、浮层按当前窗取
/// 宿主、延时定时器走共用的 `Loop`。每建一扇窗都装一遍，装的是同一组闭包，
/// 重复安装没有副作用（无头测试自装的静态宿主会在下一扇窗建好时被接管）。
fn install_host_hooks() -> Unit {
  set_repaint_hook(fn() { host_repaint_all() })
  set_overlay_provider(fn() -> OverlayHost? {
    match host_active() {
      Some(a) => Some(a.host)
      None => None
    }
  })
  let l = host_loop()
  set_timer_hooks(
    fn(ms : Int, f : () -> Unit) -> Int { l.timer(ms, f) },
    fn(id : Int) -> Unit {
      // 到期项已移除时 cancel 返回 false，不必上抛
      let _ = l.cancel(id)
    },
  )
}

///|
/// 建一扇窗并登记进注册表：注册表还空即主窗，否则是附窗（共用同一个 `Loop`
/// 与平台泵）。平台后端与窗口都建起来才算成功，无显示服务返回 None。
fn app_window(
  width : Int,
  height : Int,
  title : String,
  popup_of : @win.Window?,
  place : (Int, Int)?,
) -> App? {
  if !@win.init_backend() {
    return None
  }
  match @win.Window::new(width, height, title) {
    None => None
    Some(window) => {
      let root = Widget::new()
      let app : App = {
        window,
        sched: host_loop(),
        root,
        focus: FocusStack::new(),
        host: make_overlay_host(root),
        wid: host_new_wid(),
        primary: false,
        closed: false,
        dirty: true,
        running: true,
        last_preedit: ("", 0),
        ime_focus: 0,
        hover_id: -1,
        capture: -1,
        cursor_kind: 0,
      }
      // 弹层形态要在 show 之前定（类型提示与 transient 关系在映射时生效）
      match popup_of {
        None => ()
        Some(o) => window.set_popup(Some(o))
      }
      match place {
        None => ()
        Some(p) => window.move_to(p.0, p.1)
      }
      host_add(app, host_window_count() == 0)
      window.show()
      window.request_focus()
      install_host_hooks()
      Some(app)
    }
  }
}

///|
/// 首个宿主入口（主窗）。再要一扇窗用 `App::open_window`，或在本表已空时
/// 再调一次本函数（那扇又成主窗）。
pub fn App::new(width : Int, height : Int, title : String) -> App? {
  app_window(width, height, title, None, None)
}

///|
/// 再开一扇窗：每窗一棵控件树、一套焦点栈与输入法状态，**共用**宿主的循环与泵。
/// 关掉它不影响宿主存活（只有主窗或最后一扇被关才整体退出）；内容照挂
/// `win.mount([...])`，事件路由与上屏在 `App::step` 里逐窗走。
pub fn App::open_window(self : App, width : Int, height : Int, title : String) -> App? {
  let _ = self
  app_window(width, height, title, None, None)
}

///|
/// 在窗数与当前窗（诊断与测试用）。注册表是进程级的，`self` 只作调用点锚。
pub fn App::window_count(self : App) -> Int {
  let _ = self
  host_window_count()
}

///|
pub fn App::active_window(self : App) -> App? {
  let _ = self
  host_active()
}

///|
/// 本窗窗号与是否主窗。
pub fn App::wid(self : App) -> Int {
  self.wid
}

///|
pub fn App::is_primary(self : App) -> Bool {
  self.primary
}

///|
/// 跟随系统深浅/主色：每 `interval_ms` 读一次系统偏好，变了就 `theme_apply`
/// （订阅了主题变更的组件即时重着色，不重建界面）。返回停表函数。
///
/// 放在窗口层而不是 `yue/theme`：主题包不该反过来依赖平台后端与事件循环。
/// 桌面环境没有对应通道（非 GNOME、或 schema 缺键）时读出来是空串，
/// 于是按亮色预设走，且此后每拍都不变、不会反复重刷。
pub fn App::follow_system_theme(self : App, interval_ms? : Int = 1000) -> () -> Unit {
  let running : Ref[Bool] = Ref(true)
  let tick : Ref[() -> Unit] = Ref(fn() { () })
  tick.val = fn() -> Unit {
    if !running.val || !self.is_running() {
      running.val = false
      return
    }
    let t = @theme.theme_from_system(
      fn() -> String { @win.sys_color_scheme() },
      fn() -> String { @win.sys_accent() },
    )
    if @theme.theme_fingerprint_of(t) != @theme.theme_fingerprint_of(@theme.theme_current()) {
      @theme.theme_apply(t)
    }
    let _ = self.timer(interval_ms, tick.val)
  }
  (tick.val)()
  fn() -> Unit { running.val = false }
}

///|
/// 把声明式节点树挂进根控件（内容入口）。挂载即建控件，之后信号驱动的
/// 重挂走 `bind_node` 的原位替换；挂完标一次脏，下一帧就有内容。
/// 多窗时每窗挂自己那棵，浮层图层升回自己那层的最后。
pub fn App::mount(self : App, children : Array[Node]) -> Unit {
  mount_children(self.root, children)
  // 新挂的内容会排在浮层图层之后，把**本窗**的图层挪回最后
  self.host.raise_layer()
  self.schedule_paint()
}

///|
/// 标脏并唤醒等待中的平台泵（供控件回调与定时器使用）。
pub fn App::schedule_paint(self : App) -> Unit {
  self.dirty = true
  @win.wake()
}

///|
/// 相对延时定时器（转派 `Loop::timer`，返回可取消的句柄）。
pub fn App::timer(self : App, delay_ms : Int, work : () -> Unit) -> Int {
  self.sched.timer(delay_ms, work)
}

///|
/// 推迟一拍执行（回调里不做重活的旧链路纪律）。
pub fn App::task(self : App, work : () -> Unit) -> Unit {
  self.sched.post_task(work)
}

///|
/// 退出：只停派发，不拆对象（拆除由调用方在 `run` 返回后做）。`Loop` 是各窗
/// 共用的，所以任一窗调它即整体退出。
pub fn App::quit(self : App) -> Unit {
  self.sched.quit()
  self.running = false
  @win.wake()
}

///|
pub fn App::is_running(self : App) -> Bool {
  self.running && self.sched.is_running()
}

///|
/// 焦点真要换控件时的**前置**动作（必须在改焦点栈之前调）：
/// - 把输入法已经排队的提交文本交还**旧**控件——这些提交是旧控件的按键产生的，
///   晚一拍排空就会落进新控件（真机实测：在 A 框打的字 commit 进了 B 框）；
/// - 清掉旧控件画着的组合串；
/// - `im_reset` 打断输入法侧未完成的组合串（一个窗口只有一个 IM 上下文）。
fn App::flush_ime_for_switch(self : App, prev : Int?) -> Unit {
  match prev {
    Some(id) => {
      let mut more = true
      while more {
        match self.window.take_commit() {
          Some(t) => {
            if self.root.dispatch_commit(id, t) {
              self.schedule_paint()
            }
          }
          None => more = false
        }
      }
      if self.last_preedit.0.length() > 0 {
        self.root.dispatch_preedit(id, "", 0)
        self.last_preedit = ("", 0)
      }
    }
    None => ()
  }
  self.window.im_reset()
  self.ime_focus = 0
}

///|
/// 焦点栈移动 + 把键盘焦点重新要到窗口上 + 重绘。
pub fn App::move_focus(self : App, backward : Bool) -> Unit {
  let prev = self.focus.current()
  let next = self.focus.move_focus(backward)
  if next != prev {
    self.flush_ime_for_switch(prev)
  }
  self.window.request_focus()
  self.schedule_paint()
}

///|
/// 原始事件的归类型。`yue/win` 的 code 语义：0 键按下 1 键抬起 2 按钮按下
/// 3 按钮抬起 4 指针移动 5 滚轮；两个数据槽按 C 侧 `WmEv.dx/dy` 命名，
/// 到 MoonBit 是 `button`（dx：按钮号或滚轮横向）与 `axis`（dy：滚轮纵向，
/// 正=上滚）。
pub(all) enum RawEvent {
  Key(KeyEvent)
  Pointer(PointerEvent)
  Scroll(ScrollEvent)
  Ignored
}

///|
/// 原始事件 → 本层事件形态。独立成函数是为了无头可测（宿主其余部分要窗口）。
pub fn raw_to_event(
  code : Int,
  keysym : Int,
  mods : Int,
  x : Int,
  y : Int,
  button : Int,
  axis : Int,
) -> RawEvent {
  let xf = x.to_double()
  let yf = y.to_double()
  if code == 0 || code == 1 {
    Key({ press: code == 0, keysym, mods, })
  } else if code == 2 || code == 3 || code == 4 {
    Pointer({
      kind: if code == 2 {
        Down
      } else if code == 3 {
        Up
      } else {
        Move
      },
      x: xf,
      y: yf,
      button,
      mods,
    })
  } else if code == 5 {
    Scroll({ x: xf, y: yf, dx: button.to_double(), dy: axis.to_double(), mods, })
  } else {
    Ignored
  }
}

///|
fn App::route(self : App, ev : @win.InputEvent) -> Unit {
  // 谁被操作谁就是当前窗（浮层与工具提示跟着它，见 host.mbt）
  host_mark_active(self)
  match raw_to_event(
    ev.code,
    ev.keysym,
    ev.mods,
    ev.x,
    ev.y,
    ev.button,
    ev.axis,
  ) {
    Ignored => ()
    Pointer(pev) => {
      let r = route_pointer(self.root, pev, self.hover_id, self.capture)
      self.hover_id = r.0
      self.capture = r.1
      // 光标形状随悬停路径走（拖动期间被捕获，形状停在起手那档）
      let wants_cursor = match pev.kind {
        Move => true
        _ => false
      }
      if wants_cursor {
        let want = self.root.cursor_at(pev.x, pev.y)
        if want != self.cursor_kind {
          self.cursor_kind = want
          self.window.set_cursor(want)
        }
      }
      match pev.kind {
        Down => {
          // 按下把键盘焦点交给命中的可聚焦控件（栈里没有该 id 时不改焦点）
          match self.root.focusable_at(pev.x, pev.y) {
            Some(id) =>
              if !self.focus.is_focused(id) {
                let prev = self.focus.current()
                if self.focus.focus(id) {
                  self.flush_ime_for_switch(prev)
                  self.window.request_focus()
                }
              }
            None => ()
          }
        }
        _ => ()
      }
      if r.2 || r.3 {
        self.schedule_paint()
      }
    }
    Scroll(sev) => {
      if self.root.dispatch_scroll(sev) {
        self.schedule_paint()
      }
    }
    Key(kev) => {
      // Tab / Shift+Tab 由宿主消费并驱动焦点栈（GTK 可能给 ISO_Left_Tab）
      if kev.press && (kev.keysym == KS_TAB || kev.keysym == KS_ISO_LEFT_TAB) {
        self.move_focus(
          kev.keysym == KS_ISO_LEFT_TAB || (kev.mods & MOD_SHIFT) != 0,
        )
        return ()
      }
      let consumed = match self.focus.current() {
        Some(id) => self.root.dispatch_key(id, kev)
        None => false
      }
      if consumed {
        self.schedule_paint()
      }
    }
  }
}

///|
/// 输入法四条件里的后两条在此收口：每拍喂 surrounding + 插入符矩形，
/// 取走 commit 与组合串投给焦点控件（只喂已提交文本，不调 reset）。
pub fn App::pump_ime(self : App) -> Unit {
  let cur = match self.focus.current() {
    Some(id) => id
    None => 0
  }
  if cur != self.ime_focus {
    // 兜底：上层直接改了焦点栈（没走 move_focus / 点击接管）时，旧控件画着的
    // 组合串要清掉，去重缓存一并复位。真正的前置清理见 flush_ime_for_switch。
    if self.ime_focus != 0 && self.last_preedit.0.length() > 0 {
      self.root.dispatch_preedit(self.ime_focus, "", 0)
    }
    self.ime_focus = cur
    self.last_preedit = ("", 0)
  }
  if cur == 0 {
    return ()
  }
  match self.root.im_context_of(cur) {
    None => ()
    Some((text, caret)) => {
      self.window.set_im_surrounding(text, caret)
      match self.root.im_cursor_of(cur) {
        Some(r) => self.window.set_im_cursor(
          r.x.floor().to_int(),
          r.y.floor().to_int(),
          r.w.ceil().to_int(),
          r.h.ceil().to_int(),
        )
        None => ()
      }
      let mut more = true
      while more {
        match self.window.take_commit() {
          Some(t) => {
            if self.root.dispatch_commit(cur, t) {
              self.schedule_paint()
            }
          }
          None => more = false
        }
      }
      let st = self.window.preedit()
      if st.text != self.last_preedit.0 || st.caret != self.last_preedit.1 {
        self.last_preedit = (st.text, st.caret)
        self.root.dispatch_preedit(cur, st.text, st.caret)
        self.schedule_paint()
      }
    }
  }
}

///|
/// 一帧的绘制：根控件恒等尺寸取窗口内容尺寸，布局→绘制→上屏。
pub fn App::paint_frame(self : App) -> Unit {
  self.dirty = false
  let (w, h) = self.window.size()
  if w < 1 || h < 1 {
    return ()
  }
  // 绘制前同步一次焦点标志：焦点栈、控件树、重挂都可能在上一拍改过
  match self.focus.current() {
    Some(id) => self.root.set_focused_by_focus(id)
    None => self.root.set_focused_by_focus(0)
  }
  let bm = @render.Bitmap::new(w, h)
  let p = @render.Painter::new(bm)
  self.root.set_size(w.to_double(), h.to_double())
  self.root.relayout(w.to_double(), h.to_double())
  self.root.paint(p)
  p.end()
  self.window.present(bm.data, bm.width, bm.height)
}

///|
/// 走一圈：等事件 → 跑到期任务 → **逐窗**排空事件 → 逐窗喂输入法 → 脏窗上屏。
/// 返回是否继续（false = 已退出）。一扇窗被关（用户点关闭、或内容里调
/// `App::close_window`）只摘掉它自己，主窗或最后一扇被关才整体退出。
pub fn App::step(self : App) -> Bool {
  if !self.is_running() {
    return false
  }
  let budget = self.sched.wait_budget(@win.now_ms())
  let _ = @win.wait(
    match budget {
      Some(ms) => ms
      None => -1
    },
  )
  let _ = self.sched.advance(@win.now_ms())
  // 遍历一律走快照：排空途中关窗会改注册表
  for a in host_windows() {
    a.drain_events()
  }
  if !self.is_running() {
    return false
  }
  for a in host_windows() {
    a.pump_ime()
    if a.dirty {
      a.paint_frame()
    }
    // 原生档浮层：首帧后按内容实测尺寸收框（最多三帧，见 overlay_native.mbt）
    overlay_fit_pass(a)
  }
  self.is_running()
}

///|
/// 排空本窗的平台事件。
fn App::drain_events(self : App) -> Unit {
  let mut keep = true
  while keep && self.is_running() {
    match self.window.poll_event() {
      @win.Closing => {
        self.close_window()
        keep = false
      }
      @win.NeedsDraw => self.dirty = true
      @win.Resized => self.dirty = true
      @win.LostFocus => overlay_on_lost_focus(self)
      @win.Input => {
        match self.window.take_input() {
          Some(ev) => self.route(ev)
          None => ()
        }
      }
      @win.NoEvent => keep = false
    }
  }
}

///|
/// 关一扇窗：停派发 → 摘表 → 拆平台窗口（顺序是「先停派发、再拆对象」），
/// 再按 `host_close_action` 决定整体退出还是继续跑剩下的窗。
/// 幂等：重复调用（用户点关闭 + 内容里自己调）只生效一次。
pub fn App::close_window(self : App) -> Unit {
  if self.closed {
    return
  }
  self.closed = true
  self.running = false
  let remaining = host_window_count() - 1
  host_deregister(self)
  self.window.close()
  if host_close_action(self.primary, remaining) {
    self.sched.quit()
    @win.wake()
  }
}

///|
/// 阻塞式主循环。返回后由调用方拆对象（先停派发、再拆对象）。
pub fn App::run(self : App) -> Unit {
  while self.step() {}
}

///|
/// 关闭窗口并释放平台资源：把**所有**还在的窗一起拆掉（附窗可能还开着），
/// 注册表随之复位。已拆过的窗句柄是 -1，`wm_close` 幂等，重复调无害。
pub fn App::shutdown(self : App) -> Unit {
  for a in host_windows() {
    a.running = false
    a.closed = true
    a.window.close()
  }
  overlay_close_all_native()
  self.running = false
  if !self.closed {
    self.closed = true
    self.window.close()
  }
  host_reset()
}
