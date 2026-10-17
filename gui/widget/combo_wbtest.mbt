test "parse_combo：Ctrl+S 解析" {
  match parse_combo("Ctrl+S") {
    Some((m, k)) => {
      assert_eq(m, @base.MOD_CTRL)
      assert_eq(k, 115)
    }
    None => assert_eq(true, false)
  }
}

test "parse_combo：Alt+Shift+Tab 多修饰键" {
  match parse_combo("Alt+Shift+Tab") {
    Some((m, k)) => {
      assert_eq(m, @base.MOD_ALT | @base.MOD_SHIFT)
      assert_eq(k, @base.KS_TAB)
    }
    None => assert_eq(true, false)
  }
}

test "parse_combo：大小写不敏感" {
  match parse_combo("ctrl+enter") {
    Some((m, k)) => {
      assert_eq(m, @base.MOD_CTRL)
      assert_eq(k, @base.KS_RETURN)
    }
    None => assert_eq(true, false)
  }
}

test "parse_combo：无修饰键的单键" {
  match parse_combo("Escape") {
    Some((m, k)) => {
      assert_eq(m, 0)
      assert_eq(k, @base.KS_ESCAPE)
    }
    None => assert_eq(true, false)
  }
}

test "ev_is_combo：按下且 mods 匹配才命中" {
  let ev : KeyEvent = {
    press: true,
    keysym: 115,
    mods: @base.MOD_CTRL,
  }
  assert_true(ev_is_combo(ev, "Ctrl+S"))
  assert_false(ev_is_combo(ev, "Ctrl+Shift+S"))
  let up : KeyEvent = {
    press: false,
    keysym: 115,
    mods: @base.MOD_CTRL,
  }
  assert_false(ev_is_combo(up, "Ctrl+S"))
}
