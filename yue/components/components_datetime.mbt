// 日期时间:calendar / date_picker / time_picker 及范围选择器。

///|
/// 日期值(年月日,月/日按日常习惯 1 起始)。
pub(all) struct DateYMD {
  y : Int
  m : Int
  d : Int
}

///|
fn date_leap(y : Int) -> Bool {
  y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)
}

///|
fn date_days_in_month(y : Int, m : Int) -> Int {
  let days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  if m == 2 && date_leap(y) {
    29
  } else {
    days[m - 1]
  }
}

///|
/// 星期几(0 = 周日 .. 6 = 周六),Sakamoto 算法。
fn date_weekday(y : Int, m : Int, d : Int) -> Int {
  let t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
  let yy = if m < 3 { y - 1 } else { y }
  (yy + yy / 4 - yy / 100 + yy / 400 + t[m - 1] + d) % 7
}

///|
/// 格式化为 YYYY-MM-DD(月/日不足两位补零)。
pub fn DateYMD::format(self : DateYMD) -> String {
  fn two(n : Int) -> String {
    if n < 10 {
      "0\{n}"
    } else {
      n.to_string()
    }
  }

  "\{self.y}-\{two(self.m)}-\{two(self.d)}"
}

///|
/// 本地时区的今天(日历"今天"高亮用)。
fn local_date() -> DateYMD {
  let v = @yue.ffi_local_date()
  {
    y: (v / 10000).to_int(),
    m: (v % 10000 / 100).to_int(),
    d: (v % 100).to_int(),
  }
}

///|
/// 日期比较:负 = a 早于 b,0 = 同一天,正 = a 晚于 b。
fn date_cmp(a : DateYMD, b : DateYMD) -> Int {
  if a.y != b.y {
    a.y - b.y
  } else if a.m != b.m {
    a.m - b.m
  } else {
    a.d - b.d
  }
}

///|
fn date_eq(a : DateYMD, b : DateYMD) -> Bool {
  date_cmp(a, b) == 0
}

///|
/// d 是否落在 [s, e] 闭区间内(s/e 顺序不限,内部归一)。
fn date_in_range(d : DateYMD, s : DateYMD, e : DateYMD) -> Bool {
  let (lo, hi) = if date_cmp(s, e) <= 0 { (s, e) } else { (e, s) }
  date_cmp(d, lo) >= 0 && date_cmp(d, hi) <= 0
}

///|
/// 时间值(时 0-23 / 分 0-59;区间/日期时间选择的组成部分)。
pub(all) struct TimeHM {
  h : Int
  m : Int
}

///|
/// 时间比较:负 = a 早于 b,0 = 相同,正 = a 晚于 b。
pub fn TimeHM::compare(a : TimeHM, b : TimeHM) -> Int {
  a.h * 60 + a.m - (b.h * 60 + b.m)
}

///|
/// 格式化为 HH:MM(不足两位补零)。
pub fn TimeHM::format(self : TimeHM) -> String {
  fn two(n : Int) -> String {
    if n < 10 {
      "0\{n}"
    } else {
      n.to_string()
    }
  }

  "\{two(self.h)}:\{two(self.m)}"
}

///|
/// 钳制到合法时间(h 0-23 / m 0-59)。
fn time_clamp(h : Int, m : Int) -> TimeHM {
  let hc = if h < 0 { 0 } else if h > 23 { 23 } else { h }
  let mc = if m < 0 { 0 } else if m > 59 { 59 } else { m }
  { h: hc, m: mc, }
}

///|
/// 日期区间值(起点/终点各自可为空:选择过程的中间态)。
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
/// 日期时间区间值(日期对 + 各自时:分)。
pub(all) struct DateTimeRange {
  start : (DateYMD, TimeHM)?
  end : (DateYMD, TimeHM)?
}

///|
/// 格子状态:普通 / 单选选中 / 区间端点 / 区间中间(浅蓝底)。
priv enum CalCell {
  Plain
  Selected
  RangeEdge
  InRange
}

