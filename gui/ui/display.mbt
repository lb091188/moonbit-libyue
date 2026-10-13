// 显示族组件：标签 / 徽标 / 头像 / 统计 / 提示条 / 卡片 / 描述列表 / 结果页 /
// 空状态 / 分隔线（带文字）/ 折线进度。
//
// 与 master 的差一条（记档）：CSS 风格的 `style=[("marginRight", 8.0)]` 通道
// 还没接（随主题批的 style 通道一起做），这里只留**类型化**参数；语义色
// `SemanticType` 保留同名枚举，色值现取主题（primary/success/warning/danger/info
// 与各自 light 档在 `theme` 已就位）。

///|
/// 语义类型（与 EP 的 type 同档）。
pub(all) enum SemanticType {
  Primary
  Success
  Warning
  Danger
  Info
}

///|
/// 语义主色（实底/文字用）。
pub fn type_color(t : SemanticType) -> String {
  match t {
    Primary => @theme.theme_primary()
    Success => @theme.theme_success()
    Warning => @theme.theme_warning()
    Danger => @theme.theme_danger()
    Info => @theme.theme_info()
  }
}

///|
/// 语义浅色（底色用）。
pub fn type_light_color(t : SemanticType) -> String {
  match t {
    Primary => @theme.theme_primary_light()
    Success => @theme.theme_success_light()
    Warning => @theme.theme_warning_light()
    Danger => @theme.theme_danger_light()
    Info => @theme.theme_info_light()
  }
}

///|
/// 一行文本的测量宽（组件按内容定宽时用，绕开容器拉伸）。
pub fn text_width(text : String, font : @text.Font) -> Double {
  match @text.measure_font(text, font) {
    Some(m) => m.width.to_double()
    None => 0.0
  }
}

///|
/// 定宽定高的色块标签：`width` 传 0 表示按文本测量。
fn chip(
  text : String,
  fg : String,
  bg : String,
  height : Double,
  size : Double,
  h_pad : Double,
  width : Double,
  on_click : () -> Unit,
  clickable : Bool,
) -> @core.Node {
  let font = @text.Font::new("", size)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let tw = text_width(text, font)
    let box_w = if width > 0.0 { width } else { tw + h_pad * 2.0 }
    w.node.set_width(@yoga.fixed(box_w))
    w.node.set_height(@yoga.fixed(height))
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(bg)
      p.fill_rect(0.0, 0.0, r.w, r.h)
      let _ = @text.draw_at(p, (r.w - tw) / 2.0, ((r.h - font.size * 1.5) / 2.0).max(0.0), text, font, fg)
    })
    if clickable {
      w.on_pointer = Some(fn(
        self : @core.Widget,
        ev : @core.PointerEvent,
      ) -> Bool {
        match ev.kind {
          @core.Down => true
          @core.Up => {
            let inside_x = ev.x >= 0.0 && ev.x <= self.rect.w
            let inside_y = ev.y >= 0.0 && ev.y <= self.rect.h
            if inside_x && inside_y { on_click() }
            false
          }
          _ => false
        }
      })
    }
    w
  })
}

///|
/// 语义色标签（浅底 + 主色字）。
pub fn tag_of_type(text : String, t : SemanticType, size? : Double = 12.0) -> @core.Node {
  chip(text, type_color(t), type_light_color(t), 24.0, size, 8.0, 0.0, fn() { () }, false)
}

///|
/// 自定色标签（实底 + 白字）。
pub fn tag(text : String, color : String, size? : Double = 12.0) -> @core.Node {
  chip(text, "#ffffff", color, 24.0, size, 8.0, 0.0, fn() { () }, false)
}

///|
/// 数字徽标：超过 `max` 显示「max+」。
pub fn badge_count(value : Int, max? : Int = 99, color? : String = "") -> @core.Node {
  let txt = if value > max { max.to_string() + "+" } else { value.to_string() }
  chip(txt, "#ffffff", if color.length() > 0 {
    color
  } else {
    @theme.theme_danger()
  }, 18.0, 11.0, 5.0, 0.0, fn() { () }, false)
}

