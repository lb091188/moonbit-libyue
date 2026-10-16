# System Capabilities (Volume / App Lookup / App History / Media & Desktop Control)

The system-capability API family: system volume, application lookup, night-light color temperature, wallpaper, monitor configuration, system window management, clipboard watching, subprocess execution, power plans, system information, printers, environment variables, directory enumeration, recent files, browser bookmarks and Firefox history, VS Code local history. All are read-only or write through an authorized system service. Every call returns a `Result`; unsupported environments yield the corresponding error value instead of crashing. Each `*_supported()` call really probes the current environment.

## Platform Status (2026-10-14, after platform batches ①-⑥)

| Capability | Windows | Linux | macOS |
|---|---|---|---|
| clipboard / autostart / subprocess / files (fsx) / env vars (envx) | ✅ direct call | ✅ | ❌ Unsupported |
| system info / window management / wallpaper / power plans / launcher | ✅ direct call | ✅ | ❌ |
| app lookup / recent files / volume / printers (list+default+print) | ✅ direct call | ✅ | ❌ |
| browser/vscode data | ✅ (LOCALAPPDATA paths) | ✅ | ❌ |
| sysmonitor process data | ✅ (ships its own stub/sysmon.c) | ✅ | ❌ |
| night-light color temperature (redshift/xrandr command line) | ❌ no public API | ✅ | ❌ |

The Windows direct calls under the hood: SystemParametersInfoW (wallpaper), ShellExecuteW (launch/reveal/print), PowerGet/SetActiveScheme, the registry (product and DMI info), GlobalMemoryStatusEx, GetTickCount64, EnumWindows, EnumPrintersW, IAudioEndpointVolume (COM), GetLastInputInfo. For pitfalls and header/link requirements, see the platform-batch entries in [adaptation.md](adaptation.md).

The full demo is the "System Probes" page of `moon run examples/showcase` — each section can "re-probe" to show this machine's real results item by item, and unsupported capabilities show their error text. For field-tested conclusions and rationale per capability across distros / desktop environments — including the logind path, wpctl/pactl differences and direct SQLite reads — see [adaptation.md](adaptation.md).

## System Volume

Acts on the default output device (default sink). The backend is auto-detected: wpctl (PipeWire/WirePlumber) is preferred; when unavailable it falls back to pactl (pipewire-pulse / PulseAudio); when neither works the result is `Unsupported`. The probe runs for real on every call — cache the results yourself in high-frequency scenarios.

| Function | Description |
|---|---|
| `vol_supported() -> Bool` | whether the current system supports volume control |
| `vol_get() -> Result[VolumeInfo, VolumeError]` | read a snapshot: `VolumeInfo{ sink, volume, muted }`; the sink is an empty string when unavailable, which does not affect volume or mute |
| `vol_set(percent) -> Result[Unit, VolumeError]` | set absolute volume (0-100, out-of-range clamped) |
| `vol_add(delta) -> Result[Unit, VolumeError]` | relative adjust; the tool side clamps the final volume |
| `vol_set_mute(mute) -> Result[Unit, VolumeError]` | set / clear mute |

Error `VolumeError`: `Unsupported` (no usable volume tool) / `CommandFailed(String)` (includes timeout) / `ParseFailed(String)` (output parse failed, carries the raw text).

```moonbit
match @sys.vol_get() {
  Ok(v) =>
    println(
      "sink=\{v.sink} volume=\{v.volume}% muted=\{if v.muted { "Yes" } else { "No" }}",
    )
  Err(e) => println("Unavailable: \{e}")
}
let _ = @sys.vol_set(42)
let _ = @sys.vol_add(-5)
let _ = @sys.vol_set_mute(false)
```

## Application Lookup

Two parts: the installed-app inventory and the app binary lookup. Linux scans XDG `.desktop` entries; the user directory overrides the system directory. Windows recursively scans the Start Menu (user-level + machine-wide) for `.lnk` files — an entry's exec is the full lnk path, directly launchable via ShellExecute, and categories is marked `StartMenu`. macOS is `Unsupported`.

| Function | Description |
|---|---|
| `appfind_installed() -> Result[Array[AppEntry], AppFindError]` | installed-app inventory; yields `NoScanDir` when every scan directory is missing |
| `appfind_installed_with(list_dir) -> Result[Array[AppEntry], AppFindError]` | same as above, with directory enumeration injected by the caller — for callers without an fsx layer and for tests; Linux branch only |
| `appfind_executable(name) -> Result[String, AppFindError]` | Linux searches `~/.local/bin`, `/usr/local/bin`, `/usr/bin`, `/bin`, `/usr/sbin`, `/sbin` in order; Windows searches each `PATH` directory for name / name.exe; yields `NotFound` when nothing matches |

`AppEntry{ id, name, locale_name, exec, icon, categories }`: id is the desktop id (the .desktop filename without extension), name is the display name, locale_name is the localized name (`Name[zh_CN]` preferred, falling back to Name), exec / icon kept verbatim, categories split on semicolons. Results are deduplicated by desktop id (user directory overrides system directory) and sorted by name; entries whose Type is not Application, with NoDisplay=true, or missing Name are filtered out.

