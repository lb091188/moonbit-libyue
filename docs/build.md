# Build & linking

Link parameters are **fully hosted by prebuild** — neither users nor contributors hand-write link flags. This page explains what the mechanism means for you, and the one pitfall after editing a native stub: not relinking. The mechanism and the per-platform field records live in the "Build & linking" section of [adaptation.md](adaptation.md).

## 1. Where linking comes from

- moon runs the library module's `gui/scripts/prebuild.py` at build time, wired up via `options(--moonbit-unstable-prebuild)` in `gui/moon.mod`. It emits `link_configs` for the current system and propagates them automatically to every main package that depends on this library module.
- prebuild also probes system libraries: on Linux it looks for GTK3 / Pango / FontConfig / X11, `webkit2gtk-4.1` for the embedded WebView, and ffmpeg for the media module. If GTK is not found, it exits non-zero with a fix hint; if webkit is not found, `@web` degrades to a placeholder implementation and the capability reports `Unsupported`, instead of failing the whole link.
- The result: after `moon add NoahLiu/native-gui`, `moon run` works with zero configuration. Link flags are never written and should not be written.

## 2. Notes for contributors

- Library packages carry no `link` section — moon would generate an `.exe` without a `main`, and the build fails.
- Never hand-write `cc-link-flags` — linking is emitted entirely by prebuild; manual edits conflict with it.
- New platform C capabilities follow the "single `stub.c`, multiple branches + prebuild macros" layout; see `gui/win/stub.c` for precedent. The link flags still belong to prebuild.

The rules for aligning FFI declarations with trampolines are in the repository-root [AGENTS.md](https://github.com/lb091188/moonbit-native-gui/blob/master/AGENTS.md) and `.agents/skills/moonbit-c-binding/`.

## 3. The one pitfall: editing a C stub doesn't relink

moon compiles `.c` / `.cpp` native stubs into a static library, so changing stub code does not necessarily trigger a relink: `moon build` may report `no work to do` and keep running the old exe, and `moon test` binaries link the stale archive the same way. In both cases the symptom is "the code changed but the behavior didn't", and an old crash may still be there.

**Tell**: you edited `gui/<pkg>/*.c` or `.cpp`, but `moon build` says there is nothing to do and the behavior is unchanged.

**Fix**, pick one:

```sh
moon clean                 # full rebuild, the easiest path
# or delete only the matching artifacts (paths vary with build layout and target):
rm -rf gui/_build/native/**/build/<pkg>/     # recompile this package
rm -rf _build/native/debug/build/examples/<example>/<example>   # relink this example
```

Then run `moon build` / `moon test` again: the stub is recompiled and a fresh exe is linked.

When debugging, first reproduce with a new main target: a fresh target is always linked fresh. If main runs fine but the test crashes, the test binary almost certainly linked a stale archive, not a logic bug. The finer per-platform records are in [adaptation.md](adaptation.md).

## 4. Vendored large files and mirrors

Three third-party files are kept out of git — committing them would permanently bloat the git history — and are downloaded by prebuild when missing: `WebView2.h`, `WebView2LoaderStatic.lib`, `miniaudio.h`, about 18.6 MB in total.

- **Verification first**: a file is written only if its sha256 matches the constants in the two prebuild scripts, so any mirror is verifiable.
- **Mirrors are tried in order**: GitHub → Gitee, with no latency probing, so two machines never fetch different content from different sources.
- **20 s per source**: a direct connection to a GitHub Release asset from a CN network can stall at zero bytes for a long time; failing over quickly beats waiting.
- **Swapping or adding a source**: edit one line of `VENDOR_BASES` in `gui/scripts/prebuild.py` and in `modules/gui-media/prebuild.py`. The two copies are deliberate — `gui-media` must be able to publish standalone.
- **Intranet and offline**: the `NATIVE_GUI_VENDOR_BASE` environment variable takes a single base or a comma-separated list, tried first. You can also place the files at their target paths by hand — prebuild only downloads when missing and never touches existing files.
- If every source fails, prebuild does not abort; it prints the manual-placement hint and leaves the missing-file error to the link step.

Licenses and provenance: [THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md) at the repository root.

## 5. Related

- Platform adaptation pitfalls and verification: [adaptation.md](adaptation.md)
- Environment setup and your first project: [tutorial.md](tutorial.md)
- Components and API: [components.md](components.md)
