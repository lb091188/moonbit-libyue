test {
  let t = default_theme()
  theme_apply({ ..t, primary: "#1E4FA3", primary_light: "#E3EDFA" })
  assert_eq(theme_current().primary, "#1E4FA3")
  assert_eq(theme_current().border, "#D8DCE1")
  theme_apply(default_theme())
}
