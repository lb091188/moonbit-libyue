// 图标库页:181 个内置矢量图标按分组展示,悬停看名称。
// 网格为竖排 vbox 包行(每行 10 个)——外层容器必须 vbox,否则行组被
// 水平排布、超宽截断(图标墙首版即此 bug)。

///|
/// 一组图标的网格:vbox 包行,每行 per_row 个,悬停 tooltip 显示名称。
fn icon_grid(kinds : Array[@yue.IconKind], per_row : Int) -> @yue.Node {
  let rows : Array[@yue.Node] = []
  for row in 0..<((kinds.length() + per_row - 1) / per_row) {
    let items : Array[@yue.Node] = []
    for col in 0..<per_row {
      let idx = row * per_row + col
      if idx < kinds.length() {
        items.push(
          @yue.tooltip_t(
            @yue.icon(kinds[idx], size=18.0),
            @yue.icon_name(kinds[idx]),
          ),
        )
      }
    }
    rows.push(@yue.hbox(items, style=[("gap", 10.0)]))
  }
  @yue.vbox(rows, style=[("gap", 8.0)])
}

///|
/// 图标页各分组共用的演示代码形态:icon 画矢量图标,悬停 tooltip 显名。
fn icon_group_code(sample : Array[String]) -> Array[String] {
  let head : Array[String] = [
    "// @yue.icon(图标, size, color):181 个内置矢量图标,颜色默认跟主题",
    "@yue.hbox([",
  ]
  for line in sample {
    head.push(line)
  }
  head.push("  // …本组其余图标同构")
  head.push("], style=[(\"gap\", 10.0)])")
  head
}

