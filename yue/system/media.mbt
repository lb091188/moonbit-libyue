// 媒体控制（MPRIS / Windows SMTC 对标）：经会话总线 D-Bus 枚举
// org.mpris.MediaPlayer2.* 播放器实例，播放控制（play / pause /
// play_pause / next / previous / stop）与状态读取（PlaybackStatus +
// Metadata 的 title / artist / album）走 MPRIS Player 接口，总线调用
// 复用 @traybus 通用调用层的 gdbus_call_session / gdbus_get_property_session。
// playerctl 可用（--version 退出 0）时，总线调用失败的命令类操作回退
// 到 playerctl 子命令（pr helper，命令回退路径）。macOS 无 MPRIS，等价
// 手段是 osascript 对支持 AppleScript 的播放器（Music / Spotify /
// iTunes）发命令，且必须先 pgrep 探测再发命令（osascript 会拉起未运行
// 的 App）。Linux / macOS 之外一律 Unsupported；播放控制属设置类操作，
// 由调用方决定何时执行，本模块不在探测中代为触发。总线名过滤、状态文本
// 映射、Metadata 字段提取、playerctl 参数构造与输出解析、osascript 脚本
// 拼装与输出解析均为纯函数（media_ 前缀），media_wbtest.mbt 白盒覆盖。
//
// 典型用法：
//   match media_players() {
//     Ok(players) =>
//       for p in players {
//         println("\{p.identity}（\{p.name}）")
//         match media_status(p.name) {
//           Ok(s) => println("  \{s.playback} - \{s.title} / \{s.artist}")
//           Err(e) => println("  读状态失败：\{e}")
//         }
//       }
//     Err(e) => println("媒体控制不可用：\{e}")
//   }
//   // 播放控制（设置类）：按需调用，如 media_play_pause(name) 切换播放/暂停

///|
/// 一个 MPRIS 播放器实例：name 为总线唯一名
/// （org.mpris.MediaPlayer2.<实例名>，media_players 应答的元素），
/// identity 为展示名（Identity 属性，读不到回退为 name）。
pub(all) struct MediaPlayerInfo {
  name : String
  identity : String
}

///|
pub impl Show for MediaPlayerInfo with fn output(self, logger) {
  logger.write_string("MediaPlayerInfo { name: ")
  logger.write_string(self.name)
  logger.write_string(", identity: ")
  logger.write_string(self.identity)
  logger.write_string(" }")
}

///|
pub extend MediaPlayerInfo with Show::{to_string, output}

///|
/// 播放状态（MPRIS PlaybackStatus 属性）：Playing / Paused / Stopped
/// 三态，其余原文（含播放器自定义值）进 MediaUnknown。
pub(all) enum MediaPlayback {
  MediaPlaying
  MediaPaused
  MediaStopped
  MediaUnknown(String)
}

///|
pub impl Show for MediaPlayback with fn output(self, logger) {
  match self {
    MediaPlaying => logger.write_string("MediaPlaying")
    MediaPaused => logger.write_string("MediaPaused")
    MediaStopped => logger.write_string("MediaStopped")
    MediaUnknown(text) => logger.write_string("MediaUnknown(\{text})")
  }
}

///|
pub extend MediaPlayback with Show::{to_string, output}

///|
/// 播放状态快照：所属播放器总线名、播放状态、当前曲目标题 / 艺术家 /
/// 专辑（Metadata 的 xesam: 键，缺失字段为空串）。
pub(all) struct MediaStatus {
  player : String
  playback : MediaPlayback
  title : String
  artist : String
  album : String
}

///|
pub impl Show for MediaStatus with fn output(self, logger) {
  logger.write_string("MediaStatus { player: ")
  logger.write_string(self.player)
  logger.write_string(", playback: ")
  logger.write_string(self.playback.to_string())
  logger.write_string(", title: ")
  logger.write_string(self.title)
  logger.write_string(", artist: ")
  logger.write_string(self.artist)
  logger.write_string(", album: ")
  logger.write_string(self.album)
  logger.write_string(" }")
}

///|
pub extend MediaStatus with Show::{to_string, output}

///|
pub(all) enum MediaError {
  /// 平台/环境不支持（Linux / macOS 之外；子进程执行不可用；macOS 上
  /// 目标非候选播放器或该播放器不支持此命令）
  Unsupported
  /// 没有任何可用播放器实例（总线上无 MPRIS 实例；macOS 上三款候选
  /// App 都没在运行）
  NoPlayer
  /// 总线调用失败（连不上/已断开｜应答超时｜服务不存在｜方法被拒），
  /// 带错误名与说明
  BusFailed(String)
  /// 命令失败（playerctl 回退命令 / macOS 的 osascript），带原因
  CommandFailed(String)
  /// 播放器应答/属性解析失败（类型不符），带原文
  ParseFailed(String)
}

