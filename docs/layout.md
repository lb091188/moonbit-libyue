# Layout Style Key Quick Reference

libyue's layout engine is Yoga flexbox. This document is a quick reference for all usable style keys: name-resolution rules, value tables for the four key categories (enum / numeric / edge / special), and common-combination examples — set styles according to this table without consulting yoga docs. Styles are applied at creation via `style` / `style_str` and can be changed at runtime with `set_style` / `set_style_str`; container and native control APIs are in [components.md](components.md), and style keys inside the declarative tree are covered in [declarative.md](declarative.md).

## Conventions

Entry points (any `ViewLike`):

| API | Purpose |
|---|---|
| `set_style(name, Double)` | numeric styles (pixels) |
| `set_style_str(name, String)` | enum / percentage / auto values |
| `get_bounds() -> (x, y, w, h)` | computed geometry relative to the parent node |
| `get_computed_layout() -> String` | text dump of the yoga layout tree (debugging) |
| `on_size_changed(callback)` | size-change timing |

- **Key name resolution**: only ASCII letters are kept and lowercased — `flexDirection` / `flex-direction` / `FLEX_DIRECTION` are all equivalent; lowercase without separators (e.g. `justifycontent`) is recommended as the uniform style.
- **Value forms**: numeric keys take a `Double` in pixels; any pixel value can be written as a string percentage (e.g. `"50%"`, relative to the parent container's **content area**, i.e. the region after subtracting padding); `"auto"` restores automatic sizing.

## Basic Concepts

| Concept | Meaning |
|---|---|
| Main axis / cross axis | children are laid out one after another along the **main axis**, whose direction is set by `flexdirection` (default `column`, vertical, top to bottom); the perpendicular direction is the **cross axis** |
| `justifycontent` | how children are distributed along the **main axis** (packed at start / centered / equal spacing) |
| `alignitems` | how children are aligned along the **cross axis** (top / centered / stretched) |
| Content-determined size | when a child has no size set, its size is determined by content, and by default it stretches to fill the cross axis (`alignitems=stretch`) |

## Enum Keys

Set with `set_style_str`; values are strings:

| Key | Legal values | Description |
|---|---|---|
| `flexdirection` | `column` (default) `column-reverse` `row` `row-reverse` | Arrangement direction: `column` is vertical top-to-bottom; `row` is horizontal left-to-right; `-reverse` reverses the direction (bottom-to-top / right-to-left) |
| `justifycontent` | `flex-start` (default) `flex-end` `center` `space-between` `space-around` | Distribution of children along the **main axis**: `flex-start` all packed at the start, `flex-end` all at the end, `center` centered, `space-between` flush at both ends with equal spacing in between, `space-around` equal space on both sides of each child |
| `alignitems` | `stretch` (default) `flex-start` `flex-end` `center` | Alignment of children along the **cross axis**: `stretch` stretches to fill, `flex-start` / `flex-end` / `center` align to start / end / center |
| `aligncontent` | `flex-start` `flex-end` `center` `stretch` `space-between` `space-around` | Distribution between rows of multi-line content (effective only when wrapping with `flexwrap=wrap`); values have the same meaning as `justifycontent`, but applied to "rows" instead of "children" |
| `alignself` | `auto` (default) `flex-start` `flex-end` `center` `stretch` | Per-child override of the parent container's `alignitems`; `auto` means follow the parent container's setting |
| `flexwrap` | `nowrap` (default) `wrap` `wrap-reverse` | When one line doesn't fit: `nowrap` squeezes into a single line without wrapping, `wrap` wraps, `wrap-reverse` wraps in reverse |
| `position` | `relative` (default) `absolute` | `relative` participates in normal flow; `absolute` leaves the flow and is positioned relative to the parent using `top`/`bottom`/`left`/`right` |
| `direction` | `inherit` (default) `ltr` `rtl` | Content writing direction (left-to-right / right-to-left), usually no need to change |
| `display` | `flex` (default) `none` | `none` hides and **takes no layout space** (this is what `View::SetVisible(false)` does internally); set back to `flex` to restore visibility |
| `overflow` | `visible` (default) `hidden` `scroll` | When content overflows the container: `visible` draws the overflow, `hidden` clips it, `scroll` allows scrolling to view it |

```moonbit
let toolbar = @yue.Container::make(
  style_str=[("flexDirection", "row"), ("justifyContent", "space-between")])
toolbar.set_style_str("alignItems", "center")   // runtime key changes work too
```

## Numeric Keys

Set with `set_style`; values are `Double` pixels, with `"50%"` for percentages and `"auto"` to restore automatic sizing:

| Key | Description |
|---|---|
| `flex` | Shorthand for flexing, the most commonly used: `flex=1` means "distribute remaining space proportionally, and shrink proportionally when space is insufficient" — two children both set to 1 each take half; one set to 2 gets twice the space of one set to 1; `flex=0` (default) means fixed size, not participating in distribution |
| `flexgrow` | Only governs "how to distribute when there is remaining space": grows proportionally to the value; 0 (default) does not grow |
| `flexshrink` | Only governs "how to shrink when space is insufficient": shrinks proportionally to the value; 0 (default) does not shrink (content may overflow) |
| `flexbasis` | The "base size" along the main axis: it is allocated first before distributing remaining space; if unset, it is determined by `width`/`height` or content; `"auto"` restores |
| `width` / `height` | Fixed size (pixels); `"50%"` is half of the parent content area's width/height; `"auto"` restores content-determined sizing |
| `minwidth` / `minheight` / `maxwidth` / `maxheight` | Size bounds: flex distribution happens first, then the result is clamped into range (see "Pitfalls") |
| `aspectratio` | Width/height ratio (e.g. 1.78 ≈ 16:9): given one side, the other is derived automatically; commonly used with `width` or `flex` |
| `gap` / `rowgap` / `columngap` | Spacing between adjacent children (pixels): `gap` sets it uniformly, `rowgap` only between rows, `columngap` only between columns; does not stack with `margin` |

```moonbit
let page = @yue.Container::make(
  style=[("gap", 12.0), ("padding", 16.0)],
  style_str=[("flexDirection", "row")])
let side = @yue.Container::make(style=[("width", 220.0)])
let main = @yue.Container::make(style=[("flex", 1.0)])
let half = @yue.Container::make(style_str=[("width", "50%")])   // percentages go through style_str
```

## Edge Keys

Set with `set_style`; values are `Double` pixels, with `"50%"` percentages supported:

| Key | Description |
|---|---|
| `padding` / `paddingtop` / `paddingbottom` / `paddingleft` / `paddingright` | Inner padding: distance from the container edge to the content area; children are laid out in the region after padding is subtracted |
| `margin` / `margintop` / `marginbottom` / `marginleft` / `marginright` | Outer margin: spacing outside your own border |
| `border` / `bordertop` / `borderbottom` / `borderleft` / `borderright` | Drawn line width (border is the drawn line width and affects nothing beyond the outer layout size) |
| `top` / `bottom` / `left` / `right` | Effective only with `position=absolute`, offset relative to the parent node |

## Special Keys

Received directly by View, not routed through yoga:

| Key | Value | Equivalent API |
|---|---|---|
| `color` | `"#RGB/#RRGGBB/#RRGGBBAA"` | `View::SetColor` |
| `backgroundcolor` | same as above | `View::SetBackgroundColor` |

## Common Combinations

Classic two panes (fixed sidebar + flexible main area):

```moonbit
let root = @yue.Container::make(style_str=[("flexDirection", "row")])
root.add_child(@yue.Container::make(style=[("width", 220.0)]))   // fixed-width sidebar
root.add_child(@yue.Container::make(style=[("flex", 1.0)]))      // main area takes the rest
```

Centering on both axes:

```moonbit
let center_box = @yue.Container::make(
  style_str=[("justifyContent", "center"), ("alignItems", "center")])
```

Absolutely positioned overlay (relative to the mount container, for `dialog_t` / custom masks):

```moonbit
let overlay = @yue.Container::make(
  style_str=[("position", "absolute"), ("top", "0"), ("left", "0")],
  style=[("width", 120.0), ("height", 80.0)])
```

Flex distribution with a min/max floor (doesn't collapse on narrow screens):

```moonbit
let pane = @yue.Container::make(style=[("flex", 1.0), ("minWidth", 150.0)])
```

Proportionally scaled placeholder:

```moonbit
let thumb = @yue.Container::make(
  style=[("width", 160.0), ("aspectRatio", 1.78)])
```

## Pitfalls

- **The content view of a Group / Scroll is the layout root node**, not a child of its parent container (the parent container's styles do not affect it).
- libyue does not support CSS text / tables / float; only flexbox concepts exist.
- **On size conflicts, min/max clamping takes priority over flex distribution**: `flex=1` + `minwidth=150` yields 150px when 100px remains.
- **Composite controls (Tab / Scroll / Group) are measure-less leaf nodes in the yoga tree** — their outer frame size must be given explicitly (flex / width / height), otherwise they collapse; root cause and measurements are in [adaptation.md](adaptation.md).
- For debugging, `get_computed_layout()` directly outputs the yoga tree's final computed values.

Layout geometry test records (16 geometry assertions, composition rules, GUI automation experience) are in [adaptation.md](adaptation.md), section "Layout geometry".