///|
/// 构建自绘日历面板(头部 ‹/› 导航 + 星期行 + 42 格月网格),日历家族
/// (calendar_t / date_picker_t / 区间选择器)共用。选中语义外置:
/// state_of 决定每格画法(单选方块/区间端点/区间中浅底),on_cell 收
/// 点击;on_cell 返回后全格重绘。返回面板与「按当前状态重建网格」函数
/// (外部改状态后手动调用刷新)。
fn build_calendar(
  today : DateYMD,
  state_of : (DateYMD) -> CalCell,
  on_cell : (DateYMD) -> Unit,
) -> (@yue.Container, () -> Unit) {
  let cell_w = 36.0
  let cell_h = 30.0
  // 显式总高:PopoverRootView 按 content_size 硬分配,不读内容自然高度
  // (高 = 上下 padding 16 + 头 32+4 + 星期行 26 + 6 行 x 30)
  let panel = @yue.themed_container(style=[ // yoga 的 width 是 border-box 语义(含 padding),须加 16;
    // 只给内容宽 252 会把最后一列(周六)裁掉 16px
    ("width", cell_w * 7.0 + 16.0),
    ("height", 16.0 + 32.0 + 4.0 + 26.0 + 6.0 * cell_h),
    ("padding", 8.0),
    ("flexDirection", "column"),
  ])
  @yue.set_panel_bg(panel)
  panel.on_draw(fn(p) {
    let b = @yue.ViewLike::get_bounds(panel)
    p.set_stroke_color(@yue.theme_border())
    p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
  })
  let view_y = Ref(today.y)
  let view_m = Ref(today.m)
  // 文本水平居中走 draw_text 的 align 参数(平台布局引擎居中)
  fn draw_center(
    p : @yue.Painter,
    text : String,
    y : Double,
    h : Double,
    color : String,
  ) -> Unit {
    p.draw_text(
      text,
      0.0,
      y,
      cell_w,
      h,
      align=@yue.Center,
      valign=@yue.Center,
      color~,
    )
  }

  let head_h = 32.0
  let head = @yue.themed_container(style=[
    ("height", head_h),
    ("marginBottom", 4.0),
    ("flexDirection", "row"),
    ("alignItems", "center"),
  ])
  let title_text = Ref("")
  let title = @yue.themed_container(style=[("flex", 1.0), ("height", head_h)])
  // 月标题水平居中:GTK 端 align 无效,绘制时测宽手动摆位
  title.on_draw(fn(p) {
    let b = @yue.ViewLike::get_bounds(title)
    let probe = @yue.AttributedText::new(title_text.val, wrap=false)
    probe.set_font(@yue.Font::new("Sans", 14.0, weight=@yue.SemiBold))
    let tw = probe.get_bounds_for(10000.0, 1000.0).width
    p.draw_text(
      title_text.val,
      (b.width - tw) / 2.0,
      0.0,
      b.width,
      b.height,
      valign=@yue.Center,
      color=@yue.theme_text_primary(),
    )
  })
  fn nav_btn(glyph : String, on_click : () -> Unit) -> @yue.Container {
    let hover = Ref(false)
    let b = @yue.themed_container(style=[("width", 28.0), ("height", head_h)])
    let to_left = glyph == "‹"
    b.on_draw(fn(p) {
      let bb = @yue.ViewLike::get_bounds(b)
      if hover.val {
        p.set_fill_color(@yue.theme_fill_hover())
        p.fill_rect(0.0, 0.0, bb.width, bb.height)
      }
      // ‹/› 矢量三角(字形图标跨平台发虚,GTK align 亦无效)
      if to_left {
        draw_glyph_left(
          p,
          bb.width / 2.0,
          bb.height / 2.0,
          4.0,
          @yue.theme_text_regular(),
        )
      } else {
        draw_glyph_right(
          p,
          bb.width / 2.0,
          bb.height / 2.0,
          4.0,
          @yue.theme_text_regular(),
        )
      }
    })
    @yue.ViewLike::on_mouse_enter(b, fn(_e) {
      hover.val = true
      @yue.ViewLike::schedule_paint(b)
    })
    @yue.ViewLike::on_mouse_leave(b, fn(_e) {
      hover.val = false
      @yue.ViewLike::schedule_paint(b)
    })
    @yue.View::set_cursor(b, @yue.hand())
    @yue.ViewLike::on_mouse_down(b, fn(e) {
      if e.button == 1 {
        on_click()
        true
      } else {
        false
      }
    })
    b
  }

  // 导航按钮先于网格创建,经 Ref 间接调用重建函数
  let rebuild_ref : Ref[() -> Unit] = Ref(fn() {  })
  fn nav(delta : Int) -> Unit {
    let mut m = view_m.val + delta
    let mut y = view_y.val
    if m < 1 {
      m = 12
      y = y - 1
    }
    if m > 12 {
      m = 1
      y = y + 1
    }
    view_y.val = y
    view_m.val = m
    (rebuild_ref.val)()
  }

  head.add_child(nav_btn("‹", fn() { nav(-1) }))
  head.add_child(title)
  head.add_child(nav_btn("›", fn() { nav(1) }))
  let week_h = 26.0
  let wk = @yue.themed_container(style=[
    ("height", week_h),
    ("flexDirection", "row"),
  ])
  for name in ["日", "一", "二", "三", "四", "五", "六"] {
    let wref = name
    let c = @yue.themed_container(style=[("width", cell_w), ("height", week_h)])
    c.on_draw(fn(p) {
      let b = @yue.ViewLike::get_bounds(c)
      draw_center(p, wref, 0.0, b.height, @yue.theme_text_secondary())
    })
    wk.add_child(c)
  }
  let grid = @yue.themed_container(style=[("flexDirection", "column")])
  // 42 格一次性创建、永不增删:实测弹层窗口 map 过之后再加进来的行
  // 不会被绘制(同面板一次创建的标题/星期行始终正常,增删过的格子
  // 消失且导航重建也不恢复)——rebuild 只改每格数据+重绘
  let cells : Ref[Array[@yue.Container]] = Ref([])
  let cell_date : Ref[Array[Ref[DateYMD]]] = Ref([])
  let cell_inm : Ref[Array[Ref[Bool]]] = Ref([])
  for _row in 0..<6 {
    let r = @yue.themed_container(style=[("flexDirection", "row")])
    for _col in 0..<7 {
      let dref : Ref[DateYMD] = Ref({ y: 0, m: 1, d: 1, })
      let inm : Ref[Bool] = Ref(false)
      let hover = Ref(false)
      let c = @yue.themed_container(style=[
        ("width", cell_w),
        ("height", cell_h),
      ])
      c.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(c)
        let d = dref.val
        let in_m = inm.val
        let st = state_of(d)
        let solid = match st {
          Selected | RangeEdge => true
          Plain | InRange => false
        }
        if hover.val && !solid {
          p.set_fill_color(@yue.theme_fill_hover())
          p.fill_rect(0.0, 0.0, b.width, b.height)
        }
        match st {
          InRange => {
            p.set_fill_color(@yue.theme_primary_light())
            p.fill_rect(0.0, 0.0, b.width, b.height)
          }
          Plain | Selected | RangeEdge => ()
        }
        if solid {
          p.set_fill_color(@yue.theme_primary())
          p.fill_rect(
            (b.width - 28.0) / 2.0,
            (b.height - 28.0) / 2.0,
            28.0,
            28.0,
          )
          draw_center(p, d.d.to_string(), 0.0, b.height, "#FFFFFF")
        } else {
          let color = if !in_m {
            @yue.theme_text_secondary()
          } else if today.y == d.y && today.m == d.m && today.d == d.d {
            @yue.theme_primary()
          } else if st is InRange {
            @yue.theme_primary()
          } else {
            @yue.theme_text_primary()
          }
          draw_center(p, d.d.to_string(), 0.0, b.height, color)
        }
      })
      @yue.View::set_cursor(c, @yue.hand())
      // release 才选中:弹层内点项一律 release 防穿透;
      // calendar_t 内联面板同语义无副作用(松开选中,标准按钮感)。
      // 跨月格不可选(inm 校验在回调内,格子稳定不随月重建)
      @yue.ViewLike::on_mouse_up(c, fn(e) {
        if e.button == 1 && inm.val {
          on_cell(dref.val)
          for cc in cells.val {
            @yue.ViewLike::schedule_paint(cc)
          }
          true
        } else {
          false
        }
      })
      @yue.ViewLike::on_mouse_enter(c, fn(_e) {
        hover.val = true
        @yue.ViewLike::schedule_paint(c)
      })
      @yue.ViewLike::on_mouse_leave(c, fn(_e) {
        hover.val = false
        @yue.ViewLike::schedule_paint(c)
      })
      r.add_child(c)
      cells.val.push(c)
      cell_date.val.push(dref)
      cell_inm.val.push(inm)
    }
    grid.add_child(r)
  }

  fn rebuild_grid() -> Unit {
    let y = view_y.val
    let m = view_m.val
    title_text.val = "\{y} 年 \{m} 月"
    @yue.ViewLike::schedule_paint(title)
    let first_wd = date_weekday(y, m, 1)
    let dim = date_days_in_month(y, m)
    let dim_prev = date_days_in_month(
      if m == 1 {
        y - 1
      } else {
        y
      },
      if m == 1 {
        12
      } else {
        m - 1
      },
    )
    for idx in 0..<42 {
      let in_month = idx >= first_wd && idx < first_wd + dim
      let dd = if idx < first_wd {
        dim_prev - (first_wd - 1 - idx)
      } else if in_month {
        idx - first_wd + 1
      } else {
        idx - first_wd - dim + 1
      }
      let dy = if in_month || idx < first_wd {
        if idx < first_wd && m == 1 {
          y - 1
        } else {
          y
        }
      } else if m == 12 {
        y + 1
      } else {
        y
      }
      let dm = if idx < first_wd {
        if m == 1 {
          12
        } else {
          m - 1
        }
      } else if in_month {
        m
      } else if m == 12 {
        1
      } else {
        m + 1
      }
      cell_date.val[idx].val = { y: dy, m: dm, d: dd, }
      cell_inm.val[idx].val = in_month
      @yue.ViewLike::schedule_paint(cells.val[idx])
    }
  }

  rebuild_ref.val = rebuild_grid
  rebuild_grid()
  panel.add_child(head)
  panel.add_child(wk)
  panel.add_child(grid)
  (panel, rebuild_grid)
}

