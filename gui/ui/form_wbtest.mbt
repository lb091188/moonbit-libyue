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
  let root = mount_root([switch(on, on_text="开", off_text="关")], 240.0, 60.0)
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

///|
/// 单独画一个控件到贴合它的位图上：`paint_at(p, 自己的原点)` 把绝对落位抵消掉，
/// 于是位图坐标=控件局部坐标（浮层里的控件绝对 y 在几十到几百，用 `paint` 会画到
/// 位图外，取样永远读不到）。返回值仍是三元组，取样直接用局部坐标。
fn shot(w : @core.Widget) -> (@render.Bitmap, Int, Int) {
  let bm = @render.Bitmap::new(w.rect.w.round().to_int() + 2, w.rect.h.round().to_int() + 2)
  let p = @render.Painter::new(bm)
  w.paint_at(p, w.rect.x, w.rect.y)
  p.end()
  (bm, 0, 0)
}

///|
test "按钮配色求解：变体 + 悬停走预设，显式覆盖吃掉悬停" {
  let s0 = button_skin(Solid, false, "", "")
  assert_eq(s0.0, "#ffffff")
  assert_eq(s0.1, @theme.theme_primary())
  assert_eq((button_skin(Solid, true, "", "").1), @theme.theme_primary_hover())
  // Soft：常态浅底主色字，悬停变实底白字
  assert_eq(button_skin(Soft, false, "", ""), (@theme.theme_primary(), @theme.theme_primary_light()))
  assert_eq(button_skin(Soft, true, "", ""), ("#ffffff", @theme.theme_primary()))
  // Text：常态无底（空串 = 不画底）
  let t0 = button_skin(Text, false, "", "")
  assert_eq(t0.1, "")
  assert_eq(button_skin(Text, true, "", "").1, @theme.theme_fill_hover())
  assert_eq(button_skin(Danger, false, "", "").1, @theme.theme_danger())
  assert_eq(button_skin(Danger, true, "", "").1, @theme.theme_danger_hover())
  // 显式覆盖：所有状态一致，hover 不再变色
  assert_eq(button_skin(Solid, true, "#111111", "#222222"), ("#111111", "#222222"))
  assert_eq(button_skin(Solid, false, "#111111", "#222222"), ("#111111", "#222222"))
}

///|
test "主题化按钮：宽度随文本、抬起落在框内才算点击、焦点环只在聚焦时画" {
  let mut hits = 0
  let store_hit = fn() -> Unit { hits = hits + 1 }
  let root = mount_root([button("提交", on_click=store_hit, focus_id=7)], 300.0, 60.0)
  let w = kid(root, 0)
  // 「宽度随文本」需要文字层给测量值；本平台还没接上时（Windows 的
  // DirectWrite 在 TODO 的 W5）跳过这一条，点击与焦点环的断言照跑
  match @text.measure("提交", 13.0) {
    Some(m) => assert_eq(w.rect.w, m.width.to_double() + 24.0)
    None => println("form: skip (宽度随文本——无测量后端)")
  }
  assert_eq(w.rect.h, @theme.control_height)
  let _ = click(w, w.rect.x + w.rect.w / 2.0, w.rect.y + w.rect.h / 2.0)
  assert_eq(hits, 1)
  // 按下后拖出框外抬起：不算一次点击
  let _ = w.dispatch_pointer({ kind: @core.Down, x: w.rect.x + 4.0, y: w.rect.y + 4.0, button: 1, mods: 0, })
  let _ = w.dispatch_pointer({
    kind: @core.Up,
    x: w.rect.x + 4.0,
    y: w.rect.y + w.rect.h + 20.0,
    button: 1,
    mods: 0,
  })
  assert_eq(hits, 1)

  // 焦点环：未聚焦时是浅底，聚焦后 1px 环落在**第 0 列**——`stroke_rect` 是
  // 内侧描边（门面口径），整圈贴着盒子边缘，左右上下同宽
  let mid_y = (w.rect.h / 2.0).round().to_int()
  let (bm0, ox, oy) = shot(w)
  let edge0 = color_of(bm0, ox, oy + mid_y)
  let _ = root.set_focused_by_focus(7)
  let (bm1, _, _) = shot(w)
  let edge1 = color_of(bm1, ox, oy + mid_y)
  assert_true(edge0 != edge1)
  // 禁用：不消费事件、不回调
  let mut off_hits = 0
  let root2 = mount_root([button("禁用", on_click=fn() { off_hits = off_hits + 1 }, disabled=true)], 200.0, 40.0)
  let w2 = kid(root2, 0)
  let consumed = click(w2, w2.rect.x + 6.0, w2.rect.y + 6.0)
  assert_false(consumed)
  assert_eq(off_hits, 0)
}

///|
test "链接：宽度就是文字宽、悬停出下划线、抬起才回调" {
  if !ui_text_guard() {
    return
  }
  let mut n = 0
  let font = @text.Font::new("", 13.0)
  let root = mount_root([link("查看详情", fn() { n = n + 1 })], 300.0, 40.0)
  let w = kid(root, 0)
  assert_eq(w.rect.w, text_width("查看详情", font))
  let _ = click(w, w.rect.x + 4.0, w.rect.y + 4.0)
  assert_eq(n, 1)
  // 下划线只在悬停时画：比较整块墨量（原来只探「底行那一格」——线落在哪一行
  // 随字体的降部变，换个字体就探空了，而「画没画线」与探哪一格无关）
  let ink_in = fn(bm : @render.Bitmap) -> Int {
    let wide = w.rect.w.round().to_int()
    let tall = w.rect.h.round().to_int()
    let mut n = 0
    for y = 0; y < tall; y = y + 1 {
      for x = 0; x < wide; x = x + 1 {
        if bm.pixel(x, y).a > 0 {
          n = n + 1
        }
      }
    }
    n
  }
  let (bm0, _, _) = shot(w)
  let before = ink_in(bm0)
  root.set_hover(w.id)
  let (bm1, _, _) = shot(w)
  assert_true(ink_in(bm1) > before)
}

