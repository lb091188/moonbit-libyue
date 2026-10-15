# 组件速查（@ui）

自绘控件与组件库全部住在 `NoahLiu/native-gui/ui`（别名 `@ui`）。每个组件是一个**返回 `@core.Node` 的构造器**——把界面描述成一棵节点树，交给 `@ui.mount_window([...])` 一次挂载。本文按家族列每个组件的入口签名与用途，作速查用；参数一律以代码为准（`gui/ui/*.mbt`）。

> 各组件的可运行示例集中在 `examples/showcase`（14 页演示板，每页一个源文件），是最快的上手参照。

## 约定（先看这一节）

**类型化参数 + `class` 样式通道。** 组件只给类型化参数（尺寸、颜色、值），不接 CSS 字符串表；外观覆盖走两条路——散参数（如 `font_size` / `background_color`），或 `class? : Array[@style.Style]`（把 `Style` 值块叠上去，数组尾赢）。样式层的完整形态见 [design.md](design.md)。

**状态走 `Store`，不写胶水。** 值类控件（复选/单选/开关/滑块/输入框/进度…）的当前值由 `@core.Store[T]` 持有：组件读写它，外部改它即刷新组件。展示类另有 `x`（收值）+ `x_dyn`（收 `Signal[T]`）两条入口，同一份画法。

**事件一律 `on_*`。** 回调命名统一 `on_click` / `on_change` / `on_drop` …；`handle?` 是逃生舱（拿回内部 `@core.Widget` 句柄做框架没暴露的操作），不是事件。

**键盘可及性内建。** 表单族控件（按钮/复选/单选/开关/步进/滑杆/评分/下拉/取色/日期时间/分段）默认自动领焦点号进 Tab 链，聚焦时描边转主题色；空格/回车激活，方向键按控件语义调值或换选（详见各条）。

**文本角色 `TextRole`：** `Plain`（无角色，走显式 size/weight）· `Title` · `Section` · `Accent`（三者走 SemiBold 主题字号）· `Body` · `Secondary`。

**语义色 `SemanticType`：** `Primary` · `Success` · `Warning` · `Danger` · `Info`。存的是 theme token 名，换主题现取、不固化快照。

---

## 布局与容器

| 构造器 | 用途 |
|---|---|
| `view(children, direction?=Column, row_gap?, column_gap?, padding?, width?, height?, grow?, background_color?, border_color?, align_items?, justify_content?, class?, handle?)` | 通用容器：方向、两轴间距、内边距、尺寸、底色与描边。尺寸给 0 = 按内容；撑满剩余用 `grow=1.0` |
| `col(children, row_gap?, padding?, width?, height?, grow?, background_color?, border_color?, align_items?, class?, handle?)` | 垂直布局容器（`view` 的 Column 形态） |
| `row(children, column_gap?, padding?, width?, height?, grow?, background_color?, border_color?, align_items?=Center, class?, handle?)` | 水平布局容器（`view` 的 Row 形态） |
| `panel(title, children, padding?=10.0, row_gap?=6.0, width?)` | 带标题面板（标题在上、内容在下，面板底 + 描边） |
| `split(first, second, direction?=Horizontal, ratio?=0.5, min_first?, min_second?, class?, handle?)` | 可拖分栏（`hsplit`/`vsplit` 合一，方向参数化） |
| `scroll_view(children, state : ScrollState, width?, height?, class?, handle?)` | 垂直滚动容器；`height` 是视口高（0 = 由父给），超出被裁剪、滚动条画右缘 |

> 滚动偏移在绘制期平移、不进布局；`ScrollState` 由 `ui/scroll.mbt` 提供。

## 文本与基础

