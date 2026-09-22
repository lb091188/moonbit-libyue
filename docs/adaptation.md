# Platform Adaptation Notes

Field-tested pitfalls and conclusions per platform; each entry records only the pitfall and the fix. Protocol-interop conclusions all come from real buses and real panels. Linux is organized by distribution → desktop environment, Windows / macOS by version; add new conclusions to the matching section and sync the Chinese version ([docs/zh/adaptation.md](zh/adaptation.md)) in the same batch.

## Performance Baseline

Overhead of the full MoonBit stack (shim + MoonBit runtime) relative to native C++: examples/hello (release build) compared against a functionally identical pure-C++ libyue hello, both linked against the same vendored static library — no shim on the C++ side, so the delta is the entire wrapper cost.

| Metric | Native C++ | Full MoonBit stack |
|---|---|---|
| Startup (median of 20 warm starts, exec → window map) | 73ms | 70ms |
| Steady-state memory (Rss, 3s after the window appears) | 62.1MB | 62.9MB |
| Binary size | 6.52MB | 7.39MB |

Methodology: Ubuntu 24.04 XFCE (X11), same machine and session; the startup delta is below detection granularity — a tie. C++ side built with `-std=c++20 -O2 -DNDEBUG`; headers from the same-version fork tree (nativeui) plus the prebuilt companion tree (base/build, with `base/allocator/partition_allocator/src` added as an include root). Without `-DNDEBUG` the link fails on the missing `RefCountedBase::CalledOnValidSequence` symbol.

## Cross-Platform (build chain / FFI)

### Build and Linking

