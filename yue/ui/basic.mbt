// 基础原语与第一个交互控件：容器 / 分组 / 分隔线 / 标签 / 图像 / 图标 / 按钮。
// 一律返回 `@core.Node`（建树不实例化），颜色在 `on_draw` 里现取主题值。
//
// 与 master 的两处命名差（都记进 adaptation）：
// ① `type=` 换成 `kind=ButtonKind`——本工具链把 `type` 列为保留字，作参数名
//    直接语法错；
// ② 禁用态配色暂用「fill_hover 底 + text_secondary 字」，真正的 disabled
//    色板随主题批补进 `Theme`。

///|
/// 按钮形态。
pub(all) enum ButtonKind {
  Primary
  Border
  Text
}

///|
/// 通用容器：方向、两个轴的间距、内边距、尺寸、底色与描边。
/// 尺寸给 0 表示按内容；要撑满剩余空间用 `grow=1.0`。
pub fn container(
  children : Array[@core.Node],
  direction? : @yoga.FlexDirection = @yoga.Column,
  row_gap? : Double = 0.0,
  column_gap? : Double = 0.0,
  padding? : Double = 0.0,
  width? : Double = 0.0,
  height? : Double = 0.0,
  grow? : Double = 0.0,
  bg? : String = "",
  border? : String = "",
  align_items? : @yoga.AlignItems = @yoga.AlignItems::Stretch,
  justify_content? : @yoga.JustifyContent = @yoga.JustifyContent::FlexStart,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_flex_direction(direction)
    w.node.set_align_items(align_items)
    w.node.set_justify_content(justify_content)
    if row_gap > 0.0 || column_gap > 0.0 {
      w.node.set_gap(row_gap, column_gap)
    }
    if padding > 0.0 {
      w.set_padding(padding, padding)
    }
    if width > 0.0 {
      w.node.set_width(@yoga.fixed(width))
    }
    if height > 0.0 {
      w.node.set_height(@yoga.fixed(height))
    }
    if grow > 0.0 {
      w.node.set_flex_grow(grow)
      // 弹性项默认 min 尺寸按内容，不显式清零就缩不进比内容小的空间
      w.node.set_min_width(@yoga.fixed(0.0))
      w.node.set_min_height(@yoga.fixed(0.0))
    }
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      if bg.length() > 0 {
        p.set_fill_color(bg)
        p.fill_rect(0.0, 0.0, r.w, r.h)
      }
      if border.length() > 0 {
        p.set_stroke_color(border)
        p.set_line_width(1.0)
        p.stroke_rect(0.0, 0.0, r.w, r.h)
      }
    })
    @core.mount_children(w, children)
    handle(w)
    w
  })
}

///|
/// 带标题的面板（标题在上、内容在下，面板底 + 描边）。
pub fn group(
  title : String,
  children : Array[@core.Node],
  padding? : Double = 10.0,
  row_gap? : Double = 6.0,
  width? : Double = 0.0,
) -> @core.Node {
  let body : Array[@core.Node] = [label(title, size=12.0, color=@theme.theme_text_secondary())]
  for c in children {
    body.push(c)
  }
  container(
    body,
    padding=padding,
    row_gap=row_gap,
    width=width,
    bg=@theme.theme_bg_panel(),
    border=@theme.theme_border(),
  )
}

///|
/// 分隔线：默认横线（沿交叉轴撑满），`vertical=true` 为竖线。
pub fn separator(vertical? : Bool = false, color? : String = "") -> @core.Node {
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    if vertical {
      w.node.set_width(@yoga.fixed(1.0))
      w.node.set_align_self(Some(@yoga.AlignItems::Stretch))
    } else {
      w.node.set_height(@yoga.fixed(1.0))
      w.node.set_width(@yoga.percent(100.0))
    }
    w.on_draw = Some(fn(_self : @core.Widget, p : @render.Painter, r : @core.Rect) -> Unit {
      p.set_fill_color(if color.length() > 0 { color } else { @theme.theme_border() })
      p.fill_rect(0.0, 0.0, r.w, r.h)
    })
    w
  })
}

///|
/// 随信号更新的文本标签：文本变化 → 改状态 → 重设测量回调（标脏节点）→
/// 请求重绘，布局只重算这一条链。订阅退订随本代回收袋，重挂不留死订阅。
/// 这也是旧链路 `bind_label` 的对应物（就地改文本，不重建子树）。
pub fn label_dyn(
  sig : @core.Signal[String],
  size? : Double = 13.0,
  color? : String = "",
  weight? : @text.FontWeight = @text.Normal,
  family? : String = "",
  align? : @text.TextAlign = @text.Start,
  max_width? : Double = 0.0,
  wrap? : Bool = false,
  ellipsis? : Bool = false,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let src = text_source(
    sig.get(),
    size=size,
    color=color,
    weight=weight,
    family=family,
    align=align,
    max_width=max_width,
    wrap=wrap,
    ellipsis=ellipsis,
  )
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    attach_text_measure(w, src)
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      _r : @core.Rect,
    ) -> Unit {
      let _ = draw_text_in(self, p, src)
    })
    let sid = sig.subscribe(fn(v : String) -> Unit { relabel(w, src, v) })
    @core.sub_bag_register(fn() { sig.remove(sid) })
    handle(w)
    w
  })
}

