// 共享层:跨页状态 App 与平台判断。各页函数以 app 单参取用;
// 页内私有状态留在各页函数体内,不进 App。

///|
pub fn is_linux() -> Bool {
  @yue.platform() == "linux"
}

///|
/// 跨页共享状态:导航、窗口/托盘句柄、对话框、主题页共享计数。
pub(all) struct App {
  selected : @yue.Store[String]
  toast : (String, @yue.SemanticType) -> Unit
  win_ref : Ref[@yue.Window?]
  tray_ref : Ref[@yue.Tray?]
  close_veto : Ref[Bool]
  veto_info : @yue.Store[String]
  dark_mode : @yue.Store[Bool]
  // 主题主色(hex):空串 = 内置基准盘,否则 theme_from_accent 公式派生
  accent : @yue.Store[String]
  tray_clicks : @yue.Store[Int]
  dlg_basic : @yue.Store[Bool]
  dlg_form : @yue.Store[Bool]
  dlg_name : @yue.Store[String]
  key_info : @yue.Store[String]
  // 主题页共享信号:基础页 Button 触发,数据页 Statistic/Progress 展示,
  // visits/ratio 为 computed 派生(信号版消灭了手动 subscribe 接线)
  counter : @yue.Signal[Int]
  visits : @yue.Signal[String]
  ratio : @yue.Signal[Double]
  picked_lang : @yue.Signal[String]
  // 单实例演示:本实例角色与最近一次收到的唤起参数(系统集成页展示)
  si_role : @yue.Store[String]
  si_wake : @yue.Store[String]
}

///|
/// 推送一条轻提示(转发 toast 函数字段;函数值字段不能直接点调用)。
pub fn App::toast_push(
  self : App,
  text : String,
  t : @yue.SemanticType,
) -> Unit {
  (self.toast)(text, t)
}
