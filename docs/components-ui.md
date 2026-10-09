# Themed Component Library Quick Reference

Themed component library quick reference: a full set of Element-Plus-style UI components (buttons / input / selection / forms / navigation / layout / data display / icons / feedback / overlays). Every function is called via `@components` (add `"NoahLiu/moonbit-libyue/yue/components"` to your `moon.pkg` imports; the `Node` type and `mount` come from `@declarative`, i.e. also import `"NoahLiu/moonbit-libyue/yue/declarative"`) and returns a `Node` that goes straight into the UI tree. Optional parameters (marked `?` in the signatures below) must be passed by name, e.g. `date_picker_t(value=day)`; parameters without `?` are positional. Reactive `Store` / `Signal` parameters are covered in [declarative.md](declarative.md); native controls (Window / Label / Button / Entry, etc.) are in [components.md](components.md).

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

### Unified style channel

Every themed component exposes `style?` (style key-value pairs, numeric and string mixed; key table in [layout.md](layout.md)) and `handle?` (receives the outermost container on mount) on its outermost container. Component defaults (size / margin / direction) live in a default style table; caller `style` keys are applied last and can override them:

```moonbit
// Override width and margins (other defaults preserved)
@components.input_t(text="Name", style=[("width", 160.0), ("marginBottom", 4.0)])
// slider fills the parent width by default; fix width by also clearing grow
@components.slider_t(v, style=[("flexgrow", 0.0), ("width", 240.0)])
```

`style` is the single entry for layout customization — component signatures no longer carry layout named parameters such as margin / width / height / spacing. Named parameters that remain are semantic/structural: `size` on `avatar` / `icon` (drawn content size), `width` on `table_t` (column-distribution basis) and `row_height`, `width` / `height` on `popover_t` (native popup window size, not layout), `width` on `transfer` (column width), `ratio` on `hsplit` / `vsplit` (drag geometry), plus data/interaction parameters (min/max/step/placeholder/clearable/foldable etc.).

`style` is applied once at mount; prefer the theme palette for colors — colors set via `style` may conflict with theme switching (`theme_apply`).

```moonbit
let l = @yue.Label::make("Title")
@yue.theme_bind_fg(l, fn() { @yue.theme_current().text_regular })
let panel = @yue.Container::make()
@yue.theme_bind_bg(panel, fn() { @yue.theme_current().bg_panel })
```

## Buttons and text

### Themed button button_t

`button_t(text, on_click?, variant? = Soft, color? = "", background_color? = "", style?, handle?)`

Self-drawn button; hover changes stay within the theme palette.

| Param | Type | Default | Notes |
|---|---|---|---|
| text | String | required | button text |
| on_click | () -> Unit | no-op | click callback |
| variant | ButtonVariant | `Soft` | `Solid` solid white text / `Soft` light fill / `Text` no fill / `Danger` danger color |
| color | String | `""` | text color override: non-empty uses it in all states (hover no longer recolors) |
| background_color | String | `""` | background color override: non-empty uses it in all states (hover no longer recolors) |

Hover behavior: Solid / Danger darken, Soft goes solid white, Text gets a grey fill; once color / background_color are passed, the given colors win and hover no longer recolors.

```moonbit
@components.button_t("OK", on_click=fn() { submit() })
@components.button_t("Delete", variant=@components.Danger)
@components.button_t("Custom", color="#ffd700", background_color="#1a1a2e")
```

### Themed label label_t

`label_t(text, role? = Body, style?, handle?)`

Unified font size / color per text role, left-aligned; accepts layout styles and a handle callback.

| Param | Type | Default | Notes |
|---|---|---|---|
| text | String | required | text |
| role | TextRole | `Body` | `Title` / `Section` / `Body` / `Secondary` / `Accent` |
| style | style key-value pairs (numeric + string mixed) | `[]` | see [layout.md](layout.md) |
| handle | (Label) -> Unit | no-op | post-creation callback receiving the underlying Label |

```moonbit
@components.label_t("Settings", role=@components.Title)
@components.label_t("Current user: admin", role=@components.Secondary)
```

### Link link

`link(text, on_click)` — theme-colored text, darkens on hover with an underline-colored bar, click callback.

```moonbit
@components.link("View details", fn() { open_detail() })
```

## Input

### Themed single-line input entry_t

`entry_t(text? = "", password? = false, on_input?, style?, handle?)`

Unified font and line height; the text color follows the theme and cannot be customized (platform limitation, see [adaptation.md](adaptation.md)).

| Param | Type | Default | Notes |
|---|---|---|---|
| password | Bool | false | password mode |
| on_input | (String) -> Unit | no-op | content-change callback, receives the current text |

```moonbit
let name = @yue.Store::new("")
@components.entry_t(text="prefill", on_input=fn(s) { name.set(s) })
```

### Bordered input input_t

`input_t(text? = "", password? = false, clearable? = false, on_input?, invalid? = Store::new(false), style?, handle?)`

Self-drawn 1px outer border (turns theme primary on focus) + white background, straight corners.

| Param | Type | Default | Notes |
|---|---|---|---|
| margin / width / height | Double | 0 / 280 / 32 | outer margin and size, set via `style` |
| clearable | Bool | false | shows ✕ on the right on hover when non-empty; click clears |
| invalid | Store[Bool] | false | when true the border turns danger red (light form validation), reacts to Store set |

```moonbit
let valid = @yue.Store::new(false)
@components.input_t(text="admin", clearable=true, invalid=valid, on_input=fn(s) { check(s) })
```

### Number input input_number

`input_number(value : Store[Double], min? = 0.0, max? = 100.0, step? = 1.0, num_width? = 64.0, style?, handle?)`

-/+ buttons step the value, clamped to range; state lives in `Store[Double]`.

```moonbit
let count = @yue.Store::new(1.0)
@components.input_number(count, min=1.0, max=10.0)
```

### Multi-line input textarea_t

`textarea_t(text? = "", on_input?, clearable? = false, invalid? = Store::new(false), style?, handle?)`

Same pattern as input_t: self-drawn 1px border (turns theme primary on focus) + 8px inset; overflow scrolls per platform. clearable / invalid semantics match input_t.

```moonbit
@components.textarea_t(text="line one\nline two", style=[("width", 320.0), ("height", 120.0)])
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
@components.checkbox_t("Remember me", checked=true, on_change=fn(v) { remember(v) })
```

### Radio group radio_group

`radio_group(options, selected : Store[String], disabled? = false)`

Selected item shows a solid square + theme-colored text, unselected a hollow square; clicks are mutually exclusive.

```moonbit
let choice = @yue.Store::new("A")
@components.radio_group(["A", "B", "C"], choice)
```

### Switch switch_t

`switch_t(checked : Store[Bool], disabled? = false)` — track + knob: on = theme-blue track with the knob right, off = light-grey track with the knob left; state lives in `Store[Bool]`.

```moonbit
let enabled = @yue.Store::new(true)
@components.switch_t(enabled)
```

### Slider slider_t

`slider_t(value : Store[Double], min? = 0.0, max? = 100.0, step? = 1.0, on_change?, style?, handle?)`

Self-drawn: light-grey track + theme-colored fill + square thumb; click the track or drag the thumb, the value is step-quantized into `value` (external Store set works too); on_change fires on every change including during drags.

```moonbit
let volume = @yue.Store::new(0.5)
@components.slider_t(volume, max=1.0, step=0.1, on_change=fn(v) { set_volume(v) })
```

## Selection

### Dropdown select select_t

`select_t(options, value : Store[String], on_change?, clearable? = false, style?)`

Fully self-drawn: click opens the candidate list, hover highlight, theme-colored ✓ on the current pick, click to fill and close, blur closes; same behavior on all platforms. With clearable=true, hovering a non-empty field shows ✕ beside the arrow; click clears the selection (value set to "", `on_change("")`).

```moonbit
let color = @yue.Store::new("Red")
@components.select_t(["Red", "Green", "Blue"], color, clearable=true, on_change=fn(s) { recolor(s) })
```

### Date picker date_picker_t

`date_picker_t(value? : Store[DateYMD?], on_change?, placeholder? = "请选择日期", clearable? = false, style?)`

Fully self-drawn: input-style field; clicking opens the `calendar_t` month panel, pick to fill and close, blur closes; with clearable=true, hovering a set value shows ✕ beside the arrow to clear (no on_change).

```moonbit
let day : @yue.Store[@components.DateYMD?] = @yue.Store::new(None)
@components.date_picker_t(value=day, on_change=fn(d) { picked(d) })
```

### Date range picker date_range_picker_t

