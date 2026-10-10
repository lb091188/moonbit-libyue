// 字体族枚举与回退。绘制/测量拿到的族名可能系统里根本没有（分发的主题写了
// 思源黑体、机器上只有 Noto），这里给出「有哪些 / 这个有没有 / 该用哪个」，
// 让组件层在布局前就把族名定下来——行高按哪份字体量，取决于族名是否解析成功。
//
// 口径：与 C 的交互一律「读长度 + 逐字节读」，不递可写缓冲（见 adaptation
// G3b 条）；族名比较 ASCII 大小写不敏感，与 fontconfig/Pango 同口径。

///|
extern "c" fn pt_families_len() -> Int = "pt_families_len"

///|
extern "c" fn pt_families_byte(index : Int) -> Int = "pt_families_byte"

///|
#borrow(name)
extern "c" fn pt_family_available(name : Bytes, len : Int) -> Int =
  "pt_family_available"

///|
/// CSS 通用族关键字：不在枚举表里也算可用（Pango 自己解析到具体字面族）。
pub fn is_generic_family(name : String) -> Bool {
  match name {
    "serif" => true
    "sans-serif" => true
    "monospace" => true
    _ => false
  }
}

///|
/// 系统可用字体族（C 侧已排序、去重，这里按 '\\n' 切成表）。
/// 后端不可用（非 Linux 或无字体服务）返回 None。
pub fn families() -> Array[String]? {
  let n = pt_families_len()
  if n <= 0 {
    return None
  }
  let buf = FixedArray::make(n, b'\x00')
  for i = 0; i < n; i = i + 1 {
    buf[i] = pt_families_byte(i).to_byte()
  }
  let blob = @utf8.decode_lossy(FixedArray::unsafe_reinterpret_as_bytes(buf))
  let out : Array[String] = []
  let mut rest = blob
  let mut more = true
  while more {
    match rest.split_once("\n") {
      Some((head, tail)) => {
        out.push(head.to_owned())
        rest = tail.to_owned()
      }
      None => more = false
    }
  }
  if rest.length() > 0 {
    out.push(rest)
  }
  Some(out)
}

///|
/// 族名是否可用。空族名（= 跟随系统默认）与通用族一律 true。
pub fn family_available(name : String) -> Bool {
  if name.length() == 0 || is_generic_family(name) {
    true
  } else {
    let nb = @utf8.encode(name)
    pt_family_available(nb, nb.length()) == 1
  }
}

///|
/// CSS `font-family` 列表口径：返回第一个可用者；全都不可用给 `""`
/// （空族名就是「用系统默认」，测量与绘制都按它走）。
pub fn resolve_family(candidates : Array[String]) -> String {
  for name in candidates {
    if name.length() > 0 && family_available(name) {
      return name
    }
  }
  ""
}

///|
/// 把字体解析成「系统里真拿得到的族名」：可用名或通用族原样保留（保留请求名
/// 才量得到那一族的度量），不可用退成空族名（系统默认），字号/字重/样式不变。
pub fn Font::resolve(self : Font) -> Font {
  if self.name.length() == 0 || family_available(self.name) {
    self
  } else {
    Font::new("", self.size, weight=self.weight, style=self.style)
  }
}

///|
/// 字体列表逐个 `resolve`（组件层拿到的是 CSS 那一串候选时用）。
pub fn resolve_fonts(fonts : Array[Font]) -> Array[Font] {
  let out : Array[Font] = []
  for f in fonts {
    out.push(f.resolve())
  }
  out
}
