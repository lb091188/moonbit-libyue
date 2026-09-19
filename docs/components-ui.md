# UI Component Library (`yue/components.mbt`)

Element-Plus-style, theme-unified non-form components built in pure MoonBit on top of the declarative layer — zero platform code. Together with the themed controls (`label_t` / `button_t` / `entry_t`) they form the recommended way to build modern desktop app shells (sidebar navigation + top bar + scrolling content), as seen in `examples/components`.

**Theme**: all colors come from the `theme_*` palette — a deep, low-saturation scheme (not Element Plus defaults): blue `#2D68C4`, green `#2E9E5B`, orange `#D9822B`, red `#D64550`, plus greys for text/border/fill. Components render straight corners, use background colors for hover/active states, and center text vertically.

### Customizing the theme / dark mode

Call `theme_apply` at any time after `initialize()` (built-in palettes: `default_theme` light / `dark_theme` dark). Switching takes effect immediately without rebuilding the UI: self-drawn components repaint via theme subscriptions, colors fixed at mount (container backgrounds, label text colors) are re-applied internally, the Linux native-control CSS (entries/text views/scrollbars/window & popover backgrounds) is rebuilt, and every visible window gets a full repaint as a safety net. To follow the system dark mode: `system_prefers_dark()` reads the system preference and `on_system_theme_change(f)` fires when it changes (both currently implemented on Linux only) — pick the initial theme from the system preference and re-apply inside the callback. Focus rings and focused field borders use a neutral grey single stroke (not the theme color) to stay unobtrusive.

