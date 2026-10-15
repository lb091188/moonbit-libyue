# System Capabilities (Volume / App Lookup / App History / Media & Desktop Control)

The system-capability API family: system volume, application lookup, night-light color temperature, wallpaper, monitor configuration, system window management, clipboard watching, subprocess execution, power plans, system information, printers, environment variables, directory enumeration, recent files, browser bookmarks and Firefox history, VS Code local history. All are read-only or write through an authorized system service, uniformly return `Result`; unsupported environments yield a corresponding error value instead of crashing; `*_supported()` performs a real probe of the current environment on every call.

## Platform Status (2026-10-14, after platform batches ①-⑥)

| Capability | Windows | Linux | macOS |
|---|---|---|---|
| clipboard / autostart / subprocess / file (fsx) / env vars (envx) | ✅ direct call | ✅ | ❌ Unsupported |
| system info / window management / wallpaper / power plans / launcher | ✅ direct call | ✅ | ❌ |
| app lookup / recent files / volume / printers (list+default+print) | ✅ direct call | ✅ | ❌ |
| browser/vscode data | ✅ (LOCALAPPDATA paths) | ✅ | ❌ |
| sysmonitor process data | ✅ (ships its own stub/sysmon.c) | ✅ | ❌ |
| night-light color temperature (redshift/xrandr command line) | ❌ no public API | ✅ | ❌ |

The low-level calls used directly on Windows: SystemParametersInfoW (wallpaper), ShellExecuteW (launch/reveal/print), PowerGet/SetActiveScheme, registry (product and DMI info), GlobalMemoryStatusEx, GetTickCount64, EnumWindows, EnumPrintersW, IAudioEndpointVolume (COM), GetLastInputInfo. For pitfalls and header/link requirements see the platform-batch entries in [adaptation.md](adaptation.md).

A full demo is available via `moon run NoahLiu/gui-examples/systemprobe` — press "Read system capabilities" to present the machine's real result for each item; unsupported capabilities show their corresponding error text. For per-capability conclusions and rationale on different distros / desktop environments (logind path, wpctl/pactl differences, direct SQLite reads, etc.) see [adaptation.md](adaptation.md).

## System Volume

Operates on the default output device (default sink). Backend auto-detection: prefers wpctl (PipeWire/WirePlumber), falls back to pactl (pipewire-pulse / PulseAudio) when unavailable, and yields `Unsupported` when neither is available. Detection runs for real on every call; for high-frequency scenarios the caller should cache results itself.

| Function | Description |
|---|---|
| `vol_supported() -> Bool` | whether the current system supports volume control |
| `vol_get() -> Result[VolumeInfo, VolumeError]` | read a snapshot: `VolumeInfo{ sink, volume, muted }` (sink name is an empty string when unavailable, which does not affect volume or mute) |
| `vol_set(percent) -> Result[Unit, VolumeError]` | set absolute volume (0-100, out-of-range clamped) |
| `vol_add(delta) -> Result[Unit, VolumeError]` | relative increase/decrease (positive adds, negative subtracts; final volume clamped on the tool side) |
| `vol_set_mute(mute) -> Result[Unit, VolumeError]` | set / clear mute |

Error `VolumeError`: `Unsupported` (no usable volume tool) / `CommandFailed(String)` (execution failed, timed out, etc.) / `ParseFailed(String)` (output parse failed, carries the raw text).

```moonbit
match @sys.vol_get() {
  Ok(v) =>
    println(
      "sink=\{v.sink} 音量=\{v.volume}% 静音=\{if v.muted { "是" } else { "否" }}",
    )
  Err(e) => println("不可用：\{e}")
}
let _ = @sys.vol_set(42)
let _ = @sys.vol_add(-5)
let _ = @sys.vol_set_mute(false)
```

## Application Lookup

Two parts: the installed-app inventory and application binary lookup. Linux scans XDG `.desktop` entries (user directory overrides system directory); Windows recursively scans the Start Menu (user-level + machine-wide) for `.lnk`, where the entry's exec is the full lnk path (launchable directly via ShellExecute) and categories is marked `StartMenu`; macOS is `Unsupported`.

| Function | Description |
|---|---|
| `appfind_installed() -> Result[Array[AppEntry], AppFindError]` | installed-app inventory (real scan; yields `NoScanDir` when none of the scan directories exist) |
| `appfind_installed_with(list_dir) -> Result[Array[AppEntry], AppFindError]` | same as above, with directory enumeration injected by the caller (for callers without an fsx layer and for tests; Linux branch only) |
| `appfind_executable(name) -> Result[String, AppFindError]` | Linux searches in order `~/.local/bin`, `/usr/local/bin`, `/usr/bin`, `/bin`, `/usr/sbin`, `/sbin`; Windows searches each `PATH` directory for name / name.exe; yields `NotFound` when not found |

`AppEntry{ id, name, locale_name, exec, icon, categories }`: id is the desktop id (.desktop filename without extension), name is the display name, locale_name is the localized name (`Name[zh_CN]` preferred, falls back to Name), exec / icon kept verbatim, categories split by semicolons. Results are deduplicated by desktop id (user directory overrides system directory) and sorted by name; entries whose Type is not Application, with NoDisplay=true, or missing Name are filtered out.