| 构造器 | 用途 |
|---|---|
| `text(content, role?=Plain, font_size?=13.0, color?, weight?, family?, align?, max_width?, wrap?, ellipsis?, class?, handle?)` | 文本（`label` + `label_t` 合一）：`role` 给了按角色取字号/字重/主题色；尺寸来自 Pango 测量并进布局引擎（能参与基线对齐） |
| `text_dyn(sig : Signal[String], role?, font_size?, color?, …, class?, handle?)` | 随信号更新的文本：值变就地改字、只重算这一条链（旧 `bind_label` 的对应物，展示类 `*_dyn` 的原型） |
| `bind_label(store : Store[A], f : (A) -> String, font_size?, color?, handle?)` | 声明式文本绑定：初值 `f(store.get())`，之后每次 `set` 就地更新文本并重测；恒单行 |
| `bind(sig : Signal[A], f : (A) -> String, font_size?, color?, handle?)` | 文本绑定（信号版）：源信号或 `computed` 派生信号都能直接喂 |
| `divider(text?, vertical?=false, color?, class?)` | 分隔线（`separator` + 带字 `divider` 合一）：`text` 空 = 直线档（`vertical` 定横/竖），给字 = 居中断线档 |
| `image(path, width?, height?, handle?)` | 图像：按文件解码（PNG/JPEG/GIF 首帧）；尺寸给 0 用原始尺寸 |
| `icon(kind : @icons.IconKind, size?=16.0, color?, class?, handle?)` | 矢量图标：`size` 是盒子边长，颜色空 = 主题正文色（随主题现取） |
| `code_view(lines : Array[String], lang?="moonbit", font_size?=13.0, line_numbers?=false, handle?)` | 代码高亮视图（One Dark 深底，不随主题）：8 语言关键字表 + 词分类着色，可选行号列，尺寸按内容自适应 |
| `gif(path, width?, height?, looping?=true, running?=true, state?, handle?)` | 动图：`looping=false` 播完一轮就停；非 GIF 静图只画一帧 |

## 表单控件

值类控件的当前值都由 `Store[T]` 持有，外部改值即刷新，交互改值即回写。

| 构造器 | 用途 |
|---|---|
| `button(text, on_click?, variant?=Soft, color?, background_color?, font_size?, min_width?, focus_id?, disabled?, enabled?, class?, handle?)` | 按钮，`variant : ButtonVariant` = `Solid`/`Soft`/`Border`/`Text`/`Danger`；键盘空格/回车激活 |
| `input(store : Store[String], placeholder?, password?=false, read_only?=false, font_size?, family?, width?, focus_id?, caret_on?, …)` | 单行输入框：选区/双击选词/撤销重做/Ctrl+A-C-V/占位符/只读/密码遮罩/IME 内联全语义；`clearable`（悬停/聚焦出 ✕，点它清空） |
| `textarea(store : Store[String], placeholder?, rows?=3, width?=260.0, height?, font_size?, family?, read_only?, focus_id?, caret_on?, …)` | 多行输入：贪心折行（空格/拉丁词/中日韩逐字）+ 垂直滚动，上下键跨显示行 |
| `checkbox(content, state : Store[Bool], disabled?, enabled?, focus_id?, font_size?, class?, handle?)` | 复选框 + 文本标签（整行点击区）；空格/回车切换 |
| `radio_group(options : Array[String], state : Store[Int], disabled?, direction?=Row, gap?=12.0, class?)` | 单选组：`options` 依次对应值 0..n-1；空格/回车选中本项、方向键换选（到头环绕） |
| `switch(state : Store[Bool], on_text?, off_text?, disabled?, focus_id?, class?)` | 开关：40×20 胶囊 + 16 圆滑珠，可带开/关文案；空格/回车切换 |
| `slider(state : Store[Double], min?=0.0, max?=100.0, step?=0.0, width?=160.0, disabled?, focus_id?, class?, handle?)` | 滑块：按下即取值、拖动跟手、`step>0` 吸附；方向键步进、Home/End 到端 |
| `stepper(state : Store[Int], min?=0, max?=999, step?=1, focus_id?, class?)` | 数值步进器 `[-] 值 [+]`（共框三段、触界侧自动禁用）；方向键增减 |
| `select(options : Array[String], value : Store[String], on_change?, …)` | 下拉选择（唯一入口，可输入形态走 `editable=true`）：弹层在浮层图层，↑↓ 高亮 + 回车取 + Esc 收 |
| `color_picker(value : Store[String], colors?=[内置 15 色], on_change?, …)` | 取色器：字段 + 色板网格；回车开板、←/→ 移一格、↑/↓ 移行、回车取色 |
| `rate(value : Store[Int], max?=5, on_change?, …)` | 评分：矢量五角星 + 悬停预亮；方向键加减星、Home/End 清零/打满 |
| `form_item(label_text, control : Node, label_width?=90.0, error?=Store[String], handle?)` | 表单项：左定宽右对齐标签 + 右控件，下方常驻错误行（行高固定预留，不跳布局） |
| `form(title, items : Array[Node], row_gap?=8.0, handle?)` | 表单：分组标题 + 一组表单项（纵排） |
| `link(text, on_click : () -> Unit, font_size?, class?, handle?)` | 链接文字：主题色、悬停下划线、抬起触发 |

