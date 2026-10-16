// 日期/时间选择器回归：字段弹层开合、点选回填、✕ 清空、区间两段式、
// 时间步进与确定写回。弹层都在浮层图层上，用例先装宿主。

///|
/// 选择器弹层里的日历面板（图层第 id 层的第一块）。
fn picker_panel(id : Int) -> @core.Widget {
  match @core.overlay_root_of(id) {
    Some(w) => w.children()[0]
    None => @core.Widget::new()
  }
}

///|
test "日期选择器：字段显示占位、点开日历、点选回填并收起、✕ 清空" {
  let v : @core.Store[DateYMD?] = @core.Store::new(None)
  let changes : Array[String] = []
  let (root, field) = mounted_with_overlay(
    date_picker(
      v,
      on_change=fn(d : DateYMD) -> Unit { changes.push(d.format()) },
      today=d(2026, 10, 11),
      width=180.0,
    ),
    400.0,
    300.0,
  )
  assert_eq(field.rect.w, 180.0)
  assert_eq(@core.overlay_count(), 0)
  click_at(root, field, 40.0, 16.0)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(400.0, 300.0)
  // 弹层挂在字段下方 2px
  match @core.overlay_rect_of(@core.overlay_top_id()) {
    Some(r) => assert_eq((r.x, r.y), (field.rect.x, field.rect.y + field.rect.h + 2.0))
    None => assert_true(false)
  }
  // 点第 14 格（10 月 11 日，first_wd=4）
  let panel = picker_panel(@core.overlay_top_id())
  click_at(root, cell_at(panel, 14), 18.0, 15.0)
  assert_eq(changes, ["2026-10-11"])
  match v.get() {
    Some(x) => assert_eq(x.format(), "2026-10-11")
    None => assert_true(false)
  }
  assert_eq(@core.overlay_count(), 0)
  // 再开再关：点字段第二次收起
  click_at(root, field, 40.0, 16.0)
  assert_eq(@core.overlay_count(), 1)
  click_at(root, field, 40.0, 16.0)
  assert_eq(@core.overlay_count(), 0)
  // 点浮层外收起（图层代劳，组件句柄就此失效）后再点字段，一击即开
  click_at(root, field, 40.0, 16.0)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(400.0, 300.0)
  let _ = root.dispatch_pointer({ kind: @widget.PointerKind::Down, x: 380.0, y: 280.0, button: 1, mods: 0 })
  let _ = root.dispatch_pointer({ kind: @widget.PointerKind::Up, x: 380.0, y: 280.0, button: 1, mods: 0 })
  assert_eq(@core.overlay_count(), 0)
  click_at(root, field, 40.0, 16.0)
  assert_eq(@core.overlay_count(), 1)
  @core.overlay_clear()
  // ✕ 清空：悬停才有热区
  root.set_hover(field.id)
  click_at(root, field, 154.0, 16.0)
  assert_eq(sel_str(v), "-")
  assert_eq(changes.length(), 1)
}

///|
test "日期区间选择器：先点起点再点终点，写回整段并收起" {
  let v : @core.Store[DateRange] = @core.Store::new({ start: None, end: None })
  let changes : Array[String] = []
  let (root, field) = mounted_with_overlay(
    date_range_picker(
      v,
      on_change=fn(r : DateRange) -> Unit {
        let s = match r.start {
          Some(x) => x.format()
          None => "?"
        }
        let e = match r.end {
          Some(x) => x.format()
          None => "?"
        }
        changes.push(s + "~" + e)
      },
      today=d(2026, 10, 11),
      width=220.0,
    ),
    400.0,
    300.0,
  )
  click_at(root, field, 40.0, 16.0)
  root.relayout(400.0, 300.0)
  let panel = picker_panel(@core.overlay_top_id())
  // 起点 = 10 月 3 日（第 6 格），终点 = 10 月 7 日（第 10 格）
  click_at(root, cell_at(panel, 6), 18.0, 15.0)
  assert_eq(changes.length(), 0)
  match v.get().start {
    Some(x) => assert_eq(x.format(), "2026-10-03")
    None => assert_true(false)
  }
  assert_eq(@core.overlay_count(), 1)
  click_at(root, cell_at(panel, 10), 18.0, 15.0)
  assert_eq(changes, ["2026-10-03~2026-10-07"])
  assert_eq(@core.overlay_count(), 0)
}

