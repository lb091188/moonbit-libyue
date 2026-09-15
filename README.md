# moonbit-libyue

[![CI](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml)

MoonBit bindings for [libyue](https://libyue.com/docs/latest/cpp/).  
The upstream library supports Windows, macOS and Linux; the first milestone of this port targets Ubuntu + Xfce4 (X11), with the remaining platforms to follow.

- [x] Ubuntu 24.04 Xfce
- [ ] Ubuntu 24.04 GNOME
- [ ] Ubuntu 24.04 KDE
- [ ] Deepin 25
- [ ] OpenKylin 3
- [x] Windows 10 / 11 (first verified 2026-09, full showcase runs; see [docs/adaptation.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/adaptation.md))
- [ ] macOS

English | [简体中文](https://github.com/lb091188/moonbit-libyue/blob/master/README_ZH.md)

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
  geometry.mbt       Geometry value types (pure MoonBit)
  error.mbt          Structured errors
  events.mbt         Event system (mouse/keyboard, modifier normalization, VKEY constants, click tracking)
  button.mbt         Button / single-line Entry (Checkbox/Radio/Password)
  props.mbt          L1 props constructors (X::make / apply_style)
  declarative.mbt    L2 declarative nodes (Node/mount/vbox/label/…)
  store.mbt          L3 reactive Store (subscribe / map / bind_label)
  tray.mbt           Unified tray API
  traybus/           Pure-MoonBit DBus + StatusNotifierItem protocol stack (Linux tray)
    wire.mbt         DBus wire format codec
    bus.mbt          Session bus connection, SASL EXTERNAL handshake, message dispatch
    sni.mbt          SNI protocol implementation
    detect.mbt       Desktop environment detection (XDG_CURRENT_DESKTOP)
    icon.mbt         Procedurally generated tray bitmap (no image assets or decoders)
    sys.mbt          fd-level syscall surface (all forwarded via shim)
shim/                C ABI wrapper layer (yue_mbt.cpp + include/yue_mbt.h) + CMakeLists
scripts/prepare.py   Pinned-version libyue download + static library build (link flags are owned by prebuild.py)
scripts/prebuild.py  Moon build hook: emits per-OS link config, propagated to all dependents
scripts/postadd.py   Auto-triggered on `moon add` for the first native build
examples/            17 examples: hello / editor / browser / drawing / table / widgets /
                     drag_source / drag_destination / floating_heart /
                     auto_height_edit / showcase / misc / advanced / events / layout /
                     components / trayprobe
.agents/skills/      MoonBit skill library (the FFI conventions referenced throughout)
```

## Quick Start

### Ubuntu 24.04

System dependencies:

```sh
sudo apt install build-essential cmake pkg-config \
  libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev \
  libwebkit2gtk-4.1-dev
```

Build the native library and run an example:
 **Note: the first build downloads libyue from GitHub.**

```sh
moon run examples/hello
```

Zero configuration: link flags are emitted per-OS at build time by the `scripts/prebuild.py` hook and propagated automatically; when the static library is missing, `scripts/prepare.py` runs to build it. `prepare.py` is idempotent; after switching OS, the first build rebuilds it.

### Windows (10/11, x64)

Requires Python 3, the MoonBit toolchain (`moon`), CMake, and the MSVC C++ toolchain (with ATL). All commands below were verified on a real machine in this project:

1. Install the MoonBit toolchain (PowerShell):

```powershell
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
```

2. Install CMake and the MSVC C++ toolchain (`winget`, or install the equivalent components via the VS Installer):

```powershell
winget install Kitware.CMake
winget install Microsoft.VisualStudio.2022.BuildTools -e --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

3. Add the ATL component (libyue's Windows sources include ATL headers such as `atldef.h`, which are not installed by default; needs elevation):

```powershell
Start-Process -FilePath 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe' -ArgumentList 'modify','--installPath','"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"','--add','Microsoft.VisualStudio.Component.VC.ATL','--quiet','--norestart' -Verb RunAs -Wait
```

4. Build and run. **On Windows moon looks for `cl` on PATH when compiling native code, so run it from the "x64 Native Tools Command Prompt for VS 2022", or call `vcvars64.bat` first**:

```bat
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
python3 scripts\prepare.py
moon run examples/hello
```

The pure-MoonBit parts (DBus wire codec, color utilities, table value codec) do not require the native library and can be tested directly:

```sh
moon test
```

## Declarative UI in Two Snippets

Windows can be described as declarative node trees (`@yue.mount_window`) instead of imperative `new + set_content` calls. Both examples below run as-is (screenshot links point at the raw files on GitHub).

**1. Hello window** — nodes for a label and a button, mounted straight into a window:

```moonbit
fn main {
  if !@yue.initialize() {
    return
  }
  let window = @yue.mount_window(
    [
      @yue.label("Hello, MoonBit + libyue!", style=[("margin", 20.0)]),
      @yue.button("Quit", on_click=fn() { @yue.quit() }),
    ],
    title="Hello",
    size=Some((420.0, 160.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
  )
  window.activate()
  @yue.run()
}
```

![Hello window](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/hello.png)

**2. Reactive counter** — a `Store` holds the state; `bind_label` re-renders the label on every update. No manual "set text after click" wiring:

```moonbit
let clicks : @yue.Store[Int] = @yue.Store::new(0)
let window = @yue.mount_window(
  [
    @yue.vbox(
      [
        @yue.button("Click me", on_click=fn() { clicks.update(fn(n) { n + 1 }) }),
        @yue.bind_label(clicks, fn(n) { "Clicked \{n} times" }),
      ],
      style=[("padding", 24.0)],
    ),
  ],
  title="Counter",
  size=Some((320.0, 160.0)),
  center=true,
  on_close=fn(_w) { @yue.quit() },
)
```

![Counter window](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/counter.png)

The full [showcase](https://github.com/lb091188/moonbit-libyue/tree/master/examples/showcase) (12 tabs: widgets, inputs, canvas, browser, dialogs, system integration, events, rich text, menus, tables…) is written entirely in this declarative style — widgets page:

![Showcase widgets page](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/widgets.png)

Layout (flexbox via yoga), scrolling, grouping and more node types are covered in [docs/declarative.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/declarative.md).

## Notes

- The current binding surface is roughly 320 ABI functions (324 `extern "c"` declarations in `yue/ffi.mbt`): App/Lifetime, Window, common View capabilities and drag & drop, Container/Label/Button/Entry/TextEdit, Slider/Picker/ComboBox/ProgressBar/Tab/Group/Scroll/Separator/DatePicker/GifPlayer, Browser, Menu/MenuBar, Table + model bridge, Painter/Canvas, Tray/Notification/GlobalShortcut/Clipboard/MessageBox/Popover/FileDialog, Screen/Appearance/Locale/Cursor. New widgets follow the established pattern: add a mechanical translation function in the shim → add the extern in `ffi.mbt` → add the type and methods in a new `*.mbt`.
- Known limitations, ABI pitfalls and per-platform adaptation lessons live in `AGENTS.md` and [docs/adaptation.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/adaptation.md) instead of this README. The Linux tray design — motivation, architecture, backend fallback, desktop compatibility, debugging — is documented separately in [docs/tray.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/tray.md). The widget API quick reference (including upstream pitfalls) lives in [docs/components.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/components.md); the declarative layer — `X::make` props constructors, `Node`/`mount` render trees and `Store` reactive bindings — in [docs/declarative.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/declarative.md).
- Shim/vendor changes or a re-run of `prepare.py` require forcing a relink: `moon clean`, or delete the linked executable — see [docs/relink.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/relink.md).
- Documentation index: [docs/README.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/README.md).

## References

- libyue documentation: <https://libyue.com/docs/latest/cpp/guides/getting_started.html>
- Lua bindings (architectural reference): `lua_yue/` in github.com/yue/yue
- MoonBit skill library: `.agents/skills/` (`moonbit-c-binding`, `make-moonbit-c-bindings`)
- AI collaboration rules: `AGENTS.md` · platform adaptation experience: [docs/adaptation.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/adaptation.md)
