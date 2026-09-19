// 图标系统:统一矢量绘制入口 draw_icon + 展示视图 icon + 图标按钮
// icon_button_t。全库定案:图标一律矢量自绘,不依赖字体字形(字形图标
// Windows 渲染发虚、跨平台不一致,GTK align=Center 无效,矢量顺带解决
// 居中)。线条图标走默认 1px 描边,与既有 draw_glyph_* 风格一致;
// 主题跟随:on_draw 现取色板,theme_apply 触发整窗重绘。

///|
/// 图标种类(线条风格为主,个别实心)。绘制语义:中心 (cx,cy)、
/// s 为内容半径(半边长),坐标系同 Painter。
pub(all) enum IconKind {
  ChevronLeft
  ChevronRight
  ChevronUp
  ChevronDown
  ArrowUp
  ArrowLeft
  ArrowRight
  ArrowDown
  Plus
  Minus
  Close
  Check
  Search
  Hamburger
  Home
  Gear
  Refresh
  Trash
  Edit
  Save
  Folder
  FileDoc
  User
  Star
  Calendar
  Filter
  Copy
  Download
  Upload
  Play
  Pause
  Info
  Warning
  Error
  Success
  Ellipsis
  Grip
} derive(Eq, Debug)

///| 整圆弧度(2π,圆/点绘制用)
const ICON_TAU : Double = 6.283185307179586

///|
/// 实心圆点(圆心 x,y,半径 r)。
fn icon_dot(p : Painter, x : Double, y : Double, r : Double) -> Unit {
  p.begin_path()
  p.arc(x, y, r, 0.0, ICON_TAU)
  p.fill()
}

///|
/// 折线快捷画法:points 依次连线并描边。
fn icon_polyline(p : Painter, points : Array[(Double, Double)]) -> Unit {
  p.begin_path()
  for i, pt in points {
    if i == 0 {
      p.move_to(pt.0, pt.1)
    } else {
      p.line_to(pt.0, pt.1)
    }
  }
  p.stroke()
}

///|
/// 实心多边形:points 依次连线闭合并填充。
fn icon_polygon(p : Painter, points : Array[(Double, Double)]) -> Unit {
  p.begin_path()
  for i, pt in points {
    if i == 0 {
      p.move_to(pt.0, pt.1)
    } else {
      p.line_to(pt.0, pt.1)
    }
  }
  p.close_path()
  p.fill()
}

