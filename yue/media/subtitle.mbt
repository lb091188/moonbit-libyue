// 字幕叠加（批 D）：SRT 与 WebVTT 共用的时间轴解析，纯函数、无 IO。
//
// 只做「读一份字幕文件 → 按当前播放位置给出要画的那几行」这一件事；
// 内嵌字幕轨（mov_text/ass）与样式渲染不在本批，理由记在 TODO。

///|
/// 一条字幕：起止秒 + 文本（多行已用 `\n` 连好）。
pub(all) struct Cue {
  start : Double
  end : Double
  text : String
}

///|
/// `String::split` 给的是迭代器（本工具链的形态），要按下标取就得先收成数组。
fn sp(s : String, sep : String) -> Array[String] {
  let out : Array[String] = []
  for v in s.split(sep) {
    out.push(v.to_owned())
  }
  out
}

///|
/// 手写字面量解析：只吃数字与一个小数点，认不出任何数字时给 0。
/// 不用 `to_double` 那类通用解析是因为字幕时间戳不会有指数、负号、千分位，
/// 少一处依赖就少一处「解析器版本不同行为不同」的变量。
fn num_or_zero(s : String) -> Double {
  let mut int_part = 0.0
  let mut frac = 0.0
  let mut scale = 1.0
  let mut seen_dot = false
  let mut digits = 0
  for ch in s.iter() {
    if ch == '.' && !seen_dot {
      seen_dot = true
    } else if ch >= '0' && ch <= '9' {
      let d = (ch.to_int() - 48).to_double()
      if seen_dot {
        scale = scale * 10.0
        frac = frac + d / scale
      } else {
        int_part = int_part * 10.0 + d
      }
      digits = digits + 1
    } else {
      ()
    }
  }
  if digits == 0 { 0.0 } else { int_part + frac }
}

///|
/// 字幕时间戳 → 秒。吃 `00:01:02,500`（SRT）与 `00:01:02.500`（VTT），
/// 也吃 `01:02.500`（分:秒.毫秒）；认不出来给 0（宁可早出也不整条丢）。
pub fn srt_time(s : String) -> Double {
  let t = s.trim().to_owned()
  let comma = sp(t, ",")
  let frac =
    if comma.length() > 1 {
      num_or_zero("0." + comma[1])
    } else {
      0.0
    }
  let segs : Array[Double] = []
  for q in sp(comma[0], ":") {
    segs.push(num_or_zero(q))
  }
  let mut acc = 0.0
  for v in segs {
    acc = acc * 60.0 + v
  }
  acc + frac
}

///|
fn is_timing_line(line : String) -> Bool {
  line.contains("-->")
}

///|
/// 去掉行内标记：VTT 的 `<c.yellow>…</c>`/`<v Name>:` 与 ASS 风格的 `{\an8}`，
/// 只留可读文本。
fn strip_cue_tags(s : String) -> String {
  let out = StringBuilder()
  let mut depth = 0
  let mut brace = false
  for ch in s.iter() {
    if ch == '<' {
      depth = depth + 1
    } else if ch == '>' {
      if depth > 0 {
        depth = depth - 1
      }
    } else if ch == '{' {
      brace = true
    } else if ch == '}' {
      brace = false
    } else if depth == 0 && !brace {
      out.write_char(ch)
    } else {
      ()
    }
  }
  out.to_string().trim().to_owned()
}

///|
/// 解析整份字幕文件（SRT / WebVTT 通吃：数字编号行、`WEBVTT` 头、`NOTE` 段都跳过）。
/// 时间轴按出现顺序返回，不做排序（合并两份文件才需要排序，那是调用方的事）。
pub fn subtitle_parse(raw : String) -> Array[Cue] {
  let cues : Array[Cue] = []
  let lines : Array[String] = []
  for l in sp(raw, "\n") {
    let kept = StringBuilder()
    for ch in l.iter() {
      if ch != '\r' {
        kept.write_char(ch)
      } else {
        ()
      }
    }
    lines.push(kept.to_string())
  }
  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    if is_timing_line(line) {
      let halves = sp(line, "-->")
      if halves.length() >= 2 {
        let start = srt_time(halves[0])
        // VTT 右端可以带位置设置（"00:00:05.000 align:start"），只取第一段
        // "-->" 右边常带空格与位置设置（" 00:00:05.000 align:start"）：先裁空白
        // 再按空格切、取第一个非空段，否则整条时间会被算成 0
        let right = sp(halves[1].trim().to_owned(), " ")
        let mut end = 0.0
        for r in right {
          if r.length() > 0 {
            end = srt_time(r)
            break
          }
        }
        let body : Array[String] = []
        let mut j = i + 1
        while j < lines.length() && lines[j].trim().length() > 0 && !is_timing_line(
          lines[j],
        ) {
          let txt = strip_cue_tags(lines[j])
          if txt.length() > 0 {
            body.push(txt)
          }
          j = j + 1
        }
        if body.length() > 0 {
          let mut text = ""
          for b in body {
            text = if text.length() == 0 { b } else { text + "\n" + b }
          }
          cues.push({ start, end, text })
        }
        i = j
        continue
      }
    }
    i = i + 1
  }
  cues
}

///|
/// 当前播放位置要画的字幕（多条命中就按行拼起来，与浏览器行为一致）。
pub fn subtitle_at(cues : Array[Cue], t : Double) -> String {
  let mut out = ""
  for c in cues {
    if t >= c.start && t <= c.end {
      out = if out.length() == 0 { c.text } else { out + "\n" + c.text }
    }
  }
  out
}
