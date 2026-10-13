// 日期族回归：日期数学、42 格月网格、日历面板的选中/跨月/切月与区间格子映射。
// 网格数学全部走纯函数断言（脱离控件），面板侧只验交互结果（点了哪一天、切月后
// 可选的日期是否跟着换），绘制断言比「该处是否还是面板底色」。
// 观测一律走字符串（`format` / 格子名）：本工具链里给值类型 `derive(Eq)` 会把
// impl 方法隐式升成普通方法并告警，零警告门禁下不划算。

///|
fn d(y : Int, m : Int, dd : Int) -> DateYMD {
  { y, m, d: dd }
}

///|
/// 网格第 idx 格的可读形态：`YYYY-MM-DD`，本月的加 `*`。
fn grid_str(grid : Array[(DateYMD, Bool)], idx : Int) -> String {
  let (dt, inm) = grid[idx]
  dt.format() + (if inm { "*" } else { "" })
}

///|
/// 格子状态名（断言用）。
fn cell_name(c : CalCell) -> String {
  match c {
    Plain => "plain"
    Selected => "selected"
    RangeEdge => "edge"
    InRange => "band"
  }
}

///|
/// Store 里选中的日期（无值给 "-"）。
fn sel_str(v : @core.Store[DateYMD?]) -> String {
  match v.get() {
    Some(x) => x.format()
    None => "-"
  }
}

///|
fn cell_at(panel : @core.Widget, idx : Int) -> @core.Widget {
  let grid = panel.children()[2]
  grid.children()[idx / 7].children()[idx % 7]
}

///|
fn pick(root : @core.Widget, c : @core.Widget) -> Unit {
  let x = c.rect.x + c.rect.w / 2.0
  let y = c.rect.y + c.rect.h / 2.0
  let _ = root.dispatch_pointer({ kind: @core.Down, x, y, button: 1, mods: 0 })
  let _ = root.dispatch_pointer({ kind: @core.Up, x, y, button: 1, mods: 0 })
}

///|
/// 面板底色取样点（左侧 padding 带，任何格子都够不到）。
fn bg_of(bm : @render.Bitmap, panel : @core.Widget) -> (Int, Int, Int, Int) {
  px(bm, (panel.rect.x + 2.0).round().to_int(), (panel.rect.y + 60.0).round().to_int())
}

///|
test "日期数学：闰年、月长、星期与月份进退" {
  assert_eq(date_leap(2024), true)
  assert_eq(date_leap(1900), false)
  assert_eq(date_leap(2000), true)
  assert_eq(days_in_month(2024, 2), 29)
  assert_eq(days_in_month(2023, 2), 28)
  assert_eq(days_in_month(1900, 2), 28)
  assert_eq(days_in_month(2026, 4), 30)
  // 0 = 周日：2026-10-11 是周日、2000-01-01 是周六
  assert_eq(date_weekday(2026, 10, 11), 0)
  assert_eq(date_weekday(2000, 1, 1), 6)
  assert_eq(date_weekday(2026, 10, 1), 4)
  assert_eq(month_shift(2026, 12, 1), (2027, 1))
  assert_eq(month_shift(2026, 1, -1), (2025, 12))
  assert_eq(month_shift(2026, 10, -12), (2025, 10))
  // 2026-10 起 15 个月是 2028-01（+2 到 2026-12，再 +12 到 2027-12，再 +1）
  assert_eq(month_shift(2026, 10, 15), (2028, 1))
}

