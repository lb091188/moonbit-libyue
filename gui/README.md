# native-gui

A **native, cross-platform desktop GUI library for the MoonBit ecosystem** — the position GTK, WinForms or AppKit hold in their own ecosystems, built for MoonBit. Windows, pixels, the event loop, layout and every widget are owned by the library itself and written in pure MoonBit (self-drawn, no libyue dependency); platform specifics converge in a handful of thin C layers for windows, text, image decoding, WebView and media. One codebase runs native windows on Windows and Linux; `moon add` and go, zero configuration.

> Formerly `moonbit-libyue` (renamed 2026-10). The mooncakes package is **`NoahLiu/native-gui`** and all existing import paths are unchanged.

![Demo board](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/public/images/showcase-main.png)

## Highlights

- **Self-drawn widgets, one look everywhere** — controls are drawn by the library's own rasterizer, so they render identically on every platform; light/dark mode and the system accent colour are followed by default, and a theme is a plain value you can override wholesale.
- **Declarative UI with reactive state** — describe the interface as a tree of `@core.Node` values and mount it with one `mount_window` call; keep state in `Store` / `Signal` and bound spots refresh themselves.
- **Desktop-grade system integration** — tray, notifications, native menus, global shortcuts, message boxes, file dialogs, drag & drop (in-app and cross-application), clipboard, autostart, idle detection and OS queries (volume, power, monitors, browser history, installed apps…) behind one `@sys` / `@core` facade.
- **Content batteries included** — 20 chart types with a cross-cutting interactive layer, a GFM Markdown view, multi-language code highlighting, an embedded WebView (JS interop, custom protocols, DOM capture, policy hooks) and an audio/video engine with subtitles and speed control.
- **Honest degradation** — every capability family exposes a probe and returns a structured `Unsupported` / `NotFound` on environments that lack it, instead of crashing or pretending success.
- **Pay only for what you import** — 14 packages in this module; an unimported package never enters your binary. Heavier optional capabilities (the media engine) live in their own modules, outside the default dependency closure entirely.

## Usage

```sh
moon add NoahLiu/native-gui
```

Import the packages you need in `moon.pkg` (e.g. `NoahLiu/native-gui/ui` as `@ui`) and mount a window:

```moonbit
fn main {
  let app = match @ui.mount_window(
    [@ui.text("Hello, MoonBit!", font_size=18.0)],
    title="Hello, MoonBit!",
    width=400,
    height=300,
  ) {
    None => return // no window backend or no display service on this host
    Some(a) => a
  }
  app.run()
}
```

Runnable examples in this repository, from shallow to deep:

```sh
moon run examples/hello          # a minimal window
moon run examples/hello-themed   # the themed widget set
moon run examples/showcase       # full demo board: components + system probes + extended charts, 15 pages
moon run examples/browser        # embedded WebView browser (demo menu + status bar)
```

Each showcase page is its own source file under `examples/showcase/pages/` — the best copy-paste material library.

## Packages

| Import | Alias | Contents |
|---|---|---|
| `NoahLiu/native-gui/core` | `@core` | App host, event loop, focus / keys / pointer, menus, notifications, tray, overlays, drag & drop, `Store` / `Signal` |
| `.../native-gui/ui` | `@ui` | Self-drawn widgets and the component library: forms, display, navigation, date, tables & virtual lists, entries, scroll, overlays, code view, declarative layer |
| `.../native-gui/render` | `@render` | Rasterizer — a pure-MoonBit software raster (path / fill / blend / gradient) plus a Cairo backend; bitmaps, canvas, images, PNG |
| `.../native-gui/text` | `@text` | Text layer: font families, fonts, attributed text and range attributes (Pango / DirectWrite) |
| `.../native-gui/theme` | `@theme` | Theme system: palette derivation + change subscription |
| `.../native-gui/icons` | `@icons` | Vector icon system (800+ icons) |
| `.../native-gui/sys` | `@sys` | OS capabilities facade |
| `.../native-gui/input` | `@input` | Editing core and key codes |
| `.../native-gui/win` | `@win` | Platform window backend (Win32 / GTK3 C stubs) |
| `.../native-gui/dbus` | `@dbus` | Linux D-Bus bridge (tray SNI, notifications, logind / upower, media, network…) |
| `.../native-gui/chart` | `@chart` | Charts plus the interactive layer |
| `.../native-gui/mdview` | `@mdview` | Markdown rendering view |
| `.../native-gui/web` | `@web` | Embedded WebView |
| `.../native-gui/style` | `@style` | Style layer: stylesheets as MoonBit values — `Style` rule blocks, hover / active / focus states, transitions |

Optional capabilities in **separate modules** (a plain `moon add` of this module never drags them in):

| Module | Contents |
|---|---|
| `NoahLiu/gui-media` | Audio/video engine (ffmpeg decode + miniaudio output) and the player component |
| `NoahLiu/gui-examples` | Standalone example module (audio / video players) depending on `gui-media` |

## Platform support

| | Windows | Linux | macOS |
|---|---|---|---|
| Status | ✅ 10 / 11 | ✅ X11 mainline | 🚧 landing |
| Notes | GUI-subsystem exe — double-click with no console window | committed span **deepin 20 ~ Ubuntu 26**, staying on GTK3; Wayland sessions run with X11-dependent capabilities degrading per session | the backend (window / text / image decode / WebView / system capabilities) is developed on the `mac` branch, not yet merged into master; on master macOS calls degrade to `Unsupported` |

## Roadmap

Where this library is heading, in order of current effort (see the public roadmap for the full picture):

1. **Lower the barrier to entry** — a shortest path from "install moon" to "a window on screen" on the docs homepage, per-platform prerequisites in one sentence, build errors that carry their own fix hints.
2. **Credibility** — CI gates on Linux and Windows for every batch, on-device verification checklists, and a version promise: the stable-surface list (what will not break within 1.x) and the 1.0 cut-off are being defined.
3. **Content** — usage documentation rewritten for the self-drawn stack (tutorials, a per-component guide with screenshots), continuously expanded examples.
4. **Platform coverage** — merging the macOS backend once on-device verification closes; verifying the Linux compatibility span floor by floor (deepin 20 as the floor, Ubuntu 26 as the ceiling).

Explicit non-goals: accessibility APIs, GTK4 / Qt backends, and platform-native widget skins — the self-drawn stack is the product.

**Versioning**: at `0.x` the interfaces still evolve per batch; breaking changes are recorded in commit messages and the docs ship in the same batch.

## Documentation

- Repository root [README](https://github.com/lb091188/moonbit-native-gui) — architecture, package map, contributing and gates
- [Documentation site](https://moonbit-libyue.pages.dev/) — usage docs, Chinese version under [`/zh/`](https://moonbit-libyue.pages.dev/zh/)
- [Platform adaptation notes](https://github.com/lb091188/moonbit-native-gui/blob/master/docs/zh/adaptation.md) — field-tested pitfalls, root causes and fixes per platform
- [Public roadmap](https://github.com/lb091188/moonbit-native-gui/blob/master/docs/zh/roadmap.md) — positioning, support matrix, commitments, non-goals

MIT License.