///|
pub impl Show for MediaError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("MediaError::Unsupported")
    NoPlayer => logger.write_string("MediaError::NoPlayer")
    BusFailed(m) => logger.write_string("MediaError::BusFailed(\{m})")
    CommandFailed(m) => logger.write_string("MediaError::CommandFailed(\{m})")
    ParseFailed(m) => logger.write_string("MediaError::ParseFailed(\{m})")
  }
}

///|
pub extend MediaError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 常量：MPRIS 与 D-Bus 名称（协议固定值）
// ---------------------------------------------------------------------------

///|
/// MPRIS 总线名前缀（ListNames 过滤器；playerctld 实例也在其下）。
let media_name_prefix : String = "org.mpris.MediaPlayer2."

///|
/// MPRIS 对象路径（所有播放器实例同一路径）。
let media_object_path : String = "/org/mpris/MediaPlayer2"

///|
/// MPRIS 基础接口（Identity 等属性所在）。
let media_iface_base : String = "org.mpris.MediaPlayer2"

///|
/// MPRIS 播放接口（Play/Pause/.../PlaybackStatus/Metadata 所在）。
let media_iface_player : String = "org.mpris.MediaPlayer2.Player"

///|
/// 总线守护进程名 / 对象路径 / 接口（ListNames 用）。
let media_dbus_name : String = "org.freedesktop.DBus"

///|
let media_dbus_path : String = "/org/freedesktop/DBus"

///|
let media_dbus_iface : String = "org.freedesktop.DBus"

// ---------------------------------------------------------------------------
// 纯函数层：总线名过滤 / 状态映射 / Metadata 字段（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 是否 MPRIS 播放器总线名：前缀匹配且后缀非空（裸前缀
/// "org.mpris.MediaPlayer2." 与无后缀的近似名都不收）。
fn media_is_mpris_name(name : String) -> Bool {
  name.has_prefix(media_name_prefix) &&
  name.length() > media_name_prefix.length()
}

///|
/// ListNames 应答（as）→ MPRIS 播放器总线名列表：过滤非播放器名，
/// 保持应答序；非数组应答给空表。
fn media_mpris_names(v : @traybus.GDBusValue) -> Array[String] {
  match v {
    @traybus.GVArray(_, items) => {
      let out : Array[String] = []
      for it in items {
        match it {
          @traybus.GVString(s) => if media_is_mpris_name(s) { out.push(s) }
          _ => ()
        }
      }
      out
    }
    _ => []
  }
}

///|
/// PlaybackStatus 文本 → 播放状态：Playing / Paused / Stopped 三态，
/// 其余原样收进 MediaUnknown；容忍首尾空白。
pub fn media_playback_of(text : String) -> MediaPlayback {
  let t = text.trim().to_owned()
  if t == "Playing" {
    MediaPlaying
  } else if t == "Paused" {
    MediaPaused
  } else if t == "Stopped" {
    MediaStopped
  } else {
    MediaUnknown(t)
  }
}

///|
/// Metadata（a{sv}）取字符串字段：缺失或类型不符给空串。
fn media_meta_str(
  meta : Map[String, @traybus.GDBusValue],
  key : String,
) -> String {
  match meta.get(key) {
    Some(@traybus.GVString(s)) => s
    _ => ""
  }
}

///|
/// Metadata 取艺术家字段：xesam:artist 规范形态是字符串数组（as），
/// 取首个元素；个别播放器给单字符串也收；缺失或空数组给空串。
fn media_meta_artist(meta : Map[String, @traybus.GDBusValue]) -> String {
  match meta.get("xesam:artist") {
    Some(@traybus.GVArray(_, items)) => {
      for it in items {
        match it {
          @traybus.GVString(s) => return s
          _ => ()
        }
      }
      ""
    }
    Some(@traybus.GVString(s)) => s
    _ => ""
  }
}

///|
/// 纯函数组装 [MediaStatus]：播放状态由 [media_playback_of] 映射，
/// 曲目三字段取 Metadata 的 xesam:title / xesam:artist / xesam:album
/// 键（缺失为空串）。
pub fn media_status_of(
  player : String,
  playback : MediaPlayback,
  meta : Map[String, @traybus.GDBusValue],
) -> MediaStatus {
  {
    player,
    playback,
    title: media_meta_str(meta, "xesam:title"),
    artist: media_meta_artist(meta),
    album: media_meta_str(meta, "xesam:album"),
  }
}

// ---------------------------------------------------------------------------
// 纯函数层：命令名映射与 playerctl 参数/输出解析（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 内部控制命令（播放操作集合）。
priv enum MediaCmd {
  MediaCmdPlay
  MediaCmdPause
  MediaCmdPlayPause
  MediaCmdNext
  MediaCmdPrevious
  MediaCmdStop
}

