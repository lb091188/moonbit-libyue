# Themed Component Library Quick Reference

Themed component library quick reference: a full set of Element-Plus-style UI components (buttons / input / selection / forms / navigation / layout / data display / icons / feedback / overlays). Every function is called via `@yue` and returns a `Node` that goes straight into the UI tree; all named parameters are optional. Reactive `Store` / `Signal` parameters are covered in [declarative.md](declarative.md); native controls (Window / Label / Button / Entry, etc.) are in [components.md](components.md).

Full demo: `examples/showcase`.

## Theme

All colors come from the theme palette — a deep, low-saturation scheme: blue `#2D68C4`, green `#2E9E5B`, orange `#D9822B`, red `#D64550`, plus greys for text / border / fill. Components render straight corners, use background colors for hover/active states, and center text vertically.

### Switching and customization

| API | Purpose |
|---|---|
| `default_theme()` / `dark_theme()` | built-in light / dark themes, return a `Theme` |
| `theme_current()` | read the current theme snapshot |
| `theme_apply(t)` | apply a theme: switching takes effect immediately, no UI rebuild needed (Linux native-control styling is rebuilt too) |
| `on_theme_change(f)` | subscribe to theme changes (registered at mount for re-applying colors fixed at mount) |
| `system_prefers_dark()` | read the system light/dark preference (currently implemented on Linux only) |
| `on_system_theme_change(f)` | fires when the system preference changes (currently implemented on Linux only) |

`Theme` fields: `primary` / `primary_light` / `primary_hover`; semantic colors `success` / `warning` / `danger` / `info` (each with a `_light` variant) plus `danger_hover`; text `text_primary` / `text_regular` / `text_secondary`; `border`; `fill_hover` / `fill_zebra`; backgrounds `bg_page` (page) / `bg_panel` (panel). Customizing means editing the palette and applying it wholesale:

```moonbit
@yue.initialize()
let t = @yue.default_theme()
@yue.theme_apply({ ..t, primary: "#1E4FA3", primary_light: "#E3EDFA" })
```

Following the system: pick the initial theme from `system_prefers_dark()`, and re-read and re-apply inside the `on_system_theme_change` callback. Focus rings and focused field borders use a neutral grey single stroke (not the theme color).

### Hooking custom components into the theme

