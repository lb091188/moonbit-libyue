// 日期/时间选择器四只：字段 + 弹层。弹层一律开在浮层图层上（`overlay.mbt` 那套：
// 整窗图层、空则不可见、点外收起），日历面板与网格复用 `datetime.mbt` 的
// `build_calendar`/`month_grid`/`range_state_of`。
//
// 与 master 的两条差（记档）：① 旧链路弹层是原生 Popover（`@yue.Popover`），本栈
// 用自绘面板；② 旧链路的时间是「时/分两个 input_number 输入框」，本栈改成
// 「时/分步进器」（自绘栈里没有原生输入框语义，键盘编辑要另配一套焦点与输入法
// 通道，性价比低——需要键盘输入的多行文本请用 `entry`/`textarea`）。

///|
/// 把控件配成选择器字段（EP DatePicker 的输入框样式）：面板底 + 描边 + 文本 +
/// 右侧下拉箭头；`clearable` 且悬停且有值时，箭头左侧画 ✕。
/// `on_click` 收到的是**本地 x**：调用方据此区分「点 ✕ 清空」与「点其余处开合」。
fn setup_picker_field(
  w : @core.Widget,
  width : Double,
  text_of : () -> String,
  filled : () -> Bool,
  clearable : Bool,
  on_click : (Double) -> Unit,
) -> Unit {
  let font = @text.Font::new("", 13.0)
  watch_theme()
  w.node.set_width(@yoga.fixed(width))
  w.node.set_height(@yoga.fixed(32.0))
  w.cursor = @core.CURSOR_HAND
  w.on_draw = Some(fn(
    self : @core.Widget,
    p : @render.Painter,
    r : @core.Rect,
  ) -> Unit {
    p.set_fill_color(@theme.theme_bg_panel())
    p.fill_rect(0.0, 0.0, r.w, r.h)
    p.set_stroke_color(@theme.theme_border())
    p.set_line_width(1.0)
    p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
    let txt = text_of()
    let _ = @text.draw_box_at(
      p,
      10.0,
      0.0,
      (r.w - 44.0).max(1.0),
      r.h,
      txt,
      font,
      if filled() {
        @theme.theme_text_primary()
      } else {
        @theme.theme_text_secondary()
      },
      align=@text.Start,
      valign=@text.Center,
    )
    // 下拉箭头（矢量自绘）
    p.set_fill_color(@theme.theme_text_secondary())
    p.begin_path()
    p.move_to(r.w - 20.0, r.h / 2.0 - 2.0)
    p.line_to(r.w - 12.0, r.h / 2.0 - 2.0)
    p.line_to(r.w - 16.0, r.h / 2.0 + 3.0)
    p.close_path()
    p.fill()
    if clearable && self.hovered && filled() {
      p.set_stroke_color(@theme.theme_text_secondary())
      p.set_line_width(1.3)
      p.begin_path()
      p.move_to(r.w - 33.0, r.h / 2.0 - 3.5)
      p.line_to(r.w - 26.0, r.h / 2.0 + 3.5)
      p.move_to(r.w - 26.0, r.h / 2.0 - 3.5)
      p.line_to(r.w - 33.0, r.h / 2.0 + 3.5)
      p.stroke()
    }
  })
  w.on_pointer = Some(fn(
    _self : @core.Widget,
    ev : @core.PointerEvent,
  ) -> Bool {
    match ev.kind {
      @core.Down => true
      @core.Up => {
        on_click(ev.x)
        @core.invalidate()
        false
      }
      _ => false
    }
  })
}

///|
/// ✕ 热区（箭头左侧 20px 带宽）。
fn clear_hit(local_x : Double, width : Double, clearable : Bool, filled : Bool) -> Bool {
  clearable && filled && local_x >= width - 40.0 && local_x <= width - 20.0
}

///|
/// 日历弹层（面板形态与 `calendar_t` 相同，但开在浮层图层上）。
fn calendar_popup(
  today : DateYMD,
  state_of : (DateYMD) -> CalCell,
  on_cell : (DateYMD) -> Unit,
) -> @core.Node {
  @core.node_of_new(fn(panel : @core.Widget) -> @core.Widget {
    let _ = build_calendar(panel, today, state_of, on_cell)
    panel
  })
}

