# 声明式 UI：Node/mount 与 Store

moonbit-libyue 在经典命令式 API 之上提供三层可自由组合的语法糖

| 层 | 内容 | 典型场景 |
|---|---|---|
| L1 | `X::make(...)` props 构造器、`apply_style` | 一行创建一个控件（可单独用） |
| L2 | `Node` 树 + `mount` / `vbox` / `label` / `button` … | 声明整棵界面结构 |
| L3 | `Store[T]` + `bind_label` | 数据变化自动更新界面 |

完整对照示例见
`examples/showcase`

## L1：props 构造器

每个控件有一个 `X::make` 构造器，把"创建 + 属性 + 回调"合并成一个表达式。
除"内容性"参数（如 Label 的文本）外全部可选具名，不传即用默认值：

```moonbit
let btn = @yue.Button::make("确定", on_click=fn() { save() })
let slider = @yue.Slider::make(range=Some((0.0, 100.0)), step=Some(1.0))
let entry = @yue.Entry::make(entry_type=Password)
entry.on_activate(fn() { check(entry.get_text()) })
```

注意 L1 构造器与 L2 同名节点的回调参数不同：`Entry::make` 是
`entry_type` / `on_activate()`（回调不带参），L2 `entry` 节点则是
`password` / `on_enter(String)`（回调携带文本，见下节）。

`style`（数值型样式键值对）与 `style_str`（字符串型）几乎在每个构造器上都有：

```moonbit
@yue.Label::make("标题", style=[("marginBottom", 10.0)],
                 style_str=[("color", "#356AA0")])
```

已有控件想批量应用样式，用自由函数 `apply_style(view, style=..., style_str=...)`。

## L2：Node 树与 mount

`Node` 表示"还没挂载的界面片段"。构造节点只是建树，**挂载时才真正创建控件、
注册回调**——因此同一份代码可以先声明后装配：

```moonbit
fn page(state : State) -> @yue.Container {
  @yue.mount([
    @yue.label("设置", style_str=[("color", "#356AA0")]),
    @yue.entry(text="昵称", on_enter=fn(s) { state.save(s) }),
    @yue.hbox([
      @yue.button("保存", on_click=fn() { state.flush() }),
      @yue.button("取消"),
    ]),
  ])
}
win.set_content(page(state))   // mount 返回根 Container，直接喂给窗口
```

### 窗口作声明式根：mount_window

`Window` 没有父视图，不做成 Node，而是作为挂载入口：创建窗口、把子树
挂为内容、返回窗口句柄；菜单栏、托盘等非视图资产经 `handle` 补挂。
`handle` 执行完后窗口自动激活显示，返回即可进 `run`，无需再手动
`activate`；要抢在显示前调整窗口（无边框/透明等），写进 `handle`：

```moonbit
let win = @yue.mount_window(
  [
    @yue.label("你好"),
    @yue.button("退出", on_click=fn() { @yue.quit() }),
  ],
  title="Demo",
  size=Some((960.0, 640.0)),
  center=true,
  handle=fn(w) { w.set_menubar(build_menubar()) },
)
```

### 节点构造器一览

| 节点 | 对应控件 | 备注 |
|---|---|---|
| `vbox(children, …)` / `hbox(children, …)` | Container | 纵排 / 横排 |
| `container(on_draw, handle, …)` | Container | 自绘画布 / 拿容器句柄 |
| `label(text, …)` | Label | 文字默认跟随主题常规色(theme_apply 切换深浅即变色);固定色经 handle set_color |
| `button(title, on_click, …)` | Button | |
| `checkbox(title, checked, on_change, …)` | Checkbox | `on_change(Bool)` |
| `radio(title, checked, on_change, …)` | Radio | 同组互斥 |
| `entry(text, password, on_enter, on_input, …)` | Entry | 回调携带文本 |
| `text_edit(text, on_input, …)` | TextEdit | 回调携带文本 |
| `slider(value, range, step, on_change, …)` | Slider | `on_change(Double)` |
| `progress(value, indeterminate, …)` | ProgressBar | |
| `picker(items, selected, on_change, …)` | Picker | |
| `combo(items, selected, on_select, on_input, …)` | ComboBox | |
| `group(title, content, …)` | Group | content 是单个 Node |
| `scroll(content, content_size, policy, …)` | Scroll | content 是单个 Node |
| `separator(orientation)` | Separator | |
| `tab(pages, on_change, …)` | Tab | 每页自动包容器 |
| `date_picker(epoch, on_change)` | DatePicker | |
| `gif(image, scale)` | GifPlayer | |
| `browser(url, html, …)` | Browser | 二选一 |
| `bind_label(store, f, …)` | Label | L3 响应式绑定，见下 |