///|
fn page_icons(_app : App) -> @yue.Node {
  scroll_page([
    section(
      "基础",
      "基础",
      "方向/开关/状态等通用图标。",
      [
        icon_grid(
          [
            @yue.ChevronLeft,
            @yue.ChevronRight,
            @yue.ChevronUp,
            @yue.ChevronDown,
            @yue.ArrowUp,
            @yue.ArrowLeft,
            @yue.ArrowRight,
            @yue.ArrowDown,
            @yue.Plus,
            @yue.Minus,
            @yue.Close,
            @yue.Check,
            @yue.Search,
            @yue.Hamburger,
            @yue.Home,
            @yue.Gear,
            @yue.Refresh,
            @yue.Trash,
            @yue.Edit,
            @yue.Save,
            @yue.Folder,
            @yue.FileDoc,
            @yue.User,
            @yue.Star,
            @yue.Calendar,
            @yue.Filter,
            @yue.Copy,
            @yue.Download,
            @yue.Upload,
            @yue.Play,
            @yue.Pause,
            @yue.Info,
            @yue.Warning,
            @yue.Error,
            @yue.Success,
            @yue.Ellipsis,
            @yue.Grip,
            @yue.Pin,
            @yue.UserPlus,
            @yue.UserCheck,
            @yue.Users,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.ChevronLeft, size=18.0),", "  @yue.icon(@yue.Check, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.Star, size=18.0), @yue.icon_name(@yue.Star)),",
      ]),
    ),
    section(
      "文件",
      "文件与文档",
      "文件/文件夹/剪贴板/书签。",
      [
        icon_grid(
          [
            @yue.FilePlus,
            @yue.FolderOpen,
            @yue.FolderPlus,
            @yue.Clipboard,
            @yue.Book,
            @yue.Bookmark,
            @yue.FileCode,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.FolderOpen, size=18.0),", "  @yue.icon(@yue.FileCode, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.Book, size=18.0), @yue.icon_name(@yue.Book)),",
      ]),
    ),
    section(
      "编辑",
      "编辑",
      "撤销重做/剪切粘贴/排版/链接。",
      [
        icon_grid(
          [
            @yue.Undo,
            @yue.Redo,
            @yue.Scissors,
            @yue.Paste,
            @yue.Bold,
            @yue.Italic,
            @yue.Underline,
            @yue.AlignLeft,
            @yue.AlignCenter,
            @yue.AlignRight,
            @yue.ListUl,
            @yue.ListOl,
            @yue.Link,
            @yue.Unlink,
            @yue.ExternalLink,
            @yue.Type,
            @yue.ArrowUpDown,
            @yue.AlignJustify,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.Undo, size=18.0),", "  @yue.icon(@yue.Bold, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.Scissors, size=18.0), @yue.icon_name(@yue.Scissors)),",
      ]),
    ),
    section(
      "视图",
      "视图",
      "缩放/可见性/明暗/布局。",
      [
        icon_grid(
          [
            @yue.ZoomIn,
            @yue.ZoomOut,
            @yue.Eye,
            @yue.EyeOff,
            @yue.Sun,
            @yue.Moon,
            @yue.Grid,
            @yue.Layout,
            @yue.Sidebar,
            @yue.Move,
            @yue.Expand,
            @yue.Shrink,
            @yue.RotateCw,
            @yue.RotateCcw,
            @yue.Columns,
            @yue.Rows,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.ZoomIn, size=18.0),", "  @yue.icon(@yue.EyeOff, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.Moon, size=18.0), @yue.icon_name(@yue.Moon)),",
      ]),
    ),
    section(
      "导航",
      "导航",
      "双向翻页/跳段/返回。",
      [
        icon_grid(
          [
            @yue.ChevronsLeft,
            @yue.ChevronsRight,
            @yue.ChevronsUp,
            @yue.ChevronsDown,
            @yue.SkipBack,
            @yue.SkipForward,
            @yue.CornerUpLeft,
            @yue.CornerUpRight,
            @yue.Navigation,
            @yue.MapPin,
            @yue.Compass,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.ChevronsLeft, size=18.0),", "  @yue.icon(@yue.SkipForward, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.CornerUpLeft, size=18.0), @yue.icon_name(@yue.CornerUpLeft)),",
      ]),
    ),
    section(
      "媒体",
      "媒体",
      "录制/音量/麦克风/相机/图片/音符。",
      [
        icon_grid(
          [
            @yue.Square,
            @yue.CircleRecord,
            @yue.Volume,
            @yue.VolumeOff,
            @yue.Mic,
            @yue.Camera,
            @yue.Image,
            @yue.Music,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.Volume, size=18.0),", "  @yue.icon(@yue.Camera, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.Mic, size=18.0), @yue.icon_name(@yue.Mic)),",
      ]),
    ),
    section(
      "通信",
      "通信",
      "邮件/发送/消息/提醒/电话/订阅/网络。",
      [
        icon_grid(
          [
            @yue.Mail,
            @yue.Send,
            @yue.MessageCircle,
            @yue.Bell,
            @yue.BellOff,
            @yue.Phone,
            @yue.Rss,
            @yue.Globe,
            @yue.BellRing,
            @yue.Share,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.Mail, size=18.0),", "  @yue.icon(@yue.Bell, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.Send, size=18.0), @yue.icon_name(@yue.Send)),",
      ]),
    ),
    section(
      "系统",
      "系统",
      "电源/登录登出/锁钥/盾牌/存储/外设/网络/处理器。",
      [
        icon_grid(
          [
            @yue.Power,
            @yue.LogOut,
            @yue.LogIn,
            @yue.Lock,
            @yue.Unlock,
            @yue.Key,
            @yue.Shield,
            @yue.Sliders,
            @yue.Database,
            @yue.Server,
            @yue.HardDrive,
            @yue.Printer,
            @yue.Monitor,
            @yue.Smartphone,
            @yue.Wifi,
            @yue.WifiOff,
            @yue.Bluetooth,
            @yue.Cpu,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.Lock, size=18.0),", "  @yue.icon(@yue.Wifi, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.Cpu, size=18.0), @yue.icon_name(@yue.Cpu)),",
      ]),
    ),
    section(
      "开发",
      "开发",
      "终端/代码/Git/打包/调试/实验/云/分层/闪电。",
      [
        icon_grid(
          [
            @yue.Terminal,
            @yue.Code,
            @yue.GitBranch,
            @yue.GitCommit,
            @yue.GitPullRequest,
            @yue.Package,
            @yue.Bug,
            @yue.Flask,
            @yue.Cloud,
            @yue.CloudDownload,
            @yue.CloudUpload,
            @yue.Layers,
            @yue.Zap,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.Terminal, size=18.0),", "  @yue.icon(@yue.GitBranch, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.Bug, size=18.0), @yue.icon_name(@yue.Bug)),",
      ]),
    ),
    section(
      "语义",
      "语义与状态",
      "帮助/收藏/标记/时钟/标签/归档/收件/点赞。",
      [
        icon_grid(
          [
            @yue.Help,
            @yue.Heart,
            @yue.Flag,
            @yue.Clock,
            @yue.Tag,
            @yue.Archive,
            @yue.Inbox,
            @yue.ThumbsUp,
            @yue.CheckCircle,
            @yue.XCircle,
            @yue.InfoCircle,
            @yue.Loader,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.Help, size=18.0),", "  @yue.icon(@yue.Heart, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.Clock, size=18.0), @yue.icon_name(@yue.Clock)),",
      ]),
    ),
    section(
      "数据",
      "数据",
      "趋势/柱图/饼图/表格。",
      [
        icon_grid(
          [
            @yue.TrendingUp,
            @yue.TrendingDown,
            @yue.BarChart,
            @yue.PieChart,
            @yue.TableRows,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.TrendingUp, size=18.0),", "  @yue.icon(@yue.BarChart, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.PieChart, size=18.0), @yue.icon_name(@yue.PieChart)),",
      ]),
    ),
    section(
      "天气",
      "天气与环境",
      "云雨雪/水滴/温度/风;Sun/Moon 在「视图」组。",
      [
        icon_grid(
          [
            @yue.Cloudy,
            @yue.CloudSun,
            @yue.CloudRain,
            @yue.CloudSnow,
            @yue.Droplet,
            @yue.Thermometer,
            @yue.Wind,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.Cloudy, size=18.0),", "  @yue.icon(@yue.Thermometer, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.Wind, size=18.0), @yue.icon_name(@yue.Wind)),",
      ]),
    ),
    section(
      "设备",
      "设备与外设",
      "键盘/鼠标/耳机/电池/信号。",
      [
        icon_grid(
          [
            @yue.Keyboard,
            @yue.Mouse,
            @yue.Headphones,
            @yue.Battery,
            @yue.BatteryCharging,
            @yue.Signal,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.Keyboard, size=18.0),", "  @yue.icon(@yue.Battery, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.Signal, size=18.0), @yue.icon_name(@yue.Signal)),",
      ]),
    ),
    section(
      "商业",
      "商业与物体",
      "购物/支付/礼赠/百分比/火箭/奖杯/灯泡/扳手/皇冠。",
      [
        icon_grid(
          [
            @yue.ShoppingCart,
            @yue.CreditCard,
            @yue.Gift,
            @yue.Percent,
            @yue.Rocket,
            @yue.Trophy,
            @yue.Lightbulb,
            @yue.Wrench,
            @yue.Crown,
          ],
          12,
        ),
      ],
      code=icon_group_code([
        "  @yue.icon(@yue.ShoppingCart, size=18.0),", "  @yue.icon(@yue.Rocket, size=18.0),",
        "  @yue.tooltip_t(@yue.icon(@yue.Crown, size=18.0), @yue.icon_name(@yue.Crown)),",
      ]),
    ),
  ])
}
