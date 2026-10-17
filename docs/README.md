# Documentation Index

**native-gui** is a lightweight cross-platform desktop GUI framework for MoonBit. Windows, pixels, the event loop, layout and widgets are all implemented in pure MoonBit; the mooncakes package is `NoahLiu/native-gui`.

## Package structure

`moon add NoahLiu/native-gui` pulls in the whole module, but MoonBit compiles and links only the packages you import — anything you don't import stays out of your binary:

| Import in `moon.pkg` | Alias | Contents |
|---|---|---|
| `NoahLiu/native-gui/base` | `@base` | Platform-free primitives: `Store` / `Signal` / `ListStore`, the focus stack, key codes, end-of-frame batching and the frame ledger |
| `NoahLiu/native-gui/shell` | `@shell` | System-capability shell: menus, global hotkeys, tray, notifications, reveal, the loop scheduler and read-only platform probes |
| `NoahLiu/native-gui/widget` | `@widget` | Self-drawn widget host: layout mapping, hit-testing, event routing, paint walk, declarative `Node`, overlays, drag & drop, input mapping, the `App` pump |
| `.../native-gui/ui` | `@ui` | Self-drawn widgets and the component library: window mounting, labels / buttons, forms, display, navigation, date, tables and virtual lists, text entries, scrolling, overlays, code view, declarative layer |
| `.../native-gui/render` | `@render` | Rasterizer: a pure-MoonBit software raster plus a Cairo backend; bitmaps, canvas, images, PNG |
| `.../native-gui/text` | `@text` | Text layer: font families, fonts, rich text and range attributes (Pango / DirectWrite) |
| `.../native-gui/theme` | `@theme` | Theme system: palette derivation and change subscription |
| `.../native-gui/icons` | `@icons` | Vector icon system |
| `.../native-gui/sys` | `@sys` | OS capabilities: autostart, idle, subprocesses, environment, files, JSON, dialogs, browser history / bookmarks, recent files, wallpaper, volume, power, printers, monitors, window control, app lookup |
| `.../native-gui/input` | `@input` | Editing core and key codes |
| `.../native-gui/win` | `@win` | Platform window backends (Win32 / GTK3 C stubs): hotkeys, icons, IME, message boxes, notifications, tray, surfaces |
| `.../native-gui/dbus` | `@dbus` | Linux D-Bus bridge: tray SNI, notifications, logind / upower, media, network, screensaver |
| `.../native-gui/chart` | `@chart` | Charts and the cross-cutting interactive layer |
| `.../native-gui/mdview` | `@mdview` | Markdown rendering view |
| `.../native-gui/style` | `@style` | Style layer: stylesheets written as MoonBit values, with state classes and transitions |

Heavier optional capabilities live in separate modules, and `moon add NoahLiu/native-gui` never pulls them in:

| Module | Contents |
|---|---|
| `NoahLiu/gui-media` | Audio/video engine and the player component.
| `NoahLiu/gui-webview` | Embedded WebView (WebKitGTK / WebView2), extracted from the main module's `web` subpackage on 2026-10-16. |
| `NoahLiu/gui-examples` | Standalone example module that depends on `gui-media`. |

Don't confuse the two kinds of "optional": a sub-package you don't import stays out of your binary — the `moon.pkg` import is the compile/link boundary; a module you don't depend on is not even resolved or prebuilt — the `moon.mod` import decides the dependency closure. For a capability to reach the latter, it must live in its own module.

## Demos

Examples, from shallow to deep:

```sh
moon run examples/hello          # minimal window
moon run examples/hello-themed   # themed widget set
moon run examples/showcase       # full demo board
moon run examples/browser        # embedded WebView browser
```

`examples/showcase` covers every component family, charts, code & docs views, system integration and transitions, plus a read-only system capability probe page. Each page's source is its own file (`examples/showcase/pages/*.mbt`), ready to copy and adapt. Screenshots of the components:

![Basic components](/images/showcase-basic.png)

![Form components](/images/showcase-form.png)

![Data display](/images/showcase-data.png)

![Code & docs](/images/showcase-code.png)

![System integration](/images/showcase-system.png)

## Routing

| Document | Content |
|---|---|
| [tutorial.md](tutorial.md) | Five-minute start: install the toolchain, create a project, and build your first window with a click counter |
| [components.md](components.md) | Component quick-reference (`@ui`): constructor signatures and purposes for every widget, grouped by family |
| [declarative.md](declarative.md) | Declarative layer and reactivity: the node tree and `mount_window`, `Store` / `Signal`, `for_list` / `when`, in-place replacement |
| [layout.md](layout.md) | Layout: the Flexbox semantics of yoga-mbt, the `Style` field set of `@style`, and the `class` channel |
| [build.md](build.md) | Build and linking: how prebuild hosts link flags, and how to spot and fix a C stub edited without relinking |
| [zh/roadmap.md](zh/roadmap.md) | Public roadmap: positioning, what you can use today, platform and feature matrix, commitments and versioning, next steps, open decisions, explicit non-goals (Chinese only) |
| [zh/design.md](zh/design.md) | Frontend-style design decisions: stylesheet shape, component naming mapping, reactivity enhancements, and a view layer that uses `render` functions instead of templates (Chinese only) |
| [zh/module-structure.md](zh/module-structure.md) | Module-structure plan (draft): releasing `gui/web` as `gui-webview` and splitting `core` into `base` / `shell` / `widget` — batches, costs and risks, tracked in `TODO.md` §1 "G9 模块拆分" (module split; Chinese only) |
| [adaptation.md](adaptation.md) | Platform adaptation notes: field-tested pitfalls, root causes and verification results per platform |
| [autostart.md](autostart.md) | Autostart: XDG `.desktop` on Linux, HKCU Run key on Windows, one `is_enabled` / `enable` / `disable` API |
| [tray.md](tray.md) | Linux tray: SNI protocol-stack design, architecture, backend fallback and desktop compatibility |
| [system-capabilities.md](system-capabilities.md) | System capabilities overview (`@sys`): volume, app lookup, color temperature, wallpaper, monitors, window management, clipboard watch, system info, printers, recent files, browser history and more, with unified `Result` semantics; plus the shared subprocess and D-Bus call layers |

For the project overview and quick start, see [README.md](https://github.com/lb091188/moonbit-native-gui/#readme) at the repository root.

[中文文档索引](/zh/README.md)