所有节点都带 `style` / `style_str`；常用节点另有 **`handle`** 参数。

### handle：拿回控件句柄

声明式树里控件到挂载时才存在。想在挂载后命令式地操作某个控件
（更新进度条、聚焦输入框……），传一个 `handle` 回调，挂载时它收到具体句柄：

```moonbit
let bar : Ref[@yue.ProgressBar?] = Ref(None)
@yue.progress(handle=fn(p) { bar.val = Some(p) })
// 之后任意时刻：bar.val 里的 p.set_value(0.5)
```

### 混用命令式代码：node_of

任何已有的 ViewLike 控件都能包成节点，嵌进声明树：

```moonbit
@yue.node_of(my_legacy_view, style=[("marginBottom", 8.0)])
```

### 自定义节点

`Node` 是开放结构（一个挂载函数字段），封装自己的复合控件只需返回 Node 的
普通函数；要更底层的控制可以直接写字面量：

```moonbit
fn tagged(label_text : String, body : Node) -> Node {
  @yue.vbox([@yue.label(label_text), body])
}
```

#### 自定义组件封装路径（`examples/showcase` 实测总结）

1. **组合式组件**（推荐）：普通函数返回 Node，参数即 props，闭包即私有状态
   （如 `card`/`nav_item`）。
2. **自绘组件**：`container(on_draw=...)` + Painter，零图片资源画出徽标等元素。
3. **有状态组件**：组件内部持私有 `Store`，用 `bind_label` 自动刷新；
   每个实例状态独立（如 `counter_widget`）。跨组件协调用共享 Store + `map`
   派生（侧边栏导航高亮即此法）。
4. **扩展内置节点**：`vbox`/`hbox` 支持 `handle`（挂载时拿回 Container 句柄，
   可设背景色等）。注意：**`Node` 的 `mount` 收到的 `parent : View` 只在
   `yue` 包内有 `attach` 可用**，包外无法直接写"往 parent 挂容器"的
   Node 字面量——需在库内扩展，或用 `node_of` 包已有视图。
5. **现代化布局**：纯 vbox/hbox/scroll 弹性盒可排出「深色侧边栏 + 顶栏 +
   滚动卡片」外壳；要点是**根节点必须 `style=[("flex", 1.0)]` 才撑满窗口**，
   侧栏定宽（width）不放 flex，主区 flex=1；根容器加
   `style_str=[("alignItems", "stretch")]` 让子列占满高度。

### 组件库（yue/components.mbt）

在声明式层之上沉淀的 Element Plus 风格非表单组件，纯 MoonBit 零平台代码：

- `side_menu(items, selected)` —— 侧边导航菜单(hover 灰底、选中浅蓝底 +
  主题色文字 + 左侧强调条,与页面 set_visible 联动);
- `segmented(options, selected)` —— 分段控制器 / 顶栏导航;
- `tag` / `tag_of_type` —— 标签(自定义色实底 / 五语义类型浅底);
- `breadcrumb(items, selected)` —— 面包屑(层级随选中态联动);
- `pagination(current, pages)` —— 分页(当前页主题色实底白字);
- `alert` / `alert_closeable` —— 提示横幅(四语义类型 / 可关闭);
- `steps(items, current)` —— 步骤条(完成/当前/待办三态);
- `collapse(panels)` —— 折叠面板(点击标题开合);
- `timeline(items)` —— 时间线(色点 + 竖线,语义色);
- `descriptions(pairs)` —— 描述列表(键值网格);
- `result(t, title, desc, children)` —— 结果页;
- `empty(desc)` —— 空状态;
- `statistic(title, value)` —— 数值统计(响应式);
- `avatar` / `badge_count` / `badge_dot` —— 头像 / 角标 / 圆点;
- `card(title, children, height?)` —— 卡片(标题栏 + 分隔线 + 边框);
- `code_view(lines)` —— 代码高亮视图：逐 token 建 AttributedText（整段设色）
  测宽后自绘排版。**等价于区间设色的视觉效果且全平台一致**——Windows 的
  AttributedText 区间字体/颜色是上游缺陷（见 adaptation.md），此法绕开，
  是做代码高亮 / 终端渲染的可行替代。内置 `tokenize_moonbit` 极简着色器
  仅作演示，消费方可传入任意词法分析结果。