///|
/// 文本标签：尺寸来自 Pango 测量（measure 与 baseline 都接进布局引擎，
/// 所以文本能参与基线对齐）。
pub fn label(
  text : String,
  size? : Double = 13.0,
  color? : String = "",
  weight? : @text.FontWeight = @text.Normal,
  family? : String = "",
  align? : @text.TextAlign = @text.Start,
  max_width? : Double = 0.0,
  wrap? : Bool = false,
  ellipsis? : Bool = false,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  label_dyn(
    @core.Signal::new(text),
    size=size,
    color=color,
    weight=weight,
    family=family,
    align=align,
    max_width=max_width,
    wrap=wrap,
    ellipsis=ellipsis,
    handle=handle,
  )
}

///|
/// 图像：按文件解码（PNG/JPEG/GIF 首帧）；尺寸给 0 用图片原始尺寸。
pub fn image(
  path : String,
  width? : Double = 0.0,
  height? : Double = 0.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let img = @render.Image::new_from_file(path)
  let w0 = if width > 0.0 { width } else { img.get_width() }
  let h0 = if height > 0.0 { height } else { img.get_height() }
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    w.node.set_width(@yoga.fixed(w0))
    w.node.set_height(@yoga.fixed(h0))
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      if !img.is_empty() {
        p.flush()
        p.draw_image(img, 0.0, 0.0, r.w, r.h)
      }
    })
    handle(w)
    w
  })
}

///|
/// 图标：定点路径数据按尺寸缩放绘制；颜色空 = 主题正文色。
pub fn icon(
  kind : @icons.IconKind,
  size? : Double = 16.0,
  color? : String = "",
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_width(@yoga.fixed(size))
    w.node.set_height(@yoga.fixed(size))
    w.on_draw = Some(fn(
      _self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let c = if color.length() > 0 { color } else { @theme.theme_text_regular() }
      @icons.draw_icon(p, kind, r.w / 2.0, r.h / 2.0, size, c)
    })
    handle(w)
    w
  })
}

///|
/// 按钮形态编号（同包内 match 用裸构造器，跨包引用要写 `@ui.Primary`）。
fn kind_id(k : ButtonKind) -> Int {
  match k {
    Primary => 0
    Border => 1
    Text => 2
  }
}

///|
/// 按钮：悬停/按下态读宿主维护的 `hovered`/`pressed`；点击在**松开仍落在按钮
/// 内**时触发（捕获期保证指针离开也能收到抬起）。禁用态不消费事件、不换强调色。
pub fn button(
  text : String,
  on_click? : () -> Unit = fn() { () },
  kind? : ButtonKind = Primary,
  size? : Double = 13.0,
  min_width? : Double = 0.0,
  disabled? : Bool = false,
  enabled? : Enabled? = None,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let src = text_source(text, size=size, align=@text.Center)
  let shape = kind_id(kind)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    // 禁用态是单元：布尔若在建树时固化，边界态一改就失效（见 state.mbt）
    let off = enabled_cell(enabled, disabled)
    let is_off = fn() -> Bool { off.off }
    w.node.set_height(@yoga.fixed(@theme.control_height))
    if min_width > 0.0 {
      w.node.set_min_width(@yoga.fixed(min_width))
    }
    w.node.set_padding_left(@yoga.fixed(12.0))
    w.node.set_padding_right(@yoga.fixed(12.0))
    attach_text_measure(w, src)
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let lit = self.hovered || self.pressed
      let skin : (String, String, String) =
        if is_off() {
          (@theme.theme_text_secondary(), @theme.theme_fill_hover(), @theme.theme_border())
        } else if shape == 1 {
          (@theme.theme_primary(), @theme.theme_bg_panel(), @theme.theme_border())
        } else if shape == 2 {
          if lit {
            (@theme.theme_primary(), @theme.theme_fill_hover(), "")
          } else {
            (@theme.theme_primary(), "", "")
          }
        } else if lit {
          ("#ffffff", @theme.theme_primary_hover(), "")
        } else {
          ("#ffffff", @theme.theme_primary(), "")
        }
      if skin.1.length() > 0 {
        p.set_fill_color(skin.1)
        p.fill_rect(0.0, 0.0, r.w, r.h)
      }
      if skin.2.length() > 0 {
        p.set_stroke_color(skin.2)
        p.set_line_width(1.0)
        p.stroke_rect(0.0, 0.0, r.w, r.h)
      }
      // 左右内边距 12；盒内垂直居中交给 draw_box_at（画在会话上，平移裁剪生效）
      let _ = @text.draw_box_at(
        p,
        12.0,
        0.0,
        (r.w - 24.0).max(1.0),
        r.h,
        src.text,
        src.font,
        if is_off() { @theme.theme_text_secondary() } else { skin.0 },
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
        @core.Down => !is_off()
        @core.Up => {
          let inside_x = ev.x >= 0.0 && ev.x <= self.rect.w
          let inside_y = ev.y >= 0.0 && ev.y <= self.rect.h
          if !is_off() && inside_x && inside_y { on_click() }
          false
        }
        @core.Move => !is_off()
        @core.Leave => false
      }
    })
    handle(w)
    w
  })
}
