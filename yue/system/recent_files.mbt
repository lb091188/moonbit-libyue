// GTK 通用最近文件（只读）：解析 freedesktop 的 recently-used.xbel
// （GTK 应用经 GtkRecentManager / xdg-desktop-portal-gtk 统一写这份清单，
// Thunar / Nautilus / GIO 等打开文件都会往里追加）。
//   - rf_supported  本机是否可读（Linux 且文件可读）
//   - rf_recent     最近文件列表（modified 倒序，可限量）
//   - rf_by_app     按应用名过滤的最近文件列表
// 文件位置：$XDG_DATA_HOME/recently-used.xbel（缺省 $HOME/.local/share/）。
// XML 解析为手写薄扫描器：只取 bookmark 节点与 bookmark:application /
// mime:mime-type 子节点属性，属性值做 XML 实体解码，href 的 file:// URI
// 做百分号解码；时间戳 ISO 8601 → Unix 毫秒。解析 / 解码 / 排序均为
// 纯函数，recent_files_wbtest.mbt 白盒覆盖。

///|
/// 一条最近文件记录（recently-used.xbel 的一个 bookmark 节点）。
pub(all) struct RecentItem {
  /// bookmark href 原文（通常为 file:// URI）
  uri : String
  /// 本地路径：href 去掉 file:// 前缀并做百分号解码；非 file:// 方案给空串
  path : String
  /// MIME 类型（mime:mime-type 的 type 属性；该 bookmark 无此节点给 None）
  mime : String?
  /// 首次加入时间（Unix 毫秒；added 缺失或非法为 0）
  added : Int64
  /// 最近修改时间（Unix 毫秒；modified 缺失或非法为 0）
  modified : Int64
  /// 记录过该文件的应用个数（bookmark:application 节点数）
  app_count : Int
}

///|
pub impl Show for RecentItem with fn output(self, logger) {
  logger.write_string("RecentItem { uri: ")
  logger.write_string(self.uri)
  logger.write_string(", path: ")
  logger.write_string(self.path)
  logger.write_string(", mime: ")
  match self.mime {
    Some(m) => logger.write_string(m)
    None => logger.write_string("<无>")
  }
  logger.write_string(", added: ")
  logger.write_string(self.added.to_string())
  logger.write_string(", modified: ")
  logger.write_string(self.modified.to_string())
  logger.write_string(", app_count: ")
  logger.write_string(self.app_count.to_string())
  logger.write_string(" }")
}

///|
pub extend RecentItem with Show::{to_string, output}

///|
/// 最近文件查询失败原因。
pub(all) enum RecentError {
  /// 平台不支持（recently-used.xbel 是 Linux/GTK 侧的数据）
  RfUnsupported
  /// 定位数据目录失败（XDG_DATA_HOME 与 HOME 均不可用）
  RfNoDataDir
  /// recently-used.xbel 不存在或不可读（从未记录过最近文件）
  RfNoFile
  /// XML 解析失败，带原因
  RfParseFailed(String)
}

///|
pub impl Show for RecentError with fn output(self, logger) {
  match self {
    RfUnsupported => logger.write_string("RecentError::RfUnsupported")
    RfNoDataDir => logger.write_string("RecentError::RfNoDataDir")
    RfNoFile => logger.write_string("RecentError::RfNoFile")
    RfParseFailed(m) => logger.write_string("RecentError::RfParseFailed(\{m})")
  }
}

///|
pub extend RecentError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层：XML 实体解码 / XBEL 扫描 / URI 百分号解码 / ISO 8601 换算 /
// 排序截断（recent_files_wbtest.mbt 白盒覆盖）
// ---------------------------------------------------------------------------

///|
/// 码点拾取：取 s[i] 处码点，代理对合并为一个码点，返回 (码点, 消耗码元数)。
fn rf_char_at(s : String, i : Int) -> (Char, Int) {
  let c = s.unsafe_get(i).to_int()
  if c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length() {
    let lo = s.unsafe_get(i + 1).to_int()
    if lo >= 0xDC00 && lo <= 0xDFFF {
      return (
        (0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00)).unsafe_to_char(),
        2,
      )
    }
  }
  (c.unsafe_to_char(), 1)
}

///|
/// 码元 → 数值（越界给 -1）。
fn rf_at(s : String, i : Int) -> Int {
  if i >= 0 && i < s.length() {
    s.unsafe_get(i).to_int()
  } else {
    -1
  }
}

