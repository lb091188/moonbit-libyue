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
    popover(counter_box(clicks, 80.0, 24.0), text("弹层内容"), width=120.0, height=40.0),
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
    view(
      [
        popover(text("触发"), text("第一层"), width=100.0, height=30.0),
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
    dropdown("操作", ["重命名", "复制", "-", "删除"], on_select=fn(i : Int) -> Unit {
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
    tooltip(counter_box(Ref(0), 80.0, 24.0), "点这里", delay_ms=400),
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
    dialog(
      vis,
      "确认操作",
      [text("要删掉这一条吗？", font_size=12.0)],
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
    dialog(vis, "标题", [text("内容")], close_on_mask=true),
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
    dialog(vis3, "标题", [text("内容")], close_on_mask=false),
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
  let (root, _host) = mounted(view([text("宿主页")]), 400.0, 200.0)
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
  // 层本身按内容尺寸开：不铺满窗口（铺满=一整块盖住窗口的板）
  match @core.overlay_rect_of(@core.overlay_top_id()) {
    Some(r) => {
      assert_true(r.w > 0.0 && r.w < 400.0)
      assert_true(r.h > 0.0 && r.h < 200.0)
    }
    None => assert_true(false)
  }
  // 居中摆位（窗口原点取不到时按 0 宽算，落点就是左上）
  assert_eq(toast_left(400.0, 120.0), 140.0)
  assert_eq(toast_left(100.0, 120.0), 0.0)
  assert_eq(toast_left(0.0, 120.0), 0.0)
  // 到点自动撤：撤到最后一条时整层收起
  assert_eq(queue.val.length(), 2)
  (queue.val[0])()
  assert_eq(strip.children().length(), 1)
  assert_eq(@core.overlay_count(), 1)
  (queue.val[1])()
  assert_eq(strip.children().length(), 0)
  assert_eq(@core.overlay_count(), 0)
  // 第二轮推送：收层之后必须还能再开（真机反馈过「提示一个之后就无法触发」）
  push("第二轮", Info)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(400.0, 200.0)
  match @core.overlay_root_of(@core.overlay_top_id()) {
    Some(w) => assert_eq(w.children()[0].children().length(), 1)
    None => assert_true(false)
  }
  match @core.overlay_rect_of(@core.overlay_top_id()) {
    Some(r) => assert_true(r.w > 0.0 && r.h > 0.0)
    None => assert_true(false)
  }
  (queue.val[2])()
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
    dialog(vis, "标题", [text("内容")]),
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

///|
/// P2-e 口径：浮层族也走样式槽——触发件、菜单行、气泡与对话框面板的内置底色/描边
/// 先折进槽，`class` 的绘制期属性后落即覆盖（悬停底改由 hover 桶供）。
test "浮层族只读样式槽：class 覆盖下拉触发件、菜单行文字与对话框面板" {
  if !ui_text_guard() {
    return
  }
  let ink_in = fn(bm : @render.Bitmap, w : Int, h : Int, pick : (Int, Int, Int) -> Bool) -> Int {
    let mut n = 0
    for y = 0; y < h; y = y + 1 {
      for x = 0; x < w; x = x + 1 {
        let c = bm.pixel(x, y)
        if pick(c.r, c.g, c.b) {
          n = n + 1
        }
      }
    }
    n
  }
  let red = fn(r : Int, g : Int, b : Int) -> Bool {
    r > 128 && g < 64 && b < 64
  }
  let paint_count = fn(node : @core.Node, open_it : Bool) -> Int {
    let (root, kid) = mounted_with_overlay(node, 300.0, 200.0)
    if open_it {
      let _ = root.dispatch_pointer({
        kind: @core.Down,
        x: kid.rect.x + 8.0,
        y: kid.rect.y + 8.0,
        button: 1,
        mods: 0,
      })
      let _ = root.dispatch_pointer({
        kind: @core.Up,
        x: kid.rect.x + 8.0,
        y: kid.rect.y + 8.0,
        button: 1,
        mods: 0,
      })
      root.relayout(300.0, 200.0)
    }
    let bm = @render.Bitmap::new(300, 200)
    let p = @render.Painter::new(bm)
    root.paint(p)
    p.end()
    ink_in(bm, 300, 200, red)
  }
  // 触发件：class 的底色盖过内置 bg_panel
  let plain_closed = paint_count(
    dropdown("选项", ["甲", "乙"], width=120.0),
    false,
  )
  let classed_closed = paint_count(
    dropdown("选项", ["甲", "乙"], width=120.0, class=[@style.style(background_color="#ff0000")]),
    false,
  )
  assert_true(plain_closed == 0)
  assert_true(classed_closed > 60)
  // 展开后菜单行的文字色也吃同一份 class 的 color（skin 透进内部件）
  let classed_open = paint_count(
    dropdown(
      "选项",
      ["甲", "乙"],
      width=120.0,
      class=[@style.style(background_color="#ff0000", color="#ff0000")],
    ),
    true,
  )
  assert_true(classed_open > classed_closed)

  // 对话框面板：底色与圆角吃 class（内置是 bg_panel / 6px）
  let vis = @core.Store::new(true)
  let dlg_plain = paint_count(dialog(vis, "标题", [text("内容")]), false)
  let dlg_classed = paint_count(
    dialog(
      vis,
      "标题",
      [text("内容")],
      class=[@style.style(background_color="#ff0000")],
    ),
    false,
  )
  assert_true(dlg_classed > dlg_plain)
  @core.overlay_clear()
}

///|
/// 对话框观感回归：遮罩把面板外的底色压暗（视觉模态，EP 同款半透明黑）；
/// 面板圆角之外不再有直角描边墨（fill_round_rect 配 stroke_rect 的旧口径
/// 把圆角面板框成方角，真机截图反馈）。
test "对话框：遮罩暗化、面板圆角外无描边墨" {
  if !ui_text_guard() {
    return
  }
  let vis = @core.Store::new(true)
  let (root, _kid) = mounted_with_overlay(
    dialog(vis, "标题", [text("内容")], width=200.0),
    400.0,
    300.0,
  )
  // 根先铺白底：遮罩外角落才有「页面底色」可压暗（无头根默认不画底）
  root.on_draw = Some(fn(
    _w : @core.Widget,
    p : @render.Painter,
    r : @core.Rect,
  ) -> Unit {
    p.set_fill_color("#ffffff")
    p.fill_rect(0.0, 0.0, r.w, r.h)
  })
  root.relayout(400.0, 300.0)
  let bm = @render.Bitmap::new(400, 300)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  // 窗口角落（面板外）：白底被半透明黑罩压暗，不再是白（无遮罩时三和 ≈765）
  let (mr, mg, mb, _ma) = color_of(bm, 4, 4)
  assert_true(mr + mg + mb < 600)
  // 扫面板（纯白 bg_panel）包围盒：左上角真原点在圆角外，应露出遮罩色；
  // 旧口径直角描边会在角上落一圈浅灰边框墨（三和 ≈660）
  let mut min_x = -1
  let mut min_y = -1
  let mut max_x = -1
  for y = 0; y < 300; y = y + 1 {
    for x = 0; x < 400; x = x + 1 {
      let (cr, cg, cb, _ca) = color_of(bm, x, y)
      if cr > 250 && cg > 250 && cb > 250 {
        if min_x < 0 {
          min_x = x
          min_y = y
        }
        max_x = x
      }
    }
  }
  assert_true(min_x > 2 && max_x < 397)
  let (cr, cg, cb, _ca) = color_of(bm, min_x - 2, min_y - 2)
  assert_true(cr + cg + cb < 500)
  // 圆角内侧应是面板底色（白）
  let (ir, ig, ib, _ia) = color_of(bm, min_x + 2, min_y + 2)
  assert_true(ir > 250 && ig > 250 && ib > 250)
  @core.overlay_clear()
}

///|
test "键盘可及性：下拉菜单下键开菜单、上下移高亮（分隔线不占位）、回车取项、Esc 收起" {
  let picks : Array[Int] = []
  let (root, w) = mounted_with_overlay(
    dropdown(
      "菜单",
      ["甲", "-", "乙"],
      on_select=fn(i : Int) -> Unit { picks.push(i) },
      width=120.0,
    ),
    300.0,
    240.0,
  )
  assert_true(w.focus_id > 0)
  let key = fn(ks : Int) -> Unit {
    let _ = root.dispatch_key(w.focus_id, { press: true, keysym: ks, mods: 0, })
  }
  key(@core.KS_DOWN)
  root.relayout(300.0, 240.0)
  assert_eq(@core.overlay_count(), 1)
  key(@core.KS_DOWN)
  key(@core.KS_RETURN)
  // 高亮按行序（分隔线不占位），picks 存的是 items 下标：第 2 行=「乙」=items[2]
  assert_eq((picks, @core.overlay_count()), ([2], 0))
  key(@core.KS_SPACE)
  root.relayout(300.0, 240.0)
  assert_eq(@core.overlay_count(), 1)
  key(@core.KS_ESCAPE)
  assert_eq(@core.overlay_count(), 0)
  @core.overlay_clear()
}

///|
/// 轻提示在屏时点浮层外：点击放行给页面控件（toast 无「点外收起」语义，图层
/// 不得吞掉这一击、也不得误收提示层）；对照：默认层（dismiss 语义）仍吞击收层。
test "轻提示层不吞点外点击，普通浮层照旧点外收起" {
  let got : Ref[Int] = Ref(0)
  let btn = @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    w.node.set_width(@yoga.fixed(120.0))
    w.node.set_height(@yoga.fixed(40.0))
    w.on_pointer = Some(fn(_s : @core.Widget, ev : @core.PointerEvent) -> Bool {
      match ev.kind {
        @core.Down => {
          got.val = got.val + 1
          true
        }
        _ => false
      }
    })
    w
  })
  // 按钮垫高到 y=64..104：轻提示带占顶部 y=0..42，点击 (10,84) 落在提示外、按钮上
  let pad = @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    w.node.set_height(@yoga.fixed(64.0))
    w
  })
  let (root, _host) = mounted(view([pad, btn], width=200.0, height=104.0), 400.0, 200.0)
  with_overlay(root)
  root.relayout(400.0, 200.0)
  // 轻提示层（dismiss_on_outside=false）：开在顶部，点底部按钮（浮层外）
  let queue : Ref[Array[() -> Unit]] = Ref([])
  @core.set_timer_hooks(
    fn(_ms : Int, f : () -> Unit) -> Int {
      queue.val.push(f)
      1
    },
    fn(_id : Int) -> Unit { () },
  )
  let push = toast_layer(duration_ms=60000)
  push("保存成功", Success)
  assert_eq(@core.overlay_count(), 1)
  let _ = @core.route_pointer(
    root,
    { kind: @core.Down, x: 10.0, y: 84.0, button: 1, mods: 0 },
    0,
    0,
  )
  assert_eq(got.val, 1, msg="轻提示在屏时点外点击应放行给页面控件")
  assert_eq(@core.overlay_count(), 1, msg="点外点击不得误收轻提示层")
  // 普通层（默认 dismiss）：同样点外，点击被图层消费、页面控件收不到
  let got2 : Ref[Int] = Ref(0)
  let btn2 = @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    w.node.set_width(@yoga.fixed(120.0))
    w.node.set_height(@yoga.fixed(40.0))
    w.on_pointer = Some(fn(_s : @core.Widget, ev : @core.PointerEvent) -> Bool {
      match ev.kind {
        @core.Down => {
          got2.val = got2.val + 1
          true
        }
        _ => false
      }
    })
    w
  })
  let pad2 = @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    w.node.set_height(@yoga.fixed(64.0))
    w
  })
  let (root2, _h2) = mounted(view([pad2, btn2], width=200.0, height=104.0), 400.0, 200.0)
  with_overlay(root2)
  root2.relayout(400.0, 200.0)
  let _ = @core.overlay_show_at(text("模态面板"), 150.0, 20.0)
  assert_eq(@core.overlay_count(), 1)
  let (_h3, _c3, _u3, _g3) = @core.route_pointer(
    root2,
    { kind: @core.Down, x: 10.0, y: 84.0, button: 1, mods: 0 },
    0,
    0,
  )
  assert_eq(got2.val, 0, msg="普通浮层的点外点击仍被图层消费")
}
