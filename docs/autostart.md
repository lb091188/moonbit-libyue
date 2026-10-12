# 开机自启动（Autostart）

`@system.Autostart` 提供跨平台的开机自启动查询 / 设置 / 取消，语义归一在 MoonBit 层，使用方零平台感知。

## 平台路由

| 平台 | 机制 | 条目位置 |
|---|---|---|
| Linux | XDG 自启动目录写 `<app_id>.desktop` | `$XDG_CONFIG_HOME/autostart/`，未设回退 `$HOME/.config/autostart/` |
| Windows | HKCU `Software\Microsoft\Windows\CurrentVersion\Run` 写值 | 值名 = app_id，值为引号包裹的可执行文件路径 |
| macOS | 暂缓 | `is_supported()` 为 false，操作返回 `AutostartError::Unsupported` |

## API

| 函数 | 说明 |
|---|---|
| `Autostart::new(app_id) -> Result[Autostart, AutostartError]` | 创建句柄；app_id 走 DBus 知名名校验（≥2 点分元素、元素以字母/下划线开头） |
| `Autostart::is_supported() -> Bool` | 当前平台是否支持 |
| `Autostart::is_enabled() -> Result[Bool, AutostartError]` | 查询；Linux 兼容系统侧禁用位（`Hidden=true`、`X-GNOME-Autostart-enabled=false` 判未启用） |
| `Autostart::enable() -> Result[Unit, AutostartError]` | 启用；幂等（覆盖旧值）。可执行文件路径自动取本进程自身 |
| `Autostart::disable() -> Result[Unit, AutostartError]` | 禁用；幂等（目标本就不在也是成功） |
| `Autostart::path() -> Result[String, AutostartError]` | 条目位置（Linux 为 .desktop 完整路径；Windows 为 Run 键值描述），排查用 |

## 用法

```moonbit
match @system.Autostart::new("com.example.app") {
  Ok(a) =>
    match a.enable() {
      Ok(_) => println("已启用，重新登录后拉起")
      Err(e) => println("失败：\{e}")
    }
  Err(e) => println("app_id 非法：\{e}")
}
```

## 边界

- enable 的自启动目标取本进程可执行文件绝对路径：AppImage / 便携解压目录等临时位置下，应用更新或挪动目录后旧条目失效，需要重新 enable。
- Linux 自启动目录可能被清理工具清空；Windows Run 键可被组策略禁用（条目在但不执行）——两类均为环境侧行为，库不做探测。

## 新栈（MoonBit 原生 GUI 栈）口径

上面是旧链 `@system.Autostart`（句柄形态）。新栈在 **`yue/sys/autostart.mbt`**，是**自由函数**（无对象、无单例，app_id 每次传入）：

```moonbit
match @sys.autostart_enable("com.example.MyApp") {
  Ok(_) => ()      // 重新登录 / 重启即拉起（落点见 autostart_path）
  Err(e) => println(e.to_string())
}
match @sys.autostart_is_enabled("com.example.MyApp") { ... }
match @sys.autostart_disable("com.example.MyApp") { ... }   // 幂等
```

| 函数 | 说明 |
|---|---|
| `autostart_supported() -> Bool` | 运行时探测（macOS 本批 false） |
| `autostart_is_enabled(app_id) -> Result[Bool, AutostartError]` | 查询（Linux 认 `Hidden` / `X-GNOME-Autostart-enabled` 系统侧禁用位） |
| `autostart_enable(app_id)` / `autostart_disable(app_id) -> Result[Unit, AutostartError]` | 设置 / 取消；都幂等：重复 enable 覆盖、disable 对「本就不在」也算成功 |
| `autostart_path(app_id) -> Result[String, AutostartError]` | 落点（Linux = `.desktop` 全路径；Windows = `HKCU\…\Run\<app_id>` 描述），排查用 |
| `autostart_exe_path() -> String?` | 当前进程可执行文件全路径（enable 用的就是它） |
| `autostart_valid_app_id(app_id) -> Bool` | app_id 校验（DBus 知名名规则：≥2 点分元素、元素以字母/下划线开头） |
| `autostart_dir_of(xdg, home)` / `autostart_escape_exec(path)` / `autostart_desktop_entry(exe, app_id)` / `autostart_desktop_enabled(content)` / `autostart_run_value(exe)` / `autostart_run_value_exe(value)` | 纯函数（自启动目录解析 / Exec 转义 / `.desktop` 内容与解析 / Windows Run 值形态与反解） |

错误是 `AutostartError{Unsupported, InvalidAppId, NoExecutablePath, IoFailed(String)}`——不支持与失败分开，不静默。**exec 路径的引号按平台惯例由库加**（`.desktop` 的 Exec 与 Windows REG_SZ 都是整串双引号包裹），调用方不要再拼一层。

[中文文档](/zh/autostart.md)
