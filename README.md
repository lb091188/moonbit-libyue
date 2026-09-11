# moonbit-libyue

MoonBit bindings for [libyue](https://libyue.com/docs/latest/cpp/).  
The upstream library supports Windows, macOS and Linux; the first milestone of this port targets Ubuntu + Xfce4 (X11), with the remaining platforms to follow.

- [x] Linux X11
- [ ] Linux Wayland
- [ ] Windows
- [ ] macOS

English | [简体中文](README_ZH.md)

## Yue

A library for creating native cross-platform GUI apps.

## Three-Layer Architecture

```
┌─────────────────────────────────────────────┐
│ Consumers (examples/*)                      │  Pure MoonBit, zero platform code
├─────────────────────────────────────────────┤
│ MoonBit library (yue/)                      │  Unified API: types, closures,
│                                             │  encoding, platform probing and
│                                             │  fallback — all absorbed here
├─────────────────────────────────────────────┤
│ Platform layer (shim/ + vendor/libyue)      │  Thinnest C ABI (mechanical
│                                             │  translation) + libyue absorbing
│                                             │  win/linux/macos differences
└─────────────────────────────────────────────┘
```

Layering rules:

1. **If MoonBit can solve it, it stays out of C/C++** — string UTF-16↔UTF-8 conversion, the closure keep-alive registry, error enums, and tray fallback logic all live in `yue/`.
2. **The C++ shim only translates ABI** — `shim/yue_mbt.cpp` maps function-by-function to `shim/include/yue_mbt.h`, with no business logic.
3. **Platform differences converge in two stages** — what libyue already unifies (windows, widgets) is used directly; what libyue does not expose (e.g. Linux tray backend probing, where it only logs on dlopen failure) is supplemented by shim probing interfaces, and the MoonBit layer translates them into a unified `Result` / `is_supported()` semantics.

## Layout

```
yue/                 MoonBit library package
  ffi.mbt            Private extern "c" declarations (native backend only)
  types.mbt          Widget type definitions (Window/Label/View handles and wrappers)
  app.mbt            App lifecycle: init / run / quit
  view.mbt           Common View capabilities + callback registry (focus/enable/style/drag)
  widgets.mbt        Basic and composite widgets (Button/Entry/Slider/Picker/ComboBox/ProgressBar/Popover…)
  browser.mbt        Embedded browser (WebView)
  menu.mbt           Menu bar / popup menu / menu items
  dialog.mbt         File open/save dialogs
  text_edit.mbt      Multiline text editor
  tab.mbt            Tab control
  table.mbt          Table + data model bridge accepting MoonBit traits
  painter.mbt        2D drawing (Painter / offscreen Canvas)
  misc.mbt           Group / Scroll / Separator / Clipboard / MessageBox
  color.mbt          Color utilities (pure MoonBit)
  error.mbt          Structured errors
  tray.mbt           Unified tray API
  traybus/           Pure-MoonBit DBus + StatusNotifierItem protocol stack (Linux tray)
    wire.mbt         DBus wire format codec
    bus.mbt          Session bus connection, SASL EXTERNAL handshake, message dispatch
    sni.mbt          SNI protocol implementation
    detect.mbt       Desktop environment detection (XDG_CURRENT_DESKTOP)
    icon.mbt         Procedurally generated tray bitmap (no image assets or decoders)
    sys.mbt          fd-level syscall surface (all forwarded via shim)
shim/                C ABI wrapper layer (yue_mbt.cpp + include/yue_mbt.h) + CMakeLists
scripts/prepare.py   Pinned-version libyue download + static library build + link-flag writeback
examples/            13 examples: hello / editor / browser / drawing / table / widgets /
                     drag_source / drag_destination / floating_heart /
                     auto_height_edit / showcase / misc / advanced
.agents/skills/      MoonBit skill library (the FFI conventions referenced throughout)
```

## Quick Start

System dependencies (Ubuntu 24.04):

```sh
sudo apt install build-essential cmake pkg-config \
  libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev \
  libwebkit2gtk-4.1-dev
```

Build the native library and run an example:
 **Note: this downloads libyue and its dependencies from GitHub.** 

```sh
python3 scripts/prepare.py
moon run examples/hello
```

Both `prepare.py` and `moon` must be run from the repository root: the written link flags use a repo-root-relative `-L build` (the linker resolves relative paths from moon's working directory). `prepare.py` is idempotent — a cached archive whose sha256 does not match (e.g. an interrupted download) is deleted and re-downloaded; unchanged moon.pkg.json files are not rewritten.

The pure-MoonBit parts (DBus wire codec, color utilities, table value codec) do not require the native library and can be tested directly:

```sh
moon test
```

## Linux Tray

The AppIndicator runtime library cannot be relied upon (Ubuntu 24.04 dropped the legacy version), and libyue only logs when loading fails internally — the object silently goes dead. So this project instead **speaks the StatusNotifierItem protocol directly to the panel from MoonBit**, with no AppIndicator runtime dependency:

- `yue/traybus/` is a pure-MoonBit implementation: DBus wire codec, SASL EXTERNAL handshake, message send/receive loop (wired into the GTK main loop via a glib fd watch), SNI property/signal/Activate dispatch, desktop environment detection (XDG_CURRENT_DESKTOP), and a procedurally generated crescent bitmap;
- the shim forwards only 8 fd-level syscalls (connect/read/write/poll/close/watch_fd/getuid/getenv), non-Linux platforms get failing stubs;
- backend priority: SNI watcher online → self-implemented tray; not online → fall back to nativeui AppIndicator; neither available → `Err(Unsupported)`. Works on XFCE/KDE/MATE/Cinnamon/Budgie/LXQt and GNOME with the AppIndicator extension installed; plain GNOME without a tray protocol reports a clear error;
- consumers face a unified API: `Tray::new / is_supported / set_title / set_icon / set_icon_name / set_tooltip / on_click / set_menu / remove`, plus `desktop_environment()` for diagnostics;
- known pitfalls (documented from real-world testing): the DBus array length prefix **excludes alignment padding before the first element** — including it makes dbus-daemon disconnect as a protocol violation; the SIGNATURE field in the DBus header uses the variant signature "g" (u8-length encoded) — encoding it as "s" passes self-consistent unit tests but gets rejected by the real bus. Unit tests prove self-consistency; interop must be verified against a real bus.

## Known Limitations

- moon's `link` section only applies to the package it belongs to, and only to the final binary of a main package; putting a link section in the library package `yue/` makes moon emit a main-less executable (moon appends `.exe` to artifacts on all platforms) and the build fails. `prepare.py` only writes back to `is-main` packages, and `cc-link-flags` uses the repo-root-relative `-L build`, so `moon` must be invoked from the repository root (calling it from a subdirectory will not find `libyue_mbt.a`).
- `extern "c"` cannot return nullable types (the ABI is incompatible with C pointers — instant segfault): success/failure is reported through `Ref[Int]` out-params, handles are returned as non-null.
- FFI pointer parameters must be annotated `#borrow` (compiler-enforced); multiple such parameters in one function go in a single `#borrow(a, b)`.
- The Linux tray probe list must exactly match libyue's internal dlopen list (`libappindicator3` only); having the ayatana variant installed does not mean it is usable — nativeui only logs when loading fails and later calls hit a null pointer (the shim adds null-pointer defenses). With the SNI self-implemented backend in place, this path is fallback-only.
- MoonBit closures/function values across the C ABI: only capture-less top-level function literals are allowed (compiled to real C function pointers); closures with captures use the "function pointer + closure pointer" two-parameter pattern (`on_click` family).
- A Table (GTK) inside a Notebook tab segfaults during size measurement (negative allocation); it must go in a plain container or its own window (showcase uses a separate child window).
- The macOS branch has dual ARC/no-ARC library variants, untested; Windows link flags are not automated yet.
- The current binding surface is roughly 250 ABI functions (248 `extern "c"` declarations in `yue/ffi.mbt`): App/Lifetime, Window, common View capabilities and drag & drop, Container/Label/Button/Entry/TextEdit, Slider/Picker/ComboBox/ProgressBar/Tab/Group/Scroll/Separator/DatePicker/GifPlayer, Browser, Menu/MenuBar, Table + model bridge, Painter/Canvas, Tray/Notification/GlobalShortcut/Clipboard/MessageBox/Popover/FileDialog, Screen/Appearance/Locale/Cursor. New widgets follow the established pattern: add a mechanical translation function in the shim → add the extern in `ffi.mbt` → add the type and methods in a new `*.mbt`.
- extern declarations must use the underlying handle type `View` for widget parameters, not MoonBit wrapper structs (e.g. `Slider`): passing a struct over the ABI delivers the wrapper object instead of the handle value, so every call reports "invalid handle" and is silently dropped (the Slider/Table families were entirely broken by this, fixed 2026-09).
- Callback closures are kept alive by the registry in `view.mbt`; entries are not yet reclaimed after window destruction (acceptable at this stage).

## References

- libyue documentation: <https://libyue.com/docs/latest/cpp/guides/getting_started.html>
- Lua bindings (architectural reference): `lua_yue/` in github.com/yue/yue
- MoonBit skill library: `.agents/skills/` (including `moonbit-c-binding` and `make-moonbit-c-bindings` — the authoritative FFI conventions)
