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
