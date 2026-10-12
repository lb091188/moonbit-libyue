// 共享层：跨页状态 App 与平台判断。各页函数以 app 单参取用；
// 页内私有状态留在各页函数体内，不进 App。
//
// 与 master 线的差（G7 记档）：① 句柄类字段（窗口/托盘/对话框）暂不带——
// 那几页各自迁入时再加，避免共享层替未迁的页预置死字段；② 主题跟随不再用
// `on_system_theme_change` 回调（旧链路的平台事件通道），改为「跟随开关 +
// 定时读系统偏好」：见 `main.mbt` 的 tick，手动选色/切深浅先把跟随关掉。

///|
/// 跨页共享状态：导航、主题、跨页计数。
pub(all) struct App {
  /// 侧栏与页切换共用的导航状态（存页名）
  selected : @core.Store[String]
  /// 轻提示推送（转发 `toast_layer` 的函数值字段）
  toast : (String, @ui.SemanticType) -> Unit
  /// 深浅：跟随开关打开时由定时器写，按钮手动改时先关跟随
  dark_mode : @core.Store[Bool]
  /// 主题主色（hex）：空串 = 内置基准盘，否则 `theme_from_accent` 公式派生
  accent : @core.Store[String]
  /// 跟随系统深浅/主色开关（「跟随系统」按钮置真，手动选色置假）
  follow : @core.Store[Bool]
  /// 主题页共享信号：基础页 Button 触发，数据页 Statistic/Progress 展示；
  /// visits/ratio 为 computed 派生（信号版消灭了手动 subscribe 接线）
  counter : @core.Signal[Int]
  visits : @core.Signal[String]
  ratio : @core.Signal[Double]
  /// 最近一次链接点击（基础页回显）
  picked_lang : @core.Signal[String]
  /// 对话框可见性（反馈页的按钮是触发方，两个对话框挂在 main 的窗口根）
  dlg_basic : @core.Store[Bool]
  dlg_form : @core.Store[Bool]
  /// 表单对话框里的名称框（Store 是文本状态的唯一权威，`entry` 直连）
  dlg_name : @core.Store[String]
  /// 最近一次对话框确认的回显（与 `dlg_name` 分开，避免确认把输入框内容改掉）
  dlg_result : @core.Store[String]
}

///|
/// 推送一条轻提示（转发 toast 函数字段；函数值字段不能直接点调用）。
pub fn App::toast_push(self : App, text : String, t : @ui.SemanticType) -> Unit {
  (self.toast)(text, t)
}
