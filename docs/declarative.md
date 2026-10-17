# Declarative layer & reactivity (@core + @ui)

The UI is described as a **node tree**, state lives in `Store` / `Signal`, and the framework makes "data changed → UI follows". This page covers the wiring. Styling: [layout.md](layout.md) and [design.md (Chinese)](/zh/design); components: [components.md](components.md).

## 1. Node tree and mounting

Every `@ui` component constructor returns a `@widget.Node`. Assemble nodes into an `Array[Node]` and hand them to `mount_window` — it builds the window, mounts, and starts the loop in one step:

```moonbit
fn main {
  let count : @base.Store[Int] = @base.Store::new(0)
  let app = match @ui.mount_window(
    [@ui.col([
      @ui.text("Count", role=@ui.Title),
      @ui.button("Increment", on_click=fn() { count.update(fn(n) { n + 1 }) }),
      @ui.bind_label(count, fn(n : Int) -> String { "\{n}" }),
    ], padding=16.0, row_gap=8.0)],
    title="Declarative demo",
    width=320, height=200,
  ) {
    None => return   // no window backend or no display service
    Some(a) => a
  }
  app.run()
}
```

- `mount_window(children, title?, width?=800, height?=600, handle?)`: builds the host, mounts the children, and hands the host back for you to `run`. The window, event loop, overlay layer, and IME channel are all set up in `App::new`; returns `None` when there is no display service.
- `mount_window_render(render : () -> Array[Node], …)`: the **render slot** form, an alternative to a static array. `render` runs **once** at mount to build the first frame; the framework never re-runs it. Reactivity comes entirely from `for_list` / `when` / `*_dyn` / `bind*` in the tree, which self-subscribe and self-diff. To replace the whole tree's content, go through `bind_node`.
- `handle=fn(app : @widget.App) { … }`: take the host handle for operations the framework doesn't expose, e.g. `app.follow_system_theme(...)`.

## 2. Imperative escape hatch

When you need to build a control yourself instead of using a ready-made component:

| Entry | Purpose |
|---|---|
| `@widget.node_of(widget)` | wrap an already-built `Widget` into a `Node` |
| `@widget.node_of_new(finish : (Widget) -> Widget)` | build and configure a control on the spot, return a `Node` |
| `Node::on_mount(node, f : () -> Unit)` | run `f` at the moment of mounting — for scheduling timers, registering focus, anything needing the host present |
| `@widget.mount_children(parent, children)` | mount a batch of `Node`s under a parent widget |
| a component's `handle? : (Widget) -> Unit` | take back its internal `Widget` while building |

> **Pitfall (memorize this)**: actions that need the host present — `set_timeout`, pushing chart points, the tray dispatch table — **must not run in the construction phase**. A function like `page(app)` is evaluated before the window exists: `app.host` is still `None` and the process-level timer channel isn't installed yet, so the first tick runs on an empty channel and the loop dies once it stops rescheduling. Hang such actions on `Node::on_mount` or the `handle` callback — both run after mount.

## 3. Store: a box for one value

`Store[T]` is a readable, writable, subscribable state box:

```moonbit
let name : @base.Store[String] = @base.Store::new("MoonBit")
name.get()                       // read
name.set("World")                // write (dedups by value when T : Eq; equal values don't notify)
name.update(fn(n) { n + "!" })   // change in place
let off = name.subscribe(fn(v) { println(v) })
```

| Method | Purpose |
|---|---|
| `Store::new(value)` / `get()` | create / read |
| `set(v)` / `update(f)` | write; requires `T : Eq` — no notify when new equals old, avoiding needless repaints |
| `set_always(v)` / `update_always(f)` | use when the value type does no Eq dedup or every write must fire; for snapshot cases with in-place-mutated arrays, see adaptation |
| `subscribe(f) -> () -> Unit` / `subscribe_id(f) -> Int` / `remove(id)` | subscribe / unsubscribe |
| `map(f : A -> B) -> Store[B]` | derive a read-only box |
| `signal() -> Signal[T]` | convert to a signal for the `Signal`-taking entries `bind` / `*_dyn` |