///|
test "格式化与比较：补零、时间钳制、区间端点顺序不限" {
  assert_eq(d(2026, 1, 9).format(), "2026-01-09")
  assert_eq(d(2026, 12, 31).format(), "2026-12-31")
  assert_eq((TimeHM::{ h: 9, m: 5 }).format(), "09:05")
  assert_eq(time_clamp(25, -3).format(), "23:00")
  assert_true(DateYMD::compare(d(2026, 9, 30), d(2026, 10, 1)) < 0)
  assert_true(DateYMD::compare(d(2025, 12, 31), d(2026, 1, 1)) < 0)
  assert_eq(DateYMD::same(d(2026, 10, 11), d(2026, 10, 11)), true)
  // 端点写反也要判在区间内
  assert_eq(DateYMD::in_range(d(2026, 10, 5), d(2026, 10, 1), d(2026, 10, 9)), true)
  assert_eq(DateYMD::in_range(d(2026, 10, 5), d(2026, 10, 9), d(2026, 10, 1)), true)
  assert_eq(
    DateYMD::in_range(d(2026, 10, 10), d(2026, 10, 1), d(2026, 10, 9)),
    false,
  )
  assert_true(
    TimeHM::compare((TimeHM::{ h: 9, m: 30 }), (TimeHM::{ h: 10, m: 0 })) < 0,
  )
}

///|
test "月网格：固定 42 格、跨月尾巴与头部、本月格数等于月长" {
  let oct = month_grid(2026, 10)
  assert_eq(oct.length(), 42)
  // 10 月 1 日是周四（first_wd=4）：前 4 格是 9 月 27..30 且不带星号
  assert_eq(grid_str(oct, 0), "2026-09-27")
  assert_eq(grid_str(oct, 3), "2026-09-30")
  assert_eq(grid_str(oct, 4), "2026-10-01*")
  assert_eq(grid_str(oct, 34), "2026-10-31*")
  assert_eq(grid_str(oct, 35), "2026-11-01")
  assert_eq(grid_str(oct, 41), "2026-11-07")
  assert_eq(oct.filter(fn(x) { x.1 }).length(), 31)
  // 2 月按闰与否给本月格数
  assert_eq(month_grid(2024, 2).filter(fn(x) { x.1 }).length(), 29)
  assert_eq(month_grid(2023, 2).filter(fn(x) { x.1 }).length(), 28)
  // 1 月跨年：1 月 1 日同样是周四，头格落在上一年 12 月、尾格落到 2 月
  let jan = month_grid(2026, 1)
  assert_eq(grid_str(jan, 0), "2025-12-28")
  assert_eq(grid_str(jan, 4), "2026-01-01*")
  assert_eq(grid_str(jan, 41), "2026-02-07")
}

///|
test "本地今天：走平台日历时间而不是单调时钟" {
  let t = today_date()
  // 拿不到平台日期会退到 1970-01-01；本机有后端，必须给出真实年份
  assert_true(t.y > 2000)
  assert_true(t.m >= 1 && t.m <= 12)
  assert_true(t.d >= 1 && t.d <= days_in_month(t.y, t.m))
}

///|
test "日历面板：点当月格选中并写 Store，跨月格与格外松开都不算一次" {
  let picked : Array[String] = []
  let v = @core.Store::new(None)
  let (root, panel) = mounted(
    calendar(
      on_pick=fn(x : DateYMD) -> Unit { picked.push(x.format()) },
      value=v,
      today=d(2026, 10, 11),
    ),
    300.0,
    300.0,
  )
  assert_eq((panel.rect.w, panel.rect.h), (268.0, 258.0))
  assert_eq(panel.children().length(), 3)
  // 10 月 1 日在第 5 格
  pick(root, cell_at(panel, 4))
  assert_eq(picked.length(), 1)
  assert_eq(picked[0], "2026-10-01")
  assert_eq(sel_str(v), "2026-10-01")
  // 跨月格（9 月 30 日）不可选
  pick(root, cell_at(panel, 3))
  assert_eq(picked.length(), 1)
  // 按下后在格外松开不算一次（捕获期仍投给被按下的格）
  let c = cell_at(panel, 10)
  let _ = root.dispatch_pointer({
    kind: @core.Down,
    x: c.rect.x + 18.0,
    y: c.rect.y + 15.0,
    button: 1,
    mods: 0,
  })
  let _ = root.dispatch_pointer_to(c.id, {
    kind: @core.Up,
    x: c.rect.x + 900.0,
    y: c.rect.y + 15.0,
    button: 1,
    mods: 0,
  })
  assert_eq(picked.length(), 1)
  assert_eq(sel_str(v), "2026-10-01")
}