///|
/// 空白码元（空格 / 制表 / 换行 / 回车）。
fn rf_is_ws(c : Int) -> Bool {
  c == 32 || c == 9 || c == 10 || c == 13
}

///|
/// XML 标签名 / 属性名可用字符：字母、数字与 _ - : . 五种符号。
fn rf_is_name_char(c : Int) -> Bool {
  (c >= 97 && c <= 122) ||
  (c >= 65 && c <= 90) ||
  (c >= 48 && c <= 57) ||
  c == 95 ||
  c == 45 ||
  c == 58 ||
  c == 46
}

///|
/// 从 i 起逐码元比对文本（全中给 true；用于 "-->"/"?>" 等短串匹配）。
fn rf_match(s : String, i : Int, word : String) -> Bool {
  let n = s.length()
  let mut k = 0
  while k < word.length() {
    if i + k >= n || s.unsafe_get(i + k).to_int() != word.unsafe_get(k).to_int() {
      return false
    }
    k = k + 1
  }
  true
}

///|
/// 十六进制码元 → 数值（大小写均可；非十六进制给 None）。
fn rf_hex_val(c : Int) -> Int? {
  if c >= 48 && c <= 57 {
    Some(c - 48)
  } else if c >= 97 && c <= 102 {
    Some(c - 87)
  } else if c >= 65 && c <= 70 {
    Some(c - 55)
  } else {
    None
  }
}

///|
/// XML 实体解码：命名实体（&amp; &lt; &gt; &apos; &quot;）与字符引用
/// （&#NN; / &#xHH;，码点越界或代理值不收录）；未知实体名、缺 ';'
/// 按字面原文保留。
pub fn rf_xml_unescape(s : String) -> String {
  let sb = StringBuilder()
  let n = s.length()
  let mut i = 0
  while i < n {
    if s.unsafe_get(i).to_int() == 38 {
      // '&'
      match rf_entity_at(s, i) {
        Some((text, len)) => {
          sb.write_string(text)
          i = i + len
        }
        None => {
          sb.write_char('&')
          i = i + 1
        }
      }
    } else {
      let (cp, step) = rf_char_at(s, i)
      sb.write_char(cp)
      i = i + step
    }
  }
  sb.to_string()
}

///|
/// 从 s[i]（'&' 码元）起解一个 XML 实体：成功给 (解码文本, 消耗码元数)；
/// 未知实体名、坏字符引用或缺 ';' 给 None（调用方按字面 '&' 放行）。
fn rf_entity_at(s : String, i : Int) -> (String, Int)? {
  let n = s.length()
  let j0 = i + 1
  if j0 < n && s.unsafe_get(j0).to_int() == 35 {
    // '#'：字符引用 &#NN; / &#xHH;
    let hex = j0 + 1 < n &&
      (
        s.unsafe_get(j0 + 1).to_int() == 120 ||
        s.unsafe_get(j0 + 1).to_int() == 88
      )
    let mut k = if hex { j0 + 2 } else { j0 + 1 }
    let mut cp = 0
    let mut digits = 0
    while k < n && digits < 7 {
      let c = s.unsafe_get(k).to_int()
      if c == 59 {
        // ';'
        break
      }
      let v = if hex {
        rf_hex_val(c)
      } else if c >= 48 && c <= 57 {
        Some(c - 48)
      } else {
        None
      }
      match v {
        None => return None
        Some(d) => {
          cp = cp * (if hex { 16 } else { 10 }) + d
          k = k + 1
          digits = digits + 1
        }
      }
    }
    if digits == 0 || k >= n || s.unsafe_get(k).to_int() != 59 {
      return None
    }
    if cp <= 0 || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) {
      return None
    }
    let cs = StringBuilder()
    cs.write_char(cp.unsafe_to_char())
    Some((cs.to_string(), k + 1 - i))
  } else {
    // 命名实体：实体名最多 4 字符（&quot;），留 1 位余量
    let mut k = j0
    let sb = StringBuilder()
    let mut cnt = 0
    while k < n && cnt < 6 {
      let c = s.unsafe_get(k).to_int()
      if c == 59 {
        break
      }
      sb.write_char(c.unsafe_to_char())
      k = k + 1
      cnt = cnt + 1
    }
    if k >= n || s.unsafe_get(k).to_int() != 59 {
      return None
    }
    match sb.to_string() {
      "amp" => Some(("&", k + 1 - i))
      "lt" => Some(("<", k + 1 - i))
      "gt" => Some((">", k + 1 - i))
      "apos" => Some(("'", k + 1 - i))
      "quot" => Some(("\"", k + 1 - i))
      _ => None
    }
  }
}

