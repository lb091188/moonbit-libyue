// 样式层回归：颜色字符串三形态判定、kwargs 工厂的简写展开、merge 的逐属性
// 并集与状态桶递归、状态方法只收绘制期属性、token 不认识的一次性出声。

///|
fn is_color(o : Color?, c : Color) -> Bool {
  match o {
    Some(v) => eq_color(v, c)
    None => false
  }
}

///|
fn eq_color(a : Color, b : Color) -> Bool {
  match (a, b) {
    (Hex(x), Hex(y)) | (Named(x), Named(y)) | (Var(x), Var(y)) => x == y
    _ => false
  }
}

///|
test "parse_color：hex / 命名色（大小写不敏感）/ token 名" {
  assert_true(eq_color(parse_color("#2D68C4"), Hex("#2D68C4")))
  assert_true(eq_color(parse_color("Red"), Named("Red")))
  assert_true(eq_color(parse_color("bg_panel"), Var("bg_panel")))
  // token 名单内的 20 个名字都不许撞命名色（例如 `gray` 才是 Named）
  for t in color_tokens {
    match parse_color(t) {
      Var(_) => ()
      _ => fail("token \{t} 被误判为 hex/命名色")
    }
  }
}

///|
test "style 工厂：简写四边同值、逐边覆写、gap 展开" {
  let s = style(padding=14.0, padding_top=4.0, gap=10.0, width=120.0)
  assert_true(s.padding_left == Some(14.0))
  assert_true(s.padding_right == Some(14.0))
  assert_true(s.padding_bottom == Some(14.0))
  assert_true(s.padding_top == Some(4.0))
  assert_true(s.row_gap == Some(10.0))
  assert_true(s.column_gap == Some(10.0))
  assert_true(s.width == Some(120.0))
  assert_true(s.height == None)
  // margin 简写同形
  let m = style(margin=8.0, margin_left=2.0)
  assert_true(m.margin_top == Some(8.0))
  assert_true(m.margin_left == Some(2.0))
}

///|
test "style 工厂：颜色三形态进字段，未写的属性保持 None" {
  let s = style(color="#fff", background_color="primary", cursor=@widget.CURSOR_HAND)
  assert_true(is_color(s.color, Hex("#fff")))
  assert_true(is_color(s.background_color, Var("primary")))
  assert_true(s.cursor == Some(@widget.CURSOR_HAND))
  assert_true(s.font_size == None)
  assert_true(s.hover is None)
}

///|
test "merge：逐属性并集、后者赢、不改入参" {
  let a = style(padding=14.0, background_color="bg_panel", border_radius=8.0)
  let b = style(border_width=0.0, background_color="primary")
  let m = merge(a, b)
  assert_true(m.padding_left == Some(14.0))
  assert_true(m.border_radius == Some(8.0))
  assert_true(m.border_width == Some(0.0))
  assert_true(is_color(m.background_color, Var("primary")))
  // 入参不动（内置常量表只读用）
  assert_true(is_color(a.background_color, Var("bg_panel")))
  assert_true(b.padding_left == None)
}

///|
test "merge：状态桶逐属性递归，不是整块互换" {
  let a =
    style(background_color="primary").hover(background_color="primary_hover", color="#fff")
  let b = style().hover(border_color="border")
  let m = merge(a, b)
  match m.hover {
    Some(h) => {
      assert_true(is_color(h.background_color, Var("primary_hover")))
      assert_true(is_color(h.color, Hex("#fff")))
      assert_true(h.border_color is Some(_))
    }
    None => fail("merge 后应有 hover 桶")
  }
}

///|
test "状态方法：现场开块、已有桶逐属性并入" {
  let base = style(background_color="primary")
  let s = base.hover(color="#fff").hover(background_color="danger")
  match s.hover {
    Some(h) => {
      assert_true(is_color(h.color, Hex("#fff")))
      assert_true(is_color(h.background_color, Var("danger")))
    }
    None => fail("应有 hover 桶")
  }
  // 基础块本体不被状态方法改动
  assert_true(is_color(base.background_color, Var("primary")))
  // 三桶独立（CSS 层叠：可同时命中）
  let s2 = style().active(color="danger").focus(color="success")
  assert_true(s2.active is Some(_))
  assert_true(s2.focus is Some(_))
  assert_true(s2.hover is None)
}

///|
test "工厂状态参数收整块（具名块复用）" {
  let block = style(background_color="primary_hover")
  let s = style(background_color="primary", hover=block)
  match s.hover {
    Some(h) => assert_true(is_color(h.background_color, Var("primary_hover")))
    None => fail("hover 应收到整块")
  }
}

///|
test "token 不认识：报错文本列出全部可用 token（构造期一次性出声的判据）" {
  let msg = unknown_token_message("not_a_token")
  assert_true(msg.contains("not_a_token"))
  for t in color_tokens {
    assert_true(msg.contains(t))
  }
  // 认识的 token 原样通过
  assert_true(eq_color(check_color(Var("bg_panel")), Var("bg_panel")))
  assert_true(eq_color(check_color(Hex("#fff")), Hex("#fff")))
}

///|
test "resolve_color：Var 现取当前主题，Hex/Named 原样" {
  assert_true(resolve_color(Hex("#abc")) == "#abc")
  assert_true(resolve_color(Named("red")) == "red")
  assert_true(resolve_color(Var("primary")) == @theme.theme_primary())
  assert_true(theme_token_value("nope") == "")
}

///|
test "基调表：块构造可用、简写与状态桶就位（token 不认识会在构造即 abort）" {
  assert_true(button_base.height == Some(@theme.control_height))
  match button_base.hover {
    Some(h) => assert_true(h.background_color is Some(Var("primary")))
    None => fail("soft 档应有 hover 桶（亮档翻主色）")
  }
  assert_true(primary.cursor == Some(@widget.CURSOR_HAND))
  assert_true(card.padding_left == Some(12.0))
  assert_true(table_row_base.hover is Some(_))
  // merge 拼出的 textarea 块继承 input 皮肤
  assert_true(textarea_base.border_color is Some(Var("border")))
  assert_true(textarea_base.padding_top == Some(4.0))
}

///|
test "merge_all：class 数组按序合并、尾赢" {
  let a = style(padding=14.0, background_color="bg_panel")
  let b = style(padding=4.0)
  let m = merge_all([a, b])
  assert_true(m.padding_left == Some(4.0))
  match m.background_color {
    Some(Var(t)) => assert_eq(t, "bg_panel")
    _ => fail("未覆盖属性应保留")
  }
  let e = merge_all([])
  assert_true(e.padding_left is None && e.color is None && e.hover is None)
}
