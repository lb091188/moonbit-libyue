# Declarative layer & reactivity (@core + @ui)

The interface is described as a **tree of nodes**, state lives in `Store` / `Signal`, and the framework makes "data changed → UI follows". This page covers the wiring; styling is in [layout.md](layout.md) and [design.md (Chinese)](/zh/design), components in [components.md](components.md).

## 1. The node tree and mounting

Every `@ui` component constructor returns a `@core.Node`. Assemble nodes into an `Array[Node]` and hand them to `mount_window` to build the window, mount, and start the loop in one step:

```moonbit
fn main {
  let count : @core.Store[Int] = @core.Store::new(0)
  let app = match @ui.mount_window(
    [@ui.col([
      @ui.text("计数", role=@ui.Title),
      @ui.button("加一", on_click=fn() { count.update(fn(n) { n + 1 }) }),
      @ui.bind_label(count, fn(n : Int) -> String { "\{n}" }),
    ], padding=16.0, row_gap=8.0)],
    title="声明式示例",
    width=320, height=200,
  ) {
    None => return   // no window backend or no display service
    Some(a) => a
  }
  app.run()
}
```

- `mount_window(children, title?, width?=800, height?=600, handle?)`: builds the host (window + event loop + overlay layer + IME channel all set up in `App::new`), mounts the children, and hands the host back for you to `run`. Returns `None` with no display service.
- `mount_window_render(render : () -> Array[Node], …)`: the **render-slot** form (an alternative to a static array). `render` is called **once** at mount to build the first frame; the framework never re-runs it — reactivity is entirely the tree's `for_list` / `when` / `*_dyn` / `bind*` self-subscribing and self-diffing. Whole-tree replacement goes through `bind_node`.
- `handle=fn(app : @core.App) { … }`: take the host handle for operations the framework doesn't expose (e.g. `app.follow_system_theme(...)`).

## 2. Imperative escape hatch

When you need to build a control yourself rather than use a ready component:

| Entry | Purpose |
|---|---|
| `@core.node_of(widget)` | wrap an already-built `Widget` into a `Node` |
| `@core.node_of_new(finish : (Widget) -> Widget)` | build and configure a control on the spot, return a `Node` |
| `Node::on_mount(node, f : () -> Unit)` | run `f` at the moment of mounting (scheduling timers, registering focus — anything needing the host present) |
| `@core.mount_children(parent, children)` | mount a batch of `Node`s under some parent widget |
| a component's `handle? : (Widget) -> Unit` | take back its internal `Widget` while building |

> **Pitfall (memorize this)**: actions that need the host present (`set_timeout`, pushing chart points, the tray dispatch table) **must not run in the construction phase** — a `page(app)` function is evaluated before the window is built, when `app.host` is still `None` and the process-level timer channel isn't installed yet, so its first tick lands on an empty channel and the loop never reschedules. Hang them on `Node::on_mount` or the `handle` callback (both run after mount).

## 3. Store: a box for one value

`Store[T]` is a readable, writable, subscribable state box:

```moonbit
let name : @core.Store[String] = @core.Store::new("MoonBit")
name.get()                       // read
name.set("World")                // write (dedups by value when T : Eq; equal values don't notify)
name.update(fn(n) { n + "!" })   // change in place
let off = name.subscribe(fn(v) { println(v) })
```

| Method | Purpose |
|---|---|
| `Store::new(value)` / `get()` | create / read |
| `set(v)` / `update(f)` | write (requires `T : Eq`; if new == old, no notify, avoiding needless repaint) |
| `set_always(v)` / `update_always(f)` | for value types without Eq dedup, or when every set must fire (see adaptation for the snapshot pattern with in-place-mutated arrays) |
| `subscribe(f) -> () -> Unit` / `subscribe_id(f) -> Int` / `remove(id)` | subscribe / unsubscribe |
| `map(f : A -> B) -> Store[B]` | derive a read-only box |
| `signal() -> Signal[T]` | convert to a signal for entries that take `Signal` (`bind` / `*_dyn`) |