///|
/// URI 百分号解码：%XX 段按 UTF-8 组合解码（连续 %XX 合成一个多字节字符），
/// 其余字符原样；% 后不是两位十六进制时按字面 '%' 保留。
pub fn rf_percent_decode(s : String) -> String {
  let sb = StringBuilder()
  let pending : Array[Byte] = []
  let n = s.length()
  let mut i = 0
  while i < n {
    match rf_hex_byte_at(s, i) {
      Some(b) => {
        pending.push(b.to_byte())
        i = i + 3
      }
      None => {
        rf_flush_pending(sb, pending)
        let (cp, step) = rf_char_at(s, i)
        sb.write_char(cp)
        i = i + step
      }
    }
  }
  rf_flush_pending(sb, pending)
  sb.to_string()
}

///|
/// s[i] 处 "%XX" → 字节值（% 缺失或两位非十六进制给 None）。
fn rf_hex_byte_at(s : String, i : Int) -> Int? {
  if i + 2 >= s.length() || s.unsafe_get(i).to_int() != 37 {
    // '%'
    return None
  }
  match rf_hex_val(s.unsafe_get(i + 1).to_int()) {
    None => None
    Some(hi) =>
      match rf_hex_val(s.unsafe_get(i + 2).to_int()) {
        None => None
        Some(lo) => Some(hi * 16 + lo)
      }
  }
}

///|
/// 把累积的 %XX 字节按 UTF-8 解码刷入 sb（空则无操作；用后清空）。
fn rf_flush_pending(sb : StringBuilder, pending : Array[Byte]) -> Unit {
  if pending.length() == 0 {
    return
  }
  sb.write_string(@utf8.decode_lossy(Bytes::from_array(pending)))
  pending.clear()
}

///|
/// href → 本地路径：file:///path 直取百分号解码后的路径；file://host/path
/// 还原为 //host/path；非 file:// 方案给 None。
pub fn rf_uri_to_path(uri : String) -> String? {
  if !uri.has_prefix("file://") {
    return None
  }
  let n = uri.length()
  let mut i = 7
  let authority = if i < n && uri.unsafe_get(i).to_int() != 47 {
    // '/'
    let start = i
    while i < n && uri.unsafe_get(i).to_int() != 47 {
      i = i + 1
    }
    rf_percent_decode(rf_substring(uri, start, i))
  } else {
    ""
  }
  let path = rf_percent_decode(rf_substring(uri, i, n))
  Some(if authority != "" { "//" + authority + path } else { path })
}

///|
/// 取子串 [start, end)（码元区间，按码点复制）。
fn rf_substring(s : String, start : Int, end : Int) -> String {
  let sb = StringBuilder()
  let mut i = start
  while i < end {
    let (cp, step) = rf_char_at(s, i)
    sb.write_char(cp)
    i = i + step
  }
  sb.to_string()
}

