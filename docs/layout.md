# Layout Styling (@style + yoga-mbt)

The layout engine is this repository's own **yoga-mbt**, a pure-MoonBit implementation of CSS Flexbox Level 1. Styles are MoonBit values living in the `@style` package, and `Style` field names are CSS property names with hyphens written as underscores. Components accept loose parameters (`padding=` / `row_gap=` …) as well as a `class? : Array[@style.Style]` array that stacks style blocks. This page is a quick reference for the layout surface; the full design of the style value model and state buckets is in [design.md (Chinese)](/zh/design).

## Two write paths

- **Loose parameters**: `@ui.col/row/view` take `padding` / `row_gap` / `column_gap` / `width` / `height` / `grow` / `align_items` / `background_color` / `border_color` directly. They are sugar for the matching `Style` fields and have exactly one destination: folded into an anonymous block.
- **`class` channel**: pass one or more `Style` blocks built with `@style.style(...)`; the last array element wins — its same-named properties override earlier ones. All 34 components accept `class?`.

The two merge into a single `Style`, which lands on the widget's style slot and the Yoga node.

## Layout field quick reference (`Style`)

The labelled parameters of `@style.style(...)` are the field names; all are optional. `None` means unset and falls back to the engine default.

### Size

| Field | Meaning |
|---|---|
| `width` / `height` | fixed size, in logical pixels |
| `width_percent` / `height_percent` | percentage size, relative to the parent's content box |
| `min_width` / `min_height` | minimum size; see the min:auto rule below |
| `max_width` / `max_height` | maximum size |

### Box spacing

| Field | Meaning |
|---|---|
| `padding` | uniform padding on all four edges (shorthand) |
| `padding_left` / `padding_right` / `padding_top` / `padding_bottom` | per-edge padding |
| `margin` | uniform margin on all four edges (shorthand) |
| `margin_left` / `margin_right` / `margin_top` / `margin_bottom` | per-edge margin |

### Flex

| Field | Values | Meaning |
|---|---|---|
| `flex_direction` | `Row` / `RowReverse` / `Column` / `ColumnReverse` | main-axis direction; default `Row`, web semantics |
| `flex_wrap` | `NoWrap` / `Wrap` / `WrapReverse` | whether to wrap; default `NoWrap` |
| `flex` | `Double` | flex grow factor, used with `grow` |
| `justify_content` | `FlexStart` / `FlexEnd` / `Center` / `SpaceBetween` / `SpaceAround` / `SpaceEvenly` | main-axis alignment |
| `align_items` | `Stretch` / `FlexStart` / `FlexEnd` / `Center` / `Baseline` | cross-axis alignment, the default for children |
| `align_self` | same as `align_items` | one item overrides the parent's `align_items` |
| `row_gap` / `column_gap` / `gap` | `Double` | row gap / column gap / uniform shorthand |

### Position and stacking

| Field | Values | Meaning |
|---|---|---|
| `position` | `Relative` / `Absolute` | positioning mode |
| `top` / `right` / `bottom` / `left` | `Double` | relative or absolute offset |
| `z_index` | `Int` | paint-order key; higher values paint later |
| `display` | — | participate in layout or hide; a `Style` field, skipped in both painting and hit-testing |

The enums `FlexDirection` / `AlignItems` / `JustifyContent` / `FlexWrap` / `PositionType` are the same set the loose parameters use, all from yoga-mbt. Write them as `@yoga.Row` / `@yoga.Center`, or pass them straight to `view(direction=…)`.

## A few things you must know

**min:auto blows up scroll and wrap containers.** A flex child's default minimum size is `auto`, i.e. its content size. A scroll viewport or wrapping container that doesn't set `min_width` / `min_height = 0.0` gets pushed to its content's natural size, `max()` stays 0, and the result is that it won't scroll or the row overflows. The library-level containers `scroll_view` / `virt_list` and the showcase sidebar already fix this; when you build your own scroll or wrap structure, write `min_width=0.0, min_height=0.0` yourself.

**Wrapping must go the right direction.** `flex_wrap=Wrap` only folds vertically when the container is a **column**: a `row` container doesn't stretch on the cross axis, so wrapped items sized to content fold into a vertical stack. A chip bar that must "wrap when too wide" therefore goes into a column container, with explicit `min_* = 0` at every level.

**gap is already subtracted from free space.** When grow/shrink computes free space, it first deducts `gap × (n-1)`, so a row of "fixed items + a grow item + gap" never overflows. This was a fixed engine defect, pinned in regression tests — no workaround needed.

**Text size feeds back into layout.** The content size of `@ui.text` / `bind_label` comes from Pango measurement, and both `measure` and `baseline` are wired into the layout engine, so text can take part in baseline alignment and size to its content; wrapping and truncation are controlled by the `max_width` + `wrap` + `ellipsis` trio.

## Incremental relayout

All 39 setters, plus structural and callback changes, call `mark_changed`; versions are tracked with a global clock plus a per-node `rev`. The layout entry skips unchanged subtrees by "subtree version + input fingerprint". So changing a `bind_label`'s text recomputes only that chain, and a whole-frame layout is near constant time. Callers don't manage this layer, but it explains why in-place edits are recommended over rebuilding the whole tree — see [declarative.md](declarative.md).

## Related docs

- Style value model, state buckets, theme linkage: [design.md (Chinese)](/zh/design) §1
- Components and loose parameters: [components.md](components.md)
- Reactivity and whole-tree / in-place replacement: [declarative.md](declarative.md)
