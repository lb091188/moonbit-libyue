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
  background_color? : String = "",
  border_color? : String = "",
  align_items? : @yoga.AlignItems = @yoga.AlignItems::Stretch,
  justify_content? : @yoga.JustifyContent = @yoga.JustifyContent::FlexStart,
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  // 散参数（颜色与布局同规则）全部折进匿名块：`class` 在后 ⇒ class > 散参数
  // 由数组顺序直接成立，节点上不再留第二条写入路径（§1.5）
  let lay = @style.empty_style()
  lay.flex_direction = Some(direction)
  lay.align_items = Some(align_items)
  lay.justify_content = Some(justify_content)
  if row_gap > 0.0 || column_gap > 0.0 {
    lay.row_gap = Some(row_gap)
    lay.column_gap = Some(column_gap)
  }
  if padding > 0.0 {
    lay.padding_left = Some(padding)
    lay.padding_right = Some(padding)
    lay.padding_top = Some(padding)
    lay.padding_bottom = Some(padding)
  }
  if width > 0.0 {
    lay.width = Some(width)
  }
  if height > 0.0 {
    lay.height = Some(height)
  }
  if grow > 0.0 {
    lay.flex = Some(grow)
    // 弹性项默认 min 尺寸按内容，不显式清零就缩不进比内容小的空间
    lay.min_width = Some(0.0)
    lay.min_height = Some(0.0)
  }
  let blocks : Array[@style.Style] = [
    lay,
    match bg_block(background_color) {
      Some(b) => b
      None => @style.empty_style()
    },
    match border_block(border_color) {
      Some(b) => b
      None => @style.empty_style()
    },
  ]
  let anon = @style.merge_all(blocks)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    // 样式先落（class 覆盖散参数由数组顺序保证），再读 resolved 供绘制
    fold_style(w, anon, class)
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      // 绘制期只读样式槽并按状态选桶（§1.5 唯一路径）：散参数与 class 都在挂载时
      // 折进槽里，`handle=` 里后 apply 的样式下一帧就生效
      let s = @style.style_for(self)
      let bg = @style.color_of(s.background_color, "")
      let bd = @style.color_of(s.border_color, "")
      let rad = @style.number_of(s.border_radius, 0.0)
      // 硬阴影档（§1.1 的 box_shadow = 外扩半径）：本体之下等步长描环，
      // 用整层 alpha 压到 25%（模糊档随文本层之外的 blur 能力再评估）
      let spread = @style.number_of(s.box_shadow, 0.0)
      if spread > 0.0 {
        let layers = (spread / 2.0).round().to_int().clamp(min=2, max=8)
        let keep = p.global_alpha()
        p.set_fill_color("#000000")
        p.set_global_alpha(keep * 0.25)
        p.box_shadow(0.0, 0.0, r.w, r.h, rad, spread, layers)
        p.set_global_alpha(keep)
      }
      if bg.length() > 0 {
        p.set_fill_color(bg)
        if rad > 0.0 {
          fill_round_rect(p, 0.0, 0.0, r.w, r.h, rad)
        } else {
          p.fill_rect(0.0, 0.0, r.w, r.h)
        }
      }
      if bd.length() > 0 {
        p.set_stroke_color(bd)
        p.set_line_width(@style.number_of(s.border_width, 1.0))
        if rad > 0.0 {
          p.round_rect_path(0.5, 0.5, r.w - 1.0, r.h - 1.0, rad)
          p.stroke()
        } else {
          p.stroke_rect(0.0, 0.0, r.w, r.h)
        }
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
  let body : Array[@core.Node] = [text(title, font_size=12.0, color="text_secondary")]
  for c in children {
    body.push(c)
  }
  view(
    body,
    padding=padding,
    row_gap=row_gap,
    width=width,
    background_color="bg_panel",
    border_color="border",
  )
}

