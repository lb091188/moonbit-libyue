// 文本族首批：文字角色（字号 + 颜色随角色统一）、主题化标签、按宽量高。
//
// 与 master 的差一条（记档）：`label_t` 的 `style` 通道未接（CSS 风格参数随主题批），
// 这里给类型化参数（角色 / 固定色 / 换行 / 对齐 / 宽度上限）。

///|
/// 文字角色（主题排版体系）：字号与颜色随角色统一。
pub(all) enum TextRole {
  Title
  Section
  Body
  Secondary
  Accent
}

///|
/// 角色字号（逻辑像素）。
pub fn role_font(role : TextRole) -> @text.Font {
  // 缺省字族按平台探（Windows 钉雅黑；探不到交引擎缺省），见
  // @theme.default_font_family 的注释
  let fam = @theme.default_font_family()
  match role {
    Title => @text.Font::new(fam, 18.0, weight=@text.SemiBold)
    Section => @text.Font::new(fam, 14.0, weight=@text.SemiBold)
    Body => @text.Font::new(fam, 13.0)
    Secondary => @text.Font::new(fam, 12.0)
    Accent => @text.Font::new(fam, 13.0, weight=@text.SemiBold)
  }
}

///|
/// 角色颜色（现取主题，不固化）。
pub fn role_color(role : TextRole) -> String {
  match role {
    Title | Section => @theme.theme_text_primary()
    Body => @theme.theme_text_regular()
    Secondary => @theme.theme_text_secondary()
    Accent => @theme.theme_primary()
  }
}

///|
/// 量一段文本在指定宽度下的自然渲染高（`width` 传 0 按不换行量）。
/// 运行期长高的标签用显式高度绕开「测量口径不一致」的老坑：容器问到的
/// 自然高与绘制时按盒宽折行算出的高可能不是一回事，显式设高最稳。
pub fn measure_text_height(
  text : String,
  role? : TextRole = Body,
  width? : Double = 0.0,
) -> Double {
  let f = role_font(role)
  let box_w = if width > 0.0 { width.floor().to_int() } else { 0 }
  match @text.measure_font(text, f, max_width=box_w, wrap=box_w > 0) {
    Some(m) => m.height.to_double()
    None => 0.0
  }
}

///|
/// 主题化标签：字号颜色按角色（`color` 传非空则固定色、不随主题），可换行、
/// 可定宽（`max_width > 0` 时按它折行）。文本变化走 `relabel`（只重测这一条链）。
pub fn label_t(
  text : String,
  role? : TextRole = Body,
  color? : String = "",
  align? : @text.TextAlign = @text.Start,
  wrap? : Bool = true,
  max_width? : Double = 0.0,
  handle? : (@core.Widget) -> Unit = default_handle,
) -> @core.Node {
  let src = text_source(
    text,
    size=role_font(role).size,
    color=color,
    weight=match role {
      Title | Section | Accent => @text.SemiBold
      Body | Secondary => @text.Normal
    },
    align=align,
    wrap=wrap,
    max_width=max_width,
  )
  @core.node_of_new(fn(w : @core.Widget) -> @core.Widget {
    watch_theme()
    attach_text_measure(w, src)
    w.node.set_flex_shrink(0.0)
    w.on_draw = Some(fn(
      _s : @core.Widget,
      p : @render.Painter,
      _r : @core.Rect,
    ) -> Unit {
      let _ = draw_text_in(w, p, src)
    })
    handle(w)
    w
  })
}
