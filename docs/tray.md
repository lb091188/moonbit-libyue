# Linux Tray Design

The tray is the area with the largest platform differences in moonbit-libyue: Linux has no tray runtime library that can be depended on directly, so this project implements the StatusNotifierItem (SNI) protocol stack in pure MoonBit, connecting directly to the panel over the session bus without depending on any AppIndicator runtime library. This document explains the design motivation, architecture layers, backend fallback, and desktop compatibility of the design; for a quick API reference see the "Menu / Tray" section of [docs/components.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/components.md), and pitfalls and verification conclusions from real-desktop testing are recorded uniformly in [docs/adaptation.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/adaptation.md).

## Background and constraints

- Ubuntu 24.04 has removed the traditional `libappindicator3` runtime library; even if the ayatana fork is installed, libyue does not accept it — its detection list only recognizes `libappindicator3`.
- When the runtime library fails to load, libyue's built-in tray **only logs and silently deactivates the object**, leaving consumers with no error at all — exactly the behavior this design aims to eliminate.
- Design bottom line: a missing backend must produce a **structured result** (`Err(Unsupported)` / `is_supported() == false`), never a silent failure.

## Design overview

```
Tray unified API (yue/tray.mbt)              consumers need zero platform code
  │ backend selection and fallback
  ├─ Sni (@traybus.Item)                     watcher online (main Linux path)
  │   └─ yue/traybus/  pure MoonBit protocol stack
  │     ├─ wire.mbt    DBus wire format encode/decode (little-endian; alignment resets per scope)
  │     ├─ bus.mbt     session bus: address resolution, SASL EXTERNAL handshake, Hello,
  │     │              message send/receive/dispatch (glib fd watch hooks into the GTK main loop)
  │     ├─ sni.mbt     SNI properties/signals/Activate dispatch + DBusMenu menus
  │     ├─ detect.mbt  desktop environment detection (XDG_CURRENT_DESKTOP, diagnostics aid only)
  │     ├─ icon.mbt    built-in programmatic tray bitmap generation (32×32 crescent, big-endian ARGB)
  │     └─ sys.mbt     fd-level syscall surface (8 calls, all forwarded via shim)
  └─ Native (NativeTray)                     fallback: libyue native AppIndicator
```

The shim only forwards 8 fd-level syscalls: unix connect / read / write / poll / close / watch_fd / getuid / getenv; on non-Linux platforms these are failure stubs, based on which traybus degrades gracefully and never touches real syscalls. Apart from these 8 entry points, the entire tray chain (encode/decode, handshake, protocol state machine, menu model) is done in the MoonBit layer.

### Main loop integration

A single session-bus connection per process, all running on the main thread. `sys_watch_fd` is attached via the shim to a glib fd watch source hooked into the GTK main loop; when DBus messages arrive they are dispatched by interface and method name to the SNI / DBusMenu handlers; replies are matched back via serial numbers (pending map).

## Backend selection and fallback

`Tray::new` selects the backend by the following priorities:

1. **SNI watcher online → pure MoonBit tray**. Being able to connect to the session bus only counts as a candidate; whether a watcher exists is determined by `NameHasOwner(org.kde.StatusNotifierWatcher)` at registration time; on successful registration, `@traybus.Item` is used. On failure (watcher offline, etc.) it falls back further down.
2. **Watcher offline → fall back to nativeui AppIndicator** (libyue's native tray; the shim side has added null-pointer defenses, so detection failures don't crash). This path is fallback only.
3. **Neither available → `Err(Unsupported)`**. `Tray::is_supported()` uses the same criteria; consumers can use it to decide whether to show tray-related features.

`desktop_environment()` returns the detected desktop environment name (XFCE / GNOME / KDE…, or "unknown" when undetectable), purely for diagnostics and fallback hints; runtime truth is always determined by whether the watcher is online — the environment name plays no part in backend selection.

## Unified API and platform differences

The consumer API is completely identical across the three major platforms: `Tray::new / is_supported / set_title / set_icon / set_icon_name / set_tooltip / on_click / set_menu / remove`. Platform differences are absorbed inside the library; the externally visible behavior:

| Method | Linux SNI backend | Windows / macOS native backend |
| --- | --- | --- |
| `set_title` | supported (some panels don't render it — a panel behavior) | same as left; some panels don't render it |
| `set_icon` | no-op (PNG pixel decoding not built in; keeps the current icon) | supported |
| `set_icon_name` | supported, follows the system theme (e.g. "utilities-terminal") | no-op |
| `set_tooltip` | supported | no-op |
| `on_click` | panel Activate signal | icon click |
| `set_menu` | builds DBusMenu + ContextMenu self-drawn fallback | native SetMenu |

Linux icon notes: the image path passed to `Tray::new` is only used to take the file name as the tray Id; the bitmap is generated programmatically by `icon.mbt` (an outer circle plus an offset cut-out circle forming a crescent, 2×2 supersampled anti-aliasing, output as big-endian ARGB required by the SNI spec), without depending on any image assets or decoders; to change the icon with the system theme, use `set_icon_name`.

## Menus: the two paths of set_menu

Different panels consume tray menus differently, so the SNI backend prepares both paths:

- **Panel mirrors the DBusMenu for rendering** (XFCE 4.18, verified to take this path): `set_menu` walks the top-level items and separators of the unified `Menu` model to build the DBusMenu (id = array index + 1, 0 is the root); clicking a menu item triggers the original callback via `MenuItem::Click`; submenus are not yet supported. DBusMenu's `AboutToShow` always returns false — returning true would make the panel treat the left click as a menu click and stop sending Activate (same semantics as ksni).
- **ContextMenu(x, y) → application self-draws** (Qt style): the panel calls `ContextMenu` with the icon's screen coordinates, and the application pops up its own menu at that point using `Menu::popup_at(x, y)`, with the callback registered via `set_context_menu_handler`.

XFCE's libdbusmenu client only sends the batch versions `EventGroup` / `AboutToShowGroup`; single-item versions are silently rejected with UnknownMethod — traybus implements both the single-item and batch method groups. See [docs/adaptation.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/adaptation.md) for the packet-capture diagnosis process.

## Desktop environment compatibility

| Desktop environment | Status | Notes |
| --- | --- | --- |
| XFCE 4.18 | ✅ verified | icon, Activate click, context menu all work |
| KDE / MATE / Cinnamon / Budgie / LXQt | ❓ pending verification | protocol-level native SNI support, expected to work |
| GNOME + AppIndicator extension | ❓ pending verification | protocol-level support, pending real-machine verification |
| vanilla GNOME | ❌ | no tray protocol; `Err(Unsupported)` is expected behavior |
| Windows 10 / 11 | ✅ verified | native `Shell_NotifyIconW` backend |
| macOS | ❓ untested | native backend |

Status markers are consistent with [docs/adaptation.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/adaptation.md): ✅ verified working / ⚠️ partially working or conditional / ❌ not working / ❓ untested.
After real-machine testing of each, write version numbers and differences back into adaptation.md per the maintenance conventions and update this table.

## Debugging and verification

- For protocol interop issues, the first choice is `dbus-monitor` captures on the **real session bus**: criteria and cases (batch-version signals, `Notify` notification not sent, etc.) are in the "DBus wire protocol pitfalls" and "Desktop environments" sections of adaptation.md.
- Unit tests only prove encode/decode self-consistency (alignment, signatures, length prefixes and other wire-level rules have independent tests); **interop conclusions must come from a real bus and a real panel** — this is a repository-level verification rule, not an optional requirement of this module.
