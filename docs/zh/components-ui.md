# 组件库(`yue/components.mbt`)

纯 MoonBit 构建在声明式层之上的 Element Plus 风格、主题统一的非表单组件,零平台代码。与主题化控件(`label_t` / `button_t` / `entry_t`)一起,是搭建现代桌面应用外壳(侧边导航 + 顶栏 + 滚动内容)的推荐方式,完整演示见 `examples/showcase`。

**主题**:全部颜色来自 `theme_*` 色板——深色低饱和配色(非 Element Plus 默认色):蓝 `#2D68C4`、绿 `#2E9E5B`、橙 `#D9822B`、红 `#D64550`,以及文字/边框/填充灰阶。组件一律直角,hover/active 用背景色表达,文字垂直居中。

### 定制主题 / 深浅切换

在 `initialize()` 之后任意时刻调用 `theme_apply`(内置 `default_theme` 浅色 / `dark_theme` 暗色)。切换即时生效、无需重建界面:自绘组件经主题订阅自动重绘,挂载期定死的色(容器底色/Label 文字色等)由组件内部重设,Linux 端原生控件(输入框/多行/滚动条/窗口与弹层底)CSS 一并重建,并对全部可见窗口做整体重绘兜底。跟随系统深浅:`system_prefers_dark()` 读系统偏好,`on_system_theme_change(f)` 在系统切换时回调(两者当前仅 Linux 有实现)——典型接法是启动时按系统偏好选主题、回调里重读并重新 `theme_apply`。焦点环与字段聚焦边框为中性灰单层描亮(不用主题色),不喧宾夺主。

**颜色全部内敛,使用方零负担**:库内全部组件(含基础 `label()`,默认主题常规色)开箱即跟主题,不需要调用方做任何颜色处理。自定义组件按三条法则接入,坑已封装:

| 场景 | 做法 |
|---|---|
| 自绘(on_draw) | 颜色在 draw 回调里现取 `theme_current()` 色板,无需任何订阅(主题切换时整窗强制重绘) |
| Label 文字设主题色 | `theme_bind_fg(l, fn() { theme_current().text_regular })`——内部处理了「设色后必须同文重排」的平台坑,裸 `set_color` 不跟主题、自行订阅漏重排会残留旧色 |
| 容器背景设主题色 | `theme_bind_bg(v, fn() { theme_current().bg_panel })`——定死背景不会因重绘更新,必须重设 |

固定色(品牌色块等)直接设即可,不受主题影响。

```moonbit
@yue.initialize()
let t = @yue.default_theme()
@yue.theme_apply({ ..t, primary: "#1E4FA3", primary_light: "#E3EDFA" })
```

## 主题化控件

