// 只读系统探针（G9 Batch 2 步骤 2·乙首批）：窗口层之外、与控件树零耦合的
// 平台读数——单调时钟、深浅偏好、系统主色、本地日期。
// 示例与集成层经此取值，不必引用平台包（`@core` 门面同名转发）。

///|
/// 单调时钟（毫秒）。声明式组件的双击判定等要它；无后端时返回 0。
pub fn now_ms() -> Int64 { @win.now_ms() }

///|
/// 系统深浅偏好（"dark" / "light" / ""）。
pub fn sys_color_scheme() -> String {
  @win.sys_color_scheme()
}

///|
/// 系统主色（"#rrggbb" / ""）。
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
