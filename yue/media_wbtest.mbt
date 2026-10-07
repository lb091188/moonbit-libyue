// 媒体控制模块白盒测试：总线名过滤（ListNames 应答样例）、PlaybackStatus
// 文本映射、Metadata 的 xesam 字段提取（artist 的 as 数组与单字符串双
// 形态）、playerctl 参数构造与 --format 输出解析、真机只读冒烟
// （media_players / media_status，无会话总线或无播放器时跳过）。
// 播放控制属设置类操作，本文件不真实执行任何播放命令。

///|
/// 构造 ListNames 应答形态（as，混入总线自身名/非播放器代理名）。
fn media_test_names() -> @traybus.GDBusValue {
  @traybus.GVArray("s", [
    @traybus.GVString("org.freedesktop.DBus"),
    @traybus.GVString(":1.42"),
    @traybus.GVString("ca.desrt.confuse"),
    @traybus.GVString("org.mpris.MediaPlayer2.vlc"),
    @traybus.GVString("org.mpris.MediaPlayer2.playerctld"),
    @traybus.GVString("org.mpris.MediaPlayer2."),
  ])
}

///|
test "media_is_mpris_name：前缀过滤与空后缀拒绝" {
  assert_true(media_is_mpris_name("org.mpris.MediaPlayer2.vlc"))
  assert_true(media_is_mpris_name("org.mpris.MediaPlayer2.playerctld"))
  assert_true(
    media_is_mpris_name("org.mpris.MediaPlayer2.chromium.instance123"),
  )
  // 非 MPRIS 名字一律不收
  assert_true(!media_is_mpris_name("org.freedesktop.DBus"))
  assert_true(!media_is_mpris_name(":1.42"))
  assert_true(!media_is_mpris_name("org.mpris.MediaPlayer2")) // 缺尾点
  assert_true(!media_is_mpris_name("org.mpris.MediaPlayer2.")) // 空后缀
  assert_true(!media_is_mpris_name("org.mpris.MediaPlayer2X"))
  assert_true(!media_is_mpris_name(""))
}

///|
test "media_mpris_names：ListNames 应答过滤" {
  let names = media_mpris_names(media_test_names())
  inspect(names.length(), content="2")
  inspect(names[0], content="org.mpris.MediaPlayer2.vlc")
  inspect(names[1], content="org.mpris.MediaPlayer2.playerctld")
  // 非数组应答 → 空表（应答形态不符不当作"有播放器"）
  inspect(media_mpris_names(@traybus.GVNone).length(), content="0")
  inspect(
    media_mpris_names(@traybus.GVString("org.mpris.MediaPlayer2.vlc")).length(),
    content="0",
  )
}

///|
test "media_playback_of：PlaybackStatus 文本映射" {
  inspect(media_playback_of("Playing"), content="MediaPlaying")
  inspect(media_playback_of("Paused"), content="MediaPaused")
  inspect(media_playback_of("Stopped"), content="MediaStopped")
  // 容忍首尾空白（应答带换行）
  inspect(media_playback_of(" Playing\n"), content="MediaPlaying")
  // 自定义/未知状态原样保留（trim 后）
  inspect(
    media_playback_of("TrackChanged"),
    content="MediaUnknown(TrackChanged)",
  )
  inspect(media_playback_of(""), content="MediaUnknown()")
  inspect(media_playback_of("  playing  "), content="MediaUnknown(playing)")
}

///|
test "media_status_of：Metadata 的 xesam 字段提取" {
  // 规范形态：xesam:artist 是 as 数组（取首个），其余为字符串
  let meta : Map[String, @traybus.GDBusValue] = Map([])
  meta.set("mpris:trackid", @traybus.GVPath("/org/mpris/MediaPlayer2/track/0"))
  meta.set("mpris:length", @traybus.GVInt64(269000000L))
  meta.set("xesam:title", @traybus.GVString("晴天"))
  meta.set(
    "xesam:artist",
    @traybus.GVArray("s", [
      @traybus.GVString("周杰伦"),
      @traybus.GVString("费玉清"),
    ]),
  )
  meta.set("xesam:album", @traybus.GVString("叶惠美"))
  let st = media_status_of("org.mpris.MediaPlayer2.vlc", MediaPlaying, meta)
  inspect(st.player, content="org.mpris.MediaPlayer2.vlc")
  inspect(st.playback, content="MediaPlaying")
  inspect(st.title, content="晴天")
  inspect(st.artist, content="周杰伦")
  inspect(st.album, content="叶惠美")
  // artist 单字符串形态（个别播放器）也收
  let meta2 : Map[String, @traybus.GDBusValue] = Map([])
  meta2.set("xesam:artist", @traybus.GVString("陈奕迅"))
  let st2 = media_status_of("p2", MediaPaused, meta2)
  inspect(st2.artist, content="陈奕迅")
  // 字段缺失/类型不符 → 空串；空 artist 数组 → 空串
  let meta3 : Map[String, @traybus.GDBusValue] = Map([])
  meta3.set("xesam:artist", @traybus.GVArray("s", []))
  meta3.set("xesam:title", @traybus.GVInt32(0)) // 类型不符按缺失
  let st3 = media_status_of("p3", MediaStopped, meta3)
  inspect(st3.title, content="")
  inspect(st3.artist, content="")
  inspect(st3.album, content="")
}

