---
layout: home
hero:
  name: native-gui
  text: A lightweight cross-platform desktop GUI framework for MoonBit
  tagline: Native window hosts, a self-drawn rendering pipeline, a complete widget set, and full system integration. One MoonBit codebase, native windows on Windows / Linux. Zero config after moon add.
  actions:
    - theme: brand
      text: Package structure
      link: /README
    - theme: alt
      text: GitHub
      link: https://github.com/lb091188/moonbit-native-gui
features:
  - title: Self-drawn widgets, one theme across all platforms
    details: Windows, pixels, the event loop, layout and widgets are all pure MoonBit. Every platform looks the same, following the system accent color and light / dark mode.
  - title: Import on demand
    details: core / ui / render / text / theme / icons / sys / input / win / dbus / chart / mdview / web / style are each its own package; unused packages never enter your binary.
  - title: Platform differences absorbed inside the library
    details: Tray, autostart, power, volume, and media keys share one API; the library absorbs the Linux / Windows differences.
---

## Quick start

```sh
moon add NoahLiu/native-gui
```

```moonbit
fn main {
  let app = match @ui.mount_window(
    [@ui.text("Hello, MoonBit!", font_size=18.0)],
    title="Hello, MoonBit!",
    width=400,
    height=300,
  ) {
    None => {
      // no window backend or no display service on this platform
      return
    }
    Some(a) => a
  }
  app.run()
}
```

`@ui.*` comes from `NoahLiu/native-gui/ui` — the full package table is in the [documentation index](/README).
