# Linux Tray Design

The tray is the most platform-divergent part of native-gui. Linux has no tray runtime library to depend on directly, so this project implements the StatusNotifierItem protocol stack in pure MoonBit (`dbus/sni.mbt`) and connects to the panel straight over the session bus, with no AppIndicator runtime dependency. This document covers the design, backend selection, menu handling and desktop compatibility; pitfalls and verification conclusions on real desktops are recorded in [adaptation.md](adaptation.md).

## Background and constraints

- Ubuntu 24.04 removed the legacy `libappindicator3` runtime. This design depends on neither it nor any AppIndicator runtime: the tray speaks SNI directly over the session bus, and installing the AppIndicator extension lets GNOME use SNI too.
- Design bottom line: a missing backend must return a **structured result** — `Err(TrayError::Unsupported)` or `is_supported() == false`, never a silent failure.

## Design overview

```
Tray unified API (core/tray.mbt)             consumers need zero platform code
  │ backend selection
  ├─ SNI (@dbus.Item)                        watcher online (the main Linux path)
  │   └─ dbus/  pure-MoonBit protocol stack
  │     ├─ wire.mbt    DBus wire format encode/decode (little-endian; alignment resets per scope)
  │     ├─ bus.mbt     session bus: address resolution, SASL EXTERNAL handshake, Hello, message send/receive/dispatch
  │     ├─ sni.mbt     SNI properties/signals/Activate dispatch + DBusMenu
  │     ├─ icon.mbt    built-in programmatic tray bitmap (32×32 crescent, big-endian ARGB)
  │     └─ …           icons, notifications, logind/upower, media, network, etc.
  └─ Win32 (win/tray.mbt + Shell_NotifyIconW in stub.c)   the Windows native tray
```

One session-bus connection per process, everything on the main thread.

## Backend selection

1. **SNI watcher online → pure-MoonBit tray.** Reaching the session bus only makes it a candidate; whether a watcher exists is decided by `NameHasOwner(org.kde.StatusNotifierWatcher)` at registration time, i.e. `sni_watcher_present()`, which is stronger than `sni_available()` (bus reachability alone).
2. **Otherwise → the Win32 native tray**, decided by `@win.tray_supported()`.
3. **Neither → `Err(TrayError::Unsupported)`**, so consumers can decide whether to show tray-related features. Linux no longer falls back to AppIndicator.

## Unified API and platform differences

The consumer-facing API is identical on every platform: `Tray::new / is_supported / set_title / set_icon / set_icon_name / set_tooltip / on_click / set_menu / remove`. Platform differences are absorbed inside the library; the externally visible behavior:

| Method | Linux SNI backend | Windows native backend |
| --- | --- | --- |
| `set_title` | supported; some panels don't render it — panel-side behavior | same as left |
| `set_icon` | no-op: arbitrary PNG pixel decoding isn't built in; keeps the current icon | supported: `.ico` native, PNG via WIC, or pixels built directly |
| `set_icon_name` | supported, follows the panel theme, e.g. `utilities-terminal` | no-op |
| `set_tooltip` | supported | supported |
| `on_click` | panel Activate signal | icon click |
| `set_menu` | builds a DBusMenu, flat one level | native `TrackPopupMenuEx` |

On Linux the tray bitmap is generated programmatically by `dbus/icon.mbt`: an outer circle and an offset cut-out circle form a crescent, anti-aliased with 2×2 supersampling, output as big-endian ARGB as the SNI spec requires — no image assets or decoders. To follow the system theme, use `set_icon_name`.

## Callbacks and menus

- **Callbacks**: on Win32, left and right clicks go through a process-level queue that the host drains each tick via `dispatch_tray_event()`; a right click with no callback automatically pops up the attached menu. On SNI, D-Bus signals reach the callback directly, bypassing the queue.
- **Menus**: `Tray::set_menu(Menu)` reuses the same model from `core/menu.mbt`. Win32 goes through `TrackPopupMenuEx` + `TPM_RETURNCMD`, and the chosen item rejoins the same menu dispatch chain; SNI goes through DBusMenu — this implementation is a flat one-level menu, with submenus flattened behind a leading separator.

## Desktop environment compatibility

| Desktop environment | Status | Notes |
| --- | --- | --- |
| XFCE 4.18 | ✅ verified | icon, Activate click and context menu all work end to end |
| KDE / MATE / Cinnamon / Budgie / LXQt | ❓ pending verification | native SNI support at the protocol level, expected to work |
| GNOME + AppIndicator extension | ❓ pending verification | protocol-level support present, pending real-machine verification |
| vanilla GNOME | ❌ | no tray protocol; `Err(Unsupported)` is expected behavior |
| Windows 10 / 11 | ✅ verified | native `Shell_NotifyIconW` backend |
| macOS | 🚧 backend not yet developed | |

Status markers match [adaptation.md](adaptation.md): ✅ verified working / ⚠️ partially working or conditional / ❌ not working / ❓ untested.

## Debugging and verification

- For protocol interop issues, capture the real session bus with `dbus-monitor` first — differences such as batch-version signals are only visible on the bus; criteria and cases are in the "DBus wire protocol" and "Desktop environments" sections of adaptation.md.
- Unit tests only prove the codec is self-consistent — wire-level rules like alignment, signatures and length prefixes have their own tests; interop conclusions must come from a real bus and a real panel, which is a repository-level verification rule.
- The backend is proven by the pure-C probe `experiment/tray_probe`, with the last line `TRAY-BACKEND-OK` as the success marker; the facade is proven by the pure functions and lifecycle cases in `core/tray_wbtest.mbt`, which auto-skip on machines without a tray backend instead of faking results. Real-panel appearance — whether the icon shows, where the menu pops up, left-click behavior — still belongs to the manual test checklist.

[中文文档](/zh/tray.md)