///|
/// 日历面板(EP DatePicker 的面板形态,全自绘):‹/› 切月 + 星期行 +
/// 42 格月网格,跨月日期灰显,「今天」主题色,选中日期实心主题色方块。
/// 点击当月日期回调 on_pick 并写入 value。
pub fn calendar_t(
  on_pick? : (DateYMD) -> Unit = fn(_d) {  },
  value? : @yue.Store[DateYMD?],
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let today = local_date()
      let sel : Ref[DateYMD?] = Ref(
        match value {
          Some(s) => s.get()
          None => None
        },
      )
      let (panel, refresh) = build_calendar(
        today,
        fn(d) {
          match sel.val {
            Some(s) => if date_eq(s, d) { Selected } else { Plain }
            None => Plain
          }
        },
        fn(d) {
          sel.val = Some(d)
          match value {
            Some(s) => s.set(Some(d))
            None => ()
          }
          on_pick(d)
        },
      )
      @yue.apply_style(panel, style~)
      handle(panel)
      match value {
        Some(s) => s.subscribe(fn(_v) { refresh() })
        None => ()
      }
      @yue.attach(parent, @yue.ViewLike::view(panel))
      @yue.ViewLike::view(panel)
    },
  }
}

///|
/// 日期选择器(EP DatePicker,全自绘):输入框样式字段,点击弹出
/// 自绘日历面板(Popover 承载,三平台弹层基座见 shim),点选回填并收起;
/// 点击其他区域(字段失焦)收起。选中间经 value 同步,回调收 DateYMD。
/// clearable=true 时字段悬停且有值,箭头左侧显示 ✕,点击清空
/// (value 置 None;on_change 签名不带空值,清空不触发回调)。
pub fn date_picker_t(
  value? : @yue.Store[DateYMD?],
  on_change? : (DateYMD) -> Unit = fn(_d) {  },
  placeholder? : String = "请选择日期",
  clearable? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let today = local_date()
      let sel : Ref[DateYMD?] = Ref(
        match value {
          Some(s) => s.get()
          None => None
        },
      )
      let text = Ref(
        match sel.val {
          Some(d) => d.format()
          None => placeholder
        },
      )
      let has_val = Ref(
        match sel.val {
          Some(_) => true
          None => false
        },
      )
      // 弹层与面板:首开时创建,面板重建函数挂入 grid_refresh 供外部同步
      let pop : Ref[@yue.Popover?] = Ref(None)
      let grid_refresh : Ref[() -> Unit] = Ref(fn() {  })
      let field = build_picker_field(
        200.0,
        text,
        has_val,
        clearable,
        on_focus_changed=fn(f) {
          if !f {
            match pop.val {
              Some(p) => p.close()
              None => ()
            }
          }
        },
        extra_style=style,
      )
      fn apply_date(d : DateYMD) -> Unit {
        sel.val = Some(d)
        text.val = d.format()
        has_val.val = true
        @yue.ViewLike::schedule_paint(field)
        match value {
          Some(s) => s.set(Some(d))
          None => ()
        }
        on_change(d)
      }

      @yue.ViewLike::on_mouse_up(field, fn(e) {
        if e.button == 1 {
          @yue.ViewLike::focus(field)
          // 清空带(箭头左侧)优先:清空日期,不弹日历
          if picker_clear_hit(field, e, clearable, has_val.val) {
            sel.val = None
            text.val = placeholder
            has_val.val = false
            match value {
              Some(s) => s.set(None)
              None => ()
            }
            @yue.ViewLike::schedule_paint(field)
            return true
          }
          match pop.val {
            Some(_) => ()
            None => {
              let p = @yue.Popover::new()
              @yue.bind_popover_bg(p)
              let (panel, refresh) = build_calendar(
                today,
                fn(d) {
                  match sel.val {
                    Some(s) => if date_eq(s, d) { Selected } else { Plain }
                    None => Plain
                  }
                },
                fn(d) {
                  apply_date(d)
                  p.close()
                },
              )
              ignore(refresh)
              grid_refresh.val = refresh
              p.set_content(panel)
              // 面板高:上下 padding 16 + 头 36 + 星期 26 + 6 行 x 30
              p.set_content_size(268.0, 262.0)
              pop.val = Some(p)
            }
          }
          match pop.val {
            Some(p) => p.show_relative_to(field)
            None => ()
          }
          true
        } else {
          false
        }
      })
      match value {
        Some(s) =>
          s.subscribe(fn(v) {
            sel.val = v
            match v {
              Some(d) => {
                text.val = d.format()
                has_val.val = true
              }
              None => {
                text.val = placeholder
                has_val.val = false
              }
            }
            @yue.ViewLike::schedule_paint(field)
            (grid_refresh.val)()
          })
        None => ()
      }
      @yue.attach(parent, @yue.ViewLike::view(field))
      @yue.ViewLike::view(field)
    },
  }
}

