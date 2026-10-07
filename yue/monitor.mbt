// 显示器配置：解析 xrandr --query 的输出，给出每个输出的名称 / 连接
// 状态 / 当前分辨率×刷新率 / 位置 / 物理尺寸 / 支持的模式列表。
// 刷新率以「厘赫兹」整数表示（×100，如 5995 = 59.95Hz），避免浮点解析
// 与比较。mon_current 只回当前（已连接且有当前模式）输出的简化快照，
// 供窗口布局/多屏摆放使用。解析为纯函数，monitor_wbtest.mbt 用本机
// 真实 xrandr 输出样例白盒覆盖。

///|
/// 单个显示模式：分辨率、刷新率厘赫兹（×100）、是否首选（'+'）、
/// 是否当前（'*'）。
pub(all) struct MonitorMode {
  width : Int
  height : Int
  refresh_centi : Int
  preferred : Bool
  current : Bool
}

///|
pub impl Show for MonitorMode with fn output(self, logger) {
  logger.write_string("MonitorMode { ")
  logger.write_string(self.width.to_string())
  logger.write_string("x")
  logger.write_string(self.height.to_string())
  logger.write_string(" @ ")
  logger.write_string((self.refresh_centi / 100).to_string())
  logger.write_string(".")
  logger.write_string((self.refresh_centi % 100).to_string())
  logger.write_string("Hz")
  if self.preferred {
    logger.write_string(" preferred")
  }
  if self.current {
    logger.write_string(" current")
  }
  logger.write_string(" }")
}

///|
pub extend MonitorMode with Show::{to_string, output}

///|
/// 输出（显示器）快照：name 为输出名（如 HDMI-0）；connected 为是否
/// 连接；primary 是否主输出；width/height/refresh_centi 为当前分辨率
/// 与刷新率（已连接但未启用时为 0）；pos_x/pos_y 为屏幕坐标偏移；
/// mm_width/mm_height 为物理尺寸（未报为 0）；modes 为支持的模式列表
/// （xrandr 输出原序）。
pub(all) struct MonitorInfo {
  name : String
  connected : Bool
  primary : Bool
  width : Int
  height : Int
  refresh_centi : Int
  pos_x : Int
  pos_y : Int
  mm_width : Int
  mm_height : Int
  modes : Array[MonitorMode]
}

///|
pub impl Show for MonitorInfo with fn output(self, logger) {
  logger.write_string("MonitorInfo { name: ")
  logger.write_string(self.name)
  logger.write_string(", connected: ")
  logger.write_string(self.connected.to_string())
  logger.write_string(", primary: ")
  logger.write_string(self.primary.to_string())
  logger.write_string(", mode: ")
  logger.write_string(self.width.to_string())
  logger.write_string("x")
  logger.write_string(self.height.to_string())
  logger.write_string(", pos: +")
  logger.write_string(self.pos_x.to_string())
  logger.write_string("+")
  logger.write_string(self.pos_y.to_string())
  logger.write_string(", modes: ")
  logger.write_string(self.modes.length().to_string())
  logger.write_string(" }")
}

///|
pub extend MonitorInfo with Show::{to_string, output}

///|
/// 当前输出简化快照：名称 / 当前分辨率 / 刷新率厘赫兹 / 位置（不含
/// 支持的模式列表）。
pub(all) struct CurrentOutput {
  name : String
  width : Int
  height : Int
  refresh_centi : Int
  pos_x : Int
  pos_y : Int
}

///|
pub impl Show for CurrentOutput with fn output(self, logger) {
  logger.write_string("CurrentOutput { name: ")
  logger.write_string(self.name)
  logger.write_string(", mode: ")
  logger.write_string(self.width.to_string())
  logger.write_string("x")
  logger.write_string(self.height.to_string())
  logger.write_string(", pos: +")
  logger.write_string(self.pos_x.to_string())
  logger.write_string("+")
  logger.write_string(self.pos_y.to_string())
  logger.write_string(" }")
}

