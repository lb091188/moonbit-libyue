# 组件库(`yue/components.mbt`)

纯 MoonBit 构建在声明式层之上的 Element Plus 风格、主题统一的非表单组件,零平台代码。与主题化控件(`label_t` / `button_t` / `entry_t`)一起,是搭建现代桌面应用外壳(侧边导航 + 顶栏 + 滚动内容)的推荐方式,完整演示见 `examples/components`。

**主题**:全部颜色来自 `theme_*` 常量——深色低饱和配色(非 Element Plus 默认色):蓝 `#2D68C4`、绿 `#2E9E5B`、橙 `#D9822B`、红 `#D64550`,以及文字/边框/填充灰阶。组件一律直角,hover/active 用背景色表达,文字垂直居中。

## 主题化控件

| API | 变体 / 角色 | 说明 |
|---|---|---|
| `button_t(text, on_click?, variant?)` | `Solid` / `Soft` / `Text` / `Danger` | 原生 Button,背景前景统一主题 |
| `label_t(text, role?)` | `Title` / `Section` / `Body` / `Secondary` / `Accent` | 字号颜色随角色 |
| `entry_t(text?, password?, on_input?)` | 普通 / 密码 | 仅统一字体(GTK Entry `SetColor` 会整体染黑,见 adaptation.md) |
| `checkbox_t(title, checked?, disabled?, on_change?)` | 正常 / 禁用 | 原生勾选态,主题字体颜色 |

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