///|
test "表单项：标签定宽右对齐、错误行常驻预留 18 高、文案随 Store 变" {
  if !ui_text_guard() {
    return
  }
  let err = @core.Store::new("")
  let root = mount_root(
    [form_item("名称", text("控件区"), label_width=90.0, error=err)],
    320.0,
    120.0,
  )
  let outer = kid(root, 0)
  assert_eq(outer.children().length(), 2)
  let row = outer.children()[0]
  let err_box = outer.children()[1]
  assert_eq(err_box.rect.h, 18.0)
  // 行 = 定宽标签盒 + 12 间距 + 控件
  let label_box = row.children()[0]
  assert_eq(label_box.rect.w, 90.0)
  assert_eq(row.children()[1].rect.x, 90.0 + 12.0)
  // 预留行不随文案消失：错误为空时整块高度与填了错误时一致
  let h_empty = outer.rect.h
  err.set("必填项")
  let _ = root.relayout(320.0, 120.0)
  assert_eq(outer.rect.h, h_empty)
  // 空文案量出 0 宽，改文案后就地重测（relabel 只动这一条链）
  let err_label = err_box.children()[0]
  assert_true(err_label.rect.w > 0.0)
}

///|
test "评分：星顶点几何、点击写值并回调、悬停只预亮不改值" {
  let pts = star_points(0.0, 0.0, 10.0)
  assert_eq(pts.length(), 10)
  // 起点朝上（-90°），第二点是内半径 0.382R 在 -54°
  assert_true(pts[0].0.abs() < 0.01 && (pts[0].1 + 10.0).abs() < 0.01)
  assert_true((pts[1].0 - 2.2456).abs() < 0.01 && (pts[1].1 + 3.0918).abs() < 0.01)
  // 外内半径交替
  let r0 = (pts[0].0 * pts[0].0 + pts[0].1 * pts[0].1).sqrt()
  let r1 = (pts[1].0 * pts[1].0 + pts[1].1 * pts[1].1).sqrt()
  assert_true(r0 > r1)

  let value = @core.Store::new(0)
  let mut cb = -1
  let root = mount_root([rate(value, max=5, on_change=fn(v) { cb = v })], 300.0, 60.0)
  let w = kid(root, 0)
  assert_eq((w.rect.w, w.rect.h), (22.0 * 5.0 + 4.0 * 4.0, 22.0))
  // 第 2 颗星：x=48 → ((48+2)/26 取整)+1 = 2
  let _ = click(w, w.rect.x + 48.0, w.rect.y + 10.0)
  assert_eq((value.get(), cb), (2, 2))
  // 最右一星的右缘仍夹在 1..max
  let _ = click(w, w.rect.x + 120.0, w.rect.y + 10.0)
  assert_eq((value.get(), cb), (5, 5))
  // 悬停预亮：只换绘制，不动值（第 1 颗星心 11,11）
  let (bm0, ox, oy) = shot(w)
  let lit0 = color_of(bm0, ox + 11, oy + 11)
  value.set(0)
  let (bm_empty, _, _) = shot(w)
  let dim = color_of(bm_empty, ox + 11, oy + 11)
  assert_true(dim != lit0)
  // 移到第 3 颗星（x=60 → 预亮 1..3），第 1 颗重新亮起，值仍是 0
  let _ = w.dispatch_pointer({ kind: @core.Move, x: w.rect.x + 60.0, y: w.rect.y + 11.0, button: 0, mods: 0, })
  assert_eq(value.get(), 0)
  let (bm1, _, _) = shot(w)
  assert_true(color_of(bm1, ox + 11, oy + 11) != dim)
  // 离开后预亮清零
  let _ = w.dispatch_pointer({ kind: @core.Leave, x: 0.0, y: 0.0, button: 0, mods: 0, })
  let (bm2, _, _) = shot(w)
  assert_eq(color_of(bm2, ox + 11, oy + 11), dim)
}

///|
/// 取浮层里第 id 层的第 n 块子控件。
fn overlay_kid(id : Int, n : Int) -> @core.Widget {
  match @core.overlay_root_of(id) {
    Some(w) => w.children()[n]
    None => @core.Widget::new()
  }
}

///|
/// 下拉弹层的行列表（面板 → 滚动视口 → 内容）。
fn select_rows(id : Int) -> Array[@core.Widget] {
  overlay_kid(id, 0).children()[0].children()[0].children()
}