///|
pub extend CurrentOutput with Show::{to_string, output}

///|
pub(all) enum MonitorError {
  /// 当前平台/环境不支持（非 Linux，或 xrandr 不可用）
  Unsupported
  /// 命令执行失败（启动失败 / 非零退出码 / 超时 / 被信号终止），带原因
  CommandFailed(String)
  /// xrandr 输出解析失败（无任何输出条目），带原文
  ParseFailed(String)
}

///|
pub impl Show for MonitorError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("MonitorError::Unsupported")
    CommandFailed(m) => logger.write_string("MonitorError::CommandFailed(\{m})")
    ParseFailed(m) => logger.write_string("MonitorError::ParseFailed(\{m})")
  }
}

///|
pub extend MonitorError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层：xrandr 输出解析（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 字符是否空白（空格 / 制表）。
fn mon_is_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t'
}

///|
/// 按空白切分 token（连续空白视为一个分隔符，首尾空白忽略）。
fn mon_split_ws(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut cur = StringBuilder()
  let mut has = false
  for ch in s {
    if mon_is_ws(ch) {
      if has {
        out.push(cur.to_string())
        cur = StringBuilder()
        has = false
      }
    } else {
      cur.write_char(ch)
      has = true
    }
  }
  if has {
    out.push(cur.to_string())
  }
  out
}

///|
/// 按换行切分文本（丢弃行尾回车，空行不保留）。
fn mon_split_lines(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut cur = StringBuilder()
  let mut has = false
  for ch in s {
    if ch == '\n' {
      if has {
        out.push(cur.to_string())
        cur = StringBuilder()
        has = false
      }
    } else if ch != '\r' {
      cur.write_char(ch)
      has = true
    }
  }
  if has {
    out.push(cur.to_string())
  }
  out
}

///|
/// 解析十进制小数为厘赫兹（×100，四舍五入到百分位）："60.00" → 6000，
/// "59.95" → 5995，"60" → 6000；非法为 None。
fn mon_parse_centi(s : String) -> Int? {
  if s == "" {
    return None
  }
  let mut ip = 0
  let mut int_any = false
  let mut seen_dot = false
  let mut frac1 = -1
  let mut frac2 = -1
  let mut frac3 = -1
  for ch in s {
    if ch == '.' {
      if seen_dot {
        return None
      }
      seen_dot = true
    } else if ch >= '0' && ch <= '9' {
      let d = ch.to_int() - 48
      if !seen_dot {
        ip = ip * 10 + d
        int_any = true
      } else if frac1 < 0 {
        frac1 = d
      } else if frac2 < 0 {
        frac2 = d
      } else if frac3 < 0 {
        frac3 = d
      } else {
        return None // 超过三位小数
      }
    } else {
      return None
    }
  }
  if !int_any || (seen_dot && frac1 < 0) {
    return None
  }
  let f1 = if frac1 >= 0 { frac1 } else { 0 }
  let f2 = if frac2 >= 0 { frac2 } else { 0 }
  let mut cents = f1 * 10 + f2
  if frac3 >= 5 {
    cents = cents + 1
  }
  Some(ip * 100 + cents)
}

///|
/// 解析 "WxH" 分辨率 token（"1920x1080" → (1920, 1080)；无数值或 'x'
/// 分隔不符为 None）。
fn mon_parse_dims(tok : String) -> (Int, Int)? {
  let chars : Array[Char] = []
  for ch in tok {
    chars.push(ch)
  }
  let mut xi = -1
  for i in 0..<chars.length() {
    if chars[i] == 'x' {
      xi = i
      break
    }
  }
  if xi <= 0 || xi >= chars.length() - 1 {
    return None
  }
  let mut w = 0
  for i in 0..<xi {
    if chars[i] < '0' || chars[i] > '9' {
      return None
    }
    w = w * 10 + (chars[i].to_int() - 48)
  }
  let mut h = 0
  let mut i = xi + 1
  while i < chars.length() {
    if chars[i] < '0' || chars[i] > '9' {
      return None
    }
    h = h * 10 + (chars[i].to_int() - 48)
    i = i + 1
  }
  Some((w, h))
}