///|
/// 分隔线本体（§2 合并后公开入口是 [divider]，`text=` 给文字即带字档）。
/// 默认横线（沿交叉轴撑满），`vertical=true` 为竖线。
fn separator_impl(
  vertical~ : Option[Bool],
  color~ : Option[String],
  class~ : Array[@style.Style] = [],
) -> @core.Node {
  let vertical = vertical.unwrap_or(false)
  let color = color.unwrap_or("")
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    if vertical {
      w.node.set_width(@yoga.fixed(1.0))
      w.node.set_align_self(Some(@yoga.AlignItems::Stretch))
    } else {
      w.node.set_height(@yoga.fixed(1.0))
      w.node.set_width(@yoga.percent(100.0))
    }
    // 散参数折进样式槽（token 名因此在绘制期现取当前主题）
    let anon = match bg_block(color) {
      Some(b) => b
      None => @style.empty_style()
    }
    fold_style(w, anon, class)
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let s = @style.style_for(self)
      p.set_fill_color(@style.color_of(s.background_color, @theme.theme_border()))
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
  font_size? : Double = 13.0,
  color? : String = "",
  weight? : @text.FontWeight = @text.Normal,
  family? : String = "",
  align? : @text.TextAlign = @text.Start,
  max_width? : Double = 0.0,
  wrap? : Bool = false,
  ellipsis? : Bool = false,
  shrink_by_role? : Bool = false,
  anon? : @style.Style = @style.empty_style(),
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let src = text_source(
    sig.get(),
    role=role,
    font_size=font_size,
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
    fold_style(w, anon, class)
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
  font_size? : Double = 13.0,
  color? : String = "",
  weight? : @text.FontWeight = @text.Normal,
  family? : String = "",
  align? : @text.TextAlign = @text.Start,
  max_width? : Double = 0.0,
  wrap? : Bool = false,
  ellipsis? : Bool = false,
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let f = role_font(role)
  let eff_size = if has_role(role) { f.size } else { font_size }
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
  let anon = match fg_block(color) {
    Some(b) => b
    None => @style.empty_style()
  }
  text_dyn(
    @core.Signal::new(content),
    role=role,
    font_size=eff_size,
    color=color,
    weight=eff_weight,
    family=family,
    align=align,
    max_width=max_width,
    wrap=eff_wrap,
    ellipsis=ellipsis,
    shrink_by_role=has_role(role),
    anon=anon,
    class=class,
    handle=handle,
  )
}

///|
/// 分隔线（§2 合并：原 `separator` + 带字 `divider` 一台）：`text` 空=直线档
/// （横线/竖线由 `vertical` 定，沿交叉轴撑满），给文字=居中断线档（12 号字、
/// 两侧断线）。散参数 `color` 只作用于直线档；文字档的线与字各自读样式槽的
/// `background_color` / `color`（回落主题描边色与次要文字色），所以两条都能被
/// `class` 覆盖。
pub fn divider(
  text? : String = "",
  vertical? : Bool = false,
  color? : String = "",
  class? : Array[@style.Style] = [],
) -> @core.Node {
  if text.length() == 0 {
    separator_impl(vertical=Some(vertical), color=Some(color), class=class)
  } else {
    let font = @text.Font::new("", 12.0)
    @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
      watch_theme()
      w.node.set_height(@yoga.fixed(20.0))
      w.node.set_width(@yoga.percent(100.0))
      fold_style(w, @style.empty_style(), class)
      w.on_draw = Some(fn(
        self : @core.Widget,
        p : @render.Painter,
        r : @core.Rect,
      ) -> Unit {
        let s = @style.style_for(self)
        let line = @style.color_of(s.background_color, @theme.theme_border())
        let label = @style.color_of(s.color, @theme.theme_text_secondary())
        let tw = text_width(text, font)
        let cy = r.h / 2.0
        let gap = 8.0
        p.set_fill_color(line)
        p.fill_rect(0.0, cy, ((r.w - tw) / 2.0 - gap).max(0.0), 1.0)
        let right_x = (r.w + tw) / 2.0 + gap
        p.fill_rect(right_x, cy, (r.w - right_x).max(0.0), 1.0)
        let th = @text.line_height_font(font).unwrap_or(16).to_double()
        let _ = @text.draw_at(p, (r.w - tw) / 2.0, cy - th / 2.0, text, font, label)
      })
      w
    })
  }
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
/// 图标：`size` 为盒子边长（方形），字形按盒子短边居中、留 88% 光学边距；
/// 颜色空 = 主题正文色。
pub fn icon(
  kind : @icons.IconKind,
  size? : Double = 16.0,
  color? : String = "",
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let anon = match fg_block(color) {
    Some(b) => b
    None => @style.empty_style()
  }
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    w.node.set_width(@yoga.fixed(size))
    w.node.set_height(@yoga.fixed(size))
    fold_style(w, anon, class)
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let s = @style.style_for(self)
      let c = @style.color_of(s.color, @theme.theme_text_regular())
      // 盒子短边的一半 = 内容半径：字形随盒子走，class 改过宽高也不会溢出
      @icons.draw_icon(p, kind, r.w / 2.0, r.h / 2.0, r.w.min(r.h) / 2.0, c)
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
/// `box_size` 是按钮方盒边长，`icon_size` 是字形盒边长（字形居中在盒内）。
/// 需要文字提示时由调用方在外面包 `tooltip`（本组件不重复管提示）。
pub fn icon_button(
  kind : @icons.IconKind,
  on_click? : () -> Unit = fn() -> Unit { () },
  icon_size? : Double = 16.0,
  box_size? : Double = 28.0,
  color? : String = "",
  disabled? : Bool = false,
  enabled? : Enabled? = None,
  class? : Array[@style.Style] = [],
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  // 内置皮肤（圆角 + 悬停浅底 + 按下更深）写成样式块：基块没有底色，
  // 底色只从状态桶来，绘制期按 `self` 的态选桶即等价于旧的 hovered/pressed 分支
  let skin = @style.style(border_radius=4.0).hover(background_color="fill_hover").active(
    background_color="primary_light",
  )
  let blocks : Array[@style.Style] = [
    skin,
    match fg_block(color) {
      Some(b) => b
      None => @style.empty_style()
    },
  ]
  let anon = @style.merge_all(blocks)
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    let off = enabled_cell(enabled, disabled)
    w.node.set_width(@yoga.fixed(box_size))
    w.node.set_height(@yoga.fixed(box_size))
    w.node.set_flex_shrink(0.0)
    w.cursor_fn = Some(enabled_cursor(off, @core.CURSOR_HAND))
    fold_style(w, anon, class)
    w.on_draw = Some(fn(
      self : @core.Widget,
      p : @render.Painter,
      r : @core.Rect,
    ) -> Unit {
      let s = @style.style_for(self)
      let bg = @style.color_of(s.background_color, "")
      if !off.off && bg.length() > 0 {
        p.set_fill_color(bg)
        fill_round_rect(p, 0.0, 0.0, r.w, r.h, @style.number_of(s.border_radius, 4.0))
      }
      let fallback = if off.off {
        @theme.theme_text_secondary()
      } else {
        @theme.theme_text_regular()
      }
      let c = @style.color_of(s.color, fallback)
      @icons.draw_icon(p, kind, r.w / 2.0, r.h / 2.0, icon_size / 2.0, c)
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