///|
test "下拉选择：点开列表、点选项回填并收起、✕ 清空、选中行浅底出像素" {
  let v = @core.Store::new("")
  let changes : Array[String] = []
  let (root, field) = mounted_with_overlay(
    select(["甲", "乙", "丙"], v, on_change=fn(s : String) -> Unit { changes.push(s) }, clearable=true, width=160.0),
    420.0,
    300.0,
  )
  assert_eq(field.rect.w, 160.0)
  assert_eq(@core.overlay_count(), 0)
  click_at(root, field, 40.0, 16.0)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(420.0, 300.0)
  let rows = select_rows(@core.overlay_top_id())
  assert_eq(rows.length(), 3)
  assert_eq(rows[0].rect.h, 28.0)
  // 弹层落在字段下方 2px、与字段同宽
  match @core.overlay_rect_of(@core.overlay_top_id()) {
    Some(r) => assert_eq((r.x, r.y, r.w), (field.rect.x, field.rect.y + field.rect.h + 2.0, 160.0))
    None => assert_true(false)
  }
  click_at(root, rows[1], 30.0, 14.0)
  assert_eq((v.get(), @core.overlay_count()), ("乙", 0))
  assert_eq(changes, ["乙"])
  // 再点开：选中行（乙）有浅底，未选中行没有
  click_at(root, field, 40.0, 16.0)
  root.relayout(420.0, 300.0)
  let rows2 = select_rows(@core.overlay_top_id())
  let (bm_a, ax, ay) = shot(rows2[0])
  let (bm_b, bx, by) = shot(rows2[1])
  let plain = color_of(bm_a, ax + 40, ay + 14)
  let picked = color_of(bm_b, bx + 40, by + 14)
  assert_true(plain != picked)
  // 选中行右侧的勾也是实像素（该行最右 20px 内有非底色）
  let mut ink = 0
  for y = 0; y < 28; y = y + 1 {
    for x = 138; x < 158; x = x + 1 {
      if color_of(bm_b, bx + x, by + y) != picked {
        ink = ink + 1
      }
    }
  }
  assert_true(ink > 0)
  // ✕ 清空：悬停 + 有值时热区在箭头左侧，清空同样回调（与 master 同）
  root.set_hover(field.id)
  click_at(root, field, 130.0, 16.0)
  assert_eq(v.get(), "")
  assert_eq(changes, ["乙", ""])
}

///|
test "下拉选择：点浮层外收起后，再点字段立刻能重开（句柄活性）" {
  let v = @core.Store::new("甲")
  let (root, field) = mounted_with_overlay(
    select(["甲", "乙"], v, width=140.0),
    420.0,
    300.0,
  )
  click_at(root, field, 30.0, 16.0)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(420.0, 300.0)
  // 点浮层外：图层吃掉这一击并收起（组件的句柄就此失效）
  let _ = root.dispatch_pointer({ kind: @core.Down, x: 380.0, y: 280.0, button: 1, mods: 0 })
  let _ = root.dispatch_pointer({ kind: @core.Up, x: 380.0, y: 280.0, button: 1, mods: 0 })
  assert_eq(@core.overlay_count(), 0)
  // 第二次点字段应直接重开，而不是「先清旧句柄、要点两下」
  click_at(root, field, 30.0, 16.0)
  assert_eq(@core.overlay_count(), 1)
}

///|
test "取色器：字段点开色板网格、点色块写值并收起、选中格描边出像素" {
  let cs = ["#111111", "#222222", "#333333", "#444444", "#555555", "#666666"]
  let v = @core.Store::new("#333333")
  let changes : Array[String] = []
  let (root, field) = mounted_with_overlay(
    color_picker(v, colors=cs, on_change=fn(c : String) -> Unit { changes.push(c) }, width=180.0),
    460.0,
    320.0,
  )
  click_at(root, field, 40.0, 16.0)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(460.0, 320.0)
  // 面板 → 色板容器 → 两行（每行 5 格）
  let grid = overlay_kid(@core.overlay_top_id(), 0).children()[0]
  let lines = grid.children()
  assert_eq(lines.length(), 2)
  assert_eq(lines[0].children().length(), 5)
  assert_eq(lines[1].children().length(), 1)
  // 面板按公式定尺寸 176x80；`set_padding` 改四边可选参数（没给的边按 0）
  // 后，色板容器不再有旧口径「只给左/上」留下的右下空带，网格占满面板
  assert_eq((grid.rect.w, grid.rect.h), (176.0, 80.0))
  match @core.overlay_rect_of(@core.overlay_top_id()) {
    Some(r) => assert_eq((r.w, r.h), (176.0, 80.0))
    None => assert_true(false)
  }
  // 选中格（第 3 格）比未选格多描边与白勾
  let c3 = lines[0].children()[2]
  let c4 = lines[0].children()[3]
  let (bm3, x3, y3) = shot(c3)
  let (bm4, x4, y4) = shot(c4)
  let mut diff = 0
  for y = 0; y < 26; y = y + 1 {
    for x = 0; x < 26; x = x + 1 {
      if color_of(bm3, x3 + x, y3 + y) != color_of(bm4, x4 + x, y4 + y) {
        diff = diff + 1
      }
    }
  }
  assert_true(diff > 20)
  // 点第 6 格（第二行那格）写值并收起
  click_at(root, lines[1].children()[0], 12.0, 12.0)
  assert_eq((v.get(), @core.overlay_count()), ("#666666", 0))
  assert_eq(changes, ["#666666"])
}