///|
/// 解析 xrandr 几何 token "WxH+X+Y"（"1920x1080+0+0" →
/// (1920, 1080, 0, 0)；偏移可为负，如 "1920x1080+-1080+0"）。
fn mon_parse_geometry(tok : String) -> (Int, Int, Int, Int)? {
  let chars : Array[Char] = []
  for ch in tok {
    chars.push(ch)
  }
  let n = chars.length()
  // 第一段：W x H
  let mut xi = -1
  for i in 0..<n {
    if chars[i] == 'x' {
      xi = i
      break
    }
  }
  if xi <= 0 {
    return None
  }
  let mut w = 0
  for i in 0..<xi {
    if chars[i] < '0' || chars[i] > '9' {
      return None
    }
    w = w * 10 + (chars[i].to_int() - 48)
  }
  let mut h = 0
  let mut i = xi + 1
  while i < n && chars[i] >= '0' && chars[i] <= '9' {
    h = h * 10 + (chars[i].to_int() - 48)
    i = i + 1
  }
  if h == 0 || i >= n || chars[i] != '+' {
    return None
  }
  // 第二、三段：+X +Y（可带负号）
  let (px, i2) = mon_parse_offset(chars, i)
  match px {
    None => return None
    Some(x) => {
      let (py, _) = mon_parse_offset(chars, i2)
      match py {
        None => return None
        Some(y) => Some((w, h, x, y))
      }
    }
  }
}

///|
/// 解析 "+N"/"+N..." 形态的带符号偏移：chars[i] 应为 '+'，后跟可选
/// '-' 与十进制数字；返回 (值, 下一个下标)。
fn mon_parse_offset(chars : Array[Char], i : Int) -> (Int?, Int) {
  let n = chars.length()
  if i >= n || chars[i] != '+' {
    return (None, i)
  }
  let mut j = i + 1
  let mut neg = false
  if j < n && chars[j] == '-' {
    neg = true
    j = j + 1
  }
  let mut v = 0
  let mut any = false
  while j < n && chars[j] >= '0' && chars[j] <= '9' {
    v = v * 10 + (chars[j].to_int() - 48)
    any = true
    j = j + 1
  }
  if !any {
    return (None, j)
  }
  (Some(if neg { -v } else { v }), j)
}

///|
/// 解析过程中的输出草稿：输出行给出的字段（modes 为引用可追加，标量
/// 字段构造后不再改；当前分辨率/刷新率由 mon_finish 从 modes 中带
/// '*' 者导出）。
priv struct MonDraft {
  name : String
  connected : Bool
  primary : Bool
  pos_x : Int
  pos_y : Int
  mm_width : Int
  mm_height : Int
  modes : Array[MonitorMode]
}

///|
/// 草稿生成最终快照：当前分辨率×刷新率取 modes 中带 current 标记者
/// （无则为 0，即已连接但未启用）。
fn mon_finish(d : MonDraft) -> MonitorInfo {
  let mut w = 0
  let mut h = 0
  let mut centi = 0
  for m in d.modes {
    if m.current {
      w = m.width
      h = m.height
      centi = m.refresh_centi
    }
  }
  {
    name: d.name,
    connected: d.connected,
    primary: d.primary,
    width: w,
    height: h,
    refresh_centi: centi,
    pos_x: d.pos_x,
    pos_y: d.pos_y,
    mm_width: d.mm_width,
    mm_height: d.mm_height,
    modes: d.modes,
  }
}

