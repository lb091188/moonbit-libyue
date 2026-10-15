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
/// 键盘口径：空格/回车切换；未给 `focus_id` 时自动领号进 Tab 链，聚焦时框线转主题色。
pub fn checkbox(
  content : String,
  state : @core.Store[Bool],
  disabled? : Bool = false,
  enabled? : Enabled? = None,
  focus_id? : Int = 0,
  font_size? : Double = 13.0,
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(state)
  @core.node_of_new(fn(row : @core.Widget) -> @core.Widget {
    let off = enabled_cell(enabled, disabled)
    row.focus_id = auto_focus_id(focus_id)
    let box = @core.Widget::new()
    box.node.set_width(@yoga.fixed(14.0))
    box.node.set_height(@yoga.fixed(14.0))
    // 标记的内置基调存 token 名（随主题现取）：强调色=primary，未选框色=border
    @style.apply(
      box,
      @style.merge_all([@style.style(color="primary", border_color="border"), paint_subset(class)]),
    )
    box.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      _r : @core.Rect,
    ) -> Unit {
      let s = @style.style_for(self)
      let accent = @style.color_of(s.color, "")
      let edge = @style.color_of(s.border_color, "")
      let checked = state.get()
      p.set_stroke_color(
        if checked && !off.off {
          accent
        } else if row.focused && !off.off {
          // 聚焦指示与输入框同口径：描边转主题色
          @theme.theme_primary()
        } else {
          edge
        },
      )
      p.set_line_width(1.0)
      // 框线走内描边：按设备格取整，14×14 的框在任意原点都是锐利的 1px
      p.stroke_rect(0.0, 0.0, 14.0, 14.0)
      if checked {
        p.set_stroke_color(if off.off {
          @theme.theme_text_secondary()
        } else {
          accent
        })
        // 勾比框粗：14px 的框里 1px 折线只剩几个像素，看不出是个勾；
        // 两端离框边各留 2px 以上，否则与框线糊在一起。
        p.set_line_width(2.4)
        p.begin_path()
        p.move_to(3.4, 7.4)
        p.line_to(5.9, 9.9)
        p.line_to(10.5, 4.3)
        p.stroke()
      }
    })
    row.node.set_flex_direction(@yoga.Row)
    row.node.set_align_items(@yoga.AlignItems::Center)
    row.node.set_column_gap(6.0)
    // 行高不随字体度量塌陷：文本行盒比 14px 标记矮的字体上标记会撑破行
    //（真机 XFCE 默认字体实测），与 radio 行同一条 min_height 口径
    row.node.set_min_height(@yoga.fixed(20.0))
    row.append_child(box)
    let _ = (text(content, font_size=font_size)).mount_into(row)
    row.cursor_fn = Some(enabled_cursor(off, @core.CURSOR_HAND))
    attach_toggle(row, fn() { state.set(!state.get()) }, off)
    row.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
      if !ev.press || off.off {
        return false
      }
      if ev.keysym == @core.KS_SPACE || ev.keysym == @core.KS_RETURN {
        state.set(!state.get())
        true
      } else {
        false
      }
    })
    fold_style(row, @style.empty_style(), class)
    handle(row)
    row
  })
}

