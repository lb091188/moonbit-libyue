# moonbit-libyue

[![CI](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml)

MoonBit bindings for [libyue](https://libyue.com/docs/latest/cpp/) — build native cross-platform desktop apps (Windows / macOS / Linux) in pure MoonBit.

## Platform support

- [x] Ubuntu 24.04 Xfce
- [x] Ubuntu 24.04 GNOME
- [x] Ubuntu 24.04 KDE
- [x] Deepin 25
- [x] Windows 10 / 11 (first verified 2026-09, full showcase runs; see [docs/adaptation.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/adaptation.md))
- [?] macOS (no devices can't test)

English | [简体中文](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/README_ZH.md)

## Yue

A library for creating native cross-platform GUI apps.

## Three ways to build UI

| # | Stack | Typical code | For |
|---|---|---|---|
| 1 | **Themed component library + declarative + reactive** | `button_t` / `side_menu` / `tag` / `alert` … nodes bound to `Store` | Modern app shells — recommended |
| 2 | **Native libyue widgets + declarative + reactive** | `button` / `entry` / `slider` … nodes + `Store` bindings | Native look with declarative code |
| 3 | **Native libyue widgets + imperative** | `Window::new` + `set_content` + setters | Close to the raw libyue API |

The themed layer keeps native rendering while providing a modern Element-Plus-style look, declarative node trees and reactive data binding — native, and pleasant to use.

## Demos

### Modern — themed component library (layer 1)

`moon run examples/components` — a four-page demo board covering the full themed library, every component and state; API reference in [docs/components-ui.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/components-ui.md):

![Basic](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/components-basic.png)

![Navigation](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/components-nav.png)

![Data display](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/components-data.png)

![Feedback](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/components-feedback.png)

### Classic — native widgets (layers 2–3)

`moon run examples/showcase` — a 12-page demo covering the full native widget set (widgets / inputs / canvas / browser / table / dialogs / menus / tray / clipboard / events …) — widgets tab:

![Showcase widgets page](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/widgets.png)

More examples (17 total: hello / editor / browser / drawing / table / drag & drop / tray …) live in [examples/](https://github.com/lb091188/moonbit-libyue/tree/master/examples).

## Usage

### Quick start

#### Ubuntu 24.04

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

#### Windows (10/11, x64)

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

### Use as a dependency (mooncakes)

```sh
moon add NoahLiu/moonbit-libyue
moon run src   # no link configuration needed; the native layer builds on install, the build hook rebuilds it when missing
```

### Declarative UI

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

Layout (flexbox via yoga), scrolling, grouping and more node types are covered in [docs/declarative.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/declarative.md).

### Documentation

| Document | Content |
|---|---|
| [components-ui.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/components-ui.md) | Themed component library API with demo screenshots |
| [declarative.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/declarative.md) | Declarative `Node`/`mount` trees + `Store` reactive bindings |
| [components.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/components.md) | Widget API quick reference: classic setters and `X::make` props styles |
| [layout.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/layout.md) | Layout style keys (Yoga flexbox) |
| [adaptation.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/adaptation.md) | Platform pitfalls, root causes and verification conclusions |
| [tray.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/tray.md) | Linux tray: SNI protocol stack design and backend fallback |
| [relink.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/relink.md) | Forcing a relink after native-layer changes |

Full index: [docs/README.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/README.md).

## Development

- Build & test: `moon check && moon test` — the pure-MoonBit parts (DBus wire codec, color/table value codecs) run without the native library.
- Adding a widget: mechanical translation in `shim/yue_mbt.cpp` → declaration in `shim/include/yue_mbt.h` → `extern "c"` in `yue/ffi.mbt` → type & methods in a new `yue/*.mbt` (FFI conventions in `.agents/skills/moonbit-c-binding/`).
- Current binding surface: ~320 ABI functions (324 `extern "c"` declarations in `yue/ffi.mbt`).
- Real-world pitfalls and platform lessons go to [docs/adaptation.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/adaptation.md); usage docs and code comments stay content-only.
- After shim/vendor changes, force a relink: `moon clean` or delete the executable — see [docs/relink.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/relink.md).

## References

- libyue documentation: <https://libyue.com/docs/latest/cpp/guides/getting_started.html>
- Lua bindings (architectural reference): `lua_yue/` in github.com/yue/yue
- MoonBit skill library: `.agents/skills/` (`moonbit-c-binding`, `make-moonbit-c-bindings`)
- AI collaboration rules: `AGENTS.md` · platform adaptation experience: [docs/adaptation.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/adaptation.md)
