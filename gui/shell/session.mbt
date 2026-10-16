// 壳层窗（G9 Batch 2 核心切口）：一扇「没有内容」的窗——平台窗口句柄、
// 共用的 `Loop`、注册表键位、泵推进、定时器、退出与输入法通道原语。
// 控件树/脏区/画布归 widget 层（`App = { session, root, … }`），webview / 3D
// 路线只吃本层 + `win`，不必拖进整套自绘控件。
//
// 三条口径沿用 host.mbt（现已收进本文件）：
// ① **主窗**是注册表里的第一扇——关掉主窗即整体退出；关掉附窗只摘自己。
// ② 重绘广播走注入的 sink（widget 层装配时挂上，先例 `set_repaint_hook`）：
//    壳层不认识控件树，只知道「这批要重画」。
// ③ 当前窗（`session_active`）由输入决定；浮层与工具提示跟着它。

///|
pub(all) struct Session {
  mut window : @win.Window
  mut sched : Loop
  mut wid : Int
  mut primary : Bool
  mut closed : Bool
  mut running : Bool
  /// 本窗「该重画」标志：壳层只置位与消费，真正画一帧归 widget 层
  mut dirty : Bool
  /// 上一次投递给焦点控件的组合串（相同内容不重复投递，避免每拍置脏）
  mut last_preedit : (String, Int)
  /// 上一轮输入法服务的控件焦点 id（0 = 无）
  mut ime_focus : Int
  /// 悬停归属与按下捕获（控件 id，-1 = 无）
  mut hover_id : Int
  mut capture : Int
  /// 已下发给窗口的光标形状（只在变了时再走一次 FFI）
  mut cursor_kind : Int
}

///|
/// 关一扇窗之后宿主该不该整体退出：主窗关了退出，或这是最后一扇也退出。
pub fn host_close_action(primary : Bool, remaining : Int) -> Bool {
  primary || remaining <= 0
}

///|
let g_windows : Ref[Array[Session]] = Ref([])

let g_active : Ref[Int] = Ref(0)

let g_next_wid : Ref[Int] = Ref(1)

let g_loop : Ref[Loop?] = Ref(None)

///|
/// 进程内唯一的 `Loop`：首个宿主建它并建立时基，之后每个窗共用同一个。
/// 时基必须由平台单调时钟起算（`Loop::start`），否则首轮 advance 前排的定时器
/// 会全部立刻到期。
pub fn host_loop() -> Loop {
  match g_loop.val {
    Some(l) => l
    None => {
      let l = Loop::new()
      l.start(@win.now_ms())
      g_loop.val = Some(l)
      l
    }
  }
}

///|
/// 取一个新窗号（与平台窗口句柄无关，只作注册表键）。
pub fn host_new_wid() -> Int {
  let id = g_next_wid.val
  g_next_wid.val = id + 1
  id
}

///|
/// 建一扇壳层窗：后端/平台窗建不起来给 None。`popup_of` 与 `place` 要在
/// show 之前定（弹层类型提示与 transient 关系在映射时生效）。
pub fn session_open(
  width : Int,
  height : Int,
  title : String,
  popup_of : @win.Window?,
  place : (Int, Int)?,
) -> Session? {
  if !@win.init_backend() {
    return None
  }
  match @win.Window::new(width, height, title) {
    None => None
    Some(window) => {
      let s : Session = {
        window,
        sched: host_loop(),
        wid: host_new_wid(),
        primary: false,
        closed: false,
        running: true,
        dirty: true,
        last_preedit: ("", 0),
        ime_focus: 0,
        hover_id: -1,
        capture: -1,
        cursor_kind: 0,
      }
      match popup_of {
        None => ()
        Some(o) => window.set_popup(Some(o))
      }
      match place {
        None => ()
        Some(p) => window.move_to(p.0, p.1)
      }
      g_windows.val.push(s)
      s.primary = g_windows.val.length() == 1
      g_active.val = s.wid
      window.show()
      window.request_focus()
      // 建窗即挂系统投放目标（W23a）：后端不可用（非 Windows / OLE 起不来）时
      // 这一步静默失败，应用内拖放照常
      if @win.dragdnd_supported() {
        let _ = @win.dragdnd_enable(window.id)
      }
      Some(s)
    }
  }
}

///|
/// 登记一扇已建好的窗（`App::open_window` 这类「先建壳再挂内容」的入口用）。
pub fn host_add(s : Session) -> Unit {
  s.primary = g_windows.val.length() == 0
  g_windows.val.push(s)
  g_active.val = s.wid
}

///|
/// 摘掉一扇窗（只改注册表，不碰平台窗口——拆对象由调用方按「先停派发」
/// 的顺序做）。
pub fn host_deregister(s : Session) -> Unit {
  let kept : Array[Session] = []
  for a in g_windows.val {
    if a.wid != s.wid {
      kept.push(a)
    }
  }
  g_windows.val = kept
  if g_active.val == s.wid {
    let n = kept.length()
    g_active.val = if n > 0 { kept[n - 1].wid } else { 0 }
  }
}