///|
test "可编辑下拉：点开全量候选、提交文本即过滤、上下键移高亮、回车回填、Esc 收层" {
  let v = @core.Store::new("")
  let changes : Array[String] = []
  let (root, w) = mounted_with_overlay(
    select(
      ["甲一", "甲二", "乙三"],
      v,
      on_change=fn(s : String) -> Unit { changes.push(s) },
      width=140.0,
      focus_id=1,
      editable=true,
      clearable=false,
    ),
    420.0,
    320.0,
  )
  assert_eq(w.rect.w, 140.0)
  assert_eq(@core.overlay_count(), 0)
  // 点字段：按下被里面的输入框消费，抬起冒泡到本组件才开层
  click_at(root, w, 30.0, 16.0)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(420.0, 320.0)
  assert_eq(select_rows(@core.overlay_top_id()).length(), 3)
  // 输入法提交「甲」→ 过滤成两行并自动开层
  let _ = root.dispatch_commit(1, "甲")
  root.relayout(420.0, 320.0)
  assert_eq(@core.overlay_count(), 1)
  assert_eq(select_rows(@core.overlay_top_id()).length(), 2)
  // 下键移高亮：第 2 行亮起（浅底 + 勾），第 1 行不亮
  let (bm_a, ax, ay) = shot(select_rows(@core.overlay_top_id())[0])
  let (bm_b, bx, by) = shot(select_rows(@core.overlay_top_id())[1])
  assert_true(color_of(bm_a, ax + 40, ay + 14) != color_of(bm_b, bx + 40, by + 14))
  let _ = root.dispatch_key(1, { press: true, keysym: @core.KS_DOWN, mods: 0, })
  let (bm_c, cx, cy) = shot(select_rows(@core.overlay_top_id())[0])
  assert_true(color_of(bm_c, cx + 40, cy + 14) != color_of(bm_a, ax + 40, ay + 14))
  // 回车取高亮那一项
  let _ = root.dispatch_key(1, { press: true, keysym: @core.KS_RETURN, mods: 0, })
  assert_eq((v.get(), @core.overlay_count()), ("甲二", 0))
  assert_eq(changes, ["甲二"])
  // 再点开：过滤结果只剩一行；Esc 收层且不改值
  click_at(root, w, 30.0, 16.0)
  root.relayout(420.0, 320.0)
  assert_eq(select_rows(@core.overlay_top_id()).length(), 1)
  let _ = root.dispatch_key(1, { press: true, keysym: @core.KS_ESCAPE, mods: 0, })
  assert_eq((@core.overlay_count(), v.get()), (0, "甲二"))
  // 过滤到空集时不开层
  let _ = root.dispatch_commit(1, "丙")
  assert_eq(@core.overlay_count(), 0)
}

///|
/// P2-e 口径：按钮皮肤折进样式槽——变体底色存 token 名（随主题现取），
/// 点亮态来自 hover/active 桶，`class` 覆盖后「所有状态一致」的旧口径照旧。
test "按钮皮肤走样式槽：hover 桶点亮、class 覆盖、语义色随主题现取" {
  let b = button("确定", variant=Solid, min_width=80.0)
  let root = mount_root([b], 200.0, 60.0)
  let w = kid(root, 0)
  let corner : () -> (Int, Int, Int, Int) = fn() -> (Int, Int, Int, Int) {
    // 左下角是内边距区，必是底色而非文字
    let bm = @render.Bitmap::new(200, 60)
    let p = @render.Painter::new(bm)
    root.paint(p)
    p.end()
    color_of(bm, (w.rect.x + 2.0).round().to_int(), (w.rect.y + w.rect.h - 3.0).round().to_int())
  }
  let base_c = corner()
  assert_true(base_c != (0, 0, 0, 0))
  assert_eq(base_c, colour_of_token("primary"))
  w.hovered = true
  assert_eq(corner(), colour_of_token("primary_hover"))
  w.hovered = false
  w.pressed = true
  assert_eq(corner(), colour_of_token("primary_hover"))
  w.pressed = false
  // 同一棵树不重建，换主题后现取新主色
  @theme.theme_apply(@theme.dark_theme())
  let dark_c = corner()
  @theme.theme_apply(@theme.default_theme())
  assert_true(dark_c != base_c)

  // 数「红底像素」：class 与散参数两条覆盖路径都用它
  let red_count : (@core.Node, Bool) -> Int = fn(node : @core.Node, lit : Bool) -> Int {
    let r = mount_root([node], 200.0, 60.0)
    let wt = kid(r, 0)
    wt.hovered = lit
    let bm = @render.Bitmap::new(200, 60)
    let p = @render.Painter::new(bm)
    r.paint(p)
    p.end()
    let mut n = 0
    for y = 0; y < 60; y = y + 1 {
      for x = 0; x < 200; x = x + 1 {
        let c = color_of(bm, x, y)
        if c.0 > 128 && c.1 < 64 && c.2 < 64 {
          n = n + 1
        }
      }
    }
    n
  }
  let by_param = button("取消", variant=Solid, min_width=80.0, background_color="#ff0000")
  // 散参数显式覆盖底色：常态与点亮态同色（旧口径「覆盖后悬停不变色」）
  assert_true(red_count(by_param, false) > 40)
  assert_true(red_count(by_param, true) > 40)
  // class 覆盖常态底色：常态变红，点亮态仍取内置皮肤的状态桶（与 CSS 同向）
  let by_class = button(
    "取消",
    variant=Solid,
    min_width=80.0,
    class=[@style.style(background_color="#ff0000")],
  )
  assert_true(red_count(by_class, false) > 40)
  assert_true(red_count(by_class, true) < 40)
}

///|
/// 参照色：token 名 → 当前主题的落色像素（用绘制层同一套解析）。
fn colour_of_token(name : String) -> (Int, Int, Int, Int) {
  let hex = @style.resolve_color(@style.Var(name))
  let bm = @render.Bitmap::new(4, 4)
  let p = @render.Painter::new(bm)
  p.set_fill_color(hex)
  p.fill_rect(0.0, 0.0, 4.0, 4.0)
  p.end()
  let c = bm.pixel(2, 2)
  (c.r, c.g, c.b, c.a)
}

