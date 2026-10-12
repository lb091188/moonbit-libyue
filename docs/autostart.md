# Autostart

`@sys.autostart_*` provides cross-platform query / enable / disable of "launch at login", with the semantics unified in the MoonBit layer — the caller stays platform-agnostic.

## Platform routing

| Platform | Mechanism | Entry location |
|---|---|---|
| Linux | XDG autostart directory, writing `<app_id>.desktop` | `$XDG_CONFIG_HOME/autostart/`, falling back to `$HOME/.config/autostart/` |
| Windows | HKCU `Software\Microsoft\Windows\CurrentVersion\Run`, writing a value | value name = app_id, value = a quoted executable path |
| macOS | not yet developed | `autostart_supported()` is false; operations return `AutostartError::Unsupported` |

## API

| Function | Description |
|---|---|
| `autostart_supported() -> Bool` | runtime probe (false on macOS in this batch) |
| `autostart_is_enabled(app_id) -> Result[Bool, AutostartError]` | query (Linux honours the system-side disable bits `Hidden` / `X-GNOME-Autostart-enabled`) |
| `autostart_enable(app_id)` / `autostart_disable(app_id) -> Result[Unit, AutostartError]` | enable / disable; both idempotent (re-enabling overwrites, disabling something absent still succeeds) |
| `autostart_path(app_id) -> Result[String, AutostartError]` | entry location (Linux = full `.desktop` path; Windows = `HKCU\…\Run\<app_id>` description), for diagnostics |
| `autostart_exe_path() -> String?` | full path of the current executable (what `enable` uses) |
| `autostart_valid_app_id(app_id) -> Bool` | app_id validation (DBus well-known-name rules: ≥2 dot-separated elements, each starting with a letter / underscore) |
| `autostart_dir_of(xdg, home)` / `autostart_escape_exec(path)` / `autostart_desktop_entry(exe, app_id)` / `autostart_desktop_enabled(content)` / `autostart_run_value(exe)` / `autostart_run_value_exe(value)` | pure functions (autostart-dir resolution / Exec escaping / `.desktop` content and parsing / Windows Run value and reverse-parsing) |

## Usage

```moonbit
match @sys.autostart_enable("com.example.MyApp") {
  Ok(_) => ()      // launched on next login / reboot (see autostart_path for the location)
  Err(e) => println(e.to_string())
}
match @sys.autostart_is_enabled("com.example.MyApp") { ... }
match @sys.autostart_disable("com.example.MyApp") { ... }   // idempotent
```

Errors are `AutostartError{Unsupported, InvalidAppId, NoExecutablePath, IoFailed(String)}` — unsupported and failure stay distinct, nothing fails silently. **The library adds the exec-path quotes per platform convention** (both the `.desktop` Exec and the Windows REG_SZ are wrapped in one pair of double quotes); callers must not add another layer.

## Bounds

- `enable` targets the absolute path of the current process's executable: under AppImage / portable unpacked directories (temp locations), updating or moving the app invalidates the old entry — re-run `enable`.
- The Linux autostart directory may be emptied by cleanup tools; the Windows Run key may be disabled by group policy (entry present but never run) — both are environment-side behaviours the library does not probe.

[中文文档](/zh/autostart.md)
