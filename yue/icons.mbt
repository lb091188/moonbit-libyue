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
  // —— 文件/文档 ——
  FilePlus
  FolderOpen
  FolderPlus
  Clipboard
  Book
  Bookmark
  FileCode
  // —— 编辑 ——
  Undo
  Redo
  Scissors
  Paste
  Bold
  Italic
  Underline
  AlignLeft
  AlignCenter
  AlignRight
  ListUl
  ListOl
  Link
  Unlink
  ExternalLink
  // —— 视图 ——
  ZoomIn
  ZoomOut
  Eye
  EyeOff
  Sun
  Moon
  Grid
  Layout
  Sidebar
  // —— 导航 ——
  ChevronsLeft
  ChevronsRight
  ChevronsUp
  ChevronsDown
  SkipBack
  SkipForward
  CornerUpLeft
  CornerUpRight
  // —— 媒体 ——
  Square
  CircleRecord
  Volume
  VolumeOff
  Mic
  Camera
  Image
  Music
  // —— 通信 ——
  Mail
  Send
  MessageCircle
  Bell
  BellOff
  Phone
  Rss
  Globe
  // —— 系统 ——
  Power
  LogOut
  LogIn
  Lock
  Unlock
  Key
  Shield
  Sliders
  Database
  Server
  HardDrive
  Printer
  Monitor
  Smartphone
  Wifi
  WifiOff
  Bluetooth
  Cpu
  // —— 开发 ——
  Terminal
  Code
  GitBranch
  GitCommit
  GitPullRequest
  Package
  Bug
  Flask
  Cloud
  CloudDownload
  CloudUpload
  Layers
  Zap
  // —— 语义/状态 ——
  Help
  Heart
  Flag
  Clock
  Tag
  Archive
  Inbox
  ThumbsUp
  // —— 数据 ——
  TrendingUp
  TrendingDown
  BarChart
  PieChart
  TableRows
} derive(Eq, Debug)

///|
pub extend IconKind with Eq::{equal, not_equal}

///|
pub extend IconKind with Debug::{to_repr}

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
/// 闭合折线:依次连线后闭合并描边(轮廓图标)。
fn icon_outline(p : Painter, points : Array[(Double, Double)]) -> Unit {
  p.begin_path()
  for i, pt in points {
    if i == 0 {
      p.move_to(pt.0, pt.1)
    } else {
      p.line_to(pt.0, pt.1)
    }
  }
  p.close_path()
  p.stroke()
}

///|
/// 描边圆。
fn icon_circle(p : Painter, x : Double, y : Double, r : Double) -> Unit {
  p.begin_path()
  p.arc(x, y, r, 0.0, ICON_TAU)
  p.stroke()
}

///|
/// 单线段。
fn icon_line(p : Painter, x0 : Double, y0 : Double, x1 : Double, y1 : Double) -> Unit {
  p.begin_path()
  p.move_to(x0, y0)
  p.line_to(x1, y1)
  p.stroke()
}