| API | 变体 / 角色 | 说明 |
|---|---|---|
| `button_t(text, on_click?, variant?)` | `Solid` / `Soft` / `Text` / `Danger` | 自绘按钮,hover 收敛在主题内(Solid/Danger 加深、Soft 变实底白字、Text 浅灰底) |
| `label_t(text, role?, style?, style_str?, handle?)` | `Title` / `Section` / `Body` / `Secondary` / `Accent` | 字号颜色随角色,左对齐,可叠加布局样式与句柄回调 |
| `entry_t(text?, password?, on_input?)` | 普通 / 密码 | 仅统一字体(GTK Entry `SetColor` 会整体染黑,见 adaptation.md) |
| `input_t(text?, password?, margin?, width?, height?, clearable?, on_input?, invalid?)` | 直角边框 / 密码 / 可清空 / 校验红框 | 外层自绘 1px 边框(聚焦变主题色),内部 Entry 经 `set_borderless` 去原生边框与内阴影;clearable=true 悬停且非空时右侧 ✕ 点击清空;on_input 文本变化回调;invalid 传 Store[Bool] 边框变 danger 红(轻量表单校验) |
| `checkbox_t(title, checked?, disabled?, on_change?)` | 正常 / 禁用 | 自绘直角勾选框:选中实心主题色 + 白勾,hover 边框变主题色 |
| `date_picker_t(value? : Store[DateYMD?], on_change?, width?, placeholder?, clearable?)` | 日期选择(EP 样式,全自绘):输入框样式字段,点击弹出 `calendar_t` 日历面板(Popover 承载),‹/› 切月,点选回填并收起,失焦收起;clearable=true 悬停且有值时 ✕ 清空(不触发 on_change) |
| `date_range_picker_t(value? : Store[DateRange], on_change?, width?, placeholder?, clearable?)` | 日期区间(EP DateRange 样式,全自绘):字段显示「起 ~ 止」,弹区间日历——第一次点选起点,第二次点选终点(终点早于起点自动对调)后收起并回调 on_change(起, 止);中间日期浅主题色底,端点实心方块;再点字段重新开始新区间 |
| `time_range_picker_t(value? : Store[TimeRange], on_change?, width?, placeholder?, clearable?)` | 时间区间:字段显示「起:止」时:分,弹起/止两行步进编辑器(时 0-23 / 分 0-59,input_number 承载),步进即改即回调;起止默认 00:00 |
| `datetime_range_picker_t(value? : Store[DateTimeRange], on_change?, width?, placeholder?, clearable?)` | 日期时间区间:弹层 = 区间日历 + 分隔线 + 起/止两行时间步进 + 「完成」按钮;日期两段式选完或时间步进后区间完整即回调 on_change(起日, 起时, 止日, 止时);值类型 `DateTimeRange{ start : (DateYMD, TimeHM)?, end : (DateYMD, TimeHM)? }` |
| `textarea_t(text?, width?, height?, margin?, on_input?, clearable?, invalid?)` | 多行输入:外层自绘边框(聚焦变主题色)+ 8px 内边距,内部 TextEdit 去原生边框,内容超出按平台自身滚动;clearable=true 悬停且非空时右侧 ✕ 清空(on_input 收空串);invalid 同 input_t 校验红框 |
| `divider(vertical?, spacing?)` | 分隔线:水平(默认)/竖直,1px 主题边框色,spacing 为两侧留白 |
| `icon(kind, size?, color?)` | 内置矢量图标展示:136 种(箭头/文件/编辑/视图/导航/媒体/通信/系统/开发/数据/状态等,风格对齐 Tabler/Lucide,`all_icons()` 取全清单、`icon_name()` 取名),默认主题常规色,传 color 固定色;`draw_icon(p, kind, cx, cy, s, color)` 为统一自绘入口 |
| `icon_button_t(kind, on_click?, size?, tip?)` | 方形图标按钮:hover 浅灰底 + 文字色提亮,Enter/Space 触发;tip 非空挂悬浮提示;marginRight 6 便于工具栏排列 |
| `slider_t(value : Store[Double], min?, max?, step?, width?, on_change?)` | 自绘滑杆:浅灰轨道 + 主题色填充 + 方形 thumb,点击/拖拽调值(step 量化),外部 set 同样生效 |
| `tabs_t(pages : Array[(String, Node)], selected?)` | 顶部页签:选中主题色文字 + 底部 2px 指示条,内容区 set_visible 切换;selected 为页序号 Store(缺省内部建 0) |
| `select_t(options, value : Store[String], width?, on_change?, clearable?)` | 下拉选择(EP 样式,全自绘):点击弹候选列表,悬停高亮、当前选中 ✓ 标记,点选回填并收起,失焦收起;clearable=true 悬停且有值时箭头旁 ✕ 清空(value 置空串、on_change(""));三平台同形态 |
| `rate_t(value : Store[Int], max?, on_change?)` | 评分(自绘五角星):选中实心主题色/未选中描边灰,hover 预亮,点击写入星级 |
| `tooltip_t(content : Node, tip)` | 给任意节点包原生悬浮提示;Linux 端 tooltip 颜色已接管为恒深底白字(不随系统主题),其余平台为系统样式 |
| `popover_t(trigger : Node, content : Node, width, height)` | 气泡弹层:trigger 点击在自身下方弹任意 Node 内容,再点切换收起 |
| `dropdown_menu(trigger, items, on_select, width?)` | 下拉菜单:触发字段 + 菜单项弹层,悬停高亮,点击回调序号;items 中 `"-"` 画分隔线 |
| `carousel_t(pages : Array[Node], width?, height?, interval_ms?)` | 轮播:面板序列 + 左右箭头 + 底部指示点,interval_ms 毫秒自动切换(悬停暂停,>0 启用),点击箭头/圆点手动切 |
| `color_picker_t(value : Store[String], colors?, width?)` | 取色器(下拉形态):触发字段(当前色块 + hex)点击弹预设色板(Popover),选中描边 + 白勾,点选回填;色板可自定义 |
| `calendar_t(on_pick?, value? : Store[DateYMD?])` | 自绘月历面板:‹/› 切月 + 星期行 + 42 格月网格,跨月灰显、「今天」主题色、选中实心方块;`DateYMD::format()` 出 `YYYY-MM-DD` |

## 导航

| API | 覆盖状态 |
|---|---|
| `side_menu(items, selected, width?)` | 悬停灰底、选中浅蓝底 + 强调条;经 `set_visible` 联动页面 |
| `side_menu_sections(sections : Array[(String, Array[String])], selected, width?)` | 分组侧边菜单:组标题(次要色小字,不可点)+ 组内项(画法联动同 side_menu) |
| `segmented(options, selected)` | 选中白底 + 主题色文字,悬停灰底 |
| `breadcrumb(items, selected)` | 当前项深色,其余可点悬停变主题色 |
| `pagination(current : Store[Int], pages)` | 当前页主题色实底,悬停浅蓝;‹ › 边界钳制 |
| `steps(items, current : Store[Int])` | 完成 / 当前 / 待办三态 + 连线 |
| `hsplit(first, second, ratio?, min_first?, min_second?)` / `vsplit(...)` | 可拖动分隔布局(Qt QSplitter / GTK Paned 对位):8px 自绘把手常显分隔线+点纹(不靠 hover 就能找到),悬停浅灰底、拖动中主题色底白点,拖动经鼠标捕获不丢事件;ratio 为初始占比,min 钳制两栏下限 |

## 数据展示