///|
/// 选择器家族共用的输入框样式字段(date_picker_t 与区间选择器):
/// 边框(聚焦变主题色)+ 文本(有值主色/无值次色)+ 右侧下拉小箭头,
/// clearable=true 悬停且有值时箭头左侧显示 ✕。焦点/悬停态内部管理;
/// 聚焦变化回调 on_focus_changed(弹层随失焦关闭挂这里),点击行为
/// (弹层与清空)由调用方注册 on_mouse_up。
fn build_picker_field(
  width : Double,
  text : Ref[String],
  has_val : Ref[Bool],
  clearable : Bool,
  on_focus_changed? : (Bool) -> Unit = fn(_f) {  },
  extra_style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Container {
  let fnt = @yue.Font::new("Sans", 13.0)
  let hover = Ref(false)
  let focused = Ref(false)
  let style : Array[(String, &@yue.StyVal)] = [
    ("width", width),
    ("height", @yue.control_height),
    ("marginBottom", 10.0),
    ("flexDirection", "row"),
    ("alignItems", "center"),
  ]
  for kv in extra_style {
    style.push(kv)
  }
  let field = @yue.themed_container(style~)
  @yue.set_panel_bg(field)
  @yue.View::set_cursor(field, @yue.hand())
  field.on_draw(fn(p) {
    let b = @yue.ViewLike::get_bounds(field)
    p.set_stroke_color(
      if focused.val {
        @yue.theme_focus_accent()
      } else {
        @yue.theme_border()
      },
    )
    p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
    let probe = @yue.AttributedText::new(text.val, wrap=false)
    probe.set_font(fnt)
    p.draw_text(
      text.val,
      10.0,
      0.0,
      b.width - 30.0,
      b.height,
      valign=@yue.Center,
      color=if has_val.val {
        @yue.theme_text_primary()
      } else {
        @yue.theme_text_secondary()
      },
    )
    // 右侧下拉小箭头(矢量自绘,不依赖字体字形)
    p.set_fill_color(@yue.theme_text_secondary())
    p.begin_path()
    p.move_to(b.width - 20.0, b.height / 2.0 - 2.0)
    p.line_to(b.width - 12.0, b.height / 2.0 - 2.0)
    p.line_to(b.width - 16.0, b.height / 2.0 + 3.0)
    p.close_path()
    p.fill()
    if clearable && hover.val && has_val.val {
      draw_clear_x(p, b.width - 30.0, b.height / 2.0)
    }
  })
  @yue.ViewLike::set_focusable(field, true)
  @yue.ViewLike::on_focus_in(field, fn() {
    focused.val = true
    @yue.ViewLike::schedule_paint(field)
    on_focus_changed(true)
    false
  })
  @yue.ViewLike::on_focus_out(field, fn() {
    focused.val = false
    @yue.ViewLike::schedule_paint(field)
    on_focus_changed(false)
    false
  })
  @yue.ViewLike::on_mouse_enter(field, fn(_e) {
    hover.val = true
    @yue.ViewLike::schedule_paint(field)
  })
  @yue.ViewLike::on_mouse_leave(field, fn(_e) {
    hover.val = false
    @yue.ViewLike::schedule_paint(field)
  })
  field
}

///|
/// 点击是否落在字段清空带(下拉箭头左侧的 ✕ 区域)。
fn picker_clear_hit(
  field : @yue.Container,
  e : @yue.MouseEvent,
  clearable : Bool,
  has_val : Bool,
) -> Bool {
  if !(clearable && has_val) {
    return false
  }
  let b = @yue.ViewLike::get_bounds(field)
  e.view_x >= b.width - 40.0 && e.view_x <= b.width - 20.0
}

///|
/// 区间日历的格子状态映射:两端点实心方块,闭区间内浅蓝底。
fn range_state_of(
  start : Ref[DateYMD?],
  end : Ref[DateYMD?],
) -> (DateYMD) -> CalCell {
  fn state_of(d : DateYMD) -> CalCell {
    match (start.val, end.val) {
      (Some(s), Some(e)) =>
        if date_eq(d, s) || date_eq(d, e) {
          RangeEdge
        } else if date_in_range(d, s, e) {
          InRange
        } else {
          Plain
        }
      (Some(s), None) => if date_eq(d, s) { RangeEdge } else { Plain }
      (None, None) | (None, Some(_)) => Plain
    }
  }

  state_of
}

///|
/// 区间两段式点击:尚无区间 → 写起点;只有起点 → 写终点(终点早于起点
/// 自动对调)并回调 on_done;已有完整区间再点 → 重新从新起点开始。
fn range_cell_click(
  start : Ref[DateYMD?],
  end : Ref[DateYMD?],
  d : DateYMD,
  on_done : (DateYMD, DateYMD) -> Unit,
) -> Unit {
  match (start.val, end.val) {
    (Some(_), Some(_)) => {
      start.val = Some(d)
      end.val = None
    }
    (Some(s), None) => {
      let (a, b) = if date_cmp(d, s) < 0 { (d, s) } else { (s, d) }
      start.val = Some(a)
      end.val = Some(b)
      on_done(a, b)
    }
    (None, None) | (None, Some(_)) => {
      start.val = Some(d)
      end.val = None
    }
  }
}

///|
/// 一行「时:分」编辑器(标签 + 时 0-23 / 分 0-59 两个 input_number):
/// 任一步进写回 hm 并回调 on_change;sync 供外部值变化时回填步进器
/// 显示,回填期间置 mute=true 避免回环触发 on_change。
fn build_time_row(
  label : String,
  hm : Ref[TimeHM],
  mute : Ref[Bool],
  on_change : () -> Unit,
) -> (@yue.Node, (TimeHM) -> Unit) {
  let hs : @yue.Store[Double] = @yue.Store::new(hm.val.h.to_double())
  let ms : @yue.Store[Double] = @yue.Store::new(hm.val.m.to_double())
  hs.subscribe(fn(v) {
    hm.val = time_clamp(v.round().to_int(), hm.val.m)
    if !mute.val {
      on_change()
    }
  })
  ms.subscribe(fn(v) {
    hm.val = time_clamp(hm.val.h, v.round().to_int())
    if !mute.val {
      on_change()
    }
  })
  let row = @declarative.hbox(
    [
      label_t(label, role=Body, style=[("width", 28.0), ("marginRight", 6.0)]),
      input_number(hs, min=0.0, max=23.0, step=1.0, num_width=40.0),
      label_t(":", role=Body),
      input_number(ms, min=0.0, max=59.0, step=1.0, num_width=40.0),
    ],
    style=[("marginBottom", 6.0), ("alignItems", "center")],
  )
  fn sync(t : TimeHM) -> Unit {
    mute.val = true
    hs.set(t.h.to_double())
    ms.set(t.m.to_double())
    mute.val = false
  }

  (row, sync)
}

///|
/// 弹层内的起/止两行时间编辑面板;sync(起, 止) 回填两行显示(mute
/// 包裹,不触发 on_change),mute 供调用方在程序化写值期间整体静音。
fn build_time_panel(
  start_hm : Ref[TimeHM],
  end_hm : Ref[TimeHM],
  on_change : () -> Unit,
) -> (@yue.Container, (TimeHM, TimeHM) -> Unit, Ref[Bool]) {
  let mute = Ref(false)
  let (row1, sync1) = build_time_row("起", start_hm, mute, on_change)
  let (row2, sync2) = build_time_row("止", end_hm, mute, on_change)
  let panel = @yue.themed_container(style=[ // 显式总高:PopoverRootView 按 content_size 硬分配,不读内容自然
    // 高度,漏显式高度会把两行压塌(高 = 上下 padding 16 + 两行 x 36)
    ("padding", 8.0),
    ("width", 268.0),
    ("height", 16.0 + 2.0 * 36.0),
    ("flexDirection", "column"),
  ])
  @yue.set_panel_bg(panel)
  let _ = row1.mount_into(panel.view())
  let _ = row2.mount_into(panel.view())
  fn sync(s : TimeHM, e : TimeHM) -> Unit {
    sync1(s)
    sync2(e)
  }

  (panel, sync, mute)
}

///|
/// 日期区间选择器(EP DateRangePicker,全自绘):字段显示「起 ~ 止」,
/// 点击弹区间日历——第一次点选起点,第二次点选终点(终点早于起点自动
/// 对调)后收起,回调 on_change(起, 止);再点字段重新开始新区间。
/// clearable=true 清空两端(value 置全空,on_change 不因清空触发)。
pub fn date_range_picker_t(
  value? : @yue.Store[DateRange],
  on_change? : (DateYMD, DateYMD) -> Unit = fn(_s, _e) {  },
  placeholder? : String = "请选择日期区间",
  clearable? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let today = local_date()
      let pop : Ref[@yue.Popover?] = Ref(None)
      let start : Ref[DateYMD?] = Ref(
        match value {
          Some(v) => v.get().start
          None => None
        },
      )
      let end : Ref[DateYMD?] = Ref(
        match value {
          Some(v) => v.get().end
          None => None
        },
      )
      let text = Ref("")
      let has_val = Ref(false)
      let grid_refresh : Ref[() -> Unit] = Ref(fn() {  })
      let field = build_picker_field(
        260.0,
        text,
        has_val,
        clearable,
        on_focus_changed=fn(f) {
          if !f {
            match pop.val {
              Some(p) => p.close()
              None => ()
            }
          }
        },
        extra_style=style,
      )
      fn refresh_text() -> Unit {
        match (start.val, end.val) {
          (Some(s), Some(e)) => {
            text.val = "\{s.format()} ~ \{e.format()}"
            has_val.val = true
          }
          (Some(s), None) => {
            text.val = "\{s.format()} ~"
            has_val.val = true
          }
          (None, None) | (None, Some(_)) => {
            text.val = placeholder
            has_val.val = false
          }
        }
        @yue.ViewLike::schedule_paint(field)
      }

      fn write_value(s : DateYMD?, e : DateYMD?) -> Unit {
        match value {
          Some(v) => v.set({ start: s, end: e, })
          None => ()
        }
      }

      @yue.ViewLike::on_mouse_up(field, fn(e) {
        if e.button == 1 {
          @yue.ViewLike::focus(field)
          if picker_clear_hit(field, e, clearable, has_val.val) {
            start.val = None
            end.val = None
            write_value(None, None)
            refresh_text()
            match pop.val {
              Some(p) => p.close()
              None => ()
            }
            return true
          }
          match pop.val {
            Some(_) => ()
            None => {
              let p = @yue.Popover::new()
              @yue.bind_popover_bg(p)
              let (panel, refresh) = build_calendar(
                today,
                range_state_of(start, end),
                fn(d) {
                  range_cell_click(start, end, d, fn(a, b) {
                    refresh_text()
                    write_value(Some(a), Some(b))
                    on_change(a, b)
                    p.close()
                  })
                  refresh_text()
                },
              )
              grid_refresh.val = refresh
              refresh()
              p.set_content(panel)
              p.set_content_size(268.0, 262.0)
              pop.val = Some(p)
            }
          }
          match pop.val {
            Some(p) => p.show_relative_to(field)
            None => ()
          }
          true
        } else {
          false
        }
      })
      match value {
        Some(v) =>
          v.subscribe(fn(r) {
            start.val = r.start
            end.val = r.end
            refresh_text()
            (grid_refresh.val)()
          })
        None => ()
      }
      refresh_text()
      @yue.attach(parent, @yue.ViewLike::view(field))
      @yue.ViewLike::view(field)
    },
  }
}

