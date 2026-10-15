# Component reference (@ui)

Every self-drawn widget and component lives in `NoahLiu/native-gui/ui` (alias `@ui`). Each component is a **constructor returning `@core.Node`** — you describe the interface as a tree of nodes and mount it in one `@ui.mount_window([...])` call. This page lists each component's entry signature and purpose as a quick reference; parameters always follow the code (`gui/ui/*.mbt`).

> Runnable examples for every component are gathered in `examples/showcase` (a 14-page demo board, one source file per page) — the fastest way in.

## Conventions (read this first)

**Typed parameters + a `class` style channel.** Components take typed parameters (size, colour, value), not CSS string tables; overriding the look goes two ways — loose parameters (e.g. `font_size` / `background_color`) or `class? : Array[@style.Style]` (layer `Style` value blocks on top, last array element wins). The full style layer is in [design.md (Chinese)](/zh/design).

**State lives in `Store`, no glue code.** Value-bearing controls (checkbox / radio / switch / slider / input / progress …) hold their current value in an `@core.Store[T]`: the component reads and writes it, and an external change refreshes the component. Display components additionally come in `x` (takes a value) + `x_dyn` (takes a `Signal[T]`) pairs, sharing one drawing path.

**Events are always `on_*`.** Callbacks are named `on_click` / `on_change` / `on_drop` …; `handle?` is an escape hatch (take back the internal `@core.Widget` for operations the framework doesn't expose), not an event.

**Keyboard accessibility is built in.** Form-family controls (button / checkbox / radio / switch / stepper / slider / rate / select / color picker / date-time / segmented) claim a focus id by default and join the Tab chain, with the focus border turning the theme accent on focus; Space/Enter activate, arrow keys adjust the value or move the selection per control (see each entry).

**`TextRole`:** `Plain` (no role, uses explicit size/weight) · `Title` · `Section` · `Accent` (the three go SemiBold at theme font sizes) · `Body` · `Secondary`.

**`SemanticType`:** `Primary` · `Success` · `Warning` · `Danger` · `Info`. Stored as theme token names, resolved live on redraw — not frozen snapshots.

---

## Layout & containers

| Constructor | Purpose |
|---|---|
| `view(children, direction?=Column, row_gap?, column_gap?, padding?, width?, height?, grow?, background_color?, border_color?, align_items?, justify_content?, class?, handle?)` | Generic container: direction, gaps on both axes, padding, size, background and border. Size 0 = fit content; fill remaining space with `grow=1.0` |
| `col(children, row_gap?, padding?, width?, height?, grow?, background_color?, border_color?, align_items?, class?, handle?)` | Vertical layout container (the Column form of `view`) |
| `row(children, column_gap?, padding?, width?, height?, grow?, background_color?, border_color?, align_items?=Center, class?, handle?)` | Horizontal layout container (the Row form of `view`) |
| `panel(title, children, padding?=10.0, row_gap?=6.0, width?)` | Titled panel (title on top, content below, panel background + border) |
| `split(first, second, direction?=Horizontal, ratio?=0.5, min_first?, min_second?, class?, handle?)` | Draggable split pane (unifies `hsplit`/`vsplit`, direction parameterized) |
| `scroll_view(children, state : ScrollState, width?, height?, class?, handle?)` | Vertical scroll container; `height` is the viewport (0 = given by the parent), overflow clipped, scrollbar drawn on the right edge |

> Scroll offset is applied at paint time, not in layout; `ScrollState` is provided by `ui/scroll.mbt`.

## Text & primitives

| Constructor | Purpose |
|---|---|
| `text(content, role?=Plain, font_size?=13.0, color?, weight?, family?, align?, max_width?, wrap?, ellipsis?, class?, handle?)` | Text (unifies `label` + `label_t`): with `role` it takes role font size / weight / theme colour; size comes from Pango measurement and feeds the layout engine (so text participates in baseline alignment) |
| `text_dyn(sig : Signal[String], role?, font_size?, color?, …, class?, handle?)` | Signal-driven text: on change it edits in place and recomputes only this chain (the counterpart of the old `bind_label`, the prototype of the display `*_dyn` family) |
| `bind_label(store : Store[A], f : (A) -> String, font_size?, color?, handle?)` | Declarative text binding: initial `f(store.get())`, then every `set` updates the text in place and re-measures; always single-line |
| `bind(sig : Signal[A], f : (A) -> String, font_size?, color?, handle?)` | Text binding (signal form): takes a source signal or a `computed` derived signal directly |
| `divider(text?, vertical?=false, color?, class?)` | Divider (unifies `separator` + the labelled `divider`): empty `text` = plain line (`vertical` picks horizontal/vertical), with text = centered breaking line |
| `image(path, width?, height?, handle?)` | Image: decodes a file (PNG/JPEG/GIF first frame); size 0 uses the original dimensions |
| `icon(kind : @icons.IconKind, size?=16.0, color?, class?, handle?)` | Vector icon: `size` is the box edge, empty colour = theme body text (resolved live with the theme) |
| `code_view(lines : Array[String], lang?="moonbit", font_size?=13.0, line_numbers?=false, handle?)` | Code highlight view (One Dark, deliberately not theme-following): 8-language keyword tables + token coloring, optional line-number column, size fits content |
| `gif(path, width?, height?, looping?=true, running?=true, state?, handle?)` | Animated image: `looping=false` stops after one pass; a non-GIF still image draws a single frame |

## Form controls

Value controls hold their current value in a `Store[T]`; external changes refresh them, interaction writes back.

| Constructor | Purpose |
|---|---|
| `button(text, on_click?, variant?=Soft, color?, background_color?, font_size?, min_width?, focus_id?, disabled?, enabled?, class?, handle?)` | Button, `variant : ButtonVariant` = `Solid`/`Soft`/`Border`/`Text`/`Danger`; Space/Enter activate |
| `input(store : Store[String], placeholder?, password?=false, read_only?=false, font_size?, family?, width?, focus_id?, caret_on?, …)` | Single-line input: selection / double-click word select / undo-redo / Ctrl+A-C-V / placeholder / read-only / password mask / inline IME, all in place; `clearable` (a ✕ on hover/focus that clears when clicked) |
| `textarea(store : Store[String], placeholder?, rows?=3, width?=260.0, height?, font_size?, family?, read_only?, focus_id?, caret_on?, …)` | Multi-line input: greedy wrapping (spaces / Latin words / CJK per-character) + vertical scroll, up/down keys cross display lines |
| `checkbox(content, state : Store[Bool], disabled?, enabled?, focus_id?, font_size?, class?, handle?)` | Checkbox + text label (the whole row is the click area); Space/Enter toggle |
| `radio_group(options : Array[String], state : Store[Int], disabled?, direction?=Row, gap?=12.0, class?)` | Radio group: `options` map to values 0..n-1; Space/Enter select this item, arrow keys move the selection (wrapping) |
| `switch(state : Store[Bool], on_text?, off_text?, disabled?, focus_id?, class?)` | Switch: a 40×20 pill + 16 round knob, optional on/off labels; Space/Enter toggle |
| `slider(state : Store[Double], min?=0.0, max?=100.0, step?=0.0, width?=160.0, disabled?, focus_id?, class?, handle?)` | Slider: press to take a value, drag follows (even off the track), `step>0` snaps; arrow keys step, Home/End to the ends |
| `stepper(state : Store[Int], min?=0, max?=999, step?=1, focus_id?, class?)` | Number stepper `[-] value [+]` (one shared frame, the touching-boundary side auto-disables); arrow keys increment/decrement |
| `select(options : Array[String], value : Store[String], on_change?, …)` | Dropdown (the single entry; an editable combo is `editable=true`): the popup opens on the overlay layer, ↑↓ highlight + Enter pick + Esc close |
| `color_picker(value : Store[String], colors?=[built-in 15 colors], on_change?, …)` | Color picker: field + swatch grid; Enter opens, ←/→ move a cell, ↑/↓ move a row, Enter picks |
| `rate(value : Store[Int], max?=5, on_change?, …)` | Rating: vector five-point stars + hover pre-light; arrow keys change stars, Home/End clear/max |
| `form_item(label_text, control : Node, label_width?=90.0, error?=Store[String], handle?)` | Form item: fixed-width right-aligned label + control, a permanent error row below (fixed line height reserved so errors don't jump layout) |
| `form(title, items : Array[Node], row_gap?=8.0, handle?)` | Form: group title + a column of form items |
| `link(text, on_click : () -> Unit, font_size?, class?, handle?)` | Link text: theme colour, underline on hover, fires on release |

## Data display

The display family has `*_dyn` signal forms (`text` becomes a `Signal`, edits in place and recomputes width, unsubscribe rides the recycle bag).

| Constructor | Purpose |
|---|---|
| `tag_of_type(text, t : SemanticType, font_size?=12.0, class?)` | Semantic tag (light background + accent text); `tag_of_type_dyn` takes a signal |
| `tag(text, color, font_size?=12.0, class?)` | Custom-coloured tag (solid + white text); `tag_dyn` takes a signal |
| `badge_count(value : Int, max?=99, color?, class?)` | Number badge: over `max` shows "max+"; `badge_count_dyn` takes a `Signal[Int]` |
| `badge_dot(size?=8.0, color?, class?)` | Dot badge (no number, just "something new") |
| `avatar(text, size?=32.0, background_color?, class?)` | Avatar: centers the first character of the text; `avatar_dyn` takes a signal |
| `statistic(title, value, precision_color?, prefix?, class?)` | Statistic: small title + value (with optional prefix/suffix); `statistic_dyn` takes a `Signal[String]` |
| `card(children, title?, padding?=12.0, row_gap?=6.0, class?)` | Card: optional title bar + content, panel background + border |
| `descriptions(items : Array[(String, String)], title?, label_width?=96.0, class?)` | Description list: `(label, value)` pairs, one row each |
| `empty(description?="No data", class?)` | Empty state: icon + description, centered |
| `result(title, subtitle?, t?=Success, class?)` | Result page: semantic icon + title + subtitle |
| `progress(state : Store[Double], max?=1.0, width?=200.0, height?=6.0, color?, class?, handle?)` | Progress bar: `state` in 0..max (display-only) |
| `progress_line(state, max?=1.0, width?=200.0, label_side?=true, class?)` | Progress with a percentage label |
| `timeline(items : Array[(String, String, SemanticType)], item_height?=56.0, gap?=12.0, class?)` | Timeline: `(title, description, semantic colour)` rows of equal height; the connector line spans row gaps without breaking |
| `carousel(pages : Array[Node], width?=360.0, height?=180.0, interval_ms?=3000, rotation?=CarouselHandle::make(), class?, handle?)` | Carousel: panel sequence + arrows + indicator dots; auto-advances when `interval_ms>0` and pages > 1 (pauses on hover) |

## Navigation

| Constructor | Purpose |
|---|---|
| `menu(items : Array[String], selected : Store[String], icons?, width?=180.0, class?, handle?)` | Side navigation menu: selection = theme light background + left accent bar; `selected` can be shared with the main area for page linking |
| `menu_sections(sections : Array[(String, Array[String])], selected, icons?, foldable?=true, width?=180.0, class?, handle?)` | Grouped side menu: group header + items; `foldable=true` collapses/expands a group on the header |
| `segmented(options : Array[String], selected : Store[String], class?, handle?)` | Segmented control: selected = panel background + accent text; each segment joins the Tab chain, Space/Enter select, arrows move segments |
| `breadcrumb(items : Array[String], selected : Store[String], class?, handle?)` | Breadcrumb: `/` between levels; **the current item is decided by `selected`** (not position, otherwise the last item would never be clickable) |
| `pagination(current : Store[Int], pages : Int, class?, handle?)` | Pagination `‹ 1 2 … ›`: `current` starts at 1, out-of-range arrows clamp to first/last |
| `steps(items : Array[String], current : Store[Int], class?, handle?)` | Steps: number squares (done/current/todo) + text + connector; `current` is a 0-based index |
| `collapse(panels : Array[(String, Array[Node])], class?, handle?)` | Collapse: click a header to toggle content, panels independent, only the first expanded by default |
| `tree(root : Array[TreeNode], class?, handle?)` | Tree: per-level indent, click a row with children to expand/collapse |
| `tabs(pages : Array[(String, Node)], selected? : Store[Int], class?, handle?)` | Tabs: header row (accent text + bottom indicator) + prebuilt content switched by visibility; `selected` is 0-based, created internally if omitted |
| `transfer(left_items : Store[Array[String]], right_items : Store[Array[String]], width?=200.0, height?=160.0, item_height?=24.0, class?, handle?)` | Transfer: two columns + a middle `›`/`‹`; each column is driven by its own `Store` |

## Tables & virtual lists

| Constructor | Purpose |
|---|---|
| `table(columns : Array[TableColumn], rows : Store[Array[TableRow]], width?=560.0, row_height?=36.0, selection?, sort?, on_row_click?, class?, handle?)` | Table: header sorting (a click toggles a `TableSort`; the sort itself is the caller's job), zebra stripes, hover, row selection; column edges drag to resize |
| `table_v(columns, rows : Store[Array[TableRow]], width?=560.0, height?=360.0, row_height?=32.0, selection?, sort?, on_row_click?, class?, handle?)` | Virtual table (10k+ rows): fixed header + mounts only the visible range, sharing the header/row widgets with `table` |
| `virt_list(items : Store[Array[T]], height : Double, row_height : Double, row_of : (Int, T) -> Node, width?, overscan?=2, rev?, class?, handle?)` | Virtual list: `row_of(i, item)` builds row i (`i` is the source index; ordering from sort/filter is the caller's choice) |
| `sticky_list(groups : Array[(String, Array[Node])], st : StickyList, width?, height?, head_h?=28.0, class?, handle?)` | Sticky list: group headers pin to the top on scroll ("current group" inferred per frame from layout rectangles) |

> `TableColumn::make(...)` and `TableRow::make(cells : Array[String])` build columns and rows; `sort_rows(rows, sort)` (`ui/table.mbt`) offers a number-first, stable sort as a reference.

## Overlays & messages

Overlays (dialog / popover / menu / tooltip) all open on the window's **overlay layer**, so they naturally sit above content and other overlays with no permanently-hidden tree.

| Constructor | Purpose |
|---|---|
| `dialog(visible : Store[Bool], title, children, confirm_text?="确定", cancel_text?="取消", on_confirm?, on_cancel?, close_on_mask?=false, …)` | Dialog: `visible` drives open/close; title bar (+✕) + content + footer buttons (empty label hides a button); all three exits close first, then call back |
| `message_box(visible : Store[Bool], title, content, kind?=Information, informative?, buttons?=[("确定",1)], on_response?, on_dismiss?, close_on_mask?=false, width?)` | Self-drawn message box (coexists with the native one): `buttons` are `(label, code)`, the first is the primary default (Enter = first button; ✕/Esc/mask click go through `on_dismiss` with no code); response codes are chosen by the caller |
| `popover(trigger : Node, content : Node, width?, height?, class?, handle?)` | Popover: click `trigger` to drop arbitrary content below it, click again to close; `width/height` 0 size to content |
| `tooltip(content : Node, tip : String, delay_ms?=500, class?, handle?)` | Tooltip: after a `delay_ms` hover it opens one layer below and closes on leave (via the host's `on_hover_change`, a parent-chain semantics) |
| `context_menu_for(content : Node, items : Array[(String, () -> Unit)], width?=150.0, handle?)` | Right-click context menu: in `items` the label `"-"` draws a separator; right-click dispatch is "ancestor-first" |

## Date & time

Value model (`ui/datetime.mbt`): `DateYMD{y,m,d}`, `TimeHM{h,m}`, `DateRange`, `TimeRange`, `DateTimeRange`, with the pure functions `month_grid`/`month_shift`/`days_in_month`/`date_weekday`/`range_state_of`.

| Constructor | Purpose |
|---|---|
| `calendar(on_pick? : (DateYMD) -> Unit, …)` | Inline month calendar: ‹/› to change month, click a day |
| `date_picker(value : Store[DateYMD?], on_change?, …)` | Date picker: field + month-calendar popup, echo `YYYY-MM-DD` on pick |
| `date_range_picker(value : Store[DateRange], on_change?, …)` | Date-range picker |
| `time_range_picker(value : Store[TimeRange], on_change?, …)` | Time-range picker (stepper form, not `input`) |
| `datetime_range_picker(value : Store[DateTimeRange], on_change?, …)` | Date-time range picker |

> "Today" goes through `wm_local_date` → `@core.local_ymd()` (system calendar time; the monotonic `now_ms` clock can't derive a date).

## Reactive control

| Constructor | Purpose |
|---|---|
| `when(cond : Signal[T], then : Node, pred?)` | Signal show/hide: true mounts `then`, false hides it (not destroyed, state kept); `when_bool` is the common boolean form |
| `when_else(cond, then, otherwise, pred?)` | Both branches prebuilt, switch visibility by signal (`swap_node`, zero rebuild); `when_else_bool` is the boolean form |
| `when_store` / `when_store_bool` / `when_else_store` / `when_else_store_bool` | The `Store[T]` forms of the above |
| `for_list(ls : @core.ListStore[T], build : (T, Int) -> Node, key~, eq?)` | Keyed list diff: `build(item, index)` builds a row; default criterion "same key, same value" (mutable fields become their own Store) |
| `for_list_indexed(ls, build)` | Index-aligned (equivalent to no `:key`): shrinks only unload extra rows |

> Rebuilding the whole tree goes through `bind_node`; `ListStore` keyed diffing is part of the `@core` reactive layer (see [declarative.md](declarative.md)).

## Drag & drop (in-app, identical across three platforms)

| Constructor | Purpose |
|---|---|
| `drag_source(content : Node, payload? : () -> DragData?, threshold?=4.0, external?=false, on_external?)` | Drag source: after pressing on `content` and dragging `threshold` pixels, calls `payload()` to start; `external=true` first tries a system-level drag-out (Windows/Linux wired), auto-falling back to an in-app session if it can't |
| `drop_target(content : Node, on_drop? : (DragData, Double, Double) -> Unit, accept? : (DragData) -> Bool)` | Drop target: highlights with the accent on hover, on release `accept` (default accepts all) decides and, if accepted, calls `on_drop` |

> Don't put a button inside a drag source (pointer events go deepest-first, so the interactive widget eats the press). `payload()` is lazy; under threshold it's a normal click. `DragData` = `Text`/`Html`/`Paths`/`Img` (`@core`). Cross-application drag & drop is in adaptation.md per platform batch.

## Hover & cursor groups

| Constructor | Purpose |
|---|---|
| `hover_group(children, on_click?, …)` | Hover group: hovering anywhere inside (including all children) puts the whole group into the hover state and swaps the background; a click fires `on_click` (this stack's hover state is already parent-chain semantics, so no pointer polling) |
| `cursor_group(children, direction?, row_gap?, column_gap?, padding?, width?, cursor?=CURSOR_HAND, handle?)` | Cursor group: any position inside uses the `cursor` shape; a child that requests its own shape wins, the rest fall back to the group's |

## Declarative mounting

| Constructor | Purpose |
|---|---|
| `mount_window(children : Array[Node], title?="", width?=800, height?=600, handle? : (App) -> Unit)` | Describe a tree and mount it into a window: build the host (window + event loop + overlay layer + IME channel) → mount → hand the host back for `run`. Returns `None` with no display service. This stack does not offer `center`/`on_close` (centering is the WM's, closing stops the host loop; cleanup goes after `run()`) |
| `mount_window_render(render : () -> Array[Node], title?, width?, height?, handle?)` | render-slot form (an alternative to a static node array): `render` is called once at mount to build the first frame; thereafter reactivity relies entirely on the tree's `for_list`/`when`/`*_dyn` self-subscribing, self-diffing |

## Documentation index

- Tutorial and first window: [tutorial.md](tutorial.md)
- Declarative tree / `Store` / `Signal`: [declarative.md](declarative.md)
- Layout styling (`Style` fields and the `class` channel): [layout.md](layout.md)
- System capabilities (`@sys`): [system-capabilities.md](system-capabilities.md)
- Field-tested platform pitfalls: [adaptation.md](adaptation.md)