///|
/// 时间弹层：时/分两个步进器（长按不做，点一下 ±1；时 0-23、分 0-59 循环）。
fn time_popup(
  initial : TimeHM,
  on_confirm : (TimeHM) -> Unit,
  on_cancel : () -> Unit,
) -> @core.Node {
  let cur : Ref[TimeHM] = Ref(initial)
  @core.node_of_new(fn(panel : @core.Widget) -> @core.Widget {
    watch_theme()
    let font = @text.Font::new("", 14.0)
    panel.node.set_flex_direction(@yoga.Column)
    panel.node.set_width(@yoga.fixed(180.0))
    panel.set_padding(top=10.0, left=10.0)
    panel.on_draw = Some(fn(
      _s : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_stroke_color(@theme.theme_border())
      p.set_line_width(1.0)
      p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
      let _ = @text.draw_box_at(
        p,
        0.0,
        0.0,
        r.w,
        28.0,
        cur.val.format(),
        font,
        @theme.theme_text_primary(),
        align=@text.Center,
        valign=@text.Center,
      )
    })
    // 步进行：[−] 标签 [+]
    fn stepper(label_text : String, step : (Int) -> TimeHM) -> @core.Node {
      view(
        [
          @core.node_of_new(fn(b : @core.Widget) -> @core.Widget {
            watch_theme()
            b.node.set_width(@yoga.fixed(30.0))
            b.node.set_height(@yoga.fixed(28.0))
            b.on_draw = Some(fn(
              self : @core.Widget,
              p : @render.Painter,
              r : @core.Rect,
            ) -> Unit {
              p.set_fill_color(
                if self.hovered {
                  @theme.theme_fill_hover()
                } else {
                  @theme.theme_bg_panel()
                },
              )
              fill_round_rect(p, 0.0, 0.0, r.w, r.h, 4.0)
              p.set_stroke_color(@theme.theme_border())
              p.set_line_width(1.0)
              p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
              p.set_stroke_color(@theme.theme_text_regular())
              p.set_line_width(1.4)
              p.begin_path()
              p.move_to(10.0, r.h / 2.0)
              p.line_to(r.w - 10.0, r.h / 2.0)
              p.stroke()
            })
            b.cursor = @core.CURSOR_HAND
            b.on_pointer = Some(fn(
              _s : @core.Widget,
              ev : @core.PointerEvent,
            ) -> Bool {
              match ev.kind {
                @core.Down => true
                @core.Up => {
                  cur.val = step(-1)
                  @core.invalidate()
                  false
                }
                _ => false
              }
            })
            b
          }),
          label(label_text, size=12.0),
          @core.node_of_new(fn(b : @core.Widget) -> @core.Widget {
            watch_theme()
            b.node.set_width(@yoga.fixed(30.0))
            b.node.set_height(@yoga.fixed(28.0))
            b.on_draw = Some(fn(
              self : @core.Widget,
              p : @render.Painter,
              r : @core.Rect,
            ) -> Unit {
              p.set_fill_color(
                if self.hovered {
                  @theme.theme_fill_hover()
                } else {
                  @theme.theme_bg_panel()
                },
              )
              fill_round_rect(p, 0.0, 0.0, r.w, r.h, 4.0)
              p.set_stroke_color(@theme.theme_border())
              p.set_line_width(1.0)
              p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
              p.set_stroke_color(@theme.theme_text_regular())
              p.set_line_width(1.4)
              p.begin_path()
              p.move_to(10.0, r.h / 2.0)
              p.line_to(r.w - 10.0, r.h / 2.0)
              p.move_to(r.w / 2.0, 8.0)
              p.line_to(r.w / 2.0, r.h - 8.0)
              p.stroke()
            })
            b.cursor = @core.CURSOR_HAND
            b.on_pointer = Some(fn(
              _s : @core.Widget,
              ev : @core.PointerEvent,
            ) -> Bool {
              match ev.kind {
                @core.Down => true
                @core.Up => {
                  cur.val = step(1)
                  @core.invalidate()
                  false
                }
                _ => false
              }
            })
            b
          }),
        ],
        direction=@yoga.Row,
        column_gap=8.0,
        height=32.0,
        align_items=@yoga.AlignItems::Center,
      )
    }

    let _ = stepper("时", fn(d : Int) -> TimeHM {
      let h = cur.val.h + d
      time_clamp(if h < 0 { 23 } else if h > 23 { 0 } else { h }, cur.val.m)
    }).mount_into(panel)
    let _ = stepper("分", fn(d : Int) -> TimeHM {
      let m = cur.val.m + d * 5
      time_clamp(cur.val.h, if m < 0 { 55 } else if m > 59 { 0 } else { m })
    }).mount_into(panel)
    let _ = view(
      [
        @core.node_of_new(fn(b : @core.Widget) -> @core.Widget {
          watch_theme()
          b.node.set_width(@yoga.fixed(70.0))
          b.node.set_height(@yoga.fixed(28.0))
          b.on_draw = Some(fn(
            self : @core.Widget,
            p : @render.Painter,
            r : @core.Rect,
          ) -> Unit {
            p.set_fill_color(
              if self.hovered {
                @theme.theme_fill_hover()
              } else {
                @theme.theme_bg_panel()
              },
            )
            fill_round_rect(p, 0.0, 0.0, r.w, r.h, 4.0)
            p.set_stroke_color(@theme.theme_border())
            p.set_line_width(1.0)
            p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
            let f = @text.Font::new("", 12.0)
            let _ = @text.draw_box_at(
              p,
              0.0,
              0.0,
              r.w,
              r.h,
              "取消",
              f,
              @theme.theme_text_regular(),
              align=@text.Center,
              valign=@text.Center,
            )
          })
          b.cursor = @core.CURSOR_HAND
          b.on_pointer = Some(fn(
            _s : @core.Widget,
            ev : @core.PointerEvent,
          ) -> Bool {
            match ev.kind {
              @core.Down => true
              @core.Up => {
                on_cancel()
                false
              }
              _ => false
            }
          })
          b
        }),
        @core.node_of_new(fn(b : @core.Widget) -> @core.Widget {
          watch_theme()
          b.node.set_width(@yoga.fixed(70.0))
          b.node.set_height(@yoga.fixed(28.0))
          b.on_draw = Some(fn(
            self : @core.Widget,
            p : @render.Painter,
            r : @core.Rect,
          ) -> Unit {
            p.set_fill_color(
              if self.hovered {
                @theme.theme_primary_hover()
              } else {
                @theme.theme_primary()
              },
            )
            fill_round_rect(p, 0.0, 0.0, r.w, r.h, 4.0)
            let f = @text.Font::new("", 12.0)
            let _ = @text.draw_box_at(
              p,
              0.0,
              0.0,
              r.w,
              r.h,
              "确定",
              f,
              "#ffffff",
              align=@text.Center,
              valign=@text.Center,
            )
          })
          b.cursor = @core.CURSOR_HAND
          b.on_pointer = Some(fn(
            _s : @core.Widget,
            ev : @core.PointerEvent,
          ) -> Bool {
            match ev.kind {
              @core.Down => true
              @core.Up => {
                on_confirm(cur.val)
                false
              }
              _ => false
            }
          })
          b
        }),
      ],
      direction=@yoga.Row,
      column_gap=8.0,
      justify_content=@yoga.JustifyContent::FlexEnd,
      width=160.0,
      align_items=@yoga.AlignItems::Center,
    ).mount_into(panel)
    panel
  })
}

