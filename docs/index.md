---
layout: home
hero:
  name: moonbit-libyue
  text: Native desktop GUI for MoonBit
  tagline: One MoonBit codebase, native windows on Windows / Linux — widgets, layout and the event loop all self-drawn. Zero config after moon add.
  actions:
    - theme: brand
      text: Package structure
      link: /README
    - theme: alt
      text: GitHub
      link: https://github.com/lb091188/moonbit-native-gui
features:
  - title: Self-drawn, one theme everywhere
    details: Windows, pixels, the event loop, layout and widgets are all pure MoonBit, so widgets look the same on every platform and follow the system accent colour and light / dark mode.
  - title: Import only what you use
    details: Core, UI, render, text, theme, icons, sys, input, win, dbus, chart, mdview and web are separate packages; unused ones never enter your binary.
  - title: Platform differences absorbed
    details: Tray, autostart, power, volume, media keys and more share one API; the library takes care of the Linux / Windows differences.
---

## Quick start

```sh
moon add NoahLiu/native-gui
```

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

`@ui.*` comes from `NoahLiu/native-gui/ui` — the full package table is in the [doc index](/README).