///|
/// P2-e 口径：class 落在宿主上，标记画在内层子控件上——`paint_subset` 把 class 的
/// 绘制期属性（只这几条，布局属性不外溢）叠到标记控件的内置基调之上。
test "表单族只读样式槽：class 的绘制色落到标记控件" {
  let warm = fn(bm : @render.Bitmap, x0 : Int, y0 : Int, w : Int, h : Int) -> Int {
    let mut n = 0
    for y = y0; y < y0 + h; y = y + 1 {
      for x = x0; x < x0 + w; x = x + 1 {
        let c = color_of(bm, x, y)
        if c.0 > 128 && c.1 < 64 && c.2 < 64 {
          n = n + 1
        }
      }
    }
    n
  }
  let cool = fn(bm : @render.Bitmap, x0 : Int, y0 : Int, w : Int, h : Int) -> Int {
    let mut n = 0
    for y = y0; y < y0 + h; y = y + 1 {
      for x = x0; x < x0 + w; x = x + 1 {
        let c = color_of(bm, x, y)
        if c.2 > 128 && c.0 < 64 && c.1 < 64 {
          n = n + 1
        }
      }
    }
    n
  }
  // 复选框：勾（color）与未选框（border_color）各吃一条 class 属性
  let on = @core.Store::new(true)
  let root = mount_root(
    [checkbox("同意", on, class=[@style.style(color="#ff0000", border_color="#0000ff")])],
    200.0,
    40.0,
  )
  let box = kid(root, 0).children()[0]
  let bm = @render.Bitmap::new(200, 40)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let bx = box.rect.x.round().to_int()
  let by = box.rect.y.round().to_int()
  // 选中：勾与框都取强调色（class 的 color）
  assert_true(warm(bm, bx, by, 14, 14) > 4)
  let off_box = @core.Store::new(false)
  let root_off = mount_root(
    [checkbox("不同意", off_box, class=[@style.style(color="#ff0000", border_color="#0000ff")])],
    200.0,
    40.0,
  )
  let ob = kid(root_off, 0).children()[0]
  let bm_off = @render.Bitmap::new(200, 40)
  let pp = @render.Painter::new(bm_off)
  root_off.paint(pp)
  pp.end()
  // 未选：框描边取 class 的 border_color
  assert_true(cool(bm_off, ob.rect.x.round().to_int(), ob.rect.y.round().to_int(), 14, 14) > 10)

  // 开关：开态底色吃 class 的 background_color，滑珠仍内置白
  let sw = @core.Store::new(true)
  let root2 = mount_root(
    [switch(sw, class=[@style.style(background_color="#ff0000")])],
    200.0,
    40.0,
  )
  let pill = kid(root2, 0).children()[0]
  let bm2 = @render.Bitmap::new(200, 40)
  let p2 = @render.Painter::new(bm2)
  root2.paint(p2)
  p2.end()
  let px0 = pill.rect.x.round().to_int()
  let py0 = pill.rect.y.round().to_int()
  // 胶囊左半（滑珠在右）整片是底色
  assert_true(warm(bm2, px0 + 1, py0 + 1, 14, 18) > 100)

  // 滑块：强调色吃 class 的 color（轨道底仍内置 border 色）
  let v = @core.Store::new(80.0)
  let root3 = mount_root(
    [slider(v, min=0.0, max=100.0, width=120.0, class=[@style.style(color="#ff0000")])],
    200.0,
    40.0,
  )
  let bar = kid(root3, 0)
  let bm3 = @render.Bitmap::new(200, 40)
  let p3 = @render.Painter::new(bm3)
  root3.paint(p3)
  p3.end()
  assert_true(warm(bm3, bar.rect.x.round().to_int(), 0, 120, 40) > 60)
}

///|
test "步进器三格共框：同高、首尾相接、点 +/- 改值且触界禁用" {
  let st = @core.Store::new(1)
  let root = @core.Widget::new()
  root.set_size(300.0, 80.0)
  root.set_column()
  let group = stepper(st, min=0, max=10).mount_into(root)
  root.relayout(300.0, 80.0)
  let cells = group.children()
  assert_eq(cells.length(), 3)
  let h = @theme.control_height
  // 三格同高、且与整组同高（旧形态各画一圈边框，看着像三个没粘在一起的盒子）
  assert_eq(group.rect.h, h)
  let mut x = 0.0
  for c in cells {
    assert_eq(c.rect.h, h)
    assert_eq(c.rect.x, x)
    x = x + c.rect.w
  }
  assert_eq(group.rect.w, 108.0)
  let tap = fn(i : Int) -> Unit {
    let c = cells[i]
    let _ = root.dispatch_pointer_to(c.id, {
      kind: @core.Down, x: c.rect.x + 4.0, y: c.rect.y + 4.0, button: 1, mods: 0,
    })
    let _ = root.dispatch_pointer_to(c.id, {
      kind: @core.Up, x: c.rect.x + 4.0, y: c.rect.y + 4.0, button: 1, mods: 0,
    })
  }
  tap(2)
  assert_eq(st.get(), 2)
  tap(0)
  assert_eq(st.get(), 1)
  // 夹到区间端点：min 那一侧的钮不再改值（禁用态跟着值走）
  st.set(0)
  tap(0)
  assert_eq(st.get(), 0)
}

///|
test "色板描边贴盒边：内侧描边口径下左右上下同列" {
  let sel = fn() -> Bool { false }
  let root = mount_root(
    [color_swatch("#2D68C4", 26.0, 6.0, sel, fn() { () })],
    60.0,
    40.0,
  )
  let w = kid(root, 0)
  let (bm, _, _) = shot(w)
  let mid = 13
  let left = color_of(bm, 0, mid)
  let right = color_of(bm, 25, mid)
  let top = color_of(bm, mid, 0)
  let bottom = color_of(bm, mid, 25)
  let inner = color_of(bm, mid, mid)
  assert_true(left == right, msg="描边左右不对称（整圈往右下偏）")
  assert_true(top == bottom, msg="描边上下不对称（整圈往右下偏）")
  assert_true(left != inner, msg="描边没落在盒子边缘")
}

///|
/// 强调色像素计数（逐通道容差 48：AA 边缘的半覆盖不算，只数实心笔触）。
fn accent_count(bm : @render.Bitmap, x0 : Int, y0 : Int, w : Int, h : Int) -> Int {
  let acc = colour_of_token("primary")
  let near = fn(a : Int, b : Int) -> Bool { (a - b).abs() < 48 }
  let mut n = 0
  for y = y0; y < y0 + h; y = y + 1 {
    for x = x0; x < x0 + w; x = x + 1 {
      let c = color_of(bm, x, y)
      if near(c.0, acc.0) && near(c.1, acc.1) && near(c.2, acc.2) {
        n = n + 1
      }
    }
  }
  n
}

