// 最小 JSON 解析器（纯 MoonBit，零依赖）：VscJson 值模型 + 手写递归下降解析，
// 整数保持 Int64 精度（时间戳毫秒值超 Int32 范围）；附码点取值助手。
// vscode_history / browser_bookmarks 与图表包的 GeoJSON 共用同一解析器。
// 自 master 线 `yue/vscjson.mbt` 平移，API 名保持不变（消费方改 `@sys.` 前缀）。

// ---------------------------------------------------------------------------
// 纯函数层:JSON 解析(entries.json / storage.json / GeoJSON 形态)
// ---------------------------------------------------------------------------

///|
/// 最小 JSON 值（解析 entries.json / storage.json 用；整数保持 Int64 精度，
/// 时间戳毫秒值超 Int32 表示范围）。
pub(all) enum VscJson {
  VscJNull
  VscJBool
  VscJInt(Int64)
  VscJFloat(Double)
  VscJStr(String)
  VscJArr(Array[VscJson])
  VscJObj(Array[(String, VscJson)])
}

///|
/// 递归下降解析器状态（text + 游标）。
priv struct VscJsonParser {
  text : String
  mut pos : Int
}

///|
/// 解析 JSON 文本：语法完整且无尾随内容返回值，否则 None。
pub fn vsc_json_parse(text : String) -> VscJson? {
  let p : VscJsonParser = { text, pos: 0, }
  p.skip_ws()
  let v = match p.value() {
    Some(v) => v
    None => return None
  }
  p.skip_ws()
  if p.pos == text.length() {
    Some(v)
  } else {
    None
  }
}

///|
/// 跳过空白（空格/制表/换行/回车）。
fn VscJsonParser::skip_ws(self : VscJsonParser) -> Unit {
  let n = self.text.length()
  while self.pos < n {
    let c = self.text.unsafe_get(self.pos).to_int()
    if c == 32 || c == 9 || c == 10 || c == 13 {
      self.pos += 1
    } else {
      break
    }
  }
}

///|
/// 当前码元；越界返回 -1。
fn VscJsonParser::peek(self : VscJsonParser) -> Int {
  if self.pos < self.text.length() {
    self.text.unsafe_get(self.pos).to_int()
  } else {
    -1
  }
}

///|
fn VscJsonParser::value(self : VscJsonParser) -> VscJson? {
  match self.peek() {
    123 => self.parse_object() // '{'
    91 => self.parse_array() // '['
    34 => self.parse_string_v() // '"'
    116 => self.parse_literal("true", VscJBool) // 't'
    102 => self.parse_literal("false", VscJBool) // 'f'
    110 => self.parse_literal("null", VscJNull) // 'n'
    c =>
      if c == 45 || (c >= 48 && c <= 57) {
        self.parse_number() // '-' 数字
      } else {
        None
      }
  }
}

///|
/// 匹配字面量 true/false/null（从当前位起逐码元比对）。
fn VscJsonParser::parse_literal(
  self : VscJsonParser,
  word : String,
  out : VscJson,
) -> VscJson? {
  let n = word.length()
  let mut i = 0
  while i < n {
    if self.pos + i >= self.text.length() ||
      self.text.unsafe_get(self.pos + i).to_int() != word.unsafe_get(i).to_int() {
      return None
    }
    i += 1
  }
  self.pos += n
  Some(out)
}

///|
fn VscJsonParser::parse_object(self : VscJsonParser) -> VscJson? {
  self.pos += 1 // '{'
  self.skip_ws()
  let pairs : Array[(String, VscJson)] = []
  if self.peek() == 125 {
    // '}'
    self.pos += 1
    return Some(VscJObj(pairs))
  }
  let mut closed = false
  while !closed {
    self.skip_ws()
    if self.peek() != 34 {
      return None
    }
    let key = match self.parse_string_v() {
      Some(VscJStr(s)) => s
      _ => return None
    }
    self.skip_ws()
    if self.peek() != 58 {
      // ':'
      return None
    }
    self.pos += 1
    self.skip_ws()
    let v = match self.value() {
      Some(v) => v
      None => return None
    }
    pairs.push((key, v))
    self.skip_ws()
    match self.peek() {
      44 => self.pos += 1 // ',' 继续下一对
      125 => {
        self.pos += 1 // '}' 结束
        closed = true
      }
      _ => return None
    }
  }
  Some(VscJObj(pairs))
}

