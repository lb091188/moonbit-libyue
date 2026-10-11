// 接线层：把本包的能力装进 `yue/sys` 的注入槽。
//
// 方向是单向的——`yue/dbus` 依赖 `yue/sys`（环境变量、子进程、sysfs 读），
// 反过来不行；所以「写亮度走 logind」这件事由本包在调用方启动时**注进**
// sys 的探针槽与动作槽（`brightness_set_logind_probe` /
// `brightness_set_action`），sys 自己不引 D-Bus。

///|
/// 把 logind 的亮度写能力装进 `yue/sys` 的注入槽：探针看 logind 在不在线
/// （系统总线上 `org.freedesktop.login1` 的 NameHasOwner），动作走当前会话
/// 的 `SetBrightness(ssu)`。幂等，可重复调用。
pub fn install_logind_brightness() -> Unit {
  @sys.brightness_set_logind_probe(fn() -> Bool { logind_available() })
  @sys.brightness_set_action(fn(
    subsystem : String,
    name : String,
    value : Int,
  ) -> String {
    match bright_set_brightness(subsystem, name, value) {
      Ok(_) => ""
      Err(e) => e
    }
  })
}
