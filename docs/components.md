# Component reference (@ui)

Every self-drawn widget and the component library live in `NoahLiu/native-gui/ui` (alias `@ui`). Each component is a **constructor returning `@widget.Node`** — you describe the interface as a node tree and mount it once with `@ui.mount_window([...])`. This page lists each family's entry signatures and purposes as a quick reference; parameters always follow the code (`gui/ui/*.mbt`).

> Runnable examples for every component are gathered in `examples/showcase` — a 14-page demo board, one source file per page, the fastest way in.

## Conventions (read this first)

**Typed parameters + a `class` style channel.** Components take typed parameters only — size, colour, value — not CSS string tables. Overriding the look goes two ways: loose parameters (`font_size` / `background_color` and friends), or `class? : Array[@style.Style]` layering `Style` value blocks, where the last `class` in the array wins. The full style layer is in [design.md (Chinese)](/zh/design).

**State lives in `Store`, no glue code.** The current value of a value control (checkbox / radio / switch / slider / input / progress …) is held by an `@base.Store[T]`: the component reads and writes it, and an external change refreshes the component. Display components come through two entries — `x` takes a value, `x_dyn` takes a `Signal[T]` — sharing one drawing path.

**Events are always `on_*`.** Callbacks are named `on_click` / `on_change` / `on_drop` …; `handle?` is an escape hatch — take back the internal `@widget.Widget` handle for operations the framework does not expose — not an event.

**Keyboard accessibility is built in.** Form-family controls (button / checkbox / radio / switch / stepper / slider / rate / select / color picker / date-time / segmented) claim a focus id by default and join the Tab chain; the focus border turns the theme accent. Space/Enter activate, arrow keys adjust the value or move the selection per control semantics.

**`TextRole`:** `Plain` carries no role and uses explicit size/weight; `Title` · `Section` · `Accent` use SemiBold at theme font sizes; `Body` · `Secondary`.

**`SemanticType`:** `Primary` · `Success` · `Warning` · `Danger` · `Info`. Values are stored as theme token names and resolved live on theme switch, never frozen as snapshots.

---

## Layout & containers

| Constructor | Purpose |
|---|---|
| `view(children, direction?=Column, row_gap?, column_gap?, padding?, width?, height?, grow?, background_color?, border_color?, align_items?, justify_content?, class?, handle?)` | Generic container: direction, gaps on both axes, padding, size, background and border. Size 0 fits the content; `grow=1.0` fills the remaining space |
| `col(children, row_gap?, padding?, width?, height?, grow?, background_color?, border_color?, align_items?, class?, handle?)` | Vertical layout container (the Column form of `view`) |
| `row(children, column_gap?, padding?, width?, height?, grow?, background_color?, border_color?, align_items?=Center, class?, handle?)` | Horizontal layout container (the Row form of `view`) |
| `panel(title, children, padding?=10.0, row_gap?=6.0, width?)` | Titled panel: title on top, content below, panel background + border |
| `split(first, second, direction?=Horizontal, ratio?=0.5, min_first?, min_second?, class?, handle?)` | Draggable split pane; unifies `hsplit`/`vsplit` with the direction parameterized |
| `scroll_view(children, state : ScrollState, width?, height?, class?, handle?)` | Vertical scroll container; `height` is the viewport height, 0 means the parent supplies it; overflow is clipped, the scrollbar is drawn on the right edge |

> Scroll offset shifts at paint time and stays out of layout; `ScrollState` is provided by `ui/scroll.mbt`.

## Text & primitives