///|
/// 圆点徽标（无数字，只提示「有新东西」）。
pub fn badge_dot(size? : Double = 8.0, color? : String = "") -> @core.Node {
  let d = size
  let c = if color.length() > 0 { color } else { @theme.theme_danger() }
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_width(@yoga.fixed(d))
    w.node.set_height(@yoga.fixed(d))
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(c)
      p.fill_rect(0.0, 0.0, r.w, r.h)
    })
    w
  })
}

///|
/// 头像：取文本首字符居中（无图时的占位形态）。
pub fn avatar(text : String, size? : Double = 32.0, bg? : String = "") -> @core.Node {
  let d = size
  let font = @text.Font::new("", size * 0.45)
  let head = text.to_array()
  let one = if head.length() > 0 { head[0].to_string() } else { "?" }
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_width(@yoga.fixed(d))
    w.node.set_height(@yoga.fixed(d))
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(if bg.length() > 0 { bg } else { @theme.theme_info_light() })
      p.fill_rect(0.0, 0.0, r.w, r.h)
      let tw = text_width(one, font)
      let th = @text.line_height_font(font).unwrap_or(14).to_double()
      let _ = @text.draw_at(
        p,
        (r.w - tw) / 2.0,
        (r.h - th) / 2.0,
        one,
        font,
        @theme.theme_text_regular(),
      )
    })
    w
  })
}

///|
/// 统计数字：小标题在上，数值在下（数值可带前后缀）。
pub fn statistic(
  title : String,
  value : String,
  precision_color? : String = "",
  prefix? : String = "",
) -> @core.Node {
  let vfont = @text.Font::new("", 22.0)
  let tfont = @text.Font::new("", 12.0)
  let line = prefix + value
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    // 宽度在挂载时按测量算定（绘制回调里改布局会把 paint 变成布局的写入方）
    let vw = text_width(line, vfont)
    let tw2 = text_width(title, tfont)
    w.node.set_width(@yoga.fixed((vw + 4.0).max(tw2 + 4.0)))
    w.node.set_height(@yoga.fixed(56.0))
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      _r : @core.Rect,
    ) -> Unit {
      let _ = @text.draw_at(p, 0.0, 2.0, title, tfont, @theme.theme_text_secondary())
      let _ = @text.draw_at(
        p,
        0.0,
        22.0,
        line,
        vfont,
        if precision_color.length() > 0 { precision_color } else { @theme.theme_text_primary() },
      )
    })
    w
  })
}

///|
/// 带文字的居中分隔线。
pub fn divider(text? : String = "") -> @core.Node {
  if text.length() == 0 {
    separator()
  } else {
    let font = @text.Font::new("", 12.0)
    @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
      watch_theme()
      w.node.set_height(@yoga.fixed(20.0))
      w.node.set_width(@yoga.percent(100.0))
      w.on_draw = Some(fn(
        _self : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        let tw = text_width(text, font)
        let cy = r.h / 2.0
        let gap = 8.0
        p.set_fill_color(@theme.theme_border())
        p.fill_rect(0.0, cy, ((r.w - tw) / 2.0 - gap).max(0.0), 1.0)
        let right_x = (r.w + tw) / 2.0 + gap
        p.fill_rect(right_x, cy, (r.w - right_x).max(0.0), 1.0)
        let th = @text.line_height_font(font).unwrap_or(16).to_double()
        let _ = @text.draw_at(
          p,
          (r.w - tw) / 2.0,
          cy - th / 2.0,
          text,
          font,
          @theme.theme_text_secondary(),
        )
      })
      w
    })
  }
}

