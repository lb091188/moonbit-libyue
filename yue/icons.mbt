// 图标系统:统一矢量绘制入口 draw_icon + 展示视图 icon + 图标按钮
// icon_button_t。全库定案:图标一律矢量自绘,不依赖字体字形(字形图标
// Windows 渲染发虚、跨平台不一致,GTK align=Center 无效,矢量顺带解决
// 居中);全库填充型(iconfont 轮廓一次 fill)。绘制为数据形状:路径
// 以千分定点串存 icon_path_data,draw_icon 经 fill_icon_path 解释——
// 803 图标 ~0.6MB 数据替代旧代码形状 ~16MB 绘制代码(编译/体积双赢)。
// 主题跟随:on_draw 现取色板,theme_apply 触发整窗重绘。

///|
/// 图标种类(线条风格为主,个别实心)。绘制语义:中心 (cx,cy)、
/// s 为内容半径(半边长),坐标系同 Painter。
pub(all) enum IconKind {

  // ---- icons-gen:variants
  TreeStructure // 树形图
  Hide // 隐藏
  ClickButton // 点击按钮
  StaticText // 静态文字
  Switch // switch
  TextField // 单行输入框
  Textarea // 多行输入框
  NumberField // 数字输入框
  SelectField // 下拉多选
  TreeTable // 树形表格
  EditTable // 可编辑表格
  TableIcon // 表格
  TabIcon // 标签页
  Script // script
  Shangduiqi // 上对齐
  Youduiqi // 右对齐
  Zuoduiqi // 左对齐
  Weibiaoti545 // 撤销
  Dingceng // 顶层
  Diceng // 底层
  Shangyiyiceng // 上移一层
  Xiaduiqi // 下对齐
  Xiayiyiceng // 下移一层
  Daxiaoxiangdeng // 大小相等
  Tuceng // 图层
  ChatBar // 图表_柱状图
  Function // function
  Duiqi // 对齐
  Params // 参数
  Tucengzhizuoyuweihu // 图层制作与维护
  Kuaibuju // 块布局
  Shuxiangfenbu // 竖向分布
  Hengxiangfenbu1 // 横向分布
  Chicunbiaozhu_ // 自定义尺寸
  Zuoyoujuzhong // 左右居中
  Shangxiajuzhong // 上下居中
  Dengkuan // 09等宽
  Denggao // 10等高
  QueryFilter // 条件查询
  ZhushujushenqingShujufenxi02 // 主数据申请-数据分析-02
  Suofangdaodengbi // 缩放到等比
  Huifu // 恢复
  Menu1 // menu
  Microphone // microphone
  Minus1 // minus
  Message1 // message
  MapLocation // map-location
  MessageSolid // message-solid
  Mic // mic
  MilkTea // milk-tea
  Medal // medal
  Medal2 // medal-1
  Mobile1 // mobile
  MobilePhone // mobile-phone
  Money // money
  More1 // more
  NoSmoking // no-smoking
  MoreOutline // more-outline
  Notebook // notebook-2
  SHome // s-home
  News // news
  Notebook1 // notebook-1
  SOpen // s-open
  SMarketing // s-marketing
  Mouse // mouse
  SManagement // s-management
  SOperation // s-operation
  OfficeBuilding // office-building
  SwitchOpen // open
  Ship // ship
  Sell // sell
  Search2 // search
  Service // service
  Scissors // scissors
  Orange // orange
  PhoneOutline // phone-outline
  Picture // picture
  Receiving // receiving
  PictureOutlineRound // picture-outline-round
  PictureOutline // picture-outline
  PieChart // pie-chart
  SData // s-data
  Refrigerator // refrigerator
  SCooperation // s-cooperation
  SCheck // s-check
  SFlag // s-flag
  SCustom // s-custom
  SFinance // s-finance
  RemoveOutline // remove-outline
  SComment // s-comment
  Remove // remove
  School // school
  SShop // s-shop
  STicket // s-ticket
  SortUp // sort-up
  Sort // sort
  TakeawayBox // takeaway-box
  Stopwatch // stopwatch
  Thumb // thumb
  Tickets // tickets
  Truck // truck
  User1 // user
  UserSolid // user-solid
  VideoCameraSolid // video-camera-solid
  VideoPlay // video-play
  VideoCamera // video-camera
  Right1 // right
  VideoPause // video-pause
  StarOff // star-off
  Trophy1 // trophy
  Wallet1 // wallet
  Watch // watch
  WindPower // wind-power
  ViewIcon // view
  Watermelon // watermelon
  Share2 // share
  SetUp // set-up
  ZoomIn // zoom-in
  WaterCup // water-cup
  Warning // warning
  Watch2 // watch-1
  Setting1 // setting
  ZoomOut // zoom-out
  Pear // pear
  Paperclip // paperclip
  PlatformEleme // platform-eleme
  SClaim // s-claim
  SGoods // s-goods
  SGrid // s-grid
  SHelp // s-help
  ShoppingCart // shopping-cart-2
  Smoking // smoking
  Soccer // soccer
  SPromotion // s-promotion
  SortDown // sort-down
  SRelease // s-release
  SOpportunity // s-opportunity
  SOrder // s-order
  STools // s-tools
  SoldOut // sold-out
  SPlatform // s-platform
  Suitcase // suitcase
  Suitcase2 // suitcase-1
  Sugar // sugar
  Sunset // sunset
  Sunrise // sunrise-1
  TopLeft // top-left
  SwitchButton // switch-button
  ToiletPaper // toilet-paper
  TableLamp // table-lamp
  Tableware // tableware
  TopRight // top-right
  Top // top
  TurnOff // turn-off
  Monitor1 // monitor
  Unlock1 // unlock
  Postcard // postcard
  Umbrella // umbrella
  Moon // moon
  AddLocation // add-location
  Present // present
  Aim // aim
  Position // position
  Back // back
  PriceTag // price-tag
  ArrowLeft // arrow-left
  PotatoStrips // potato-strips
  Attract // attract
  ArrowRight // arrow-right
  Sunny // sunny
  ArrowUp // arrow-up
  MoonNight // moon-night
  AlarmClock // alarm-clock
  Reading // reading
  ArrowDown // arrow-down
  Rank // rank
  Apple1 // apple
  BottomRight // bottom-right
  Upload2 // upload
  Box // box
  Timer // timer
  Brush // brush
  Guide // guide
  BankCard // bank-card
  Trophy12 // trophy-1
  BottomLeft // bottom-left
  Bicycle // bicycle
  Baseball // baseball
  Basketball // basketball
  Burger // burger
  Bottom // bottom
  CScaleToOriginal // c-scale-to-original
  ChatDotRound // chat-dot-round
  ChatRound // chat-round
  ChatDotSquare // chat-dot-square
  ChatSquare // chat-square
  CircleClose // circle-close
  Chicken // chicken
  CloseNotification // close-notification
  Close2 // close
  Cherry // cherry
  CoffeeCup // coffee-cup
  Cloudy // cloudy
  CollectionTag // collection-tag
  ColdDrink // cold-drink
  Collection // collection
  Coordinate // coordinate
  Connection // connection
  Crop // crop
  Cpu // cpu
  CopyDocument // copy-document
  DCaret // d-caret
  DArrowRight // d-arrow-right
  DataBoard // data-board
  DataAnalysis // data-analysis
  DataLine // data-line
  DArrowLeft // d-arrow-left
  DeleteSolid // delete-solid
  DeleteLocation // delete-location
  Discount // discount
  Date // date
  Dessert // dessert
  Dish // dish
  Delete2 // delete
  DocumentCopy // document-copy
  Document // document
  Discover // discover
  DocumentAdd // document-add
  DocumentChecked // document-checked
  DocumentDelete // document-delete
  DocumentRemove // document-remove
  Dish2 // dish-1
  Download1 // download
  Coin // coin
  Female // female
  Film // film
  Error1 // error
  Eleme // eleme
  Coffee // coffee
  FolderRemove // folder-remove
  FolderChecked // folder-checked
  FolderAdd1 // folder-add
  FolderDelete // folder-delete
  Football // football
  Finished // finished
  ForkSpoon // fork-spoon
  FirstAidKit // first-aid-kit
  GobletFull // goblet-full
  Food // food
  Fullscreen // full-screen
  GobletSquareFull // goblet-square-full
  Goblet // goblet
  Goods // goods
  Headset // headset
  House // house
  IceCreamRound // ice-cream-round
  HotWater // hot-water
  HeavyRain // heavy-rain
  IceDrink // ice-drink
  IceCream // ice-cream
  Key1 // key
  IceCreamSquare // ice-cream-square
  KnifeFork // knife-fork
  IceTea // ice-tea
  Info // info
  Grape // grape
  LightRain // light-rain
  Lock1 // lock
  LocationOutline // location-outline
  Lightning // lightning
  MagicStick // magic-stick
  Link1 // link
  Lollipop // lollipop
  LoadingStep // loading
  Rest // rest
  BellFill // bell-fill
  Usb // USB
  FilterFill // filter-fill
  Skin // skin
  FireFill // fire-fill
  Home // home
  FunnelplotFill // funnel plot-fill
  Bank // bank
  GiftFill // gift-fill
  Filter1 // filter
  HourglassFill // hourglass-fill
  Funnelplot // funnel plot
  HomeFill // home-fill
  Like // like
  TrophyFill // trophy-fill
  Unlike // unlike
  LocationFill // location-fill
  Unlock // unlock
  CloudFill // cloud-fill
  Lock // lock
  CustomerserviceFill // customerservice-fill
  Customerservice // customerservice
  ExperimentFill // experiment-fill
  Flag // flag
  EyeFill // eye-fill
  Moneycollect // money collect
  LikeFill // like-fill
  Medicinebox // medicinebox
  LockFill // lock-fill
  Shop // shop
  UnlikeFill // unlike-fill
  Shopping // shopping
  StarFill // star-fill
  Folder // folder
  UnlockFill // unlock-fill
  FolderOpen // folder-open
  AlertFill // alert-fill
  ApiFill // api-fill
  Deploymentunit // deployment unit
  HighlightFill // highlight-fill
  Accountbook // account book
  PhoneFill // phone-fill
  Contacts // contacts
  EditFill // edit-fill
  Carryout // carry out
  PushpinFill // pushpin-fill
  CalendarCheck // calendar-check
  ThunderboltFill // thunderbolt-fill
  Calendar1 // calendar
  TagFill // tag-fill
  Scan // scan
  WrenchFill // wrench-fill
  Select // select
  TagsFill // tags-fill
  Boxplot // box plot
  BankFill // bank-fill
  Build // build
  CameraFill // camera-fill
  Sliders // sliders
  ErrorFill // error-fill
  Laptop // laptop
  CrownFill // crown-fill
  Barcode1 // barcode
  MailFill // mail-fill
  Camera // camera
  CarFill // car-fill
  Cluster // cluster
  PrinterFill // printer-fill
  Gateway // gateway
  ShopFill // shop-fill
  Car // car
  SettingFill // setting-fill
  Printer // printer
  USBFill // USB-fill
  Read // read
  GoldenFill // golden-fill
  CloudServer // cloud-server
  BuildFill // build-fill
  CloudUpload // cloud-upload
  BoxplotFill // box plot-fill
  Cloud // cloud
  SlidersFill // sliders-fill
  CloudDownload // cloud-download
  Alibaba // alibaba
  CloudSync // cloud-sync
  Alibabacloud // alibabacloud
  Video // video
  Antdesign // ant design
  NotificationIcon // notification
  AntCloud // ant-cloud
  Sound // sound
  Behance // behance
  RadarChart // radar chart
  Googleplus // google plus
  Qrcode // qrcode
  Medium // medium
  Fund // fund
  Google // google
  Image1 // image
  IE // IE
  Mail1 // mail
  Amazon // amazon
  Slack // slack
  Idcard // id card
  Alipay // alipay
  Creditcard // credit card
  Taobao // taobao
  Heart // heart
  Zhihu // zhihu
  Block // block
  HTML // HTML5
  Error // error
  Linkedin // linkedin
  Star // star
  Yahoo // yahoo
  Gold // gold
  Facebook // facebook
  Heatmap // heat map
  Skype // skype
  Wifi // wifi
  CodeSandbox // CodeSandbox
  Paperclip2 // attachment
  Chrome // chrome
  Edit1 // edit
  Aliwangwang // aliwangwang
  Key // key
  Apple // apple
  Api // api
  Android // android
  Disconnect // disconnect
  Sketch // sketch
  Highlight // highlight
  Gitlab // Gitlab
  Monitor // monitor
  Dribbble // dribbble
  Link // link
  Instagram // instagram
  Man // man
  Reddit // reddit
  Percentage // percentage
  Windows // windows
  Pushpin // pushpin
  Yuque // yuque
  Phone // phone
  Youtube // Youtube
  Shake // shake
  GitlabFill // Gitlab-fill
  Tag // tag
  Dropbox // dropbox
  Wrench // wrench
  Dingtalk // dingtalk
  Woman // woman
  AndroidFill // android-fill
  Tags // tags
  AppleFill // apple-fill
  Scissor // scissor
  HTMLFill // HTML5-fill
  Mr // mr
  WindowsFill // windows-fill
  Share1 // share
  QQ // QQ
  Branches // branches
  Twitter // twitter
  Fork // fork
  SkypeFill // skype-fill
  Shrink // shrink
  Weibo // weibo
  Arrawsalt // arrawsalt
  YuqueFill // yuque-fill
  Verticalright // vertical right
  YoutubeFill // Youtube-fill
  Verticalleft // vertical left
  YahooFill // yahoo-fill
  Wechat // wechat
  ChromeFill // chrome-fill
  AliwangwangFill // aliwangwang-fill
  FullscreenExit // fullscreen-exit
  GithubFill // github-fill
  MediumCircleFill // medium-circle-fill
  ColumnHeight // colum-height
  VAlignBottom // vertical-align-botto
  VAlignMiddle // vertical-align-middl
  ToTop // totop
  VAlignTop // vertical-align-top
  Download // download
  SortDesc // sort-descending
  SortAsc // sort-ascending
  Fall // fall
  Swap // swap
  Stock // stock
  Rise // rise
  Indent // indent
  Outdent // outdent
  MenuIcon // menu
  Unorderedlist // unordered list
  Orderedlist // ordered list
  AlignRight // align-right
  AlignCenter // align-center
  AlignLeft // align-left
  PicCenter // pic-center
  PicRight // pic-right
  PicLeft // pic-left
  Bold // bold
  FontColor // font-colors
  CheckCircle // check-circle
  Exclaimination // exclaimination
  CI // CI
  FontSize // font-size
  Dollar // Dollar
  Infomation // infomation
  Compass // compass
  LineHeight // line-height
  Strikethrough // strikethrough
  Frown // frown
  Underline // underline
  InfoCircle // info-circle
  Number // number
  LeftCircle // left-circle
  Italic // italic
  Loading // loading
  DownCircle // down-circle
  Code // code
  EURO // EURO
  ColumnWidth // column-width
  Copyright // copyright
  MinusCircle // minus-circle
  Meh // meh
  Dash // dash
  PlusCircle // plus-circle
  PlayCircle // play-circle
  Enter1 // enter
  QuestionCircle // question-circle
  Line // line
  Pound // Pound
  Minus // minus
  RightCircle // right-circle
  Question // question
  Smile // smile
  Plus // plus
  Trademark // trademark
  SmallDash // small-dash
  Pause // pause
  Earth // earth
  BgColors // bg-colors
  YUAN // YUAN
  Crown // crown
  UpCircle // up-circle
  Drag // drag
  WarningCircle // warning-circle
  Sync // sync
  Gift // gift
  Transaction // transaction
  Stop // stop
  Undo // undo
  Fire // fire
  Redo // redo
  Thunderbolt // thunderbolt
  Reload // reload
  CheckCircleFill // check-circle-fill
  Reloadtime // reload time
  LeftCircleFill // left-circle-fill
  Message // message
  DownCircleFill // down-circle-fill
  Dashboard // dashboard
  MinusCircleFill // minus-circle-fill
  Issuesclose // issues close
  CloseCircleFill // close-circle-fill
  Poweroff // poweroff
  InfoCircleFill // info-circle-fill
  Logout // logout
  UpCircleFill // up-circle-fill
  Login // login
  RightCircleFill // right-circle-fill
  Piechart // pie chart
  PlusCircleFill // plus-circle-fill
  QuestionCircleFill // question-circle-fill
  Eye // eye
  EUROCircleFill // EURO-circle-fill
  FrownFill // frown-fill
  CopyrightCircleFil // copyright-circle-fil
  Export // export
  CICircleFill // CI-circle-fill
  Save1 // save
  CompassFill // compass-fill
  Import // Import
  DollarCircleFill // Dollar-circle-fill
  Appstore // app store
  PoweroffCircleFill // poweroff-circle-fill
  MehFill // meh-fill
  PlayCircleFill // play-circle-fill
  Layout // layout
  PoundCircleFill // Pound-circle-fill
  SmileFill // smile-fill
  StopFill // stop-fill
  Control // control
  WarningCircleFill // warning-circle-fill
  Codelibrary // code library
  Detail // detail
  TrademarkCircleFil // trademark-circle-fil
  YUANCircleFill // YUAN-circle-fill
  HeartFill // heart-fill
  PiechartCircleFil // pie chart-circle-fil
  Project // project
  DashboardFill // dashboard-fill
  Wallet // wallet
  MessageFill // message-fill
  Calculator // calculator
  Interation // interation
  Border // border
  CodelibraryFill // code library-fill
  BorderOuter // border-outer
  BorderTop // border-top
  BorderBottom // border-bottom
  BorderLeft // border-left
  BorderRight // border-right
  BorderInner // border-inner
  AccountbookFill // account book-fill
  BorderVertical // border-verticle
  CarryoutFill // carry out-fill
  BorderHorizontal // border-horizontal
  CalendarFill // calendar-fill
  RadiusBottomleft // radius-bottomleft
  CalculatorFill // calculator-fill
  RadiusBottomright // radius-bottomright
  InterationFill // interation-fill
  RadiusUpleft // radius-upleft
  ProjectFill // project-fill
  RadiusUpright // radius-upright
  DetailFill // detail-fill
  RadiusSetting // radius-setting
  SaveFill // save-fill
  Adduser // add user
  WalletFill // wallet-fill
  Deleteteam // delete team
  ControlFill // control-fill
  Deleteuser // delete user
  LayoutFill // layout-fill
  Addteam // addteam
  AppstoreFill // app store-fill
  User // user
  MobileFill // mobile-fill
  Team // team
  TabletFill // tablet-fill
  AreaChart // area chart
  BookFill // book-fill
  LineChart // line chart
  RedenvelopeFill // red envelope-fill
  Barchart // bar chart
  SafetycertificateF // safety certificate-f
  Pointmap // point map
  PropertysafetyFill // property safety-fill
  ContainerIcon // container
  Database // database
  SecurityscanFill // security scan-fill
  Sever // sever
  FileExclamationFil // file-exclamation-fil
  Mobile // mobile
  FileAddFill // file-add-fill
  Tablet // tablet
  FileExcelFill // file-excel-fill
  Redenvelope // red envelope
  FileMarkdownFill // file-markdown-fill
  Book // book
  FileTextFill // file-text-fill
  Filedone // file done
  FilePptFill // file-ppt-fill
  Reconciliation // reconciliation
  FileUnknownFill // file-unknown-fill
  FileException // file -exception
  FileWordFill // file-word-fill
  Filesync // file sync
  FileZipFill // file-zip-fill
  FileSearch // file search
  FilePdfFill // file-pdf-fill
  Solution // solution
  FileImageFill // file-image-fill
  Fileprotect // file protect
  DiffFill // diff-fill
  FileAdd // file-add
  FileCopyFill // file-copy-fill
  FileExcel // file-excel
  SnippetsFill // snippets-fill
  FileExclamation // file-exclamation
  BatchfoldingFill // batch folding-fill
  FilePdf // file-pdf
  ReconciliationFill // reconciliation-fill
  FileImage // file-image
  FileMarkdown // file-markdown
  FolderFill // folder-fill
  FileUnknown // file-unknown
  FolderOpenFill // folder-open-fill
  FilePpt // file-ppt
  DatabaseFill // database-fill
  FileWord // file-word
  ContainerFill // container-fill
  File1 // file
  SeverFill // sever-fill
  FileZip // file-zip
  CalendarCheckFill // calendar-check-fill
  FileText // file-text
  ImageFill // image-fill
  FileCopy // file-copy
  IdcardFill // id card-fill
  Snippets // snippets
  CreditcardFill // credit card-fill
  Audit // audit
  FundFill // fund-fill
  Diff // diff
  ReadFill // read-fill
  Batchfolding // Batch folding
  ContactsFill // contacts-fill
  Securityscan // security scan
  Propertysafety // property safety
  NotificationFill // notification-fill
  Safetycertificate // safety certificate
  FlagFill // flag-fill
  MoneycollectFill // money collect-fill
  Alert // alert
  MedicineboxFill // medicine box-fill
  RestFill // rest-fill
  Hourglass // hourglass
  ShoppingFill // shopping-fill
  Bulb // bulb
  SkinFill // skin-fill
  Experiment // experiment
  VideoFill // video-fill
  Bell // bell
  SoundFill // sound-fill
  Trophy // trophy
  BulbFill // bulb-fill
  FuwuActive // 服务
  ShouyeShouye // 首页-首页
  Cangkuxinxi // 仓库信息
  Saomiao // 239扫描
  Iconset0254 // 条码
  Zhongsuanrenwuliebiao // 重算任务列表
  Xiangxiazhanhang // 向下占行
  Qita // 其他
  Xiajia // 下架
  Feiji // plane
  Tixing // 提醒
  Shaixuan_o // 筛选_o
  Siji // 司机
  Lianxiwomen // 联系我们
  Guanyuwomen // 关于我们
  Wode // 我的
  TruckFull // 货车
  Xiayibu // xiayibu
  Video2 // video
  ImageIcon // images
  File // file-fill
  Xinhao // 信号
  Gengduo // 更多
  Xuhao // 3序号
  Zhiye // 职业
  Weixian // 危险
  Apptubiao // 没有
  Jingdiananli_wujiaoxing_shoucanghou // 经典案例_五角星_收藏后
  Jingdiananli_kongwujiaoxing_shoucang // 经典案例_空五角星_收藏
  Caigou // 采购
  NaviconQtrkd // 其他入库单
  CustomWorker // 审批模型-工人
  Ruku // 入库
  Yichang // 异常
  Shougongpeidui // 12、手工配对
  Lunkuohua113 // -补货
  Jiebang // 解绑
  Goodsppeinventory // 资产盘点 goods/ppe/inventory
  Weixiujilu // 维修记录
  Taizhangguanli // 1台账管理
  Weixiu // 维修
  Baoxiu // 报修
  Daijiedan // 待接单
  Shebeidianjian // 设备点检
  Shebeidianjiantongji // 设备点检统计
  Baoyanggongdan // 保养工单
  Baoyangjihua // 保养计划
  Chart // chart
  ChartBar // chart-bar
  Filter // filter
  FilterClear // filter-clear
  Share // share
  Books // books
  Cart // cart
  Clear // clear
  MenuFold // menu-fold
  LockOff // lock-off
  Rotation // rotation
  Layers // layers
  LockOn // lock-on
  RootList // root-list
  AControlplatform // control.platform
  ChartBubble // chart-bubble
  CaretUpSmall // caret-up-small
  Enter // enter
  Rollfront // rollfront
  Jump // jump
  Rollback // rollback
  CaretRightSmall // caret-right-small
  Mirror // mirror
  Time // time
  UserAvatar // user-avatar
  UsergroupClear // usergroup-clear
  MinusRectangle // minus-rectangle
  FormatHorizontalAlignTop // format-horizontal-align-top
  Move1 // move
  Bulletpoint // bulletpoint
  Barcode // barcode
  LogoWecom // logo-wecom
  MenuUnfold // menu-unfold
  Tools // tools
  CaretLeftSmall // caret-left-small
  Round // round
  CaretDownSmall // caret-down-small
  Check // check
  APrecisemonitor // precise.monitor
  GenderFemale // gender-female
  AOrderAdjustmentcolumn // order-adjustment.column
  Queue // queue
  Print // print
  Ellipsis // ellipsis
  TimeFilled // time-filled
  Slash // slash
  HelpCircleFilled // help-circle-filled
  MenuApplication // menu-application
  Pin // pin
  UserTalk // user-talk
  More // more
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

///|
/// 实心多边形:points 依次连线闭合并填充。

///|
/// 闭合折线:依次连线后闭合并描边(轮廓图标)。

///|
/// 描边圆。

///|
/// 单线段。

///|
/// 描边圆弧(起止角为弧度,canvas 语义:0 = 右,顺时针为正)。

///|
/// 从定点路径串 d 的 d[i] 起读一个定点整数(可选负号,前导逗号跳过),
/// 返回 (值, 新下标)。
fn path_num(d : String, i : Int) -> (Double, Int) {
  let n = d.length()
  let mut j = i
  let mut neg = false
  while j < n {
    let c = d.unsafe_get(j).to_int()
    if c == 44 {
      j += 1 // ','
    } else if c == 45 {
      neg = true // '-'
      j += 1
      break
    } else {
      break
    }
  }
  let mut v = 0.0
  while j < n {
    let c = d.unsafe_get(j).to_int()
    if c >= 48 && c <= 57 {
      v = v * 10.0 + Double::from_int(c - 48)
      j += 1
    } else {
      break
    }
  }
  (if neg { -v } else { v }, j)
}

///|
/// 定点路径数据解释绘制:命令 M/L/C/Z(ASCII 单字符),坐标为归一化值
/// ×1000 的整数定点、逗号分隔;每子路径 M…Z 闭合,整体一次填充。
/// 坐标换算 v × s × 0.88 / 1000 + 中心(0.88 为图标安全边距,同生成器;
/// 单命令即读即调,数值解析全程微秒级,无需缓存)。
fn fill_icon_path(
    p : Painter, d : String, cx : Double, cy : Double, s : Double) -> Unit {
  let u = s * 0.88 / 1000.0
  let n = d.length()
  let mut i = 0
  p.begin_path()
  while i < n {
    let c = d.unsafe_get(i).to_int()
    i += 1
    if c == 90 {
      p.close_path()
    } else if c == 77 {
      let (x, i2) = path_num(d, i)
      i = i2
      let (y, i3) = path_num(d, i)
      i = i3
      p.move_to(cx + x * u, cy + y * u)
    } else if c == 76 {
      let (x, i2) = path_num(d, i)
      i = i2
      let (y, i3) = path_num(d, i)
      i = i3
      p.line_to(cx + x * u, cy + y * u)
    } else if c == 67 {
      let (x1, i2) = path_num(d, i)
      i = i2
      let (y1, i3) = path_num(d, i)
      i = i3
      let (x2, i4) = path_num(d, i)
      i = i4
      let (y2, i5) = path_num(d, i)
      i = i5
      let (px, i6) = path_num(d, i)
      i = i6
      let (py, i7) = path_num(d, i)
      i = i7
      p.bezier_curve_to(
        cx + x1 * u, cy + y1 * u, cx + x2 * u, cy + y2 * u, cx + px * u, cy + py * u,
      )
    } else {
      // 未知命令容错跳过,保持后续可解析
    }
  }
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
  // ---- icons-gen:dispatch
  fill_icon_path(p, icon_path_data[kind_index(kind)], cx, cy, s)
// ---- icons-gen:end ----
}

// ---- icons-gen:chunks
///|
/// 全部图标的定点路径数据(千分定点串,命令 M/L/C/Z),与
/// kind_index/all_icons 同序;绘制入口 fill_icon_path 解释执行。
let icon_path_data : Array[String] = [
  "M-200,-733L-867,-733C-904,-733,-933,-763,-933,-800L-933,-933C-933,-970,-904,-1000,-867,-1000L-200,-1000C-163,-1000,-133,-970,-133,-933L-133,-800C-133,-763,-163,-733,-200,-733ZM-867,1000C-904,1000,-933,970,-933,933L-933,-933C-933,-970,-904,-1000,-867,-1000C-830,-1000,-800,-970,-800,-933L-800,933C-800,970,-830,1000,-867,1000ZM-333,0C-370,0,-400,-30,-400,-67L-400,-533C-400,-570,-370,-600,-333,-600C-296,-600,-267,-570,-267,-533L-267,-67C-267,-30,-296,0,-333,0ZM-933,-467C-933,-504,-904,-533,-867,-533L-335,-533C-299,-533,-269,-504,-269,-467C-269,-430,-299,-400,-335,-400L-867,-400C-904,-400,-933,-430,-933,-467ZM-400,-67C-400,-104,-370,-133,-333,-133L304,-133C341,-133,371,-104,371,-67C371,-30,341,0,304,0L-333,0C-370,0,-400,-30,-400,-67ZM-333,800C-370,800,-400,770,-400,733L-400,267C-400,230,-370,200,-333,200C-296,200,-267,230,-267,267L-267,733C-267,770,-296,800,-333,800ZM-400,733C-400,696,-370,667,-333,667L304,667C341,667,371,696,371,733C371,770,341,800,304,800L-333,800C-370,800,-400,770,-400,733ZM-933,333C-933,296,-904,267,-867,267L-335,267C-299,267,-269,296,-269,333C-269,370,-299,400,-335,400L-867,400C-904,400,-933,370,-933,333ZM333,-333L-333,-333C-370,-333,-400,-363,-400,-400L-400,-533C-400,-570,-370,-600,-333,-600L333,-600C370,-600,400,-570,400,-533L400,-400C400,-363,370,-333,333,-333ZM867,67L200,67C163,67,133,37,133,0L133,-133C133,-170,163,-200,200,-200L867,-200C904,-200,933,-170,933,-133L933,0C933,37,904,67,867,67ZM867,867L200,867C163,867,133,837,133,800L133,667C133,630,163,600,200,600L867,600C904,600,933,630,933,667L933,800C933,837,904,867,867,867ZM333,467L-333,467C-370,467,-400,437,-400,400L-400,267C-400,230,-370,200,-333,200L333,200C370,200,400,230,400,267L400,400C400,437,370,467,333,467Z",
  "M0,-658C368,-658,702,-436,1000,8C702,453,368,675,0,675C-368,675,-702,453,-1000,8C-702,-436,-368,-658,0,-658ZM0,-492C-283,-492,-550,-342,-833,8C-561,346,-306,495,0,508C283,508,550,359,833,8C561,-329,306,-478,0,-492ZM699,-825L816,-707L-716,825L-833,707ZM0,-325L58,-320L114,-305L167,-280L214,-247L255,-206L289,-158L313,-106L328,-50L333,8L328,66L313,122L289,175L255,223L214,264L167,297L114,322L58,337L0,342L-58,337L-114,322L-167,297L-214,264L-255,223L-289,175L-313,122L-328,66L-333,8L-328,-50L-313,-106L-289,-158L-255,-206L-214,-247L-167,-280L-114,-305L-58,-320L0,-325ZM0,-158L-29,-156L-57,-148L-83,-136L-107,-119L-128,-99L-144,-75L-157,-49L-164,-21L-167,8L-164,37L-157,65L-144,92L-128,115L-107,136L-83,153L-57,165L-29,172L0,175L29,172L57,165L83,153L107,136L128,115L144,92L157,65L164,37L167,8L164,-21L157,-49L144,-75L128,-99L107,-119L83,-136L57,-148L29,-156L0,-158Z",
  "M516,700C497,690,498,691,421,557L409,535L380,565C348,597,326,607,304,602C292,599,268,579,262,568C260,564,248,505,237,437C225,368,214,307,213,301L210,291L-297,291C-652,291,-810,289,-824,286C-893,272,-961,211,-988,138L-997,113L-998,-200C-999,-549,-1000,-541,-973,-593C-945,-645,-889,-689,-831,-703C-809,-708,-705,-709,-2,-709C701,-709,806,-708,827,-703C908,-684,979,-612,995,-534C998,-520,1000,-415,1000,-212C999,123,1000,116,973,167C954,204,913,245,876,264C834,286,812,291,738,291L674,291L690,305C743,351,720,415,647,425C637,427,629,429,629,430C629,432,647,457,670,488C697,523,713,547,715,557C719,575,713,602,702,615C697,621,666,643,633,666C580,701,571,706,553,707C537,709,529,707,516,700ZM591,593C610,581,624,568,623,566C622,563,597,528,567,488C508,411,505,404,517,381C524,368,543,360,583,353C598,350,609,347,608,345C606,340,253,25,251,26C250,27,258,78,269,139L289,253L309,367C320,431,330,486,330,489C332,493,345,483,367,461C400,430,403,427,418,427C442,427,455,444,508,538C532,582,553,618,555,618C556,617,572,606,591,593ZM195,205C195,203,187,151,176,90C165,29,156,-27,156,-35C156,-54,170,-79,185,-88C201,-98,232,-98,248,-89C255,-85,332,-16,421,64L583,209L683,209C739,209,794,207,807,204C853,196,889,166,907,123L916,101L916,-527L904,-552C891,-581,867,-603,836,-616L814,-625L14,-626C-558,-627,-794,-626,-812,-623C-860,-615,-897,-584,-910,-540C-914,-527,-915,-452,-915,-213C-915,78,-915,99,-908,119C-894,162,-857,196,-815,204C-791,209,195,210,195,205Z",
  "M-718,-846C-730,-846,-741,-845,-751,-842L-764,-840L-778,-840L-791,-842L-804,-846L-815,-853L-825,-862L-834,-872L-841,-884L-845,-896L-848,-909L-848,-923L-845,-936L-841,-949L-834,-960L-825,-971L-815,-979L-804,-986L-791,-990C-768,-997,-743,-1000,-718,-1000L-638,-1000L-625,-999L-612,-995L-600,-990L-589,-982L-579,-973L-572,-962L-566,-949L-562,-936L-561,-923L-562,-910L-566,-897L-572,-885L-579,-874L-589,-864L-600,-856L-612,-851L-625,-847L-638,-846L-718,-846ZM-396,-923L-395,-936L-391,-949L-386,-962L-378,-973L-369,-982L-358,-990L-345,-995L-332,-999L-319,-1000L-160,-1000L-146,-999L-133,-995L-121,-990L-110,-982L-101,-973L-93,-962L-87,-949L-84,-936L-83,-923L-84,-910L-87,-897L-93,-885L-101,-874L-110,-864L-121,-856L-133,-851L-146,-847L-160,-846L-319,-846L-332,-847L-345,-851L-357,-856L-368,-864L-378,-874L-386,-885L-391,-897L-395,-910L-396,-923ZM83,-923L84,-936L87,-949L93,-962L101,-973L110,-982L121,-990L133,-995L146,-999L160,-1000L319,-1000L332,-999L345,-995L358,-990L369,-982L378,-973L386,-962L391,-949L395,-936L396,-923L395,-910L391,-897L386,-885L378,-874L369,-864L358,-856L345,-851L332,-847L319,-846L160,-846L146,-847L133,-851L121,-856L110,-864L101,-874L93,-885L87,-897L84,-910L83,-923ZM561,-923L562,-936L566,-949L572,-962L579,-973L589,-982L600,-990L612,-995L625,-999L638,-1000L718,-1000C743,-1000,768,-997,791,-990L804,-986L815,-979L825,-971L834,-960L841,-949L845,-936L848,-923L848,-909L845,-896L841,-884L834,-872L825,-862L815,-853L804,-846L791,-842L778,-839L764,-839L751,-842L735,-845L718,-846L638,-846L625,-847L612,-851L600,-856L589,-864L579,-874L572,-885L566,-897L562,-910L561,-923ZM-896,-845L-884,-841L-872,-834L-862,-825L-853,-815L-846,-804L-842,-791L-839,-778L-839,-764L-842,-751L-845,-735L-846,-718L-846,-638L-847,-625L-851,-612L-856,-600L-864,-589L-874,-579L-885,-572L-897,-566L-910,-562L-923,-561L-936,-562L-949,-566L-961,-572L-972,-579L-982,-589L-990,-600L-995,-612L-999,-625L-1000,-638L-1000,-718C-1000,-743,-997,-768,-990,-791L-986,-804L-979,-815L-971,-825L-960,-834L-949,-841L-936,-845L-923,-848L-909,-848L-896,-845ZM896,-845L909,-848L923,-848L936,-845L949,-841L960,-834L971,-825L979,-815L986,-804L990,-791C997,-768,1000,-743,1000,-718L1000,-638L999,-625L995,-612L990,-600L982,-589L972,-579L961,-572L949,-566L936,-562L923,-561L910,-562L897,-566L885,-572L874,-579L864,-589L856,-600L851,-612L847,-625L846,-638L846,-718C846,-730,845,-741,842,-751L839,-764L839,-778L842,-791L846,-804L853,-815L862,-825L872,-834L884,-841L896,-845ZM-923,-396L-910,-395L-897,-391L-885,-386L-874,-378L-864,-369L-856,-358L-851,-346L-847,-333L-846,-319L-846,-160L-847,-146L-851,-133L-856,-121L-864,-110L-874,-101L-885,-93L-897,-87L-910,-84L-923,-83L-936,-84L-949,-87L-961,-93L-972,-101L-982,-110L-990,-121L-995,-133L-999,-146L-1000,-160L-1000,-319L-999,-332L-995,-345L-990,-357L-982,-368L-972,-378L-961,-386L-949,-391L-936,-395L-923,-396ZM923,-396L936,-395L949,-391L961,-386L972,-378L982,-369L990,-358L995,-346L999,-333L1000,-319L1000,-160L999,-146L995,-133L990,-121L982,-110L972,-101L961,-93L949,-87L936,-84L923,-83L910,-84L897,-87L885,-93L874,-101L864,-110L856,-121L851,-133L847,-146L846,-160L846,-319L847,-332L851,-345L856,-357L864,-368L874,-378L885,-386L897,-391L910,-395L923,-396ZM-923,83L-910,84L-897,87L-885,93L-874,101L-864,110L-856,121L-851,133L-847,146L-846,160L-846,319L-847,332L-851,345L-856,358L-864,369L-874,378L-885,386L-897,391L-910,395L-923,396L-936,395L-949,391L-961,386L-972,378L-982,369L-990,358L-995,345L-999,332L-1000,319L-1000,160L-999,146L-995,133L-990,121L-982,110L-972,101L-961,93L-949,87L-936,84L-923,83ZM923,83L936,84L949,87L961,93L972,101L982,110L990,121L995,133L999,146L1000,160L1000,319L999,332L995,345L990,358L982,369L972,378L961,386L949,391L936,395L923,396L910,395L897,391L885,386L874,378L864,369L856,358L851,345L847,332L846,319L846,160L847,146L851,133L856,121L864,110L874,101L885,93L897,87L910,84L923,83ZM923,561L936,562L949,566L961,572L972,579L982,589L990,600L995,612L999,625L1000,638L1000,718C1000,743,997,767,990,791L986,803L980,814L972,824L963,832L952,839L940,844L928,847L915,848L902,847L890,843L879,838L868,831L859,822L851,812L845,801L841,789L839,776L839,764L842,751C845,741,846,730,846,718L846,638L847,625L851,612L856,600L864,589L874,579L885,571L897,566L910,562L923,561ZM-923,561L-910,562L-897,566L-885,572L-874,579L-864,589L-856,600L-851,612L-847,625L-846,638L-846,718C-846,729,-845,741,-842,751L-840,764L-840,777L-842,790L-847,803L-854,814L-862,824L-873,833L-884,839L-897,844L-910,846L-923,846L-936,844L-948,840L-960,833L-970,825L-979,815L-986,803L-990,791L-998,755L-1000,718L-1000,638L-999,625L-995,612L-990,600L-982,589L-972,579L-961,571L-949,566L-936,562L-923,561ZM-845,896L-841,884L-834,872L-825,862L-815,853L-804,846L-791,842L-778,840L-764,840L-751,842L-735,845L-718,846L-638,846L-625,847L-612,851L-600,856L-589,864L-579,874L-572,885L-566,897L-562,910L-561,923L-562,936L-566,949L-572,962L-579,973L-589,982L-600,990L-612,995L-625,999L-638,1000L-718,1000C-743,1000,-768,997,-791,990L-804,986L-815,979L-825,971L-834,960L-841,949L-845,936L-848,923L-848,910L-845,896ZM845,896L848,910L848,923L845,936L841,949L834,960L825,971L815,979L804,986L791,990C768,997,743,1000,718,1000L638,1000L625,999L612,995L600,990L589,982L579,973L572,962L566,949L562,936L561,923L562,910L566,897L572,885L579,874L589,864L600,856L612,851L625,847L638,846L718,846C730,846,741,845,751,842L764,840L778,840L791,842L804,846L815,853L825,862L834,872L841,884L845,896ZM-396,923L-395,910L-391,897L-386,885L-378,874L-368,864L-357,856L-345,851L-332,847L-319,846L-159,846L-146,847L-133,851L-121,856L-110,864L-101,874L-93,885L-87,897L-84,910L-83,923L-84,936L-87,949L-93,961L-101,972L-110,982L-121,990L-133,995L-146,999L-159,1000L-319,1000L-332,999L-345,995L-357,990L-368,982L-378,972L-386,961L-391,949L-395,936L-396,923ZM83,923L84,910L87,897L93,885L101,874L110,864L121,856L133,851L146,847L160,846L319,846L333,847L345,851L358,856L369,864L378,874L386,885L391,897L395,910L396,923L395,936L391,949L386,961L378,972L369,982L358,990L345,995L333,999L319,1000L160,1000L146,999L133,995L121,990L110,982L101,972L93,961L87,949L84,936L83,923ZM-410,-385L-424,-383L-437,-380L-449,-374L-460,-367L-469,-357L-477,-346L-483,-334L-486,-321L-487,-308L-486,-294L-483,-281L-477,-269L-469,-258L-460,-249L-449,-241L-437,-235L-424,-232L-410,-231L-77,-231L-77,410L-76,424L-72,436L-67,449L-59,460L-49,469L-38,477L-26,482L-13,486L0,487L13,486L26,482L38,477L49,469L59,460L67,449L72,436L76,424L77,410L77,-231L410,-231L424,-232L437,-235L449,-241L460,-249L469,-258L477,-269L483,-281L486,-294L487,-308L486,-321L483,-334L477,-346L469,-357L460,-367L449,-374L437,-380L424,-383L410,-385L-410,-385Z",
  "M400,600L-400,600C-733,600,-1000,333,-1000,0C-1000,-333,-733,-600,-400,-600L400,-600C733,-600,1000,-333,1000,0C1000,327,733,600,400,600ZM-400,-467C-660,-467,-867,-260,-867,0C-867,260,-660,467,-400,467L400,467C660,467,867,260,867,0C867,-260,660,-467,400,-467L-400,-467ZM-380,0ZM-713,0L-708,58L-693,114L-669,167L-635,214L-594,255L-547,289L-494,313L-438,328L-380,333L-322,328L-266,313L-213,289L-166,255L-125,214L-91,167L-67,114L-52,58L-47,0L-52,-58L-67,-114L-91,-167L-125,-214L-166,-255L-213,-289L-266,-313L-322,-328L-380,-333L-438,-328L-494,-313L-547,-289L-594,-255L-635,-214L-669,-167L-693,-114L-708,-58L-713,0Z",
  "M857,-643L-857,-643C-936,-643,-1000,-579,-1000,-500L-1000,500C-1000,579,-936,643,-857,643L857,643C936,643,1000,579,1000,500L1000,-500C1000,-579,936,-643,857,-643ZM857,429C857,471,829,500,786,500L-786,500C-829,500,-857,471,-857,429L-857,-429C-857,-471,-829,-500,-786,-500L786,-500C829,-500,857,-471,857,-429L857,429ZM-643,-357C-686,-357,-714,-329,-714,-286L-714,286C-714,321,-686,357,-643,357C-600,357,-571,329,-571,286L-571,-286C-571,-321,-600,-357,-643,-357Z",
  "M857,-786L-857,-786C-936,-786,-1000,-721,-1000,-643L-1000,643C-1000,721,-936,786,-857,786L857,786C936,786,1000,721,1000,643L1000,-643C1000,-721,936,-786,857,-786ZM857,571C857,607,829,643,786,643L-786,643C-829,643,-857,614,-857,571L-857,-571C-857,-607,-829,-643,-786,-643L786,-643C829,-643,857,-614,857,-571L857,571ZM-643,-500C-686,-500,-714,-471,-714,-429L-714,143C-714,179,-686,214,-643,214C-600,214,-571,186,-571,143L-571,-429C-571,-464,-600,-500,-643,-500ZM714,571C757,571,786,543,786,500L786,214L429,571L714,571Z",
  "M857,-714L882,-712L906,-706L929,-695L949,-681L967,-663L981,-643L991,-620L998,-596L1000,-571L1000,571L998,596L991,620L981,643L967,663L949,681L929,695L906,706L882,712L857,714L-857,714L-882,712L-906,706L-929,695L-949,681L-967,663L-981,643L-991,620L-998,596L-1000,571L-1000,-571L-998,-596L-991,-620L-981,-643L-967,-663L-949,-681L-929,-695L-906,-706L-882,-712L-857,-714L857,-714ZM786,-571L-786,-571L-797,-570L-808,-568L-819,-563L-829,-557L-837,-549L-845,-540L-850,-530L-854,-520L-857,-508L-857,-500L-857,500L-856,511L-853,523L-849,533L-843,543L-835,552L-826,559L-816,565L-805,569L-794,571L-786,571L786,571L797,570L808,568L819,563L829,557L837,549L845,540L850,530L854,520L857,508L857,500L857,-500L856,-512L853,-524L848,-536L840,-546L832,-555L821,-562L810,-567L798,-570L786,-571ZM531,-393L564,-390L596,-382L627,-370L656,-352L681,-330L702,-305L720,-277L732,-246L740,-213L743,-180C743,-129,724,-81,694,-45L721,-20L744,8L763,40L776,74L785,110L787,146C787,282,673,393,532,393C396,393,285,291,276,163L419,163C427,214,474,253,532,253C595,253,646,205,646,146C646,87,595,39,532,39C520,39,510,41,499,43L499,-99C508,-100,517,-101,526,-101L526,-101L531,-101C573,-101,607,-137,607,-180C607,-224,573,-259,531,-259C499,-259,471,-238,460,-209L321,-209L328,-242L340,-273L358,-302L379,-329L405,-351L433,-369L464,-382L497,-390L531,-393ZM0,-393C118,-393,214,-298,214,-180C214,-139,202,-100,181,-67L181,-67L-43,250L218,250L218,393L-215,393L-215,250L59,-137L57,-137L63,-147L68,-157L71,-169L72,-180C72,-220,40,-252,0,-252L-12,-251L-24,-248L-36,-243L-46,-236L-55,-227L-62,-217L-67,-206L-71,-194L-72,-182L-71,-170L-78,-172L-214,-172L-214,-176L-214,-180C-214,-298,-119,-393,0,-393ZM-446,-392L-446,392L-589,392L-589,-249L-732,-178L-732,-321L-589,-392L-446,-392Z",
  "M-951,-951L415,-951L415,-756L-951,-756L-951,-951ZM-561,-171L1000,-171L1000,24L-561,24L-561,-171ZM-561,707L1000,707L1000,902L-561,902L-561,707ZM805,-756L1000,-951L610,-951L805,-756ZM-1000,-220L-707,-220L-707,73L-1000,73L-1000,-220ZM-902,-122L-902,-24L-805,-24L-805,-122L-902,-122ZM-1000,659L-707,659L-707,951L-1000,951L-1000,659ZM-902,756L-902,854L-805,854L-805,756L-902,756Z",
  "M-300,-1000L942,-1000C981,-1000,1000,-978,1000,-933L1000,-567C1000,-522,981,-500,942,-500L-300,-500C-338,-500,-358,-522,-358,-567L-358,-933C-358,-978,-338,-1000,-300,-1000ZM58,-250L942,-250C981,-250,1000,-228,1000,-183L1000,183C1000,228,981,250,942,250L58,250C19,250,0,228,0,183L0,-183C0,-228,19,-250,58,-250ZM58,500L942,500C981,500,1000,522,1000,567L1000,933C1000,978,981,1000,942,1000L58,1000C19,1000,0,978,0,933L0,567C0,522,19,500,58,500ZM-214,67C-183,67,-158,36,-158,0C-158,-38,-183,-67,-214,-67L-730,-67L-730,-500L-628,-500C-597,-500,-572,-531,-572,-567L-572,-933C-572,-970,-597,-1000,-628,-1000L-942,-1000C-973,-1000,-1000,-969,-1000,-933L-1000,-567C-1000,-530,-975,-500,-942,-500L-844,-500L-844,750C-844,788,-819,817,-787,817L-216,817C-184,817,-159,786,-159,750C-159,713,-184,683,-216,683L-731,683L-731,67L-216,67Z",
  "M929,-786L-929,-786C-968,-786,-1000,-754,-1000,-714L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-714C1000,-754,968,-786,929,-786ZM839,-625L839,-321L-839,-321L-839,-625L839,-625ZM-223,179L-223,-179L839,-179L839,625L-223,625L-223,179ZM-839,-179L-366,-179L-366,179L-839,179L-839,-179ZM-839,321L-366,321L-366,625L-839,625L-839,321ZM625,17L129,513C101,541,56,541,28,513C0,485,0,440,28,412L524,-84C552,-112,597,-112,625,-84C653,-56,653,-11,625,17Z",
  "M-1000,-1000L-1000,1000L1000,1000L1000,-1000L-1000,-1000ZM-875,-500L-375,-500L-375,-125L-875,-125L-875,-500ZM250,-125L-250,-125L-250,-500L250,-500L250,-125ZM250,0L250,375L-250,375L-250,0L250,0ZM-875,0L-375,0L-375,375L-875,375L-875,0ZM-875,875L-875,500L-375,500L-375,875L-875,875ZM-250,875L-250,500L250,500L250,875L-250,875ZM875,875L375,875L375,500L875,500L875,875ZM875,375L375,375L375,0L875,0L875,375ZM875,-125L375,-125L375,-500L875,-500L875,-125ZM-875,-625L-875,-875L875,-875L875,-625L-875,-625Z",
  "M1000,734L998,761L991,787L979,812L963,835L944,854L921,870L896,882L870,889L843,891L-843,891L-870,889L-896,882L-921,870L-944,854L-963,835L-979,812L-991,787L-998,761L-1000,734L-1000,-733L-998,-758L-992,-782L-983,-805L-970,-826L-954,-845L-935,-861L-914,-874L-891,-883L-867,-889L-843,-891L-169,-891L-141,-889L-115,-882L-90,-870L-68,-854L-48,-835L-32,-812L-21,-787L-14,-761L-11,-734L-11,-722L843,-722L869,-720L894,-714L919,-703L941,-688L960,-670L976,-649L988,-626L996,-601L1000,-575L1000,734ZM910,-352L-910,-352L-910,734L-909,745L-906,755L-902,765L-896,775L-889,783L-880,790L-871,795L-860,798L-849,800L843,800L854,799L865,796L876,791L886,785L894,777L900,767L905,756L908,745L909,734L909,-352ZM-169,-801L-843,-801L-853,-800L-863,-798L-873,-794L-882,-788L-890,-781L-897,-774L-902,-765L-906,-755L-909,-745L-909,-734L-909,-442L-101,-442L-101,-734L-102,-745L-105,-755L-109,-765L-115,-774L-122,-783L-131,-789L-140,-795L-151,-798L-161,-800ZM405,-632L-11,-632L-11,-442L405,-442L405,-632ZM843,-632L495,-632L495,-442L910,-442L910,-565L909,-576L906,-587L902,-597L896,-606L889,-614L880,-621L871,-626L860,-630L849,-632Z",
  "M341,-638C344,-637,347,-636,350,-635C395,-623,416,-571,393,-531C350,-457,307,-382,264,-308C90,-6,-84,295,-258,597C-265,609,-273,619,-285,627C-293,631,-302,634,-310,636C-312,637,-313,637,-314,638C-320,638,-326,638,-332,638C-334,637,-337,636,-339,636C-373,627,-396,597,-395,562C-394,551,-391,540,-386,530C-257,307,-128,85,1,-138C89,-292,178,-445,266,-599C275,-613,286,-625,302,-632C307,-634,313,-635,318,-637C319,-637,320,-637,321,-638C328,-638,334,-638,341,-638ZM-1000,-2C-999,-4,-998,-5,-998,-7C-994,-21,-988,-33,-978,-43C-853,-168,-729,-292,-604,-416C-584,-437,-559,-443,-531,-434C-504,-425,-487,-405,-483,-376C-479,-353,-486,-332,-503,-315C-589,-228,-676,-142,-762,-56C-786,-32,-810,-8,-834,17C-835,18,-837,19,-838,20C-836,22,-835,24,-833,25C-723,135,-613,245,-503,355C-464,395,-481,461,-535,476C-561,483,-585,477,-604,457C-628,434,-651,411,-674,388C-774,287,-875,187,-975,86C-987,75,-995,63,-998,47C-998,45,-999,44,-1000,42C-1000,28,-1000,13,-1000,-2ZM1000,46C999,49,999,51,998,54C994,65,988,75,980,83C938,125,896,168,854,210C840,224,826,238,812,252C762,302,712,352,662,402C644,421,626,439,607,458C586,478,561,483,534,474C506,465,490,445,486,416C482,392,490,372,507,355C561,301,615,246,670,191C716,145,763,98,810,51C820,41,830,31,840,21C838,19,837,17,836,16C811,-8,787,-33,763,-57C700,-120,637,-183,574,-246C551,-269,528,-292,505,-316C486,-336,480,-360,488,-387C496,-413,515,-430,542,-436C567,-441,590,-434,608,-416C658,-366,708,-315,758,-265C814,-209,870,-153,926,-97C944,-79,962,-61,981,-42C990,-32,997,-21,999,-7C999,-7,1000,-6,1000,-6C1000,12,1000,29,1000,46Z",
  "M1000,-750L1000,-875L-1000,-875L-1000,-750L1000,-750ZM750,375L750,-625L125,-625L125,375L750,375ZM-125,-500L-125,750L-625,750L-625,-500L-125,-500ZM0,-625L-750,-625L-750,875L0,875L0,-625L0,-625Z",
  "M750,-1000L875,-1000L875,1000L750,1000L750,-1000ZM-375,-750L625,-750L625,-125L-375,-125L-375,-750ZM500,125L500,625L-750,625L-750,125L500,125ZM625,0L-875,0L-875,750L625,750L625,0L625,0Z",
  "M-875,-1000L-750,-1000L-750,1000L-875,1000L-875,-1000ZM-625,-750L375,-750L375,-125L-625,-125L-625,-750ZM750,125L750,625L-500,625L-500,125L750,125ZM875,0L-625,0L-625,750L875,750L875,0L875,0Z",
  "M-202,-435L-202,-844L-1000,-120L-202,604L-202,167C20,167,704,167,1000,844L1000,768C1000,467,704,-499,-202,-435Z",
  "M469,104L466,96L461,88L455,82L449,76L441,71L433,68L424,66L230,34L454,-169C469,-184,475,-205,469,-225L466,-233L461,-241L456,-248L449,-254L441,-258L433,-262L424,-264L229,-296L454,-499C469,-513,475,-535,469,-555L466,-563L461,-571L455,-577L449,-583L441,-588L433,-591L424,-593L-304,-713L-313,-714L-323,-713L-332,-711L-340,-708L-348,-703L-978,-235L-985,-229L-990,-222L-995,-215L-998,-206L-1000,-198L-1000,-189L-999,-180C-995,-160,-978,-143,-957,-138L-738,-83L-978,95L-985,101L-990,107L-995,115L-998,123L-1000,132L-1000,141L-999,149C-995,170,-979,186,-957,192L-739,247L-978,425L-985,430L-990,437L-995,445L-998,453L-1000,461L-1000,470L-999,479L-996,487L-992,495L-987,503L-981,509L-974,514L-966,518L-957,521L-194,712L-184,714L-175,714L-166,713L-157,710L-148,705L-141,699L454,160C469,146,475,124,469,104ZM-599,-48L-194,53L-184,55L-175,55L-166,54L-157,51L-148,46L-141,40L126,-201L293,-174L-196,269L-817,113L-599,-48ZM-196,599L-817,443L-599,281L-194,383L-184,385L-175,385L-166,383L-157,380L-148,376L-141,370L126,128L293,156L-196,599ZM720,-308L440,54L626,54L626,81C626,271,561,443,458,587C664,488,804,289,813,54L1000,54L720,-308Z",
  "M405,68L213,35L433,-175L439,-182L444,-189L448,-197L450,-206L451,-215L451,-224L449,-233L445,-241L441,-249L435,-256L429,-262L421,-266L413,-270L404,-272L212,-305L433,-515L439,-521L444,-529L448,-537L450,-546L451,-555L451,-564L449,-572L445,-581L441,-589L435,-595L429,-601L421,-606L413,-610L404,-612L-314,-736L-323,-737L-332,-736L-341,-734L-350,-730L-357,-725L-978,-242L-985,-236L-991,-228L-996,-219L-998,-210L-1000,-201L-1000,-191L-998,-181L-994,-172L-989,-164L-983,-157L-976,-151L-967,-146L-958,-142L-742,-86L-978,98L-985,104L-991,112L-996,121L-999,130L-1000,139L-1000,149L-998,159L-994,168L-989,176L-983,183L-976,189L-967,194L-958,198L-742,254L-978,438L-985,445L-991,452L-996,461L-999,470L-1000,480L-1000,489L-998,499L-994,508L-989,516L-983,523L-976,530L-967,534L-958,538L-371,692L-205,735L-196,737L-186,737L-177,735L-168,732L-160,728L-153,722L434,165L440,158L444,151L448,143L450,134L451,125L451,116L449,107L446,99L441,91L436,84L429,78L421,74L413,70L405,68ZM-309,-620L275,-520L-207,-63L-819,-223L-309,-620ZM-605,-50L-205,55L-196,57L-187,57L-177,55L-168,52L-160,47L-153,42L110,-208L275,-180L-207,278L-819,117L-605,-50ZM816,233L805,135L780,41L741,-48L688,-131L624,-204L549,-267L466,-318C567,-169,632,9,632,205L632,233L447,233L724,606L1000,233L816,233Z",
  "M-956,-281L-31,142C-21,147,-11,149,0,149C11,149,22,147,32,142L956,-281C983,-293,1000,-320,1000,-350C1000,-380,983,-406,955,-418L31,-834L19,-838L6,-841L-6,-841L-19,-838L-31,-834L-955,-418C-983,-406,-1000,-380,-1000,-350C-1000,-320,-983,-293,-956,-281ZM955,273L710,163C685,151,656,163,645,187C634,212,645,240,670,252L871,342L0,741L-871,342L-670,251C-645,240,-634,211,-645,187C-656,162,-685,151,-710,162L-955,273C-983,285,-1000,312,-1000,342C-1000,372,-983,398,-956,411L-31,834C-21,838,-11,841,0,841C11,841,22,838,32,834L956,411C983,398,1000,372,1000,342C1000,312,983,285,955,273Z",
  "M1000,750L1000,875L-1000,875L-1000,750L1000,750ZM875,-375L875,625L250,625L250,-375L875,-375ZM-125,-750L-125,500L-625,500L-625,-750L-125,-750ZM0,-875L-750,-875L-750,625L0,625L0,-875Z",
  "M-956,-281L-31,142C-21,147,-11,149,0,149C11,149,22,147,32,142L956,-281C983,-293,1000,-320,1000,-350C1000,-380,983,-406,955,-418L31,-834L19,-838L6,-841L-6,-841L-19,-838L-31,-834L-955,-418C-983,-406,-1000,-380,-1000,-350C-1000,-320,-983,-293,-956,-281ZM0,-741L871,-349L0,49L-871,-349L0,-741ZM955,273L506,71C480,59,449,59,422,71L0,264L-422,71C-448,59,-479,59,-506,71L-955,273C-983,285,-1000,312,-1000,342C-1000,372,-983,398,-956,411L-31,834C-21,838,-11,841,0,841C11,841,22,838,32,834L956,411C983,398,1000,372,1000,342C1000,312,983,285,955,273Z",
  "M714,-429L-143,-429C-300,-429,-429,-300,-429,-143L-429,714C-429,871,-300,1000,-143,1000L714,1000C871,1000,1000,871,1000,714L1000,-143C1000,-300,871,-429,714,-429ZM857,571C857,729,729,857,571,857L0,857C-157,857,-286,729,-286,571L-286,0C-286,-157,-157,-286,0,-286L571,-286C729,-286,857,-157,857,0L857,571ZM43,-900C57,-900,57,-929,43,-943L14,-943L-71,-843C-86,-814,-86,-800,-71,-771L14,-686L43,-686C43,-686,57,-714,43,-729L-14,-771L586,-771L529,-686C514,-686,514,-657,529,-643L557,-643L643,-729C657,-757,657,-771,643,-800L571,-929L543,-929C529,-929,529,-900,543,-886L586,-814L-14,-814L43,-900ZM-357,-571C-400,-571,-429,-600,-429,-643L-429,-929C-429,-971,-400,-1000,-357,-1000C-314,-1000,-286,-971,-286,-929L-286,-643C-286,-600,-314,-571,-357,-571ZM929,-571C886,-571,857,-614,857,-643L857,-929C857,-971,886,-1000,929,-1000C971,-1000,1000,-971,1000,-929L1000,-643C1000,-614,971,-571,929,-571ZM-900,529C-900,514,-929,514,-943,529L-943,557L-829,643C-800,657,-786,657,-757,643L-671,557L-671,529C-671,529,-700,514,-714,529L-757,571L-757,-14L-671,43C-671,57,-643,57,-629,43L-629,14L-729,-71C-757,-86,-771,-86,-800,-71L-929,0L-929,29C-929,43,-900,43,-886,29L-814,-14L-814,586L-900,529ZM-571,929C-571,971,-600,1000,-643,1000L-929,1000C-971,1000,-1000,971,-1000,929C-1000,900,-971,857,-929,857L-643,857C-600,857,-571,900,-571,929ZM-571,-357C-571,-314,-600,-286,-643,-286L-929,-286C-971,-286,-1000,-314,-1000,-357C-1000,-400,-971,-429,-929,-429L-643,-429C-600,-429,-571,-400,-571,-357Z",
  "M815,-120L844,-102C904,-65,921,13,884,73C874,89,860,103,844,113L68,601C27,626,-26,626,-67,601L-844,112C-904,75,-921,-4,-884,-63C-874,-79,-860,-93,-844,-103L-815,-121L-67,349C-26,375,27,375,68,349L815,-120L815,-120ZM815,253L844,271C904,309,921,387,884,447C874,463,860,476,844,487L68,974C27,1000,-26,1000,-67,974L-844,486C-904,448,-921,370,-884,310C-874,294,-860,281,-844,270L-815,252L-67,722C-26,748,27,748,68,722L815,253L815,253ZM67,-974L844,-485C903,-448,921,-370,884,-310C874,-294,860,-280,844,-270L68,217C27,243,-26,243,-67,217L-844,-271C-904,-309,-921,-387,-884,-447C-874,-463,-860,-476,-844,-487L-68,-974C-26,-1000,26,-1000,67,-974L67,-974Z",
  "M-1000,38L-615,38L-615,885L-1000,885ZM-462,-885L-77,-885L-77,885L-462,885ZM77,-269L462,-269L462,885L77,885ZM615,269L1000,269L1000,885L615,885Z",
  "M0,1000C-135,1000,-266,973,-389,921C-508,871,-615,799,-707,707C-799,615,-871,508,-921,389C-973,266,-1000,135,-1000,0C-1000,-135,-973,-266,-921,-389C-871,-508,-799,-615,-707,-707C-615,-799,-508,-871,-389,-921C-266,-973,-135,-1000,0,-1000C135,-1000,266,-973,389,-921C508,-871,615,-799,707,-707C799,-615,871,-508,921,-389C973,-266,1000,-135,1000,0C1000,135,973,266,921,389C871,508,799,615,707,707C615,799,508,871,389,921C266,973,135,1000,0,1000ZM0,-803C-443,-803,-803,-443,-803,0C-803,443,-443,803,0,803C443,803,803,443,803,0C803,-443,443,-803,0,-803ZM-220,-442L436,-16L-220,409Z",
  "M836,-910L-450,-910C-499,-910,-538,-871,-538,-823L-538,-562C-538,-514,-499,-475,-450,-475L836,-475C884,-475,923,-514,923,-562L923,-823C924,-871,884,-910,836,-910ZM836,474L-450,474C-499,474,-538,514,-538,562L-538,822C-538,871,-499,910,-450,910L836,910C884,910,923,871,923,822L923,562C924,514,884,474,836,474ZM-450,218L366,218C414,218,454,179,454,131L454,-130C454,-178,414,-217,366,-217L-450,-217C-499,-217,-538,-178,-538,-130L-538,131C-538,179,-499,218,-450,218ZM-847,-1000C-889,-1000,-924,-966,-924,-923L-924,923C-924,965,-890,1000,-847,1000C-804,1000,-770,966,-770,923L-770,-923C-770,-965,-804,-1000,-847,-1000Z",
  "M-714,-1000ZM-679,-1000L-607,-1000C-583,-1000,-571,-988,-571,-964L-571,201C-571,225,-583,237,-607,237L-679,237C-702,237,-714,225,-714,201L-714,-964C-714,-988,-702,-1000,-679,-1000ZM-714,516ZM-679,516L-607,516C-583,516,-571,528,-571,552L-571,964C-571,988,-583,1000,-607,1000L-679,1000C-702,1000,-714,988,-714,964L-714,552C-714,528,-702,516,-679,516ZM571,-1000ZM607,-1000L679,-1000C702,-1000,714,-988,714,-964L714,193C714,216,702,228,679,228L607,228C583,228,571,216,571,193L571,-964C571,-988,583,-1000,607,-1000ZM571,522ZM607,522L679,522C702,522,714,534,714,558L714,964C714,988,702,1000,679,1000L607,1000C583,1000,571,988,571,964L571,558C571,534,583,522,607,522ZM-71,-236ZM-36,-236L36,-236C60,-236,71,-225,71,-201L71,964C71,988,60,1000,36,1000L-36,1000C-60,1000,-71,988,-71,964L-71,-201C-71,-225,-60,-236,-36,-236ZM-643,286L-637,286L-619,288L-602,293L-586,300L-572,310L-559,323L-548,337L-540,353L-535,369L-533,387L-533,405L-537,422L-543,439L-552,454L-563,468L-576,479L-591,489L-608,495L-625,499L-643,500L-649,500L-667,498L-685,493L-702,484L-717,473L-730,460L-740,444L-747,427L-752,409L-753,390L-751,371L-745,354L-737,337L-726,322L-712,309L-697,299L-680,291L-662,287L-643,286ZM-643,143L-686,146L-729,156L-769,173L-805,197L-837,227L-863,262L-882,301L-894,343L-899,386L-897,430L-886,472L-869,512L-845,549L-815,580L-780,606L-741,626L-699,638L-656,643L-643,643L-599,640L-557,630L-517,613L-481,589L-449,558L-423,523L-404,484L-391,443L-386,399L-389,356L-399,313L-417,273L-441,237L-471,205L-506,180L-545,160L-587,148L-630,143ZM0,-509L6,-509L25,-507L43,-502L59,-493L74,-482L87,-469L98,-453L105,-436L109,-418L111,-399L108,-381L103,-363L95,-346L84,-331L70,-318L55,-308L38,-300L19,-296L1,-295L-5,-295L-24,-297L-42,-302L-59,-310L-74,-321L-86,-335L-97,-351L-104,-368L-109,-386L-110,-404L-108,-423L-102,-441L-94,-458L-83,-473L-69,-486L-54,-496L-37,-503L-19,-508L0,-509ZM0,-652L-44,-649L-86,-639L-126,-622L-162,-597L-194,-567L-220,-532L-239,-493L-252,-452L-256,-408L-254,-365L-244,-322L-226,-282L-202,-246L-172,-214L-137,-188L-98,-169L-56,-157L-13,-152L0,-152L44,-154L86,-165L126,-182L162,-206L194,-236L220,-271L239,-310L252,-352L256,-395L254,-439L244,-481L226,-521L202,-558L172,-589L137,-615L98,-635L56,-647L13,-652ZM643,286L649,286L667,288L685,293L702,302L717,313L730,326L740,342L748,359L752,377L753,396L751,414L746,432L737,449L726,464L712,477L697,487L680,495L662,499L643,500L637,500L618,498L600,493L584,484L569,473L556,459L546,444L538,427L534,408L533,390L535,371L540,353L549,337L560,322L573,309L589,299L606,291L624,287L643,286ZM643,143L599,146L557,156L517,173L481,197L449,227L423,262L404,301L391,343L386,386L389,430L399,472L417,512L441,549L471,580L506,606L545,626L587,638L630,643L643,643L686,640L729,630L769,613L805,589L837,558L863,523L882,484L894,443L899,399L897,356L886,313L869,273L845,237L815,205L780,180L741,160L699,148L656,143ZM-71,-1000ZM-36,-1000L36,-1000C60,-1000,71,-988,71,-964L71,-596C71,-572,60,-560,36,-560L-36,-560C-60,-560,-71,-572,-71,-596L-71,-964C-71,-988,-60,-1000,-36,-1000Z",
  "M-1,-1000L-1000,-300L0,400L1000,-300ZM-540,222L-651,300L0,756L651,300L539,222L714,100L1000,300L0,1000L-1000,300L-714,100L-540,222Z",
  "M-1000,-917L-267,-917L-267,917L-1000,917ZM-67,-917L1000,-917L1000,-117L-67,-117ZM-67,83L-67,883L1000,883L1000,83L-67,83ZM937,820L-3,820L-3,147L937,147L937,820Z",
  "M1000,-813L999,-802L996,-791L992,-781L985,-772L978,-765L969,-758L959,-754L948,-751L937,-750L-938,-750L-948,-751L-959,-754L-969,-758L-978,-765L-985,-772L-992,-781L-996,-791L-999,-802L-1000,-813L-999,-823L-996,-834L-992,-844L-985,-853L-978,-860L-969,-867L-959,-871L-948,-874L-938,-875L937,-875L948,-874L959,-871L969,-867L978,-860L985,-853L992,-844L996,-834L999,-823L1000,-813ZM1000,813L999,823L996,834L992,844L985,853L978,860L969,867L959,871L948,874L937,875L-938,875L-948,874L-959,871L-969,867L-978,860L-985,853L-992,844L-996,834L-999,823L-1000,813L-999,802L-996,791L-992,781L-985,772L-978,765L-969,758L-959,754L-948,751L-938,750L937,750L948,751L959,754L969,758L978,765L985,772L992,781L996,791L999,802L1000,813ZM-563,-250L562,-250L573,-249L584,-246L594,-242L603,-235L610,-228L617,-219L621,-209L624,-198L625,-188L625,188L624,198L621,209L617,219L610,228L603,235L594,242L584,246L573,249L562,250L-563,250L-573,249L-584,246L-594,242L-603,235L-610,228L-617,219L-621,209L-624,198L-625,188L-625,-188L-624,-198L-621,-209L-617,-219L-610,-228L-603,-235L-594,-242L-584,-246L-573,-249L-563,-250Z",
  "M-813,-1000L-803,-999L-793,-997L-784,-993L-776,-988L-768,-982L-762,-974L-757,-966L-753,-957L-751,-947L-750,-938L-750,937L-751,948L-754,959L-758,969L-765,978L-772,985L-781,992L-791,996L-802,999L-812,1000L-823,999L-834,996L-844,992L-853,985L-860,978L-867,969L-871,959L-874,948L-875,937L-875,-938L-874,-947L-872,-957L-868,-966L-863,-974L-857,-982L-849,-988L-841,-993L-832,-997L-822,-999L-813,-1000ZM813,-1000L822,-999L832,-997L841,-993L849,-988L857,-982L863,-974L868,-966L872,-957L874,-947L875,-938L875,937L874,948L871,959L867,969L860,978L853,985L844,992L834,996L823,999L813,1000L802,999L791,996L781,992L772,985L765,978L758,969L754,959L751,948L750,937L750,-938L751,-947L753,-957L757,-966L762,-974L768,-982L776,-988L784,-993L793,-997L803,-999L813,-1000ZM-250,562L-250,-562L-249,-572L-247,-582L-243,-591L-238,-599L-232,-607L-224,-613L-216,-618L-207,-622L-197,-624L-187,-625L187,-625L197,-624L207,-622L216,-618L224,-613L232,-607L238,-599L243,-591L247,-582L249,-572L250,-562L250,562L249,572L247,582L243,591L238,599L232,607L224,613L216,618L207,622L197,624L187,625L-187,625L-197,624L-207,622L-216,618L-224,613L-232,607L-238,599L-243,591L-247,582L-249,572L-250,562Z",
  "M-825,675L837,675L837,837L-825,837ZM-950,500L-887,500C-850,500,-837,513,-837,550L-837,950C-837,988,-850,1000,-887,1000L-950,1000C-987,1000,-1000,987,-1000,950L-1000,550C-1000,525,-975,500,-950,500ZM-950,500ZM888,500L950,500C988,500,1000,513,1000,550L1000,950C1000,988,987,1000,950,1000L888,1000C850,1000,838,987,837,950L837,550C837,525,850,500,888,500ZM888,500ZM-62,275L813,-600C837,-625,837,-650,813,-675L513,-975C488,-1000,463,-1000,438,-975L-438,-88L-450,-75L-512,275C-512,288,-512,313,-500,325C-487,338,-475,338,-450,338L-88,288C-75,288,-63,288,-62,275ZM-62,275Z",
  "M-34,-1000L34,-1000L34,1000L-34,1000ZM-469,-714L469,-714L469,-203L-469,-203ZM815,592L-815,592L-815,20L815,20L815,592ZM-748,525L748,525L748,87L-748,87L-748,525Z",
  "M-1000,-34L1000,-34L1000,34L-1000,34ZM114,469L114,-469L624,-469L624,469ZM-49,-815L-49,815L-621,815L-621,-815L-49,-815ZM-117,748L-117,-748L-554,-748L-554,748L-117,748Z",
  "M745,517L745,651L411,651L411,517ZM839,490L933,584L651,867L556,772ZM933,584L839,678L556,395L650,301ZM-745,650L-745,517L-411,517L-411,650ZM-839,678L-934,584L-651,301L-557,396ZM-934,583L-839,489L-556,772L-651,866ZM-1000,-867L1000,-867L1000,-333L-1000,-333ZM-267,317L267,317L267,851L-267,851ZM867,533L1000,533L1000,733L867,733ZM867,267L1000,267L1000,467L867,467ZM867,0L1000,0L1000,200L867,200ZM867,-267L1000,-267L1000,-67L867,-67ZM-1000,533L-867,533L-867,733L-1000,733ZM-1000,267L-867,267L-867,467L-1000,467ZM-1000,0L-867,0L-867,200L-1000,200ZM-1000,-267L-867,-267L-867,-67L-1000,-67Z",
  "M517,-745L651,-745L651,-411L517,-411ZM490,-839L584,-934L867,-651L773,-557ZM584,-933L678,-839L395,-556L301,-650ZM651,745L517,745L517,411L651,411ZM678,840L584,934L301,651L396,557ZM584,933L489,839L772,556L866,650ZM-867,1000L-867,-1000L-333,-1000L-333,1000ZM317,267L317,-267L851,-267L851,267ZM533,-867L533,-1000L733,-1000L733,-867ZM267,-867L267,-1000L467,-1000L467,-867ZM0,-867L0,-1000L200,-1000L200,-867ZM-267,-867L-267,-1000L-67,-1000L-67,-867ZM533,1000L533,867L733,867L733,1000ZM267,1000L267,867L467,867L467,1000ZM0,1000L0,867L200,867L200,1000ZM-267,1000L-267,867L-67,867L-67,1000Z",
  "M714,-1000L0,-167L0,1000L-286,714L-286,-167L-1000,-1000L714,-1000ZM1000,571L1000,857L286,857L286,571L1000,571ZM1000,0L1000,286L286,286L286,0L1000,0Z",
  "M804,623L-804,623L-838,619L-871,611L-902,596L-930,576L-954,552L-974,524L-988,493L-997,460L-1000,426L-1000,-695C-1000,-803,-912,-891,-804,-891L804,-891C912,-891,1000,-803,1000,-695L1000,426C1000,534,912,623,804,623ZM-804,-784L-818,-783L-831,-780L-844,-775L-856,-767L-867,-758L-876,-747L-883,-736L-888,-723L-892,-709L-893,-695L-893,426L-892,440L-888,454L-883,467L-876,479L-867,489L-856,498L-844,506L-831,511L-818,514L-804,515L804,515L818,514L831,511L844,506L856,498L867,489L876,479L883,467L888,454L892,440L893,426L893,-695L892,-709L888,-723L883,-736L876,-747L867,-758L856,-767L844,-775L831,-780L818,-783L804,-784L-804,-784ZM564,891L-564,891C-593,891,-617,868,-617,838C-617,808,-593,784,-564,784L563,784C593,784,617,808,617,838C617,868,593,891,564,891ZM357,268L-357,268C-387,268,-411,244,-411,214L-411,-500C-411,-530,-387,-554,-357,-554C-328,-554,-304,-530,-304,-500L-304,161L357,161C387,161,411,185,411,214C411,244,387,268,357,268ZM-199,109C-228,109,-252,85,-252,56L-252,-24C-252,-53,-228,-77,-199,-77C-169,-77,-145,-53,-145,-24L-145,56C-145,85,-169,109,-199,109ZM-40,109C-69,109,-93,85,-93,56L-93,-182C-93,-212,-69,-236,-40,-236C-10,-236,14,-212,14,-182L14,56C14,85,-10,109,-40,109ZM119,109C89,109,65,85,65,56L65,-500C65,-530,89,-554,119,-554C149,-554,173,-530,173,-500L173,56C173,85,149,109,119,109ZM278,109C248,109,224,85,224,56L224,-341C224,-371,248,-395,278,-395C307,-395,331,-371,331,-341L331,55C331,85,308,109,278,109Z",
  "M713,-712L736,-711L758,-706L779,-698L798,-686L815,-672L830,-655L841,-635L849,-615L854,-593L855,-570L855,572C855,611,842,645,814,673L797,687L778,699L757,708L736,713L713,714L-713,714L-736,713L-757,708L-778,699L-797,687L-814,673L-829,656L-840,637L-849,616L-854,594L-855,572L-855,-570L-854,-593L-849,-615L-841,-635L-830,-655L-815,-672L-798,-686L-779,-698L-758,-706L-736,-711L-713,-712L713,-712ZM713,-857L-713,-857C-751,-855,-788,-847,-822,-833C-857,-819,-888,-798,-915,-771C-941,-744,-962,-714,-977,-679C-993,-644,-1000,-608,-1000,-570L-1000,572C-1000,610,-992,647,-977,681C-962,716,-941,747,-915,774L-881,803L-843,826L-801,843L-758,853L-713,857L713,857C751,857,788,850,822,835C857,821,888,800,915,774C941,747,962,716,977,681C993,647,1000,610,1000,572L1000,-570C1000,-608,992,-644,977,-679L960,-712L939,-743L915,-771L887,-796L856,-817L822,-833L787,-845L750,-853L713,-857ZM429,-428L418,-427L406,-425L396,-420L386,-414L378,-407L371,-398L365,-389L361,-378L359,-368L358,-357L358,356L358,368L361,379L365,389L371,399L378,407L387,415L396,420L407,425L418,427L429,428L440,427L451,425L462,420L471,415L480,407L487,399L493,389L497,379L499,368L500,356L500,-357L499,-368L497,-379L493,-390L487,-399L480,-408L471,-415L462,-421L451,-425L440,-427L429,-428L429,-428ZM-429,-428L-440,-427L-451,-424L-461,-420L-470,-414L-479,-407L-486,-398L-492,-389L-496,-379L-499,-368L-500,-357L-500,356L-499,368L-497,379L-493,389L-487,399L-480,407L-471,415L-461,420L-451,425L-440,427L-429,428L-417,427L-406,425L-396,420L-386,415L-378,407L-370,399L-365,389L-360,379L-358,368L-357,356L-357,-357L-358,-368L-361,-379L-365,-389L-371,-398L-378,-407L-386,-414L-396,-420L-406,-425L-417,-427L-429,-428ZM0,-286L-11,-284L-22,-281L-33,-277L-42,-271L-51,-263L-58,-255L-64,-245L-68,-234L-70,-223L-71,-212L-71,-141L-70,-130L-68,-119L-63,-109L-57,-100L-50,-92L-42,-85L-32,-79L-22,-75L-11,-73L0,-72L11,-73L22,-75L32,-79L42,-85L50,-92L57,-100L63,-109L68,-119L70,-130L71,-141L71,-212L71,-224L68,-235L64,-245L58,-255L50,-263L39,-272L27,-279L14,-283L0,-286ZM0,72L-11,73L-22,75L-33,79L-42,85L-51,92L-58,101L-64,110L-68,121L-71,132L-71,143L-71,214L-71,226L-68,237L-64,247L-58,257L-51,265L-42,273L-33,278L-22,283L-11,285L0,285L11,285L22,283L33,278L42,273L51,265L58,257L64,247L68,237L71,226L71,214L71,143L70,132L68,121L63,111L57,102L50,93L42,86L32,80L22,76L11,73L0,72L0,72Z",
  "M202,-435L202,-844L1000,-120L202,604L202,167C-20,167,-704,167,-1000,844L-1000,768C-1000,467,-704,-499,202,-435Z",
  "M-917,-167C-941,-167,-961,-174,-977,-190C-992,-206,-1000,-226,-1000,-250L-1000,-917C-1000,-941,-992,-961,-977,-977C-961,-992,-941,-1000,-917,-1000L-250,-1000C-226,-1000,-206,-992,-190,-977C-174,-961,-167,-941,-167,-917L-167,-250C-167,-226,-174,-206,-190,-190C-206,-174,-226,-167,-250,-167L-917,-167ZM250,-167C226,-167,206,-174,190,-190C174,-206,167,-226,167,-250L167,-917C167,-941,174,-961,190,-977C206,-992,226,-1000,250,-1000L917,-1000C941,-1000,961,-992,977,-977C992,-961,1000,-941,1000,-917L1000,-250C1000,-226,992,-206,977,-190C961,-174,941,-167,917,-167L250,-167ZM-917,1000C-941,1000,-961,992,-977,977C-992,961,-1000,941,-1000,917L-1000,250C-1000,226,-992,206,-977,190C-961,174,-941,167,-917,167L-250,167C-226,167,-206,174,-190,190C-174,206,-167,226,-167,250L-167,917C-167,941,-174,961,-190,977C-206,992,-226,1000,-250,1000L-917,1000ZM250,1000C226,1000,206,992,190,977C174,961,167,941,167,917L167,250C167,226,174,206,190,190C206,174,226,167,250,167L917,167C941,167,961,174,977,190C992,206,1000,226,1000,250L1000,917C1000,941,992,961,977,977C961,992,941,1000,917,1000L250,1000Z",
  "M0,-857C-80,-856,-148,-828,-202,-773C-256,-719,-284,-652,-286,-571L-286,0C-284,80,-256,148,-202,202C-148,256,-80,284,0,286C80,284,148,256,202,202C256,148,284,80,286,0L286,-571C284,-652,256,-719,202,-773C148,-828,80,-856,0,-857ZM0,-1000C122,-997,223,-955,304,-875C384,-795,426,-693,429,-571L429,0C426,122,384,223,304,304C223,384,122,426,0,429C-122,426,-223,384,-304,304C-384,223,-426,122,-429,0L-429,-571C-426,-693,-384,-795,-304,-875C-223,-955,-122,-997,0,-1000ZM-71,857L-71,714C-253,710,-404,647,-526,526C-647,404,-710,253,-714,71L-714,0C-714,-21,-708,-38,-694,-51C-681,-65,-664,-71,-643,-71C-622,-71,-605,-65,-592,-51C-578,-38,-571,-21,-571,0L-571,71C-568,213,-520,331,-425,425C-331,520,-213,568,-71,571L71,571C213,568,331,520,425,425C520,331,568,213,571,71L571,0C571,-21,578,-38,592,-51C605,-65,622,-71,643,-71C664,-71,681,-65,694,-51C708,-38,714,-21,714,0L714,71C710,253,647,404,526,526C404,647,253,710,71,714L71,857L214,857C235,857,252,864,266,877C279,891,286,908,286,929C286,949,279,967,266,980C252,993,235,1000,214,1000L-214,1000C-235,1000,-252,993,-266,980C-279,967,-286,949,-286,929C-286,908,-279,891,-266,877C-252,864,-235,857,-214,857L-71,857Z",
  "M-923,77L923,77C946,77,964,70,978,55C993,41,1000,22,1000,0C1000,-22,993,-41,978,-55C964,-70,946,-77,923,-77L-923,-77C-946,-77,-964,-70,-978,-55C-993,-41,-1000,-22,-1000,0C-1000,22,-993,41,-978,55C-964,70,-946,77,-923,77Z",
  "M-857,-643L-857,500C-856,540,-842,574,-815,600C-788,627,-754,641,-714,643L714,643C754,641,788,627,815,600C841,574,856,540,857,500L857,-643L-857,-643ZM-857,-786L857,-786C897,-784,931,-770,958,-743C984,-716,998,-683,1000,-643L1000,500C999,580,971,648,916,702C862,756,795,784,714,786L-714,786C-795,784,-862,756,-916,702C-971,648,-998,580,-1000,500L-1000,-643C-999,-683,-984,-717,-958,-743C-931,-770,-897,-784,-857,-786ZM875,-643L324,-11C282,35,233,71,177,96C122,121,62,134,0,134C-62,134,-122,121,-177,96C-233,71,-282,35,-324,-11L-875,-643L875,-643ZM-685,-643L-214,-105C-187,-74,-155,-50,-118,-34C-81,-17,-42,-9,0,-9C42,-9,81,-17,118,-34C155,-50,187,-74,214,-105L685,-643L-685,-643Z",
  "M643,-214C638,-396,575,-547,454,-668C333,-790,181,-853,0,-857C-182,-853,-333,-790,-454,-668C-576,-547,-638,-396,-643,-214C-643,-82,-590,70,-483,240C-377,410,-216,599,0,806C216,599,377,410,483,240C590,70,643,-82,643,-214ZM0,1000C-524,524,-786,119,-786,-214C-780,-438,-703,-623,-556,-770C-409,-917,-223,-994,0,-1000C223,-994,408,-917,556,-770C703,-623,780,-437,786,-214C786,119,524,524,0,1000ZM0,-143C40,-144,74,-158,100,-185C127,-212,141,-246,141,-286C141,-326,127,-359,100,-386C73,-413,40,-426,0,-426C-40,-426,-74,-413,-101,-386C-127,-359,-141,-326,-141,-286C-141,-246,-127,-212,-100,-185C-74,-158,-40,-144,0,-143ZM0,0C-80,-1,-148,-29,-202,-84C-256,-138,-284,-205,-286,-286C-284,-366,-256,-433,-202,-488C-148,-542,-80,-570,0,-571C80,-570,148,-542,202,-488C256,-433,284,-366,286,-286C284,-205,256,-138,202,-84C148,-29,80,-2,0,0ZM772,429L1000,1000L357,1000L357,857L-357,857L-357,1000L-1000,1000L-772,429L772,429ZM618,429L-618,429L-788,857L788,857Z",
  "M286,714C284,795,256,862,202,916C148,971,80,998,0,1000C-80,999,-148,971,-202,916C-256,862,-284,795,-286,714L286,714ZM714,571L-844,571C-868,571,-888,563,-904,547C-920,530,-929,510,-929,486C-929,461,-920,441,-904,425C-888,410,-868,401,-844,400L-714,400L-714,-143C-711,-318,-657,-470,-551,-597C-446,-724,-310,-806,-143,-844C-144,-870,-139,-896,-128,-920C-117,-943,-100,-963,-76,-978C-52,-993,-27,-1000,0,-1000C27,-1000,52,-993,76,-978C100,-963,117,-943,128,-920C139,-896,144,-870,143,-844C313,-805,449,-722,554,-595C658,-468,711,-317,714,-143L714,400L844,400C868,401,888,410,904,425C920,441,929,461,929,486C929,510,920,531,904,547C888,563,868,571,844,571L714,571Z",
  "M-71,429L286,429C326,427,359,413,386,386C413,359,427,326,429,286L429,214L214,214C193,214,176,208,163,194C150,181,143,164,143,143C143,122,150,105,163,92C176,78,193,71,214,71L429,71L429,-143L214,-143C193,-143,176,-150,163,-163C150,-176,143,-193,143,-214C143,-235,150,-252,163,-266C176,-279,193,-286,214,-286L429,-286L429,-500L214,-500C193,-500,176,-507,163,-520C150,-533,143,-551,143,-571C143,-592,150,-609,163,-623C176,-636,193,-643,214,-643L429,-643L429,-714C427,-754,413,-788,386,-815C359,-841,326,-856,286,-857L-286,-857C-326,-856,-359,-842,-386,-815C-413,-788,-427,-754,-429,-714L-429,-643L-214,-643C-193,-643,-176,-636,-163,-623C-150,-609,-143,-592,-143,-571C-143,-551,-150,-533,-163,-520C-176,-507,-193,-500,-214,-500L-429,-500L-429,-286L-214,-286C-193,-286,-176,-279,-163,-266C-150,-252,-143,-235,-143,-214C-143,-193,-150,-176,-163,-163C-176,-150,-193,-143,-214,-143L-429,-143L-429,71L-214,71C-193,71,-176,78,-163,92C-150,105,-143,122,-143,143C-143,164,-150,181,-163,194C-176,208,-193,214,-214,214L-429,214L-429,286C-427,326,-413,359,-386,386C-359,413,-326,427,-286,429L-71,429ZM71,571L71,857L500,857C521,857,538,864,551,877C565,891,571,908,571,929C571,949,565,967,551,980C538,993,521,1000,500,1000L-500,1000C-521,1000,-538,993,-551,980C-565,967,-571,949,-571,929C-571,908,-565,891,-551,877C-538,864,-521,857,-500,857L-71,857L-71,571L-286,571C-366,570,-433,542,-488,488C-542,433,-570,366,-571,286L-571,-714C-570,-795,-542,-862,-488,-916C-433,-971,-366,-998,-286,-1000L286,-1000C366,-999,433,-971,488,-916C542,-862,570,-795,571,-714L571,286C570,366,542,433,488,488C433,542,366,570,286,571L71,571Z",
  "M-200,-733L-200,-800C-199,-857,-179,-904,-142,-942C-104,-979,-57,-999,0,-1000L267,-1000C286,-1000,302,-994,315,-981C327,-969,333,-953,333,-933C333,-914,327,-898,315,-885C302,-873,286,-867,267,-867L0,-867C-19,-867,-35,-860,-48,-848C-60,-835,-67,-819,-67,-800L-67,-733L600,-733C654,-732,700,-714,738,-679C775,-644,795,-600,798,-546C801,-492,786,-445,753,-405C721,-366,678,-342,625,-335L542,875C539,911,525,941,500,964C475,986,444,999,408,1000L-408,1000C-444,999,-475,986,-500,964C-525,941,-539,911,-542,875L-625,-335C-678,-342,-721,-366,-753,-405C-786,-445,-801,-492,-798,-546C-795,-600,-775,-644,-738,-679C-700,-714,-654,-732,-600,-733L-200,-733ZM-492,-333L-408,867L408,867L419,719C308,688,220,629,156,541C92,452,63,351,69,235C78,120,121,23,197,-56C272,-135,367,-183,481,-198L492,-333L-492,-333ZM-600,-467L600,-467C619,-467,635,-473,648,-485C660,-498,667,-514,667,-533C667,-553,660,-569,648,-581C635,-594,619,-600,600,-600L-600,-600C-619,-600,-635,-594,-648,-581C-660,-569,-667,-553,-667,-533C-667,-514,-660,-498,-648,-485C-635,-473,-619,-467,-600,-467ZM427,583L473,-60C397,-45,334,-10,284,45C235,100,208,166,202,244C197,322,215,391,256,452C298,513,355,557,427,583Z",
  "M0,857C162,853,297,797,404,690C511,583,567,448,571,286C567,124,511,-11,404,-118C297,-225,162,-281,0,-286C-162,-281,-297,-225,-404,-118C-511,-11,-567,124,-571,286C-567,448,-511,583,-404,690C-297,797,-162,853,0,857ZM0,1000C-202,996,-371,926,-506,791C-640,657,-710,488,-714,286C-710,83,-640,-85,-506,-220C-371,-355,-202,-424,0,-429C202,-424,371,-355,506,-220C640,-85,710,83,714,286C710,488,640,657,506,791C371,926,202,996,0,1000ZM143,-857L-143,-857L-143,-411C-95,-423,-48,-429,0,-429C43,-429,91,-423,143,-411L143,-857ZM286,-857L286,-366C341,-347,399,-321,460,-290L547,-857L286,-857ZM-286,-857L-547,-857L-460,-290C-399,-321,-341,-347,-286,-366L-286,-857ZM-632,-1000L632,-1000C653,-1000,670,-992,684,-975C698,-959,704,-940,701,-917L571,-71C317,-214,126,-286,0,-286C-127,-286,-317,-214,-572,-71L-701,-917C-704,-940,-698,-959,-684,-975C-670,-992,-653,-1000,-632,-1000Z",
  "M0,857C162,853,297,797,404,690C511,583,567,448,571,286C567,124,511,-11,404,-118C297,-225,162,-281,0,-286C-162,-281,-297,-225,-404,-118C-511,-11,-567,124,-571,286C-567,448,-511,583,-404,690C-297,797,-162,853,0,857ZM0,1000C-202,996,-371,926,-506,791C-640,657,-710,488,-714,286C-710,83,-640,-85,-506,-220C-371,-355,-202,-424,0,-429C202,-424,371,-355,506,-220C640,-85,710,83,714,286C710,488,640,657,506,791C371,926,202,996,0,1000ZM-71,-71L71,-71L71,500L214,500L214,643L-214,643L-214,500L-71,500L-71,71L-214,71L-214,-71L-71,-71ZM143,-857L-143,-857L-143,-411C-95,-423,-48,-429,0,-429C43,-429,91,-423,143,-411L143,-857ZM286,-857L286,-366C341,-347,399,-321,460,-290L547,-857L286,-857ZM-286,-857L-547,-857L-460,-290C-399,-321,-341,-347,-286,-366L-286,-857ZM-632,-1000L632,-1000C653,-1000,670,-992,684,-975C698,-959,704,-940,701,-917L571,-71C317,-214,126,-286,0,-286C-127,-286,-317,-214,-572,-71L-701,-917C-704,-940,-698,-959,-684,-975C-670,-992,-653,-1000,-632,-1000Z",
  "M-571,-857C-612,-856,-645,-842,-672,-815C-699,-788,-713,-754,-714,-714L-714,714C-713,754,-699,788,-672,815C-645,841,-612,856,-571,857L571,857C612,856,645,842,672,815C699,788,713,754,714,714L714,-714C713,-754,699,-788,672,-815C645,-841,612,-856,571,-857L-571,-857ZM-571,-1000L571,-1000C652,-999,719,-971,773,-916C828,-862,856,-795,857,-714L857,714C856,795,828,862,773,916C719,971,652,998,571,1000L-571,1000C-652,999,-719,971,-773,916C-828,862,-856,795,-857,714L-857,-714C-856,-795,-828,-862,-773,-916C-719,-971,-652,-998,-571,-1000ZM-286,-714L286,-714C307,-714,324,-708,337,-694C350,-681,357,-664,357,-643C357,-622,350,-605,337,-592C324,-578,307,-571,286,-571L-286,-571C-307,-571,-324,-578,-337,-592C-350,-605,-357,-622,-357,-643C-357,-664,-350,-681,-337,-694C-324,-708,-307,-714,-286,-714ZM0,714C-40,713,-74,699,-100,672C-127,645,-141,612,-141,571C-141,531,-127,498,-100,471C-74,444,-40,431,0,431C40,431,74,444,100,471C127,498,141,531,141,571C141,612,127,645,100,672C74,699,40,713,0,714Z",
  "M-600,533L-600,733C-599,771,-585,802,-560,827C-535,852,-504,865,-467,867L467,867C504,865,535,852,560,827C585,802,599,771,600,733L600,533L-600,533ZM-600,400L600,400L600,-733C599,-771,585,-802,560,-827C535,-852,504,-865,467,-867L-467,-867C-504,-865,-535,-852,-560,-827C-585,-802,-599,-771,-600,-733L-600,400ZM-533,1000C-590,999,-637,979,-675,942C-713,904,-732,857,-733,800L-733,-800C-732,-857,-713,-904,-675,-942C-637,-979,-590,-999,-533,-1000L533,-1000C590,-999,637,-979,675,-942C713,-904,732,-857,733,-800L733,800C732,857,713,904,675,942C637,979,590,999,533,1000L-533,1000ZM100,700C99,728,89,751,70,770C51,789,28,798,0,798C-28,798,-51,789,-70,770C-89,751,-98,728,-98,700C-98,672,-89,649,-70,630C-51,611,-28,602,0,602C28,602,51,611,70,630C89,649,99,672,100,700Z",
  "M-571,286L-571,714L857,714L857,-286L571,-286L571,-429L908,-429C923,-429,935,-428,943,-426C951,-425,958,-423,964,-420C976,-412,985,-403,991,-393C994,-387,996,-380,998,-372C999,-363,1000,-352,1000,-337L1000,766C1000,781,999,792,998,800C996,808,994,815,991,821C984,833,975,842,964,848C958,851,951,853,943,855C935,856,923,857,908,857L-623,857C-638,857,-649,856,-657,855C-666,853,-673,851,-679,848C-690,841,-699,832,-705,821C-708,815,-711,808,-712,800C-714,792,-714,781,-714,766L-714,286L-571,286ZM571,-714L-857,-714L-857,286L571,286L571,-714ZM714,-766L714,337C714,352,714,364,712,372C711,380,708,387,705,393C698,405,689,414,679,420C673,423,666,425,657,426C649,428,638,429,623,429L-908,429C-923,429,-935,428,-943,426C-951,425,-958,423,-964,420C-976,412,-985,403,-991,393C-994,387,-996,380,-998,372C-999,363,-1000,352,-1000,337L-1000,-766C-1000,-781,-999,-792,-998,-800C-996,-808,-994,-815,-991,-821C-984,-833,-975,-842,-964,-848C-958,-851,-951,-853,-943,-855C-935,-856,-923,-857,-908,-857L623,-857C638,-857,649,-856,657,-855C665,-853,673,-851,679,-848C689,-841,698,-832,705,-821C708,-815,711,-808,712,-800C714,-792,714,-780,714,-766ZM-143,143C-244,140,-328,105,-395,38C-462,-29,-497,-113,-500,-214C-497,-315,-462,-400,-395,-466C-328,-533,-244,-568,-143,-571C-42,-568,42,-533,109,-466C176,-400,211,-315,214,-214C211,-113,176,-29,109,38C42,105,-42,140,-143,143ZM-143,0C-82,-1,-31,-22,9,-62C49,-103,69,-153,69,-214C69,-275,49,-326,9,-366C-31,-406,-82,-426,-143,-426C-204,-426,-254,-406,-295,-366C-335,-326,-355,-275,-355,-214C-355,-153,-335,-103,-295,-62C-254,-22,-204,-1,-143,0Z",
  "M-750,-250C-679,-249,-619,-224,-573,-177C-526,-131,-502,-71,-500,0C-501,71,-526,131,-573,177C-619,224,-679,248,-750,250C-821,249,-881,224,-927,177C-974,131,-998,71,-1000,0C-999,-71,-974,-131,-927,-177C-881,-224,-821,-248,-750,-250ZM0,-250C71,-249,131,-224,177,-177C224,-131,248,-71,250,0C249,71,224,131,177,177C131,224,71,248,0,250C-71,249,-131,224,-177,177C-224,131,-248,71,-250,0C-249,-71,-224,-131,-177,-177C-131,-224,-71,-248,0,-250ZM750,-250C821,-249,881,-224,927,-177C974,-131,998,-71,1000,0C999,71,974,131,927,177C881,224,821,248,750,250C679,249,619,224,573,177C526,131,502,71,500,0C501,-71,526,-131,573,-177C619,-224,679,-248,750,-250Z",
  "M-161,196L-571,196L-571,482L-446,482L-589,625L-643,625C-664,625,-681,618,-694,605C-708,592,-714,574,-714,554L-714,125C-714,104,-708,87,-694,74C-681,60,-664,54,-643,54L-18,54ZM161,482L429,482L429,214L589,54L929,54C949,54,967,60,980,74C993,87,1000,104,1000,125L1000,554C1000,574,993,592,980,605C967,618,949,625,929,625L18,625ZM571,196L571,482L857,482L857,196L571,196ZM504,-268L607,-165L-504,946L-607,844ZM-571,-946L-429,-946L-429,-232L-571,-232L-571,-946ZM-857,-661L-714,-661L-714,-232L-857,-232L-857,-661ZM-1000,54L-857,54L-857,625L-1000,625L-1000,54Z",
  "M-750,-250C-821,-249,-881,-224,-927,-177C-974,-131,-998,-71,-1000,0C-999,71,-974,131,-927,177C-881,224,-821,248,-750,250C-679,249,-619,224,-573,177C-526,131,-502,71,-500,0C-501,-71,-526,-131,-573,-177C-619,-224,-679,-248,-750,-250ZM-750,-107C-720,-106,-695,-95,-675,-75C-655,-55,-645,-30,-645,0C-645,30,-655,55,-675,75C-695,95,-720,105,-750,105C-780,105,-805,95,-825,75C-845,55,-855,30,-855,0C-855,-30,-845,-55,-825,-75C-805,-95,-780,-106,-750,-107ZM0,-250C71,-249,131,-224,177,-177C224,-131,248,-71,250,0C249,71,224,131,177,177C131,224,71,248,0,250C-71,249,-131,224,-177,177C-224,131,-248,71,-250,0C-249,-71,-224,-131,-177,-177C-131,-224,-71,-248,0,-250ZM0,-107C-30,-106,-55,-95,-75,-75C-95,-55,-105,-30,-105,0C-105,30,-95,55,-75,75C-55,95,-30,105,0,105C30,105,55,95,75,75C95,55,105,30,105,0C105,-30,95,-55,75,-75C55,-95,30,-106,0,-107ZM750,-250C821,-249,881,-224,927,-177C974,-131,998,-71,1000,0C999,71,974,131,927,177C881,224,821,248,750,250C679,249,619,224,573,177C526,131,502,71,500,0C501,-71,526,-131,573,-177C619,-224,679,-248,750,-250ZM750,-107C720,-106,695,-95,675,-75C655,-55,645,-30,645,0C645,30,655,55,675,75C695,95,720,105,750,105C780,105,805,95,825,75C845,55,855,30,855,0C855,-30,845,-55,825,-75C805,-95,780,-106,750,-107Z",
  "M-357,-857L-357,857L-500,857L-500,-857L-714,-857L-714,857L714,857L714,-857L-357,-857ZM-786,-1000L786,-1000C807,-1000,824,-993,837,-980C850,-967,857,-949,857,-929L857,929C857,949,850,967,837,980C824,993,807,1000,786,1000L-786,1000C-807,1000,-824,993,-837,980C-850,967,-857,949,-857,929L-857,-929C-857,-949,-850,-967,-837,-980C-824,-993,-807,-1000,-786,-1000ZM-71,-571L357,-571C405,-571,429,-548,429,-500C429,-452,405,-429,357,-429L-71,-429C-119,-429,-143,-452,-143,-500C-143,-548,-119,-571,-71,-571ZM-71,-143L357,-143C405,-143,429,-119,429,-71C429,-24,405,0,357,0L-71,0C-119,0,-143,-24,-143,-71C-143,-119,-119,-143,-71,-143ZM-71,286L357,286C405,286,429,310,429,357C429,405,405,429,357,429L-71,429C-119,429,-143,405,-143,357C-143,310,-119,286,-71,286Z",
  "M0,-1000L-1000,-167L-1000,1000L-333,1000L-333,333L333,333L333,1000L1000,1000L1000,-167Z",
  "M-77,-846L-77,-692L-692,-692C-736,-691,-772,-675,-800,-647C-829,-618,-845,-582,-846,-538L-846,692C-845,736,-829,772,-800,800C-772,829,-736,845,-692,846L538,846C582,845,618,829,647,800C675,772,691,736,692,692L692,77L846,77L846,692C845,779,815,851,756,910C697,968,625,998,538,1000L-692,1000C-779,998,-851,968,-910,910C-968,851,-998,779,-1000,692L-1000,-538C-998,-625,-968,-698,-910,-756C-851,-814,-779,-845,-692,-846L-77,-846ZM538,-231C625,-232,698,-262,756,-321C814,-379,845,-452,846,-538C845,-625,815,-698,756,-756C697,-814,625,-845,538,-846C452,-845,379,-815,321,-756C262,-697,232,-625,231,-538C232,-452,262,-379,321,-321C379,-262,452,-232,538,-231ZM538,-77C407,-80,298,-125,212,-212C125,-298,80,-407,77,-538C80,-670,125,-779,212,-865C298,-952,407,-997,538,-1000C670,-997,779,-952,865,-865C952,-779,997,-670,1000,-538C997,-407,952,-298,865,-212C779,-125,670,-80,538,-77Z",
  "M-643,-857L-643,857L786,857L786,-857L-643,-857ZM-714,-1000L857,-1000C878,-1000,895,-993,908,-980C922,-967,929,-949,929,-929L929,929C929,949,922,967,908,980C895,993,878,1000,857,1000L-714,1000C-735,1000,-752,993,-766,980C-779,967,-786,949,-786,929L-786,-929C-786,-949,-779,-967,-766,-980C-752,-993,-735,-1000,-714,-1000ZM429,-857L571,-857L571,857L429,857L429,-857ZM-857,-714L-571,-714C-524,-714,-500,-690,-500,-643C-500,-595,-524,-571,-571,-571L-857,-571C-905,-571,-929,-595,-929,-643C-929,-690,-905,-714,-857,-714ZM-857,-286L-571,-286C-524,-286,-500,-262,-500,-214C-500,-167,-524,-143,-571,-143L-857,-143C-905,-143,-929,-167,-929,-214C-929,-262,-905,-286,-857,-286ZM-857,143L-571,143C-524,143,-500,167,-500,214C-500,262,-524,286,-571,286L-857,286C-905,286,-929,262,-929,214C-929,167,-905,143,-857,143ZM-857,571L-571,571C-524,571,-500,595,-500,643C-500,690,-524,714,-571,714L-857,714C-905,714,-929,690,-929,643C-929,595,-905,571,-857,571Z",
  "M231,386L231,771C229,837,207,892,164,935C120,978,66,1000,0,1000C-66,1000,-120,978,-164,935C-207,892,-229,837,-231,771L-231,386L-462,386C-549,385,-621,355,-680,296C-738,237,-769,165,-770,78L770,78C769,165,738,237,680,296C621,355,549,385,462,386L231,386ZM-770,-76L-770,-1000L770,-1000L770,-76L-770,-76Z",
  "M-1000,1000L-1000,-1000L1000,-1000L1000,1000L-1000,1000ZM-240,148L94,414L562,-112L438,-221L73,185L-260,-81L-729,445L-604,555ZM792,-417C790,-451,777,-480,754,-504C730,-527,701,-539,667,-539C632,-539,603,-527,579,-504C556,-480,544,-451,544,-417C544,-382,556,-353,579,-329C603,-306,632,-294,667,-294C701,-294,730,-306,754,-329C777,-353,790,-382,792,-417Z",
  "M-165,-571C-240,-571,-295,-568,-333,-563C-370,-557,-402,-546,-429,-531C-473,-507,-507,-473,-531,-429C-546,-402,-557,-370,-563,-333C-569,-295,-572,-240,-572,-165L-572,451C-572,525,-569,581,-563,618C-557,656,-546,688,-531,714C-507,759,-473,793,-429,817C-402,832,-370,842,-333,848C-295,854,-240,857,-165,857L165,857C240,857,295,854,333,848C370,842,402,832,429,817C473,793,507,759,531,714C546,688,557,656,563,618C569,581,572,525,572,451L572,-165C572,-240,569,-295,563,-333C557,-370,546,-402,531,-429C507,-473,473,-507,429,-531C402,-546,370,-557,333,-563C295,-568,240,-571,165,-571L-165,-571ZM-165,-714L165,-714C257,-714,327,-709,375,-700C423,-690,463,-676,496,-656C566,-619,619,-566,656,-496C676,-463,690,-423,700,-375C709,-327,714,-257,714,-165L714,451C714,543,709,613,700,661C690,708,676,749,656,781C619,851,566,905,496,942C463,961,423,976,375,986C327,995,257,1000,165,1000L-165,1000C-257,1000,-327,995,-375,986C-423,976,-463,961,-496,942C-566,905,-619,851,-656,781C-676,749,-690,708,-700,661C-709,613,-714,543,-714,451L-714,-165C-714,-257,-709,-327,-700,-375C-690,-423,-676,-463,-656,-496C-619,-566,-566,-619,-496,-656C-463,-676,-423,-690,-375,-700C-327,-709,-257,-714,-165,-714ZM0,-429C48,-429,71,-405,71,-357L71,-71C71,-24,48,0,0,0C-48,0,-71,-24,-71,-71L-71,-357C-71,-405,-48,-429,0,-429ZM71,-643C71,-622,65,-605,51,-592C38,-578,21,-571,0,-571C-21,-571,-38,-578,-51,-592C-65,-605,-71,-622,-71,-643L-71,-786C-71,-807,-78,-824,-92,-837C-105,-850,-122,-857,-143,-857L-357,-857C-378,-857,-395,-864,-409,-877C-422,-891,-429,-908,-429,-929C-429,-949,-422,-967,-409,-980C-395,-993,-378,-1000,-357,-1000L-143,-1000C-82,-999,-31,-978,9,-938C49,-897,70,-847,71,-786L71,-643Z",
  "M167,-1000L167,-250L417,-500L667,-250L667,-1000L1000,-1000L1000,1000L-500,1000L-500,-1000L167,-1000ZM-1000,-1000L-667,-1000L-667,1000L-1000,1000L-1000,-1000Z",
  "M-320,667C-301,616,-270,576,-228,546C-185,515,-137,500,-83,500C-29,500,19,515,61,546C104,576,134,616,154,667L1000,667L1000,833L154,833C134,884,104,924,61,954C19,985,-29,1000,-83,1000C-137,1000,-185,985,-228,954C-270,924,-301,884,-320,833L-1000,833L-1000,667L-320,667ZM180,-83C199,-134,230,-174,272,-204C315,-235,363,-250,417,-250C470,-250,519,-235,561,-204C604,-174,634,-134,654,-83L1000,-83L1000,83L654,83C634,134,604,174,561,204C519,235,470,250,417,250C363,250,315,235,272,204C230,174,199,134,180,83L-1000,83L-1000,-83L180,-83ZM-654,-833C-634,-884,-604,-924,-561,-954C-519,-985,-470,-1000,-417,-1000C-363,-1000,-315,-985,-272,-954C-230,-924,-199,-884,-180,-833L1000,-833L1000,-667L-180,-667C-199,-616,-230,-576,-272,-546C-315,-515,-363,-500,-417,-500C-470,-500,-519,-515,-561,-546C-604,-576,-634,-616,-654,-667L-1000,-667L-1000,-833L-654,-833Z",
  "M-714,-786L-714,786L143,786L143,-786L-714,-786ZM-786,-929L214,-929C235,-929,252,-922,266,-909C279,-895,286,-878,286,-857L286,857C286,878,279,895,266,909C252,922,235,929,214,929L-786,929C-807,929,-824,922,-837,909C-850,895,-857,878,-857,857L-857,-857C-857,-878,-850,-895,-837,-909C-824,-922,-807,-929,-786,-929ZM-571,-500L0,-500L0,-357L-571,-357L-571,-500ZM-571,-71L0,-71L0,71L-571,71L-571,-71ZM-571,357L0,357L0,500L-571,500L-571,357ZM286,71L571,71L571,214L286,214L286,71ZM286,357L571,357L571,500L286,500L286,357ZM-1000,786L1000,786L1000,929L-1000,929L-1000,786ZM286,-214L286,786L714,786L714,-214L286,-214ZM214,-357L786,-357C807,-357,824,-350,837,-337C850,-324,857,-307,857,-286L857,857C857,878,850,895,837,909C824,922,807,929,786,929L214,929C193,929,176,922,163,909C150,895,143,878,143,857L143,-286C143,-307,150,-324,163,-337C176,-350,193,-357,214,-357Z",
  "M-357,-500C-498,-496,-616,-447,-710,-353C-804,-259,-853,-141,-857,0C-853,141,-804,259,-710,353C-616,447,-498,496,-357,500L357,500C498,496,616,447,710,353C804,259,853,141,857,0C853,-141,804,-259,710,-353C616,-447,498,-496,357,-500L-357,-500ZM-357,-643L357,-643C539,-638,690,-575,811,-454C932,-333,995,-182,1000,0C995,182,932,333,811,454C690,575,539,638,357,643L-357,643C-539,638,-690,575,-811,454C-932,333,-995,182,-1000,0C-995,-182,-932,-333,-811,-454C-690,-575,-539,-638,-357,-643ZM357,214C396,214,432,204,465,185C497,166,523,140,542,107C561,74,571,38,571,0C571,-38,561,-74,542,-107C523,-140,497,-166,465,-185C432,-204,396,-214,357,-214C297,-212,246,-191,206,-151C165,-110,144,-60,143,0C144,60,165,110,206,151C246,191,297,212,357,214ZM357,357C256,354,172,319,105,252C38,185,3,101,0,0C3,-101,38,-185,105,-252C172,-319,256,-354,357,-357C458,-354,542,-319,609,-252C676,-185,711,-101,714,0C711,101,676,185,609,252C542,319,458,354,357,357Z",
  "M0,-232L0,-93L923,-93C945,-93,964,-83,978,-64C993,-44,997,-23,991,0L818,609C789,705,737,781,661,838C586,894,498,924,398,925L-398,925C-498,924,-586,894,-661,838C-737,781,-789,705,-818,609L-991,0C-997,-23,-993,-44,-978,-64C-964,-83,-945,-93,-923,-93L-145,-93L-145,-843C-144,-870,-132,-891,-109,-905C-86,-918,-63,-919,-39,-907L-7,-891L0,-893L0,-886L527,-600C552,-585,563,-562,563,-533C562,-503,549,-483,523,-470ZM0,-391L329,-541L0,-721L0,-391ZM0,52L-825,52L-784,198L784,198L825,52L0,52ZM-743,343L-677,568C-659,632,-625,683,-574,721C-523,758,-464,778,-398,780L398,780C464,778,523,758,574,721C625,683,659,632,677,568L743,343L-743,343Z",
  "M459,-500L751,-500C770,-500,786,-494,799,-482C812,-470,820,-455,823,-435L865,0L722,0L686,-357L459,-357L459,-143C459,-122,452,-105,439,-91C425,-78,408,-71,387,-71C366,-71,349,-78,336,-91C323,-105,316,-122,316,-143L316,-357L-256,-357L-256,-143C-256,-122,-262,-105,-276,-91C-289,-78,-306,-71,-327,-71C-348,-71,-365,-78,-378,-91C-392,-105,-398,-122,-398,-143L-398,-357L-626,-357L-740,786L30,786L30,929L-820,929C-841,929,-859,921,-873,905C-887,890,-892,871,-890,850L-762,-435C-759,-455,-751,-470,-739,-482C-726,-494,-710,-500,-691,-500L-398,-500L-398,-549C-395,-677,-354,-783,-273,-868C-193,-953,-92,-997,30,-1000C152,-997,253,-953,334,-868C414,-783,456,-677,459,-549L459,-500ZM316,-500L316,-549C314,-637,286,-710,232,-768C178,-826,110,-856,30,-857C-50,-856,-118,-826,-172,-768C-226,-710,-254,-637,-256,-549L-256,-500L316,-500ZM764,580L602,415L602,929C602,949,595,967,581,980C568,993,551,1000,530,1000C509,1000,492,993,479,980C465,967,459,949,459,929L459,415L296,580C275,600,251,606,225,598C199,591,183,574,176,548C170,522,175,499,193,480L479,194C494,179,511,172,530,172C549,172,567,179,581,194L867,480C885,499,891,522,884,548C877,574,861,591,835,598C809,606,785,600,764,580Z",
  "M692,588L979,876C993,891,1000,908,1000,927C1000,947,993,963,978,978C963,993,947,1000,927,1000C908,1000,891,993,876,979L588,692C384,859,158,935,-91,921C-339,906,-555,804,-738,616C-912,418,-998,194,-993,-54C-988,-303,-895,-522,-712,-712C-522,-895,-303,-988,-54,-993C195,-998,418,-913,616,-738C804,-555,906,-339,921,-91C935,158,859,384,692,588ZM-36,774C195,768,386,689,537,537C689,385,768,194,774,-36C768,-266,689,-457,537,-609C385,-761,194,-840,-36,-846C-266,-840,-457,-761,-609,-609C-760,-457,-839,-266,-846,-36C-840,194,-760,385,-609,537C-457,689,-266,768,-36,774Z",
  "M778,-217C852,-175,907,-117,944,-44C981,29,995,108,986,192C976,276,946,350,894,414C842,478,775,523,695,549C664,681,599,786,498,866C398,946,281,987,146,990L-65,990C-85,990,-102,984,-115,970C-128,957,-135,940,-135,920C-135,899,-128,883,-115,869C-102,856,-85,850,-65,850L146,850C237,848,318,822,390,772C461,721,513,654,543,569L497,569C477,569,460,562,447,549C434,536,427,519,427,498L427,-204C427,-225,434,-242,447,-255C460,-268,477,-274,497,-274L568,-274C591,-274,614,-273,636,-270C615,-434,547,-569,430,-674C314,-779,172,-834,6,-836C-161,-834,-303,-779,-419,-674C-536,-569,-604,-434,-625,-270C-603,-273,-580,-274,-557,-274L-486,-274C-466,-274,-449,-268,-436,-255C-423,-242,-416,-225,-416,-204L-416,498C-416,519,-423,536,-436,549C-449,562,-466,569,-486,569L-557,569C-655,567,-740,538,-813,482C-887,426,-936,350,-962,256C-987,161,-982,71,-946,-14C-910,-100,-851,-168,-767,-217C-761,-437,-686,-620,-541,-765C-396,-911,-214,-986,6,-990C225,-986,407,-911,552,-765C697,-620,773,-437,778,-217ZM-557,-134C-636,-133,-702,-105,-755,-52C-809,2,-836,68,-838,147C-836,226,-809,292,-755,346C-702,399,-636,427,-557,428L-557,-134ZM849,147C847,68,820,2,766,-52C713,-105,647,-132,568,-134L568,428C647,427,713,399,766,346C820,292,847,226,849,147Z",
  "M0,203L-245,553C-243,647,-271,729,-327,798C-384,866,-458,909,-551,926C-645,939,-729,923,-804,875C-880,828,-932,759,-961,669C-987,579,-981,494,-944,412C-907,330,-845,270,-760,230C-673,193,-587,188,-501,215C-416,242,-348,295,-298,374L-89,77L-721,-827C-733,-844,-737,-862,-733,-881C-730,-900,-719,-916,-703,-928C-686,-940,-668,-944,-649,-941C-630,-937,-614,-926,-602,-910L297,374C349,295,418,242,502,215C587,188,673,193,760,230C845,270,907,330,944,412C981,493,987,579,961,669C932,759,880,828,804,875C729,923,644,939,551,926C460,909,386,866,328,797C271,729,243,647,245,553ZM124,-230L602,-910C614,-926,630,-937,649,-940C668,-944,686,-940,703,-928C719,-916,730,-900,733,-881C737,-862,733,-844,721,-827L215,-102L126,-230L124,-230ZM-737,745C-703,768,-667,781,-629,785C-591,789,-554,782,-517,765C-480,749,-451,724,-429,692C-407,660,-394,624,-390,585C-386,545,-393,508,-410,473C-426,438,-452,409,-485,386C-537,352,-591,341,-648,351C-704,362,-750,392,-785,443C-820,493,-833,547,-824,603C-815,659,-786,707,-737,745ZM737,745C770,722,796,693,812,658C829,623,836,585,833,545C830,504,817,468,795,436C773,404,743,380,706,363C669,346,630,339,591,343C553,347,517,361,485,386C436,422,407,469,398,526C389,584,402,637,437,687C472,736,518,766,574,777C631,788,685,777,737,745Z",
  "M71,855C161,848,246,827,328,792C410,758,485,712,554,654L145,246C123,259,98,269,71,277L71,855ZM654,554C712,485,758,410,792,328C827,246,848,161,855,71L277,71C269,98,259,123,246,145ZM855,-71C848,-161,827,-246,792,-328C758,-410,712,-485,654,-554L246,-145C259,-123,269,-98,277,-71L855,-71ZM554,-654C485,-712,410,-758,328,-792C246,-827,161,-848,71,-855L71,-277C98,-269,123,-259,145,-246ZM-71,-855C-161,-848,-246,-827,-328,-792C-410,-758,-485,-712,-554,-654L-145,-246C-123,-259,-98,-269,-71,-277L-71,-855ZM-654,-554C-712,-485,-758,-410,-792,-328C-827,-246,-848,-161,-855,-71L-277,-71C-269,-98,-259,-123,-246,-145ZM-855,71C-848,161,-827,246,-792,328C-758,410,-712,485,-654,554L-246,145C-259,121,-269,97,-277,71L-855,71ZM-554,654C-485,712,-410,758,-328,792C-246,827,-161,848,-71,855L-71,277C-97,269,-121,259,-145,246ZM0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-706C-518,-895,-283,-993,0,-1000C283,-993,518,-895,706,-706C895,-518,993,-283,1000,0C993,283,895,518,706,706C518,895,283,993,0,1000ZM0,143C40,141,74,127,100,100C127,74,141,40,141,0C141,-40,127,-74,100,-100C74,-127,40,-141,0,-141C-40,-141,-74,-127,-100,-100C-127,-74,-141,-40,-141,0C-141,40,-127,74,-100,100C-74,127,-40,141,0,143Z",
  "M-978,-174L174,978C184,988,197,994,211,997C225,999,239,997,253,991L820,749C844,738,859,721,863,696C868,671,861,650,843,632L499,286C488,276,474,269,459,266C444,263,430,265,416,273L259,351L-351,-259L-273,-416C-265,-430,-263,-444,-266,-459C-269,-474,-276,-488,-286,-499L-632,-843C-650,-861,-671,-868,-696,-863C-721,-859,-738,-844,-749,-820L-991,-253C-997,-239,-999,-225,-997,-211C-994,-197,-988,-184,-978,-174ZM-841,-241L-659,-668L-423,-434L-526,-230L230,526L434,423L668,659L241,841ZM-6,-425L-6,-569C157,-565,293,-508,401,-401C508,-293,565,-157,569,6L425,6C422,-117,380,-219,300,-300C219,-380,117,-422,-6,-425ZM-6,-856L-6,-1000C279,-993,516,-894,705,-705C894,-516,993,-279,1000,6L856,6C850,-238,766,-441,604,-604C441,-766,238,-850,-6,-856Z",
  "M-929,857C-949,857,-967,850,-980,837C-993,824,-1000,807,-1000,786L-1000,-786C-1000,-807,-993,-824,-980,-837C-967,-850,-949,-857,-929,-857L929,-857C949,-857,967,-850,980,-837C993,-824,1000,-807,1000,-786L1000,786C1000,807,993,824,980,837C967,850,949,857,929,857L-929,857ZM-223,348L-377,194C-392,179,-409,172,-429,172C-448,172,-465,179,-480,194L-857,571L882,571L342,-76C327,-94,308,-103,286,-103C263,-103,245,-94,230,-76L-118,342C-132,358,-149,366,-170,367C-190,368,-208,362,-223,348ZM-571,-286C-571,-247,-562,-211,-542,-179C-523,-146,-497,-120,-463,-100C-430,-81,-394,-71,-357,-71C-320,-71,-284,-81,-250,-100C-216,-120,-189,-146,-171,-179C-152,-211,-143,-247,-143,-286C-144,-347,-165,-397,-205,-438C-246,-478,-296,-498,-357,-498C-418,-498,-469,-478,-509,-438C-549,-397,-570,-347,-572,-286Z",
  "M-500,-286L500,-286L500,-143L-500,-143L-500,-286ZM-286,-571L286,-571L286,-429L-286,-429L-286,-571ZM-850,0L-286,0L-286,286L286,286L286,0L850,0L469,-714L-469,-714ZM857,143L429,143L429,429L-429,429L-429,143L-857,143L-857,714L857,714L857,143ZM-527,-857L527,-857C557,-856,578,-842,591,-817L993,-16C998,-5,1000,6,1000,18L1000,786C1000,807,993,824,980,837C967,850,949,857,929,857L-929,857C-949,857,-967,850,-980,837C-993,824,-1000,807,-1000,786L-1000,18C-1000,6,-998,-5,-993,-16L-592,-817C-578,-842,-557,-856,-527,-857Z",
  "M0,-857C-243,-851,-445,-767,-606,-606C-767,-445,-851,-243,-857,0C-851,243,-767,445,-606,606C-445,767,-243,851,0,857C243,851,445,767,606,606C767,445,851,243,857,0C851,-243,767,-445,606,-606C445,-767,243,-851,0,-857ZM0,-1000C283,-993,518,-895,706,-706C895,-518,993,-283,1000,0C993,283,895,518,706,706C518,895,283,993,0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-706C-518,-895,-283,-993,0,-1000ZM286,-500C381,-500,429,-452,429,-357C429,-262,381,-214,286,-214C190,-214,143,-262,143,-357C143,-452,190,-500,286,-500ZM-663,623L-766,520L-350,107C-312,70,-267,49,-216,45C-166,40,-118,54,-74,85L234,304C248,314,263,319,279,317C295,316,310,310,324,299L882,-201L976,-94L420,406C380,439,335,457,287,460C239,463,194,449,152,420L-158,201C-172,191,-187,186,-204,188C-221,189,-237,196,-250,208Z",
  "M-846,-846L-846,846L846,846L846,-846L-846,-846ZM-923,-1000L923,-1000C946,-1000,964,-993,978,-978C993,-964,1000,-946,1000,-923L1000,923C1000,946,993,964,978,978C964,993,946,1000,923,1000L-923,1000C-946,1000,-964,993,-978,978C-993,964,-1000,946,-1000,923L-1000,-923C-1000,-946,-993,-964,-978,-978C-964,-993,-946,-1000,-923,-1000ZM-308,-538C-205,-538,-154,-487,-154,-385C-154,-282,-205,-231,-308,-231C-410,-231,-462,-282,-462,-385C-462,-487,-410,-538,-308,-538ZM-786,877L-906,784L-387,106C-349,56,-298,27,-234,19C-171,11,-115,26,-65,62L235,305C253,318,272,323,292,321C312,318,329,309,344,293L863,-356L983,-260L464,389C424,439,372,467,309,474C245,480,189,464,139,425L-159,185C-176,172,-195,167,-215,169C-235,172,-252,182,-265,200Z",
  "M-176,-913L-176,-774C-389,-732,-558,-629,-684,-468C-809,-306,-866,-116,-853,101C-830,317,-743,494,-592,634C-441,773,-257,845,-39,851C165,847,341,782,489,657C636,532,729,370,768,169L904,169C861,422,746,624,558,774C370,925,148,994,-108,983C-362,959,-571,858,-736,682C-901,505,-987,289,-994,33C-989,-210,-912,-418,-761,-592C-611,-766,-416,-873,-176,-913ZM97,-851L97,-103L844,-103C823,-306,744,-476,607,-613C470,-750,300,-829,97,-851ZM-39,-921L-39,-987C100,-996,234,-976,362,-929C491,-881,604,-808,703,-709C802,-611,875,-497,922,-368C970,-240,989,-106,981,33L-39,33L-39,-921Z",
  "M-250,1000L-250,-1000L250,-1000L250,1000L-250,1000ZM-1000,1000L-1000,-167L-500,-167L-500,1000L-1000,1000ZM500,1000L500,-500L1000,-500L1000,1000L500,1000Z",
  "M-571,-143L571,-143L571,-786C571,-807,565,-824,551,-837C538,-850,521,-857,500,-857L-500,-857C-521,-857,-538,-850,-551,-837C-565,-824,-571,-807,-571,-786L-571,-143ZM-571,0L-571,786C-571,807,-565,824,-551,837C-538,850,-521,857,-500,857L500,857C521,857,538,850,551,837C565,824,571,807,571,786L571,0L-571,0ZM-500,-1000L500,-1000C561,-999,612,-978,652,-938C692,-897,713,-847,714,-786L714,786C713,847,692,897,652,938C612,978,561,999,500,1000L-500,1000C-561,999,-612,978,-652,938C-692,897,-713,847,-714,786L-714,-786C-713,-847,-692,-897,-652,-938C-612,-978,-561,-999,-500,-1000ZM-429,-500L-286,-500L-286,-286L-429,-286L-429,-500ZM-429,143L-286,143L-286,357L-429,357L-429,143Z",
  "M-500,-500L-500,-1000L500,-1000L500,-500L1000,-500L1000,0L-1000,0L-1000,-500L-500,-500ZM-1000,167L1000,167L1000,1000L-1000,1000L-1000,167ZM-333,-500L333,-500L333,-833L-333,-833L-333,-500Z",
  "M292,-95L292,332L667,332C760,334,839,366,902,430C966,493,998,572,1000,665L-1000,665C-998,572,-966,493,-902,430C-839,366,-760,334,-667,332L-292,332L-292,-95C-380,-161,-441,-244,-474,-345C-507,-446,-507,-549,-473,-654C-439,-759,-379,-842,-294,-905C-209,-967,-111,-999,0,-999C111,-999,209,-967,294,-905C379,-842,439,-759,473,-654C507,-549,507,-446,474,-345C441,-244,380,-161,292,-95ZM-1000,999L-1000,832L1000,832L1000,999L-1000,999Z",
  "M-571,-857L786,-857L429,-286L786,286L-571,286L-571,1000L-786,1000L-786,-1000L-571,-1000L-571,-857Z",
  "M281,41C498,108,671,228,800,401C930,575,997,774,1000,1000L-1000,1000C-997,774,-930,575,-800,401C-671,228,-498,108,-281,41L0,462ZM500,-500C497,-359,448,-241,353,-147C259,-52,141,-3,0,0C-141,-3,-259,-52,-353,-147C-448,-241,-497,-359,-500,-500C-497,-641,-448,-759,-353,-853C-259,-948,-141,-997,0,-1000C141,-997,259,-948,353,-853C448,-759,497,-641,500,-500Z",
  "M458,0C375,2,306,30,251,85C197,139,168,208,167,292C168,375,197,444,251,499C306,553,375,582,458,583L1000,583L1000,1000L-1000,1000L-1000,-417L1000,-417L1000,0L458,0ZM542,417L458,417C424,415,395,402,371,379C348,355,336,326,336,292C336,257,348,228,371,204C395,181,424,168,458,167L542,167C576,168,605,181,629,204C652,228,664,257,664,292C664,326,652,355,629,379C605,402,576,415,542,417ZM333,-1000L667,-583L-333,-583Z",
  "M-357,-71L357,-71C378,-71,395,-65,408,-51C422,-38,429,-21,429,0C429,21,422,38,408,51C395,65,378,71,357,71L-357,71C-378,71,-395,65,-408,51C-422,38,-429,21,-429,0C-429,-21,-422,-38,-408,-51C-395,-65,-378,-71,-357,-71ZM0,857C243,851,445,767,606,606C767,445,851,243,857,0C851,-243,767,-445,606,-606C445,-767,243,-851,0,-857C-243,-851,-445,-767,-606,-606C-767,-445,-851,-243,-857,0C-851,243,-767,445,-606,606C-445,767,-243,851,0,857ZM0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-706C-518,-895,-283,-993,0,-1000C283,-993,518,-895,706,-706C895,-518,993,-283,1000,0C993,283,895,518,706,706C518,895,283,993,0,1000Z",
  "M560,-60C520,-62,487,-75,461,-101C435,-127,423,-160,423,-200C423,-240,435,-273,461,-299C487,-325,520,-337,560,-337C600,-337,633,-324,659,-299C685,-273,697,-240,697,-200C697,-160,685,-127,659,-101C633,-76,600,-62,560,-60ZM0,-60C-40,-62,-73,-75,-99,-101C-125,-127,-137,-160,-137,-200C-137,-240,-125,-273,-99,-299C-73,-325,-40,-337,0,-337C40,-337,73,-324,99,-299C125,-273,137,-240,137,-200C137,-160,125,-127,99,-101C73,-76,40,-62,0,-60ZM-560,-60C-600,-62,-633,-75,-659,-101C-685,-127,-697,-160,-697,-200C-697,-240,-685,-273,-659,-299C-633,-325,-600,-337,-560,-337C-520,-337,-487,-324,-461,-299C-435,-273,-423,-240,-423,-200C-423,-160,-435,-127,-461,-101C-487,-76,-520,-62,-560,-60ZM-960,-1000L-960,600L-480,600L-480,1000L80,600L960,600L960,-1000L-960,-1000Z",
  "M0,-1000C283,-993,518,-895,706,-706C895,-518,993,-283,1000,0C993,283,895,518,706,706C518,895,283,993,0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-706C-518,-895,-283,-993,0,-1000ZM-500,0C-500,24,-492,44,-475,60C-459,77,-439,85,-415,85L415,85C439,85,459,77,476,60C492,44,500,24,500,0C500,-24,492,-44,476,-60C459,-77,439,-85,415,-85L-415,-85C-439,-85,-459,-77,-475,-60C-492,-44,-500,-24,-500,0Z",
  "M-643,-786L-643,786L643,786L643,-786L-643,-786ZM-714,-929L714,-929C735,-929,752,-922,766,-908C779,-895,786,-878,786,-857L786,857C786,878,779,895,766,908C752,922,735,929,714,929L-714,929C-735,929,-752,922,-766,908C-779,895,-786,878,-786,857L-786,-857C-786,-878,-779,-895,-766,-908C-752,-922,-735,-929,-714,-929ZM-1000,786L1000,786L1000,929L-1000,929L-1000,786ZM-429,-643L-143,-643L-143,-429L-429,-429L-429,-643ZM-286,786L286,786L286,643C284,562,256,495,202,441C148,387,80,359,0,357C-80,359,-148,387,-202,441C-256,495,-284,563,-286,643L-286,786ZM0,214C122,217,223,259,304,339C384,420,426,521,429,643L429,929L-429,929L-429,643C-426,521,-384,420,-304,339C-223,259,-122,217,0,214ZM-429,-214L-143,-214L-143,0L-429,0L-429,-214ZM143,-643L429,-643L429,-429L143,-429L143,-643ZM143,-214L429,-214L429,0L143,0L143,-214Z",
  "M500,500L667,500L667,1000L-667,1000L-667,500L-500,500L-500,667L500,667L500,500ZM992,104C997,123,1000,144,1000,167C998,238,974,297,927,344C880,391,821,414,750,414C679,414,620,391,573,344C526,297,502,238,500,167C498,238,474,297,427,344C380,391,321,414,250,414C179,414,120,391,73,344C26,297,2,238,0,167C-2,238,-26,297,-73,344C-120,391,-179,414,-250,414C-321,414,-380,391,-427,344C-474,297,-498,238,-500,167C-502,238,-526,297,-573,344C-620,391,-679,414,-750,414C-821,414,-880,391,-927,344C-974,297,-998,238,-1000,167C-1000,144,-997,123,-992,104L-833,-1000L833,-1000Z",
  "M286,714L-1000,714L-1000,286C-920,284,-852,256,-798,202C-744,148,-716,80,-714,0C-716,-80,-744,-148,-798,-202C-852,-256,-920,-284,-1000,-286L-1000,-714L286,-714L286,-357L429,-357L429,-714L1000,-714L1000,-286C920,-284,852,-256,798,-202C744,-148,716,-80,714,0C716,80,744,148,798,202C852,256,920,284,1000,286L1000,714L429,714L429,357L286,357L286,714ZM286,-214L286,214L429,214L429,-214L286,-214Z",
  "M-424,-923L-424,925C-424,947,-417,965,-403,979C-389,993,-371,1000,-349,1000C-327,1000,-309,993,-295,979C-281,965,-274,947,-274,925L-274,-740L297,-171C313,-156,330,-148,350,-148C369,-148,386,-156,401,-171C416,-187,424,-205,424,-224C424,-244,417,-261,403,-277L-295,-974C-306,-985,-318,-992,-333,-995C-348,-998,-363,-997,-377,-991C-391,-984,-402,-975,-411,-964C-419,-952,-424,-938,-424,-923Z",
  "M-286,-929C-286,-949,-279,-967,-266,-980C-252,-993,-235,-1000,-214,-1000C-193,-1000,-176,-993,-163,-980C-150,-967,-143,-949,-143,-929L-143,828C-143,843,-147,856,-155,867C-163,878,-174,887,-188,893C-201,899,-215,900,-229,897C-243,894,-255,888,-266,877L-929,214C-942,201,-949,184,-949,164C-949,144,-942,127,-929,114C-914,99,-897,92,-878,92C-860,92,-843,99,-828,114L-286,656L-286,-928ZM143,-828C143,-843,147,-856,155,-867C163,-878,174,-887,188,-893C201,-899,215,-900,229,-897C243,-894,255,-888,266,-877L929,-214C942,-201,949,-184,949,-164C949,-144,942,-127,929,-114C914,-99,897,-92,878,-92C860,-92,843,-99,828,-114L286,-656L286,929C286,949,279,967,266,980C252,993,235,1000,214,1000C193,1000,176,993,163,980C150,967,143,949,143,929L143,-828Z",
  "M667,-200L-667,-200L-667,733L667,733L667,-200ZM-867,-333L867,-333L867,-733L-867,-733L-867,-333ZM800,-200L800,800C800,819,794,835,781,848C769,860,753,867,733,867L-733,867C-753,867,-769,860,-781,848C-794,835,-800,819,-800,800L-800,-200L-933,-200C-953,-200,-969,-206,-981,-219C-994,-231,-1000,-247,-1000,-267L-1000,-800C-1000,-819,-994,-835,-981,-848C-969,-860,-953,-867,-933,-867L933,-867C953,-867,969,-860,981,-848C994,-835,1000,-819,1000,-800L1000,-267C1000,-247,994,-231,981,-219C969,-206,953,-200,933,-200L800,-200ZM-200,67L200,67C219,67,235,73,248,85C260,98,267,114,267,133C267,153,260,169,248,181C235,194,219,200,200,200L-200,200C-219,200,-235,194,-248,181C-260,169,-267,153,-267,133C-267,114,-260,98,-248,85C-235,73,-219,67,-200,67Z",
  "M0,857C243,851,445,767,606,606C767,445,851,243,857,0C851,-243,767,-445,606,-606C445,-767,243,-851,0,-857C-243,-851,-445,-767,-606,-606C-767,-445,-851,-243,-857,0C-851,243,-767,445,-606,606C-445,767,-243,851,0,857ZM0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-706C-518,-895,-283,-993,0,-1000C283,-993,518,-895,706,-706C895,-518,993,-283,1000,0C993,283,895,518,706,706C518,895,283,993,0,1000ZM357,-618C269,-228,178,48,83,212C-1,328,-88,360,-179,308C-269,256,-285,164,-225,34C-130,-130,64,-347,357,-618Z",
  "M-15,-851C-56,-849,-90,-835,-117,-809C-144,-782,-158,-749,-159,-709L-159,442L-544,135C-581,105,-622,89,-668,88C-713,86,-755,99,-795,126C-816,143,-829,166,-833,192C-838,219,-832,244,-815,266L-413,800C-399,819,-383,833,-363,843C-343,853,-322,858,-299,858L840,858L840,143C840,112,830,84,812,59C793,34,768,17,737,8L279,-130C233,-145,196,-171,169,-207C141,-243,128,-286,128,-335L128,-709C126,-749,112,-782,85,-809C59,-835,25,-850,-15,-851ZM-355,103L-302,146L-302,-709C-302,-760,-289,-809,-265,-853C-240,-898,-205,-933,-160,-960C-115,-987,-67,-1000,-16,-1000C35,-1000,84,-987,129,-960C174,-933,209,-898,234,-853C258,-809,270,-760,270,-709L270,-335C270,-318,275,-304,284,-291C293,-279,305,-270,321,-266L780,-128C841,-109,889,-75,925,-26C962,23,981,80,982,144L982,858C981,898,967,931,940,958C913,984,880,998,840,1000L-299,1000C-345,1000,-388,990,-427,970C-466,950,-499,922,-526,887L-929,350C-948,324,-962,294,-970,263C-978,231,-979,198,-973,165C-967,131,-956,101,-938,73C-920,46,-897,23,-869,6C-803,-37,-733,-57,-659,-53C-584,-50,-516,-24,-455,23Z",
  "M-714,-857L-714,857L714,857L714,-857L-714,-857ZM-786,-1000L786,-1000C807,-1000,824,-993,837,-980C850,-967,857,-949,857,-929L857,929C857,949,850,967,837,980C824,993,807,1000,786,1000L-786,1000C-807,1000,-824,993,-837,980C-850,967,-857,949,-857,929L-857,-929C-857,-949,-850,-967,-837,-980C-824,-993,-807,-1000,-786,-1000ZM-429,0L429,0L429,143L-429,143L-429,0ZM-429,-429L0,-429L0,-286L-429,-286L-429,-429ZM-429,429L429,429L429,571L-429,571L-429,429Z",
  "M-854,430L-928,430C-949,430,-966,424,-980,410C-993,397,-1000,380,-1000,359L-1000,-717C-1000,-738,-993,-756,-980,-769C-966,-783,-949,-789,-928,-789L363,-789C384,-789,401,-783,415,-769C428,-756,435,-738,435,-717L435,-502L805,-502C823,-502,838,-497,851,-485C864,-474,871,-460,874,-442L995,347C998,370,993,389,979,406C964,422,947,430,926,430L720,430C726,493,716,552,689,606C663,661,624,705,571,739C518,772,460,789,399,789C338,789,281,772,228,739C175,705,135,661,109,606C83,552,73,493,78,430L-213,430C-207,493,-217,552,-243,606C-269,661,-309,705,-362,739C-415,772,-472,789,-534,789C-595,789,-652,772,-705,739C-758,705,-798,661,-824,606C-850,552,-860,493,-854,430ZM-803,287C-771,242,-732,207,-686,182C-640,156,-589,143,-534,143C-478,143,-428,156,-381,182C-335,207,-296,242,-265,287L130,287C170,229,224,187,291,161L291,-646L-857,-646L-857,287L-803,287ZM668,287L841,287L798,0L435,0L435,146C483,152,527,167,567,191C608,214,641,247,668,287ZM776,-144L742,-359L435,-359L435,-144L776,-144ZM399,646C450,644,492,627,526,593C559,559,576,517,576,466C576,415,559,373,526,340C492,306,450,289,399,289C348,289,306,306,272,340C239,373,222,415,222,466C222,517,239,559,272,593C306,627,348,644,399,646ZM-534,646C-483,644,-441,627,-407,593C-373,559,-357,517,-357,466C-357,415,-373,373,-407,340C-441,306,-483,289,-534,289C-584,289,-627,306,-660,340C-694,373,-711,415,-711,466C-711,517,-694,559,-660,593C-627,627,-584,644,-534,646Z",
  "M0,37C127,34,232,-9,315,-93C398,-176,441,-281,444,-407C441,-534,398,-639,315,-722C232,-806,127,-849,0,-852C-127,-849,-232,-806,-315,-722C-398,-639,-441,-534,-444,-407C-441,-281,-398,-176,-315,-93C-232,-9,-127,34,0,37ZM0,185C-168,181,-308,123,-419,12C-530,-100,-588,-239,-593,-407C-588,-576,-530,-715,-419,-826C-308,-937,-168,-995,0,-1000C168,-995,308,-937,419,-826C530,-715,588,-576,593,-407C588,-239,530,-100,419,12C308,123,168,181,0,185ZM741,926L741,704C739,640,718,588,676,546C634,505,582,483,519,481L-519,481C-582,483,-634,505,-676,546C-718,588,-739,640,-741,704L-741,926C-741,948,-748,965,-762,979C-775,993,-793,1000,-815,1000C-836,1000,-854,993,-868,979C-882,965,-889,948,-889,926L-889,704C-886,599,-850,512,-780,442C-711,373,-623,336,-519,333L519,333C623,336,711,373,780,442C850,512,886,599,889,704L889,926C889,948,882,965,868,979C854,993,836,1000,815,1000C793,1000,775,993,762,979C748,965,741,948,741,926Z",
  "M-538,-462C-535,-309,-483,-182,-381,-81C-279,21,-152,74,0,77C152,74,279,21,381,-81C483,-182,535,-309,538,-462C535,-614,483,-741,381,-843C279,-944,152,-997,0,-1000C-152,-997,-279,-944,-381,-843C-483,-741,-535,-614,-538,-462ZM769,1000L-846,1000C-869,1000,-887,993,-901,978C-916,964,-923,946,-923,923L-923,692C-920,583,-882,493,-810,421C-738,349,-647,311,-538,308L538,308C647,311,738,349,810,421C882,493,920,583,923,692L923,923C923,946,916,964,901,978C887,993,869,1000,846,1000L769,1000Z",
  "M571,143L1000,0L1000,714L571,571L571,786C571,807,565,824,551,837C538,850,521,857,500,857L-929,857C-949,857,-967,850,-980,837C-993,824,-1000,807,-1000,786L-1000,-71C-1000,-92,-993,-109,-980,-123C-967,-136,-949,-143,-929,-143L500,-143C521,-143,538,-136,551,-123C565,-109,571,-92,571,-71L571,143ZM-714,571L-714,714L143,714L143,571L-714,571ZM-286,-500C-283,-601,-248,-685,-181,-752C-114,-819,-30,-854,71,-857C173,-854,257,-819,324,-752C391,-685,426,-601,429,-500C426,-399,391,-315,324,-248C257,-181,173,-146,71,-143C-30,-146,-114,-181,-181,-248C-248,-315,-283,-399,-286,-500ZM-143,-500C-143,-461,-133,-426,-114,-393C-95,-360,-68,-334,-35,-315C-1,-295,34,-286,71,-286C109,-286,144,-295,178,-315C213,-334,239,-360,258,-393C276,-426,286,-461,286,-500C284,-561,263,-612,223,-652C183,-692,132,-712,71,-712C10,-712,-40,-692,-80,-652C-121,-612,-141,-561,-143,-500ZM-857,-429C-857,-481,-844,-528,-819,-571C-794,-615,-759,-649,-714,-675C-670,-701,-622,-714,-571,-714C-521,-714,-473,-701,-429,-675C-384,-649,-349,-615,-324,-571C-298,-528,-286,-481,-286,-429C-287,-348,-315,-281,-369,-227C-424,-172,-491,-144,-571,-143C-652,-144,-719,-172,-773,-227C-828,-281,-856,-348,-857,-429ZM-714,-429C-713,-388,-699,-355,-672,-328C-645,-301,-612,-288,-571,-288C-531,-288,-498,-301,-471,-328C-444,-355,-431,-388,-431,-429C-431,-469,-444,-502,-471,-529C-498,-556,-531,-569,-571,-569C-612,-569,-645,-556,-672,-529C-699,-502,-713,-469,-714,-429Z",
  "M0,-1000C283,-993,518,-895,706,-706C895,-518,993,-283,1000,0C993,283,895,518,706,706C518,895,283,993,0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-706C-518,-895,-283,-993,0,-1000ZM0,857C243,851,445,767,606,606C767,445,851,243,857,0C851,-243,767,-445,606,-606C445,-767,243,-851,0,-857C-243,-851,-445,-767,-606,-606C-767,-445,-851,-243,-857,0C-851,243,-767,445,-606,606C-445,767,-243,851,0,857ZM-107,304L350,0L-107,-304L-107,304ZM-83,-460L473,-89C504,-67,520,-37,520,0C520,37,504,67,473,89L-83,460C-100,472,-119,478,-138,479C-158,480,-176,475,-193,466C-210,456,-224,443,-234,426C-245,410,-250,392,-250,371L-250,-370C-250,-391,-245,-410,-234,-426C-224,-443,-210,-456,-193,-465C-176,-475,-158,-479,-138,-479C-119,-478,-100,-472,-83,-460Z",
  "M429,571L429,-571L-857,-571L-857,571L429,571ZM571,-357L1000,-571L1000,571L571,357L571,643C571,664,565,681,551,694C538,708,521,714,500,714L-929,714C-949,714,-967,708,-980,694C-993,681,-1000,664,-1000,643L-1000,-643C-1000,-664,-993,-681,-980,-694C-967,-708,-949,-714,-929,-714L500,-714C521,-714,538,-708,551,-694C565,-681,571,-664,571,-643L571,-357ZM571,-196L571,196L857,339L857,-339ZM-714,-429L-286,-429L-286,-286L-714,-286L-714,-429Z",
  "M704,-87L-913,-87C-938,-87,-959,-79,-976,-63C-992,-46,-1000,-25,-1000,0C-1000,25,-992,46,-976,63C-959,79,-938,87,-913,87L704,87L68,720C52,738,43,759,43,783C43,806,52,827,69,844C87,861,107,870,130,870C154,870,175,861,193,845L976,63C992,44,1000,24,1000,0C1000,-24,992,-44,976,-63L193,-845C175,-861,154,-870,130,-870C107,-870,87,-861,69,-844C52,-827,43,-806,43,-783C43,-759,52,-738,68,-720Z",
  "M0,-1000C283,-993,518,-895,706,-706C895,-518,993,-283,1000,0C993,283,895,518,706,706C518,895,283,993,0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-706C-518,-895,-283,-993,0,-1000ZM0,857C243,851,445,767,606,606C767,445,851,243,857,0C851,-243,767,-445,606,-606C445,-767,243,-851,0,-857C-243,-851,-445,-767,-606,-606C-767,-445,-851,-243,-857,0C-851,243,-767,445,-606,606C-445,767,-243,851,0,857ZM-214,-357C-167,-357,-143,-333,-143,-286L-143,286C-143,333,-167,357,-214,357C-262,357,-286,333,-286,286L-286,-286C-286,-333,-262,-357,-214,-357ZM214,-357C262,-357,286,-333,286,-286L286,286C286,333,262,357,214,357C167,357,143,333,143,286L143,-286C143,-333,167,-357,214,-357Z",
  "M0,538L510,806C516,808,521,807,525,804C530,801,531,797,530,791L434,223L845,-180C850,-185,851,-189,850,-195C848,-200,845,-203,839,-205L268,-288L13,-804C10,-810,6,-813,0,-813C-6,-813,-11,-810,-14,-804L-269,-288L-839,-205C-845,-203,-849,-200,-850,-195C-852,-189,-850,-185,-846,-180L-434,223L-533,791C-533,797,-530,801,-526,804C-521,807,-516,808,-510,806ZM-443,932C-471,947,-500,953,-529,951C-558,948,-585,938,-610,921C-634,903,-652,880,-663,852C-675,825,-678,796,-674,766L-588,272L-946,-77C-969,-98,-983,-123,-990,-152C-997,-181,-995,-210,-985,-239C-976,-268,-960,-292,-937,-311C-915,-330,-889,-341,-859,-346L-362,-417L-141,-867C-128,-895,-108,-917,-83,-932C-57,-946,-30,-954,0,-954C30,-954,57,-947,83,-932C108,-917,128,-895,141,-867L362,-417L859,-346C889,-341,915,-330,938,-311C962,-292,978,-268,987,-239C996,-210,997,-181,990,-152C983,-123,969,-98,946,-77L588,272L673,766C678,796,675,825,663,852C652,880,634,903,610,921C585,938,558,948,529,951C500,953,471,947,443,934L0,699Z",
  "M-71,857L-71,424C-189,408,-291,362,-377,286C-464,210,-522,115,-554,0L-627,0C-675,0,-717,-14,-754,-41C-792,-69,-818,-106,-833,-152L-933,-493C-942,-520,-944,-547,-939,-573C-933,-599,-923,-623,-906,-645C-890,-667,-870,-685,-846,-696C-822,-708,-797,-714,-770,-714L-571,-714L-571,-929C-571,-949,-565,-967,-551,-980C-538,-993,-521,-1000,-500,-1000L500,-1000C521,-1000,538,-993,551,-980C565,-967,571,-949,571,-929L571,-714L770,-714C797,-714,822,-708,846,-696C870,-685,890,-667,906,-645C923,-623,933,-599,939,-573C944,-546,942,-520,933,-493L830,-152C817,-107,792,-71,754,-42C717,-14,675,0,627,0L554,0C522,115,464,210,377,286C291,362,189,408,71,424L71,857L357,857C378,857,395,864,409,877C422,891,429,908,429,929C429,949,422,967,409,980C395,993,378,1000,357,1000L-357,1000C-378,1000,-395,993,-408,980C-422,967,-429,949,-429,929C-429,908,-422,891,-408,877C-395,864,-378,857,-357,857L-71,857ZM429,-143L429,-857L-429,-857L-429,-143C-426,-21,-384,80,-304,161C-223,241,-122,283,0,286C122,283,223,241,304,161C384,80,426,-21,429,-143ZM571,-143L627,-143C642,-143,656,-147,668,-156C681,-165,690,-178,694,-194L797,-536C800,-545,798,-553,792,-560C786,-568,779,-571,770,-571L571,-571L571,-143ZM-571,-143L-571,-571L-770,-571C-779,-571,-786,-568,-792,-560C-798,-553,-800,-545,-797,-536L-694,-194C-690,-178,-681,-165,-669,-156C-656,-147,-642,-143,-627,-143L-572,-143Z",
  "M286,-429L143,-429L143,-786L-857,-786L-857,786L0,786L0,857C0,878,7,895,20,908C33,922,51,929,71,929L-929,929C-949,929,-967,922,-980,908C-993,895,-1000,878,-1000,857L-1000,-857C-1000,-878,-993,-895,-980,-908C-967,-922,-949,-929,-929,-929L214,-929C235,-929,252,-922,266,-908C279,-895,286,-878,286,-857L286,-429ZM-857,-357L-857,786L857,786L857,-357L-857,-357ZM-929,-500L929,-500C949,-500,967,-493,980,-480C993,-467,1000,-449,1000,-429L1000,857C1000,878,993,895,980,908C967,922,949,929,929,929L-929,929C-949,929,-967,922,-980,908C-993,895,-1000,878,-1000,857L-1000,-429C-1000,-449,-993,-467,-980,-480C-967,-493,-949,-500,-929,-500ZM429,357C388,356,355,342,328,315C301,288,288,254,288,214C288,174,301,141,328,114C355,87,388,74,429,74C469,74,502,87,529,114C556,141,569,174,569,214C569,254,556,288,529,315C502,342,469,356,429,357Z",
  "M0,571C162,567,297,511,404,404C511,297,567,162,571,0C567,-162,511,-297,404,-404C297,-511,162,-567,0,-571C-162,-567,-297,-511,-404,-404C-511,-297,-567,-162,-571,0C-567,162,-511,297,-404,404C-297,511,-162,567,0,571ZM0,714C-202,710,-371,640,-506,506C-640,371,-710,202,-714,0C-710,-202,-640,-371,-506,-506C-371,-640,-202,-710,0,-714C202,-710,371,-640,506,-506C640,-371,710,-202,714,0C710,202,640,371,506,506C371,640,202,710,0,714ZM-71,-357C-51,-357,-33,-350,-20,-337C-7,-324,0,-307,0,-286L0,71C0,92,-7,109,-20,123C-33,136,-51,143,-71,143C-92,143,-109,136,-123,123C-136,109,-143,92,-143,71L-143,-286C-143,-307,-136,-324,-123,-337C-109,-350,-92,-357,-71,-357ZM-71,0L214,0C262,0,286,24,286,71C286,119,262,143,214,143L-71,143C-119,143,-143,119,-143,71C-143,24,-119,0,-71,0ZM214,-571L214,-857L-214,-857L-214,-571L-357,-571L-357,-1000L357,-1000L357,-571L214,-571ZM-214,571L-214,857L214,857L214,571L357,571L357,1000L-357,1000L-357,571L-214,571Z",
  "M-857,-1000C-810,-1000,-786,-976,-786,-929L-786,929C-786,976,-810,1000,-857,1000C-905,1000,-929,976,-929,929L-929,-929C-929,-976,-905,-1000,-857,-1000ZM71,-208L357,-234L357,-766L71,-792L71,-208ZM-71,-196L-71,-804L-500,-844L-500,-786L-643,-786L-643,-1000L734,-875C791,-869,837,-846,873,-806C908,-766,927,-717,929,-661L929,-339C927,-283,909,-234,873,-194C837,-154,791,-131,734,-125L-643,0L-643,-643L-500,-643L-500,-156ZM500,-248L721,-268C740,-269,756,-277,768,-290C780,-304,786,-320,786,-339L786,-661C786,-680,780,-697,768,-710C756,-723,740,-731,721,-732L500,-752L500,-248Z",
  "M0,-687C315,-659,560,-544,734,-344C909,-143,997,-29,1000,0C997,29,909,143,734,344C560,544,315,659,0,687C-315,659,-560,544,-734,344C-909,143,-997,29,-1000,0C-997,-29,-909,-143,-734,-344C-560,-544,-315,-659,0,-687ZM0,-562C-221,-548,-406,-474,-553,-339C-700,-204,-800,-91,-854,0C-800,91,-700,204,-553,339C-406,474,-221,548,0,562C221,548,406,474,553,339C700,204,800,91,854,0C800,-91,700,-204,553,-339C406,-474,221,-548,0,-562ZM0,-438C124,-435,227,-392,310,-310C392,-227,435,-124,438,0C435,124,392,227,310,310C227,392,124,435,0,438C-124,435,-227,392,-310,310C-392,227,-435,124,-438,0C-435,-124,-392,-227,-310,-310C-227,-392,-124,-435,0,-438ZM0,-313C-89,-310,-162,-279,-221,-221C-279,-162,-310,-89,-313,0C-310,89,-279,162,-221,221C-162,279,-89,310,0,313C89,310,162,279,221,221C279,162,310,89,313,0C310,-89,279,-162,221,-221C162,-279,89,-310,0,-313Z",
  "M422,223L313,629L161,589L293,93L156,-44L-238,352L-353,238L43,-156L-96,-295L-589,-161L-632,-315L-226,-425L-574,-773C-735,-576,-811,-357,-801,-116C-791,125,-698,337,-522,522C-338,698,-125,791,116,801C356,811,576,735,773,574ZM1000,574C859,733,691,844,496,907C301,969,100,976,-106,928C-312,876,-487,778,-633,633C-778,487,-876,312,-928,106C-976,-100,-969,-301,-907,-496C-844,-691,-733,-859,-574,-1000Z",
  "M423,-415L-349,65C-335,109,-331,155,-336,201L379,469C429,401,492,357,570,338C647,320,723,330,798,369C873,408,925,465,953,539C981,613,980,690,951,769C922,848,873,906,802,944C731,981,655,990,573,971C492,951,427,909,381,844C334,779,315,705,323,619L-392,351C-433,409,-485,450,-548,473C-611,495,-676,498,-743,480C-811,462,-866,428,-909,377C-953,326,-978,266,-985,197C-992,128,-979,64,-946,5C-914,-54,-866,-98,-803,-128C-740,-157,-676,-168,-610,-158C-545,-149,-487,-121,-435,-73L336,-553C312,-635,316,-712,349,-786C381,-859,436,-913,512,-948C589,-983,665,-989,741,-966C817,-943,877,-895,922,-824C967,-752,984,-677,971,-599C958,-521,919,-455,853,-401C788,-347,715,-322,635,-326C555,-329,484,-359,423,-415Z",
  "M-692,-846C-736,-845,-772,-829,-800,-800C-829,-772,-845,-736,-846,-692L-846,692C-845,736,-829,772,-800,800C-772,829,-736,845,-692,846L692,846C736,845,772,829,800,800C829,772,845,736,846,692L846,-692C845,-736,829,-772,800,-800C772,-829,736,-845,692,-846L-692,-846ZM-692,-1000L692,-1000C779,-998,851,-968,910,-910C968,-851,998,-779,1000,-692L1000,692C998,779,968,851,910,910C851,968,779,998,692,1000L-692,1000C-779,998,-851,968,-910,910C-968,851,-998,779,-1000,692L-1000,-692C-998,-779,-968,-851,-910,-910C-851,-968,-779,-998,-692,-1000ZM-308,-231C-264,-232,-228,-248,-200,-276C-171,-305,-156,-341,-156,-385C-156,-428,-171,-464,-200,-493C-228,-522,-265,-536,-308,-536C-351,-536,-387,-522,-416,-493C-445,-464,-459,-428,-459,-385C-459,-341,-445,-305,-416,-276C-387,-248,-351,-232,-308,-231ZM-308,-77C-394,-79,-467,-109,-525,-167C-584,-226,-614,-298,-615,-385C-614,-471,-584,-544,-525,-602C-467,-661,-394,-691,-308,-692C-221,-691,-149,-661,-90,-602C-32,-544,-2,-471,0,-385C-2,-298,-32,-226,-90,-167C-149,-109,-221,-79,-308,-77ZM-77,-462L538,-462C590,-462,615,-436,615,-385C615,-333,590,-308,538,-308L-77,-308C-128,-308,-154,-333,-154,-385C-154,-436,-128,-462,-77,-462ZM308,538C351,537,387,522,416,493C445,464,459,428,459,385C459,341,445,305,416,276C387,248,351,233,308,233C265,233,228,248,200,276C171,305,156,341,156,385C156,428,171,464,200,493C228,522,264,537,308,538ZM308,692C221,691,149,661,90,602C32,544,2,471,0,385C2,298,32,226,90,167C149,109,221,79,308,77C394,79,467,109,525,167C584,226,614,298,615,385C614,471,584,544,525,602C467,661,394,691,308,692ZM-538,308L77,308C128,308,154,333,154,385C154,436,128,462,77,462L-538,462C-590,462,-615,436,-615,385C-615,333,-590,308,-538,308Z",
  "M692,588L979,876C993,891,1000,908,1000,927C1000,947,993,963,978,978C963,993,947,1000,927,1000C908,1000,891,993,876,979L588,692C384,859,158,935,-91,921C-339,906,-555,804,-738,616C-912,418,-998,194,-993,-54C-988,-303,-895,-522,-712,-712C-522,-895,-303,-988,-54,-993C195,-998,418,-913,616,-738C804,-555,906,-339,921,-91C935,158,859,384,692,588ZM-36,774C195,768,386,689,537,537C689,385,768,194,774,-36C768,-266,689,-457,537,-609C385,-761,194,-840,-36,-846C-266,-840,-457,-761,-609,-609C-760,-457,-839,-266,-846,-36C-840,194,-760,385,-609,537C-457,689,-266,768,-36,774ZM-109,-109L-109,-330C-109,-352,-102,-369,-89,-383C-75,-397,-57,-404,-36,-404C-14,-404,4,-397,17,-383C31,-369,38,-352,38,-330L38,-109L259,-109C280,-109,298,-102,312,-89C326,-75,333,-57,333,-36C333,-14,326,3,312,17C298,31,280,38,259,38L38,38L38,259C38,280,31,298,17,312C4,326,-14,333,-36,333C-57,333,-75,326,-89,312C-102,298,-109,280,-109,259L-109,38L-330,38C-352,38,-369,31,-383,17C-397,3,-404,-14,-404,-36C-404,-57,-397,-75,-383,-89C-369,-102,-352,-109,-330,-109L-109,-109Z",
  "M481,667L481,-815L-852,-815L-852,667C-850,708,-836,743,-808,771C-780,799,-745,813,-704,815L333,815C375,813,410,799,437,771C465,743,480,708,481,667ZM630,-593L778,-593C840,-591,892,-569,934,-528C976,-486,998,-434,1000,-370L1000,148C998,211,976,264,934,306C892,347,839,369,778,370L630,370L630,667C628,750,599,820,543,876C486,932,417,961,333,963L-704,963C-787,961,-857,932,-913,876C-969,820,-998,750,-1000,667L-1000,-889C-1000,-911,-993,-928,-979,-942C-965,-956,-948,-963,-926,-963L556,-963C577,-963,595,-956,609,-942C623,-928,630,-911,630,-889L630,-593ZM630,-444L630,222L778,222C798,222,815,215,829,201C843,188,850,170,852,148L852,-370C850,-392,843,-410,829,-424C815,-438,798,-444,778,-444L630,-444Z",
  "M0,-1000C283,-993,518,-895,707,-707C895,-518,993,-283,1000,0C993,283,895,518,707,706C518,895,283,993,0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-707C-518,-895,-283,-993,0,-1000ZM0,-571C-39,-571,-71,-557,-96,-529C-121,-501,-132,-467,-130,-429L-78,143C-75,164,-67,180,-52,193C-38,206,-21,212,0,212C21,212,38,206,52,193C66,180,75,164,78,143L129,-429C132,-467,121,-501,96,-529C71,-557,39,-571,0,-571ZM0,571C33,570,60,559,82,538C103,517,114,490,114,458C114,425,103,398,82,376C60,354,33,344,0,344C-33,344,-60,355,-81,376C-103,398,-114,425,-114,458C-114,490,-103,517,-81,538C-60,559,-33,570,0,571Z",
  "M0,571C162,567,297,511,404,404C511,297,567,162,571,0C567,-162,511,-297,404,-404C297,-511,162,-567,0,-571C-162,-567,-297,-511,-404,-404C-511,-297,-567,-162,-571,0C-567,162,-511,297,-404,404C-297,511,-162,567,0,571ZM0,714C-202,710,-371,640,-506,506C-640,371,-710,202,-714,0C-710,-202,-640,-371,-506,-506C-371,-640,-202,-710,0,-714C202,-710,371,-640,506,-506C640,-371,710,-202,714,0C710,202,640,371,506,506C371,640,202,710,0,714ZM214,-571L214,-857L-214,-857L-214,-571L-357,-571L-357,-1000L357,-1000L357,-571L214,-571ZM-214,571L-214,857L214,857L214,571L357,571L357,1000L-357,1000L-357,571L-214,571ZM0,-286C-21,-286,-38,-292,-51,-306C-65,-319,-71,-336,-71,-357C-71,-378,-65,-395,-51,-408C-38,-422,-21,-429,0,-429C21,-429,38,-422,51,-408C65,-395,71,-378,71,-357C71,-336,65,-319,51,-306C38,-292,21,-286,0,-286ZM0,429C-21,429,-38,422,-51,408C-65,395,-71,378,-71,357C-71,336,-65,319,-51,306C-38,292,-21,286,0,286C21,286,38,292,51,306C65,319,71,336,71,357C71,378,65,395,51,408C38,422,21,429,0,429ZM-286,0C-286,21,-292,38,-306,51C-319,65,-336,71,-357,71C-378,71,-395,65,-408,51C-422,38,-429,21,-429,0C-429,-21,-422,-38,-408,-51C-395,-65,-378,-71,-357,-71C-336,-71,-319,-65,-306,-51C-292,-38,-286,-21,-286,0ZM429,0C429,21,422,38,408,51C395,65,378,71,357,71C336,71,319,65,306,51C292,38,286,21,286,0C286,-21,292,-38,306,-51C319,-65,336,-71,357,-71C378,-71,395,-65,408,-51C422,-38,429,-21,429,0ZM-201,-201C-222,-183,-245,-177,-271,-184C-297,-191,-314,-208,-321,-234C-329,-261,-323,-284,-304,-304C-289,-317,-272,-324,-253,-324C-235,-324,-218,-317,-204,-302C-190,-288,-183,-272,-182,-252C-181,-233,-187,-216,-201,-201ZM304,304C284,323,261,329,234,321C208,314,191,297,184,271C177,245,183,222,201,201C216,188,233,181,252,182C272,183,288,190,302,204C317,218,324,235,324,253C324,272,317,289,304,304ZM-201,201C-183,222,-177,245,-184,271C-191,297,-208,314,-234,321C-261,329,-284,323,-304,304C-317,289,-324,272,-324,253C-324,235,-317,218,-302,204C-288,190,-272,183,-252,182C-233,181,-216,187,-201,201ZM304,-304C321,-283,327,-259,320,-233C314,-207,297,-191,271,-184C245,-177,222,-183,201,-201C187,-216,181,-233,182,-252C183,-272,190,-288,204,-302C218,-317,235,-324,253,-324C272,-324,289,-317,304,-304Z",
  "M250,-1000L741,-717L646,-551C679,-512,708,-470,735,-425C761,-379,783,-332,801,-283L991,-283L991,283L801,283C766,382,714,471,646,551L741,717L250,1000L155,834C52,853,-52,853,-155,834L-250,1000L-741,717L-646,551C-680,511,-710,469,-736,424C-761,379,-783,332,-801,283L-991,283L-991,-283L-801,-283C-766,-382,-714,-471,-646,-551L-741,-717L-250,-1000L-155,-834C-52,-853,52,-853,155,-834ZM303,-808L277,-763L228,-677L128,-695C43,-711,-43,-711,-128,-695L-228,-677L-303,-808L-547,-666L-474,-535L-538,-460C-594,-394,-637,-319,-666,-237L-699,-142L-850,-142L-850,142L-701,142L-666,237C-651,280,-634,319,-613,354C-592,389,-567,425,-538,460L-474,536L-547,666L-303,808L-228,677L-128,695C-43,711,43,711,128,695L228,677L303,808L547,666L474,536L538,460C594,392,637,318,666,237L699,142L850,142L850,-142L701,-142L666,-237C653,-277,635,-315,613,-353C591,-390,566,-426,538,-460L474,-535L547,-666ZM0,-496C140,-493,257,-444,351,-351C444,-257,493,-140,496,0C493,140,444,257,351,351C257,444,140,493,0,496C-140,493,-257,444,-351,351C-444,257,-493,140,-496,0C-493,-140,-444,-257,-351,-351C-257,-444,-140,-493,0,-496ZM0,-354C-100,-351,-184,-316,-250,-250C-316,-184,-351,-100,-354,0C-351,100,-316,184,-250,250C-184,316,-100,351,0,354C100,351,184,316,250,250C316,184,351,100,354,0C351,-100,316,-184,250,-250C184,-316,100,-351,0,-354Z",
  "M692,588L979,876C993,891,1000,908,1000,927C1000,947,993,963,978,978C963,993,947,1000,927,1000C908,1000,891,993,876,979L588,692C384,859,158,935,-91,921C-339,906,-555,804,-738,616C-912,418,-998,194,-993,-54C-988,-303,-895,-522,-712,-712C-522,-895,-303,-988,-54,-993C195,-998,418,-913,616,-738C804,-555,906,-339,921,-91C935,158,859,384,692,588ZM-36,774C195,768,386,689,537,537C689,385,768,194,774,-36C768,-266,689,-457,537,-609C385,-761,194,-840,-36,-846C-266,-840,-457,-761,-609,-609C-760,-457,-839,-266,-846,-36C-840,194,-760,385,-609,537C-457,689,-266,768,-36,774ZM-330,-109L259,-109C280,-109,298,-102,312,-89C326,-75,333,-57,333,-36C333,-14,326,3,312,17C298,31,280,38,259,38L-330,38C-352,38,-369,31,-383,17C-397,3,-404,-14,-404,-36C-404,-57,-397,-75,-383,-89C-369,-102,-352,-109,-330,-109Z",
  "M67,-566C61,-549,54,-530,47,-511C38,-485,21,-470,-6,-465C-32,-460,-54,-467,-73,-487C-91,-507,-96,-530,-87,-555L-85,-562C-158,-544,-219,-509,-267,-457C-315,-405,-346,-342,-358,-269L-398,-39L-442,-6C-508,42,-558,97,-592,160C-627,222,-644,288,-644,357C-639,495,-577,612,-457,707C-337,803,-185,853,0,857C185,853,337,803,457,707C577,612,639,495,643,357C643,288,626,222,592,160C558,97,508,42,442,-6L398,-39L357,-269C344,-345,311,-410,259,-464C207,-517,143,-552,67,-567ZM-22,-716C-4,-750,15,-783,36,-815C88,-890,147,-948,212,-987C230,-996,248,-998,266,-993C284,-989,298,-978,308,-961C319,-944,322,-926,317,-907C313,-889,302,-874,284,-864C239,-835,196,-791,154,-732L132,-698C229,-671,310,-622,375,-550C441,-477,483,-392,501,-294L527,-120C608,-60,671,10,716,92C762,173,785,261,787,356C781,538,704,690,556,811C409,933,223,995,0,1000C-223,996,-409,933,-556,811C-704,690,-781,538,-787,356C-785,261,-762,173,-716,92C-671,10,-608,-60,-527,-120L-501,-294C-478,-413,-423,-511,-336,-589C-249,-666,-144,-709,-22,-716Z",
  "M182,-572C277,-660,385,-704,505,-704C626,-704,733,-660,826,-572C914,-477,959,-369,959,-249C959,-128,914,-21,826,72L76,822C-49,941,-192,1000,-353,1000C-514,1000,-656,941,-781,822C-899,698,-959,555,-959,394C-959,233,-899,90,-781,-34L182,-1000L291,-891L-674,72C-763,165,-807,272,-807,393C-807,514,-763,621,-674,716C-580,804,-472,849,-351,849C-231,849,-124,804,-31,716L720,-34C778,-97,807,-169,807,-250C807,-330,778,-401,720,-463C656,-523,585,-553,504,-553C424,-553,353,-523,291,-463L-405,233C-425,254,-432,278,-425,307C-418,335,-400,353,-372,360C-343,367,-319,360,-298,340L398,-356L504,-250L-192,446C-220,476,-254,497,-294,508C-333,519,-373,519,-413,509C-453,499,-488,479,-516,451C-544,423,-564,388,-574,347C-584,306,-584,266,-573,227C-562,189,-542,155,-514,127Z",
  "M-750,-1000L750,-1000C821,-999,881,-974,927,-927C974,-881,998,-821,1000,-750L1000,750C999,821,974,881,927,927C881,974,821,998,750,1000L-750,1000C-821,999,-881,974,-927,927C-974,881,-998,821,-1000,750L-1000,-750C-999,-821,-974,-881,-927,-927C-881,-974,-821,-998,-750,-1000ZM-413,-612C-586,-494,-692,-339,-733,-147C-774,45,-740,230,-632,408C-513,580,-357,686,-165,727C27,767,211,733,388,623C409,611,428,597,444,583C453,575,458,566,460,556C461,545,459,536,453,527L420,475C403,450,381,435,354,429C326,423,300,428,275,444C148,522,17,546,-119,517C-256,488,-365,412,-449,290C-528,164,-552,32,-523,-104C-494,-240,-419,-351,-297,-438C-199,-499,-94,-526,18,-520C129,-514,231,-475,321,-402C324,-400,327,-397,328,-393C336,-384,338,-374,335,-364C332,-353,326,-345,317,-337L-123,-49C-148,-33,-164,-11,-170,17C-176,44,-171,71,-156,96L-120,150C-113,160,-104,166,-94,168C-83,171,-73,169,-62,163L625,-284C643,-298,648,-316,641,-337L641,-339L607,-400C488,-569,333,-675,141,-715C-51,-756,-236,-722,-413,-612ZM614,-16L475,74C465,81,459,90,456,100C454,111,457,121,464,129L554,268C561,278,570,285,580,287C591,289,600,287,609,279L678,234C708,215,727,189,733,157C740,125,734,95,714,65L670,-4C662,-13,653,-19,643,-21C632,-23,623,-21,614,-16Z",
  "M462,-769L846,-769L846,1000L-846,1000L-846,-769L-462,-769L-462,-615L462,-615L462,-769ZM-481,60L-591,171L-156,606L606,-156L498,-264L-156,387ZM-308,-769L-308,-1000L308,-1000L308,-769L-308,-769Z",
  "M-800,-360L800,-360L960,1000L-960,1000ZM-480,200L-320,200L-320,-120L-480,-120L-480,200ZM320,200L480,200L480,-120L320,-120L320,200ZM-320,-520L-480,-520C-477,-657,-430,-770,-340,-860C-250,-950,-137,-997,0,-1000C137,-997,250,-950,340,-860C430,-770,477,-657,480,-520L320,-520C318,-610,287,-685,226,-746C165,-807,90,-838,0,-840C-90,-838,-165,-807,-226,-746C-287,-685,-318,-610,-320,-520Z",
  "M333,-333L333,333L-333,333L-333,-333L333,-333ZM500,-333L1000,-333L1000,333L500,333L500,-333ZM333,1000L-333,1000L-333,500L333,500L333,1000ZM500,1000L500,500L1000,500L1000,1000L500,1000ZM333,-1000L333,-500L-333,-500L-333,-1000L333,-1000ZM500,-1000L1000,-1000L1000,-500L500,-500L500,-1000ZM-500,-333L-500,333L-1000,333L-1000,-333L-500,-333ZM-500,1000L-1000,1000L-1000,500L-500,500L-500,1000ZM-500,-1000L-500,-500L-1000,-500L-1000,-1000L-500,-1000Z",
  "M1000,-77L455,-77C438,-175,395,-258,326,-326C258,-395,175,-438,77,-455L77,-1000C329,-976,540,-879,710,-710C879,-540,976,-329,1000,-77ZM1000,77C976,329,879,540,710,710C540,879,329,976,77,1000L77,455C175,438,258,395,326,326C395,258,438,175,455,77L1000,77ZM-1000,77L-455,77C-438,175,-395,258,-326,326C-258,395,-175,438,-77,455L-77,1000C-329,976,-540,879,-710,710C-879,540,-976,329,-1000,77ZM-1000,-77C-976,-329,-879,-540,-710,-710C-540,-879,-329,-976,-77,-1000L-77,-455C-175,-438,-258,-395,-326,-326C-395,-258,-438,-175,-455,-77L-1000,-77Z",
  "M-180,962C-210,961,-235,950,-255,930C-275,910,-285,885,-285,855C-285,825,-275,801,-255,781C-235,761,-210,750,-180,750C-151,750,-126,761,-106,781C-86,801,-76,825,-76,855C-76,885,-86,910,-106,930C-126,950,-151,961,-180,962ZM532,962C503,961,478,950,458,930C438,910,428,885,428,855C428,825,438,801,458,781C478,761,503,750,532,750C562,750,587,761,607,781C627,801,637,825,637,855C637,885,627,910,607,930C587,950,562,961,532,962ZM-929,-820C-950,-820,-967,-826,-980,-840C-993,-853,-1000,-870,-1000,-891C-1000,-912,-993,-929,-980,-942C-967,-955,-950,-962,-929,-962L-572,-962C-555,-962,-539,-957,-527,-946C-514,-936,-506,-922,-503,-904L-428,-534L924,-534C947,-534,965,-526,979,-508C993,-490,998,-470,993,-448L780,550C777,567,769,580,756,590C744,601,728,606,710,606L-287,606C-305,606,-320,601,-333,590C-346,580,-353,566,-356,548L-630,-819L-929,-819ZM-229,463L653,463L835,-392L-401,-392Z",
  "M-571,357L-571,643L857,643L857,357L-571,357ZM-643,214L929,214C949,214,967,221,980,234C993,248,1000,265,1000,286L1000,714C1000,735,993,752,980,766C967,779,949,786,929,786L-643,786C-664,786,-681,779,-694,766C-708,752,-714,735,-714,714L-714,286C-714,265,-708,248,-694,234C-681,221,-664,214,-643,214ZM429,357L571,357L571,643L429,643L429,357ZM-571,-786L-429,-786L-429,-71L-571,-71L-571,-786ZM-857,-500L-714,-500L-714,-71L-857,-71L-857,-500ZM-1000,214L-857,214L-857,786L-1000,786L-1000,214Z",
  "M-210,801L-804,207C-821,313,-823,410,-807,498C-791,585,-758,655,-706,705C-655,756,-586,789,-499,805C-412,820,-316,819,-210,801ZM-47,761C47,730,136,688,221,637C306,586,384,525,454,454C525,383,586,306,637,221C689,136,730,47,761,-47L49,-759C-46,-728,-137,-686,-222,-634C-308,-582,-386,-521,-456,-451C-527,-381,-588,-304,-639,-220C-691,-136,-732,-48,-763,44ZM801,-210C819,-316,820,-412,805,-499C789,-586,756,-655,705,-705C655,-756,586,-789,500,-805C414,-820,317,-818,210,-799ZM-808,808C-936,670,-982,468,-946,202C-911,-64,-782,-315,-560,-551C-324,-773,-71,-903,196,-942C464,-981,668,-936,808,-808C936,-668,981,-465,944,-199C907,68,777,319,556,556C319,777,68,907,-199,944C-465,981,-668,936,-808,808ZM201,-304L252,-353C267,-366,284,-373,302,-373C321,-373,337,-366,352,-352C366,-337,373,-321,373,-302C373,-284,366,-267,353,-252L304,-201L404,-100C423,-81,429,-58,422,-32C414,-6,398,10,372,18C346,25,323,19,304,0L201,-100L100,0L201,100C220,120,227,143,220,170C213,196,196,213,170,220C143,226,120,220,100,201L0,100L-100,201L0,303C19,323,25,345,18,372C10,398,-6,414,-32,422C-58,429,-81,423,-100,404L-201,303L-252,353C-271,372,-295,378,-321,372C-348,365,-365,348,-372,321C-378,295,-372,272,-353,252L-303,201L-404,100C-423,81,-429,58,-422,32C-414,6,-398,-10,-372,-18C-345,-25,-323,-19,-303,0L-201,100L-100,0L-201,-100C-220,-120,-226,-143,-220,-170C-213,-196,-196,-213,-170,-220C-143,-227,-120,-220,-100,-201L0,-100L101,-201L0,-304C-13,-318,-20,-335,-20,-354C-20,-372,-13,-389,1,-403C15,-417,32,-424,50,-424C69,-424,86,-417,101,-404Z",
  "M-1000,-231L1000,-1000L692,692L-380,108L846,-846L-570,2ZM-385,1000L-385,272L77,538Z",
  "M278,-925L278,742L-292,171C-313,151,-336,144,-364,151C-391,158,-409,176,-417,204C-424,232,-418,257,-398,277L299,974C310,985,323,992,338,995C353,998,367,997,381,991C396,984,407,975,415,964C424,952,428,938,428,923L428,-925C428,-947,421,-965,407,-979C393,-993,375,-1000,353,-1000C331,-1000,313,-993,299,-979C285,-965,278,-947,278,-925Z",
  "M108,231L435,-96L327,-204L0,123L-327,-204L-435,-96L-108,231L-435,558L-327,666L0,339L327,666L435,558ZM462,-769L846,-769L846,1000L-846,1000L-846,-769L-462,-769L-462,-615L462,-615L462,-769ZM-308,-769L-308,-1000L308,-1000L308,-769L-308,-769Z",
  "M-199,1000L-199,859L225,859L225,1000L-199,1000ZM791,-202C791,-84,766,27,717,130C668,234,598,323,508,397C466,432,431,474,405,522C380,569,367,621,367,677L367,717L-340,717L-340,686C-340,632,-351,580,-372,531C-394,483,-425,442,-466,410C-583,317,-666,203,-716,68C-766,-66,-778,-207,-751,-352C-720,-506,-652,-637,-545,-747C-438,-857,-308,-929,-155,-962C-38,-987,77,-987,190,-960C303,-934,407,-883,499,-808C592,-733,664,-643,715,-538C766,-434,791,-322,791,-202ZM-411,-132C-410,-280,-371,-399,-295,-488C-219,-578,-116,-624,13,-627L13,-768C-159,-764,-296,-703,-397,-586C-498,-469,-550,-317,-553,-132L-411,-132Z",
  "M462,-769L846,-769L846,1000L-846,1000L-846,-769L-462,-769L-462,-615L462,-615L462,-769ZM-538,0L538,0L538,-154L-538,-154L-538,0ZM-538,615L538,615L538,462L-538,462L-538,615ZM-308,-769L-308,-1000L308,-1000L308,-769L-308,-769Z",
  "M563,-547C655,-452,720,-341,757,-214L1000,-214L1000,214L757,214C720,341,655,452,563,547L685,759L315,973L192,761C64,794,-64,794,-192,761L-315,973L-685,759L-563,547C-655,452,-720,341,-757,214L-1000,214L-1000,-214L-757,-214C-720,-341,-655,-452,-563,-547L-685,-759L-315,-973L-192,-761C-64,-794,64,-794,192,-761L315,-973L685,-759ZM429,0C426,-122,384,-223,304,-304C223,-384,122,-426,0,-429C-122,-426,-223,-384,-304,-304C-384,-223,-426,-122,-429,0C-426,122,-384,223,-304,304C-223,384,-122,426,0,429C122,426,223,384,304,304C384,223,426,122,429,0Z",
  "M464,-493L761,-493C781,-493,797,-487,810,-474C823,-462,830,-447,833,-427L877,15L732,15L695,-348L464,-348L464,-130C464,-109,457,-92,444,-78C430,-65,413,-58,392,-58C371,-58,353,-65,340,-78C326,-92,319,-109,319,-130L319,-348L-260,-348L-260,-130C-260,-109,-267,-92,-281,-78C-294,-65,-312,-58,-333,-58C-354,-58,-371,-65,-385,-78C-399,-92,-405,-109,-405,-130L-405,-348L-636,-348L-752,812L29,812L29,957L-834,957C-855,957,-872,949,-887,933C-901,917,-907,899,-904,878L-775,-427C-772,-447,-764,-462,-751,-474C-738,-487,-722,-493,-702,-493L-405,-493L-405,-542C-402,-672,-360,-780,-279,-866C-197,-952,-94,-997,29,-1000C153,-997,256,-952,337,-866C419,-780,461,-672,464,-542L464,-493ZM319,-493L319,-542C318,-632,290,-706,234,-764C179,-823,111,-854,29,-855C-52,-854,-120,-823,-176,-764C-231,-706,-259,-632,-260,-542L-260,-493L319,-493ZM775,586C796,566,820,559,847,566C874,573,891,590,898,617C905,644,898,668,879,687L589,977C574,992,556,1000,537,1000C517,1000,500,992,485,977L195,687C177,668,171,645,178,618C185,592,201,575,228,567C254,560,278,566,299,586L464,753L464,232C464,211,471,194,485,180C498,166,516,160,537,160C558,160,575,166,589,180C602,194,609,211,609,232L609,753Z",
  "M-167,833L-167,667L167,667L167,833L667,833L667,1000L-667,1000L-667,833L-167,833ZM-1000,500L-1000,-1000L1000,-1000L1000,500L-1000,500Z",
  "M-857,-214L857,-214L857,-357C856,-397,842,-431,815,-458C788,-484,754,-498,714,-500L-714,-500C-754,-499,-788,-484,-815,-458C-841,-431,-856,-397,-857,-357L-857,-214ZM-857,-71L-857,643C-856,683,-842,717,-815,743C-788,770,-754,784,-714,786L714,786C754,784,788,770,815,743C841,716,856,683,857,643L857,-71L-857,-71ZM-714,-643L714,-643C795,-641,862,-613,916,-559C971,-505,998,-437,1000,-357L1000,643C999,723,971,791,916,845C862,899,795,927,714,929L-714,929C-795,927,-862,899,-916,845C-971,791,-998,723,-1000,643L-1000,-357C-999,-438,-971,-505,-916,-559C-862,-613,-795,-641,-714,-643ZM-286,-786L-286,-643L286,-643L286,-786L-286,-786ZM-286,-929L286,-929C326,-927,359,-913,386,-886C413,-859,427,-826,429,-786L429,-643C427,-603,413,-569,386,-542C359,-516,326,-502,286,-500L-286,-500C-326,-501,-359,-516,-386,-542C-413,-569,-427,-603,-429,-643L-429,-786C-427,-826,-413,-859,-386,-886C-359,-913,-326,-927,-286,-929Z",
  "M-857,-214L857,-214L857,-357C856,-397,842,-431,815,-458C788,-484,754,-498,714,-500L-714,-500C-754,-499,-788,-484,-815,-458C-841,-431,-856,-397,-857,-357L-857,-214ZM-857,-71L-857,643C-856,683,-842,717,-815,743C-788,770,-754,784,-714,786L-571,786L-571,-71L-857,-71ZM-429,786L429,786L429,-71L-429,-71L-429,786ZM571,786L714,786C754,784,788,770,815,743C841,716,856,683,857,643L857,-71L571,-71L571,786ZM-714,-643L714,-643C795,-641,862,-613,916,-559C971,-505,998,-437,1000,-357L1000,643C999,723,971,791,916,845C862,899,795,927,714,929L-714,929C-795,927,-862,899,-916,845C-971,791,-998,723,-1000,643L-1000,-357C-999,-438,-971,-505,-916,-559C-862,-613,-795,-641,-714,-643ZM-286,-786L-286,-643L286,-643L286,-786L-286,-786ZM-286,-929L286,-929C326,-927,359,-913,386,-886C413,-859,427,-826,429,-786L429,-643C427,-603,413,-569,386,-542C359,-516,326,-502,286,-500L-286,-500C-326,-501,-359,-516,-386,-542C-413,-569,-427,-603,-429,-643L-429,-786C-427,-826,-413,-859,-386,-886C-359,-913,-326,-927,-286,-929Z",
  "M639,-360L648,-349C704,-292,732,-226,732,-151C732,-76,704,-9,648,49L52,646C24,672,-7,693,-41,707C-74,722,-110,729,-148,729C-187,729,-223,722,-256,707C-290,693,-320,672,-346,646L-357,637L-399,877C-405,903,-416,926,-433,946C-450,966,-471,980,-496,988C-521,996,-546,997,-572,990C-598,983,-620,971,-639,954L-954,639C-971,620,-983,598,-990,572C-997,546,-996,521,-988,496C-980,471,-966,450,-946,433C-926,416,-903,405,-877,399L-637,357L-646,346C-672,320,-693,290,-707,256C-722,223,-729,187,-729,148C-729,110,-722,74,-707,41C-693,7,-672,-24,-646,-52L-49,-648C-22,-674,9,-695,43,-710C77,-724,113,-732,151,-732C189,-732,225,-724,259,-710C292,-695,322,-674,349,-648L360,-639L402,-879C407,-905,419,-928,436,-947C452,-966,474,-980,499,-988C525,-996,550,-997,575,-991C600,-985,622,-973,641,-954L954,-639C973,-620,985,-598,991,-573C997,-548,996,-523,988,-497C980,-472,966,-450,947,-433C928,-417,905,-406,879,-402ZM-569,78L415,78L415,83L549,-52C575,-78,589,-110,591,-148L-349,-148L-547,50C-556,58,-563,68,-569,78ZM-569,219C-563,229,-556,239,-547,247L-247,547C-218,575,-185,588,-147,588C-110,588,-77,575,-49,547L278,219L-569,219ZM509,-289L250,-549C220,-577,187,-591,150,-591C112,-591,80,-577,52,-549L-208,-289L509,-289ZM-853,538L-538,853L-485,551C-482,532,-488,516,-502,502C-515,488,-532,482,-551,485ZM540,-855L487,-553C484,-534,490,-518,504,-504C518,-490,534,-484,553,-487L855,-540Z",
  "M-838,313C-890,129,-886,-49,-827,-222C-768,-394,-661,-536,-508,-648C-352,-758,-182,-813,0,-813C182,-813,352,-758,508,-648C661,-536,768,-394,827,-222C886,-49,890,129,838,313L707,313C760,154,764,-3,717,-156C670,-310,579,-437,445,-539C310,-638,162,-688,1,-688C-160,-688,-309,-638,-445,-539C-580,-437,-670,-310,-717,-156C-764,-3,-761,154,-707,312L-838,312ZM-937,437L937,437C979,437,1000,458,1000,500C1000,542,979,562,937,562L-937,562C-979,562,-1000,542,-1000,500C-1000,458,-979,437,-937,437ZM-437,687L437,687C479,687,500,708,500,750C500,792,479,812,437,813L-437,813C-479,813,-500,792,-500,750C-500,708,-479,687,-437,687Z",
  "M-937,437L937,437C956,437,971,443,982,455C994,467,1000,482,1000,500C1000,518,994,533,982,545C971,557,956,562,937,562L-937,562C-956,562,-971,557,-982,545C-994,533,-1000,518,-1000,500C-1000,482,-994,467,-982,455C-971,443,-956,437,-937,437ZM-437,687L437,687C479,687,500,708,500,750C500,792,479,812,437,812L-437,812C-479,812,-500,792,-500,750C-500,708,-479,687,-437,687ZM-687,312C-682,117,-615,-45,-486,-174C-357,-303,-195,-370,0,-375C195,-370,357,-303,486,-174C615,-45,682,117,687,312L562,312C559,154,504,21,397,-85C291,-191,159,-246,0,-250C-159,-246,-291,-191,-397,-85C-504,21,-559,154,-562,312L-687,312ZM0,-812C18,-812,33,-807,45,-795C57,-783,62,-768,63,-750L63,-562C63,-544,57,-529,45,-518C33,-506,18,-500,0,-500C-18,-500,-33,-506,-45,-518C-57,-529,-63,-544,-63,-562L-63,-750C-63,-768,-57,-783,-45,-795C-33,-807,-18,-812,0,-812ZM795,-482C808,-469,814,-455,814,-438C814,-422,808,-408,795,-395L662,-262C645,-245,625,-240,603,-246C580,-253,565,-267,559,-290C552,-313,557,-333,574,-350L707,-482C720,-495,735,-502,751,-502C767,-502,782,-495,795,-482ZM-795,-482C-782,-495,-767,-502,-751,-502C-735,-502,-720,-495,-707,-482L-574,-350C-557,-333,-552,-313,-559,-290C-565,-267,-580,-253,-603,-246C-625,-240,-645,-245,-662,-262L-795,-395C-808,-408,-814,-422,-814,-438C-814,-455,-808,-469,-795,-482Z",
  "M-789,-789L579,-789C610,-789,635,-799,655,-819C674,-839,684,-864,684,-895C684,-925,674,-951,655,-970C635,-990,610,-1000,579,-1000L-895,-1000C-925,-1000,-951,-990,-970,-970C-990,-951,-1000,-925,-1000,-895L-1000,579C-1000,610,-990,635,-970,655C-951,674,-925,684,-895,684C-864,684,-839,674,-819,655C-799,635,-789,610,-789,579L-789,-789ZM-819,-970C-841,-990,-866,-1000,-895,-1000C-923,-1000,-948,-990,-969,-969C-990,-948,-1000,-923,-1000,-895C-1000,-866,-990,-841,-970,-819L819,970C841,990,866,1000,895,1000C923,1000,948,990,969,969C990,948,1000,923,1000,895C1000,866,990,841,970,819Z",
  "M-357,-786L-357,-629C-521,-542,-640,-417,-713,-257C-787,-96,-804,74,-763,254C-717,434,-625,579,-487,689C-348,798,-186,854,0,857C186,854,348,798,487,689C625,579,717,435,763,254C804,74,787,-96,713,-257C639,-417,521,-542,357,-629L357,-786C564,-695,718,-555,819,-365C920,-175,951,31,911,252C862,474,754,653,588,789C422,925,226,996,0,1000C-226,996,-423,925,-589,789C-756,653,-863,475,-911,255C-951,31,-920,-175,-819,-365C-718,-555,-564,-695,-357,-786ZM0,-1000C47,-1000,71,-976,71,-929L71,-214C71,-167,47,-143,0,-143C-48,-143,-72,-167,-72,-214L-72,-929C-72,-976,-48,-1000,0,-1000Z",
  "M185,-857L-429,-857C-551,-854,-652,-812,-732,-732C-812,-652,-854,-551,-857,-429L-857,857L0,857L0,-357C0,-458,17,-552,50,-638C84,-725,129,-798,185,-857ZM500,-1000C641,-996,759,-933,854,-811C948,-690,997,-539,1000,-357C997,-176,948,-24,854,97C759,218,641,281,500,286L143,286L143,1000L-1000,1000L-1000,-429C-996,-591,-940,-725,-833,-833C-725,-940,-591,-996,-429,-1000L500,-1000ZM143,-357L143,143L500,143C597,140,680,92,749,-1C818,-94,854,-213,857,-357C854,-501,818,-620,749,-713C680,-806,597,-854,500,-857C403,-854,320,-806,251,-713C182,-620,146,-501,143,-357ZM500,-143C460,-144,426,-165,400,-205C373,-246,359,-296,359,-357C359,-418,373,-469,400,-509C426,-549,460,-569,500,-569C540,-569,574,-549,600,-509C627,-469,641,-418,641,-357C641,-296,627,-246,600,-205C574,-165,540,-144,500,-143Z",
  "M-357,857L357,857C405,857,429,881,429,929C429,976,405,1000,357,1000L-357,1000C-405,1000,-429,976,-429,929C-429,881,-405,857,-357,857ZM-458,-857L-679,143L679,143L458,-857L-458,-857ZM-513,-1000L513,-1000C531,-1000,547,-995,559,-984C572,-974,580,-961,585,-944L837,199C842,221,837,241,823,259C808,277,790,286,768,286L-768,286C-790,286,-808,277,-823,259C-837,241,-842,221,-837,199L-585,-944C-580,-961,-572,-974,-559,-984C-547,-995,-531,-1000,-513,-1000ZM357,143C405,143,429,167,429,214L429,500C429,548,405,571,357,571C310,571,286,548,286,500L286,214C286,167,310,143,357,143ZM-71,143L71,143L71,1000L-71,1000L-71,143Z",
  "M479,544C580,473,662,385,722,280C783,175,820,61,833,-63L-833,-63C-820,61,-783,175,-722,280C-662,385,-580,473,-479,544L479,544ZM-531,694C-675,601,-787,481,-866,336C-945,190,-985,32,-987,-139C-987,-161,-980,-179,-966,-193C-951,-208,-933,-215,-911,-215L911,-215C933,-215,951,-208,966,-193C980,-179,987,-161,987,-139C985,32,945,190,866,336C787,481,675,601,531,694L531,848C530,891,515,926,486,955C458,983,422,998,380,1000L-380,1000C-422,998,-458,983,-486,955C-515,926,-530,891,-531,848L-531,694ZM-45,-367L-259,-367L344,-969C365,-990,389,-996,418,-989C446,-982,464,-964,471,-936C478,-908,471,-883,451,-862ZM401,-367L97,-367L735,-737C754,-746,774,-748,794,-743C813,-737,828,-725,839,-707C849,-689,852,-670,847,-650C842,-630,830,-615,811,-604ZM-380,696L-380,848L380,848L380,696L-380,696Z",
  "M789,-789L-572,-789C-603,-789,-628,-799,-648,-819C-668,-839,-678,-864,-678,-895C-678,-925,-668,-951,-648,-970C-628,-990,-603,-1000,-572,-1000L895,-1000C925,-1000,951,-990,970,-970C990,-951,1000,-925,1000,-895L1000,579C1000,610,990,635,970,655C951,674,925,684,895,684C864,684,839,674,819,655C799,635,789,610,789,579L789,-789ZM819,-970C841,-990,866,-1000,895,-1000C923,-1000,948,-990,969,-969C990,-948,1000,-923,1000,-895C1000,-866,990,-841,970,-819L-819,970C-841,990,-866,1000,-895,1000C-923,1000,-948,990,-969,969C-990,948,-1000,923,-1000,895C-1000,866,-990,841,-970,819Z",
  "M81,-705L81,921C81,943,74,962,58,977C43,992,24,1000,0,1000C-23,1000,-43,992,-58,977C-73,962,-81,943,-81,921L-81,-705L-677,-72C-691,-55,-710,-47,-733,-47C-757,-47,-776,-56,-792,-73C-807,-90,-815,-111,-815,-134C-815,-157,-806,-178,-790,-196L-57,-976C-42,-992,-23,-1000,0,-1000C23,-1000,42,-992,57,-976L790,-196C806,-178,815,-157,815,-134C815,-111,807,-90,792,-73C776,-56,757,-47,735,-47C712,-47,693,-55,677,-72Z",
  "M-357,-500C-498,-496,-616,-447,-710,-353C-804,-259,-853,-141,-857,0C-853,141,-804,259,-710,353C-616,447,-498,496,-357,500L357,500C498,496,616,447,710,353C804,259,853,141,857,0C853,-141,804,-259,710,-353C616,-447,498,-496,357,-500L-357,-500ZM-357,-643L357,-643C539,-638,690,-575,811,-454C932,-333,995,-182,1000,0C995,182,932,333,811,454C690,575,539,638,357,643L-357,643C-539,638,-690,575,-811,454C-932,333,-995,182,-1000,0C-995,-182,-932,-333,-811,-454C-690,-575,-539,-638,-357,-643ZM-357,214C-318,214,-282,204,-250,185C-218,166,-192,140,-173,107C-153,74,-143,38,-143,0C-143,-38,-153,-74,-173,-107C-192,-140,-218,-166,-250,-185C-282,-204,-318,-214,-357,-214C-417,-212,-467,-191,-508,-151C-548,-110,-569,-60,-571,0C-569,60,-548,110,-508,151C-467,191,-417,212,-357,214ZM-357,357C-458,354,-542,319,-609,252C-676,185,-711,101,-714,0C-711,-101,-676,-185,-609,-252C-542,-319,-458,-354,-357,-357C-256,-354,-172,-319,-105,-252C-38,-185,-3,-101,0,0C-3,101,-38,185,-105,252C-172,319,-256,354,-357,357Z",
  "M71,500L71,786L500,786C521,786,538,792,551,806C565,819,571,836,571,857C571,878,565,895,551,908C538,922,521,929,500,929L-500,929C-521,929,-538,922,-551,908C-565,895,-571,878,-571,857C-571,836,-565,819,-551,806C-538,792,-521,786,-500,786L-71,786L-71,500L-714,500C-795,499,-862,471,-916,416C-971,362,-998,295,-1000,214L-1000,-643C-999,-723,-971,-791,-916,-845C-862,-899,-795,-927,-714,-929L714,-929C795,-927,862,-899,916,-845C971,-791,998,-723,1000,-643L1000,214C999,295,971,362,916,416C862,471,795,498,714,500L71,500ZM-714,-786C-754,-784,-788,-770,-815,-743C-841,-716,-856,-683,-857,-643L-857,214C-856,254,-842,288,-815,315C-788,341,-754,356,-714,357L714,357C754,356,788,342,815,315C841,288,856,254,857,214L857,-643C856,-683,842,-717,815,-743C788,-770,754,-784,714,-786L-714,-786Z",
  "M-634,-128C-655,-128,-672,-121,-685,-108C-698,-95,-705,-78,-705,-57L-705,789C-705,809,-698,826,-685,839C-672,852,-655,859,-634,859L634,859C655,859,672,852,685,839C698,826,705,809,705,789L705,-57C705,-78,698,-95,685,-108C672,-121,655,-128,634,-128L-634,-128ZM-634,-269L634,-269C695,-267,745,-247,784,-207C824,-167,844,-118,846,-57L846,789C844,849,824,899,784,938C745,978,695,999,634,1000L-634,1000C-695,999,-745,978,-784,938C-824,899,-844,849,-846,789L-846,-57C-844,-118,-824,-167,-784,-207C-745,-247,-695,-267,-634,-269ZM0,84C21,84,37,90,51,103C64,117,70,134,70,154L70,577C70,598,64,615,51,628C37,641,21,648,0,648C-21,648,-37,641,-51,628C-64,615,-70,598,-70,577L-70,154C-70,134,-64,117,-51,103C-37,90,-21,84,0,84ZM392,-566C352,-662,289,-733,203,-780C116,-827,22,-841,-79,-824C-181,-803,-263,-755,-326,-680C-389,-604,-421,-514,-423,-410L-423,-269L352,-269L564,-185L564,-128L-564,-128L-564,-410C-561,-548,-518,-667,-435,-769C-352,-870,-242,-935,-106,-965C29,-988,155,-968,270,-905C385,-842,470,-747,524,-619Z",
  "M-786,-643C-807,-643,-824,-636,-837,-623C-850,-609,-857,-592,-857,-571L-857,571C-857,592,-850,609,-837,623C-824,636,-807,643,-786,643L786,643C807,643,824,636,837,623C850,609,857,592,857,571L857,-571C857,-592,850,-609,837,-623C824,-636,807,-643,786,-643L-786,-643ZM-786,-786L786,-786C847,-784,897,-763,938,-723C978,-683,999,-632,1000,-571L1000,571C999,632,978,683,938,723C897,763,847,784,786,786L-786,786C-847,784,-897,763,-938,723C-978,683,-999,632,-1000,571L-1000,-571C-999,-632,-978,-683,-938,-723C-897,-763,-847,-784,-786,-786ZM429,-429C469,-427,502,-413,529,-386C556,-359,569,-326,569,-286C569,-246,556,-212,529,-185C502,-158,469,-145,429,-145C388,-145,355,-158,328,-185C301,-212,288,-246,288,-286C288,-326,301,-359,328,-386C355,-413,388,-427,429,-429ZM-500,-143L71,-143C119,-143,143,-119,143,-71C143,-24,119,0,71,0L-500,0C-548,0,-571,-24,-571,-71C-571,-119,-548,-143,-500,-143ZM-500,143L71,143C119,143,143,167,143,214C143,262,119,286,71,286L-500,286C-548,286,-571,262,-571,214C-571,167,-548,143,-500,143Z",
  "M-429,643C-429,622,-422,605,-409,592C-395,578,-378,571,-357,571C-336,571,-319,578,-306,592C-292,605,-286,622,-286,643C-284,683,-270,717,-243,743C-216,770,-183,783,-143,784C-103,784,-69,770,-42,743C-16,716,-1,683,0,643L0,71L-1000,71C-993,-211,-895,-447,-706,-635C-518,-823,-283,-921,0,-929C283,-921,518,-823,707,-635C895,-447,993,-211,1000,71L143,71L143,643C141,723,113,791,59,845C5,899,-63,927,-143,929C-223,927,-291,899,-345,845C-399,791,-427,723,-429,643ZM846,-71C806,-281,708,-452,554,-583C399,-714,214,-781,0,-786C-214,-781,-399,-714,-554,-583C-708,-452,-806,-281,-846,-71L846,-71Z",
  "M-585,-635C-696,-520,-770,-388,-808,-239C-846,-90,-843,61,-799,214C-755,367,-677,497,-564,602C-451,707,-317,778,-163,813C-8,848,143,842,290,794C438,746,564,663,670,545C497,587,327,584,160,538C-6,492,-153,405,-279,279C-405,153,-492,6,-538,-160C-584,-327,-587,-497,-545,-670ZM-177,177C-10,338,184,423,404,429C623,436,822,365,1000,215C936,459,806,651,612,790C418,930,195,992,-56,975C-307,951,-517,855,-686,686C-855,517,-951,307,-975,56C-992,-195,-930,-418,-790,-612C-651,-806,-459,-936,-215,-1000C-365,-822,-436,-623,-429,-404C-423,-184,-338,10,-177,177Z",
  "M-500,857L500,857C548,857,571,881,571,929C571,976,548,1000,500,1000L-500,1000C-548,1000,-571,976,-571,929C-571,881,-548,857,-500,857ZM643,-214C638,-396,575,-547,454,-668C333,-790,182,-853,0,-857C-182,-853,-333,-790,-454,-668C-575,-547,-638,-396,-643,-214C-643,-82,-590,70,-483,240C-377,410,-216,599,0,806C216,599,377,410,483,240C590,70,643,-82,643,-214ZM0,1000C-524,524,-786,119,-786,-214C-780,-438,-703,-623,-556,-770C-408,-917,-223,-994,0,-1000C223,-994,409,-917,556,-770C703,-623,780,-437,786,-214C786,119,524,524,0,1000ZM71,-286L286,-286C307,-286,324,-279,337,-266C350,-252,357,-235,357,-214C357,-193,350,-176,337,-163C324,-150,307,-143,286,-143L71,-143L71,71C71,92,65,109,51,123C38,136,21,143,0,143C-21,143,-38,136,-51,123C-65,109,-71,92,-71,71L-71,-143L-286,-143C-307,-143,-324,-150,-337,-163C-350,-176,-357,-193,-357,-214C-357,-235,-350,-252,-337,-266C-324,-279,-307,-286,-286,-286L-71,-286L-71,-500C-71,-521,-65,-538,-51,-551C-38,-565,-21,-571,0,-571C21,-571,38,-565,51,-551C65,-538,71,-521,71,-500L71,-286Z",
  "M-71,857L-71,286L-714,286L-714,143L-71,143L-71,-429L-714,-429L-714,857L-71,857ZM71,857L714,857L714,-429L71,-429L71,143L714,143L714,286L71,286L71,857ZM-857,-571L857,-571L857,929C857,949,850,967,837,980C824,993,807,1000,786,1000L-786,1000C-807,1000,-824,993,-837,980C-850,967,-857,949,-857,929L-857,-571ZM-929,-571L929,-571C976,-571,1000,-548,1000,-500C1000,-452,976,-429,929,-429L-929,-429C-976,-429,-1000,-452,-1000,-500C-1000,-548,-976,-571,-929,-571ZM-214,-571C-174,-573,-141,-587,-114,-614C-87,-641,-74,-674,-74,-714C-74,-754,-87,-788,-114,-815C-141,-842,-174,-855,-214,-855C-254,-855,-288,-842,-315,-815C-342,-788,-355,-754,-355,-714C-355,-674,-341,-641,-315,-614C-288,-587,-254,-573,-214,-571ZM-214,-429C-295,-430,-362,-458,-416,-512C-471,-567,-498,-634,-500,-714C-499,-795,-471,-862,-416,-916C-362,-971,-295,-998,-214,-1000C-134,-999,-67,-971,-12,-916C42,-862,70,-795,71,-714C70,-634,42,-567,-12,-512C-67,-458,-134,-430,-214,-429ZM214,-571C254,-573,288,-587,315,-614C341,-641,355,-674,355,-714C355,-754,342,-788,315,-815C288,-842,254,-855,214,-855C174,-855,141,-842,114,-815C87,-788,74,-754,74,-714C74,-674,87,-641,114,-614C141,-587,174,-573,214,-571ZM214,-429C134,-430,67,-458,12,-512C-42,-567,-70,-634,-71,-714C-70,-795,-42,-862,12,-916C67,-971,134,-998,214,-1000C295,-999,362,-971,416,-916C471,-862,498,-795,500,-714C499,-634,471,-567,416,-512C362,-458,295,-430,214,-429Z",
  "M0,857C243,851,445,767,606,606C767,445,851,243,857,0C851,-243,767,-445,606,-606C445,-767,243,-851,0,-857C-243,-851,-445,-767,-606,-606C-767,-445,-851,-243,-857,0C-851,243,-767,445,-606,606C-445,767,-243,851,0,857ZM0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-706C-518,-895,-283,-993,0,-1000C283,-993,518,-895,706,-706C895,-518,993,-283,1000,0C993,283,895,518,706,706C518,895,283,993,0,1000ZM0,-929C21,-929,38,-922,51,-908C65,-895,71,-878,71,-857L71,-429C71,-408,65,-391,51,-377C38,-364,21,-357,0,-357C-21,-357,-38,-364,-51,-377C-65,-391,-71,-408,-71,-429L-71,-857C-71,-878,-65,-895,-51,-908C-38,-922,-21,-929,0,-929ZM0,357C21,357,38,364,51,377C65,391,71,408,71,429L71,857C71,878,65,895,51,908C38,922,21,929,0,929C-21,929,-38,922,-51,908C-65,895,-71,878,-71,857L-71,429C-71,408,-65,391,-51,377C-38,364,-21,357,0,357ZM-929,0C-929,-21,-922,-38,-908,-51C-895,-65,-878,-71,-857,-71L-429,-71C-408,-71,-391,-65,-377,-51C-364,-38,-357,-21,-357,0C-357,21,-364,38,-377,51C-391,65,-408,71,-429,71L-857,71C-878,71,-895,65,-908,51C-922,38,-929,21,-929,0ZM357,0C357,-21,364,-38,377,-51C391,-65,408,-71,429,-71L857,-71C878,-71,895,-65,908,-51C922,-38,929,-21,929,0C929,21,922,38,908,51C895,65,878,71,857,71L429,71C408,71,391,65,377,51C364,38,357,21,357,0Z",
  "M-626,-218L130,-116L225,619L784,-782ZM-931,-106C-949,-108,-963,-115,-975,-127C-987,-139,-994,-154,-996,-172C-999,-190,-996,-206,-987,-220C-978,-235,-966,-245,-950,-251L893,-988C908,-994,922,-996,936,-993C950,-990,963,-983,974,-972C985,-960,992,-948,995,-934C998,-919,997,-905,990,-891L256,948C250,964,239,976,224,985C209,993,193,996,175,994C158,992,143,985,131,973C120,961,113,946,111,929L-5,19Z",
  "M-826,-87L913,-87C938,-87,959,-79,976,-63C992,-46,1000,-25,1000,0C1000,25,992,46,976,63C959,79,938,87,913,87L-826,87C-851,87,-872,79,-889,63C-905,46,-913,25,-913,0C-913,-25,-905,-46,-889,-63C-872,-79,-851,-87,-826,-87ZM-791,0L-68,720C-52,738,-43,759,-43,783C-43,806,-52,827,-69,844C-87,861,-107,870,-130,870C-154,870,-175,861,-193,845L-976,63C-992,44,-1000,24,-1000,0C-1000,-24,-992,-44,-976,-63L-193,-845C-175,-861,-154,-870,-130,-870C-107,-870,-87,-861,-69,-844C-52,-827,-43,-806,-43,-783C-43,-759,-52,-738,-68,-720Z",
  "M-624,-391L-624,861L624,861L624,-391L89,-829C61,-851,32,-861,0,-861C-32,-861,-61,-851,-89,-829ZM176,-937L737,-478C754,-463,763,-445,763,-424L763,931C763,951,756,968,743,981C730,994,714,1000,693,1000L-693,1000C-714,1000,-730,994,-743,981C-756,968,-763,951,-763,931L-763,-424C-763,-445,-754,-463,-737,-478L-176,-937C-122,-979,-64,-1000,0,-1000C64,-1000,122,-979,176,-937ZM0,-109C39,-111,72,-125,97,-151C123,-177,136,-209,137,-248C137,-287,124,-320,97,-346C71,-372,39,-385,0,-385C-39,-385,-71,-372,-97,-346C-124,-320,-137,-287,-137,-248C-136,-209,-123,-177,-97,-151C-72,-125,-39,-111,0,-109ZM0,29C-78,28,-143,1,-196,-52C-249,-105,-276,-170,-277,-248C-276,-326,-249,-392,-196,-444C-143,-497,-78,-524,0,-526C78,-524,143,-497,196,-444C249,-391,276,-326,277,-248C276,-170,249,-105,196,-52C143,1,78,28,0,29Z",
  "M390,-979L-503,-59C-519,-43,-527,-24,-527,-1C-527,21,-519,41,-503,59L390,978C406,993,425,1000,446,1000C468,1000,487,992,503,976C519,960,527,941,527,919C527,898,519,879,503,863L-338,0L503,-863C519,-879,527,-898,527,-919C527,-941,519,-960,503,-976C487,-992,468,-1000,446,-1000C425,-1000,406,-993,390,-978Z",
  "M230,-610L230,-763C230,-785,223,-804,208,-818C194,-832,176,-839,153,-839C131,-839,113,-832,98,-818C84,-804,77,-785,77,-763L77,42L141,42C173,42,203,32,230,13L230,-610ZM472,-226C440,-226,410,-217,383,-198L383,-226L537,-226L537,-610C537,-632,529,-650,515,-665C501,-679,482,-686,460,-686C438,-686,419,-679,405,-665C391,-650,383,-632,383,-610L383,-226L472,-226ZM652,-226C685,-226,717,-219,746,-205C776,-190,801,-170,823,-145C844,-119,859,-91,867,-60C875,-29,876,4,870,37L726,813C715,868,688,912,647,946C605,980,556,998,498,1000L-498,1000C-556,998,-605,980,-647,946C-688,912,-715,867,-726,813L-870,37C-876,4,-875,-29,-867,-60C-859,-91,-844,-119,-823,-145C-801,-170,-776,-190,-746,-205C-717,-219,-685,-226,-652,-226L-690,-226L-690,-610C-688,-669,-669,-719,-632,-762C-596,-804,-548,-829,-490,-836C-432,-843,-379,-832,-333,-801C-287,-771,-255,-727,-237,-669C-185,-690,-131,-692,-77,-674L-77,-763C-75,-822,-56,-873,-19,-915C18,-957,65,-982,123,-989C182,-996,234,-985,280,-954C326,-924,358,-880,376,-823C411,-837,447,-842,485,-838C522,-834,557,-822,589,-800C621,-778,646,-751,663,-717C681,-684,690,-648,690,-610L690,-226L651,-226ZM381,80C351,117,315,145,273,165C232,185,188,195,141,195L-141,195C-188,195,-231,185,-273,165C-315,145,-350,117,-381,80L-383,80L-383,75C-393,64,-401,52,-407,40L-472,-73L-652,-73C-672,-73,-690,-65,-704,-48C-719,-31,-723,-12,-719,8L-649,387L649,387L719,8C723,-12,719,-31,704,-48C690,-65,672,-73,651,-73L472,-73L407,40C399,52,391,64,383,75L383,80L381,80ZM-77,-456C-77,-479,-84,-497,-98,-511C-112,-526,-131,-533,-153,-533C-176,-533,-194,-526,-208,-511C-223,-497,-230,-479,-230,-456L-230,13C-203,32,-173,42,-141,42L-77,42L-77,-456ZM-383,-226L-383,-610C-383,-632,-390,-650,-405,-665C-419,-679,-437,-686,-460,-686C-482,-686,-501,-679,-515,-665C-529,-650,-536,-632,-536,-610L-536,-226L-472,-226C-440,-226,-410,-217,-383,-198L-383,-226ZM-620,540L-575,785C-570,802,-561,817,-547,829C-534,841,-517,847,-498,847L498,847C517,847,534,841,547,829C561,817,570,802,575,785L620,540L-620,540Z",
  "M833,-500L833,-833L500,-833L500,0C497,142,448,260,354,354C260,448,142,497,0,500C-142,497,-260,448,-354,354C-448,260,-497,142,-500,0L-500,-833L-833,-833L-833,-500L-500,-500L-500,-333L-833,-333L-833,0C-828,236,-747,433,-590,590C-433,747,-236,828,0,833C236,828,433,747,590,590C747,433,828,236,833,0L833,-333L500,-333L500,-500L833,-500ZM333,0L333,-1000L1000,-1000L1000,0C993,283,895,519,707,707C519,895,283,993,0,1000C-283,993,-519,895,-707,707C-895,519,-993,283,-1000,0L-1000,-1000L-333,-1000L-333,0C-332,94,-299,172,-236,236C-172,299,-94,332,0,333C94,332,172,299,236,236C299,172,332,94,333,0Z",
  "M-503,-978C-519,-960,-527,-941,-527,-919C-527,-897,-519,-879,-503,-862L338,0L-503,863C-519,879,-527,898,-527,919C-527,941,-519,960,-503,976C-487,992,-468,1000,-446,1000C-425,1000,-406,993,-390,978L503,59C519,43,527,23,527,0C527,-23,519,-43,503,-59L-390,-978C-406,-993,-425,-1000,-446,-1000C-468,-1000,-487,-993,-503,-978Z",
  "M0,429C122,426,223,384,304,304C384,223,426,122,429,0C426,-122,384,-223,304,-304C223,-384,122,-426,0,-429C-122,-426,-223,-384,-304,-304C-384,-223,-426,-122,-429,0C-426,122,-384,223,-304,304C-223,384,-122,426,0,429ZM0,571C-162,567,-297,511,-404,404C-511,297,-567,162,-571,0C-567,-162,-511,-297,-404,-404C-297,-511,-162,-567,0,-571C162,-567,297,-511,404,-404C511,-297,567,-162,571,0C567,162,511,297,404,404C297,511,162,567,0,571ZM0,-1000C21,-1000,38,-993,51,-980C65,-967,71,-949,71,-929L71,-786C71,-765,65,-748,51,-734C38,-721,21,-714,0,-714C-21,-714,-38,-721,-51,-734C-65,-748,-71,-765,-71,-786L-71,-929C-71,-949,-65,-967,-51,-980C-38,-993,-21,-1000,0,-1000ZM0,714C21,714,38,721,51,734C65,748,71,765,71,786L71,929C71,949,65,967,51,980C38,993,21,1000,0,1000C-21,1000,-38,993,-51,980C-65,967,-71,949,-71,929L-71,786C-71,765,-65,748,-51,734C-38,721,-21,714,0,714ZM-708,-708C-693,-721,-676,-728,-656,-728C-637,-728,-620,-721,-607,-708L-504,-607C-487,-586,-481,-563,-488,-537C-494,-511,-511,-494,-537,-488C-563,-481,-586,-487,-607,-504L-708,-607C-721,-621,-728,-637,-728,-656C-728,-676,-721,-693,-708,-708ZM504,504C519,491,537,484,556,484C575,484,592,491,607,504L708,607C721,621,728,637,728,656C728,676,721,692,706,707C692,721,676,728,656,728C637,728,621,721,607,708L504,607C491,592,484,575,484,556C484,537,491,519,504,505ZM-1000,0C-1000,-21,-993,-38,-980,-51C-967,-65,-949,-71,-929,-71L-786,-71C-765,-71,-748,-65,-734,-51C-721,-38,-714,-21,-714,0C-714,21,-721,38,-734,51C-748,65,-765,71,-786,71L-929,71C-949,71,-967,65,-980,51C-993,38,-1000,21,-1000,0ZM714,0C714,-21,721,-38,734,-51C748,-65,765,-71,786,-71L929,-71C949,-71,967,-65,980,-51C993,-38,1000,-21,1000,0C1000,21,993,38,980,51C967,65,949,71,929,71L786,71C765,71,748,65,734,51C721,38,714,21,714,0ZM-708,708C-721,693,-728,676,-728,656C-728,637,-721,620,-708,607L-607,504C-592,491,-575,484,-556,484C-536,484,-520,491,-506,505C-491,520,-484,536,-484,556C-484,575,-491,592,-504,607L-607,707C-621,721,-637,728,-656,728C-676,728,-693,721,-708,707ZM504,-504C491,-519,484,-536,484,-556C484,-575,491,-592,504,-607L607,-708C621,-721,637,-728,656,-728C676,-728,692,-721,707,-706C721,-692,728,-676,728,-656C728,-637,721,-621,708,-607L607,-504C592,-491,575,-484,556,-484C537,-484,519,-491,505,-504Z",
  "M-62,-540L-976,419C-992,437,-1000,457,-1000,478C-1000,500,-992,520,-976,538L-976,540C-960,556,-940,565,-918,565C-896,565,-876,556,-860,540L0,-363L860,540C876,556,896,565,918,565C940,565,960,556,976,540L976,538C992,520,1000,500,1000,478C1000,457,992,437,976,419L62,-540C46,-556,25,-565,0,-565C-25,-565,-46,-556,-62,-540Z",
  "M-250,12C-249,-143,-211,-286,-138,-418C-64,-549,39,-656,172,-736C44,-744,-76,-722,-189,-670C-301,-618,-396,-541,-473,-439C-550,-338,-597,-226,-616,-103C-635,19,-624,141,-582,262L-213,262C-238,180,-250,96,-250,12ZM-666,387C-748,207,-771,25,-733,-160C-696,-345,-605,-505,-461,-639C-314,-769,-146,-843,42,-860C230,-878,409,-837,578,-736C447,-727,327,-688,220,-619C112,-550,27,-458,-35,-342C-98,-226,-128,-104,-126,23C-124,151,-90,272,-25,387L-666,387ZM-938,262L938,262C979,262,1000,283,1000,324C1000,366,979,387,938,387L-938,387C-979,387,-1000,366,-1000,324C-1000,283,-979,262,-938,262ZM-687,512L62,512C81,512,96,518,107,529C119,541,125,556,125,574C125,592,119,607,107,619C96,631,81,637,62,637L-687,637C-706,637,-721,631,-732,619C-744,607,-750,592,-750,574C-750,556,-744,541,-732,529C-721,518,-706,512,-687,512ZM-375,762L62,762C81,762,96,768,107,779C119,791,125,806,125,824C125,842,119,857,107,869C96,881,81,887,62,887L-375,887C-393,885,-408,879,-420,867C-432,855,-437,841,-438,824C-438,806,-432,791,-420,779C-408,768,-393,762,-375,762Z",
  "M9,724C211,719,379,650,513,516C648,381,717,213,722,11C717,-191,648,-359,513,-493C379,-628,211,-697,9,-702C-193,-697,-361,-628,-496,-493C-630,-359,-699,-191,-704,11C-699,213,-630,381,-496,516C-361,650,-193,719,9,724ZM9,866C-233,860,-435,777,-596,616C-757,455,-840,253,-846,11C-840,-231,-757,-432,-596,-593C-435,-755,-233,-838,9,-844C251,-838,452,-755,614,-593C775,-432,858,-231,864,11C858,253,775,455,614,616C452,777,251,860,9,866ZM-481,708L-356,779L-463,964C-478,987,-499,998,-526,998C-552,998,-572,986,-586,963C-599,940,-600,917,-588,893ZM499,708L374,779L481,964C496,987,517,998,543,998C570,998,590,986,604,963C617,940,618,917,606,893ZM9,11L365,11C386,11,403,18,416,31C430,45,436,62,436,82C436,103,430,120,416,134C403,147,386,154,365,154L-62,154C-83,154,-100,147,-114,134C-127,120,-134,103,-134,82L-134,-416C-134,-437,-127,-454,-114,-468C-100,-481,-83,-488,-62,-488C-42,-488,-25,-481,-11,-468C2,-454,9,-437,9,-416L9,11ZM-931,-434C-977,-507,-996,-584,-988,-666C-980,-748,-945,-819,-883,-881C-821,-942,-750,-977,-668,-986C-586,-994,-509,-975,-436,-929L-541,-824C-583,-843,-625,-849,-669,-842C-713,-834,-751,-814,-783,-782C-815,-749,-835,-711,-843,-667C-851,-623,-846,-581,-826,-539L-929,-434L-931,-434ZM931,-434C977,-507,996,-584,988,-666C980,-748,945,-819,884,-881C823,-942,752,-977,669,-986C587,-994,509,-975,436,-929L541,-824C583,-843,625,-849,669,-842C713,-834,751,-814,784,-782C817,-749,837,-711,844,-667C852,-623,846,-581,826,-539Z",
  "M0,776L857,655L857,-771L31,-653C10,-650,-11,-650,-31,-653L-857,-771L-857,655ZM-837,-914L-11,-796C-4,-794,4,-794,11,-796L837,-914C880,-919,918,-907,950,-878C982,-850,999,-814,1000,-771L1000,655C1000,691,988,722,965,748C942,774,913,790,877,796L11,919C4,920,-4,920,-11,919L-877,796C-913,790,-942,774,-965,748C-988,722,-1000,691,-1000,655L-1000,-771C-999,-814,-982,-850,-950,-878C-918,-907,-880,-919,-837,-914ZM-72,-722L71,-722L71,849L-72,849L-72,-722Z",
  "M862,-503L0,338L-863,-503C-879,-519,-898,-527,-919,-527C-941,-527,-960,-519,-976,-503C-992,-486,-1000,-468,-1000,-446C-1000,-424,-993,-406,-978,-392L-59,503C-43,519,-23,527,0,527C23,527,43,519,59,503L978,-389C993,-406,1000,-425,1000,-447C1000,-470,992,-489,976,-504C960,-519,941,-527,919,-527C898,-527,879,-519,863,-503Z",
  "M-742,74L-646,168C-627,189,-622,213,-629,240C-636,267,-652,284,-679,291C-706,298,-729,292,-749,274L-970,53C-985,38,-993,20,-993,0C-993,-20,-985,-38,-970,-53L-749,-274C-729,-292,-706,-298,-679,-291C-652,-284,-636,-267,-629,-240C-622,-213,-627,-189,-646,-168L-742,-74L-74,-74L-74,-749L-168,-653C-188,-633,-212,-626,-240,-633C-268,-640,-286,-657,-293,-685C-300,-713,-293,-736,-271,-756L-50,-977C-37,-992,-20,-1000,0,-1000C20,-1000,38,-992,53,-977L274,-756C287,-741,294,-724,293,-706C293,-687,285,-671,270,-656C256,-642,239,-634,221,-633C202,-632,186,-639,170,-653L74,-747L74,-74L743,-74L648,-168C633,-183,625,-201,625,-221C625,-241,633,-258,647,-272C662,-287,679,-294,699,-294C719,-294,736,-287,752,-274L972,-53C986,-38,993,-20,993,0C993,20,986,38,972,53L752,274C736,287,719,294,699,294C679,294,662,287,647,272C633,258,625,241,625,221C625,201,633,183,648,168L743,74L74,74L74,747L170,653C190,633,213,627,240,634C267,642,284,659,292,686C300,713,294,736,274,756L53,977C38,992,20,1000,0,1000C-20,1000,-37,992,-51,977L-271,756C-287,743,-294,726,-294,706C-294,686,-287,668,-272,654C-258,639,-241,632,-221,632C-201,632,-183,639,-168,653L-74,749L-74,74L-743,74Z",
  "M204,-683C251,-694,299,-698,347,-694L353,-694C388,-692,418,-689,445,-684C472,-678,500,-669,530,-656C615,-621,699,-555,781,-457C888,-316,935,-131,921,98C906,328,834,532,702,711L633,801C612,828,590,854,566,879C532,916,495,944,455,963C416,982,371,991,320,991C286,992,254,990,225,983C196,976,165,966,132,951L116,944C94,933,75,926,60,923C45,919,29,917,10,917C-9,917,-26,919,-43,923C-59,926,-79,934,-103,946L-116,951C-148,964,-176,975,-203,982C-229,990,-257,994,-289,995C-369,998,-439,976,-499,928C-559,881,-623,804,-691,698C-802,534,-871,352,-899,151C-928,-50,-899,-230,-814,-389C-762,-482,-693,-555,-606,-607C-520,-660,-425,-688,-322,-691C-286,-693,-251,-689,-216,-680C-181,-671,-142,-658,-99,-640L-36,-615L-16,-609C22,-653,48,-691,63,-720C92,-780,123,-855,154,-946C160,-966,172,-979,189,-988C206,-996,224,-997,244,-991C263,-985,277,-974,285,-956C293,-939,294,-921,288,-902C262,-817,233,-743,203,-682ZM87,-508C56,-468,17,-424,-29,-376C-42,-363,-59,-356,-78,-355C-98,-354,-115,-360,-129,-374C-143,-387,-150,-404,-151,-423C-152,-442,-146,-460,-132,-474L-105,-504C-136,-517,-170,-530,-207,-543C-244,-555,-281,-562,-320,-562C-399,-560,-472,-539,-539,-497C-606,-455,-661,-398,-702,-327C-780,-175,-801,-9,-766,171C-731,351,-671,502,-586,626C-547,687,-504,742,-456,790C-409,839,-354,864,-293,865C-238,859,-190,846,-150,824C-110,802,-56,790,11,787C78,790,132,803,171,825C211,847,259,860,318,863C377,862,426,841,464,800C502,760,548,704,602,630C721,466,785,285,793,86C801,-113,764,-266,682,-374C600,-466,531,-522,473,-541C416,-559,372,-567,342,-564C296,-569,251,-564,208,-551C165,-537,125,-523,87,-508Z",
  "M-579,789C-610,789,-635,799,-655,819C-674,839,-684,864,-684,895C-684,925,-674,951,-655,970C-635,990,-610,1000,-579,1000L895,1000C925,1000,951,990,970,970C990,951,1000,925,1000,895L1000,-579C1000,-610,990,-635,970,-655C951,-674,925,-684,895,-684C864,-684,839,-674,819,-655C799,-635,789,-610,789,-579L789,789L-579,789ZM819,970C841,990,866,1000,895,1000C923,1000,948,990,969,969C990,948,1000,923,1000,895C1000,866,990,841,970,819L-819,-970C-841,-990,-866,-1000,-895,-1000C-923,-1000,-948,-990,-969,-969C-990,-948,-1000,-923,-1000,-895C-1000,-866,-990,-841,-970,-819Z",
  "M71,750L71,321L357,321L0,-107L-357,321L-71,321L-71,750L-464,750C-614,743,-743,693,-843,593C-943,493,-993,364,-1000,214C-1000,71,-950,-43,-864,-143C-779,-243,-664,-300,-529,-314C-500,-443,-443,-550,-343,-629C-243,-707,-129,-750,0,-750C129,-750,243,-707,343,-629C443,-550,500,-443,529,-314C664,-300,779,-236,864,-143C950,-43,1000,71,1000,214C993,364,943,493,843,593C743,693,614,743,464,750L71,750Z",
  "M-435,-857L-857,-375L-857,857L857,857L857,-375L435,-857L-435,-857ZM-467,-1000L467,-1000C489,-1000,507,-992,522,-975L982,-449C994,-435,1000,-420,1000,-402L1000,929C1000,949,993,967,980,980C967,993,949,1000,929,1000L-929,1000C-949,1000,-966,993,-980,980C-993,967,-1000,949,-1000,929L-1000,-402C-1000,-420,-994,-435,-982,-449L-522,-975C-507,-992,-489,-1000,-466,-1000ZM-1000,-429L1000,-429L1000,-286L-1000,-286L-1000,-429ZM-143,-411L-143,286L143,286L143,-411L31,-857L-31,-857ZM-143,-1000L143,-1000L286,-429L286,357C286,378,279,395,266,408C252,422,235,429,214,429L-214,429C-235,429,-252,422,-266,408C-279,395,-286,378,-286,357L-286,-429Z",
  "M607,-464C457,-607,286,-686,71,-707L71,-857L286,-857C307,-857,321,-864,336,-879C350,-893,357,-907,357,-929C357,-950,350,-964,336,-979C321,-993,307,-1000,286,-1000L-286,-1000C-307,-1000,-321,-993,-336,-979C-350,-964,-357,-950,-357,-929C-357,-907,-350,-893,-336,-879C-321,-864,-307,-857,-286,-857L-71,-857L-71,-707C-286,-686,-457,-607,-607,-464C-771,-307,-850,-100,-857,143C-850,386,-764,586,-607,750C-450,914,-243,993,0,1000C243,993,443,907,607,750C771,593,850,386,857,143C850,-100,764,-300,607,-464ZM507,650C371,786,200,850,0,857C-200,850,-371,786,-507,650C-643,514,-707,343,-714,143C-707,-57,-643,-229,-507,-364C-371,-500,-200,-564,0,-571C200,-564,371,-500,507,-364C643,-229,714,-64,714,143C707,343,643,514,507,650ZM100,43C129,71,143,100,143,143C143,186,129,214,100,243C71,271,43,286,0,286C-43,286,-71,271,-100,243C-129,214,-143,186,-143,143C-143,100,-129,71,-100,43C-93,36,-79,29,-71,21L-71,-357C-71,-379,-64,-393,-50,-407C-36,-421,-21,-429,0,-429C21,-429,36,-421,50,-407C64,-393,71,-379,71,-357L71,21C79,29,93,36,100,43Z",
  "M857,-179L-857,-179L-857,250C-856,290,-842,324,-815,350C-788,377,-754,391,-714,393L-286,393L-286,821L286,821L286,393L714,393C754,391,788,377,815,350C841,324,856,290,857,250L857,-179ZM-864,-321C-864,-427,-852,-522,-828,-607C-795,-728,-734,-847,-643,-964L288,-964L254,-808L500,-964L971,-964C916,-869,878,-750,857,-607C844,-512,839,-417,844,-321L1000,-321L1000,250C999,330,971,398,916,452C862,506,795,534,714,536L429,536L429,893C429,914,422,931,408,944C395,958,378,964,357,964L-357,964C-378,964,-395,958,-408,944C-422,931,-429,914,-429,893L-429,536L-714,536C-795,534,-862,506,-916,452C-971,398,-998,330,-1000,250L-1000,-321L-864,-321ZM-721,-321L701,-321C696,-424,702,-526,716,-627C725,-696,739,-760,757,-821L542,-821L49,-507L112,-821L-569,-821C-627,-737,-667,-653,-690,-569C-711,-498,-721,-415,-721,-321Z",
  "M975,343L754,93C739,79,725,71,696,71L275,71L275,-71L632,-71C654,-71,668,-79,682,-93C696,-107,704,-121,704,-143L704,-643C704,-664,696,-679,682,-693C668,-707,654,-714,632,-714L275,-714L275,-929C275,-950,268,-964,254,-979C239,-993,225,-1000,204,-1000L-225,-1000C-246,-1000,-261,-993,-275,-979C-289,-964,-296,-950,-296,-929L-296,-714L-696,-714C-718,-714,-732,-707,-746,-693L-968,-443C-982,-429,-982,-414,-982,-393C-982,-371,-975,-357,-968,-343L-746,-93C-732,-79,-718,-71,-696,-71L-296,-71L-296,71L-632,71C-654,71,-668,79,-682,93C-696,107,-704,121,-704,143L-704,643C-704,664,-696,679,-682,693C-668,707,-646,714,-632,714L-296,714L-296,929C-296,950,-289,964,-275,979C-261,993,-246,1000,-225,1000L204,1000C225,1000,239,993,254,979C268,964,275,950,275,929L275,714L689,714C711,714,732,707,746,693L968,443C982,429,982,414,982,393C982,371,982,357,975,343ZM-154,-857L132,-857L132,-714L-154,-714L-154,-857ZM-661,-214L-818,-393L-661,-571L561,-571L561,-214L-661,-214ZM-154,-71L132,-71L132,71L-154,71L-154,-71ZM132,857L-154,857L-154,714L132,714L132,857ZM661,571L-561,571L-561,214L661,214L818,393L661,571Z",
  "M857,-420C857,-466,856,-499,853,-520C850,-541,844,-558,835,-571C824,-594,808,-610,786,-621C772,-629,755,-635,734,-638C713,-641,680,-643,634,-643L-634,-643C-680,-643,-713,-641,-734,-638C-755,-635,-772,-629,-786,-621C-808,-610,-824,-594,-835,-571C-844,-558,-850,-541,-853,-520C-856,-499,-857,-466,-857,-420L-857,420C-857,466,-856,499,-853,520C-850,541,-844,558,-835,571C-824,594,-808,610,-786,621C-772,629,-755,635,-734,638C-713,641,-680,643,-634,643L634,643C680,643,713,641,734,638C755,635,772,629,786,621C808,610,824,594,835,571C844,558,850,541,853,520C856,499,857,466,857,420L857,-420ZM1000,-420L1000,420C1000,482,997,529,990,560C983,591,974,618,962,638C937,686,901,722,855,748C833,760,806,769,775,776C743,782,696,786,634,786L-634,786C-696,786,-743,782,-775,776C-806,769,-833,760,-855,748C-901,722,-937,687,-962,641C-974,618,-983,591,-990,560C-997,529,-1000,482,-1000,420L-1000,-420C-1000,-482,-997,-529,-990,-560C-983,-591,-974,-618,-962,-641C-937,-687,-901,-722,-855,-748C-833,-760,-806,-769,-775,-776C-743,-782,-696,-786,-634,-786L634,-786C696,-786,743,-782,775,-776C806,-769,832,-760,853,-748C900,-722,937,-687,962,-641C974,-618,983,-591,990,-560C997,-529,1000,-482,1000,-420ZM-1000,-429L1000,-429L1000,-286L-1000,-286L-1000,-429ZM-1000,-143L1000,-143L1000,0L-1000,0L-1000,-143ZM-714,286L-143,286L-143,429L-714,429L-714,286Z",
  "M907,-693C893,-707,879,-714,857,-714L571,-714L571,-929C571,-950,564,-964,550,-979C536,-993,521,-1000,500,-1000L-500,-1000C-521,-1000,-536,-993,-550,-979C-564,-964,-571,-950,-571,-929L-571,-714L-857,-714C-879,-714,-893,-707,-907,-693C-921,-679,-929,-657,-929,-643C-921,-400,-871,-229,-786,-143C-707,-64,-614,-21,-500,-7C-479,36,-443,79,-407,121C-314,214,-207,264,-71,279L-71,571L-286,571C-307,571,-321,579,-336,593C-350,607,-357,621,-357,643C-357,664,-350,679,-336,693C-321,707,-307,714,-286,714L286,714C307,714,321,707,336,693C350,679,357,664,357,643C357,621,350,607,336,593C321,579,307,571,286,571L71,571L71,279C207,264,314,214,407,121C443,86,479,43,500,-7C607,-21,700,-71,786,-143C871,-229,921,-393,929,-643C929,-657,921,-679,907,-693ZM-571,-164C-614,-179,-650,-207,-686,-243C-736,-293,-764,-400,-779,-571L-571,-571L-571,-164ZM300,14C214,93,121,143,0,143C-121,143,-221,100,-300,14C-379,-71,-429,-164,-429,-286L-429,-857L429,-857L429,-286C429,-164,386,-64,300,14ZM686,-243C650,-207,614,-186,571,-164L571,-571L779,-571C764,-400,736,-293,686,-243ZM621,879C636,893,643,907,643,929C643,950,636,964,621,979C607,993,593,1000,571,1000L-571,1000C-593,1000,-607,993,-621,979C-636,964,-643,950,-643,929C-643,907,-636,893,-621,879C-607,864,-593,857,-571,857L571,857C593,857,607,864,621,879Z",
  "M-789,789L579,789C610,789,635,799,655,819C674,839,684,864,684,895C684,925,674,951,655,970C635,990,610,1000,579,1000L-895,1000C-925,1000,-951,990,-970,970C-990,951,-1000,925,-1000,895L-1000,-579C-1000,-610,-990,-635,-970,-655C-951,-674,-925,-684,-895,-684C-864,-684,-839,-674,-819,-655C-799,-635,-789,-610,-789,-579L-789,789ZM-819,970C-841,990,-866,1000,-895,1000C-923,1000,-948,990,-969,969C-990,948,-1000,923,-1000,895C-1000,866,-990,841,-970,819L819,-970C841,-990,866,-1000,895,-1000C923,-1000,948,-990,969,-969C990,-948,1000,-923,1000,-895C1000,-866,990,-841,970,-819Z",
  "M-571,714C-491,713,-424,685,-369,631C-315,576,-287,509,-286,429C-287,348,-315,281,-369,227C-424,172,-491,144,-571,143C-652,144,-719,172,-773,227C-828,281,-856,348,-857,429C-856,509,-828,576,-773,631C-719,685,-652,713,-571,714ZM-571,857C-693,854,-795,812,-875,732C-955,652,-997,551,-1000,429C-997,307,-955,205,-875,125C-795,45,-693,3,-571,0C-449,3,-348,45,-268,125C-188,205,-146,307,-143,429C-146,551,-188,652,-268,732C-348,812,-449,854,-571,857ZM-500,357L214,357C262,357,286,381,286,429C286,476,262,500,214,500L-500,500C-548,500,-571,476,-571,429C-571,381,-548,357,-500,357ZM571,714C652,713,719,685,773,631C828,576,856,509,857,429C856,348,828,281,773,227C719,172,652,144,571,143C491,144,424,172,369,227C315,281,287,348,286,429C287,509,315,576,369,631C424,685,491,713,571,714ZM571,857C449,854,348,812,268,732C188,652,146,551,143,429C146,307,188,205,268,125C348,45,449,3,571,0C693,3,795,45,875,125C955,205,997,307,1000,429C997,551,955,652,875,732C795,812,693,854,571,857ZM-71,-714C-92,-714,-109,-721,-123,-734C-136,-748,-143,-765,-143,-786C-143,-807,-136,-824,-123,-837C-109,-850,-92,-857,-71,-857L286,-857C302,-857,317,-852,329,-843C342,-833,350,-820,355,-804L569,54C574,73,571,91,560,107C550,124,535,134,517,138C498,143,481,141,464,132C448,123,437,109,431,89L230,-714L-71,-714ZM-929,-286C-949,-286,-967,-292,-980,-306C-993,-319,-1000,-336,-1000,-357C-1000,-378,-993,-395,-980,-408C-967,-422,-949,-429,-929,-429L-643,-429C-626,-429,-612,-424,-600,-415C-589,-406,-580,-394,-576,-379L-433,49C-424,76,-429,100,-446,121C-464,141,-487,149,-514,143C-542,137,-559,121,-567,94L-694,-286L-928,-286ZM-310,196L-404,89L310,-554L404,-446Z",
  "M-708,708C-903,502,-1000,266,-1000,0C-1000,-266,-903,-502,-708,-708C-502,-903,-266,-1000,0,-1000C266,-1000,502,-903,708,-708C903,-502,1000,-266,1000,0C1000,266,903,502,708,708C502,903,266,1000,0,1000C-266,1000,-502,903,-708,708ZM-607,607C-430,774,-228,857,0,857C228,857,430,774,607,607C774,430,857,228,857,0C857,-228,774,-430,607,-607C430,-774,228,-857,0,-857C-228,-857,-430,-774,-607,-607C-774,-430,-857,-228,-857,0C-857,228,-774,430,-607,607ZM-34,-926C19,-916,67,-906,112,-895C48,-779,24,-658,40,-533C57,-408,111,-298,203,-203C298,-111,408,-56,533,-40C658,-24,779,-48,895,-112C905,-67,916,-19,926,34C785,100,640,122,492,98C344,74,214,8,100,-100C-8,-214,-74,-344,-98,-492C-122,-640,-100,-785,-33,-926ZM-902,-45C-762,-106,-620,-123,-478,-97C-335,-71,-209,-5,-100,100C5,209,71,335,97,478C123,621,106,762,45,902C-6,893,-55,884,-103,875C-43,760,-23,643,-41,521C-60,400,-114,294,-203,203C-294,114,-400,60,-521,41C-643,23,-760,43,-875,103Z",
  "M596,616C672,543,732,460,776,366C820,272,846,173,855,69C772,19,683,-9,588,-14C494,-20,403,-2,315,38C446,212,540,405,596,616ZM473,714C448,606,412,501,365,400C318,298,261,203,194,114C83,209,15,325,-8,461C-31,597,-5,728,69,855C141,849,211,834,279,810C347,786,412,754,473,714ZM-94,853C-161,701,-176,548,-141,394C-105,240,-24,110,103,4C68,-34,33,-71,-4,-105C-112,22,-242,103,-395,138C-548,174,-701,159,-853,94C-841,191,-814,283,-772,371C-731,458,-675,537,-606,606C-537,675,-459,731,-372,772C-285,814,-192,841,-94,853ZM-855,-69C-728,4,-597,29,-461,6C-325,-17,-210,-84,-116,-194C-205,-263,-300,-320,-401,-366C-501,-412,-606,-448,-714,-473C-754,-412,-786,-348,-810,-280C-834,-212,-849,-142,-855,-69ZM-616,-596C-406,-539,-214,-446,-38,-317C1,-405,18,-496,12,-589C7,-683,-20,-772,-69,-855C-173,-846,-272,-820,-366,-776C-460,-732,-543,-672,-616,-596ZM94,-853C138,-751,159,-646,156,-537C153,-427,126,-323,74,-223C127,-177,177,-128,223,-76C322,-128,425,-155,535,-158C644,-161,750,-140,853,-94C841,-192,814,-285,772,-372C731,-459,675,-537,606,-606C537,-675,459,-731,372,-772C285,-814,192,-841,94,-853ZM708,708C502,903,266,1000,0,1000C-266,1000,-502,903,-708,708C-903,502,-1000,266,-1000,0C-1000,-266,-903,-502,-708,-708C-502,-903,-266,-1000,0,-1000C266,-1000,502,-903,708,-708C903,-502,1000,-266,1000,0C1000,266,903,502,708,708Z",
  "M-786,68C-806,68,-823,75,-837,88C-850,102,-857,119,-857,139L-857,282C-857,302,-851,318,-838,331C-825,345,-809,352,-790,354L786,354C807,354,824,347,837,334C851,320,857,303,857,282L857,140C857,119,851,102,837,88C824,75,807,68,786,68L-785,68ZM857,-64C900,-47,935,-21,961,16C987,52,1000,93,1000,139L1000,282C1000,322,990,360,969,394C948,428,920,454,884,472L766,787C749,828,723,861,687,886C652,911,612,924,567,925L-567,925C-612,924,-652,911,-687,886C-723,861,-749,828,-766,787L-884,472C-920,454,-948,428,-969,394C-990,360,-1000,322,-1000,282L-1000,139C-1000,93,-987,52,-961,16C-935,-21,-900,-47,-857,-64L-857,-75C-850,-317,-765,-519,-602,-678C-439,-838,-236,-921,7,-925C249,-918,450,-833,610,-671C770,-508,852,-306,857,-64ZM714,-75C710,-277,640,-446,506,-580C371,-715,202,-785,0,-789C-202,-785,-371,-715,-505,-580C-640,-446,-710,-277,-714,-75L714,-75ZM0,497L-723,497L-632,735C-627,750,-619,762,-607,770C-595,778,-582,782,-567,782L567,782C582,782,595,778,607,770C619,762,627,750,632,735L723,497L0,497Z",
  "M81,705L81,-919C81,-942,74,-962,59,-977C43,-992,24,-1000,0,-1000C-24,-1000,-43,-992,-59,-977C-74,-962,-81,-942,-81,-919L-81,705L-674,74C-691,57,-711,48,-733,48C-755,48,-774,57,-790,75C-806,93,-814,113,-814,135C-814,157,-807,177,-791,196L-59,975C-42,992,-22,1000,0,1000C22,1000,42,992,59,975L791,196C807,177,814,157,814,135C814,113,806,93,790,75C774,57,755,48,733,48C711,48,691,57,674,74Z",
  "M713,-712C754,-712,788,-699,815,-672C842,-645,855,-611,855,-570L855,572C855,612,842,645,814,673C786,700,753,714,713,714L-713,714C-753,714,-786,700,-814,673C-842,645,-855,612,-855,572L-855,-570C-855,-611,-842,-645,-815,-672C-788,-699,-754,-712,-713,-712L713,-712ZM713,-857L-713,-857C-751,-855,-787,-847,-822,-833C-857,-819,-888,-798,-915,-771C-942,-745,-962,-714,-977,-679C-992,-644,-1000,-608,-1000,-570L-1000,572C-1000,610,-992,646,-977,681C-962,716,-942,747,-915,774C-888,801,-857,821,-822,835C-787,850,-751,857,-713,857L713,857C751,857,787,850,822,835C857,821,888,801,915,774C942,747,962,716,977,681C992,647,1000,610,1000,572L1000,-570C1000,-608,992,-644,977,-679C962,-714,942,-745,915,-771C888,-798,857,-819,822,-833C787,-847,751,-855,713,-857ZM429,-428C408,-428,391,-421,378,-407C364,-392,358,-376,358,-357L358,356C358,377,364,394,378,407C391,421,408,427,429,427C449,427,466,421,480,407C493,394,500,377,500,356L500,-357C500,-377,493,-394,480,-408C466,-421,449,-428,429,-428ZM-429,-428C-448,-428,-464,-421,-479,-407C-493,-392,-500,-376,-500,-357L-500,356C-500,377,-493,394,-480,407C-466,421,-449,427,-429,427C-408,427,-391,421,-378,407C-364,394,-358,377,-358,356L-358,-357C-358,-376,-364,-392,-378,-407C-391,-421,-408,-428,-429,-428ZM0,-286C-20,-284,-37,-277,-51,-263C-64,-250,-71,-233,-71,-212L-71,-141C-71,-122,-64,-106,-51,-93C-37,-79,-20,-72,0,-72C21,-72,38,-79,51,-93C64,-106,71,-122,71,-141L71,-212C71,-233,64,-250,50,-263C36,-277,19,-284,0,-286ZM0,72C-20,72,-37,79,-51,92C-64,106,-71,123,-71,143L-71,214C-71,235,-64,252,-51,265C-37,279,-20,285,0,285C21,285,38,279,51,265C64,252,71,235,71,214L71,143C71,124,64,108,50,93C36,79,19,72,0,72Z",
  "M-752,750L-451,650L-397,674C-275,737,-143,768,0,768C243,761,445,681,606,530C768,379,851,197,857,-18C851,-232,768,-415,606,-566C445,-717,243,-796,0,-803C-242,-796,-444,-717,-606,-566C-767,-415,-851,-232,-857,-18C-857,60,-844,136,-817,212C-790,288,-751,359,-698,426L-649,491ZM-855,933C-883,942,-907,936,-927,914C-948,892,-952,868,-942,839L-812,513C-872,435,-918,350,-951,260C-984,170,-1000,77,-1000,-18C-994,-263,-899,-477,-714,-660C-530,-842,-292,-938,0,-947C292,-938,530,-842,714,-660C899,-477,994,-263,1000,-18C994,228,899,441,714,624C530,806,292,902,0,911C-162,911,-316,875,-462,803ZM0,96C-21,96,-40,91,-57,81C-74,72,-88,58,-98,39C-109,20,-114,1,-114,-18C-114,-37,-109,-56,-98,-75C-88,-93,-74,-108,-57,-117C-40,-127,-21,-132,0,-132C33,-132,60,-121,82,-99C103,-78,114,-51,114,-18C114,15,103,42,82,64C60,85,33,96,0,96ZM429,96C408,96,389,91,372,81C355,72,341,58,330,39C320,20,315,1,315,-18C315,-37,320,-56,330,-75C341,-93,355,-108,372,-117C389,-127,408,-132,429,-132C461,-132,489,-121,510,-99C532,-78,543,-51,543,-18C543,15,532,42,510,64C489,85,461,96,429,96ZM-428,96C-449,96,-468,91,-485,81C-503,72,-516,58,-527,39C-537,20,-542,1,-542,-18C-542,-37,-537,-56,-527,-75C-516,-93,-503,-108,-485,-117C-468,-127,-449,-132,-428,-132C-396,-132,-369,-121,-347,-99C-325,-78,-315,-51,-315,-18C-315,15,-325,42,-347,64C-369,85,-396,96,-428,96Z",
  "M-752,750L-462,652L-411,679C-289,738,-152,768,0,768C255,762,460,684,616,536C772,387,853,202,857,-18C853,-240,773,-425,617,-573C462,-721,256,-798,0,-804C-256,-798,-462,-721,-617,-573C-773,-425,-853,-240,-857,-18C-857,65,-844,146,-817,223C-790,301,-752,372,-703,437L-654,502ZM-855,933C-883,942,-907,936,-928,914C-948,892,-952,867,-942,839L-817,525C-877,446,-922,360,-953,268C-984,176,-1000,80,-1000,-18C-997,-263,-907,-477,-731,-660C-555,-842,-311,-938,0,-946C311,-938,555,-842,731,-660C907,-477,997,-263,1000,-18C997,228,907,442,730,624C553,806,310,902,0,911C-179,909,-336,874,-473,806Z",
  "M-572,498L692,498C736,496,772,481,801,452C829,423,845,387,846,344L846,-656C845,-700,829,-736,801,-764C772,-793,736,-808,692,-810L-692,-810C-736,-809,-772,-793,-800,-764C-829,-736,-844,-700,-846,-656L-846,716ZM-519,651L-875,935C-901,954,-927,957,-956,943C-984,930,-998,907,-1000,875L-1000,-656C-998,-743,-968,-815,-910,-874C-851,-932,-779,-962,-692,-964L692,-964C779,-962,851,-932,910,-874C968,-815,998,-743,1000,-656L1000,344C998,430,968,503,910,561C851,620,779,650,692,651L-519,651ZM0,-72C-35,-72,-65,-84,-88,-107C-111,-130,-123,-159,-123,-195C-123,-230,-111,-259,-88,-282C-65,-306,-35,-317,0,-317C35,-317,65,-306,88,-282C111,-259,123,-230,123,-195C123,-159,111,-130,88,-107C65,-84,35,-72,0,-72ZM462,-72C426,-72,397,-84,374,-107C351,-130,339,-159,339,-195C339,-230,351,-259,374,-282C397,-306,426,-317,462,-317C497,-317,526,-306,549,-282C573,-259,584,-230,584,-195C584,-159,573,-130,549,-107C526,-84,497,-72,462,-72ZM-462,-72C-497,-72,-526,-84,-549,-107C-573,-130,-584,-159,-584,-195C-584,-230,-573,-259,-549,-282C-526,-306,-497,-317,-462,-317C-426,-317,-397,-306,-374,-282C-351,-259,-339,-230,-339,-195C-339,-159,-351,-130,-374,-107C-397,-84,-426,-72,-462,-72Z",
  "M-572,498L692,498C736,496,772,481,801,452C829,423,845,387,846,344L846,-656C845,-700,829,-736,801,-764C772,-793,736,-808,692,-810L-692,-810C-736,-809,-772,-793,-800,-764C-829,-736,-844,-699,-846,-656L-846,716ZM-519,651L-875,935C-901,954,-927,957,-956,943C-984,930,-998,907,-1000,875L-1000,-656C-998,-743,-968,-815,-910,-874C-851,-932,-779,-962,-692,-964L692,-964C779,-962,851,-932,910,-874C968,-815,998,-743,1000,-656L1000,344C998,430,968,503,910,561C851,620,779,650,692,651L-519,651Z",
  "M-100,0L-304,-201C-317,-216,-324,-233,-324,-252C-324,-272,-317,-288,-302,-302C-288,-317,-272,-324,-252,-324C-233,-324,-216,-317,-201,-304L0,-100L201,-304C222,-323,245,-329,271,-322C297,-314,314,-297,322,-271C329,-245,323,-222,304,-201L100,0L304,201C323,222,329,245,322,271C314,297,297,314,271,321C245,329,222,323,201,304L0,100L-201,304C-216,317,-233,324,-252,324C-272,324,-288,316,-302,302C-317,288,-324,271,-324,252C-324,233,-317,216,-304,201ZM0,857C243,851,445,767,606,606C767,445,851,243,857,0C851,-243,767,-445,606,-606C445,-767,243,-851,0,-857C-243,-851,-445,-767,-606,-606C-767,-445,-851,-243,-857,0C-851,243,-767,445,-606,606C-445,767,-243,851,0,857ZM0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-706C-518,-895,-283,-993,0,-1000C283,-993,518,-895,706,-706C895,-518,993,-283,1000,0C993,283,895,518,706,706C518,895,283,993,0,1000Z",
  "M-340,439L-57,156C-79,145,-98,132,-115,114C-132,96,-146,77,-158,57L-438,340L-434,360L-430,430L-359,434ZM-215,511C-171,555,-144,606,-135,664C-125,723,-134,780,-162,834C-190,889,-230,931,-282,958C-334,986,-390,996,-451,987C-511,978,-563,954,-606,913C-649,873,-677,823,-688,763L-693,693L-763,689C-823,675,-873,648,-913,605C-954,563,-978,511,-987,451C-996,390,-986,334,-958,282C-931,230,-889,190,-834,162C-779,135,-723,125,-666,135C-608,144,-557,170,-513,213L-193,-105C-194,-219,-166,-343,-107,-475C-49,-607,31,-725,134,-829C254,-943,375,-996,499,-987C622,-978,732,-925,829,-829C925,-732,978,-622,987,-499C996,-375,942,-254,827,-134C724,-33,607,47,475,106C342,165,219,194,103,193ZM-15,15C49,67,158,68,310,19C463,-30,602,-114,728,-232C811,-320,850,-407,844,-493C838,-580,800,-658,729,-729C658,-800,579,-839,492,-845C405,-852,319,-813,232,-730C114,-603,30,-463,-20,-310C-69,-158,-68,-49,-15,15ZM-570,421C-569,392,-575,365,-590,340C-604,315,-625,296,-652,284C-679,271,-707,268,-736,273C-764,278,-789,291,-809,312C-830,334,-842,359,-848,387C-853,416,-849,443,-838,470C-826,497,-808,518,-783,533C-758,548,-731,554,-702,553L-579,544ZM-553,702C-554,731,-547,758,-533,782C-518,806,-497,824,-470,837C-443,849,-415,853,-387,847C-358,842,-334,829,-314,808C-293,787,-280,762,-275,734C-270,707,-273,679,-285,652C-297,625,-315,604,-340,590C-365,575,-392,569,-421,570L-546,577Z",
  "M-605,714L-462,571L571,571L571,-143C570,-238,549,-326,509,-406L612,-511C644,-456,670,-398,688,-336C705,-274,714,-210,714,-143L714,571L929,571C949,571,967,578,980,591C993,605,1000,622,1000,643C1000,664,993,681,980,694C967,707,949,714,929,714L-605,714ZM-806,714L-929,714C-949,714,-967,708,-980,694C-993,681,-1000,664,-1000,643C-1000,622,-993,605,-980,591C-967,578,-949,571,-929,571L-714,571L-714,-143C-711,-317,-658,-468,-554,-595C-449,-722,-313,-805,-143,-844L-143,-857C-141,-897,-127,-931,-100,-958C-74,-984,-40,-998,0,-998C40,-998,74,-984,100,-958C127,-931,141,-897,143,-857L143,-844C217,-827,287,-801,352,-764C416,-728,475,-682,527,-627L424,-524C344,-614,247,-672,134,-699C21,-725,-92,-717,-204,-674C-317,-631,-406,-562,-471,-466C-536,-371,-570,-263,-571,-143L-571,478ZM-143,857L143,857C141,897,127,931,100,958C74,984,40,998,0,998C-40,998,-74,984,-100,958C-127,931,-141,897,-143,857ZM-806,775C-821,788,-837,795,-856,795C-875,795,-891,788,-905,773C-919,759,-927,743,-928,724C-928,706,-922,689,-909,674L663,-908C678,-922,695,-929,713,-929C732,-929,748,-921,762,-907C776,-893,784,-876,785,-857C785,-838,779,-821,766,-806Z",
  "M813,-958L0,-145L-813,-958C-834,-977,-859,-987,-885,-987C-912,-987,-936,-977,-956,-956C-977,-936,-987,-912,-987,-885C-987,-859,-977,-834,-958,-813L-145,0L-958,813C-986,841,-995,874,-986,913C-976,952,-952,976,-915,986C-877,995,-843,986,-813,958L0,145L813,958C834,977,859,987,885,987C912,987,936,977,956,956C977,936,987,912,987,885C987,859,977,834,958,813L145,0L958,-813C986,-841,995,-874,986,-913C976,-952,952,-976,913,-986C874,-995,841,-986,813,-958Z",
  "M-559,-67C-528,-222,-481,-353,-419,-461C-366,-551,-282,-658,-169,-781L-428,-781C-449,-781,-466,-787,-479,-801C-492,-814,-499,-831,-499,-852C-499,-872,-492,-889,-479,-903C-466,-916,-449,-923,-428,-923L423,-923C444,-923,461,-916,475,-903C488,-889,494,-872,494,-852C494,-831,488,-814,475,-801C461,-787,444,-781,423,-781L93,-781C126,-693,184,-588,268,-466C322,-390,368,-332,408,-289C448,-247,480,-222,506,-213C636,-207,746,-162,836,-77C926,8,977,116,989,246C996,378,962,492,886,590C810,687,707,749,579,774C450,793,333,769,228,703C123,636,52,541,16,417C-17,290,-5,171,51,60C107,-51,196,-131,317,-180C267,-231,212,-300,153,-386C66,-510,3,-620,-36,-716C-158,-588,-245,-479,-296,-390C-347,-302,-387,-193,-415,-64C-283,-39,-179,24,-103,124C-27,225,6,342,-4,475C-21,606,-76,714,-170,797C-263,881,-377,923,-510,923C-645,917,-756,870,-846,782C-935,694,-985,583,-996,450C-999,317,-959,202,-878,105C-797,9,-690,-49,-559,-66ZM-499,780C-398,777,-315,743,-248,676C-182,610,-147,526,-144,426C-147,325,-182,242,-248,175C-315,109,-398,74,-499,71C-599,74,-683,109,-749,175C-816,242,-851,325,-854,426C-851,526,-816,610,-749,676C-683,743,-599,777,-499,780ZM494,638C595,636,678,601,745,534C811,468,846,384,849,284C846,183,811,100,745,33C678,-33,595,-68,494,-71C394,-68,310,-33,244,33C177,100,143,183,140,284C143,384,177,468,244,534C310,601,394,636,494,638Z",
  "M568,-713C647,-713,719,-693,785,-655C851,-616,904,-562,942,-493C981,-424,999,-352,997,-276C995,-200,973,-129,932,-61C891,6,837,58,770,94C702,129,629,146,550,143C515,270,447,373,346,451C246,529,130,569,-2,570L-430,570C-592,566,-726,510,-833,403C-940,296,-995,162,-1000,0L-1000,-784C-1000,-805,-993,-822,-980,-835C-967,-849,-949,-855,-929,-855L497,-855C518,-855,535,-849,548,-835C561,-822,568,-805,568,-784L568,-713ZM568,-570L568,0C648,-2,715,-29,770,-84C824,-138,852,-205,853,-285C852,-365,824,-433,770,-487C715,-541,648,-569,568,-570ZM-929,713L497,713C517,713,535,719,548,733C561,746,568,763,568,784C568,805,561,822,548,835C535,849,517,855,497,855L-929,855C-950,855,-967,849,-980,835C-993,822,-1000,805,-1000,784C-1000,763,-993,746,-980,733C-967,719,-950,713,-929,713ZM-857,-713L-857,0C-854,122,-813,223,-733,303C-653,383,-552,425,-430,428L-2,428C120,425,221,383,301,303C381,223,422,122,425,0L425,-713L-857,-713Z",
  "M507,-265L434,-283L407,-354C373,-444,318,-514,241,-564C164,-614,78,-636,-18,-631C-114,-625,-197,-592,-267,-532C-337,-472,-383,-396,-405,-303L-425,-217L-511,-197C-619,-170,-702,-114,-762,-29C-822,57,-847,155,-839,265C-824,375,-777,464,-699,533C-621,602,-527,639,-416,642L398,642C460,642,519,630,574,606C629,583,679,549,722,505C766,462,799,413,823,357C847,302,858,243,858,181C857,74,824,-21,760,-102C696,-183,611,-238,507,-266ZM540,-403C677,-367,787,-296,871,-190C954,-84,997,40,1000,181C996,351,937,493,824,606C711,720,569,779,398,783L-416,783C-563,780,-689,732,-793,639C-897,547,-959,427,-980,281C-993,133,-960,3,-879,-111C-799,-224,-687,-299,-544,-336C-513,-460,-451,-562,-357,-641C-264,-719,-153,-763,-27,-772C102,-780,217,-750,319,-683C420,-615,494,-522,540,-403Z",
  "M-591,-852L-591,762L-139,400C-97,367,-51,351,0,351C51,351,97,367,139,400L591,762L591,-852L-591,-852ZM-665,-1000L665,-1000C687,-1000,704,-993,718,-979C732,-965,739,-948,739,-926L739,914C737,945,723,967,696,980C669,993,644,991,619,972L46,515C32,504,17,499,0,499C-17,499,-32,504,-46,515L-619,972C-644,991,-669,993,-696,980C-723,967,-737,945,-739,914L-739,-926C-739,-948,-732,-965,-718,-979C-704,-993,-687,-1000,-665,-1000Z",
  "M559,-982C646,-981,724,-957,793,-912C862,-866,914,-803,948,-722C982,-642,991,-561,976,-479C960,-397,922,-325,862,-262C801,-199,730,-159,648,-142C566,-124,485,-131,404,-161L-79,480L-79,858L134,858C155,858,171,865,185,878C198,892,205,909,205,929C205,950,198,967,185,980C171,993,155,1000,134,1000L-433,1000C-453,1000,-470,993,-483,980C-497,967,-503,950,-503,929C-503,909,-497,892,-483,878C-470,865,-453,858,-433,858L-220,858L-220,480L-970,-518C-989,-544,-999,-573,-999,-604L-999,-628C-999,-647,-992,-664,-979,-677C-966,-690,-949,-698,-928,-699L-769,-699L-915,-883C-927,-899,-931,-917,-929,-936C-927,-955,-918,-971,-901,-982C-885,-994,-868,-999,-850,-997C-831,-994,-815,-986,-802,-971L-590,-699L158,-699C189,-785,241,-853,313,-904C385,-955,467,-981,559,-982ZM313,-699L629,-699C650,-698,667,-690,680,-677C693,-664,700,-647,700,-628L700,-604C700,-573,691,-545,671,-520L494,-281C567,-266,634,-276,696,-310C758,-344,800,-396,824,-467C848,-538,845,-605,817,-670C789,-735,741,-783,674,-813C606,-843,538,-848,471,-826C404,-805,351,-762,313,-697L313,-699ZM-479,-558L-194,-190C-182,-174,-177,-157,-179,-138C-181,-120,-190,-105,-206,-93C-221,-81,-238,-76,-257,-77C-275,-79,-291,-87,-304,-102L-658,-558L-822,-558L-149,338L523,-558L-479,-558Z",
  "M-714,500L714,500L714,-857L-571,-857C-612,-856,-645,-842,-672,-815C-699,-788,-713,-754,-714,-714L-714,500ZM-571,-1000L786,-1000C807,-1000,824,-993,837,-980C850,-967,857,-949,857,-929L857,571C857,592,850,609,837,623C824,636,807,643,786,643L-786,643L-857,772L-857,-714C-856,-795,-828,-862,-773,-916C-719,-971,-652,-998,-571,-1000ZM-607,643C-637,644,-662,655,-682,675C-702,695,-712,720,-712,750C-712,780,-702,805,-682,825C-662,845,-637,856,-607,857L714,857L714,643L-607,643ZM-607,500L857,500L857,857C856,897,842,931,815,958C788,984,754,998,714,1000L-607,1000C-679,999,-738,974,-785,927C-831,881,-856,821,-857,750C-856,679,-831,619,-785,573C-738,526,-679,502,-607,500ZM-286,-857L-286,-297L-71,-469L143,-297L143,-857L-286,-857ZM-429,-1000L286,-1000L286,-150C284,-120,270,-99,244,-86C218,-73,193,-76,170,-94L-71,-286L-312,-94C-336,-76,-361,-73,-387,-86C-413,-99,-427,-120,-429,-150L-429,-1000Z",
  "M-71,0L71,0L71,714L-71,714L-71,0ZM-714,857L714,857C713,817,699,783,672,757C645,730,612,716,571,714L-571,714C-612,716,-645,730,-672,757C-699,784,-713,817,-714,857ZM-571,571L571,571C652,573,719,601,773,655C828,709,856,777,857,857L857,1000L-857,1000L-857,857C-856,777,-828,709,-773,655C-719,601,-652,573,-571,571ZM0,0C122,-3,223,-45,304,-125C384,-205,426,-307,429,-429C426,-551,384,-652,304,-732C223,-812,122,-854,0,-857C-122,-854,-223,-812,-304,-732C-384,-652,-426,-551,-429,-429C-426,-307,-384,-205,-304,-125C-223,-45,-122,-3,0,0ZM0,143C-162,138,-297,83,-404,-25C-511,-132,-567,-266,-571,-429C-567,-591,-511,-725,-404,-833C-297,-940,-162,-996,0,-1000C162,-996,297,-940,404,-833C511,-725,567,-591,571,-429C567,-266,511,-132,404,-25C297,83,162,138,0,143Z",
  "M286,-286L286,-143L-143,-143C-223,-141,-291,-113,-345,-59C-399,-5,-427,63,-429,143L-429,429C-427,509,-399,576,-345,631C-291,685,-223,713,-143,714L571,714C652,713,719,685,773,631C828,576,856,509,857,429L857,143C857,91,845,43,819,0C794,-43,759,-78,714,-105L714,-261C799,-230,868,-179,920,-107C972,-36,999,48,1000,143L1000,429C997,551,955,652,875,732C795,812,693,854,571,857L-143,857C-265,854,-366,812,-446,732C-527,652,-568,551,-571,429L-571,143C-568,21,-527,-80,-446,-161C-366,-241,-265,-283,-143,-286L286,-286ZM-286,286L-286,143L143,143C223,141,291,114,345,59C399,5,427,-62,429,-143L429,-429C427,-509,399,-576,345,-631C291,-685,223,-713,143,-714L-571,-714C-652,-713,-719,-685,-773,-631C-828,-576,-856,-509,-857,-429L-857,-143C-857,-91,-845,-43,-819,0C-794,43,-759,78,-714,105L-714,261C-801,230,-869,178,-921,105C-972,32,-999,-51,-1000,-143L-1000,-429C-997,-551,-955,-652,-875,-732C-795,-812,-693,-854,-571,-857L143,-857C265,-854,366,-812,446,-732C527,-652,568,-551,571,-429L571,-143C568,-21,527,80,446,161C366,241,265,283,143,286L-286,286Z",
  "M-571,571L929,571C949,571,967,578,980,591C993,605,1000,622,1000,643C1000,664,993,681,980,694C967,708,949,714,929,714L-643,714C-664,714,-681,708,-694,694C-708,681,-714,664,-714,643L-714,-929C-714,-949,-708,-967,-694,-980C-681,-993,-664,-1000,-643,-1000C-622,-1000,-605,-993,-591,-980C-578,-967,-571,-949,-571,-929L-571,571ZM714,-643L714,929C714,949,708,967,694,980C681,993,664,1000,643,1000C622,1000,605,993,591,980C578,967,571,949,571,929L571,-571L-929,-571C-949,-571,-967,-578,-980,-591C-993,-605,-1000,-622,-1000,-643C-1000,-664,-993,-681,-980,-694C-967,-708,-949,-714,-929,-714L643,-714C664,-714,681,-708,694,-694C708,-681,714,-664,714,-643Z",
  "M-429,-571C-469,-570,-502,-556,-529,-529C-556,-502,-570,-469,-571,-429L-571,429C-570,469,-556,502,-529,529C-502,556,-469,570,-429,571L429,571C469,570,502,556,529,529C556,502,570,469,571,429L571,-429C570,-469,556,-502,529,-529C502,-556,469,-570,429,-571L-429,-571ZM-429,-714L429,-714C509,-713,576,-685,631,-631C685,-576,713,-509,714,-429L714,429C713,509,685,576,631,631C576,685,509,713,429,714L-429,714C-509,713,-576,685,-631,631C-685,576,-713,509,-714,429L-714,-429C-713,-509,-685,-576,-631,-631C-576,-685,-509,-713,-429,-714ZM0,-1000C21,-1000,38,-993,51,-980C65,-967,71,-949,71,-929L71,-643L-71,-643L-71,-929C-71,-949,-65,-967,-51,-980C-38,-993,-21,-1000,0,-1000ZM357,-1000C378,-1000,395,-993,408,-980C422,-967,429,-949,429,-929L429,-643L286,-643L286,-929C286,-949,292,-967,306,-980C319,-993,336,-1000,357,-1000ZM-357,-1000C-336,-1000,-319,-993,-306,-980C-292,-967,-286,-949,-286,-929L-286,-643L-429,-643L-429,-929C-429,-949,-422,-967,-408,-980C-395,-993,-378,-1000,-357,-1000ZM0,1000C-21,1000,-38,993,-51,980C-65,967,-71,949,-71,929L-71,643L71,643L71,929C71,949,65,967,51,980C38,993,21,1000,0,1000ZM357,1000C336,1000,319,993,306,980C292,967,286,949,286,929L286,643L429,643L429,929C429,949,422,967,408,980C395,993,378,1000,357,1000ZM-357,1000C-378,1000,-395,993,-408,980C-422,967,-429,949,-429,929L-429,643L-286,643L-286,929C-286,949,-292,967,-306,980C-319,993,-336,1000,-357,1000ZM-1000,0C-1000,-21,-993,-38,-980,-51C-967,-65,-949,-71,-929,-71L-643,-71L-643,71L-929,71C-949,71,-967,65,-980,51C-993,38,-1000,21,-1000,0ZM-1000,-357C-1000,-378,-993,-395,-980,-408C-967,-422,-949,-429,-929,-429L-643,-429L-643,-286L-929,-286C-949,-286,-967,-292,-980,-306C-993,-319,-1000,-336,-1000,-357ZM-1000,357C-1000,336,-993,319,-980,306C-967,292,-949,286,-929,286L-643,286L-643,429L-929,429C-949,429,-967,422,-980,408C-993,395,-1000,378,-1000,357ZM1000,0C1000,21,993,38,980,51C967,65,949,71,929,71L643,71L643,-71L929,-71C949,-71,967,-65,980,-51C993,-38,1000,-21,1000,0ZM1000,-357C1000,-336,993,-319,980,-306C967,-292,949,-286,929,-286L643,-286L643,-429L929,-429C949,-429,967,-422,980,-408C993,-395,1000,-378,1000,-357ZM1000,357C1000,378,993,395,980,408C967,422,949,429,929,429L643,429L643,286L929,286C949,286,967,292,980,306C993,319,1000,336,1000,357Z",
  "M571,714C570,795,542,862,488,916C433,971,366,998,286,1000L-714,1000C-795,999,-862,971,-916,916C-971,862,-998,795,-1000,714L-1000,-286C-999,-366,-971,-433,-916,-488C-862,-542,-795,-570,-714,-571L-714,-429C-754,-427,-788,-413,-815,-386C-841,-359,-856,-326,-857,-286L-857,714C-856,754,-842,788,-815,815C-788,841,-754,856,-714,857L286,857C326,856,359,842,386,815C413,788,427,754,429,714L571,714ZM-286,-857C-326,-856,-359,-842,-386,-815C-413,-788,-427,-754,-429,-714L-429,286C-427,326,-413,359,-386,386C-359,413,-326,427,-286,429L714,429C754,427,788,413,815,386C841,359,856,326,857,286L857,-714C856,-754,842,-788,815,-815C788,-841,754,-856,714,-857L-286,-857ZM-286,-1000L714,-1000C795,-999,862,-971,916,-916C971,-862,998,-795,1000,-714L1000,286C999,366,971,433,916,488C862,542,795,570,714,571L-286,571C-366,570,-433,542,-488,488C-542,433,-570,366,-571,286L-571,-714C-570,-795,-542,-862,-488,-916C-433,-971,-366,-998,-286,-1000Z",
  "M0,-1000L750,-167L-750,-167ZM-750,167L750,167L0,1000Z",
  "M-158,-978C-142,-993,-123,-1000,-101,-1000C-80,-1000,-61,-993,-45,-978L848,-59C864,-43,872,-23,872,0C872,23,864,43,848,59L-45,978C-61,993,-80,1000,-101,1000C-123,1000,-142,992,-158,976C-174,960,-182,941,-182,919C-182,898,-174,879,-158,863L683,0L-158,-862C-174,-879,-182,-897,-182,-919C-182,-941,-174,-960,-158,-978ZM-848,-978C-832,-993,-813,-1000,-791,-1000C-770,-1000,-751,-993,-735,-978L158,-59C174,-43,182,-23,182,0C182,23,174,43,158,59L-735,978C-751,993,-770,1000,-791,1000C-813,1000,-832,992,-848,976C-864,960,-872,941,-872,919C-872,898,-864,879,-848,863L-7,0L-848,-862C-864,-879,-872,-897,-872,-919C-872,-941,-864,-960,-848,-978Z",
  "M-1000,-867L1000,-867L1000,-733L-1000,-733L-1000,-867ZM-667,-733L-667,333L667,333L667,-733L-667,-733ZM-800,-867L800,-867L800,400C800,419,794,435,781,448C769,460,753,467,733,467L-733,467C-753,467,-769,460,-781,448C-794,435,-800,419,-800,400L-800,-867ZM-396,867L-550,867L-248,344L-133,410ZM550,867L396,867L133,410L248,344Z",
  "M319,467L550,867L396,867L165,467L-165,467L-396,867L-550,867L-319,467L-733,467C-753,467,-769,460,-781,448C-794,435,-800,419,-800,400L-800,-733L-933,-733C-953,-733,-969,-740,-981,-752C-994,-765,-1000,-781,-1000,-800C-1000,-819,-994,-835,-981,-848C-969,-860,-953,-867,-933,-867L933,-867C953,-867,969,-860,981,-848C994,-835,1000,-819,1000,-800C1000,-781,994,-765,981,-752C969,-740,953,-733,933,-733L800,-733L800,400C800,419,794,435,781,448C769,460,753,467,733,467L319,467ZM667,-733L-667,-733L-667,333L667,333L667,-733ZM-333,-200C-314,-200,-298,-194,-285,-181C-273,-169,-267,-153,-267,-133L-267,0C-267,19,-273,35,-285,48C-298,60,-314,67,-333,67C-353,67,-369,60,-381,48C-394,35,-400,19,-400,0L-400,-133C-400,-153,-394,-169,-381,-181C-369,-194,-353,-200,-333,-200ZM0,-333C20,-333,36,-327,48,-315C61,-302,67,-286,67,-267L67,0C67,19,61,35,48,48C36,60,20,67,0,67C-19,67,-35,60,-48,48C-60,35,-67,19,-67,0L-67,-267C-67,-286,-60,-302,-48,-315C-35,-327,-19,-333,0,-333ZM333,-467C353,-467,369,-460,381,-448C394,-435,400,-419,400,-400L400,0C400,19,394,35,381,48C369,60,353,67,333,67C314,67,298,60,286,48C273,35,267,19,267,0L267,-400C267,-419,273,-435,286,-448C298,-460,314,-467,333,-467Z",
  "M-319,467L-733,467C-753,467,-769,460,-781,448C-794,435,-800,419,-800,400L-800,-733L-933,-733C-953,-733,-969,-740,-981,-752C-994,-765,-1000,-781,-1000,-800C-1000,-819,-994,-835,-981,-848C-969,-860,-953,-867,-933,-867L933,-867C953,-867,969,-860,981,-848C994,-835,1000,-819,1000,-800C1000,-781,994,-765,981,-752C969,-740,953,-733,933,-733L800,-733L800,400C800,419,794,435,781,448C769,460,753,467,733,467L319,467L550,867L396,867L165,467L-165,467L-396,867L-550,867ZM667,-733L-667,-733L-667,333L667,333L667,-733ZM-352,-19C-366,-6,-382,0,-400,0C-418,0,-434,-7,-447,-20C-460,-33,-467,-49,-467,-67C-467,-85,-460,-101,-448,-115L-140,-421L121,-225L348,-508C365,-529,386,-538,411,-534C437,-531,454,-517,463,-493C472,-468,469,-446,452,-425L146,-42L-127,-246Z",
  "M45,-978C61,-993,80,-1000,101,-1000C123,-1000,142,-992,158,-976C174,-960,182,-941,182,-919C182,-898,174,-879,158,-863L-683,0L158,862C174,879,182,898,182,920C182,943,174,962,158,977C142,992,123,1000,101,1000C80,1000,61,993,45,978L-848,59C-864,41,-872,21,-872,-1C-872,-24,-864,-43,-848,-59ZM735,-978C751,-993,770,-1000,791,-1000C813,-1000,832,-992,848,-976C864,-960,872,-941,872,-919C872,-898,864,-879,848,-863L7,0L848,862C864,879,872,898,872,920C872,943,864,962,848,977C832,992,813,1000,791,1000C770,1000,751,993,735,978L-158,59C-174,41,-182,21,-182,-1C-182,-24,-174,-43,-158,-59Z",
  "M-357,-714L-357,-929C-357,-949,-350,-967,-337,-980C-324,-993,-307,-1000,-286,-1000L286,-1000C307,-1000,324,-993,337,-980C350,-967,357,-949,357,-929L357,-714L929,-714C949,-714,967,-708,980,-694C993,-681,1000,-664,1000,-643C1000,-622,993,-605,980,-591C967,-578,949,-571,929,-571L-929,-571C-949,-571,-967,-578,-980,-591C-993,-605,-1000,-622,-1000,-643C-1000,-664,-993,-681,-980,-694C-967,-708,-949,-714,-929,-714L-357,-714ZM-214,-714L214,-714L214,-857L-214,-857L-214,-714ZM-714,1000C-735,1000,-752,993,-766,980C-779,967,-786,949,-786,929L-786,-571L786,-571L786,929C786,949,779,967,766,980C752,993,735,1000,714,1000L-714,1000ZM-214,571C-193,571,-176,565,-163,551C-150,538,-143,521,-143,500L-143,-214C-143,-235,-150,-252,-163,-266C-176,-279,-193,-286,-214,-286C-235,-286,-252,-279,-266,-266C-279,-252,-286,-235,-286,-214L-286,500C-286,521,-279,538,-266,551C-252,565,-235,571,-214,571ZM214,571C235,571,252,565,266,551C279,538,286,521,286,500L286,-214C286,-235,279,-252,266,-266C252,-279,235,-286,214,-286C193,-286,176,-279,163,-266C150,-252,143,-235,143,-214L143,500C143,521,150,538,163,551C176,565,193,571,214,571Z",
  "M-500,857L500,857C548,857,571,881,571,929C571,976,548,1000,500,1000L-500,1000C-548,1000,-571,976,-571,929C-571,881,-548,857,-500,857ZM643,-214C638,-396,575,-547,454,-668C333,-790,182,-853,0,-857C-182,-853,-333,-790,-454,-668C-575,-547,-638,-396,-643,-214C-643,-82,-590,70,-483,240C-377,410,-216,599,0,806C216,599,377,410,483,240C590,70,643,-82,643,-214ZM0,1000C-524,524,-786,119,-786,-214C-780,-438,-703,-623,-556,-770C-408,-917,-223,-994,0,-1000C223,-994,409,-917,556,-770C703,-623,780,-437,786,-214C786,119,524,524,0,1000ZM-286,-286L286,-286C333,-286,357,-262,357,-214C357,-167,333,-143,286,-143L-286,-143C-333,-143,-357,-167,-357,-214C-357,-262,-333,-286,-286,-286Z",
  "M-624,445L624,445L624,-391L89,-829C61,-851,32,-861,0,-861C-32,-861,-61,-851,-89,-829L-624,-391L-624,445ZM-624,584L-624,861L624,861L624,584L-624,584ZM176,-937L737,-478C754,-463,763,-445,763,-424L763,931C763,951,756,968,743,981C730,994,714,1000,693,1000L-693,1000C-714,1000,-730,994,-743,981C-756,968,-763,951,-763,931L-763,-424C-763,-445,-754,-463,-737,-478L-176,-937C-122,-979,-64,-1000,0,-1000C64,-1000,122,-979,176,-937ZM0,-109C39,-111,72,-125,97,-151C123,-177,136,-209,137,-248C137,-287,124,-320,97,-346C71,-372,39,-385,0,-385C-39,-385,-71,-372,-97,-346C-124,-320,-137,-287,-137,-248C-136,-209,-123,-177,-97,-151C-72,-125,-39,-111,0,-109ZM0,29C-78,28,-143,1,-196,-52C-249,-105,-276,-170,-277,-248C-276,-326,-249,-392,-196,-444C-143,-497,-78,-524,0,-526C78,-524,143,-497,196,-444C249,-391,276,-326,277,-248C276,-170,249,-105,196,-52C143,1,78,28,0,29Z",
  "M-857,-286L-857,857L857,857L857,-714L571,-714L571,-643C571,-622,565,-605,551,-591C538,-578,521,-571,500,-571C479,-571,462,-578,449,-591C435,-605,429,-622,429,-643L429,-714L-429,-714L-429,-643C-429,-622,-435,-605,-449,-591C-462,-578,-479,-571,-500,-571C-521,-571,-538,-578,-551,-591C-565,-605,-571,-622,-571,-643L-571,-714L-857,-714L-857,-429L857,-429L857,-286L-857,-286ZM-429,-857L429,-857L429,-929C429,-949,435,-967,449,-980C462,-993,479,-1000,500,-1000C521,-1000,538,-993,551,-980C565,-967,571,-949,571,-929L571,-857L929,-857C949,-857,967,-850,980,-837C993,-824,1000,-807,1000,-786L1000,929C1000,949,993,967,980,980C967,993,949,1000,929,1000L-929,1000C-949,1000,-967,993,-980,980C-993,967,-1000,949,-1000,929L-1000,-786C-1000,-807,-993,-824,-980,-837C-967,-850,-949,-857,-929,-857L-571,-857L-571,-929C-571,-949,-565,-967,-551,-980C-538,-993,-521,-1000,-500,-1000C-479,-1000,-462,-993,-449,-980C-435,-967,-429,-949,-429,-929L-429,-857ZM-500,0L-357,0C-336,0,-319,7,-306,20C-292,33,-286,51,-286,71C-286,92,-292,109,-306,123C-319,136,-336,143,-357,143L-500,143C-521,143,-538,136,-551,123C-565,109,-571,92,-571,71C-571,51,-565,33,-551,20C-538,7,-521,0,-500,0ZM-500,429L-357,429C-336,429,-319,435,-306,449C-292,462,-286,479,-286,500C-286,521,-292,538,-306,551C-319,565,-336,571,-357,571L-500,571C-521,571,-538,565,-551,551C-565,538,-571,521,-571,500C-571,479,-565,462,-551,449C-538,435,-521,429,-500,429ZM-71,0L71,0C92,0,109,7,123,20C136,33,143,51,143,71C143,92,136,109,123,123C109,136,92,143,71,143L-71,143C-92,143,-109,136,-123,123C-136,109,-143,92,-143,71C-143,51,-136,33,-123,20C-109,7,-92,0,-71,0ZM-71,429L71,429C92,429,109,435,123,449C136,462,143,479,143,500C143,521,136,538,123,551C109,565,92,571,71,571L-71,571C-92,571,-109,565,-123,551C-136,538,-143,521,-143,500C-143,479,-136,462,-123,449C-109,435,-92,429,-71,429ZM357,0L500,0C521,0,538,7,551,20C565,33,571,51,571,71C571,92,565,109,551,123C538,136,521,143,500,143L357,143C336,143,319,136,306,123C292,109,286,92,286,71C286,51,292,33,306,20C319,7,336,0,357,0ZM357,429L500,429C521,429,538,435,551,449C565,462,571,479,571,500C571,521,565,538,551,551C538,565,521,571,500,571L357,571C336,571,319,565,306,551C292,538,286,521,286,500C286,479,292,462,306,449C319,435,336,429,357,429Z",
  "M-857,-214L-857,-321C-857,-369,-847,-414,-827,-456C-807,-499,-779,-536,-742,-567C-706,-598,-665,-620,-619,-632C-574,-644,-528,-646,-480,-638C-447,-747,-387,-834,-300,-900C-213,-965,-113,-999,0,-1000C113,-999,213,-965,300,-900C387,-834,447,-747,480,-638C528,-646,574,-644,619,-632C665,-620,706,-598,742,-567C779,-536,807,-499,827,-456C847,-414,857,-369,857,-321L857,-214C853,13,778,207,632,366C486,525,299,617,72,641L72,857L-71,857L-71,641C-299,617,-486,525,-632,366C-777,207,-853,13,-857,-214ZM-217,-286L216,-286C211,-344,219,-399,242,-451C265,-503,301,-547,348,-583C327,-665,285,-730,222,-780C159,-830,85,-855,0,-855C-85,-855,-159,-830,-222,-780C-285,-730,-327,-664,-348,-583C-301,-547,-265,-503,-242,-451C-219,-399,-211,-344,-217,-286ZM-380,-286C-372,-318,-374,-350,-386,-380C-398,-409,-418,-434,-445,-453C-473,-472,-503,-482,-536,-482C-569,-482,-599,-472,-626,-453C-654,-434,-673,-409,-685,-380C-697,-350,-700,-318,-692,-286L-380,-286ZM379,-286L692,-286C699,-318,697,-350,685,-380C673,-409,654,-434,626,-453C599,-472,568,-482,536,-482C503,-482,473,-472,445,-453C418,-434,398,-409,386,-380C374,-350,372,-318,379,-286ZM0,500C187,496,347,434,479,315C610,196,687,43,710,-143L-710,-143C-688,43,-611,196,-479,315C-347,434,-188,496,0,500ZM-286,857L286,857C307,857,324,864,337,877C350,891,357,908,357,929C357,949,350,967,337,980C324,993,306,1000,286,1000L-286,1000C-307,1000,-324,993,-337,980C-351,967,-357,949,-357,929C-357,908,-351,891,-337,877C-324,864,-307,857,-286,857Z",
  "M-70,-558L-70,-700L-280,-700C-300,-700,-317,-707,-330,-720C-343,-733,-350,-750,-350,-770C-350,-791,-343,-807,-330,-821C-317,-834,-300,-840,-280,-840L280,-840C301,-840,317,-834,331,-821C344,-807,350,-791,350,-770C350,-750,344,-733,331,-720C317,-707,301,-700,280,-700L70,-700L70,-558C207,-548,336,-511,455,-449C575,-386,678,-301,764,-194C850,-86,911,32,946,162C982,292,991,425,972,560L-972,560C-991,425,-982,292,-946,162C-911,32,-850,-86,-764,-194C-678,-301,-575,-386,-455,-449C-336,-511,-207,-548,-70,-558ZM-840,420L840,420C835,182,752,-16,594,-174C436,-332,238,-414,0,-420C-238,-414,-436,-332,-594,-174C-752,-16,-834,182,-840,420ZM-910,700L910,700C931,700,948,707,961,720C974,733,980,750,980,770C980,791,974,807,961,821C948,834,931,840,910,840L-910,840C-931,840,-947,834,-961,821C-974,807,-980,791,-980,770C-980,750,-974,733,-961,720C-947,707,-931,700,-910,700Z",
  "M-786,-571L-929,-571C-949,-571,-967,-578,-980,-591C-993,-605,-1000,-622,-1000,-643C-1000,-664,-993,-681,-980,-694C-967,-708,-949,-714,-929,-714L-357,-714L-357,-929C-357,-949,-350,-967,-337,-980C-324,-993,-307,-1000,-286,-1000L286,-1000C307,-1000,324,-993,337,-980C350,-967,357,-949,357,-929L357,-714L929,-714C949,-714,967,-708,980,-694C993,-681,1000,-664,1000,-643C1000,-622,993,-605,980,-591C967,-578,949,-571,929,-571L786,-571L786,929C786,949,779,967,766,980C752,993,735,1000,714,1000L-714,1000C-735,1000,-752,993,-766,980C-779,967,-786,949,-786,929L-786,-571ZM214,-714L214,-857L-214,-857L-214,-714L214,-714ZM-643,857L643,857L643,-571L-643,-571L-643,857ZM-214,571C-235,571,-252,565,-266,551C-279,538,-286,521,-286,500L-286,-214C-286,-235,-279,-252,-266,-266C-252,-279,-235,-286,-214,-286C-193,-286,-176,-279,-163,-266C-150,-252,-143,-235,-143,-214L-143,500C-143,521,-150,538,-163,551C-176,565,-193,571,-214,571ZM214,571C193,571,176,565,163,551C150,538,143,521,143,500L143,-214C143,-235,150,-252,163,-266C176,-279,193,-286,214,-286C235,-286,252,-279,266,-266C279,-252,286,-235,286,-214L286,500C286,521,279,538,266,551C252,565,235,571,214,571Z",
  "M-857,-429L-857,857L429,857L429,-429L-857,-429ZM-929,-571L500,-571C521,-571,538,-565,551,-551C565,-538,571,-521,571,-500L571,929C571,949,565,967,551,980C538,993,521,1000,500,1000L-929,1000C-949,1000,-967,993,-980,980C-993,967,-1000,949,-1000,929L-1000,-500C-1000,-521,-993,-538,-980,-551C-967,-565,-949,-571,-929,-571ZM1000,-929L1000,643C1000,664,993,681,980,694C967,708,949,714,929,714L714,714L714,571L857,571L857,-857L-286,-857L-286,-714L-429,-714L-429,-929C-429,-949,-422,-967,-408,-980C-395,-993,-378,-1000,-357,-1000L929,-1000C949,-1000,967,-993,980,-980C993,-967,1000,-949,1000,-929ZM-571,357L143,357L143,500L-571,500L-571,357ZM-571,-71L143,-71L143,71L-571,71L-571,-71Z",
  "M714,-286L143,-286L143,-857L-714,-857L-714,857L714,857L714,-286ZM656,-429L286,-799L286,-429L656,-429ZM-786,-1000L286,-1000L857,-429L857,929C857,949,850,967,837,980C824,993,807,1000,786,1000L-786,1000C-807,1000,-824,993,-837,980C-850,967,-857,949,-857,929L-857,-929C-857,-949,-850,-967,-837,-980C-824,-993,-807,-1000,-786,-1000ZM-429,0L429,0L429,143L-429,143L-429,0ZM-429,-429L-71,-429L-71,-286L-429,-286L-429,-429ZM-429,429L429,429L429,571L-429,571L-429,429Z",
  "M0,857C243,851,445,767,606,606C767,445,851,243,857,0C851,-243,767,-445,606,-606C445,-767,243,-851,0,-857C-243,-851,-445,-767,-606,-606C-767,-445,-851,-243,-857,0C-851,243,-767,445,-606,606C-445,767,-243,851,0,857ZM0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-706C-518,-895,-283,-993,0,-1000C283,-993,518,-895,706,-706C895,-518,993,-283,1000,0C993,283,895,518,706,706C518,895,283,993,0,1000ZM478,-440C368,-185,250,4,126,127C2,251,-187,368,-440,478C-452,482,-462,480,-471,471C-480,462,-482,452,-478,440C-368,187,-251,-2,-127,-125C-4,-248,185,-366,440,-478C452,-482,462,-480,471,-471C480,-462,482,-452,478,-440Z",
  "M714,-286L143,-286L143,-857L-714,-857L-714,857L714,857L714,-286ZM656,-429L286,-799L286,-429L656,-429ZM-786,-1000L286,-1000L857,-429L857,929C857,949,850,967,837,980C824,993,807,1000,786,1000L-786,1000C-807,1000,-824,993,-837,980C-850,967,-857,949,-857,929L-857,-929C-857,-949,-850,-967,-837,-980C-824,-993,-807,-1000,-786,-1000ZM-71,143L-71,-143L71,-143L71,143L357,143L357,286L71,286L71,571L-71,571L-71,286L-357,286L-357,143L-71,143Z",
  "M656,-429L286,-799L286,-429L656,-429ZM714,-286L143,-286L143,-857L-714,-857L-714,857L714,857L714,-286ZM-786,-1000L286,-1000L857,-429L857,929C857,949,850,967,837,980C824,993,807,1000,786,1000L-786,1000C-807,1000,-824,993,-837,980C-850,967,-857,949,-857,929L-857,-929C-857,-949,-850,-967,-837,-980C-824,-993,-807,-1000,-786,-1000ZM-76,299L328,-105L431,-4L-76,502L-429,147L-328,47Z",
  "M656,-429L286,-799L286,-429L656,-429ZM714,-286L143,-286L143,-857L-714,-857L-714,857L714,857L714,-286ZM-786,-1000L286,-1000L857,-429L857,929C857,949,850,967,837,980C824,993,807,1000,786,1000L-786,1000C-807,1000,-824,993,-837,980C-850,967,-857,949,-857,929L-857,-929C-857,-949,-850,-967,-837,-980C-824,-993,-807,-1000,-786,-1000ZM-96,219L-299,18L-196,-85L4,118L208,-85L308,18L107,219L308,422L208,522L4,321L-196,522L-299,422Z",
  "M656,-429L286,-799L286,-429L656,-429ZM714,-286L143,-286L143,-857L-714,-857L-714,857L714,857L714,-286ZM-786,-1000L286,-1000L857,-429L857,929C857,949,850,967,837,980C824,993,807,1000,786,1000L-786,1000C-807,1000,-824,993,-837,980C-850,967,-857,949,-857,929L-857,-929C-857,-949,-850,-967,-837,-980C-824,-993,-807,-1000,-786,-1000ZM-357,143L357,143L357,286L-357,286L-357,143Z",
  "M-275,-476L-275,-586C-272,-663,-244,-728,-193,-780C-141,-833,-76,-860,1,-861C79,-860,143,-833,195,-782C247,-730,274,-665,277,-586L277,-478C509,-403,688,-268,813,-72C938,124,985,343,955,586L-953,586C-984,343,-937,124,-812,-72C-686,-268,-507,-403,-274,-476ZM-895,723L897,723C917,723,933,730,946,743C959,756,965,772,965,792C965,812,959,829,946,842C933,855,917,861,897,861L-895,861C-915,861,-931,855,-944,842C-957,829,-963,812,-963,792C-963,772,-957,756,-944,743C-931,730,-915,723,-895,723ZM-826,448L828,448C822,214,741,19,585,-137C430,-292,235,-373,1,-379C-233,-373,-428,-292,-583,-137C-739,19,-820,214,-826,448ZM139,-517L139,-586C137,-624,124,-657,98,-682C72,-708,40,-721,1,-721C-38,-721,-70,-708,-96,-682C-122,-657,-135,-624,-137,-586L-137,-517L139,-517Z",
  "M-917,833L917,833C941,833,961,841,977,857C992,872,1000,892,1000,917C1000,941,992,961,977,977C961,992,941,1000,917,1000L-917,1000C-941,1000,-961,992,-977,977C-992,961,-1000,941,-1000,917C-1000,892,-992,872,-977,857C-961,841,-941,833,-917,833ZM83,172L698,-443L818,-326L-8,500L-833,-326L-716,-443L-83,190L-83,-1000L83,-1000L83,172Z",
  "M-841,166L-769,308C-819,356,-844,407,-846,462C-840,564,-758,653,-600,728C-442,804,-242,843,0,846C242,843,442,804,600,728C758,653,840,564,846,462C845,407,819,356,769,308L844,166C893,208,932,253,959,303C986,352,1000,405,1000,462C992,620,893,749,704,847C515,946,280,997,0,1000C-280,997,-515,946,-704,847C-893,749,-992,620,-1000,462C-1000,405,-986,353,-958,303C-930,253,-891,207,-841,166ZM-841,-296L-769,-154C-819,-106,-844,-54,-846,0C-840,103,-758,192,-600,267C-442,342,-242,381,0,385C242,381,442,342,600,267C758,192,840,103,846,0C845,-55,819,-106,769,-154L844,-296C893,-254,932,-208,959,-159C986,-109,1000,-56,1000,0C992,159,893,287,704,386C515,484,280,535,0,538C-280,535,-515,484,-704,386C-893,287,-992,159,-1000,0C-1000,-56,-986,-109,-958,-159C-930,-208,-891,-254,-841,-296ZM0,77C-280,74,-515,23,-704,-76C-893,-174,-992,-303,-1000,-462C-992,-620,-893,-749,-704,-847C-515,-946,-280,-997,0,-1000C280,-997,515,-946,704,-847C893,-749,992,-620,1000,-462C992,-303,893,-174,704,-76C515,23,280,74,0,77ZM0,-77C242,-80,442,-119,600,-195C758,-270,840,-359,846,-462C840,-564,758,-653,600,-728C442,-804,242,-843,0,-846C-242,-843,-442,-804,-600,-728C-758,-653,-840,-564,-846,-462C-840,-359,-758,-270,-600,-195C-442,-119,-242,-80,0,-77Z",
  "M0,286C162,281,297,225,404,118C511,11,567,-124,571,-286C567,-448,511,-583,404,-690C297,-797,162,-853,0,-857C-162,-853,-297,-797,-404,-690C-511,-583,-567,-448,-571,-286C-567,-124,-511,11,-404,118C-297,225,-162,281,0,286ZM0,429C-202,424,-371,355,-506,220C-640,85,-710,-83,-714,-286C-710,-488,-640,-657,-506,-791C-371,-926,-202,-996,0,-1000C202,-996,371,-926,506,-791C640,-657,710,-488,714,-286C710,-83,640,85,506,220C371,355,202,424,0,429ZM0,286C48,286,71,310,71,357L71,929C71,976,48,1000,0,1000C-48,1000,-71,976,-71,929L-71,357C-71,310,-48,286,0,286ZM-357,643L357,643C405,643,429,667,429,714C429,762,405,786,357,786L-357,786C-405,786,-429,762,-429,714C-429,667,-405,643,-357,643Z",
  "M-846,-846L-846,846L846,846L846,-846L-846,-846ZM-923,-1000L923,-1000C946,-1000,964,-993,978,-978C993,-964,1000,-946,1000,-923L1000,923C1000,946,993,964,978,978C964,993,946,1000,923,1000L-923,1000C-946,1000,-964,993,-978,978C-993,964,-1000,946,-1000,923L-1000,-923C-1000,-946,-993,-964,-978,-978C-964,-993,-946,-1000,-923,-1000ZM-462,-538L-462,-923L-308,-923L-308,-77L308,-77L308,-923L462,-923L462,-538L846,-538L846,-385L462,-385L462,-77L846,-77L846,77L462,77L462,385L846,385L846,538L462,538L462,923L308,923L308,77L-308,77L-308,923L-462,923L-462,538L-923,538L-923,385L-462,385L-462,77L-923,77L-923,-77L-462,-77L-462,-385L-923,-385L-923,-538L-462,-538Z",
  "M0,-1000C283,-993,518,-895,706,-706C895,-518,993,-283,1000,0C993,283,895,518,706,706C518,895,283,993,0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-706C-518,-895,-283,-993,0,-1000ZM0,-120L-232,-353C-250,-371,-270,-379,-294,-379C-317,-379,-337,-371,-354,-354C-371,-337,-379,-317,-379,-294C-379,-270,-370,-250,-353,-232L-120,0L-353,232C-371,250,-379,270,-379,294C-379,317,-371,337,-354,354C-337,371,-317,379,-294,379C-270,379,-250,370,-232,353L0,120L232,353C256,375,283,382,315,374C346,366,366,346,374,315C382,283,375,256,353,232L120,0L353,-232C371,-250,379,-270,379,-294C379,-317,371,-337,354,-354C337,-371,317,-379,294,-379C270,-379,250,-370,232,-353Z",
  "M-496,-790C-268,-930,-31,-974,214,-922C459,-871,657,-736,809,-517L854,-440L854,-437C859,-426,859,-414,855,-401C851,-389,844,-378,834,-370L-46,200C-60,208,-73,211,-86,209C-100,206,-110,199,-119,187L-164,117C-184,84,-190,50,-183,15C-175,-20,-155,-48,-124,-70L439,-438C452,-446,460,-457,462,-470C465,-483,462,-497,454,-510C452,-515,449,-519,444,-522C329,-614,200,-664,57,-672C-85,-681,-219,-645,-344,-565C-500,-457,-598,-315,-635,-140C-673,35,-641,203,-541,365C-435,520,-294,616,-120,654C54,691,222,660,384,560C417,540,451,534,486,542C521,551,550,571,571,602L616,668C623,681,625,694,622,706C620,719,614,729,604,738C582,758,558,775,531,790C303,930,66,974,-179,922C-424,871,-622,735,-774,515C-914,287,-957,50,-905,-195C-852,-440,-716,-638,-496,-790ZM819,-27C832,-34,845,-36,859,-34C872,-31,883,-24,891,-12L949,75C972,113,979,153,971,194C963,235,940,268,904,295L814,353C802,361,789,363,776,360C763,357,751,349,741,338L626,160C618,147,615,133,618,120C622,107,629,96,641,88Z",
  "M694,-714L725,-714C743,-714,759,-709,771,-698C784,-686,792,-672,795,-654L844,-368C847,-347,841,-328,827,-311C813,-294,795,-286,772,-286L663,-286L576,933C574,952,567,968,554,981C540,994,524,1000,504,1000L-504,1000C-524,1000,-540,994,-554,981C-567,968,-574,952,-576,933L-663,-286L-772,-286C-795,-286,-813,-294,-827,-311C-841,-328,-847,-347,-844,-368L-795,-654C-792,-672,-784,-686,-771,-698C-759,-709,-743,-714,-725,-714L-694,-714L-710,-924C-710,-945,-703,-963,-689,-978C-674,-993,-658,-1000,-638,-1000L636,-1000C657,-1000,674,-993,689,-978C703,-963,709,-945,708,-924ZM549,-714L560,-857L-560,-857L-551,-714L549,-714ZM-674,-429L688,-429L665,-571L-665,-571L-688,-429L-674,-429ZM-520,-286L-438,857L437,857L520,-286L-520,-286Z",
  "M-857,-714L-857,714L857,714L857,-429L-58,-429L-344,-714L-857,-714ZM-929,-857L-286,-857L0,-571L929,-571C949,-571,967,-565,980,-551C993,-538,1000,-521,1000,-500L1000,786C1000,807,993,824,980,837C967,850,949,857,929,857L-929,857C-949,857,-967,850,-980,837C-993,824,-1000,807,-1000,786L-1000,-786C-1000,-807,-993,-824,-980,-837C-967,-850,-949,-857,-929,-857ZM-357,71L357,71L357,214L-357,214L-357,71Z",
  "M-857,-714L-857,714L857,714L857,-429L-58,-429L-344,-714L-857,-714ZM-929,-857L-286,-857L0,-571L929,-571C949,-571,967,-565,980,-551C993,-538,1000,-521,1000,-500L1000,786C1000,807,993,824,980,837C967,850,949,857,929,857L-929,857C-949,857,-967,850,-980,837C-993,824,-1000,807,-1000,786L-1000,-786C-1000,-807,-993,-824,-980,-837C-967,-850,-949,-857,-929,-857ZM-4,263L400,-141L500,-40L-4,467L-357,112L-257,11Z",
  "M-857,-714L-857,714L857,714L857,-429L-58,-429L-344,-714L-857,-714ZM-929,-857L-286,-857L0,-571L929,-571C949,-571,967,-565,980,-551C993,-538,1000,-521,1000,-500L1000,786C1000,807,993,824,980,837C967,850,949,857,929,857L-929,857C-949,857,-967,850,-980,837C-993,824,-1000,807,-1000,786L-1000,-786C-1000,-807,-993,-824,-980,-837C-967,-850,-949,-857,-929,-857ZM-71,71L-71,-214L71,-214L71,71L357,71L357,214L71,214L71,500L-71,500L-71,214L-357,214L-357,71L-71,71Z",
  "M-857,-714L-857,714L857,714L857,-429L-58,-429L-344,-714L-857,-714ZM-929,-857L-286,-857L0,-571L929,-571C949,-571,967,-565,980,-551C993,-538,1000,-521,1000,-500L1000,786C1000,807,993,824,980,837C967,850,949,857,929,857L-929,857C-949,857,-967,850,-980,837C-993,824,-1000,807,-1000,786L-1000,-786C-1000,-807,-993,-824,-980,-837C-967,-850,-949,-857,-929,-857ZM-100,143L-304,-58L-201,-161L0,42L201,-161L304,-58L101,143L304,344L201,446L0,243L-201,446L-304,344Z",
  "M0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-706C-518,-895,-283,-993,0,-1000C283,-993,518,-895,706,-706C895,-518,993,-283,1000,0C993,283,895,518,706,706C518,895,283,993,0,1000ZM0,857C243,851,445,767,606,606C767,445,851,243,857,0C851,-243,767,-445,606,-606C445,-767,243,-851,0,-857C-243,-851,-445,-767,-606,-606C-767,-445,-851,-243,-857,0C-851,243,-767,445,-606,606C-445,767,-243,851,0,857ZM-725,-545C-690,-580,-655,-615,-620,-647C-582,-579,-533,-519,-473,-467L-547,-339C-617,-397,-676,-466,-725,-545ZM734,-556C684,-474,621,-402,547,-339L473,-464C536,-519,587,-583,627,-656C661,-625,697,-592,734,-556ZM-103,-150L-78,-290C-26,-284,26,-284,78,-290L103,-150C34,-141,-34,-141,-103,-150ZM-243,-179C-309,-198,-371,-224,-429,-257L-357,-382C-314,-356,-268,-336,-219,-319ZM429,-257C371,-224,309,-198,243,-179L219,-319C268,-336,314,-356,357,-382ZM-734,556C-684,474,-621,402,-547,339L-473,464C-534,519,-585,582,-625,652C-661,622,-697,590,-734,556ZM734,558C697,592,661,624,625,654C585,583,534,519,473,464L547,339C621,402,684,475,734,558ZM-103,150C-34,141,34,141,103,150L78,290C26,284,-26,284,-78,290ZM-243,179L-219,319C-268,336,-314,356,-357,382L-429,257C-371,224,-309,198,-243,179ZM429,257L357,382C312,356,266,336,216,319L243,179C309,198,371,224,429,257Z",
  "M-451,559L425,-696C441,-717,462,-727,488,-724C515,-722,533,-709,544,-686C555,-662,553,-639,539,-616L-380,693C-392,709,-407,719,-425,722C-444,726,-461,722,-476,711L-970,341C-984,329,-993,315,-996,296C-999,278,-994,260,-983,245C-972,229,-957,220,-938,218C-920,216,-902,220,-887,232ZM521,-95C501,-95,485,-102,472,-114C459,-127,453,-144,453,-163C453,-183,459,-200,472,-213C485,-225,501,-232,521,-232L932,-232C952,-232,968,-225,981,-213C994,-200,1000,-183,1000,-163C1000,-144,994,-127,981,-114C968,-102,952,-95,932,-95L521,-95ZM248,315C228,315,211,309,199,296C186,283,179,267,179,247C179,227,186,210,199,198C211,185,228,178,248,178L932,178C952,178,968,185,981,198C994,210,1000,227,1000,247C1000,267,994,283,981,296C968,309,952,315,932,315L248,315ZM-26,725C-46,725,-62,719,-75,706C-88,693,-94,677,-94,657C-94,637,-88,621,-75,608C-62,595,-46,589,-26,589L932,589C952,589,968,595,981,608C994,621,1000,637,1000,657C1000,677,994,693,981,706C968,719,952,725,932,725L-26,725Z",
  "M-571,-228L-571,-929C-571,-949,-565,-966,-551,-980C-538,-993,-521,-1000,-500,-1000C-479,-1000,-462,-993,-449,-980C-435,-966,-429,-949,-429,-929L-429,-228C-385,-243,-351,-268,-325,-305C-299,-341,-286,-382,-286,-428L-286,-928C-286,-949,-279,-966,-266,-980C-252,-993,-235,-1000,-214,-1000C-193,-1000,-176,-993,-163,-980C-150,-966,-143,-949,-143,-928L-143,-428C-144,-342,-171,-267,-223,-203C-275,-139,-344,-97,-429,-78L-429,929C-429,949,-435,967,-449,980C-462,993,-479,1000,-500,1000C-521,1000,-538,993,-551,980C-565,967,-571,949,-571,929L-571,-78C-656,-97,-725,-139,-777,-203C-829,-267,-856,-342,-857,-428L-857,-928C-857,-949,-850,-966,-837,-980C-824,-993,-807,-1000,-786,-1000C-765,-1000,-748,-993,-734,-980C-721,-966,-714,-949,-714,-928L-714,-428C-714,-382,-701,-341,-675,-305C-649,-268,-615,-243,-571,-228ZM357,134C253,109,168,45,102,-58C35,-161,2,-284,0,-429C3,-591,45,-725,125,-833C205,-940,307,-996,429,-1000C551,-996,652,-940,732,-833C812,-725,854,-591,857,-429C856,-284,822,-161,756,-58C689,45,604,109,500,134L500,929C500,949,493,966,480,980C467,993,449,1000,429,1000C408,1000,391,993,377,980C364,966,357,949,357,929L357,134ZM429,0C504,-3,570,-44,626,-123C682,-202,711,-304,714,-429C711,-554,682,-655,626,-734C570,-813,504,-854,429,-857C353,-854,287,-813,231,-734C175,-655,146,-554,143,-429C146,-304,175,-202,231,-123C287,-44,353,-3,429,0Z",
  "M-714,-500C-754,-499,-788,-484,-815,-458C-841,-431,-856,-397,-857,-357L-857,643C-856,683,-842,717,-815,743C-788,770,-754,784,-714,786L714,786C754,784,788,770,815,743C841,716,856,683,857,643L857,-357C856,-397,842,-431,815,-458C788,-484,754,-498,714,-500L-714,-500ZM-714,-643L714,-643C795,-641,862,-613,916,-559C971,-505,998,-437,1000,-357L1000,643C999,723,971,791,916,845C862,899,795,927,714,929L-714,929C-795,927,-862,899,-916,845C-971,791,-998,723,-1000,643L-1000,-357C-999,-438,-971,-505,-916,-559C-862,-613,-795,-641,-714,-643ZM71,71L286,71C307,71,324,78,337,92C350,105,357,122,357,143C357,164,350,181,337,194C324,208,307,214,286,214L71,214L71,429C71,449,65,467,51,480C38,493,21,500,0,500C-21,500,-38,493,-51,480C-65,467,-71,449,-71,429L-71,214L-286,214C-307,214,-324,208,-337,194C-350,181,-357,164,-357,143C-357,122,-350,105,-337,92C-324,78,-307,71,-286,71L-71,71L-71,-143C-71,-164,-65,-181,-51,-194C-38,-208,-21,-214,0,-214C21,-214,38,-208,51,-194C65,-181,71,-164,71,-143L71,71ZM-357,-786L-357,-643L357,-643L357,-786L-357,-786ZM-429,-929L429,-929C449,-929,467,-922,480,-908C493,-895,500,-878,500,-857L500,-571C500,-551,493,-533,480,-520C467,-507,449,-500,429,-500L-429,-500C-449,-500,-467,-507,-480,-520C-493,-533,-500,-551,-500,-571L-500,-857C-500,-878,-493,-895,-480,-908C-467,-922,-449,-929,-429,-929Z",
  "M-571,-429L571,-429C571,-604,544,-747,489,-857L-480,-857C-541,-714,-571,-572,-571,-429ZM554,-286L-554,-286C-518,-158,-450,-55,-349,22C-249,100,-132,140,0,143C132,140,249,100,349,22C450,-55,518,-158,554,-286ZM71,281L71,857L286,857C307,857,324,864,337,877C350,891,357,908,357,929C357,949,350,967,337,980C324,993,307,1000,286,1000L-286,1000C-307,1000,-324,993,-337,980C-350,967,-357,949,-357,929C-357,908,-350,891,-337,877C-324,864,-307,857,-286,857L-71,857L-71,281C-257,259,-410,182,-529,50C-648,-81,-710,-241,-714,-429C-714,-619,-667,-810,-571,-1000L571,-1000C667,-857,714,-667,714,-429C710,-241,648,-81,529,50C410,182,257,259,71,281Z",
  "M-867,-274L-867,-277C-865,-410,-829,-531,-757,-638C-686,-745,-588,-824,-465,-875C-342,-926,-217,-939,-91,-914C34,-889,145,-830,242,-737C317,-773,394,-787,473,-780C552,-772,625,-744,692,-695C759,-646,807,-585,836,-510C866,-436,874,-358,860,-277C902,-272,936,-253,962,-220C987,-187,997,-150,991,-110C925,285,763,534,506,638L506,735C504,796,483,848,442,888C402,929,351,950,289,951L-289,951C-351,950,-402,929,-442,888C-483,848,-504,796,-506,735L-506,638C-763,534,-925,285,-991,-110C-997,-149,-988,-184,-964,-217C-940,-249,-907,-268,-867,-274ZM-722,-277L-578,-277C-575,-379,-539,-464,-472,-532C-404,-599,-319,-635,-217,-638C-114,-635,-29,-599,38,-532C106,-464,142,-379,145,-277L289,-277C286,-420,237,-539,141,-634C46,-730,-74,-779,-217,-782C-360,-779,-479,-730,-574,-634C-670,-539,-719,-420,-722,-277ZM-433,-277L0,-277C-1,-338,-22,-389,-63,-430C-104,-471,-155,-491,-217,-491C-278,-491,-329,-471,-370,-430C-411,-389,-432,-338,-433,-277ZM558,-277L713,-277C724,-320,725,-363,716,-406C707,-449,689,-489,661,-525C634,-561,601,-589,561,-608C521,-628,479,-638,433,-638C399,-638,366,-632,334,-620C361,-579,382,-535,397,-489C426,-496,454,-495,481,-485C508,-476,530,-459,549,-436C567,-412,576,-386,578,-358C579,-329,573,-302,558,-276ZM361,662L-361,662L-361,735C-361,756,-354,773,-341,787C-327,800,-310,807,-289,807L289,807C310,807,327,800,341,787C354,773,361,756,361,735L361,662ZM-413,518L413,518C528,482,621,410,693,304C765,197,816,51,847,-132L-846,-132C-816,52,-765,197,-693,304C-621,410,-527,482,-413,518Z",
  "M-846,-1000L-385,-1000C-362,-998,-344,-990,-329,-976C-315,-961,-308,-943,-308,-922C-308,-900,-315,-882,-329,-868C-344,-853,-362,-846,-385,-846L-846,-846L-846,-385C-846,-362,-853,-344,-868,-329C-882,-315,-901,-308,-923,-308C-946,-308,-964,-315,-978,-329C-993,-344,-1000,-362,-1000,-385L-1000,-1000L-846,-1000ZM-846,1000L-1000,1000L-1000,385C-1000,362,-993,344,-978,329C-964,315,-946,308,-923,308C-901,308,-882,315,-868,329C-853,344,-846,362,-846,385L-846,846L-385,846C-362,846,-344,853,-329,868C-315,882,-308,900,-308,922C-308,943,-315,962,-329,976C-344,990,-362,998,-385,1000L-846,1000ZM846,-1000L1000,-1000L1000,-385C1000,-362,993,-344,978,-329C964,-315,946,-308,923,-308C901,-308,882,-315,868,-329C853,-344,846,-362,846,-385L846,-846L385,-846C362,-846,344,-853,329,-868C315,-882,308,-900,308,-922C308,-943,315,-962,329,-976C344,-990,362,-998,385,-1000L846,-1000ZM846,1000L385,1000C362,998,344,990,329,976C315,961,308,943,308,922C308,900,315,882,329,868C344,853,362,846,385,846L846,846L846,385C846,362,853,344,868,329C882,315,901,308,923,308C946,308,964,315,978,329C993,344,1000,362,1000,385L1000,1000L846,1000Z",
  "M-571,-538L-536,-516L-507,-496C-428,-449,-342,-427,-250,-429C-217,-427,-186,-433,-157,-448C-128,-462,-92,-486,-47,-520C11,-565,62,-597,105,-616C148,-635,196,-644,250,-643C311,-643,367,-632,419,-609C470,-587,519,-556,567,-516L571,-511L571,-857L-571,-857L-571,-538ZM-569,-368C-559,-215,-507,-92,-414,0C-321,92,-183,140,0,143C176,141,310,98,402,13C494,-72,548,-185,565,-326C535,-351,505,-378,475,-406C440,-438,404,-461,367,-477C331,-492,291,-500,248,-500C215,-502,184,-495,154,-481C124,-467,86,-442,40,-406L38,-406C-17,-363,-66,-332,-108,-312C-151,-293,-198,-284,-250,-286C-311,-286,-368,-293,-421,-307C-474,-321,-523,-342,-569,-368ZM-71,283C-323,255,-494,166,-586,17C-677,-133,-720,-281,-714,-429L-714,-929C-714,-949,-708,-967,-694,-980C-681,-993,-664,-1000,-643,-1000L643,-1000C664,-1000,681,-993,694,-980C708,-967,714,-949,714,-929L714,-429C720,-281,677,-133,586,17C494,166,323,255,71,283L71,857L286,857C307,857,324,864,337,877C350,891,357,908,357,929C357,949,350,967,337,980C324,993,307,1000,286,1000L-286,1000C-307,1000,-324,993,-337,980C-350,967,-357,949,-357,929C-357,908,-350,891,-337,877C-324,864,-307,857,-286,857L-71,857L-71,283Z",
  "M71,281L71,857L286,857C307,857,324,864,337,877C350,891,357,908,357,929C357,949,350,967,337,980C324,993,307,1000,286,1000L-286,1000C-307,1000,-324,993,-337,980C-350,967,-357,949,-357,929C-357,908,-350,891,-337,877C-324,864,-307,857,-286,857L-71,857L-71,281C-257,259,-410,182,-529,50C-648,-81,-710,-241,-714,-429C-714,-619,-667,-810,-571,-1000L571,-1000C667,-857,714,-667,714,-429C710,-241,648,-81,529,50C410,182,257,259,71,281ZM-571,-429C-567,-266,-511,-132,-404,-25C-297,82,-162,138,0,143C162,138,297,82,404,-25C511,-132,567,-266,571,-429C571,-604,544,-747,489,-857L-480,-857C-541,-714,-571,-572,-571,-429Z",
  "M-445,-481L-445,-532C-441,-665,-398,-775,-315,-863C-232,-951,-127,-997,0,-1000C126,-997,231,-951,315,-863C398,-775,441,-665,444,-532L444,-481L748,-481C768,-481,784,-475,797,-463C811,-451,819,-434,822,-414L954,919C957,941,951,960,936,976C922,992,903,1000,882,1000L-882,1000C-904,1000,-922,992,-936,976C-951,960,-957,941,-954,919L-822,-414C-819,-434,-811,-451,-797,-463C-784,-475,-768,-481,-748,-481L-444,-481ZM-296,-481L296,-481L296,-532C295,-623,266,-699,209,-759C153,-819,83,-850,0,-852C-83,-850,-153,-819,-210,-759C-266,-699,-295,-623,-296,-532L-296,-481ZM-445,-333L-681,-333L-799,852L798,852L680,-333L444,-333L444,-111C444,-89,437,-72,423,-58C410,-44,392,-37,370,-37C349,-37,331,-44,317,-58C303,-72,296,-89,296,-111L296,-333L-296,-333L-296,-111C-296,-89,-303,-72,-317,-58C-331,-44,-349,-37,-371,-37C-392,-37,-410,-44,-424,-58C-438,-72,-445,-89,-445,-111L-445,-333Z",
  "M857,109L857,71C851,-171,767,-373,606,-535C445,-696,243,-780,0,-786C-243,-780,-445,-696,-606,-535C-767,-373,-851,-171,-857,71L-857,109C-812,84,-765,71,-714,71C-664,71,-616,84,-571,110C-527,137,-492,171,-466,214C-441,257,-429,305,-429,357L-429,643C-430,723,-458,791,-512,845C-567,899,-634,927,-714,929C-795,927,-862,899,-916,845C-971,791,-998,723,-1000,643L-1000,71C-993,-211,-895,-447,-706,-635C-518,-823,-283,-921,0,-929C283,-921,518,-823,706,-635C895,-447,993,-211,1000,71L1000,643C999,723,971,791,916,845C862,899,795,927,714,929C634,927,567,899,512,845C458,791,430,723,429,643L429,357C429,305,441,257,466,214C492,171,527,137,571,110C616,84,664,71,714,71C765,71,812,84,857,109ZM857,357C856,317,842,283,815,257C788,230,754,217,714,216C674,216,641,230,614,257C587,284,573,317,571,357L571,643C573,683,587,717,614,743C641,770,674,783,714,784C754,784,788,770,815,743C842,716,856,683,857,643L857,357ZM-857,357L-857,643C-856,683,-842,717,-815,743C-788,770,-754,783,-714,784C-674,784,-641,770,-614,743C-587,716,-573,683,-571,643L-571,357C-573,317,-587,283,-614,257C-641,230,-674,217,-714,216C-754,216,-788,230,-815,257C-842,284,-856,317,-857,357Z",
  "M-722,-232L-722,856L722,856L722,-232L0,-835ZM-840,-323L-45,-984C-32,-995,-17,-1000,0,-1000C17,-1000,32,-995,45,-984L840,-323C858,-308,867,-289,867,-266L867,928C867,949,860,966,847,980C833,993,816,1000,795,1000L-795,1000C-816,1000,-833,993,-847,980C-860,966,-867,949,-867,928L-867,-266C-867,-289,-858,-308,-840,-323Z",
  "M-570,-28L28,570C45,586,65,594,87,594C109,594,129,586,146,570L684,33C782,-71,831,-190,831,-324C831,-458,782,-578,684,-684C578,-782,458,-831,324,-831C190,-831,71,-782,-33,-684L-570,-146C-586,-129,-594,-108,-594,-86C-594,-63,-586,-43,-570,-28ZM-212,570L-570,926C-621,975,-680,1000,-747,999C-814,998,-872,972,-922,922C-972,872,-998,814,-999,747C-1000,680,-975,621,-926,570L-570,212L-689,94C-736,43,-760,-18,-760,-87C-760,-156,-736,-216,-689,-265L-151,-802C-13,-934,146,-1000,325,-1000C505,-1000,664,-934,802,-802C934,-664,1000,-505,1000,-325C1000,-146,934,13,802,151L265,689C216,738,156,763,87,763C18,763,-43,738,-94,689ZM-331,449L-449,331L-808,689C-823,707,-831,726,-831,748C-831,770,-823,790,-806,806C-790,823,-770,831,-748,831C-726,831,-706,823,-689,808ZM325,-563C341,-545,349,-525,349,-503C349,-481,341,-462,325,-444L-151,33C-176,56,-204,63,-236,55C-267,47,-287,28,-295,-4C-303,-36,-296,-63,-273,-86L204,-563C222,-580,242,-589,265,-589C288,-589,308,-580,326,-563ZM563,-325C580,-308,589,-288,589,-265C589,-242,580,-222,563,-204L86,270C63,293,36,300,5,293C-25,285,-45,265,-54,233C-63,202,-56,174,-33,152L444,-325C460,-341,480,-349,503,-349C527,-349,547,-341,563,-325Z",
  "M-500,-71L500,-71L500,-213L-500,-213L-500,-71ZM-500,71L-500,178C-500,231,-490,281,-470,328C-449,376,-421,418,-384,456C-347,494,-305,522,-257,542C-210,561,-160,571,-107,571L107,571C160,571,210,561,257,542C305,522,347,494,384,456C421,418,449,376,470,328C490,281,500,231,500,178L500,71L-500,71ZM-571,-358L571,-358C591,-356,607,-349,621,-336C635,-323,642,-306,642,-287L642,178C638,330,586,456,485,557C385,659,259,711,107,713L-107,713C-179,713,-248,700,-313,674C-378,647,-435,608,-485,557C-536,507,-574,449,-601,384C-629,319,-642,250,-642,178L-642,-287C-642,-306,-635,-323,-621,-336C-607,-349,-590,-356,-571,-358ZM0,-1000C20,-1000,36,-993,50,-979C64,-965,71,-948,71,-929L71,-571C71,-552,64,-535,51,-521C38,-507,21,-500,0,-500C-21,-500,-38,-507,-51,-521C-65,-535,-71,-552,-71,-571L-71,-929C-71,-948,-64,-965,-50,-979C-36,-993,-20,-1000,0,-1000ZM-287,-858C-266,-856,-249,-849,-235,-836C-222,-823,-215,-805,-213,-785L-213,-571C-215,-552,-222,-535,-235,-521C-249,-507,-265,-500,-286,-500C-306,-500,-322,-507,-336,-521C-349,-535,-356,-552,-358,-571L-358,-785C-356,-805,-349,-823,-336,-836C-322,-849,-306,-856,-287,-858ZM287,-858C306,-856,322,-849,336,-836C349,-823,356,-805,358,-785L358,-571C356,-552,349,-535,336,-521C322,-507,306,-500,285,-500C265,-500,249,-507,235,-521C222,-535,215,-552,213,-571L213,-785C215,-805,222,-823,235,-836C249,-849,266,-856,287,-858ZM-713,858L713,858C734,858,751,864,765,878C778,891,785,908,785,928C785,948,778,965,765,979C751,993,734,1000,713,1000L-713,1000C-734,1000,-751,993,-765,979C-778,965,-785,948,-785,928C-785,908,-778,891,-765,878C-751,864,-734,858,-713,858Z",
  "M504,-487L427,-500L398,-575C362,-663,306,-731,230,-781C154,-831,68,-853,-27,-847C-121,-841,-204,-808,-274,-750C-345,-691,-392,-616,-415,-522L-438,-433L-529,-418C-625,-399,-703,-354,-762,-283C-821,-213,-852,-129,-853,-31C-850,80,-812,172,-739,246C-665,319,-573,357,-462,360L427,360C539,357,635,320,713,249C792,178,838,86,851,-27C859,-139,830,-238,767,-323C703,-409,616,-463,505,-487ZM996,-67C991,95,935,229,828,336C720,442,587,498,427,502L-462,502C-535,502,-603,489,-668,462C-732,436,-790,397,-840,347C-890,296,-929,239,-955,173C-982,108,-996,40,-996,-31C-994,-164,-953,-279,-871,-376C-790,-472,-684,-533,-553,-558C-521,-679,-458,-779,-366,-858C-273,-936,-163,-980,-36,-989C90,-996,204,-967,307,-901C409,-835,484,-744,531,-627C667,-597,778,-531,863,-429C949,-327,993,-206,996,-67ZM-640,644C-619,644,-602,651,-589,664C-575,678,-569,695,-569,716L-569,929C-569,950,-575,967,-589,980C-602,993,-619,1000,-640,1000C-661,1000,-678,993,-691,980C-704,967,-711,950,-711,929L-711,716C-711,695,-704,678,-691,664C-678,651,-661,644,-640,644ZM-213,644C-193,644,-175,651,-162,664C-149,678,-142,695,-142,716L-142,929C-142,950,-149,967,-162,980C-175,993,-193,1000,-213,1000C-234,1000,-251,993,-264,980C-278,967,-284,950,-284,929L-284,716C-284,695,-278,678,-264,664C-251,651,-234,644,-213,644ZM213,644C234,644,251,651,264,664C278,678,284,695,284,716L284,929C284,950,278,967,264,980C251,993,234,1000,213,1000C193,1000,176,993,162,980C149,967,142,950,142,929L142,716C142,695,149,678,162,664C176,651,193,644,213,644ZM640,644C661,644,678,651,691,664C704,678,711,695,711,716L711,929C711,950,704,967,691,980C678,993,661,1000,640,1000C619,1000,602,993,589,980C576,967,569,950,569,929L569,716C569,695,576,678,589,664C602,651,619,644,640,644Z",
  "M0,-67L0,200L500,200L533,-67L0,-67ZM-133,-67L-533,-67L-500,200L-133,200L-133,-67ZM0,-598L0,-200L517,-200C483,-319,420,-415,326,-487C232,-560,124,-596,0,-598ZM-133,-581C-228,-556,-309,-510,-376,-443C-444,-375,-490,-294,-517,-200L-133,-200L-133,-581ZM0,-731C161,-728,301,-679,421,-582C540,-486,617,-358,652,-200L800,-200C819,-200,835,-194,848,-181C860,-169,867,-153,867,-133C867,-114,860,-98,848,-85C835,-73,819,-67,800,-67L667,-67L548,883C542,917,527,944,503,966C479,987,450,999,417,1000L-417,1000C-450,999,-479,987,-503,966C-527,944,-542,917,-548,883L-667,-67L-800,-67C-819,-67,-835,-73,-848,-85C-860,-98,-867,-114,-867,-133C-867,-153,-860,-169,-848,-181C-835,-194,-819,-200,-800,-200L-652,-200C-624,-332,-564,-444,-471,-536C-378,-629,-265,-690,-133,-719L-133,-800C-132,-857,-112,-904,-75,-942C-37,-979,10,-999,67,-1000L333,-1000C353,-1000,369,-994,381,-981C394,-969,400,-953,400,-933C400,-914,394,-898,381,-885C369,-873,353,-867,333,-867L67,-867C47,-867,31,-860,19,-848C6,-835,0,-819,0,-800L0,-731ZM483,333L-483,333L-417,867L417,867Z",
  "M-819,-177C-809,-289,-766,-383,-690,-459C-613,-534,-519,-577,-406,-587C-386,-710,-331,-809,-239,-886C-148,-962,-40,-999,86,-998C211,-991,316,-946,401,-864C486,-782,534,-679,546,-553C624,-520,687,-470,736,-403C784,-336,812,-261,819,-176L821,-176L79,970C65,990,46,1000,21,1000C-3,1000,-21,990,-34,970L-821,-176L-819,-176ZM-682,-177L-71,-177C-81,-256,-114,-322,-171,-372C-228,-423,-297,-449,-376,-450C-456,-449,-525,-423,-582,-372C-639,-322,-672,-256,-682,-177ZM68,-177L682,-177C671,-256,637,-322,581,-372C525,-423,456,-449,374,-450C295,-449,226,-423,170,-372C114,-322,80,-256,69,-177ZM-563,-40L19,810L569,-40L-563,-40ZM0,-380C44,-450,102,-503,173,-539C245,-576,322,-592,404,-587C386,-669,345,-734,282,-785C220,-836,146,-860,62,-859C-22,-857,-94,-830,-155,-778C-216,-725,-254,-657,-270,-574C-212,-560,-161,-536,-116,-503C-70,-469,-31,-428,0,-380Z",
  "M-130,-134L-130,-929C-130,-948,-123,-965,-109,-979C-95,-993,-79,-1000,-60,-1000L365,-1000C385,-1000,402,-993,415,-980C429,-967,435,-950,435,-929C435,-909,429,-892,415,-878C402,-865,385,-859,365,-859L11,-859L11,-576L365,-576C385,-576,402,-569,415,-556C429,-543,435,-526,435,-505C435,-484,429,-467,415,-454C402,-441,385,-434,365,-434L11,-434L11,-151C164,-148,293,-97,398,2C502,102,561,227,575,379C580,532,537,664,445,776C353,887,232,954,82,976C-71,992,-206,958,-323,873C-439,788,-513,671,-546,520C-571,370,-545,234,-467,112C-390,-11,-278,-92,-130,-134ZM11,839C132,836,232,794,312,715C391,635,432,535,435,414C432,294,391,193,312,114C232,34,132,-7,11,-10C-110,-7,-210,34,-290,114C-369,193,-410,294,-413,414C-410,535,-369,635,-290,715C-210,794,-110,836,11,839Z",
  "M-215,287L358,287C378,287,396,280,409,267C422,254,429,237,429,216L429,-785C429,-806,422,-823,409,-837C396,-850,378,-857,358,-857L-358,-857C-378,-857,-396,-850,-409,-837C-422,-823,-429,-806,-429,-785L-429,216C-429,237,-422,254,-409,267C-396,280,-378,287,-358,287L-215,287ZM215,430L215,788C213,849,192,899,152,940C112,980,61,1000,0,1000C-61,1000,-112,980,-152,940C-192,899,-213,849,-215,788L-215,430L-358,430C-419,429,-469,408,-509,368C-550,327,-571,277,-572,216L-572,-785C-571,-847,-550,-897,-509,-937C-469,-978,-419,-999,-358,-1000L358,-1000C419,-999,469,-978,509,-937C550,-897,571,-847,572,-785L572,216C571,277,550,327,509,368C469,408,419,429,358,430L215,430ZM72,430L-72,430L-72,788C-72,809,-65,826,-51,839C-38,853,-21,859,0,859C21,859,38,853,51,839C65,826,72,809,72,788L72,430Z",
  "M-500,-225L-500,-929C-500,-949,-493,-967,-480,-980C-467,-993,-449,-1000,-429,-1000C-408,-1000,-391,-993,-377,-980C-364,-967,-357,-949,-357,-929L-357,-225C-314,-242,-279,-268,-253,-305C-227,-341,-214,-382,-214,-429L-214,-929C-214,-949,-208,-966,-194,-980C-181,-993,-164,-1000,-143,-1000C-122,-1000,-105,-993,-91,-980C-78,-966,-71,-949,-71,-929L-71,-429C-73,-342,-100,-267,-152,-203C-204,-139,-272,-97,-357,-78L-357,929C-357,949,-364,967,-377,980C-391,993,-408,1000,-429,1000C-449,1000,-467,993,-480,980C-493,967,-500,949,-500,929L-500,-78C-585,-97,-653,-139,-705,-203C-757,-267,-784,-342,-786,-429L-786,-929C-786,-949,-779,-966,-766,-980C-752,-993,-735,-1000,-714,-1000C-693,-1000,-676,-993,-663,-980C-650,-966,-643,-949,-643,-929L-643,-429C-643,-382,-630,-341,-604,-305C-578,-268,-543,-242,-500,-225ZM357,-786L357,71L641,71C633,-104,612,-259,576,-393C545,-515,472,-646,357,-786ZM357,214L357,929C357,949,350,966,337,980C324,993,307,1000,286,1000C265,1000,248,993,234,980C221,966,214,949,214,929L214,-1000L357,-1000C548,-801,667,-610,714,-429C762,-247,786,-33,786,214L357,214Z",
  "M-654,-458C-621,-618,-545,-748,-425,-847C-306,-946,-164,-997,0,-1000C164,-997,306,-946,425,-847C544,-748,621,-618,654,-458C699,-446,734,-422,760,-387C787,-353,800,-312,800,-267L800,-133C799,-87,785,-47,758,-11C732,24,696,48,650,60L548,883C542,917,527,944,503,966C479,987,449,999,415,1000L-415,1000C-449,999,-479,987,-503,966C-527,944,-542,917,-548,883L-650,60C-696,48,-732,24,-758,-11C-785,-47,-799,-87,-800,-133L-800,-267C-800,-312,-787,-353,-760,-387C-734,-422,-699,-446,-654,-458ZM-517,-467L517,-467C483,-586,420,-682,326,-754C232,-826,124,-864,0,-867C-124,-864,-232,-826,-326,-754C-420,-682,-483,-586,-517,-467ZM514,67L-515,67L-415,867L414,867ZM-600,-67L600,-67C619,-67,635,-73,648,-85C660,-98,667,-114,667,-133L667,-267C667,-286,660,-302,648,-315C635,-327,619,-333,600,-333L-600,-333C-620,-333,-636,-327,-648,-315C-661,-302,-667,-286,-667,-267L-667,-133C-667,-114,-661,-98,-648,-85C-636,-73,-620,-67,-600,-67ZM-267,333L-133,333L-133,467L-267,467L-267,333ZM133,467L267,467L267,600L133,600L133,467ZM-133,600L0,600L0,733L-133,733L-133,600ZM0,200L133,200L133,333L0,333L0,200Z",
  "M0,-1000C283,-993,518,-895,706,-706C895,-518,993,-283,1000,0C993,283,895,518,706,706C518,895,283,993,0,1000C-283,993,-518,895,-706,706C-895,518,-993,283,-1000,0C-993,-283,-895,-518,-706,-706C-518,-895,-283,-993,0,-1000ZM150,-386C188,-386,220,-398,246,-421C271,-444,284,-475,284,-513C284,-552,271,-583,246,-606C220,-629,189,-641,151,-641C113,-641,81,-629,56,-606C31,-583,18,-552,18,-513C18,-475,31,-444,56,-421C81,-398,112,-386,150,-386ZM176,417C176,408,177,397,179,382C180,367,180,353,179,339L60,475C48,489,36,499,23,507C11,514,0,516,-9,513C-22,507,-28,497,-27,482L170,-136C177,-178,170,-214,150,-243C129,-273,95,-291,49,-297C-3,-295,-60,-273,-122,-231C-183,-189,-237,-135,-284,-69L-284,-36C-285,-21,-285,-7,-284,7L-165,-129C-153,-143,-141,-153,-128,-161C-116,-168,-106,-170,-98,-167C-83,-160,-78,-148,-83,-132L-277,484C-287,522,-282,555,-261,584C-240,613,-204,633,-152,643C-77,641,-15,620,36,578C86,537,133,483,176,418Z",
  "M71,-708C115,-699,154,-683,191,-660C227,-637,259,-607,286,-571C336,-637,400,-680,476,-701C553,-722,630,-717,706,-685C783,-654,841,-604,881,-535C920,-466,934,-390,923,-308C912,-226,878,-157,821,-102C765,-46,695,-13,612,-2C635,50,646,104,643,161C640,217,624,270,596,320C568,370,530,410,483,441C436,471,384,490,326,498C359,575,365,653,346,730C327,807,284,872,219,923C153,974,80,1000,0,1000C-80,1000,-153,974,-219,923C-284,872,-327,807,-346,730C-365,653,-359,575,-326,498C-384,490,-436,471,-483,441C-530,410,-568,370,-596,320C-624,270,-640,217,-643,161C-646,104,-635,50,-612,-2C-695,-13,-765,-46,-821,-102C-878,-157,-912,-226,-923,-308C-934,-390,-920,-465,-881,-535C-841,-604,-783,-654,-706,-685C-630,-717,-553,-722,-476,-701C-400,-680,-336,-637,-286,-571C-259,-607,-227,-637,-191,-660C-154,-683,-115,-699,-71,-708L-71,-857L-214,-857C-235,-857,-252,-864,-266,-877C-279,-891,-286,-908,-286,-929C-286,-949,-279,-967,-266,-980C-252,-993,-235,-1000,-214,-1000L214,-1000C235,-1000,252,-993,266,-980C279,-967,286,-949,286,-929C286,-908,279,-891,266,-877C252,-864,235,-857,214,-857L72,-857L72,-708ZM0,-143C61,-144,112,-165,152,-205C192,-246,212,-296,212,-357C212,-418,192,-469,152,-509C112,-549,61,-569,0,-569C-61,-569,-112,-549,-152,-509C-192,-469,-212,-418,-212,-357C-212,-296,-192,-246,-152,-205C-112,-165,-61,-144,0,-143ZM-571,-143C-510,-144,-460,-165,-420,-205C-380,-246,-359,-296,-359,-357C-359,-418,-380,-469,-420,-509C-460,-549,-510,-569,-571,-569C-632,-569,-683,-549,-723,-509C-763,-469,-784,-418,-784,-357C-784,-296,-763,-246,-723,-205C-683,-165,-632,-144,-571,-143ZM-286,357C-225,356,-174,335,-134,295C-94,254,-74,204,-74,143C-74,82,-94,31,-134,-9C-174,-49,-225,-69,-286,-69C-347,-69,-397,-49,-438,-9C-478,31,-498,82,-498,143C-498,204,-478,254,-438,295C-397,335,-347,356,-286,357ZM0,857C61,856,112,835,152,795C192,754,212,704,212,643C212,582,192,531,152,491C112,451,61,431,0,431C-61,431,-112,451,-152,491C-192,531,-212,582,-212,643C-212,704,-192,754,-152,795C-112,835,-61,856,0,857ZM286,357C347,356,397,335,437,295C478,254,498,204,498,143C498,82,478,31,437,-9C397,-49,347,-69,286,-69C225,-69,174,-49,134,-9C94,31,74,82,74,143C74,204,94,254,134,295C174,335,225,356,286,357ZM571,-143C632,-144,683,-165,723,-205C763,-246,783,-296,783,-357C783,-418,763,-469,723,-509C683,-549,632,-569,571,-569C510,-569,460,-549,420,-509C379,-469,359,-418,359,-357C359,-296,379,-246,420,-205C460,-165,510,-144,571,-143Z",
  "M504,-487L427,-500L398,-575C362,-663,306,-731,230,-781C154,-831,68,-853,-27,-847C-121,-841,-204,-808,-274,-750C-345,-691,-392,-616,-415,-522L-438,-433L-529,-418C-625,-399,-703,-354,-762,-283C-821,-213,-852,-129,-853,-31C-850,80,-812,172,-739,246C-665,319,-573,357,-462,360L427,360C539,357,635,320,713,249C792,178,838,86,851,-27C859,-139,830,-238,767,-323C703,-409,616,-463,505,-487ZM996,-67C991,95,935,229,828,336C720,442,587,498,427,502L-462,502C-535,502,-603,489,-668,462C-732,436,-790,397,-840,347C-890,296,-929,239,-955,173C-982,108,-996,40,-996,-31C-994,-164,-953,-279,-871,-376C-790,-472,-684,-533,-553,-558C-521,-679,-458,-779,-366,-858C-273,-936,-163,-980,-36,-989C90,-996,204,-967,307,-901C409,-835,484,-744,531,-627C667,-597,778,-531,863,-429C949,-327,993,-206,996,-67ZM-498,644L-355,644L-355,787L-498,787L-498,644ZM-71,644L71,644L71,787L-71,787L-71,644ZM-284,858L-142,858L-142,1000L-284,1000L-284,858ZM142,858L284,858L284,1000L142,1000L142,858ZM356,644L498,644L498,787L356,787L356,644Z",
  "M-643,-143C-664,-143,-681,-136,-694,-123C-708,-109,-714,-92,-714,-71L-714,786C-714,807,-708,824,-694,837C-681,850,-664,857,-643,857L643,857C664,857,681,850,694,837C708,824,714,807,714,786L714,-71C714,-92,708,-109,694,-123C681,-136,664,-143,643,-143L-643,-143ZM-643,-286L643,-286C704,-284,754,-263,795,-223C835,-183,856,-132,857,-71L857,786C856,847,835,897,795,938C754,978,704,999,643,1000L-643,1000C-704,999,-754,978,-795,938C-835,897,-856,847,-857,786L-857,-71C-856,-132,-835,-183,-795,-223C-754,-263,-704,-284,-643,-286ZM0,71C21,71,38,78,51,92C65,105,71,122,71,143L71,571C71,592,65,609,51,623C38,636,21,643,0,643C-21,643,-38,636,-51,623C-65,609,-71,592,-71,571L-71,143C-71,122,-65,105,-51,92C-38,78,-21,71,0,71ZM429,-286L429,-429C426,-551,384,-652,304,-732C223,-812,122,-854,0,-857C-122,-854,-223,-812,-304,-732C-384,-652,-426,-551,-429,-429L-429,-286L429,-286ZM0,-1000C162,-996,297,-940,404,-833C511,-725,567,-591,571,-429L571,-143L-571,-143L-571,-429C-567,-591,-511,-725,-404,-833C-297,-940,-162,-996,0,-1000Z",
  "M643,-214C638,-396,575,-547,454,-668C333,-790,182,-853,0,-857C-182,-853,-333,-790,-454,-668C-575,-547,-638,-396,-643,-214C-643,-82,-590,70,-483,240C-377,410,-216,599,0,806C216,599,377,410,483,240C590,70,643,-82,643,-214ZM0,1000C-524,524,-786,119,-786,-214C-780,-438,-703,-623,-556,-770C-408,-917,-223,-994,0,-1000C223,-994,409,-917,556,-770C703,-623,780,-437,786,-214C786,119,524,524,0,1000ZM0,0C61,-1,112,-22,152,-62C192,-103,212,-153,212,-214C212,-275,192,-326,152,-366C112,-406,61,-426,0,-426C-61,-426,-112,-406,-152,-366C-192,-326,-212,-275,-212,-214C-212,-153,-192,-103,-152,-62C-112,-22,-61,-1,0,0ZM0,143C-101,140,-185,105,-252,38C-319,-29,-354,-113,-357,-214C-354,-315,-319,-400,-252,-466C-185,-533,-101,-568,0,-571C101,-568,185,-533,252,-466C319,-400,354,-315,357,-214C354,-113,319,-29,252,38C185,105,101,140,0,143Z",
  "M-498,355L-498,497C-641,485,-759,429,-851,330C-944,231,-991,110,-994,-33C-993,-166,-952,-281,-870,-377C-789,-473,-683,-534,-553,-559C-521,-680,-458,-780,-366,-858C-273,-936,-164,-980,-37,-989C89,-996,203,-967,305,-901C407,-836,482,-744,529,-628C669,-598,782,-530,867,-425C952,-319,993,-195,990,-51C984,91,936,212,845,312C754,413,637,474,496,494L496,350C599,331,683,283,748,207C813,131,847,41,850,-64C849,-171,816,-262,753,-339C689,-416,606,-466,502,-488L425,-501L396,-577C360,-664,305,-732,228,-782C152,-831,67,-853,-28,-847C-122,-841,-205,-809,-275,-751C-345,-692,-392,-617,-416,-524L-438,-435L-529,-419C-625,-400,-702,-355,-761,-285C-821,-215,-851,-131,-852,-33C-851,72,-817,160,-750,231C-684,303,-599,344,-497,354ZM-214,499C-241,497,-261,485,-274,462C-287,439,-288,416,-276,392L8,-104C23,-128,43,-140,70,-140C96,-140,117,-128,131,-104C145,-81,145,-57,132,-33L-92,357L212,357C238,358,258,371,272,394C285,417,286,440,274,463L-10,960C-20,978,-35,989,-53,993C-72,998,-90,995,-108,986C-125,976,-136,962,-141,943C-145,925,-143,907,-134,889L90,499L-214,499Z",
  "M31,-1000L180,-1000L180,-553L31,-553L31,-1000ZM31,341L180,341L180,788L31,788L31,341ZM-788,-31L-788,-180L-341,-180L-341,-31L-788,-31ZM553,-31L553,-180L1000,-180L1000,-31L553,-31ZM-579,-686L-474,-790L-157,-474L-262,-369ZM369,262L474,157L790,474L686,579ZM-895,1000L-1000,895L-262,157L-157,262ZM474,-369L369,-474L686,-790L790,-686Z",
  "M534,296L414,178L652,-60C750,-163,804,-276,815,-398C827,-520,792,-625,712,-712C625,-792,520,-827,398,-815C276,-804,163,-749,60,-652L-178,-414L-296,-534L-60,-770C78,-901,230,-972,398,-983C566,-994,709,-943,830,-830C943,-709,994,-566,983,-398C972,-230,901,-78,770,60ZM296,534L60,770C-78,901,-230,972,-398,983C-566,994,-709,943,-830,830C-943,709,-994,566,-983,398C-972,230,-901,78,-770,-60L-534,-296L-414,-178L-652,60C-750,163,-804,276,-815,398C-827,520,-792,625,-712,712C-625,792,-520,827,-398,815C-276,804,-163,749,-60,652L178,414ZM296,-414L414,-296L-296,414L-414,296Z",
  "M-77,-72C-83,-115,-75,-153,-53,-186C-31,-219,1,-240,43,-248C84,-257,122,-251,155,-230C188,-208,209,-177,219,-135C228,-93,222,-55,200,-21C178,13,146,35,105,46C132,90,169,122,215,140C262,158,310,160,360,146C409,131,450,105,480,65C511,26,527,-20,527,-72L678,-72C675,35,638,124,567,195C496,266,407,303,299,306C192,303,103,266,32,195C-39,124,-76,35,-79,-72L-77,-72ZM-377,-143C-354,5,-290,127,-186,223C-82,318,45,371,193,382C341,387,472,347,586,262C699,176,775,62,813,-82C845,-227,829,-363,767,-490C705,-617,606,-713,472,-777C335,-836,198,-846,62,-808C-75,-770,-187,-691,-273,-569C-179,-634,-76,-670,34,-677C145,-684,251,-661,353,-608C454,-555,534,-482,591,-387C647,-292,677,-187,678,-72L527,-72C523,-194,483,-297,406,-381C329,-466,229,-513,108,-524C-14,-532,-120,-501,-210,-430C-299,-359,-356,-263,-378,-143ZM-127,449L-614,936C-662,979,-715,1000,-774,999C-833,998,-885,975,-930,930C-975,885,-998,833,-999,774C-1000,715,-979,661,-936,614L-449,127C-534,-45,-556,-219,-515,-395C-474,-571,-377,-718,-224,-834C-67,-945,101,-993,282,-979C462,-964,621,-891,759,-759C891,-621,964,-462,979,-282C993,-101,945,67,834,224C717,377,571,474,395,515C219,556,45,534,-127,449ZM-254,363C-294,330,-330,294,-363,254L-830,723C-850,744,-856,768,-848,795C-841,823,-823,841,-795,848C-768,856,-744,850,-723,830Z",
  "M0,-1000C21,-1000,38,-993,51,-980C65,-967,71,-949,71,-929L71,-500C71,-479,65,-462,51,-449C38,-435,21,-429,0,-429C-21,-429,-38,-435,-51,-449C-65,-462,-71,-479,-71,-500L-71,-929C-71,-949,-65,-967,-51,-980C-38,-993,-21,-1000,0,-1000ZM0,429C21,429,38,435,51,449C65,462,71,479,71,500L71,929C71,949,65,967,51,980C38,993,21,1000,0,1000C-21,1000,-38,993,-51,980C-65,967,-71,949,-71,929L-71,500C-71,479,-65,462,-51,449C-38,435,-21,429,0,429ZM1000,0C1000,21,993,38,980,51C967,65,949,71,929,71L500,71C479,71,462,65,449,51C435,38,429,21,429,0C429,-21,435,-38,449,-51C462,-65,479,-71,500,-71L929,-71C949,-71,967,-65,980,-51C993,-38,1000,-21,1000,0ZM-429,0C-429,21,-435,38,-449,51C-462,65,-479,71,-500,71L-929,71C-949,71,-967,65,-980,51C-993,38,-1000,21,-1000,0C-1000,-21,-993,-38,-980,-51C-967,-65,-949,-71,-929,-71L-500,-71C-479,-71,-462,-65,-449,-51C-435,-38,-429,-21,-429,0ZM-708,-708C-693,-721,-676,-728,-656,-728C-637,-728,-621,-721,-607,-708L-304,-404C-290,-389,-283,-372,-283,-354C-283,-335,-291,-319,-305,-305C-319,-290,-335,-283,-354,-283C-372,-283,-389,-290,-404,-304L-708,-607C-721,-620,-728,-637,-728,-656C-728,-676,-721,-693,-708,-708ZM304,304C318,289,335,281,354,281C372,281,389,289,404,304L708,607C721,621,728,637,728,656C728,676,721,692,706,707C692,721,676,728,656,728C637,728,621,721,607,708L304,404C289,389,281,372,281,354C281,335,289,319,304,304ZM708,-708C721,-693,728,-676,728,-656C728,-637,721,-621,708,-607L404,-304C389,-290,372,-283,354,-283C335,-283,319,-291,305,-305C290,-319,283,-335,283,-354C283,-372,290,-389,304,-404L607,-708C620,-721,637,-728,656,-728C676,-728,693,-721,708,-708ZM-304,304C-289,318,-281,335,-281,354C-281,372,-289,389,-304,404L-607,708C-621,721,-637,728,-656,728C-676,728,-692,721,-707,706C-721,692,-728,676,-728,656C-728,637,-721,621,-708,607L-404,304C-389,289,-372,281,-354,281C-335,281,-319,289,-304,304Z",
  "M-10,480C189,480,350,319,350,120C350,-79,189,-240,-10,-240C-209,-240,-370,-79,-370,120C-370,319,-209,480,-10,480ZM-10,-80C100,-80,190,10,190,120C190,230,100,320,-10,320C-120,320,-210,230,-210,120C-210,10,-120,-80,-10,-80ZM800,-640L730,-640L640,-942C630,-976,599,-1000,564,-1000L-564,-1000C-600,-1000,-631,-976,-640,-942L-730,-640L-800,-640C-844,-640,-880,-604,-880,-560L-880,-490C-880,-479,-871,-470,-860,-470L-746,-470L-626,927C-623,968,-588,1000,-546,1000L526,1000C568,1000,603,968,606,927L726,-470L860,-470C871,-470,880,-479,880,-490L880,-560C880,-604,844,-640,800,-640ZM-496,-830L496,-830L552,-640L-552,-640L-496,-830ZM444,830L-464,830L-575,-470L555,-470L444,830Z",
  "M691,582L636,582L636,-191C636,-512,399,-777,91,-821L91,-909C91,-959,50,-1000,0,-1000C-50,-1000,-91,-959,-91,-909L-91,-821C-399,-777,-636,-512,-636,-191L-636,582L-691,582C-731,582,-764,614,-764,655L-764,727C-764,737,-755,745,-745,745L-255,745C-255,886,-140,1000,0,1000C140,1000,255,886,255,745L745,745C755,745,764,737,764,727L764,655C764,614,731,582,691,582ZM0,855C-60,855,-109,806,-109,745L109,745C109,806,60,855,0,855Z",
  "M620,-200L620,-920C620,-964,584,-1000,540,-1000L-540,-1000C-584,-1000,-620,-964,-620,-920L-620,-200C-786,-200,-920,-70,-920,90L-920,980C-920,991,-911,1000,-900,1000L-760,1000C-749,1000,-740,991,-740,980L-740,90C-740,29,-686,-20,-620,-20L620,-20C686,-20,740,29,740,90L740,980C740,991,749,1000,760,1000L900,1000C911,1000,920,991,920,980L920,90C920,-70,786,-200,620,-200ZM-440,-200L-440,-820L440,-820L440,-200L-440,-200ZM-140,-660L-260,-660C-271,-660,-280,-651,-280,-640L-280,-520C-280,-509,-271,-500,-260,-500L-140,-500C-129,-500,-120,-509,-120,-520L-120,-640C-120,-651,-129,-660,-140,-660ZM260,-660L140,-660C129,-660,120,-651,120,-640L120,-520C120,-509,129,-500,140,-500L260,-500C271,-500,280,-509,280,-520L280,-640C280,-651,271,-660,260,-660Z",
  "M-400,799C-400,843,-365,878,-322,878L322,878C365,878,400,843,400,799L400,319L-400,319L-400,799ZM902,-878L-902,-878C-962,-878,-1000,-812,-970,-760L-427,162L428,162L970,-760C1000,-812,962,-878,902,-878Z",
  "M891,-960L378,-960C334,-960,296,-931,286,-887C254,-756,137,-662,0,-662C-137,-662,-254,-756,-286,-887C-296,-931,-334,-960,-378,-960L-891,-960C-951,-960,-1000,-911,-1000,-851L-1000,-224C-1000,-163,-951,-114,-891,-114L-704,-114L-704,851C-704,911,-655,960,-595,960L595,960C655,960,704,911,704,851L704,-114L891,-114C951,-114,1000,-163,1000,-224L1000,-851C1000,-911,951,-960,891,-960ZM821,-294L525,-294L525,781L-525,781L-525,-294L-821,-294L-821,-781L-440,-781C-369,-604,-197,-483,0,-483C197,-483,369,-604,440,-781L821,-781L821,-294Z",
  "M718,-92C675,-190,613,-277,533,-349L469,-409C459,-417,444,-413,440,-401L411,-318C393,-266,359,-213,312,-160C309,-157,306,-156,303,-156C301,-156,297,-156,293,-159C290,-162,289,-166,289,-170C297,-304,257,-456,169,-620C97,-757,-4,-864,-131,-939L-223,-993C-235,-1000,-250,-991,-250,-977L-245,-870C-241,-796,-250,-732,-270,-678C-294,-612,-330,-551,-375,-496C-406,-458,-442,-423,-481,-393C-574,-321,-652,-227,-704,-122C-757,-16,-785,103,-785,222C-785,327,-764,429,-723,525C-684,618,-627,701,-555,772C-483,844,-399,900,-305,939C-209,979,-106,1000,0,1000C106,1000,209,979,305,939C399,900,483,844,555,773C627,701,684,618,723,525C764,429,785,327,785,222C785,113,763,7,718,-92Z",
  "M959,-12L106,-864L49,-921C22,-948,-22,-948,-49,-921L-958,-12C-985,15,-1000,51,-1000,90C-999,167,-934,229,-857,229L-763,229L-763,948L763,948L763,229L859,229C897,229,932,215,959,188C985,161,1000,126,1000,88C1000,50,985,15,959,-12ZM124,789L-123,789L-123,339L124,339L124,789ZM604,70L604,789L265,789L265,286C265,237,225,198,177,198L-176,198C-225,198,-265,237,-265,286L-265,789L-604,789L-604,70L-816,70L0,-745L51,-694L816,70L604,70Z",
  "M-430,181L430,181L638,-181L-638,-181ZM902,-878L-902,-878C-962,-878,-1000,-812,-970,-760L-728,-338L728,-338L970,-760C1000,-812,962,-878,902,-878ZM-400,799C-400,843,-365,878,-322,878L322,878C365,878,400,843,400,799L400,338L-400,338L-400,799Z",
  "M897,-117C970,-117,1000,-211,941,-254L44,-906L34,-912L23,-917L12,-920L0,-921L-12,-920L-23,-917L-34,-912L-44,-906L-941,-254C-1000,-211,-970,-117,-897,-117L-752,-117L-752,761L-921,761C-931,761,-939,769,-939,780L-939,902C-939,912,-931,921,-921,921L921,921C931,921,939,912,939,902L939,780C939,769,931,761,921,761L752,761L752,-117L897,-117ZM0,-741L637,-277L-637,-277L0,-741ZM-582,-117L-308,-117L-308,761L-582,761L-582,-117ZM-139,-117L136,-117L136,761L-139,761L-139,-117ZM582,761L305,761L305,-117L582,-117L582,761Z",
  "M-850,923C-850,965,-816,1000,-773,1000L-82,1000L-82,92L-850,92L-850,923ZM82,1000L773,1000C816,1000,850,965,850,923L850,92L82,92L82,1000ZM889,-488L532,-488C565,-540,585,-601,585,-667C585,-850,435,-1000,251,-1000C151,-1000,61,-956,0,-886C-61,-956,-151,-1000,-251,-1000C-435,-1000,-585,-850,-585,-667C-585,-601,-565,-540,-532,-488L-889,-488C-932,-488,-966,-453,-966,-411L-966,-72L-82,-72L-82,-488L82,-488L82,-72L966,-72L966,-411C966,-453,932,-488,889,-488ZM-82,-498L-251,-498C-344,-498,-420,-573,-420,-667C-420,-760,-344,-836,-251,-836C-158,-836,-82,-760,-82,-667L-82,-498ZM251,-498L82,-498L82,-667C82,-760,158,-836,251,-836C344,-836,420,-760,420,-667C420,-573,344,-498,251,-498Z",
  "M902,-878L-902,-878C-962,-878,-1000,-812,-970,-760L-400,209L-400,799C-400,843,-365,878,-322,878L322,878C365,878,400,843,400,799L400,209L970,-760C1000,-812,962,-878,902,-878ZM224,701L-224,701L-224,319L224,319L224,701ZM248,121L224,162L-224,162L-248,121L-734,-701L734,-701L248,121Z",
  "M575,-485L575,-820L790,-820C801,-820,810,-829,810,-840L810,-980C810,-991,801,-1000,790,-1000L-790,-1000C-801,-1000,-810,-991,-810,-980L-810,-840C-810,-829,-801,-820,-790,-820L-575,-820L-575,-485C-575,-281,-469,-102,-309,0C-469,102,-575,281,-575,485L-575,820L-790,820C-801,820,-810,829,-810,840L-810,980C-810,991,-801,1000,-790,1000L790,1000C801,1000,810,991,810,980L810,840C810,829,801,820,790,820L575,820L575,485C575,281,469,102,309,0C469,-102,575,-281,575,-485Z",
  "M902,-878L-902,-878C-962,-878,-1000,-812,-970,-760L-400,234L-400,799C-400,843,-365,878,-322,878L322,878C365,878,400,843,400,799L400,234L970,-760C1000,-812,962,-878,902,-878ZM224,701L-224,701L-224,338L224,338L224,701ZM248,146L227,181L-227,181L-248,146L-435,-181L435,-181L248,146ZM525,-338L-525,-338L-734,-701L734,-701L525,-338Z",
  "M945,-12L43,-914C15,-941,-29,-941,-56,-914L-959,-12C-985,14,-1000,50,-1000,87C-1000,165,-937,228,-860,228L-765,228L-765,871C-765,910,-733,941,-695,941L-147,941L-147,450L98,450L98,941L681,941C720,941,751,910,751,871L751,228L846,228C883,228,919,213,945,186C1000,132,1000,43,945,-12Z",
  "M907,53C948,-1,971,-67,971,-136C971,-245,910,-348,812,-405L792,-415L772,-422L750,-427L729,-428L147,-428L161,-726C165,-798,139,-867,90,-919C40,-971,-27,-1000,-100,-1000C-226,-1000,-337,-915,-371,-793L-579,-39L-893,-39C-936,-39,-971,-4,-971,39L-971,922C-971,965,-936,1000,-893,1000L566,1000C589,1000,610,996,631,987C746,938,821,825,821,700C821,669,816,639,807,610C848,556,871,490,871,421C871,391,866,361,858,331C898,278,921,212,921,143C921,112,916,82,907,53ZM-796,825L-796,136L-599,136L-599,825L-796,825ZM748,-31L695,15L729,76C740,97,746,119,746,143C746,183,728,221,698,247L645,293L679,355C690,375,696,397,696,421C696,461,678,499,648,525L595,571L629,633C640,653,645,676,645,699C645,754,613,803,564,825L-444,825L-444,128L-203,-747C-190,-793,-148,-825,-100,-825C-82,-825,-64,-820,-49,-809C-25,-791,-12,-764,-14,-735L-37,-253L726,-253C769,-227,796,-182,796,-136C796,-96,779,-58,748,-31Z",
  "M890,-880L660,-880L660,-980C660,-991,651,-1000,640,-1000L-640,-1000C-651,-1000,-660,-991,-660,-980L-660,-880L-890,-880C-951,-880,-1000,-831,-1000,-770L-1000,-400C-1000,-196,-850,-26,-654,5C-616,296,-382,524,-90,556L-90,819L-580,819C-624,819,-660,855,-660,899L-660,980C-660,991,-651,1000,-640,1000L640,1000C651,1000,660,991,660,980L660,899C660,855,624,819,580,819L90,819L90,556C382,524,616,296,654,5C850,-26,1000,-196,1000,-400L1000,-770C1000,-831,951,-880,890,-880ZM-660,-181C-753,-211,-820,-298,-820,-400L-820,-700L-660,-700L-660,-181ZM820,-400C820,-298,753,-210,660,-181L660,-700L820,-700L820,-400Z",
  "M908,-53C916,-82,921,-112,921,-143C921,-211,898,-277,857,-331C866,-360,870,-390,870,-421C870,-490,848,-556,807,-610C816,-639,820,-669,820,-699C820,-825,746,-938,630,-987C610,-996,588,-1000,566,-1000L-893,-1000C-936,-1000,-971,-965,-971,-922L-971,-39C-971,4,-936,39,-893,39L-579,39L-371,793C-338,915,-226,1000,-100,1000C-28,1000,40,971,89,919C139,867,165,798,161,726L146,428L729,428C758,428,787,420,812,405C910,348,971,245,971,136C971,67,948,1,908,-53ZM-796,-136L-796,-825L-600,-825L-600,-136L-796,-136ZM726,253L-37,253L-14,735C-12,764,-25,791,-49,809C-64,820,-82,825,-100,825C-148,825,-190,793,-203,747L-444,-128L-444,-825L564,-825C614,-803,646,-754,646,-700C646,-676,640,-654,629,-633L595,-572L648,-526C679,-499,696,-461,696,-421C696,-398,690,-375,679,-355L645,-293L699,-247C729,-221,746,-183,746,-143C746,-119,741,-97,729,-77L695,-15L749,31C779,58,796,96,796,136C796,182,770,227,726,253Z",
  "M0,-416C-67,-416,-130,-390,-178,-342C-225,-294,-252,-231,-252,-164C-252,-97,-225,-34,-178,14C-130,61,-67,88,0,88C67,88,130,61,178,14C226,-34,252,-97,252,-164C252,-231,226,-294,178,-342C130,-390,67,-416,0,-416ZM770,-501C728,-598,667,-686,590,-761C514,-836,424,-895,325,-936C222,-978,113,-1000,0,-1000C-113,-1000,-222,-978,-325,-936C-424,-895,-514,-836,-590,-761C-667,-686,-728,-598,-770,-501C-814,-400,-836,-293,-836,-182C-836,-23,-798,135,-723,287C-663,410,-580,529,-474,642C-294,836,-104,955,-51,986C-35,996,-18,1000,0,1000C17,1000,35,996,50,986C104,955,293,836,474,642C579,529,663,410,723,287C798,135,836,-23,836,-182C836,-292,814,-400,770,-501ZM0,232C-218,232,-396,55,-396,-164C-396,-382,-218,-560,0,-560C218,-560,396,-382,396,-164C396,55,218,232,0,232Z",
  "M800,-120L-450,-120L-450,-680C-450,-757,-387,-820,-310,-820L310,-820C387,-820,450,-757,450,-680L450,-510C450,-499,459,-490,470,-490L610,-490C621,-490,630,-499,630,-510L630,-680C630,-857,487,-1000,310,-1000L-310,-1000C-487,-1000,-630,-857,-630,-680L-630,-120L-800,-120C-844,-120,-880,-84,-880,-40L-880,920C-880,964,-844,1000,-800,1000L800,1000C844,1000,880,964,880,920L880,-40C880,-84,844,-120,800,-120ZM700,820L-700,820L-700,60L700,60L700,820ZM-70,472L-70,605C-70,616,-61,625,-50,625L50,625C61,625,70,616,70,605L70,472C100,451,120,415,120,375C120,309,66,255,0,255C-66,255,-120,309,-120,375C-120,415,-100,451,-70,472Z",
  "M668,-208C566,-478,306,-670,0,-670C-305,-670,-565,-478,-667,-208C-859,-158,-1000,16,-1000,223C-1000,470,-800,670,-554,670L554,670C800,670,1000,470,1000,223C1000,16,859,-158,668,-208Z",
  "M800,-120L630,-120L630,-680C630,-857,487,-1000,310,-1000L-310,-1000C-487,-1000,-630,-857,-630,-680L-630,-120L-800,-120C-844,-120,-880,-84,-880,-40L-880,920C-880,964,-844,1000,-800,1000L800,1000C844,1000,880,964,880,920L880,-40C880,-84,844,-120,800,-120ZM-450,-680C-450,-757,-387,-820,-310,-820L310,-820C387,-820,450,-757,450,-680L450,-120L-450,-120L-450,-680ZM700,820L-700,820L-700,60L700,60L700,820ZM-70,472L-70,605C-70,616,-61,625,-50,625L50,625C61,625,70,616,70,605L70,472C100,451,120,415,120,375C120,309,66,255,0,255C-66,255,-120,309,-120,375C-120,415,-100,451,-70,472Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0L-1000,938C-1000,972,-972,1000,-938,1000L-458,1000C-366,1000,-292,925,-292,833L-292,292C-292,200,-366,125,-458,125L-812,125L-812,0C-812,-449,-449,-812,0,-812C449,-812,812,-449,812,0L812,125L458,125C366,125,292,200,292,292L292,833C292,925,366,1000,458,1000L938,1000C972,1000,1000,972,1000,938L1000,0C1000,-552,552,-1000,0,-1000Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0L-1000,938C-1000,972,-972,1000,-938,1000L-458,1000C-366,1000,-292,925,-292,833L-292,292C-292,200,-366,125,-458,125L-812,125L-812,0C-812,-449,-449,-812,0,-812C449,-812,812,-449,812,0L812,125L458,125C366,125,292,200,292,292L292,833C292,925,366,1000,458,1000L938,1000C972,1000,1000,972,1000,938L1000,0C1000,-552,552,-1000,0,-1000ZM-479,312L-479,812L-812,812L-812,312L-479,312ZM812,812L479,812L479,312L812,312L812,812Z",
  "M-743,311L-637,377C-637,378,-636,378,-636,378L-604,398L-603,399C-533,440,-452,462,-368,462C-256,462,-150,422,-66,352C49,256,194,202,347,202C477,202,602,242,708,314L728,326L449,-396L449,-830L608,-830C619,-830,628,-839,628,-850L628,-980C628,-991,619,-1000,608,-1000L-629,-1000C-640,-1000,-649,-991,-649,-980L-649,-850C-649,-839,-640,-830,-629,-830L-470,-830L-470,-396L-743,311ZM89,-197C144,-197,189,-152,189,-97C189,-42,144,3,89,3C34,3,-11,-42,-11,-97C-11,-152,34,-197,89,-197ZM904,783L830,589L615,456L615,456C613,455,611,453,610,452L589,440L589,439C516,395,433,372,346,372C234,372,128,411,44,481C-71,577,-216,631,-369,631C-501,631,-627,591,-734,517L-806,472L-926,783C-933,801,-936,821,-936,840C-936,928,-865,1000,-777,1000L755,1000C775,1000,795,996,813,989C895,958,936,865,904,783Z",
  "M920,-518L280,-518L280,-800C280,-844,244,-880,200,-880L-820,-880L-820,-980C-820,-991,-829,-1000,-840,-1000L-980,-1000C-991,-1000,-1000,-991,-1000,-980L-1000,980C-1000,991,-991,1000,-980,1000L-840,1000C-829,1000,-820,991,-820,980L-820,320L-200,320L-200,602C-200,647,-164,682,-120,682L920,682C964,682,1000,647,1000,602L1000,-438C1000,-482,964,-518,920,-518ZM-820,140L-820,-700L100,-700L100,140L-820,140ZM820,502L-20,502L-20,320L260,320C271,320,280,311,280,300L280,-338L820,-338L820,502Z",
  "M-9,0ZM-265,0L-261,44L-249,87L-231,128L-205,164L-174,196L-137,221L-97,240L-54,252L-9,256L35,252L78,240L119,221L155,196L187,164L212,128L231,87L243,44L247,0L243,-44L231,-87L212,-128L187,-164L155,-196L119,-221L78,-240L35,-252L-9,-256L-54,-252L-97,-240L-137,-221L-174,-196L-205,-164L-231,-128L-249,-87L-261,-44L-265,0ZM982,-59C766,-515,439,-744,0,-744C-439,-744,-766,-515,-982,-59C-1000,-22,-1000,22,-982,59C-766,515,-439,744,0,744C439,744,766,515,982,59C1000,22,1000,-21,982,-59ZM-9,402C-231,402,-411,222,-411,0C-411,-222,-231,-402,-9,-402C213,-402,393,-222,393,0C393,222,213,402,-9,402Z",
  "M998,470C994,460,983,455,972,458L819,514L819,-830C819,-924,743,-1000,649,-1000L-649,-1000C-743,-1000,-819,-924,-819,-830L-819,514L-972,458C-975,458,-977,457,-979,457C-990,457,-999,466,-999,477L-999,626C-999,634,-994,642,-986,645L-27,994C-10,1000,9,1000,27,994L986,645C994,642,999,635,999,626L999,477C999,475,999,473,998,470ZM0,812L-639,580L-639,-820L639,-820L639,580L0,812ZM371,-500L235,-500C228,-500,221,-496,217,-489L6,-68L-2,-68L-214,-489C-218,-496,-224,-500,-232,-500L-371,-500C-374,-500,-377,-500,-380,-498C-390,-493,-394,-480,-388,-471L-129,8L-271,8C-282,8,-291,17,-291,28L-291,95C-291,106,-282,115,-271,115L-81,115L-81,213L-271,213C-282,213,-291,222,-291,233L-291,300C-291,311,-282,320,-271,320L-81,320L-81,479C-81,490,-72,499,-61,499L63,499C74,499,83,490,83,479L83,320L274,320C285,320,294,311,294,300L294,232C294,221,285,212,274,212L83,212L83,115L274,115C285,115,294,106,294,95L294,27C294,16,285,7,274,7L130,7L389,-471C390,-474,391,-477,391,-481C391,-491,382,-500,371,-500Z",
  "M907,53C948,-1,971,-67,971,-136C971,-245,910,-348,812,-405L792,-415L772,-422L750,-427L729,-428L147,-428L161,-726C165,-798,139,-867,90,-919C40,-971,-27,-1000,-100,-1000C-226,-1000,-337,-915,-371,-793L-579,-39L-580,-39L-580,1000L566,1000C589,1000,610,996,631,987C746,938,821,825,821,700C821,669,816,639,807,610C848,556,871,490,871,421C871,391,866,361,858,331C898,278,921,212,921,143C921,112,916,82,907,53ZM-971,39L-971,922C-971,965,-936,1000,-893,1000L-735,1000L-735,-39L-893,-39C-936,-39,-971,-4,-971,39Z",
  "M818,-585C807,-618,776,-640,742,-640L560,-640L560,-920C560,-964,524,-1000,480,-1000L-480,-1000C-524,-1000,-560,-964,-560,-920L-560,-640L-742,-640C-777,-640,-807,-618,-818,-585L-1000,-25L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-25L818,-585ZM-380,-820L380,-820L380,-640L-380,-640L-380,-820ZM820,820L-820,820L-820,4L-669,-460L669,-460L820,4L820,820ZM350,150L80,150L80,-120C80,-131,71,-140,60,-140L-60,-140C-71,-140,-80,-131,-80,-120L-80,150L-350,150C-361,150,-370,159,-370,170L-370,290C-370,301,-361,310,-350,310L-80,310L-80,580C-80,591,-71,600,-60,600L60,600C71,600,80,591,80,580L80,310L350,310C361,310,370,301,370,290L370,170C370,159,361,150,350,150Z",
  "M800,-120L630,-120L630,-680C630,-857,487,-1000,310,-1000L-310,-1000C-487,-1000,-630,-857,-630,-680L-630,-120L-800,-120C-844,-120,-880,-84,-880,-40L-880,920C-880,964,-844,1000,-800,1000L800,1000C844,1000,880,964,880,920L880,-40C880,-84,844,-120,800,-120ZM70,472L70,605C70,616,61,625,50,625L-50,625C-61,625,-70,616,-70,605L-70,472C-100,451,-120,415,-120,375C-120,309,-66,255,0,255C66,255,120,309,120,375C120,415,100,451,70,472ZM450,-120L-450,-120L-450,-680C-450,-757,-387,-820,-310,-820L310,-820C387,-820,450,-757,450,-680L450,-120Z",
  "M925,-600L925,-920C925,-964,889,-1000,845,-1000L-845,-1000C-889,-1000,-925,-964,-925,-920L-925,-600C-967,-597,-1000,-562,-1000,-520L-1000,-191C-1000,-130,-988,-70,-964,-15C-953,11,-940,35,-925,58L-925,920C-925,964,-889,1000,-845,1000L845,1000C889,1000,925,964,925,920L925,58C940,35,953,10,964,-15C988,-70,1000,-130,1000,-191L1000,-520C1000,-562,967,-597,925,-600ZM-745,-820L745,-820L745,-600L-745,-600L-745,-820ZM160,820L-160,820L-160,560L160,560L160,820ZM745,820L320,820L320,480C320,436,284,400,240,400L-240,400C-284,400,-320,436,-320,480L-320,820L-745,820L-745,215C-738,218,-730,222,-722,225C-667,248,-608,260,-546,260C-486,260,-426,248,-370,225C-336,210,-304,192,-274,170C-273,169,-273,169,-272,170C-242,192,-210,210,-176,225C-120,248,-60,260,0,260C62,260,120,248,176,225C211,210,244,192,273,170C274,169,274,169,275,170C304,192,337,210,372,225C427,248,486,260,548,260C608,260,668,248,724,225C731,222,738,218,746,215L746,820ZM820,-191C820,-41,698,80,547,80C445,80,356,25,309,-57C302,-70,288,-78,274,-78L272,-78C258,-78,245,-70,238,-57C191,25,102,80,0,80C-102,80,-190,25,-238,-57C-245,-70,-258,-78,-273,-78C-288,-78,-302,-70,-309,-57C-356,25,-445,80,-547,80C-698,80,-820,-41,-820,-191L-820,-419C-820,-420,-820,-420,-819,-420L819,-420C820,-420,820,-420,820,-419L820,-191Z",
  "M908,-53C916,-82,921,-112,921,-142C921,-211,898,-277,857,-331C866,-360,870,-390,870,-421C870,-490,848,-556,807,-609C816,-639,820,-669,820,-699C820,-825,746,-937,630,-987C610,-995,588,-1000,566,-1000L-580,-1000L-580,39L-579,39L-371,793C-338,915,-226,1000,-100,1000C-28,1000,40,971,89,919C139,867,165,798,161,726L146,428L729,428C758,428,787,420,812,405C910,348,971,245,971,136C971,67,948,1,908,-53ZM-971,-922L-971,-39C-971,4,-936,39,-893,39L-735,39L-735,-1000L-893,-1000C-936,-1000,-971,-965,-971,-922Z",
  "M800,-500L460,-500L460,-540C460,-794,254,-1000,0,-1000C-254,-1000,-460,-794,-460,-540L-460,-500L-800,-500C-844,-500,-880,-464,-880,-420L-880,920C-880,964,-844,1000,-800,1000L800,1000C844,1000,880,964,880,920L880,-420C880,-464,844,-500,800,-500ZM-280,-540C-280,-695,-155,-820,0,-820C155,-820,280,-695,280,-540L280,-500L-280,-500L-280,-540ZM700,820L-700,820L-700,-320L-460,-320L-460,-100C-460,-89,-451,-80,-440,-80L-300,-80C-289,-80,-280,-89,-280,-100L-280,-320L280,-320L280,-100C280,-89,289,-80,300,-80L440,-80C451,-80,460,-89,460,-100L460,-320L700,-320L700,820Z",
  "M930,-281L335,-367L68,-907C61,-922,49,-934,34,-941C-3,-959,-48,-944,-66,-907L-333,-367L-928,-281C-945,-278,-960,-271,-971,-259C-1000,-229,-1000,-182,-970,-153L-539,268L-641,861C-643,877,-641,894,-633,909C-614,945,-568,959,-532,940L1,660L534,940C548,948,565,950,581,947C622,940,650,902,643,861L541,268L972,-153C984,-164,991,-179,994,-196C1000,-237,971,-275,930,-281Z",
  "M920,-534L22,-534L-271,-814C-275,-818,-280,-820,-284,-820L-920,-820C-964,-820,-1000,-784,-1000,-740L-1000,740C-1000,784,-964,820,-920,820L920,820C964,820,1000,784,1000,740L1000,-454C1000,-498,964,-534,920,-534ZM820,640L-820,640L-820,-640L-349,-640L-50,-354L820,-354L820,640Z",
  "M800,-120L-450,-120L-450,-680C-450,-757,-387,-820,-310,-820L310,-820C387,-820,450,-757,450,-680L450,-510C450,-499,459,-490,470,-490L610,-490C621,-490,630,-499,630,-510L630,-680C630,-857,487,-1000,310,-1000L-310,-1000C-487,-1000,-630,-857,-630,-680L-630,-120L-800,-120C-844,-120,-880,-84,-880,-40L-880,920C-880,964,-844,1000,-800,1000L800,1000C844,1000,880,964,880,920L880,-40C880,-84,844,-120,800,-120ZM70,472L70,605C70,616,61,625,50,625L-50,625C-61,625,-70,616,-70,605L-70,472C-100,451,-120,415,-120,375C-120,309,-66,255,0,255C66,255,120,309,120,375C120,415,100,451,70,472Z",
  "M929,-152L688,-152L688,-405C688,-445,656,-477,616,-477L-87,-477L-349,-727C-352,-730,-357,-732,-361,-732L-929,-732C-968,-732,-1000,-700,-1000,-661L-1000,661C-1000,700,-968,732,-929,732L629,732C658,732,685,715,696,688L995,-54C998,-62,1000,-71,1000,-80C1000,-120,968,-152,929,-152ZM-839,-571L-419,-571L-152,-316L527,-316L527,-152L-612,-152C-641,-152,-667,-134,-678,-107L-839,293L-839,-571ZM579,571L-788,571L-557,0L810,0L579,571Z",
  "M0,-604C397,-604,718,-282,718,115L718,640C718,679,686,712,646,712L-647,712C-686,712,-719,679,-719,640L-719,115C-719,-282,-397,-604,0,-604ZM-63,-1000L63,-1000L66,-1000L69,-999L72,-998L75,-996L77,-994L79,-991L80,-988L81,-985L81,-982L81,-766L81,-763L80,-760L79,-757L77,-754L75,-752L72,-750L69,-749L66,-748L63,-748L-63,-748L-66,-748L-69,-749L-72,-750L-75,-752L-77,-754L-79,-757L-80,-760L-81,-763L-81,-766L-81,-982L-81,-985L-80,-988L-79,-991L-77,-994L-75,-996L-72,-998L-69,-999L-66,-1000L-63,-1000ZM-754,-721L-752,-723L-749,-725L-747,-726L-744,-727L-741,-727L-738,-727L-736,-726L-733,-725L-731,-723L-729,-721L-576,-569L-574,-566L-572,-564L-571,-561L-571,-559L-570,-556L-571,-553L-571,-550L-572,-548L-574,-545L-576,-543L-665,-454L-667,-452L-669,-451L-672,-450L-675,-449L-678,-449L-680,-449L-683,-450L-686,-451L-688,-452L-690,-454L-843,-607L-845,-609L-847,-611L-848,-614L-848,-617L-849,-620L-848,-622L-848,-625L-847,-628L-845,-630L-843,-632L-754,-721ZM754,-721L843,-632L845,-630L847,-628L848,-625L848,-622L849,-620L848,-617L848,-614L847,-611L845,-609L843,-607L690,-454L688,-452L686,-451L683,-450L680,-449L678,-449L675,-449L672,-450L669,-451L667,-452L665,-454L576,-543L574,-545L572,-548L571,-550L571,-553L570,-556L571,-559L571,-561L572,-564L574,-566L576,-569L729,-721L731,-723L733,-725L736,-726L738,-727L741,-727L744,-727L747,-726L749,-725L752,-723L754,-721ZM-721,856L721,856C760,856,793,888,793,928L793,982L792,985L792,988L790,991L788,994L786,996L784,998L781,999L778,1000L775,1000L-775,1000L-778,1000L-781,999L-784,998L-786,996L-789,994L-791,991L-792,988L-793,985L-793,982L-793,928C-793,888,-761,856,-721,856ZM-388,142L-388,712L-243,712L-243,142L-388,142Z",
  "M992,-888L889,-992C885,-996,880,-998,875,-998C870,-998,865,-996,861,-992L675,-806C592,-862,496,-890,400,-890C275,-890,150,-842,54,-747L-195,-497C-203,-490,-203,-477,-195,-470L470,195C474,199,478,201,484,201C488,201,494,199,497,195L747,-54C915,-223,935,-484,806,-674L992,-861C1000,-868,1000,-881,992,-888ZM164,85C156,77,143,77,136,85L-27,248L-248,27L-85,-136C-77,-144,-77,-156,-85,-164L-174,-253C-181,-260,-194,-260,-201,-253L-365,-90L-470,-195C-474,-199,-479,-200,-484,-200C-489,-200,-494,-199,-498,-195L-747,54C-915,223,-935,484,-806,675L-992,861C-1000,868,-1000,881,-992,888L-889,992C-885,996,-880,998,-875,998C-870,998,-865,996,-861,992L-675,806C-592,862,-496,890,-400,890C-275,890,-150,842,-54,747L195,497C203,490,203,477,195,470L90,364L253,201C261,194,261,181,253,174L164,85Z",
  "M840,387C745,332,630,347,552,415L433,347L433,8C433,-27,415,-60,384,-77L81,-252L81,-402C179,-435,250,-529,250,-639C250,-777,138,-889,0,-889C-138,-889,-250,-777,-250,-639C-250,-529,-179,-435,-80,-402L-80,-252L-384,-77C-414,-60,-433,-27,-433,8L-433,347L-551,415C-629,346,-745,332,-840,387C-959,456,-1000,609,-931,728C-863,847,-711,889,-592,820C-497,765,-452,657,-472,554L-363,491L-49,672C-34,681,-17,685,0,685C17,685,34,681,49,672L363,491L472,554C451,657,497,765,591,820C710,889,863,848,931,728C1000,609,959,456,840,387ZM-663,696C-713,725,-779,708,-808,657C-838,605,-820,540,-769,510C-718,481,-653,498,-623,550C-594,601,-611,666,-663,696ZM22,-126ZM-107,-639C-107,-698,-59,-746,0,-746C59,-746,107,-698,107,-639C107,-579,59,-531,0,-531C-59,-531,-107,-579,-107,-639ZM272,358L0,515L-272,358L-272,44L0,-113L272,44L272,358ZM808,657C779,708,713,726,663,696C612,667,594,601,623,550C653,499,718,481,769,510C820,540,838,605,808,657Z",
  "M993,-9L203,-788C196,-795,185,-795,178,-788L-355,-264C-362,-257,-362,-245,-355,-238L-355,-238L-266,-150L-527,107C-534,114,-534,125,-527,132L-527,132L-439,219L-861,636L-982,636C-992,636,-1000,644,-1000,654L-1000,777C-1000,787,-992,795,-982,795L-213,795C-208,795,-204,793,-200,790L-31,621L59,710C66,717,78,717,84,710L346,452L435,540C442,547,453,547,460,540L992,16C1000,9,1000,-2,993,-9Z",
  "M920,-820L500,-820L500,-980C500,-991,491,-1000,480,-1000L340,-1000C329,-1000,320,-991,320,-980L320,-820L-320,-820L-320,-980C-320,-991,-329,-1000,-340,-1000L-480,-1000C-491,-1000,-500,-991,-500,-980L-500,-820L-920,-820C-964,-820,-1000,-784,-1000,-740L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-740C1000,-784,964,-820,920,-820ZM820,820L-820,820L-820,-640L-500,-640L-500,-520C-500,-509,-491,-500,-480,-500L-340,-500C-329,-500,-320,-509,-320,-520L-320,-640L320,-640L320,-520C320,-509,329,-500,340,-500L480,-500C491,-500,500,-509,500,-520L500,-640L820,-640L820,820ZM319,-245L206,-245C199,-245,192,-241,188,-234L5,130L-2,130L-186,-234C-189,-241,-196,-245,-203,-245L-318,-245C-322,-245,-325,-244,-328,-242C-338,-237,-341,-225,-336,-215L-112,195L-234,195C-245,195,-254,204,-254,215L-254,268C-254,279,-245,288,-234,288L-71,288L-71,372L-234,372C-245,372,-254,381,-254,392L-254,446C-254,456,-245,466,-234,466L-71,466L-71,600C-71,611,-62,620,-51,620L52,620C63,620,72,611,72,600L72,466L236,466C246,466,256,456,256,446L256,392C256,381,246,372,236,372L72,372L72,288L236,288C246,288,256,279,256,268L256,215C256,204,246,195,236,195L113,195L336,-216C338,-218,338,-222,338,-225C339,-236,330,-245,319,-245Z",
  "M895,-680L638,-936C601,-973,552,-994,500,-994C448,-994,398,-973,361,-936L85,-660C48,-623,28,-574,28,-522C28,-469,48,-420,85,-383L287,-181C240,-76,174,18,93,99C12,180,-82,246,-187,294L-389,92C-426,55,-476,34,-527,34C-580,34,-629,55,-666,92L-943,368C-979,405,-1000,454,-1000,506C-1000,559,-979,608,-943,645L-686,901C-627,960,-546,994,-463,994C-445,994,-428,992,-411,990C-86,936,236,763,497,503C757,243,929,-79,984,-405C1000,-505,967,-607,895,-680Z",
  "M184,200C224,155,249,96,249,31C249,-107,137,-219,0,-219C-137,-219,-249,-107,-249,31C-249,96,-224,155,-184,200C-279,259,-344,362,-350,481C-351,492,-343,500,-332,500L-234,500C-225,500,-217,493,-217,483C-208,370,-114,281,0,281C115,281,209,371,217,483C218,493,225,500,235,500L333,500C343,500,351,492,350,481C344,362,279,259,184,200ZM0,147C-64,147,-115,95,-115,31C-115,-33,-64,-85,0,-85C64,-85,115,-33,115,31C115,95,64,147,0,147ZM929,-643L571,-643L571,-768C571,-778,563,-786,554,-786L429,-786C419,-786,411,-778,411,-768L411,-643L80,-643L80,-768C80,-778,72,-786,62,-786L-62,-786C-72,-786,-80,-778,-80,-768L-80,-643L-411,-643L-411,-768C-411,-778,-419,-786,-429,-786L-554,-786C-563,-786,-571,-778,-571,-768L-571,-643L-929,-643C-968,-643,-1000,-611,-1000,-571L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-571C1000,-611,968,-643,929,-643ZM839,625L-839,625L-839,-482L-571,-482L-571,-357C-571,-347,-563,-339,-554,-339L-429,-339C-419,-339,-411,-347,-411,-357L-411,-482L-80,-482L-80,-357C-80,-347,-72,-339,-62,-339L62,-339C72,-339,80,-347,80,-357L80,-482L411,-482L411,-357C411,-347,419,-339,429,-339L554,-339C563,-339,571,-347,571,-357L571,-482L839,-482L839,625Z",
  "M920,810L-920,810C-964,810,-1000,846,-1000,890L-1000,980C-1000,991,-991,1000,-980,1000L980,1000C991,1000,1000,991,1000,980L1000,890C1000,846,964,810,920,810ZM-636,600C-631,600,-626,600,-621,599L-200,525C-195,524,-190,522,-187,518L873,-542C882,-552,882,-567,873,-577L457,-993C452,-998,446,-1000,440,-1000C433,-1000,426,-998,422,-993L-638,67C-642,71,-644,75,-645,80L-719,501C-724,528,-715,556,-695,575C-679,591,-658,600,-636,600Z",
  "M920,-820L500,-820L500,-980C500,-991,491,-1000,480,-1000L340,-1000C329,-1000,320,-991,320,-980L320,-820L-320,-820L-320,-980C-320,-991,-329,-1000,-340,-1000L-480,-1000C-491,-1000,-500,-991,-500,-980L-500,-820L-920,-820C-964,-820,-1000,-784,-1000,-740L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-740C1000,-784,964,-820,920,-820ZM820,820L-820,820L-820,-640L-500,-640L-500,-520C-500,-509,-491,-500,-480,-500L-340,-500C-329,-500,-320,-509,-320,-520L-320,-640L320,-640L320,-520C320,-509,329,-500,340,-500L480,-500C491,-500,500,-509,500,-520L500,-640L820,-640L820,820ZM440,-230L302,-230C289,-230,277,-224,270,-214L-108,306L-270,84C-277,73,-289,67,-302,67L-440,67C-456,67,-466,86,-456,99L-140,534C-124,556,-91,556,-75,534L456,-198C466,-212,456,-230,440,-230Z",
  "M966,-317L314,-969C297,-986,274,-995,252,-995C229,-995,207,-986,190,-969L-237,-542C-269,-546,-301,-548,-334,-548C-528,-548,-721,-484,-880,-356C-921,-324,-924,-263,-887,-226L-407,255L-976,824C-983,831,-988,840,-989,850L-998,949C-1000,973,-980,995,-956,995C-954,995,-953,995,-952,994L-853,985C-843,985,-834,980,-827,973L-257,403L223,884C240,901,263,910,285,910C311,910,337,899,354,877C503,691,565,458,540,233L966,-193C1000,-227,1000,-283,966,-317Z",
  "M929,-643L571,-643L571,-768C571,-778,563,-786,554,-786L429,-786C419,-786,411,-778,411,-768L411,-643L80,-643L80,-768C80,-778,72,-786,62,-786L-62,-786C-72,-786,-80,-778,-80,-768L-80,-643L-411,-643L-411,-768C-411,-778,-419,-786,-429,-786L-554,-786C-563,-786,-571,-778,-571,-768L-571,-643L-929,-643C-968,-643,-1000,-611,-1000,-571L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-571C1000,-611,968,-643,929,-643ZM839,625L-839,625L-839,-482L-571,-482L-571,-357C-571,-347,-563,-339,-554,-339L-429,-339C-419,-339,-411,-347,-411,-357L-411,-482L-80,-482L-80,-357C-80,-347,-72,-339,-62,-339L62,-339C72,-339,80,-347,80,-357L80,-482L411,-482L411,-357C411,-347,419,-339,429,-339L554,-339C563,-339,571,-347,571,-357L571,-482L839,-482L839,625ZM-214,-36L-625,-36C-635,-36,-643,-28,-643,-18L-643,89C-643,99,-635,107,-625,107L-214,107C-204,107,-196,99,-196,89L-196,-18C-196,-28,-204,-36,-214,-36ZM-214,268L-625,268C-635,268,-643,276,-643,286L-643,393C-643,403,-635,411,-625,411L-214,411C-204,411,-196,403,-196,393L-196,286C-196,276,-204,268,-214,268ZM474,-128L242,193L125,29C118,20,107,15,96,15L-27,15C-41,15,-50,31,-41,43L213,396C228,416,257,416,271,396L639,-114C648,-126,639,-143,625,-143L502,-143C491,-143,480,-137,474,-128Z",
  "M803,-369L275,-369L750,-969C760,-982,751,-1000,735,-1000L-184,-1000C-191,-1000,-197,-996,-201,-990L-822,82C-829,95,-820,111,-805,111L-387,111L-601,968C-606,987,-583,1000,-570,987L817,-336C829,-348,821,-369,803,-369Z",
  "M920,-820L500,-820L500,-980C500,-991,491,-1000,480,-1000L340,-1000C329,-1000,320,-991,320,-980L320,-820L-320,-820L-320,-980C-320,-991,-329,-1000,-340,-1000L-480,-1000C-491,-1000,-500,-991,-500,-980L-500,-820L-920,-820C-964,-820,-1000,-784,-1000,-740L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-740C1000,-784,964,-820,920,-820ZM820,820L-820,820L-820,-130L820,-130L820,820ZM-820,-300L-820,-640L-500,-640L-500,-520C-500,-509,-491,-500,-480,-500L-340,-500C-329,-500,-320,-509,-320,-520L-320,-640L320,-640L320,-520C320,-509,329,-500,340,-500L480,-500C491,-500,500,-509,500,-520L500,-640L820,-640L820,-300L-820,-300Z",
  "M1000,-125L930,-857C927,-895,896,-925,858,-929L126,-999L125,-999C117,-999,111,-996,107,-992L-991,106C-1000,115,-1000,130,-991,139L-138,992C-134,996,-128,999,-121,999C-115,999,-109,996,-105,992L993,-106C998,-111,1000,-118,1000,-125ZM439,-293C357,-293,289,-360,289,-443C289,-526,357,-593,439,-593C522,-593,589,-526,589,-443C589,-360,522,-293,439,-293Z",
  "M-940,-320L-800,-320C-789,-320,-780,-329,-780,-340L-780,-780L-340,-780C-329,-780,-320,-789,-320,-800L-320,-940C-320,-951,-329,-960,-340,-960L-790,-960C-884,-960,-960,-884,-960,-790L-960,-340C-960,-329,-951,-320,-940,-320ZM340,-780L780,-780L780,-340C780,-329,789,-320,800,-320L940,-320C951,-320,960,-329,960,-340L960,-790C960,-884,884,-960,790,-960L340,-960C329,-960,320,-951,320,-940L320,-800C320,-789,329,-780,340,-780ZM-340,780L-780,780L-780,340C-780,329,-789,320,-800,320L-940,320C-951,320,-960,329,-960,340L-960,790C-960,884,-884,960,-790,960L-340,960C-329,960,-320,951,-320,940L-320,800C-320,789,-329,780,-340,780ZM940,320L800,320C789,320,780,329,780,340L780,780L340,780C329,780,320,789,320,800L320,940C320,951,329,960,340,960L790,960C884,960,960,884,960,790L960,340C960,329,951,320,940,320ZM980,-90L-980,-90C-991,-90,-1000,-81,-1000,-70L-1000,70C-1000,81,-991,90,-980,90L980,90C991,90,1000,81,1000,70L1000,-70C1000,-81,991,-90,980,-90Z",
  "M858,-639C857,-640,703,-488,397,-182L182,-397L640,-855C399,-1000,90,-963,-111,-762C-269,-604,-328,-377,-271,-165L-267,-148L-984,569C-1000,585,-1000,611,-984,626L-626,984C-611,1000,-585,1000,-569,984L148,267L165,272C376,328,604,269,762,111C963,-89,1000,-399,858,-639Z",
  "M919,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,919C-1000,963,-964,999,-920,999L-21,999C-10,999,-1,990,-1,979L-1,839C-1,828,-10,819,-21,819L-820,819L-820,-820L819,-820L819,-21C819,-10,828,-1,839,-1L979,-1C990,-1,999,-10,999,-21L999,-920C999,-964,963,-1000,919,-1000ZM352,218L483,87C495,76,488,55,471,53L23,1C10,-1,-1,10,1,23L53,471C55,488,75,495,87,483L218,352L858,992C866,1000,879,1000,886,992L992,886C1000,879,1000,866,992,858L352,218Z",
  "M-68,620L776,-224C779,-228,781,-233,781,-238L724,-910C722,-928,709,-941,691,-943L19,-1000C14,-1000,8,-998,5,-994L-839,-151C-846,-144,-846,-133,-839,-126L-93,620C-86,627,-75,627,-68,620ZM206,-570C247,-612,315,-612,357,-570C399,-528,399,-460,357,-419C315,-377,248,-377,206,-419C164,-460,164,-528,206,-570ZM839,61L750,-27C743,-34,732,-34,725,-27L-82,779L-612,250C-619,243,-631,243,-637,250L-726,338C-733,345,-733,357,-726,363L-183,905L-95,993C-88,1000,-77,1000,-70,993L839,86C846,79,846,68,839,61Z",
  "M982,-643L866,-643C856,-643,848,-635,848,-625L848,-71L643,-71L643,-464C643,-474,635,-482,625,-482L-625,-482C-635,-482,-643,-474,-643,-464L-643,-71L-848,-71L-848,-625C-848,-635,-856,-643,-866,-643L-982,-643C-992,-643,-1000,-635,-1000,-625L-1000,625C-1000,635,-992,643,-982,643L-866,643C-856,643,-848,635,-848,625L-848,80L-643,80L-643,464C-643,474,-635,482,-625,482L625,482C635,482,643,474,643,464L643,80L848,80L848,625C848,635,856,643,866,643L982,643C992,643,1000,635,1000,625L1000,-625C1000,-635,992,-643,982,-643ZM-482,-321L-286,-321L-286,321L-482,321L-482,-321ZM482,321L-143,321L-143,-321L482,-321L482,321Z",
  "M897,-117C970,-117,1000,-211,941,-254L44,-906L34,-912L23,-917L12,-920L0,-921L-12,-920L-23,-917L-34,-912L-44,-906L-941,-254C-1000,-211,-970,-117,-897,-117L-752,-117L-752,761L-921,761C-931,761,-939,769,-939,780L-939,902C-939,912,-931,921,-921,921L921,921C931,921,939,912,939,902L939,780C939,769,931,761,921,761L752,761L752,-117L897,-117ZM-308,761L-582,761L-582,-117L-308,-117L-308,761ZM136,761L-139,761L-139,-117L136,-117L136,761ZM582,761L305,761L305,-117L582,-117L582,761Z",
  "M927,-693L-312,-693C-353,-693,-385,-660,-385,-619L-385,-78L-927,-78C-967,-78,-1000,-45,-1000,-5L-1000,619C-1000,660,-967,693,-927,693L312,693C353,693,385,660,385,619L385,78L927,78C967,78,1000,45,1000,5L1000,-619C1000,-660,967,-693,927,-693ZM-229,-537L229,-537L229,-78L-229,-78L-229,-537ZM-385,537L-844,537L-844,78L-385,78L-385,537ZM229,537L-229,537L-229,78L229,78L229,537ZM844,-78L385,-78L385,-537L844,-537L844,-78Z",
  "M815,-583L500,-583L425,-794C414,-823,387,-843,355,-843L-355,-843C-386,-843,-414,-823,-425,-794L-500,-583L-815,-583C-917,-583,-1000,-500,-1000,-398L-1000,657C-1000,760,-917,843,-815,843L815,843C917,843,1000,760,1000,657L1000,-398C1000,-500,917,-583,815,-583ZM0,472C-205,472,-370,306,-370,102C-370,-103,-205,-269,0,-269C205,-269,370,-103,370,102C370,306,205,472,0,472ZM0,102ZM-222,102L-219,140L-209,178L-192,213L-170,245L-143,272L-111,294L-76,311L-39,321L0,324L39,321L76,311L111,294L143,272L170,245L192,213L209,178L219,140L222,102L219,63L209,26L192,-9L170,-41L143,-68L111,-91L76,-107L39,-117L0,-120L-39,-117L-76,-107L-111,-91L-143,-68L-170,-41L-192,-9L-209,26L-219,63L-222,102Z",
  "M-480,-720L-645,-720L-645,-860C-645,-871,-654,-880,-665,-880L-795,-880C-806,-880,-815,-871,-815,-860L-815,-720L-980,-720C-991,-720,-1000,-711,-1000,-700L-1000,700C-1000,711,-991,720,-980,720L-815,720L-815,860C-815,871,-806,880,-795,880L-665,880C-654,880,-645,871,-645,860L-645,720L-480,720C-469,720,-460,711,-460,700L-460,-700C-460,-711,-469,-720,-480,-720ZM-630,550L-830,550L-830,-550L-630,-550L-630,550ZM980,-540L815,-540L815,-780C815,-791,806,-800,795,-800L665,-800C654,-800,645,-791,645,-780L645,-540L480,-540C469,-540,460,-531,460,-520L460,520C460,531,469,540,480,540L645,540L645,780C645,791,654,800,665,800L795,800C806,800,815,791,815,780L815,540L980,540C991,540,1000,531,1000,520L1000,-520C1000,-531,991,-540,980,-540ZM830,370L630,370L630,-370L830,-370L830,370ZM250,-270L85,-270L85,-700C85,-711,76,-720,65,-720L-65,-720C-76,-720,-85,-711,-85,-700L-85,-270L-250,-270C-261,-270,-270,-261,-270,-250L-270,250C-270,261,-261,270,-250,270L-85,270L-85,700C-85,711,-76,720,-65,720L65,720C76,720,85,711,85,700L85,270L250,270C261,270,270,261,270,250L270,-250C270,-261,261,-270,250,-270ZM100,92C100,96,97,100,92,100L-92,100C-96,100,-100,97,-100,92L-100,-92C-100,-96,-97,-100,-92,-100L92,-100C96,-100,100,-97,100,-92L100,92Z",
  "M973,754L61,-825C47,-848,24,-860,0,-860C-24,-860,-47,-848,-61,-825L-973,754C-1000,801,-966,860,-912,860L912,860C966,860,1000,801,973,754ZM-70,-211C-70,-220,-62,-228,-53,-228L53,-228C62,-228,70,-220,70,-211L70,193C70,203,62,211,53,211L-53,211C-62,211,-70,203,-70,193L-70,-211ZM0,561C-58,561,-105,514,-105,456C-105,398,-58,351,0,351C58,351,105,398,105,456C105,514,58,561,0,561Z",
  "M983,737L850,265L850,-761C850,-800,818,-832,779,-832L-779,-832C-818,-832,-850,-800,-850,-761L-850,265L-983,737C-1000,783,-966,832,-917,832L917,832C966,832,1000,783,983,737ZM-690,-673L690,-673L690,201L-690,201L-690,-673ZM-185,673L-167,591L165,591L183,673L-185,673ZM310,673L268,481C266,473,259,467,251,467L-253,467C-261,467,-268,473,-270,481L-312,673L-800,673L-706,343L706,343L800,673L310,673Z",
  "M967,-585L482,-286L16,-907C8,-918,-8,-918,-16,-907L-481,-286L-967,-585C-982,-594,-1000,-582,-998,-566L-807,883C-804,903,-787,918,-767,918L768,918C788,918,805,903,807,883L998,-566C1000,-582,982,-594,967,-585ZM0,557C-155,557,-281,431,-281,276C-281,121,-155,-5,0,-5C155,-5,281,121,281,276C281,431,155,557,0,557ZM0,155C-66,155,-120,209,-120,276C-120,342,-66,396,0,396C67,396,120,342,120,276C120,209,67,155,0,155Z",
  "M-875,-785L-982,-785C-992,-785,-1000,-777,-1000,-767L-1000,767C-1000,777,-992,785,-982,785L-875,785C-865,785,-857,777,-857,767L-857,-767C-857,-777,-865,-785,-875,-785ZM982,-785L875,-785C865,-785,857,-777,857,-767L857,767C857,777,865,785,875,785L982,785C992,785,1000,777,1000,767L1000,-767C1000,-777,992,-785,982,-785ZM-697,499L-447,499C-437,499,-429,491,-429,482L-429,-767C-429,-777,-437,-785,-447,-785L-697,-785C-707,-785,-715,-777,-715,-767L-715,482C-715,491,-707,499,-697,499ZM19,499L126,499C136,499,144,491,144,482L144,-767C144,-777,136,-785,126,-785L19,-785C9,-785,1,-777,1,-767L1,482C1,491,9,499,19,499ZM300,499L697,499C707,499,715,491,715,482L715,-767C715,-777,707,-785,697,-785L300,-785C290,-785,282,-777,282,-767L282,482C282,491,290,499,300,499ZM-269,499L-162,499C-152,499,-144,491,-144,482L-144,-767C-144,-777,-152,-785,-162,-785L-269,-785C-278,-785,-287,-777,-287,-767L-287,482C-287,491,-278,499,-269,499ZM-445,642L-695,642C-704,642,-712,650,-712,660L-712,767C-712,777,-704,785,-695,785L-445,785C-435,785,-427,777,-427,767L-427,660C-427,650,-435,642,-445,642ZM128,642L21,642C11,642,3,650,3,660L3,767C3,777,11,785,21,785L128,785C138,785,146,777,146,767L146,660C146,650,138,642,128,642ZM699,642L302,642C292,642,284,650,284,660L284,767C284,777,292,785,302,785L699,785C709,785,717,777,717,767L717,660C717,650,709,642,699,642ZM-159,642L-266,642C-276,642,-284,650,-284,660L-284,767C-284,777,-276,785,-266,785L-159,785C-150,785,-142,777,-142,767L-142,660C-142,650,-150,642,-159,642Z",
  "M929,-786L-929,-786C-968,-786,-1000,-754,-1000,-714L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-714C1000,-754,968,-786,929,-786ZM748,-543L44,5C27,19,2,19,-15,5L-720,-543C-724,-546,-726,-550,-726,-555C-726,-564,-719,-571,-710,-571L738,-571C743,-571,748,-569,751,-565C756,-558,755,-548,748,-543Z",
  "M815,-583L500,-583L425,-794C414,-823,387,-843,355,-843L-355,-843C-386,-843,-414,-823,-425,-794L-500,-583L-815,-583C-917,-583,-1000,-500,-1000,-398L-1000,657C-1000,760,-917,843,-815,843L815,843C917,843,1000,760,1000,657L1000,-398C1000,-500,917,-583,815,-583ZM833,657C833,668,825,676,815,676L-815,676C-825,676,-833,668,-833,657L-833,-398C-833,-408,-825,-417,-815,-417L-383,-417L-343,-527L-290,-676L290,-676L343,-527L382,-417L815,-417C825,-417,833,-408,833,-398L833,657ZM0,-269C-205,-269,-370,-103,-370,102C-370,306,-205,472,0,472C205,472,370,306,370,102C370,-103,205,-269,0,-269ZM0,324C-123,324,-222,225,-222,102C-222,-21,-123,-120,0,-120C123,-120,222,-21,222,102C222,225,123,324,0,324Z",
  "M995,-220L943,-312C938,-320,927,-323,918,-318L805,-252L631,-734C612,-793,557,-833,495,-833L-469,-833C-546,-833,-615,-783,-639,-709L-805,-252L-918,-318C-927,-323,-937,-320,-942,-312L-995,-220C-1000,-211,-997,-200,-989,-196L-854,-117L-886,-28C-889,-21,-890,-13,-890,-6L-890,769C-890,804,-864,833,-832,833L-681,833C-654,833,-630,812,-624,783L-607,699L607,699L625,783C631,812,654,833,682,833L832,833C864,833,891,804,891,769L891,-6C891,-13,889,-21,887,-28L854,-117L989,-196C997,-200,1000,-211,995,-220ZM-552,243C-601,243,-641,203,-641,154C-641,104,-601,64,-552,64C-503,64,-463,104,-463,154C-463,203,-503,243,-552,243ZM312,410C312,419,304,427,294,427L-294,427C-304,427,-312,419,-312,410L-312,223C-312,213,-304,205,-294,205L-205,205C-195,205,-187,213,-187,223L-187,303L187,303L187,223C187,213,195,205,205,205L294,205C304,205,312,213,312,223L312,410ZM552,243C503,243,463,203,463,154C463,104,503,64,552,64C601,64,641,104,641,154C641,203,601,243,552,243ZM-650,-209L-488,-654L-487,-657L-486,-660C-484,-668,-477,-672,-469,-672L483,-672L651,-209L-650,-209Z",
  "M979,438L839,438L839,73L89,73L89,-167L708,-167C731,-167,750,-185,750,-208L750,-896C750,-919,731,-938,708,-938L-708,-938C-731,-938,-750,-919,-750,-896L-750,-208C-750,-185,-731,-167,-708,-167L-89,-167L-89,73L-839,73L-839,438L-979,438C-991,438,-1000,447,-1000,458L-1000,917C-1000,928,-991,938,-979,938L-521,938C-509,938,-500,928,-500,917L-500,458C-500,447,-509,438,-521,438L-661,438L-661,250L-89,250L-89,438L-229,438C-241,438,-250,447,-250,458L-250,917C-250,928,-241,938,-229,938L229,938C241,938,250,928,250,917L250,458C250,447,241,438,229,438L89,438L89,250L661,250L661,438L521,438C509,438,500,447,500,458L500,917C500,928,509,938,521,938L979,938C991,938,1000,928,1000,917L1000,458C1000,447,991,438,979,438ZM-667,764C-667,768,-670,771,-674,771L-827,771C-830,771,-834,768,-834,764L-834,611C-834,607,-830,604,-827,604L-674,604C-670,604,-667,607,-667,611L-667,764ZM83,764C83,768,80,771,76,771L-77,771C-80,771,-84,768,-84,764L-84,611C-84,607,-80,604,-77,604L76,604C80,604,83,607,83,611L83,764ZM-583,-333L-583,-771L583,-771L583,-333L-583,-333ZM833,764C833,768,830,771,826,771L673,771C670,771,666,768,666,764L666,611C666,607,670,604,673,604L826,604C830,604,833,607,833,611L833,764ZM-292,-552ZM-396,-552L-394,-534L-390,-516L-382,-500L-371,-485L-359,-472L-344,-462L-327,-454L-310,-449L-292,-448L-274,-449L-256,-454L-240,-462L-225,-472L-212,-485L-201,-500L-194,-516L-189,-534L-188,-552L-189,-570L-194,-588L-201,-604L-212,-619L-225,-632L-240,-642L-256,-650L-274,-655L-292,-656L-310,-655L-327,-650L-344,-642L-359,-632L-371,-619L-382,-604L-390,-588L-394,-570L-396,-552Z",
  "M524,-933C524,-944,515,-952,505,-952L-505,-952C-515,-952,-524,-944,-524,-933L-524,-581L524,-581L524,-933ZM810,-429L-810,-429C-915,-429,-1000,-343,-1000,-238L-1000,543C-1000,585,-966,619,-924,619L-524,619L-524,933C-524,944,-515,952,-505,952L505,952C515,952,524,944,524,933L524,619L924,619C966,619,1000,585,1000,543L1000,-238C1000,-343,915,-429,810,-429ZM362,790L-362,790L-362,133L362,133L362,790ZM752,-67C752,-56,744,-48,733,-48L638,-48C628,-48,619,-56,619,-67L619,-162C619,-172,628,-181,638,-181L733,-181C744,-181,752,-172,752,-162L752,-67Z",
  "M963,-278C983,-278,1000,-294,1000,-315L1000,-741C1000,-761,983,-778,963,-778L537,-778C517,-778,500,-761,500,-741L500,-611L-500,-611L-500,-741C-500,-761,-517,-778,-537,-778L-963,-778C-983,-778,-1000,-761,-1000,-741L-1000,-315C-1000,-294,-983,-278,-963,-278L-833,-278L-833,278L-963,278C-983,278,-1000,294,-1000,315L-1000,741C-1000,761,-983,778,-963,778L-537,778C-517,778,-500,761,-500,741L-500,611L500,611L500,741C500,761,517,778,537,778L963,778C983,778,1000,761,1000,741L1000,315C1000,294,983,278,963,278L833,278L833,-278L963,-278ZM648,-630L852,-630L852,-426L648,-426L648,-630ZM-852,-426L-852,-630L-648,-630L-648,-426L-852,-426ZM-648,630L-852,630L-852,426L-648,426L-648,630ZM852,426L852,630L648,630L648,426L852,426ZM667,278L537,278C517,278,500,294,500,315L500,444L-500,444L-500,315C-500,294,-517,278,-537,278L-667,278L-667,-278L-537,-278C-517,-278,-500,-294,-500,-315L-500,-444L500,-444L500,-315C500,-294,517,-278,537,-278L667,-278L667,278Z",
  "M925,-600L925,-920C925,-964,889,-1000,845,-1000L-845,-1000C-889,-1000,-925,-964,-925,-920L-925,-600C-967,-597,-1000,-562,-1000,-520L-1000,-191C-1000,-130,-988,-70,-964,-15C-953,11,-940,35,-925,58L-925,920C-925,964,-889,1000,-845,1000L-160,1000L-160,560L160,560L160,1000L845,1000C889,1000,925,964,925,920L925,58C940,35,953,10,964,-15C988,-70,1000,-130,1000,-191L1000,-520C1000,-562,967,-597,925,-600ZM745,820L320,820L320,480C320,436,284,400,240,400L-240,400C-284,400,-320,436,-320,480L-320,820L-745,820L-745,215C-738,218,-730,222,-722,225C-667,248,-608,260,-546,260C-486,260,-426,248,-370,225C-336,210,-304,192,-274,170C-273,169,-273,169,-272,170C-242,192,-210,210,-176,225C-120,248,-60,260,0,260C62,260,120,248,176,225C211,210,244,192,273,170C274,169,274,169,275,170C304,192,337,210,372,225C427,248,486,260,548,260C608,260,668,248,724,225C731,222,738,218,746,215L746,820ZM745,-600L-745,-600L-745,-820L745,-820L745,-600Z",
  "M-294,427L294,427C304,427,312,419,312,410L312,223C312,213,304,205,294,205L205,205C195,205,187,213,187,223L187,303L-187,303L-187,223C-187,213,-195,205,-205,205L-294,205C-304,205,-312,213,-312,223L-312,410C-312,419,-304,427,-294,427ZM552,154ZM463,154L465,169L469,184L475,198L484,211L495,222L508,231L522,237L537,241L552,243L568,241L583,237L597,231L610,222L620,211L629,198L636,184L640,169L641,154L640,138L636,123L629,109L620,96L610,85L597,76L583,70L568,66L552,64L537,66L522,70L508,76L495,85L484,96L475,109L469,123L465,138L463,154ZM995,-220L943,-312C938,-320,927,-323,918,-318L805,-252L631,-734C612,-793,557,-833,495,-833L-469,-833C-546,-833,-615,-783,-639,-709L-805,-252L-918,-318C-927,-323,-937,-320,-942,-312L-995,-220C-1000,-211,-997,-200,-989,-196L-854,-117L-886,-28C-889,-21,-890,-13,-890,-6L-890,769C-890,804,-864,833,-832,833L-681,833C-654,833,-630,812,-624,783L-607,699L607,699L625,783C631,812,654,833,682,833L832,833C864,833,891,804,891,769L891,-6C891,-13,889,-21,887,-28L854,-117L989,-196C997,-200,1000,-211,995,-220ZM730,11L730,539L-730,539L-730,11L-695,-85L696,-85L730,11ZM-488,-654L-487,-657L-486,-660C-484,-668,-477,-672,-469,-672L483,-672L651,-209L-650,-209L-488,-654ZM-552,154ZM-641,154L-640,169L-636,184L-629,198L-620,211L-609,222L-597,231L-583,237L-568,241L-552,243L-537,241L-522,237L-508,231L-495,222L-484,211L-475,198L-468,184L-464,169L-463,154L-464,138L-468,123L-475,109L-484,96L-495,85L-508,76L-522,70L-537,66L-552,64L-568,66L-583,70L-597,76L-609,85L-620,96L-629,109L-636,123L-640,138L-641,154Z",
  "M0,-269C-66,-269,-129,-243,-176,-196C-223,-149,-249,-86,-249,-20C-249,47,-223,110,-176,157C-129,204,-66,230,0,230C67,230,130,204,177,157C224,110,250,47,250,-20C250,-86,224,-149,177,-196C130,-243,67,-269,0,-269ZM920,256L774,131C781,89,784,46,784,3C784,-40,781,-84,774,-126L920,-250C942,-270,950,-301,940,-329L938,-335C898,-447,838,-551,761,-642L757,-646C738,-669,707,-677,679,-668L498,-603C431,-658,356,-701,276,-731L241,-921C235,-950,212,-973,183,-978L177,-979C61,-1000,-61,-1000,-177,-979L-183,-978C-212,-973,-235,-950,-241,-921L-276,-730C-356,-700,-430,-657,-496,-603L-679,-668C-706,-677,-738,-669,-757,-646L-761,-642C-838,-550,-898,-447,-938,-335L-940,-329C-950,-301,-942,-270,-920,-250L-772,-125C-779,-83,-782,-40,-782,3C-782,45,-779,88,-772,130L-919,256C-942,275,-950,306,-940,334L-938,340C-898,452,-838,556,-760,647L-756,652C-737,674,-706,683,-678,673L-496,608C-429,662,-355,706,-275,736L-240,926C-235,955,-212,978,-183,983L-177,984C-118,995,-59,1000,0,1000C60,1000,119,995,177,984L183,983C213,978,236,955,241,926L276,736C357,706,431,663,498,608L679,673C707,683,738,674,757,652L761,647C839,555,898,452,939,340L941,334C950,306,942,275,920,256ZM0,372C-216,372,-391,197,-391,-20C-391,-236,-216,-411,0,-411C217,-411,392,-236,392,-20C392,197,217,372,0,372Z",
  "M733,-181L638,-181C628,-181,619,-172,619,-162L619,-67C619,-56,628,-48,638,-48L733,-48C744,-48,752,-56,752,-67L752,-162C752,-172,744,-181,733,-181ZM810,-429L524,-429L524,-933C524,-944,515,-952,505,-952L-505,-952C-515,-952,-524,-944,-524,-933L-524,-429L-810,-429C-915,-429,-1000,-343,-1000,-238L-1000,543C-1000,585,-966,619,-924,619L-524,619L-524,933C-524,944,-515,952,-505,952L505,952C515,952,524,944,524,933L524,619L924,619C966,619,1000,585,1000,543L1000,-238C1000,-343,915,-429,810,-429ZM-362,-790L362,-790L362,-429L-362,-429L-362,-790ZM362,790L-362,790L-362,133L362,133L362,790ZM838,457L524,457L524,-29L-524,-29L-524,457L-838,457L-838,-238C-838,-254,-825,-267,-810,-267L810,-267C825,-267,838,-254,838,-238L838,457Z",
  "M-260,-500L-140,-500C-129,-500,-120,-509,-120,-520L-120,-640C-120,-651,-129,-660,-140,-660L-260,-660C-271,-660,-280,-651,-280,-640L-280,-520C-280,-509,-271,-500,-260,-500ZM620,-200L620,-920C620,-964,584,-1000,540,-1000L-540,-1000C-584,-1000,-620,-964,-620,-920L-620,-200C-786,-200,-920,-70,-920,90L-920,980C-920,991,-911,1000,-900,1000L900,1000C911,1000,920,991,920,980L920,90C920,-70,786,-200,620,-200ZM440,-200L-440,-200L-440,-820L440,-820L440,-200ZM140,-500L260,-500C271,-500,280,-509,280,-520L280,-640C280,-651,271,-660,260,-660L140,-660C129,-660,120,-651,120,-640L120,-520C120,-509,129,-500,140,-500Z",
  "M929,-784L418,-784C308,-784,201,-753,109,-693L0,-623L-109,-693C-201,-753,-308,-784,-418,-784L-929,-784C-968,-784,-1000,-752,-1000,-713L-1000,555C-1000,595,-968,627,-929,627L-418,627C-308,627,-201,658,-109,717L-10,781C-7,783,-4,784,0,784C3,784,6,783,9,781L108,717C201,658,308,627,418,627L929,627C968,627,1000,595,1000,555L1000,-713C1000,-752,968,-784,929,-784ZM-418,466L-839,466L-839,-623L-418,-623C-339,-623,-262,-601,-196,-558L-87,-488L-71,-478L-71,553C-178,496,-296,466,-418,466ZM839,466L418,466C296,466,178,496,71,553L71,-478L87,-488L196,-558C262,-601,339,-623,418,-623L839,-623L839,466ZM-257,-338L-672,-338C-680,-338,-688,-330,-688,-321L-688,-221C-688,-211,-680,-204,-672,-204L-257,-204C-248,-204,-241,-211,-241,-221L-241,-321C-241,-330,-248,-338,-257,-338ZM241,-321L241,-221C241,-211,248,-204,257,-204L671,-204C680,-204,687,-211,687,-221L687,-321C687,-330,680,-338,671,-338L257,-338C248,-338,241,-330,241,-321ZM-257,-25L-672,-25C-680,-25,-688,-18,-688,-8L-688,92C-688,101,-680,109,-672,109L-257,109C-248,109,-241,101,-241,92L-241,-8C-241,-18,-248,-25,-257,-25ZM672,-25L257,-25C248,-25,241,-18,241,-8L241,92C241,101,248,109,257,109L671,109C680,109,687,101,687,92L687,-8C688,-18,680,-25,672,-25Z",
  "M998,747L896,118C895,109,886,101,876,101L213,101C203,101,194,109,193,118L91,747C91,748,91,750,91,751C91,762,100,771,111,771L978,771C979,771,980,771,981,771C992,769,1000,759,998,747ZM-194,118C-196,109,-204,101,-214,101L-878,101C-888,101,-896,109,-898,118L-1000,747C-1000,748,-1000,750,-1000,751C-1000,762,-991,771,-980,771L-112,771C-111,771,-110,771,-109,771C-98,769,-91,759,-92,747L-194,118ZM-432,-101L435,-101C436,-101,438,-101,439,-102C450,-103,457,-114,455,-125L354,-754C352,-764,343,-771,334,-771L-330,-771C-340,-771,-348,-764,-350,-754L-452,-125C-452,-124,-452,-123,-452,-122C-452,-111,-443,-101,-432,-101Z",
  "M428,-149L-428,-149C-438,-149,-446,-141,-446,-132L-446,765C-446,774,-438,783,-428,783L428,783C438,783,446,774,446,765L446,-132C446,-141,438,-149,428,-149ZM-303,-7L303,-7L303,254L-303,254L-303,-7ZM303,640L-303,640L-303,379L303,379L303,640ZM-125,524ZM-196,524L-195,536L-192,548L-187,560L-180,570L-171,579L-161,586L-149,591L-137,594L-125,595L-113,594L-101,591L-89,586L-79,579L-70,570L-63,560L-58,548L-55,536L-54,524L-55,512L-58,500L-63,488L-70,478L-79,469L-89,462L-101,457L-113,454L-125,453L-137,454L-149,457L-161,462L-171,469L-180,478L-187,488L-192,500L-195,512L-196,524ZM-125,127ZM-196,127L-195,139L-192,151L-187,163L-180,173L-171,182L-161,189L-149,194L-137,197L-125,198L-113,197L-101,194L-89,189L-79,182L-70,173L-63,163L-58,151L-55,139L-54,127L-55,115L-58,103L-63,91L-70,81L-79,72L-89,65L-101,60L-113,57L-125,56L-137,57L-149,60L-161,65L-171,72L-180,81L-187,91L-192,103L-195,115L-196,127ZM667,-321C565,-591,305,-783,0,-783C-304,-783,-565,-591,-667,-321C-859,-271,-1000,-95,-999,113C-998,346,-817,535,-590,555C-579,556,-570,548,-570,537L-570,403C-570,394,-577,386,-586,385C-646,377,-703,351,-747,308C-800,256,-829,185,-829,111C-829,48,-809,-11,-771,-60C-734,-107,-681,-142,-624,-157L-539,-179L-508,-261C-489,-312,-462,-360,-429,-403C-395,-446,-356,-483,-312,-514C-220,-579,-112,-613,0,-613C113,-613,221,-579,312,-514C357,-483,396,-445,429,-403C463,-360,490,-312,509,-261L540,-179L624,-157C745,-125,829,-15,829,110C829,185,800,255,746,308C703,351,646,377,586,385C577,386,571,393,571,402L571,537C571,548,580,556,590,555C817,535,997,346,999,113C1000,-95,859,-270,667,-321Z",
  "M927,-693L-312,-693C-353,-693,-385,-660,-385,-619L-385,-78L-927,-78C-967,-78,-1000,-45,-1000,-5L-1000,619C-1000,660,-967,693,-927,693L312,693C353,693,385,660,385,619L385,78L927,78C967,78,1000,45,1000,5L1000,-619C1000,-660,967,-693,927,-693ZM229,537L-229,537L-229,78L229,78L229,537ZM844,-78L385,-78L385,-537L844,-537L844,-78Z",
  "M14,-118C7,-127,-7,-127,-14,-118L-264,198C-273,210,-265,227,-250,227L-85,227L-85,768C-85,778,-77,786,-67,786L67,786C77,786,85,778,85,768L85,227L250,227C265,227,273,210,264,198L14,-118ZM668,-324C566,-594,306,-786,0,-786C-305,-786,-565,-594,-667,-325C-859,-274,-1000,-100,-1000,107C-1000,354,-800,554,-554,554L-464,554C-454,554,-446,546,-446,536L-446,402C-446,392,-454,384,-464,384L-554,384C-629,384,-700,354,-752,300C-805,246,-833,173,-830,98C-828,39,-808,-17,-772,-63C-735,-111,-682,-146,-624,-161L-540,-183L-509,-265C-490,-316,-463,-363,-429,-406C-396,-449,-356,-486,-312,-518C-220,-582,-112,-616,0,-616C113,-616,221,-582,313,-518C357,-486,397,-449,430,-406C464,-363,490,-315,510,-265L540,-183L625,-161C746,-128,830,-18,830,107C830,181,802,251,749,303C697,355,628,384,554,384L464,384C454,384,446,392,446,402L446,536C446,546,454,554,464,554L554,554C800,554,1000,354,1000,107C1000,-100,859,-274,668,-324Z",
  "M982,-643L866,-643C856,-643,848,-635,848,-625L848,-71L643,-71L643,-464C643,-474,635,-482,625,-482L-143,-482L-143,482L625,482C635,482,643,474,643,464L643,80L848,80L848,625C848,635,856,643,866,643L982,643C992,643,1000,635,1000,625L1000,-625C1000,-635,992,-643,982,-643ZM-643,-464L-643,-71L-848,-71L-848,-625C-848,-635,-856,-643,-866,-643L-982,-643C-992,-643,-1000,-635,-1000,-625L-1000,625C-1000,635,-992,643,-982,643L-866,643C-856,643,-848,635,-848,625L-848,80L-643,80L-643,464C-643,474,-635,482,-625,482L-286,482L-286,-482L-625,-482C-635,-482,-643,-474,-643,-464Z",
  "M668,-208C566,-478,306,-670,0,-670C-305,-670,-565,-478,-667,-208C-859,-158,-1000,16,-1000,223C-1000,470,-800,670,-554,670L554,670C800,670,1000,470,1000,223C1000,16,859,-158,668,-208ZM749,419C697,471,628,500,554,500L-554,500C-628,500,-697,471,-749,419C-802,367,-830,297,-830,223C-830,161,-810,102,-772,53C-735,5,-682,-29,-624,-45L-540,-67L-509,-148C-490,-199,-463,-247,-429,-290C-396,-333,-356,-370,-312,-401C-220,-466,-112,-500,0,-500C113,-500,221,-466,313,-401C357,-370,397,-333,430,-290C464,-247,490,-199,510,-148L540,-67L625,-45C746,-12,830,98,830,223C830,297,802,367,749,419Z",
  "M980,-540L815,-540L815,-780C815,-791,806,-800,795,-800L665,-800C654,-800,645,-791,645,-780L645,-540L480,-540C469,-540,460,-531,460,-520L460,520C460,531,469,540,480,540L645,540L645,780C645,791,654,800,665,800L795,800C806,800,815,791,815,780L815,540L980,540C991,540,1000,531,1000,520L1000,-520C1000,-531,991,-540,980,-540ZM-480,-720L-645,-720L-645,-860C-645,-871,-654,-880,-665,-880L-795,-880C-806,-880,-815,-871,-815,-860L-815,-720L-980,-720C-991,-720,-1000,-711,-1000,-700L-1000,700C-1000,711,-991,720,-980,720L-815,720L-815,860C-815,871,-806,880,-795,880L-665,880C-654,880,-645,871,-645,860L-645,720L-480,720C-469,720,-460,711,-460,700L-460,-700C-460,-711,-469,-720,-480,-720ZM250,-270L85,-270L85,-700C85,-711,76,-720,65,-720L-65,-720C-76,-720,-85,-711,-85,-700L-85,-270L-250,-270C-261,-270,-270,-261,-270,-250L-270,250C-270,261,-261,270,-250,270L-85,270L-85,700C-85,711,-76,720,-65,720L65,720C76,720,85,711,85,700L85,270L250,270C261,270,270,261,270,250L270,-250C270,-261,261,-270,250,-270Z",
  "M250,433L85,433L85,-108C85,-118,77,-126,67,-126L-67,-126C-77,-126,-85,-118,-85,-108L-85,433L-250,433C-265,433,-273,450,-264,461L-14,778C-7,787,7,787,14,778L264,461C273,450,265,433,250,433ZM668,-325C566,-595,306,-787,0,-787C-305,-787,-565,-595,-667,-326C-859,-275,-1000,-101,-1000,106C-1000,353,-800,552,-554,552L-464,552C-454,552,-446,544,-446,535L-446,401C-446,391,-454,383,-464,383L-554,383C-629,383,-700,353,-752,299C-805,245,-833,172,-830,96C-828,37,-808,-18,-772,-65C-735,-112,-682,-147,-624,-162L-540,-184L-509,-266C-490,-317,-463,-364,-429,-407C-396,-450,-356,-488,-312,-519C-220,-583,-112,-617,0,-617C113,-617,221,-583,313,-519C357,-488,397,-450,430,-407C464,-364,490,-317,510,-266L540,-184L625,-162C746,-129,830,-19,830,106C830,180,802,250,749,302C697,354,628,383,554,383L464,383C454,383,446,391,446,401L446,535C446,544,454,552,464,552L554,552C800,552,1000,353,1000,106C1000,-101,859,-275,668,-325Z",
  "M224,258C145,263,152,221,199,159C307,16,505,-178,514,-320C527,-505,341,-562,150,-562C17,-558,-120,-521,-214,-488C-537,-374,-739,-195,-867,6C-1000,205,-959,396,-672,401C-455,393,-309,332,-161,256C-160,256,-571,374,-723,288C-740,279,-757,266,-761,232C-761,161,-645,88,-577,64L-577,-56C-439,-8,-277,-22,-139,-125C-134,-112,-130,-97,-131,-80L-108,-80C-102,-128,-134,-175,-188,-178C-173,-166,-161,-156,-156,-147L-158,-145L-159,-144C-338,-19,-511,-77,-527,-80L-428,-177L-456,-248C-258,-317,-95,-367,176,-415L115,-464L147,-483C308,-439,416,-405,410,-320C408,-306,402,-289,394,-271C346,-176,205,-23,148,43C111,87,74,127,48,167C19,208,5,247,4,281C9,562,837,149,1000,41C762,142,504,240,224,258ZM405,-387C411,-376,414,-363,414,-347C413,-361,411,-375,405,-387Z",
  "M667,-321C565,-591,305,-783,0,-783C-304,-783,-565,-591,-667,-321C-859,-271,-1000,-95,-999,113C-998,346,-817,535,-590,555C-579,556,-570,548,-570,537L-570,403C-570,394,-577,386,-586,385C-646,377,-703,351,-747,308C-800,256,-829,185,-829,111C-829,48,-809,-11,-771,-60C-734,-107,-681,-142,-624,-157L-539,-179L-508,-261C-489,-312,-462,-360,-429,-403C-395,-446,-356,-483,-312,-514C-220,-579,-112,-613,0,-613C113,-613,221,-579,312,-514C357,-483,396,-445,429,-403C463,-360,490,-312,509,-261L540,-179L624,-157C745,-125,829,-15,829,110C829,185,800,255,746,308C703,351,646,377,586,385C577,386,571,393,571,402L571,537C571,548,580,556,590,555C817,535,997,346,999,113C1000,-95,859,-270,667,-321ZM-301,320C-297,245,-266,175,-213,122C-157,65,-79,33,1,33C81,33,158,65,215,122C218,125,221,128,224,132L168,175C156,185,160,203,175,207L394,260C405,263,416,255,416,243L417,17C417,2,400,-6,388,3L337,44C255,-50,135,-109,1,-109C-238,-109,-434,81,-444,318C-444,328,-436,337,-426,337L-319,337C-310,337,-302,329,-301,320ZM426,337L319,337C310,337,302,344,301,354C297,428,266,498,213,551C156,608,79,640,-1,640C-82,640,-158,608,-215,551C-218,548,-221,545,-224,542L-168,498C-157,489,-161,470,-175,466L-394,413C-405,410,-416,419,-416,430L-417,656C-417,671,-400,680,-388,670L-337,630C-255,723,-135,783,-1,783C238,783,434,593,444,355C444,345,436,337,426,337Z",
  "M1000,-287C999,-471,850,-620,667,-620L143,-620L191,-429L641,-331C682,-322,712,-286,714,-243C714,-242,714,240,714,242C712,285,682,321,641,330L191,428L143,619L667,619C850,619,999,470,1000,287L1000,-287ZM-640,331C-681,321,-712,285,-714,242C-714,241,-714,-241,-714,-242C-712,-286,-681,-322,-640,-331L-191,-429L-143,-619L-667,-619C-850,-619,-999,-471,-1000,-287L-1000,287C-999,471,-850,620,-667,620L-143,620L-191,429L-640,331ZM-191,-24L191,-24L191,23L-191,23Z",
  "M893,-468L607,-304L607,-643C607,-722,543,-786,464,-786L-857,-786C-936,-786,-1000,-722,-1000,-643L-1000,643C-1000,722,-936,786,-857,786L464,786C543,786,607,722,607,643L607,304L893,468C940,496,1000,461,1000,406L1000,-406C1000,-461,940,-496,893,-468ZM446,625L-839,625L-839,-625L446,-625L446,625ZM839,252L607,119L607,-119L839,-252L839,252ZM-679,-339L-429,-339C-419,-339,-411,-347,-411,-357L-411,-464C-411,-474,-419,-482,-429,-482L-679,-482C-688,-482,-696,-474,-696,-464L-696,-357C-696,-347,-688,-339,-679,-339Z",
  "M449,-438C491,-480,491,-548,449,-589L295,-744L295,-743C254,-784,184,-854,85,-954C38,-999,-38,-999,-84,-952L-953,-84C-1000,-38,-1000,38,-953,85L-84,953C-38,999,38,999,84,953L449,589C491,547,491,479,449,437C407,395,339,395,297,437L21,713C10,725,-8,725,-20,713L-714,20C-725,9,-725,-9,-714,-21L-20,-714C-19,-715,-18,-716,-17,-717C-5,-726,10,-725,21,-714L297,-438C339,-396,407,-396,449,-438ZM-230,5L-227,43L-217,81L-202,116L-181,149L-154,177L-124,201L-90,219L-53,232L-15,238L24,238L62,232L99,219L133,201L163,177L190,149L211,116L226,81L236,43L239,5L236,-34L226,-71L211,-107L190,-139L163,-168L133,-192L99,-210L62,-223L24,-229L-15,-229L-53,-223L-90,-210L-124,-192L-154,-168L-181,-139L-202,-107L-217,-71L-227,-34L-230,5ZM953,-81L682,-350C640,-392,572,-392,530,-350C488,-309,488,-241,530,-199L714,-16C725,-4,725,13,714,25L533,205C491,247,491,315,533,357C575,398,643,398,685,357L953,88C1000,41,1000,-34,953,-81Z",
  "M920,-1000C910,-1000,901,-998,891,-994L-550,-415L-960,-415C-982,-415,-1000,-397,-1000,-374L-1000,374C-1000,397,-982,415,-960,415L-706,415C-715,444,-720,475,-720,506C-720,671,-586,805,-420,805C-282,805,-165,711,-130,584L891,994C901,998,911,1000,920,1000C962,1000,1000,965,1000,917L1000,-917C1000,-965,962,-1000,920,-1000ZM-420,626C-486,626,-540,572,-540,506C-540,478,-530,451,-513,430L-300,515C-305,577,-357,626,-420,626ZM820,772L-483,248L-515,235L-820,235L-820,-235L-515,-235L-483,-248L820,-772L820,772Z",
  "M-297,504C-304,504,-311,503,-317,501L-307,569L-248,569L-283,503C-287,504,-292,504,-297,504ZM643,-146C615,-146,587,-142,561,-136C513,-222,422,-280,317,-280C302,-280,287,-279,272,-276C193,-449,19,-569,-183,-569C-434,-569,-641,-385,-678,-144C-859,-126,-1000,26,-1000,212C-1000,409,-840,569,-643,569L-531,569L-502,508C-560,489,-598,443,-589,399C-579,351,-516,323,-448,337C-397,348,-358,380,-347,416C-336,399,-318,388,-297,388L-297,388C-299,381,-300,374,-300,366C-300,321,-267,284,-223,278L-223,221C-223,211,-215,203,-206,203C-196,203,-188,211,-188,221L-188,280C-177,282,-168,287,-160,293L-116,245C-109,237,-98,237,-91,244C-83,250,-83,262,-90,269L-134,318L-135,319C-126,332,-121,349,-121,366C-121,416,-161,456,-210,456C-221,456,-230,454,-240,451C-240,463,-245,475,-253,484L-208,569L652,569L652,569C845,564,1000,406,1000,212C1000,14,840,-146,643,-146ZM-388,502L-398,569L-343,569L-356,477C-364,487,-375,496,-388,502ZM744,-462ZM637,-462L639,-444L644,-426L652,-409L662,-393L676,-380L691,-369L708,-362L726,-357L744,-355L763,-357L781,-362L798,-369L813,-380L826,-393L837,-409L845,-426L850,-444L852,-462L850,-481L845,-499L837,-516L826,-531L813,-544L798,-555L781,-563L763,-568L744,-569L726,-568L708,-563L691,-555L676,-544L662,-531L652,-516L644,-499L639,-481L637,-462ZM544,-325ZM491,-325L491,-317L494,-308L497,-300L502,-293L508,-286L515,-281L523,-276L531,-274L540,-272L549,-272L557,-274L566,-276L573,-281L580,-286L586,-293L591,-300L595,-308L597,-317L598,-325L597,-334L595,-343L591,-351L586,-358L580,-365L573,-370L566,-375L557,-377L549,-379L540,-379L531,-377L523,-375L515,-370L508,-365L502,-358L497,-351L494,-343L491,-334L491,-325ZM-466,515L-492,569L-433,569L-426,514C-438,516,-452,517,-466,515Z",
  "M260,-906C247,-906,233,-903,220,-894L-589,-365L-963,-365C-984,-365,-1000,-349,-1000,-329L-1000,329C-1000,349,-984,365,-963,365L-589,365L220,894C233,903,247,906,260,906C298,906,333,876,333,833L333,-833C333,-876,298,-906,260,-906ZM169,664L-499,228L-540,201L-836,201L-836,-201L-540,-201L-499,-228L169,-664L169,664ZM963,-82L671,-82C651,-82,635,-66,635,-46L635,46C635,66,651,82,671,82L963,82C984,82,1000,66,1000,46L1000,-46C1000,-66,984,-82,963,-82ZM868,516L616,370C610,367,604,365,598,365C585,365,573,372,566,384L521,462C511,480,517,502,534,512L786,658C792,661,798,662,804,662C817,662,829,656,836,644L881,565C891,548,885,526,868,516ZM566,-384C573,-372,585,-365,598,-365C604,-365,610,-367,616,-370L868,-516C885,-526,891,-548,881,-565L836,-644C829,-655,817,-662,804,-662C798,-662,792,-661,786,-657L534,-512C517,-502,511,-479,521,-462L566,-384Z",
  "M306,-545L805,-545L805,-424L306,-424ZM-194,-66C-84,-118,-26,-199,-26,-323C-26,-568,-209,-628,-420,-628L-1000,-628L-1000,604L-403,604C-180,604,30,496,30,246C30,92,-43,-23,-194,-66ZM-729,-418L-475,-418C-378,-418,-290,-390,-290,-277C-290,-172,-358,-130,-455,-130L-729,-130L-729,-418ZM-440,395L-730,395L-730,56L-435,56C-316,56,-240,105,-240,232C-240,356,-330,395,-440,395ZM1000,171C1000,-93,846,-313,566,-313C295,-313,110,-108,110,159C110,437,285,628,566,628C779,628,917,532,983,328L768,328C744,404,649,444,574,444C431,444,356,360,356,217L998,217C999,202,1000,187,1000,171ZM356,62C363,-55,442,-128,559,-128C682,-128,743,-56,754,62L356,62Z",
  "M963,-267L44,-935L34,-942L23,-946L12,-949L0,-950L-12,-949L-23,-946L-34,-942L-44,-935L-963,-267C-989,-248,-1000,-214,-990,-184L-639,898C-629,929,-600,950,-568,950L568,950C601,950,629,929,639,898L990,-184C1000,-214,989,-248,963,-267ZM758,-221L530,-146L65,-482L65,-725L758,-221ZM-107,128L-314,412L-442,19L-107,128ZM-377,-97L-65,-322L-65,5L-377,-97ZM0,203L218,502L-218,502L0,203ZM65,-322L377,-97L65,5L65,-322ZM107,128L442,19L314,412L107,128ZM-65,-725L-65,-482L-530,-146L-758,-221L-65,-725ZM-796,-96L-595,-30L-408,542L-533,713L-796,-96ZM-429,792L-313,632L313,632L430,792L-429,792ZM533,713L408,542L595,-30L796,-96L533,713Z",
  "M821,-112C820,-172,820,-232,820,-292L641,-292C640,-232,640,-172,639,-112C579,-112,519,-111,460,-111L460,68C519,69,580,69,639,70C640,130,640,190,640,250L819,250C820,190,820,130,820,70C881,69,940,69,1000,68L1000,-111C940,-111,880,-111,821,-112ZM-352,-111C-352,-40,-352,32,-351,104C-232,107,-111,106,8,107C-44,374,-406,460,-597,286C-794,134,-785,-201,-580,-342C-437,-456,-234,-428,-91,-329C-35,-381,18,-437,69,-495C-50,-589,-196,-657,-352,-650C-676,-661,-974,-377,-979,-52C-1000,213,-826,473,-580,566C-335,661,-20,597,136,376C240,237,262,58,250,-110C49,-112,-151,-112,-352,-111Z",
  "M-115,-1000L-917,-1000C-963,-1000,-1000,-963,-1000,-917L-1000,-115C-1000,-103,-991,-94,-979,-94L-115,-94C-103,-94,-94,-103,-94,-115L-94,-979C-94,-991,-103,-1000,-115,-1000ZM-260,-260L-833,-260L-833,-833L-260,-833L-260,-260ZM-620,-453L-474,-453C-462,-453,-453,-462,-453,-474L-453,-620C-453,-631,-462,-641,-474,-641L-620,-641C-631,-641,-641,-631,-641,-620L-641,-474C-641,-462,-631,-453,-620,-453ZM-115,94L-979,94C-991,94,-1000,103,-1000,115L-1000,917C-1000,963,-963,1000,-917,1000L-115,1000C-103,1000,-94,991,-94,979L-94,115C-94,103,-103,94,-115,94ZM-260,833L-833,833L-833,260L-260,260L-260,833ZM-620,641L-474,641C-462,641,-453,631,-453,620L-453,474C-453,462,-462,453,-474,453L-620,453C-631,453,-641,462,-641,474L-641,620C-641,631,-631,641,-620,641ZM917,-1000L115,-1000C103,-1000,94,-991,94,-979L94,-115C94,-103,103,-94,115,-94L979,-94C991,-94,1000,-103,1000,-115L1000,-917C1000,-963,963,-1000,917,-1000ZM833,-260L260,-260L260,-833L833,-833L833,-260ZM474,-453L620,-453C631,-453,641,-462,641,-474L641,-620C641,-631,631,-641,620,-641L474,-641C462,-641,453,-631,453,-620L453,-474C453,-462,462,-453,474,-453ZM979,94L854,94C843,94,833,103,833,115L833,464L630,464L630,115C630,103,621,94,609,94L115,94C103,94,94,103,94,115L94,979C94,991,103,1000,115,1000L240,1000C251,1000,260,991,260,979L260,344L464,344L464,609C464,621,473,630,484,630L979,630C991,630,1000,621,1000,609L1000,115C1000,103,991,94,979,94ZM609,833L484,833C473,833,464,843,464,854L464,979C464,991,473,1000,484,1000L609,1000C621,1000,630,991,630,979L630,854C630,843,621,833,609,833ZM979,833L854,833C843,833,833,843,833,854L833,979C833,991,843,1000,854,1000L979,1000C991,1000,1000,991,1000,979L1000,854C1000,843,991,833,979,833Z",
  "M840,-609L1000,-762L1000,-796L447,-796L53,190L-395,-796L-975,-796L-975,-762L-788,-536C-770,-520,-761,-495,-763,-471L-763,415C-757,447,-767,480,-790,503L-1000,759L-1000,792L-405,792L-405,759L-615,503C-637,480,-648,448,-643,416L-643,-351L-121,793L-60,793L389,-351L389,560C389,584,389,589,374,605L212,762L212,796L996,796L996,762L840,609C827,598,820,581,823,564L823,-564C820,-581,827,-598,840,-609Z",
  "M929,-786L-929,-786C-968,-786,-1000,-754,-1000,-714L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-714C1000,-754,968,-786,929,-786ZM839,625L-839,625L-839,-625L839,-625L839,625ZM-631,441C-625,448,-613,448,-606,441L-221,56L34,312C41,319,52,319,59,312L722,-352C729,-358,729,-370,722,-377L640,-459C633,-466,622,-466,615,-459L47,109L-208,-146C-215,-153,-227,-153,-234,-146L-713,334C-720,341,-720,352,-713,359L-631,441Z",
  "M961,-182L20,-182L20,205L558,205C535,330,464,436,358,507C269,567,154,602,20,602C-241,602,-461,426,-540,190C-559,130,-571,66,-571,0C-571,-66,-559,-130,-540,-190C-461,-426,-240,-602,20,-602C167,-602,298,-552,402,-453L689,-739C515,-901,289,-1000,20,-1000C-371,-1000,-709,-776,-873,-449C-941,-314,-979,-161,-979,0C-979,162,-941,314,-873,449C-709,776,-371,1000,20,1000C290,1000,516,910,681,758C870,584,979,327,979,23C979,-48,973,-116,961,-182Z",
  "M929,-786L-929,-786C-968,-786,-1000,-754,-1000,-714L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-714C1000,-754,968,-786,929,-786ZM839,625L-839,625L-839,536L-530,169L-195,567L326,-51L839,557L839,625ZM839,335L340,-257C333,-266,320,-266,312,-257L-195,345L-517,-36C-524,-45,-537,-45,-544,-36L-839,314L-839,-625L839,-625L839,335ZM-464,-125C-356,-125,-268,-213,-268,-321C-268,-430,-356,-518,-464,-518C-573,-518,-661,-430,-661,-321C-661,-213,-573,-125,-464,-125ZM-464,-384C-430,-384,-402,-356,-402,-321C-402,-287,-430,-259,-464,-259C-499,-259,-527,-287,-527,-321C-527,-356,-499,-384,-464,-384Z",
  "M816,-337C854,-425,892,-552,892,-650C892,-909,608,-1000,145,-787C-238,-813,-606,-525,-698,-123C-589,-248,-420,-416,-264,-483C-458,-312,-622,-94,-747,133C-821,268,-904,486,-904,649C-904,1000,-573,957,-262,799C-150,853,-25,854,100,854C445,854,756,661,871,334L441,334C254,650,-259,523,-259,165L911,165C934,10,905,-175,816,-337ZM-674,329C-611,511,-483,670,-317,768C-633,942,-934,872,-674,329ZM-261,-58C-254,-255,-82,-396,109,-396C299,-396,472,-255,479,-58L-261,-58ZM396,-726C472,-763,568,-804,654,-804C766,-804,847,-727,847,-613C847,-542,821,-439,795,-372C702,-522,560,-662,396,-726Z",
  "M929,-786L-929,-786C-968,-786,-1000,-754,-1000,-714L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-714C1000,-754,968,-786,929,-786ZM839,-538L839,625L-839,625L-839,-538L-901,-586L-813,-699L-718,-625L718,-625L813,-699L901,-586L839,-538ZM718,-625L0,-67L-718,-625L-813,-699L-901,-587L-840,-539L-77,54C-32,89,31,89,76,54L839,-538L901,-586L813,-699L718,-625Z",
  "M782,644C774,641,764,643,753,647C598,717,449,768,303,797C-12,862,-318,828,-616,697C-699,661,-814,599,-961,512C-965,509,-970,507,-975,507C-980,507,-984,507,-988,509C-992,511,-995,514,-997,517C-999,520,-1000,525,-998,531C-997,536,-993,542,-987,549C-961,580,-928,612,-890,647C-852,681,-801,720,-738,764C-675,807,-608,846,-539,880C-470,914,-390,942,-299,965C-208,988,-116,1000,-25,1000C65,1000,153,990,239,972C324,954,396,933,455,908C514,883,568,855,617,825C667,795,703,769,727,749C751,729,768,713,778,701C789,686,795,674,795,663C795,652,791,646,782,644ZM38,-409C0,-406,-46,-399,-100,-388C-154,-378,-203,-365,-249,-350C-295,-335,-343,-313,-390,-286C-438,-259,-479,-228,-513,-194C-547,-159,-574,-116,-596,-64C-617,-12,-628,46,-628,108C-628,176,-616,236,-592,290C-568,343,-537,385,-497,416C-457,447,-412,471,-362,489C-311,507,-258,515,-203,512C-148,510,-95,502,-42,486C10,472,59,448,104,416C150,383,187,345,216,301C227,318,237,330,245,338L267,360C281,375,304,397,334,426C364,454,394,482,425,510L686,260L671,248C660,240,647,228,633,212C618,197,604,179,590,161C575,142,563,120,553,96C543,71,537,48,537,25L537,-633C537,-658,533,-685,523,-715C513,-744,496,-776,471,-811C446,-845,415,-876,378,-903C341,-930,291,-953,229,-972C167,-990,98,-1000,21,-1000C-57,-1000,-130,-990,-198,-972C-266,-954,-324,-930,-373,-899C-421,-869,-462,-834,-497,-793C-531,-753,-557,-711,-574,-667C-591,-623,-599,-579,-599,-534L-261,-505C-247,-546,-229,-581,-206,-612C-183,-642,-161,-664,-141,-678C-121,-692,-100,-703,-77,-711C-54,-719,-39,-723,-31,-724C-23,-725,-16,-725,-12,-725C55,-725,102,-706,128,-666C144,-643,152,-607,152,-558L152,-416C114,-415,76,-412,38,-409ZM152,-29C152,12,147,50,136,83C113,156,69,202,5,221C-51,237,-105,229,-155,196C-209,161,-236,111,-236,48C-236,-2,-223,-45,-198,-80C-173,-115,-140,-142,-98,-159C-56,-177,-16,-190,25,-197C64,-204,107,-209,152,-210L152,-29ZM991,519C980,505,951,496,903,492C856,487,815,487,779,493C741,497,701,508,661,526C620,544,602,559,607,571L608,574L611,576L614,576L626,576C628,576,630,576,634,576C637,576,640,575,643,575C646,575,651,574,656,574C661,574,666,573,671,572C672,572,681,571,697,570C714,568,726,567,733,567C740,566,752,565,769,564C786,564,799,564,809,564C819,565,831,566,843,567C856,568,866,570,874,574C882,577,888,581,892,587C905,603,903,640,885,696C867,753,850,798,834,832C827,846,827,855,834,859C841,863,850,859,863,849C902,818,935,772,961,710C976,674,987,636,994,596C1000,556,999,531,991,519Z",
  "M971,71C943,-18,848,-66,760,-37L572,24L449,-355L637,-416C725,-444,773,-539,744,-627C716,-716,621,-764,533,-735L345,-674L283,-863C254,-952,160,-1000,71,-971C-17,-943,-65,-848,-36,-760L25,-570L-353,-447L-415,-637C-444,-725,-539,-773,-627,-744C-715,-716,-763,-621,-734,-533L-673,-343L-863,-281C-952,-253,-1000,-158,-971,-70C-943,19,-848,67,-760,38L-569,-24L-446,355L-637,417C-725,445,-773,540,-745,628C-716,717,-621,765,-533,736L-343,674L-281,863C-252,952,-157,1000,-69,971C19,943,67,848,39,760L-23,570L355,447L417,637C446,725,541,773,629,744C717,716,765,621,737,533L676,344L863,282C952,254,1000,159,971,71ZM-127,251L-250,-128L129,-251L252,128L-127,251Z",
  "M929,-786L-929,-786C-968,-786,-1000,-754,-1000,-714L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-714C1000,-754,968,-786,929,-786ZM839,625L-839,625L-839,-625L839,-625L839,625ZM219,-80L495,-80C498,-80,500,-88,500,-98L500,-205C500,-215,498,-223,495,-223L219,-223C217,-223,214,-215,214,-205L214,-98C214,-88,217,-80,219,-80ZM230,241L645,241C653,241,660,233,660,223L660,116C660,106,653,98,645,98L230,98C221,98,214,106,214,116L214,223C214,233,221,241,230,241ZM-643,359L-545,359C-535,359,-528,352,-527,343C-519,230,-425,141,-310,141C-196,141,-102,230,-93,343C-93,352,-85,359,-76,359L22,359C33,359,41,351,40,341C34,222,-31,118,-126,59C-86,15,-61,-44,-61,-109C-61,-248,-173,-359,-310,-359C-447,-359,-559,-248,-559,-109C-559,-44,-534,15,-494,59C-589,118,-654,222,-660,341C-661,351,-653,359,-643,359ZM-310,-225C-247,-225,-195,-173,-195,-109C-195,-45,-247,7,-310,7C-374,7,-426,-45,-426,-109C-426,-173,-374,-225,-310,-225Z",
  "M639,293C557,266,447,224,325,180C399,52,457,-93,496,-250L93,-250L93,-395L586,-395L586,-476L93,-476L93,-718L-109,-718C-144,-718,-144,-683,-144,-683L-144,-476L-643,-476L-643,-395L-144,-395L-144,-250L-556,-250L-556,-169L243,-169C214,-69,175,26,128,111C-131,26,-408,-43,-582,-1C-693,27,-765,76,-807,127C-1000,361,-862,718,-454,718C-213,717,20,583,200,362C468,491,1000,712,1000,712L1000,397C1000,397,933,391,639,293ZM-492,581C-810,581,-904,331,-746,194C-694,148,-598,125,-547,120C-358,102,-183,173,23,274C-122,463,-307,581,-492,581Z",
  "M929,-786L-929,-786C-968,-786,-1000,-754,-1000,-714L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-714C1000,-754,968,-786,929,-786ZM-839,-625L839,-625L839,-357L-839,-357L-839,-625ZM839,625L-839,625L-839,-161L839,-161L839,625ZM310,482L679,482C688,482,696,474,696,464L696,304C696,294,688,286,679,286L310,286C300,286,292,294,292,304L292,464C292,474,300,482,310,482Z",
  "M-861,-616L-858,-587L-851,-559L-838,-532L-821,-508L-801,-487L-777,-470L-750,-458L-721,-450L-692,-447L-663,-450L-634,-458L-608,-470L-583,-487L-563,-508L-546,-532L-533,-559L-526,-587L-523,-616L-525,-644L-532,-671L-543,-697L-559,-720L-578,-741L-600,-758L-624,-771L-651,-780L-678,-785L-706,-785L-733,-780L-760,-771L-784,-758L-806,-741L-825,-720L-841,-697L-852,-671L-859,-644L-861,-616ZM935,-422C935,-422,877,-875,-115,-594C-73,-668,-52,-716,-52,-716L-300,-785C-300,-785,-400,-459,-578,-307C-578,-307,-406,-207,-408,-210C-358,-260,-314,-310,-276,-359C-236,-376,-198,-392,-161,-408C-206,-325,-280,-201,-354,-123L-250,-32C-250,-32,-179,-100,-102,-183L-13,-183L-13,-31L-358,-31L-358,91L-13,91L-13,383C-17,383,-22,383,-26,382C-64,380,-123,374,-147,337C-175,293,-154,211,-153,161L-391,161L-400,165C-400,165,-487,556,-148,547C169,556,351,459,439,392L474,522L670,440L537,115L378,165L408,276C367,307,320,330,270,346L270,91L607,91L607,-31L270,-31L270,-183L608,-183L608,-304L7,-304C50,-357,84,-406,93,-436L-12,-465C438,-626,688,-598,686,-334L686,362C686,362,713,601,439,583L291,552L256,692C256,692,895,875,948,384C1000,-108,935,-422,935,-422ZM-805,-377L-917,-205L-711,-77C-711,-77,-574,-7,-639,125C-700,249,-1000,522,-1000,522L-732,689C-546,286,-558,340,-512,195C-464,48,-453,-65,-535,-147C-639,-252,-650,-261,-805,-377Z",
  "M951,-531C920,-603,876,-667,820,-722C763,-777,698,-820,625,-851C550,-882,470,-898,388,-898C274,-898,163,-866,66,-807C43,-793,21,-778,0,-761C-21,-778,-43,-793,-66,-807C-163,-866,-274,-898,-388,-898C-470,-898,-550,-882,-625,-851C-698,-821,-763,-777,-820,-722C-876,-667,-920,-603,-951,-531C-984,-456,-1000,-376,-1000,-295C-1000,-218,-984,-137,-953,-56C-927,13,-889,84,-841,155C-766,268,-661,386,-531,506C-317,704,-104,841,-95,847L-40,882C-16,898,16,898,40,882L95,847C104,841,316,704,531,506C661,386,765,268,841,155C889,84,927,13,953,-56C984,-137,1000,-218,1000,-295C1000,-376,984,-456,951,-531ZM0,699C0,699,-824,171,-824,-295C-824,-531,-629,-722,-388,-722C-219,-722,-72,-627,0,-489C72,-627,219,-722,388,-722C629,-722,824,-531,824,-295C824,171,0,699,0,699Z",
  "M141,-748L141,775L301,775L368,965L650,775L1000,775L1000,-748L141,-748ZM800,573L640,573L441,707L393,573L346,573L346,-540L799,-540L799,573ZM39,-65L-314,-65C-309,-184,-303,-342,-297,-525L51,-525L51,-546C51,-548,50,-585,45,-624C39,-663,27,-716,-11,-716L-595,-716C-583,-771,-553,-902,-517,-966L-500,-995L-534,-997C-536,-997,-586,-1000,-644,-969C-739,-919,-781,-819,-800,-745C-849,-550,-918,-415,-948,-358C-957,-341,-962,-331,-964,-324C-969,-311,-967,-298,-957,-289C-929,-264,-855,-297,-855,-297C-853,-298,-851,-299,-849,-300C-812,-317,-702,-366,-663,-524L-513,-524C-511,-439,-504,-157,-505,-65L-880,-65L-885,-61C-947,-16,-966,107,-967,112L-971,137L-527,137C-560,345,-597,438,-617,475C-627,494,-637,513,-646,531C-702,643,-761,759,-981,939C-991,946,-1000,960,-994,975C-988,992,-969,1000,-929,1000C-914,1000,-897,999,-877,997C-745,985,-609,949,-518,764C-473,671,-434,574,-401,475L-39,900L-25,868C-23,863,25,745,-12,613L-13,608L-300,281L-359,326C-342,256,-331,193,-326,137L96,137L96,115C96,9,47,-54,45,-57L39,-65Z",
  "M956,-378L378,-378L378,-956C378,-980,358,-1000,333,-1000L-956,-1000C-980,-1000,-1000,-980,-1000,-956L-1000,333C-1000,358,-980,378,-956,378L-378,378L-378,956C-378,980,-358,1000,-333,1000L956,1000C980,1000,1000,980,1000,956L1000,-333C1000,-358,980,-378,956,-378ZM-378,-333L-378,189L-811,189L-811,-811L189,-811L189,-378L-333,-378C-358,-378,-378,-358,-378,-333ZM189,-189L189,189L-189,189L-189,-189L189,-189ZM811,811L-189,811L-189,378L333,378C358,378,378,358,378,333L378,-189L811,-189L811,811Z",
  "M-882,-1000L-723,795L0,1000L720,795L882,-1000L-882,-1000ZM587,684L0,851L-590,684L-726,-857L726,-857L587,684ZM-555,-632L-551,-574L-496,36L0,36L0,35L272,35L244,320L-2,387L-2,387L-4,387L-250,321L-266,145L-484,145L-457,493L-4,618L0,618L0,617L451,492L455,453L506,-129L514,-188L-2,-188L-2,-187L-293,-187L-313,-413L534,-413L538,-460L549,-574L553,-632L-2,-632Z",
  "M0,456ZM-105,456L-104,474L-99,492L-91,509L-81,524L-68,537L-53,547L-36,555L-18,560L0,561L18,560L36,555L53,547L68,537L81,524L91,509L99,492L104,474L105,456L104,438L99,420L91,404L81,388L68,376L53,365L36,357L18,352L0,351L-18,352L-36,357L-53,365L-68,376L-81,388L-91,404L-99,420L-104,438L-105,456ZM-70,-211L-70,193C-70,203,-62,211,-53,211L53,211C62,211,70,203,70,193L70,-211C70,-220,62,-228,53,-228L-53,-228C-62,-228,-70,-220,-70,-211ZM973,754L61,-825C47,-848,24,-860,0,-860C-24,-860,-47,-848,-61,-825L-973,754C-1000,801,-966,860,-912,860L912,860C966,860,1000,801,973,754ZM-745,693L0,-597L745,693L-745,693Z",
  "M839,-1000L-839,-1000C-928,-1000,-1000,-928,-1000,-839L-1000,839C-1000,928,-928,1000,-839,1000L839,1000C928,1000,1000,928,1000,839L1000,-839C1000,-928,928,-1000,839,-1000ZM839,840C-280,840,-840,839,-840,839C-840,-280,-839,-840,-839,-840C280,-840,840,-839,840,-839C840,280,839,840,839,840ZM-703,-250L-407,-250L-407,704L-703,704ZM-555,-381C-460,-381,-383,-458,-383,-553C-383,-647,-460,-725,-555,-725C-650,-725,-727,-648,-727,-553C-727,-458,-650,-381,-555,-381ZM76,232C76,107,100,-13,254,-13C406,-13,408,129,408,240L408,704L704,704L704,181C704,-76,649,-274,349,-274C204,-274,108,-195,68,-120L64,-120L64,-250L-221,-250L-221,704L76,704L76,232Z",
  "M930,-281L335,-367L68,-907C61,-922,49,-934,34,-941C-3,-959,-48,-944,-66,-907L-333,-367L-928,-281C-945,-278,-960,-271,-971,-259C-1000,-229,-1000,-182,-970,-153L-539,268L-641,861C-643,877,-641,894,-633,909C-614,945,-568,959,-532,940L1,660L534,940C548,948,565,950,581,947C622,940,650,902,643,861L541,268L972,-153C984,-164,991,-179,994,-196C1000,-237,971,-275,930,-281ZM360,208L444,702L1,469L-442,702L-357,209L-716,-141L-220,-213L1,-662L223,-213L718,-141L360,208Z",
  "M770,376L739,376C678,376,629,425,629,486L629,517C629,577,678,627,739,627L770,627C830,627,880,577,880,517L880,486C880,425,830,376,770,376ZM-248,-627C-663,-627,-1000,-346,-1000,0C-1000,346,-663,627,-248,627C167,627,503,346,503,0C503,-346,167,-627,-248,-627ZM-248,502C-599,502,-875,272,-875,0C-875,-139,-803,-267,-686,-359L-686,-251L-604,-251L-248,105L-248,251L-436,251L-436,376L65,376L65,251L-123,251L-123,105L108,-125L253,-125L253,-251L-123,-251L-123,-105L-185,-43L-393,-251L-311,-251L-311,-376L-663,-376C-553,-454,-408,-502,-248,-502C103,-502,379,-272,379,0C379,272,103,502,-248,502ZM942,-627L692,-627C657,-627,630,-599,631,-564L660,251L848,251L994,-565C1000,-599,977,-627,942,-627Z",
  "M-432,-101L435,-101C436,-101,438,-101,439,-102C450,-103,457,-114,455,-125L354,-754C352,-764,343,-771,334,-771L-330,-771C-340,-771,-348,-764,-350,-754L-452,-125C-452,-124,-452,-123,-452,-122C-452,-111,-443,-101,-432,-101ZM-201,-599L204,-599L256,-274L-253,-274L-201,-599ZM-194,118C-196,109,-204,101,-214,101L-878,101C-888,101,-896,109,-898,118L-1000,747C-1000,748,-1000,750,-1000,751C-1000,762,-991,771,-980,771L-112,771C-111,771,-110,771,-109,771C-98,769,-91,759,-92,747L-194,118ZM-801,599L-748,274L-344,274L-291,599L-801,599ZM998,747L896,118C895,109,886,101,876,101L213,101C203,101,194,109,193,118L91,747C91,748,91,750,91,751C91,762,100,771,111,771L978,771C979,771,980,771,981,771C992,769,1000,759,998,747ZM290,599L342,274L747,274L799,599L290,599Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM840,840L380,840L380,226L640,226L679,-76L380,-76L380,-269C380,-356,404,-416,529,-416L689,-416L689,-686C661,-690,566,-698,456,-698C225,-698,68,-557,68,-299L68,-76L-193,-76L-193,225L68,225L68,840L-840,840L-840,-840L840,-840L840,840Z",
  "M973,754L61,-825C47,-848,24,-860,0,-860C-24,-860,-47,-848,-61,-825L-973,754C-1000,801,-966,860,-912,860L912,860C966,860,1000,801,973,754ZM-760,702L0,-614L760,702L-760,702ZM-61,-338L-561,526C-588,573,-554,632,-500,632L500,632C554,632,588,573,560,526L61,-338C47,-361,23,-373,0,-373C-24,-373,-47,-361,-61,-338ZM409,509L-409,509L0,-197L409,509ZM-61,83L-186,299C-213,345,-179,404,-125,404L125,404C179,404,213,345,186,299L61,83C47,60,24,48,0,48C-24,48,-47,60,-61,83ZM64,299L-64,299L0,188L64,299Z",
  "M929,167C940,110,945,53,945,-5C945,-132,920,-256,871,-372C823,-485,755,-586,668,-672C582,-759,480,-827,368,-875C252,-924,128,-949,0,-949C-60,-949,-120,-943,-178,-932C-259,-975,-350,-997,-441,-997C-590,-997,-731,-939,-836,-834C-942,-728,-1000,-588,-1000,-438C-1000,-343,-976,-250,-930,-167C-939,-114,-944,-59,-944,-5C-944,123,-919,247,-870,363C-822,475,-754,576,-668,663C-581,750,-480,818,-367,865C-251,915,-127,940,0,940C56,940,111,935,166,925C250,972,344,997,441,997C590,997,730,939,836,834C942,728,1000,588,1000,438C1000,343,976,250,929,167ZM709,707C637,779,542,818,441,818C376,818,312,801,254,768L198,737L134,748C90,756,45,760,0,760C-103,760,-203,740,-297,700C-388,661,-470,606,-540,536C-610,466,-666,384,-704,293C-744,199,-764,99,-764,-4C-764,-48,-760,-92,-752,-136L-742,-199L-772,-255C-804,-311,-820,-374,-820,-438C-820,-540,-781,-635,-709,-706C-637,-778,-542,-817,-441,-817C-379,-817,-318,-802,-262,-773L-206,-743L-144,-755C-97,-764,-48,-769,0,-769C104,-769,204,-749,298,-709C389,-670,471,-615,541,-545C612,-475,666,-393,705,-302C745,-208,765,-108,765,-5C765,41,761,88,752,134L740,198L772,254C804,311,820,374,820,439C820,540,781,635,709,707ZM178,-114L-42,-163C-126,-183,-223,-208,-223,-287C-223,-366,-156,-422,-33,-422C214,-422,191,-252,314,-252C378,-252,435,-290,435,-355C435,-507,191,-622,-15,-622C-240,-622,-478,-526,-478,-273C-478,-151,-435,-21,-194,39L104,114C194,136,217,187,217,233C217,309,142,384,4,384C-264,384,-226,177,-370,177C-434,177,-481,222,-481,285C-481,409,-331,574,4,574C324,574,482,420,482,214C482,81,420,-60,178,-114Z",
  "M470,242C344,133,181,67,2,67C-177,67,-341,133,-466,242C-473,248,-474,259,-468,267L-388,362C-381,370,-370,371,-362,364C-265,279,-138,227,2,227C141,227,269,279,366,364C374,371,385,370,391,362L472,267C478,259,477,248,470,242ZM731,-70C534,-235,279,-334,2,-334C-276,-334,-530,-235,-728,-70C-735,-64,-736,-53,-730,-45L-650,50C-644,58,-632,59,-625,53C-455,-89,-236,-174,2,-174C240,-174,458,-89,628,53C636,59,647,58,653,50L733,-45C740,-53,739,-64,731,-70ZM991,-380C721,-602,374,-735,-3,-735C-377,-735,-721,-604,-991,-384C-999,-378,-1000,-367,-994,-359L-913,-264C-907,-256,-896,-255,-889,-261C-646,-457,-338,-575,-3,-575C335,-575,646,-456,888,-257C896,-251,907,-252,913,-259L994,-355C1000,-362,999,-374,991,-380ZM0,593ZM-143,593L-141,617L-134,641L-124,664L-110,684L-92,702L-72,716L-49,727L-25,733L0,735L24,733L48,727L71,716L91,702L109,684L123,664L134,641L140,617L142,593L140,568L134,544L123,521L109,501L91,483L71,469L48,459L24,452L0,450L-25,452L-49,459L-72,469L-92,483L-110,501L-124,521L-134,544L-141,568L-143,593Z",
  "M475,-726L476,-726L476,-726L0,-1000L-476,-726L-477,-726L-475,-726L-867,-500L-867,500L0,1000L867,500L867,-500L475,-726ZM-70,797L-414,599L-414,263L-726,86L-726,-334L-70,44L-70,797ZM-658,-458L-334,-645L0,-453L334,-645L659,-458L0,-78L-658,-458ZM726,87L416,263L416,597L70,797L70,44L726,-334L726,87Z",
  "M672,-763C435,-1000,49,-1000,-187,-763L-843,-108C-848,-103,-850,-98,-850,-92C-850,-85,-848,-80,-843,-75L-751,17C-742,26,-727,26,-719,17L-62,-638C19,-720,127,-764,242,-764C358,-764,466,-720,547,-638C629,-557,673,-448,673,-334C673,-218,629,-110,547,-29L-122,640L-230,748C-331,849,-496,849,-597,748C-646,699,-673,634,-673,564C-673,495,-646,430,-597,381L66,-282C83,-299,105,-308,129,-308L129,-308C153,-308,175,-299,191,-282C208,-265,217,-243,217,-220C217,-196,208,-174,191,-158L-351,384C-355,388,-358,394,-358,400C-358,406,-355,412,-351,416L-258,509C-249,518,-235,518,-226,509L316,-33C366,-83,393,-149,393,-220C393,-291,365,-357,316,-407C212,-510,44,-510,-59,-407L-123,-342L-722,256C-805,339,-850,448,-850,565C-850,681,-804,790,-722,873C-637,958,-525,1000,-414,1000C-302,1000,-190,958,-105,873L672,96C786,-19,850,-171,850,-334C850,-496,786,-649,672,-763Z",
  "M1000,0L1000,0C1000,-553,552,-1000,0,-1000C-552,-1000,-1000,-553,-1000,0L-1000,0C-1000,553,-552,1000,0,1000C552,1000,1000,553,1000,0L1000,0L1000,0ZM983,-179L985,-171C986,-165,987,-160,988,-154C987,-160,986,-166,985,-171L983,-179C983,-181,982,-184,982,-186C982,-184,983,-181,983,-179ZM396,303C524,105,522,-152,369,-331L759,-351C809,-244,836,-126,836,0C836,444,489,808,50,834L396,303ZM0,337C-186,337,-337,186,-337,0C-337,-187,-186,-337,0,-337C186,-337,337,-187,337,0C337,186,186,337,0,337ZM887,-460L880,-474L887,-460ZM0,-837C291,-837,548,-687,698,-461L64,-495C-170,-508,-393,-377,-470,-156L-683,-483C-531,-697,-282,-837,0,-837ZM-984,177C-921,525,-679,811,-355,934C-679,812,-921,526,-984,177ZM-836,0C-836,-135,-804,-262,-748,-374L-461,191C-355,400,-130,527,102,484L-76,832C-502,794,-836,436,-836,0ZM-56,998C-46,998,-37,999,-27,999C-37,998,-46,998,-56,998Z",
  "M-636,600C-631,600,-626,600,-621,599L-200,525C-195,524,-190,522,-187,518L873,-542C882,-552,882,-567,873,-577L457,-993C452,-998,446,-1000,440,-1000C433,-1000,426,-998,422,-993L-638,67C-642,71,-644,75,-645,80L-719,501C-724,528,-715,556,-695,575C-679,591,-658,600,-636,600ZM-467,164L440,-742L623,-559L-284,347L-506,386L-467,164ZM920,810L-920,810C-964,810,-1000,846,-1000,890L-1000,980C-1000,991,-991,1000,-980,1000L980,1000C991,1000,1000,991,1000,980L1000,890C1000,846,964,810,920,810Z",
  "M911,-343C863,-458,793,-562,704,-651C615,-740,511,-809,396,-858C277,-909,151,-934,20,-934C-87,-934,-192,-917,-291,-883C-523,-992,-792,-1000,-869,-1000C-874,-1000,-888,-1000,-893,-999C-923,-998,-951,-983,-967,-958C-984,-932,-987,-901,-976,-872L-812,-460C-900,-311,-947,-141,-947,33C-947,164,-921,291,-871,409C-822,524,-753,628,-664,717C-575,806,-471,875,-356,924C-237,974,-110,1000,20,1000C151,1000,277,974,397,924C511,876,615,806,704,717C792,628,862,524,911,409C961,290,987,163,987,33C986,-98,961,-224,911,-343ZM741,336C702,430,645,514,573,586C501,659,417,716,324,755L324,755C227,795,124,816,18,816C-88,816,-191,795,-287,755C-381,715,-465,658,-537,586C-609,514,-666,430,-705,337L-705,336C-746,240,-766,137,-766,31C-766,-111,-729,-249,-657,-370L-623,-426L-648,-487L-779,-816C-741,-815,-687,-811,-626,-802C-515,-785,-416,-757,-333,-719L-285,-696L-234,-714C-154,-741,-69,-755,18,-755C124,-755,227,-734,324,-693C417,-654,501,-597,573,-525C646,-452,702,-368,741,-275L741,-275L742,-275C782,-179,803,-76,803,31C803,137,782,240,741,336ZM433,-377C381,-377,339,-334,339,-282L339,-142C339,-90,381,-47,433,-47C486,-47,528,-90,528,-142L528,-282C528,-335,485,-377,433,-377ZM-14,-377C-66,-377,-108,-334,-108,-282L-108,-142C-108,-90,-66,-47,-14,-47C39,-47,81,-90,81,-142L81,-282C81,-335,39,-377,-14,-377Z",
  "M241,-1000C-178,-1000,-518,-660,-518,-241C-518,-65,-459,96,-359,225L-461,328L-617,172C-625,164,-637,164,-645,172L-745,271C-753,279,-753,292,-745,300L-589,455L-701,567L-857,412C-865,404,-877,404,-885,412L-985,511C-993,519,-993,532,-985,540L-829,695L-992,858C-1000,866,-1000,879,-992,887L-887,992C-879,1000,-866,1000,-858,992L-225,359C-96,459,65,518,241,518C660,518,1000,178,1000,-241C1000,-660,660,-1000,241,-1000ZM643,162C536,269,393,329,241,329C89,329,-54,269,-162,162C-269,54,-329,-89,-329,-241C-329,-393,-269,-536,-162,-643C-54,-751,89,-810,241,-810C393,-810,536,-751,643,-643C751,-536,810,-393,810,-241C810,-89,751,54,643,162Z",
  "M563,54C562,-110,636,-233,785,-324C702,-444,575,-510,409,-522C251,-535,78,-430,15,-430C-52,-430,-205,-518,-325,-518C-574,-514,-837,-320,-837,75C-837,192,-816,312,-773,436C-716,600,-511,1000,-296,994C-184,991,-105,914,41,914C183,914,256,994,381,994C597,990,783,626,837,463C547,326,563,62,563,54ZM537,693C503,741,469,779,437,803C412,822,392,830,380,831C358,830,337,825,296,810C294,808,290,807,286,806C284,805,277,802,276,802C234,786,209,777,177,769C133,757,88,751,41,751C-7,751,-53,757,-98,768C-132,776,-160,786,-201,801C-202,802,-220,809,-225,810C-233,814,-240,816,-246,818C-271,827,-287,830,-301,831C-302,831,-304,830,-305,830C-308,830,-311,829,-315,827C-326,823,-339,815,-353,804C-387,777,-424,736,-461,684C-527,591,-589,469,-619,383C-656,275,-674,173,-674,75C-674,-70,-632,-179,-559,-254C-496,-318,-411,-353,-324,-355C-310,-355,-289,-352,-263,-344C-243,-339,-220,-331,-190,-321C-181,-317,-149,-306,-145,-305C-127,-298,-113,-293,-99,-289C-56,-275,-22,-267,15,-267C52,-267,84,-275,129,-291C146,-297,208,-320,219,-323C280,-345,325,-357,364,-360C376,-361,386,-361,396,-360C450,-356,497,-345,536,-327C446,-223,400,-96,400,53C399,88,402,129,412,177C428,250,457,322,503,390C538,441,582,488,634,528C607,585,573,644,537,693ZM311,-677C432,-821,421,-953,418,-1000C311,-994,186,-927,116,-845C38,-757,-8,-648,2,-525C118,-516,224,-575,311,-677Z",
  "M992,-888L889,-992C885,-996,880,-998,875,-998C870,-998,865,-996,861,-992L675,-806C592,-862,496,-890,400,-890C275,-890,150,-842,54,-747L-195,-497C-203,-490,-203,-477,-195,-470L470,195C474,199,478,201,484,201C488,201,494,199,497,195L747,-54C915,-223,935,-484,806,-674L992,-861C1000,-868,1000,-881,992,-888ZM629,-172L484,-27L27,-484L172,-629C233,-690,314,-724,400,-724C487,-724,568,-690,629,-629C690,-568,724,-487,724,-400C724,-314,690,-233,629,-172ZM164,85C156,77,143,77,136,85L-27,248L-248,27L-85,-136C-77,-144,-77,-156,-85,-164L-174,-253C-181,-260,-194,-260,-201,-253L-365,-90L-470,-195C-474,-199,-479,-200,-484,-200C-489,-200,-494,-199,-498,-195L-747,54C-915,223,-935,484,-806,675L-992,861C-1000,868,-1000,881,-992,888L-889,992C-885,996,-880,998,-875,998C-870,998,-865,996,-861,992L-675,806C-592,862,-496,890,-400,890C-275,890,-150,842,-54,747L195,497C203,490,203,477,195,470L90,364L253,201C261,194,261,181,253,174L164,85ZM-172,629C-233,690,-314,724,-401,724C-487,724,-568,690,-629,629C-690,568,-724,487,-724,401C-724,314,-690,233,-629,172L-484,27L-27,484L-172,629Z",
  "M-142,-640C-184,-640,-214,-610,-214,-569C-214,-528,-184,-498,-142,-498C-101,-498,-71,-528,-71,-569C-71,-610,-101,-640,-142,-640ZM737,-425C706,-456,664,-473,618,-473C609,-473,601,-472,594,-471L594,-473L586,-473C574,-541,545,-608,501,-668C459,-725,405,-775,343,-813L399,-893L399,-900C399,-902,400,-905,401,-909C402,-914,404,-921,404,-929C404,-970,374,-1000,332,-1000C310,-1000,289,-987,275,-965L209,-871C142,-893,70,-905,0,-905C-70,-905,-142,-893,-210,-871L-275,-966C-289,-987,-311,-1000,-333,-1000C-374,-1000,-404,-970,-404,-929C-404,-915,-399,-900,-389,-890L-339,-818C-403,-780,-458,-730,-500,-673C-543,-613,-571,-546,-582,-478L-594,-478L-594,-475C-601,-477,-609,-478,-618,-478C-663,-478,-706,-461,-737,-430C-767,-399,-785,-357,-785,-312L-785,213C-785,258,-768,300,-737,331C-706,362,-664,379,-618,379C-609,379,-601,378,-594,377L-594,585C-594,650,-541,704,-475,704L-404,704L-404,834C-404,879,-387,921,-356,952C-326,983,-283,1000,-238,1000C-192,1000,-150,983,-119,952C-88,922,-71,880,-71,834L-71,704L71,704L71,834C71,879,88,921,119,952C150,983,192,1000,238,1000C283,1000,325,983,356,952C387,921,404,879,404,834L404,704L475,704C541,704,594,650,594,585L594,381C601,382,609,383,618,383C663,383,706,367,737,336C767,305,785,263,785,217L785,-307C784,-352,768,-394,737,-425ZM-594,218C-594,233,-603,241,-618,241C-633,241,-642,233,-642,218L-642,-307C-642,-322,-633,-331,-618,-331C-603,-331,-594,-322,-594,-307L-594,218ZM-301,-668C-218,-729,-111,-762,0,-762C111,-762,218,-729,301,-667C374,-615,422,-546,441,-472L-441,-472C-422,-547,-373,-615,-301,-668ZM-214,838C-215,850,-223,857,-237,857C-252,857,-261,849,-261,834L-261,704L-214,704L-214,838ZM238,857C223,857,214,849,214,834L214,704L261,704L261,838C260,850,252,857,238,857ZM452,561L-451,561L-451,-330L452,-330L452,561ZM642,218C642,233,633,241,618,241C603,241,594,233,594,218L594,-307C594,-322,603,-331,618,-331C633,-331,642,-322,642,-307L642,218ZM143,-640C101,-640,71,-610,71,-569C71,-528,102,-498,143,-498C184,-498,214,-528,214,-569C214,-611,185,-640,143,-640Z",
  "M791,-791C583,-1000,245,-1000,36,-791L-203,-552L-77,-426L162,-665C295,-798,519,-812,666,-665C812,-518,798,-295,666,-162L426,77L553,204L792,-36C1000,-244,1000,-582,791,-791ZM-162,666C-294,798,-518,812,-665,666C-812,519,-798,295,-665,162L-426,-77L-552,-203L-791,36C-1000,245,-1000,583,-791,791C-582,1000,-244,1000,-36,791L203,552L77,426L-162,666ZM-621,-747C-629,-754,-641,-754,-649,-747L-747,-649C-754,-641,-754,-629,-747,-621L622,747C629,755,642,755,650,747L747,650C755,642,755,629,747,622L-621,-747Z",
  "M995,-257L507,-868C504,-871,499,-874,495,-874L-495,-874C-499,-874,-504,-871,-507,-868L-995,-257C-1000,-252,-1000,-243,-995,-237L-12,869C-9,872,-4,874,0,874C4,874,8,872,12,869L995,-237C1000,-243,1000,-252,995,-257ZM321,-735L403,-413L84,-735L321,-735ZM340,-306L-340,-306L0,-650L340,-306ZM-321,-735L-84,-735L-404,-413L-321,-735ZM-449,-719L-555,-306L-779,-306L-449,-719ZM-764,-186L-537,-186L-234,411L-764,-186ZM0,605L-402,-186L401,-186L0,605ZM234,411L537,-186L764,-186L234,411ZM555,-306L449,-719L779,-306L555,-306Z",
  "M993,-9L203,-788C196,-795,185,-795,178,-788L-355,-264C-362,-257,-362,-245,-355,-238L-355,-238L-266,-150L-527,107C-534,114,-534,125,-527,132L-527,132L-439,219L-861,636L-982,636C-992,636,-1000,644,-1000,654L-1000,777C-1000,787,-992,795,-982,795L-213,795C-208,795,-204,793,-200,790L-31,621L59,710C66,717,78,717,84,710L346,452L435,540C442,547,453,547,460,540L992,16C1000,9,1000,-2,993,-9ZM-273,635L-631,635L-331,338L-152,514L-273,635ZM72,496L-310,120L-157,-31L225,346L72,496ZM448,327L-138,-251L190,-574L776,3L448,327Z",
  "M989,94L721,-819L721,-820C702,-876,658,-910,602,-910C544,-910,497,-876,480,-823L304,-298L-304,-298L-480,-823C-497,-876,-544,-910,-602,-910C-659,-910,-707,-873,-721,-819L-989,94C-1000,130,-986,171,-956,194L-49,875C-42,883,-33,890,-23,894L-2,910L19,894C31,890,41,882,49,872L956,194C986,171,1000,130,989,94ZM590,-790C592,-794,597,-795,598,-795C601,-795,605,-794,607,-787L753,-295L424,-295L590,-790ZM-610,-787C-608,-794,-605,-795,-602,-795C-595,-795,-595,-794,-594,-790L-428,-295L-753,-295L-610,-787ZM-870,110L-801,-130L-302,535L-870,110ZM-688,-177L-388,-177L-164,523L-688,-177ZM2,645L-262,-177L265,-177L2,645ZM391,-177L685,-177L167,515L391,-177ZM290,547L801,-135L873,110L290,547Z",
  "M453,-249L453,-250L367,-360C360,-369,347,-370,339,-364L213,-265L37,-491C30,-499,17,-501,9,-494L-86,-420C-95,-413,-96,-401,-89,-392L87,-167L86,-166L173,-56C179,-47,192,-45,201,-52L326,-150L487,54C493,63,506,65,514,58L609,-16C618,-23,619,-35,613,-44L453,-249ZM241,-1000C-179,-1000,-518,-660,-518,-241C-518,-65,-459,96,-359,225L-992,858C-1000,866,-1000,879,-992,887L-887,992C-879,1000,-866,1000,-858,992L-225,359C-96,459,65,518,241,518C660,518,1000,179,1000,-241C1000,-660,660,-1000,241,-1000ZM643,162C536,269,393,329,241,329C89,329,-54,269,-162,162C-269,54,-329,-89,-329,-241C-329,-393,-269,-536,-162,-643C-54,-751,89,-810,241,-810C393,-810,536,-751,643,-643C751,-536,810,-393,810,-241C810,-89,751,54,643,162Z",
  "M0,-1000C-551,-1000,-1000,-551,-1000,0C-1000,551,-551,1000,0,1000C551,1000,1000,551,1000,0C1000,-551,551,-1000,0,-1000ZM661,-539C780,-394,852,-208,854,-7C826,-13,544,-70,259,-34C253,-49,247,-63,241,-78C223,-120,204,-161,184,-202C500,-331,643,-514,661,-539ZM0,-853C217,-853,415,-771,566,-638C551,-616,422,-443,119,-329C-21,-586,-176,-797,-200,-829C-135,-845,-68,-853,0,-853ZM-363,-772C-341,-741,-188,-529,-47,-278C-446,-172,-798,-173,-836,-174C-781,-439,-602,-659,-363,-772ZM-854,1C-854,-7,-854,-16,-854,-25C-816,-24,-402,-19,24,-147C49,-99,72,-50,94,-2C82,1,71,5,60,8C-381,151,-615,539,-635,572C-771,421,-854,221,-854,1ZM0,855C-198,855,-380,788,-524,675C-509,644,-336,310,146,142L151,140C271,451,321,713,333,788C231,831,118,856,0,855ZM477,709C469,657,423,407,311,100C579,58,814,128,843,137C805,375,669,580,477,709Z",
  "M153,379C146,371,133,371,125,379L-162,666C-294,798,-518,812,-665,666C-812,519,-798,295,-665,162L-378,-125C-371,-132,-371,-145,-378,-153L-476,-251C-484,-259,-497,-259,-504,-251L-791,36C-1000,245,-1000,583,-791,791C-582,1000,-244,1000,-36,791L251,504C259,497,259,484,251,476L153,379ZM791,-791C583,-1000,245,-1000,36,-791L-251,-504C-259,-497,-259,-484,-251,-476L-153,-379C-145,-371,-133,-371,-125,-379L162,-665C295,-798,519,-812,665,-665C812,-518,798,-295,665,-162L379,125C371,133,371,145,379,153L477,251C484,259,497,259,505,251L791,-36C1000,-244,1000,-582,791,-791ZM242,-345C235,-352,222,-352,214,-345L-345,214C-352,222,-352,234,-345,242L-247,340C-239,347,-227,347,-219,340L340,-219C347,-227,347,-239,340,-247L242,-345Z",
  "M0,-512C-284,-512,-513,-284,-513,0C-513,284,-284,512,0,512C283,512,512,284,512,0C512,-284,283,-512,0,-512ZM0,333C-184,333,-333,183,-333,0C-333,-183,-184,-333,0,-333C183,-333,333,-183,333,0C333,183,183,333,0,333ZM533,-653C467,-653,413,-599,413,-533C413,-467,467,-413,533,-413C599,-413,653,-467,653,-533C652,-600,599,-653,533,-653ZM999,0C999,-138,1000,-275,992,-412C984,-572,948,-714,831,-831C714,-948,572,-984,412,-992C274,-1000,138,-999,0,-999C-138,-999,-275,-1000,-412,-992C-572,-984,-714,-948,-831,-831C-948,-714,-985,-572,-992,-412C-1000,-274,-999,-138,-999,0C-999,138,-1000,275,-992,412C-985,572,-948,714,-831,831C-714,948,-572,984,-412,992C-274,1000,-138,999,0,999C138,999,274,1000,412,992C572,984,714,948,831,831C948,714,984,572,992,412C1000,275,999,138,999,0ZM779,589C760,635,738,669,703,704C668,739,634,761,589,779C457,831,145,819,0,819C-146,819,-458,831,-590,779C-635,761,-669,739,-704,704C-739,669,-761,635,-780,589C-832,458,-820,146,-820,0C-820,-146,-832,-458,-780,-589C-761,-635,-739,-669,-704,-704C-669,-739,-635,-761,-590,-779C-458,-831,-146,-819,0,-819C145,-819,458,-831,589,-779C634,-761,668,-739,703,-704C739,-669,761,-635,779,-589C831,-458,819,-146,819,0C819,146,831,458,779,589Z",
  "M923,-1000L281,-1000C272,-1000,265,-993,265,-985L265,-842C265,-833,272,-827,281,-827L690,-827L181,-318C54,-416,-102,-469,-265,-469C-461,-469,-646,-393,-785,-254C-923,-115,-1000,69,-1000,265C-1000,461,-923,646,-785,785C-646,923,-461,1000,-265,1000C-69,1000,116,923,254,785C393,646,469,461,469,265C469,102,416,-53,318,-181L827,-689L827,-281C827,-272,833,-265,842,-265L985,-265C993,-265,1000,-272,1000,-281L1000,-923C1000,-966,966,-1000,923,-1000ZM-265,806C-564,806,-806,564,-806,265C-806,-33,-564,-276,-265,-276C33,-276,276,-33,276,265C276,564,33,806,-265,806Z",
  "M-375,127ZM-500,127L-498,147L-493,167L-485,186L-474,204L-460,219L-443,231L-425,241L-406,248L-385,251L-365,251L-344,248L-325,241L-307,231L-290,219L-276,204L-265,186L-257,167L-252,147L-250,127L-252,106L-257,86L-265,67L-276,50L-290,35L-307,22L-325,12L-344,6L-365,2L-385,2L-406,6L-425,12L-443,22L-460,35L-474,50L-485,67L-493,86L-498,106L-500,127ZM256,394C204,435,102,478,0,478C-102,478,-204,435,-256,394C-288,369,-335,374,-360,406C-386,438,-380,485,-348,510C-258,581,-122,627,0,627C122,627,258,581,348,510C380,485,386,438,360,406C335,374,288,369,256,394ZM1000,-123C1000,-261,888,-373,750,-373C656,-373,574,-321,531,-245C403,-315,246,-360,76,-371L225,-706L511,-623C536,-551,606,-498,688,-498C791,-498,875,-582,875,-686C875,-789,791,-873,688,-873C616,-873,554,-833,522,-775L204,-867C169,-877,131,-859,116,-825L-87,-370C-253,-359,-406,-314,-531,-245C-574,-321,-656,-373,-750,-373C-888,-373,-1000,-261,-1000,-123C-1000,-21,-939,67,-851,106C-867,152,-875,202,-875,252C-875,597,-483,877,0,877C483,877,875,597,875,252C875,201,867,152,851,106C939,67,1000,-21,1000,-123ZM688,-756C726,-756,758,-725,758,-686C758,-647,726,-615,688,-615C649,-615,617,-647,617,-686C617,-725,649,-756,688,-756ZM-875,-123C-875,-192,-819,-248,-750,-248C-700,-248,-657,-219,-637,-177C-702,-127,-756,-70,-797,-7C-842,-26,-875,-71,-875,-123ZM0,728C-401,728,-727,515,-727,252C-727,-11,-401,-225,0,-225C401,-225,727,-11,727,252C727,515,401,728,0,728ZM796,-7C756,-70,702,-127,637,-177C657,-219,700,-248,750,-248C819,-248,875,-192,875,-123C875,-71,842,-26,796,-7ZM375,127ZM250,127L252,147L257,167L265,186L276,204L290,219L307,231L325,241L344,248L365,251L385,251L406,248L425,241L443,231L460,219L474,204L485,186L493,167L498,147L500,127L498,106L493,86L485,67L474,50L460,35L443,22L425,12L406,6L385,2L365,2L344,6L325,12L307,22L290,35L276,50L265,67L257,86L252,106L250,127Z",
  "M976,-856L856,-976C847,-985,833,-985,824,-976L-976,824C-985,832,-985,847,-976,856L-856,976C-847,985,-833,985,-824,976L976,-824C985,-832,985,-847,976,-856ZM-591,-182C-365,-182,-182,-365,-182,-591C-182,-816,-365,-1000,-591,-1000C-816,-1000,-1000,-816,-1000,-591C-1000,-365,-816,-182,-591,-182ZM-591,-795C-478,-795,-386,-704,-386,-591C-386,-478,-478,-386,-591,-386C-704,-386,-795,-478,-795,-591C-795,-704,-704,-795,-591,-795ZM591,182C365,182,182,365,182,591C182,816,365,1000,591,1000C816,1000,1000,816,1000,591C1000,365,816,182,591,182ZM591,795C478,795,386,704,386,591C386,478,478,386,591,386C704,386,795,478,795,591C795,704,704,795,591,795Z",
  "M-1000,658L-178,792L-178,81L-1000,81L-1000,658ZM-839,242L-339,242L-339,603L-839,521L-839,242ZM28,819L1000,977L1000,81L28,81L28,819ZM189,242L839,242L839,788L189,682L189,242ZM28,-816L28,-81L1000,-81L1000,-977L28,-816ZM839,-242L189,-242L189,-680L839,-787L839,-242ZM-1000,-81L-178,-81L-178,-789L-1000,-653L-1000,-81ZM-839,-517L-339,-599L-339,-242L-839,-242L-839,-517Z",
  "M966,-317L314,-969C297,-986,274,-995,252,-995C229,-995,207,-986,190,-969L-237,-542C-269,-546,-301,-548,-334,-548C-528,-548,-721,-484,-880,-356C-921,-324,-924,-263,-887,-226L-407,255L-976,824C-983,831,-988,840,-989,850L-998,949C-1000,973,-980,995,-956,995C-954,995,-953,995,-952,994L-853,985C-843,985,-834,980,-827,973L-257,403L223,884C240,901,263,910,285,910C311,910,337,899,354,877C503,691,565,458,540,233L966,-193C1000,-227,1000,-283,966,-317ZM405,99L340,164L350,255C360,344,353,432,328,518C314,569,294,617,270,662L-665,-273C-630,-292,-595,-308,-558,-320C-486,-345,-411,-358,-334,-358C-308,-358,-283,-356,-257,-353L-166,-343L-102,-408L252,-762L759,-255L405,99Z",
  "M824,-384C800,-479,847,-630,1000,-683L837,-692C837,-692,775,-908,492,-928C208,-947,23,-935,23,-935C23,-935,233,-801,149,-563C87,-437,-9,-333,-113,-215C-116,-212,-119,-209,-121,-206C-463,179,-1000,792,-1000,792C-409,947,-13,777,222,573C271,573,308,572,333,572C659,572,935,290,924,-25C916,-241,847,-290,824,-384ZM333,419C307,419,270,419,220,419L164,420L121,457C8,556,-130,629,-291,668C-417,698,-556,707,-706,691C-663,641,-619,591,-573,539C-352,288,-155,64,-4,-106L0,-110L3,-113C13,-124,52,-169,62,-181C86,-208,104,-229,121,-250C195,-338,247,-413,287,-495L291,-503L294,-511C327,-605,331,-696,309,-783C363,-781,420,-778,481,-774C561,-768,614,-743,652,-704C666,-689,676,-674,684,-659C687,-654,688,-650,690,-647L702,-604C664,-521,654,-428,674,-347C681,-318,691,-293,704,-264C709,-253,727,-216,730,-208C755,-153,767,-104,770,-19C778,209,572,419,333,419Z",
  "M902,-679L637,-944C605,-976,561,-994,516,-994C470,-994,427,-976,394,-944L109,-659C77,-627,59,-583,59,-538C59,-492,77,-449,109,-416L332,-193C281,-74,209,32,117,123C26,215,-81,287,-199,338L-422,115C-454,83,-497,65,-543,65C-589,65,-632,83,-664,115L-950,400C-982,432,-1000,476,-1000,522C-1000,568,-982,611,-950,643L-685,908C-630,963,-554,994,-476,994C-460,994,-444,993,-428,990C-99,936,228,761,491,497C755,234,930,-93,984,-422C1000,-516,969,-612,902,-679ZM808,-452C760,-159,602,133,365,371C127,608,-165,766,-458,814C-494,820,-532,808,-559,781L-819,522L-543,246L-246,544L-243,546L-190,527C140,405,399,146,520,-184L540,-237L240,-537L515,-813L775,-553C802,-527,814,-489,808,-452Z",
  "M1000,-6C1000,-11,1000,-17,1000,-23C1000,-41,999,-62,999,-83C997,-146,994,-208,989,-266C982,-347,972,-414,959,-464C930,-571,846,-655,740,-684C676,-701,553,-712,379,-718C296,-721,207,-723,119,-724C87,-725,59,-725,33,-725L-33,-725C-59,-725,-88,-725,-119,-724C-207,-723,-296,-721,-379,-718C-553,-711,-677,-701,-740,-684C-846,-656,-930,-571,-959,-464C-973,-414,-982,-347,-989,-266C-994,-208,-997,-146,-999,-83C-999,-62,-1000,-41,-1000,-23C-1000,-17,-1000,-11,-1000,-6L-1000,6C-1000,11,-1000,17,-1000,23C-1000,41,-999,62,-999,83C-997,146,-994,208,-989,266C-982,347,-972,414,-959,464C-930,571,-846,656,-740,684C-677,701,-553,712,-379,718C-296,721,-207,723,-119,724C-87,725,-59,725,-33,725L33,725C59,725,88,725,119,724C207,723,296,721,379,718C553,711,677,701,740,684C846,656,930,571,959,464C973,414,982,347,989,266C994,208,997,146,999,83C999,62,1000,41,1000,23C1000,17,1000,11,1000,6L1000,0L1000,-6ZM839,5C839,10,839,15,839,21C839,39,838,58,838,79C836,138,833,197,829,252C823,324,814,383,804,423C790,474,749,515,698,529C651,541,533,551,372,557C291,560,204,563,116,564C86,564,57,564,32,564L-32,564C-57,564,-86,564,-116,564C-204,562,-291,560,-372,557C-533,551,-651,541,-698,529C-749,515,-790,474,-804,423C-814,383,-823,324,-829,252C-833,197,-836,138,-838,79C-839,58,-839,38,-839,21C-839,15,-839,10,-839,5L-839,-1L-839,-5C-839,-10,-839,-15,-839,-21C-839,-39,-838,-58,-838,-79C-836,-138,-833,-197,-829,-252C-823,-324,-814,-383,-804,-423C-790,-474,-749,-515,-698,-529C-651,-541,-533,-551,-372,-557C-291,-560,-204,-563,-116,-564C-86,-564,-57,-564,-32,-564L32,-564C57,-564,86,-564,116,-564C204,-562,291,-560,372,-557C533,-551,651,-541,698,-529C749,-515,790,-474,804,-423C814,-383,823,-324,829,-252C833,-197,836,-138,838,-79C839,-58,839,-38,839,-21C839,-15,839,-10,839,-5L839,5ZM-199,299L319,-2L-199,-299Z",
  "M-308,339ZM-414,339L-412,357L-407,375L-400,392L-389,407L-376,420L-361,430L-344,438L-326,443L-308,445L-290,443L-272,438L-255,430L-240,420L-227,407L-217,392L-209,375L-204,357L-202,339L-204,321L-209,303L-217,286L-227,271L-240,258L-255,247L-272,240L-290,235L-308,233L-326,235L-344,240L-361,247L-376,258L-389,271L-400,286L-407,303L-412,321L-414,339ZM943,-342L342,-944C315,-971,279,-986,240,-986C201,-986,165,-971,138,-944L-943,138C-1000,194,-1000,286,-943,342L-342,944C-315,971,-279,986,-240,986C-201,986,-165,971,-138,944L944,-138C1000,-194,1000,-286,943,-342ZM-240,810L-810,240L240,-810L810,-240L-240,810ZM-790,-304C-784,-298,-773,-298,-766,-304L-304,-766C-298,-773,-298,-784,-304,-790L-389,-875C-396,-882,-407,-882,-414,-875L-875,-414C-882,-407,-882,-396,-875,-389L-790,-304ZM791,304C784,298,773,298,766,304L304,766C298,773,298,784,304,791L389,875C396,882,407,882,414,875L875,414C882,407,882,396,875,389L791,304Z",
  "M990,98L719,-823C702,-874,662,-908,607,-908C553,-908,509,-877,492,-827L313,-291L-313,-291L-493,-826C-509,-877,-553,-908,-608,-908C-662,-908,-706,-874,-719,-823L-990,98C-1000,132,-986,169,-959,190L-1,908L959,190C986,170,1000,132,990,98Z",
  "M1000,-125L930,-857C927,-895,896,-925,858,-929L126,-999L125,-999C117,-999,111,-996,107,-992L-991,106C-1000,115,-1000,130,-991,139L-138,992C-134,996,-128,999,-121,999C-115,999,-109,996,-105,992L993,-106C998,-111,1000,-118,1000,-125ZM-122,756L-756,123L181,-814L760,-759L815,-180L-122,756ZM395,-600C281,-600,188,-508,188,-394C188,-280,281,-188,395,-188C508,-188,601,-280,601,-394C601,-508,508,-600,395,-600ZM395,-319C353,-319,320,-352,320,-394C320,-435,353,-469,395,-469C436,-469,470,-435,470,-394C470,-352,436,-319,395,-319Z",
  "M-1000,101L-410,489L1,146L-592,-221ZM1000,-547ZM1000,-547L412,-930L1,-587L593,-221L1,146L412,489L1000,106L593,-221ZM2,219L-410,562L-588,447L-588,576L2,930L591,576L591,447L415,562ZM-410,-930L-1000,-550L-592,-221L1,-587ZM-1000,101Z",
  "M859,-639C858,-641,856,-643,854,-645C842,-657,822,-657,810,-645L391,-226L226,-391L645,-810C647,-812,649,-814,650,-816C659,-831,654,-850,639,-859C400,-1000,87,-968,-118,-762C-281,-599,-335,-368,-280,-160L-993,552C-1000,560,-1000,572,-992,579L-579,992C-572,999,-559,1000,-552,993L160,280C368,336,599,282,762,119C968,-87,1000,-400,859,-639ZM639,-5C497,136,285,163,117,76L95,98L95,97L-572,764L-764,572L-205,12C-205,12,-205,12,-204,12L-76,-116C-163,-285,-135,-497,6,-638C101,-734,230,-778,356,-769L33,-446C2,-415,2,-366,33,-335L336,-32C366,-2,415,-2,446,-32L769,-356C778,-230,734,-101,639,-5Z",
  "M135,-617C-227,-749,-757,-990,-757,-990C-794,-1000,-800,-964,-800,-964C-812,-817,-719,-579,-671,-526C-624,-473,93,-254,93,-254C93,-254,-458,-365,-591,-403C-724,-441,-682,-361,-682,-361C-655,-213,-527,-45,-425,-29C-324,-13,102,-20,102,-20C102,-20,17,-10,-121,9C-224,23,-354,39,-387,51C-467,81,-330,201,-330,201C-127,385,-20,322,-20,322C60,297,127,278,184,264L114,557L316,557L205,1000L696,349L439,349L492,256C493,258,493,258,493,258C493,258,676,-34,746,-183L747,-186L747,-186C759,-211,768,-233,771,-247C812,-418,497,-485,135,-617Z",
  "M992,-887L887,-992C879,-1000,866,-1000,859,-992L628,-762L418,-972C410,-980,398,-980,390,-972L285,-867C277,-859,277,-847,285,-839L495,-628L157,-291C32,-387,-121,-439,-281,-439C-473,-439,-654,-364,-789,-228C-925,-92,-1000,89,-1000,281C-1000,473,-925,653,-789,789C-654,925,-473,1000,-281,1000C-89,1000,92,925,228,789C364,653,439,473,439,281C439,120,386,-32,290,-157L629,-495L839,-285C847,-277,859,-277,867,-285L972,-390C980,-397,980,-410,972,-418L762,-628L992,-859C1000,-866,1000,-879,992,-887ZM-281,810C-573,810,-810,573,-810,281C-810,-11,-573,-249,-281,-249C11,-249,249,-11,249,281C249,573,11,810,-281,810Z",
  "M-539,513C-539,566,-497,608,-444,608L-336,608L-336,877C-336,944,-281,1000,-214,1000C-147,1000,-92,945,-92,877L-92,608L97,608L97,876C97,944,152,1000,219,1000C286,1000,341,944,341,876L341,608L449,608C501,608,544,565,544,513L544,-368L-539,-368L-539,513ZM257,-824L357,-969C363,-978,361,-989,353,-995C346,-1000,334,-997,329,-989L225,-838C156,-865,80,-880,0,-880C-80,-880,-156,-865,-225,-838L-328,-989C-334,-997,-345,-1000,-353,-994C-361,-989,-362,-978,-357,-969L-256,-824C-416,-750,-527,-610,-541,-446L542,-446C527,-610,416,-750,257,-824ZM-229,-596C-262,-596,-289,-623,-289,-656C-289,-689,-262,-716,-229,-716C-196,-716,-169,-689,-169,-656C-169,-623,-196,-596,-229,-596ZM236,-596C203,-596,176,-623,176,-656C176,-689,203,-716,236,-716C269,-716,296,-689,296,-656C296,-623,269,-596,236,-596ZM734,-371C667,-371,612,-316,612,-248L612,235C612,302,667,358,734,358C801,358,856,303,856,235L856,-248C856,-316,801,-371,734,-371ZM-734,-371C-801,-371,-856,-316,-856,-248L-856,235C-856,302,-801,358,-734,358C-667,358,-612,303,-612,235L-612,-248C-612,-316,-667,-371,-734,-371Z",
  "M-68,620L776,-224C779,-228,781,-233,781,-238L724,-910C722,-928,709,-941,691,-943L19,-1000C14,-1000,8,-998,5,-994L-839,-151C-846,-144,-846,-133,-839,-126L-93,620C-86,627,-75,627,-68,620ZM72,-834L573,-791L615,-291L-81,405L-624,-138L72,-834ZM206,-418L219,-407L234,-398L251,-392L268,-388L286,-387L303,-389L320,-394L336,-402L351,-412L363,-425L373,-439L381,-455L386,-472L388,-490L388,-507L384,-525L378,-541L369,-556L357,-570L344,-581L328,-590L312,-597L295,-600L277,-601L259,-599L243,-594L227,-586L212,-576L200,-563L189,-549L182,-533L177,-516L174,-499L175,-481L179,-464L185,-447L194,-432L206,-418ZM839,61L750,-27C743,-34,732,-34,725,-27L-82,779L-612,250C-619,243,-631,243,-637,250L-726,338C-733,345,-733,357,-726,363L-183,905L-95,993C-88,1000,-77,1000,-70,993L839,86C846,79,846,68,839,61Z",
  "M563,54C562,-110,636,-233,785,-324C702,-444,575,-510,409,-522C251,-535,78,-430,15,-430C-52,-430,-205,-518,-325,-518C-574,-514,-837,-320,-837,75C-837,192,-816,312,-773,436C-716,600,-511,1000,-296,994C-184,991,-105,914,41,914C183,914,256,994,381,994C597,990,783,626,837,463C547,326,563,62,563,54ZM311,-677C432,-821,421,-953,418,-1000C311,-994,186,-927,116,-845C38,-757,-8,-648,2,-525C118,-516,224,-575,311,-677Z",
  "M142,0L986,-846C1000,-859,990,-882,972,-882L732,-882C726,-882,721,-880,717,-876L-7,-150L-246,-390C-213,-449,-194,-516,-194,-588C-194,-811,-375,-991,-597,-991C-819,-991,-1000,-811,-1000,-588C-1000,-366,-819,-186,-597,-186C-524,-186,-455,-205,-396,-239L-157,0L-396,239C-455,205,-524,186,-597,186C-820,186,-1000,366,-1000,588C-1000,811,-820,991,-597,991C-375,991,-194,811,-194,588C-194,516,-213,449,-247,390L-8,150L717,876C721,880,726,882,732,882L972,882C990,882,1000,860,986,846L142,0ZM-597,-376C-714,-376,-809,-471,-809,-588C-809,-705,-714,-800,-597,-800C-480,-800,-385,-705,-385,-588C-385,-471,-480,-376,-597,-376ZM-597,800C-714,800,-809,705,-809,588C-809,471,-714,376,-597,376C-480,376,-385,471,-385,588C-385,705,-480,800,-597,800Z",
  "M-882,-1000L-723,795L0,1000L720,795L882,-1000L-882,-1000ZM548,-574L537,-461L533,-414L-312,-414L-292,-188L513,-188L505,-129L454,453L450,492L1,616L1,617L-2,617L-3,617L-3,617L-3,617L-456,492L-484,144L-265,144L-249,320L-3,387L-2,387L243,320L271,35L-3,35L-3,35L-495,35L-550,-574L-554,-633L552,-633L548,-574Z",
  "M668,472L668,-772C668,-793,651,-811,629,-811L218,-811L218,-977C218,-992,201,-1000,190,-991L-119,-747C-128,-740,-128,-726,-119,-720L189,-476C201,-467,218,-475,218,-490L218,-656L494,-656L494,472C387,508,310,610,310,729C310,878,431,1000,581,1000C730,1000,852,878,852,729C852,610,775,508,668,472ZM581,845C517,845,465,793,465,729C465,665,517,612,581,612C645,612,697,665,697,729C697,793,645,845,581,845ZM-310,-724C-310,-873,-431,-995,-581,-995C-730,-995,-852,-873,-852,-724C-852,-605,-775,-503,-668,-467L-668,472C-775,508,-852,610,-852,729C-852,878,-730,1000,-581,1000C-431,1000,-310,878,-310,729C-310,610,-387,509,-494,472L-494,-467C-387,-503,-310,-605,-310,-724ZM-697,-724C-697,-788,-645,-840,-581,-840C-517,-840,-465,-788,-465,-724C-465,-659,-517,-607,-581,-607C-645,-607,-697,-659,-697,-724ZM-465,729C-465,793,-517,845,-581,845C-645,845,-697,793,-697,729C-697,665,-645,612,-581,612C-517,612,-465,665,-465,729Z",
  "M28,-816L28,-81L1000,-81L1000,-977ZM28,819L1000,977L1000,81L28,81ZM-1000,-81L-178,-81L-178,-789L-1000,-653ZM-1000,658L-178,792L-178,81L-1000,81Z",
  "M612,388C540,388,472,413,420,456L-109,73C-104,50,-102,25,-102,0C-102,-25,-104,-49,-109,-73L420,-456C472,-413,540,-388,612,-388C781,-388,918,-525,918,-694C918,-863,781,-1000,612,-1000C443,-1000,306,-863,306,-694C306,-664,310,-636,318,-609L-184,-245C-258,-344,-377,-408,-510,-408C-736,-408,-918,-226,-918,0C-918,226,-736,408,-510,408C-377,408,-258,344,-184,245L318,609C310,636,306,665,306,694C306,863,443,1000,612,1000C781,1000,918,863,918,694C918,525,781,388,612,388ZM612,-827C685,-827,745,-767,745,-694C745,-621,685,-561,612,-561C539,-561,480,-621,480,-694C480,-767,539,-827,612,-827ZM-510,224C-634,224,-735,124,-735,0C-735,-124,-634,-224,-510,-224C-386,-224,-286,-124,-286,0C-286,124,-386,224,-510,224ZM612,827C539,827,480,767,480,694C480,621,539,561,612,561C685,561,745,621,745,694C745,767,685,827,612,827Z",
  "M777,243C737,115,691,8,621,-167C632,-628,441,-1000,0,-1000C-446,-1000,-633,-620,-621,-167C-692,8,-737,115,-777,243C-861,514,-834,626,-813,629C-768,634,-639,425,-639,425C-639,546,-577,704,-441,819C-507,839,-654,893,-619,952C-590,1000,-132,983,0,968C132,983,590,1000,618,952C653,893,506,839,441,819C576,704,639,546,639,425C639,425,768,634,813,629C834,626,861,514,777,243Z",
  "M553,-852C403,-852,282,-730,282,-580C282,-459,362,-355,472,-321L472,-88L-466,219L-466,-471C-359,-507,-282,-609,-282,-728C-282,-878,-403,-1000,-553,-1000C-703,-1000,-825,-878,-825,-728C-825,-609,-748,-507,-641,-471L-641,471C-748,507,-825,609,-825,728C-825,878,-703,1000,-553,1000C-403,1000,-282,878,-282,728C-282,609,-359,507,-466,471L-466,403L562,67C613,50,647,3,647,-50L647,-325C751,-363,825,-463,825,-580C825,-730,703,-852,553,-852ZM-670,-728C-670,-793,-618,-845,-553,-845C-489,-845,-437,-793,-437,-728C-437,-664,-489,-612,-553,-612C-618,-612,-670,-664,-670,-728ZM-437,728C-437,792,-489,844,-553,844C-618,844,-670,792,-670,728C-670,664,-618,611,-553,611C-489,611,-437,664,-437,728ZM553,-464C489,-464,437,-516,437,-580C437,-644,489,-697,553,-697C618,-697,670,-644,670,-580C670,-516,618,-464,553,-464Z",
  "M1000,-619C926,-588,846,-565,764,-556C849,-607,914,-687,944,-782C866,-735,777,-701,684,-683C609,-763,503,-812,385,-812C158,-812,-25,-628,-25,-402C-25,-371,-21,-339,-15,-308C-355,-326,-658,-489,-860,-737C-896,-676,-916,-607,-916,-530C-916,-388,-844,-263,-733,-189C-801,-192,-864,-211,-919,-241L-919,-236C-919,-37,-778,128,-590,166C-624,175,-661,180,-698,180C-725,180,-750,178,-775,174C-723,336,-572,455,-392,458C-533,569,-709,634,-901,634C-935,634,-967,632,-1000,629C-818,745,-603,812,-371,812C383,812,796,188,796,-354C796,-372,796,-390,794,-407C874,-466,944,-538,1000,-619Z",
  "M583,-1000C433,-1000,311,-878,311,-728C311,-612,383,-513,485,-474L485,-407L0,217L-485,-407L-485,-474C-383,-513,-311,-612,-311,-728C-311,-878,-433,-1000,-583,-1000C-733,-1000,-854,-878,-854,-728C-854,-605,-772,-501,-660,-468L-660,-384C-660,-361,-652,-337,-638,-319L-87,389L-87,471C-195,507,-272,609,-272,728C-272,878,-150,1000,0,1000C150,1000,272,878,272,728C272,609,195,507,87,471L87,389L638,-319C652,-337,660,-361,660,-384L660,-468C772,-501,854,-605,854,-728C854,-878,733,-1000,583,-1000ZM-699,-728C-699,-792,-647,-845,-583,-845C-518,-845,-466,-792,-466,-728C-466,-664,-518,-612,-583,-612C-647,-612,-699,-664,-699,-728ZM117,728C117,792,64,845,0,845C-64,845,-117,792,-117,728C-117,664,-64,612,0,612C64,612,117,664,117,728ZM583,-612C518,-612,466,-664,466,-728C466,-792,518,-845,583,-845C647,-845,699,-792,699,-728C699,-664,647,-612,583,-612Z",
  "M929,167C940,110,945,53,945,-5C945,-132,920,-256,871,-372C823,-485,755,-586,668,-672C582,-759,480,-827,368,-875C252,-924,128,-949,0,-949C-60,-949,-120,-943,-178,-932C-259,-975,-350,-997,-441,-997C-590,-997,-731,-939,-836,-834C-942,-728,-1000,-588,-1000,-438C-1000,-343,-976,-250,-930,-167C-939,-114,-944,-59,-944,-5C-944,123,-919,247,-870,363C-822,475,-754,576,-668,663C-581,750,-480,818,-367,865C-251,915,-127,940,0,940C56,940,111,935,166,925C250,972,344,997,441,997C590,997,730,939,836,834C942,728,1000,588,1000,438C1000,343,976,250,929,167ZM4,574C-331,574,-481,409,-481,285C-481,222,-434,178,-370,178C-226,178,-264,384,4,384C142,384,217,309,217,233C217,187,195,136,104,114L-194,40C-434,-21,-478,-151,-478,-273C-478,-526,-240,-621,-15,-621C191,-621,435,-507,435,-355C435,-290,378,-252,314,-252C191,-252,214,-422,-33,-422C-156,-422,-223,-366,-223,-287C-223,-208,-126,-182,-42,-163L178,-114C420,-60,482,81,482,214C482,420,324,574,4,574Z",
  "M992,-871L871,-992C862,-1000,849,-1000,840,-992L418,-569L271,-716C259,-728,237,-721,235,-703L172,-196C170,-182,182,-170,196,-172L703,-235C721,-237,728,-259,716,-271L569,-418L992,-841C1000,-849,1000,-862,992,-871ZM-196,172L-703,235C-721,237,-728,259,-716,271L-569,418L-992,840C-1000,849,-1000,862,-992,871L-871,992C-862,1000,-849,1000,-840,992L-418,569L-271,716C-258,728,-237,721,-235,703L-172,196C-170,182,-182,170,-196,172Z",
  "M-140,84C-295,43,-470,121,-538,257C-606,397,-540,552,-383,602C-221,655,-29,575,37,424C103,277,21,125,-140,84ZM-258,440C-290,490,-357,512,-408,489C-458,466,-473,408,-442,359C-410,310,-345,288,-295,309C-244,331,-227,389,-258,440ZM-154,306C-166,326,-191,335,-211,327C-230,319,-236,297,-225,278C-214,259,-190,250,-170,257C-151,265,-144,287,-154,306ZM608,-143C642,-132,679,-151,690,-185C717,-268,700,-364,637,-433C574,-503,481,-530,396,-512C360,-504,338,-470,346,-435C353,-400,388,-377,423,-385C465,-394,510,-381,541,-347C572,-313,580,-266,567,-225C556,-191,574,-154,608,-143ZM836,-613C707,-756,516,-811,339,-774C299,-765,273,-725,281,-684C290,-643,330,-617,371,-626C497,-653,632,-614,724,-512C816,-410,841,-271,802,-149C789,-109,811,-67,850,-54C890,-41,932,-63,945,-102L945,-102C1000,-274,965,-470,836,-613ZM480,-17C452,-25,433,-31,448,-67C479,-146,482,-215,448,-263C385,-355,209,-350,9,-266C9,-266,-54,-238,-38,-288C-7,-387,-12,-470,-60,-518C-169,-627,-458,-514,-707,-266C-892,-80,-1000,117,-1000,287C-1000,613,-582,811,-173,811C362,811,719,500,719,252C719,103,593,18,480,-17ZM-172,694C-498,726,-780,579,-801,365C-822,151,-575,-49,-249,-81C77,-114,359,34,380,248C401,462,154,662,-172,694Z",
  "M973,-998L436,-931C417,-929,410,-906,423,-893L578,-738L143,-303C134,-294,134,-279,143,-270L270,-143C279,-134,294,-134,303,-143L738,-578L893,-423C907,-410,929,-418,932,-436L998,-973C1000,-988,988,-1000,973,-998ZM-271,143C-280,134,-294,134,-303,143L-738,578L-893,423C-907,410,-929,418,-932,437L-998,973C-1000,988,-988,1000,-973,998L-436,932C-418,929,-410,907,-423,893L-578,738L-143,303C-134,294,-134,279,-143,270L-271,143Z",
  "M824,-384C800,-479,847,-630,1000,-683L837,-692C837,-692,775,-908,492,-928C208,-947,23,-935,23,-935C23,-935,233,-801,149,-563C87,-437,-9,-333,-113,-215C-116,-212,-119,-209,-121,-206C-463,179,-1000,792,-1000,792C-409,947,-13,777,222,573C271,573,308,572,333,572C659,572,935,290,924,-25C916,-241,847,-290,824,-384Z",
  "M-519,-971L-697,-971C-710,-971,-720,-961,-720,-948L-720,971C-720,983,-710,993,-697,993L-519,993C-507,993,-497,983,-497,971L-497,-948C-497,-961,-507,-971,-519,-971ZM720,-769L720,-971C720,-990,698,-1000,683,-988L-494,0L683,988C698,1000,720,990,720,971L720,769C720,743,708,717,688,700L-147,0L688,-700C708,-717,720,-743,720,-769Z",
  "M958,-482C935,-568,867,-636,781,-659C625,-701,0,-701,0,-701C0,-701,-625,-701,-781,-659C-868,-636,-935,-568,-958,-482C-1000,-326,-1000,0,-1000,0C-1000,0,-1000,326,-958,482C-935,568,-867,636,-781,659C-625,701,0,701,0,701C0,701,625,701,781,659C868,636,935,568,958,482C1000,326,1000,0,1000,0C1000,0,1000,-326,958,-482ZM-199,299L-199,-299L319,-2L-199,299Z",
  "M697,-971L519,-971C507,-971,497,-961,497,-948L497,971C497,983,507,993,519,993L697,993C710,993,720,983,720,971L720,-948C720,-961,710,-971,697,-971ZM-720,-971L-720,-769C-720,-742,-708,-717,-688,-700L147,0L-688,700C-708,717,-720,742,-720,769L-720,971C-720,990,-698,1000,-683,988L494,0L-683,-988C-698,-1000,-720,-990,-720,-971Z",
  "M942,-627L692,-627C657,-627,630,-599,631,-564L660,251L848,251L994,-565C1000,-599,977,-627,942,-627ZM770,376L739,376C678,376,629,425,629,486L629,517C629,577,678,627,739,627L770,627C830,627,880,577,880,517L880,486C880,425,830,376,770,376ZM-248,-627C-663,-627,-1000,-346,-1000,0C-1000,346,-663,627,-248,627C167,627,503,346,503,0C503,-346,167,-627,-248,-627ZM253,-125L108,-125L-123,105L-123,251L65,251L65,376L-436,376L-436,251L-248,251L-248,105L-604,-251L-686,-251L-686,-376L-311,-376L-311,-251L-393,-251L-185,-43L-123,-105L-123,-251L253,-251L253,-125Z",
  "M398,-301C411,-301,424,-301,437,-300C383,-587,84,-807,-277,-807C-676,-807,-1000,-538,-1000,-206C-1000,-25,-903,139,-750,249C-738,258,-730,272,-730,288C-730,294,-731,298,-732,304C-745,349,-764,421,-765,425C-766,431,-769,436,-769,442C-769,456,-758,467,-745,467C-739,467,-735,465,-731,462L-572,371C-561,364,-548,360,-534,360C-527,360,-520,361,-513,363C-439,384,-359,396,-277,396C-264,396,-250,396,-237,395C-253,348,-262,299,-262,248C-262,-56,34,-301,398,-301ZM-36,-494C17,-494,60,-451,60,-398C60,-345,17,-302,-36,-302C-89,-302,-132,-345,-132,-398C-132,-451,-89,-494,-36,-494ZM-518,-302C-571,-302,-614,-345,-614,-398C-614,-451,-571,-494,-518,-494C-465,-494,-422,-451,-422,-398C-422,-345,-465,-302,-518,-302ZM792,626C919,534,1000,398,1000,247C1000,-30,730,-254,397,-254C65,-254,-205,-30,-205,247C-205,524,65,748,397,748C466,748,533,738,594,721C600,719,606,718,612,718C623,718,634,722,644,727L776,803C779,805,783,807,787,807C793,807,798,805,802,801C805,797,807,792,807,787C807,782,805,777,804,772C804,770,787,709,777,671C776,667,775,663,775,658C775,645,782,633,792,626ZM197,167C153,167,117,131,117,87C117,43,153,7,197,7C241,7,277,43,277,87C277,131,241,167,197,167ZM599,167C554,167,518,131,518,87C518,43,554,7,599,7C643,7,679,43,679,87C679,131,643,167,599,167Z",
  "M-371,-4C-371,173,-228,316,-51,316C125,316,268,173,268,-4C268,-180,125,-323,-51,-323C-228,-323,-371,-181,-371,-4ZM834,-345L299,-317C444,-148,447,97,325,284L-104,944C74,953,257,914,423,818C834,581,1000,83,834,-345ZM-488,179L-845,-523C-943,-374,-1000,-195,-1000,-4C-1000,471,-653,864,-199,933L45,456C-175,497,-388,376,-488,179ZM10,-472L795,-431C715,-590,589,-729,423,-825C272,-912,107,-953,-55,-952C-334,-951,-607,-826,-789,-600L-497,-151C-424,-360,-212,-485,10,-472Z",
  "M911,-343C862,-458,793,-562,704,-651C615,-740,511,-809,396,-858C277,-909,151,-934,20,-934C-87,-934,-192,-917,-291,-883C-523,-992,-792,-1000,-869,-1000C-874,-1000,-888,-1000,-893,-999C-923,-998,-951,-983,-967,-958C-984,-932,-987,-901,-976,-872L-812,-460C-900,-311,-947,-141,-947,33C-947,164,-921,291,-871,409C-822,524,-753,628,-664,717C-575,806,-471,875,-356,924C-237,974,-110,1000,20,1000C151,1000,277,974,397,924C511,876,615,806,704,717C792,628,862,524,911,409C961,290,987,163,987,33C986,-98,961,-224,911,-343ZM81,-142C81,-90,39,-47,-14,-47C-66,-47,-108,-90,-108,-142L-108,-282C-108,-334,-66,-377,-14,-377C39,-377,81,-335,81,-282L81,-142ZM528,-142C528,-90,486,-47,433,-47C381,-47,339,-90,339,-142L339,-282C339,-334,381,-377,433,-377C485,-377,528,-335,528,-282L528,-142Z",
  "M-328,-735C-330,-753,-352,-761,-365,-748L-483,-629L-846,-992C-854,-1000,-868,-1000,-877,-992L-992,-877C-1000,-868,-1000,-855,-992,-846L-629,-484L-748,-365C-761,-352,-753,-330,-735,-328L-301,-277C-287,-275,-275,-287,-277,-301L-328,-735ZM-301,277L-735,328C-753,330,-761,352,-748,365L-629,484L-992,846C-1000,854,-1000,868,-992,877L-877,991C-868,1000,-854,1000,-846,991L-483,629L-365,748C-352,760,-330,753,-328,735L-277,301C-275,287,-287,275,-301,277ZM301,-277L735,-328C753,-330,761,-352,748,-365L629,-484L992,-846C1000,-854,1000,-868,992,-877L877,-991C868,-1000,854,-1000,846,-991L483,-629L365,-748C352,-761,330,-753,328,-735L277,-301C275,-287,287,-275,301,-277ZM629,484L748,365C761,352,753,330,735,328L301,277C287,275,275,287,277,301L328,735C330,753,352,761,365,748L483,629L846,992C854,1000,868,1000,877,992L992,877C1000,868,1000,855,992,846L629,484Z",
  "M0,-978C-552,-978,-1000,-531,-1000,21C-1000,458,-720,829,-330,965C-278,978,-286,941,-286,916L-286,742C-589,778,-601,577,-621,544C-663,474,-760,456,-731,422C-662,387,-591,431,-510,552C-451,639,-336,624,-277,610C-265,557,-237,510,-200,474C-514,417,-645,226,-645,-2C-645,-113,-609,-214,-537,-296C-583,-432,-533,-547,-526,-565C-396,-576,-261,-472,-251,-463C-177,-483,-93,-494,1,-494C96,-494,181,-483,255,-463C280,-482,405,-572,526,-561C533,-544,581,-430,538,-297C611,-215,648,-112,648,-1C648,227,516,419,201,474C253,526,286,598,286,678L286,929C288,949,286,969,319,969C715,836,1000,462,1000,21C1000,-531,552,-978,0,-978Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM571,-434L480,-346C472,-340,469,-331,470,-321L470,321C469,331,472,341,480,347L570,434L570,453L121,453L121,435L214,345C223,336,223,333,223,320L223,-200L-34,451L-69,451L-367,-200L-367,237C-370,255,-363,273,-350,287L-230,432L-230,451L-571,451L-571,432L-451,287C-438,273,-433,255,-436,237L-436,-268C-434,-282,-440,-296,-450,-305L-557,-434L-557,-453L-225,-453L30,108L256,-453L571,-453L571,-434Z",
  "M820,810L-820,810C-831,810,-840,819,-840,830L-840,980C-840,991,-831,1000,-820,1000L820,1000C831,1000,840,991,840,980L840,830C840,819,831,810,820,810ZM820,-1000L-820,-1000C-831,-1000,-840,-991,-840,-980L-840,-830C-840,-819,-831,-810,-820,-810L820,-810C831,-810,840,-819,840,-830L840,-980C840,-991,831,-1000,820,-1000ZM247,-335C262,-335,270,-352,261,-364L9,-683C2,-692,-12,-692,-19,-683L-271,-364C-280,-352,-272,-335,-257,-335L-90,-335L-90,335L-247,335C-262,335,-270,352,-261,364L-9,683C-2,692,12,692,19,683L271,364C280,352,272,335,257,335L90,335L90,-335L247,-335Z",
  "M977,753L-977,753C-990,753,-1000,763,-1000,775L-1000,944C-1000,956,-990,966,-977,966L977,966C990,966,1000,956,1000,944L1000,775C1000,763,990,753,977,753ZM-18,441C-9,453,9,453,18,441L332,43C344,28,333,7,315,7L106,7L106,-944C106,-956,96,-966,84,-966L-85,-966C-97,-966,-107,-956,-107,-944L-107,6L-315,6C-333,6,-344,28,-332,43L-18,441Z",
  "M836,-91L-836,-91C-847,-91,-856,-83,-856,-72L-856,72C-856,83,-847,91,-836,91L836,91C847,91,856,83,856,72L856,-72C856,-83,847,-91,836,-91ZM-14,-271C-7,-262,7,-262,13,-271L256,-577C265,-589,257,-606,242,-606L91,-606L91,-981C91,-991,83,-1000,72,-1000L-72,-1000C-83,-1000,-91,-991,-91,-981L-91,-606L-242,-606C-257,-606,-265,-589,-256,-578L-14,-271ZM14,271C7,262,-7,262,-13,271L-256,578C-265,589,-257,606,-242,606L-91,606L-91,981C-91,991,-83,1000,-72,1000L72,1000C83,1000,91,991,91,981L91,606L242,606C257,606,265,589,256,578L14,271Z",
  "M978,730L-978,730C-990,730,-1000,740,-1000,751L-1000,915C-1000,926,-990,936,-978,936L978,936C990,936,1000,926,1000,915L1000,751C1000,740,990,730,978,730ZM-340,-505L-139,-505L-139,415C-139,426,-129,436,-117,436L46,436C58,436,68,426,68,415L68,-505L269,-505C287,-505,297,-526,286,-540L-18,-925C-27,-936,-44,-936,-52,-925L-357,-540C-368,-526,-358,-505,-340,-505Z",
  "M977,-966L-977,-966C-990,-966,-1000,-956,-1000,-944L-1000,-775C-1000,-763,-990,-753,-977,-753L977,-753C990,-753,1000,-763,1000,-775L1000,-944C1000,-956,990,-966,977,-966ZM18,-441C9,-453,-9,-453,-18,-441L-332,-43C-344,-28,-333,-7,-315,-7L-107,-7L-107,944C-107,956,-97,966,-85,966L84,966C96,966,106,956,106,944L106,-6L315,-6C333,-6,344,-28,332,-43L18,-441Z",
  "M-17,398C-8,409,8,409,17,398L316,20C327,6,317,-15,299,-15L101,-15L101,-920C101,-932,92,-941,80,-941L-80,-941C-92,-941,-102,-932,-102,-920L-102,-15L-299,-15C-317,-15,-327,5,-316,19L-17,398ZM979,305L818,305C806,305,797,314,797,326L797,738L-797,738L-797,326C-797,314,-806,305,-818,305L-979,305C-990,305,-1000,314,-1000,326L-1000,856C-1000,903,-962,941,-914,941L914,941C962,941,1000,903,1000,856L1000,326C1000,314,990,305,979,305Z",
  "M893,-212L647,-982C644,-993,634,-1000,623,-1000L413,-1000C401,-1000,392,-993,388,-982L140,-212C139,-210,139,-207,139,-205C139,-191,150,-179,164,-179L317,-179C329,-179,339,-187,342,-198L389,-365L631,-365L678,-198C681,-187,691,-180,703,-180L869,-180C872,-180,874,-180,877,-181C883,-183,888,-187,892,-193C895,-199,895,-206,893,-212ZM414,-507L503,-824L520,-824L608,-507L414,-507ZM804,833L452,833L452,832L812,318C815,314,817,309,817,304L817,205C817,191,805,179,792,179L237,179C223,179,212,191,212,205L212,321C212,335,223,347,237,347L570,347L570,348L209,861C206,865,204,870,204,876L204,975C204,989,215,1000,229,1000L804,1000C818,1000,829,989,829,975L829,858C829,844,818,833,804,833ZM-545,-937C-554,-948,-571,-948,-579,-937L-884,-552C-895,-537,-885,-516,-867,-516L-660,-516L-660,924C-660,936,-650,946,-638,946L-486,946C-474,946,-464,936,-464,924L-464,-516L-258,-516C-240,-516,-229,-537,-241,-552L-545,-937Z",
  "M893,-212L647,-982C644,-993,634,-1000,623,-1000L413,-1000C401,-1000,392,-993,388,-982L140,-212C139,-210,139,-207,139,-205C139,-191,150,-179,164,-179L317,-179C329,-179,339,-187,342,-198L389,-365L631,-365L678,-198C681,-187,691,-180,703,-180L869,-180C872,-180,874,-180,877,-181C883,-183,888,-187,892,-193C895,-199,895,-206,893,-212ZM414,-507L503,-824L520,-824L608,-507L414,-507ZM804,833L452,833L452,832L812,318C815,314,817,309,817,304L817,205C817,191,805,179,792,179L237,179C223,179,212,191,212,205L212,321C212,335,223,347,237,347L570,347L570,348L209,861C206,865,204,870,204,876L204,975C204,989,215,1000,229,1000L804,1000C818,1000,829,989,829,975L829,858C829,844,818,833,804,833ZM-258,516L-464,516L-464,-924C-464,-936,-474,-946,-486,-946L-638,-946C-650,-946,-660,-936,-660,-924L-660,516L-867,516C-885,516,-895,538,-884,552L-579,937C-571,948,-554,948,-545,937L-241,552C-230,538,-240,516,-258,516Z",
  "M998,704L940,224C939,208,919,201,908,213L765,356L110,-298C95,-313,71,-313,56,-298L-190,-53L-857,-720C-864,-728,-877,-728,-884,-720L-993,-611C-1000,-604,-1000,-591,-993,-584L-217,192C-202,208,-177,208,-162,192L83,-53L628,492L485,635C474,646,481,666,497,668L977,726C989,728,1000,717,998,704Z",
  "M890,212L-953,212C-965,212,-975,221,-975,233L-975,392C-975,404,-965,413,-953,413L649,413L267,898C256,912,266,932,284,932L476,932C489,932,501,926,509,916L956,349C1000,293,961,212,890,212ZM953,-413L-649,-413L-267,-898C-256,-912,-266,-932,-284,-932L-476,-932C-489,-932,-501,-926,-509,-916L-956,-349C-1000,-293,-961,-212,-890,-212L953,-212C965,-212,975,-221,975,-233L975,-392C975,-404,965,-413,953,-413Z",
  "M980,584L-980,584C-991,584,-1000,593,-1000,604L-1000,744C-1000,755,-991,764,-980,764L980,764C991,764,1000,755,1000,744L1000,604C1000,593,991,584,980,584ZM-866,271L-766,370C-759,378,-746,378,-738,370L-152,-215L92,29C124,60,174,60,206,29L866,-629C874,-637,874,-650,866,-658L767,-757C759,-764,746,-764,738,-757L149,-169L-95,-412C-126,-443,-177,-443,-208,-412L-866,243C-874,251,-874,264,-866,271Z",
  "M977,-726L497,-668C481,-666,474,-646,485,-635L628,-492L83,53L-162,-192C-177,-207,-202,-207,-217,-192L-993,584C-1000,591,-1000,603,-993,611L-884,720C-877,727,-864,727,-857,720L-190,53L56,298C71,313,95,313,110,298L765,-356L908,-213C919,-201,939,-208,940,-224L998,-704C1000,-717,989,-727,977,-726Z",
  "M-260,-175L940,-175C951,-175,960,-184,960,-195L960,-335C960,-346,951,-355,940,-355L-260,-355C-271,-355,-280,-346,-280,-335L-280,-195C-280,-184,-271,-175,-260,-175ZM-280,335C-280,346,-271,355,-260,355L940,355C951,355,960,346,960,335L960,195C960,184,951,175,940,175L-260,175C-271,175,-280,184,-280,195L-280,335ZM980,-880L-980,-880C-991,-880,-1000,-871,-1000,-860L-1000,-720C-1000,-709,-991,-700,-980,-700L980,-700C991,-700,1000,-709,1000,-720L1000,-860C1000,-871,991,-880,980,-880ZM980,700L-980,700C-991,700,-1000,709,-1000,720L-1000,860C-1000,871,-991,880,-980,880L980,880C991,880,1000,871,1000,860L1000,720C1000,709,991,700,980,700ZM-924,325L-533,18C-522,9,-522,-8,-533,-17L-924,-325C-938,-337,-960,-326,-960,-308L-960,308C-960,326,-939,337,-924,325Z",
  "M-258,-175L940,-175C951,-175,960,-184,960,-195L960,-335C960,-346,951,-355,940,-355L-258,-355C-269,-355,-278,-346,-278,-335L-278,-195C-278,-184,-269,-175,-258,-175ZM-278,335C-278,346,-269,355,-258,355L940,355C951,355,960,346,960,335L960,195C960,184,951,175,940,175L-258,175C-269,175,-278,184,-278,195L-278,335ZM980,-879L-977,-879C-988,-879,-997,-870,-997,-859L-997,-719C-997,-708,-988,-699,-977,-699L980,-699C991,-699,1000,-708,1000,-719L1000,-859C1000,-870,991,-879,980,-879ZM980,699L-977,699C-988,699,-997,708,-997,719L-997,859C-997,870,-988,879,-977,879L980,879C991,879,1000,870,1000,859L1000,719C1000,708,991,699,980,699ZM-989,17L-599,325C-584,336,-563,326,-563,307L-563,-307C-563,-326,-584,-336,-599,-325L-989,-17C-1000,-8,-1000,8,-989,17Z",
  "M980,-880L-980,-880C-991,-880,-1000,-871,-1000,-860L-1000,-700C-1000,-689,-991,-680,-980,-680L980,-680C991,-680,1000,-689,1000,-700L1000,-860C1000,-871,991,-880,980,-880ZM980,680L-980,680C-991,680,-1000,689,-1000,700L-1000,860C-1000,871,-991,880,-980,880L980,880C991,880,1000,871,1000,860L1000,700C1000,689,991,680,980,680ZM980,-100L-980,-100C-991,-100,-1000,-91,-1000,-80L-1000,80C-1000,91,-991,100,-980,100L980,100C991,100,1000,91,1000,80L1000,-80C1000,-91,991,-100,980,-100Z",
  "M980,-784L-451,-784C-462,-784,-471,-775,-471,-765L-471,-627C-471,-617,-462,-608,-451,-608L980,-608C991,-608,1000,-617,1000,-627L1000,-765C1000,-775,991,-784,980,-784ZM980,-88L-451,-88C-462,-88,-471,-79,-471,-69L-471,69C-471,79,-462,88,-451,88L980,88C991,88,1000,79,1000,69L1000,-69C1000,-79,991,-88,980,-88ZM980,608L-451,608C-462,608,-471,617,-471,627L-471,765C-471,775,-462,784,-451,784L980,784C991,784,1000,775,1000,765L1000,627C1000,617,991,608,980,608ZM-863,-696ZM-1000,-696L-998,-672L-992,-649L-982,-627L-968,-608L-951,-591L-931,-577L-910,-567L-887,-561L-863,-559L-839,-561L-816,-567L-794,-577L-775,-591L-758,-608L-744,-627L-734,-649L-728,-672L-725,-696L-728,-720L-734,-743L-744,-765L-758,-784L-775,-801L-794,-815L-816,-825L-839,-831L-863,-833L-887,-831L-910,-825L-931,-815L-951,-801L-968,-784L-982,-765L-992,-743L-998,-720L-1000,-696ZM-863,0ZM-1000,0L-998,24L-992,47L-982,69L-968,88L-951,105L-931,119L-910,129L-887,135L-863,137L-839,135L-816,129L-794,119L-775,105L-758,88L-744,69L-734,47L-728,24L-725,0L-728,-24L-734,-47L-744,-69L-758,-88L-775,-105L-794,-119L-816,-129L-839,-135L-863,-137L-887,-135L-910,-129L-931,-119L-951,-105L-968,-88L-982,-69L-992,-47L-998,-24L-1000,0ZM-863,696ZM-1000,696L-998,720L-992,743L-982,765L-968,784L-951,801L-931,815L-910,825L-887,831L-863,833L-839,831L-816,825L-794,815L-775,801L-758,784L-744,765L-734,743L-728,720L-725,696L-728,672L-734,649L-744,627L-758,608L-775,591L-794,577L-816,567L-839,561L-863,559L-887,561L-910,567L-931,577L-951,591L-968,608L-982,627L-992,649L-998,672L-1000,696Z",
  "M981,596L-423,596C-434,596,-442,605,-442,615L-442,750C-442,761,-434,769,-423,769L981,769C991,769,1000,761,1000,750L1000,615C1000,605,991,596,981,596ZM981,-769L-423,-769C-434,-769,-442,-761,-442,-750L-442,-615C-442,-605,-434,-596,-423,-596L981,-596C991,-596,1000,-605,1000,-615L1000,-750C1000,-761,991,-769,981,-769ZM981,-87L-423,-87C-434,-87,-442,-78,-442,-67L-442,67C-442,78,-434,87,-423,87L981,87C991,87,1000,78,1000,67L1000,-67C1000,-78,991,-87,981,-87ZM-712,481L-990,481C-996,481,-1000,485,-1000,490L-1000,572C-1000,577,-996,582,-990,582L-816,582L-816,631L-902,631C-907,631,-912,635,-912,641L-912,722C-912,728,-907,732,-902,732L-816,732L-816,784L-990,784C-996,784,-1000,788,-1000,793L-1000,875C-1000,880,-996,885,-990,885L-712,885C-706,885,-702,880,-702,875L-702,490C-702,485,-706,481,-712,481ZM-990,-779L-899,-779L-899,-490C-899,-485,-895,-481,-889,-481L-793,-481C-788,-481,-784,-485,-784,-490L-784,-865C-784,-876,-792,-885,-803,-885L-990,-885C-996,-885,-1000,-880,-1000,-875L-1000,-788C-1000,-783,-996,-779,-990,-779ZM-712,-202L-990,-202C-996,-202,-1000,-198,-1000,-192L-1000,-106C-1000,-100,-996,-96,-990,-96L-826,-96L-995,91C-998,94,-1000,99,-1000,104L-1000,192C-1000,198,-996,202,-990,202L-712,202C-706,202,-702,198,-702,192L-702,106C-702,100,-706,96,-712,96L-876,96L-707,-91C-704,-94,-702,-99,-702,-104L-702,-192C-702,-198,-706,-202,-712,-202Z",
  "M980,-885L-260,-885C-271,-885,-280,-876,-280,-865L-280,-725C-280,-714,-271,-705,-260,-705L980,-705C991,-705,1000,-714,1000,-725L1000,-865C1000,-876,991,-885,980,-885ZM980,175L-260,175C-271,175,-280,184,-280,195L-280,335C-280,346,-271,355,-260,355L980,355C991,355,1000,346,1000,335L1000,195C1000,184,991,175,980,175ZM980,705L-980,705C-991,705,-1000,714,-1000,725L-1000,865C-1000,876,-991,885,-980,885L980,885C991,885,1000,876,1000,865L1000,725C1000,714,991,705,980,705ZM980,-355L-980,-355C-991,-355,-1000,-346,-1000,-335L-1000,-195C-1000,-184,-991,-175,-980,-175L980,-175C991,-175,1000,-184,1000,-195L1000,-335C1000,-346,991,-355,980,-355Z",
  "M-620,-705L620,-705C631,-705,640,-714,640,-725L640,-865C640,-876,631,-885,620,-885L-620,-885C-631,-885,-640,-876,-640,-865L-640,-725C-640,-714,-631,-705,-620,-705ZM620,355C631,355,640,346,640,335L640,195C640,184,631,175,620,175L-620,175C-631,175,-640,184,-640,195L-640,335C-640,346,-631,355,-620,355L620,355ZM980,705L-980,705C-991,705,-1000,714,-1000,725L-1000,865C-1000,876,-991,885,-980,885L980,885C991,885,1000,876,1000,865L1000,725C1000,714,991,705,980,705ZM980,-355L-980,-355C-991,-355,-1000,-346,-1000,-335L-1000,-195C-1000,-184,-991,-175,-980,-175L980,-175C991,-175,1000,-184,1000,-195L1000,-335C1000,-346,991,-355,980,-355Z",
  "M-980,-705L260,-705C271,-705,280,-714,280,-725L280,-865C280,-876,271,-885,260,-885L-980,-885C-991,-885,-1000,-876,-1000,-865L-1000,-725C-1000,-714,-991,-705,-980,-705ZM-980,355L260,355C271,355,280,346,280,335L280,195C280,184,271,175,260,175L-980,175C-991,175,-1000,184,-1000,195L-1000,335C-1000,346,-991,355,-980,355ZM980,705L-980,705C-991,705,-1000,714,-1000,725L-1000,865C-1000,876,-991,885,-980,885L980,885C991,885,1000,876,1000,865L1000,725C1000,714,991,705,980,705ZM980,-355L-980,-355C-991,-355,-1000,-346,-1000,-335L-1000,-195C-1000,-184,-991,-175,-980,-175L980,-175C991,-175,1000,-184,1000,-195L1000,-335C1000,-346,991,-355,980,-355Z",
  "M982,625L-982,625C-992,625,-1000,633,-1000,643L-1000,768C-1000,778,-992,786,-982,786L982,786C992,786,1000,778,1000,768L1000,643C1000,633,992,625,982,625ZM982,-786L-982,-786C-992,-786,-1000,-778,-1000,-768L-1000,-643C-1000,-633,-992,-625,-982,-625L982,-625C992,-625,1000,-633,1000,-643L1000,-768C1000,-778,992,-786,982,-786ZM750,330C770,330,786,314,786,295L786,-295C786,-314,770,-330,750,-330L-750,-330C-770,-330,-786,-314,-786,-295L-786,295C-786,314,-770,330,-750,330L750,330ZM-625,-170L625,-170L625,170L-625,170L-625,-170Z",
  "M982,625L-982,625C-992,625,-1000,633,-1000,643L-1000,768C-1000,778,-992,786,-982,786L982,786C992,786,1000,778,1000,768L1000,643C1000,633,992,625,982,625ZM982,-786L-982,-786C-992,-786,-1000,-778,-1000,-768L-1000,-643C-1000,-633,-992,-625,-982,-625L982,-625C992,-625,1000,-633,1000,-643L1000,-768C1000,-778,992,-786,982,-786ZM929,330C948,330,964,314,964,295L964,-295C964,-314,948,-330,929,-330L-214,-330C-234,-330,-250,-314,-250,-295L-250,295C-250,314,-234,330,-214,330L929,330ZM-89,-170L804,-170L804,170L-89,170L-89,-170ZM-964,299C-964,309,-956,317,-946,317L-446,317C-437,317,-429,309,-429,299L-429,174C-429,164,-437,156,-446,156L-946,156C-956,156,-964,164,-964,174L-964,299ZM-946,-156L-446,-156C-437,-156,-429,-164,-429,-174L-429,-299C-429,-309,-437,-317,-446,-317L-946,-317C-956,-317,-964,-309,-964,-299L-964,-174C-964,-164,-956,-156,-946,-156Z",
  "M982,625L-982,625C-992,625,-1000,633,-1000,643L-1000,768C-1000,778,-992,786,-982,786L982,786C992,786,1000,778,1000,768L1000,643C1000,633,992,625,982,625ZM982,-786L-982,-786C-992,-786,-1000,-778,-1000,-768L-1000,-643C-1000,-633,-992,-625,-982,-625L982,-625C992,-625,1000,-633,1000,-643L1000,-768C1000,-778,992,-786,982,-786ZM214,330C234,330,250,314,250,295L250,-295C250,-314,234,-330,214,-330L-929,-330C-948,-330,-964,-314,-964,-295L-964,295C-964,314,-948,330,-929,330L214,330ZM-804,-170L89,-170L89,170L-804,170L-804,-170ZM429,299C429,309,437,317,446,317L946,317C956,317,964,309,964,299L964,174C964,164,956,156,946,156L446,156C437,156,429,164,429,174L429,299ZM446,-156L946,-156C956,-156,964,-164,964,-174L964,-299C964,-309,956,-317,946,-317L446,-317C437,-317,429,-309,429,-299L429,-174C429,-164,437,-156,446,-156Z",
  "M505,-78C596,-173,652,-301,652,-443L652,-470C652,-763,413,-1000,118,-1000L-686,-1000C-727,-1000,-761,-967,-761,-926L-761,920C-761,964,-725,1000,-681,1000L185,1000C503,1000,761,744,761,428L761,398C761,200,659,25,505,-78ZM-500,-739L111,-739C266,-739,391,-618,391,-469L391,-443C391,-295,265,-174,111,-174L-500,-174L-500,-739ZM496,428C496,599,356,737,182,737L-500,737L-500,89L182,89C356,89,496,227,496,398L496,428Z",
  "M980,760L-980,760C-991,760,-1000,769,-1000,780L-1000,980C-1000,991,-991,1000,-980,1000L980,1000C991,1000,1000,991,1000,980L1000,780C1000,769,991,760,980,760ZM-646,560L-433,560C-423,560,-413,553,-410,543L-276,128L272,128L405,543C408,553,418,560,428,560L651,560C654,560,657,560,659,559C672,554,679,540,674,528L154,-984C150,-993,141,-1000,131,-1000L-125,-1000C-135,-1000,-144,-994,-148,-984L-669,528C-670,530,-670,533,-670,536C-670,549,-659,560,-646,560ZM-6,-730L4,-730L214,-71L-218,-71L-6,-730Z",
  "M417,-355L313,-355C290,-355,268,-344,255,-325L-96,161L-255,-59C-268,-78,-290,-89,-313,-89L-417,-89C-432,-89,-440,-72,-432,-60L-154,325C-125,365,-67,365,-38,325L432,-327C440,-338,432,-355,417,-355ZM0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830Z",
  "M0,820ZM-180,820L-177,851L-169,882L-156,910L-138,936L-116,958L-90,976L-61,989L-31,997L0,1000L31,997L61,989L90,976L116,958L138,936L156,910L169,882L177,851L180,820L177,789L169,759L156,730L138,705L116,683L90,665L61,651L31,643L0,640L-31,643L-61,651L-90,665L-116,683L-138,705L-156,730L-169,759L-177,789L-180,820ZM-90,348L90,348C102,348,112,338,112,326L112,-978C112,-990,102,-1000,90,-1000L-90,-1000C-102,-1000,-112,-990,-112,-978L-112,326C-112,338,-102,348,-90,348Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830ZM487,-447L374,-447C364,-447,356,-439,356,-429L356,429C356,439,364,447,374,447L487,447C496,447,504,439,504,429L504,-429C504,-439,496,-447,487,-447ZM-142,-336C-31,-336,44,-266,53,-163C54,-153,61,-146,71,-146L188,-146C193,-146,198,-151,198,-156C198,-337,55,-464,-142,-464C-372,-464,-504,-309,-504,-53L-504,57C-504,311,-372,464,-142,464C54,464,198,341,198,169C198,163,193,159,188,159L70,159C61,159,53,166,52,175C43,271,-32,337,-142,337C-278,337,-355,236,-355,57L-355,-53C-355,-235,-278,-336,-142,-336Z",
  "M981,-231L250,-231C239,-231,231,-222,231,-212L231,58C231,68,239,77,250,77L365,77C376,77,385,68,385,58L385,-77L529,-77L529,692L418,692C408,692,399,701,399,712L399,827C399,838,408,846,418,846L812,846C823,846,832,838,832,827L832,712C832,701,823,692,812,692L702,692L702,-77L846,-77L846,58C846,68,855,77,865,77L981,77C991,77,1000,68,1000,58L1000,-212C1000,-222,991,-231,981,-231ZM346,-519L346,-827C346,-838,338,-846,327,-846L-981,-846C-991,-846,-1000,-838,-1000,-827L-1000,-519C-1000,-509,-991,-500,-981,-500L-846,-500C-836,-500,-827,-509,-827,-519L-827,-673L-423,-673L-423,673L-644,673C-655,673,-663,682,-663,692L-663,827C-663,838,-655,846,-644,846L-10,846C1,846,10,838,10,827L10,692C10,682,1,673,-10,673L-231,673L-231,-673L173,-673L173,-519C173,-509,182,-500,192,-500L327,-500C338,-500,346,-509,346,-519Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830ZM106,-52L50,-65L50,-365C135,-353,187,-300,196,-235C197,-226,205,-219,214,-219L314,-219C324,-219,333,-229,332,-239C318,-378,204,-467,51,-483L51,-556C51,-566,43,-574,33,-574L-30,-574C-40,-574,-48,-566,-48,-556L-48,-482C-206,-467,-329,-379,-329,-217C-329,-66,-218,7,-102,35L-46,49L-46,368C-145,354,-200,302,-212,231C-213,222,-221,216,-229,216L-333,216C-343,216,-351,225,-350,235C-340,358,-247,471,-49,486L-49,556C-49,566,-41,574,-31,574L33,574C42,574,50,566,50,556L50,485C225,469,350,376,350,208C350,53,251,-16,106,-52ZM-47,-88C-59,-92,-70,-95,-80,-99C-156,-126,-191,-170,-191,-227C-191,-308,-129,-354,-47,-365L-47,-88ZM50,368L50,70C57,72,63,73,69,75C175,107,210,152,210,220C210,307,145,360,50,368Z",
  "M0,-820ZM-180,-820L-177,-789L-169,-759L-156,-730L-138,-705L-116,-683L-90,-665L-61,-651L-31,-643L0,-640L31,-643L61,-651L90,-665L116,-683L138,-705L156,-730L169,-759L177,-789L180,-820L177,-851L169,-882L156,-910L138,-936L116,-958L90,-976L61,-989L31,-997L0,-1000L-31,-997L-61,-989L-90,-976L-116,-958L-138,-936L-156,-910L-169,-882L-177,-851L-180,-820ZM90,-348L-90,-348C-102,-348,-112,-338,-112,-326L-112,978C-112,990,-102,1000,-90,1000L90,1000C102,1000,112,990,112,978L112,-326C112,-338,102,-348,90,-348Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830ZM443,-482C425,-489,406,-489,388,-481L-217,-217L-481,388C-489,407,-489,427,-481,446C-474,463,-460,477,-442,484C-433,487,-425,489,-416,489C-406,489,-396,487,-387,483L218,218L482,-387C490,-405,490,-426,482,-444C475,-462,460,-475,443,-482ZM145,50L203,108L108,203L50,145L-295,296L-144,-49L-201,-106L-106,-201L-49,-144L296,-295L145,50ZM-106,-201L-201,-106L-144,-49L50,145L108,203L203,108L145,50L-49,-144Z",
  "M323,-844L-981,-844C-991,-844,-1000,-835,-1000,-825L-1000,-518C-1000,-507,-991,-499,-981,-499L-847,-499C-836,-499,-827,-507,-827,-518L-827,-671L-425,-671L-425,671L-645,671C-656,671,-664,680,-664,690L-664,825C-664,835,-656,844,-645,844L-12,844C-2,844,7,835,7,825L7,690C7,680,-2,671,-12,671L-233,671L-233,-671L170,-671L170,-518C170,-507,179,-499,189,-499L323,-499C334,-499,343,-507,343,-518L343,-825C343,-835,334,-844,323,-844ZM977,465L822,465L822,-465L977,-465C992,-465,1000,-482,991,-493L749,-799C743,-808,729,-808,722,-799L481,-493C472,-482,480,-465,494,-465L649,-465L649,465L494,465C480,465,472,482,480,493L722,799C729,808,743,808,749,799L991,493C1000,482,992,465,977,465Z",
  "M982,-85L129,-85C107,-89,83,-94,59,-98C23,-105,9,-107,-10,-111C-125,-133,-194,-156,-248,-187C-327,-233,-365,-295,-365,-377C-365,-460,-331,-528,-267,-576C-203,-623,-113,-648,-6,-648C116,-648,211,-616,275,-552C307,-520,331,-480,346,-435C349,-426,352,-412,355,-395C357,-384,367,-377,377,-377L540,-377C552,-377,562,-387,562,-399L562,-401C561,-417,560,-428,558,-437C542,-534,496,-620,425,-683C326,-774,180,-821,4,-821C-158,-821,-303,-781,-406,-708C-463,-667,-507,-616,-536,-557C-567,-496,-582,-426,-582,-349C-582,-283,-569,-228,-543,-178C-525,-143,-499,-113,-467,-85L-982,-85C-992,-85,-1000,-77,-1000,-67L-1000,67C-1000,77,-992,85,-982,85L-15,85C-10,86,-6,87,-2,88C67,101,108,111,147,122C198,136,237,151,270,170C350,215,389,279,389,368C389,447,354,517,292,566C223,620,123,648,0,648C-97,648,-180,629,-246,592C-311,555,-355,503,-379,437C-381,432,-383,425,-385,417C-388,407,-397,400,-407,400L-585,400C-597,400,-607,410,-607,422L-607,425C-607,430,-606,434,-606,437C-591,546,-538,636,-448,703C-343,780,-195,821,-20,821C168,821,326,777,436,693C492,651,535,599,563,539C592,479,607,410,607,335C607,264,594,205,568,153C555,128,538,105,519,85L982,85C992,85,1000,77,1000,67L1000,-67C1000,-77,992,-85,982,-85Z",
  "M-393,-203ZM-500,-203L-498,-185L-494,-166L-486,-150L-475,-134L-462,-121L-446,-110L-430,-102L-411,-98L-393,-96L-374,-98L-356,-102L-339,-110L-324,-121L-311,-134L-300,-150L-292,-166L-287,-185L-286,-203L-287,-222L-292,-240L-300,-257L-311,-272L-324,-285L-339,-296L-356,-304L-374,-309L-393,-310L-411,-309L-430,-304L-446,-296L-462,-285L-475,-272L-486,-257L-494,-240L-498,-222L-500,-203ZM393,-203ZM286,-203L287,-185L292,-166L300,-150L311,-134L324,-121L339,-110L356,-102L374,-98L393,-96L411,-98L430,-102L446,-110L462,-121L475,-134L486,-150L494,-166L498,-185L500,-203L498,-222L494,-240L486,-257L475,-272L462,-285L446,-296L430,-304L411,-309L393,-310L374,-309L356,-304L339,-296L324,-285L311,-272L300,-257L292,-240L287,-222L286,-203ZM0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM587,587C511,663,422,723,323,765C221,808,112,830,0,830C-112,830,-221,808,-323,765C-422,723,-511,663,-587,587C-664,511,-723,422,-765,323C-808,221,-830,112,-830,0C-830,-112,-808,-221,-765,-323C-723,-422,-663,-511,-587,-587C-511,-664,-422,-723,-323,-765C-221,-808,-112,-830,0,-830C112,-830,221,-808,323,-765C422,-723,511,-663,587,-587C664,-511,723,-422,765,-323C808,-221,830,-112,830,0C830,112,808,221,765,323C723,422,663,511,587,587ZM0,47C-191,47,-347,197,-357,385C-358,396,-350,404,-339,404L-232,404C-223,404,-215,397,-214,388C-205,277,-113,190,0,190C113,190,206,277,214,388C215,397,223,404,232,404L339,404C350,404,358,396,357,385C347,197,191,47,0,47Z",
  "M848,793L-848,793C-860,793,-870,803,-870,814L-870,979C-870,991,-860,1000,-848,1000L848,1000C860,1000,870,991,870,979L870,814C870,803,860,793,848,793ZM0,587C189,587,366,513,499,380C633,246,707,69,707,-120L707,-967C707,-985,692,-1000,674,-1000L511,-1000C493,-1000,478,-985,478,-967L478,-120C478,144,264,359,0,359C-264,359,-478,144,-478,-120L-478,-967C-478,-985,-493,-1000,-511,-1000L-674,-1000C-692,-1000,-707,-985,-707,-967L-707,-120C-707,69,-633,246,-499,380C-366,514,-189,587,0,587Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830ZM0,-393ZM-107,-393L-106,-374L-101,-356L-93,-339L-82,-324L-69,-311L-54,-300L-37,-292L-19,-287L0,-286L19,-287L37,-292L54,-300L69,-311L82,-324L93,-339L101,-356L106,-374L107,-393L106,-411L101,-430L93,-446L82,-462L69,-475L54,-486L37,-494L19,-498L0,-500L-19,-498L-37,-494L-54,-486L-69,-475L-82,-462L-93,-446L-101,-430L-106,-411L-107,-393ZM54,-143L-54,-143C-63,-143,-71,-135,-71,-125L-71,482C-71,492,-63,500,-54,500L54,500C63,500,71,492,71,482L71,-125C71,-135,63,-143,54,-143Z",
  "M978,-321C990,-321,1000,-330,1000,-342L1000,-505C1000,-517,990,-527,978,-527L533,-527L533,-978C533,-990,523,-1000,511,-1000L337,-1000C325,-1000,315,-990,315,-978L315,-527L-304,-527L-304,-978C-304,-990,-314,-1000,-326,-1000L-500,-1000C-512,-1000,-522,-990,-522,-978L-522,-527L-978,-527C-990,-527,-1000,-517,-1000,-505L-1000,-342C-1000,-330,-990,-321,-978,-321L-522,-321L-522,321L-978,321C-990,321,-1000,330,-1000,342L-1000,505C-1000,517,-990,527,-978,527L-522,527L-522,978C-522,990,-512,1000,-500,1000L-326,1000C-314,1000,-304,990,-304,978L-304,527L315,527L315,978C315,990,325,1000,337,1000L511,1000C523,1000,533,990,533,978L533,527L978,527C990,527,1000,517,1000,505L1000,342C1000,330,990,321,978,321L533,321L533,-321L978,-321ZM315,321L-304,321L-304,-321L315,-321L315,321Z",
  "M204,-412L-345,-15C-355,-7,-355,7,-345,14L204,412C216,420,232,412,232,397L232,292C232,270,221,248,203,235L-122,0L203,-235C221,-248,232,-270,232,-293L232,-397C232,-412,216,-420,204,-412ZM0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830Z",
  "M808,-1000L-419,-1000C-432,-1000,-442,-990,-442,-977L-442,-795C-442,-783,-432,-773,-419,-773L96,-773L-347,773L-808,773C-821,773,-831,783,-831,795L-831,977C-831,990,-821,1000,-808,1000L419,1000C432,1000,442,990,442,977L442,795C442,783,432,773,419,773L-111,773L332,-773L808,-773C821,-773,831,-783,831,-795L831,-977C831,-990,821,-1000,808,-1000Z",
  "M921,-389C877,-495,815,-591,737,-676C752,-706,761,-740,761,-777C761,-900,661,-1000,538,-1000C473,-1000,414,-972,374,-928C255,-976,129,-1000,0,-1000C-135,-1000,-266,-974,-389,-921C-508,-871,-615,-799,-707,-707C-799,-615,-871,-508,-921,-389C-974,-266,-1000,-135,-1000,0C-1000,135,-974,266,-921,389C-871,508,-799,615,-707,707C-615,799,-508,871,-389,921C-266,974,-135,1000,0,1000C135,1000,266,974,389,921C508,871,615,799,707,707C799,615,871,508,921,389C974,266,1000,135,1000,0C1000,-135,974,-266,921,-389ZM841,355C795,464,729,562,645,645C562,729,464,795,355,841C243,889,123,913,0,913C-123,913,-243,889,-355,841C-464,795,-562,729,-645,645C-729,562,-795,464,-841,355C-889,243,-913,123,-913,0C-913,-123,-889,-243,-841,-355C-795,-464,-729,-562,-645,-645C-562,-729,-464,-795,-355,-841C-243,-889,-123,-913,0,-913C113,-913,223,-892,328,-852C319,-829,315,-803,315,-777C315,-654,415,-554,538,-554C593,-554,643,-573,682,-606C749,-532,802,-448,841,-355C889,-243,913,-123,913,0C913,123,889,243,841,355Z",
  "M397,-239L293,-239C270,-239,248,-228,235,-209L0,115L-235,-209C-248,-228,-270,-239,-293,-239L-397,-239C-412,-239,-420,-222,-412,-210L-15,339C-7,348,7,348,14,339L412,-210C420,-222,412,-239,397,-239ZM0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830Z",
  "M-164,751L333,-692C333,-694,333,-695,334,-696L-164,751ZM333,-768L182,-768C175,-768,168,-763,165,-756L-351,744C-352,746,-352,748,-352,750C-352,760,-344,768,-334,768L-183,768C-175,768,-168,763,-166,756L-164,751L334,-696L350,-744C351,-746,351,-748,351,-750C351,-760,343,-768,333,-768ZM988,-24C986,-26,984,-28,982,-30L493,-412C485,-418,474,-417,468,-409C465,-406,464,-402,464,-398L464,-216C464,-211,467,-206,471,-202L728,-1L471,199C467,203,464,208,464,213L464,395C464,405,472,413,482,413C486,413,490,411,493,409L982,27C997,15,1000,-8,988,-24ZM-493,-412L-982,-30C-984,-28,-986,-26,-988,-24C-1000,-8,-997,14,-982,27L-493,409C-490,411,-486,413,-482,413C-472,413,-464,405,-464,395L-464,213C-464,208,-467,203,-471,199L-728,-1L-471,-202C-467,-206,-464,-211,-464,-216L-464,-398C-464,-402,-466,-406,-468,-409C-474,-417,-485,-418,-493,-412Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830ZM263,-483C227,-491,186,-496,139,-496C-99,-496,-260,-371,-304,-161L-375,-161C-385,-161,-393,-153,-393,-143L-393,-82C-393,-73,-385,-65,-375,-65L-316,-65C-317,-55,-317,-46,-317,-36L-317,46L-375,46C-385,46,-393,54,-393,64L-393,125C-393,135,-385,143,-375,143L-308,143C-269,364,-106,496,139,496C186,496,227,492,263,484C271,482,277,475,277,467L277,371C277,360,267,352,256,354C223,360,185,363,140,363C-13,363,-115,281,-150,143L142,143C152,143,160,135,160,125L160,64C160,54,152,46,142,46L-162,46L-162,-34C-162,-44,-162,-55,-162,-65L142,-65C151,-65,159,-73,159,-83L159,-143C159,-153,151,-161,142,-161L-145,-161C-106,-288,-6,-363,140,-363C184,-363,223,-360,255,-353C267,-351,277,-359,277,-371L277,-466C277,-475,271,-482,263,-483Z",
  "M-830,-840L-980,-840C-991,-840,-1000,-831,-1000,-820L-1000,820C-1000,831,-991,840,-980,840L-830,840C-819,840,-810,831,-810,820L-810,-820C-810,-831,-819,-840,-830,-840ZM980,-840L830,-840C819,-840,810,-831,810,-820L810,820C810,831,819,840,830,840L980,840C991,840,1000,831,1000,820L1000,-820C1000,-831,991,-840,980,-840ZM683,-19L364,-271C352,-280,335,-272,335,-257L335,-90L-335,-90L-335,-247C-335,-262,-352,-270,-364,-261L-683,-9C-692,-2,-692,12,-683,19L-364,271C-353,280,-335,272,-335,257L-335,90L335,90L335,247C335,262,352,270,364,261L683,9C692,2,692,-12,683,-19Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830ZM12,-359C131,-359,211,-283,220,-173C221,-163,229,-156,238,-156L365,-156C370,-156,375,-161,375,-167C375,-360,222,-496,12,-496C-233,-496,-375,-330,-375,-56L-375,60C-375,332,-233,496,12,496C222,496,375,364,375,180C375,174,370,169,365,169L238,169C228,169,221,177,220,186C210,289,130,359,12,359C-133,359,-216,252,-216,61L-216,-56C-215,-250,-133,-359,12,-359Z",
  "M411,-71L-411,-71C-421,-71,-429,-63,-429,-54L-429,54C-429,63,-421,71,-411,71L411,71C421,71,429,63,429,54L429,-54C429,-63,421,-71,411,-71ZM0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830Z",
  "M-393,-203ZM-500,-203L-498,-185L-494,-166L-486,-150L-475,-134L-462,-121L-446,-110L-430,-102L-411,-98L-393,-96L-374,-98L-356,-102L-339,-110L-324,-121L-311,-134L-300,-150L-292,-166L-287,-185L-286,-203L-287,-222L-292,-240L-300,-257L-311,-272L-324,-285L-339,-296L-356,-304L-374,-309L-393,-310L-411,-309L-430,-304L-446,-296L-462,-285L-475,-272L-486,-257L-494,-240L-498,-222L-500,-203ZM393,-203ZM286,-203L287,-185L292,-166L300,-150L311,-134L324,-121L339,-110L356,-102L374,-98L393,-96L411,-98L430,-102L446,-110L462,-121L475,-134L486,-150L494,-166L498,-185L500,-203L498,-222L494,-240L486,-257L475,-272L462,-285L446,-296L430,-304L411,-309L393,-310L374,-309L356,-304L339,-296L324,-285L311,-272L300,-257L292,-240L287,-222L286,-203ZM0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM587,587C511,663,422,723,323,765C221,808,112,830,0,830C-112,830,-221,808,-323,765C-422,723,-511,663,-587,587C-664,511,-723,422,-765,323C-808,221,-830,112,-830,0C-830,-112,-808,-221,-765,-323C-723,-422,-663,-511,-587,-587C-511,-664,-422,-723,-323,-765C-221,-808,-112,-830,0,-830C112,-830,221,-808,323,-765C422,-723,511,-663,587,-587C664,-511,723,-422,765,-323C808,-221,830,-112,830,0C830,112,808,221,765,323C723,422,663,511,587,587ZM339,118L-339,118C-349,118,-357,126,-357,136L-357,243C-357,253,-349,261,-339,261L339,261C349,261,357,253,357,243L357,136C357,126,349,118,339,118Z",
  "M-1000,-90L-600,-90L-600,90L-1000,90ZM-200,-90L200,-90L200,90L-200,90ZM600,-90L1000,-90L1000,90L600,90Z",
  "M411,-71L71,-71L71,-411C71,-421,63,-429,54,-429L-54,-429C-63,-429,-71,-421,-71,-411L-71,-71L-411,-71C-421,-71,-429,-63,-429,-54L-429,54C-429,63,-421,71,-411,71L-71,71L-71,411C-71,421,-63,429,-54,429L54,429C63,429,71,421,71,411L71,71L411,71C421,71,429,63,429,54L429,-54C429,-63,421,-71,411,-71ZM0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830ZM463,-29L-198,-509C-222,-526,-254,-509,-254,-480L-254,480C-254,509,-221,526,-198,509L463,29C483,15,483,-15,463,-29ZM-112,270L-112,-270L260,0L-112,270Z",
  "M978,-954L811,-954C799,-954,789,-944,789,-931L789,506L-559,506L-559,303C-559,284,-581,274,-595,286L-989,596C-1000,605,-1000,622,-989,631L-595,942C-580,954,-559,943,-559,924L-559,716L822,716C920,716,1000,637,1000,539L1000,-931C1000,-944,990,-954,978,-954Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830ZM249,-436C182,-495,94,-527,0,-527C-94,-527,-182,-494,-249,-436C-319,-375,-357,-293,-357,-205L-357,-188C-357,-179,-349,-171,-339,-171L-232,-171C-222,-171,-214,-179,-214,-188L-214,-205C-214,-304,-118,-384,0,-384C118,-384,214,-304,214,-205C214,-136,165,-72,89,-43C42,-25,2,7,-27,48C-56,91,-72,142,-72,193L-72,241C-72,251,-64,259,-54,259L53,259C63,259,71,251,71,241L71,190C71,146,99,106,140,90C272,40,357,-76,357,-205C357,-293,319,-375,249,-436ZM0,491ZM-89,491L-88,506L-84,520L-79,534L-70,546L-60,557L-49,566L-36,573L-22,578L-7,580L7,580L22,578L36,573L49,566L60,557L70,546L79,534L84,520L88,506L89,491L88,476L84,462L79,449L70,436L60,425L49,416L36,409L22,405L7,402L-7,402L-22,405L-36,409L-49,416L-60,425L-70,436L-79,449L-84,462L-88,476L-89,491Z",
  "M980,-90L-980,-90C-991,-90,-1000,-81,-1000,-70L-1000,70C-1000,81,-991,90,-980,90L980,90C991,90,1000,81,1000,70L1000,-70C1000,-81,991,-90,980,-90Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830ZM308,362L-94,362L-94,352C-33,313,4,239,4,148C4,117,-1,86,-8,57L212,57C222,57,230,49,230,39L230,-28C230,-38,222,-46,212,-46L-38,-46C-54,-96,-68,-148,-68,-203C-68,-300,8,-360,127,-360C175,-360,222,-351,262,-337C273,-332,285,-341,285,-354L285,-442C285,-449,281,-456,274,-458C232,-475,176,-487,117,-487C-90,-487,-221,-388,-221,-218C-221,-160,-206,-102,-189,-46L-308,-46C-318,-46,-326,-38,-326,-28L-326,39C-326,48,-318,56,-308,56L-158,56C-151,89,-145,122,-145,155C-145,256,-209,341,-308,365C-316,367,-321,375,-321,383L-321,469C-321,479,-313,487,-303,487L308,487C318,487,326,479,326,469L326,380C326,370,318,362,308,362Z",
  "M978,-103L-978,-103C-990,-103,-1000,-93,-1000,-82L-1000,82C-1000,93,-990,103,-978,103L978,103C990,103,1000,93,1000,82L1000,-82C1000,-93,990,-103,978,-103Z",
  "M345,-15L-204,-412C-216,-420,-232,-412,-232,-397L-232,-293C-232,-270,-221,-248,-203,-235L122,0L-203,235C-221,248,-232,270,-232,293L-232,397C-232,412,-216,420,-204,412L345,15C355,7,355,-7,345,-15ZM0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830Z",
  "M651,-597C615,-676,564,-747,498,-808C365,-932,188,-1000,0,-1000C-188,-1000,-365,-932,-498,-808C-564,-747,-615,-676,-651,-597C-689,-514,-708,-427,-708,-336L-708,-267C-708,-251,-695,-238,-679,-238L-540,-238C-524,-238,-511,-251,-511,-267L-511,-336C-511,-594,-282,-803,0,-803C282,-803,511,-594,511,-336C511,-231,473,-132,402,-49C332,33,233,91,123,116C60,130,3,166,-37,217C-76,267,-98,330,-98,394L-98,475C-98,491,-86,504,-70,504L70,504C86,504,99,491,99,475L99,394C99,353,127,318,166,309C317,275,454,193,552,80C601,22,640,-42,666,-112C694,-184,708,-259,708,-336C708,-427,689,-515,651,-597ZM0,711C-80,711,-145,775,-145,855C-145,935,-80,1000,0,1000C80,1000,145,935,145,855C145,775,80,711,0,711Z",
  "M-393,-203ZM-500,-203L-498,-185L-494,-166L-486,-150L-475,-134L-462,-121L-446,-110L-430,-102L-411,-98L-393,-96L-374,-98L-356,-102L-339,-110L-324,-121L-311,-134L-300,-150L-292,-166L-287,-185L-286,-203L-287,-222L-292,-240L-300,-257L-311,-272L-324,-285L-339,-296L-356,-304L-374,-309L-393,-310L-411,-309L-430,-304L-446,-296L-462,-285L-475,-272L-486,-257L-494,-240L-498,-222L-500,-203ZM393,-203ZM286,-203L287,-185L292,-166L300,-150L311,-134L324,-121L339,-110L356,-102L374,-98L393,-96L411,-98L430,-102L446,-110L462,-121L475,-134L486,-150L494,-166L498,-185L500,-203L498,-222L494,-240L486,-257L475,-272L462,-285L446,-296L430,-304L411,-309L393,-310L374,-309L356,-304L339,-296L324,-285L311,-272L300,-257L292,-240L287,-222L286,-203ZM0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM587,587C511,663,422,723,323,765C221,808,112,830,0,830C-112,830,-221,808,-323,765C-422,723,-511,663,-587,587C-664,511,-723,422,-765,323C-808,221,-830,112,-830,0C-830,-112,-808,-221,-765,-323C-723,-422,-663,-511,-587,-587C-511,-664,-422,-723,-323,-765C-221,-808,-112,-830,0,-830C112,-830,221,-808,323,-765C422,-723,511,-663,587,-587C664,-511,723,-422,765,-323C808,-221,830,-112,830,0C830,112,808,221,765,323C723,422,663,511,587,587ZM339,47L232,47C223,47,215,54,214,63C205,174,113,261,0,261C-113,261,-206,174,-214,63C-215,54,-223,47,-232,47L-339,47C-350,47,-358,55,-357,66C-347,254,-191,404,0,404C191,404,347,254,357,66C358,55,350,47,339,47Z",
  "M933,-106L106,-106L106,-1000L-106,-1000L-106,-106L-933,-106C-946,-106,-956,-96,-956,-83L-956,83C-956,96,-946,106,-933,106L-106,106L-106,1000L106,1000L106,106L933,106C946,106,956,96,956,83L956,-83C956,-96,946,-106,933,-106Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830ZM195,83C273,55,370,-26,370,-183C370,-342,269,-475,48,-475L-299,-475C-309,-475,-317,-467,-317,-458L-317,458C-317,467,-309,475,-299,475L-177,475C-168,475,-160,467,-160,458L-160,110L38,110L205,465C208,471,214,475,221,475L359,475C362,475,365,475,367,474C376,469,380,459,375,450L195,83ZM22,-16L-160,-16L-160,-346L27,-346C134,-346,207,-290,207,-177C207,-73,141,-16,22,-16Z",
  "M-1000,-90L-820,-90L-820,90L-1000,90ZM-545,-90L-365,-90L-365,90L-545,90ZM365,-90L545,-90L545,90L365,90ZM820,-90L1000,-90L1000,90L820,90ZM-90,-90L90,-90L90,90L-90,90Z",
  "M-619,-1000L-381,-1000L-381,1000L-619,1000ZM595,-1000L405,-1000C392,-1000,381,-989,381,-976L381,976C381,989,392,1000,405,1000L595,1000C608,1000,619,989,619,976L619,-976C619,-989,608,-1000,595,-1000Z",
  "M764,645C765,644,765,644,766,643C912,469,1000,245,1000,0C1000,-245,912,-469,766,-643C766,-644,765,-644,765,-645C762,-648,760,-650,757,-653C756,-654,756,-655,755,-656C752,-660,749,-663,746,-667L745,-667C742,-671,738,-674,735,-678L735,-678C728,-686,721,-694,713,-701L713,-701L702,-712L702,-712C698,-716,695,-719,692,-722C690,-723,689,-724,688,-725C686,-728,683,-730,681,-732C681,-732,680,-733,679,-734C501,-899,262,-1000,0,-1000C-262,-1000,-501,-899,-679,-734C-680,-733,-681,-733,-681,-732C-684,-730,-686,-727,-688,-725C-689,-724,-690,-723,-692,-722C-695,-719,-698,-715,-702,-712L-702,-712L-713,-701L-713,-701C-721,-693,-728,-686,-735,-678L-735,-678C-739,-674,-742,-670,-746,-667L-746,-666C-749,-663,-752,-659,-755,-656C-756,-655,-757,-654,-758,-653C-760,-650,-762,-647,-765,-644C-765,-644,-766,-643,-766,-643C-912,-469,-1000,-245,-1000,0C-1000,245,-912,469,-766,643C-766,644,-765,644,-765,645C-762,648,-760,650,-758,653C-757,654,-756,655,-755,656C-752,660,-749,663,-746,667C-746,667,-746,667,-746,667C-742,671,-739,675,-735,678L-735,679C-728,686,-721,694,-714,701L-713,701C-710,705,-706,708,-703,712L-702,712C-695,720,-687,727,-680,734C-501,899,-262,1000,0,1000C262,1000,501,899,679,734C687,727,694,720,702,712L702,712C706,708,709,705,713,701L713,701C720,694,727,686,734,679L735,678C738,675,742,671,745,667C745,667,745,667,745,667C748,663,751,660,754,656C755,655,756,654,757,653C760,650,762,648,764,645ZM773,327C743,399,702,467,652,528C597,480,536,438,471,403C496,298,513,183,517,62L837,62C830,154,809,242,773,327ZM837,-62L517,-62C513,-183,496,-298,471,-403C536,-438,597,-480,652,-528C702,-467,743,-399,773,-327C809,-242,830,-154,837,-62ZM327,-773C415,-736,496,-684,567,-619C525,-584,481,-553,434,-526C399,-626,354,-713,302,-783C310,-780,319,-777,327,-773ZM124,790C104,806,83,819,62,827L62,413C152,419,238,439,321,471C302,526,281,577,256,623C217,695,172,753,124,790ZM256,-623C281,-577,302,-526,321,-471C238,-439,152,-419,62,-413L62,-827C83,-819,104,-806,124,-790C172,-753,217,-695,256,-623ZM62,288L62,62L392,62C388,161,376,257,355,348L355,350C263,316,165,294,62,288ZM62,-62L62,-288C165,-294,263,-316,355,-350L355,-348C376,-257,388,-161,392,-62L62,-62ZM-62,62L-62,288C-165,294,-263,316,-355,350L-355,348C-376,257,-388,161,-392,62L-62,62ZM-392,-62C-388,-161,-376,-257,-355,-348L-355,-350C-263,-316,-165,-294,-62,-288L-62,-62L-392,-62ZM-62,413L-62,827C-83,819,-104,806,-124,790C-172,753,-217,695,-256,623C-281,577,-302,526,-321,471C-238,439,-152,419,-62,413ZM-62,-413C-152,-419,-238,-439,-321,-471C-302,-526,-281,-577,-256,-623C-217,-695,-172,-753,-124,-790C-104,-806,-83,-819,-62,-827L-62,-413ZM-327,-773C-318,-777,-310,-780,-302,-783C-354,-713,-399,-626,-434,-526C-481,-552,-525,-584,-567,-619C-496,-684,-415,-736,-327,-773ZM-773,-327C-743,-399,-702,-467,-652,-528C-597,-480,-536,-438,-471,-403C-496,-298,-513,-183,-517,-62L-837,-62C-830,-154,-809,-242,-773,-327ZM-837,62L-517,62C-512,183,-496,298,-471,403C-536,438,-597,480,-652,528C-702,467,-743,399,-773,327C-809,242,-830,154,-837,62ZM-327,773C-415,736,-496,684,-567,619C-525,584,-481,553,-434,526C-399,626,-354,713,-302,783C-310,780,-319,777,-327,773ZM327,773C318,777,310,780,302,783C354,713,399,626,434,526C481,552,525,584,567,619C496,684,415,736,327,773Z",
  "M611,597C716,597,802,510,802,404C802,275,611,66,611,66C611,66,420,275,420,404C420,510,506,597,611,597ZM-295,491C-278,508,-250,508,-233,491L382,-123C399,-140,399,-168,382,-185L-233,-800C-234,-801,-236,-803,-238,-804L-426,-992C-434,-1000,-448,-1000,-456,-992L-572,-876C-580,-868,-580,-854,-572,-846L-410,-684L-909,-185C-926,-168,-926,-140,-909,-123L-295,491ZM-264,-586L166,-156L-693,-156L-264,-586ZM941,769L-941,769C-952,769,-961,778,-961,789L-961,981C-961,991,-952,1000,-941,1000L941,1000C952,1000,961,991,961,981L961,789C961,778,952,769,941,769Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830ZM356,-475L223,-475C217,-475,210,-472,208,-466L5,-64L-2,-64L-204,-466C-208,-472,-214,-475,-220,-475L-356,-475C-359,-475,-362,-475,-364,-473C-373,-469,-376,-458,-371,-449L-123,8L-260,8C-270,8,-278,16,-278,26L-278,93C-278,103,-270,111,-260,111L-77,111L-77,203L-260,203C-270,203,-278,211,-278,221L-278,288C-278,298,-270,306,-260,306L-77,306L-77,458C-77,467,-69,475,-60,475L62,475C71,475,79,467,79,458L79,306L262,306C272,306,280,298,280,288L280,221C280,211,272,203,262,203L79,203L79,110L262,110C272,110,280,102,280,93L280,26C280,16,272,8,262,8L124,8L372,-449C373,-452,374,-455,374,-458C374,-467,366,-475,356,-475Z",
  "M967,-585L482,-286L16,-907C8,-918,-8,-918,-16,-907L-481,-286L-967,-585C-982,-594,-1000,-582,-998,-566L-807,883C-804,903,-787,918,-767,918L768,918C788,918,805,903,807,883L998,-566C1000,-582,982,-594,967,-585ZM653,747L-653,747L-787,-274L-438,-59L0,-644L439,-59L787,-274L653,747ZM0,-5C-155,-5,-281,121,-281,276C-281,431,-155,557,0,557C155,557,281,431,281,276C281,121,155,-5,0,-5ZM0,396C-66,396,-120,342,-120,276C-120,209,-66,155,0,155C67,155,120,209,120,276C120,342,67,396,0,396Z",
  "M15,-339C7,-348,-7,-348,-14,-339L-412,210C-420,222,-412,239,-397,239L-292,239C-270,239,-248,228,-235,209L0,-115L235,209C248,228,270,239,293,239L397,239C412,239,420,222,412,210L15,-339ZM0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830Z",
  "M991,-14L673,-265C661,-274,644,-266,644,-251L644,-90L90,-90L90,-643L252,-643C266,-643,275,-661,266,-673L14,-991C7,-1000,-7,-1000,-14,-991L-265,-673C-274,-661,-266,-643,-251,-643L-90,-643L-90,-90L-643,-90L-643,-251C-643,-266,-661,-275,-673,-265L-991,-14C-1000,-7,-1000,7,-991,14L-673,265C-661,275,-644,266,-644,251L-644,90L-90,90L-90,644L-252,644C-266,644,-275,661,-266,673L-14,991C-7,1000,7,1000,14,991L265,673C274,661,266,644,251,644L90,644L90,90L644,90L644,252C644,266,661,275,673,266L991,14C1000,7,1000,-7,991,-14Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-458,-458,-830,0,-830C458,-830,830,-458,830,0C830,458,458,830,0,830ZM0,393ZM-107,393L-106,411L-101,430L-93,446L-82,462L-69,475L-54,486L-37,494L-19,498L0,500L19,498L37,494L54,486L69,475L82,462L93,446L101,430L106,411L107,393L106,374L101,356L93,339L82,324L69,311L54,300L37,292L19,287L0,286L-19,287L-37,292L-54,300L-69,311L-82,324L-93,339L-101,356L-106,374L-107,393ZM-54,143L54,143C63,143,71,135,71,125L71,-482C71,-492,63,-500,54,-500L-54,-500C-63,-500,-71,-492,-71,-482L-71,125C-71,135,-63,143,-54,143Z",
  "M-819,-19C-816,-123,-795,-224,-755,-318C-714,-416,-655,-503,-579,-579C-504,-654,-417,-713,-319,-755C-218,-797,-111,-819,0,-819C110,-819,218,-797,318,-755C416,-713,503,-654,578,-579C602,-555,624,-530,645,-504L501,-392C489,-383,493,-363,508,-359L927,-256C939,-254,950,-263,950,-275L952,-705C952,-721,934,-730,921,-720L787,-615C604,-850,319,-1000,0,-1000C-546,-1000,-990,-563,-1000,-20C-1000,-9,-991,0,-981,0L-838,0C-827,0,-819,-8,-819,-19ZM981,0L838,0C827,0,819,8,819,19C816,123,795,224,755,318C714,416,655,504,579,579C504,654,417,713,319,755C218,797,111,819,0,819C-110,819,-218,797,-318,755C-416,713,-503,654,-579,579C-602,555,-624,530,-645,504L-502,392C-489,383,-493,363,-509,359L-927,256C-939,254,-950,263,-950,275L-952,706C-952,721,-934,731,-921,721L-787,616C-604,850,-319,1000,0,1000C546,1000,990,562,1000,20C1000,9,991,0,981,0Z",
  "M889,-488L532,-488C565,-540,585,-601,585,-667C585,-850,435,-1000,251,-1000C151,-1000,61,-956,0,-886C-61,-956,-151,-1000,-251,-1000C-435,-1000,-585,-850,-585,-667C-585,-601,-565,-540,-532,-488L-889,-488C-932,-488,-966,-453,-966,-411L-966,72C-966,83,-957,92,-947,92L-850,92L-850,923C-850,965,-816,1000,-773,1000L773,1000C816,1000,850,965,850,923L850,92L947,92C957,92,966,83,966,72L966,-411C966,-453,932,-488,889,-488ZM82,-667C82,-760,158,-836,251,-836C344,-836,420,-760,420,-667C420,-573,344,-498,251,-498L82,-498L82,-667ZM-251,-836C-158,-836,-82,-760,-82,-667L-82,-498L-251,-498C-344,-498,-420,-573,-420,-667C-420,-760,-344,-836,-251,-836ZM-802,-72L-802,-324L-82,-324L-82,-72L-802,-72ZM-686,92L-82,92L-82,836L-686,836L-686,92ZM686,836L82,836L82,92L686,92L686,836ZM802,-72L82,-72L82,-324L802,-324L802,-72Z",
  "M364,-446C364,-457,356,-465,346,-465L219,-465C212,-465,205,-461,202,-455L5,-62L-2,-62L-199,-455C-203,-461,-209,-465,-216,-465L-345,-465C-348,-465,-351,-464,-354,-463C-363,-458,-366,-446,-362,-438L-120,8L-252,8C-263,8,-271,16,-271,27L-271,90C-271,100,-263,108,-252,108L-76,108L-76,199L-252,199C-263,199,-271,207,-271,217L-271,280C-271,291,-263,299,-252,299L-76,299L-76,446C-76,457,-67,465,-57,465L59,465C69,465,77,457,77,446L77,299L255,299C265,299,273,290,273,280L273,217C273,207,265,199,255,199L77,199L77,108L255,108C265,108,273,100,273,89L273,26C273,16,265,8,255,8L121,8L362,-438C363,-440,364,-443,364,-446ZM-823,-18C-821,-123,-799,-224,-759,-320C-718,-418,-658,-506,-583,-582C-507,-657,-419,-717,-321,-758C-220,-801,-112,-823,-1,-823C110,-823,217,-801,319,-758C416,-717,504,-657,580,-582C603,-558,625,-534,645,-509L528,-418C516,-408,520,-389,535,-385L900,-296C912,-293,923,-302,923,-314L925,-689C925,-705,907,-714,895,-704L784,-617C601,-850,318,-1000,-1,-1000C-546,-1000,-990,-562,-1000,-19C-1000,-9,-992,0,-981,0L-842,0C-832,0,-824,-8,-823,-18ZM981,0L842,0C832,0,823,8,823,18C821,123,799,224,759,320C717,418,658,506,582,582C507,657,419,717,321,758C220,801,112,823,1,823C-110,823,-218,801,-319,758C-417,717,-505,657,-580,582C-603,558,-625,534,-645,509L-529,418C-517,408,-521,389,-536,385L-900,296C-912,293,-924,302,-924,314L-925,690C-925,705,-907,714,-895,704L-784,618C-601,850,-318,1000,1,1000C546,1000,990,562,1000,19C1000,9,992,0,981,0Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,830C-458,830,-830,458,-830,0C-830,-199,-760,-381,-644,-524L524,644C381,760,199,830,0,830ZM644,524L-524,-644C-381,-760,-199,-830,0,-830C458,-830,830,-458,830,0C830,199,760,381,644,524Z",
  "M-2,-970C-554,-969,-1000,-522,-1000,30C-1000,350,-850,635,-616,818L-709,938C-720,951,-710,970,-694,970L-276,968C-263,968,-254,956,-257,944L-356,538C-360,522,-380,517,-391,530L-492,660C-518,640,-542,619,-566,596C-639,522,-697,436,-737,341C-779,243,-800,138,-800,30C-800,-78,-779,-183,-737,-281C-697,-376,-639,-462,-566,-536C-492,-609,-407,-667,-312,-707C-213,-749,-108,-770,0,-770C108,-770,213,-749,311,-707C406,-667,492,-609,566,-536C639,-462,697,-376,737,-281C779,-183,800,-78,800,30C800,138,779,243,737,341C697,436,639,522,566,596C547,614,527,632,507,648C498,656,497,668,504,676L602,802C610,811,622,813,631,806C856,622,1000,343,1000,30C1000,-523,552,-970,-2,-970Z",
  "M718,-92C675,-190,613,-277,533,-349L469,-409C459,-417,444,-413,440,-401L411,-318C393,-266,359,-213,312,-160C309,-157,306,-156,303,-156C301,-156,297,-156,293,-159C290,-162,289,-166,289,-170C297,-304,257,-456,169,-620C97,-757,-4,-864,-131,-939L-223,-993C-235,-1000,-250,-991,-250,-977L-245,-870C-241,-796,-250,-732,-270,-678C-294,-612,-330,-551,-375,-496C-406,-458,-442,-423,-481,-393C-574,-321,-652,-227,-704,-122C-757,-16,-785,103,-785,222C-785,327,-764,429,-723,525C-684,618,-627,701,-555,772C-483,844,-399,900,-305,939C-209,979,-106,1000,0,1000C106,1000,209,979,305,939C399,900,483,844,555,773C627,701,684,618,723,525C764,429,785,327,785,222C785,113,763,7,718,-92ZM448,664C329,783,169,848,0,848C-169,848,-329,783,-448,664C-568,546,-633,389,-633,222C-633,125,-612,32,-568,-55C-527,-139,-464,-215,-388,-273C-340,-310,-296,-352,-258,-400C-202,-468,-158,-543,-128,-625C-116,-657,-107,-692,-101,-729C-47,-679,-2,-619,36,-549C110,-410,145,-285,138,-180C135,-129,155,-81,192,-46C225,-17,267,-2,311,-4C355,-7,396,-26,425,-59C455,-92,480,-126,502,-161C533,-121,559,-77,580,-30C615,50,633,134,633,222C633,389,568,546,448,664Z",
  "M616,818C850,635,1000,350,1000,30C1000,-522,554,-969,2,-970C-552,-970,-1000,-522,-1000,30C-1000,343,-856,622,-631,806C-622,813,-610,811,-602,802L-504,676C-497,668,-499,656,-507,648C-527,632,-547,614,-566,596C-639,522,-697,436,-737,341C-779,243,-800,138,-800,30C-800,-78,-779,-182,-737,-281C-697,-376,-639,-462,-566,-535C-492,-609,-407,-666,-312,-707C-213,-748,-108,-770,0,-770C108,-770,213,-748,311,-707C406,-666,492,-609,566,-535C639,-462,697,-376,737,-281C779,-182,800,-78,800,30C800,138,779,243,737,342C697,437,639,522,566,596C542,619,518,641,492,661L390,530C380,517,359,522,355,538L256,944C253,956,263,968,276,968L693,970C710,970,719,951,709,938L616,818Z",
  "M803,-369L275,-369L750,-969C760,-982,751,-1000,735,-1000L-184,-1000C-191,-1000,-197,-996,-201,-990L-822,82C-829,95,-820,111,-805,111L-387,111L-601,968C-606,987,-583,1000,-570,987L817,-336C829,-348,821,-369,803,-369ZM-323,526L-178,-52L-555,-52L-101,-837L437,-837L-62,-206L444,-206L-323,526Z",
  "M946,-721L811,-616C628,-850,344,-1000,24,-1000C-528,-1000,-975,-554,-976,-1C-977,552,-529,1000,24,1000C455,1000,823,726,963,343C967,333,962,321,952,318L817,272C807,268,796,273,793,283C788,295,784,307,779,319C737,416,678,504,603,579C528,654,440,713,343,755C242,797,135,819,24,819C-86,819,-194,797,-294,755C-392,714,-479,655,-555,579C-630,504,-689,416,-730,319C-773,218,-794,110,-794,0C-794,-111,-773,-218,-730,-319C-689,-417,-630,-504,-555,-580C-479,-655,-392,-714,-294,-755C-194,-798,-86,-820,24,-820C135,-820,242,-798,343,-755C440,-714,528,-655,603,-580C627,-556,649,-531,669,-505L526,-393C513,-383,518,-363,533,-359L951,-257C963,-254,975,-263,975,-275L977,-706C976,-722,958,-730,946,-721Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM432,-327L-38,325C-67,365,-125,365,-154,325L-432,-60C-440,-72,-432,-89,-417,-89L-313,-89C-290,-89,-268,-78,-255,-59L-96,161L255,-325C268,-344,290,-355,313,-355L417,-355C432,-355,440,-338,432,-327Z",
  "M58,-556L-54,-556C-64,-556,-73,-547,-73,-537L-73,103C-73,109,-70,115,-65,118L319,399C328,405,339,403,345,395L412,304C418,296,416,284,408,278L76,38L76,-537C76,-547,68,-556,58,-556ZM569,-381L933,-292C945,-289,956,-298,956,-310L958,-685C958,-701,940,-710,928,-700L562,-414C549,-404,554,-384,569,-381ZM959,319L827,274C817,271,807,276,803,285C799,297,794,309,789,320C748,418,689,506,613,582C537,657,449,717,351,758C250,801,142,823,31,823C-80,823,-188,801,-289,758C-387,717,-475,657,-551,582C-626,506,-686,418,-727,320C-770,219,-791,111,-791,0C-791,-111,-770,-219,-727,-320C-685,-418,-626,-506,-550,-582C-475,-657,-386,-717,-289,-758C-188,-801,-80,-823,31,-823C143,-823,250,-801,352,-758C449,-717,538,-657,613,-582C637,-558,659,-533,680,-507L819,-616C636,-850,351,-1000,31,-1000C-526,-1000,-974,-547,-968,10C-962,558,-517,1000,31,1000C463,1000,830,727,970,344C974,334,968,323,959,319Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM232,-293C232,-270,221,-248,203,-235L-122,0L203,235C221,248,232,270,232,293L232,397C232,412,216,420,204,412L-345,15C-355,7,-355,-7,-345,-14L204,-412C216,-420,232,-412,232,-397L232,-293Z",
  "M0,0ZM-107,0L-105,19L-101,37L-93,54L-82,69L-69,82L-54,93L-37,101L-19,105L0,107L19,105L37,101L54,93L69,82L82,69L93,54L101,37L105,19L107,0L105,-19L101,-37L93,-54L82,-69L69,-82L54,-93L37,-101L19,-105L0,-107L-19,-105L-37,-101L-54,-93L-69,-82L-82,-69L-93,-54L-101,-37L-105,-19L-107,0ZM446,0ZM339,0L341,19L346,37L353,54L364,69L377,82L393,93L410,101L428,105L446,107L465,105L483,101L500,93L515,82L528,69L539,54L547,37L552,19L553,0L552,-19L547,-37L539,-54L528,-69L515,-82L500,-93L483,-101L465,-105L446,-107L428,-105L410,-101L393,-93L377,-82L364,-69L353,-54L346,-37L341,-19L339,0ZM-446,0ZM-553,0L-552,18L-547,35L-540,51L-531,66L-519,79L-505,90L-489,98L-472,104L-455,107L-437,107L-420,104L-403,98L-388,90L-374,79L-362,66L-352,51L-345,35L-341,18L-339,0L-341,-19L-346,-37L-353,-54L-364,-69L-377,-82L-393,-93L-410,-101L-428,-105L-446,-107L-465,-105L-483,-101L-500,-93L-515,-82L-528,-69L-539,-54L-547,-37L-552,-19L-553,0ZM922,-387C871,-507,799,-615,707,-707C615,-799,507,-872,387,-922C265,-973,134,-999,0,-999L-4,-999C-140,-999,-271,-972,-394,-919C-513,-868,-619,-796,-710,-704C-802,-612,-873,-505,-923,-385C-974,-262,-1000,-130,-999,5C-999,159,-962,313,-892,451L-892,790C-892,846,-846,892,-790,892L-450,892C-313,962,-159,999,-4,999L0,999C134,999,263,973,385,923C505,873,612,802,704,710C796,619,869,513,919,394C972,271,999,140,999,4C1000,-131,974,-263,922,-387ZM585,590C428,745,221,830,0,830L-4,830C-138,829,-272,796,-390,733L-409,723L-723,723L-723,409L-733,390C-796,272,-829,138,-830,4C-831,-219,-746,-427,-590,-585C-434,-742,-226,-829,-4,-830L0,-830C112,-830,220,-808,322,-765C421,-724,511,-664,587,-587C664,-510,724,-421,766,-321C809,-218,831,-109,830,4C829,226,742,434,585,590Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM412,-210L15,339C7,348,-7,348,-14,339L-412,-210C-420,-222,-412,-239,-397,-239L-292,-239C-270,-239,-248,-228,-235,-209L0,115L235,-209C248,-228,270,-239,293,-239L397,-239C412,-239,420,-222,412,-210Z",
  "M921,-282C871,-401,799,-508,707,-600C615,-692,508,-764,389,-814C266,-867,135,-893,0,-893C-135,-893,-266,-867,-389,-814C-508,-764,-615,-692,-707,-600C-799,-508,-871,-401,-921,-282C-974,-159,-1000,-28,-1000,107C-1000,403,-870,682,-643,873L-639,876C-626,887,-610,893,-593,893L594,893C610,893,627,887,640,876L643,873C870,682,1000,403,1000,107C1000,-28,973,-159,921,-282ZM557,723L-557,723C-731,566,-830,343,-830,107C-830,-115,-744,-323,-587,-480C-430,-637,-222,-723,0,-723C222,-723,430,-637,587,-480C744,-323,830,-115,830,107C830,343,731,566,557,723ZM249,-202C242,-209,231,-209,224,-202L35,-13C-7,-25,-53,-14,-86,19C-135,68,-135,147,-86,196C-37,245,42,245,91,196C124,163,135,117,123,75L312,-114C319,-121,319,-132,312,-139L249,-202ZM-49,-429L49,-429C59,-429,67,-437,67,-446L67,-625C67,-635,59,-643,49,-643L-49,-643C-59,-643,-67,-635,-67,-625L-67,-446C-67,-437,-59,-429,-49,-429ZM531,58L531,156C531,166,539,174,549,174L728,174C738,174,746,166,746,156L746,58C746,48,738,40,728,40L549,40C539,40,531,48,531,58ZM560,-382L490,-452C483,-458,472,-458,465,-452L339,-325C332,-318,332,-307,339,-300L408,-231C415,-224,426,-224,433,-231L560,-357C567,-364,567,-375,560,-382ZM-464,-452C-471,-458,-482,-458,-489,-452L-559,-382C-566,-375,-566,-364,-559,-357L-432,-231C-425,-224,-414,-224,-407,-231L-338,-300C-331,-307,-331,-318,-338,-325L-464,-452ZM-558,40L-737,40C-746,40,-754,48,-754,58L-754,156C-754,166,-746,174,-737,174L-558,174C-548,174,-540,166,-540,156L-540,58C-540,48,-548,40,-558,40Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM429,54C429,63,421,71,411,71L-411,71C-421,71,-429,63,-429,54L-429,-54C-429,-63,-421,-71,-411,-71L411,-71C421,-71,429,-63,429,-54L429,54Z",
  "M-2,409ZM-113,409L-111,429L-106,447L-98,465L-87,481L-73,494L-57,505L-40,513L-21,518L-2,520L17,518L36,513L53,505L69,494L83,481L94,465L102,447L107,429L109,409L107,390L102,371L94,354L83,338L69,324L53,313L36,305L17,300L-2,299L-21,300L-40,305L-57,313L-73,324L-87,338L-98,354L-106,371L-111,390L-113,409ZM53,151C63,151,72,143,72,132L72,-495C72,-505,63,-514,53,-514L-57,-514C-68,-514,-76,-505,-76,-495L-76,132C-76,143,-68,151,-57,151L53,151ZM976,-283L839,-283C833,-283,828,-280,824,-275L579,63L464,-95C460,-100,455,-103,449,-103L312,-103C297,-103,288,-86,297,-74L549,274C563,294,594,294,609,274L991,-254C1000,-266,991,-283,976,-283ZM875,423L727,423C714,423,702,430,695,440C663,492,624,540,580,584C505,659,417,719,319,760C218,803,110,824,-1,824C-112,824,-220,803,-321,760C-419,719,-507,659,-583,584C-658,509,-718,421,-759,323C-802,222,-823,114,-823,3C-823,-108,-802,-215,-759,-316C-718,-414,-658,-502,-583,-578C-507,-653,-419,-712,-321,-754C-220,-796,-112,-818,-1,-818C110,-818,218,-796,319,-754C417,-712,505,-653,580,-578C624,-534,662,-486,695,-434C702,-423,714,-417,727,-417L875,-417C889,-417,897,-431,891,-443C729,-766,396,-989,11,-994C-540,-1000,-998,-549,-999,1C-1000,553,-553,1000,-1,1000C389,1000,727,776,891,450C897,438,888,423,875,423Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM369,380L222,379L0,115L-222,379L-369,380C-379,380,-387,372,-387,362C-387,358,-385,354,-383,350L-92,4L-383,-342C-385,-345,-387,-349,-387,-353C-387,-363,-379,-371,-369,-371L-222,-370L0,-106L222,-370L369,-371C379,-371,387,-363,387,-353C387,-349,385,-345,383,-341L93,4L383,350C385,354,387,358,387,362C387,372,379,380,369,380Z",
  "M450,-894C438,-900,423,-891,423,-877L423,-729C423,-716,430,-705,440,-698C492,-665,540,-627,584,-583C659,-507,719,-419,760,-321C803,-220,824,-112,824,-1C824,110,803,217,760,319C719,417,659,504,584,580C509,656,421,715,323,756C222,799,114,821,3,821C-108,821,-215,799,-316,756C-414,715,-502,656,-578,580C-653,504,-712,417,-754,319C-796,217,-818,110,-818,-1C-818,-112,-796,-220,-754,-321C-712,-419,-653,-507,-578,-583C-534,-627,-486,-665,-434,-698C-423,-704,-417,-716,-417,-729L-417,-877C-417,-891,-431,-900,-443,-894C-766,-732,-989,-399,-994,-14C-1000,537,-549,995,1,996C553,997,1000,550,1000,-1C1000,-392,776,-730,450,-894ZM-71,110L77,110C87,110,96,102,96,92L96,-979C96,-989,87,-997,77,-997L-71,-997C-81,-997,-89,-989,-89,-979L-89,92C-89,102,-81,110,-71,110Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM71,482C71,492,63,500,54,500L-54,500C-63,500,-71,492,-71,482L-71,-125C-71,-135,-63,-143,-54,-143L54,-143C63,-143,71,-135,71,-125L71,482ZM0,-286C-59,-286,-107,-334,-107,-393C-107,-452,-59,-500,0,-500C59,-500,107,-452,107,-393C107,-334,59,-286,0,-286Z",
  "M789,500L629,500C619,500,608,504,602,513C586,532,569,551,551,568C477,642,391,700,295,741C196,782,91,804,-18,804C-127,804,-232,782,-331,741C-427,700,-513,642,-587,568C-661,495,-718,409,-759,313C-801,214,-822,109,-822,0C-822,-108,-801,-213,-759,-312C-719,-408,-661,-494,-587,-568C-513,-641,-427,-699,-331,-740C-232,-781,-127,-803,-18,-803C91,-803,196,-782,295,-740C391,-699,477,-641,551,-568C569,-550,585,-531,602,-512C608,-504,619,-499,629,-499L789,-499C803,-499,812,-515,804,-527C630,-797,326,-976,-20,-975C-564,-974,-1000,-533,-995,10C-989,545,-554,976,-18,976C327,976,630,797,804,528C812,516,803,500,789,500ZM991,-14L669,-268C657,-278,639,-269,639,-254L639,-81L-73,-81C-83,-81,-91,-73,-91,-63L-91,64C-91,74,-83,82,-73,82L639,82L639,255C639,270,657,278,669,269L991,15C1000,7,1000,-7,991,-14Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM397,239L293,239C270,239,248,228,235,209L0,-115L-235,209C-248,228,-270,239,-293,239L-397,239C-412,239,-420,222,-412,210L-15,-339C-7,-348,7,-348,14,-339L412,210C420,222,412,239,397,239Z",
  "M20,-975C-326,-976,-630,-797,-804,-527C-812,-515,-803,-499,-789,-499L-629,-499C-619,-499,-608,-504,-602,-512C-586,-531,-569,-550,-551,-568C-477,-641,-391,-699,-295,-740C-196,-781,-91,-803,18,-803C127,-803,232,-782,331,-740C427,-699,513,-641,587,-568C661,-494,718,-408,759,-312C801,-213,822,-108,822,0C822,109,801,214,759,313C719,409,661,495,587,568C513,642,427,700,331,741C232,782,127,804,18,804C-91,804,-196,782,-295,741C-391,700,-477,642,-551,568C-569,550,-585,532,-602,513C-608,504,-619,500,-629,500L-789,500C-803,500,-812,516,-804,528C-630,797,-327,976,18,976C554,976,989,545,995,10C1000,-533,564,-974,20,-975ZM-639,255L-639,82L73,82C83,82,91,74,91,64L91,-63C91,-73,83,-81,73,-81L-639,-81L-639,-254C-639,-269,-657,-278,-669,-268L-991,-14C-1000,-7,-1000,7,-991,15L-669,269C-657,278,-639,270,-639,255Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM345,15L-204,412C-216,420,-232,412,-232,397L-232,293C-232,270,-221,248,-203,235L122,0L-203,-235C-221,-248,-232,-270,-232,-293L-232,-397C-232,-412,-216,-420,-204,-412L345,-15C355,-7,355,7,345,15Z",
  "M799,14L-14,14L-14,-799C-14,-809,-22,-817,-32,-817L-91,-817C-214,-817,-333,-793,-445,-746C-553,-700,-650,-635,-734,-551C-817,-468,-883,-371,-928,-263C-976,-150,-1000,-31,-1000,91C-1000,214,-976,333,-929,445C-883,553,-817,650,-734,734C-651,817,-553,883,-445,928C-333,976,-214,1000,-91,1000C31,1000,150,976,262,929C371,883,468,817,551,734C634,651,700,553,746,445C793,333,817,214,817,91L817,32C817,22,809,14,799,14ZM440,627C297,768,105,846,-95,846C-295,845,-483,766,-625,625C-767,482,-846,293,-846,91C-846,-110,-767,-300,-625,-442C-501,-566,-341,-642,-169,-659L-169,169L659,169C642,342,565,502,440,627ZM999,-112L993,-176C974,-386,881,-583,731,-732C582,-881,384,-974,174,-993L110,-999C100,-1000,90,-992,90,-981L90,-109C90,-99,99,-90,109,-90L981,-93C992,-93,1000,-102,999,-112ZM244,-244L244,-827C387,-798,519,-727,622,-623C726,-520,797,-388,827,-246L244,-244Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM429,54C429,63,421,71,411,71L71,71L71,411C71,421,63,429,54,429L-54,429C-63,429,-71,421,-71,411L-71,71L-411,71C-421,71,-429,63,-429,54L-429,-54C-429,-63,-421,-71,-411,-71L-71,-71L-71,-411C-71,-421,-63,-429,-54,-429L54,-429C63,-429,71,-421,71,-411L71,-71L411,-71C421,-71,429,-63,429,-54L429,54Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM0,580C-49,580,-89,540,-89,491C-89,442,-49,402,0,402C49,402,89,442,89,491C89,540,49,580,0,580ZM140,90C99,106,71,146,71,190L71,241C71,251,63,259,54,259L-54,259C-63,259,-71,251,-71,241L-71,193C-71,142,-56,91,-27,48C2,7,42,-25,89,-43C165,-72,214,-136,214,-205C214,-304,118,-384,0,-384C-118,-384,-214,-304,-214,-205L-214,-188C-214,-179,-222,-171,-232,-171L-339,-171C-349,-171,-357,-179,-357,-188L-357,-205C-357,-293,-319,-375,-249,-436C-182,-495,-94,-527,0,-527C94,-527,182,-494,249,-436C319,-375,357,-293,357,-205C357,-76,272,40,140,90Z",
  "M982,-59C766,-515,439,-744,0,-744C-439,-744,-766,-515,-982,-59C-1000,-22,-1000,22,-982,59C-766,515,-439,744,0,744C439,744,766,515,982,59C1000,22,1000,-21,982,-59ZM0,580C-368,580,-638,393,-828,0C-638,-393,-368,-580,0,-580C368,-580,638,-393,828,0C638,393,369,580,0,580ZM-9,-402C-231,-402,-411,-222,-411,0C-411,222,-231,402,-9,402C213,402,393,222,393,0C393,-222,213,-402,-9,-402ZM-9,256C-150,256,-265,141,-265,0C-265,-141,-150,-256,-9,-256C132,-256,247,-141,247,0C247,141,132,256,-9,256Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM142,-161C152,-161,160,-153,160,-143L160,-83C160,-73,152,-65,142,-65L-162,-65C-163,-55,-163,-44,-162,-34L-162,46L142,46C151,46,159,54,159,64L159,125C159,135,151,143,142,143L-150,143C-116,281,-13,363,140,363C184,363,223,360,256,354C267,352,277,360,277,371L277,467C277,475,271,482,262,484C227,492,186,496,139,496C-106,496,-269,364,-308,143L-375,143C-385,143,-393,135,-393,125L-393,64C-393,54,-385,46,-375,46L-317,46L-317,-36C-317,-46,-317,-56,-316,-65L-375,-65C-385,-65,-393,-73,-393,-82L-393,-143C-393,-153,-385,-161,-375,-161L-304,-161C-260,-371,-99,-496,139,-496C186,-496,227,-491,262,-483C271,-482,277,-475,277,-466L277,-371L277,-371C277,-359,267,-351,255,-353C223,-360,184,-363,140,-363C-6,-363,-106,-288,-145,-161L142,-161Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM-500,-203C-500,-262,-452,-310,-393,-310C-334,-310,-286,-262,-286,-203C-286,-144,-334,-96,-393,-96C-452,-96,-500,-144,-500,-203ZM339,404L232,404C223,404,215,397,214,388C205,277,113,190,0,190C-113,190,-206,277,-214,388C-215,397,-223,404,-232,404L-339,404C-350,404,-358,396,-357,385C-347,197,-191,47,0,47C191,47,347,197,357,385C358,396,350,404,339,404ZM393,-96C334,-96,286,-144,286,-203C286,-262,334,-310,393,-310C452,-310,500,-262,500,-203C500,-144,452,-96,393,-96Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM12,496C-233,496,-375,332,-375,60L-375,-56C-375,-330,-233,-496,12,-496C222,-496,375,-360,375,-167C375,-161,370,-156,365,-156L238,-156C229,-156,221,-163,220,-173C211,-283,131,-359,12,-359C-133,-359,-215,-250,-215,-56L-215,61C-215,252,-133,359,12,359C130,359,210,289,220,186C221,177,229,169,238,169L365,169C371,169,375,174,375,180C375,364,222,496,12,496Z",
  "M942,627L805,627C794,627,785,636,785,646L785,804L-823,804L-823,-804L785,-804L785,-646C785,-636,794,-627,805,-627L942,-627C953,-627,962,-636,962,-646L962,-902C962,-946,927,-981,884,-981L-922,-981C-965,-981,-1000,-946,-1000,-902L-1000,902C-1000,946,-965,981,-922,981L883,981C927,981,962,946,962,902L962,646C962,636,953,627,942,627ZM990,-16L627,-302C614,-313,594,-303,594,-286L594,-92L-208,-92C-219,-92,-229,-83,-229,-72L-229,72C-229,83,-219,92,-208,92L594,92L594,286C594,303,614,313,627,302L990,16C1000,8,1000,-8,990,-16Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM-142,464C-372,464,-504,311,-504,57L-504,-53C-504,-309,-372,-464,-142,-464C55,-464,198,-337,198,-156C198,-151,193,-146,188,-146L71,-146C61,-146,54,-153,53,-163C44,-266,-31,-336,-142,-336C-278,-336,-355,-235,-355,-53L-355,57C-355,237,-278,337,-142,337C-31,337,43,271,53,175C54,166,61,159,71,159L188,159C194,159,198,163,198,169C198,341,54,464,-142,464ZM504,429C504,439,496,447,487,447L374,447C364,447,356,439,356,429L356,-429C356,-439,364,-447,374,-447L487,-447C496,-447,504,-439,504,-429L504,429Z",
  "M953,-547L547,-953C528,-972,505,-986,480,-993L480,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-434C1000,-476,983,-517,953,-547ZM-320,-820L320,-820L320,-560L-320,-560L-320,-820ZM820,820L-820,820L-820,-820L-480,-820L-480,-480C-480,-436,-444,-400,-400,-400L400,-400C444,-400,480,-436,480,-480L480,-766L820,-426L820,820ZM0,-175C-199,-175,-360,-14,-360,185C-360,384,-199,545,0,545C199,545,360,384,360,185C360,-14,199,-175,0,-175ZM0,385C-110,385,-200,296,-200,185C-200,74,-110,-15,0,-15C110,-15,200,74,200,185C200,296,110,385,0,385Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM-412,425C-417,427,-422,425,-424,420C-425,418,-425,415,-424,413L-204,-90L91,205L-412,425ZM425,-412L205,91L-90,-204L413,-424C418,-426,423,-424,425,-419C426,-417,426,-415,425,-412Z",
  "M945,628L807,628C796,628,787,637,787,647L787,805L-823,805L-823,-805L787,-805L787,-647C787,-637,796,-628,807,-628L945,-628C955,-628,964,-636,964,-647L964,-904C964,-947,929,-982,886,-982L-921,-982C-965,-982,-1000,-947,-1000,-904L-1000,904C-1000,947,-965,982,-921,982L886,982C929,982,964,947,964,904L964,647C964,636,955,628,945,628ZM980,-92L176,-92L176,-286C176,-304,157,-313,143,-303L-220,-16C-230,-8,-230,8,-220,16L143,303C157,313,176,304,176,286L176,92L980,92C991,92,1000,83,1000,72L1000,-72C1000,-83,991,-92,980,-92Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM50,485L50,556C50,565,42,574,32,574L-31,574C-41,574,-49,566,-49,556L-49,486C-247,471,-340,358,-350,235C-351,225,-343,216,-333,216L-229,216C-221,216,-213,222,-212,231C-200,301,-145,354,-46,367L-46,49L-102,35C-218,7,-329,-66,-329,-217C-329,-379,-206,-467,-48,-482L-48,-556C-48,-566,-40,-574,-30,-574L33,-574C43,-574,51,-566,51,-556L51,-483C204,-468,318,-378,332,-239C333,-229,325,-220,314,-220L214,-220C205,-220,197,-226,196,-235C187,-300,135,-353,50,-365L50,-65L106,-52C251,-16,350,53,350,208C350,376,225,470,50,485ZM-191,-227C-191,-170,-156,-126,-80,-99C-70,-95,-59,-92,-47,-88L-47,-365C-129,-354,-191,-308,-191,-227ZM69,75C63,73,57,72,50,70L50,368C145,360,210,308,210,220C210,152,175,107,69,75Z",
  "M-130,-1000L-957,-1000C-980,-1000,-1000,-980,-1000,-957L-1000,-130C-1000,-107,-980,-87,-957,-87L-130,-87C-107,-87,-87,-107,-87,-130L-87,-957C-87,-980,-107,-1000,-130,-1000ZM-272,-272L-815,-272L-815,-815L-272,-815L-272,-272ZM957,-1000L130,-1000C107,-1000,87,-980,87,-957L87,-130C87,-107,107,-87,130,-87L957,-87C980,-87,1000,-107,1000,-130L1000,-957C1000,-980,980,-1000,957,-1000ZM815,-272L272,-272L272,-815L815,-815L815,-272ZM-130,87L-957,87C-980,87,-1000,107,-1000,130L-1000,957C-1000,980,-980,1000,-957,1000L-130,1000C-107,1000,-87,980,-87,957L-87,130C-87,107,-107,87,-130,87ZM-272,815L-815,815L-815,272L-272,272L-272,815ZM957,87L130,87C107,87,87,107,87,130L87,957C87,980,107,1000,130,1000L957,1000C980,1000,1000,980,1000,957L1000,130C1000,107,980,87,957,87ZM815,815L272,815L272,272L815,272L815,815Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM-179,339C-179,349,-187,357,-196,357L-304,357C-313,357,-321,349,-321,339L-321,-339C-321,-349,-313,-357,-304,-357L-196,-357C-187,-357,-179,-349,-179,-339L-179,339ZM321,339C321,349,313,357,304,357L196,357C187,357,179,349,179,339L179,-339C179,-349,187,-357,196,-357L304,-357C313,-357,321,-349,321,-339L321,339Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM-500,-203C-500,-262,-452,-310,-393,-310C-334,-310,-286,-262,-286,-203C-286,-144,-334,-96,-393,-96C-452,-96,-500,-144,-500,-203ZM357,243C357,253,349,261,339,261L-339,261C-349,261,-357,253,-357,243L-357,136C-357,126,-349,118,-339,118L339,118C349,118,357,126,357,136L357,243ZM393,-96C334,-96,286,-144,286,-203C286,-262,334,-310,393,-310C452,-310,500,-262,500,-203C500,-144,452,-96,393,-96Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM322,15L-166,370C-169,372,-173,373,-176,373C-186,373,-194,365,-194,356L-194,-353C-194,-357,-193,-361,-191,-364C-185,-372,-174,-374,-166,-368L322,-13C323,-12,325,-11,326,-9C331,-2,330,10,322,15Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM-820,-820L-480,-820L-480,820L-820,820L-820,-820ZM820,820L-320,820L-320,-320L820,-320L820,820ZM-320,-480L-320,-820L820,-820L820,-480L-320,-480Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM326,469C326,479,318,487,308,487L-303,487C-313,487,-321,479,-321,469L-321,383C-321,375,-315,367,-307,365C-209,341,-145,256,-145,155C-145,122,-150,90,-158,56L-308,56C-318,56,-326,48,-326,39L-326,-28C-326,-38,-318,-46,-308,-46L-188,-46C-206,-102,-221,-159,-221,-218C-221,-388,-90,-487,117,-487C177,-487,232,-475,274,-458C281,-456,286,-449,286,-442L286,-354C286,-341,274,-333,262,-337C222,-351,175,-360,127,-360C8,-360,-67,-301,-67,-203C-67,-148,-54,-96,-38,-46L212,-46C222,-46,230,-38,230,-28L230,39C230,49,222,57,212,57L-8,57C-1,86,4,117,4,148C4,239,-33,313,-94,352L-94,362L308,362C318,362,326,370,326,380L326,469Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM-500,-203C-500,-262,-452,-310,-393,-310C-334,-310,-286,-262,-286,-203C-286,-144,-334,-96,-393,-96C-452,-96,-500,-144,-500,-203ZM0,404C-191,404,-347,254,-357,66C-358,55,-350,47,-339,47L-232,47C-223,47,-215,54,-214,63C-205,174,-113,261,0,261C113,261,206,174,214,63C215,54,223,47,232,47L339,47C350,47,358,55,357,66C347,254,191,404,0,404ZM393,-96C334,-96,286,-144,286,-203C286,-262,334,-310,393,-310C452,-310,500,-262,500,-203C500,-144,452,-96,393,-96Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM524,644L-644,-524C-608,-568,-568,-608,-524,-644L644,524C608,568,568,608,524,644Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM820,820L-820,820L-820,-820L820,-820L820,820ZM-430,428L-430,620C-430,631,-421,640,-410,640L-290,640C-279,640,-270,631,-270,620L-270,428C-295,436,-322,440,-350,440C-378,440,-405,436,-430,428ZM-270,-68L-270,-620C-270,-631,-279,-640,-290,-640L-410,-640C-421,-640,-430,-631,-430,-620L-430,-68C-405,-76,-378,-80,-350,-80C-322,-80,-295,-76,-270,-68ZM-430,428C-405,436,-378,440,-350,440C-322,440,-295,436,-270,428C-166,394,-90,296,-90,180C-90,64,-166,-34,-270,-68C-295,-76,-322,-80,-350,-80C-378,-80,-405,-76,-430,-68C-534,-34,-610,64,-610,180C-610,296,-534,394,-430,428ZM-430,138C-429,137,-428,135,-427,134L-427,134L-424,129C-424,128,-424,128,-424,128C-423,126,-422,126,-421,124C-421,124,-420,124,-420,123C-419,122,-418,120,-417,119L-416,118L-413,116L-412,114C-411,113,-410,112,-408,111C-406,110,-405,109,-404,108C-403,108,-403,107,-402,107C-401,106,-400,105,-399,104C-399,104,-398,104,-398,104C-396,103,-395,102,-393,101C-393,101,-392,101,-392,100C-391,100,-390,99,-388,98L-387,98C-385,97,-383,96,-382,96C-380,95,-378,94,-376,94C-376,94,-376,94,-375,94C-374,93,-372,93,-371,92C-370,92,-370,92,-370,92C-368,92,-366,92,-364,91C-364,91,-363,91,-363,91C-361,91,-360,91,-358,90L-357,90C-355,90,-353,90,-351,90C-349,90,-347,90,-345,90L-344,90C-342,90,-341,91,-339,91C-339,91,-338,91,-338,91C-336,92,-334,92,-332,92C-332,92,-332,93,-331,92C-330,93,-328,93,-327,94C-326,94,-326,94,-326,94C-324,94,-322,95,-320,96C-318,96,-317,97,-315,98L-314,98C-312,99,-311,100,-310,100C-309,101,-309,101,-309,101C-307,102,-305,103,-304,104C-304,104,-303,104,-303,104C-302,105,-300,106,-300,107C-299,107,-299,108,-298,108C-297,109,-295,110,-294,111C-293,112,-291,113,-290,114L-289,116L-286,118L-285,119C-284,121,-283,122,-282,123C-281,124,-281,124,-281,124C-280,125,-279,127,-278,128C-278,128,-278,129,-278,129L-275,134C-275,134,-275,134,-274,134C-274,135,-273,137,-272,138C-266,151,-262,165,-262,180C-262,195,-266,209,-272,222C-273,223,-274,225,-274,226C-274,226,-274,227,-275,226L-278,231C-278,232,-278,232,-278,232C-279,234,-280,235,-281,236C-281,236,-282,237,-282,237C-283,238,-284,240,-285,241L-286,242L-289,244L-290,246C-291,247,-292,248,-294,249C-296,250,-297,251,-298,252C-299,253,-299,253,-300,253C-301,254,-302,255,-303,256C-303,256,-304,256,-304,256C-306,257,-307,258,-309,259C-309,259,-310,259,-310,260C-311,260,-312,261,-314,262L-315,262C-317,263,-319,264,-320,264C-322,265,-324,266,-326,266C-326,266,-326,266,-327,266C-328,267,-330,267,-331,268C-332,268,-332,268,-332,268C-334,268,-336,269,-338,269C-338,269,-339,269,-339,269C-341,269,-342,269,-344,270L-345,270C-347,270,-349,270,-351,270C-353,270,-355,270,-357,270L-358,270C-360,270,-361,269,-363,269C-363,269,-364,269,-364,269C-366,268,-368,268,-370,268C-370,268,-370,268,-371,268C-372,267,-374,267,-375,266C-376,266,-376,266,-376,266C-378,266,-380,265,-382,264C-384,264,-385,263,-387,262L-388,262C-390,261,-391,260,-392,260C-393,259,-393,259,-393,259C-395,258,-397,257,-398,256C-398,256,-399,256,-399,256C-400,255,-402,254,-402,253C-403,253,-403,252,-404,252C-405,251,-407,250,-408,249C-409,248,-411,247,-412,246L-413,244L-416,242L-417,241C-418,240,-419,238,-420,237C-421,236,-421,236,-421,236C-422,235,-423,234,-424,232C-424,232,-424,232,-424,231L-427,226L-427,226C-428,225,-429,223,-430,222C-436,209,-440,195,-440,180C-440,165,-436,151,-430,138ZM270,68L270,620C270,631,279,640,290,640L410,640C421,640,430,631,430,620L430,68C405,76,378,80,350,80C322,80,295,76,270,68ZM430,-428L430,-620C430,-631,421,-640,410,-640L290,-640C279,-640,270,-631,270,-620L270,-428C295,-436,322,-440,350,-440C378,-440,405,-436,430,-428ZM270,68C295,76,322,80,350,80C378,80,405,76,430,68C534,34,610,-64,610,-180C610,-296,534,-394,430,-428C405,-436,378,-440,350,-440C322,-440,295,-436,270,-428C166,-394,90,-296,90,-180C90,-64,166,34,270,68ZM270,-222C271,-223,272,-225,273,-226L273,-226L276,-231C276,-232,276,-232,276,-232C277,-234,278,-234,279,-236C279,-236,280,-236,280,-237C281,-238,282,-240,283,-241L284,-242L287,-244L288,-246C289,-247,290,-248,292,-249C294,-250,295,-251,296,-252C297,-252,297,-253,298,-253C299,-254,300,-255,301,-256C301,-256,302,-256,302,-256C304,-257,305,-258,307,-259C307,-259,308,-259,308,-260C309,-260,310,-261,312,-262L313,-262C315,-263,317,-264,318,-264C320,-265,322,-266,324,-266C324,-266,324,-266,325,-266C326,-267,328,-267,329,-268C330,-268,330,-268,330,-268C332,-268,334,-268,336,-269C336,-269,337,-269,337,-269C339,-269,340,-269,342,-270L343,-270C345,-270,347,-270,349,-270C351,-270,353,-270,355,-270L356,-270C358,-270,359,-269,361,-269C361,-269,362,-269,362,-269C364,-268,366,-268,368,-268C368,-268,368,-267,369,-268C370,-267,372,-267,373,-266C374,-266,374,-266,374,-266C376,-266,378,-265,380,-264C382,-264,383,-263,385,-262L386,-262C388,-261,389,-260,390,-260C391,-259,391,-259,391,-259C393,-258,395,-257,396,-256C396,-256,397,-256,397,-256C398,-255,400,-254,400,-253C401,-253,401,-252,402,-252C403,-251,405,-250,406,-249C407,-248,409,-247,410,-246L411,-244L414,-242L415,-241C416,-239,417,-238,418,-237C419,-236,419,-236,419,-236C420,-235,421,-233,422,-232C422,-232,422,-231,422,-231L425,-226L425,-226C426,-225,427,-223,428,-222C434,-209,438,-195,438,-180C438,-165,434,-151,428,-138C427,-137,426,-135,425,-134L425,-134L422,-129C422,-128,422,-128,422,-128C421,-126,420,-125,419,-124C419,-124,418,-123,418,-123C417,-122,416,-120,415,-119L414,-118L411,-116L410,-114C409,-113,408,-112,406,-111C404,-110,403,-109,402,-108C401,-107,401,-107,400,-107C399,-106,398,-105,397,-104C397,-104,396,-104,396,-104C394,-103,393,-102,391,-101C391,-101,390,-101,390,-100C389,-100,388,-99,386,-98L385,-98C383,-97,381,-96,380,-96C378,-95,376,-94,374,-94C374,-94,374,-94,373,-94C372,-93,370,-93,369,-92C368,-92,368,-92,368,-92C366,-92,364,-91,362,-91C362,-91,361,-91,361,-91C359,-91,358,-91,356,-90L355,-90C353,-90,351,-90,349,-90C347,-90,345,-90,343,-90L342,-90C340,-90,339,-91,337,-91C337,-91,336,-91,336,-91C334,-92,332,-92,330,-92C330,-92,330,-92,329,-92C328,-93,326,-93,325,-94C324,-94,324,-94,324,-94C322,-94,320,-95,318,-96C316,-96,315,-97,313,-98L312,-98C310,-99,309,-100,308,-100C307,-101,307,-101,307,-101C305,-102,303,-103,302,-104C302,-104,301,-104,301,-104C300,-105,298,-106,298,-107C297,-107,297,-108,296,-108C295,-109,293,-110,292,-111C291,-112,289,-113,288,-114L287,-116L284,-118L283,-119C282,-120,281,-122,280,-123C279,-124,279,-124,279,-124C278,-125,277,-126,276,-128C276,-128,276,-128,276,-129L273,-134L273,-134C272,-135,271,-137,270,-138C264,-151,260,-165,260,-180C260,-195,264,-209,270,-222Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM-71,-482C-71,-492,-63,-500,-54,-500L54,-500C63,-500,71,-492,71,-482L71,125C71,135,63,143,54,143L-54,143C-63,143,-71,135,-71,125L-71,-482ZM0,500C-59,500,-107,452,-107,393C-107,334,-59,286,0,286C59,286,107,334,107,393C107,452,59,500,0,500Z",
  "M10,402C10,414,18,422,29,422L491,422C501,422,510,414,510,402L510,282C510,272,501,262,491,262L29,262C18,262,10,272,10,282L10,402ZM-477,418L3,15C12,7,12,-8,3,-16L-477,-418C-490,-429,-510,-420,-510,-402L-510,-246C-510,-240,-507,-234,-503,-230L-228,0L-503,230C-507,234,-510,240,-510,246L-510,402C-510,420,-490,429,-477,418ZM920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM820,820L-820,820L-820,-820L820,-820L820,820Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM820,820L-820,820L-820,-820L820,-820L820,820ZM-50,-280L410,-280C421,-280,430,-289,430,-300L430,-420C430,-431,421,-440,410,-440L-50,-440C-61,-440,-70,-431,-70,-420L-70,-300C-70,-289,-61,-280,-50,-280ZM-50,80L410,80C421,80,430,71,430,60L430,-60C430,-71,421,-80,410,-80L-50,-80C-61,-80,-70,-71,-70,-60L-70,60C-70,71,-61,80,-50,80ZM-50,440L410,440C421,440,430,431,430,420L430,300C430,289,421,280,410,280L-50,280C-61,280,-70,289,-70,300L-70,420C-70,431,-61,440,-50,440ZM-330,-360ZM-430,-360L-428,-343L-424,-326L-417,-310L-407,-296L-394,-283L-380,-273L-364,-266L-347,-262L-330,-260L-313,-262L-296,-266L-280,-273L-266,-283L-253,-296L-243,-310L-236,-326L-232,-343L-230,-360L-232,-377L-236,-394L-243,-410L-253,-424L-266,-437L-280,-447L-296,-454L-313,-458L-330,-460L-347,-458L-364,-454L-380,-447L-394,-437L-407,-424L-417,-410L-424,-394L-428,-377L-430,-360ZM-330,0ZM-430,0L-428,17L-424,34L-417,50L-407,64L-394,77L-380,87L-364,94L-347,98L-330,100L-313,98L-296,94L-280,87L-266,77L-253,64L-243,50L-236,34L-232,17L-230,0L-232,-17L-236,-34L-243,-50L-253,-64L-266,-77L-280,-87L-296,-94L-313,-98L-330,-100L-347,-98L-364,-94L-380,-87L-394,-77L-407,-64L-417,-50L-424,-34L-428,-17L-430,0ZM-330,360ZM-430,360L-428,377L-424,394L-417,410L-407,424L-394,437L-380,447L-364,454L-347,458L-330,460L-313,458L-296,454L-280,447L-266,437L-253,424L-243,410L-236,394L-232,377L-230,360L-232,343L-236,326L-243,310L-253,296L-266,283L-280,273L-296,266L-313,262L-330,260L-347,262L-364,266L-380,273L-394,283L-407,296L-417,310L-424,326L-428,343L-430,360Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM368,474C365,475,362,475,360,475L221,475C215,475,208,471,205,465L39,110L-159,110L-159,458C-159,467,-167,475,-177,475L-299,475C-309,475,-317,467,-317,458L-317,-458C-317,-467,-309,-475,-299,-475L48,-475C269,-475,370,-342,370,-183C370,-26,273,55,195,83L375,450C380,458,376,469,368,474ZM27,-346L-160,-346L-160,-16L22,-16C141,-16,207,-73,207,-177C207,-290,134,-346,27,-346Z",
  "M0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM372,-449L124,8L262,8C272,8,280,16,280,26L280,93C280,102,272,110,262,110L79,110L79,203L262,203C272,203,280,211,280,221L280,288C280,298,272,306,262,306L79,306L79,458C79,467,71,475,61,475L-60,475C-70,475,-78,467,-78,458L-78,306L-260,306C-270,306,-278,298,-278,288L-278,221C-278,211,-270,203,-260,203L-78,203L-78,110L-260,110C-270,110,-278,102,-278,93L-278,26C-278,16,-270,8,-260,8L-123,8L-372,-449C-377,-458,-373,-469,-365,-473C-362,-475,-359,-476,-356,-476L-221,-476C-214,-476,-208,-472,-205,-466L-3,-64L5,-64L207,-466C210,-472,216,-476,223,-476L356,-476C366,-476,374,-468,374,-458C374,-455,373,-452,372,-449Z",
  "M951,-531C920,-603,876,-667,820,-722C763,-777,698,-820,625,-851C550,-882,470,-898,388,-898C274,-898,163,-866,66,-807C43,-793,21,-778,0,-761C-21,-778,-43,-793,-66,-807C-163,-866,-274,-898,-388,-898C-470,-898,-550,-882,-625,-851C-698,-821,-763,-777,-820,-722C-876,-667,-920,-603,-951,-531C-984,-456,-1000,-376,-1000,-295C-1000,-218,-984,-137,-953,-56C-927,13,-889,84,-841,155C-766,268,-661,386,-531,506C-317,704,-104,841,-95,847L-40,882C-16,898,16,898,40,882L95,847C104,841,316,704,531,506C661,386,765,268,841,155C889,84,927,13,953,-56C984,-137,1000,-218,1000,-295C1000,-376,984,-456,951,-531Z",
  "M799,14L-14,14L-14,-799C-14,-809,-22,-817,-32,-817L-91,-817C-214,-817,-333,-793,-445,-746C-553,-700,-650,-635,-734,-551C-817,-468,-883,-371,-928,-263C-976,-150,-1000,-31,-1000,91C-1000,214,-976,333,-928,445C-883,553,-817,650,-734,734C-650,817,-553,883,-445,928C-333,976,-214,1000,-91,1000C31,1000,151,976,262,929C370,883,468,817,551,734C635,650,700,553,746,445C793,333,818,214,818,91L818,32C817,22,809,14,799,14ZM999,-112L993,-176C974,-386,881,-583,731,-732C582,-881,384,-974,174,-993L110,-999C99,-1000,90,-992,90,-981L90,-109C90,-99,98,-90,108,-90L981,-93C991,-93,1000,-102,999,-112Z",
  "M-580,600L-380,600C-369,600,-360,591,-360,580L-360,-580C-360,-591,-369,-600,-380,-600L-580,-600C-591,-600,-600,-591,-600,-580L-600,580C-600,591,-591,600,-580,600ZM-100,-100L100,-100C111,-100,120,-109,120,-120L120,-580C120,-591,111,-600,100,-600L-100,-600C-111,-600,-120,-591,-120,-580L-120,-120C-120,-109,-111,-100,-100,-100ZM380,80L580,80C591,80,600,71,600,60L600,-580C600,-591,591,-600,580,-600L380,-600C369,-600,360,-591,360,-580L360,60C360,71,369,80,380,80ZM920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM820,820L-820,820L-820,-820L820,-820L820,820Z",
  "M921,-282C871,-401,799,-508,707,-600C615,-692,508,-764,389,-814C266,-867,135,-893,0,-893C-135,-893,-266,-867,-389,-814C-508,-764,-615,-692,-707,-600C-799,-508,-871,-401,-921,-282C-974,-159,-1000,-28,-1000,107C-1000,403,-870,682,-643,873L-639,876C-626,887,-610,893,-593,893L594,893C610,893,627,887,640,876L643,873C870,682,1000,403,1000,107C1000,-28,973,-159,921,-282ZM-67,-625C-67,-635,-59,-643,-49,-643L49,-643C59,-643,67,-635,67,-625L67,-446C67,-437,59,-429,49,-429L-49,-429C-59,-429,-67,-437,-67,-446L-67,-625ZM-540,156C-540,166,-548,174,-558,174L-737,174C-746,174,-754,166,-754,156L-754,58C-754,48,-746,40,-737,40L-558,40C-548,40,-540,48,-540,58L-540,156ZM-338,-300L-407,-231C-414,-224,-425,-224,-432,-231L-559,-357C-566,-364,-566,-375,-559,-382L-489,-452C-482,-459,-471,-459,-464,-452L-338,-325C-331,-319,-331,-307,-338,-300ZM312,-114L123,75C135,117,124,163,91,196C42,245,-37,245,-86,196C-135,147,-135,68,-86,19C-53,-14,-7,-25,35,-13L224,-202C231,-209,242,-209,249,-202L312,-139C319,-132,319,-121,312,-114ZM408,-231L339,-300C332,-307,332,-318,339,-325L465,-452C472,-458,483,-458,490,-452L560,-382C567,-375,567,-364,560,-357L433,-231C426,-224,415,-224,408,-231ZM746,156C746,166,738,174,728,174L549,174C539,174,531,166,531,156L531,58C531,48,539,40,549,40L728,40C738,40,746,48,746,58L746,156Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM820,160L40,160L40,-160L820,-160L820,160ZM820,820L-820,820L-820,-820L820,-820L820,-320L-40,-320C-84,-320,-120,-284,-120,-240L-120,240C-120,284,-84,320,-40,320L820,320L820,820ZM270,0ZM170,0L172,17L176,34L183,50L193,64L206,77L220,87L236,94L253,98L270,100L287,98L304,94L320,87L334,77L347,64L357,50L364,34L368,17L370,0L368,-17L364,-34L357,-50L347,-64L334,-77L320,-87L304,-94L287,-98L270,-100L253,-98L236,-94L220,-87L206,-77L193,-64L183,-50L176,-34L172,-17L170,0Z",
  "M920,-388C870,-507,798,-615,706,-707C614,-800,506,-872,387,-922C264,-974,134,-1000,0,-1000L-4,-1000C-140,-999,-270,-973,-393,-920C-512,-869,-618,-797,-709,-704C-800,-612,-872,-505,-921,-386C-973,-262,-998,-131,-998,5C-997,160,-960,313,-891,451L-891,790C-891,847,-845,893,-788,893L-450,893C-312,962,-159,999,-4,1000L0,1000C134,1000,263,974,385,923C504,874,611,802,703,711C795,620,867,513,918,394C971,271,997,140,998,4C998,-131,972,-263,920,-388ZM-446,107C-504,107,-552,59,-552,0C-552,-59,-504,-107,-446,-107C-387,-107,-339,-59,-339,0C-339,59,-386,107,-446,107ZM0,107C-59,107,-107,59,-107,0C-107,-59,-59,-107,0,-107C59,-107,107,-59,107,0C107,59,59,107,0,107ZM446,107C387,107,339,59,339,0C339,-59,387,-107,446,-107C504,-107,552,-59,552,0C552,59,504,107,446,107Z",
  "M-652,-312L-480,-312L-480,-140C-480,-136,-476,-132,-470,-132L-350,-132C-344,-132,-340,-136,-340,-141L-340,-312L-168,-312C-164,-312,-160,-317,-160,-322L-160,-442C-160,-448,-164,-452,-168,-452L-340,-452L-340,-624C-340,-629,-344,-632,-350,-632L-470,-632C-476,-632,-480,-629,-480,-624L-480,-452L-652,-452C-656,-452,-660,-448,-660,-442L-660,-322C-660,-317,-656,-312,-652,-312ZM168,-312L652,-312C656,-312,660,-317,660,-322L660,-442C660,-448,656,-452,652,-452L168,-452C164,-452,160,-448,160,-442L160,-322C160,-317,164,-312,168,-312ZM168,350L652,350C656,350,660,346,660,340L660,220C660,214,656,210,652,210L168,210C164,210,160,214,160,220L160,340C160,346,164,350,168,350ZM168,610L652,610C656,610,660,606,660,600L660,480C660,474,656,470,652,470L168,470C164,470,160,474,160,480L160,600C160,606,164,610,168,610ZM-321,408L-168,220C-158,207,-166,188,-183,188L-310,188C-316,188,-321,190,-325,195L-410,299L-495,195C-498,190,-504,188,-509,188L-637,188C-653,188,-662,207,-652,220L-498,408L-655,600C-666,612,-657,632,-641,632L-514,632C-508,632,-502,630,-499,625L-410,516L-322,625C-318,630,-312,632,-307,632L-180,632C-163,632,-154,612,-165,600L-321,408ZM920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM830,830L-830,830L-830,-830L830,-830L830,830Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM820,820L-820,820L-820,-820L820,-820L820,820ZM-518,30L-391,30C-382,30,-374,22,-374,13L-374,-184C-374,-234,-334,-273,-286,-273L229,-273L229,-140C229,-126,245,-118,256,-126L529,-341C538,-348,538,-361,529,-368L256,-582C245,-590,229,-582,229,-568L229,-435L-286,-435C-424,-435,-535,-323,-535,-185L-535,12C-535,22,-528,30,-518,30ZM-528,367L-256,582C-245,590,-228,582,-228,568L-228,435L286,435C424,435,535,323,535,184L535,-13C535,-22,528,-30,518,-30L391,-30C382,-30,374,-22,374,-13L374,184C374,234,334,274,286,274L-228,274L-228,140C-228,126,-245,118,-256,127L-528,341C-537,347,-537,360,-528,367Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM820,820L-820,820L-820,-820L820,-820L820,820Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM3,15L-477,418C-490,429,-510,420,-510,402L-510,246C-510,240,-507,234,-503,230L-228,0L-503,-230C-507,-234,-510,-240,-510,-246L-510,-402C-510,-420,-490,-429,-477,-418L3,-16C12,-8,12,7,3,15ZM510,402C510,414,501,422,491,422L29,422C18,422,10,414,10,402L10,282C10,272,18,262,29,262L491,262C501,262,510,272,510,282L510,402Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM820,820L-820,820L-820,-820L820,-820L820,820ZM-70,-365L70,-365C81,-365,90,-374,90,-385L90,-525C90,-536,81,-545,70,-545L-70,-545C-81,-545,-90,-536,-90,-525L-90,-385C-90,-374,-81,-365,-70,-365ZM-525,90L-385,90C-374,90,-365,81,-365,70L-365,-70C-365,-81,-374,-90,-385,-90L-525,-90C-536,-90,-545,-81,-545,-70L-545,70C-545,81,-536,90,-525,90ZM385,90L525,90C536,90,545,81,545,70L545,-70C545,-81,536,-90,525,-90L385,-90C374,-90,365,-81,365,-70L365,70C365,81,374,90,385,90ZM-70,90L70,90C81,90,90,81,90,70L90,-70C90,-81,81,-90,70,-90L-70,-90C-81,-90,-90,-81,-90,-70L-90,70C-90,81,-81,90,-70,90ZM-70,545L70,545C81,545,90,536,90,525L90,385C90,374,81,365,70,365L-70,365C-81,365,-90,374,-90,385L-90,525C-90,536,-81,545,-70,545Z",
  "M978,-1000L-978,-1000C-990,-1000,-1000,-990,-1000,-978L-1000,-826C-1000,-814,-990,-804,-978,-804L978,-804C990,-804,1000,-814,1000,-826L1000,-978C1000,-990,990,-1000,978,-1000ZM-826,-549L-978,-549C-990,-549,-1000,-539,-1000,-527L-1000,-375C-1000,-363,-990,-353,-978,-353L-826,-353C-814,-353,-804,-363,-804,-375L-804,-527C-804,-539,-814,-549,-826,-549ZM-826,804L-978,804C-990,804,-1000,814,-1000,826L-1000,978C-1000,990,-990,1000,-978,1000L-826,1000C-814,1000,-804,990,-804,978L-804,826C-804,814,-814,804,-826,804ZM-826,-98L-978,-98C-990,-98,-1000,-88,-1000,-76L-1000,76C-1000,88,-990,98,-978,98L-826,98C-814,98,-804,88,-804,76L-804,-76C-804,-88,-814,-98,-826,-98ZM-826,353L-978,353C-990,353,-1000,363,-1000,375L-1000,527C-1000,539,-990,549,-978,549L-826,549C-814,549,-804,539,-804,527L-804,375C-804,363,-814,353,-826,353ZM-375,-98L-527,-98C-539,-98,-549,-88,-549,-76L-549,76C-549,88,-539,98,-527,98L-375,98C-363,98,-353,88,-353,76L-353,-76C-353,-88,-363,-98,-375,-98ZM-375,804L-527,804C-539,804,-549,814,-549,826L-549,978C-549,990,-539,1000,-527,1000L-375,1000C-363,1000,-353,990,-353,978L-353,826C-353,814,-363,804,-375,804ZM527,804L375,804C363,804,353,814,353,826L353,978C353,990,363,1000,375,1000L527,1000C539,1000,549,990,549,978L549,826C549,814,539,804,527,804ZM527,-98L375,-98C363,-98,353,-88,353,-76L353,76C353,88,363,98,375,98L527,98C539,98,549,88,549,76L549,-76C549,-88,539,-98,527,-98ZM978,-98L826,-98C814,-98,804,-88,804,-76L804,76C804,88,814,98,826,98L978,98C990,98,1000,88,1000,76L1000,-76C1000,-88,990,-98,978,-98ZM76,-98L-76,-98C-88,-98,-98,-88,-98,-76L-98,76C-98,88,-88,98,-76,98L76,98C88,98,98,88,98,76L98,-76C98,-88,88,-98,76,-98ZM978,804L826,804C814,804,804,814,804,826L804,978C804,990,814,1000,826,1000L978,1000C990,1000,1000,990,1000,978L1000,826C1000,814,990,804,978,804ZM76,804L-76,804C-88,804,-98,814,-98,826L-98,978C-98,990,-88,1000,-76,1000L76,1000C88,1000,98,990,98,978L98,826C98,814,88,804,76,804ZM978,-549L826,-549C814,-549,804,-539,804,-527L804,-375C804,-363,814,-353,826,-353L978,-353C990,-353,1000,-363,1000,-375L1000,-527C1000,-539,990,-549,978,-549ZM76,-549L-76,-549C-88,-549,-98,-539,-98,-527L-98,-375C-98,-363,-88,-353,-76,-353L76,-353C88,-353,98,-363,98,-375L98,-527C98,-539,88,-549,76,-549ZM978,353L826,353C814,353,804,363,804,375L804,527C804,539,814,549,826,549L978,549C990,549,1000,539,1000,527L1000,375C1000,363,990,353,978,353ZM76,353L-76,353C-88,353,-98,363,-98,375L-98,527C-98,539,-88,549,-76,549L76,549C88,549,98,539,98,527L98,375C98,363,88,353,76,353Z",
  "M978,804L-978,804C-990,804,-1000,814,-1000,826L-1000,978C-1000,990,-990,1000,-978,1000L978,1000C990,1000,1000,990,1000,978L1000,826C1000,814,990,804,978,804ZM-978,549L-826,549C-814,549,-804,539,-804,527L-804,375C-804,363,-814,353,-826,353L-978,353C-990,353,-1000,363,-1000,375L-1000,527C-1000,539,-990,549,-978,549ZM-978,-804L-826,-804C-814,-804,-804,-814,-804,-826L-804,-978C-804,-990,-814,-1000,-826,-1000L-978,-1000C-990,-1000,-1000,-990,-1000,-978L-1000,-826C-1000,-814,-990,-804,-978,-804ZM-978,98L-826,98C-814,98,-804,88,-804,76L-804,-76C-804,-88,-814,-98,-826,-98L-978,-98C-990,-98,-1000,-88,-1000,-76L-1000,76C-1000,88,-990,98,-978,98ZM-978,-353L-826,-353C-814,-353,-804,-363,-804,-375L-804,-527C-804,-539,-814,-549,-826,-549L-978,-549C-990,-549,-1000,-539,-1000,-527L-1000,-375C-1000,-363,-990,-353,-978,-353ZM-527,98L-375,98C-363,98,-353,88,-353,76L-353,-76C-353,-88,-363,-98,-375,-98L-527,-98C-539,-98,-549,-88,-549,-76L-549,76C-549,88,-539,98,-527,98ZM-527,-804L-375,-804C-363,-804,-353,-814,-353,-826L-353,-978C-353,-990,-363,-1000,-375,-1000L-527,-1000C-539,-1000,-549,-990,-549,-978L-549,-826C-549,-814,-539,-804,-527,-804ZM375,-804L527,-804C539,-804,549,-814,549,-826L549,-978C549,-990,539,-1000,527,-1000L375,-1000C363,-1000,353,-990,353,-978L353,-826C353,-814,363,-804,375,-804ZM375,98L527,98C539,98,549,88,549,76L549,-76C549,-88,539,-98,527,-98L375,-98C363,-98,353,-88,353,-76L353,76C353,88,363,98,375,98ZM978,-98L826,-98C814,-98,804,-88,804,-76L804,76C804,88,814,98,826,98L978,98C990,98,1000,88,1000,76L1000,-76C1000,-88,990,-98,978,-98ZM-76,98L76,98C88,98,98,88,98,76L98,-76C98,-88,88,-98,76,-98L-76,-98C-88,-98,-98,-88,-98,-76L-98,76C-98,88,-88,98,-76,98ZM978,-1000L826,-1000C814,-1000,804,-990,804,-978L804,-826C804,-814,814,-804,826,-804L978,-804C990,-804,1000,-814,1000,-826L1000,-978C1000,-990,990,-1000,978,-1000ZM-76,-804L76,-804C88,-804,98,-814,98,-826L98,-978C98,-990,88,-1000,76,-1000L-76,-1000C-88,-1000,-98,-990,-98,-978L-98,-826C-98,-814,-88,-804,-76,-804ZM978,353L826,353C814,353,804,363,804,375L804,527C804,539,814,549,826,549L978,549C990,549,1000,539,1000,527L1000,375C1000,363,990,353,978,353ZM-76,549L76,549C88,549,98,539,98,527L98,375C98,363,88,353,76,353L-76,353C-88,353,-98,363,-98,375L-98,527C-98,539,-88,549,-76,549ZM978,-549L826,-549C814,-549,804,-539,804,-527L804,-375C804,-363,814,-353,826,-353L978,-353C990,-353,1000,-363,1000,-375L1000,-527C1000,-539,990,-549,978,-549ZM-76,-353L76,-353C88,-353,98,-363,98,-375L98,-527C98,-539,88,-549,76,-549L-76,-549C-88,-549,-98,-539,-98,-527L-98,-375C-98,-363,-88,-353,-76,-353Z",
  "M-826,-1000L-978,-1000C-990,-1000,-1000,-990,-1000,-978L-1000,978C-1000,990,-990,1000,-978,1000L-826,1000C-814,1000,-804,990,-804,978L-804,-978C-804,-990,-814,-1000,-826,-1000ZM-375,-1000L-527,-1000C-539,-1000,-549,-990,-549,-978L-549,-826C-549,-814,-539,-804,-527,-804L-375,-804C-363,-804,-353,-814,-353,-826L-353,-978C-353,-990,-363,-1000,-375,-1000ZM978,-1000L826,-1000C814,-1000,804,-990,804,-978L804,-826C804,-814,814,-804,826,-804L978,-804C990,-804,1000,-814,1000,-826L1000,-978C1000,-990,990,-1000,978,-1000ZM76,-1000L-76,-1000C-88,-1000,-98,-990,-98,-978L-98,-826C-98,-814,-88,-804,-76,-804L76,-804C88,-804,98,-814,98,-826L98,-978C98,-990,88,-1000,76,-1000ZM527,-1000L375,-1000C363,-1000,353,-990,353,-978L353,-826C353,-814,363,-804,375,-804L527,-804C539,-804,549,-814,549,-826L549,-978C549,-990,539,-1000,527,-1000ZM76,-549L-76,-549C-88,-549,-98,-539,-98,-527L-98,-375C-98,-363,-88,-353,-76,-353L76,-353C88,-353,98,-363,98,-375L98,-527C98,-539,88,-549,76,-549ZM978,-549L826,-549C814,-549,804,-539,804,-527L804,-375C804,-363,814,-353,826,-353L978,-353C990,-353,1000,-363,1000,-375L1000,-527C1000,-539,990,-549,978,-549ZM978,353L826,353C814,353,804,363,804,375L804,527C804,539,814,549,826,549L978,549C990,549,1000,539,1000,527L1000,375C1000,363,990,353,978,353ZM76,353L-76,353C-88,353,-98,363,-98,375L-98,527C-98,539,-88,549,-76,549L76,549C88,549,98,539,98,527L98,375C98,363,88,353,76,353ZM76,804L-76,804C-88,804,-98,814,-98,826L-98,978C-98,990,-88,1000,-76,1000L76,1000C88,1000,98,990,98,978L98,826C98,814,88,804,76,804ZM76,-98L-76,-98C-88,-98,-98,-88,-98,-76L-98,76C-98,88,-88,98,-76,98L76,98C88,98,98,88,98,76L98,-76C98,-88,88,-98,76,-98ZM978,804L826,804C814,804,804,814,804,826L804,978C804,990,814,1000,826,1000L978,1000C990,1000,1000,990,1000,978L1000,826C1000,814,990,804,978,804ZM978,-98L826,-98C814,-98,804,-88,804,-76L804,76C804,88,814,98,826,98L978,98C990,98,1000,88,1000,76L1000,-76C1000,-88,990,-98,978,-98ZM-375,804L-527,804C-539,804,-549,814,-549,826L-549,978C-549,990,-539,1000,-527,1000L-375,1000C-363,1000,-353,990,-353,978L-353,826C-353,814,-363,804,-375,804ZM-375,-98L-527,-98C-539,-98,-549,-88,-549,-76L-549,76C-549,88,-539,98,-527,98L-375,98C-363,98,-353,88,-353,76L-353,-76C-353,-88,-363,-98,-375,-98ZM527,804L375,804C363,804,353,814,353,826L353,978C353,990,363,1000,375,1000L527,1000C539,1000,549,990,549,978L549,826C549,814,539,804,527,804ZM527,-98L375,-98C363,-98,353,-88,353,-76L353,76C353,88,363,98,375,98L527,98C539,98,549,88,549,76L549,-76C549,-88,539,-98,527,-98Z",
  "M978,-1000L826,-1000C814,-1000,804,-990,804,-978L804,978C804,990,814,1000,826,1000L978,1000C990,1000,1000,990,1000,978L1000,-978C1000,-990,990,-1000,978,-1000ZM527,-1000L375,-1000C363,-1000,353,-990,353,-978L353,-826C353,-814,363,-804,375,-804L527,-804C539,-804,549,-814,549,-826L549,-978C549,-990,539,-1000,527,-1000ZM-826,-1000L-978,-1000C-990,-1000,-1000,-990,-1000,-978L-1000,-826C-1000,-814,-990,-804,-978,-804L-826,-804C-814,-804,-804,-814,-804,-826L-804,-978C-804,-990,-814,-1000,-826,-1000ZM76,-1000L-76,-1000C-88,-1000,-98,-990,-98,-978L-98,-826C-98,-814,-88,-804,-76,-804L76,-804C88,-804,98,-814,98,-826L98,-978C98,-990,88,-1000,76,-1000ZM-375,-1000L-527,-1000C-539,-1000,-549,-990,-549,-978L-549,-826C-549,-814,-539,-804,-527,-804L-375,-804C-363,-804,-353,-814,-353,-826L-353,-978C-353,-990,-363,-1000,-375,-1000ZM76,-549L-76,-549C-88,-549,-98,-539,-98,-527L-98,-375C-98,-363,-88,-353,-76,-353L76,-353C88,-353,98,-363,98,-375L98,-527C98,-539,88,-549,76,-549ZM-826,-549L-978,-549C-990,-549,-1000,-539,-1000,-527L-1000,-375C-1000,-363,-990,-353,-978,-353L-826,-353C-814,-353,-804,-363,-804,-375L-804,-527C-804,-539,-814,-549,-826,-549ZM-826,353L-978,353C-990,353,-1000,363,-1000,375L-1000,527C-1000,539,-990,549,-978,549L-826,549C-814,549,-804,539,-804,527L-804,375C-804,363,-814,353,-826,353ZM76,353L-76,353C-88,353,-98,363,-98,375L-98,527C-98,539,-88,549,-76,549L76,549C88,549,98,539,98,527L98,375C98,363,88,353,76,353ZM76,804L-76,804C-88,804,-98,814,-98,826L-98,978C-98,990,-88,1000,-76,1000L76,1000C88,1000,98,990,98,978L98,826C98,814,88,804,76,804ZM76,-98L-76,-98C-88,-98,-98,-88,-98,-76L-98,76C-98,88,-88,98,-76,98L76,98C88,98,98,88,98,76L98,-76C98,-88,88,-98,76,-98ZM-826,804L-978,804C-990,804,-1000,814,-1000,826L-1000,978C-1000,990,-990,1000,-978,1000L-826,1000C-814,1000,-804,990,-804,978L-804,826C-804,814,-814,804,-826,804ZM-826,-98L-978,-98C-990,-98,-1000,-88,-1000,-76L-1000,76C-1000,88,-990,98,-978,98L-826,98C-814,98,-804,88,-804,76L-804,-76C-804,-88,-814,-98,-826,-98ZM527,804L375,804C363,804,353,814,353,826L353,978C353,990,363,1000,375,1000L527,1000C539,1000,549,990,549,978L549,826C549,814,539,804,527,804ZM527,-98L375,-98C363,-98,353,-88,353,-76L353,76C353,88,363,98,375,98L527,98C539,98,549,88,549,76L549,-76C549,-88,539,-98,527,-98ZM-375,804L-527,804C-539,804,-549,814,-549,826L-549,978C-549,990,-539,1000,-527,1000L-375,1000C-363,1000,-353,990,-353,978L-353,826C-353,814,-363,804,-375,804ZM-375,-98L-527,-98C-539,-98,-549,-88,-549,-76L-549,76C-549,88,-539,98,-527,98L-375,98C-363,98,-353,88,-353,76L-353,-76C-353,-88,-363,-98,-375,-98Z",
  "M978,-98L98,-98L98,-1000L-98,-1000L-98,-98L-978,-98C-990,-98,-1000,-88,-1000,-76L-1000,76C-1000,88,-990,98,-978,98L-98,98L-98,1000L98,1000L98,98L978,98C990,98,1000,88,1000,76L1000,-76C1000,-88,990,-98,978,-98ZM978,-549L826,-549C814,-549,804,-539,804,-527L804,-375C804,-363,814,-353,826,-353L978,-353C990,-353,1000,-363,1000,-375L1000,-527C1000,-539,990,-549,978,-549ZM978,804L826,804C814,804,804,814,804,826L804,978C804,990,814,1000,826,1000L978,1000C990,1000,1000,990,1000,978L1000,826C1000,814,990,804,978,804ZM978,-1000L826,-1000C814,-1000,804,-990,804,-978L804,-826C804,-814,814,-804,826,-804L978,-804C990,-804,1000,-814,1000,-826L1000,-978C1000,-990,990,-1000,978,-1000ZM978,353L826,353C814,353,804,363,804,375L804,527C804,539,814,549,826,549L978,549C990,549,1000,539,1000,527L1000,375C1000,363,990,353,978,353ZM375,-804L527,-804C539,-804,549,-814,549,-826L549,-978C549,-990,539,-1000,527,-1000L375,-1000C363,-1000,353,-990,353,-978L353,-826C353,-814,363,-804,375,-804ZM527,804L375,804C363,804,353,814,353,826L353,978C353,990,363,1000,375,1000L527,1000C539,1000,549,990,549,978L549,826C549,814,539,804,527,804ZM-375,804L-527,804C-539,804,-549,814,-549,826L-549,978C-549,990,-539,1000,-527,1000L-375,1000C-363,1000,-353,990,-353,978L-353,826C-353,814,-363,804,-375,804ZM-527,-804L-375,-804C-363,-804,-353,-814,-353,-826L-353,-978C-353,-990,-363,-1000,-375,-1000L-527,-1000C-539,-1000,-549,-990,-549,-978L-549,-826C-549,-814,-539,-804,-527,-804ZM-978,-804L-826,-804C-814,-804,-804,-814,-804,-826L-804,-978C-804,-990,-814,-1000,-826,-1000L-978,-1000C-990,-1000,-1000,-990,-1000,-978L-1000,-826C-1000,-814,-990,-804,-978,-804ZM-826,804L-978,804C-990,804,-1000,814,-1000,826L-1000,978C-1000,990,-990,1000,-978,1000L-826,1000C-814,1000,-804,990,-804,978L-804,826C-804,814,-814,804,-826,804ZM-978,-353L-826,-353C-814,-353,-804,-363,-804,-375L-804,-527C-804,-539,-814,-549,-826,-549L-978,-549C-990,-549,-1000,-539,-1000,-527L-1000,-375C-1000,-363,-990,-353,-978,-353ZM-826,353L-978,353C-990,353,-1000,363,-1000,375L-1000,527C-1000,539,-990,549,-978,549L-826,549C-814,549,-804,539,-804,527L-804,375C-804,363,-814,353,-826,353Z",
  "M920,-820L500,-820L500,-980C500,-991,491,-1000,480,-1000L340,-1000C329,-1000,320,-991,320,-980L320,-820L-320,-820L-320,-980C-320,-991,-329,-1000,-340,-1000L-480,-1000C-491,-1000,-500,-991,-500,-980L-500,-820L-920,-820C-964,-820,-1000,-784,-1000,-740L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-740C1000,-784,964,-820,920,-820ZM341,-213L122,190L236,190C250,190,261,201,261,215L261,268C261,282,250,293,236,293L77,293L77,367L236,367C250,367,261,378,261,392L261,446C261,459,250,470,236,470L77,470L77,600C77,614,66,625,52,625L-51,625C-65,625,-76,614,-76,600L-76,470L-234,470C-248,470,-259,459,-259,446L-259,392C-259,378,-248,367,-234,367L-76,367L-76,293L-234,293C-248,293,-259,282,-259,268L-259,215C-259,201,-248,190,-234,190L-121,190L-341,-213C-347,-225,-343,-240,-331,-247C-327,-249,-323,-250,-319,-250L-204,-250C-194,-250,-186,-245,-182,-236L1,124L184,-236C188,-245,197,-250,206,-250L318,-250C332,-250,344,-239,344,-225C344,-221,343,-217,341,-213Z",
  "M978,-98L-978,-98C-990,-98,-1000,-88,-1000,-76L-1000,76C-1000,88,-990,98,-978,98L978,98C990,98,1000,88,1000,76L1000,-76C1000,-88,990,-98,978,-98ZM978,-549L826,-549C814,-549,804,-539,804,-527L804,-375C804,-363,814,-353,826,-353L978,-353C990,-353,1000,-363,1000,-375L1000,-527C1000,-539,990,-549,978,-549ZM978,804L826,804C814,804,804,814,804,826L804,978C804,990,814,1000,826,1000L978,1000C990,1000,1000,990,1000,978L1000,826C1000,814,990,804,978,804ZM978,-1000L826,-1000C814,-1000,804,-990,804,-978L804,-826C804,-814,814,-804,826,-804L978,-804C990,-804,1000,-814,1000,-826L1000,-978C1000,-990,990,-1000,978,-1000ZM978,353L826,353C814,353,804,363,804,375L804,527C804,539,814,549,826,549L978,549C990,549,1000,539,1000,527L1000,375C1000,363,990,353,978,353ZM375,-804L527,-804C539,-804,549,-814,549,-826L549,-978C549,-990,539,-1000,527,-1000L375,-1000C363,-1000,353,-990,353,-978L353,-826C353,-814,363,-804,375,-804ZM527,804L375,804C363,804,353,814,353,826L353,978C353,990,363,1000,375,1000L527,1000C539,1000,549,990,549,978L549,826C549,814,539,804,527,804ZM-375,804L-527,804C-539,804,-549,814,-549,826L-549,978C-549,990,-539,1000,-527,1000L-375,1000C-363,1000,-353,990,-353,978L-353,826C-353,814,-363,804,-375,804ZM-527,-804L-375,-804C-363,-804,-353,-814,-353,-826L-353,-978C-353,-990,-363,-1000,-375,-1000L-527,-1000C-539,-1000,-549,-990,-549,-978L-549,-826C-549,-814,-539,-804,-527,-804ZM-978,-804L-826,-804C-814,-804,-804,-814,-804,-826L-804,-978C-804,-990,-814,-1000,-826,-1000L-978,-1000C-990,-1000,-1000,-990,-1000,-978L-1000,-826C-1000,-814,-990,-804,-978,-804ZM-76,-804L76,-804C88,-804,98,-814,98,-826L98,-978C98,-990,88,-1000,76,-1000L-76,-1000C-88,-1000,-98,-990,-98,-978L-98,-826C-98,-814,-88,-804,-76,-804ZM-826,804L-978,804C-990,804,-1000,814,-1000,826L-1000,978C-1000,990,-990,1000,-978,1000L-826,1000C-814,1000,-804,990,-804,978L-804,826C-804,814,-814,804,-826,804ZM76,804L-76,804C-88,804,-98,814,-98,826L-98,978C-98,990,-88,1000,-76,1000L76,1000C88,1000,98,990,98,978L98,826C98,814,88,804,76,804ZM-978,-353L-826,-353C-814,-353,-804,-363,-804,-375L-804,-527C-804,-539,-814,-549,-826,-549L-978,-549C-990,-549,-1000,-539,-1000,-527L-1000,-375C-1000,-363,-990,-353,-978,-353ZM-76,-353L76,-353C88,-353,98,-363,98,-375L98,-527C98,-539,88,-549,76,-549L-76,-549C-88,-549,-98,-539,-98,-527L-98,-375C-98,-363,-88,-353,-76,-353ZM-826,353L-978,353C-990,353,-1000,363,-1000,375L-1000,527C-1000,539,-990,549,-978,549L-826,549C-814,549,-804,539,-804,527L-804,375C-804,363,-814,353,-826,353ZM76,353L-76,353C-88,353,-98,363,-98,375L-98,527C-98,539,-88,549,-76,549L76,549C88,549,98,539,98,527L98,375C98,363,88,353,76,353Z",
  "M920,-820L500,-820L500,-980C500,-991,491,-1000,480,-1000L340,-1000C329,-1000,320,-991,320,-980L320,-820L-320,-820L-320,-980C-320,-991,-329,-1000,-340,-1000L-480,-1000C-491,-1000,-500,-991,-500,-980L-500,-820L-920,-820C-964,-820,-1000,-784,-1000,-740L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-740C1000,-784,964,-820,920,-820ZM456,-198L-75,534C-91,556,-124,556,-140,534L-456,98C-466,85,-456,67,-440,67L-302,67C-289,67,-277,73,-270,83L-108,306L270,-214C277,-224,289,-230,302,-230L440,-230C456,-230,466,-212,456,-198Z",
  "M76,-1000L-76,-1000C-88,-1000,-98,-990,-98,-978L-98,978C-98,990,-88,1000,-76,1000L76,1000C88,1000,98,990,98,978L98,-978C98,-990,88,-1000,76,-1000ZM-375,-1000L-527,-1000C-539,-1000,-549,-990,-549,-978L-549,-826C-549,-814,-539,-804,-527,-804L-375,-804C-363,-804,-353,-814,-353,-826L-353,-978C-353,-990,-363,-1000,-375,-1000ZM978,-1000L826,-1000C814,-1000,804,-990,804,-978L804,-826C804,-814,814,-804,826,-804L978,-804C990,-804,1000,-814,1000,-826L1000,-978C1000,-990,990,-1000,978,-1000ZM-826,-1000L-978,-1000C-990,-1000,-1000,-990,-1000,-978L-1000,-826C-1000,-814,-990,-804,-978,-804L-826,-804C-814,-804,-804,-814,-804,-826L-804,-978C-804,-990,-814,-1000,-826,-1000ZM527,-1000L375,-1000C363,-1000,353,-990,353,-978L353,-826C353,-814,363,-804,375,-804L527,-804C539,-804,549,-814,549,-826L549,-978C549,-990,539,-1000,527,-1000ZM-826,-549L-978,-549C-990,-549,-1000,-539,-1000,-527L-1000,-375C-1000,-363,-990,-353,-978,-353L-826,-353C-814,-353,-804,-363,-804,-375L-804,-527C-804,-539,-814,-549,-826,-549ZM978,-549L826,-549C814,-549,804,-539,804,-527L804,-375C804,-363,814,-353,826,-353L978,-353C990,-353,1000,-363,1000,-375L1000,-527C1000,-539,990,-549,978,-549ZM978,353L826,353C814,353,804,363,804,375L804,527C804,539,814,549,826,549L978,549C990,549,1000,539,1000,527L1000,375C1000,363,990,353,978,353ZM-826,353L-978,353C-990,353,-1000,363,-1000,375L-1000,527C-1000,539,-990,549,-978,549L-826,549C-814,549,-804,539,-804,527L-804,375C-804,363,-814,353,-826,353ZM-826,804L-978,804C-990,804,-1000,814,-1000,826L-1000,978C-1000,990,-990,1000,-978,1000L-826,1000C-814,1000,-804,990,-804,978L-804,826C-804,814,-814,804,-826,804ZM-826,-98L-978,-98C-990,-98,-1000,-88,-1000,-76L-1000,76C-1000,88,-990,98,-978,98L-826,98C-814,98,-804,88,-804,76L-804,-76C-804,-88,-814,-98,-826,-98ZM978,804L826,804C814,804,804,814,804,826L804,978C804,990,814,1000,826,1000L978,1000C990,1000,1000,990,1000,978L1000,826C1000,814,990,804,978,804ZM978,-98L826,-98C814,-98,804,-88,804,-76L804,76C804,88,814,98,826,98L978,98C990,98,1000,88,1000,76L1000,-76C1000,-88,990,-98,978,-98ZM-375,804L-527,804C-539,804,-549,814,-549,826L-549,978C-549,990,-539,1000,-527,1000L-375,1000C-363,1000,-353,990,-353,978L-353,826C-353,814,-363,804,-375,804ZM-375,-98L-527,-98C-539,-98,-549,-88,-549,-76L-549,76C-549,88,-539,98,-527,98L-375,98C-363,98,-353,88,-353,76L-353,-76C-353,-88,-363,-98,-375,-98ZM527,804L375,804C363,804,353,814,353,826L353,978C353,990,363,1000,375,1000L527,1000C539,1000,549,990,549,978L549,826C549,814,539,804,527,804ZM527,-98L375,-98C363,-98,353,-88,353,-76L353,76C353,88,363,98,375,98L527,98C539,98,549,88,549,76L549,-76C549,-88,539,-98,527,-98Z",
  "M-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-130L-1000,-130L-1000,920ZM920,-820L500,-820L500,-980C500,-991,491,-1000,480,-1000L340,-1000C329,-1000,320,-991,320,-980L320,-820L-320,-820L-320,-980C-320,-991,-329,-1000,-340,-1000L-480,-1000C-491,-1000,-500,-991,-500,-980L-500,-820L-920,-820C-964,-820,-1000,-784,-1000,-740L-1000,-300L1000,-300L1000,-740C1000,-784,964,-820,920,-820Z",
  "M521,812L375,812C364,812,354,822,354,833L354,979C354,991,364,1000,375,1000L521,1000C532,1000,542,991,542,979L542,833C542,822,532,812,521,812ZM526,-1000L380,-1000C369,-1000,359,-991,359,-979L359,-833C359,-822,369,-812,380,-812L526,-812C538,-812,547,-822,547,-833L547,-979C547,-991,538,-1000,526,-1000ZM-979,-359L-833,-359C-822,-359,-812,-369,-812,-380L-812,-526C-812,-538,-822,-547,-833,-547L-979,-547C-991,-547,-1000,-538,-1000,-526L-1000,-380C-1000,-369,-991,-359,-979,-359ZM-979,-812L-833,-812C-822,-812,-812,-822,-812,-833L-812,-979C-812,-991,-822,-1000,-833,-1000L-979,-1000C-991,-1000,-1000,-991,-1000,-979L-1000,-833C-1000,-822,-991,-812,-979,-812ZM979,812L833,812C822,812,812,822,812,833L812,979C812,991,822,1000,833,1000L979,1000C991,1000,1000,991,1000,979L1000,833C1000,822,991,812,979,812ZM979,359L833,359C822,359,812,369,812,380L812,526C812,538,822,547,833,547L979,547C991,547,1000,538,1000,526L1000,380C1000,369,991,359,979,359ZM979,-94L833,-94C822,-94,812,-84,812,-73L812,73C812,84,822,94,833,94L979,94C991,94,1000,84,1000,73L1000,-73C1000,-84,991,-94,979,-94ZM979,-547L833,-547C822,-547,812,-538,812,-526L812,-380C812,-369,822,-359,833,-359L979,-359C991,-359,1000,-369,1000,-380L1000,-526C1000,-538,991,-547,979,-547ZM979,-1000L833,-1000C822,-1000,812,-991,812,-979L812,-833C812,-822,822,-812,833,-812L979,-812C991,-812,1000,-822,1000,-833L1000,-979C1000,-991,991,-1000,979,-1000ZM73,-1000L-73,-1000C-84,-1000,-94,-991,-94,-979L-94,-833C-94,-822,-84,-812,-73,-812L73,-812C84,-812,94,-822,94,-833L94,-979C94,-991,84,-1000,73,-1000ZM-526,-812L-380,-812C-369,-812,-359,-822,-359,-833L-359,-979C-359,-991,-369,-1000,-380,-1000L-526,-1000C-538,-1000,-547,-991,-547,-979L-547,-833C-547,-822,-538,-812,-526,-812ZM73,812L-401,812C-628,812,-812,628,-812,401L-812,-73C-812,-84,-822,-94,-833,-94L-979,-94C-991,-94,-1000,-84,-1000,-73L-1000,401C-1000,732,-732,1000,-401,1000L73,1000C84,1000,94,991,94,979L94,833C94,822,84,812,73,812Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM-180,632L-306,632C-312,632,-318,630,-321,625L-410,516L-499,625C-502,630,-508,632,-514,632L-640,632C-657,632,-666,613,-655,600L-498,408L-651,220C-662,208,-653,188,-636,188L-509,188C-504,188,-498,190,-494,195L-410,299L-324,195C-321,190,-316,188,-310,188L-183,188C-166,188,-157,208,-168,220L-321,408L-164,600C-154,613,-163,632,-180,632ZM-160,-322C-160,-317,-164,-312,-168,-312L-340,-312L-340,-141C-340,-136,-344,-132,-350,-132L-470,-132C-476,-132,-480,-136,-480,-140L-480,-312L-652,-312C-656,-312,-660,-317,-660,-322L-660,-442C-660,-448,-656,-452,-652,-452L-480,-452L-480,-624C-480,-629,-476,-632,-470,-632L-350,-632C-344,-632,-340,-629,-340,-624L-340,-452L-168,-452C-164,-452,-160,-448,-160,-442L-160,-322ZM660,600C660,606,656,610,652,610L168,610C164,610,160,606,160,600L160,480C160,474,164,470,168,470L652,470C656,470,660,474,660,480L660,600ZM660,340C660,346,656,350,652,350L168,350C164,350,160,346,160,340L160,220C160,214,164,210,168,210L652,210C656,210,660,214,660,220L660,340ZM660,-322C660,-317,656,-312,652,-312L168,-312C164,-312,160,-317,160,-322L160,-442C160,-448,164,-452,168,-452L652,-452C656,-452,660,-448,660,-442L660,-322Z",
  "M-375,812L-521,812C-532,812,-542,822,-542,833L-542,979C-542,991,-532,1000,-521,1000L-375,1000C-364,1000,-354,991,-354,979L-354,833C-354,822,-364,812,-375,812ZM-526,-812L-380,-812C-369,-812,-359,-822,-359,-833L-359,-979C-359,-991,-369,-1000,-380,-1000L-526,-1000C-538,-1000,-547,-991,-547,-979L-547,-833C-547,-822,-538,-812,-526,-812ZM979,-547L833,-547C822,-547,812,-538,812,-526L812,-380C812,-369,822,-359,833,-359L979,-359C991,-359,1000,-369,1000,-380L1000,-526C1000,-538,991,-547,979,-547ZM979,-1000L833,-1000C822,-1000,812,-991,812,-979L812,-833C812,-822,822,-812,833,-812L979,-812C991,-812,1000,-822,1000,-833L1000,-979C1000,-991,991,-1000,979,-1000ZM-833,812L-979,812C-991,812,-1000,822,-1000,833L-1000,979C-1000,991,-991,1000,-979,1000L-833,1000C-822,1000,-812,991,-812,979L-812,833C-812,822,-822,812,-833,812ZM-833,359L-979,359C-991,359,-1000,369,-1000,380L-1000,526C-1000,538,-991,547,-979,547L-833,547C-822,547,-812,538,-812,526L-812,380C-812,369,-822,359,-833,359ZM-833,-94L-979,-94C-991,-94,-1000,-84,-1000,-73L-1000,73C-1000,84,-991,94,-979,94L-833,94C-822,94,-812,84,-812,73L-812,-73C-812,-84,-822,-94,-833,-94ZM-833,-547L-979,-547C-991,-547,-1000,-538,-1000,-526L-1000,-380C-1000,-369,-991,-359,-979,-359L-833,-359C-822,-359,-812,-369,-812,-380L-812,-526C-812,-538,-822,-547,-833,-547ZM-833,-1000L-979,-1000C-991,-1000,-1000,-991,-1000,-979L-1000,-833C-1000,-822,-991,-812,-979,-812L-833,-812C-822,-812,-812,-822,-812,-833L-812,-979C-812,-991,-822,-1000,-833,-1000ZM-73,-812L73,-812C84,-812,94,-822,94,-833L94,-979C94,-991,84,-1000,73,-1000L-73,-1000C-84,-1000,-94,-991,-94,-979L-94,-833C-94,-822,-84,-812,-73,-812ZM380,-812L526,-812C538,-812,547,-822,547,-833L547,-979C547,-991,538,-1000,526,-1000L380,-1000C369,-1000,359,-991,359,-979L359,-833C359,-822,369,-812,380,-812ZM979,-94L833,-94C822,-94,812,-84,812,-73L812,401C812,628,628,812,401,812L-73,812C-84,812,-94,822,-94,833L-94,979C-94,991,-84,1000,-73,1000L401,1000C732,1000,1000,732,1000,401L1000,-73C1000,-84,991,-94,979,-94Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM535,184C535,322,423,434,286,434L-228,434L-228,568C-228,582,-245,590,-256,581L-528,367C-537,360,-537,347,-528,340L-256,126C-245,117,-228,125,-228,139L-228,273L286,273C335,273,374,233,374,184L374,-14C374,-23,382,-30,392,-30L518,-30C528,-30,535,-23,535,-14L535,184ZM528,-340L256,-126C245,-118,228,-126,228,-140L228,-273L-286,-273C-335,-273,-374,-233,-374,-184L-374,13C-374,22,-382,30,-392,30L-518,30C-528,30,-535,23,-535,13L-535,-184C-535,-322,-424,-434,-286,-434L228,-434L228,-568C228,-582,244,-590,256,-581L528,-367C537,-360,537,-347,528,-340Z",
  "M375,-812L521,-812C532,-812,542,-822,542,-833L542,-979C542,-991,532,-1000,521,-1000L375,-1000C364,-1000,354,-991,354,-979L354,-833C354,-822,364,-812,375,-812ZM526,812L380,812C369,812,359,822,359,833L359,979C359,991,369,1000,380,1000L526,1000C538,1000,547,991,547,979L547,833C547,822,538,812,526,812ZM-833,359L-979,359C-991,359,-1000,369,-1000,380L-1000,526C-1000,538,-991,547,-979,547L-833,547C-822,547,-812,538,-812,526L-812,380C-812,369,-822,359,-833,359ZM-833,812L-979,812C-991,812,-1000,822,-1000,833L-1000,979C-1000,991,-991,1000,-979,1000L-833,1000C-822,1000,-812,991,-812,979L-812,833C-812,822,-822,812,-833,812ZM979,-1000L833,-1000C822,-1000,812,-991,812,-979L812,-833C812,-822,822,-812,833,-812L979,-812C991,-812,1000,-822,1000,-833L1000,-979C1000,-991,991,-1000,979,-1000ZM979,-547L833,-547C822,-547,812,-538,812,-526L812,-380C812,-369,822,-359,833,-359L979,-359C991,-359,1000,-369,1000,-380L1000,-526C1000,-538,991,-547,979,-547ZM979,-94L833,-94C822,-94,812,-84,812,-73L812,73C812,84,822,94,833,94L979,94C991,94,1000,84,1000,73L1000,-73C1000,-84,991,-94,979,-94ZM979,359L833,359C822,359,812,369,812,380L812,526C812,538,822,547,833,547L979,547C991,547,1000,538,1000,526L1000,380C1000,369,991,359,979,359ZM979,812L833,812C822,812,812,822,812,833L812,979C812,991,822,1000,833,1000L979,1000C991,1000,1000,991,1000,979L1000,833C1000,822,991,812,979,812ZM73,812L-73,812C-84,812,-94,822,-94,833L-94,979C-94,991,-84,1000,-73,1000L73,1000C84,1000,94,991,94,979L94,833C94,822,84,812,73,812ZM-380,812L-526,812C-538,812,-547,822,-547,833L-547,979C-547,991,-538,1000,-526,1000L-380,1000C-369,1000,-359,991,-359,979L-359,833C-359,822,-369,812,-380,812ZM73,-1000L-401,-1000C-732,-1000,-1000,-732,-1000,-401L-1000,73C-1000,84,-991,94,-979,94L-833,94C-822,94,-812,84,-812,73L-812,-401C-812,-628,-628,-812,-401,-812L73,-812C84,-812,94,-822,94,-833L94,-979C94,-991,84,-1000,73,-1000Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM-360,580C-360,591,-369,600,-380,600L-580,600C-591,600,-600,591,-600,580L-600,-580C-600,-591,-591,-600,-580,-600L-380,-600C-369,-600,-360,-591,-360,-580L-360,580ZM120,-120C120,-109,111,-100,100,-100L-100,-100C-111,-100,-120,-109,-120,-120L-120,-580C-120,-591,-111,-600,-100,-600L100,-600C111,-600,120,-591,120,-580L120,-120ZM600,60C600,71,591,80,580,80L380,80C369,80,360,71,360,60L360,-580C360,-591,369,-600,380,-600L580,-600C591,-600,600,-591,600,-580L600,60Z",
  "M-375,-1000L-521,-1000C-532,-1000,-542,-991,-542,-979L-542,-833C-542,-822,-532,-812,-521,-812L-375,-812C-364,-812,-354,-822,-354,-833L-354,-979C-354,-991,-364,-1000,-375,-1000ZM-380,812L-526,812C-538,812,-547,822,-547,833L-547,979C-547,991,-538,1000,-526,1000L-380,1000C-369,1000,-359,991,-359,979L-359,833C-359,822,-369,812,-380,812ZM979,359L833,359C822,359,812,369,812,380L812,526C812,538,822,547,833,547L979,547C991,547,1000,538,1000,526L1000,380C1000,369,991,359,979,359ZM979,812L833,812C822,812,812,822,812,833L812,979C812,991,822,1000,833,1000L979,1000C991,1000,1000,991,1000,979L1000,833C1000,822,991,812,979,812ZM-833,-1000L-979,-1000C-991,-1000,-1000,-991,-1000,-979L-1000,-833C-1000,-822,-991,-812,-979,-812L-833,-812C-822,-812,-812,-822,-812,-833L-812,-979C-812,-991,-822,-1000,-833,-1000ZM-833,-547L-979,-547C-991,-547,-1000,-538,-1000,-526L-1000,-380C-1000,-369,-991,-359,-979,-359L-833,-359C-822,-359,-812,-369,-812,-380L-812,-526C-812,-538,-822,-547,-833,-547ZM-833,-94L-979,-94C-991,-94,-1000,-84,-1000,-73L-1000,73C-1000,84,-991,94,-979,94L-833,94C-822,94,-812,84,-812,73L-812,-73C-812,-84,-822,-94,-833,-94ZM-833,359L-979,359C-991,359,-1000,369,-1000,380L-1000,526C-1000,538,-991,547,-979,547L-833,547C-822,547,-812,538,-812,526L-812,380C-812,369,-822,359,-833,359ZM-833,812L-979,812C-991,812,-1000,822,-1000,833L-1000,979C-1000,991,-991,1000,-979,1000L-833,1000C-822,1000,-812,991,-812,979L-812,833C-812,822,-822,812,-833,812ZM73,812L-73,812C-84,812,-94,822,-94,833L-94,979C-94,991,-84,1000,-73,1000L73,1000C84,1000,94,991,94,979L94,833C94,822,84,812,73,812ZM526,812L380,812C369,812,359,822,359,833L359,979C359,991,369,1000,380,1000L526,1000C538,1000,547,991,547,979L547,833C547,822,538,812,526,812ZM401,-1000L-73,-1000C-84,-1000,-94,-991,-94,-979L-94,-833C-94,-822,-84,-812,-73,-812L401,-812C628,-812,812,-628,812,-401L812,73C812,84,822,94,833,94L979,94C991,94,1000,84,1000,73L1000,-401C1000,-732,732,-1000,401,-1000Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM-330,460C-385,460,-430,415,-430,360C-430,305,-385,260,-330,260C-275,260,-230,305,-230,360C-230,415,-275,460,-330,460ZM-330,100C-385,100,-430,55,-430,0C-430,-55,-385,-100,-330,-100C-275,-100,-230,-55,-230,0C-230,55,-275,100,-330,100ZM-330,-260C-385,-260,-430,-305,-430,-360C-430,-415,-385,-460,-330,-460C-275,-460,-230,-415,-230,-360C-230,-305,-275,-260,-330,-260ZM430,420C430,431,421,440,410,440L-50,440C-61,440,-70,431,-70,420L-70,300C-70,289,-61,280,-50,280L410,280C421,280,430,289,430,300L430,420ZM430,60C430,71,421,80,410,80L-50,80C-61,80,-70,71,-70,60L-70,-60C-70,-71,-61,-80,-50,-80L410,-80C421,-80,430,-71,430,-60L430,60ZM430,-300C430,-289,421,-280,410,-280L-50,-280C-61,-280,-70,-289,-70,-300L-70,-420C-70,-431,-61,-440,-50,-440L410,-440C421,-440,430,-431,430,-420L430,-300Z",
  "M-261,-896L-393,-896C-404,-896,-412,-887,-412,-877L-412,-744C-412,-734,-404,-725,-393,-725L-261,-725C-250,-725,-242,-734,-242,-744L-242,-877C-242,-887,-250,-896,-261,-896ZM-365,725L-498,725C-508,725,-517,734,-517,744L-517,877C-517,887,-508,896,-498,896L-365,896C-355,896,-346,887,-346,877L-346,744C-346,734,-355,725,-365,725ZM877,242L744,242C734,242,725,250,725,261L725,393C725,404,734,412,744,412L877,412C887,412,896,404,896,393L896,261C896,250,887,242,877,242ZM-744,-412L-877,-412C-887,-412,-896,-404,-896,-393L-896,-261C-896,-250,-887,-242,-877,-242L-744,-242C-734,-242,-725,-250,-725,-261L-725,-393C-725,-404,-734,-412,-744,-412ZM-744,-33L-877,-33C-887,-33,-896,-25,-896,-14L-896,118C-896,129,-887,137,-877,137L-744,137C-734,137,-725,129,-725,118L-725,-14C-725,-25,-734,-33,-744,-33ZM-744,346L-877,346C-887,346,-896,355,-896,365L-896,498C-896,508,-887,517,-877,517L-744,517C-734,517,-725,508,-725,498L-725,365C-725,355,-734,346,-744,346ZM-744,725L-877,725C-887,725,-896,734,-896,744L-896,877C-896,887,-887,896,-877,896L-744,896C-734,896,-725,887,-725,877L-725,744C-725,734,-734,725,-744,725ZM14,725L-118,725C-129,725,-137,734,-137,744L-137,877C-137,887,-129,896,-118,896L14,896C25,896,33,887,33,877L33,744C33,734,25,725,14,725ZM393,725L261,725C250,725,242,734,242,744L242,877C242,887,250,896,261,896L393,896C404,896,412,887,412,877L412,744C412,734,404,725,393,725ZM725,52C725,63,734,71,744,71L877,71C887,71,896,63,896,52L896,-351C896,-652,652,-896,351,-896L-52,-896C-63,-896,-71,-887,-71,-877L-71,-744C-71,-734,-63,-725,-52,-725L351,-725C558,-725,725,-558,725,-351L725,52ZM-640,-1000L-981,-1000C-991,-1000,-1000,-991,-1000,-981L-1000,-640C-1000,-629,-991,-621,-981,-621L-640,-621C-629,-621,-621,-629,-621,-640L-621,-981C-621,-991,-629,-1000,-640,-1000ZM-754,-759C-754,-756,-756,-754,-759,-754L-862,-754C-865,-754,-867,-756,-867,-759L-867,-862C-867,-865,-865,-867,-862,-867L-759,-867C-756,-867,-754,-865,-754,-862L-754,-759ZM981,621L640,621C629,621,621,629,621,640L621,981C621,991,629,1000,640,1000L981,1000C991,1000,1000,991,1000,981L1000,640C1000,629,991,621,981,621ZM867,862C867,865,865,867,862,867L759,867C756,867,754,865,754,862L754,759C754,756,756,754,759,754L862,754C865,754,867,756,867,759L867,862Z",
  "M953,-547L547,-953C517,-983,476,-1000,434,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-434C1000,-476,983,-517,953,-547ZM-320,-840L320,-840L320,-560L-320,-560L-320,-840ZM0,545C-199,545,-360,384,-360,185C-360,-14,-199,-175,0,-175C199,-175,360,-14,360,185C360,384,199,545,0,545ZM0,-15C-110,-15,-200,74,-200,185C-200,296,-110,385,0,385C110,385,200,296,200,185C200,74,110,-15,0,-15Z",
  "M404,317C462,286,530,268,602,268L602,268C609,268,613,259,607,254C532,187,448,133,355,94C354,93,353,93,352,93C503,-17,601,-195,601,-397C601,-730,332,-1000,-1,-1000C-333,-1000,-603,-730,-603,-397C-603,-195,-505,-17,-353,93C-354,93,-355,93,-356,94C-465,140,-562,206,-646,290C-730,374,-796,472,-842,581C-887,687,-911,800,-914,917C-914,928,-905,937,-894,937L-748,937C-738,937,-729,928,-729,918C-724,730,-649,554,-516,421C-378,283,-195,207,-1,207C137,207,270,245,384,317C390,320,397,321,404,317ZM-1,22C-112,22,-217,-22,-296,-101C-375,-180,-418,-285,-418,-397C-418,-508,-375,-613,-296,-692C-217,-772,-112,-815,-1,-815C111,-815,216,-772,295,-692C374,-613,417,-508,417,-397C417,-285,374,-180,295,-101C216,-22,111,22,-1,22ZM894,601L690,601L690,397C690,386,681,377,670,377L534,377C523,377,515,386,515,397L515,601L310,601C300,601,291,610,291,620L291,757C291,767,300,776,310,776L515,776L515,981C515,991,523,1000,534,1000L670,1000C681,1000,690,991,690,981L690,776L894,776C905,776,914,767,914,757L914,620C914,610,905,601,894,601Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM840,160L40,160L40,-160L840,-160L840,160ZM270,0ZM170,0L172,17L176,34L183,50L193,64L206,77L220,87L236,94L253,98L270,100L287,98L304,94L320,87L334,77L347,64L357,50L364,34L368,17L370,0L368,-17L364,-34L357,-50L347,-64L334,-77L320,-87L304,-94L287,-98L270,-100L253,-98L236,-94L220,-87L206,-77L193,-64L183,-50L176,-34L172,-17L170,0Z",
  "M943,681L384,681C373,681,364,690,364,701L364,820C364,831,373,840,384,840L943,840C954,840,963,831,963,820L963,701C963,690,954,681,943,681ZM-340,-2C-343,-24,-344,-46,-344,-68C-344,-107,-340,-146,-333,-184C-331,-193,-336,-202,-344,-206C-378,-221,-410,-242,-436,-268C-501,-331,-535,-416,-533,-506C-531,-586,-499,-662,-442,-720C-381,-783,-298,-817,-210,-816C-130,-816,-54,-785,5,-731C24,-712,41,-692,56,-670C60,-662,70,-659,79,-662C123,-677,169,-688,217,-693C231,-694,239,-709,232,-722C151,-882,-14,-993,-206,-996C-483,-1000,-713,-773,-713,-497C-713,-340,-641,-201,-528,-109C-607,-72,-680,-22,-744,42C-881,178,-958,358,-963,550C-963,562,-954,571,-943,571L-803,571C-792,571,-783,562,-783,552C-778,407,-720,272,-617,169C-543,95,-453,45,-355,20C-346,17,-339,8,-340,-2ZM783,-68C783,-341,564,-562,292,-567C16,-571,-214,-344,-214,-68C-214,89,-142,229,-29,320C-108,357,-181,407,-245,471C-382,607,-459,787,-464,980C-464,991,-455,1000,-444,1000L-304,1000C-294,1000,-285,992,-284,981C-280,836,-221,701,-118,598C-10,490,132,431,285,431C560,431,783,208,783,-68ZM510,158C450,218,370,252,285,252C199,252,119,218,59,158C-2,97,-36,16,-35,-71C-34,-153,-1,-232,56,-291C116,-352,196,-386,281,-387C366,-388,448,-355,508,-296C570,-235,604,-154,604,-68C604,18,571,98,510,158Z",
  "M920,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-920C1000,-964,964,-1000,920,-1000ZM-270,428L-270,620C-270,631,-279,640,-290,640L-410,640C-421,640,-430,631,-430,620L-430,428C-534,394,-610,296,-610,180C-610,64,-534,-34,-430,-68L-430,-620C-430,-631,-421,-640,-410,-640L-290,-640C-279,-640,-270,-631,-270,-620L-270,-68C-166,-34,-90,64,-90,180C-90,296,-166,394,-270,428ZM429,68C430,68,430,68,430,68L430,620C430,631,421,640,410,640L290,640C279,640,270,631,270,620L270,68C270,68,271,68,271,68C166,34,90,-64,90,-180C90,-296,166,-394,271,-428C270,-428,270,-428,270,-428L270,-620C270,-631,279,-640,290,-640L410,-640C421,-640,430,-631,430,-620L430,-428C430,-428,429,-428,429,-428C534,-394,610,-296,610,-180C610,-64,534,34,429,68ZM350,-180ZM260,-180L261,-164L265,-149L272,-135L281,-122L292,-111L305,-102L319,-95L334,-91L350,-90L366,-91L381,-95L395,-102L408,-111L419,-122L428,-135L435,-149L439,-164L440,-180L439,-196L435,-211L428,-225L419,-238L408,-249L395,-258L381,-265L366,-269L350,-270L334,-269L319,-265L305,-258L292,-249L281,-238L272,-225L265,-211L261,-196L260,-180ZM-272,136L-275,130C-275,130,-276,130,-276,130L-278,127C-278,126,-278,126,-278,126C-281,123,-283,120,-286,117L-287,116C-288,116,-289,114,-290,114C-292,112,-294,110,-296,108L-296,108L-300,106C-300,106,-300,106,-300,106C-304,104,-307,102,-310,100C-311,100,-312,100,-312,99C-313,98,-314,98,-315,98C-316,98,-316,97,-317,97C-318,96,-320,96,-321,96C-322,95,-323,95,-324,94L-326,94C-328,94,-329,93,-330,93C-330,93,-331,93,-332,92C-334,92,-335,92,-337,92C-338,92,-338,92,-338,91C-340,91,-341,91,-343,91C-343,91,-344,91,-344,90C-346,90,-348,90,-350,90C-352,90,-354,90,-356,90C-356,90,-357,90,-358,91C-359,91,-361,91,-362,91C-362,91,-363,91,-364,92C-365,92,-367,92,-369,92C-369,93,-370,93,-370,93C-372,93,-373,94,-374,94L-376,94C-377,95,-378,95,-380,96C-381,96,-382,96,-383,97C-384,97,-385,98,-386,98C-387,98,-388,98,-388,99C-389,99,-390,100,-390,100C-394,102,-397,104,-400,106C-400,106,-401,106,-401,106L-404,108L-404,108C-406,110,-409,112,-411,114C-412,115,-413,116,-414,116L-414,117C-417,120,-420,123,-422,126C-422,126,-423,126,-423,127L-425,130C-425,130,-425,130,-425,130L-429,136C-429,137,-430,137,-430,138C-436,150,-440,165,-440,180C-440,195,-436,210,-430,222C-430,223,-429,223,-429,224L-425,230C-425,230,-425,230,-425,230L-423,233C-422,234,-422,234,-422,234C-420,237,-417,240,-414,243L-414,244C-413,244,-412,246,-411,246C-409,248,-406,250,-404,252L-404,252L-401,254C-401,254,-400,254,-400,254C-397,256,-394,258,-390,260C-390,260,-389,260,-388,261C-388,262,-387,262,-386,262C-385,262,-384,263,-383,263C-382,264,-381,264,-380,264C-378,265,-377,265,-376,266L-374,266C-373,266,-372,267,-370,267C-370,267,-369,267,-369,268C-367,268,-365,268,-364,268C-363,268,-362,268,-362,269C-360,269,-359,269,-358,269C-357,269,-357,269,-356,270C-354,270,-352,270,-350,270C-348,270,-346,270,-344,270C-344,270,-344,270,-343,269C-341,269,-340,269,-338,269C-338,269,-338,269,-337,268C-335,268,-334,268,-332,268C-331,267,-330,267,-330,267C-329,267,-328,266,-326,266L-324,266C-323,265,-322,265,-321,264C-320,264,-318,264,-317,263C-316,263,-316,262,-315,262C-314,262,-313,262,-312,261C-312,261,-311,260,-310,260C-307,258,-304,256,-300,254C-300,254,-300,254,-300,254L-296,252L-296,252C-294,250,-292,248,-290,246C-289,245,-288,244,-287,244L-286,243C-284,240,-281,237,-278,234C-278,234,-278,234,-278,233L-276,230C-276,230,-275,230,-275,230L-272,224C-271,223,-271,223,-271,222C-264,210,-260,195,-260,180C-260,165,-264,150,-271,138C-271,137,-271,136,-272,136Z",
  "M417,360C478,328,547,309,621,309L621,309C629,309,633,300,627,295C550,226,462,170,366,130C365,129,364,129,363,128C519,15,621,-169,621,-377C621,-721,343,-1000,-1,-1000C-344,-1000,-622,-721,-622,-377C-622,-169,-521,15,-365,128C-366,129,-367,129,-368,130C-480,177,-581,245,-667,332C-754,419,-822,520,-869,632C-916,742,-941,859,-943,979C-944,991,-935,1000,-923,1000L-773,1000C-762,1000,-753,991,-753,980C-748,786,-670,605,-533,467C-391,325,-202,246,-1,246C142,246,279,286,396,360C403,363,410,364,417,360ZM-1,55C-116,55,-224,10,-306,-71C-387,-153,-432,-262,-432,-377C-432,-492,-387,-601,-306,-682C-224,-764,-116,-809,-1,-809C115,-809,223,-764,304,-682C386,-601,431,-492,431,-377C431,-262,386,-153,304,-71C223,10,114,55,-1,55ZM923,653L320,653C309,653,300,662,300,673L300,814C300,825,309,834,320,834L923,834C935,834,944,825,944,814L944,673C944,662,935,653,923,653Z",
  "M-320,1000L920,1000C964,1000,1000,964,1000,920L1000,-430L-320,-430L-320,1000ZM920,-1000L-320,-1000L-320,-590L1000,-590L1000,-920C1000,-964,964,-1000,920,-1000ZM-1000,-920L-1000,920C-1000,964,-964,1000,-920,1000L-480,1000L-480,-1000L-920,-1000C-964,-1000,-1000,-964,-1000,-920Z",
  "M920,632L727,632L727,438C727,427,718,419,707,419L591,419C580,419,572,427,572,438L572,632L378,632C367,632,358,641,358,651L358,767C358,778,367,787,378,787L572,787L572,981C572,991,580,1000,591,1000L707,1000C718,1000,727,991,727,981L727,787L920,787C931,787,940,778,940,767L940,651C940,641,931,632,920,632ZM-335,-31C-338,-52,-339,-73,-339,-95C-339,-133,-335,-171,-328,-207C-327,-216,-331,-225,-339,-229C-372,-244,-403,-264,-429,-290C-491,-351,-525,-433,-522,-521C-520,-598,-489,-672,-435,-728C-375,-789,-294,-823,-209,-822C-132,-821,-57,-791,0,-738C19,-720,35,-701,49,-679C54,-672,63,-669,71,-672C114,-686,159,-697,205,-702C219,-703,227,-718,221,-730C142,-885,-19,-993,-205,-996C-473,-1000,-697,-780,-697,-511C-697,-359,-627,-224,-517,-135C-594,-99,-665,-50,-727,12C-860,144,-935,319,-940,506C-940,517,-931,525,-920,525L-784,525C-774,525,-765,517,-765,507C-760,366,-703,235,-603,135C-532,64,-445,14,-350,-10C-341,-12,-334,-21,-335,-31ZM756,-95C756,-360,543,-575,279,-579C10,-583,-213,-363,-213,-95C-213,57,-143,193,-33,282C-110,317,-181,366,-243,428C-375,561,-451,735,-455,922C-456,933,-447,942,-436,942L-300,942C-290,942,-281,934,-281,923C-276,783,-219,651,-119,551C-15,447,124,390,271,390C539,390,756,173,756,-95ZM490,124C432,183,354,215,271,215C188,215,111,183,52,124C-7,65,-39,-14,-39,-98C-38,-177,-6,-254,49,-311C107,-371,185,-404,268,-405C350,-406,430,-374,489,-316C549,-257,582,-179,582,-95C581,-12,549,66,490,124Z",
  "M957,-1000L130,-1000C107,-1000,87,-980,87,-957L87,-130C87,-107,107,-87,130,-87L957,-87C980,-87,1000,-107,1000,-130L1000,-957C1000,-980,980,-1000,957,-1000ZM957,87L130,87C107,87,87,107,87,130L87,957C87,980,107,1000,130,1000L957,1000C980,1000,1000,980,1000,957L1000,130C1000,107,980,87,957,87ZM-130,-1000L-957,-1000C-980,-1000,-1000,-980,-1000,-957L-1000,-130C-1000,-107,-980,-87,-957,-87L-130,-87C-107,-87,-87,-107,-87,-130L-87,-957C-87,-980,-107,-1000,-130,-1000ZM-130,87L-957,87C-980,87,-1000,107,-1000,130L-1000,957C-1000,980,-980,1000,-957,1000L-130,1000C-107,1000,-87,980,-87,957L-87,130C-87,107,-107,87,-130,87Z",
  "M871,632C823,520,755,419,668,332C581,245,480,177,368,129C367,129,366,129,365,128C521,15,623,-169,623,-377C623,-721,344,-1000,0,-1000C-344,-1000,-623,-721,-623,-377C-623,-169,-521,15,-365,128C-366,129,-367,129,-368,130C-480,177,-581,245,-668,332C-755,419,-823,520,-871,632C-917,742,-942,859,-945,979C-945,991,-936,1000,-925,1000L-774,1000C-763,1000,-754,991,-754,980C-749,786,-671,605,-533,467C-391,325,-202,246,0,246C202,246,391,325,533,467C671,605,749,786,754,980C754,991,763,1000,774,1000L925,1000C936,1000,945,991,945,979C942,859,917,742,871,632ZM0,55C-115,55,-224,10,-306,-71C-387,-153,-432,-262,-432,-377C-432,-492,-387,-601,-306,-682C-224,-764,-115,-809,0,-809C115,-809,224,-764,306,-682C387,-601,432,-492,432,-377C432,-262,387,-153,306,-71C224,10,115,55,0,55Z",
  "M518,-1000L-518,-1000C-597,-1000,-661,-936,-661,-857L-661,857C-661,936,-597,1000,-518,1000L518,1000C597,1000,661,936,661,857L661,-857C661,-936,597,-1000,518,-1000ZM0,701C-49,701,-89,661,-89,612C-89,562,-49,522,0,522C49,522,89,562,89,612C89,661,49,701,0,701Z",
  "M779,471C715,408,642,357,563,320C676,229,748,89,748,-68C748,-344,518,-571,241,-567C-31,-562,-250,-341,-250,-68C-250,89,-178,229,-65,320C-144,357,-217,407,-280,471C-417,607,-494,787,-499,980C-499,991,-490,1000,-479,1000L-339,1000C-329,1000,-320,992,-319,981C-315,836,-256,701,-153,598C-45,490,98,431,249,431C401,431,544,490,652,598C755,701,813,836,818,981C819,992,827,1000,838,1000L978,1000C989,1000,998,991,998,980C993,787,916,607,779,471ZM249,252C164,252,84,218,24,158C-37,97,-71,16,-70,-71C-69,-153,-36,-232,21,-291C81,-352,161,-386,246,-387C331,-388,413,-355,473,-296C535,-235,569,-154,569,-68C569,18,536,98,475,158C415,218,335,252,249,252ZM-375,-2C-378,-24,-379,-46,-379,-68C-379,-107,-375,-146,-368,-184C-366,-193,-371,-202,-379,-206C-413,-221,-445,-242,-471,-268C-536,-331,-571,-416,-568,-506C-566,-586,-534,-662,-477,-720C-416,-783,-333,-817,-245,-816C-165,-816,-89,-785,-30,-731C-11,-712,6,-692,20,-670C25,-662,35,-659,44,-662C88,-677,134,-688,182,-693C196,-694,204,-709,197,-722C116,-882,-49,-993,-241,-996C-518,-1000,-748,-773,-748,-497C-748,-340,-676,-201,-563,-109C-642,-72,-715,-22,-779,42C-916,178,-993,358,-998,550C-998,562,-989,571,-978,571L-838,571C-827,571,-818,562,-818,552C-813,407,-755,272,-652,169C-578,95,-488,45,-390,20C-381,17,-374,8,-375,-2Z",
  "M643,-1000L-643,-1000C-722,-1000,-786,-936,-786,-857L-786,857C-786,936,-722,1000,-643,1000L643,1000C722,1000,786,936,786,857L786,-857C786,-936,722,-1000,643,-1000ZM0,696C-49,696,-89,656,-89,607C-89,558,-49,518,0,518C49,518,89,558,89,607C89,656,49,696,0,696Z",
  "M979,729L-812,729L-812,-896C-812,-907,-822,-917,-833,-917L-979,-917C-991,-917,-1000,-907,-1000,-896L-1000,896C-1000,907,-991,917,-979,917L979,917C991,917,1000,907,1000,896L1000,750C1000,739,991,729,979,729ZM-625,562L771,562C782,562,792,553,792,542L792,-594C792,-612,769,-622,756,-609L208,-61L-118,-384C-126,-392,-140,-392,-148,-384L-640,110C-644,114,-646,119,-646,124L-646,542C-646,553,-636,562,-625,562Z",
  "M714,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-929C786,-968,754,-1000,714,-1000ZM348,-371L244,-446L134,-367L134,-866L348,-866L348,-371Z",
  "M979,729L-812,729L-812,-896C-812,-907,-822,-917,-833,-917L-979,-917C-991,-917,-1000,-907,-1000,-896L-1000,896C-1000,907,-991,917,-979,917L979,917C991,917,1000,907,1000,896L1000,750C1000,739,991,729,979,729ZM-537,327C-529,335,-516,335,-508,327L-147,-31L185,303C193,311,206,311,214,303L932,-414C940,-422,940,-435,932,-443L828,-546C820,-554,807,-554,799,-546L200,53L-132,-281C-140,-289,-153,-289,-161,-281L-640,195C-648,203,-648,216,-640,224L-537,327Z",
  "M714,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-929C786,-968,754,-1000,714,-1000ZM301,-93L107,267L209,267C219,267,228,275,228,285L228,341C228,352,219,360,209,360L68,360L68,424L209,424C219,424,228,432,228,443L228,498C228,509,220,517,210,517L68,517L68,629C68,639,60,648,50,648L-48,648C-58,648,-67,639,-67,629L-67,517L-207,517C-218,517,-226,509,-226,499L-226,443C-226,432,-218,424,-207,424L-67,424L-67,360L-207,360C-218,360,-226,352,-226,341L-226,285C-226,275,-218,267,-207,267L-106,267L-301,-93C-306,-102,-303,-113,-294,-118C-291,-120,-288,-121,-285,-121L-176,-121C-169,-121,-162,-117,-159,-110L1,206L162,-110C165,-117,171,-121,178,-121L285,-121C295,-121,304,-112,304,-102C304,-99,303,-96,301,-93ZM1,-422L-498,-812L498,-812L1,-422Z",
  "M979,729L-812,729L-812,-896C-812,-907,-822,-917,-833,-917L-979,-917C-991,-917,-1000,-907,-1000,-896L-1000,896C-1000,907,-991,917,-979,917L979,917C991,917,1000,907,1000,896L1000,750C1000,739,991,729,979,729ZM-583,521L-438,521C-426,521,-417,511,-417,500L-417,125C-417,114,-426,104,-438,104L-583,104C-595,104,-604,114,-604,125L-604,500C-604,511,-595,521,-583,521ZM-188,521L-42,521C-30,521,-21,511,-21,500L-21,-333C-21,-345,-30,-354,-42,-354L-188,-354C-199,-354,-208,-345,-208,-333L-208,500C-208,511,-199,521,-188,521ZM208,521L354,521C366,521,375,511,375,500L375,-130C375,-142,366,-151,354,-151L208,-151C197,-151,188,-142,188,-130L188,500C188,511,197,521,208,521ZM604,521L750,521C761,521,771,511,771,500L771,-542C771,-553,761,-562,750,-562L604,-562C593,-562,583,-553,583,-542L583,500C583,511,593,521,604,521Z",
  "M771,-744L33,-995C24,-998,12,-1000,0,-1000C-12,-1000,-24,-998,-33,-995L-771,-744C-789,-738,-804,-717,-804,-698L-804,351C-804,370,-792,395,-777,407L-28,991C-20,997,-10,1000,0,1000C10,1000,20,997,27,991L776,407C791,396,804,370,804,351L804,-698C804,-717,789,-737,771,-744ZM397,-372L-65,264C-79,283,-108,283,-122,264L-397,-114C-405,-126,-397,-142,-383,-142L-263,-142C-251,-142,-241,-137,-234,-128L-94,66L234,-386C241,-395,251,-400,263,-400L383,-400C397,-400,405,-384,397,-372Z",
  "M979,729L-812,729L-812,-896C-812,-907,-822,-917,-833,-917L-979,-917C-991,-917,-1000,-907,-1000,-896L-1000,896C-1000,907,-991,917,-979,917L979,917C991,917,1000,907,1000,896L1000,750C1000,739,991,729,979,729ZM-417,240ZM-583,240L-581,269L-573,297L-561,323L-544,347L-524,367L-500,384L-474,396L-446,404L-417,406L-388,404L-360,396L-333,384L-310,367L-289,347L-272,323L-260,297L-253,269L-250,240L-253,211L-260,183L-272,156L-289,132L-310,112L-333,95L-360,83L-388,75L-417,73L-446,75L-474,83L-500,95L-524,112L-544,132L-561,156L-573,183L-581,211L-583,240ZM-151,-344ZM-276,-344L-274,-322L-269,-301L-259,-281L-247,-263L-231,-248L-214,-235L-194,-226L-173,-221L-151,-219L-129,-221L-108,-226L-89,-235L-71,-248L-55,-263L-43,-281L-34,-301L-28,-322L-26,-344L-28,-365L-34,-387L-43,-406L-55,-424L-71,-440L-89,-452L-108,-461L-129,-467L-151,-469L-173,-467L-194,-461L-214,-452L-231,-440L-247,-424L-259,-406L-269,-387L-274,-365L-276,-344ZM385,250ZM135,250L139,293L150,336L169,375L194,411L225,442L260,467L300,485L342,496L385,500L429,496L471,485L510,467L546,442L577,411L602,375L620,336L632,293L635,250L632,207L620,164L602,125L577,89L546,58L510,33L471,15L429,4L385,0L342,4L300,15L260,33L225,58L194,89L169,125L150,164L139,207L135,250ZM667,-568ZM521,-568L523,-542L530,-518L540,-495L555,-474L573,-456L594,-441L617,-431L641,-424L667,-422L692,-424L717,-431L740,-441L760,-456L778,-474L793,-495L804,-518L810,-542L812,-568L810,-593L804,-618L793,-641L778,-661L760,-679L740,-694L717,-705L692,-711L667,-714L641,-711L617,-705L594,-694L573,-679L555,-661L540,-641L530,-618L523,-593L521,-568Z",
  "M771,-744L33,-995C24,-998,12,-1000,0,-1000C-12,-1000,-24,-998,-33,-995L-771,-744C-789,-738,-804,-717,-804,-698L-804,351C-804,370,-792,395,-777,407L-28,991C-20,997,-10,1000,0,1000C10,1000,20,997,27,991L776,407C791,396,804,370,804,351L804,-698C804,-717,789,-737,771,-744ZM296,-390L106,-39L205,-39C217,-39,227,-30,227,-18L227,29C227,41,217,50,205,50L67,50L67,115L205,115C217,115,227,125,227,137L227,183C227,195,217,205,205,205L67,205L67,317C67,329,57,339,45,339L-44,339C-56,339,-66,329,-66,317L-66,205L-203,205C-215,205,-225,195,-225,183L-225,137C-225,125,-215,115,-203,115L-66,115L-66,50L-203,50C-215,50,-225,41,-225,29L-225,-18C-225,-30,-215,-39,-203,-39L-105,-39L-296,-390C-302,-400,-298,-413,-288,-419C-284,-421,-281,-422,-277,-422L-177,-422C-169,-422,-162,-417,-158,-410L1,-96L160,-410C163,-417,171,-422,179,-422L277,-422C289,-422,299,-412,299,-400C299,-396,298,-393,296,-390Z",
  "M714,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-929C786,-968,754,-1000,714,-1000ZM625,839L-625,839L-625,391L-406,391C-381,464,-335,530,-275,580C-198,643,-100,679,0,679C100,679,198,644,275,580C335,530,381,464,406,391L625,391L625,250L294,250L282,305C255,439,137,536,0,536C-137,536,-255,439,-282,305L-294,250L-625,250L-625,-839L625,-839L625,839ZM-429,-382L429,-382C438,-382,446,-390,446,-400L446,-507C446,-517,438,-525,429,-525L-429,-525C-438,-525,-446,-517,-446,-507L-446,-400C-446,-390,-438,-382,-429,-382ZM-429,-25L429,-25C438,-25,446,-33,446,-42L446,-150C446,-159,438,-167,429,-167L-429,-167C-438,-167,-446,-159,-446,-150L-446,-42C-446,-33,-438,-25,-429,-25Z",
  "M714,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-929C786,-968,754,-1000,714,-1000ZM-625,-839L625,-839L625,-375L-625,-375L-625,-839ZM625,232L-625,232L-625,-232L625,-232L625,232ZM625,839L-625,839L-625,375L625,375L625,839ZM-375,-607ZM-464,-607L-463,-592L-459,-578L-454,-565L-445,-552L-435,-541L-424,-532L-411,-525L-397,-521L-382,-518L-368,-518L-353,-521L-339,-525L-326,-532L-315,-541L-305,-552L-296,-565L-291,-578L-287,-592L-286,-607L-287,-622L-291,-636L-296,-650L-305,-662L-315,-673L-326,-682L-339,-689L-353,-694L-368,-696L-382,-696L-397,-694L-411,-689L-424,-682L-435,-673L-445,-662L-454,-650L-459,-636L-463,-622L-464,-607ZM-375,0ZM-464,0L-463,15L-459,29L-454,42L-445,55L-435,66L-424,75L-411,82L-397,87L-382,89L-368,89L-353,87L-339,82L-326,75L-315,66L-305,55L-296,42L-291,29L-287,15L-286,0L-287,-15L-291,-29L-296,-42L-305,-55L-315,-66L-326,-75L-339,-82L-353,-87L-368,-89L-382,-89L-397,-87L-411,-82L-424,-75L-435,-66L-445,-55L-454,-42L-459,-29L-463,-15L-464,0ZM-375,607ZM-464,607L-463,622L-459,636L-454,650L-445,662L-435,673L-424,682L-411,689L-397,694L-382,696L-368,696L-353,694L-339,689L-326,682L-315,673L-305,662L-296,650L-291,636L-287,622L-286,607L-287,592L-291,578L-296,565L-305,552L-315,541L-326,532L-339,525L-353,521L-368,518L-382,518L-397,521L-411,525L-424,532L-435,541L-445,552L-454,565L-459,578L-463,592L-464,607Z",
  "M771,-744L33,-995C24,-998,12,-1000,0,-1000C-12,-1000,-24,-998,-33,-995L-771,-744C-789,-738,-804,-717,-804,-698L-804,351C-804,370,-792,395,-777,407L-28,991C-20,997,-10,1000,0,1000C10,1000,20,997,27,991L776,407C791,396,804,370,804,351L804,-698C804,-717,789,-737,771,-744ZM250,91C144,197,-18,211,-139,135L-307,303C-314,310,-325,310,-332,303L-406,229C-412,223,-412,212,-406,205L-237,36C-313,-85,-299,-246,-193,-352C-71,-474,127,-474,250,-352C372,-229,372,-31,250,91ZM-95,-7L-72,12L-46,27L-17,38L13,43L43,43L73,38L102,27L128,12L151,-7L171,-30L186,-57L196,-85L201,-115L201,-146L196,-175L186,-204L171,-230L151,-253L128,-273L102,-288L73,-299L43,-304L13,-304L-17,-299L-46,-288L-72,-273L-95,-253L-115,-230L-130,-204L-140,-175L-145,-146L-145,-115L-140,-85L-130,-57L-115,-30L-95,-7Z",
  "M714,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-929C786,-968,754,-1000,714,-1000ZM-625,-839L625,-839L625,-375L-625,-375L-625,-839ZM625,232L-625,232L-625,-232L625,-232L625,232ZM625,839L-625,839L-625,375L625,375L625,839ZM-36,-679L-446,-679C-456,-679,-464,-671,-464,-661L-464,-554C-464,-544,-456,-536,-446,-536L-36,-536C-26,-536,-18,-544,-18,-554L-18,-661C-18,-671,-26,-679,-36,-679ZM-446,71L-36,71C-26,71,-18,63,-18,54L-18,-54C-18,-63,-26,-71,-36,-71L-446,-71C-456,-71,-464,-63,-464,-54L-464,54C-464,63,-456,71,-446,71ZM375,616ZM286,616L287,631L291,645L296,659L305,671L315,682L326,691L339,698L353,703L368,705L382,705L397,703L411,698L424,691L435,682L445,671L454,659L459,645L463,631L464,616L463,601L459,587L454,574L445,561L435,550L424,541L411,534L397,530L382,527L368,527L353,530L339,534L326,541L315,550L305,561L296,574L291,587L287,601L286,616Z",
  "M765,-498C778,-485,786,-467,786,-448L786,929C786,968,754,1000,714,1000L-714,1000C-754,1000,-786,968,-786,929L-786,-929C-786,-968,-754,-1000,-714,-1000L234,-1000C253,-1000,271,-992,284,-979L765,-498ZM621,-415L201,-835L201,-415L621,-415ZM0,607C49,607,89,567,89,518C89,469,49,429,0,429C-49,429,-89,469,-89,518C-89,567,-49,607,0,607ZM71,268L71,-143L71,-146L70,-149L69,-152L67,-154L65,-157L62,-158L60,-160L57,-160L54,-161L-54,-161L-56,-160L-59,-160L-62,-159L-64,-157L-66,-155L-68,-153L-69,-151L-71,-148L-71,-146L-71,-143L-71,268L-71,271L-70,274L-69,277L-67,279L-65,282L-63,283L-60,285L-57,285L-54,286L54,286L57,285L60,285L63,283L65,282L67,279L69,277L70,274L71,271L71,268Z",
  "M518,-1000L-518,-1000C-597,-1000,-661,-936,-661,-857L-661,857C-661,936,-597,1000,-518,1000L518,1000C597,1000,661,936,661,857L661,-857C661,-936,597,-1000,518,-1000ZM500,839L-500,839L-500,-839L500,-839L500,839ZM0,612ZM-89,612L-88,626L-84,641L-79,654L-70,666L-60,677L-49,686L-36,693L-22,698L-7,701L7,701L22,698L36,693L49,686L60,677L70,666L79,654L84,641L88,626L89,612L88,597L84,583L79,569L70,557L60,546L49,537L36,530L22,525L7,523L-7,523L-22,525L-36,530L-49,537L-60,546L-70,557L-79,569L-84,583L-88,597L-89,612Z",
  "M-71,152L-312,152L-316,152L-319,153L-321,154L-324,156L-326,158L-328,161L-329,164L-330,167L-330,170L-330,277L-330,280L-329,282L-328,285L-327,287L-325,289L-323,291L-321,293L-318,294L-315,294L-312,295L-71,295L-71,536L-71,539L-71,541L-69,544L-68,546L-66,548L-64,550L-62,552L-59,553L-56,553L-54,554L54,554L57,553L60,552L62,551L65,549L67,547L69,545L70,542L71,539L71,536L71,295L312,295L316,294L319,294L321,292L324,290L326,288L328,286L329,283L330,280L330,277L330,170L330,167L329,164L328,161L326,158L324,156L321,154L319,153L316,152L313,152L71,152L71,-89L71,-92L70,-95L69,-98L67,-101L65,-103L63,-105L60,-106L57,-107L54,-107L-54,-107L-57,-107L-60,-106L-62,-105L-65,-103L-67,-101L-69,-98L-70,-95L-71,-92L-71,-89L-71,152ZM765,-498C778,-485,786,-467,786,-448L786,929C786,968,754,1000,714,1000L-714,1000C-754,1000,-786,968,-786,929L-786,-929C-786,-968,-754,-1000,-714,-1000L234,-1000C253,-1000,271,-992,284,-979L765,-498ZM621,-415L201,-835L201,-415L621,-415Z",
  "M643,-1000L-643,-1000C-722,-1000,-786,-936,-786,-857L-786,857C-786,936,-722,1000,-643,1000L643,1000C722,1000,786,936,786,857L786,-857C786,-936,722,-1000,643,-1000ZM625,839L-625,839L-625,-839L625,-839L625,839ZM0,607ZM-89,607L-88,622L-84,636L-79,650L-70,662L-60,673L-49,682L-36,689L-22,694L-7,696L7,696L22,694L36,689L49,682L60,673L70,662L79,650L84,636L88,622L89,607L88,592L84,578L79,565L70,552L60,541L49,532L36,525L22,521L7,518L-7,518L-22,521L-36,525L-49,532L-60,541L-70,552L-79,565L-84,578L-88,592L-89,607Z",
  "M765,-498C778,-485,786,-467,786,-448L786,929C786,968,754,1000,714,1000L-714,1000C-754,1000,-786,968,-786,929L-786,-929C-786,-968,-754,-1000,-714,-1000L234,-1000C253,-1000,271,-992,284,-979L765,-498ZM621,-415L201,-835L201,-415L621,-415ZM141,-76L5,152L-133,-76L-136,-80L-139,-83L-143,-86L-147,-88L-152,-89L-156,-89L-242,-89L-246,-89L-249,-88L-253,-87L-256,-85C-269,-77,-273,-61,-265,-48L-81,243L-267,539L-269,543L-270,546L-271,550L-271,554C-271,568,-259,580,-244,580L-168,580L-163,580L-159,579L-154,577L-151,574L-147,571L-145,568L-5,341L134,568L137,571L140,574L144,577L148,579L153,580L157,580L241,580L245,580L248,579L252,578L255,576C268,568,271,552,263,539L76,248L267,-48L268,-51L270,-55L271,-59L271,-62C271,-77,259,-89,244,-89L164,-89L160,-89L155,-88L151,-86L147,-83L144,-80L141,-76Z",
  "M-159,-110C-162,-117,-169,-121,-176,-121L-285,-121C-288,-121,-291,-120,-294,-118C-303,-113,-306,-102,-301,-93L-106,267L-208,267C-218,267,-226,275,-226,285L-226,342C-226,352,-218,360,-208,360L-67,360L-67,424L-208,424C-218,424,-226,433,-226,443L-226,499C-226,509,-218,518,-208,518L-67,518L-67,629C-67,639,-58,648,-48,648L49,648C60,648,68,639,68,629L68,518L209,518C220,518,228,509,228,499L228,443C228,433,219,424,209,424L68,424L68,360L209,360C219,360,228,352,228,342L228,285C228,275,219,267,209,267L106,267L301,-93C303,-95,303,-98,303,-102C303,-112,295,-120,285,-120L178,-120C171,-120,165,-116,161,-110L1,207L-159,-110ZM714,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-929C786,-968,754,-1000,714,-1000ZM625,839L-625,839L-625,-712L-44,-256C-18,-236,18,-236,44,-256L625,-712L625,839ZM625,-838L554,-838L0,-403L-554,-838L-625,-838L-625,-839L625,-839L625,-838Z",
  "M765,-498C778,-485,786,-467,786,-448L786,929C786,968,754,1000,714,1000L-714,1000C-754,1000,-786,968,-786,929L-786,-929C-786,-968,-754,-1000,-714,-1000L234,-1000C253,-1000,271,-992,284,-979L765,-498ZM621,-415L201,-835L201,-415L621,-415ZM-192,199L-60,495L-57,500L-53,505L-49,509L-44,512L-39,515L-33,516L-27,517L27,517C41,517,54,508,59,495L191,198L191,549C191,569,207,585,227,585L288,585C308,585,324,569,324,549L324,-58C324,-78,308,-94,288,-94L210,-94L204,-93L199,-92L193,-89L188,-86L184,-82L180,-77L178,-72L0,335L-177,-72L-180,-77L-184,-82L-188,-86L-193,-89L-198,-92L-204,-93L-210,-94L-288,-94C-308,-94,-324,-78,-324,-58L-324,549C-324,569,-308,585,-288,585L-227,585C-208,585,-192,569,-192,549L-192,199Z",
  "M714,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-929C786,-968,754,-1000,714,-1000ZM134,-839L348,-839L348,-371L244,-446L134,-367L134,-839ZM625,839L-625,839L-625,-839L0,-839L0,-177C0,-169,2,-162,7,-156C18,-140,40,-136,56,-148L244,-281L425,-149C431,-144,439,-142,446,-142C466,-142,482,-158,482,-177L482,-839L625,-839L625,839Z",
  "M765,-498C778,-485,786,-467,786,-448L786,929C786,968,754,1000,714,1000L-714,1000C-754,1000,-786,968,-786,929L-786,-929C-786,-968,-754,-1000,-714,-1000L234,-1000C253,-1000,271,-992,284,-979L765,-498ZM621,-415L201,-835L201,-415L621,-415ZM-429,-67L-432,-67L-435,-66L-437,-65L-440,-63L-442,-61L-444,-58L-445,-55L-446,-52L-446,-49L-446,58L-446,61L-446,64L-444,66L-443,69L-441,71L-439,72L-437,74L-434,75L-431,76L-429,76L429,76L432,76L435,75L438,74L440,72L442,70L444,67L445,64L446,61L446,58L446,-49L446,-52L445,-55L444,-58L442,-61L440,-63L438,-65L435,-66L432,-67L429,-67L-429,-67ZM-429,237L-431,237L-434,237L-437,239L-439,240L-441,242L-443,244L-444,246L-446,249L-446,252L-446,254L-446,362L-446,365L-445,368L-444,371L-442,373L-440,375L-438,377L-435,378L-432,379L-429,379L-18,379L-15,379L-12,378L-9,377L-6,375L-4,373L-2,371L-1,368L0,365L0,362L0,254L0,252L-1,249L-2,246L-3,244L-5,242L-7,240L-10,239L-12,237L-15,237L-18,237L-429,237Z",
  "M404,-459L404,-569C404,-579,395,-587,385,-587L-495,-587C-506,-587,-514,-579,-514,-569L-514,-459C-514,-449,-506,-440,-495,-440L385,-440C395,-440,404,-449,404,-459ZM-495,-257C-506,-257,-514,-249,-514,-239L-514,-128C-514,-118,-506,-110,-495,-110L-73,-110C-63,-110,-55,-118,-55,-128L-55,-239C-55,-249,-63,-257,-73,-257L-495,-257ZM367,9C93,9,-128,231,-128,505C-128,778,93,1000,367,1000C641,1000,862,778,862,505C862,231,641,9,367,9ZM614,751C548,817,460,853,367,853C274,853,186,817,120,751C55,685,18,598,18,505C18,411,55,324,120,258C186,192,274,156,367,156C460,156,548,192,614,258C679,324,716,411,716,505C716,598,679,685,614,751ZM571,330L469,330C464,330,458,333,455,338L309,539L256,466C253,461,247,458,241,458L140,458C125,458,116,475,125,488L294,722C302,732,317,732,324,722L586,359C595,347,586,330,571,330ZM-165,780L-697,780L-697,-835L587,-835L587,-46C587,-36,595,-28,606,-28L734,-28C744,-28,752,-36,752,-46L752,-927C752,-967,719,-1000,679,-1000L-789,-1000C-830,-1000,-862,-967,-862,-927L-862,872C-862,912,-830,945,-789,945L-165,945C-155,945,-147,937,-147,927L-147,798C-147,788,-155,780,-165,780Z",
  "M765,-498C778,-485,786,-467,786,-448L786,929C786,968,754,1000,714,1000L-714,1000C-754,1000,-786,968,-786,929L-786,-929C-786,-968,-754,-1000,-714,-1000L234,-1000C253,-1000,271,-992,284,-979L765,-498ZM621,-415L201,-835L201,-415L621,-415ZM-97,554L-97,349L35,349C170,349,259,261,259,130C259,0,171,-89,36,-89L-196,-89C-211,-89,-223,-77,-223,-62L-223,554C-223,568,-211,580,-196,580L-124,580C-109,580,-97,568,-97,554ZM-97,243L-19,243C88,243,131,214,131,130C131,59,90,18,20,18L-97,18L-97,243Z",
  "M410,132C283,132,180,236,180,362C180,490,283,592,410,592C537,592,640,490,640,362C640,236,537,132,410,132ZM410,448C363,448,325,410,325,362C325,316,363,278,410,278C457,278,495,316,495,362C495,410,457,448,410,448ZM920,-860L390,-860C390,-937,327,-1000,250,-1000L50,-1000C-27,-1000,-90,-937,-90,-860L-620,-860C-664,-860,-700,-824,-700,-780L-700,-280L-920,-280C-964,-280,-1000,-244,-1000,-200L-1000,920C-1000,964,-964,1000,-920,1000L-80,1000C-36,1000,0,964,0,920L0,880L920,880C964,880,1000,844,1000,800L1000,-780C1000,-824,964,-860,920,-860ZM-110,-700L70,-700L70,-840L230,-840L230,-700L410,-700L410,-580L-110,-580L-110,-700ZM-160,840L-840,840L-840,260L-160,260L-160,840ZM-160,100L-840,100L-840,-120L-160,-120L-160,100ZM820,700L0,700L0,-200C0,-244,-36,-280,-80,-280L-520,-280L-520,-680L-270,-680L-270,-420L570,-420L570,-680L820,-680L820,700ZM480,-260L480,-20C480,-9,489,0,500,0L620,0C631,0,640,-9,640,-20L640,-260C640,-271,631,-280,620,-280L500,-280C489,-280,480,-271,480,-260ZM200,0L320,0C331,0,340,-9,340,-20L340,-160C340,-171,331,-180,320,-180L200,-180C189,-180,180,-171,180,-160L180,-20C180,-9,189,0,200,0Z",
  "M765,-498C778,-485,786,-467,786,-448L786,929C786,968,754,1000,714,1000L-714,1000C-754,1000,-786,968,-786,929L-786,-929C-786,-968,-754,-1000,-714,-1000L234,-1000C253,-1000,271,-992,284,-979L765,-498ZM621,-415L201,-835L201,-415L621,-415ZM-246,83C-246,95,-236,104,-224,104L-151,104C-139,104,-129,94,-129,83C-129,20,-72,-32,0,-32C72,-32,129,20,129,83C129,139,83,188,19,196C-24,202,-58,242,-58,286L-58,357C-58,369,-48,379,-36,379L36,379C48,379,58,369,58,357L58,330C58,317,67,304,80,300C179,268,247,180,246,79C244,-44,136,-146,3,-147C-134,-149,-246,-46,-246,83ZM0,589C39,589,71,557,71,518C71,478,39,446,0,446C-39,446,-71,478,-71,518C-71,557,-39,589,0,589Z",
  "M404,-459L404,-569C404,-579,395,-587,385,-587L-495,-587C-506,-587,-514,-579,-514,-569L-514,-459C-514,-449,-506,-440,-495,-440L385,-440C395,-440,404,-449,404,-459ZM-495,-257C-506,-257,-514,-249,-514,-239L-514,-128C-514,-118,-506,-110,-495,-110L-73,-110C-63,-110,-55,-118,-55,-128L-55,-239C-55,-249,-63,-257,-73,-257L-495,-257ZM367,9C93,9,-128,231,-128,505C-128,778,93,1000,367,1000C641,1000,862,778,862,505C862,231,641,9,367,9ZM614,751C548,817,460,853,367,853C274,853,186,817,120,751C55,685,18,598,18,505C18,411,55,324,120,258C186,192,274,156,367,156C460,156,548,192,614,258C679,324,716,411,716,505C716,598,679,685,614,751ZM367,688ZM294,688L295,701L298,713L303,725L311,735L320,744L330,752L342,757L354,760L367,761L380,760L392,757L404,752L414,744L423,735L431,725L436,713L439,701L440,688L439,675L436,663L431,651L423,641L414,632L404,625L392,619L380,616L367,615L354,616L342,619L330,625L320,632L311,641L303,651L298,663L295,675L294,688ZM321,541L413,541C423,541,431,533,431,523L431,266C431,256,423,248,413,248L321,248C311,248,303,256,303,266L303,523C303,533,311,541,321,541ZM-165,780L-697,780L-697,-835L587,-835L587,-46C587,-36,595,-28,606,-28L734,-28C744,-28,752,-36,752,-46L752,-927C752,-967,719,-1000,679,-1000L-789,-1000C-830,-1000,-862,-967,-862,-927L-862,872C-862,912,-830,945,-789,945L-165,945C-155,945,-147,937,-147,927L-147,798C-147,788,-155,780,-165,780Z",
  "M765,-498C778,-485,786,-467,786,-448L786,929C786,968,754,1000,714,1000L-714,1000C-754,1000,-786,968,-786,929L-786,-929C-786,-968,-754,-1000,-714,-1000L234,-1000C253,-1000,271,-992,284,-979L765,-498ZM621,-415L201,-835L201,-415L621,-415ZM0,121L118,561L119,565L121,568L124,572L127,575L131,577L135,579L139,580L144,580L215,580L219,580L223,579L227,577L231,575L234,572L237,568L239,565L241,561L407,-56L407,-59L407,-62C407,-77,396,-89,381,-89L301,-89L297,-89L292,-88L288,-86L285,-83L281,-80L279,-77L277,-73L275,-69L173,376L62,-69L60,-73L58,-77L56,-81L52,-84L49,-86L45,-88L40,-89L36,-89L-36,-89L-40,-89L-45,-88L-49,-86L-52,-84L-56,-81L-58,-77L-60,-73L-62,-69L-173,375L-276,-69L-277,-73L-279,-77L-282,-80L-285,-83L-289,-86L-293,-88L-297,-89L-302,-89L-381,-89L-384,-89L-388,-88C-402,-85,-410,-70,-407,-56L-241,561L-240,565L-237,568L-235,572L-231,575L-228,577L-224,579L-220,580L-215,580L-144,580L-139,580L-135,579L-131,577L-127,575L-124,572L-121,568L-119,565L-118,561L0,121Z",
  "M-496,-587C-506,-587,-514,-579,-514,-569L-514,-459C-514,-449,-506,-440,-496,-440L385,-440C395,-440,403,-449,403,-459L403,-569C403,-579,395,-587,385,-587L-496,-587ZM-55,-128L-55,-239C-55,-249,-64,-257,-74,-257L-496,-257C-506,-257,-514,-249,-514,-239L-514,-128C-514,-118,-506,-110,-496,-110L-74,-110C-64,-110,-55,-118,-55,-128ZM-165,780L-697,780L-697,-835L587,-835L587,-46C587,-36,595,-28,605,-28L734,-28C744,-28,752,-36,752,-46L752,-927C752,-967,719,-1000,679,-1000L-789,-1000C-830,-1000,-863,-967,-863,-927L-863,872C-863,912,-830,945,-789,945L-165,945C-155,945,-147,937,-147,927L-147,798C-147,788,-155,780,-165,780ZM73,515C78,436,111,361,167,305C227,245,309,211,394,211C480,211,561,244,622,305C629,312,636,320,643,328L590,369C578,379,582,398,597,402L811,453C822,456,833,447,833,436L835,217C835,201,817,193,805,202L758,238C673,132,541,64,394,64C142,64,-64,264,-74,513C-74,523,-66,532,-55,532L55,532C65,532,73,525,73,515ZM844,532L733,532C724,532,716,540,715,550C711,629,678,703,622,759C561,819,479,853,394,853C308,853,228,820,167,759C160,752,153,744,146,736L199,695C211,686,207,666,192,663L-22,611C-33,608,-44,617,-45,629L-46,847C-46,863,-29,872,-17,862L30,826C116,932,247,1000,394,1000C646,1000,852,801,862,551C863,541,854,532,844,532Z",
  "M765,-498C778,-485,786,-467,786,-448L786,929C786,968,754,1000,714,1000L-714,1000C-754,1000,-786,968,-786,929L-786,-929C-786,-968,-754,-1000,-714,-1000L234,-1000C253,-1000,271,-992,284,-979L765,-498ZM621,-415L201,-835L201,-415L621,-415ZM-482,-839L-482,-696L-339,-696L-339,-839L-482,-839ZM-339,-696L-339,-554L-196,-554L-196,-696L-339,-696ZM-482,-554L-482,-411L-339,-411L-339,-554L-482,-554ZM-339,-411L-339,-268L-196,-268L-196,-411L-339,-411ZM-482,-268L-482,-125L-339,-125L-339,-268L-482,-268ZM-339,-125L-339,18L-196,18L-196,-125L-339,-125ZM-482,18L-482,161L-339,161L-339,18L-482,18ZM-482,161L-482,518L-196,518L-196,161L-482,161ZM-375,268L-304,268L-304,411L-375,411L-375,268Z",
  "M403,-459L403,-569C403,-579,394,-587,384,-587L-496,-587C-506,-587,-515,-579,-515,-569L-515,-459C-515,-449,-506,-440,-496,-440L384,-440C394,-440,403,-449,403,-459ZM-496,-257C-506,-257,-515,-249,-515,-239L-515,-128C-515,-118,-506,-110,-496,-110L-74,-110C-64,-110,-56,-118,-56,-128L-56,-239C-56,-249,-64,-257,-74,-257L-496,-257ZM-166,780L-698,780L-698,-835L586,-835L586,-46C586,-36,594,-28,605,-28L733,-28C743,-28,751,-36,751,-46L751,-927C751,-967,719,-1000,678,-1000L-790,-1000C-831,-1000,-863,-967,-863,-927L-863,872C-863,912,-831,945,-790,945L-166,945C-156,945,-148,937,-148,927L-148,798C-148,788,-156,780,-166,780ZM856,898L642,684C693,616,724,532,724,440C724,217,543,37,320,37C97,37,-83,217,-83,440C-83,663,97,844,320,844C402,844,478,819,542,778L759,995C763,998,768,1000,772,1000C777,1000,782,998,785,995L856,924C863,917,863,905,856,898ZM320,697C178,697,63,582,63,440C63,298,178,183,320,183C462,183,577,298,577,440C577,582,462,697,320,697Z",
  "M765,-498C778,-485,786,-467,786,-448L786,929C786,968,754,1000,714,1000L-714,1000C-754,1000,-786,968,-786,929L-786,-929C-786,-968,-754,-1000,-714,-1000L234,-1000C253,-1000,271,-992,284,-979L765,-498ZM621,-415L201,-835L201,-415L621,-415ZM271,280C237,278,201,281,160,286C106,253,69,207,43,139C44,137,45,131,45,129C46,125,47,121,48,118C58,77,63,48,65,18C66,-4,64,-25,60,-44C53,-86,24,-110,-13,-112C-48,-113,-79,-94,-88,-64C-101,-16,-93,48,-65,156C-101,241,-148,341,-179,396C-222,418,-254,438,-282,460C-318,489,-341,518,-347,550C-350,564,-346,583,-335,599C-324,616,-306,628,-284,629C-230,633,-164,578,-91,452C-84,450,-76,447,-66,444C-61,442,-43,436,-40,435C-23,429,-11,425,1,421C53,404,93,394,129,388C191,421,264,443,312,443C352,443,379,422,389,389C398,361,391,327,372,309C353,290,318,281,271,280ZM-283,566L-283,565L-283,565C-280,557,-276,549,-270,541C-261,526,-247,511,-231,494C-222,485,-213,477,-203,467C-200,465,-185,451,-182,449L-157,425L-175,454C-203,498,-228,530,-249,550C-257,558,-264,563,-269,567C-272,568,-274,570,-275,570C-276,571,-277,571,-278,571L-278,571L-279,571L-280,571L-281,570L-281,570L-282,569L-282,568L-283,568L-283,567L-283,566ZM-2,79L-7,88L-10,78C-17,56,-22,23,-23,-7C-25,-41,-22,-61,-12,-61C3,-61,10,-37,11,-1C11,31,6,65,-2,79ZM-15,210L-11,200L-7,209C19,256,53,296,90,324L98,329L89,331C52,339,18,350,-28,369C-23,367,-76,389,-90,394L-102,398L-95,388C-68,340,-42,282,-15,210ZM337,380C319,387,282,380,215,352L198,345L217,344C269,340,305,343,327,350C336,354,342,358,345,363C348,368,346,374,342,377C341,378,339,379,337,380Z",
  "M403,-569C403,-579,395,-587,385,-587L-496,-587C-506,-587,-514,-579,-514,-569L-514,-459C-514,-449,-506,-440,-496,-440L385,-440C395,-440,403,-449,403,-459L403,-569ZM385,-257L-496,-257C-506,-257,-514,-249,-514,-239L-514,-128C-514,-118,-506,-110,-496,-110L385,-110C395,-110,403,-118,403,-128L403,-239C403,-249,395,-257,385,-257ZM-74,73L-496,73C-506,73,-514,82,-514,92L-514,202C-514,212,-506,220,-496,220L-74,220C-64,220,-55,212,-55,202L-55,92C-55,82,-64,73,-74,73ZM-184,780L-697,780L-697,-835L587,-835L587,-46C587,-36,595,-28,605,-28L734,-28C744,-28,752,-36,752,-46L752,-927C752,-967,719,-1000,679,-1000L-789,-1000C-830,-1000,-863,-967,-863,-927L-863,872C-863,912,-830,945,-789,945L-184,945C-174,945,-165,937,-165,927L-165,798C-165,788,-174,780,-184,780ZM635,609C701,549,743,462,743,365C743,182,595,34,413,34C230,34,82,182,82,365C82,462,124,549,191,609C60,684,-30,822,-37,981C-37,991,-29,1000,-19,1000L92,1000C101,1000,109,992,110,983C119,824,251,697,413,697C574,697,706,824,715,983C716,992,724,1000,733,1000L844,1000C854,1000,863,991,862,981C856,822,765,684,635,609ZM413,181C514,181,596,263,596,365C596,466,514,548,413,548C311,548,229,466,229,365C229,263,311,181,413,181Z",
  "M765,-498L284,-979C271,-992,253,-1000,234,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-448C786,-467,778,-485,765,-498ZM-250,-246C-201,-246,-161,-206,-161,-156C-161,-107,-201,-67,-250,-67C-299,-67,-339,-107,-339,-156C-339,-206,-299,-246,-250,-246ZM411,411L-411,411C-426,411,-434,394,-425,382L-202,98C-195,89,-181,89,-174,98L-82,215L92,-6C99,-16,112,-16,120,-6L424,382C434,394,425,411,411,411ZM201,-415L201,-835L621,-415L201,-415Z",
  "M304,361C301,356,295,353,289,353L188,353C173,353,164,370,173,382L342,616C350,626,365,626,372,616L634,254C643,242,634,225,619,225L517,225C511,225,506,228,503,232L357,434L304,361ZM404,-472L404,-583C404,-593,395,-601,385,-601L-495,-601C-506,-601,-514,-593,-514,-583L-514,-472C-514,-462,-506,-454,-495,-454L385,-454C395,-454,404,-462,404,-472ZM-495,-271C-506,-271,-514,-262,-514,-252L-514,-142C-514,-132,-506,-124,-495,-124L-73,-124C-63,-124,-55,-132,-55,-142L-55,-252C-55,-262,-63,-271,-73,-271L-495,-271ZM-73,780L-697,780L-697,-835L587,-835L587,-156C587,-146,595,-138,606,-138L734,-138C744,-138,752,-146,752,-156L752,-927C752,-967,719,-1000,679,-1000L-789,-1000C-830,-1000,-862,-967,-862,-927L-862,872C-862,912,-830,945,-789,945L-73,945C-63,945,-55,937,-55,927L-55,798C-55,788,-63,780,-73,780ZM850,44L410,-109C408,-110,406,-110,404,-110C402,-110,400,-110,398,-109L-43,44C-50,47,-55,53,-55,61L-55,637C-55,643,-53,648,-48,652L392,996C396,999,400,1000,404,1000C408,1000,412,999,415,996L855,652C860,648,862,643,862,637L862,61C862,53,857,47,850,44ZM720,577L404,825L87,577L87,149L404,39L720,149L720,577Z",
  "M764,-458L222,-980C208,-993,191,-1000,172,-1000L-482,-1000C-492,-1000,-500,-992,-500,-982L-500,-857C-500,-847,-492,-839,-482,-839L136,-839L625,-369L625,696C625,706,633,714,643,714L768,714C778,714,786,706,786,696L786,-407C786,-427,778,-445,764,-458ZM92,-693C79,-707,61,-714,42,-714L-714,-714C-754,-714,-786,-682,-786,-643L-786,929C-786,968,-754,1000,-714,1000L429,1000C468,1000,500,968,500,929L500,-256C500,-275,492,-293,479,-306L92,-693ZM125,538C125,546,117,554,108,554L-394,554C-403,554,-411,546,-411,538L-411,444C-411,436,-403,429,-394,429L108,429C117,429,125,436,125,444L125,538ZM125,47C125,55,117,63,108,63L-80,63L-80,252C-80,261,-87,268,-96,268L-190,268C-198,268,-205,261,-205,252L-205,63L-394,63C-403,63,-411,55,-411,47L-411,-47C-411,-56,-403,-63,-394,-62L-205,-62L-205,-252C-205,-261,-198,-268,-190,-268L-96,-268C-87,-268,-80,-261,-80,-252L-80,-62L108,-62C117,-62,125,-56,125,-47L125,47Z",
  "M765,-499L284,-979C271,-992,253,-1000,234,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-448C786,-467,778,-485,765,-499ZM621,-415L201,-415L201,-835L621,-415ZM625,839L-625,839L-625,-839L49,-839L49,-357C49,-305,91,-263,143,-263L625,-263L625,839ZM71,-89C71,-99,63,-107,54,-107L-54,-107C-63,-107,-71,-99,-71,-89L-71,152L-312,152C-322,152,-330,160,-330,170L-330,277C-330,287,-322,295,-312,295L-71,295L-71,536C-71,546,-63,554,-54,554L54,554C63,554,71,546,71,536L71,295L312,295C322,295,330,287,330,277L330,170C330,160,322,152,312,152L71,152L71,-89Z",
  "M714,-1000L-482,-1000C-492,-1000,-500,-992,-500,-982L-500,-857C-500,-847,-492,-839,-482,-839L625,-839L625,696C625,706,633,714,643,714L768,714C778,714,786,706,786,696L786,-929C786,-968,754,-1000,714,-1000ZM429,-714L-714,-714C-754,-714,-786,-682,-786,-643L-786,542C-786,561,-778,579,-765,592L-378,979C-373,984,-367,988,-361,991L-361,996L-352,996C-344,998,-336,1000,-327,1000L429,1000C468,1000,500,968,500,929L500,-643C500,-682,468,-714,429,-714ZM-290,857L-291,857L-625,523L-625,522L-290,522L-290,857Z",
  "M765,-499L284,-979C271,-992,253,-1000,234,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-448C786,-467,778,-485,765,-499ZM621,-415L201,-415L201,-835L621,-415ZM625,839L-625,839L-625,-839L49,-839L49,-357C49,-305,91,-263,143,-263L625,-263L625,839ZM5,152L-133,-77C-138,-85,-147,-90,-156,-90L-242,-90C-247,-90,-252,-88,-256,-85C-269,-77,-273,-61,-265,-48L-81,243L-267,539C-270,544,-271,548,-271,554C-271,568,-259,580,-244,580L-167,580C-158,580,-149,575,-144,568L-4,341L135,567C140,575,148,580,157,580L241,580C246,580,251,579,256,576C268,568,272,551,264,539L76,248L267,-48C269,-52,271,-57,271,-62C271,-77,259,-89,244,-89L164,-89C155,-89,146,-84,141,-76L5,152Z",
  "M714,-893L473,-893L473,-982C473,-992,465,-1000,455,-1000L330,-1000C321,-1000,312,-992,312,-982L312,-893L-27,-893L-27,-982C-27,-992,-35,-1000,-45,-1000L-170,-1000C-179,-1000,-188,-992,-188,-982L-188,-893L-429,-893C-468,-893,-500,-861,-500,-821L-500,-554L-714,-554C-754,-554,-786,-522,-786,-482L-786,929C-786,968,-754,1000,-714,1000L429,1000C468,1000,500,968,500,929L500,714L714,714C754,714,786,682,786,643L786,-821C786,-861,754,-893,714,-893ZM339,-58L4,-58L4,-393L5,-393L339,-58L339,-58ZM625,554L500,554L500,-125L71,-554L-339,-554L-339,-732L-188,-732L-188,-661C-188,-651,-179,-643,-170,-643L-45,-643C-35,-643,-27,-651,-27,-661L-27,-732L312,-732L312,-661C312,-651,321,-643,330,-643L455,-643C465,-643,473,-651,473,-661L473,-732L625,-732L625,554Z",
  "M765,-499L284,-979C271,-992,253,-1000,234,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-448C786,-467,778,-485,765,-499ZM621,-415L201,-415L201,-835L621,-415ZM625,839L-625,839L-625,-839L49,-839L49,-357C49,-305,91,-263,143,-263L625,-263L625,839ZM0,518ZM-89,518L-88,533L-84,547L-79,560L-70,573L-60,584L-49,593L-36,600L-22,604L-7,607L7,607L22,604L36,600L49,593L60,584L70,573L79,560L84,547L88,533L89,518L88,503L84,489L79,475L70,463L60,452L49,443L36,436L22,431L7,429L-7,429L-22,431L-36,436L-49,443L-60,452L-70,463L-79,475L-84,489L-88,503L-89,518ZM-54,286L54,286C63,286,71,278,71,268L71,-143C71,-153,63,-161,54,-161L-54,-161C-63,-161,-71,-153,-71,-143L-71,268C-71,278,-63,286,-54,286Z",
  "M600,-680L-920,-680C-964,-680,-1000,-644,-1000,-600L-1000,920C-1000,964,-964,1000,-920,1000L600,1000C644,1000,680,964,680,920L680,-600C680,-644,644,-680,600,-680ZM210,235C210,246,201,255,190,255L-510,255C-521,255,-530,246,-530,235L-530,115C-530,104,-521,95,-510,95L190,95C201,95,210,104,210,115L210,235ZM920,-1000L-620,-1000C-631,-1000,-640,-991,-640,-980L-640,-840C-640,-829,-631,-820,-620,-820L820,-820L820,620C820,631,829,640,840,640L980,640C991,640,1000,631,1000,620L1000,-920C1000,-964,964,-1000,920,-1000Z",
  "M43,139L44,136C57,83,73,16,60,-44C52,-92,17,-110,-13,-111C-48,-113,-80,-93,-88,-64C-102,-10,-89,63,-65,156C-96,229,-144,334,-179,396C-246,431,-334,483,-347,550C-350,562,-347,578,-340,592C-331,607,-318,619,-303,625C-296,628,-288,630,-279,630C-239,630,-176,598,-91,452C-78,448,-65,444,-52,439C9,419,72,397,129,388C192,421,264,443,312,443C360,443,379,415,387,397C399,367,393,329,373,309C343,280,272,272,160,286C105,253,69,207,43,139ZM-202,478C-233,523,-256,546,-269,556C-254,528,-225,499,-202,478ZM-6,-47C5,-27,4,33,-5,63C-16,19,-18,-44,-11,-52C-9,-52,-8,-50,-6,-47ZM-10,222C14,263,44,298,77,325C29,336,-15,354,-54,370C-63,374,-73,377,-81,381C-52,327,-27,266,-10,222ZM338,368C338,368,338,369,337,370L336,370L336,371C334,372,316,382,237,351C327,347,337,368,338,368ZM765,-499L284,-979C271,-992,253,-1000,234,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-448C786,-467,778,-485,765,-499ZM621,-415L201,-415L201,-835L621,-415ZM625,839L-625,839L-625,-839L49,-839L49,-357C49,-305,91,-263,143,-263L625,-263L625,839Z",
  "M410,278C363,278,325,316,325,362C325,410,363,448,410,448C457,448,495,410,495,362C495,316,457,278,410,278ZM920,-860L390,-860C390,-937,327,-1000,250,-1000L50,-1000C-27,-1000,-90,-937,-90,-860L-620,-860C-664,-860,-700,-824,-700,-780L-700,-280L-920,-280C-964,-280,-1000,-244,-1000,-200L-1000,920C-1000,964,-964,1000,-920,1000L-80,1000C-36,1000,0,964,0,920L0,880L920,880C964,880,1000,844,1000,800L1000,-780C1000,-824,964,-860,920,-860ZM-160,840L-840,840L-840,260L-160,260L-160,840ZM-160,100L-840,100L-840,-120L-160,-120L-160,100ZM-110,-580L-110,-700L70,-700L70,-840L230,-840L230,-700L410,-700L410,-580L-110,-580ZM340,-160L340,-20C340,-9,331,0,320,0L200,0C189,0,180,-9,180,-20L180,-160C180,-171,189,-180,200,-180L320,-180C331,-180,340,-171,340,-160ZM410,592C283,592,180,490,180,362C180,236,283,132,410,132C537,132,640,236,640,362C640,490,537,592,410,592ZM640,-20C640,-9,631,0,620,0L500,0C489,0,480,-9,480,-20L480,-260C480,-271,489,-280,500,-280L620,-280C631,-280,640,-271,640,-260L640,-20ZM410,132C283,132,180,236,180,362C180,490,283,592,410,592C537,592,640,490,640,362C640,236,537,132,410,132ZM410,448C363,448,325,410,325,362C325,316,363,278,410,278C457,278,495,316,495,362C495,410,457,448,410,448Z",
  "M92,-6L-82,215L-174,98C-181,89,-195,89,-202,98L-425,382C-434,394,-425,411,-410,411L411,411C426,411,434,394,425,382L120,-6C113,-16,99,-16,92,-6ZM-250,-156ZM-339,-156L-338,-141L-334,-126L-327,-112L-318,-99L-307,-88L-295,-79L-281,-72L-266,-68L-250,-67L-234,-68L-219,-72L-205,-79L-193,-88L-182,-99L-173,-112L-166,-126L-162,-141L-161,-156L-162,-171L-166,-185L-171,-199L-180,-211L-190,-222L-201,-231L-214,-238L-228,-243L-243,-245L-257,-245L-272,-243L-286,-238L-299,-231L-310,-222L-320,-211L-329,-199L-334,-185L-338,-171L-339,-156ZM765,-499L284,-979C271,-992,253,-1000,234,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-448C786,-467,778,-485,765,-499ZM621,-415L201,-415L201,-835L621,-415ZM625,839L-625,839L-625,-839L49,-839L49,-357C49,-305,91,-263,143,-263L625,-263L625,839Z",
  "M765,-499L284,-979C271,-992,253,-1000,234,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-448C786,-467,778,-485,765,-499ZM621,-415L201,-415L201,-835L621,-415ZM625,839L-625,839L-625,-839L49,-839L49,-357C49,-305,91,-263,143,-263L625,-263L625,839ZM-185,-69C-190,-79,-199,-85,-210,-85L-288,-85C-303,-85,-315,-73,-315,-58L-315,549C-315,564,-303,576,-288,576L-227,576C-213,576,-201,564,-201,549L-201,156L-52,492C-47,501,-38,508,-27,508L27,508C37,508,47,501,51,492L200,156L200,549C200,564,212,576,227,576L288,576C303,576,315,564,315,549L315,-58C315,-73,303,-85,288,-85L210,-85C200,-85,190,-79,186,-69L0,358L-185,-69Z",
  "M920,-534L22,-534L-271,-814C-275,-818,-280,-820,-285,-820L-920,-820C-964,-820,-1000,-784,-1000,-740L-1000,740C-1000,784,-964,820,-920,820L920,820C964,820,1000,784,1000,740L1000,-454C1000,-498,964,-534,920,-534Z",
  "M765,-498L284,-979C271,-992,253,-1000,234,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-448C786,-467,778,-485,765,-498ZM621,-415L201,-415L201,-835L621,-415ZM625,839L-625,839L-625,-839L49,-839L49,-357C49,-305,91,-263,143,-263L625,-263L625,839ZM-246,83C-246,95,-236,104,-224,104L-151,104C-139,104,-129,94,-129,83C-129,20,-72,-32,0,-32C72,-32,129,20,129,83C129,139,83,188,19,196C-24,202,-58,242,-58,286L-58,357C-58,369,-48,379,-36,379L36,379C48,379,58,369,58,357L58,330C58,317,67,304,80,300C179,268,247,180,246,79C244,-44,136,-146,3,-147C-134,-149,-246,-46,-246,83ZM0,518ZM-71,518L-70,530L-67,542L-62,554L-55,564L-46,573L-36,580L-24,585L-12,588L0,589L12,588L24,585L36,580L46,573L55,564L62,554L67,542L70,530L71,518L70,505L67,493L62,482L55,472L46,463L36,456L24,451L12,448L0,446L-12,448L-24,451L-36,456L-46,463L-55,472L-62,482L-67,493L-70,505L-71,518Z",
  "M929,-152L688,-152L688,-405C688,-445,656,-477,616,-477L-87,-477L-349,-727C-352,-730,-357,-732,-361,-732L-929,-732C-968,-732,-1000,-700,-1000,-661L-1000,661C-1000,700,-968,732,-929,732L629,732C658,732,685,715,696,688L995,-54C998,-62,1000,-71,1000,-80C1000,-120,968,-152,929,-152ZM527,-152L-612,-152C-641,-152,-667,-134,-678,-107L-839,293L-839,-571L-419,-571L-152,-316L527,-316L527,-152Z",
  "M-196,-80C-206,-80,-214,-72,-214,-62L-214,554C-214,563,-206,571,-196,571L-124,571C-114,571,-106,563,-106,554L-106,340L35,340C168,340,250,254,250,130C250,9,169,-80,36,-80L-196,-80ZM140,130C140,227,81,251,-19,251L-106,251L-106,9L19,9C95,9,140,53,140,130ZM765,-499L284,-979C271,-992,253,-1000,234,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-448C786,-467,778,-485,765,-499ZM621,-415L201,-415L201,-835L621,-415ZM625,839L-625,839L-625,-839L49,-839L49,-357C49,-305,91,-263,143,-263L625,-263L625,839Z",
  "M714,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,-429L786,-429L786,-929C786,-968,754,-1000,714,-1000ZM-500,-625C-549,-625,-589,-665,-589,-714C-589,-764,-549,-804,-500,-804C-451,-804,-411,-764,-411,-714C-411,-665,-451,-625,-500,-625ZM-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,429L-786,429L-786,929ZM-500,625C-451,625,-411,665,-411,714C-411,764,-451,804,-500,804C-549,804,-589,764,-589,714C-589,665,-549,625,-500,625ZM-786,286L786,286L786,-286L-786,-286L-786,286ZM-500,-89C-451,-89,-411,-49,-411,0C-411,49,-451,89,-500,89C-549,89,-589,49,-589,0C-589,-49,-549,-89,-500,-89Z",
  "M765,-499L284,-979C271,-992,253,-1000,234,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-448C786,-467,778,-485,765,-499ZM621,-415L201,-415L201,-835L621,-415ZM625,839L-625,839L-625,-839L49,-839L49,-357C49,-305,91,-263,143,-263L625,-263L625,839ZM36,-89L-36,-89C-48,-89,-59,-81,-62,-69L-173,375L-276,-69C-279,-81,-289,-89,-302,-89L-381,-89C-383,-89,-385,-89,-388,-88C-402,-85,-410,-70,-407,-56L-241,560C-238,572,-227,580,-215,580L-144,580C-132,580,-121,572,-118,560L0,121L118,560C121,572,132,580,144,580L215,580C227,580,238,572,241,560L407,-56C407,-58,408,-60,408,-62C408,-77,396,-89,381,-89L301,-89C289,-89,278,-81,275,-69L173,376L62,-69C59,-81,48,-89,36,-89Z",
  "M714,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,252C-786,251,-785,250,-783,250L-294,250L-282,305C-255,439,-137,536,0,536C137,536,255,439,282,305L294,250L783,250C785,250,786,251,786,252L786,-929C786,-968,754,-1000,714,-1000ZM446,-42C446,-33,438,-25,429,-25L-429,-25C-438,-25,-446,-33,-446,-42L-446,-150C-446,-159,-438,-167,-429,-167L429,-167C438,-167,446,-159,446,-150L446,-42ZM446,-400C446,-390,438,-382,429,-382L-429,-382C-438,-382,-446,-390,-446,-400L-446,-507C-446,-517,-438,-525,-429,-525L429,-525C438,-525,446,-517,446,-507L446,-400ZM783,391L406,391C381,464,335,530,275,580C198,644,100,679,0,679C-100,679,-198,643,-275,580C-335,530,-381,464,-406,391L-783,391C-785,391,-786,390,-786,388L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,388C786,390,785,391,783,391Z",
  "M765,-499L284,-979C271,-992,253,-1000,234,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-448C786,-467,778,-485,765,-499ZM621,-415L201,-415L201,-835L621,-415ZM625,839L-625,839L-625,-839L49,-839L49,-357C49,-305,91,-263,143,-263L625,-263L625,839Z",
  "M714,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,-429L786,-429L786,-929C786,-968,754,-1000,714,-1000ZM-125,-661C-125,-651,-133,-643,-143,-643L-554,-643C-563,-643,-571,-651,-571,-661L-571,-768C-571,-778,-563,-786,-554,-786L-143,-786C-133,-786,-125,-778,-125,-768L-125,-661ZM-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,429L-786,429L-786,929ZM500,625C549,625,589,665,589,714C589,764,549,804,500,804C451,804,411,764,411,714C411,665,451,625,500,625ZM-786,286L786,286L786,-286L-786,-286L-786,286ZM-571,-54C-571,-63,-563,-71,-554,-71L-143,-71C-133,-71,-125,-63,-125,-54L-125,54C-125,63,-133,71,-143,71L-554,71C-563,71,-571,63,-571,54L-571,-54Z",
  "M-482,-268L-339,-268L-339,-125L-482,-125ZM-482,156L-482,513L-196,513L-196,156L-339,156L-339,18L-482,18L-482,156ZM-304,263L-304,406L-375,406L-375,263L-304,263ZM-339,-411L-196,-411L-196,-268L-339,-268ZM-482,-554L-339,-554L-339,-411L-482,-411ZM-339,-125L-196,-125L-196,18L-339,18ZM-339,-696L-196,-696L-196,-554L-339,-554ZM765,-499L284,-979C271,-992,253,-1000,234,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-448C786,-467,778,-485,765,-499ZM621,-415L201,-415L201,-835L621,-415ZM625,839L-625,839L-625,-839L-482,-839L-482,-696L-339,-696L-339,-839L49,-839L49,-357C49,-305,91,-263,143,-263L625,-263L625,839Z",
  "M929,-643L571,-643L571,-768C571,-778,563,-786,554,-786L429,-786C419,-786,411,-778,411,-768L411,-643L80,-643L80,-768C80,-778,72,-786,62,-786L-62,-786C-72,-786,-80,-778,-80,-768L-80,-643L-411,-643L-411,-768C-411,-778,-419,-786,-429,-786L-554,-786C-563,-786,-571,-778,-571,-768L-571,-643L-929,-643C-968,-643,-1000,-611,-1000,-571L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-571C1000,-611,968,-643,929,-643ZM-196,393C-196,403,-204,411,-214,411L-625,411C-635,411,-643,403,-643,393L-643,286C-643,276,-635,268,-625,268L-214,268C-204,268,-196,276,-196,286L-196,393ZM-196,89C-196,99,-204,107,-214,107L-625,107C-635,107,-643,99,-643,89L-643,-18C-643,-28,-635,-36,-625,-36L-214,-36C-204,-36,-196,-28,-196,-18L-196,89ZM640,-115L271,396C257,416,228,416,214,396L-41,43C-50,31,-41,15,-27,15L96,15C107,15,118,20,125,29L242,192L474,-128C481,-138,491,-143,503,-143L625,-143C640,-143,648,-126,640,-115Z",
  "M765,-499L284,-979C271,-992,253,-1000,234,-1000L-714,-1000C-754,-1000,-786,-968,-786,-929L-786,929C-786,968,-754,1000,-714,1000L714,1000C754,1000,786,968,786,929L786,-448C786,-467,778,-485,765,-499ZM621,-415L201,-415L201,-835L621,-415ZM625,839L-625,839L-625,-839L49,-839L49,-357C49,-305,91,-263,143,-263L625,-263L625,839ZM-18,237L-429,237C-438,237,-446,245,-446,254L-446,362C-446,371,-438,379,-429,379L-18,379C-8,379,0,371,0,362L0,254C0,245,-8,237,-18,237ZM-446,-49L-446,58C-446,68,-438,76,-429,76L429,76C438,76,446,68,446,58L446,-49C446,-59,438,-67,429,-67L-429,-67C-438,-67,-446,-59,-446,-49Z",
  "M929,-786L-929,-786C-968,-786,-1000,-754,-1000,-714L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-714C1000,-754,968,-786,929,-786ZM-388,-464C-310,-464,-246,-400,-246,-321C-246,-243,-310,-179,-388,-179C-467,-179,-531,-243,-531,-321C-531,-400,-467,-464,-388,-464ZM759,511C756,514,751,516,747,516L-747,516C-757,516,-765,508,-765,498C-765,494,-764,490,-761,486L-381,35C-375,28,-363,27,-356,33C-355,34,-354,34,-353,35L-131,299L221,-120C228,-127,239,-128,247,-122C247,-121,248,-121,249,-120L761,486C767,494,766,505,759,511Z",
  "M714,-1000L-482,-1000C-492,-1000,-500,-992,-500,-982L-500,-857C-500,-847,-492,-839,-482,-839L625,-839L625,696C625,706,633,714,643,714L768,714C778,714,786,706,786,696L786,-929C786,-968,754,-1000,714,-1000ZM429,-714L-714,-714C-754,-714,-786,-682,-786,-643L-786,542C-786,561,-778,579,-765,592L-378,979C-373,984,-367,988,-361,991L-361,996L-352,996C-344,998,-336,1000,-327,1000L429,1000C468,1000,500,968,500,929L500,-643C500,-682,468,-714,429,-714ZM-362,768L-554,576L-362,576L-362,768ZM339,839L-219,839L-219,522C-219,473,-259,433,-308,433L-625,433L-625,-554L339,-554L339,839Z",
  "M-310,-225C-374,-225,-426,-173,-426,-109C-426,-45,-374,7,-310,7C-247,7,-195,-45,-195,-109C-195,-173,-247,-225,-310,-225ZM929,-786L-929,-786C-968,-786,-1000,-754,-1000,-714L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-714C1000,-754,968,-786,929,-786ZM214,-205C214,-215,217,-223,219,-223L495,-223C498,-223,500,-215,500,-205L500,-98C500,-88,498,-80,495,-80L219,-80C217,-80,214,-88,214,-98L214,-205ZM22,359L-76,359C-85,359,-93,352,-93,343C-102,230,-196,141,-310,141C-425,141,-519,230,-527,343C-528,352,-535,359,-545,359L-643,359C-653,359,-661,351,-661,341C-654,222,-589,118,-494,59C-535,15,-559,-44,-559,-109C-559,-248,-448,-359,-310,-359C-173,-359,-62,-248,-62,-109C-62,-44,-86,15,-127,59C-31,118,33,222,40,341C41,351,33,359,22,359ZM645,241L230,241C221,241,214,233,214,223L214,116C214,106,221,98,230,98L645,98C653,98,660,106,660,116L660,223L661,223C661,233,654,241,645,241Z",
  "M714,-893L473,-893L473,-982C473,-992,465,-1000,455,-1000L330,-1000C321,-1000,312,-992,312,-982L312,-893L-27,-893L-27,-982C-27,-992,-35,-1000,-45,-1000L-170,-1000C-179,-1000,-188,-992,-188,-982L-188,-893L-429,-893C-468,-893,-500,-861,-500,-821L-500,-554L-714,-554C-754,-554,-786,-522,-786,-482L-786,929C-786,968,-754,1000,-714,1000L429,1000C468,1000,500,968,500,929L500,714L714,714C754,714,786,682,786,643L786,-821C786,-861,754,-893,714,-893ZM339,839L-625,839L-625,-393L-138,-393L-138,-4C-138,45,-98,85,-49,85L339,85L339,839ZM339,-58L4,-58L4,-393L5,-393L339,-58L339,-58ZM625,554L500,554L500,-125L71,-554L-339,-554L-339,-732L-188,-732L-188,-661C-188,-651,-179,-643,-170,-643L-45,-643C-35,-643,-27,-651,-27,-661L-27,-732L312,-732L312,-661C312,-651,321,-643,330,-643L455,-643C465,-643,473,-651,473,-661L473,-732L625,-732L625,554Z",
  "M929,-786L-929,-786C-968,-786,-1000,-754,-1000,-714L-1000,-357L1000,-357L1000,-714C1000,-754,968,-786,929,-786ZM-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-161L-1000,-161L-1000,714ZM292,304C292,294,300,286,310,286L679,286C688,286,696,294,696,304L696,464C696,474,688,482,679,482L310,482C300,482,292,474,292,464L292,304Z",
  "M-495,-601C-506,-601,-514,-593,-514,-583L-514,-472C-514,-462,-506,-454,-495,-454L385,-454C395,-454,404,-462,404,-472L404,-583C404,-593,395,-601,385,-601L-495,-601ZM-73,-271L-495,-271C-506,-271,-514,-262,-514,-252L-514,-142C-514,-132,-506,-124,-495,-124L-73,-124C-63,-124,-55,-132,-55,-142L-55,-252C-55,-262,-63,-271,-73,-271ZM-183,780L-697,780L-697,-835L587,-835L587,-101C587,-91,595,-83,606,-83L734,-83C744,-83,752,-91,752,-101L752,-927C752,-967,719,-1000,679,-1000L-789,-1000C-830,-1000,-862,-967,-862,-927L-862,872C-862,912,-830,945,-789,945L-183,945C-173,945,-165,937,-165,927L-165,798C-165,788,-173,780,-183,780ZM826,578L495,578L495,494C602,462,679,364,679,248C679,106,564,-9,422,-9C280,-9,165,106,165,248C165,364,242,462,349,494L349,578L18,578C-2,578,-18,594,-18,615L-18,963C-18,983,-2,1000,18,1000L826,1000C846,1000,862,983,862,963L862,615C862,594,846,578,826,578ZM307,248C307,184,359,133,422,133C485,133,537,184,537,248C537,311,485,362,422,362C359,362,307,311,307,248ZM720,858L124,858L124,720L720,720L720,858Z",
  "M929,-786L-929,-786C-968,-786,-1000,-754,-1000,-714L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-714C1000,-754,968,-786,929,-786ZM723,-352L60,312C53,319,41,319,34,312L-221,56L-606,441C-613,448,-625,448,-631,441L-714,359C-721,352,-721,341,-714,334L-234,-146C-227,-153,-216,-153,-209,-146L47,109L615,-459C622,-466,633,-466,640,-459L722,-377C729,-370,729,-359,723,-352Z",
  "M-80,-252C-80,-261,-87,-268,-96,-268L-190,-268C-198,-268,-205,-261,-205,-252L-205,-62L-394,-62C-403,-62,-411,-56,-411,-47L-411,47C-411,55,-403,63,-394,63L-205,63L-205,252C-205,261,-198,268,-190,268L-96,268C-87,268,-80,261,-80,252L-80,63L108,63C117,63,125,55,125,47L125,-47C125,-56,117,-63,108,-62L-80,-62L-80,-252ZM108,429L-394,429C-403,429,-411,436,-411,444L-411,538C-411,546,-403,554,-394,554L108,554C117,554,125,546,125,538L125,444C125,436,117,429,108,429ZM92,-693C79,-707,61,-714,42,-714L-714,-714C-754,-714,-786,-682,-786,-643L-786,929C-786,968,-754,1000,-714,1000L429,1000C468,1000,500,968,500,929L500,-256C500,-275,492,-293,479,-306L92,-693ZM339,839L-625,839L-625,-554L5,-554L339,-219L339,839ZM764,-458L222,-980C208,-993,191,-1000,172,-1000L-482,-1000C-492,-1000,-500,-992,-500,-982L-500,-857C-500,-847,-492,-839,-482,-839L136,-839L625,-369L625,696C625,706,633,714,643,714L768,714C778,714,786,706,786,696L786,-407C786,-427,778,-445,764,-458Z",
  "M929,-784L418,-784C308,-784,201,-753,109,-693L0,-623L-109,-693C-201,-753,-308,-784,-418,-784L-929,-784C-968,-784,-1000,-752,-1000,-713L-1000,555C-1000,595,-968,627,-929,627L-418,627C-308,627,-201,658,-109,717L-10,781C-7,783,-4,784,0,784C3,784,6,783,9,781L108,717C201,658,308,627,418,627L929,627C968,627,1000,595,1000,555L1000,-713C1000,-752,968,-784,929,-784ZM-241,92C-241,101,-248,109,-257,109L-672,109C-680,109,-688,101,-688,92L-688,-8C-688,-18,-680,-25,-672,-25L-257,-25C-248,-25,-241,-18,-241,-8L-241,92ZM-241,-221C-241,-211,-248,-204,-257,-204L-672,-204C-680,-204,-688,-211,-688,-221L-688,-321C-688,-330,-680,-338,-672,-338L-257,-338C-248,-338,-241,-330,-241,-321L-241,-221ZM688,92C688,101,680,109,672,109L257,109C248,109,241,101,241,92L241,-8C241,-18,248,-25,257,-25L671,-25C680,-25,687,-18,687,-8L687,92ZM688,-221C688,-211,680,-204,672,-204L257,-204C248,-204,241,-211,241,-221L241,-321C241,-330,248,-338,257,-338L671,-338C680,-338,687,-330,687,-321L687,-221Z",
  "M600,-680L-920,-680C-964,-680,-1000,-644,-1000,-600L-1000,920C-1000,964,-964,1000,-920,1000L600,1000C644,1000,680,964,680,920L680,-600C680,-644,644,-680,600,-680ZM500,820L-820,820L-820,-500L500,-500L500,820ZM920,-1000L-620,-1000C-631,-1000,-640,-991,-640,-980L-640,-840C-640,-829,-631,-820,-620,-820L820,-820L820,620C820,631,829,640,840,640L980,640C991,640,1000,631,1000,620L1000,-920C1000,-964,964,-1000,920,-1000ZM-530,95L210,95L210,255L-530,255Z",
  "M929,-643L571,-643L571,-768C571,-778,563,-786,554,-786L429,-786C419,-786,411,-778,411,-768L411,-643L80,-643L80,-768C80,-778,72,-786,62,-786L-62,-786C-72,-786,-80,-778,-80,-768L-80,-643L-411,-643L-411,-768C-411,-778,-419,-786,-429,-786L-554,-786C-563,-786,-571,-778,-571,-768L-571,-643L-929,-643C-968,-643,-1000,-611,-1000,-571L-1000,714C-1000,754,-968,786,-929,786L929,786C968,786,1000,754,1000,714L1000,-571C1000,-611,968,-643,929,-643ZM333,500L235,500C225,500,218,493,217,483C208,370,114,281,0,281C-114,281,-208,371,-217,483C-218,493,-225,500,-235,500L-333,500C-343,500,-351,492,-350,481C-344,362,-279,259,-184,200C-224,155,-249,96,-249,31C-249,-107,-138,-219,0,-219C137,-219,248,-107,248,31C248,96,224,155,183,200C279,259,344,362,350,481C351,492,343,500,333,500ZM0,-85C-64,-85,-115,-33,-115,31C-115,95,-64,147,0,147C64,147,115,95,115,31C115,-33,64,-85,0,-85Z",
  "M771,-744L33,-995C24,-998,12,-1000,0,-1000C-12,-1000,-24,-998,-33,-995L-771,-744C-789,-738,-804,-717,-804,-698L-804,351C-804,370,-792,395,-777,407L-28,991C-20,997,-10,1000,0,1000C10,1000,20,997,27,991L776,407C791,396,804,370,804,351L804,-698C804,-717,789,-737,771,-744ZM648,309L0,814L-648,309L-648,-620L0,-841L648,-620L648,309ZM-237,36L-406,205C-412,212,-412,223,-406,229L-332,303C-325,310,-314,310,-307,303L-139,135C-18,211,144,197,250,91C372,-31,372,-229,250,-352C127,-474,-71,-474,-193,-352C-299,-246,-313,-84,-237,36ZM-95,-253C-27,-321,83,-321,151,-253C219,-185,219,-75,151,-7C83,61,-27,61,-95,-7C-163,-75,-163,-185,-95,-253Z",
  "M771,-744L33,-995C24,-998,12,-1000,0,-1000C-12,-1000,-24,-998,-33,-995L-771,-744C-789,-738,-804,-717,-804,-698L-804,351C-804,370,-792,395,-777,407L-28,991C-20,997,-10,1000,0,1000C10,1000,20,997,27,991L776,407C791,396,804,370,804,351L804,-698C804,-717,789,-737,771,-744ZM648,309L0,814L-648,309L-648,-620L0,-841L648,-620L648,309ZM-177,-422L-277,-422C-281,-422,-284,-421,-288,-419C-298,-414,-302,-400,-296,-390L-105,-39L-203,-39C-215,-39,-225,-30,-225,-18L-225,29C-225,41,-215,50,-203,50L-66,50L-66,115L-203,115C-215,115,-225,125,-225,137L-225,183C-225,195,-215,205,-203,205L-66,205L-66,317C-66,329,-56,339,-44,339L45,339C57,339,67,329,67,317L67,205L205,205C217,205,227,195,227,183L227,137C227,125,217,115,205,115L67,115L67,50L205,50C217,50,227,41,227,29L227,-18C227,-30,217,-39,205,-39L106,-39L296,-390C298,-393,299,-396,299,-400C299,-412,289,-422,277,-422L179,-422C171,-422,164,-417,160,-410L1,-96L-158,-410C-161,-417,-169,-422,-177,-422Z",
  "M920,-1000C910,-1000,901,-998,891,-994L-550,-415L-960,-415C-982,-415,-1000,-397,-1000,-374L-1000,374C-1000,397,-982,415,-960,415L-706,415C-715,444,-720,475,-720,506C-720,671,-586,805,-420,805C-282,805,-165,711,-130,584L891,994C901,998,911,1000,920,1000C962,1000,1000,965,1000,917L1000,-917C1000,-965,962,-1000,920,-1000ZM-420,626C-486,626,-540,572,-540,506C-540,478,-530,451,-513,430L-300,515C-305,577,-357,626,-420,626Z",
  "M771,-744L33,-995C24,-998,12,-1000,0,-1000C-12,-1000,-24,-998,-33,-995L-771,-744C-789,-738,-804,-717,-804,-698L-804,351C-804,370,-792,395,-777,407L-28,991C-20,997,-10,1000,0,1000C10,1000,20,997,27,991L776,407C791,396,804,370,804,351L804,-698C804,-717,789,-737,771,-744ZM648,309L0,814L-648,309L-648,-620L0,-841L648,-620L648,309ZM-234,-128C-241,-137,-251,-142,-263,-142L-383,-142C-397,-142,-405,-126,-397,-114L-122,264C-108,283,-79,283,-65,264L397,-372C405,-384,397,-400,383,-400L263,-400C251,-400,241,-395,234,-386L-94,66L-234,-128Z",
  "M920,-518L280,-518L280,-800C280,-844,244,-880,200,-880L-820,-880L-820,-980C-820,-991,-829,-1000,-840,-1000L-980,-1000C-991,-1000,-1000,-991,-1000,-980L-1000,980C-1000,991,-991,1000,-980,1000L-840,1000C-829,1000,-820,991,-820,980L-820,320L-200,320L-200,602C-200,647,-164,682,-120,682L920,682C964,682,1000,647,1000,602L1000,-438C1000,-482,964,-518,920,-518Z",
  "M998,470C994,460,983,455,972,458L819,514L819,-830C819,-924,743,-1000,649,-1000L-649,-1000C-743,-1000,-819,-924,-819,-830L-819,514L-972,458C-975,458,-977,457,-979,457C-990,457,-999,466,-999,477L-999,626C-999,634,-994,642,-986,645L-27,994C-10,1000,9,1000,27,994L986,645C994,642,999,635,999,626L999,477C999,475,999,473,998,470ZM389,-471L130,7L274,7C285,7,294,16,294,27L294,95C294,106,285,115,274,115L83,115L83,212L274,212C285,212,294,221,294,232L294,300C294,311,285,320,274,320L83,320L83,479C83,490,74,499,63,499L-61,499C-72,499,-81,490,-81,479L-81,320L-271,320C-282,320,-291,311,-291,300L-291,233C-291,222,-282,213,-271,213L-81,213L-81,115L-271,115C-282,115,-291,106,-291,95L-291,28C-291,17,-282,8,-271,8L-129,8L-388,-471C-394,-480,-390,-493,-380,-498C-377,-500,-374,-500,-371,-500L-232,-500C-224,-500,-218,-496,-214,-489L-2,-68L6,-68L217,-489C221,-496,228,-500,235,-500L371,-500C382,-500,391,-491,391,-481C391,-477,390,-474,389,-471Z",
  "M-719,640C-719,680,-686,712,-647,712L646,712C686,712,718,680,718,640L718,115C718,-282,397,-604,0,-604C-397,-604,-719,-282,-719,115L-719,640ZM-557,115C-557,-192,-307,-441,0,-441C307,-441,556,-192,556,115L556,550L-243,550L-243,164C-243,152,-254,142,-266,142L-365,142C-377,142,-388,152,-388,164L-388,550L-557,550L-557,115ZM-665,-454L-576,-543C-569,-550,-569,-561,-576,-568L-729,-721C-736,-728,-747,-728,-754,-721L-843,-632C-850,-625,-850,-614,-843,-607L-690,-454C-683,-447,-672,-447,-665,-454ZM843,-632L754,-721C747,-728,736,-728,729,-721L576,-568C569,-561,569,-550,576,-543L665,-454C672,-447,683,-447,690,-454L843,-607C850,-614,850,-625,843,-632ZM720,856L-721,856C-761,856,-793,888,-793,928L-793,982C-793,992,-785,1000,-775,1000L775,1000C784,1000,793,992,793,982L793,928C793,888,760,856,720,856ZM-63,-748L63,-748C73,-748,81,-756,81,-766L81,-982C81,-992,73,-1000,63,-1000L-63,-1000C-73,-1000,-81,-992,-81,-982L-81,-766C-81,-756,-73,-748,-63,-748Z",
  "M818,-585C807,-618,776,-640,742,-640L560,-640L560,-920C560,-964,524,-1000,480,-1000L-480,-1000C-524,-1000,-560,-964,-560,-920L-560,-640L-742,-640C-777,-640,-807,-618,-818,-585L-1000,-25L-1000,920C-1000,964,-964,1000,-920,1000L920,1000C964,1000,1000,964,1000,920L1000,-25L818,-585ZM370,290C370,301,361,310,350,310L80,310L80,580C80,591,71,600,60,600L-60,600C-71,600,-80,591,-80,580L-80,310L-350,310C-361,310,-370,301,-370,290L-370,170C-370,159,-361,150,-350,150L-80,150L-80,-120C-80,-131,-71,-140,-60,-140L60,-140C71,-140,80,-131,80,-120L80,150L350,150C361,150,370,159,370,170L370,290ZM380,-640L-380,-640L-380,-820L380,-820L380,-640Z",
  "M800,-640L730,-640L640,-942C630,-976,599,-1000,564,-1000L-564,-1000C-600,-1000,-631,-976,-640,-942L-730,-640L-800,-640C-844,-640,-880,-604,-880,-560L-880,-490C-880,-479,-871,-470,-860,-470L-746,-470L-626,927C-623,968,-588,1000,-546,1000L526,1000C568,1000,603,968,606,927L726,-470L860,-470C871,-470,880,-479,880,-490L880,-560C880,-604,844,-640,800,-640ZM-10,480C-209,480,-370,319,-370,120C-370,-79,-209,-240,-10,-240C189,-240,350,-79,350,120C350,319,189,480,-10,480ZM-552,-640L-496,-830L496,-830L552,-640L-552,-640ZM-10,120ZM-210,120L-207,155L-198,188L-183,220L-163,249L-139,273L-110,293L-78,308L-45,317L-10,320L25,317L58,308L90,293L119,273L143,249L163,220L178,188L187,155L190,120L187,85L178,52L163,20L143,-9L119,-33L90,-53L58,-68L25,-77L-10,-80L-45,-77L-78,-68L-110,-53L-139,-33L-163,-9L-183,20L-198,52L-207,85L-210,120Z",
  "M575,-485L575,-820L790,-820C801,-820,810,-829,810,-840L810,-980C810,-991,801,-1000,790,-1000L-790,-1000C-801,-1000,-810,-991,-810,-980L-810,-840C-810,-829,-801,-820,-790,-820L-575,-820L-575,-485C-575,-281,-469,-102,-309,0C-469,102,-575,281,-575,485L-575,820L-790,820C-801,820,-810,829,-810,840L-810,980C-810,991,-801,1000,-790,1000L790,1000C801,1000,810,991,810,980L810,840C810,829,801,820,790,820L575,820L575,485C575,281,469,102,309,0C469,-102,575,-281,575,-485ZM395,485L395,820L-395,820L-395,485C-395,380,-354,280,-279,206C-205,131,-106,90,0,90C106,90,205,131,279,206C354,280,395,380,395,485ZM395,-485C395,-380,354,-280,279,-206C205,-131,106,-90,0,-90C-106,-90,-205,-131,-279,-206C-354,-280,-395,-380,-395,-485L-395,-820L395,-820L395,-485Z",
  "M800,-500L460,-500L460,-540C460,-794,254,-1000,0,-1000C-254,-1000,-460,-794,-460,-540L-460,-500L-800,-500C-844,-500,-880,-464,-880,-420L-880,920C-880,964,-844,1000,-800,1000L800,1000C844,1000,880,964,880,920L880,-420C880,-464,844,-500,800,-500ZM280,-500L-280,-500L-280,-540C-280,-695,-155,-820,0,-820C155,-820,280,-695,280,-540L280,-500Z",
  "M268,839L-268,839C-278,839,-286,847,-286,857L-286,929C-286,968,-254,1000,-214,1000L214,1000C254,1000,286,968,286,929L286,857C286,847,278,839,268,839ZM0,-1000C-404,-1000,-732,-672,-732,-268C-732,3,-585,240,-366,366L-366,625C-366,665,-334,696,-295,696L295,696C334,696,366,665,366,625L366,366C585,240,732,3,732,-268C732,-672,404,-1000,0,-1000ZM285,227L205,274L205,536L-205,536L-205,274L-285,227C-461,126,-571,-61,-571,-268C-571,-583,-316,-839,0,-839C316,-839,571,-583,571,-268C571,-61,461,126,285,227Z",
  "M891,-960L378,-960C334,-960,296,-931,286,-887C254,-756,137,-662,0,-662C-137,-662,-254,-756,-286,-887C-296,-931,-334,-960,-378,-960L-891,-960C-951,-960,-1000,-911,-1000,-851L-1000,-224C-1000,-163,-951,-114,-891,-114L-704,-114L-704,851C-704,911,-655,960,-595,960L595,960C655,960,704,911,704,851L704,-114L891,-114C951,-114,1000,-163,1000,-224L1000,-851C1000,-911,951,-960,891,-960Z",
  "M89,-97ZM-11,-97L-9,-80L-5,-63L3,-47L13,-33L25,-21L39,-11L55,-4L72,1L89,2L106,1L123,-4L139,-11L153,-21L166,-33L176,-47L183,-63L187,-80L189,-97L187,-115L183,-131L176,-147L166,-161L153,-174L139,-184L123,-191L106,-195L89,-197L72,-195L55,-191L39,-184L25,-174L13,-161L3,-147L-5,-131L-9,-115L-11,-97ZM905,783L449,-397L449,-830L628,-830L628,-1000L-649,-1000L-649,-830L-470,-830L-470,-397L-926,783C-933,801,-937,821,-937,840C-937,928,-865,1000,-777,1000L756,1000C775,1000,795,996,813,989C896,958,937,865,905,783ZM-301,-365L-301,-825L279,-825L279,-365L506,222C454,209,401,202,347,202C194,202,50,256,-65,352C-150,422,-256,461,-368,461C-450,461,-528,440,-597,402L-301,-365ZM-762,830L-658,562C-569,607,-470,631,-368,631C-215,631,-70,577,45,481C129,411,235,372,347,372C434,372,518,396,590,439L741,830L-762,830Z",
  "M893,-468L607,-304L607,-643C607,-722,543,-786,464,-786L-857,-786C-936,-786,-1000,-722,-1000,-643L-1000,643C-1000,722,-936,786,-857,786L464,786C543,786,607,722,607,643L607,304L893,468C940,496,1000,461,1000,406L1000,-406C1000,-461,940,-496,893,-468ZM-411,-357C-411,-347,-419,-339,-429,-339L-679,-339C-688,-339,-696,-347,-696,-357L-696,-464C-696,-474,-688,-482,-679,-482L-429,-482C-419,-482,-411,-474,-411,-464L-411,-357ZM839,252L607,119L607,-119L839,-252L839,252Z",
  "M691,582L636,582L636,-191C636,-512,399,-777,91,-821L91,-909C91,-959,50,-1000,0,-1000C-50,-1000,-91,-959,-91,-909L-91,-821C-399,-777,-636,-512,-636,-191L-636,582L-691,582C-731,582,-764,614,-764,655L-764,727C-764,737,-755,745,-745,745L-255,745C-255,886,-140,1000,0,1000C140,1000,255,886,255,745L745,745C755,745,764,737,764,727L764,655C764,614,731,582,691,582ZM0,855C-60,855,-109,806,-109,745L109,745C109,806,60,855,0,855ZM-473,582L-473,-191C-473,-317,-424,-436,-334,-525C-245,-615,-126,-664,0,-664C126,-664,245,-615,334,-525C424,-436,473,-317,473,-191L473,582L-473,582Z",
  "M868,516L616,370C610,367,604,365,598,365C585,365,573,372,566,384L521,462C511,480,517,502,534,512L786,658C792,661,798,662,804,662C817,662,829,656,836,644L881,565C891,548,885,526,868,516ZM566,-384C573,-372,585,-365,598,-365C604,-365,610,-367,616,-370L868,-516C885,-526,891,-548,881,-565L836,-644C829,-655,817,-662,804,-662C798,-662,792,-661,786,-657L534,-512C517,-502,511,-479,521,-462L566,-384ZM963,-82L671,-82C651,-82,635,-66,635,-46L635,46C635,66,651,82,671,82L963,82C984,82,1000,66,1000,46L1000,-46C1000,-66,984,-82,963,-82ZM260,-906C247,-906,233,-903,220,-894L-589,-365L-963,-365C-984,-365,-1000,-349,-1000,-329L-1000,329C-1000,349,-984,365,-963,365L-589,365L220,894C233,903,247,906,260,906C298,906,333,876,333,833L333,-833C333,-876,298,-906,260,-906Z",
  "M890,-880L660,-880L660,-980C660,-991,651,-1000,640,-1000L-640,-1000C-651,-1000,-660,-991,-660,-980L-660,-880L-890,-880C-951,-880,-1000,-831,-1000,-770L-1000,-400C-1000,-196,-850,-26,-654,5C-616,296,-382,524,-90,556L-90,819L-580,819C-624,819,-660,855,-660,899L-660,980C-660,991,-651,1000,-640,1000L640,1000C651,1000,660,991,660,980L660,899C660,855,624,819,580,819L90,819L90,556C382,524,616,296,654,5C850,-26,1000,-196,1000,-400L1000,-770C1000,-831,951,-880,890,-880ZM-820,-400L-820,-700L-660,-700L-660,-181C-753,-210,-820,-298,-820,-400ZM480,-80C480,43,432,158,345,245C258,332,143,380,20,380L-20,380C-143,380,-258,332,-345,245C-432,158,-480,43,-480,-80L-480,-820L480,-820L480,-80ZM820,-400C820,-298,753,-210,660,-181L660,-700L820,-700L820,-400Z",
  "M-366,366C-585,240,-732,3,-732,-268C-732,-672,-404,-1000,0,-1000C404,-1000,732,-672,732,-268C732,3,585,240,366,366L366,625C366,665,334,696,295,696L-295,696C-334,696,-366,665,-366,625L-366,366ZM-268,839L268,839C278,839,286,847,286,857L286,929C286,968,254,1000,214,1000L-214,1000C-254,1000,-286,968,-286,929L-286,857C-286,847,-278,839,-268,839Z",
  "M-905,-127C-955,-127,-1000,-168,-1000,-223L-1000,-905C-1000,-959,-959,-1000,-905,-1000L-218,-1000C-168,-1000,-123,-959,-123,-905L-123,-218C-123,-168,-164,-123,-218,-123L-905,-123ZM218,-127C168,-127,123,-168,123,-223L123,-905C123,-955,164,-1000,218,-1000L905,-1000C959,-1000,1000,-959,1000,-905L1000,-218C1000,-168,959,-123,905,-123L218,-123ZM-905,1000C-959,1000,-1000,959,-1000,905L-1000,218C-1000,168,-959,123,-905,123L-218,123C-168,123,-123,164,-123,218L-123,905C-123,955,-164,1000,-218,1000L-905,1000ZM218,1000C168,1000,123,959,123,905L123,218C123,168,164,123,218,123L905,123C955,123,1000,164,1000,218L1000,905C1000,955,959,1000,905,1000L218,1000Z",
  "M516,1000L157,1000L157,616C157,588,134,565,106,565L-76,565C-104,565,-127,589,-127,616L-127,1000L-515,1000C-622,1000,-709,913,-709,806L-709,172L-929,104L-946,86C-998,34,-998,-50,-946,-102L-87,-961C-62,-986,-29,-1000,6,-1000C42,-1000,75,-986,100,-961L959,-102C984,-77,998,-43,998,-8C998,28,984,61,959,86L941,104L710,172L710,806C710,913,623,1000,516,1000Z",
  "M985,13L17,-988L14,-990L11,-992L7,-994L4,-995L0,-995L-4,-995L-8,-994L-11,-992L-14,-990L-17,-988L-985,13C-1000,28,-989,54,-968,54L-816,54L-816,967L-815,972L-814,977L-812,981L-809,985L-806,988L-802,991L-798,993L-793,994L-789,995L783,995L788,994L793,993L797,991L801,988L804,985L807,981L809,977L810,972L810,967L810,54L968,54C989,54,1000,28,985,13ZM-428,874L-428,878L-429,882L-431,885L-433,889L-435,891L-439,894L-442,895L-446,896L-449,897L-612,897L-616,896L-619,895L-623,894L-626,891L-629,889L-631,885L-632,882L-633,878L-634,874L-634,709L-633,705L-632,701L-631,698L-629,694L-626,692L-623,689L-619,688L-616,687L-612,686L-449,686L-446,687L-442,688L-439,689L-435,692L-433,694L-431,698L-429,701L-428,705L-428,709ZM-428,587L-428,591L-429,594L-431,598L-433,601L-435,604L-439,606L-442,608L-446,609L-449,609L-612,609L-616,609L-619,608L-623,606L-626,604L-629,601L-631,598L-632,594L-633,591L-634,587L-634,421L-633,417L-632,413L-631,410L-629,407L-626,404L-623,402L-619,400L-616,399L-612,399L-449,399L-446,399L-442,400L-439,402L-435,404L-433,407L-431,410L-429,413L-428,417L-428,421ZM-428,298L-428,302L-429,306L-431,310L-433,313L-435,315L-439,318L-442,319L-446,320L-449,321L-612,321L-616,320L-619,319L-623,318L-626,315L-629,313L-631,310L-632,306L-633,302L-634,298L-634,132L-633,129L-632,125L-631,121L-629,118L-626,115L-623,113L-619,112L-616,111L-612,110L-449,110L-446,111L-442,112L-439,113L-435,115L-433,118L-431,121L-429,125L-428,129L-428,132ZM-151,874L-151,878L-152,882L-153,885L-156,889L-158,891L-161,894L-165,895L-168,896L-172,897L-335,897L-338,896L-342,895L-346,894L-349,891L-351,889L-353,885L-355,882L-356,878L-356,874L-356,709L-356,705L-355,701L-353,698L-351,694L-349,692L-346,689L-342,688L-338,687L-335,686L-172,686L-169,687L-165,688L-161,689L-158,692L-156,694L-153,698L-152,701L-151,705L-151,709ZM-151,587L-151,591L-152,594L-153,598L-156,601L-158,604L-161,606L-165,608L-168,609L-172,609L-335,609L-338,609L-342,608L-346,606L-349,604L-351,601L-353,598L-355,594L-356,591L-356,587L-356,421L-356,417L-355,413L-353,410L-351,407L-349,404L-346,402L-342,400L-338,399L-335,399L-172,399L-169,399L-165,400L-161,402L-158,404L-156,407L-153,410L-152,413L-151,417L-151,421ZM131,874L131,878L130,882L129,885L126,889L124,891L121,894L117,895L114,896L110,897L-52,897L-56,896L-60,895L-63,894L-67,891L-69,889L-71,885L-73,882L-74,878L-74,874L-74,709L-74,705L-73,701L-71,697L-69,694L-67,692L-63,689L-60,688L-56,687L-52,686L110,686L114,687L117,688L121,689L124,692L127,694L129,697L130,701L131,705L132,708Z",
  "M-1000,-333L-1000,-917C-1000,-962,-962,-1000,-917,-1000L-333,-1000L-333,-833L-833,-833L-833,-333L-1000,-333ZM333,-833L833,-833L833,-333L1000,-333L1000,-917C1000,-962,962,-1000,917,-1000L333,-1000L333,-833ZM833,333L833,833L333,833L333,1000L917,1000C962,1000,1000,962,1000,917L1000,333L833,333ZM-333,833L-833,833L-833,333L-1000,333L-1000,917C-1000,962,-962,1000,-917,1000L-333,1000L-333,833ZM1000,-83L-1000,-83L-1000,83L1000,83L1000,-83Z",
  "M-364,727L-136,727L-136,-727L-364,-727L-364,727ZM-545,727L-455,727L-455,-727L-545,-727L-545,727ZM-45,727L45,727L45,-727L-45,-727L-45,727ZM-818,727L-636,727L-636,-727L-818,-727L-818,727ZM-1000,-636L-1000,636C-1000,686,-959,727,-909,727L-909,-727C-959,-727,-1000,-686,-1000,-636ZM909,-727L818,-727L818,727L909,727C959,727,1000,686,1000,636L1000,-636C1000,-686,959,-727,909,-727ZM136,727L227,727L227,-727L136,-727L136,727ZM636,727L727,727L727,-727L636,-727L636,727ZM318,727L545,727L545,-727L318,-727L318,727Z",
  "M751,-999L-751,-999C-889,-999,-1000,-887,-1000,-750L-1000,750C-1000,887,-889,999,-751,999L749,999C886,999,997,887,997,750L997,-750C1000,-887,889,-999,751,-999ZM-457,544L-706,544L-706,296L-457,296L-457,544ZM-457,127L-706,127L-706,-124L-457,-124L-457,127ZM-457,-293L-706,-293L-706,-541L-457,-541L-457,-293ZM709,544L-263,544L-263,296L706,296L706,544L709,544ZM709,127L-263,127L-263,-124L706,-124L706,127L709,127ZM709,-293L-263,-293L-263,-541L706,-541L706,-293L709,-293Z",
  "M-54,154L-43,163L-30,171L-17,176L-3,180L12,181L27,180L41,176L54,171L67,163L78,154L973,-741L983,-754L991,-768L997,-783L1000,-799L1000,-815L997,-831L991,-846L983,-860L973,-873L960,-883L946,-891L931,-897L915,-900L899,-900L883,-897L868,-891L854,-883L841,-873L12,-43L-842,-897L-854,-908L-868,-916L-883,-921L-899,-924L-916,-924L-932,-921L-947,-916L-961,-908L-973,-897L-984,-885L-992,-871L-997,-856L-1000,-840L-1000,-823L-997,-808L-992,-792L-984,-778L-973,-766L-54,154ZM841,-130L12,700L-842,-154L-854,-164L-868,-173L-883,-178L-899,-181L-915,-181L-931,-178L-947,-173L-961,-164L-973,-154L-983,-142L-992,-128L-997,-112L-1000,-96L-1000,-80L-997,-64L-992,-49L-983,-35L-973,-23L-54,897L-43,906L-30,914L-17,920L-2,923L12,924L27,923L41,920L54,914L67,906L78,897L973,2L983,-10L991,-23L996,-37L999,-53L1000,-68L998,-83L994,-98L987,-112L978,-124L967,-135L955,-144L941,-151L926,-155L911,-157L896,-156L881,-153L866,-147L853,-140L841,-130Z",
  "M405,-143C369,-164,324,-164,288,-143C252,-122,230,-83,230,-41C230,1,252,39,288,60C324,81,369,81,405,60C441,39,463,1,463,-41C463,-83,441,-122,405,-143ZM880,-322C860,-385,834,-445,801,-501C779,-540,728,-543,703,-508C688,-486,690,-463,703,-440C811,-243,837,-35,776,181C651,619,197,866,-238,736C-557,641,-789,353,-813,20C-823,-116,-801,-246,-746,-372C-596,-716,-214,-915,154,-840C238,-822,318,-793,393,-750C406,-743,419,-738,434,-740C460,-744,479,-763,484,-787C489,-813,477,-836,452,-851C243,-966,22,-1000,-210,-948C-631,-854,-931,-476,-932,-43C-932,26,-924,95,-909,162C-791,685,-256,1000,257,850C619,743,881,427,919,49C932,-77,918,-201,880,-322ZM-63,-143C-99,-122,-121,-83,-121,-41C-121,23,-69,76,-4,76C60,76,113,23,113,-41C113,-83,90,-122,54,-143C18,-164,-26,-164,-63,-143ZM-413,-143C-449,-122,-472,-83,-472,-41C-472,1,-449,39,-413,60C-377,81,-332,81,-296,60C-260,39,-238,1,-238,-41C-238,-83,-260,-122,-296,-143C-332,-164,-377,-164,-413,-143Z",
  "M922,-913L-922,-913C-965,-913,-1000,-879,-1000,-837L-1000,-390C-1000,-348,-965,-313,-922,-313C-879,-313,-844,-348,-844,-390L-844,-760L844,-760L844,-390C844,-348,879,-313,922,-313C965,-313,1000,-348,1000,-390L1000,-837C1000,-879,965,-913,922,-913ZM335,322L81,625L81,-466C81,-509,47,-543,4,-543C-39,-543,-74,-509,-74,-466L-74,628L-331,322C-361,292,-411,292,-441,322C-472,352,-472,401,-441,431L-57,890C-40,906,-19,913,2,912C24,913,45,906,62,890L446,431C476,401,476,352,446,322C415,292,366,292,335,322Z",
  "M121,587L686,831L961,-1000L-961,130L-457,368L762,-740L-216,481L-229,1000L121,587Z",
  "M796,548L667,256L667,-161C667,-437,490,-686,237,-785C228,-905,125,-1000,0,-1000C-125,-1000,-224,-905,-237,-785C-495,-686,-667,-437,-667,-161L-667,256L-796,548C-813,587,-809,630,-787,665C-766,699,-727,720,-684,720L684,720C727,720,766,699,787,665C809,630,813,583,796,548ZM-675,591L-538,282L-538,-161C-538,-398,-378,-609,-151,-677L-99,-695L-108,-751L-108,-763C-108,-824,-60,-871,0,-871C60,-871,108,-824,108,-763L108,-746L99,-690L151,-673C378,-604,538,-394,538,-157L538,286L675,596L-675,596ZM0,1000C120,1000,215,905,215,785L-215,785C-215,905,-120,1000,0,1000Z",
  "M158,95L1000,-789L-1000,-789L-158,95L-158,579L158,789L158,95ZM158,-63L53,42L53,579L-53,505L-53,32L-158,-74L-747,-684L747,-684L158,-63Z",
  "M0,28C-283,28,-514,-203,-514,-486C-514,-769,-283,-1000,0,-1000C283,-1000,514,-769,514,-486C514,-203,283,28,0,28ZM0,-853C-202,-853,-367,-688,-367,-486C-367,-284,-202,-119,0,-119C202,-119,367,-284,367,-486C367,-688,202,-853,0,-853ZM859,1000L713,1000L713,888C713,495,393,175,0,175C-393,175,-713,494,-713,887L-713,1000L-859,1000L-859,888C-859,414,-474,28,0,28C474,28,859,414,859,887L859,1000ZM-65,624L397,162L501,266L39,728ZM367,983L220,983C220,861,121,762,0,762C-121,762,-220,861,-220,983L-367,983C-367,780,-202,615,0,615C202,615,367,780,367,983Z",
  "M619,1000L-45,1000C-249,1000,-411,834,-411,634L-411,525C-411,321,-245,158,-45,158L619,158C823,158,985,325,985,525L985,634C985,834,819,1000,619,1000ZM-385,340C-396,340,-411,336,-419,325L-966,-170C-981,-181,-985,-200,-981,-219C-977,-238,-966,-253,-951,-260L823,-989C845,-1000,872,-989,887,-970C902,-947,898,-921,879,-902L-347,325C-358,336,-374,340,-385,340ZM-834,-192L-389,215L615,-789L-834,-192ZM226,955C215,955,200,951,192,940L-268,525L-298,494C-317,475,-317,442,-298,419C-279,400,-245,400,-223,419L-192,449L208,811L808,-675C819,-702,849,-717,875,-706C902,-694,917,-664,906,-638L275,921C268,936,257,947,238,951C234,955,230,955,226,955Z",
  "M2,995L-8,995C-130,994,-248,972,-360,927L-336,869C-232,910,-120,932,-6,932L3,932C499,932,915,531,930,35C938,-224,842,-468,659,-651C474,-834,231,-930,-28,-923C-534,-907,-935,-482,-926,24C-923,179,-880,330,-804,464L-859,496C-942,354,-986,191,-989,25C-1000,-515,-570,-968,-32,-986C245,-995,506,-891,701,-697C897,-501,1000,-240,992,36C975,567,531,995,2,995ZM46,-265C-8,-265,-52,-310,-52,-363C-52,-417,-8,-461,46,-461C100,-461,144,-417,144,-363C144,-310,100,-265,46,-265ZM-16,469C-55,476,-88,457,-111,430C-139,395,-147,346,-136,303L-52,-11C-52,-35,-60,-32,-117,-43C-125,-44,-130,-55,-123,-62C-84,-107,-21,-141,46,-141C90,-141,117,-111,131,-76C144,-46,144,-11,136,19L60,303C51,336,73,370,106,376C123,379,136,378,134,389C123,428,62,469,-16,469ZM-831,480ZM-863,480L-862,486L-861,491L-858,496L-855,501L-851,504L-847,508L-842,510L-836,511L-831,512L-825,511L-820,510L-815,508L-811,504L-807,501L-804,496L-801,491L-800,486L-799,480L-800,475L-801,469L-804,464L-807,460L-811,456L-815,453L-820,451L-825,449L-831,449L-836,449L-842,451L-847,453L-851,456L-855,460L-858,464L-861,469L-862,475L-863,480ZM-349,899ZM-381,899L-380,904L-379,910L-376,915L-373,919L-369,923L-365,926L-360,929L-355,930L-349,930L-344,930L-338,929L-333,926L-329,923L-325,919L-322,915L-319,910L-318,904L-318,899L-318,893L-319,888L-322,883L-325,879L-329,875L-333,872L-338,869L-344,868L-349,867L-355,868L-360,869L-365,872L-369,875L-373,879L-376,883L-379,888L-380,893L-381,899ZM-474,810ZM-506,810L-505,816L-504,821L-501,826L-498,831L-494,835L-490,838L-485,840L-479,842L-474,842L-468,842L-463,840L-458,838L-454,835L-450,831L-447,826L-444,821L-443,816L-442,810L-443,805L-444,800L-447,795L-450,790L-454,786L-458,783L-463,781L-468,779L-474,779L-479,779L-485,781L-490,783L-494,786L-498,790L-501,795L-504,800L-505,805L-506,810Z",
  "M0,-250ZM-333,-250L-328,-192L-313,-136L-289,-83L-255,-36L-214,5L-167,39L-114,63L-58,78L0,83L58,78L114,63L167,39L214,5L255,-36L289,-83L313,-136L328,-192L333,-250L328,-308L313,-364L289,-417L255,-464L214,-505L167,-539L114,-563L58,-578L0,-583L-58,-578L-114,-563L-167,-539L-214,-505L-255,-464L-289,-417L-313,-364L-328,-308L-333,-250ZM0,-1000C-552,-1000,-1000,-552,-1000,0C-1000,552,-552,1000,0,1000C552,1000,1000,552,1000,0C1000,-552,552,-1000,0,-1000ZM608,686C619,639,625,591,625,542C625,316,506,119,327,9C250,105,132,167,0,167C-132,167,-250,105,-327,9C-506,119,-625,316,-625,542C-625,591,-619,639,-608,686C-797,518,-917,273,-917,0C-917,-506,-506,-917,0,-917C506,-917,917,-506,917,0C917,273,797,518,608,686Z",
  "M972,55L-152,55C-222,55,-247,29,-246,-38L-246,-456C-246,-518,-270,-562,-336,-562L-444,-562C-558,-562,-665,-509,-734,-418C-810,-318,-905,-192,-947,-130C-973,-93,-989,-50,-993,-5C-1000,89,-999,273,-999,273L-999,375C-999,409,-971,437,-936,437L-842,437C-842,393,-832,351,-813,312C-800,285,-782,260,-760,239C-707,185,-637,156,-561,156C-486,156,-416,185,-363,239C-341,260,-323,285,-310,312L311,312C324,285,342,260,364,239C389,214,418,194,449,180C484,165,523,156,563,156C602,156,641,164,676,180C708,194,736,214,761,239C783,260,801,285,814,312C834,351,843,393,843,437L875,437C944,437,1000,381,1000,312L1000,81C996,69,986,59,972,55ZM-312,-158C-312,-141,-326,-127,-343,-127L-859,-126C-865,-126,-869,-133,-865,-138C-817,-206,-743,-303,-684,-380C-656,-417,-620,-448,-578,-468C-536,-489,-490,-499,-444,-499L-374,-499C-340,-499,-311,-471,-312,-437L-312,-158ZM-561,437ZM-780,437L-777,475L-767,512L-751,547L-729,578L-702,605L-671,627L-636,643L-599,652L-561,656L-523,652L-487,643L-452,627L-421,605L-394,578L-372,547L-356,512L-346,475L-343,437L-346,399L-356,362L-372,328L-394,297L-421,270L-452,248L-487,232L-523,222L-561,219L-599,222L-636,232L-671,248L-702,270L-729,297L-751,328L-767,362L-777,399L-780,437ZM563,437ZM344,437L347,473L356,508L371,541L390,571L415,598L443,620L475,637L509,649L545,655L581,655L616,649L651,637L682,620L711,598L735,571L755,541L770,508L778,473L781,437L778,401L770,366L755,333L735,303L711,276L682,254L651,237L616,225L581,219L545,219L509,225L475,237L443,254L415,276L390,303L371,333L356,366L347,401L344,437ZM984,-4L-124,-4C-159,-4,-187,-32,-187,-66L-187,-640C-187,-649,-180,-656,-171,-656L984,-656C993,-656,1000,-649,1000,-640L1000,-20C1000,-11,993,-4,984,-4Z",
  "M-450,1000C-477,1000,-503,990,-523,969C-563,929,-562,863,-522,824L313,5L-522,-813C-562,-853,-563,-918,-523,-959C-484,-999,-418,-1000,-378,-960L532,-68C552,-49,563,-22,563,5C563,33,552,59,532,79L-378,971C-398,990,-424,1000,-450,1000Z",
  "M-1000,-750L-1000,750L1000,750L1000,-750L-1000,-750ZM-625,625L-875,625L-875,375L-625,375L-625,625ZM-625,125L-875,125L-875,-125L-625,-125L-625,125ZM-625,-375L-875,-375L-875,-625L-625,-625L-625,-375ZM500,625L-500,625L-500,-625L500,-625L500,625ZM875,625L625,625L625,375L875,375L875,625ZM875,125L625,125L625,-125L875,-125L875,125ZM875,-375L625,-375L625,-625L875,-625L875,-375ZM-250,-375L-250,375L250,0Z",
  "M898,-515L531,-533L509,-772C505,-822,460,-857,407,-853L-910,-745C-962,-741,-1000,-699,-996,-649L-902,400C-897,451,-852,486,-800,482L-733,477L-744,680C-746,736,-703,782,-644,785L825,855C884,857,932,816,935,760L997,-411C1000,-467,956,-512,898,-515ZM-682,-491L-713,109L-791,218L-862,-574C-862,-574,-862,-575,-862,-576C-862,-577,-862,-577,-862,-578C-860,-600,-843,-618,-820,-620L341,-715C365,-717,385,-702,388,-680C388,-679,390,-679,390,-678C390,-678,391,-677,391,-676L403,-539L-572,-586C-630,-588,-679,-547,-682,-491ZM805,563L597,317L475,171C464,158,446,148,427,147C408,146,394,154,378,165L305,218C289,227,277,234,261,233C245,232,231,226,220,216C217,212,210,206,205,201L14,-17C1,-34,-22,-45,-47,-47C-72,-48,-97,-37,-113,-22L-563,462L-593,495L-592,465L-561,-109L-547,-388C-547,-389,-547,-390,-547,-391C-547,-392,-547,-392,-547,-393C-540,-417,-519,-434,-494,-433L415,-389L543,-383L802,-371C828,-369,848,-350,848,-325C848,-324,850,-324,850,-323C850,-322,851,-322,851,-321L805,563ZM522,28C608,28,679,-42,679,-128C679,-214,609,-285,522,-285C436,-285,366,-215,366,-128C366,-41,435,28,522,28Z",
  "M765,-498C778,-485,786,-467,786,-448L786,929C786,968,754,1000,714,1000L-714,1000C-754,1000,-786,968,-786,929L-786,-929C-786,-968,-754,-1000,-714,-1000L234,-1000C253,-1000,271,-992,284,-979L765,-498ZM621,-415L201,-835L201,-415L621,-415Z",
  "M-664,327C-617,327,-573,335,-532,353C-491,371,-456,395,-426,426C-396,457,-372,493,-354,533C-337,574,-328,617,-328,663C-328,710,-337,754,-354,794C-372,835,-396,870,-426,900C-456,930,-491,954,-532,972C-573,990,-617,999,-664,999C-709,999,-753,990,-793,972C-834,954,-870,930,-900,900C-931,870,-955,835,-973,794C-991,754,-1000,710,-1000,663C-1000,617,-991,574,-973,533C-955,493,-931,457,-900,426C-870,395,-834,371,-793,353C-753,335,-709,327,-664,327ZM-861,-352C-694,-352,-536,-320,-389,-257C-241,-193,-112,-107,-3,3C106,113,192,242,256,390C319,537,351,695,351,862L165,862C103,862,45,861,-11,860C-11,743,-33,632,-77,529C-121,425,-182,335,-259,258C-336,181,-426,120,-530,76C-633,32,-744,10,-861,10L-861,-352ZM-859,-999C-687,-999,-522,-977,-364,-933C-206,-888,-57,-826,80,-745C218,-665,343,-567,456,-454C569,-340,666,-215,746,-77C827,61,889,208,934,366C978,524,1000,688,1000,860L876,860L799,860C776,860,755,859,736,859C716,858,694,858,668,858C668,718,650,582,613,452C577,321,526,200,459,87C393,-26,313,-129,221,-222C128,-314,25,-394,-88,-459C-201,-525,-322,-576,-452,-612C-582,-649,-717,-667,-857,-667L-857,-736C-857,-770,-857,-805,-858,-842C-858,-878,-859,-911,-859,-941L-859,-999Z",
  "M-727,0ZM-1000,0L-996,45L-985,89L-967,130L-942,168L-912,201L-876,229L-837,250L-794,265L-749,272L-704,272L-660,265L-617,250L-578,229L-542,201L-511,168L-487,130L-469,89L-457,45L-454,0L-457,-45L-469,-89L-487,-130L-511,-168L-542,-201L-578,-229L-617,-250L-660,-265L-704,-272L-749,-272L-794,-265L-837,-250L-876,-229L-912,-201L-942,-168L-967,-130L-985,-89L-996,-45L-1000,0ZM0,0ZM-273,0L-269,45L-258,89L-240,130L-216,168L-185,201L-149,229L-110,250L-67,265L-23,272L23,272L67,265L110,250L149,229L185,201L216,168L240,130L258,89L269,45L273,0L269,-45L258,-89L240,-130L216,-168L185,-201L149,-229L110,-250L67,-265L23,-272L-23,-272L-67,-265L-110,-250L-149,-229L-185,-201L-216,-168L-240,-130L-258,-89L-269,-45L-273,0ZM727,0ZM454,0L457,45L469,89L487,130L511,168L542,201L578,229L617,250L660,265L704,272L749,272L794,265L837,250L876,229L912,201L942,168L967,130L985,89L996,45L1000,0L996,-45L985,-89L967,-130L942,-168L912,-201L876,-229L837,-250L794,-265L749,-272L704,-272L660,-265L617,-250L578,-229L542,-201L511,-168L487,-130L469,-89L457,-45L454,0Z",
  "M833,-833L833,457L455,833L-833,833L-833,-833L833,-833ZM1000,-1000L-1000,-1000L-1000,1000L523,1000L1000,527L1000,-1000ZM161,-508L33,-508C12,-508,-7,-495,-15,-476C-51,-390,-132,-320,-256,-267C-275,-258,-288,-239,-288,-218L-288,-60C-288,-43,-280,-28,-267,-18C-258,-11,-247,-8,-235,-7C-230,-7,-225,-8,-221,-10C-158,-28,-100,-53,-46,-86L-46,455C-46,484,-23,507,6,507L160,507C190,507,213,484,213,455L213,-457C213,-485,190,-508,161,-508Z",
  "M1000,-360L1000,40L-1000,40L-1000,-360C-1000,-400,-987,-440,-947,-467C-920,-493,-867,-507,-813,-507L-413,-507L-413,-680C-413,-707,-400,-733,-387,-747C-373,-760,-347,-773,-320,-773L333,-773C360,-773,387,-760,400,-747C413,-733,427,-707,427,-680L427,-507L813,-507C853,-507,893,-493,947,-467C987,-440,1000,-400,1000,-360ZM1000,133L1000,613C1000,653,987,693,947,733C920,760,867,773,813,773L-813,773C-853,773,-893,760,-947,733C-973,707,-1000,653,-1000,613L-1000,133L-253,133L-253,293C-253,307,-240,320,-240,333C-227,347,-213,347,-187,347L173,347C187,347,213,347,227,333C240,320,253,307,240,293L240,133L1000,133ZM-280,-533L293,-533L293,-667L-280,-667L-280,-533ZM147,133L147,267L-147,267L-147,133L147,133Z",
  "M-1,-695L21,-694L44,-689L65,-680L84,-669L102,-655L118,-638L130,-619L772,457L782,478L790,501L794,525L794,549L790,572L783,595L773,617L760,636L745,653L727,668L707,680L685,688L663,693L640,695L-640,695L-663,693L-686,688L-707,680L-727,668L-745,653L-761,636L-773,617L-784,595L-791,573L-794,549L-794,525L-790,501L-783,479L-772,457L-133,-619L-120,-638L-105,-655L-87,-669L-67,-680L-46,-689L-24,-694L-1,-695ZM-1,-827L-50,-823L-98,-811L-143,-790L-183,-762L-219,-727L-247,-687L-886,390C-1000,582,-863,827,-640,827L640,827C863,827,1000,582,885,389L244,-687L216,-727L181,-762L140,-790L95,-811L48,-823L-1,-827ZM0,-336L-12,-335L-23,-332L-33,-328L-43,-321L-51,-313L-57,-303L-62,-293L-65,-282L-66,-270L-66,193L-65,205L-62,216L-57,226L-51,236L-43,244L-33,251L-23,255L-12,258L0,259L11,258L23,255L33,251L42,244L51,236L57,226L62,216L65,205L66,193L66,-270L65,-282L62,-293L57,-303L51,-313L42,-321L33,-328L23,-332L11,-335L0,-336ZM0,346L-12,347L-23,350L-33,355L-43,361L-51,369L-57,379L-62,389L-65,400L-66,412L-65,423L-62,435L-57,445L-51,455L-43,463L-33,469L-23,474L-12,477L0,478L11,477L23,474L33,469L42,463L51,455L57,445L62,435L65,423L66,412L65,400L62,389L57,379L51,369L42,361L33,355L23,350L11,347L0,346Z",
  "M0,-862C475,-862,862,-475,862,0C862,475,475,862,0,862C-475,862,-862,475,-862,0C-862,-475,-475,-862,0,-862ZM0,-1000C-550,-1000,-1000,-550,-1000,0C-1000,550,-550,1000,0,1000C550,1000,1000,550,1000,0C1000,-550,550,-1000,0,-1000ZM-362,-413C-425,-413,-475,-362,-475,-300C-475,-238,-425,-188,-362,-187C-300,-187,-250,-238,-250,-300C-250,-363,-300,-413,-362,-413ZM362,-413C300,-413,250,-362,250,-300C250,-238,300,-188,362,-187C425,-187,475,-238,475,-300C488,-363,425,-413,362,-413ZM500,387C362,237,187,150,0,150C-200,150,-375,237,-500,387L-400,475C-300,363,-150,288,0,287C150,287,287,350,400,475L500,387ZM500,387Z",
  "M1,-952L290,-299L1000,-223L469,253L616,952L-2,594L-620,949L-471,251L-1000,-227L-290,-300L1,-952Z",
  "M1000,-235L311,-340L0,-1000L-311,-340L-1000,-235L-501,275L-620,1000L0,658L620,1000L501,275L1000,-235ZM0,512L-465,774L-376,248L-776,-159L-235,-231L0,-732L233,-231L772,-154L376,250L459,776L0,512Z",
  "M411,-43L-57,468L-67,478L-79,486L-92,491L-106,495L-120,496L-120,496L-134,495L-148,491L-161,485L-173,477L-183,467L-412,212L-421,201L-428,188L-434,174L-436,160L-437,145L-434,131L-430,117L-423,104L-414,93L-403,83L-390,75L-377,70L-362,67L-348,66L-333,68L-319,72L-306,79L-294,88L-284,98L-119,284L285,-158L296,-168L309,-175L322,-180L336,-183L351,-183L365,-181L379,-177L392,-170L403,-161L413,-151L421,-138L427,-125L430,-111L431,-97L430,-82L426,-68L419,-55L411,-43ZM767,-875L597,-875C596,-875,597,-820,597,-789L597,-620L594,-590L587,-562L574,-535L557,-510L536,-489L512,-472L485,-459L456,-451L427,-449L-426,-449L-456,-451L-485,-459L-512,-472L-536,-489L-557,-510L-574,-535L-586,-562L-594,-590L-597,-620L-597,-789C-597,-820,-597,-846,-597,-875L-768,-875C-862,-875,-938,-799,-938,-705L-938,830C-938,924,-862,1000,-768,1000L768,1000L797,997L826,990L853,977L877,960L898,939L915,915L927,888L935,860L938,830L938,-705L935,-735L927,-763L914,-790L897,-814L876,-835L852,-852L825,-865L796,-872L767,-875ZM421,-938L412,-953L400,-966L387,-978L372,-987L356,-994L339,-998L321,-1000L-321,-1000C-364,-1000,-401,-975,-421,-938L-430,-918L-436,-896L-438,-874L-438,-751C-438,-681,-385,-625,-321,-625L321,-625C385,-625,437,-681,437,-751L437,-874L436,-896L430,-918L421,-938Z",
  "M255,-473L-514,-473C-543,-473,-566,-496,-566,-524C-566,-553,-543,-576,-514,-576L255,-576C284,-576,306,-553,306,-524C306,-496,284,-473,255,-473ZM255,-119L-514,-119C-543,-119,-566,-142,-566,-170C-566,-199,-543,-222,-514,-222L255,-222C284,-222,306,-199,306,-170C306,-142,284,-119,255,-119ZM-108,450L-498,450C-527,450,-549,428,-549,399C-549,370,-527,347,-498,347L-108,347C-79,347,-56,370,-56,399C-56,428,-79,450,-108,450ZM-167,599C-181,599,-194,593,-203,583C-223,563,-223,531,-203,510L-91,399L-204,286C-225,265,-225,233,-204,213C-184,192,-152,192,-131,213L18,362C27,371,33,384,33,398C33,411,28,425,18,434L-131,582C-142,593,-154,599,-167,599ZM413,398ZM280,398L283,421L289,443L298,464L312,483L328,500L347,513L368,523L390,529L413,531L436,529L459,523L480,513L499,500L515,483L528,464L538,443L544,421L546,398L544,375L538,352L528,331L515,312L499,296L480,283L459,273L436,267L413,265L390,267L368,273L347,283L328,296L312,312L298,331L289,352L283,375L280,398ZM787,398ZM654,398L656,420L661,441L670,461L682,479L697,496L714,509L734,519L754,527L776,530L798,530L820,527L840,519L860,509L877,496L892,479L904,461L913,441L918,420L920,398L918,376L913,355L904,335L892,316L877,300L860,287L840,276L820,269L798,266L776,266L754,269L734,276L714,287L697,300L682,316L670,335L661,355L656,376L654,398ZM-307,1000L-868,1000C-897,1000,-920,977,-920,949L-920,-949C-920,-977,-897,-1000,-868,-1000L607,-1000C636,-1000,658,-977,658,-949L658,-392C658,-363,636,-340,607,-340C578,-340,555,-363,555,-392L555,-897L-817,-897L-817,897L-307,897C-278,897,-256,920,-256,949C-256,977,-278,1000,-307,1000Z",
  "M513,-391L609,-391C661,-391,696,-426,696,-478C696,-530,661,-565,609,-565L513,-565C470,-809,261,-1000,0,-1000C-261,-1000,-470,-809,-513,-565L-609,-565C-661,-565,-696,-530,-696,-478C-696,-426,-661,-391,-609,-391L513,-391ZM-957,957C-957,983,-939,1000,-913,1000L-609,1000L-609,513C-800,609,-939,748,-957,957ZM522,478L522,1000L913,1000C939,1000,957,983,957,957C930,722,757,565,522,478ZM217,243C400,139,522,-96,522,-304L-522,-304C-522,-96,-400,130,-217,243C-191,261,-174,287,-174,322C-174,365,-209,409,-252,409C-348,426,-435,452,-522,478L-522,1000L435,1000L435,452C374,435,313,426,252,409C209,400,174,365,174,313C174,287,191,261,217,243Z",
  "M-269,667L-889,667L-908,665L-927,660L-944,652L-960,641L-974,627L-985,611L-993,593L-998,575L-1000,555L-998,536L-993,517L-985,500L-974,484L-960,470L-944,459L-927,451L-908,446L-889,444L-269,444L-412,301L-423,286L-431,270L-436,252L-439,234L-438,215L-434,197L-428,180L-418,164L-406,150L-392,138L-377,129L-359,122L-341,118L-323,118L-305,120L-287,125L-270,134L-256,144L67,467L80,479L92,493L101,508L107,525L111,543L111,561L109,579L104,596L96,612L85,627L72,640L-256,968L-270,980L-287,990L-305,996L-325,1000L-344,1000L-363,996L-381,989L-398,980L-413,967L-425,952L-435,935L-441,917L-445,898L-445,879L-441,860L-434,841L-425,825L-412,810L-269,667ZM889,1000L444,1000L425,998L406,993L389,985L373,974L359,960L348,944L340,927L335,908L333,889L335,870L340,851L348,833L359,817L373,804L389,793L406,784L425,779L444,778L778,778L778,-272L0,-758L-778,-271L-778,0L-779,19L-784,38L-793,55L-804,71L-817,85L-833,96L-851,104L-870,109L-889,111L-908,109L-927,104L-944,96L-960,85L-974,71L-985,55L-993,38L-998,19L-1000,0L-1000,-333L-998,-352L-994,-370L-986,-387L-976,-403L-963,-417L-948,-428L-59,-983L-43,-992L-26,-997L-9,-1000L9,-1000L26,-997L43,-992L59,-983L948,-428L963,-417L976,-403L986,-387L994,-370L998,-352L1000,-333L1000,889L999,906L995,923L988,939L979,954L967,967L954,979L939,988L923,994L906,999L889,1000Z",
  "M976,677L117,-812L103,-831L87,-847L67,-861L46,-871L23,-877L0,-879L-20,-877L-40,-873L-58,-866L-76,-855L-92,-843L-105,-828L-117,-812L-976,677C-1000,719,-1000,770,-976,812C-952,853,-907,879,-859,879L859,879C907,879,952,853,976,812C1000,770,1000,719,976,677ZM17,-396C79,-396,139,-342,139,-292L109,229C109,280,68,321,17,321C-33,321,-74,280,-74,229L-104,-292C-104,-342,-56,-394,17,-396ZM17,699C-52,699,-108,643,-108,574C-108,504,-52,448,17,448C87,448,143,504,143,574C143,643,87,699,17,699Z",
  "M-126,-424C-252,-282,-342,-180,-394,-120C-415,-96,-427,-83,-433,-75L-437,-71L-440,-66L-443,-63L-445,-60L-453,-50C-505,18,-564,96,-583,185C-605,292,-565,395,-462,492C-373,576,-282,618,-191,618C-176,618,-161,617,-146,615C29,588,129,412,134,405C151,375,140,336,109,319C79,302,41,312,23,343C23,344,-52,473,-166,490C-231,500,-302,469,-375,400C-520,263,-464,173,-352,27L-342,13L-342,13C-335,5,-293,-44,-31,-340L-30,-342C-29,-342,0,-376,43,-396C94,-420,139,-413,186,-377C298,-290,263,-241,229,-194C226,-190,223,-186,220,-182C200,-153,208,-114,237,-94C265,-74,305,-82,325,-111C326,-113,329,-116,331,-120C350,-146,386,-195,389,-260C392,-337,350,-410,264,-477C98,-606,-64,-499,-126,-424ZM-342,13L-342,13C-339,10,-339,9,-342,13ZM191,-632C222,-615,260,-627,277,-657C278,-659,354,-792,468,-810C533,-820,602,-790,675,-722C823,-582,761,-483,647,-334L642,-327L642,-327C635,-319,593,-270,331,26L329,28C329,28,301,61,260,81C208,106,162,100,113,63C71,30,47,-1,44,-29C40,-60,63,-90,82,-113C87,-120,91,-126,95,-132C115,-161,108,-200,79,-220C50,-240,11,-232,-9,-203C-11,-201,-14,-196,-18,-191C-44,-158,-92,-96,-82,-13C-74,49,-34,109,36,163C92,207,148,223,199,223C300,223,385,160,426,110C552,-32,642,-134,694,-194C715,-218,727,-231,733,-239L737,-243L740,-248L743,-251L745,-254L748,-258C848,-389,1000,-589,762,-814C659,-911,554,-952,448,-935C272,-908,170,-726,166,-718C149,-688,160,-649,191,-632ZM642,-327L642,-327C640,-325,640,-324,642,-327ZM765,-28C730,-28,702,0,702,35L702,802C702,815,692,825,679,825L-851,825C-863,825,-873,815,-873,802L-873,-730C-873,-743,-863,-753,-851,-753L-85,-753C-50,-753,-22,-781,-22,-816C-22,-851,-50,-880,-85,-880L-851,-880C-933,-880,-1000,-813,-1000,-730L-1000,802C-1000,885,-933,952,-851,952L679,952C762,952,829,885,829,802L829,35C829,0,800,-28,765,-28Z",
  "M622,484L-539,484C-622,484,-694,427,-719,344L-980,-519C-1000,-583,-988,-654,-949,-707C-913,-755,-859,-783,-800,-783L82,-783C117,-783,145,-755,145,-720C145,-685,117,-657,82,-657L-800,-657C-825,-657,-840,-641,-847,-632C-863,-610,-868,-582,-860,-556L-599,307C-589,337,-566,357,-539,357L622,357C650,357,675,335,683,303L869,-454C877,-487,912,-508,945,-500C979,-491,1000,-457,992,-423L805,333C783,422,708,484,622,484ZM903,-375L-891,-375C-926,-375,-954,-403,-954,-438C-954,-473,-926,-501,-891,-501L903,-501C938,-501,967,-473,967,-438C967,-403,938,-375,903,-375ZM267,46L-239,46C-274,46,-303,18,-303,-17C-303,-52,-274,-80,-239,-80L267,-80C302,-80,330,-52,330,-17C330,18,302,46,267,46ZM14,299C-21,299,-49,271,-49,236L-49,-270C-49,-305,-21,-333,14,-333C49,-333,77,-305,77,-270L77,236C77,271,49,299,14,299ZM275,-717C275,-741,294,-759,317,-759C341,-759,360,-741,360,-717C360,-694,341,-675,317,-675C294,-675,275,-694,275,-717ZM317,-644C277,-644,244,-677,244,-717C244,-758,277,-791,317,-791C358,-791,391,-758,391,-717C391,-677,358,-644,317,-644ZM317,-728C312,-728,307,-723,307,-717C307,-711,312,-707,317,-707C323,-707,328,-711,328,-717C328,-723,323,-728,317,-728ZM524,-717ZM482,-717L483,-710L484,-703L488,-696L492,-690L497,-685L503,-681L510,-678L517,-676L524,-675L531,-676L538,-678L545,-681L551,-685L556,-690L560,-696L564,-703L565,-710L566,-717L565,-725L564,-732L560,-738L556,-744L551,-750L545,-754L538,-757L531,-759L524,-759L517,-759L510,-757L503,-754L497,-750L492,-744L488,-738L484,-732L483,-725L482,-717ZM524,-644C483,-644,450,-677,450,-717C450,-758,483,-791,524,-791C565,-791,598,-758,598,-717C598,-677,565,-644,524,-644ZM524,-728C518,-728,513,-723,513,-717C513,-711,518,-707,524,-707C530,-707,535,-711,535,-717C535,-723,530,-728,524,-728ZM764,-717C764,-694,745,-675,722,-675C699,-675,680,-694,680,-717C680,-741,699,-759,722,-759C745,-759,764,-741,764,-717ZM722,-644C682,-644,649,-677,649,-717C649,-758,682,-791,722,-791C763,-791,796,-758,796,-717C796,-677,763,-644,722,-644ZM722,-728C716,-728,712,-723,712,-717C712,-711,716,-707,722,-707C728,-707,733,-711,733,-717C733,-723,728,-728,722,-728ZM-368,791C-471,791,-554,708,-554,605C-554,503,-471,419,-368,419C-265,419,-182,503,-182,605C-182,708,-265,791,-368,791ZM-368,545C-401,545,-428,572,-428,605C-428,638,-401,665,-368,665C-335,665,-308,638,-308,605C-308,572,-335,545,-368,545ZM398,791C296,791,212,708,212,605C212,503,296,419,398,419C501,419,584,503,584,605C584,708,501,791,398,791ZM398,545C365,545,339,572,339,605C339,638,365,665,398,665C431,665,458,638,458,605C458,572,431,545,398,545Z",
  "M791,-791C583,-1000,245,-1000,36,-791L-203,-552L-77,-426L162,-665C295,-798,519,-812,666,-665C812,-518,798,-295,666,-162L426,77L553,204L792,-36C1000,-244,1000,-582,791,-791ZM-162,666C-294,798,-518,812,-665,666C-812,519,-798,295,-665,162L-426,-77L-552,-203L-791,36C-1000,245,-1000,583,-791,791C-582,1000,-244,1000,-36,791L203,552L77,426L-162,666ZM-621,-747C-629,-754,-641,-754,-649,-747L-747,-649C-754,-641,-754,-629,-747,-621L622,747C629,755,642,755,650,747L747,650C755,642,755,629,747,622L-621,-747Z",
  "M784,-468L-876,-468L-878,675C-878,678,-884,751,-809,751L-101,751C-58,751,-33,769,-33,810C-33,840,-57,868,-101,868L-820,868C-959,868,-1000,761,-1000,675L-1000,-533C-1000,-570,-985,-606,-960,-632L-733,-875C-699,-911,-649,-932,-596,-932L508,-932C562,-932,612,-911,646,-875L872,-632C899,-605,913,-570,913,-533L913,-167C913,-126,890,-102,847,-102C805,-102,783,-126,783,-167C784,-301,784,-409,784,-468ZM730,-594L550,-787C527,-814,503,-805,495,-805L-608,-805C-622,-807,-635,-801,-645,-790L-821,-594L730,-594ZM-132,327C-132,37,102,-198,392,-198C682,-198,917,36,917,326C917,433,884,537,823,625L964,764C1000,802,998,862,960,898C924,932,867,932,831,898L690,759C452,923,125,863,-40,625C-101,537,-132,433,-132,327ZM387,724C596,724,762,571,782,350C801,129,598,-82,373,-71C149,-60,-4,102,-4,315C-4,528,179,724,387,724Z",
  "M180,-116C119,-116,58,-99,3,-72C-30,-55,-36,-11,-8,17L180,204L113,271L-75,83C-86,72,-97,66,-113,66C-135,66,-152,77,-163,99C-235,243,-213,425,-91,547C-14,624,80,657,180,657C224,657,268,652,307,635L622,939L660,978C682,1000,715,1000,738,978L776,939L854,862L892,823C914,801,914,768,892,746L854,707L539,403C588,265,555,110,450,0C373,-77,273,-116,180,-116ZM434,365C417,403,428,448,461,481L776,785L699,862L384,558C362,536,334,525,307,525C296,525,285,525,268,530C240,541,207,547,174,547C102,547,30,519,-19,464C-86,398,-113,309,-97,221L30,348C52,370,80,381,108,381C135,381,163,370,185,348L251,282C296,238,296,166,251,127L124,0C141,-6,157,-6,174,-6C246,-6,318,22,367,77C445,149,472,260,434,365ZM-141,-171C-141,-204,-169,-227,-196,-227L-528,-227C-555,-227,-583,-204,-583,-171C-583,-138,-555,-116,-528,-116L-196,-116C-169,-116,-141,-144,-141,-171ZM-367,105L-517,105C-550,105,-577,127,-577,160C-577,193,-550,215,-517,215L-367,215C-334,215,-307,193,-307,160C-307,127,-334,105,-367,105ZM-367,436L-517,436C-550,436,-577,459,-577,492C-577,525,-550,547,-517,547L-367,547C-334,547,-307,525,-307,492C-307,459,-334,436,-367,436ZM-528,-448L467,-448C494,-448,522,-475,522,-503C522,-530,494,-558,467,-558L-528,-558C-555,-558,-583,-530,-583,-503C-583,-475,-555,-448,-528,-448ZM798,-1000L-859,-1000C-887,-1000,-914,-972,-914,-945L-914,934C-914,967,-887,989,-859,989L-30,989C3,989,25,967,25,934C25,901,3,878,-30,878L-804,878L-804,-890L743,-890L743,-61C743,-28,765,-6,798,-6C831,-6,854,-28,854,-61L854,-945C854,-978,826,-1000,798,-1000Z",
  "M-186,1000L-971,1000L-971,-643C-971,-843,-814,-1000,-614,-1000L743,-1000L743,-214C743,-171,714,-143,671,-143C629,-143,600,-171,600,-214L600,-857L-614,-857C-729,-857,-829,-757,-829,-643L-829,857L-186,857C-143,857,-114,886,-114,929C-114,971,-143,1000,-186,1000ZM314,-500C314,-543,286,-571,243,-571L-471,-571C-514,-571,-543,-543,-543,-500C-543,-457,-514,-429,-471,-429L243,-429C286,-429,314,-457,314,-500ZM29,-71C29,-114,0,-143,-43,-143L-471,-143C-514,-143,-543,-114,-543,-71C-543,-29,-514,0,-471,0L-43,0C0,0,29,-29,29,-71ZM-257,357C-257,314,-286,286,-329,286L-471,286C-514,286,-543,314,-543,357C-543,400,-514,429,-471,429L-329,429C-286,429,-257,400,-257,357ZM971,500C971,557,957,600,943,657C886,643,829,657,800,700C771,757,786,814,829,843C757,914,671,971,557,1000C557,943,500,900,443,900C386,900,343,943,329,1000C229,971,129,929,57,843C100,814,114,743,86,700C57,643,0,629,-57,657C-71,614,-86,557,-86,500C-86,443,-71,400,-57,343C0,357,57,343,86,300C114,243,100,186,57,157C157,71,243,29,357,0C357,57,414,100,471,100C529,100,571,57,586,0C686,29,786,71,857,157C814,186,800,257,829,300C857,357,914,371,971,343C957,400,971,443,971,500ZM671,500C671,386,586,300,471,300C357,300,271,386,271,500C271,614,357,700,471,700C586,700,671,614,671,500Z",
  "M926,526L376,-17C409,-99,428,-188,428,-281C428,-670,108,-986,-286,-986C-410,-986,-527,-955,-628,-900L-221,-498L-214,-490L-208,-481L-204,-471L-201,-460L-200,-449L-201,-438L-204,-428L-208,-418L-214,-409L-221,-401L-407,-217L-416,-209L-427,-203L-438,-199L-450,-197L-463,-197L-474,-199L-486,-203L-496,-209L-506,-217L-913,-619L-961,-512L-990,-398L-1000,-281C-1000,108,-680,423,-286,423C-177,423,-73,399,19,356L559,888C658,986,819,986,918,888L926,881L952,851L973,817L988,781L997,743L1000,703L997,664L988,626L972,589L952,556L926,526Z",
  "M-336,-80C-327,-80,-316,-84,-310,-92L-129,-268C-115,-282,-115,-302,-129,-315L-290,-474L-293,-481C-302,-502,-301,-528,-290,-552L-287,-555L-275,-576C-259,-605,-218,-655,-176,-701L-174,-703C-96,-778,10,-825,120,-833L124,-833C138,-833,150,-840,158,-854C165,-870,158,-888,138,-899L135,-899C-117,-1000,-402,-944,-595,-757L-983,-388C-990,-380,-992,-374,-992,-363C-992,-353,-987,-347,-983,-339L-753,-118C-740,-104,-716,-104,-702,-118L-547,-268L-521,-243L-363,-89C-354,-86,-345,-80,-336,-80ZM856,771C863,763,865,757,865,747C865,736,860,727,856,722L375,240C361,226,340,226,328,240L149,416C141,424,140,430,140,440C140,449,143,460,149,465L630,947C637,955,643,956,654,956C664,956,670,953,678,947L856,771ZM841,-213C962,-333,992,-514,919,-670C915,-679,906,-689,894,-689C882,-692,870,-686,863,-680L633,-449L503,-579L732,-808C741,-817,744,-830,741,-839C738,-851,732,-860,720,-864C669,-888,610,-899,553,-899C444,-899,345,-857,271,-781C165,-676,127,-517,171,-376L179,-354L-400,223L-422,216C-563,170,-723,208,-829,315C-946,433,-980,614,-912,765C-907,777,-898,784,-886,786C-874,787,-862,783,-856,777L-630,551L-500,680L-723,906C-731,914,-735,926,-732,937C-729,947,-723,958,-713,962C-658,988,-600,1000,-538,1000C-429,1000,-330,958,-254,882C-149,777,-111,615,-158,471L-165,451L410,-124L431,-116C473,-103,515,-95,560,-95C667,-95,765,-137,841,-213Z",
  "M156,-500C190,-500,216,-471,216,-436C216,-401,190,-372,156,-372L-605,-372C-638,-372,-665,-401,-665,-436C-665,-471,-638,-500,-605,-500L156,-500ZM-208,353L-604,353C-638,353,-664,325,-664,289C-664,254,-638,225,-604,225L-181,225C-194,266,-203,309,-208,353ZM-49,-9L-604,-9C-638,-9,-664,-38,-664,-74C-664,-109,-638,-138,-604,-138L101,-138C45,-102,-6,-59,-49,-9ZM551,-233C520,-237,488,-240,455,-240C445,-240,434,-239,423,-239L423,-792C423,-822,399,-847,369,-847L-817,-847C-846,-847,-871,-822,-871,-792L-871,643C-871,673,-846,698,-817,698L-156,698C-134,747,-107,792,-75,834L-935,834C-971,834,-1000,805,-1000,770L-1000,-906C-1000,-941,-971,-970,-935,-970L486,-970C522,-970,551,-942,551,-906L551,-233ZM895,105L503,499L304,297C291,284,270,284,257,297L187,367C175,380,175,401,187,414L409,639C410,639,410,639,410,640L458,688L470,700L480,710C493,723,514,723,527,710L974,260C991,312,1000,368,1000,426C1000,726,756,970,455,970C155,970,-89,727,-89,426C-89,125,155,-119,455,-119C636,-119,796,-31,895,105Z",
  "M103,617C96,572,96,525,103,480L-739,480C-808,480,-864,424,-864,356L-864,-721C-864,-790,-808,-846,-739,-846L723,-846C792,-846,848,-790,848,-721L848,173C865,187,882,201,899,217C934,253,963,292,984,335L984,-721C984,-865,867,-982,723,-982L-739,-982C-883,-982,-1000,-865,-1000,-721L-1000,356C-1000,499,-883,617,-739,617L103,617ZM235,880C203,847,176,811,155,772L-762,772L-762,909L268,909C257,900,246,890,235,880ZM-101,88C-119,88,-136,81,-149,68L-386,-169L-290,-266L-98,-74L365,-471L454,-368L-56,71C-69,82,-85,88,-101,88ZM1000,885L880,766C984,617,969,411,837,278C688,129,446,129,297,278C148,428,148,669,297,818C371,893,469,930,567,930C643,930,719,908,784,863L904,982L1000,885ZM393,722C297,626,297,471,393,375C441,327,504,303,567,303C630,303,693,327,740,375C836,471,836,626,740,722C645,818,489,818,393,722Z",
  "M553,-103L553,-568L394,-568L394,-110C447,-115,501,-113,553,-103ZM-241,-453L-82,-453L-82,123L-241,123ZM236,-67L236,-377L77,-377L77,39C124,-7,178,-42,236,-67ZM41,778L-762,778L-762,914L219,914C165,889,114,854,70,809C60,799,50,789,41,778ZM-559,-176L-400,-176L-400,123L-559,123ZM-52,622C-69,578,-80,532,-85,486L-739,486C-808,486,-864,430,-864,362L-864,-714C-864,-783,-808,-839,-739,-839L722,-839C790,-839,846,-783,846,-714L846,59C919,136,964,230,982,329L982,-714C982,-858,866,-975,722,-975L-739,-975C-883,-975,-1000,-858,-1000,-714L-1000,362C-1000,505,-883,622,-739,622L-52,622ZM601,255L395,462L303,370L207,466L347,606C360,619,377,626,395,626C413,626,431,619,443,606L698,352L601,255ZM1000,879L803,682C926,512,911,273,758,120C589,-49,314,-49,145,120C-25,290,-25,565,145,734C229,818,341,860,452,860C541,860,631,833,707,778L904,975L1000,879ZM241,638C185,582,154,507,154,428C154,348,185,273,241,217C297,161,372,130,451,130C531,130,606,161,662,217C718,274,749,348,749,428C749,507,718,582,662,638C605,694,531,725,451,725C372,725,297,694,241,638Z",
  "M789,-1000L772,-1000C726,-1000,687,-971,664,-931C640,-891,596,-864,546,-864C503,-864,465,-883,440,-913C398,-965,340,-1000,274,-1000L273,-1000C206,-1000,148,-965,106,-913C81,-883,43,-864,1,-864C-42,-864,-80,-883,-105,-913C-147,-965,-205,-1000,-272,-1000C-338,-1000,-396,-965,-439,-913C-464,-883,-502,-864,-544,-864C-594,-864,-638,-891,-662,-931C-685,-971,-724,-1000,-771,-1000L-789,-1000C-855,-1000,-909,-946,-909,-879L-909,879C-909,946,-855,1000,-789,1000L-771,1000C-724,1000,-685,971,-662,931C-638,891,-594,864,-544,864C-502,864,-464,883,-439,913C-396,965,-338,1000,-272,1000C-205,1000,-147,965,-105,913C-80,883,-42,864,1,864C43,864,81,883,106,913C148,965,206,1000,273,1000L274,1000C340,1000,398,965,440,913C465,883,503,864,546,864C596,864,640,891,664,931C687,971,726,1000,772,1000L789,1000C855,1000,909,946,909,879L909,-879C909,-946,855,-1000,789,-1000ZM330,201C330,228,308,250,281,250L-620,250C-647,250,-669,228,-669,201L-669,133C-669,105,-647,83,-620,83L281,83C308,83,330,106,330,133L330,201ZM664,-216C664,-189,641,-166,614,-166L-619,-166C-647,-166,-669,-189,-669,-216L-669,-283C-669,-311,-647,-333,-619,-333L614,-333C641,-333,664,-311,664,-283L664,-216Z",
  "M-22,583C-22,455,27,338,106,250L-621,250C-649,250,-671,228,-671,200L-671,132C-671,104,-649,82,-621,82L280,82C299,82,315,92,323,109C371,93,422,84,476,84C623,84,756,148,847,251C868,275,908,260,908,228L908,-880C908,-946,854,-1000,788,-1000L774,-1000C729,-1000,686,-977,666,-937C644,-893,597,-863,545,-863C499,-863,460,-886,435,-919C399,-968,344,-1000,284,-1000L277,-1000C211,-1000,148,-972,110,-919C85,-886,44,-863,0,-863C-42,-863,-81,-883,-105,-914C-147,-965,-205,-1000,-272,-1000C-338,-1000,-397,-965,-439,-914C-463,-883,-502,-863,-544,-863C-596,-863,-642,-894,-665,-937C-686,-977,-728,-1000,-772,-1000L-788,-1000C-854,-1000,-908,-946,-908,-880L-908,880C-908,946,-854,1000,-788,1000L-772,1000C-728,1000,-685,977,-665,937C-643,893,-596,863,-544,863C-502,863,-463,883,-439,914C-397,965,-338,1000,-272,1000C-205,1000,-147,965,-105,914C-81,883,-42,863,0,863L2,863C29,863,47,837,35,812C-1,744,-22,666,-22,583ZM-671,-284C-671,-312,-649,-334,-621,-334L614,-334C641,-334,664,-312,664,-284L664,-216C664,-189,642,-166,614,-166L-621,-166C-648,-166,-671,-188,-671,-216L-671,-284ZM487,167C257,167,70,354,70,583C70,813,257,1000,487,1000C716,1000,903,813,903,583C903,354,716,167,487,167ZM673,728L632,770C620,783,599,783,586,770L425,610L425,414C425,396,440,382,457,382L516,382C534,382,548,397,548,414L548,559L672,683C686,693,686,714,673,728Z",
  "M-833,-1000L-862,-997L-890,-990L-917,-978L-940,-961L-961,-940L-978,-917L-990,-890L-997,-862L-1000,-833L-1000,833L-997,862L-990,890L-978,917L-961,940L-940,961L-917,978L-890,990L-862,997L-833,1000L833,1000L862,997L890,990L917,978L940,961L961,940L978,917L990,890L997,862L1000,833L1000,-833L997,-862L990,-890L978,-917L961,-940L940,-961L917,-978L890,-990L862,-997L833,-1000L-833,-1000ZM-833,833L-833,-833L833,-833L833,833L-833,833ZM-83,667L-83,-583L83,-583L83,667L-83,667ZM-583,-83L-583,667L-417,667L-417,-83L-583,-83ZM417,167L417,667L583,667L583,167L417,167Z",
  "M750,1000L750,333L917,333L917,1000L750,1000ZM-83,-1000L-83,1000L83,1000L83,-1000L-83,-1000ZM-917,-333L-917,1000L-750,1000L-750,-333L-917,-333Z",
  "M-1000,-833L-997,-862L-990,-890L-978,-917L-961,-940L-940,-961L-917,-978L-890,-990L-862,-997L-833,-1000L833,-1000L862,-997L890,-990L917,-978L940,-961L961,-940L978,-917L990,-890L997,-862L1000,-833L1000,-536L292,-119L292,1000L-292,1000L-292,-119L-1000,-536L-1000,-833ZM833,-833L-833,-833L-833,-631L-125,-214L-125,833L125,833L125,-214L833,-631L833,-833Z",
  "M510,-982L-849,-982L-873,-980L-897,-974L-920,-964L-940,-951L-959,-935L-971,-920L-983,-899L-993,-877L-998,-854L-1000,-829L-998,-805L-992,-782L-982,-760L-969,-739L-953,-721L-396,-194L-396,982L57,642L57,-194L614,-721L631,-740L644,-762L654,-786L659,-811L661,-837L657,-862L650,-887L639,-910L623,-930L605,-948L584,-963L560,-973L535,-980L510,-982ZM-849,-831L510,-831L-94,-259L-94,566L-245,680L-245,-259L-849,-831ZM679,440L466,227L359,333L573,547L359,761L466,868L679,654L893,868L1000,761L786,547L1000,333L893,227L679,440Z",
  "M295,-407L340,-366L391,-333L447,-310L506,-297L567,-294L627,-301L685,-318L739,-346L788,-382L830,-426L864,-476L888,-532L903,-590L908,-651L902,-711L885,-770L859,-825L824,-874L782,-917L732,-952L677,-978L618,-994L558,-1000L498,-995L439,-981L383,-956L333,-922L289,-880L253,-831L226,-777L208,-719L201,-659L204,-598L218,-539L-295,-240L-339,-281L-390,-313L-446,-336L-505,-350L-565,-353L-625,-346L-683,-329L-737,-303L-786,-267L-828,-224L-862,-174L-887,-119L-902,-60L-908,0L-902,60L-887,118L-862,173L-828,223L-786,267L-737,302L-683,329L-625,346L-565,353L-505,350L-446,336L-390,313L-339,280L-295,239L218,538L204,597L201,658L208,718L225,776L253,831L288,880L332,922L383,956L438,980L497,995L557,1000L618,994L676,978L731,952L781,918L824,875L859,825L885,770L901,712L907,651L903,591L888,532L864,476L830,426L788,382L739,346L685,319L627,301L567,294L506,297L447,310L391,333L340,366L295,407L-218,108L-205,55L-201,0L-205,-55L-218,-108L295,-407ZM554,-848L589,-845L623,-836L655,-821L683,-801L708,-776L728,-747L743,-715L752,-682L755,-647L752,-612L743,-578L728,-546L708,-518L683,-493L655,-473L623,-458L589,-449L554,-446L519,-449L486,-458L454,-473L425,-493L400,-518L380,-546L365,-578L356,-612L353,-647L356,-682L365,-715L380,-747L400,-776L425,-801L454,-821L486,-835L519,-844L554,-848ZM-383,-105L-381,-101L-378,-97L-366,-69L-357,-40L-354,-10L-354,20L-359,50L-369,78L-383,105L-404,133L-429,157L-458,176L-489,190L-523,198L-557,201L-592,197L-625,188L-656,173L-685,153L-709,128L-729,100L-743,68L-752,35L-755,0L-752,-34L-743,-68L-729,-99L-709,-128L-685,-153L-656,-173L-625,-188L-592,-197L-557,-201L-523,-198L-489,-190L-458,-176L-429,-157L-404,-133L-383,-105ZM354,647C354,614,361,582,376,555L382,546L386,536L408,509L433,486L462,468L494,455L527,447L561,445L596,449L628,459L659,475L687,495L711,520L730,548L744,579L752,613L755,647L752,682L743,716L728,747L708,776L683,801L655,821L623,836L589,845L554,848L519,845L486,836L454,821L425,801L400,776L380,747L366,716L356,682L353,647Z",
  "M0,262L-693,747L-693,-827L693,-827L693,747L0,262ZM0,473L730,984L743,992L756,997L771,999L785,1000L800,998L813,993L826,987L838,978L848,967L856,955L862,942L865,928L867,913L867,-827L864,-857L856,-886L843,-913L826,-938L805,-959L780,-977L753,-990L723,-997L693,-1000L-693,-1000L-723,-997L-753,-990L-780,-977L-805,-959L-826,-938L-843,-913L-856,-886L-864,-857L-867,-827L-867,913L-865,928L-862,942L-856,955L-848,967L-838,978L-826,987L-813,993L-800,998L-785,1000L-771,1000L-756,997L-743,992L-730,984L0,473Z",
  "M-459,901L-441,899L-422,895L-405,887L-390,876L-376,863L-366,847L-358,830L-353,812L-351,793L-353,774L-358,756L-366,739L-376,723L-390,710L-405,699L-422,691L-441,687L-459,685L-478,687L-496,691L-513,699L-529,710L-542,723L-553,739L-561,756L-566,774L-567,793L-566,812L-561,830L-553,847L-542,863L-529,876L-513,887L-496,895L-478,899L-459,901ZM703,901L722,899L740,895L757,887L773,876L786,863L797,847L805,830L810,812L811,793L810,774L805,756L797,739L786,723L773,710L757,699L740,691L722,687L703,685L684,687L666,691L649,699L634,710L620,723L610,739L602,756L597,774L595,793L597,812L602,830L610,847L620,863L634,876L649,887L666,895L684,899L703,901ZM-1000,-757L-773,-757L-572,444L-568,462L-561,478L-552,494L-540,507L-526,519L-511,528L-494,535L-477,539L-459,541L874,541L874,397L-434,397L-482,108L762,108L782,107L800,102L817,94L833,84L847,71L859,56L868,39L874,21L997,-469L1000,-488L1000,-507L997,-526L991,-544L981,-561L970,-576L956,-589L940,-599L922,-607L904,-611L885,-613L-602,-613L-634,-805L-639,-822L-646,-839L-655,-854L-667,-868L-681,-879L-696,-889L-713,-896L-730,-900L-748,-901L-1000,-901L-1000,-757ZM740,-36L-506,-36L-578,-469L848,-469L740,-36Z",
  "M-154,-538L154,-538L154,-846L-154,-846L-154,-538ZM308,-846L308,-538L769,-538L796,-536L822,-529L846,-518L868,-502L887,-484L902,-462L914,-437L921,-411L923,-385L923,-77L921,-53L915,-29L906,-6L893,14L877,33L858,48L837,61L815,70L791,75L898,824L899,851L896,877L889,902L877,926L862,947L843,965L821,980L797,991L772,998L746,1000L-746,1000L-772,998L-797,991L-821,980L-843,965L-862,947L-877,926L-889,902L-896,877L-899,851L-898,824L-791,75L-815,70L-837,61L-858,49L-877,33L-893,14L-906,-6L-915,-29L-921,-53L-923,-77L-923,-385L-921,-411L-914,-437L-902,-462L-887,-484L-868,-502L-846,-518L-822,-529L-796,-536L-769,-538L-308,-538L-308,-846L-305,-873L-298,-899L-287,-923L-272,-945L-253,-964L-231,-979L-206,-991L-181,-998L-154,-1000L154,-1000L181,-998L206,-991L231,-979L253,-964L272,-945L287,-923L298,-899L305,-873L308,-846ZM636,-77L769,-77L769,-385L154,-385L-154,-385L-769,-385L-769,-77L636,-77ZM636,77L-636,77L-746,846L-462,846L-462,538L-308,538L-308,846L-77,846L-77,538L77,538L77,846L308,846L308,538L462,538L462,846L746,846L636,77Z",
  "M1000,-665L-1000,-668L-1000,-834L1000,-832L1000,-665ZM-867,462L-339,67L-328,57L-319,46L-313,34L-308,21L-306,7L-306,-7L-308,-21L-313,-34L-319,-46L-328,-57L-339,-67L-867,-462L-879,-470L-892,-475L-905,-478L-920,-479L-934,-477L-947,-473L-960,-467L-971,-458L-981,-448L-989,-437L-995,-424L-999,-410L-1000,-396L-1000,396L-999,410L-995,424L-989,437L-981,448L-971,458L-960,467L-947,473L-934,477L-920,479L-905,478L-892,475L-879,470L-867,462ZM-833,229L-833,-229L-528,0L-833,229ZM1000,84L-83,84L-83,-82L1000,-82L1000,84ZM1000,834L-1000,832L-1000,665L1000,668L1000,834Z",
  "M-560,-440L-560,-280L-800,-280L-814,-279L-827,-275L-840,-269L-851,-261L-861,-251L-869,-240L-875,-227L-879,-214L-880,-200L-880,920L-879,934L-875,947L-869,960L-861,971L-851,981L-840,989L-827,995L-814,999L-800,1000L800,1000L814,999L827,995L840,989L851,981L861,971L869,960L875,947L879,934L880,920L880,-200L879,-214L875,-227L869,-240L861,-251L851,-261L840,-269L827,-275L814,-279L800,-280L-400,-280L-400,-440L-394,-509L-376,-577L-346,-640L-306,-697L-257,-746L-200,-786L-137,-816L-69,-834L0,-840L69,-834L137,-816L200,-786L257,-746L306,-697L346,-640L376,-577L394,-509L400,-440L560,-440L551,-537L526,-632L485,-720L429,-800L360,-869L280,-925L192,-966L97,-991L0,-1000L-97,-991L-192,-966L-280,-925L-360,-869L-429,-800L-485,-720L-526,-632L-551,-537L-560,-440ZM-720,-120L720,-120L720,840L-720,840L-720,-120ZM-320,360L-320,520L320,520L320,360L-320,360Z",
  "M-1000,-1000L-833,-1000L-833,14L-684,51L-541,111L-410,192L-293,293L-192,410L-111,541L-51,684L-14,833L1000,833L1000,1000L-833,1000L-862,997L-890,990L-917,978L-940,961L-961,940L-978,917L-990,890L-997,862L-1000,833L-1000,-1000ZM-183,833L-222,700L-283,575L-364,462L-462,364L-575,283L-700,222L-833,183L-833,833L-183,833Z",
  "M0,-76L934,-465C997,-491,997,-585,934,-611L0,-1000L-934,-611C-997,-585,-997,-491,-934,-465L0,-76ZM0,-245L-703,-538L0,-831L703,-538L0,-245ZM-1000,-150L-1000,39L0,478L1000,39L1000,-150L0,290L-1000,-150ZM-1000,372L-1000,560L0,1000L1000,561L1000,372L0,811L-999,372Z",
  "M-560,-279L-560,-440L-551,-538L-526,-632L-485,-720L-429,-800L-360,-869L-280,-925L-191,-966L-97,-991L0,-1000L97,-991L191,-966L280,-925L360,-869L429,-800L485,-720L526,-632L551,-538L560,-440L560,-279L799,-279L813,-278L827,-274L839,-268L851,-260L861,-250L869,-239L874,-226L878,-213L879,-199L879,920L878,934L874,947L869,960L861,971L851,981L839,989L827,995L813,999L799,1000L-799,1000L-813,999L-827,995L-839,989L-851,981L-861,971L-869,960L-874,947L-878,934L-879,920L-879,-199L-878,-213L-874,-226L-869,-239L-861,-250L-851,-260L-839,-268L-827,-274L-813,-278L-799,-279L-560,-279ZM-400,-440L-400,-279L400,-279L400,-440L394,-510L376,-577L346,-640L306,-697L257,-747L200,-787L137,-816L69,-834L0,-840L-69,-834L-137,-816L-200,-787L-257,-747L-306,-697L-346,-640L-376,-577L-394,-510L-400,-440ZM719,840L719,-119L-719,-119L-719,840L719,840ZM-320,520L-320,361L320,361L320,520L-320,520Z",
  "M-1000,-833L-997,-862L-990,-890L-978,-917L-961,-940L-940,-961L-917,-978L-890,-990L-862,-997L-833,-1000L833,-1000L862,-997L890,-990L917,-978L940,-961L961,-940L978,-917L990,-890L997,-862L1000,-833L1000,833L997,862L990,890L978,917L961,940L940,961L917,978L890,990L862,997L833,1000L-833,1000L-862,997L-890,990L-917,978L-940,961L-961,940L-978,917L-990,890L-997,862L-1000,833L-1000,-833ZM833,833L833,-833L-833,-833L-833,833L833,833ZM583,-500L-583,-500L-583,-333L583,-333L583,-500ZM-583,-83L167,-83L167,83L-583,83L-583,-83Z",
  "M875,-515L63,-983L46,-992L28,-997L10,-1000L-9,-1000L-28,-997L-46,-992L-63,-983L-875,-515L-875,422C-875,467,-851,509,-811,532L0,1000L811,531L829,519L845,503L858,485L867,465L873,444L875,422L875,-515ZM0,-88L-673,-476L0,-864L673,-476L0,-88ZM67,29L740,-359L740,417L67,805L67,29ZM-67,29L-67,805L-740,417L-740,-359L-67,29Z",
  "M167,-417L159,-330L137,-246L100,-167L50,-95L-12,-34L-83,16L-162,53L-247,76L-333,83L-420,76L-504,53L-583,16L-655,-34L-716,-95L-766,-167L-803,-246L-826,-330L-833,-417L-826,-503L-803,-588L-766,-667L-716,-738L-655,-800L-583,-850L-504,-887L-420,-909L-333,-917L-247,-909L-162,-887L-83,-850L-12,-800L50,-738L100,-667L137,-588L159,-503L167,-417ZM1000,-750L997,-721L990,-693L978,-667L961,-643L940,-622L917,-606L890,-593L862,-586L833,-583L804,-586L776,-593L750,-606L726,-622L706,-643L689,-667L677,-693L669,-721L667,-750L669,-779L677,-807L689,-833L706,-857L726,-878L750,-894L776,-907L804,-914L833,-917L862,-914L890,-907L917,-894L940,-878L961,-857L978,-833L990,-807L997,-779L1000,-750ZM0,-417L-5,-475L-20,-531L-45,-583L-78,-631L-119,-672L-167,-705L-219,-730L-275,-745L-333,-750L-391,-745L-447,-730L-500,-705L-548,-672L-589,-631L-622,-583L-647,-531L-662,-475L-667,-417L-662,-359L-647,-303L-622,-250L-589,-202L-548,-161L-500,-128L-447,-103L-391,-88L-333,-83L-275,-88L-219,-103L-167,-128L-119,-161L-78,-202L-45,-250L-20,-303L-5,-359L0,-417ZM1000,333L994,406L975,476L944,542L903,601L851,653L792,694L726,725L656,744L583,750L511,744L441,725L375,694L316,653L264,601L222,542L192,476L173,406L167,333L173,261L192,191L222,125L264,66L316,14L375,-28L441,-58L511,-77L583,-83L656,-77L726,-58L792,-28L851,14L903,66L944,125L975,191L994,261L1000,333ZM833,333L830,290L818,248L800,208L775,173L744,142L708,117L669,98L627,87L583,83L540,87L498,98L458,117L423,142L392,173L367,208L348,248L337,290L333,333L337,377L348,419L367,458L392,494L423,525L458,550L498,568L540,580L583,583L627,580L669,568L708,550L744,525L775,494L800,458L818,419L830,377L833,333ZM-750,917L-707,913L-664,902L-625,883L-589,858L-558,827L-533,792L-515,752L-504,710L-500,667L-504,623L-515,581L-533,542L-558,506L-589,475L-625,450L-664,432L-707,420L-750,417L-793,420L-836,432L-875,450L-911,475L-942,506L-967,542L-985,581L-996,623L-1000,667L-996,710L-985,752L-967,792L-942,827L-911,858L-875,883L-836,902L-793,913L-750,917Z",
  "M1000,750L-1000,750L0,-750L1000,750Z",
  "M826,-814L826,230L-704,230L-417,-56L-540,-179L-975,255L-985,267L-992,280L-997,295L-1000,310L-1000,325L-997,340L-992,354L-985,368L-975,379L-540,814L-417,691L-704,404L826,404L856,402L886,394L913,381L938,363L959,342L977,317L990,290L997,260L1000,230L1000,-814L826,-814Z",
  "M703,-491L417,-777L540,-900L974,-466L983,-455L990,-444L996,-431L999,-418L1000,-404L999,-390L996,-377L990,-364L983,-353L974,-342L540,92L417,-31L703,-317L-304,-317L-395,-309L-483,-286L-565,-247L-640,-195L-704,-131L-756,-56L-795,26L-818,114L-826,205L-818,295L-795,383L-756,466L-704,540L-640,604L-565,657L-483,695L-395,719L-304,726L565,726L565,900L-304,900L-425,890L-542,858L-652,807L-752,738L-837,652L-907,553L-958,443L-989,325L-1000,205L-989,84L-958,-33L-907,-143L-837,-242L-752,-328L-652,-398L-542,-449L-425,-480L-304,-491L703,-491Z",
  "M-833,1000L-862,997L-890,990L-917,978L-940,961L-961,940L-978,917L-990,890L-997,862L-1000,833L-1000,-833L-997,-862L-990,-890L-978,-917L-961,-940L-940,-961L-917,-978L-890,-990L-862,-997L-833,-1000L-83,-1000L-83,-833L-833,-833L-833,833L833,833L833,83L1000,83L1000,833L997,862L990,890L978,917L961,940L940,961L917,978L890,990L862,997L833,1000L-833,1000ZM167,-1000L167,-833L716,-833L0,-118L118,0L833,-716L833,-167L1000,-167L1000,-917L999,-931L995,-945L989,-958L981,-970L970,-981L958,-989L945,-995L931,-999L917,-1000L167,-1000Z",
  "M-704,-491L-417,-778L-540,-901L-975,-466L-985,-455L-992,-441L-997,-427L-1000,-412L-1000,-397L-997,-382L-992,-367L-985,-354L-975,-342L-540,92L-417,-31L-704,-317L304,-317L395,-309L483,-286L565,-247L640,-195L704,-131L756,-56L795,26L818,114L826,205L818,295L795,383L756,466L704,540L640,605L565,657L483,695L395,719L304,727L-566,727L-566,901L304,901L425,890L542,859L652,808L751,738L837,652L907,553L958,443L989,326L1000,205L989,84L958,-33L907,-143L837,-243L751,-328L652,-398L542,-449L425,-481L304,-491L-704,-491Z",
  "M-750,-1000L-750,1000L750,0L-750,-1000Z",
  "M-910,711C-900,714,-885,714,-856,714L-379,714C-359,714,-349,714,-341,712L-330,709L-320,704L-311,697L-303,689L-296,680L-291,670L-288,659C-286,651,-286,641,-286,621L-286,-429C-286,-504,-286,-542,-292,-556L-297,-567L-305,-576L-314,-585L-325,-591L-336,-596L-348,-598L-360,-599L-373,-597L-384,-593L-395,-588L-405,-580C-416,-570,-432,-536,-463,-467L-940,583C-953,610,-959,623,-960,634L-960,646L-959,659L-955,670L-949,681L-941,691L-932,700L-922,706L-910,711ZM-429,-198L-429,571L-778,571L-429,-198ZM-72,-1000L71,-1000L71,1000L-72,1000L-72,-1000ZM960,634L960,645L959,656L956,667L952,677L946,686L938,694L930,701L920,707L910,711C900,714,885,714,856,714L379,714C359,714,349,714,340,712L330,709L320,704L311,697L303,689L296,680L291,670L287,659C286,651,286,641,286,621L286,-429C286,-504,286,-542,291,-556L297,-567L305,-576L314,-584L325,-591L336,-596L348,-598L360,-599L373,-597L384,-593L395,-588L405,-580C416,-570,432,-536,463,-467L940,583C952,610,958,623,960,634ZM428,571L778,571L428,-198L428,571Z",
  "M0,1000L174,985L342,940L500,866L643,766L766,643L866,500L940,342L985,174L1000,0L985,-174L940,-342L866,-500L766,-643L643,-766L500,-866L342,-940L174,-985L0,-1000L-174,-985L-342,-940L-500,-866L-643,-766L-766,-643L-866,-500L-940,-342L-985,-174L-1000,0L-985,174L-940,342L-866,500L-766,643L-643,766L-500,866L-342,940L-174,985L0,1000ZM0,-857L149,-844L293,-805L429,-742L551,-657L657,-551L742,-429L805,-293L844,-149L857,0L844,149L805,293L742,429L657,551L551,657L429,742L293,805L149,844L0,857L-149,844L-293,805L-429,742L-551,657L-657,551L-742,429L-805,293L-844,149L-857,0L-844,-149L-805,-293L-742,-429L-657,-551L-551,-657L-429,-742L-293,-805L-149,-844L0,-857ZM-71,56L-71,-571L71,-571L71,-4L387,328L286,429L-71,56Z",
  "M-1000,-846L-998,-873L-991,-899L-979,-923L-964,-945L-945,-964L-923,-979L-899,-991L-873,-998L-846,-1000L846,-1000L873,-998L899,-991L923,-979L945,-964L964,-945L979,-923L991,-899L998,-873L1000,-846L1000,846L998,873L991,899L979,923L964,945L945,964L923,979L899,991L873,998L846,1000L-846,1000L-873,998L-899,991L-923,979L-945,964L-964,945L-979,923L-991,899L-998,873L-1000,846L-1000,-846ZM846,846L846,-846L-846,-846L-846,846L846,846ZM0,77L67,71L132,54L192,25L247,-13L295,-60L333,-115L361,-176L379,-241L385,-308L379,-374L361,-439L333,-500L295,-555L247,-602L192,-641L132,-669L67,-686L0,-692L-67,-686L-132,-669L-192,-641L-247,-602L-295,-555L-333,-500L-361,-439L-379,-374L-385,-308L-379,-241L-361,-176L-333,-115L-295,-60L-247,-13L-192,25L-132,54L-67,71L0,77ZM0,-538L40,-535L79,-525L115,-508L148,-484L177,-456L200,-423L217,-387L227,-348L231,-308L227,-268L217,-229L200,-192L177,-159L148,-131L115,-108L79,-91L40,-80L0,-77L-40,-80L-79,-91L-115,-108L-148,-131L-177,-159L-200,-192L-217,-229L-227,-268L-231,-308L-227,-348L-217,-387L-200,-423L-177,-456L-148,-484L-115,-508L-79,-525L-40,-535L0,-538ZM538,520L367,446L186,400L0,385L-186,400L-367,446L-538,520L-538,692L-692,692L-692,517C-692,463,-665,413,-618,388L-421,302L-214,249L0,231L214,249L421,302L618,388C665,413,692,463,692,517L692,692L538,692L538,520Z",
  "M-67,-801L-132,-826L-200,-841L-269,-843L-338,-834L-404,-813L-466,-782L-521,-740L-568,-689L-607,-631L-634,-568L-651,-500L-656,-431L-649,-362L-630,-295L-600,-233L-560,-176L-511,-127L-454,-87L-392,-57L-325,-38L-256,-32L-256,-156L-302,-161L-347,-174L-390,-194L-428,-220L-462,-253L-490,-291L-511,-332L-525,-377L-531,-423L-529,-470L-520,-516L-503,-560L-480,-600L-449,-636L-414,-666L-374,-690L-330,-707L-284,-717L-237,-719L-191,-713L-146,-699L-67,-801ZM656,-336L651,-269L634,-204L607,-143L571,-86L525,-37L472,4L413,36L350,58L284,69L217,69L150,58L87,36L28,4L-25,-37L-71,-86L-107,-143L-134,-204L-151,-269L-156,-336L-150,-407L-132,-475L-102,-539L-61,-597L-11,-647L47,-688L111,-718L180,-736L250,-742L321,-736L389,-718L453,-688L511,-647L561,-597L602,-539L632,-475L650,-407L656,-336ZM531,-336L527,-382L516,-427L497,-470L472,-509L441,-543L404,-571L363,-594L319,-609L273,-616L227,-616L181,-609L137,-594L96,-571L60,-543L28,-509L3,-470L-16,-427L-27,-382L-31,-336L-27,-287L-14,-240L6,-195L35,-155L69,-121L109,-92L154,-72L201,-59L250,-55L299,-59L346,-72L391,-92L431,-121L465,-155L494,-195L514,-240L527,-287L531,-336ZM-256,58L-488,76L-715,127L-932,210L-949,220L-964,233L-977,247L-987,264L-994,281L-999,300L-1000,320L-1000,593L-999,603L-997,613L-993,622L-988,630L-982,638L-974,644L-966,649L-957,653L-947,655L-938,656L-643,656L-643,531L-875,531L-875,322L-676,246L-468,200L-256,184L-256,59ZM375,340L119,340L-134,385L-375,473L-375,718L313,718L313,843L-437,843L-447,843L-457,840L-466,837L-474,832L-482,825L-488,818L-493,809L-497,800L-499,791L-500,781L-500,471C-500,424,-474,381,-432,362L-173,266L99,217L375,215L375,340ZM461,755L642,574L461,393L549,304L731,485L912,304L1000,393L819,574L1000,755L912,843L731,662L549,843L461,755Z",
  "M-1000,833L-997,862L-990,890L-978,917L-961,940L-940,961L-917,978L-890,990L-862,997L-833,1000L833,1000L862,997L890,990L917,978L940,961L961,940L978,917L990,890L997,862L1000,833L1000,-833L997,-862L990,-890L978,-917L961,-940L940,-961L917,-978L890,-990L862,-997L833,-1000L-833,-1000L-862,-997L-890,-990L-917,-978L-940,-961L-961,-940L-978,-917L-990,-890L-997,-862L-1000,-833L-1000,833ZM833,833L-833,833L-833,-833L833,-833L833,833ZM500,83L-500,83L-500,-83L500,-83L500,83Z",
  "M-958,500L-958,-1000L-792,-1000L-792,500L-958,500ZM-375,-1000L-375,1000L-208,1000L-208,-1000L-375,-1000ZM208,-1000L208,500L375,500L375,-1000L208,-1000ZM792,-1000L792,1000L958,1000L958,-1000L792,-1000Z",
  "M-571,-857L-569,-882L-563,-906L-552,-929L-538,-949L-520,-967L-500,-981L-477,-991L-453,-998L-429,-1000L-404,-998L-380,-991L-357,-981L-337,-967L-319,-949L-305,-929L-294,-906L-288,-882L-286,-857L-288,-832L-294,-808L-305,-786L-319,-765L-337,-748L-357,-733L-380,-723L-404,-716L-429,-714L-453,-716L-477,-723L-500,-733L-520,-748L-538,-765L-552,-786L-563,-808L-569,-832L-571,-857ZM286,-857L288,-882L294,-906L305,-929L319,-949L337,-967L357,-981L380,-991L404,-998L429,-1000L453,-998L477,-991L500,-981L520,-967L538,-949L552,-929L563,-906L569,-882L571,-857L569,-832L563,-808L552,-786L538,-765L520,-748L500,-733L477,-723L453,-716L429,-714L404,-716L380,-723L357,-733L337,-748L319,-765L305,-786L294,-808L288,-832L286,-857ZM-571,-286L-569,-311L-563,-335L-552,-357L-538,-378L-520,-395L-500,-409L-477,-420L-453,-426L-429,-429L-404,-426L-380,-420L-357,-409L-337,-395L-319,-378L-305,-357L-294,-335L-288,-311L-286,-286L-288,-261L-294,-237L-305,-214L-319,-194L-337,-176L-357,-162L-380,-151L-404,-145L-429,-143L-453,-145L-477,-151L-500,-162L-520,-176L-538,-194L-552,-214L-563,-237L-569,-261L-571,-286ZM286,-286L288,-311L294,-335L305,-357L319,-378L337,-395L357,-409L380,-420L404,-426L429,-429L453,-426L477,-420L500,-409L520,-395L538,-378L552,-357L563,-335L569,-311L571,-286L569,-261L563,-237L552,-214L538,-194L520,-176L500,-162L477,-151L453,-145L429,-143L404,-145L380,-151L357,-162L337,-176L319,-194L305,-214L294,-237L288,-261L286,-286ZM-571,286L-569,261L-563,237L-552,214L-538,194L-520,176L-500,162L-477,151L-453,145L-429,143L-404,145L-380,151L-357,162L-337,176L-319,194L-305,214L-294,237L-288,261L-286,286L-288,311L-294,335L-305,357L-319,378L-337,395L-357,409L-380,420L-404,426L-429,429L-453,426L-477,420L-500,409L-520,395L-538,378L-552,357L-563,335L-569,311L-571,286ZM286,286L288,261L294,237L305,214L319,194L337,176L357,162L380,151L404,145L429,143L453,145L477,151L500,162L520,176L538,194L552,214L563,237L569,261L571,286L569,311L563,335L552,357L538,378L520,395L500,409L477,420L453,426L429,429L404,426L380,420L357,409L337,395L319,378L305,357L294,335L288,311L286,286ZM-429,714L-453,716L-477,723L-500,733L-520,748L-538,765L-552,786L-563,808L-569,832L-571,857L-569,882L-563,906L-552,929L-538,949L-520,967L-500,981L-477,991L-453,998L-429,1000L-404,998L-380,991L-357,981L-337,967L-319,949L-305,929L-294,906L-288,882L-286,857L-288,832L-294,808L-305,786L-319,765L-337,748L-357,733L-380,723L-404,716L-429,714ZM286,857L288,832L294,808L305,786L319,765L337,748L357,733L380,723L404,716L429,714L453,716L477,723L500,733L520,748L538,765L552,786L563,808L569,832L571,857L569,882L563,906L552,929L538,949L520,967L500,981L477,991L453,998L429,1000L404,998L380,991L357,981L337,967L319,949L305,929L294,906L288,882L286,857Z",
  "M-1000,-833L-750,-833L-750,-667L-1000,-667L-1000,-833ZM-500,-833L1000,-833L1000,-667L-500,-667L-500,-833ZM-750,-83L-1000,-83L-1000,83L-750,83L-750,-83ZM1000,-83L-500,-83L-500,83L1000,83L1000,-83ZM-750,667L-1000,667L-1000,833L-750,833L-750,667ZM1000,667L-500,667L-500,833L1000,833L1000,667Z",
  "M-667,-1000L-667,1000L-1000,1000L-1000,-1000L-667,-1000ZM1000,-1000L1000,1000L667,1000L667,-1000L1000,-1000ZM500,-1000L500,1000L333,1000L333,-1000L500,-1000ZM167,-1000L167,1000L-167,1000L-167,-1000L167,-1000ZM-333,-1000L-333,1000L-500,1000L-500,-1000L-333,-1000Z",
  "M593,-396L536,-492L465,-578C331,-716,144,-805,-62,-828L-169,-835L-275,-829C-483,-806,-671,-718,-805,-580L-877,-494L-934,-398L-970,-308L-992,-214L-1000,-117C-1000,9,-962,132,-890,241C-853,296,-793,365,-738,414L-763,610L-763,611L-764,614L-766,618L-766,621L-766,625L-766,626L-767,628L-767,630L-767,632L-767,636L-767,638L-765,649L-761,659L-756,668L-749,676L-742,683L-733,689L-723,693L-713,695L-702,695L-692,694L-681,691L-672,687L-672,687L-671,686L-670,686L-668,685L-667,684L-430,565L-309,591L-186,601L-62,595L44,576L147,546L129,538L113,528L98,515L86,499L77,482L71,464L68,445L68,425L-50,453L-171,462L-221,461L-271,456L-277,455L-336,445L-394,430L-407,427L-420,427L-434,428L-447,432L-459,438L-462,439L-614,529L-614,529C-617,531,-619,531,-620,531L-622,531L-624,531L-625,530L-627,529L-628,528L-629,526L-630,525L-630,523L-630,521L-624,499L-621,486L-618,474L-611,449L-607,434L-596,389L-594,379L-593,370L-594,360L-596,351L-599,342L-604,334L-610,327L-618,321L-649,296L-678,270L-724,221L-765,168L-802,103L-829,33L-846,-40L-852,-115C-852,-191,-835,-266,-800,-336C-774,-389,-740,-438,-697,-481C-586,-595,-430,-668,-259,-687L-169,-691L-80,-686C91,-667,246,-593,356,-480C398,-436,433,-387,458,-334L488,-258L505,-178L509,-96L509,-91L525,-99L542,-105L559,-107L577,-107L595,-105L612,-99L628,-91L643,-81L656,-68L657,-153L646,-236L625,-318L593,-396ZM478,-13L465,2L455,19L449,38L445,58L445,77L448,97L455,116L465,133L477,149L492,162L509,172L528,179L548,183L603,198L655,222L703,253L745,293L748,296L753,298L757,300L762,300L767,300L771,300L776,298L780,296L784,292L787,289L789,285L791,280L792,275L792,271L791,266L789,261L787,257L784,254L780,250L743,210L713,164L690,114L675,61L673,49L671,38L664,19L654,2L641,-14L625,-26L608,-36L589,-43L569,-47L549,-47L530,-43L511,-36L494,-26L478,-13ZM348,405L347,412L346,419L340,437L332,454L321,469L307,482L292,493L275,501L256,507L238,509L219,508L200,504L183,497L167,487L152,475L140,461L130,444L123,427L120,408L119,390L121,371L126,353L134,336L145,320L158,307L173,295L190,287L208,281L227,278L281,263L333,239L380,206L421,167L425,164L429,162L434,161L439,160L443,161L448,162L452,164L456,166L460,170L463,173L465,178L466,182L467,187L467,192L466,196L464,201L461,205L458,208L419,250L387,298L363,350L348,405ZM803,312L818,300L835,290L853,283L872,280L891,279L910,282L929,288L946,296L961,308L975,322L985,338L993,356L998,374L1000,394L998,413L994,432L986,449L975,466L962,480L947,491L929,500L911,506L892,509L837,525L786,549L738,581L697,620L693,623L689,625L685,626L680,626L675,626L671,625L667,623L663,620L660,617L657,613L655,609L653,605L653,600L653,596L654,591L655,587L658,583L660,579L700,537L731,490L755,437L770,382L771,375L775,358L782,341L792,326L803,313ZM333,532L330,528L328,524L327,519L327,515L327,510L328,505L330,501L333,497L336,494L340,491L344,489L348,488L353,487L357,487L362,488L366,490L370,492L374,495L418,536L470,569L525,593L585,607L603,613L621,622L636,634L650,648L660,665L668,683L673,702L674,721L672,741L667,760L659,777L647,793L633,807L617,819L600,827L581,832L561,835L542,833L523,829L505,821L488,810L474,797L462,782L453,764L447,746L444,726L428,671L404,620L372,573L333,532Z",
  "M-1000,-834L1000,-832L1000,-665L-1000,-668L-1000,-834ZM339,-67L328,-57L319,-46L313,-34L308,-21L306,-7L306,7L308,21L313,34L319,46L328,57L339,67L867,462L879,470L892,475L905,478L920,479L934,477L947,473L960,467L971,458L981,448L989,437L995,424L999,410L1000,396L1000,-396L999,-410L995,-424L989,-437L981,-448L971,-458L960,-467L947,-473L934,-477L920,-479L905,-478L892,-475L879,-470L867,-462L339,-67ZM833,-229L833,229L528,0L833,-229ZM-1000,-84L83,-84L83,82L-1000,82L-1000,-84ZM-1000,665L1000,668L1000,834L-1000,832L-1000,665Z",
  "M198,9L280,31C425,71,584,35,694,-76L737,-126L772,-183L797,-244L812,-309L817,-375L812,-441L658,-287L629,-262L596,-243L560,-230L523,-223L485,-223L447,-230L411,-243L378,-262L349,-287L287,-349L263,-378L244,-411L231,-447L224,-484L224,-522L231,-560L244,-596L263,-629L287,-658L441,-812L375,-817L309,-812L245,-797L183,-771L127,-737L76,-694L35,-645L1,-591L-24,-532L-40,-470L-47,-406L-43,-342L-31,-279L-8,-197L-854,649L-648,855L198,9ZM561,-932C609,-916,656,-893,699,-864L390,-555L382,-545L376,-534L371,-522L369,-510L369,-497L371,-484L376,-472L382,-461L390,-452L452,-390L462,-382L473,-375L485,-371L497,-369L510,-369L522,-371L534,-375L545,-382L555,-390L864,-699C893,-655,916,-609,932,-561C1000,-360,955,-131,797,27L732,83L659,129L580,162L497,184L411,193L325,189L241,172L-545,958L-565,974L-587,987L-610,995L-635,1000L-661,1000L-686,995L-710,987L-732,974L-751,958L-957,752L-972,734L-984,715L-993,694L-998,671L-1000,648L-998,626L-993,603L-984,582L-972,563L-957,545L-171,-240L-188,-325L-193,-411L-184,-496L-162,-580L-128,-659L-83,-732L-27,-797C131,-955,360,-1000,561,-932Z",
  "M750,-1000L750,1000L-750,0L750,-1000Z",
  "M0,700L-115,690L-227,662L-333,616L-430,552L-515,474L-586,383L-641,281L-679,172L-698,58L-698,-58L-679,-172L-641,-281L-586,-383L-515,-474L-430,-552L-333,-616L-227,-662L-115,-690L0,-700L122,-689L239,-658L350,-606L450,-536L536,-450L606,-350L658,-239L689,-122L700,0L689,122L658,239L606,350L536,450L450,536L350,606L239,658L122,689L0,700ZM0,1000L174,985L342,940L500,866L643,766L766,643L866,500L940,342L985,174L1000,0L985,-174L940,-342L866,-500L766,-643L643,-766L500,-866L342,-940L174,-985L0,-1000L-174,-985L-342,-940L-500,-866L-643,-766L-766,-643L-866,-500L-940,-342L-985,-174L-1000,0L-985,174L-940,342L-866,500L-766,643L-643,766L-500,866L-342,940L-174,985L0,1000Z",
  "M1000,-750L-1000,-750L0,750L1000,-750Z",
  "M-231,378L841,-695L1000,-536L-231,695L-1000,-74L-841,-232L-231,378Z",
  "M-77,-1000L-77,-462L77,-462L77,-1000L-77,-1000ZM-272,-381L-816,-925L-925,-816L-381,-272L-272,-381ZM272,-381L816,-925L925,-816L381,-272L272,-381ZM154,0L152,27L145,53L133,77L118,99L99,118L77,133L53,145L27,152L0,154L-27,152L-53,145L-77,133L-99,118L-118,99L-133,77L-1000,77L-1000,-77L-133,-77L-118,-99L-99,-118L-77,-133L-53,-145L-27,-152L0,-154L27,-152L53,-145L77,-133L99,-118L118,-99L133,-77L145,-53L152,-27L154,0ZM-381,272L-925,816L-816,925L-272,381L-381,272ZM381,272L925,816L816,925L272,381L381,272ZM1000,-77L462,-77L462,77L1000,77L1000,-77ZM-77,1000L-77,462L77,462L77,1000L-77,1000Z",
  "M0,-1000L-91,-993L-179,-970L-262,-933L-338,-883L-405,-821L-460,-749L-503,-669L-532,-582L-545,-492L-544,-401L-528,-312L-497,-226L-452,-147L-395,-76L-326,-16L-249,32L-165,67L-76,87L-76,298L-388,298L-388,454L-76,454L-76,1000L80,1000L80,454L392,454L392,298L80,298L80,86L169,65L252,30L329,-18L397,-78L454,-149L498,-229L529,-314L545,-403L545,-494L531,-584L502,-670L460,-750L404,-822L338,-884L262,-934L179,-970L91,-993L0,-1000ZM0,-844L68,-838L134,-821L195,-792L251,-753L299,-705L338,-649L367,-588L384,-522L390,-454L384,-386L367,-321L338,-259L299,-204L251,-155L195,-116L134,-88L68,-70L0,-64L-67,-70L-133,-88L-195,-116L-250,-155L-298,-204L-337,-259L-366,-321L-384,-386L-390,-454L-384,-522L-366,-588L-337,-649L-298,-705L-250,-753L-195,-792L-133,-821L-67,-838L0,-844Z",
  "M-72,71L-72,1000L71,1000L71,71L737,71L495,313L596,414L960,50L967,42L973,32L977,22L980,11L981,0L980,-11L977,-22L973,-32L967,-42L960,-50L596,-414L495,-313L737,-71L71,-71L71,-1000L-72,-1000L-72,-71L-736,-71L-495,-313L-596,-414L-960,-50L-967,-42L-973,-32L-977,-22L-980,-11L-981,0L-980,11L-977,22L-973,32L-967,42L-960,50L-596,414L-495,313L-736,71L-72,71Z",
  "M-667,-833L833,-833L833,667L1000,667L1000,-833L997,-862L990,-890L978,-917L961,-940L940,-961L917,-978L890,-990L862,-997L833,-1000L-667,-1000L-667,-833ZM-833,1000L-862,997L-890,990L-917,978L-940,961L-961,940L-978,917L-990,890L-997,862L-1000,833L-1000,-500L-997,-529L-990,-557L-978,-583L-961,-607L-940,-628L-917,-644L-890,-657L-862,-664L-833,-667L500,-667L529,-664L557,-657L583,-644L607,-628L628,-607L644,-583L657,-557L664,-529L667,-500L667,833L664,862L657,890L644,917L628,940L607,961L583,978L557,990L529,997L500,1000L-833,1000ZM500,-500L-833,-500L-833,833L500,833L500,-500ZM-236,236L-236,722L-69,722L-69,236L389,236L389,69L-69,69L-69,-389L-236,-389L-236,69L-722,69L-722,236L-236,236Z",
  "M-667,-1000L-667,-667L-833,-667C-926,-667,-1000,-593,-1000,-500L-1000,333C-1000,426,-926,500,-833,500L-667,500L-667,1000L667,1000L667,500L833,500C926,500,1000,426,1000,333L1000,-500C1000,-593,926,-667,833,-667L667,-667L667,-1000L-667,-1000ZM500,-667L-500,-667L-500,-833L500,-833L500,-667ZM-833,-500L833,-500L833,333L667,333L667,0L-667,0L-667,333L-833,333L-833,-500ZM-500,833L-500,167L500,167L500,833L-500,833Z",
  "M667,0L669,29L677,57L689,83L706,107L726,128L750,144L776,157L804,164L833,167L862,164L890,157L917,144L940,128L961,107L978,83L990,57L997,29L1000,0L997,-29L990,-57L978,-83L961,-107L940,-128L917,-144L890,-157L862,-164L833,-167L804,-164L776,-157L750,-144L726,-128L706,-107L689,-83L677,-57L669,-29L667,0ZM-833,167L-862,164L-890,157L-917,144L-940,128L-961,107L-978,83L-990,57L-997,29L-1000,0L-997,-29L-990,-57L-978,-83L-961,-107L-940,-128L-917,-144L-890,-157L-862,-164L-833,-167L-804,-164L-776,-157L-750,-144L-726,-128L-706,-107L-689,-83L-677,-57L-669,-29L-667,0L-669,29L-677,57L-689,83L-706,107L-726,128L-750,144L-776,157L-804,164L-833,167ZM-167,0L-164,29L-157,57L-144,83L-128,107L-107,128L-83,144L-57,157L-29,164L0,167L29,164L57,157L83,144L107,128L128,107L144,83L157,57L164,29L167,0L164,-29L157,-57L144,-83L128,-107L107,-128L83,-144L57,-157L29,-164L0,-167L-29,-164L-57,-157L-83,-144L-107,-128L-128,-107L-144,-83L-157,-57L-164,-29L-167,0Z",
  "M0,1000L174,985L342,940L500,866L643,766L766,643L866,500L940,342L985,174L1000,0L985,-174L940,-342L866,-500L766,-643L643,-766L500,-866L342,-940L174,-985L0,-1000L-174,-985L-342,-940L-500,-866L-643,-766L-766,-643L-866,-500L-940,-342L-985,-174L-1000,0L-985,174L-940,342L-866,500L-766,643L-643,766L-500,866L-342,940L-174,985L0,1000ZM-71,-429L71,-429L71,-4L479,404L378,505L-71,56L-71,-429Z",
  "M-623,921L486,-1000L623,-921L-486,1000L-623,921Z",
  "M1000,0L985,-174L940,-342L866,-500L766,-643L643,-766L500,-866L342,-940L174,-985L0,-1000L-174,-985L-342,-940L-500,-866L-643,-766L-766,-643L-866,-500L-940,-342L-985,-174L-1000,0L-985,174L-940,342L-866,500L-766,643L-643,766L-500,866L-342,940L-174,985L0,1000L174,985L342,940L500,866L643,766L766,643L866,500L940,342L985,174L1000,0ZM-313,-196C-313,-368,-173,-509,0,-509C173,-509,313,-368,313,-196C313,-57,207,50,101,94L94,97L87,102L82,108L77,115L74,123L72,130L71,139L71,252L-71,252L-71,139C-71,59,-23,-10,47,-39L47,-39C118,-67,170,-133,170,-196C170,-289,94,-366,0,-366C-94,-366,-170,-289,-170,-196L-313,-196ZM-75,453L-74,441L-71,429L-66,417L-59,407L-51,398L-41,390L-30,384L-18,380L-6,378L6,378L18,380L30,384L41,390L51,398L59,407L66,417L71,429L74,441L75,453L74,466L71,479L65,491L58,502L48,511L38,518L26,524L13,527L0,529L-13,527L-26,524L-38,518L-48,511L-58,502L-65,491L-71,479L-74,466L-75,453Z",
  "M-833,-667L-804,-669L-776,-677L-750,-689L-726,-706L-706,-726L-689,-750L-677,-776L-669,-804L-667,-833L-669,-862L-677,-890L-689,-917L-706,-940L-726,-961L-750,-978L-776,-990L-804,-997L-833,-1000L-862,-997L-890,-990L-917,-978L-940,-961L-961,-940L-978,-917L-990,-890L-997,-862L-1000,-833L-997,-804L-990,-776L-978,-750L-961,-726L-940,-706L-917,-689L-890,-677L-862,-669L-833,-667ZM0,-667L29,-669L57,-677L83,-689L107,-706L128,-726L144,-750L157,-776L164,-804L167,-833L164,-862L157,-890L144,-917L128,-940L107,-961L83,-978L57,-990L29,-997L0,-1000L-29,-997L-57,-990L-83,-978L-107,-961L-128,-940L-144,-917L-157,-890L-164,-862L-167,-833L-164,-804L-157,-776L-144,-750L-128,-726L-107,-706L-83,-689L-57,-677L-29,-669L0,-667ZM833,-667L862,-669L890,-677L917,-689L940,-706L961,-726L978,-750L990,-776L997,-804L1000,-833L997,-862L990,-890L978,-917L961,-940L940,-961L917,-978L890,-990L862,-997L833,-1000L804,-997L776,-990L750,-978L726,-961L706,-940L689,-917L677,-890L669,-862L667,-833L669,-804L677,-776L689,-750L706,-726L726,-706L750,-689L776,-677L804,-669L833,-667ZM-833,167L-804,164L-776,157L-750,144L-726,128L-706,107L-689,83L-677,57L-669,29L-667,0L-669,-29L-677,-57L-689,-83L-706,-107L-726,-128L-750,-144L-776,-157L-804,-164L-833,-167L-862,-164L-890,-157L-917,-144L-940,-128L-961,-107L-978,-83L-990,-57L-997,-29L-1000,0L-997,29L-990,57L-978,83L-961,107L-940,128L-917,144L-890,157L-862,164L-833,167ZM0,167L29,164L57,157L83,144L107,128L128,107L144,83L157,57L164,29L167,0L164,-29L157,-57L144,-83L128,-107L107,-128L83,-144L57,-157L29,-164L0,-167L-29,-164L-57,-157L-83,-144L-107,-128L-128,-107L-144,-83L-157,-57L-164,-29L-167,0L-164,29L-157,57L-144,83L-128,107L-107,128L-83,144L-57,157L-29,164L0,167ZM833,167L862,164L890,157L917,144L940,128L961,107L978,83L990,57L997,29L1000,0L997,-29L990,-57L978,-83L961,-107L940,-128L917,-144L890,-157L862,-164L833,-167L804,-164L776,-157L750,-144L726,-128L706,-107L689,-83L677,-57L669,-29L667,0L669,29L677,57L689,83L706,107L726,128L750,144L776,157L804,164L833,167ZM-667,833L-669,862L-677,890L-689,917L-706,940L-726,961L-750,978L-776,990L-804,997L-833,1000L-862,997L-890,990L-917,978L-940,961L-961,940L-978,917L-990,890L-997,862L-1000,833L-997,804L-990,776L-978,750L-961,726L-940,706L-917,689L-890,677L-862,669L-833,667L-804,669L-776,677L-750,689L-726,706L-706,726L-689,750L-677,776L-669,804L-667,833ZM167,833L164,862L157,890L144,917L128,940L107,961L83,978L57,990L29,997L0,1000L-29,997L-57,990L-83,978L-107,961L-128,940L-144,917L-157,890L-164,862L-167,833L-164,804L-157,776L-144,750L-128,726L-107,706L-83,689L-57,677L-29,669L0,667L29,669L57,677L83,689L107,706L128,726L144,750L157,776L164,804L167,833ZM833,1000L862,997L890,990L917,978L940,961L961,940L978,917L990,890L997,862L1000,833L997,804L990,776L978,750L961,726L940,706L917,689L890,677L862,669L833,667L804,669L776,677L750,689L726,706L706,726L689,750L677,776L669,804L667,833L669,862L677,890L689,917L706,940L726,961L750,978L776,990L804,997L833,1000Z",
  "M637,-973L625,-983L612,-990L598,-996L583,-999L567,-1000L552,-998L537,-994L523,-987L510,-978L-123,-444L-243,-564L-255,-574L-267,-582L-281,-587L-295,-591L-310,-592L-325,-591L-339,-587L-353,-582L-365,-574L-376,-564L-706,-235L-715,-224L-723,-211L-729,-198L-732,-183L-733,-169L-732,-154L-729,-140L-723,-126L-715,-113L-706,-102L-357,246L-1000,889L-889,1000L-246,357L102,706L113,715L126,723L140,729L154,732L169,733L183,732L198,729L211,723L224,715L235,706L564,376L574,365L582,353L587,339L591,325L592,310L591,295L587,281L582,267L574,255L564,243L444,123L978,-510L987,-523L994,-537L998,-552L1000,-567L999,-582L996,-598L991,-612L983,-625L973,-637L637,-973ZM567,-821L821,-567L231,132L409,310L169,551L-551,-169L-310,-410L-132,-231L567,-821Z",
  "M719,396L737,407L754,421L768,437L779,455L787,474L792,495L793,516L793,830L792,842L789,854L784,865L777,874L768,883L759,890L748,895L736,898L724,899L-931,899L-942,898L-952,896L-962,892L-972,886L-980,879L-987,871L-992,861L-997,851L-999,841L-1000,830L-1000,516L-999,495L-994,474L-986,455L-974,437L-961,421L-944,407L-926,396L-662,293L-386,230L-103,209C191,209,469,277,719,396ZM-103,347C-375,347,-631,409,-862,518L-862,761L655,761L655,518L412,424L157,366L-103,347ZM700,-801L762,-728L810,-644L843,-554L860,-459L860,-363L843,-269L810,-178L762,-95L700,-21L798,76L868,-6L925,-98L966,-198L992,-303L1000,-411L992,-519L966,-624L925,-724L868,-817L798,-899L700,-801ZM505,-216L536,-253L560,-295L577,-340L585,-387L585,-435L577,-483L560,-528L536,-570L505,-606L603,-704L649,-649L685,-586L710,-518L722,-447L722,-375L710,-304L685,-236L649,-174L603,-119L505,-216ZM379,-411L372,-327L350,-246L315,-170L266,-101L207,-41L138,7L62,42L-20,64L-103,71L-187,64L-269,42L-345,7L-414,-41L-473,-101L-522,-170L-557,-246L-579,-327L-586,-411L-579,-495L-557,-576L-522,-653L-473,-722L-414,-781L-345,-829L-269,-865L-187,-887L-103,-894L-20,-887L62,-865L138,-829L207,-781L266,-722L315,-653L350,-576L372,-495L379,-411ZM241,-411L236,-471L221,-529L195,-584L161,-633L118,-675L69,-710L14,-735L-44,-751L-103,-756L-163,-751L-221,-735L-276,-710L-325,-675L-368,-633L-402,-584L-427,-529L-443,-471L-448,-411L-443,-351L-427,-293L-402,-239L-368,-190L-325,-147L-276,-113L-221,-87L-163,-72L-103,-66L-44,-72L14,-87L69,-113L118,-147L161,-190L195,-239L221,-293L236,-351L241,-411Z",
  "M167,833L164,862L157,890L144,917L128,940L107,961L83,978L57,990L29,997L0,1000L-29,997L-57,990L-83,978L-107,961L-128,940L-144,917L-157,890L-164,862L-167,833L-164,804L-157,776L-144,750L-128,726L-107,706L-83,689L-57,677L-29,669L0,667L29,669L57,677L83,689L107,706L128,726L144,750L157,776L164,804L167,833ZM0,-667L29,-669L57,-677L83,-689L107,-706L128,-726L144,-750L157,-776L164,-804L167,-833L164,-862L157,-890L144,-917L128,-940L107,-961L83,-978L57,-990L29,-997L0,-1000L-29,-997L-57,-990L-83,-978L-107,-961L-128,-940L-144,-917L-157,-890L-164,-862L-167,-833L-164,-804L-157,-776L-144,-750L-128,-726L-107,-706L-83,-689L-57,-677L-29,-669L0,-667ZM0,167L29,164L57,157L83,144L107,128L128,107L144,83L157,57L164,29L167,0L164,-29L157,-57L144,-83L128,-107L107,-128L83,-144L57,-157L29,-164L0,-167L-29,-164L-57,-157L-83,-144L-107,-128L-128,-107L-144,-83L-157,-57L-164,-29L-167,0L-164,29L-157,57L-144,83L-128,107L-107,128L-83,144L-57,157L-29,164L0,167Z",
]

///|
/// 图标变体 → 路径数据下标(与 all_icons 清单同序,wbtest 断言双射)。
fn kind_index(kind : IconKind) -> Int {
  match kind {
    TreeStructure => 0
    Hide => 1
    ClickButton => 2
    StaticText => 3
    Switch => 4
    TextField => 5
    Textarea => 6
    NumberField => 7
    SelectField => 8
    TreeTable => 9
    EditTable => 10
    TableIcon => 11
    TabIcon => 12
    Script => 13
    Shangduiqi => 14
    Youduiqi => 15
    Zuoduiqi => 16
    Weibiaoti545 => 17
    Dingceng => 18
    Diceng => 19
    Shangyiyiceng => 20
    Xiaduiqi => 21
    Xiayiyiceng => 22
    Daxiaoxiangdeng => 23
    Tuceng => 24
    ChatBar => 25
    Function => 26
    Duiqi => 27
    Params => 28
    Tucengzhizuoyuweihu => 29
    Kuaibuju => 30
    Shuxiangfenbu => 31
    Hengxiangfenbu1 => 32
    Chicunbiaozhu_ => 33
    Zuoyoujuzhong => 34
    Shangxiajuzhong => 35
    Dengkuan => 36
    Denggao => 37
    QueryFilter => 38
    ZhushujushenqingShujufenxi02 => 39
    Suofangdaodengbi => 40
    Huifu => 41
    Menu1 => 42
    Microphone => 43
    Minus1 => 44
    Message1 => 45
    MapLocation => 46
    MessageSolid => 47
    Mic => 48
    MilkTea => 49
    Medal => 50
    Medal2 => 51
    Mobile1 => 52
    MobilePhone => 53
    Money => 54
    More1 => 55
    NoSmoking => 56
    MoreOutline => 57
    Notebook => 58
    SHome => 59
    News => 60
    Notebook1 => 61
    SOpen => 62
    SMarketing => 63
    Mouse => 64
    SManagement => 65
    SOperation => 66
    OfficeBuilding => 67
    SwitchOpen => 68
    Ship => 69
    Sell => 70
    Search2 => 71
    Service => 72
    Scissors => 73
    Orange => 74
    PhoneOutline => 75
    Picture => 76
    Receiving => 77
    PictureOutlineRound => 78
    PictureOutline => 79
    PieChart => 80
    SData => 81
    Refrigerator => 82
    SCooperation => 83
    SCheck => 84
    SFlag => 85
    SCustom => 86
    SFinance => 87
    RemoveOutline => 88
    SComment => 89
    Remove => 90
    School => 91
    SShop => 92
    STicket => 93
    SortUp => 94
    Sort => 95
    TakeawayBox => 96
    Stopwatch => 97
    Thumb => 98
    Tickets => 99
    Truck => 100
    User1 => 101
    UserSolid => 102
    VideoCameraSolid => 103
    VideoPlay => 104
    VideoCamera => 105
    Right1 => 106
    VideoPause => 107
    StarOff => 108
    Trophy1 => 109
    Wallet1 => 110
    Watch => 111
    WindPower => 112
    ViewIcon => 113
    Watermelon => 114
    Share2 => 115
    SetUp => 116
    ZoomIn => 117
    WaterCup => 118
    Warning => 119
    Watch2 => 120
    Setting1 => 121
    ZoomOut => 122
    Pear => 123
    Paperclip => 124
    PlatformEleme => 125
    SClaim => 126
    SGoods => 127
    SGrid => 128
    SHelp => 129
    ShoppingCart => 130
    Smoking => 131
    Soccer => 132
    SPromotion => 133
    SortDown => 134
    SRelease => 135
    SOpportunity => 136
    SOrder => 137
    STools => 138
    SoldOut => 139
    SPlatform => 140
    Suitcase => 141
    Suitcase2 => 142
    Sugar => 143
    Sunset => 144
    Sunrise => 145
    TopLeft => 146
    SwitchButton => 147
    ToiletPaper => 148
    TableLamp => 149
    Tableware => 150
    TopRight => 151
    Top => 152
    TurnOff => 153
    Monitor1 => 154
    Unlock1 => 155
    Postcard => 156
    Umbrella => 157
    Moon => 158
    AddLocation => 159
    Present => 160
    Aim => 161
    Position => 162
    Back => 163
    PriceTag => 164
    ArrowLeft => 165
    PotatoStrips => 166
    Attract => 167
    ArrowRight => 168
    Sunny => 169
    ArrowUp => 170
    MoonNight => 171
    AlarmClock => 172
    Reading => 173
    ArrowDown => 174
    Rank => 175
    Apple1 => 176
    BottomRight => 177
    Upload2 => 178
    Box => 179
    Timer => 180
    Brush => 181
    Guide => 182
    BankCard => 183
    Trophy12 => 184
    BottomLeft => 185
    Bicycle => 186
    Baseball => 187
    Basketball => 188
    Burger => 189
    Bottom => 190
    CScaleToOriginal => 191
    ChatDotRound => 192
    ChatRound => 193
    ChatDotSquare => 194
    ChatSquare => 195
    CircleClose => 196
    Chicken => 197
    CloseNotification => 198
    Close2 => 199
    Cherry => 200
    CoffeeCup => 201
    Cloudy => 202
    CollectionTag => 203
    ColdDrink => 204
    Collection => 205
    Coordinate => 206
    Connection => 207
    Crop => 208
    Cpu => 209
    CopyDocument => 210
    DCaret => 211
    DArrowRight => 212
    DataBoard => 213
    DataAnalysis => 214
    DataLine => 215
    DArrowLeft => 216
    DeleteSolid => 217
    DeleteLocation => 218
    Discount => 219
    Date => 220
    Dessert => 221
    Dish => 222
    Delete2 => 223
    DocumentCopy => 224
    Document => 225
    Discover => 226
    DocumentAdd => 227
    DocumentChecked => 228
    DocumentDelete => 229
    DocumentRemove => 230
    Dish2 => 231
    Download1 => 232
    Coin => 233
    Female => 234
    Film => 235
    Error1 => 236
    Eleme => 237
    Coffee => 238
    FolderRemove => 239
    FolderChecked => 240
    FolderAdd1 => 241
    FolderDelete => 242
    Football => 243
    Finished => 244
    ForkSpoon => 245
    FirstAidKit => 246
    GobletFull => 247
    Food => 248
    Fullscreen => 249
    GobletSquareFull => 250
    Goblet => 251
    Goods => 252
    Headset => 253
    House => 254
    IceCreamRound => 255
    HotWater => 256
    HeavyRain => 257
    IceDrink => 258
    IceCream => 259
    Key1 => 260
    IceCreamSquare => 261
    KnifeFork => 262
    IceTea => 263
    Info => 264
    Grape => 265
    LightRain => 266
    Lock1 => 267
    LocationOutline => 268
    Lightning => 269
    MagicStick => 270
    Link1 => 271
    Lollipop => 272
    LoadingStep => 273
    Rest => 274
    BellFill => 275
    Usb => 276
    FilterFill => 277
    Skin => 278
    FireFill => 279
    Home => 280
    FunnelplotFill => 281
    Bank => 282
    GiftFill => 283
    Filter1 => 284
    HourglassFill => 285
    Funnelplot => 286
    HomeFill => 287
    Like => 288
    TrophyFill => 289
    Unlike => 290
    LocationFill => 291
    Unlock => 292
    CloudFill => 293
    Lock => 294
    CustomerserviceFill => 295
    Customerservice => 296
    ExperimentFill => 297
    Flag => 298
    EyeFill => 299
    Moneycollect => 300
    LikeFill => 301
    Medicinebox => 302
    LockFill => 303
    Shop => 304
    UnlikeFill => 305
    Shopping => 306
    StarFill => 307
    Folder => 308
    UnlockFill => 309
    FolderOpen => 310
    AlertFill => 311
    ApiFill => 312
    Deploymentunit => 313
    HighlightFill => 314
    Accountbook => 315
    PhoneFill => 316
    Contacts => 317
    EditFill => 318
    Carryout => 319
    PushpinFill => 320
    CalendarCheck => 321
    ThunderboltFill => 322
    Calendar1 => 323
    TagFill => 324
    Scan => 325
    WrenchFill => 326
    Select => 327
    TagsFill => 328
    Boxplot => 329
    BankFill => 330
    Build => 331
    CameraFill => 332
    Sliders => 333
    ErrorFill => 334
    Laptop => 335
    CrownFill => 336
    Barcode1 => 337
    MailFill => 338
    Camera => 339
    CarFill => 340
    Cluster => 341
    PrinterFill => 342
    Gateway => 343
    ShopFill => 344
    Car => 345
    SettingFill => 346
    Printer => 347
    USBFill => 348
    Read => 349
    GoldenFill => 350
    CloudServer => 351
    BuildFill => 352
    CloudUpload => 353
    BoxplotFill => 354
    Cloud => 355
    SlidersFill => 356
    CloudDownload => 357
    Alibaba => 358
    CloudSync => 359
    Alibabacloud => 360
    Video => 361
    Antdesign => 362
    NotificationIcon => 363
    AntCloud => 364
    Sound => 365
    Behance => 366
    RadarChart => 367
    Googleplus => 368
    Qrcode => 369
    Medium => 370
    Fund => 371
    Google => 372
    Image1 => 373
    IE => 374
    Mail1 => 375
    Amazon => 376
    Slack => 377
    Idcard => 378
    Alipay => 379
    Creditcard => 380
    Taobao => 381
    Heart => 382
    Zhihu => 383
    Block => 384
    HTML => 385
    Error => 386
    Linkedin => 387
    Star => 388
    Yahoo => 389
    Gold => 390
    Facebook => 391
    Heatmap => 392
    Skype => 393
    Wifi => 394
    CodeSandbox => 395
    Paperclip2 => 396
    Chrome => 397
    Edit1 => 398
    Aliwangwang => 399
    Key => 400
    Apple => 401
    Api => 402
    Android => 403
    Disconnect => 404
    Sketch => 405
    Highlight => 406
    Gitlab => 407
    Monitor => 408
    Dribbble => 409
    Link => 410
    Instagram => 411
    Man => 412
    Reddit => 413
    Percentage => 414
    Windows => 415
    Pushpin => 416
    Yuque => 417
    Phone => 418
    Youtube => 419
    Shake => 420
    GitlabFill => 421
    Tag => 422
    Dropbox => 423
    Wrench => 424
    Dingtalk => 425
    Woman => 426
    AndroidFill => 427
    Tags => 428
    AppleFill => 429
    Scissor => 430
    HTMLFill => 431
    Mr => 432
    WindowsFill => 433
    Share1 => 434
    QQ => 435
    Branches => 436
    Twitter => 437
    Fork => 438
    SkypeFill => 439
    Shrink => 440
    Weibo => 441
    Arrawsalt => 442
    YuqueFill => 443
    Verticalright => 444
    YoutubeFill => 445
    Verticalleft => 446
    YahooFill => 447
    Wechat => 448
    ChromeFill => 449
    AliwangwangFill => 450
    FullscreenExit => 451
    GithubFill => 452
    MediumCircleFill => 453
    ColumnHeight => 454
    VAlignBottom => 455
    VAlignMiddle => 456
    ToTop => 457
    VAlignTop => 458
    Download => 459
    SortDesc => 460
    SortAsc => 461
    Fall => 462
    Swap => 463
    Stock => 464
    Rise => 465
    Indent => 466
    Outdent => 467
    MenuIcon => 468
    Unorderedlist => 469
    Orderedlist => 470
    AlignRight => 471
    AlignCenter => 472
    AlignLeft => 473
    PicCenter => 474
    PicRight => 475
    PicLeft => 476
    Bold => 477
    FontColor => 478
    CheckCircle => 479
    Exclaimination => 480
    CI => 481
    FontSize => 482
    Dollar => 483
    Infomation => 484
    Compass => 485
    LineHeight => 486
    Strikethrough => 487
    Frown => 488
    Underline => 489
    InfoCircle => 490
    Number => 491
    LeftCircle => 492
    Italic => 493
    Loading => 494
    DownCircle => 495
    Code => 496
    EURO => 497
    ColumnWidth => 498
    Copyright => 499
    MinusCircle => 500
    Meh => 501
    Dash => 502
    PlusCircle => 503
    PlayCircle => 504
    Enter1 => 505
    QuestionCircle => 506
    Line => 507
    Pound => 508
    Minus => 509
    RightCircle => 510
    Question => 511
    Smile => 512
    Plus => 513
    Trademark => 514
    SmallDash => 515
    Pause => 516
    Earth => 517
    BgColors => 518
    YUAN => 519
    Crown => 520
    UpCircle => 521
    Drag => 522
    WarningCircle => 523
    Sync => 524
    Gift => 525
    Transaction => 526
    Stop => 527
    Undo => 528
    Fire => 529
    Redo => 530
    Thunderbolt => 531
    Reload => 532
    CheckCircleFill => 533
    Reloadtime => 534
    LeftCircleFill => 535
    Message => 536
    DownCircleFill => 537
    Dashboard => 538
    MinusCircleFill => 539
    Issuesclose => 540
    CloseCircleFill => 541
    Poweroff => 542
    InfoCircleFill => 543
    Logout => 544
    UpCircleFill => 545
    Login => 546
    RightCircleFill => 547
    Piechart => 548
    PlusCircleFill => 549
    QuestionCircleFill => 550
    Eye => 551
    EUROCircleFill => 552
    FrownFill => 553
    CopyrightCircleFil => 554
    Export => 555
    CICircleFill => 556
    Save1 => 557
    CompassFill => 558
    Import => 559
    DollarCircleFill => 560
    Appstore => 561
    PoweroffCircleFill => 562
    MehFill => 563
    PlayCircleFill => 564
    Layout => 565
    PoundCircleFill => 566
    SmileFill => 567
    StopFill => 568
    Control => 569
    WarningCircleFill => 570
    Codelibrary => 571
    Detail => 572
    TrademarkCircleFil => 573
    YUANCircleFill => 574
    HeartFill => 575
    PiechartCircleFil => 576
    Project => 577
    DashboardFill => 578
    Wallet => 579
    MessageFill => 580
    Calculator => 581
    Interation => 582
    Border => 583
    CodelibraryFill => 584
    BorderOuter => 585
    BorderTop => 586
    BorderBottom => 587
    BorderLeft => 588
    BorderRight => 589
    BorderInner => 590
    AccountbookFill => 591
    BorderVertical => 592
    CarryoutFill => 593
    BorderHorizontal => 594
    CalendarFill => 595
    RadiusBottomleft => 596
    CalculatorFill => 597
    RadiusBottomright => 598
    InterationFill => 599
    RadiusUpleft => 600
    ProjectFill => 601
    RadiusUpright => 602
    DetailFill => 603
    RadiusSetting => 604
    SaveFill => 605
    Adduser => 606
    WalletFill => 607
    Deleteteam => 608
    ControlFill => 609
    Deleteuser => 610
    LayoutFill => 611
    Addteam => 612
    AppstoreFill => 613
    User => 614
    MobileFill => 615
    Team => 616
    TabletFill => 617
    AreaChart => 618
    BookFill => 619
    LineChart => 620
    RedenvelopeFill => 621
    Barchart => 622
    SafetycertificateF => 623
    Pointmap => 624
    PropertysafetyFill => 625
    ContainerIcon => 626
    Database => 627
    SecurityscanFill => 628
    Sever => 629
    FileExclamationFil => 630
    Mobile => 631
    FileAddFill => 632
    Tablet => 633
    FileExcelFill => 634
    Redenvelope => 635
    FileMarkdownFill => 636
    Book => 637
    FileTextFill => 638
    Filedone => 639
    FilePptFill => 640
    Reconciliation => 641
    FileUnknownFill => 642
    FileException => 643
    FileWordFill => 644
    Filesync => 645
    FileZipFill => 646
    FileSearch => 647
    FilePdfFill => 648
    Solution => 649
    FileImageFill => 650
    Fileprotect => 651
    DiffFill => 652
    FileAdd => 653
    FileCopyFill => 654
    FileExcel => 655
    SnippetsFill => 656
    FileExclamation => 657
    BatchfoldingFill => 658
    FilePdf => 659
    ReconciliationFill => 660
    FileImage => 661
    FileMarkdown => 662
    FolderFill => 663
    FileUnknown => 664
    FolderOpenFill => 665
    FilePpt => 666
    DatabaseFill => 667
    FileWord => 668
    ContainerFill => 669
    File1 => 670
    SeverFill => 671
    FileZip => 672
    CalendarCheckFill => 673
    FileText => 674
    ImageFill => 675
    FileCopy => 676
    IdcardFill => 677
    Snippets => 678
    CreditcardFill => 679
    Audit => 680
    FundFill => 681
    Diff => 682
    ReadFill => 683
    Batchfolding => 684
    ContactsFill => 685
    Securityscan => 686
    Propertysafety => 687
    NotificationFill => 688
    Safetycertificate => 689
    FlagFill => 690
    MoneycollectFill => 691
    Alert => 692
    MedicineboxFill => 693
    RestFill => 694
    Hourglass => 695
    ShoppingFill => 696
    Bulb => 697
    SkinFill => 698
    Experiment => 699
    VideoFill => 700
    Bell => 701
    SoundFill => 702
    Trophy => 703
    BulbFill => 704
    FuwuActive => 705
    ShouyeShouye => 706
    Cangkuxinxi => 707
    Saomiao => 708
    Iconset0254 => 709
    Zhongsuanrenwuliebiao => 710
    Xiangxiazhanhang => 711
    Qita => 712
    Xiajia => 713
    Feiji => 714
    Tixing => 715
    Shaixuan_o => 716
    Siji => 717
    Lianxiwomen => 718
    Guanyuwomen => 719
    Wode => 720
    TruckFull => 721
    Xiayibu => 722
    Video2 => 723
    ImageIcon => 724
    File => 725
    Xinhao => 726
    Gengduo => 727
    Xuhao => 728
    Zhiye => 729
    Weixian => 730
    Apptubiao => 731
    Jingdiananli_wujiaoxing_shoucanghou => 732
    Jingdiananli_kongwujiaoxing_shoucang => 733
    Caigou => 734
    NaviconQtrkd => 735
    CustomWorker => 736
    Ruku => 737
    Yichang => 738
    Shougongpeidui => 739
    Lunkuohua113 => 740
    Jiebang => 741
    Goodsppeinventory => 742
    Weixiujilu => 743
    Taizhangguanli => 744
    Weixiu => 745
    Baoxiu => 746
    Daijiedan => 747
    Shebeidianjian => 748
    Shebeidianjiantongji => 749
    Baoyanggongdan => 750
    Baoyangjihua => 751
    Chart => 752
    ChartBar => 753
    Filter => 754
    FilterClear => 755
    Share => 756
    Books => 757
    Cart => 758
    Clear => 759
    MenuFold => 760
    LockOff => 761
    Rotation => 762
    Layers => 763
    LockOn => 764
    RootList => 765
    AControlplatform => 766
    ChartBubble => 767
    CaretUpSmall => 768
    Enter => 769
    Rollfront => 770
    Jump => 771
    Rollback => 772
    CaretRightSmall => 773
    Mirror => 774
    Time => 775
    UserAvatar => 776
    UsergroupClear => 777
    MinusRectangle => 778
    FormatHorizontalAlignTop => 779
    Move1 => 780
    Bulletpoint => 781
    Barcode => 782
    LogoWecom => 783
    MenuUnfold => 784
    Tools => 785
    CaretLeftSmall => 786
    Round => 787
    CaretDownSmall => 788
    Check => 789
    APrecisemonitor => 790
    GenderFemale => 791
    AOrderAdjustmentcolumn => 792
    Queue => 793
    Print => 794
    Ellipsis => 795
    TimeFilled => 796
    Slash => 797
    HelpCircleFilled => 798
    MenuApplication => 799
    Pin => 800
    UserTalk => 801
    More => 802
  }
}
// ---- icons-gen:end ----

///|
/// 全部图标种类清单(803 项,图标墙/选取器素材)。
pub fn all_icons() -> Array[IconKind] {
  [
    // ---- icons-gen:all
    TreeStructure,
    Hide,
    ClickButton,
    StaticText,
    Switch,
    TextField,
    Textarea,
    NumberField,
    SelectField,
    TreeTable,
    EditTable,
    TableIcon,
    TabIcon,
    Script,
    Shangduiqi,
    Youduiqi,
    Zuoduiqi,
    Weibiaoti545,
    Dingceng,
    Diceng,
    Shangyiyiceng,
    Xiaduiqi,
    Xiayiyiceng,
    Daxiaoxiangdeng,
    Tuceng,
    ChatBar,
    Function,
    Duiqi,
    Params,
    Tucengzhizuoyuweihu,
    Kuaibuju,
    Shuxiangfenbu,
    Hengxiangfenbu1,
    Chicunbiaozhu_,
    Zuoyoujuzhong,
    Shangxiajuzhong,
    Dengkuan,
    Denggao,
    QueryFilter,
    ZhushujushenqingShujufenxi02,
    Suofangdaodengbi,
    Huifu,
    Menu1,
    Microphone,
    Minus1,
    Message1,
    MapLocation,
    MessageSolid,
    Mic,
    MilkTea,
    Medal,
    Medal2,
    Mobile1,
    MobilePhone,
    Money,
    More1,
    NoSmoking,
    MoreOutline,
    Notebook,
    SHome,
    News,
    Notebook1,
    SOpen,
    SMarketing,
    Mouse,
    SManagement,
    SOperation,
    OfficeBuilding,
    SwitchOpen,
    Ship,
    Sell,
    Search2,
    Service,
    Scissors,
    Orange,
    PhoneOutline,
    Picture,
    Receiving,
    PictureOutlineRound,
    PictureOutline,
    PieChart,
    SData,
    Refrigerator,
    SCooperation,
    SCheck,
    SFlag,
    SCustom,
    SFinance,
    RemoveOutline,
    SComment,
    Remove,
    School,
    SShop,
    STicket,
    SortUp,
    Sort,
    TakeawayBox,
    Stopwatch,
    Thumb,
    Tickets,
    Truck,
    User1,
    UserSolid,
    VideoCameraSolid,
    VideoPlay,
    VideoCamera,
    Right1,
    VideoPause,
    StarOff,
    Trophy1,
    Wallet1,
    Watch,
    WindPower,
    ViewIcon,
    Watermelon,
    Share2,
    SetUp,
    ZoomIn,
    WaterCup,
    Warning,
    Watch2,
    Setting1,
    ZoomOut,
    Pear,
    Paperclip,
    PlatformEleme,
    SClaim,
    SGoods,
    SGrid,
    SHelp,
    ShoppingCart,
    Smoking,
    Soccer,
    SPromotion,
    SortDown,
    SRelease,
    SOpportunity,
    SOrder,
    STools,
    SoldOut,
    SPlatform,
    Suitcase,
    Suitcase2,
    Sugar,
    Sunset,
    Sunrise,
    TopLeft,
    SwitchButton,
    ToiletPaper,
    TableLamp,
    Tableware,
    TopRight,
    Top,
    TurnOff,
    Monitor1,
    Unlock1,
    Postcard,
    Umbrella,
    Moon,
    AddLocation,
    Present,
    Aim,
    Position,
    Back,
    PriceTag,
    ArrowLeft,
    PotatoStrips,
    Attract,
    ArrowRight,
    Sunny,
    ArrowUp,
    MoonNight,
    AlarmClock,
    Reading,
    ArrowDown,
    Rank,
    Apple1,
    BottomRight,
    Upload2,
    Box,
    Timer,
    Brush,
    Guide,
    BankCard,
    Trophy12,
    BottomLeft,
    Bicycle,
    Baseball,
    Basketball,
    Burger,
    Bottom,
    CScaleToOriginal,
    ChatDotRound,
    ChatRound,
    ChatDotSquare,
    ChatSquare,
    CircleClose,
    Chicken,
    CloseNotification,
    Close2,
    Cherry,
    CoffeeCup,
    Cloudy,
    CollectionTag,
    ColdDrink,
    Collection,
    Coordinate,
    Connection,
    Crop,
    Cpu,
    CopyDocument,
    DCaret,
    DArrowRight,
    DataBoard,
    DataAnalysis,
    DataLine,
    DArrowLeft,
    DeleteSolid,
    DeleteLocation,
    Discount,
    Date,
    Dessert,
    Dish,
    Delete2,
    DocumentCopy,
    Document,
    Discover,
    DocumentAdd,
    DocumentChecked,
    DocumentDelete,
    DocumentRemove,
    Dish2,
    Download1,
    Coin,
    Female,
    Film,
    Error1,
    Eleme,
    Coffee,
    FolderRemove,
    FolderChecked,
    FolderAdd1,
    FolderDelete,
    Football,
    Finished,
    ForkSpoon,
    FirstAidKit,
    GobletFull,
    Food,
    Fullscreen,
    GobletSquareFull,
    Goblet,
    Goods,
    Headset,
    House,
    IceCreamRound,
    HotWater,
    HeavyRain,
    IceDrink,
    IceCream,
    Key1,
    IceCreamSquare,
    KnifeFork,
    IceTea,
    Info,
    Grape,
    LightRain,
    Lock1,
    LocationOutline,
    Lightning,
    MagicStick,
    Link1,
    Lollipop,
    LoadingStep,
    Rest,
    BellFill,
    Usb,
    FilterFill,
    Skin,
    FireFill,
    Home,
    FunnelplotFill,
    Bank,
    GiftFill,
    Filter1,
    HourglassFill,
    Funnelplot,
    HomeFill,
    Like,
    TrophyFill,
    Unlike,
    LocationFill,
    Unlock,
    CloudFill,
    Lock,
    CustomerserviceFill,
    Customerservice,
    ExperimentFill,
    Flag,
    EyeFill,
    Moneycollect,
    LikeFill,
    Medicinebox,
    LockFill,
    Shop,
    UnlikeFill,
    Shopping,
    StarFill,
    Folder,
    UnlockFill,
    FolderOpen,
    AlertFill,
    ApiFill,
    Deploymentunit,
    HighlightFill,
    Accountbook,
    PhoneFill,
    Contacts,
    EditFill,
    Carryout,
    PushpinFill,
    CalendarCheck,
    ThunderboltFill,
    Calendar1,
    TagFill,
    Scan,
    WrenchFill,
    Select,
    TagsFill,
    Boxplot,
    BankFill,
    Build,
    CameraFill,
    Sliders,
    ErrorFill,
    Laptop,
    CrownFill,
    Barcode1,
    MailFill,
    Camera,
    CarFill,
    Cluster,
    PrinterFill,
    Gateway,
    ShopFill,
    Car,
    SettingFill,
    Printer,
    USBFill,
    Read,
    GoldenFill,
    CloudServer,
    BuildFill,
    CloudUpload,
    BoxplotFill,
    Cloud,
    SlidersFill,
    CloudDownload,
    Alibaba,
    CloudSync,
    Alibabacloud,
    Video,
    Antdesign,
    NotificationIcon,
    AntCloud,
    Sound,
    Behance,
    RadarChart,
    Googleplus,
    Qrcode,
    Medium,
    Fund,
    Google,
    Image1,
    IE,
    Mail1,
    Amazon,
    Slack,
    Idcard,
    Alipay,
    Creditcard,
    Taobao,
    Heart,
    Zhihu,
    Block,
    HTML,
    Error,
    Linkedin,
    Star,
    Yahoo,
    Gold,
    Facebook,
    Heatmap,
    Skype,
    Wifi,
    CodeSandbox,
    Paperclip2,
    Chrome,
    Edit1,
    Aliwangwang,
    Key,
    Apple,
    Api,
    Android,
    Disconnect,
    Sketch,
    Highlight,
    Gitlab,
    Monitor,
    Dribbble,
    Link,
    Instagram,
    Man,
    Reddit,
    Percentage,
    Windows,
    Pushpin,
    Yuque,
    Phone,
    Youtube,
    Shake,
    GitlabFill,
    Tag,
    Dropbox,
    Wrench,
    Dingtalk,
    Woman,
    AndroidFill,
    Tags,
    AppleFill,
    Scissor,
    HTMLFill,
    Mr,
    WindowsFill,
    Share1,
    QQ,
    Branches,
    Twitter,
    Fork,
    SkypeFill,
    Shrink,
    Weibo,
    Arrawsalt,
    YuqueFill,
    Verticalright,
    YoutubeFill,
    Verticalleft,
    YahooFill,
    Wechat,
    ChromeFill,
    AliwangwangFill,
    FullscreenExit,
    GithubFill,
    MediumCircleFill,
    ColumnHeight,
    VAlignBottom,
    VAlignMiddle,
    ToTop,
    VAlignTop,
    Download,
    SortDesc,
    SortAsc,
    Fall,
    Swap,
    Stock,
    Rise,
    Indent,
    Outdent,
    MenuIcon,
    Unorderedlist,
    Orderedlist,
    AlignRight,
    AlignCenter,
    AlignLeft,
    PicCenter,
    PicRight,
    PicLeft,
    Bold,
    FontColor,
    CheckCircle,
    Exclaimination,
    CI,
    FontSize,
    Dollar,
    Infomation,
    Compass,
    LineHeight,
    Strikethrough,
    Frown,
    Underline,
    InfoCircle,
    Number,
    LeftCircle,
    Italic,
    Loading,
    DownCircle,
    Code,
    EURO,
    ColumnWidth,
    Copyright,
    MinusCircle,
    Meh,
    Dash,
    PlusCircle,
    PlayCircle,
    Enter1,
    QuestionCircle,
    Line,
    Pound,
    Minus,
    RightCircle,
    Question,
    Smile,
    Plus,
    Trademark,
    SmallDash,
    Pause,
    Earth,
    BgColors,
    YUAN,
    Crown,
    UpCircle,
    Drag,
    WarningCircle,
    Sync,
    Gift,
    Transaction,
    Stop,
    Undo,
    Fire,
    Redo,
    Thunderbolt,
    Reload,
    CheckCircleFill,
    Reloadtime,
    LeftCircleFill,
    Message,
    DownCircleFill,
    Dashboard,
    MinusCircleFill,
    Issuesclose,
    CloseCircleFill,
    Poweroff,
    InfoCircleFill,
    Logout,
    UpCircleFill,
    Login,
    RightCircleFill,
    Piechart,
    PlusCircleFill,
    QuestionCircleFill,
    Eye,
    EUROCircleFill,
    FrownFill,
    CopyrightCircleFil,
    Export,
    CICircleFill,
    Save1,
    CompassFill,
    Import,
    DollarCircleFill,
    Appstore,
    PoweroffCircleFill,
    MehFill,
    PlayCircleFill,
    Layout,
    PoundCircleFill,
    SmileFill,
    StopFill,
    Control,
    WarningCircleFill,
    Codelibrary,
    Detail,
    TrademarkCircleFil,
    YUANCircleFill,
    HeartFill,
    PiechartCircleFil,
    Project,
    DashboardFill,
    Wallet,
    MessageFill,
    Calculator,
    Interation,
    Border,
    CodelibraryFill,
    BorderOuter,
    BorderTop,
    BorderBottom,
    BorderLeft,
    BorderRight,
    BorderInner,
    AccountbookFill,
    BorderVertical,
    CarryoutFill,
    BorderHorizontal,
    CalendarFill,
    RadiusBottomleft,
    CalculatorFill,
    RadiusBottomright,
    InterationFill,
    RadiusUpleft,
    ProjectFill,
    RadiusUpright,
    DetailFill,
    RadiusSetting,
    SaveFill,
    Adduser,
    WalletFill,
    Deleteteam,
    ControlFill,
    Deleteuser,
    LayoutFill,
    Addteam,
    AppstoreFill,
    User,
    MobileFill,
    Team,
    TabletFill,
    AreaChart,
    BookFill,
    LineChart,
    RedenvelopeFill,
    Barchart,
    SafetycertificateF,
    Pointmap,
    PropertysafetyFill,
    ContainerIcon,
    Database,
    SecurityscanFill,
    Sever,
    FileExclamationFil,
    Mobile,
    FileAddFill,
    Tablet,
    FileExcelFill,
    Redenvelope,
    FileMarkdownFill,
    Book,
    FileTextFill,
    Filedone,
    FilePptFill,
    Reconciliation,
    FileUnknownFill,
    FileException,
    FileWordFill,
    Filesync,
    FileZipFill,
    FileSearch,
    FilePdfFill,
    Solution,
    FileImageFill,
    Fileprotect,
    DiffFill,
    FileAdd,
    FileCopyFill,
    FileExcel,
    SnippetsFill,
    FileExclamation,
    BatchfoldingFill,
    FilePdf,
    ReconciliationFill,
    FileImage,
    FileMarkdown,
    FolderFill,
    FileUnknown,
    FolderOpenFill,
    FilePpt,
    DatabaseFill,
    FileWord,
    ContainerFill,
    File1,
    SeverFill,
    FileZip,
    CalendarCheckFill,
    FileText,
    ImageFill,
    FileCopy,
    IdcardFill,
    Snippets,
    CreditcardFill,
    Audit,
    FundFill,
    Diff,
    ReadFill,
    Batchfolding,
    ContactsFill,
    Securityscan,
    Propertysafety,
    NotificationFill,
    Safetycertificate,
    FlagFill,
    MoneycollectFill,
    Alert,
    MedicineboxFill,
    RestFill,
    Hourglass,
    ShoppingFill,
    Bulb,
    SkinFill,
    Experiment,
    VideoFill,
    Bell,
    SoundFill,
    Trophy,
    BulbFill,
    FuwuActive,
    ShouyeShouye,
    Cangkuxinxi,
    Saomiao,
    Iconset0254,
    Zhongsuanrenwuliebiao,
    Xiangxiazhanhang,
    Qita,
    Xiajia,
    Feiji,
    Tixing,
    Shaixuan_o,
    Siji,
    Lianxiwomen,
    Guanyuwomen,
    Wode,
    TruckFull,
    Xiayibu,
    Video2,
    ImageIcon,
    File,
    Xinhao,
    Gengduo,
    Xuhao,
    Zhiye,
    Weixian,
    Apptubiao,
    Jingdiananli_wujiaoxing_shoucanghou,
    Jingdiananli_kongwujiaoxing_shoucang,
    Caigou,
    NaviconQtrkd,
    CustomWorker,
    Ruku,
    Yichang,
    Shougongpeidui,
    Lunkuohua113,
    Jiebang,
    Goodsppeinventory,
    Weixiujilu,
    Taizhangguanli,
    Weixiu,
    Baoxiu,
    Daijiedan,
    Shebeidianjian,
    Shebeidianjiantongji,
    Baoyanggongdan,
    Baoyangjihua,
    Chart,
    ChartBar,
    Filter,
    FilterClear,
    Share,
    Books,
    Cart,
    Clear,
    MenuFold,
    LockOff,
    Rotation,
    Layers,
    LockOn,
    RootList,
    AControlplatform,
    ChartBubble,
    CaretUpSmall,
    Enter,
    Rollfront,
    Jump,
    Rollback,
    CaretRightSmall,
    Mirror,
    Time,
    UserAvatar,
    UsergroupClear,
    MinusRectangle,
    FormatHorizontalAlignTop,
    Move1,
    Bulletpoint,
    Barcode,
    LogoWecom,
    MenuUnfold,
    Tools,
    CaretLeftSmall,
    Round,
    CaretDownSmall,
    Check,
    APrecisemonitor,
    GenderFemale,
    AOrderAdjustmentcolumn,
    Queue,
    Print,
    Ellipsis,
    TimeFilled,
    Slash,
    HelpCircleFilled,
    MenuApplication,
    Pin,
    UserTalk,
    More,
// ---- icons-gen:end ----
  ]
}


///|
/// 图标名称(图标墙/提示文案用)。
pub fn icon_name(kind : IconKind) -> String {
  match kind {

    // ---- icons-gen:names
    TreeStructure => "tree-structure"
    Hide => "hide"
    ClickButton => "click-button"
    StaticText => "static-text"
    Switch => "switch"
    TextField => "text-field"
    Textarea => "textarea-field"
    NumberField => "number-field"
    SelectField => "select-field"
    TreeTable => "tree-table"
    EditTable => "edit-table"
    TableIcon => "table"
    TabIcon => "tab"
    Script => "script"
    Shangduiqi => "shangduiqi"
    Youduiqi => "youduiqi"
    Zuoduiqi => "zuoduiqi"
    Weibiaoti545 => "weibiaoti545"
    Dingceng => "dingceng"
    Diceng => "diceng"
    Shangyiyiceng => "shangyiyiceng"
    Xiaduiqi => "xiaduiqi"
    Xiayiyiceng => "xiayiyiceng"
    Daxiaoxiangdeng => "daxiaoxiangdeng"
    Tuceng => "tuceng"
    ChatBar => "chat-bar"
    Function => "yunhang"
    Duiqi => "duiqi-"
    Params => "canshu"
    Tucengzhizuoyuweihu => "tucengzhizuoyuweihu"
    Kuaibuju => "kuaibuju"
    Shuxiangfenbu => "shuxiangfenbu"
    Hengxiangfenbu1 => "hengxiangfenbu1"
    Chicunbiaozhu_ => "chicunbiaozhu_"
    Zuoyoujuzhong => "zuoyoujuzhong"
    Shangxiajuzhong => "shangxiajuzhong"
    Dengkuan => "dengkuan"
    Denggao => "denggao"
    QueryFilter => "tiaojianchaxun"
    ZhushujushenqingShujufenxi02 => "zhushujushenqing-shujufenxi-02"
    Suofangdaodengbi => "suofangdaodengbi"
    Huifu => "huifu"
    Menu1 => "menu1"
    Microphone => "microphone"
    Minus1 => "minus1"
    Message1 => "message1"
    MapLocation => "map-location"
    MessageSolid => "message-solid"
    Mic => "mic"
    MilkTea => "milk-tea"
    Medal => "medal"
    Medal2 => "medal-"
    Mobile1 => "mobile1"
    MobilePhone => "mobile-phone"
    Money => "money"
    More1 => "more1"
    NoSmoking => "no-smoking"
    MoreOutline => "more-outline"
    Notebook => "notebook-"
    SHome => "s-home"
    News => "news"
    Notebook1 => "notebook-1"
    SOpen => "s-open"
    SMarketing => "s-marketing"
    Mouse => "mouse"
    SManagement => "s-management"
    SOperation => "s-operation"
    OfficeBuilding => "office-building"
    SwitchOpen => "switch-open"
    Ship => "ship"
    Sell => "sell"
    Search2 => "search2"
    Service => "service"
    Scissors => "scissors"
    Orange => "orange"
    PhoneOutline => "phone-outline"
    Picture => "picture"
    Receiving => "receiving"
    PictureOutlineRound => "picture-outline-round"
    PictureOutline => "picture-outline"
    PieChart => "pie-chart"
    SData => "s-data"
    Refrigerator => "refrigerator"
    SCooperation => "s-cooperation"
    SCheck => "s-check"
    SFlag => "s-flag"
    SCustom => "s-custom"
    SFinance => "s-finance"
    RemoveOutline => "remove-outline"
    SComment => "s-comment"
    Remove => "remove"
    School => "school"
    SShop => "s-shop"
    STicket => "s-ticket"
    SortUp => "sort-up"
    Sort => "sort"
    TakeawayBox => "takeaway-box"
    Stopwatch => "stopwatch"
    Thumb => "thumb"
    Tickets => "tickets"
    Truck => "truck"
    User1 => "user1"
    UserSolid => "user-solid"
    VideoCameraSolid => "video-camera-solid"
    VideoPlay => "video-play"
    VideoCamera => "video-camera"
    Right1 => "right1"
    VideoPause => "video-pause"
    StarOff => "star-off"
    Trophy1 => "trophy1"
    Wallet1 => "wallet1"
    Watch => "watch"
    WindPower => "wind-power"
    ViewIcon => "view"
    Watermelon => "watermelon"
    Share2 => "share2"
    SetUp => "set-up"
    ZoomIn => "zoom-in"
    WaterCup => "water-cup"
    Warning => "warning"
    Watch2 => "watch-"
    Setting1 => "setting1"
    ZoomOut => "zoom-out"
    Pear => "pear"
    Paperclip => "paperclip"
    PlatformEleme => "platform-eleme"
    SClaim => "s-claim"
    SGoods => "s-goods"
    SGrid => "s-grid"
    SHelp => "s-help"
    ShoppingCart => "shopping-cart-"
    Smoking => "smoking"
    Soccer => "soccer"
    SPromotion => "s-promotion"
    SortDown => "sort-down"
    SRelease => "s-release"
    SOpportunity => "s-opportunity"
    SOrder => "s-order"
    STools => "s-tools"
    SoldOut => "sold-out"
    SPlatform => "s-platform"
    Suitcase => "suitcase"
    Suitcase2 => "suitcase-"
    Sugar => "sugar"
    Sunset => "sunset"
    Sunrise => "sunrise-"
    TopLeft => "top-left"
    SwitchButton => "switch-button"
    ToiletPaper => "toilet-paper"
    TableLamp => "table-lamp"
    Tableware => "tableware"
    TopRight => "top-right"
    Top => "top"
    TurnOff => "turn-off"
    Monitor1 => "monitor1"
    Unlock1 => "unlock1"
    Postcard => "postcard"
    Umbrella => "umbrella"
    Moon => "moon"
    AddLocation => "add-location"
    Present => "present"
    Aim => "aim"
    Position => "position"
    Back => "back"
    PriceTag => "price-tag"
    ArrowLeft => "arrow-left"
    PotatoStrips => "potato-strips"
    Attract => "attract"
    ArrowRight => "arrow-right"
    Sunny => "sunny"
    ArrowUp => "arrow-up"
    MoonNight => "moon-night"
    AlarmClock => "alarm-clock"
    Reading => "reading"
    ArrowDown => "arrow-down"
    Rank => "rank"
    Apple1 => "apple1"
    BottomRight => "bottom-right"
    Upload2 => "upload2"
    Box => "box"
    Timer => "timer"
    Brush => "brush"
    Guide => "guide"
    BankCard => "bank-card"
    Trophy12 => "trophy-1"
    BottomLeft => "bottom-left"
    Bicycle => "bicycle"
    Baseball => "baseball"
    Basketball => "basketball"
    Burger => "burger"
    Bottom => "bottom"
    CScaleToOriginal => "c-scale-to-original"
    ChatDotRound => "chat-dot-round"
    ChatRound => "chat-round"
    ChatDotSquare => "chat-dot-square"
    ChatSquare => "chat-square"
    CircleClose => "circle-close"
    Chicken => "chicken"
    CloseNotification => "close-notification"
    Close2 => "close2"
    Cherry => "cherry"
    CoffeeCup => "coffee-cup"
    Cloudy => "cloudy"
    CollectionTag => "collection-tag"
    ColdDrink => "cold-drink"
    Collection => "collection"
    Coordinate => "coordinate"
    Connection => "connection"
    Crop => "crop"
    Cpu => "cpu"
    CopyDocument => "copy-document"
    DCaret => "d-caret"
    DArrowRight => "d-arrow-right"
    DataBoard => "data-board"
    DataAnalysis => "data-analysis"
    DataLine => "data-line"
    DArrowLeft => "d-arrow-left"
    DeleteSolid => "delete-solid"
    DeleteLocation => "delete-location"
    Discount => "discount"
    Date => "date"
    Dessert => "dessert"
    Dish => "dish"
    Delete2 => "delete2"
    DocumentCopy => "document-copy"
    Document => "document"
    Discover => "discover"
    DocumentAdd => "document-add"
    DocumentChecked => "document-checked"
    DocumentDelete => "document-delete"
    DocumentRemove => "document-remove"
    Dish2 => "dish-"
    Download1 => "download1"
    Coin => "coin"
    Female => "female"
    Film => "film"
    Error1 => "error1"
    Eleme => "eleme"
    Coffee => "coffee"
    FolderRemove => "folder-remove"
    FolderChecked => "folder-checked"
    FolderAdd1 => "folder-add1"
    FolderDelete => "folder-delete"
    Football => "football"
    Finished => "finished"
    ForkSpoon => "fork-spoon"
    FirstAidKit => "first-aid-kit"
    GobletFull => "goblet-full"
    Food => "food"
    Fullscreen => "full-screen"
    GobletSquareFull => "goblet-square-full"
    Goblet => "goblet"
    Goods => "goods"
    Headset => "headset"
    House => "house"
    IceCreamRound => "ice-cream-round"
    HotWater => "hot-water"
    HeavyRain => "heavy-rain"
    IceDrink => "ice-drink"
    IceCream => "ice-cream"
    Key1 => "key1"
    IceCreamSquare => "ice-cream-square"
    KnifeFork => "knife-fork"
    IceTea => "ice-tea"
    Info => "info"
    Grape => "grape"
    LightRain => "light-rain"
    Lock1 => "lock1"
    LocationOutline => "location-outline"
    Lightning => "lightning"
    MagicStick => "magic-stick"
    Link1 => "link1"
    Lollipop => "lollipop"
    LoadingStep => "loading-step"
    Rest => "rest"
    BellFill => "bell-fill"
    Usb => "USB"
    FilterFill => "filter-fill"
    Skin => "skin"
    FireFill => "fire-fill"
    Home => "home"
    FunnelplotFill => "funnelplot-fill"
    Bank => "bank"
    GiftFill => "gift-fill"
    Filter1 => "filter1"
    HourglassFill => "hourglass-fill"
    Funnelplot => "funnelplot"
    HomeFill => "home-fill"
    Like => "like"
    TrophyFill => "trophy-fill"
    Unlike => "unlike"
    LocationFill => "location-fill"
    Unlock => "unlock"
    CloudFill => "cloud-fill"
    Lock => "lock"
    CustomerserviceFill => "customerservice-fill"
    Customerservice => "customerservice"
    ExperimentFill => "experiment-fill"
    Flag => "flag"
    EyeFill => "eye-fill"
    Moneycollect => "moneycollect"
    LikeFill => "like-fill"
    Medicinebox => "medicinebox"
    LockFill => "lock-fill"
    Shop => "shop"
    UnlikeFill => "unlike-fill"
    Shopping => "shopping"
    StarFill => "star-fill"
    Folder => "folder"
    UnlockFill => "unlock-fill"
    FolderOpen => "folder-open"
    AlertFill => "alert-fill"
    ApiFill => "api-fill"
    Deploymentunit => "deploymentunit"
    HighlightFill => "highlight-fill"
    Accountbook => "accountbook"
    PhoneFill => "phone-fill"
    Contacts => "contacts"
    EditFill => "edit-fill"
    Carryout => "carryout"
    PushpinFill => "pushpin-fill"
    CalendarCheck => "calendar-check"
    ThunderboltFill => "thunderbolt-fill"
    Calendar1 => "calendar1"
    TagFill => "tag-fill"
    Scan => "scan1"
    WrenchFill => "wrench-fill"
    Select => "select"
    TagsFill => "tags-fill"
    Boxplot => "boxplot"
    BankFill => "bank-fill"
    Build => "build"
    CameraFill => "camera-fill"
    Sliders => "sliders"
    ErrorFill => "error-fill"
    Laptop => "laptop"
    CrownFill => "crown-fill"
    Barcode1 => "barcode1"
    MailFill => "mail-fill"
    Camera => "camera"
    CarFill => "car-fill"
    Cluster => "cluster"
    PrinterFill => "printer-fill"
    Gateway => "gateway"
    ShopFill => "shop-fill"
    Car => "car"
    SettingFill => "setting-fill"
    Printer => "printer"
    USBFill => "USB-fill"
    Read => "read"
    GoldenFill => "golden-fill"
    CloudServer => "cloud-server"
    BuildFill => "build-fill"
    CloudUpload => "cloud-upload"
    BoxplotFill => "boxplot-fill"
    Cloud => "cloud"
    SlidersFill => "sliders-fill"
    CloudDownload => "cloud-download"
    Alibaba => "alibaba"
    CloudSync => "cloud-sync"
    Alibabacloud => "alibabacloud"
    Video => "video1"
    Antdesign => "antdesign"
    NotificationIcon => "notification"
    AntCloud => "ant-cloud"
    Sound => "sound"
    Behance => "behance"
    RadarChart => "radarchart"
    Googleplus => "googleplus"
    Qrcode => "qrcode"
    Medium => "medium"
    Fund => "fund"
    Google => "google"
    Image1 => "image1"
    IE => "IE"
    Mail1 => "mail1"
    Amazon => "amazon"
    Slack => "slack"
    Idcard => "idcard"
    Alipay => "alipay"
    Creditcard => "creditcard"
    Taobao => "taobao"
    Heart => "heart"
    Zhihu => "zhihu"
    Block => "block"
    HTML => "HTML"
    Error => "error"
    Linkedin => "linkedin"
    Star => "star"
    Yahoo => "yahoo"
    Gold => "gold"
    Facebook => "facebook"
    Heatmap => "heatmap"
    Skype => "skype"
    Wifi => "wifi"
    CodeSandbox => "CodeSandbox"
    Paperclip2 => "attachment"
    Chrome => "chrome"
    Edit1 => "edit1"
    Aliwangwang => "aliwangwang"
    Key => "key"
    Apple => "apple"
    Api => "api"
    Android => "android"
    Disconnect => "disconnect"
    Sketch => "sketch"
    Highlight => "highlight"
    Gitlab => "Gitlab"
    Monitor => "monitor"
    Dribbble => "dribbble"
    Link => "link"
    Instagram => "instagram"
    Man => "man"
    Reddit => "reddit"
    Percentage => "percentage"
    Windows => "windows"
    Pushpin => "pushpin"
    Yuque => "yuque"
    Phone => "phone"
    Youtube => "Youtube"
    Shake => "shake"
    GitlabFill => "Gitlab-fill"
    Tag => "tag"
    Dropbox => "dropbox"
    Wrench => "wrench"
    Dingtalk => "dingtalk"
    Woman => "woman"
    AndroidFill => "android-fill"
    Tags => "tags"
    AppleFill => "apple-fill"
    Scissor => "scissor"
    HTMLFill => "HTML-fill"
    Mr => "mr"
    WindowsFill => "windows-fill"
    Share1 => "share1"
    QQ => "QQ"
    Branches => "branches"
    Twitter => "twitter"
    Fork => "fork"
    SkypeFill => "skype-fill"
    Shrink => "shrink"
    Weibo => "weibo"
    Arrawsalt => "arrawsalt"
    YuqueFill => "yuque-fill"
    Verticalright => "verticalright"
    YoutubeFill => "Youtube-fill"
    Verticalleft => "verticalleft"
    YahooFill => "yahoo-fill"
    Wechat => "wechat"
    ChromeFill => "chrome-fill"
    AliwangwangFill => "aliwangwang-fill"
    FullscreenExit => "fullscreen-exit"
    GithubFill => "github-fill"
    MediumCircleFill => "medium-circle-fill"
    ColumnHeight => "colum-height"
    VAlignBottom => "vertical-align-botto"
    VAlignMiddle => "vertical-align-middl"
    ToTop => "totop"
    VAlignTop => "vertical-align-top"
    Download => "download"
    SortDesc => "sort-descending"
    SortAsc => "sort-ascending"
    Fall => "fall"
    Swap => "swap"
    Stock => "stock"
    Rise => "rise"
    Indent => "indent"
    Outdent => "outdent"
    MenuIcon => "menu"
    Unorderedlist => "unorderedlist"
    Orderedlist => "orderedlist"
    AlignRight => "align-right"
    AlignCenter => "align-center"
    AlignLeft => "align-left"
    PicCenter => "pic-center"
    PicRight => "pic-right"
    PicLeft => "pic-left"
    Bold => "bold"
    FontColor => "font-colors"
    CheckCircle => "check-circle"
    Exclaimination => "exclaimination"
    CI => "CI"
    FontSize => "font-size"
    Dollar => "Dollar"
    Infomation => "infomation"
    Compass => "compass"
    LineHeight => "line-height"
    Strikethrough => "strikethrough"
    Frown => "frown"
    Underline => "underline"
    InfoCircle => "info-circle"
    Number => "number"
    LeftCircle => "left-circle"
    Italic => "italic"
    Loading => "loading"
    DownCircle => "down-circle"
    Code => "code"
    EURO => "EURO"
    ColumnWidth => "column-width"
    Copyright => "copyright"
    MinusCircle => "minus-circle"
    Meh => "meh"
    Dash => "dash"
    PlusCircle => "plus-circle"
    PlayCircle => "play-circle"
    Enter1 => "enter1"
    QuestionCircle => "question-circle"
    Line => "line"
    Pound => "Pound"
    Minus => "minus"
    RightCircle => "right-circle"
    Question => "question"
    Smile => "smile"
    Plus => "plus"
    Trademark => "trademark"
    SmallDash => "small-dash"
    Pause => "pause"
    Earth => "earth"
    BgColors => "bg-colors"
    YUAN => "YUAN"
    Crown => "crown"
    UpCircle => "up-circle"
    Drag => "drag"
    WarningCircle => "warning-circle"
    Sync => "sync"
    Gift => "gift"
    Transaction => "transaction"
    Stop => "stop"
    Undo => "undo"
    Fire => "fire"
    Redo => "redo"
    Thunderbolt => "thunderbolt"
    Reload => "reload"
    CheckCircleFill => "check-circle-fill"
    Reloadtime => "reloadtime"
    LeftCircleFill => "left-circle-fill"
    Message => "message"
    DownCircleFill => "down-circle-fill"
    Dashboard => "dashboard1"
    MinusCircleFill => "minus-circle-fill"
    Issuesclose => "issuesclose"
    CloseCircleFill => "close-circle-fill"
    Poweroff => "poweroff"
    InfoCircleFill => "info-circle-fill"
    Logout => "logout"
    UpCircleFill => "up-circle-fill"
    Login => "login"
    RightCircleFill => "right-circle-fill"
    Piechart => "piechart"
    PlusCircleFill => "plus-circle-fill"
    QuestionCircleFill => "question-circle-fill"
    Eye => "eye"
    EUROCircleFill => "EURO-circle-fill"
    FrownFill => "frown-fill"
    CopyrightCircleFil => "copyright-circle-fil"
    Export => "export"
    CICircleFill => "CI-circle-fill"
    Save1 => "save1"
    CompassFill => "compass-fill"
    Import => "Import"
    DollarCircleFill => "Dollar-circle-fill"
    Appstore => "appstore"
    PoweroffCircleFill => "poweroff-circle-fill"
    MehFill => "meh-fill"
    PlayCircleFill => "play-circle-fill"
    Layout => "layout"
    PoundCircleFill => "Pound-circle-fill"
    SmileFill => "smile-fill"
    StopFill => "stop-fill"
    Control => "control"
    WarningCircleFill => "warning-circle-fill"
    Codelibrary => "codelibrary"
    Detail => "detail"
    TrademarkCircleFil => "trademark-circle-fil"
    YUANCircleFill => "YUAN-circle-fill"
    HeartFill => "heart-fill"
    PiechartCircleFil => "piechart-circle-fil"
    Project => "project"
    DashboardFill => "dashboard-fill"
    Wallet => "wallet"
    MessageFill => "message-fill"
    Calculator => "calculator"
    Interation => "interation"
    Border => "border"
    CodelibraryFill => "codelibrary-fill"
    BorderOuter => "border-outer"
    BorderTop => "border-top"
    BorderBottom => "border-bottom"
    BorderLeft => "border-left"
    BorderRight => "border-right"
    BorderInner => "border-inner"
    AccountbookFill => "accountbook-fill"
    BorderVertical => "border-verticle"
    CarryoutFill => "carryout-fill"
    BorderHorizontal => "border-horizontal"
    CalendarFill => "calendar-fill"
    RadiusBottomleft => "radius-bottomleft"
    CalculatorFill => "calculator-fill"
    RadiusBottomright => "radius-bottomright"
    InterationFill => "interation-fill"
    RadiusUpleft => "radius-upleft"
    ProjectFill => "project-fill"
    RadiusUpright => "radius-upright"
    DetailFill => "detail-fill"
    RadiusSetting => "radius-setting"
    SaveFill => "save-fill"
    Adduser => "adduser"
    WalletFill => "wallet-fill"
    Deleteteam => "deleteteam"
    ControlFill => "control-fill"
    Deleteuser => "deleteuser"
    LayoutFill => "layout-fill"
    Addteam => "addteam"
    AppstoreFill => "appstore-fill"
    User => "user"
    MobileFill => "mobile-fill"
    Team => "team"
    TabletFill => "tablet-fill"
    AreaChart => "areachart"
    BookFill => "book-fill"
    LineChart => "linechart"
    RedenvelopeFill => "redenvelope-fill"
    Barchart => "barchart"
    SafetycertificateF => "safetycertificate-f"
    Pointmap => "pointmap"
    PropertysafetyFill => "propertysafety-fill"
    ContainerIcon => "container"
    Database => "database"
    SecurityscanFill => "securityscan-fill"
    Sever => "sever"
    FileExclamationFil => "file-exclamation-fil"
    Mobile => "mobile"
    FileAddFill => "file-add-fill"
    Tablet => "tablet"
    FileExcelFill => "file-excel-fill"
    Redenvelope => "redenvelope"
    FileMarkdownFill => "file-markdown-fill"
    Book => "book"
    FileTextFill => "file-text-fill"
    Filedone => "filedone"
    FilePptFill => "file-ppt-fill"
    Reconciliation => "reconciliation"
    FileUnknownFill => "file-unknown-fill"
    FileException => "file-exception"
    FileWordFill => "file-word-fill"
    Filesync => "filesync"
    FileZipFill => "file-zip-fill"
    FileSearch => "filesearch"
    FilePdfFill => "file-pdf-fill"
    Solution => "solution"
    FileImageFill => "file-image-fill"
    Fileprotect => "fileprotect"
    DiffFill => "diff-fill"
    FileAdd => "file-add"
    FileCopyFill => "file-copy-fill"
    FileExcel => "file-excel"
    SnippetsFill => "snippets-fill"
    FileExclamation => "file-exclamation"
    BatchfoldingFill => "batchfolding-fill"
    FilePdf => "file-pdf"
    ReconciliationFill => "reconciliation-fill"
    FileImage => "file-image"
    FileMarkdown => "file-markdown"
    FolderFill => "folder-fill"
    FileUnknown => "file-unknown"
    FolderOpenFill => "folder-open-fill"
    FilePpt => "file-ppt"
    DatabaseFill => "database-fill"
    FileWord => "file-word"
    ContainerFill => "container-fill"
    File1 => "file1"
    SeverFill => "sever-fill"
    FileZip => "file-zip"
    CalendarCheckFill => "calendar-check-fill"
    FileText => "file-text"
    ImageFill => "image-fill"
    FileCopy => "file-copy"
    IdcardFill => "idcard-fill"
    Snippets => "snippets"
    CreditcardFill => "creditcard-fill"
    Audit => "audit"
    FundFill => "fund-fill"
    Diff => "diff"
    ReadFill => "read-fill"
    Batchfolding => "Batchfolding"
    ContactsFill => "contacts-fill"
    Securityscan => "securityscan"
    Propertysafety => "propertysafety"
    NotificationFill => "notification-fill"
    Safetycertificate => "safetycertificate"
    FlagFill => "flag-fill"
    MoneycollectFill => "moneycollect-fill"
    Alert => "alert"
    MedicineboxFill => "medicinebox-fill"
    RestFill => "rest-fill"
    Hourglass => "hourglass"
    ShoppingFill => "shopping-fill"
    Bulb => "bulb"
    SkinFill => "skin-fill"
    Experiment => "experiment"
    VideoFill => "video-fill"
    Bell => "bell"
    SoundFill => "sound-fill"
    Trophy => "trophy"
    BulbFill => "bulb-fill"
    FuwuActive => "fuwu-active"
    ShouyeShouye => "shouye-shouye"
    Cangkuxinxi => "cangkuxinxi"
    Saomiao => "saomiao"
    Iconset0254 => "iconset0254"
    Zhongsuanrenwuliebiao => "zhongsuanrenwuliebiao"
    Xiangxiazhanhang => "xiangxiazhanhang"
    Qita => "qita"
    Xiajia => "xiajia"
    Feiji => "feiji"
    Tixing => "tixing"
    Shaixuan_o => "shaixuan_o"
    Siji => "siji"
    Lianxiwomen => "lianxiwomen"
    Guanyuwomen => "guanyuwomen"
    Wode => "wode"
    TruckFull => "truck-full"
    Xiayibu => "xiayibu"
    Video2 => "video"
    ImageIcon => "image"
    File => "file"
    Xinhao => "xinhao"
    Gengduo => "gengduo"
    Xuhao => "xuhao"
    Zhiye => "zhiye"
    Weixian => "weixian"
    Apptubiao => "apptubiao-"
    Jingdiananli_wujiaoxing_shoucanghou => "jingdiananli_wujiaoxing_shoucanghou"
    Jingdiananli_kongwujiaoxing_shoucang => "jingdiananli_kongwujiaoxing_shoucang"
    Caigou => "caigou"
    NaviconQtrkd => "navicon-qtrkd"
    CustomWorker => "custom-worker"
    Ruku => "ruku"
    Yichang => "yichang"
    Shougongpeidui => "shougongpeidui"
    Lunkuohua113 => "lunkuohua-113"
    Jiebang => "jiebang"
    Goodsppeinventory => "goodsppeinventory"
    Weixiujilu => "weixiujilu"
    Taizhangguanli => "taizhangguanli"
    Weixiu => "weixiu"
    Baoxiu => "baoxiu"
    Daijiedan => "daijiedan"
    Shebeidianjian => "shebeidianjian"
    Shebeidianjiantongji => "shebeidianjiantongji"
    Baoyanggongdan => "baoyanggongdan"
    Baoyangjihua => "baoyangjihua"
    Chart => "chart"
    ChartBar => "chart-bar"
    Filter => "filter"
    FilterClear => "filter-clear"
    Share => "share"
    Books => "books"
    Cart => "cart"
    Clear => "clear"
    MenuFold => "menu-fold"
    LockOff => "lock-off"
    Rotation => "rotation"
    Layers => "layers"
    LockOn => "lock-on"
    RootList => "root-list"
    AControlplatform => "a-controlplatform"
    ChartBubble => "chart-bubble"
    CaretUpSmall => "caret-up-small"
    Enter => "enter"
    Rollfront => "rollfront"
    Jump => "jump"
    Rollback => "rollback"
    CaretRightSmall => "caret-right-small"
    Mirror => "mirror"
    Time => "time"
    UserAvatar => "user-avatar"
    UsergroupClear => "usergroup-clear"
    MinusRectangle => "minus-rectangle"
    FormatHorizontalAlignTop => "format-horizontal-align-top"
    Move1 => "move1"
    Bulletpoint => "bulletpoint"
    Barcode => "barcode"
    LogoWecom => "logo-wecom"
    MenuUnfold => "menu-unfold"
    Tools => "tools"
    CaretLeftSmall => "caret-left-small"
    Round => "round"
    CaretDownSmall => "caret-down-small"
    Check => "check"
    APrecisemonitor => "a-precisemonitor"
    GenderFemale => "gender-female"
    AOrderAdjustmentcolumn => "a-order-adjustmentcolumn"
    Queue => "queue"
    Print => "print"
    Ellipsis => "ellipsis"
    TimeFilled => "time-filled"
    Slash => "slash"
    HelpCircleFilled => "help-circle-filled"
    MenuApplication => "menu-application"
    Pin => "pin"
    UserTalk => "user-talk"
    More => "more"
// ---- icons-gen:end ----
  }
}

///|
/// 图标展示视图:颜色默认主题常规文字色,传 color 固定色。
/// size 为视图边长(默认与 Body 正文字号一致,图文并排时基线协调),
/// 图标内容约占 84%。
pub fn icon(
  kind : IconKind,
  size? : Double = 13.0,
  color? : String = "",
  style? : Array[(String, &StyVal)] = [],
  handle? : (Container) -> Unit = fn(_c) { },
) -> Node {
  {
    mount: fn(parent) {
      let base : Array[(String, &StyVal)] = [("width", size), ("height", size)]
      for kv in style {
        base.push(kv)
      }
      let v = themed_container(style=base)
      handle(v)
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
/// 横向排列;style 由调用方追加(后应用,可覆盖默认值,
/// 如去掉右边距 ["marginRight", 0.0] 或加外边距)。
pub fn icon_button_t(
  kind : IconKind,
  on_click? : () -> Unit = fn() {  },
  size? : Double = 28.0,
  tip? : String = "",
  style? : Array[(String, &StyVal)] = [],
  handle? : (Container) -> Unit = fn(_c) { },
) -> Node {
  {
    mount: fn(parent) {
      let hover = Ref(false)
      let focused = Ref(false)
      let base : Array[(String, &StyVal)] = [
        ("width", size),
        ("height", size),
        ("marginRight", 6.0),
      ]
      for kv in style {
        base.push(kv)
      }
      let v = themed_container(style=base)
      handle(v)
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