```moonbit
// Installed inventory: inject a directory-listing function (e.g. your own readdir wrapper)
match @sys.appfind_installed_with(fn(dir) { my_list_dir(dir) }) {
  Ok(apps) => for a in apps {
      println("\{a.locale_name}  \{a.exec}")
    }
  Err(e) => println("不可用：\{e}")
}
// Binary lookup
match @sys.appfind_executable("code") {
  Ok(path) => println("code 位于 \{path}")
  Err(@sys.AppFindError::NotFound(_)) => println("未安装")
  Err(_) => println("平台不支持")
}
```

## VS Code Local History & Recent Workspaces

Reads the local VS Code user data: the local history snapshot list for a given file (`User/History`) and the recently opened workspaces / folders. Paths for all three platforms are implemented (Linux / macOS / Windows each located by its user-data directory).

| Function | Description |
|---|---|
| `vsc_supported() -> Bool` | whether the machine has readable VS Code user data |
| `vsc_local_history(file_path) -> Result[Array[VscHistoryEntry], VscodeError]` | history snapshots for a file (time-descending, newest→oldest); pass either an absolute path or a `file://` URI; empty array when there is no history |
| `vsc_recent() -> Result[Array[String], VscodeError]` | recently opened workspace / folder paths (most recently active first); empty array when there is no window state |