**Colors are fully internalized — zero burden on consumers**: every component in the library (including the plain `label()`, which defaults to the theme's regular text color) follows the theme out of the box. Custom components hook in via three rules, with the platform pitfalls already encapsulated:

| Case | How |
|---|---|
| Self-drawn (on_draw) | Read colors from `theme_current()` inside the draw callback — no subscription needed (theme switches force a full repaint) |
| Label text with theme color | `theme_bind_fg(l, fn() { theme_current().text_regular })` — handles the "must re-set text after set_color" platform pitfall internally; bare `set_color` won't follow the theme, and hand-rolled subscriptions without the re-set leave stale colors |
| Container background with theme color | `theme_bind_bg(v, fn() { theme_current().bg_panel })` — fixed backgrounds don't update on repaint, they must be re-set |

Fixed colors (brand swatches etc.) can be set directly and stay theme-independent.

```moonbit
@yue.initialize()
let t = @yue.default_theme()
@yue.theme_apply({ ..t, primary: "#1E4FA3", primary_light: "#E3EDFA" })
```

## Themed controls

| API | Variants / roles | Notes |
|---|---|---|
| `button_t(text, on_click?, variant?)` | `Solid` / `Soft` / `Text` / `Danger` | self-drawn, hover stays within the theme (Solid/Danger darken, Soft goes solid white, Text grey fill) |
| `label_t(text, role?, style?, style_str?, handle?)` | `Title` / `Section` / `Body` / `Secondary` / `Accent` | font size+color by role, left-aligned, accepts layout styles and a handle callback |
| `entry_t(text?, password?, on_input?)` | normal / password | font themed only (GTK Entry `SetColor` paints the whole input dark — see adaptation.md) |
| `input_t(text?, password?, margin?, width?, height?, clearable?, on_input?, invalid?)` | bordered / password / clearable / invalid red border | outer self-drawn 1px border (focus turns primary), inner Entry stripped of native border & inner shadow via `set_borderless`; clearable=true shows ✕ on hover when non-empty, click to clear; on_input text-change callback; pass a Store[Bool] as invalid to turn the border danger red (light form validation) |
| `checkbox_t(title, checked?, disabled?, on_change?)` | normal / disabled | self-drawn square check + white tick, border turns primary on hover |
| `date_picker_t(value? : Store[DateYMD?], on_change?, width?, placeholder?, clearable?)` | date picker (EP style, fully self-drawn): input-style field; clicking opens the `calendar_t` month panel in a popover, ‹/› switch months, pick to fill and close, blur closes; clearable=true shows ✕ beside the arrow on hover when a value is set, click to clear (no on_change) |
| `textarea_t(text?, width?, height?, margin?, on_input?, clearable?, invalid?)` | multi-line input: self-drawn border (focus turns theme primary) + 8px inset, inner TextEdit with native border removed; overflow scrolls per platform; clearable=true shows ✕ on hover when non-empty, click to clear (on_input receives ""); invalid adds the validation red border like input_t |
| `divider(vertical?, spacing?)` | divider line: horizontal (default) or vertical, 1px theme border color, spacing on both sides |
| `icon(kind, size?, color?)` | built-in vector icon: 37 kinds (arrows/editing/media/status, `all_icons()` for the full list, `icon_name()` for the name), theme regular color by default, fixed color via color; `draw_icon(p, kind, cx, cy, s, color)` is the unified self-drawing entry |
| `icon_button_t(kind, on_click?, size?, tip?)` | square icon button: hover grey fill + text brightening, Enter/Space activates; non-empty tip attaches a native tooltip; marginRight 6 for toolbar rows |
| `slider_t(value : Store[Double], min?, max?, step?, width?, on_change?)` | self-drawn slider: light track + themed fill + square thumb, click/drag to set (step-quantized), external Store set also applies |
| `tabs_t(pages : Array[(String, Node)], selected?)` | top tabs: active tab themed text + 2px bottom indicator, content switched via set_visible; `selected` is an index Store (internal 0 by default) |
| `select_t(options, value : Store[String], width?, on_change?, clearable?)` | dropdown select (EP style, fully self-drawn): click to open the candidate list, hover highlight, ✓ on the current pick, click to fill and close; clearable=true shows ✕ beside the arrow on hover when a value is set, click to clear (value set to "", on_change("")); same behavior on all platforms |
| `rate_t(value : Store[Int], max?, on_change?)` | star rating (self-drawn): filled theme color when on, outlined gray when off, hover preview, click sets stars |
| `tooltip_t(content : Node, tip)` | wrap any node with the native tooltip; on Linux the tooltip color is pinned to dark background + white text (independent of the system theme), other platforms keep the system style |
| `popover_t(trigger : Node, content : Node, width, height)` | popover bubble: clicking the trigger opens arbitrary Node content below it, click again to close |
| `dropdown_menu(trigger, items, on_select, width?)` | dropdown menu: trigger field + item popover, hover highlight, click calls back the index; `"-"` in items draws a separator |
| `carousel_t(pages : Array[Node], width?, height?, interval_ms?)` | carousel: panel sequence + side arrows + bottom dots, auto-advance every interval_ms ms (hover pauses, enabled when > 0), arrows/dots switch manually |
| `color_picker_t(value : Store[String], colors?, width?)` | color picker (dropdown form): trigger field (current swatch + hex) opens the preset palette popover; theme outline + white check on current, click to fill; custom palette supported |
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
| `hsplit(first, second, ratio?, min_first?, min_second?)` / `vsplit(...)` | draggable split layout (Qt QSplitter / GTK Paned counterpart): 8px self-drawn handle with an always-visible divider line + dots (no need to hunt for it), grey fill on hover, theme color + white dots while dragging, mouse capture keeps events outside the handle; ratio is the initial share, min clamps both panes |

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
| `dialog_t(visible : Store[Bool], title, children, width?, confirm_text?, cancel_text?, on_confirm?, on_cancel?, close_on_mask?)` | in-app dialog: same-window mask (semi-transparent black, absolute relative to the mount container — mounted at the window root it covers the whole window) + centered panel (title bar with ✕ + body + right-aligned buttons); ✕/cancel/confirm auto-close after the callback; empty text hides the button; visually modal, not keyboard-modal |
| `toast_layer(duration_ms?) -> (Node, (String, SemanticType) -> Unit)` | light toast: mount the layer node at the window root (absolute top strip, no layout space), the push function shows a semantic toast bar (panel bg + border + type icon), auto-removed after 2.6s by default, multiple bars stack top-down; call after the layer is mounted |
| `context_menu_for(content, items : Array[(String, () -> Unit)])` | context menu: wrap any node with a native right-click menu, label "-" draws a separator; popup position converted to screen coordinates via bounds_in_screen, the menu is rebuilt on each right-click |
| `radio_group(options, selected, disabled?)` | mutually exclusive selection |

## Demo

`moon run examples/components` — ten-page showcase (Basic / Form / Navigation / Data Display / Feedback + Native Widgets / Canvas & Rich Text + System Integration / Window & Web / Environment) covering the component library and all libyue capabilities:

![Basic](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/components-basic.png)

![Navigation](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/components-nav.png)

![Data display](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/components-data.png)

![Feedback](https://github.com/lb091188/moonbit-libyue/raw/master/docs/images/components-feedback.png)

**Native & drawing**: the "Native Widgets" page (Entry/Slider/ProgressBar/Checkbox/Radio/ComboBox/Picker/DatePicker/TextEdit/GifPlayer/Popover) and "Canvas & Rich Text" page (container self-drawing + Painter primitives/blend modes/PNG, AttributedText range styling).
**System capabilities**: the "System Integration" page (file dialogs / message boxes / system notifications / clipboard / timers) and "Window & Web" page (window APIs / global shortcuts / drag in & out / native context menu / embedded WebView + custom protocol) wrap libyue system pieces in the modern theme; the menu bar and system tray are attached at demo startup. Full-capability default-theme demos live in `examples/showcase`.

State coordination across components goes through `Store` (subscribe / map / bind_label); see [docs/declarative.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/declarative.md). Chinese version: [docs/zh/components-ui.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/components-ui.md).