///|
/// 日期选择器（EP DatePicker）：字段 + 日历弹层，点选回填并收起；`clearable`
/// 时字段悬停且有值显示 ✕，点它清空（清空不触发 `on_change`，与 master 同）。
pub fn date_picker_t(
  value : @core.Store[DateYMD?],
  on_change? : (DateYMD) -> Unit = fn(_d : DateYMD) -> Unit { () },
  placeholder? : String = "请选择日期",
  clearable? : Bool = true,
  today? : DateYMD = today_date(),
  width? : Double = 180.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(value)
  let t = today
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    let open_id : Ref[Int] = Ref(0)
    let close_pop = fn() -> Unit {
      if open_id.val != 0 {
        @core.overlay_hide(open_id.val)
        open_id.val = 0
      }
    }

    setup_picker_field(
      w,
      width,
      fn() -> String {
        match value.get() {
          Some(d) => d.format()
          None => placeholder
        }
      },
      fn() -> Bool {
        match value.get() {
          Some(_) => true
          None => false
        }
      },
      clearable,
      fn(local_x : Double) -> Unit {
        let filled = match value.get() {
          Some(_) => true
          None => false
        }
        if clear_hit(local_x, width, clearable, filled) {
          value.set(None)
          close_pop()
        } else if overlay_alive(open_id.val) {
          close_pop()
        } else {
          open_id.val = @core.overlay_show_at(
            calendar_popup(
              t,
              fn(d : DateYMD) -> CalCell {
                match value.get() {
                  Some(s) => if DateYMD::same(s, d) { Selected } else { Plain }
                  None => Plain
                }
              },
              fn(d : DateYMD) -> Unit {
                value.set(Some(d))
                on_change(d)
                close_pop()
              },
            ),
            w.rect.x,
            w.rect.y + w.rect.h + 2.0,
          )
        }
      },
    )
    handle(w)
    w
  })
}

