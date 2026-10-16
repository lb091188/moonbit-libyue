///|
/// LRC 解析的无头回归：时间戳形态、一行多时间戳、排序、元信息、offset、
/// 增强 LRC 的行内逐字标记、无文本行、按位置取行。
test "LRC 解析：多时间戳行按时间排好、结束时刻接下一行" {
  let l = lrc_parse(
    "[00:20.00]第二句\n[00:10.00]第一句\n[00:15.00][00:45.00]副歌\n",
  )
  assert_eq(l.cues.length(), 4)
  assert_eq(l.cues[0].start, 10.0)
  assert_eq(l.cues[1].start, 15.0)
  assert_eq(l.cues[2].start, 20.0)
  assert_eq(l.cues[3].start, 45.0)
  assert_eq(l.cues[1].text, "副歌")
  assert_eq(l.cues[2].end, 45.0)
  assert_true(l.cues[3].end > 1.0e17)
}

///|
/// 元信息四键 + offset（正值=延后出现，负值把开头钳到 0）；CRLF 行尾不吃进文本。
test "LRC 元信息与 offset" {
  let l = lrc_parse(
    "[ti:稻香]\r\n[ar:周杰伦]\r\n[al:魔杰座]\r\n[by:某人]\r\n[offset:+500]\r\n[00:10.00]一句\r\n",
  )
  assert_eq(l.title, "稻香")
  assert_eq(l.artist, "周杰伦")
  assert_eq(l.album, "魔杰座")
  assert_eq(l.maker, "某人")
  assert_eq(l.cues.length(), 1)
  assert_eq(l.cues[0].start, 10.5)
  assert_eq(l.cues[0].text, "一句")
  let l2 = lrc_parse("[offset:-2000]\n[00:01.00]一句\n")
  assert_eq(l2.cues[0].start, 0.0)
}

///|
/// 增强 LRC 的行内 `<mm:ss.xx>` 只剥标记不留时间；只有时间戳没有文本的行不进表。
test "LRC 行内逐字标记与空文本行" {
  let l = lrc_parse(
    "[00:01.00]<00:01.00>一<00:01.50>句\n[00:05.00]\n[00:09.00]另一句\n[随手写的标记]不该进表\n",
  )
  assert_eq(l.cues.length(), 2)
  assert_eq(l.cues[0].text, "一句")
  assert_eq(l.cues[1].start, 9.0)
}

///|
/// 取行判据：未开始的段落给空，边界归下一行（不会上下两行同时命中）。
test "lrc_at 取当前行" {
  let l = lrc_parse("[00:10.00]第一句\n[00:20.00]第二句\n")
  assert_eq(lrc_at(l, 5.0), "")
  assert_eq(lrc_at(l, 10.0), "第一句")
  assert_eq(lrc_at(l, 19.9), "第一句")
  assert_eq(lrc_at(l, 20.0), "第二句")
  assert_eq(lrc_at(l, 9999.0), "第二句")
  assert_eq(lrc_at(lrc_parse(""), 1.0), "")
}