///|
test "日历面板：切月后可选日期跟着换，选中格画实心方块" {
  let picked : Array[String] = []
  let v = @core.Store::new(None)
  let (root, panel) = mounted(
    calendar(
      on_pick=fn(x : DateYMD) -> Unit { picked.push(x.format()) },
      value=v,
      today=d(2026, 10, 11),
    ),
    300.0,
    300.0,
  )
  let head = panel.children()[0]
  // 11 月 1 日是周日，切月后落在第 0 格且变为可选
  pick(root, head.children()[2])
  pick(root, cell_at(panel, 0))
  assert_eq(picked.length(), 1)
  assert_eq(picked[0], "2026-11-01")
  // 左箭头切回 10 月：第 0 格又变回跨月的 9 月 27 日（不可选）
  pick(root, head.children()[0])
  pick(root, cell_at(panel, 0))
  assert_eq(picked.length(), 1)
  pick(root, cell_at(panel, 14))
  assert_eq(picked[picked.length() - 1], "2026-10-11")

  let bm = @render.Bitmap::new(300, 300)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let bg = bg_of(bm, panel)
  let sel = cell_at(panel, 14)
  let other = cell_at(panel, 12)
  // 实心方块 28×28 居中：格内左侧 6px 在方块里、又离字形足够远——
  // 选中格该处不是面板底，未选格该处仍是面板底
  assert_true(
    px(bm, (sel.rect.x + 6.0).round().to_int(), (sel.rect.y + 15.0).round().to_int()) != bg,
  )
  assert_eq(
    px(bm, (other.rect.x + 6.0).round().to_int(), (other.rect.y + 15.0).round().to_int()),
    bg,
  )
  // 方块不铺满整格：选中格的左上角仍是面板底
  assert_eq(
    px(bm, (sel.rect.x + 1.0).round().to_int(), (sel.rect.y + 1.0).round().to_int()),
    bg,
  )
}

///|
test "外部改 Store 即换选中格；区间格子映射端点实心、中间浅底" {
  let v = @core.Store::new(None)
  let (root, panel) = mounted(
    calendar(value=v, today=d(2026, 10, 11)),
    300.0,
    300.0,
  )
  v.set(Some(d(2026, 10, 20)))
  let bm = @render.Bitmap::new(300, 300)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let bg = bg_of(bm, panel)
  // 第 23 格 = 10 月 20 日该有实心方块；第 14 格 = 10 月 11 日（「今天」只换
  // 字色不铺底）不该有
  let on20 = cell_at(panel, 23)
  let on11 = cell_at(panel, 14)
  assert_true(
    px(bm, (on20.rect.x + 6.0).round().to_int(), (on20.rect.y + 15.0).round().to_int()) != bg,
  )
  assert_eq(
    px(bm, (on11.rect.x + 6.0).round().to_int(), (on11.rect.y + 15.0).round().to_int()),
    bg,
  )

  let r : DateRange = { start: Some(d(2026, 10, 3)), end: Some(d(2026, 10, 7)) }
  assert_eq(cell_name(range_state_of(r, d(2026, 10, 3))), "edge")
  assert_eq(cell_name(range_state_of(r, d(2026, 10, 7))), "edge")
  assert_eq(cell_name(range_state_of(r, d(2026, 10, 5))), "band")
  assert_eq(cell_name(range_state_of(r, d(2026, 10, 8))), "plain")
  // 端点写反同样归一
  let rev : DateRange = { start: Some(d(2026, 10, 7)), end: Some(d(2026, 10, 3)) }
  assert_eq(cell_name(range_state_of(rev, d(2026, 10, 5))), "band")
  let half : DateRange = { start: Some(d(2026, 10, 3)), end: None }
  assert_eq(cell_name(range_state_of(half, d(2026, 10, 3))), "selected")
  assert_eq(cell_name(range_state_of(half, d(2026, 10, 4))), "plain")
  let empty : DateRange = { start: None, end: None }
  assert_eq(cell_name(range_state_of(empty, d(2026, 10, 4))), "plain")
}
