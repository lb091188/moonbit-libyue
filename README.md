# moonbit-libyue

[![CI](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml)

MoonBit bindings for [libyue](https://libyue.com/docs/latest/cpp/) — build native cross-platform desktop apps (Windows / macOS / Linux) in pure MoonBit.

English | [简体中文](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/README_ZH.md)

![Component showcase](docs/images/showcase-basic.png)

## Highlights

**🎨 Modern theme** — An Element-Plus-style themed component library (50+ widgets: buttons / forms / navigation / data display / feedback), fully self-drawn and visually consistent across all three platforms; reskin with one `theme_apply` call, light/dark follows the system:

```moonbit
@yue.theme_apply({ ..@yue.default_theme(), primary: "#1E4FA3" })
```

**📝 Declarative** — Describe the UI as a node tree; no `new + set_content` plumbing:

```moonbit
let window = @yue.mount_window(
  [
    @yue.label("Hello, MoonBit + libyue!", style=[("margin", 20.0)]),
    @yue.button("Quit", on_click=fn() { @yue.quit() }),
  ],
  title="Hello", size=Some((420.0, 160.0)), center=true, on_close=fn(_w) { @yue.quit() },
)
```

**⚡ Reactive signals** — State lives in `Signal` / `Store`; bound views refresh automatically, no "on click update that label" glue:

```moonbit
let clicks = @yue.Signal::new(0)
@yue.button("Click me", on_click=fn() { clicks.update(fn(n) { n + 1 }) }),
@yue.bind(clicks, fn(n) { "Clicked \{n} times" }),  // derived text, updates on click
```

The three compose freely: the themed library is the recommended front door (unified look), while libyue native widgets and the imperative style remain fully available.

> **New to MoonBit?** Start with the [five-minute tutorial](docs/tutorial.md): from `moon new` to a running window, with links to the official MoonBit tutorial and the interactive Tour.

## Quick start

```sh
# Ubuntu 24.04: one-time system dependencies (GTK/WebKit dev packages)
sudo apt install build-essential cmake pkg-config \
  libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev libwebkit2gtk-4.1-dev

# As a dependency: prebuilt native libraries ship with the package — zero C++ compilation
moon add NoahLiu/moonbit-libyue
moon run src

# Run the demo board
git clone https://github.com/lb091188/moonbit-libyue && cd moonbit-libyue
moon run examples/showcase
```

<details>
<summary>Windows (10/11, x64) setup</summary>

Requires Python 3, MoonBit, CMake and the MSVC C++ toolchain (with ATL). moon locates `cl` via PATH when compiling native code, so run from "x64 Native Tools Command Prompt for VS 2022" or call `vcvars64.bat` first:

```powershell
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex            # MoonBit
winget install Kitware.CMake
winget install Microsoft.VisualStudio.2022.BuildTools -e --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
# Add the ATL component:
Start-Process -FilePath 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe' -ArgumentList 'modify','--installPath','"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"','--add','Microsoft.VisualStudio.Component.VC.ATL','--quiet','--norestart' -Verb RunAs -Wait
```

</details>

**Projects must target native**: the `moon new` template defaults to `preferred_target = "wasm"` and fails with `ffi_* is unbound`; change `preferred_target` to `"native"` in moon.mod.

## Three ways to build a UI

| Layer | Style | Best for |
|---|---|---|
| 1 | **Themed library + declarative + reactive**: `button_t` / `side_menu` / `tag` … nodes + `Store` bindings | Modern app shells, recommended |
| 2 | **libyue native widgets + declarative + reactive**: `button` / `entry` / `slider` … nodes + `Store` bindings | Native look with declarative code |
| 3 | **libyue native widgets + imperative**: `Window::new` + `set_content` + setters | Closest to raw libyue |

## Demo

```sh
moon run examples/hello         # minimal native-widget window
moon run examples/hello-themed  # themed minimal example (theme_apply + button_t/input_t/label_t)
moon run examples/showcase      # full demo board: 15 pages, 3 collapsible side-menu groups
```

The showcase covers Basic / Icons / Form / Navigation / Data / Feedback / Code & Docs / Events & Layout / Store comparison + Native widgets / Canvas & rich text + System / Window / Browser / Environment, with a collapsible grouped side menu and the package version pinned at the bottom (kept in sync with moon.mod). More screenshots in [docs/README.md](docs/README.md).

![Navigation page](docs/images/showcase-nav.png)

## Documentation

| Doc | Content |
|---|---|
| [components-ui.md](docs/components-ui.md) | Themed component library quick reference: per-API signatures and parameter tables, plus theme customization |
| [declarative.md](docs/declarative.md) | Declarative `Node`/`mount` trees + `Store` reactive bindings |
| [components.md](docs/components.md) | Widget API quick reference: classic setters and `X::make` props styles |
| [layout.md](docs/layout.md) | Layout style key quick reference: all keys + common-combination examples |
| [adaptation.md](docs/adaptation.md) | Platform pitfalls, root causes and verification conclusions |
| [tray.md](docs/tray.md) | Linux tray: SNI protocol stack design and backend fallback |
| [relink.md](docs/relink.md) | Forcing a relink after native-layer changes |

Full index: [docs/README.md](docs/README.md).

## Platform support

Ubuntu 24.04 (XFCE / GNOME / KDE) ✅ · Deepin 25 ✅ · Windows 10/11 ✅ · macOS builds on CI (no device)

## Contributing

- Build & test: `moon check && moon test` (gate: zero errors, zero warnings)
- Adding a widget: mechanical translation in `shim/yue_mbt.cpp` → declaration in `shim/include/yue_mbt.h` → `extern` in `yue/ffi.mbt` → type & methods in a new `yue/*.mbt` (FFI guide in `.agents/skills/moonbit-c-binding/`)
- Real-machine findings go to [docs/adaptation.md](docs/adaptation.md); push `bin-*` tags for binary releases, `vendor-*` tags for native-layer updates

## Reference

- libyue docs: <https://libyue.com/docs/latest/cpp/guides/getting_started.html>
- Lua bindings (architecture reference): github.com/yue/yue
