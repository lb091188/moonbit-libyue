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
  mut dirty : Bool
  mut running : Bool
  /// 上一次投递给焦点控件的组合串（相同内容不重复投递，避免每拍置脏）
  mut last_preedit : (String, Int)
  /// 上一轮输入法服务的控件焦点 id（0 = 无）；换焦点时用来清掉旧控件的组合串
  mut ime_focus : Int
}

///|
/// 平台后端与窗口都建起来才算成功；无显示服务返回 None。
pub fn App::new(width : Int, height : Int, title : String) -> App? {
  if !@win.init_backend() {
    return None
  }
  match @win.Window::new(width, height, title) {
    None => None
    Some(window) => {
      let sched = Loop::new()
      sched.start(@win.now_ms())
      let root = Widget::new()
      let app = {
        window,
        sched,
        root,
        focus: FocusStack::new(),
        dirty: true,
        running: true,
        last_preedit: ("", 0),
        ime_focus: 0,
      }
      window.show()
      window.request_focus()
      // 声明式层的 invalidate() 从这里回到本宿主的脏标（见 node.mbt）
      set_repaint_hook(fn() { app.schedule_paint() })
      Some(app)
    }
  }
}

///|
/// 把声明式节点树挂进根控件（内容入口）。挂载即建控件，之后信号驱动的
/// 重挂走 `bind_node` 的原位替换；挂完标一次脏，下一帧就有内容。
pub fn App::mount(self : App, children : Array[Node]) -> Unit {
  mount_children(self.root, children)
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
/// 退出：只停派发，不拆对象（拆除由调用方在 `run` 返回后做）。
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
      match pev.kind {
        Down => {
          // 按下先把键盘焦点交给命中的可聚焦控件（栈里没有该 id 时不改焦点）
          match self.root.focusable_at(pev.x, pev.y) {
            Some(id) =>
              if !self.focus.is_focused(id) {
                let prev = self.focus.current()
                if self.focus.focus(id) {
                  self.flush_ime_for_switch(prev)
                  self.window.request_focus()
                  self.schedule_paint()
                }
              }
            None => ()
          }
        }
        _ => ()
      }
      if self.root.dispatch_pointer(pev) {
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
  let bm = @render.Bitmap::new(w, h)
  let p = @render.Painter::new(bm)
  self.root.set_size(w.to_double(), h.to_double())
  self.root.relayout(w.to_double(), h.to_double())
  self.root.paint(p)
  p.end()
  self.window.present(bm.data, bm.width, bm.height)
}

///|
/// 走一圈：等事件 → 跑到期任务 → 排空事件 → 喂输入法 → 脏则上屏。
/// 返回是否继续（false = 已退出）。
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
  let mut keep = true
  while keep && self.is_running() {
    match self.window.poll_event() {
      @win.Closing => {
        self.quit()
        keep = false
      }
      @win.NeedsDraw => self.dirty = true
      @win.Resized => self.dirty = true
      @win.Input => {
        match self.window.take_input() {
          Some(ev) => self.route(ev)
          None => ()
        }
      }
      @win.NoEvent => keep = false
    }
  }
  if self.is_running() {
    self.pump_ime()
    if self.dirty {
      self.paint_frame()
    }
  }
  self.is_running()
}

///|
/// 阻塞式主循环。返回后由调用方拆对象（先停派发、再拆对象）。
pub fn App::run(self : App) -> Unit {
  while self.step() {}
}

///|
/// 关闭窗口并释放平台资源。
pub fn App::shutdown(self : App) -> Unit {
  self.window.close()
}