///|
/// 描边圆弧(起止角为弧度,canvas 语义:0 = 右,顺时针为正)。
fn icon_arc(
  p : Painter,
  x : Double,
  y : Double,
  r : Double,
  a0 : Double,
  a1 : Double,
  ccw? : Bool = false,
) -> Unit {
  p.begin_path()
  // 逆时针弧 libyue 两层后端都表达不了（GTK cairo_arc 会把 ea<sa 规范
  // 化成顺时针长弧；Win 公开 API 写死顺时针）。描边方向不影响几何，
  // 交换起止角即等价；填充场景（见图表圆环）须用折线近似。
  if ccw {
    p.arc(x, y, r, a1, a0)
  } else {
    p.arc(x, y, r, a0, a1)
  }
  p.stroke()
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
    // —— 文件/文档(24 网格,u = s/9 为 Tabler 式坐标换算) ——
    FilePlus => {
      let u = s / 9.0
      icon_outline(p, [(cx - 5 * u, cy - 9 * u), (cx + u, cy - 9 * u), (cx + 5 * u, cy - 5 * u), (cx + 5 * u, cy + 9 * u), (cx - 5 * u, cy + 9 * u)])
      icon_polyline(p, [(cx + u, cy - 9 * u), (cx + u, cy - 5 * u), (cx + 5 * u, cy - 5 * u)])
      icon_line(p, cx, cy + 3 * u, cx, cy + 7 * u)
      icon_line(p, cx - 2 * u, cy + 5 * u, cx + 2 * u, cy + 5 * u)
    }
    FolderOpen => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 9 * u, cy - 6 * u), (cx - 3 * u, cy - 6 * u), (cx - u, cy - 4 * u), (cx + 8 * u, cy - 4 * u), (cx + 8 * u, cy - 1 * u)])
      icon_outline(p, [(cx - 8.5 * u, cy - 1 * u), (cx + 8.5 * u, cy - 1 * u), (cx + 6.5 * u, cy + 6 * u), (cx - 6.5 * u, cy + 6 * u)])
    }
    FolderPlus => {
      let u = s / 9.0
      icon_outline(p, [(cx - 8 * u, cy - 6 * u), (cx - 3 * u, cy - 6 * u), (cx - u, cy - 4 * u), (cx + 8 * u, cy - 4 * u), (cx + 8 * u, cy + 7 * u), (cx - 8 * u, cy + 7 * u)])
      icon_line(p, cx, cy + 1 * u, cx, cy + 5 * u)
      icon_line(p, cx - 2 * u, cy + 3 * u, cx + 2 * u, cy + 3 * u)
    }
    Clipboard => {
      let u = s / 9.0
      icon_outline(p, [(cx - 3 * u, cy - 5 * u), (cx - 6 * u, cy - 5 * u), (cx - 6 * u, cy + 9 * u), (cx + 6 * u, cy + 9 * u), (cx + 6 * u, cy - 5 * u), (cx + 3 * u, cy - 5 * u)])
      icon_outline(p, [(cx - 3 * u, cy - 8 * u), (cx + 3 * u, cy - 8 * u), (cx + 3 * u, cy - 5 * u), (cx - 3 * u, cy - 5 * u)])
    }
    Book => {
      let u = s / 9.0
      icon_outline(p, [(cx - 7 * u, cy - 8 * u), (cx + 7 * u, cy - 8 * u), (cx + 7 * u, cy + 8 * u), (cx - 7 * u, cy + 8 * u)])
      icon_line(p, cx - 3.5 * u, cy - 8 * u, cx - 3.5 * u, cy + 8 * u)
    }
    Bookmark => {
      let u = s / 9.0
      icon_outline(p, [(cx - 5 * u, cy - 8 * u), (cx + 5 * u, cy - 8 * u), (cx + 5 * u, cy + 8 * u), (cx, cy + 4 * u), (cx - 5 * u, cy + 8 * u)])
    }
    FileCode => {
      let u = s / 9.0
      icon_outline(p, [(cx - 5 * u, cy - 9 * u), (cx + u, cy - 9 * u), (cx + 5 * u, cy - 5 * u), (cx + 5 * u, cy + 9 * u), (cx - 5 * u, cy + 9 * u)])
      icon_polyline(p, [(cx + u, cy - 9 * u), (cx + u, cy - 5 * u), (cx + 5 * u, cy - 5 * u)])
      icon_polyline(p, [(cx - 0.5 * u, cy - 1.5 * u), (cx - 2.5 * u, cy + 0.5 * u), (cx - 0.5 * u, cy + 2.5 * u)])
      icon_polyline(p, [(cx + 0.5 * u, cy - 1.5 * u), (cx + 2.5 * u, cy + 0.5 * u), (cx + 0.5 * u, cy + 2.5 * u)])
    }
    // —— 编辑 ——
    Undo => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 3 * u, cy + 2 * u), (cx - 7 * u, cy - 2 * u), (cx - 3 * u, cy - 6 * u)])
      icon_line(p, cx - 7 * u, cy - 2 * u, cx + 4 * u, cy - 2 * u)
      icon_arc(p, cx + 4 * u, cy + 2 * u, 4 * u, -1.5708, 1.5708)
    }
    Redo => {
      let u = s / 9.0
      icon_polyline(p, [(cx + 3 * u, cy + 2 * u), (cx + 7 * u, cy - 2 * u), (cx + 3 * u, cy - 6 * u)])
      icon_line(p, cx + 7 * u, cy - 2 * u, cx - 4 * u, cy - 2 * u)
      icon_arc(p, cx - 4 * u, cy + 2 * u, 4 * u, 1.5708, -1.5708, ccw=true)
    }
    Scissors => {
      let u = s / 9.0
      icon_circle(p, cx - 6 * u, cy - 6 * u, 2.2 * u)
      icon_circle(p, cx - 6 * u, cy + 6 * u, 2.2 * u)
      icon_line(p, cx - 4.2 * u, cy - 4.7 * u, cx + 8 * u, cy + 8 * u)
      icon_line(p, cx - 4.2 * u, cy + 4.7 * u, cx + 8 * u, cy - 8 * u)
      icon_line(p, cx - 4.8 * u, cy - 2 * u, cx - 1 * u, cy + 0.5 * u)
    }
    Paste => {
      let u = s / 9.0
      icon_outline(p, [(cx - 3 * u, cy - 5 * u), (cx - 6 * u, cy - 5 * u), (cx - 6 * u, cy + 9 * u), (cx + 6 * u, cy + 9 * u), (cx + 6 * u, cy - 5 * u), (cx + 3 * u, cy - 5 * u)])
      icon_outline(p, [(cx - 3 * u, cy - 8 * u), (cx + 3 * u, cy - 8 * u), (cx + 3 * u, cy - 5 * u), (cx - 3 * u, cy - 5 * u)])
      icon_line(p, cx - 3.5 * u, cy - 1 * u, cx + 3.5 * u, cy - 1 * u)
      icon_line(p, cx - 3.5 * u, cy + 2 * u, cx + 3.5 * u, cy + 2 * u)
    }
    Bold => {
      let u = s / 9.0
      icon_outline(p, [(cx - 5 * u, cy - 7 * u), (cx + 1 * u, cy - 7 * u), (cx + 1 * u, cy), (cx - 5 * u, cy)])
      icon_outline(p, [(cx - 5 * u, cy), (cx + 2.5 * u, cy), (cx + 2.5 * u, cy + 7 * u), (cx - 5 * u, cy + 7 * u)])
      icon_line(p, cx - 5 * u, cy - 7 * u, cx - 5 * u, cy + 7 * u)
    }
    Italic => {
      let u = s / 9.0
      icon_line(p, cx - 2 * u, cy - 7 * u, cx + 4 * u, cy - 7 * u)
      icon_line(p, cx - 4 * u, cy + 7 * u, cx + 2 * u, cy + 7 * u)
      icon_line(p, cx + 2 * u, cy - 7 * u, cx - 2 * u, cy + 7 * u)
    }
    Underline => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 5 * u, cy - 8 * u), (cx - 5 * u, cy + 0.5 * u), (cx - 3 * u, cy + 3.5 * u), (cx, cy + 4.5 * u), (cx + 3 * u, cy + 3.5 * u), (cx + 5 * u, cy + 0.5 * u), (cx + 5 * u, cy - 8 * u)])
      icon_line(p, cx - 6 * u, cy + 8 * u, cx + 6 * u, cy + 8 * u)
    }
    AlignLeft => {
      let u = s / 9.0
      icon_line(p, cx - 8 * u, cy - 6 * u, cx + 8 * u, cy - 6 * u)
      icon_line(p, cx - 8 * u, cy, cx + 2 * u, cy)
      icon_line(p, cx - 8 * u, cy + 6 * u, cx + 5 * u, cy + 6 * u)
    }
    AlignCenter => {
      let u = s / 9.0
      icon_line(p, cx - 7 * u, cy - 6 * u, cx + 7 * u, cy - 6 * u)
      icon_line(p, cx - 5 * u, cy, cx + 5 * u, cy)
      icon_line(p, cx - 8 * u, cy + 6 * u, cx + 8 * u, cy + 6 * u)
    }
    AlignRight => {
      let u = s / 9.0
      icon_line(p, cx - 8 * u, cy - 6 * u, cx + 8 * u, cy - 6 * u)
      icon_line(p, cx - 2 * u, cy, cx + 8 * u, cy)
      icon_line(p, cx - 5 * u, cy + 6 * u, cx + 8 * u, cy + 6 * u)
    }
    ListUl => {
      let u = s / 9.0
      p.set_fill_color(color)
      icon_dot(p, cx - 7 * u, cy - 6 * u, 1.1 * u)
      icon_dot(p, cx - 7 * u, cy, 1.1 * u)
      icon_dot(p, cx - 7 * u, cy + 6 * u, 1.1 * u)
      icon_line(p, cx - 3 * u, cy - 6 * u, cx + 8 * u, cy - 6 * u)
      icon_line(p, cx - 3 * u, cy, cx + 8 * u, cy)
      icon_line(p, cx - 3 * u, cy + 6 * u, cx + 8 * u, cy + 6 * u)
    }
    ListOl => {
      let u = s / 9.0
      icon_line(p, cx - 8 * u, cy - 7 * u, cx - 5.5 * u, cy - 7 * u)
      icon_line(p, cx - 5.5 * u, cy - 7 * u, cx - 5.5 * u, cy - 4.5 * u)
      icon_line(p, cx - 8 * u, cy - 1 * u, cx - 8.5 * u, cy + 0.5 * u)
      icon_line(p, cx - 8 * u, cy - 1 * u, cx - 6 * u, cy - 1 * u)
      icon_line(p, cx - 6 * u, cy - 1 * u, cx - 6 * u, cy + 1.5 * u)
      icon_line(p, cx - 8 * u, cy + 6 * u, cx - 5.5 * u, cy + 6 * u)
      icon_line(p, cx - 3 * u, cy - 6 * u, cx + 8 * u, cy - 6 * u)
      icon_line(p, cx - 3 * u, cy, cx + 8 * u, cy)
      icon_line(p, cx - 3 * u, cy + 6 * u, cx + 8 * u, cy + 6 * u)
    }
    Link => {
      let u = s / 9.0
      icon_line(p, cx - 3 * u, cy + 3 * u, cx + 3 * u, cy - 3 * u)
      icon_outline(p, [(cx - 8 * u, cy - 2 * u), (cx - 4 * u, cy - 6 * u), (cx, cy - 2 * u), (cx - 4 * u, cy + 2 * u)])
      icon_outline(p, [(cx, cy + 2 * u), (cx + 4 * u, cy - 2 * u), (cx + 8 * u, cy + 2 * u), (cx + 4 * u, cy + 6 * u)])
    }
    Unlink => {
      let u = s / 9.0
      icon_outline(p, [(cx - 9 * u, cy - 3 * u), (cx - 5 * u, cy - 7 * u), (cx - 1 * u, cy - 3 * u), (cx - 5 * u, cy + 1 * u)])
      icon_outline(p, [(cx + 1 * u, cy + 3 * u), (cx + 5 * u, cy - 1 * u), (cx + 9 * u, cy + 3 * u), (cx + 5 * u, cy + 7 * u)])
      icon_line(p, cx - 3 * u, cy + 3 * u, cx - 1.5 * u, cy + 1.5 * u)
      icon_line(p, cx + 1.5 * u, cy - 1.5 * u, cx + 3 * u, cy - 3 * u)
      icon_line(p, cx - 8 * u, cy + 8 * u, cx - 6 * u, cy + 6 * u)
      icon_line(p, cx + 6 * u, cy - 6 * u, cx + 8 * u, cy - 8 * u)
    }
    ExternalLink => {
      let u = s / 9.0
      icon_outline(p, [(cx + 2 * u, cy - 7 * u), (cx - 7 * u, cy - 7 * u), (cx - 7 * u, cy + 7 * u), (cx + 7 * u, cy + 7 * u), (cx + 7 * u, cy - 2 * u)])
      icon_polyline(p, [(cx + 2 * u, cy - 2 * u), (cx + 7 * u, cy - 7 * u)])
      icon_line(p, cx + 3.5 * u, cy - 7 * u, cx + 7 * u, cy - 7 * u)
      icon_line(p, cx + 7 * u, cy - 7 * u, cx + 7 * u, cy - 3.5 * u)
    }
    // —— 视图 ——
    ZoomIn => {
      let u = s / 9.0
      icon_circle(p, cx - 2 * u, cy - 2 * u, 6 * u)
      icon_line(p, cx + 2.5 * u, cy + 2.5 * u, cx + 8 * u, cy + 8 * u)
      icon_line(p, cx - 4.5 * u, cy - 2 * u, cx + 0.5 * u, cy - 2 * u)
      icon_line(p, cx - 2 * u, cy - 4.5 * u, cx - 2 * u, cy + 0.5 * u)
    }
    ZoomOut => {
      let u = s / 9.0
      icon_circle(p, cx - 2 * u, cy - 2 * u, 6 * u)
      icon_line(p, cx + 2.5 * u, cy + 2.5 * u, cx + 8 * u, cy + 8 * u)
      icon_line(p, cx - 4.5 * u, cy - 2 * u, cx + 0.5 * u, cy - 2 * u)
    }
    Eye => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 9.5 * u, cy), (cx - 6 * u, cy - 4 * u), (cx - 3 * u, cy - 5.5 * u), (cx, cy - 6 * u), (cx + 3 * u, cy - 5.5 * u), (cx + 6 * u, cy - 4 * u), (cx + 9.5 * u, cy)])
      icon_polyline(p, [(cx - 9.5 * u, cy), (cx - 6 * u, cy + 4 * u), (cx - 3 * u, cy + 5.5 * u), (cx, cy + 6 * u), (cx + 3 * u, cy + 5.5 * u), (cx + 6 * u, cy + 4 * u), (cx + 9.5 * u, cy)])
      icon_circle(p, cx, cy, 2.8 * u)
    }
    EyeOff => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 6 * u, cy - 4 * u), (cx - 3 * u, cy - 5.5 * u), (cx, cy - 6 * u), (cx + 3 * u, cy - 5.5 * u), (cx + 6 * u, cy - 4 * u)])
      icon_polyline(p, [(cx + 9.5 * u, cy), (cx + 6 * u, cy + 4 * u), (cx + 3 * u, cy + 5.5 * u), (cx, cy + 6 * u), (cx - 3 * u, cy + 5.5 * u), (cx - 6 * u, cy + 4 * u), (cx - 9.5 * u, cy)])
      icon_line(p, cx - 8 * u, cy - 8 * u, cx + 8 * u, cy + 8 * u)
    }
    Sun => {
      let u = s / 9.0
      icon_circle(p, cx, cy, 4 * u)
      for (dx, dy, ex, ey) in [
        (0.0, -4.0, 0.0, -7.5), (0.0, 4.0, 0.0, 7.5), (-4.0, 0.0, -7.5, 0.0), (4.0, 0.0, 7.5, 0.0),
        (-3.0, -3.0, -5.5, -5.5), (3.0, 3.0, 5.5, 5.5), (-3.0, 3.0, -5.5, 5.5), (3.0, -3.0, 5.5, -5.5),
      ] {
        icon_line(p, cx + dx * u, cy + dy * u, cx + ex * u, cy + ey * u)
      }
    }
    Moon => {
      let u = s / 9.0
      p.set_fill_color(color)
      icon_polygon(p, [
        (cx + 6 * u, cy - 7.5 * u), (cx + 1 * u, cy - 6.5 * u), (cx - 2.5 * u, cy - 3 * u), (cx - 3.5 * u, cy + 1.5 * u), (cx - 1.5 * u, cy + 5.5 * u), (cx + 2.5 * u, cy + 7.5 * u), (cx + 6 * u, cy + 7.5 * u), (cx + 1.5 * u, cy + 6.5 * u), (cx - 1.5 * u, cy + 3 * u), (cx - 2 * u, cy - 1 * u), (cx - 0.5 * u, cy - 5 * u), (cx + 2.5 * u, cy - 7.5 * u),
      ])
    }
    Grid => {
      let u = s / 9.0
      icon_outline(p, [(cx - 8 * u, cy - 8 * u), (cx + 8 * u, cy - 8 * u), (cx + 8 * u, cy + 8 * u), (cx - 8 * u, cy + 8 * u)])
      icon_line(p, cx - 2.7 * u, cy - 8 * u, cx - 2.7 * u, cy + 8 * u)
      icon_line(p, cx + 2.7 * u, cy - 8 * u, cx + 2.7 * u, cy + 8 * u)
      icon_line(p, cx - 8 * u, cy - 2.7 * u, cx + 8 * u, cy - 2.7 * u)
      icon_line(p, cx - 8 * u, cy + 2.7 * u, cx + 8 * u, cy + 2.7 * u)
    }
    Layout => {
      let u = s / 9.0
      icon_outline(p, [(cx - 8 * u, cy - 8 * u), (cx + 8 * u, cy - 8 * u), (cx + 8 * u, cy + 8 * u), (cx - 8 * u, cy + 8 * u)])
      icon_line(p, cx - 8 * u, cy - 3 * u, cx + 8 * u, cy - 3 * u)
      icon_line(p, cx - 2 * u, cy - 3 * u, cx - 2 * u, cy + 8 * u)
    }
    Sidebar => {
      let u = s / 9.0
      icon_outline(p, [(cx - 8 * u, cy - 8 * u), (cx + 8 * u, cy - 8 * u), (cx + 8 * u, cy + 8 * u), (cx - 8 * u, cy + 8 * u)])
      icon_line(p, cx + 2 * u, cy - 8 * u, cx + 2 * u, cy + 8 * u)
    }
    // —— 导航 ——
    ChevronsLeft => {
      let u = s / 9.0
      icon_polyline(p, [(cx - u, cy - 5 * u), (cx - 6 * u, cy), (cx - u, cy + 5 * u)])
      icon_polyline(p, [(cx + 6 * u, cy - 5 * u), (cx + u, cy), (cx + 6 * u, cy + 5 * u)])
    }
    ChevronsRight => {
      let u = s / 9.0
      icon_polyline(p, [(cx + u, cy - 5 * u), (cx + 6 * u, cy), (cx + u, cy + 5 * u)])
      icon_polyline(p, [(cx - 6 * u, cy - 5 * u), (cx - u, cy), (cx - 6 * u, cy + 5 * u)])
    }
    ChevronsUp => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 5 * u, cy - u), (cx, cy - 6 * u), (cx + 5 * u, cy - u)])
      icon_polyline(p, [(cx - 5 * u, cy + 6 * u), (cx, cy + u), (cx + 5 * u, cy + 6 * u)])
    }
    ChevronsDown => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 5 * u, cy + u), (cx, cy + 6 * u), (cx + 5 * u, cy + u)])
      icon_polyline(p, [(cx - 5 * u, cy - 6 * u), (cx, cy - u), (cx + 5 * u, cy - 6 * u)])
    }
    SkipBack => {
      let u = s / 9.0
      p.set_fill_color(color)
      icon_polygon(p, [(cx - 6 * u, cy - 7 * u), (cx - 4 * u, cy - 7 * u), (cx - 4 * u, cy + 7 * u), (cx - 6 * u, cy + 7 * u)])
      icon_polygon(p, [(cx + 6 * u, cy - 7 * u), (cx - 3 * u, cy), (cx + 6 * u, cy + 7 * u)])
    }
    SkipForward => {
      let u = s / 9.0
      p.set_fill_color(color)
      icon_polygon(p, [(cx + 4 * u, cy - 7 * u), (cx + 6 * u, cy - 7 * u), (cx + 6 * u, cy + 7 * u), (cx + 4 * u, cy + 7 * u)])
      icon_polygon(p, [(cx - 6 * u, cy - 7 * u), (cx + 3 * u, cy), (cx - 6 * u, cy + 7 * u)])
    }
    CornerUpLeft => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 3 * u, cy + 2 * u), (cx - 8 * u, cy - 3 * u), (cx - 3 * u, cy - 8 * u)])
      icon_polyline(p, [(cx - 8 * u, cy - 3 * u), (cx + 8 * u, cy - 3 * u), (cx + 8 * u, cy + 8 * u)])
    }
    CornerUpRight => {
      let u = s / 9.0
      icon_polyline(p, [(cx + 3 * u, cy + 2 * u), (cx + 8 * u, cy - 3 * u), (cx + 3 * u, cy - 8 * u)])
      icon_polyline(p, [(cx + 8 * u, cy - 3 * u), (cx - 8 * u, cy - 3 * u), (cx - 8 * u, cy + 8 * u)])
    }
    // —— 媒体 ——
    Square => {
      let u = s / 9.0
      icon_outline(p, [(cx - 6 * u, cy - 6 * u), (cx + 6 * u, cy - 6 * u), (cx + 6 * u, cy + 6 * u), (cx - 6 * u, cy + 6 * u)])
    }
    CircleRecord => {
      let u = s / 9.0
      icon_circle(p, cx, cy, 8 * u)
      p.set_fill_color(color)
      icon_dot(p, cx, cy, 3 * u)
    }
    Volume => {
      let u = s / 9.0
      p.set_fill_color(color)
      icon_polygon(p, [(cx - 8 * u, cy - 3 * u), (cx - 4 * u, cy - 3 * u), (cx + 1 * u, cy - 7 * u), (cx + 1 * u, cy + 7 * u), (cx - 4 * u, cy + 3 * u), (cx - 8 * u, cy + 3 * u)])
      icon_arc(p, cx + 2 * u, cy, 4.5 * u, -0.8, 0.8)
    }
    VolumeOff => {
      let u = s / 9.0
      p.set_fill_color(color)
      icon_polygon(p, [(cx - 8 * u, cy - 3 * u), (cx - 4 * u, cy - 3 * u), (cx + 1 * u, cy - 7 * u), (cx + 1 * u, cy + 7 * u), (cx - 4 * u, cy + 3 * u), (cx - 8 * u, cy + 3 * u)])
      icon_line(p, cx + 5 * u, cy - 2.5 * u, cx + 9 * u, cy + 2.5 * u)
      icon_line(p, cx + 9 * u, cy - 2.5 * u, cx + 5 * u, cy + 2.5 * u)
    }
    Mic => {
      let u = s / 9.0
      icon_outline(p, [(cx - 3 * u, cy - 9 * u), (cx + 3 * u, cy - 9 * u), (cx + 3 * u, cy - 1 * u), (cx - 3 * u, cy - 1 * u)])
      icon_polyline(p, [(cx - 7 * u, cy - 1 * u), (cx - 7 * u, cy + 0.5 * u), (cx - 5 * u, cy + 3.5 * u), (cx, cy + 5 * u), (cx + 5 * u, cy + 3.5 * u), (cx + 7 * u, cy + 0.5 * u), (cx + 7 * u, cy - 1 * u)])
      icon_line(p, cx, cy + 5 * u, cx, cy + 9 * u)
      icon_line(p, cx - 3 * u, cy + 9 * u, cx + 3 * u, cy + 9 * u)
    }
    Camera => {
      let u = s / 9.0
      icon_outline(p, [(cx - 8 * u, cy - 5 * u), (cx - 3 * u, cy - 5 * u), (cx - 1.5 * u, cy - 7 * u), (cx + 1.5 * u, cy - 7 * u), (cx + 3 * u, cy - 5 * u), (cx + 8 * u, cy - 5 * u), (cx + 8 * u, cy + 7 * u), (cx - 8 * u, cy + 7 * u)])
      icon_circle(p, cx, cy + 1 * u, 3.2 * u)
    }
    Image => {
      let u = s / 9.0
      icon_outline(p, [(cx - 8 * u, cy - 8 * u), (cx + 8 * u, cy - 8 * u), (cx + 8 * u, cy + 8 * u), (cx - 8 * u, cy + 8 * u)])
      p.set_fill_color(color)
      icon_dot(p, cx - 3 * u, cy - 2.5 * u, 1.4 * u)
      icon_polyline(p, [(cx - 8 * u, cy + 6 * u), (cx - 2.5 * u, cy + 0.5 * u), (cx + 1 * u, cy + 4 * u), (cx + 3.5 * u, cy + 1.5 * u), (cx + 8 * u, cy + 6 * u)])
    }
    Music => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 3 * u, cy + 6 * u), (cx - 3 * u, cy - 6 * u), (cx + 8 * u, cy - 8 * u), (cx + 8 * u, cy + 4 * u)])
      icon_circle(p, cx - 5.2 * u, cy + 6 * u, 2.2 * u)
      icon_circle(p, cx + 5.8 * u, cy + 4 * u, 2.2 * u)
    }
    // —— 通信 ——
    Mail => {
      let u = s / 9.0
      icon_outline(p, [(cx - 9 * u, cy - 7 * u), (cx + 9 * u, cy - 7 * u), (cx + 9 * u, cy + 7 * u), (cx - 9 * u, cy + 7 * u)])
      icon_polyline(p, [(cx - 9 * u, cy - 6 * u), (cx, cy + 1 * u), (cx + 9 * u, cy - 6 * u)])
    }
    Send => {
      let u = s / 9.0
      icon_outline(p, [(cx + 9 * u, cy - 9 * u), (cx + 2.8 * u, cy + 7.5 * u), (cx - 1 * u, cy), (cx - 8.5 * u, cy - 2.8 * u)])
      icon_line(p, cx + 9 * u, cy - 9 * u, cx - 1 * u, cy)
    }
    MessageCircle => {
      let u = s / 9.0
      icon_circle(p, cx, cy - 0.5 * u, 7.5 * u)
      icon_polyline(p, [(cx - 5 * u, cy + 5.2 * u), (cx - 7.5 * u, cy + 8.5 * u), (cx - 2 * u, cy + 7.6 * u)])
    }
    Bell => {
      let u = s / 9.0
      icon_outline(p, [(cx + 6 * u, cy + 4 * u), (cx - 6 * u, cy + 4 * u), (cx - 6 * u, cy - 2 * u), (cx - 4.5 * u, cy - 6.2 * u), (cx - 2 * u, cy - 7.8 * u), (cx, cy - 8 * u), (cx + 2 * u, cy - 7.8 * u), (cx + 4.5 * u, cy - 6.2 * u), (cx + 6 * u, cy - 2 * u), (cx + 6 * u, cy + 4 * u)])
      icon_line(p, cx - 2.5 * u, cy + 7 * u, cx + 2.5 * u, cy + 7 * u)
    }
    BellOff => {
      let u = s / 9.0
      icon_outline(p, [(cx + 6 * u, cy + 4 * u), (cx - 6 * u, cy + 4 * u), (cx - 6 * u, cy - 2 * u), (cx - 4.5 * u, cy - 6.2 * u), (cx - 2 * u, cy - 7.8 * u), (cx, cy - 8 * u), (cx + 2 * u, cy - 7.8 * u), (cx + 4.5 * u, cy - 6.2 * u), (cx + 6 * u, cy - 2 * u), (cx + 6 * u, cy + 4 * u)])
      icon_line(p, cx - 2.5 * u, cy + 7 * u, cx + 2.5 * u, cy + 7 * u)
      icon_line(p, cx - 8 * u, cy - 8 * u, cx + 8 * u, cy + 8 * u)
    }
    Phone => {
      let u = s / 9.0
      icon_outline(p, [(cx + 7.5 * u, cy + 4 * u), (cx + 7.5 * u, cy + 7 * u), (cx + 5 * u, cy + 8 * u), (cx - 1 * u, cy + 5.5 * u), (cx - 5.5 * u, cy + 1 * u), (cx - 8 * u, cy - 5 * u), (cx - 7 * u, cy - 7.5 * u), (cx - 4 * u, cy - 7.5 * u), (cx - 2.5 * u, cy - 3 * u), (cx - 4 * u, cy - 1.5 * u), (cx + 1.5 * u, cy + 4 * u), (cx + 3 * u, cy + 2.5 * u)])
    }
    Rss => {
      let u = s / 9.0
      p.set_fill_color(color)
      icon_dot(p, cx - 6.5 * u, cy + 6.5 * u, 1.4 * u)
      icon_arc(p, cx - 7 * u, cy + 7 * u, 5 * u, -1.4, -0.1)
      icon_arc(p, cx - 7 * u, cy + 7 * u, 8.5 * u, -1.4, -0.1)
    }
    Globe => {
      let u = s / 9.0
      icon_circle(p, cx, cy, 9 * u)
      icon_line(p, cx - 9 * u, cy, cx + 9 * u, cy)
      icon_polyline(p, [(cx - 3.5 * u, cy - 7 * u), (cx - 5 * u, cy - 3.5 * u), (cx - 5 * u, cy), (cx - 5 * u, cy + 3.5 * u), (cx - 3.5 * u, cy + 7 * u)])
      icon_polyline(p, [(cx + 3.5 * u, cy - 7 * u), (cx + 5 * u, cy - 3.5 * u), (cx + 5 * u, cy), (cx + 5 * u, cy + 3.5 * u), (cx + 3.5 * u, cy + 7 * u)])
      icon_polyline(p, [(cx - 7.5 * u, cy - 3.5 * u), (cx - 3.5 * u, cy - 4.8 * u), (cx, cy - 5 * u), (cx + 3.5 * u, cy - 4.8 * u), (cx + 7.5 * u, cy - 3.5 * u)])
      icon_polyline(p, [(cx - 7.5 * u, cy + 3.5 * u), (cx - 3.5 * u, cy + 4.8 * u), (cx, cy + 5 * u), (cx + 3.5 * u, cy + 4.8 * u), (cx + 7.5 * u, cy + 3.5 * u)])
    }
    // —— 系统 ——
    Power => {
      let u = s / 9.0
      icon_line(p, cx, cy - 9 * u, cx, cy - 1 * u)
      icon_arc(p, cx, cy + 1 * u, 7 * u, -0.55, 3.7)
    }
    LogOut => {
      let u = s / 9.0
      icon_outline(p, [(cx - 4 * u, cy - 8 * u), (cx + 4 * u, cy - 8 * u), (cx + 4 * u, cy + 8 * u), (cx - 4 * u, cy + 8 * u)])
      icon_line(p, cx - 1 * u, cy, cx + 9 * u, cy)
      icon_polyline(p, [(cx + 6 * u, cy - 3.5 * u), (cx + 9 * u, cy), (cx + 6 * u, cy + 3.5 * u)])
    }
    LogIn => {
      let u = s / 9.0
      icon_outline(p, [(cx - 4 * u, cy - 8 * u), (cx + 4 * u, cy - 8 * u), (cx + 4 * u, cy + 8 * u), (cx - 4 * u, cy + 8 * u)])
      icon_line(p, cx - 9 * u, cy, cx + 1 * u, cy)
      icon_polyline(p, [(cx - 2 * u, cy - 3.5 * u), (cx + 1 * u, cy), (cx - 2 * u, cy + 3.5 * u)])
    }
    Lock => {
      let u = s / 9.0
      icon_outline(p, [(cx - 7 * u, cy - 1 * u), (cx + 7 * u, cy - 1 * u), (cx + 7 * u, cy + 9 * u), (cx - 7 * u, cy + 9 * u)])
      icon_arc(p, cx, cy - 1 * u, 4 * u, 3.1416, 6.2832)
      icon_line(p, cx, cy + 3 * u, cx, cy + 5.5 * u)
    }
    Unlock => {
      let u = s / 9.0
      icon_outline(p, [(cx - 7 * u, cy - 1 * u), (cx + 7 * u, cy - 1 * u), (cx + 7 * u, cy + 9 * u), (cx - 7 * u, cy + 9 * u)])
      icon_arc(p, cx - 1 * u, cy - 1 * u, 4 * u, 3.6, 6.2832)
      icon_line(p, cx + 2.2 * u, cy - 4.8 * u, cx + 5.5 * u, cy - 4.8 * u)
    }
    Key => {
      let u = s / 9.0
      icon_circle(p, cx - 5.5 * u, cy + 5.5 * u, 3.2 * u)
      icon_line(p, cx - 3.2 * u, cy + 3.2 * u, cx + 7.5 * u, cy - 7.5 * u)
      icon_line(p, cx + 4.5 * u, cy - 3.5 * u, cx + 7 * u, cy - 1 * u)
      icon_line(p, cx + 7 * u, cy - 5 * u, cx + 9.5 * u, cy - 2.5 * u)
    }
    Shield => {
      let u = s / 9.0
      icon_outline(p, [(cx, cy - 9 * u), (cx + 7 * u, cy - 6 * u), (cx + 7 * u, cy - 1 * u), (cx + 5.5 * u, cy + 4 * u), (cx, cy + 9 * u), (cx - 5.5 * u, cy + 4 * u), (cx - 7 * u, cy - 1 * u), (cx - 7 * u, cy - 6 * u)])
    }
    Sliders => {
      let u = s / 9.0
      p.set_fill_color(color)
      icon_line(p, cx - 8 * u, cy - 5 * u, cx + 8 * u, cy - 5 * u)
      icon_dot(p, cx + 2 * u, cy - 5 * u, 1.8 * u)
      icon_line(p, cx - 8 * u, cy, cx + 8 * u, cy)
      icon_dot(p, cx - 4 * u, cy, 1.8 * u)
      icon_line(p, cx - 8 * u, cy + 5 * u, cx + 8 * u, cy + 5 * u)
      icon_dot(p, cx + 4 * u, cy + 5 * u, 1.8 * u)
    }
    Database => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 7 * u, cy - 6 * u), (cx - 5.5 * u, cy - 4.5 * u), (cx - 2.5 * u, cy - 3.8 * u), (cx, cy - 3.5 * u), (cx + 2.5 * u, cy - 3.8 * u), (cx + 5.5 * u, cy - 4.5 * u), (cx + 7 * u, cy - 6 * u)])
      icon_polyline(p, [(cx - 7 * u, cy + 0.5 * u), (cx - 5.5 * u, cy + 2 * u), (cx - 2.5 * u, cy + 2.7 * u), (cx, cy + 3 * u), (cx + 2.5 * u, cy + 2.7 * u), (cx + 5.5 * u, cy + 2 * u), (cx + 7 * u, cy + 0.5 * u)])
      icon_polyline(p, [(cx - 7 * u, cy + 7 * u), (cx - 5.5 * u, cy + 8.5 * u), (cx - 2.5 * u, cy + 9.2 * u), (cx, cy + 9.5 * u), (cx + 2.5 * u, cy + 9.2 * u), (cx + 5.5 * u, cy + 8.5 * u), (cx + 7 * u, cy + 7 * u)])
      icon_line(p, cx - 7 * u, cy - 6 * u, cx - 7 * u, cy + 7 * u)
      icon_line(p, cx + 7 * u, cy - 6 * u, cx + 7 * u, cy + 7 * u)
    }
    Server => {
      let u = s / 9.0
      icon_outline(p, [(cx - 8 * u, cy - 8 * u), (cx + 8 * u, cy - 8 * u), (cx + 8 * u, cy - 2 * u), (cx - 8 * u, cy - 2 * u)])
      icon_outline(p, [(cx - 8 * u, cy + 2 * u), (cx + 8 * u, cy + 2 * u), (cx + 8 * u, cy + 8 * u), (cx - 8 * u, cy + 8 * u)])
      p.set_fill_color(color)
      icon_dot(p, cx - 5 * u, cy - 5 * u, 0.9 * u)
      icon_dot(p, cx - 5 * u, cy + 5 * u, 0.9 * u)
    }
    HardDrive => {
      let u = s / 9.0
      icon_outline(p, [(cx - 7 * u, cy - 6 * u), (cx + 7 * u, cy - 6 * u), (cx + 9 * u, cy), (cx + 9 * u, cy + 6 * u), (cx - 9 * u, cy + 6 * u), (cx - 9 * u, cy)])
      icon_line(p, cx - 9 * u, cy, cx + 9 * u, cy)
      p.set_fill_color(color)
      icon_dot(p, cx - 5 * u, cy + 3 * u, 0.9 * u)
    }
    Printer => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 3 * u, cy - 7 * u), (cx - 3 * u, cy - 9 * u), (cx + 3 * u, cy - 9 * u), (cx + 3 * u, cy - 7 * u)])
      icon_outline(p, [(cx - 8 * u, cy - 7 * u), (cx + 8 * u, cy - 7 * u), (cx + 8 * u, cy + 2 * u), (cx + 5 * u, cy + 2 * u), (cx + 5 * u, cy), (cx - 5 * u, cy), (cx - 5 * u, cy + 2 * u), (cx - 8 * u, cy + 2 * u)])
      icon_outline(p, [(cx - 5 * u, cy), (cx + 5 * u, cy), (cx + 5 * u, cy + 7 * u), (cx - 5 * u, cy + 7 * u)])
    }
    Monitor => {
      let u = s / 9.0
      icon_outline(p, [(cx - 9 * u, cy - 7 * u), (cx + 9 * u, cy - 7 * u), (cx + 9 * u, cy + 3 * u), (cx - 9 * u, cy + 3 * u)])
      icon_line(p, cx, cy + 3 * u, cx, cy + 7 * u)
      icon_line(p, cx - 4 * u, cy + 7 * u, cx + 4 * u, cy + 7 * u)
    }
    Smartphone => {
      let u = s / 9.0
      icon_outline(p, [(cx - 5 * u, cy - 9 * u), (cx + 5 * u, cy - 9 * u), (cx + 5 * u, cy + 9 * u), (cx - 5 * u, cy + 9 * u)])
      icon_line(p, cx - 1.5 * u, cy + 6 * u, cx + 1.5 * u, cy + 6 * u)
    }
    Wifi => {
      let u = s / 9.0
      icon_arc(p, cx, cy + 8 * u, 4.2 * u, -2.36, -0.78)
      icon_arc(p, cx, cy + 8 * u, 8 * u, -2.36, -0.78)
      p.set_fill_color(color)
      icon_dot(p, cx, cy + 6.5 * u, 1.2 * u)
    }
    WifiOff => {
      let u = s / 9.0
      icon_arc(p, cx, cy + 8 * u, 7 * u, -2.36, -0.78)
      p.set_fill_color(color)
      icon_dot(p, cx, cy + 6.5 * u, 1.1 * u)
      icon_line(p, cx - 8 * u, cy - 8 * u, cx + 8 * u, cy + 8 * u)
    }
    Bluetooth => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 5.5 * u, cy - 5 * u), (cx + 5.5 * u, cy + 4 * u), (cx, cy + 8 * u), (cx, cy - 8 * u), (cx + 5.5 * u, cy - 4 * u), (cx - 5.5 * u, cy + 5 * u)])
    }
    Cpu => {
      let u = s / 9.0
      icon_outline(p, [(cx - 6 * u, cy - 6 * u), (cx + 6 * u, cy - 6 * u), (cx + 6 * u, cy + 6 * u), (cx - 6 * u, cy + 6 * u)])
      icon_outline(p, [(cx - 2.5 * u, cy - 2.5 * u), (cx + 2.5 * u, cy - 2.5 * u), (cx + 2.5 * u, cy + 2.5 * u), (cx - 2.5 * u, cy + 2.5 * u)])
      icon_line(p, cx - 3 * u, cy - 9 * u, cx - 3 * u, cy - 6 * u)
      icon_line(p, cx + 3 * u, cy - 9 * u, cx + 3 * u, cy - 6 * u)
      icon_line(p, cx - 3 * u, cy + 6 * u, cx - 3 * u, cy + 9 * u)
      icon_line(p, cx + 3 * u, cy + 6 * u, cx + 3 * u, cy + 9 * u)
      icon_line(p, cx - 9 * u, cy - 3 * u, cx - 6 * u, cy - 3 * u)
      icon_line(p, cx - 9 * u, cy + 3 * u, cx - 6 * u, cy + 3 * u)
      icon_line(p, cx + 6 * u, cy - 3 * u, cx + 9 * u, cy - 3 * u)
      icon_line(p, cx + 6 * u, cy + 3 * u, cx + 9 * u, cy + 3 * u)
    }
    // —— 开发 ——
    Terminal => {
      let u = s / 9.0
      icon_outline(p, [(cx - 9 * u, cy - 8 * u), (cx + 9 * u, cy - 8 * u), (cx + 9 * u, cy + 8 * u), (cx - 9 * u, cy + 8 * u)])
      icon_polyline(p, [(cx - 5 * u, cy - 3 * u), (cx - 2 * u, cy), (cx - 5 * u, cy + 3 * u)])
      icon_line(p, cx - 1 * u, cy + 3 * u, cx + 4 * u, cy + 3 * u)
    }
    Code => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 3.5 * u, cy - 5 * u), (cx - 8.5 * u, cy), (cx - 3.5 * u, cy + 5 * u)])
      icon_polyline(p, [(cx + 3.5 * u, cy - 5 * u), (cx + 8.5 * u, cy), (cx + 3.5 * u, cy + 5 * u)])
    }
    GitBranch => {
      let u = s / 9.0
      icon_circle(p, cx - 6 * u, cy - 6.5 * u, 2 * u)
      icon_circle(p, cx - 6 * u, cy + 6.5 * u, 2 * u)
      icon_circle(p, cx + 5 * u, cy - 5 * u, 2 * u)
      icon_line(p, cx - 6 * u, cy - 4.5 * u, cx - 6 * u, cy + 4.5 * u)
      icon_polyline(p, [(cx + 5 * u, cy - 3 * u), (cx + 5 * u, cy + 0.5 * u), (cx + 1 * u, cy + 2 * u), (cx - 6 * u, cy + 2.2 * u)])
    }
    GitCommit => {
      let u = s / 9.0
      icon_circle(p, cx, cy, 3.2 * u)
      icon_line(p, cx - 9 * u, cy, cx - 3.2 * u, cy)
      icon_line(p, cx + 3.2 * u, cy, cx + 9 * u, cy)
    }
    GitPullRequest => {
      let u = s / 9.0
      icon_circle(p, cx - 6 * u, cy - 6.5 * u, 2 * u)
      icon_circle(p, cx - 6 * u, cy + 6.5 * u, 2 * u)
      icon_circle(p, cx + 6 * u, cy + 6.5 * u, 2 * u)
      icon_line(p, cx - 6 * u, cy - 4.5 * u, cx - 6 * u, cy + 4.5 * u)
      icon_polyline(p, [(cx + 1 * u, cy - 4.5 * u), (cx + 3.5 * u, cy - 7 * u), (cx + 6 * u, cy - 4.5 * u)])
      icon_line(p, cx + 3.5 * u, cy - 7 * u, cx + 3.5 * u, cy + 4.5 * u)
    }
    Package => {
      let u = s / 9.0
      icon_outline(p, [(cx, cy - 9 * u), (cx + 8 * u, cy - 4.5 * u), (cx + 8 * u, cy + 4.5 * u), (cx, cy + 9 * u), (cx - 8 * u, cy + 4.5 * u), (cx - 8 * u, cy - 4.5 * u)])
      icon_polyline(p, [(cx - 8 * u, cy - 4.5 * u), (cx, cy), (cx + 8 * u, cy - 4.5 * u)])
      icon_line(p, cx, cy, cx, cy + 9 * u)
      icon_polyline(p, [(cx - 4 * u, cy - 6.7 * u), (cx + 4 * u, cy - 2.2 * u)])
    }
    Bug => {
      let u = s / 9.0
      icon_outline(p, [(cx - 3 * u, cy - 4 * u), (cx + 3 * u, cy - 4 * u), (cx + 4 * u, cy + 0.5 * u), (cx + 2 * u, cy + 5.5 * u), (cx + 2 * u, cy + 8 * u), (cx - 2 * u, cy + 8 * u), (cx - 2 * u, cy + 5.5 * u), (cx - 4 * u, cy + 0.5 * u)])
      icon_polyline(p, [(cx - 3 * u, cy - 7 * u), (cx - 1.5 * u, cy - 5.5 * u), (cx + 1.5 * u, cy - 5.5 * u), (cx + 3 * u, cy - 7 * u)])
      icon_line(p, cx - 8 * u, cy - 1 * u, cx - 4.5 * u, cy - 0.5 * u)
      icon_line(p, cx - 8 * u, cy + 2.5 * u, cx - 4.5 * u, cy + 2.5 * u)
      icon_line(p, cx - 7 * u, cy + 5.5 * u, cx - 4.2 * u, cy + 4 * u)
      icon_line(p, cx + 8 * u, cy - 1 * u, cx + 4.5 * u, cy - 0.5 * u)
      icon_line(p, cx + 8 * u, cy + 2.5 * u, cx + 4.5 * u, cy + 2.5 * u)
      icon_line(p, cx + 7 * u, cy + 5.5 * u, cx + 4.2 * u, cy + 4 * u)
    }
    Flask => {
      let u = s / 9.0
      icon_outline(p, [(cx - 2 * u, cy - 9 * u), (cx + 2 * u, cy - 9 * u), (cx + 2 * u, cy - 2 * u), (cx + 6.5 * u, cy + 6 * u), (cx + 5 * u, cy + 8 * u), (cx - 5 * u, cy + 8 * u), (cx - 6.5 * u, cy + 6 * u), (cx - 2 * u, cy - 2 * u)])
      icon_line(p, cx - 5 * u, cy + 3 * u, cx + 5 * u, cy + 3 * u)
    }
    Cloud => {
      let u = s / 9.0
      icon_outline(p, [(cx - 6.5 * u, cy + 5 * u), (cx - 8 * u, cy + 3.5 * u), (cx - 8 * u, cy + 0.5 * u), (cx - 6.5 * u, cy - 1.5 * u), (cx - 4.5 * u, cy - 2.2 * u), (cx - 3 * u, cy - 1.5 * u), (cx - 2 * u, cy - 3.5 * u), (cx - 0.5 * u, cy - 4.5 * u), (cx + 1.5 * u, cy - 4.5 * u), (cx + 3.5 * u, cy - 3.5 * u), (cx + 4.5 * u, cy - 1.5 * u), (cx + 6 * u, cy - 1 * u), (cx + 7 * u, cy + 0.5 * u), (cx + 7 * u, cy + 2.5 * u), (cx + 5.5 * u, cy + 4.5 * u), (cx + 4 * u, cy + 5 * u)])
    }
    CloudDownload => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 6 * u, cy - 3 * u), (cx - 7.5 * u, cy - 4.5 * u), (cx - 7.5 * u, cy - 7 * u), (cx - 6 * u, cy - 8.5 * u), (cx - 4.5 * u, cy - 9 * u), (cx - 3.5 * u, cy - 9.8 * u), (cx - 2 * u, cy - 10.5 * u), (cx - 0.5 * u, cy - 10.5 * u), (cx + 1 * u, cy - 9.5 * u), (cx + 2 * u, cy - 8 * u), (cx + 3.5 * u, cy - 7.5 * u), (cx + 4.5 * u, cy - 6 * u), (cx + 4.5 * u, cy - 4.5 * u), (cx + 3.5 * u, cy - 3 * u)])
      icon_line(p, cx, cy - 2 * u, cx, cy + 7 * u)
      icon_polyline(p, [(cx - 3.5 * u, cy + 3.5 * u), (cx, cy + 7 * u), (cx + 3.5 * u, cy + 3.5 * u)])
    }
    CloudUpload => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 6 * u, cy - 3 * u), (cx - 7.5 * u, cy - 4.5 * u), (cx - 7.5 * u, cy - 7 * u), (cx - 6 * u, cy - 8.5 * u), (cx - 4.5 * u, cy - 9 * u), (cx - 3.5 * u, cy - 9.8 * u), (cx - 2 * u, cy - 10.5 * u), (cx - 0.5 * u, cy - 10.5 * u), (cx + 1 * u, cy - 9.5 * u), (cx + 2 * u, cy - 8 * u), (cx + 3.5 * u, cy - 7.5 * u), (cx + 4.5 * u, cy - 6 * u), (cx + 4.5 * u, cy - 4.5 * u), (cx + 3.5 * u, cy - 3 * u)])
      icon_line(p, cx, cy + 7 * u, cx, cy - 2 * u)
      icon_polyline(p, [(cx - 3.5 * u, cy + 1.5 * u), (cx, cy - 2 * u), (cx + 3.5 * u, cy + 1.5 * u)])
    }
    Layers => {
      let u = s / 9.0
      icon_outline(p, [(cx, cy - 9 * u), (cx + 9 * u, cy - 4 * u), (cx, cy + 1 * u), (cx - 9 * u, cy - 4 * u)])
      icon_polyline(p, [(cx - 9 * u, cy), (cx, cy + 5 * u), (cx + 9 * u, cy)])
      icon_polyline(p, [(cx - 9 * u, cy + 4 * u), (cx, cy + 9 * u), (cx + 9 * u, cy + 4 * u)])
    }
    Zap => {
      let u = s / 9.0
      p.set_fill_color(color)
      icon_polygon(p, [(cx + 1 * u, cy - 9 * u), (cx - 7 * u, cy + 2 * u), (cx - 1 * u, cy + 2 * u), (cx - 1 * u, cy + 9 * u), (cx + 7 * u, cy - 2 * u), (cx + 1 * u, cy - 2 * u)])
    }
    // —— 语义/状态 ——
    Help => {
      let u = s / 9.0
      icon_circle(p, cx, cy, 9 * u)
      icon_polyline(p, [(cx - 2.5 * u, cy - 2.5 * u), (cx - 2 * u, cy - 4 * u), (cx - 0.5 * u, cy - 4.5 * u), (cx + 1 * u, cy - 4 * u), (cx + 1.5 * u, cy - 2.5 * u), (cx + 0.5 * u, cy - 1 * u), (cx, cy + 0.5 * u), (cx, cy + 1.5 * u)])
      p.set_fill_color(color)
      icon_dot(p, cx, cy + 4.5 * u, 1 * u)
    }
    Heart => {
      let u = s / 9.0
      icon_outline(p, [(cx, cy + 8 * u), (cx - 8 * u, cy + 0.5 * u), (cx - 9 * u, cy - 2.5 * u), (cx - 8 * u, cy - 5.5 * u), (cx - 5 * u, cy - 7.5 * u), (cx - 2 * u, cy - 7 * u), (cx, cy - 5 * u), (cx + 2 * u, cy - 7 * u), (cx + 5 * u, cy - 7.5 * u), (cx + 8 * u, cy - 5.5 * u), (cx + 9 * u, cy - 2.5 * u), (cx + 8 * u, cy + 0.5 * u)])
    }
    Flag => {
      let u = s / 9.0
      icon_line(p, cx - 7 * u, cy - 9 * u, cx - 7 * u, cy + 9 * u)
      icon_outline(p, [(cx - 7 * u, cy - 8 * u), (cx + 6 * u, cy - 8 * u), (cx + 3.5 * u, cy - 4 * u), (cx + 6 * u, cy), (cx - 7 * u, cy)])
    }
    Clock => {
      let u = s / 9.0
      icon_circle(p, cx, cy, 9 * u)
      icon_polyline(p, [(cx, cy - 5 * u), (cx, cy), (cx + 3.5 * u, cy + 2 * u)])
    }
    Tag => {
      let u = s / 9.0
      icon_outline(p, [(cx - 9 * u, cy), (cx, cy - 9 * u), (cx + 8 * u, cy - 9 * u), (cx + 8 * u, cy + 1 * u), (cx - 1 * u, cy + 9 * u)])
      p.set_fill_color(color)
      icon_dot(p, cx + 4 * u, cy - 4 * u, 1.2 * u)
    }
    Archive => {
      let u = s / 9.0
      icon_outline(p, [(cx - 9 * u, cy - 8 * u), (cx + 9 * u, cy - 8 * u), (cx + 9 * u, cy - 3 * u), (cx - 9 * u, cy - 3 * u)])
      icon_outline(p, [(cx - 7 * u, cy - 3 * u), (cx + 7 * u, cy - 3 * u), (cx + 7 * u, cy + 8 * u), (cx - 7 * u, cy + 8 * u)])
      icon_line(p, cx - 2 * u, cy + 1 * u, cx + 2 * u, cy + 1 * u)
    }
    Inbox => {
      let u = s / 9.0
      icon_outline(p, [(cx - 8 * u, cy - 7 * u), (cx + 8 * u, cy - 7 * u), (cx + 8 * u, cy + 7 * u), (cx - 8 * u, cy + 7 * u)])
      icon_polyline(p, [(cx - 8 * u, cy + 1 * u), (cx - 3 * u, cy + 1 * u), (cx - 2 * u, cy + 3 * u), (cx + 2 * u, cy + 3 * u), (cx + 3 * u, cy + 1 * u), (cx + 8 * u, cy + 1 * u)])
    }
    ThumbsUp => {
      let u = s / 9.0
      icon_outline(p, [(cx - 5 * u, cy - 1 * u), (cx - 5 * u, cy + 9 * u), (cx - 8 * u, cy + 9 * u), (cx - 8 * u, cy - 1 * u)])
      icon_polyline(p, [(cx - 5 * u, cy - 1 * u), (cx - 0.5 * u, cy - 7.5 * u), (cx + 1 * u, cy - 7 * u), (cx + 0.5 * u, cy - 3 * u), (cx + 6.5 * u, cy - 3 * u), (cx + 8 * u, cy - 1.5 * u), (cx + 7 * u, cy + 7.5 * u), (cx - 5 * u, cy + 9 * u)])
    }
    // —— 数据 ——
    TrendingUp => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 9 * u, cy + 5 * u), (cx - 3 * u, cy - 1 * u), (cx + 1 * u, cy + 3 * u), (cx + 9 * u, cy - 5 * u)])
      icon_polyline(p, [(cx + 3 * u, cy - 5 * u), (cx + 9 * u, cy - 5 * u), (cx + 9 * u, cy + 1 * u)])
    }
    TrendingDown => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 9 * u, cy - 5 * u), (cx - 3 * u, cy + 1 * u), (cx + 1 * u, cy - 3 * u), (cx + 9 * u, cy + 5 * u)])
      icon_polyline(p, [(cx + 3 * u, cy + 5 * u), (cx + 9 * u, cy + 5 * u), (cx + 9 * u, cy - 1 * u)])
    }
    BarChart => {
      let u = s / 9.0
      icon_outline(p, [(cx - 7 * u, cy - 1 * u), (cx - 4 * u, cy - 1 * u), (cx - 4 * u, cy + 8 * u), (cx - 7 * u, cy + 8 * u)])
      icon_outline(p, [(cx - 1.5 * u, cy - 8 * u), (cx + 1.5 * u, cy - 8 * u), (cx + 1.5 * u, cy + 8 * u), (cx - 1.5 * u, cy + 8 * u)])
      icon_outline(p, [(cx + 4 * u, cy - 4 * u), (cx + 7 * u, cy - 4 * u), (cx + 7 * u, cy + 8 * u), (cx + 4 * u, cy + 8 * u)])
    }
    PieChart => {
      let u = s / 9.0
      icon_circle(p, cx, cy, 9 * u)
      icon_line(p, cx, cy - 9 * u, cx, cy)
      icon_line(p, cx, cy, cx + 8 * u, cy + 4 * u)
    }
    TableRows => {
      let u = s / 9.0
      icon_outline(p, [(cx - 8 * u, cy - 8 * u), (cx + 8 * u, cy - 8 * u), (cx + 8 * u, cy + 8 * u), (cx - 8 * u, cy + 8 * u)])
      icon_line(p, cx - 8 * u, cy - 2.5 * u, cx + 8 * u, cy - 2.5 * u)
      icon_line(p, cx - 8 * u, cy + 3 * u, cx + 8 * u, cy + 3 * u)
    }
  }
}