///|
/// 解析 xrandr 模式行的刷新率 token：去掉尾部 '*'（当前）、'+'（首选）、
/// 'i'（隔行）标记后按厘赫兹解析，返回 (厘赫兹, 是否当前, 是否首选)。
fn mon_parse_rate_token(tok : String) -> (Int, Bool, Bool)? {
  let chars : Array[Char] = []
  for ch in tok {
    chars.push(ch)
  }
  let mut end = chars.length()
  while end > 0 {
    let c = chars[end - 1]
    if c == '*' || c == '+' || c == 'i' {
      end = end - 1
    } else {
      break
    }
  }
  let mut current = false
  let mut preferred = false
  for i in end..<chars.length() {
    if chars[i] == '*' {
      current = true
    } else if chars[i] == '+' {
      preferred = true
    }
  }
  let buf = StringBuilder()
  let mut k = 0
  while k < end {
    buf.write_char(chars[k])
    k = k + 1
  }
  match mon_parse_centi(buf.to_string()) {
    None => None
    Some(centi) => Some((centi, current, preferred))
  }
}

///|
/// 解析 "Nmm" 物理尺寸 token（"530mm" → 530；非该形态为 None）。
fn mon_parse_mm(tok : String) -> Int? {
  match mon_strip_suffix(tok, "mm") {
    None => None
    Some(numtxt) => {
      if numtxt == "" {
        return None
      }
      let mut v = 0
      for ch in numtxt {
        if ch < '0' || ch > '9' {
          return None
        }
        v = v * 10 + (ch.to_int() - 48)
      }
      Some(v)
    }
  }
}

///|
/// 剥掉指定结尾字符串（不匹配或长度不足为 None）。
fn mon_strip_suffix(s : String, suffix : String) -> String? {
  let n = s.length()
  let m = suffix.length()
  if n < m {
    return None
  }
  // 从后往前逐字符比较
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let suffix_chars : Array[Char] = []
  for ch in suffix {
    suffix_chars.push(ch)
  }
  let mut k = 0
  while k < m {
    if chars[n - m + k] != suffix_chars[k] {
      return None
    }
    k = k + 1
  }
  let buf = StringBuilder()
  let mut i = 0
  while i < n - m {
    buf.write_char(chars[i])
    i = i + 1
  }
  Some(buf.to_string())
}

///|
/// 从输出行 token 中提取物理尺寸（"… 530mm x 290mm" → (530, 290)；
/// 未报为 (0, 0)）。
fn mon_parse_mm_pair(toks : Array[String]) -> (Int, Int) {
  let n = toks.length()
  let mut i = 0
  while i < n - 2 {
    match mon_parse_mm(toks[i]) {
      Some(w) =>
        if toks[i + 1] == "x" {
          match mon_parse_mm(toks[i + 2]) {
            Some(h) => return (w, h)
            None => return (0, 0)
          }
        }
      None => ()
    }
    i = i + 1
  }
  (0, 0)
}

///|
/// 行是否输出行（顶格且第二个 token 为 connected/disconnected）。
fn mon_line_is_output(toks : Array[String]) -> Bool {
  if toks.length() < 2 {
    return false
  }
  toks[1] == "connected" || toks[1] == "disconnected"
}

///|
/// 归一化模式行 token：刷新率标记（'*' 当前 / '+' 首选 / 'i' 隔行）
/// 可能打成独立 token 且位于被标记刷新率之后（"59.95 +  75.00"），
/// 旧版 xrandr 直接附着在刷新率尾部（"59.95+"）。此处把独立标记
/// token 回贴到前一 token 尾部，统一为附着形态。
fn mon_fold_marker_tokens(toks : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for t in toks {
    if (t == "+" || t == "*" || t == "i") && out.length() > 0 {
      out[out.length() - 1] = out[out.length() - 1] + t
    } else {
      out.push(t)
    }
  }
  out
}

