# moonbit-libyue [![CI](https://github.com/lb091188/moonbit-native-gui/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-native-gui/actions/workflows/ci.yml)

> **⚠ Renamed** — the mooncakes package is now **`NoahLiu/native-gui`** (formerly `NoahLiu/moonbit-libyue`; the old name will be marked deprecated once the stack stabilizes); sub-modules `NoahLiu/yue-media` → **`NoahLiu/gui-media`**, `NoahLiu/yue-examples` → **`NoahLiu/gui-examples`**. 

> **On origins** — this library started life as a MoonBit binding of [Cheng Zhao (zcbenz)](https://github.com/zcbenz)'s [Yue / libyue](https://github.com/yue/yue), with [Yoga](https://github.com/facebook/yoga)'s flexbox for layout. The stack is self-drawn now and depends on neither — what stays with us is what we learned from them. Thanks also to [MoonBit](https://github.com/moonbitlang).

A **native cross-platform desktop GUI library** for the [MoonBit](https://github.com/moonbitlang) ecosystem — windows, pixels, the event loop, layout and widgets are all written in pure MoonBit. One codebase runs native windows on Windows ✅ / Linux ✅, with the macOS backend landing on the `mac` branch; zero config after `moon add`.

English | [简体中文](https://github.com/lb091188/moonbit-native-gui/blob/master/README_ZH.md)

![Component showcase](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/images/showcase-main.png)

![Live demo on Linux (XFCE)](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/images/showcase-anim-linux.webp) ![Live demo on Windows](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/images/showcase-anim-windows.webp)

*Left: Linux (XFCE) · Right: Windows — one MoonBit codebase*

## Core highlights

**🎨 Self-drawn widgets, one theme everywhere** — widgets are drawn by the library's own rasterizer, so they look the same on every platform. Light/dark and the system accent colour are followed by default, and the theme is a plain value you can override.

**📝 Declarative UI** — describe the interface as a tree and let the library drive it:

```moonbit
fn main {
  let app = match @ui.mount_window(
    [@ui.label("Hello, MoonBit!", size=18.0)],
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

**⚡ Reactive state** — keep state in `Store` / `Signal` (from `@core`); bound spots refresh themselves when the data changes.

**🖥 Desktop-grade system integration** — tray, notifications, global shortcuts, clipboard, native menus, file dialogs, drag & drop, autostart, media keys, and OS queries (volume, power, browser history, installed apps…) sit behind one `@sys` API.

**📊 Self-drawn charts & rich content** — charts (line / bar / pie / gauge / scatter plus radar, heatmap, candlestick, funnel, boxplot, sankey, tree, treemap, sunburst, map and more, with a cross-cutting interactive layer) and a Markdown view, drawn by the same rasterizer.

> `moon run examples/showcase` — the full demo board: component library + system capabilities.

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

Heavier optional capabilities live in **separate modules**, so a plain `moon add` never drags them in:

| Module | Contents |
|---|---|
| `NoahLiu/gui-media` | Audio/video engine (ffmpeg decode + miniaudio output) and the player component. |
| `NoahLiu/gui-examples` | Standalone example module (systemprobe, native-web) that depends on `gui-media`. |

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
moon run examples/showcase       # full demo board: components + system capabilities
```

## Platform support

Ubuntu 24.04 (XFCE / GNOME / KDE) ✅ · Deepin 23 / 25 ✅ · Windows 10/11 ✅ · macOS 🚧 landing on the `mac` branch (Cocoa / CoreText / ImageIO / WKWebView)

On Windows, exes are built as a GUI-subsystem binary — no console window on double-click.

## Documentation index

📚 **Online docs**: <https://moonbit-libyue.pages.dev/> — 中文版在 [`/zh/`](https://moonbit-libyue.pages.dev/zh/).

| Document | Content |
|---|---|
| [docs/README.md](docs/README.md) | Documentation index and package overview |
| [docs/adaptation.md](docs/adaptation.md) | Platform adaptation notes: field-tested pitfalls and fixes, per platform |
| [docs/autostart.md](docs/autostart.md) | Cross-platform autostart |
| [docs/tray.md](docs/tray.md) | Linux tray: SNI protocol-stack design |
| [docs/zh/system-capabilities.md](docs/zh/system-capabilities.md) | System capabilities overview (Chinese) |

## Contributing

Everyone is welcome: reporting platform-compatibility issues, adding widgets, improving docs — the macOS backend is the largest open gap (landing on the `mac` branch; it needs an Apple Silicon machine). A few basic requirements:

- **Commit gate**: `moon check && moon test` zero errors and zero warnings repo-wide
- **Experience on record**: write field-tested pitfalls together with their fixes into [adaptation.md](docs/adaptation.md) — not only in commit messages
- **Small batches**: one cohesive change per commit, short commit messages

The full process for adding widgets, CI and releases is in [AGENTS.md](AGENTS.md).

## License

`moonbit-libyue` is released under the [MIT License](LICENSE).

## References

- [MoonBit docs](https://docs.moonbitlang.cn/)
- Ideas this library learned from: [Yue / libyue](https://github.com/yue/yue) · [Yoga](https://github.com/facebook/yoga)
