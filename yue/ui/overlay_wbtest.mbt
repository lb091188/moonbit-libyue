// 浮层回归：空图层不挡内容、开层/收起、点浮层外收起、下拉菜单回调与分隔线、
// 悬浮提示的延时与离开即收。浮层宿主是进程级单槽，用例开头先清干净。

///|
/// 给测试根装浮层宿主（内容树里的图层由 App 装，无头用例手动装）。
fn with_overlay(root : @core.Widget) -> Unit {
  @core.set_overlay_host(@core.make_overlay_host(root))
  @core.overlay_clear()
}

///|
/// 先在根上装好浮层宿主，再把节点挂进去（对话框这类「挂载即按 Store 开层」的
/// 组件要求宿主先就位；真窗口里 App::new 先建宿主、内容后挂）。
fn mounted_with_overlay(
  node : @core.Node,
  w : Double,
  h : Double,
) -> (@core.Widget, @core.Widget) {
  let root = @core.Widget::new()
  root.set_size(w, h)
  root.set_column()
  root.node.set_align_items(@yoga.AlignItems::FlexStart)
  with_overlay(root)
  let kid = node.mount_into(root)
  root.relayout(w, h)
  (root, kid)
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
  match @core.overlay_rect_of(@core.overlay_top_id()) {
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
  if !ui_text_guard() {
    return
  }
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
  let rows = match @core.overlay_root_of(@core.overlay_top_id()) {
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
  match @core.overlay_rect_of(@core.overlay_top_id()) {
    Some(r) => assert_eq((r.x, r.y), (anchor.rect.x, anchor.rect.y + anchor.rect.h + 4.0))
    None => assert_true(false)
  }
  // 指针离开：气泡收起
  root.set_hover(0)
  assert_eq(@core.overlay_count(), 0)
  @core.set_timer_hooks(fn(_ms, _f) { 0 }, fn(_id) { () })
}

///|
test "对话框：Store 驱动弹收，确定/取消/✕ 都先收起再回调" {
  if !ui_text_guard() {
    return
  }
  let vis = @core.Store::new(false)
  let acts : Array[String] = []
  let (root, _anchor) = mounted_with_overlay(
    dialog_t(
      vis,
      "确认操作",
      [label("要删掉这一条吗？", size=12.0)],
      on_confirm=fn() -> Unit { acts.push("ok") },
      on_cancel=fn() -> Unit { acts.push("cancel") },
    ),
    400.0,
    300.0,
  )
  assert_eq(@core.overlay_count(), 0)
  vis.set(true)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(400.0, 300.0)
  let scrim = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0]
    None => @core.Widget::new()
  }
  // 遮罩铺满整窗（宽度靠 100% 而不是内容撑）、面板居中
  assert_eq(scrim.rect.w, 400.0)
  assert_eq(scrim.rect.h, 300.0)
  let panel = scrim.children()[0]
  assert_eq(panel.rect.w, 420.0)
  // 面板在遮罩里居中（本用例窗口只有 400 宽，面板比窗口宽、中心仍对齐）
  assert_eq(panel.rect.x + panel.rect.w / 2.0, scrim.rect.w / 2.0)
  assert_eq(panel.rect.y + panel.rect.h / 2.0, scrim.rect.h / 2.0)
  let footer = panel.children()[3]
  assert_eq(footer.children().length(), 2)
  // 取消：回调 + 收起 + Store 归假
  click_at(root, footer.children()[0], 20.0, 14.0)
  assert_eq(acts, ["cancel"])
  assert_eq(@core.overlay_count(), 0)
  assert_eq(vis.get(), false)
  // 再开一次，点确定
  vis.set(true)
  root.relayout(400.0, 300.0)
  let scrim2 = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0]
    None => @core.Widget::new()
  }
  let footer2 = scrim2.children()[0].children()[3]
  click_at(root, footer2.children()[1], 20.0, 14.0)
  assert_eq(acts, ["cancel", "ok"])
  assert_eq(vis.get(), false)
}

