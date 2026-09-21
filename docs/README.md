# Documentation Index

This directory holds the usage documentation for moonbit-libyue. The component API has two usage styles, semantically identical: the **classic per-setter approach** (`X::new()` + `set_xxx()`), or the **props-style one-shot approach** (`X::make(...)`, just a bundle of setters); all types are referenced via `@yue`, and the component API quick reference (parameters / method tables) is in [components.md](components.md).

| Document | Content |
|---|---|
| [tutorial.md](tutorial.md) | Five-minute tutorial for MoonBit newcomers: from `moon new` to a running window, with the three newcomer pitfalls resolved; includes links to the official MoonBit tutorial & Tour |
| [adaptation.md](adaptation.md) | Platform adaptation experience: real-world pitfalls per platform, root causes, and verification conclusions (continuously updated) |
| [components.md](components.md) | Component API quick reference: both classic setter and `X::make` props styles, including upstream pitfalls |
| [declarative.md](declarative.md) | Declarative UI: `Node`/`mount` render tree + `Store`/`Signal` reactive bindings (signals: computed with automatic dependency tracking + batch) |
| [components-ui.md](components-ui.md) | UI component library quick reference: Element-Plus-style themed components (buttons/input/selection/forms/navigation/layout/data display/icons/feedback/overlays), per-API signatures, parameter tables and examples |
| [layout.md](layout.md) | Layout style key quick reference: all Yoga flexbox style keys (enum / numeric / edge / special) with common-combination examples |
| [tray.md](tray.md) | Linux tray solution: SNI protocol stack design, architecture, backend fallback, desktop compatibility |
| [relink.md](relink.md) | Forcing a relink after native layer (shim/vendor) changes: detection and handling |

For a quick start, demos and usage, see the repository root [README.md](../README.md).

## Demo

`moon run examples/showcase` — the full-capability demo board, one page per capability area, each page's source in its own file (`examples/showcase/pages_*.mbt`) — the best copy-paste material library.

![Navigation page](images/showcase-nav.png)

![Basic components](images/components-basic.png)

![Navigation](images/components-nav.png)

![Data display](images/components-data.png)

![Feedback](images/components-feedback.png)

[中文版文档索引](zh/README.md)
