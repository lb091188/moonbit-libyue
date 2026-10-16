# 声明式层与响应式（@core + @ui）

界面用一棵**节点树**描述，状态用 `Store` / `Signal` 持有，框架负责「数据变了 UI 跟着变」。本文讲这套接线怎么写；样式见 [layout.md](layout.md) 与 [design.md](design.md)，组件见 [components.md](components.md)。

## 1. 节点树与挂载

`@ui` 的每个组件构造器返回一个 `@core.Node`。把节点组成 `Array[Node]` 交给 `mount_window`，一步建窗、挂载、起循环：

```moonbit
fn main {
  let count : @core.Store[Int] = @core.Store::new(0)
  let app = match @ui.mount_window(
    [@ui.col([
      @ui.text("计数", role=@ui.Title),
      @ui.button("加一", on_click=fn() { count.update(fn(n) { n + 1 }) }),
      @ui.bind_label(count, fn(n : Int) -> String { "\{n}" }),
    ], padding=16.0, row_gap=8.0)],
    title="声明式示例",
    width=320, height=200,
  ) {
    None => return   // 无窗口后端或无显示服务
    Some(a) => a
  }
  app.run()
}
```

- `mount_window(children, title?, width?=800, height?=600, handle?)`：建宿主、挂载子节点、把宿主交回给你 `run`。窗口、事件循环、浮层图层、输入法通道都在 `App::new` 里就位；无显示服务返回 `None`。
- `mount_window_render(render : () -> Array[Node], …)`：**render 槽**形态，与静态数组二选一。`render` 在挂载时调**一次**建首帧，此后框架不再重跑它，响应全靠树里的 `for_list` / `when` / `*_dyn` / `bind*` 自订阅、自差分。要整棵换内容才走 `bind_node`。
- `handle=fn(app : @core.App) { … }`：拿宿主句柄做框架没暴露的操作，例如 `app.follow_system_theme(...)`。

## 2. 命令式逃生舱

需要自己造控件、而不是用现成组件时：

| 入口 | 用途 |
|---|---|
| `@core.node_of(widget)` | 把一个已建好的 `Widget` 包成 `Node` |
| `@core.node_of_new(finish : (Widget) -> Widget)` | 现场建控件并配置，返回 `Node` |
| `Node::on_mount(node, f : () -> Unit)` | 挂载那一刻执行 `f`，用于排定时器、注册焦点等需要宿主在场的动作 |
| `@core.mount_children(parent, children)` | 把一批 `Node` 挂到某个父控件下 |
| 组件的 `handle? : (Widget) -> Unit` | 建组件时拿回它内部的 `Widget` |

> **坑（务必记住）**：需要宿主在场的动作——`set_timeout`、图表推点、托盘派发表——**不能写在构造期**。`page(app)` 这类函数求值早于建窗，那时 `app.host` 还是 `None`、进程级 timer 通道还没装上，第一拍跑在空通道上，循环不再重排就死掉。这类动作挂到 `Node::on_mount` 或 `handle` 回调上，两者都在挂载之后跑。

## 3. Store：一个值的盒子

`Store[T]` 是可读可写、可订阅的状态盒：

```moonbit
let name : @core.Store[String] = @core.Store::new("MoonBit")
name.get()                       // 读
name.set("World")                // 写（T : Eq 时按值去重，同值不通知）
name.update(fn(n) { n + "!" })   // 就地改
let off = name.subscribe(fn(v) { println(v) })
```

| 方法 | 用途 |
|---|---|
| `Store::new(value)` / `get()` | 建、读 |
| `set(v)` / `update(f)` | 写；要求 `T : Eq`，新旧相等就不通知，避免无谓重绘 |
| `set_always(v)` / `update_always(f)` | 值类型不做 Eq 去重、每次必发时用；存会被原地改的数组这类快照场景另见 adaptation |
| `subscribe(f) -> () -> Unit` / `subscribe_id(f) -> Int` / `remove(id)` | 订阅与退订 |
| `map(f : A -> B) -> Store[B]` | 派生一个只读盒 |
| `signal() -> Signal[T]` | 转成信号，喂需要 `Signal` 的入口 `bind` / `*_dyn` |

