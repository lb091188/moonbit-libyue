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
