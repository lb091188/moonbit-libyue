// 浮层回归：空图层不挡内容、开层/收起、点浮层外收起、下拉菜单回调与分隔线、
// 悬浮提示的延时与离开即收。浮层宿主是进程级单槽，用例开头先清干净。

///|
/// 给测试根装浮层宿主（内容树里的图层由 App 装，无头用例手动装）。
fn with_overlay(root : @core.Widget) -> Unit {
  @core.set_overlay_host(@core.make_overlay_host(root))
  @core.overlay_clear()
}

///|
/// 一个只记点击次数的小控件（用来验「空图层不挡内容」）。
fn counter_box(n : Ref[Int], w : Double, h : Double) -> @core.Node {
  @core.node_of_new(fn(b : @core.Widget) -> @core.Widget {
    b.node.set_width(@yoga.fixed(w))
    b.node.set_height(@yoga.fixed(h))
    b.on_pointer = Some(fn(
      _self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Down => true
        @core.Up => {
          n.val = n.val + 1
          false
        }
        _ => false
      }
    })
    b
  })
}

///|
test "空图层不挡内容；点触发件开层、再点收起" {
  let clicks = Ref(0)
  let (root, wrap) = mounted(
    popover_t(counter_box(clicks, 80.0, 24.0), label("弹层内容"), width=120.0, height=40.0),
    300.0,
    200.0,
  )
  with_overlay(root)
  assert_eq(@core.overlay_count(), 0)
  assert_eq(@core.overlay_visible(), false)
  // 图层铺满窗口但不可见：点击照常落到内容上
  let trigger = wrap.children()[0]
  click_at(root, trigger, 10.0, 10.0)
  assert_eq(clicks.val, 1)
  assert_eq(@core.overlay_count(), 1)
  assert_eq(@core.overlay_visible(), true)
  // 浮层是刚挂上的子控件：矩形要等下一次布局（真窗口里宿主每帧都会重排）
  root.relayout(300.0, 200.0)
  // 浮层挂在触发件下方（距下沿 2px）
  match @core.overlay_rect_of(1) {
    Some(r) => {
      assert_eq((r.x, r.y), (trigger.rect.x, trigger.rect.y + trigger.rect.h + 2.0))
      assert_eq((r.w, r.h), (120.0, 40.0))
    }
    None => assert_true(false)
  }
  root.relayout(300.0, 200.0)
  // 再点触发件：这一击被图层消费（先收起浮层，不漏给内容），所以触发件内部
  // 的计数不涨——「点外面先关浮层」的标准口径
  click_at(root, trigger, 10.0, 10.0)
  assert_eq(clicks.val, 1)
  assert_eq(@core.overlay_count(), 0)
  assert_eq(@core.overlay_visible(), false)
  // 收起之后再点内容照常计数
  click_at(root, trigger, 10.0, 10.0)
  assert_eq(clicks.val, 2)
}

///|
test "点浮层外收起最上面那层（不打扰被点的内容）" {
  let clicks = Ref(0)
  let (root, wrap) = mounted(
    container(
      [
        popover_t(label("触发"), label("第一层"), width=100.0, height=30.0),
        counter_box(clicks, 60.0, 20.0),
      ],
      row_gap=30.0,
      align_items=@yoga.AlignItems::FlexStart,
    ),
    300.0,
    240.0,
  )
  with_overlay(root)
  let trigger = wrap.children()[0].children()[0]
  let other = wrap.children()[1]
  click_at(root, trigger, 10.0, 10.0)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(300.0, 240.0)
  // 点浮层外：图层在抬起时收起它，并且这一击不再落到下面的内容
  click_at(root, other, 10.0, 10.0)
  assert_eq(@core.overlay_count(), 0)
  assert_eq(clicks.val, 0)
  // 收起后再点内容正常
  click_at(root, other, 10.0, 10.0)
  assert_eq(clicks.val, 1)
}

///|
test "下拉菜单：'-' 画分隔线、选中回调序号并收起" {
  let picks : Array[Int] = []
  let (root, menu) = mounted(
    dropdown_menu("操作", ["重命名", "复制", "-", "删除"], on_select=fn(i : Int) -> Unit {
      picks.push(i)
    }),
    300.0,
    200.0,
  )
  with_overlay(root)
  click_at(root, menu, 10.0, 10.0)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(300.0, 200.0)
  // 4 项里有一项是分隔线（面板子项数仍是 4：分隔线也占一项）
  let rows = match @core.overlay_root_of(1) {
    Some(w) => w.children()[0].children()
    None => []
  }

  assert_eq(rows.length(), 4)
  // 第 3 项是分隔线（1px 高、无指针回调：事件冒到图层也落在浮层内）
  assert_eq(rows[2].rect.h, 1.0)
  click_at(root, rows[1], 20.0, 10.0)
  assert_eq(picks.length(), 1)
  assert_eq(picks[0], 1)
  assert_eq(@core.overlay_count(), 0)
}

///|
test "悬浮提示：延时到点才出现、离开即收、延时未到就离开则不出现" {
  let queue : Ref[Array[() -> Unit]] = Ref([])
  @core.set_timer_hooks(
    fn(_ms : Int, f : () -> Unit) -> Int {
      queue.val.push(f)
      1
    },
    fn(_id : Int) -> Unit { () },
  )
  let (root, wrap) = mounted(
    tooltip_t(counter_box(Ref(0), 80.0, 24.0), "点这里", delay_ms=400),
    300.0,
    200.0,
  )
  with_overlay(root)
  let anchor = wrap.children()[0]
  // 指针移进（宿主口径：悬停归属变化）：只排延时，气泡还没出现
  root.set_hover(anchor.id)
  assert_eq(@core.overlay_count(), 0)
  assert_eq(queue.val.length(), 1)
  // 离开：延时取消
  root.set_hover(0)
  assert_eq(queue.val.length(), 1)
  // 再移进并让延时到点：气泡出现在锚点下方
  root.set_hover(anchor.id)
  assert_eq(queue.val.length(), 2)
  (queue.val[1])()
  assert_eq(@core.overlay_count(), 1)
  root.relayout(300.0, 200.0)
  match @core.overlay_rect_of(1) {
    Some(r) => assert_eq((r.x, r.y), (anchor.rect.x, anchor.rect.y + anchor.rect.h + 4.0))
    None => assert_true(false)
  }
  // 指针离开：气泡收起
  root.set_hover(0)
  assert_eq(@core.overlay_count(), 0)
  @core.set_timer_hooks(fn(_ms, _f) { 0 }, fn(_id) { () })
}