///|
fn VscJsonParser::parse_array(self : VscJsonParser) -> VscJson? {
  self.pos += 1 // '['
  self.skip_ws()
  let items : Array[VscJson] = []
  if self.peek() == 93 {
    // ']'
    self.pos += 1
    return Some(VscJArr(items))
  }
  let mut closed = false
  while !closed {
    self.skip_ws()
    let v = match self.value() {
      Some(v) => v
      None => return None
    }
    items.push(v)
    self.skip_ws()
    match self.peek() {
      44 => self.pos += 1 // ','
      93 => {
        self.pos += 1 // ']'
        closed = true
      }
      _ => return None
    }
  }
  Some(VscJArr(items))
}

///|
/// 字符串值（含 \" \\ \/ \b \f \n \r \t \uXXXX 转义与代理对合并）。
fn VscJsonParser::parse_string_v(self : VscJsonParser) -> VscJson? {
  self.pos += 1 // '"'
  let sb = StringBuilder()
  let n = self.text.length()
  while self.pos < n {
    let c = self.text.unsafe_get(self.pos).to_int()
    if c == 34 {
      // '"'
      self.pos += 1
      return Some(VscJStr(sb.to_string()))
    }
    if c == 92 {
      // '\'
      self.pos += 1
      let e = self.peek()
      let simple : Int? = match e {
        34 => Some(34)
        92 => Some(92)
        47 => Some(47) // '/'
        98 => Some(8) // 'b'
        102 => Some(12) // 'f'
        110 => Some(10) // 'n'
        114 => Some(13) // 'r'
        116 => Some(9) // 't'
        _ => None
      }
      match simple {
        Some(ch) => {
          sb.write_char(ch.unsafe_to_char())
          self.pos += 1
        }
        None =>
          if e == 117 {
            // 'u'：先消费 u 再读 4 位十六进制；高代理再看一个 \uXXXX 合并
            self.pos += 1
            let h1 = match self.hex4() {
              Some(v) => v
              None => return None
            }
            let cp = if h1 >= 0xD800 &&
              h1 <= 0xDBFF &&
              self.pos + 1 < n &&
              self.text.unsafe_get(self.pos).to_int() == 92 &&
              self.text.unsafe_get(self.pos + 1).to_int() == 117 {
              self.pos += 2
              let h2 = match self.hex4() {
                Some(v) => v
                None => return None
              }
              if h2 >= 0xDC00 && h2 <= 0xDFFF {
                0x10000 + ((h1 - 0xD800) << 10) + (h2 - 0xDC00)
              } else {
                0xFFFD
              }
            } else if h1 >= 0xD800 && h1 <= 0xDFFF {
              0xFFFD
            } else {
              h1
            }
            sb.write_char(cp.unsafe_to_char())
          } else {
            return None
          }
      }
    } else {
      let (cp, step) = vsc_codepoint_at(self.text, self.pos)
      sb.write_char(cp.unsafe_to_char())
      self.pos += step
    }
  }
  None // 未闭合
}

///|
/// 从当前位置读 4 位十六进制（\uXXXX 的 XXXX 部分）。
fn VscJsonParser::hex4(self : VscJsonParser) -> Int? {
  let mut v = 0
  let mut i = 0
  while i < 4 {
    let d = match vsc_hex_val(self.peek()) {
      Some(d) => d
      None => return None
    }
    v = v * 16 + d
    self.pos += 1
    i += 1
  }
  Some(v)
}

