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
    date_picker_t(
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
  match @core.overlay_rect_of(1) {
    Some(r) => assert_eq((r.x, r.y), (field.rect.x, field.rect.y + field.rect.h + 2.0))
    None => assert_true(false)
  }
  // 点第 14 格（10 月 11 日，first_wd=4）
  let panel = picker_panel(1)
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
    date_range_picker_t(
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
  let panel = picker_panel(1)
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
    time_range_picker_t(
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
  let panel = picker_panel(1)
  // 面板：标题 28 + 时步进 32 + 分步进 32 + 按钮行 32（子项顺序 = 追加顺序）
  let hour_row = panel.children()[0]
  let plus_hour = hour_row.children()[2]
  click_at(root, plus_hour, 15.0, 14.0)
  click_at(root, plus_hour, 15.0, 14.0)
  // 确定：按钮行第 2 个
  let btn_row = panel.children()[2]
  click_at(root, btn_row.children()[1], 30.0, 14.0)
  assert_eq(changes, ["11:00~-"])
  match v.get().start {
    Some(t) => assert_eq(t.format(), "11:00")
    None => assert_true(false)
  }
  // 取消路径：改完不确认，Store 不变
  click_at(root, start_field, 40.0, 16.0)
  root.relayout(400.0, 300.0)
  let panel2 = picker_panel(2)
  click_at(root, panel2.children()[0].children()[2], 15.0, 14.0)
  click_at(root, panel2.children()[2].children()[0], 30.0, 14.0)
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
    datetime_range_picker_t(
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
  click_at(root, cell_at(picker_panel(1), 14), 18.0, 15.0)
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
  let panel = picker_panel(2)
  click_at(root, panel.children()[0].children()[2], 15.0, 14.0)
  click_at(root, panel.children()[2].children()[1], 30.0, 14.0)
  match v.get().start {
    Some(p) => assert_eq(p.1.format(), "10:00")
    None => assert_true(false)
  }
  assert_eq(changes.length(), 2)
}
