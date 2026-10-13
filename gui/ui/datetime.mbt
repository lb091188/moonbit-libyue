// 日期族首批：日期/时间值模型 + 自绘日历面板 + `calendar`。
//
// 两条与 master 的差（记档）：① CSS `style` 通道同样未接，只留类型化参数；
// ② 「今天」不由组件直接问平台，而是 `@core.local_ymd()` 转派，并且可以显式
//    传入（`today?`）——无头测试要拿确定日期才测得动网格。
//
// 一条结构差：42 格的排布规则外置成纯函数 `month_grid`（面板只负责画与点），
// 网格数学因此可以脱离控件验证，后面的日期选择器也共用同一份。

///|
/// 日期值（年月日，月/日按日常习惯 1 起始）。
pub(all) struct DateYMD {
  y : Int
  m : Int
  d : Int
}

///|
/// 闰年（格里高利历）。
pub fn date_leap(y : Int) -> Bool {
  y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)
}

///|
/// 当月天数（`m` 越界按 1 月处理：宁给可画的值，不给越界索引）。
pub fn days_in_month(y : Int, m : Int) -> Int {
  let days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  let mi = if m >= 1 && m <= 12 { m } else { 1 }
  if mi == 2 && date_leap(y) {
    29
  } else {
    days[mi - 1]
  }
}

///|
/// 星期几（0 = 周日 .. 6 = 周六），Sakamoto 算法。
pub fn date_weekday(y : Int, m : Int, d : Int) -> Int {
  let t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
  let yy = if m < 3 { y - 1 } else { y }
  (yy + yy / 4 - yy / 100 + yy / 400 + t[m - 1] + d) % 7
}

///|
/// 月份前进/后退 `delta` 个月（可跨年，`delta` 可为任意整数）。
pub fn month_shift(y : Int, m : Int, delta : Int) -> (Int, Int) {
  let mi = if m >= 1 && m <= 12 { m } else { 1 }
  let zero = y * 12 + (mi - 1) + delta
  (zero / 12, zero % 12 + 1)
}

///|
/// 本地时区的今天；平台给不出时退回 1970-01-01（本层不猜日期）。
pub fn today_date() -> DateYMD {
  let (y, m, d) = @core.local_ymd()
  if y > 0 && m >= 1 && m <= 12 && d >= 1 && d <= 31 {
    { y, m, d }
  } else {
    { y: 1970, m: 1, d: 1 }
  }
}

