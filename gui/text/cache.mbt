// 文本度量缓存：shaping 是 FFI 里最贵的一步，而布局期每个文本控件每帧都会
// 经 set_measure 回调问一遍 measure_font、基线回调每帧问一遍 font_metrics
// （line_height_font / line_ascent_font 都经它）——这些都是纯函数，按输入键
// 缓存后命中零 FFI。后端不可用（None）同样缓存：失败路径每帧重走一遍 FFI
// 同样是白烧。
//
// 口径：条目上限 CACHE_LIMIT，超限整表清空——测量键访问有强局部性（同一批
// 控件反复问同样的问题），整清比逐条 LRU 便宜且无簿记；清空只发生在内容域
// 异常膨胀（一次性长文本流）的场景，代价是下一轮冷启动。
// 实现是零依赖的开放寻址哈希表（FNV-1a + 线性探测，负载 0.75 倍增）：根
// moonbitlang/core 在本工具链解析不了（实测 Cannot find import），text 包
// 也不值得为此引依赖。

///|
const CACHE_LIMIT : Int = 8192

///|
priv struct Slot[V] {
  key : String
  val : V
}

///|
priv struct StrCache[V] {
  mut slots : Array[Slot[V]?]
  mut count : Int
}

///|
fn[V] StrCache::new() -> StrCache[V] {
  { slots: Array::make(256, None), count: 0 }
}

///|
/// djb2 字符串哈希：h = h×33 + 字符码，溢出按 32 位环绕，哈希用途无妨。
/// （不用 FNV-1a 是它的初始常量 2166136261 超出 Int 字面量范围。）
fn hash_str(s : String) -> Int {
  let mut h = 5381
  for c in s {
    h = h * 33 + c.to_int()
  }
  h
}

///|
/// 查键：命中返回值，撞到空槽即不存在。负载因子恒 < 0.75，容量步数内必有
/// 空槽，探测必然终止。
fn[V] StrCache::get(self : StrCache[V], key : String) -> V? {
  let cap = self.slots.length()
  let mut i = hash_str(key) & (cap - 1)
  for _k in 0..<cap {
    match self.slots[i] {
      Some(s) =>
        if s.key == key {
          return Some(s.val)
        }
      None => return None
    }
    i = (i + 1) & (cap - 1)
  }
  None
}

///|
/// 存键：已有同键就覆盖，否则占用首个空槽并计数；达上限整清、达负载先倍增。
fn[V] StrCache::put(self : StrCache[V], key : String, val : V) -> Unit {
  if self.count >= CACHE_LIMIT {
    self.clear()
  }
  let cap = self.slots.length()
  if (self.count + 1) * 4 > cap * 3 {
    self.rehash(cap * 2)
  }
  let cap = self.slots.length()
  let mut i = hash_str(key) & (cap - 1)
  for _k in 0..<cap {
    match self.slots[i] {
      Some(s) =>
        if s.key == key {
          self.slots[i] = Some({ key, val })
          return
        }
      None => {
        self.slots[i] = Some({ key, val })
        self.count += 1
        return
      }
    }
    i = (i + 1) & (cap - 1)
  }
}

///|
/// 倍增重排：新表容量必须是 2 的幂，旧条目按各自哈希重新落位，计数不变。
fn[V] StrCache::rehash(self : StrCache[V], newcap : Int) -> Unit {
  let old = self.slots
  self.slots = Array::make(newcap, None)
  for slot in old {
    match slot {
      Some(s) => self.place(newcap, s)
      None => ()
    }
  }
}

///|
/// 把一个已有条目放进容量 newcap 的新表（只在新表里找空位，不计数）。
fn[V] StrCache::place(self : StrCache[V], newcap : Int, s : Slot[V]) -> Unit {
  let mut i = hash_str(s.key) & (newcap - 1)
  for _k in 0..<newcap {
    if self.slots[i] is None {
      self.slots[i] = Some(s)
      return
    }
    i = (i + 1) & (newcap - 1)
  }
}

///|
/// 整清：表容量与计数一并回到冷启动形态。
fn[V] StrCache::clear(self : StrCache[V]) -> Unit {
  self.slots = Array::make(256, None)
  self.count = 0
}

///|
let g_measure_font_cache : StrCache[TextMetrics?] = StrCache::new()

///|
let g_measure_cache : StrCache[TextMetrics?] = StrCache::new()

///|
let g_font_metrics_cache : StrCache[FontMetrics?] = StrCache::new()

///|
let g_line_cache : StrCache[Int?] = StrCache::new()

///|
/// 字体键：族名 + 字号 + 字重 + 字形（度量只由这四者决定）。
fn font_key(f : Font) -> String {
  f.name + "\u{1F}" + f.size.to_string() + "\u{1F}" + weight_value(f.weight).to_string() + "\u{1F}" + style_id(f.style).to_string()
}

///|
/// 通用存取：命中直接返，未命中先算再入表。
fn[V] cache_get(m : StrCache[V], key : String, compute : () -> V) -> V {
  match m.get(key) {
    Some(v) => v
    None => {
      let v = compute()
      m.put(key, v)
      v
    }
  }
}

///|
pub(all) enum LineKind {
  Height
  Ascent
}

///|
/// 测量（带字体）：键 = 字体 + 宽度约束 + 省略/换行标志 + 文本。
pub fn measure_font_cached(
  text : String,
  font : Font,
  max_width : Int,
  ellipsize : Bool,
  wrap : Bool,
) -> TextMetrics? {
  let key = font_key(font) + "\u{1F}" + max_width.to_string() + "\u{1F}" + (if ellipsize { "1" } else { "0" }) + "\u{1F}" + (if wrap { "1" } else { "0" }) + "\u{1F}" + text
  cache_get(g_measure_font_cache, key, fn() {
    measure_font_uncached(text, font, max_width, ellipsize, wrap)
  })
}

///|
/// 测量（族名 + 字号）：键 = 族名 + 字号 + 宽度约束 + 标志 + 文本。
pub fn measure_cached(
  text : String,
  size : Double,
  family : String,
  max_width : Int,
  ellipsize : Bool,
  wrap : Bool,
) -> TextMetrics? {
  let key = family + "\u{1F}" + size.to_string() + "\u{1F}" + max_width.to_string() + "\u{1F}" + (if ellipsize { "1" } else { "0" }) + "\u{1F}" + (if wrap { "1" } else { "0" }) + "\u{1F}" + text
  cache_get(g_measure_cache, key, fn() {
    measure_uncached(text, size, family, max_width, ellipsize, wrap)
  })
}

///|
/// 字体度量：键 = 字体四要素。line_height_font / line_ascent_font /
/// line_height_multi 都经此，缓存后基线与行高回调零 FFI。
pub fn font_metrics_cached(font : Font) -> FontMetrics? {
  cache_get(g_font_metrics_cache, font_key(font), fn() { font_metrics_uncached(font) })
}

///|
/// 行高 / 基线（族名 + 字号，字重字形固定常规正体）：键 = kind + 族名 + 字号
/// ——同一 (size, family) 的行高与基线是两个值，kind 必须进键。
pub fn line_cached(kind : LineKind, size : Double, family : String) -> Int? {
  let key = (if kind is Height { "h" } else { "a" }) + "\u{1F}" + family + "\u{1F}" + size.to_string()
  cache_get(g_line_cache, key, fn() {
    match kind {
      Height => line_height_uncached(size, family)
      Ascent => line_ascent_uncached(size, family)
    }
  })
}
