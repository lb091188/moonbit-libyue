---
layout: home
hero:
  name: moonbit-libyue
  text: libyue bindings for MoonBit
  tagline: One MoonBit codebase, native desktop windows on Windows / Linux / macOS — zero config after moon add.
  actions:
    - theme: brand
      text: Five-minute tutorial
      link: /tutorial
    - theme: alt
      text: Package structure
      link: /README
features:
  - title: Native, windows in a flash
    details: A full binding of libyue (C++) — real native windows and widgets, ~7 MB binaries, ~80 ms startup.
  - title: Import only what you use
    details: Core, declarative, themed components, charts, icons, markdown and OS capabilities are separate packages; unused ones never enter your binary.
  - title: Platform differences absorbed
    details: Tray, autostart, power, volume, media keys and more share one API; the library takes care of Linux / Windows / macOS differences.
---

## Quick start

```sh
moon add NoahLiu/moonbit-libyue
```

```moonbit
fn main {
  if !@yue.initialize() {
    return
  }
  let _ = @declarative.mount_window(
    [
      @declarative.label("Hello, MoonBit + libyue!"),
      @declarative.button("Quit", on_click=fn() { @yue.quit() }),
    ],
    title="Hello",
    center=true,
  )
  @yue.run()
}
```

Remember to import `NoahLiu/moonbit-libyue/yue/declarative` for `@declarative.*` — the full package table is in the [doc index](/README).
