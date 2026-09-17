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
| `date_picker_t(value? : Store[DateYMD?], on_change?, width?, placeholder?)` | date picker (EP style, fully self-drawn): input-style field; clicking opens the `calendar_t` month panel in a popover, ‹/› switch months, pick to fill and close, blur closes |
| `textarea_t(text?, width?, height?, margin?, on_input?)` | multi-line input: self-drawn border (focus turns theme primary) + 8px inset, inner TextEdit with native border removed; overflow scrolls per platform |
| `divider(vertical?, spacing?)` | divider line: horizontal (default) or vertical, 1px theme border color, spacing on both sides |
| `slider_t(value : Store[Double], min?, max?, step?, width?, on_change?)` | self-drawn slider: light track + themed fill + square thumb, click/drag to set (step-quantized), external Store set also applies |
| `tabs_t(pages : Array[(String, Node)], selected?)` | top tabs: active tab themed text + 2px bottom indicator, content switched via set_visible; `selected` is an index Store (internal 0 by default) |
| `select_t(options, value : Store[String], width?, on_change?)` | dropdown select (EP style, fully self-drawn): read-only field + popover option list (hover highlight / ✓ on current), pick to fill, blur to close; use autocomplete for long lists (no in-popover scrolling) |
| `rate_t(value : Store[Int], max?, on_change?)` | star rating (self-drawn): filled theme color when on, outlined gray when off, hover preview, click sets stars |
| `tooltip_t(content : Node, tip)` | wrap any node with the native tooltip (system style; use popover_t for themed bubbles) |
| `popover_t(trigger : Node, content : Node, width, height)` | popover bubble: clicking the trigger opens arbitrary Node content below it, click again to close |
| `dropdown_menu(trigger, items, on_select, width?)` | dropdown menu: trigger field + item popover, hover highlight, click calls back the index; `"-"` in items draws a separator |
| `carousel_t(pages : Array[Node], width?, height?, interval_ms?)` | carousel: panel sequence + side arrows + bottom dots, auto-advance every interval_ms ms (hover pauses, enabled when > 0), arrows/dots switch manually |
| `color_picker_t(value : Store[String], colors?)` | color picker (preset swatch form): swatch grid, click to pick, theme outline + white check on current, hex shown below; custom palette supported |
| `calendar_t(on_pick?, value? : Store[DateYMD?])` | self-drawn month panel: ‹/› month nav + weekday row + 42-cell grid, adjacent-month days dimmed, "today" in theme primary, selected day as solid square; `DateYMD::format()` renders `YYYY-MM-DD` |

## Navigation

| API | States covered |
|---|---|
| `side_menu(items, selected, width?)` | hover grey, selected light-blue + accent bar; syncs pages via `set_visible` |
| `side_menu_sections(sections : Array[(String, Array[String])], selected, width?)` | grouped side menu: group captions (secondary small text, not clickable) + items (same rendering/selection as side_menu) |
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
| `table_v_t(columns, rows : Store[Array[TableRow]], width?, height?, row_height?, selection?, on_row_click?)` | virtualized table (10k+ rows): whole surface canvas-drawn, only visible rows painted, self-managed scrolling (wheel / drag scrollbar / keyboard); same cell types and selection semantics as `table_t` (CellLines clamps to two lines per fixed row height) |

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
