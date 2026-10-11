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
pub fn[T] follow_store(s : @core.Store[T]) -> Unit {
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
    row.cursor = @core.CURSOR_HAND
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
    row.cursor = @core.CURSOR_HAND
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
    w.cursor = @core.CURSOR_HAND
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

///|
/// 按钮变体：Solid 主题色实底白字 / Soft 浅底主题色字 / Text 透明底主题色字 /
/// Danger 红底白字。
pub(all) enum ButtonVariant {
  Solid
  Soft
  Text
  Danger
}

///|
/// 按钮配色求解（纯函数）：`color`/`background_color` 传非空即显式覆盖，
/// 且**所有状态一致**（悬停不再变色）；未传按变体 + 悬停走预设。返回
/// `(文字色, 底色)`，底色为空串表示不画底。
pub fn button_skin(
  variant : ButtonVariant,
  lit : Bool,
  color : String,
  background_color : String,
) -> (String, String) {
  let fg = if color.length() > 0 {
    color
  } else {
    match variant {
      Solid | Danger => "#ffffff"
      Soft => if lit { "#ffffff" } else { @theme.theme_primary() }
      Text => @theme.theme_primary()
    }
  }
  let bg = if background_color.length() > 0 {
    background_color
  } else {
    match variant {
      Solid => if lit { @theme.theme_primary_hover() } else { @theme.theme_primary() }
      Soft => if lit { @theme.theme_primary() } else { @theme.theme_primary_light() }
      Text => if lit { @theme.theme_fill_hover() } else { "" }
      Danger => if lit { @theme.theme_danger_hover() } else { @theme.theme_danger() }
    }
  }
  (fg, bg)
}

///|
/// 主题化按钮：变体配色（悬停/按下都收敛在主题内）+ 焦点环。`focus_id` 传
/// 正数才可 Tab 到；焦点环在实底变体上用白色（主题色环在其上不可见）。
pub fn button_t(
  text : String,
  on_click? : () -> Unit = fn() -> Unit { () },
  variant? : ButtonVariant = Soft,
  color? : String = "",
  background_color? : String = "",
  size? : Double = 13.0,
  min_width? : Double = 0.0,
  focus_id? : Int = 0,
  disabled? : Bool = false,
  enabled? : Enabled? = None,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let src = text_source(text, size=size, align=@text.Center)
  let v_id = match variant {
    Solid => 0
    Soft => 1
    Text => 2
    Danger => 3
  }
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let off = enabled_cell(enabled, disabled)
    w.focus_id = focus_id
    w.node.set_height(@yoga.fixed(@theme.control_height))
    if min_width > 0.0 {
      w.node.set_min_width(@yoga.fixed(min_width))
    }
    w.node.set_padding_left(@yoga.fixed(12.0))
    w.node.set_padding_right(@yoga.fixed(12.0))
    w.node.set_flex_shrink(0.0)
    w.cursor = @core.CURSOR_HAND
    attach_text_measure(w, src)
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let (fg0, bg0) = button_skin(
        variant,
        self.hovered || self.pressed,
        color,
        background_color,
      )
      let fg = if off.off { @theme.theme_text_secondary() } else { fg0 }
      let bg = if off.off { @theme.theme_fill_hover() } else { bg0 }
      if bg.length() > 0 {
        p.set_fill_color(bg)
        p.fill_rect(0.0, 0.0, r.w, r.h)
      }
      let _ = @text.draw_box_at(
        p,
        12.0,
        0.0,
        (r.w - 24.0).max(1.0),
        r.h,
        src.text,
        src.font,
        fg,
        align=@text.Center,
        valign=@text.Center,
        wrap=false,
      )
      if self.focused && v_id != 0 && v_id != 3 {
        // 主题色环只在非实底上可见
        p.set_stroke_color(@theme.theme_primary())
        p.set_line_width(1.0)
        p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
      } else if self.focused {
        p.set_stroke_color("#ffffff")
        p.set_line_width(1.0)
        p.stroke_rect(1.5, 1.5, r.w - 3.0, r.h - 3.0)
      }
    })
    w.on_pointer = Some(fn(
      self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Down => !off.off
        @core.Up => {
          let inside = ev.x >= 0.0 && ev.x <= self.rect.w &&
            ev.y >= 0.0 && ev.y <= self.rect.h
          if !off.off && inside { on_click() }
          false
        }
        @core.Move => !off.off
        @core.Leave => false
      }
    })
    handle(w)
    w
  })
}

