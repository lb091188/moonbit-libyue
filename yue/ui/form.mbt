// 表单控件首批：复选 / 单选组 / 开关 / 滑块 / 进度 / 步进器。
//
// 值一律走 `@core.Store[T]`（与 master 同：组件不持有状态，状态归调用方）。
// 组件订阅 Store 只为**请求重绘**——颜色与位置都在 `on_draw` 里现取，订阅退订
// 随本代回收袋，重挂不留死订阅。
//
// 交互统一口径：`Down` 消费（真实事件流里即进入捕获期），`Up` 且松开仍落在
// 自己范围内才算一次操作；需要拖动的（滑块）自己记拖动状态，靠按身份投递的
// 捕获通道拿到出界的移动量。禁用态是 `Enabled` 单元而非布尔（见 state.mbt）。

///|
/// 订阅一个 Store，只为请求重绘；退订随本代回收袋。
fn[T] follow_store(s : @core.Store[T]) -> Unit {
  let sig = s.signal()
  let sid = sig.subscribe(fn(_v : T) -> Unit { @core.invalidate() })
  @core.sub_bag_register(fn() { sig.remove(sid) })
}

///|
/// 一行开关型控件的点击：按下消费，抬起且落在自己范围内才写回值。
fn attach_toggle(
  w : @core.Widget,
  toggle : () -> Unit,
  off : Enabled,
) -> Unit {
  w.on_pointer = Some(fn(self : @core.Widget, ev : @core.PointerEvent) -> Bool {
    match ev.kind {
      @core.Down => !off.off
      @core.Up => {
        let inside_x = ev.x >= 0.0 && ev.x <= self.rect.w
        let inside_y = ev.y >= 0.0 && ev.y <= self.rect.h
        if !off.off && inside_x && inside_y { toggle() }
        false
      }
      @core.Move => !off.off
      @core.Leave => false
    }
  })
}

///|
/// 复选框 + 文本标签（点标签同样生效，整行是点击区）。
pub fn checkbox(
  text : String,
  state : @core.Store[Bool],
  disabled? : Bool = false,
  enabled? : Enabled? = None,
  size? : Double = 13.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(state)
  @core.node_of_new(fn(row : @core.Widget) -> @core.Widget {
    let off = enabled_cell(enabled, disabled)
    let box = @core.Widget::new()
    box.node.set_width(@yoga.fixed(14.0))
    box.node.set_height(@yoga.fixed(14.0))
    box.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      _r : @core.Rect,
    ) -> Unit {
      let checked = state.get()
      let edge = if checked && !off.off {
        @theme.theme_primary()
      } else {
        @theme.theme_border()
      }
      p.set_stroke_color(edge)
      p.set_line_width(1.0)
      p.stroke_rect(0.0, 0.0, 14.0, 14.0)
      if checked {
        p.set_stroke_color(if off.off {
          @theme.theme_text_secondary()
        } else {
          @theme.theme_primary()
        })
        p.move_to(3.0, 7.5)
        p.line_to(6.0, 10.5)
        p.line_to(11.0, 4.0)
        p.stroke()
      }
    })
    row.node.set_flex_direction(@yoga.Row)
    row.node.set_align_items(@yoga.AlignItems::Center)
    row.node.set_column_gap(6.0)
    row.append_child(box)
    let _ = (label(text, size=size)).mount_into(row)
    attach_toggle(row, fn() { state.set(!state.get()) }, off)
    handle(row)
    row
  })
}