///|
/// 时间区间选择器(EP TimeRangePicker,全自绘):字段显示「起:止」
/// 时:分,点击弹起/止两行步进编辑器(时 0-23 / 分 0-59),步进即改
/// 即回调 on_change;起止默认 00:00,弹层随字段失焦收起。clearable
/// 清空两端(重开弹层后步进即重新写入)。
pub fn time_range_picker_t(
  value? : @yue.Store[TimeRange],
  on_change? : (TimeHM, TimeHM) -> Unit = fn(_s, _e) {  },
  placeholder? : String = "请选择时间区间",
  clearable? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let pop : Ref[@yue.Popover?] = Ref(None)
      let start = Ref(time_clamp(0, 0))
      let end = Ref(time_clamp(0, 0))
      let touched = Ref(false) // 弹层内动过步进才视为有值
      let text = Ref("")
      let has_val = Ref(false)
      let field = build_picker_field(
        180.0,
        text,
        has_val,
        clearable,
        on_focus_changed=fn(f) {
          if !f {
            match pop.val {
              Some(p) => p.close()
              None => ()
            }
          }
        },
        extra_style=style,
      )
      fn refresh_text() -> Unit {
        if has_val.val {
          text.val = "\{start.val.format()} ~ \{end.val.format()}"
        } else {
          text.val = placeholder
        }
        @yue.ViewLike::schedule_paint(field)
      }

      fn write_value(s : TimeHM, e : TimeHM) -> Unit {
        match value {
          Some(v) => v.set({ start: Some(s), end: Some(e), })
          None => ()
        }
      }

      @yue.ViewLike::on_mouse_up(field, fn(e) {
        if e.button == 1 {
          @yue.ViewLike::focus(field)
          if picker_clear_hit(field, e, clearable, has_val.val) {
            touched.val = false
            has_val.val = false
            match value {
              Some(v) => v.set({ start: None, end: None, })
              None => ()
            }
            refresh_text()
            match pop.val {
              Some(p) => p.close()
              None => ()
            }
            return true
          }
          match pop.val {
            Some(_) => ()
            None => {
              let p = @yue.Popover::new()
              @yue.bind_popover_bg(p)
              let (panel, _sync, _mute) = build_time_panel(start, end, fn() {
                if !touched.val {
                  touched.val = true
                  has_val.val = true
                }
                refresh_text()
                write_value(start.val, end.val)
                on_change(start.val, end.val)
              })
              p.set_content(panel)
              // 高 = 时间面板 88(+4 余量)
              p.set_content_size(268.0, 92.0)
              pop.val = Some(p)
            }
          }
          match pop.val {
            Some(p) => p.show_relative_to(field)
            None => ()
          }
          true
        } else {
          false
        }
      })
      match value {
        Some(v) =>
          v.subscribe(fn(r) {
            match (r.start, r.end) {
              (Some(s), Some(e)) => {
                start.val = s
                end.val = e
                touched.val = true
                has_val.val = true
              }
              (_, _) => {
                touched.val = false
                has_val.val = false
              }
            }
            refresh_text()
          })
        None => ()
      }
      refresh_text()
      @yue.attach(parent, @yue.ViewLike::view(field))
      @yue.ViewLike::view(field)
    },
  }
}