Bind to the UI with `bind_label(store, f)` (text) or `*_dyn` (display signal forms). Lists use `ListStore` (§5).

## 4. Signal: derived values with dependency tracking

`Signal[T]` is a finer-grained reactive source with automatic dependency collection:

| Entry | Purpose |
|---|---|
| `Signal::new(v)` / `get` / `set` / `set_eq` / `update` | basic read / write |
| `Signal::computed(fn () -> T)` | **derived signal**: signals `get` inside become dependencies automatically; when they change, recompute and notify downstream |
| `Signal::effect(fn () -> Unit)` / `@core.effect(body)` | **side effect**: tracks signals read in the body, re-runs on change; returns an unsubscribe function |
| `Signal::subscribe(f) -> Int` / `remove(sid)` / `sub_count()` | subscribe / unsubscribe / count |
| `Signal::map(f)` / `Signal::store()` | derive / convert back to a `Store` |
| `batch(fn () -> Unit)` | commit in bulk — multiple sets inside fire downstream only once |

Store ↔ Signal convert freely (`store.signal()`, `Signal.store()`); display entries take `Signal[T]`, input controls take `Store[T]` directly, both from the same source.

## 5. Lists and visibility: for_list / when

List rendering uses keyed diffing to avoid rebuilding the whole list:

```moonbit
let rows : @core.ListStore[String] = @core.ListStore::new(["a", "b"])
@ui.for_list(rows, build=fn(item, _i) { @ui.text(item) }, key~=fn(r) { r })
```

| Entry | Purpose |
|---|---|
| `ListStore::new / get / length / push / remove / update / splice` | list state: `remove` / `update` hit by predicate |
| `ListStore::subscribe_diff(...)` / `ListStore.signal()` | keyed-diff subscription |
| `@ui.for_list(ls, build, key~, eq?)` | build rows by key; default criterion "same key, same value" (make mutable fields their own `Store` rather than remount the whole row) |
| `@ui.for_list_indexed(ls, build)` | index-aligned (equivalent to no `:key`); unloads extra rows only on shrink |

Visibility uses `when` (not destroyed, state kept) or `when_else` (both branches prebuilt, switched by visibility, zero rebuild):

```moonbit
@ui.when_bool(show_sig, @ui.text("only when show is true"))
@ui.when_else_store(vis_store, ok_node, cancel_node)   // both resident, toggle by visibility
```

`when` / `when_else` each come in `Signal`/`Store` × generic/boolean variants (see the "reactive control" section of [components.md](components.md)).

## 6. Whole-tree and in-place replacement

When the structure changes (not just editing text or toggling visibility):

- `@core.bind_node(sig : Signal[T], f : (T) -> Node)`: on a signal change, build a new node with `f(v)` and **replace the old one in place**.
- `@core.swap_node(sig : Signal[Bool], a : Node, b : Node)`: switch between two nodes in place by a boolean.

"In-place replacement" is this stack's relink decision (the engine provides `insert_child`/`remove_child_at` for it, the widget layer `index_of`/`move_child`); the parent chain isn't rebuilt and hit rectangles are re-taken from the layout result each frame, so the old Windows chain's two workarounds ("defer a tick / force a reflow") aren't needed.

## 7. The repaint loop

Framework repaints route back to the host App via the process-level `@core.set_repaint_hook`; a control requests a redraw of the current frame with `@core.invalidate()`. Incremental dirty-rect relayout guarantees "only the changed chain is recomputed" — `bind_label` / `*_dyn` re-measure only themselves on a text change, without rebuilding the subtree.

## 8. Related docs

- Components and parameters: [components.md](components.md)
- Layout styling (`Style` values and the `class` channel): [layout.md](layout.md)
- View-layer and reactivity design: [design.md (Chinese)](/zh/design) (§3 reactivity, §4 view layer)
- Five-minute tutorial: [tutorial.md](tutorial.md)