## 数据展示

展示类另有 `*_dyn` 信号版（`text` 换 `Signal`、就地改字重算宽、退订随回收袋）。

| 构造器 | 用途 |
|---|---|
| `tag_of_type(text, t : SemanticType, font_size?=12.0, class?)` | 语义色标签（浅底 + 主色字）；`tag_of_type_dyn` 收信号 |
| `tag(text, color, font_size?=12.0, class?)` | 自定色标签（实底 + 白字）；`tag_dyn` 收信号 |
| `badge_count(value : Int, max?=99, color?, class?)` | 数字徽标：超 `max` 显示「max+」；`badge_count_dyn` 收 `Signal[Int]` |
| `badge_dot(size?=8.0, color?, class?)` | 圆点徽标（无数字，只提示「有新东西」） |
| `avatar(text, size?=32.0, background_color?, class?)` | 头像：取文本首字符居中；`avatar_dyn` 收信号 |
| `statistic(title, value, precision_color?, prefix?, class?)` | 统计数字：小标题 + 数值（可带前后缀）；`statistic_dyn` 收 `Signal[String]` |
| `card(children, title?, padding?=12.0, row_gap?=6.0, class?)` | 卡片：可选标题栏 + 内容区，面板底 + 描边 |
| `descriptions(items : Array[(String, String)], title?, label_width?=96.0, class?)` | 描述列表：`(标签, 值)` 对逐行 |
| `empty(description?="暂无数据", class?)` | 空状态：图标 + 描述，居中 |
| `result(title, subtitle?, t?=Success, class?)` | 结果页：语义图标 + 标题 + 副标题 |
| `progress(state : Store[Double], max?=1.0, width?=200.0, height?=6.0, color?, class?, handle?)` | 进度条：`state` 取 0..max（纯展示） |
| `progress_line(state, max?=1.0, width?=200.0, label_side?=true, class?)` | 带百分比文字的进度 |
| `timeline(items : Array[(String, String, SemanticType)], item_height?=56.0, gap?=12.0, class?)` | 时间线：`(标题, 描述, 语义色)` 逐行等高；连接线含行间隙不断线 |
| `carousel(pages : Array[Node], width?=360.0, height?=180.0, interval_ms?=3000, rotation?=CarouselHandle::make(), class?, handle?)` | 轮播：面板序列 + 箭头 + 指示点；`interval_ms>0` 且页数 >1 自动轮播（悬停暂停） |

## 导航

| 构造器 | 用途 |
|---|---|
| `menu(items : Array[String], selected : Store[String], icons?, width?=180.0, class?, handle?)` | 侧边导航菜单：选中主题浅底 + 左缘强调条；`selected` 可共享给主区做联动 |
| `menu_sections(sections : Array[(String, Array[String])], selected, icons?, foldable?=true, width?=180.0, class?, handle?)` | 分组侧边菜单：组标题行 + 组内项；`foldable=true` 点标题收起/展开 |
| `segmented(options : Array[String], selected : Store[String], class?, handle?)` | 分段控制器：选中面板底 + 主题色文字；每段进 Tab 链、空格/回车选中、方向键换段 |
| `breadcrumb(items : Array[String], selected : Store[String], class?, handle?)` | 面包屑：层级间插 `/`；**当前项按 `selected` 判**（不按位置，否则末项永远点不动） |
| `pagination(current : Store[Int], pages : Int, class?, handle?)` | 分页 `‹ 1 2 … ›`：`current` 从 1 起，箭头越界夹到首/末页 |
| `steps(items : Array[String], current : Store[Int], class?, handle?)` | 步骤条：数字方块（已完成/当前/待办）+ 文字 + 连线；`current` 是 0 起始下标 |
| `collapse(panels : Array[(String, Array[Node])], class?, handle?)` | 折叠面板：点标题切内容显隐，各面板独立，默认只第一个展开 |
| `tree(root : Array[TreeNode], class?, handle?)` | 树：逐层缩进，点有子节点的行展开/收起 |
| `tabs(pages : Array[(String, Node)], selected? : Store[Int], class?, handle?)` | 页签：头行（选中主题色 + 底部指示条）+ 内容区预建靠显隐；`selected` 0 起始，不传内部建 |
| `transfer(left_items : Store[Array[String]], right_items : Store[Array[String]], width?=200.0, height?=160.0, item_height?=24.0, class?, handle?)` | 穿梭框：左右两列 + 中间 `›`/`‹`；两列各由一个 `Store` 驱动 |

