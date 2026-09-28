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
  // —— 编辑补充 ——
  Type
  ArrowUpDown
  AlignJustify
  // —— 视图/布局补充 ——
  Move
  Expand
  Shrink
  RotateCw
  RotateCcw
  Columns
  Rows
  // —— 状态/反馈补充 ——
  CheckCircle
  XCircle
  InfoCircle
  Loader
  BellRing
  Pin
  Share
  // —— 用户 ——
  UserPlus
  UserCheck
  Users
  // —— 天气 ——
  Cloudy
  CloudSun
  CloudRain
  CloudSnow
  Droplet
  Thermometer
  Wind
  // —— 设备 ——
  Keyboard
  Mouse
  Headphones
  Battery
  BatteryCharging
  Signal
  // —— 商业/物体 ——
  ShoppingCart
  CreditCard
  Gift
  Percent
  Rocket
  Trophy
  Lightbulb
  Wrench
  Compass
  MapPin
  Navigation
  Crown
  // ---- icons-gen:variants
  YhTreeStructure // 树形图
  YhTreeTable // 树形表格
  YhTable // 表格
  YhTab // 标签页
  YhTextField // 单行输入框
  YhTextarea // 多行输入框
  YhNumberField // 数字输入框
  YhSelectField // 下拉多选
  YhEditTable // 可编辑表格
  YhScript // script
  YhFunction // function
  YhParams // 参数
  YhQueryFilter // 条件查询
  YhFontSize // font-size
  YhFontColor // font-colors
  YhLineHeight // line-height
  YhStrikethrough // strikethrough
  YhIndent // indent
  YhOutdent // outdent
  YhColumnHeight // colum-height
  YhColumnWidth // column-width
  YhVAlignBottom // vertical-align-botto
  YhVAlignMiddle // vertical-align-middl
  YhVAlignTop // vertical-align-top
  YhBorderOuter // border-outer
  YhBorderTop // border-top
  YhBorderBottom // border-bottom
  YhBorderLeft // border-left
  YhBorderRight // border-right
  YhBorderInner // border-inner
  YhBorderVertical // border-verticle
  YhBorderHorizontal // border-horizontal
  YhAppstore // app store
  YhFullscreen // full-screen
  YhFullscreenExit // fullscreen-exit
  YhToTop // totop
  YhSwap // swap
  YhRollback // rollback
  YhEnter // enter
  YhDrag // drag
  YhMenuFold // menu-fold
  YhMenuUnfold // menu-unfold
  YhSortDesc // sort-descending
  YhSortAsc // sort-ascending
  YhFile // file-fill
  YhFilePdf // file-pdf
  YhFileWord // file-word
  YhFileExcel // file-excel
  YhFilePpt // file-ppt
  YhFileZip // file-zip
  YhFileMarkdown // file-markdown
  YhFileSearch // file search
  YhSnippets // snippets
  YhCloudServer // cloud-server
  YhCloudSync // cloud-sync
  YhApi // api
  YhGateway // gateway
  YhQrcode // qrcode
  YhBarcode // barcode
  YhScan // scan
  YhLaptop // laptop
  YhTablet // tablet
  YhUsb // USB
  YhVideo // video
  YhAreaChart // area chart
  YhLineChart // line chart
  YhRadarChart // radar chart
  YhBoxplot // box plot
  YhDashboard // dashboard
  YhIdcard // id card
  YhContacts // contacts
  YhStop // stop
  YhExport // export
  YhImport // Import
  YhSmile // smile
  YhFrown // frown
  YhPaperclip // attachment
  YhCrop // crop
  YhMagicStick // magic-stick
  YhWallet // wallet
  YhBooks // books
  // ---- icons-gen:end ----
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
      p.begin_path()
      p.arc(cx, cy, s * 0.72, -0.9, 4.5)
      p.stroke()
      icon_polyline(p, [(cx + s * 0.05, cy - s * 0.98), (cx + s * 0.68, cy - s * 0.56), (cx + s * 0.30, cy - s * 0.12)])
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
      icon_line(p, cx + s * 0.75, cy - s * 0.25, cx + s * 0.25, cy - s * 0.75)
      icon_polyline(p, [(cx + s * 0.25, cy - s * 0.75), (cx - s * 0.55, cy + s * 0.05), (cx - s * 0.75, cy + s * 0.75), (cx - s * 0.05, cy + s * 0.55), (cx + s * 0.75, cy - s * 0.25)])
      icon_line(p, cx - s * 0.55, cy + s * 0.05, cx - s * 0.05, cy + s * 0.55)
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
      p.bezier_curve_to(cx - s * 0.4, cy - s * 0.15, cx - s * 0.15, cy + s * 0.05, cx - s * 0.15, cy + s * 0.3)
      p.line_to(cx - s * 0.15, cy + s * 0.75)
      p.line_to(cx + s * 0.15, cy + s * 0.75)
      p.line_to(cx + s * 0.15, cy + s * 0.3)
      p.bezier_curve_to(cx + s * 0.15, cy + s * 0.05, cx + s * 0.4, cy - s * 0.15, cx + s * 0.85, cy - s * 0.7)
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
      icon_polyline(p, [(cx - 8.5 * u, cy + 6 * u), (cx - 8.5 * u, cy - 5.5 * u), (cx - 3.5 * u, cy - 5.5 * u), (cx - 1.5 * u, cy - 3.5 * u), (cx + 5.5 * u, cy - 3.5 * u), (cx + 5.5 * u, cy - 1.5 * u)])
      icon_outline(p, [(cx - 8.5 * u, cy + 6 * u), (cx - 5 * u, cy - 1.5 * u), (cx + 8.5 * u, cy - 1.5 * u), (cx + 5 * u, cy + 6 * u)])
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
      icon_polyline(p, [(cx - 4 * u, cy + 1.5 * u), (cx - 7.5 * u, cy - 2 * u), (cx - 4 * u, cy - 5.5 * u)])
      icon_line(p, cx - 7.5 * u, cy - 2 * u, cx + 1 * u, cy - 2 * u)
      icon_arc(p, cx + 1 * u, cy + 2 * u, 4 * u, -1.5708, 1.5708)
    }
    Redo => {
      let u = s / 9.0
      icon_polyline(p, [(cx + 4 * u, cy + 1.5 * u), (cx + 7.5 * u, cy - 2 * u), (cx + 4 * u, cy - 5.5 * u)])
      icon_line(p, cx + 7.5 * u, cy - 2 * u, cx - 1 * u, cy - 2 * u)
      icon_arc(p, cx - 1 * u, cy + 2 * u, 4 * u, 4.712389, 1.5708, ccw=true)
    }
    Scissors => {
      let u = s / 9.0
      icon_circle(p, cx - 6.5 * u, cy - 5.5 * u, 2.5 * u)
      icon_circle(p, cx - 6.5 * u, cy + 5.5 * u, 2.5 * u)
      icon_line(p, cx - 4.6 * u, cy - 4 * u, cx + 8 * u, cy + 6.5 * u)
      icon_line(p, cx - 4.6 * u, cy + 4 * u, cx + 8 * u, cy - 6.5 * u)
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
      icon_line(p, cx - 5 * u, cy - 8 * u, cx - 5 * u, cy + 8 * u)
      icon_arc(p, cx - 5 * u, cy - 4.5 * u, 4.5 * u, -1.5708, 1.5708)
      icon_arc(p, cx - 5 * u, cy + 3.5 * u, 5.5 * u, -1.5708, 1.5708)
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
      // 1
      icon_polyline(p, [(cx - 7.5 * u, cy - 7.8 * u), (cx - 6.3 * u, cy - 8.5 * u), (cx - 6.3 * u, cy - 4.5 * u)])
      // 2
      icon_polyline(p, [(cx - 8.3 * u, cy - 1.3 * u), (cx - 6.3 * u, cy - 3.2 * u), (cx - 6.3 * u, cy - 0.5 * u), (cx - 8.3 * u, cy + 1.2 * u), (cx - 5.9 * u, cy + 1.2 * u)])
      // 3
      icon_polyline(p, [(cx - 8.3 * u, cy + 4.6 * u), (cx - 6.3 * u, cy + 3.8 * u), (cx - 6.3 * u, cy + 7.8 * u), (cx - 8.3 * u, cy + 7 * u)])
      icon_line(p, cx - 2.5 * u, cy - 6.5 * u, cx + 8 * u, cy - 6.5 * u)
      icon_line(p, cx - 2.5 * u, cy, cx + 8 * u, cy)
      icon_line(p, cx - 2.5 * u, cy + 6.5 * u, cx + 8 * u, cy + 6.5 * u)
    }
    Link => {
      let u = s / 9.0
      icon_line(p, cx - 3 * u, cy + 3 * u, cx + 3 * u, cy - 3 * u)
      icon_outline(p, [(cx - 8 * u, cy - 2 * u), (cx - 4 * u, cy - 6 * u), (cx, cy - 2 * u), (cx - 4 * u, cy + 2 * u)])
      icon_outline(p, [(cx, cy + 2 * u), (cx + 4 * u, cy - 2 * u), (cx + 8 * u, cy + 2 * u), (cx + 4 * u, cy + 6 * u)])
    }
    Unlink => {
      let u = s / 9.0
      icon_line(p, cx - 1.8 * u, cy + 1.8 * u, cx + 1.8 * u, cy - 1.8 * u)
      icon_polyline(p, [(cx - 7.5 * u, cy + 0.5 * u), (cx - 7.5 * u, cy + 7.5 * u), (cx - 0.5 * u, cy + 7.5 * u)])
      icon_line(p, cx - 5.5 * u, cy + 5.5 * u, cx - 2.2 * u, cy + 2.2 * u)
      icon_polyline(p, [(cx + 7.5 * u, cy - 0.5 * u), (cx + 7.5 * u, cy - 7.5 * u), (cx + 0.5 * u, cy - 7.5 * u)])
      icon_line(p, cx + 5.5 * u, cy - 5.5 * u, cx + 2.2 * u, cy - 2.2 * u)
    }
    ExternalLink => {
      let u = s / 9.0
      icon_polyline(p, [(cx + 2.5 * u, cy - 2.5 * u), (cx - 7 * u, cy - 2.5 * u), (cx - 7 * u, cy + 7.5 * u), (cx + 7 * u, cy + 7.5 * u), (cx + 7 * u, cy - 2 * u)])
      icon_line(p, cx + 1 * u, cy - 1 * u, cx + 7.5 * u, cy - 7.5 * u)
      icon_polyline(p, [(cx + 2.5 * u, cy - 7.5 * u), (cx + 7.5 * u, cy - 7.5 * u), (cx + 7.5 * u, cy - 2.5 * u)])
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
      icon_arc(p, cx, cy + 3 * u, 7.62 * u, 3.55, 5.88)
      icon_arc(p, cx, cy - 3 * u, 7.62 * u, 0.40, 2.74)
      icon_circle(p, cx, cy, 2.6 * u)
      icon_line(p, cx - 8.5 * u, cy - 8.5 * u, cx + 8.5 * u, cy + 8.5 * u)
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
      icon_arc(p, cx, cy, 7.16 * u, 1.15, 5.24)
      icon_arc(p, cx + 4 * u, cy, 6.58 * u, 1.72, 4.56)
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
      p.begin_path()
      p.move_to(cx + 6 * u, cy + 4 * u)
      p.bezier_curve_to(cx + 6.5 * u, cy + 4 * u, cx + 6.5 * u, cy + 3.5 * u, cx + 6 * u, cy + 3 * u)
      p.bezier_curve_to(cx + 5 * u, cy + 1.5 * u, cx + 5 * u, cy - 1 * u, cx + 5 * u, cy - 3 * u)
      p.bezier_curve_to(cx + 5 * u, cy - 6.5 * u, cx + 2.8 * u, cy - 8 * u, cx, cy - 8 * u)
      p.bezier_curve_to(cx - 2.8 * u, cy - 8 * u, cx - 5 * u, cy - 6.5 * u, cx - 5 * u, cy - 3 * u)
      p.bezier_curve_to(cx - 5 * u, cy - 1 * u, cx - 5 * u, cy + 1.5 * u, cx - 6 * u, cy + 3 * u)
      p.bezier_curve_to(cx - 6.5 * u, cy + 3.5 * u, cx - 6.5 * u, cy + 4 * u, cx - 6 * u, cy + 4 * u)
      p.close_path()
      p.stroke()
      icon_dot(p, cx, cy - 9 * u, 0.7 * u)
      icon_arc(p, cx, cy + 5.5 * u, 2.5 * u, 0.0, 3.141592653589793)
      let u = s / 9.0
      p.begin_path()
      p.move_to(cx + 6 * u, cy + 4 * u)
      p.bezier_curve_to(cx + 6.5 * u, cy + 4 * u, cx + 6.5 * u, cy + 3.5 * u, cx + 6 * u, cy + 3 * u)
      p.bezier_curve_to(cx + 5 * u, cy + 1.5 * u, cx + 5 * u, cy - 1 * u, cx + 5 * u, cy - 3 * u)
      p.bezier_curve_to(cx + 5 * u, cy - 6.5 * u, cx + 2.8 * u, cy - 8 * u, cx, cy - 8 * u)
      p.bezier_curve_to(cx - 2.8 * u, cy - 8 * u, cx - 5 * u, cy - 6.5 * u, cx - 5 * u, cy - 3 * u)
      p.bezier_curve_to(cx - 5 * u, cy - 1 * u, cx - 5 * u, cy + 1.5 * u, cx - 6 * u, cy + 3 * u)
      p.bezier_curve_to(cx - 6.5 * u, cy + 3.5 * u, cx - 6.5 * u, cy + 4 * u, cx - 6 * u, cy + 4 * u)
      p.close_path()
      p.stroke()
      icon_line(p, cx - 8 * u, cy - 8.5 * u, cx + 8 * u, cy + 8.5 * u)
      icon_line(p, cx - 2.5 * u, cy + 7 * u, cx + 2.5 * u, cy + 7 * u)
    }
    BellOff => {
      let u = s / 9.0
      p.begin_path()
      p.move_to(cx + 6 * u, cy + 4 * u)
      p.bezier_curve_to(cx + 6.5 * u, cy + 4 * u, cx + 6.5 * u, cy + 3.5 * u, cx + 6 * u, cy + 3 * u)
      p.bezier_curve_to(cx + 5 * u, cy + 1.5 * u, cx + 5 * u, cy - 1 * u, cx + 5 * u, cy - 3 * u)
      p.bezier_curve_to(cx + 5 * u, cy - 6.5 * u, cx + 2.8 * u, cy - 8 * u, cx, cy - 8 * u)
      p.bezier_curve_to(cx - 2.8 * u, cy - 8 * u, cx - 5 * u, cy - 6.5 * u, cx - 5 * u, cy - 3 * u)
      p.bezier_curve_to(cx - 5 * u, cy - 1 * u, cx - 5 * u, cy + 1.5 * u, cx - 6 * u, cy + 3 * u)
      p.bezier_curve_to(cx - 6.5 * u, cy + 3.5 * u, cx - 6.5 * u, cy + 4 * u, cx - 6 * u, cy + 4 * u)
      p.close_path()
      p.stroke()
      icon_line(p, cx - 8 * u, cy - 8.5 * u, cx + 8 * u, cy + 8.5 * u)
      icon_line(p, cx - 2.5 * u, cy + 7 * u, cx + 2.5 * u, cy + 7 * u)
    }
    Phone => {
      let u = s / 9.0
      p.begin_path()
      p.move_to(cx + 7.5 * u, cy + 2 * u)
      p.bezier_curve_to(cx + 7.8 * u, cy + 5.5 * u, cx + 6 * u, cy + 7.5 * u, cx + 4 * u, cy + 7.5 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 7.5 * u, cx - 3 * u, cy + 5 * u, cx - 6 * u, cy + 2 * u)
      p.bezier_curve_to(cx - 8 * u, cy - 1 * u, cx - 7.5 * u, cy - 5 * u, cx - 7.5 * u, cy - 6 * u)
      p.bezier_curve_to(cx - 7.5 * u, cy - 7.5 * u, cx - 6 * u, cy - 8 * u, cx - 4.5 * u, cy - 7.5 * u)
      p.bezier_curve_to(cx - 3 * u, cy - 7 * u, cx - 2 * u, cy - 5 * u, cx - 2.5 * u, cy - 3.5 * u)
      p.bezier_curve_to(cx - 2.8 * u, cy - 2.5 * u, cx - 3 * u, cy - 1.5 * u, cx - 2 * u, cy - 0.5 * u)
      p.bezier_curve_to(cx - 0.5 * u, cy + 1.5 * u, cx + 1.5 * u, cy + 3 * u, cx + 3 * u, cy + 3.5 * u)
      p.bezier_curve_to(cx + 4 * u, cy + 3.8 * u, cx + 5 * u, cy + 3 * u, cx + 6 * u, cy + 2.5 * u)
      p.close_path()
      p.stroke()
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
      icon_circle(p, cx, cy, 8.5 * u)
      icon_arc(p, cx, cy, 8.5 * u, 3.6652, 5.7596)
      icon_arc(p, cx, cy, 8.5 * u, 0.5236, 2.6180)
      icon_line(p, cx - 8.5 * u, cy, cx + 8.5 * u, cy)
      p.begin_path()
      p.arc(cx, cy, 4 * u, 0.0, ICON_TAU)
      p.move_to(cx, cy - 8.5 * u)
      p.bezier_curve_to(cx - 2.5 * u, cy - 5.5 * u, cx - 2.5 * u, cy + 5.5 * u, cx, cy + 8.5 * u)
      p.stroke()
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
      icon_arc(p, cx - 2.5 * u, cy - 1 * u, 4.5 * u, 3.141592653589793, ICON_TAU)
      icon_line(p, cx + 2 * u, cy - 5.5 * u, cx + 2 * u, cy - 3 * u)
      icon_line(p, cx + 2 * u, cy - 5.5 * u, cx + 5.5 * u, cy - 5.5 * u)
      icon_line(p, cx + 5.5 * u, cy - 5.5 * u, cx + 5.5 * u, cy - 1 * u)
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
      p.begin_path()
      p.move_to(cx - 7.5 * u, cy + 4 * u)
      p.arc(cx - 4.25 * u, cy + 4 * u, 3.25 * u, 3.141592653589793, ICON_TAU)
      p.arc(cx + 1.75 * u, cy + 4 * u, 4.25 * u, 3.141592653589793, ICON_TAU)
      p.close_path()
      p.stroke()
    }
    CloudDownload => {
      let u = s / 9.0
      p.begin_path()
      p.move_to(cx - 7.5 * u, cy + 4 * u)
      p.arc(cx - 4.25 * u, cy + 4 * u, 3.25 * u, 3.141592653589793, ICON_TAU)
      p.arc(cx + 1.75 * u, cy + 4 * u, 4.25 * u, 3.141592653589793, ICON_TAU)
      p.close_path()
      p.stroke()
      icon_line(p, cx, cy + 6 * u, cx, cy + 11 * u)
      icon_polyline(p, [(cx - 2.2 * u, cy + 9 * u), (cx, cy + 11 * u), (cx + 2.2 * u, cy + 9 * u)])
    }
    CloudUpload => {
      let u = s / 9.0
      p.begin_path()
      p.move_to(cx - 7.5 * u, cy + 4 * u)
      p.arc(cx - 4.25 * u, cy + 4 * u, 3.25 * u, 3.141592653589793, ICON_TAU)
      p.arc(cx + 1.75 * u, cy + 4 * u, 4.25 * u, 3.141592653589793, ICON_TAU)
      p.close_path()
      p.stroke()
      icon_line(p, cx, cy + 11 * u, cx, cy + 6 * u)
      icon_polyline(p, [(cx - 2.2 * u, cy + 8 * u), (cx, cy + 6 * u), (cx + 2.2 * u, cy + 8 * u)])
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
    Type => {
      let u = s / 9.0
      icon_line(p, cx - 7 * u, cy - 6 * u, cx + 7 * u, cy - 6 * u)
      icon_line(p, cx, cy - 6 * u, cx, cy + 7 * u)
    }
    ArrowUpDown => {
      let u = s / 9.0
      icon_line(p, cx - 4.5 * u, cy + 8 * u, cx - 4.5 * u, cy - 8 * u)
      icon_polyline(p, [(cx - 6.8 * u, cy - 5.4 * u), (cx - 4.5 * u, cy - 8 * u), (cx - 2.2 * u, cy - 5.4 * u)])
      icon_line(p, cx + 4.5 * u, cy - 8 * u, cx + 4.5 * u, cy + 8 * u)
      icon_polyline(p, [(cx + 2.2 * u, cy + 5.4 * u), (cx + 4.5 * u, cy + 8 * u), (cx + 6.8 * u, cy + 5.4 * u)])
    }
    AlignJustify => {
      let u = s / 9.0
      icon_line(p, cx - 7 * u, cy - 6 * u, cx + 7 * u, cy - 6 * u)
      icon_line(p, cx - 7 * u, cy - 2 * u, cx + 7 * u, cy - 2 * u)
      icon_line(p, cx - 7 * u, cy + 2 * u, cx + 7 * u, cy + 2 * u)
      icon_line(p, cx - 7 * u, cy + 6 * u, cx + 7 * u, cy + 6 * u)
    }
    Move => {
      let u = s / 9.0
      icon_dot(p, cx, cy, 1.2 * u)
      icon_line(p, cx, cy - 8 * u, cx, cy + 8 * u)
      icon_line(p, cx - 8 * u, cy, cx + 8 * u, cy)
      icon_polyline(p, [(cx - 2 * u, cy - 6 * u), (cx, cy - 8 * u), (cx + 2 * u, cy - 6 * u)])
      icon_polyline(p, [(cx - 2 * u, cy + 6 * u), (cx, cy + 8 * u), (cx + 2 * u, cy + 6 * u)])
      icon_polyline(p, [(cx - 6 * u, cy - 2 * u), (cx - 8 * u, cy), (cx - 6 * u, cy + 2 * u)])
      icon_polyline(p, [(cx + 6 * u, cy - 2 * u), (cx + 8 * u, cy), (cx + 6 * u, cy + 2 * u)])
    }
    Expand => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 7 * u, cy - 3 * u), (cx - 7 * u, cy - 7 * u), (cx - 3 * u, cy - 7 * u)])
      icon_polyline(p, [(cx + 3 * u, cy - 7 * u), (cx + 7 * u, cy - 7 * u), (cx + 7 * u, cy - 3 * u)])
      icon_polyline(p, [(cx + 7 * u, cy + 3 * u), (cx + 7 * u, cy + 7 * u), (cx + 3 * u, cy + 7 * u)])
      icon_polyline(p, [(cx - 3 * u, cy + 7 * u), (cx - 7 * u, cy + 7 * u), (cx - 7 * u, cy + 3 * u)])
    }
    Shrink => {
      let u = s / 9.0
      icon_line(p, cx - 3 * u, cy - 3 * u, cx - 7.5 * u, cy - 7.5 * u)
      icon_polyline(p, [(cx - 4.2 * u, cy - 7.5 * u), (cx - 7.5 * u, cy - 7.5 * u), (cx - 7.5 * u, cy - 4.2 * u)])
      icon_line(p, cx + 3 * u, cy + 3 * u, cx + 7.5 * u, cy + 7.5 * u)
      icon_polyline(p, [(cx + 4.2 * u, cy + 7.5 * u), (cx + 7.5 * u, cy + 7.5 * u), (cx + 7.5 * u, cy + 4.2 * u)])
    }
    RotateCw => {
      let u = s / 9.0
      icon_arc(p, cx, cy, 7 * u, -0.5236, -2.6180)
      icon_polyline(p, [(cx + 0.6 * u, cy - 9.6 * u), (cx + 6.4 * u, cy - 4.2 * u), (cx + 0.8 * u, cy - 3.2 * u)])
    }
    RotateCcw => {
      let u = s / 9.0
      icon_arc(p, cx, cy, 7 * u, -2.6180, -0.5236, ccw=true)
      icon_polyline(p, [(cx - 0.6 * u, cy - 9.6 * u), (cx - 6.4 * u, cy - 4.2 * u), (cx - 0.8 * u, cy - 3.2 * u)])
    }
    Columns => {
      let u = s / 9.0
      icon_outline(p, [(cx - 7 * u, cy - 7 * u), (cx + 7 * u, cy - 7 * u), (cx + 7 * u, cy + 7 * u), (cx - 7 * u, cy + 7 * u)])
      icon_line(p, cx, cy - 7 * u, cx, cy + 7 * u)
    }
    Rows => {
      let u = s / 9.0
      icon_outline(p, [(cx - 7 * u, cy - 7 * u), (cx + 7 * u, cy - 7 * u), (cx + 7 * u, cy + 7 * u), (cx - 7 * u, cy + 7 * u)])
      icon_line(p, cx - 7 * u, cy, cx + 7 * u, cy)
    }
    CheckCircle => {
      let u = s / 9.0
      icon_circle(p, cx, cy, 8 * u)
      icon_polyline(p, [(cx - 3.6 * u, cy + 0.2 * u), (cx - 1 * u, cy + 2.8 * u), (cx + 4 * u, cy - 2.8 * u)])
    }
    XCircle => {
      let u = s / 9.0
      icon_circle(p, cx, cy, 8 * u)
      icon_line(p, cx - 3.2 * u, cy - 3.2 * u, cx + 3.2 * u, cy + 3.2 * u)
      icon_line(p, cx + 3.2 * u, cy - 3.2 * u, cx - 3.2 * u, cy + 3.2 * u)
    }
    InfoCircle => {
      let u = s / 9.0
      icon_circle(p, cx, cy, 8 * u)
      icon_dot(p, cx, cy - 3.5 * u, 0.9 * u)
      icon_line(p, cx, cy - 0.5 * u, cx, cy + 4 * u)
    }
    Loader => {
      let u = s / 9.0
      icon_arc(p, cx, cy, 7 * u, -1.5708, 3.14)
      icon_dot(p, cx, cy, 1.3 * u)
    }
    BellRing => {
      let u = s / 9.0
      let bx = cx - 2 * u
      p.begin_path()
      p.move_to(bx + 6 * u, cy + 4 * u)
      p.bezier_curve_to(bx + 6.5 * u, cy + 4 * u, bx + 6.5 * u, cy + 3.5 * u, bx + 6 * u, cy + 3 * u)
      p.bezier_curve_to(bx + 5 * u, cy + 1.5 * u, bx + 5 * u, cy - 1 * u, bx + 5 * u, cy - 3 * u)
      p.bezier_curve_to(bx + 5 * u, cy - 6.5 * u, bx + 2.8 * u, cy - 8 * u, bx, cy - 8 * u)
      p.bezier_curve_to(bx - 2.8 * u, cy - 8 * u, bx - 5 * u, cy - 6.5 * u, bx - 5 * u, cy - 3 * u)
      p.bezier_curve_to(bx - 5 * u, cy - 1 * u, bx - 5 * u, cy + 1.5 * u, bx - 6 * u, cy + 3 * u)
      p.bezier_curve_to(bx - 6.5 * u, cy + 3.5 * u, bx - 6.5 * u, cy + 4 * u, bx - 6 * u, cy + 4 * u)
      p.close_path()
      p.stroke()
      icon_line(p, bx - 2.5 * u, cy + 7 * u, bx + 2.5 * u, cy + 7 * u)
      // 右侧声波:两段同心弧
      icon_arc(p, bx + 6.5 * u, cy - 1 * u, 3 * u, -0.9, 0.9)
      icon_arc(p, bx + 6.5 * u, cy - 1 * u, 5.5 * u, -0.7, 0.7)
    }
    Pin => {
      let u = s / 9.0
      icon_outline(p, [(cx - 3 * u, cy - 8 * u), (cx + 3 * u, cy - 8 * u), (cx + 2.5 * u, cy - 3 * u), (cx + 4.5 * u, cy - 1 * u), (cx + 4.5 * u, cy + 0.5 * u), (cx - 4.5 * u, cy + 0.5 * u), (cx - 4.5 * u, cy - 1 * u), (cx - 2.5 * u, cy - 3 * u)])
      icon_line(p, cx, cy + 0.5 * u, cx, cy + 8 * u)
    }
    Share => {
      let u = s / 9.0
      icon_circle(p, cx + 5 * u, cy - 6 * u, 2.4 * u)
      icon_circle(p, cx + 5 * u, cy + 6 * u, 2.4 * u)
      icon_circle(p, cx - 5 * u, cy, 2.4 * u)
      icon_line(p, cx - 2.8 * u, cy - 1.3 * u, cx + 2.9 * u, cy - 4.8 * u)
      icon_line(p, cx - 2.8 * u, cy + 1.3 * u, cx + 2.9 * u, cy + 4.8 * u)
    }
    UserPlus => {
      let u = s / 9.0
      icon_circle(p, cx - 2 * u, cy - 4 * u, 3.2 * u)
      p.begin_path()
      p.arc(cx - 2 * u, cy + 7.5 * u, 6 * u, 3.141592653589793, ICON_TAU)
      p.stroke()
      icon_line(p, cx + 4.5 * u, cy - 1 * u, cx + 4.5 * u, cy + 5 * u)
      icon_line(p, cx + 1.5 * u, cy + 2 * u, cx + 7.5 * u, cy + 2 * u)
    }
    UserCheck => {
      let u = s / 9.0
      icon_circle(p, cx - 2 * u, cy - 4 * u, 3.2 * u)
      p.begin_path()
      p.arc(cx - 2 * u, cy + 7.5 * u, 6 * u, 3.141592653589793, ICON_TAU)
      p.stroke()
      icon_polyline(p, [(cx + 2.6 * u, cy + 2 * u), (cx + 4.1 * u, cy + 3.8 * u), (cx + 7.5 * u, cy - 0.5 * u)])
    }
    Users => {
      let u = s / 9.0
      // 前人:头 + 圆肩(竖直短边接半圆拱)
      icon_circle(p, cx - 3.5 * u, cy - 3 * u, 3.2 * u)
      p.begin_path()
      p.move_to(cx - 8 * u, cy + 8.5 * u)
      p.line_to(cx - 8 * u, cy + 6.5 * u)
      p.arc(cx - 3.5 * u, cy + 6.5 * u, 4.5 * u, 3.141592653589793, ICON_TAU)
      p.line_to(cx + 1 * u, cy + 8.5 * u)
      p.stroke()
      // 后人:右露大半张脸(右向弧) + 肩头(右缘竖线接四分之一肩弧,弧端朝上指向头部)
      icon_arc(p, cx + 4.5 * u, cy - 3.5 * u, 3 * u, -1.3, 1.3)
      p.begin_path()
      p.move_to(cx + 8.3 * u, cy + 8.5 * u)
      p.line_to(cx + 8.3 * u, cy + 6.8 * u)
      p.arc(cx + 8.3 * u, cy + 3.4 * u, 3.4 * u, 1.5707963267948966, 3.141592653589793)
      p.stroke()
    }
    Cloudy => {
      let u = s / 9.0
      icon_outline(p, [(cx - 7 * u, cy + 3 * u), (cx - 7 * u, cy - 1 * u), (cx - 5 * u, cy - 4.5 * u), (cx - 1.5 * u, cy - 5.5 * u), (cx + 1 * u, cy - 7.5 * u), (cx + 4 * u, cy - 7 * u), (cx + 6 * u, cy - 4.5 * u), (cx + 7 * u, cy - 1 * u), (cx + 7 * u, cy + 3 * u)])
    }
    CloudSun => {
      let u = s / 9.0
      p.begin_path()
      p.move_to(cx - 7.5 * u, cy + 4 * u)
      p.arc(cx - 4.25 * u, cy + 4 * u, 3.25 * u, 3.141592653589793, ICON_TAU)
      p.arc(cx + 1.75 * u, cy + 4 * u, 4.25 * u, 3.141592653589793, ICON_TAU)
      p.close_path()
      p.stroke()
      // 左上太阳:圆 + 三根光芒
      icon_circle(p, cx - 3 * u, cy - 5.5 * u, 2.2 * u)
      icon_line(p, cx - 3 * u, cy - 9.5 * u, cx - 3 * u, cy - 8.6 * u)
      icon_line(p, cx - 7 * u, cy - 5.5 * u, cx - 6.1 * u, cy - 5.5 * u)
      icon_line(p, cx - 6 * u, cy - 8.5 * u, cx - 5.4 * u, cy - 7.9 * u)
    }
    CloudRain => {
      let u = s / 9.0
      p.begin_path()
      p.move_to(cx - 7.5 * u, cy + 4 * u)
      p.arc(cx - 4.25 * u, cy + 4 * u, 3.25 * u, 3.141592653589793, ICON_TAU)
      p.arc(cx + 1.75 * u, cy + 4 * u, 4.25 * u, 3.141592653589793, ICON_TAU)
      p.close_path()
      p.stroke()
      icon_line(p, cx - 4.5 * u, cy + 6.5 * u, cx - 5.5 * u, cy + 9.5 * u)
      icon_line(p, cx + 0.5 * u, cy + 6.5 * u, cx - 0.5 * u, cy + 9.5 * u)
      icon_line(p, cx + 5.5 * u, cy + 6.5 * u, cx + 4.5 * u, cy + 9.5 * u)
    }
    CloudSnow => {
      let u = s / 9.0
      p.begin_path()
      p.move_to(cx - 7.5 * u, cy + 4 * u)
      p.arc(cx - 4.25 * u, cy + 4 * u, 3.25 * u, 3.141592653589793, ICON_TAU)
      p.arc(cx + 1.75 * u, cy + 4 * u, 4.25 * u, 3.141592653589793, ICON_TAU)
      p.close_path()
      p.stroke()
      icon_dot(p, cx - 4.5 * u, cy + 6.5 * u, 0.8 * u)
      icon_dot(p, cx, cy + 6.5 * u, 0.8 * u)
      icon_dot(p, cx + 4.5 * u, cy + 6.5 * u, 0.8 * u)
      icon_dot(p, cx - 2.2 * u, cy + 9 * u, 0.8 * u)
      icon_dot(p, cx + 2.2 * u, cy + 9 * u, 0.8 * u)
    }
    Droplet => {
      let u = s / 9.0
      p.begin_path()
      p.move_to(cx, cy - 8 * u)
      p.bezier_curve_to(cx, cy - 8 * u, cx + 6 * u, cy - 1 * u, cx + 6 * u, cy + 2 * u)
      p.arc(cx, cy + 2 * u, 6 * u, 0.0, 3.141592653589793)
      p.bezier_curve_to(cx - 6 * u, cy - 1 * u, cx, cy - 8 * u, cx, cy - 8 * u)
      p.close_path()
      p.stroke()
    }
    Thermometer => {
      let u = s / 9.0
      icon_outline(p, [(cx - 2 * u, cy - 8 * u), (cx + 2 * u, cy - 8 * u), (cx + 2 * u, cy + 1 * u), (cx + 3.5 * u, cy + 2.5 * u), (cx + 3.5 * u, cy + 5 * u), (cx + 1.8 * u, cy + 7.2 * u), (cx - 1.8 * u, cy + 7.2 * u), (cx - 3.5 * u, cy + 5 * u), (cx - 3.5 * u, cy + 2.5 * u), (cx - 2 * u, cy + 1 * u)])
      icon_line(p, cx, cy - 6 * u, cx, cy + 2 * u)
      icon_dot(p, cx, cy + 4 * u, 2.2 * u)
    }
    Wind => {
      let u = s / 9.0
      icon_line(p, cx - 7 * u, cy - 4 * u, cx + 4 * u, cy - 4 * u)
      icon_arc(p, cx + 4 * u, cy - 5.5 * u, 1.5 * u, 1.5708, 4.712)
      icon_line(p, cx - 7 * u, cy + 0.5 * u, cx + 1 * u, cy + 0.5 * u)
      icon_arc(p, cx + 1 * u, cy - 1 * u, 1.5 * u, 1.5708, 4.712)
      icon_line(p, cx - 4 * u, cy + 5 * u, cx + 5 * u, cy + 5 * u)
      icon_arc(p, cx + 5 * u, cy + 3.5 * u, 1.5 * u, 1.5708, 4.712)
    }
    Keyboard => {
      let u = s / 9.0
      icon_outline(p, [(cx - 8 * u, cy - 5 * u), (cx + 8 * u, cy - 5 * u), (cx + 8 * u, cy + 5 * u), (cx - 8 * u, cy + 5 * u)])
      icon_dot(p, cx - 6 * u, cy - 2.2 * u, 0.6 * u)
      icon_dot(p, cx - 3 * u, cy - 2.2 * u, 0.6 * u)
      icon_dot(p, cx, cy - 2.2 * u, 0.6 * u)
      icon_dot(p, cx + 3 * u, cy - 2.2 * u, 0.6 * u)
      icon_dot(p, cx + 6 * u, cy - 2.2 * u, 0.6 * u)
      icon_dot(p, cx - 6 * u, cy + 0.6 * u, 0.6 * u)
      icon_dot(p, cx - 3 * u, cy + 0.6 * u, 0.6 * u)
      icon_dot(p, cx, cy + 0.6 * u, 0.6 * u)
      icon_dot(p, cx + 3 * u, cy + 0.6 * u, 0.6 * u)
      icon_dot(p, cx + 6 * u, cy + 0.6 * u, 0.6 * u)
      icon_line(p, cx - 4 * u, cy + 3.4 * u, cx + 4 * u, cy + 3.4 * u)
    }
    Mouse => {
      let u = s / 9.0
      icon_outline(p, [(cx - 4 * u, cy - 6.5 * u), (cx + 4 * u, cy - 6.5 * u), (cx + 4 * u, cy + 2 * u), (cx + 2 * u, cy + 7 * u), (cx - 2 * u, cy + 7 * u), (cx - 4 * u, cy + 2 * u)])
      icon_line(p, cx, cy - 6.5 * u, cx, cy - 2 * u)
      icon_line(p, cx - 4 * u, cy - 2 * u, cx + 4 * u, cy - 2 * u)
    }
    Headphones => {
      let u = s / 9.0
      icon_arc(p, cx, cy + 2.5 * u, 6.5 * u, 3.141592653589793, ICON_TAU)
      icon_outline(p, [(cx - 7.8 * u, cy + 2.5 * u), (cx - 6.2 * u, cy + 2.5 * u), (cx - 6.2 * u, cy + 7 * u), (cx - 7.8 * u, cy + 7 * u)])
      icon_outline(p, [(cx + 6.2 * u, cy + 2.5 * u), (cx + 7.8 * u, cy + 2.5 * u), (cx + 7.8 * u, cy + 7 * u), (cx + 6.2 * u, cy + 7 * u)])
    }
    Battery => {
      let u = s / 9.0
      icon_outline(p, [(cx - 8 * u, cy - 4 * u), (cx + 6.5 * u, cy - 4 * u), (cx + 6.5 * u, cy + 4 * u), (cx - 8 * u, cy + 4 * u)])
      icon_line(p, cx + 6.5 * u, cy - 1.5 * u, cx + 8.5 * u, cy - 1.5 * u)
      icon_line(p, cx + 8.5 * u, cy - 1.5 * u, cx + 8.5 * u, cy + 1.5 * u)
      icon_line(p, cx + 8.5 * u, cy + 1.5 * u, cx + 6.5 * u, cy + 1.5 * u)
      icon_line(p, cx - 6 * u, cy - 1.8 * u, cx - 6 * u, cy + 1.8 * u)
      icon_line(p, cx - 2.5 * u, cy - 1.8 * u, cx - 2.5 * u, cy + 1.8 * u)
      icon_line(p, cx + 1 * u, cy - 1.8 * u, cx + 1 * u, cy + 1.8 * u)
    }
    BatteryCharging => {
      let u = s / 9.0
      icon_outline(p, [(cx - 8 * u, cy - 4 * u), (cx + 6.5 * u, cy - 4 * u), (cx + 6.5 * u, cy + 4 * u), (cx - 8 * u, cy + 4 * u)])
      icon_line(p, cx + 6.5 * u, cy - 1.5 * u, cx + 8.5 * u, cy - 1.5 * u)
      icon_line(p, cx + 8.5 * u, cy - 1.5 * u, cx + 8.5 * u, cy + 1.5 * u)
      icon_line(p, cx + 8.5 * u, cy + 1.5 * u, cx + 6.5 * u, cy + 1.5 * u)
      icon_polygon(p, [(cx + 1.5 * u, cy - 5 * u), (cx - 3.5 * u, cy + 0.5 * u), (cx - 0.3 * u, cy + 0.5 * u), (cx - 1.5 * u, cy + 5 * u), (cx + 3.8 * u, cy - 0.8 * u), (cx + 0.6 * u, cy - 0.8 * u)])
    }
    Signal => {
      let u = s / 9.0
      icon_line(p, cx - 6.5 * u, cy + 6 * u, cx - 6.5 * u, cy + 3 * u)
      icon_line(p, cx - 2.2 * u, cy + 6 * u, cx - 2.2 * u, cy)
      icon_line(p, cx + 2.2 * u, cy + 6 * u, cx + 2.2 * u, cy - 3 * u)
      icon_line(p, cx + 6.5 * u, cy + 6 * u, cx + 6.5 * u, cy - 6 * u)
    }
    ShoppingCart => {
      let u = s / 9.0
      icon_polyline(p, [(cx - 8 * u, cy - 7 * u), (cx - 6 * u, cy - 7 * u), (cx - 4 * u, cy - 2 * u), (cx + 6.5 * u, cy - 2 * u), (cx + 5 * u, cy + 2.5 * u), (cx - 4.5 * u, cy + 2.5 * u)])
      icon_circle(p, cx - 3 * u, cy + 6.5 * u, 1.8 * u)
      icon_circle(p, cx + 3.5 * u, cy + 6.5 * u, 1.8 * u)
    }
    CreditCard => {
      let u = s / 9.0
      icon_outline(p, [(cx - 8 * u, cy - 5.5 * u), (cx + 8 * u, cy - 5.5 * u), (cx + 8 * u, cy + 5.5 * u), (cx - 8 * u, cy + 5.5 * u)])
      icon_line(p, cx - 8 * u, cy - 1.5 * u, cx + 8 * u, cy - 1.5 * u)
      icon_line(p, cx - 5.5 * u, cy + 3 * u, cx - 1 * u, cy + 3 * u)
    }
    Gift => {
      let u = s / 9.0
      icon_outline(p, [(cx - 6.5 * u, cy - 2 * u), (cx + 6.5 * u, cy - 2 * u), (cx + 6.5 * u, cy + 7 * u), (cx - 6.5 * u, cy + 7 * u)])
      icon_line(p, cx - 7.5 * u, cy - 5 * u, cx + 7.5 * u, cy - 5 * u)
      icon_line(p, cx - 7.5 * u, cy - 5 * u, cx - 7.5 * u, cy - 2 * u)
      icon_line(p, cx + 7.5 * u, cy - 5 * u, cx + 7.5 * u, cy - 2 * u)
      icon_line(p, cx - 6.5 * u, cy - 5 * u, cx + 6.5 * u, cy - 5 * u)
      icon_line(p, cx, cy - 5 * u, cx, cy + 7 * u)
      icon_arc(p, cx - 2.8 * u, cy - 6.5 * u, 2 * u, 0.0, 3.141592653589793)
      icon_arc(p, cx + 2.8 * u, cy - 6.5 * u, 2 * u, 0.0, 3.141592653589793)
    }
    Percent => {
      let u = s / 9.0
      icon_line(p, cx - 5.5 * u, cy + 5.5 * u, cx + 5.5 * u, cy - 5.5 * u)
      icon_circle(p, cx - 5 * u, cy - 5 * u, 2.5 * u)
      icon_circle(p, cx + 5 * u, cy + 5 * u, 2.5 * u)
    }
    Rocket => {
      let u = s / 9.0
      icon_outline(p, [(cx, cy - 8.5 * u), (cx + 3 * u, cy - 4 * u), (cx + 3 * u, cy + 2 * u), (cx - 3 * u, cy + 2 * u), (cx - 3 * u, cy - 4 * u)])
      icon_circle(p, cx, cy - 3 * u, 1.6 * u)
      icon_polyline(p, [(cx - 3 * u, cy - 1 * u), (cx - 6 * u, cy + 2.5 * u), (cx - 3 * u, cy + 3.5 * u)])
      icon_polyline(p, [(cx + 3 * u, cy - 1 * u), (cx + 6 * u, cy + 2.5 * u), (cx + 3 * u, cy + 3.5 * u)])
      icon_polyline(p, [(cx - 1.5 * u, cy + 4.5 * u), (cx, cy + 8 * u), (cx + 1.5 * u, cy + 4.5 * u)])
    }
    Trophy => {
      let u = s / 9.0
      icon_outline(p, [(cx - 5 * u, cy - 7.5 * u), (cx + 5 * u, cy - 7.5 * u), (cx + 4 * u, cy - 0.5 * u), (cx + 1.5 * u, cy + 2 * u), (cx - 1.5 * u, cy + 2 * u), (cx - 4 * u, cy - 0.5 * u)])
      icon_arc(p, cx - 6.5 * u, cy - 5 * u, 2 * u, 1.5708, 4.712)
      icon_arc(p, cx + 6.5 * u, cy - 5 * u, 2 * u, -1.5708, 1.5708)
      icon_line(p, cx, cy + 2 * u, cx, cy + 4.5 * u)
      icon_line(p, cx - 3 * u, cy + 4.5 * u, cx + 3 * u, cy + 4.5 * u)
      icon_line(p, cx - 3.5 * u, cy + 7.5 * u, cx + 3.5 * u, cy + 7.5 * u)
    }
    Lightbulb => {
      let u = s / 9.0
      icon_circle(p, cx, cy - 4 * u, 4.8 * u)
      icon_polyline(p, [(cx - 3 * u, cy - 0.8 * u), (cx - 2 * u, cy + 2 * u), (cx + 2 * u, cy + 2 * u), (cx + 3 * u, cy - 0.8 * u)])
      icon_line(p, cx - 2 * u, cy + 4 * u, cx + 2 * u, cy + 4 * u)
      icon_line(p, cx - 2.5 * u, cy + 6.5 * u, cx + 2.5 * u, cy + 6.5 * u)
      icon_line(p, cx - 2 * u, cy + 9 * u, cx + 2 * u, cy + 9 * u)
    }
    Wrench => {
      let u = s / 9.0
      icon_arc(p, cx - 4 * u, cy - 4 * u, 4.2 * u, 0.7854, 4.3197)
      icon_line(p, cx - 1.2 * u, cy - 1.2 * u, cx + 6.5 * u, cy + 6.5 * u)
      icon_line(p, cx + 4 * u, cy + 7.8 * u, cx + 7.8 * u, cy + 4 * u)
      icon_line(p, cx + 4.9 * u, cy + 6.9 * u, cx + 6.9 * u, cy + 4.9 * u)
    }
    Compass => {
      let u = s / 9.0
      icon_circle(p, cx, cy, 8 * u)
      icon_outline(p, [(cx + 5 * u, cy - 5 * u), (cx - 2.2 * u, cy + 2.2 * u), (cx - 5 * u, cy + 5 * u), (cx + 2.2 * u, cy - 2.2 * u)])
    }
    MapPin => {
      let u = s / 9.0
      p.begin_path()
      p.move_to(cx, cy + 8 * u)
      p.bezier_curve_to(cx - 0.5 * u, cy + 5 * u, cx - 6 * u, cy + 1 * u, cx - 6 * u, cy - 2.5 * u)
      p.arc(cx, cy - 2.5 * u, 6 * u, 3.141592653589793, ICON_TAU)
      p.bezier_curve_to(cx + 6 * u, cy + 1 * u, cx + 0.5 * u, cy + 5 * u, cx, cy + 8 * u)
      p.close_path()
      p.stroke()
      icon_circle(p, cx, cy - 2.5 * u, 2.3 * u)
    }
    Navigation => {
      let u = s / 9.0
      icon_outline(p, [(cx - 6.5 * u, cy - 6.5 * u), (cx + 7.5 * u, cy - 0.5 * u), (cx + 0.5 * u, cy + 0.8 * u), (cx - 2 * u, cy + 7 * u)])
    }
    Crown => {
      let u = s / 9.0
      icon_outline(p, [(cx - 7.5 * u, cy + 6 * u), (cx - 7.5 * u, cy - 5 * u), (cx - 3 * u, cy - 0.5 * u), (cx, cy - 7 * u), (cx + 3 * u, cy - 0.5 * u), (cx + 7.5 * u, cy - 5 * u), (cx + 7.5 * u, cy + 6 * u)])
    }
    // ---- icons-gen:arms
    YhTreeStructure => { // 树形图
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.2 * u, cy + -0.7333 * u)
      p.line_to(cx + -0.8667 * u, cy + -0.7333 * u)
      p.bezier_curve_to(cx + -0.9035 * u, cy + -0.7333 * u, cx + -0.9333 * u, cy + -0.7631 * u, cx + -0.9333 * u, cy + -0.8 * u)
      p.line_to(cx + -0.9333 * u, cy + -0.9333 * u)
      p.bezier_curve_to(cx + -0.9333 * u, cy + -0.9702 * u, cx + -0.9035 * u, cy + -1 * u, cx + -0.8667 * u, cy + -1 * u)
      p.line_to(cx + -0.2 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.1631 * u, cy + -1 * u, cx + -0.1333 * u, cy + -0.9702 * u, cx + -0.1333 * u, cy + -0.9333 * u)
      p.line_to(cx + -0.1333 * u, cy + -0.8 * u)
      p.bezier_curve_to(cx + -0.1333 * u, cy + -0.7631 * u, cx + -0.1631 * u, cy + -0.7333 * u, cx + -0.2 * u, cy + -0.7333 * u)
      p.close_path()
      p.move_to(cx + -0.8667 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.9035 * u, cy + 1 * u, cx + -0.9333 * u, cy + 0.9702 * u, cx + -0.9333 * u, cy + 0.9333 * u)
      p.line_to(cx + -0.9333 * u, cy + -0.9333 * u)
      p.bezier_curve_to(cx + -0.9333 * u, cy + -0.9702 * u, cx + -0.9035 * u, cy + -1 * u, cx + -0.8667 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.8298 * u, cy + -1 * u, cx + -0.8 * u, cy + -0.9702 * u, cx + -0.8 * u, cy + -0.9333 * u)
      p.line_to(cx + -0.8 * u, cy + 0.9333 * u)
      p.bezier_curve_to(cx + -0.8 * u, cy + 0.9702 * u, cx + -0.8298 * u, cy + 1 * u, cx + -0.8667 * u, cy + 1 * u)
      p.close_path()
      p.move_to(cx + -0.3333 * u, cy + 0 * u)
      p.bezier_curve_to(cx + -0.3702 * u, cy + 0 * u, cx + -0.4 * u, cy + -0.0298 * u, cx + -0.4 * u, cy + -0.0667 * u)
      p.line_to(cx + -0.4 * u, cy + -0.5333 * u)
      p.bezier_curve_to(cx + -0.4 * u, cy + -0.5702 * u, cx + -0.3702 * u, cy + -0.6 * u, cx + -0.3333 * u, cy + -0.6 * u)
      p.bezier_curve_to(cx + -0.2965 * u, cy + -0.6 * u, cx + -0.2667 * u, cy + -0.5702 * u, cx + -0.2667 * u, cy + -0.5333 * u)
      p.line_to(cx + -0.2667 * u, cy + -0.0667 * u)
      p.bezier_curve_to(cx + -0.2667 * u, cy + -0.0298 * u, cx + -0.2965 * u, cy + 0 * u, cx + -0.3333 * u, cy + 0 * u)
      p.close_path()
      p.move_to(cx + -0.9333 * u, cy + -0.4667 * u)
      p.bezier_curve_to(cx + -0.9333 * u, cy + -0.5035 * u, cx + -0.9035 * u, cy + -0.5333 * u, cx + -0.8667 * u, cy + -0.5333 * u)
      p.line_to(cx + -0.3354 * u, cy + -0.5333 * u)
      p.bezier_curve_to(cx + -0.2985 * u, cy + -0.5333 * u, cx + -0.2687 * u, cy + -0.5035 * u, cx + -0.2688 * u, cy + -0.4667 * u)
      p.bezier_curve_to(cx + -0.2688 * u, cy + -0.4298 * u, cx + -0.2985 * u, cy + -0.4 * u, cx + -0.3354 * u, cy + -0.4 * u)
      p.line_to(cx + -0.8667 * u, cy + -0.4 * u)
      p.bezier_curve_to(cx + -0.9035 * u, cy + -0.4 * u, cx + -0.9333 * u, cy + -0.4298 * u, cx + -0.9333 * u, cy + -0.4667 * u)
      p.close_path()
      p.move_to(cx + -0.4 * u, cy + -0.0667 * u)
      p.bezier_curve_to(cx + -0.4 * u, cy + -0.1035 * u, cx + -0.3702 * u, cy + -0.1333 * u, cx + -0.3333 * u, cy + -0.1333 * u)
      p.line_to(cx + 0.3042 * u, cy + -0.1333 * u)
      p.bezier_curve_to(cx + 0.341 * u, cy + -0.1333 * u, cx + 0.3708 * u, cy + -0.1035 * u, cx + 0.3708 * u, cy + -0.0667 * u)
      p.bezier_curve_to(cx + 0.3708 * u, cy + -0.0298 * u, cx + 0.341 * u, cy + 0 * u, cx + 0.3042 * u, cy + 0 * u)
      p.line_to(cx + -0.3333 * u, cy + 0 * u)
      p.bezier_curve_to(cx + -0.3702 * u, cy + 0 * u, cx + -0.4 * u, cy + -0.0298 * u, cx + -0.4 * u, cy + -0.0667 * u)
      p.close_path()
      p.move_to(cx + -0.3333 * u, cy + 0.8 * u)
      p.bezier_curve_to(cx + -0.3702 * u, cy + 0.8 * u, cx + -0.4 * u, cy + 0.7702 * u, cx + -0.4 * u, cy + 0.7333 * u)
      p.line_to(cx + -0.4 * u, cy + 0.2667 * u)
      p.bezier_curve_to(cx + -0.4 * u, cy + 0.2298 * u, cx + -0.3702 * u, cy + 0.2 * u, cx + -0.3333 * u, cy + 0.2 * u)
      p.bezier_curve_to(cx + -0.2965 * u, cy + 0.2 * u, cx + -0.2667 * u, cy + 0.2298 * u, cx + -0.2667 * u, cy + 0.2667 * u)
      p.line_to(cx + -0.2667 * u, cy + 0.7333 * u)
      p.bezier_curve_to(cx + -0.2667 * u, cy + 0.7702 * u, cx + -0.2965 * u, cy + 0.8 * u, cx + -0.3333 * u, cy + 0.8 * u)
      p.close_path()
      p.move_to(cx + -0.4 * u, cy + 0.7333 * u)
      p.bezier_curve_to(cx + -0.4 * u, cy + 0.6965 * u, cx + -0.3702 * u, cy + 0.6667 * u, cx + -0.3333 * u, cy + 0.6667 * u)
      p.line_to(cx + 0.3042 * u, cy + 0.6667 * u)
      p.bezier_curve_to(cx + 0.341 * u, cy + 0.6667 * u, cx + 0.3708 * u, cy + 0.6965 * u, cx + 0.3708 * u, cy + 0.7333 * u)
      p.bezier_curve_to(cx + 0.3708 * u, cy + 0.7702 * u, cx + 0.341 * u, cy + 0.8 * u, cx + 0.3042 * u, cy + 0.8 * u)
      p.line_to(cx + -0.3333 * u, cy + 0.8 * u)
      p.bezier_curve_to(cx + -0.3702 * u, cy + 0.8 * u, cx + -0.4 * u, cy + 0.7702 * u, cx + -0.4 * u, cy + 0.7333 * u)
      p.close_path()
      p.move_to(cx + -0.9333 * u, cy + 0.3333 * u)
      p.bezier_curve_to(cx + -0.9333 * u, cy + 0.2965 * u, cx + -0.9035 * u, cy + 0.2667 * u, cx + -0.8667 * u, cy + 0.2667 * u)
      p.line_to(cx + -0.3354 * u, cy + 0.2667 * u)
      p.bezier_curve_to(cx + -0.2985 * u, cy + 0.2667 * u, cx + -0.2687 * u, cy + 0.2965 * u, cx + -0.2688 * u, cy + 0.3333 * u)
      p.bezier_curve_to(cx + -0.2688 * u, cy + 0.3702 * u, cx + -0.2985 * u, cy + 0.4 * u, cx + -0.3354 * u, cy + 0.4 * u)
      p.line_to(cx + -0.8667 * u, cy + 0.4 * u)
      p.bezier_curve_to(cx + -0.9035 * u, cy + 0.4 * u, cx + -0.9333 * u, cy + 0.3702 * u, cx + -0.9333 * u, cy + 0.3333 * u)
      p.close_path()
      p.move_to(cx + 0.3333 * u, cy + -0.3333 * u)
      p.line_to(cx + -0.3333 * u, cy + -0.3333 * u)
      p.bezier_curve_to(cx + -0.3702 * u, cy + -0.3333 * u, cx + -0.4 * u, cy + -0.3631 * u, cx + -0.4 * u, cy + -0.4 * u)
      p.line_to(cx + -0.4 * u, cy + -0.5333 * u)
      p.bezier_curve_to(cx + -0.4 * u, cy + -0.5702 * u, cx + -0.3702 * u, cy + -0.6 * u, cx + -0.3333 * u, cy + -0.6 * u)
      p.line_to(cx + 0.3333 * u, cy + -0.6 * u)
      p.bezier_curve_to(cx + 0.3702 * u, cy + -0.6 * u, cx + 0.4 * u, cy + -0.5702 * u, cx + 0.4 * u, cy + -0.5333 * u)
      p.line_to(cx + 0.4 * u, cy + -0.4 * u)
      p.bezier_curve_to(cx + 0.4 * u, cy + -0.3631 * u, cx + 0.3702 * u, cy + -0.3333 * u, cx + 0.3333 * u, cy + -0.3333 * u)
      p.close_path()
      p.move_to(cx + 0.8667 * u, cy + 0.0667 * u)
      p.line_to(cx + 0.2 * u, cy + 0.0667 * u)
      p.bezier_curve_to(cx + 0.1631 * u, cy + 0.0667 * u, cx + 0.1333 * u, cy + 0.0369 * u, cx + 0.1333 * u, cy + 0 * u)
      p.line_to(cx + 0.1333 * u, cy + -0.1333 * u)
      p.bezier_curve_to(cx + 0.1333 * u, cy + -0.1702 * u, cx + 0.1631 * u, cy + -0.2 * u, cx + 0.2 * u, cy + -0.2 * u)
      p.line_to(cx + 0.8667 * u, cy + -0.2 * u)
      p.bezier_curve_to(cx + 0.9035 * u, cy + -0.2 * u, cx + 0.9333 * u, cy + -0.1702 * u, cx + 0.9333 * u, cy + -0.1333 * u)
      p.line_to(cx + 0.9333 * u, cy + 0 * u)
      p.bezier_curve_to(cx + 0.9333 * u, cy + 0.0369 * u, cx + 0.9035 * u, cy + 0.0667 * u, cx + 0.8667 * u, cy + 0.0667 * u)
      p.close_path()
      p.move_to(cx + 0.8667 * u, cy + 0.8667 * u)
      p.line_to(cx + 0.2 * u, cy + 0.8667 * u)
      p.bezier_curve_to(cx + 0.1631 * u, cy + 0.8667 * u, cx + 0.1333 * u, cy + 0.8369 * u, cx + 0.1333 * u, cy + 0.8 * u)
      p.line_to(cx + 0.1333 * u, cy + 0.6667 * u)
      p.bezier_curve_to(cx + 0.1333 * u, cy + 0.6298 * u, cx + 0.1631 * u, cy + 0.6 * u, cx + 0.2 * u, cy + 0.6 * u)
      p.line_to(cx + 0.8667 * u, cy + 0.6 * u)
      p.bezier_curve_to(cx + 0.9035 * u, cy + 0.6 * u, cx + 0.9333 * u, cy + 0.6298 * u, cx + 0.9333 * u, cy + 0.6667 * u)
      p.line_to(cx + 0.9333 * u, cy + 0.8 * u)
      p.bezier_curve_to(cx + 0.9333 * u, cy + 0.8369 * u, cx + 0.9035 * u, cy + 0.8667 * u, cx + 0.8667 * u, cy + 0.8667 * u)
      p.close_path()
      p.move_to(cx + 0.3333 * u, cy + 0.4667 * u)
      p.line_to(cx + -0.3333 * u, cy + 0.4667 * u)
      p.bezier_curve_to(cx + -0.3702 * u, cy + 0.4667 * u, cx + -0.4 * u, cy + 0.4369 * u, cx + -0.4 * u, cy + 0.4 * u)
      p.line_to(cx + -0.4 * u, cy + 0.2667 * u)
      p.bezier_curve_to(cx + -0.4 * u, cy + 0.2298 * u, cx + -0.3702 * u, cy + 0.2 * u, cx + -0.3333 * u, cy + 0.2 * u)
      p.line_to(cx + 0.3333 * u, cy + 0.2 * u)
      p.bezier_curve_to(cx + 0.3702 * u, cy + 0.2 * u, cx + 0.4 * u, cy + 0.2298 * u, cx + 0.4 * u, cy + 0.2667 * u)
      p.line_to(cx + 0.4 * u, cy + 0.4 * u)
      p.bezier_curve_to(cx + 0.4 * u, cy + 0.4369 * u, cx + 0.3702 * u, cy + 0.4667 * u, cx + 0.3333 * u, cy + 0.4667 * u)
      p.close_path()
      p.fill()
    }
    YhTreeTable => { // 树形表格
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.3 * u, cy + -1 * u)
      p.line_to(cx + 0.9422 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.9813 * u, cy + -1 * u, cx + 1 * u, cy + -0.9781 * u, cx + 1 * u, cy + -0.9328 * u)
      p.line_to(cx + 1 * u, cy + -0.5672 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.5219 * u, cx + 0.9812 * u, cy + -0.5 * u, cx + 0.9422 * u, cy + -0.5 * u)
      p.line_to(cx + -0.3 * u, cy + -0.5 * u)
      p.bezier_curve_to(cx + -0.3375 * u, cy + -0.5 * u, cx + -0.3578 * u, cy + -0.5219 * u, cx + -0.3578 * u, cy + -0.5672 * u)
      p.line_to(cx + -0.3578 * u, cy + -0.9328 * u)
      p.bezier_curve_to(cx + -0.3578 * u, cy + -0.9781 * u, cx + -0.3375 * u, cy + -1 * u, cx + -0.3 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.0578 * u, cy + -0.25 * u)
      p.line_to(cx + 0.9422 * u, cy + -0.25 * u)
      p.bezier_curve_to(cx + 0.9813 * u, cy + -0.25 * u, cx + 1 * u, cy + -0.2281 * u, cx + 1 * u, cy + -0.1828 * u)
      p.line_to(cx + 1 * u, cy + 0.1828 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.2281 * u, cx + 0.9812 * u, cy + 0.25 * u, cx + 0.9422 * u, cy + 0.25 * u)
      p.line_to(cx + 0.0578 * u, cy + 0.25 * u)
      p.bezier_curve_to(cx + 0.0187 * u, cy + 0.25 * u, cx + 0 * u, cy + 0.2281 * u, cx + 0 * u, cy + 0.1828 * u)
      p.line_to(cx + 0 * u, cy + -0.1828 * u)
      p.bezier_curve_to(cx + 0 * u, cy + -0.2281 * u, cx + 0.0188 * u, cy + -0.25 * u, cx + 0.0578 * u, cy + -0.25 * u)
      p.close_path()
      p.move_to(cx + 0.0578 * u, cy + 0.5 * u)
      p.line_to(cx + 0.9422 * u, cy + 0.5 * u)
      p.bezier_curve_to(cx + 0.9813 * u, cy + 0.5 * u, cx + 1 * u, cy + 0.5219 * u, cx + 1 * u, cy + 0.5672 * u)
      p.line_to(cx + 1 * u, cy + 0.9328 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.9781 * u, cx + 0.9812 * u, cy + 1 * u, cx + 0.9422 * u, cy + 1 * u)
      p.line_to(cx + 0.0578 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.0187 * u, cy + 1 * u, cx + 0 * u, cy + 0.9781 * u, cx + 0 * u, cy + 0.9328 * u)
      p.line_to(cx + 0 * u, cy + 0.5672 * u)
      p.bezier_curve_to(cx + 0 * u, cy + 0.5219 * u, cx + 0.0188 * u, cy + 0.5 * u, cx + 0.0578 * u, cy + 0.5 * u)
      p.close_path()
      p.move_to(cx + -0.2141 * u, cy + 0.0672 * u)
      p.bezier_curve_to(cx + -0.1828 * u, cy + 0.0672 * u, cx + -0.1578 * u, cy + 0.0359 * u, cx + -0.1578 * u, cy + 0 * u)
      p.bezier_curve_to(cx + -0.1578 * u, cy + -0.0375 * u, cx + -0.1828 * u, cy + -0.0672 * u, cx + -0.2141 * u, cy + -0.0672 * u)
      p.line_to(cx + -0.7297 * u, cy + -0.0672 * u)
      p.line_to(cx + -0.7297 * u, cy + -0.5 * u)
      p.line_to(cx + -0.6281 * u, cy + -0.5 * u)
      p.bezier_curve_to(cx + -0.5969 * u, cy + -0.5 * u, cx + -0.5719 * u, cy + -0.5313 * u, cx + -0.5719 * u, cy + -0.5672 * u)
      p.line_to(cx + -0.5719 * u, cy + -0.9328 * u)
      p.bezier_curve_to(cx + -0.5719 * u, cy + -0.9703 * u, cx + -0.5969 * u, cy + -1 * u, cx + -0.6281 * u, cy + -1 * u)
      p.line_to(cx + -0.9422 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.9734 * u, cy + -1 * u, cx + -1 * u, cy + -0.9687 * u, cx + -1 * u, cy + -0.9328 * u)
      p.line_to(cx + -1 * u, cy + -0.5672 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.5297 * u, cx + -0.975 * u, cy + -0.5 * u, cx + -0.9422 * u, cy + -0.5 * u)
      p.line_to(cx + -0.8437 * u, cy + -0.5 * u)
      p.line_to(cx + -0.8437 * u, cy + 0.75 * u)
      p.bezier_curve_to(cx + -0.8437 * u, cy + 0.7875 * u, cx + -0.8188 * u, cy + 0.8172 * u, cx + -0.7875 * u, cy + 0.8172 * u)
      p.line_to(cx + -0.2156 * u, cy + 0.8172 * u)
      p.bezier_curve_to(cx + -0.1844 * u, cy + 0.8172 * u, cx + -0.1594 * u, cy + 0.7859 * u, cx + -0.1594 * u, cy + 0.75 * u)
      p.bezier_curve_to(cx + -0.1594 * u, cy + 0.7125 * u, cx + -0.1844 * u, cy + 0.6828 * u, cx + -0.2156 * u, cy + 0.6828 * u)
      p.line_to(cx + -0.7313 * u, cy + 0.6828 * u)
      p.line_to(cx + -0.7313 * u, cy + 0.0672 * u)
      p.line_to(cx + -0.2156 * u, cy + 0.0672 * u)
      p.close_path()
      p.fill()
    }
    YhTable => { // 表格
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -1 * u, cy + -1 * u)
      p.line_to(cx + -1 * u, cy + 1 * u)
      p.line_to(cx + 1 * u, cy + 1 * u)
      p.line_to(cx + 1 * u, cy + -1 * u)
      p.line_to(cx + -1 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.875 * u, cy + -0.5 * u)
      p.line_to(cx + -0.375 * u, cy + -0.5 * u)
      p.line_to(cx + -0.375 * u, cy + -0.125 * u)
      p.line_to(cx + -0.875 * u, cy + -0.125 * u)
      p.line_to(cx + -0.875 * u, cy + -0.5 * u)
      p.close_path()
      p.move_to(cx + 0.25 * u, cy + -0.125 * u)
      p.line_to(cx + -0.25 * u, cy + -0.125 * u)
      p.line_to(cx + -0.25 * u, cy + -0.5 * u)
      p.line_to(cx + 0.25 * u, cy + -0.5 * u)
      p.line_to(cx + 0.25 * u, cy + -0.125 * u)
      p.close_path()
      p.move_to(cx + 0.25 * u, cy + 0 * u)
      p.line_to(cx + 0.25 * u, cy + 0.375 * u)
      p.line_to(cx + -0.25 * u, cy + 0.375 * u)
      p.line_to(cx + -0.25 * u, cy + 0 * u)
      p.line_to(cx + 0.25 * u, cy + 0 * u)
      p.close_path()
      p.move_to(cx + -0.875 * u, cy + 0 * u)
      p.line_to(cx + -0.375 * u, cy + 0 * u)
      p.line_to(cx + -0.375 * u, cy + 0.375 * u)
      p.line_to(cx + -0.875 * u, cy + 0.375 * u)
      p.line_to(cx + -0.875 * u, cy + 0 * u)
      p.close_path()
      p.move_to(cx + -0.875 * u, cy + 0.875 * u)
      p.line_to(cx + -0.875 * u, cy + 0.5 * u)
      p.line_to(cx + -0.375 * u, cy + 0.5 * u)
      p.line_to(cx + -0.375 * u, cy + 0.875 * u)
      p.line_to(cx + -0.875 * u, cy + 0.875 * u)
      p.close_path()
      p.move_to(cx + -0.25 * u, cy + 0.875 * u)
      p.line_to(cx + -0.25 * u, cy + 0.5 * u)
      p.line_to(cx + 0.25 * u, cy + 0.5 * u)
      p.line_to(cx + 0.25 * u, cy + 0.875 * u)
      p.line_to(cx + -0.25 * u, cy + 0.875 * u)
      p.close_path()
      p.move_to(cx + 0.875 * u, cy + 0.875 * u)
      p.line_to(cx + 0.375 * u, cy + 0.875 * u)
      p.line_to(cx + 0.375 * u, cy + 0.5 * u)
      p.line_to(cx + 0.875 * u, cy + 0.5 * u)
      p.line_to(cx + 0.875 * u, cy + 0.875 * u)
      p.close_path()
      p.move_to(cx + 0.875 * u, cy + 0.375 * u)
      p.line_to(cx + 0.375 * u, cy + 0.375 * u)
      p.line_to(cx + 0.375 * u, cy + 0 * u)
      p.line_to(cx + 0.875 * u, cy + 0 * u)
      p.line_to(cx + 0.875 * u, cy + 0.375 * u)
      p.close_path()
      p.move_to(cx + 0.875 * u, cy + -0.125 * u)
      p.line_to(cx + 0.375 * u, cy + -0.125 * u)
      p.line_to(cx + 0.375 * u, cy + -0.5 * u)
      p.line_to(cx + 0.875 * u, cy + -0.5 * u)
      p.line_to(cx + 0.875 * u, cy + -0.125 * u)
      p.close_path()
      p.move_to(cx + -0.875 * u, cy + -0.625 * u)
      p.line_to(cx + -0.875 * u, cy + -0.875 * u)
      p.line_to(cx + 0.875 * u, cy + -0.875 * u)
      p.line_to(cx + 0.875 * u, cy + -0.625 * u)
      p.line_to(cx + -0.875 * u, cy + -0.625 * u)
      p.close_path()
      p.fill()
    }
    YhTab => { // 标签页
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 1 * u, cy + 0.7337 * u)
      p.line_to(cx + 0.9976 * u, cy + 0.761 * u)
      p.line_to(cx + 0.9905 * u, cy + 0.7875 * u)
      p.line_to(cx + 0.9789 * u, cy + 0.8123 * u)
      p.line_to(cx + 0.9632 * u, cy + 0.8348 * u)
      p.line_to(cx + 0.9438 * u, cy + 0.8542 * u)
      p.line_to(cx + 0.9213 * u, cy + 0.8699 * u)
      p.line_to(cx + 0.8965 * u, cy + 0.8815 * u)
      p.line_to(cx + 0.87 * u, cy + 0.8886 * u)
      p.line_to(cx + 0.8427 * u, cy + 0.891 * u)
      p.line_to(cx + -0.8427 * u, cy + 0.891 * u)
      p.line_to(cx + -0.87 * u, cy + 0.8886 * u)
      p.line_to(cx + -0.8965 * u, cy + 0.8815 * u)
      p.line_to(cx + -0.9213 * u, cy + 0.8699 * u)
      p.line_to(cx + -0.9438 * u, cy + 0.8542 * u)
      p.line_to(cx + -0.9632 * u, cy + 0.8348 * u)
      p.line_to(cx + -0.9789 * u, cy + 0.8123 * u)
      p.line_to(cx + -0.9905 * u, cy + 0.7875 * u)
      p.line_to(cx + -0.9976 * u, cy + 0.761 * u)
      p.line_to(cx + -1 * u, cy + 0.7337 * u)
      p.line_to(cx + -1 * u, cy + -0.733 * u)
      p.line_to(cx + -0.9982 * u, cy + -0.7577 * u)
      p.line_to(cx + -0.9925 * u, cy + -0.7818 * u)
      p.line_to(cx + -0.9831 * u, cy + -0.8047 * u)
      p.line_to(cx + -0.9702 * u, cy + -0.8258 * u)
      p.line_to(cx + -0.9542 * u, cy + -0.8447 * u)
      p.line_to(cx + -0.9354 * u, cy + -0.8608 * u)
      p.line_to(cx + -0.9143 * u, cy + -0.8738 * u)
      p.line_to(cx + -0.8914 * u, cy + -0.8833 * u)
      p.line_to(cx + -0.8673 * u, cy + -0.8891 * u)
      p.line_to(cx + -0.8427 * u, cy + -0.891 * u)
      p.line_to(cx + -0.1687 * u, cy + -0.891 * u)
      p.line_to(cx + -0.1413 * u, cy + -0.8886 * u)
      p.line_to(cx + -0.1149 * u, cy + -0.8815 * u)
      p.line_to(cx + -0.09 * u, cy + -0.8699 * u)
      p.line_to(cx + -0.0675 * u, cy + -0.8542 * u)
      p.line_to(cx + -0.0481 * u, cy + -0.8348 * u)
      p.line_to(cx + -0.0324 * u, cy + -0.8123 * u)
      p.line_to(cx + -0.0208 * u, cy + -0.7875 * u)
      p.line_to(cx + -0.0137 * u, cy + -0.761 * u)
      p.line_to(cx + -0.0113 * u, cy + -0.7337 * u)
      p.line_to(cx + -0.0113 * u, cy + -0.7223 * u)
      p.line_to(cx + 0.8427 * u, cy + -0.7223 * u)
      p.line_to(cx + 0.8689 * u, cy + -0.7202 * u)
      p.line_to(cx + 0.8945 * u, cy + -0.7137 * u)
      p.line_to(cx + 0.9186 * u, cy + -0.703 * u)
      p.line_to(cx + 0.9405 * u, cy + -0.6884 * u)
      p.line_to(cx + 0.9598 * u, cy + -0.6704 * u)
      p.line_to(cx + 0.9757 * u, cy + -0.6495 * u)
      p.line_to(cx + 0.988 * u, cy + -0.6261 * u)
      p.line_to(cx + 0.9961 * u, cy + -0.6011 * u)
      p.line_to(cx + 1 * u, cy + -0.575 * u)
      p.line_to(cx + 1 * u, cy + 0.7337 * u)
      p.close_path()
      p.move_to(cx + 0.91 * u, cy + -0.3517 * u)
      p.line_to(cx + -0.91 * u, cy + -0.3517 * u)
      p.line_to(cx + -0.91 * u, cy + 0.7337 * u)
      p.line_to(cx + -0.9091 * u, cy + 0.7446 * u)
      p.line_to(cx + -0.9065 * u, cy + 0.7553 * u)
      p.line_to(cx + -0.9021 * u, cy + 0.7654 * u)
      p.line_to(cx + -0.8962 * u, cy + 0.7746 * u)
      p.line_to(cx + -0.8888 * u, cy + 0.7827 * u)
      p.line_to(cx + -0.8801 * u, cy + 0.7895 * u)
      p.line_to(cx + -0.8705 * u, cy + 0.7948 * u)
      p.line_to(cx + -0.8602 * u, cy + 0.7984 * u)
      p.line_to(cx + -0.8493 * u, cy + 0.8003 * u)
      p.line_to(cx + 0.8427 * u, cy + 0.8003 * u)
      p.line_to(cx + 0.8542 * u, cy + 0.7993 * u)
      p.line_to(cx + 0.8655 * u, cy + 0.7963 * u)
      p.line_to(cx + 0.876 * u, cy + 0.7914 * u)
      p.line_to(cx + 0.8855 * u, cy + 0.7847 * u)
      p.line_to(cx + 0.8937 * u, cy + 0.7765 * u)
      p.line_to(cx + 0.9004 * u, cy + 0.767 * u)
      p.line_to(cx + 0.9053 * u, cy + 0.7565 * u)
      p.line_to(cx + 0.9083 * u, cy + 0.7452 * u)
      p.line_to(cx + 0.9093 * u, cy + 0.7337 * u)
      p.line_to(cx + 0.9093 * u, cy + -0.3517 * u)
      p.close_path()
      p.move_to(cx + -0.1687 * u, cy + -0.801 * u)
      p.line_to(cx + -0.8427 * u, cy + -0.801 * u)
      p.line_to(cx + -0.8531 * u, cy + -0.8002 * u)
      p.line_to(cx + -0.8633 * u, cy + -0.7977 * u)
      p.line_to(cx + -0.8729 * u, cy + -0.7937 * u)
      p.line_to(cx + -0.8819 * u, cy + -0.7883 * u)
      p.line_to(cx + -0.8898 * u, cy + -0.7815 * u)
      p.line_to(cx + -0.8966 * u, cy + -0.7735 * u)
      p.line_to(cx + -0.9021 * u, cy + -0.7646 * u)
      p.line_to(cx + -0.9061 * u, cy + -0.7549 * u)
      p.line_to(cx + -0.9085 * u, cy + -0.7448 * u)
      p.line_to(cx + -0.9093 * u, cy + -0.7343 * u)
      p.line_to(cx + -0.9093 * u, cy + -0.4417 * u)
      p.line_to(cx + -0.1013 * u, cy + -0.4417 * u)
      p.line_to(cx + -0.1013 * u, cy + -0.7337 * u)
      p.line_to(cx + -0.1022 * u, cy + -0.7446 * u)
      p.line_to(cx + -0.1048 * u, cy + -0.7552 * u)
      p.line_to(cx + -0.1091 * u, cy + -0.7652 * u)
      p.line_to(cx + -0.115 * u, cy + -0.7744 * u)
      p.line_to(cx + -0.1223 * u, cy + -0.7825 * u)
      p.line_to(cx + -0.1308 * u, cy + -0.7893 * u)
      p.line_to(cx + -0.1403 * u, cy + -0.7947 * u)
      p.line_to(cx + -0.1506 * u, cy + -0.7984 * u)
      p.line_to(cx + -0.1613 * u, cy + -0.8003 * u)
      p.close_path()
      p.move_to(cx + 0.4047 * u, cy + -0.6323 * u)
      p.line_to(cx + -0.0113 * u, cy + -0.6323 * u)
      p.line_to(cx + -0.0113 * u, cy + -0.4417 * u)
      p.line_to(cx + 0.4047 * u, cy + -0.4417 * u)
      p.line_to(cx + 0.4047 * u, cy + -0.6323 * u)
      p.close_path()
      p.move_to(cx + 0.8427 * u, cy + -0.6323 * u)
      p.line_to(cx + 0.4947 * u, cy + -0.6323 * u)
      p.line_to(cx + 0.4947 * u, cy + -0.4417 * u)
      p.line_to(cx + 0.91 * u, cy + -0.4417 * u)
      p.line_to(cx + 0.91 * u, cy + -0.565 * u)
      p.line_to(cx + 0.9091 * u, cy + -0.576 * u)
      p.line_to(cx + 0.9065 * u, cy + -0.5866 * u)
      p.line_to(cx + 0.9021 * u, cy + -0.5967 * u)
      p.line_to(cx + 0.8962 * u, cy + -0.6059 * u)
      p.line_to(cx + 0.8888 * u, cy + -0.614 * u)
      p.line_to(cx + 0.8801 * u, cy + -0.6209 * u)
      p.line_to(cx + 0.8705 * u, cy + -0.6261 * u)
      p.line_to(cx + 0.8602 * u, cy + -0.6298 * u)
      p.line_to(cx + 0.8493 * u, cy + -0.6317 * u)
      p.close_path()
      p.fill()
    }
    YhTextField => { // 单行输入框
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.8571 * u, cy + -0.6429 * u)
      p.line_to(cx + -0.8571 * u, cy + -0.6429 * u)
      p.bezier_curve_to(cx + -0.9357 * u, cy + -0.6429 * u, cx + -1 * u, cy + -0.5786 * u, cx + -1 * u, cy + -0.5 * u)
      p.line_to(cx + -1 * u, cy + 0.5 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.5786 * u, cx + -0.9357 * u, cy + 0.6429 * u, cx + -0.8571 * u, cy + 0.6429 * u)
      p.line_to(cx + 0.8571 * u, cy + 0.6429 * u)
      p.bezier_curve_to(cx + 0.9357 * u, cy + 0.6429 * u, cx + 1 * u, cy + 0.5786 * u, cx + 1 * u, cy + 0.5 * u)
      p.line_to(cx + 1 * u, cy + -0.5 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.5786 * u, cx + 0.9357 * u, cy + -0.6429 * u, cx + 0.8571 * u, cy + -0.6429 * u)
      p.close_path()
      p.move_to(cx + 0.8571 * u, cy + 0.4286 * u)
      p.bezier_curve_to(cx + 0.8571 * u, cy + 0.4714 * u, cx + 0.8286 * u, cy + 0.5 * u, cx + 0.7857 * u, cy + 0.5 * u)
      p.line_to(cx + -0.7857 * u, cy + 0.5 * u)
      p.bezier_curve_to(cx + -0.8286 * u, cy + 0.5 * u, cx + -0.8571 * u, cy + 0.4714 * u, cx + -0.8571 * u, cy + 0.4286 * u)
      p.line_to(cx + -0.8571 * u, cy + -0.4286 * u)
      p.bezier_curve_to(cx + -0.8571 * u, cy + -0.4714 * u, cx + -0.8286 * u, cy + -0.5 * u, cx + -0.7857 * u, cy + -0.5 * u)
      p.line_to(cx + 0.7857 * u, cy + -0.5 * u)
      p.bezier_curve_to(cx + 0.8286 * u, cy + -0.5 * u, cx + 0.8571 * u, cy + -0.4714 * u, cx + 0.8571 * u, cy + -0.4286 * u)
      p.line_to(cx + 0.8571 * u, cy + 0.4286 * u)
      p.close_path()
      p.move_to(cx + -0.6429 * u, cy + -0.3571 * u)
      p.bezier_curve_to(cx + -0.6857 * u, cy + -0.3571 * u, cx + -0.7143 * u, cy + -0.3286 * u, cx + -0.7143 * u, cy + -0.2857 * u)
      p.line_to(cx + -0.7143 * u, cy + 0.2857 * u)
      p.bezier_curve_to(cx + -0.7143 * u, cy + 0.3214 * u, cx + -0.6857 * u, cy + 0.3571 * u, cx + -0.6429 * u, cy + 0.3571 * u)
      p.bezier_curve_to(cx + -0.6 * u, cy + 0.3571 * u, cx + -0.5714 * u, cy + 0.3286 * u, cx + -0.5714 * u, cy + 0.2857 * u)
      p.line_to(cx + -0.5714 * u, cy + -0.2857 * u)
      p.bezier_curve_to(cx + -0.5714 * u, cy + -0.3214 * u, cx + -0.6 * u, cy + -0.3571 * u, cx + -0.6429 * u, cy + -0.3571 * u)
      p.close_path()
      p.fill()
    }
    YhTextarea => { // 多行输入框
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.8571 * u, cy + -0.7857 * u)
      p.line_to(cx + -0.8571 * u, cy + -0.7857 * u)
      p.bezier_curve_to(cx + -0.9357 * u, cy + -0.7857 * u, cx + -1 * u, cy + -0.7214 * u, cx + -1 * u, cy + -0.6429 * u)
      p.line_to(cx + -1 * u, cy + 0.6429 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.7214 * u, cx + -0.9357 * u, cy + 0.7857 * u, cx + -0.8571 * u, cy + 0.7857 * u)
      p.line_to(cx + 0.8571 * u, cy + 0.7857 * u)
      p.bezier_curve_to(cx + 0.9357 * u, cy + 0.7857 * u, cx + 1 * u, cy + 0.7214 * u, cx + 1 * u, cy + 0.6429 * u)
      p.line_to(cx + 1 * u, cy + -0.6429 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.7214 * u, cx + 0.9357 * u, cy + -0.7857 * u, cx + 0.8571 * u, cy + -0.7857 * u)
      p.close_path()
      p.move_to(cx + 0.8571 * u, cy + 0.5714 * u)
      p.bezier_curve_to(cx + 0.8571 * u, cy + 0.6071 * u, cx + 0.8286 * u, cy + 0.6429 * u, cx + 0.7857 * u, cy + 0.6429 * u)
      p.line_to(cx + -0.7857 * u, cy + 0.6429 * u)
      p.bezier_curve_to(cx + -0.8286 * u, cy + 0.6429 * u, cx + -0.8571 * u, cy + 0.6143 * u, cx + -0.8571 * u, cy + 0.5714 * u)
      p.line_to(cx + -0.8571 * u, cy + -0.5714 * u)
      p.bezier_curve_to(cx + -0.8571 * u, cy + -0.6071 * u, cx + -0.8286 * u, cy + -0.6429 * u, cx + -0.7857 * u, cy + -0.6429 * u)
      p.line_to(cx + 0.7857 * u, cy + -0.6429 * u)
      p.bezier_curve_to(cx + 0.8286 * u, cy + -0.6429 * u, cx + 0.8571 * u, cy + -0.6143 * u, cx + 0.8571 * u, cy + -0.5714 * u)
      p.line_to(cx + 0.8571 * u, cy + 0.5714 * u)
      p.close_path()
      p.move_to(cx + -0.6429 * u, cy + -0.5 * u)
      p.bezier_curve_to(cx + -0.6857 * u, cy + -0.5 * u, cx + -0.7143 * u, cy + -0.4714 * u, cx + -0.7143 * u, cy + -0.4286 * u)
      p.line_to(cx + -0.7143 * u, cy + 0.1429 * u)
      p.bezier_curve_to(cx + -0.7143 * u, cy + 0.1786 * u, cx + -0.6857 * u, cy + 0.2143 * u, cx + -0.6429 * u, cy + 0.2143 * u)
      p.bezier_curve_to(cx + -0.6 * u, cy + 0.2143 * u, cx + -0.5714 * u, cy + 0.1857 * u, cx + -0.5714 * u, cy + 0.1429 * u)
      p.line_to(cx + -0.5714 * u, cy + -0.4286 * u)
      p.bezier_curve_to(cx + -0.5714 * u, cy + -0.4643 * u, cx + -0.6 * u, cy + -0.5 * u, cx + -0.6429 * u, cy + -0.5 * u)
      p.close_path()
      p.move_to(cx + 0.7143 * u, cy + 0.5714 * u)
      p.bezier_curve_to(cx + 0.7571 * u, cy + 0.5714 * u, cx + 0.7857 * u, cy + 0.5429 * u, cx + 0.7857 * u, cy + 0.5 * u)
      p.line_to(cx + 0.7857 * u, cy + 0.2143 * u)
      p.line_to(cx + 0.4286 * u, cy + 0.5714 * u)
      p.line_to(cx + 0.7143 * u, cy + 0.5714 * u)
      p.close_path()
      p.fill()
    }
    YhNumberField => { // 数字输入框
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.8571 * u, cy + -0.7143 * u)
      p.line_to(cx + 0.8819 * u, cy + -0.7121 * u)
      p.line_to(cx + 0.906 * u, cy + -0.7057 * u)
      p.line_to(cx + 0.9286 * u, cy + -0.6951 * u)
      p.line_to(cx + 0.949 * u, cy + -0.6809 * u)
      p.line_to(cx + 0.9666 * u, cy + -0.6633 * u)
      p.line_to(cx + 0.9809 * u, cy + -0.6429 * u)
      p.line_to(cx + 0.9914 * u, cy + -0.6203 * u)
      p.line_to(cx + 0.9978 * u, cy + -0.5962 * u)
      p.line_to(cx + 1 * u, cy + -0.5714 * u)
      p.line_to(cx + 1 * u, cy + 0.5714 * u)
      p.line_to(cx + 0.9978 * u, cy + 0.5962 * u)
      p.line_to(cx + 0.9914 * u, cy + 0.6203 * u)
      p.line_to(cx + 0.9809 * u, cy + 0.6429 * u)
      p.line_to(cx + 0.9666 * u, cy + 0.6633 * u)
      p.line_to(cx + 0.949 * u, cy + 0.6809 * u)
      p.line_to(cx + 0.9286 * u, cy + 0.6951 * u)
      p.line_to(cx + 0.906 * u, cy + 0.7057 * u)
      p.line_to(cx + 0.8819 * u, cy + 0.7121 * u)
      p.line_to(cx + 0.8571 * u, cy + 0.7143 * u)
      p.line_to(cx + -0.8571 * u, cy + 0.7143 * u)
      p.line_to(cx + -0.8819 * u, cy + 0.7121 * u)
      p.line_to(cx + -0.906 * u, cy + 0.7057 * u)
      p.line_to(cx + -0.9286 * u, cy + 0.6951 * u)
      p.line_to(cx + -0.949 * u, cy + 0.6809 * u)
      p.line_to(cx + -0.9666 * u, cy + 0.6633 * u)
      p.line_to(cx + -0.9809 * u, cy + 0.6429 * u)
      p.line_to(cx + -0.9914 * u, cy + 0.6203 * u)
      p.line_to(cx + -0.9978 * u, cy + 0.5962 * u)
      p.line_to(cx + -1 * u, cy + 0.5714 * u)
      p.line_to(cx + -1 * u, cy + -0.5714 * u)
      p.line_to(cx + -0.9978 * u, cy + -0.5962 * u)
      p.line_to(cx + -0.9914 * u, cy + -0.6203 * u)
      p.line_to(cx + -0.9809 * u, cy + -0.6429 * u)
      p.line_to(cx + -0.9666 * u, cy + -0.6633 * u)
      p.line_to(cx + -0.949 * u, cy + -0.6809 * u)
      p.line_to(cx + -0.9286 * u, cy + -0.6951 * u)
      p.line_to(cx + -0.906 * u, cy + -0.7057 * u)
      p.line_to(cx + -0.8819 * u, cy + -0.7121 * u)
      p.line_to(cx + -0.8571 * u, cy + -0.7143 * u)
      p.line_to(cx + 0.8571 * u, cy + -0.7143 * u)
      p.close_path()
      p.move_to(cx + 0.7857 * u, cy + -0.5714 * u)
      p.line_to(cx + -0.7857 * u, cy + -0.5714 * u)
      p.line_to(cx + -0.7972 * u, cy + -0.5705 * u)
      p.line_to(cx + -0.8084 * u, cy + -0.5677 * u)
      p.line_to(cx + -0.819 * u, cy + -0.5632 * u)
      p.line_to(cx + -0.8287 * u, cy + -0.557 * u)
      p.line_to(cx + -0.8373 * u, cy + -0.5494 * u)
      p.line_to(cx + -0.8446 * u, cy + -0.5404 * u)
      p.line_to(cx + -0.8503 * u, cy + -0.5304 * u)
      p.line_to(cx + -0.8544 * u, cy + -0.5197 * u)
      p.line_to(cx + -0.8566 * u, cy + -0.5084 * u)
      p.line_to(cx + -0.8571 * u, cy + -0.5 * u)
      p.line_to(cx + -0.8571 * u, cy + 0.5 * u)
      p.line_to(cx + -0.8562 * u, cy + 0.5115 * u)
      p.line_to(cx + -0.8534 * u, cy + 0.5227 * u)
      p.line_to(cx + -0.8489 * u, cy + 0.5333 * u)
      p.line_to(cx + -0.8427 * u, cy + 0.543 * u)
      p.line_to(cx + -0.8351 * u, cy + 0.5516 * u)
      p.line_to(cx + -0.8261 * u, cy + 0.5589 * u)
      p.line_to(cx + -0.8162 * u, cy + 0.5646 * u)
      p.line_to(cx + -0.8054 * u, cy + 0.5687 * u)
      p.line_to(cx + -0.7941 * u, cy + 0.5709 * u)
      p.line_to(cx + -0.7857 * u, cy + 0.5714 * u)
      p.line_to(cx + 0.7857 * u, cy + 0.5714 * u)
      p.line_to(cx + 0.7972 * u, cy + 0.5705 * u)
      p.line_to(cx + 0.8084 * u, cy + 0.5677 * u)
      p.line_to(cx + 0.819 * u, cy + 0.5632 * u)
      p.line_to(cx + 0.8287 * u, cy + 0.557 * u)
      p.line_to(cx + 0.8373 * u, cy + 0.5494 * u)
      p.line_to(cx + 0.8446 * u, cy + 0.5404 * u)
      p.line_to(cx + 0.8503 * u, cy + 0.5304 * u)
      p.line_to(cx + 0.8544 * u, cy + 0.5197 * u)
      p.line_to(cx + 0.8566 * u, cy + 0.5084 * u)
      p.line_to(cx + 0.8571 * u, cy + 0.5 * u)
      p.line_to(cx + 0.8571 * u, cy + -0.5 * u)
      p.line_to(cx + 0.8561 * u, cy + -0.5124 * u)
      p.line_to(cx + 0.8528 * u, cy + -0.5244 * u)
      p.line_to(cx + 0.8476 * u, cy + -0.5357 * u)
      p.line_to(cx + 0.8404 * u, cy + -0.5459 * u)
      p.line_to(cx + 0.8316 * u, cy + -0.5547 * u)
      p.line_to(cx + 0.8214 * u, cy + -0.5619 * u)
      p.line_to(cx + 0.8101 * u, cy + -0.5671 * u)
      p.line_to(cx + 0.7981 * u, cy + -0.5703 * u)
      p.line_to(cx + 0.7857 * u, cy + -0.5714 * u)
      p.close_path()
      p.move_to(cx + 0.5309 * u, cy + -0.3929 * u)
      p.line_to(cx + 0.5641 * u, cy + -0.3902 * u)
      p.line_to(cx + 0.5964 * u, cy + -0.3824 * u)
      p.line_to(cx + 0.6272 * u, cy + -0.3695 * u)
      p.line_to(cx + 0.6556 * u, cy + -0.3521 * u)
      p.line_to(cx + 0.6809 * u, cy + -0.3304 * u)
      p.line_to(cx + 0.7024 * u, cy + -0.305 * u)
      p.line_to(cx + 0.7198 * u, cy + -0.2766 * u)
      p.line_to(cx + 0.7325 * u, cy + -0.2458 * u)
      p.line_to(cx + 0.7402 * u, cy + -0.2134 * u)
      p.line_to(cx + 0.7427 * u, cy + -0.1801 * u)
      p.bezier_curve_to(cx + 0.7427 * u, cy + -0.1287 * u, cx + 0.7244 * u, cy + -0.0814 * u, cx + 0.6941 * u, cy + -0.0446 * u)
      p.line_to(cx + 0.7212 * u, cy + -0.02 * u)
      p.line_to(cx + 0.7442 * u, cy + 0.0084 * u)
      p.line_to(cx + 0.7628 * u, cy + 0.0399 * u)
      p.line_to(cx + 0.7763 * u, cy + 0.0739 * u)
      p.line_to(cx + 0.7846 * u, cy + 0.1095 * u)
      p.line_to(cx + 0.7875 * u, cy + 0.146 * u)
      p.bezier_curve_to(cx + 0.7875 * u, cy + 0.2824 * u, cx + 0.6729 * u, cy + 0.3929 * u, cx + 0.5316 * u, cy + 0.3929 * u)
      p.bezier_curve_to(cx + 0.396 * u, cy + 0.3929 * u, cx + 0.285 * u, cy + 0.2911 * u, cx + 0.2761 * u, cy + 0.1626 * u)
      p.line_to(cx + 0.4186 * u, cy + 0.1626 * u)
      p.bezier_curve_to(cx + 0.4271 * u, cy + 0.2138 * u, cx + 0.4744 * u, cy + 0.253 * u, cx + 0.5316 * u, cy + 0.253 * u)
      p.bezier_curve_to(cx + 0.5947 * u, cy + 0.253 * u, cx + 0.6459 * u, cy + 0.2051 * u, cx + 0.6459 * u, cy + 0.146 * u)
      p.bezier_curve_to(cx + 0.6459 * u, cy + 0.0869 * u, cx + 0.5947 * u, cy + 0.039 * u, cx + 0.5316 * u, cy + 0.039 * u)
      p.bezier_curve_to(cx + 0.5204 * u, cy + 0.039 * u, cx + 0.5096 * u, cy + 0.0405 * u, cx + 0.4994 * u, cy + 0.0433 * u)
      p.line_to(cx + 0.4994 * u, cy + -0.0989 * u)
      p.bezier_curve_to(cx + 0.508 * u, cy + -0.1 * u, cx + 0.5169 * u, cy + -0.1006 * u, cx + 0.5257 * u, cy + -0.1008 * u)
      p.line_to(cx + 0.5258 * u, cy + -0.1014 * u)
      p.line_to(cx + 0.5309 * u, cy + -0.1012 * u)
      p.bezier_curve_to(cx + 0.5728 * u, cy + -0.1012 * u, cx + 0.6067 * u, cy + -0.1366 * u, cx + 0.6067 * u, cy + -0.1801 * u)
      p.bezier_curve_to(cx + 0.6067 * u, cy + -0.2238 * u, cx + 0.5728 * u, cy + -0.2591 * u, cx + 0.5309 * u, cy + -0.2591 * u)
      p.bezier_curve_to(cx + 0.4987 * u, cy + -0.2591 * u, cx + 0.4711 * u, cy + -0.2382 * u, cx + 0.4601 * u, cy + -0.2087 * u)
      p.line_to(cx + 0.321 * u, cy + -0.2087 * u)
      p.line_to(cx + 0.3281 * u, cy + -0.2418 * u)
      p.line_to(cx + 0.3404 * u, cy + -0.2733 * u)
      p.line_to(cx + 0.3575 * u, cy + -0.3024 * u)
      p.line_to(cx + 0.3791 * u, cy + -0.3285 * u)
      p.line_to(cx + 0.4045 * u, cy + -0.3508 * u)
      p.line_to(cx + 0.4332 * u, cy + -0.3688 * u)
      p.line_to(cx + 0.4643 * u, cy + -0.382 * u)
      p.line_to(cx + 0.4971 * u, cy + -0.3901 * u)
      p.line_to(cx + 0.5309 * u, cy + -0.3929 * u)
      p.close_path()
      p.move_to(cx + -0.0002 * u, cy + -0.3929 * u)
      p.bezier_curve_to(cx + 0.1181 * u, cy + -0.3929 * u, cx + 0.2141 * u, cy + -0.2977 * u, cx + 0.2141 * u, cy + -0.1804 * u)
      p.bezier_curve_to(cx + 0.2141 * u, cy + -0.1388 * u, cx + 0.202 * u, cy + -0.0999 * u, cx + 0.1812 * u, cy + -0.0671 * u)
      p.line_to(cx + 0.1814 * u, cy + -0.0671 * u)
      p.line_to(cx + -0.0431 * u, cy + 0.25 * u)
      p.line_to(cx + 0.2179 * u, cy + 0.25 * u)
      p.line_to(cx + 0.2179 * u, cy + 0.3929 * u)
      p.line_to(cx + -0.215 * u, cy + 0.3929 * u)
      p.line_to(cx + -0.215 * u, cy + 0.25 * u)
      p.line_to(cx + 0.0586 * u, cy + -0.1366 * u)
      p.line_to(cx + 0.0571 * u, cy + -0.137 * u)
      p.line_to(cx + 0.0634 * u, cy + -0.1468 * u)
      p.line_to(cx + 0.0681 * u, cy + -0.1574 * u)
      p.line_to(cx + 0.0709 * u, cy + -0.1687 * u)
      p.line_to(cx + 0.0719 * u, cy + -0.1804 * u)
      p.bezier_curve_to(cx + 0.0719 * u, cy + -0.2198 * u, cx + 0.0396 * u, cy + -0.2518 * u, cx + -0.0002 * u, cy + -0.2518 * u)
      p.line_to(cx + -0.0125 * u, cy + -0.2508 * u)
      p.line_to(cx + -0.0244 * u, cy + -0.2477 * u)
      p.line_to(cx + -0.0356 * u, cy + -0.2426 * u)
      p.line_to(cx + -0.0457 * u, cy + -0.2357 * u)
      p.line_to(cx + -0.0546 * u, cy + -0.2272 * u)
      p.line_to(cx + -0.0618 * u, cy + -0.2172 * u)
      p.line_to(cx + -0.0673 * u, cy + -0.2062 * u)
      p.line_to(cx + -0.0708 * u, cy + -0.1944 * u)
      p.line_to(cx + -0.0722 * u, cy + -0.1822 * u)
      p.line_to(cx + -0.0715 * u, cy + -0.1699 * u)
      p.line_to(cx + -0.0781 * u, cy + -0.1717 * u)
      p.line_to(cx + -0.2143 * u, cy + -0.1716 * u)
      p.line_to(cx + -0.2144 * u, cy + -0.176 * u)
      p.line_to(cx + -0.2145 * u, cy + -0.1804 * u)
      p.bezier_curve_to(cx + -0.2145 * u, cy + -0.2977 * u, cx + -0.1186 * u, cy + -0.3929 * u, cx + -0.0002 * u, cy + -0.3929 * u)
      p.close_path()
      p.move_to(cx + -0.4464 * u, cy + -0.3921 * u)
      p.line_to(cx + -0.4464 * u, cy + 0.3921 * u)
      p.line_to(cx + -0.5893 * u, cy + 0.3921 * u)
      p.line_to(cx + -0.5893 * u, cy + -0.2493 * u)
      p.line_to(cx + -0.7321 * u, cy + -0.1779 * u)
      p.line_to(cx + -0.7321 * u, cy + -0.3207 * u)
      p.line_to(cx + -0.5893 * u, cy + -0.3921 * u)
      p.line_to(cx + -0.4464 * u, cy + -0.3921 * u)
      p.close_path()
      p.fill()
    }
    YhSelectField => { // 下拉多选
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.9512 * u, cy + -0.9512 * u)
      p.line_to(cx + 0.4146 * u, cy + -0.9512 * u)
      p.line_to(cx + 0.4146 * u, cy + -0.7561 * u)
      p.line_to(cx + -0.9512 * u, cy + -0.7561 * u)
      p.line_to(cx + -0.9512 * u, cy + -0.9512 * u)
      p.close_path()
      p.move_to(cx + -0.561 * u, cy + -0.1707 * u)
      p.line_to(cx + 1 * u, cy + -0.1707 * u)
      p.line_to(cx + 1 * u, cy + 0.0244 * u)
      p.line_to(cx + -0.561 * u, cy + 0.0244 * u)
      p.line_to(cx + -0.561 * u, cy + -0.1707 * u)
      p.close_path()
      p.move_to(cx + -0.561 * u, cy + 0.7073 * u)
      p.line_to(cx + 1 * u, cy + 0.7073 * u)
      p.line_to(cx + 1 * u, cy + 0.9024 * u)
      p.line_to(cx + -0.561 * u, cy + 0.9024 * u)
      p.line_to(cx + -0.561 * u, cy + 0.7073 * u)
      p.close_path()
      p.move_to(cx + 0.8049 * u, cy + -0.7561 * u)
      p.line_to(cx + 1 * u, cy + -0.9512 * u)
      p.line_to(cx + 0.6098 * u, cy + -0.9512 * u)
      p.line_to(cx + 0.8049 * u, cy + -0.7561 * u)
      p.close_path()
      p.move_to(cx + -1 * u, cy + -0.2195 * u)
      p.line_to(cx + -0.7073 * u, cy + -0.2195 * u)
      p.line_to(cx + -0.7073 * u, cy + 0.0732 * u)
      p.line_to(cx + -1 * u, cy + 0.0732 * u)
      p.line_to(cx + -1 * u, cy + -0.2195 * u)
      p.close_path()
      p.move_to(cx + -0.9024 * u, cy + -0.122 * u)
      p.line_to(cx + -0.9024 * u, cy + -0.0244 * u)
      p.line_to(cx + -0.8049 * u, cy + -0.0244 * u)
      p.line_to(cx + -0.8049 * u, cy + -0.122 * u)
      p.line_to(cx + -0.9024 * u, cy + -0.122 * u)
      p.close_path()
      p.move_to(cx + -1 * u, cy + 0.6585 * u)
      p.line_to(cx + -0.7073 * u, cy + 0.6585 * u)
      p.line_to(cx + -0.7073 * u, cy + 0.9512 * u)
      p.line_to(cx + -1 * u, cy + 0.9512 * u)
      p.line_to(cx + -1 * u, cy + 0.6585 * u)
      p.close_path()
      p.move_to(cx + -0.9024 * u, cy + 0.7561 * u)
      p.line_to(cx + -0.9024 * u, cy + 0.8537 * u)
      p.line_to(cx + -0.8049 * u, cy + 0.8537 * u)
      p.line_to(cx + -0.8049 * u, cy + 0.7561 * u)
      p.line_to(cx + -0.9024 * u, cy + 0.7561 * u)
      p.close_path()
      p.fill()
    }
    YhEditTable => { // 可编辑表格
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9286 * u, cy + -0.7857 * u)
      p.line_to(cx + -0.9286 * u, cy + -0.7857 * u)
      p.bezier_curve_to(cx + -0.9681 * u, cy + -0.7857 * u, cx + -1 * u, cy + -0.7538 * u, cx + -1 * u, cy + -0.7143 * u)
      p.line_to(cx + -1 * u, cy + 0.7143 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.7538 * u, cx + -0.9681 * u, cy + 0.7857 * u, cx + -0.9286 * u, cy + 0.7857 * u)
      p.line_to(cx + 0.9286 * u, cy + 0.7857 * u)
      p.bezier_curve_to(cx + 0.9681 * u, cy + 0.7857 * u, cx + 1 * u, cy + 0.7538 * u, cx + 1 * u, cy + 0.7143 * u)
      p.line_to(cx + 1 * u, cy + -0.7143 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.7538 * u, cx + 0.9681 * u, cy + -0.7857 * u, cx + 0.9286 * u, cy + -0.7857 * u)
      p.close_path()
      p.move_to(cx + 0.8393 * u, cy + -0.625 * u)
      p.line_to(cx + 0.8393 * u, cy + -0.3214 * u)
      p.line_to(cx + -0.8393 * u, cy + -0.3214 * u)
      p.line_to(cx + -0.8393 * u, cy + -0.625 * u)
      p.line_to(cx + 0.8393 * u, cy + -0.625 * u)
      p.close_path()
      p.move_to(cx + -0.2232 * u, cy + 0.1786 * u)
      p.line_to(cx + -0.2232 * u, cy + -0.1786 * u)
      p.line_to(cx + 0.8393 * u, cy + -0.1786 * u)
      p.line_to(cx + 0.8393 * u, cy + 0.625 * u)
      p.line_to(cx + -0.2232 * u, cy + 0.625 * u)
      p.line_to(cx + -0.2232 * u, cy + 0.1786 * u)
      p.close_path()
      p.move_to(cx + -0.8393 * u, cy + -0.1786 * u)
      p.line_to(cx + -0.3661 * u, cy + -0.1786 * u)
      p.line_to(cx + -0.3661 * u, cy + 0.1786 * u)
      p.line_to(cx + -0.8393 * u, cy + 0.1786 * u)
      p.line_to(cx + -0.8393 * u, cy + -0.1786 * u)
      p.close_path()
      p.move_to(cx + -0.8393 * u, cy + 0.3214 * u)
      p.line_to(cx + -0.3661 * u, cy + 0.3214 * u)
      p.line_to(cx + -0.3661 * u, cy + 0.625 * u)
      p.line_to(cx + -0.8393 * u, cy + 0.625 * u)
      p.line_to(cx + -0.8393 * u, cy + 0.3214 * u)
      p.close_path()
      p.move_to(cx + 0.625 * u, cy + 0.0167 * u)
      p.line_to(cx + 0.1288 * u, cy + 0.5129 * u)
      p.bezier_curve_to(cx + 0.1009 * u, cy + 0.5408 * u, cx + 0.0556 * u, cy + 0.5408 * u, cx + 0.0277 * u, cy + 0.5129 * u)
      p.bezier_curve_to(cx + -0.0002 * u, cy + 0.485 * u, cx + -0.0002 * u, cy + 0.4397 * u, cx + 0.0277 * u, cy + 0.4118 * u)
      p.line_to(cx + 0.5237 * u, cy + -0.0842 * u)
      p.bezier_curve_to(cx + 0.5516 * u, cy + -0.1121 * u, cx + 0.5969 * u, cy + -0.1121 * u, cx + 0.6248 * u, cy + -0.0842 * u)
      p.bezier_curve_to(cx + 0.6527 * u, cy + -0.0562 * u, cx + 0.6527 * u, cy + -0.0112 * u, cx + 0.625 * u, cy + 0.0167 * u)
      p.close_path()
      p.fill()
    }
    YhScript => { // script
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.3407 * u, cy + -0.6378 * u)
      p.bezier_curve_to(cx + 0.3439 * u, cy + -0.637 * u, cx + 0.3469 * u, cy + -0.6361 * u, cx + 0.35 * u, cy + -0.6352 * u)
      p.bezier_curve_to(cx + 0.3949 * u, cy + -0.6226 * u, cx + 0.416 * u, cy + -0.5713 * u, cx + 0.3929 * u, cy + -0.5312 * u)
      p.bezier_curve_to(cx + 0.3502 * u, cy + -0.4565 * u, cx + 0.307 * u, cy + -0.3821 * u, cx + 0.2639 * u, cy + -0.3077 * u)
      p.bezier_curve_to(cx + 0.0899 * u, cy + -0.0063 * u, cx + -0.0841 * u, cy + 0.295 * u, cx + -0.258 * u, cy + 0.5966 * u)
      p.bezier_curve_to(cx + -0.265 * u, cy + 0.6088 * u, cx + -0.2733 * u, cy + 0.6194 * u, cx + -0.2854 * u, cy + 0.6267 * u)
      p.bezier_curve_to(cx + -0.2931 * u, cy + 0.6314 * u, cx + -0.3017 * u, cy + 0.6342 * u, cx + -0.3104 * u, cy + 0.6364 * u)
      p.bezier_curve_to(cx + -0.3115 * u, cy + 0.6367 * u, cx + -0.3127 * u, cy + 0.6372 * u, cx + -0.3137 * u, cy + 0.6378 * u)
      p.bezier_curve_to(cx + -0.3198 * u, cy + 0.6378 * u, cx + -0.326 * u, cy + 0.6378 * u, cx + -0.3321 * u, cy + 0.6378 * u)
      p.bezier_curve_to(cx + -0.3344 * u, cy + 0.637 * u, cx + -0.3367 * u, cy + 0.6361 * u, cx + -0.339 * u, cy + 0.6355 * u)
      p.bezier_curve_to(cx + -0.3735 * u, cy + 0.6271 * u, cx + -0.3962 * u, cy + 0.5972 * u, cx + -0.3947 * u, cy + 0.562 * u)
      p.bezier_curve_to(cx + -0.3942 * u, cy + 0.5508 * u, cx + -0.3911 * u, cy + 0.5402 * u, cx + -0.3855 * u, cy + 0.5304 * u)
      p.bezier_curve_to(cx + -0.2569 * u, cy + 0.3075 * u, cx + -0.1281 * u, cy + 0.0847 * u, cx + 0.0005 * u, cy + -0.1382 * u)
      p.bezier_curve_to(cx + 0.0891 * u, cy + -0.2917 * u, cx + 0.1778 * u, cy + -0.4451 * u, cx + 0.2662 * u, cy + -0.5986 * u)
      p.bezier_curve_to(cx + 0.2748 * u, cy + -0.6135 * u, cx + 0.2859 * u, cy + -0.6252 * u, cx + 0.3018 * u, cy + -0.6318 * u)
      p.bezier_curve_to(cx + 0.3071 * u, cy + -0.634 * u, cx + 0.3127 * u, cy + -0.6351 * u, cx + 0.3183 * u, cy + -0.6367 * u)
      p.bezier_curve_to(cx + 0.3193 * u, cy + -0.637 * u, cx + 0.3201 * u, cy + -0.6374 * u, cx + 0.321 * u, cy + -0.6378 * u)
      p.bezier_curve_to(cx + 0.3276 * u, cy + -0.6378 * u, cx + 0.3341 * u, cy + -0.6378 * u, cx + 0.3407 * u, cy + -0.6378 * u)
      p.close_path()
      p.move_to(cx + -1 * u, cy + -0.0019 * u)
      p.bezier_curve_to(cx + -0.9991 * u, cy + -0.0037 * u, cx + -0.998 * u, cy + -0.0054 * u, cx + -0.9976 * u, cy + -0.0073 * u)
      p.bezier_curve_to(cx + -0.9944 * u, cy + -0.0213 * u, cx + -0.9876 * u, cy + -0.0332 * u, cx + -0.9775 * u, cy + -0.0432 * u)
      p.bezier_curve_to(cx + -0.8532 * u, cy + -0.1675 * u, cx + -0.7289 * u, cy + -0.292 * u, cx + -0.6044 * u, cy + -0.4162 * u)
      p.bezier_curve_to(cx + -0.5839 * u, cy + -0.4367 * u, cx + -0.5588 * u, cy + -0.4425 * u, cx + -0.5314 * u, cy + -0.4337 * u)
      p.bezier_curve_to(cx + -0.5038 * u, cy + -0.4248 * u, cx + -0.4874 * u, cy + -0.405 * u, cx + -0.4828 * u, cy + -0.3764 * u)
      p.bezier_curve_to(cx + -0.4791 * u, cy + -0.3528 * u, cx + -0.4859 * u, cy + -0.3318 * u, cx + -0.5031 * u, cy + -0.3146 * u)
      p.bezier_curve_to(cx + -0.5894 * u, cy + -0.2283 * u, cx + -0.6758 * u, cy + -0.1421 * u, cx + -0.7622 * u, cy + -0.0557 * u)
      p.bezier_curve_to(cx + -0.7863 * u, cy + -0.0316 * u, cx + -0.8103 * u, cy + -0.0076 * u, cx + -0.8343 * u, cy + 0.0166 * u)
      p.bezier_curve_to(cx + -0.8355 * u, cy + 0.0177 * u, cx + -0.8366 * u, cy + 0.0189 * u, cx + -0.8379 * u, cy + 0.0203 * u)
      p.bezier_curve_to(cx + -0.8363 * u, cy + 0.0222 * u, cx + -0.8349 * u, cy + 0.0237 * u, cx + -0.8333 * u, cy + 0.0253 * u)
      p.bezier_curve_to(cx + -0.7233 * u, cy + 0.1353 * u, cx + -0.6133 * u, cy + 0.2454 * u, cx + -0.5033 * u, cy + 0.3554 * u)
      p.bezier_curve_to(cx + -0.4639 * u, cy + 0.3947 * u, cx + -0.4809 * u, cy + 0.4611 * u, cx + -0.5346 * u, cy + 0.4756 * u)
      p.bezier_curve_to(cx + -0.5609 * u, cy + 0.4827 * u, cx + -0.5847 * u, cy + 0.4766 * u, cx + -0.6043 * u, cy + 0.4573 * u)
      p.bezier_curve_to(cx + -0.6276 * u, cy + 0.4342 * u, cx + -0.6506 * u, cy + 0.4109 * u, cx + -0.6738 * u, cy + 0.3877 * u)
      p.bezier_curve_to(cx + -0.7741 * u, cy + 0.2873 * u, cx + -0.8745 * u, cy + 0.1869 * u, cx + -0.9751 * u, cy + 0.0864 * u)
      p.bezier_curve_to(cx + -0.9866 * u, cy + 0.0751 * u, cx + -0.9947 * u, cy + 0.0625 * u, cx + -0.9979 * u, cy + 0.0466 * u)
      p.bezier_curve_to(cx + -0.9981 * u, cy + 0.0452 * u, cx + -0.9993 * u, cy + 0.0438 * u, cx + -1 * u, cy + 0.0425 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.0276 * u, cx + -1 * u, cy + 0.0129 * u, cx + -1 * u, cy + -0.0019 * u)
      p.close_path()
      p.move_to(cx + 1 * u, cy + 0.0461 * u)
      p.bezier_curve_to(cx + 0.9993 * u, cy + 0.0485 * u, cx + 0.9986 * u, cy + 0.0511 * u, cx + 0.9979 * u, cy + 0.0535 * u)
      p.bezier_curve_to(cx + 0.9944 * u, cy + 0.065 * u, cx + 0.9884 * u, cy + 0.0747 * u, cx + 0.98 * u, cy + 0.0833 * u)
      p.bezier_curve_to(cx + 0.9379 * u, cy + 0.1253 * u, cx + 0.896 * u, cy + 0.1675 * u, cx + 0.8541 * u, cy + 0.2096 * u)
      p.bezier_curve_to(cx + 0.8399 * u, cy + 0.2239 * u, cx + 0.8257 * u, cy + 0.2381 * u, cx + 0.8116 * u, cy + 0.2524 * u)
      p.bezier_curve_to(cx + 0.7618 * u, cy + 0.3023 * u, cx + 0.712 * u, cy + 0.3522 * u, cx + 0.6622 * u, cy + 0.4022 * u)
      p.bezier_curve_to(cx + 0.6439 * u, cy + 0.4206 * u, cx + 0.6259 * u, cy + 0.4394 * u, cx + 0.6071 * u, cy + 0.4575 * u)
      p.bezier_curve_to(cx + 0.5862 * u, cy + 0.4777 * u, cx + 0.5612 * u, cy + 0.4834 * u, cx + 0.5339 * u, cy + 0.4744 * u)
      p.bezier_curve_to(cx + 0.5063 * u, cy + 0.4653 * u, cx + 0.4899 * u, cy + 0.4452 * u, cx + 0.4857 * u, cy + 0.4162 * u)
      p.bezier_curve_to(cx + 0.4822 * u, cy + 0.3924 * u, cx + 0.4897 * u, cy + 0.3721 * u, cx + 0.5065 * u, cy + 0.3552 * u)
      p.bezier_curve_to(cx + 0.5609 * u, cy + 0.3006 * u, cx + 0.6153 * u, cy + 0.2461 * u, cx + 0.6696 * u, cy + 0.1914 * u)
      p.bezier_curve_to(cx + 0.7164 * u, cy + 0.1445 * u, cx + 0.7631 * u, cy + 0.0976 * u, cx + 0.8099 * u, cy + 0.0506 * u)
      p.bezier_curve_to(cx + 0.8197 * u, cy + 0.0408 * u, cx + 0.8297 * u, cy + 0.0312 * u, cx + 0.8402 * u, cy + 0.0209 * u)
      p.bezier_curve_to(cx + 0.8383 * u, cy + 0.0189 * u, cx + 0.837 * u, cy + 0.0175 * u, cx + 0.8356 * u, cy + 0.016 * u)
      p.bezier_curve_to(cx + 0.8113 * u, cy + -0.0084 * u, cx + 0.787 * u, cy + -0.0328 * u, cx + 0.7628 * u, cy + -0.0572 * u)
      p.bezier_curve_to(cx + 0.7 * u, cy + -0.1202 * u, cx + 0.6372 * u, cy + -0.1833 * u, cx + 0.5744 * u, cy + -0.2462 * u)
      p.bezier_curve_to(cx + 0.5513 * u, cy + -0.2693 * u, cx + 0.528 * u, cy + -0.2922 * u, cx + 0.5054 * u, cy + -0.3156 * u)
      p.bezier_curve_to(cx + 0.4861 * u, cy + -0.3356 * u, cx + 0.4799 * u, cy + -0.3598 * u, cx + 0.4881 * u, cy + -0.3866 * u)
      p.bezier_curve_to(cx + 0.4962 * u, cy + -0.4132 * u, cx + 0.5147 * u, cy + -0.4301 * u, cx + 0.5419 * u, cy + -0.4359 * u)
      p.bezier_curve_to(cx + 0.5674 * u, cy + -0.4414 * u, cx + 0.5898 * u, cy + -0.4342 * u, cx + 0.6083 * u, cy + -0.4158 * u)
      p.bezier_curve_to(cx + 0.6583 * u, cy + -0.3655 * u, cx + 0.7084 * u, cy + -0.3152 * u, cx + 0.7585 * u, cy + -0.265 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -0.209 * u, cx + 0.8699 * u, cy + -0.1531 * u, cx + 0.9256 * u, cy + -0.0973 * u)
      p.bezier_curve_to(cx + 0.9439 * u, cy + -0.0788 * u, cx + 0.9624 * u, cy + -0.0605 * u, cx + 0.9807 * u, cy + -0.0419 * u)
      p.bezier_curve_to(cx + 0.9901 * u, cy + -0.0322 * u, cx + 0.9969 * u, cy + -0.0209 * u, cx + 0.9989 * u, cy + -0.0072 * u)
      p.bezier_curve_to(cx + 0.999 * u, cy + -0.0066 * u, cx + 0.9996 * u, cy + -0.0062 * u, cx + 0.9999 * u, cy + -0.0057 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.0116 * u, cx + 1 * u, cy + 0.0289 * u, cx + 1 * u, cy + 0.0461 * u)
      p.close_path()
      p.fill()
    }
    YhFunction => { // function
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.135 * u, cy + 1 * u, cx + -0.2658 * u, cy + 0.9735 * u, cx + -0.3893 * u, cy + 0.9213 * u)
      p.bezier_curve_to(cx + -0.5085 * u, cy + 0.871 * u, cx + -0.6153 * u, cy + 0.7989 * u, cx + -0.7071 * u, cy + 0.7071 * u)
      p.bezier_curve_to(cx + -0.7989 * u, cy + 0.6153 * u, cx + -0.871 * u, cy + 0.5085 * u, cx + -0.9213 * u, cy + 0.3893 * u)
      p.bezier_curve_to(cx + -0.9735 * u, cy + 0.2661 * u, cx + -1 * u, cy + 0.135 * u, cx + -1 * u, cy + 0 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.135 * u, cx + -0.9735 * u, cy + -0.2658 * u, cx + -0.9213 * u, cy + -0.3893 * u)
      p.bezier_curve_to(cx + -0.871 * u, cy + -0.5085 * u, cx + -0.7989 * u, cy + -0.6153 * u, cx + -0.7071 * u, cy + -0.7071 * u)
      p.bezier_curve_to(cx + -0.6153 * u, cy + -0.7989 * u, cx + -0.5085 * u, cy + -0.871 * u, cx + -0.3893 * u, cy + -0.9213 * u)
      p.bezier_curve_to(cx + -0.2661 * u, cy + -0.9735 * u, cx + -0.135 * u, cy + -1 * u, cx + 0 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.135 * u, cy + -1 * u, cx + 0.2658 * u, cy + -0.9735 * u, cx + 0.3893 * u, cy + -0.9213 * u)
      p.bezier_curve_to(cx + 0.5085 * u, cy + -0.871 * u, cx + 0.6153 * u, cy + -0.7989 * u, cx + 0.7071 * u, cy + -0.7071 * u)
      p.bezier_curve_to(cx + 0.7989 * u, cy + -0.6153 * u, cx + 0.871 * u, cy + -0.5085 * u, cx + 0.9213 * u, cy + -0.3893 * u)
      p.bezier_curve_to(cx + 0.9735 * u, cy + -0.2661 * u, cx + 1 * u, cy + -0.135 * u, cx + 1 * u, cy + 0 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.135 * u, cx + 0.9735 * u, cy + 0.2658 * u, cx + 0.9213 * u, cy + 0.3893 * u)
      p.bezier_curve_to(cx + 0.871 * u, cy + 0.5085 * u, cx + 0.7989 * u, cy + 0.6153 * u, cx + 0.7071 * u, cy + 0.7071 * u)
      p.bezier_curve_to(cx + 0.6153 * u, cy + 0.7989 * u, cx + 0.5085 * u, cy + 0.871 * u, cx + 0.3893 * u, cy + 0.9213 * u)
      p.bezier_curve_to(cx + 0.2661 * u, cy + 0.9735 * u, cx + 0.135 * u, cy + 1 * u, cx + 0 * u, cy + 1 * u)
      p.close_path()
      p.move_to(cx + 0 * u, cy + -0.8033 * u)
      p.bezier_curve_to(cx + -0.4429 * u, cy + -0.8033 * u, cx + -0.8033 * u, cy + -0.4429 * u, cx + -0.8033 * u, cy + 0 * u)
      p.bezier_curve_to(cx + -0.8033 * u, cy + 0.4429 * u, cx + -0.4429 * u, cy + 0.8033 * u, cx + 0 * u, cy + 0.8033 * u)
      p.bezier_curve_to(cx + 0.4429 * u, cy + 0.8033 * u, cx + 0.8033 * u, cy + 0.4429 * u, cx + 0.8033 * u, cy + 0 * u)
      p.bezier_curve_to(cx + 0.8033 * u, cy + -0.4429 * u, cx + 0.4429 * u, cy + -0.8033 * u, cx + 0 * u, cy + -0.8033 * u)
      p.close_path()
      p.move_to(cx + -0.2199 * u, cy + -0.4418 * u)
      p.line_to(cx + 0.4361 * u, cy + -0.0164 * u)
      p.line_to(cx + -0.2199 * u, cy + 0.4087 * u)
      p.close_path()
      p.fill()
    }
    YhParams => { // 参数
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.7143 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.6786 * u, cy + -1 * u)
      p.line_to(cx + -0.6071 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.5833 * u, cy + -1 * u, cx + -0.5714 * u, cy + -0.9881 * u, cx + -0.5714 * u, cy + -0.9643 * u)
      p.line_to(cx + -0.5714 * u, cy + 0.2011 * u)
      p.bezier_curve_to(cx + -0.5714 * u, cy + 0.2249 * u, cx + -0.5833 * u, cy + 0.2368 * u, cx + -0.6071 * u, cy + 0.2368 * u)
      p.line_to(cx + -0.6786 * u, cy + 0.2368 * u)
      p.bezier_curve_to(cx + -0.7024 * u, cy + 0.2368 * u, cx + -0.7143 * u, cy + 0.2249 * u, cx + -0.7143 * u, cy + 0.2011 * u)
      p.line_to(cx + -0.7143 * u, cy + -0.9643 * u)
      p.bezier_curve_to(cx + -0.7143 * u, cy + -0.9881 * u, cx + -0.7024 * u, cy + -1 * u, cx + -0.6786 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.7143 * u, cy + 0.5161 * u)
      p.close_path()
      p.move_to(cx + -0.6786 * u, cy + 0.5161 * u)
      p.line_to(cx + -0.6071 * u, cy + 0.5161 * u)
      p.bezier_curve_to(cx + -0.5833 * u, cy + 0.5161 * u, cx + -0.5714 * u, cy + 0.528 * u, cx + -0.5714 * u, cy + 0.5518 * u)
      p.line_to(cx + -0.5714 * u, cy + 0.9643 * u)
      p.bezier_curve_to(cx + -0.5714 * u, cy + 0.9881 * u, cx + -0.5833 * u, cy + 1 * u, cx + -0.6071 * u, cy + 1 * u)
      p.line_to(cx + -0.6786 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.7024 * u, cy + 1 * u, cx + -0.7143 * u, cy + 0.9881 * u, cx + -0.7143 * u, cy + 0.9643 * u)
      p.line_to(cx + -0.7143 * u, cy + 0.5518 * u)
      p.bezier_curve_to(cx + -0.7143 * u, cy + 0.528 * u, cx + -0.7024 * u, cy + 0.5161 * u, cx + -0.6786 * u, cy + 0.5161 * u)
      p.close_path()
      p.move_to(cx + 0.5714 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.6071 * u, cy + -1 * u)
      p.line_to(cx + 0.6786 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.7024 * u, cy + -1 * u, cx + 0.7143 * u, cy + -0.9881 * u, cx + 0.7143 * u, cy + -0.9643 * u)
      p.line_to(cx + 0.7143 * u, cy + 0.1925 * u)
      p.bezier_curve_to(cx + 0.7143 * u, cy + 0.2163 * u, cx + 0.7024 * u, cy + 0.2282 * u, cx + 0.6786 * u, cy + 0.2282 * u)
      p.line_to(cx + 0.6071 * u, cy + 0.2282 * u)
      p.bezier_curve_to(cx + 0.5833 * u, cy + 0.2282 * u, cx + 0.5714 * u, cy + 0.2163 * u, cx + 0.5714 * u, cy + 0.1925 * u)
      p.line_to(cx + 0.5714 * u, cy + -0.9643 * u)
      p.bezier_curve_to(cx + 0.5714 * u, cy + -0.9881 * u, cx + 0.5833 * u, cy + -1 * u, cx + 0.6071 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.5714 * u, cy + 0.5218 * u)
      p.close_path()
      p.move_to(cx + 0.6071 * u, cy + 0.5218 * u)
      p.line_to(cx + 0.6786 * u, cy + 0.5218 * u)
      p.bezier_curve_to(cx + 0.7024 * u, cy + 0.5218 * u, cx + 0.7143 * u, cy + 0.5337 * u, cx + 0.7143 * u, cy + 0.5575 * u)
      p.line_to(cx + 0.7143 * u, cy + 0.9643 * u)
      p.bezier_curve_to(cx + 0.7143 * u, cy + 0.9881 * u, cx + 0.7024 * u, cy + 1 * u, cx + 0.6786 * u, cy + 1 * u)
      p.line_to(cx + 0.6071 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.5833 * u, cy + 1 * u, cx + 0.5714 * u, cy + 0.9881 * u, cx + 0.5714 * u, cy + 0.9643 * u)
      p.line_to(cx + 0.5714 * u, cy + 0.5575 * u)
      p.bezier_curve_to(cx + 0.5714 * u, cy + 0.5337 * u, cx + 0.5833 * u, cy + 0.5218 * u, cx + 0.6071 * u, cy + 0.5218 * u)
      p.close_path()
      p.move_to(cx + -0.0714 * u, cy + -0.2364 * u)
      p.close_path()
      p.move_to(cx + -0.0357 * u, cy + -0.2364 * u)
      p.line_to(cx + 0.0357 * u, cy + -0.2364 * u)
      p.bezier_curve_to(cx + 0.0595 * u, cy + -0.2364 * u, cx + 0.0714 * u, cy + -0.2245 * u, cx + 0.0714 * u, cy + -0.2007 * u)
      p.line_to(cx + 0.0714 * u, cy + 0.9643 * u)
      p.bezier_curve_to(cx + 0.0714 * u, cy + 0.9881 * u, cx + 0.0595 * u, cy + 1 * u, cx + 0.0357 * u, cy + 1 * u)
      p.line_to(cx + -0.0357 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.0595 * u, cy + 1 * u, cx + -0.0714 * u, cy + 0.9881 * u, cx + -0.0714 * u, cy + 0.9643 * u)
      p.line_to(cx + -0.0714 * u, cy + -0.2007 * u)
      p.bezier_curve_to(cx + -0.0714 * u, cy + -0.2245 * u, cx + -0.0595 * u, cy + -0.2364 * u, cx + -0.0357 * u, cy + -0.2364 * u)
      p.close_path()
      p.move_to(cx + -0.6429 * u, cy + 0.2857 * u)
      p.line_to(cx + -0.6368 * u, cy + 0.2857 * u)
      p.line_to(cx + -0.6192 * u, cy + 0.2877 * u)
      p.line_to(cx + -0.6022 * u, cy + 0.2925 * u)
      p.line_to(cx + -0.5862 * u, cy + 0.3001 * u)
      p.line_to(cx + -0.5716 * u, cy + 0.3102 * u)
      p.line_to(cx + -0.5589 * u, cy + 0.3225 * u)
      p.line_to(cx + -0.5485 * u, cy + 0.3368 * u)
      p.line_to(cx + -0.5405 * u, cy + 0.3526 * u)
      p.line_to(cx + -0.5352 * u, cy + 0.3695 * u)
      p.line_to(cx + -0.5328 * u, cy + 0.387 * u)
      p.line_to(cx + -0.5333 * u, cy + 0.4047 * u)
      p.line_to(cx + -0.5367 * u, cy + 0.4221 * u)
      p.line_to(cx + -0.5429 * u, cy + 0.4387 * u)
      p.line_to(cx + -0.5518 * u, cy + 0.454 * u)
      p.line_to(cx + -0.563 * u, cy + 0.4677 * u)
      p.line_to(cx + -0.5764 * u, cy + 0.4793 * u)
      p.line_to(cx + -0.5915 * u, cy + 0.4885 * u)
      p.line_to(cx + -0.6079 * u, cy + 0.4952 * u)
      p.line_to(cx + -0.6252 * u, cy + 0.499 * u)
      p.line_to(cx + -0.6429 * u, cy + 0.5 * u)
      p.line_to(cx + -0.6486 * u, cy + 0.5 * u)
      p.line_to(cx + -0.6671 * u, cy + 0.4979 * u)
      p.line_to(cx + -0.685 * u, cy + 0.4926 * u)
      p.line_to(cx + -0.7018 * u, cy + 0.4842 * u)
      p.line_to(cx + -0.7168 * u, cy + 0.4731 * u)
      p.line_to(cx + -0.7296 * u, cy + 0.4595 * u)
      p.line_to(cx + -0.7399 * u, cy + 0.444 * u)
      p.line_to(cx + -0.7474 * u, cy + 0.4268 * u)
      p.line_to(cx + -0.7517 * u, cy + 0.4086 * u)
      p.line_to(cx + -0.7529 * u, cy + 0.39 * u)
      p.line_to(cx + -0.7507 * u, cy + 0.3714 * u)
      p.line_to(cx + -0.7454 * u, cy + 0.3535 * u)
      p.line_to(cx + -0.7371 * u, cy + 0.3368 * u)
      p.line_to(cx + -0.726 * u, cy + 0.3218 * u)
      p.line_to(cx + -0.7124 * u, cy + 0.3089 * u)
      p.line_to(cx + -0.6968 * u, cy + 0.2986 * u)
      p.line_to(cx + -0.6797 * u, cy + 0.2912 * u)
      p.line_to(cx + -0.6615 * u, cy + 0.2868 * u)
      p.line_to(cx + -0.6429 * u, cy + 0.2857 * u)
      p.close_path()
      p.move_to(cx + -0.6429 * u, cy + 0.1429 * u)
      p.line_to(cx + -0.6864 * u, cy + 0.1455 * u)
      p.line_to(cx + -0.7287 * u, cy + 0.1557 * u)
      p.line_to(cx + -0.7687 * u, cy + 0.1731 * u)
      p.line_to(cx + -0.8051 * u, cy + 0.1972 * u)
      p.line_to(cx + -0.8367 * u, cy + 0.2272 * u)
      p.line_to(cx + -0.8626 * u, cy + 0.2623 * u)
      p.line_to(cx + -0.882 * u, cy + 0.3013 * u)
      p.line_to(cx + -0.8944 * u, cy + 0.3431 * u)
      p.line_to(cx + -0.8993 * u, cy + 0.3864 * u)
      p.line_to(cx + -0.8966 * u, cy + 0.4299 * u)
      p.line_to(cx + -0.8864 * u, cy + 0.4723 * u)
      p.line_to(cx + -0.869 * u, cy + 0.5123 * u)
      p.line_to(cx + -0.8449 * u, cy + 0.5486 * u)
      p.line_to(cx + -0.8149 * u, cy + 0.5802 * u)
      p.line_to(cx + -0.7799 * u, cy + 0.6061 * u)
      p.line_to(cx + -0.7408 * u, cy + 0.6256 * u)
      p.line_to(cx + -0.699 * u, cy + 0.6379 * u)
      p.line_to(cx + -0.6557 * u, cy + 0.6429 * u)
      p.line_to(cx + -0.6429 * u, cy + 0.6429 * u)
      p.line_to(cx + -0.5993 * u, cy + 0.6402 * u)
      p.line_to(cx + -0.557 * u, cy + 0.63 * u)
      p.line_to(cx + -0.517 * u, cy + 0.6126 * u)
      p.line_to(cx + -0.4807 * u, cy + 0.5885 * u)
      p.line_to(cx + -0.449 * u, cy + 0.5585 * u)
      p.line_to(cx + -0.4231 * u, cy + 0.5234 * u)
      p.line_to(cx + -0.4037 * u, cy + 0.4844 * u)
      p.line_to(cx + -0.3913 * u, cy + 0.4426 * u)
      p.line_to(cx + -0.3864 * u, cy + 0.3993 * u)
      p.line_to(cx + -0.3891 * u, cy + 0.3558 * u)
      p.line_to(cx + -0.3993 * u, cy + 0.3134 * u)
      p.line_to(cx + -0.4167 * u, cy + 0.2734 * u)
      p.line_to(cx + -0.4408 * u, cy + 0.2371 * u)
      p.line_to(cx + -0.4708 * u, cy + 0.2055 * u)
      p.line_to(cx + -0.5059 * u, cy + 0.1796 * u)
      p.line_to(cx + -0.5449 * u, cy + 0.1601 * u)
      p.line_to(cx + -0.5867 * u, cy + 0.1478 * u)
      p.line_to(cx + -0.63 * u, cy + 0.1429 * u)
      p.close_path()
      p.move_to(cx + 0 * u, cy + -0.5089 * u)
      p.line_to(cx + 0.0061 * u, cy + -0.5089 * u)
      p.line_to(cx + 0.0246 * u, cy + -0.5068 * u)
      p.line_to(cx + 0.0426 * u, cy + -0.5016 * u)
      p.line_to(cx + 0.0593 * u, cy + -0.4932 * u)
      p.line_to(cx + 0.0743 * u, cy + -0.4821 * u)
      p.line_to(cx + 0.0872 * u, cy + -0.4686 * u)
      p.line_to(cx + 0.0975 * u, cy + -0.453 * u)
      p.line_to(cx + 0.105 * u, cy + -0.4359 * u)
      p.line_to(cx + 0.1094 * u, cy + -0.4178 * u)
      p.line_to(cx + 0.1105 * u, cy + -0.3991 * u)
      p.line_to(cx + 0.1084 * u, cy + -0.3805 * u)
      p.line_to(cx + 0.1032 * u, cy + -0.3626 * u)
      p.line_to(cx + 0.0948 * u, cy + -0.3459 * u)
      p.line_to(cx + 0.0837 * u, cy + -0.3309 * u)
      p.line_to(cx + 0.0702 * u, cy + -0.318 * u)
      p.line_to(cx + 0.0546 * u, cy + -0.3077 * u)
      p.line_to(cx + 0.0375 * u, cy + -0.3002 * u)
      p.line_to(cx + 0.0194 * u, cy + -0.2958 * u)
      p.line_to(cx + 0.0007 * u, cy + -0.2946 * u)
      p.line_to(cx + -0.0054 * u, cy + -0.2946 * u)
      p.line_to(cx + -0.0239 * u, cy + -0.2967 * u)
      p.line_to(cx + -0.0418 * u, cy + -0.302 * u)
      p.line_to(cx + -0.0586 * u, cy + -0.3103 * u)
      p.line_to(cx + -0.0736 * u, cy + -0.3214 * u)
      p.line_to(cx + -0.0865 * u, cy + -0.335 * u)
      p.line_to(cx + -0.0968 * u, cy + -0.3505 * u)
      p.line_to(cx + -0.1043 * u, cy + -0.3677 * u)
      p.line_to(cx + -0.1087 * u, cy + -0.3858 * u)
      p.line_to(cx + -0.1098 * u, cy + -0.4045 * u)
      p.line_to(cx + -0.1077 * u, cy + -0.423 * u)
      p.line_to(cx + -0.1024 * u, cy + -0.4409 * u)
      p.line_to(cx + -0.0941 * u, cy + -0.4577 * u)
      p.line_to(cx + -0.083 * u, cy + -0.4727 * u)
      p.line_to(cx + -0.0695 * u, cy + -0.4856 * u)
      p.line_to(cx + -0.0539 * u, cy + -0.4959 * u)
      p.line_to(cx + -0.0368 * u, cy + -0.5034 * u)
      p.line_to(cx + -0.0186 * u, cy + -0.5078 * u)
      p.line_to(cx + 0 * u, cy + -0.5089 * u)
      p.close_path()
      p.move_to(cx + 0 * u, cy + -0.6518 * u)
      p.line_to(cx + -0.0435 * u, cy + -0.6491 * u)
      p.line_to(cx + -0.0859 * u, cy + -0.6389 * u)
      p.line_to(cx + -0.1259 * u, cy + -0.6215 * u)
      p.line_to(cx + -0.1622 * u, cy + -0.5974 * u)
      p.line_to(cx + -0.1938 * u, cy + -0.5674 * u)
      p.line_to(cx + -0.2197 * u, cy + -0.5324 * u)
      p.line_to(cx + -0.2392 * u, cy + -0.4933 * u)
      p.line_to(cx + -0.2515 * u, cy + -0.4515 * u)
      p.line_to(cx + -0.2564 * u, cy + -0.4082 * u)
      p.line_to(cx + -0.2537 * u, cy + -0.3647 * u)
      p.line_to(cx + -0.2436 * u, cy + -0.3223 * u)
      p.line_to(cx + -0.2261 * u, cy + -0.2824 * u)
      p.line_to(cx + -0.2021 * u, cy + -0.246 * u)
      p.line_to(cx + -0.1721 * u, cy + -0.2144 * u)
      p.line_to(cx + -0.137 * u, cy + -0.1885 * u)
      p.line_to(cx + -0.098 * u, cy + -0.1691 * u)
      p.line_to(cx + -0.0562 * u, cy + -0.1567 * u)
      p.line_to(cx + -0.0129 * u, cy + -0.1518 * u)
      p.line_to(cx + 0 * u, cy + -0.1518 * u)
      p.line_to(cx + 0.0435 * u, cy + -0.1545 * u)
      p.line_to(cx + 0.0859 * u, cy + -0.1647 * u)
      p.line_to(cx + 0.1259 * u, cy + -0.1821 * u)
      p.line_to(cx + 0.1622 * u, cy + -0.2061 * u)
      p.line_to(cx + 0.1938 * u, cy + -0.2362 * u)
      p.line_to(cx + 0.2197 * u, cy + -0.2712 * u)
      p.line_to(cx + 0.2392 * u, cy + -0.3102 * u)
      p.line_to(cx + 0.2515 * u, cy + -0.352 * u)
      p.line_to(cx + 0.2564 * u, cy + -0.3954 * u)
      p.line_to(cx + 0.2537 * u, cy + -0.4389 * u)
      p.line_to(cx + 0.2436 * u, cy + -0.4812 * u)
      p.line_to(cx + 0.2261 * u, cy + -0.5212 * u)
      p.line_to(cx + 0.2021 * u, cy + -0.5576 * u)
      p.line_to(cx + 0.1721 * u, cy + -0.5892 * u)
      p.line_to(cx + 0.137 * u, cy + -0.6151 * u)
      p.line_to(cx + 0.098 * u, cy + -0.6345 * u)
      p.line_to(cx + 0.0562 * u, cy + -0.6469 * u)
      p.line_to(cx + 0.0129 * u, cy + -0.6518 * u)
      p.close_path()
      p.move_to(cx + 0.6429 * u, cy + 0.2857 * u)
      p.line_to(cx + 0.6489 * u, cy + 0.2857 * u)
      p.line_to(cx + 0.6675 * u, cy + 0.2879 * u)
      p.line_to(cx + 0.6854 * u, cy + 0.2932 * u)
      p.line_to(cx + 0.7021 * u, cy + 0.3016 * u)
      p.line_to(cx + 0.7171 * u, cy + 0.3127 * u)
      p.line_to(cx + 0.7299 * u, cy + 0.3263 * u)
      p.line_to(cx + 0.7402 * u, cy + 0.3419 * u)
      p.line_to(cx + 0.7476 * u, cy + 0.3591 * u)
      p.line_to(cx + 0.7519 * u, cy + 0.3772 * u)
      p.line_to(cx + 0.753 * u, cy + 0.3959 * u)
      p.line_to(cx + 0.7509 * u, cy + 0.4145 * u)
      p.line_to(cx + 0.7455 * u, cy + 0.4324 * u)
      p.line_to(cx + 0.7372 * u, cy + 0.4491 * u)
      p.line_to(cx + 0.726 * u, cy + 0.4641 * u)
      p.line_to(cx + 0.7124 * u, cy + 0.4769 * u)
      p.line_to(cx + 0.6968 * u, cy + 0.4872 * u)
      p.line_to(cx + 0.6797 * u, cy + 0.4946 * u)
      p.line_to(cx + 0.6615 * u, cy + 0.4989 * u)
      p.line_to(cx + 0.6429 * u, cy + 0.5 * u)
      p.line_to(cx + 0.6368 * u, cy + 0.5 * u)
      p.line_to(cx + 0.6182 * u, cy + 0.4978 * u)
      p.line_to(cx + 0.6003 * u, cy + 0.4925 * u)
      p.line_to(cx + 0.5836 * u, cy + 0.4841 * u)
      p.line_to(cx + 0.5686 * u, cy + 0.473 * u)
      p.line_to(cx + 0.5558 * u, cy + 0.4594 * u)
      p.line_to(cx + 0.5455 * u, cy + 0.4438 * u)
      p.line_to(cx + 0.5381 * u, cy + 0.4266 * u)
      p.line_to(cx + 0.5338 * u, cy + 0.4085 * u)
      p.line_to(cx + 0.5327 * u, cy + 0.3898 * u)
      p.line_to(cx + 0.5348 * u, cy + 0.3713 * u)
      p.line_to(cx + 0.5402 * u, cy + 0.3534 * u)
      p.line_to(cx + 0.5486 * u, cy + 0.3367 * u)
      p.line_to(cx + 0.5597 * u, cy + 0.3217 * u)
      p.line_to(cx + 0.5733 * u, cy + 0.3088 * u)
      p.line_to(cx + 0.5889 * u, cy + 0.2986 * u)
      p.line_to(cx + 0.606 * u, cy + 0.2911 * u)
      p.line_to(cx + 0.6242 * u, cy + 0.2868 * u)
      p.line_to(cx + 0.6429 * u, cy + 0.2857 * u)
      p.close_path()
      p.move_to(cx + 0.6429 * u, cy + 0.1429 * u)
      p.line_to(cx + 0.5993 * u, cy + 0.1455 * u)
      p.line_to(cx + 0.557 * u, cy + 0.1557 * u)
      p.line_to(cx + 0.517 * u, cy + 0.1731 * u)
      p.line_to(cx + 0.4807 * u, cy + 0.1972 * u)
      p.line_to(cx + 0.449 * u, cy + 0.2272 * u)
      p.line_to(cx + 0.4231 * u, cy + 0.2623 * u)
      p.line_to(cx + 0.4037 * u, cy + 0.3013 * u)
      p.line_to(cx + 0.3913 * u, cy + 0.3431 * u)
      p.line_to(cx + 0.3864 * u, cy + 0.3864 * u)
      p.line_to(cx + 0.3891 * u, cy + 0.4299 * u)
      p.line_to(cx + 0.3993 * u, cy + 0.4723 * u)
      p.line_to(cx + 0.4167 * u, cy + 0.5123 * u)
      p.line_to(cx + 0.4408 * u, cy + 0.5486 * u)
      p.line_to(cx + 0.4708 * u, cy + 0.5802 * u)
      p.line_to(cx + 0.5059 * u, cy + 0.6061 * u)
      p.line_to(cx + 0.5449 * u, cy + 0.6256 * u)
      p.line_to(cx + 0.5867 * u, cy + 0.6379 * u)
      p.line_to(cx + 0.63 * u, cy + 0.6429 * u)
      p.line_to(cx + 0.6429 * u, cy + 0.6429 * u)
      p.line_to(cx + 0.6864 * u, cy + 0.6402 * u)
      p.line_to(cx + 0.7287 * u, cy + 0.63 * u)
      p.line_to(cx + 0.7687 * u, cy + 0.6126 * u)
      p.line_to(cx + 0.8051 * u, cy + 0.5885 * u)
      p.line_to(cx + 0.8367 * u, cy + 0.5585 * u)
      p.line_to(cx + 0.8626 * u, cy + 0.5234 * u)
      p.line_to(cx + 0.882 * u, cy + 0.4844 * u)
      p.line_to(cx + 0.8944 * u, cy + 0.4426 * u)
      p.line_to(cx + 0.8993 * u, cy + 0.3993 * u)
      p.line_to(cx + 0.8966 * u, cy + 0.3558 * u)
      p.line_to(cx + 0.8864 * u, cy + 0.3134 * u)
      p.line_to(cx + 0.869 * u, cy + 0.2734 * u)
      p.line_to(cx + 0.8449 * u, cy + 0.2371 * u)
      p.line_to(cx + 0.8149 * u, cy + 0.2055 * u)
      p.line_to(cx + 0.7799 * u, cy + 0.1796 * u)
      p.line_to(cx + 0.7408 * u, cy + 0.1601 * u)
      p.line_to(cx + 0.699 * u, cy + 0.1478 * u)
      p.line_to(cx + 0.6557 * u, cy + 0.1429 * u)
      p.close_path()
      p.move_to(cx + -0.0714 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.0357 * u, cy + -1 * u)
      p.line_to(cx + 0.0357 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.0595 * u, cy + -1 * u, cx + 0.0714 * u, cy + -0.9881 * u, cx + 0.0714 * u, cy + -0.9643 * u)
      p.line_to(cx + 0.0714 * u, cy + -0.5961 * u)
      p.bezier_curve_to(cx + 0.0714 * u, cy + -0.5723 * u, cx + 0.0595 * u, cy + -0.5604 * u, cx + 0.0357 * u, cy + -0.5604 * u)
      p.line_to(cx + -0.0357 * u, cy + -0.5604 * u)
      p.bezier_curve_to(cx + -0.0595 * u, cy + -0.5604 * u, cx + -0.0714 * u, cy + -0.5723 * u, cx + -0.0714 * u, cy + -0.5961 * u)
      p.line_to(cx + -0.0714 * u, cy + -0.9643 * u)
      p.bezier_curve_to(cx + -0.0714 * u, cy + -0.9881 * u, cx + -0.0595 * u, cy + -1 * u, cx + -0.0357 * u, cy + -1 * u)
      p.close_path()
      p.fill()
    }
    YhQueryFilter => { // 条件查询
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.7143 * u, cy + -1 * u)
      p.line_to(cx + 0 * u, cy + -0.1667 * u)
      p.line_to(cx + 0 * u, cy + 1 * u)
      p.line_to(cx + -0.2857 * u, cy + 0.7143 * u)
      p.line_to(cx + -0.2857 * u, cy + -0.1667 * u)
      p.line_to(cx + -1 * u, cy + -1 * u)
      p.line_to(cx + 0.7143 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 1 * u, cy + 0.5714 * u)
      p.line_to(cx + 1 * u, cy + 0.8571 * u)
      p.line_to(cx + 0.2857 * u, cy + 0.8571 * u)
      p.line_to(cx + 0.2857 * u, cy + 0.5714 * u)
      p.line_to(cx + 1 * u, cy + 0.5714 * u)
      p.close_path()
      p.move_to(cx + 1 * u, cy + 0 * u)
      p.line_to(cx + 1 * u, cy + 0.2857 * u)
      p.line_to(cx + 0.2857 * u, cy + 0.2857 * u)
      p.line_to(cx + 0.2857 * u, cy + 0 * u)
      p.line_to(cx + 1 * u, cy + 0 * u)
      p.close_path()
      p.fill()
    }
    YhFontSize => { // font-size
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9808 * u, cy + -0.2308 * u)
      p.line_to(cx + 0.25 * u, cy + -0.2308 * u)
      p.bezier_curve_to(cx + 0.2394 * u, cy + -0.2308 * u, cx + 0.2308 * u, cy + -0.2221 * u, cx + 0.2308 * u, cy + -0.2115 * u)
      p.line_to(cx + 0.2308 * u, cy + 0.0577 * u)
      p.bezier_curve_to(cx + 0.2308 * u, cy + 0.0683 * u, cx + 0.2394 * u, cy + 0.0769 * u, cx + 0.25 * u, cy + 0.0769 * u)
      p.line_to(cx + 0.3654 * u, cy + 0.0769 * u)
      p.bezier_curve_to(cx + 0.376 * u, cy + 0.0769 * u, cx + 0.3846 * u, cy + 0.0683 * u, cx + 0.3846 * u, cy + 0.0577 * u)
      p.line_to(cx + 0.3846 * u, cy + -0.0769 * u)
      p.line_to(cx + 0.5288 * u, cy + -0.0769 * u)
      p.line_to(cx + 0.5288 * u, cy + 0.6923 * u)
      p.line_to(cx + 0.4183 * u, cy + 0.6923 * u)
      p.bezier_curve_to(cx + 0.4077 * u, cy + 0.6923 * u, cx + 0.399 * u, cy + 0.701 * u, cx + 0.399 * u, cy + 0.7115 * u)
      p.line_to(cx + 0.399 * u, cy + 0.8269 * u)
      p.bezier_curve_to(cx + 0.399 * u, cy + 0.8375 * u, cx + 0.4077 * u, cy + 0.8462 * u, cx + 0.4183 * u, cy + 0.8462 * u)
      p.line_to(cx + 0.8125 * u, cy + 0.8462 * u)
      p.bezier_curve_to(cx + 0.8231 * u, cy + 0.8462 * u, cx + 0.8317 * u, cy + 0.8375 * u, cx + 0.8317 * u, cy + 0.8269 * u)
      p.line_to(cx + 0.8317 * u, cy + 0.7115 * u)
      p.bezier_curve_to(cx + 0.8317 * u, cy + 0.701 * u, cx + 0.8231 * u, cy + 0.6923 * u, cx + 0.8125 * u, cy + 0.6923 * u)
      p.line_to(cx + 0.7019 * u, cy + 0.6923 * u)
      p.line_to(cx + 0.7019 * u, cy + -0.0769 * u)
      p.line_to(cx + 0.8462 * u, cy + -0.0769 * u)
      p.line_to(cx + 0.8462 * u, cy + 0.0577 * u)
      p.bezier_curve_to(cx + 0.8462 * u, cy + 0.0683 * u, cx + 0.8548 * u, cy + 0.0769 * u, cx + 0.8654 * u, cy + 0.0769 * u)
      p.line_to(cx + 0.9808 * u, cy + 0.0769 * u)
      p.bezier_curve_to(cx + 0.9913 * u, cy + 0.0769 * u, cx + 1 * u, cy + 0.0683 * u, cx + 1 * u, cy + 0.0577 * u)
      p.line_to(cx + 1 * u, cy + -0.2115 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.2221 * u, cx + 0.9913 * u, cy + -0.2308 * u, cx + 0.9808 * u, cy + -0.2308 * u)
      p.close_path()
      p.move_to(cx + 0.3462 * u, cy + -0.5192 * u)
      p.line_to(cx + 0.3462 * u, cy + -0.8269 * u)
      p.bezier_curve_to(cx + 0.3462 * u, cy + -0.8375 * u, cx + 0.3375 * u, cy + -0.8462 * u, cx + 0.3269 * u, cy + -0.8462 * u)
      p.line_to(cx + -0.9808 * u, cy + -0.8462 * u)
      p.bezier_curve_to(cx + -0.9913 * u, cy + -0.8462 * u, cx + -1 * u, cy + -0.8375 * u, cx + -1 * u, cy + -0.8269 * u)
      p.line_to(cx + -1 * u, cy + -0.5192 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.5087 * u, cx + -0.9913 * u, cy + -0.5 * u, cx + -0.9808 * u, cy + -0.5 * u)
      p.line_to(cx + -0.8462 * u, cy + -0.5 * u)
      p.bezier_curve_to(cx + -0.8356 * u, cy + -0.5 * u, cx + -0.8269 * u, cy + -0.5087 * u, cx + -0.8269 * u, cy + -0.5192 * u)
      p.line_to(cx + -0.8269 * u, cy + -0.6731 * u)
      p.line_to(cx + -0.4231 * u, cy + -0.6731 * u)
      p.line_to(cx + -0.4231 * u, cy + 0.6731 * u)
      p.line_to(cx + -0.6442 * u, cy + 0.6731 * u)
      p.bezier_curve_to(cx + -0.6548 * u, cy + 0.6731 * u, cx + -0.6635 * u, cy + 0.6817 * u, cx + -0.6635 * u, cy + 0.6923 * u)
      p.line_to(cx + -0.6635 * u, cy + 0.8269 * u)
      p.bezier_curve_to(cx + -0.6635 * u, cy + 0.8375 * u, cx + -0.6548 * u, cy + 0.8462 * u, cx + -0.6442 * u, cy + 0.8462 * u)
      p.line_to(cx + -0.0096 * u, cy + 0.8462 * u)
      p.bezier_curve_to(cx + 0.001 * u, cy + 0.8462 * u, cx + 0.0096 * u, cy + 0.8375 * u, cx + 0.0096 * u, cy + 0.8269 * u)
      p.line_to(cx + 0.0096 * u, cy + 0.6923 * u)
      p.bezier_curve_to(cx + 0.0096 * u, cy + 0.6817 * u, cx + 0.001 * u, cy + 0.6731 * u, cx + -0.0096 * u, cy + 0.6731 * u)
      p.line_to(cx + -0.2308 * u, cy + 0.6731 * u)
      p.line_to(cx + -0.2308 * u, cy + -0.6731 * u)
      p.line_to(cx + 0.1731 * u, cy + -0.6731 * u)
      p.line_to(cx + 0.1731 * u, cy + -0.5192 * u)
      p.bezier_curve_to(cx + 0.1731 * u, cy + -0.5087 * u, cx + 0.1817 * u, cy + -0.5 * u, cx + 0.1923 * u, cy + -0.5 * u)
      p.line_to(cx + 0.3269 * u, cy + -0.5 * u)
      p.bezier_curve_to(cx + 0.3375 * u, cy + -0.5 * u, cx + 0.3462 * u, cy + -0.5087 * u, cx + 0.3462 * u, cy + -0.5192 * u)
      p.close_path()
      p.fill()
    }
    YhFontColor => { // font-colors
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.98 * u, cy + 0.76 * u)
      p.line_to(cx + -0.98 * u, cy + 0.76 * u)
      p.bezier_curve_to(cx + -0.991 * u, cy + 0.76 * u, cx + -1 * u, cy + 0.769 * u, cx + -1 * u, cy + 0.78 * u)
      p.line_to(cx + -1 * u, cy + 0.98 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.991 * u, cx + -0.991 * u, cy + 1 * u, cx + -0.98 * u, cy + 1 * u)
      p.line_to(cx + 0.98 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.991 * u, cy + 1 * u, cx + 1 * u, cy + 0.991 * u, cx + 1 * u, cy + 0.98 * u)
      p.line_to(cx + 1 * u, cy + 0.78 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.769 * u, cx + 0.991 * u, cy + 0.76 * u, cx + 0.98 * u, cy + 0.76 * u)
      p.close_path()
      p.move_to(cx + -0.6458 * u, cy + 0.56 * u)
      p.line_to(cx + -0.4333 * u, cy + 0.56 * u)
      p.bezier_curve_to(cx + -0.4228 * u, cy + 0.56 * u, cx + -0.4133 * u, cy + 0.5533 * u, cx + -0.41 * u, cy + 0.543 * u)
      p.line_to(cx + -0.2757 * u, cy + 0.128 * u)
      p.line_to(cx + 0.2722 * u, cy + 0.128 * u)
      p.line_to(cx + 0.4052 * u, cy + 0.543 * u)
      p.bezier_curve_to(cx + 0.4085 * u, cy + 0.553 * u, cx + 0.4178 * u, cy + 0.56 * u, cx + 0.4285 * u, cy + 0.56 * u)
      p.line_to(cx + 0.6512 * u, cy + 0.56 * u)
      p.bezier_curve_to(cx + 0.654 * u, cy + 0.56 * u, cx + 0.6567 * u, cy + 0.5595 * u, cx + 0.6593 * u, cy + 0.5587 * u)
      p.bezier_curve_to(cx + 0.672 * u, cy + 0.5543 * u, cx + 0.6787 * u, cy + 0.5405 * u, cx + 0.6743 * u, cy + 0.5278 * u)
      p.line_to(cx + 0.154 * u, cy + -0.9835 * u)
      p.bezier_curve_to(cx + 0.1505 * u, cy + -0.9932 * u, cx + 0.1412 * u, cy + -1 * u, cx + 0.131 * u, cy + -1 * u)
      p.line_to(cx + -0.1247 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.1353 * u, cy + -1 * u, cx + -0.1445 * u, cy + -0.9935 * u, cx + -0.1477 * u, cy + -0.9835 * u)
      p.line_to(cx + -0.6687 * u, cy + 0.5278 * u)
      p.bezier_curve_to(cx + -0.6697 * u, cy + 0.5302 * u, cx + -0.67 * u, cy + 0.533 * u, cx + -0.67 * u, cy + 0.5357 * u)
      p.bezier_curve_to(cx + -0.6703 * u, cy + 0.549 * u, cx + -0.6593 * u, cy + 0.56 * u, cx + -0.6458 * u, cy + 0.56 * u)
      p.close_path()
      p.move_to(cx + -0.006 * u, cy + -0.7302 * u)
      p.line_to(cx + 0.0043 * u, cy + -0.7302 * u)
      p.line_to(cx + 0.2137 * u, cy + -0.0707 * u)
      p.line_to(cx + -0.2177 * u, cy + -0.0707 * u)
      p.line_to(cx + -0.006 * u, cy + -0.7302 * u)
      p.close_path()
      p.fill()
    }
    YhLineHeight => { // line-height
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.3234 * u, cy + -0.8439 * u)
      p.line_to(cx + -0.9808 * u, cy + -0.8439 * u)
      p.bezier_curve_to(cx + -0.9914 * u, cy + -0.8439 * u, cx + -1 * u, cy + -0.8353 * u, cx + -1 * u, cy + -0.8247 * u)
      p.line_to(cx + -1 * u, cy + -0.5179 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.5073 * u, cx + -0.9914 * u, cy + -0.4987 * u, cx + -0.9808 * u, cy + -0.4987 * u)
      p.line_to(cx + -0.8466 * u, cy + -0.4987 * u)
      p.bezier_curve_to(cx + -0.836 * u, cy + -0.4987 * u, cx + -0.8274 * u, cy + -0.5073 * u, cx + -0.8274 * u, cy + -0.5179 * u)
      p.line_to(cx + -0.8274 * u, cy + -0.6713 * u)
      p.line_to(cx + -0.4246 * u, cy + -0.6713 * u)
      p.line_to(cx + -0.4246 * u, cy + 0.6713 * u)
      p.line_to(cx + -0.6452 * u, cy + 0.6713 * u)
      p.bezier_curve_to(cx + -0.6557 * u, cy + 0.6713 * u, cx + -0.6643 * u, cy + 0.6799 * u, cx + -0.6643 * u, cy + 0.6905 * u)
      p.line_to(cx + -0.6643 * u, cy + 0.8247 * u)
      p.bezier_curve_to(cx + -0.6643 * u, cy + 0.8353 * u, cx + -0.6557 * u, cy + 0.8439 * u, cx + -0.6452 * u, cy + 0.8439 * u)
      p.line_to(cx + -0.0122 * u, cy + 0.8439 * u)
      p.bezier_curve_to(cx + -0.0017 * u, cy + 0.8439 * u, cx + 0.007 * u, cy + 0.8353 * u, cx + 0.007 * u, cy + 0.8247 * u)
      p.line_to(cx + 0.007 * u, cy + 0.6905 * u)
      p.bezier_curve_to(cx + 0.007 * u, cy + 0.6799 * u, cx + -0.0017 * u, cy + 0.6713 * u, cx + -0.0122 * u, cy + 0.6713 * u)
      p.line_to(cx + -0.2328 * u, cy + 0.6713 * u)
      p.line_to(cx + -0.2328 * u, cy + -0.6713 * u)
      p.line_to(cx + 0.17 * u, cy + -0.6713 * u)
      p.line_to(cx + 0.17 * u, cy + -0.5179 * u)
      p.bezier_curve_to(cx + 0.17 * u, cy + -0.5073 * u, cx + 0.1786 * u, cy + -0.4987 * u, cx + 0.1892 * u, cy + -0.4987 * u)
      p.line_to(cx + 0.3234 * u, cy + -0.4987 * u)
      p.bezier_curve_to(cx + 0.334 * u, cy + -0.4987 * u, cx + 0.3426 * u, cy + -0.5073 * u, cx + 0.3426 * u, cy + -0.5179 * u)
      p.line_to(cx + 0.3426 * u, cy + -0.8247 * u)
      p.bezier_curve_to(cx + 0.3426 * u, cy + -0.8353 * u, cx + 0.334 * u, cy + -0.8439 * u, cx + 0.3234 * u, cy + -0.8439 * u)
      p.close_path()
      p.move_to(cx + 0.9775 * u, cy + 0.4651 * u)
      p.line_to(cx + 0.8221 * u, cy + 0.4651 * u)
      p.line_to(cx + 0.8221 * u, cy + -0.4651 * u)
      p.line_to(cx + 0.9775 * u, cy + -0.4651 * u)
      p.bezier_curve_to(cx + 0.9918 * u, cy + -0.4651 * u, cx + 1 * u, cy + -0.4819 * u, cx + 0.9911 * u, cy + -0.4932 * u)
      p.line_to(cx + 0.7495 * u, cy + -0.7991 * u)
      p.bezier_curve_to(cx + 0.7425 * u, cy + -0.808 * u, cx + 0.7291 * u, cy + -0.808 * u, cx + 0.7224 * u, cy + -0.7991 * u)
      p.line_to(cx + 0.4807 * u, cy + -0.4932 * u)
      p.bezier_curve_to(cx + 0.4718 * u, cy + -0.4819 * u, cx + 0.4797 * u, cy + -0.4651 * u, cx + 0.4944 * u, cy + -0.4651 * u)
      p.line_to(cx + 0.6495 * u, cy + -0.4651 * u)
      p.line_to(cx + 0.6495 * u, cy + 0.4651 * u)
      p.line_to(cx + 0.4941 * u, cy + 0.4651 * u)
      p.bezier_curve_to(cx + 0.4797 * u, cy + 0.4651 * u, cx + 0.4716 * u, cy + 0.4819 * u, cx + 0.4805 * u, cy + 0.4932 * u)
      p.line_to(cx + 0.7221 * u, cy + 0.7988 * u)
      p.bezier_curve_to(cx + 0.7291 * u, cy + 0.8077 * u, cx + 0.7425 * u, cy + 0.8077 * u, cx + 0.7492 * u, cy + 0.7988 * u)
      p.line_to(cx + 0.9909 * u, cy + 0.4932 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.4819 * u, cx + 0.9918 * u, cy + 0.4651 * u, cx + 0.9775 * u, cy + 0.4651 * u)
      p.close_path()
      p.fill()
    }
    YhStrikethrough => { // strikethrough
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9821 * u, cy + -0.0847 * u)
      p.line_to(cx + 0.1292 * u, cy + -0.0847 * u)
      p.bezier_curve_to(cx + 0.1069 * u, cy + -0.0892 * u, cx + 0.0835 * u, cy + -0.0936 * u, cx + 0.0587 * u, cy + -0.0981 * u)
      p.bezier_curve_to(cx + 0.0232 * u, cy + -0.1046 * u, cx + 0.0092 * u, cy + -0.1073 * u, cx + -0.01 * u, cy + -0.111 * u)
      p.bezier_curve_to(cx + -0.1246 * u, cy + -0.1334 * u, cx + -0.1935 * u, cy + -0.1557 * u, cx + -0.2484 * u, cy + -0.1874 * u)
      p.bezier_curve_to(cx + -0.3268 * u, cy + -0.2331 * u, cx + -0.365 * u, cy + -0.2952 * u, cx + -0.365 * u, cy + -0.3773 * u)
      p.bezier_curve_to(cx + -0.365 * u, cy + -0.4599 * u, cx + -0.331 * u, cy + -0.5285 * u, cx + -0.2667 * u, cy + -0.576 * u)
      p.bezier_curve_to(cx + -0.2033 * u, cy + -0.6229 * u, cx + -0.1132 * u, cy + -0.6477 * u, cx + -0.006 * u, cy + -0.6477 * u)
      p.bezier_curve_to(cx + 0.1163 * u, cy + -0.6477 * u, cx + 0.2107 * u, cy + -0.6155 * u, cx + 0.2748 * u, cy + -0.5521 * u)
      p.bezier_curve_to(cx + 0.3074 * u, cy + -0.52 * u, cx + 0.3312 * u, cy + -0.4805 * u, cx + 0.3458 * u, cy + -0.4347 * u)
      p.bezier_curve_to(cx + 0.3487 * u, cy + -0.4256 * u, cx + 0.352 * u, cy + -0.4124 * u, cx + 0.3554 * u, cy + -0.395 * u)
      p.bezier_curve_to(cx + 0.3574 * u, cy + -0.3843 * u, cx + 0.367 * u, cy + -0.3767 * u, cx + 0.3775 * u, cy + -0.3767 * u)
      p.line_to(cx + 0.54 * u, cy + -0.3767 * u)
      p.bezier_curve_to(cx + 0.5525 * u, cy + -0.3767 * u, cx + 0.5625 * u, cy + -0.3869 * u, cx + 0.5625 * u, cy + -0.3992 * u)
      p.line_to(cx + 0.5625 * u, cy + -0.4015 * u)
      p.bezier_curve_to(cx + 0.5609 * u, cy + -0.4166 * u, cx + 0.5596 * u, cy + -0.4285 * u, cx + 0.558 * u, cy + -0.4372 * u)
      p.bezier_curve_to(cx + 0.5417 * u, cy + -0.5343 * u, cx + 0.4955 * u, cy + -0.6195 * u, cx + 0.4248 * u, cy + -0.6834 * u)
      p.bezier_curve_to(cx + 0.3257 * u, cy + -0.7738 * u, cx + 0.1799 * u, cy + -0.8213 * u, cx + 0.0036 * u, cy + -0.8213 * u)
      p.bezier_curve_to(cx + -0.1578 * u, cy + -0.8213 * u, cx + -0.3031 * u, cy + -0.7809 * u, cx + -0.4056 * u, cy + -0.7077 * u)
      p.bezier_curve_to(cx + -0.4627 * u, cy + -0.6666 * u, cx + -0.5069 * u, cy + -0.6157 * u, cx + -0.5364 * u, cy + -0.5566 * u)
      p.bezier_curve_to(cx + -0.5665 * u, cy + -0.4961 * u, cx + -0.5817 * u, cy + -0.4262 * u, cx + -0.5817 * u, cy + -0.3492 * u)
      p.bezier_curve_to(cx + -0.5817 * u, cy + -0.2834 * u, cx + -0.569 * u, cy + -0.2276 * u, cx + -0.5431 * u, cy + -0.1785 * u)
      p.bezier_curve_to(cx + -0.5246 * u, cy + -0.1434 * u, cx + -0.4993 * u, cy + -0.1126 * u, cx + -0.467 * u, cy + -0.0847 * u)
      p.line_to(cx + -0.9821 * u, cy + -0.0847 * u)
      p.bezier_curve_to(cx + -0.992 * u, cy + -0.0847 * u, cx + -1 * u, cy + -0.0767 * u, cx + -1 * u, cy + -0.0669 * u)
      p.line_to(cx + -1 * u, cy + 0.0671 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.0769 * u, cx + -0.992 * u, cy + 0.0849 * u, cx + -0.9821 * u, cy + 0.0849 * u)
      p.line_to(cx + -0.0152 * u, cy + 0.0849 * u)
      p.bezier_curve_to(cx + -0.0105 * u, cy + 0.0858 * u, cx + -0.0065 * u, cy + 0.0867 * u, cx + -0.002 * u, cy + 0.0876 * u)
      p.bezier_curve_to(cx + 0.067 * u, cy + 0.1015 * u, cx + 0.1085 * u, cy + 0.1108 * u, cx + 0.1467 * u, cy + 0.1215 * u)
      p.bezier_curve_to(cx + 0.198 * u, cy + 0.136 * u, cx + 0.2373 * u, cy + 0.1512 * u, cx + 0.2699 * u, cy + 0.1695 * u)
      p.bezier_curve_to(cx + 0.3498 * u, cy + 0.2146 * u, cx + 0.3888 * u, cy + 0.2794 * u, cx + 0.3888 * u, cy + 0.3682 * u)
      p.bezier_curve_to(cx + 0.3888 * u, cy + 0.447 * u, cx + 0.3542 * u, cy + 0.5173 * u, cx + 0.2915 * u, cy + 0.5664 * u)
      p.bezier_curve_to(cx + 0.2234 * u, cy + 0.6198 * u, cx + 0.1228 * u, cy + 0.6477 * u, cx + 0.0002 * u, cy + 0.6477 * u)
      p.bezier_curve_to(cx + -0.0973 * u, cy + 0.6477 * u, cx + -0.1799 * u, cy + 0.6287 * u, cx + -0.2458 * u, cy + 0.5919 * u)
      p.bezier_curve_to(cx + -0.3107 * u, cy + 0.5555 * u, cx + -0.3554 * u, cy + 0.503 * u, cx + -0.379 * u, cy + 0.4367 * u)
      p.bezier_curve_to(cx + -0.3808 * u, cy + 0.4318 * u, cx + -0.3828 * u, cy + 0.4251 * u, cx + -0.385 * u, cy + 0.4166 * u)
      p.bezier_curve_to(cx + -0.3877 * u, cy + 0.4068 * u, cx + -0.3969 * u, cy + 0.3999 * u, cx + -0.4067 * u, cy + 0.3999 * u)
      p.line_to(cx + -0.5846 * u, cy + 0.3999 * u)
      p.bezier_curve_to(cx + -0.5971 * u, cy + 0.3999 * u, cx + -0.6071 * u, cy + 0.4102 * u, cx + -0.6071 * u, cy + 0.4224 * u)
      p.line_to(cx + -0.6071 * u, cy + 0.4247 * u)
      p.bezier_curve_to(cx + -0.6067 * u, cy + 0.4298 * u, cx + -0.6062 * u, cy + 0.434 * u, cx + -0.6058 * u, cy + 0.4374 * u)
      p.bezier_curve_to(cx + -0.5913 * u, cy + 0.5463 * u, cx + -0.5382 * u, cy + 0.6356 * u, cx + -0.448 * u, cy + 0.7026 * u)
      p.bezier_curve_to(cx + -0.3429 * u, cy + 0.7802 * u, cx + -0.1949 * u, cy + 0.8213 * u, cx + -0.0199 * u, cy + 0.8213 * u)
      p.bezier_curve_to(cx + 0.1681 * u, cy + 0.8213 * u, cx + 0.3257 * u, cy + 0.7771 * u, cx + 0.4359 * u, cy + 0.6934 * u)
      p.bezier_curve_to(cx + 0.4917 * u, cy + 0.6512 * u, cx + 0.5346 * u, cy + 0.5992 * u, cx + 0.5634 * u, cy + 0.5394 * u)
      p.bezier_curve_to(cx + 0.5924 * u, cy + 0.4789 * u, cx + 0.6074 * u, cy + 0.4102 * u, cx + 0.6074 * u, cy + 0.3352 * u)
      p.bezier_curve_to(cx + 0.6074 * u, cy + 0.2642 * u, cx + 0.5944 * u, cy + 0.2048 * u, cx + 0.5676 * u, cy + 0.1535 * u)
      p.bezier_curve_to(cx + 0.5547 * u, cy + 0.1285 * u, cx + 0.5384 * u, cy + 0.1055 * u, cx + 0.519 * u, cy + 0.0847 * u)
      p.line_to(cx + 0.9821 * u, cy + 0.0847 * u)
      p.bezier_curve_to(cx + 0.992 * u, cy + 0.0847 * u, cx + 1 * u, cy + 0.0767 * u, cx + 1 * u, cy + 0.0669 * u)
      p.line_to(cx + 1 * u, cy + -0.0671 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.0767 * u, cx + 0.992 * u, cy + -0.0847 * u, cx + 0.9821 * u, cy + -0.0847 * u)
      p.close_path()
      p.fill()
    }
    YhIndent => { // indent
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.26 * u, cy + -0.175 * u)
      p.line_to(cx + 0.94 * u, cy + -0.175 * u)
      p.bezier_curve_to(cx + 0.951 * u, cy + -0.175 * u, cx + 0.96 * u, cy + -0.184 * u, cx + 0.96 * u, cy + -0.195 * u)
      p.line_to(cx + 0.96 * u, cy + -0.335 * u)
      p.bezier_curve_to(cx + 0.96 * u, cy + -0.346 * u, cx + 0.951 * u, cy + -0.355 * u, cx + 0.94 * u, cy + -0.355 * u)
      p.line_to(cx + -0.26 * u, cy + -0.355 * u)
      p.bezier_curve_to(cx + -0.271 * u, cy + -0.355 * u, cx + -0.28 * u, cy + -0.346 * u, cx + -0.28 * u, cy + -0.335 * u)
      p.line_to(cx + -0.28 * u, cy + -0.195 * u)
      p.bezier_curve_to(cx + -0.28 * u, cy + -0.184 * u, cx + -0.271 * u, cy + -0.175 * u, cx + -0.26 * u, cy + -0.175 * u)
      p.close_path()
      p.move_to(cx + -0.28 * u, cy + 0.335 * u)
      p.bezier_curve_to(cx + -0.28 * u, cy + 0.346 * u, cx + -0.271 * u, cy + 0.355 * u, cx + -0.26 * u, cy + 0.355 * u)
      p.line_to(cx + 0.94 * u, cy + 0.355 * u)
      p.bezier_curve_to(cx + 0.951 * u, cy + 0.355 * u, cx + 0.96 * u, cy + 0.346 * u, cx + 0.96 * u, cy + 0.335 * u)
      p.line_to(cx + 0.96 * u, cy + 0.195 * u)
      p.bezier_curve_to(cx + 0.96 * u, cy + 0.184 * u, cx + 0.951 * u, cy + 0.175 * u, cx + 0.94 * u, cy + 0.175 * u)
      p.line_to(cx + -0.26 * u, cy + 0.175 * u)
      p.bezier_curve_to(cx + -0.271 * u, cy + 0.175 * u, cx + -0.28 * u, cy + 0.184 * u, cx + -0.28 * u, cy + 0.195 * u)
      p.line_to(cx + -0.28 * u, cy + 0.335 * u)
      p.close_path()
      p.move_to(cx + 0.98 * u, cy + -0.88 * u)
      p.line_to(cx + -0.98 * u, cy + -0.88 * u)
      p.bezier_curve_to(cx + -0.991 * u, cy + -0.88 * u, cx + -1 * u, cy + -0.871 * u, cx + -1 * u, cy + -0.86 * u)
      p.line_to(cx + -1 * u, cy + -0.72 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.709 * u, cx + -0.991 * u, cy + -0.7 * u, cx + -0.98 * u, cy + -0.7 * u)
      p.line_to(cx + 0.98 * u, cy + -0.7 * u)
      p.bezier_curve_to(cx + 0.991 * u, cy + -0.7 * u, cx + 1 * u, cy + -0.709 * u, cx + 1 * u, cy + -0.72 * u)
      p.line_to(cx + 1 * u, cy + -0.86 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.871 * u, cx + 0.991 * u, cy + -0.88 * u, cx + 0.98 * u, cy + -0.88 * u)
      p.close_path()
      p.move_to(cx + 0.98 * u, cy + 0.7 * u)
      p.line_to(cx + -0.98 * u, cy + 0.7 * u)
      p.bezier_curve_to(cx + -0.991 * u, cy + 0.7 * u, cx + -1 * u, cy + 0.709 * u, cx + -1 * u, cy + 0.72 * u)
      p.line_to(cx + -1 * u, cy + 0.86 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.871 * u, cx + -0.991 * u, cy + 0.88 * u, cx + -0.98 * u, cy + 0.88 * u)
      p.line_to(cx + 0.98 * u, cy + 0.88 * u)
      p.bezier_curve_to(cx + 0.991 * u, cy + 0.88 * u, cx + 1 * u, cy + 0.871 * u, cx + 1 * u, cy + 0.86 * u)
      p.line_to(cx + 1 * u, cy + 0.72 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.709 * u, cx + 0.991 * u, cy + 0.7 * u, cx + 0.98 * u, cy + 0.7 * u)
      p.close_path()
      p.move_to(cx + -0.924 * u, cy + 0.3252 * u)
      p.line_to(cx + -0.5333 * u, cy + 0.0175 * u)
      p.bezier_curve_to(cx + -0.522 * u, cy + 0.0088 * u, cx + -0.522 * u, cy + -0.0083 * u, cx + -0.5333 * u, cy + -0.0173 * u)
      p.line_to(cx + -0.924 * u, cy + -0.3252 * u)
      p.bezier_curve_to(cx + -0.9385 * u, cy + -0.3367 * u, cx + -0.96 * u, cy + -0.3265 * u, cx + -0.96 * u, cy + -0.308 * u)
      p.line_to(cx + -0.96 * u, cy + 0.3078 * u)
      p.bezier_curve_to(cx + -0.96 * u, cy + 0.3262 * u, cx + -0.9387 * u, cy + 0.3367 * u, cx + -0.924 * u, cy + 0.3252 * u)
      p.close_path()
      p.fill()
    }
    YhOutdent => { // outdent
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.2583 * u, cy + -0.1748 * u)
      p.line_to(cx + 0.9401 * u, cy + -0.1748 * u)
      p.bezier_curve_to(cx + 0.9511 * u, cy + -0.1748 * u, cx + 0.9601 * u, cy + -0.1837 * u, cx + 0.9601 * u, cy + -0.1947 * u)
      p.line_to(cx + 0.9601 * u, cy + -0.3345 * u)
      p.bezier_curve_to(cx + 0.9601 * u, cy + -0.3455 * u, cx + 0.9511 * u, cy + -0.3545 * u, cx + 0.9401 * u, cy + -0.3545 * u)
      p.line_to(cx + -0.2583 * u, cy + -0.3545 * u)
      p.bezier_curve_to(cx + -0.2693 * u, cy + -0.3545 * u, cx + -0.2782 * u, cy + -0.3455 * u, cx + -0.2782 * u, cy + -0.3345 * u)
      p.line_to(cx + -0.2782 * u, cy + -0.1947 * u)
      p.bezier_curve_to(cx + -0.2782 * u, cy + -0.1837 * u, cx + -0.2693 * u, cy + -0.1748 * u, cx + -0.2583 * u, cy + -0.1748 * u)
      p.close_path()
      p.move_to(cx + -0.2782 * u, cy + 0.3345 * u)
      p.bezier_curve_to(cx + -0.2782 * u, cy + 0.3455 * u, cx + -0.2693 * u, cy + 0.3545 * u, cx + -0.2583 * u, cy + 0.3545 * u)
      p.line_to(cx + 0.9401 * u, cy + 0.3545 * u)
      p.bezier_curve_to(cx + 0.9511 * u, cy + 0.3545 * u, cx + 0.9601 * u, cy + 0.3455 * u, cx + 0.9601 * u, cy + 0.3345 * u)
      p.line_to(cx + 0.9601 * u, cy + 0.1947 * u)
      p.bezier_curve_to(cx + 0.9601 * u, cy + 0.1837 * u, cx + 0.9511 * u, cy + 0.1748 * u, cx + 0.9401 * u, cy + 0.1748 * u)
      p.line_to(cx + -0.2583 * u, cy + 0.1748 * u)
      p.bezier_curve_to(cx + -0.2693 * u, cy + 0.1748 * u, cx + -0.2782 * u, cy + 0.1837 * u, cx + -0.2782 * u, cy + 0.1947 * u)
      p.line_to(cx + -0.2782 * u, cy + 0.3345 * u)
      p.close_path()
      p.move_to(cx + 0.98 * u, cy + -0.8788 * u)
      p.line_to(cx + -0.9773 * u, cy + -0.8788 * u)
      p.bezier_curve_to(cx + -0.9883 * u, cy + -0.8788 * u, cx + -0.9973 * u, cy + -0.8698 * u, cx + -0.9973 * u, cy + -0.8588 * u)
      p.line_to(cx + -0.9973 * u, cy + -0.719 * u)
      p.bezier_curve_to(cx + -0.9973 * u, cy + -0.708 * u, cx + -0.9883 * u, cy + -0.699 * u, cx + -0.9773 * u, cy + -0.699 * u)
      p.line_to(cx + 0.98 * u, cy + -0.699 * u)
      p.bezier_curve_to(cx + 0.991 * u, cy + -0.699 * u, cx + 1 * u, cy + -0.708 * u, cx + 1 * u, cy + -0.719 * u)
      p.line_to(cx + 1 * u, cy + -0.8588 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.8698 * u, cx + 0.991 * u, cy + -0.8788 * u, cx + 0.98 * u, cy + -0.8788 * u)
      p.close_path()
      p.move_to(cx + 0.98 * u, cy + 0.699 * u)
      p.line_to(cx + -0.9773 * u, cy + 0.699 * u)
      p.bezier_curve_to(cx + -0.9883 * u, cy + 0.699 * u, cx + -0.9973 * u, cy + 0.708 * u, cx + -0.9973 * u, cy + 0.719 * u)
      p.line_to(cx + -0.9973 * u, cy + 0.8588 * u)
      p.bezier_curve_to(cx + -0.9973 * u, cy + 0.8698 * u, cx + -0.9883 * u, cy + 0.8788 * u, cx + -0.9773 * u, cy + 0.8788 * u)
      p.line_to(cx + 0.98 * u, cy + 0.8788 * u)
      p.bezier_curve_to(cx + 0.991 * u, cy + 0.8788 * u, cx + 1 * u, cy + 0.8698 * u, cx + 1 * u, cy + 0.8588 * u)
      p.line_to(cx + 1 * u, cy + 0.719 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.708 * u, cx + 0.991 * u, cy + 0.699 * u, cx + 0.98 * u, cy + 0.699 * u)
      p.close_path()
      p.move_to(cx + -0.9888 * u, cy + 0.0172 * u)
      p.line_to(cx + -0.5986 * u, cy + 0.3246 * u)
      p.bezier_curve_to(cx + -0.5841 * u, cy + 0.336 * u, cx + -0.5626 * u, cy + 0.3258 * u, cx + -0.5626 * u, cy + 0.3073 * u)
      p.line_to(cx + -0.5626 * u, cy + -0.3073 * u)
      p.bezier_curve_to(cx + -0.5626 * u, cy + -0.3258 * u, cx + -0.5838 * u, cy + -0.336 * u, cx + -0.5986 * u, cy + -0.3246 * u)
      p.line_to(cx + -0.9888 * u, cy + -0.0172 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.0085 * u, cx + -1 * u, cy + 0.0085 * u, cx + -0.9888 * u, cy + 0.0172 * u)
      p.close_path()
      p.fill()
    }
    YhColumnHeight => { // colum-height
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.82 * u, cy + 0.81 * u)
      p.line_to(cx + -0.82 * u, cy + 0.81 * u)
      p.bezier_curve_to(cx + -0.831 * u, cy + 0.81 * u, cx + -0.84 * u, cy + 0.819 * u, cx + -0.84 * u, cy + 0.83 * u)
      p.line_to(cx + -0.84 * u, cy + 0.98 * u)
      p.bezier_curve_to(cx + -0.84 * u, cy + 0.991 * u, cx + -0.831 * u, cy + 1 * u, cx + -0.82 * u, cy + 1 * u)
      p.line_to(cx + 0.82 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.831 * u, cy + 1 * u, cx + 0.84 * u, cy + 0.991 * u, cx + 0.84 * u, cy + 0.98 * u)
      p.line_to(cx + 0.84 * u, cy + 0.83 * u)
      p.bezier_curve_to(cx + 0.84 * u, cy + 0.819 * u, cx + 0.831 * u, cy + 0.81 * u, cx + 0.82 * u, cy + 0.81 * u)
      p.close_path()
      p.move_to(cx + 0.82 * u, cy + -1 * u)
      p.line_to(cx + -0.82 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.831 * u, cy + -1 * u, cx + -0.84 * u, cy + -0.991 * u, cx + -0.84 * u, cy + -0.98 * u)
      p.line_to(cx + -0.84 * u, cy + -0.83 * u)
      p.bezier_curve_to(cx + -0.84 * u, cy + -0.819 * u, cx + -0.831 * u, cy + -0.81 * u, cx + -0.82 * u, cy + -0.81 * u)
      p.line_to(cx + 0.82 * u, cy + -0.81 * u)
      p.bezier_curve_to(cx + 0.831 * u, cy + -0.81 * u, cx + 0.84 * u, cy + -0.819 * u, cx + 0.84 * u, cy + -0.83 * u)
      p.line_to(cx + 0.84 * u, cy + -0.98 * u)
      p.bezier_curve_to(cx + 0.84 * u, cy + -0.991 * u, cx + 0.831 * u, cy + -1 * u, cx + 0.82 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.247 * u, cy + -0.335 * u)
      p.bezier_curve_to(cx + 0.262 * u, cy + -0.335 * u, cx + 0.2705 * u, cy + -0.3525 * u, cx + 0.2612 * u, cy + -0.3643 * u)
      p.line_to(cx + 0.0092 * u, cy + -0.6833 * u)
      p.bezier_curve_to(cx + 0.002 * u, cy + -0.6925 * u, cx + -0.012 * u, cy + -0.6925 * u, cx + -0.019 * u, cy + -0.6833 * u)
      p.line_to(cx + -0.271 * u, cy + -0.3643 * u)
      p.bezier_curve_to(cx + -0.2802 * u, cy + -0.3525 * u, cx + -0.272 * u, cy + -0.335 * u, cx + -0.2567 * u, cy + -0.335 * u)
      p.line_to(cx + -0.09 * u, cy + -0.335 * u)
      p.line_to(cx + -0.09 * u, cy + 0.335 * u)
      p.line_to(cx + -0.247 * u, cy + 0.335 * u)
      p.bezier_curve_to(cx + -0.262 * u, cy + 0.335 * u, cx + -0.2705 * u, cy + 0.3525 * u, cx + -0.2612 * u, cy + 0.3643 * u)
      p.line_to(cx + -0.0092 * u, cy + 0.683 * u)
      p.bezier_curve_to(cx + -0.002 * u, cy + 0.6923 * u, cx + 0.012 * u, cy + 0.6923 * u, cx + 0.019 * u, cy + 0.683 * u)
      p.line_to(cx + 0.271 * u, cy + 0.3643 * u)
      p.bezier_curve_to(cx + 0.2802 * u, cy + 0.3525 * u, cx + 0.272 * u, cy + 0.335 * u, cx + 0.2567 * u, cy + 0.335 * u)
      p.line_to(cx + 0.09 * u, cy + 0.335 * u)
      p.line_to(cx + 0.09 * u, cy + -0.335 * u)
      p.line_to(cx + 0.247 * u, cy + -0.335 * u)
      p.close_path()
      p.fill()
    }
    YhColumnWidth => { // column-width
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.83 * u, cy + -0.84 * u)
      p.line_to(cx + -0.98 * u, cy + -0.84 * u)
      p.bezier_curve_to(cx + -0.991 * u, cy + -0.84 * u, cx + -1 * u, cy + -0.831 * u, cx + -1 * u, cy + -0.82 * u)
      p.line_to(cx + -1 * u, cy + 0.82 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.831 * u, cx + -0.991 * u, cy + 0.84 * u, cx + -0.98 * u, cy + 0.84 * u)
      p.line_to(cx + -0.83 * u, cy + 0.84 * u)
      p.bezier_curve_to(cx + -0.819 * u, cy + 0.84 * u, cx + -0.81 * u, cy + 0.831 * u, cx + -0.81 * u, cy + 0.82 * u)
      p.line_to(cx + -0.81 * u, cy + -0.82 * u)
      p.bezier_curve_to(cx + -0.81 * u, cy + -0.831 * u, cx + -0.819 * u, cy + -0.84 * u, cx + -0.83 * u, cy + -0.84 * u)
      p.close_path()
      p.move_to(cx + 0.98 * u, cy + -0.84 * u)
      p.line_to(cx + 0.83 * u, cy + -0.84 * u)
      p.bezier_curve_to(cx + 0.819 * u, cy + -0.84 * u, cx + 0.81 * u, cy + -0.831 * u, cx + 0.81 * u, cy + -0.82 * u)
      p.line_to(cx + 0.81 * u, cy + 0.82 * u)
      p.bezier_curve_to(cx + 0.81 * u, cy + 0.831 * u, cx + 0.819 * u, cy + 0.84 * u, cx + 0.83 * u, cy + 0.84 * u)
      p.line_to(cx + 0.98 * u, cy + 0.84 * u)
      p.bezier_curve_to(cx + 0.991 * u, cy + 0.84 * u, cx + 1 * u, cy + 0.831 * u, cx + 1 * u, cy + 0.82 * u)
      p.line_to(cx + 1 * u, cy + -0.82 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.831 * u, cx + 0.991 * u, cy + -0.84 * u, cx + 0.98 * u, cy + -0.84 * u)
      p.close_path()
      p.move_to(cx + 0.6833 * u, cy + -0.0192 * u)
      p.line_to(cx + 0.3643 * u, cy + -0.271 * u)
      p.bezier_curve_to(cx + 0.3525 * u, cy + -0.2802 * u, cx + 0.335 * u, cy + -0.272 * u, cx + 0.335 * u, cy + -0.2567 * u)
      p.line_to(cx + 0.335 * u, cy + -0.09 * u)
      p.line_to(cx + -0.335 * u, cy + -0.09 * u)
      p.line_to(cx + -0.335 * u, cy + -0.247 * u)
      p.bezier_curve_to(cx + -0.335 * u, cy + -0.262 * u, cx + -0.3525 * u, cy + -0.2705 * u, cx + -0.3643 * u, cy + -0.2612 * u)
      p.line_to(cx + -0.6833 * u, cy + -0.0092 * u)
      p.bezier_curve_to(cx + -0.6925 * u, cy + -0.002 * u, cx + -0.6925 * u, cy + 0.012 * u, cx + -0.6833 * u, cy + 0.019 * u)
      p.line_to(cx + -0.3645 * u, cy + 0.271 * u)
      p.bezier_curve_to(cx + -0.3528 * u, cy + 0.2802 * u, cx + -0.3352 * u, cy + 0.272 * u, cx + -0.3352 * u, cy + 0.2567 * u)
      p.line_to(cx + -0.3352 * u, cy + 0.09 * u)
      p.line_to(cx + 0.3347 * u, cy + 0.09 * u)
      p.line_to(cx + 0.3347 * u, cy + 0.247 * u)
      p.bezier_curve_to(cx + 0.3347 * u, cy + 0.262 * u, cx + 0.3523 * u, cy + 0.2705 * u, cx + 0.364 * u, cy + 0.2612 * u)
      p.line_to(cx + 0.6827 * u, cy + 0.0092 * u)
      p.bezier_curve_to(cx + 0.6923 * u, cy + 0.002 * u, cx + 0.6923 * u, cy + -0.012 * u, cx + 0.6833 * u, cy + -0.0192 * u)
      p.close_path()
      p.fill()
    }
    YhVAlignBottom => { // vertical-align-botto
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9772 * u, cy + 0.7528 * u)
      p.line_to(cx + -0.9772 * u, cy + 0.7528 * u)
      p.bezier_curve_to(cx + -0.9899 * u, cy + 0.7528 * u, cx + -1 * u, cy + 0.7629 * u, cx + -1 * u, cy + 0.7753 * u)
      p.line_to(cx + -1 * u, cy + 0.9438 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9562 * u, cx + -0.9899 * u, cy + 0.9663 * u, cx + -0.9772 * u, cy + 0.9663 * u)
      p.line_to(cx + 0.9772 * u, cy + 0.9663 * u)
      p.bezier_curve_to(cx + 0.9899 * u, cy + 0.9663 * u, cx + 1 * u, cy + 0.9562 * u, cx + 1 * u, cy + 0.9438 * u)
      p.line_to(cx + 1 * u, cy + 0.7753 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.7629 * u, cx + 0.9899 * u, cy + 0.7528 * u, cx + 0.9772 * u, cy + 0.7528 * u)
      p.close_path()
      p.move_to(cx + -0.0177 * u, cy + 0.441 * u)
      p.bezier_curve_to(cx + -0.0087 * u, cy + 0.4525 * u, cx + 0.0087 * u, cy + 0.4525 * u, cx + 0.0177 * u, cy + 0.441 * u)
      p.line_to(cx + 0.3323 * u, cy + 0.043 * u)
      p.bezier_curve_to(cx + 0.3438 * u, cy + 0.0284 * u, cx + 0.3334 * u, cy + 0.0067 * u, cx + 0.3146 * u, cy + 0.0067 * u)
      p.line_to(cx + 0.1065 * u, cy + 0.0067 * u)
      p.line_to(cx + 0.1065 * u, cy + -0.9438 * u)
      p.bezier_curve_to(cx + 0.1065 * u, cy + -0.9562 * u, cx + 0.0963 * u, cy + -0.9663 * u, cx + 0.084 * u, cy + -0.9663 * u)
      p.line_to(cx + -0.0846 * u, cy + -0.9663 * u)
      p.bezier_curve_to(cx + -0.0969 * u, cy + -0.9663 * u, cx + -0.107 * u, cy + -0.9562 * u, cx + -0.107 * u, cy + -0.9438 * u)
      p.line_to(cx + -0.107 * u, cy + 0.0065 * u)
      p.line_to(cx + -0.3146 * u, cy + 0.0065 * u)
      p.bezier_curve_to(cx + -0.3334 * u, cy + 0.0065 * u, cx + -0.3438 * u, cy + 0.0281 * u, cx + -0.3323 * u, cy + 0.0427 * u)
      p.line_to(cx + -0.0177 * u, cy + 0.441 * u)
      p.close_path()
      p.fill()
    }
    YhVAlignMiddle => { // vertical-align-middl
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.8363 * u, cy + -0.0913 * u)
      p.line_to(cx + -0.8363 * u, cy + -0.0913 * u)
      p.bezier_curve_to(cx + -0.8471 * u, cy + -0.0913 * u, cx + -0.8558 * u, cy + -0.0827 * u, cx + -0.8558 * u, cy + -0.0721 * u)
      p.line_to(cx + -0.8558 * u, cy + 0.0721 * u)
      p.bezier_curve_to(cx + -0.8558 * u, cy + 0.0827 * u, cx + -0.8471 * u, cy + 0.0913 * u, cx + -0.8363 * u, cy + 0.0913 * u)
      p.line_to(cx + 0.8363 * u, cy + 0.0913 * u)
      p.bezier_curve_to(cx + 0.8471 * u, cy + 0.0913 * u, cx + 0.8558 * u, cy + 0.0827 * u, cx + 0.8558 * u, cy + 0.0721 * u)
      p.line_to(cx + 0.8558 * u, cy + -0.0721 * u)
      p.bezier_curve_to(cx + 0.8558 * u, cy + -0.0827 * u, cx + 0.8471 * u, cy + -0.0913 * u, cx + 0.8363 * u, cy + -0.0913 * u)
      p.close_path()
      p.move_to(cx + -0.0137 * u, cy + -0.2709 * u)
      p.bezier_curve_to(cx + -0.0067 * u, cy + -0.262 * u, cx + 0.0067 * u, cy + -0.262 * u, cx + 0.0135 * u, cy + -0.2709 * u)
      p.line_to(cx + 0.2558 * u, cy + -0.5774 * u)
      p.bezier_curve_to(cx + 0.2647 * u, cy + -0.5887 * u, cx + 0.2567 * u, cy + -0.6055 * u, cx + 0.2421 * u, cy + -0.6055 * u)
      p.line_to(cx + 0.0913 * u, cy + -0.6055 * u)
      p.line_to(cx + 0.0913 * u, cy + -0.9808 * u)
      p.bezier_curve_to(cx + 0.0913 * u, cy + -0.9913 * u, cx + 0.0827 * u, cy + -1 * u, cx + 0.0721 * u, cy + -1 * u)
      p.line_to(cx + -0.0721 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.0827 * u, cy + -1 * u, cx + -0.0913 * u, cy + -0.9913 * u, cx + -0.0913 * u, cy + -0.9808 * u)
      p.line_to(cx + -0.0913 * u, cy + -0.6058 * u)
      p.line_to(cx + -0.2423 * u, cy + -0.6058 * u)
      p.bezier_curve_to(cx + -0.2567 * u, cy + -0.6058 * u, cx + -0.2649 * u, cy + -0.5889 * u, cx + -0.256 * u, cy + -0.5776 * u)
      p.line_to(cx + -0.0137 * u, cy + -0.2709 * u)
      p.close_path()
      p.move_to(cx + 0.0137 * u, cy + 0.2709 * u)
      p.bezier_curve_to(cx + 0.0067 * u, cy + 0.262 * u, cx + -0.0067 * u, cy + 0.262 * u, cx + -0.0135 * u, cy + 0.2709 * u)
      p.line_to(cx + -0.2558 * u, cy + 0.5776 * u)
      p.bezier_curve_to(cx + -0.2647 * u, cy + 0.5889 * u, cx + -0.2567 * u, cy + 0.6058 * u, cx + -0.2421 * u, cy + 0.6058 * u)
      p.line_to(cx + -0.0913 * u, cy + 0.6058 * u)
      p.line_to(cx + -0.0913 * u, cy + 0.9808 * u)
      p.bezier_curve_to(cx + -0.0913 * u, cy + 0.9913 * u, cx + -0.0827 * u, cy + 1 * u, cx + -0.0721 * u, cy + 1 * u)
      p.line_to(cx + 0.0721 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.0827 * u, cy + 1 * u, cx + 0.0913 * u, cy + 0.9913 * u, cx + 0.0913 * u, cy + 0.9808 * u)
      p.line_to(cx + 0.0913 * u, cy + 0.6058 * u)
      p.line_to(cx + 0.2423 * u, cy + 0.6058 * u)
      p.bezier_curve_to(cx + 0.2567 * u, cy + 0.6058 * u, cx + 0.2649 * u, cy + 0.5889 * u, cx + 0.256 * u, cy + 0.5776 * u)
      p.line_to(cx + 0.0137 * u, cy + 0.2709 * u)
      p.close_path()
      p.fill()
    }
    YhVAlignTop => { // vertical-align-top
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9772 * u, cy + -0.9663 * u)
      p.line_to(cx + -0.9772 * u, cy + -0.9663 * u)
      p.bezier_curve_to(cx + -0.9899 * u, cy + -0.9663 * u, cx + -1 * u, cy + -0.9562 * u, cx + -1 * u, cy + -0.9438 * u)
      p.line_to(cx + -1 * u, cy + -0.7753 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.7629 * u, cx + -0.9899 * u, cy + -0.7528 * u, cx + -0.9772 * u, cy + -0.7528 * u)
      p.line_to(cx + 0.9772 * u, cy + -0.7528 * u)
      p.bezier_curve_to(cx + 0.9899 * u, cy + -0.7528 * u, cx + 1 * u, cy + -0.7629 * u, cx + 1 * u, cy + -0.7753 * u)
      p.line_to(cx + 1 * u, cy + -0.9438 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.9562 * u, cx + 0.9899 * u, cy + -0.9663 * u, cx + 0.9772 * u, cy + -0.9663 * u)
      p.close_path()
      p.move_to(cx + 0.0177 * u, cy + -0.441 * u)
      p.bezier_curve_to(cx + 0.0087 * u, cy + -0.4525 * u, cx + -0.0087 * u, cy + -0.4525 * u, cx + -0.0177 * u, cy + -0.441 * u)
      p.line_to(cx + -0.3323 * u, cy + -0.043 * u)
      p.bezier_curve_to(cx + -0.3438 * u, cy + -0.0284 * u, cx + -0.3334 * u, cy + -0.0067 * u, cx + -0.3146 * u, cy + -0.0067 * u)
      p.line_to(cx + -0.107 * u, cy + -0.0067 * u)
      p.line_to(cx + -0.107 * u, cy + 0.9438 * u)
      p.bezier_curve_to(cx + -0.107 * u, cy + 0.9562 * u, cx + -0.0969 * u, cy + 0.9663 * u, cx + -0.0846 * u, cy + 0.9663 * u)
      p.line_to(cx + 0.084 * u, cy + 0.9663 * u)
      p.bezier_curve_to(cx + 0.0963 * u, cy + 0.9663 * u, cx + 0.1065 * u, cy + 0.9562 * u, cx + 0.1065 * u, cy + 0.9438 * u)
      p.line_to(cx + 0.1065 * u, cy + -0.0065 * u)
      p.line_to(cx + 0.3146 * u, cy + -0.0065 * u)
      p.bezier_curve_to(cx + 0.3334 * u, cy + -0.0065 * u, cx + 0.3438 * u, cy + -0.0281 * u, cx + 0.3323 * u, cy + -0.0427 * u)
      p.line_to(cx + 0.0177 * u, cy + -0.441 * u)
      p.close_path()
      p.fill()
    }
    YhBorderOuter => { // border-outer
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.92 * u, cy + -1 * u)
      p.line_to(cx + -0.92 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.9643 * u, cy + -1 * u, cx + -1 * u, cy + -0.9643 * u, cx + -1 * u, cy + -0.92 * u)
      p.line_to(cx + -1 * u, cy + 0.92 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9643 * u, cx + -0.9643 * u, cy + 1 * u, cx + -0.92 * u, cy + 1 * u)
      p.line_to(cx + 0.92 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.9643 * u, cy + 1 * u, cx + 1 * u, cy + 0.9643 * u, cx + 1 * u, cy + 0.92 * u)
      p.line_to(cx + 1 * u, cy + -0.92 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.9643 * u, cx + 0.9643 * u, cy + -1 * u, cx + 0.92 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.82 * u, cy + 0.82 * u)
      p.line_to(cx + -0.82 * u, cy + 0.82 * u)
      p.line_to(cx + -0.82 * u, cy + -0.82 * u)
      p.line_to(cx + 0.82 * u, cy + -0.82 * u)
      p.line_to(cx + 0.82 * u, cy + 0.82 * u)
      p.close_path()
      p.move_to(cx + -0.07 * u, cy + -0.365 * u)
      p.line_to(cx + 0.07 * u, cy + -0.365 * u)
      p.bezier_curve_to(cx + 0.081 * u, cy + -0.365 * u, cx + 0.09 * u, cy + -0.374 * u, cx + 0.09 * u, cy + -0.385 * u)
      p.line_to(cx + 0.09 * u, cy + -0.525 * u)
      p.bezier_curve_to(cx + 0.09 * u, cy + -0.536 * u, cx + 0.081 * u, cy + -0.545 * u, cx + 0.07 * u, cy + -0.545 * u)
      p.line_to(cx + -0.07 * u, cy + -0.545 * u)
      p.bezier_curve_to(cx + -0.081 * u, cy + -0.545 * u, cx + -0.09 * u, cy + -0.536 * u, cx + -0.09 * u, cy + -0.525 * u)
      p.line_to(cx + -0.09 * u, cy + -0.385 * u)
      p.bezier_curve_to(cx + -0.09 * u, cy + -0.374 * u, cx + -0.081 * u, cy + -0.365 * u, cx + -0.07 * u, cy + -0.365 * u)
      p.close_path()
      p.move_to(cx + -0.525 * u, cy + 0.09 * u)
      p.line_to(cx + -0.385 * u, cy + 0.09 * u)
      p.bezier_curve_to(cx + -0.374 * u, cy + 0.09 * u, cx + -0.365 * u, cy + 0.081 * u, cx + -0.365 * u, cy + 0.07 * u)
      p.line_to(cx + -0.365 * u, cy + -0.07 * u)
      p.bezier_curve_to(cx + -0.365 * u, cy + -0.081 * u, cx + -0.374 * u, cy + -0.09 * u, cx + -0.385 * u, cy + -0.09 * u)
      p.line_to(cx + -0.525 * u, cy + -0.09 * u)
      p.bezier_curve_to(cx + -0.536 * u, cy + -0.09 * u, cx + -0.545 * u, cy + -0.081 * u, cx + -0.545 * u, cy + -0.07 * u)
      p.line_to(cx + -0.545 * u, cy + 0.07 * u)
      p.bezier_curve_to(cx + -0.545 * u, cy + 0.081 * u, cx + -0.536 * u, cy + 0.09 * u, cx + -0.525 * u, cy + 0.09 * u)
      p.close_path()
      p.move_to(cx + 0.385 * u, cy + 0.09 * u)
      p.line_to(cx + 0.525 * u, cy + 0.09 * u)
      p.bezier_curve_to(cx + 0.536 * u, cy + 0.09 * u, cx + 0.545 * u, cy + 0.081 * u, cx + 0.545 * u, cy + 0.07 * u)
      p.line_to(cx + 0.545 * u, cy + -0.07 * u)
      p.bezier_curve_to(cx + 0.545 * u, cy + -0.081 * u, cx + 0.536 * u, cy + -0.09 * u, cx + 0.525 * u, cy + -0.09 * u)
      p.line_to(cx + 0.385 * u, cy + -0.09 * u)
      p.bezier_curve_to(cx + 0.374 * u, cy + -0.09 * u, cx + 0.365 * u, cy + -0.081 * u, cx + 0.365 * u, cy + -0.07 * u)
      p.line_to(cx + 0.365 * u, cy + 0.07 * u)
      p.bezier_curve_to(cx + 0.365 * u, cy + 0.081 * u, cx + 0.374 * u, cy + 0.09 * u, cx + 0.385 * u, cy + 0.09 * u)
      p.close_path()
      p.move_to(cx + -0.07 * u, cy + 0.09 * u)
      p.line_to(cx + 0.07 * u, cy + 0.09 * u)
      p.bezier_curve_to(cx + 0.081 * u, cy + 0.09 * u, cx + 0.09 * u, cy + 0.081 * u, cx + 0.09 * u, cy + 0.07 * u)
      p.line_to(cx + 0.09 * u, cy + -0.07 * u)
      p.bezier_curve_to(cx + 0.09 * u, cy + -0.081 * u, cx + 0.081 * u, cy + -0.09 * u, cx + 0.07 * u, cy + -0.09 * u)
      p.line_to(cx + -0.07 * u, cy + -0.09 * u)
      p.bezier_curve_to(cx + -0.081 * u, cy + -0.09 * u, cx + -0.09 * u, cy + -0.081 * u, cx + -0.09 * u, cy + -0.07 * u)
      p.line_to(cx + -0.09 * u, cy + 0.07 * u)
      p.bezier_curve_to(cx + -0.09 * u, cy + 0.081 * u, cx + -0.081 * u, cy + 0.09 * u, cx + -0.07 * u, cy + 0.09 * u)
      p.close_path()
      p.move_to(cx + -0.07 * u, cy + 0.545 * u)
      p.line_to(cx + 0.07 * u, cy + 0.545 * u)
      p.bezier_curve_to(cx + 0.081 * u, cy + 0.545 * u, cx + 0.09 * u, cy + 0.536 * u, cx + 0.09 * u, cy + 0.525 * u)
      p.line_to(cx + 0.09 * u, cy + 0.385 * u)
      p.bezier_curve_to(cx + 0.09 * u, cy + 0.374 * u, cx + 0.081 * u, cy + 0.365 * u, cx + 0.07 * u, cy + 0.365 * u)
      p.line_to(cx + -0.07 * u, cy + 0.365 * u)
      p.bezier_curve_to(cx + -0.081 * u, cy + 0.365 * u, cx + -0.09 * u, cy + 0.374 * u, cx + -0.09 * u, cy + 0.385 * u)
      p.line_to(cx + -0.09 * u, cy + 0.525 * u)
      p.bezier_curve_to(cx + -0.09 * u, cy + 0.536 * u, cx + -0.081 * u, cy + 0.545 * u, cx + -0.07 * u, cy + 0.545 * u)
      p.close_path()
      p.fill()
    }
    YhBorderTop => { // border-top
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9783 * u, cy + -1 * u)
      p.line_to(cx + -0.9783 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -1 * u, cx + -1 * u, cy + -0.9902 * u, cx + -1 * u, cy + -0.9783 * u)
      p.line_to(cx + -1 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.8141 * u, cx + -0.9902 * u, cy + -0.8043 * u, cx + -0.9783 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.9783 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + -0.8043 * u, cx + 1 * u, cy + -0.8141 * u, cx + 1 * u, cy + -0.8261 * u)
      p.line_to(cx + 1 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.9902 * u, cx + 0.9902 * u, cy + -1 * u, cx + 0.9783 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + -0.5489 * u)
      p.line_to(cx + -0.9783 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -0.5489 * u, cx + -1 * u, cy + -0.5391 * u, cx + -1 * u, cy + -0.5272 * u)
      p.line_to(cx + -1 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.363 * u, cx + -0.9902 * u, cy + -0.3533 * u, cx + -0.9783 * u, cy + -0.3533 * u)
      p.line_to(cx + -0.8261 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + -0.3533 * u, cx + -0.8043 * u, cy + -0.363 * u, cx + -0.8043 * u, cy + -0.375 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.5391 * u, cx + -0.8141 * u, cy + -0.5489 * u, cx + -0.8261 * u, cy + -0.5489 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.9783 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + 0.8043 * u, cx + -1 * u, cy + 0.8141 * u, cx + -1 * u, cy + 0.8261 * u)
      p.line_to(cx + -1 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9902 * u, cx + -0.9902 * u, cy + 1 * u, cx + -0.9783 * u, cy + 1 * u)
      p.line_to(cx + -0.8261 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 1 * u, cx + -0.8043 * u, cy + 0.9902 * u, cx + -0.8043 * u, cy + 0.9783 * u)
      p.line_to(cx + -0.8043 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + 0.8141 * u, cx + -0.8141 * u, cy + 0.8043 * u, cx + -0.8261 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.9783 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -0.0978 * u, cx + -1 * u, cy + -0.088 * u, cx + -1 * u, cy + -0.0761 * u)
      p.line_to(cx + -1 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.088 * u, cx + -0.9902 * u, cy + 0.0978 * u, cx + -0.9783 * u, cy + 0.0978 * u)
      p.line_to(cx + -0.8261 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 0.0978 * u, cx + -0.8043 * u, cy + 0.088 * u, cx + -0.8043 * u, cy + 0.0761 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.088 * u, cx + -0.8141 * u, cy + -0.0978 * u, cx + -0.8261 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + 0.3533 * u)
      p.line_to(cx + -0.9783 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + 0.3533 * u, cx + -1 * u, cy + 0.363 * u, cx + -1 * u, cy + 0.375 * u)
      p.line_to(cx + -1 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.5391 * u, cx + -0.9902 * u, cy + 0.5489 * u, cx + -0.9783 * u, cy + 0.5489 * u)
      p.line_to(cx + -0.8261 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 0.5489 * u, cx + -0.8043 * u, cy + 0.5391 * u, cx + -0.8043 * u, cy + 0.5272 * u)
      p.line_to(cx + -0.8043 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + 0.363 * u, cx + -0.8141 * u, cy + 0.3533 * u, cx + -0.8261 * u, cy + 0.3533 * u)
      p.close_path()
      p.move_to(cx + -0.375 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.5272 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + -0.0978 * u, cx + -0.5489 * u, cy + -0.088 * u, cx + -0.5489 * u, cy + -0.0761 * u)
      p.line_to(cx + -0.5489 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + 0.088 * u, cx + -0.5391 * u, cy + 0.0978 * u, cx + -0.5272 * u, cy + 0.0978 * u)
      p.line_to(cx + -0.375 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + 0.0978 * u, cx + -0.3533 * u, cy + 0.088 * u, cx + -0.3533 * u, cy + 0.0761 * u)
      p.line_to(cx + -0.3533 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + -0.088 * u, cx + -0.363 * u, cy + -0.0978 * u, cx + -0.375 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + -0.375 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.5272 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + 0.8043 * u, cx + -0.5489 * u, cy + 0.8141 * u, cx + -0.5489 * u, cy + 0.8261 * u)
      p.line_to(cx + -0.5489 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + 0.9902 * u, cx + -0.5391 * u, cy + 1 * u, cx + -0.5272 * u, cy + 1 * u)
      p.line_to(cx + -0.375 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + 1 * u, cx + -0.3533 * u, cy + 0.9902 * u, cx + -0.3533 * u, cy + 0.9783 * u)
      p.line_to(cx + -0.3533 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + 0.8141 * u, cx + -0.363 * u, cy + 0.8043 * u, cx + -0.375 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.5272 * u, cy + 0.8043 * u)
      p.line_to(cx + 0.375 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + 0.8043 * u, cx + 0.3533 * u, cy + 0.8141 * u, cx + 0.3533 * u, cy + 0.8261 * u)
      p.line_to(cx + 0.3533 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + 0.9902 * u, cx + 0.363 * u, cy + 1 * u, cx + 0.375 * u, cy + 1 * u)
      p.line_to(cx + 0.5272 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + 1 * u, cx + 0.5489 * u, cy + 0.9902 * u, cx + 0.5489 * u, cy + 0.9783 * u)
      p.line_to(cx + 0.5489 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + 0.8141 * u, cx + 0.5391 * u, cy + 0.8043 * u, cx + 0.5272 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.5272 * u, cy + -0.0978 * u)
      p.line_to(cx + 0.375 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + -0.0978 * u, cx + 0.3533 * u, cy + -0.088 * u, cx + 0.3533 * u, cy + -0.0761 * u)
      p.line_to(cx + 0.3533 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + 0.088 * u, cx + 0.363 * u, cy + 0.0978 * u, cx + 0.375 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.5272 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + 0.0978 * u, cx + 0.5489 * u, cy + 0.088 * u, cx + 0.5489 * u, cy + 0.0761 * u)
      p.line_to(cx + 0.5489 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + -0.088 * u, cx + 0.5391 * u, cy + -0.0978 * u, cx + 0.5272 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -0.0978 * u)
      p.line_to(cx + 0.8261 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -0.0978 * u, cx + 0.8043 * u, cy + -0.088 * u, cx + 0.8043 * u, cy + -0.0761 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.088 * u, cx + 0.8141 * u, cy + 0.0978 * u, cx + 0.8261 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.9783 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 0.0978 * u, cx + 1 * u, cy + 0.088 * u, cx + 1 * u, cy + 0.0761 * u)
      p.line_to(cx + 1 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.088 * u, cx + 0.9902 * u, cy + -0.0978 * u, cx + 0.9783 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.0761 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -0.0978 * u, cx + -0.0978 * u, cy + -0.088 * u, cx + -0.0978 * u, cy + -0.0761 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.088 * u, cx + -0.088 * u, cy + 0.0978 * u, cx + -0.0761 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.0761 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 0.0978 * u, cx + 0.0978 * u, cy + 0.088 * u, cx + 0.0978 * u, cy + 0.0761 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.088 * u, cx + 0.088 * u, cy + -0.0978 * u, cx + 0.0761 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + 0.8043 * u)
      p.line_to(cx + 0.8261 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + 0.8043 * u, cx + 0.8043 * u, cy + 0.8141 * u, cx + 0.8043 * u, cy + 0.8261 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.9902 * u, cx + 0.8141 * u, cy + 1 * u, cx + 0.8261 * u, cy + 1 * u)
      p.line_to(cx + 0.9783 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 1 * u, cx + 1 * u, cy + 0.9902 * u, cx + 1 * u, cy + 0.9783 * u)
      p.line_to(cx + 1 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.8141 * u, cx + 0.9902 * u, cy + 0.8043 * u, cx + 0.9783 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.0761 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + 0.8043 * u, cx + -0.0978 * u, cy + 0.8141 * u, cx + -0.0978 * u, cy + 0.8261 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.9902 * u, cx + -0.088 * u, cy + 1 * u, cx + -0.0761 * u, cy + 1 * u)
      p.line_to(cx + 0.0761 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 1 * u, cx + 0.0978 * u, cy + 0.9902 * u, cx + 0.0978 * u, cy + 0.9783 * u)
      p.line_to(cx + 0.0978 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + 0.8141 * u, cx + 0.088 * u, cy + 0.8043 * u, cx + 0.0761 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -0.5489 * u)
      p.line_to(cx + 0.8261 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -0.5489 * u, cx + 0.8043 * u, cy + -0.5391 * u, cx + 0.8043 * u, cy + -0.5272 * u)
      p.line_to(cx + 0.8043 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + -0.363 * u, cx + 0.8141 * u, cy + -0.3533 * u, cx + 0.8261 * u, cy + -0.3533 * u)
      p.line_to(cx + 0.9783 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + -0.3533 * u, cx + 1 * u, cy + -0.363 * u, cx + 1 * u, cy + -0.375 * u)
      p.line_to(cx + 1 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.5391 * u, cx + 0.9902 * u, cy + -0.5489 * u, cx + 0.9783 * u, cy + -0.5489 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + -0.5489 * u)
      p.line_to(cx + -0.0761 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -0.5489 * u, cx + -0.0978 * u, cy + -0.5391 * u, cx + -0.0978 * u, cy + -0.5272 * u)
      p.line_to(cx + -0.0978 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + -0.363 * u, cx + -0.088 * u, cy + -0.3533 * u, cx + -0.0761 * u, cy + -0.3533 * u)
      p.line_to(cx + 0.0761 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + -0.3533 * u, cx + 0.0978 * u, cy + -0.363 * u, cx + 0.0978 * u, cy + -0.375 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.5391 * u, cx + 0.088 * u, cy + -0.5489 * u, cx + 0.0761 * u, cy + -0.5489 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + 0.3533 * u)
      p.line_to(cx + 0.8261 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + 0.3533 * u, cx + 0.8043 * u, cy + 0.363 * u, cx + 0.8043 * u, cy + 0.375 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.5391 * u, cx + 0.8141 * u, cy + 0.5489 * u, cx + 0.8261 * u, cy + 0.5489 * u)
      p.line_to(cx + 0.9783 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 0.5489 * u, cx + 1 * u, cy + 0.5391 * u, cx + 1 * u, cy + 0.5272 * u)
      p.line_to(cx + 1 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.363 * u, cx + 0.9902 * u, cy + 0.3533 * u, cx + 0.9783 * u, cy + 0.3533 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + 0.3533 * u)
      p.line_to(cx + -0.0761 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + 0.3533 * u, cx + -0.0978 * u, cy + 0.363 * u, cx + -0.0978 * u, cy + 0.375 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.5391 * u, cx + -0.088 * u, cy + 0.5489 * u, cx + -0.0761 * u, cy + 0.5489 * u)
      p.line_to(cx + 0.0761 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 0.5489 * u, cx + 0.0978 * u, cy + 0.5391 * u, cx + 0.0978 * u, cy + 0.5272 * u)
      p.line_to(cx + 0.0978 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + 0.363 * u, cx + 0.088 * u, cy + 0.3533 * u, cx + 0.0761 * u, cy + 0.3533 * u)
      p.close_path()
      p.fill()
    }
    YhBorderBottom => { // border-bottom
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9783 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.9783 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + 0.8043 * u, cx + -1 * u, cy + 0.8141 * u, cx + -1 * u, cy + 0.8261 * u)
      p.line_to(cx + -1 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9902 * u, cx + -0.9902 * u, cy + 1 * u, cx + -0.9783 * u, cy + 1 * u)
      p.line_to(cx + 0.9783 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 1 * u, cx + 1 * u, cy + 0.9902 * u, cx + 1 * u, cy + 0.9783 * u)
      p.line_to(cx + 1 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.8141 * u, cx + 0.9902 * u, cy + 0.8043 * u, cx + 0.9783 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.9783 * u, cy + 0.5489 * u)
      p.line_to(cx + -0.8261 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 0.5489 * u, cx + -0.8043 * u, cy + 0.5391 * u, cx + -0.8043 * u, cy + 0.5272 * u)
      p.line_to(cx + -0.8043 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + 0.363 * u, cx + -0.8141 * u, cy + 0.3533 * u, cx + -0.8261 * u, cy + 0.3533 * u)
      p.line_to(cx + -0.9783 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + 0.3533 * u, cx + -1 * u, cy + 0.363 * u, cx + -1 * u, cy + 0.375 * u)
      p.line_to(cx + -1 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.5391 * u, cx + -0.9902 * u, cy + 0.5489 * u, cx + -0.9783 * u, cy + 0.5489 * u)
      p.close_path()
      p.move_to(cx + -0.9783 * u, cy + -0.8043 * u)
      p.line_to(cx + -0.8261 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + -0.8043 * u, cx + -0.8043 * u, cy + -0.8141 * u, cx + -0.8043 * u, cy + -0.8261 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.9902 * u, cx + -0.8141 * u, cy + -1 * u, cx + -0.8261 * u, cy + -1 * u)
      p.line_to(cx + -0.9783 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -1 * u, cx + -1 * u, cy + -0.9902 * u, cx + -1 * u, cy + -0.9783 * u)
      p.line_to(cx + -1 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.8141 * u, cx + -0.9902 * u, cy + -0.8043 * u, cx + -0.9783 * u, cy + -0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.9783 * u, cy + 0.0978 * u)
      p.line_to(cx + -0.8261 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 0.0978 * u, cx + -0.8043 * u, cy + 0.088 * u, cx + -0.8043 * u, cy + 0.0761 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.088 * u, cx + -0.8141 * u, cy + -0.0978 * u, cx + -0.8261 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.9783 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -0.0978 * u, cx + -1 * u, cy + -0.088 * u, cx + -1 * u, cy + -0.0761 * u)
      p.line_to(cx + -1 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.088 * u, cx + -0.9902 * u, cy + 0.0978 * u, cx + -0.9783 * u, cy + 0.0978 * u)
      p.close_path()
      p.move_to(cx + -0.9783 * u, cy + -0.3533 * u)
      p.line_to(cx + -0.8261 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + -0.3533 * u, cx + -0.8043 * u, cy + -0.363 * u, cx + -0.8043 * u, cy + -0.375 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.5391 * u, cx + -0.8141 * u, cy + -0.5489 * u, cx + -0.8261 * u, cy + -0.5489 * u)
      p.line_to(cx + -0.9783 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -0.5489 * u, cx + -1 * u, cy + -0.5391 * u, cx + -1 * u, cy + -0.5272 * u)
      p.line_to(cx + -1 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.363 * u, cx + -0.9902 * u, cy + -0.3533 * u, cx + -0.9783 * u, cy + -0.3533 * u)
      p.close_path()
      p.move_to(cx + -0.5272 * u, cy + 0.0978 * u)
      p.line_to(cx + -0.375 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + 0.0978 * u, cx + -0.3533 * u, cy + 0.088 * u, cx + -0.3533 * u, cy + 0.0761 * u)
      p.line_to(cx + -0.3533 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + -0.088 * u, cx + -0.363 * u, cy + -0.0978 * u, cx + -0.375 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.5272 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + -0.0978 * u, cx + -0.5489 * u, cy + -0.088 * u, cx + -0.5489 * u, cy + -0.0761 * u)
      p.line_to(cx + -0.5489 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + 0.088 * u, cx + -0.5391 * u, cy + 0.0978 * u, cx + -0.5272 * u, cy + 0.0978 * u)
      p.close_path()
      p.move_to(cx + -0.5272 * u, cy + -0.8043 * u)
      p.line_to(cx + -0.375 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + -0.8043 * u, cx + -0.3533 * u, cy + -0.8141 * u, cx + -0.3533 * u, cy + -0.8261 * u)
      p.line_to(cx + -0.3533 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + -0.9902 * u, cx + -0.363 * u, cy + -1 * u, cx + -0.375 * u, cy + -1 * u)
      p.line_to(cx + -0.5272 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + -1 * u, cx + -0.5489 * u, cy + -0.9902 * u, cx + -0.5489 * u, cy + -0.9783 * u)
      p.line_to(cx + -0.5489 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + -0.8141 * u, cx + -0.5391 * u, cy + -0.8043 * u, cx + -0.5272 * u, cy + -0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.375 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.5272 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + -0.8043 * u, cx + 0.5489 * u, cy + -0.8141 * u, cx + 0.5489 * u, cy + -0.8261 * u)
      p.line_to(cx + 0.5489 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + -0.9902 * u, cx + 0.5391 * u, cy + -1 * u, cx + 0.5272 * u, cy + -1 * u)
      p.line_to(cx + 0.375 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + -1 * u, cx + 0.3533 * u, cy + -0.9902 * u, cx + 0.3533 * u, cy + -0.9783 * u)
      p.line_to(cx + 0.3533 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + -0.8141 * u, cx + 0.363 * u, cy + -0.8043 * u, cx + 0.375 * u, cy + -0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.375 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.5272 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + 0.0978 * u, cx + 0.5489 * u, cy + 0.088 * u, cx + 0.5489 * u, cy + 0.0761 * u)
      p.line_to(cx + 0.5489 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + -0.088 * u, cx + 0.5391 * u, cy + -0.0978 * u, cx + 0.5272 * u, cy + -0.0978 * u)
      p.line_to(cx + 0.375 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + -0.0978 * u, cx + 0.3533 * u, cy + -0.088 * u, cx + 0.3533 * u, cy + -0.0761 * u)
      p.line_to(cx + 0.3533 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + 0.088 * u, cx + 0.363 * u, cy + 0.0978 * u, cx + 0.375 * u, cy + 0.0978 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -0.0978 * u)
      p.line_to(cx + 0.8261 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -0.0978 * u, cx + 0.8043 * u, cy + -0.088 * u, cx + 0.8043 * u, cy + -0.0761 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.088 * u, cx + 0.8141 * u, cy + 0.0978 * u, cx + 0.8261 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.9783 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 0.0978 * u, cx + 1 * u, cy + 0.088 * u, cx + 1 * u, cy + 0.0761 * u)
      p.line_to(cx + 1 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.088 * u, cx + 0.9902 * u, cy + -0.0978 * u, cx + 0.9783 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + -0.0761 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.0761 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 0.0978 * u, cx + 0.0978 * u, cy + 0.088 * u, cx + 0.0978 * u, cy + 0.0761 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.088 * u, cx + 0.088 * u, cy + -0.0978 * u, cx + 0.0761 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.0761 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -0.0978 * u, cx + -0.0978 * u, cy + -0.088 * u, cx + -0.0978 * u, cy + -0.0761 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.088 * u, cx + -0.088 * u, cy + 0.0978 * u, cx + -0.0761 * u, cy + 0.0978 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -1 * u)
      p.line_to(cx + 0.8261 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -1 * u, cx + 0.8043 * u, cy + -0.9902 * u, cx + 0.8043 * u, cy + -0.9783 * u)
      p.line_to(cx + 0.8043 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + -0.8141 * u, cx + 0.8141 * u, cy + -0.8043 * u, cx + 0.8261 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.9783 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + -0.8043 * u, cx + 1 * u, cy + -0.8141 * u, cx + 1 * u, cy + -0.8261 * u)
      p.line_to(cx + 1 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.9902 * u, cx + 0.9902 * u, cy + -1 * u, cx + 0.9783 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.0761 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.0761 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + -0.8043 * u, cx + 0.0978 * u, cy + -0.8141 * u, cx + 0.0978 * u, cy + -0.8261 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.9902 * u, cx + 0.088 * u, cy + -1 * u, cx + 0.0761 * u, cy + -1 * u)
      p.line_to(cx + -0.0761 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -1 * u, cx + -0.0978 * u, cy + -0.9902 * u, cx + -0.0978 * u, cy + -0.9783 * u)
      p.line_to(cx + -0.0978 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + -0.8141 * u, cx + -0.088 * u, cy + -0.8043 * u, cx + -0.0761 * u, cy + -0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + 0.3533 * u)
      p.line_to(cx + 0.8261 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + 0.3533 * u, cx + 0.8043 * u, cy + 0.363 * u, cx + 0.8043 * u, cy + 0.375 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.5391 * u, cx + 0.8141 * u, cy + 0.5489 * u, cx + 0.8261 * u, cy + 0.5489 * u)
      p.line_to(cx + 0.9783 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 0.5489 * u, cx + 1 * u, cy + 0.5391 * u, cx + 1 * u, cy + 0.5272 * u)
      p.line_to(cx + 1 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.363 * u, cx + 0.9902 * u, cy + 0.3533 * u, cx + 0.9783 * u, cy + 0.3533 * u)
      p.close_path()
      p.move_to(cx + -0.0761 * u, cy + 0.5489 * u)
      p.line_to(cx + 0.0761 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 0.5489 * u, cx + 0.0978 * u, cy + 0.5391 * u, cx + 0.0978 * u, cy + 0.5272 * u)
      p.line_to(cx + 0.0978 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + 0.363 * u, cx + 0.088 * u, cy + 0.3533 * u, cx + 0.0761 * u, cy + 0.3533 * u)
      p.line_to(cx + -0.0761 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + 0.3533 * u, cx + -0.0978 * u, cy + 0.363 * u, cx + -0.0978 * u, cy + 0.375 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.5391 * u, cx + -0.088 * u, cy + 0.5489 * u, cx + -0.0761 * u, cy + 0.5489 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -0.5489 * u)
      p.line_to(cx + 0.8261 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -0.5489 * u, cx + 0.8043 * u, cy + -0.5391 * u, cx + 0.8043 * u, cy + -0.5272 * u)
      p.line_to(cx + 0.8043 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + -0.363 * u, cx + 0.8141 * u, cy + -0.3533 * u, cx + 0.8261 * u, cy + -0.3533 * u)
      p.line_to(cx + 0.9783 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + -0.3533 * u, cx + 1 * u, cy + -0.363 * u, cx + 1 * u, cy + -0.375 * u)
      p.line_to(cx + 1 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.5391 * u, cx + 0.9902 * u, cy + -0.5489 * u, cx + 0.9783 * u, cy + -0.5489 * u)
      p.close_path()
      p.move_to(cx + -0.0761 * u, cy + -0.3533 * u)
      p.line_to(cx + 0.0761 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + -0.3533 * u, cx + 0.0978 * u, cy + -0.363 * u, cx + 0.0978 * u, cy + -0.375 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.5391 * u, cx + 0.088 * u, cy + -0.5489 * u, cx + 0.0761 * u, cy + -0.5489 * u)
      p.line_to(cx + -0.0761 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -0.5489 * u, cx + -0.0978 * u, cy + -0.5391 * u, cx + -0.0978 * u, cy + -0.5272 * u)
      p.line_to(cx + -0.0978 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + -0.363 * u, cx + -0.088 * u, cy + -0.3533 * u, cx + -0.0761 * u, cy + -0.3533 * u)
      p.close_path()
      p.fill()
    }
    YhBorderLeft => { // border-left
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.8261 * u, cy + -1 * u)
      p.line_to(cx + -0.9783 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -1 * u, cx + -1 * u, cy + -0.9902 * u, cx + -1 * u, cy + -0.9783 * u)
      p.line_to(cx + -1 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9902 * u, cx + -0.9902 * u, cy + 1 * u, cx + -0.9783 * u, cy + 1 * u)
      p.line_to(cx + -0.8261 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 1 * u, cx + -0.8043 * u, cy + 0.9902 * u, cx + -0.8043 * u, cy + 0.9783 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.9902 * u, cx + -0.8141 * u, cy + -1 * u, cx + -0.8261 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.375 * u, cy + -1 * u)
      p.line_to(cx + -0.5272 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + -1 * u, cx + -0.5489 * u, cy + -0.9902 * u, cx + -0.5489 * u, cy + -0.9783 * u)
      p.line_to(cx + -0.5489 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + -0.8141 * u, cx + -0.5391 * u, cy + -0.8043 * u, cx + -0.5272 * u, cy + -0.8043 * u)
      p.line_to(cx + -0.375 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + -0.8043 * u, cx + -0.3533 * u, cy + -0.8141 * u, cx + -0.3533 * u, cy + -0.8261 * u)
      p.line_to(cx + -0.3533 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + -0.9902 * u, cx + -0.363 * u, cy + -1 * u, cx + -0.375 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -1 * u)
      p.line_to(cx + 0.8261 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -1 * u, cx + 0.8043 * u, cy + -0.9902 * u, cx + 0.8043 * u, cy + -0.9783 * u)
      p.line_to(cx + 0.8043 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + -0.8141 * u, cx + 0.8141 * u, cy + -0.8043 * u, cx + 0.8261 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.9783 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + -0.8043 * u, cx + 1 * u, cy + -0.8141 * u, cx + 1 * u, cy + -0.8261 * u)
      p.line_to(cx + 1 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.9902 * u, cx + 0.9902 * u, cy + -1 * u, cx + 0.9783 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + -1 * u)
      p.line_to(cx + -0.0761 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -1 * u, cx + -0.0978 * u, cy + -0.9902 * u, cx + -0.0978 * u, cy + -0.9783 * u)
      p.line_to(cx + -0.0978 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + -0.8141 * u, cx + -0.088 * u, cy + -0.8043 * u, cx + -0.0761 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.0761 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + -0.8043 * u, cx + 0.0978 * u, cy + -0.8141 * u, cx + 0.0978 * u, cy + -0.8261 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.9902 * u, cx + 0.088 * u, cy + -1 * u, cx + 0.0761 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.5272 * u, cy + -1 * u)
      p.line_to(cx + 0.375 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + -1 * u, cx + 0.3533 * u, cy + -0.9902 * u, cx + 0.3533 * u, cy + -0.9783 * u)
      p.line_to(cx + 0.3533 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + -0.8141 * u, cx + 0.363 * u, cy + -0.8043 * u, cx + 0.375 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.5272 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + -0.8043 * u, cx + 0.5489 * u, cy + -0.8141 * u, cx + 0.5489 * u, cy + -0.8261 * u)
      p.line_to(cx + 0.5489 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + -0.9902 * u, cx + 0.5391 * u, cy + -1 * u, cx + 0.5272 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + -0.5489 * u)
      p.line_to(cx + -0.0761 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -0.5489 * u, cx + -0.0978 * u, cy + -0.5391 * u, cx + -0.0978 * u, cy + -0.5272 * u)
      p.line_to(cx + -0.0978 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + -0.363 * u, cx + -0.088 * u, cy + -0.3533 * u, cx + -0.0761 * u, cy + -0.3533 * u)
      p.line_to(cx + 0.0761 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + -0.3533 * u, cx + 0.0978 * u, cy + -0.363 * u, cx + 0.0978 * u, cy + -0.375 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.5391 * u, cx + 0.088 * u, cy + -0.5489 * u, cx + 0.0761 * u, cy + -0.5489 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -0.5489 * u)
      p.line_to(cx + 0.8261 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -0.5489 * u, cx + 0.8043 * u, cy + -0.5391 * u, cx + 0.8043 * u, cy + -0.5272 * u)
      p.line_to(cx + 0.8043 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + -0.363 * u, cx + 0.8141 * u, cy + -0.3533 * u, cx + 0.8261 * u, cy + -0.3533 * u)
      p.line_to(cx + 0.9783 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + -0.3533 * u, cx + 1 * u, cy + -0.363 * u, cx + 1 * u, cy + -0.375 * u)
      p.line_to(cx + 1 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.5391 * u, cx + 0.9902 * u, cy + -0.5489 * u, cx + 0.9783 * u, cy + -0.5489 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + 0.3533 * u)
      p.line_to(cx + 0.8261 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + 0.3533 * u, cx + 0.8043 * u, cy + 0.363 * u, cx + 0.8043 * u, cy + 0.375 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.5391 * u, cx + 0.8141 * u, cy + 0.5489 * u, cx + 0.8261 * u, cy + 0.5489 * u)
      p.line_to(cx + 0.9783 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 0.5489 * u, cx + 1 * u, cy + 0.5391 * u, cx + 1 * u, cy + 0.5272 * u)
      p.line_to(cx + 1 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.363 * u, cx + 0.9902 * u, cy + 0.3533 * u, cx + 0.9783 * u, cy + 0.3533 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + 0.3533 * u)
      p.line_to(cx + -0.0761 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + 0.3533 * u, cx + -0.0978 * u, cy + 0.363 * u, cx + -0.0978 * u, cy + 0.375 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.5391 * u, cx + -0.088 * u, cy + 0.5489 * u, cx + -0.0761 * u, cy + 0.5489 * u)
      p.line_to(cx + 0.0761 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 0.5489 * u, cx + 0.0978 * u, cy + 0.5391 * u, cx + 0.0978 * u, cy + 0.5272 * u)
      p.line_to(cx + 0.0978 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + 0.363 * u, cx + 0.088 * u, cy + 0.3533 * u, cx + 0.0761 * u, cy + 0.3533 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.0761 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + 0.8043 * u, cx + -0.0978 * u, cy + 0.8141 * u, cx + -0.0978 * u, cy + 0.8261 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.9902 * u, cx + -0.088 * u, cy + 1 * u, cx + -0.0761 * u, cy + 1 * u)
      p.line_to(cx + 0.0761 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 1 * u, cx + 0.0978 * u, cy + 0.9902 * u, cx + 0.0978 * u, cy + 0.9783 * u)
      p.line_to(cx + 0.0978 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + 0.8141 * u, cx + 0.088 * u, cy + 0.8043 * u, cx + 0.0761 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.0761 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -0.0978 * u, cx + -0.0978 * u, cy + -0.088 * u, cx + -0.0978 * u, cy + -0.0761 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.088 * u, cx + -0.088 * u, cy + 0.0978 * u, cx + -0.0761 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.0761 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 0.0978 * u, cx + 0.0978 * u, cy + 0.088 * u, cx + 0.0978 * u, cy + 0.0761 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.088 * u, cx + 0.088 * u, cy + -0.0978 * u, cx + 0.0761 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + 0.8043 * u)
      p.line_to(cx + 0.8261 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + 0.8043 * u, cx + 0.8043 * u, cy + 0.8141 * u, cx + 0.8043 * u, cy + 0.8261 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.9902 * u, cx + 0.8141 * u, cy + 1 * u, cx + 0.8261 * u, cy + 1 * u)
      p.line_to(cx + 0.9783 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 1 * u, cx + 1 * u, cy + 0.9902 * u, cx + 1 * u, cy + 0.9783 * u)
      p.line_to(cx + 1 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.8141 * u, cx + 0.9902 * u, cy + 0.8043 * u, cx + 0.9783 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -0.0978 * u)
      p.line_to(cx + 0.8261 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -0.0978 * u, cx + 0.8043 * u, cy + -0.088 * u, cx + 0.8043 * u, cy + -0.0761 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.088 * u, cx + 0.8141 * u, cy + 0.0978 * u, cx + 0.8261 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.9783 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 0.0978 * u, cx + 1 * u, cy + 0.088 * u, cx + 1 * u, cy + 0.0761 * u)
      p.line_to(cx + 1 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.088 * u, cx + 0.9902 * u, cy + -0.0978 * u, cx + 0.9783 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + -0.375 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.5272 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + 0.8043 * u, cx + -0.5489 * u, cy + 0.8141 * u, cx + -0.5489 * u, cy + 0.8261 * u)
      p.line_to(cx + -0.5489 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + 0.9902 * u, cx + -0.5391 * u, cy + 1 * u, cx + -0.5272 * u, cy + 1 * u)
      p.line_to(cx + -0.375 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + 1 * u, cx + -0.3533 * u, cy + 0.9902 * u, cx + -0.3533 * u, cy + 0.9783 * u)
      p.line_to(cx + -0.3533 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + 0.8141 * u, cx + -0.363 * u, cy + 0.8043 * u, cx + -0.375 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.375 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.5272 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + -0.0978 * u, cx + -0.5489 * u, cy + -0.088 * u, cx + -0.5489 * u, cy + -0.0761 * u)
      p.line_to(cx + -0.5489 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + 0.088 * u, cx + -0.5391 * u, cy + 0.0978 * u, cx + -0.5272 * u, cy + 0.0978 * u)
      p.line_to(cx + -0.375 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + 0.0978 * u, cx + -0.3533 * u, cy + 0.088 * u, cx + -0.3533 * u, cy + 0.0761 * u)
      p.line_to(cx + -0.3533 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + -0.088 * u, cx + -0.363 * u, cy + -0.0978 * u, cx + -0.375 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + 0.5272 * u, cy + 0.8043 * u)
      p.line_to(cx + 0.375 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + 0.8043 * u, cx + 0.3533 * u, cy + 0.8141 * u, cx + 0.3533 * u, cy + 0.8261 * u)
      p.line_to(cx + 0.3533 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + 0.9902 * u, cx + 0.363 * u, cy + 1 * u, cx + 0.375 * u, cy + 1 * u)
      p.line_to(cx + 0.5272 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + 1 * u, cx + 0.5489 * u, cy + 0.9902 * u, cx + 0.5489 * u, cy + 0.9783 * u)
      p.line_to(cx + 0.5489 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + 0.8141 * u, cx + 0.5391 * u, cy + 0.8043 * u, cx + 0.5272 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.5272 * u, cy + -0.0978 * u)
      p.line_to(cx + 0.375 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + -0.0978 * u, cx + 0.3533 * u, cy + -0.088 * u, cx + 0.3533 * u, cy + -0.0761 * u)
      p.line_to(cx + 0.3533 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + 0.088 * u, cx + 0.363 * u, cy + 0.0978 * u, cx + 0.375 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.5272 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + 0.0978 * u, cx + 0.5489 * u, cy + 0.088 * u, cx + 0.5489 * u, cy + 0.0761 * u)
      p.line_to(cx + 0.5489 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + -0.088 * u, cx + 0.5391 * u, cy + -0.0978 * u, cx + 0.5272 * u, cy + -0.0978 * u)
      p.close_path()
      p.fill()
    }
    YhBorderRight => { // border-right
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9783 * u, cy + -1 * u)
      p.line_to(cx + 0.8261 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -1 * u, cx + 0.8043 * u, cy + -0.9902 * u, cx + 0.8043 * u, cy + -0.9783 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.9902 * u, cx + 0.8141 * u, cy + 1 * u, cx + 0.8261 * u, cy + 1 * u)
      p.line_to(cx + 0.9783 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 1 * u, cx + 1 * u, cy + 0.9902 * u, cx + 1 * u, cy + 0.9783 * u)
      p.line_to(cx + 1 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.9902 * u, cx + 0.9902 * u, cy + -1 * u, cx + 0.9783 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.5272 * u, cy + -1 * u)
      p.line_to(cx + 0.375 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + -1 * u, cx + 0.3533 * u, cy + -0.9902 * u, cx + 0.3533 * u, cy + -0.9783 * u)
      p.line_to(cx + 0.3533 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + -0.8141 * u, cx + 0.363 * u, cy + -0.8043 * u, cx + 0.375 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.5272 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + -0.8043 * u, cx + 0.5489 * u, cy + -0.8141 * u, cx + 0.5489 * u, cy + -0.8261 * u)
      p.line_to(cx + 0.5489 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + -0.9902 * u, cx + 0.5391 * u, cy + -1 * u, cx + 0.5272 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + -1 * u)
      p.line_to(cx + -0.9783 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -1 * u, cx + -1 * u, cy + -0.9902 * u, cx + -1 * u, cy + -0.9783 * u)
      p.line_to(cx + -1 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.8141 * u, cx + -0.9902 * u, cy + -0.8043 * u, cx + -0.9783 * u, cy + -0.8043 * u)
      p.line_to(cx + -0.8261 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + -0.8043 * u, cx + -0.8043 * u, cy + -0.8141 * u, cx + -0.8043 * u, cy + -0.8261 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.9902 * u, cx + -0.8141 * u, cy + -1 * u, cx + -0.8261 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + -1 * u)
      p.line_to(cx + -0.0761 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -1 * u, cx + -0.0978 * u, cy + -0.9902 * u, cx + -0.0978 * u, cy + -0.9783 * u)
      p.line_to(cx + -0.0978 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + -0.8141 * u, cx + -0.088 * u, cy + -0.8043 * u, cx + -0.0761 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.0761 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + -0.8043 * u, cx + 0.0978 * u, cy + -0.8141 * u, cx + 0.0978 * u, cy + -0.8261 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.9902 * u, cx + 0.088 * u, cy + -1 * u, cx + 0.0761 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.375 * u, cy + -1 * u)
      p.line_to(cx + -0.5272 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + -1 * u, cx + -0.5489 * u, cy + -0.9902 * u, cx + -0.5489 * u, cy + -0.9783 * u)
      p.line_to(cx + -0.5489 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + -0.8141 * u, cx + -0.5391 * u, cy + -0.8043 * u, cx + -0.5272 * u, cy + -0.8043 * u)
      p.line_to(cx + -0.375 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + -0.8043 * u, cx + -0.3533 * u, cy + -0.8141 * u, cx + -0.3533 * u, cy + -0.8261 * u)
      p.line_to(cx + -0.3533 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + -0.9902 * u, cx + -0.363 * u, cy + -1 * u, cx + -0.375 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + -0.5489 * u)
      p.line_to(cx + -0.0761 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -0.5489 * u, cx + -0.0978 * u, cy + -0.5391 * u, cx + -0.0978 * u, cy + -0.5272 * u)
      p.line_to(cx + -0.0978 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + -0.363 * u, cx + -0.088 * u, cy + -0.3533 * u, cx + -0.0761 * u, cy + -0.3533 * u)
      p.line_to(cx + 0.0761 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + -0.3533 * u, cx + 0.0978 * u, cy + -0.363 * u, cx + 0.0978 * u, cy + -0.375 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.5391 * u, cx + 0.088 * u, cy + -0.5489 * u, cx + 0.0761 * u, cy + -0.5489 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + -0.5489 * u)
      p.line_to(cx + -0.9783 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -0.5489 * u, cx + -1 * u, cy + -0.5391 * u, cx + -1 * u, cy + -0.5272 * u)
      p.line_to(cx + -1 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.363 * u, cx + -0.9902 * u, cy + -0.3533 * u, cx + -0.9783 * u, cy + -0.3533 * u)
      p.line_to(cx + -0.8261 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + -0.3533 * u, cx + -0.8043 * u, cy + -0.363 * u, cx + -0.8043 * u, cy + -0.375 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.5391 * u, cx + -0.8141 * u, cy + -0.5489 * u, cx + -0.8261 * u, cy + -0.5489 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + 0.3533 * u)
      p.line_to(cx + -0.9783 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + 0.3533 * u, cx + -1 * u, cy + 0.363 * u, cx + -1 * u, cy + 0.375 * u)
      p.line_to(cx + -1 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.5391 * u, cx + -0.9902 * u, cy + 0.5489 * u, cx + -0.9783 * u, cy + 0.5489 * u)
      p.line_to(cx + -0.8261 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 0.5489 * u, cx + -0.8043 * u, cy + 0.5391 * u, cx + -0.8043 * u, cy + 0.5272 * u)
      p.line_to(cx + -0.8043 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + 0.363 * u, cx + -0.8141 * u, cy + 0.3533 * u, cx + -0.8261 * u, cy + 0.3533 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + 0.3533 * u)
      p.line_to(cx + -0.0761 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + 0.3533 * u, cx + -0.0978 * u, cy + 0.363 * u, cx + -0.0978 * u, cy + 0.375 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.5391 * u, cx + -0.088 * u, cy + 0.5489 * u, cx + -0.0761 * u, cy + 0.5489 * u)
      p.line_to(cx + 0.0761 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 0.5489 * u, cx + 0.0978 * u, cy + 0.5391 * u, cx + 0.0978 * u, cy + 0.5272 * u)
      p.line_to(cx + 0.0978 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + 0.363 * u, cx + 0.088 * u, cy + 0.3533 * u, cx + 0.0761 * u, cy + 0.3533 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.0761 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + 0.8043 * u, cx + -0.0978 * u, cy + 0.8141 * u, cx + -0.0978 * u, cy + 0.8261 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.9902 * u, cx + -0.088 * u, cy + 1 * u, cx + -0.0761 * u, cy + 1 * u)
      p.line_to(cx + 0.0761 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 1 * u, cx + 0.0978 * u, cy + 0.9902 * u, cx + 0.0978 * u, cy + 0.9783 * u)
      p.line_to(cx + 0.0978 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + 0.8141 * u, cx + 0.088 * u, cy + 0.8043 * u, cx + 0.0761 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.0761 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -0.0978 * u, cx + -0.0978 * u, cy + -0.088 * u, cx + -0.0978 * u, cy + -0.0761 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.088 * u, cx + -0.088 * u, cy + 0.0978 * u, cx + -0.0761 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.0761 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 0.0978 * u, cx + 0.0978 * u, cy + 0.088 * u, cx + 0.0978 * u, cy + 0.0761 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.088 * u, cx + 0.088 * u, cy + -0.0978 * u, cx + 0.0761 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.9783 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + 0.8043 * u, cx + -1 * u, cy + 0.8141 * u, cx + -1 * u, cy + 0.8261 * u)
      p.line_to(cx + -1 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9902 * u, cx + -0.9902 * u, cy + 1 * u, cx + -0.9783 * u, cy + 1 * u)
      p.line_to(cx + -0.8261 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 1 * u, cx + -0.8043 * u, cy + 0.9902 * u, cx + -0.8043 * u, cy + 0.9783 * u)
      p.line_to(cx + -0.8043 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + 0.8141 * u, cx + -0.8141 * u, cy + 0.8043 * u, cx + -0.8261 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.9783 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -0.0978 * u, cx + -1 * u, cy + -0.088 * u, cx + -1 * u, cy + -0.0761 * u)
      p.line_to(cx + -1 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.088 * u, cx + -0.9902 * u, cy + 0.0978 * u, cx + -0.9783 * u, cy + 0.0978 * u)
      p.line_to(cx + -0.8261 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 0.0978 * u, cx + -0.8043 * u, cy + 0.088 * u, cx + -0.8043 * u, cy + 0.0761 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.088 * u, cx + -0.8141 * u, cy + -0.0978 * u, cx + -0.8261 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + 0.5272 * u, cy + 0.8043 * u)
      p.line_to(cx + 0.375 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + 0.8043 * u, cx + 0.3533 * u, cy + 0.8141 * u, cx + 0.3533 * u, cy + 0.8261 * u)
      p.line_to(cx + 0.3533 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + 0.9902 * u, cx + 0.363 * u, cy + 1 * u, cx + 0.375 * u, cy + 1 * u)
      p.line_to(cx + 0.5272 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + 1 * u, cx + 0.5489 * u, cy + 0.9902 * u, cx + 0.5489 * u, cy + 0.9783 * u)
      p.line_to(cx + 0.5489 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + 0.8141 * u, cx + 0.5391 * u, cy + 0.8043 * u, cx + 0.5272 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.5272 * u, cy + -0.0978 * u)
      p.line_to(cx + 0.375 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + -0.0978 * u, cx + 0.3533 * u, cy + -0.088 * u, cx + 0.3533 * u, cy + -0.0761 * u)
      p.line_to(cx + 0.3533 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + 0.088 * u, cx + 0.363 * u, cy + 0.0978 * u, cx + 0.375 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.5272 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + 0.0978 * u, cx + 0.5489 * u, cy + 0.088 * u, cx + 0.5489 * u, cy + 0.0761 * u)
      p.line_to(cx + 0.5489 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + -0.088 * u, cx + 0.5391 * u, cy + -0.0978 * u, cx + 0.5272 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + -0.375 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.5272 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + 0.8043 * u, cx + -0.5489 * u, cy + 0.8141 * u, cx + -0.5489 * u, cy + 0.8261 * u)
      p.line_to(cx + -0.5489 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + 0.9902 * u, cx + -0.5391 * u, cy + 1 * u, cx + -0.5272 * u, cy + 1 * u)
      p.line_to(cx + -0.375 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + 1 * u, cx + -0.3533 * u, cy + 0.9902 * u, cx + -0.3533 * u, cy + 0.9783 * u)
      p.line_to(cx + -0.3533 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + 0.8141 * u, cx + -0.363 * u, cy + 0.8043 * u, cx + -0.375 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.375 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.5272 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + -0.0978 * u, cx + -0.5489 * u, cy + -0.088 * u, cx + -0.5489 * u, cy + -0.0761 * u)
      p.line_to(cx + -0.5489 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + 0.088 * u, cx + -0.5391 * u, cy + 0.0978 * u, cx + -0.5272 * u, cy + 0.0978 * u)
      p.line_to(cx + -0.375 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + 0.0978 * u, cx + -0.3533 * u, cy + 0.088 * u, cx + -0.3533 * u, cy + 0.0761 * u)
      p.line_to(cx + -0.3533 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + -0.088 * u, cx + -0.363 * u, cy + -0.0978 * u, cx + -0.375 * u, cy + -0.0978 * u)
      p.close_path()
      p.fill()
    }
    YhBorderInner => { // border-inner
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9783 * u, cy + -0.0978 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.0978 * u)
      p.line_to(cx + 0.0978 * u, cy + -1 * u)
      p.line_to(cx + -0.0978 * u, cy + -1 * u)
      p.line_to(cx + -0.0978 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.9783 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -0.0978 * u, cx + -1 * u, cy + -0.088 * u, cx + -1 * u, cy + -0.0761 * u)
      p.line_to(cx + -1 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.088 * u, cx + -0.9902 * u, cy + 0.0978 * u, cx + -0.9783 * u, cy + 0.0978 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.0978 * u)
      p.line_to(cx + -0.0978 * u, cy + 1 * u)
      p.line_to(cx + 0.0978 * u, cy + 1 * u)
      p.line_to(cx + 0.0978 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.9783 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 0.0978 * u, cx + 1 * u, cy + 0.088 * u, cx + 1 * u, cy + 0.0761 * u)
      p.line_to(cx + 1 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.088 * u, cx + 0.9902 * u, cy + -0.0978 * u, cx + 0.9783 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -0.5489 * u)
      p.line_to(cx + 0.8261 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -0.5489 * u, cx + 0.8043 * u, cy + -0.5391 * u, cx + 0.8043 * u, cy + -0.5272 * u)
      p.line_to(cx + 0.8043 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + -0.363 * u, cx + 0.8141 * u, cy + -0.3533 * u, cx + 0.8261 * u, cy + -0.3533 * u)
      p.line_to(cx + 0.9783 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + -0.3533 * u, cx + 1 * u, cy + -0.363 * u, cx + 1 * u, cy + -0.375 * u)
      p.line_to(cx + 1 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.5391 * u, cx + 0.9902 * u, cy + -0.5489 * u, cx + 0.9783 * u, cy + -0.5489 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + 0.8043 * u)
      p.line_to(cx + 0.8261 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + 0.8043 * u, cx + 0.8043 * u, cy + 0.8141 * u, cx + 0.8043 * u, cy + 0.8261 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.9902 * u, cx + 0.8141 * u, cy + 1 * u, cx + 0.8261 * u, cy + 1 * u)
      p.line_to(cx + 0.9783 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 1 * u, cx + 1 * u, cy + 0.9902 * u, cx + 1 * u, cy + 0.9783 * u)
      p.line_to(cx + 1 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.8141 * u, cx + 0.9902 * u, cy + 0.8043 * u, cx + 0.9783 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -1 * u)
      p.line_to(cx + 0.8261 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -1 * u, cx + 0.8043 * u, cy + -0.9902 * u, cx + 0.8043 * u, cy + -0.9783 * u)
      p.line_to(cx + 0.8043 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + -0.8141 * u, cx + 0.8141 * u, cy + -0.8043 * u, cx + 0.8261 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.9783 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + -0.8043 * u, cx + 1 * u, cy + -0.8141 * u, cx + 1 * u, cy + -0.8261 * u)
      p.line_to(cx + 1 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.9902 * u, cx + 0.9902 * u, cy + -1 * u, cx + 0.9783 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + 0.3533 * u)
      p.line_to(cx + 0.8261 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + 0.3533 * u, cx + 0.8043 * u, cy + 0.363 * u, cx + 0.8043 * u, cy + 0.375 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.5391 * u, cx + 0.8141 * u, cy + 0.5489 * u, cx + 0.8261 * u, cy + 0.5489 * u)
      p.line_to(cx + 0.9783 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 0.5489 * u, cx + 1 * u, cy + 0.5391 * u, cx + 1 * u, cy + 0.5272 * u)
      p.line_to(cx + 1 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.363 * u, cx + 0.9902 * u, cy + 0.3533 * u, cx + 0.9783 * u, cy + 0.3533 * u)
      p.close_path()
      p.move_to(cx + 0.375 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.5272 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + -0.8043 * u, cx + 0.5489 * u, cy + -0.8141 * u, cx + 0.5489 * u, cy + -0.8261 * u)
      p.line_to(cx + 0.5489 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + -0.9902 * u, cx + 0.5391 * u, cy + -1 * u, cx + 0.5272 * u, cy + -1 * u)
      p.line_to(cx + 0.375 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + -1 * u, cx + 0.3533 * u, cy + -0.9902 * u, cx + 0.3533 * u, cy + -0.9783 * u)
      p.line_to(cx + 0.3533 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + -0.8141 * u, cx + 0.363 * u, cy + -0.8043 * u, cx + 0.375 * u, cy + -0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.5272 * u, cy + 0.8043 * u)
      p.line_to(cx + 0.375 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + 0.8043 * u, cx + 0.3533 * u, cy + 0.8141 * u, cx + 0.3533 * u, cy + 0.8261 * u)
      p.line_to(cx + 0.3533 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + 0.9902 * u, cx + 0.363 * u, cy + 1 * u, cx + 0.375 * u, cy + 1 * u)
      p.line_to(cx + 0.5272 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + 1 * u, cx + 0.5489 * u, cy + 0.9902 * u, cx + 0.5489 * u, cy + 0.9783 * u)
      p.line_to(cx + 0.5489 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + 0.8141 * u, cx + 0.5391 * u, cy + 0.8043 * u, cx + 0.5272 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.375 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.5272 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + 0.8043 * u, cx + -0.5489 * u, cy + 0.8141 * u, cx + -0.5489 * u, cy + 0.8261 * u)
      p.line_to(cx + -0.5489 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + 0.9902 * u, cx + -0.5391 * u, cy + 1 * u, cx + -0.5272 * u, cy + 1 * u)
      p.line_to(cx + -0.375 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + 1 * u, cx + -0.3533 * u, cy + 0.9902 * u, cx + -0.3533 * u, cy + 0.9783 * u)
      p.line_to(cx + -0.3533 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + 0.8141 * u, cx + -0.363 * u, cy + 0.8043 * u, cx + -0.375 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.5272 * u, cy + -0.8043 * u)
      p.line_to(cx + -0.375 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + -0.8043 * u, cx + -0.3533 * u, cy + -0.8141 * u, cx + -0.3533 * u, cy + -0.8261 * u)
      p.line_to(cx + -0.3533 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + -0.9902 * u, cx + -0.363 * u, cy + -1 * u, cx + -0.375 * u, cy + -1 * u)
      p.line_to(cx + -0.5272 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + -1 * u, cx + -0.5489 * u, cy + -0.9902 * u, cx + -0.5489 * u, cy + -0.9783 * u)
      p.line_to(cx + -0.5489 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + -0.8141 * u, cx + -0.5391 * u, cy + -0.8043 * u, cx + -0.5272 * u, cy + -0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.9783 * u, cy + -0.8043 * u)
      p.line_to(cx + -0.8261 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + -0.8043 * u, cx + -0.8043 * u, cy + -0.8141 * u, cx + -0.8043 * u, cy + -0.8261 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.9902 * u, cx + -0.8141 * u, cy + -1 * u, cx + -0.8261 * u, cy + -1 * u)
      p.line_to(cx + -0.9783 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -1 * u, cx + -1 * u, cy + -0.9902 * u, cx + -1 * u, cy + -0.9783 * u)
      p.line_to(cx + -1 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.8141 * u, cx + -0.9902 * u, cy + -0.8043 * u, cx + -0.9783 * u, cy + -0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.9783 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + 0.8043 * u, cx + -1 * u, cy + 0.8141 * u, cx + -1 * u, cy + 0.8261 * u)
      p.line_to(cx + -1 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9902 * u, cx + -0.9902 * u, cy + 1 * u, cx + -0.9783 * u, cy + 1 * u)
      p.line_to(cx + -0.8261 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 1 * u, cx + -0.8043 * u, cy + 0.9902 * u, cx + -0.8043 * u, cy + 0.9783 * u)
      p.line_to(cx + -0.8043 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + 0.8141 * u, cx + -0.8141 * u, cy + 0.8043 * u, cx + -0.8261 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.9783 * u, cy + -0.3533 * u)
      p.line_to(cx + -0.8261 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + -0.3533 * u, cx + -0.8043 * u, cy + -0.363 * u, cx + -0.8043 * u, cy + -0.375 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.5391 * u, cx + -0.8141 * u, cy + -0.5489 * u, cx + -0.8261 * u, cy + -0.5489 * u)
      p.line_to(cx + -0.9783 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -0.5489 * u, cx + -1 * u, cy + -0.5391 * u, cx + -1 * u, cy + -0.5272 * u)
      p.line_to(cx + -1 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.363 * u, cx + -0.9902 * u, cy + -0.3533 * u, cx + -0.9783 * u, cy + -0.3533 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + 0.3533 * u)
      p.line_to(cx + -0.9783 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + 0.3533 * u, cx + -1 * u, cy + 0.363 * u, cx + -1 * u, cy + 0.375 * u)
      p.line_to(cx + -1 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.5391 * u, cx + -0.9902 * u, cy + 0.5489 * u, cx + -0.9783 * u, cy + 0.5489 * u)
      p.line_to(cx + -0.8261 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 0.5489 * u, cx + -0.8043 * u, cy + 0.5391 * u, cx + -0.8043 * u, cy + 0.5272 * u)
      p.line_to(cx + -0.8043 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + 0.363 * u, cx + -0.8141 * u, cy + 0.3533 * u, cx + -0.8261 * u, cy + 0.3533 * u)
      p.close_path()
      p.fill()
    }
    YhBorderVertical => { // border-verticle
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9783 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.9783 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -0.0978 * u, cx + -1 * u, cy + -0.088 * u, cx + -1 * u, cy + -0.0761 * u)
      p.line_to(cx + -1 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.088 * u, cx + -0.9902 * u, cy + 0.0978 * u, cx + -0.9783 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.9783 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 0.0978 * u, cx + 1 * u, cy + 0.088 * u, cx + 1 * u, cy + 0.0761 * u)
      p.line_to(cx + 1 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.088 * u, cx + 0.9902 * u, cy + -0.0978 * u, cx + 0.9783 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -0.5489 * u)
      p.line_to(cx + 0.8261 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -0.5489 * u, cx + 0.8043 * u, cy + -0.5391 * u, cx + 0.8043 * u, cy + -0.5272 * u)
      p.line_to(cx + 0.8043 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + -0.363 * u, cx + 0.8141 * u, cy + -0.3533 * u, cx + 0.8261 * u, cy + -0.3533 * u)
      p.line_to(cx + 0.9783 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + -0.3533 * u, cx + 1 * u, cy + -0.363 * u, cx + 1 * u, cy + -0.375 * u)
      p.line_to(cx + 1 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.5391 * u, cx + 0.9902 * u, cy + -0.5489 * u, cx + 0.9783 * u, cy + -0.5489 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + 0.8043 * u)
      p.line_to(cx + 0.8261 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + 0.8043 * u, cx + 0.8043 * u, cy + 0.8141 * u, cx + 0.8043 * u, cy + 0.8261 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.9902 * u, cx + 0.8141 * u, cy + 1 * u, cx + 0.8261 * u, cy + 1 * u)
      p.line_to(cx + 0.9783 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 1 * u, cx + 1 * u, cy + 0.9902 * u, cx + 1 * u, cy + 0.9783 * u)
      p.line_to(cx + 1 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.8141 * u, cx + 0.9902 * u, cy + 0.8043 * u, cx + 0.9783 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -1 * u)
      p.line_to(cx + 0.8261 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -1 * u, cx + 0.8043 * u, cy + -0.9902 * u, cx + 0.8043 * u, cy + -0.9783 * u)
      p.line_to(cx + 0.8043 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + -0.8141 * u, cx + 0.8141 * u, cy + -0.8043 * u, cx + 0.8261 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.9783 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + -0.8043 * u, cx + 1 * u, cy + -0.8141 * u, cx + 1 * u, cy + -0.8261 * u)
      p.line_to(cx + 1 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.9902 * u, cx + 0.9902 * u, cy + -1 * u, cx + 0.9783 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + 0.3533 * u)
      p.line_to(cx + 0.8261 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + 0.3533 * u, cx + 0.8043 * u, cy + 0.363 * u, cx + 0.8043 * u, cy + 0.375 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.5391 * u, cx + 0.8141 * u, cy + 0.5489 * u, cx + 0.8261 * u, cy + 0.5489 * u)
      p.line_to(cx + 0.9783 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 0.5489 * u, cx + 1 * u, cy + 0.5391 * u, cx + 1 * u, cy + 0.5272 * u)
      p.line_to(cx + 1 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.363 * u, cx + 0.9902 * u, cy + 0.3533 * u, cx + 0.9783 * u, cy + 0.3533 * u)
      p.close_path()
      p.move_to(cx + 0.375 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.5272 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + -0.8043 * u, cx + 0.5489 * u, cy + -0.8141 * u, cx + 0.5489 * u, cy + -0.8261 * u)
      p.line_to(cx + 0.5489 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + -0.9902 * u, cx + 0.5391 * u, cy + -1 * u, cx + 0.5272 * u, cy + -1 * u)
      p.line_to(cx + 0.375 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + -1 * u, cx + 0.3533 * u, cy + -0.9902 * u, cx + 0.3533 * u, cy + -0.9783 * u)
      p.line_to(cx + 0.3533 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + -0.8141 * u, cx + 0.363 * u, cy + -0.8043 * u, cx + 0.375 * u, cy + -0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.5272 * u, cy + 0.8043 * u)
      p.line_to(cx + 0.375 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + 0.8043 * u, cx + 0.3533 * u, cy + 0.8141 * u, cx + 0.3533 * u, cy + 0.8261 * u)
      p.line_to(cx + 0.3533 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + 0.9902 * u, cx + 0.363 * u, cy + 1 * u, cx + 0.375 * u, cy + 1 * u)
      p.line_to(cx + 0.5272 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + 1 * u, cx + 0.5489 * u, cy + 0.9902 * u, cx + 0.5489 * u, cy + 0.9783 * u)
      p.line_to(cx + 0.5489 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + 0.8141 * u, cx + 0.5391 * u, cy + 0.8043 * u, cx + 0.5272 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.375 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.5272 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + 0.8043 * u, cx + -0.5489 * u, cy + 0.8141 * u, cx + -0.5489 * u, cy + 0.8261 * u)
      p.line_to(cx + -0.5489 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + 0.9902 * u, cx + -0.5391 * u, cy + 1 * u, cx + -0.5272 * u, cy + 1 * u)
      p.line_to(cx + -0.375 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + 1 * u, cx + -0.3533 * u, cy + 0.9902 * u, cx + -0.3533 * u, cy + 0.9783 * u)
      p.line_to(cx + -0.3533 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + 0.8141 * u, cx + -0.363 * u, cy + 0.8043 * u, cx + -0.375 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.5272 * u, cy + -0.8043 * u)
      p.line_to(cx + -0.375 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + -0.8043 * u, cx + -0.3533 * u, cy + -0.8141 * u, cx + -0.3533 * u, cy + -0.8261 * u)
      p.line_to(cx + -0.3533 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + -0.9902 * u, cx + -0.363 * u, cy + -1 * u, cx + -0.375 * u, cy + -1 * u)
      p.line_to(cx + -0.5272 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + -1 * u, cx + -0.5489 * u, cy + -0.9902 * u, cx + -0.5489 * u, cy + -0.9783 * u)
      p.line_to(cx + -0.5489 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + -0.8141 * u, cx + -0.5391 * u, cy + -0.8043 * u, cx + -0.5272 * u, cy + -0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.9783 * u, cy + -0.8043 * u)
      p.line_to(cx + -0.8261 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + -0.8043 * u, cx + -0.8043 * u, cy + -0.8141 * u, cx + -0.8043 * u, cy + -0.8261 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.9902 * u, cx + -0.8141 * u, cy + -1 * u, cx + -0.8261 * u, cy + -1 * u)
      p.line_to(cx + -0.9783 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -1 * u, cx + -1 * u, cy + -0.9902 * u, cx + -1 * u, cy + -0.9783 * u)
      p.line_to(cx + -1 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.8141 * u, cx + -0.9902 * u, cy + -0.8043 * u, cx + -0.9783 * u, cy + -0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.0761 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.0761 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + -0.8043 * u, cx + 0.0978 * u, cy + -0.8141 * u, cx + 0.0978 * u, cy + -0.8261 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.9902 * u, cx + 0.088 * u, cy + -1 * u, cx + 0.0761 * u, cy + -1 * u)
      p.line_to(cx + -0.0761 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -1 * u, cx + -0.0978 * u, cy + -0.9902 * u, cx + -0.0978 * u, cy + -0.9783 * u)
      p.line_to(cx + -0.0978 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + -0.8141 * u, cx + -0.088 * u, cy + -0.8043 * u, cx + -0.0761 * u, cy + -0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.9783 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + 0.8043 * u, cx + -1 * u, cy + 0.8141 * u, cx + -1 * u, cy + 0.8261 * u)
      p.line_to(cx + -1 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9902 * u, cx + -0.9902 * u, cy + 1 * u, cx + -0.9783 * u, cy + 1 * u)
      p.line_to(cx + -0.8261 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 1 * u, cx + -0.8043 * u, cy + 0.9902 * u, cx + -0.8043 * u, cy + 0.9783 * u)
      p.line_to(cx + -0.8043 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + 0.8141 * u, cx + -0.8141 * u, cy + 0.8043 * u, cx + -0.8261 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.0761 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + 0.8043 * u, cx + -0.0978 * u, cy + 0.8141 * u, cx + -0.0978 * u, cy + 0.8261 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.9902 * u, cx + -0.088 * u, cy + 1 * u, cx + -0.0761 * u, cy + 1 * u)
      p.line_to(cx + 0.0761 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 1 * u, cx + 0.0978 * u, cy + 0.9902 * u, cx + 0.0978 * u, cy + 0.9783 * u)
      p.line_to(cx + 0.0978 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + 0.8141 * u, cx + 0.088 * u, cy + 0.8043 * u, cx + 0.0761 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.9783 * u, cy + -0.3533 * u)
      p.line_to(cx + -0.8261 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + -0.3533 * u, cx + -0.8043 * u, cy + -0.363 * u, cx + -0.8043 * u, cy + -0.375 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.5391 * u, cx + -0.8141 * u, cy + -0.5489 * u, cx + -0.8261 * u, cy + -0.5489 * u)
      p.line_to(cx + -0.9783 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -0.5489 * u, cx + -1 * u, cy + -0.5391 * u, cx + -1 * u, cy + -0.5272 * u)
      p.line_to(cx + -1 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.363 * u, cx + -0.9902 * u, cy + -0.3533 * u, cx + -0.9783 * u, cy + -0.3533 * u)
      p.close_path()
      p.move_to(cx + -0.0761 * u, cy + -0.3533 * u)
      p.line_to(cx + 0.0761 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + -0.3533 * u, cx + 0.0978 * u, cy + -0.363 * u, cx + 0.0978 * u, cy + -0.375 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.5391 * u, cx + 0.088 * u, cy + -0.5489 * u, cx + 0.0761 * u, cy + -0.5489 * u)
      p.line_to(cx + -0.0761 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -0.5489 * u, cx + -0.0978 * u, cy + -0.5391 * u, cx + -0.0978 * u, cy + -0.5272 * u)
      p.line_to(cx + -0.0978 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + -0.363 * u, cx + -0.088 * u, cy + -0.3533 * u, cx + -0.0761 * u, cy + -0.3533 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + 0.3533 * u)
      p.line_to(cx + -0.9783 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + 0.3533 * u, cx + -1 * u, cy + 0.363 * u, cx + -1 * u, cy + 0.375 * u)
      p.line_to(cx + -1 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.5391 * u, cx + -0.9902 * u, cy + 0.5489 * u, cx + -0.9783 * u, cy + 0.5489 * u)
      p.line_to(cx + -0.8261 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 0.5489 * u, cx + -0.8043 * u, cy + 0.5391 * u, cx + -0.8043 * u, cy + 0.5272 * u)
      p.line_to(cx + -0.8043 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + 0.363 * u, cx + -0.8141 * u, cy + 0.3533 * u, cx + -0.8261 * u, cy + 0.3533 * u)
      p.close_path()
      p.move_to(cx + 0.0761 * u, cy + 0.3533 * u)
      p.line_to(cx + -0.0761 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + 0.3533 * u, cx + -0.0978 * u, cy + 0.363 * u, cx + -0.0978 * u, cy + 0.375 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.5391 * u, cx + -0.088 * u, cy + 0.5489 * u, cx + -0.0761 * u, cy + 0.5489 * u)
      p.line_to(cx + 0.0761 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 0.5489 * u, cx + 0.0978 * u, cy + 0.5391 * u, cx + 0.0978 * u, cy + 0.5272 * u)
      p.line_to(cx + 0.0978 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + 0.363 * u, cx + 0.088 * u, cy + 0.3533 * u, cx + 0.0761 * u, cy + 0.3533 * u)
      p.close_path()
      p.fill()
    }
    YhBorderHorizontal => { // border-horizontal
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.0761 * u, cy + -1 * u)
      p.line_to(cx + -0.0761 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.088 * u, cy + -1 * u, cx + -0.0978 * u, cy + -0.9902 * u, cx + -0.0978 * u, cy + -0.9783 * u)
      p.line_to(cx + -0.0978 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -0.0978 * u, cy + 0.9902 * u, cx + -0.088 * u, cy + 1 * u, cx + -0.0761 * u, cy + 1 * u)
      p.line_to(cx + 0.0761 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.088 * u, cy + 1 * u, cx + 0.0978 * u, cy + 0.9902 * u, cx + 0.0978 * u, cy + 0.9783 * u)
      p.line_to(cx + 0.0978 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 0.0978 * u, cy + -0.9902 * u, cx + 0.088 * u, cy + -1 * u, cx + 0.0761 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.375 * u, cy + -1 * u)
      p.line_to(cx + -0.5272 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + -1 * u, cx + -0.5489 * u, cy + -0.9902 * u, cx + -0.5489 * u, cy + -0.9783 * u)
      p.line_to(cx + -0.5489 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + -0.8141 * u, cx + -0.5391 * u, cy + -0.8043 * u, cx + -0.5272 * u, cy + -0.8043 * u)
      p.line_to(cx + -0.375 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + -0.8043 * u, cx + -0.3533 * u, cy + -0.8141 * u, cx + -0.3533 * u, cy + -0.8261 * u)
      p.line_to(cx + -0.3533 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + -0.9902 * u, cx + -0.363 * u, cy + -1 * u, cx + -0.375 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -1 * u)
      p.line_to(cx + 0.8261 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -1 * u, cx + 0.8043 * u, cy + -0.9902 * u, cx + 0.8043 * u, cy + -0.9783 * u)
      p.line_to(cx + 0.8043 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + -0.8141 * u, cx + 0.8141 * u, cy + -0.8043 * u, cx + 0.8261 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.9783 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + -0.8043 * u, cx + 1 * u, cy + -0.8141 * u, cx + 1 * u, cy + -0.8261 * u)
      p.line_to(cx + 1 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.9902 * u, cx + 0.9902 * u, cy + -1 * u, cx + 0.9783 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + -1 * u)
      p.line_to(cx + -0.9783 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -1 * u, cx + -1 * u, cy + -0.9902 * u, cx + -1 * u, cy + -0.9783 * u)
      p.line_to(cx + -1 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.8141 * u, cx + -0.9902 * u, cy + -0.8043 * u, cx + -0.9783 * u, cy + -0.8043 * u)
      p.line_to(cx + -0.8261 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + -0.8043 * u, cx + -0.8043 * u, cy + -0.8141 * u, cx + -0.8043 * u, cy + -0.8261 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.9902 * u, cx + -0.8141 * u, cy + -1 * u, cx + -0.8261 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.5272 * u, cy + -1 * u)
      p.line_to(cx + 0.375 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + -1 * u, cx + 0.3533 * u, cy + -0.9902 * u, cx + 0.3533 * u, cy + -0.9783 * u)
      p.line_to(cx + 0.3533 * u, cy + -0.8261 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + -0.8141 * u, cx + 0.363 * u, cy + -0.8043 * u, cx + 0.375 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.5272 * u, cy + -0.8043 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + -0.8043 * u, cx + 0.5489 * u, cy + -0.8141 * u, cx + 0.5489 * u, cy + -0.8261 * u)
      p.line_to(cx + 0.5489 * u, cy + -0.9783 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + -0.9902 * u, cx + 0.5391 * u, cy + -1 * u, cx + 0.5272 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + -0.5489 * u)
      p.line_to(cx + -0.9783 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -0.5489 * u, cx + -1 * u, cy + -0.5391 * u, cx + -1 * u, cy + -0.5272 * u)
      p.line_to(cx + -1 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.363 * u, cx + -0.9902 * u, cy + -0.3533 * u, cx + -0.9783 * u, cy + -0.3533 * u)
      p.line_to(cx + -0.8261 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + -0.3533 * u, cx + -0.8043 * u, cy + -0.363 * u, cx + -0.8043 * u, cy + -0.375 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.5391 * u, cx + -0.8141 * u, cy + -0.5489 * u, cx + -0.8261 * u, cy + -0.5489 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -0.5489 * u)
      p.line_to(cx + 0.8261 * u, cy + -0.5489 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -0.5489 * u, cx + 0.8043 * u, cy + -0.5391 * u, cx + 0.8043 * u, cy + -0.5272 * u)
      p.line_to(cx + 0.8043 * u, cy + -0.375 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + -0.363 * u, cx + 0.8141 * u, cy + -0.3533 * u, cx + 0.8261 * u, cy + -0.3533 * u)
      p.line_to(cx + 0.9783 * u, cy + -0.3533 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + -0.3533 * u, cx + 1 * u, cy + -0.363 * u, cx + 1 * u, cy + -0.375 * u)
      p.line_to(cx + 1 * u, cy + -0.5272 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.5391 * u, cx + 0.9902 * u, cy + -0.5489 * u, cx + 0.9783 * u, cy + -0.5489 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + 0.3533 * u)
      p.line_to(cx + 0.8261 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + 0.3533 * u, cx + 0.8043 * u, cy + 0.363 * u, cx + 0.8043 * u, cy + 0.375 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.5391 * u, cx + 0.8141 * u, cy + 0.5489 * u, cx + 0.8261 * u, cy + 0.5489 * u)
      p.line_to(cx + 0.9783 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 0.5489 * u, cx + 1 * u, cy + 0.5391 * u, cx + 1 * u, cy + 0.5272 * u)
      p.line_to(cx + 1 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.363 * u, cx + 0.9902 * u, cy + 0.3533 * u, cx + 0.9783 * u, cy + 0.3533 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + 0.3533 * u)
      p.line_to(cx + -0.9783 * u, cy + 0.3533 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + 0.3533 * u, cx + -1 * u, cy + 0.363 * u, cx + -1 * u, cy + 0.375 * u)
      p.line_to(cx + -1 * u, cy + 0.5272 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.5391 * u, cx + -0.9902 * u, cy + 0.5489 * u, cx + -0.9783 * u, cy + 0.5489 * u)
      p.line_to(cx + -0.8261 * u, cy + 0.5489 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 0.5489 * u, cx + -0.8043 * u, cy + 0.5391 * u, cx + -0.8043 * u, cy + 0.5272 * u)
      p.line_to(cx + -0.8043 * u, cy + 0.375 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + 0.363 * u, cx + -0.8141 * u, cy + 0.3533 * u, cx + -0.8261 * u, cy + 0.3533 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.9783 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + 0.8043 * u, cx + -1 * u, cy + 0.8141 * u, cx + -1 * u, cy + 0.8261 * u)
      p.line_to(cx + -1 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9902 * u, cx + -0.9902 * u, cy + 1 * u, cx + -0.9783 * u, cy + 1 * u)
      p.line_to(cx + -0.8261 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 1 * u, cx + -0.8043 * u, cy + 0.9902 * u, cx + -0.8043 * u, cy + 0.9783 * u)
      p.line_to(cx + -0.8043 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + 0.8141 * u, cx + -0.8141 * u, cy + 0.8043 * u, cx + -0.8261 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.8261 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.9783 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + -0.0978 * u, cx + -1 * u, cy + -0.088 * u, cx + -1 * u, cy + -0.0761 * u)
      p.line_to(cx + -1 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.088 * u, cx + -0.9902 * u, cy + 0.0978 * u, cx + -0.9783 * u, cy + 0.0978 * u)
      p.line_to(cx + -0.8261 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + -0.8141 * u, cy + 0.0978 * u, cx + -0.8043 * u, cy + 0.088 * u, cx + -0.8043 * u, cy + 0.0761 * u)
      p.line_to(cx + -0.8043 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + -0.8043 * u, cy + -0.088 * u, cx + -0.8141 * u, cy + -0.0978 * u, cx + -0.8261 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + 0.8043 * u)
      p.line_to(cx + 0.8261 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + 0.8043 * u, cx + 0.8043 * u, cy + 0.8141 * u, cx + 0.8043 * u, cy + 0.8261 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.9902 * u, cx + 0.8141 * u, cy + 1 * u, cx + 0.8261 * u, cy + 1 * u)
      p.line_to(cx + 0.9783 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 1 * u, cx + 1 * u, cy + 0.9902 * u, cx + 1 * u, cy + 0.9783 * u)
      p.line_to(cx + 1 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.8141 * u, cx + 0.9902 * u, cy + 0.8043 * u, cx + 0.9783 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.9783 * u, cy + -0.0978 * u)
      p.line_to(cx + 0.8261 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + 0.8141 * u, cy + -0.0978 * u, cx + 0.8043 * u, cy + -0.088 * u, cx + 0.8043 * u, cy + -0.0761 * u)
      p.line_to(cx + 0.8043 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + 0.8043 * u, cy + 0.088 * u, cx + 0.8141 * u, cy + 0.0978 * u, cx + 0.8261 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.9783 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 0.0978 * u, cx + 1 * u, cy + 0.088 * u, cx + 1 * u, cy + 0.0761 * u)
      p.line_to(cx + 1 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.088 * u, cx + 0.9902 * u, cy + -0.0978 * u, cx + 0.9783 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + -0.375 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.5272 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + 0.8043 * u, cx + -0.5489 * u, cy + 0.8141 * u, cx + -0.5489 * u, cy + 0.8261 * u)
      p.line_to(cx + -0.5489 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + 0.9902 * u, cx + -0.5391 * u, cy + 1 * u, cx + -0.5272 * u, cy + 1 * u)
      p.line_to(cx + -0.375 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + 1 * u, cx + -0.3533 * u, cy + 0.9902 * u, cx + -0.3533 * u, cy + 0.9783 * u)
      p.line_to(cx + -0.3533 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + 0.8141 * u, cx + -0.363 * u, cy + 0.8043 * u, cx + -0.375 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + -0.375 * u, cy + -0.0978 * u)
      p.line_to(cx + -0.5272 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + -0.5391 * u, cy + -0.0978 * u, cx + -0.5489 * u, cy + -0.088 * u, cx + -0.5489 * u, cy + -0.0761 * u)
      p.line_to(cx + -0.5489 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + -0.5489 * u, cy + 0.088 * u, cx + -0.5391 * u, cy + 0.0978 * u, cx + -0.5272 * u, cy + 0.0978 * u)
      p.line_to(cx + -0.375 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + -0.363 * u, cy + 0.0978 * u, cx + -0.3533 * u, cy + 0.088 * u, cx + -0.3533 * u, cy + 0.0761 * u)
      p.line_to(cx + -0.3533 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + -0.3533 * u, cy + -0.088 * u, cx + -0.363 * u, cy + -0.0978 * u, cx + -0.375 * u, cy + -0.0978 * u)
      p.close_path()
      p.move_to(cx + 0.5272 * u, cy + 0.8043 * u)
      p.line_to(cx + 0.375 * u, cy + 0.8043 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + 0.8043 * u, cx + 0.3533 * u, cy + 0.8141 * u, cx + 0.3533 * u, cy + 0.8261 * u)
      p.line_to(cx + 0.3533 * u, cy + 0.9783 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + 0.9902 * u, cx + 0.363 * u, cy + 1 * u, cx + 0.375 * u, cy + 1 * u)
      p.line_to(cx + 0.5272 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + 1 * u, cx + 0.5489 * u, cy + 0.9902 * u, cx + 0.5489 * u, cy + 0.9783 * u)
      p.line_to(cx + 0.5489 * u, cy + 0.8261 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + 0.8141 * u, cx + 0.5391 * u, cy + 0.8043 * u, cx + 0.5272 * u, cy + 0.8043 * u)
      p.close_path()
      p.move_to(cx + 0.5272 * u, cy + -0.0978 * u)
      p.line_to(cx + 0.375 * u, cy + -0.0978 * u)
      p.bezier_curve_to(cx + 0.363 * u, cy + -0.0978 * u, cx + 0.3533 * u, cy + -0.088 * u, cx + 0.3533 * u, cy + -0.0761 * u)
      p.line_to(cx + 0.3533 * u, cy + 0.0761 * u)
      p.bezier_curve_to(cx + 0.3533 * u, cy + 0.088 * u, cx + 0.363 * u, cy + 0.0978 * u, cx + 0.375 * u, cy + 0.0978 * u)
      p.line_to(cx + 0.5272 * u, cy + 0.0978 * u)
      p.bezier_curve_to(cx + 0.5391 * u, cy + 0.0978 * u, cx + 0.5489 * u, cy + 0.088 * u, cx + 0.5489 * u, cy + 0.0761 * u)
      p.line_to(cx + 0.5489 * u, cy + -0.0761 * u)
      p.bezier_curve_to(cx + 0.5489 * u, cy + -0.088 * u, cx + 0.5391 * u, cy + -0.0978 * u, cx + 0.5272 * u, cy + -0.0978 * u)
      p.close_path()
      p.fill()
    }
    YhAppstore => { // app store
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.1304 * u, cy + -1 * u)
      p.line_to(cx + -0.9565 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.9804 * u, cy + -1 * u, cx + -1 * u, cy + -0.9804 * u, cx + -1 * u, cy + -0.9565 * u)
      p.line_to(cx + -1 * u, cy + -0.1304 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.1065 * u, cx + -0.9804 * u, cy + -0.087 * u, cx + -0.9565 * u, cy + -0.087 * u)
      p.line_to(cx + -0.1304 * u, cy + -0.087 * u)
      p.bezier_curve_to(cx + -0.1065 * u, cy + -0.087 * u, cx + -0.087 * u, cy + -0.1065 * u, cx + -0.087 * u, cy + -0.1304 * u)
      p.line_to(cx + -0.087 * u, cy + -0.9565 * u)
      p.bezier_curve_to(cx + -0.087 * u, cy + -0.9804 * u, cx + -0.1065 * u, cy + -1 * u, cx + -0.1304 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.2717 * u, cy + -0.2717 * u)
      p.line_to(cx + -0.8152 * u, cy + -0.2717 * u)
      p.line_to(cx + -0.8152 * u, cy + -0.8152 * u)
      p.line_to(cx + -0.2717 * u, cy + -0.8152 * u)
      p.line_to(cx + -0.2717 * u, cy + -0.2717 * u)
      p.close_path()
      p.move_to(cx + 0.9565 * u, cy + -1 * u)
      p.line_to(cx + 0.1304 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.1065 * u, cy + -1 * u, cx + 0.087 * u, cy + -0.9804 * u, cx + 0.087 * u, cy + -0.9565 * u)
      p.line_to(cx + 0.087 * u, cy + -0.1304 * u)
      p.bezier_curve_to(cx + 0.087 * u, cy + -0.1065 * u, cx + 0.1065 * u, cy + -0.087 * u, cx + 0.1304 * u, cy + -0.087 * u)
      p.line_to(cx + 0.9565 * u, cy + -0.087 * u)
      p.bezier_curve_to(cx + 0.9804 * u, cy + -0.087 * u, cx + 1 * u, cy + -0.1065 * u, cx + 1 * u, cy + -0.1304 * u)
      p.line_to(cx + 1 * u, cy + -0.9565 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.9804 * u, cx + 0.9804 * u, cy + -1 * u, cx + 0.9565 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.8152 * u, cy + -0.2717 * u)
      p.line_to(cx + 0.2717 * u, cy + -0.2717 * u)
      p.line_to(cx + 0.2717 * u, cy + -0.8152 * u)
      p.line_to(cx + 0.8152 * u, cy + -0.8152 * u)
      p.line_to(cx + 0.8152 * u, cy + -0.2717 * u)
      p.close_path()
      p.move_to(cx + -0.1304 * u, cy + 0.087 * u)
      p.line_to(cx + -0.9565 * u, cy + 0.087 * u)
      p.bezier_curve_to(cx + -0.9804 * u, cy + 0.087 * u, cx + -1 * u, cy + 0.1065 * u, cx + -1 * u, cy + 0.1304 * u)
      p.line_to(cx + -1 * u, cy + 0.9565 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9804 * u, cx + -0.9804 * u, cy + 1 * u, cx + -0.9565 * u, cy + 1 * u)
      p.line_to(cx + -0.1304 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.1065 * u, cy + 1 * u, cx + -0.087 * u, cy + 0.9804 * u, cx + -0.087 * u, cy + 0.9565 * u)
      p.line_to(cx + -0.087 * u, cy + 0.1304 * u)
      p.bezier_curve_to(cx + -0.087 * u, cy + 0.1065 * u, cx + -0.1065 * u, cy + 0.087 * u, cx + -0.1304 * u, cy + 0.087 * u)
      p.close_path()
      p.move_to(cx + -0.2717 * u, cy + 0.8152 * u)
      p.line_to(cx + -0.8152 * u, cy + 0.8152 * u)
      p.line_to(cx + -0.8152 * u, cy + 0.2717 * u)
      p.line_to(cx + -0.2717 * u, cy + 0.2717 * u)
      p.line_to(cx + -0.2717 * u, cy + 0.8152 * u)
      p.close_path()
      p.move_to(cx + 0.9565 * u, cy + 0.087 * u)
      p.line_to(cx + 0.1304 * u, cy + 0.087 * u)
      p.bezier_curve_to(cx + 0.1065 * u, cy + 0.087 * u, cx + 0.087 * u, cy + 0.1065 * u, cx + 0.087 * u, cy + 0.1304 * u)
      p.line_to(cx + 0.087 * u, cy + 0.9565 * u)
      p.bezier_curve_to(cx + 0.087 * u, cy + 0.9804 * u, cx + 0.1065 * u, cy + 1 * u, cx + 0.1304 * u, cy + 1 * u)
      p.line_to(cx + 0.9565 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.9804 * u, cy + 1 * u, cx + 1 * u, cy + 0.9804 * u, cx + 1 * u, cy + 0.9565 * u)
      p.line_to(cx + 1 * u, cy + 0.1304 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.1065 * u, cx + 0.9804 * u, cy + 0.087 * u, cx + 0.9565 * u, cy + 0.087 * u)
      p.close_path()
      p.move_to(cx + 0.8152 * u, cy + 0.8152 * u)
      p.line_to(cx + 0.2717 * u, cy + 0.8152 * u)
      p.line_to(cx + 0.2717 * u, cy + 0.2717 * u)
      p.line_to(cx + 0.8152 * u, cy + 0.2717 * u)
      p.line_to(cx + 0.8152 * u, cy + 0.8152 * u)
      p.close_path()
      p.fill()
    }
    YhFullscreen => { // full-screen
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.8462 * u, cy + -1 * u)
      p.line_to(cx + -0.3846 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.3622 * u, cy + -0.9984 * u, cx + -0.3437 * u, cy + -0.9904 * u, cx + -0.3293 * u, cy + -0.9759 * u)
      p.bezier_curve_to(cx + -0.3149 * u, cy + -0.9615 * u, cx + -0.3077 * u, cy + -0.9434 * u, cx + -0.3077 * u, cy + -0.9218 * u)
      p.bezier_curve_to(cx + -0.3077 * u, cy + -0.9003 * u, cx + -0.3149 * u, cy + -0.8822 * u, cx + -0.3293 * u, cy + -0.8678 * u)
      p.bezier_curve_to(cx + -0.3437 * u, cy + -0.8533 * u, cx + -0.3622 * u, cy + -0.8461 * u, cx + -0.3846 * u, cy + -0.8462 * u)
      p.line_to(cx + -0.8462 * u, cy + -0.8462 * u)
      p.line_to(cx + -0.8462 * u, cy + -0.3846 * u)
      p.bezier_curve_to(cx + -0.8462 * u, cy + -0.3622 * u, cx + -0.8534 * u, cy + -0.3437 * u, cx + -0.8678 * u, cy + -0.3293 * u)
      p.bezier_curve_to(cx + -0.8822 * u, cy + -0.3149 * u, cx + -0.9006 * u, cy + -0.3077 * u, cx + -0.9231 * u, cy + -0.3077 * u)
      p.bezier_curve_to(cx + -0.9455 * u, cy + -0.3077 * u, cx + -0.964 * u, cy + -0.3149 * u, cx + -0.9784 * u, cy + -0.3293 * u)
      p.bezier_curve_to(cx + -0.9928 * u, cy + -0.3437 * u, cx + -1 * u, cy + -0.3622 * u, cx + -1 * u, cy + -0.3846 * u)
      p.line_to(cx + -1 * u, cy + -1 * u)
      p.line_to(cx + -0.8462 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.8462 * u, cy + 1 * u)
      p.line_to(cx + -1 * u, cy + 1 * u)
      p.line_to(cx + -1 * u, cy + 0.3846 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.3622 * u, cx + -0.9928 * u, cy + 0.3437 * u, cx + -0.9784 * u, cy + 0.3293 * u)
      p.bezier_curve_to(cx + -0.964 * u, cy + 0.3149 * u, cx + -0.9455 * u, cy + 0.3077 * u, cx + -0.9231 * u, cy + 0.3077 * u)
      p.bezier_curve_to(cx + -0.9006 * u, cy + 0.3077 * u, cx + -0.8822 * u, cy + 0.3149 * u, cx + -0.8678 * u, cy + 0.3293 * u)
      p.bezier_curve_to(cx + -0.8534 * u, cy + 0.3437 * u, cx + -0.8462 * u, cy + 0.3622 * u, cx + -0.8462 * u, cy + 0.3846 * u)
      p.line_to(cx + -0.8462 * u, cy + 0.8462 * u)
      p.line_to(cx + -0.3846 * u, cy + 0.8462 * u)
      p.bezier_curve_to(cx + -0.3622 * u, cy + 0.8462 * u, cx + -0.3437 * u, cy + 0.8534 * u, cx + -0.3293 * u, cy + 0.8678 * u)
      p.bezier_curve_to(cx + -0.3149 * u, cy + 0.8822 * u, cx + -0.3077 * u, cy + 0.9002 * u, cx + -0.3077 * u, cy + 0.9218 * u)
      p.bezier_curve_to(cx + -0.3077 * u, cy + 0.9435 * u, cx + -0.3149 * u, cy + 0.9615 * u, cx + -0.3293 * u, cy + 0.9759 * u)
      p.bezier_curve_to(cx + -0.3437 * u, cy + 0.9903 * u, cx + -0.3622 * u, cy + 0.9984 * u, cx + -0.3846 * u, cy + 1 * u)
      p.line_to(cx + -0.8462 * u, cy + 1 * u)
      p.close_path()
      p.move_to(cx + 0.8462 * u, cy + -1 * u)
      p.line_to(cx + 1 * u, cy + -1 * u)
      p.line_to(cx + 1 * u, cy + -0.3846 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.3622 * u, cx + 0.9928 * u, cy + -0.3437 * u, cx + 0.9784 * u, cy + -0.3293 * u)
      p.bezier_curve_to(cx + 0.964 * u, cy + -0.3149 * u, cx + 0.9455 * u, cy + -0.3077 * u, cx + 0.9231 * u, cy + -0.3077 * u)
      p.bezier_curve_to(cx + 0.9006 * u, cy + -0.3077 * u, cx + 0.8822 * u, cy + -0.3149 * u, cx + 0.8678 * u, cy + -0.3293 * u)
      p.bezier_curve_to(cx + 0.8534 * u, cy + -0.3437 * u, cx + 0.8462 * u, cy + -0.3622 * u, cx + 0.8462 * u, cy + -0.3846 * u)
      p.line_to(cx + 0.8462 * u, cy + -0.8462 * u)
      p.line_to(cx + 0.3846 * u, cy + -0.8462 * u)
      p.bezier_curve_to(cx + 0.3622 * u, cy + -0.8462 * u, cx + 0.3437 * u, cy + -0.8534 * u, cx + 0.3293 * u, cy + -0.8678 * u)
      p.bezier_curve_to(cx + 0.3149 * u, cy + -0.8822 * u, cx + 0.3077 * u, cy + -0.9002 * u, cx + 0.3077 * u, cy + -0.9218 * u)
      p.bezier_curve_to(cx + 0.3077 * u, cy + -0.9435 * u, cx + 0.3149 * u, cy + -0.9615 * u, cx + 0.3293 * u, cy + -0.9759 * u)
      p.bezier_curve_to(cx + 0.3437 * u, cy + -0.9903 * u, cx + 0.3622 * u, cy + -0.9984 * u, cx + 0.3846 * u, cy + -1 * u)
      p.line_to(cx + 0.8462 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.8462 * u, cy + 1 * u)
      p.line_to(cx + 0.3846 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.3622 * u, cy + 0.9984 * u, cx + 0.3437 * u, cy + 0.9904 * u, cx + 0.3293 * u, cy + 0.9759 * u)
      p.bezier_curve_to(cx + 0.3149 * u, cy + 0.9615 * u, cx + 0.3077 * u, cy + 0.9434 * u, cx + 0.3077 * u, cy + 0.9218 * u)
      p.bezier_curve_to(cx + 0.3077 * u, cy + 0.9003 * u, cx + 0.3149 * u, cy + 0.8822 * u, cx + 0.3293 * u, cy + 0.8678 * u)
      p.bezier_curve_to(cx + 0.3437 * u, cy + 0.8533 * u, cx + 0.3622 * u, cy + 0.8461 * u, cx + 0.3846 * u, cy + 0.8462 * u)
      p.line_to(cx + 0.8462 * u, cy + 0.8462 * u)
      p.line_to(cx + 0.8462 * u, cy + 0.3846 * u)
      p.bezier_curve_to(cx + 0.8462 * u, cy + 0.3622 * u, cx + 0.8534 * u, cy + 0.3437 * u, cx + 0.8678 * u, cy + 0.3293 * u)
      p.bezier_curve_to(cx + 0.8822 * u, cy + 0.3149 * u, cx + 0.9006 * u, cy + 0.3077 * u, cx + 0.9231 * u, cy + 0.3077 * u)
      p.bezier_curve_to(cx + 0.9455 * u, cy + 0.3077 * u, cx + 0.964 * u, cy + 0.3149 * u, cx + 0.9784 * u, cy + 0.3293 * u)
      p.bezier_curve_to(cx + 0.9928 * u, cy + 0.3437 * u, cx + 1 * u, cy + 0.3622 * u, cx + 1 * u, cy + 0.3846 * u)
      p.line_to(cx + 1 * u, cy + 1 * u)
      p.line_to(cx + 0.8462 * u, cy + 1 * u)
      p.close_path()
      p.fill()
    }
    YhFullscreenExit => { // fullscreen-exit
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.3281 * u, cy + -0.7351 * u)
      p.bezier_curve_to(cx + -0.3303 * u, cy + -0.753 * u, cx + -0.3522 * u, cy + -0.7606 * u, cx + -0.365 * u, cy + -0.7478 * u)
      p.line_to(cx + -0.4835 * u, cy + -0.6293 * u)
      p.line_to(cx + -0.846 * u, cy + -0.9916 * u)
      p.bezier_curve_to(cx + -0.8544 * u, cy + -1 * u, cx + -0.8682 * u, cy + -1 * u, cx + -0.8766 * u, cy + -0.9916 * u)
      p.line_to(cx + -0.9916 * u, cy + -0.8769 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.8685 * u, cx + -1 * u, cy + -0.8547 * u, cx + -0.9916 * u, cy + -0.8463 * u)
      p.line_to(cx + -0.6291 * u, cy + -0.4837 * u)
      p.line_to(cx + -0.7481 * u, cy + -0.3647 * u)
      p.bezier_curve_to(cx + -0.7608 * u, cy + -0.352 * u, cx + -0.7533 * u, cy + -0.33 * u, cx + -0.7354 * u, cy + -0.3278 * u)
      p.line_to(cx + -0.301 * u, cy + -0.2766 * u)
      p.bezier_curve_to(cx + -0.2871 * u, cy + -0.2749 * u, cx + -0.2752 * u, cy + -0.2866 * u, cx + -0.2768 * u, cy + -0.3007 * u)
      p.line_to(cx + -0.3281 * u, cy + -0.7351 * u)
      p.close_path()
      p.move_to(cx + -0.3007 * u, cy + 0.2768 * u)
      p.line_to(cx + -0.7354 * u, cy + 0.3281 * u)
      p.bezier_curve_to(cx + -0.7533 * u, cy + 0.3303 * u, cx + -0.7608 * u, cy + 0.3522 * u, cx + -0.7481 * u, cy + 0.365 * u)
      p.line_to(cx + -0.6291 * u, cy + 0.484 * u)
      p.line_to(cx + -0.9916 * u, cy + 0.846 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.8544 * u, cx + -1 * u, cy + 0.8682 * u, cx + -0.9916 * u, cy + 0.8766 * u)
      p.line_to(cx + -0.8766 * u, cy + 0.9913 * u)
      p.bezier_curve_to(cx + -0.8682 * u, cy + 0.9997 * u, cx + -0.8544 * u, cy + 0.9997 * u, cx + -0.846 * u, cy + 0.9913 * u)
      p.line_to(cx + -0.4835 * u, cy + 0.6291 * u)
      p.line_to(cx + -0.365 * u, cy + 0.7476 * u)
      p.bezier_curve_to(cx + -0.3522 * u, cy + 0.7603 * u, cx + -0.3303 * u, cy + 0.7527 * u, cx + -0.3281 * u, cy + 0.7348 * u)
      p.line_to(cx + -0.2768 * u, cy + 0.3007 * u)
      p.bezier_curve_to(cx + -0.2752 * u, cy + 0.2869 * u, cx + -0.2869 * u, cy + 0.2752 * u, cx + -0.3007 * u, cy + 0.2768 * u)
      p.close_path()
      p.move_to(cx + 0.3007 * u, cy + -0.2768 * u)
      p.line_to(cx + 0.7354 * u, cy + -0.3281 * u)
      p.bezier_curve_to(cx + 0.7533 * u, cy + -0.3303 * u, cx + 0.7608 * u, cy + -0.3522 * u, cx + 0.7481 * u, cy + -0.365 * u)
      p.line_to(cx + 0.6291 * u, cy + -0.4837 * u)
      p.line_to(cx + 0.9916 * u, cy + -0.846 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.8544 * u, cx + 1 * u, cy + -0.8682 * u, cx + 0.9916 * u, cy + -0.8766 * u)
      p.line_to(cx + 0.8766 * u, cy + -0.9913 * u)
      p.bezier_curve_to(cx + 0.8682 * u, cy + -0.9997 * u, cx + 0.8544 * u, cy + -0.9997 * u, cx + 0.846 * u, cy + -0.9913 * u)
      p.line_to(cx + 0.4835 * u, cy + -0.6293 * u)
      p.line_to(cx + 0.365 * u, cy + -0.7478 * u)
      p.bezier_curve_to(cx + 0.3522 * u, cy + -0.7606 * u, cx + 0.3303 * u, cy + -0.753 * u, cx + 0.3281 * u, cy + -0.7351 * u)
      p.line_to(cx + 0.2768 * u, cy + -0.301 * u)
      p.bezier_curve_to(cx + 0.2752 * u, cy + -0.2869 * u, cx + 0.2869 * u, cy + -0.2752 * u, cx + 0.3007 * u, cy + -0.2768 * u)
      p.close_path()
      p.move_to(cx + 0.6291 * u, cy + 0.4837 * u)
      p.line_to(cx + 0.7481 * u, cy + 0.3647 * u)
      p.bezier_curve_to(cx + 0.7608 * u, cy + 0.352 * u, cx + 0.7533 * u, cy + 0.33 * u, cx + 0.7354 * u, cy + 0.3278 * u)
      p.line_to(cx + 0.301 * u, cy + 0.2766 * u)
      p.bezier_curve_to(cx + 0.2871 * u, cy + 0.2749 * u, cx + 0.2752 * u, cy + 0.2866 * u, cx + 0.2768 * u, cy + 0.3007 * u)
      p.line_to(cx + 0.3281 * u, cy + 0.7351 * u)
      p.bezier_curve_to(cx + 0.3303 * u, cy + 0.753 * u, cx + 0.3522 * u, cy + 0.7606 * u, cx + 0.365 * u, cy + 0.7478 * u)
      p.line_to(cx + 0.4835 * u, cy + 0.6293 * u)
      p.line_to(cx + 0.846 * u, cy + 0.9916 * u)
      p.bezier_curve_to(cx + 0.8544 * u, cy + 1 * u, cx + 0.8682 * u, cy + 1 * u, cx + 0.8766 * u, cy + 0.9916 * u)
      p.line_to(cx + 0.9916 * u, cy + 0.8769 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.8685 * u, cx + 1 * u, cy + 0.8547 * u, cx + 0.9916 * u, cy + 0.8463 * u)
      p.line_to(cx + 0.6291 * u, cy + 0.4837 * u)
      p.close_path()
      p.fill()
    }
    YhToTop => { // totop
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9783 * u, cy + 0.7298 * u)
      p.line_to(cx + -0.9783 * u, cy + 0.7298 * u)
      p.bezier_curve_to(cx + -0.9902 * u, cy + 0.7298 * u, cx + -1 * u, cy + 0.7395 * u, cx + -1 * u, cy + 0.7515 * u)
      p.line_to(cx + -1 * u, cy + 0.9145 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9265 * u, cx + -0.9902 * u, cy + 0.9363 * u, cx + -0.9783 * u, cy + 0.9363 * u)
      p.line_to(cx + 0.9783 * u, cy + 0.9363 * u)
      p.bezier_curve_to(cx + 0.9902 * u, cy + 0.9363 * u, cx + 1 * u, cy + 0.9265 * u, cx + 1 * u, cy + 0.9145 * u)
      p.line_to(cx + 1 * u, cy + 0.7515 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.7395 * u, cx + 0.9902 * u, cy + 0.7298 * u, cx + 0.9783 * u, cy + 0.7298 * u)
      p.close_path()
      p.move_to(cx + -0.3397 * u, cy + -0.5048 * u)
      p.line_to(cx + -0.1389 * u, cy + -0.5048 * u)
      p.line_to(cx + -0.1389 * u, cy + 0.4145 * u)
      p.bezier_curve_to(cx + -0.1389 * u, cy + 0.4265 * u, cx + -0.1291 * u, cy + 0.4363 * u, cx + -0.1171 * u, cy + 0.4363 * u)
      p.line_to(cx + 0.0459 * u, cy + 0.4363 * u)
      p.bezier_curve_to(cx + 0.0579 * u, cy + 0.4363 * u, cx + 0.0677 * u, cy + 0.4265 * u, cx + 0.0677 * u, cy + 0.4145 * u)
      p.line_to(cx + 0.0677 * u, cy + -0.5048 * u)
      p.line_to(cx + 0.269 * u, cy + -0.5048 * u)
      p.bezier_curve_to(cx + 0.2872 * u, cy + -0.5048 * u, cx + 0.2973 * u, cy + -0.5257 * u, cx + 0.2861 * u, cy + -0.5398 * u)
      p.line_to(cx + -0.0182 * u, cy + -0.9251 * u)
      p.bezier_curve_to(cx + -0.0269 * u, cy + -0.9363 * u, cx + -0.0438 * u, cy + -0.9363 * u, cx + -0.0524 * u, cy + -0.9251 * u)
      p.line_to(cx + -0.3568 * u, cy + -0.5401 * u)
      p.bezier_curve_to(cx + -0.3679 * u, cy + -0.5257 * u, cx + -0.3579 * u, cy + -0.5048 * u, cx + -0.3397 * u, cy + -0.5048 * u)
      p.close_path()
      p.fill()
    }
    YhSwap => { // swap
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.8896 * u, cy + 0.2119 * u)
      p.line_to(cx + -0.9534 * u, cy + 0.2119 * u)
      p.bezier_curve_to(cx + -0.965 * u, cy + 0.2119 * u, cx + -0.9746 * u, cy + 0.2214 * u, cx + -0.9746 * u, cy + 0.2331 * u)
      p.line_to(cx + -0.9746 * u, cy + 0.3919 * u)
      p.bezier_curve_to(cx + -0.9746 * u, cy + 0.4036 * u, cx + -0.965 * u, cy + 0.4131 * u, cx + -0.9534 * u, cy + 0.4131 * u)
      p.line_to(cx + 0.6494 * u, cy + 0.4131 * u)
      p.line_to(cx + 0.2672 * u, cy + 0.8978 * u)
      p.bezier_curve_to(cx + 0.2564 * u, cy + 0.9115 * u, cx + 0.2662 * u, cy + 0.9322 * u, cx + 0.2839 * u, cy + 0.9322 * u)
      p.line_to(cx + 0.4759 * u, cy + 0.9322 * u)
      p.bezier_curve_to(cx + 0.4889 * u, cy + 0.9322 * u, cx + 0.5011 * u, cy + 0.9264 * u, cx + 0.5093 * u, cy + 0.916 * u)
      p.line_to(cx + 0.9563 * u, cy + 0.349 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.2934 * u, cx + 0.9605 * u, cy + 0.2119 * u, cx + 0.8896 * u, cy + 0.2119 * u)
      p.close_path()
      p.move_to(cx + 0.9534 * u, cy + -0.4131 * u)
      p.line_to(cx + -0.6494 * u, cy + -0.4131 * u)
      p.line_to(cx + -0.2672 * u, cy + -0.8978 * u)
      p.bezier_curve_to(cx + -0.2564 * u, cy + -0.9115 * u, cx + -0.2662 * u, cy + -0.9322 * u, cx + -0.2839 * u, cy + -0.9322 * u)
      p.line_to(cx + -0.4759 * u, cy + -0.9322 * u)
      p.bezier_curve_to(cx + -0.4889 * u, cy + -0.9322 * u, cx + -0.5011 * u, cy + -0.9264 * u, cx + -0.5093 * u, cy + -0.916 * u)
      p.line_to(cx + -0.9563 * u, cy + -0.349 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.2934 * u, cx + -0.9605 * u, cy + -0.2119 * u, cx + -0.8898 * u, cy + -0.2119 * u)
      p.line_to(cx + 0.9534 * u, cy + -0.2119 * u)
      p.bezier_curve_to(cx + 0.965 * u, cy + -0.2119 * u, cx + 0.9746 * u, cy + -0.2214 * u, cx + 0.9746 * u, cy + -0.2331 * u)
      p.line_to(cx + 0.9746 * u, cy + -0.3919 * u)
      p.bezier_curve_to(cx + 0.9746 * u, cy + -0.4036 * u, cx + 0.965 * u, cy + -0.4131 * u, cx + 0.9534 * u, cy + -0.4131 * u)
      p.close_path()
      p.fill()
    }
    YhRollback => { // rollback
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.704 * u, cy + -0.4912 * u)
      p.line_to(cx + -0.4174 * u, cy + -0.7776 * u)
      p.line_to(cx + -0.5404 * u, cy + -0.9008 * u)
      p.line_to(cx + -0.9749 * u, cy + -0.4663 * u)
      p.line_to(cx + -0.9846 * u, cy + -0.4545 * u)
      p.line_to(cx + -0.9922 * u, cy + -0.4413 * u)
      p.line_to(cx + -0.9974 * u, cy + -0.4269 * u)
      p.line_to(cx + -1 * u, cy + -0.4118 * u)
      p.line_to(cx + -1 * u, cy + -0.3966 * u)
      p.line_to(cx + -0.9974 * u, cy + -0.3815 * u)
      p.line_to(cx + -0.9922 * u, cy + -0.3671 * u)
      p.line_to(cx + -0.9846 * u, cy + -0.3539 * u)
      p.line_to(cx + -0.9749 * u, cy + -0.3421 * u)
      p.line_to(cx + -0.5404 * u, cy + 0.0924 * u)
      p.line_to(cx + -0.4174 * u, cy + -0.0308 * u)
      p.line_to(cx + -0.704 * u, cy + -0.3172 * u)
      p.line_to(cx + 0.304 * u, cy + -0.3172 * u)
      p.line_to(cx + 0.3946 * u, cy + -0.3093 * u)
      p.line_to(cx + 0.4825 * u, cy + -0.2857 * u)
      p.line_to(cx + 0.565 * u, cy + -0.2473 * u)
      p.line_to(cx + 0.6395 * u, cy + -0.1951 * u)
      p.line_to(cx + 0.7039 * u, cy + -0.1307 * u)
      p.line_to(cx + 0.7561 * u, cy + -0.0562 * u)
      p.line_to(cx + 0.7945 * u, cy + 0.0263 * u)
      p.line_to(cx + 0.8181 * u, cy + 0.1142 * u)
      p.line_to(cx + 0.826 * u, cy + 0.2048 * u)
      p.line_to(cx + 0.8181 * u, cy + 0.2954 * u)
      p.line_to(cx + 0.7945 * u, cy + 0.3833 * u)
      p.line_to(cx + 0.7561 * u, cy + 0.4658 * u)
      p.line_to(cx + 0.7039 * u, cy + 0.5403 * u)
      p.line_to(cx + 0.6395 * u, cy + 0.6047 * u)
      p.line_to(cx + 0.565 * u, cy + 0.6569 * u)
      p.line_to(cx + 0.4825 * u, cy + 0.6953 * u)
      p.line_to(cx + 0.3946 * u, cy + 0.7189 * u)
      p.line_to(cx + 0.304 * u, cy + 0.7268 * u)
      p.line_to(cx + -0.566 * u, cy + 0.7268 * u)
      p.line_to(cx + -0.566 * u, cy + 0.9008 * u)
      p.line_to(cx + 0.304 * u, cy + 0.9008 * u)
      p.line_to(cx + 0.4249 * u, cy + 0.8902 * u)
      p.line_to(cx + 0.542 * u, cy + 0.8588 * u)
      p.line_to(cx + 0.652 * u, cy + 0.8075 * u)
      p.line_to(cx + 0.7514 * u, cy + 0.738 * u)
      p.line_to(cx + 0.8372 * u, cy + 0.6522 * u)
      p.line_to(cx + 0.9068 * u, cy + 0.5528 * u)
      p.line_to(cx + 0.958 * u, cy + 0.4428 * u)
      p.line_to(cx + 0.9894 * u, cy + 0.3257 * u)
      p.line_to(cx + 1 * u, cy + 0.2048 * u)
      p.line_to(cx + 0.9894 * u, cy + 0.0839 * u)
      p.line_to(cx + 0.958 * u, cy + -0.0332 * u)
      p.line_to(cx + 0.9068 * u, cy + -0.1432 * u)
      p.line_to(cx + 0.8372 * u, cy + -0.2426 * u)
      p.line_to(cx + 0.7514 * u, cy + -0.3284 * u)
      p.line_to(cx + 0.652 * u, cy + -0.398 * u)
      p.line_to(cx + 0.542 * u, cy + -0.4492 * u)
      p.line_to(cx + 0.4249 * u, cy + -0.4806 * u)
      p.line_to(cx + 0.304 * u, cy + -0.4912 * u)
      p.line_to(cx + -0.704 * u, cy + -0.4912 * u)
      p.close_path()
      p.fill()
    }
    YhEnter => { // enter
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.826 * u, cy + -0.8138 * u)
      p.line_to(cx + 0.826 * u, cy + 0.2302 * u)
      p.line_to(cx + -0.704 * u, cy + 0.2302 * u)
      p.line_to(cx + -0.4174 * u, cy + -0.0562 * u)
      p.line_to(cx + -0.5404 * u, cy + -0.1794 * u)
      p.line_to(cx + -0.9749 * u, cy + 0.2551 * u)
      p.line_to(cx + -0.9846 * u, cy + 0.2669 * u)
      p.line_to(cx + -0.9922 * u, cy + 0.2801 * u)
      p.line_to(cx + -0.9974 * u, cy + 0.2945 * u)
      p.line_to(cx + -1 * u, cy + 0.3096 * u)
      p.line_to(cx + -1 * u, cy + 0.3248 * u)
      p.line_to(cx + -0.9974 * u, cy + 0.3399 * u)
      p.line_to(cx + -0.9922 * u, cy + 0.3543 * u)
      p.line_to(cx + -0.9846 * u, cy + 0.3675 * u)
      p.line_to(cx + -0.9749 * u, cy + 0.3793 * u)
      p.line_to(cx + -0.5404 * u, cy + 0.8138 * u)
      p.line_to(cx + -0.4174 * u, cy + 0.6906 * u)
      p.line_to(cx + -0.704 * u, cy + 0.4042 * u)
      p.line_to(cx + 0.826 * u, cy + 0.4042 * u)
      p.line_to(cx + 0.8562 * u, cy + 0.4016 * u)
      p.line_to(cx + 0.8855 * u, cy + 0.3937 * u)
      p.line_to(cx + 0.913 * u, cy + 0.3809 * u)
      p.line_to(cx + 0.9378 * u, cy + 0.3635 * u)
      p.line_to(cx + 0.9593 * u, cy + 0.342 * u)
      p.line_to(cx + 0.9767 * u, cy + 0.3172 * u)
      p.line_to(cx + 0.9895 * u, cy + 0.2897 * u)
      p.line_to(cx + 0.9974 * u, cy + 0.2604 * u)
      p.line_to(cx + 1 * u, cy + 0.2302 * u)
      p.line_to(cx + 1 * u, cy + -0.8138 * u)
      p.line_to(cx + 0.826 * u, cy + -0.8138 * u)
      p.close_path()
      p.fill()
    }
    YhDrag => { // drag
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.991 * u, cy + -0.0141 * u)
      p.line_to(cx + 0.6728 * u, cy + -0.2652 * u)
      p.bezier_curve_to(cx + 0.6611 * u, cy + -0.2745 * u, cx + 0.6436 * u, cy + -0.2662 * u, cx + 0.6436 * u, cy + -0.251 * u)
      p.line_to(cx + 0.6436 * u, cy + -0.0897 * u)
      p.line_to(cx + 0.0899 * u, cy + -0.0897 * u)
      p.line_to(cx + 0.0899 * u, cy + -0.6433 * u)
      p.line_to(cx + 0.2515 * u, cy + -0.6433 * u)
      p.bezier_curve_to(cx + 0.2665 * u, cy + -0.6433 * u, cx + 0.275 * u, cy + -0.6608 * u, cx + 0.2657 * u, cy + -0.6725 * u)
      p.line_to(cx + 0.0143 * u, cy + -0.9908 * u)
      p.bezier_curve_to(cx + 0.0071 * u, cy + -1 * u, cx + -0.0069 * u, cy + -1 * u, cx + -0.0138 * u, cy + -0.9908 * u)
      p.line_to(cx + -0.2652 * u, cy + -0.6725 * u)
      p.bezier_curve_to(cx + -0.2745 * u, cy + -0.6608 * u, cx + -0.2662 * u, cy + -0.6433 * u, cx + -0.251 * u, cy + -0.6433 * u)
      p.line_to(cx + -0.0897 * u, cy + -0.6433 * u)
      p.line_to(cx + -0.0897 * u, cy + -0.0897 * u)
      p.line_to(cx + -0.6433 * u, cy + -0.0897 * u)
      p.line_to(cx + -0.6433 * u, cy + -0.2513 * u)
      p.bezier_curve_to(cx + -0.6433 * u, cy + -0.2662 * u, cx + -0.6608 * u, cy + -0.2747 * u, cx + -0.6725 * u, cy + -0.2655 * u)
      p.line_to(cx + -0.9908 * u, cy + -0.0141 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.0069 * u, cx + -1 * u, cy + 0.0071 * u, cx + -0.9908 * u, cy + 0.0141 * u)
      p.line_to(cx + -0.6728 * u, cy + 0.2655 * u)
      p.bezier_curve_to(cx + -0.6611 * u, cy + 0.2747 * u, cx + -0.6436 * u, cy + 0.2665 * u, cx + -0.6436 * u, cy + 0.2513 * u)
      p.line_to(cx + -0.6436 * u, cy + 0.0899 * u)
      p.line_to(cx + -0.0899 * u, cy + 0.0899 * u)
      p.line_to(cx + -0.0899 * u, cy + 0.6436 * u)
      p.line_to(cx + -0.2515 * u, cy + 0.6436 * u)
      p.bezier_curve_to(cx + -0.2665 * u, cy + 0.6436 * u, cx + -0.275 * u, cy + 0.6611 * u, cx + -0.2657 * u, cy + 0.6728 * u)
      p.line_to(cx + -0.0143 * u, cy + 0.9908 * u)
      p.bezier_curve_to(cx + -0.0071 * u, cy + 1 * u, cx + 0.0069 * u, cy + 1 * u, cx + 0.0138 * u, cy + 0.9908 * u)
      p.line_to(cx + 0.2652 * u, cy + 0.6728 * u)
      p.bezier_curve_to(cx + 0.2745 * u, cy + 0.6611 * u, cx + 0.2662 * u, cy + 0.6436 * u, cx + 0.251 * u, cy + 0.6436 * u)
      p.line_to(cx + 0.0899 * u, cy + 0.6436 * u)
      p.line_to(cx + 0.0899 * u, cy + 0.0899 * u)
      p.line_to(cx + 0.6436 * u, cy + 0.0899 * u)
      p.line_to(cx + 0.6436 * u, cy + 0.2515 * u)
      p.bezier_curve_to(cx + 0.6436 * u, cy + 0.2665 * u, cx + 0.6611 * u, cy + 0.275 * u, cx + 0.6728 * u, cy + 0.2657 * u)
      p.line_to(cx + 0.9908 * u, cy + 0.0143 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.0071 * u, cx + 1 * u, cy + -0.0069 * u, cx + 0.991 * u, cy + -0.0141 * u)
      p.close_path()
      p.fill()
    }
    YhMenuFold => { // menu-fold
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9998 * u, cy + -0.6654 * u)
      p.line_to(cx + -1 * u, cy + -0.6678 * u)
      p.line_to(cx + -0.9997 * u, cy + -0.8344 * u)
      p.line_to(cx + 1 * u, cy + -0.8321 * u)
      p.line_to(cx + 0.9998 * u, cy + -0.6654 * u)
      p.close_path()
      p.move_to(cx + -0.8665 * u, cy + 0.4625 * u)
      p.line_to(cx + -0.3387 * u, cy + 0.0667 * u)
      p.line_to(cx + -0.3282 * u, cy + 0.0573 * u)
      p.line_to(cx + -0.3195 * u, cy + 0.0464 * u)
      p.line_to(cx + -0.3127 * u, cy + 0.0341 * u)
      p.line_to(cx + -0.308 * u, cy + 0.0208 * u)
      p.line_to(cx + -0.3057 * u, cy + 0.007 * u)
      p.line_to(cx + -0.3057 * u, cy + -0.007 * u)
      p.line_to(cx + -0.308 * u, cy + -0.0208 * u)
      p.line_to(cx + -0.3127 * u, cy + -0.0341 * u)
      p.line_to(cx + -0.3195 * u, cy + -0.0464 * u)
      p.line_to(cx + -0.3282 * u, cy + -0.0573 * u)
      p.line_to(cx + -0.3387 * u, cy + -0.0667 * u)
      p.line_to(cx + -0.8665 * u, cy + -0.4625 * u)
      p.line_to(cx + -0.8785 * u, cy + -0.47 * u)
      p.line_to(cx + -0.8917 * u, cy + -0.4753 * u)
      p.line_to(cx + -0.9055 * u, cy + -0.4784 * u)
      p.line_to(cx + -0.9197 * u, cy + -0.4791 * u)
      p.line_to(cx + -0.9337 * u, cy + -0.4773 * u)
      p.line_to(cx + -0.9473 * u, cy + -0.4732 * u)
      p.line_to(cx + -0.96 * u, cy + -0.4669 * u)
      p.line_to(cx + -0.9714 * u, cy + -0.4585 * u)
      p.line_to(cx + -0.9812 * u, cy + -0.4483 * u)
      p.line_to(cx + -0.9892 * u, cy + -0.4366 * u)
      p.line_to(cx + -0.995 * u, cy + -0.4236 * u)
      p.line_to(cx + -0.9986 * u, cy + -0.4099 * u)
      p.line_to(cx + -0.9998 * u, cy + -0.3958 * u)
      p.line_to(cx + -0.9998 * u, cy + 0.3958 * u)
      p.line_to(cx + -0.9986 * u, cy + 0.4099 * u)
      p.line_to(cx + -0.995 * u, cy + 0.4236 * u)
      p.line_to(cx + -0.9892 * u, cy + 0.4366 * u)
      p.line_to(cx + -0.9812 * u, cy + 0.4483 * u)
      p.line_to(cx + -0.9714 * u, cy + 0.4585 * u)
      p.line_to(cx + -0.96 * u, cy + 0.4669 * u)
      p.line_to(cx + -0.9473 * u, cy + 0.4732 * u)
      p.line_to(cx + -0.9337 * u, cy + 0.4773 * u)
      p.line_to(cx + -0.9197 * u, cy + 0.4791 * u)
      p.line_to(cx + -0.9055 * u, cy + 0.4784 * u)
      p.line_to(cx + -0.8917 * u, cy + 0.4753 * u)
      p.line_to(cx + -0.8785 * u, cy + 0.47 * u)
      p.line_to(cx + -0.8665 * u, cy + 0.4625 * u)
      p.close_path()
      p.move_to(cx + -0.8332 * u, cy + 0.2291 * u)
      p.line_to(cx + -0.8332 * u, cy + -0.2291 * u)
      p.line_to(cx + -0.5277 * u, cy + 0 * u)
      p.line_to(cx + -0.8332 * u, cy + 0.2291 * u)
      p.close_path()
      p.move_to(cx + 1 * u, cy + 0.0845 * u)
      p.line_to(cx + -0.0832 * u, cy + 0.0845 * u)
      p.line_to(cx + -0.0832 * u, cy + -0.0822 * u)
      p.line_to(cx + 1 * u, cy + -0.0822 * u)
      p.line_to(cx + 1 * u, cy + 0.0845 * u)
      p.close_path()
      p.move_to(cx + 0.9998 * u, cy + 0.8344 * u)
      p.line_to(cx + -1 * u, cy + 0.8321 * u)
      p.line_to(cx + -0.9997 * u, cy + 0.6654 * u)
      p.line_to(cx + 1 * u, cy + 0.6678 * u)
      p.line_to(cx + 0.9998 * u, cy + 0.8344 * u)
      p.close_path()
      p.fill()
    }
    YhMenuUnfold => { // menu-unfold
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.9998 * u, cy + -0.8344 * u)
      p.line_to(cx + 1 * u, cy + -0.8321 * u)
      p.line_to(cx + 0.9997 * u, cy + -0.6654 * u)
      p.line_to(cx + -1 * u, cy + -0.6678 * u)
      p.line_to(cx + -0.9998 * u, cy + -0.8344 * u)
      p.close_path()
      p.move_to(cx + 0.3387 * u, cy + -0.0667 * u)
      p.line_to(cx + 0.3282 * u, cy + -0.0573 * u)
      p.line_to(cx + 0.3195 * u, cy + -0.0464 * u)
      p.line_to(cx + 0.3127 * u, cy + -0.0341 * u)
      p.line_to(cx + 0.308 * u, cy + -0.0208 * u)
      p.line_to(cx + 0.3057 * u, cy + -0.007 * u)
      p.line_to(cx + 0.3057 * u, cy + 0.007 * u)
      p.line_to(cx + 0.308 * u, cy + 0.0208 * u)
      p.line_to(cx + 0.3127 * u, cy + 0.0341 * u)
      p.line_to(cx + 0.3195 * u, cy + 0.0464 * u)
      p.line_to(cx + 0.3282 * u, cy + 0.0573 * u)
      p.line_to(cx + 0.3387 * u, cy + 0.0667 * u)
      p.line_to(cx + 0.8665 * u, cy + 0.4625 * u)
      p.line_to(cx + 0.8785 * u, cy + 0.47 * u)
      p.line_to(cx + 0.8917 * u, cy + 0.4753 * u)
      p.line_to(cx + 0.9055 * u, cy + 0.4784 * u)
      p.line_to(cx + 0.9197 * u, cy + 0.4791 * u)
      p.line_to(cx + 0.9337 * u, cy + 0.4773 * u)
      p.line_to(cx + 0.9473 * u, cy + 0.4732 * u)
      p.line_to(cx + 0.96 * u, cy + 0.4669 * u)
      p.line_to(cx + 0.9714 * u, cy + 0.4585 * u)
      p.line_to(cx + 0.9812 * u, cy + 0.4483 * u)
      p.line_to(cx + 0.9892 * u, cy + 0.4366 * u)
      p.line_to(cx + 0.995 * u, cy + 0.4236 * u)
      p.line_to(cx + 0.9986 * u, cy + 0.4099 * u)
      p.line_to(cx + 0.9998 * u, cy + 0.3958 * u)
      p.line_to(cx + 0.9998 * u, cy + -0.3958 * u)
      p.line_to(cx + 0.9986 * u, cy + -0.4099 * u)
      p.line_to(cx + 0.995 * u, cy + -0.4236 * u)
      p.line_to(cx + 0.9892 * u, cy + -0.4366 * u)
      p.line_to(cx + 0.9812 * u, cy + -0.4483 * u)
      p.line_to(cx + 0.9714 * u, cy + -0.4585 * u)
      p.line_to(cx + 0.96 * u, cy + -0.4669 * u)
      p.line_to(cx + 0.9473 * u, cy + -0.4732 * u)
      p.line_to(cx + 0.9337 * u, cy + -0.4773 * u)
      p.line_to(cx + 0.9197 * u, cy + -0.4791 * u)
      p.line_to(cx + 0.9055 * u, cy + -0.4784 * u)
      p.line_to(cx + 0.8917 * u, cy + -0.4753 * u)
      p.line_to(cx + 0.8785 * u, cy + -0.47 * u)
      p.line_to(cx + 0.8665 * u, cy + -0.4625 * u)
      p.line_to(cx + 0.3387 * u, cy + -0.0667 * u)
      p.close_path()
      p.move_to(cx + 0.8332 * u, cy + -0.2291 * u)
      p.line_to(cx + 0.8332 * u, cy + 0.2291 * u)
      p.line_to(cx + 0.5277 * u, cy + 0 * u)
      p.line_to(cx + 0.8332 * u, cy + -0.2291 * u)
      p.close_path()
      p.move_to(cx + -1 * u, cy + -0.0845 * u)
      p.line_to(cx + 0.0832 * u, cy + -0.0845 * u)
      p.line_to(cx + 0.0832 * u, cy + 0.0822 * u)
      p.line_to(cx + -1 * u, cy + 0.0822 * u)
      p.line_to(cx + -1 * u, cy + -0.0845 * u)
      p.close_path()
      p.move_to(cx + -0.9998 * u, cy + 0.6654 * u)
      p.line_to(cx + 1 * u, cy + 0.6678 * u)
      p.line_to(cx + 0.9997 * u, cy + 0.8344 * u)
      p.line_to(cx + -1 * u, cy + 0.8321 * u)
      p.line_to(cx + -0.9998 * u, cy + 0.6654 * u)
      p.close_path()
      p.fill()
    }
    YhSortDesc => { // sort-descending
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.8932 * u, cy + -0.2125 * u)
      p.line_to(cx + 0.647 * u, cy + -0.9823 * u)
      p.bezier_curve_to(cx + 0.6437 * u, cy + -0.9929 * u, cx + 0.634 * u, cy + -1 * u, cx + 0.6228 * u, cy + -1 * u)
      p.line_to(cx + 0.4125 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.4014 * u, cy + -1 * u, cx + 0.3918 * u, cy + -0.9929 * u, cx + 0.3883 * u, cy + -0.9823 * u)
      p.line_to(cx + 0.1402 * u, cy + -0.2125 * u)
      p.bezier_curve_to(cx + 0.1394 * u, cy + -0.2101 * u, cx + 0.1389 * u, cy + -0.2073 * u, cx + 0.1389 * u, cy + -0.2046 * u)
      p.bezier_curve_to(cx + 0.1389 * u, cy + -0.1908 * u, cx + 0.1503 * u, cy + -0.1793 * u, cx + 0.1641 * u, cy + -0.1793 * u)
      p.line_to(cx + 0.3174 * u, cy + -0.1793 * u)
      p.bezier_curve_to(cx + 0.3288 * u, cy + -0.1793 * u, cx + 0.3386 * u, cy + -0.187 * u, cx + 0.3418 * u, cy + -0.1978 * u)
      p.line_to(cx + 0.3894 * u, cy + -0.3652 * u)
      p.line_to(cx + 0.6313 * u, cy + -0.3652 * u)
      p.line_to(cx + 0.6783 * u, cy + -0.1981 * u)
      p.bezier_curve_to(cx + 0.6813 * u, cy + -0.1872 * u, cx + 0.6913 * u, cy + -0.1796 * u, cx + 0.7027 * u, cy + -0.1796 * u)
      p.line_to(cx + 0.869 * u, cy + -0.1796 * u)
      p.bezier_curve_to(cx + 0.8717 * u, cy + -0.1796 * u, cx + 0.8742 * u, cy + -0.1799 * u, cx + 0.8766 * u, cy + -0.1807 * u)
      p.bezier_curve_to(cx + 0.8832 * u, cy + -0.1829 * u, cx + 0.8883 * u, cy + -0.1872 * u, cx + 0.8916 * u, cy + -0.1932 * u)
      p.bezier_curve_to(cx + 0.8946 * u, cy + -0.1992 * u, cx + 0.8951 * u, cy + -0.206 * u, cx + 0.8932 * u, cy + -0.2125 * u)
      p.close_path()
      p.move_to(cx + 0.4141 * u, cy + -0.5068 * u)
      p.line_to(cx + 0.5033 * u, cy + -0.8245 * u)
      p.line_to(cx + 0.5204 * u, cy + -0.8245 * u)
      p.line_to(cx + 0.6076 * u, cy + -0.5068 * u)
      p.line_to(cx + 0.4141 * u, cy + -0.5068 * u)
      p.close_path()
      p.move_to(cx + 0.8041 * u, cy + 0.8326 * u)
      p.line_to(cx + 0.4519 * u, cy + 0.8326 * u)
      p.line_to(cx + 0.4519 * u, cy + 0.8315 * u)
      p.line_to(cx + 0.8122 * u, cy + 0.3182 * u)
      p.bezier_curve_to(cx + 0.8152 * u, cy + 0.3139 * u, cx + 0.8168 * u, cy + 0.309 * u, cx + 0.8168 * u, cy + 0.3035 * u)
      p.line_to(cx + 0.8168 * u, cy + 0.2046 * u)
      p.bezier_curve_to(cx + 0.8168 * u, cy + 0.1908 * u, cx + 0.8054 * u, cy + 0.1793 * u, cx + 0.7916 * u, cy + 0.1793 * u)
      p.line_to(cx + 0.2372 * u, cy + 0.1793 * u)
      p.bezier_curve_to(cx + 0.2234 * u, cy + 0.1793 * u, cx + 0.212 * u, cy + 0.1908 * u, cx + 0.212 * u, cy + 0.2046 * u)
      p.line_to(cx + 0.212 * u, cy + 0.3215 * u)
      p.bezier_curve_to(cx + 0.212 * u, cy + 0.3353 * u, cx + 0.2234 * u, cy + 0.3467 * u, cx + 0.2372 * u, cy + 0.3467 * u)
      p.line_to(cx + 0.5704 * u, cy + 0.3467 * u)
      p.line_to(cx + 0.5704 * u, cy + 0.3478 * u)
      p.line_to(cx + 0.2087 * u, cy + 0.8611 * u)
      p.bezier_curve_to(cx + 0.2057 * u, cy + 0.8655 * u, cx + 0.2041 * u, cy + 0.8704 * u, cx + 0.2041 * u, cy + 0.8758 * u)
      p.line_to(cx + 0.2041 * u, cy + 0.9747 * u)
      p.bezier_curve_to(cx + 0.2041 * u, cy + 0.9886 * u, cx + 0.2155 * u, cy + 1 * u, cx + 0.2293 * u, cy + 1 * u)
      p.line_to(cx + 0.8038 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.8177 * u, cy + 1 * u, cx + 0.8291 * u, cy + 0.9886 * u, cx + 0.8291 * u, cy + 0.9747 * u)
      p.line_to(cx + 0.8291 * u, cy + 0.8579 * u)
      p.bezier_curve_to(cx + 0.8293 * u, cy + 0.844 * u, cx + 0.8179 * u, cy + 0.8326 * u, cx + 0.8041 * u, cy + 0.8326 * u)
      p.close_path()
      p.move_to(cx + -0.5451 * u, cy + -0.9372 * u)
      p.bezier_curve_to(cx + -0.5538 * u, cy + -0.9484 * u, cx + -0.5707 * u, cy + -0.9484 * u, cx + -0.5793 * u, cy + -0.9372 * u)
      p.line_to(cx + -0.8837 * u, cy + -0.5516 * u)
      p.bezier_curve_to(cx + -0.8951 * u, cy + -0.5372 * u, cx + -0.8848 * u, cy + -0.5163 * u, cx + -0.8666 * u, cy + -0.5163 * u)
      p.line_to(cx + -0.6601 * u, cy + -0.5163 * u)
      p.line_to(cx + -0.6601 * u, cy + 0.9239 * u)
      p.bezier_curve_to(cx + -0.6601 * u, cy + 0.9359 * u, cx + -0.6503 * u, cy + 0.9457 * u, cx + -0.6383 * u, cy + 0.9457 * u)
      p.line_to(cx + -0.4861 * u, cy + 0.9457 * u)
      p.bezier_curve_to(cx + -0.4742 * u, cy + 0.9457 * u, cx + -0.4644 * u, cy + 0.9359 * u, cx + -0.4644 * u, cy + 0.9239 * u)
      p.line_to(cx + -0.4644 * u, cy + -0.5163 * u)
      p.line_to(cx + -0.2579 * u, cy + -0.5163 * u)
      p.bezier_curve_to(cx + -0.2397 * u, cy + -0.5163 * u, cx + -0.2293 * u, cy + -0.5375 * u, cx + -0.2408 * u, cy + -0.5516 * u)
      p.line_to(cx + -0.5451 * u, cy + -0.9372 * u)
      p.close_path()
      p.fill()
    }
    YhSortAsc => { // sort-ascending
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.8932 * u, cy + -0.2125 * u)
      p.line_to(cx + 0.647 * u, cy + -0.9823 * u)
      p.bezier_curve_to(cx + 0.6437 * u, cy + -0.9929 * u, cx + 0.634 * u, cy + -1 * u, cx + 0.6228 * u, cy + -1 * u)
      p.line_to(cx + 0.4125 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.4014 * u, cy + -1 * u, cx + 0.3918 * u, cy + -0.9929 * u, cx + 0.3883 * u, cy + -0.9823 * u)
      p.line_to(cx + 0.1402 * u, cy + -0.2125 * u)
      p.bezier_curve_to(cx + 0.1394 * u, cy + -0.2101 * u, cx + 0.1389 * u, cy + -0.2073 * u, cx + 0.1389 * u, cy + -0.2046 * u)
      p.bezier_curve_to(cx + 0.1389 * u, cy + -0.1908 * u, cx + 0.1503 * u, cy + -0.1793 * u, cx + 0.1641 * u, cy + -0.1793 * u)
      p.line_to(cx + 0.3174 * u, cy + -0.1793 * u)
      p.bezier_curve_to(cx + 0.3288 * u, cy + -0.1793 * u, cx + 0.3386 * u, cy + -0.187 * u, cx + 0.3418 * u, cy + -0.1978 * u)
      p.line_to(cx + 0.3894 * u, cy + -0.3652 * u)
      p.line_to(cx + 0.6313 * u, cy + -0.3652 * u)
      p.line_to(cx + 0.6783 * u, cy + -0.1981 * u)
      p.bezier_curve_to(cx + 0.6813 * u, cy + -0.1872 * u, cx + 0.6913 * u, cy + -0.1796 * u, cx + 0.7027 * u, cy + -0.1796 * u)
      p.line_to(cx + 0.869 * u, cy + -0.1796 * u)
      p.bezier_curve_to(cx + 0.8717 * u, cy + -0.1796 * u, cx + 0.8742 * u, cy + -0.1799 * u, cx + 0.8766 * u, cy + -0.1807 * u)
      p.bezier_curve_to(cx + 0.8832 * u, cy + -0.1829 * u, cx + 0.8883 * u, cy + -0.1872 * u, cx + 0.8916 * u, cy + -0.1932 * u)
      p.bezier_curve_to(cx + 0.8946 * u, cy + -0.1992 * u, cx + 0.8951 * u, cy + -0.206 * u, cx + 0.8932 * u, cy + -0.2125 * u)
      p.close_path()
      p.move_to(cx + 0.4141 * u, cy + -0.5068 * u)
      p.line_to(cx + 0.5033 * u, cy + -0.8245 * u)
      p.line_to(cx + 0.5204 * u, cy + -0.8245 * u)
      p.line_to(cx + 0.6076 * u, cy + -0.5068 * u)
      p.line_to(cx + 0.4141 * u, cy + -0.5068 * u)
      p.close_path()
      p.move_to(cx + 0.8041 * u, cy + 0.8326 * u)
      p.line_to(cx + 0.4519 * u, cy + 0.8326 * u)
      p.line_to(cx + 0.4519 * u, cy + 0.8315 * u)
      p.line_to(cx + 0.8122 * u, cy + 0.3182 * u)
      p.bezier_curve_to(cx + 0.8152 * u, cy + 0.3139 * u, cx + 0.8168 * u, cy + 0.309 * u, cx + 0.8168 * u, cy + 0.3035 * u)
      p.line_to(cx + 0.8168 * u, cy + 0.2046 * u)
      p.bezier_curve_to(cx + 0.8168 * u, cy + 0.1908 * u, cx + 0.8054 * u, cy + 0.1793 * u, cx + 0.7916 * u, cy + 0.1793 * u)
      p.line_to(cx + 0.2372 * u, cy + 0.1793 * u)
      p.bezier_curve_to(cx + 0.2234 * u, cy + 0.1793 * u, cx + 0.212 * u, cy + 0.1908 * u, cx + 0.212 * u, cy + 0.2046 * u)
      p.line_to(cx + 0.212 * u, cy + 0.3215 * u)
      p.bezier_curve_to(cx + 0.212 * u, cy + 0.3353 * u, cx + 0.2234 * u, cy + 0.3467 * u, cx + 0.2372 * u, cy + 0.3467 * u)
      p.line_to(cx + 0.5704 * u, cy + 0.3467 * u)
      p.line_to(cx + 0.5704 * u, cy + 0.3478 * u)
      p.line_to(cx + 0.2087 * u, cy + 0.8611 * u)
      p.bezier_curve_to(cx + 0.2057 * u, cy + 0.8655 * u, cx + 0.2041 * u, cy + 0.8704 * u, cx + 0.2041 * u, cy + 0.8758 * u)
      p.line_to(cx + 0.2041 * u, cy + 0.9747 * u)
      p.bezier_curve_to(cx + 0.2041 * u, cy + 0.9886 * u, cx + 0.2155 * u, cy + 1 * u, cx + 0.2293 * u, cy + 1 * u)
      p.line_to(cx + 0.8038 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.8177 * u, cy + 1 * u, cx + 0.8291 * u, cy + 0.9886 * u, cx + 0.8291 * u, cy + 0.9747 * u)
      p.line_to(cx + 0.8291 * u, cy + 0.8579 * u)
      p.bezier_curve_to(cx + 0.8293 * u, cy + 0.844 * u, cx + 0.8179 * u, cy + 0.8326 * u, cx + 0.8041 * u, cy + 0.8326 * u)
      p.close_path()
      p.move_to(cx + -0.2579 * u, cy + 0.5163 * u)
      p.line_to(cx + -0.4644 * u, cy + 0.5163 * u)
      p.line_to(cx + -0.4644 * u, cy + -0.9239 * u)
      p.bezier_curve_to(cx + -0.4644 * u, cy + -0.9359 * u, cx + -0.4742 * u, cy + -0.9457 * u, cx + -0.4861 * u, cy + -0.9457 * u)
      p.line_to(cx + -0.6383 * u, cy + -0.9457 * u)
      p.bezier_curve_to(cx + -0.6503 * u, cy + -0.9457 * u, cx + -0.6601 * u, cy + -0.9359 * u, cx + -0.6601 * u, cy + -0.9239 * u)
      p.line_to(cx + -0.6601 * u, cy + 0.5163 * u)
      p.line_to(cx + -0.8666 * u, cy + 0.5163 * u)
      p.bezier_curve_to(cx + -0.8848 * u, cy + 0.5163 * u, cx + -0.8951 * u, cy + 0.5375 * u, cx + -0.8837 * u, cy + 0.5516 * u)
      p.line_to(cx + -0.5793 * u, cy + 0.9372 * u)
      p.bezier_curve_to(cx + -0.5707 * u, cy + 0.9484 * u, cx + -0.5538 * u, cy + 0.9484 * u, cx + -0.5451 * u, cy + 0.9372 * u)
      p.line_to(cx + -0.2408 * u, cy + 0.5516 * u)
      p.bezier_curve_to(cx + -0.2296 * u, cy + 0.5375 * u, cx + -0.2397 * u, cy + 0.5163 * u, cx + -0.2579 * u, cy + 0.5163 * u)
      p.close_path()
      p.fill()
    }
    YhFile => { // file-fill
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.7647 * u, cy + -0.4984 * u)
      p.bezier_curve_to(cx + 0.7781 * u, cy + -0.485 * u, cx + 0.7857 * u, cy + -0.467 * u, cx + 0.7857 * u, cy + -0.448 * u)
      p.line_to(cx + 0.7857 * u, cy + 0.9286 * u)
      p.bezier_curve_to(cx + 0.7857 * u, cy + 0.9681 * u, cx + 0.7538 * u, cy + 1 * u, cx + 0.7143 * u, cy + 1 * u)
      p.line_to(cx + -0.7143 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.7538 * u, cy + 1 * u, cx + -0.7857 * u, cy + 0.9681 * u, cx + -0.7857 * u, cy + 0.9286 * u)
      p.line_to(cx + -0.7857 * u, cy + -0.9286 * u)
      p.bezier_curve_to(cx + -0.7857 * u, cy + -0.9681 * u, cx + -0.7538 * u, cy + -1 * u, cx + -0.7143 * u, cy + -1 * u)
      p.line_to(cx + 0.2337 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.2527 * u, cy + -1 * u, cx + 0.271 * u, cy + -0.9924 * u, cx + 0.2844 * u, cy + -0.979 * u)
      p.line_to(cx + 0.7647 * u, cy + -0.4984 * u)
      p.close_path()
      p.move_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.8353 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.close_path()
      p.fill()
    }
    YhFilePdf => { // file-pdf
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.0431 * u, cy + 0.1393 * u)
      p.line_to(cx + 0.0437 * u, cy + 0.1362 * u)
      p.bezier_curve_to(cx + 0.0567 * u, cy + 0.0828 * u, cx + 0.073 * u, cy + 0.0163 * u, cx + 0.0603 * u, cy + -0.044 * u)
      p.bezier_curve_to(cx + 0.0518 * u, cy + -0.0915 * u, cx + 0.0167 * u, cy + -0.11 * u, cx + -0.0132 * u, cy + -0.1114 * u)
      p.bezier_curve_to(cx + -0.0484 * u, cy + -0.1129 * u, cx + -0.0799 * u, cy + -0.0929 * u, cx + -0.0877 * u, cy + -0.0636 * u)
      p.bezier_curve_to(cx + -0.1025 * u, cy + -0.01 * u, cx + -0.0893 * u, cy + 0.0632 * u, cx + -0.0652 * u, cy + 0.1565 * u)
      p.bezier_curve_to(cx + -0.0955 * u, cy + 0.2288 * u, cx + -0.144 * u, cy + 0.3339 * u, cx + -0.1795 * u, cy + 0.3964 * u)
      p.bezier_curve_to(cx + -0.2455 * u, cy + 0.4306 * u, cx + -0.3342 * u, cy + 0.4833 * u, cx + -0.3473 * u, cy + 0.5498 * u)
      p.bezier_curve_to(cx + -0.35 * u, cy + 0.5621 * u, cx + -0.3469 * u, cy + 0.5777 * u, cx + -0.3395 * u, cy + 0.5917 * u)
      p.bezier_curve_to(cx + -0.3312 * u, cy + 0.6074 * u, cx + -0.3181 * u, cy + 0.6194 * u, cx + -0.3027 * u, cy + 0.6252 * u)
      p.bezier_curve_to(cx + -0.296 * u, cy + 0.6277 * u, cx + -0.2879 * u, cy + 0.6297 * u, cx + -0.2786 * u, cy + 0.6297 * u)
      p.bezier_curve_to(cx + -0.2393 * u, cy + 0.6297 * u, cx + -0.1757 * u, cy + 0.598 * u, cx + -0.0908 * u, cy + 0.4525 * u)
      p.bezier_curve_to(cx + -0.0779 * u, cy + 0.4482 * u, cx + -0.0645 * u, cy + 0.4437 * u, cx + -0.0516 * u, cy + 0.4393 * u)
      p.bezier_curve_to(cx + 0.0092 * u, cy + 0.4188 * u, cx + 0.0721 * u, cy + 0.3973 * u, cx + 0.129 * u, cy + 0.3877 * u)
      p.bezier_curve_to(cx + 0.192 * u, cy + 0.4214 * u, cx + 0.2636 * u, cy + 0.4431 * u, cx + 0.3123 * u, cy + 0.4431 * u)
      p.bezier_curve_to(cx + 0.3605 * u, cy + 0.4431 * u, cx + 0.3795 * u, cy + 0.4145 * u, cx + 0.3866 * u, cy + 0.3973 * u)
      p.bezier_curve_to(cx + 0.3991 * u, cy + 0.3672 * u, cx + 0.3931 * u, cy + 0.3292 * u, cx + 0.3728 * u, cy + 0.3089 * u)
      p.bezier_curve_to(cx + 0.3433 * u, cy + 0.2799 * u, cx + 0.2717 * u, cy + 0.2723 * u, cx + 0.16 * u, cy + 0.2862 * u)
      p.bezier_curve_to(cx + 0.1051 * u, cy + 0.2527 * u, cx + 0.0692 * u, cy + 0.2071 * u, cx + 0.0431 * u, cy + 0.1393 * u)
      p.close_path()
      p.move_to(cx + -0.2018 * u, cy + 0.4783 * u)
      p.bezier_curve_to(cx + -0.2328 * u, cy + 0.5234 * u, cx + -0.2563 * u, cy + 0.546 * u, cx + -0.269 * u, cy + 0.5558 * u)
      p.bezier_curve_to(cx + -0.254 * u, cy + 0.5283 * u, cx + -0.2248 * u, cy + 0.4993 * u, cx + -0.2018 * u, cy + 0.4783 * u)
      p.close_path()
      p.move_to(cx + -0.0063 * u, cy + -0.0473 * u)
      p.bezier_curve_to(cx + 0.0054 * u, cy + -0.0275 * u, cx + 0.0038 * u, cy + 0.0326 * u, cx + -0.0051 * u, cy + 0.0629 * u)
      p.bezier_curve_to(cx + -0.0161 * u, cy + 0.0185 * u, cx + -0.0176 * u, cy + -0.0444 * u, cx + -0.0112 * u, cy + -0.0518 * u)
      p.bezier_curve_to(cx + -0.0094 * u, cy + -0.0516 * u, cx + -0.0078 * u, cy + -0.0502 * u, cx + -0.0063 * u, cy + -0.0473 * u)
      p.close_path()
      p.move_to(cx + -0.0098 * u, cy + 0.2217 * u)
      p.bezier_curve_to(cx + 0.0141 * u, cy + 0.2629 * u, cx + 0.0442 * u, cy + 0.2984 * u, cx + 0.0775 * u, cy + 0.3248 * u)
      p.bezier_curve_to(cx + 0.0292 * u, cy + 0.3357 * u, cx + -0.0147 * u, cy + 0.3538 * u, cx + -0.054 * u, cy + 0.3699 * u)
      p.bezier_curve_to(cx + -0.0634 * u, cy + 0.3737 * u, cx + -0.0725 * u, cy + 0.3775 * u, cx + -0.0815 * u, cy + 0.381 * u)
      p.bezier_curve_to(cx + -0.0518 * u, cy + 0.3272 * u, cx + -0.027 * u, cy + 0.2663 * u, cx + -0.0098 * u, cy + 0.2217 * u)
      p.close_path()
      p.move_to(cx + 0.3375 * u, cy + 0.3679 * u)
      p.bezier_curve_to(cx + 0.3377 * u, cy + 0.3683 * u, cx + 0.3379 * u, cy + 0.369 * u, cx + 0.3366 * u, cy + 0.3699 * u)
      p.line_to(cx + 0.3362 * u, cy + 0.3699 * u)
      p.line_to(cx + 0.3357 * u, cy + 0.3705 * u)
      p.bezier_curve_to(cx + 0.3339 * u, cy + 0.3717 * u, cx + 0.3156 * u, cy + 0.3824 * u, cx + 0.2368 * u, cy + 0.3513 * u)
      p.bezier_curve_to(cx + 0.3275 * u, cy + 0.3471 * u, cx + 0.3373 * u, cy + 0.3676 * u, cx + 0.3375 * u, cy + 0.3679 * u)
      p.close_path()
      p.move_to(cx + 0.7647 * u, cy + -0.4987 * u)
      p.line_to(cx + 0.2844 * u, cy + -0.979 * u)
      p.bezier_curve_to(cx + 0.271 * u, cy + -0.9924 * u, cx + 0.2529 * u, cy + -1 * u, cx + 0.2339 * u, cy + -1 * u)
      p.line_to(cx + -0.7143 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.7538 * u, cy + -1 * u, cx + -0.7857 * u, cy + -0.9681 * u, cx + -0.7857 * u, cy + -0.9286 * u)
      p.line_to(cx + -0.7857 * u, cy + 0.9286 * u)
      p.bezier_curve_to(cx + -0.7857 * u, cy + 0.9681 * u, cx + -0.7538 * u, cy + 1 * u, cx + -0.7143 * u, cy + 1 * u)
      p.line_to(cx + 0.7143 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.7538 * u, cy + 1 * u, cx + 0.7857 * u, cy + 0.9681 * u, cx + 0.7857 * u, cy + 0.9286 * u)
      p.line_to(cx + 0.7857 * u, cy + -0.448 * u)
      p.bezier_curve_to(cx + 0.7857 * u, cy + -0.467 * u, cx + 0.7781 * u, cy + -0.4853 * u, cx + 0.7647 * u, cy + -0.4987 * u)
      p.close_path()
      p.move_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.8353 * u)
      p.line_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.close_path()
      p.move_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.0491 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.0491 * u, cy + -0.3571 * u)
      p.bezier_curve_to(cx + 0.0491 * u, cy + -0.3054 * u, cx + 0.0911 * u, cy + -0.2634 * u, cx + 0.1429 * u, cy + -0.2634 * u)
      p.line_to(cx + 0.625 * u, cy + -0.2634 * u)
      p.line_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.close_path()
      p.fill()
    }
    YhFileWord => { // file-word
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.7647 * u, cy + -0.4987 * u)
      p.line_to(cx + 0.2844 * u, cy + -0.979 * u)
      p.bezier_curve_to(cx + 0.271 * u, cy + -0.9924 * u, cx + 0.2529 * u, cy + -1 * u, cx + 0.2339 * u, cy + -1 * u)
      p.line_to(cx + -0.7143 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.7538 * u, cy + -1 * u, cx + -0.7857 * u, cy + -0.9681 * u, cx + -0.7857 * u, cy + -0.9286 * u)
      p.line_to(cx + -0.7857 * u, cy + 0.9286 * u)
      p.bezier_curve_to(cx + -0.7857 * u, cy + 0.9681 * u, cx + -0.7538 * u, cy + 1 * u, cx + -0.7143 * u, cy + 1 * u)
      p.line_to(cx + 0.7143 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.7538 * u, cy + 1 * u, cx + 0.7857 * u, cy + 0.9681 * u, cx + 0.7857 * u, cy + 0.9286 * u)
      p.line_to(cx + 0.7857 * u, cy + -0.448 * u)
      p.bezier_curve_to(cx + 0.7857 * u, cy + -0.467 * u, cx + 0.7781 * u, cy + -0.4853 * u, cx + 0.7647 * u, cy + -0.4987 * u)
      p.close_path()
      p.move_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.8353 * u)
      p.line_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.close_path()
      p.move_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.0491 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.0491 * u, cy + -0.3571 * u)
      p.bezier_curve_to(cx + 0.0491 * u, cy + -0.3054 * u, cx + 0.0911 * u, cy + -0.2634 * u, cx + 0.1429 * u, cy + -0.2634 * u)
      p.line_to(cx + 0.625 * u, cy + -0.2634 * u)
      p.line_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.close_path()
      p.move_to(cx + 0.0359 * u, cy + -0.0893 * u)
      p.line_to(cx + -0.0359 * u, cy + -0.0893 * u)
      p.bezier_curve_to(cx + -0.0482 * u, cy + -0.0893 * u, cx + -0.0589 * u, cy + -0.081 * u, cx + -0.0618 * u, cy + -0.069 * u)
      p.line_to(cx + -0.1728 * u, cy + 0.375 * u)
      p.line_to(cx + -0.2757 * u, cy + -0.0685 * u)
      p.bezier_curve_to(cx + -0.2786 * u, cy + -0.0806 * u, cx + -0.2893 * u, cy + -0.0893 * u, cx + -0.3018 * u, cy + -0.0893 * u)
      p.line_to(cx + -0.3808 * u, cy + -0.0893 * u)
      p.bezier_curve_to(cx + -0.3833 * u, cy + -0.0893 * u, cx + -0.3855 * u, cy + -0.0891 * u, cx + -0.3877 * u, cy + -0.0884 * u)
      p.bezier_curve_to(cx + -0.402 * u, cy + -0.0846 * u, cx + -0.4105 * u, cy + -0.0699 * u, cx + -0.4067 * u, cy + -0.0556 * u)
      p.line_to(cx + -0.2411 * u, cy + 0.5605 * u)
      p.bezier_curve_to(cx + -0.2379 * u, cy + 0.5721 * u, cx + -0.2272 * u, cy + 0.5804 * u, cx + -0.2152 * u, cy + 0.5804 * u)
      p.line_to(cx + -0.1437 * u, cy + 0.5804 * u)
      p.bezier_curve_to(cx + -0.1317 * u, cy + 0.5804 * u, cx + -0.121 * u, cy + 0.5723 * u, cx + -0.1179 * u, cy + 0.5605 * u)
      p.line_to(cx + 0 * u, cy + 0.1208 * u)
      p.line_to(cx + 0.1179 * u, cy + 0.5605 * u)
      p.bezier_curve_to(cx + 0.121 * u, cy + 0.5721 * u, cx + 0.1317 * u, cy + 0.5804 * u, cx + 0.1437 * u, cy + 0.5804 * u)
      p.line_to(cx + 0.2147 * u, cy + 0.5804 * u)
      p.bezier_curve_to(cx + 0.2268 * u, cy + 0.5804 * u, cx + 0.2375 * u, cy + 0.5723 * u, cx + 0.2406 * u, cy + 0.5605 * u)
      p.line_to(cx + 0.4067 * u, cy + -0.0556 * u)
      p.bezier_curve_to(cx + 0.4074 * u, cy + -0.0578 * u, cx + 0.4076 * u, cy + -0.0603 * u, cx + 0.4076 * u, cy + -0.0625 * u)
      p.bezier_curve_to(cx + 0.4076 * u, cy + -0.0772 * u, cx + 0.3955 * u, cy + -0.0893 * u, cx + 0.3808 * u, cy + -0.0893 * u)
      p.line_to(cx + 0.3013 * u, cy + -0.0893 * u)
      p.bezier_curve_to(cx + 0.2888 * u, cy + -0.0893 * u, cx + 0.2781 * u, cy + -0.0806 * u, cx + 0.2752 * u, cy + -0.0685 * u)
      p.line_to(cx + 0.173 * u, cy + 0.3759 * u)
      p.line_to(cx + 0.0618 * u, cy + -0.069 * u)
      p.bezier_curve_to(cx + 0.0589 * u, cy + -0.081 * u, cx + 0.0482 * u, cy + -0.0893 * u, cx + 0.0359 * u, cy + -0.0893 * u)
      p.close_path()
      p.fill()
    }
    YhFileExcel => { // file-excel
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.7647 * u, cy + -0.4987 * u)
      p.line_to(cx + 0.2844 * u, cy + -0.979 * u)
      p.bezier_curve_to(cx + 0.271 * u, cy + -0.9924 * u, cx + 0.2529 * u, cy + -1 * u, cx + 0.2339 * u, cy + -1 * u)
      p.line_to(cx + -0.7143 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.7538 * u, cy + -1 * u, cx + -0.7857 * u, cy + -0.9681 * u, cx + -0.7857 * u, cy + -0.9286 * u)
      p.line_to(cx + -0.7857 * u, cy + 0.9286 * u)
      p.bezier_curve_to(cx + -0.7857 * u, cy + 0.9681 * u, cx + -0.7538 * u, cy + 1 * u, cx + -0.7143 * u, cy + 1 * u)
      p.line_to(cx + 0.7143 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.7538 * u, cy + 1 * u, cx + 0.7857 * u, cy + 0.9681 * u, cx + 0.7857 * u, cy + 0.9286 * u)
      p.line_to(cx + 0.7857 * u, cy + -0.448 * u)
      p.bezier_curve_to(cx + 0.7857 * u, cy + -0.467 * u, cx + 0.7781 * u, cy + -0.4853 * u, cx + 0.7647 * u, cy + -0.4987 * u)
      p.close_path()
      p.move_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.8353 * u)
      p.line_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.close_path()
      p.move_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.0491 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.0491 * u, cy + -0.3571 * u)
      p.bezier_curve_to(cx + 0.0491 * u, cy + -0.3054 * u, cx + 0.0911 * u, cy + -0.2634 * u, cx + 0.1429 * u, cy + -0.2634 * u)
      p.line_to(cx + 0.625 * u, cy + -0.2634 * u)
      p.line_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.close_path()
      p.move_to(cx + 0.0047 * u, cy + 0.152 * u)
      p.line_to(cx + -0.1333 * u, cy + -0.0766 * u)
      p.bezier_curve_to(cx + -0.1382 * u, cy + -0.0846 * u, cx + -0.1469 * u, cy + -0.0895 * u, cx + -0.1563 * u, cy + -0.0895 * u)
      p.line_to(cx + -0.242 * u, cy + -0.0895 * u)
      p.bezier_curve_to(cx + -0.2471 * u, cy + -0.0895 * u, cx + -0.252 * u, cy + -0.0882 * u, cx + -0.2563 * u, cy + -0.0853 * u)
      p.bezier_curve_to(cx + -0.2688 * u, cy + -0.0775 * u, cx + -0.2725 * u, cy + -0.0609 * u, cx + -0.2645 * u, cy + -0.0482 * u)
      p.line_to(cx + -0.0808 * u, cy + 0.2429 * u)
      p.line_to(cx + -0.267 * u, cy + 0.5393 * u)
      p.bezier_curve_to(cx + -0.2696 * u, cy + 0.5435 * u, cx + -0.271 * u, cy + 0.5484 * u, cx + -0.271 * u, cy + 0.5536 * u)
      p.bezier_curve_to(cx + -0.271 * u, cy + 0.5683 * u, cx + -0.2589 * u, cy + 0.5804 * u, cx + -0.2442 * u, cy + 0.5804 * u)
      p.line_to(cx + -0.1672 * u, cy + 0.5804 * u)
      p.bezier_curve_to(cx + -0.1578 * u, cy + 0.5804 * u, cx + -0.1493 * u, cy + 0.5754 * u, cx + -0.1444 * u, cy + 0.5676 * u)
      p.line_to(cx + -0.0045 * u, cy + 0.3411 * u)
      p.line_to(cx + 0.1346 * u, cy + 0.5674 * u)
      p.bezier_curve_to(cx + 0.1395 * u, cy + 0.5754 * u, cx + 0.1482 * u, cy + 0.5801 * u, cx + 0.1574 * u, cy + 0.5801 * u)
      p.line_to(cx + 0.2411 * u, cy + 0.5801 * u)
      p.bezier_curve_to(cx + 0.2462 * u, cy + 0.5801 * u, cx + 0.2511 * u, cy + 0.5786 * u, cx + 0.2556 * u, cy + 0.5759 * u)
      p.bezier_curve_to(cx + 0.2681 * u, cy + 0.5679 * u, cx + 0.2717 * u, cy + 0.5513 * u, cx + 0.2636 * u, cy + 0.5388 * u)
      p.line_to(cx + 0.0761 * u, cy + 0.2478 * u)
      p.line_to(cx + 0.2665 * u, cy + -0.048 * u)
      p.bezier_curve_to(cx + 0.2692 * u, cy + -0.0522 * u, cx + 0.2708 * u, cy + -0.0574 * u, cx + 0.2708 * u, cy + -0.0625 * u)
      p.bezier_curve_to(cx + 0.2708 * u, cy + -0.0772 * u, cx + 0.2587 * u, cy + -0.0893 * u, cx + 0.244 * u, cy + -0.0893 * u)
      p.line_to(cx + 0.1643 * u, cy + -0.0893 * u)
      p.bezier_curve_to(cx + 0.1549 * u, cy + -0.0893 * u, cx + 0.1462 * u, cy + -0.0844 * u, cx + 0.1413 * u, cy + -0.0763 * u)
      p.line_to(cx + 0.0047 * u, cy + 0.152 * u)
      p.close_path()
      p.fill()
    }
    YhFilePpt => { // file-ppt
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.1964 * u, cy + -0.0804 * u)
      p.bezier_curve_to(cx + -0.2063 * u, cy + -0.0804 * u, cx + -0.2143 * u, cy + -0.0723 * u, cx + -0.2143 * u, cy + -0.0625 * u)
      p.line_to(cx + -0.2143 * u, cy + 0.5536 * u)
      p.bezier_curve_to(cx + -0.2143 * u, cy + 0.5634 * u, cx + -0.2063 * u, cy + 0.5714 * u, cx + -0.1964 * u, cy + 0.5714 * u)
      p.line_to(cx + -0.1239 * u, cy + 0.5714 * u)
      p.bezier_curve_to(cx + -0.1141 * u, cy + 0.5714 * u, cx + -0.106 * u, cy + 0.5634 * u, cx + -0.106 * u, cy + 0.5536 * u)
      p.line_to(cx + -0.106 * u, cy + 0.3404 * u)
      p.line_to(cx + 0.0353 * u, cy + 0.3404 * u)
      p.bezier_curve_to(cx + 0.1679 * u, cy + 0.3404 * u, cx + 0.25 * u, cy + 0.2536 * u, cx + 0.25 * u, cy + 0.1304 * u)
      p.bezier_curve_to(cx + 0.25 * u, cy + 0.0087 * u, cx + 0.169 * u, cy + -0.0801 * u, cx + 0.0357 * u, cy + -0.0801 * u)
      p.line_to(cx + -0.1964 * u, cy + -0.0801 * u)
      p.close_path()
      p.move_to(cx + 0.1397 * u, cy + 0.1301 * u)
      p.bezier_curve_to(cx + 0.1397 * u, cy + 0.227 * u, cx + 0.0806 * u, cy + 0.2513 * u, cx + -0.0192 * u, cy + 0.2513 * u)
      p.line_to(cx + -0.106 * u, cy + 0.2513 * u)
      p.line_to(cx + -0.106 * u, cy + 0.0094 * u)
      p.line_to(cx + 0.0194 * u, cy + 0.0094 * u)
      p.bezier_curve_to(cx + 0.0949 * u, cy + 0.0094 * u, cx + 0.1397 * u, cy + 0.0533 * u, cx + 0.1397 * u, cy + 0.1301 * u)
      p.close_path()
      p.move_to(cx + 0.7647 * u, cy + -0.4987 * u)
      p.line_to(cx + 0.2844 * u, cy + -0.979 * u)
      p.bezier_curve_to(cx + 0.271 * u, cy + -0.9924 * u, cx + 0.2529 * u, cy + -1 * u, cx + 0.2339 * u, cy + -1 * u)
      p.line_to(cx + -0.7143 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.7538 * u, cy + -1 * u, cx + -0.7857 * u, cy + -0.9681 * u, cx + -0.7857 * u, cy + -0.9286 * u)
      p.line_to(cx + -0.7857 * u, cy + 0.9286 * u)
      p.bezier_curve_to(cx + -0.7857 * u, cy + 0.9681 * u, cx + -0.7538 * u, cy + 1 * u, cx + -0.7143 * u, cy + 1 * u)
      p.line_to(cx + 0.7143 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.7538 * u, cy + 1 * u, cx + 0.7857 * u, cy + 0.9681 * u, cx + 0.7857 * u, cy + 0.9286 * u)
      p.line_to(cx + 0.7857 * u, cy + -0.448 * u)
      p.bezier_curve_to(cx + 0.7857 * u, cy + -0.467 * u, cx + 0.7781 * u, cy + -0.4853 * u, cx + 0.7647 * u, cy + -0.4987 * u)
      p.close_path()
      p.move_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.8353 * u)
      p.line_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.close_path()
      p.move_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.0491 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.0491 * u, cy + -0.3571 * u)
      p.bezier_curve_to(cx + 0.0491 * u, cy + -0.3054 * u, cx + 0.0911 * u, cy + -0.2634 * u, cx + 0.1429 * u, cy + -0.2634 * u)
      p.line_to(cx + 0.625 * u, cy + -0.2634 * u)
      p.line_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.close_path()
      p.fill()
    }
    YhFileZip => { // file-zip
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.4821 * u, cy + -0.2679 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.2679 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.125 * u)
      p.line_to(cx + -0.4821 * u, cy + -0.125 * u)
      p.close_path()
      p.move_to(cx + -0.4821 * u, cy + 0.1563 * u)
      p.line_to(cx + -0.4821 * u, cy + 0.5134 * u)
      p.line_to(cx + -0.1964 * u, cy + 0.5134 * u)
      p.line_to(cx + -0.1964 * u, cy + 0.1563 * u)
      p.line_to(cx + -0.3393 * u, cy + 0.1563 * u)
      p.line_to(cx + -0.3393 * u, cy + 0.0179 * u)
      p.line_to(cx + -0.4821 * u, cy + 0.0179 * u)
      p.line_to(cx + -0.4821 * u, cy + 0.1563 * u)
      p.close_path()
      p.move_to(cx + -0.3036 * u, cy + 0.2634 * u)
      p.line_to(cx + -0.3036 * u, cy + 0.4063 * u)
      p.line_to(cx + -0.375 * u, cy + 0.4063 * u)
      p.line_to(cx + -0.375 * u, cy + 0.2634 * u)
      p.line_to(cx + -0.3036 * u, cy + 0.2634 * u)
      p.close_path()
      p.move_to(cx + -0.3393 * u, cy + -0.4107 * u)
      p.line_to(cx + -0.1964 * u, cy + -0.4107 * u)
      p.line_to(cx + -0.1964 * u, cy + -0.2679 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.2679 * u)
      p.close_path()
      p.move_to(cx + -0.4821 * u, cy + -0.5536 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.5536 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.4107 * u)
      p.line_to(cx + -0.4821 * u, cy + -0.4107 * u)
      p.close_path()
      p.move_to(cx + -0.3393 * u, cy + -0.125 * u)
      p.line_to(cx + -0.1964 * u, cy + -0.125 * u)
      p.line_to(cx + -0.1964 * u, cy + 0.0179 * u)
      p.line_to(cx + -0.3393 * u, cy + 0.0179 * u)
      p.close_path()
      p.move_to(cx + -0.3393 * u, cy + -0.6964 * u)
      p.line_to(cx + -0.1964 * u, cy + -0.6964 * u)
      p.line_to(cx + -0.1964 * u, cy + -0.5536 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.5536 * u)
      p.close_path()
      p.move_to(cx + 0.7647 * u, cy + -0.4987 * u)
      p.line_to(cx + 0.2844 * u, cy + -0.979 * u)
      p.bezier_curve_to(cx + 0.271 * u, cy + -0.9924 * u, cx + 0.2529 * u, cy + -1 * u, cx + 0.2339 * u, cy + -1 * u)
      p.line_to(cx + -0.7143 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.7538 * u, cy + -1 * u, cx + -0.7857 * u, cy + -0.9681 * u, cx + -0.7857 * u, cy + -0.9286 * u)
      p.line_to(cx + -0.7857 * u, cy + 0.9286 * u)
      p.bezier_curve_to(cx + -0.7857 * u, cy + 0.9681 * u, cx + -0.7538 * u, cy + 1 * u, cx + -0.7143 * u, cy + 1 * u)
      p.line_to(cx + 0.7143 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.7538 * u, cy + 1 * u, cx + 0.7857 * u, cy + 0.9681 * u, cx + 0.7857 * u, cy + 0.9286 * u)
      p.line_to(cx + 0.7857 * u, cy + -0.448 * u)
      p.bezier_curve_to(cx + 0.7857 * u, cy + -0.467 * u, cx + 0.7781 * u, cy + -0.4853 * u, cx + 0.7647 * u, cy + -0.4987 * u)
      p.close_path()
      p.move_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.8353 * u)
      p.line_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.close_path()
      p.move_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + -0.8393 * u)
      p.line_to(cx + -0.4821 * u, cy + -0.8393 * u)
      p.line_to(cx + -0.4821 * u, cy + -0.6964 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.6964 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.0491 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.0491 * u, cy + -0.3571 * u)
      p.bezier_curve_to(cx + 0.0491 * u, cy + -0.3054 * u, cx + 0.0911 * u, cy + -0.2634 * u, cx + 0.1429 * u, cy + -0.2634 * u)
      p.line_to(cx + 0.625 * u, cy + -0.2634 * u)
      p.line_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.close_path()
      p.fill()
    }
    YhFileMarkdown => { // file-markdown
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.7647 * u, cy + -0.4987 * u)
      p.line_to(cx + 0.2844 * u, cy + -0.979 * u)
      p.bezier_curve_to(cx + 0.271 * u, cy + -0.9924 * u, cx + 0.2529 * u, cy + -1 * u, cx + 0.2339 * u, cy + -1 * u)
      p.line_to(cx + -0.7143 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.7538 * u, cy + -1 * u, cx + -0.7857 * u, cy + -0.9681 * u, cx + -0.7857 * u, cy + -0.9286 * u)
      p.line_to(cx + -0.7857 * u, cy + 0.9286 * u)
      p.bezier_curve_to(cx + -0.7857 * u, cy + 0.9681 * u, cx + -0.7538 * u, cy + 1 * u, cx + -0.7143 * u, cy + 1 * u)
      p.line_to(cx + 0.7143 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.7538 * u, cy + 1 * u, cx + 0.7857 * u, cy + 0.9681 * u, cx + 0.7857 * u, cy + 0.9286 * u)
      p.line_to(cx + 0.7857 * u, cy + -0.448 * u)
      p.bezier_curve_to(cx + 0.7857 * u, cy + -0.467 * u, cx + 0.7781 * u, cy + -0.4853 * u, cx + 0.7647 * u, cy + -0.4987 * u)
      p.close_path()
      p.move_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.4152 * u)
      p.line_to(cx + 0.2009 * u, cy + -0.8353 * u)
      p.line_to(cx + 0.621 * u, cy + -0.4152 * u)
      p.close_path()
      p.move_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.0491 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.0491 * u, cy + -0.3571 * u)
      p.bezier_curve_to(cx + 0.0491 * u, cy + -0.3054 * u, cx + 0.0911 * u, cy + -0.2634 * u, cx + 0.1429 * u, cy + -0.2634 * u)
      p.line_to(cx + 0.625 * u, cy + -0.2634 * u)
      p.line_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.close_path()
      p.move_to(cx + -0.1853 * u, cy + -0.0688 * u)
      p.bezier_curve_to(cx + -0.1895 * u, cy + -0.0786 * u, cx + -0.1991 * u, cy + -0.0848 * u, cx + -0.2098 * u, cy + -0.0848 * u)
      p.line_to(cx + -0.2879 * u, cy + -0.0848 * u)
      p.bezier_curve_to(cx + -0.3027 * u, cy + -0.0848 * u, cx + -0.3147 * u, cy + -0.0728 * u, cx + -0.3147 * u, cy + -0.058 * u)
      p.line_to(cx + -0.3147 * u, cy + 0.5491 * u)
      p.bezier_curve_to(cx + -0.3147 * u, cy + 0.5638 * u, cx + -0.3027 * u, cy + 0.5759 * u, cx + -0.2879 * u, cy + 0.5759 * u)
      p.line_to(cx + -0.2275 * u, cy + 0.5759 * u)
      p.bezier_curve_to(cx + -0.2127 * u, cy + 0.5759 * u, cx + -0.2007 * u, cy + 0.5638 * u, cx + -0.2007 * u, cy + 0.5491 * u)
      p.line_to(cx + -0.2007 * u, cy + 0.1565 * u)
      p.line_to(cx + -0.0516 * u, cy + 0.4917 * u)
      p.bezier_curve_to(cx + -0.0473 * u, cy + 0.5013 * u, cx + -0.0377 * u, cy + 0.5076 * u, cx + -0.027 * u, cy + 0.5076 * u)
      p.line_to(cx + 0.0268 * u, cy + 0.5076 * u)
      p.bezier_curve_to(cx + 0.0373 * u, cy + 0.5076 * u, cx + 0.0469 * u, cy + 0.5013 * u, cx + 0.0513 * u, cy + 0.4917 * u)
      p.line_to(cx + 0.2004 * u, cy + 0.1556 * u)
      p.line_to(cx + 0.2004 * u, cy + 0.5491 * u)
      p.bezier_curve_to(cx + 0.2004 * u, cy + 0.5638 * u, cx + 0.2125 * u, cy + 0.5759 * u, cx + 0.2272 * u, cy + 0.5759 * u)
      p.line_to(cx + 0.2879 * u, cy + 0.5759 * u)
      p.bezier_curve_to(cx + 0.3027 * u, cy + 0.5759 * u, cx + 0.3147 * u, cy + 0.5638 * u, cx + 0.3147 * u, cy + 0.5491 * u)
      p.line_to(cx + 0.3147 * u, cy + -0.058 * u)
      p.bezier_curve_to(cx + 0.3147 * u, cy + -0.0728 * u, cx + 0.3027 * u, cy + -0.0848 * u, cx + 0.2879 * u, cy + -0.0848 * u)
      p.line_to(cx + 0.2105 * u, cy + -0.0848 * u)
      p.bezier_curve_to(cx + 0.1998 * u, cy + -0.0848 * u, cx + 0.1902 * u, cy + -0.0786 * u, cx + 0.1859 * u, cy + -0.0688 * u)
      p.line_to(cx + 0.0004 * u, cy + 0.3576 * u)
      p.line_to(cx + -0.1853 * u, cy + -0.0688 * u)
      p.close_path()
      p.fill()
    }
    YhFileSearch => { // file search
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.4028 * u, cy + -0.4587 * u)
      p.line_to(cx + 0.4028 * u, cy + -0.5688 * u)
      p.bezier_curve_to(cx + 0.4028 * u, cy + -0.5789 * u, cx + 0.3945 * u, cy + -0.5872 * u, cx + 0.3844 * u, cy + -0.5872 * u)
      p.line_to(cx + -0.4963 * u, cy + -0.5872 * u)
      p.bezier_curve_to(cx + -0.5064 * u, cy + -0.5872 * u, cx + -0.5147 * u, cy + -0.5789 * u, cx + -0.5147 * u, cy + -0.5688 * u)
      p.line_to(cx + -0.5147 * u, cy + -0.4587 * u)
      p.bezier_curve_to(cx + -0.5147 * u, cy + -0.4486 * u, cx + -0.5064 * u, cy + -0.4404 * u, cx + -0.4963 * u, cy + -0.4404 * u)
      p.line_to(cx + 0.3844 * u, cy + -0.4404 * u)
      p.bezier_curve_to(cx + 0.3945 * u, cy + -0.4404 * u, cx + 0.4028 * u, cy + -0.4486 * u, cx + 0.4028 * u, cy + -0.4587 * u)
      p.close_path()
      p.move_to(cx + -0.4963 * u, cy + -0.2569 * u)
      p.bezier_curve_to(cx + -0.5064 * u, cy + -0.2569 * u, cx + -0.5147 * u, cy + -0.2486 * u, cx + -0.5147 * u, cy + -0.2385 * u)
      p.line_to(cx + -0.5147 * u, cy + -0.1284 * u)
      p.bezier_curve_to(cx + -0.5147 * u, cy + -0.1183 * u, cx + -0.5064 * u, cy + -0.1101 * u, cx + -0.4963 * u, cy + -0.1101 * u)
      p.line_to(cx + -0.0743 * u, cy + -0.1101 * u)
      p.bezier_curve_to(cx + -0.0642 * u, cy + -0.1101 * u, cx + -0.056 * u, cy + -0.1183 * u, cx + -0.056 * u, cy + -0.1284 * u)
      p.line_to(cx + -0.056 * u, cy + -0.2385 * u)
      p.bezier_curve_to(cx + -0.056 * u, cy + -0.2486 * u, cx + -0.0642 * u, cy + -0.2569 * u, cx + -0.0743 * u, cy + -0.2569 * u)
      p.line_to(cx + -0.4963 * u, cy + -0.2569 * u)
      p.close_path()
      p.move_to(cx + -0.1661 * u, cy + 0.7798 * u)
      p.line_to(cx + -0.6982 * u, cy + 0.7798 * u)
      p.line_to(cx + -0.6982 * u, cy + -0.8349 * u)
      p.line_to(cx + 0.5862 * u, cy + -0.8349 * u)
      p.line_to(cx + 0.5862 * u, cy + -0.0459 * u)
      p.bezier_curve_to(cx + 0.5862 * u, cy + -0.0358 * u, cx + 0.5945 * u, cy + -0.0275 * u, cx + 0.6046 * u, cy + -0.0275 * u)
      p.line_to(cx + 0.733 * u, cy + -0.0275 * u)
      p.bezier_curve_to(cx + 0.7431 * u, cy + -0.0275 * u, cx + 0.7514 * u, cy + -0.0358 * u, cx + 0.7514 * u, cy + -0.0459 * u)
      p.line_to(cx + 0.7514 * u, cy + -0.9266 * u)
      p.bezier_curve_to(cx + 0.7514 * u, cy + -0.9672 * u, cx + 0.7186 * u, cy + -1 * u, cx + 0.678 * u, cy + -1 * u)
      p.line_to(cx + -0.7899 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.8305 * u, cy + -1 * u, cx + -0.8633 * u, cy + -0.9672 * u, cx + -0.8633 * u, cy + -0.9266 * u)
      p.line_to(cx + -0.8633 * u, cy + 0.8716 * u)
      p.bezier_curve_to(cx + -0.8633 * u, cy + 0.9122 * u, cx + -0.8305 * u, cy + 0.945 * u, cx + -0.7899 * u, cy + 0.945 * u)
      p.line_to(cx + -0.1661 * u, cy + 0.945 * u)
      p.bezier_curve_to(cx + -0.156 * u, cy + 0.945 * u, cx + -0.1477 * u, cy + 0.9367 * u, cx + -0.1477 * u, cy + 0.9266 * u)
      p.line_to(cx + -0.1477 * u, cy + 0.7982 * u)
      p.bezier_curve_to(cx + -0.1477 * u, cy + 0.7881 * u, cx + -0.156 * u, cy + 0.7798 * u, cx + -0.1661 * u, cy + 0.7798 * u)
      p.close_path()
      p.move_to(cx + 0.8562 * u, cy + 0.8979 * u)
      p.line_to(cx + 0.6422 * u, cy + 0.6839 * u)
      p.bezier_curve_to(cx + 0.6933 * u, cy + 0.6163 * u, cx + 0.7239 * u, cy + 0.5319 * u, cx + 0.7239 * u, cy + 0.4404 * u)
      p.bezier_curve_to(cx + 0.7239 * u, cy + 0.2174 * u, cx + 0.5431 * u, cy + 0.0367 * u, cx + 0.3202 * u, cy + 0.0367 * u)
      p.bezier_curve_to(cx + 0.0972 * u, cy + 0.0367 * u, cx + -0.0835 * u, cy + 0.2174 * u, cx + -0.0835 * u, cy + 0.4404 * u)
      p.bezier_curve_to(cx + -0.0835 * u, cy + 0.6633 * u, cx + 0.0972 * u, cy + 0.844 * u, cx + 0.3202 * u, cy + 0.844 * u)
      p.bezier_curve_to(cx + 0.4023 * u, cy + 0.844 * u, cx + 0.4784 * u, cy + 0.8195 * u, cx + 0.5422 * u, cy + 0.7775 * u)
      p.line_to(cx + 0.7594 * u, cy + 0.9947 * u)
      p.bezier_curve_to(cx + 0.7631 * u, cy + 0.9984 * u, cx + 0.7677 * u, cy + 1 * u, cx + 0.7722 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.7768 * u, cy + 1 * u, cx + 0.7817 * u, cy + 0.9982 * u, cx + 0.7851 * u, cy + 0.9947 * u)
      p.line_to(cx + 0.8562 * u, cy + 0.9236 * u)
      p.bezier_curve_to(cx + 0.8633 * u, cy + 0.9165 * u, cx + 0.8633 * u, cy + 0.905 * u, cx + 0.8562 * u, cy + 0.8979 * u)
      p.close_path()
      p.move_to(cx + 0.3202 * u, cy + 0.6972 * u)
      p.bezier_curve_to(cx + 0.1782 * u, cy + 0.6972 * u, cx + 0.0633 * u, cy + 0.5823 * u, cx + 0.0633 * u, cy + 0.4404 * u)
      p.bezier_curve_to(cx + 0.0633 * u, cy + 0.2984 * u, cx + 0.1782 * u, cy + 0.1835 * u, cx + 0.3202 * u, cy + 0.1835 * u)
      p.bezier_curve_to(cx + 0.4622 * u, cy + 0.1835 * u, cx + 0.5771 * u, cy + 0.2984 * u, cx + 0.5771 * u, cy + 0.4404 * u)
      p.bezier_curve_to(cx + 0.5771 * u, cy + 0.5823 * u, cx + 0.4622 * u, cy + 0.6972 * u, cx + 0.3202 * u, cy + 0.6972 * u)
      p.close_path()
      p.fill()
    }
    YhSnippets => { // snippets
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.7143 * u, cy + -0.8929 * u)
      p.line_to(cx + 0.4732 * u, cy + -0.8929 * u)
      p.line_to(cx + 0.4732 * u, cy + -0.9821 * u)
      p.bezier_curve_to(cx + 0.4732 * u, cy + -0.992 * u, cx + 0.4652 * u, cy + -1 * u, cx + 0.4554 * u, cy + -1 * u)
      p.line_to(cx + 0.3304 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.3205 * u, cy + -1 * u, cx + 0.3125 * u, cy + -0.992 * u, cx + 0.3125 * u, cy + -0.9821 * u)
      p.line_to(cx + 0.3125 * u, cy + -0.8929 * u)
      p.line_to(cx + -0.0268 * u, cy + -0.8929 * u)
      p.line_to(cx + -0.0268 * u, cy + -0.9821 * u)
      p.bezier_curve_to(cx + -0.0268 * u, cy + -0.992 * u, cx + -0.0348 * u, cy + -1 * u, cx + -0.0446 * u, cy + -1 * u)
      p.line_to(cx + -0.1696 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.1795 * u, cy + -1 * u, cx + -0.1875 * u, cy + -0.992 * u, cx + -0.1875 * u, cy + -0.9821 * u)
      p.line_to(cx + -0.1875 * u, cy + -0.8929 * u)
      p.line_to(cx + -0.4286 * u, cy + -0.8929 * u)
      p.bezier_curve_to(cx + -0.4681 * u, cy + -0.8929 * u, cx + -0.5 * u, cy + -0.8609 * u, cx + -0.5 * u, cy + -0.8214 * u)
      p.line_to(cx + -0.5 * u, cy + -0.5536 * u)
      p.line_to(cx + -0.7143 * u, cy + -0.5536 * u)
      p.bezier_curve_to(cx + -0.7538 * u, cy + -0.5536 * u, cx + -0.7857 * u, cy + -0.5217 * u, cx + -0.7857 * u, cy + -0.4821 * u)
      p.line_to(cx + -0.7857 * u, cy + 0.9286 * u)
      p.bezier_curve_to(cx + -0.7857 * u, cy + 0.9681 * u, cx + -0.7538 * u, cy + 1 * u, cx + -0.7143 * u, cy + 1 * u)
      p.line_to(cx + 0.4286 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.4681 * u, cy + 1 * u, cx + 0.5 * u, cy + 0.9681 * u, cx + 0.5 * u, cy + 0.9286 * u)
      p.line_to(cx + 0.5 * u, cy + 0.7143 * u)
      p.line_to(cx + 0.7143 * u, cy + 0.7143 * u)
      p.bezier_curve_to(cx + 0.7538 * u, cy + 0.7143 * u, cx + 0.7857 * u, cy + 0.6824 * u, cx + 0.7857 * u, cy + 0.6429 * u)
      p.line_to(cx + 0.7857 * u, cy + -0.8214 * u)
      p.bezier_curve_to(cx + 0.7857 * u, cy + -0.8609 * u, cx + 0.7538 * u, cy + -0.8929 * u, cx + 0.7143 * u, cy + -0.8929 * u)
      p.close_path()
      p.move_to(cx + 0.3393 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + -0.3929 * u)
      p.line_to(cx + -0.1384 * u, cy + -0.3929 * u)
      p.line_to(cx + -0.1384 * u, cy + -0.0045 * u)
      p.bezier_curve_to(cx + -0.1384 * u, cy + 0.0449 * u, cx + -0.0984 * u, cy + 0.0848 * u, cx + -0.0491 * u, cy + 0.0848 * u)
      p.line_to(cx + 0.3393 * u, cy + 0.0848 * u)
      p.line_to(cx + 0.3393 * u, cy + 0.8393 * u)
      p.close_path()
      p.move_to(cx + 0.3393 * u, cy + -0.058 * u)
      p.line_to(cx + 0.0045 * u, cy + -0.058 * u)
      p.line_to(cx + 0.0045 * u, cy + -0.3929 * u)
      p.line_to(cx + 0.0049 * u, cy + -0.3929 * u)
      p.line_to(cx + 0.3393 * u, cy + -0.0585 * u)
      p.line_to(cx + 0.3393 * u, cy + -0.058 * u)
      p.close_path()
      p.move_to(cx + 0.625 * u, cy + 0.5536 * u)
      p.line_to(cx + 0.5 * u, cy + 0.5536 * u)
      p.line_to(cx + 0.5 * u, cy + -0.125 * u)
      p.line_to(cx + 0.0714 * u, cy + -0.5536 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.5536 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.7321 * u)
      p.line_to(cx + -0.1875 * u, cy + -0.7321 * u)
      p.line_to(cx + -0.1875 * u, cy + -0.6607 * u)
      p.bezier_curve_to(cx + -0.1875 * u, cy + -0.6509 * u, cx + -0.1795 * u, cy + -0.6429 * u, cx + -0.1696 * u, cy + -0.6429 * u)
      p.line_to(cx + -0.0446 * u, cy + -0.6429 * u)
      p.bezier_curve_to(cx + -0.0348 * u, cy + -0.6429 * u, cx + -0.0268 * u, cy + -0.6509 * u, cx + -0.0268 * u, cy + -0.6607 * u)
      p.line_to(cx + -0.0268 * u, cy + -0.7321 * u)
      p.line_to(cx + 0.3125 * u, cy + -0.7321 * u)
      p.line_to(cx + 0.3125 * u, cy + -0.6607 * u)
      p.bezier_curve_to(cx + 0.3125 * u, cy + -0.6509 * u, cx + 0.3205 * u, cy + -0.6429 * u, cx + 0.3304 * u, cy + -0.6429 * u)
      p.line_to(cx + 0.4554 * u, cy + -0.6429 * u)
      p.bezier_curve_to(cx + 0.4652 * u, cy + -0.6429 * u, cx + 0.4732 * u, cy + -0.6509 * u, cx + 0.4732 * u, cy + -0.6607 * u)
      p.line_to(cx + 0.4732 * u, cy + -0.7321 * u)
      p.line_to(cx + 0.625 * u, cy + -0.7321 * u)
      p.line_to(cx + 0.625 * u, cy + 0.5536 * u)
      p.close_path()
      p.fill()
    }
    YhCloudServer => { // cloud-server
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.4279 * u, cy + -0.1494 * u)
      p.line_to(cx + -0.4282 * u, cy + -0.1494 * u)
      p.bezier_curve_to(cx + -0.438 * u, cy + -0.1494 * u, cx + -0.446 * u, cy + -0.1413 * u, cx + -0.446 * u, cy + -0.1315 * u)
      p.line_to(cx + -0.446 * u, cy + 0.7647 * u)
      p.bezier_curve_to(cx + -0.446 * u, cy + 0.7745 * u, cx + -0.438 * u, cy + 0.7825 * u, cx + -0.4282 * u, cy + 0.7825 * u)
      p.line_to(cx + 0.4279 * u, cy + 0.7825 * u)
      p.bezier_curve_to(cx + 0.4377 * u, cy + 0.7825 * u, cx + 0.4458 * u, cy + 0.7745 * u, cx + 0.4458 * u, cy + 0.7647 * u)
      p.line_to(cx + 0.4458 * u, cy + -0.1315 * u)
      p.bezier_curve_to(cx + 0.4458 * u, cy + -0.1413 * u, cx + 0.4377 * u, cy + -0.1494 * u, cx + 0.4279 * u, cy + -0.1494 * u)
      p.close_path()
      p.move_to(cx + -0.3033 * u, cy + -0.0067 * u)
      p.line_to(cx + 0.3031 * u, cy + -0.0067 * u)
      p.line_to(cx + 0.3031 * u, cy + 0.2542 * u)
      p.line_to(cx + -0.3033 * u, cy + 0.2542 * u)
      p.line_to(cx + -0.3033 * u, cy + -0.0067 * u)
      p.close_path()
      p.move_to(cx + 0.3031 * u, cy + 0.6398 * u)
      p.line_to(cx + -0.3033 * u, cy + 0.6398 * u)
      p.line_to(cx + -0.3033 * u, cy + 0.379 * u)
      p.line_to(cx + 0.3031 * u, cy + 0.379 * u)
      p.line_to(cx + 0.3031 * u, cy + 0.6398 * u)
      p.close_path()
      p.move_to(cx + -0.125 * u, cy + 0.5239 * u)
      p.close_path()
      p.move_to(cx + -0.1963 * u, cy + 0.5239 * u)
      p.line_to(cx + -0.1952 * u, cy + 0.5363 * u)
      p.line_to(cx + -0.192 * u, cy + 0.5483 * u)
      p.line_to(cx + -0.1867 * u, cy + 0.5596 * u)
      p.line_to(cx + -0.1796 * u, cy + 0.5698 * u)
      p.line_to(cx + -0.1708 * u, cy + 0.5786 * u)
      p.line_to(cx + -0.1606 * u, cy + 0.5857 * u)
      p.line_to(cx + -0.1494 * u, cy + 0.5909 * u)
      p.line_to(cx + -0.1373 * u, cy + 0.5942 * u)
      p.line_to(cx + -0.125 * u, cy + 0.5953 * u)
      p.line_to(cx + -0.1126 * u, cy + 0.5942 * u)
      p.line_to(cx + -0.1006 * u, cy + 0.5909 * u)
      p.line_to(cx + -0.0893 * u, cy + 0.5857 * u)
      p.line_to(cx + -0.0791 * u, cy + 0.5786 * u)
      p.line_to(cx + -0.0703 * u, cy + 0.5698 * u)
      p.line_to(cx + -0.0632 * u, cy + 0.5596 * u)
      p.line_to(cx + -0.0579 * u, cy + 0.5483 * u)
      p.line_to(cx + -0.0547 * u, cy + 0.5363 * u)
      p.line_to(cx + -0.0536 * u, cy + 0.5239 * u)
      p.line_to(cx + -0.0547 * u, cy + 0.5115 * u)
      p.line_to(cx + -0.0579 * u, cy + 0.4995 * u)
      p.line_to(cx + -0.0632 * u, cy + 0.4882 * u)
      p.line_to(cx + -0.0703 * u, cy + 0.4781 * u)
      p.line_to(cx + -0.0791 * u, cy + 0.4693 * u)
      p.line_to(cx + -0.0893 * u, cy + 0.4621 * u)
      p.line_to(cx + -0.1006 * u, cy + 0.4569 * u)
      p.line_to(cx + -0.1126 * u, cy + 0.4537 * u)
      p.line_to(cx + -0.125 * u, cy + 0.4526 * u)
      p.line_to(cx + -0.1373 * u, cy + 0.4537 * u)
      p.line_to(cx + -0.1494 * u, cy + 0.4569 * u)
      p.line_to(cx + -0.1606 * u, cy + 0.4621 * u)
      p.line_to(cx + -0.1708 * u, cy + 0.4693 * u)
      p.line_to(cx + -0.1796 * u, cy + 0.4781 * u)
      p.line_to(cx + -0.1867 * u, cy + 0.4882 * u)
      p.line_to(cx + -0.192 * u, cy + 0.4995 * u)
      p.line_to(cx + -0.1952 * u, cy + 0.5115 * u)
      p.line_to(cx + -0.1963 * u, cy + 0.5239 * u)
      p.close_path()
      p.move_to(cx + -0.125 * u, cy + 0.1271 * u)
      p.close_path()
      p.move_to(cx + -0.1963 * u, cy + 0.1271 * u)
      p.line_to(cx + -0.1952 * u, cy + 0.1395 * u)
      p.line_to(cx + -0.192 * u, cy + 0.1515 * u)
      p.line_to(cx + -0.1867 * u, cy + 0.1627 * u)
      p.line_to(cx + -0.1796 * u, cy + 0.1729 * u)
      p.line_to(cx + -0.1708 * u, cy + 0.1817 * u)
      p.line_to(cx + -0.1606 * u, cy + 0.1889 * u)
      p.line_to(cx + -0.1494 * u, cy + 0.1941 * u)
      p.line_to(cx + -0.1373 * u, cy + 0.1973 * u)
      p.line_to(cx + -0.125 * u, cy + 0.1984 * u)
      p.line_to(cx + -0.1126 * u, cy + 0.1973 * u)
      p.line_to(cx + -0.1006 * u, cy + 0.1941 * u)
      p.line_to(cx + -0.0893 * u, cy + 0.1889 * u)
      p.line_to(cx + -0.0791 * u, cy + 0.1817 * u)
      p.line_to(cx + -0.0703 * u, cy + 0.1729 * u)
      p.line_to(cx + -0.0632 * u, cy + 0.1627 * u)
      p.line_to(cx + -0.0579 * u, cy + 0.1515 * u)
      p.line_to(cx + -0.0547 * u, cy + 0.1395 * u)
      p.line_to(cx + -0.0536 * u, cy + 0.1271 * u)
      p.line_to(cx + -0.0547 * u, cy + 0.1147 * u)
      p.line_to(cx + -0.0579 * u, cy + 0.1027 * u)
      p.line_to(cx + -0.0632 * u, cy + 0.0914 * u)
      p.line_to(cx + -0.0703 * u, cy + 0.0812 * u)
      p.line_to(cx + -0.0791 * u, cy + 0.0724 * u)
      p.line_to(cx + -0.0893 * u, cy + 0.0653 * u)
      p.line_to(cx + -0.1006 * u, cy + 0.06 * u)
      p.line_to(cx + -0.1126 * u, cy + 0.0568 * u)
      p.line_to(cx + -0.125 * u, cy + 0.0557 * u)
      p.line_to(cx + -0.1373 * u, cy + 0.0568 * u)
      p.line_to(cx + -0.1494 * u, cy + 0.06 * u)
      p.line_to(cx + -0.1606 * u, cy + 0.0653 * u)
      p.line_to(cx + -0.1708 * u, cy + 0.0724 * u)
      p.line_to(cx + -0.1796 * u, cy + 0.0812 * u)
      p.line_to(cx + -0.1867 * u, cy + 0.0914 * u)
      p.line_to(cx + -0.192 * u, cy + 0.1027 * u)
      p.line_to(cx + -0.1952 * u, cy + 0.1147 * u)
      p.line_to(cx + -0.1963 * u, cy + 0.1271 * u)
      p.close_path()
      p.move_to(cx + 0.6674 * u, cy + -0.3213 * u)
      p.bezier_curve_to(cx + 0.5653 * u, cy + -0.5908 * u, cx + 0.3051 * u, cy + -0.7825 * u, cx + 0.0003 * u, cy + -0.7825 * u)
      p.bezier_curve_to(cx + -0.3044 * u, cy + -0.7825 * u, cx + -0.5646 * u, cy + -0.591 * u, cx + -0.6667 * u, cy + -0.3215 * u)
      p.bezier_curve_to(cx + -0.8587 * u, cy + -0.2709 * u, cx + -1 * u, cy + -0.0954 * u, cx + -0.9989 * u, cy + 0.1128 * u)
      p.bezier_curve_to(cx + -0.9975 * u, cy + 0.3456 * u, cx + -0.817 * u, cy + 0.5348 * u, cx + -0.5896 * u, cy + 0.5551 * u)
      p.bezier_curve_to(cx + -0.5791 * u, cy + 0.556 * u, cx + -0.5702 * u, cy + 0.5478 * u, cx + -0.5702 * u, cy + 0.5373 * u)
      p.line_to(cx + -0.5702 * u, cy + 0.4026 * u)
      p.bezier_curve_to(cx + -0.5702 * u, cy + 0.3937 * u, cx + -0.5769 * u, cy + 0.3861 * u, cx + -0.5858 * u, cy + 0.385 * u)
      p.bezier_curve_to(cx + -0.646 * u, cy + 0.3774 * u, cx + -0.7028 * u, cy + 0.3511 * u, cx + -0.7465 * u, cy + 0.3081 * u)
      p.bezier_curve_to(cx + -0.8 * u, cy + 0.2557 * u, cx + -0.8295 * u, cy + 0.1853 * u, cx + -0.8295 * u, cy + 0.1106 * u)
      p.bezier_curve_to(cx + -0.8295 * u, cy + 0.0482 * u, cx + -0.8092 * u, cy + -0.0107 * u, cx + -0.771 * u, cy + -0.0597 * u)
      p.bezier_curve_to(cx + -0.7338 * u, cy + -0.1075 * u, cx + -0.6814 * u, cy + -0.142 * u, cx + -0.6237 * u, cy + -0.1572 * u)
      p.line_to(cx + -0.5392 * u, cy + -0.1795 * u)
      p.line_to(cx + -0.5082 * u, cy + -0.2613 * u)
      p.bezier_curve_to(cx + -0.489 * u, cy + -0.3121 * u, cx + -0.4623 * u, cy + -0.3598 * u, cx + -0.4286 * u, cy + -0.4029 * u)
      p.bezier_curve_to(cx + -0.3954 * u, cy + -0.4457 * u, cx + -0.3559 * u, cy + -0.4831 * u, cx + -0.3118 * u, cy + -0.5143 * u)
      p.bezier_curve_to(cx + -0.2202 * u, cy + -0.5788 * u, cx + -0.1123 * u, cy + -0.6129 * u, cx + 0.0003 * u, cy + -0.6129 * u)
      p.bezier_curve_to(cx + 0.1129 * u, cy + -0.6129 * u, cx + 0.2208 * u, cy + -0.5788 * u, cx + 0.3125 * u, cy + -0.5141 * u)
      p.bezier_curve_to(cx + 0.3568 * u, cy + -0.4829 * u, cx + 0.3961 * u, cy + -0.4454 * u, cx + 0.4293 * u, cy + -0.4026 * u)
      p.bezier_curve_to(cx + 0.4629 * u, cy + -0.3596 * u, cx + 0.4897 * u, cy + -0.3119 * u, cx + 0.5089 * u, cy + -0.2611 * u)
      p.line_to(cx + 0.5396 * u, cy + -0.1795 * u)
      p.line_to(cx + 0.6239 * u, cy + -0.1572 * u)
      p.bezier_curve_to(cx + 0.7447 * u, cy + -0.1251 * u, cx + 0.8292 * u, cy + -0.0152 * u, cx + 0.8292 * u, cy + 0.1104 * u)
      p.bezier_curve_to(cx + 0.8292 * u, cy + 0.1853 * u, cx + 0.7998 * u, cy + 0.2555 * u, cx + 0.7463 * u, cy + 0.3079 * u)
      p.bezier_curve_to(cx + 0.7028 * u, cy + 0.3507 * u, cx + 0.6462 * u, cy + 0.3772 * u, cx + 0.586 * u, cy + 0.3848 * u)
      p.bezier_curve_to(cx + 0.5771 * u, cy + 0.3859 * u, cx + 0.5706 * u, cy + 0.3935 * u, cx + 0.5706 * u, cy + 0.4024 * u)
      p.line_to(cx + 0.5706 * u, cy + 0.5373 * u)
      p.bezier_curve_to(cx + 0.5706 * u, cy + 0.5478 * u, cx + 0.5798 * u, cy + 0.556 * u, cx + 0.5902 * u, cy + 0.5551 * u)
      p.bezier_curve_to(cx + 0.817 * u, cy + 0.5346 * u, cx + 0.9971 * u, cy + 0.3456 * u, cx + 0.9987 * u, cy + 0.1133 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.095 * u, cx + 0.8589 * u, cy + -0.2704 * u, cx + 0.6674 * u, cy + -0.3213 * u)
      p.close_path()
      p.fill()
    }
    YhCloudSync => { // cloud-sync
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.6674 * u, cy + -0.3213 * u)
      p.bezier_curve_to(cx + 0.5653 * u, cy + -0.5908 * u, cx + 0.3051 * u, cy + -0.7825 * u, cx + 0.0003 * u, cy + -0.7825 * u)
      p.bezier_curve_to(cx + -0.3044 * u, cy + -0.7825 * u, cx + -0.5646 * u, cy + -0.591 * u, cx + -0.6667 * u, cy + -0.3215 * u)
      p.bezier_curve_to(cx + -0.8587 * u, cy + -0.2709 * u, cx + -1 * u, cy + -0.0954 * u, cx + -0.9989 * u, cy + 0.1128 * u)
      p.bezier_curve_to(cx + -0.9975 * u, cy + 0.3456 * u, cx + -0.817 * u, cy + 0.5348 * u, cx + -0.5896 * u, cy + 0.5551 * u)
      p.bezier_curve_to(cx + -0.5791 * u, cy + 0.556 * u, cx + -0.5702 * u, cy + 0.5478 * u, cx + -0.5702 * u, cy + 0.5373 * u)
      p.line_to(cx + -0.5702 * u, cy + 0.4026 * u)
      p.bezier_curve_to(cx + -0.5702 * u, cy + 0.3937 * u, cx + -0.5769 * u, cy + 0.3861 * u, cx + -0.5858 * u, cy + 0.385 * u)
      p.bezier_curve_to(cx + -0.646 * u, cy + 0.3774 * u, cx + -0.7028 * u, cy + 0.3511 * u, cx + -0.7465 * u, cy + 0.3081 * u)
      p.bezier_curve_to(cx + -0.8 * u, cy + 0.2557 * u, cx + -0.8295 * u, cy + 0.1853 * u, cx + -0.8295 * u, cy + 0.1106 * u)
      p.bezier_curve_to(cx + -0.8295 * u, cy + 0.0482 * u, cx + -0.8092 * u, cy + -0.0107 * u, cx + -0.771 * u, cy + -0.0597 * u)
      p.bezier_curve_to(cx + -0.7338 * u, cy + -0.1075 * u, cx + -0.6814 * u, cy + -0.142 * u, cx + -0.6237 * u, cy + -0.1572 * u)
      p.line_to(cx + -0.5392 * u, cy + -0.1795 * u)
      p.line_to(cx + -0.5082 * u, cy + -0.2613 * u)
      p.bezier_curve_to(cx + -0.489 * u, cy + -0.3121 * u, cx + -0.4623 * u, cy + -0.3598 * u, cx + -0.4286 * u, cy + -0.4029 * u)
      p.bezier_curve_to(cx + -0.3954 * u, cy + -0.4457 * u, cx + -0.3559 * u, cy + -0.4831 * u, cx + -0.3118 * u, cy + -0.5143 * u)
      p.bezier_curve_to(cx + -0.2202 * u, cy + -0.5788 * u, cx + -0.1123 * u, cy + -0.6129 * u, cx + 0.0003 * u, cy + -0.6129 * u)
      p.bezier_curve_to(cx + 0.1129 * u, cy + -0.6129 * u, cx + 0.2208 * u, cy + -0.5788 * u, cx + 0.3125 * u, cy + -0.5141 * u)
      p.bezier_curve_to(cx + 0.3568 * u, cy + -0.4829 * u, cx + 0.3961 * u, cy + -0.4454 * u, cx + 0.4293 * u, cy + -0.4026 * u)
      p.bezier_curve_to(cx + 0.4629 * u, cy + -0.3596 * u, cx + 0.4897 * u, cy + -0.3119 * u, cx + 0.5089 * u, cy + -0.2611 * u)
      p.line_to(cx + 0.5396 * u, cy + -0.1795 * u)
      p.line_to(cx + 0.6239 * u, cy + -0.1572 * u)
      p.bezier_curve_to(cx + 0.7447 * u, cy + -0.1251 * u, cx + 0.8292 * u, cy + -0.0152 * u, cx + 0.8292 * u, cy + 0.1104 * u)
      p.bezier_curve_to(cx + 0.8292 * u, cy + 0.1853 * u, cx + 0.7998 * u, cy + 0.2555 * u, cx + 0.7463 * u, cy + 0.3079 * u)
      p.bezier_curve_to(cx + 0.7028 * u, cy + 0.3507 * u, cx + 0.6462 * u, cy + 0.3772 * u, cx + 0.586 * u, cy + 0.3848 * u)
      p.bezier_curve_to(cx + 0.5771 * u, cy + 0.3859 * u, cx + 0.5706 * u, cy + 0.3935 * u, cx + 0.5706 * u, cy + 0.4024 * u)
      p.line_to(cx + 0.5706 * u, cy + 0.5373 * u)
      p.bezier_curve_to(cx + 0.5706 * u, cy + 0.5478 * u, cx + 0.5798 * u, cy + 0.556 * u, cx + 0.5902 * u, cy + 0.5551 * u)
      p.bezier_curve_to(cx + 0.817 * u, cy + 0.5346 * u, cx + 0.9971 * u, cy + 0.3456 * u, cx + 0.9987 * u, cy + 0.1133 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.095 * u, cx + 0.8589 * u, cy + -0.2704 * u, cx + 0.6674 * u, cy + -0.3213 * u)
      p.close_path()
      p.move_to(cx + -0.3013 * u, cy + 0.3197 * u)
      p.bezier_curve_to(cx + -0.2973 * u, cy + 0.245 * u, cx + -0.2663 * u, cy + 0.1755 * u, cx + -0.2132 * u, cy + 0.1222 * u)
      p.bezier_curve_to(cx + -0.1566 * u, cy + 0.0653 * u, cx + -0.0795 * u, cy + 0.0334 * u, cx + 0.0008 * u, cy + 0.0334 * u)
      p.bezier_curve_to(cx + 0.0815 * u, cy + 0.0334 * u, cx + 0.1575 * u, cy + 0.0649 * u, cx + 0.2148 * u, cy + 0.1222 * u)
      p.bezier_curve_to(cx + 0.2179 * u, cy + 0.1253 * u, cx + 0.2208 * u, cy + 0.1284 * u, cx + 0.2239 * u, cy + 0.1318 * u)
      p.line_to(cx + 0.1682 * u, cy + 0.1755 * u)
      p.bezier_curve_to(cx + 0.1564 * u, cy + 0.1846 * u, cx + 0.1604 * u, cy + 0.2033 * u, cx + 0.1749 * u, cy + 0.2069 * u)
      p.line_to(cx + 0.3938 * u, cy + 0.2604 * u)
      p.bezier_curve_to(cx + 0.405 * u, cy + 0.2631 * u, cx + 0.4159 * u, cy + 0.2546 * u, cx + 0.4159 * u, cy + 0.2432 * u)
      p.line_to(cx + 0.417 * u, cy + 0.0174 * u)
      p.bezier_curve_to(cx + 0.417 * u, cy + 0.0025 * u, cx + 0.4001 * u, cy + -0.006 * u, cx + 0.3883 * u, cy + 0.0033 * u)
      p.line_to(cx + 0.3365 * u, cy + 0.0439 * u)
      p.bezier_curve_to(cx + 0.2549 * u, cy + -0.0497 * u, cx + 0.135 * u, cy + -0.109 * u, cx + 0.001 * u, cy + -0.109 * u)
      p.bezier_curve_to(cx + -0.2384 * u, cy + -0.109 * u, cx + -0.4337 * u, cy + 0.0807 * u, cx + -0.4435 * u, cy + 0.3184 * u)
      p.bezier_curve_to(cx + -0.444 * u, cy + 0.3284 * u, cx + -0.436 * u, cy + 0.3369 * u, cx + -0.4257 * u, cy + 0.3369 * u)
      p.line_to(cx + -0.3189 * u, cy + 0.3369 * u)
      p.bezier_curve_to(cx + -0.3096 * u, cy + 0.3366 * u, cx + -0.3018 * u, cy + 0.3293 * u, cx + -0.3013 * u, cy + 0.3197 * u)
      p.close_path()
      p.move_to(cx + 0.4257 * u, cy + 0.3366 * u)
      p.line_to(cx + 0.3189 * u, cy + 0.3366 * u)
      p.bezier_curve_to(cx + 0.3096 * u, cy + 0.3366 * u, cx + 0.3018 * u, cy + 0.344 * u, cx + 0.3011 * u, cy + 0.3536 * u)
      p.bezier_curve_to(cx + 0.2971 * u, cy + 0.4283 * u, cx + 0.2661 * u, cy + 0.4978 * u, cx + 0.213 * u, cy + 0.5511 * u)
      p.bezier_curve_to(cx + 0.1564 * u, cy + 0.608 * u, cx + 0.0793 * u, cy + 0.6398 * u, cx + -0.001 * u, cy + 0.6398 * u)
      p.bezier_curve_to(cx + -0.0817 * u, cy + 0.6398 * u, cx + -0.1577 * u, cy + 0.6084 * u, cx + -0.215 * u, cy + 0.5511 * u)
      p.bezier_curve_to(cx + -0.2181 * u, cy + 0.548 * u, cx + -0.221 * u, cy + 0.5449 * u, cx + -0.2242 * u, cy + 0.5415 * u)
      p.line_to(cx + -0.1684 * u, cy + 0.4978 * u)
      p.bezier_curve_to(cx + -0.1566 * u, cy + 0.4887 * u, cx + -0.1606 * u, cy + 0.47 * u, cx + -0.1751 * u, cy + 0.4664 * u)
      p.line_to(cx + -0.394 * u, cy + 0.4129 * u)
      p.bezier_curve_to(cx + -0.4052 * u, cy + 0.4102 * u, cx + -0.4161 * u, cy + 0.4187 * u, cx + -0.4161 * u, cy + 0.4301 * u)
      p.line_to(cx + -0.417 * u, cy + 0.6561 * u)
      p.bezier_curve_to(cx + -0.417 * u, cy + 0.6711 * u, cx + -0.4001 * u, cy + 0.6795 * u, cx + -0.3883 * u, cy + 0.6702 * u)
      p.line_to(cx + -0.3365 * u, cy + 0.6296 * u)
      p.bezier_curve_to(cx + -0.2549 * u, cy + 0.7232 * u, cx + -0.135 * u, cy + 0.7825 * u, cx + -0.001 * u, cy + 0.7825 * u)
      p.bezier_curve_to(cx + 0.2384 * u, cy + 0.7825 * u, cx + 0.4337 * u, cy + 0.5928 * u, cx + 0.4435 * u, cy + 0.3551 * u)
      p.bezier_curve_to(cx + 0.444 * u, cy + 0.3451 * u, cx + 0.436 * u, cy + 0.3366 * u, cx + 0.4257 * u, cy + 0.3366 * u)
      p.close_path()
      p.fill()
    }
    YhApi => { // api
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9924 * u, cy + -0.8884 * u)
      p.line_to(cx + 0.8887 * u, cy + -0.9922 * u)
      p.bezier_curve_to(cx + 0.8848 * u, cy + -0.9961 * u, cx + 0.8799 * u, cy + -0.9978 * u, cx + 0.8747 * u, cy + -0.9978 * u)
      p.bezier_curve_to(cx + 0.8696 * u, cy + -0.9978 * u, cx + 0.8647 * u, cy + -0.9958 * u, cx + 0.8608 * u, cy + -0.9922 * u)
      p.line_to(cx + 0.6746 * u, cy + -0.806 * u)
      p.bezier_curve_to(cx + 0.5922 * u, cy + -0.862 * u, cx + 0.4963 * u, cy + -0.8899 * u, cx + 0.4004 * u, cy + -0.8899 * u)
      p.bezier_curve_to(cx + 0.2751 * u, cy + -0.8899 * u, cx + 0.1498 * u, cy + -0.8422 * u, cx + 0.0542 * u, cy + -0.7465 * u)
      p.line_to(cx + -0.1951 * u, cy + -0.4972 * u)
      p.bezier_curve_to(cx + -0.2027 * u, cy + -0.4897 * u, cx + -0.2027 * u, cy + -0.4772 * u, cx + -0.1951 * u, cy + -0.4696 * u)
      p.line_to(cx + 0.4696 * u, cy + 0.1951 * u)
      p.bezier_curve_to(cx + 0.4735 * u, cy + 0.199 * u, cx + 0.4784 * u, cy + 0.2007 * u, cx + 0.4835 * u, cy + 0.2007 * u)
      p.bezier_curve_to(cx + 0.4884 * u, cy + 0.2007 * u, cx + 0.4936 * u, cy + 0.1988 * u, cx + 0.4975 * u, cy + 0.1951 * u)
      p.line_to(cx + 0.7468 * u, cy + -0.0542 * u)
      p.bezier_curve_to(cx + 0.9154 * u, cy + -0.223 * u, cx + 0.9352 * u, cy + -0.484 * u, cx + 0.8062 * u, cy + -0.6744 * u)
      p.line_to(cx + 0.9924 * u, cy + -0.8606 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.8684 * u, cx + 1 * u, cy + -0.8809 * u, cx + 0.9924 * u, cy + -0.8884 * u)
      p.close_path()
      p.move_to(cx + 0.6289 * u, cy + -0.1719 * u)
      p.line_to(cx + 0.4835 * u, cy + -0.0265 * u)
      p.line_to(cx + 0.0265 * u, cy + -0.4835 * u)
      p.line_to(cx + 0.1719 * u, cy + -0.6289 * u)
      p.bezier_curve_to(cx + 0.2328 * u, cy + -0.6898 * u, cx + 0.314 * u, cy + -0.7235 * u, cx + 0.4004 * u, cy + -0.7235 * u)
      p.bezier_curve_to(cx + 0.4867 * u, cy + -0.7235 * u, cx + 0.5677 * u, cy + -0.69 * u, cx + 0.6289 * u, cy + -0.6289 * u)
      p.bezier_curve_to(cx + 0.6898 * u, cy + -0.568 * u, cx + 0.7235 * u, cy + -0.4867 * u, cx + 0.7235 * u, cy + -0.4004 * u)
      p.bezier_curve_to(cx + 0.7235 * u, cy + -0.314 * u, cx + 0.6898 * u, cy + -0.233 * u, cx + 0.6289 * u, cy + -0.1719 * u)
      p.close_path()
      p.move_to(cx + 0.1635 * u, cy + 0.085 * u)
      p.bezier_curve_to(cx + 0.156 * u, cy + 0.0774 * u, cx + 0.1435 * u, cy + 0.0774 * u, cx + 0.1359 * u, cy + 0.085 * u)
      p.line_to(cx + -0.027 * u, cy + 0.248 * u)
      p.line_to(cx + -0.248 * u, cy + 0.027 * u)
      p.line_to(cx + -0.0848 * u, cy + -0.1361 * u)
      p.bezier_curve_to(cx + -0.0772 * u, cy + -0.1437 * u, cx + -0.0772 * u, cy + -0.1562 * u, cx + -0.0848 * u, cy + -0.1638 * u)
      p.line_to(cx + -0.1738 * u, cy + -0.2528 * u)
      p.bezier_curve_to(cx + -0.1814 * u, cy + -0.2604 * u, cx + -0.1939 * u, cy + -0.2604 * u, cx + -0.2015 * u, cy + -0.2528 * u)
      p.line_to(cx + -0.3646 * u, cy + -0.0897 * u)
      p.line_to(cx + -0.4698 * u, cy + -0.1949 * u)
      p.bezier_curve_to(cx + -0.4738 * u, cy + -0.1988 * u, cx + -0.4787 * u, cy + -0.2005 * u, cx + -0.4838 * u, cy + -0.2005 * u)
      p.bezier_curve_to(cx + -0.4887 * u, cy + -0.2005 * u, cx + -0.4938 * u, cy + -0.1985 * u, cx + -0.4977 * u, cy + -0.1949 * u)
      p.line_to(cx + -0.7468 * u, cy + 0.0544 * u)
      p.bezier_curve_to(cx + -0.9154 * u, cy + 0.2232 * u, cx + -0.9352 * u, cy + 0.4843 * u, cx + -0.8062 * u, cy + 0.6746 * u)
      p.line_to(cx + -0.9924 * u, cy + 0.8608 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.8684 * u, cx + -1 * u, cy + 0.8809 * u, cx + -0.9924 * u, cy + 0.8884 * u)
      p.line_to(cx + -0.8887 * u, cy + 0.9922 * u)
      p.bezier_curve_to(cx + -0.8848 * u, cy + 0.9961 * u, cx + -0.8799 * u, cy + 0.9978 * u, cx + -0.8747 * u, cy + 0.9978 * u)
      p.bezier_curve_to(cx + -0.8696 * u, cy + 0.9978 * u, cx + -0.8647 * u, cy + 0.9958 * u, cx + -0.8608 * u, cy + 0.9922 * u)
      p.line_to(cx + -0.6746 * u, cy + 0.806 * u)
      p.bezier_curve_to(cx + -0.5922 * u, cy + 0.862 * u, cx + -0.4963 * u, cy + 0.8899 * u, cx + -0.4004 * u, cy + 0.8899 * u)
      p.bezier_curve_to(cx + -0.2751 * u, cy + 0.8899 * u, cx + -0.1498 * u, cy + 0.8422 * u, cx + -0.0542 * u, cy + 0.7465 * u)
      p.line_to(cx + 0.1951 * u, cy + 0.4972 * u)
      p.bezier_curve_to(cx + 0.2027 * u, cy + 0.4897 * u, cx + 0.2027 * u, cy + 0.4772 * u, cx + 0.1951 * u, cy + 0.4696 * u)
      p.line_to(cx + 0.0899 * u, cy + 0.3644 * u)
      p.line_to(cx + 0.2531 * u, cy + 0.2012 * u)
      p.bezier_curve_to(cx + 0.2607 * u, cy + 0.1936 * u, cx + 0.2607 * u, cy + 0.1812 * u, cx + 0.2531 * u, cy + 0.1736 * u)
      p.line_to(cx + 0.1635 * u, cy + 0.085 * u)
      p.close_path()
      p.move_to(cx + -0.1721 * u, cy + 0.6291 * u)
      p.bezier_curve_to(cx + -0.233 * u, cy + 0.69 * u, cx + -0.3143 * u, cy + 0.7238 * u, cx + -0.4006 * u, cy + 0.7238 * u)
      p.bezier_curve_to(cx + -0.487 * u, cy + 0.7238 * u, cx + -0.568 * u, cy + 0.6903 * u, cx + -0.6291 * u, cy + 0.6291 * u)
      p.bezier_curve_to(cx + -0.69 * u, cy + 0.5682 * u, cx + -0.7238 * u, cy + 0.487 * u, cx + -0.7238 * u, cy + 0.4006 * u)
      p.bezier_curve_to(cx + -0.7238 * u, cy + 0.3143 * u, cx + -0.6903 * u, cy + 0.2333 * u, cx + -0.6291 * u, cy + 0.1721 * u)
      p.line_to(cx + -0.4838 * u, cy + 0.0268 * u)
      p.line_to(cx + -0.0268 * u, cy + 0.4838 * u)
      p.line_to(cx + -0.1721 * u, cy + 0.6291 * u)
      p.close_path()
      p.fill()
    }
    YhGateway => { // gateway
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.963 * u, cy + -0.2778 * u)
      p.bezier_curve_to(cx + 0.9833 * u, cy + -0.2778 * u, cx + 1 * u, cy + -0.2944 * u, cx + 1 * u, cy + -0.3148 * u)
      p.line_to(cx + 1 * u, cy + -0.7407 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.7611 * u, cx + 0.9833 * u, cy + -0.7778 * u, cx + 0.963 * u, cy + -0.7778 * u)
      p.line_to(cx + 0.537 * u, cy + -0.7778 * u)
      p.bezier_curve_to(cx + 0.5167 * u, cy + -0.7778 * u, cx + 0.5 * u, cy + -0.7611 * u, cx + 0.5 * u, cy + -0.7407 * u)
      p.line_to(cx + 0.5 * u, cy + -0.6111 * u)
      p.line_to(cx + -0.5 * u, cy + -0.6111 * u)
      p.line_to(cx + -0.5 * u, cy + -0.7407 * u)
      p.bezier_curve_to(cx + -0.5 * u, cy + -0.7611 * u, cx + -0.5167 * u, cy + -0.7778 * u, cx + -0.537 * u, cy + -0.7778 * u)
      p.line_to(cx + -0.963 * u, cy + -0.7778 * u)
      p.bezier_curve_to(cx + -0.9833 * u, cy + -0.7778 * u, cx + -1 * u, cy + -0.7611 * u, cx + -1 * u, cy + -0.7407 * u)
      p.line_to(cx + -1 * u, cy + -0.3148 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.2944 * u, cx + -0.9833 * u, cy + -0.2778 * u, cx + -0.963 * u, cy + -0.2778 * u)
      p.line_to(cx + -0.8333 * u, cy + -0.2778 * u)
      p.line_to(cx + -0.8333 * u, cy + 0.2778 * u)
      p.line_to(cx + -0.963 * u, cy + 0.2778 * u)
      p.bezier_curve_to(cx + -0.9833 * u, cy + 0.2778 * u, cx + -1 * u, cy + 0.2944 * u, cx + -1 * u, cy + 0.3148 * u)
      p.line_to(cx + -1 * u, cy + 0.7407 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.7611 * u, cx + -0.9833 * u, cy + 0.7778 * u, cx + -0.963 * u, cy + 0.7778 * u)
      p.line_to(cx + -0.537 * u, cy + 0.7778 * u)
      p.bezier_curve_to(cx + -0.5167 * u, cy + 0.7778 * u, cx + -0.5 * u, cy + 0.7611 * u, cx + -0.5 * u, cy + 0.7407 * u)
      p.line_to(cx + -0.5 * u, cy + 0.6111 * u)
      p.line_to(cx + 0.5 * u, cy + 0.6111 * u)
      p.line_to(cx + 0.5 * u, cy + 0.7407 * u)
      p.bezier_curve_to(cx + 0.5 * u, cy + 0.7611 * u, cx + 0.5167 * u, cy + 0.7778 * u, cx + 0.537 * u, cy + 0.7778 * u)
      p.line_to(cx + 0.963 * u, cy + 0.7778 * u)
      p.bezier_curve_to(cx + 0.9833 * u, cy + 0.7778 * u, cx + 1 * u, cy + 0.7611 * u, cx + 1 * u, cy + 0.7407 * u)
      p.line_to(cx + 1 * u, cy + 0.3148 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.2944 * u, cx + 0.9833 * u, cy + 0.2778 * u, cx + 0.963 * u, cy + 0.2778 * u)
      p.line_to(cx + 0.8333 * u, cy + 0.2778 * u)
      p.line_to(cx + 0.8333 * u, cy + -0.2778 * u)
      p.line_to(cx + 0.963 * u, cy + -0.2778 * u)
      p.close_path()
      p.move_to(cx + 0.6481 * u, cy + -0.6296 * u)
      p.line_to(cx + 0.8519 * u, cy + -0.6296 * u)
      p.line_to(cx + 0.8519 * u, cy + -0.4259 * u)
      p.line_to(cx + 0.6481 * u, cy + -0.4259 * u)
      p.line_to(cx + 0.6481 * u, cy + -0.6296 * u)
      p.close_path()
      p.move_to(cx + -0.8519 * u, cy + -0.4259 * u)
      p.line_to(cx + -0.8519 * u, cy + -0.6296 * u)
      p.line_to(cx + -0.6481 * u, cy + -0.6296 * u)
      p.line_to(cx + -0.6481 * u, cy + -0.4259 * u)
      p.line_to(cx + -0.8519 * u, cy + -0.4259 * u)
      p.close_path()
      p.move_to(cx + -0.6481 * u, cy + 0.6296 * u)
      p.line_to(cx + -0.8519 * u, cy + 0.6296 * u)
      p.line_to(cx + -0.8519 * u, cy + 0.4259 * u)
      p.line_to(cx + -0.6481 * u, cy + 0.4259 * u)
      p.line_to(cx + -0.6481 * u, cy + 0.6296 * u)
      p.close_path()
      p.move_to(cx + 0.8519 * u, cy + 0.4259 * u)
      p.line_to(cx + 0.8519 * u, cy + 0.6296 * u)
      p.line_to(cx + 0.6481 * u, cy + 0.6296 * u)
      p.line_to(cx + 0.6481 * u, cy + 0.4259 * u)
      p.line_to(cx + 0.8519 * u, cy + 0.4259 * u)
      p.close_path()
      p.move_to(cx + 0.6667 * u, cy + 0.2778 * u)
      p.line_to(cx + 0.537 * u, cy + 0.2778 * u)
      p.bezier_curve_to(cx + 0.5167 * u, cy + 0.2778 * u, cx + 0.5 * u, cy + 0.2944 * u, cx + 0.5 * u, cy + 0.3148 * u)
      p.line_to(cx + 0.5 * u, cy + 0.4444 * u)
      p.line_to(cx + -0.5 * u, cy + 0.4444 * u)
      p.line_to(cx + -0.5 * u, cy + 0.3148 * u)
      p.bezier_curve_to(cx + -0.5 * u, cy + 0.2944 * u, cx + -0.5167 * u, cy + 0.2778 * u, cx + -0.537 * u, cy + 0.2778 * u)
      p.line_to(cx + -0.6667 * u, cy + 0.2778 * u)
      p.line_to(cx + -0.6667 * u, cy + -0.2778 * u)
      p.line_to(cx + -0.537 * u, cy + -0.2778 * u)
      p.bezier_curve_to(cx + -0.5167 * u, cy + -0.2778 * u, cx + -0.5 * u, cy + -0.2944 * u, cx + -0.5 * u, cy + -0.3148 * u)
      p.line_to(cx + -0.5 * u, cy + -0.4444 * u)
      p.line_to(cx + 0.5 * u, cy + -0.4444 * u)
      p.line_to(cx + 0.5 * u, cy + -0.3148 * u)
      p.bezier_curve_to(cx + 0.5 * u, cy + -0.2944 * u, cx + 0.5167 * u, cy + -0.2778 * u, cx + 0.537 * u, cy + -0.2778 * u)
      p.line_to(cx + 0.6667 * u, cy + -0.2778 * u)
      p.line_to(cx + 0.6667 * u, cy + 0.2778 * u)
      p.close_path()
      p.fill()
    }
    YhQrcode => { // qrcode
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.1146 * u, cy + -1 * u)
      p.line_to(cx + -0.9167 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.9628 * u, cy + -1 * u, cx + -1 * u, cy + -0.9628 * u, cx + -1 * u, cy + -0.9167 * u)
      p.line_to(cx + -1 * u, cy + -0.1146 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.1031 * u, cx + -0.9906 * u, cy + -0.0938 * u, cx + -0.9792 * u, cy + -0.0938 * u)
      p.line_to(cx + -0.1146 * u, cy + -0.0938 * u)
      p.bezier_curve_to(cx + -0.1031 * u, cy + -0.0938 * u, cx + -0.0938 * u, cy + -0.1031 * u, cx + -0.0938 * u, cy + -0.1146 * u)
      p.line_to(cx + -0.0938 * u, cy + -0.9792 * u)
      p.bezier_curve_to(cx + -0.0938 * u, cy + -0.9906 * u, cx + -0.1031 * u, cy + -1 * u, cx + -0.1146 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.2604 * u, cy + -0.2604 * u)
      p.line_to(cx + -0.8333 * u, cy + -0.2604 * u)
      p.line_to(cx + -0.8333 * u, cy + -0.8333 * u)
      p.line_to(cx + -0.2604 * u, cy + -0.8333 * u)
      p.line_to(cx + -0.2604 * u, cy + -0.2604 * u)
      p.close_path()
      p.move_to(cx + -0.6198 * u, cy + -0.4531 * u)
      p.line_to(cx + -0.474 * u, cy + -0.4531 * u)
      p.bezier_curve_to(cx + -0.4625 * u, cy + -0.4531 * u, cx + -0.4531 * u, cy + -0.4625 * u, cx + -0.4531 * u, cy + -0.474 * u)
      p.line_to(cx + -0.4531 * u, cy + -0.6198 * u)
      p.bezier_curve_to(cx + -0.4531 * u, cy + -0.6312 * u, cx + -0.4625 * u, cy + -0.6406 * u, cx + -0.474 * u, cy + -0.6406 * u)
      p.line_to(cx + -0.6198 * u, cy + -0.6406 * u)
      p.bezier_curve_to(cx + -0.6312 * u, cy + -0.6406 * u, cx + -0.6406 * u, cy + -0.6312 * u, cx + -0.6406 * u, cy + -0.6198 * u)
      p.line_to(cx + -0.6406 * u, cy + -0.474 * u)
      p.bezier_curve_to(cx + -0.6406 * u, cy + -0.4625 * u, cx + -0.6312 * u, cy + -0.4531 * u, cx + -0.6198 * u, cy + -0.4531 * u)
      p.close_path()
      p.move_to(cx + -0.1146 * u, cy + 0.0938 * u)
      p.line_to(cx + -0.9792 * u, cy + 0.0938 * u)
      p.bezier_curve_to(cx + -0.9906 * u, cy + 0.0938 * u, cx + -1 * u, cy + 0.1031 * u, cx + -1 * u, cy + 0.1146 * u)
      p.line_to(cx + -1 * u, cy + 0.9167 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9628 * u, cx + -0.9628 * u, cy + 1 * u, cx + -0.9167 * u, cy + 1 * u)
      p.line_to(cx + -0.1146 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.1031 * u, cy + 1 * u, cx + -0.0938 * u, cy + 0.9906 * u, cx + -0.0938 * u, cy + 0.9792 * u)
      p.line_to(cx + -0.0938 * u, cy + 0.1146 * u)
      p.bezier_curve_to(cx + -0.0938 * u, cy + 0.1031 * u, cx + -0.1031 * u, cy + 0.0938 * u, cx + -0.1146 * u, cy + 0.0938 * u)
      p.close_path()
      p.move_to(cx + -0.2604 * u, cy + 0.8333 * u)
      p.line_to(cx + -0.8333 * u, cy + 0.8333 * u)
      p.line_to(cx + -0.8333 * u, cy + 0.2604 * u)
      p.line_to(cx + -0.2604 * u, cy + 0.2604 * u)
      p.line_to(cx + -0.2604 * u, cy + 0.8333 * u)
      p.close_path()
      p.move_to(cx + -0.6198 * u, cy + 0.6406 * u)
      p.line_to(cx + -0.474 * u, cy + 0.6406 * u)
      p.bezier_curve_to(cx + -0.4625 * u, cy + 0.6406 * u, cx + -0.4531 * u, cy + 0.6312 * u, cx + -0.4531 * u, cy + 0.6198 * u)
      p.line_to(cx + -0.4531 * u, cy + 0.474 * u)
      p.bezier_curve_to(cx + -0.4531 * u, cy + 0.4625 * u, cx + -0.4625 * u, cy + 0.4531 * u, cx + -0.474 * u, cy + 0.4531 * u)
      p.line_to(cx + -0.6198 * u, cy + 0.4531 * u)
      p.bezier_curve_to(cx + -0.6312 * u, cy + 0.4531 * u, cx + -0.6406 * u, cy + 0.4625 * u, cx + -0.6406 * u, cy + 0.474 * u)
      p.line_to(cx + -0.6406 * u, cy + 0.6198 * u)
      p.bezier_curve_to(cx + -0.6406 * u, cy + 0.6312 * u, cx + -0.6312 * u, cy + 0.6406 * u, cx + -0.6198 * u, cy + 0.6406 * u)
      p.close_path()
      p.move_to(cx + 0.9167 * u, cy + -1 * u)
      p.line_to(cx + 0.1146 * u, cy + -1 * u)
      p.bezier_curve_to(cx + 0.1031 * u, cy + -1 * u, cx + 0.0938 * u, cy + -0.9906 * u, cx + 0.0938 * u, cy + -0.9792 * u)
      p.line_to(cx + 0.0938 * u, cy + -0.1146 * u)
      p.bezier_curve_to(cx + 0.0938 * u, cy + -0.1031 * u, cx + 0.1031 * u, cy + -0.0938 * u, cx + 0.1146 * u, cy + -0.0938 * u)
      p.line_to(cx + 0.9792 * u, cy + -0.0938 * u)
      p.bezier_curve_to(cx + 0.9906 * u, cy + -0.0938 * u, cx + 1 * u, cy + -0.1031 * u, cx + 1 * u, cy + -0.1146 * u)
      p.line_to(cx + 1 * u, cy + -0.9167 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.9628 * u, cx + 0.9628 * u, cy + -1 * u, cx + 0.9167 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.8333 * u, cy + -0.2604 * u)
      p.line_to(cx + 0.2604 * u, cy + -0.2604 * u)
      p.line_to(cx + 0.2604 * u, cy + -0.8333 * u)
      p.line_to(cx + 0.8333 * u, cy + -0.8333 * u)
      p.line_to(cx + 0.8333 * u, cy + -0.2604 * u)
      p.close_path()
      p.move_to(cx + 0.474 * u, cy + -0.4531 * u)
      p.line_to(cx + 0.6198 * u, cy + -0.4531 * u)
      p.bezier_curve_to(cx + 0.6312 * u, cy + -0.4531 * u, cx + 0.6406 * u, cy + -0.4625 * u, cx + 0.6406 * u, cy + -0.474 * u)
      p.line_to(cx + 0.6406 * u, cy + -0.6198 * u)
      p.bezier_curve_to(cx + 0.6406 * u, cy + -0.6312 * u, cx + 0.6312 * u, cy + -0.6406 * u, cx + 0.6198 * u, cy + -0.6406 * u)
      p.line_to(cx + 0.474 * u, cy + -0.6406 * u)
      p.bezier_curve_to(cx + 0.4625 * u, cy + -0.6406 * u, cx + 0.4531 * u, cy + -0.6312 * u, cx + 0.4531 * u, cy + -0.6198 * u)
      p.line_to(cx + 0.4531 * u, cy + -0.474 * u)
      p.bezier_curve_to(cx + 0.4531 * u, cy + -0.4625 * u, cx + 0.4625 * u, cy + -0.4531 * u, cx + 0.474 * u, cy + -0.4531 * u)
      p.close_path()
      p.move_to(cx + 0.9792 * u, cy + 0.0938 * u)
      p.line_to(cx + 0.8542 * u, cy + 0.0938 * u)
      p.bezier_curve_to(cx + 0.8427 * u, cy + 0.0938 * u, cx + 0.8333 * u, cy + 0.1031 * u, cx + 0.8333 * u, cy + 0.1146 * u)
      p.line_to(cx + 0.8333 * u, cy + 0.4635 * u)
      p.line_to(cx + 0.6302 * u, cy + 0.4635 * u)
      p.line_to(cx + 0.6302 * u, cy + 0.1146 * u)
      p.bezier_curve_to(cx + 0.6302 * u, cy + 0.1031 * u, cx + 0.6208 * u, cy + 0.0938 * u, cx + 0.6094 * u, cy + 0.0938 * u)
      p.line_to(cx + 0.1146 * u, cy + 0.0938 * u)
      p.bezier_curve_to(cx + 0.1031 * u, cy + 0.0938 * u, cx + 0.0938 * u, cy + 0.1031 * u, cx + 0.0938 * u, cy + 0.1146 * u)
      p.line_to(cx + 0.0938 * u, cy + 0.9792 * u)
      p.bezier_curve_to(cx + 0.0938 * u, cy + 0.9906 * u, cx + 0.1031 * u, cy + 1 * u, cx + 0.1146 * u, cy + 1 * u)
      p.line_to(cx + 0.2396 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.251 * u, cy + 1 * u, cx + 0.2604 * u, cy + 0.9906 * u, cx + 0.2604 * u, cy + 0.9792 * u)
      p.line_to(cx + 0.2604 * u, cy + 0.3438 * u)
      p.line_to(cx + 0.4635 * u, cy + 0.3438 * u)
      p.line_to(cx + 0.4635 * u, cy + 0.6094 * u)
      p.bezier_curve_to(cx + 0.4635 * u, cy + 0.6208 * u, cx + 0.4729 * u, cy + 0.6302 * u, cx + 0.4844 * u, cy + 0.6302 * u)
      p.line_to(cx + 0.9792 * u, cy + 0.6302 * u)
      p.bezier_curve_to(cx + 0.9906 * u, cy + 0.6302 * u, cx + 1 * u, cy + 0.6208 * u, cx + 1 * u, cy + 0.6094 * u)
      p.line_to(cx + 1 * u, cy + 0.1146 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.1031 * u, cx + 0.9906 * u, cy + 0.0938 * u, cx + 0.9792 * u, cy + 0.0938 * u)
      p.close_path()
      p.move_to(cx + 0.6094 * u, cy + 0.8333 * u)
      p.line_to(cx + 0.4844 * u, cy + 0.8333 * u)
      p.bezier_curve_to(cx + 0.4729 * u, cy + 0.8333 * u, cx + 0.4635 * u, cy + 0.8427 * u, cx + 0.4635 * u, cy + 0.8542 * u)
      p.line_to(cx + 0.4635 * u, cy + 0.9792 * u)
      p.bezier_curve_to(cx + 0.4635 * u, cy + 0.9906 * u, cx + 0.4729 * u, cy + 1 * u, cx + 0.4844 * u, cy + 1 * u)
      p.line_to(cx + 0.6094 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.6208 * u, cy + 1 * u, cx + 0.6302 * u, cy + 0.9906 * u, cx + 0.6302 * u, cy + 0.9792 * u)
      p.line_to(cx + 0.6302 * u, cy + 0.8542 * u)
      p.bezier_curve_to(cx + 0.6302 * u, cy + 0.8427 * u, cx + 0.6208 * u, cy + 0.8333 * u, cx + 0.6094 * u, cy + 0.8333 * u)
      p.close_path()
      p.move_to(cx + 0.9792 * u, cy + 0.8333 * u)
      p.line_to(cx + 0.8542 * u, cy + 0.8333 * u)
      p.bezier_curve_to(cx + 0.8427 * u, cy + 0.8333 * u, cx + 0.8333 * u, cy + 0.8427 * u, cx + 0.8333 * u, cy + 0.8542 * u)
      p.line_to(cx + 0.8333 * u, cy + 0.9792 * u)
      p.bezier_curve_to(cx + 0.8333 * u, cy + 0.9906 * u, cx + 0.8427 * u, cy + 1 * u, cx + 0.8542 * u, cy + 1 * u)
      p.line_to(cx + 0.9792 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.9906 * u, cy + 1 * u, cx + 1 * u, cy + 0.9906 * u, cx + 1 * u, cy + 0.9792 * u)
      p.line_to(cx + 1 * u, cy + 0.8542 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.8427 * u, cx + 0.9906 * u, cy + 0.8333 * u, cx + 0.9792 * u, cy + 0.8333 * u)
      p.close_path()
      p.fill()
    }
    YhBarcode => { // barcode
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.6667 * u, cy + -1 * u)
      p.line_to(cx + -0.6667 * u, cy + 1 * u)
      p.line_to(cx + -1 * u, cy + 1 * u)
      p.line_to(cx + -1 * u, cy + -1 * u)
      p.line_to(cx + -0.6667 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 1 * u, cy + -1 * u)
      p.line_to(cx + 1 * u, cy + 1 * u)
      p.line_to(cx + 0.6667 * u, cy + 1 * u)
      p.line_to(cx + 0.6667 * u, cy + -1 * u)
      p.line_to(cx + 1 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.5 * u, cy + -1 * u)
      p.line_to(cx + 0.5 * u, cy + 1 * u)
      p.line_to(cx + 0.3333 * u, cy + 1 * u)
      p.line_to(cx + 0.3333 * u, cy + -1 * u)
      p.line_to(cx + 0.5 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.1667 * u, cy + -1 * u)
      p.line_to(cx + 0.1667 * u, cy + 1 * u)
      p.line_to(cx + -0.1667 * u, cy + 1 * u)
      p.line_to(cx + -0.1667 * u, cy + -1 * u)
      p.line_to(cx + 0.1667 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + -0.3333 * u, cy + -1 * u)
      p.line_to(cx + -0.3333 * u, cy + 1 * u)
      p.line_to(cx + -0.5 * u, cy + 1 * u)
      p.line_to(cx + -0.5 * u, cy + -1 * u)
      p.line_to(cx + -0.3333 * u, cy + -1 * u)
      p.close_path()
      p.fill()
    }
    YhScan => { // scan
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.94 * u, cy + -0.32 * u)
      p.line_to(cx + -0.8 * u, cy + -0.32 * u)
      p.bezier_curve_to(cx + -0.789 * u, cy + -0.32 * u, cx + -0.78 * u, cy + -0.329 * u, cx + -0.78 * u, cy + -0.34 * u)
      p.line_to(cx + -0.78 * u, cy + -0.78 * u)
      p.line_to(cx + -0.34 * u, cy + -0.78 * u)
      p.bezier_curve_to(cx + -0.329 * u, cy + -0.78 * u, cx + -0.32 * u, cy + -0.789 * u, cx + -0.32 * u, cy + -0.8 * u)
      p.line_to(cx + -0.32 * u, cy + -0.94 * u)
      p.bezier_curve_to(cx + -0.32 * u, cy + -0.951 * u, cx + -0.329 * u, cy + -0.96 * u, cx + -0.34 * u, cy + -0.96 * u)
      p.line_to(cx + -0.79 * u, cy + -0.96 * u)
      p.bezier_curve_to(cx + -0.884 * u, cy + -0.96 * u, cx + -0.96 * u, cy + -0.884 * u, cx + -0.96 * u, cy + -0.79 * u)
      p.line_to(cx + -0.96 * u, cy + -0.34 * u)
      p.bezier_curve_to(cx + -0.96 * u, cy + -0.329 * u, cx + -0.951 * u, cy + -0.32 * u, cx + -0.94 * u, cy + -0.32 * u)
      p.close_path()
      p.move_to(cx + 0.34 * u, cy + -0.78 * u)
      p.line_to(cx + 0.78 * u, cy + -0.78 * u)
      p.line_to(cx + 0.78 * u, cy + -0.34 * u)
      p.bezier_curve_to(cx + 0.78 * u, cy + -0.329 * u, cx + 0.789 * u, cy + -0.32 * u, cx + 0.8 * u, cy + -0.32 * u)
      p.line_to(cx + 0.94 * u, cy + -0.32 * u)
      p.bezier_curve_to(cx + 0.951 * u, cy + -0.32 * u, cx + 0.96 * u, cy + -0.329 * u, cx + 0.96 * u, cy + -0.34 * u)
      p.line_to(cx + 0.96 * u, cy + -0.79 * u)
      p.bezier_curve_to(cx + 0.96 * u, cy + -0.884 * u, cx + 0.884 * u, cy + -0.96 * u, cx + 0.79 * u, cy + -0.96 * u)
      p.line_to(cx + 0.34 * u, cy + -0.96 * u)
      p.bezier_curve_to(cx + 0.329 * u, cy + -0.96 * u, cx + 0.32 * u, cy + -0.951 * u, cx + 0.32 * u, cy + -0.94 * u)
      p.line_to(cx + 0.32 * u, cy + -0.8 * u)
      p.bezier_curve_to(cx + 0.32 * u, cy + -0.789 * u, cx + 0.329 * u, cy + -0.78 * u, cx + 0.34 * u, cy + -0.78 * u)
      p.close_path()
      p.move_to(cx + -0.34 * u, cy + 0.78 * u)
      p.line_to(cx + -0.78 * u, cy + 0.78 * u)
      p.line_to(cx + -0.78 * u, cy + 0.34 * u)
      p.bezier_curve_to(cx + -0.78 * u, cy + 0.329 * u, cx + -0.789 * u, cy + 0.32 * u, cx + -0.8 * u, cy + 0.32 * u)
      p.line_to(cx + -0.94 * u, cy + 0.32 * u)
      p.bezier_curve_to(cx + -0.951 * u, cy + 0.32 * u, cx + -0.96 * u, cy + 0.329 * u, cx + -0.96 * u, cy + 0.34 * u)
      p.line_to(cx + -0.96 * u, cy + 0.79 * u)
      p.bezier_curve_to(cx + -0.96 * u, cy + 0.884 * u, cx + -0.884 * u, cy + 0.96 * u, cx + -0.79 * u, cy + 0.96 * u)
      p.line_to(cx + -0.34 * u, cy + 0.96 * u)
      p.bezier_curve_to(cx + -0.329 * u, cy + 0.96 * u, cx + -0.32 * u, cy + 0.951 * u, cx + -0.32 * u, cy + 0.94 * u)
      p.line_to(cx + -0.32 * u, cy + 0.8 * u)
      p.bezier_curve_to(cx + -0.32 * u, cy + 0.789 * u, cx + -0.329 * u, cy + 0.78 * u, cx + -0.34 * u, cy + 0.78 * u)
      p.close_path()
      p.move_to(cx + 0.94 * u, cy + 0.32 * u)
      p.line_to(cx + 0.8 * u, cy + 0.32 * u)
      p.bezier_curve_to(cx + 0.789 * u, cy + 0.32 * u, cx + 0.78 * u, cy + 0.329 * u, cx + 0.78 * u, cy + 0.34 * u)
      p.line_to(cx + 0.78 * u, cy + 0.78 * u)
      p.line_to(cx + 0.34 * u, cy + 0.78 * u)
      p.bezier_curve_to(cx + 0.329 * u, cy + 0.78 * u, cx + 0.32 * u, cy + 0.789 * u, cx + 0.32 * u, cy + 0.8 * u)
      p.line_to(cx + 0.32 * u, cy + 0.94 * u)
      p.bezier_curve_to(cx + 0.32 * u, cy + 0.951 * u, cx + 0.329 * u, cy + 0.96 * u, cx + 0.34 * u, cy + 0.96 * u)
      p.line_to(cx + 0.79 * u, cy + 0.96 * u)
      p.bezier_curve_to(cx + 0.884 * u, cy + 0.96 * u, cx + 0.96 * u, cy + 0.884 * u, cx + 0.96 * u, cy + 0.79 * u)
      p.line_to(cx + 0.96 * u, cy + 0.34 * u)
      p.bezier_curve_to(cx + 0.96 * u, cy + 0.329 * u, cx + 0.951 * u, cy + 0.32 * u, cx + 0.94 * u, cy + 0.32 * u)
      p.close_path()
      p.move_to(cx + 0.98 * u, cy + -0.09 * u)
      p.line_to(cx + -0.98 * u, cy + -0.09 * u)
      p.bezier_curve_to(cx + -0.991 * u, cy + -0.09 * u, cx + -1 * u, cy + -0.081 * u, cx + -1 * u, cy + -0.07 * u)
      p.line_to(cx + -1 * u, cy + 0.07 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.081 * u, cx + -0.991 * u, cy + 0.09 * u, cx + -0.98 * u, cy + 0.09 * u)
      p.line_to(cx + 0.98 * u, cy + 0.09 * u)
      p.bezier_curve_to(cx + 0.991 * u, cy + 0.09 * u, cx + 1 * u, cy + 0.081 * u, cx + 1 * u, cy + 0.07 * u)
      p.line_to(cx + 1 * u, cy + -0.07 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.081 * u, cx + 0.991 * u, cy + -0.09 * u, cx + 0.98 * u, cy + -0.09 * u)
      p.close_path()
      p.fill()
    }
    YhLaptop => { // laptop
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9834 * u, cy + 0.7369 * u)
      p.line_to(cx + 0.8496 * u, cy + 0.2655 * u)
      p.line_to(cx + 0.8496 * u, cy + -0.7611 * u)
      p.bezier_curve_to(cx + 0.8496 * u, cy + -0.8002 * u, cx + 0.8179 * u, cy + -0.8319 * u, cx + 0.7788 * u, cy + -0.8319 * u)
      p.line_to(cx + -0.7788 * u, cy + -0.8319 * u)
      p.bezier_curve_to(cx + -0.8179 * u, cy + -0.8319 * u, cx + -0.8496 * u, cy + -0.8002 * u, cx + -0.8496 * u, cy + -0.7611 * u)
      p.line_to(cx + -0.8496 * u, cy + 0.2655 * u)
      p.line_to(cx + -0.9834 * u, cy + 0.7369 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.7832 * u, cx + -0.9659 * u, cy + 0.8319 * u, cx + -0.9168 * u, cy + 0.8319 * u)
      p.line_to(cx + 0.9168 * u, cy + 0.8319 * u)
      p.bezier_curve_to(cx + 0.9659 * u, cy + 0.8319 * u, cx + 1 * u, cy + 0.7832 * u, cx + 0.9834 * u, cy + 0.7369 * u)
      p.close_path()
      p.move_to(cx + -0.6903 * u, cy + -0.6726 * u)
      p.line_to(cx + 0.6903 * u, cy + -0.6726 * u)
      p.line_to(cx + 0.6903 * u, cy + 0.2013 * u)
      p.line_to(cx + -0.6903 * u, cy + 0.2013 * u)
      p.line_to(cx + -0.6903 * u, cy + -0.6726 * u)
      p.close_path()
      p.move_to(cx + -0.1852 * u, cy + 0.6726 * u)
      p.line_to(cx + -0.1673 * u, cy + 0.5907 * u)
      p.line_to(cx + 0.1653 * u, cy + 0.5907 * u)
      p.line_to(cx + 0.1832 * u, cy + 0.6726 * u)
      p.line_to(cx + -0.1852 * u, cy + 0.6726 * u)
      p.close_path()
      p.move_to(cx + 0.3104 * u, cy + 0.6726 * u)
      p.line_to(cx + 0.2681 * u, cy + 0.4808 * u)
      p.bezier_curve_to(cx + 0.2664 * u, cy + 0.4726 * u, cx + 0.2591 * u, cy + 0.4668 * u, cx + 0.2509 * u, cy + 0.4668 * u)
      p.line_to(cx + -0.2527 * u, cy + 0.4668 * u)
      p.bezier_curve_to(cx + -0.2611 * u, cy + 0.4668 * u, cx + -0.2681 * u, cy + 0.4726 * u, cx + -0.2699 * u, cy + 0.4808 * u)
      p.line_to(cx + -0.3122 * u, cy + 0.6726 * u)
      p.line_to(cx + -0.7996 * u, cy + 0.6726 * u)
      p.line_to(cx + -0.706 * u, cy + 0.3429 * u)
      p.line_to(cx + 0.706 * u, cy + 0.3429 * u)
      p.line_to(cx + 0.7996 * u, cy + 0.6726 * u)
      p.line_to(cx + 0.3104 * u, cy + 0.6726 * u)
      p.close_path()
      p.fill()
    }
    YhTablet => { // tablet
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.6429 * u, cy + -1 * u)
      p.line_to(cx + -0.6429 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.7217 * u, cy + -1 * u, cx + -0.7857 * u, cy + -0.9359 * u, cx + -0.7857 * u, cy + -0.8571 * u)
      p.line_to(cx + -0.7857 * u, cy + 0.8571 * u)
      p.bezier_curve_to(cx + -0.7857 * u, cy + 0.9359 * u, cx + -0.7217 * u, cy + 1 * u, cx + -0.6429 * u, cy + 1 * u)
      p.line_to(cx + 0.6429 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.7217 * u, cy + 1 * u, cx + 0.7857 * u, cy + 0.9359 * u, cx + 0.7857 * u, cy + 0.8571 * u)
      p.line_to(cx + 0.7857 * u, cy + -0.8571 * u)
      p.bezier_curve_to(cx + 0.7857 * u, cy + -0.9359 * u, cx + 0.7217 * u, cy + -1 * u, cx + 0.6429 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + 0.8393 * u)
      p.line_to(cx + -0.625 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.625 * u, cy + -0.8393 * u)
      p.line_to(cx + 0.625 * u, cy + 0.8393 * u)
      p.close_path()
      p.move_to(cx + 0 * u, cy + 0.6071 * u)
      p.close_path()
      p.move_to(cx + -0.0893 * u, cy + 0.6071 * u)
      p.line_to(cx + -0.0881 * u, cy + 0.6218 * u)
      p.line_to(cx + -0.0844 * u, cy + 0.6361 * u)
      p.line_to(cx + -0.0785 * u, cy + 0.6496 * u)
      p.line_to(cx + -0.0705 * u, cy + 0.662 * u)
      p.line_to(cx + -0.0605 * u, cy + 0.6728 * u)
      p.line_to(cx + -0.0488 * u, cy + 0.6819 * u)
      p.line_to(cx + -0.0359 * u, cy + 0.6889 * u)
      p.line_to(cx + -0.0219 * u, cy + 0.6937 * u)
      p.line_to(cx + -0.0074 * u, cy + 0.6961 * u)
      p.line_to(cx + 0.0074 * u, cy + 0.6961 * u)
      p.line_to(cx + 0.0219 * u, cy + 0.6937 * u)
      p.line_to(cx + 0.0359 * u, cy + 0.6889 * u)
      p.line_to(cx + 0.0488 * u, cy + 0.6819 * u)
      p.line_to(cx + 0.0605 * u, cy + 0.6728 * u)
      p.line_to(cx + 0.0705 * u, cy + 0.662 * u)
      p.line_to(cx + 0.0785 * u, cy + 0.6496 * u)
      p.line_to(cx + 0.0844 * u, cy + 0.6361 * u)
      p.line_to(cx + 0.0881 * u, cy + 0.6218 * u)
      p.line_to(cx + 0.0893 * u, cy + 0.6071 * u)
      p.line_to(cx + 0.0881 * u, cy + 0.5924 * u)
      p.line_to(cx + 0.0844 * u, cy + 0.5782 * u)
      p.line_to(cx + 0.0785 * u, cy + 0.5646 * u)
      p.line_to(cx + 0.0705 * u, cy + 0.5523 * u)
      p.line_to(cx + 0.0605 * u, cy + 0.5415 * u)
      p.line_to(cx + 0.0488 * u, cy + 0.5324 * u)
      p.line_to(cx + 0.0359 * u, cy + 0.5254 * u)
      p.line_to(cx + 0.0219 * u, cy + 0.5206 * u)
      p.line_to(cx + 0.0074 * u, cy + 0.5182 * u)
      p.line_to(cx + -0.0074 * u, cy + 0.5182 * u)
      p.line_to(cx + -0.0219 * u, cy + 0.5206 * u)
      p.line_to(cx + -0.0359 * u, cy + 0.5254 * u)
      p.line_to(cx + -0.0488 * u, cy + 0.5324 * u)
      p.line_to(cx + -0.0605 * u, cy + 0.5415 * u)
      p.line_to(cx + -0.0705 * u, cy + 0.5523 * u)
      p.line_to(cx + -0.0785 * u, cy + 0.5646 * u)
      p.line_to(cx + -0.0844 * u, cy + 0.5782 * u)
      p.line_to(cx + -0.0881 * u, cy + 0.5924 * u)
      p.line_to(cx + -0.0893 * u, cy + 0.6071 * u)
      p.close_path()
      p.fill()
    }
    YhUsb => { // USB
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.62 * u, cy + -0.2 * u)
      p.line_to(cx + 0.62 * u, cy + -0.92 * u)
      p.bezier_curve_to(cx + 0.62 * u, cy + -0.9643 * u, cx + 0.5843 * u, cy + -1 * u, cx + 0.54 * u, cy + -1 * u)
      p.line_to(cx + -0.54 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.5843 * u, cy + -1 * u, cx + -0.62 * u, cy + -0.9643 * u, cx + -0.62 * u, cy + -0.92 * u)
      p.line_to(cx + -0.62 * u, cy + -0.2 * u)
      p.bezier_curve_to(cx + -0.7855 * u, cy + -0.2 * u, cx + -0.92 * u, cy + -0.0698 * u, cx + -0.92 * u, cy + 0.09 * u)
      p.line_to(cx + -0.92 * u, cy + 0.98 * u)
      p.bezier_curve_to(cx + -0.92 * u, cy + 0.991 * u, cx + -0.911 * u, cy + 1 * u, cx + -0.9 * u, cy + 1 * u)
      p.line_to(cx + -0.76 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.749 * u, cy + 1 * u, cx + -0.74 * u, cy + 0.991 * u, cx + -0.74 * u, cy + 0.98 * u)
      p.line_to(cx + -0.74 * u, cy + 0.09 * u)
      p.bezier_curve_to(cx + -0.74 * u, cy + 0.0293 * u, cx + -0.686 * u, cy + -0.02 * u, cx + -0.6198 * u, cy + -0.02 * u)
      p.line_to(cx + 0.6198 * u, cy + -0.02 * u)
      p.bezier_curve_to(cx + 0.686 * u, cy + -0.02 * u, cx + 0.74 * u, cy + 0.0293 * u, cx + 0.74 * u, cy + 0.09 * u)
      p.line_to(cx + 0.74 * u, cy + 0.98 * u)
      p.bezier_curve_to(cx + 0.74 * u, cy + 0.991 * u, cx + 0.749 * u, cy + 1 * u, cx + 0.76 * u, cy + 1 * u)
      p.line_to(cx + 0.9 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.911 * u, cy + 1 * u, cx + 0.92 * u, cy + 0.991 * u, cx + 0.92 * u, cy + 0.98 * u)
      p.line_to(cx + 0.92 * u, cy + 0.09 * u)
      p.bezier_curve_to(cx + 0.92 * u, cy + -0.0698 * u, cx + 0.7855 * u, cy + -0.2 * u, cx + 0.62 * u, cy + -0.2 * u)
      p.close_path()
      p.move_to(cx + -0.44 * u, cy + -0.2 * u)
      p.line_to(cx + -0.44 * u, cy + -0.82 * u)
      p.line_to(cx + 0.44 * u, cy + -0.82 * u)
      p.line_to(cx + 0.44 * u, cy + -0.2 * u)
      p.line_to(cx + -0.44 * u, cy + -0.2 * u)
      p.close_path()
      p.move_to(cx + -0.14 * u, cy + -0.66 * u)
      p.line_to(cx + -0.26 * u, cy + -0.66 * u)
      p.bezier_curve_to(cx + -0.271 * u, cy + -0.66 * u, cx + -0.28 * u, cy + -0.651 * u, cx + -0.28 * u, cy + -0.64 * u)
      p.line_to(cx + -0.28 * u, cy + -0.52 * u)
      p.bezier_curve_to(cx + -0.28 * u, cy + -0.509 * u, cx + -0.271 * u, cy + -0.5 * u, cx + -0.26 * u, cy + -0.5 * u)
      p.line_to(cx + -0.14 * u, cy + -0.5 * u)
      p.bezier_curve_to(cx + -0.129 * u, cy + -0.5 * u, cx + -0.12 * u, cy + -0.509 * u, cx + -0.12 * u, cy + -0.52 * u)
      p.line_to(cx + -0.12 * u, cy + -0.64 * u)
      p.bezier_curve_to(cx + -0.12 * u, cy + -0.651 * u, cx + -0.129 * u, cy + -0.66 * u, cx + -0.14 * u, cy + -0.66 * u)
      p.close_path()
      p.move_to(cx + 0.26 * u, cy + -0.66 * u)
      p.line_to(cx + 0.14 * u, cy + -0.66 * u)
      p.bezier_curve_to(cx + 0.129 * u, cy + -0.66 * u, cx + 0.12 * u, cy + -0.651 * u, cx + 0.12 * u, cy + -0.64 * u)
      p.line_to(cx + 0.12 * u, cy + -0.52 * u)
      p.bezier_curve_to(cx + 0.12 * u, cy + -0.509 * u, cx + 0.129 * u, cy + -0.5 * u, cx + 0.14 * u, cy + -0.5 * u)
      p.line_to(cx + 0.26 * u, cy + -0.5 * u)
      p.bezier_curve_to(cx + 0.271 * u, cy + -0.5 * u, cx + 0.28 * u, cy + -0.509 * u, cx + 0.28 * u, cy + -0.52 * u)
      p.line_to(cx + 0.28 * u, cy + -0.64 * u)
      p.bezier_curve_to(cx + 0.28 * u, cy + -0.651 * u, cx + 0.271 * u, cy + -0.66 * u, cx + 0.26 * u, cy + -0.66 * u)
      p.close_path()
      p.fill()
    }
    YhVideo => { // video
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.8929 * u, cy + -0.4681 * u)
      p.line_to(cx + 0.6071 * u, cy + -0.3036 * u)
      p.line_to(cx + 0.6071 * u, cy + -0.6429 * u)
      p.bezier_curve_to(cx + 0.6071 * u, cy + -0.7217 * u, cx + 0.5431 * u, cy + -0.7857 * u, cx + 0.4643 * u, cy + -0.7857 * u)
      p.line_to(cx + -0.8571 * u, cy + -0.7857 * u)
      p.bezier_curve_to(cx + -0.9359 * u, cy + -0.7857 * u, cx + -1 * u, cy + -0.7217 * u, cx + -1 * u, cy + -0.6429 * u)
      p.line_to(cx + -1 * u, cy + 0.6429 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.7217 * u, cx + -0.9359 * u, cy + 0.7857 * u, cx + -0.8571 * u, cy + 0.7857 * u)
      p.line_to(cx + 0.4643 * u, cy + 0.7857 * u)
      p.bezier_curve_to(cx + 0.5431 * u, cy + 0.7857 * u, cx + 0.6071 * u, cy + 0.7217 * u, cx + 0.6071 * u, cy + 0.6429 * u)
      p.line_to(cx + 0.6071 * u, cy + 0.3036 * u)
      p.line_to(cx + 0.8929 * u, cy + 0.4681 * u)
      p.bezier_curve_to(cx + 0.9404 * u, cy + 0.4955 * u, cx + 1 * u, cy + 0.4612 * u, cx + 1 * u, cy + 0.4065 * u)
      p.line_to(cx + 1 * u, cy + -0.4063 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.4612 * u, cx + 0.9404 * u, cy + -0.4955 * u, cx + 0.8929 * u, cy + -0.4681 * u)
      p.close_path()
      p.move_to(cx + 0.4464 * u, cy + 0.625 * u)
      p.line_to(cx + -0.8393 * u, cy + 0.625 * u)
      p.line_to(cx + -0.8393 * u, cy + -0.625 * u)
      p.line_to(cx + 0.4464 * u, cy + -0.625 * u)
      p.line_to(cx + 0.4464 * u, cy + 0.625 * u)
      p.close_path()
      p.move_to(cx + 0.8393 * u, cy + 0.2522 * u)
      p.line_to(cx + 0.6071 * u, cy + 0.1188 * u)
      p.line_to(cx + 0.6071 * u, cy + -0.1185 * u)
      p.line_to(cx + 0.8393 * u, cy + -0.2522 * u)
      p.line_to(cx + 0.8393 * u, cy + 0.2522 * u)
      p.close_path()
      p.move_to(cx + -0.6786 * u, cy + -0.3393 * u)
      p.line_to(cx + -0.4286 * u, cy + -0.3393 * u)
      p.bezier_curve_to(cx + -0.4188 * u, cy + -0.3393 * u, cx + -0.4107 * u, cy + -0.3473 * u, cx + -0.4107 * u, cy + -0.3571 * u)
      p.line_to(cx + -0.4107 * u, cy + -0.4643 * u)
      p.bezier_curve_to(cx + -0.4107 * u, cy + -0.4741 * u, cx + -0.4187 * u, cy + -0.4821 * u, cx + -0.4286 * u, cy + -0.4821 * u)
      p.line_to(cx + -0.6786 * u, cy + -0.4821 * u)
      p.bezier_curve_to(cx + -0.6884 * u, cy + -0.4821 * u, cx + -0.6964 * u, cy + -0.4741 * u, cx + -0.6964 * u, cy + -0.4643 * u)
      p.line_to(cx + -0.6964 * u, cy + -0.3571 * u)
      p.bezier_curve_to(cx + -0.6964 * u, cy + -0.3473 * u, cx + -0.6884 * u, cy + -0.3393 * u, cx + -0.6786 * u, cy + -0.3393 * u)
      p.close_path()
      p.fill()
    }
    YhAreaChart => { // area chart
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9792 * u, cy + 0.7292 * u)
      p.line_to(cx + -0.8125 * u, cy + 0.7292 * u)
      p.line_to(cx + -0.8125 * u, cy + -0.8958 * u)
      p.bezier_curve_to(cx + -0.8125 * u, cy + -0.9073 * u, cx + -0.8219 * u, cy + -0.9167 * u, cx + -0.8333 * u, cy + -0.9167 * u)
      p.line_to(cx + -0.9792 * u, cy + -0.9167 * u)
      p.bezier_curve_to(cx + -0.9906 * u, cy + -0.9167 * u, cx + -1 * u, cy + -0.9073 * u, cx + -1 * u, cy + -0.8958 * u)
      p.line_to(cx + -1 * u, cy + 0.8958 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9073 * u, cx + -0.9906 * u, cy + 0.9167 * u, cx + -0.9792 * u, cy + 0.9167 * u)
      p.line_to(cx + 0.9792 * u, cy + 0.9167 * u)
      p.bezier_curve_to(cx + 0.9906 * u, cy + 0.9167 * u, cx + 1 * u, cy + 0.9073 * u, cx + 1 * u, cy + 0.8958 * u)
      p.line_to(cx + 1 * u, cy + 0.75 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.7385 * u, cx + 0.9906 * u, cy + 0.7292 * u, cx + 0.9792 * u, cy + 0.7292 * u)
      p.close_path()
      p.move_to(cx + -0.625 * u, cy + 0.5625 * u)
      p.line_to(cx + 0.7708 * u, cy + 0.5625 * u)
      p.bezier_curve_to(cx + 0.7823 * u, cy + 0.5625 * u, cx + 0.7917 * u, cy + 0.5531 * u, cx + 0.7917 * u, cy + 0.5417 * u)
      p.line_to(cx + 0.7917 * u, cy + -0.5938 * u)
      p.bezier_curve_to(cx + 0.7917 * u, cy + -0.6125 * u, cx + 0.769 * u, cy + -0.6216 * u, cx + 0.756 * u, cy + -0.6086 * u)
      p.line_to(cx + 0.2083 * u, cy + -0.0609 * u)
      p.line_to(cx + -0.1182 * u, cy + -0.3839 * u)
      p.bezier_curve_to(cx + -0.1263 * u, cy + -0.3919 * u, cx + -0.1396 * u, cy + -0.3919 * u, cx + -0.1477 * u, cy + -0.3839 * u)
      p.line_to(cx + -0.6398 * u, cy + 0.1099 * u)
      p.bezier_curve_to(cx + -0.6438 * u, cy + 0.1138 * u, cx + -0.6458 * u, cy + 0.119 * u, cx + -0.6458 * u, cy + 0.1245 * u)
      p.line_to(cx + -0.6458 * u, cy + 0.5417 * u)
      p.bezier_curve_to(cx + -0.6458 * u, cy + 0.5531 * u, cx + -0.6365 * u, cy + 0.5625 * u, cx + -0.625 * u, cy + 0.5625 * u)
      p.close_path()
      p.fill()
    }
    YhLineChart => { // line chart
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9792 * u, cy + 0.7292 * u)
      p.line_to(cx + -0.8125 * u, cy + 0.7292 * u)
      p.line_to(cx + -0.8125 * u, cy + -0.8958 * u)
      p.bezier_curve_to(cx + -0.8125 * u, cy + -0.9073 * u, cx + -0.8219 * u, cy + -0.9167 * u, cx + -0.8333 * u, cy + -0.9167 * u)
      p.line_to(cx + -0.9792 * u, cy + -0.9167 * u)
      p.bezier_curve_to(cx + -0.9906 * u, cy + -0.9167 * u, cx + -1 * u, cy + -0.9073 * u, cx + -1 * u, cy + -0.8958 * u)
      p.line_to(cx + -1 * u, cy + 0.8958 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9073 * u, cx + -0.9906 * u, cy + 0.9167 * u, cx + -0.9792 * u, cy + 0.9167 * u)
      p.line_to(cx + 0.9792 * u, cy + 0.9167 * u)
      p.bezier_curve_to(cx + 0.9906 * u, cy + 0.9167 * u, cx + 1 * u, cy + 0.9073 * u, cx + 1 * u, cy + 0.8958 * u)
      p.line_to(cx + 1 * u, cy + 0.75 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.7385 * u, cx + 0.9906 * u, cy + 0.7292 * u, cx + 0.9792 * u, cy + 0.7292 * u)
      p.close_path()
      p.move_to(cx + -0.537 * u, cy + 0.3273 * u)
      p.bezier_curve_to(cx + -0.5289 * u, cy + 0.3354 * u, cx + -0.5159 * u, cy + 0.3354 * u, cx + -0.5076 * u, cy + 0.3273 * u)
      p.line_to(cx + -0.1474 * u, cy + -0.031 * u)
      p.line_to(cx + 0.1849 * u, cy + 0.3034 * u)
      p.bezier_curve_to(cx + 0.193 * u, cy + 0.3115 * u, cx + 0.2063 * u, cy + 0.3115 * u, cx + 0.2143 * u, cy + 0.3034 * u)
      p.line_to(cx + 0.9315 * u, cy + -0.4135 * u)
      p.bezier_curve_to(cx + 0.9396 * u, cy + -0.4216 * u, cx + 0.9396 * u, cy + -0.4349 * u, cx + 0.9315 * u, cy + -0.443 * u)
      p.line_to(cx + 0.8284 * u, cy + -0.5461 * u)
      p.bezier_curve_to(cx + 0.8203 * u, cy + -0.5542 * u, cx + 0.807 * u, cy + -0.5542 * u, cx + 0.799 * u, cy + -0.5461 * u)
      p.line_to(cx + 0.2 * u, cy + 0.0526 * u)
      p.line_to(cx + -0.1318 * u, cy + -0.2812 * u)
      p.bezier_curve_to(cx + -0.1398 * u, cy + -0.2893 * u, cx + -0.1531 * u, cy + -0.2893 * u, cx + -0.1612 * u, cy + -0.2812 * u)
      p.line_to(cx + -0.6398 * u, cy + 0.1945 * u)
      p.bezier_curve_to(cx + -0.6479 * u, cy + 0.2026 * u, cx + -0.6479 * u, cy + 0.2159 * u, cx + -0.6398 * u, cy + 0.224 * u)
      p.line_to(cx + -0.537 * u, cy + 0.3273 * u)
      p.close_path()
      p.fill()
    }
    YhRadarChart => { // radar chart
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9631 * u, cy + -0.2667 * u)
      p.line_to(cx + 0.0436 * u, cy + -0.9354 * u)
      p.line_to(cx + 0.0337 * u, cy + -0.9415 * u)
      p.line_to(cx + 0.023 * u, cy + -0.946 * u)
      p.line_to(cx + 0.0116 * u, cy + -0.9488 * u)
      p.line_to(cx + 0 * u, cy + -0.9497 * u)
      p.line_to(cx + -0.0116 * u, cy + -0.9488 * u)
      p.line_to(cx + -0.023 * u, cy + -0.946 * u)
      p.line_to(cx + -0.0337 * u, cy + -0.9415 * u)
      p.line_to(cx + -0.0436 * u, cy + -0.9354 * u)
      p.line_to(cx + -0.9631 * u, cy + -0.2667 * u)
      p.bezier_curve_to(cx + -0.9891 * u, cy + -0.2479 * u, cx + -1 * u, cy + -0.2142 * u, cx + -0.99 * u, cy + -0.1836 * u)
      p.line_to(cx + -0.6387 * u, cy + 0.8984 * u)
      p.bezier_curve_to(cx + -0.6287 * u, cy + 0.929 * u, cx + -0.6002 * u, cy + 0.9497 * u, cx + -0.5681 * u, cy + 0.9497 * u)
      p.line_to(cx + 0.5684 * u, cy + 0.9497 * u)
      p.bezier_curve_to(cx + 0.6007 * u, cy + 0.9497 * u, cx + 0.629 * u, cy + 0.929 * u, cx + 0.639 * u, cy + 0.8984 * u)
      p.line_to(cx + 0.9902 * u, cy + -0.1836 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.2142 * u, cx + 0.9891 * u, cy + -0.2477 * u, cx + 0.9631 * u, cy + -0.2667 * u)
      p.close_path()
      p.move_to(cx + 0.7583 * u, cy + -0.2205 * u)
      p.line_to(cx + 0.5296 * u, cy + -0.1462 * u)
      p.line_to(cx + 0.0652 * u, cy + -0.4822 * u)
      p.line_to(cx + 0.0652 * u, cy + -0.7246 * u)
      p.line_to(cx + 0.7583 * u, cy + -0.2205 * u)
      p.close_path()
      p.move_to(cx + -0.1068 * u, cy + 0.1282 * u)
      p.line_to(cx + -0.3137 * u, cy + 0.4122 * u)
      p.line_to(cx + -0.4418 * u, cy + 0.0193 * u)
      p.line_to(cx + -0.1068 * u, cy + 0.1282 * u)
      p.close_path()
      p.move_to(cx + -0.3768 * u, cy + -0.0965 * u)
      p.line_to(cx + -0.065 * u, cy + -0.322 * u)
      p.line_to(cx + -0.065 * u, cy + 0.0049 * u)
      p.line_to(cx + -0.3768 * u, cy + -0.0965 * u)
      p.close_path()
      p.move_to(cx + 0 * u, cy + 0.2025 * u)
      p.line_to(cx + 0.218 * u, cy + 0.5018 * u)
      p.line_to(cx + -0.218 * u, cy + 0.5018 * u)
      p.line_to(cx + 0 * u, cy + 0.2025 * u)
      p.close_path()
      p.move_to(cx + 0.0652 * u, cy + -0.322 * u)
      p.line_to(cx + 0.3768 * u, cy + -0.0965 * u)
      p.line_to(cx + 0.0652 * u, cy + 0.0047 * u)
      p.line_to(cx + 0.0652 * u, cy + -0.322 * u)
      p.close_path()
      p.move_to(cx + 0.1068 * u, cy + 0.1282 * u)
      p.line_to(cx + 0.4418 * u, cy + 0.0193 * u)
      p.line_to(cx + 0.3137 * u, cy + 0.4122 * u)
      p.line_to(cx + 0.1068 * u, cy + 0.1282 * u)
      p.close_path()
      p.move_to(cx + -0.065 * u, cy + -0.7246 * u)
      p.line_to(cx + -0.065 * u, cy + -0.4822 * u)
      p.line_to(cx + -0.5296 * u, cy + -0.1462 * u)
      p.line_to(cx + -0.7583 * u, cy + -0.2205 * u)
      p.line_to(cx + -0.065 * u, cy + -0.7246 * u)
      p.close_path()
      p.move_to(cx + -0.7957 * u, cy + -0.0956 * u)
      p.line_to(cx + -0.5948 * u, cy + -0.0304 * u)
      p.line_to(cx + -0.4082 * u, cy + 0.5417 * u)
      p.line_to(cx + -0.5331 * u, cy + 0.7133 * u)
      p.line_to(cx + -0.7957 * u, cy + -0.0956 * u)
      p.close_path()
      p.move_to(cx + -0.4293 * u, cy + 0.7918 * u)
      p.line_to(cx + -0.3125 * u, cy + 0.6316 * u)
      p.line_to(cx + 0.3127 * u, cy + 0.6316 * u)
      p.line_to(cx + 0.4295 * u, cy + 0.7918 * u)
      p.line_to(cx + -0.4293 * u, cy + 0.7918 * u)
      p.close_path()
      p.move_to(cx + 0.5331 * u, cy + 0.7133 * u)
      p.line_to(cx + 0.4082 * u, cy + 0.5417 * u)
      p.line_to(cx + 0.5948 * u, cy + -0.0304 * u)
      p.line_to(cx + 0.7957 * u, cy + -0.0956 * u)
      p.line_to(cx + 0.5331 * u, cy + 0.7133 * u)
      p.close_path()
      p.fill()
    }
    YhBoxplot => { // box plot
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9821 * u, cy + -0.6429 * u)
      p.line_to(cx + 0.8661 * u, cy + -0.6429 * u)
      p.bezier_curve_to(cx + 0.8563 * u, cy + -0.6429 * u, cx + 0.8482 * u, cy + -0.6348 * u, cx + 0.8482 * u, cy + -0.625 * u)
      p.line_to(cx + 0.8482 * u, cy + -0.0714 * u)
      p.line_to(cx + 0.6429 * u, cy + -0.0714 * u)
      p.line_to(cx + 0.6429 * u, cy + -0.4643 * u)
      p.bezier_curve_to(cx + 0.6429 * u, cy + -0.4741 * u, cx + 0.6348 * u, cy + -0.4821 * u, cx + 0.625 * u, cy + -0.4821 * u)
      p.line_to(cx + -0.625 * u, cy + -0.4821 * u)
      p.bezier_curve_to(cx + -0.6348 * u, cy + -0.4821 * u, cx + -0.6429 * u, cy + -0.4741 * u, cx + -0.6429 * u, cy + -0.4643 * u)
      p.line_to(cx + -0.6429 * u, cy + -0.0714 * u)
      p.line_to(cx + -0.8482 * u, cy + -0.0714 * u)
      p.line_to(cx + -0.8482 * u, cy + -0.625 * u)
      p.bezier_curve_to(cx + -0.8482 * u, cy + -0.6348 * u, cx + -0.8562 * u, cy + -0.6429 * u, cx + -0.8661 * u, cy + -0.6429 * u)
      p.line_to(cx + -0.9821 * u, cy + -0.6429 * u)
      p.bezier_curve_to(cx + -0.992 * u, cy + -0.6429 * u, cx + -1 * u, cy + -0.6348 * u, cx + -1 * u, cy + -0.625 * u)
      p.line_to(cx + -1 * u, cy + 0.625 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.6348 * u, cx + -0.992 * u, cy + 0.6429 * u, cx + -0.9821 * u, cy + 0.6429 * u)
      p.line_to(cx + -0.8661 * u, cy + 0.6429 * u)
      p.bezier_curve_to(cx + -0.8562 * u, cy + 0.6429 * u, cx + -0.8482 * u, cy + 0.6348 * u, cx + -0.8482 * u, cy + 0.625 * u)
      p.line_to(cx + -0.8482 * u, cy + 0.0804 * u)
      p.line_to(cx + -0.6429 * u, cy + 0.0804 * u)
      p.line_to(cx + -0.6429 * u, cy + 0.4643 * u)
      p.bezier_curve_to(cx + -0.6429 * u, cy + 0.4741 * u, cx + -0.6348 * u, cy + 0.4821 * u, cx + -0.625 * u, cy + 0.4821 * u)
      p.line_to(cx + 0.625 * u, cy + 0.4821 * u)
      p.bezier_curve_to(cx + 0.6348 * u, cy + 0.4821 * u, cx + 0.6429 * u, cy + 0.4741 * u, cx + 0.6429 * u, cy + 0.4643 * u)
      p.line_to(cx + 0.6429 * u, cy + 0.0804 * u)
      p.line_to(cx + 0.8482 * u, cy + 0.0804 * u)
      p.line_to(cx + 0.8482 * u, cy + 0.625 * u)
      p.bezier_curve_to(cx + 0.8482 * u, cy + 0.6348 * u, cx + 0.8562 * u, cy + 0.6429 * u, cx + 0.8661 * u, cy + 0.6429 * u)
      p.line_to(cx + 0.9821 * u, cy + 0.6429 * u)
      p.bezier_curve_to(cx + 0.992 * u, cy + 0.6429 * u, cx + 1 * u, cy + 0.6348 * u, cx + 1 * u, cy + 0.625 * u)
      p.line_to(cx + 1 * u, cy + -0.625 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.6348 * u, cx + 0.992 * u, cy + -0.6429 * u, cx + 0.9821 * u, cy + -0.6429 * u)
      p.close_path()
      p.move_to(cx + -0.4821 * u, cy + -0.3214 * u)
      p.line_to(cx + -0.2857 * u, cy + -0.3214 * u)
      p.line_to(cx + -0.2857 * u, cy + 0.3214 * u)
      p.line_to(cx + -0.4821 * u, cy + 0.3214 * u)
      p.line_to(cx + -0.4821 * u, cy + -0.3214 * u)
      p.close_path()
      p.move_to(cx + 0.4821 * u, cy + 0.3214 * u)
      p.line_to(cx + -0.1429 * u, cy + 0.3214 * u)
      p.line_to(cx + -0.1429 * u, cy + -0.3214 * u)
      p.line_to(cx + 0.4821 * u, cy + -0.3214 * u)
      p.line_to(cx + 0.4821 * u, cy + 0.3214 * u)
      p.close_path()
      p.fill()
    }
    YhDashboard => { // dashboard
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9214 * u, cy + -0.2821 * u)
      p.bezier_curve_to(cx + 0.871 * u, cy + -0.4013 * u, cx + 0.7989 * u, cy + -0.5083 * u, cx + 0.7071 * u, cy + -0.6 * u)
      p.bezier_curve_to(cx + 0.6154 * u, cy + -0.6917 * u, cx + 0.5085 * u, cy + -0.7638 * u, cx + 0.3893 * u, cy + -0.8143 * u)
      p.bezier_curve_to(cx + 0.2658 * u, cy + -0.8665 * u, cx + 0.135 * u, cy + -0.8929 * u, cx + 0 * u, cy + -0.8929 * u)
      p.bezier_curve_to(cx + -0.135 * u, cy + -0.8929 * u, cx + -0.2658 * u, cy + -0.8665 * u, cx + -0.3893 * u, cy + -0.8143 * u)
      p.bezier_curve_to(cx + -0.5085 * u, cy + -0.7638 * u, cx + -0.6154 * u, cy + -0.6917 * u, cx + -0.7071 * u, cy + -0.6 * u)
      p.bezier_curve_to(cx + -0.7989 * u, cy + -0.5083 * u, cx + -0.871 * u, cy + -0.4013 * u, cx + -0.9214 * u, cy + -0.2821 * u)
      p.bezier_curve_to(cx + -0.9737 * u, cy + -0.1587 * u, cx + -1 * u, cy + -0.0279 * u, cx + -1 * u, cy + 0.1071 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.4033 * u, cx + -0.8699 * u, cy + 0.6824 * u, cx + -0.6431 * u, cy + 0.873 * u)
      p.line_to(cx + -0.6393 * u, cy + 0.8761 * u)
      p.bezier_curve_to(cx + -0.6263 * u, cy + 0.8868 * u, cx + -0.61 * u, cy + 0.8929 * u, cx + -0.5933 * u, cy + 0.8929 * u)
      p.line_to(cx + 0.5935 * u, cy + 0.8929 * u)
      p.bezier_curve_to(cx + 0.6103 * u, cy + 0.8929 * u, cx + 0.6266 * u, cy + 0.8868 * u, cx + 0.6395 * u, cy + 0.8761 * u)
      p.line_to(cx + 0.6433 * u, cy + 0.873 * u)
      p.bezier_curve_to(cx + 0.8699 * u, cy + 0.6824 * u, cx + 1 * u, cy + 0.4033 * u, cx + 1 * u, cy + 0.1071 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.0279 * u, cx + 0.9734 * u, cy + -0.1587 * u, cx + 0.9214 * u, cy + -0.2821 * u)
      p.close_path()
      p.move_to(cx + 0.5567 * u, cy + 0.7232 * u)
      p.line_to(cx + -0.5567 * u, cy + 0.7232 * u)
      p.bezier_curve_to(cx + -0.731 * u, cy + 0.5658 * u, cx + -0.8304 * u, cy + 0.3429 * u, cx + -0.8304 * u, cy + 0.1071 * u)
      p.bezier_curve_to(cx + -0.8304 * u, cy + -0.1147 * u, cx + -0.744 * u, cy + -0.3232 * u, cx + -0.5871 * u, cy + -0.4799 * u)
      p.bezier_curve_to(cx + -0.4301 * u, cy + -0.6368 * u, cx + -0.2217 * u, cy + -0.7232 * u, cx + 0 * u, cy + -0.7232 * u)
      p.bezier_curve_to(cx + 0.2219 * u, cy + -0.7232 * u, cx + 0.4304 * u, cy + -0.6368 * u, cx + 0.5871 * u, cy + -0.4799 * u)
      p.bezier_curve_to(cx + 0.744 * u, cy + -0.323 * u, cx + 0.8304 * u, cy + -0.1145 * u, cx + 0.8304 * u, cy + 0.1071 * u)
      p.bezier_curve_to(cx + 0.8304 * u, cy + 0.3429 * u, cx + 0.731 * u, cy + 0.5658 * u, cx + 0.5567 * u, cy + 0.7232 * u)
      p.close_path()
      p.move_to(cx + 0.2489 * u, cy + -0.202 * u)
      p.bezier_curve_to(cx + 0.242 * u, cy + -0.2089 * u, cx + 0.2306 * u, cy + -0.2089 * u, cx + 0.2237 * u, cy + -0.202 * u)
      p.line_to(cx + 0.035 * u, cy + -0.0134 * u)
      p.bezier_curve_to(cx + -0.0067 * u, cy + -0.0246 * u, cx + -0.0529 * u, cy + -0.0138 * u, cx + -0.0857 * u, cy + 0.019 * u)
      p.bezier_curve_to(cx + -0.1346 * u, cy + 0.0679 * u, cx + -0.1346 * u, cy + 0.1469 * u, cx + -0.0857 * u, cy + 0.1958 * u)
      p.bezier_curve_to(cx + -0.0368 * u, cy + 0.2446 * u, cx + 0.0422 * u, cy + 0.2446 * u, cx + 0.0911 * u, cy + 0.1958 * u)
      p.bezier_curve_to(cx + 0.1239 * u, cy + 0.1629 * u, cx + 0.1346 * u, cy + 0.1167 * u, cx + 0.1234 * u, cy + 0.075 * u)
      p.line_to(cx + 0.3121 * u, cy + -0.1136 * u)
      p.bezier_curve_to(cx + 0.319 * u, cy + -0.1205 * u, cx + 0.319 * u, cy + -0.1319 * u, cx + 0.3121 * u, cy + -0.1388 * u)
      p.line_to(cx + 0.2489 * u, cy + -0.202 * u)
      p.close_path()
      p.move_to(cx + -0.0491 * u, cy + -0.4286 * u)
      p.line_to(cx + 0.0491 * u, cy + -0.4286 * u)
      p.bezier_curve_to(cx + 0.0589 * u, cy + -0.4286 * u, cx + 0.067 * u, cy + -0.4366 * u, cx + 0.067 * u, cy + -0.4464 * u)
      p.line_to(cx + 0.067 * u, cy + -0.625 * u)
      p.bezier_curve_to(cx + 0.067 * u, cy + -0.6348 * u, cx + 0.0589 * u, cy + -0.6429 * u, cx + 0.0491 * u, cy + -0.6429 * u)
      p.line_to(cx + -0.0491 * u, cy + -0.6429 * u)
      p.bezier_curve_to(cx + -0.0589 * u, cy + -0.6429 * u, cx + -0.067 * u, cy + -0.6348 * u, cx + -0.067 * u, cy + -0.625 * u)
      p.line_to(cx + -0.067 * u, cy + -0.4464 * u)
      p.bezier_curve_to(cx + -0.067 * u, cy + -0.4366 * u, cx + -0.0589 * u, cy + -0.4286 * u, cx + -0.0491 * u, cy + -0.4286 * u)
      p.close_path()
      p.move_to(cx + 0.5312 * u, cy + 0.058 * u)
      p.line_to(cx + 0.5312 * u, cy + 0.1563 * u)
      p.bezier_curve_to(cx + 0.5312 * u, cy + 0.1661 * u, cx + 0.5393 * u, cy + 0.1741 * u, cx + 0.5491 * u, cy + 0.1741 * u)
      p.line_to(cx + 0.7277 * u, cy + 0.1741 * u)
      p.bezier_curve_to(cx + 0.7375 * u, cy + 0.1741 * u, cx + 0.7455 * u, cy + 0.1661 * u, cx + 0.7455 * u, cy + 0.1563 * u)
      p.line_to(cx + 0.7455 * u, cy + 0.058 * u)
      p.bezier_curve_to(cx + 0.7455 * u, cy + 0.0482 * u, cx + 0.7375 * u, cy + 0.0402 * u, cx + 0.7277 * u, cy + 0.0402 * u)
      p.line_to(cx + 0.5491 * u, cy + 0.0402 * u)
      p.bezier_curve_to(cx + 0.5393 * u, cy + 0.0402 * u, cx + 0.5312 * u, cy + 0.0482 * u, cx + 0.5312 * u, cy + 0.058 * u)
      p.close_path()
      p.move_to(cx + 0.5596 * u, cy + -0.3821 * u)
      p.line_to(cx + 0.4902 * u, cy + -0.4516 * u)
      p.bezier_curve_to(cx + 0.4833 * u, cy + -0.4585 * u, cx + 0.4719 * u, cy + -0.4585 * u, cx + 0.465 * u, cy + -0.4516 * u)
      p.line_to(cx + 0.3386 * u, cy + -0.3252 * u)
      p.bezier_curve_to(cx + 0.3317 * u, cy + -0.3183 * u, cx + 0.3317 * u, cy + -0.3069 * u, cx + 0.3386 * u, cy + -0.3 * u)
      p.line_to(cx + 0.408 * u, cy + -0.2306 * u)
      p.bezier_curve_to(cx + 0.415 * u, cy + -0.2237 * u, cx + 0.4263 * u, cy + -0.2237 * u, cx + 0.4333 * u, cy + -0.2306 * u)
      p.line_to(cx + 0.5596 * u, cy + -0.3569 * u)
      p.bezier_curve_to(cx + 0.5665 * u, cy + -0.3638 * u, cx + 0.5665 * u, cy + -0.3752 * u, cx + 0.5596 * u, cy + -0.3821 * u)
      p.close_path()
      p.move_to(cx + -0.4641 * u, cy + -0.4516 * u)
      p.bezier_curve_to(cx + -0.471 * u, cy + -0.4585 * u, cx + -0.4824 * u, cy + -0.4585 * u, cx + -0.4893 * u, cy + -0.4516 * u)
      p.line_to(cx + -0.5587 * u, cy + -0.3821 * u)
      p.bezier_curve_to(cx + -0.5656 * u, cy + -0.3752 * u, cx + -0.5656 * u, cy + -0.3638 * u, cx + -0.5587 * u, cy + -0.3569 * u)
      p.line_to(cx + -0.4324 * u, cy + -0.2306 * u)
      p.bezier_curve_to(cx + -0.4254 * u, cy + -0.2237 * u, cx + -0.4141 * u, cy + -0.2237 * u, cx + -0.4071 * u, cy + -0.2306 * u)
      p.line_to(cx + -0.3377 * u, cy + -0.3 * u)
      p.bezier_curve_to(cx + -0.3308 * u, cy + -0.3069 * u, cx + -0.3308 * u, cy + -0.3183 * u, cx + -0.3377 * u, cy + -0.3252 * u)
      p.line_to(cx + -0.4641 * u, cy + -0.4516 * u)
      p.close_path()
      p.move_to(cx + -0.558 * u, cy + 0.0402 * u)
      p.line_to(cx + -0.7366 * u, cy + 0.0402 * u)
      p.bezier_curve_to(cx + -0.7464 * u, cy + 0.0402 * u, cx + -0.7545 * u, cy + 0.0482 * u, cx + -0.7545 * u, cy + 0.058 * u)
      p.line_to(cx + -0.7545 * u, cy + 0.1563 * u)
      p.bezier_curve_to(cx + -0.7545 * u, cy + 0.1661 * u, cx + -0.7464 * u, cy + 0.1741 * u, cx + -0.7366 * u, cy + 0.1741 * u)
      p.line_to(cx + -0.558 * u, cy + 0.1741 * u)
      p.bezier_curve_to(cx + -0.5482 * u, cy + 0.1741 * u, cx + -0.5402 * u, cy + 0.1661 * u, cx + -0.5402 * u, cy + 0.1563 * u)
      p.line_to(cx + -0.5402 * u, cy + 0.058 * u)
      p.bezier_curve_to(cx + -0.5402 * u, cy + 0.0482 * u, cx + -0.5482 * u, cy + 0.0402 * u, cx + -0.558 * u, cy + 0.0402 * u)
      p.close_path()
      p.fill()
    }
    YhIdcard => { // id card
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9286 * u, cy + -0.7857 * u)
      p.line_to(cx + -0.9286 * u, cy + -0.7857 * u)
      p.bezier_curve_to(cx + -0.9681 * u, cy + -0.7857 * u, cx + -1 * u, cy + -0.7538 * u, cx + -1 * u, cy + -0.7143 * u)
      p.line_to(cx + -1 * u, cy + 0.7143 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.7538 * u, cx + -0.9681 * u, cy + 0.7857 * u, cx + -0.9286 * u, cy + 0.7857 * u)
      p.line_to(cx + 0.9286 * u, cy + 0.7857 * u)
      p.bezier_curve_to(cx + 0.9681 * u, cy + 0.7857 * u, cx + 1 * u, cy + 0.7538 * u, cx + 1 * u, cy + 0.7143 * u)
      p.line_to(cx + 1 * u, cy + -0.7143 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.7538 * u, cx + 0.9681 * u, cy + -0.7857 * u, cx + 0.9286 * u, cy + -0.7857 * u)
      p.close_path()
      p.move_to(cx + 0.8393 * u, cy + 0.625 * u)
      p.line_to(cx + -0.8393 * u, cy + 0.625 * u)
      p.line_to(cx + -0.8393 * u, cy + -0.625 * u)
      p.line_to(cx + 0.8393 * u, cy + -0.625 * u)
      p.line_to(cx + 0.8393 * u, cy + 0.625 * u)
      p.close_path()
      p.move_to(cx + 0.2194 * u, cy + -0.0804 * u)
      p.line_to(cx + 0.4949 * u, cy + -0.0804 * u)
      p.bezier_curve_to(cx + 0.4978 * u, cy + -0.0804 * u, cx + 0.5 * u, cy + -0.0884 * u, cx + 0.5 * u, cy + -0.0982 * u)
      p.line_to(cx + 0.5 * u, cy + -0.2054 * u)
      p.bezier_curve_to(cx + 0.5 * u, cy + -0.2152 * u, cx + 0.4978 * u, cy + -0.2232 * u, cx + 0.4949 * u, cy + -0.2232 * u)
      p.line_to(cx + 0.2194 * u, cy + -0.2232 * u)
      p.bezier_curve_to(cx + 0.2165 * u, cy + -0.2232 * u, cx + 0.2143 * u, cy + -0.2152 * u, cx + 0.2143 * u, cy + -0.2054 * u)
      p.line_to(cx + 0.2143 * u, cy + -0.0982 * u)
      p.bezier_curve_to(cx + 0.2143 * u, cy + -0.0884 * u, cx + 0.2165 * u, cy + -0.0804 * u, cx + 0.2194 * u, cy + -0.0804 * u)
      p.close_path()
      p.move_to(cx + 0.2301 * u, cy + 0.2411 * u)
      p.line_to(cx + 0.6446 * u, cy + 0.2411 * u)
      p.bezier_curve_to(cx + 0.6533 * u, cy + 0.2411 * u, cx + 0.6605 * u, cy + 0.233 * u, cx + 0.6605 * u, cy + 0.2232 * u)
      p.line_to(cx + 0.6605 * u, cy + 0.1161 * u)
      p.bezier_curve_to(cx + 0.6605 * u, cy + 0.1063 * u, cx + 0.6533 * u, cy + 0.0982 * u, cx + 0.6446 * u, cy + 0.0982 * u)
      p.line_to(cx + 0.2301 * u, cy + 0.0982 * u)
      p.bezier_curve_to(cx + 0.2214 * u, cy + 0.0982 * u, cx + 0.2143 * u, cy + 0.1062 * u, cx + 0.2143 * u, cy + 0.1161 * u)
      p.line_to(cx + 0.2143 * u, cy + 0.2232 * u)
      p.bezier_curve_to(cx + 0.2143 * u, cy + 0.233 * u, cx + 0.2214 * u, cy + 0.2411 * u, cx + 0.2301 * u, cy + 0.2411 * u)
      p.close_path()
      p.move_to(cx + -0.6429 * u, cy + 0.3594 * u)
      p.line_to(cx + -0.5449 * u, cy + 0.3594 * u)
      p.bezier_curve_to(cx + -0.5355 * u, cy + 0.3594 * u, cx + -0.5279 * u, cy + 0.352 * u, cx + -0.5272 * u, cy + 0.3426 * u)
      p.bezier_curve_to(cx + -0.5187 * u, cy + 0.2299 * u, cx + -0.4246 * u, cy + 0.1406 * u, cx + -0.3103 * u, cy + 0.1406 * u)
      p.bezier_curve_to(cx + -0.196 * u, cy + 0.1406 * u, cx + -0.1018 * u, cy + 0.2299 * u, cx + -0.0933 * u, cy + 0.3426 * u)
      p.bezier_curve_to(cx + -0.0926 * u, cy + 0.352 * u, cx + -0.085 * u, cy + 0.3594 * u, cx + -0.0757 * u, cy + 0.3594 * u)
      p.line_to(cx + 0.0223 * u, cy + 0.3594 * u)
      p.bezier_curve_to(cx + 0.0326 * u, cy + 0.3594 * u, cx + 0.0406 * u, cy + 0.3509 * u, cx + 0.0402 * u, cy + 0.3406 * u)
      p.bezier_curve_to(cx + 0.0339 * u, cy + 0.2217 * u, cx + -0.0312 * u, cy + 0.1181 * u, cx + -0.1263 * u, cy + 0.0592 * u)
      p.bezier_curve_to(cx + -0.0859 * u, cy + 0.0147 * u, cx + -0.0614 * u, cy + -0.0444 * u, cx + -0.0614 * u, cy + -0.1094 * u)
      p.bezier_curve_to(cx + -0.0614 * u, cy + -0.2475 * u, cx + -0.1728 * u, cy + -0.3594 * u, cx + -0.31 * u, cy + -0.3594 * u)
      p.bezier_curve_to(cx + -0.4473 * u, cy + -0.3594 * u, cx + -0.5587 * u, cy + -0.2475 * u, cx + -0.5587 * u, cy + -0.1094 * u)
      p.bezier_curve_to(cx + -0.5587 * u, cy + -0.0444 * u, cx + -0.5342 * u, cy + 0.0145 * u, cx + -0.4937 * u, cy + 0.0592 * u)
      p.bezier_curve_to(cx + -0.5891 * u, cy + 0.1183 * u, cx + -0.654 * u, cy + 0.2217 * u, cx + -0.6603 * u, cy + 0.3406 * u)
      p.bezier_curve_to(cx + -0.6612 * u, cy + 0.3509 * u, cx + -0.6531 * u, cy + 0.3594 * u, cx + -0.6429 * u, cy + 0.3594 * u)
      p.close_path()
      p.move_to(cx + -0.3103 * u, cy + -0.2254 * u)
      p.bezier_curve_to(cx + -0.2467 * u, cy + -0.2254 * u, cx + -0.1949 * u, cy + -0.1734 * u, cx + -0.1949 * u, cy + -0.1094 * u)
      p.bezier_curve_to(cx + -0.1949 * u, cy + -0.0453 * u, cx + -0.2467 * u, cy + 0.0067 * u, cx + -0.3103 * u, cy + 0.0067 * u)
      p.bezier_curve_to(cx + -0.3739 * u, cy + 0.0067 * u, cx + -0.4257 * u, cy + -0.0453 * u, cx + -0.4257 * u, cy + -0.1094 * u)
      p.bezier_curve_to(cx + -0.4257 * u, cy + -0.1734 * u, cx + -0.3739 * u, cy + -0.2254 * u, cx + -0.3103 * u, cy + -0.2254 * u)
      p.close_path()
      p.fill()
    }
    YhContacts => { // contacts
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.1837 * u, cy + 0.1998 * u)
      p.bezier_curve_to(cx + 0.2241 * u, cy + 0.1554 * u, cx + 0.2487 * u, cy + 0.0962 * u, cx + 0.2487 * u, cy + 0.0313 * u)
      p.bezier_curve_to(cx + 0.2487 * u, cy + -0.1069 * u, cx + 0.1373 * u, cy + -0.2187 * u, cx + 0 * u, cy + -0.2187 * u)
      p.bezier_curve_to(cx + -0.1373 * u, cy + -0.2187 * u, cx + -0.2487 * u, cy + -0.1069 * u, cx + -0.2487 * u, cy + 0.0313 * u)
      p.bezier_curve_to(cx + -0.2487 * u, cy + 0.0962 * u, cx + -0.2241 * u, cy + 0.1551 * u, cx + -0.1837 * u, cy + 0.1998 * u)
      p.bezier_curve_to(cx + -0.279 * u, cy + 0.2589 * u, cx + -0.344 * u, cy + 0.3623 * u, cx + -0.3502 * u, cy + 0.4813 * u)
      p.bezier_curve_to(cx + -0.3507 * u, cy + 0.4915 * u, cx + -0.3426 * u, cy + 0.5 * u, cx + -0.3324 * u, cy + 0.5 * u)
      p.line_to(cx + -0.2344 * u, cy + 0.5 * u)
      p.bezier_curve_to(cx + -0.225 * u, cy + 0.5 * u, cx + -0.2174 * u, cy + 0.4926 * u, cx + -0.2167 * u, cy + 0.4833 * u)
      p.bezier_curve_to(cx + -0.2083 * u, cy + 0.3703 * u, cx + -0.1141 * u, cy + 0.2812 * u, cx + 0.0002 * u, cy + 0.2813 * u)
      p.bezier_curve_to(cx + 0.1145 * u, cy + 0.2813 * u, cx + 0.2087 * u, cy + 0.3705 * u, cx + 0.2172 * u, cy + 0.4833 * u)
      p.bezier_curve_to(cx + 0.2179 * u, cy + 0.4926 * u, cx + 0.2254 * u, cy + 0.5 * u, cx + 0.2348 * u, cy + 0.5 * u)
      p.line_to(cx + 0.3326 * u, cy + 0.5 * u)
      p.bezier_curve_to(cx + 0.3429 * u, cy + 0.5 * u, cx + 0.3509 * u, cy + 0.4915 * u, cx + 0.3504 * u, cy + 0.4813 * u)
      p.bezier_curve_to(cx + 0.3442 * u, cy + 0.3623 * u, cx + 0.279 * u, cy + 0.2587 * u, cx + 0.1837 * u, cy + 0.1998 * u)
      p.close_path()
      p.move_to(cx + 0 * u, cy + 0.1473 * u)
      p.bezier_curve_to(cx + -0.0636 * u, cy + 0.1473 * u, cx + -0.1154 * u, cy + 0.0953 * u, cx + -0.1154 * u, cy + 0.0313 * u)
      p.bezier_curve_to(cx + -0.1154 * u, cy + -0.0328 * u, cx + -0.0636 * u, cy + -0.0848 * u, cx + 0 * u, cy + -0.0848 * u)
      p.bezier_curve_to(cx + 0.0636 * u, cy + -0.0848 * u, cx + 0.1154 * u, cy + -0.0328 * u, cx + 0.1154 * u, cy + 0.0313 * u)
      p.bezier_curve_to(cx + 0.1154 * u, cy + 0.0953 * u, cx + 0.0636 * u, cy + 0.1473 * u, cx + 0 * u, cy + 0.1473 * u)
      p.close_path()
      p.move_to(cx + 0.9286 * u, cy + -0.6429 * u)
      p.line_to(cx + 0.5714 * u, cy + -0.6429 * u)
      p.line_to(cx + 0.5714 * u, cy + -0.7679 * u)
      p.bezier_curve_to(cx + 0.5714 * u, cy + -0.7777 * u, cx + 0.5634 * u, cy + -0.7857 * u, cx + 0.5536 * u, cy + -0.7857 * u)
      p.line_to(cx + 0.4286 * u, cy + -0.7857 * u)
      p.bezier_curve_to(cx + 0.4188 * u, cy + -0.7857 * u, cx + 0.4107 * u, cy + -0.7777 * u, cx + 0.4107 * u, cy + -0.7679 * u)
      p.line_to(cx + 0.4107 * u, cy + -0.6429 * u)
      p.line_to(cx + 0.0804 * u, cy + -0.6429 * u)
      p.line_to(cx + 0.0804 * u, cy + -0.7679 * u)
      p.bezier_curve_to(cx + 0.0804 * u, cy + -0.7777 * u, cx + 0.0723 * u, cy + -0.7857 * u, cx + 0.0625 * u, cy + -0.7857 * u)
      p.line_to(cx + -0.0625 * u, cy + -0.7857 * u)
      p.bezier_curve_to(cx + -0.0723 * u, cy + -0.7857 * u, cx + -0.0804 * u, cy + -0.7777 * u, cx + -0.0804 * u, cy + -0.7679 * u)
      p.line_to(cx + -0.0804 * u, cy + -0.6429 * u)
      p.line_to(cx + -0.4107 * u, cy + -0.6429 * u)
      p.line_to(cx + -0.4107 * u, cy + -0.7679 * u)
      p.bezier_curve_to(cx + -0.4107 * u, cy + -0.7777 * u, cx + -0.4188 * u, cy + -0.7857 * u, cx + -0.4286 * u, cy + -0.7857 * u)
      p.line_to(cx + -0.5536 * u, cy + -0.7857 * u)
      p.bezier_curve_to(cx + -0.5634 * u, cy + -0.7857 * u, cx + -0.5714 * u, cy + -0.7777 * u, cx + -0.5714 * u, cy + -0.7679 * u)
      p.line_to(cx + -0.5714 * u, cy + -0.6429 * u)
      p.line_to(cx + -0.9286 * u, cy + -0.6429 * u)
      p.bezier_curve_to(cx + -0.9681 * u, cy + -0.6429 * u, cx + -1 * u, cy + -0.6109 * u, cx + -1 * u, cy + -0.5714 * u)
      p.line_to(cx + -1 * u, cy + 0.7143 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.7538 * u, cx + -0.9681 * u, cy + 0.7857 * u, cx + -0.9286 * u, cy + 0.7857 * u)
      p.line_to(cx + 0.9286 * u, cy + 0.7857 * u)
      p.bezier_curve_to(cx + 0.9681 * u, cy + 0.7857 * u, cx + 1 * u, cy + 0.7538 * u, cx + 1 * u, cy + 0.7143 * u)
      p.line_to(cx + 1 * u, cy + -0.5714 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.6109 * u, cx + 0.9681 * u, cy + -0.6429 * u, cx + 0.9286 * u, cy + -0.6429 * u)
      p.close_path()
      p.move_to(cx + 0.8393 * u, cy + 0.625 * u)
      p.line_to(cx + -0.8393 * u, cy + 0.625 * u)
      p.line_to(cx + -0.8393 * u, cy + -0.4821 * u)
      p.line_to(cx + -0.5714 * u, cy + -0.4821 * u)
      p.line_to(cx + -0.5714 * u, cy + -0.3571 * u)
      p.bezier_curve_to(cx + -0.5714 * u, cy + -0.3473 * u, cx + -0.5634 * u, cy + -0.3393 * u, cx + -0.5536 * u, cy + -0.3393 * u)
      p.line_to(cx + -0.4286 * u, cy + -0.3393 * u)
      p.bezier_curve_to(cx + -0.4188 * u, cy + -0.3393 * u, cx + -0.4107 * u, cy + -0.3473 * u, cx + -0.4107 * u, cy + -0.3571 * u)
      p.line_to(cx + -0.4107 * u, cy + -0.4821 * u)
      p.line_to(cx + -0.0804 * u, cy + -0.4821 * u)
      p.line_to(cx + -0.0804 * u, cy + -0.3571 * u)
      p.bezier_curve_to(cx + -0.0804 * u, cy + -0.3473 * u, cx + -0.0723 * u, cy + -0.3393 * u, cx + -0.0625 * u, cy + -0.3393 * u)
      p.line_to(cx + 0.0625 * u, cy + -0.3393 * u)
      p.bezier_curve_to(cx + 0.0723 * u, cy + -0.3393 * u, cx + 0.0804 * u, cy + -0.3473 * u, cx + 0.0804 * u, cy + -0.3571 * u)
      p.line_to(cx + 0.0804 * u, cy + -0.4821 * u)
      p.line_to(cx + 0.4107 * u, cy + -0.4821 * u)
      p.line_to(cx + 0.4107 * u, cy + -0.3571 * u)
      p.bezier_curve_to(cx + 0.4107 * u, cy + -0.3473 * u, cx + 0.4187 * u, cy + -0.3393 * u, cx + 0.4286 * u, cy + -0.3393 * u)
      p.line_to(cx + 0.5536 * u, cy + -0.3393 * u)
      p.bezier_curve_to(cx + 0.5634 * u, cy + -0.3393 * u, cx + 0.5714 * u, cy + -0.3473 * u, cx + 0.5714 * u, cy + -0.3571 * u)
      p.line_to(cx + 0.5714 * u, cy + -0.4821 * u)
      p.line_to(cx + 0.8393 * u, cy + -0.4821 * u)
      p.line_to(cx + 0.8393 * u, cy + 0.625 * u)
      p.close_path()
      p.fill()
    }
    YhStop => { // stop
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.5522 * u, cy + -1 * u, cx + -1 * u, cy + -0.5522 * u, cx + -1 * u, cy + 0 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.5522 * u, cx + -0.5522 * u, cy + 1 * u, cx + 0 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.5522 * u, cy + 1 * u, cx + 1 * u, cy + 0.5522 * u, cx + 1 * u, cy + 0 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.5522 * u, cx + 0.5522 * u, cy + -1 * u, cx + 0 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0 * u, cy + 0.8304 * u)
      p.bezier_curve_to(cx + -0.4585 * u, cy + 0.8304 * u, cx + -0.8304 * u, cy + 0.4585 * u, cx + -0.8304 * u, cy + 0 * u)
      p.bezier_curve_to(cx + -0.8304 * u, cy + -0.1987 * u, cx + -0.7605 * u, cy + -0.3812 * u, cx + -0.644 * u, cy + -0.5241 * u)
      p.line_to(cx + 0.5241 * u, cy + 0.644 * u)
      p.bezier_curve_to(cx + 0.3812 * u, cy + 0.7605 * u, cx + 0.1987 * u, cy + 0.8304 * u, cx + 0 * u, cy + 0.8304 * u)
      p.close_path()
      p.move_to(cx + 0.644 * u, cy + 0.5241 * u)
      p.line_to(cx + -0.5241 * u, cy + -0.644 * u)
      p.bezier_curve_to(cx + -0.3812 * u, cy + -0.7605 * u, cx + -0.1987 * u, cy + -0.8304 * u, cx + 0 * u, cy + -0.8304 * u)
      p.bezier_curve_to(cx + 0.4585 * u, cy + -0.8304 * u, cx + 0.8304 * u, cy + -0.4585 * u, cx + 0.8304 * u, cy + 0 * u)
      p.bezier_curve_to(cx + 0.8304 * u, cy + 0.1987 * u, cx + 0.7605 * u, cy + 0.3812 * u, cx + 0.644 * u, cy + 0.5241 * u)
      p.close_path()
      p.fill()
    }
    YhExport => { // export
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.942 * u, cy + 0.6268 * u)
      p.line_to(cx + 0.8046 * u, cy + 0.6268 * u)
      p.bezier_curve_to(cx + 0.7939 * u, cy + 0.6268 * u, cx + 0.7849 * u, cy + 0.6358 * u, cx + 0.7849 * u, cy + 0.6465 * u)
      p.line_to(cx + 0.7849 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.8235 * u, cy + 0.8043 * u)
      p.line_to(cx + -0.8235 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.7852 * u, cy + -0.8043 * u)
      p.line_to(cx + 0.7852 * u, cy + -0.6465 * u)
      p.bezier_curve_to(cx + 0.7852 * u, cy + -0.6358 * u, cx + 0.7941 * u, cy + -0.6268 * u, cx + 0.8049 * u, cy + -0.6268 * u)
      p.line_to(cx + 0.9423 * u, cy + -0.6268 * u)
      p.bezier_curve_to(cx + 0.953 * u, cy + -0.6268 * u, cx + 0.9619 * u, cy + -0.6355 * u, cx + 0.9619 * u, cy + -0.6465 * u)
      p.line_to(cx + 0.9619 * u, cy + -0.9024 * u)
      p.bezier_curve_to(cx + 0.9619 * u, cy + -0.9458 * u, cx + 0.9269 * u, cy + -0.9808 * u, cx + 0.8835 * u, cy + -0.9808 * u)
      p.line_to(cx + -0.9216 * u, cy + -0.9808 * u)
      p.bezier_curve_to(cx + -0.965 * u, cy + -0.9808 * u, cx + -1 * u, cy + -0.9458 * u, cx + -1 * u, cy + -0.9024 * u)
      p.line_to(cx + -1 * u, cy + 0.9024 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9458 * u, cx + -0.965 * u, cy + 0.9808 * u, cx + -0.9216 * u, cy + 0.9808 * u)
      p.line_to(cx + 0.8833 * u, cy + 0.9808 * u)
      p.bezier_curve_to(cx + 0.9267 * u, cy + 0.9808 * u, cx + 0.9617 * u, cy + 0.9458 * u, cx + 0.9617 * u, cy + 0.9024 * u)
      p.line_to(cx + 0.9617 * u, cy + 0.6465 * u)
      p.bezier_curve_to(cx + 0.9617 * u, cy + 0.6355 * u, cx + 0.9527 * u, cy + 0.6268 * u, cx + 0.942 * u, cy + 0.6268 * u)
      p.close_path()
      p.move_to(cx + 0.9895 * u, cy + -0.0161 * u)
      p.line_to(cx + 0.6271 * u, cy + -0.3022 * u)
      p.bezier_curve_to(cx + 0.6135 * u, cy + -0.3129 * u, cx + 0.5939 * u, cy + -0.3032 * u, cx + 0.5939 * u, cy + -0.2861 * u)
      p.line_to(cx + 0.5939 * u, cy + -0.092 * u)
      p.line_to(cx + -0.2082 * u, cy + -0.092 * u)
      p.bezier_curve_to(cx + -0.2194 * u, cy + -0.092 * u, cx + -0.2286 * u, cy + -0.0828 * u, cx + -0.2286 * u, cy + -0.0715 * u)
      p.line_to(cx + -0.2286 * u, cy + 0.0715 * u)
      p.bezier_curve_to(cx + -0.2286 * u, cy + 0.0828 * u, cx + -0.2194 * u, cy + 0.092 * u, cx + -0.2082 * u, cy + 0.092 * u)
      p.line_to(cx + 0.5939 * u, cy + 0.092 * u)
      p.line_to(cx + 0.5939 * u, cy + 0.2861 * u)
      p.bezier_curve_to(cx + 0.5939 * u, cy + 0.3032 * u, cx + 0.6138 * u, cy + 0.3129 * u, cx + 0.6271 * u, cy + 0.3022 * u)
      p.line_to(cx + 0.9895 * u, cy + 0.0161 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.0079 * u, cx + 1 * u, cy + -0.0079 * u, cx + 0.9895 * u, cy + -0.0161 * u)
      p.close_path()
      p.fill()
    }
    YhImport => { // Import
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.9445 * u, cy + 0.6276 * u)
      p.line_to(cx + 0.8069 * u, cy + 0.6276 * u)
      p.bezier_curve_to(cx + 0.7962 * u, cy + 0.6276 * u, cx + 0.7872 * u, cy + 0.6366 * u, cx + 0.7872 * u, cy + 0.6473 * u)
      p.line_to(cx + 0.7872 * u, cy + 0.8054 * u)
      p.line_to(cx + -0.8233 * u, cy + 0.8054 * u)
      p.line_to(cx + -0.8233 * u, cy + -0.8054 * u)
      p.line_to(cx + 0.7875 * u, cy + -0.8054 * u)
      p.line_to(cx + 0.7875 * u, cy + -0.6473 * u)
      p.bezier_curve_to(cx + 0.7875 * u, cy + -0.6366 * u, cx + 0.7964 * u, cy + -0.6276 * u, cx + 0.8072 * u, cy + -0.6276 * u)
      p.line_to(cx + 0.9448 * u, cy + -0.6276 * u)
      p.bezier_curve_to(cx + 0.9555 * u, cy + -0.6276 * u, cx + 0.9645 * u, cy + -0.6363 * u, cx + 0.9645 * u, cy + -0.6473 * u)
      p.line_to(cx + 0.9645 * u, cy + -0.9036 * u)
      p.bezier_curve_to(cx + 0.9645 * u, cy + -0.9471 * u, cx + 0.9294 * u, cy + -0.9821 * u, cx + 0.8859 * u, cy + -0.9821 * u)
      p.line_to(cx + -0.9215 * u, cy + -0.9821 * u)
      p.bezier_curve_to(cx + -0.965 * u, cy + -0.9821 * u, cx + -1 * u, cy + -0.9471 * u, cx + -1 * u, cy + -0.9036 * u)
      p.line_to(cx + -1 * u, cy + 0.9036 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9471 * u, cx + -0.965 * u, cy + 0.9821 * u, cx + -0.9215 * u, cy + 0.9821 * u)
      p.line_to(cx + 0.8857 * u, cy + 0.9821 * u)
      p.bezier_curve_to(cx + 0.9292 * u, cy + 0.9821 * u, cx + 0.9642 * u, cy + 0.9471 * u, cx + 0.9642 * u, cy + 0.9036 * u)
      p.line_to(cx + 0.9642 * u, cy + 0.6473 * u)
      p.bezier_curve_to(cx + 0.9642 * u, cy + 0.6363 * u, cx + 0.9552 * u, cy + 0.6276 * u, cx + 0.9445 * u, cy + 0.6276 * u)
      p.close_path()
      p.move_to(cx + 0.9795 * u, cy + -0.0921 * u)
      p.line_to(cx + 0.1765 * u, cy + -0.0921 * u)
      p.line_to(cx + 0.1765 * u, cy + -0.2864 * u)
      p.bezier_curve_to(cx + 0.1765 * u, cy + -0.3036 * u, cx + 0.1565 * u, cy + -0.3133 * u, cx + 0.1432 * u, cy + -0.3026 * u)
      p.line_to(cx + -0.2197 * u, cy + -0.0161 * u)
      p.bezier_curve_to(cx + -0.2302 * u, cy + -0.0079 * u, cx + -0.2302 * u, cy + 0.0079 * u, cx + -0.2197 * u, cy + 0.0161 * u)
      p.line_to(cx + 0.1432 * u, cy + 0.3026 * u)
      p.bezier_curve_to(cx + 0.1568 * u, cy + 0.3133 * u, cx + 0.1765 * u, cy + 0.3036 * u, cx + 0.1765 * u, cy + 0.2864 * u)
      p.line_to(cx + 0.1765 * u, cy + 0.0921 * u)
      p.line_to(cx + 0.9795 * u, cy + 0.0921 * u)
      p.bezier_curve_to(cx + 0.9908 * u, cy + 0.0921 * u, cx + 1 * u, cy + 0.0829 * u, cx + 1 * u, cy + 0.0716 * u)
      p.line_to(cx + 1 * u, cy + -0.0716 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.0829 * u, cx + 0.9908 * u, cy + -0.0921 * u, cx + 0.9795 * u, cy + -0.0921 * u)
      p.close_path()
      p.fill()
    }
    YhSmile => { // smile
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.3929 * u, cy + -0.2031 * u)
      p.close_path()
      p.move_to(cx + -0.5 * u, cy + -0.2031 * u)
      p.line_to(cx + -0.4984 * u, cy + -0.1845 * u)
      p.line_to(cx + -0.4935 * u, cy + -0.1665 * u)
      p.line_to(cx + -0.4856 * u, cy + -0.1496 * u)
      p.line_to(cx + -0.4749 * u, cy + -0.1343 * u)
      p.line_to(cx + -0.4617 * u, cy + -0.121 * u)
      p.line_to(cx + -0.4464 * u, cy + -0.1103 * u)
      p.line_to(cx + -0.4295 * u, cy + -0.1024 * u)
      p.line_to(cx + -0.4115 * u, cy + -0.0976 * u)
      p.line_to(cx + -0.3929 * u, cy + -0.096 * u)
      p.line_to(cx + -0.3743 * u, cy + -0.0976 * u)
      p.line_to(cx + -0.3562 * u, cy + -0.1024 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.1103 * u)
      p.line_to(cx + -0.324 * u, cy + -0.121 * u)
      p.line_to(cx + -0.3108 * u, cy + -0.1343 * u)
      p.line_to(cx + -0.3001 * u, cy + -0.1496 * u)
      p.line_to(cx + -0.2922 * u, cy + -0.1665 * u)
      p.line_to(cx + -0.2873 * u, cy + -0.1845 * u)
      p.line_to(cx + -0.2857 * u, cy + -0.2031 * u)
      p.line_to(cx + -0.2873 * u, cy + -0.2217 * u)
      p.line_to(cx + -0.2922 * u, cy + -0.2398 * u)
      p.line_to(cx + -0.3001 * u, cy + -0.2567 * u)
      p.line_to(cx + -0.3108 * u, cy + -0.272 * u)
      p.line_to(cx + -0.324 * u, cy + -0.2852 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.2959 * u)
      p.line_to(cx + -0.3562 * u, cy + -0.3038 * u)
      p.line_to(cx + -0.3743 * u, cy + -0.3086 * u)
      p.line_to(cx + -0.3929 * u, cy + -0.3103 * u)
      p.line_to(cx + -0.4115 * u, cy + -0.3086 * u)
      p.line_to(cx + -0.4295 * u, cy + -0.3038 * u)
      p.line_to(cx + -0.4464 * u, cy + -0.2959 * u)
      p.line_to(cx + -0.4617 * u, cy + -0.2852 * u)
      p.line_to(cx + -0.4749 * u, cy + -0.272 * u)
      p.line_to(cx + -0.4856 * u, cy + -0.2567 * u)
      p.line_to(cx + -0.4935 * u, cy + -0.2398 * u)
      p.line_to(cx + -0.4984 * u, cy + -0.2217 * u)
      p.line_to(cx + -0.5 * u, cy + -0.2031 * u)
      p.close_path()
      p.move_to(cx + 0.3929 * u, cy + -0.2031 * u)
      p.close_path()
      p.move_to(cx + 0.2857 * u, cy + -0.2031 * u)
      p.line_to(cx + 0.2873 * u, cy + -0.1845 * u)
      p.line_to(cx + 0.2922 * u, cy + -0.1665 * u)
      p.line_to(cx + 0.3001 * u, cy + -0.1496 * u)
      p.line_to(cx + 0.3108 * u, cy + -0.1343 * u)
      p.line_to(cx + 0.324 * u, cy + -0.121 * u)
      p.line_to(cx + 0.3393 * u, cy + -0.1103 * u)
      p.line_to(cx + 0.3562 * u, cy + -0.1024 * u)
      p.line_to(cx + 0.3743 * u, cy + -0.0976 * u)
      p.line_to(cx + 0.3929 * u, cy + -0.096 * u)
      p.line_to(cx + 0.4115 * u, cy + -0.0976 * u)
      p.line_to(cx + 0.4295 * u, cy + -0.1024 * u)
      p.line_to(cx + 0.4464 * u, cy + -0.1103 * u)
      p.line_to(cx + 0.4617 * u, cy + -0.121 * u)
      p.line_to(cx + 0.4749 * u, cy + -0.1343 * u)
      p.line_to(cx + 0.4856 * u, cy + -0.1496 * u)
      p.line_to(cx + 0.4935 * u, cy + -0.1665 * u)
      p.line_to(cx + 0.4984 * u, cy + -0.1845 * u)
      p.line_to(cx + 0.5 * u, cy + -0.2031 * u)
      p.line_to(cx + 0.4984 * u, cy + -0.2217 * u)
      p.line_to(cx + 0.4935 * u, cy + -0.2398 * u)
      p.line_to(cx + 0.4856 * u, cy + -0.2567 * u)
      p.line_to(cx + 0.4749 * u, cy + -0.272 * u)
      p.line_to(cx + 0.4617 * u, cy + -0.2852 * u)
      p.line_to(cx + 0.4464 * u, cy + -0.2959 * u)
      p.line_to(cx + 0.4295 * u, cy + -0.3038 * u)
      p.line_to(cx + 0.4115 * u, cy + -0.3086 * u)
      p.line_to(cx + 0.3929 * u, cy + -0.3103 * u)
      p.line_to(cx + 0.3743 * u, cy + -0.3086 * u)
      p.line_to(cx + 0.3562 * u, cy + -0.3038 * u)
      p.line_to(cx + 0.3393 * u, cy + -0.2959 * u)
      p.line_to(cx + 0.324 * u, cy + -0.2852 * u)
      p.line_to(cx + 0.3108 * u, cy + -0.272 * u)
      p.line_to(cx + 0.3001 * u, cy + -0.2567 * u)
      p.line_to(cx + 0.2922 * u, cy + -0.2398 * u)
      p.line_to(cx + 0.2873 * u, cy + -0.2217 * u)
      p.line_to(cx + 0.2857 * u, cy + -0.2031 * u)
      p.close_path()
      p.move_to(cx + 0 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.5522 * u, cy + -1 * u, cx + -1 * u, cy + -0.5522 * u, cx + -1 * u, cy + 0 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.5522 * u, cx + -0.5522 * u, cy + 1 * u, cx + 0 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.5522 * u, cy + 1 * u, cx + 1 * u, cy + 0.5522 * u, cx + 1 * u, cy + 0 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.5522 * u, cx + 0.5522 * u, cy + -1 * u, cx + 0 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.5871 * u, cy + 0.5871 * u)
      p.bezier_curve_to(cx + 0.5107 * u, cy + 0.6634 * u, cx + 0.4219 * u, cy + 0.7232 * u, cx + 0.323 * u, cy + 0.7652 * u)
      p.bezier_curve_to(cx + 0.221 * u, cy + 0.8085 * u, cx + 0.1123 * u, cy + 0.8304 * u, cx + 0 * u, cy + 0.8304 * u)
      p.bezier_curve_to(cx + -0.1123 * u, cy + 0.8304 * u, cx + -0.221 * u, cy + 0.8085 * u, cx + -0.3232 * u, cy + 0.7652 * u)
      p.bezier_curve_to(cx + -0.4221 * u, cy + 0.7234 * u, cx + -0.5109 * u, cy + 0.6634 * u, cx + -0.5873 * u, cy + 0.5871 * u)
      p.bezier_curve_to(cx + -0.6636 * u, cy + 0.5107 * u, cx + -0.7234 * u, cy + 0.4219 * u, cx + -0.7654 * u, cy + 0.323 * u)
      p.bezier_curve_to(cx + -0.8085 * u, cy + 0.221 * u, cx + -0.8304 * u, cy + 0.1123 * u, cx + -0.8304 * u, cy + 0 * u)
      p.bezier_curve_to(cx + -0.8304 * u, cy + -0.1123 * u, cx + -0.8085 * u, cy + -0.221 * u, cx + -0.7652 * u, cy + -0.3232 * u)
      p.bezier_curve_to(cx + -0.7234 * u, cy + -0.4221 * u, cx + -0.6634 * u, cy + -0.5109 * u, cx + -0.5871 * u, cy + -0.5873 * u)
      p.bezier_curve_to(cx + -0.5107 * u, cy + -0.6636 * u, cx + -0.4219 * u, cy + -0.7234 * u, cx + -0.323 * u, cy + -0.7654 * u)
      p.bezier_curve_to(cx + -0.221 * u, cy + -0.8085 * u, cx + -0.1123 * u, cy + -0.8304 * u, cx + 0 * u, cy + -0.8304 * u)
      p.bezier_curve_to(cx + 0.1123 * u, cy + -0.8304 * u, cx + 0.221 * u, cy + -0.8085 * u, cx + 0.3232 * u, cy + -0.7652 * u)
      p.bezier_curve_to(cx + 0.4221 * u, cy + -0.7234 * u, cx + 0.5109 * u, cy + -0.6634 * u, cx + 0.5873 * u, cy + -0.5871 * u)
      p.bezier_curve_to(cx + 0.6636 * u, cy + -0.5107 * u, cx + 0.7234 * u, cy + -0.4219 * u, cx + 0.7654 * u, cy + -0.323 * u)
      p.bezier_curve_to(cx + 0.8085 * u, cy + -0.221 * u, cx + 0.8304 * u, cy + -0.1123 * u, cx + 0.8304 * u, cy + 0 * u)
      p.bezier_curve_to(cx + 0.8304 * u, cy + 0.1123 * u, cx + 0.8085 * u, cy + 0.221 * u, cx + 0.7652 * u, cy + 0.3232 * u)
      p.bezier_curve_to(cx + 0.7234 * u, cy + 0.4221 * u, cx + 0.6634 * u, cy + 0.5109 * u, cx + 0.5871 * u, cy + 0.5871 * u)
      p.close_path()
      p.move_to(cx + 0.3393 * u, cy + 0.0469 * u)
      p.line_to(cx + 0.2319 * u, cy + 0.0469 * u)
      p.bezier_curve_to(cx + 0.2225 * u, cy + 0.0469 * u, cx + 0.2145 * u, cy + 0.054 * u, cx + 0.2138 * u, cy + 0.0634 * u)
      p.bezier_curve_to(cx + 0.2054 * u, cy + 0.1739 * u, cx + 0.1127 * u, cy + 0.2612 * u, cx + 0 * u, cy + 0.2612 * u)
      p.bezier_curve_to(cx + -0.1127 * u, cy + 0.2612 * u, cx + -0.2056 * u, cy + 0.1739 * u, cx + -0.2138 * u, cy + 0.0634 * u)
      p.bezier_curve_to(cx + -0.2145 * u, cy + 0.054 * u, cx + -0.2225 * u, cy + 0.0469 * u, cx + -0.2319 * u, cy + 0.0469 * u)
      p.line_to(cx + -0.3393 * u, cy + 0.0469 * u)
      p.bezier_curve_to(cx + -0.3496 * u, cy + 0.0469 * u, cx + -0.3576 * u, cy + 0.0554 * u, cx + -0.3571 * u, cy + 0.0656 * u)
      p.bezier_curve_to(cx + -0.3473 * u, cy + 0.2538 * u, cx + -0.1908 * u, cy + 0.404 * u, cx + 0 * u, cy + 0.404 * u)
      p.bezier_curve_to(cx + 0.1908 * u, cy + 0.404 * u, cx + 0.3473 * u, cy + 0.2538 * u, cx + 0.3571 * u, cy + 0.0656 * u)
      p.bezier_curve_to(cx + 0.3576 * u, cy + 0.0554 * u, cx + 0.3496 * u, cy + 0.0469 * u, cx + 0.3393 * u, cy + 0.0469 * u)
      p.close_path()
      p.fill()
    }
    YhFrown => { // frown
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.3929 * u, cy + -0.2031 * u)
      p.close_path()
      p.move_to(cx + -0.5 * u, cy + -0.2031 * u)
      p.line_to(cx + -0.4984 * u, cy + -0.1845 * u)
      p.line_to(cx + -0.4935 * u, cy + -0.1665 * u)
      p.line_to(cx + -0.4856 * u, cy + -0.1496 * u)
      p.line_to(cx + -0.4749 * u, cy + -0.1343 * u)
      p.line_to(cx + -0.4617 * u, cy + -0.121 * u)
      p.line_to(cx + -0.4464 * u, cy + -0.1103 * u)
      p.line_to(cx + -0.4295 * u, cy + -0.1024 * u)
      p.line_to(cx + -0.4115 * u, cy + -0.0976 * u)
      p.line_to(cx + -0.3929 * u, cy + -0.096 * u)
      p.line_to(cx + -0.3743 * u, cy + -0.0976 * u)
      p.line_to(cx + -0.3562 * u, cy + -0.1024 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.1103 * u)
      p.line_to(cx + -0.324 * u, cy + -0.121 * u)
      p.line_to(cx + -0.3108 * u, cy + -0.1343 * u)
      p.line_to(cx + -0.3001 * u, cy + -0.1496 * u)
      p.line_to(cx + -0.2922 * u, cy + -0.1665 * u)
      p.line_to(cx + -0.2873 * u, cy + -0.1845 * u)
      p.line_to(cx + -0.2857 * u, cy + -0.2031 * u)
      p.line_to(cx + -0.2873 * u, cy + -0.2217 * u)
      p.line_to(cx + -0.2922 * u, cy + -0.2398 * u)
      p.line_to(cx + -0.3001 * u, cy + -0.2567 * u)
      p.line_to(cx + -0.3108 * u, cy + -0.272 * u)
      p.line_to(cx + -0.324 * u, cy + -0.2852 * u)
      p.line_to(cx + -0.3393 * u, cy + -0.2959 * u)
      p.line_to(cx + -0.3562 * u, cy + -0.3038 * u)
      p.line_to(cx + -0.3743 * u, cy + -0.3086 * u)
      p.line_to(cx + -0.3929 * u, cy + -0.3103 * u)
      p.line_to(cx + -0.4115 * u, cy + -0.3086 * u)
      p.line_to(cx + -0.4295 * u, cy + -0.3038 * u)
      p.line_to(cx + -0.4464 * u, cy + -0.2959 * u)
      p.line_to(cx + -0.4617 * u, cy + -0.2852 * u)
      p.line_to(cx + -0.4749 * u, cy + -0.272 * u)
      p.line_to(cx + -0.4856 * u, cy + -0.2567 * u)
      p.line_to(cx + -0.4935 * u, cy + -0.2398 * u)
      p.line_to(cx + -0.4984 * u, cy + -0.2217 * u)
      p.line_to(cx + -0.5 * u, cy + -0.2031 * u)
      p.close_path()
      p.move_to(cx + 0.3929 * u, cy + -0.2031 * u)
      p.close_path()
      p.move_to(cx + 0.2857 * u, cy + -0.2031 * u)
      p.line_to(cx + 0.2873 * u, cy + -0.1845 * u)
      p.line_to(cx + 0.2922 * u, cy + -0.1665 * u)
      p.line_to(cx + 0.3001 * u, cy + -0.1496 * u)
      p.line_to(cx + 0.3108 * u, cy + -0.1343 * u)
      p.line_to(cx + 0.324 * u, cy + -0.121 * u)
      p.line_to(cx + 0.3393 * u, cy + -0.1103 * u)
      p.line_to(cx + 0.3562 * u, cy + -0.1024 * u)
      p.line_to(cx + 0.3743 * u, cy + -0.0976 * u)
      p.line_to(cx + 0.3929 * u, cy + -0.096 * u)
      p.line_to(cx + 0.4115 * u, cy + -0.0976 * u)
      p.line_to(cx + 0.4295 * u, cy + -0.1024 * u)
      p.line_to(cx + 0.4464 * u, cy + -0.1103 * u)
      p.line_to(cx + 0.4617 * u, cy + -0.121 * u)
      p.line_to(cx + 0.4749 * u, cy + -0.1343 * u)
      p.line_to(cx + 0.4856 * u, cy + -0.1496 * u)
      p.line_to(cx + 0.4935 * u, cy + -0.1665 * u)
      p.line_to(cx + 0.4984 * u, cy + -0.1845 * u)
      p.line_to(cx + 0.5 * u, cy + -0.2031 * u)
      p.line_to(cx + 0.4984 * u, cy + -0.2217 * u)
      p.line_to(cx + 0.4935 * u, cy + -0.2398 * u)
      p.line_to(cx + 0.4856 * u, cy + -0.2567 * u)
      p.line_to(cx + 0.4749 * u, cy + -0.272 * u)
      p.line_to(cx + 0.4617 * u, cy + -0.2852 * u)
      p.line_to(cx + 0.4464 * u, cy + -0.2959 * u)
      p.line_to(cx + 0.4295 * u, cy + -0.3038 * u)
      p.line_to(cx + 0.4115 * u, cy + -0.3086 * u)
      p.line_to(cx + 0.3929 * u, cy + -0.3103 * u)
      p.line_to(cx + 0.3743 * u, cy + -0.3086 * u)
      p.line_to(cx + 0.3562 * u, cy + -0.3038 * u)
      p.line_to(cx + 0.3393 * u, cy + -0.2959 * u)
      p.line_to(cx + 0.324 * u, cy + -0.2852 * u)
      p.line_to(cx + 0.3108 * u, cy + -0.272 * u)
      p.line_to(cx + 0.3001 * u, cy + -0.2567 * u)
      p.line_to(cx + 0.2922 * u, cy + -0.2398 * u)
      p.line_to(cx + 0.2873 * u, cy + -0.2217 * u)
      p.line_to(cx + 0.2857 * u, cy + -0.2031 * u)
      p.close_path()
      p.move_to(cx + 0 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.5522 * u, cy + -1 * u, cx + -1 * u, cy + -0.5522 * u, cx + -1 * u, cy + 0 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.5522 * u, cx + -0.5522 * u, cy + 1 * u, cx + 0 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.5522 * u, cy + 1 * u, cx + 1 * u, cy + 0.5522 * u, cx + 1 * u, cy + 0 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.5522 * u, cx + 0.5522 * u, cy + -1 * u, cx + 0 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.5871 * u, cy + 0.5871 * u)
      p.bezier_curve_to(cx + 0.5107 * u, cy + 0.6634 * u, cx + 0.4219 * u, cy + 0.7232 * u, cx + 0.323 * u, cy + 0.7652 * u)
      p.bezier_curve_to(cx + 0.221 * u, cy + 0.8085 * u, cx + 0.1123 * u, cy + 0.8304 * u, cx + 0 * u, cy + 0.8304 * u)
      p.bezier_curve_to(cx + -0.1123 * u, cy + 0.8304 * u, cx + -0.221 * u, cy + 0.8085 * u, cx + -0.3232 * u, cy + 0.7652 * u)
      p.bezier_curve_to(cx + -0.4221 * u, cy + 0.7234 * u, cx + -0.5109 * u, cy + 0.6634 * u, cx + -0.5873 * u, cy + 0.5871 * u)
      p.bezier_curve_to(cx + -0.6636 * u, cy + 0.5107 * u, cx + -0.7234 * u, cy + 0.4219 * u, cx + -0.7654 * u, cy + 0.323 * u)
      p.bezier_curve_to(cx + -0.8085 * u, cy + 0.221 * u, cx + -0.8304 * u, cy + 0.1123 * u, cx + -0.8304 * u, cy + 0 * u)
      p.bezier_curve_to(cx + -0.8304 * u, cy + -0.1123 * u, cx + -0.8085 * u, cy + -0.221 * u, cx + -0.7652 * u, cy + -0.3232 * u)
      p.bezier_curve_to(cx + -0.7234 * u, cy + -0.4221 * u, cx + -0.6634 * u, cy + -0.5109 * u, cx + -0.5871 * u, cy + -0.5873 * u)
      p.bezier_curve_to(cx + -0.5107 * u, cy + -0.6636 * u, cx + -0.4219 * u, cy + -0.7234 * u, cx + -0.323 * u, cy + -0.7654 * u)
      p.bezier_curve_to(cx + -0.221 * u, cy + -0.8085 * u, cx + -0.1123 * u, cy + -0.8304 * u, cx + 0 * u, cy + -0.8304 * u)
      p.bezier_curve_to(cx + 0.1123 * u, cy + -0.8304 * u, cx + 0.221 * u, cy + -0.8085 * u, cx + 0.3232 * u, cy + -0.7652 * u)
      p.bezier_curve_to(cx + 0.4221 * u, cy + -0.7234 * u, cx + 0.5109 * u, cy + -0.6634 * u, cx + 0.5873 * u, cy + -0.5871 * u)
      p.bezier_curve_to(cx + 0.6636 * u, cy + -0.5107 * u, cx + 0.7234 * u, cy + -0.4219 * u, cx + 0.7654 * u, cy + -0.323 * u)
      p.bezier_curve_to(cx + 0.8085 * u, cy + -0.221 * u, cx + 0.8304 * u, cy + -0.1123 * u, cx + 0.8304 * u, cy + 0 * u)
      p.bezier_curve_to(cx + 0.8304 * u, cy + 0.1123 * u, cx + 0.8085 * u, cy + 0.221 * u, cx + 0.7652 * u, cy + 0.3232 * u)
      p.bezier_curve_to(cx + 0.7234 * u, cy + 0.4221 * u, cx + 0.6634 * u, cy + 0.5109 * u, cx + 0.5871 * u, cy + 0.5871 * u)
      p.close_path()
      p.move_to(cx + 0 * u, cy + 0.0469 * u)
      p.bezier_curve_to(cx + -0.1908 * u, cy + 0.0469 * u, cx + -0.3473 * u, cy + 0.1971 * u, cx + -0.3571 * u, cy + 0.3853 * u)
      p.bezier_curve_to(cx + -0.3576 * u, cy + 0.3955 * u, cx + -0.3496 * u, cy + 0.404 * u, cx + -0.3393 * u, cy + 0.404 * u)
      p.line_to(cx + -0.2319 * u, cy + 0.404 * u)
      p.bezier_curve_to(cx + -0.2225 * u, cy + 0.404 * u, cx + -0.2145 * u, cy + 0.3969 * u, cx + -0.2138 * u, cy + 0.3875 * u)
      p.bezier_curve_to(cx + -0.2054 * u, cy + 0.277 * u, cx + -0.1127 * u, cy + 0.1897 * u, cx + 0 * u, cy + 0.1897 * u)
      p.bezier_curve_to(cx + 0.1127 * u, cy + 0.1897 * u, cx + 0.2056 * u, cy + 0.277 * u, cx + 0.2138 * u, cy + 0.3875 * u)
      p.bezier_curve_to(cx + 0.2145 * u, cy + 0.3969 * u, cx + 0.2225 * u, cy + 0.404 * u, cx + 0.2319 * u, cy + 0.404 * u)
      p.line_to(cx + 0.3393 * u, cy + 0.404 * u)
      p.bezier_curve_to(cx + 0.3496 * u, cy + 0.404 * u, cx + 0.3576 * u, cy + 0.3955 * u, cx + 0.3571 * u, cy + 0.3853 * u)
      p.bezier_curve_to(cx + 0.3473 * u, cy + 0.1971 * u, cx + 0.1908 * u, cy + 0.0469 * u, cx + 0 * u, cy + 0.0469 * u)
      p.close_path()
      p.fill()
    }
    YhPaperclip => { // attachment
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.6718 * u, cy + -0.7632 * u)
      p.bezier_curve_to(cx + 0.435 * u, cy + -1 * u, cx + 0.0494 * u, cy + -1 * u, cx + -0.1872 * u, cy + -0.7632 * u)
      p.line_to(cx + -0.8433 * u, cy + -0.1076 * u)
      p.bezier_curve_to(cx + -0.8475 * u, cy + -0.1033 * u, cx + -0.8498 * u, cy + -0.0975 * u, cx + -0.8498 * u, cy + -0.0915 * u)
      p.bezier_curve_to(cx + -0.8498 * u, cy + -0.0855 * u, cx + -0.8475 * u, cy + -0.0797 * u, cx + -0.8433 * u, cy + -0.0754 * u)
      p.line_to(cx + -0.7505 * u, cy + 0.0173 * u)
      p.bezier_curve_to(cx + -0.7417 * u, cy + 0.0261 * u, cx + -0.7274 * u, cy + 0.0261 * u, cx + -0.7186 * u, cy + 0.0173 * u)
      p.line_to(cx + -0.0625 * u, cy + -0.6383 * u)
      p.bezier_curve_to(cx + 0.019 * u, cy + -0.7197 * u, cx + 0.1273 * u, cy + -0.7645 * u, cx + 0.2425 * u, cy + -0.7645 * u)
      p.bezier_curve_to(cx + 0.3576 * u, cy + -0.7645 * u, cx + 0.4659 * u, cy + -0.7197 * u, cx + 0.5471 * u, cy + -0.6383 * u)
      p.bezier_curve_to(cx + 0.6286 * u, cy + -0.5568 * u, cx + 0.6733 * u, cy + -0.4485 * u, cx + 0.6733 * u, cy + -0.3336 * u)
      p.bezier_curve_to(cx + 0.6733 * u, cy + -0.2185 * u, cx + 0.6286 * u, cy + -0.1104 * u, cx + 0.5471 * u, cy + -0.0289 * u)
      p.line_to(cx + -0.1215 * u, cy + 0.6395 * u)
      p.line_to(cx + -0.2299 * u, cy + 0.7479 * u)
      p.bezier_curve_to(cx + -0.3312 * u, cy + 0.8492 * u, cx + -0.4959 * u, cy + 0.8492 * u, cx + -0.5972 * u, cy + 0.7479 * u)
      p.bezier_curve_to(cx + -0.6462 * u, cy + 0.6988 * u, cx + -0.6731 * u, cy + 0.6337 * u, cx + -0.6731 * u, cy + 0.5644 * u)
      p.bezier_curve_to(cx + -0.6731 * u, cy + 0.495 * u, cx + -0.6462 * u, cy + 0.4299 * u, cx + -0.5972 * u, cy + 0.3808 * u)
      p.line_to(cx + 0.0662 * u, cy + -0.2823 * u)
      p.bezier_curve_to(cx + 0.0831 * u, cy + -0.2989 * u, cx + 0.1052 * u, cy + -0.3082 * u, cx + 0.1288 * u, cy + -0.3082 * u)
      p.line_to(cx + 0.1291 * u, cy + -0.3082 * u)
      p.bezier_curve_to(cx + 0.1527 * u, cy + -0.3082 * u, cx + 0.1746 * u, cy + -0.2989 * u, cx + 0.1912 * u, cy + -0.2823 * u)
      p.bezier_curve_to(cx + 0.208 * u, cy + -0.2655 * u, cx + 0.2171 * u, cy + -0.2433 * u, cx + 0.2171 * u, cy + -0.2197 * u)
      p.bezier_curve_to(cx + 0.2171 * u, cy + -0.1963 * u, cx + 0.2078 * u, cy + -0.1742 * u, cx + 0.1912 * u, cy + -0.1576 * u)
      p.line_to(cx + -0.3511 * u, cy + 0.3841 * u)
      p.bezier_curve_to(cx + -0.3553 * u, cy + 0.3884 * u, cx + -0.3576 * u, cy + 0.3942 * u, cx + -0.3576 * u, cy + 0.4002 * u)
      p.bezier_curve_to(cx + -0.3576 * u, cy + 0.4062 * u, cx + -0.3553 * u, cy + 0.412 * u, cx + -0.3511 * u, cy + 0.4163 * u)
      p.line_to(cx + -0.2583 * u, cy + 0.509 * u)
      p.bezier_curve_to(cx + -0.2495 * u, cy + 0.5178 * u, cx + -0.2352 * u, cy + 0.5178 * u, cx + -0.2264 * u, cy + 0.509 * u)
      p.line_to(cx + 0.3156 * u, cy + -0.0329 * u)
      p.bezier_curve_to(cx + 0.3656 * u, cy + -0.083 * u, cx + 0.393 * u, cy + -0.1493 * u, cx + 0.393 * u, cy + -0.22 * u)
      p.bezier_curve_to(cx + 0.393 * u, cy + -0.2906 * u, cx + 0.3654 * u, cy + -0.3572 * u, cx + 0.3156 * u, cy + -0.407 * u)
      p.bezier_curve_to(cx + 0.2123 * u, cy + -0.5103 * u, cx + 0.0444 * u, cy + -0.5101 * u, cx + -0.0589 * u, cy + -0.407 * u)
      p.line_to(cx + -0.1233 * u, cy + -0.3424 * u)
      p.line_to(cx + -0.7221 * u, cy + 0.2562 * u)
      p.bezier_curve_to(cx + -0.8046 * u, cy + 0.3386 * u, cx + -0.8498 * u, cy + 0.448 * u, cx + -0.8498 * u, cy + 0.5646 * u)
      p.bezier_curve_to(cx + -0.8498 * u, cy + 0.681 * u, cx + -0.8043 * u, cy + 0.7903 * u, cx + -0.7221 * u, cy + 0.8725 * u)
      p.bezier_curve_to(cx + -0.6369 * u, cy + 0.9575 * u, cx + -0.5253 * u, cy + 1 * u, cx + -0.4137 * u, cy + 1 * u)
      p.bezier_curve_to(cx + -0.302 * u, cy + 1 * u, cx + -0.1904 * u, cy + 0.9575 * u, cx + -0.1055 * u, cy + 0.8725 * u)
      p.line_to(cx + 0.6718 * u, cy + 0.0958 * u)
      p.bezier_curve_to(cx + 0.7862 * u, cy + -0.0189 * u, cx + 0.8495 * u, cy + -0.1714 * u, cx + 0.8495 * u, cy + -0.3336 * u)
      p.bezier_curve_to(cx + 0.8498 * u, cy + -0.496 * u, cx + 0.7865 * u, cy + -0.6486 * u, cx + 0.6718 * u, cy + -0.7632 * u)
      p.close_path()
      p.fill()
    }
    YhCrop => { // crop
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + -0.5714 * u, cy + 0.5714 * u)
      p.line_to(cx + 0.9286 * u, cy + 0.5714 * u)
      p.bezier_curve_to(cx + 0.9494 * u, cy + 0.5714 * u, cx + 0.9665 * u, cy + 0.5781 * u, cx + 0.9799 * u, cy + 0.5915 * u)
      p.bezier_curve_to(cx + 0.9933 * u, cy + 0.6049 * u, cx + 1 * u, cy + 0.622 * u, cx + 1 * u, cy + 0.6429 * u)
      p.bezier_curve_to(cx + 1 * u, cy + 0.6637 * u, cx + 0.9933 * u, cy + 0.6808 * u, cx + 0.9799 * u, cy + 0.6942 * u)
      p.bezier_curve_to(cx + 0.9665 * u, cy + 0.7076 * u, cx + 0.9494 * u, cy + 0.7143 * u, cx + 0.9286 * u, cy + 0.7143 * u)
      p.line_to(cx + -0.6429 * u, cy + 0.7143 * u)
      p.bezier_curve_to(cx + -0.6637 * u, cy + 0.7143 * u, cx + -0.6808 * u, cy + 0.7076 * u, cx + -0.6942 * u, cy + 0.6942 * u)
      p.bezier_curve_to(cx + -0.7076 * u, cy + 0.6808 * u, cx + -0.7143 * u, cy + 0.6637 * u, cx + -0.7143 * u, cy + 0.6429 * u)
      p.line_to(cx + -0.7143 * u, cy + -0.9286 * u)
      p.bezier_curve_to(cx + -0.7143 * u, cy + -0.9494 * u, cx + -0.7076 * u, cy + -0.9665 * u, cx + -0.6942 * u, cy + -0.9799 * u)
      p.bezier_curve_to(cx + -0.6808 * u, cy + -0.9933 * u, cx + -0.6637 * u, cy + -1 * u, cx + -0.6429 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.622 * u, cy + -1 * u, cx + -0.6049 * u, cy + -0.9933 * u, cx + -0.5915 * u, cy + -0.9799 * u)
      p.bezier_curve_to(cx + -0.5781 * u, cy + -0.9665 * u, cx + -0.5714 * u, cy + -0.9494 * u, cx + -0.5714 * u, cy + -0.9286 * u)
      p.line_to(cx + -0.5714 * u, cy + 0.5714 * u)
      p.close_path()
      p.move_to(cx + 0.7143 * u, cy + -0.6429 * u)
      p.line_to(cx + 0.7143 * u, cy + 0.9286 * u)
      p.bezier_curve_to(cx + 0.7143 * u, cy + 0.9494 * u, cx + 0.7076 * u, cy + 0.9665 * u, cx + 0.6942 * u, cy + 0.9799 * u)
      p.bezier_curve_to(cx + 0.6808 * u, cy + 0.9933 * u, cx + 0.6637 * u, cy + 1 * u, cx + 0.6429 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.622 * u, cy + 1 * u, cx + 0.6049 * u, cy + 0.9933 * u, cx + 0.5915 * u, cy + 0.9799 * u)
      p.bezier_curve_to(cx + 0.5781 * u, cy + 0.9665 * u, cx + 0.5714 * u, cy + 0.9494 * u, cx + 0.5714 * u, cy + 0.9286 * u)
      p.line_to(cx + 0.5714 * u, cy + -0.5714 * u)
      p.line_to(cx + -0.9286 * u, cy + -0.5714 * u)
      p.bezier_curve_to(cx + -0.9494 * u, cy + -0.5714 * u, cx + -0.9665 * u, cy + -0.5781 * u, cx + -0.9799 * u, cy + -0.5915 * u)
      p.bezier_curve_to(cx + -0.9933 * u, cy + -0.6049 * u, cx + -1 * u, cy + -0.622 * u, cx + -1 * u, cy + -0.6429 * u)
      p.bezier_curve_to(cx + -1 * u, cy + -0.6637 * u, cx + -0.9933 * u, cy + -0.6808 * u, cx + -0.9799 * u, cy + -0.6942 * u)
      p.bezier_curve_to(cx + -0.9665 * u, cy + -0.7076 * u, cx + -0.9494 * u, cy + -0.7143 * u, cx + -0.9286 * u, cy + -0.7143 * u)
      p.line_to(cx + 0.6429 * u, cy + -0.7143 * u)
      p.bezier_curve_to(cx + 0.6637 * u, cy + -0.7143 * u, cx + 0.6808 * u, cy + -0.7076 * u, cx + 0.6942 * u, cy + -0.6942 * u)
      p.bezier_curve_to(cx + 0.7076 * u, cy + -0.6808 * u, cx + 0.7143 * u, cy + -0.6637 * u, cx + 0.7143 * u, cy + -0.6429 * u)
      p.close_path()
      p.fill()
    }
    YhMagicStick => { // magic-stick
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.0314 * u, cy + -1 * u)
      p.line_to(cx + 0.1804 * u, cy + -1 * u)
      p.line_to(cx + 0.1804 * u, cy + -0.553 * u)
      p.line_to(cx + 0.0314 * u, cy + -0.553 * u)
      p.line_to(cx + 0.0314 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.0314 * u, cy + 0.3411 * u)
      p.line_to(cx + 0.1804 * u, cy + 0.3411 * u)
      p.line_to(cx + 0.1804 * u, cy + 0.7881 * u)
      p.line_to(cx + 0.0314 * u, cy + 0.7881 * u)
      p.line_to(cx + 0.0314 * u, cy + 0.3411 * u)
      p.close_path()
      p.move_to(cx + -0.7881 * u, cy + -0.0314 * u)
      p.line_to(cx + -0.7881 * u, cy + -0.1805 * u)
      p.line_to(cx + -0.3411 * u, cy + -0.1805 * u)
      p.line_to(cx + -0.3411 * u, cy + -0.0314 * u)
      p.line_to(cx + -0.7881 * u, cy + -0.0314 * u)
      p.close_path()
      p.move_to(cx + 0.5529 * u, cy + -0.0314 * u)
      p.line_to(cx + 0.5529 * u, cy + -0.1805 * u)
      p.line_to(cx + 1 * u, cy + -0.1805 * u)
      p.line_to(cx + 1 * u, cy + -0.0314 * u)
      p.line_to(cx + 0.5529 * u, cy + -0.0314 * u)
      p.close_path()
      p.move_to(cx + -0.5786 * u, cy + -0.6857 * u)
      p.line_to(cx + -0.4738 * u, cy + -0.7904 * u)
      p.line_to(cx + -0.1572 * u, cy + -0.4738 * u)
      p.line_to(cx + -0.2619 * u, cy + -0.369 * u)
      p.close_path()
      p.move_to(cx + 0.369 * u, cy + 0.262 * u)
      p.line_to(cx + 0.4737 * u, cy + 0.1572 * u)
      p.line_to(cx + 0.7904 * u, cy + 0.4738 * u)
      p.line_to(cx + 0.6856 * u, cy + 0.5786 * u)
      p.close_path()
      p.move_to(cx + -0.8952 * u, cy + 1 * u)
      p.line_to(cx + -1 * u, cy + 0.8952 * u)
      p.line_to(cx + -0.2619 * u, cy + 0.1572 * u)
      p.line_to(cx + -0.1572 * u, cy + 0.262 * u)
      p.close_path()
      p.move_to(cx + 0.4738 * u, cy + -0.369 * u)
      p.line_to(cx + 0.3691 * u, cy + -0.4738 * u)
      p.line_to(cx + 0.6857 * u, cy + -0.7904 * u)
      p.line_to(cx + 0.7905 * u, cy + -0.6857 * u)
      p.close_path()
      p.fill()
    }
    YhWallet => { // wallet
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0.92 * u, cy + -1 * u)
      p.line_to(cx + -0.92 * u, cy + -1 * u)
      p.bezier_curve_to(cx + -0.9643 * u, cy + -1 * u, cx + -1 * u, cy + -0.9643 * u, cx + -1 * u, cy + -0.92 * u)
      p.line_to(cx + -1 * u, cy + 0.92 * u)
      p.bezier_curve_to(cx + -1 * u, cy + 0.9643 * u, cx + -0.9643 * u, cy + 1 * u, cx + -0.92 * u, cy + 1 * u)
      p.line_to(cx + 0.92 * u, cy + 1 * u)
      p.bezier_curve_to(cx + 0.9643 * u, cy + 1 * u, cx + 1 * u, cy + 0.9643 * u, cx + 1 * u, cy + 0.92 * u)
      p.line_to(cx + 1 * u, cy + -0.92 * u)
      p.bezier_curve_to(cx + 1 * u, cy + -0.9643 * u, cx + 0.9643 * u, cy + -1 * u, cx + 0.92 * u, cy + -1 * u)
      p.close_path()
      p.move_to(cx + 0.82 * u, cy + 0.16 * u)
      p.line_to(cx + 0.04 * u, cy + 0.16 * u)
      p.line_to(cx + 0.04 * u, cy + -0.16 * u)
      p.line_to(cx + 0.82 * u, cy + -0.16 * u)
      p.line_to(cx + 0.82 * u, cy + 0.16 * u)
      p.close_path()
      p.move_to(cx + 0.82 * u, cy + 0.82 * u)
      p.line_to(cx + -0.82 * u, cy + 0.82 * u)
      p.line_to(cx + -0.82 * u, cy + -0.82 * u)
      p.line_to(cx + 0.82 * u, cy + -0.82 * u)
      p.line_to(cx + 0.82 * u, cy + -0.32 * u)
      p.line_to(cx + -0.04 * u, cy + -0.32 * u)
      p.bezier_curve_to(cx + -0.0843 * u, cy + -0.32 * u, cx + -0.12 * u, cy + -0.2843 * u, cx + -0.12 * u, cy + -0.24 * u)
      p.line_to(cx + -0.12 * u, cy + 0.24 * u)
      p.bezier_curve_to(cx + -0.12 * u, cy + 0.2843 * u, cx + -0.0843 * u, cy + 0.32 * u, cx + -0.04 * u, cy + 0.32 * u)
      p.line_to(cx + 0.82 * u, cy + 0.32 * u)
      p.line_to(cx + 0.82 * u, cy + 0.82 * u)
      p.close_path()
      p.move_to(cx + 0.27 * u, cy + 0 * u)
      p.close_path()
      p.move_to(cx + 0.17 * u, cy + 0 * u)
      p.line_to(cx + 0.1715 * u, cy + 0.0174 * u)
      p.line_to(cx + 0.176 * u, cy + 0.0342 * u)
      p.line_to(cx + 0.1834 * u, cy + 0.05 * u)
      p.line_to(cx + 0.1934 * u, cy + 0.0643 * u)
      p.line_to(cx + 0.2057 * u, cy + 0.0766 * u)
      p.line_to(cx + 0.22 * u, cy + 0.0866 * u)
      p.line_to(cx + 0.2358 * u, cy + 0.094 * u)
      p.line_to(cx + 0.2526 * u, cy + 0.0985 * u)
      p.line_to(cx + 0.27 * u, cy + 0.1 * u)
      p.line_to(cx + 0.2874 * u, cy + 0.0985 * u)
      p.line_to(cx + 0.3042 * u, cy + 0.094 * u)
      p.line_to(cx + 0.32 * u, cy + 0.0866 * u)
      p.line_to(cx + 0.3343 * u, cy + 0.0766 * u)
      p.line_to(cx + 0.3466 * u, cy + 0.0643 * u)
      p.line_to(cx + 0.3566 * u, cy + 0.05 * u)
      p.line_to(cx + 0.364 * u, cy + 0.0342 * u)
      p.line_to(cx + 0.3685 * u, cy + 0.0174 * u)
      p.line_to(cx + 0.37 * u, cy + 0 * u)
      p.line_to(cx + 0.3685 * u, cy + -0.0174 * u)
      p.line_to(cx + 0.364 * u, cy + -0.0342 * u)
      p.line_to(cx + 0.3566 * u, cy + -0.05 * u)
      p.line_to(cx + 0.3466 * u, cy + -0.0643 * u)
      p.line_to(cx + 0.3343 * u, cy + -0.0766 * u)
      p.line_to(cx + 0.32 * u, cy + -0.0866 * u)
      p.line_to(cx + 0.3042 * u, cy + -0.094 * u)
      p.line_to(cx + 0.2874 * u, cy + -0.0985 * u)
      p.line_to(cx + 0.27 * u, cy + -0.1 * u)
      p.line_to(cx + 0.2526 * u, cy + -0.0985 * u)
      p.line_to(cx + 0.2358 * u, cy + -0.094 * u)
      p.line_to(cx + 0.22 * u, cy + -0.0866 * u)
      p.line_to(cx + 0.2057 * u, cy + -0.0766 * u)
      p.line_to(cx + 0.1934 * u, cy + -0.0643 * u)
      p.line_to(cx + 0.1834 * u, cy + -0.05 * u)
      p.line_to(cx + 0.176 * u, cy + -0.0342 * u)
      p.line_to(cx + 0.1715 * u, cy + -0.0174 * u)
      p.line_to(cx + 0.17 * u, cy + 0 * u)
      p.close_path()
      p.fill()
    }
    YhBooks => { // books
      let u = s * 0.88
      p.begin_path()
      p.move_to(cx + 0 * u, cy + 0.2616 * u)
      p.line_to(cx + -0.6933 * u, cy + 0.7468 * u)
      p.line_to(cx + -0.6933 * u, cy + -0.8269 * u)
      p.line_to(cx + 0.6933 * u, cy + -0.8269 * u)
      p.line_to(cx + 0.6933 * u, cy + 0.7468 * u)
      p.line_to(cx + 0 * u, cy + 0.2616 * u)
      p.close_path()
      p.move_to(cx + 0 * u, cy + 0.473 * u)
      p.line_to(cx + 0.7302 * u, cy + 0.9843 * u)
      p.line_to(cx + 0.7427 * u, cy + 0.9916 * u)
      p.line_to(cx + 0.7563 * u, cy + 0.9967 * u)
      p.line_to(cx + 0.7706 * u, cy + 0.9995 * u)
      p.line_to(cx + 0.7852 * u, cy + 0.9998 * u)
      p.line_to(cx + 0.7995 * u, cy + 0.9977 * u)
      p.line_to(cx + 0.8134 * u, cy + 0.9933 * u)
      p.line_to(cx + 0.8263 * u, cy + 0.9866 * u)
      p.line_to(cx + 0.8379 * u, cy + 0.9778 * u)
      p.line_to(cx + 0.8478 * u, cy + 0.9672 * u)
      p.line_to(cx + 0.8559 * u, cy + 0.9551 * u)
      p.line_to(cx + 0.8618 * u, cy + 0.9418 * u)
      p.line_to(cx + 0.8654 * u, cy + 0.9277 * u)
      p.line_to(cx + 0.8666 * u, cy + 0.9132 * u)
      p.line_to(cx + 0.8666 * u, cy + -0.8267 * u)
      p.line_to(cx + 0.8639 * u, cy + -0.8568 * u)
      p.line_to(cx + 0.8561 * u, cy + -0.886 * u)
      p.line_to(cx + 0.8434 * u, cy + -0.9133 * u)
      p.line_to(cx + 0.826 * u, cy + -0.9381 * u)
      p.line_to(cx + 0.8047 * u, cy + -0.9595 * u)
      p.line_to(cx + 0.7799 * u, cy + -0.9768 * u)
      p.line_to(cx + 0.7525 * u, cy + -0.9895 * u)
      p.line_to(cx + 0.7234 * u, cy + -0.9974 * u)
      p.line_to(cx + 0.6933 * u, cy + -1 * u)
      p.line_to(cx + -0.6933 * u, cy + -1 * u)
      p.line_to(cx + -0.7234 * u, cy + -0.9974 * u)
      p.line_to(cx + -0.7525 * u, cy + -0.9895 * u)
      p.line_to(cx + -0.7799 * u, cy + -0.9768 * u)
      p.line_to(cx + -0.8047 * u, cy + -0.9595 * u)
      p.line_to(cx + -0.826 * u, cy + -0.9381 * u)
      p.line_to(cx + -0.8434 * u, cy + -0.9133 * u)
      p.line_to(cx + -0.8561 * u, cy + -0.886 * u)
      p.line_to(cx + -0.8639 * u, cy + -0.8568 * u)
      p.line_to(cx + -0.8666 * u, cy + -0.8267 * u)
      p.line_to(cx + -0.8666 * u, cy + 0.9134 * u)
      p.line_to(cx + -0.8654 * u, cy + 0.9279 * u)
      p.line_to(cx + -0.8618 * u, cy + 0.942 * u)
      p.line_to(cx + -0.8559 * u, cy + 0.9553 * u)
      p.line_to(cx + -0.8478 * u, cy + 0.9674 * u)
      p.line_to(cx + -0.8379 * u, cy + 0.9779 * u)
      p.line_to(cx + -0.8263 * u, cy + 0.9867 * u)
      p.line_to(cx + -0.8134 * u, cy + 0.9934 * u)
      p.line_to(cx + -0.7995 * u, cy + 0.9979 * u)
      p.line_to(cx + -0.7852 * u, cy + 1 * u)
      p.line_to(cx + -0.7706 * u, cy + 0.9997 * u)
      p.line_to(cx + -0.7563 * u, cy + 0.9969 * u)
      p.line_to(cx + -0.7427 * u, cy + 0.9918 * u)
      p.line_to(cx + -0.7302 * u, cy + 0.9845 * u)
      p.line_to(cx + 0 * u, cy + 0.4732 * u)
      p.close_path()
      p.fill()
    }
      // ---- icons-gen:end ----
  }
}

///|
/// 全部图标种类清单(181 项,图标墙/选取器素材)。
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
    Type,
    ArrowUpDown,
    AlignJustify,
    Move,
    Expand,
    Shrink,
    RotateCw,
    RotateCcw,
    Columns,
    Rows,
    CheckCircle,
    XCircle,
    InfoCircle,
    Loader,
    BellRing,
    Pin,
    Share,
    UserPlus,
    UserCheck,
    Users,
    Cloudy,
    CloudSun,
    CloudRain,
    CloudSnow,
    Droplet,
    Thermometer,
    Wind,
    Keyboard,
    Mouse,
    Headphones,
    Battery,
    BatteryCharging,
    Signal,
    ShoppingCart,
    CreditCard,
    Gift,
    Percent,
    Rocket,
    Trophy,
    Lightbulb,
    Wrench,
    Compass,
    MapPin,
    Navigation,
    Crown,
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
    Type => "Type"
    ArrowUpDown => "ArrowUpDown"
    AlignJustify => "AlignJustify"
    Move => "Move"
    Expand => "Expand"
    Shrink => "Shrink"
    RotateCw => "RotateCw"
    RotateCcw => "RotateCcw"
    Columns => "Columns"
    Rows => "Rows"
    CheckCircle => "CheckCircle"
    XCircle => "XCircle"
    InfoCircle => "InfoCircle"
    Loader => "Loader"
    BellRing => "BellRing"
    Pin => "Pin"
    Share => "Share"
    UserPlus => "UserPlus"
    UserCheck => "UserCheck"
    Users => "Users"
    Cloudy => "Cloudy"
    CloudSun => "CloudSun"
    CloudRain => "CloudRain"
    CloudSnow => "CloudSnow"
    Droplet => "Droplet"
    Thermometer => "Thermometer"
    Wind => "Wind"
    Keyboard => "Keyboard"
    Mouse => "Mouse"
    Headphones => "Headphones"
    Battery => "Battery"
    BatteryCharging => "BatteryCharging"
    Signal => "Signal"
    ShoppingCart => "ShoppingCart"
    CreditCard => "CreditCard"
    Gift => "Gift"
    Percent => "Percent"
    Rocket => "Rocket"
    Trophy => "Trophy"
    Lightbulb => "Lightbulb"
    Wrench => "Wrench"
    Compass => "Compass"
    MapPin => "MapPin"
    Navigation => "Navigation"
    Crown => "Crown"
    // ---- icons-gen:names
    YhTreeStructure => "yh/tree-structure"
    YhTreeTable => "yh/tree-table"
    YhTable => "yh/table"
    YhTab => "yh/tab"
    YhTextField => "yh/text-field"
    YhTextarea => "yh/textarea-field"
    YhNumberField => "yh/number-field"
    YhSelectField => "yh/select-field"
    YhEditTable => "yh/edit-table"
    YhScript => "yh/script"
    YhFunction => "yh/yunhang"
    YhParams => "yh/canshu"
    YhQueryFilter => "yh/tiaojianchaxun"
    YhFontSize => "yh/font-size"
    YhFontColor => "yh/font-colors"
    YhLineHeight => "yh/line-height"
    YhStrikethrough => "yh/strikethrough"
    YhIndent => "yh/indent"
    YhOutdent => "yh/outdent"
    YhColumnHeight => "yh/colum-height"
    YhColumnWidth => "yh/column-width"
    YhVAlignBottom => "yh/vertical-align-botto"
    YhVAlignMiddle => "yh/vertical-align-middl"
    YhVAlignTop => "yh/vertical-align-top"
    YhBorderOuter => "yh/border-outer"
    YhBorderTop => "yh/border-top"
    YhBorderBottom => "yh/border-bottom"
    YhBorderLeft => "yh/border-left"
    YhBorderRight => "yh/border-right"
    YhBorderInner => "yh/border-inner"
    YhBorderVertical => "yh/border-verticle"
    YhBorderHorizontal => "yh/border-horizontal"
    YhAppstore => "yh/appstore"
    YhFullscreen => "yh/full-screen"
    YhFullscreenExit => "yh/fullscreen-exit"
    YhToTop => "yh/totop"
    YhSwap => "yh/swap"
    YhRollback => "yh/rollback"
    YhEnter => "yh/enter"
    YhDrag => "yh/drag"
    YhMenuFold => "yh/menu-fold"
    YhMenuUnfold => "yh/menu-unfold"
    YhSortDesc => "yh/sort-descending"
    YhSortAsc => "yh/sort-ascending"
    YhFile => "yh/file"
    YhFilePdf => "yh/file-pdf"
    YhFileWord => "yh/file-word"
    YhFileExcel => "yh/file-excel"
    YhFilePpt => "yh/file-ppt"
    YhFileZip => "yh/file-zip"
    YhFileMarkdown => "yh/file-markdown"
    YhFileSearch => "yh/filesearch"
    YhSnippets => "yh/snippets"
    YhCloudServer => "yh/cloud-server"
    YhCloudSync => "yh/cloud-sync"
    YhApi => "yh/api"
    YhGateway => "yh/gateway"
    YhQrcode => "yh/qrcode"
    YhBarcode => "yh/barcode"
    YhScan => "yh/scan1"
    YhLaptop => "yh/laptop"
    YhTablet => "yh/tablet"
    YhUsb => "yh/USB"
    YhVideo => "yh/video1"
    YhAreaChart => "yh/areachart"
    YhLineChart => "yh/linechart"
    YhRadarChart => "yh/radarchart"
    YhBoxplot => "yh/boxplot"
    YhDashboard => "yh/dashboard1"
    YhIdcard => "yh/idcard"
    YhContacts => "yh/contacts"
    YhStop => "yh/stop"
    YhExport => "yh/export"
    YhImport => "yh/Import"
    YhSmile => "yh/smile"
    YhFrown => "yh/frown"
    YhPaperclip => "yh/attachment"
    YhCrop => "yh/crop"
    YhMagicStick => "yh/magic-stick"
    YhWallet => "yh/wallet"
    YhBooks => "yh/books"
      // ---- icons-gen:end ----
  }
}

///|
/// 图标展示视图:颜色默认主题常规文字色,传 color 固定色。
/// size 为视图边长(默认与 Body 正文字号一致,图文并排时基线协调),
/// 图标内容约占 84%。
pub fn icon(kind : IconKind, size? : Double = 13.0, color? : String = "") -> Node {
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
/// on_click;tip 非空时挂原生悬浮提示。默认 marginRight 6 便于工具栏
/// 横向排列;style/style_str 由调用方追加(后应用,可覆盖默认值,
/// 如去掉右边距 ["marginRight", 0.0] 或加外边距)。
pub fn icon_button_t(
  kind : IconKind,
  on_click? : () -> Unit = fn() {  },
  size? : Double = 28.0,
  tip? : String = "",
  style? : Array[(String, Double)] = [],
  style_str? : Array[(String, String)] = [],
) -> Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      let focused = Ref(false)
      let base : Array[(String, Double)] = [
        ("width", size),
        ("height", size),
        ("marginRight", 6.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let v = themed_container(style=base, style_str~)
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
