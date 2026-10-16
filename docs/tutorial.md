# Five-minute tutorial

No MoonBit knowledge needed — programming experience in any language is enough. This tutorial builds a desktop app from scratch: one window, one button, and a counter that refreshes on every click.

## 1. Prepare the tools

**MoonBit toolchain**:

```sh
# Linux / macOS
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
# Windows (PowerShell)
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
```

<details>
<summary>Linux (Ubuntu 24.04) environment setup</summary>

The library is self-drawn and uses native FFI. Building needs only a C toolchain, pkg-config, Python 3, and the dev packages for GTK3 / Pango / FontConfig / X11; Python 3 runs the library's prebuild script:

```sh
sudo apt install build-essential pkg-config python3 \
  libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev
```

Install more only when you use the matching feature: embedded WebView (`@web`) needs `libwebkit2gtk-4.1-dev`; the media module (`NoahLiu/gui-media`) needs `libavformat-dev libavcodec-dev libswscale-dev libswresample-dev libavutil-dev`. If the runtime reports missing GTK libraries, the apt list above is most likely incomplete.

</details>

<details>
<summary>Windows (10/11, x64) environment setup</summary>

You need Python 3 and the MSVC C++ toolchain — Python 3 runs prebuild; for the toolchain, pick the "Desktop development with C++" workload of VS 2022 Build Tools:

```powershell
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex            # MoonBit
winget install Python.Python.3.12
winget install Microsoft.VisualStudio.2022.BuildTools -e --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

On Windows, moon compiles native code **out of the box and locates the MSVC toolchain itself**. A plain shell (PowerShell / Git Bash) runs `moon run` directly — no need for the "x64 Native Tools Command Prompt" or a manual `call vcvars64.bat`. The older guidance — "must run from the Native Tools prompt", "also install CMake and ATL" — described the old libyue/CMake build chain and does not apply to the self-drawn stack.

</details>

## 2. Create the project

```sh
moon new my_app
cd my_app
moon add NoahLiu/native-gui
```

The project `moon new` generates needs three manual adjustments:

- **`moon.mod`: change `preferred_target = "wasm"` to `"native"`** — this library uses native FFI and supports only the native backend; skip if the template already defaults to native.

- **Rename the entry file: `my_app.mbt` → `main.mbt`** — the current moon only recognizes a file named `main.mbt` as the program entry; the template's default file name reports `Missing main function`.

- **Replace the whole `moon.pkg` with** — moon's DSL format, not JSON:

  ```
  import {
    "NoahLiu/native-gui/core",
    "NoahLiu/native-gui/ui",
  }

  pkgtype(kind: "executable")

  supported_targets = "native"
  ```

  `import` gives the code access to the library: `@ui.*` provides widgets, components, and the declarative entries (`mount_window` and the node constructors), `@core.*` provides the app host and reactive state (`Store` / `Signal`). `pkgtype(kind: "executable")` and `supported_targets = "native"` declare this package an executable entry that builds only for the native target.

## 3. Your first window

Replace `main.mbt` entirely with:

```moonbit
fn main {
  let count : @core.Store[Int] = @core.Store::new(0)
  let app = match @ui.mount_window(
    [
      @ui.col(
        [
          @ui.text("Hello, MoonBit!", role=@ui.Title),
          @ui.button("Click me", variant=@ui.Solid, on_click=fn() {
            count.update(fn(n) { n + 1 })
          }),
          @ui.bind_label(count, fn(n : Int) -> String { "Clicked \{n} times" }),
        ],
        padding=24.0,
        row_gap=12.0,
      ),
    ],
    title="Tutorial demo",
    width=360,
    height=220,
  ) {
    None => {
      println("No window backend or no display service on this platform")
      return
    }
    Some(a) => a
  }
  app.run()
}
```

```sh
moon run .
```

A window appears: a title, a button, and a "Clicked 0 times" line. Click the button and the number ticks up by itself. That is **reactive state**: when `count` changes, `bind_label` refreshes on its own — no "update the text on click" glue code. The UI is declared as a tree of **node constructors** (`@ui.col([...])` / `@ui.text(...)` / `@ui.button(...)`) and mounted in one `mount_window` call; `mount_window` returns `None` when there is no window backend or no display service, and the example exits accordingly.

## 4. MoonBit syntax at a glance (only what the code above uses)

| Syntax | Meaning |
|---|---|
| `fn main { ... }` | program entry |
| `let count : @core.Store[Int] = ...` | type annotation: `Store[Int]` is a box of integer state |
| `match expr { ... }` | pattern matching, take a value per branch (here, unwrapping an `Option`) |
| `None => ... / Some(a) => a` | the two states of an optional value: `None` absent, `Some(x)` present |
| `fn(n) { n + 1 }` | anonymous function (lambda), passed in as a callback |
| `on_click=fn() { ... }` | labelled argument: parameters with defaults are passed by name |
| `"Clicked \{n} times"` | string interpolation, `\{expression}` embeds any value |

**Learn MoonBit properly**: the official [Chinese tutorial](https://docs.moonbitlang.com/zh-cn/latest/tutorial/index.html) ([English tutorial](https://docs.moonbitlang.com/en/latest/tutorial/index.html)); if you prefer learning hands-on, the official [Tour of MoonBit](https://tour.moonbitlang.com) walks you through lessons in the browser.

## 5. Next steps

Once your first app runs, pick a path by goal:

**Make it look good** — out of the box the app already follows the system light/dark mode and accent color; connect it in one `follow_system_theme` line:

```moonbit
handle=fn(a : @core.App) -> Unit {
  let _ = a.follow_system_theme(interval_ms=2000)
}
```

Themed forms for `@ui.text` / `@ui.button` (the four `button` `variant`s, `tag` / `alert` / `card`, …) are in [components.md](components.md); stylesheets (`Style` values plus `hover` / `active` / `focus` states and transitions) in [design.md (Chinese)](/zh/design).

**Copy from a working app** — the demo board is the material library:

```sh
git clone https://github.com/lb091188/moonbit-native-gui && cd moonbit-native-gui
moon run examples/showcase    # 15 pages: basics / forms / navigation / data display / feedback / events & layout / system integration…
```

Pick a page in the left menu and write against it on the right; each page's source is its own file (`examples/showcase/pages/*.mbt`), ready to copy and adapt. For smaller starting points: `moon run examples/hello` (minimal window) and `moon run examples/hello-themed` (themed widget set).

**Learn the layers** — a few documents, each covering one face:

- [declarative.md](declarative.md): describe the UI as a node tree (`Node` / `mount_window`) and bind state with `Store` / `Signal` — the click counter in section 3 is its minimal form
- [layout.md](layout.md): layout styling (the flex / padding / margin fields of `Style`, and the loose parameters plus the `class` channel of `@ui.col` / `@ui.row`)
- [components.md](components.md): a quick reference to every widget and component's parameters and events
- [system-capabilities.md](system-capabilities.md): OS capabilities (`@sys`) — volume / app lookup / wallpaper / monitors / clipboard / power / printers…, with unified `Result` semantics

**Hit a problem** — [adaptation.md](adaptation.md) records field-tested pitfalls and root causes per platform; the tray design is in [tray.md](tray.md).

## 6. A note to contributors

This library aims at writing native desktop apps in MoonBit. It now covers self-drawn widgets, charts, Markdown, an embedded WebView, and system capabilities — and there is still a lot worth doing:

- **Platform compatibility**: mainline verification runs on Ubuntu (XFCE/GNOME/KDE) and Windows; the macOS backend is landing on the `mac` branch and not yet merged into master — whatever you hit on a Mac is valuable input.
- **Widgets and capabilities**: un-wrapped items and per-platform adaptation pitfalls are all welcome as issues first.
- **Docs and examples**: the tutorial, component docs, and every showcase page are open for improvement.

No barrier to taking part: file an issue describing a problem or idea, or send a PR directly. Before you start, remember three things — `moon check` passes with zero errors and zero warnings and `moon test` is all green before committing; field-tested pitfalls go into [adaptation.md](adaptation.md) together with their fixes; one cohesive change per batch. The full process (the FFI spec for new widgets, prebuild-hosted linking) is in [AGENTS.md](https://github.com/lb091188/moonbit-native-gui/blob/master/AGENTS.md) at the repository root.