```moonbit
// Installed inventory: inject a directory-listing function (e.g. your own readdir wrapper)
match @sys.appfind_installed_with(fn(dir) { my_list_dir(dir) }) {
  Ok(apps) => for a in apps {
      println("\{a.locale_name}  \{a.exec}")
    }
  Err(e) => println("Unavailable: \{e}")
}
// Binary lookup
match @sys.appfind_executable("code") {
  Ok(path) => println("code located at \{path}")
  Err(@sys.AppFindError::NotFound(_)) => println("Not installed")
  Err(_) => println("Platform not supported")
}
```

## VS Code Local History & Recent Workspaces

Reads local VS Code user data: the local history snapshot list for a file (`User/History`) and recent workspaces. Paths for all three platforms are implemented, each located by its user-data directory.

| Function | Description |
|---|---|
| `vsc_supported() -> Bool` | whether the machine has readable VS Code user data |
| `vsc_local_history(file_path) -> Result[Array[VscHistoryEntry], VscodeError]` | history snapshots of a file (time-descending); an absolute path or a `file://` URI both work; an empty array when there is no history |
| `vsc_recent() -> Result[Array[String], VscodeError]` | recently opened workspace / folder paths (most recently active first); an empty array when there is no window state |

`VscHistoryEntry{ path, timestamp }`: path is the absolute path of the snapshot file — the file's full text at that moment; timestamp is Unix milliseconds, converted to seconds by `timestamp_seconds()`. Error `VscodeError`: `Unsupported` (cannot locate the user-data directory) / `StorageUnavailable` (VS Code has never run on this machine) / `StorageCorrupted(String)` / `HistoryCorrupted(String)`.

```moonbit
match @sys.vsc_local_history("/home/me/proj/src/main.mbt") {
  Ok(snaps) => for s in snaps {
      println("\{s.timestamp_seconds()}  \{s.path}")
    }
  Err(e) => println("Unavailable: \{e}")
}
match @sys.vsc_recent() {
  Ok(paths) => if paths.length() > 0 {
      println("Recent workspace: \{paths[0]}")
    }
  Err(e) => println("Unavailable: \{e}")
}
```

## Browser History & Download Records

Read-only access to the History databases of Chrome / Chromium / Edge / Brave; all profiles are auto-detected (Default and Profile 1..24). Only the Linux path detection is implemented; other platforms yield `BhUnsupported`.

| Function | Description |
|---|---|
| `bh_supported() -> Bool` | whether the current platform is supported |
| `bh_browsers() -> Result[Array[BrowserProfile], BrowserHistoryError]` | list profiles with a readable History database; yields `BhNoBrowser` when none is readable |
| `bh_history(limit? = 200) -> Result[Array[HistoryItem], BrowserHistoryError]` | browsing history — aggregates all profiles, sorted by last-visit time descending, hidden redirect entries filtered out; limit ≤ 0 takes everything |
| `bh_downloads(limit? = 50) -> Result[Array[DownloadItem], BrowserHistoryError]` | download records (sorted by start time descending) |
| `bh_search(keyword, limit? = 50) -> Result[Array[HistoryItem], BrowserHistoryError]` | substring search on url or title, ASCII case-insensitive; an empty keyword matches everything |
| `bh_download_state_name(state) -> String` | download state number → name (in progress / complete / cancelled / interrupted) |

`BrowserProfile{ browser, profile, history_path }`: browser is google-chrome / chromium / microsoft-edge / brave, profile is the directory name (Default or Profile N). `HistoryItem{ url, title, visit_count, last_visit_time }` (times are Unix milliseconds, 0 when unknown); `DownloadItem{ target_path, received_bytes, total_bytes, start_time, end_time, state }`. Error `BrowserHistoryError`: `BhUnsupported` / `BhNoConfigDir` / `BhNoBrowser` / `BhIoFailed(String)` — a single profile read failure is skipped; only an all-fail case errors.

