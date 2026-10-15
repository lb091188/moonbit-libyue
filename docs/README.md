# Documentation Index

This directory holds the documentation for **native-gui** — a native, cross-platform desktop GUI library for [MoonBit](https://github.com/moonbitlang). Windows, pixels, the event loop, layout and widgets are all pure MoonBit; the mooncakes package is `NoahLiu/native-gui`.

## Packages

`moon add NoahLiu/native-gui` brings the whole module, but MoonBit compiles and links only the packages you import — an unused package costs nothing in your binary:

| Import in `moon.pkg` | Alias | Contents |
|---|---|---|
| `NoahLiu/native-gui/core` | `@core` | App host, event loop, focus / keys / pointer, menus, notifications, tray, overlays, drag & drop, `Store` / `Signal` |
| `.../native-gui/ui` | `@ui` | Self-drawn widgets and the component library: window mount, labels / buttons, forms, display, navigation, date, tables & virtual lists, entries, scroll, overlays, code view, declarative layer |
| `.../native-gui/render` | `@render` | Rasterizer — a pure-MoonBit software raster (path / fill / blend / gradient) plus a Cairo backend; bitmaps, canvas, images, PNG |
| `.../native-gui/text` | `@text` | Text layer: font families, fonts, attributed text and range attributes (Pango / DirectWrite) |
| `.../native-gui/theme` | `@theme` | Theme system: palette derivation + change subscription |
| `.../native-gui/icons` | `@icons` | Vector icon system |
| `.../native-gui/sys` | `@sys` | OS capabilities: autostart, idle, subprocess, env, files, JSON, dialogs, browser history / bookmarks, recent files, wallpaper, volume, power, printers, monitors, window control, app lookup… |
| `.../native-gui/input` | `@input` | Editing core and key codes |
| `.../native-gui/win` | `@win` | Platform window backend (Win32 / GTK3 C stubs): hotkeys, icons, IME, message boxes, notifications, trays, surfaces |
| `.../native-gui/dbus` | `@dbus` | Linux D-Bus bridge (tray SNI, notifications, logind / upower, media, network, screensaver…) |
| `.../native-gui/chart` | `@chart` | Charts, plus the cross-cutting interactive layer |
| `.../native-gui/mdview` | `@mdview` | Markdown rendering view |
| `.../native-gui/web` | `@web` | Embedded WebView |
| `.../native-gui/style` | `@style` | Style layer: stylesheets as MoonBit values — `Style` rule blocks and named class constants, hover / active / focus states, transitions |

Heavier optional capabilities live in **separate modules**, so a plain `moon add` never drags them in:

| Module | Contents |
|---|---|
| `NoahLiu/gui-media` | Audio/video engine (ffmpeg decode + miniaudio output) and the player component. |
| `NoahLiu/gui-examples` | Standalone example module (audio / video players) that depends on `gui-media`. |

**Two layers of "optional"** — a sub-package you do not import costs nothing in your binary (the `moon.pkg` import is the compile/link boundary); a module you do not depend on is not even resolved or prebuilt (the `moon.mod` import defines the dependency closure). A capability can only reach the second layer by living in its own module.

## Demo

Examples, from shallow to deep:

```sh
moon run examples/hello          # a minimal window
moon run examples/hello-themed   # the themed widget set
moon run examples/showcase       # full demo board: component library + system probes
moon run examples/browser        # embedded WebView browser (demo menu + status bar)
moon run examples/charts         # extended charts gallery (radar / sankey / sunburst …)
```

`examples/showcase` covers Basic / Icons / Form / Navigation / Data Display / Charts / Feedback / Code & Docs / Events & Layout / Store / Window, plus canvas & rich text, system integration, transitions & effects and a read-only **system probe** page, with a collapsible grouped side menu. Each page's source is its own file (`examples/showcase/pages/*.mbt`) — the best copy-paste material library.

![Basic components](/images/showcase-basic.png)

![Form components](/images/showcase-form.png)

![Data display](/images/showcase-data.png)

![Code & docs](/images/showcase-code.png)

![System integration](/images/showcase-system.png)

## Routing

**Usage**

| Document | Content |
|---|---|
| [tutorial.md](tutorial.md) | Five-minute tutorial: install the toolchain, create a project, build a first window with a click counter |
| [components.md](components.md) | Component quick-reference (`@ui`): every widget/component constructor's signature and purpose, by family |
| [declarative.md](declarative.md) | Declarative layer & reactivity: the `Node` tree, `mount_window`, `Store` / `Signal`, `for_list` / `when`, in-place replacement |
| [layout.md](layout.md) | Layout styling: the `Style` field set and the `class` channel on yoga-mbt (CSS Flexbox L1) |
| [system-capabilities.md](system-capabilities.md) | System capabilities (`@sys`): volume / app lookup / wallpaper / monitors / window control / clipboard watch / power profiles / printers / env / recent files / browser bookmarks & history / VS Code history…, with a unified `Result` semantics |
| [build.md](build.md) | Build & linking: how prebuild hosts link flags, and the one pitfall — editing a C stub without relinking |

**Platform notes**

| Document | Content |
|---|---|
| [adaptation.md](adaptation.md) | Platform adaptation notes: field-tested pitfalls and fixes, per platform (continuously updated) |
| [autostart.md](autostart.md) | Cross-platform autostart: XDG `.desktop` on Linux / HKCU Run key on Windows, one `is_enabled` / `enable` / `disable` API |
| [tray.md](tray.md) | Linux tray: SNI protocol-stack design, architecture, backend fallback, desktop compatibility |

**Project** (Chinese only)

| Document | Content |
|---|---|
| [zh/design.md](/zh/design.md) (Chinese) | Frontend-layer design notes: style sheets as MoonBit values (`Style` + named class constants, CSS as an import channel), component naming mapping, reactivity and view-layer decisions |
| [zh/roadmap.md](/zh/roadmap.md) (Chinese) | Public roadmap: positioning, what you can use today, platform support matrix, stability commitment and versioning, next-phase directions, open decisions, explicit non-goals |

For the project overview and quick start, see the repository root [README.md](https://github.com/lb091188/moonbit-native-gui/#readme).

[中文版文档索引](/zh/README.md)