///|
/// 两位补零。
fn pad_two(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
/// 格式化为 YYYY-MM-DD（月/日不足两位补零）。
pub fn DateYMD::format(self : DateYMD) -> String {
  self.y.to_string() + "-" + pad_two(self.m) + "-" + pad_two(self.d)
}

///|
/// 日期比较：负 = a 早于 b，0 = 同一天，正 = a 晚于 b。
pub fn DateYMD::compare(a : DateYMD, b : DateYMD) -> Int {
  if a.y != b.y {
    a.y - b.y
  } else if a.m != b.m {
    a.m - b.m
  } else {
    a.d - b.d
  }
}

///|
/// 同一天。
pub fn DateYMD::same(a : DateYMD, b : DateYMD) -> Bool {
  DateYMD::compare(a, b) == 0
}

///|
/// `d` 是否落在 [s, e] 闭区间内（s/e 顺序不限，内部归一）。
pub fn DateYMD::in_range(d : DateYMD, s : DateYMD, e : DateYMD) -> Bool {
  let (lo, hi) = if DateYMD::compare(s, e) <= 0 {
    (s, e)
  } else {
    (e, s)
  }
  DateYMD::compare(d, lo) >= 0 && DateYMD::compare(d, hi) <= 0
}

///|
/// 月网格：固定 42 格（6 行 × 7 列），每格给日期与「是否本月」。首格前的
/// 尾巴属于上月、月末后的头部属于下月，两者都按灰显且不可选处理。
pub fn month_grid(y : Int, m : Int) -> Array[(DateYMD, Bool)] {
  let out : Array[(DateYMD, Bool)] = []
  let first_wd = date_weekday(y, m, 1)
  let dim = days_in_month(y, m)
  let (py, pm) = month_shift(y, m, -1)
  let (ny, nm) = month_shift(y, m, 1)
  let dim_prev = days_in_month(py, pm)
  for idx = 0; idx < 42; idx = idx + 1 {
    let in_month = idx >= first_wd && idx < first_wd + dim
    let date = if idx < first_wd {
      { y: py, m: pm, d: dim_prev - (first_wd - idx) + 1 }
    } else if in_month {
      { y: y, m: m, d: idx - first_wd + 1 }
    } else {
      { y: ny, m: nm, d: idx - first_wd - dim + 1 }
    }
    out.push((date, in_month))
  }
  out
}

///|
/// 时间值（时 0-23 / 分 0-59；区间与日期时间选择的组成部分）。
pub(all) struct TimeHM {
  h : Int
  m : Int
}

///|
/// 钳制到合法时间（时 0-23 / 分 0-59）。
pub fn time_clamp(h : Int, m : Int) -> TimeHM {
  let hc = if h < 0 {
    0
  } else if h > 23 {
    23
  } else {
    h
  }
  let mc = if m < 0 {
    0
  } else if m > 59 {
    59
  } else {
    m
  }
  { h: hc, m: mc }
}

///|
/// 时间比较：负 = a 早于 b，0 = 相同，正 = a 晚于 b。
pub fn TimeHM::compare(a : TimeHM, b : TimeHM) -> Int {
  a.h * 60 + a.m - (b.h * 60 + b.m)
}

///|
/// 格式化为 HH:MM。
pub fn TimeHM::format(self : TimeHM) -> String {
  pad_two(self.h) + ":" + pad_two(self.m)
}

///|
/// 日期区间值（起点/终点各自可为空：选择过程的中间态）。
pub(all) struct DateRange {
  start : DateYMD?
  end : DateYMD?
}

///|
/// 时间区间值。
pub(all) struct TimeRange {
  start : TimeHM?
  end : TimeHM?
}

///|
/// 日期时间区间值（日期对 + 各自时:分）。
pub(all) struct DateTimeRange {
  start : (DateYMD, TimeHM)?
  end : (DateYMD, TimeHM)?
}

///|
/// 格子状态：普通 / 单选选中 / 区间端点 / 区间中间（浅色底）。
pub(all) enum CalCell {
  Plain
  Selected
  RangeEdge
  InRange
}

///|
/// 格子画法：实心方块（选中/端点）优先于浅底（区间中间），浅底优先于悬停底色。
fn cell_solid(st : CalCell) -> Bool {
  match st {
    Selected | RangeEdge => true
    Plain | InRange => false
  }
}

///|
/// 左右向的矢量三角（`‹`/`›` 字形跨平台发虚，一律画路径）。
fn draw_chevron(p : @render.Painter, cx : Double, cy : Double, size : Double, right : Bool, color : String) -> Unit {
  p.set_fill_color(color)
  p.begin_path()
  if right {
    p.move_to(cx - size / 2.0, cy - size)
    p.line_to(cx + size / 2.0, cy)
    p.line_to(cx - size / 2.0, cy + size)
  } else {
    p.move_to(cx + size / 2.0, cy - size)
    p.line_to(cx - size / 2.0, cy)
    p.line_to(cx + size / 2.0, cy + size)
  }
  p.close_path()
  p.fill()
}

///|
/// 区间日历的格子状态：两端点实心、闭区间内浅底；只有起点时起点按选中画
/// （选择过程的中间态）。区间选择器与任何要画区间的面板共用这份映射。
pub fn range_state_of(range : DateRange, d : DateYMD) -> CalCell {
  match (range.start, range.end) {
    (Some(s), Some(e)) =>
      if DateYMD::same(d, s) || DateYMD::same(d, e) {
        RangeEdge
      } else if DateYMD::in_range(d, s, e) {
        InRange
      } else {
        Plain
      }
    (Some(s), None) => if DateYMD::same(d, s) { Selected } else { Plain }
    (None, Some(e)) => if DateYMD::same(d, e) { Selected } else { Plain }
    (None, None) => Plain
  }
}

///|
/// 自绘日历面板：头部 `‹ 年 月 ›` + 星期行 + 42 格月网格。选中语义外置——
/// `state_of` 决定每格画法，`on_cell` 收点击（返回后整格重画）。
/// 返回「按当前月份重建网格」的函数，外部改了视图状态就调它。
///
/// 42 格一次建好、永不增删：切月只改每格的数据（日期与是否本月）再请求重绘，
/// 网格结构稳定，命中矩形也不会因为增删子控件而错位。
fn build_calendar(
  panel : @core.Widget,
  today : DateYMD,
  state_of : (DateYMD) -> CalCell,
  on_cell : (DateYMD) -> Unit,
) -> () -> Unit {
  let cell_w = 36.0
  let cell_h = 30.0
  let head_h = 32.0
  let week_h = 26.0
  watch_theme()
  panel.node.set_flex_direction(@yoga.Column)
  // yoga 的 width 是 border-box 语义（含 padding），故在内容宽上补两侧 8
  panel.node.set_width(@yoga.fixed(cell_w * 7.0 + 16.0))
  panel.node.set_height(
    @yoga.fixed(16.0 + head_h + 4.0 + week_h + 6.0 * cell_h),
  )
  panel.set_padding(top=8.0, left=8.0)
  panel.on_draw = Some(fn(
    _self : @core.Widget,
    p : @render.Painter,
    r : @core.Rect,
  ) -> Unit {
    p.set_fill_color(@theme.theme_bg_panel())
    p.fill_rect(0.0, 0.0, r.w, r.h)
    p.set_stroke_color(@theme.theme_border())
    p.set_line_width(1.0)
    p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
  })
  let view_y = Ref(today.y)
  let view_m = Ref(today.m)
  let rebuild : Ref[() -> Unit] = Ref(fn() { () })
  let head_font = @text.Font::new("", 14.0, weight=@text.SemiBold)
  let cell_font = @text.Font::new("", 13.0)

  let head = @core.Widget::new()
  head.node.set_flex_direction(@yoga.Row)
  head.node.set_height(@yoga.fixed(head_h))
  head.set_margin(bottom=4.0)

  fn chevron(right : Bool) -> @core.Widget {
    let b = @core.Widget::new()
    b.node.set_width(@yoga.fixed(28.0))
    b.node.set_height(@yoga.fixed(head_h))
    b.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      if self.hovered {
        p.set_fill_color(@theme.theme_fill_hover())
        p.fill_rect(0.0, 0.0, r.w, r.h)
      }
      draw_chevron(
        p,
        r.w / 2.0,
        r.h / 2.0,
        4.0,
        right,
        @theme.theme_text_regular(),
      )
    })
    let delta = if right { 1 } else { -1 }
    b.on_pointer = Some(fn(
      _self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Down => {
          let (y, m) = month_shift(view_y.val, view_m.val, delta)
          view_y.val = y
          view_m.val = m
          (rebuild.val)()
          true
        }
        _ => false
      }
    })
    b
  }

  let title = @core.Widget::new()
  title.node.set_flex_grow(1.0)
  title.node.set_height(@yoga.fixed(head_h))
  title.on_draw = Some(fn(
    _self : @core.Widget,
    p : @render.Painter,
    r : @core.Rect,
  ) -> Unit {
    let _ = @text.draw_box_at(
      p,
      0.0,
      0.0,
      r.w,
      r.h,
      view_y.val.to_string() + " 年 " + view_m.val.to_string() + " 月",
      head_font,
      @theme.theme_text_primary(),
      align=@text.Center,
      valign=@text.Center,
    )
  })
  head.append_child(chevron(false))
  head.append_child(title)
  head.append_child(chevron(true))

  let week = @core.Widget::new()
  week.node.set_flex_direction(@yoga.Row)
  week.node.set_height(@yoga.fixed(week_h))
  for name in ["日", "一", "二", "三", "四", "五", "六"] {
    let c = @core.Widget::new()
    c.node.set_width(@yoga.fixed(cell_w))
    c.node.set_height(@yoga.fixed(week_h))
    let label = name
    c.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let _ = @text.draw_box_at(
        p,
        0.0,
        0.0,
        r.w,
        r.h,
        label,
        cell_font,
        @theme.theme_text_secondary(),
        align=@text.Center,
        valign=@text.Center,
      )
    })
    week.append_child(c)
  }

  let grid = @core.Widget::new()
  grid.node.set_flex_direction(@yoga.Column)
  let cell_date : Array[Ref[DateYMD]] = []
  let cell_inm : Array[Ref[Bool]] = []
  for _row = 0; _row < 6; _row = _row + 1 {
    let row = @core.Widget::new()
    row.node.set_flex_direction(@yoga.Row)
    for _col = 0; _col < 7; _col = _col + 1 {
      let dref : Ref[DateYMD] = Ref({ y: 1970, m: 1, d: 1 })
      let inm : Ref[Bool] = Ref(false)
      let c = @core.Widget::new()
      c.node.set_width(@yoga.fixed(cell_w))
      c.node.set_height(@yoga.fixed(cell_h))
      c.on_draw = Some(fn(
        self : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        let d = dref.val
        let st = state_of(d)
        let solid = cell_solid(st)
        let band = match st {
          InRange => true
          _ => false
        }
        if band {
          p.set_fill_color(@theme.theme_primary_light())
          p.fill_rect(0.0, 0.0, r.w, r.h)
        } else if self.hovered && inm.val {
          p.set_fill_color(@theme.theme_fill_hover())
          p.fill_rect(0.0, 0.0, r.w, r.h)
        }
        let txt = d.d.to_string()
        if solid {
          p.set_fill_color(@theme.theme_primary())
          p.fill_rect((r.w - 28.0) / 2.0, (r.h - 28.0) / 2.0, 28.0, 28.0)
          let _ = @text.draw_box_at(
            p,
            0.0,
            0.0,
            r.w,
            r.h,
            txt,
            cell_font,
            "#ffffff",
            align=@text.Center,
            valign=@text.Center,
          )
        } else {
          let color = if !inm.val {
            @theme.theme_text_secondary()
          } else if DateYMD::same(d, today) {
            @theme.theme_primary()
          } else if band {
            @theme.theme_primary()
          } else {
            @theme.theme_text_primary()
          }
          let _ = @text.draw_box_at(
            p,
            0.0,
            0.0,
            r.w,
            r.h,
            txt,
            cell_font,
            color,
            align=@text.Center,
            valign=@text.Center,
          )
        }
      })
      c.on_pointer = Some(fn(
        self : @core.Widget,
        ev : @core.PointerEvent,
      ) -> Bool {
        match ev.kind {
          // 松开才算选中（与弹层内点项同一口径），跨月格不可选
          @core.Down => inm.val
          @core.Up => {
            let inside = ev.x >= 0.0 && ev.x <= self.rect.w && ev.y >= 0.0 && ev.y <= self.rect.h
            if inm.val && inside {
              on_cell(dref.val)
              @core.invalidate()
            }
            false
          }
          _ => false
        }
      })
      row.append_child(c)
      cell_date.push(dref)
      cell_inm.push(inm)
    }
    grid.append_child(row)
  }

  fn rebuild_grid() -> Unit {
    let cells = month_grid(view_y.val, view_m.val)
    for i = 0; i < 42; i = i + 1 {
      cell_date[i].val = cells[i].0
      cell_inm[i].val = cells[i].1
    }
    @core.invalidate()
  }

  rebuild.val = rebuild_grid
  panel.append_child(head)
  panel.append_child(week)
  panel.append_child(grid)
  rebuild_grid()
  rebuild_grid
}

