// 浮层原生档的无头回归：档位判定、内容量尺、收框与清理路径。
// 「弹层真能盖住网页」由 modules/gui-examples/native-web 的桥接窗回证（AGENTS 规则 6）。

///|
fn fake_host_app() -> App {
  let w : @win.Window = { id: 900L, width: 400, height: 300 }
  let root = Widget::new()
  {
    window: w,
    sched: Loop::new(),
    root,
    focus: FocusStack::new(),
    host: make_overlay_host(root),
    wid: 1,
    primary: true,
    closed: false,
    dirty: false,
    running: true,
    last_preedit: ("", 0),
    ime_focus: 0,
    hover_id: -1,
    capture: -1,
    cursor_kind: 0,
    canvas: None,
  }
}

///|
test "档位判定：所在窗没有已挂载子件时走图层档" {
  host_reset()
  let a = fake_host_app()
  host_add(a, true)
  set_overlay_provider(fn() -> OverlayHost? { Some(a.host) })
  // 假窗句柄越界，桩里所有 wm_* 早退 → 子件数恒 0 → 不走原生档
  assert_eq(a.window.has_child_surfaces(), false)
  assert_eq(overlay_native_tier(), false)
  assert_eq(overlay_native_count(), 0)
  // 图层档照常工作
  let cid = overlay_show_at(
    node_of_new(fn(p : Widget) -> Widget {
      let k = Widget::new()
      k.set_size(60.0, 20.0)
      p.append_child(k)
      k
    }),
    10.0,
    10.0,
  )
  assert_true(cid > 0)
  assert_eq(overlay_count(), 1)
  assert_eq(a.host.items.length(), 1)
  overlay_hide(cid)
  assert_eq(overlay_count(), 0)
  assert_eq(a.host.items.length(), 0)
  // 关不存在的原生档句柄是空操作；清空也不炸
  overlay_hide(cid)
  overlay_close_all_native()
  assert_eq(overlay_native_count(), 0)
  host_reset()
}

///|
test "内容量尺：取可见子项的右/下边界，隐藏项不算" {
  let a = fake_host_app()
  let one = Widget::new()
  one.set_size(120.0, 40.0)
  let two = Widget::new()
  two.set_size(60.0, 90.0)
  a.root.append_child(one)
  a.root.append_child(two)
  a.root.set_size(500.0, 400.0)
  a.root.relayout(500.0, 400.0)
  assert_true(one.rect.w > 0.0)
  let (w, h) = overlay_content_size(a)
  assert_true(w >= 120 && w < 500)
  assert_true(h >= 90 && h < 400)
  // 全隐藏后量不到东西（返回 0，调用方因此不改窗尺寸）
  one.set_visible(false)
  two.set_visible(false)
  a.root.relayout(500.0, 400.0)
  let (w2, h2) = overlay_content_size(a)
  assert_eq(w2, 0)
  assert_eq(h2, 0)
}

///|
test "失焦与收框：没有原生档浮层时两条路径都是空操作" {
  host_reset()
  let a = fake_host_app()
  host_add(a, true)
  overlay_on_lost_focus(a)
  overlay_fit_pass(a)
  assert_eq(overlay_native_count(), 0)
  assert_eq(a.host.items.length(), 0)
  host_reset()
}