///|
test "对话框：✕ 收起、遮罩点击按 close_on_mask 决定收不收" {
  let vis = @core.Store::new(true)
  let (root, _a) = mounted_with_overlay(
    dialog_t(vis, "标题", [label("内容")], close_on_mask=true),
    400.0,
    300.0,
  )
  assert_eq(@core.overlay_count(), 1)
  root.relayout(400.0, 300.0)
  let scrim = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0]
    None => @core.Widget::new()
  }
  // ✕ 在标题栏右上角：收掉
  let close_btn = scrim.children()[0].children()[1]
  click_at(root, close_btn, 12.0, 12.0)
  assert_eq(@core.overlay_count(), 0)
  // 换 close_on_mask=false 的形态：点遮罩角落不收
  let vis3 = @core.Store::new(true)
  let (root3, _b) = mounted_with_overlay(
    dialog_t(vis3, "标题", [label("内容")], close_on_mask=false),
    400.0,
    300.0,
  )
  assert_eq(@core.overlay_count(), 1)
  root3.relayout(400.0, 300.0)
  let top = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0]
    None => @core.Widget::new()
  }
  click_at(root3, top, 5.0, 5.0)
  assert_eq(@core.overlay_count(), 1)
  assert_eq(vis3.get(), true)
}

///|
test "轻提示层：推送后挂一条、到点自动撤、宽度随文本" {
  if !ui_text_guard() {
    return
  }
  let queue : Ref[Array[() -> Unit]] = Ref([])
  @core.set_timer_hooks(
    fn(_ms : Int, f : () -> Unit) -> Int {
      queue.val.push(f)
      1
    },
    fn(_id : Int) -> Unit { () },
  )
  let push = toast_layer(duration_ms=1000)
  let (root, _host) = mounted(container([label("宿主页")]), 400.0, 200.0)
  with_overlay(root)
  // 提示带子开在浮层图层上：推送后才开层
  push("保存成功", Success)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(400.0, 200.0)
  let strip = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0]
    None => @core.Widget::new()
  }

  assert_eq(strip.children().length(), 1)
  let w1 = strip.children()[0].rect.w
  push("这是一条更长的提示文字", Warning)
  assert_eq(strip.children().length(), 2)
  root.relayout(400.0, 200.0)
  assert_true(strip.children()[1].rect.w > w1)
  // 到点自动撤：撤到最后一条时整层收起
  assert_eq(queue.val.length(), 2)
  (queue.val[0])()
  assert_eq(strip.children().length(), 1)
  assert_eq(@core.overlay_count(), 1)
  (queue.val[1])()
  assert_eq(strip.children().length(), 0)
  assert_eq(@core.overlay_count(), 0)
  @core.set_timer_hooks(fn(_ms, _f) { 0 }, fn(_id) { () })
}

///|
test "右键上下文菜单：在指针处弹出、点项回调并收起" {
  let picks : Array[Int] = []
  let (root, wrap) = mounted(
    context_menu_for(counter_box(Ref(0), 120.0, 40.0), [
      ("复制", fn() -> Unit { picks.push(1) }),
      ("-", fn() -> Unit { picks.push(2) }),
      ("删除", fn() -> Unit { picks.push(3) }),
    ]),
    400.0,
    300.0,
  )
  with_overlay(root)
  // 右键（button 3）在包装控件内部 (30, 10) 处
  let _ = root.dispatch_pointer({
    kind: @core.Down,
    x: wrap.rect.x + 30.0,
    y: wrap.rect.y + 10.0,
    button: 3,
    mods: 0,
  })
  assert_eq(@core.overlay_count(), 1)
  root.relayout(400.0, 300.0)
  // 弹在指针处（窗口坐标）
  match @core.overlay_rect_of(@core.overlay_top_id()) {
    Some(r) => assert_eq((r.x, r.y), (wrap.rect.x + 30.0, wrap.rect.y + 10.0))
    None => assert_true(false)
  }
  let rows = match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => w.children()[0].children()
    None => []
  }
  assert_eq(rows.length(), 3)
  click_at(root, rows[2], 20.0, 10.0)
  assert_eq(picks, [3])
  assert_eq(@core.overlay_count(), 0)
}

///|
test "轻提示开在对话框之上（图层条目后开者在上）" {
  let vis = @core.Store::new(false)
  let (_root, _a) = mounted_with_overlay(
    dialog_t(vis, "标题", [label("内容")]),
    400.0,
    300.0,
  )
  let push = toast_layer(duration_ms=5000)
  vis.set(true)
  assert_eq(@core.overlay_count(), 1)
  push("对话框开着时的提示", Success)
  assert_eq(@core.overlay_count(), 2)
  // 句柄表按开层先后排列：排在后面的画在上层（句柄是进程级递增的，别写死数字）
  let ids = @core.overlay_ids()
  assert_eq(ids.length(), 2)
  assert_eq(@core.overlay_top_id(), ids[1])
  assert_eq(
    match @core.overlay_rect_of(ids[0]) {
      Some(_) => true
      None => false
    },
    true,
  )
  @core.set_timer_hooks(fn(_ms, _f) { 0 }, fn(_id) { () })
}
