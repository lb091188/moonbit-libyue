// 组件的动态交互状态：`Enabled`（禁用态单元）。
//
// 为什么不是一句 `disabled : Bool`：测试抓到真 bug——布尔若在建树时固化进闭包，
// 步进器的 `-`/`+` 按边界算出的禁用就永远停在挂载那一刻（值到上界后 `+` 仍可点、
// `-` 仍禁用）。所以禁用态必须是**可读写的单元**，绘制与事件回调每次现取。
//
// 组合控件（复选行、开关、步进器两侧）共用同一个单元：外层建好往里传，
// 调用方也可以拿着它在任意时刻改，下一帧就生效。单元跟着闭包一起存活，
// 不需要按控件 id 建侧表，也不留回收问题。

///|
pub(all) struct Enabled {
  mut off : Bool
}

///|
pub fn Enabled::new(off : Bool) -> Enabled {
  { off, }
}

///|
/// 取用禁用单元：调用方给了就用它（组合控件共用），否则按 `disabled` 新建一个。
/// 在 mount 内部调用，所以同一个 Node 挂两次会得到两个独立单元。
fn enabled_cell(enabled : Enabled?, disabled : Bool) -> Enabled {
  match enabled {
    Some(c) => c
    None => Enabled::new(disabled)
  }
}

///|
/// 改禁用态（`v=true` 即禁用）。持有单元的调用方随时可改。
pub fn set_disabled(cell : Enabled, v : Bool) -> Unit {
  cell.off = v
}

///|
/// 读禁用态。
pub fn is_disabled(cell : Enabled) -> Bool {
  cell.off
}

///|
/// 按禁用单元下发光标请求：可用时请求 `on`，禁用时不请求（查询继续往祖先走，
/// 最终回默认箭头）。光标是按命中路径现查的，所以禁用态必须**查询时现算**——
/// 建树时定死会与「禁用态是单元」的口径冲突（同 `enabled_cell` 的注释）。
fn enabled_cursor(cell : Enabled, on : Int) -> (@widget.Widget) -> Int {
  fn(_w : @widget.Widget) -> Int {
    if cell.off {
      @widget.CURSOR_DEFAULT
    } else {
      on
    }
  }
}