Every component in the library (including the plain `label()`, which defaults to the theme's regular text color) follows the theme out of the box — zero color burden on consumers. Custom components follow three rules, with the platform pitfalls already encapsulated:

| Case | How |
|---|---|
| Self-drawn (on_draw) | Read colors from `theme_current()` inside the draw callback — no subscription needed (theme switches force a full repaint) |
| Label text with theme color | `theme_bind_fg(l, fn() { theme_current().text_regular })` — handles the "must re-set text after set_color" platform pitfall internally; bare `set_color` won't follow the theme, and hand-rolled subscriptions without the re-set leave stale colors |
| Container background with theme color | `theme_bind_bg(v, fn() { theme_current().bg_panel })` — fixed backgrounds don't update on repaint, they must be re-set |

Fixed colors (brand swatches etc.) can be set directly and stay theme-independent.

## Buttons and text

### Themed button button_t

`button_t(text, on_click?, variant? = Soft)`

Self-drawn button; hover changes stay within the theme palette.

| Param | Type | Default | Notes |
|---|---|---|---|
| text | String | required | button text |
| on_click | () -> Unit | no-op | click callback |
| variant | ButtonVariant | `Soft` | `Solid` solid white text / `Soft` light fill / `Text` no fill / `Danger` danger color |

Hover behavior: Solid / Danger darken, Soft goes solid white, Text gets a grey fill.

### Themed label label_t

`label_t(text, role? = Body, style?, style_str?, handle?)`

Unified font size / color per text role, left-aligned; accepts layout styles and a handle callback.

| Param | Type | Default | Notes |
|---|---|---|---|
| text | String | required | text |
| role | TextRole | `Body` | `Title` / `Section` / `Body` / `Secondary` / `Accent` |
| style / style_str | style key-value pairs | `[]` | see [layout.md](layout.md) |
| handle | (Label) -> Unit | no-op | post-creation callback receiving the underlying Label |

### Link link

`link(text, on_click)` — theme-colored text, darkens on hover with an underline-colored bar, click callback.

## Input

### Themed single-line input entry_t

`entry_t(text? = "", password? = false, height? = 30.0, on_input?)`

Unified font and line height; the text color follows the theme and cannot be customized (platform limitation, see [adaptation.md](adaptation.md)).

| Param | Type | Default | Notes |
|---|---|---|---|
| password | Bool | false | password mode |
| on_input | (String) -> Unit | no-op | content-change callback, receives the current text |

### Bordered input input_t

`input_t(text? = "", password? = false, margin? = 0.0, width? = 280.0, height? = 30.0, clearable? = false, on_input?, invalid? = Store::new(false))`

Self-drawn 1px outer border (turns theme primary on focus) + white background, straight corners.

| Param | Type | Default | Notes |
|---|---|---|---|
| margin / width / height | Double | 0 / 280 / 30 | outer margin and size |
| clearable | Bool | false | shows ✕ on the right on hover when non-empty; click clears |
| invalid | Store[Bool] | false | when true the border turns danger red (light form validation), reacts to Store set |

### Number input input_number

`input_number(value : Store[Double], min? = 0.0, max? = 100.0, step? = 1.0, num_width? = 64.0)`

-/+ buttons step the value, clamped to range; state lives in `Store[Double]`.

### Multi-line input textarea_t

`textarea_t(text? = "", width? = 280.0, height? = 110.0, margin? = 0.0, on_input?, clearable? = false, invalid? = Store::new(false))`

Same pattern as input_t: self-drawn 1px border (turns theme primary on focus) + 8px inset; overflow scrolls per platform. clearable / invalid semantics match input_t.

### Checkbox checkbox_t

`checkbox_t(title, checked? = false, disabled? = false, on_change?)`

Self-drawn square checkbox (14×14): solid theme fill + white tick when checked, border turns theme primary on hover, disabled state included.

| Param | Type | Default | Notes |
|---|---|---|---|
| checked | Bool | false | initial state |
| disabled | Bool | false | disabled state |
| on_change | (Bool) -> Unit | no-op | change callback, receives the new state |

### Radio group radio_group

`radio_group(options, selected : Store[String], disabled? = false)`

Selected item shows a solid square + theme-colored text, unselected a hollow square; clicks are mutually exclusive.

### Switch switch_t

`switch_t(checked : Store[Bool], disabled? = false)` — track + knob: on = theme-blue track with the knob right, off = light-grey track with the knob left; state lives in `Store[Bool]`.

### Slider slider_t

`slider_t(value : Store[Double], min? = 0.0, max? = 100.0, step? = 1.0, width? = 0.0, on_change?)`

Self-drawn: light-grey track + theme-colored fill + square thumb; click the track or drag the thumb, the value is step-quantized into `value` (external Store set works too); on_change fires on every change including during drags.

## Selection

### Dropdown select select_t

`select_t(options, value : Store[String], width? = 200.0, on_change?, clearable? = false)`

Fully self-drawn: click opens the candidate list, hover highlight, theme-colored ✓ on the current pick, click to fill and close, blur closes; same behavior on all platforms. With clearable=true, hovering a non-empty field shows ✕ beside the arrow; click clears the selection (value set to "", `on_change("")`).

### Date picker date_picker_t

`date_picker_t(value? : Store[DateYMD?], on_change?, width? = 200.0, placeholder? = "请选择日期", clearable? = false)`

Fully self-drawn: input-style field; clicking opens the `calendar_t` month panel, pick to fill and close, blur closes; with clearable=true, hovering a set value shows ✕ beside the arrow to clear (no on_change).

### Date range picker date_range_picker_t

`date_range_picker_t(value? : Store[DateRange], on_change?, width? = 260.0, placeholder? = "请选择日期区间", clearable? = false)`

The field shows "start ~ end"; clicking opens the range calendar — first pick sets the start, second sets the end (swapped automatically if earlier), then it closes and fires `on_change(start, end)`; in-between days get a light theme fill, endpoints solid squares; clicking the field again starts a new range. clearable clears both ends.

### Time range picker time_range_picker_t

`time_range_picker_t(value? : Store[TimeRange], on_change?, width? = 180.0, placeholder? = "请选择时间区间", clearable? = false)`

The field shows "start : end" as HH:MM; clicking opens start/end stepper rows (hour 0-23 / minute 0-59, backed by `input_number`), every step fires `on_change(start, end)` immediately; both default to 00:00, and the popover closes on field blur.

### Date-time range picker datetime_range_picker_t

`datetime_range_picker_t(value? : Store[DateTimeRange], on_change?, width? = 340.0, placeholder? = "请选择日期时间区间", clearable? = false)`

The field shows "start date start HH:MM ~ end date end HH:MM"; the popover is a range calendar + separator + start/end time stepper rows + a "Done" button; once the date range is complete, any time change fires `on_change(start date, start time, end date, end time)`. Value type `DateTimeRange{ start : (DateYMD, TimeHM)?, end : (DateYMD, TimeHM)? }`.

### Calendar panel calendar_t

`calendar_t(on_pick?, value? : Store[DateYMD?])`

Fully self-drawn month panel: ‹/› month nav + weekday row + 42-cell grid, adjacent-month days dimmed, "today" in theme primary, the selected day a solid theme square; clicking a day of the current month fires on_pick and writes value. `DateYMD::format()` renders `YYYY-MM-DD`, `TimeHM::format()` renders `HH:MM`.

### Color picker color_picker_t

`color_picker_t(value : Store[String], colors?, width? = 200.0)`

Dropdown form: the trigger field (current swatch + hex + arrow) opens the preset palette; clicking a swatch writes `value` (`"#RRGGBB"`) and closes, the selected swatch gets a theme outline + white check, blur closes; the palette is customizable (15 colors by default).

### Rating rate_t

`rate_t(value : Store[Int], max? = 5, on_change?)` — star sequence: filled theme color when on, outlined grey when off, hover preview, click writes `value` (0..max).

## Forms

### Form item form_item

`form_item(label, control : Node, label_width? = 90.0, error? = Store::new(""))`

Left label (grey, fixed width) + right control area, vertically centered; `error` is a validation message Store — when non-empty, danger-red text appears below the control row (row height is reserved, so appearing/disappearing errors cause no layout shift).

### Form form

`form(title, items : Array[Node])` — group title + a set of form items.

## Navigation

### Side menu side_menu

`side_menu(items, selected : Store[String], width? = 180.0, icons? = [])`

Hover light grey, selected theme-light-blue fill + theme-colored text + 3px left accent bar, 4px rounded corners. `icons` maps "item text → icon" (not drawn by default); `selected` is shared state — the main area subscribes to the same Store for `set_visible` page switching.

### Grouped side menu side_menu_sections

`side_menu_sections(sections : Array[(String, Array[String])], selected : Store[String], width? = 180.0, icons? = [], foldable? = true)`

Group caption row (secondary small text + collapse arrow on the right) + group items (same rendering/selection as side_menu); with foldable=true the group can be collapsed/expanded (all expanded by default, Enter/Space works too).

### Segmented control segmented

`segmented(options, selected : Store[String])` — selected white fill + theme-colored text, hover grey, straight corners.

### Breadcrumb breadcrumb

`breadcrumb(items, selected : Store[String])` — current item dark and non-clickable, the rest grey and clickable, turning theme-colored on hover.

### Pagination pagination

`pagination(current : Store[Int], pages)` — ‹ page numbers ›, current page solid theme fill with white text, hover light blue, 28×28 straight corners; `current` starts at 1, clicks write straight to the source Store, ‹ › are clamped at the bounds.

### Steps steps

`steps(items, current : Store[Int])` — number squares (done light blue / current solid / todo grey) + text + connector lines.

### Tabs tabs_t

`tabs_t(pages : Array[(String, Node)], selected? : Store[Int])`

Top form: tab header row (selected theme-colored text + 2px bottom indicator, darkens on hover) + content area switched via `set_visible`; `selected` is a page-index Store (internal 0 by default).

## Layout and separation

### Divider divider

`divider(vertical? = false, spacing? = 10.0)` — horizontal (default, 1px tall, flex width) or vertical (1px wide, height follows the parent container); spacing is the margin on both sides. The color is read from the theme at mount, so it takes effect on UI rebuild.

### Split panes hsplit / vsplit

`hsplit(first, second, ratio? = 0.5, min_first? = 80.0, min_second? = 80.0)` (`vsplit` defaults its min values to 60)

Draggable split layout: an 8px self-drawn handle with an always-visible divider line + dots (no need to hunt for it), grey fill on hover, theme color + white dots while dragging, mouse capture keeps events from being lost; ratio is the initial share, min clamps both panes.

## Data display

### Tag tag / tag_of_type

`tag(text, color, height? = 24.0)` / `tag_of_type(text, t : SemanticType)`

The former is a solid colored tag (custom color), the latter a light-fill tag with same-family dark text (`Primary` / `Success` / `Warning` / `Danger` / `Info`); straight corners, width adapts to the text.

### Avatar avatar

`avatar(letter, color, size? = 36.0)` — square solid fill with a white letter centered.

### Badge badge_count / badge_dot

`badge_count(count)` is a red-background white-text chip (width adapts, color follows the theme); `badge_dot(color? = "")` is an 8×8 dot.

### Statistic statistic

`statistic(title, value : Store[String])` — large reactive number + grey title.

### Linear progress progress_line

`progress_line(value : Store[Double], height? = 8.0)` — light-grey track + theme-colored fill, value in 0..1, changes repaint automatically.

### Descriptions descriptions

`descriptions(pairs : Array[(String, String)])` — two-column grid with grey keys and dark values.

### Timeline timeline

`timeline(items : Array[(String, String, SemanticType)])` — color dot + vertical line on the left, title + description on the right; items are (title, description, semantic type), fixed 56px row height.

### Collapse collapse

`collapse(panels : Array[(String, Array[Node])])` — click the title row to toggle content visibility, panels collapse independently, only the first panel is expanded initially.

### Card card

`card(title, children : Array[Node], height? = 160.0)` — title bar (bold, bottom separator) + border; content starts below the title bar.

### Code highlighting code_view

`code_view(lines, lang? = "moonbit", font_size? = 13.0, width? = 560.0, line_numbers? = false)`

Per-token highlighting with manual layout — consistent behavior on all platforms (including Windows). lang keyword sets: moonbit / js / ts / python / rust / c / go / bash / sql (case-insensitive); line_numbers=true draws a left gutter.

### Markdown rendering markdown_view

`markdown_view(source, width? = 560.0)` — headings 1-6, paragraphs, **bold**, *italic*, `inline code`, link text, ordered/unordered lists, blockquotes (theme-colored bar), rules, fenced code blocks (language from the fence marker, backed by code_view); consistent rendering across platforms, link/code colors follow the theme.

### Table table_t

`table_t(columns, rows : Store[Array[TableRow]], width? = 560.0, row_height? = 36.0, selection? : Store[Array[Int]], on_row_click?)`

Header + zebra stripes + hover highlight + Store-driven (a set rebuilds all rows and clears the selection). Columns via `TableColumn::make(title, width, align?)` (width ≤ 0 = flexible columns sharing the remaining width). Cells are `TableCell`: `CellText` / `CellTag(text, semantic type)` / `CellColorBox(hex, name)` / `CellLines(multi-line, row auto-grows)`; `TableRow::make(string array)` builds plain rows. Without `selection` rows single-select on click; pass `selection` to enable a checkbox column (row click toggles, header select-all/clear, dash when partial, selected rows get a light-blue fill); the callback receives `(index, row)`.

### Virtualized table table_v_t

`table_v_t(columns, rows : Store[Array[TableRow]], width? = 560.0, height? = 360.0, row_height? = 32.0, selection? : Store[Array[Int]], on_row_click?)`

The 10k+-row form of table_t: only visible rows are painted, self-managed scrolling (wheel / drag scrollbar / keyboard), free of the scroll container's content-height limit; cell rendering matches table_t (CellLines clamps to two lines within the row height), column/selection semantics are identical.

### Tree tree

`tree(root : Array[TreeNode])` — indented hierarchy + click to expand/collapse (arrow indicator when a node has children). Node type `TreeNode{ label : String, children : Array[TreeNode] }`.

### Transfer transfer

`transfer(left_items : Store[Array[String]], right_items : Store[Array[String]], width? = 160.0)` — two columns, click a row to select it (solid-square marker), the middle ›/‹ buttons move selected items between columns; data is driven by two Stores.

## Icons

136 built-in vector icons (arrows / file / editing / view / navigation / media / messaging / system / development / data / status, styled after Tabler / Lucide).

| API | Purpose |
|---|---|
| `icon(kind : IconKind, size? = 16.0, color? = "")` | icon node: theme regular color by default, fixed color via color |
| `icon_button_t(kind, on_click?, size? = 28.0, tip? = "")` | square icon button: hover grey fill + text brightening, Enter/Space activates; non-empty tip attaches a native tooltip; marginRight 6 for toolbar rows |
| `draw_icon(p : Painter, kind, cx, cy, s, color)` | unified self-drawing entry (center coordinates + edge length) |
| `all_icons()` / `icon_name(kind)` | full list / name lookup |

## Feedback

### Alert banners alert / alert_closeable

`alert(text, t : SemanticType, height? = 40.0)` / `alert_closeable(text, t)`

Light fill of the type + 4px left color bar + same-family dark text, full width; the latter adds a right-side close button that hides the whole banner.

### Result result

`result(t, title, desc, children : Array[Node])` — large colored symbol + title + description + custom button area.

### Empty state empty

`empty(desc)` — grey placeholder block + centered caption.

### Dialog dialog_t

`dialog_t(visible : Store[Bool], title, children : Array[Node], width? = 420.0, confirm_text? = "确定", cancel_text? = "取消", on_confirm?, on_cancel?, close_on_mask? = false)`

In-app dialog: same-window mask (semi-transparent black, absolute relative to the mount container — mounted at the window root it covers the whole window) + centered panel (title bar with ✕ + body + right-aligned buttons). `visible` drives show/hide; ✕ / cancel / confirm auto-close after the callback, empty text hides that button (both empty hides the whole row), close_on_mask=true also closes on mask clicks. Visually modal, not keyboard-modal.

### Toast toast_layer

`toast_layer(duration_ms? = 2600) -> (Node, (String, SemanticType) -> Unit)`

Mount the layer node at the window root (absolute top strip, no layout space); the push function shows a semantic toast bar (panel background + border + type icon), auto-removed after 2.6s by default, multiple bars stack top-down; call it after the layer is mounted.

### Context menu context_menu_for

`context_menu_for(content : Node, items : Array[(String, () -> Unit)])` — wrap any node with a native right-click menu, label "-" draws a separator; the popup position is converted to screen coordinates via `bounds_in_screen`, and the menu is rebuilt on each right-click.

## Overlays

### Tooltip tooltip_t

`tooltip_t(content : Node, tip)` — wrap any node with a native tooltip (system style, zero cost; use popover_t for a themed bubble). On Linux the tooltip color is pinned to a dark background with white text (independent of the system theme).

### Popover popover_t

`popover_t(trigger : Node, content : Node, width, height)` — clicking the trigger opens arbitrary Node content below it; click again to toggle closed.

### Dropdown menu dropdown_menu

`dropdown_menu(trigger : String, items, on_select : (Int) -> Unit, width? = 160.0)` — trigger text + dropdown arrow; clicking opens the item list: hover highlight, click calls back the index and closes; `"-"` in items draws a separator.

### Carousel carousel_t

`carousel_t(pages : Array[Node], width? = 360.0, height? = 180.0, interval_ms? = 3000)` — panel sequence + side arrows + bottom dots; with interval_ms > 0 it auto-advances every interval milliseconds (paused on hover), arrows/dots switch manually.

## Demo

`moon run examples/showcase` — the full-capability demo board, one page per capability area, each page's source in its own file (`examples/showcase/pages_*.mbt`) — the best copy-paste material library; the page list is in the [documentation index](README.md) "Demo" section.

![Basic components](images/components-basic.png)

![Navigation](images/components-nav.png)

![Data display](images/components-data.png)

![Feedback](images/components-feedback.png)

State coordination across components goes through `Store` (subscribe / map / bind_label) or signals (`Signal`: computed with automatic dependency tracking, batch updates; pass a `sig.store()` view to component APIs taking a Store); see [declarative.md](declarative.md). Chinese version: [docs/zh/components-ui.md](zh/components-ui.md).
