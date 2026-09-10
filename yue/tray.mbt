// 系统托盘：平台差异收敛的示范实现。
//
// 后端现状：
// - Windows / macOS：系统原生支持，恒可用。
// - Linux：后端是 AppIndicator（indicators 协议），运行库不随基础桌面保证存在，
//   且 nativeui 加载失败时只打日志、不对外报告。
// 因此库在 ABI 层提供 yue_mbt_tray_supported() 探测，
// MoonBit 层暴露统一的 is_supported() 与 Result 构造，
// 消费方写的代码在三大平台完全一致，缺失后端时拿到结构化错误而非静默失效。

///|
/// 托盘后端是否可用。消费方可据此决定是否展示托盘相关功能。
pub fn Tray::is_supported() -> Bool {
  yue_mbt_tray_supported()
}

///|
/// 用图片文件创建托盘图标。失败返回结构化错误：
/// 后端缺失（Linux 无 AppIndicator 运行库）或图标读取失败。
pub fn Tray::new(icon_path : String) -> Result[Tray, TrayError] {
  if not(Tray::is_supported()) {
    return Err(Unsupported)
  }
  match yue_mbt_tray_new(utf8_bytes(icon_path)) {
    Some(tray) => Ok(tray)
    None => Err(IconLoadFailed)
  }
}

///|
/// 设置托盘标题（Linux 下映射为 AppIndicator label；
/// 部分桌面环境不渲染标题，属于平台表现差异，接口不变）。
pub fn Tray::set_title(self : Tray, title : String) -> Unit {
  yue_mbt_tray_set_title(self, utf8_bytes(title))
}

///|
/// 移除托盘图标。之后对象不可再用。
pub fn Tray::remove(self : Tray) -> Unit {
  yue_mbt_tray_remove(self)
}