///|
/// 提示条：语义色浅底 + 主色标题与描述。
pub fn alert(
  title : String,
  description? : String = "",
  t? : SemanticType = Info,
  closable? : Bool = false,
  on_close? : () -> Unit = fn() { () },
) -> @core.Node {
  let tf = @text.Font::new("", 13.0, weight=@text.SemiBold)
  let df = @text.Font::new("", 12.0)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_height(@yoga.fixed(if description.length() > 0 { 56.0 } else { 36.0 }))
    w.node.set_width(@yoga.percent(100.0))
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      p.set_fill_color(type_light_color(t))
      p.fill_rect(0.0, 0.0, r.w, r.h)
      p.set_fill_color(type_color(t))
      p.fill_rect(0.0, 0.0, 3.0, r.h)
      let _ = @text.draw_at(p, 12.0, 6.0, title, tf, type_color(t))
      if description.length() > 0 {
        let _ = @text.draw_at(p, 12.0, 28.0, description, df, @theme.theme_text_regular())
      }
    })
    if closable {
      w.on_pointer = Some(fn(
        self : @core.Widget,
        ev : @core.PointerEvent,
      ) -> Bool {
        match ev.kind {
          @core.Down => true
          @core.Up => {
            // 关闭热区在右上角 24×24
            if ev.x >= self.rect.w - 24.0 && ev.y <= 24.0 { on_close() }
            false
          }
          _ => false
        }
      })
    }
    w
  })
}

///|
/// 卡片：可选标题栏 + 内容区，面板底 + 描边。
pub fn card(
  children : Array[@core.Node],
  title? : String = "",
  padding? : Double = 12.0,
  row_gap? : Double = 6.0,
) -> @core.Node {
  let body : Array[@core.Node] = []
  if title.length() > 0 {
    body.push(
      label(title, size=14.0, weight=@text.SemiBold, color=@theme.theme_text_primary()),
    )
    body.push(separator())
  }
  for c in children {
    body.push(c)
  }
  view(
    body,
    padding=padding,
    row_gap=row_gap,
    bg=@theme.theme_bg_panel(),
    border=@theme.theme_border(),
  )
}

///|
/// 描述列表：`items` 是 (标签, 值) 对，逐行排布。
pub fn descriptions(
  items : Array[(String, String)],
  title? : String = "",
  label_width? : Double = 96.0,
) -> @core.Node {
  let rows : Array[@core.Node] = []
  if title.length() > 0 {
    rows.push(label(title, size=14.0, weight=@text.SemiBold))
  }
  for kv in items {
    rows.push(
      view(
        [
          label(kv.0, size=12.0, color=@theme.theme_text_secondary()),
          label(
            kv.1,
            size=12.0,
            handle=fn(w : @core.Widget) -> Unit {
              w.node.set_min_width(@yoga.fixed(label_width))
            },
          ),
        ],
        direction=@yoga.Row,
        column_gap=8.0,
      ),
    )
  }
  view(rows, row_gap=4.0)
}

///|
/// 空状态：图标 + 描述，居中。
pub fn empty(description? : String = "暂无数据") -> @core.Node {
  view(
    [
      icon(@icons.IconKind::Box, size=42.0, color=@theme.theme_border()),
      label(description, size=12.0, color=@theme.theme_text_secondary(), align=@text.Center),
    ],
    padding=16.0,
    row_gap=8.0,
    align_items=@yoga.AlignItems::Center,
  )
}

///|
/// 结果页：语义图标 + 标题 + 副标题。
pub fn result(title : String, subtitle? : String = "", t? : SemanticType = Success) -> @core.Node {
  let kind = match t {
    Success => @icons.IconKind::Finished
    Danger => @icons.IconKind::CircleClose
    Warning => @icons.IconKind::Warning
    Info => @icons.IconKind::Info
    Primary => @icons.IconKind::Check
  }
  view(
    [
      icon(kind, size=40.0, color=type_color(t)),
      label(title, size=16.0, weight=@text.SemiBold, align=@text.Center),
      label(
        subtitle,
        size=12.0,
        color=@theme.theme_text_secondary(),
        align=@text.Center,
      ),
    ],
    padding=16.0,
    row_gap=6.0,
    align_items=@yoga.AlignItems::Center,
  )
}