| Constructor | Purpose |
|---|---|
| `text(content, role?=Plain, font_size?=13.0, color?, weight?, family?, align?, max_width?, wrap?, ellipsis?, class?, handle?)` | Text, unifying `label` + `label_t`: with a `role` it takes the role's font size, weight and theme colour; size comes from Pango measurement and feeds the layout engine, so text participates in baseline alignment |
| `text_dyn(sig : Signal[String], role?, font_size?, color?, …, class?, handle?)` | Signal-driven text: on change it edits the text in place and recomputes only this chain; the counterpart of the old `bind_label` and the prototype of the display `*_dyn` family |
| `bind_label(store : Store[A], f : (A) -> String, font_size?, color?, handle?)` | Declarative text binding: initial value `f(store.get())`, then every `set` updates the text in place and re-measures; always single-line |
| `bind(sig : Signal[A], f : (A) -> String, font_size?, color?, handle?)` | Text binding in signal form: takes a source signal or a `computed` derived signal directly |
| `divider(text?, vertical?=false, color?, class?)` | Divider, unifying `separator` + the labelled `divider`: empty `text` draws a plain line (`vertical` picks horizontal/vertical), with text it draws a centered breaking line |
| `image(path, width?, height?, handle?)` | Image: decodes a file (PNG/JPEG/GIF first frame); size 0 uses the original dimensions |
| `icon(kind : @icons.IconKind, size?=16.0, color?, class?, handle?)` | Vector icon: `size` is the box edge; empty colour means the theme body text colour, resolved live with the theme |
| `code_view(lines : Array[String], lang?="moonbit", font_size?=13.0, line_numbers?=false, handle?)` | Code highlight view on a One Dark background, deliberately not theme-following: 8-language keyword tables + token coloring, optional line-number column, size fits the content |
| `gif(path, width?, height?, looping?=true, running?=true, state?, handle?)` | Animated image: `looping=false` stops after one pass; a non-GIF still image draws a single frame |

## Form controls

Value controls hold their current value in a `Store[T]`: an external change refreshes the control, an interaction writes back.

| Constructor | Purpose |
|---|---|
| `button(text, on_click?, variant?=Soft, color?, background_color?, font_size?, min_width?, focus_id?, disabled?, enabled?, class?, handle?)` | Button, `variant : ButtonVariant` = `Solid`/`Soft`/`Border`/`Text`/`Danger`; Space/Enter activate from the keyboard |
| `input(store : Store[String], placeholder?, password?=false, read_only?=false, font_size?, family?, width?, focus_id?, caret_on?, …)` | Single-line input: selection / double-click word select / undo-redo / Ctrl+A-C-V / placeholder / read-only / password mask / inline IME, all with full semantics; `clearable` shows a ✕ on hover/focus and clicking it clears |
| `textarea(store : Store[String], placeholder?, rows?=3, width?=260.0, height?, font_size?, family?, read_only?, focus_id?, caret_on?, …)` | Multi-line input: greedy wrapping (spaces / Latin words / CJK per character) + vertical scroll; up/down keys move across display lines |
| `checkbox(content, state : Store[Bool], disabled?, enabled?, focus_id?, font_size?, class?, handle?)` | Checkbox + text label; the whole row is the click area; Space/Enter toggle |
| `radio_group(options : Array[String], state : Store[Int], disabled?, direction?=Row, gap?=12.0, class?)` | Radio group: `options` map to values 0..n-1 in order; Space/Enter select the current item, arrow keys move the selection and wrap around |
| `switch(state : Store[Bool], on_text?, off_text?, disabled?, focus_id?, class?)` | Switch: a 40×20 pill + 16 round knob, with optional on/off labels; Space/Enter toggle |
| `slider(state : Store[Double], min?=0.0, max?=100.0, step?=0.0, width?=160.0, disabled?, focus_id?, class?, handle?)` | Slider: a press takes the value, dragging follows the pointer, `step>0` snaps; arrow keys step, Home/End jump to the ends |
| `stepper(state : Store[Int], min?=0, max?=999, step?=1, focus_id?, class?)` | Number stepper `[-] 值 [+]`: a single boxed three-segment control, and the button at the reached bound disables itself; arrow keys increment/decrement |
| `select(options : Array[String], value : Store[String], on_change?, …)` | Dropdown, the single entry — the editable form goes through `editable=true`: the popup opens on the overlay layer, ↑↓ highlight + Enter picks + Esc closes |
| `color_picker(value : Store[String], colors?=[内置 15 色], on_change?, …)` | Color picker: field + swatch grid; Enter opens, ←/→ move a cell, ↑/↓ move a row, Enter picks |
| `rate(value : Store[Int], max?=5, on_change?, …)` | Rating: vector five-point stars + hover pre-lighting; arrow keys change stars, Home/End clear or max out |
| `form_item(label_text, control : Node, label_width?=90.0, error?=Store[String], handle?)` | Form item: fixed-width right-aligned label + control; a permanent error row below, its line height always reserved so errors never jump the layout |
| `form(title, items : Array[Node], row_gap?=8.0, handle?)` | Form: group title + a column of form items |
| `link(text, on_click : () -> Unit, font_size?, class?, handle?)` | Link text: theme colour, underline on hover, fires on release |

