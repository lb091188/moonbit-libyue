// 窗口注册表（批 A）：一宿主管 N 窗。
//
// 一条窗（一个 `App`）= 一个平台窗口 + 一棵控件树 + 一套焦点/输入法/悬停状态；
// 窗与窗之间**只共用两样**：`Loop`（定时器与延时的唯一时基）与平台泵
// （`@win.wait`/`wake` 是进程级的，一进程只有一个事件循环）。因此本文件只管
// 「有哪些窗、当前是哪扇、关一扇之后退不退」，单窗的绘制与事件语义仍在 app.mbt。
//
// 三条口径：
// ① **主窗**是注册表里的第一扇——关掉主窗即整体退出；关掉附窗只摘自己，
//    宿主继续跑（这是「关于」窗、二次编辑窗这类形态的前提）。
// ② `invalidate()` 走的是进程级重绘钩子，多窗时**广播**给所有在窗（一次置脏
//    + 一次唤醒）。跨窗共享的 Store/信号本来就该两边都重画；单窗被多余置脏
//    只多一帧重排，不会画错。
// ③ 当前窗（`host_active`）决定浮层开在哪扇窗上：新窗建好即当前窗，
//    哪扇窗收到输入就切到哪扇，当前窗被关掉则退回注册表里最后一扇。

///|
/// 关一扇窗之后宿主该不该整体退出：主窗关了退出，或这是最后一扇也退出。
/// 独立成纯函数是为了无头可测（注册表其余部分要 `App` 值）。
pub fn host_close_action(primary : Bool, remaining : Int) -> Bool {
  primary || remaining <= 0
}

///|
let g_windows : Ref[Array[App]] = Ref([])
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
/// 登记一扇窗（`primary` 由调用方按「注册表是否还空」定）。
pub fn host_add(app : App, primary : Bool) -> Unit {
  app.primary = primary
  g_windows.val.push(app)
  host_mark_active(app)
}

///|
/// 摘掉一扇窗（只改注册表，不碰平台窗口——拆对象由调用方按「先停派发」的顺序做）。
pub fn host_deregister(app : App) -> Unit {
  let kept : Array[App] = []
  for a in g_windows.val {
    if a.wid != app.wid {
      kept.push(a)
    }
  }
  g_windows.val = kept
  if g_active.val == app.wid {
    let n = kept.length()
    g_active.val = if n > 0 { kept[n - 1].wid } else { 0 }
  }
}

///|
/// 在窗列表的快照（遍历中可能增删，调用方一律走快照而不是活表）。
pub fn host_windows() -> Array[App] {
  g_windows.val.copy()
}

///|
pub fn host_window_count() -> Int {
  g_windows.val.length()
}

///|
fn host_window_of(wid : Int) -> App? {
  for a in g_windows.val {
    if a.wid == wid {
      return Some(a)
    }
  }
  None
}

///|
/// 当前窗：最后被输入（或在建窗时被要过焦点）的那扇；没有窗给 None。
pub fn host_active() -> App? {
  match host_window_of(g_active.val) {
    Some(a) => Some(a)
    None => {
      let n = g_windows.val.length()
      if n > 0 { Some(g_windows.val[n - 1]) } else { None }
    }
  }
}

///|
pub fn host_mark_active(app : App) -> Unit {
  g_active.val = app.wid
}

///|
/// 广播置脏 + 唤醒等待中的平台泵（`invalidate()` 的宿主侧落点）。
/// 整窗语义：跨窗共享的信号变化拿不准各窗哪些区域受影响，一律全量。
pub fn host_repaint_all() -> Unit {
  for a in g_windows.val {
    a.dirty = true
    a.dirty_full = true
    a.dirty_rect = None
  }
  @win.wake()
}

///|
/// 按控件 id 局部置脏：命中哪扇窗就把该控件的矩形并进那扇窗的脏区（动画这类
/// 「只影响一个控件」的自驱动用它，不必整窗广播）。
/// 所有窗都找不到（已卸载/隐藏）回退整窗广播——宁可多画，不可漏画。
pub fn invalidate_id(id : Int) -> Unit {
  if id <= 0 {
    return
  }
  let mut hit = false
  for a in host_windows() {
    match a.root.by_id(id) {
      Some(w) => {
        a.mark_widget_rect(w)
        hit = true
      }
      None => ()
    }
  }
  if !hit {
    host_repaint_all()
  }
}

///|
/// 清空注册表并退回未起动态（`App::shutdown` 拆完窗之后调用，
/// 于是同进程再开一窗又会成为主窗）。
pub fn host_reset() -> Unit {
  g_windows.val = []
  g_active.val = 0
  g_loop.val = None
}