///|
/// 折线进度（带百分比文字）：`state` 取 0..max。
pub fn progress_line(
  state : @core.Store[Double],
  max? : Double = 1.0,
  width? : Double = 200.0,
  label_side? : Bool = true,
) -> @core.Node {
  follow_store(state)
  let hi = if max > 0.0 { max } else { 1.0 }
  let bar = progress(state, max=hi, width=(width - 44.0).max(20.0), height=8.0)
  if label_side {
    let pct = @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
      watch_theme()
      // 百分比列要按字高占位，否则 11px 的字被 8px 的条高裁掉
      w.node.set_width(@yoga.fixed(40.0))
      w.node.set_height(@yoga.fixed(16.0))
      let font = @text.Font::new("", 11.0)
      w.on_draw = Some(fn(
        _self : @core.Widget,
        p : @render.Painter,
        _r : @core.Rect,
      ) -> Unit {
        let ratio = (state.get() / hi).clamp(min=0.0, max=1.0)
        let txt = (ratio * 100.0).round().to_int().to_string() + "%"
        let _ = @text.draw_at(p, 0.0, 0.0, txt, font, @theme.theme_text_regular())
      })
      w
    })
    view([bar, pct], direction=@yoga.Row, column_gap=4.0, align_items=@yoga.AlignItems::Center)
  } else {
    view([bar], align_items=@yoga.AlignItems::Center)
  }
}

///|
/// 时间线一行：左列 20px 画色点与贯通竖线，右列标题 + 描述。
fn timeline_row(
  title : String,
  desc : String,
  t : SemanticType,
  first : Bool,
  last : Bool,
  height : Double,
) -> @core.Node {
  let mark = @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    w.node.set_width(@yoga.fixed(20.0))
    w.node.set_height(@yoga.fixed(height))
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let cy = r.h / 2.0
      // 首行从点心起、末行到点心止，中间行整条贯通（点块在行高中间）
      let top = if first { cy } else { 0.0 }
      let bottom = if last { cy } else { r.h }
      if bottom > top {
        p.set_fill_color(@theme.theme_border())
        p.fill_rect(9.0, top, 2.0, bottom - top)
      }
      p.set_fill_color(type_color(t))
      p.fill_rect(5.0, cy - 5.0, 10.0, 10.0)
    })
    w
  })
  view(
    [
      mark,
      view(
        [
          label(title, size=13.0, weight=@text.SemiBold, color=@theme.theme_text_primary()),
          label(desc, size=12.0, color=@theme.theme_text_secondary()),
        ],
        grow=1.0,
        handle=fn(w : @core.Widget) -> Unit { w.set_padding(top=2.0, left=8.0) },
      ),
    ],
    direction=@yoga.Row,
    height=height,
  )
}

///|
/// 时间线（EP Timeline）：`items` 是 (标题, 描述, 语义色)，逐行等高排布。
pub fn timeline(
  items : Array[(String, String, SemanticType)],
  item_height? : Double = 56.0,
  gap? : Double = 12.0,
) -> @core.Node {
  let rows : Array[@core.Node] = []
  let n = items.length()
  for i = 0; i < n; i = i + 1 {
    let entry = items[i]
    rows.push(
      timeline_row(entry.0, entry.1, entry.2, i == 0, i == n - 1, item_height),
    )
  }
  view(rows, row_gap=gap)
}

///|
/// 轮播句柄：自动轮播开关、待触发的延时句柄、当前页、悬停暂停标志与切换入口。
/// `carousel_t` 挂载后会把 `switch` 接到真实切页函数，句柄因此可以在挂载前后
/// 同一份用（调用方拿着它随时切页/停转，不必再找控件）。
pub(all) struct CarouselHandle {
  running : Ref[Bool]
  timer : Ref[Int]
  cur : Ref[Int]
  paused : Ref[Bool]
  switch : Ref[(Int) -> Unit]
}