## Data display

The display family also has `*_dyn` signal forms: `text` becomes a `Signal`, the label is edited in place and the width recomputed, and unsubscribing rides the unsubscribe bundle.

| Constructor | Purpose |
|---|---|
| `tag_of_type(text, t : SemanticType, font_size?=12.0, class?)` | Semantic-colour tag: light background + accent text; `tag_of_type_dyn` takes a signal |
| `tag(text, color, font_size?=12.0, class?)` | Custom-colour tag: solid background + white text; `tag_dyn` takes a signal |
| `badge_count(value : Int, max?=99, color?, class?)` | Number badge: over `max` it shows "max+"; `badge_count_dyn` takes a `Signal[Int]` |
| `badge_dot(size?=8.0, color?, class?)` | Dot badge: no number, it just signals "something new" |
| `avatar(text, size?=32.0, background_color?, class?)` | Avatar: centers the first character of the text; `avatar_dyn` takes a signal |
| `statistic(title, value, precision_color?, prefix?, class?)` | Statistic: small title + value, with optional prefix/suffix; `statistic_dyn` takes a `Signal[String]` |
| `card(children, title?, padding?=12.0, row_gap?=6.0, class?)` | Card: optional title bar + content area, panel background + border |
| `descriptions(items : Array[(String, String)], title?, label_width?=96.0, class?)` | Description list: `(label, value)` pairs, one row each |
| `empty(description?="暂无数据", class?)` | Empty state: icon + description, centered |
| `result(title, subtitle?, t?=Success, class?)` | Result page: semantic icon + title + subtitle |
| `progress(state : Store[Double], max?=1.0, width?=200.0, height?=6.0, color?, class?, handle?)` | Progress bar: `state` runs 0..max, display-only |
| `progress_line(state, max?=1.0, width?=200.0, label_side?=true, class?)` | Progress with a percentage label |
| `timeline(items : Array[(String, String, SemanticType)], item_height?=56.0, gap?=12.0, class?)` | Timeline: `(title, description, semantic colour)` rows of equal height; the connector line spans row gaps without breaking |
| `carousel(pages : Array[Node], width?=360.0, height?=180.0, interval_ms?=3000, rotation?=CarouselHandle::make(), class?, handle?)` | Carousel: panel sequence + arrows + indicator dots; auto-advances when `interval_ms>0` and pages > 1, pauses on hover |

## Navigation

| Constructor | Purpose |
|---|---|
| `menu(items : Array[String], selected : Store[String], icons?, width?=180.0, class?, handle?)` | Side navigation menu: the selection gets a light theme background + a left accent bar; `selected` can be shared with the main area for page linking |
| `menu_sections(sections : Array[(String, Array[String])], selected, icons?, foldable?=true, width?=180.0, class?, handle?)` | Grouped side menu: group header row + items in the group; with `foldable=true` a header click collapses/expands the group |
| `segmented(options : Array[String], selected : Store[String], class?, handle?)` | Segmented control: the selected segment gets a panel background + accent text; every segment joins the Tab chain, Space/Enter select, arrow keys move segments |
| `breadcrumb(items : Array[String], selected : Store[String], class?, handle?)` | Breadcrumb: `/` between levels; **the current item is decided by `selected`**, not by position — otherwise the last item would never be clickable |
| `pagination(current : Store[Int], pages : Int, class?, handle?)` | Pagination `‹ 1 2 … ›`: `current` starts at 1; out-of-range arrows clamp to the first/last page |
| `steps(items : Array[String], current : Store[Int], class?, handle?)` | Steps: number squares (done/current/todo) + text + connector; `current` is a 0-based index |
| `collapse(panels : Array[(String, Array[Node])], class?, handle?)` | Collapse: clicking a header toggles its content; panels are independent, only the first is expanded by default |
| `tree(root : Array[TreeNode], class?, handle?)` | Tree: per-level indent; clicking a row with children expands/collapses it |
| `tabs(pages : Array[(String, Node)], selected? : Store[Int], class?, handle?)` | Tabs: the selected header gets accent text + a bottom indicator; content pages are prebuilt and switched by visibility; `selected` is 0-based and created internally when omitted |
| `transfer(left_items : Store[Array[String]], right_items : Store[Array[String]], width?=200.0, height?=160.0, item_height?=24.0, class?, handle?)` | Transfer: two columns + a middle `›`/`‹`; each column is driven by its own `Store` |

