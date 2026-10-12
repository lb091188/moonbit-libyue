# Linux Tray Design

The tray is the area with the largest platform differences in moonbit-libyue: Linux has no tray runtime library that can be depended on directly, so the library implements the StatusNotifierItem (SNI) protocol stack in pure MoonBit (`dbus/sni.mbt`), connecting to the panel directly over the session bus with zero AppIndicator dependency. This document covers the design, backend selection, menu handling and desktop compatibility; pitfalls and real-desktop verification conclusions are recorded in [docs/adaptation.md](adaptation.md).

## Background and constraints

- Ubuntu 24.04 removed the traditional `libappindicator3` runtime library. The design depends on none of it: the tray talks SNI over the session bus, so no AppIndicator runtime is needed at all — and with the AppIndicator extension installed, SNI works on GNOME too.
- Design bottom line: a missing backend must produce a **structured result** (`Err(TrayError::Unsupported)` / `is_supported() == false`), never a silent failure.

## Design overview

```
Tray unified API (core/tray.mbt)            consumers need zero platform code
  │ backend selection
  ├─ SNI (@dbus.Item)                       watcher online (the Linux path)
  │   └─ dbus/  pure-MoonBit protocol stack
  │     ├─ wire.mbt    DBus wire format encode/decode (little-endian; alignment resets per scope)
  │     ├─ bus.mbt     session bus: address resolution, SASL EXTERNAL handshake, Hello,
  │     │              message send/receive/dispatch
  │     ├─ sni.mbt     SNI properties/signals/Activate dispatch + DBusMenu menus
  │     ├─ icon.mbt    built-in programmatic tray bitmap (32×32 crescent, big-endian ARGB)
  │     └─ …           icons, notifications, logind/upower, media, network…
  └─ Win32 (win/tray.mbt + Shell_NotifyIconW in stub.c)   the Windows native tray
```

A single session-bus connection per process, all on the main thread.

## Backend selection

1. **SNI watcher online → pure-MoonBit tray.** Being able to reach the session bus only makes it a candidate; whether a watcher exists is decided by `NameHasOwner(org.kde.StatusNotifierWatcher)` at registration time (`sni_watcher_present()`), which is stronger than `sni_available()` (bus reachability only).
2. **Otherwise → the Win32 native tray** (`@win.tray_supported()`).
3. **Neither → `Err(TrayError::Unsupported)`**, a structured result the caller can use to decide whether to show tray features. **Linux no longer falls back to AppIndicator.**

## Unified API and platform differences

The consumer API is identical everywhere: `Tray::new / is_supported / set_title / set_icon / set_icon_name / set_tooltip / on_click / set_menu / remove`. Platform differences are absorbed inside the library:

| Method | Linux SNI backend | Windows native backend |
| --- | --- | --- |
| `set_title` | supported (some panels don't render it — a panel behaviour) | same |
| `set_icon` | no-op (arbitrary PNG pixel decoding is not built in; keeps the current icon) | supported (`.ico` native / PNG via WIC / pixels built directly) |
| `set_icon_name` | supported, follows the panel theme (e.g. "utilities-terminal") | no-op |
| `set_tooltip` | supported | supported |
| `on_click` | panel Activate signal | icon click |
| `set_menu` | builds DBusMenu (flat, one level) | native `TrackPopupMenuEx` |

Linux icon note: the bitmap is generated programmatically by `dbus/icon.mbt` (an outer circle plus an offset cut-out circle forming a crescent, 2×2 supersampled anti-aliasing, big-endian ARGB per the SNI spec), with no image assets or decoders; to follow the system theme, use `set_icon_name`.

## Callbacks and menus

- **Callbacks**: on Win32, left/right clicks go through a process-level queue drained by the host each tick via `dispatch_tray_event()` (a right click with no callback **automatically pops the attached menu**); on SNI, clicks reach the callback directly via D-Bus signals and bypass the queue.
- **Menus**: `Tray::set_menu(Menu)` reuses the same model from `core/menu.mbt` — Win32 goes through `TrackPopupMenuEx` + `TPM_RETURNCMD` (the chosen item rejoins the same menu dispatch chain); SNI goes through DBusMenu, where this implementation is a **flat one-level menu (submenus are flattened, preceded by a separator)**.

## Desktop environment compatibility

| Desktop environment | Status | Notes |
| --- | --- | --- |
| XFCE 4.18 | ✅ verified | icon, Activate click, context menu all work |
| KDE / MATE / Cinnamon / Budgie / LXQt | ❓ pending verification | protocol-level native SNI support, expected to work |
| GNOME + AppIndicator extension | ❓ pending verification | protocol-level support, pending real-machine verification |
| vanilla GNOME | ❌ | no tray protocol; `Err(Unsupported)` is expected behaviour |
| Windows 10 / 11 | ✅ verified | native `Shell_NotifyIconW` backend |
| macOS | 🚧 backend not yet developed | |

Status markers are consistent with [docs/adaptation.md](adaptation.md): ✅ verified working / ⚠️ partially working or conditional / ❌ not working / ❓ untested.

## Debugging and verification

- For protocol interop issues, the first choice is `dbus-monitor` captures on the **real session bus** (batch-version signals, etc.); see the DBus wire-protocol and desktop-environment sections of adaptation.md.
- Unit tests only prove encode/decode self-consistency; **interop conclusions must come from a real bus and a real panel** — a repository-level verification rule, not an optional requirement of this module.
- The backend is proven by the pure-C probe `experiment/tray_probe` (last line `TRAY-BACKEND-OK`); the facade by the pure-function and lifecycle cases in `core/tray_wbtest.mbt` (which auto-skip on machines with no tray backend instead of faking). **Real-panel look and feel still belongs to the manual test checklist.**

[中文文档](/zh/tray.md)
