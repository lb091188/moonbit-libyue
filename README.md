# moonbit-libyue [![CI](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml)

> Thanks to [Cheng Zhao (zcbenz)](https://github.com/zcbenz) and his [Yue](https://github.com/yue/yue) framework, and to [MoonBit](https://github.com/moonbitlang). As it happens, both of these programming tools carry the character for "moon" — and I have grown fond of them both. [About me and `libyue`](docs/aboutlibyue.md)

A **native cross-platform desktop GUI library** for the [MoonBit](https://github.com/moonbitlang) ecosystem — a full binding of [libyue](https://libyue.com/docs/latest/cpp/) (C++): one MoonBit codebase runs native windows on Windows / macOS / Linux, zero-config right after `moon add`.

English | [简体中文](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/README_ZH.md)

![Component showcase](docs/images/showcase-basic.png)

<p align="center">
  <img src="docs/images/showcase-data.png" width="32%" alt="Data display">
  <img src="docs/images/showcase-form.png" width="32%" alt="Form components">
  <img src="docs/images/showcase-system.png" width="32%" alt="System integration">
</p>

## Core highlights

**🎨 Modern theme** — everything self-drawn, visually consistent across the three platforms; `theme_apply` reskins in one line, light/dark follows the system automatically:

```moonbit
@yue.theme_apply({ ..@yue.default_theme(), primary: "#1E4FA3" })
```

**📝 Declarative** — describe the UI as a node tree, no hand-written `new + set_xxx`:

```moonbit
let window = @yue.mount_window(
  [
    @yue.label("Hello, MoonBit + libyue!", style=[("margin", 20.0)]),
    @yue.button("Quit", on_click=fn() { @yue.quit() }),
  ],
  title="Hello", size=Some((420.0, 160.0)), center=true, on_close=fn(_w) { @yue.quit() },
)
```

**⚡ Signal reactivity** — keep state in `Signal` / `Store`; bound spots refresh automatically, with no "update the text on click" glue:

```moonbit
let clicks = @yue.Signal::new(0)
let text = @yue.Signal::computed(fn() { "Clicked \{clicks.get()} times" })  // dependencies auto-collected

@yue.button("Click me", on_click=fn() { clicks.update(fn(n) { n + 1 }) }),
@yue.bind(text, fn(s) { s }),
```

**🖥 Desktop-grade system integration** — system tray (Linux via a self-built DBus/SNI link, closing a libyue gap) · notifications & notification center · global shortcuts · clipboard · native menu bar · file dialogs · drag & drop · multiple monitors:

```moonbit
let tray = @yue.Tray::new("icon.png") // Result, errors are handleable
match tray {
  Ok(t) => t.on_click(fn() { window.show() })
  Err(e) => println("Tray unavailable: \{e}")
}
let n = @yue.Notification::new()
n.set_title("Build finished"); n.set_body("45/45 passed"); n.show()
```

> 55 native widgets fully bound · 57 themed self-drawn components · wrapper overhead [measured: startup on par with C++, memory under 1 MB](docs/adaptation.md) · three-platform CI · published on [mooncakes](https://mooncakes.io/)

## Quick start

Don't know MoonBit? Any programming language background is enough — the [five-minute tutorial](docs/tutorial.md) takes you from `moon new` to a running window: installing the MoonBit toolchain and per-platform system dependencies, avoiding the three newcomer pitfalls, and building your first desktop app, with links to the official MoonBit tutorial and interactive Tour.

Already know MoonBit? Section 2 of the tutorial covers adding this library from `moon new` to `moon add` — up and running in minutes.

## Documentation index

| Document | Content |
|---|---|
| [tutorial.md](docs/tutorial.md) | Five-minute quick start: from `moon new` to a running window, avoiding the three newcomer pitfalls |
| [declarative.md](docs/declarative.md) | Declarative `Node`/`mount` render tree + `Store` reactive bindings |
| [layout.md](docs/layout.md) | Layout style key quick reference: all style keys + common-combination examples |
| [components-ui.md](docs/components-ui.md) | Themed component library quick reference: per-API signatures + parameter tables, including theme customization / light-dark switching |
| [components.md](docs/components.md) | Widget API quick reference: both the classic setter and `X::make` props styles |
| [Troubleshooting & topics](docs/README.md) | Platform adaptation notes · Linux tray · native-layer relink (three standalone documents) |

## Platform support

Ubuntu 24.04 (XFCE / GNOME / KDE) ✅ · Deepin 25 ✅ · Windows 10/11 ✅ · macOS builds pass (CI, no real machine)

On Windows, exes built against this library automatically run as a GUI subsystem — no console window on double-click; `moon run` output is captured via pipes and stays visible.

## Contributing

Everyone is welcome: reporting platform-compatibility issues, adding widgets, improving docs — macOS real-machine testing is especially appreciated (currently only CI builds pass, no real-machine verification). A few basic requirements:

- **Commit gate**: `moon check && moon test` zero errors and zero warnings repo-wide
- **Experience on record**: write field-tested pitfalls together with their fixes into [adaptation.md](docs/adaptation.md) — not only in commit messages
- **Small batches**: one cohesive change per commit, short commit messages

The full process for adding widgets, native-layer releases, and more is in [AGENTS.md](AGENTS.md).

## References

- [libyue docs](https://libyue.com/docs/latest/cpp/guides/getting_started.html)

- [MoonBit docs](https://docs.moonbitlang.cn/)