///|
/// 复选框标记区（14×14，去掉 1px 框线后的内部）。
fn box_inside(bm : @render.Bitmap, box : @core.Widget) -> Int {
  accent_count(bm, box.rect.x.round().to_int() + 1, box.rect.y.round().to_int() + 1, 12, 12)
}

///|
/// 勾要看得出是个勾：实心笔触覆盖 20 个像素以上；未选的那只框内不许掺强调色
/// （旧口径下上一只控件的圆弧路径会漏画进来，两只看起来都是实心块）。
test "复选框：勾是粗笔触，未选框内不掺强调色" {
  let on = @core.Store::new(true)
  let off = @core.Store::new(false)
  let root = mount_root([checkbox("甲", on), checkbox("乙", off)], 200.0, 60.0)
  let bm = @render.Bitmap::new(200, 60)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  assert_true(box_inside(bm, kid(root, 0).children()[0]) > 20)
  assert_eq(box_inside(bm, kid(root, 1).children()[0]), 0)
}

///|
/// 单选组同理：选中项=强调色环 + 强调色实心圆心，未选中项圆内只有灰环。
test "单选组：选中项是环加心，未选中项圆内干净" {
  let pick = @core.Store::new(0)
  let root = mount_root([radio_group(["甲", "乙", "丙"], pick)], 300.0, 40.0)
  let bm = @render.Bitmap::new(300, 40)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let g = kid(root, 0)
  let dots = fn(i : Int) -> @core.Widget { g.children()[i].children()[0] }
  assert_true(box_inside(bm, dots(0)) > 12)
  assert_eq(box_inside(bm, dots(1)), 0)
  assert_eq(box_inside(bm, dots(2)), 0)
}

///|
/// 一行的格子图（每格 `#`/`.` 由谓词判「这格有没有东西」）。
/// 「有墨」取不透明度过半：环的 1.2px 描边是 AA 笔，阈值过高会整条看不见。
fn row_ink(bm : @render.Bitmap, y : Int, x0 : Int, n : Int) -> Array[String] {
  let out : Array[String] = []
  for i = 0; i < n; i = i + 1 {
    let c = color_of(bm, x0 + i, y)
    out.push(if c.3 > 60 { "#" } else { "." })
  }
  out
}
///| 「滑珠白」= 三通道全满（胶囊底色是浅灰，进不了这个判定）。
fn row_knob(bm : @render.Bitmap, y : Int, x0 : Int, n : Int) -> Array[String] {
  let out : Array[String] = []
  for i = 0; i < n; i = i + 1 {
    let c = color_of(bm, x0 + i, y)
    out.push(if c.3 > 200 && c.0 > 250 && c.1 > 250 && c.2 > 250 {
      "#"
    } else {
      "."
    })
  }
  out
}
///| 「实心墨」= 不透明度过 200：AA 的淡格不计，用来量环/心的实体宽度。
fn ring_ink(bm : @render.Bitmap, y : Int, x0 : Int, n : Int) -> Array[String] {
  let out : Array[String] = []
  for i = 0; i < n; i = i + 1 {
    let c = color_of(bm, x0 + i, y)
    out.push(if c.3 > 200 { "#" } else { "." })
  }
  out
}
fn ink_span(row : Array[String], from : Int, to : Int) -> String {
  let mut s = ""
  for i = from; i < to; i = i + 1 {
    s = s + row[i]
  }
  s
}
fn ink_text(row : Array[String]) -> String {
  ink_span(row, 0, row.length())
}

///|
/// 单选标记是「环—空白—心—空白—环」，不是糊成一片的实心板：中心行两端各
/// 两格是环，紧挨着各两格必须留白，中间六格是圆心（且是实心的）。
test "单选标记的环与心之间留得出一条空白" {
  let pick = @core.Store::new(0)
  let root = mount_root([radio_group(["甲"], pick)], 120.0, 30.0)
  let bm = @render.Bitmap::new(120, 30)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let dot = kid(root, 0).children()[0].children()[0]
  let dy = dot.rect.y.round().to_int() + 7
  let dx = dot.rect.x.round().to_int()
  let row = row_ink(bm, dy, dx, 14)
  assert_eq(ink_span(row, 0, 2), "##", msg="环的左缘没落墨：\{ink_text(row)}")
  assert_eq(ink_span(row, 2, 4), "..", msg="环与心之间没留出空白：\{ink_text(row)}")
  assert_eq(ink_span(row, 4, 10), "######", msg="圆心没落在正中：\{ink_text(row)}")
  assert_eq(ink_span(row, 10, 12), "..", msg="心与环之间没留出空白：\{ink_text(row)}")
  assert_eq(ink_span(row, 12, 14), "##", msg="环的右缘没落墨：\{ink_text(row)}")
  // 心是实心板：中段四格（直径内部）不透明度过 200，环沿线也不留空洞。
  // 圆心直径两端的边缘格不进这条判据——cairo 按面积采样给 ~196（0.76 覆盖），
  // 纯光栅器按「像素是一格」的口径算满 255，两后端方法面同形但边缘格读数
  // 不同；两端「有墨」已由上面阈值 60 的形态判据覆盖。
  assert_eq(
    ink_span(ring_ink(bm, dy, dx, 14), 5, 9),
    "####",
    msg="圆心不是实心的",
  )
  for j in [1, 6, 7, 12] {
    let r = row_ink(bm, dot.rect.y.round().to_int() + j, dx, 14)
    assert_true(ink_text(r).contains("#"), msg="环的第 \{j} 行整行没墨")
  }
}

