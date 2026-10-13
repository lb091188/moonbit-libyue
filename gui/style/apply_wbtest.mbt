// apply / resolved / style_for 回归：布局字段落 Yoga、外观进侧表、状态桶按控件
// 交互态选桶、z_index 同步绘制层序键。

///|
fn laid_out(root : @core.Widget) -> Unit {
  @yoga.calculate_layout(root.node, None, None)
}

///|
test "apply：尺寸与定位走 Yoga（逻辑像素落位）" {
  let root = @core.Widget::new()
  let box_w = @core.Widget::new()
  root.append_child(box_w)
  apply(box_w, style(width=100.0, height=50.0))
  laid_out(root)
  assert_eq(box_w.node.layout().width, 100.0)
  assert_eq(box_w.node.layout().height, 50.0)
}

///|
test "apply：absolute + 四向 inset 落位（定位组）" {
  let root = @core.Widget::new()
  root.node.set_width(@yoga.fixed(300.0))
  root.node.set_height(@yoga.fixed(200.0))
  let kid = @core.Widget::new()
  root.append_child(kid)
  apply(kid, style(width=40.0, height=20.0, position=@yoga.Absolute, top=10.0, left=20.0))
  laid_out(root)
  assert_eq(kid.node.layout().top, 10.0)
  assert_eq(kid.node.layout().left, 20.0)
}

///|
test "apply：width_percent 与 width 共用一条 Yoga 入口（后写者赢）" {
  let root = @core.Widget::new()
  root.node.set_width(@yoga.fixed(200.0))
  let kid = @core.Widget::new()
  root.append_child(kid)
  apply(kid, style(width_percent=50.0))
  root.node.set_flex_direction(@yoga.Column)
  laid_out(root)
  assert_eq(kid.node.layout().width, 100.0)
}
///|
test "apply：padding 逐边、margin、flex_direction 全走 Yoga 落位" {
  let root = @core.Widget::new()
  apply(root, style(width=300.0, height=200.0, flex_direction=@yoga.Column))
  let kid = @core.Widget::new()
  root.append_child(kid)
  apply(kid, style(padding=14.0, padding_top=4.0, margin=8.0, width=50.0, height=30.0))
  let inner = @core.Widget::new()
  kid.append_child(inner)
  apply(inner, style(width=20.0, height=10.0))
  @yoga.calculate_layout(root.node, None, None)
  // margin 四边同值 → 子顶边距父顶 8
  assert_eq(kid.node.layout().top, 8.0)
  // padding 简写铺四边、逐边覆顶 → 内容盒左上角 (14, 4)
  assert_eq(inner.node.layout().left, 14.0)
  assert_eq(inner.node.layout().top, 4.0)
}

test "apply：visibility/cursor 落宿主，z_index 落绘制层序键" {
  let w = @core.Widget::new()
  apply(w, style(visibility=Hidden, cursor=@core.CURSOR_HAND, z_index=3))
  assert_true(!w.visible)
  assert_eq(w.cursor, @core.CURSOR_HAND)
  assert_eq(w.z_index_paint, 3.0)
  let w2 = @core.Widget::new()
  apply(w2, style(visibility=Visible))
  assert_true(w2.visible)
}

///|
test "resolved/style_for：基块与状态桶按控件交互态选桶" {
  let w = @core.Widget::new()
  let block =
    style(background_color="bg_panel")
    .hover(background_color="fill_hover")
    .active(color="danger")
    .focus(color="success")
  apply(w, block)
  // 无状态 → 基块
  let s0 = style_for(w)
  match s0.background_color {
    Some(Var(t)) => assert_eq(t, "bg_panel")
    _ => fail("基块背景应为主题 token")
  }
  assert_true(s0.color is None)
  // 悬停 → hover 桶并进基块（逐属性，不是整块替换）
  w.hovered = true
  let s1 = style_for(w)
  match s1.background_color {
    Some(Var(t)) => assert_eq(t, "fill_hover")
    _ => fail("hover 应覆盖背景")
  }
  // 悬停+按下 → 两桶同时命中按序层叠（CSS 层叠同义）
  w.pressed = true
  let s2 = style_for(w)
  match s2.color {
    Some(Var(t)) => assert_eq(t, "danger")
    _ => fail("active 桶应生效")
  }
  match s2.background_color {
    Some(Var(t)) => assert_eq(t, "fill_hover")
    _ => fail("hover 桶不应被 active 抹掉")
  }
  w.hovered = false
  w.pressed = false
  w.focused = true
  let s3 = style_for(w)
  match s3.color {
    Some(Var(t)) => assert_eq(t, "success")
    _ => fail("focus 桶应生效")
  }
}

///|
test "apply 多次调用逐属性叠加，样式常量本体不被改动" {
  let w = @core.Widget::new()
  let base = style(padding=14.0, background_color="bg_panel")
  apply(w, base)
  apply(w, style(padding=4.0))
  let s = resolved(w)
  assert_eq(s.padding_left, Some(4.0))
  match s.background_color {
    Some(Var(t)) => assert_eq(t, "bg_panel")
    _ => fail("未覆盖的属性应保留")
  }
  // 常量块本体不动
  assert_eq(base.padding_left, Some(14.0))
}