///|
/// 统一图标绘制入口:中心 (cx,cy),s 为内容半径,color 为十六进制色。
/// 线条图标以 color 为描边色,实心图标(Star/Play/圆点)以 color 为填充色;
/// 混合型(圆底 + 内符)内符沿用 color。
pub fn draw_icon(
  p : Painter,
  kind : IconKind,
  cx : Double,
  cy : Double,
  s : Double,
  color : String,
) -> Unit {
  p.set_stroke_color(color)
  p.set_fill_color(color)
  match kind {
    ChevronLeft =>
      icon_polyline(p, [(cx + s * 0.35, cy - s * 0.75), (cx - s * 0.45, cy), (cx + s * 0.35, cy + s * 0.75)])
    ChevronRight =>
      icon_polyline(p, [(cx - s * 0.35, cy - s * 0.75), (cx + s * 0.45, cy), (cx - s * 0.35, cy + s * 0.75)])
    ChevronUp =>
      icon_polyline(p, [(cx - s * 0.75, cy + s * 0.35), (cx, cy - s * 0.45), (cx + s * 0.75, cy + s * 0.35)])
    ChevronDown =>
      icon_polyline(p, [(cx - s * 0.75, cy - s * 0.35), (cx, cy + s * 0.45), (cx + s * 0.75, cy - s * 0.35)])
    ArrowUp => {
      icon_polyline(p, [(cx, cy + s), (cx, cy - s)])
      icon_polyline(p, [(cx - s * 0.55, cy - s * 0.35), (cx, cy - s), (cx + s * 0.55, cy - s * 0.35)])
    }
    ArrowDown => {
      icon_polyline(p, [(cx, cy - s), (cx, cy + s)])
      icon_polyline(p, [(cx - s * 0.55, cy + s * 0.35), (cx, cy + s), (cx + s * 0.55, cy + s * 0.35)])
    }
    ArrowLeft => {
      icon_polyline(p, [(cx + s, cy), (cx - s, cy)])
      icon_polyline(p, [(cx - s * 0.35, cy - s * 0.55), (cx - s, cy), (cx - s * 0.35, cy + s * 0.55)])
    }
    ArrowRight => {
      icon_polyline(p, [(cx - s, cy), (cx + s, cy)])
      icon_polyline(p, [(cx + s * 0.35, cy - s * 0.55), (cx + s, cy), (cx + s * 0.35, cy + s * 0.55)])
    }
    Plus => {
      p.set_stroke_color(color)
      icon_polyline(p, [(cx - s * 0.8, cy), (cx + s * 0.8, cy)])
      icon_polyline(p, [(cx, cy - s * 0.8), (cx, cy + s * 0.8)])
    }
    Minus => {
      p.set_stroke_color(color)
      icon_polyline(p, [(cx - s * 0.8, cy), (cx + s * 0.8, cy)])
    }
    Close => {
      p.set_stroke_color(color)
      icon_polyline(p, [(cx - s * 0.7, cy - s * 0.7), (cx + s * 0.7, cy + s * 0.7)])
      icon_polyline(p, [(cx + s * 0.7, cy - s * 0.7), (cx - s * 0.7, cy + s * 0.7)])
    }
    Check => {
      p.set_stroke_color(color)
      icon_polyline(p, [(cx - s * 0.8, cy), (cx - s * 0.25, cy + s * 0.6), (cx + s * 0.8, cy - s * 0.6)])
    }
    Search => {
      p.set_stroke_color(color)
      p.begin_path()
      p.arc(cx - s * 0.2, cy - s * 0.2, s * 0.6, 0.0, ICON_TAU)
      p.stroke()
      icon_polyline(p, [(cx + s * 0.25, cy + s * 0.25), (cx + s * 0.8, cy + s * 0.8)])
    }
    Hamburger => {
      p.set_stroke_color(color)
      icon_polyline(p, [(cx - s * 0.7, cy - s * 0.5), (cx + s * 0.7, cy - s * 0.5)])
      icon_polyline(p, [(cx - s * 0.7, cy), (cx + s * 0.7, cy)])
      icon_polyline(p, [(cx - s * 0.7, cy + s * 0.5), (cx + s * 0.7, cy + s * 0.5)])
    }
    Home => {
      p.set_stroke_color(color)
      icon_polyline(p, [(cx - s, cy - s * 0.15), (cx, cy - s), (cx + s, cy - s * 0.15)])
      p.stroke_rect(cx - s * 0.7, cy - s * 0.1, s * 1.4, s * 0.8)
    }
    Gear => {
      p.set_stroke_color(color)
      p.begin_path()
      p.arc(cx, cy, s * 0.55, 0.0, ICON_TAU)
      p.stroke()
      // 八根辐条(45° 倍数方向,自 0.65s 至 s)
      for i in 0..<8 {
        let a = Double::from_int(i) * ICON_TAU / 8.0
        icon_polyline(p, [(cx + s * 0.65 * @math.cos(a), cy + s * 0.65 * @math.sin(a)), (cx + s * @math.cos(a), cy + s * @math.sin(a))])
      }
      p.set_fill_color(color)
      icon_dot(p, cx, cy, s * 0.18)
    }
    Refresh => {
      p.set_stroke_color(color)
      // 300° 圆弧,缺口朝右下,开口两端各一段回勾形成旋转感
      p.begin_path()
      p.arc(cx, cy, s * 0.75, 0.5, 0.5 + ICON_TAU * 0.83)
      p.stroke()
      let a0 = 0.5
      let tip_x = cx + s * 0.75 * @math.cos(a0)
      let tip_y = cy + s * 0.75 * @math.sin(a0)
      icon_polyline(p, [(tip_x - s * 0.3, tip_y - s * 0.18), (tip_x, tip_y), (tip_x - s * 0.05, tip_y - s * 0.35)])
    }
    Trash => {
      p.set_stroke_color(color)
      icon_polyline(p, [(cx - s * 0.55, cy - s * 0.65), (cx + s * 0.55, cy - s * 0.65)])
      icon_polyline(p, [(cx - s * 0.25, cy - s * 0.65), (cx - s * 0.25, cy - s * 0.9), (cx + s * 0.25, cy - s * 0.9), (cx + s * 0.25, cy - s * 0.65)])
      icon_polyline(p, [(cx - s * 0.6, cy - s * 0.65), (cx - s * 0.5, cy + s * 0.9), (cx + s * 0.5, cy + s * 0.9), (cx + s * 0.6, cy - s * 0.65)])
      icon_polyline(p, [(cx - s * 0.2, cy - s * 0.35), (cx - s * 0.2, cy + s * 0.55)])
      icon_polyline(p, [(cx + s * 0.2, cy - s * 0.35), (cx + s * 0.2, cy + s * 0.55)])
    }
    Edit => {
      p.set_stroke_color(color)
      icon_polyline(p, [(cx + s * 0.7, cy - s * 0.7), (cx - s * 0.55, cy + s * 0.55)])
      icon_polyline(p, [(cx - s * 0.85, cy + s * 0.85), (cx - s * 0.3, cy + s * 0.3)])
      icon_polyline(p, [(cx + s * 0.45, cy - s * 0.95), (cx + s * 0.95, cy - s * 0.45)])
    }
    Save => {
      p.set_stroke_color(color)
      p.stroke_rect(cx - s * 0.8, cy - s * 0.8, s * 1.6, s * 1.6)
      icon_polyline(p, [(cx - s * 0.45, cy - s * 0.25), (cx + s * 0.45, cy - s * 0.25)])
      p.stroke_rect(cx - s * 0.3, cy + 0.0, s * 0.6, s * 0.8)
    }
    Folder => {
      p.set_stroke_color(color)
      p.begin_path()
      p.move_to(cx - s * 0.9, cy - s * 0.6)
      p.line_to(cx - s * 0.3, cy - s * 0.6)
      p.line_to(cx - s * 0.15, cy - s * 0.4)
      p.line_to(cx + s * 0.9, cy - s * 0.4)
      p.line_to(cx + s * 0.9, cy + s * 0.6)
      p.line_to(cx - s * 0.9, cy + s * 0.6)
      p.close_path()
      p.stroke()
    }
    FileDoc => {
      p.set_stroke_color(color)
      p.begin_path()
      p.move_to(cx - s * 0.6, cy - s)
      p.line_to(cx + s * 0.35, cy - s)
      p.line_to(cx + s * 0.6, cy - s * 0.75)
      p.line_to(cx + s * 0.6, cy + s)
      p.line_to(cx - s * 0.6, cy + s)
      p.close_path()
      p.stroke()
      icon_polyline(p, [(cx - s * 0.35, cy - s * 0.3), (cx + s * 0.35, cy - s * 0.3)])
      icon_polyline(p, [(cx - s * 0.35, cy + 0.05 * s), (cx + s * 0.35, cy + 0.05 * s)])
    }
    User => {
      p.set_stroke_color(color)
      p.begin_path()
      p.arc(cx, cy - s * 0.45, s * 0.4, 0.0, ICON_TAU)
      p.stroke()
      p.begin_path()
      // 肩部上半圆
      p.arc(cx, cy + s * 0.85, s * 0.75, 3.141592653589793, ICON_TAU)
      p.stroke()
    }
    Star => {
      // 五角星(实心):外半径 s、内半径 0.42s,顶点起始朝上
      p.set_fill_color(color)
      p.begin_path()
      for i in 0..<10 {
        let r = if i % 2 == 0 { s } else { s * 0.42 }
        let a = Double::from_int(i) * ICON_TAU / 10.0 - ICON_TAU / 4.0
        let px = cx + r * @math.cos(a)
        let py = cy + r * @math.sin(a)
        if i == 0 {
          p.move_to(px, py)
        } else {
          p.line_to(px, py)
        }
      }
      p.close_path()
      p.fill()
    }
    Calendar => {
      p.set_stroke_color(color)
      p.stroke_rect(cx - s * 0.8, cy - s * 0.7, s * 1.6, s * 1.4)
      icon_polyline(p, [(cx - s * 0.45, cy - s * 0.95), (cx - s * 0.45, cy - s * 0.5)])
      icon_polyline(p, [(cx + s * 0.45, cy - s * 0.95), (cx + s * 0.45, cy - s * 0.5)])
      icon_polyline(p, [(cx - s * 0.8, cy - s * 0.25), (cx + s * 0.8, cy - s * 0.25)])
      p.set_fill_color(color)
      p.fill_rect(cx - s * 0.45, cy + 0.05 * s, s * 0.3, s * 0.3)
      p.fill_rect(cx + 0.15 * s, cy + 0.05 * s, s * 0.3, s * 0.3)
    }
    Filter => {
      p.set_stroke_color(color)
      p.begin_path()
      p.move_to(cx - s * 0.85, cy - s * 0.7)
      p.line_to(cx + s * 0.85, cy - s * 0.7)
      p.line_to(cx + s * 0.2, cy - s * 0.05)
      p.line_to(cx + s * 0.2, cy + s * 0.7)
      p.line_to(cx - s * 0.2, cy + s * 0.7)
      p.line_to(cx - s * 0.2, cy - s * 0.05)
      p.close_path()
      p.stroke()
    }
    Copy => {
      p.set_stroke_color(color)
      p.stroke_rect(cx - s * 0.7, cy - s * 0.4, s * 0.95, s * 1.1)
      p.stroke_rect(cx - s * 0.25, cy - s * 0.85, s * 0.95, s * 1.1)
    }
    Download => {
      p.set_stroke_color(color)
      icon_polyline(p, [(cx, cy - s * 0.8), (cx, cy + s * 0.35)])
      icon_polyline(p, [(cx - s * 0.5, cy - s * 0.05), (cx, cy + s * 0.45), (cx + s * 0.5, cy - s * 0.05)])
      icon_polyline(p, [(cx - s * 0.8, cy + s * 0.8), (cx + s * 0.8, cy + s * 0.8)])
    }
    Upload => {
      p.set_stroke_color(color)
      icon_polyline(p, [(cx, cy + s * 0.8), (cx, cy - s * 0.35)])
      icon_polyline(p, [(cx - s * 0.5, cy + s * 0.05), (cx, cy - s * 0.45), (cx + s * 0.5, cy + s * 0.05)])
      icon_polyline(p, [(cx - s * 0.8, cy + s * 0.8), (cx + s * 0.8, cy + s * 0.8)])
    }
    Play => {
      p.set_fill_color(color)
      icon_polygon(p, [(cx - s * 0.45, cy - s * 0.7), (cx - s * 0.45, cy + s * 0.7), (cx + s * 0.65, cy)])
    }
    Pause => {
      p.set_stroke_color(color)
      icon_polyline(p, [(cx - s * 0.3, cy - s * 0.7), (cx - s * 0.3, cy + s * 0.7)])
      icon_polyline(p, [(cx + s * 0.3, cy - s * 0.7), (cx + s * 0.3, cy + s * 0.7)])
    }
    Info => {
      p.set_stroke_color(color)
      p.begin_path()
      p.arc(cx, cy, s * 0.85, 0.0, ICON_TAU)
      p.stroke()
      icon_polyline(p, [(cx, cy + s * 0.45), (cx, cy - s * 0.05)])
      p.set_fill_color(color)
      icon_dot(p, cx, cy - s * 0.42, s * 0.11)
    }
    Warning => {
      p.set_stroke_color(color)
      p.begin_path()
      p.move_to(cx, cy - s * 0.85)
      p.line_to(cx + s * 0.9, cy + s * 0.75)
      p.line_to(cx - s * 0.9, cy + s * 0.75)
      p.close_path()
      p.stroke()
      icon_polyline(p, [(cx, cy - s * 0.25), (cx, cy + s * 0.22)])
      p.set_fill_color(color)
      icon_dot(p, cx, cy + s * 0.45, s * 0.1)
    }
    Error => {
      p.set_stroke_color(color)
      p.begin_path()
      p.arc(cx, cy, s * 0.85, 0.0, ICON_TAU)
      p.stroke()
      icon_polyline(p, [(cx - s * 0.35, cy - s * 0.35), (cx + s * 0.35, cy + s * 0.35)])
      icon_polyline(p, [(cx + s * 0.35, cy - s * 0.35), (cx - s * 0.35, cy + s * 0.35)])
    }
    Success => {
      p.set_stroke_color(color)
      p.begin_path()
      p.arc(cx, cy, s * 0.85, 0.0, ICON_TAU)
      p.stroke()
      icon_polyline(p, [(cx - s * 0.35, cy), (cx - s * 0.1, cy + s * 0.3), (cx + s * 0.4, cy - s * 0.3)])
    }
    Ellipsis => {
      p.set_fill_color(color)
      icon_dot(p, cx - s * 0.6, cy, s * 0.14)
      icon_dot(p, cx, cy, s * 0.14)
      icon_dot(p, cx + s * 0.6, cy, s * 0.14)
    }
    Grip => {
      p.set_fill_color(color)
      for dy in [-0.5, 0.0, 0.5] {
        icon_dot(p, cx - s * 0.3, cy + s * dy, s * 0.13)
        icon_dot(p, cx + s * 0.3, cy + s * dy, s * 0.13)
      }
    }
  }
}