`VscHistoryEntry{ path, timestamp }`: path is the absolute path of the snapshot file (its content is the file's full text at that moment), timestamp is Unix milliseconds, `timestamp_seconds()` converts to seconds. Error `VscodeError`: `Unsupported` (cannot locate the user-data directory) / `StorageUnavailable` (VS Code has never run on this machine) / `StorageCorrupted(String)` / `HistoryCorrupted(String)`.

```moonbit
match @sys.vsc_local_history("/home/me/proj/src/main.mbt") {
  Ok(snaps) => for s in snaps {
      println("\{s.timestamp_seconds()}  \{s.path}")
    }
  Err(e) => println("不可用：\{e}")
}
match @sys.vsc_recent() {
  Ok(paths) => if paths.length() > 0 {
      println("最近工作区：\{paths[0]}")
    }
  Err(e) => println("不可用：\{e}")
}
```

## Browser History & Downloads

Read-only access to the History databases of Chrome / Chromium / Edge / Brave (parses the on-disk file directly, does not copy or modify the original database); auto-detects all profiles (Default and Profile 1..24). Only the Linux path detection is implemented; other platforms yield `BhUnsupported`.

| Function | Description |
|---|---|
| `bh_supported() -> Bool` | whether the current platform is supported |
| `bh_browsers() -> Result[Array[BrowserProfile], BrowserHistoryError]` | list profiles with a readable History database; yields `BhNoBrowser` when none is readable |
| `bh_history(limit? = 200) -> Result[Array[HistoryItem], BrowserHistoryError]` | browsing history (aggregates all profiles, sorted by last-visit time descending, hidden redirect entries filtered out); limit ≤ 0 takes all |
| `bh_downloads(limit? = 50) -> Result[Array[DownloadItem], BrowserHistoryError]` | download records (sorted by start time descending) |
| `bh_search(keyword, limit? = 50) -> Result[Array[HistoryItem], BrowserHistoryError]` | substring search on url or title (ASCII case-insensitive); an empty keyword matches everything |
| `bh_download_state_name(state) -> String` | download state number → name (in progress / complete / cancelled / interrupted) |

`BrowserProfile{ browser, profile, history_path }`: browser is google-chrome / chromium / microsoft-edge / brave, profile is the directory name (Default or Profile N). `HistoryItem{ url, title, visit_count, last_visit_time }` (times are Unix milliseconds, 0 when unknown); `DownloadItem{ target_path, received_bytes, total_bytes, start_time, end_time, state }`. Error `BrowserHistoryError`: `BhUnsupported` / `BhNoConfigDir` / `BhNoBrowser` / `BhIoFailed(String)` (a single profile read failure is skipped; only errors when all fail).

```moonbit
match @sys.bh_history(limit=6) {
  Ok(items) => for it in items {
      let title = if it.title == "" { "(无标题)" } else { it.title }
      println("[\{it.visit_count}次] \{title}\n  \{it.url}")
    }
  Err(e) => println("不可用：\{e}")
}
match @sys.bh_downloads(limit=3) {
  Ok(ds) => for d in ds {
      println("\{d.target_path}  \{@sys.bh_download_state_name(d.state)}")
    }
  Err(_) => ()
}
let _ = @sys.bh_search("moonbit", limit=10)
```

## Media Control (MPRIS)

Enumerates `org.mpris.MediaPlayer2.*` player instances on the session bus; playback control (play / pause / play_pause / next / previous / stop) and status reads (PlaybackStatus + Metadata's title / artist / album) go through the MPRIS Player interface; playback control that fails on the bus can fall back to the `playerctl` subcommand (the command-class fallback path). Only the Linux path is implemented so far; other platforms uniformly yield `Unsupported`.

| Function | Description |
|---|---|
| `media_supported() -> Bool` | session bus usable (ListNames works) or playerctl usable |
| `media_players() -> Result[Array[MediaPlayerInfo], MediaError]` | enumerate player instances (including the playerctld proxy instance), preserving the ListNames response order; yields `NoPlayer` when there are none |
| `media_status(player) -> Result[MediaStatus, MediaError]` | read a player's status and current track |
| `media_play(player)` / `media_pause(player)` / `media_play_pause(player)` / `media_next(player)` / `media_previous(player)` / `media_stop(player)` | playback control (returns `Result[Unit, MediaError]`) |

`MediaPlayerInfo{ name, identity }`: name is the bus name (the argument to `media_status` / playback control), identity is the player's display name. `MediaStatus{ player, playback, title, artist, album }`, where `MediaPlayback` is `MediaPlaying` / `MediaPaused` / `MediaStopped` / `MediaUnknown(String)`. Error `MediaError`: `Unsupported` / `NoPlayer` / `BusFailed(String)` (carries the error name and description) / `CommandFailed(String)` (playerctl fallback failed) / `ParseFailed(String)`.

Playback control is a set-class operation, executed only when the caller explicitly calls it; the probe and query paths never trigger it.

```moonbit
match @dbus.media_players() {
  Ok(players) if players.length() > 0 => {
    let p = players[0].name
    match @dbus.media_status(p) {
      Ok(s) => println("\{s.title} - \{s.artist}（\{s.playback}）")
      Err(e) => println("读状态失败：\{e}")
    }
    let _ = @dbus.media_play_pause(p)
  }
  Err(@dbus.MediaError::NoPlayer) => println("无播放器")
  Err(e) => println("不可用：\{e}")
}
```

### Media Status Watching

MPRIS offers no unified signal-callback path (the bus can subscribe to `PropertiesChanged`, but that needs a resident read loop, incompatible with the library's synchronous-call model), so status watching uses polling deltas: read status at an interval, and fire `on_change` whenever playing state / title / artist / album changes; the first round only establishes a baseline and does not fire; the target player (empty player takes the first instance) is retried for resolution each round until it appears, then locked; rounds whose query fails are silently skipped.

| Function | Description |
|---|---|
| `MediaWatcher::make() -> MediaWatcher` | create a watch handle (running by default) |
| `media_watch_status(player?, interval_ms? = 1000, on_change) -> MediaWatcher` | start polling watch; an empty player watches the first MPRIS instance; on_change receives a `MediaStatus` |
| `media_watch_stop(w)` | stop watching (deregisters the timer on the next frame; not recoverable — to watch again use a new handle) |
| `MediaWatcher::is_running() -> Bool` | whether the handle is watching |

If the `on_change` callback throws an exception it interrupts that timer (make sure it does not throw itself); call `media_watch_stop` explicitly before the component is destroyed.

```moonbit
let w = @sys.media_watch_status(interval_ms=1000, fn(s : @sys.MediaStatus) {
  println("现在播放：\{s.title} - \{s.artist}")
})
// when no longer needed
@sys.media_watch_stop(w)
```

### Notification Progress

The desktop-notification spec itself has no progress field (the freedesktop notification protocol has no progress, and the native progress rendering on Windows / macOS each differs); the cross-platform-consistent approach is to render a character progress bar + percentage in the body.

| Function | Description |
|---|---|
| `notification_progress_text(percent : Double, width? : Int = 10) -> String` | progress text: character bar + percentage (percent clamped to [0,100], NaN treated as 0, width<=0 gives only the percentage) |
| `Notification::set_progress(body : String, percent : Double, width? : Int = 10) -> Unit` | set the notification body: first line is the original text + a second progress line |

```moonbit
let n = @core.Notification::new()
n.set_title("导出中")
n.set_progress("正在导出 3/8 个文件", 37.5, width=4)
n.show()
```

## Night Light Color Temperature

Color temperature is expressed as a percentage 0-100 (0 = warmest, 100 = 6500K neutral i.e. no change). Two backends are auto-detected: when `redshift` is present it is preferred (`-P -O <K>` sets the temperature once), otherwise `xrandr --output <preferred output> --gamma R:G:B` (the more the blue channel is attenuated, the warmer; the green channel stays 1.00).

| Function | Description |
|---|---|
| `nl_supported() -> Bool` | either redshift or xrandr usable (all probes are read-only calls, no side effects) |
| `nl_set_temperature(percent) -> Result[Unit, NightlightError]` | set color temperature (0-100, out-of-range clamped; redshift path 0→2500K / 100→6500K) |
| `nl_reset() -> Result[Unit, NightlightError]` | reset (redshift `-x` / `xrandr --gamma 1.00:1.00:1.00`, without `--output` it affects all outputs) |

Error `NightlightError`: `Unsupported` (not Linux, or both redshift and xrandr unavailable, or xrandr has no connected output) / `CommandFailed(String)`. The xrandr path takes its output from the current primary output; when there is no primary output it takes the first connected output.

```moonbit
let _ = @sys.nl_set_temperature(30) // warmer
let _ = @sys.nl_reset()
```

## Wallpaper

Windows uses `SystemParametersInfoW (SPI_SETDESKWALLPAPER)` directly. Linux dispatches by desktop environment (DE recognition is a self-contained pure function inside the sys package, namely `XDG_CURRENT_DESKTOP`). **XFCE** uses `xfconf-query` to read/write the `/backdrop/<screen>/monitor<output>/<workspace>/last-image` property on the xfce4-desktop channel (with multiple monitors it takes a connected output); **GNOME** uses `gsettings` to read/write `picture-uri` on `org.gnome.desktop.background` (falls back to `picture-uri-dark` when unset); **KDE** uses `qdbus6`/`qdbus` to call plasmashell's `evaluateScript` (a Plasma scripting convention, not verified on real KDE hardware in this repo).

| Function | Description |
|---|---|
| `wp_get() -> Result[String, WallpaperError]` | read the current wallpaper path |
| `wp_set(path) -> Result[Unit, WallpaperError]` | set the wallpaper (changes the desktop appearance) |

Error `WallpaperError`: `Unsupported` (subprocess unavailable on Linux, or KDE's qdbus absent) / `UnknownDesktop(String)` (not XFCE/GNOME/KDE, carries the raw `XDG_CURRENT_DESKTOP`) / `CommandFailed(String)` / `ParseFailed(String)` / `InvalidParam(String)`. On XFCE writes, a nonexistent property is created.

```moonbit
match @sys.wp_get() {
  Ok(p) => println("当前壁纸：\{p}")
  Err(e) => println("读不到：\{e}")
}
let _ = @sys.wp_set("/home/me/Pictures/wall.png")
```

## Audio/Video Playback (gui-media optional layer)

Media playback is not in the yue core packages (zero cost for those who do not want to pull in an ffmpeg dependency); it lives in the optional module `NoahLiu/gui-media` (depending on the FFI bindings of `NoahLiu/ffmpeg-mbt`):

```moonbit
// moon.mod import: "NoahLiu/gui-media@0.1.0"
// moon.pkg import: "NoahLiu/gui-media/src" @yuemedia
```

Decoding goes through ffmpeg FFI (in-process dynamic linking, formats follow the system ffmpeg: MP3/OGG/M4A/AAC/FLAC/WAV…); the output device is driven directly by the embedded miniaudio device layer (s16 PCM queue, no resampling). In environments with no output device (CI/headless) it automatically degrades to silent, with the state machine proceeding as normal.

### AudioPlayer (browser `<audio>` counterpart)

```moonbit
let player = @yuemedia.AudioPlayer::make("/path/song.mp3")?
player.play()
let view = @yuemedia.audio_player_t(player)  // play/pause/progress/time/volume/loop control bar
```

| API | Description |
|---|---|
| `AudioPlayer::make(path, volume?=0.8, looping?=false)` | open an audio file (all ffmpeg formats) + output device |
| `play() / pause() / stop() / seek(t_s)` | playback control (seek clears the queue and relocates; while playing it resumes from the new position) |
| `pump()` | advance one step (refill the PCM queue / transition state when playback ends) — the component's 50ms clock calls it automatically; call it yourself on a timer when used standalone |
| `is_playing() / current() / duration() / has_audio / is_muted()` | state/position (converted from bytes the device has consumed) /duration / silent-degradation query |
| `set_volume(0..1) / get_volume / set_looping` | volume and looping |
| `free()` | release (afterwards the component clock automatically halts) |

### Video Frame-Source View (yue core, zero dependency)

Video frame rendering goes through "frame-source callback produces RGBA bytes → `pngr_encode_rgba` encodes to PNG in memory → `Image::new_from_png` decodes → `Painter::draw_image` fills the area": taking in-memory RGBA through PNG encode-then-decode is a pure-MoonBit relay channel (stored compression, a valid zlib stream, enough for small resolutions). The decoder is decoupled from this component — any frame source (a future moonav1 / platform decoder) can be plugged in as long as it provides RGBA by frame number.

| Function | Description |
|---|---|
| `video_view_t(width, height, frame_count, source, fps?=30, looping?=false, handle?, fill?, style?, on_ready?)` | video view; a missing frame / failed decode draws the theme background as a placeholder without interrupting playback |
| `vid_pause(handle)` / `vid_resume(handle)` / `vid_stop(handle)` | pause/resume/stop (after stop the timer is deregistered on the next frame, not recoverable; **you must call vid_stop before unmounting the component** — the frame-advance timer has no cancel id, missing a stop keeps it spinning uselessly on the destroyed view until playback ends) |
| `VidHandle::make()` / `is_running()` / `is_paused()` | playback handle |
| `vid_frame_image(source, idx, w, h)` | single frame → Image (length check + encode + decode, None on failure) |
| `pngr_encode_rgba(data, w, h)` | RGBA → PNG (Result; Err on size/length mismatch) |

```moonbit
// Frame source: produce RGBA by frame number (here a 320x240 per-frame color-change illustration)
fn source(i : Int) -> Bytes? {
  let px = FixedArray::make(320 * 240 * 4, (i * 7 % 255).to_byte())
  Some(Bytes::from_array(px))
}
let view = @yuemedia.video_view_t(320, 240, 120, source, fps=30)
```

### VideoPlayer (browser `<video>` counterpart)

The full FFI chain: the video stream yields per-frame RGBA (timestamp-level seek), while the audio track is a second independent decoder for the same file (read cursors don't interfere with each other) that decodes PCM and pushes it straight to the output device — no CLI subprocess. No audio track / no output device automatically goes silent.

```moonbit
let player = @yuemedia.VideoPlayer::make("demo.mp4", fps=12, width=480)?
player.play()
let view = @yuemedia.video_player_t(player)
```

| API | Description |
|---|---|
| `VideoPlayer::make(path, fps?=12, width?=0, height?=0, volume?=0.8, looping?=false)` | open a video (dual decoders including audio; synchronous and time-consuming, best placed in `set_timeout`) |
| `play() / pause() / stop() / seek(t_s)` | playback control (seek relocates and resumes each of the two streams) |
| `is_playing() / current() / duration() / has_audio()` | state/position/duration/audio-track query |
| `current_frame() / frame_width() / frame_height()` | current frame RGBA (self-rendering scenarios) |
| `set_volume / set_looping / free()` | volume/loop/release |

Control-bar component (video_player_t / audio_player_t share the same style): play/pause button, draggable progress bar (seeks 180ms after drag-release debouncing), time text (m:ss / m:ss), volume slider, loop toggle; the 50ms clock pumps + refreshes automatically, and the clock halts automatically after `free()`.

systemprobe auto-loads the demo player on startup; play/pause/drag progress/volume/loop are all interactive.

## Monitor Configuration

Parses the `xrandr --query` output, giving each output's name / connection status / current resolution × refresh rate / position / physical size / supported mode list. Refresh rate is expressed as an integer in centihertz (×100, e.g. 5995 = 59.95Hz) to avoid float parsing and comparison.

| Function | Description |
|---|---|
| `mon_list() -> Result[Array[MonitorInfo], MonitorError]` | enumerate all outputs (including unconnected), preserving xrandr order |
| `mon_current() -> Result[Array[CurrentOutput], MonitorError]` | simplified snapshot of current outputs (connected and with a current mode), without the mode list |

`MonitorInfo{ name, connected, primary, width, height, refresh_centi, pos_x, pos_y, mm_width, mm_height, modes }`; `MonitorMode{ width, height, refresh_centi, preferred, current }`; `CurrentOutput{ name, width, height, refresh_centi, pos_x, pos_y }`. Error `MonitorError`: `Unsupported` (not Linux or xrandr unavailable) / `CommandFailed(String)` / `ParseFailed(String)` (no output entries at all).

```moonbit
match @sys.mon_current() {
  Ok(outs) => for o in outs {
      println("\{o.name}  \{o.width}x\{o.height}@\{o.refresh_centi / 100}Hz")
    }
  Err(e) => println("读不到：\{e}")
}
```

## System Window Management

Window list (id / desktop / host / title), activate by id or title, close by title. Windows uses `EnumWindows` / `SetForegroundWindow` / `WM_CLOSE` directly; Linux parses `wmctrl -l` and uses its activate / close actions. It does not depend on a GUI application environment — an ordinary MoonBit process can use it.

| Function | Description |
|---|---|
| `win_supported() -> Bool` | always true on Windows; on Linux requires wmctrl available (when wmctrl is missing, Unix surfaces it via exit code 127) |
| `win_list() -> Result[Array[WindowInfo], WinError]` | window list |
| `win_activate(id_or_title) -> Result[Unit, WinError]` | activate by window id (wmctrl's `0x...` hex) or title |
| `win_close(title) -> Result[Unit, WinError]` | close a window by title |

`WindowInfo{ id, desktop, host, title }`: id can be passed straight back to `win_activate`; desktop is the desktop the window is on, -1 means all desktops (sticky). Error `WinError`: `Unsupported` / `CommandFailed(String)` / `ParseFailed(String)` / `InvalidParam(String)`.

Activation and closing change real window state (set-class): the interfaces are fully implemented, but the application layer should only call them on user action.

```moonbit
match @sys.win_list() {
  Ok(wins) => for w in wins { println("\{w.id}  \{w.title}") }
  Err(e) => println("不可用：\{e}")
}
let _ = @sys.win_activate("ZCode")   // by title
let _ = @sys.win_close("ZCode")
```

## Clipboard Watching

Text read/write and change watching. Windows uses Win32's `CF_UNICODETEXT` directly; Linux prefers GtkClipboard (requires the host to have run gtk_init; when the probe returns 0 it falls back to the command-line `xclip`), dispatching the new text via a callback when the text content changes. This module is a pure-polling implementation, usable from any MoonBit process with callbacks landing in the caller's context.

| Function | Description |
|---|---|
| `cbw_get_text() -> Result[String, ClipboardError]` | read the clipboard text once (unavailable / no text in the selection yields the corresponding Err) |
| `cbw_start_watch(interval_ms? = 800, cb) -> ClipboardWatcher` | start watching (polling interval clamped to 100..60000; the baseline is the content at the moment of startup, so the initial content does not fire the callback) |
| `cbw_stop(watcher)` | stop watching (sets a park flag, runs at most one more tick then terminates itself; idempotent) |

Error `ClipboardError`: `Unsupported` (platform/backend both unavailable) / `CommandFailed(String)`. A read failure silently skips that tick without firing the callback. The polling is attached to a GUI timer, so it only actually dispatches once the message loop is running.

```moonbit
let w = @sys.cbw_start_watch(interval_ms=500, fn(text) {
  println("剪贴板新内容：\{text}")
})
// ……when needed
@sys.cbw_stop(w)
```

## Power Plans

Reads the available plan set, reads the current plan, and switches plans via three `powerprofilesctl` commands (when `power-profiles-daemon` is not installed the shell surfaces it via exit code 127 → `PpUnsupported`).

| Function | Description |
|---|---|
| `pp_supported() -> Bool` | powerprofilesctl present and queryable |
| `pp_profiles() -> Result[Array[PowerProfile], PowerProfileError]` | available plan list (in backend output order; when the recommended order comes first it is the recommended order) |
| `pp_current() -> Result[PowerProfile, PowerProfileError]` | the current plan |
| `pp_set(profile) -> Result[Unit, PowerProfileError]` | switch plan (has side effects, requires authorization; the caller runs its own authorization flow) |

`PowerProfile`: `PPerformance` (performance) / `PBalanced` (balanced) / `PPowerSaver` (power saver). Error `PowerProfileError`: `PpUnsupported` / `PpCommandFailed(String)` / `PpParseFailed(String)`.

```moonbit
match @sys.pp_profiles() {
  Ok(profiles) if profiles.contains(@sys.PBalanced) => {
    let _ = @sys.pp_set(@sys.PBalanced)
  }
  _ => ()
}
```

## System Information

Reads `/proc` and `/sys` text only: distro identity (`/etc/os-release`), machine DMI identity (`/sys/class/dmi/id/`), physical memory (`/proc/meminfo`), uptime (`/proc/uptime`). Non-Linux uniformly yields `Unsupported`; when unreadable (file missing / insufficient permission) it yields `Err` carrying the path rather than papering over with an empty string.

| Function | Description |
|---|---|
| `si_os() -> Result[OsInfo, SysInfoError]` | distro: `OsInfo{ pretty_name, id, version_id }` |
| `si_machine() -> Result[MachineInfo, SysInfoError]` | machine: `MachineInfo{ vendor, product, serial }` (the serial is readable only by root on most distros; unreadable yields `Err`) |
| `si_memory() -> Result[MemoryInfo, SysInfoError]` | memory: `MemoryInfo{ total_kb, available_kb }` (unit kB; MemAvailable is the real measure of "how much can still be used") |
| `si_uptime() -> Result[Double, SysInfoError]` | uptime (seconds) |

Error `SysInfoError`: `SiUnsupported` (not Linux) / `SiReadFailed(String)` (carries the path) / `SiParseFailed(String)`.

```moonbit
let os = @sys.si_os() // Ok({ pretty_name: "Ubuntu 24.04.5 LTS", id: "ubuntu", .. })
let mem = @sys.si_memory()
let up = @sys.si_uptime() // Ok(84088.08)
```

## Printers

Windows uses winspool directly (`EnumPrintersW` for the list + `GetDefaultPrinterW` for the default name) and `ShellExecuteW` with the "print" verb for printing; Linux reads the printer list (`-p`) and default printer (`-d`) via `lpstat` and submits print jobs via `lp`. When CUPS is not installed (lpstat surfaces it via exit code 127) → `PrtUnsupported`, a legitimate degradation.

| Function | Description |
|---|---|
| `prt_supported() -> Bool` | Windows checks that the winspool list is retrievable; Linux checks lpstat availability |
| `prt_list() -> Result[Array[PrinterInfo], PrinterError]` | printer list (name + availability status) |
| `prt_default() -> Result[String, PrinterError]` | default printer name |
| `prt_print(printer? = "", path, copies? = 1) -> Result[Unit, PrinterError]` | submit a print job (Linux uses the system default printer as the printer default; Windows uses the "print" verb and does not support a copies parameter; has side effects, actually queues for printing) |

`PrinterStatus`: `Idle` / `Printing` / `Paused` (paused, accepts no new jobs) / `Disabled`; `prt_status_available(status)` decides whether it can accept jobs. `PrinterInfo{ name, status }`. Error `PrinterError`: `PrtUnsupported` / `PrtCommandFailed(String)` / `PrtParseFailed(String)` / `PrtInvalidParam(String)` (empty file path, copies < 1).

```moonbit
match @sys.prt_default() {
  Ok(name) => {
    let _ = @sys.prt_print(printer=name, path="/tmp/doc.pdf")
  }
  Err(e) => println("无默认打印机：\{e}")
}
```

## Environment Variables & Directory Enumeration

Two small primitives: in-process environment-variable read/write and delete (`envx`, reads go through `core/env`, write/delete go through the C-layer setenv/unsetenv), and directory enumeration (`fsx`, C-layer opendir/readdir or Win32 FindFirstFileW).

| Function | Purpose |
|---|---|
| `envx_get(name) -> String?` | read (current process environment, None when unavailable) |
| `envx_set(name, value) -> Result[Unit, EnvxError]` | write (current process environment only, visible to subprocesses spawned afterwards) |
| `envx_unset(name) -> Result[Unit, EnvxError]` | delete (treating an absent variable as success too, idempotent) |
| `envx_common() -> Map[String, String]` | common set: PATH / HOME / LANG / SHELL / USER read as fixed + an `XDG_*` prefix scan (included only when present in the environment) |
| `fsx_list_dir(path) -> Result[Array[String], FsError]` | enumerate a directory's child names (excludes `.` `..`, non-recursive, includes hidden entries) |
| `fsx_set_env(name, value, overwrite) -> Result[Unit, FsError]` | write an environment variable (when overwrite=false and it already exists, keeps the original value, still Ok) |
| `fsx_unset_env(name) -> Result[Unit, FsError]` | delete an environment variable (the low level of envx_unset) |

The semantics are "in-process effect" — writes only change the current process environment, never touching the system's persistent configuration nor affecting the parent process. Errors: `EnvxError::ExInvalidParam(String)` (empty variable name) / `ExFailed(String)` (C layer rejects, e.g. name contains '='); `FsError::InvalidParam(String)` / `OpenFailed(String)` (directory cannot be opened, carries the path) / `EnvFailed(String)`. A known edge of `fsx_list_dir`: extreme filenames whose child name itself contains '\n' get split apart (flat text encoding).

```moonbit
let path = @sys.envx_get("PATH")
let _ = @sys.envx_set("MY_FLAG", "1")
let _ = @sys.envx_unset("MY_FLAG")
match @sys.fsx_list_dir("/usr/share/applications") {
  Ok(names) => for n in names if n.ends_with(".desktop") { println(n) }
  Err(e) => println("打不开：\{e}")
}
```

## Recent Files (GTK recently-used.xbel)

Parses freedesktop's `recently-used.xbel` (GTK apps write this list uniformly via GtkRecentManager / xdg-desktop-portal-gtk; Thunar / Nautilus / GIO opening a file all append to it). File location: `$XDG_DATA_HOME/recently-used.xbel` (default `$HOME/.local/share/`). The XML parser is a hand-written thin scanner: it takes only bookmark nodes and the attributes of `bookmark:application` / `mime:mime-type` child nodes, XML-entity decodes attribute values, and percent-decodes the `file://` URI of href; timestamps ISO 8601 → Unix milliseconds.

| Function | Description |
|---|---|
| `rf_supported() -> Bool` | Linux and the file is readable |
| `rf_recent(limit? = 100) -> Result[Array[RecentItem], RecentError]` | recent file list (modified descending, ties by path ascending); limit ≤ 0 takes all |
| `rf_by_app(name, limit? = 100) -> Result[Array[RecentItem], RecentError]` | filter by application name (exact match on the name of `bookmark:application`), also descending |

`RecentItem{ uri, path, mime, added, modified, app_count }`: path is the local path after stripping the `file://` prefix from href and percent-decoding (non-file:// schemes give an empty string), mime is the MIME type (None when that bookmark has no such node), added / modified are Unix milliseconds (0 when missing or invalid), app_count is the number of applications that recorded this file. Error `RecentError`: `RfUnsupported` / `RfNoDataDir` / `RfNoFile` (never recorded) / `RfParseFailed(String)`. Pure functions for decoding and conversion: `rf_xml_unescape` / `rf_percent_decode` / `rf_uri_to_path` / `rf_iso_to_unix_ms` / `rf_sort_recent`.

```moonbit
match @sys.rf_recent(limit=8) {
  Ok(items) => for it in items { println("\{it.path}  (\{it.modified})") }
  Err(e) => println("读不到：\{e}")
}
```

## Browser Bookmarks (Chrome family)

Read-only parsing of the `Bookmarks` JSON files of Chrome / Chromium / Edge / Brave (does not copy or modify the original file). The JSON parser reuses the same package's hand-written parser (integer fields keep Int64 precision — Chrome's date_added etc. are stored as numeric strings, microsecond values converted to Unix milliseconds); auto-detects all profiles (Default and Profile 1..24).

| Function | Description |
|---|---|
| `bm_supported() -> Bool` | Linux (this file implements only the Linux path detection) |
| `bm_browsers() -> Result[Array[BookmarkProfile], BookmarkError]` | list profiles with a readable Bookmarks file |
| `bm_bookmarks(browser) -> Result[BookmarkNode, BookmarkError]` | the first readable bookmark tree of a given browser (browser identifier takes "google-chrome"/"chromium"/"microsoft-edge"/"brave", profile takes Default first, then Profile 1..24) |

`BookmarkProfile{ browser, profile, bookmarks_path }`; `BookmarkNode{ name, url?, children, added, root }` (added is Unix milliseconds, root labels the owning root bookmark_bar / other / synced) — returns a virtual-root tree (name `"<browser>/<profile>"`, children merge the three roots), classified by `BookmarkNode::is_folder()` / `is_url()`, and `bm_flatten(node)` gives a preorder flattened url-bookmark list. Error `BookmarkError`: `BmUnsupported` / `BmNoConfigDir` / `BmNoBrowser` / `BmIoFailed(String)`.

```moonbit
match @sys.bm_bookmarks("google-chrome") {
  Ok(root) =>
    for n in @sys.bm_flatten(root) {
      println("\{n.name}  →  \{n.url}")
    }
  Err(e) => println("读不到：\{e}")
}
```

## Firefox Browsing History

Reads the `places.sqlite` of each profile under `~/.mozilla/firefox/` (the `moz_places` table, read in pure MoonBit, does not copy or modify the original database). Entries reuse `browser_history.mbt`'s `HistoryItem` (field structure identical to Chrome history), with times converted from Firefox's Unix-epoch microseconds → milliseconds; sorting / truncation / column selection likewise reuse the pure functions exported by that file.

| Function | Description |
|---|---|
| `ffx_supported() -> Bool` | profiles.ini location is implemented for Linux / macOS / Windows |
| `ffx_profiles() -> Result[Array[FirefoxProfile], FirefoxHistoryError]` | list profiles with a readable places.sqlite |
| `ffx_history(limit? = 200) -> Result[Array[HistoryItem], FirefoxHistoryError]` | browsing history (aggregates all detected profiles, sorted by last-visit time descending); limit ≤ 0 takes all |

`FirefoxProfile{ profile, places_path }` (profile is the `Path=` directory name from profiles.ini, absolute paths take the last segment). Hidden entries (bookmarks etc.) are filtered out; a single profile read failure is skipped, only yielding `FfxIoFailed` when all fail. Error `FirefoxHistoryError`: `FfxUnsupported` / `FfxNoProfile` (Firefox not installed or never started) / `FfxIoFailed(String)`. When profiles.ini is missing it falls back to fixed candidate names (default / default-release / default-esr / default-nightly / dev-edition-default); profile directories named with a random prefix are not picked up.

```moonbit
match @sys.ffx_history(limit=10) {
  Ok(items) => for it in items { println("\{it.title}  \{it.url}") }
  Err(e) => println("读不到：\{e}")
}
```

## Shared Infrastructure: Subprocess Execution (procrun)

The shared "spawn → bounded-time reap → capture stdout/stderr to temp files" wrapper used by all command-line capabilities (volume, monitors, wallpaper, night light, printers, power plans, Firefox profile location): the command name is resolved via PATH; the subprocess environment is forced to the C locale so output language stays consistently parseable; exit code 0 is normalized to `Ok`, a nonzero exit is normalized to `Err` carrying stderr, so callers need not re-check codes themselves.

| Function | Description |
|---|---|
| `pr_available() -> Bool` | whether the current platform supports subprocess execution (true on the three main platforms Linux / macOS / Windows, based on the sys package's own C stubs) |
| `pr_run(cmd, args, timeout_ms? = 5000) -> Result[ProcOutput, ProcError]` | run a command and normalize the result (a timed-out process is force-terminated) |

`ProcOutput{ stdout, exit_code }`; error `ProcError`: `Unsupported` (not one of the Linux / macOS / Windows main platforms) / `SpawnFailed(String)` (a missing command is, per Unix convention, surfaced by the subprocess with exit code 127, folded into a nonzero exit) / `Timeout(String)` / `NonZeroExit(Int, String)` / `Signaled(Int)`.

"Command missing" and "present but failed" are two distinct semantics: the former is usually normalized in the module itself to `*Supported == false` or `Unsupported` (e.g. `PpUnsupported`, `PrtUnsupported`), the latter is `CommandFailed` — callers can classify by error value.

```moonbit
match @sys.pr_run("wpctl", ["get-volume", "@DEFAULT_SINK@"]) {
  Ok(out) => println(out.stdout)
  Err(@sys.ProcError::NonZeroExit(_, err)) => println("失败：\{err}")
  Err(e) => println(e)
}
```

## Shared Infrastructure: Generic D-Bus Call Layer (@dbus)

Method calls and property read/write against any service; the common foundation for modules such as media control (MPRIS). Connections reuse the process-level session/system connections of `bus.mbt`, encoding/decoding reuses the wire protocol of `wire.mbt`; synchronous calls time out at 1.5 seconds, and a response timeout yields a `gdbus.timeout` error.

| Function | Description |
|---|---|
| `gdbus_call_session(dest, path, iface, action, args) -> Result[GDBusValue, GDBusError]` | session-bus method call |
| `gdbus_call_system(dest, path, iface, action, args) -> Result[GDBusValue, GDBusError]` | system-bus method call |
| `gdbus_get_property_session(dest, path, iface, prop)` / `gdbus_get_property_system(...)` | read a property (via `org.freedesktop.DBus.Properties.Get`; the return value already has the variant wrapper stripped) |
| `gdbus_set_property_session(dest, path, iface, prop, value)` / `gdbus_set_property_system(...)` | write a property (via `Properties.Set`; pass a bare value as value, the variant wrapper is done at this layer) |

Value model `GDBusValue`: `GVNone` (no return value, cannot be a call argument) / `GVBool` / `GVInt32` / `GVUInt32` / `GVInt64` / `GVU64` ('t', unsigned 64-bit Size/Time etc. in udisks) / `GVDouble` / `GVString` / `GVPath` ('o') / `GVArray(element signature, element table) / `GVDict(a{sv}, values already have the variant wrapper stripped, Map serialized in insertion order) / `GVVariant` (keeps the wrapper) / `GVStruct`. On the response side, `{sv}` arrays fold into `GVDict`, and multiple return values fold into `GVStruct`. Error `GDBusError{ name, message }`: name is a D-Bus error name or a local prefix `gdbus.io` (cannot connect / disconnected) / `gdbus.timeout` / `gdbus.encode`.

```moonbit
match
  @dbus.gdbus_get_property_system(
    "org.freedesktop.timedate1",
    "/org/freedesktop/timedate1",
    "org.freedesktop.timedate1",
    "NTP",
  ) {
  Ok(@dbus.GVBool(on)) => println("NTP 开启：\{on}")
  Ok(_) => ()
  Err(e) => println("总线失败：\{e.name} \{e.message}")
}
```

## Boundaries

- The browser History database may keep getting new writes while the browser is running; the read result is a snapshot at the moment of reading (does not include the latest records not yet merged into the main database).
- Firefox's places.sqlite is often in WAL mode; this implementation reads only the main database file, so the latest browsing records not yet checkpointed into the main database are not readable; when aggregating multiple profiles the same url appears once per profile (consistent with the Chrome-side aggregation policy).
- `appfind_executable`'s hit test is that a directory has an entry of that name; it does not read file contents or verify the executable permission bit.
- Volume setting relies on the corresponding system service being online (Windows IAudioEndpointVolume / Linux PipeWire-Pulse); when the service is absent the write interfaces return an error value, handled item by item by error value.
- Printing / switching power plans are operations that change the system's real state: the interfaces are fully implemented, but should be called only on explicit user action, never triggered on behalf of the user in probe or query paths.
- Both the clipboard watcher's and the ripple animation's timers are driven by the message loop and have no cancel id (`set_timer`): the way to stop them is to have the callback return false, so handle-class APIs (`cbw_stop` / `eff_stop`) should be called explicitly before a component is unmounted.
