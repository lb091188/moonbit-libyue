test {
  let t = default_theme()
  theme_apply({ ..t, primary: "#1E4FA3", primary_light: "#E3EDFA" })
  assert_eq(theme_current().primary, "#1E4FA3")
  assert_eq(theme_current().border, "#D8DCE1")
  theme_apply(default_theme())
}

test {
  // 深浅切换:订阅者在 theme_apply 时被通知,色板整体替换,焦点环随主色
  let hits = Ref(0)
  on_theme_change(fn() { hits.val = hits.val + 1 })
  theme_apply(dark_theme())
  assert_eq(theme_current().bg_page, "#141518")
  assert_eq(theme_current().bg_panel, "#1E2126")
  assert_eq(theme_current().primary, "#5B8DEF")
  let after_dark = hits.val
  assert_true(after_dark >= 1)
  theme_apply(default_theme())
  assert_eq(theme_current().bg_panel, "#FFFFFF")
  assert_eq(hits.val, after_dark + 1)
}

test {
  // 日期比较与区间判定:date_cmp 字典序,区间两端点顺序自动归一
  let a : DateYMD = { y: 2026, m: 9, d: 1 }
  let b : DateYMD = { y: 2026, m: 9, d: 20 }
  let c : DateYMD = { y: 2027, m: 1, d: 1 }
  assert_true(date_cmp(a, b) < 0)
  assert_true(date_cmp(b, a) > 0)
  assert_true(date_cmp(a, { y: 2026, m: 9, d: 1 }) == 0)
  assert_true(date_cmp(a, c) < 0)
  assert_true(date_in_range(b, a, b)) // 端点含于闭区间
  assert_true(date_in_range({ y: 2026, m: 9, d: 10 }, a, b))
  assert_true(date_in_range({ y: 2026, m: 9, d: 10 }, b, a)) // 顺序归一
  assert_false(date_in_range({ y: 2026, m: 8, d: 31 }, a, b))
  assert_false(date_in_range(c, a, b))
}

test {
  // TimeHM:格式化补零、比较、钳制
  assert_eq(TimeHM::format({ h: 8, m: 5 }), "08:05")
  assert_eq(TimeHM::format({ h: 23, m: 59 }), "23:59")
  assert_true(TimeHM::compare({ h: 8, m: 0 }, { h: 9, m: 0 }) < 0)
  assert_true(TimeHM::compare({ h: 9, m: 30 }, { h: 9, m: 0 }) > 0)
  assert_true(TimeHM::compare({ h: 9, m: 30 }, { h: 9, m: 30 }) == 0)
  assert_true(TimeHM::compare({ h: 23, m: 59 }, { h: 0, m: 0 }) > 0)
  let t = time_clamp(24, 61)
  assert_eq(t.h, 23)
  assert_eq(t.m, 59)
  let t2 = time_clamp(-1, -5)
  assert_eq(t2.h, 0)
  assert_eq(t2.m, 0)
}
