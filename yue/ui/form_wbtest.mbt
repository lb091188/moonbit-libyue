// 表单控件首批回归：Store 值随点击变化、滑块的拖动与吸附、进度条的填充比例、
// 步进器的夹取。事件都投给挂好的控件（本地坐标），布局用 basic_wbtest 的助手。

///|
///|
/// 点击 = 按下 + 抬起。坐标是**窗口坐标**（`dispatch_pointer` 按坐标命中，
/// 与宿主真实投递一致），所以调用方传 `w.rect.x + 局部x`。
fn click(w : @core.Widget, x : Double, y : Double) -> Bool {
  let _ = w.dispatch_pointer({ kind: @core.Down, x, y, button: 1, mods: 0, })
  let last = w.dispatch_pointer({ kind: @core.Up, x, y, button: 1, mods: 0, })
  last
}

///|
test "复选框：点一下换状态，再点回来；禁用态不动作" {
  let on = @core.Store::new(false)
  let root = mount_root([checkbox("同意", on)], 240.0, 60.0)
  let w = kid(root, 0)
  assert_eq(on.get(), false)
  let _ = click(w, w.rect.w / 2.0, w.rect.h / 2.0)
  assert_eq(on.get(), true)
  let _ = click(w, w.rect.x + 4.0, w.rect.y + 4.0)
  assert_eq(on.get(), false)
  // 松开落在控件外：不算一次操作
  let _ = w.dispatch_pointer({
    kind: @core.Down,
    x: w.rect.x + 6.0,
    y: w.rect.y + 6.0,
    button: 1,
    mods: 0,
  })
  let _ = w.dispatch_pointer({
    kind: @core.Up,
    x: w.rect.x + 6.0,
    y: w.rect.y + w.rect.h + 30.0,
    button: 1,
    mods: 0,
  })
  assert_eq(on.get(), false)

  let off = @core.Store::new(false)
  let root2 = mount_root([checkbox("禁用", off, disabled=true)], 240.0, 60.0)
  let w2 = kid(root2, 0)
  let consumed = click(w2, w2.rect.x + 6.0, w2.rect.y + 6.0)
  assert_false(consumed)
  assert_eq(off.get(), false)
  // 复选框的宽度含文本：比纯色块宽
  assert_true(w.rect.w > 14.0)
}

///|
test "单选组：点第几项就写第几项，横向排列" {
  let pick = @core.Store::new(0)
  let root = mount_root([radio_group(["甲", "乙", "丙"], pick)], 300.0, 60.0)
  let group = kid(root, 0)
  assert_eq(group.children().length(), 3)
  let second = group.children()[1]
  assert_true(second.rect.x > group.children()[0].rect.x)
  let _ = click(second, second.rect.x + 6.0, second.rect.y + second.rect.h / 2.0)
  assert_eq(pick.get(), 1)
  let third = group.children()[2]
  let _ = click(third, third.rect.x + 6.0, third.rect.y + 6.0)
  assert_eq(pick.get(), 2)
  // 点已选中项仍是它（单选语义：不取消）
  let _ = click(third, third.rect.x + 6.0, third.rect.y + 6.0)
  assert_eq(pick.get(), 2)
}

///|
test "开关：胶囊尺寸固定，点击换值，绘制跟随 Store 现值" {
  let on = @core.Store::new(false)
  let root = mount_root([switch_t(on, on_text="开", off_text="关")], 240.0, 60.0)
  let row = kid(root, 0)
  let pill = row.children()[0]
  assert_eq((pill.rect.w, pill.rect.h), (40.0, 20.0))
  let _ = click(row, row.rect.x + 10.0, row.rect.y + 10.0)
  assert_eq(on.get(), true)

  // 绘制只读 Store 现值：不改结构、不重建，换值后画面就不同
  let bm = @render.Bitmap::new(60, 40)
  let sy = pill.rect.y.round().to_int()
  on.set(false)
  let p = @render.Painter::new(bm)
  pill.paint(p)
  p.end()
  let off_left = color_of(bm, 6, sy + 4)
  let off_right = color_of(bm, 34, sy + 4)
  on.set(true)
  let p2 = @render.Painter::new(bm)
  pill.paint(p2)
  p2.end()
  assert_true(color_of(bm, 6, sy + 4) != off_left)
  assert_true(color_of(bm, 34, sy + 4) != off_right)
}