///|
/// 全部图标种类清单(37 项,图标墙/选取器素材)。
pub fn all_icons() -> Array[IconKind] {
  [
    ChevronLeft,
    ChevronRight,
    ChevronUp,
    ChevronDown,
    ArrowUp,
    ArrowLeft,
    ArrowRight,
    ArrowDown,
    Plus,
    Minus,
    Close,
    Check,
    Search,
    Hamburger,
    Home,
    Gear,
    Refresh,
    Trash,
    Edit,
    Save,
    Folder,
    FileDoc,
    User,
    Star,
    Calendar,
    Filter,
    Copy,
    Download,
    Upload,
    Play,
    Pause,
    Info,
    Warning,
    Error,
    Success,
    Ellipsis,
    Grip,
  ]
}

///|
/// 图标名称(图标墙/提示文案用)。
pub fn icon_name(kind : IconKind) -> String {
  match kind {
    ChevronLeft => "ChevronLeft"
    ChevronRight => "ChevronRight"
    ChevronUp => "ChevronUp"
    ChevronDown => "ChevronDown"
    ArrowUp => "ArrowUp"
    ArrowLeft => "ArrowLeft"
    ArrowRight => "ArrowRight"
    ArrowDown => "ArrowDown"
    Plus => "Plus"
    Minus => "Minus"
    Close => "Close"
    Check => "Check"
    Search => "Search"
    Hamburger => "Hamburger"
    Home => "Home"
    Gear => "Gear"
    Refresh => "Refresh"
    Trash => "Trash"
    Edit => "Edit"
    Save => "Save"
    Folder => "Folder"
    FileDoc => "FileDoc"
    User => "User"
    Star => "Star"
    Calendar => "Calendar"
    Filter => "Filter"
    Copy => "Copy"
    Download => "Download"
    Upload => "Upload"
    Play => "Play"
    Pause => "Pause"
    Info => "Info"
    Warning => "Warning"
    Error => "Error"
    Success => "Success"
    Ellipsis => "Ellipsis"
    Grip => "Grip"
  }
}

