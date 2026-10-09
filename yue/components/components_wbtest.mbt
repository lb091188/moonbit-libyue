///|
test {
  @yue.theme_apply(
    @yue.Theme::{ ..@yue.default_theme(), primary: "#1E4FA3", primary_light: "#E3EDFA" },
  )
  assert_eq(@yue.theme_current().primary, "#1E4FA3")
  assert_eq(@yue.theme_current().border, "#D8DCE1")
  @yue.theme_apply(@yue.default_theme())
}

///|
test {
  // 深浅切换:订阅者在 theme_apply 时被通知,色板整体替换,焦点环随主色
  let hits = Ref(0)
  ignore(@yue.on_theme_change(fn() { hits.val = hits.val + 1 }))
  @yue.theme_apply(@yue.dark_theme())
  assert_eq(@yue.theme_current().bg_page, "#141518")
  assert_eq(@yue.theme_current().bg_panel, "#1E2126")
  assert_eq(@yue.theme_current().primary, "#5B8DEF")
  let after_dark = hits.val
  assert_true(after_dark >= 1)
  @yue.theme_apply(@yue.default_theme())
  assert_eq(@yue.theme_current().bg_panel, "#FFFFFF")
  assert_eq(hits.val, after_dark + 1)
}

///|
test {
  // 日期比较与区间判定:date_cmp 字典序,区间两端点顺序自动归一
  let a : DateYMD = { y: 2026, m: 9, d: 1, }
  let b : DateYMD = { y: 2026, m: 9, d: 20, }
  let c : DateYMD = { y: 2027, m: 1, d: 1, }
  assert_true(date_cmp(a, b) < 0)
  assert_true(date_cmp(b, a) > 0)
  assert_true(date_cmp(a, { y: 2026, m: 9, d: 1, }) == 0)
  assert_true(date_cmp(a, c) < 0)
  assert_true(date_in_range(b, a, b)) // 端点含于闭区间
  assert_true(date_in_range({ y: 2026, m: 9, d: 10, }, a, b))
  assert_true(date_in_range({ y: 2026, m: 9, d: 10, }, b, a)) // 顺序归一
  assert_false(date_in_range({ y: 2026, m: 8, d: 31, }, a, b))
  assert_false(date_in_range(c, a, b))
}

///|
test {
  // TimeHM:格式化补零、比较、钳制
  assert_eq(TimeHM::format({ h: 8, m: 5, }), "08:05")
  assert_eq(TimeHM::format({ h: 23, m: 59, }), "23:59")
  assert_true(TimeHM::compare({ h: 8, m: 0, }, { h: 9, m: 0, }) < 0)
  assert_true(TimeHM::compare({ h: 9, m: 30, }, { h: 9, m: 0, }) > 0)
  assert_true(TimeHM::compare({ h: 9, m: 30, }, { h: 9, m: 30, }) == 0)
  assert_true(TimeHM::compare({ h: 23, m: 59, }, { h: 0, m: 0, }) > 0)
  let t = time_clamp(24, 61)
  assert_eq(t.h, 23)
  assert_eq(t.m, 59)
  let t2 = time_clamp(-1, -5)
  assert_eq(t2.h, 0)
  assert_eq(t2.m, 0)
}