///|
test "滑块：按下即取值，捕获期拖动跟手，step 吸附" {
  let v = @core.Store::new(0.0)
  let root = mount_root([slider(v, width=120.0)], 240.0, 60.0)
  let w = kid(root, 0)
  assert_eq((w.rect.w, w.rect.h), (120.0, @theme.control_height))
  let _ = w.dispatch_pointer({ kind: @core.Down, x: 60.0, y: 10.0, button: 1, mods: 0, })
  let mid = v.get()
  assert_true(mid > 40.0 && mid < 60.0)

  // 拖出轨道仍然连续：靠宿主的「按身份投递」（真实事件流里由捕获期触发）。
  // 按坐标命中的 dispatch_pointer 投不进来——坐标已经出了控件矩形，命中测试
  // 就把事件给了别的（或不给），这正是宿主要做捕获的原因。
  let drag = fn(kind : @core.PointerKind, x : Double) -> Unit {
    let _ = root.dispatch_pointer_to(w.id, {
      kind,
      x,
      y: w.rect.y + 10.0,
      button: 1,
      mods: 0,
    })
  }
  drag(@core.Move, w.rect.x - 20.0)
  assert_eq(v.get(), 0.0)
  drag(@core.Move, w.rect.x + 400.0)
  assert_eq(v.get(), 100.0)
  drag(@core.Up, w.rect.x + 400.0)
  // 松开之后再拖动不改值
  drag(@core.Move, w.rect.x + 20.0)
  assert_eq(v.get(), 100.0)

  // 步长 25：只落在刻度上
  let s = @core.Store::new(0.0)
  let root2 = mount_root([slider(s, width=100.0, step=25.0)], 240.0, 60.0)
  let w2 = kid(root2, 0)
  // 轨道宽 = 控件宽 - 2×手柄半径(6) = 88：x=50 → 比值 0.5 → 50（正好在刻度上）
  let _ = w2.dispatch_pointer({ kind: @core.Down, x: w2.rect.x + 50.0, y: w2.rect.y + 10.0, button: 1, mods: 0, })
  assert_eq(s.get(), 50.0)
  // x=94 → 比值 1.0 → 100
  let _ = w2.dispatch_pointer({
    kind: @core.Move,
    x: w2.rect.x + 94.0,
    y: w2.rect.y + 10.0,
    button: 1,
    mods: 0,
  })
  assert_eq(s.get(), 100.0)

  // 禁用：不消费、不改值
  let d = @core.Store::new(10.0)
  let root3 = mount_root([slider(d, width=100.0, disabled=true)], 240.0, 60.0)
  let w3 = kid(root3, 0)
  let consumed = w3.dispatch_pointer({
    kind: @core.Down,
    x: w3.rect.x + 50.0,
    y: w3.rect.y + 10.0,
    button: 1,
    mods: 0,
  })
  assert_false(consumed)
  assert_eq(d.get(), 10.0)
}

///|
test "进度条：填充比例按 Store 值，绘制像素两侧不同色" {
  let v = @core.Store::new(0.0)
  let root = mount_root([progress(v, width=100.0, height=6.0)], 200.0, 40.0)
  let w = kid(root, 0)
  let bm = @render.Bitmap::new(120, 20)
  v.set(0.5)
  let p = @render.Painter::new(bm)
  w.paint(p)
  p.end()
  let left = color_of(bm, 20, 3)
  let right = color_of(bm, 80, 3)
  assert_true(left != right)
  v.set(1.0)
  let p2 = @render.Painter::new(bm)
  w.paint(p2)
  p2.end()
  assert_true(color_of(bm, 80, 3) != right)
}

///|
test "步进器：加减按步长夹在区间内，触边界那侧禁用" {
  let n = @core.Store::new(0)
  let root = mount_root([stepper(n, min=0, max=2)], 260.0, 60.0)
  let row = kid(root, 0)
  assert_eq(row.children().length(), 3)
  let minus = row.children()[0]
  let plus = row.children()[2]
  // 下界：减号那侧禁用，点了不动
  let m_at = (minus.rect.x + 10.0, minus.rect.y + 10.0)
  let p_at = (plus.rect.x + 10.0, plus.rect.y + 10.0)
  let _ = click(minus, m_at.0, m_at.1)
  assert_eq(n.get(), 0)
  let _ = click(plus, p_at.0, p_at.1)
  assert_eq(n.get(), 1)
  let _ = click(plus, p_at.0, p_at.1)
  assert_eq(n.get(), 2)
  // 上界：加号那侧不再增长
  let _ = click(plus, p_at.0, p_at.1)
  assert_eq(n.get(), 2)
  let _ = click(minus, m_at.0, m_at.1)
  assert_eq(n.get(), 1)
}

///|
test "Store 订阅随回收袋退订：反复重挂不在 Store 上堆积订阅" {
  let v = @core.Store::new(false)
  let s2 = @core.Store::new(0.0)
  let mut i = 0
  while i < 5 {
    // 每一代都开袋挂载（bind_node 的形态），旧代订阅整袋退订
    @core.sub_bag_begin()
    let holder = @core.Widget::new()
    @core.mount_children(holder, [checkbox("勾选", v), slider(s2, width=80.0)])
    let offs = @core.sub_bag_end()
    @core.sub_bag_discard(offs)
    i = i + 1
  }
  assert_eq((v.signal().sub_count(), s2.signal().sub_count()), (0, 0))
  // 不套袋的常规挂载：订阅随应用存活，注册一条就留一条
  let holder2 = @core.Widget::new()
  @core.mount_children(holder2, [checkbox("另一处", v)])
  assert_eq(v.signal().sub_count(), 1)
}