///|
/// 单个十六进制码元 → 数值（大小写均可）。
pub fn vsc_hex_val(c : Int) -> Int? {
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
/// 数值：纯整数走 Int64（溢出与含小数/指数走 Double 近似）。
fn VscJsonParser::parse_number(self : VscJsonParser) -> VscJson? {
  let chars : Array[Int] = []
  let n = self.text.length()
  while self.pos < n {
    let c = self.text.unsafe_get(self.pos).to_int()
    if (c >= 48 && c <= 57) ||
      c == 45 ||
      c == 43 ||
      c == 46 ||
      c == 101 ||
      c == 69 {
      chars.push(c)
      self.pos += 1
    } else {
      break
    }
  }
  if chars.length() == 0 {
    return None
  }
  Some(vsc_number_value(chars))
}

///|
/// 数值词元（码元列表）→ VscJson。
fn vsc_number_value(chars : Array[Int]) -> VscJson {
  let mut is_float = false
  for c in chars {
    if c == 46 || c == 101 || c == 69 {
      // '.' 'e' 'E'
      is_float = true
      break
    }
  }
  if !is_float {
    let mut v : Int64 = 0L
    let mut neg = false
    let mut idx = 0
    if chars[0] == 45 {
      neg = true
      idx = 1
    }
    let mut overflow = false
    while idx < chars.length() {
      if v > 922337203685477580L {
        overflow = true
        break
      }
      v = v * 10L + (chars[idx] - 48).to_int64()
      idx += 1
    }
    if !overflow {
      return VscJInt(if neg { -v } else { v })
    }
  }
  // Double 近似（尾数逐位累加 + 10 的幂）
  let mut mant = 0.0
  let mut neg = false
  let mut frac_cnt = 0
  let mut exp = 0
  let mut i = 0
  if chars[0] == 45 {
    neg = true
    i = 1
  }
  let mut in_frac = false
  let mut in_exp = false
  let mut exp_neg = false
  while i < chars.length() {
    let c = chars[i]
    if c >= 48 && c <= 57 {
      if in_exp {
        exp = exp * 10 + (c - 48)
      } else {
        mant = mant * 10.0 + (c - 48).to_double()
        if in_frac {
          frac_cnt += 1
        }
      }
    } else if c == 46 {
      in_frac = true
    } else if c == 101 || c == 69 {
      in_exp = true
      if i + 1 < chars.length() && (chars[i + 1] == 45 || chars[i + 1] == 43) {
        exp_neg = chars[i + 1] == 45
        i += 1
      }
    }
    i += 1
  }
  if exp_neg {
    exp = -exp
  }
  let mut out = mant
  let mut shift = exp - frac_cnt
  while shift > 0 {
    out = out * 10.0
    shift -= 1
  }
  while shift < 0 {
    out = out / 10.0
    shift += 1
  }
  VscJFloat(if neg { -out } else { out })
}

///|
/// 对象按键取首个匹配（键不存在或值非对象返回 None）。
pub fn vsc_json_get(v : VscJson, key : String) -> VscJson? {
  match v {
    VscJObj(pairs) => {
      for pair in pairs {
        if pair.0 == key {
          return Some(pair.1)
        }
      }
      None
    }
    _ => None
  }
}

///|
/// 字符串值；缺失或非字符串返回 None。
pub fn vsc_json_str(v : VscJson?) -> String? {
  match v {
    Some(VscJStr(s)) => Some(s)
    Some(
      VscJNull
      | VscJBool
      | VscJInt(_)
      | VscJFloat(_)
      | VscJArr(_)
      | VscJObj(_)
    ) => None
    None => None
  }
}

///|
/// 整数值；缺失、非整数返回 None；整值浮点（如 123.0）兜底转 Int64。
pub fn vsc_json_int64(v : VscJson?) -> Int64? {
  match v {
    Some(VscJInt(i)) => Some(i)
    Some(VscJFloat(f)) => vsc_float_to_int64(f)
    Some(VscJNull | VscJBool | VscJStr(_) | VscJArr(_) | VscJObj(_)) => None
    None => None
  }
}

///|
/// 整值浮点 → Int64；带小数部分或超出 2^53 精确表示范围返回 None。
fn vsc_float_to_int64(f : Double) -> Int64? {
  let t = f.trunc()
  if t == f && t.abs() <= 9007199254740992.0 {
    Some(t.to_int64())
  } else {
    None
  }
}

// ---------------------------------------------------------------------------
// 纯函数层:UTF-16 码点取值(JSON 字符串转义与 URI 解码共用)
// ---------------------------------------------------------------------------
///|
/// 取 i 处码点：代理对合并为一个码点，返回 (码点, 消耗码元数)；
/// 孤立代理替换为 U+FFFD。
pub fn vsc_codepoint_at(s : String, i : Int) -> (Int, Int) {
  let c = s.unsafe_get(i).to_int()
  if c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length() {
    let lo = s.unsafe_get(i + 1).to_int()
    if lo >= 0xDC00 && lo <= 0xDFFF {
      return (0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00), 2)
    }
  }
  if c >= 0xD800 && c <= 0xDFFF {
    return (0xFFFD, 1)
  }
  (c, 1)
}
