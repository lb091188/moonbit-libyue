# Five-Minute Tutorial (for MoonBit newcomers)

No MoonBit experience required — programming basics in any language will do. This tutorial builds a desktop app from scratch: a window, a button, and a counter that refreshes itself on click. Every step was verified on Ubuntu 24.04 with moon 0.1.20260911.

## 1. Install the toolchain (once)

**MoonBit toolchain** (moon is its official build tool):

```sh
# Linux / macOS
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
# Windows (PowerShell)
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
```

**Linux also needs the GTK system libraries** (Ubuntu 24.04, one line):

```sh
sudo apt install build-essential cmake pkg-config \
  libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev libwebkit2gtk-4.1-dev
```

For the Windows MSVC setup see the collapsed section under "Quick start" in the repository README.

## 2. Create the project (three newcomer pitfalls, avoided)

```sh
moon new my_app
cd my_app
moon add NoahLiu/moonbit-libyue
```

The generated project needs three manual adjustments — all verified the hard way:

**① In `moon.mod`: change `preferred_target = "wasm"` to `"native"`**
This library goes through native FFI and only supports the native backend; otherwise the build fails with `ffi_* is unbound`.

**② Rename the entry file: `my_app.mbt` → `main.mbt`**
The current moon only recognizes `main.mbt` as the program entry; the template's default file name fails with `Missing main function`.

**③ Replace `moon.pkg` entirely with** (note: this is moon's DSL format, not JSON):

```
import {
  "NoahLiu/moonbit-libyue/yue",
}

options(
  "is-main": true,
)
```

`import` makes the component library reachable as `@yue.*`; `is-main` marks this package as the executable entry.

## 3. The first window

Replace `main.mbt` entirely with:

```moonbit
fn main {
  if !@yue.initialize() {
    return
  }
  let clicks = @yue.Signal::new(0)
  let _ = @yue.mount_window(
    [
      @yue.label("Hello, MoonBit + libyue!", style=[("margin", 20.0)]),
      @yue.button("Click me", on_click=fn() { clicks.update(fn(n) { n + 1 }) }),
      @yue.bind(clicks, fn(n) { "Clicked \{n} times" }),
      @yue.button("Quit", on_click=fn() { @yue.quit() }),
    ],
    title="Tutorial",
    size=Some((360.0, 220.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
  )
  @yue.run()
}
```

```sh
moon run .
```

A window appears: a label, a button; click the button and the "Clicked N times" line updates by itself — that is **reactive signals**: state changes propagate to bound views automatically, no "on click, set that label" glue. `mount_window` takes an array of nodes and **declaratively** describes the UI.

## 4. MoonBit syntax in five rows (only what the code above uses)

| Syntax | Meaning |
|---|---|
| `fn main { ... }` | Program entry |
| `if !cond { return }` | Early return; `!` is logical not |
| `let clicks = ...` | Immutable binding (mutable would be `let mut`, unused here) |
| `fn(n) { n + 1 }` | Anonymous function (lambda), passed as a callback |
| `on_click=fn() { ... }` | Named argument: parameters with defaults are passed by name |
| `"Clicked \{n} times"` | String interpolation; `\{expression}` embeds any value |
| `Some((360.0, 220.0))` | The "present" form of an optional value; `None` means absent |

Learn the rest (pattern matching, structs, traits) from the official **[MoonBit tutorial](https://docs.moonbitlang.com/en/latest/tutorial/index.html)** (Chinese version [here](https://docs.moonbitlang.com/zh-cn/latest/tutorial/index.html)), or play through the interactive **[Tour of MoonBit](https://tour.moonbitlang.com)** in your browser.

## 5. Next steps

- **Theming in one line**: `@yue.theme_apply({ ..@yue.default_theme(), primary: "#1E4FA3" })`; light/dark system following in [components-ui.md](components-ui.md)
- **The full widget gallery**: clone this repository and `moon run examples/showcase` — a 15-page demo board; each page's source is a standalone file (`examples/showcase/pages_*.mbt`), the best copy-paste material
- **Go deeper**: declarative nodes & reactive bindings in [declarative.md](declarative.md), layout style keys in [layout.md](layout.md), widget API reference in [components.md](components.md)

## FAQ

| Symptom | Cause & fix |
|---|---|
| `ffi_* is unbound` | `preferred_target` in `moon.mod` not changed to `"native"` |
| `Missing main function` | Entry file not named `main.mbt`, or `options("is-main": true)` missing in `moon.pkg` |
| `Package "yue" not found` | `import` section of `moon.pkg` missing `"NoahLiu/moonbit-libyue/yue"` |
| Missing GTK libraries on Linux | apt list in step 1 not fully installed |
| `moon run my_app` says path not found | The root package is run with `moon run .` |
| Code changes not taking effect | After native-layer (shim/vendor) changes force a relink, see [relink.md](relink.md) |
