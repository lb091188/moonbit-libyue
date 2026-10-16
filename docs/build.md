# Build & linking

This library's link parameters are **fully hosted by prebuild** — neither ordinary users nor contributors hand-write link flags. This page explains what that means for you, plus the one pitfall after editing a native stub: not relinking. The mechanism and per-platform field records are in [adaptation.md](adaptation.md) ("Build & linking").

## 1. Where linking comes from (not your concern)

- **At build time**: moon runs the library module's `gui/scripts/prebuild.py` (wired up in `gui/moon.mod`'s `options(--moonbit-unstable-prebuild)`). It emits `link_configs` for the **current system** and propagates them automatically to every main package that depends on this module.
- **Probe & degrade**: prebuild probes system libraries — GTK3 / Pango / FontConfig / X11 on Linux, `webkit2gtk-4.1` for the embedded WebView, ffmpeg for the media module. If GTK is missing it exits non-zero with a fix hint; if webkit is missing, `@web` degrades to a placeholder implementation (the capability reports `Unsupported`) instead of failing the whole link.
- **What you see**: `moon add NoahLiu/native-gui` then `moon run` with zero configuration — link flags are not written and should not be written.

## 2. Contributors: no moon.pkg writes link flags

- **Library packages carry no `link` section** — moon would generate an `.exe` with no `main` and the build fails.
- **Never hand-write `cc-link-flags`** — linking is emitted by prebuild; editing it by hand fights prebuild.
- **New platform C capabilities** follow the "single `stub.c`, multi-branch + prebuild macros" layout (see `gui/win/stub.c`); the link flags still belong to prebuild.

(The FFI-declaration and trampoline-ABI rules are in the repository-root [AGENTS.md](https://github.com/lb091188/moonbit-native-gui/blob/master/AGENTS.md) and `.agents/skills/moonbit-c-binding/`.)

## 3. The one pitfall: editing a C stub doesn't relink

Once moon compiles a `.c` / `.cpp` native-stub into a static library, changing the stub code **may not trigger a relink**: `moon build` can report `no work to do` and keep running the old exe; `moon test` binaries behave the same, still linking the old archive. Before and after, the symptom is "changed the code, behavior didn't change" (an old crash even persists).

**Tell**: you edited `gui/<pkg>/*.c` or `.cpp`, but `moon build` says nothing to do and it still behaves the old way — that's this.

**Fix** (pick one):

```sh
moon clean                 # full rebuild, the easy path
# or delete just the relevant artifacts (paths vary with build layout and target):
rm -rf gui/_build/native/**/build/<pkg>/                 # rebuild that package
rm -rf _build/native/debug/build/examples/<example>/<example>   # relink that example
```

Then `moon build` / `moon test` recompiles the stub and links a fresh exe.

**Why it's worth "reproduce on a main target first"**: a brand-new target is always linked fresh — if "main is fine, the test crashes", you can almost conclude the test binary linked a stale archive, not a logic bug. This and the finer platform records (stepped on separately under GTK / Win32 / macOS) are in [adaptation.md](adaptation.md).

## 5. Vendored large files and mirrors

Three third-party files are kept out of git (committing them would permanently bloat the
history) and are fetched by prebuild **only when missing**: `WebView2.h`,
`WebView2LoaderStatic.lib`, `miniaudio.h` — about 18.6 MB in total.

- **Verification first**: a file is written only if its sha256 matches the constant in the
  two prebuild scripts, so any mirror is verifiable;
- **Mirrors are tried in order** (GitHub → Gitee) with no latency probing: measuring first
  would make two machines fetch from different sources and cost us reproducibility, while
  the order only ever affects speed;
- **20 s per source**: a direct GitHub Release asset fetch from a CN network was measured at
  "15 s, 0 bytes", so failing over fast beats waiting on one source;
- **Adding a source**: one line in `VENDOR_BASES` in `gui/scripts/prebuild.py` and
  `modules/gui-media/prebuild.py` (two copies on purpose — `gui-media` must publish
  standalone and cannot reach back into the main module's `scripts/`);
- **Intranet and offline**: set `NATIVE_GUI_VENDOR_BASE` to a single base URL or a
  comma-separated list (tried first), or place the files at their target paths by hand —
  prebuild never touches files that already exist;
- If every source fails, prebuild does not abort: it prints the manual-placement hint and
  lets the link step report the missing file.

Licenses and provenance: [`THIRD-PARTY-NOTICES.md`](../THIRD-PARTY-NOTICES.md) at the repo root.

## 4. Related

- Platform adaptation pitfalls and verification: [adaptation.md](adaptation.md)
- Tutorial (environment setup and your first project): [tutorial.md](tutorial.md)
- Components and API: [components.md](components.md)