## Tables & virtual lists

| Constructor | Purpose |
|---|---|
| `table(columns : Array[TableColumn], rows : Store[Array[TableRow]], width?=560.0, row_height?=36.0, selection?, sort?, on_row_click?, class?, handle?)` | Table: header sorting — a click toggles a `TableSort` and the sort itself is the caller's job; zebra stripes, hover, row selection; column edges drag to resize |
| `table_v(columns, rows : Store[Array[TableRow]], width?=560.0, height?=360.0, row_height?=32.0, selection?, sort?, on_row_click?, class?, handle?)` | Virtual table at 10k+ rows: fixed header + only the visible range is mounted, sharing the header/row widgets with `table` |
| `virt_list(items : Store[Array[T]], height : Double, row_height : Double, row_of : (Int, T) -> Node, width?, overscan?=2, rev?, class?, handle?)` | Virtual list: `row_of(i, item)` builds row i; `i` is the source index, and sort/filter ordering stays the caller's choice |
| `sticky_list(groups : Array[(String, Array[Node])], st : StickyList, width?, height?, head_h?=28.0, class?, handle?)` | Sticky list: group headers pin to the top on scroll; the "current group" is inferred each frame from layout rectangles |

> `TableColumn::make(...)` and `TableRow::make(cells : Array[String])` build columns and rows; `sort_rows(rows, sort)` (`ui/table.mbt`) gives a number-first, stable sort as a reference.

## Overlays & messages

Overlays — dialog / popover / menu / tooltip — all open on the window-wide **overlay layer**, so they naturally sit above content and other overlays; no permanently hidden tree is needed.

| Constructor | Purpose |
|---|---|
| `dialog(visible : Store[Bool], title, children, confirm_text?="确定", cancel_text?="取消", on_confirm?, on_cancel?, close_on_mask?=false, …)` | Dialog: `visible` drives open/close; title bar with +✕ + content + footer buttons, and an empty label hides that button; all three exits close first, then call back |
| `message_box(visible : Store[Bool], title, content, kind?=Information, informative?, buttons?=[("确定",1)], on_response?, on_dismiss?, close_on_mask?=false, width?)` | Self-drawn message box, coexisting with the native form: `buttons` are `(label, code)` and the first is the primary default button; Enter = first button, while ✕/Esc/mask click go through `on_dismiss` without a code; response codes are chosen by the caller |
| `popover(trigger : Node, content : Node, width?, height?, class?, handle?)` | Popover: clicking the trigger drops arbitrary content below it, clicking again closes; `width/height` of 0 size to the content |
| `tooltip(content : Node, tip : String, delay_ms?=500, class?, handle?)` | Tooltip: after a `delay_ms` hover it opens a bubble below and closes on leave; it rides the host's `on_hover_change`, a parent-chain semantics |
| `context_menu_for(content : Node, items : Array[(String, () -> Unit)], width?=150.0, handle?)` | Right-click context menu: in `items` the label `"-"` draws a separator; right-click dispatch is "ancestor-first" |

## Date & time

Value model (`ui/datetime.mbt`): `DateYMD{y,m,d}`, `TimeHM{h,m}`, `DateRange`, `TimeRange`, `DateTimeRange`, with the pure functions `month_grid`/`month_shift`/`days_in_month`/`date_weekday`/`range_state_of`.

| Constructor | Purpose |
|---|---|
| `calendar(on_pick? : (DateYMD) -> Unit, …)` | Inline month calendar: ‹/› change the month, click picks a day |
| `date_picker(value : Store[DateYMD?], on_change?, …)` | Date picker: field + month-calendar popup; the pick echoes back as `YYYY-MM-DD` |
| `date_range_picker(value : Store[DateRange], on_change?, …)` | Date-range picker |
| `time_range_picker(value : Store[TimeRange], on_change?, …)` | Time-range picker: stepper form, not `input` |
| `datetime_range_picker(value : Store[DateTimeRange], on_change?, …)` | Date-time range picker |

