# 开机自启动（Autostart）

`@yue.Autostart` 提供跨平台的开机自启动查询 / 设置 / 取消，语义归一在 MoonBit 层，使用方零平台感知。

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
match @yue.Autostart::new("com.example.app") {
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

[中文文档](zh/autostart.md)