///|
/// 建轮播句柄（默认自动轮播中、停在第 0 页）。
pub fn CarouselHandle::make() -> CarouselHandle {
  {
    running: Ref(true),
    timer: Ref(0),
    cur: Ref(0),
    paused: Ref(false),
    switch: Ref(fn(_i) { () }),
  }
}

///|
/// 是否还在自动轮播（手动切页与指示点不受这个开关影响）。
pub fn CarouselHandle::is_running(self : CarouselHandle) -> Bool {
  self.running.val
}

///|
/// 当前页下标。
pub fn CarouselHandle::index(self : CarouselHandle) -> Int {
  self.cur.val
}

///|
/// 切到第 `i` 页（越界回绕；挂载前的调用是空操作）。
pub fn carousel_goto(handle : CarouselHandle, i : Int) -> Unit {
  (handle.switch.val)(i)
}

///|
/// 手动暂停/恢复自动轮播。页面内容自己吃掉了全部指针事件（连移动与离开都不冒泡
/// 上来）时用这个自己控制，组件默认的悬停暂停见 `carousel_t`。
pub fn carousel_pause(handle : CarouselHandle, v : Bool) -> Unit {
  handle.paused.val = v
}

///|
/// 停止自动轮播（不可恢复；手动切页仍可用）。卸载轮播前必须调：自排的延时链
/// 不认识视图已移除，不退就会继续对销毁掉的子树空转。
pub fn carousel_stop(handle : CarouselHandle) -> Unit {
  handle.running.val = false
  @core.clear_timeout(handle.timer.val)
  handle.timer.val = 0
}

