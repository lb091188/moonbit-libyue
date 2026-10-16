// LRC 歌词解析（纯函数、无 IO）：与字幕层同口径——外部 `.lrc` 由调用方读好
// 喂进来，本层不碰磁盘。解出来的行复用字幕的 `Cue` 表，所以「按位置取当前行」
// 直接走 `subtitle_at`，两种文本在渲染侧同形。
//
// 吃得下的形态：`[mm:ss.xx]文本`、一行多个时间戳 `[00:12.00][01:30.00]副歌`、
// 头部元信息 `[ti:] [ar:] [al:] [by:] [offset:]`、增强 LRC 的行内
// `<mm:ss.xx>` 逐字标记（剥掉，只留文本）。
//
// `offset` 的符号各家播放器不一致，这里定死一条：**毫秒数加在所有时间戳上**，
// 正值=歌词整体延后出现。调用方要反向补偿就把值取负传进来。

///|
/// 最后一行歌词的结束时刻（开放到结尾，`subtitle_at` 的区间判据照旧成立）。
let lrc_open_end : Double = 1.0e18

///|
/// 一份歌词：按时间排好的行 + 头部元信息（缺失给空串）。
pub(all) struct Lrc {
  cues : Array[Cue]
  title : String
  artist : String
  album : String
  maker : String
}

///|
/// 带符号毫秒数（`offset` 的 `+500` / `-500` / `500` 三种写法都收）。
fn lrc_signed(s : String) -> Double {
  let t = s.trim().to_owned()
  let v = num_or_zero(t)
  if t.length() > 0 && t[0] == '-' { -v } else { v }
}

///|
/// 方括号内容分类，返回 `(是否时间戳, 元信息键, 元信息值)`：冒号前全是数字才算
/// 时间戳（`00:12.34`），出现字母就是键名（`ti:` / `offset:`）；没有冒号按秒数。
fn lrc_bracket(inner : String) -> (Bool, String, String) {
  let mut colon = -1
  for i = 0; i < inner.length(); i = i + 1 {
    if inner[i] == ':' {
      colon = i
      break
    }
  }
  if colon < 0 {
    // 没有冒号：`[12.34]` 这种纯秒数收，`[随手写的]` 这种非数字标记忽略
    let mut has_digit = false
    for ch in inner.iter() {
      if ch >= '0' && ch <= '9' {
        has_digit = true
      }
    }
    return (has_digit, "", "")
  }
  if colon == 0 {
    return (false, "", "")
  }
  let mut all_digits = true
  for i = 0; i < colon; i = i + 1 {
    let ch = inner[i]
    if ch < '0' || ch > '9' {
      all_digits = false
    }
  }
  if all_digits {
    (true, "", "")
  } else {
    let key = StringBuilder()
    for ch in inner[0:colon].iter() {
      key.write_char(
        if ch >= 'A' && ch <= 'Z' { (ch.to_int() + 32).unsafe_to_char() } else { ch },
      )
    }
    (false, key.to_string(), inner[colon + 1:].trim().to_owned())
  }
}

///|
/// 解析整份 LRC。时间轴**按开始时刻排好序**（LRC 不保证有序，一行多时间戳也会
/// 打乱出现顺序），每行的结束时刻取下一行的开始时刻，最后一行开放到结尾。
/// 只有时间戳没有文本的行（段落分隔）不进歌词表。
pub fn lrc_parse(raw : String) -> Lrc {
  let items : Array[(Double, String)] = []
  let mut title = ""
  let mut artist = ""
  let mut album = ""
  let mut maker = ""
  let mut offset_ms = 0.0
  for line in sp(raw, "\n") {
    let n = line.length()
    let mut pos = 0
    let times : Array[Double] = []
    while pos < n && line[pos] == '[' {
      let mut close = -1
      for i = pos + 1; i < n; i = i + 1 {
        if line[i] == ']' {
          close = i
          break
        }
      }
      if close < 0 {
        break
      }
      let inner = line[pos + 1:close].to_owned()
      let b = lrc_bracket(inner)
      if b.0 {
        times.push(srt_time(inner))
      } else {
        match b.1 {
          "ti" => title = b.2
          "ar" => artist = b.2
          "al" => album = b.2
          "by" => maker = b.2
          "offset" => offset_ms = lrc_signed(b.2)
          _ => ()
        }
      }
      pos = close + 1
    }
    if times.is_empty() {
      continue
    }
    let text = strip_cue_tags(line[pos:n].to_owned())
    if text.length() == 0 {
      continue
    }
    for t in times {
      let s = t + offset_ms / 1000.0
      items.push((if s < 0.0 { 0.0 } else { s }, text))
    }
  }
  // 插入排序：歌词近有序，几百行一次载入，代价可忽略
  for i = 1; i < items.length(); i = i + 1 {
    let cur = items[i]
    let mut j = i - 1
    while j >= 0 && items[j].0 > cur.0 {
      items[j + 1] = items[j]
      j = j - 1
    }
    items[j + 1] = cur
  }
  let cues : Array[Cue] = []
  for i = 0; i < items.length(); i = i + 1 {
    let end =
      if i + 1 < items.length() { items[i + 1].0 } else { lrc_open_end }
    cues.push({ start: items[i].0, end, text: items[i].1, })
  }
  { cues, title, artist, album, maker }
}

///|
/// 当前播放位置要显示的那行歌词（没有命中给空串）。判据是「开始时刻不晚于位置的
/// 最后一行」而不是区间命中——两行相接处若按 `[start, end]` 双闭区间查，
/// 边界那一瞬会同时命中上下两行、拼成两行字。
pub fn lrc_at(l : Lrc, t : Double) -> String {
  let mut out = ""
  for c in l.cues {
    if c.start <= t {
      out = c.text
    } else {
      break
    }
  }
  out
}
