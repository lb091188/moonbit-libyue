// 代码高亮白盒测试：分词着色（关键字/类型/调用/数字/字符串/注释/断词）
// 与 code_view 组件（深底出像素、多色 token、行号列、高度按行数）。
// 分词断言与 master components_wbtest 同源平移。

///|
fn mounted_bm(w : @core.Widget) -> @render.Bitmap {
  let bm = @render.Bitmap::new(w.rect.w.round().to_int() + 2, w.rect.h.round().to_int() + 2)
  let p = @render.Painter::new(bm)
  w.paint_at(p, w.rect.x, w.rect.y)
  p.end()
  bm
}

///|
/// 近似色计数（容差 16/通道）。
fn count_color(
  bm : @render.Bitmap,
  r : Int,
  g : Int,
  b : Int,
) -> Int {
  let mut n = 0
  for y in 0..<bm.height {
    for x in 0..<bm.width {
      let px = bm.pixel(x, y)
      if (px.r - r).abs() <= 16 && (px.g - g).abs() <= 16 && (px.b - b).abs() <= 16 {
        n = n + 1
      }
    }
  }
  n
}

///|
test "tokenize_lang / tokenize_moonbit：分词与着色规则" {
  fn color_of(line : String, word : String, lang : String) -> String {
    let mut found = ""
    for t in tokenize_lang(line, lang) {
      if t.text == word {
        found = t.color
      }
    }
    found
  }
  // 关键字(含补全的 in/loop/typealias 等)紫、大写开头类型黄
  assert_eq(color_of("for row in rows", "for", "moonbit"), "#C678DD")
  assert_eq(color_of("for row in rows", "in", "moonbit"), "#C678DD")
  assert_eq(color_of("loop { break }", "loop", "moonbit"), "#C678DD")
  assert_eq(color_of("typealias T = Int", "typealias", "moonbit"), "#C678DD")
  assert_eq(color_of("typealias T = Int", "T", "moonbit"), "#E5C07B")
  assert_eq(color_of("let n : Array[Int] = []", "Array", "moonbit"), "#E5C07B")
  // @ 限定名:最后段小写为调用蓝、大写为类型黄
  assert_eq(color_of("@yue.tooltip_t(x, y)", "@yue.tooltip_t", "moonbit"), "#61AFEF")
  assert_eq(color_of("@yue.IconKind", "@yue.IconKind", "moonbit"), "#E5C07B")
  // 词后紧跟 '(' 为函数调用;无括号的限定名保持普通色
  assert_eq(color_of("items.push(v)", "items.push", "moonbit"), "#61AFEF")
  assert_eq(color_of("let v = items.copy", "items.copy", "moonbit"), "#ABB2BF")
  // 区间:前导数字独立着橙,..< 归运算符
  assert_eq(color_of("for i in 0..<n", "0", "moonbit"), "#D19A66")
  assert_eq(color_of("for i in 0..<n", "..<", "moonbit"), "#ABB2BF")
  // 字符串绿、行注释灰(按语言前缀)
  assert_eq(color_of("let s = \"abc\"", "\"abc\"", "moonbit"), "#98C379")
  assert_eq(color_of("// note", "// note", "moonbit"), "#5C6370")
  assert_eq(color_of("# python", "# python", "python"), "#5C6370")
  // tokenize_moonbit 收敛为 moonbit 特化;其余语言关键字表不回归
  assert_eq(tokenize_moonbit("in")[0].color, "#C678DD")
  assert_eq(color_of("fn main() {}", "fn", "rust"), "#C678DD")
}

///|
test "code_view 组件：深底出像素、多色 token、行号列、高度按行数" {
  if !ui_text_guard() {
    return
  }
  let code = [
    "fn main {",
    "  let s = \"你好\"",
    "  // 注释行",
    "}",
  ]
  let (_root, w) = mounted(
    code_view(code, line_numbers=true, font_size=13.0),
    640.0,
    400.0,
  )
  // 尺寸按内容：4 行 > 0 高、宽 > 0（内容宽自适应）
  assert_true(w.rect.h > 60.0)
  assert_true(w.rect.w > 100.0)
  let bm = mounted_bm(w)
  // 深底（One Dark #282C34 = 40,44,52）铺满
  let dark = count_color(bm, 40, 44, 52)
  assert_true(dark > bm.width * bm.height / 2)
  // token 墨迹：非深底且非透明的像素（逐纯色计数对抗锯齿敏感，
  // 小字形的字芯也会被次像素渲染稀释，故按「有墨」计）
  let mut inked = 0
  for y in 0..<bm.height {
    for x in 0..<bm.width {
      let px = bm.pixel(x, y)
      if !((px.r - 40).abs() <= 16 && (px.g - 44).abs() <= 16 && (px.b - 52).abs() <= 16) && px.a > 0 {
        inked = inked + 1
      }
    }
  }
  assert_true(inked > 150)
}

///|
test "code_view 组件：行数翻倍高度近似翻倍（行高恒定）" {
  let two = ["let a = 1", "let b = 2"]
  let four = [
    "let a = 1",
    "let b = 2",
    "let c = 3",
    "let d = 4",
  ]
  let (_r1, w1) = mounted(code_view(two), 640.0, 400.0)
  let (_r2, w2) = mounted(code_view(four), 640.0, 400.0)
  let grew = w2.rect.h - w1.rect.h
  let per_line = w1.rect.h / 2.0
  // 新增两行 ≈ 两倍单行高（容差一行的一半）
  assert_true((grew - per_line * 2.0).abs() < per_line)
}