> "Today" goes through `wm_local_date` → `@shell.local_ymd()` for system calendar time; the monotonic `now_ms` clock cannot derive a date.

## Reactive control

| Constructor | Purpose |
|---|---|
| `when(cond : Signal[T], then : Node, pred?)` | Signal show/hide: true mounts `then`, false hides it — nothing is destroyed, state survives; `when_bool` is the common boolean-source form |
| `when_else(cond, then, otherwise, pred?)` | Both branches stay resident and the signal switches visibility; `swap_node` lands the change with zero rebuilds; `when_else_bool` is the boolean-source form |
| `when_store` / `when_store_bool` / `when_else_store` / `when_else_store_bool` | The `Store[T]` forms of the above |
| `for_list(ls : @base.ListStore[T], build : (T, Int) -> Node, key~, eq?)` | Keyed list diff: `build(item, index)` builds each row; the default criterion is "same key, same value", so mutable fields become their own Store |
| `for_list_indexed(ls, build)` | Index-aligned, equivalent to no `:key`: extra rows unload only when the length shrinks |

> Replacing the whole tree goes through `bind_node`; `ListStore` keyed diffing belongs to the `@core` reactive layer (details in [declarative.md](declarative.md)).

## Drag & drop (in-app, identical across the three platforms)

| Constructor | Purpose |
|---|---|
| `drag_source(content : Node, payload? : () -> DragData?, threshold?=4.0, external?=false, on_external?)` | Drag source: after pressing on `content` and dragging `threshold` pixels, `payload()` is called to fetch the data and start the drag; `external=true` first tries a system-level drag-out (Windows/Linux wired), and falls back to an in-app session automatically if it fails |
| `drop_target(content : Node, on_drop? : (DragData, Double, Double) -> Unit, accept? : (DragData) -> Bool)` | Drop target: hover highlights with the theme accent; on release `accept` (defaults to accepting everything) decides, and an accepted drop calls `on_drop` |

> Don't put a button inside a drag source: pointer events go deepest-first, so the interactive widget eats the press. `payload()` is lazy — under the threshold the gesture stays a normal click. `DragData` = `Text`/`Html`/`Paths`/`Img` (`@core`). Cross-application system drag & drop is covered in the platform batches of adaptation.md.

## Hover & cursor groups

| Constructor | Purpose |
|---|---|
| `hover_group(children, on_click?, …)` | Hover group: hovering anywhere inside, including all children, puts the whole group into hover state and swaps its background; a click fires `on_click`; hover state in this stack is already parent-chain semantics, so no pointer polling is needed |
| `cursor_group(children, direction?, row_gap?, column_gap?, padding?, width?, cursor?=CURSOR_HAND, handle?)` | Cursor group: any position inside uses the `cursor` shape; a child that requests its own shape wins, the rest fall back to the group's shape |

## Declarative mounting

| Constructor | Purpose |
|---|---|
| `mount_window(children : Array[Node], title?="", width?=800, height?=600, handle? : (App) -> Unit)` | Describe a tree and mount it into a window: build the host (window + event loop + overlay layer + IME channel) → mount → hand it back for the caller's `run`. Returns `None` when no display service exists. This stack offers no `center`/`on_close` parameters: centering is left to the WM, closing stops the host loop, and cleanup goes after `run()` |
| `mount_window_render(render : () -> Array[Node], title?, width?, height?, handle?)` | The render-slot form, an alternative to a static node array: `render` is called once at mount to build the first frame; after that, all reactivity relies on the tree's `for_list`/`when`/`*_dyn` self-subscribing, self-diffing |

## Component library documentation index

- Tutorial and first window: [tutorial.md](tutorial.md)
- Declarative tree / `Store` / `Signal`: [declarative.md](declarative.md)
- Layout styling (`Style` fields and the `class` channel): [layout.md](layout.md)
- System capabilities (`@sys`): [system-capabilities.md](system-capabilities.md)
- Field-tested platform pitfalls: [adaptation.md](adaptation.md)