绑定到界面：文本用 `bind_label(store, f)`，展示类用 `*_dyn` 信号版；列表用 `ListStore`，见 §5。

## 4. Signal：带依赖收集的派生

`Signal[T]` 是比 `Store` 更细粒度的反应源，支持自动依赖收集：

| 入口 | 用途 |
|---|---|
| `Signal::new(v)` / `get` / `set` / `set_eq` / `update` | 基础读写 |
| `Signal::computed(fn () -> T)` | **派生信号**：函数里 `get` 到的信号自动成为依赖，依赖变则重算并通知下游 |
| `Signal::effect(fn () -> Unit)` / `@core.effect(body)` | **副作用**：跟踪体内读到的信号，变了就重跑，返回退订函数 |
| `Signal::subscribe(f) -> Int` / `remove(sid)` / `sub_count()` | 订阅、退订、计数 |
| `Signal::map(f)` / `Signal::store()` | 派生、转回 `Store` |
| `batch(fn () -> Unit)` | 批量提交，批内多次 set 只触发一轮下游 |

Store 与 Signal 可互转：`store.signal()`、`Signal.store()`。展示类入口收 `Signal[T]`，输入类控件直接吃 `Store[T]`，两者同源。

## 5. 列表与显隐：for_list / when

列表渲染走 keyed 差分，避免整表重建：

```moonbit
let rows : @core.ListStore[String] = @core.ListStore::new(["a", "b"])
@ui.for_list(rows, build=fn(item, _i) { @ui.text(item) }, key~=fn(r) { r })
```

| 入口 | 用途 |
|---|---|
| `ListStore::new / get / length / push / remove / update / splice` | 列表状态，`remove` 与 `update` 按谓词命中 |
| `ListStore::subscribe_diff(...)` / `@core.ListStore.signal()` | keyed 差分订阅 |
| `@ui.for_list(ls, build, key~, eq?)` | 按 key 建行，缺省判据是「同键同值」；会变的字段各自做成 `Store`，别整行重挂 |
| `@ui.for_list_indexed(ls, build)` | 按下标对齐，等价于无 `:key`，长度收缩才卸多余行 |

显隐用 `when`：不销毁节点，状态不丢。要两支常驻、切换只走显隐且零重建，用 `when_else`：

```moonbit
@ui.when_bool(show_sig, @ui.text("只在 show 为真时出现"))
@ui.when_else_store(vis_store, ok_node, cancel_node)   // 两支常驻，切换靠显隐
```

`when` 与 `when_else` 各有 `Signal` / `Store` × 泛型 / 布尔四组形态，详见 [components.md](components.md) 的「响应式控制」。

## 6. 整棵替换与原位替换

内容结构变化，既不是改文本也不是切显隐时：

- `@core.bind_node(sig : Signal[T], f : (T) -> Node)`：信号一变，用 `f(v)` 造的新节点**原位替换**旧节点。
- `@core.swap_node(sig : Signal[Bool], a : Node, b : Node)`：按布尔在两个节点间原位切换。

「原位替换」是本栈 relink 的定案：引擎为此提供 `insert_child` / `remove_child_at`，控件层提供 `index_of` / `move_child`。替换不重建父链，命中矩形每帧从布局结果重取，因此不需要旧链路 Windows 那两条「推迟一拍 / 强制重排」的规避。

## 7. 重绘回路

框架重绘经进程级 `@core.set_repaint_hook` 回到宿主 App，控件改状态时用 `@core.invalidate()` 请求重画当前帧。脏区增量重排保证只重算变了的那条链：`bind_label` 与 `*_dyn` 改文本只重测自身，不重建子树。

## 8. 相关文档

- 组件与参数：[components.md](components.md)
- 布局样式：`Style` 值与 `class` 通道见 [layout.md](layout.md)
- 视图层与响应式设计口径：[design.md](design.md) §3 响应式、§4 视图层
- 五分钟上手：[tutorial.md](tutorial.md)