## 表格与虚拟列表

| 构造器 | 用途 |
|---|---|
| `table(columns : Array[TableColumn], rows : Store[Array[TableRow]], width?=560.0, row_height?=36.0, selection?, sort?, on_row_click?, class?, handle?)` | 表格：表头排序（点击切 `TableSort`，排序口径归调用方）、斑马纹、悬停、行选择；列边界可拖调宽 |
| `table_v(columns, rows : Store[Array[TableRow]], width?=560.0, height?=360.0, row_height?=32.0, selection?, sort?, on_row_click?, class?, handle?)` | 虚拟表格（万行级）：固定表头 + 只挂可见区间，与 `table` 共用表头/行控件 |
| `virt_list(items : Store[Array[T]], height : Double, row_height : Double, row_of : (Int, T) -> Node, width?, overscan?=2, rev?, class?, handle?)` | 虚拟列表：`row_of(i, item)` 造第 i 行（`i` 是源下标，排序/过滤由调用方定顺序） |
| `sticky_list(groups : Array[(String, Array[Node])], st : StickyList, width?, height?, head_h?=28.0, class?, handle?)` | 粘性列表：分组标题滚动时吸顶（「当前组」每帧读布局矩形反推） |

> `TableColumn::make(...)`、`TableRow::make(cells : Array[String])` 建列与行；`sort_rows(rows, sort)`（`ui/table.mbt`）给一个数值优先 + 稳定排序的参考口径。

## 浮层与消息

浮层（对话框/气泡/菜单/提示）一律开在整窗的**浮层图层**上，天然压过内容与其它浮层，不需要常驻隐藏树。

| 构造器 | 用途 |
|---|---|
| `dialog(visible : Store[Bool], title, children, confirm_text?="确定", cancel_text?="取消", on_confirm?, on_cancel?, close_on_mask?=false, …)` | 对话框：`visible` 驱弹/收；标题栏（+✕）+ 内容 + 底部按钮（文案空串隐藏该钮）；三出口都先收再回调 |
| `message_box(visible : Store[Bool], title, content, kind?=Information, informative?, buttons?=[("确定",1)], on_response?, on_dismiss?, close_on_mask?=false, width?)` | 自绘消息框（与原生档并存）：`buttons` 是 `(文案, 编号)`，第一个是主色默认钮（Enter=第一钮，✕/Esc/点遮罩走 `on_dismiss` 不给编号）；响应编号由调用方定 |
| `popover(trigger : Node, content : Node, width?, height?, class?, handle?)` | 气泡弹层：点 trigger 在其下方弹任意内容，再点收起；`width/height` 传 0 按内容定尺 |
| `tooltip(content : Node, tip : String, delay_ms?=500, class?, handle?)` | 悬浮提示：停 `delay_ms` 后在下方开一层气泡，离开即收（走宿主 `on_hover_change` 父链语义） |
| `context_menu_for(content : Node, items : Array[(String, () -> Unit)], width?=150.0, handle?)` | 右键上下文菜单：`items` 里文案 `"-"` 画分隔线；右键走「祖先优先」派发 |

## 日期与时间

值模型（`ui/datetime.mbt`）：`DateYMD{y,m,d}`、`TimeHM{h,m}`、`DateRange`、`TimeRange`、`DateTimeRange`，配纯函数 `month_grid`/`month_shift`/`days_in_month`/`date_weekday`/`range_state_of`。

