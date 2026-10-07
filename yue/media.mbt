// 媒体控制（MPRIS / Windows SMTC 对标）：经会话总线 D-Bus 枚举
// org.mpris.MediaPlayer2.* 播放器实例，播放控制（play / pause /
// play_pause / next / previous / stop）与状态读取（PlaybackStatus +
// Metadata 的 title / artist / album）走 MPRIS Player 接口，总线调用
// 复用 @traybus 通用调用层的 gdbus_call_session / gdbus_get_property_session。
// playerctl 可用（--version 退出 0）时，总线调用失败的命令类操作回退
// 到 playerctl 子命令（pr helper，命令回退路径）。目前仅实现 Linux
// 路径，其余平台一律 Unsupported；播放控制属设置类操作，由调用方决定
// 何时执行，本模块不在探测中代为触发。总线名过滤、状态文本映射、
// Metadata 字段提取、playerctl 参数构造与输出解析均为纯函数（media_
// 前缀），media_wbtest.mbt 白盒覆盖。
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
  /// 平台/环境不支持（非 Linux；子进程执行不可用）
  Unsupported
  /// 会话总线上没有任何 MPRIS 播放器实例
  NoPlayer
  /// 总线调用失败（连不上/已断开｜应答超时｜服务不存在｜方法被拒），
  /// 带错误名与说明
  BusFailed(String)
  /// playerctl 回退命令失败，带原因
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
/// playerctl 可用（命令回退路径）。每次调用真实探测。
pub fn media_supported() -> Bool {
  if platform() != "linux" {
    return false
  }
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
/// 枚举会话总线上的 MPRIS 播放器实例（org.mpris.MediaPlayer2.*，含
/// playerctld 代理实例），保持 ListNames 应答序。非 Linux 给
/// [Unsupported]；总线不可用给 [BusFailed]；实例一个都没有给
/// [NoPlayer]（无播放器 ≠ 不可用，可稍后再试）。
pub fn media_players() -> Result[Array[MediaPlayerInfo], MediaError] {
  if platform() != "linux" {
    return Err(Unsupported)
  }
  match media_players_dbus() {
    Ok(players) => if players.is_empty() { Err(NoPlayer) } else { Ok(players) }
    Err(e) => Err(e)
  }
}

///|
/// 读某播放器的播放状态与当前曲目（title / artist / album）。总线路径
/// 失败且 playerctl 可用时回退 playerctl 只读查询；两种路径都失败给
/// 对应错误（总线错误名或 playerctl 退出原因）。
pub fn media_status(player : String) -> Result[MediaStatus, MediaError] {
  if platform() != "linux" {
    return Err(Unsupported)
  }
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
/// 播放控制公共实现：优先 MPRIS Player 方法（会话总线）；总线调用失败
/// 且 playerctl 可用时回退 playerctl 子命令。属设置类操作，只在调用
/// 方显式调用时执行，探测与查询路径不会触发。
fn media_control(player : String, c : MediaCmd) -> Result[Unit, MediaError] {
  if platform() != "linux" {
    return Err(Unsupported)
  }
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
/// 停止播放（MPRIS Player.Stop；playerctl stop 回退）。
pub fn media_stop(player : String) -> Result[Unit, MediaError] {
  media_control(player, MediaCmdStop)
}
