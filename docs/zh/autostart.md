# 开机自启动（Autostart）

`@sys.autostart_*` 提供跨平台的开机自启动查询、设置与取消，语义在 MoonBit 层归一，使用方不需感知平台。

## 平台路由

| 平台 | 机制 | 条目位置 |
|---|---|---|
| Linux | XDG 自启动目录写 `<app_id>.desktop` | `$XDG_CONFIG_HOME/autostart/`，未设回退 `$HOME/.config/autostart/` |
| Windows | HKCU `Software\Microsoft\Windows\CurrentVersion\Run` 写值 | 值名是 app_id，值是引号包裹的可执行文件路径 |
| macOS | 暂未开发 | `autostart_supported()` 为 false，操作返回 `AutostartError::Unsupported` |

## API

| 函数 | 说明 |
|---|---|
| `autostart_supported() -> Bool` | 运行时探测；macOS 为 false |
| `autostart_is_enabled(app_id) -> Result[Bool, AutostartError]` | 查询当前状态；Linux 认 `Hidden` 与 `X-GNOME-Autostart-enabled` 两个系统侧禁用位 |
| `autostart_enable(app_id)` / `autostart_disable(app_id) -> Result[Unit, AutostartError]` | 设置与取消；两者幂等：重复 enable 覆盖，disable 对本就不存在的条目也算成功 |
| `autostart_path(app_id) -> Result[String, AutostartError]` | 落点描述，排查用：Linux 是 `.desktop` 全路径，Windows 是 `HKCU\…\Run\<app_id>` |
| `autostart_exe_path() -> String?` | 当前进程可执行文件全路径，enable 写入的就是它 |
| `autostart_valid_app_id(app_id) -> Bool` | 按 DBus 知名名规则校验 app_id：至少两个点分元素，元素以字母或下划线开头 |
| `autostart_dir_of` / `autostart_escape_exec` / `autostart_desktop_entry` / `autostart_desktop_enabled` / `autostart_run_value` / `autostart_run_value_exe` | 纯函数：自启动目录解析、Exec 转义、`.desktop` 内容与解析、Windows Run 值形态与反解 |

## 用法

```moonbit
match @sys.autostart_enable("com.example.MyApp") {
  Ok(_) => ()      // 重新登录 / 重启即拉起（落点见 autostart_path）
  Err(e) => println(e.to_string())
}
match @sys.autostart_is_enabled("com.example.MyApp") { ... }
match @sys.autostart_disable("com.example.MyApp") { ... }   // 幂等
```

错误类型 `AutostartError{Unsupported, InvalidAppId, NoExecutablePath, IoFailed(String)}` 把不支持与失败分开，不静默。exec 路径的引号按平台惯例由库加——`.desktop` 的 Exec 与 Windows REG_SZ 都是整串双引号包裹，调用方不要再拼一层。

## 边界

- 自启动目标取本进程可执行文件的绝对路径：AppImage 或便携解压目录等临时位置下，应用更新或挪动目录后旧条目失效，需要重新 enable。
- Linux 的自启动目录可能被清理工具清空，Windows 的 Run 键可被组策略禁用（条目在但不执行）。两类都是环境侧行为，库不做探测。

[English](/autostart)