///|
/// 单选组：`options` 依次对应值 0..n-1，写回 `state`；点已选中项不改值。
/// 键盘口径：空格/回车选中本项，←/↑ 上一项、→/↓ 下一项（到头环绕）；
/// 每项各自进 Tab 链（自动领号），聚焦时环转主题色。
pub fn radio_group(
  options : Array[String],
  state : @core.Store[Int],
  disabled? : Bool = false,
  direction? : @yoga.FlexDirection = @yoga.Row,
  gap? : Double = 12.0,
  class? : Array[@style.Style] = [],
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
      // 内置基调存 token 名：选中=primary，未选环=border
      @style.apply(
        w,
        @style.merge_all([@style.style(color="primary", border_color="border"), paint_subset(class)]),
      )
      w.on_draw = Some(fn(
        self : @core.Widget,
        p : @render.Painter,
        _r : @core.Rect,
      ) -> Unit {
        let s = @style.style_for(self)
        let accent = @style.color_of(s.color, "")
        let picked = state.get() == idx
        p.set_stroke_color(if picked && !disabled { accent } else { @style.color_of(s.border_color, "") })
        p.set_line_width(1.3)
        // 环与心都走解析圆（半径=边长一半）：像素按到圆心的距离求覆盖，
        // 展平成折线再描边会在小半径上留下接头缺口
        p.stroke_round_rect(1.0, 1.0, 12.0, 12.0, 6.0)
        if picked {
          p.set_fill_color(if disabled {
            @theme.theme_text_secondary()
          } else {
            accent
          })
          // 心半径 3.0：环的内沿在 5.4，两者之间留得出一条空白，
          // 否则 14px 的标记上环与心糊成一整块实心板
          p.fill_round_rect(4.0, 4.0, 6.0, 6.0, 3.0)
        }
      })
      w
    })
    items.push(
      view(
        [dot, text(options[i])],
        direction=@yoga.Row,
        column_gap=6.0,
        align_items=@yoga.AlignItems::Center,
        class=class,
        handle=fn(w : @core.Widget) -> Unit {
          // 行高不随字体度量塌陷：文本行盒比 14px 标记还矮的字体上（真机
          // XFCE 的默认字体实测如此），标记会把行撑破、圆圈顶被上一行盖住
          w.node.set_min_height(@yoga.fixed(20.0))
          w.focus_id = auto_focus_id(0)
          attach_toggle(w, fn() { state.set(idx) }, Enabled::new(disabled))
          // 聚焦环画在 dot 上（行本身不铺底）：包一层原绘制，末尾补一圈主题色
          if w.kids.length() > 0 {
            let dot_w = w.kids[0]
            let prev = dot_w.on_draw
            dot_w.on_draw = Some(fn(
              self : @core.Widget,
              p : @render.Painter,
              r : @core.Rect,
            ) -> Unit {
              match prev {
                Some(f) => f(self, p, r)
                None => ()
              }
              if w.focused && !disabled {
                p.set_stroke_color(@theme.theme_primary())
                p.set_line_width(1.0)
                p.stroke_round_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0, r.h / 2.0)
              }
            })
          }
          let n = options.length()
          w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
            if !ev.press || disabled {
              return false
            }
            let ks = ev.keysym
            if ks == @core.KS_SPACE || ks == @core.KS_RETURN {
              state.set(idx)
              true
            } else if ks == @core.KS_LEFT || ks == @core.KS_UP {
              state.set((idx + n - 1) % n)
              true
            } else if ks == @core.KS_RIGHT || ks == @core.KS_DOWN {
              state.set((idx + 1) % n)
              true
            } else {
              false
            }
          })
        },
      ),
    )
  }
  view(
    items,
    direction=direction,
    row_gap=if is_row { 0.0 } else { gap },
    column_gap=if is_row { gap } else { 0.0 },
  )
}

///|
/// 开关：40×20 胶囊（圆角半径=半高）+ 16 圆滑珠，可带开/关文案。
/// 键盘口径：空格/回车切换，自动进 Tab 链，聚焦时胶囊描边转主题色。
pub fn switch(
  state : @core.Store[Bool],
  on_text? : String = "",
  off_text? : String = "",
  disabled? : Bool = false,
  focus_id? : Int = 0,
  class? : Array[@style.Style] = [],
) -> @core.Node {
  follow_store(state)
  @core.node_of_new(fn(row : @core.Widget) -> @core.Widget {
    let off = enabled_cell(None, disabled)
    row.focus_id = auto_focus_id(focus_id)
    let pill = @core.Widget::new()
    pill.node.set_width(@yoga.fixed(40.0))
    pill.node.set_height(@yoga.fixed(20.0))
    // 标记控件的基调存 token 名：开态底色=primary，关态=border，滑珠=白
    @style.apply(
      pill,
      @style.merge_all([
        @style.style(color="#ffffff", background_color="primary", border_color="border"),
        paint_subset(class),
      ]),
    )
    pill.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let s = @style.style_for(self)
      let on = state.get()
      // 禁用态底色是组件语义（不随 class），仍走主题浅灰
      let body = if off.off {
        @theme.theme_fill_hover()
      } else if on {
        @style.color_of(s.background_color, "")
      } else {
        @style.color_of(s.border_color, "")
      }
      p.set_fill_color(body)
      p.fill_round_rect(0.0, 0.0, r.w, r.h, r.h / 2.0)
      p.set_fill_color(@style.color_of(s.color, "#ffffff"))
      // 滑珠是圆：圆心离两端各一个半高，半径 8 → 珠沿与胶囊壁齐平
      let cx = if on { r.w - 10.0 } else { 10.0 }
      p.fill_round_rect(cx - 8.0, r.h / 2.0 - 8.0, 16.0, 16.0, 8.0)
      if row.focused {
        p.set_stroke_color(@theme.theme_primary())
        p.set_line_width(1.0)
        p.stroke_round_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0, r.h / 2.0 - 0.5)
      }
    })
    row.node.set_flex_direction(@yoga.Row)
    row.node.set_align_items(@yoga.AlignItems::Center)
    row.node.set_column_gap(6.0)
    row.append_child(pill)
    let txt = if state.get() { on_text } else { off_text }
    if txt.length() > 0 {
      let _ = (text(txt)).mount_into(row)
    }
    row.cursor_fn = Some(enabled_cursor(off, @core.CURSOR_HAND))
    attach_toggle(row, fn() { state.set(!state.get()) }, off)
    row.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
      if !ev.press || off.off {
        return false
      }
      if ev.keysym == @core.KS_SPACE || ev.keysym == @core.KS_RETURN {
        state.set(!state.get())
        true
      } else {
        false
      }
    })
    fold_style(row, @style.empty_style(), class)
    row
  })
}

