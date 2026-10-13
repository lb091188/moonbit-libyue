// 演示板共享层（systemprobe 新栈版）：跨页状态 ProbeApp。
// 页面「段」装配与 showcase 共用同一套（section.mbt 与 showcase 副本逐行
// 同源）；本文件只放本演示板自己的共享状态——比 showcase 的 App 轻得多：
// 这个板子不接管主题（跟随系统初始值即可）、不挂对话框，只需要
// 导航状态、toast 推送与宿主句柄（文件对话框的 parent 要用）。

///|
/// 跨页共享状态：导航、轻提示、宿主句柄。
pub(all) struct ProbeApp {
  /// 侧栏与页切换共用的导航状态（存页名）
  selected : @core.Store[String]
  /// 轻提示推送（转发 `toast_layer` 的函数值字段）
  toast : (String, @ui.SemanticType) -> Unit
  /// 宿主句柄（挂载时由 main 的 handle 回调填入）：媒体页的文件对话框
  /// parent 要用。页函数体跑完时还没挂载，所以是 Ref。
  host : Ref[@core.App?]
}

///|
/// 推送一条轻提示（转发 toast 函数字段；函数值字段不能直接点调用）。
pub fn ProbeApp::toast_push(
  self : ProbeApp,
  text : String,
  t : @ui.SemanticType,
) -> Unit {
  (self.toast)(text, t)
}
