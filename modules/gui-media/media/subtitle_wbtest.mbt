// 字幕解析的无头回归：时间戳两种写法、SRT/VTT 通吃、行内标记剥离、
// 命中查询的边界（起点含、终点含、多条拼接）。

///|
test "时间戳：SRT 逗号与 VTT 点号、分秒两段都吃" {
  assert_eq(srt_time("00:00:00,000"), 0.0)
  assert_eq(srt_time("00:01:02,500"), 62.5)
  assert_eq(srt_time("00:01:02.500"), 62.5)
  assert_eq(srt_time("01:02.500"), 62.5)
  assert_eq(srt_time(" 00:00:05.125 "), 5.125)
  assert_eq(srt_time("乱码"), 0.0)
}

///|
test "SRT 解析：编号行与空行分隔，多行文本合成一条" {
  let s =
    "1\n00:00:01,000 --> 00:00:04,000\n第一行\n第二行\n\n2\n00:00:05,000 --> 00:00:06,000\n只有这一句\n"
  let cues = subtitle_parse(s)
  assert_eq(cues.length(), 2)
  assert_eq(cues[0].start, 1.0)
  assert_eq(cues[0].end, 4.0)
  assert_eq(cues[0].text, "第一行\n第二行")
  assert_eq(cues[1].text, "只有这一句")
}

///|
test "VTT 解析：跳头、剥标记、右端的位置设置不影响时间" {
  let s =
    "WEBVTT\n\n00:00:01.000 --> 00:00:03.000 align:start position:10%\n<c.yellow>黄字</c>正文\n\n" +
    "NOTE 这段是注释\n\n00:00:04.000 --> 00:00:05.000\n{\\an8}顶部对齐的一句\n"
  let cues = subtitle_parse(s)
  assert_eq(cues.length(), 2)
  assert_eq(cues[0].text, "黄字正文")
  assert_eq(cues[1].text, "顶部对齐的一句")
}

///|
test "命中查询：起止都含、无命中给空、多条命中按行拼" {
  let cues = subtitle_parse(
    "1\n00:00:01,000 --> 00:00:02,000\n甲\n\n2\n00:00:02,000 --> 00:00:03,000\n乙\n",
  )
  assert_eq(subtitle_at(cues, 0.5), "")
  assert_eq(subtitle_at(cues, 1.0), "甲")
  assert_eq(subtitle_at(cues, 2.0), "甲\n乙")
  assert_eq(subtitle_at(cues, 2.5), "乙")
  assert_eq(subtitle_at(cues, 9.0), "")
  assert_eq(subtitle_at([], 1.0), "")
}

///|
/// 内嵌轨搬运：字段对齐、排版标记与外部字幕同一条清洗路（`{\an8}`、`<c.xxx>` 剥掉）。
test "内嵌轨转 Cue：搬运并对齐外部字幕的清洗口径" {
  let cues = subtitle_from_embedded([
    { start_s: 1.0, end_s: 2.5, text: "{\\an8}<i>斜体一行</i>", },
    { start_s: 3.0, end_s: 4.0, text: "第二行", },
  ])
  assert_eq(cues.length(), 2)
  assert_eq(cues[0].start, 1.0)
  assert_eq(cues[0].end, 2.5)
  assert_eq(cues[0].text, "斜体一行")
  assert_eq(cues[1].text, "第二行")
  assert_eq(subtitle_from_embedded([]).length(), 0)
}

///|
/// 端到端（无头，不开窗口）：真容器 `av_1s_subs.mp4` 的内嵌 mov_text 轨解出来
/// 转成本层 Cue，再按位置查——0.3s 命中第一条、0.9s 不命中。这条钉的是
/// 「解码器 → 搬运 → 查表」整条链，任何一环字段错位都会在这里露出来。
test "内嵌字幕端到端：解码转 Cue 后按位置命中" {
  let path = "modules/ffmpeg-mbt/src/testdata/av_1s_subs.mp4"
  let cues = match @ffmbt.subtitle_cues(path) {
    Err(e) => fail("内嵌字幕读取失败：\{e}")
    Ok(list) => subtitle_from_embedded(list)
  }
  assert_eq(cues.length(), 2)
  // 时间轴按包时长落回素材本意（0.2..0.6 / 0.6..1.0），不是解码器那个恒 2 秒的默认值
  assert_true(cues[0].end > 0.55 && cues[0].end < 0.65)
  assert_true(cues[1].end > 0.95)
  assert_eq(subtitle_at(cues, 0.3), "第一条字幕")
  assert_eq(subtitle_at(cues, 0.7), "第二条带标记")
  assert_eq(subtitle_at(cues, 1.2), "")
}