///|
/// 开关是胶囊 + 圆珠：四角落在胶囊弧外（不落墨），滑珠按行收窄成圆
/// （中缝 16 格满宽、上下两行只剩 6 格），不是两块直角矩形。
test "开关是胶囊与圆珠，四角不落墨" {
  let on = @core.Store::new(false)
  let root = mount_root([switch(on)], 120.0, 30.0)
  let bm = @render.Bitmap::new(120, 30)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let pill = kid(root, 0).children()[0]
  let px = pill.rect.x.round().to_int()
  let py = pill.rect.y.round().to_int()
  let alpha = fn(dx : Int, dy : Int) -> Int { (color_of(bm, px + dx, py + dy)).3 }
  assert_true(alpha(0, 0) < 60, msg="左上角该在胶囊弧外，却落了墨")
  assert_true(alpha(39, 19) < 60, msg="右下角该在胶囊弧外，却落了墨")
  assert_true(alpha(20, 10) > 200, msg="胶囊正中没落墨")
  // 关态滑珠贴左：圆心在 (10, 10)、半径 8 → 中缝满宽，上下两行只剩中段
  let mid = row_knob(bm, py + 9, px, 40)
  assert_eq(ink_span(mid, 3, 17), "##############", msg="滑珠中缝不满宽：\{ink_text(mid)}")
  for j in [4, 15] {
    let edge = row_knob(bm, py + j, px, 40)
    assert_eq(
      ink_span(edge, 5, 15),
      "##########",
      msg="滑珠第 \{j} 行不是圆的：\{ink_text(edge)}",
    )
  }
}

///|
/// 复选框框线是内描边：四条边与四个角都落满一格。换成居中式描边就不行了—
/// 标记在行里居中，原点常落在半像素上（14 高的标记放进 17 高的行 → y=1.5），
/// 1px 会摊成两行各半墨，框看着发虚变淡。
test "复选框框线四边四角都满墨" {
  let st = @core.Store::new(false)
  let root = mount_root([checkbox("甲", st)], 120.0, 30.0)
  let bm = @render.Bitmap::new(120, 30)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let box = kid(root, 0).children()[0]
  let bx = box.rect.x.round().to_int()
  let by = box.rect.y.round().to_int()
  let a = fn(dx : Int, dy : Int) -> Int { (color_of(bm, bx + dx, by + dy)).3 }
  let frame : Array[(Int, Int)] = [
    (7, 0),
    (7, 13),
    (0, 7),
    (13, 7),
    (0, 0),
    (13, 0),
    (0, 13),
    (13, 13),
  ]
  for (dx, dy) in frame {
    assert_true(a(dx, dy) > 200, msg="框线在 \{dx},\{dy} 没落满墨")
  }
}

///|
/// 键盘可及性（本批口径）：控件默认自动领焦点号进 Tab 链，空格/回车激活、
/// 方向键调值。键只在按下投递（宿主口径），测试直接 `dispatch_key`。
test "键盘可及性：复选/开关自动领号进 Tab 链，空格与回车切换，禁用不吃键" {
  let on = @core.Store::new(false)
  let sw = @core.Store::new(false)
  let dis = @core.Store::new(false)
  let root = mount_root(
    [checkbox("甲", on), switch(sw), checkbox("乙", dis, disabled=true)],
    300.0,
    140.0,
  )
  let cb = kid(root, 0)
  let st = kid(root, 1)
  let dc = kid(root, 2)
  assert_true(cb.focus_id > 0 && st.focus_id > 0 && cb.focus_id != st.focus_id)
  // 两只都在 Tab 链里（树序读数收得到）
  let ids = root.focus_ids()
  let has = fn(id : Int) -> Bool {
    let mut found = false
    for v in ids {
      if v == id {
        found = true
      }
    }
    found
  }
  assert_true(has(cb.focus_id) && has(st.focus_id))
  // 空格开、回车关
  let _ = root.dispatch_key(cb.focus_id, { press: true, keysym: @core.KS_SPACE, mods: 0, })
  assert_true(on.get())
  let _ = root.dispatch_key(cb.focus_id, { press: true, keysym: @core.KS_RETURN, mods: 0, })
  assert_eq(on.get(), false)
  // 开关同口径
  let _ = root.dispatch_key(st.focus_id, { press: true, keysym: @core.KS_SPACE, mods: 0, })
  assert_true(sw.get())
  // 禁用态不吃键
  let _ = root.dispatch_key(dc.focus_id, { press: true, keysym: @core.KS_SPACE, mods: 0, })
  assert_eq(dis.get(), false)
}

///|
test "键盘可及性：单选空格选中本项，左右键在组内环绕换选" {
  let v = @core.Store::new(0)
  let root = mount_root([radio_group(["甲", "乙", "丙"], v)], 300.0, 120.0)
  let group = kid(root, 0)
  assert_eq(group.kids.length(), 3)
  let item0 = group.kids[0]
  let item2 = group.kids[2]
  assert_true(item0.focus_id > 0 && item2.focus_id > 0)
  let key = fn(w : @core.Widget, ks : Int) -> Unit {
    let _ = root.dispatch_key(w.focus_id, { press: true, keysym: ks, mods: 0, })
  }
  key(item2, @core.KS_SPACE)
  assert_eq(v.get(), 2)
  // ←/↑/→/↓ 都按「焦点项的下标」换选（不是相对当前值），到头环绕
  key(item2, @core.KS_LEFT)
  assert_eq(v.get(), 1)
  key(item2, @core.KS_RIGHT)
  assert_eq(v.get(), 0)
  // 换选只看焦点项的下标：焦点还在丙（idx 2），→ 恒给 0、↑ 给 1
  key(item2, @core.KS_RIGHT)
  assert_eq(v.get(), 0)
  key(item2, @core.KS_UP)
  assert_eq(v.get(), 1)
  key(item0, @core.KS_RETURN)
  assert_eq(v.get(), 0)
}

