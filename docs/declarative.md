# Declarative UI: Node/mount and Store

moonbit-libyue provides three freely composable layers of syntactic sugar on top of the classic imperative API:

| Layer | Content | Typical scenario |
|---|---|---|
| L1 | `X::make(...)` props constructors, `apply_style` | Create a widget in one line (usable standalone) |
| L2 | `Node` tree + `mount` / `vbox` / `label` / `button` … | Declare the whole UI structure |
| L3 | `Store[T]` + `bind_label` | UI updates automatically when data changes |

For a full side-by-side example, see
`examples/showcase`.

## L1: props constructors

Every widget has an `X::make` constructor that merges "create + properties + callbacks" into a single expression.
Apart from "content" parameters (such as a Label's text), everything is optional and named; omitting a parameter uses the default:

```moonbit
let btn = @yue.Button::make("OK", on_click=fn() { save() })
let slider = @yue.Slider::make(range=Some((0.0, 100.0)), step=Some(1.0))
let entry = @yue.Entry::make(entry_type=Password)
entry.on_activate(fn() { check(entry.get_text()) })
```

Note that L1 constructors and their same-named L2 nodes differ in callback parameters: `Entry::make` takes
`entry_type` / `on_activate()` (callback without arguments), while the L2 `entry` node takes
`password` / `on_enter(String)` (callback receives the text, see the next section).

`style` (numeric style key-value pairs) and `style_str` (string-typed) are available on almost every constructor:

```moonbit
@yue.Label::make("Title", style=[("marginBottom", 10.0)],
                 style_str=[("color", "#356AA0")])
```

To batch-apply styles to an existing widget, use the free function `apply_style(view, style=..., style_str=...)`.

## L2: the Node tree and mount

A `Node` represents "a UI fragment not yet mounted". Constructing nodes only builds the tree; **widgets are actually created and callbacks registered at mount time** — so the same code can declare first and assemble later:

```moonbit
fn page(state : State) -> @yue.Container {
  @yue.mount([
    @yue.label("Settings", style_str=[("color", "#356AA0")]),
    @yue.entry(text="Nickname", on_enter=fn(s) { state.save(s) }),
    @yue.hbox([
      @yue.button("Save", on_click=fn() { state.flush() }),
      @yue.button("Cancel"),
    ]),
  ])
}
win.set_content(page(state))   // mount returns the root Container; feed it straight to the window
```

### Windows as the declarative root: mount_window

A `Window` has no parent view, so instead of being a Node it serves as the mount entry point: it creates the window, mounts the subtree as its content, and returns the window handle; non-view assets such as menu bars and tray icons are attached via `handle`:

```moonbit
let win = @yue.mount_window(
  [
    @yue.label("Hello"),
    @yue.button("Quit", on_click=fn() { @yue.quit() }),
  ],
  title="Demo",
  size=Some((960.0, 640.0)),
  center=true,
  handle=fn(w) { w.set_menubar(build_menubar()) },
)
```

### Node constructor overview

| Node | Corresponding widget | Notes |
|---|---|---|
| `vbox(children, …)` / `hbox(children, …)` | Container | vertical / horizontal layout |
| `container(on_draw, handle, …)` | Container | custom-paint canvas / get container handle |
| `label(text, …)` | Label | text follows the theme regular color by default (changes with `theme_apply`); fixed colors via handle `set_color` |
| `button(title, on_click, …)` | Button | |
| `checkbox(title, checked, on_change, …)` | Checkbox | `on_change(Bool)` |
| `radio(title, checked, on_change, …)` | Radio | mutually exclusive within a group |
| `entry(text, password, on_enter, on_input, …)` | Entry | callbacks receive the text |
| `text_edit(text, on_input, …)` | TextEdit | callback receives the text |
| `slider(value, range, step, on_change, …)` | Slider | `on_change(Double)` |
| `progress(value, indeterminate, …)` | ProgressBar | |
| `picker(items, selected, on_change, …)` | Picker | |
| `combo(items, selected, on_select, on_input, …)` | ComboBox | |
| `group(title, content, …)` | Group | content is a single Node |
| `scroll(content, content_size, policy, …)` | Scroll | content is a single Node |
| `separator(orientation)` | Separator | |
| `tab(pages, on_change, …)` | Tab | each page gets an automatic container |
| `date_picker(epoch, on_change)` | DatePicker | |
| `gif(image, scale)` | GifPlayer | |
| `browser(url, html, …)` | Browser | one of the two |
| `bind_label(store, f, …)` | Label | L3 reactive binding, see below |

All nodes accept `style` / `style_str`; common nodes also have a **`handle`** parameter.

### handle: getting the widget handle back

In a declarative tree, widgets only exist once mounted. If you want to imperatively operate on a widget after mounting (update a progress bar, focus an input…), pass a `handle` callback that receives the concrete handle at mount time:

```moonbit
let bar : Ref[@yue.ProgressBar?] = Ref(None)
@yue.progress(handle=fn(p) { bar.val = Some(p) })
// any time later: p.set_value(0.5) on the value in bar.val
```

### Mixing in imperative code: node_of

Any existing ViewLike widget can be wrapped as a node and embedded in a declarative tree:

```moonbit
@yue.node_of(my_legacy_view, style=[("marginBottom", 8.0)])
```

### Custom nodes

`Node` is an open structure (a single mount-function field); to wrap your own composite widget, just write an ordinary function returning a Node; for lower-level control you can write a literal directly:

```moonbit
fn tagged(label_text : String, body : Node) -> Node {
  @yue.vbox([@yue.label(label_text), body])
}
```

#### Custom component recipes (summarized from `examples/showcase`)

1. **Composite components** (recommended): an ordinary function returning a Node; parameters are props, closures are private state (e.g. `card`/`nav_item`).
2. **Drawn components**: `container(on_draw=...)` + Painter draws badges etc. with zero image assets.
3. **Stateful components**: the component holds a private `Store`, refreshed automatically via `bind_label`; each instance has independent state (e.g. `counter_widget`). Cross-component coordination uses a shared Store + `map` derivation (the sidebar highlight works this way).
4. **Extending built-in nodes**: `vbox`/`hbox` accept `handle` (returns the Container handle at mount time, for background colors etc.). Note: the `parent : View` received by a `Node`'s `mount` only has `attach` available **inside the `yue` package** — outside the package you cannot write a Node literal that mounts a container into the parent directly; extend the library instead, or wrap existing views with `node_of`.
5. **Modern layouts**: plain vbox/hbox/scroll flex boxes can produce a "dark sidebar + header bar + scrolling cards" shell; the key points are that **the root node needs `style=[("flex", 1.0)]` to fill the window**, the fixed-width sidebar sets `width` without flex, the main area takes `flex=1`, and the root container uses `style_str=[("alignItems", "stretch")]` so child columns fill the height.

### Component library (yue/components.mbt)

Element-Plus-style non-form components built on top of the declarative layer, pure MoonBit with zero platform code:

- `side_menu(items, selected)` — sidebar navigation (hover grey, selected light-blue + accent bar, syncs pages via `set_visible`);
- `segmented(options, selected)` — segmented control / top-bar navigation;
- `tag` / `tag_of_type` — labels (solid custom color / five semantic types);
- `breadcrumb` · `pagination` · `steps` · `alert` / `alert_closeable` · `timeline` · `collapse` · `descriptions` · `result` · `empty` · `statistic` · `avatar` · `badge_count` / `badge_dot` · `card`;
- `code_view(lines)` — syntax-highlighted code view
- `segmented(options, selected)` — segmented control / top-bar navigation (selected item floats on white);
- `tag(text, color)` — colored rounded label (width auto-fits the text at mount time);
- `code_view(lines)` — syntax-highlighted code view: one AttributedText per token (whole-range coloring) measured and drawn manually. **Visually equivalent to range coloring and consistent across platforms** — on Windows, AttributedText range font/color is an upstream deficiency (see adaptation.md); this approach bypasses it and is a viable alternative for code highlighting / terminal rendering. The built-in `tokenize_moonbit` is a demo tokenizer; consumers can feed any lexical analysis result.

Component state coordination goes through `Store`; main-area page switching uses "subscribe to Store + `ViewLike::set_visible`" (the ABI was added on 2026-09-16). Full demo in `examples/showcase` (sidebar + top bar + page switching + code page); component list and screenshots in [docs/components-ui.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/components-ui.md).

## L3: Store and bind_label

A `Store[T]` is a subscribable value: `set` notifies all subscribers, `map` derives read-only views, and `bind_label` plugs a Store into a declarative tree — when the state changes, the text updates automatically:

```moonbit
let count : @yue.Store[Int] = @yue.Store::new(0)

win.set_content(@yue.mount([
  @yue.bind_label(count, fn(n) { "Clicked \{n} times" }),
  @yue.button("Click me", on_click=fn() { count.update(fn(n) { n + 1 }) }),
]))
```

Clicking the button → `count` changes → the `bind_label` text automatically becomes "Clicked 1 times".
Where you don't use a Store, keep using `handle` + setter as before; both coexist.

API overview:

| Function | Description |
|---|---|
| `Store::new(v)` | create |
| `get()` / `set(v)` | read / write and notify |
| `update(f)` | `set(f(get()))` |
| `subscribe(f)` | subscribe; **no callback at registration time**, read the initial value via `get` directly |
| `map(f)` | derive a Store that follows the source automatically on change (chainable) |
| `bind_label(store, f, …)` | bind text inside a declarative tree; `f` maps the state to a string |

## Inherent pitfalls

1. **Nodes are instantiated only at mount time**: when `button(...)` returns, the widget does not exist yet — do not save widget references while building the tree; if you need a reference, use `handle` (triggered at mount time). A tree is normally `mount`ed only once; mounting the same node again instantiates a **second** copy of the widget.
2. **`handle` is not called `ref`**: `ref` is also a MoonBit reserved word.
3. **Store has no unsubscription**: subscriptions live for the whole application lifetime, and `set` does not deduplicate (identical values still notify). Calling `set` on another Store inside a subscription callback is safe (snapshot iteration), but do not let two Stores trigger each other into an infinite loop.
4. **bind_label's subscription happens at mount time**: an unmounted bind node does not subscribe and receives no notifications; the initial value is rendered at mount time directly with `f(store.get())`.
5. **Checkbox/radio initialization callbacks**: after `checkbox`/`radio` mounts with `checked=true`, it asynchronously receives one `on_change` when entering the event loop (GTK toggled-signal semantics); **when a radio group switches, the old item that got deselected also receives one `on_change(false)`**. Base business logic on `is_checked()`.
6. **Heterogeneous children only via Node**: MoonBit traits cannot be used as array element types, so `Array[ViewLike]` cannot hold mixed widgets — this is exactly why `Node` exists; at the `X::make` layer, the single-content parameters (`Group::make` / `Scroll::make`) accept concrete widgets directly.
