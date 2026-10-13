// 基础原语：容器 / 面板 / 分隔线 / 文本 / 图像 / 图标（§2 前端化命名后）。
// 一律返回 `@core.Node`（建树不实例化），颜色在 `on_draw` 里现取主题值。
//
// 与 master 的一条差仍成立：禁用态配色暂用「fill_hover 底 + text_secondary
// 字」，真正的 disabled 色板随主题批补进 `Theme`。


///|
/// 通用容器：方向、两个轴的间距、内边距、尺寸、底色与描边。
/// 尺寸给 0 表示按内容；要撑满剩余空间用 `grow=1.0`。
pub fn view(
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
      w.set_padding_all(padding)
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
pub fn panel(
  title : String,
  children : Array[@core.Node],
  padding? : Double = 10.0,
  row_gap? : Double = 6.0,
  width? : Double = 0.0,
) -> @core.Node {
  let body : Array[@core.Node] = [text(title, size=12.0, color=@theme.theme_text_secondary())]
  for c in children {
    body.push(c)
  }
  view(
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
/// 随信号更新的文本：文本变化 → 改状态 → 重设测量回调（标脏节点）→
/// 请求重绘，布局只重算这一条链。订阅退订随本代回收袋，重挂不留死订阅。
/// 这也是旧链路 `bind_label` 的对应物（就地改文本，不重建子树），§3 通则里
/// 展示类 `*_dyn` 信号版的原型。
pub fn text_dyn(
  sig : @core.Signal[String],
  role? : TextRole = Plain,
  size? : Double = 13.0,
  color? : String = "",
  weight? : @text.FontWeight = @text.Normal,
  family? : String = "",
  align? : @text.TextAlign = @text.Start,
  max_width? : Double = 0.0,
  wrap? : Bool = false,
  ellipsis? : Bool = false,
  shrink_by_role? : Bool = false,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let src = text_source(
    sig.get(),
    role=role,
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
    // 角色形态沿用 `label_t` 现状:不参与收缩,文本按自然宽占位
    if shrink_by_role {
      w.node.set_flex_shrink(0.0)
    }
    let sid = sig.subscribe(fn(v : String) -> Unit { relabel(w, src, v) })
    @core.sub_bag_register(fn() { sig.remove(sid) })
    handle(w)
    w
  })
}

///|
/// 文本（§2 合并入口：原 `label` + `label_t` 一台）：`role` 给了就按角色取字号
/// 字重与主题色（`role_font` / `role_color`，现状 `label_t` 的排版体系），
/// 不给走显式 `size` / `weight` / `family`。尺寸来自 Pango 测量（measure 与
/// baseline 都接进布局引擎，所以文本能参与基线对齐）。
/// 两条现状差按调用点保持：角色形态默认折行且 `flex_shrink=0`（`label_t` 原样），
/// 无角色形态不折行（`label` 原样）；散参数改名与 class 接线随后续批。
pub fn text(
  content : String,
  role? : TextRole = Plain,
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
  let f = role_font(role)
  let eff_size = if has_role(role) { f.size } else { size }
  let eff_weight =
    if has_role(role) {
      match role {
        Title | Section | Accent => @text.SemiBold
        _ => @text.Normal
      }
    } else {
      weight
    }
  let eff_wrap = if wrap { true } else { role is Body }
  text_dyn(
    @core.Signal::new(content),
    role=role,
    size=eff_size,
    color=color,
    weight=eff_weight,
    family=family,
    align=align,
    max_width=max_width,
    wrap=eff_wrap,
    ellipsis=ellipsis,
    shrink_by_role=has_role(role),
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
/// §2 合并：按钮唯一入口在 `ui/form.mbt` 的 `button`（原 `button`，
/// `variant = solid / soft / border / text / danger`）；本文件的旧 `button` 已删。

///|
/// 图标按钮：只有图标的按钮（悬停浅底、按下更深、禁用不吃事件）。
/// 需要文字提示时由调用方在外面包 `tooltip`（本组件不重复管提示）。
pub fn icon_button(
  kind : @icons.IconKind,
  on_click? : () -> Unit = fn() -> Unit { () },
  icon_size? : Double = 16.0,
  box_size? : Double = 28.0,
  color? : String = "",
  disabled? : Bool = false,
  enabled? : Enabled? = None,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let off = enabled_cell(enabled, disabled)
    w.node.set_width(@yoga.fixed(box_size))
    w.node.set_height(@yoga.fixed(box_size))
    w.node.set_flex_shrink(0.0)
    w.cursor_fn = Some(enabled_cursor(off, @core.CURSOR_HAND))
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      if !off.off && (self.hovered || self.pressed) {
        p.set_fill_color(
          if self.pressed { @theme.theme_primary_light() } else { @theme.theme_fill_hover() },
        )
        fill_round_rect(p, 0.0, 0.0, r.w, r.h, 4.0)
      }
      let c = if color.length() > 0 {
        color
      } else if off.off {
        @theme.theme_text_secondary()
      } else {
        @theme.theme_text_regular()
      }
      @icons.draw_icon(p, kind, r.w / 2.0, r.h / 2.0, icon_size, c)
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
