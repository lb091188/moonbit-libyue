// 组件层公共地基：文本测量接入布局引擎、主题跟随重绘、绘制小工具。
//
// 三条统一口径：
// ① 组件一律返回 `@core.Node`——构造只建树，mount 才建控件；命令式使用者经
//    `handle?` 拿控件句柄（与 master 同名同义）。
// ② 随内容定尺寸的控件把尺寸交给布局引擎的 measure/baseline 回调，测量走
//    `text`（Pango）；文本状态的唯一权威在组件自己的 `TextSource`。
// ③ 主题色在 `on_draw` 里**现取**（不在建树时固化），主题变化经一次进程级
//    订阅请求重绘。

///|
/// `handle?` 的默认值：不需要句柄时不必写空闭包。
pub fn default_handle(_w : @core.Widget) -> Unit { () }


///|
/// 文字角色（主题排版体系）：字号与颜色随角色统一。§2 合并后 `text` 的排版入口。
pub(all) enum TextRole {
  Plain
  Title
  Section
  Body
  Secondary
  Accent
}

///|
/// 给了角色没有（`Plain` = 无角色形态，走 `text` 的显式 size/weight 原语义）。
/// 哨兵不叫 `None`：包内所有 `Store::new(None)` 会撞过来按 TextRole 推断
/// （W21b 同款坑，见 adaptation）。
pub fn has_role(r : TextRole) -> Bool {
  match r {
    Plain => false
    _ => true
  }
}

///|
/// 角色字号（逻辑像素）与字重（`Title` / `Section` / `Accent` 走 SemiBold）。
/// 缺省字族按平台探（Windows 钉雅黑；探不到交引擎缺省），见
/// @theme.default_font_family 的注释。
pub fn role_font(role : TextRole) -> @text.Font {
  let fam = @theme.default_font_family()
  match role {
    Plain => @text.Font::new(fam, 13.0)
    Title => @text.Font::new(fam, 18.0, weight=@text.SemiBold)
    Section => @text.Font::new(fam, 14.0, weight=@text.SemiBold)
    Body => @text.Font::new(fam, 13.0)
    Secondary => @text.Font::new(fam, 12.0)
    Accent => @text.Font::new(fam, 13.0, weight=@text.SemiBold)
  }
}

///|
/// 角色颜色键：`Var(token)` 形态，落色发生在绘制期（[TextSource.fg] 经
/// `@style.resolve_color` 现取主题），主题切换随重绘生效、不固化快照。
fn role_token(role : TextRole) -> String {
  match role {
    Plain => "text_regular"
    Title | Section => "text_primary"
    Body => "text_regular"
    Secondary => "text_secondary"
    Accent => "primary"
  }
}

///|
/// 角色颜色（现取主题，画一期一个读数；供需要字符串的调用方）。
pub fn role_color(role : TextRole) -> String {
  @style.resolve_color(@style.Var(role_token(role)))
}

///|
/// 一份文本状态（引用语义：字段 mut，测量与绘制回调共用同一份）。
pub(all) struct TextSource {
  mut text : String
  /// 排版角色：`color` 空串时按角色现取主题色（§2 `text` 合并入口用它）
  mut role : TextRole
  mut font : @text.Font
  mut color : String
  mut align : @text.TextAlign
  mut wrap : Bool
  mut ellipsis : Bool
  /// 盒宽上限（像素）；0 = 不设限。换行与省略都按它算
  mut max_width : Double
}

///|
/// 建一份文本状态（字号是逻辑像素，不是磅）。
pub fn text_source(
  text : String,
  role? : TextRole = Plain,
  size? : Double = 13.0,
  color? : String = "",
  weight? : @text.FontWeight = @text.Normal,
  style? : @text.FontStyle = @text.Roman,
  family? : String = "",
  align? : @text.TextAlign = @text.Start,
  wrap? : Bool = false,
  ellipsis? : Bool = false,
  max_width? : Double = 0.0,
) -> TextSource {
  {
    text,
    role,
    font: @text.Font::new(family, size, weight=weight, style=style),
    color,
    align,
    wrap,
    ellipsis,
    max_width,
  }
}

///|
/// 生效颜色：空串走主题正文色（主题切换后现取，不固化）。
pub fn TextSource::fg(self : TextSource) -> String {
  if self.color.length() == 0 {
    role_color(self.role)
  } else {
    self.color
  }
}

///|
/// 把文本状态接到布局引擎的测量面：内容尺寸来自 Pango，基线同源。
/// 近似口径（记档）：min-content 探询（请求轴 `Some(0.0)`）按「不受约束」处理
/// ——本层还没有按 min-content 定宽的弹性场景，接进省略号自适应时再细化。
fn attach_text_measure(w : @core.Widget, src : TextSource) -> Unit {
  w.node.set_measure(fn(avail_w : Double?, _avail_h : Double?) -> (
    Double,
    Double,
  ) {
    // 有盒宽上限就用它，否则用父给的可用宽（0 视为不约束）
    let cap = if src.max_width > 0.0 {
      src.max_width
    } else {
      match avail_w {
        Some(v) => v
        None => 0.0
      }
    }
    let box_w = cap.floor().to_int()
    let wrap = src.wrap && box_w > 0
    match @text.measure_font(
      src.text,
      src.font,
      max_width=box_w,
      ellipsize=src.ellipsis,
      wrap=wrap,
    ) {
      Some(m) => (m.width.to_double(), m.height.to_double())
      None => (0.0, 0.0)
    }
  })
  w.node.set_baseline(fn(_a : Double?, _b : Double?) -> Double? {
    @text.line_ascent_font(src.font).map(fn(v : Int) -> Double { v.to_double() })
  })
}