///|
/// 滑块：按下即取值，拖动跟手（含拖出轨道），`step>0` 按刻度吸附。
/// 键盘口径：←/↓ 减、→/↑ 加（无 step 时按百分之一量程）、Home/End 到两端；
/// 自动进 Tab 链，聚焦时拇指外围一圈主题色。
pub fn slider(
  state : @core.Store[Double],
  min? : Double = 0.0,
  max? : Double = 100.0,
  step? : Double = 0.0,
  width? : Double = 160.0,
  disabled? : Bool = false,
  focus_id? : Int = 0,
  class? : Array[@style.Style] = [],
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
    w.focus_id = auto_focus_id(focus_id)
    w.node.set_width(@yoga.fixed(width))
    w.node.set_height(@yoga.fixed(@theme.control_height))
    w.cursor_fn = Some(enabled_cursor(off, @core.CURSOR_HAND))
    let set_from_x = fn(self : @core.Widget, x : Double) -> Unit {
      let track = (self.rect.w - 12.0).max(1.0)
      let ratio = ((x - 6.0) / track).clamp(min=0.0, max=1.0)
      let raw = lo + ratio * (hi - lo)
      let v = if st > 0.0 { (raw / st).round() * st } else { raw }
      state.set(v.clamp(min=lo, max=hi))
    }
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      // 强调色（已填充段与拇指）=样式 color，轨道底=border_color
      let s = @style.style_for(self)
      let track = (r.w - 12.0).max(1.0)
      let ratio = ((state.get() - lo) / (hi - lo)).clamp(min=0.0, max=1.0)
      let cy = r.h / 2.0
      p.set_fill_color(if off.off {
        @theme.theme_fill_hover()
      } else {
        @style.color_of(s.border_color, @theme.theme_border())
      })
      p.fill_rect(0.0, cy - 2.0, r.w, 4.0)
      p.set_fill_color(if off.off {
        @theme.theme_text_secondary()
      } else {
        @style.color_of(s.color, @theme.theme_primary())
      })
      p.fill_rect(0.0, cy - 2.0, 6.0 + track * ratio, 4.0)
      let tx = 2.0 + track * ratio
      p.fill_rect(tx, cy - 6.0, 12.0, 12.0)
      if self.focused {
        // 拇指聚焦环：整圈画进控件矩形内（绘制按控件矩形裁剪），贴边时夹住
        p.set_stroke_color(@theme.theme_primary())
        p.set_line_width(1.0)
        let x0 = (tx - 2.0).max(0.0)
        let x1 = (tx + 14.0).min(r.w)
        p.stroke_rect(x0, cy - 8.0, (x1 - x0).max(1.0), 16.0)
      }
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
    w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
      if !ev.press || off.off {
        return false
      }
      let dv = if st > 0.0 { st } else { (hi - lo) / 100.0 }
      let ks = ev.keysym
      if ks == @core.KS_LEFT || ks == @core.KS_DOWN {
        state.set((state.get() - dv).clamp(min=lo, max=hi))
        true
      } else if ks == @core.KS_RIGHT || ks == @core.KS_UP {
        state.set((state.get() + dv).clamp(min=lo, max=hi))
        true
      } else if ks == @core.KS_HOME {
        state.set(lo)
        true
      } else if ks == @core.KS_END {
        state.set(hi)
        true
      } else {
        false
      }
    })
    fold_style(w, @style.style(color="primary", border_color="border"), class)
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
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(state)
  let hi = if max > 0.0 { max } else { 1.0 }
  let blocks : Array[@style.Style] = [
    @style.style(background_color="fill_zebra"),
    match fg_block(if color.length() > 0 { color } else { "primary" }) {
      Some(b) => b
      None => @style.empty_style()
    },
  ]
  let anon = @style.merge_all(blocks)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_width(@yoga.fixed(width))
    w.node.set_height(@yoga.fixed(height))
    fold_style(w, anon, class)
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      // 槽底=background_color，进度段=color（散参数 color 折块，class 覆盖同一条路）
      let s = @style.style_for(self)
      let ratio = (state.get() / hi).clamp(min=0.0, max=1.0)
      p.set_fill_color(@style.color_of(s.background_color, @theme.theme_fill_zebra()))
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_fill_color(@style.color_of(s.color, ""))
      p.fill_rect(0.0, 0.0, r.w * ratio, r.h)
    })
    handle(w)
    w
  })
}