///|
/// 日期时间区间选择器(EP DateTimeRangePicker,全自绘):字段显示
/// 「起日期 起:分 ~ 止日期 止:分」,点击弹区间日历 + 底部起/止两行
/// 时间步进;日期两段式选完或时间步进后,区间完整即回调 on_change
/// (起日期, 起时间, 止日期, 止时间);「完成」按钮或字段失焦收起。
pub fn datetime_range_picker_t(
  value? : @yue.Store[DateTimeRange],
  on_change? : (DateYMD, TimeHM, DateYMD, TimeHM) -> Unit = fn(
    _sd,
    _st,
    _ed,
    _et,
  ) {

  },
  placeholder? : String = "请选择日期时间区间",
  clearable? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
) -> @yue.Node {
  {
    mount: fn(parent) {
      let today = local_date()
      let pop : Ref[@yue.Popover?] = Ref(None)
      let start_d : Ref[DateYMD?] = Ref(
        match value {
          Some(v) =>
            match v.get().start {
              Some((d, _t)) => Some(d)
              None => None
            }
          None => None
        },
      )
      let end_d : Ref[DateYMD?] = Ref(
        match value {
          Some(v) =>
            match v.get().end {
              Some((d, _t)) => Some(d)
              None => None
            }
          None => None
        },
      )
      let start_t = Ref(
        match value {
          Some(v) =>
            match v.get().start {
              Some((_d, t)) => t
              None => time_clamp(0, 0)
            }
          None => time_clamp(0, 0)
        },
      )
      let end_t = Ref(
        match value {
          Some(v) =>
            match v.get().end {
              Some((_d, t)) => t
              None => time_clamp(0, 0)
            }
          None => time_clamp(0, 0)
        },
      )
      let text = Ref("")
      let has_val = Ref(false)
      let time_sync : Ref[(TimeHM, TimeHM) -> Unit] = Ref(fn(_st, _et) {  })
      let grid_refresh_d : Ref[() -> Unit] = Ref(fn() {  })
      let field = build_picker_field(
        340.0,
        text,
        has_val,
        clearable,
        on_focus_changed=fn(f) {
          if !f {
            match pop.val {
              Some(p) => p.close()
              None => ()
            }
          }
        },
        extra_style=style,
      )
      fn refresh_text() -> Unit {
        match (start_d.val, end_d.val) {
          (Some(sd), Some(ed)) => {
            text.val = "\{sd.format()} \{start_t.val.format()} ~ \{ed.format()} \{end_t.val.format()}"
            has_val.val = true
          }
          (Some(sd), None) => {
            text.val = "\{sd.format()} \{start_t.val.format()} ~"
            has_val.val = true
          }
          (None, None) | (None, Some(_)) => {
            text.val = placeholder
            has_val.val = false
          }
        }
        @yue.ViewLike::schedule_paint(field)
      }

      fn write_value() -> Unit {
        match value {
          Some(v) => {
            let s : (DateYMD, TimeHM)? = match start_d.val {
              Some(d) => Some((d, start_t.val))
              None => None
            }
            let e : (DateYMD, TimeHM)? = match end_d.val {
              Some(d) => Some((d, end_t.val))
              None => None
            }
            v.set({ start: s, end: e, })
          }
          None => ()
        }
      }

      fn emit() -> Unit {
        // 区间完整才对外回调;不完整只反映在 value 的中间态
        match (start_d.val, end_d.val) {
          (Some(sd), Some(ed)) => {
            write_value()
            on_change(sd, start_t.val, ed, end_t.val)
          }
          _ => write_value()
        }
      }

      @yue.ViewLike::on_mouse_up(field, fn(e) {
        if e.button == 1 {
          @yue.ViewLike::focus(field)
          if picker_clear_hit(field, e, clearable, has_val.val) {
            start_d.val = None
            end_d.val = None
            write_value()
            refresh_text()
            match pop.val {
              Some(p) => p.close()
              None => ()
            }
            return true
          }
          match pop.val {
            Some(_) => ()
            None => {
              let p = @yue.Popover::new()
              @yue.bind_popover_bg(p)
              let (cal, refresh) = build_calendar(
                today,
                range_state_of(start_d, end_d),
                fn(d) {
                  range_cell_click(start_d, end_d, d, fn(_a, _b) { emit() })
                  refresh_text()
                },
              )
              let (tpanel, sync, _mute) = build_time_panel(start_t, end_t, fn() {
                emit()
                refresh_text()
              })
              time_sync.val = sync
              grid_refresh_d.val = refresh
              // 显式总宽高:PopoverRootView 按 content_size 硬分配,漏显式
              // 高度会把时间面板/完成行压塌
              let body = @yue.themed_container(style=[
                ("width", 268.0),
                ("height", 258.0 + 1.0 + 88.0 + 32.0),
                ("flexDirection", "column"),
              ])
              body.add_child(cal)
              let sep = @yue.themed_container(style=[("height", 1.0)])
              sep.on_draw(fn(p2) {
                let b2 = @yue.ViewLike::get_bounds(sep)
                p2.set_stroke_color(@yue.theme_border())
                p2.stroke_rect(0.5, 0.5, b2.width - 1.0, 0.0)
              })
              body.add_child(sep)
              body.add_child(tpanel)
              let done_row = @yue.themed_container(style=[
                ("height", 32.0),
                ("padding", 6.0),
                ("flexDirection", "row"),
                ("alignItems", "center"),
                ("justifyContent", "flex-end"),
              ])
              let _ = button_t("完成", variant=Solid, on_click=fn() {
                p.close()
              }).mount_into(done_row.view())
              body.add_child(done_row)
              p.set_content(body)
              // 高 = 日历面板 258 + 分隔 1 + 时间面板 88 + 完成行 32 = 379(+5 余量)
              p.set_content_size(268.0, 384.0)
              pop.val = Some(p)
            }
          }
          match pop.val {
            Some(p) => p.show_relative_to(field)
            None => ()
          }
          true
        } else {
          false
        }
      })
      match value {
        Some(v) =>
          v.subscribe(fn(r) {
            match r.start {
              Some((d, t)) => {
                start_d.val = Some(d)
                start_t.val = t
              }
              None => start_d.val = None
            }
            match r.end {
              Some((d, t)) => {
                end_d.val = Some(d)
                end_t.val = t
              }
              None => end_d.val = None
            }
            (time_sync.val)(start_t.val, end_t.val)
            refresh_text()
            (grid_refresh_d.val)()
          })
        None => ()
      }
      refresh_text()
      @yue.attach(parent, @yue.ViewLike::view(field))
      @yue.ViewLike::view(field)
    },
  }
}