///|
/// 全部图标种类清单(137 项,图标墙/选取器素材)。
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
    FilePlus,
    FolderOpen,
    FolderPlus,
    Clipboard,
    Book,
    Bookmark,
    FileCode,
    Undo,
    Redo,
    Scissors,
    Paste,
    Bold,
    Italic,
    Underline,
    AlignLeft,
    AlignCenter,
    AlignRight,
    ListUl,
    ListOl,
    Link,
    Unlink,
    ExternalLink,
    ZoomIn,
    ZoomOut,
    Eye,
    EyeOff,
    Sun,
    Moon,
    Grid,
    Layout,
    Sidebar,
    ChevronsLeft,
    ChevronsRight,
    ChevronsUp,
    ChevronsDown,
    SkipBack,
    SkipForward,
    CornerUpLeft,
    CornerUpRight,
    Square,
    CircleRecord,
    Volume,
    VolumeOff,
    Mic,
    Camera,
    Image,
    Music,
    Mail,
    Send,
    MessageCircle,
    Bell,
    BellOff,
    Phone,
    Rss,
    Globe,
    Power,
    LogOut,
    LogIn,
    Lock,
    Unlock,
    Key,
    Shield,
    Sliders,
    Database,
    Server,
    HardDrive,
    Printer,
    Monitor,
    Smartphone,
    Wifi,
    WifiOff,
    Bluetooth,
    Cpu,
    Terminal,
    Code,
    GitBranch,
    GitCommit,
    GitPullRequest,
    Package,
    Bug,
    Flask,
    Cloud,
    CloudDownload,
    CloudUpload,
    Layers,
    Zap,
    Help,
    Heart,
    Flag,
    Clock,
    Tag,
    Archive,
    Inbox,
    ThumbsUp,
    TrendingUp,
    TrendingDown,
    BarChart,
    PieChart,
    TableRows,
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
    FilePlus => "FilePlus"
    FolderOpen => "FolderOpen"
    FolderPlus => "FolderPlus"
    Clipboard => "Clipboard"
    Book => "Book"
    Bookmark => "Bookmark"
    FileCode => "FileCode"
    Undo => "Undo"
    Redo => "Redo"
    Scissors => "Scissors"
    Paste => "Paste"
    Bold => "Bold"
    Italic => "Italic"
    Underline => "Underline"
    AlignLeft => "AlignLeft"
    AlignCenter => "AlignCenter"
    AlignRight => "AlignRight"
    ListUl => "ListUl"
    ListOl => "ListOl"
    Link => "Link"
    Unlink => "Unlink"
    ExternalLink => "ExternalLink"
    ZoomIn => "ZoomIn"
    ZoomOut => "ZoomOut"
    Eye => "Eye"
    EyeOff => "EyeOff"
    Sun => "Sun"
    Moon => "Moon"
    Grid => "Grid"
    Layout => "Layout"
    Sidebar => "Sidebar"
    ChevronsLeft => "ChevronsLeft"
    ChevronsRight => "ChevronsRight"
    ChevronsUp => "ChevronsUp"
    ChevronsDown => "ChevronsDown"
    SkipBack => "SkipBack"
    SkipForward => "SkipForward"
    CornerUpLeft => "CornerUpLeft"
    CornerUpRight => "CornerUpRight"
    Square => "Square"
    CircleRecord => "CircleRecord"
    Volume => "Volume"
    VolumeOff => "VolumeOff"
    Mic => "Mic"
    Camera => "Camera"
    Image => "Image"
    Music => "Music"
    Mail => "Mail"
    Send => "Send"
    MessageCircle => "MessageCircle"
    Bell => "Bell"
    BellOff => "BellOff"
    Phone => "Phone"
    Rss => "Rss"
    Globe => "Globe"
    Power => "Power"
    LogOut => "LogOut"
    LogIn => "LogIn"
    Lock => "Lock"
    Unlock => "Unlock"
    Key => "Key"
    Shield => "Shield"
    Sliders => "Sliders"
    Database => "Database"
    Server => "Server"
    HardDrive => "HardDrive"
    Printer => "Printer"
    Monitor => "Monitor"
    Smartphone => "Smartphone"
    Wifi => "Wifi"
    WifiOff => "WifiOff"
    Bluetooth => "Bluetooth"
    Cpu => "Cpu"
    Terminal => "Terminal"
    Code => "Code"
    GitBranch => "GitBranch"
    GitCommit => "GitCommit"
    GitPullRequest => "GitPullRequest"
    Package => "Package"
    Bug => "Bug"
    Flask => "Flask"
    Cloud => "Cloud"
    CloudDownload => "CloudDownload"
    CloudUpload => "CloudUpload"
    Layers => "Layers"
    Zap => "Zap"
    Help => "Help"
    Heart => "Heart"
    Flag => "Flag"
    Clock => "Clock"
    Tag => "Tag"
    Archive => "Archive"
    Inbox => "Inbox"
    ThumbsUp => "ThumbsUp"
    TrendingUp => "TrendingUp"
    TrendingDown => "TrendingDown"
    BarChart => "BarChart"
    PieChart => "PieChart"
    TableRows => "TableRows"
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
      attach(parent, ViewLike::view(v))
      if tip != "" {
        attach_tooltip(parent, ViewLike::view(v), tip)
      }
      ViewLike::view(v)
    },
  }
}
