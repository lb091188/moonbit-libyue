# Layout styling (@style + yoga-mbt)

The layout engine is the repository's own **yoga-mbt** (a pure-MoonBit CSS Flexbox Level-1 implementation), and styling is written as MoonBit values in the `@style` package (a `Style` struct whose field names are CSS property names with hyphens turned into underscores). Components take both loose parameters (`padding=` / `row_gap=` …) and a `class? : Array[@style.Style]` channel. This page is a quick reference for the layout surface; the full value model and state-bucket design are in [design.md (Chinese)](/zh/design).

## Two write paths

- **Loose parameters**: `@ui.col/row/view` take `padding` / `row_gap` / `column_gap` / `width` / `height` / `grow` / `align_items` / `background_color` / `border_color` directly — these are sugar for the matching `Style` fields and have exactly one destination (folded into an anonymous block).
- **The `class` channel**: pass one or more `Style` blocks made with `@style.style(...)`; the last array element wins (its same-named properties override earlier ones). 34 components accept `class?`.

Both merge into one `Style` that lands on the widget's style slot and on the Yoga node.

## Layout field reference (`Style`)

The labelled parameters of `@style.style(...)` are the field names; all are optional (`None` = unset, uses the engine default):

### Size

| Field | Meaning |
|---|---|
| `width` / `height` | fixed size (logical pixels) |
| `width_percent` / `height_percent` | percentage size (relative to the parent's content box) |
| `min_width` / `min_height` | minimum size (**see the min:auto pitfall below**) |
| `max_width` / `max_height` | maximum size |

### Box spacing

| Field | Meaning |
|---|---|
| `padding` | uniform inner padding (shorthand) |
| `padding_left` / `padding_right` / `padding_top` / `padding_bottom` | per-edge padding |
| `margin` | uniform outer margin (shorthand) |
| `margin_left` / `margin_right` / `margin_top` / `margin_bottom` | per-edge margin |

### Flex

| Field | Values | Meaning |
|---|---|---|
| `flex_direction` | `Row` / `RowReverse` / `Column` / `ColumnReverse` | main-axis direction (default `Row`, web semantics) |
| `flex_wrap` | `NoWrap` / `Wrap` / `WrapReverse` | wrapping (default `NoWrap`) |
| `flex` | `Double` | flex-grow factor (with `grow`) |
| `justify_content` | `FlexStart` / `FlexEnd` / `Center` / `SpaceBetween` / `SpaceAround` / `SpaceEvenly` | main-axis distribution |
| `align_items` | `Stretch` / `FlexStart` / `FlexEnd` / `Center` / `Baseline` | cross-axis alignment (children default) |
| `align_self` | same as `align_items` | one item overrides the parent's `align_items` |
| `row_gap` / `column_gap` / `gap` | `Double` | row gap / column gap / uniform shorthand |

### Position & stacking

| Field | Values | Meaning |
|---|---|---|
| `position` | `Relative` / `Absolute` | positioning mode |
| `top` / `right` / `bottom` / `left` | `Double` | relative/absolute offsets |
| `z_index` | `Int` | paint-order key (higher draws later) |
| `display` | — | participate in layout / hidden (`Style` field; skipped in both paint and hit-test) |

> The enums (`FlexDirection` / `AlignItems` / `JustifyContent` / `FlexWrap` / `PositionType`) are the same set the loose parameters use (from yoga-mbt), written as `@yoga.Row` / `@yoga.Center` or passed straight to `view(direction=…)`.

## A few things you must know

**min:auto blows up scroll/wrap containers.** A flex child's default minimum size is `auto` (= content size); a scroll viewport or a wrapping container that doesn't set `min_width`/`min_height = 0.0` gets stretched to its content's natural size and `max()` stays 0 (it won't scroll, or the row overflows). Library-level containers (`scroll_view` / `virt_list` / the showcase sidebar) already set this — **when you build your own scroll/wrap structure, write `min_width=0.0, min_height=0.0` yourself**.

**Wrap needs the right direction.** `flex_wrap=Wrap` folds vertically only when the container is a **column** — a `row` container doesn't stretch on the cross axis, so wrapped items size to content and stack into a vertical column; "wrap when too wide" cases (a chip bar, say) must sit in a column container plus explicit `min_* = 0` on every level.

**gap is already subtracted from free space.** The flex distribution (grow/shrink) subtracts `gap × (n-1)` from free space first, so a row of "fixed items + a grow item + gap" won't overflow (this is a fixed engine defect pinned in regression tests — no need to work around it).

**Text size feeds back into layout.** `@ui.text` / `bind_label` sizes come from Pango measurement, and both `measure` and `baseline` are wired into the layout engine, so text participates in baseline alignment and sizes to content; the `max_width` + `wrap` + `ellipsis` trio controls its wrapping and truncation.

## Incremental relayout (why changing one control doesn't lag)

Dirty-rect incremental relayout: all 39 setters plus structural/callback changes `mark_changed` (a global clock + per-node `rev`), and the layout entry skips clean subtrees by "subtree version + input fingerprint". Changing one control only recomputes its chain, not the whole tree.

## Related docs

- Components and parameters: [components.md](components.md)
- The `Style` value model, state buckets, transitions: [design.md (Chinese)](/zh/design)
- Declarative tree / `Store` / `Signal`: [declarative.md](declarative.md)
