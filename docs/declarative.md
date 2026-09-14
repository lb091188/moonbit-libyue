# 声明式 UI：Node/mount 与 Store

moonbit-libyue 在经典命令式 API 之上提供三层可自由组合的糖，
体验对标 Vue 的 render 函数（`h()`）+ 轻量响应式：

| 层 | 内容 | 典型场景 |
|---|---|---|
| L1 | `X::make(...)` props 构造器、`apply_style` | 一行创建一个控件（可单独用） |
| L2 | `Node` 树 + `mount` / `vbox` / `label` / `button` … | 声明整棵界面结构 |
| L3 | `Store[T]` + `bind_label` | 数据变化自动更新界面 |

三层都建立在公开 setter 之上，不改变库的行为；与既有命令式代码可以
随意混用（`node_of` 是两个世界的桥）。完整对照示例见
`examples/showcase`（全部页面用声明式实现）。

## L1：props 构造器

每个控件有一个 `X::make` 构造器，把"创建 + 属性 + 回调"合并成一个表达式。
除"内容性"参数（如 Label 的文本）外全部可选具名，不传即用默认值：

```moonbit
let btn = @yue.Button::make("确定", on_click=fn() { save() })
let slider = @yue.Slider::make(range=Some((0.0, 100.0)), step=Some(1.0))
let entry = @yue.Entry::make(password=true, on_enter=fn(s) { check(s) })
```

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
挂为内容、返回窗口句柄；菜单栏、托盘等非视图资产经 `handle` 补挂：

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
| `label(text, …)` | Label | |
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

## 固有坑

1. **构造器叫 `make` 不叫 `with`**：`with` 是 MoonBit 保留字（struct 更新语法）。
2. **节点挂载时才实例化**：`button(...)` 返回时控件还不存在，别在构建树时保存
   控件引用；需要引用就用 `handle`（挂载时触发）。一棵树通常只 `mount` 一次，
   对同一节点再次挂载会实例化出**第二份**控件。
3. **`handle` 不叫 `ref`**：`ref` 也是 MoonBit 保留字。
4. **Store 无退订**：订阅存活整个应用期，`set` 也不去重（相同值照样通知）。
   在订阅回调里再 `set` 别的 Store 是安全的（快照遍历），但别让两条 Store
   互相触发形成死循环。
5. **bind_label 的订阅发生在挂载时**：未挂载的 bind 节点不订阅、不收通知；
   初值在挂载时用 `f(store.get())` 直接渲染。
6. **复选/单选的初始化回调**：`checkbox`/`radio` 以 `checked=true` 挂载后，
   进入事件循环时会异步收到一次 `on_change`（GTK toggled 信号语义）；
   **单选组切换时被取消选中的旧项也会收到一次 `on_change(false)`**。
   业务判断以 `is_checked()` 为准。
7. **异构 children 只有 Node 一条路**：MoonBit 的 trait 不能作数组元素类型，
   `Array[ViewLike]` 装不了混排控件——这正是 `Node` 存在的原因；
   `X::make` 层的单内容参数（`Group::make` / `Scroll::make`）则直接接受具体控件。