///|
/// 链接文字：主题色，悬停出下划线，点击回调（按下在抬起时才触发，与按钮同口径）。
pub fn link(
  text : String,
  on_click : () -> Unit,
  size? : Double = 13.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let font = @text.Font::new("", size)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let tw = text_width(text, font)
    w.node.set_width(@yoga.fixed(tw))
    w.node.set_height(@yoga.fixed(@text.line_height_font(font).unwrap_or(18).to_double()))
    w.node.set_flex_shrink(0.0)
    w.cursor = @core.CURSOR_HAND
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let _ = @text.draw_at(p, 0.0, 0.0, text, font, @theme.theme_primary())
      if self.hovered {
        p.set_fill_color(@theme.theme_primary())
        p.fill_rect(0.0, r.h - 1.0, r.w, 1.0)
      }
    })
    w.on_pointer = Some(fn(
      self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        @core.Down => true
        @core.Up => {
          let inside = ev.x >= 0.0 && ev.x <= self.rect.w &&
            ev.y >= 0.0 && ev.y <= self.rect.h
          if inside { on_click() }
          false
        }
        _ => false
      }
    })
    handle(w)
    w
  })
}

///|
/// 表单项：左侧定宽右对齐标签 + 右侧控件；控件下方是错误文案行（`error` 非空
/// 时显示 danger 红字）。行高固定预留，错误出现/消失不引起布局跳动。
pub fn form_item(
  label_text : String,
  control : @core.Node,
  label_width? : Double = 90.0,
  error? : @core.Store[String] = @core.Store::new(""),
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let err_store = error
  container(
    [
      container(
        [
          container(
            [
              label(
                label_text,
                size=13.0,
                color=@theme.theme_text_secondary(),
                align=@text.End,
              ),
            ],
            direction=@yoga.Row,
            width=label_width,
            align_items=@yoga.AlignItems::Center,
            justify_content=@yoga.JustifyContent::FlexEnd,
          ),
          control,
        ],
        direction=@yoga.Row,
        column_gap=12.0,
        align_items=@yoga.AlignItems::Center,
      ),
      container(
        [label_dyn(err_store.signal(), size=12.0, color=@theme.theme_danger(), wrap=false)],
        direction=@yoga.Row,
        height=18.0,
        handle=fn(w : @core.Widget) -> Unit { w.set_margin(0.0, 0.0, label_width + 12.0, 0.0) },
      ),
    ],
    direction=@yoga.Column,
    row_gap=2.0,
    handle=handle,
  )
}

///|
/// 表单：分组标题 + 一组表单项（纵向排布）。
pub fn form(
  title : String,
  items : Array[@core.Node],
  row_gap? : Double = 8.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let nodes : Array[@core.Node] = [label_t(title, role=Section)]
  for it in items {
    nodes.push(it)
  }
  container(nodes, direction=@yoga.Column, row_gap=row_gap, handle=handle)
}

///|
/// 五角星顶点（纯几何，供绘制与测试共用）：`cx`/`cy` 星心，`r_out` 外半径，
/// 内半径取 0.382R（正五角星比例），起点朝上，共 10 点（外内交替）。
pub fn star_points(cx : Double, cy : Double, r_out : Double) -> Array[(Double, Double)] {
  let r_in = r_out * 0.382
  let pts : Array[(Double, Double)] = []
  for k = 0; k < 10; k = k + 1 {
    let rad = if k % 2 == 0 { r_out } else { r_in }
    let ang = (-90.0 + k.to_double() * 36.0) * 3.141592653589793 / 180.0
    pts.push((cx + rad * @math.cos(ang), cy + rad * @math.sin(ang)))
  }
  pts
}

///|
/// 画一颗星（路径 + 上色由调用方决定：亮星填充、暗星描边）。
fn star_path(p : @render.Painter, cx : Double, cy : Double, r_out : Double) -> Unit {
  p.begin_path()
  let pts = star_points(cx, cy, r_out)
  for i = 0; i < pts.length(); i = i + 1 {
    if i == 0 {
      p.move_to(pts[i].0, pts[i].1)
    } else {
      p.line_to(pts[i].0, pts[i].1)
    }
  }
  p.close_path()
}