///|
/// 单选组：`options` 依次对应值 0..n-1，写回 `state`；点已选中项不改值。
pub fn radio_group(
  options : Array[String],
  state : @core.Store[Int],
  disabled? : Bool = false,
  direction? : @yoga.FlexDirection = @yoga.Row,
  gap? : Double = 12.0,
) -> @core.Node {
  follow_store(state)
  let is_row = match direction {
    @yoga.Row | @yoga.RowReverse => true
    _ => false
  }
  let items : Array[@core.Node] = []
  for i = 0; i < options.length(); i = i + 1 {
    let idx = i
    let dot = @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
      w.node.set_width(@yoga.fixed(14.0))
      w.node.set_height(@yoga.fixed(14.0))
      w.on_draw = Some(fn(
        _self : @core.Widget,
        p : @render.Painter,
        _r : @core.Rect,
      ) -> Unit {
        let picked = state.get() == idx
        p.set_stroke_color(if picked && !disabled {
          @theme.theme_primary()
        } else {
          @theme.theme_border()
        })
        p.set_line_width(1.0)
        p.move_to(13.0, 7.0)
        p.arc(7.0, 7.0, 6.0, 0.0, 6.283185307179586)
        p.stroke()
        if picked {
          p.set_fill_color(if disabled {
            @theme.theme_text_secondary()
          } else {
            @theme.theme_primary()
          })
          p.move_to(10.0, 7.0)
          p.arc(7.0, 7.0, 3.5, 0.0, 6.283185307179586)
          p.fill()
        }
      })
      w
    })
    items.push(
      container(
        [dot, label(options[i])],
        direction=@yoga.Row,
        column_gap=6.0,
        align_items=@yoga.AlignItems::Center,
        handle=fn(w : @core.Widget) -> Unit {
          attach_toggle(w, fn() { state.set(idx) }, Enabled::new(disabled))
        },
      ),
    )
  }
  container(
    items,
    direction=direction,
    row_gap=if is_row { 0.0 } else { gap },
    column_gap=if is_row { gap } else { 0.0 },
  )
}

///|
/// 开关：40×20 胶囊 + 16 圆滑块（胶囊自身按圆角矩形近似，直角先记档），
/// 可带开/关文案。
pub fn switch_t(
  state : @core.Store[Bool],
  on_text? : String = "",
  off_text? : String = "",
  disabled? : Bool = false,
) -> @core.Node {
  follow_store(state)
  @core.node_of_new(fn(row : @core.Widget) -> @core.Widget {
    let off = enabled_cell(None, disabled)
    let pill = @core.Widget::new()
    pill.node.set_width(@yoga.fixed(40.0))
    pill.node.set_height(@yoga.fixed(20.0))
    pill.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let on = state.get()
      p.set_fill_color(if off.off {
        @theme.theme_fill_hover()
      } else if on {
        @theme.theme_primary()
      } else {
        @theme.theme_border()
      })
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_fill_color("#ffffff")
      let kx = if on { r.w - 18.0 } else { 2.0 }
      p.fill_rect(kx, 2.0, 16.0, 16.0)
    })
    row.node.set_flex_direction(@yoga.Row)
    row.node.set_align_items(@yoga.AlignItems::Center)
    row.node.set_column_gap(6.0)
    row.append_child(pill)
    let txt = if state.get() { on_text } else { off_text }
    if txt.length() > 0 {
      let _ = (label(txt)).mount_into(row)
    }
    attach_toggle(row, fn() { state.set(!state.get()) }, off)
    row
  })
}

