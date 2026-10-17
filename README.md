# native-gui [![CI](https://github.com/lb091188/moonbit-native-gui/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-native-gui/actions/workflows/ci.yml)

> **Renamed**: this project is now **native-gui**, formerly `moonbit-libyue`. The mooncakes package is **`NoahLiu/native-gui`**; the old name will be retired once the self-drawn stack stabilizes. Sub-modules rename in step: `NoahLiu/yue-media` → **`NoahLiu/gui-media`**, `NoahLiu/yue-examples` → **`NoahLiu/gui-examples`**.

> **On origins**: this library began as a MoonBit binding of [Cheng Zhao (zcbenz)](https://github.com/zcbenz)'s [Yue / libyue](https://github.com/yue/yue), with [Yoga](https://github.com/facebook/yoga)'s flexbox for layout. Neither is a runtime dependency now — both stay as references for behavior and sources of material. Thanks also to [MoonBit](https://github.com/moonbitlang).

A cross-platform desktop GUI framework for [MoonBit](https://github.com/moonbitlang) — one MoonBit codebase produces native windows on Windows ✅ / Linux ✅, with tray, notifications, global shortcuts, file dialogs and more ready to use. Zero config after `moon add`. The macOS backend is landing on the `mac` branch.

English | [简体中文](https://github.com/lb091188/moonbit-native-gui/blob/master/README_ZH.md)

![Component showcase](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/public/images/showcase-main.png)

![Live demo on Linux (XFCE)](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/public/images/showcase-anim-linux.webp) ![Live demo on Windows](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/public/images/showcase-anim-windows.webp)

*Second image: Linux (XFCE) · Third image: Windows — the same MoonBit codebase*

## Core highlights

**🖥 Full system integration** — tray, notifications, global shortcuts, clipboard, native menus, file dialogs, drag & drop, autostart and more desktop essentials work out of the box, plus system queries for volume, power, wallpaper, monitors, printers and beyond. Capabilities are probed and degrade in a structured way — never silently. See the [system capabilities overview](docs/system-capabilities.md) for the full list.

**🎨 Self-drawn rendering pipeline** — no Skia-class engine dependency; widgets look the same on every platform, light/dark mode and the system accent colour are followed by default, and the theme is fully customizable.

**📊 A complete widget set** — five general chart types (line / bar / pie / gauge / scatter), plus specialised charts such as radar, heatmap, candlestick, funnel, boxplot, sankey, tree, treemap, sunburst and map, with a cross-cutting interaction layer. The Markdown view, the embedded WebView and the self-drawn widgets share one rasterizer and one layout tree.

**📝 Declarative UI and reactive state** — the interface is described as a tree and mounted in one `mount_window` call; state lives in `Store` / `Signal`, and bound spots refresh with the data:

```moonbit
fn main {
  let app = match @ui.mount_window(
    [@ui.text("Hello, MoonBit!", font_size=18.0)],
    title="Hello, MoonBit!",
    width=400,
    height=300,
  ) {
    None => {
      // no window backend or no display service on this host
      return
    }
    Some(a) => a
  }
  app.run()
}
```

> `moon run examples/showcase` — the 15-page demo board: the component library, system capability probes and extended charts.

## Ecosystem position

GUI efforts in the MoonBit ecosystem each have their lane: [MoUI](https://github.com/wzzc-dev/MoUI) targets shared logic across platforms, and [Sun](https://github.com/wzzc-dev/sun) provides the low level for graphics and text rendering. native-gui depends on neither and takes a third lane — **one-stop delivery for desktop apps**: everyday desktop capabilities work out of the box, common widgets are ready-to-use components.

## Package layout

`moon add NoahLiu/native-gui` brings in the whole module. MoonBit compiles and links only the packages you import, so unused packages add nothing to your binary:

| Import in `moon.pkg` | Alias | Contents |
|---|---|---|
| `NoahLiu/native-gui/base` | `@base` | Platform-free primitives: the `Store` / `Signal` / `ListStore` reactive core, the focus stack, key-code constants, end-of-frame batching and the frame ledger |
| `NoahLiu/native-gui/shell` | `@shell` | System-capability shell: menu bars / context menus, the global-hotkey facade, tray, notifications, open-externally, plus the loop scheduler and read-only platform probes |
| `NoahLiu/native-gui/widget` | `@widget` | Self-drawn widget host: layout-tree mapping, hit-testing and event routing, paint walk, declarative `Node`, overlays (layer and native tiers), drag & drop, input mapping, the `App` pump |
| `.../native-gui/ui` | `@ui` | Self-drawn controls and the component library: window mounting, labels / buttons, forms, display, navigation, date, tables and virtual lists, entries, scrolling, overlays, code view, declarative layer |
| `.../native-gui/render` | `@render` | Rasterizer: pure-MoonBit software raster plus a Cairo backend; bitmaps, canvas, images, PNG |
| `.../native-gui/text` | `@text` | Text layer: font families, fonts, rich text and range attributes (Pango / DirectWrite) |
| `.../native-gui/theme` | `@theme` | Theme system: palette derivation and change subscription |
| `.../native-gui/icons` | `@icons` | Vector icon system |
| `.../native-gui/sys` | `@sys` | System capabilities: autostart, idle, subprocess, environment, files, JSON, dialogs, browser history / bookmarks, recent files, wallpaper, volume, power, printers, monitors, window control, app lookup |
| `.../native-gui/input` | `@input` | Editing core and key codes |
| `.../native-gui/win` | `@win` | Platform window backends, the Win32 / GTK3 C stubs: hotkeys, icons, input methods, message boxes, notifications, tray, surfaces |
| `.../native-gui/dbus` | `@dbus` | Linux D-Bus bridge: tray SNI, notifications, logind / upower, media, network, screensaver |
| `.../native-gui/chart` | `@chart` | Charts and the cross-cutting interaction layer |
| `.../native-gui/mdview` | `@mdview` | Markdown rendering view |
| `.../native-gui/style` | `@style` | Style layer: stylesheets as MoonBit values, with state classes and transitions |

Heavier optional capabilities live in **separate modules**, so a plain `moon add` never pulls them in:

| Module | Contents |
|---|---|
| `NoahLiu/gui-media` | Audio/video engine and the player component.
| `NoahLiu/gui-webview` | Embedded WebView (WebKitGTK / WebView2), extracted from the main module's `web` subpackage on 2026-10-16. |
| `NoahLiu/gui-examples` | Standalone example module; depends on `gui-media`. |

Two kinds of "optional" are at work: a sub-package you do not import costs nothing in your binary, because the `moon.pkg` import is the compile and link boundary; a module you do not depend on is never resolved or prebuilt, because the `moon.mod` import sets the dependency closure.

## Quick start

New to MoonBit? The [documentation site](https://moonbit-libyue.pages.dev/) covers the toolchain and your first window. The prerequisite is the MoonBit native toolchain.

```sh
moon add NoahLiu/native-gui
```

Then run one of the bundled examples:

```sh
moon run examples/hello          # minimal window
moon run examples/hello-themed   # themed widget set
moon run examples/showcase       # full demo board
moon run examples/browser        # embedded WebView browser
```

## Platform support

| Platform | Status | Notes |
|---|---|---|
| Ubuntu 24.04 (XFCE / GNOME / KDE) | ✅ | X11 is the primary path |
| Deepin 23 / 25 | ✅ | |
| Windows 10 / 11 | ✅ | Built as a GUI-subsystem exe — double-clicking opens no console |
| macOS | 🚧 | Landing on the `mac` branch: Cocoa / CoreText / ImageIO / WKWebView; CI green, on-device re-verification pending |

## Documentation

📚 **Online docs**: <https://moonbit-libyue.pages.dev/> — Chinese version at [`/zh/`](https://moonbit-libyue.pages.dev/zh/).

| Document | Content |
|---|---|
| [docs/README.md](docs/README.md) | Documentation index and package overview |
| [docs/adaptation.md](docs/adaptation.md) | Platform adaptation notes: field-tested pitfalls and fixes per platform |
| [docs/autostart.md](docs/autostart.md) | Cross-platform autostart |
| [docs/tray.md](docs/tray.md) | Linux tray: SNI protocol-stack design |
| [docs/system-capabilities.md](docs/system-capabilities.md) | System capabilities overview |
| [docs/zh/design.md](docs/zh/design.md) | Frontend-oriented design notes (Chinese) |

## Contributing

Platform-compatibility reports, new widgets and doc improvements are all welcome. The macOS backend has landed on the `mac` branch; on-device visual verification and the merge back are the biggest open items, and they need an Apple Silicon machine. The basic requirements:

- **Commit gate**: from `gui/`, `moon check` plus `moon test core ui render text theme icons sys input win dbus chart mdview web style` — zero errors, zero warnings
- **Experience on record**: field-tested pitfalls and their fixes go into [adaptation.md](docs/adaptation.md), not only into commit messages
- **Small batches**: one cohesive change per commit, short commit messages

The full process is in [AGENTS.md](AGENTS.md).

## License

`native-gui` is released under the [MIT License](LICENSE). Third-party asset licenses and origins: see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) at the repo root.

## References

- [MoonBit docs](https://docs.moonbitlang.cn/)
- Projects this library learned ideas from: [Yue / libyue](https://github.com/yue/yue) · [Yoga](https://github.com/facebook/yoga)