///|
test "时间区间：步进器改值、确定写回、取消不改" {
  let v : @core.Store[TimeRange] = @core.Store::new({ start: Some(TimeHM::{ h: 9, m: 0 }), end: None })
  let changes : Array[String] = []
  let (root, row) = mounted_with_overlay(
    time_range_picker(
      v,
      on_change=fn(r : TimeRange) -> Unit {
        let f = fn(t : TimeHM?) -> String {
          match t {
            Some(x) => x.format()
            None => "-"
          }
        }
        changes.push(f(r.start) + "~" + f(r.end))
      },
      width=110.0,
    ),
    400.0,
    300.0,
  )
  let start_field = row.children()[0]
  click_at(root, start_field, 40.0, 16.0)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(400.0, 300.0)
  let panel = picker_panel(@core.overlay_top_id())
  // 面板子项：标题 28 / 时步进 32 / 分步进 32 / 按钮行 32（标题是占位子件，
  // 所以步进行从索引 1 起）
  let hour_row = panel.children()[1]
  let plus_hour = hour_row.children()[2]
  click_at(root, plus_hour, 15.0, 14.0)
  click_at(root, plus_hour, 15.0, 14.0)
  // 确定：按钮行第 2 个
  let btn_row = panel.children()[3]
  click_at(root, btn_row.children()[1], 30.0, 14.0)
  assert_eq(changes, ["11:00~-"])
  match v.get().start {
    Some(t) => assert_eq(t.format(), "11:00")
    None => assert_true(false)
  }
  // 取消路径：改完不确认，Store 不变
  click_at(root, start_field, 40.0, 16.0)
  root.relayout(400.0, 300.0)
  let panel2 = picker_panel(@core.overlay_top_id())
  click_at(root, panel2.children()[1].children()[2], 15.0, 14.0)
  click_at(root, panel2.children()[3].children()[0], 30.0, 14.0)
  assert_eq(changes.length(), 1)
  match v.get().start {
    Some(t) => assert_eq(t.format(), "11:00")
    None => assert_true(false)
  }
}

///|
test "日期时间区间：日期走日历、时间走步进，两侧各写各的" {
  let v : @core.Store[DateTimeRange] = @core.Store::new({ start: None, end: None })
  let changes : Array[Int] = []
  let (root, row) = mounted_with_overlay(
    datetime_range_picker(
      v,
      on_change=fn(_r : DateTimeRange) -> Unit { changes.push(1) },
      today=d(2026, 10, 11),
      date_width=130.0,
      time_width=86.0,
    ),
    500.0,
    300.0,
  )
  // 四个字段：起日期 / 起时间 / ~ / 止日期 / 止时间
  assert_eq(row.children().length(), 5)
  let start_date = row.children()[0]
  click_at(root, start_date, 30.0, 16.0)
  root.relayout(500.0, 300.0)
  click_at(root, cell_at(picker_panel(@core.overlay_top_id()), 14), 18.0, 15.0)
  match v.get().start {
    Some(p) => {
      assert_eq(p.0.format(), "2026-10-11")
      assert_eq(p.1.format(), "09:00")
    }
    None => assert_true(false)
  }
  assert_eq(changes.length(), 1)
  // 起点时间：步进 +1 小时后确定
  let start_time = row.children()[1]
  click_at(root, start_time, 30.0, 16.0)
  root.relayout(500.0, 300.0)
  let panel = picker_panel(@core.overlay_top_id())
  click_at(root, panel.children()[1].children()[2], 15.0, 14.0)
  click_at(root, panel.children()[3].children()[1], 30.0, 14.0)
  match v.get().start {
    Some(p) => assert_eq(p.1.format(), "10:00")
    None => assert_true(false)
  }
  assert_eq(changes.length(), 2)
}