///|
/// 日期区间选择器（EP DatePicker 区间形态）：字段 + 日历弹层，两段式点击
/// （先起点、再终点；已有完整区间时再从新起点开始），端点实心、区间内浅底。
pub fn date_range_picker_t(
  value : @core.Store[DateRange],
  on_change? : (DateRange) -> Unit = fn(_r : DateRange) -> Unit { () },
  placeholder? : String = "请选择日期区间",
  clearable? : Bool = true,
  today? : DateYMD = today_date(),
  width? : Double = 220.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(value)
  let t = today
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    let open_id : Ref[Int] = Ref(0)
    let close_pop = fn() -> Unit {
      if open_id.val != 0 {
        @core.overlay_hide(open_id.val)
        open_id.val = 0
      }
    }

    setup_picker_field(
      w,
      width,
      fn() -> String {
        let r = value.get()
        match (r.start, r.end) {
          (None, None) => placeholder
          _ => {
            let s = match r.start {
              Some(x) => x.format()
              None => "?"
            }
            let e = match r.end {
              Some(x) => x.format()
              None => "?"
            }
            s + " ~ " + e
          }
        }
      },
      fn() -> Bool {
        let r = value.get()
        match (r.start, r.end) {
          (Some(_), Some(_)) => true
          (Some(_), None) => true
          _ => false
        }
      },
      clearable,
      fn(local_x : Double) -> Unit {
        let filled = match value.get().start {
          Some(_) => true
          None => false
        }
        if clear_hit(local_x, width, clearable, filled) {
          value.set({ start: None, end: None })
          close_pop()
        } else if overlay_alive(open_id.val) {
          close_pop()
        } else {
          open_id.val = @core.overlay_show_at(
            calendar_popup(
              t,
              fn(d : DateYMD) -> CalCell { range_state_of(value.get(), d) },
              fn(d : DateYMD) -> Unit {
                let r = value.get()
                match (r.start, r.end) {
                  (None, _) => value.set({ start: Some(d), end: None })
                  (Some(_), None) => {
                    value.set({ start: r.start, end: Some(d) })
                    on_change(value.get())
                    close_pop()
                  }
                  (Some(_), Some(_)) => value.set({ start: Some(d), end: None })
                }
              },
            ),
            w.rect.x,
            w.rect.y + w.rect.h + 2.0,
          )
        }
      },
    )
    handle(w)
    w
  })
}

///|
/// 一行「标签 + 时间字段」：点字段开时间弹层，确定后写回。
fn time_field(
  width : Double,
  get : () -> TimeHM?,
  set : (TimeHM) -> Unit,
  placeholder? : String = "?:?",
) -> @core.Node {
  @core.node_of_new(fn(field : @core.Widget) -> @core.Widget {
    let open_id : Ref[Int] = Ref(0)
    let close_pop = fn() -> Unit {
      if open_id.val != 0 {
        @core.overlay_hide(open_id.val)
        open_id.val = 0
      }
    }

    // 字段本体（标签由外层容器画）
    setup_picker_field(
      field,
      width,
      fn() -> String {
        match get() {
          Some(t) => t.format()
          None => placeholder
        }
      },
      fn() -> Bool {
        match get() {
          Some(_) => true
          None => false
        }
      },
      false,
      fn(_local_x : Double) -> Unit {
        if overlay_alive(open_id.val) {
          close_pop()
        } else {
          let init = match get() {
            Some(t) => t
            None => TimeHM::{ h: 9, m: 0 }
          }
          open_id.val = @core.overlay_show_at(
            time_popup(
              init,
              fn(t : TimeHM) -> Unit {
                set(t)
                close_pop()
              },
              close_pop,
            ),
            field.rect.x - 40.0,
            field.rect.y + field.rect.h + 2.0,
          )
        }
      },
    )
    field
  })
}