| 构造器 | 用途 |
|---|---|
| `calendar(on_pick? : (DateYMD) -> Unit, …)` | 内联月历：‹/› 切月，点选一天 |
| `date_picker(value : Store[DateYMD?], on_change?, …)` | 日期选择：字段 + 月历浮层，选中回显 `YYYY-MM-DD` |
| `date_range_picker(value : Store[DateRange], on_change?, …)` | 日期区间选择器 |
| `time_range_picker(value : Store[TimeRange], on_change?, …)` | 时间区间选择器（步进器形态，非 `input`） |
| `datetime_range_picker(value : Store[DateTimeRange], on_change?, …)` | 日期时间区间选择器 |

> 「今天」走 `wm_local_date` → `@core.local_ymd()`（系统日历时间；单调钟 `now_ms` 不能推日期）。

## 响应式控制

| 构造器 | 用途 |
|---|---|
| `when(cond : Signal[T], then : Node, pred?)` | 信号版显隐：真挂 `then`、假隐藏（不销毁、状态不丢）；另有 `when_bool`（布尔源常用档） |
| `when_else(cond, then, otherwise, pred?)` | 双支常驻、按信号切显隐（`swap_node` 落地，零重建）；`when_else_bool` 是布尔源档 |
| `when_store` / `when_store_bool` / `when_else_store` / `when_else_store_bool` | 上面各条的 `Store[T]` 形态 |
| `for_list(ls : @core.ListStore[T], build : (T, Int) -> Node, key~, eq?)` | keyed 列表差分：`build(item, index)` 建行，缺省判据「同键同值」（会变字段各自做成 Store） |
| `for_list_indexed(ls, build)` | 按下标对齐（等价无 `:key`）：长度收缩才卸多余行 |

> 整棵换内容走 `bind_node`；`ListStore` 的键控差分随 `@core` 响应式层（详见 [declarative.md](declarative.md)）。

## 拖放（应用内，三平台同构）

| 构造器 | 用途 |
|---|---|
| `drag_source(content : Node, payload? : () -> DragData?, threshold?=4.0, external?=false, on_external?)` | 拖源：`content` 上按下拖出 `threshold` 像素后调 `payload()` 取数据开拖；`external=true` 先试系统级拖出（Windows/Linux 已接），不成自动回落应用内会话 |
| `drop_target(content : Node, on_drop? : (DragData, Double, Double) -> Unit, accept? : (DragData) -> Bool)` | 落点：悬停描主题主色高亮，松手按 `accept`（默认全收）判收不收、收则调 `on_drop` |

> 拖源内容里别放按钮（指针事件最深优先，交互件会吃掉按下）。`payload()` 惰性，没过阈值当普通点击。`DragData` = `Text`/`Html`/`Paths`/`Img`（`@core`）。跨应用系统级拖放见 adaptation.md 各平台批。

## 悬停与光标组

| 构造器 | 用途 |
|---|---|
| `hover_group(children, on_click?, …)` | 悬停组：组内任意位置（含全部子控件）悬停即整组进入悬停态换底色，点击触发 `on_click`（本栈悬停态是父链语义，无需轮询指针） |
| `cursor_group(children, direction?, row_gap?, column_gap?, padding?, width?, cursor?=CURSOR_HAND, handle?)` | 光标组：组内任意位置用 `cursor` 形状；子件自己提形状时以子件为准，其余回落组的形状 |

## 声明式挂载

| 构造器 | 用途 |
|---|---|
| `mount_window(children : Array[Node], title?="", width?=800, height?=600, handle? : (App) -> Unit)` | 声明一棵树并装进窗口：建宿主（窗口 + 事件循环 + 浮层图层 + 输入法通道）→ 挂载 → 交回调用方 `run`。无显示服务返回 `None`。本栈不提供 `center`/`on_close` 参数（居中交 WM、关闭停宿主循环，收尾写在 `run()` 之后） |
| `mount_window_render(render : () -> Array[Node], title?, width?, height?, handle?)` | render 槽形态（与静态数组二选一）：`render` 挂载时调一次建首帧，此后响应全靠树内 `for_list`/`when`/`*_dyn` 自订阅自差分 |

## 组件库文档索引

- 教程与第一扇窗：[tutorial.md](tutorial.md)
- 声明式树 / `Store` / `Signal`：[declarative.md](declarative.md)
- 布局样式（`Style` 字段与 `class` 通道）：[layout.md](layout.md)
- 系统能力（`@sys`）：[system-capabilities.md](system-capabilities.md)
- 平台实测坑：[adaptation.md](adaptation.md)
