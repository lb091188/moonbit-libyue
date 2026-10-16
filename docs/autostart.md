# Autostart

`@sys.autostart_*` provides cross-platform query, enable, and disable of launch-at-login. The semantics are unified in the MoonBit layer, so callers don't need to be aware of the platform.

## Platform routing

| Platform | Mechanism | Entry location |
|---|---|---|
| Linux | Writes `<app_id>.desktop` into the XDG autostart directory | `$XDG_CONFIG_HOME/autostart/`, falling back to `$HOME/.config/autostart/` when unset |
| Windows | Writes a value under HKCU `Software\Microsoft\Windows\CurrentVersion\Run` | The value name is the app_id; the value is the double-quoted executable path |
| macOS | Not yet developed | `autostart_supported()` returns false; operations return `AutostartError::Unsupported` |

## API

| Function | Description |
|---|---|
| `autostart_supported() -> Bool` | Runtime probe; false on macOS |
| `autostart_is_enabled(app_id) -> Result[Bool, AutostartError]` | Queries the current state; on Linux it honours the two system-side disable bits `Hidden` and `X-GNOME-Autostart-enabled` |
| `autostart_enable(app_id)` / `autostart_disable(app_id) -> Result[Unit, AutostartError]` | Enable and disable; both idempotent: a repeated enable overwrites, and disabling an entry that never existed also succeeds |
| `autostart_path(app_id) -> Result[String, AutostartError]` | Describes where the entry lands, for troubleshooting: the full `.desktop` path on Linux, `HKCU\…\Run\<app_id>` on Windows |
| `autostart_exe_path() -> String?` | Full path of the current process's executable; this is what enable writes |
| `autostart_valid_app_id(app_id) -> Bool` | Validates an app_id against the DBus well-known-name rules: at least two dot-separated elements, each starting with a letter or an underscore |
| `autostart_dir_of` / `autostart_escape_exec` / `autostart_desktop_entry` / `autostart_desktop_enabled` / `autostart_run_value` / `autostart_run_value_exe` | Pure functions: autostart-dir resolution, Exec escaping, `.desktop` content and parsing, Windows Run value format and reverse parsing |

## Usage

```moonbit
match @sys.autostart_enable("com.example.MyApp") {
  Ok(_) => ()      // launches on next login / reboot (see autostart_path for the location)
  Err(e) => println(e.to_string())
}
match @sys.autostart_is_enabled("com.example.MyApp") { ... }
match @sys.autostart_disable("com.example.MyApp") { ... }   // idempotent
```

The error type `AutostartError{Unsupported, InvalidAppId, NoExecutablePath, IoFailed(String)}` keeps "unsupported" and "failed" separate; nothing fails silently. The library adds the exec-path quotes per platform convention: both the `.desktop` Exec and the Windows REG_SZ wrap the whole path in one pair of double quotes, so callers should not add another layer.

## Edge cases

- The autostart target is the absolute path of the current process's executable. When the app runs from a temporary location such as an AppImage or a portable unpacked directory, updating the app or moving the directory invalidates the old entry, so enable must be run again.
- Cleanup tools may empty the Linux autostart directory, and group policy may disable the Windows Run key (the entry stays but never runs). Both are environment-side behaviors; the library does not probe for them.

[中文文档](/zh/autostart.md)