///|
/// 闰年判定（4 年一闰、百年不闰、四百年再闰）。
fn rf_is_leap(y : Int) -> Bool {
  (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
}

///|
/// 月份天数（按闰年实算；月份越界给 None）。
fn rf_days_in_month(y : Int, m : Int) -> Int? {
  match m {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => Some(31)
    4 | 6 | 9 | 11 => Some(30)
    2 => Some(if rf_is_leap(y) { 29 } else { 28 })
    _ => None
  }
}

///|
/// 公历日期 → 距 1970-01-01 的天数（Hinnant days_from_civil 标准算法）。
pub fn rf_days_from_civil(y : Int, m : Int, d : Int) -> Int {
  let yy = if m <= 2 { y - 1 } else { y }
  let era = (if yy >= 0 { yy } else { yy - 399 }) / 400
  let yoe = yy - era * 400
  let mp = if m > 2 { m - 3 } else { m + 9 }
  let doy = (153 * mp + 2) / 5 + d - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

///|
/// ISO 8601 时间戳 → Unix 毫秒：XBEL 形如
/// "2026-04-21T07:40:38.510353Z"，支持小数秒（毫秒去尾）与
/// "+HH:MM"/"-HH:MM" 时区偏移（无偏移按 UTC）；日期时间按阳历来算
/// （含闰年、闰日校验），任一段非法给 None。
pub fn rf_iso_to_unix_ms(text : String) -> Int64? {
  let y = match rf_num(text, 0, 4) {
    Some(v) => v
    None => return None
  }
  if rf_at(text, 4) != 45 {
    // '-'
    return None
  }
  let mo = match rf_num(text, 5, 2) {
    Some(v) => v
    None => return None
  }
  if rf_at(text, 7) != 45 {
    return None
  }
  let d = match rf_num(text, 8, 2) {
    Some(v) => v
    None => return None
  }
  let sep = rf_at(text, 10)
  if sep != 84 && sep != 32 {
    // 'T' 或空格
    return None
  }
  let h = match rf_num(text, 11, 2) {
    Some(v) => v
    None => return None
  }
  if rf_at(text, 13) != 58 {
    // ':'
    return None
  }
  let mi = match rf_num(text, 14, 2) {
    Some(v) => v
    None => return None
  }
  if rf_at(text, 16) != 58 {
    return None
  }
  let s = match rf_num(text, 17, 2) {
    Some(v) => v
    None => return None
  }
  let dim = match rf_days_in_month(y, mo) {
    Some(v) if d >= 1 && d <= v => v
    _ => return None
  }
  if h > 23 || mi > 59 || s > 60 || dim <= 0 {
    return None
  }
  // 小数秒：取前三位（毫秒），其余位跳过
  let mut i = 19
  let mut ms = 0L
  if rf_at(text, i) == 46 {
    // '.'
    i = i + 1
    let mut scale = 100L
    let mut cnt = 0
    while cnt < 3 {
      let c = rf_at(text, i)
      if c < 48 || c > 57 {
        break
      }
      ms = ms + (c - 48).to_int64() * scale
      scale = scale / 10L
      i = i + 1
      cnt = cnt + 1
    }
    while true {
      let c = rf_at(text, i)
      if c < 48 || c > 57 {
        break
      }
      i = i + 1
    }
  }
  // 时区后缀：'Z' / 'z' / '+HH:MM' / '-HH:MM' / 缺省 UTC
  let mut offset_secs = 0
  let tz = rf_at(text, i)
  if tz == 90 || tz == 122 {
    i = i + 1
  } else if tz == 43 || tz == 45 {
    let sign = if tz == 43 { 1 } else { -1 }
    let oh = match rf_num(text, i + 1, 2) {
      Some(v) => v
      None => return None
    }
    if rf_at(text, i + 3) != 58 {
      return None
    }
    let om = match rf_num(text, i + 4, 2) {
      Some(v) => v
      None => return None
    }
    if oh > 23 || om > 59 {
      return None
    }
    offset_secs = sign * (oh * 3600 + om * 60)
    i = i + 6
  }
  let days = rf_days_from_civil(y, mo, d)
  let secs = days.to_int64() * 86400L +
    h.to_int64() * 3600L +
    mi.to_int64() * 60L +
    s.to_int64() -
    offset_secs.to_int64()
  Some(secs * 1000L + ms)
}

///|
/// 从 i 起读恰好 len 位十进制数字（不足位或含非数字给 None）。
fn rf_num(s : String, i : Int, len : Int) -> Int? {
  if i < 0 || i + len > s.length() {
    return None
  }
  let mut v = 0
  for k in 0..<len {
    let c = s.unsafe_get(i + k).to_int()
    if c < 48 || c > 57 {
      return None
    }
    v = v * 10 + (c - 48)
  }
  Some(v)
}

// ---------------------------------------------------------------------------
// XBEL 扫描（bookmark 节点 + bookmark:application / mime:mime-type 子节点）
// ---------------------------------------------------------------------------

///|
/// 解析中的 bookmark：bookmark:application 与 mime:mime-type 在闭合前
/// 陆续回填到当前条目上。
priv struct RfEntry {
  uri : String
  mut mime : String?
  added : Int64
  modified : Int64
  apps : Array[String]
}

///|
/// 扫描器状态（XBEL 文本 + 码元游标）。
priv struct RfScanner {
  text : String
  mut pos : Int
}

///|
/// 当前码元（越界 -1）。
fn RfScanner::peek(self : RfScanner) -> Int {
  rf_at(self.text, self.pos)
}

///|
/// 读标签名 / 属性名（名称字符开头才收，空则 None 且不消耗）。
fn RfScanner::read_name(self : RfScanner) -> String? {
  let n = self.text.length()
  let sb = StringBuilder()
  let mut cnt = 0
  while self.pos < n && rf_is_name_char(self.text.unsafe_get(self.pos).to_int()) {
    let (cp, step) = rf_char_at(self.text, self.pos)
    sb.write_char(cp)
    self.pos = self.pos + step
    cnt = cnt + step
  }
  if cnt == 0 {
    None
  } else {
    Some(sb.to_string())
  }
}

///|
/// 读标签属性表（当前位置在标签名之后）：扫到 '>' 结束，返回
/// (属性对, 是否自闭合)。值必须引号包裹（单双均可），引号内的 '>' 与
/// 另一引号不截断；值做 XML 实体解码。属性缺 '=' 或缺引号整体跳过；
/// 文本在 '>' 前截断时按已读部分返回。
fn RfScanner::read_attrs(self : RfScanner) -> (Array[(String, String)], Bool) {
  let attrs : Array[(String, String)] = []
  let text = self.text
  let n = text.length()
  let mut done = false
  let mut closed = false
  while !done {
    while self.pos < n && rf_is_ws(text.unsafe_get(self.pos).to_int()) {
      self.pos = self.pos + 1
    }
    if self.pos >= n {
      done = true
    } else {
      let c = text.unsafe_get(self.pos).to_int()
      if c == 62 {
        // '>'
        self.pos = self.pos + 1
        done = true
      } else if c == 47 &&
        self.pos + 1 < n &&
        text.unsafe_get(self.pos + 1).to_int() == 62 {
        // '/>'
        self.pos = self.pos + 2
        done = true
        closed = true
      } else {
        match self.read_name() {
          None =>
            // 非属性名起始：跳过一码元继续（容错）
            self.pos = self.pos + 1
          Some(name) => {
            let mut vpos = self.pos
            while vpos < n && rf_is_ws(text.unsafe_get(vpos).to_int()) {
              vpos = vpos + 1
            }
            if vpos < n && text.unsafe_get(vpos).to_int() == 61 {
              // '='
              vpos = vpos + 1
              while vpos < n && rf_is_ws(text.unsafe_get(vpos).to_int()) {
                vpos = vpos + 1
              }
              if vpos < n {
                let q = text.unsafe_get(vpos).to_int()
                if q == 34 || q == 39 {
                  // '"' 或 '\''
                  vpos = vpos + 1
                  let sb = StringBuilder()
                  while vpos < n {
                    let ch = text.unsafe_get(vpos).to_int()
                    if ch == q {
                      break
                    }
                    sb.write_char(ch.unsafe_to_char())
                    vpos = vpos + 1
                  }
                  if vpos < n {
                    vpos = vpos + 1
                  }
                  self.pos = vpos
                  attrs.push((name, rf_xml_unescape(sb.to_string())))
                }
                // 值无引号：属性名已消耗，值丢弃
              }
            }
            // 无 '=' 的裸名称：不收录，游标停在名后继续
          }
        }
      }
    }
  }
  (attrs, closed)
}

///|
/// 跳到 '>' 之后（结束标签收尾用）。
fn RfScanner::skip_gt(self : RfScanner) -> Unit {
  let n = self.text.length()
  let mut j = self.pos
  while j < n {
    if self.text.unsafe_get(j).to_int() == 62 {
      self.pos = j + 1
      return
    }
    j = j + 1
  }
  self.pos = n
}

///|
/// 跳过 <! 之后的声明：注释（<!--）跳到 "-->" 之后，DOCTYPE / CDATA 等
/// 跳到 '>' 之后；找不到结束记号就到文本尾。
fn RfScanner::skip_declaration(self : RfScanner) -> Unit {
  let text = self.text
  let n = text.length()
  if rf_match(text, self.pos, "--") {
    let mut j = self.pos + 2
    while j + 3 <= n {
      if text.unsafe_get(j).to_int() == 45 &&
        text.unsafe_get(j + 1).to_int() == 45 &&
        text.unsafe_get(j + 2).to_int() == 62 {
        self.pos = j + 3
        return
      }
      j = j + 1
    }
    self.pos = n
    return
  }
  self.skip_gt()
}

///|
/// 跳过处理指令：跳到 "?>" 之后（<?xml ... ?> 声明用），找不到就到文本尾。
fn RfScanner::skip_pi(self : RfScanner) -> Unit {
  let text = self.text
  let n = text.length()
  let mut j = self.pos
  while j + 2 <= n {
    if text.unsafe_get(j).to_int() == 63 &&
      text.unsafe_get(j + 1).to_int() == 62 {
      self.pos = j + 2
      return
    }
    j = j + 1
  }
  self.pos = n
}

///|
/// 定位 <xbel 根起始标签位置（'<' 的下标）：按 '<' + "xbel" + 空白/'>'/'/'
/// 匹配；找不到给 None（不是 XBEL 文档）。
fn rf_find_root(xml : String) -> Int? {
  let n = xml.length()
  let mut i = 0
  while i < n {
    if xml.unsafe_get(i).to_int() == 60 && rf_match(xml, i + 1, "xbel") {
      // '<'
      let after = rf_at(xml, i + 5)
      if rf_is_ws(after) || after == 62 || after == 47 {
        return Some(i)
      }
    }
    i = i + 1
  }
  None
}

///|
/// 属性表按键取值（同名取首个；不存在给 None）。
fn rf_attr(attrs : Array[(String, String)], key : String) -> String? {
  for pair in attrs {
    if pair.0 == key {
      return Some(pair.1)
    }
  }
  None
}

///|
/// bookmark 起始标签属性 → 解析条目：href 缺失或空给 None（无从定位
/// 文件，整条跳过）；added / modified 缺失或非法按 0。
fn rf_entry_of(attrs : Array[(String, String)]) -> RfEntry? {
  let href = match rf_attr(attrs, "href") {
    Some(h) if h != "" => h
    _ => return None
  }
  Some({
    uri: href,
    mime: None,
    added: rf_time_of(attrs, "added"),
    modified: rf_time_of(attrs, "modified"),
    apps: [],
  })
}

///|
/// 属性表的 ISO 8601 时间 → Unix 毫秒（缺失或非法按 0）。
fn rf_time_of(attrs : Array[(String, String)], key : String) -> Int64 {
  match rf_attr(attrs, key) {
    Some(t) =>
      match rf_iso_to_unix_ms(t) {
        Some(ms) => ms
        None => 0L
      }
    None => 0L
  }
}

///|
/// 解析 XBEL 文本 → bookmark 条目（文档顺序）：无 <xbel> 根给 Err；
/// 其余一律容错——注释/处理指令/DOCTYPE 跳过，属性乱序、单双引号、
/// 自闭合、缺属性均收，未闭合的 bookmark 不收（截断写入的场景）。
fn rf_parse_xbel(xml : String) -> Result[Array[RfEntry], String] {
  match rf_find_root(xml) {
    None => Err("无 <xbel> 根节点，不是 XBEL 文档")
    Some(start) => {
      let sc : RfScanner = { text: xml, pos: start, }
      let out : Array[RfEntry] = []
      let mut cur : RfEntry? = None
      while sc.pos < xml.length() {
        if sc.peek() != 60 {
          // '<'
          sc.pos = sc.pos + 1
          continue
        }
        let next = rf_at(xml, sc.pos + 1)
        if next == 33 {
          // '!'
          sc.pos = sc.pos + 2
          sc.skip_declaration()
        } else if next == 63 {
          // '?'
          sc.pos = sc.pos + 2
          sc.skip_pi()
        } else if next == 47 {
          // '/' 结束标签
          sc.pos = sc.pos + 2
          if sc.read_name() == Some("bookmark") {
            match cur {
              Some(entry) => {
                out.push(entry)
                cur = None
              }
              None => ()
            }
          }
          sc.skip_gt()
        } else {
          sc.pos = sc.pos + 1
          match sc.read_name() {
            None => () // '<' 后无名：游标已过 '<'，外层循环继续
            Some(name) => {
              let (attrs, closed) = sc.read_attrs()
              if name == "bookmark" {
                cur = rf_entry_of(attrs)
                if closed {
                  // 自闭合 bookmark（无 info 子节点）：立即成条
                  match cur {
                    Some(entry) => {
                      out.push(entry)
                      cur = None
                    }
                    None => ()
                  }
                }
              } else if name == "bookmark:application" {
                match rf_attr(attrs, "name") {
                  Some(app) =>
                    match cur {
                      Some(entry) => entry.apps.push(app)
                      None => ()
                    }
                  None => ()
                }
              } else if name == "mime:mime-type" {
                match rf_attr(attrs, "type") {
                  Some(t) =>
                    match cur {
                      Some(entry) if entry.mime is None => entry.mime = Some(t)
                      _ => ()
                    }
                  None => ()
                }
              }
            }
          }
        }
      }
      Ok(out)
    }
  }
}

///|
/// 解析条目 → 公开记录（href 转本地路径、应用计数）。
fn rf_win_abs_path(s : String) -> Bool {
  if s.has_prefix("\\\\") {
    return true // UNC
  }
  let n = s.length()
  if n < 3 {
    return false
  }
  let c0 = s.unsafe_get(0).to_int()
  let is_drive = (c0 >= 65 && c0 <= 90) || (c0 >= 97 && c0 <= 122)
  is_drive && s.unsafe_get(1).to_int() == 58 &&
  (s.unsafe_get(2).to_int() == 92 || s.unsafe_get(2).to_int() == 47)
}

fn rf_entry_to_item(e : RfEntry) -> RecentItem {
  // Windows 装载器的 uri 就是 .lnk 目标本体（裸路径），非 file:// 形式；
  // 只把「绝对路径形态」的 uri 直接当 path，URL 形态（http 等）仍留空
  let path = match rf_uri_to_path(e.uri) {
    Some(p) => p
    None =>
      if @yue.platform() == "windows" && rf_win_abs_path(e.uri) {
        e.uri
      } else {
        ""
      }
  }
  {
    uri: e.uri,
    path,
    mime: e.mime,
    added: e.added,
    modified: e.modified,
    app_count: e.apps.length(),
  }
}

///|
/// 按应用名过滤解析条目：只收 bookmark:application name 精确匹配的。
fn rf_filter_apps(entries : Array[RfEntry], name : String) -> Array[RfEntry] {
  let out : Array[RfEntry] = []
  for e in entries {
    if e.apps.contains(name) {
      out.push(e)
    }
  }
  out
}

///|
/// 最近文件排序：modified 降序，并列按 path 升序、再按 uri 升序
/// （返回新数组）。
pub fn rf_sort_recent(items : Array[RecentItem]) -> Array[RecentItem] {
  let out = items.copy()
  out
  .mut_view()
  .sort_by(fn(a, b) {
    if a.modified > b.modified {
      -1
    } else if a.modified < b.modified {
      1
    } else if a.path < b.path {
      -1
    } else if a.path > b.path {
      1
    } else if a.uri < b.uri {
      -1
    } else if a.uri > b.uri {
      1
    } else {
      0
    }
  })
  out
}

///|
/// 截断：limit <= 0 或超出长度时全收，否则取前 limit 项（返回新数组）。
fn[T] rf_take(items : Array[T], limit : Int) -> Array[T] {
  if limit <= 0 || limit >= items.length() {
    return items.copy()
  }
  let out : Array[T] = []
  for i = 0; i < limit; i = i + 1 {
    out.push(items[i])
  }
  out
}

// ---------------------------------------------------------------------------
// 探测与读取（只读，不改写 recently-used.xbel）
// ---------------------------------------------------------------------------

///|
/// 最近文件数据目录：XDG_DATA_HOME（设且非空）优先，回退
/// $HOME/.local/share。
pub fn rf_data_dir(xdg_data_home : String?, home : String?) -> String? {
  match xdg_data_home {
    Some(d) if d != "" => Some(d)
    _ =>
      match home {
        Some(h) if h != "" => Some(h + "/.local/share")
        _ => None
      }
  }
}

///|
/// 本机最近文件数据源定位：Linux 为 XDG 数据目录的 recently-used.xbel；
/// Windows 为 %APPDATA%\Microsoft\Windows\Recent（.lnk 集合）；其余平台
/// None。
fn rf_recent_source() -> String? {
  if @yue.platform() == "windows" {
    return match getenv_str("APPDATA") {
      Some(d) if d != "" => Some(d + "/Microsoft/Windows/Recent")
      _ => None
    }
  }
  if @yue.platform() != "linux" {
    return None
  }
  match rf_data_dir(getenv_str("XDG_DATA_HOME"), getenv_str("HOME")) {
    Some(d) => Some(d + "/recently-used.xbel")
    None => None
  }
}

///|
/// 读取并解析最近文件条目：Linux 读 recently-used.xbel；Windows 枚举
/// Recent 目录 .lnk 并逐个解析目标路径与 mtime（每次调用真实读盘）。
fn rf_load_entries() -> Result[Array[RfEntry], RecentError] {
  if @yue.platform() == "windows" {
    return rf_load_win()
  }
  if @yue.platform() != "linux" {
    return Err(RfUnsupported)
  }
  let path = match rf_recent_source() {
    Some(p) => p
    None => return Err(RfNoDataDir)
  }
  match @yue.read_text_file(path) {
    None => Err(RfNoFile)
    Some(text) =>
      match rf_parse_xbel(text) {
        Ok(entries) => Ok(entries)
        Err(reason) => Err(RfParseFailed(path + ": " + reason))
      }
  }
}

///|
/// Windows 路径：毫秒时间戳文本 → Int64（非法为 0）。
fn rf_parse_ms(s : String) -> Int64 {
  sys_parse_i64(s)
}

///|
/// Windows 读取路径：枚举 Recent 目录 .lnk → shim 解析 "mtime\t目标路径"
/// → RfEntry（uri 为目标路径本体、mime 无来源、应用名无来源 app_count=1、
/// added=0 / modified 取 .lnk mtime）。
fn rf_load_win() -> Result[Array[RfEntry], RecentError] {
  let dir = match rf_recent_source() {
    Some(d) => d
    None => return Err(RfNoDataDir)
  }
  let names = match @yue.fsx_list_dir(dir) {
    Ok(ns) => ns
    Err(_) => return Err(RfNoFile)
  }
  let entries : Array[RfEntry] = []
  for name in names {
    if !appfind_is_lnk(name) {
      continue
    }
    let lnk_path = dir + "/" + name
    let ok = Ref(0)
    let text = @utf8.decode_lossy(@yue.ffi_lnk_target(@yue.utf8_bytes(lnk_path), ok))
    if ok.val != 1 {
      continue // 解析失败（无目标/损坏）：跳过该项
    }
    let fields = sys_split_fields(text, '\t')
    if fields.length() != 2 || fields[1] == "" {
      continue
    }
    entries.push({
      uri: fields[1],
      mime: None,
      added: 0L,
      modified: rf_parse_ms(fields[0]),
      apps: [""], // .lnk 无应用名来源；空串占位
    })
  }
  Ok(entries)
}

///|
/// 本机是否可读最近文件（Linux 且 recently-used.xbel 可读；Windows 且
/// Recent 目录可枚举）。每次调用真实探测，高频场景请调用方自行缓存。
pub fn rf_supported() -> Bool {
  if @yue.platform() == "windows" {
    let dir = match rf_recent_source() {
      Some(d) => d
      None => return false
    }
    return @yue.fsx_list_dir(dir) is Ok(_)
  }
  match rf_recent_source() {
    Some(p) => @yue.read_text_file(p) is Some(_)
    None => false
  }
}

///|
/// 最近文件列表：解析本机 recently-used.xbel，按 modified 倒序（并列按
/// path 升序）取前 limit 项；limit 缺省 100，<= 0 取全部。
pub fn rf_recent(limit? : Int = 100) -> Result[Array[RecentItem], RecentError] {
  match rf_load_entries() {
    Err(e) => Err(e)
    Ok(entries) =>
      Ok(rf_take(rf_sort_recent(entries.map(rf_entry_to_item)), limit))
  }
}

///|
/// 按应用名过滤的最近文件：只收 bookmark:application name 精确匹配的
/// 条目，同样按 modified 倒序取前 limit 项；limit 缺省 100，<= 0 取全部。
pub fn rf_by_app(
  name : String,
  limit? : Int = 100,
) -> Result[Array[RecentItem], RecentError] {
  match rf_load_entries() {
    Err(e) => Err(e)
    Ok(entries) =>
      Ok(
        rf_take(
          rf_sort_recent(rf_filter_apps(entries, name).map(rf_entry_to_item)),
          limit,
        ),
      )
  }
}
