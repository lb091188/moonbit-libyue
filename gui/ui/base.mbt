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
  font_size? : Double = 13.0,
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
    font: @text.Font::new(family, font_size, weight=weight, style=style),
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
/// 文本类样式的合流（§1.1「文本与颜色」那半张表的真去处）：样式槽给了就用样式的，
/// 没给回落 `src`。五个返回值 = 生效字体 / 对齐 / 是否折行 / 行高（0=不设）/ 下划线。
/// `st` 由调用方决定读哪一层：**绘制期**传 `style_for(w)`（含状态桶），
/// **测量期**传 `resolved_by_id(id)`（只看基块——状态桶不带布局属性，§1.3）。
fn text_eff(
  st : @style.Style,
  src : TextSource,
) -> (@text.Font, @text.TextAlign, Bool, Double, Bool) {
  let f0 = src.font
  let fam = match st.font_family {
    Some(v) => v
    None => f0.name
  }
  let sz = match st.font_size {
    Some(v) => v
    None => f0.size
  }
  let wt = match st.font_weight {
    Some(v) => v
    None => f0.weight
  }
  let font = @text.Font::new(fam, sz, weight=wt, style=f0.style)
  let align = match st.text_align {
    Some(v) => v
    None => src.align
  }
  let wrap = match st.white_space {
    Some(@style.WhiteSpace::NoWrap) => false
    Some(@style.WhiteSpace::Normal) => true
    None => src.wrap
  }
  let line_h = match st.line_height {
    Some(v) => v
    None => 0.0
  }
  let underline = match st.text_decoration {
    Some(@style.TextDecoration::Underline) => true
    _ => false
  }
  (font, align, wrap, line_h, underline)
}

///|
/// 把文本状态接到布局引擎的测量面：内容尺寸来自 Pango，基线同源。
/// 近似口径（记档）：min-content 探询（请求轴 `Some(0.0)`）按「不受约束」处理
/// ——本层还没有按 min-content 定宽的弹性场景，接进省略号自适应时再细化。
fn attach_text_measure(w : @core.Widget, src : TextSource) -> Unit {
  // 只记 id，不记句柄：回调挂在布局节点上，捕获控件就成了引用环
  let id = w.id
  w.node.set_measure(fn(avail_w : Double?, _avail_h : Double?) -> (
    Double,
    Double,
  ) {
    let (font, _align, wrap, line_h, _u) = text_eff(@style.resolved_by_id(id), src)
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
    let do_wrap = wrap && box_w > 0
    match @text.measure_font(
      src.text,
      font,
      max_width=box_w,
      ellipsize=src.ellipsis,
      wrap=do_wrap,
    ) {
      Some(m) => {
        // `line_height` 是行盒高：单行档精确生效；折行档要多行行距，那要等
        // 文本层开行距接口（记档在 design.md §1.1），这里只在单行时覆盖
        let h = if line_h > 0.0 && !do_wrap {
          line_h
        } else {
          m.height.to_double()
        }
        (m.width.to_double(), h)
      }
      None => (0.0, 0.0)
    }
  })
  w.node.set_baseline(fn(_a : Double?, _b : Double?) -> Double? {
    let (font, _align, _wrap, _lh, _u) = text_eff(@style.resolved_by_id(id), src)
    @text.line_ascent_font(font).map(fn(v : Int) -> Double { v.to_double() })
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
  let (font1, align1, wrap1, _line_h, underline) = text_eff(st, src)
  let drew = @text.draw_box_at(
    p,
    0.0,
    0.0,
    box_w,
    r.h,
    src.text,
    font1,
    fg1,
    align=align1,
    valign=@text.Center,
    ellipsize=src.ellipsis,
    wrap=wrap1,
  )
  if underline && src.text.length() > 0 {
    // 下划线按测量宽自绘（文本层的 range 属性只有 font+color，没有下划线接口，
    // 与 `link` 的悬停下划线同一手法）：单行档精确，折行档只落最后一行下方
    draw_underline(p, w, src, font1, box_w, fg1, align1)
  }
  drew
}

///|
/// 单行下划线：基线下方 1.5px 起一条 1px 线，宽度与左右位置按对齐算。
fn draw_underline(
  p : @render.Painter,
  w : @core.Widget,
  src : TextSource,
  font : @text.Font,
  box_w : Double,
  color : String,
  align : @text.TextAlign,
) -> Unit {
  let m = match @text.measure_font(src.text, font, wrap=false) {
    Some(m) => m
    None => return ()
  }
  let tw = m.width.to_double()
  let th = m.height.to_double()
  let r = w.rect
  if r.h <= 0.0 {
    return ()
  }
  let top = ((r.h - th) / 2.0).max(0.0)
  // 线必须落在盒内：后端给的行盒不够高（有的平台 height 只算到基线）时贴着
  // 底边画，而不是把整条下划线丢掉——丢了就是「样式没生效」，比画低一格坏。
  let y = (top + m.baseline.to_double() + 1.5).min(r.h - 1.0).max(0.0)
  let x = if align is @text.TextAlign::Center {
    ((box_w - tw) / 2.0).max(0.0)
  } else if align is @text.TextAlign::End {
    (box_w - tw).max(0.0)
  } else {
    0.0
  }
  p.set_fill_color(color)
  p.fill_rect(x, y, tw.max(1.0), 1.0)
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