To bind to the UI: `bind_label(store, f)` for text, the `*_dyn` signal forms for display components, `ListStore` for lists (§5).

## 4. Signal: derived values with dependency collection

`Signal[T]` is a finer-grained reactive source than `Store`, with automatic dependency collection:

| Entry | Purpose |
|---|---|
| `Signal::new(v)` / `get` / `set` / `set_eq` / `update` | basic read / write |
| `Signal::computed(fn () -> T)` | **derived signal**: every signal `get` inside becomes a dependency automatically; when a dependency changes, recompute and notify downstream |
| `Signal::effect(fn () -> Unit)` / `@base.effect(body)` | **side effect**: tracks the signals read in the body, re-runs on change, returns an unsubscribe function |
| `Signal::subscribe(f) -> Int` / `remove(sid)` / `sub_count()` | subscribe / unsubscribe / count |
| `Signal::map(f)` / `Signal::store()` | derive / convert back to a `Store` |
| `batch(fn () -> Unit)` | commit in batch — multiple sets inside fire downstream only once |

Store and Signal convert both ways: `store.signal()`, `Signal.store()`. Display entries take `Signal[T]`; input controls take `Store[T]` directly. Both share one source.

## 5. Lists and visibility: for_list / when

List rendering uses keyed diffing to avoid rebuilding the whole table:

```moonbit
let rows : @base.ListStore[String] = @base.ListStore::new(["a", "b"])
@ui.for_list(rows, build=fn(item, _i) { @ui.text(item) }, key~=fn(r) { r })
```

| Entry | Purpose |
|---|---|
| `ListStore::new / get / length / push / remove / update / splice` | list state; `remove` and `update` hit by predicate |
| `ListStore::subscribe_diff(...)` / `@base.ListStore.signal()` | keyed-diff subscription |
| `@ui.for_list(ls, build, key~, eq?)` | build rows by key; the default criterion is "same key, same value" — make changing fields their own `Store`s instead of remounting the whole row |
| `@ui.for_list_indexed(ls, build)` | index-aligned — equivalent to no `:key`; unloads extra rows only when the length shrinks |

`when` handles visibility: nodes are not destroyed, state is kept. To keep both branches resident and switch purely by visibility with zero rebuilds, use `when_else`:

```moonbit
@ui.when_bool(show_sig, @ui.text("only shown when show is true"))
@ui.when_else_store(vis_store, ok_node, cancel_node)   // both branches resident, toggled by visibility
```

`when` and `when_else` each come in four forms — `Signal` / `Store` × generic / boolean; see the "reactive control" section of [components.md](components.md).

## 6. Whole-tree replace and in-place replace

When the content structure changes — not a text edit, not a visibility toggle:

- `@widget.bind_node(sig : Signal[T], f : (T) -> Node)`: on a signal change, build a new node with `f(v)` and **replace the old node in place**.
- `@widget.swap_node(sig : Signal[Bool], a : Node, b : Node)`: switch between two nodes in place on a boolean.

"In-place replace" is this stack's settled relink design: the engine provides `insert_child` / `remove_child_at` for it, the widget layer provides `index_of` / `move_child`. Replacement does not rebuild the parent chain, and hit rectangles are re-taken from the layout result each frame — so the two workarounds of the old Windows chain ("defer a tick / force a reflow") are not needed.

## 7. The repaint loop

Framework repaints route back to the host App through the process-level `@widget.set_repaint_hook`; a control requests a redraw of the current frame with `@widget.invalidate()`. Incremental dirty-region relayout recomputes only the changed chain: `bind_label` and `*_dyn` re-measure only themselves on a text change, without rebuilding the subtree.

## 8. Related docs

- Components and parameters: [components.md](components.md)
- Layout styling: `Style` values and the `class` channel in [layout.md](layout.md)
- View-layer and reactivity design: [design.md (Chinese)](/zh/design) §3 reactivity, §4 view layer
- Five-minute tutorial: [tutorial.md](tutorial.md)
