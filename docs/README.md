# Documentation Index

## Introduction

This directory holds the usage documentation for moonbit-libyue. All types are referenced via `@yue`; the widget API quick reference (parameters / method tables) is in [components.md](components.md).

The component API has two usage styles, semantically identical: the **classic per-setter approach** (`X::new()` + `set_xxx()`) or the **props-style one-shot approach** (`X::make(...)`, just a bundle of setters).

Never touched MoonBit? Start from the [five-minute tutorial](tutorial.md) — learning MoonBit, installing dependencies, and building your first desktop app.

## Packages

Since 0.5.11 the module is split into sub-packages — `moon add NoahLiu/moonbit-libyue` gets you all of them, but you only compile and link what you import (MoonBit builds the import closure; an unused package costs nothing in your binary):

| Import in `moon.pkg` | Alias | Contents |
|---|---|---|
| `NoahLiu/moonbit-libyue/yue` | `@yue` | Core: FFI, native widgets (Window / View / Label / Button / Entry / Table / Tab / Menu / dialog…), Painter, events, `Store`/`Signal`, theme, tray, file/env helpers |
| `.../yue/declarative` | `@declarative` | Declarative layer: `Node`/`mount` render tree, node constructors, `bind_label`/`bind`, hover group, overlay scroll |
| `.../yue/components` | `@components` | Themed component library: buttons / inputs / selection / forms / navigation / layout / data display / feedback / overlays |
| `.../yue/charts` | `@charts` | 20+ chart types plus the cross-cutting interactive layer |
| `.../yue/icons` | `@icons` | Vector icon system (`draw_icon` and the icon views/buttons) |
| `.../yue/markdown` | `@markdown` | `markdown_view` rendering (this package pulls in the mizchi/markdown dependency) |
| `.../yue/system` | `@system` | OS capabilities: autostart, single instance, power & sessions, volume, brightness, media keys, wallpaper, Bluetooth, printers, disk volumes, browser history… (pulls in subproc / sqlite) |
| `.../yue/browser` | `@browser` | Webview widget — import only if you need it (it is the only package that links WebKit/WebView2) |

The tutorial imports core + declarative; the themed component library and everything above it is opt-in.

## Demo

Five examples, from shallow to deep:

```sh
moon run examples/hello         # minimal window with the original widgets
moon run examples/hello-themed  # minimal example of the themed component library (theme_apply + button_t/input_t/label_t)
moon run examples/showcase      # full-capability demo board: 14 pages, three grouped sidebars, component library + system capabilities
moon run examples/sysmonitor    # flagship app: Ubuntu process manager & hardware monitor (1000-row process table + live curves)
moon run NoahLiu/yue-examples/systemprobe   # system capabilities + extended charts demo (volume/brightness/browser & VS Code history/app lookup + radar/heatmap/candlestick/funnel/boxplot/sankey)
```

The showcase covers 14 pages: Basic / Icons / Form / Navigation / Data Display / Charts / Feedback / Code & Docs / Events & Layout / Store comparison / Canvas & rich text / System integration / Window / Browser.

A collapsible grouped side menu sits on the left and the package version at the bottom (kept in sync with `moon.mod`). Each page's source is its own file (`examples/showcase/pages/*.mbt`) — ready to copy from. Screenshots of the component library:

![Basic components](/images/showcase-basic.png)

![Form components](/images/showcase-form.png)

![Data display](/images/showcase-data.png)

![Code & docs](/images/showcase-code.png)

![System integration](/images/showcase-system.png)

### sysmonitor: process manager & hardware monitor

The library's flagship app for expressiveness + performance, in two layers:

- **Data layer** — pure MoonBit reads of /proc and /sys: two-sample CPU diff, memory, a 1000-row process table, hwmon temperatures, disk IO and capacity, PCI GPUs, NIC rates; the only syscalls go through the app's own native stub.
- **View layer** — five tabbed pages (Overview / Processes / Sensors / Disks / Network) driven by one 1Hz timer; curves and value cards repaint the canvas only, never rebuilding the view tree; light/dark follows the system.

Process page: a 1000-row virtual table with search filtering, six sortable columns, selection-driven kill (SIGTERM, falling back to SIGKILL) / renice, and errno mapped to Chinese notices. Measured: 1053 processes sampled in 14.94ms/pass, 1Hz steady-state CPU 2-3% (figures in [adaptation.md](adaptation.md)).

![Overview](/images/sysmonitor-overview.png)

![Processes](/images/sysmonitor-process.png)

![Dark theme](/images/sysmonitor-dark.png)

## Routing

| Document | Content |
|---|---|
| [tutorial.md](tutorial.md) | Five-minute tutorial (for MoonBit newcomers): from `moon new` to a running window, avoiding the three newcomer pitfalls one by one; includes links to the official MoonBit tutorial & Tour |
| [aboutlibyue.md](aboutlibyue.md) | About me and `libyue`: how the author met this library and how the binding came to be |
| [declarative.md](declarative.md) | Declarative UI (package `@declarative`): `Node`/`mount` render tree + `Store`/`Signal` reactive bindings (signals: computed with automatic dependency tracking + batch) |
| [layout.md](layout.md) | Layout style key quick reference: all Yoga flexbox style keys (enum / numeric / edge / special) + common-combination examples |
| [components-ui.md](components-ui.md) | Themed component library quick reference (package `@components`): per-API signatures + parameter tables + examples across 12 groups — buttons & text, input, selection, forms, navigation, layout, data display, charts, chart interaction, icons, feedback, overlays; theme customization and light/dark included |
| [components.md](components.md) | Widget API quick reference: both classic setter and `X::make` props styles, including upstream pitfalls |
| [adaptation.md](adaptation.md) | Platform adaptation notes: field-tested pitfalls per platform, root causes, and verification conclusions (continuously updated) |
| [tray.md](tray.md) | Linux tray solution: SNI protocol stack design, architecture, backend fallback, desktop compatibility |
| [autostart.md](autostart.md) | Cross-platform autostart: XDG .desktop on Linux / HKCU Run key on Windows, unified is_enabled / enable / disable |
| [zh/system-capabilities.md](/zh/system-capabilities.md) (Chinese) | System capabilities (package `@system`, Chinese only): 26 capabilities + 2 shared layers (procrun / traybus) in five groups; each has an API table and an example, with unified `Result` semantics |
| [zh/plan-system-integration.md](/zh/plan-system-integration.md) (Chinese) | System-integration expansion master plan: the batch breakdown of P1-P12 plus the closing item P14, acceptance gates, shared-infrastructure decisions and risks (finalized) |
| [relink.md](relink.md) | Forcing a relink after native layer (shim/vendor) changes: detection and handling |

For the project overview and quick-start entry points, see the repository root [README.md](https://github.com/lb091188/moonbit-libyue/#readme).

[中文版文档索引](/zh/README.md)