- moon must run at the repository root: vendor/build artifacts and WebView2Loader.dll are located via the working directory at runtime.
- Library packages must not carry a `link` section (moon would generate a main-less exe and the build fails); all link flags come from `scripts/prebuild.py` via the `--moonbit-unstable-prebuild` hook, which emits link_configs auto-propagated to every main package depending on yue. Never hand-write `cc-link-flags` in any package.
- prebuild script constraints: stdout must carry only the final JSON (progress goes to stderr); all flags go in the single link_flags string with hand-controlled ordering (`-lyue_mbt` must precede `-lstdc++`, GNU ld is single-pass); the script's cwd is the consumer's project root, so library paths must be absolute.
- moon does not relink when a static library changes (prebuild only rebuilds a missing library): after shim or static-library changes run `prepare.py` to rebuild plus `moon clean` (or delete the produced exe) to force relinking; `nm build/libyue_mbt.a | grep <symbol>` with zero hits means a stale library. prebuild rebuilds automatically when shim sources are newer than the vendored library.
- shim patches land as commits in the fork (lb091188/yue, main = upstream v0.15.6); fork CI emits three-platform source packages and prebuilt libraries on `v*-mbt*` tags. A shim change must backfill the local platform's vendored library in the same batch and promptly align all three platforms via the `vendor-*` CI, otherwise the zero-compile mooncakes path is broken for users.
- The static library and the shim must come from the same compiler family: on Linux a clang-built library + gcc-built shim segfaults reliably (same ABI, same libstdc++); prebuilt libraries are built with gcc. Ubuntu 22.04 toolchain artifacts need `-latomic` at final link.
- libyue version is pinned in prepare.py (`LIBYUE_VERSION` + six-asset sha256); update checksums when upgrading.
- Vendored libraries ship with mooncakes (`lib/<platform>/`); prebuild resolves "vendored → build/" in cascade. Three-platform artifacts are pinned by `vendor-native.yml` (tag `vendor-*`); maintainers align with `vendor_native.py --fetch <tag>`.
- Recent moon deprecates `moon.mod.json` / `moon.pkg.json` (`moon fmt` migrates in one shot); `moon doc` only accepts the new format, and older moon does not understand it.
- MSVC misreads BOM-less UTF-8 source as cp936; Chinese comments produce fake preprocessing errors (the reported line has no such directive): CMake adds `/utf-8` for MSVC.
- Adding a shim function: definitions use `extern "C"`, declarations go into the extern "C" block of `yue_mbt.h` in the same batch, and `nm` must show no `_Z`-prefixed symbol; GLib (`g_*`) is Linux-only — cross-platform functions must not call it.
- Recent moon deprecates implicit trait-method promotion: call sites use the explicit static form `ViewLike::method(obj)`; `impl Trait for X` declaration sites need explicit `pub extend X with Trait::{...}` (generate the method list from `moon check --no-render` output, don't hand-copy); black-box tests must qualify in-package symbols as `@yue.xxx`. These warnings are missed by incremental builds — a clean full build surfaces them all.

### MoonBit cfg(platform=)

- moonc implements `#cfg(platform="windows"/"linux"/"macos")`, evaluated from the `-target` triple; but current released moon passes moonc an OS-less `native` target, so every condition is false. The condition lights up once `moon build -v` shows the full triple in the moonc command line.
- Current substitute: runtime `platform()` checks — declarative trees assemble nodes conditionally and simply skip creation when unmet.

### Declarative Layer and Self-Drawn Components

- Never call `set_background_color` inside mouse callbacks: runtime CSS rewrites swallow the immediately following press ("works on the second click"). Interactive states (hover / pressed) are expressed in on_draw; set_background_color is allowed only at mount time and in theme-subscription callbacks.
- A flex container's attach order is also its layout order and z-order: interleave widgets (handles / dividers) must attach in exact layout position and stay permanently visible — users find them by looking, not by hovering.

### Self-drawn canvas and chart rendering

- An offscreen `Canvas::new + get_painter` supports all geometry drawing (fill / stroke / arc / clip) without `initialize()`, so drawing benchmarks run on headless CI too; but text paths (`draw_text` / `AttributedText::get_bounds_for`) segfault outright — the GTK text stack needs initialize first. Benchmarks therefore come in two tiers: "pure pipeline + geometry-call mirror" (no display needed) and a real full-frame run (text included) that only executes when DISPLAY is present; both tiers print from `charts_wbtest.mbt`.
- `stroke()` under the painter's default stroke color is a no-op (draws nothing): a benchmark that forgets `set_stroke_color` shows stroke cost as ~0 and passes bogusly. Always set an explicit color before timing strokes.
- Under software rasterization (GTK/X11, no GPU) a path stroke costs ~1.8µs per segment, ~13µs for near-vertical segments (slope > 30); `fill_rect` ~1µs each (axis-aligned fast path), `draw_text` ~0.11ms per call, `line_to` itself ~12ns (path building only). A 1000-point × 4-series line chart drawn entirely with path strokes costs 45–60ms per frame — far over the 5ms acceptance line.
- Fix (shared by the whole chart family, see `yue/charts.mbt`): in dense mode (more points than pixel columns) decimate to columns (min/max preserving extremes) and switch to rect paths — area mode fills one rect per column up to the anchor (the fill's top edge *is* the line), line mode draws a min..max vertical bar per column; only sparse mode (points <= columns) uses a true polyline plus polygon area fill. Per-frame cost is decoupled from window size and grows only with plot width.
- libyue's Arc cannot express a counterclockwise arc: on GTK `PainterGtk::Arc` is a plain `cairo_arc`, and cairo normalizes `ea < sa` into a "plus 2π clockwise long arc"; the Win public API is hardwired clockwise too (the underlying ArcPixel has an `anticlockwise` parameter that is never exposed). The shim's "ccw as negative span" conversion therefore never takes effect on either backend — using ccw for a ring's inner arc wraps the hole into the long arc and fills a solid pie (verified by real-machine screenshot: donut and gauge centers were not hollow, with the total/percentage painted on the solid face). Fix: approximate the inner return arc with a polyline (32 segments per full circle, chord error < 0.4px, identical on all platforms); for pure strokes (icon arcs) simply swap the start/end angles, which is geometrically equivalent. Changing `PainterGtk::Arc` to `cairo_arc_negative` in the fork would be the root fix, but that needs a vendor-* release, so it is deferred.
- Chart acceptance benchmarks (release, Ubuntu 24.04 XFCE X11, offscreen canvas + initialize, real full frame incl. text): line 1000 points × 4 series (adversarial sawtooth) 3.08ms / smooth data 1.81ms; bar 200 categories 0.38ms; donut 50 sectors 0.70ms; gauge 0.15ms; scatter 10000 points 3.03ms. Pure-function pipeline (range / ticks / decimation / mapping) for the line chart: 0.028ms. Long-run push: 4800 pushes (10 min at 2Hz × 4 series) total 2.89ms with window length pinned at 1000 — live data is bounded at 4 × 1000 × 8B = 32KB; the increment is GC-reclaimed window garbage, which does not accumulate across continuous pushes.
- Line area anchor: the zero line when 0 is inside the range, the plot bottom for all-positive data, the plot top for all-negative (straddling columns emit two rects, above and below).
- `Painter::DrawText` (canvas `draw_text`) defaults to `wrap=true`: long text in a fixed-height row or narrow box gets wrapped by the platform layout engine and overflows the row bounds. Three symptoms verified on the real machine: process-table command lines (often 100+ chars) wrapped and bled into the next row; large chart y-axis values ("21414.7") stacked vertically as multi-line garbage; end-value labels of multiple line series overlapped when their last values were close. Fix: the shim gained `yue_mbt_painter_draw_text_ex` exposing TextAttributes' wrap/ellipsis (pure ABI translation), MoonBit's `draw_text` gained optional parameters, and table cells now draw with `wrap=false + ellipsis=true` (truncation is done by the platform layout, so no per-cell measurement); `fmt_axis` switches to k/M/G units from |v| >= 1e4 (one decimal, trailing zeros trimmed) so labels stay within 5 characters and never trigger wrapping; end labels are now collected, spread apart by y (14px minimum gap, clamped back into the canvas), then drawn.
- Chart / virtual-table responsiveness (`fill` switch): no fixed width — the container stretches along the cross axis of the column parent and follows window resizes. In the table's fill mode, column geometry is re-laid-out on every paint from the actual width: fixed columns keep their (possibly drag-resized) widths while elastic columns share the remainder (dragging swaps width between the two adjacent columns conservatively, so it never conflicts with the elastic re-layout). Self-drawn row containers that anchor to `w - offset` already followed their parent's width.

### Layout Geometry (Yoga flexbox)

- Built-in layout assertions pass 16/16 (±1px); composition rules: content area = container − 2×padding; gap does not stack with margin; percentages resolve against the parent content width.
- Composite widgets (Tab / Scroll / Group) are measure-less leaf nodes in the yoga tree: their outer size must be given explicitly (e.g. `flex:1`) or they collapse (Tab freezes its minimum size at construction, driving the page area to zero).
- tabs_t once hard-coded the outer width to 360px and gave content pages no flex: any Scroll / Table placed inside collapsed to zero (measured: the sysmonitor overview page rendered completely blank except the tab strip). Fix: outer drops the fixed width in favor of `flex:1` (stretch gets the width in a column parent; fills when the parent has a definite height) and content pages get `flex:1` too. When the parent has no definite height flex does not grow, so embedded usage (the showcase section) is unchanged.
- GUI automation: prefer keyboard (Tab focus + Space activate); `xdotool key --window` sends XSendEvent events that GTK drops — use XTEST (no --window); coordinate clicks are unreliable due to WM decoration offsets.

### MoonBit ↔ C ABI

- Trampolines must match the C function pointer prototype bit-for-bit, including arity: C calls `callback(closure, args...)` and the trampoline's first parameter receives the closure. Misalignment hides itself — row counts work, some callbacks fire; a callback is verified only once it has actually fired.
- `extern "c"` returning nullable types: older toolchains segfault outright (report success/failure via a `Ref[Int]` out-parameter); on moon 0.1.20260904 + moonc v0.10.12, `-> Bytes?` works — a C-side NULL maps to None correctly, verified in both debug and release against real missing-file and directory (EISDIR) paths (sysmonitor's read_text_file). Other nullable types (handles etc.) are untested; the out-parameter pattern remains the fallback.
- FFI pointer parameters need `#borrow` (compiler-enforced); widget parameters take the handle type `View`, never the MoonBit wrapper struct (otherwise handles are invalid at runtime and silently dropped).
- Closures across the ABI: capture-free top-level function literals compile to real C function pointers; capturing closures use the "function pointer + closure pointer" two-parameter form.
- Callback closures are kept alive process-wide by a registry and not reclaimed per window (negligible leak for single-window tools — settled).
- Toolbar / Vibrant have no Linux static-library symbols (link would fail) and are not exposed; the Browser empty-cookie-list crash is fixed since fork mbt.7.
- Changing a shim signature requires the same batch in `.cpp` / `yue_mbt.h` / ffi.mbt; both a missed signature sync and an entirely missed declaration manifest as a mangle split (`_Z`-prefixed symbol vs plain-C reference) — locate with nm, and run a ".cpp definitions × header declarations" cross-scan before packaging.
- The XFCE panel prioritizes IconPixmap over IconName: set_icon_name and set_pixmap are mutually exclusive — setting one must clear the other.

## Linux

### Distributions

#### Ubuntu 24.04 ✅ mainline

- System dependencies: `build-essential cmake pkg-config libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev libwebkit2gtk-4.1-dev`.
- AppIndicator runtime is gone, so libyue's built-in tray is unusable → replaced by `yue/traybus/` (pure-MoonBit SNI direct to the panel).
- The webkit2gtk package name varies by distribution (4.0 / 4.1); prepare.py probes with pkg-config and accepts either.

#### Other distributions ❓ untested

- First porting step: check each dependency's pkg-config name, then run prepare.py.

### Desktop environments (tray / menu behavior)

#### XFCE ✅

- Context menus are rendered by the panel mirroring DBusMenu; the app is not asked to draw via SNI ContextMenu.
- xfce4-panel 4.18 sends only the batch `EventGroup` / `AboutToShowGroup`, not the singular versions: implementing only the singular forms gets silently rejected by UnknownMethod — the menu opens but clicks do nothing.
- Desktop notifications must go through `Notification::Show()`; `NotificationCenter::AddNotification` never issues the DBus Notify call on Linux and fails silently.
- Global shortcuts are exclusive XGrabKey registrations; a taken key combination makes Register return -1 (no crash, silent failure) — callers must check and offer another key.
- With desktop focus, xfwm4 captures the keyboard and global shortcuts do not fire (they work when an application window has focus).

#### GNOME ✅ (X11 and Wayland sessions)

- The AppIndicator extension reads the Menu property at registration time to build its proxy: an empty menu returning `/` permanently kills the menu client (clicking the icon does nothing). traybus always returns the real `/MenuBar`, exporting it even when empty, filled via LayoutUpdated.
- With `ItemIsMenu=false`, both left and right clicks emit Activate.
- Global shortcuts segfault on Wayland sessions (upstream casts the root window through a GDK X11 macro): a `GDK_IS_X11_DISPLAY` guard is in place; non-X11 sessions get Register = -1.
- Mouse button semantics are yue-unified 1=left 2=right 3=middle (GDK's 2/3 are swapped); components judge by yue semantics.
- Environment variables for launching GUI apps over SSH: X11 session `XAUTHORITY=/run/user/1000/gdm/Xauthority`; Wayland session `XAUTHORITY=/run/user/1000/.mutter-Xwaylandauth.*` and `WAYLAND_DISPLAY=wayland-0`; both need `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`.

#### KDE ✅ (Plasma 5.27)

- The panel consumes SNI directly; new icons go straight into the visible tray area; tray / menu / quit all pass.
- Protocol behavior is the opposite of XFCE: only singular `Event` / `AboutToShow`, no batch versions; traybus implements both.

#### Deepin ✅ (23 / 25, DDE)

- dde-dock implements StatusNotifierWatcher; SNI direct connection works; new icons land in the collapsed tray area by default and can be dragged out.
- libyue's Popover (transparent window + pointer grab) does not render on DDE and slows the pointer: the shim checks `XDG_CURRENT_DESKTOP` (23=DDE, 25=Deepin) and falls back to a borderless plain window.
- Binaries built on the host (Ubuntu 24.04) run directly: the glibc symbol ceiling is 2.38 and deepin ships the webkit2gtk-4.1 runtime; for cross-distribution shipping, check the glibc symbol requirement first (`objdump -T | grep GLIBC_`).
- `TextEdit::Delete()` deletes the selection, it does not clear; use `set_text("")` to clear.
- DDE clipboard-manager interactions produce occasional CHECK / CRITICAL log noise; functionality is unaffected.

#### KDE / MATE / Cinnamon / Budgie / LXQt ❓ untested

- All support SNI at the protocol level and traybus implements the protocol; awaiting per-environment verification.

### DBus wire protocol (traybus)

- The DBus array length prefix excludes alignment padding before the first element; counting it makes dbus-daemon disconnect as a protocol violation.
- The variant signature in the header SIGNATURE field is "g" (u8 length-encoded); encoding it as "s" passes unit tests but real buses reject it.
- The SNI Menu property must always return the real menu object path — never `/`, even when empty.
- Unit-test self-consistency ≠ interop: protocol issues are located with dbus-monitor on the real bus; GNOME panel-side exceptions show up in journalctl.

- Measured sysmonitor figures (Ubuntu 24.04 XFCE X11, same methodology as the performance baseline at the top of this file: startup median, steady-state RSS, release binary): startup (exec → window map) over 5 runs 77/78/81/82/88ms, median 81ms (the hello baseline of 70ms is an idle system; this run carried 1042 processes); steady state with the process page foregrounded at 1Hz uses 2-3% CPU (sampling + derived data + 1000-row table rebuild + repaint total ≈ 25ms/second), RSS 84.9MB flattening at 85.8MB after 100s; binary 7.72MB (hello counterpart 7.03MB). The 1000-row process page meets acceptance: full sampling of 1053 processes takes 14.94ms/pass (release, ≈14µs per process — two /proc reads each), a 1.5% duty cycle at 1Hz.
- The 1000-row table uses table_v_t virtual scrolling (only visible rows draw): refresh goes "full data sampling → filter/sort derived data → rows Store set → table load + schedule_paint", never rebuilding the view tree; selection is remapped by pid so it doesn't drift as the sort order changes every second. There is no C++ counterpart binary, so the combined "wrapper + data layer" overhead is attributed directly from the figures above; the UI drawing portion is on par with the hello baseline under the same methodology.
### System monitor data layer (/proc, /sys — sysmonitor example)

- /proc and /sys pseudo-files always report stat size 0 (fseek/ftell cannot learn the length): whole-file reads must loop with incremental `fread` and a doubling buffer (16MB cap); opening a directory succeeds but `fread` fails with EISDIR — detect via `ferror`. Implemented in the app's own native stub `examples/sysmonitor/stub/sysmon.c`; the MoonBit side goes through `read_text_file`.
- An app-owned native stub may live in a subdirectory: `"native-stub": ["stub/sysmon.c"]` resolves relative to the moon.pkg directory; all symbols are within libc's default link set — zero shim / fork / vendored / link-flag changes. The test target links the stub automatically, so wbtests can read real /proc files.
- /proc/stat column order is `user nice system idle iowait irq softirq steal guest guest_nice`: the 9th column (guest) is already folded into user/nice by the kernel — adding it double-counts. Usage = (Δtotal − Δidle − Δiowait) / Δtotal; iowait is not CPU-busy. When the sampling interval is shorter than one tick (USER_HZ, usually 10ms), Δtotal ≤ 0 and the result is 0; a zero first sample makes the first screen show the since-boot average.
- /proc/cpuinfo model field differs by platform: x86 uses `model name`, ARM boards only have `Processor` / `Hardware` — three-level fallback; core count = number of `processor` lines (logical CPUs incl. hyperthreading, matches nproc).
- /proc/meminfo units are always kB; `MemAvailable` only exists on kernels ≥ 3.14 — fall back to `MemFree`; used = total − available (includes reclaimable cache).
- The `moon run` wrapper process does not forward signals to its child: smoke-testing exit behavior requires killing the built exe child process — killing only the wrapper PID leaves an orphan window.
- Measured full-process sampling (release, Ubuntu 24.04): 580 processes × 2 file reads (stat + cmdline) = 9.57ms per pass, ~1% CPU at 1Hz refresh; RSS comes from stat's page count × page size (equal to status's VmRSS), saving a third read per process.
- /proc/[pid]/stat comm can contain spaces and nested parentheses (process name "(foo (bar))") — split at the LAST ')' in the line; comm is truncated to 15 chars, so the full command line is read separately from cmdline (NUL-separated; empty falls back to [comm] for kernel threads).
- getpriority's nice = -1 is a legal value and is ambiguous with the error return: report success/failure via a `Ref[Int]` out-parameter (kill / setpriority still use the errno return).
- Windows has no /proc and no nice semantics: the stub keeps the same ABI at compile time and returns an "unsupported" sentinel (-1000) at runtime, which the MoonBit layer turns into a Chinese notice — the whole process page degrades cleanly; three-platform CI builds are unaffected (macOS takes the POSIX branch naturally).
- diskstats lists both whole disks and partitions (nvme0n1 alongside nvme0n1p1/p2/p3); an LVM mount's device name (/dev/mapper/ubuntu--vg-ubuntu--lv) does not match its diskstats name (dm-N) — resolve via `/sys/block/dm-*/dm/name` to find dm-N, then take the first slaves entry (measured: dm-0 → nvme0n1p3) to attribute IO rates to the mount row.
- hwmon temperature indices skip numbers (coretemp exposes only some cores' tempN_input); labels may be absent (acpitz has none — fall back to the chip name); millidegrees can be negative (battery sensors); NVIDIA dGPUs commonly expose no hwmon temperature (measured: 0x2488 has none), so GPU temperature shows "—" under the hwmon convention.
- statvfs capacity uses f_bavail (available, minus reserved blocks) rather than f_bfree, matching df's Use% convention; the struct is flattened across the ABI into three int64 out-params (total/free/avail).
- /proc/mounts pseudo-filesystems (~20 kinds: proc/sysfs/cgroup2/devtmpfs/efivarfs …) have no meaningful statvfs capacity — the capacity table skips them via an fstype blacklist, keeping only real /dev/ device lines; multiple mounts of one device (btrfs subvolumes / LVM snapshots) are deduplicated by device, first occurrence wins.
- Directory enumeration (/sys/class/hwmon, /sys/class/net, /sys/bus/pci/devices, /sys/block/*/slaves) goes through a generic opendir/readdir stub (newline-separated entry names); together with read_text_file these are the data layer's only two IO primitives.
- The /dev/fuse control mount (appears once the file manager brings up gvfsd-fuse; mount point /tmp/fuse) returns a valid statvfs with f_blocks=0: filtering by the fstype blacklist alone is not enough — also skip total<=0, or the disk page shows a "0 MB / 0 MB" noise row (verified: the S5 whitebox assertion total>0 failed because of it).
- sysmonitor UI copy discipline (from the full UI-polish pass): interface text states only "what it is / how to use it" — never data conventions or implementation paths (e.g. /proc paths, "two-sample difference", "milli-degree conversion", or a "nvidia-smi planned later" note); rates, capacities and axis values always switch units dynamically (B→K→M→G) so numbers stay short; the large 24px statistic cards especially must never wrap and overflow.

### Display protocols

- X11 ✅ mainline; Wayland unsupported — verify GUI behavior in an X11 session (tray / shortcuts are session-guarded).

### GTK specifics

- A Table inside a Notebook tab segfaults during size measurement (negative allocation): keep it in a plain container or a standalone window.
- Content widgets (Group / Scroll) extend View, not Container: attach content via `SetContentView`; `AddChild` is rejected by the type check.
- Upstream NUContainer defects (patch `patch_linux_container_events`): (1) the event window raises on map, stealing hits from native child widgets (tabs unclickable, wheel dead) → `gdk_window_show_unraised`; (2) container preferred sizes hardcode 0 and Scroll's size_request is 0×0 → width follows the viewport, height resolves to the content's natural yoga height. Do not report yoga's dynamic natural size to GTK: allocation pollutes yoga state and requisition negotiation oscillates without converging.
- The visibility guard at the top of `UpdateChildBounds` misses GTK's first size-allocate (it happens before map): layout must run unconditionally.
- `Slider::SetValue` sets the ignore flag even for identical values, swallowing the user's first callback: set it only when the value actually changes.
- `ProgressBar::SetValue` means 0..100 on both Linux and Windows; the yue layer is unified on 0..1, so the conversion branch must cover both platforms.
- `View::GetBoundsInScreen` stacks coordinates wrongly under Scroll / nested containers (patch `patch_linux_view_bounds_in_screen`): GTK screen coordinates must be "client-area origin (`gdk_window_get_origin`) + offset within the client area (`gtk_widget_translate_coordinates`)"; `gtk_window_get_position` includes the title-bar decoration — mixing it with translate is off by exactly one decoration size.
- Table checkbox-column indicators scale with row height (XFCE theme): set `indicator-size=16` explicitly on checkbox columns and cap the renderer height at 20.
- Drag-out data must use the `Data(std::vector<base::FilePath>)` constructor (the string constructor silently degrades to Text); relativize paths first (`g_filename_to_uri` rejects relative paths).
- The drag preview hotspot is hardcoded to (0,0) upstream; the patch centers the image on the cursor (`patch_linux_drag_icon_hotspot`).
- Whether a drop is accepted is decided by drag-motion (`handle_drag_update`); `handle_drag_enter` is only an entry notice. Register the Image data type too — dragging in from image viewers / browsers yields image content, not file paths.
- libyue's `Entry::SetText` swallows `on_text_change`: the GTK side guards with an `is-editing` object-data flag that filters the `changed` signal during programmatic sets (loop prevention), so the visible text changes but consumers get no callback — `input_t`'s clear ✕ therefore "cleared the text but never refreshed the filtered list". Fix: the clear handler explicitly invokes `on_input("")` once. Any path that programmatically changes Entry / TextEdit text and then relies on the callback must invoke it manually.
- Drag-out initiation: calling `gtk_drag_begin` synchronously desyncs GTK's drag state machine (nested gtk_main never exits, drag works once), so it must be deferred until the event queue drains, initiated with the press event, and the drag_context backfilled; drag-failed needs a defensive cleanup (fork mbt.12).
- Creating a Browser page (WebKitGTK) aborts the process immediately: `Could not create GBM EGL display: EGL_NOT_INITIALIZED. Aborting...` — WebKitGTK 2.5x's DRMDeviceManager initializes the main DRM device when a WebView is created and RELEASE_ASSERTs to death when the GBM EGL display can't be obtained. On the NVIDIA proprietary driver without `libnvidia-egl-gbm`, GLVND only has the X11 backend (`10_nvidia.json` has no GBM), so neither card1 nor renderD128 yields a display (measured: `eglGetPlatformDisplay(GBM)` returns NULL; note that in-process probe results don't match WebKit's actual path — an in-process probe on renderD128 initialized successfully while WebKit still aborted, so don't gate on probe results). showcase mounts a Browser page on its first screen, so it always crashed. Library-side fix: the shim's app_init (Linux) sets `WEBKIT_DISABLE_DMABUF_RENDERER=1` unconditionally (overwrite=0, an explicit user setting wins), pushing WebKit onto the legacy rendering path — no more crash, full Browser functionality (only web content loses one layer of GPU acceleration; the cairo-based UI is untouched). Verified: bare `moon run examples/showcase` opens its window, stays alive, zero aborts. Root fix at the system level: install `libnvidia-egl-gbm` (NVIDIA's GBM EGL backend), after which `WEBKIT_DISABLE_DMABUF_RENDERER=0` restores hardware rendering. Engineering note: after changing the shim, moon does not necessarily relink (the exe isn't in its dependency graph) — run `moon clean` or delete the exe to force a relink and confirm with `nm exe | grep <new symbol>`.
- Reading the system accent color (GTK3 has no accent API; `yue_mbt_system_accent` falls through three steps): 1) the GNOME 47+ GSettings key `org.gnome.desktop.interface`/`accent-color` — when the schema exists but the key does not (e.g. Ubuntu 24.04's gsettings-desktop-schemas), `g_settings_get_string` aborts instead of returning empty, so probe with `g_settings_schema_has_key` first (abort reproduced with a probe on this machine); 2) `@define-color theme_selected_bg_color` in the current theme's CSS: GTK themes express their primary color as the selection background, searched in `~/.themes` → `$XDG_DATA_HOME/themes` → `$XDG_DATA_DIRS/themes` → `/usr/share/themes` under `gtk-3.0/{gtk,gtk-contained,gtk-dark}.css`, with the dark preference deciding which file is parsed first (Orchis themes define the light accent in gtk.css and the dark variant in gtk-dark.css); 3) empty when neither hits. Verified with a probe (Ubuntu 24.04 + XFCE + Orchis-Teal-Light-Compact): returns `#009688`, matching the theme CSS bit for bit; XFCE has no accent setting, so step 2 is what captures the theme's primary color.

## Windows 10 / 11 ✅

### Toolchain

- Requires VS Build Tools (VCTools workload + the ATL component for `base/win/atl_throw.h`); run moon / cmake from an x64 Native Tools Command Prompt or after vcvars64. Installer quiet / passive mode requires elevation, else Exit 5007.
- Release asset names are `libyue_{v}_win.zip` / `_mac.zip` (not windows / darwin).
- On case-sensitive volumes compilation fails with C1083 on `webview2.h`: the SDK ships only `WebView2.h` (capital W); prepare.py adds a lowercase alias after extraction. On the same volume `shutil.copyfile`'s samefile check is unreliable — delete the destination before copying.
- Platform-specific code must guard its includes and implementations in the same batch: a bare `gtk/gtk.h`, or a function guarded at the call site but not at the definition, explodes on the other platform's compiler with C1083 / C2065.
- shim platform differences: guard `dlfcn.h` with `__linux__`; MSVC needs `_USE_MATH_DEFINES` for `M_PI`; `base::FilePath` is `std::wstring` under UNICODE builds — go through `FromUTF8Unsafe / AsUTF8Unsafe`; Windows has no Popover and no `SetOverlayScrollbar` / `Clipboard::Selection` / `Tray::SetTitle` etc., all degraded to no-ops in the shim; `operator new/delete` redirect to `malloc/free` (moon builds its runtime with MOONBIT_ALLOCATOR=SYSTEM); a widget's HWND comes from `dynamic_cast<nu::SubwinView*>(GetNative())->hwnd()` — `GetNative()` itself is not an HWND.
- Native child HWNDs do not follow the container after scrolling (they float over scrolled content): force `View::Layout()`, and the scroll wrapper registers on_scroll with the callback deferred via a 0ms timer until layout completes; an input's inner shadow is `WS_EX_CLIENTEDGE`, so borderless must clear STATICEDGE / CLIENTEDGE / WS_BORDER; DatePicker shows only the year unless given an explicit width; glyph-based small icons are inconsistent across platforms — draw them with Painter vectors inside components.

### Link flags (moon → cl / link)

- `cc-link-flags` is spliced verbatim into the cl command line; GNU-style `-L/-l` triggers D9002. The correct form is link inputs (`build/yue_mbt.lib setupapi.lib …`): cl forwards .lib position arguments to link, and system libraries resolve via the LIB environment variable.
- Path separators must be forward slashes: backslashes are eaten by moon's argument parsing and link fails with LNK1104.
- The official CMakeLists system-library list is incomplete; copying it verbatim yields 144+ LNK2019. The prepare.py list is complete.
- The CRT must match moon's static /MT: CMake multi-config generators ignore `CMAKE_BUILD_TYPE`, so `cmake --build` must pass `--config Release` (prepare.py automates this), else LNK4098 plus unresolved `__imp__*`.
- The console window on exes is fixed by the `win_gui.c` link pragma built into the yue package: the pragma lives in the .obj's drectve section and an archived member is only read if it is referenced — `initialize()` references the stub symbol `yue_mbt_win_gui_marker` to guarantee extraction, so consumers need zero configuration; the PE-header rewrite in release-bin.yml (Subsystem 3→2) remains as a fallback. User link_flags are spliced before `/link`, so cl discards `/SUBSYSTEM`-class link options outright (D9002) — appending flags cannot work. Under the GUI subsystem stdout is visible only through pipes / redirection.
- After swapping `yue_mbt.lib`, `moon build` reports "no work to do": delete the produced exe under `_build` to force relinking.

### Manifest

- Without a manifest an exe fails at launch with "procedure entry point ordinal 345 not found" (TaskDialogIndirect is exported by ordinal from Common-Controls v6): the official manifest compiles to `yue_mbt_manifest.res` and reaches every exe via link flags; test drivers use `YUE_MBT_SKIP_MANIFEST=1` to avoid the CVT1100 conflict with moon's own MANIFEST.

### Runtime differences

- `AttributedText` ranged font / color: upstream Windows supports only whole-text (ranged calls CHECK-crash; GDI+ has no rich text). Fork mbt.9 builds a segmented layout engine (run storage / flowing line breaking / measure-draw from one source) and the MoonBit-side degradation guards are removed — three platforms now agree. Gotcha: `Gdiplus::Font::GetHeight`'s overload takes `(const Graphics*)`; passing a reference does not compile.
- `Color::Get(Border)` hits NOTREACHED and returns a garbage color: the shim maps Border to `GetSysColor(COLOR_WINDOWFRAME)`.
- Blurry self-drawn text: libyue's GDI+ brush hardcodes grayscale antialiasing; an idempotent prepare.py patch switches it to `TextRenderingHintClearTypeGridFit`.
- System notifications: WinRT toast looks up the notifier by AUMID and silently fails without an AppUserModelID; the shim sets the AUMID automatically before the first notification and writes the registry DisplayName.
- Browser prefers WebView2 (falls back to IE when the loader / runtime is missing); WebView2 follows the system proxy — on machines with a broken proxy set `LIBYUE_WEBVIEW2_ARGS=--no-proxy-server` (a prepare.py patch injects AdditionalBrowserArguments from the variable); the demo:// custom protocol does nothing under WebView2 (the IE path works).
- win32 Group / Scroll do not grow with content: give them explicit heights; ScrollImpl's scroll range only honors SetContentSize, so a prepare.py patch queries the content yoga tree for natural size when none was set explicitly.
- Key codes and modifiers: the Windows KeyboardCode uses Win32 VK values, normalized to the constant table at the events.mbt entry; Windows' native modifier bits are Shift=2 / Ctrl=4 / Alt=8, and the shim's `NormalizeModifiers` gained an OS_WIN branch mapping to the unified 1/2/4/8.
- Ghost tray icons: abnormal exits skip the CRT static-destruction chain and leave the icon behind; the shim installs four process-level hooks (atexit / SetConsoleCtrlHandler / SetUnhandledExceptionFilter / SIGABRT) that re-issue NIM_DELETE by "owner window + icon ID range"; a taskkill /F hard kill cannot be rooted out in-process. A blank tray icon means check the asset first (it was once a 1×1 placeholder).
- The Popover substitute (borderless / non-activating / topmost window): the popup needs `WS_EX_NOACTIVATE` (else clicking the popup steals focus); under nested scrolling `GetBoundsInScreen` yields garbage offsets, so anchor coordinates come from the native child HWND's `GetWindowRect`; close is destructive on Windows — a reusable popup switches to `SetVisible(false)`; outside-click dismissal installs a `WH_MOUSE_LL` hook that PostTasks a close when the press lands outside the popup rectangle; the popup background ignores themes, so `Popover::set_background_color` was added end to end. libyue's SetVisible / IsVisible are unreliable on a non-activating topmost window — use Win32 `SetWindowPos` + `SW_SHOWNOACTIVATE` directly.
- autocomplete keyboard navigation: the Windows branch attaches on_key_down on the Entry (↑↓ highlight / Enter select / Esc dismiss); single-line EDIT has no vertical-centering style, so `entry_vcenter` narrows the control by font line height and splits the leftover into margins; RichEdit text stays black regardless of theme — `Entry::set_colors` (EM_SETBKCOLOR + CHARFORMAT2) hooks it into the theme chain.
- Dark mode for native controls: real Win32 common controls (RICHEDIT50W / SysListView32 / SysDateTimePick32 etc.) all ignore the system dark theme; RichEdit can be darkened via the message channel; Table cannot (its custom draw repaints a white base over external messages); the official answer is the self-drawn component library, with native dark mode as a known boundary.
- Hit testing runs opposite to painting: upstream `FindChildFromPoint` iterates children in insertion order, so a late-attached full-screen mask paints on top but its events fall through to the earlier container (dialog uncloseable, clicks pass through) — fork mbt.6 reversed the traversal to match paint order. Any "visually-topmost view receives no events" — check the hit-test direction first.
- The wheel is consumed outright by the outermost Scroll and never dispatched, so nested scroll areas and self-drawn canvases never scroll: a prepare.py patch (`patch_win_wheel_dispatch`) dispatches to the child under the cursor via FindChildFromPoint, and shim `yue_mbt_view_on_wheel` gained a Windows branch converting WM_MOUSEWHEEL deltas.
- Text measuring and drawing disagree: `GetBoundsFor` uses GenericDefault (with overhang) while `DrawString` uses GenericTypographic, so manual `x=(width−measured)/2` centering always sits left; positioning must use `align=Center/End` and leave it to the platform — measuring is only for computing container widths.
- Two splitter traps: an explicit `SetCapture` on Windows triggers `WM_CAPTURECHANGED`, which tears down the implicit capture (skip if capture is already held); the `flexbasis:"50%"` percentage string parses only on GTK — use pixel values everywhere.
- The Entry infinite-recursion case: two mutually recursive functions in the non-Linux branch overflowed the stack, and MSVC C4717 had already warned — treat "logically doomed" warnings as errors. For "no window" GUIs use `Get-Process <name> | Select MainWindowHandle`; MoonBit println is fully buffered through pipes and lost if the process dies — instrument via stderr.
- mount_window activates the window automatically after the handle callback; consumers no longer call activate manually.
- Platform info / locale / scaling / clipboard / timers / global shortcuts / global mouse polling / canvas (GDI+) all verified working.

## macOS ❓ untested

- The libyue v0.15.6 release ships ARC / no-ARC dual libraries: Darwin link flags = main library + `-lyue_mbt_noarc` (no-ARC symbols are referenced by the main library, so it goes after) + frameworks AppKit / Carbon / IOKit / Security / WebKit / OpenDirectory + `-lobjc -lc++ -lpthread -lbsm -Wl,-dead_strip`; the prebuild Darwin branch is pre-configured accordingly.
- CI (macos runner) covers build + tests; headless runners have no WindowServer, so no GUI smoke.
- `#else` fallbacks in shim platform branches swallow macOS: borderless needs `#elif defined(OS_WIN)`; CurrentDirForDrag splits into three branches (mac uses `getcwd`); `Window::SetSkipTaskbar` / `SetIcon` / `App::SetID` have no macOS declarations — guard the calls as no-ops.

## Maintenance

1. Add new conclusions to the matching section, recording only the pitfall and the fix; protocol-interop conclusions must come from the real bus and real panels — unit-test self-consistency does not count.
2. Keep both language versions (this file and docs/zh/adaptation.md) in sync in the same batch.