///|
test {
  // 代码高亮分词:关键字/类型/函数调用/数字/字符串/注释与断词规则
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
  assert_eq(
    color_of("@yue.tooltip_t(x, y)", "@yue.tooltip_t", "moonbit"),
    "#61AFEF",
  )
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
test {
  // 主题订阅退订句柄:off_theme_change 后 theme_apply 不再回调
  let hits = Ref(0)
  let h = @yue.on_theme_change(fn() { hits.val = hits.val + 1 })
  @yue.theme_apply(@yue.dark_theme())
  let after_first = hits.val
  assert_true(after_first >= 1)
  @yue.off_theme_change(h)
  @yue.theme_apply(@yue.default_theme())
  assert_eq(hits.val, after_first)
  // 幂等:重复退订与未知句柄都安全
  @yue.off_theme_change(h)
  @yue.off_theme_change(999999)
}

///|
test {
  // 主题订阅回收袋:模拟重建式组件换行——旧代订阅整袋退订,
  // 不再随重建次数累积(死订阅会在 theme_apply 时被逐帧回调)
  let old_hits = Ref(0)
  let new_hits = Ref(0)
  let keep_hits = Ref(0)
  let h_keep = @yue.on_theme_change(fn() { keep_hits.val = keep_hits.val + 1 })
  @yue.sub_bag_begin()
  ignore(@yue.on_theme_change(fn() { old_hits.val = old_hits.val + 1 }))
  let gen_old = @yue.sub_bag_end()
  @yue.theme_apply(@yue.dark_theme())
  assert_true(old_hits.val >= 1)
  // 重建:先整袋退订旧代,再开新袋挂新一代
  @yue.sub_bag_discard(gen_old)
  @yue.sub_bag_begin()
  ignore(@yue.on_theme_change(fn() { new_hits.val = new_hits.val + 1 }))
  let gen_new = @yue.sub_bag_end()
  let old_base = old_hits.val
  let keep_base = keep_hits.val
  @yue.theme_apply(@yue.default_theme())
  assert_eq(old_hits.val, old_base) // 旧代已退订,不再回调
  assert_true(new_hits.val >= 1) // 新代在袋里,正常回调
  assert_true(keep_hits.val > keep_base) // 袋外订阅不受影响
  @yue.sub_bag_discard(gen_new)
  @yue.off_theme_change(h_keep)
}

///|
test {
  // 轮播句柄:stop 停自动轮播并取消已排下的超时(卸载前的回收通道)
  let h = CarouselHandle::make()
  assert_true(h.is_running())
  carousel_stop(h)
  assert_false(h.is_running())
  // 真 SetTimeout 拿 id 再 stop:cancel 通路走通,id 归零
  h.timer.val = @yue.set_timeout(60000, fn() { () })
  carousel_stop(h)
  assert_false(h.is_running())
  assert_eq(h.timer.val, 0)
  carousel_stop(h) // 幂等
  assert_false(h.is_running())
}

///|
test {
  // 按钮配色:显式 color / background_color 优先,所有状态一致(hover 不再变色)
  let (fg1, bg1) = button_colors(Solid, true, "#123456", "#abcdef")
  assert_eq(fg1, "#123456")
  assert_eq(bg1, "#abcdef")
  let (fg2, bg2) = button_colors(Soft, false, "#000000", "#ffffff")
  assert_eq(fg2, "#000000")
  assert_eq(bg2, "#ffffff")
  // 只设一个:另一个仍走预设
  let (fg3, bg3) = button_colors(Danger, true, "#ffd700", "")
  assert_eq(fg3, "#ffd700")
  assert_true(bg3 != "")
}

///|
test {
  // 按钮配色:未传时按 variant + hover 走预设(与主题访问函数对照,
  // 不依赖具体色板,theme_apply 切换后依然成立)
  let (fg_solid, bg_solid) = button_colors(Solid, false, "", "")
  assert_eq(fg_solid, "#FFFFFF")
  assert_eq(bg_solid, @yue.theme_primary())
  let (fg_soft, bg_soft) = button_colors(Soft, false, "", "")
  assert_eq(fg_soft, @yue.theme_primary())
  assert_eq(bg_soft, @yue.theme_primary_light())
  let (_, bg_text) = button_colors(Text, false, "", "")
  assert_eq(bg_text, "") // Text 常态无底
  let (fg_soft_hover, bg_soft_hover) = button_colors(Soft, true, "", "")
  assert_eq(fg_soft_hover, "#FFFFFF")
  assert_eq(bg_soft_hover, @yue.theme_primary()) // Soft hover 变实底
  let (fg_danger, _) = button_colors(Danger, true, "", "")
  assert_eq(fg_danger, "#FFFFFF")
}