///|
/// 轮播（EP Carousel）：面板序列 + 左右箭头 + 底部指示点。
/// `interval_ms > 0` 且页数大于 1 时自动轮播（每 `interval_ms` 毫秒前进一页，
/// 指针停在轮播上暂停、离开恢复）；面板全部预建，切页只翻显隐。
pub fn carousel_t(
  pages : Array[@core.Node],
  width? : Double = 360.0,
  height? : Double = 180.0,
  interval_ms? : Int = 3000,
  rotation? : CarouselHandle = CarouselHandle::make(),
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let n = pages.length()
  let cur = rotation.cur
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_flex_direction(@yoga.Column)
    w.node.set_width(@yoga.fixed(width))
    w.node.set_height(@yoga.fixed(height + 24.0))
    if n > 0 {
      let panels : Array[@core.Widget] = []
      // 切页：越界回绕；面板只显示当前页（预建 + 显隐，不销毁子树）
      fn do_switch(i : Int) -> Unit {
        let idx = if i < 0 { n - 1 } else if i >= n { 0 } else { i }
        if idx != cur.val {
          panels[cur.val].set_visible(false)
          panels[idx].set_visible(true)
          cur.val = idx
          @core.invalidate()
        }
      }

      rotation.switch.val = fn(i : Int) -> Unit { do_switch(i) }
      let stage = @core.Widget::new()
      stage.node.set_flex_direction(@yoga.Column)
      stage.node.set_flex_grow(1.0)
      stage.node.set_min_width(@yoga.fixed(0.0))
      stage.node.set_min_height(@yoga.fixed(0.0))
      for i = 0; i < n; i = i + 1 {
        let pc = @core.Widget::new()
        pc.node.set_flex_direction(@yoga.Column)
        // 面板撑满舞台：固定宽会让两侧箭头的热区被盖住
        pc.node.set_flex_grow(1.0)
        pc.node.set_min_height(@yoga.fixed(0.0))
        pc.node.set_align_self(Some(@yoga.AlignItems::Stretch))
        pc.set_visible(i == 0)
        let _ = (pages[i].mount)(pc)
        stage.append_child(pc)
        panels.push(pc)
      }

      fn arrow(right : Bool) -> @core.Widget {
        let a = @core.Widget::new()
        a.node.set_width(@yoga.fixed(24.0))
        a.node.set_height(@yoga.fixed(height))
        a.on_draw = Some(fn(
          self : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          if self.hovered {
            p.set_fill_color(@theme.theme_fill_hover())
            p.fill_rect(0.0, 0.0, r.w, r.h)
          }
          let cx = r.w / 2.0
          let cy = r.h / 2.0
          p.set_fill_color(@theme.theme_text_regular())
          p.begin_path()
          if right {
            p.move_to(cx - 4.0, cy - 5.0)
            p.line_to(cx + 4.0, cy)
            p.line_to(cx - 4.0, cy + 5.0)
          } else {
            p.move_to(cx + 4.0, cy - 5.0)
            p.line_to(cx - 4.0, cy)
            p.line_to(cx + 4.0, cy + 5.0)
          }
          p.close_path()
          p.fill()
        })
        a.cursor = @core.CURSOR_HAND
        a.on_pointer = Some(fn(
          _self : @core.Widget,
          ev : @core.PointerEvent,
        ) -> Bool {
          match ev.kind {
            @core.Down => {
              do_switch(if right { cur.val + 1 } else { cur.val - 1 })
              true
            }
            _ => false
          }
        })
        a
      }

      let stage_row = @core.Widget::new()
      stage_row.node.set_flex_direction(@yoga.Row)
      stage_row.node.set_height(@yoga.fixed(height))
      stage_row.append_child(arrow(false))
      stage_row.append_child(stage)
      stage_row.append_child(arrow(true))
      w.append_child(stage_row)

      let dots_row = @core.Widget::new()
      dots_row.node.set_flex_direction(@yoga.Row)
      dots_row.node.set_height(@yoga.fixed(24.0))
      dots_row.node.set_justify_content(@yoga.JustifyContent::Center)
      for i = 0; i < n; i = i + 1 {
        let dot = @core.Widget::new()
        dot.node.set_width(@yoga.fixed(8.0))
        dot.node.set_height(@yoga.fixed(8.0))
        dot.set_margin(top=8.0, bottom=4.0, left=4.0, right=4.0)
        let di = i
        dot.on_draw = Some(fn(
          _self : @core.Widget,
          p : @render.Painter,
          r : @core.Rect,
        ) -> Unit {
          p.set_fill_color(
            if cur.val == di {
              @theme.theme_primary()
            } else {
              @theme.theme_border()
            },
          )
          p.fill_rect(0.0, 0.0, r.w, r.h)
        })
        dot.cursor = @core.CURSOR_HAND
        dot.on_pointer = Some(fn(
          _self : @core.Widget,
          ev : @core.PointerEvent,
        ) -> Bool {
          match ev.kind {
            @core.Down => {
              do_switch(di)
              true
            }
            _ => false
          }
        })
        dots_row.append_child(dot)
      }
      w.append_child(dots_row)

      // 悬停暂停：指针进到本控件（父链才会收到移动）即停，离开（宿主补发的
      // Leave 沿同一条路径上来）即恢复
      w.on_pointer = Some(fn(
        _self : @core.Widget,
        ev : @core.PointerEvent,
      ) -> Bool {
        match ev.kind {
          @core.Move => {
            rotation.paused.val = true
            false
          }
          @core.Leave => {
            rotation.paused.val = false
            false
          }
          _ => false
        }
      })
      if interval_ms > 0 && n > 1 {
        // 一次性延时自排下一拍：句柄存进 rotation，停转时取消待触发那次
        let tick : Ref[() -> Unit] = Ref(fn() { () })
        tick.val = fn() {
          rotation.timer.val = @core.set_timeout(interval_ms, fn() {
            if rotation.running.val {
              if !rotation.paused.val {
                do_switch(cur.val + 1)
              }
              (tick.val)()
            }
          })
        }
        (tick.val)()
      }
    }
    handle(w)
    w
  })
}

