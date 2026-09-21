# Documentation Index

This directory holds the usage documentation for moonbit-libyue. The component API has two usage styles, semantically identical: the **classic per-setter approach** (`X::new()` + `set_xxx()`), or the **props-style one-shot approach** (`X::make(...)`, just a bundle of setters); all types are referenced via `@yue`, and the component API quick reference (parameters / method tables) is in [components.md](components.md).

| Document | Content |
|---|---|
| [tutorial.md](tutorial.md) | Five-minute tutorial for MoonBit newcomers: from `moon new` to a running window, with the three newcomer pitfalls resolved; includes links to the official MoonBit tutorial & Tour |
| [adaptation.md](adaptation.md) | Platform adaptation experience: real-world pitfalls per platform, root causes, and verification conclusions (continuously updated) |
| [components.md](components.md) | Component API quick reference: both classic setter and `X::make` props styles, including upstream pitfalls |
| [declarative.md](declarative.md) | Declarative UI: `Node`/`mount` render tree + `Store`/`Signal` reactive bindings (signals: computed with automatic dependency tracking + batch) |
| [components-ui.md](components-ui.md) | UI component library quick reference: Element-Plus-style themed components (buttons/input/selection/forms/navigation/layout/data display/icons/feedback/overlays), per-API signatures and parameter tables, with demo screenshots |
| [layout.md](layout.md) | Complete set of layout style keys (Yoga flexbox), with real-world test records |
| [tray.md](tray.md) | Linux tray solution: SNI protocol stack design, architecture, backend fallback, desktop compatibility |
| [relink.md](relink.md) | Forcing a relink after native layer (shim/vendor) changes: detection and handling |

For a quick start, demos and usage, see the repository root [README.md](../README.md).

[中文版文档索引](zh/README.md)