///|
/// 解析 xrandr --query 全文：顶格的 connected/disconnected 行开新输出，
/// 缩进行为该输出的模式列表；当前分辨率/刷新率取带 '*' 的模式。
fn mon_parse_xrandr(text : String) -> Array[MonitorInfo] {
  let drafts : Array[MonDraft] = []
  let mut idx = -1 // 当前草稿在 drafts 中的下标，-1 = 未开始
  for line in mon_split_lines(text) {
    if line == "" {
      continue
    }
    let toks = mon_split_ws(line)
    if mon_line_is_output(toks) {
      let connected = toks[1] == "connected"
      let mut pos_x = 0
      let mut pos_y = 0
      for tok in toks {
        match mon_parse_geometry(tok) {
          Some((_, _, gx, gy)) => {
            pos_x = gx
            pos_y = gy
          }
          None => ()
        }
      }
      let (mmw, mmh) = mon_parse_mm_pair(toks)
      drafts.push({
        name: toks[0],
        connected,
        primary: toks.contains("primary"),
        pos_x,
        pos_y,
        mm_width: mmw,
        mm_height: mmh,
        modes: [],
      })
      idx = drafts.length() - 1
    } else if idx >= 0 && toks.length() >= 2 && mon_is_indented(line) {
      // 模式行：首 token 为 WxH，其余为带标记的刷新率（先折叠独立标记
      // token 再解析）
      match mon_parse_dims(toks[0]) {
        None => ()
        Some((mw, mh)) => {
          let rates = mon_fold_marker_tokens(toks)
          for i in 1..<rates.length() {
            match mon_parse_rate_token(rates[i]) {
              None => ()
              Some((centi, current, preferred)) =>
                drafts[idx].modes.push({
                  width: mw,
                  height: mh,
                  refresh_centi: centi,
                  preferred,
                  current,
                })
            }
          }
        }
      }
    }
  }
  let out : Array[MonitorInfo] = []
  for d in drafts {
    out.push(mon_finish(d))
  }
  out
}

///|
/// 行是否缩进行（首字符空白——xrandr 的模式行以空白缩进）。
fn mon_is_indented(line : String) -> Bool {
  for ch in line {
    return mon_is_ws(ch)
  }
  false
}

///|
/// 从完整快照中提取当前输出（已连接且有当前模式者），保持 xrandr 顺序。
fn mon_current_from(infos : Array[MonitorInfo]) -> Array[CurrentOutput] {
  let out : Array[CurrentOutput] = []
  for info in infos {
    if info.connected && info.width > 0 {
      out.push({
        name: info.name,
        width: info.width,
        height: info.height,
        refresh_centi: info.refresh_centi,
        pos_x: info.pos_x,
        pos_y: info.pos_y,
      })
    }
  }
  out
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 枚举全部输出（含未连接）：名称 / 连接状态 / 当前分辨率×刷新率 /
/// 位置 / 物理尺寸 / 支持的模式列表。
pub fn mon_list() -> Result[Array[MonitorInfo], MonitorError] {
  if platform() != "linux" {
    return Err(Unsupported)
  }
  match pr_run("xrandr", ["--query"], timeout_ms=5000) {
    Err(Timeout(m)) => Err(CommandFailed(m))
    Err(SpawnFailed(m)) => Err(CommandFailed(m))
    Err(Signaled(sig)) => Err(CommandFailed("xrandr: 被信号 \{sig} 终止"))
    Err(NonZeroExit(code, _)) =>
      Err(CommandFailed("xrandr --query: 退出码 \{code}"))
    Err(Unsupported) => Err(Unsupported)
    Ok(out) => {
      let infos = mon_parse_xrandr(out.stdout)
      if infos.length() == 0 {
        Err(ParseFailed(mon_first_line(out.stdout)))
      } else {
        Ok(infos)
      }
    }
  }
}

///|
/// 当前输出简化快照（已连接且有当前模式的输出；不含模式列表），保持
/// xrandr 顺序。
pub fn mon_current() -> Result[Array[CurrentOutput], MonitorError] {
  match mon_list() {
    Err(e) => Err(e)
    Ok(infos) => Ok(mon_current_from(infos))
  }
}

///|
/// 取文本首行（错误消息只取首行，避免刷屏）。
fn mon_first_line(s : String) -> String {
  let buf = StringBuilder()
  for ch in s {
    if ch == '\n' {
      break
    }
    buf.write_char(ch)
  }
  buf.to_string()
}