`date_range_picker_t(value? : Store[DateRange], on_change?, placeholder? = "请选择日期区间", clearable? = false, style?)`

The field shows "start ~ end"; clicking opens the range calendar — first pick sets the start, second sets the end (swapped automatically if earlier), then it closes and fires `on_change(start, end)`; in-between days get a light theme fill, endpoints solid squares; clicking the field again starts a new range. clearable clears both ends.

```moonbit
let range : @yue.Store[@components.DateRange] = @yue.Store::new({ start: None, end: None })
@components.date_range_picker_t(value=range, on_change=fn(s, e) { show(s, e) })
```

### Time range picker time_range_picker_t

`time_range_picker_t(value? : Store[TimeRange], on_change?, placeholder? = "请选择时间区间", clearable? = false, style?)`

The field shows "start : end" as HH:MM; clicking opens start/end stepper rows (hour 0-23 / minute 0-59, backed by `input_number`), every step fires `on_change(start, end)` immediately; both default to 00:00, and the popover closes on field blur.

```moonbit
let tr : @yue.Store[@components.TimeRange] = @yue.Store::new({ start: None, end: None })
@components.time_range_picker_t(value=tr, on_change=fn(s, e) { show(s, e) })
```

### Date-time range picker datetime_range_picker_t

`datetime_range_picker_t(value? : Store[DateTimeRange], on_change?, placeholder? = "请选择日期时间区间", clearable? = false, style?)`

The field shows "start date start HH:MM ~ end date end HH:MM"; the popover is a range calendar + separator + start/end time stepper rows + a "Done" button; once the date range is complete, any time change fires `on_change(start date, start time, end date, end time)`. Value type `DateTimeRange{ start : (DateYMD, TimeHM)?, end : (DateYMD, TimeHM)? }`.

```moonbit
let dtr : @yue.Store[@components.DateTimeRange] = @yue.Store::new({ start: None, end: None })
@components.datetime_range_picker_t(value=dtr, on_change=fn(sd, st, ed, et) { show(sd, st, ed, et) })
```

### Calendar panel calendar_t

`calendar_t(on_pick?, value? : Store[DateYMD?])`

Fully self-drawn month panel: ‹/› month nav + weekday row + 42-cell grid, adjacent-month days dimmed, "today" in theme primary, the selected day a solid theme square; clicking a day of the current month fires on_pick and writes value. `DateYMD::format()` renders `YYYY-MM-DD`, `TimeHM::format()` renders `HH:MM`.

```moonbit
@components.calendar_t(on_pick=fn(d) { picked(d) })
```

### Color picker color_picker_t

`color_picker_t(value : Store[String], colors?, style?)`

Dropdown form: the trigger field (current swatch + hex + arrow) opens the preset palette; clicking a swatch writes `value` (`"#RRGGBB"`) and closes, the selected swatch gets a theme outline + white check, blur closes; the palette is customizable (15 colors by default).

```moonbit
let hex = @yue.Store::new("#2D68C4")
@components.color_picker_t(hex)
```

### Rating rate_t

`rate_t(value : Store[Int], max? = 5, on_change?)` — star sequence: filled theme color when on, outlined grey when off, hover preview, click writes `value` (0..max).

```moonbit
let stars = @yue.Store::new(4)
@components.rate_t(stars)
```

## Forms

### Form item form_item

`form_item(label, control : Node, label_width? = 90.0, error? = Store::new(""))`

Left label (grey, fixed width) + right control area, vertically centered; `error` is a validation message Store — when non-empty, danger-red text appears below the control row (row height is reserved, so appearing/disappearing errors cause no layout shift).

```moonbit
let err = @yue.Store::new("")
@components.form_item("Username", @components.input_t(text="admin"), error=err)
```

### Form form

`form(title, items : Array[Node])` — group title + a set of form items.

```moonbit
@components.form("Account", [
  @components.form_item("Username", @components.input_t()),
  @components.form_item("Password", @components.input_t(password=true)),
])
```

## Navigation

### Side menu side_menu

`side_menu(items, selected : Store[String], icons? = [], style?)`

Hover light grey, selected theme-light-blue fill + theme-colored text + 3px left accent bar, 4px rounded corners. `icons` maps "item text → icon" (not drawn by default); `selected` is shared state — the main area subscribes to the same Store for `set_visible` page switching.

```moonbit
let page = @yue.Store::new("Home")
@components.side_menu(["Home", "Settings", "About"], page)
```

### Grouped side menu side_menu_sections

`side_menu_sections(sections : Array[(String, Array[String])], selected : Store[String], icons? = [], foldable? = true, style?, handle?)`

Group caption row (secondary small text + collapse arrow on the right) + group items (same rendering/selection as side_menu); with foldable=true the group can be collapsed/expanded (all expanded by default, Enter/Space works too).

```moonbit
let page = @yue.Store::new("Buttons")
@components.side_menu_sections([("Components", ["Buttons", "Input"]), ("System", ["About"])], page)
```

### Segmented control segmented

`segmented(options, selected : Store[String])` — selected white fill + theme-colored text, hover grey, straight corners.

```moonbit
let view = @yue.Store::new("List")
@components.segmented(["List", "Grid"], view)
```

### Breadcrumb breadcrumb

`breadcrumb(items, selected : Store[String])` — current item dark and non-clickable, the rest grey and clickable, turning theme-colored on hover.

```moonbit
let cur = @yue.Store::new("Network")
@components.breadcrumb(["Home", "Settings", "Network"], cur)
```

### Pagination pagination

`pagination(current : Store[Int], pages)` — ‹ page numbers ›, current page solid theme fill with white text, hover light blue, 28×28 straight corners; `current` starts at 1, clicks write straight to the source Store, ‹ › are clamped at the bounds.

```moonbit
let page_no = @yue.Store::new(1)
@components.pagination(page_no, 10)
```

### Steps steps

`steps(items, current : Store[Int])` — number squares (done light blue / current solid / todo grey) + text + connector lines.

```moonbit
let step = @yue.Store::new(1)
@components.steps(["Fill in", "Verify", "Done"], step)
```

### Tabs tabs_t

`tabs_t(pages : Array[(String, Node)], selected? : Store[Int])`

Top form: tab header row (selected theme-colored text + 2px bottom indicator, darkens on hover) + content area switched via `set_visible`; `selected` is a page-index Store (internal 0 by default).

```moonbit
@components.tabs_t([("Overview", overview_view), ("Log", log_view)])
```

## Layout and separation

### Divider divider

`divider(vertical? = false, style?, handle?)` — horizontal (default, 1px tall, flex width) or vertical (1px wide, height follows the parent container); side margins default to 10px, override via style. The color is read from the theme at mount, so it takes effect on UI rebuild.

