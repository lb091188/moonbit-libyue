// 窗口注册表（G9 Batch 2 后的一层薄账）：壳层那本「有哪些窗」的账（`Session`
// 列表、当前窗号、共用泵）住在 `shell/session.mbt`；本文件只补 widget 侧的
// 另一半——窗号 → 挂了内容的 `App`，于是 `host_active()`/`host_windows()`
// 这两张脸对外不变（ui/浮层/拖放/媒体都靠它们问「当前是哪扇窗」）。
//
// 三条口径照旧：
// ① 主窗是注册表里的第一扇——关掉主窗即整体退出（裁决在 `host_close_action`）。
// ② `invalidate()` 走进程级重绘钩子，多窗时**广播**给所有在窗（一次置脏
//    + 一次唤醒）。跨窗共享的 Store/信号本来就该两边都重画。
// ③ 当前窗决定浮层开在哪扇窗上：新窗建好即当前窗，哪扇窗收到输入就切到
//    哪扇，当前窗被关掉则退回注册表里最后一扇。

///|
// 窗号 → 挂了内容的 App。表归 widget 侧：壳层泵每拍要按在窗逐个排空事件、
// 喂输入法、画脏窗，拿的都是这半本账。
let g_apps : Map[Int, App] = Map([])

///|
pub fn host_add_app(app : App) -> Unit {
  // 壳层账本里还没有这扇窗（手搓假窗的测试路径）就补登记；生产路径由
  // `@shell.session_open` 建好即入册，这里不重复推。
  let mut seen = false
  for x in @shell.host_windows() {
    if x.wid == app.session.wid {
      seen = true
    }
  }
  if !seen {
    @shell.host_add(app.session)
  }
  g_apps[app.wid()] = app
}

///|
pub fn host_remove_app(wid : Int) -> Unit {
  let _ = g_apps.remove(wid)
}

///|
fn host_app_of(wid : Int) -> App? {
  g_apps.get(wid)
}

///|
/// 当前窗（挂了内容的那半）；没有窗给 None。
pub fn host_active() -> App? {
  match @shell.session_active() {
    Some(s) => host_app_of(s.wid)
    None => None
  }
}

///|
/// 在窗 App 的快照（遍历中可能增删，调用方一律走快照而不是活表）。
pub fn host_windows() -> Array[App] {
  let out : Array[App] = []
  for s in @shell.host_windows() {
    match host_app_of(s.wid) {
      Some(a) => out.push(a)
      None => ()
    }
  }
  out
}

///|
/// 广播置脏 + 唤醒等待中的平台泵（`invalidate()` 的宿主侧落点）。
/// 整窗语义：跨窗共享的信号变化拿不准各窗哪些区域受影响，一律全量。
pub fn host_repaint_all() -> Unit {
  for a in host_windows() {
    a.session.dirty = true
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
/// 清空两半本账（`App::shutdown` 拆完窗之后调用，于是同进程再开一窗又会
/// 成为主窗）。
pub fn host_reset() -> Unit {
  g_apps.clear()
  @shell.host_reset()
}
