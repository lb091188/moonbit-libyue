// 多行输入框回归：折行布局的纯函数（断点单位 / 显示行）、键入与回车换行、
// 上下键按显示行移动并记住起算 x、Home/End 走行首行尾、只读不吃编辑键、
// 滚轮滚动与滚动条比例、插入点滚进可视区。

///|
fn area_font() -> @text.Font {
  @text.Font::new("", 13.0)
}

///|
/// 建一个已挂载并布局好的多行框，返回 (根, 控件, Store)。
///|
/// 在控件内部坐标点一下（按下 + 抬起）。
fn click_in(root : @core.Widget, w : @core.Widget, fx : Double, fy : Double) -> Unit {
  let _ = root.dispatch_pointer({
    kind: @core.Down,
    x: w.rect.x + fx,
    y: w.rect.y + fy,
    button: 1,
    mods: 0,
  })
  let _ = root.dispatch_pointer({
    kind: @core.Up,
    x: w.rect.x + fx,
    y: w.rect.y + fy,
    button: 1,
    mods: 0,
  })
}

///|
fn mounted_area(
  text : String,
  width : Double,
  height : Double,
  read_only? : Bool = false,
) -> (@core.Widget, @core.Widget, @core.Store[String]) {
  let store = @core.Store::new(text)
  let (root, w) = mounted(
    textarea(store, width=width, height=height, focus_id=1, read_only=read_only),
    width + 40.0,
    height + 40.0,
  )
  (root, w, store)
}

///|
test "折行断点单位：空格成段、拉丁词成段、中日韩逐字成段" {
  // "ab 中c d"：a0 b1 空格2 中(3..5) c6 空格7 d8
  let u = wrap_units("ab 中c d", 0, 9)
  assert_eq(
    u,
    [(0, 2), (2, 3), (3, 6), (6, 7), (7, 8), (8, 9)],
  )
  // 区间可截在中间：只取 [0,6) 时不含末尾的空格与 d
  assert_eq(wrap_units("ab 中c d", 0, 6).length(), 3)
}

///|
test "显示行布局：按换行符断行、按盒宽贪心折行、空文本仍给一行" {
  if !ui_text_guard() {
    return
  }
  let f = area_font()
  // 逻辑行
  let ls = layout_lines("a\nbb\nccc", 200.0, f)
  assert_eq(ls.length(), 3)
  assert_eq((ls[0].start, ls[0].end), (0, 1))
  assert_eq((ls[1].start, ls[1].end), (2, 4))
  assert_eq((ls[2].start, ls[2].end), (5, 8))
  // 空文本也要有一行放插入点
  let e = layout_lines("", 100.0, f)
  assert_eq((e.length(), e[0].start, e[0].end), (1, 0, 0))
  // 贪心折行：给一行的宽放不下两个词就断，且断行处不留行首空格
  let text = "alpha beta gamma"
  let wide = layout_lines(text, 4000.0, f)
  assert_eq(wide.length(), 1)
  let narrow = layout_lines(text, 60.0, f)
  assert_true(narrow.length() > 1)
  let bs = @utf8.encode(text)
  assert_true(bs[narrow[1].start].to_int() != 0x20)
  // 行与行首尾相接（中间只可能隔一个换行符）
  let mut i = 0
  while i + 1 < narrow.length() {
    assert_true(narrow[i + 1].start - narrow[i].end <= 1)
    i = i + 1
  }
  // 中文可逐字断：三行两字
  let cjk = layout_lines("中中中中中中", seg_width("中中", 0, 6, f) + 1.0, f)
  assert_eq(cjk.length(), 3)
  assert_eq((cjk[0].start, cjk[0].end), (0, 6))
  // 单词比一行还宽时不拆词（宁可溢出）
  let one = layout_lines("supercalifragilistic", 20.0, f)
  assert_eq(one.length(), 1)
}

///|
test "多行框：回车插入换行、上下键按显示行移动并记住 x、Home/End 走行首尾" {
  let (root, w, store) = mounted_area("", 200.0, 90.0)
  assert_eq((w.rect.w, w.rect.h), (200.0, 90.0))
  key(root, w, 'a'.to_int(), 0)
  key(root, w, 'b'.to_int(), 0)
  key(root, w, @core.KS_RETURN, 0)
  // 两行给同样的内容：上下键按「记住的像素 x」映射，两行字宽不等时落点随字体变
  // （"ab\ncd" 在 DejaVu 上第二行更窄，上键就回到行中而不是行尾），而这里要验的是
  // 「按显示行移动并记住 x」这条规则本身，不是某个字体的宽度关系
  key(root, w, 'a'.to_int(), 0)
  key(root, w, 'b'.to_int(), 0)
  assert_eq(store.get(), "ab\nab")
  assert_eq(caret_of(w), 5)
  // 行布局：第 0 行 [0,2)，第 1 行 [3,5)
  let lines = layout_lines(store.get(), 200.0 - 8.0, area_font())
  assert_eq((lines.length(), lines[0].end, lines[1].start), (2, 2, 3))
  // 上键：回到第 0 行的同一 x（两行等长 → 落在行尾 2）
  key(root, w, @core.KS_UP, 0)
  assert_eq(caret_of(w), 2)
  key(root, w, @core.KS_DOWN, 0)
  assert_eq(caret_of(w), 5)
  // Home/End 走行首行尾（不带 Ctrl）
  key(root, w, @core.KS_HOME, 0)
  assert_eq(caret_of(w), 3)
  key(root, w, @core.KS_END, 0)
  assert_eq(caret_of(w), 5)
  // Shift+Home 扩选到行首（只扩选，内容不动）
  key(root, w, @core.KS_HOME, @core.MOD_SHIFT)
  assert_eq(store.get(), "ab\nab")
  key(root, w, 'x'.to_int(), 0)
  assert_eq(store.get(), "ab\nx")
  // 回到行首再退格：删掉的是换行符，两行并回一行
  key(root, w, @core.KS_HOME, 0)
  assert_eq(caret_of(w), 3)
  key(root, w, @core.KS_BACKSPACE, 0)
  assert_eq(store.get(), "abx")
}

