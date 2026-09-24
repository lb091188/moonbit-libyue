# Themed Component Library Quick Reference

Themed component library quick reference: a full set of Element-Plus-style UI components (buttons / input / selection / forms / navigation / layout / data display / icons / feedback / overlays). Every function is called via `@yue` and returns a `Node` that goes straight into the UI tree. Optional parameters (marked `?` in the signatures below) must be passed by name, e.g. `date_picker_t(value=day)`; parameters without `?` are positional. Reactive `Store` / `Signal` parameters are covered in [declarative.md](declarative.md); native controls (Window / Label / Button / Entry, etc.) are in [components.md](components.md).

Full demo: `examples/showcase`.

## Theme

All colors come from the theme palette — a deep, low-saturation scheme: blue `#2D68C4`, green `#2E9E5B`, orange `#D9822B`, red `#D64550`, plus greys for text / border / fill. Components render straight corners, use background colors for hover/active states, and center text vertically. Form controls share a unified height of 32px (`control_height`), so buttons / inputs / selects / steppers / picker fields align on one row.

### Switching and customization

| API | Purpose |
|---|---|
| `default_theme()` / `dark_theme()` | built-in light / dark themes, return a `Theme` |
| `theme_current()` | read the current theme snapshot |
| `theme_apply(t)` | apply a theme: switching takes effect immediately, no UI rebuild needed (Linux native-control styling is rebuilt too) |
| `on_theme_change(f)` | subscribe to theme changes (registered at mount for re-applying colors fixed at mount) |
| `system_prefers_dark()` | read the system light/dark preference (currently implemented on Linux only) |
| `on_system_theme_change(f)` | fires when the system preference changes (currently implemented on Linux only) |
| `system_accent()` | read the system accent color as hex, empty string when the system has no accent |
| `theme_from_accent(accent, dark?)` | derive a whole palette from one accent color via formula, returns a `Theme` |
| `theme_from_system()` | follow the system for both light/dark and accent, returns a `Theme` |

`Theme` fields:

| Field | Purpose |
|---|---|
| `primary` / `primary_light` / `primary_hover` | primary / light primary / hover darkening |
| `success` / `warning` / `danger` / `info` | four semantic colors (each with a same-named `_light` variant) |
| `danger_hover` | danger hover darkening |
| `text_primary` / `text_regular` / `text_secondary` | primary / regular / secondary text |
| `border` | border color |
| `fill_hover` / `fill_zebra` | hover fill / zebra stripe |
| `bg_page` / `bg_panel` | page background / panel background |

Customizing means editing the palette and applying it wholesale:

```moonbit
@yue.initialize()
let t = @yue.default_theme()
@yue.theme_apply({ ..t, primary: "#1E4FA3", primary_light: "#E3EDFA" })
```

Following the system: `theme_from_system()` gives you a theme that follows the system for both light/dark and the accent color (falling back to the built-in primary on desktops without an accent); recompute and re-apply inside the `on_system_theme_change` callback to track live changes. Focus rings and focused field borders use a neutral grey single stroke (not the theme color).

```moonbit
@yue.theme_apply(@yue.theme_from_system())
@yue.on_system_theme_change(fn() {
  @yue.theme_apply(@yue.theme_from_system())
})
```

### Formula-derived palettes and the system accent

With a single accent color you don't have to hand-tune a whole palette: `theme_from_accent(accent, dark?)` derives one via HSL formulas — the accent keeps its hue while lightness is clamped per mode (0.34..0.52 light / 0.55..0.72 dark) with a saturation floor for readability; `primary_hover` shifts lightness by ∓8%, `primary_light` mixes toward the panel background (this is the Soft button fill); semantic colors (success/warning/danger/info) use a fixed hue wheel 142/36/4/210 borrowing the accent's saturation, with lightness following the mode; neutrals (text / border / fills / backgrounds) stay on the built-in base ramps and never shift with the accent.

`system_accent()` reads the system accent color: on Linux a three-step fallback (GNOME 47+ accent-color setting → the selected-background color in the current GTK theme CSS → empty string), on Windows the DWM colorization color, on macOS `controlAccentColor`; see [adaptation.md](adaptation.md) for the read paths and measured values.

```moonbit
// click a preset to re-skin instantly; light/dark switching keeps the current accent
let accent = @yue.Store::new("")
@yue.theme_apply(@yue.theme_from_accent(accent.get(), dark=@yue.system_prefers_dark()))
accent.subscribe(fn(a) {
  @yue.theme_apply(@yue.theme_from_accent(a, dark=@yue.system_prefers_dark()))
})
```

### Hooking custom components into the theme

