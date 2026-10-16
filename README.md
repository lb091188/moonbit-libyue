# native-gui [![CI](https://github.com/lb091188/moonbit-native-gui/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-native-gui/actions/workflows/ci.yml)

> **⚠ Renamed** — this project is now **native-gui** (formerly `moonbit-libyue`): the mooncakes package is **`NoahLiu/native-gui`** (the old name will be marked deprecated once the stack stabilizes); sub-modules `NoahLiu/yue-media` → **`NoahLiu/gui-media`**, `NoahLiu/yue-examples` → **`NoahLiu/gui-examples`**. 

> **On origins** — this library started life as a MoonBit binding of [Cheng Zhao (zcbenz)](https://github.com/zcbenz)'s [Yue / libyue](https://github.com/yue/yue), with [Yoga](https://github.com/facebook/yoga)'s flexbox for layout. The stack is self-drawn now and depends on neither — what stays with us is what we learned from them. Thanks also to [MoonBit](https://github.com/moonbitlang).

A **desktop GUI library** for the [MoonBit](https://github.com/moonbitlang) ecosystem — everything a desktop app needs from the OS (tray, notifications, shortcuts, autostart, D-Bus…) behind one API, with rendering, layout and widgets owned by a pure-MoonBit stack and no heavy engine like Skia. One codebase runs native windows on Windows ✅ / Linux ✅, with the macOS backend landing on the `mac` branch; zero config after `moon add`.

English | [简体中文](https://github.com/lb091188/moonbit-native-gui/blob/master/README_ZH.md)

![Component showcase](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/public/images/showcase-main.png)

![Live demo on Linux (XFCE)](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/public/images/showcase-anim-linux.webp) ![Live demo on Windows](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/public/images/showcase-anim-windows.webp)

*Left: Linux (XFCE) · Right: Windows — one MoonBit codebase*

## Core highlights

**🖥 Desktop-grade system integration** — tray (SNI / NSStatusItem / Shell_NotifyIcon), notifications, global shortcuts, clipboard, native menus, file dialogs, drag & drop, autostart, idle detection, MPRIS media control (Linux), plus OS queries (volume, power, wallpaper, monitors, printers, browser history, installed apps…) behind one `@sys` / `@core` API — capability probing with semantic fallbacks, never silent.

**🎨 Lightweight self-drawing, one theme everywhere** — rendered by the library's own pure-MoonBit software rasterizer (optional Cairo backend) with no Skia-class engine; the `hello` minimal window ships as a **1.1 MB** release binary that shows a window in ~0.5 s (measured on Linux; the 15-page `showcase` is 5.5 MB / ~1 s). Widgets look the same on every platform; light/dark and the system accent colour are followed by default, and the theme is a plain value you can override.

**📊 Charts & rich content** — charts (line / bar / pie / gauge / scatter plus radar, heatmap, candlestick, funnel, boxplot, sankey, tree, treemap, sunburst, map and more, with a cross-cutting interactive layer), a Markdown view and an embedded WebView share the same rasterizer and layout tree as regular widgets.

**📝 Declarative UI & reactive state** — describe the interface as a tree and let the library drive it; keep state in `Store` / `Signal` (from `@core`) and bound spots refresh themselves when the data changes:

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

> `moon run examples/showcase` — the full demo board: component library + system probes + extended charts (15 pages).

## Ecosystem position

GUI efforts in the MoonBit ecosystem each have their lane: [MoUI](https://github.com/wzzc-dev/MoUI) targets shared multi-platform logic (Skia / WebGPU rendering), and [Sun](https://github.com/wzzc-dev/sun) provides low-level 2D graphics and text rendering. native-gui shares no code with either and focuses on a third lane — **one-stop desktop apps**: deep OS integration plus ready-made desktop components (charts / Markdown / WebView).

## Packages

`moon add NoahLiu/native-gui` brings the whole module, but MoonBit compiles and links only the packages you import — an unused package costs nothing in your binary:

| Import in `moon.pkg` | Alias | Contents |
|---|---|---|
| `NoahLiu/native-gui/core` | `@core` | App host, event loop, focus / keys / pointer, menus, notifications, tray, hotkey facade, overlays, drag & drop, `Store` / `Signal` |
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

**Two layers of "optional"** — a sub-package you do not import costs nothing in your binary (the `moon.pkg` import is the compile/link boundary); a module you do not depend on is not even resolved or prebuilt (the `moon.mod` import defines the dependency closure).

## Quick start

New to MoonBit? The [documentation site](https://moonbit-libyue.pages.dev/) covers the toolchain and your first window.

Prerequisite: the MoonBit native toolchain.

```sh
moon add NoahLiu/native-gui
```

Then run one of the bundled examples:

```sh
moon run examples/hello          # a minimal window
moon run examples/hello-themed   # the themed widget set
moon run examples/showcase       # full demo board: components + system probes + extended charts
moon run examples/browser        # embedded WebView browser (demo menu + status bar)
```

## Platform support

Ubuntu 24.04 (XFCE / GNOME / KDE) ✅ · Deepin 23 / 25 ✅ · Windows 10/11 ✅ · macOS 🚧 landing on the `mac` branch (Cocoa / CoreText / ImageIO / WKWebView; CI green, pending on-device verification)

On Windows, exes are built as a GUI-subsystem binary — no console window on double-click.

## Documentation index

📚 **Online docs**: <https://moonbit-libyue.pages.dev/> — 中文版在 [`/zh/`](https://moonbit-libyue.pages.dev/zh/).

| Document | Content |
|---|---|
| [docs/README.md](docs/README.md) | Documentation index and package overview |
| [docs/adaptation.md](docs/adaptation.md) | Platform adaptation notes: field-tested pitfalls and fixes, per platform |
| [docs/autostart.md](docs/autostart.md) | Cross-platform autostart |
| [docs/tray.md](docs/tray.md) | Linux tray: SNI protocol-stack design |
| [docs/zh/adaptation.md](docs/zh/adaptation.md) | 平台适配经验(中文版) |
| [docs/zh/system-capabilities.md](docs/zh/system-capabilities.md) | System capabilities overview (Chinese) |
| [docs/zh/design.md](docs/zh/design.md) | Frontend-layer design notes (Chinese) |

## Contributing

Everyone is welcome: reporting platform-compatibility issues, adding widgets, improving docs — the macOS backend has landed on the `mac` branch, and its on-device verification & merge is the largest open item (it needs an Apple Silicon machine). A few basic requirements:

- **Commit gate**: the MoonBit native toolchain, then `cd gui && moon check && moon test core ui render text theme icons sys input win dbus chart mdview web style` — zero errors, zero warnings
- **Experience on record**: write field-tested pitfalls together with their fixes into [adaptation.md](docs/adaptation.md) — not only in commit messages
- **Small batches**: one cohesive change per commit, short commit messages

The full process for adding widgets, CI and releases is in [AGENTS.md](AGENTS.md).

## License

`native-gui` is released under the [MIT License](LICENSE).

## References

- [MoonBit docs](https://docs.moonbitlang.cn/)
- Ideas this library learned from: [Yue / libyue](https://github.com/yue/yue) · [Yoga](https://github.com/facebook/yoga)