全部组件配色取自 `theme_*` 主题常量(深色高级变体:蓝 #2D68C4 /
绿 #2E9E5B / 橙 #D9822B / 红 #D64550,低饱和深色调);文字一律垂直居中。
组件间状态协调统一走 `Store`；主区页面联动用「订阅 Store +
`ViewLike::set_visible`」（2026-09-16 补齐该 ABI）。完整演示见
`examples/showcase`（侧栏 + 顶栏 + 页面切换 + 代码页）;组件清单与截图详见 [docs/zh/components-ui.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/components-ui.md)。

## L3：Store 与 bind_label

`Store[T]` 是可订阅的值：`set` 时通知所有订阅者，`map` 派生只读视图，
`bind_label` 把 Store 接进声明树——状态变化，文本自动更新：

```moonbit
let count : @yue.Store[Int] = @yue.Store::new(0)

win.set_content(@yue.mount([
  @yue.bind_label(count, fn(n) { "已点 \{n} 次" }),
  @yue.button("点我", on_click=fn() { count.update(fn(n) { n + 1 }) }),
]))
```

点击按钮 → `count` 变化 → `bind_label` 的文本自动变为「已点 1 次」。
不用 Store 的地方照旧用 `handle` + setter，两者共存。

API 一览：

| 函数 | 说明 |
|---|---|
| `Store::new(v)` | 创建 |
| `get()` / `set(v)` | 读 / 写并通知 |
| `update(f)` | `set(f(get()))` |
| `subscribe(f)` | 订阅；**注册时不回调**，初始值请直接 `get` |
| `map(f)` | 派生 Store，源变化时自动跟随（可链式） |
| `bind_label(store, f, …)` | 声明树里绑定文本，`f` 把状态映射为字符串 |

### Signal：自动依赖收集的派生

`Signal[T]` 与 `Store` 共享同一内核，多一层**自动依赖收集**：
`Signal::computed(fn() { ... })` 闭包里读到的每个信号自动成为依赖，任一依赖
变化后该派生信号失效、下次读取时重算——派生关系写在定义处，不需要在动作
回调里手动 `set` 另一个 Store：

```moonbit
let count = @yue.Signal::new(0)
let doubled = @yue.Signal::computed(fn() { count.get() * 2 })

@yue.bind(doubled, fn(n) { "双倍:\{n}" })   // 信号版文本绑定
@yue.button("点我", on_click=fn() { count.update(fn(n) { n + 1 }) })
```

同一事件回调里多次 `set` 会触发多轮通知，需要合并时用 `batch` 包裹：

```moonbit
@yue.batch(fn() {
  a.set(1)
  b.set(2)   // 订阅者只在出 batch 时收到一次通知
})
```

API 一览：

| 函数 | 说明 |
|---|---|
| `Signal::new(v)` | 创建源信号 |
| `Signal::computed(f)` | 派生信号，`f` 内读到的信号自动成为依赖，惰性重算 |
| `get()` / `set(v)` / `update(f)` | 同 Store 语义 |
| `subscribe(f)` | 同 Store 语义（回调收到最新值） |
| `map(f)` | 一对一派生，等价只读一个源的 `computed` |
| `batch(fn)` | 批处理：fn 内多次 set 合并为一次通知，可嵌套 |
| `bind(sig, f, …)` | 声明树里绑定文本，接源信号或 computed 派生 |
| `Signal::store()` / `Store::signal()` | 两者零成本互转（共享值与订阅）；组件 API 的 Store 参数传 `sig.store()` 即可 |

## 固有坑

1. **节点挂载时才实例化**：`button(...)` 返回时控件还不存在，别在构建树时保存
   控件引用；需要引用就用 `handle`（挂载时触发）。一棵树通常只 `mount` 一次，
   对同一节点再次挂载会实例化出**第二份**控件。
2. **`handle` 不叫 `ref`**：`ref` 也是 MoonBit 保留字。
3. **Store 无退订**：订阅存活整个应用期，`set` 也不去重（相同值照样通知）。
   在订阅回调里再 `set` 别的 Store 是安全的（快照遍历），但别让两条 Store
   互相触发形成死循环。
4. **bind_label 的订阅发生在挂载时**：未挂载的 bind 节点不订阅、不收通知；
   初值在挂载时用 `f(store.get())` 直接渲染。
5. **复选/单选的初始化回调**：`checkbox`/`radio` 以 `checked=true` 挂载后，
   进入事件循环时会异步收到一次 `on_change`（GTK toggled 信号语义）；
   **单选组切换时被取消选中的旧项也会收到一次 `on_change(false)`**。
   业务判断以 `is_checked()` 为准。
6. **异构 children 只有 Node 一条路**：MoonBit 的 trait 不能作数组元素类型，
   `Array[ViewLike]` 装不了混排控件——这正是 `Node` 存在的原因；
   `X::make` 层的单内容参数（`Group::make` / `Scroll::make`）则直接接受具体控件。