Every component in the library (including the plain `label()`, which defaults to the theme's regular text color) follows the theme out of the box — zero color burden on consumers. Custom components follow three rules, with the platform pitfalls already encapsulated:

| Case | How |
|---|---|
| Self-drawn (on_draw) | Read colors from `theme_current()` inside the draw callback — no subscription needed (theme switches force a full repaint) |
| Label text with theme color | `theme_bind_fg(l, fn() { theme_current().text_regular })` — handles the "must re-set text after set_color" platform pitfall internally; bare `set_color` won't follow the theme, and hand-rolled subscriptions without the re-set leave stale colors |
| Container background with theme color | `theme_bind_bg(v, fn() { theme_current().bg_panel })` — fixed backgrounds don't update on repaint, they must be re-set |

Fixed colors (brand swatches etc.) can be set directly and stay theme-independent.

```moonbit
let l = @yue.Label::make("Title")
@yue.theme_bind_fg(l, fn() { @yue.theme_current().text_regular })
let panel = @yue.Container::make()
@yue.theme_bind_bg(panel, fn() { @yue.theme_current().bg_panel })
```

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

```moonbit
@yue.button_t("OK", on_click=fn() { submit() })
@yue.button_t("Delete", variant=@yue.Danger)
```

### Themed label label_t

`label_t(text, role? = Body, style?, style_str?, handle?)`

Unified font size / color per text role, left-aligned; accepts layout styles and a handle callback.

| Param | Type | Default | Notes |
|---|---|---|---|
| text | String | required | text |
| role | TextRole | `Body` | `Title` / `Section` / `Body` / `Secondary` / `Accent` |
| style / style_str | style key-value pairs | `[]` | see [layout.md](layout.md) |
| handle | (Label) -> Unit | no-op | post-creation callback receiving the underlying Label |

```moonbit
@yue.label_t("Settings", role=@yue.Title)
@yue.label_t("Current user: admin", role=@yue.Secondary)
```

### Link link

`link(text, on_click)` — theme-colored text, darkens on hover with an underline-colored bar, click callback.

```moonbit
@yue.link("View details", fn() { open_detail() })
```

## Input

### Themed single-line input entry_t

`entry_t(text? = "", password? = false, height? = 32.0, on_input?)`

Unified font and line height; the text color follows the theme and cannot be customized (platform limitation, see [adaptation.md](adaptation.md)).

| Param | Type | Default | Notes |
|---|---|---|---|
| password | Bool | false | password mode |
| on_input | (String) -> Unit | no-op | content-change callback, receives the current text |

```moonbit
let name = @yue.Store::new("")
@yue.entry_t(text="prefill", on_input=fn(s) { name.set(s) })
```

### Bordered input input_t

`input_t(text? = "", password? = false, margin? = 0.0, width? = 280.0, height? = 32.0, clearable? = false, on_input?, invalid? = Store::new(false))`

Self-drawn 1px outer border (turns theme primary on focus) + white background, straight corners.

| Param | Type | Default | Notes |
|---|---|---|---|
| margin / width / height | Double | 0 / 280 / 32 | outer margin and size |
| clearable | Bool | false | shows ✕ on the right on hover when non-empty; click clears |
| invalid | Store[Bool] | false | when true the border turns danger red (light form validation), reacts to Store set |

```moonbit
let valid = @yue.Store::new(false)
@yue.input_t(text="admin", clearable=true, invalid=valid, on_input=fn(s) { check(s) })
```

### Number input input_number

`input_number(value : Store[Double], min? = 0.0, max? = 100.0, step? = 1.0, num_width? = 64.0)`

-/+ buttons step the value, clamped to range; state lives in `Store[Double]`.

```moonbit
let count = @yue.Store::new(1.0)
@yue.input_number(count, min=1.0, max=10.0)
```

### Multi-line input textarea_t

`textarea_t(text? = "", width? = 280.0, height? = 110.0, margin? = 0.0, on_input?, clearable? = false, invalid? = Store::new(false))`

Same pattern as input_t: self-drawn 1px border (turns theme primary on focus) + 8px inset; overflow scrolls per platform. clearable / invalid semantics match input_t.

```moonbit
@yue.textarea_t(text="line one\nline two", width=320.0, height=120.0)
```

### Checkbox checkbox_t

`checkbox_t(title, checked? = false, disabled? = false, on_change?)`

Self-drawn square checkbox (14×14): solid theme fill + white tick when checked, border turns theme primary on hover, disabled state included.

| Param | Type | Default | Notes |
|---|---|---|---|
| checked | Bool | false | initial state |
| disabled | Bool | false | disabled state |
| on_change | (Bool) -> Unit | no-op | change callback, receives the new state |

```moonbit
@yue.checkbox_t("Remember me", checked=true, on_change=fn(v) { remember(v) })
```

### Radio group radio_group

`radio_group(options, selected : Store[String], disabled? = false)`

Selected item shows a solid square + theme-colored text, unselected a hollow square; clicks are mutually exclusive.

```moonbit
let choice = @yue.Store::new("A")
@yue.radio_group(["A", "B", "C"], choice)
```

### Switch switch_t

`switch_t(checked : Store[Bool], disabled? = false)` — track + knob: on = theme-blue track with the knob right, off = light-grey track with the knob left; state lives in `Store[Bool]`.

```moonbit
let enabled = @yue.Store::new(true)
@yue.switch_t(enabled)
```

### Slider slider_t

`slider_t(value : Store[Double], min? = 0.0, max? = 100.0, step? = 1.0, width? = 0.0, on_change?)`

Self-drawn: light-grey track + theme-colored fill + square thumb; click the track or drag the thumb, the value is step-quantized into `value` (external Store set works too); on_change fires on every change including during drags.

```moonbit
let volume = @yue.Store::new(0.5)
@yue.slider_t(volume, max=1.0, step=0.1, on_change=fn(v) { set_volume(v) })
```

## Selection

### Dropdown select select_t

`select_t(options, value : Store[String], width? = 200.0, on_change?, clearable? = false)`

Fully self-drawn: click opens the candidate list, hover highlight, theme-colored ✓ on the current pick, click to fill and close, blur closes; same behavior on all platforms. With clearable=true, hovering a non-empty field shows ✕ beside the arrow; click clears the selection (value set to "", `on_change("")`).

```moonbit
let color = @yue.Store::new("Red")
@yue.select_t(["Red", "Green", "Blue"], color, clearable=true, on_change=fn(s) { recolor(s) })
```

### Date picker date_picker_t

`date_picker_t(value? : Store[DateYMD?], on_change?, width? = 200.0, placeholder? = "请选择日期", clearable? = false)`

Fully self-drawn: input-style field; clicking opens the `calendar_t` month panel, pick to fill and close, blur closes; with clearable=true, hovering a set value shows ✕ beside the arrow to clear (no on_change).

```moonbit
let day : @yue.Store[@yue.DateYMD?] = @yue.Store::new(None)
@yue.date_picker_t(value=day, on_change=fn(d) { picked(d) })
```

### Date range picker date_range_picker_t

`date_range_picker_t(value? : Store[DateRange], on_change?, width? = 260.0, placeholder? = "请选择日期区间", clearable? = false)`

The field shows "start ~ end"; clicking opens the range calendar — first pick sets the start, second sets the end (swapped automatically if earlier), then it closes and fires `on_change(start, end)`; in-between days get a light theme fill, endpoints solid squares; clicking the field again starts a new range. clearable clears both ends.

```moonbit
let range : @yue.Store[@yue.DateRange] = @yue.Store::new({ start: None, end: None })
@yue.date_range_picker_t(value=range, on_change=fn(s, e) { show(s, e) })
```

### Time range picker time_range_picker_t

`time_range_picker_t(value? : Store[TimeRange], on_change?, width? = 180.0, placeholder? = "请选择时间区间", clearable? = false)`

The field shows "start : end" as HH:MM; clicking opens start/end stepper rows (hour 0-23 / minute 0-59, backed by `input_number`), every step fires `on_change(start, end)` immediately; both default to 00:00, and the popover closes on field blur.

```moonbit
let tr : @yue.Store[@yue.TimeRange] = @yue.Store::new({ start: None, end: None })
@yue.time_range_picker_t(value=tr, on_change=fn(s, e) { show(s, e) })
```

### Date-time range picker datetime_range_picker_t

`datetime_range_picker_t(value? : Store[DateTimeRange], on_change?, width? = 340.0, placeholder? = "请选择日期时间区间", clearable? = false)`

The field shows "start date start HH:MM ~ end date end HH:MM"; the popover is a range calendar + separator + start/end time stepper rows + a "Done" button; once the date range is complete, any time change fires `on_change(start date, start time, end date, end time)`. Value type `DateTimeRange{ start : (DateYMD, TimeHM)?, end : (DateYMD, TimeHM)? }`.

```moonbit
let dtr : @yue.Store[@yue.DateTimeRange] = @yue.Store::new({ start: None, end: None })
@yue.datetime_range_picker_t(value=dtr, on_change=fn(sd, st, ed, et) { show(sd, st, ed, et) })
```

### Calendar panel calendar_t

`calendar_t(on_pick?, value? : Store[DateYMD?])`

Fully self-drawn month panel: ‹/› month nav + weekday row + 42-cell grid, adjacent-month days dimmed, "today" in theme primary, the selected day a solid theme square; clicking a day of the current month fires on_pick and writes value. `DateYMD::format()` renders `YYYY-MM-DD`, `TimeHM::format()` renders `HH:MM`.

```moonbit
@yue.calendar_t(on_pick=fn(d) { picked(d) })
```

### Color picker color_picker_t

`color_picker_t(value : Store[String], colors?, width? = 200.0)`

Dropdown form: the trigger field (current swatch + hex + arrow) opens the preset palette; clicking a swatch writes `value` (`"#RRGGBB"`) and closes, the selected swatch gets a theme outline + white check, blur closes; the palette is customizable (15 colors by default).

```moonbit
let hex = @yue.Store::new("#2D68C4")
@yue.color_picker_t(hex)
```

### Rating rate_t

`rate_t(value : Store[Int], max? = 5, on_change?)` — star sequence: filled theme color when on, outlined grey when off, hover preview, click writes `value` (0..max).

```moonbit
let stars = @yue.Store::new(4)
@yue.rate_t(stars)
```

## Forms

### Form item form_item

`form_item(label, control : Node, label_width? = 90.0, error? = Store::new(""))`

Left label (grey, fixed width) + right control area, vertically centered; `error` is a validation message Store — when non-empty, danger-red text appears below the control row (row height is reserved, so appearing/disappearing errors cause no layout shift).

```moonbit
let err = @yue.Store::new("")
@yue.form_item("Username", @yue.input_t(text="admin"), error=err)
```

### Form form

`form(title, items : Array[Node])` — group title + a set of form items.

```moonbit
@yue.form("Account", [
  @yue.form_item("Username", @yue.input_t()),
  @yue.form_item("Password", @yue.input_t(password=true)),
])
```

## Navigation

### Side menu side_menu

`side_menu(items, selected : Store[String], width? = 180.0, icons? = [])`

Hover light grey, selected theme-light-blue fill + theme-colored text + 3px left accent bar, 4px rounded corners. `icons` maps "item text → icon" (not drawn by default); `selected` is shared state — the main area subscribes to the same Store for `set_visible` page switching.

```moonbit
let page = @yue.Store::new("Home")
@yue.side_menu(["Home", "Settings", "About"], page)
```

### Grouped side menu side_menu_sections

`side_menu_sections(sections : Array[(String, Array[String])], selected : Store[String], width? = 180.0, icons? = [], foldable? = true)`

Group caption row (secondary small text + collapse arrow on the right) + group items (same rendering/selection as side_menu); with foldable=true the group can be collapsed/expanded (all expanded by default, Enter/Space works too).

```moonbit
let page = @yue.Store::new("Buttons")
@yue.side_menu_sections([("Components", ["Buttons", "Input"]), ("System", ["About"])], page)
```

### Segmented control segmented

`segmented(options, selected : Store[String])` — selected white fill + theme-colored text, hover grey, straight corners.

```moonbit
let view = @yue.Store::new("List")
@yue.segmented(["List", "Grid"], view)
```

### Breadcrumb breadcrumb

`breadcrumb(items, selected : Store[String])` — current item dark and non-clickable, the rest grey and clickable, turning theme-colored on hover.

```moonbit
let cur = @yue.Store::new("Network")
@yue.breadcrumb(["Home", "Settings", "Network"], cur)
```

### Pagination pagination

`pagination(current : Store[Int], pages)` — ‹ page numbers ›, current page solid theme fill with white text, hover light blue, 28×28 straight corners; `current` starts at 1, clicks write straight to the source Store, ‹ › are clamped at the bounds.

```moonbit
let page_no = @yue.Store::new(1)
@yue.pagination(page_no, 10)
```

### Steps steps

`steps(items, current : Store[Int])` — number squares (done light blue / current solid / todo grey) + text + connector lines.

```moonbit
let step = @yue.Store::new(1)
@yue.steps(["Fill in", "Verify", "Done"], step)
```

### Tabs tabs_t

`tabs_t(pages : Array[(String, Node)], selected? : Store[Int])`

Top form: tab header row (selected theme-colored text + 2px bottom indicator, darkens on hover) + content area switched via `set_visible`; `selected` is a page-index Store (internal 0 by default).

```moonbit
@yue.tabs_t([("Overview", overview_view), ("Log", log_view)])
```

## Layout and separation

### Divider divider

`divider(vertical? = false, spacing? = 10.0)` — horizontal (default, 1px tall, flex width) or vertical (1px wide, height follows the parent container); spacing is the margin on both sides. The color is read from the theme at mount, so it takes effect on UI rebuild.

```moonbit
@yue.divider(spacing=16.0)
@yue.divider(vertical=true)
```

### Split panes hsplit / vsplit

`hsplit(first, second, ratio? = 0.5, min_first? = 80.0, min_second? = 80.0)` (`vsplit` defaults its min values to 60)

Draggable split layout: an 8px self-drawn handle with an always-visible divider line + dots (no need to hunt for it), grey fill on hover, theme color + white dots while dragging, mouse capture keeps events from being lost; ratio is the initial share, min clamps both panes.

```moonbit
@yue.hsplit(nav_panel, content_panel, ratio=0.25)
@yue.vsplit(editor_panel, terminal_panel)
```

## Data display

### Tag tag / tag_of_type

`tag(text, color, height? = 24.0)` / `tag_of_type(text, t : SemanticType)`

The former is a solid colored tag (custom color), the latter a light-fill tag with same-family dark text (`Primary` / `Success` / `Warning` / `Danger` / `Info`); straight corners, width adapts to the text.

```moonbit
@yue.tag("v1.2", "#2D68C4")
@yue.tag_of_type("Running", @yue.Success)
```

### Avatar avatar

`avatar(letter, color, size? = 36.0)` — square solid fill with a white letter centered.

```moonbit
@yue.avatar("Y", "#2D68C4", size=40.0)
```

### Badge badge_count / badge_dot

`badge_count(count)` is a red-background white-text chip (width adapts, color follows the theme); `badge_dot(color? = "")` is an 8×8 dot.

```moonbit
@yue.badge_count(3)
@yue.badge_dot(color="#2E9E5B")
```

### Statistic statistic

`statistic(title, value : Store[String])` — large reactive number + grey title.

```moonbit
let visits = @yue.Store::new("1,024")
@yue.statistic("Visits today", visits)
```

### Linear progress progress_line

`progress_line(value : Store[Double], height? = 8.0)` — light-grey track + theme-colored fill, value in 0..1, changes repaint automatically.

```moonbit
let ratio = @yue.Store::new(0.42)
@yue.progress_line(ratio, height=6.0)
```

### Descriptions descriptions

`descriptions(pairs : Array[(String, String)])` — two-column grid with grey keys and dark values.

```moonbit
@yue.descriptions([("Name", "libyue"), ("Version", "0.15.6"), ("Platform", "Linux")])
```

### Timeline timeline

`timeline(items : Array[(String, String, SemanticType)])` — color dot + vertical line on the left, title + description on the right; items are (title, description, semantic type), fixed 56px row height.

```moonbit
@yue.timeline([
  ("Build", "compiled", @yue.Success),
  ("Test", "45/45 passed", @yue.Success),
  ("Release", "awaiting review", @yue.Warning),
])
```

### Collapse collapse

`collapse(panels : Array[(String, Array[Node])])` — click the title row to toggle content visibility, panels collapse independently, only the first panel is expanded initially.

```moonbit
@yue.collapse([
  ("General", [@yue.label_t("Basic options", role=@yue.Body)]),
  ("Advanced", [@yue.label_t("Debug options", role=@yue.Body)]),
])
```

### Card card

`card(title, children : Array[Node], height? = 160.0)` — title bar (bold, bottom separator) + border; content starts below the title bar.

```moonbit
@yue.card("Summary", [@yue.statistic("Tasks", done)], height=120.0)
```

### Code highlighting code_view

`code_view(lines, lang? = "moonbit", font_size? = 13.0, width? = 560.0, line_numbers? = false)`

Per-token highlighting with manual layout — consistent behavior on all platforms (including Windows). lang keyword sets: moonbit / js / ts / python / rust / c / go / bash / sql (case-insensitive); line_numbers=true draws a left gutter.

```moonbit
@yue.code_view(
  ["fn main() {", "  println(\"hello\")", "}"],
  lang="moonbit",
  line_numbers=true,
)
```

### Markdown rendering markdown_view

`markdown_view(source, width? = 560.0)` — headings 1-6, paragraphs, **bold**, *italic*, `inline code`, link text, ordered/unordered lists, blockquotes (theme-colored bar), rules, fenced code blocks (language from the fence marker, backed by code_view); consistent rendering across platforms, link/code colors follow the theme.

```moonbit
@yue.markdown_view("# Heading\n\nBody **bold** and `inline code`.")
```

### Table table_t

`table_t(columns, rows : Store[Array[TableRow]], width? = 560.0, row_height? = 36.0, selection? : Store[Array[Int]], sort? : Store[TableSort], on_row_click?)`

Header + zebra stripes + hover highlight + Store-driven (a set rebuilds all rows and clears the selection). Columns via `TableColumn::make(title, width, align?, sortable?)` (width ≤ 0 = flexible columns sharing the remaining width; `sortable=false` keeps a column out of header sorting). Cells are `TableCell`: `CellText` (single-line ellipsis when overflowing; re-truncated at the new width after column resize) / `CellTag(text, semantic type)` / `CellColorBox(hex, name)` / `CellLines(multi-line, row auto-grows)`; `TableRow::make(string array)` builds plain rows. Without `selection` rows single-select on click; pass `selection` to enable a checkbox column (row click toggles, header select-all/clear, dash when partial, selected rows get a light-blue fill); the callback receives `(index, row)`.

Header sorting and column resizing: pass `sort` (a `Store[TableSort]`; `TableSort{ column, asc }` where `column` is the column-definition index, < 0 = unsorted) and sortable columns keep a grey ↕ double-triangle hint at the right of the header so users can tell the column is clickable; clicking runs a three-state cycle "new column ascending → same column descending → click again to clear" (column set back to -1, subscribers restore the original order), and the actively sorted column switches to a solid theme-colored ▲ / ▼ so the sort state is obvious at a glance; actual data sorting is up to you — subscribe to the store, sort, and write back to `rows`. Header column boundaries stay visible as light lines and turn theme-colored on hover / while dragging; press within 4px of either edge of a column (no handle on the last column's right edge) to resize, with the two neighbors trading width (minimum 56px), mouse capture keeping the drag alive, and no row rebuild or selection loss.

```moonbit
let rows = @yue.Store::new([@yue.TableRow::make(["A", "1"]), @yue.TableRow::make(["B", "2"])])
let sort = @yue.Store::new(@yue.TableSort::{ column: -1, asc: true })
sort.subscribe(fn(st) { /* re-sort by st.column / st.asc, then rows.set(...) */ })
@yue.table_t(
  [@yue.TableColumn::make("Name", 120.0), @yue.TableColumn::make("Count", 80.0, align=@yue.Center)],
  rows,
  sort=sort,
)
```

### Virtualized table table_v_t

`table_v_t(columns, rows : Store[Array[TableRow]], width? = 560.0, height? = 360.0, row_height? = 32.0, selection? : Store[Array[Int]], sort? : Store[TableSort], on_row_click?)`

The 10k+-row form of table_t: only visible rows are painted, self-managed scrolling (wheel / drag scrollbar / keyboard), free of the scroll container's content-height limit; cell rendering matches table_t (CellLines clamps to two lines within the row height), and column / selection / sort (header arrows) / column-resize semantics are identical.

```moonbit
let rows = @yue.Store::new([@yue.TableRow::make(["1", "A"]), @yue.TableRow::make(["2", "B"])])
@yue.table_v_t(
  [@yue.TableColumn::make("No.", 90.0), @yue.TableColumn::make("Name", 160.0)],
  rows,
  height=480.0,
)
```

### Tree tree

`tree(root : Array[TreeNode])` — indented hierarchy + click to expand/collapse (arrow indicator when a node has children). Node type `TreeNode{ label : String, children : Array[TreeNode] }`.

```moonbit
@yue.tree([
  { label: "src", children: [{ label: "main.mbt", children: [] }] },
  { label: "README.md", children: [] },
])
```

### Transfer transfer

`transfer(left_items : Store[Array[String]], right_items : Store[Array[String]], width? = 160.0)` — two columns, click a row to select it (solid-square marker), the middle ›/‹ buttons move selected items between columns; data is driven by two Stores.

```moonbit
let left = @yue.Store::new(["A", "B"])
let right = @yue.Store::new(["C"])
@yue.transfer(left, right)
```

## Charts

The whole chart family (EP Chart counterpart) is self-drawn in pure MoonBit: data flows through `Store`, a set only calls schedule_paint on the canvas — no view-tree rebuild; colors are read from the theme palette at draw time, so `theme_apply` light/dark switches follow immediately. Series colors cycle the four semantic theme colors (line charts ≤4 series), donut charts cycle five.

### Line / area chart line_chart_t

`line_chart_t(series : Store[Array[LineSeries]], width? = 560.0, height? = 260.0, area? = false, y_range?, show_last? = true)`

Multi-series line chart over fixed-length rolling windows.

| Param | Type | Default | Notes |
|---|---|---|---|
| series | Store[Array[LineSeries]] | required | multi-series data, see push helpers below |
| width / height | Double | 560 / 260 | canvas size |
| area | Bool | false | semi-transparent area fill |
| y_range | (Double, Double)? | None | manual y range; None = auto |
| show_last | Bool | true | right-edge latest-value label |
 `LineSeries::make(name, max_points?)` creates a series (window capacity defaults to 100, oldest dropped on overflow); push points with `series_push(store, series index, value)` (or `win_push(window, max_points, value)` for a new window, then set it wholesale). The y-axis auto-ranges (window min/max + 8% padding) or is pinned via `y_range = (low, high)`; horizontal grid + left ticks; `area = true` adds semi-transparent area fill (to the zero line when 0 is in range, plot bottom for all-positive, plot top for all-negative); `show_last` toggles the right-edge latest-value label.

Rendering strategy: when points outnumber pixel columns the chart decimates to columns (keeping each column's min/max extremes) and switches to rect paths — area mode fills one rect per column up to the anchor (the fill's top edge *is* the line), line mode draws a min..max vertical bar per column; when points are fewer than columns it uses a true polyline plus polygon area fill. Per-frame cost is decoupled from window size (1000 points × 4 series measured ~3ms, see adaptation.md).

```moonbit
let series = @yue.Store::new([
  @yue.LineSeries::make("CPU", max_points=120),
  @yue.LineSeries::make("Memory", max_points=120),
])
ignore(@yue.set_timer(500, fn() {
  @yue.series_push(series, 0, cpu_usage())
  @yue.series_push(series, 1, mem_usage())
  true
}))
@yue.line_chart_t(series, width=380.0, height=220.0)
@yue.line_chart_t(series, width=380.0, height=220.0, area=true)
```

### Bar chart bar_chart_t

`bar_chart_t(data : Store[Array[BarItem]], width? = 560.0, height? = 280.0, horizontal? = false, y_range? = None)`

Vertical bars

| Param | Type | Default | Notes |
|---|---|---|---|
| data | Store[Array[BarItem]] | required | category data (values may be negative) |
| width / height | Double | 560 / 280 | canvas size |
| horizontal | Bool | false | horizontal bar form |
 (default) and horizontal bars (`horizontal = true`, for long category names). `BarItem::make(label, value)` with possibly negative values; zero baseline, positive in theme color and negative in red. Hovering highlights the category and annotates its value inline (self-drawn, no popover); category labels thin out and truncate automatically when dense. Full redraw of 200 categories measured ~0.4ms.

```moonbit
let bars = @yue.Store::new([
  @yue.BarItem::make("Jan", 12.0),
  @yue.BarItem::make("Feb", -8.0),
])
@yue.bar_chart_t(bars, width=380.0, height=220.0)
@yue.bar_chart_t(bars, width=380.0, height=220.0, horizontal=true)
```

### Donut / pie chart donut_chart_t

`donut_chart_t(data : Store[Array[DonutSlice]], width? = 480.0, height? = 240.0, thickness? = 34.0, center? = "")`

Proportional sectors

| Param | Type | Default | Notes |
|---|---|---|---|
| data | Store[Array[DonutSlice]] | required | sector data (negatives excluded) |
| width / height | Double | 480 / 240 | canvas size |
| thickness | Double | 34 | ring thickness (0 = solid pie) |
| center | String | "" | center text; empty = total value |
 (clockwise from 12 o'clock, five-color cycle, adjacent sectors differ); the center shows the total (pass `center` to override the text); a right-side legend (swatch + label + value and percentage). Hovering explodes a sector by 4px and highlights its legend row. `DonutSlice::make(label, value)`; negative values are excluded from proportions. Redraw of 50 sectors measured ~2.9ms.

```moonbit
let slices = @yue.Store::new([
  @yue.DonutSlice::make("Direct", 335.0),
  @yue.DonutSlice::make("Search", 510.0),
])
@yue.donut_chart_t(slices, width=420.0, height=220.0)
```

### Gauge gauge_t

`gauge_t(value : Store[Double], width? = 240.0, height? = 170.0, thresholds?)`

Single-value percentage ring

| Param | Type | Default | Notes |
|---|---|---|---|
| value | Store[Double] | required | 0..1, clamped |
| width / height | Double | 240 / 170 | canvas size |
| thresholds | Array[(Double, String)] | [] | ascending (upper bound, color) bands; empty = theme primary |
 (270° sweep starting at 135°, opening downward) + big center number. `value` is 0..1 (clamped); `thresholds` is an ascending `[(upper bound, color), ...]` and the value arc takes the color of the band it falls into (empty table = theme primary), e.g. `[(0.6, green), (0.85, orange), (1.0, red)]`. Smooth interpolation: after a target change a 16ms timer closes 25% of the remaining gap per tick (not animation-frame driven), so 2Hz updates never jump.

```moonbit
let usage = @yue.Store::new(0.0)
@yue.gauge_t(usage, thresholds=[
  (0.6, @yue.theme_current().success),
  (0.85, @yue.theme_current().warning),
  (1.0, @yue.theme_current().danger),
])
```

### Scatter chart scatter_t

`scatter_t(points : Store[Array[(Double, Double)]>, width? = 560.0, height? = 320.0, trend? = false, dot? = 3.0)`

x/y point series

| Param | Type | Default | Notes |
|---|---|---|---|
| points | Store[Array[(Double, Double)]] | required | (x, y) points |
| width / height | Double | 560 / 320 | canvas size |
| trend | Bool | false | least-squares trend line |
| dot | Double | 3 | dot edge length (px) |
 (small squares), dual adaptive axes + grid; `trend = true` overlays a least-squares trend line (red). First draw of 10000 points measured ~3ms. Box-select zoom is post-poned, not implemented.

```moonbit
let pts = @yue.Store::new([(0.0, 1.0), (1.0, 3.0), (2.0, 5.0)])
@yue.scatter_t(pts, trend=true)
```

## Icons

136 built-in vector icons (arrows / file / editing / view / navigation / media / messaging / system / development / data / status, styled after Tabler / Lucide).

| API | Purpose |
|---|---|
| `icon(kind : IconKind, size? = 16.0, color? = "")` | icon node: theme regular color by default, fixed color via color |
| `icon_button_t(kind, on_click?, size? = 28.0, tip? = "")` | square icon button: hover grey fill + text brightening, Enter/Space activates; non-empty tip attaches a native tooltip; marginRight 6 for toolbar rows |
| `draw_icon(p : Painter, kind, cx, cy, s, color)` | unified self-drawing entry (center coordinates + edge length) |
| `all_icons()` / `icon_name(kind)` | full list / name lookup |

```moonbit
@yue.icon(@yue.Search, size=18.0)
@yue.icon_button_t(@yue.Plus, on_click=fn() { add_row() }, tip="Add row")

// self-drawing entry (inside an on_draw callback):
@yue.draw_icon(p, @yue.Star, 24.0, 24.0, 16.0, "#D9822B")
```

## Feedback

### Alert banners alert / alert_closeable

`alert(text, t : SemanticType, height? = 40.0)` / `alert_closeable(text, t)`

Light fill of the type + 4px left color bar + same-family dark text, full width; the latter adds a right-side close button that hides the whole banner.

```moonbit
@yue.alert("Saved", @yue.Success)
@yue.alert_closeable("A new version is available", @yue.Info)
```

### Result result

`result(t, title, desc, children : Array[Node])` — large colored symbol + title + description + custom button area.

```moonbit
@yue.result(@yue.Success, "Submitted", "Results arrive within one business day", [@yue.button_t("OK")])
```

### Empty state empty

`empty(desc)` — grey placeholder block + centered caption.

```moonbit
@yue.empty("No data")
```

### Dialog dialog_t

`dialog_t(visible : Store[Bool], title, children : Array[Node], width? = 420.0, confirm_text? = "确定", cancel_text? = "取消", on_confirm?, on_cancel?, close_on_mask? = false)`

In-app dialog: same-window mask (semi-transparent black, absolute relative to the mount container — mounted at the window root it covers the whole window) + centered panel (title bar with ✕ + body + right-aligned buttons). `visible` drives show/hide; ✕ / cancel / confirm auto-close after the callback, empty text hides that button (both empty hides the whole row), close_on_mask=true also closes on mask clicks. Visually modal, not keyboard-modal.

```moonbit
let show = @yue.Store::new(false)
@yue.dialog_t(show, "Confirm delete", [@yue.label_t("This cannot be undone. Sure?")],
  confirm_text="Delete", on_confirm=fn() { remove() }, close_on_mask=true)
```

### Toast toast_layer

`toast_layer(duration_ms? = 2600) -> (Node, (String, SemanticType) -> Unit)`

Mount the layer node at the window root (absolute top strip, no layout space); the push function shows a semantic toast bar (panel background + border + type icon), auto-removed after 2.6s by default, multiple bars stack top-down; call it after the layer is mounted.

```moonbit
let (layer, toast) = @yue.toast_layer()
// after mounting layer at the window root:
toast("Saved", @yue.Success)
```

### Context menu context_menu_for

`context_menu_for(content : Node, items : Array[(String, () -> Unit)])` — wrap any node with a native right-click menu, label "-" draws a separator; the popup position is converted to screen coordinates via `bounds_in_screen`, and the menu is rebuilt on each right-click.

```moonbit
@yue.context_menu_for(row_view, [("Copy", fn() { copy() }), ("-", fn() {}), ("Delete", fn() { remove() })])
```

## Overlays

### Tooltip tooltip_t

`tooltip_t(content : Node, tip)` — wrap any node with a hover tooltip: after a 500ms hover a themed self-drawn bubble pops below the control (width adapts to the text, flips above when there is no room below) and dismisses on leave or press; identical on all three platforms. Use popover_t for a themed bubble with arbitrary content.

```moonbit
@yue.tooltip_t(@yue.button_t("Delete"), "Delete this item")
```

### Popover popover_t

`popover_t(trigger : Node, content : Node, width, height)` — clicking the trigger opens arbitrary Node content below it; click again to toggle closed.

```moonbit
@yue.popover_t(@yue.button_t("More"), filter_panel, 240.0, 160.0)
```

### Dropdown menu dropdown_menu

`dropdown_menu(trigger : String, items, on_select : (Int) -> Unit, width? = 160.0)` — trigger text + dropdown arrow; clicking opens the item list: hover highlight, click calls back the index and closes; `"-"` in items draws a separator.

```moonbit
@yue.dropdown_menu("Actions", ["Edit", "-", "Delete"], fn(i) { handle(i) })
```

### Carousel carousel_t

`carousel_t(pages : Array[Node], width? = 360.0, height? = 180.0, interval_ms? = 3000)` — panel sequence + side arrows + bottom dots; with interval_ms > 0 it auto-advances every interval milliseconds (paused on hover), arrows/dots switch manually.

```moonbit
@yue.carousel_t([banner1, banner2], interval_ms=4000)
```

State coordination across components goes through `Store` (subscribe / map / bind_label) or signals (`Signal`: computed with automatic dependency tracking, batch updates; pass a `sig.store()` view to component APIs taking a Store); see [declarative.md](declarative.md). Chinese version: [docs/zh/components-ui.md](zh/components-ui.md).