///|
test "media_playerctl_sel / media_playerctl_parse_meta：命令回退纯逻辑" {
  // -p 选择参数：剥 MPRIS 前缀取实例名；非 MPRIS 形态原样
  inspect(media_playerctl_sel("org.mpris.MediaPlayer2.vlc"), content="vlc")
  inspect(
    media_playerctl_sel("org.mpris.MediaPlayer2.chromium.instance1"),
    content="chromium.instance1",
  )
  inspect(media_playerctl_sel("vlc"), content="vlc")
  // --format 输出按 US 字符切三段
  let (t1, a1, b1) = media_playerctl_parse_meta(
    "晴天\u{1f}周杰伦\u{1f}叶惠美\n",
  )
  inspect(t1, content="晴天")
  inspect(a1, content="周杰伦")
  inspect(b1, content="叶惠美")
  // 缺段补空串（不支持模板的播放器）
  let (t2, a2, b2) = media_playerctl_parse_meta("只有标题")
  assert_eq((t2, a2, b2), ("只有标题", "", ""))
  let (t3, a3, b3) = media_playerctl_parse_meta("")
  assert_eq((t3, a3, b3), ("", "", ""))
  // 空段保留（标题缺失但分隔符在）
  let (t4, a4, b4) = media_playerctl_parse_meta("\u{1f}歌手\u{1f}专辑")
  assert_eq((t4, a4, b4), ("", "歌手", "专辑"))
}

///|
test "media_playerctl_meta_args：参数表构造" {
  let args = media_playerctl_meta_args("vlc")
  inspect(args.length(), content="5")
  inspect(args[0], content="-p")
  inspect(args[1], content="vlc")
  inspect(args[2], content="metadata")
  inspect(args[3], content="--format")
  // 模板含三个 {{字段}} 占位与三个 US 分隔符 → 4 段
  let fmt = args[4]
  assert_true(fmt.contains("{{title}}"))
  assert_true(fmt.contains("{{artist}}"))
  assert_true(fmt.contains("{{album}}"))
  inspect(media_split_us(fmt).length(), content="4")
}

///|
test "media_mpris_method / media_playerctl_subcmd：命令名映射" {
  inspect(media_mpris_method(MediaCmdPlay), content="Play")
  inspect(media_mpris_method(MediaCmdPause), content="Pause")
  inspect(media_mpris_method(MediaCmdPlayPause), content="PlayPause")
  inspect(media_mpris_method(MediaCmdNext), content="Next")
  inspect(media_mpris_method(MediaCmdPrevious), content="Previous")
  inspect(media_mpris_method(MediaCmdStop), content="Stop")
  inspect(media_playerctl_subcmd(MediaCmdPlay), content="play")
  inspect(media_playerctl_subcmd(MediaCmdPause), content="pause")
  inspect(media_playerctl_subcmd(MediaCmdPlayPause), content="play-pause")
  inspect(media_playerctl_subcmd(MediaCmdNext), content="next")
  inspect(media_playerctl_subcmd(MediaCmdPrevious), content="previous")
  inspect(media_playerctl_subcmd(MediaCmdStop), content="stop")
}

///|
test "media 真机只读冒烟：players 与 status（无总线或无播放器跳过）" {
  if platform() != "linux" {
    println("media: skip (非 Linux)")
    return
  }
  println("media_supported: \{media_supported()}")
  match media_players() {
    Ok(players) =>
      for p in players {
        println("media player: \{p.identity} (\{p.name})")
        match media_status(p.name) {
          Ok(s) => println("media status: \{s}")
          Err(e) => println("media_status(\{p.name}) failed: \{e}")
        }
      }
    Err(NoPlayer) =>
      println("media: 无 MPRIS 播放器（等待播放器上线）")
    Err(Unsupported) => println("media: 平台不支持")
    Err(e) => println("media_players failed: \{e}")
  }
}

///|
test "media 错误路径：不存在的播放器给错误而非 Ok" {
  if platform() != "linux" {
    println("media: skip (非 Linux)")
    return
  }
  // 只读查询：ServiceUnknown（无此服务）与 playerctl 回退失败都应是
  // Err；不存在的实例名不可能读回 Ok
  match media_status("org.mpris.MediaPlayer2.__no_such_player__") {
    Ok(_) => fail("不存在的播放器不应读回 Ok")
    Err(e) => println("media_status(不存在实例) 预期错误: \{e}")
  }
  // media_players 在无播放器时给 NoPlayer，在有播放器时给 Ok，两者
  // 之外都 println 出来（由真机冒烟测试观察）
  match media_players() {
    Ok(ps) => println("players: \{ps.length()} 个")
    Err(e) => println("players err: \{e}")
  }
}