///|
/// 时间区间选择器（EP TimePicker 区间形态）：起止两个时间字段（步进式弹层）。
pub fn time_range_picker_t(
  value : @core.Store[TimeRange],
  on_change? : (TimeRange) -> Unit = fn(_r : TimeRange) -> Unit { () },
  width? : Double = 110.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(value)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_flex_direction(@yoga.Row)
    w.node.set_align_items(@yoga.AlignItems::Center)
    w.node.set_gap(0.0, 8.0)
    let _ = time_field(
      width,
      fn() -> TimeHM? { value.get().start },
      fn(t : TimeHM) -> Unit {
        let r = value.get()
        value.set({ start: Some(t), end: r.end })
        on_change(value.get())
      },
    ).mount_into(w)
    let _ = label("~", size=13.0).mount_into(w)
    let _ = time_field(
      width,
      fn() -> TimeHM? { value.get().end },
      fn(t : TimeHM) -> Unit {
        let r = value.get()
        value.set({ start: r.start, end: Some(t) })
        on_change(value.get())
      },
    ).mount_into(w)
    handle(w)
    w
  })
}

///|
/// 日期时间区间选择器：起止各一对「日期字段 + 时间字段」，日期走日历弹层、
/// 时间走步进弹层；任一侧任一维改动都会把整份区间写回 Store 并回调。
pub fn datetime_range_picker_t(
  value : @core.Store[DateTimeRange],
  on_change? : (DateTimeRange) -> Unit = fn(_r : DateTimeRange) -> Unit { () },
  today? : DateYMD = today_date(),
  date_width? : Double = 130.0,
  time_width? : Double = 86.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(value)
  let t = today
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_flex_direction(@yoga.Row)
    w.node.set_align_items(@yoga.AlignItems::Center)
    w.node.set_gap(0.0, 6.0)
    fn date_field(is_start : Bool) -> @core.Node {
      @core.node_of_new(fn(field : @core.Widget) -> @core.Widget {
        let open_id : Ref[Int] = Ref(0)
        let close_pop = fn() -> Unit {
          if open_id.val != 0 {
            @core.overlay_hide(open_id.val)
            open_id.val = 0
          }
        }

        setup_picker_field(
          field,
          date_width,
          fn() -> String {
            let pair = if is_start { value.get().start } else { value.get().end }
            match pair {
              Some(p) => p.0.format()
              None => "选择日期"
            }
          },
          fn() -> Bool {
            match (if is_start { value.get().start } else { value.get().end }) {
              Some(_) => true
              None => false
            }
          },
          false,
          fn(_local_x : Double) -> Unit {
            if overlay_alive(open_id.val) {
              close_pop()
            } else {
              open_id.val = @core.overlay_show_at(
                calendar_popup(
                  t,
                  fn(d : DateYMD) -> CalCell {
                    let pair = if is_start { value.get().start } else { value.get().end }
                    match pair {
                      Some(p) => if DateYMD::same(p.0, d) { Selected } else { Plain }
                      None => Plain
                    }
                  },
                  fn(d : DateYMD) -> Unit {
                    let r = value.get()
                    if is_start {
                      let tm = match r.start {
                        Some(p) => p.1
                        None => TimeHM::{ h: 9, m: 0 }
                      }
                      value.set({ start: Some((d, tm)), end: r.end })
                    } else {
                      let tm = match r.end {
                        Some(p) => p.1
                        None => TimeHM::{ h: 18, m: 0 }
                      }
                      value.set({ start: r.start, end: Some((d, tm)) })
                    }
                    on_change(value.get())
                    close_pop()
                  },
                ),
                field.rect.x,
                field.rect.y + field.rect.h + 2.0,
              )
            }
          },
        )
        field
      })
    }

    let _ = date_field(true).mount_into(w)
    let _ = time_field(
      time_width,
      fn() -> TimeHM? {
        match value.get().start {
          Some(p) => Some(p.1)
          None => None
        }
      },
      fn(tm : TimeHM) -> Unit {
        let r = value.get()
        match r.start {
          Some(p) => value.set({ start: Some((p.0, tm)), end: r.end })
          None => ()
        }
        on_change(value.get())
      },
    ).mount_into(w)
    let _ = label("~", size=13.0).mount_into(w)
    let _ = date_field(false).mount_into(w)
    let _ = time_field(
      time_width,
      fn() -> TimeHM? {
        match value.get().end {
          Some(p) => Some(p.1)
          None => None
        }
      },
      fn(tm : TimeHM) -> Unit {
        let r = value.get()
        match r.end {
          Some(p) => value.set({ start: r.start, end: Some((p.0, tm)) })
          None => ()
        }
        on_change(value.get())
      },
    ).mount_into(w)
    handle(w)
    w
  })
}