///|
/// 命令 → MPRIS Player 方法名（Play / Pause / PlayPause / Next /
/// Previous / Stop，协议大小写敏感）。
fn media_mpris_method(c : MediaCmd) -> String {
  match c {
    MediaCmdPlay => "Play"
    MediaCmdPause => "Pause"
    MediaCmdPlayPause => "PlayPause"
    MediaCmdNext => "Next"
    MediaCmdPrevious => "Previous"
    MediaCmdStop => "Stop"
  }
}

///|
/// 命令 → playerctl 子命令名（PlayPause 在命令行是 play-pause）。
fn media_playerctl_subcmd(c : MediaCmd) -> String {
  match c {
    MediaCmdPlay => "play"
    MediaCmdPause => "pause"
    MediaCmdPlayPause => "play-pause"
    MediaCmdNext => "next"
    MediaCmdPrevious => "previous"
    MediaCmdStop => "stop"
  }
}

///|
/// 总线名 → playerctl 选择参数值：剥掉 org.mpris.MediaPlayer2. 前缀
/// （playerctl -p 认播放器实例名，如 vlc / playerctld）；非 MPRIS
/// 形态原样返回。
fn media_playerctl_sel(name : String) -> String {
  if !media_is_mpris_name(name) {
    return name
  }
  let buf = StringBuilder()
  let chars : Array[Char] = []
  for ch in name {
    chars.push(ch)
  }
  let mut i = media_name_prefix.length()
  while i < chars.length() {
    buf.write_char(chars[i])
    i += 1
  }
  buf.to_string()
}

///|
/// playerctl metadata --format 模板：三个 xesam 字段以 US 字符
/// （U+001F，控制字符，元数据文本实际不会出现）分隔，一次调用取回
/// 全部曲目字段。
let media_playerctl_meta_format : String = "\u{1f}{{title}}\u{1f}{{artist}}\u{1f}{{album}}"

///|
/// playerctl metadata 调用参数表（-p 选择播放器 + --format 模板）。
fn media_playerctl_meta_args(sel : String) -> Array[String] {
  ["-p", sel, "metadata", "--format", media_playerctl_meta_format]
}

///|
/// 按 US 字符（U+001F）切分文本（空段保留，如行首分隔符前的空串；
/// 至少返回一个元素）。
fn media_split_us(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut cur = StringBuilder()
  for ch in s {
    if ch == '\u{1f}' {
      out.push(cur.to_string())
      cur = StringBuilder()
    } else {
      cur.write_char(ch)
    }
  }
  out.push(cur.to_string())
  out
}

///|
/// playerctl --format 输出 → (title, artist, album)：按 US 字符切段，
/// 缺段补空串（个别播放器不支持模板时输出无分隔符，整段作标题）；
/// 容忍首尾换行。
fn media_playerctl_parse_meta(out : String) -> (String, String, String) {
  let parts = media_split_us(out.trim().to_owned())
  let title = if parts.length() > 0 { parts[0] } else { "" }
  let artist = if parts.length() > 1 { parts[1] } else { "" }
  let album = if parts.length() > 2 { parts[2] } else { "" }
  (title, artist, album)
}

// ---------------------------------------------------------------------------
// playerctl 回退层（pr helper：--version 探测 + 子命令执行）
// ---------------------------------------------------------------------------