```moonbit
match @sys.bh_history(limit=6) {
  Ok(items) => for it in items {
      let title = if it.title == "" { "(No title)" } else { it.title }
      println("[\{it.visit_count} visits] \{title}\n  \{it.url}")
    }
  Err(e) => println("Unavailable: \{e}")
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

Enumerates `org.mpris.MediaPlayer2.*` player instances on the session bus. Playback control (play / pause / play_pause / next / previous / stop) and status reads (PlaybackStatus + title / artist / album from Metadata) go through the MPRIS Player interface; a bus failure can fall back to the `playerctl` subcommand. Only the Linux path is implemented so far; other platforms uniformly yield `Unsupported`.

| Function | Description |
|---|---|
| `media_supported() -> Bool` | the session bus works (ListNames succeeds) or playerctl works |
| `media_players() -> Result[Array[MediaPlayerInfo], MediaError]` | enumerate player instances, including the playerctld proxy instance; preserves the ListNames response order; yields `NoPlayer` when there is none |
| `media_status(player) -> Result[MediaStatus, MediaError]` | read one player's status and current track |
| `media_play(player)` / `media_pause(player)` / `media_play_pause(player)` / `media_next(player)` / `media_previous(player)` / `media_stop(player)` | playback control (returns `Result[Unit, MediaError]`) |

`MediaPlayerInfo{ name, identity }`: name is the bus name — the argument to `media_status` and the playback-control calls; identity is the player's display name. `MediaStatus{ player, playback, title, artist, album }`; `MediaPlayback` is `MediaPlaying` / `MediaPaused` / `MediaStopped` / `MediaUnknown(String)`. Error `MediaError`: `Unsupported` / `NoPlayer` / `BusFailed(String)` (carries the error name and description) / `CommandFailed(String)` (playerctl fallback failed) / `ParseFailed(String)`.

Playback control is a set-class operation: it runs only when the caller invokes it explicitly; probe and query paths never trigger it.

```moonbit
match @dbus.media_players() {
  Ok(players) if players.length() > 0 => {
    let p = players[0].name
    match @dbus.media_status(p) {
      Ok(s) => println("\{s.title} - \{s.artist} (\{s.playback})")
      Err(e) => println("Failed to read status: \{e}")
    }
    let _ = @dbus.media_play_pause(p)
  }
  Err(@dbus.MediaError::NoPlayer) => println("No player")
  Err(e) => println("Unavailable: \{e}")
}
```

### Media Status Watching

MPRIS has no unified signal-callback path — `PropertiesChanged` needs a resident read loop, incompatible with the library's synchronous-call model. Status watching therefore polls for deltas: it reads status at an interval and fires `on_change` when playing state / title / artist / album changes. The first round only establishes the baseline and does not fire. Before the target player appears, resolution is retried each round and locks once it appears (an empty player takes the first instance). Rounds whose query fails are silently skipped.

| Function | Description |
|---|---|
| `MediaWatcher::make() -> MediaWatcher` | create a watch handle (running by default) |
| `media_watch_status(player?, interval_ms? = 1000, on_change) -> MediaWatcher` | start polling; an empty player watches the first MPRIS instance; on_change receives a `MediaStatus` |
| `media_watch_stop(w)` | stop watching; the timer deregisters on the next frame. Not recoverable — use a new handle to watch again |
| `MediaWatcher::is_running() -> Bool` | whether the handle is watching |

An exception thrown in the `on_change` callback interrupts that timer; call `media_watch_stop` explicitly before the component is destroyed.

```moonbit
let w = @sys.media_watch_status(interval_ms=1000, fn(s : @sys.MediaStatus) {
  println("Now playing: \{s.title} - \{s.artist}")
})
// when no longer needed
@sys.media_watch_stop(w)
```

### Notification Progress

The freedesktop notification protocol has no progress field, and native progress rendering on Windows / macOS each differs. The cross-platform-consistent approach renders a character progress bar + percentage inside the body.

| Function | Description |
|---|---|
| `notification_progress_text(percent : Double, width? : Int = 10) -> String` | progress text: character bar + percentage; percent is clamped to [0,100], NaN treated as 0, width<=0 gives only the percentage |
| `Notification::set_progress(body : String, percent : Double, width? : Int = 10) -> Unit` | set the notification body: the first line keeps the original text, the second line shows progress |

```moonbit
let n = @core.Notification::new()
n.set_title("Exporting")
n.set_progress("Exporting 3/8 files", 37.5, width=4)
n.show()
```

## Night Light Color Temperature

Color temperature is expressed as a percentage 0-100: 0 = warmest, 100 = 6500K neutral, i.e. no change. Two backends are auto-detected: `redshift` is preferred when present (`-P -O <K>` sets the temperature once), otherwise `xrandr --output <preferred output> --gamma R:G:B` — the more the blue channel is attenuated, the warmer; the green channel stays 1.00.

| Function | Description |
|---|---|
| `nl_supported() -> Bool` | either redshift or xrandr works; all probes are read-only calls with no side effects |
| `nl_set_temperature(percent) -> Result[Unit, NightlightError]` | set color temperature (0-100, out-of-range clamped; the redshift path maps 0→2500K / 100→6500K) |
| `nl_reset() -> Result[Unit, NightlightError]` | reset (redshift `-x` / `xrandr --gamma 1.00:1.00:1.00`; without `--output` it affects all outputs) |

Error `NightlightError`: `Unsupported` (not Linux, or both redshift and xrandr unavailable, or xrandr has no connected output) / `CommandFailed(String)`. The xrandr path takes the current primary output; without a primary output it takes the first connected one.

```moonbit
let _ = @sys.nl_set_temperature(30) // warmer
let _ = @sys.nl_reset()
```

## Wallpaper

Windows calls `SystemParametersInfoW` (SPI_SETDESKWALLPAPER) directly. Linux dispatches by `XDG_CURRENT_DESKTOP`, with DE recognition handled by a pure function inside the sys package. **XFCE** uses `xfconf-query` to read/write the `/backdrop/<screen>/monitor<output>/<workspace>/last-image` property on the xfce4-desktop channel; with multiple monitors it takes a connected output. **GNOME** uses `gsettings` to read/write `picture-uri` on `org.gnome.desktop.background`, falling back to `picture-uri-dark` when unset. **KDE** uses `qdbus6`/`qdbus` to call plasmashell's `evaluateScript`; this repo has not verified KDE on real hardware.

| Function | Description |
|---|---|
| `wp_get() -> Result[String, WallpaperError]` | read the current wallpaper path |
| `wp_set(path) -> Result[Unit, WallpaperError]` | set the wallpaper; changes the desktop appearance |

Error `WallpaperError`: `Unsupported` (subprocess unavailable on Linux, or KDE's qdbus absent) / `UnknownDesktop(String)` (not XFCE/GNOME/KDE; carries the raw `XDG_CURRENT_DESKTOP`) / `CommandFailed(String)` / `ParseFailed(String)` / `InvalidParam(String)`. An XFCE write creates the property when it does not exist.

```moonbit
match @sys.wp_get() {
  Ok(p) => println("Current wallpaper: \{p}")
  Err(e) => println("Cannot read: \{e}")
}
let _ = @sys.wp_set("/home/me/Pictures/wall.png")
```

## Audio/Video Playback (gui-media Optional Layer)

Media playback is not in the yue core packages; it lives in the optional module `NoahLiu/gui-media` (depending on `NoahLiu/ffmpeg-mbt`):

```moonbit
// moon.mod import: "NoahLiu/gui-media@0.1.0"
// moon.pkg import: "NoahLiu/gui-media/src" @yuemedia
```

Decoding goes through the ffmpeg FFI, linked dynamically in-process; formats follow the system ffmpeg: MP3/OGG/M4A/AAC/FLAC/WAV…. Output goes straight through the embedded miniaudio device layer (s16 PCM queue, zero resampling). With no output device (CI/headless) it automatically degrades to silent while the state machine proceeds as normal.

### AudioPlayer (browser `<audio>` counterpart)

```moonbit
let player = @yuemedia.AudioPlayer::make("/path/song.mp3")?
player.play()
let view = @yuemedia.audio_player_t(player)  // play/pause/progress/time/volume/loop control bar
```

| API | Description |
|---|---|
| `AudioPlayer::make(path, volume?=0.8, looping?=false)` | open an audio file (all ffmpeg formats) + the output device |
| `play() / pause() / stop() / seek(t_s)` | playback control; seek clears the queue and relocates, then resumes from the new position while playing |
| `pump()` | advance one step — refill the PCM queue / transition state when playback ends; the component's 50ms clock calls it automatically, and when used standalone call it on your own timer |
| `is_playing() / current() / duration() / is_muted()` | state / position (converted from bytes the device has consumed) / duration / silent-degradation query; `is_muted()` is the counterpart of `has_audio` |
| `set_volume(0..1) / get_volume / set_looping` | volume and looping |
| `free()` | release; afterwards the component clock halts automatically |

### Video Frame-Source View (yue core, zero dependency)

Video frame rendering follows: a frame-source callback produces RGBA bytes → `pngr_encode_rgba` encodes them to PNG in memory → `Image::new_from_png` decodes → `Painter::draw_image` fills the area. This is a pure-MoonBit relay channel with stored compression — a valid zlib stream, enough for small resolutions. The decoder is decoupled from this component: any frame source (a future moonav1 / platform decoder) can plug in as long as it provides RGBA by frame number.

| Function | Description |
|---|---|
| `video_view_t(width, height, frame_count, source, fps?=30, looping?=false, handle?, fill?, style?, on_ready?)` | video view; a missing frame or failed decode draws the theme background as a placeholder without interrupting playback |
| `vid_pause(handle)` / `vid_resume(handle)` / `vid_stop(handle)` | pause/resume/stop; after stop the timer deregisters on the next frame and is not recoverable. **Call vid_stop before unmounting the component** — the timer has no cancel id, and a missed stop keeps spinning on the destroyed view until playback ends |
| `VidHandle::make()` / `is_running()` / `is_paused()` | playback handle |
| `vid_frame_image(source, idx, w, h)` | single frame → Image; length check + encode + decode, None on failure |
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

The full FFI chain: the video stream yields per-frame RGBA with timestamp-level seek; the audio track is a second independent decoder on the same file whose PCM is pushed straight to the output device — no CLI subprocess. No audio track or no output device automatically goes silent.

```moonbit
let player = @yuemedia.VideoPlayer::make("demo.mp4", fps=12, width=480)?
player.play()
let view = @yuemedia.video_player_t(player)
```

| API | Description |
|---|---|
| `VideoPlayer::make(path, fps?=12, width?=0, height?=0, volume?=0.8, looping?=false)` | open a video (dual decoders including the audio track); synchronous and time-consuming, best placed in `set_timeout` |
| `play() / pause() / stop() / seek(t_s)` | playback control; seek relocates each of the two streams and resumes |
| `is_playing() / current() / duration() / has_audio()` | state / position / duration / audio-track query |
| `current_frame() / frame_width() / frame_height()` | current frame RGBA, for self-rendering scenarios |
| `set_volume / set_looping / free()` | volume / loop / release |

The control-bar components share one style (video_player_t / audio_player_t): play/pause button, draggable progress bar (seeks 180ms after drag-release debouncing), time text (m:ss / m:ss), volume slider, loop toggle. The 50ms clock pumps and refreshes automatically; after `free()` the clock halts on its own.

Player demos: `moon run modules/gui-examples/audio` / `moon run modules/gui-examples/video` — the default asset auto-loads on startup, and play/pause/seek/volume/speed are all interactive.

## Monitor Configuration

Parses `xrandr --query` output, giving each output's name / connection status / current resolution × refresh rate / position / physical size / supported mode list. The refresh rate is an integer in centihertz (×100, e.g. 5995 = 59.95Hz), avoiding float comparison.

| Function | Description |
|---|---|
| `mon_list() -> Result[Array[MonitorInfo], MonitorError]` | enumerate all outputs, including unconnected ones, preserving xrandr order |
| `mon_current() -> Result[Array[CurrentOutput], MonitorError]` | simplified snapshot of current outputs (connected and with a current mode), without the mode list |

`MonitorInfo{ name, connected, primary, width, height, refresh_centi, pos_x, pos_y, mm_width, mm_height, modes }`; `MonitorMode{ width, height, refresh_centi, preferred, current }`; `CurrentOutput{ name, width, height, refresh_centi, pos_x, pos_y }`. Error `MonitorError`: `Unsupported` (not Linux or xrandr unavailable) / `CommandFailed(String)` / `ParseFailed(String)` (no output entries at all).

```moonbit
match @sys.mon_current() {
  Ok(outs) => for o in outs {
      println("\{o.name}  \{o.width}x\{o.height}@\{o.refresh_centi / 100}Hz")
    }
  Err(e) => println("Cannot read: \{e}")
}
```

## System Window Management

Window list (id / desktop / host / title), activate by id or title, close by title. Windows calls `EnumWindows` / `SetForegroundWindow` / `WM_CLOSE` directly; Linux parses `wmctrl -l` and uses its activate / close actions. An ordinary MoonBit process can call these — no GUI host needed.

| Function | Description |
|---|---|
| `win_supported() -> Bool` | always true on Windows; on Linux requires wmctrl — a missing wmctrl surfaces on Unix via exit code 127 |
| `win_list() -> Result[Array[WindowInfo], WinError]` | window list |
| `win_activate(id_or_title) -> Result[Unit, WinError]` | activate by window id (wmctrl's `0x...` hex) or title |
| `win_close(title) -> Result[Unit, WinError]` | close a window by title |

`WindowInfo{ id, desktop, host, title }`: id can be passed straight back to `win_activate`; desktop is the desktop the window is on, -1 means sticky (spans all desktops). Error `WinError`: `Unsupported` / `CommandFailed(String)` / `ParseFailed(String)` / `InvalidParam(String)`.

Activation and closing change real window state: the interfaces are fully implemented; the application layer should call them only on user action.

```moonbit
match @sys.win_list() {
  Ok(wins) => for w in wins { println("\{w.id}  \{w.title}") }
  Err(e) => println("Unavailable: \{e}")
}
let _ = @sys.win_activate("ZCode")   // by title
let _ = @sys.win_close("ZCode")
```

## Clipboard Watching

Text read/write and change watching. Windows calls Win32 `CF_UNICODETEXT` directly. Linux prefers GtkClipboard, which requires the host to have run gtk_init; when the probe returns 0 it falls back to the command line `xclip`. The callback dispatches the new text when the text content changes. This module is pure polling — any MoonBit process can use it, and callbacks run in the caller's context.

| Function | Description |
|---|---|
| `cbw_get_text() -> Result[String, ClipboardError]` | read the clipboard text once; unavailable / no text in the selection yields the corresponding Err |
| `cbw_start_watch(interval_ms? = 800, cb) -> ClipboardWatcher` | start watching; the polling interval is clamped to 100..60000. The baseline is the content at startup, so the initial content does not fire the callback |
| `cbw_stop(watcher)` | stop watching; sets a park flag, runs at most one more tick, then terminates itself. Idempotent |

Error `ClipboardError`: `Unsupported` (platform/backend both unavailable) / `CommandFailed(String)`. A read failure silently skips that tick without firing the callback. The polling hangs on a GUI timer, so it only dispatches once the message loop is running.

```moonbit
let w = @sys.cbw_start_watch(interval_ms=500, fn(text) {
  println("New clipboard content: \{text}")
})
// ……when needed
@sys.cbw_stop(w)
```

## Power Plans

Three `powerprofilesctl` commands read the available plan set, read the current plan, and switch plans. When `power-profiles-daemon` is not installed the shell surfaces it via exit code 127 → `PpUnsupported`.

| Function | Description |
|---|---|
| `pp_supported() -> Bool` | powerprofilesctl is present and queryable |
| `pp_profiles() -> Result[Array[PowerProfile], PowerProfileError]` | available plan list, in backend output order; it equals the recommended order when the recommended plan comes first |
| `pp_current() -> Result[PowerProfile, PowerProfileError]` | the current plan |
| `pp_set(profile) -> Result[Unit, PowerProfileError]` | switch plan; has side effects and requires authorization — the caller runs its own authorization flow |

`PowerProfile`: `PPerformance` / `PBalanced` / `PPowerSaver`. Error `PowerProfileError`: `PpUnsupported` / `PpCommandFailed(String)` / `PpParseFailed(String)`.

```moonbit
match @sys.pp_profiles() {
  Ok(profiles) if profiles.contains(@sys.PBalanced) => {
    let _ = @sys.pp_set(@sys.PBalanced)
  }
  _ => ()
}
```

## System Information

Reads `/proc` and `/sys` text only: distro identity (`/etc/os-release`), machine DMI identity (`/sys/class/dmi/id/`), physical memory (`/proc/meminfo`), uptime (`/proc/uptime`). Non-Linux uniformly yields `Unsupported`. A missing file or insufficient permission yields `Err` carrying the path — never an empty string.

| Function | Description |
|---|---|
| `si_os() -> Result[OsInfo, SysInfoError]` | distro: `OsInfo{ pretty_name, id, version_id }` |
| `si_machine() -> Result[MachineInfo, SysInfoError]` | machine: `MachineInfo{ vendor, product, serial }`; the serial is readable only by root on most distros, and unreadable yields `Err` |
| `si_memory() -> Result[MemoryInfo, SysInfoError]` | memory: `MemoryInfo{ total_kb, available_kb }`; unit kB, available_kb is MemAvailable |
| `si_uptime() -> Result[Double, SysInfoError]` | uptime (seconds) |

Error `SysInfoError`: `SiUnsupported` (not Linux) / `SiReadFailed(String)` (carries the path) / `SiParseFailed(String)`.

```moonbit
let os = @sys.si_os() // Ok({ pretty_name: "Ubuntu 24.04.5 LTS", id: "ubuntu", .. })
let mem = @sys.si_memory()
let up = @sys.si_uptime() // Ok(84088.08)
```

## Printers

Windows calls winspool directly — `EnumPrintersW` for the list, `GetDefaultPrinterW` for the default name — and prints via `ShellExecuteW` with the "print" verb. Linux reads the printer list (`-p`) and default printer (`-d`) via `lpstat` and submits jobs via `lp`. Without CUPS installed, lpstat surfaces it via exit code 127 → `PrtUnsupported`.

| Function | Description |
|---|---|
| `prt_supported() -> Bool` | Windows checks that the winspool list is retrievable; Linux checks lpstat availability |
| `prt_list() -> Result[Array[PrinterInfo], PrinterError]` | printer list (name + availability status) |
| `prt_default() -> Result[String, PrinterError]` | default printer name |
| `prt_print(printer? = "", path, copies? = 1) -> Result[Unit, PrinterError]` | submit a print job; Linux defaults printer to the system default, Windows uses the "print" verb and does not support a copies parameter. Has side effects — real queued printing |

`PrinterStatus`: `Idle` / `Printing` / `Paused` (paused, accepts no new jobs) / `Disabled`; `prt_status_available(status)` tells whether it can accept jobs. `PrinterInfo{ name, status }`. Error `PrinterError`: `PrtUnsupported` / `PrtCommandFailed(String)` / `PrtParseFailed(String)` / `PrtInvalidParam(String)` (empty file path, copies < 1).

```moonbit
match @sys.prt_default() {
  Ok(name) => {
    let _ = @sys.prt_print(printer=name, path="/tmp/doc.pdf")
  }
  Err(e) => println("No default printer: \{e}")
}
```

## Environment Variables & Directory Enumeration

Two small primitives: in-process environment-variable read/write/delete (`envx` — reads go through `core/env`, write/delete through the C-layer setenv/unsetenv) and directory enumeration (`fsx` — C-layer opendir/readdir or Win32 FindFirstFileW).

| Function | Purpose |
|---|---|
| `envx_get(name) -> String?` | read the current process environment; None when absent |
| `envx_set(name, value) -> Result[Unit, EnvxError]` | write the current process environment only; visible to subprocesses spawned afterwards |
| `envx_unset(name) -> Result[Unit, EnvxError]` | delete; an absent variable also counts as success — idempotent |
| `envx_common() -> Map[String, String]` | common set: PATH / HOME / LANG / SHELL / USER read as fixed, plus an `XDG_*` prefix scan (included only when present) |
| `fsx_list_dir(path) -> Result[Array[String], FsError]` | enumerate a directory's child names; excludes `.` `..`, non-recursive, includes hidden entries |
| `fsx_set_env(name, value, overwrite) -> Result[Unit, FsError]` | write an environment variable; with overwrite=false and the variable already present, the original value is kept and the result is still Ok |
| `fsx_unset_env(name) -> Result[Unit, FsError]` | delete an environment variable (the low level under envx_unset) |

The semantics are "in-process effect": a write changes only the current process environment — it never touches the system's persistent configuration and never affects the parent process. Errors: `EnvxError::ExInvalidParam(String)` (empty variable name) / `ExFailed(String)` (the C layer rejects, e.g. the name contains '='); `FsError::InvalidParam(String)` / `OpenFailed(String)` (directory cannot be opened, carries the path) / `EnvFailed(String)`. A known edge of `fsx_list_dir`: a child name containing '\n' gets split apart.

```moonbit
let path = @sys.envx_get("PATH")
let _ = @sys.envx_set("MY_FLAG", "1")
let _ = @sys.envx_unset("MY_FLAG")
match @sys.fsx_list_dir("/usr/share/applications") {
  Ok(names) => for n in names if n.ends_with(".desktop") { println(n) }
  Err(e) => println("Cannot open: \{e}")
}
```

## Recent Files (GTK recently-used.xbel)

Parses freedesktop's `recently-used.xbel`. GTK apps write this list via `GtkRecentManager` / xdg-desktop-portal-gtk; Thunar / Nautilus / GIO all append to it when opening a file. File location: `$XDG_DATA_HOME/recently-used.xbel` (default `$HOME/.local/share/`). The XML parser is a hand-written thin scanner: it reads only bookmark nodes and the attributes of `bookmark:application` / `mime:mime-type` child nodes, XML-entity decodes attribute values, and percent-decodes the `file://` URI in href; timestamps convert from ISO 8601 to Unix milliseconds.