///|
/// 日历面板（EP DatePicker 的面板形态，全自绘）：`‹`/`›` 切月 + 星期行 +
/// 42 格月网格，跨月日期灰显且不可选，「今天」用主题色，选中日期实心主题色方块。
/// 松开当月日期即写入 `value`（若有）并回调 `on_pick`。
pub fn calendar(
  on_pick? : (DateYMD) -> Unit = fn(_d : DateYMD) -> Unit { () },
  value? : @core.Store[DateYMD?],
  today? : DateYMD = today_date(),
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let t = today
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    // 有 Store 就以 Store 为唯一权威（外部 set 立刻反映到画法），没有才自持
    let sel : Ref[DateYMD?] = Ref(
      match value {
        Some(s) => s.get()
        None => None
      },
    )
    fn read_sel() -> DateYMD? {
      match value {
        Some(s) => s.get()
        None => sel.val
      }
    }

    let _refresh = build_calendar(
      w,
      t,
      fn(d : DateYMD) -> CalCell {
        match read_sel() {
          Some(s) => if DateYMD::same(s, d) { Selected } else { Plain }
          None => Plain
        }
      },
      fn(d : DateYMD) -> Unit {
        sel.val = Some(d)
        match value {
          Some(s) => s.set(Some(d))
          None => ()
        }
        on_pick(d)
      },
    )
    match value {
      Some(s) => follow_store(s)
      None => ()
    }
    fold_style(w, @style.empty_style(), class)
    handle(w)
    w
  })
}
