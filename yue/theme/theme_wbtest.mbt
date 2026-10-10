// 主题色板与订阅的回归：派生公式的不变量（色相保持、饱和度保底、明度钳制区间、
// 语义色色相轮、混色方向）、非法输入的回落、订阅的通知与退订、快照切换。
// 具体十六进制值只在「公式必然给出」的场合断言，其余断 HSL 不变量——
// 换基准盘颜色不至于整片红。

///|
fn hsl_of(hex : String) -> (Double, Double, Double) {
  match parse_hex(hex) {
    Some((r, g, b)) => rgb_to_hsl(r, g, b)
    None => (-1.0, -1.0, -1.0)
  }
}

///|
fn close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn all_fields(t : Theme) -> Array[String] {
  [
    t.primary,
    t.primary_light,
    t.primary_hover,
    t.danger_hover,
    t.success,
    t.success_light,
    t.warning,
    t.warning_light,
    t.danger,
    t.danger_light,
    t.info,
    t.info_light,
    t.text_primary,
    t.text_regular,
    t.text_secondary,
    t.border,
    t.fill_hover,
    t.fill_zebra,
    t.bg_page,
    t.bg_panel,
  ]
}

///|
test "预设色板：字段齐备、合法 hex、深浅底相反" {
  let light = default_theme()
  let dark = dark_theme()
  assert_eq(all_fields(light).length(), 20)
  let mut bad = 0
  for t in [light, dark] {
    for c in all_fields(t) {
      match parse_hex(c) {
        Some(_) => ()
        None => bad = bad + 1
      }
    }
  }
  assert_eq(bad, 0)
  let (_, _, ll) = hsl_of(light.bg_page)
  let (_, _, dl) = hsl_of(dark.bg_page)
  assert_eq(ll > 0.9, true)
  assert_eq(dl < 0.2, true)
  // 浅底上文字要深、深底上文字要浅
  let (_, _, tl) = hsl_of(light.text_primary)
  let (_, _, td) = hsl_of(dark.text_primary)
  assert_eq(tl < 0.3 && td > 0.8, true)
}

///|
test "主色派生：色相保持、饱和度保底、明度按模式钳制" {
  // 纯红：h=0 s=1 l=0.5，浅模式区间 0.34..0.52 内不动 → 原样
  let red = theme_from_accent("#FF0000")
  assert_eq(red.primary, "#ff0000")
  // 灰accent（s=0）：饱和度必须被抬到保底 0.45，色相归零
  let grey = theme_from_accent("#808080")
  let (gh, gs, gl) = hsl_of(grey.primary)
  assert_eq(gs > 0.44 && gs < 0.46, true)
  assert_eq(gh < 0.01 || gh > 359.99, true)
  assert_eq(gl >= 0.34 - 0.01 && gl <= 0.52 + 0.01, true)
  // 极亮 accent（白）：明度被钳到浅模式上限 0.52
  let white = theme_from_accent("#FFFFFF")
  let (_, _, wl) = hsl_of(white.primary)
  assert_eq(close(wl, 0.52, 0.02), true)
  // 深模式：暗 accent 被抬到下限 0.55
  let dk = theme_from_accent("#2D68C4", dark=true)
  let (_, _, dl2) = hsl_of(dk.primary)
  assert_eq(dl2 >= 0.55 - 0.02, true)
  // hover 方向：浅模式更深、深模式更亮
  let (_, _, hl) = hsl_of(red.primary_hover)
  assert_eq(hl < 0.5, true)
  let (_, _, dh) = hsl_of(dk.primary_hover)
  assert_eq(dh > dl2, true)
}

///|
test "语义色取固定色相轮，浅底变体混色方向正确" {
  let t = theme_from_accent("#7A3CF0")
  let (sh, _, _) = hsl_of(t.success)
  let (wh, _, _) = hsl_of(t.warning)
  let (dh, _, _) = hsl_of(t.danger)
  let (ih, _, _) = hsl_of(t.info)
  assert_eq(close(sh, 142.0, 1.0), true)
  assert_eq(close(wh, 36.0, 1.0), true)
  assert_eq(close(dh, 4.0, 1.0), true)
  assert_eq(close(ih, 210.0, 1.0), true)
  // 浅模式：light 变体比本体更亮；深模式：更暗（向面板底混）
  let (_, _, sl) = hsl_of(t.success)
  let (_, _, sll) = hsl_of(t.success_light)
  assert_eq(sll > sl, true)
  let d = theme_from_accent("#7A3CF0", dark=true)
  let (_, _, dsl) = hsl_of(d.success)
  let (_, _, dsll) = hsl_of(d.success_light)
  assert_eq(dsll < dsl, true)
  // primary_light 同理
  let (_, _, pl) = hsl_of(t.primary)
  let (_, _, pll) = hsl_of(t.primary_light)
  assert_eq(pll > pl, true)
}

///|
test "非法 accent 回落内置基准盘" {
  assert_eq(theme_from_accent("not-a-color").primary, default_theme().primary)
  assert_eq(
    theme_from_accent("not-a-color", dark=true).bg_panel,
    dark_theme().bg_panel,
  )
}

///|
test "订阅：apply 通知全部、退订后不再通知、通知用快照" {
  let hits = Ref(0)
  let late = Ref(0)
  let h = on_theme_change(fn() { hits.val = hits.val + 1 })
  // 通知过程中的订阅表是快照：新注册的不在本轮回调里
  let h2 = on_theme_change(fn() {
    late.val = late.val + 1
    let _ = on_theme_change(fn() { () })
  })
  theme_apply(dark_theme())
  assert_eq(hits.val, 1)
  assert_eq(late.val, 1)
  off_theme_change(h)
  theme_apply(default_theme())
  assert_eq(hits.val, 1)
  assert_eq(late.val, 2)
  off_theme_change(h2)
  // 未知句柄与重复退订都是空操作
  off_theme_change(h)
  off_theme_change(-1)
  theme_apply(default_theme())
  assert_eq(hits.val, 1)
  assert_eq(late.val, 2)
}

///|
test "theme_apply 换快照后 getter 跟随" {
  theme_apply(dark_theme())
  assert_eq(theme_current().bg_panel, "#1E2126")
  assert_eq(theme_bg_panel(), "#1E2126")
  assert_eq(theme_bg_page(), "#141518")
  theme_apply(theme_from_accent("#FF0000"))
  assert_eq(theme_primary(), "#ff0000")
  // 焦点环取中性灰，不跟主色
  assert_eq(theme_focus_accent(), theme_text_secondary())
  theme_apply(default_theme())
  assert_eq(theme_bg_panel(), "#FFFFFF")
}

///|
test "控件高度基准：常量与字体实测两路" {
  assert_eq(control_height, 32.0)
  let plain = entry_ctrl_height(false)
  let bordered = entry_ctrl_height(true)
  // 有边框比无边框高 2px（边框各 1px）；13px 字体的行盒要高于字号本身
  assert_eq(close(bordered - plain, 2.0, 0.001), true)
  assert_eq(plain >= 13.0, true)
}