///|
/// 滑块：按下即取值，拖动跟手（含拖出轨道），`step>0` 按刻度吸附。
pub fn slider(
  state : @core.Store[Double],
  min? : Double = 0.0,
  max? : Double = 100.0,
  step? : Double = 0.0,
  width? : Double = 160.0,
  disabled? : Bool = false,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(state)
  let lo = min
  let hi = if max > min { max } else { min + 1.0 }
  let st = if step > 0.0 { step } else { 0.0 }
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let off = enabled_cell(None, disabled)
    // 拖动状态自己持有：宿主维护的 `pressed` 只在真实事件流里置位，组件要在
    // 任何投递路径下都能把拖动做完（也才测得到）
    let dragging = Ref(false)
    w.node.set_width(@yoga.fixed(width))
    w.node.set_height(@yoga.fixed(@theme.control_height))
    let set_from_x = fn(self : @core.Widget, x : Double) -> Unit {
      let track = (self.rect.w - 12.0).max(1.0)
      let ratio = ((x - 6.0) / track).clamp(min=0.0, max=1.0)
      let raw = lo + ratio * (hi - lo)
      let v = if st > 0.0 { (raw / st).round() * st } else { raw }
      state.set(v.clamp(min=lo, max=hi))
    }
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let track = (r.w - 12.0).max(1.0)
      let ratio = ((state.get() - lo) / (hi - lo)).clamp(min=0.0, max=1.0)
      let cy = r.h / 2.0
      p.set_fill_color(if off.off {
        @theme.theme_fill_hover()
      } else {
        @theme.theme_border()
      })
      p.fill_rect(0.0, cy - 2.0, r.w, 4.0)
      p.set_fill_color(if off.off {
        @theme.theme_text_secondary()
      } else {
        @theme.theme_primary()
      })
      p.fill_rect(0.0, cy - 2.0, 6.0 + track * ratio, 4.0)
      p.fill_rect(2.0 + track * ratio, cy - 6.0, 12.0, 12.0)
    })
    w.on_pointer = Some(fn(
      self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      if off.off {
        return false
      }
      match ev.kind {
        @core.Down => {
          dragging.val = true
          set_from_x(self, ev.x)
          true
        }
        @core.Move => {
          if dragging.val { set_from_x(self, ev.x) }
          true
        }
        @core.Up => {
          dragging.val = false
          false
        }
        @core.Leave => false
      }
    })
    handle(w)
    w
  })
}

///|
/// 进度条：`state` 取 0..max 的实数值（纯展示，不响应点击）。
pub fn progress(
  state : @core.Store[Double],
  max? : Double = 1.0,
  width? : Double = 200.0,
  height? : Double = 6.0,
  color? : String = "",
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(state)
  let hi = if max > 0.0 { max } else { 1.0 }
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_width(@yoga.fixed(width))
    w.node.set_height(@yoga.fixed(height))
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let ratio = (state.get() / hi).clamp(min=0.0, max=1.0)
      p.set_fill_color(@theme.theme_fill_zebra())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_fill_color(if color.length() > 0 {
        color
      } else {
        @theme.theme_primary()
      })
      p.fill_rect(0.0, 0.0, r.w * ratio, r.h)
    })
    handle(w)
    w
  })
}

///|
/// 步进器：`[-] 值 [+]`，按 step 增减并夹在区间内；触边界那一侧自动禁用
/// （禁用态必须跟着值走，见 state.mbt 那条实测）。
pub fn stepper(
  state : @core.Store[Int],
  min? : Int = 0,
  max? : Int = 999,
  step? : Int = 1,
) -> @core.Node {
  let lo = min
  let hi = if max > min { max } else { min }
  let inc = if step > 0 { step } else { 1 }
  let minus_off = Enabled::new(state.get() <= lo)
  let plus_off = Enabled::new(state.get() >= hi)
  let sync = fn() -> Unit {
    let v = state.get()
    minus_off.off = v <= lo
    plus_off.off = v >= hi
  }
  let value = @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    w.node.set_width(@yoga.fixed(44.0))
    w.node.set_height(@yoga.fixed(@theme.control_height))
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_stroke_color(@theme.theme_border())
      p.set_line_width(1.0)
      p.stroke_rect(0.0, 0.0, r.w, r.h)
      let txt = state.get().to_string()
      let tw = match @text.measure(txt, 13.0) {
        Some(m) => m.width.to_double()
        None => 0.0
      }
      let _ = @text.draw_text_at(
        p,
        (r.w - tw) / 2.0,
        7.0,
        txt,
        13.0,
        @theme.theme_text_regular(),
      )
    })
    w
  })
  container(
    [
      button(
        "-",
        on_click=fn() {
          state.set((state.get() - inc).clamp(min=lo, max=hi))
          sync()
        },
        kind=Border,
        min_width=32.0,
        enabled=Some(minus_off),
      ),
      value,
      button(
        "+",
        on_click=fn() {
          state.set((state.get() + inc).clamp(min=lo, max=hi))
          sync()
        },
        kind=Border,
        min_width=32.0,
        enabled=Some(plus_off),
      ),
    ],
    direction=@yoga.Row,
    align_items=@yoga.AlignItems::Center,
  )
}