///|
/// 步进器的一格 `+` / `-`：**与本体共用同一外框**（外框由行容器按样式槽画），
/// 自己只画悬停/按下底、内容字与靠内侧的那条分隔线。
fn step_cell(
  glyph : String,
  off : Enabled,
  sep_right : Bool,
  on_click : () -> Unit,
  subset : @style.Style,
) -> @core.Node {
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_width(@yoga.fixed(32.0))
    w.node.set_height(@yoga.fixed(@theme.control_height))
    w.cursor = @core.CURSOR_HAND
    fold_style(
      w,
      @style.empty_style().hover(background_color="fill_hover").active(
        background_color="border",
      ),
      [subset],
    )
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let st = @style.style_for(self)
      let bg = @style.color_of(st.background_color, "")
      if bg.length() > 0 && !off.off {
        // 内缩 1px：别把共用外框盖掉
        p.set_fill_color(bg)
        p.fill_rect(1.0, 1.0, r.w - 2.0, r.h - 2.0)
      }
      p.set_stroke_color(@theme.theme_border())
      p.set_line_width(1.0)
      let sx = if sep_right { r.w - 1.0 } else { 0.0 }
      p.begin_path()
      p.move_to(sx, 1.0)
      p.line_to(sx, r.h - 1.0)
      p.stroke()
      let _ = @text.draw_box_at(
        p,
        0.0,
        0.0,
        r.w,
        r.h,
        glyph,
        @text.Font::new("", 13.0),
        if off.off {
          @theme.theme_text_secondary()
        } else {
          @theme.theme_text_regular()
        },
        align=@text.Center,
        valign=@text.Center,
        wrap=false,
      )
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
          if !off.off && inside {
            on_click()
          }
          false
        }
        @core.Move => !off.off
        @core.Leave => false
      }
    })
    w
  })
}

///|
/// 步进器：`[-] 值 [+]` 共框三段（外框由行容器画、格与格之间只有一条分隔线，
/// 三格同高同边——各自画一圈边框会看着像三个没粘在一起的盒子），按 step 增减
/// 并夹在区间内；触边界那一侧自动禁用（禁用态必须跟着值走，见 state.mbt 那条实测）。
/// 键盘口径：←/↓ 减、→/↑ 加（触界侧吃掉键但不改值），自动进 Tab 链，
/// 聚焦时外框描边转主题色。
pub fn stepper(
  state : @core.Store[Int],
  min? : Int = 0,
  max? : Int = 999,
  step? : Int = 1,
  focus_id? : Int = 0,
  class? : Array[@style.Style] = [],
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
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let st = @style.style_for(self)
      let _ = @text.draw_box_at(
        p,
        0.0,
        0.0,
        r.w,
        r.h,
        state.get().to_string(),
        @text.Font::new("", 13.0),
        @style.color_of(st.color, @theme.theme_text_regular()),
        align=@text.Center,
        valign=@text.Center,
        wrap=false,
      )
    })
    w
  })
  let subset = paint_subset(class)
  view(
    [
      step_cell(
        "-",
        minus_off,
        true,
        fn() {
          state.set((state.get() - inc).clamp(min=lo, max=hi))
          sync()
        },
        subset,
      ),
      value,
      step_cell(
        "+",
        plus_off,
        false,
        fn() {
          state.set((state.get() + inc).clamp(min=lo, max=hi))
          sync()
        },
        subset,
      ),
    ],
    direction=@yoga.Row,
    width=108.0,
    height=@theme.control_height,
    align_items=@yoga.AlignItems::Center,
    class=[
      @style.style(
        background_color="bg_panel",
        border_color="border",
        border_width=1.0,
        border_radius=4.0,
      ),
    ] + class,
    handle=fn(w : @core.Widget) -> Unit {
      w.focus_id = auto_focus_id(focus_id)
      // 外框底/描边是 view 的内置绘制：包一层，聚焦时末尾补一圈主题色
      let prev = w.on_draw
      w.on_draw = Some(fn(
        self : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        match prev {
          Some(f) => f(self, p, r)
          None => ()
        }
        if self.focused {
          p.set_stroke_color(@theme.theme_primary())
          p.set_line_width(1.0)
          p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
        }
      })
      w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
        if !ev.press {
          return false
        }
        let ks = ev.keysym
        if ks == @core.KS_LEFT || ks == @core.KS_DOWN {
          if !minus_off.off {
            state.set((state.get() - inc).clamp(min=lo, max=hi))
            sync()
          }
          true
        } else if ks == @core.KS_RIGHT || ks == @core.KS_UP {
          if !plus_off.off {
            state.set((state.get() + inc).clamp(min=lo, max=hi))
            sync()
          }
          true
        } else {
          false
        }
      })
    },
  )
}
///|
/// 按钮变体：Solid 主题色实底白字 / Soft 浅底主题色字 / Text 透明底主题色字 /
/// Danger 红底白字。
pub(all) enum ButtonVariant {
  Solid
  Soft
  Border
  Text
  Danger
}

///|
/// 按钮内置皮肤的 **token 名**表（§1.4：token 名单就是 theme 的颜色字段）：
/// `button` 折进样式槽用的是这份，所以换主题后绘制期现取；`lit` = 点亮态
/// （悬停或按下）。`#ffffff` 是实底上的白字，不是主题字段，原样给。
pub fn button_skin_token(variant : ButtonVariant, lit : Bool) -> (String, String) {
  let fg = match variant {
    Solid | Danger => "#ffffff"
    Soft => if lit { "#ffffff" } else { "primary" }
    Border | Text => "primary"
  }
  let bg = match variant {
    Solid => if lit { "primary_hover" } else { "primary" }
    Soft => if lit { "primary" } else { "primary_light" }
    Border => "bg_panel"
    Text => if lit { "fill_hover" } else { "" }
    Danger => if lit { "danger_hover" } else { "danger" }
  }
  (fg, bg)
}