///|
/// 在窗列表的快照（遍历中可能增删，调用方一律走快照而不是活表）。
pub fn host_windows() -> Array[Session] {
  g_windows.val.copy()
}

///|
pub fn host_window_count() -> Int {
  g_windows.val.length()
}

///|
fn host_window_of(wid : Int) -> Session? {
  for a in g_windows.val {
    if a.wid == wid {
      return Some(a)
    }
  }
  None
}

///|
/// 当前窗：最后被输入（或在建窗时被要过焦点）的那扇；没有窗给 None。
pub fn session_active() -> Session? {
  match host_window_of(g_active.val) {
    Some(a) => Some(a)
    None => {
      let n = g_windows.val.length()
      if n > 0 { Some(g_windows.val[n - 1]) } else { None }
    }
  }
}

///|
pub fn host_mark_active(s : Session) -> Unit {
  g_active.val = s.wid
}

///|
/// 清空注册表并退回未起动态（`App::shutdown` 拆完窗之后调用，
/// 于是同进程再开一窗又会成为主窗）。
pub fn host_reset() -> Unit {
  g_windows.val = []
  g_active.val = 0
  g_loop.val = None
}

///|
/// 进程级重绘广播的落点：widget 层装配时注入（逐窗置脏并唤醒泵）。
/// 壳层不认识控件树，只知道「这批要重画」。
let repaint_sink : Ref[() -> Unit] = Ref(fn() { () })

///|
pub fn set_repaint_sink(f : () -> Unit) -> Unit {
  repaint_sink.val = f
}

///|
/// 泵推进一拍的「等」段：按 `Loop` 的预算等平台事件，再跑到期任务。
/// 排空/输入法/绘制在 widget 层的 `step` 里继续。
pub fn session_pump_advance() -> Unit {
  let l = host_loop()
  let budget = l.wait_budget(@win.now_ms())
  let _ = @win.wait(
    match budget {
      Some(ms) => ms
      None => -1
    },
  )
  let _ = l.advance(@win.now_ms())
}

///|
/// 泵的可等性判断（widget 层 `step` 的开头用）。
pub fn session_pump_running() -> Bool {
  host_loop().is_running()
}

///|
/// 单调时钟（毫秒）。
pub fn session_now_ms() -> Int64 { @win.now_ms() }

///|
/// 退出：只停派发，不拆对象。`Loop` 是各窗共用的，任一窗调它即整体退出。
pub fn Session::quit(self : Session) -> Unit {
  self.sched.quit()
  self.running = false
  @win.wake()
}

///|
pub fn Session::is_running(self : Session) -> Bool {
  self.running && self.sched.is_running()
}

///|
/// 相对延时定时器（转派共用的 `Loop`）。
pub fn Session::timer(self : Session, delay_ms : Int, work : () -> Unit) -> Int {
  self.sched.timer(delay_ms, work)
}

///|
/// 停掉一个周期/延时表。幂等。
pub fn Session::cancel_timer(self : Session, id : Int) -> Bool {
  if self.closed {
    return false
  }
  self.sched.cancel(id)
}

///|
/// 推迟一拍执行（回调里不做重活的旧链路纪律）。
pub fn Session::task(self : Session, work : () -> Unit) -> Unit {
  self.sched.post_task(work)
}

///|
/// 本窗窗号与是否主窗。
pub fn Session::wid(self : Session) -> Int {
  self.wid
}

///|
pub fn Session::is_primary(self : Session) -> Bool {
  self.primary
}

///|
/// 本窗的窗口层门面（标题/尺寸/无边框这类窗口级动作由上层直调 `@win`）。
pub fn Session::window(self : Session) -> @win.Window {
  self.window
}

///|
/// 本窗全屏开关（播放器「铺满整屏」这类窗口级动作）。
pub fn Session::set_fullscreen(self : Session, on : Bool) -> Unit {
  if self.closed {
    return
  }
  self.window.set_fullscreen(on)
}

///|
/// 标脏并唤醒等待中的平台泵（整窗语义的壳层侧：置位 + 唤醒，绘制由
/// widget 层的 step 消费）。
pub fn Session::mark_dirty(self : Session) -> Unit {
  self.dirty = true
  @win.wake()
}

///|
/// 关一扇窗：停派发 → 摘表 → 拆平台窗口（「先停派发、再拆对象」），
/// 再按 `host_close_action` 决定整体退出还是继续跑剩下的窗。幂等。
pub fn Session::close_window(self : Session) -> Unit {
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
/// 测试通道的假会话：句柄取越界值（桩里所有 wm_* 对越界句柄早退），
/// 于是「挂内容 + 注册表 + 浮层」逻辑可以完全不碰平台。生产路径不走这里。
pub fn fake_session(id : Int, wid : Int, primary : Bool, w : Int, h : Int) -> Session {
  let win : @win.Window = { id: id.to_int64(), width: w, height: h }
  {
    window: win,
    sched: host_loop(),
    wid,
    primary,
    closed: false,
    running: true,
    dirty: false,
    last_preedit: ("", 0),
    ime_focus: 0,
    hover_id: -1,
    capture: -1,
    cursor_kind: 0,
  }
}