///|
/// P2-e 口径：日期选择的字段、日历面板、箭头与日期格都只读样式槽——
/// 内置皮肤先折进槽，`class` 的同名属性覆盖；日期格的悬停底走 hover 桶，
/// 「选中 / 区间内 / 今天」这些数据态配色留内置当回落值。
test "日期选择只读样式槽：class 覆盖字段底、日历面板与箭头悬停底" {
  if !ui_text_guard() {
    return
  }
  let red_count = fn(bm : @render.Bitmap, w : Int, h : Int) -> Int {
    let mut n = 0
    for y = 0; y < h; y = y + 1 {
      for x = 0; x < w; x = x + 1 {
        let c = bm.pixel(x, y)
        if c.r > 128 && c.g < 64 && c.b < 64 {
          n = n + 1
        }
      }
    }
    n
  }
  let paint_count = fn(node : @core.Node, open_it : Bool) -> Int {
    let (root, field) = mounted_with_overlay(node, 420.0, 360.0)
    if open_it {
      let _ = root.dispatch_pointer({
        kind: @widget.PointerKind::Down,
        x: field.rect.x + 40.0,
        y: field.rect.y + 16.0,
        button: 1,
        mods: 0,
      })
      let _ = root.dispatch_pointer({
        kind: @widget.PointerKind::Up,
        x: field.rect.x + 40.0,
        y: field.rect.y + 16.0,
        button: 1,
        mods: 0,
      })
      root.relayout(420.0, 360.0)
    }
    let bm = @render.Bitmap::new(420, 360)
    let p = @render.Painter::new(bm)
    root.paint(p)
    p.end()
    red_count(bm, 420, 360)
  }
  let v : @core.Store[DateYMD?] = @core.Store::new(None)
  let mk = fn(cls : Array[@style.Style]) -> @core.Node {
    date_picker(v, today=d(2026, 11, 11), width=180.0, class=cls)
  }
  // 字段底色：内置是 bg_panel（无红），class 换成红
  assert_true(paint_count(mk([]), false) == 0)
  assert_true(paint_count(mk([@style.style(background_color="#ff0000")]), false) > 200)
  // 展开的日历面板底色也吃同一份 class 投影（skin 透进弹层）
  assert_true(
    paint_count(mk([@style.style(background_color="#ff0000")]), true) > 1000,
  )
}

///|
test "时间弹层：顶部时间是占位的子件，第一行步进不被压住" {
  let n = time_popup(TimeHM::{ h: 9, m: 0 }, fn(_) { () }, fn() { () })
  let root = @core.Widget::new()
  root.set_size(300.0, 300.0)
  root.set_column()
  let panel = n.mount_into(root)
  root.relayout(300.0, 300.0)
  let kids = panel.children()
  assert_eq(kids.length(), 4)
  // 旧形态把时间画在面板 (0,0,28) 上、不占布局：第一行步进从 y=10 起被压住
  assert_eq((kids[0].rect.y, kids[0].rect.h), (10.0, 28.0))
  let mut prev_end = 0.0
  for c in kids {
    assert_true(c.rect.y >= prev_end, msg="弹层子件纵向重叠")
    prev_end = c.rect.y + c.rect.h
  }
  assert_true(panel.rect.h >= prev_end + 10.0, msg="弹层高度没包住内容")
}

///|
test "键盘可及性：日期字段回车/空格开日历、Esc 收起" {
  let v : @core.Store[DateYMD?] = @core.Store::new(None)
  let (root, w) = mounted_with_overlay(date_picker(v), 400.0, 400.0)
  assert_true(w.focus_id > 0)
  let _ = root.dispatch_key(w.focus_id, { press: true, keysym: @core.KS_RETURN, mods: 0, })
  root.relayout(400.0, 400.0)
  assert_eq(@core.overlay_count(), 1)
  let _ = root.dispatch_key(w.focus_id, { press: true, keysym: @core.KS_ESCAPE, mods: 0, })
  assert_eq(@core.overlay_count(), 0)
  assert_true(match v.get() {
    None => true
    Some(_) => false
  })
  @core.overlay_clear()
}