```moonbit
@components.divider(style=[("marginTop", 16.0), ("marginBottom", 16.0)])
@components.divider(vertical=true)
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

`tag(text, color, style?, handle?)` / `tag_of_type(text, t : SemanticType, style?, handle?)`

The former is a solid colored tag (custom color), the latter a light-fill tag with same-family dark text (`Primary` / `Success` / `Warning` / `Danger` / `Info`); straight corners, width adapts to the text.

```moonbit
@components.tag("v1.2", "#2D68C4")
@components.tag_of_type("Running", @components.Success)
```

### Avatar avatar

`avatar(letter, color, size? = 36.0)` — square solid fill with a white letter centered.

```moonbit
@components.avatar("Y", "#2D68C4", size=40.0)
```

### Badge badge_count / badge_dot

`badge_count(count)` is a red-background white-text chip (width adapts, color follows the theme); `badge_dot(color? = "")` is an 8×8 dot.

```moonbit
@components.badge_count(3)
@components.badge_dot(color="#2E9E5B")
```

### Statistic statistic

`statistic(title, value : Store[String])` — large reactive number + grey title.

```moonbit
let visits = @yue.Store::new("1,024")
@components.statistic("Visits today", visits)
```

### Linear progress progress_line

`progress_line(value : Store[Double], style?, handle?)` — light-grey track + theme-colored fill (bar height defaults to 8, override via style), value in 0..1, changes repaint automatically.

```moonbit
let ratio = @yue.Store::new(0.42)
@components.progress_line(ratio, style=[("height", 6.0)])
```

### Descriptions descriptions

`descriptions(pairs : Array[(String, String)])` — two-column grid with grey keys and dark values.

```moonbit
@components.descriptions([("Name", "libyue"), ("Version", "0.15.6"), ("Platform", "Linux")])
```

### Timeline timeline

`timeline(items : Array[(String, String, SemanticType)])` — color dot + vertical line on the left, title + description on the right; items are (title, description, semantic type), fixed 56px row height.

```moonbit
@components.timeline([
  ("Build", "compiled", @components.Success),
  ("Test", "45/45 passed", @components.Success),
  ("Release", "awaiting review", @components.Warning),
])
```

### Collapse collapse

`collapse(panels : Array[(String, Array[Node])])` — click the title row to toggle content visibility, panels collapse independently, only the first panel is expanded initially.

```moonbit
@components.collapse([
  ("General", [@components.label_t("Basic options", role=@components.Body)]),
  ("Advanced", [@components.label_t("Debug options", role=@components.Body)]),
])
```

### Card card

`card(title, children : Array[Node], style?, handle?)` — title bar (bold, bottom separator) + border (card height defaults to 160, override via style); content starts below the title bar.

```moonbit
@components.card("Summary", [@components.statistic("Tasks", done)], style=[("height", 120.0)])
```

### Code highlighting code_view

`code_view(lines, lang? = "moonbit", font_size? = 13.0, line_numbers? = false, style?, handle?)`

Per-token highlighting with manual layout — consistent behavior on all platforms (including Windows). Color classes: keywords purple / types and capitalized constructors yellow / calls followed by `(` blue / numbers orange / strings green / line comments gray; punctuation and operators tokenize separately (`items.push(`, `0..<` each color correctly). lang keyword sets: moonbit / js / ts / python / rust / c / go / bash / sql (case-insensitive); line_numbers=true draws a left gutter.

```moonbit
@components.code_view(
  ["fn main() {", "  println(\"hello\")", "}"],
  lang="moonbit",
  line_numbers=true,
)
```

### Markdown rendering markdown_view

`markdown_view(source, style?)` — headings 1-6 (ATX/Setext), paragraphs, **bold**, *italic*, ~~strikethrough~~ (line drawn per range), `inline code`, [links](url) (click opens the default browser, hand cursor and address tooltip on hover; reference-style links resolve from the document link definitions), autolinks, ordered/unordered lists (with start), task lists (real checkboxes, click to toggle), blockquotes (theme-colored bar), GFM alerts, rules, fenced and indented code blocks (language from the fence marker, backed by code_view), tables (equal-width column grid, rich-text cells, column alignment from `:---` `:---:` `---:`), definition lists, footnotes (superscript references numbered in order of appearance, referenced definitions rendered after a rule at the end), block images (loaded from local paths or `file://`, scaled proportionally up to 560 wide; on load failure or network URLs falls back to the alt text, inline images fall back to alt); style ranges stay aligned after non-BMP characters (emoji) via UTF-16 indexing; inline HTML and HTML blocks are not rendered; consistent rendering across platforms, link/code colors follow the theme.

```moonbit
@markdown.markdown_view("# Heading\n\nBody **bold**, ~~struck~~ and a [link](https://libyue.com).\n\n- [x] Task item\n\n| Col A | Col B |\n|:--|--:|\n| 1 | 2 |\n\nA footnote[^1].\n\n[^1]: Footnote body.")
```

### Table table_t

`table_t(columns, rows : Store[Array[TableRow]], width? = 560.0, row_height? = 36.0, selection? : Store[Array[Int]], sort? : Store[TableSort], on_row_click?, style?, handle?)`

Header + zebra stripes + hover highlight + Store-driven (a set rebuilds all rows and clears the selection). Columns via `TableColumn::make(title, width, align?, sortable?)` (width ≤ 0 = flexible columns sharing the remaining width; `sortable=false` keeps a column out of header sorting). Cells are `TableCell`: `CellText` (single-line ellipsis when overflowing; re-truncated at the new width after column resize) / `CellTag(text, semantic type)` / `CellColorBox(hex, name)` / `CellLines(multi-line, row auto-grows)`; `TableRow::make(string array)` builds plain rows. Without `selection` rows single-select on click; pass `selection` to enable a checkbox column (row click toggles, header select-all/clear, dash when partial, selected rows get a light-blue fill); the callback receives `(index, row)`.

Header sorting and column resizing: pass `sort` (a `Store[TableSort]`; `TableSort{ column, asc }` where `column` is the column-definition index, < 0 = unsorted) and sortable columns keep a grey ↕ double-triangle hint at the right of the header so users can tell the column is clickable; clicking runs a three-state cycle "new column ascending → same column descending → click again to clear" (column set back to -1, subscribers restore the original order), and the actively sorted column switches to a solid theme-colored ▲ / ▼ so the sort state is obvious at a glance; actual data sorting is up to you — subscribe to the store, sort, and write back to `rows`. Header column boundaries stay visible as light lines and turn theme-colored on hover / while dragging; press within 4px of either edge of a column (no handle on the last column's right edge) to resize, with the two neighbors trading width (minimum 56px), mouse capture keeping the drag alive, and no row rebuild or selection loss.

```moonbit
let rows = @yue.Store::new([@components.TableRow::make(["A", "1"]), @components.TableRow::make(["B", "2"])])
let sort = @yue.Store::new(@components.TableSort::{ column: -1, asc: true })
sort.subscribe(fn(st) { /* re-sort by st.column / st.asc, then rows.set(...) */ })
@components.table_t(
  [@components.TableColumn::make("Name", 120.0), @components.TableColumn::make("Count", 80.0, align=@yue.Center)],
  rows,
  sort=sort,
)
```

### Virtualized table table_v_t

`table_v_t(columns, rows : Store[Array[TableRow]], width? = 560.0, height? = 360.0, row_height? = 32.0, selection? : Store[Array[Int]], sort? : Store[TableSort], on_row_click?, fill? = false, style?, handle?)`

The 10k+-row form of table_t: only visible rows are painted, self-managed scrolling (wheel / drag scrollbar / keyboard), free of the scroll container's content-height limit; cell rendering matches table_t (CellLines clamps to two lines within the row height), and column / selection / sort (header arrows) / column-resize semantics are identical.

```moonbit
let rows = @yue.Store::new([@components.TableRow::make(["1", "A"]), @components.TableRow::make(["2", "B"])])
@components.table_v_t(
  [@components.TableColumn::make("No.", 90.0), @components.TableColumn::make("Name", 160.0)],
  rows,
  height=480.0,
)
```

### Tree tree

`tree(root : Array[TreeNode])` — indented hierarchy + click to expand/collapse (arrow indicator when a node has children). Node type `TreeNode{ label : String, children : Array[TreeNode] }`.

```moonbit
@components.tree([
  { label: "src", children: [{ label: "main.mbt", children: [] }] },
  { label: "README.md", children: [] },
])
```

### Transfer transfer

`transfer(left_items : Store[Array[String]], right_items : Store[Array[String]], width? = 160.0)` — two columns, click a row to select it (solid-square marker), the middle ›/‹ buttons move selected items between columns; data is driven by two Stores.

```moonbit
let left = @yue.Store::new(["A", "B"])
let right = @yue.Store::new(["C"])
@components.transfer(left, right)
```

## Charts

The whole chart family (EP Chart counterpart) is self-drawn in pure MoonBit: data flows through `Store`, a set only calls schedule_paint on the canvas — no view-tree rebuild; colors are read from the theme palette at draw time, so `theme_apply` light/dark switches follow immediately. Series colors cycle the four semantic theme colors (line charts ≤4 series), donut charts cycle five.

### Line / area chart line_chart_t

`line_chart_t(series : Store[Array[LineSeries]], area? = false, y_range?, show_last? = true, fill? = false, style?, handle?)`

Multi-series line chart over fixed-length rolling windows.

| Param | Type | Default | Notes |
|---|---|---|---|
| series | Store[Array[LineSeries]] | required | multi-series data, see push helpers below |
| width / height | Double | 560 / 260 | canvas size, set via `style` |
| area | Bool | false | semi-transparent area fill |
| y_range | (Double, Double)? | None | manual y range; None = auto |
| show_last | Bool | true | right-edge latest-value label |
 `LineSeries::make(name, max_points?)` creates a series (window capacity defaults to 100, oldest dropped on overflow); push points with `series_push(store, series index, value)` (or `win_push(window, max_points, value)` for a new window, then set it wholesale). The y-axis auto-ranges (window min/max + 8% padding) or is pinned via `y_range = (low, high)`; horizontal grid + left ticks; `area = true` adds semi-transparent area fill (to the zero line when 0 is in range, plot bottom for all-positive, plot top for all-negative); `show_last` toggles the right-edge latest-value label.

Rendering strategy: when points outnumber pixel columns the chart decimates to columns (keeping each column's min/max extremes) and switches to rect paths — area mode fills one rect per column up to the anchor (the fill's top edge *is* the line), line mode draws a min..max vertical bar per column; when points are fewer than columns it uses a true polyline plus polygon area fill. Per-frame cost is decoupled from window size (1000 points × 4 series measured ~3ms, see adaptation.md).

```moonbit
let series = @yue.Store::new([
  @charts.LineSeries::make("CPU", max_points=120),
  @charts.LineSeries::make("Memory", max_points=120),
])
ignore(@yue.set_timer(500, fn() {
  @charts.series_push(series, 0, cpu_usage())
  @charts.series_push(series, 1, mem_usage())
  true
}))
@charts.line_chart_t(series, style=[("width", 380.0), ("height", 220.0)])
@charts.line_chart_t(series, style=[("width", 380.0), ("height", 220.0)], area=true)
```

### Bar chart bar_chart_t

`bar_chart_t(data : Store[Array[BarItem]], horizontal? = false, y_range? = None, fill? = false, style?, handle?)`

Vertical bars

| Param | Type | Default | Notes |
|---|---|---|---|
| data | Store[Array[BarItem]] | required | category data (values may be negative) |
| width / height | Double | 560 / 280 | canvas size, set via `style` |
| horizontal | Bool | false | horizontal bar form |
 (default) and horizontal bars (`horizontal = true`, for long category names). `BarItem::make(label, value)` with possibly negative values; zero baseline, positive in theme color and negative in red. Hovering highlights the category and annotates its value inline (self-drawn, no popover); category labels thin out and truncate automatically when dense. Full redraw of 200 categories measured ~0.4ms.

```moonbit
let bars = @yue.Store::new([
  @charts.BarItem::make("Jan", 12.0),
  @charts.BarItem::make("Feb", -8.0),
])
@charts.bar_chart_t(bars, style=[("width", 380.0), ("height", 220.0)])
@charts.bar_chart_t(bars, style=[("width", 380.0), ("height", 220.0)], horizontal=true)
```

### Donut / pie chart donut_chart_t

`donut_chart_t(data : Store[Array[DonutSlice]], thickness? = 34.0, center? = "", style?, handle?)`

Proportional sectors

| Param | Type | Default | Notes |
|---|---|---|---|
| data | Store[Array[DonutSlice]] | required | sector data (negatives excluded) |
| width / height | Double | 480 / 240 | canvas size, set via `style` |
| thickness | Double | 34 | ring thickness (0 = solid pie) |
| center | String | "" | center text; empty = total value |
 (clockwise from 12 o'clock, five-color cycle, adjacent sectors differ); the center shows the total (pass `center` to override the text); a right-side legend (swatch + label + value and percentage). Hovering explodes a sector by 4px and highlights its legend row. `DonutSlice::make(label, value)`; negative values are excluded from proportions. Redraw of 50 sectors measured ~2.9ms.

```moonbit
let slices = @yue.Store::new([
  @charts.DonutSlice::make("Direct", 335.0),
  @charts.DonutSlice::make("Search", 510.0),
])
@charts.donut_chart_t(slices, style=[("width", 420.0), ("height", 220.0)])
```

### Gauge gauge_t

`gauge_t(value : Store[Double], thresholds?, style?, handle?)`

Single-value percentage ring

| Param | Type | Default | Notes |
|---|---|---|---|
| value | Store[Double] | required | 0..1, clamped |
| width / height | Double | 240 / 170 | canvas size, set via `style` |
| thresholds | Array[(Double, String)] | [] | ascending (upper bound, color) bands; empty = theme primary |
 (270° sweep starting at 135°, opening downward) + big center number. `value` is 0..1 (clamped); `thresholds` is an ascending `[(upper bound, color), ...]` and the value arc takes the color of the band it falls into (empty table = theme primary), e.g. `[(0.6, green), (0.85, orange), (1.0, red)]`. Smooth interpolation: after a target change a 16ms timer closes 25% of the remaining gap per tick (not animation-frame driven), so 2Hz updates never jump.

```moonbit
let usage = @yue.Store::new(0.0)
@charts.gauge_t(usage, thresholds=[
  (0.6, @yue.theme_current().success),
  (0.85, @yue.theme_current().warning),
  (1.0, @yue.theme_current().danger),
])
```

### Scatter chart scatter_t

`scatter_t(points : Store[Array[(Double, Double)]>, trend? = false, dot? = 3.0, style?, handle?)`

x/y point series

| Param | Type | Default | Notes |
|---|---|---|---|
| points | Store[Array[(Double, Double)]] | required | (x, y) points |
| width / height | Double | 560 / 320 | canvas size, set via `style` |
| trend | Bool | false | least-squares trend line |
| dot | Double | 3 | dot edge length (px) |
 (small squares), dual adaptive axes + grid; `trend = true` overlays a least-squares trend line (red). First draw of 10000 points measured ~3ms. Box-select zoom is post-poned, not implemented.

```moonbit
let pts = @yue.Store::new([(0.0, 1.0), (1.0, 3.0), (2.0, 5.0)])
@charts.scatter_t(pts, trend=true)
```

The nine charts below and the interaction layer are likewise self-drawn in pure MoonBit and driven by `Store` data: a set only calls schedule_paint on the canvas — no view-tree rebuild — and colors are picked from the theme at draw time, so `theme_apply` switches follow immediately. Unless noted otherwise, all of them can override the canvas size via `style` and stretch horizontally to fill the parent via `fill=true`.

### Tree chart tree_chart_t

`tree_chart_t(root : Store[TreeItem], orientation? = "horizontal", fill? = false, style?, handle?)`

Hierarchical tree: leaf nodes share slots evenly along the spread direction, parent nodes take the midpoint of their children, and depth positions nodes in layers; links are right-angle elbow lines.

| Param | Type | Default | Notes |
|---|---|---|---|
| root | Store[TreeItem] | required | tree root node (`children` is a mutable child list; push to add/remove, then set to repaint) |
| orientation | String | "horizontal" | "horizontal" spreads sideways (root at left, leaves at right); "vertical" spreads downward (root at top, leaves at bottom) |
| fill | Bool | false | no fixed width; stretches horizontally to fill the parent |
| width / height | Double | 560 / 320 | canvas size (when fill=false), set via `style` |

`TreeItem::make(name, value? = None)` creates a node: `value` is the dot-size dimension (None, or no value anywhere in the tree, makes all dots equal size); `children` can still be pushed after creation. The node dot radius ∝ value (relative to the subtree maximum), depth is shaded along a theme-primary gradient, and every node carries a name label. Companion pure functions: `tree_depth` (subtree height), `tree_leaf_count` (leaf count), `tree_max_value` (peak), `tree_vertical(orientation)` (whether the form is vertical).

```moonbit
let root = @charts.TreeItem::make("repo")
let src = @charts.TreeItem::make("src", value=80.0)
src.children.push(@charts.TreeItem::make("main.mbt", value=40.0))
root.children.push(src)
root.children.push(@charts.TreeItem::make("README.md", value=10.0))
let tree = @yue.Store::new(root)
@charts.tree_chart_t(tree, style=[("width", 420.0), ("height", 260.0)])
@charts.tree_chart_t(tree, orientation="vertical") // vertical form
```

### Treemap tm_chart_t

`tm_chart_t(items : Store[Array[TmItem]], levels? = 2, gap? = 4.0, fill? = false, style?, handle?)`

Hierarchical data is split orthogonally with area ∝ value (squarified aspect-ratio optimization).

| Param | Type | Default | Notes |
|---|---|---|---|
| items | Store[Array[TmItem]] | required | top-level items (each item's children expands recursively) |
| levels | Int | 2 | expansion depth: 1 = lay out the top level only; >1 yields the parent rect to its children and lays out recursively |
| gap | Double | 4 | sibling cell gap (px) |
| fill | Bool | false | no fixed width; stretches horizontally to fill the parent |
| width / height | Double | 560 / 360 | canvas size (when fill=false), set via `style` |

`TmItem::make(name, value? = 0.0, children? = [])` creates a node; the value rule is `tm_value_of` — a positive own value wins, otherwise children are summed recursively, and all-zero degenerates to 0 (excluded from layout). Sibling cells spread their shading evenly along the theme primary's HSL lightness axis (same color family, neighbors distinguishable); parent cells get a light background plus a name band; in-cell labels `tm_label_lines` give name + value on two lines (two lines only when the cell height is ≥30, name only for 16..30, nothing below that, truncated to the available width). Hover hits the deepest visible cell (brightened + outlined); the hit table is rebuilt on every on_draw, sharing one layout with drawing.

```moonbit
let tm = @yue.Store::new([
  @charts.TmItem::make(
    "East China",
    children=[
      @charts.TmItem::make("Shanghai", value=320.0),
      @charts.TmItem::make("Jiangsu", value=260.0),
    ],
  ),
  @charts.TmItem::make("South China", children=[@charts.TmItem::make("Guangdong", value=300.0)]),
])
@charts.tm_chart_t(tm, levels=2, gap=3.0, style=[("width", 420.0), ("height", 260.0)])
```

### Sunburst chart sun_chart_t

`sun_chart_t(data : Store[SunItem], inner? = 0.0, show_labels? = true, center_text? = None, fill? = false, style?, handle?)`

Tree data as concentric rings level by level: a parent segment's angular span is divided among its children by aggregated value share.

| Param | Type | Default | Notes |
|---|---|---|---|
| data | Store[SunItem] | required | tree root node |
| inner | Double | 0 | center hole radius (px); ≤ 0 takes 22% of the outer radius |
| show_labels | Bool | true | in-segment name labels (drawn only when the space allows) |
| center_text | String? | None | center text: None = aggregated total + "Total"; `Some("")` hides it; `Some(t)` is custom |
| fill | Bool | false | no fixed width; stretches horizontally to fill the parent |
| width / height | Double | 440 / 380 | canvas size (when fill=false), set via `style` |

`SunItem::make(name, value? = None, children? = [])`: when value is omitted it is filled from the sum of the children's aggregated values. The aggregation rule is `sun_total` — an explicit value > 0 wins, otherwise children are summed recursively, negatives are excluded, and a childless node is 0. Top-level segments of one branch cycle the five semantic theme colors, brightening level by level; segments inset angularly to leave gaps (independent of stroke width).

```moonbit
let sun = @yue.Store::new(
  @charts.SunItem::make(
    "All",
    children=[
      @charts.SunItem::make("Direct", value=335.0),
      @charts.SunItem::make("Search", children=[
        @charts.SunItem::make("Baidu", value=120.0),
        @charts.SunItem::make("Bing", value=80.0),
      ]),
    ],
  ),
)
@charts.sun_chart_t(sun, style=[("width", 380.0), ("height", 320.0)])
@charts.sun_chart_t(sun, inner=40.0, center_text=Some("Total visits"))
```

### Map and flights geo_map_t

`geo_map_t(regions : Store[Array[GeoRegion]], flights? = [], show_labels? = true, fill? = false, style?, handle?)`

GeoJSON regions are drawn under an equirectangular projection (fill + stroke + centroid region-name labels); flights are quadratic Bézier arcs between origin and destination coordinates.

| Param | Type | Default | Notes |
|---|---|---|---|
| regions | Store[Array[GeoRegion]] | required | region table (ring lists, each ring a list of `(lon, lat)` point pairs) |
| flights | Array[GeoFlight] | [] | flights (not backed by a Store; repainting needs a full remount or a change to regions) |
| show_labels | Bool | true | region-name labels (drawn at the centroid, truncated to the available width, only when they fit) |
| fill | Bool | false | no fixed width; stretches horizontally to fill the parent |
| width / height | Double | 560 / 360 | canvas size (when fill=false), set via `style` |

No map dataset is built in: text parsing goes through `geojson_parse(text) -> Result[Array[GeoRegion], GeoError]` (supports FeatureCollection / Feature / bare Polygon / MultiPolygon; malformed geometry yields `GeoError::BadGeometry`), or construct `GeoRegion::make(name?, ring list)` yourself. The projection rect is the merged bounding box of the region rings and flight endpoints, centered and inset by its own aspect ratio (no distortion); with no data it draws "No data". Region fills take the theme primary as the base and tweak lightness by ±0.06 hashed from the region name (same name, same color; unchanged across theme switches); flights are segmented gradient dashes + origin/destination dots + an end arrow — a static rendering with no animation, and no hover. Companion pure functions: `geo_project` (equirectangular projection), `geo_bbox` / `geo_bbox_points`, `geo_fit_rect`, `geo_shoelace` (ring signed area), `geo_ring_centroid` / `geo_region_centroid`, `geo_flight_points` (arc sampling), `geo_quad_bezier`.

```moonbit
let geojson = @yue.read_text_file("china.geojson") // your own text reader is fine
let regions = match geojson {
  Some(text) => @charts.geojson_parse(text) catch { _ => [] }
  None => []
}
@charts.geo_map_t(
  @yue.Store::new(regions),
  flights=[
    @charts.GeoFlight::make((121.47, 31.23), (114.06, 22.54)),
  ],
  style=[("width", 420.0), ("height", 300.0)],
)
```

### Force-directed graph gph_chart_t

`gph_chart_t(data : Store[GraphData], iterations? = 300, show_labels? = true, fill? = false, style?, handle?)`

A node-edge graph is drawn statically after the force simulation converges: Coulomb repulsion between node pairs + Hookean springs on edges (stiffness ∝ weight) + centripetal pull toward the centroid, with damped stepping.

| Param | Type | Default | Notes |
|---|---|---|---|
| data | Store[GraphData] | required | `GraphData::make(node table, edge table)`; edges reference nodes by index |
| iterations | Int | 300 | force simulation steps |
| show_labels | Bool | true | node-name labels (at positions after anti-overlap pushing) |
| fill | Bool | false | no fixed width; stretches horizontally to fill the parent |
| width / height | Double | 560 / 320 | canvas size (when fill=false), set via `style` |

`GraphNode::make(name, value? = 1.0)` (value sets the node circle's area; it does not take part in the force simulation), `GraphEdge::make(source index, target index, weight? = 1.0)` (edges with out-of-range endpoints, self-loops, or weight ≤ 0 neither take part in the simulation nor get drawn). Edges are drawn as semi-transparent parallelogram bands (width ∝ weight), node circles cycle the four semantic theme colors; the simulation has no random source (starting from evenly spaced points on a circle), so identical input always yields identical output. The layout converges once at first draw for the current canvas size and is cached; it is only recomputed when the data is set or the canvas size changes.

```moonbit
let g = @charts.GraphData::make(
  [
    @charts.GraphNode::make("Core", value=10.0),
    @charts.GraphNode::make("Gateway", value=5.0),
    @charts.GraphNode::make("Terminal", value=3.0),
  ],
  [@charts.GraphEdge::make(0, 1, 8.0), @charts.GraphEdge::make(1, 2, 4.0)],
)
@charts.gph_chart_t(@yue.Store::new(g), iterations=200, style=[("width", 420.0), ("height", 300.0)])
```

### Parallel coordinates chart par_chart_t

`par_chart_t(axes : Store[Array[ParAxis]], rows : Store[Array[Array[Double]]], highlight? = -1, fill? = false, style?, handle?)`

N vertical axes are laid out evenly side by side, each normalized on its own range; every data row is one polyline crossing the axes.

| Param | Type | Default | Notes |
|---|---|---|---|
| axes | Store[Array[ParAxis]] | required | `ParAxis::make(name, min? = None, max? = None)`; when only one end is given, the other is still inferred from the data |
| rows | Store[Array[Array[Double]]] | required | data rows, one polyline per row (positions shorter than the column count are treated as missing) |
| highlight | Int | -1 | highlighted row index (when ≥0 that row is redrawn opaque, with vertex dots on every axis) |
| fill | Bool | false | no fixed width; stretches horizontally to fill the parent |
| width / height | Double | 640 / 320 | canvas size (when fill=false), set via `style` |

Each axis carries a name at the top, min/max range labels beside it, and small tick marks on its body; polylines take the series colors alpha-blended (many rows overlapping show density), while the highlighted row uses its opaque own color. `par_axis_range` infers a single axis's range (no padding; a degenerate equal-value range is stretched open around the value), `par_norm` normalizes, and `par_row_vertices` gives a row's vertices for reuse in self-drawing.

```moonbit
let axes = @yue.Store::new([
  @charts.ParAxis::make("Render", 0.0, 100.0),
  @charts.ParAxis::make("IO", 0.0, 100.0),
  @charts.ParAxis::make("Memory", 0.0, 100.0),
])
let rows = @yue.Store::new([[88.0, 72.0, 80.0], [70.0, 90.0, 65.0]])
@charts.par_chart_t(axes, rows, highlight=0, style=[("width", 480.0), ("height", 260.0)])
```

### Theme river chart trv_chart_t

`trv_chart_t(names : Store[Array[String]], values : Store[Array[Array[Double]]], baseline? = TrvZero, tension? = 1.0, show_legend? = true, fill? = false, style?, handle?)`

Multiple series are stacked into a river on an evenly spaced time axis, with smooth curves along each layer's top and bottom edges.

| Param | Type | Default | Notes |
|---|---|---|---|
| names | Store[Array[String]] | required | series names, same order as values (names[i] ↔ values[i]) |
| values | Store[Array[Array[Double]]] | required | each series' values over time (evenly aligned by time index; negatives count as 0, missing positions in short series count as 0) |
| baseline | TrvBaseline | `TrvZero` | `TrvZero` stacks from the bottom (accumulating layer by layer from 0); `TrvSym` is symmetric about the horizontal midline (the classic wiggle center) |
| tension | Double | 1.0 | smoothing tension: 1 = standard Catmull-Rom; 0 = degenerates to a polyline |
| show_legend | Bool | true | right-side legend (swatch + layer name + series total) |
| fill | Bool | false | no fixed width; stretches horizontally to fill the parent |
| width / height | Double | 560 / 320 | canvas size (when fill=false), set via `style` |

Layer colors cycle the four semantic theme colors; the time-axis length is the longest length across all series (`trv_axis_len`). Companion pure functions: `trv_row_at` / `trv_total_at` (value and column total), `trv_stack_offsets` (stacking offsets), `trv_range` (value range), `trv_layer_band` (layer-band pixel box), `trv_series_total`.

```moonbit
let names = @yue.Store::new(["Search", "Direct"])
let values = @yue.Store::new([[120.0, 132.0, 101.0], [220.0, 182.0, 191.0]])
@charts.trv_chart_t(names, values, baseline=@charts.TrvSym, fill=false)
```

### Ripple scatter chart eff_chart_t

`eff_chart_t(points : Store[Array[EffPoint]], period_ms? = 3000, rings? = 3, x_range?, y_range?, anim? = EffAnim::make(), fill? = false, style?, handle?)`

Scatter plus ripple animation: each point periodically expands N concentric rings (radius grows with phase, stroke alpha decays), with `set_timer` driving the phase Store forward and then schedule_paint repainting.

| Param | Type | Default | Notes |
|---|---|---|---|
| points | Store[Array[EffPoint]] | required | `EffPoint::make(x, y, size? = 12.0)`; size is the dot diameter (logical px, clamped to 2..48 at draw time) |
| period_ms | Int | 3000 | one ripple cycle (frame step = period ÷ 60, with a minimum fallback of 16ms) |
| rings | Int | 3 | number of rings expanding simultaneously per point (≤0 degenerates to a static scatter) |
| x_range / y_range | (Double, Double)? | None | manual value ranges; None = adaptive |
| anim | EffAnim | self-built | animation handle: `eff_stop(anim)` stops the timer; when omitted, this mount builds its own (impossible to stop from outside) |
| fill | Bool | false | no fixed width; stretches horizontally to fill the parent |
| width / height | Double | 560 / 320 | canvas size (when fill=false), set via `style` |

**Stop discipline**: views in this library have no destroy callback (`yue/view.mbt` has no dispose hook), so after a component is unmounted its timer stays alive and keeps calling schedule_paint on the unmounted view — callers must therefore call `eff_stop(anim)` explicitly before unmounting; stopping is not recoverable, and to resume, remount with a new handle. Companion pure functions: `eff_point_radius` (clamped diameter to radius), `eff_ring_progress` / `eff_ring_radius` / `eff_ring_alpha` (single-ring progress → radius / alpha), `eff_phase_advance`, `eff_tick_ms`, `eff_xy` (point-to-pair table).

```moonbit
let pts = @yue.Store::new([
  @charts.EffPoint::make(120.0, 12.0, size=14.0),
  @charts.EffPoint::make(320.0, 26.0, size=20.0),
])
let anim = @charts.EffAnim::make()
@charts.eff_chart_t(pts, period_ms=2500, rings=3, anim=anim)
// …before the page unmounts
@charts.eff_stop(anim)
```

### Pictorial bar chart pb_chart_t

`pb_chart_t(data : Store[Array[BarItem]], symbol? = PbRect, mode? = PbRepeat, unit? = 10.0, horizontal? = false, show_values? = false, y_range? = None, fill? = false, style?, handle?)`

Values are expressed by symbols repeated along the baseline or stretched as a whole; the coordinate semantics match `bar_chart_t` (zero baseline, positive/negative values, slots, grid ticks, and category-label thinning/truncation all come from the same source).

| Param | Type | Default | Notes |
|---|---|---|---|
| data | Store[Array[BarItem]] | required | reuses the bar chart's `BarItem::make(label, value)` |
| symbol | PbSymbol | `PbRect` | `PbRect` / `PbCircle` / `PbTriangle` (apex points toward the value end of the bar axis) / `PbCustom` self-draw callback |
| mode | PbMode | `PbRepeat` | `PbRepeat` repeats along the bar axis (count = ceil(|value| / unit)); `PbStretch` stretches one symbol from baseline to value end |
| unit | Double | 10 | value unit represented by each symbol (≤0 gives one symbol per bar) |
| horizontal | Bool | false | horizontal bar form |
| show_values | Bool | false | per-bar value labels (just outside the bar end) |
| y_range | (Double, Double)? | None | manual value range; None = adaptive |
| fill | Bool | false | no fixed width; stretches horizontally to fill the parent |
| width / height | Double | 560 / 280 | canvas size (when fill=false), set via `style` |

Positive values take the theme primary upward / rightward, negatives take the danger color downward / leftward. Per-bar symbol count is clamped at 64; a symbol's pixel size is computed as "unit × bar length / |value|" and clamped within the bar slot width. Custom symbol: `PbCustom((Painter, x, y, w, h, color) -> Unit)` self-draws inside the given box (set the color yourself with set_fill_color).

```moonbit
let pb = @yue.Store::new([
  @charts.BarItem::make("Q1", 32.0),
  @charts.BarItem::make("Q2", 48.0),
])
@charts.pb_chart_t(pb, symbol=@charts.PbCircle, mode=@charts.PbRepeat, unit=10.0, show_values=true)
@charts.pb_chart_t(pb, symbol=@charts.PbTriangle, mode=@charts.PbStretch, horizontal=true)
```

## Chart interaction layer

A cross-cutting layer (the tooltip and hit testing in `charts_tooltip.mbt` + the legend / zoom / marks / visual map / export in `charts_interactive.mbt` + the three interactive variants in `charts_it.mbt`): it adds hover tooltips, a clickable legend, DataZoom pan/zoom, threshold lines and highlight bands, visual-map color mapping, and export to any self-drawn chart. It shares the same rendering model as the other charts; the geometric knowledge stays with the caller (drawing and hit testing come from one source), and the interaction layer only wires up events and positions the tooltip.

### Hover tooltip and hit testing ci_tooltip

`ci_tooltip(draw, hit, plot? = ..., zoom? = None, pan? = false, zoom_map? = None, style? = [("width", 560.0), ("height", 280.0)], handle?)`

| Param | Type | Default | Notes |
|---|---|---|---|
| draw | (Painter, Double, Double) -> Unit | required | chart content drawing (excluding borders and the tooltip) |
| hit | (x, y, width, height) -> (title, rows)? | required | hit → `Some((title, [(swatch color, row text), ...]))`; None hides the tooltip |
| plot | (Double, Double) -> CiPlot | whole canvas | plot rect (the zoom anchor / hit conversion basis; must match the drawing geometry) |
| zoom | CiZoom? | None | when not None, binds wheel zoom; `zoom_map` defaults to taking the plot fraction along the x axis — override it for category-axis-on-y scenarios like horizontal bars |
| pan | Bool | false | left-button drag to pan the window (set_capture on press, release_capture on release) |
| style | Array[(String, &StyVal)] | 560×280 | canvas size style |

The tooltip is drawn inside the chart container's own on_draw (drawing it after the chart puts it on top, so there is no z-order problem); it always uses a dark background with light text and does not follow theme switches. Positioning goes through `ci_tooltip_pos`, clamped inside the canvas, flipping to the anchor's opposite side when it would overflow right. schedule_paint only fires when the tooltip shows/hides on mouse-enter or during a drag; static mouse movement does not repaint. The state struct `CiTip` (`CiTip::new()` / `ci_tip_show(tip, title, rows, px, py)` / `ci_tip_hide(tip)` / `ci_tip_draw(p, tip, w, h)` / `ci_tip_size(title, rows)`) can also be used directly in self-drawn charts. Hit-testing pure functions: `CiPlot::make(x0, y0, x1, y1)` (`width` / `frac` / `contains`), `ci_nearest_idx(px, n, x0, x1)` (nearest index in an evenly spaced point series; -1 outside the plot area), `ci_sector_at(px, py, cx, cy, r_in, r_out, values)` (sector hit, clockwise from 12 o'clock, same construction as `sector_angles`).

```moonbit
let zoom = @charts.ci_zoom_make()
@charts.ci_tooltip(
  draw=fn(p, w, h) { // self-draw after slicing by the zoom window
    let (i0, i1) = @charts.ci_zoom_visible(zoom, pts.length())
    my_draw(p, w, h, @charts.ci_slice_range(pts, i0, i1))
  },
  hit=fn(px, _py, _w, _h) {
    match @charts.ci_nearest_idx(px, pts.length(), 46.0, 500.0) {
      i if i >= 0 => Some(("Point \{i + 1}", [("", "\{pts[i].y}")]))
      _ => None
    }
  },
  zoom=Some(zoom),
  pan=true,
  style=[("width", 420.0), ("height", 240.0)],
)
```

(The two required `draw` / `hit` callbacks can also be passed positionally: `@charts.ci_tooltip(self-draw callback, hit callback, zoom=Some(zoom))`.)

### Clickable legend ci_legend + visibility bit helpers

`ci_legend(items~ : Store[Array[(String, String)]], visible~ : Store[Array[Bool]], on_toggle? = (Int) -> Unit, style?)`

Series swatches + names in a single row, with a light background on hover; clicking toggles the corresponding series' visibility and calls back `on_toggle` (the caller repaints the chart). `visible` need not be pre-aligned in length: at draw / click time `ci_fit_len` pads it to the items length (default true = visible), and wholesale data replacement only sets items. Items whose start exceeds the container width are not drawn (the same width threshold as the `ci_legend_hit` hit test). Visibility helpers: `ci_fit_len(flags, n)`, `ci_toggle_flag(flags, i)`, `ci_filter_visible(arr, flags)` and `ci_filter_visible_at(arr, flags, base)` (returns `(visible items, each item's original index)` — after toggling, colors / indexes still position by the original data, so colors don't shift), `ci_slice_range(arr, i0, i1)` (closed-interval slice, auto-narrowing when out of range).

```moonbit
let items = @yue.Store::new([("CPU", @yue.theme_current().primary), ("Memory", @yue.theme_current().info)])
let visible = @yue.Store::new([true, true])
@charts.ci_legend(items~, visible~, on_toggle=fn(_i) { my_repaint() })
```

### DataZoom state window ci_zoom

| Function | Notes |
|---|---|
| `ci_zoom_make(start? = 0.0, end? = 100.0) -> CiZoom` | build a window (start/end percentages 0..100, full window by default) |
| `ci_zoom_span(z) -> Double` | current window span |
| `ci_zoom_reset(z)` | reset to the full window |
| `ci_zoom_set(z, start, end, min_span? = 5.0)` | set the window (start/end are normalized first; a span below min_span is stretched open around the midpoint, then clamped to the edges) |
| `ci_zoom_wheel(z, anchor, delta, min_span? = 5.0, step? = 0.2)` | wheel zoom: anchor is the mouse's percentage on the category axis, scrolling up zooms in (clamps at the boundaries, the anchor slides) |
| `ci_zoom_pan(z, dx)` | drag to pan (span unchanged, stops at the 0/100 boundaries) |
| `ci_zoom_visible(z, n) -> (Int, Int)` | window → visible closed index interval `[i0, i1]` (i0 floored, i1 ceil−1, so no in-window point is dropped; n ≤ 0 gives (0, −1)) |

The window math is independently testable pure functions (`ci_zoom_normalize` keeps swapped inputs ordered, clamps to 0..100, and has a 1% minimum span); the state itself does not depend on a view. Data slicing is done by the drawing caller, pulling points out via `ci_zoom_visible` + `ci_slice_range` before repainting.

### Threshold line and highlight band ci_mark_line / ci_mark_area

Call these inside any `on_draw` callback against the plot rect `(x0,y0)-(x1,y1)`:

| Function | Notes |
|---|---|
| `ci_mark_line(p, horizontal, value, lo, hi, x0, y0, x1, y1, label? = "", color? = theme_danger(), dashed? = true)` | horizontal (y=value) / vertical (x=value) threshold line + end label; not drawn when value falls outside the range `[lo, hi]`, with the label clamped inside the plot rect |
| `ci_mark_area(p, horizontal, from, to, lo, hi, x0, y0, x1, y1, label? = "", color? = theme_warning(), alpha? = "26")` | semi-transparent fill of the from..to value band + end labels inside the band; from/to are swapped automatically, the band is not drawn when it has no intersection with the value range, and a partial intersection is clipped to the intersection |

```moonbit
cv.on_draw(fn(p) {
  @charts.ci_mark_area(p, true, 0.0, 60.0, 0.0, 100.0, 46.0, 12.0, 540.0, 240.0, label="Safe zone")
  @charts.ci_mark_line(p, true, 80.0, 0.0, 100.0, 46.0, 12.0, 540.0, 240.0, label="Alert line")
})
```

### Visual map ci_visual_map

| Function | Notes |
|---|---|
| `ci_visual_map_make(min, max, low, high) -> CiVisualMap` | two-color band (min/max are swapped automatically if unordered, low→high linear mix) |
| `ci_visual_map3_make(min, mid, max, low, midc, high) -> CiVisualMap` | three-color band (when mid is missing or lands as an endpoint, the min/max midpoint is used) |
| `ci_visual_map_frac(v, lo, hi) -> Double` | value → normalized fraction 0..1 (a degenerate range gives 0, clamped outside the ends) |
| `CiVisualMap::color(self, v) -> String` | value → color (two-color band linear mix; three-color band linear mix on each segment, with midc at the midpoint) |

The fallback semantics for invalid color strings match `mix_hex` (the high-end color is returned as-is).

```moonbit
let vm = @charts.ci_visual_map3_make(0.0, 50.0, 100.0, "#E3EDFA", "#409EFF", "#1E4FA3")
let fill_color = vm.color(73.0)
```

### Export ci_save / ci_save_chart

| Function | Notes |
|---|---|
| `ci_save(canvas : Canvas, path, format? = "png") -> Result[Unit, CiSaveError]` | offscreen canvas to disk: an invalid format (png/jpeg/jpg only) is rejected up front without touching the disk; write failures carry the format and path |
| `ci_save_chart(draw, w, h, path, format? = "png") -> Result[Unit, CiSaveError]` | draws the same draw callback used at mount time onto an offscreen canvas, then exports (there is no shim API for view pixels, so re-rendering is the only way) |

On non-Windows platforms libyue exposes no cross-platform Canvas export API (the shim always fails), and error messages carry a platform hint; cross-platform export goes through packaging / screenshot tools and is not solved by this layer. The error `CiSaveError`: `UnsupportedFormat(String)` / `WriteFailed(String)`.

### Interactive variants line_chart_it / bar_chart_it / donut_chart_it

Three ready-made "interactive" versions: data / parameter semantics match the original charts, but they mount on the `ci_tooltip` interactive canvas, with layout = vbox(legend row + canvas) and a total height one legend row (30px) taller than the original chart.

| Component | Added interaction | DataZoom |
|---|---|---|
| `line_chart_it(series, area? = false, y_range?, show_last? = true, zoom? = true, fill? = false, style?, handle?)` | hover nearest point: tooltip "Point N" + each visible series' value, plus a vertical crosshair and the series dots (4×4 color dots); legend click toggles series visibility | supported (the window is scaled by the longest series, short series are sliced by the same window; the y axis adapts to the visible window) |
| `bar_chart_it(data, horizontal? = false, y_range? = None, zoom? = true, fill? = false, style?, handle?)` | hover category: the tooltip shows the category label + value (bar highlighting is handled by the drawing layer's hover parameter); legend click toggles category visibility | supported (the window is scaled by category index; a horizontal bar's window is mapped along the y axis via zoom_map; the y value range is computed over all categories, so the axis stays put on zoom / visibility toggles) |
| `donut_chart_it(data, thickness? = 34.0, center? = "", fill? = false, style?, handle?)` | hover sector: the tooltip shows label + value (the share is recomputed over the currently visible sectors), with the sector exploding 4px; legend click toggles sector visibility | none (a donut has no x axis) |

The legend palette is rebuilt on theme changes (`on_theme_change`); Store subscriptions and theme callbacks are all registered at mount time — a Node that is constructed but never mounted leaves nothing behind.

```moonbit
let series = @yue.Store::new([
  @charts.LineSeries::make("CPU", max_points=120),
  @charts.LineSeries::make("Memory", max_points=120),
])
@charts.line_chart_it(series, area=true, zoom=true)
@charts.bar_chart_it(bars, horizontal=true)
@charts.donut_chart_it(slices)
```

## Icons

803 built-in vector icons, all generated from an iconfont package (Yuanhai common library, MES-flavored) via `scripts/gen_icons.py <iconfont-package-dir>`: SVG font outlines (beziers/arcs) are translated into Painter primitives, bbox-normalized with y-flip, fill-style, variant names are the PascalCase of `font_class` (e.g. `FilePdf`, `CaretRightSmall`), with an `Icon` suffix when clashing with a widget type (e.g. `MenuIcon`, `TableIcon`); `icon_name` returns `<font_class>`. Groups: forms & tables / editing & typography / directions / layout & view / files / cloud & ops / devices / charts / messaging / users / security / time / status / finance / system tools / weather & food / media & travel / brands — the showcase icons page renders them by group (that page is generated by `scripts/gen_showcase_icons.py`). To swap icon sets, point the script at the new package and rerun; never hand-edit the `icons-gen` marker sections.

| API | Purpose |
|---|---|
| `icon(kind : IconKind, size? = 16.0, color? = "")` | icon node: theme regular color by default, fixed color via color |
| `icon_button_t(kind, on_click?, size? = 28.0, tip? = "", style?, handle?)` | Square icon button: hover light fill + brighter icon, triggered by click/Enter/Space; native tooltip when tip is non-empty; default marginRight 6 — caller style is appended last (can override defaults) |
| `draw_icon(p : Painter, kind, cx, cy, s, color)` | unified self-drawing entry (center coordinates + edge length) |
| `all_icons()` / `icon_name(kind)` | full list / name lookup |

Quick reference by group (full enum in `yue/icons/icons.mbt` `IconKind`; live wall on the showcase icons page):

| Group | Icons |
|---|---|
| Basic | ChevronLeft/Right/Up/Down, ArrowUp/Left/Right/Down, Plus, Minus, Close, Check, Search, Hamburger, Home, Gear, Refresh, Trash, Edit, Save, Star, User(s), Pin, Copy, Download, Upload, Play, Pause, Ellipsis, Grip |
| Files & editing | Folder(Open/Plus), FileDoc/Code/Plus, Clipboard, Bookmark, Undo, Redo, Scissors, Paste, Bold, Italic, Underline, Type, Align*, ListUl/Ol, Link, Unlink, ExternalLink |
| View & layout | ZoomIn/Out, Eye(EyeOff), Sun, Moon, Grid, Layout, Sidebar, Move, Expand, Shrink, RotateCw/Ccw, Columns, Rows |
| Media & messaging | Square, CircleRecord, Volume(Off), Mic, Camera, Image, Music, Mail, Send, MessageCircle, Bell(BellOff/BellRing), Phone, Rss, Globe, Share |
| System | Power, LogIn/Out, Lock/Unlock, Key, Shield, Database, Server, HardDrive, Monitor, Smartphone, Wifi(Off), Bluetooth, Cpu, Keyboard, Mouse, Battery(Charging), Signal |
| Data & status | TrendingUp/Down, BarChart, PieChart, TableRows, Info, Warning, Error, Success, Help, Heart, Flag, Clock, Tag, CheckCircle, XCircle, InfoCircle, Loader |
| Weather & misc | Cloud family (Cloudy/CloudSun/CloudRain/CloudSnow/Upload/Download), Droplet, Thermometer, Wind, ShoppingCart, CreditCard, Gift, Rocket, Trophy, Lightbulb, Wrench, Compass, MapPin, Navigation, Crown, Zap, Layers, Package |

```moonbit
@icons.icon(@icons.Search2, size=18.0)
@icons.icon_button_t(@icons.Plus, on_click=fn() { add_row() }, tip="Add row")

// self-drawing entry (inside an on_draw callback):
@icons.draw_icon(p, @icons.Star, 24.0, 24.0, 16.0, "#D9822B")
```

## Feedback

### Alert banners alert / alert_closeable

`alert(text, t : SemanticType, height? = 40.0)` / `alert_closeable(text, t)`

Light fill of the type + 4px left color bar + same-family dark text, full width; the latter adds a right-side close button that hides the whole banner.

```moonbit
@components.alert("Saved", @components.Success)
@components.alert_closeable("A new version is available", @icons.InfoCircleFill)
```

### Result result

`result(t, title, desc, children : Array[Node])` — large colored symbol + title + description + custom button area.

```moonbit
@components.result(@components.Success, "Submitted", "Results arrive within one business day", [@components.button_t("OK")])
```

### Empty state empty

`empty(desc)` — grey placeholder block + centered caption.

```moonbit
@components.empty("No data")
```

### Dialog dialog_t

`dialog_t(visible : Store[Bool], title, children : Array[Node], width? = 420.0, confirm_text? = "确定", cancel_text? = "取消", on_confirm?, on_cancel?, close_on_mask? = false)`

In-app dialog: same-window mask (semi-transparent black, absolute relative to the mount container — mounted at the window root it covers the whole window) + centered panel (title bar with ✕ + body + right-aligned buttons). `visible` drives show/hide; ✕ / cancel / confirm auto-close after the callback, empty text hides that button (both empty hides the whole row), close_on_mask=true also closes on mask clicks. Visually modal, not keyboard-modal.

```moonbit
let show = @yue.Store::new(false)
@components.dialog_t(show, "Confirm delete", [@components.label_t("This cannot be undone. Sure?")],
  confirm_text="Delete", on_confirm=fn() { remove() }, close_on_mask=true)
```

### Toast toast_layer

`toast_layer(duration_ms? = 2600) -> (Node, (String, SemanticType) -> Unit)`

Mount the layer node at the window root (absolute top strip, no layout space); the push function shows a semantic toast bar (panel background + border + type icon), auto-removed after 2.6s by default, multiple bars stack top-down; call it after the layer is mounted.

```moonbit
let (layer, toast) = @components.toast_layer()
// after mounting layer at the window root:
toast("Saved", @components.Success)
```

### Context menu context_menu_for

`context_menu_for(content : Node, items : Array[(String, () -> Unit)])` — wrap any node with a native right-click menu, label "-" draws a separator; the popup position is converted to screen coordinates via `bounds_in_screen`, and the menu is rebuilt on each right-click.

```moonbit
@components.context_menu_for(row_view, [("Copy", fn() { copy() }), ("-", fn() {}), ("Delete", fn() { remove() })])
```

## Overlays

### Tooltip tooltip_t

`tooltip_t(content : Node, tip)` — wrap any node with a native tooltip (system style, zero cost; use popover_t for a themed bubble). On Linux the tooltip color is pinned to a dark background with white text (independent of the system theme).

```moonbit
@components.tooltip_t(@components.button_t("Delete"), "Delete this item")
```

### Popover popover_t

`popover_t(trigger : Node, content : Node, width, height)` — clicking the trigger opens arbitrary Node content below it; click again to toggle closed.

```moonbit
@components.popover_t(@components.button_t("More"), filter_panel, 240.0, 160.0)
```

### Dropdown menu dropdown_menu

`dropdown_menu(trigger : String, items, on_select : (Int) -> Unit, style?)` — trigger text + dropdown arrow; clicking opens the item list: hover highlight, click calls back the index and closes; `"-"` in items draws a separator.

```moonbit
@components.dropdown_menu("Actions", ["Edit", "-", "Delete"], fn(i) { handle(i) })
```

### Carousel carousel_t

`carousel_t(pages : Array[Node], width? = 360.0, height? = 180.0, interval_ms? = 3000, rotation?, style?, handle?)` — panel sequence + side arrows + bottom dots; with interval_ms > 0 it auto-advances every interval milliseconds (paused on hover), arrows/dots switch manually.

```moonbit
@components.carousel_t([banner1, banner2], interval_ms=4000)
```

Auto-advance is a self-scheduling timeout chain: **call `carousel_stop(rotation)` before unmounting the carousel** (otherwise the chain keeps ticking against the removed views). Pass a handle you built with `CarouselHandle::make()` as `rotation` (`is_running()` reads the state); without it the component builds its own handle that callers cannot reach, which only fits carousels living for the whole app.

State coordination across components goes through `Store` (subscribe / map / bind_label) or signals (`Signal`: computed with automatic dependency tracking, batch updates; pass a `sig.store()` view to component APIs taking a Store); see [declarative.md](declarative.md). Chinese version: [docs/zh/components-ui.md](zh/components-ui.md).
