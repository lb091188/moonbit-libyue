// 显示族组件：标签 / 徽标 / 头像 / 统计 / 提示条 / 卡片 / 描述列表 / 结果页 /
// 空状态 / 分隔线（带文字）/ 折线进度。
//
// 与 master 的差一条（记档）：CSS 风格的 `style=[("marginRight", 8.0)]` 通道
// 还没接（随主题批的 style 通道一起做），这里只留**类型化**参数；语义色
// `SemanticType` 保留同名枚举，色值现取主题（primary/success/warning/danger/info
// 与各自 light 档在 `yue/theme` 已就位）。

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
fn text_width(text : String, font : @text.Font) -> Double {
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
  container(
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
      container(
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
  container(rows, row_gap=4.0)
}

///|
/// 空状态：图标 + 描述，居中。
pub fn empty(description? : String = "暂无数据") -> @core.Node {
  container(
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
  container(
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
    container([bar, pct], direction=@yoga.Row, column_gap=4.0, align_items=@yoga.AlignItems::Center)
  } else {
    container([bar], align_items=@yoga.AlignItems::Center)
  }
}
