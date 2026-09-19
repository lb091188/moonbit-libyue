# Layout System Style Key Reference

libyue's layout engine is **Yoga flexbox** (`View::SetStyleProperty` writes directly to the yoga node).
This document is a **complete list of usable keys** extracted from the vendored libyue source
(the `yoga_util.cc` property dispatch table + `View::SetStyleProperty`), with real-world test records
on Ubuntu 24.04/X11. Consumers can set styles according to this table without consulting yoga docs.

MoonBit-side entry points (`yue/view.mbt` / `yue/events.mbt`):

- `set_style(name, Double)` for numeric values; `set_style_str(name, String)` for enum/percentage/auto values
- `get_bounds() -> (x, y, w, h)` computed geometry relative to the parent node
- `get_computed_layout() -> String` text dump of the yoga layout tree (debugging)
- `on_size_changed(callback)` size-change timing

**Key name resolution** (`ParseName`): only ASCII letters are kept and lowercased — `flexDirection` /
`flex-direction` / `FLEX_DIRECTION` are all equivalent; lowercase without separators (e.g. `justifycontent`)
is recommended as the uniform style.

## Basic Concepts

- Layout is simply "the container distributing space among children": children are laid out one after
  another along the **main axis**, whose direction is determined by `flexdirection` (default `column`,
  vertical, top to bottom); the direction perpendicular to the main axis is the **cross axis**.
- `justifycontent` determines how children are distributed along the **main axis** (packed at start /
  centered / equal spacing), while `alignitems` determines alignment along the **cross axis**
  (top / centered / stretched).
- When a child has no size set, its size is determined by content, and by default it stretches to fill
  the container on the cross axis (`alignitems=stretch`).
- All pixel values can be written as string percentages (e.g. `"50%"`, relative to the parent
  container's **content area**, i.e. the region after subtracting padding); `"auto"` restores automatic
  sizing (determined by content).

## Enum Keys (set_style_str, value is a string)

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

## Numeric Keys (set_style, value in pixels; % suffix goes through percentage)

The value is a `Double` in pixels; the string `"50%"` is a percentage relative to the parent container's
content area; the string `"auto"` restores automatic sizing. See the previous section for main axis /
cross axis concepts.

| Key | Description |
|---|---|
| `flex` | Shorthand for flexing, the most commonly used: `flex=1` means "distribute remaining space proportionally, and shrink proportionally when space is insufficient" — two children both set to 1 each take half; one set to 2 gets twice the space of one set to 1; `flex=0` (default) means fixed size, not participating in distribution |
| `flexgrow` | Only governs "how to distribute when there is remaining space": grows proportionally to the value; 0 (default) does not grow |
| `flexshrink` | Only governs "how to shrink when space is insufficient": shrinks proportionally to the value; 0 (default) does not shrink (content may overflow) |
| `flexbasis` | The "base size" along the main axis: it is allocated first before distributing remaining space; if unset, it is determined by `width`/`height` or content; `"auto"` restores |
| `width` / `height` | Fixed size (pixels); `"50%"` is half of the parent content area's width/height; `"auto"` restores content-determined sizing |
| `minwidth` / `minheight` / `maxwidth` / `maxheight` | Size bounds: flex distribution happens first, then the result is clamped into range (measured: `flex=1` + `minwidth=150` yields 150px when 100px remains; see test records below) |
| `aspectratio` | Width/height ratio (e.g. 1.78 ≈ 16:9): given one side, the other is derived automatically; commonly used with `width` or `flex` |
| `gap` / `rowgap` / `columngap` | Spacing between adjacent children (pixels): `gap` sets it uniformly, `rowgap` only between rows, `columngap` only between columns; does not stack with `margin` |

## Edge Keys (set_style, value in pixels; % suffix supported)

`padding` `paddingtop` `paddingbottom` `paddingleft` `paddingright`
`margin` `margintop` `marginbottom` `marginleft` `marginright`
`border` `bordertop` `borderbottom` `borderleft` `borderright` (border is the drawn line width and affects nothing beyond the outer layout size)
`top` `bottom` `left` `right` (effective only with `position=absolute`, offset relative to the parent node)

## Special Keys (received directly by View, not routed through yoga)

| Key | Value | Equivalent API |
|---|---|---|
| `color` | `"#RGB/#RRGGBB/#RRGGBBAA"` | `View::SetColor` |
| `backgroundcolor` | same as above | `View::SetBackgroundColor` |

## Layout Model Essentials

- Containers default to `flexDirection=column`, `alignItems=stretch`: children stretch to fill the cross axis by default.
- **The content view of a Group / Scroll is the layout root node**, not a child of its parent container (the parent container's styles do not affect it).
- libyue does not support CSS text/tables/float; only flexbox concepts exist.
- On size conflicts: min/max clamping takes priority over flex distribution (measured: `flex=1` + `minwidth=150` yields 150px when 100px remains).
- Debugging: `get_computed_layout()` directly outputs the yoga tree's final computed values.

## Ubuntu 24.04 / X11 / XFCE 4.18 Test Records (2026-09-11)

The layout system ships 16 geometry assertions (flex equal split, gap spacing, percentage width,
justify/align centering, min-width floor, absolute positioning); measured in a real window,
**all 16/16 passed (failures=0)** with a ±1px tolerance.
The composition rules match hand calculation: content area = container − 2×padding; gap does not stack
with margin; percentage basis is the parent content area width.

**GUI automation experience** (on record): coordinate-based clicks are unstable due to WM frame offsets
and window occlusion; **keyboard-driven interaction (Tab focus + Space activation) is the preferred way
to trigger controls**; `xdotool key --window` uses XSendEvent synthetic events which GTK drops —
XTEST must be used (without --window).
