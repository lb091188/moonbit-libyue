# UI Component Library (`yue/components.mbt`)

Element-Plus-style, theme-unified non-form components built in pure MoonBit on top of the declarative layer — zero platform code. Together with the themed controls (`label_t` / `button_t` / `entry_t`) they form the recommended way to build modern desktop app shells (sidebar navigation + top bar + scrolling content), as seen in `examples/components`.

**Theme**: all colors come from the `theme_*` palette — a deep, low-saturation scheme (not Element Plus defaults): blue `#2D68C4`, green `#2E9E5B`, orange `#D9822B`, red `#D64550`, plus greys for text/border/fill. Components render straight corners, use background colors for hover/active states, and center text vertically.

### Customizing the theme

Call `theme_apply` after `initialize()` and before mounting the UI. Colors are read at draw/mount time, so self-drawn interactive components pick up the new palette on repaint; colors fixed at mount (static label text, borders) need a rebuilt UI. A full snapshot can be read back with `theme_current`.

```moonbit
@yue.initialize()
let t = @yue.default_theme()
@yue.theme_apply({ ..t, primary: "#1E4FA3", primary_light: "#E3EDFA" })
```

## Themed controls

| API | Variants / roles | Notes |
|---|---|---|
| `button_t(text, on_click?, variant?)` | `Solid` / `Soft` / `Text` / `Danger` | self-drawn, hover stays within the theme (Solid/Danger darken, Soft goes solid white, Text grey fill) |
| `label_t(text, role?)` | `Title` / `Section` / `Body` / `Secondary` / `Accent` | font size+color by role |
| `entry_t(text?, password?, on_input?)` | normal / password | font themed only (GTK Entry `SetColor` paints the whole input dark — see adaptation.md) |
| `input_t(text?, password?, margin?, width?, height?)` | bordered / password | outer self-drawn 1px border (focus turns primary), inner Entry stripped of native border & inner shadow via `set_borderless` |
| `checkbox_t(title, checked?, disabled?, on_change?)` | normal / disabled | self-drawn square check + white tick, border turns primary on hover |
| `autocomplete(options, value : Store[String], width?)` | plain filtering | live-filtered candidates in a floating layer (never pushes content): native Popover on Linux, borderless topmost mini-window on Windows; picking a row writes the Store, blur/empty input collapses it |
| `date_picker_t(label, on_change?)` | date | inline label + native date picker; explicit width applied inside (Windows themes size to content minimum) |

## Navigation

| API | States covered |
|---|---|
| `side_menu(items, selected, width?)` | hover grey, selected light-blue + accent bar; syncs pages via `set_visible` |
| `segmented(options, selected)` | selected white + primary text, hover grey |
| `breadcrumb(items, selected)` | current dark, others clickable with hover accent |
| `pagination(current : Store[Int], pages)` | current page solid primary, hover light-blue; ‹ › clamped |
| `steps(items, current : Store[Int])` | done / active / todo three states with connector lines |

## Data display

| API | Notes |
|---|---|
| `tag(text, color)` / `tag_of_type(text, t)` | auto width; five semantic types |
| `avatar(letter, color, size?)` | square, white letter centered |
| `badge_count(n)` / `badge_dot(color?)` | number chip / dot |
| `statistic(title, value : Store[String])` | reactive big number |
| `progress_line(value : Store[Double], height?)` | themed fill on a light track, reactive value |
| `descriptions(pairs)` | key–value grid |
| `timeline(items)` | colored node + connector, semantic colors |
| `collapse(panels)` | click title to expand/collapse, independent panels |
| `card(title, children, height?)` | header bar + separator + border |
| `code_view(lines, font_size?, width?)` | syntax highlighting; one `AttributedText` per token (whole-range coloring), measured and drawn manually — consistent on all platforms, bypassing the Windows range-attribute deficiency |
| `table_t(columns, rows : Store[Array[TableRow]], width?, row_height?, selection?, on_row_click?)` | table: header + zebra stripes + hover highlight; columns via `TableColumn::make(title, width, align?)` (width ≤ 0 = flexible), full rebuild on Store set. Cells are `TableCell`: `CellText` / `CellTag(text, semantic type)` / `CellColorBox(hex, name)` / `CellLines(multi-line, row auto-grows)`; `TableRow::make(string array)` for plain rows. Without `selection` rows single-select on click; pass `selection : Store[Array[Int]]` for a checkbox column (row click toggles, header select-all/clear, dash when partial). Callback receives `(index, row)` |

## Feedback

| API | States covered |
|---|---|
| `alert(text, t, height?)` | Success / Info / Warning / Danger banners |
| `alert_closeable(text, t)` | with ✕ to dismiss |
| `result(t, title, desc, children)` | big symbol + title + description + action area |
| `empty(desc)` | placeholder block + caption |
| `switch_t(checked : Store[Bool], disabled?)` | on / off / disabled |
| `radio_group(options, selected, disabled?)` | mutually exclusive selection |

## Demo

`moon run examples/components` — four-page showcase with every component and state:

![Basic](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/components-basic.png)

![Navigation](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/components-nav.png)

![Data display](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/components-data.png)

![Feedback](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/components-feedback.png)

State coordination across components goes through `Store` (subscribe / map / bind_label); see [docs/declarative.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/declarative.md). Chinese version: [docs/zh/components-ui.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/components-ui.md).