///|
/// 按钮配色求解（纯函数）：`color`/`background_color` 传非空即显式覆盖，
/// 且**所有状态一致**（悬停不再变色）；未传按变体 + 悬停走预设。返回
/// `(文字色, 底色)`，底色为空串表示不画底。预设取自 [button_skin_token]
/// 再落色，所以与样式槽那条路吃同一张表。
pub fn button_skin(
  variant : ButtonVariant,
  lit : Bool,
  color : String,
  background_color : String,
) -> (String, String) {
  let (tf, tb) = button_skin_token(variant, lit)
  let fg = if color.length() > 0 { color } else { @style.resolve_color(@style.parse_color(tf)) }
  let bg =
    if background_color.length() > 0 {
      background_color
    } else if tb.length() > 0 {
      @style.resolve_color(@style.parse_color(tb))
    } else {
      ""
    }
  (fg, bg)
}

///|
/// 按钮（§2 唯一入口，原 `button` + `button` 合并）：`variant = solid / soft /
/// border / text / danger`，变体配色（悬停/按下都收敛在主题内）+ 焦点环。
/// `focus_id` 传正数才可 Tab 到；焦点环在实底变体上用白色（主题色环在其上不可见）。
/// 边框档（Border）另描 1px `border` 色边，其余档无描边。
pub fn button(
  text : String,
  on_click? : () -> Unit = fn() -> Unit { () },
  variant? : ButtonVariant = Soft,
  color? : String = "",
  background_color? : String = "",
  font_size? : Double = 13.0,
  min_width? : Double = 0.0,
  focus_id? : Int = 0,
  disabled? : Bool = false,
  enabled? : Enabled? = None,
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let src = text_source(text, font_size=font_size, align=@text.Center)
  // 变体皮肤折进样式槽：基块=常态，`hover`/`active` 桶=点亮态（旧口径
  // `lit = hovered || pressed`，两桶同值）；散参数显式覆盖会让两态取到同一色，
  // 「覆盖后悬停不再变色」这条现状由 [button_skin_token] 的取值顺序天然保持。
  // 键盘口径：空格/回车激活；未给 `focus_id` 时自动领号进 Tab 链（焦点环已画）。
  let (fg0, bg0) = button_skin_token(variant, false)
  let (fg1, bg1) = button_skin_token(variant, true)
  let base_fg = if color.length() > 0 { color } else { fg0 }
  let base_bg = if background_color.length() > 0 { background_color } else { bg0 }
  let lit_fg = if color.length() > 0 { color } else { fg1 }
  let lit_bg = if background_color.length() > 0 { background_color } else { bg1 }
  let blocks : Array[@style.Style] = [
    match fg_block(base_fg) {
      Some(b) => b
      None => @style.empty_style()
    },
    match bg_block(base_bg) {
      Some(b) => b
      None => @style.empty_style()
    },
  ]
  let lit_blocks : Array[@style.Style] = [
    match fg_block(lit_fg) {
      Some(b) => b
      None => @style.empty_style()
    },
    match bg_block(lit_bg) {
      Some(b) => b
      None => @style.empty_style()
    },
  ]
  let skin = if variant is Border {
    @style.merge_all(
      blocks + [@style.style(border_color="border", border_width=1.0)],
    )
  } else {
    @style.merge_all(blocks)
  }
  let lit = @style.merge_all(lit_blocks)
  skin.hover = Some(lit)
  skin.active = Some(lit)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let off = enabled_cell(enabled, disabled)
    w.focus_id = auto_focus_id(focus_id)
    w.node.set_height(@yoga.fixed(@theme.control_height))
    if min_width > 0.0 {
      w.node.set_min_width(@yoga.fixed(min_width))
    }
    w.node.set_padding_left(@yoga.fixed(12.0))
    w.node.set_padding_right(@yoga.fixed(12.0))
    w.node.set_flex_shrink(0.0)
    w.cursor_fn = Some(enabled_cursor(off, @core.CURSOR_HAND))
    attach_text_measure(w, src)
    fold_style(w, skin, class)
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let s = @style.style_for(self)
      // 禁用态是组件语义，不走样式：文字转次要色、底色统一浅灰
      let fg = if off.off {
        @theme.theme_text_secondary()
      } else {
        @style.color_of(s.color, "")
      }
      let bg = if off.off { @theme.theme_fill_hover() } else { @style.color_of(s.background_color, "") }
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
      // 描边只看样式给没给（Border 档折了一条 1px `border`，其余档没有）
      let bd = @style.color_of(s.border_color, "")
      if bd.length() > 0 {
        p.set_stroke_color(bd)
        p.set_line_width(@style.number_of(s.border_width, 1.0))
        p.stroke_rect(0.0, 0.0, r.w, r.h)
      }
      if self.focused {
        match variant {
          // 主题色环只在非实底上可见
          Solid | Danger => {
            p.set_stroke_color("#ffffff")
            p.set_line_width(1.0)
            p.stroke_rect(1.0, 1.0, r.w - 2.0, r.h - 2.0)
          }
          _ => {
            p.set_stroke_color(@theme.theme_primary())
            p.set_line_width(1.0)
            p.stroke_rect(0.0, 0.0, r.w, r.h)
          }
        }
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
    w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
      if !ev.press || off.off {
        return false
      }
      if ev.keysym == @core.KS_SPACE || ev.keysym == @core.KS_RETURN {
        on_click()
        true
      } else {
        false
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
  font_size? : Double = 13.0,
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let font = @text.Font::new("", font_size)
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
      let s = @style.style_for(self)
      let hue = @style.color_of(s.color, @theme.theme_primary())
      let _ = @text.draw_at(p, 0.0, 0.0, text, font, hue)
      if self.hovered {
        p.set_fill_color(hue)
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
    fold_style(w, @style.empty_style(), class)
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
  view(
    [
      view(
        [
          view(
            [
              text(
                label_text,
                font_size=13.0,
                color="text_secondary",
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
      view(
        [text_dyn(err_store.signal(), font_size=12.0, color="danger", wrap=false)],
        direction=@yoga.Row,
        height=18.0,
        handle=fn(w : @core.Widget) -> Unit { w.set_margin(left=label_width + 12.0) },
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
  let nodes : Array[@core.Node] = [text(title, role=Section)]
  for it in items {
    nodes.push(it)
  }
  view(nodes, direction=@yoga.Column, row_gap=row_gap, handle=handle)
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
/// 组件同口径）。键盘口径：→/↑ 加一星、←/↓ 减一星、Home/End 到两端，
/// 写值同点击（回调 on_change）；自动进 Tab 链，聚焦时整圈主题色描边。
pub fn rate(
  value : @core.Store[Int],
  max? : Int = 5,
  on_change? : (Int) -> Unit = fn(_v : Int) -> Unit { () },
  size? : Double = 22.0,
  gap? : Double = 4.0,
  focus_id? : Int = 0,
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  follow_store(value)
  let n = if max > 0 { max } else { 1 }
  let hover_n : Ref[Int] = Ref(0)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.focus_id = auto_focus_id(focus_id)
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
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let st = @style.style_for(self)
      let lit_c = @style.color_of(st.color, @theme.theme_primary())
      let dim_c = @style.color_of(st.border_color, @theme.theme_border())
      let cur = value.get()
      for i = 1; i <= n; i = i + 1 {
        let cx = (i - 1).to_double() * (size + gap) + size / 2.0
        let cy = size / 2.0
        // 悬停预亮优先于当前值（离开时 hover_n 归 0）
        let lit = if hover_n.val > 0 { i <= hover_n.val } else { i <= cur }
        if lit {
          p.set_fill_color(lit_c)
          star_path(p, cx, cy, size / 2.0 - 1.0)
          p.fill()
        } else {
          p.set_stroke_color(dim_c)
          p.set_line_width(1.0)
          star_path(p, cx, cy, size / 2.0 - 1.0)
          p.stroke()
        }
      }
      if self.focused {
        p.set_stroke_color(@theme.theme_primary())
        p.set_line_width(1.0)
        p.stroke_rect(0.5, 0.5, r.w - 1.0, r.h - 1.0)
      }
    })
    w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
      if !ev.press {
        return false
      }
      let cur = value.get()
      let setv = fn(v : Int) -> Bool {
        value.set(v)
        on_change(v)
        true
      }
      let ks = ev.keysym
      if ks == @core.KS_RIGHT || ks == @core.KS_UP {
        setv((cur + 1).clamp(min=1, max=n))
      } else if ks == @core.KS_LEFT || ks == @core.KS_DOWN {
        setv((cur - 1).clamp(min=1, max=n))
      } else if ks == @core.KS_HOME {
        setv(1)
      } else if ks == @core.KS_END {
        setv(n)
      } else {
        false
      }
    })
    fold_style(w, @style.style(color="primary", border_color="border"), class)
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
    // 内置基调：常态文字 text_regular，悬停底 fill_hover（选中态见下方注释）
    @style.apply(
      w,
      @style.style(color="text_regular").hover(background_color="fill_hover"),
    )
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let st = @style.style_for(self)
      let act = selected()
      if act {
        p.set_fill_color(@theme.theme_primary_light())
        p.fill_rect(0.0, 0.0, r.w, r.h)
      } else if st.background_color is Some(_) {
        // 悬停底色来自 hover 桶（样式没给就不画底）
        p.set_fill_color(@style.color_of(st.background_color, ""))
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
        if act { @theme.theme_primary() } else { @style.color_of(st.color, @theme.theme_text_regular()) },
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
  overlay_pane([scroll_view(rows, st, width=width, height=list_h)], width, list_h)
}

///|
/// 下拉选择（EP Select，全自绘）：字段点开候选列表（开在浮层图层上），悬停高亮、
/// 当前选中主色 + ✓，点选回填并收起；`clearable` 时字段悬停且有值显示 ✕，
/// 点它清空（`value` 置空串并回调 `on_change("")`，与 master 同）。
/// 列表超过 300 高时内部套一层垂直滚动（选项再多也不会顶出窗口）。
///
/// 与 master 的两条差（记档）：① 弹层是浮层图层上的自绘面板，不是原生 Popover，
/// 「点外面收起」由图层负责，组件不再自己跟踪；② master 靠字段失焦收起，本栈
/// 收起走「点外面 / 再点字段 / Esc」三条路。键盘口径：空格/回车/↓ 开层，
/// ↑/↓ 移高亮、回车/空格取高亮、Esc 收层（字段自动进 Tab 链，聚焦时描边转
/// 主题色，见 `setup_picker_field`）。
pub fn select(
  options : Array[String],
  value : @core.Store[String],
  on_change? : (String) -> Unit = fn(_s : String) -> Unit { () },
  clearable? : Bool = false,
  placeholder? : String = "",
  width? : Double = 200.0,
  focus_id? : Int = 0,
  editable? : Bool = false,
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  if editable {
    // §2 合并:`combo`(可输入)就是 select 的 editable 档,原实现整体复用
    // (labelled 参数没有透传通道,combo_impl 收显式 Option 形参)
    return combo_impl(
      options,
      value,
      on_change=Some(on_change),
      placeholder=Some(placeholder),
      width=Some(width),
      focus_id=Some(focus_id),
      handle=Some(handle),
    )
  }
  follow_store(value)
  let opts = options
  let ph = placeholder
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let open_id : Ref[Int] = Ref(0)
    let hi : Ref[Int] = Ref(0)
    let shown : Ref[Array[String]] = Ref([])
    w.focus_id = auto_focus_id(focus_id)
    let close_pop = fn() -> Unit {
      if open_id.val != 0 {
        @core.overlay_hide(open_id.val)
        open_id.val = 0
      }
    }
    let open_pop = fn() -> Unit {
      // 高亮先对到当前值所在行
      let cur = value.get()
      hi.val = 0
      for i = 0; i < opts.length(); i = i + 1 {
        if opts[i] == cur {
          hi.val = i
        }
      }
      shown.val = opts
      let rows : Array[@core.Node] = []
      for i = 0; i < opts.length(); i = i + 1 {
        let opt = opts[i]
        rows.push(
          select_row(
            opt,
            // 选中✓跟当前值走；高亮行（浅底）跟 hi 走，两者共用同一视觉
            fn() -> Bool {
              value.get() == opt ||
              (hi.val < shown.val.length() && shown.val[hi.val] == opt)
            },
            fn() -> Unit {
              value.set(opt)
              on_change(opt)
              close_pop()
            },
          ),
        )
      }
      open_id.val = @core.overlay_show_at(
        list_popup(rows, opts.length(), width),
        w.rect.x,
        w.rect.y + w.rect.h + 2.0,
      )
    }
    let pick_hi = fn() -> Unit {
      let n = shown.val.length()
      if n > 0 {
        let opt = shown.val[hi.val.clamp(min=0, max=n - 1)]
        value.set(opt)
        on_change(opt)
        close_pop()
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
          open_pop()
        }
      },
    )
    w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
      if !ev.press {
        return false
      }
      let ks = ev.keysym
      if overlay_alive(open_id.val) {
        let n = shown.val.length()
        if ks == @core.KS_RETURN || ks == @core.KS_SPACE {
          pick_hi()
          true
        } else if ks == @core.KS_ESCAPE {
          close_pop()
          true
        } else if n > 0 && ks == @core.KS_DOWN {
          hi.val = (hi.val + 1) % n
          @core.invalidate()
          true
        } else if n > 0 && ks == @core.KS_UP {
          hi.val = (hi.val + n - 1) % n
          @core.invalidate()
          true
        } else {
          false
        }
      } else if ks == @core.KS_RETURN ||
        ks == @core.KS_SPACE ||
        ks == @core.KS_DOWN {
        open_pop()
        true
      } else {
        false
      }
    })
    fold_style(w, @style.empty_style(), class)
    handle(w)
    w
  })
}

///|
/// 取色器（EP ColorPicker 下拉形态）：触发字段（当前色块 + hex + 箭头）点开
/// 预设色板（每行 5 格，选中格主色描边 + 白勾），点色块写入 `value`（`#RRGGBB`）
/// 并收起。字段与弹层同 `select_t`：开在浮层图层上，点外面由图层收起。
/// 键盘口径：空格/回车/↓ 开层，←/→ 移一格、↑/↓ 移一行（夹在色板范围内），
/// 回车/空格取色、Esc 收层。
pub fn color_picker(
  value : @core.Store[String],
  colors? : Array[String] = [
    "#2D68C4", "#2E9E5B", "#D9822B", "#D64550", "#6B7480", "#1E4FA3", "#3F6E9E",
    "#7A9E4E", "#B86E2B", "#9AA0A6", "#E8EAED", "#BDC1C6", "#4E5560", "#2A2F36",
    "#F5F7FA",
  ],
  on_change? : (String) -> Unit = fn(_s : String) -> Unit { () },
  width? : Double = 200.0,
  focus_id? : Int = 0,
  class? : Array[@style.Style] = [],
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
    let hi : Ref[Int] = Ref(0)
    w.focus_id = auto_focus_id(focus_id)
    let close_pop = fn() -> Unit {
      if open_id.val != 0 {
        @core.overlay_hide(open_id.val)
        open_id.val = 0
      }
    }
    let open_pop = fn() -> Unit {
      // 高亮先对到当前色所在格
      let cur = value.get()
      hi.val = 0
      for i = 0; i < cs.length(); i = i + 1 {
        if cs[i] == cur {
          hi.val = i
        }
      }
      let rows : Array[@core.Node] = []
      let mut line : Array[@core.Node] = []
      for i = 0; i < cs.length(); i = i + 1 {
        let c = cs[i]
        line.push(
          color_swatch(
            c,
            swatch,
            cell_gap,
            fn() -> Bool {
              value.get() == c || (hi.val < cs.length() && cs[hi.val] == c)
            },
            fn() -> Unit {
              value.set(c)
              on_change(c)
              close_pop()
            },
          ),
        )
        if (i + 1) % per_row == 0 || i + 1 == cs.length() {
          rows.push(
            view(
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
          [view(rows, direction=@yoga.Column, row_gap=0.0, padding=8.0)],
          per_row.to_double() * (swatch + cell_gap) + 16.0,
          16.0 + rows_n * (swatch + cell_gap),
        ),
        w.rect.x,
        w.rect.y + w.rect.h + 2.0,
      )
    }
    let pick_hi = fn() -> Unit {
      if cs.length() > 0 {
        let c = cs[hi.val.clamp(min=0, max=cs.length() - 1)]
        value.set(c)
        on_change(c)
        close_pop()
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
          open_pop()
        }
      },
    )
    w.on_key = Some(fn(ev : @core.KeyEvent) -> Bool {
      if !ev.press {
        return false
      }
      let ks = ev.keysym
      if overlay_alive(open_id.val) {
        let n = cs.length()
        if ks == @core.KS_RETURN || ks == @core.KS_SPACE {
          pick_hi()
          true
        } else if ks == @core.KS_ESCAPE {
          close_pop()
          true
        } else if n > 0 && ks == @core.KS_LEFT {
          hi.val = (hi.val - 1).clamp(min=0, max=n - 1)
          @core.invalidate()
          true
        } else if n > 0 && ks == @core.KS_RIGHT {
          hi.val = (hi.val + 1).clamp(min=0, max=n - 1)
          @core.invalidate()
          true
        } else if n > 0 && ks == @core.KS_UP {
          hi.val = (hi.val - per_row).clamp(min=0, max=n - 1)
          @core.invalidate()
          true
        } else if n > 0 && ks == @core.KS_DOWN {
          hi.val = (hi.val + per_row).clamp(min=0, max=n - 1)
          @core.invalidate()
          true
        } else {
          false
        }
      } else if ks == @core.KS_RETURN ||
        ks == @core.KS_SPACE ||
        ks == @core.KS_DOWN {
        open_pop()
        true
      } else {
        false
      }
    })
    fold_style(w, @style.empty_style(), class)
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
    w.set_margin(right=gap)
    // 格子的色是数据不是样式，但仍走同一条槽：折成 background_color 供绘制期读
    @style.apply(w, @style.style(background_color=c))
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let st = @style.style_for(self)
      p.set_fill_color(@style.color_of(st.background_color, c))
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_stroke_color(@style.color_of(st.border_color, @theme.theme_border()))
      p.set_line_width(1.0)
      p.stroke_rect(0.0, 0.0, r.w, r.h)
      if selected() {
        p.set_stroke_color(@theme.theme_primary())
        p.stroke_rect(1.0, 1.0, r.w - 2.0, r.h - 2.0)
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
/// 编辑语义（选区/双击选词/undo/输入法）全在里面的 `input`，本组件只加「候选」这一层。
///
/// 与 master 的一条差（记档）：旧链路的 combo 是原生可编辑组合框（GTK
/// `ComboBoxEntry`），本栈全自绘——浮层开在浮层图层上，收层同样由图层负责。
fn combo_impl(
  options : Array[String],
  value : @core.Store[String],
  on_change~ : Option[(String) -> Unit],
  placeholder~ : Option[String],
  width~ : Option[Double],
  focus_id~ : Option[Int],
  handle~ : Option[(@core.Widget) -> Unit],
) -> @core.Node {
  let on_change = on_change.unwrap_or(fn(_s : String) -> Unit { () })
  let placeholder = placeholder.unwrap_or("")
  let width = width.unwrap_or(200.0)
  let focus_id = focus_id.unwrap_or(0)
  let handle = handle.unwrap_or(default_handle)
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

    let box = input(
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