///|
test "键盘可及性：滑块方向键增减与 Home/End、步进器左右加减、评分箭头改星" {
  let key = fn(root : @core.Widget, w : @core.Widget, ks : Int) -> Unit {
    let _ = root.dispatch_key(w.focus_id, { press: true, keysym: ks, mods: 0, })
  }
  let sv = @core.Store::new(50.0)
  let root = mount_root([slider(sv, step=10.0)], 300.0, 60.0)
  let sl = kid(root, 0)
  assert_true(sl.focus_id > 0)
  key(root, sl, @core.KS_RIGHT)
  assert_eq(sv.get(), 60.0)
  key(root, sl, @core.KS_LEFT)
  assert_eq(sv.get(), 50.0)
  key(root, sl, @core.KS_END)
  assert_eq(sv.get(), 100.0)
  key(root, sl, @core.KS_HOME)
  assert_eq(sv.get(), 0.0)
  let nv = @core.Store::new(5)
  let root2 = mount_root([stepper(nv, min=0, max=10, step=2)], 300.0, 60.0)
  let sp = kid(root2, 0)
  assert_true(sp.focus_id > 0)
  key(root2, sp, @core.KS_RIGHT)
  assert_eq(nv.get(), 7)
  key(root2, sp, @core.KS_LEFT)
  assert_eq(nv.get(), 5)
  // 步进器只吃方向键（Home/End 走滑块），触界侧吃掉键但不改值
  key(root2, sp, @core.KS_HOME)
  assert_eq(nv.get(), 5)
  key(root2, sp, @core.KS_LEFT)
  key(root2, sp, @core.KS_LEFT)
  assert_eq(nv.get(), 1)
  key(root2, sp, @core.KS_LEFT)
  assert_eq(nv.get(), 0)
  key(root2, sp, @core.KS_LEFT)
  assert_eq(nv.get(), 0)
  let rv = @core.Store::new(3)
  let changes : Array[Int] = []
  let root3 = mount_root(
    [rate(rv, on_change=fn(x : Int) -> Unit { changes.push(x) })],
    200.0,
    40.0,
  )
  let rt = kid(root3, 0)
  assert_true(rt.focus_id > 0)
  key(root3, rt, @core.KS_RIGHT)
  assert_eq((rv.get(), changes.length()), (4, 1))
  key(root3, rt, @core.KS_END)
  assert_eq(rv.get(), 5)
  key(root3, rt, @core.KS_LEFT)
  assert_eq(rv.get(), 4)
  key(root3, rt, @core.KS_HOME)
  assert_eq(rv.get(), 1)
}

///|
test "键盘可及性：按钮空格/回车激活，禁用不吃键" {
  let n = Ref(0)
  let root = mount_root(
    [
      button("确定", on_click=fn() -> Unit { n.val = n.val + 1 }),
      button("禁用", disabled=true, on_click=fn() -> Unit { n.val = n.val + 10 }),
    ],
    300.0,
    60.0,
  )
  let b0 = kid(root, 0)
  let b1 = kid(root, 1)
  assert_true(b0.focus_id > 0 && b1.focus_id > 0)
  let _ = root.dispatch_key(b0.focus_id, { press: true, keysym: @core.KS_RETURN, mods: 0, })
  assert_eq(n.val, 1)
  let _ = root.dispatch_key(b0.focus_id, { press: true, keysym: @core.KS_SPACE, mods: 0, })
  assert_eq(n.val, 2)
  let _ = root.dispatch_key(b1.focus_id, { press: true, keysym: @core.KS_SPACE, mods: 0, })
  assert_eq(n.val, 2)
}

///|
test "键盘可及性：下拉选择空格开层、上下移高亮、回车回填、Esc 收层" {
  let v = @core.Store::new("")
  let (root, w) = mounted_with_overlay(
    select(["甲", "乙", "丙"], v, width=140.0),
    420.0,
    320.0,
  )
  assert_true(w.focus_id > 0)
  let key = fn(ks : Int) -> Unit {
    let _ = root.dispatch_key(w.focus_id, { press: true, keysym: ks, mods: 0, })
  }
  // 关着时下键也能开层
  key(@core.KS_DOWN)
  root.relayout(420.0, 320.0)
  assert_eq(@core.overlay_count(), 1)
  // ↓ 移到第 2 行，回车取高亮
  key(@core.KS_DOWN)
  key(@core.KS_RETURN)
  assert_eq((v.get(), @core.overlay_count()), ("乙", 0))
  // 空格再开（高亮先对到当前值所在行），Esc 收层不改值
  key(@core.KS_SPACE)
  root.relayout(420.0, 320.0)
  assert_eq(@core.overlay_count(), 1)
  key(@core.KS_ESCAPE)
  assert_eq((v.get(), @core.overlay_count()), ("乙", 0))
  @core.overlay_clear()
}

///|
test "键盘可及性：取色器回车开层、方向键移格、回车取色" {
  let v = @core.Store::new("")
  let (root, w) = mounted_with_overlay(
    color_picker(v, colors=["#111111", "#222222", "#333333"], width=160.0),
    420.0,
    320.0,
  )
  assert_true(w.focus_id > 0)
  let key = fn(ks : Int) -> Unit {
    let _ = root.dispatch_key(w.focus_id, { press: true, keysym: ks, mods: 0, })
  }
  key(@core.KS_RETURN)
  root.relayout(420.0, 320.0)
  assert_eq(@core.overlay_count(), 1)
  key(@core.KS_RIGHT)
  key(@core.KS_RETURN)
  assert_eq((v.get(), @core.overlay_count()), ("#222222", 0))
  @core.overlay_clear()
}
