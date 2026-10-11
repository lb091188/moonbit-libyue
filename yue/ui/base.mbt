// 组件层公共地基：文本测量接入布局引擎、主题跟随重绘、绘制小工具。
//
// 三条统一口径：
// ① 组件一律返回 `@core.Node`——构造只建树，mount 才建控件；命令式使用者经
//    `handle?` 拿控件句柄（与 master 同名同义）。
// ② 随内容定尺寸的控件把尺寸交给布局引擎的 measure/baseline 回调，测量走
//    `yue/text`（Pango）；文本状态的唯一权威在组件自己的 `TextSource`。
// ③ 主题色在 `on_draw` 里**现取**（不在建树时固化），主题变化经一次进程级
//    订阅请求重绘。

///|
/// `handle?` 的默认值：不需要句柄时不必写空闭包。
pub fn default_handle(_w : @core.Widget) -> Unit { () }

///|
/// 一份文本状态（引用语义：字段 mut，测量与绘制回调共用同一份）。
pub(all) struct TextSource {
  mut text : String
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
    @theme.theme_text_regular()
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
fn draw_text_in(w : @core.Widget, p : @render.Painter, src : TextSource) -> Unit {
  let r = w.rect
  p.flush()
  let _ = @text.draw_in_box(
    p.bitmap,
    0.0,
    0.0,
    r.w,
    r.h,
    src.text,
    src.font,
    src.fg(),
    align=src.align,
    valign=@text.Center,
    ellipsize=src.ellipsis,
    wrap=src.wrap,
    max_width=if src.max_width > 0.0 { src.max_width.floor().to_int() } else { 0 },
  )
}

// ---- 主题跟随 ----

let theme_watch : Ref[Bool] = Ref(false)

///|
/// 主题变化就请求重绘。这里**只订阅一次**（进程级）：`invalidate` 本就是全局
/// 的，按控件逐个订阅会让每次重挂都留下一条死订阅，换不来任何精度。
fn watch_theme() -> Unit {
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