///|
/// playerctl 是否可用：--version 退出 0 即存在（真实探测，只读；
/// 每次调用重新探测，高频场景请调用方自行缓存）。
fn media_playerctl_available() -> Bool {
  if !pr_available() {
    return false
  }
  match pr_run("playerctl", ["--version"], timeout_ms=2000) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
/// 运行 playerctl 并取 stdout；失败按 ProcError 归一为 [MediaError]。
fn media_run_playerctl(args : Array[String]) -> Result[String, MediaError] {
  match pr_run("playerctl", args, timeout_ms=3000) {
    Ok(o) => Ok(o.stdout)
    Err(NonZeroExit(code, err)) =>
      Err(CommandFailed("playerctl: 退出码 \{code} \{err}"))
    Err(Timeout(m)) => Err(CommandFailed(m))
    Err(SpawnFailed(m)) => Err(CommandFailed(m))
    Err(Signaled(sig)) =>
      Err(CommandFailed("playerctl: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(Unsupported)
  }
}

///|
/// playerctl 命令回退：-p 选择播放器后执行对应子命令（-p 传实例名，
/// 由 [media_playerctl_sel] 从总线名剥出）。
fn media_playerctl_control(
  player : String,
  c : MediaCmd,
) -> Result[Unit, MediaError] {
  match
    media_run_playerctl([
      "-p",
      media_playerctl_sel(player),
      media_playerctl_subcmd(c),
    ]) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

// ---------------------------------------------------------------------------
// 总线层：ListNames 枚举实例 / Identity / PlaybackStatus / Metadata
// ---------------------------------------------------------------------------

///|
/// ListNames 应答 → 播放器实例列表：每个实例补一次 Identity 属性读作
/// 展示名（属性读不到或类型不符回退总线名）。
fn media_players_dbus() -> Result[Array[MediaPlayerInfo], MediaError] {
  match
    @traybus.gdbus_call_session(
      media_dbus_name,
      media_dbus_path,
      media_dbus_iface,
      "ListNames",
      [],
    ) {
    Err(e) => Err(BusFailed("\{e.name}: \{e.message}"))
    Ok(v) => {
      let out : Array[MediaPlayerInfo] = []
      for name in media_mpris_names(v) {
        out.push(media_info_of(name))
      }
      Ok(out)
    }
  }
}

///|
/// 单个实例的展示名：Identity 属性读作 identity（读不到或空串回退
/// 总线名）。
fn media_info_of(name : String) -> MediaPlayerInfo {
  let identity = match
    @traybus.gdbus_get_property_session(
      name, media_object_path, media_iface_base, "Identity",
    ) {
    Ok(@traybus.GVString(s)) => if s != "" { s } else { name }
    _ => name
  }
  { name, identity, }
}

///|
/// 总线路径读播放状态：PlaybackStatus 属性（字符串）映射播放状态，
/// Metadata 属性（a{sv}）取曲目三字段。
fn media_status_dbus(player : String) -> Result[MediaStatus, MediaError] {
  let playback = match
    @traybus.gdbus_get_property_session(
      player, media_object_path, media_iface_player, "PlaybackStatus",
    ) {
    Ok(@traybus.GVString(s)) => media_playback_of(s)
    Ok(_) => return Err(ParseFailed("PlaybackStatus 属性类型不符"))
    Err(e) => return Err(BusFailed("\{e.name}: \{e.message}"))
  }
  let meta = match
    @traybus.gdbus_get_property_session(
      player, media_object_path, media_iface_player, "Metadata",
    ) {
    Ok(@traybus.GVDict(m)) => m
    Ok(_) =>
      return Err(ParseFailed("Metadata 属性类型不符（非 a{sv}）"))
    Err(e) => return Err(BusFailed("\{e.name}: \{e.message}"))
  }
  Ok(media_status_of(player, playback, meta))
}

///|
/// playerctl 回退读状态：status 子命令取播放状态，metadata --format
/// 一次取回 title / artist / album（只读，不改变播放状态）。
fn media_status_playerctl(player : String) -> Result[MediaStatus, MediaError] {
  let sel = media_playerctl_sel(player)
  let playback = match media_run_playerctl(["-p", sel, "status"]) {
    Ok(out) => media_playback_of(out)
    Err(e) => return Err(e)
  }
  let (title, artist, album) = match
    media_run_playerctl(media_playerctl_meta_args(sel)) {
    Ok(out) => media_playerctl_parse_meta(out)
    Err(e) => return Err(e)
  }
  Ok({ player, playback, title, artist, album, })
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 媒体控制是否可用：Linux 且会话总线可列名（ListNames 成功），或
/// playerctl 可用（命令回退路径）；macOS 上子进程执行可用（osascript /
/// pgrep 随系统自带）即支持。每次调用真实探测。
pub fn media_supported() -> Bool {
  match @yue.platform() {
    "linux" => media_supported_linux()
    "macos" => media_supported_mac()
    _ => false
  }
}

///|
/// Linux 路径的可用性探测：会话总线可列名（ListNames 成功），或
/// playerctl 可用（命令回退路径）。每次调用真实探测。
fn media_supported_linux() -> Bool {
  match
    @traybus.gdbus_call_session(
      media_dbus_name,
      media_dbus_path,
      media_dbus_iface,
      "ListNames",
      [],
    ) {
    Ok(@traybus.GVArray(_, _)) => true
    Ok(_) => false
    Err(_) => media_playerctl_available()
  }
}

///|
/// 枚举可用播放器实例：Linux 枚举会话总线上的 MPRIS 实例
/// （org.mpris.MediaPlayer2.*，含 playerctld 代理实例），保持 ListNames
/// 应答序；macOS 列出三款候选中正在运行的 App。Linux / macOS 之外给
/// [Unsupported]；总线不可用给 [BusFailed]；一个实例都没有给
/// [NoPlayer]（无播放器 ≠ 不可用，可稍后再试）。
pub fn media_players() -> Result[Array[MediaPlayerInfo], MediaError] {
  match @yue.platform() {
    "linux" => media_players_linux()
    "macos" => media_players_mac()
    _ => Err(Unsupported)
  }
}

///|
/// Linux 路径枚举播放器实例：会话总线的 MPRIS 实例（保持 ListNames
/// 应答序）；一个都没有给 [NoPlayer]。
fn media_players_linux() -> Result[Array[MediaPlayerInfo], MediaError] {
  match media_players_dbus() {
    Ok(players) => if players.is_empty() { Err(NoPlayer) } else { Ok(players) }
    Err(e) => Err(e)
  }
}

///|
/// 读某播放器的播放状态与当前曲目（title / artist / album）。Linux：
/// 总线路径失败且 playerctl 可用时回退 playerctl 只读查询；macOS：对
/// 正在运行的候选 App 发 osascript 状态查询。两种路径都失败给对应错误
/// （总线错误名、命令退出原因或解析原文）。
pub fn media_status(player : String) -> Result[MediaStatus, MediaError] {
  match @yue.platform() {
    "linux" => media_status_linux(player)
    "macos" => media_status_mac(player)
    _ => Err(Unsupported)
  }
}

///|
/// Linux 路径读播放状态：总线失败且 playerctl 可用时回退 playerctl
/// 只读查询。
fn media_status_linux(player : String) -> Result[MediaStatus, MediaError] {
  match media_status_dbus(player) {
    Ok(s) => Ok(s)
    Err(e) =>
      if media_playerctl_available() {
        media_status_playerctl(player)
      } else {
        Err(e)
      }
  }
}

///|
/// 播放控制公共实现：Linux 优先 MPRIS Player 方法（会话总线），总线调用
/// 失败且 playerctl 可用时回退 playerctl 子命令；macOS 对正在运行的候选
/// App 发 osascript 命令。属设置类操作，只在调用方显式调用时执行，探测
/// 与查询路径不会触发。
fn media_control(player : String, c : MediaCmd) -> Result[Unit, MediaError] {
  match @yue.platform() {
    "linux" => media_control_linux(player, c)
    "macos" => media_control_mac(player, c)
    _ => Err(Unsupported)
  }
}

///|
/// Linux 路径的播放控制实现：优先 MPRIS Player 方法（会话总线）；总线
/// 调用失败且 playerctl 可用时回退 playerctl 子命令。
fn media_control_linux(
  player : String,
  c : MediaCmd,
) -> Result[Unit, MediaError] {
  match
    @traybus.gdbus_call_session(
      player,
      media_object_path,
      media_iface_player,
      media_mpris_method(c),
      [],
    ) {
    Ok(_) => Ok(())
    Err(e) =>
      if media_playerctl_available() {
        media_playerctl_control(player, c)
      } else {
        Err(BusFailed("\{e.name}: \{e.message}"))
      }
  }
}

///|
/// 开始/继续播放（MPRIS Player.Play；playerctl play 回退）。
pub fn media_play(player : String) -> Result[Unit, MediaError] {
  media_control(player, MediaCmdPlay)
}

///|
/// 暂停播放（MPRIS Player.Pause；playerctl pause 回退）。
pub fn media_pause(player : String) -> Result[Unit, MediaError] {
  media_control(player, MediaCmdPause)
}

///|
/// 播放/暂停切换（MPRIS Player.PlayPause；playerctl play-pause 回退）。
pub fn media_play_pause(player : String) -> Result[Unit, MediaError] {
  media_control(player, MediaCmdPlayPause)
}

///|
/// 下一曲（MPRIS Player.Next；playerctl next 回退）。
pub fn media_next(player : String) -> Result[Unit, MediaError] {
  media_control(player, MediaCmdNext)
}

///|
/// 上一曲（MPRIS Player.Previous；playerctl previous 回退）。
pub fn media_previous(player : String) -> Result[Unit, MediaError] {
  media_control(player, MediaCmdPrevious)
}

///|
/// 停止播放（MPRIS Player.Stop；playerctl stop 回退；macOS 上 Spotify 的
/// AppleScript 字典无 stop 命令，给 [Unsupported]）。
pub fn media_stop(player : String) -> Result[Unit, MediaError] {
  media_control(player, MediaCmdStop)
}

// ---------------------------------------------------------------------------
// macOS 实现：osascript 对支持 AppleScript 的播放器发命令
//
// macOS 没有 MPRIS，等价手段是 osascript 对支持 AppleScript 的播放器发
// 命令，候选限定 Music / Spotify / iTunes 三款（脚本字典一致）。两条硬约束：
// 一是**先探测再发命令**——osascript 对未运行的 App 会把它拉起来，那是
// 副作用，故任何命令前先 `pgrep -x <app>` 探测（退出码 0 即在运行），未
// 运行直接 NoPlayer，绝不发命令；二是**不支持的命令不偷偷映射**——Spotify
// 的 AppleScript 字典无 stop，对它请求 stop 返回 Unsupported 而非退化成
// pause。状态查询的 player state 是小写（playing / paused / stopped），
// 由 [media_mac_state_text] 规范化后仍交给 [media_playback_of] 映射；
// 脚本拼装与输出解析均为纯函数，media_wbtest.mbt 白盒覆盖（无 macOS
// 真机也能测）。
// ---------------------------------------------------------------------------

///|
/// macOS 候选播放器（AppleScript 字典一致的三个 App）：Music 为系统音乐
/// App、Spotify、iTunes 为旧系统上的音乐 App。枚举序即 [media_players]
/// 的返回序。
let media_mac_apps : Array[String] = ["Music", "Spotify", "iTunes"]

///|
/// macOS 候选播放器列表（枚举序即优先级）：[media_players_mac] 依次探测
/// 其中正在运行的 App。纯函数，media_wbtest.mbt 白盒覆盖。
fn media_mac_candidates() -> Array[String] {
  media_mac_apps
}

///|
/// 是否 macOS 候选播放器：非候选的播放器名（如 MPRIS 总线名）在 macOS
/// 路径上一律拒收，避免把陌生名字拼进 osascript 脚本。
fn media_mac_is_candidate(app : String) -> Bool {
  media_mac_candidates().contains(app)
}

///|
/// 命令 → AppleScript 命令文本（playpause 是一个词；切轨是 `next track`
/// / `previous track`）。与 MPRIS 方法名、playerctl 子命令并列第三套
/// 命令名映射。
fn media_mac_cmd_text(c : MediaCmd) -> String {
  match c {
    MediaCmdPlay => "play"
    MediaCmdPause => "pause"
    MediaCmdPlayPause => "playpause"
    MediaCmdNext => "next track"
    MediaCmdPrevious => "previous track"
    MediaCmdStop => "stop"
  }
}

///|
/// 拼装 `tell application "<app>" to <命令>` 脚本文本。
fn media_mac_script(app : String, cmd : String) -> String {
  "tell application \"" + app + "\" to " + cmd
}

///|
/// 控制命令的 osascript 参数表（`osascript -e '<脚本>'`）；无对应命令时
/// None——Spotify 的 AppleScript 字典没有 stop，不映射成 pause。纯函数，
/// media_wbtest.mbt 白盒覆盖。
fn media_mac_as_args(app : String, c : MediaCmd) -> Array[String]? {
  if app == "Spotify" && (c is MediaCmdStop) {
    None
  } else {
    Some(["-e", media_mac_script(app, media_mac_cmd_text(c))])
  }
}

///|
/// 状态查询的 osascript 参数表：一次取回 player state 与曲目三字段
/// （AppleScript 列表转文本为「英文逗号 + 空格」分隔）。纯函数。
fn media_mac_state_args(app : String) -> Array[String] {
  [
    "-e",
    media_mac_script(
      app,
      "get {player state, name of current track, artist of current track, album of current track}",
    ),
  ]
}

///|
/// AppleScript 的 player state（小写 playing / paused / stopped）→
/// [media_playback_of] 认的首字母大写形态；未知文本 trim 后原样返回，
/// 由 [media_playback_of] 收进 MediaUnknown（不绕过该映射）。纯函数。
fn media_mac_state_text(text : String) -> String {
  let t = text.trim().to_owned()
  if t == "playing" {
    "Playing"
  } else if t == "paused" {
    "Paused"
  } else if t == "stopped" {
    "Stopped"
  } else {
    t
  }
}

///|
/// 是否 AppleScript 的 player state 词（小写三态）：状态输出的首段不是
/// 这三个词即说明 osascript 报错（错误文本），整段不可解析。
fn media_mac_is_state(text : String) -> Bool {
  let t = text.trim().to_owned()
  t == "playing" || t == "paused" || t == "stopped"
}

///|
/// 按第一个逗号切出首段与余段（AppleScript 列表分隔符是「英文逗号 +
/// 空格」），无逗号时整段作首段、余段为空；两段各自 trim。
fn media_mac_split_head(s : String) -> (String, String) {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let n = chars.length()
  let mut i = 0
  while i < n {
    if chars[i] == ',' {
      let head = StringBuilder()
      let mut k = 0
      while k < i {
        head.write_char(chars[k])
        k = k + 1
      }
      let tail = StringBuilder()
      let mut j = i + 1
      while j < n {
        tail.write_char(chars[j])
        j = j + 1
      }
      return (head.to_string().trim().to_owned(), tail.to_string().trim().to_owned())
    }
    i = i + 1
  }
  (s.trim().to_owned(), "")
}

///|
/// 按逗号切分并逐段 trim（至少返回一个元素；空串给 [""]）。
fn media_mac_split_commas(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut cur = StringBuilder()
  for ch in s {
    if ch == ',' {
      out.push(cur.to_string().trim().to_owned())
      cur = StringBuilder()
    } else {
      cur.write_char(ch)
    }
  }
  out.push(cur.to_string().trim().to_owned())
  out
}

///|
/// 段数组拼回文本（以「英文逗号 + 空格」连接），用于把含逗号的曲名还原。
fn media_mac_join(parts : Array[String]) -> String {
  let buf = StringBuilder()
  let mut i = 0
  while i < parts.length() {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string(parts[i])
    i = i + 1
  }
  buf.to_string()
}

///|
/// 解析 osascript 状态查询输出 → (player state, title, artist, album)：
/// 首段只可能是 playing / paused / stopped 三词，故按第一个逗号切出播放
/// 态；余下三段从后往前分配（album 取末段、artist 取次末段，其余全部归
/// title），这样曲名里的逗号不会破坏分段；不足三段时按 title → artist
/// → album 顺序依次填入，缺的留空。输出为空、或首段不是播放态（无曲目
/// 时 AppleScript 报错，输出为错误文本）→ None。纯函数，
/// media_wbtest.mbt 白盒覆盖。
fn media_mac_parse_status(out : String) -> (String, String, String, String)? {
  let text = out.trim().to_owned()
  if text == "" {
    return None
  }
  let (state, rest) = media_mac_split_head(text)
  if !media_mac_is_state(state) {
    return None
  }
  let parts = media_mac_split_commas(rest)
  let n = parts.length()
  if n == 1 {
    return Some((state, parts[0], "", ""))
  }
  if n == 2 {
    return Some((state, parts[0], parts[1], ""))
  }
  let title_parts : Array[String] = []
  let mut i = 0
  while i < n - 2 {
    title_parts.push(parts[i])
    i = i + 1
  }
  Some((state, media_mac_join(title_parts), parts[n - 2], parts[n - 1]))
}

///|
/// stderr 诊断文本压成单行并截断（错误消息只取首行前 120 字符，避免
/// 刷屏）。
fn media_first_line(s : String) -> String {
  let buf = StringBuilder()
  let mut n = 0
  for ch in s {
    if ch == '\n' || n >= 120 {
      break
    }
    buf.write_char(ch)
    n = n + 1
  }
  buf.to_string()
}

///|
/// macOS 路径可用性：osascript / pgrep 随系统自带，子进程执行可用即可用
/// （不额外起进程探测）。
fn media_supported_mac() -> Bool {
  pr_available()
}

///|
/// macOS 路径枚举播放器：三款候选中正在运行的都列出（name / identity
/// 同为 App 名，macOS 侧没有独立的可读展示名）；一个都没运行给
/// [NoPlayer]（无播放器 ≠ 不可用）。
fn media_players_mac() -> Result[Array[MediaPlayerInfo], MediaError] {
  if !pr_available() {
    return Err(Unsupported)
  }
  let out : Array[MediaPlayerInfo] = []
  for app in media_mac_candidates() {
    if media_mac_running(app) {
      out.push({ name: app, identity: app })
    }
  }
  if out.is_empty() {
    Err(NoPlayer)
  } else {
    Ok(out)
  }
}

///|
/// macOS 路径读播放状态：先 [media_mac_running] 探测（未运行绝不发
/// osascript，否则会把 App 拉起来），再取 player state 与曲目三字段；
/// 播放态经 [media_mac_state_text] 规范化后仍走 [media_playback_of] 映射。
fn media_status_mac(player : String) -> Result[MediaStatus, MediaError] {
  if !pr_available() {
    return Err(Unsupported)
  }
  if !media_mac_is_candidate(player) {
    return Err(Unsupported)
  }
  if !media_mac_running(player) {
    return Err(NoPlayer)
  }
  let out = match media_mac_run_osascript(media_mac_state_args(player)) {
    Ok(o) => o
    Err(e) => return Err(e)
  }
  match media_mac_parse_status(out) {
    None => Err(ParseFailed("osascript: \{media_first_line(out)}"))
    Some((state, title, artist, album)) =>
      Ok(
        {
          player,
          playback: media_playback_of(media_mac_state_text(state)),
          title,
          artist,
          album,
        },
      )
  }
}

///|
/// macOS 路径播放控制：先探测再发命令（osascript 会拉起未运行的 App，
/// 这是副作用）；[media_mac_as_args] 给不出命令（Spotify 的 stop）→
/// [Unsupported]；未运行 → [NoPlayer]。
fn media_control_mac(player : String, c : MediaCmd) -> Result[Unit, MediaError] {
  if !pr_available() {
    return Err(Unsupported)
  }
  if !media_mac_is_candidate(player) {
    return Err(Unsupported)
  }
  if !media_mac_running(player) {
    return Err(NoPlayer)
  }
  match media_mac_as_args(player, c) {
    None => Err(Unsupported)
    Some(args) => media_mac_apply_osascript(args)
  }
}

///|
/// 探测 App 是否在运行：`pgrep -x <app>` 退出码 0 即在运行（pgrep 无
/// 匹配时退出 1，归为未运行；命令缺失或执行异常同样按未运行处理——探测
/// 失败时宁可不发命令）。
fn media_mac_running(app : String) -> Bool {
  match pr_run("pgrep", ["-x", app], timeout_ms=2000) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
/// 跑 osascript 并捕获标准输出（错误映射与 Linux 侧 [media_run_playerctl]
/// 对齐：127 = 命令缺失 → Unsupported，其余非零退出 → CommandFailed）。
fn media_mac_run_osascript(args : Array[String]) -> Result[String, MediaError] {
  match pr_run("osascript", args, timeout_ms=4000) {
    Ok(o) => Ok(o.stdout)
    Err(NonZeroExit(127, _)) => Err(Unsupported)
    Err(NonZeroExit(code, err)) =>
      Err(CommandFailed("osascript: 退出码 \{code}（\{media_first_line(err)}）"))
    Err(Timeout(m)) => Err(CommandFailed(m))
    Err(SpawnFailed(m)) => Err(CommandFailed(m))
    Err(Signaled(sig)) => Err(CommandFailed("osascript: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(Unsupported)
  }
}

///|
/// 跑 osascript 控制命令，只关心成败（有副作用：会改变播放器状态）。
fn media_mac_apply_osascript(args : Array[String]) -> Result[Unit, MediaError] {
  match media_mac_run_osascript(args) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

// ---------------------------------------------------------------------------
// 媒体状态监视（轮询 PlaybackStatus 与元数据的增量变化）
//
// 监视内部只调 [media_players] / [media_status] 这两个公开 API，故 macOS
// 上挂好这两个分支后 [media_watch_status] 自动可用，无需平台特化。
// ---------------------------------------------------------------------------

///|
/// 媒体状态监视句柄：句柄持定时器开关，停止后下一帧轮询回调返回 false
/// 即注销定时器。同一句柄可多处持有，任意一处 stop 即全局停。
pub(all) struct MediaWatcher {
  running : Ref[Bool]
}

///|
/// 建监视句柄（默认运行中；传给 media_watch_status 后即开始轮询）。
pub fn MediaWatcher::make() -> MediaWatcher {
  { running: Ref(true), }
}

///|
/// 句柄当前是否在监视（定时器存活）。
pub fn MediaWatcher::is_running(self : MediaWatcher) -> Bool {
  self.running.val
}

///|
/// 停止监视（下一帧轮询回调返回 false 即注销定时器）。停止不可恢复，
/// 恢复请用新句柄重新调用 media_watch_status。
pub fn media_watch_stop(w : MediaWatcher) -> Unit {
  w.running.val = false
}

///|
/// 两份状态快照是否有变化（播放态、标题、艺术家、专辑任一不同即变化）。
pub fn media_status_changed(old : MediaStatus, new : MediaStatus) -> Bool {
  old.playback.to_string() != new.playback.to_string() ||
  old.title != new.title ||
  old.artist != new.artist ||
  old.album != new.album
}

///|
/// 解析监视目标（player 非空即用；为空取当前首个播放器——Linux 取首个
/// MPRIS 实例总线名，macOS 取首个正在运行的候选 App 名）。
fn media_watch_resolve(player : String) -> String? {
  if player != "" {
    Some(player)
  } else {
    match media_players() {
      Ok(players) => if players.is_empty() { None } else { Some(players[0].name) }
      Err(_) => None
    }
  }
}

///|
/// 轮询监视某播放器（空 player 监视首个实例；interval_ms 轮询间隔，
/// 默认 1000ms）。播放态 / 标题 / 艺术家 / 专辑任一变化时触发
/// on_change（首次轮询不触发，只建立基线）。播放器未出现前每轮重试
/// 解析目标，出现后锁定。目标解析或查询失败的轮次静默跳过，不影响
/// 后续轮询。不需要监视时 media_watch_stop 停止句柄。
pub fn media_watch_status(
  player? : String = "",
  interval_ms? : Int = 1000,
  on_change : (MediaStatus) -> Unit,
) -> MediaWatcher {
  let w = MediaWatcher::make()
  let mut target : String? = None
  let mut last : MediaStatus? = None
  @yue.set_timer(interval_ms, fn() {
    if !w.running.val {
      false
    } else {
      if target is None {
        target = media_watch_resolve(player)
      }
      match target {
        None => ()
        Some(name) =>
          match media_status(name) {
            Err(_) => ()
            Ok(st) => {
              let changed = match last {
                None => false
                Some(prev) => media_status_changed(prev, st)
              }
              last = Some(st)
              if changed {
                on_change(st)
              }
            }
          }
      }
      true
    }
  })
  w
}