| API | 说明 |
|---|---|
| `tag(text, color)` / `tag_of_type(text, t)` | 宽度自适应;五种语义类型 |
| `avatar(letter, color, size?)` | 方形实底,白字居中 |
| `badge_count(n)` / `badge_dot(color?)` | 数字角标 / 圆点 |
| `statistic(title, value : Store[String])` | 响应式大号数值 |
| `progress_line(value : Store[Double], height?)` | 主题色填充 + 浅灰轨道,数值响应式 |
| `descriptions(pairs)` | 键值网格 |
| `timeline(items)` | 语义色节点 + 连线 |
| `collapse(panels)` | 点击标题开合,面板独立 |
| `card(title, children, height?)` | 标题栏 + 分隔线 + 边框 |
| `code_view(lines, font_size?, width?)` | 代码高亮;逐 token 建 AttributedText(整段设色)测宽自绘,全平台一致,绕开 Windows 区间属性缺陷 |
| `table_t(columns, rows : Store[Array[TableRow]], width?, row_height?, selection?, on_row_click?)` | 表格:表头 + 斑马纹 + 悬停底色;列用 `TableColumn::make(标题, 宽, align?)`(宽 ≤0 为弹性列均分剩余宽),Store set 后整表重建。单元格 `TableCell`:`CellText` / `CellTag(文本, 语义类型)` / `CellColorBox(色值, 名)` / `CellLines(多行,行自动撑高)`,`TableRow::make(字符串数组)` 建纯文本行。不传 `selection` 行点击单选高亮;传 `selection : Store[Array[Int]]` 启用复选框列(行点击勾选、表头全选/清空、部分选中画横条),回调收 `(行号, 行)` |
| `table_v_t(columns, rows : Store[Array[TableRow]], width?, height?, row_height?, selection?, on_row_click?)` | 虚拟滚动表格(万行级):整面 canvas 自绘、只画可见行,自管滚动(滚轮/拖滚动条/键盘),不受原生滚动容器内容高度上限约束;单元格画法同 `table_t`(CellLines 行高内最多两行),列/selection 语义一致 |

## 反馈

| API | 覆盖状态 |
|---|---|
| `alert(text, t, height?)` | Success / Info / Warning / Danger 横幅 |
| `alert_closeable(text, t)` | 带 ✕ 可关闭 |
| `result(t, title, desc, children)` | 大符号 + 标题 + 描述 + 操作区 |
| `empty(desc)` | 占位块 + 说明 |
| `switch_t(checked : Store[Bool], disabled?)` | 开 / 关 / 禁用 |
| `dialog_t(visible : Store[Bool], title, children, width?, confirm_text?, cancel_text?, on_confirm?, on_cancel?, close_on_mask?)` | 应用内对话框:同窗遮罩(半透明黑,absolute 相对挂载容器——挂窗口根即盖全窗)+ 居中面板(标题栏 ✕ + 内容 + 右对齐按钮区);✕/取消/确定回调后自动收起;文案传空串隐藏按钮;视觉模态非键盘强模态 |
| `toast_layer(duration_ms?) -> (Node, (String, SemanticType) -> Unit)` | 轻提示:层节点挂窗口根(absolute 顶部,不占布局),推送函数弹语义提示条(面板底+边框+类型图标),默认 2.6s 自动移除,多条自上而下堆叠;须在层 mount 后调用 |
| `context_menu_for(content, items : Array[(String, () -> Unit)])` | 右键上下文菜单:给任意节点包原生右键菜单,文案 "-" 画分隔线;弹出位置经 bounds_in_screen 换算屏幕坐标,每次右键现建菜单 |
| `radio_group(options, selected, disabled?)` | 互斥单选 |

## 演示

`moon run examples/showcase` —— 十一页演示板(基础/表单/事件与布局/导航/数据展示/反馈 + 原生控件/画布与富文本 + 系统集成/窗口与网页/环境与平台),左侧分组菜单(基础/进阶/原生/系统四组),覆盖组件库与 libyue 全部能力:

![基础组件](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-basic.png)

![导航](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-nav.png)

![数据展示](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-data.png)

![反馈](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-feedback.png)

**原生与绘制**:「原生控件」页(Entry/Slider/ProgressBar/Checkbox/Radio/ComboBox/Picker/DatePicker/TextEdit/GifPlayer/Popover 等原生件)与「画布与富文本」页(container 自绘 + Painter 原语/混合模式/PNG、AttributedText 范围着色)。
**系统能力**:「系统集成」页(文件对话框 / 消息框 / 系统通知 / 剪贴板 / 定时器与延迟任务)与「窗口与网页」页(窗口 API / 全局快捷键 / 拖放收发 / 原生右键菜单 / 内嵌 WebView + 自定义协议)以现代主题包装 libyue 系统件;菜单栏与系统托盘在演示板启动时挂载。全能力默认主题演示见 `examples/showcase`。

组件间状态协调统一走 `Store`(subscribe / map / bind_label)或信号 `Signal`(computed 自动依赖收集,batch 批处理;组件 Store 参数可传 `sig.store()` 视图),见 [docs/zh/declarative.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/declarative.md)。English version: [docs/components-ui.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/components-ui.md).