| Function | Description |
|---|---|
| `rf_supported() -> Bool` | Linux and the file is readable |
| `rf_recent(limit? = 100) -> Result[Array[RecentItem], RecentError]` | recent file list, modified-descending with ties by path ascending; limit ≤ 0 takes everything |
| `rf_by_app(name, limit? = 100) -> Result[Array[RecentItem], RecentError]` | filter by application name — exact match on the name of `bookmark:application` — also descending |

`RecentItem{ uri, path, mime, added, modified, app_count }`: path is the local path after stripping the `file://` prefix from href and percent-decoding (non-file:// schemes give an empty string); mime is the MIME type (None when that node is absent); added / modified are Unix milliseconds (0 when missing or invalid); app_count is how many applications recorded this file. Error `RecentError`: `RfUnsupported` / `RfNoDataDir` / `RfNoFile` / `RfParseFailed(String)`. Pure decode/conversion functions: `rf_xml_unescape` / `rf_percent_decode` / `rf_uri_to_path` / `rf_iso_to_unix_ms` / `rf_sort_recent`.

```moonbit
match @sys.rf_recent(limit=8) {
  Ok(items) => for it in items { println("\{it.path}  (\{it.modified})") }
  Err(e) => println("Cannot read: \{e}")
}
```

## Browser Bookmarks (Chrome Family)

Read-only parsing of the `Bookmarks` JSON files of Chrome / Chromium / Edge / Brave. The JSON parse reuses the package's hand-written parser — Chrome stores date_added and friends as numeric strings, integer fields keep Int64 precision, and microsecond values convert to Unix milliseconds. All profiles are auto-detected (Default and Profile 1..24).

| Function | Description |
|---|---|
| `bm_supported() -> Bool` | Linux (this file implements only the Linux path detection) |
| `bm_browsers() -> Result[Array[BookmarkProfile], BookmarkError]` | list profiles with a readable Bookmarks file |
| `bm_bookmarks(browser) -> Result[BookmarkNode, BookmarkError]` | the first readable bookmark tree of a given browser; the browser identifier takes "google-chrome"/"chromium"/"microsoft-edge"/"brave", the profile takes Default first, then Profile 1..24 |

`BookmarkProfile{ browser, profile, bookmarks_path }`; `BookmarkNode{ name, url?, children, added, root }` (added is Unix milliseconds; root labels the owning root: bookmark_bar / other / synced). The returned tree has a virtual root — name `"<browser>/<profile>"`, children merge the three roots. `BookmarkNode::is_folder()` / `is_url()` classify nodes, and `bm_flatten(node)` gives a preorder flattened url-bookmark list. Error `BookmarkError`: `BmUnsupported` / `BmNoConfigDir` / `BmNoBrowser` / `BmIoFailed(String)`.

```moonbit
match @sys.bm_bookmarks("google-chrome") {
  Ok(root) =>
    for n in @sys.bm_flatten(root) {
      println("\{n.name}  →  \{n.url}")
    }
  Err(e) => println("Cannot read: \{e}")
}
```

## Firefox Browsing History

Reads each profile's `places.sqlite` (the `moz_places` table) under `~/.mozilla/firefox/`. Entries reuse `browser_history.mbt`'s `HistoryItem`; times convert from Unix-epoch microseconds to milliseconds. Sorting / truncation / column selection reuse the pure functions exported by the same file.

| Function | Description |
|---|---|
| `ffx_supported() -> Bool` | profiles.ini location is implemented for Linux / macOS / Windows |
| `ffx_profiles() -> Result[Array[FirefoxProfile], FirefoxHistoryError]` | list profiles with a readable places.sqlite |
| `ffx_history(limit? = 200) -> Result[Array[HistoryItem], FirefoxHistoryError]` | browsing history — aggregates all detected profiles, sorted by last-visit time descending; limit ≤ 0 takes everything |

`FirefoxProfile{ profile, places_path }` (profile is the `Path=` directory name from profiles.ini; absolute paths take the last segment). Hidden entries are filtered out; a single profile read failure is skipped, and `FfxIoFailed` is yielded only when all fail. Error `FirefoxHistoryError`: `FfxUnsupported` / `FfxNoProfile` (Firefox not installed or never started) / `FfxIoFailed(String)`. When profiles.ini is missing it falls back to fixed candidate names (default / default-release / default-esr / default-nightly / dev-edition-default); profile directories with a random prefix are not picked up.

```moonbit
match @sys.ffx_history(limit=10) {
  Ok(items) => for it in items { println("\{it.title}  \{it.url}") }
  Err(e) => println("Cannot read: \{e}")
}
```

## Shared Infrastructure: Subprocess Execution (procrun)

The shared "spawn → bounded-time reap → capture stdout/stderr to temp files" wrapper used by all command-line capabilities (volume, monitors, wallpaper, night light, printers, power plans, Firefox profile location): the command name resolves via PATH; the subprocess is forced to the C locale; exit code 0 normalizes to `Ok`, and a nonzero exit normalizes to `Err` carrying stderr.

| Function | Description |
|---|---|
| `pr_available() -> Bool` | whether the current platform supports subprocess execution; true on the three main platforms Linux / macOS / Windows, based on the sys package's own C stubs |
| `pr_run(cmd, args, timeout_ms? = 5000) -> Result[ProcOutput, ProcError]` | run a command and normalize the result; a timed-out process is force-terminated |

`ProcOutput{ stdout, exit_code }`; error `ProcError`: `Unsupported` (not one of the Linux / macOS / Windows main platforms) / `SpawnFailed(String)` (a missing command surfaces via the subprocess's exit code 127, folded into a nonzero exit) / `Timeout(String)` / `NonZeroExit(Int, String)` / `Signaled(Int)`.

"Command missing" and "present but failed" carry different semantics: the former normalizes to `*Supported == false` or `Unsupported` (e.g. `PpUnsupported`, `PrtUnsupported`); the latter is `CommandFailed`.

```moonbit
match @sys.pr_run("wpctl", ["get-volume", "@DEFAULT_SINK@"]) {
  Ok(out) => println(out.stdout)
  Err(@sys.ProcError::NonZeroExit(_, err)) => println("Failed: \{err}")
  Err(e) => println(e)
}
```

## Shared Infrastructure: Generic D-Bus Call Layer (@dbus)

Method calls and property read/write against any service — the common foundation for modules such as media control (MPRIS). Connections reuse the process-level session/system connections of `bus.mbt`; encoding/decoding reuses the wire protocol of `wire.mbt`. Synchronous calls time out at 1.5 seconds; a response timeout yields `gdbus.timeout`.

| Function | Description |
|---|---|
| `gdbus_call_session(dest, path, iface, action, args) -> Result[GDBusValue, GDBusError]` | session-bus method call |
| `gdbus_call_system(dest, path, iface, action, args) -> Result[GDBusValue, GDBusError]` | system-bus method call |
| `gdbus_get_property_session(dest, path, iface, prop)` / `gdbus_get_property_system(...)` | read a property via `org.freedesktop.DBus.Properties.Get`; the return value already has the variant wrapper stripped |
| `gdbus_set_property_session(dest, path, iface, prop, value)` / `gdbus_set_property_system(...)` | write a property via `Properties.Set`; pass a bare value as value — the variant wrapper is added at this layer |

Value model `GDBusValue`: `GVNone` (no return value, cannot be a call argument) / `GVBool` / `GVInt32` / `GVUInt32` / `GVInt64` / `GVU64` ('t', unsigned 64-bit values such as Size/Time in udisks) / `GVDouble` / `GVString` / `GVPath` ('o') / `GVArray(element signature, element table)` / `GVDict(a{sv}, values already have the variant wrapper stripped, Map serialized in insertion order)` / `GVVariant` (keeps the wrapper) / `GVStruct`. On the response side, `{sv}` arrays fold into `GVDict`, and multiple return values fold into `GVStruct`. Error `GDBusError{ name, message }`: name is a D-Bus error name or a local prefix `gdbus.io` (cannot connect / disconnected) / `gdbus.timeout` / `gdbus.encode`.

```moonbit
match
  @dbus.gdbus_get_property_system(
    "org.freedesktop.timedate1",
    "/org/freedesktop/timedate1",
    "org.freedesktop.timedate1",
    "NTP",
  ) {
  Ok(@dbus.GVBool(on)) => println("NTP enabled: \{on}")
  Ok(_) => ()
  Err(e) => println("Bus call failed: \{e.name} \{e.message}")
}
```

## Boundaries

- While the browser runs, its History database keeps taking new writes; the read result is a snapshot at the moment of reading.
- Firefox's places.sqlite often stays in WAL mode; this implementation reads only the main database file, so the latest records not yet checkpointed into it are not readable. When aggregating multiple profiles, the same url appears once per profile — consistent with the Chrome-side aggregation.
- `appfind_executable` hits when a directory has an entry of that name; it does not read file contents or check the executable permission bit.
- Volume setting relies on the corresponding system service being online (Windows IAudioEndpointVolume / Linux PipeWire-Pulse); when the service is absent, write interfaces return an error value.
- Printing / switching power plans change real system state: the interfaces are fully implemented, but call them only on explicit user action — never trigger them on the user's behalf in probe or query paths.
- Both the clipboard watcher's and the ripple animation's timers are driven by the message loop and have no cancel id (`set_timer`): the way to stop them is for the callback to return false, so handle-class APIs (`cbw_stop` / `eff_stop`) should be called explicitly before a component is destroyed.

[中文文档](/zh/system-capabilities.md)