///|
/// 评分：`max` 颗五角星，选中实心主题色、未选中描边灰；悬停预亮到第 N 颗，
/// 点击写入 `value`（1..max）并回调 `on_change`（外部写值不回调，与本栈其它
/// 组件同口径）。
pub fn rate_t(
  value : @core.Store[Int],
  max? : Int = 5,
  on_change? : (Int) -> Unit = fn(_v : Int) -> Unit { () },
  size? : Double = 22.0,
  gap? : Double = 4.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(value)
  let n = if max > 0 { max } else { 1 }
  let hover_n : Ref[Int] = Ref(0)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_width(@yoga.fixed(size * n.to_double() + gap * (n - 1).to_double()))
    w.node.set_height(@yoga.fixed(size))
    w.node.set_flex_shrink(0.0)
    w.cursor = @core.CURSOR_HAND
    // 第几颗星（1 起，越界夹住）：星星间距的一半算在星内，边缘不空
    w.on_pointer = Some(fn(_self : @core.Widget, ev : @core.PointerEvent) -> Bool {
      let star_at = fn(x : Double) -> Int {
        let idx = ((x + gap / 2.0) / (size + gap)).to_int() + 1
        idx.clamp(min=1, max=n)
      }
      match ev.kind {
        @core.Down => {
          let v = star_at(ev.x)
          value.set(v)
          on_change(v)
          true
        }
        @core.Move => {
          let h = star_at(ev.x)
          if h != hover_n.val {
            hover_n.val = h
            @core.invalidate()
          }
          true
        }
        @core.Leave => {
          hover_n.val = 0
          @core.invalidate()
          false
        }
        @core.Up => false
      }
    })
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      _r : @core.Rect,
    ) -> Unit {
      let cur = value.get()
      for i = 1; i <= n; i = i + 1 {
        let cx = (i - 1).to_double() * (size + gap) + size / 2.0
        let cy = size / 2.0
        // 悬停预亮优先于当前值（离开时 hover_n 归 0）
        let lit = if hover_n.val > 0 { i <= hover_n.val } else { i <= cur }
        if lit {
          p.set_fill_color(@theme.theme_primary())
          star_path(p, cx, cy, size / 2.0 - 1.0)
          p.fill()
        } else {
          p.set_stroke_color(@theme.theme_border())
          p.set_line_width(1.0)
          star_path(p, cx, cy, size / 2.0 - 1.0)
          p.stroke()
        }
      }
    })
    handle(w)
    w
  })
}

///|
/// 下拉候选行（EP 样式）：当前选中浅蓝底 + 主色字 + 右侧 ✓，悬停灰底。
/// 选中在**抬起**时触发（与浮层其它项同：按下被图层消费，抬起才派发）。
fn select_row(opt : String, selected : () -> Bool, on_pick : () -> Unit) -> @core.Node {
  let font = @text.Font::new("", 13.0)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_width(@yoga.percent(100.0))
    w.node.set_height(@yoga.fixed(28.0))
    w.node.set_flex_shrink(0.0)
    w.cursor = @core.CURSOR_HAND
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let act = selected()
      if act {
        p.set_fill_color(@theme.theme_primary_light())
        p.fill_rect(0.0, 0.0, r.w, r.h)
      } else if self.hovered {
        p.set_fill_color(@theme.theme_fill_hover())
        p.fill_rect(0.0, 0.0, r.w, r.h)
      }
      let _ = @text.draw_box_at(
        p,
        8.0,
        0.0,
        (r.w - 26.0).max(1.0),
        r.h,
        opt,
        font,
        if act { @theme.theme_primary() } else { @theme.theme_text_regular() },
        align=@text.Start,
        valign=@text.Center,
      )
      if act {
        // 矢量小勾（不依赖字体字形）
        p.set_stroke_color(@theme.theme_primary())
        p.set_line_width(1.3)
        p.begin_path()
        p.move_to(r.w - 18.0, r.h / 2.0)
        p.line_to(r.w - 14.0, r.h / 2.0 + 4.0)
        p.line_to(r.w - 8.0, r.h / 2.0 - 4.0)
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
          on_pick()
          false
        }
        _ => false
      }
    })
    w
  })
}

///|
/// 候选浮层：`n` 行 × 28 高 + 4×2 内边距，超过 300 高就套一层垂直滚动
/// （选项再多也不会顶出窗口）。`select_t` 与 `combo` 共用。
fn list_popup(rows : Array[@core.Node], n : Int, width : Double) -> @core.Node {
  let want = n.to_double() * 28.0 + 8.0
  let list_h = if want > 300.0 { 300.0 } else { want }
  let st = ScrollState::new()
  overlay_pane([scroll_v(rows, st, width=width, height=list_h)], width, list_h)
}