///|
/// 按文本状态在控件盒内绘制（对齐/换行/省略都按 `src`，垂直居中）。
fn draw_text_in(w : @core.Widget, p : @render.Painter, src : TextSource) -> Bool {
  let r = w.rect
  // 盒宽取「控件宽与声明的 max_width 的较小者」：draw_box_at 的宽度约束就是盒宽
  let box_w = if src.max_width > 0.0 { src.max_width.min(r.w) } else { r.w }
  // 文字属性按状态选桶读（design.md §1.3：绘制期读 `self`）：散参数已折进
  // resolved Style，`class` 覆盖散参数由解析顺序保证；桶里没写的一律回落 src。
  let st = @style.style_for(w)
  let fg1 = match st.color {
    Some(c) => @style.resolve_color(c)
    None => src.fg()
  }
  let font1 = match (st.font_size, st.font_weight, st.font_family) {
    (fs, fw, ff) => {
      let f0 = src.font
      let fam = match ff {
        Some(v) => v
        None => f0.name
      }
      let sz = match fs {
        Some(v) => v
        None => f0.size
      }
      let wt = match fw {
        Some(v) => v
        None => f0.weight
      }
      @text.Font::new(fam, sz, weight=wt, style=f0.style)
    }
  }
  @text.draw_box_at(
    p,
    0.0,
    0.0,
    box_w,
    r.h,
    src.text,
    font1,
    fg1,
    align=src.align,
    valign=@text.Center,
    ellipsize=src.ellipsis,
    wrap=src.wrap,
  )
}

// ---- 主题跟随 ----

let theme_watch : Ref[Bool] = Ref(false)

///|
/// 主题变化就请求重绘。这里**只订阅一次**（进程级）：`invalidate` 本就是全局
/// 的，按控件逐个订阅会让每次重挂都留下一条死订阅，换不来任何精度。
pub fn watch_theme() -> Unit {
  if !theme_watch.val {
    theme_watch.val = true
    let _ = @theme.on_theme_change(fn() { @core.invalidate() })
  }
}

///|
/// 换文本后让布局重新测量：重设一次测量回调即 `mark_changed`，下一帧只重算
/// 这一条链（脏区增量重排）。
pub fn relabel(w : @core.Widget, src : TextSource, text : String) -> Unit {
  src.text = text
  attach_text_measure(w, src)
  @core.invalidate()
}

///|
/// 颜色散参数→`Color`：`#` 开头按 hex、命名色按 named、其余按 theme token 名
/// （落色画期现取，§1.4）。空串=没给。
pub fn parse_style_color(hex : String) -> @style.Color? {
  if hex.length() == 0 {
    None
  } else if hex.has_prefix("#") || @style.is_named_color(hex) {
    Some(@style.parse_color(hex))
  } else {
    Some(@style.Var(hex))
  }
}

///|
/// 散参数折块（§1.5「散参数是糖，只有一条去向」）：把一条颜色属性折进匿名块。
pub fn fold_color(
  hex : String,
  set : (@style.Style, @style.Color) -> Unit,
) -> @style.Style? {
  match parse_style_color(hex) {
    Some(c) => {
      let s = @style.empty_style()
      set(s, c)
      Some(s)
    }
    None => None
  }
}

///|
/// 三个颜色属性的折块快捷入口（对应散参数 `background_color` / `color` /
/// `border_color`）。
pub fn bg_block(hex : String) -> @style.Style? {
  fold_color(hex, fn(s, c) { s.background_color = Some(c) })
}

///|
pub fn fg_block(hex : String) -> @style.Style? {
  fold_color(hex, fn(s, c) { s.color = Some(c) })
}

///|
pub fn border_block(hex : String) -> @style.Style? {
  fold_color(hex, fn(s, c) { s.border_color = Some(c) })
}

///|
/// 组件统一收口（§2「散参数是糖，只有一条去向」）：散参数折成的匿名块排最前，
/// `class` 在后（数组尾赢 ⇒ `class` > 散参数，不需要第二条优先级规则），
/// 一次 `merge_all` + `apply` 落到控件样式槽与 Yoga。
pub fn fold_style(
  w : @core.Widget,
  anon : @style.Style,
  class : Array[@style.Style],
) -> Unit {
  @style.apply(w, @style.merge_all([anon] + class))
}

///|
/// 标记控件的取色口径（§1.5「只有读 resolved Style 一条路径」的收尾）：勾选点、
/// 单选环、开关滑珠、滑块拇指这类标记画在**子控件**上，而 `class` 落在外层宿主；
/// 子控件的 `on_draw` 只读自己的样式槽，所以建树时从 `class` 里**只摘绘制期属性**
/// （`color` / `background_color` / `border_color` / `border_width` / `border_radius`
/// 与三个状态桶）叠在组件内置基调之上。布局属性（宽度、内边距那批）不外溢给标记，
/// 一个「组」的 class 于是同时管得住整行排版与标记配色。
pub fn paint_subset(class : Array[@style.Style]) -> @style.Style {
  let s = @style.merge_all(class)
  let out = @style.empty_style()
  out.color = s.color
  out.background_color = s.background_color
  out.border_color = s.border_color
  out.border_width = s.border_width
  out.border_radius = s.border_radius
  out.hover = s.hover
  out.active = s.active
  out.focus = s.focus
  out
}

