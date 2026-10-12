// 任务栏进度（TODO §6.3 接缝项「任务栏进度 / dock 徽标」的 Windows 半边）。
//
// 口径：
// - **只写不读**：Win32 无 getter，`TBPF_*` 状态不可反读（与 notify 的
//   kind→`NIIF_*` 映射同款「映射不可反读，由代码评审兜底」）；
// - **unsupported 语义化降级**：非 Windows 平台 `supported` 恒 false，
//   调用方据此藏 UI，不把失败当 0% 进度；
// - Linux 的任务栏进度另有 Unity LauncherEntry（DBus）路径、macOS 是
//   dock 徽标（NSDockTile），都归后续跨平台门面批——本文件只做 Windows。
//
// 与既有形态的关系：值走 `Int64`（下载字节数一类的进度值会超 32 位），
// C 侧透传 ULONGLONG；窗口句柄从窗口槽拿（越界由 C 侧挡，返回 false）。

///|
/// 任务栏按钮状态（Win32 `TBPF_*` 的语义编号，跨平台门面的共同词汇）。
pub(all) enum TaskbarState {
  /// 不显示进度条（清空）
  NoProgress
  /// 正常绿色进度
  Normal
  /// 红色（出错）
  Error
  /// 黄色（暂停）
  Paused
  /// 绿色滚动（不确定进度，value/total 无意义）
  Indeterminate
}

///|
/// 状态 → C 侧编号（纯函数，供测试与文档对照）。
pub fn taskbar_state_id(s : TaskbarState) -> Int {
  match s {
    NoProgress => 0
    Normal => 1
    Error => 2
    Paused => 3
    Indeterminate => 4
  }
}

///|
/// 编号 → 状态（纯函数；未知编号归 NoProgress，与 C 侧 default 分支一致）。
pub fn taskbar_state_of(id : Int) -> TaskbarState {
  match id {
    1 => Normal
    2 => Error
    3 => Paused
    4 => Indeterminate
    _ => NoProgress
  }
}

///|
/// 后端可用性：无显示服务或 COM 起不来时 false。
pub fn taskbar_supported() -> Bool {
  wm_taskbar_supported() == 1
}

///|
/// 设进度（`value`/`total`；total <= 0 按 C 侧口径视为无效值，
/// 此时先 `set_taskbar_state(Indeterminate)` 更稳）。
pub fn Window::set_taskbar_progress(
  self : Window,
  value : Int64,
  total : Int64,
) -> Bool {
  wm_taskbar_set_progress(self.id, value, total) == 1
}

///|
/// 设状态（清空进度用 `NoProgress`）。
pub fn Window::set_taskbar_state(self : Window, state : TaskbarState) -> Bool {
  wm_taskbar_set_state(self.id, taskbar_state_id(state)) == 1
}

///|
/// 清空任务栏进度（`NoProgress` 的语义化别名）。
pub fn Window::clear_taskbar_progress(self : Window) -> Bool {
  self.set_taskbar_state(NoProgress)
}