///|
/// 图标展示视图:固定尺寸,颜色默认主题常规文字色,传 color 固定色。
/// size 为视图边长,图标内容约占 84%。
pub fn icon(kind : IconKind, size? : Double = 16.0, color? : String = "") -> Node {
  {
    mount: fn(parent) {
      let v = themed_container(style=[("width", size), ("height", size)])
      v.on_draw(fn(p) {
        let c = if color != "" { color } else { theme_text_regular() }
        draw_icon(p, kind, size / 2.0, size / 2.0, size * 0.42, c)
      })
      attach(parent, ViewLike::view(v))
      ViewLike::view(v)
    },
  }
}

///|
/// 图标按钮:方形自绘,hover 浅灰底 + 文字色提亮,点击/Enter/Space 触发
/// on_click;tip 非空时挂原生悬浮提示。marginRight 6 便于工具栏横向排列。
pub fn icon_button_t(
  kind : IconKind,
  on_click? : () -> Unit = fn() {  },
  size? : Double = 28.0,
  tip? : String = "",
) -> Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      let focused = Ref(false)
      let v = themed_container(style=[
        ("width", size),
        ("height", size),
        ("marginRight", 6.0),
      ])
      v.on_draw(fn(p) {
        let b = ViewLike::get_bounds(v)
        if hover.val {
          p.set_fill_color(theme_fill_hover())
          p.fill_rect(0.0, 0.0, b.width, b.height)
        }
        let c = if hover.val { theme_text_primary() } else { theme_text_regular() }
        draw_icon(p, kind, b.width / 2.0, b.height / 2.0, size * 0.26, c)
        if focused.val {
          draw_focus_ring(p, b.width, b.height)
        }
      })
      View::set_cursor(v, hand())
      ViewLike::on_mouse_down(v,fn(e) {
        if e.button == 1 {
          ViewLike::focus(v)
          on_click()
          true
        } else {
          false
        }
      })
      bind_focus(v, fn() { ViewLike::schedule_paint(v) }, focused, on_click)
      ViewLike::on_mouse_enter(v,fn(_e) {
        hover.val = true
        ViewLike::schedule_paint(v)
      })
      ViewLike::on_mouse_leave(v,fn(_e) {
        hover.val = false
        ViewLike::schedule_paint(v)
      })
      if tip != "" {
        ffi_view_set_tooltip(ViewLike::view(v), utf8_bytes(tip))
      }
      attach(parent, ViewLike::view(v))
      ViewLike::view(v)
    },
  }
}
