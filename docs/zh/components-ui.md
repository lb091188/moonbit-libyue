# 组件库(`yue/components.mbt`)

纯 MoonBit 构建在声明式层之上的 Element Plus 风格、主题统一的非表单组件,零平台代码。与主题化控件(`label_t` / `button_t` / `entry_t`)一起,是搭建现代桌面应用外壳(侧边导航 + 顶栏 + 滚动内容)的推荐方式,完整演示见 `examples/components`。

**主题**:全部颜色来自 `theme_*` 色板——深色低饱和配色(非 Element Plus 默认色):蓝 `#2D68C4`、绿 `#2E9E5B`、橙 `#D9822B`、红 `#D64550`,以及文字/边框/填充灰阶。组件一律直角,hover/active 用背景色表达,文字垂直居中。

### 定制主题

在 `initialize()` 之后、挂载界面之前调用 `theme_apply`。颜色在绘制/挂载时读取:自绘交互组件重绘即用新色;挂载时定死的颜色(静态文字、边框等)需重建界面才生效。当前值可用 `theme_current` 读回快照。

```moonbit
@yue.initialize()
let t = @yue.default_theme()
@yue.theme_apply({ ..t, primary: "#1E4FA3", primary_light: "#E3EDFA" })
```

## 主题化控件

| API | 变体 / 角色 | 说明 |
|---|---|---|
| `button_t(text, on_click?, variant?)` | `Solid` / `Soft` / `Text` / `Danger` | 自绘按钮,hover 收敛在主题内(Solid/Danger 加深、Soft 变实底白字、Text 浅灰底) |
| `label_t(text, role?)` | `Title` / `Section` / `Body` / `Secondary` / `Accent` | 字号颜色随角色 |
| `entry_t(text?, password?, on_input?)` | 普通 / 密码 | 仅统一字体(GTK Entry `SetColor` 会整体染黑,见 adaptation.md) |
| `input_t(text?, password?, margin?, width?, height?)` | 直角边框 / 密码 | 外层自绘 1px 边框(聚焦变主题色),内部 Entry 经 `set_borderless` 去原生边框与内阴影 |
| `checkbox_t(title, checked?, disabled?, on_change?)` | 正常 / 禁用 | 自绘直角勾选框:选中实心主题色 + 白勾,hover 边框变主题色 |
| `autocomplete(options, value : Store[String], width?)` | 普通过滤 | 输入实时过滤候选,悬浮弹层(不挤压内容):Linux 原生 Popover、Windows 无边框置顶小窗口;点击候选项写入 Store,失焦/清空自动收起 |
| `date_picker_t(value? : Store[DateYMD?], on_change?, width?, placeholder?)` | 日期选择(EP 样式,全自绘):输入框样式字段,点击弹出 `calendar_t` 日历面板(Popover 承载),‹/› 切月,点选回填并收起,失焦收起 |
| `textarea_t(text?, width?, height?, margin?, on_input?)` | 多行输入:外层自绘边框(聚焦变主题色)+ 8px 内边距,内部 TextEdit 去原生边框,内容超出按平台自身滚动 |
| `divider(vertical?, spacing?)` | 分隔线:水平(默认)/竖直,1px 主题边框色,spacing 为两侧留白 |
| `calendar_t(on_pick?, value? : Store[DateYMD?])` | 自绘月历面板:‹/› 切月 + 星期行 + 42 格月网格,跨月灰显、「今天」主题色、选中实心方块;`DateYMD::format()` 出 `YYYY-MM-DD` |

## 导航

| API | 覆盖状态 |
|---|---|
| `side_menu(items, selected, width?)` | 悬停灰底、选中浅蓝底 + 强调条;经 `set_visible` 联动页面 |
| `segmented(options, selected)` | 选中白底 + 主题色文字,悬停灰底 |
| `breadcrumb(items, selected)` | 当前项深色,其余可点悬停变主题色 |
| `pagination(current : Store[Int], pages)` | 当前页主题色实底,悬停浅蓝;‹ › 边界钳制 |
| `steps(items, current : Store[Int])` | 完成 / 当前 / 待办三态 + 连线 |

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
| `radio_group(options, selected, disabled?)` | 互斥单选 |

## 演示

`moon run examples/components` —— 四页演示板,覆盖每个组件与状态:

![基础组件](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-basic.png)

![导航](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-nav.png)

![数据展示](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-data.png)

![反馈](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-feedback.png)

组件间状态协调统一走 `Store`(subscribe / map / bind_label),见 [docs/zh/declarative.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/declarative.md)。English version: [docs/components-ui.md](https://github.com/lb091188/moonbit-libyue/blob/master/docs/components-ui.md).