///|
/// 下拉选择（EP Select，全自绘）：字段点开候选列表（开在浮层图层上），悬停高亮、
/// 当前选中主色 + ✓，点选回填并收起；`clearable` 时字段悬停且有值显示 ✕，
/// 点它清空（`value` 置空串并回调 `on_change("")`，与 master 同）。
/// 列表超过 300 高时内部套一层垂直滚动（选项再多也不会顶出窗口）。
///
/// 与 master 的两条差（记档）：① 弹层是浮层图层上的自绘面板，不是原生 Popover，
/// 「点外面收起」由图层负责，组件不再自己跟踪；② master 靠字段失焦收起，本栈
/// 字段是否可聚焦由调用方给 `focus_id` 决定，收起只走「点外面 / 再点字段」两条路。
pub fn select_t(
  options : Array[String],
  value : @core.Store[String],
  on_change? : (String) -> Unit = fn(_s : String) -> Unit { () },
  clearable? : Bool = false,
  placeholder? : String = "",
  width? : Double = 200.0,
  focus_id? : Int = 0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(value)
  let opts = options
  let ph = placeholder
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let open_id : Ref[Int] = Ref(0)
    w.focus_id = focus_id
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
        let v = value.get()
        if v.length() > 0 { v } else { ph }
      },
      fn() -> Bool { value.get().length() > 0 },
      clearable,
      fn(local_x : Double) -> Unit {
        if clear_hit(local_x, width, clearable, value.get().length() > 0) {
          value.set("")
          on_change("")
          close_pop()
        } else if overlay_alive(open_id.val) {
          close_pop()
        } else {
          let rows : Array[@core.Node] = []
          for i = 0; i < opts.length(); i = i + 1 {
            let opt = opts[i]
            rows.push(
              select_row(opt, fn() -> Bool { value.get() == opt }, fn() -> Unit {
                value.set(opt)
                on_change(opt)
                close_pop()
              }),
            )
          }
          open_id.val = @core.overlay_show_at(
            list_popup(rows, opts.length(), width),
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
/// 取色器（EP ColorPicker 下拉形态）：触发字段（当前色块 + hex + 箭头）点开
/// 预设色板（每行 5 格，选中格主色描边 + 白勾），点色块写入 `value`（`#RRGGBB`）
/// 并收起。字段与弹层同 `select_t`：开在浮层图层上，点外面由图层收起。
pub fn color_picker_t(
  value : @core.Store[String],
  colors? : Array[String] = [
    "#2D68C4", "#2E9E5B", "#D9822B", "#D64550", "#6B7480", "#1E4FA3", "#3F6E9E",
    "#7A9E4E", "#B86E2B", "#9AA0A6", "#E8EAED", "#BDC1C6", "#4E5560", "#2A2F36",
    "#F5F7FA",
  ],
  on_change? : (String) -> Unit = fn(_s : String) -> Unit { () },
  width? : Double = 200.0,
  focus_id? : Int = 0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(value)
  let cs = colors
  let swatch = 26.0
  let cell_gap = 6.0
  let per_row = 5
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let open_id : Ref[Int] = Ref(0)
    w.focus_id = focus_id
    let close_pop = fn() -> Unit {
      if open_id.val != 0 {
        @core.overlay_hide(open_id.val)
        open_id.val = 0
      }
    }

    setup_picker_field(
      w,
      width,
      fn() -> String { value.get() },
      fn() -> Bool { value.get().length() > 0 },
      false,
      fn(_local_x : Double) -> Unit {
        if overlay_alive(open_id.val) {
          close_pop()
        } else {
          let rows : Array[@core.Node] = []
          let mut line : Array[@core.Node] = []
          for i = 0; i < cs.length(); i = i + 1 {
            let c = cs[i]
            line.push(
              color_swatch(c, swatch, cell_gap, fn() -> Bool { value.get() == c }, fn() -> Unit {
                value.set(c)
                on_change(c)
                close_pop()
              }),
            )
            if (i + 1) % per_row == 0 || i + 1 == cs.length() {
              rows.push(
                container(
                  line,
                  direction=@yoga.Row,
                  height=swatch + cell_gap,
                  align_items=@yoga.AlignItems::FlexStart,
                ),
              )
              line = []
            }
          }
          let rows_n = ((cs.length() + per_row - 1) / per_row).to_double()
          open_id.val = @core.overlay_show_at(
            overlay_pane(
              [container(rows, direction=@yoga.Column, row_gap=0.0, padding=8.0)],
              per_row.to_double() * (swatch + cell_gap) + 16.0,
              16.0 + rows_n * (swatch + cell_gap),
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
/// 色板一格：`size` 见方的色块 + 描边，选中时内圈主色 + 白勾。
fn color_swatch(
  c : String,
  size : Double,
  gap : Double,
  selected : () -> Bool,
  on_pick : () -> Unit,
) -> @core.Node {
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_width(@yoga.fixed(size))
    w.node.set_height(@yoga.fixed(size))
    w.node.set_flex_shrink(0.0)
    w.cursor = @core.CURSOR_HAND
    w.set_margin(0.0, 0.0, 0.0, gap)
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(c)
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_stroke_color(@theme.theme_border())
      p.set_line_width(1.0)
      p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
      if selected() {
        p.set_stroke_color(@theme.theme_primary())
        p.stroke_rect(1.5, 1.5, r.w - 3.0, r.h - 3.0)
        p.set_stroke_color("#ffffff")
        p.set_line_width(1.4)
        p.begin_path()
        p.move_to(r.w / 2.0 - 5.0, r.h / 2.0)
        p.line_to(r.w / 2.0 - 1.0, r.h / 2.0 + 4.0)
        p.line_to(r.w / 2.0 + 6.0, r.h / 2.0 - 5.0)
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
          on_pick()
          false
        }
        _ => false
      }
    })
    w
  })
}

///|
/// 可编辑下拉（EP Combobox 形态）：文本框 + 随输入过滤的候选浮层。
/// 打字即过滤并开层，↑/↓ 移动高亮、回车取高亮、Esc 收层，点候选行直接回填；
/// 编辑语义（选区/双击选词/undo/输入法）全在里面的 `entry`，本组件只加「候选」这一层。
///
/// 与 master 的一条差（记档）：旧链路的 combo 是原生可编辑组合框（GTK
/// `ComboBoxEntry`），本栈全自绘——浮层开在浮层图层上，收层同样由图层负责。
pub fn combo(
  options : Array[String],
  value : @core.Store[String],
  on_change? : (String) -> Unit = fn(_s : String) -> Unit { () },
  placeholder? : String = "",
  width? : Double = 200.0,
  focus_id? : Int = 0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(value)
  let opts = options
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let open_id : Ref[Int] = Ref(0)
    let hi : Ref[Int] = Ref(0)
    let shown : Ref[Array[String]] = Ref([])
    let close = fn() -> Unit {
      if open_id.val != 0 {
        @core.overlay_hide(open_id.val)
        open_id.val = 0
      }
    }

    let filtered = fn() -> Array[String] {
      let t = value.get()
      let out : Array[String] = []
      if t.length() == 0 {
        for o in opts {
          out.push(o)
        }
      } else {
        for o in opts {
          if o.contains(t) {
            out.push(o)
          }
        }
      }
      out
    }
    let pick = fn(s : String) -> Unit {
      value.set(s)
      on_change(s)
      close()
    }
    let open = fn() -> Unit {
      let cand = filtered()
      if cand.length() == 0 {
        close()
        return
      }
      if hi.val >= cand.length() {
        hi.val = 0
      }
      let rows : Array[@core.Node] = []
      for i = 0; i < cand.length(); i = i + 1 {
        let idx = i
        let text = cand[i]
        rows.push(
          select_row(text, fn() -> Bool { hi.val == idx }, fn() -> Unit { pick(text) }),
        )
      }
      shown.val = cand
      close()
      open_id.val = @core.overlay_show_at(
        list_popup(rows, cand.length(), width),
        w.rect.x,
        w.rect.y + w.rect.h + 2.0,
      )
    }
    let accept = fn() -> Unit {
      let cand = shown.val
      if cand.length() > 0 {
        pick(cand[hi.val.clamp(min=0, max=cand.length() - 1)])
      }
    }

    let box = entry(
      value,
      placeholder=placeholder,
      width=width,
      focus_id=focus_id,
      on_change=fn(_t : String) -> Unit { open() },
      on_enter=accept,
    )
    let _ = box.mount_into(w)
    w.on_pointer = Some(fn(
      _self : @core.Widget,
      ev : @core.PointerEvent,
    ) -> Bool {
      match ev.kind {
        // 字段里的抬起（选完词、点完插入点）顺手把候选开出来：
        // 输入框自己消费了按下，这一击的抬起才冒泡到这里
        @core.Up => {
          open()
          false
        }
        _ => false
      }
    })
    w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
      if !ev.press || !overlay_alive(open_id.val) {
        return false
      }
      let n = shown.val.length()
      if ev.keysym == @core.KS_ESCAPE {
        close()
        true
      } else if n > 0 && ev.keysym == @core.KS_DOWN {
        hi.val = (hi.val + 1) % n
        @core.invalidate()
        true
      } else if n > 0 && ev.keysym == @core.KS_UP {
        hi.val = (hi.val + n - 1) % n
        @core.invalidate()
        true
      } else {
        false
      }
    })
    handle(w)
    w
  })
}