///|
test "多行框：点击定位到第几行、拖选跨行、只读不吃编辑键" {
  if !ui_text_guard() {
    return
  }
  let (root, w, store) = mounted_area("第一行内容\n第二行内容\n第三行内容", 220.0, 90.0)
  let lh = (@text.line_height_font(area_font()).unwrap_or(18).to_double() + 2.0).max(14.0)
  // 点第二行最左：插入点落在第二行行首（每字 3 字节 → 15 + 换行 1 = 16）
  click_in(root, w, 4.0, lh + 4.0)
  assert_eq(caret_of(w), 16)
  key(root, w, 'Z'.to_int(), 0)
  assert_eq(store.get(), "第一行内容\nZ第二行内容\n第三行内容")
  // 拖选跨行：从第一行行首拖到第三行行尾，删除后什么都不剩
  let (root2, w2, store2) = mounted_area("aaa\nbbb\nccc", 220.0, 90.0)
  let _ = root2.dispatch_pointer({
    kind: @core.Down,
    x: w2.rect.x + 4.0,
    y: w2.rect.y + 2.0,
    button: 1,
    mods: 0,
  })
  let _ = root2.dispatch_pointer({
    kind: @core.Move,
    x: w2.rect.x + 200.0,
    y: w2.rect.y + 2.0 * lh + 6.0,
    button: 1,
    mods: 0,
  })
  let _ = root2.dispatch_pointer({
    kind: @core.Up,
    x: w2.rect.x + 200.0,
    y: w2.rect.y + 2.0 * lh + 6.0,
    button: 1,
    mods: 0,
  })
  key(root2, w2, @core.KS_DELETE, 0)
  assert_eq(store2.get(), "")
  // 只读：编辑键不改文本
  let (root3, _w3, store3) = mounted_area("只读文本", 220.0, 60.0, read_only=true)
  key(root3, _w3, 'q'.to_int(), 0)
  key(root3, _w3, @core.KS_BACKSPACE, 0)
  assert_eq(store3.get(), "只读文本")
}

///|
test "多行框：内容超视口才出滚动条，滚轮下滚后拇指下移、插入点滚进可视区" {
  if !ui_text_guard() {
    return
  }
  let mut text = ""
  for i = 0; i < 12; i = i + 1 {
    if i > 0 {
      text = text + "\n"
    }
    text = text + "第 " + i.to_string() + " 行"
  }
  let (root, w, _store) = mounted_area(text, 200.0, 70.0)
  // 滚动条是唯一的子控件（绝对定位贴右缘，压在文字之上才吃得到命中）
  assert_eq(w.children().length(), 1)
  let bar = w.children()[0]
  assert_true(bar.rect.w > 0.0 && bar.rect.h > 0.0)
  // 第一帧绘制把几何抄进状态（此前 max() 还是 0，画不出拇指）
  let (bm0, _, _) = shot(w)
  let bx = w.rect.w.round().to_int() - 4
  let top0 = color_of(bm0, bx, 4)
  let bot0 = color_of(bm0, bx, 62)
  assert_true(top0 != bot0)
  // 滚轮下滚三格 × 若干次：拇指从顶上走到底部
  let mut n = 0
  while n < 20 {
    let _ = root.dispatch_scroll({ x: w.rect.x + 40.0, y: w.rect.y + 30.0, dx: 0.0, dy: 0.0 - 1.0, mods: 0, })
    n = n + 1
  }
  let (bm1, _, _) = shot(w)
  // 滚到底：拇指与轨道正好换位（顶格变成轨道、底格变成拇指）
  assert_eq(color_of(bm1, bx, 4), bot0)
  assert_eq(color_of(bm1, bx, 62), top0)
  // 插入点滚进可视区：点第 3 行再按下键，插入点进第 4 行时整块上移（顶行像素变了）
  let (root2, w2, _s2) = mounted_area(text, 200.0, 70.0)
  let (bm_b, _, _) = shot(w2)
  click_in(root2, w2, 6.0, 60.0)
  key(root2, w2, @core.KS_DOWN, 0)
  let (bm_a, _, _) = shot(w2)
  let mut moved = 0
  for y = 0; y < 24; y = y + 1 {
    for x = 4; x < 120; x = x + 1 {
      if color_of(bm_a, x, y) != color_of(bm_b, x, y) {
        moved = moved + 1
      }
    }
  }
  assert_true(moved > 20)
}
