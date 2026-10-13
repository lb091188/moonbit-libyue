// 自绘控件宿主：控件树 ↔ yoga-mbt 布局树的映射、绝对矩形折算、命中测试、
// 事件路由与绘制遍历。方案 §2 把这一层划给 `core`（循环/焦点栈同在 core，
// 渲染契约在 render，平台后端在 win），本层不认识任何平台句柄——输入事件由
// 上层（应用宿主）从 `win` 的原始事件翻译后投递进来。
//
// **坐标口径（本层唯一一处换算）**：yoga 给出的 `left/top` 是「相对父节点边框盒」
// 的偏移，`relayout` 之后一次遍历把它折算成窗口坐标的绝对矩形写回各控件；
// 命中测试与绘制都用绝对矩形，事件交给控件前再平移成控件本地坐标
// （本地 (0,0) = 该控件边框盒左上角）。绘制时逐层 `translate + clip_rect`，
// 所以控件的绘制回调只写本地坐标、也不需要自己裁剪。

///|
pub(all) struct Rect {
  x : Double
  y : Double
  w : Double
  h : Double
}

///|
/// 光标形状编号（`Widget.cursor` 与 `Window::set_cursor` 共用同一套码）。
/// 全自绘栈没有原生控件，形状只能由宿主按悬停路径下发：取路径上**最深的那个
/// 非零请求**，所以包住一整组的 `cursor_group` 会自然回退生效。
pub const CURSOR_DEFAULT : Int = 0
///|
pub const CURSOR_HAND : Int = 1
///|
pub const CURSOR_TEXT : Int = 2
///|
pub const CURSOR_RESIZE_H : Int = 3
///|
pub const CURSOR_RESIZE_V : Int = 4

///|
/// 半开区间判定：`px ∈ [x, x+w)`、`py ∈ [y, y+h)`；零宽/零高矩形不命中。
pub fn Rect::contains(self : Rect, px : Double, py : Double) -> Bool {
  self.w > 0.0 && self.h > 0.0 && px >= self.x && px < self.x + self.w && py >= self.y && py < self.y + self.h
}

///|
pub(all) enum PointerKind {
  Down
  Up
  Move
  Leave
}

///|
/// 指针事件（窗口坐标；投递给控件时换算为本地坐标，`Leave` 保持窗口坐标）。
pub(all) struct PointerEvent {
  kind : PointerKind
  x : Double
  y : Double
  button : Int
  mods : Int
}

///|
/// 按键事件（`keysym` 为平台虚拟键码，修饰键位取 `core/keys.mbt` 的 MOD_*）。
pub(all) struct KeyEvent {
  press : Bool
  keysym : Int
  mods : Int
}

///|
/// 滚轮事件：`x/y` 为窗口坐标，`dx/dy` 为滚量。
pub(all) struct ScrollEvent {
  x : Double
  y : Double
  dx : Double
  dy : Double
  mods : Int
}

///|
/// 自绘控件：一颗布局节点 + 绘制/事件回调 + 折算出的绝对矩形。
/// 字段全公开（`pub(all)`），组件层直接经 `node` 写样式，不在本层套一层转发。
pub(all) struct Widget {
  /// 实例编号（自增，从 1 起）：控件本体比较与注册表都靠它——
  /// Widget 带闭包字段，`==` 派生不出来。
  id : Int
  node : @yoga.Node
  mut kids : Array[Widget]
  mut rect : Rect
  mut visible : Bool
  /// 最近一次「真的被画到」的帧号（见 `paint_epoch`）：宿主每帧在绘制入口
  /// `bump_paint_epoch`，遍历经过本控件时写下当前帧号。子控件**没有指向父控件的
  /// 引用**（父子互指是引用环，本工具链断不掉），所以「我所在的整块被藏起来了吗」
  /// 只能靠这个读数回答：`is_painted()` 在本帧没被画过 = 被祖先隐藏或在视口外。
  /// 自转型组件（轮播、动图）据此停掉无效重绘。
  mut paint_epoch : Int
  /// 绘制回调：入参是**已平移到本控件原点、已裁剪到本控件矩形**的绘制器，
  /// 以及本控件的绝对矩形（取宽高用；坐标请一律按本地写）。
  /// 绘制回调：第一个参数是控件本身（读 `hovered`/`pressed`/`rect` 等状态用），
  /// **不要再把控件句柄捕获进闭包**——控件持有回调、回调又持有控件就是引用环，
  /// 本工具链的计数式回收断不掉环，动态换树（bind_node 重挂）会稳定泄漏。
  mut on_draw : Option[(Widget, @render.Painter, Rect) -> Unit]
  /// 指针回调：首参是控件本身（要读 `rect` 判「松开是否在自己范围内」、
  /// 拖动边界等，都由参数拿，不要把控件句柄捕获进闭包——见 `on_draw` 注）
  mut on_pointer : Option[(Widget, PointerEvent) -> Bool]
  mut on_key : Option[(KeyEvent) -> Bool]
  mut on_scroll : Option[(ScrollEvent) -> Bool]
  /// 交互态（悬停 / 按下）：**由宿主按命中与捕获统一维护**，控件只在
  /// `on_draw` 里读，不必自己处理 enter/leave（见 `set_hover`/`set_press`）
  mut hovered : Bool
  mut pressed : Bool
  /// 键盘焦点标志：同样由宿主维护（焦点栈里只有 focus_id，控件画高亮时
  /// 要知道「那个 id 是不是我」），组件不必自己去问焦点栈
  mut focused : Bool
  /// 悬停状态变化回调（入参是本控件与新的悬停值）：给「要按悬停起停定时器」的
  /// 组件用（悬浮提示）。宿主只在悬停归属变化时调用，且父链上的控件同样算悬停
  /// （与 CSS `:hover` 同义），所以包住别人的组件也能收到——不必依赖子控件把
  /// 移动事件冒泡上来（子控件可能自己消费掉移动）。
  mut on_hover_change : Option[(Widget, Bool) -> Unit]
  /// 输入法提交文本到达本控件（宿主按焦点 id 路由）；返回是否消费。
  mut on_commit : Option[(String) -> Bool]
  /// 组合串更新（文本 + 串内字节光标）；宿主每拍投给焦点控件。
  mut on_preedit : Option[(String, Int) -> Unit]
  /// 输入法需要的上下文（已提交文本 + 字节光标）；给 None 表示本控件不吃
  /// 输入法，宿主于是本轮不喂 surrounding、也不取 commit。
  mut im_context : Option[() -> (String, Int)?]
  /// 插入符矩形（窗口坐标），候选窗据此定位。
  mut im_cursor : Option[(Widget) -> Rect?]
  /// 焦点栈里的 id（0 = 不参与键盘焦点）
  mut focus_id : Int
  /// 光标形状请求（0 = 不请求，用默认箭头；1 手型 / 2 文本 I 形 / 3 横向调整 /
  /// 4 纵向调整）。全自绘栈没有原生控件，形状由宿主按命中路径下发：取悬停路径上
  /// **最深的那个非零请求**，所以包住一整组的 `cursor_group` 会自然回退生效。
  mut cursor : Int
  /// 动态光标请求：给 Some 时**优先于 `cursor`**，且每次命中查询现算——`cursor`
  /// 是建树时定死的一次性值，禁用态这类会随单元变化的请求要用它。入参是控件本身，
  /// 同 `on_draw` 注：不要把控件句柄捕获进闭包（引用环）。返回 0 表示本控件不请求，
  /// 查询继续往祖先走（`cursor_group` 的组请求仍然生效）。
  mut cursor_fn : Option[(Widget) -> Int]
  /// 拖源载荷（W21c）：给 Some 即「本控件可拖出」，按下拖过阈值后调它取数据；
  /// 给 None（返回 None 同理）表示这一拖不成立。
  mut drag_payload : Option[() -> DragData?]
  /// 投放回调（W21c）：拖拽松手且本控件是**最深命中者**时调用，返回是否接受。
  /// 悬停高亮不靠回调：绘制方读 `@core.drag_hover() == self.id` 自判（见 drag.mbt）。
  mut on_drop : Option[(DragData, Double, Double) -> Bool]
  /// resolved `Style` 本体不进 core（core 依赖 style 会成环）：由 `@style` 包的
  /// 进程级侧表按控件 id 持有，绘制期 `@style.resolved(self)` 读取。
  /// 绘制层序键（resolved `z_index` 的落点，design.md §5 P1）：`@style.apply`
  /// 写入，绘制遍历按它**稳定重排** kids（同值保持数组序，尾赢），默认 0.0。
  mut z_index_paint : Double
  /// 整层透明度（resolved `Style.opacity` 的落点，design.md §5 P4）：绘制遍历
  /// 进本控件时把「祖先累乘 × 自身」塞进 Painter 的 `global_alpha`，默认 1.0。
  mut alpha_paint : Double
}

///|
let widget_next_id : Ref[Int] = Ref(0)

///|
pub fn Widget::new() -> Widget {
  widget_next_id.val = widget_next_id.val + 1
  {
    id: widget_next_id.val,
    node: @yoga.Node::new(),
    kids: [],
    rect: { x: 0.0, y: 0.0, w: 0.0, h: 0.0, },
    visible: true,
    paint_epoch: 0,
    on_draw: None,
    on_pointer: None,
    on_key: None,
    on_scroll: None,
    hovered: false,
    pressed: false,
    focused: false,
    on_hover_change: None,
    on_commit: None,
    on_preedit: None,
    im_context: None,
    im_cursor: None,
    focus_id: 0,
    cursor: 0,
    cursor_fn: None,
    drag_payload: None,
    on_drop: None,
    z_index_paint: 0.0,
    alpha_paint: 1.0,
  }
}

///|
/// 绘制轮次（进程级）：宿主每帧在绘制入口 `bump_paint_epoch` 一次，遍历经过的控件
/// 把当时的轮次记进 `Widget.paint_epoch`。无头测试自己派帧时也要手动 bump 才算一帧。
let paint_epoch_ref : Ref[Int] = Ref(0)

///|
pub fn bump_paint_epoch() -> Int {
  paint_epoch_ref.val = paint_epoch_ref.val + 1
  paint_epoch_ref.val
}

///|
/// 当前绘制轮次。
pub fn paint_epoch() -> Int {
  paint_epoch_ref.val
}

///|
/// 本控件在**当前这一帧**被画过吗（被祖先隐藏、被视口剔除、或还没画到 → false）。
pub fn Widget::is_painted(self : Widget) -> Bool {
  self.paint_epoch == paint_epoch_ref.val
}

///|
/// 追加子控件（同步进布局树）。
pub fn Widget::append_child(self : Widget, child : Widget) -> Unit {
  self.kids.push(child)
  self.node.append_child(child.node)
}

///|
/// 移除全部子控件并重建布局树的子节点表（本层不做增量 remove，
/// 控件重建走「清空 + 按新顺序追加」，与声明式层的整树重挂载一致）。
pub fn Widget::clear_children(self : Widget) -> Unit {
  self.kids.clear()
  self.node.clear_children()
}

///|
/// 在 `index` 处插入子控件（布局树同位插入，越界按首/尾钳制）。
/// 声明式层的就地重挂必须走这个而不是「清空再追加」——兄弟项的排布
/// 顺序与坐标才不会被换掉的那一项影响。
pub fn Widget::insert_child(self : Widget, index : Int, child : Widget) -> Unit {
  let n = self.kids.length()
  let at = if index < 0 { 0 } else if index > n { n } else { index }
  self.kids.insert(at, child)
  self.node.insert_child(at, child.node)
}

///|
/// 摘除一个子控件（按控件身份找位置）。不是本控件的直接子项返回 false。
pub fn Widget::remove_child(self : Widget, child : Widget) -> Bool {
  let mut i = 0
  let mut found = -1
  for k in self.kids {
    if k.id == child.id {
      found = i
    }
    i = i + 1
  }
  if found < 0 {
    return false
  }
  let _ = self.kids.remove(found)
  let _ = self.node.remove_child_at(found)
  true
}

///|
/// 直接子控件的位置（按控件身份找）；不是本控件的子项给 -1。
pub fn Widget::index_of(self : Widget, child : Widget) -> Int {
  let mut i = 0
  for k in self.kids {
    if k.id == child.id {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// 把第 `from` 个子控件挪到第 `to` 位（两端都越界即钳制）。
/// 声明式层的原位重挂用它：新一代先挂到尾部，再挪回旧一代原先的位置。
pub fn Widget::move_child(self : Widget, from : Int, to : Int) -> Unit {
  let n = self.kids.length()
  if n == 0 {
    return ()
  }
  let f = if from < 0 { 0 } else if from >= n { n - 1 } else { from }
  let t = if to < 0 { 0 } else if to >= n { n - 1 } else { to }
  if f == t {
    return ()
  }
  let moved = self.kids.remove(f)
  self.kids.insert(t, moved)
  let _ = self.node.remove_child_at(f)
  self.node.insert_child(t, moved.node)
}

///|
/// 子控件快照。
pub fn Widget::children(self : Widget) -> Array[Widget] {
  self.kids.copy()
}

///|
/// 显隐：与布局节点的 `Display` 同步——隐藏即不测量、不占位、不绘制、不命中
/// （`display:none` 的清零重显语义由布局引擎的语料用例守着）。
pub fn Widget::set_visible(self : Widget, v : Bool) -> Unit {
  self.visible = v
  self.node.set_display(if v {
    @yoga.Flex
  } else {
    @yoga.None
  })
}

///|
/// 设定固定宽高（border-box 语义，含自身 padding/border，与布局层口径一致）。
pub fn Widget::set_size(self : Widget, w : Double, h : Double) -> Unit {
  self.node.set_width(@yoga.fixed(w))
  self.node.set_height(@yoga.fixed(h))
}

///|
/// 排布整棵树并把绝对矩形折算回各控件；`avail_w/avail_h` 为可用空间，
/// 根控件落在窗口原点。
pub fn Widget::relayout(self : Widget, avail_w : Double, avail_h : Double) -> Unit {
  self.relayout_at(0.0, 0.0, avail_w, avail_h)
}

///|
/// 同上，但把根控件摆到窗口坐标 (ox, oy)——宿主嵌在窗口某块区域里时用这条。
pub fn Widget::relayout_at(
  self : Widget,
  ox : Double,
  oy : Double,
  avail_w : Double,
  avail_h : Double,
) -> Unit {
  @yoga.calculate_layout(self.node, Some(avail_w), Some(avail_h))
  self.collect_abs(ox, oy)
}

///|
fn Widget::collect_abs(self : Widget, ox : Double, oy : Double) -> Unit {
  if !self.visible {
    // 隐藏的整棵子树一起清零：布局引擎遇到 display:none 就不再往下递归，
    // 后代留着上一轮的旧数值——不清就会拿陈旧矩形去命中/绘制
    zero_rect_subtree(self, ox, oy)
    return ()
  }
  let l = self.node.layout()
  let ax = ox + l.left
  let ay = oy + l.top
  self.rect = { x: ax, y: ay, w: l.width, h: l.height, }
  for k in self.kids {
    k.collect_abs(ax, ay)
  }
}

///|
fn zero_rect_subtree(w : Widget, x : Double, y : Double) -> Unit {
  w.rect = { x, y, w: 0.0, h: 0.0, }
  for k in w.kids {
    zero_rect_subtree(k, x, y)
  }
}

///|
/// 命中测试：返回最深、同层里最靠后（后画在上）的可见控件；无命中给 None。
pub fn Widget::hit_test(self : Widget, px : Double, py : Double) -> Widget? {
  if !self.visible || !self.rect.contains(px, py) {
    return None
  }
  let mut i = self.kids.length()
  while i > 0 {
    i = i - 1
    match self.kids[i].hit_test(px, py) {
      Some(w) => return Some(w)
      None => ()
    }
  }
  Some(self)
}

// ---- 事件路由 ----
// 传播规则：从命中控件起沿祖先链向上，第一个返回 true 的处理器消费掉事件
// （返回 false 继续上传）。这与旧链路的「控件不处理则父容器接手」一致，
// 滚动要冒泡到滚动容器、按下要冒泡到卡片/按钮的包裹层都靠它。
// 本地化：交给处理器前把窗口坐标平移为该控件的本地坐标。

///|
/// 命中路径：自根控件到命中控件（含两端）；未命中给空表。
pub fn Widget::hit_path(self : Widget, px : Double, py : Double) -> Array[Widget] {
  path_to(self, px, py)
}

///|
fn path_to(w : Widget, px : Double, py : Double) -> Array[Widget] {
  if !w.visible || !w.rect.contains(px, py) {
    return []
  }
  let mut i = w.kids.length()
  while i > 0 {
    i = i - 1
    let sub = path_to(w.kids[i], px, py)
    if sub.length() > 0 {
      let out : Array[Widget] = [w]
      for k in sub {
        out.push(k)
      }
      return out
    }
  }
  [w]
}

///|
/// 自根到指定控件 id 的路径（含两端）；控件隐藏或不在树里给空表。
fn path_to_widget(w : Widget, id : Int, acc : Array[Widget]) -> Array[Widget] {
  if !w.visible {
    return []
  }
  let here : Array[Widget] = acc.copy()
  here.push(w)
  if w.id == id {
    return here
  }
  for k in w.kids {
    let sub = path_to_widget(k, id, here)
    if sub.length() > 0 {
      return sub
    }
  }
  []
}

///|
/// 命中链上最近的可聚焦控件 id（从命中控件沿祖先链向上，第一个声明了
/// `focus_id` 的算），整条链都没有则 None。宿主在按钮按下时用它把键盘
/// 焦点交给控件——与 Web 同源（点表单控件即聚焦它），控件不必自己改焦点栈。
pub fn Widget::focusable_at(self : Widget, x : Double, y : Double) -> Int? {
  let path = self.hit_path(x, y)
  let mut i = path.length()
  while i > 0 {
    i = i - 1
    let id = path[i].focus_id
    if id != 0 {
      return Some(id)
    }
  }
  None
}

///|
/// 沿给定路径投递指针事件：从最深往上，第一个返回 true 的处理器消费掉；
/// 交给处理器前把窗口坐标平移为该控件的本地坐标。
fn dispatch_on_path(path : Array[Widget], ev : PointerEvent) -> Bool {
  // 右键（button 3）**祖先优先**：上下文菜单是容器级能力，包在内层控件外面的
  // 包装层要能先拿到它——否则包住按钮时，按钮先把按下吃掉（本仓按钮的 Down 不分
  // 按键一律消费），上下文菜单永远弹不出来。其余按键维持「最深优先」。
  let ancestor_first = ev.button == 3
  let mut i = if ancestor_first { 0 } else { path.length() }
  let mut handled = false
  while !handled {
    if ancestor_first {
      if i >= path.length() {
        break
      }
    } else {
      if i <= 0 {
        break
      }
      i = i - 1
    }
    let w = path[i]
    let at_local = {
      kind: ev.kind,
      x: ev.x - w.rect.x,
      y: ev.y - w.rect.y,
      button: ev.button,
      mods: ev.mods,
    }
    match w.on_pointer {
      Some(f) => handled = f(w, at_local)
      None => ()
    }
    // 祖先优先是**先取后进**：这里自增，正好在路径末项之后退出循环
    // （早先写成取下标前自增——路径只有一项时 path[1] 直接越界，实测右键点击
    // 必崩：PanicError at dispatch_on_path）
    if ancestor_first {
      i = i + 1
    }
  }
  handled
}

///|
/// 指针事件路由（按坐标命中）。
pub fn Widget::dispatch_pointer(self : Widget, ev : PointerEvent) -> Bool {
  dispatch_on_path(self.hit_path(ev.x, ev.y), ev)
}

///|
/// 沿「指定控件到根」的路径投递指针事件（传播规则同坐标命中）。
/// 用于按下后的捕获期：拖动与松手要交给**被按下**的那个控件，而不是当前
/// 坐标底下的控件——否则指针一离开控件就收不到 Up，按下态卡死、拖选也做不了
/// （与 Web 的 setPointerCapture 同义）。
pub fn Widget::dispatch_pointer_to(self : Widget, widget_id : Int, ev : PointerEvent) -> Bool {
  dispatch_on_path(path_to_widget(self, widget_id, []), ev)
}

///|
/// 本控件**自己**的光标请求（0 = 不请求）：`cursor_fn` 存在时以它现算的结果为准，
/// 否则取静态 `cursor`。
pub fn Widget::cursor_request(self : Widget) -> Int {
  match self.cursor_fn {
    Some(f) => f(self)
    None => self.cursor
  }
}

///|
/// 命中路径上「最深的一个非零光标请求」；无人请求时返回 0（默认箭头）。
/// 控件带 `cursor_fn` 时以它现算的结果为准（禁用态等动态请求）。
pub fn Widget::cursor_at(self : Widget, x : Double, y : Double) -> Int {
  let path = self.hit_path(x, y)
  let mut i = path.length()
  while i > 0 {
    i = i - 1
    let k = path[i].cursor_request()
    if k != 0 {
      return k
    }
  }
  0
}

///|
/// 按控件身份找控件（不在树里给 None）。
pub fn Widget::by_id(self : Widget, id : Int) -> Widget? {
  match path_to_widget(self, id, []) {
    [] => None
    path => Some(path[path.length() - 1])
  }
}

///|
/// 按**焦点栈 id** 重排 `focused` 标志（一次遍历，宿主每帧画之前同步一次）。
/// 焦点栈只记 id，控件绘制要的是「我是不是那个被聚焦的」，这层换算归宿主。
pub fn Widget::set_focused_by_focus(self : Widget, focus_id : Int) -> Unit {
  self.focused = focus_id > 0 && self.focus_id == focus_id
  for k in self.kids {
    k.set_focused_by_focus(focus_id)
  }
}

///|
/// 把悬停态交给 id 对应的控件**及其祖先链**（与 CSS `:hover` 同义：指针在子项上
/// 时父项也算悬停），`id` 为 0 或负数表示全部清掉。只有一趟遍历，且只在悬停者
/// 变化时由宿主调用；状态翻转时按控件触发 `on_hover_change`。
pub fn Widget::set_hover(self : Widget, id : Int) -> Unit {
  let path = if id > 0 {
    path_to_widget(self, id, [])
  } else {
    let empty : Array[Widget] = []
    empty
  }
  self.apply_hover_path(path)
}

///|
fn Widget::apply_hover_path(self : Widget, path : Array[Widget]) -> Unit {
  let mut on = false
  for w in path {
    if w.id == self.id {
      on = true
    }
  }
  if self.hovered != on {
    self.hovered = on
    match self.on_hover_change {
      Some(f) => f(self, on)
      None => ()
    }
  }
  for k in self.kids {
    k.apply_hover_path(path)
  }
}

///|
/// 把按下态交给 id 对应的控件（`id` 为 0 或负数表示全部清掉）。
pub fn Widget::set_press(self : Widget, id : Int) -> Unit {
  self.pressed = self.id == id
  for k in self.kids {
    k.set_press(id)
  }
}

///|
/// 指针事件在控件树上的分发决策：悬停归属、按下捕获、事件投递。
/// 独立成纯函数是为了无头可测——`App` 只保存 `hover_id`/`capture` 两个状态
/// 并把返回值写回，另在 `Down` 时做焦点接管（那要碰窗口与焦点栈）。
/// 规则：
/// - `Down`：命中者标 pressed 并成为捕获者；此后 `Move`/`Up` 都投给它
///   （指针离开也不丢抬起，按下态不会卡死，拖选与拖动插入点才有依据）；
/// - 捕获期悬停不动，`Up` 之后按抬起位置重新判定悬停者；
/// - 悬停者换了就给上一个补一次 `Leave`（窗口坐标）。
pub fn route_pointer(
  root : Widget,
  ev : PointerEvent,
  hover_id : Int,
  capture : Int,
) -> (Int, Int, Bool, Bool) {
  let hit = match root.hit_test(ev.x, ev.y) {
    Some(w) => w.id
    None => -1
  }
  let mut hover = hover_id
  let mut cap = capture
  let mut changed = false
  match ev.kind {
    Down => {
      root.set_press(hit)
      cap = hit
      changed = true
    }
    Up => changed = true
    Move => {
      if cap < 0 && hit != hover {
        if hover >= 0 {
          let _ = root.dispatch_pointer_to(
            hover,
            { kind: Leave, x: ev.x, y: ev.y, button: ev.button, mods: ev.mods, },
          )
        }
        root.set_hover(hit)
        hover = hit
        changed = true
      }
    }
    Leave => ()
  }
  let consumed = if cap >= 0 {
    root.dispatch_pointer_to(cap, ev)
  } else {
    root.dispatch_pointer(ev)
  }
  match ev.kind {
    Up => {
      root.set_press(-1)
      cap = -1
      if hit != hover {
        root.set_hover(hit)
        hover = hit
      }
      changed = true
    }
    _ => ()
  }
  (hover, cap, consumed, changed)
}

///|
/// 滚轮事件路由（传播规则同指针）。
pub fn Widget::dispatch_scroll(self : Widget, ev : ScrollEvent) -> Bool {
  let path = self.hit_path(ev.x, ev.y)
  let mut i = path.length()
  let mut handled = false
  while i > 0 && !handled {
    i = i - 1
    let w = path[i]
    let at_local = {
      x: ev.x - w.rect.x,
      y: ev.y - w.rect.y,
      dx: ev.dx,
      dy: ev.dy,
      mods: ev.mods,
    }
    match w.on_scroll {
      Some(f) => handled = f(at_local)
      None => ()
    }
  }
  handled
}

///|
/// 按键事件路由：先按焦点 id 在树里定位控件，再沿其祖先链向上直到被消费。
/// 找不到该 id（控件不存在或已隐藏）时不做任何事，返回 false。
pub fn Widget::dispatch_key(
  self : Widget,
  focus_id : Int,
  ev : KeyEvent,
) -> Bool {
  let path = path_to_id(self, focus_id, [])
  let mut i = path.length()
  let mut handled = false
  while i > 0 && !handled {
    i = i - 1
    match path[i].on_key {
      Some(f) => handled = f(ev)
      None => ()
    }
  }
  handled
}

///|
/// 焦点控件与其带 `on_key` 的祖先链：键处理只可能落在这条链上，
/// 是按键置脏的标记范围。
pub fn Widget::key_targets(self : Widget, focus_id : Int) -> Array[Widget] {
  let path = path_to_id(self, focus_id, [])
  let out : Array[Widget] = []
  for w in path {
    match w.on_key {
      Some(_) => out.push(w)
      None => ()
    }
  }
  out
}

///|
fn path_to_id(w : Widget, id : Int, acc : Array[Widget]) -> Array[Widget] {
  if !w.visible {
    return []
  }
  let here : Array[Widget] = acc.copy()
  here.push(w)
  if w.focus_id == id && id > 0 {
    return here
  }
  for k in w.kids {
    let sub = path_to_id(k, id, here)
    if sub.length() > 0 {
      return sub
    }
  }
  []
}

///|
/// 在树里按焦点 id 找控件（焦点栈只存整数 id，路由之外还要它做高亮等判断）。
pub fn Widget::find_by_focus_id(self : Widget, id : Int) -> Widget? {
  match path_to_id(self, id, []) {
    path =>
      if path.length() == 0 {
        None
      } else {
        Some(path[path.length() - 1])
      }
  }
}

///|
/// 纵向排列子控件（列容器）。
pub fn Widget::set_column(self : Widget) -> Unit {
  self.node.set_flex_direction(@yoga.Column)
}

///|
/// 外边距（上/右/下/左），逻辑像素；没给的边按 0 处理。
/// 四边同值用 [Widget::set_margin_all]（对应 CSS `margin: 14px` 的一值简写）。
/// labelled 形态与 [Widget::set_padding] 同构（design.md §1.5 第九条）：
/// 位置参数四路全 `Double`，错序编译期查不出。
pub fn Widget::set_margin(
  self : Widget,
  top? : Double = 0.0,
  right? : Double = 0.0,
  bottom? : Double = 0.0,
  left? : Double = 0.0,
) -> Unit {
  self.node.set_margin_top(@yoga.fixed(top))
  self.node.set_margin_right(@yoga.fixed(right))
  self.node.set_margin_bottom(@yoga.fixed(bottom))
  self.node.set_margin_left(@yoga.fixed(left))
}

///|
/// 外边距四边同值，逻辑像素。
pub fn Widget::set_margin_all(self : Widget, v : Double) -> Unit {
  self.node.set_margin_top(@yoga.fixed(v))
  self.node.set_margin_right(@yoga.fixed(v))
  self.node.set_margin_bottom(@yoga.fixed(v))
  self.node.set_margin_left(@yoga.fixed(v))
}

///|
/// 内边距（上/右/下/左），逻辑像素；没给的边按 0 处理。
/// 四边同值用 [Widget::set_padding_all]（对应 CSS `padding: 14px` 的一值简写）。
pub fn Widget::set_padding(
  self : Widget,
  top? : Double = 0.0,
  right? : Double = 0.0,
  bottom? : Double = 0.0,
  left? : Double = 0.0,
) -> Unit {
  self.node.set_padding_top(@yoga.fixed(top))
  self.node.set_padding_right(@yoga.fixed(right))
  self.node.set_padding_bottom(@yoga.fixed(bottom))
  self.node.set_padding_left(@yoga.fixed(left))
}

///|
/// 内边距四边同值，逻辑像素。
pub fn Widget::set_padding_all(self : Widget, v : Double) -> Unit {
  self.node.set_padding_top(@yoga.fixed(v))
  self.node.set_padding_right(@yoga.fixed(v))
  self.node.set_padding_bottom(@yoga.fixed(v))
  self.node.set_padding_left(@yoga.fixed(v))
}

///|
/// 绘制遍历：逐层平移到控件原点并裁剪到控件矩形，先画自己再画子控件
/// （后画的覆盖在前，与命中优先级同一口径）。整窗共用一个绘制器会话。
pub fn Widget::paint(self : Widget, p : @render.Painter) -> Unit {
  self.paint_at(p, 0.0, 0.0)
}

///|
/// 带「已平移原点」的绘制：`ox/oy` 是**父控件**的绝对原点，本控件只平移
/// 自己那一段差值。直接按绝对矩形逐层 translate 会把祖先的偏移重复累加
/// （嵌套一层就偏一层，第二行的文字会掉到窗口外）。
pub fn Widget::paint_at(self : Widget, p : @render.Painter, ox : Double, oy : Double) -> Unit {
  if !self.visible {
    return ()
  }
  // 视口剔除（纯光栅器后端）：整块落在当前裁剪外的控件直接跳过遍历——累积
  // 验证页一屏叠十几页，整树重画实测 550ms/帧（真机「窗口未响应」的主因之一），
  // 剔除后只画屏内那部分。判交必须用**相对当前原点的本地矩形**（rect 减去父
  // 原点 ox/oy）：CTM 的原点就在父内容原点，直接拿绝对矩形去过 CTM 会把父
  // 原点计两次（实测：oy≠0 的子树全被误剔，下半屏整片空白）。裁剪与 CTM 在
  // 会话里是设备空间的真值（滚动的平移也在 CTM 里），所以这层判交天然把滚动
  // 视口算对。cairo 后端不查（那边没有可查的设备裁剪且本来快）；旋转矩阵下
  // 用两角包围盒近似（本栈的控件绘制只用平移，够用）。
  match widget_cull_skip(
    p,
    self.rect.x - ox,
    self.rect.y - oy,
    self.rect.w,
    self.rect.h,
  ) {
    true => return ()
    false => ()
  }
  self.paint_epoch = paint_epoch_ref.val
  p.save()
  p.translate(self.rect.x - ox, self.rect.y - oy)
  p.clip_rect(0.0, 0.0, self.rect.w, self.rect.h)
  // 整层透明度:祖先累乘 × 自身(on_draw 与其子树都在这段 alpha 内绘制)
  let inherited = p.global_alpha()
  let own = self.alpha_paint
  if own < 1.0 || inherited < 1.0 {
    p.set_global_alpha(inherited * own)
  }
  match self.on_draw {
    Some(f) => f(self, p, self.rect)
    None => ()
  }
  // 层序:按 resolved z_index **稳定**重排(同值保持 kids 数组序=尾画者赢,
  // design.md §1.2「层序按 kids 数组序」的过渡口径被 z_index 取代);未应用过
  // 样式的树全部 0.0,排序恒等,现有示例逐帧不变。
  for k in widget_paint_order(self.kids) {
    k.paint_at(p, self.rect.x, self.rect.y)
  }
  p.set_global_alpha(inherited)
  p.restore()
}

///|
/// 绘制层序：按 `z_index_paint` 升序**稳定**排序（同值保持原数组序，于是后加的
/// 子件仍画在前，与「kids 数组序即层序」的旧口径兼容）。插入排序——一屏兄弟
/// 数量级小，且必须稳定（`Array::sort` 不保证）。
fn widget_paint_order(kids : Array[Widget]) -> Array[Widget] {
  let out : Array[Widget] = []
  for k in kids {
    let mut i = out.length()
    while i > 0 && out[i - 1].z_index_paint > k.z_index_paint {
      i = i - 1
    }
    out.push(k)
    if i < out.length() - 1 {
      let mut j = out.length() - 1
      while j > i {
        out[j] = out[j - 1]
        j = j - 1
      }
      out[i] = k
    }
  }
  out
}

///|
///|
/// 控件矩形（内容坐标）与当前设备裁剪不相交则为 true（可跳过）。
fn widget_cull_skip(
  p : @render.Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Bool {
  match p.raster() {
    None => false
    Some(r) => {
      let (cx0, cy0, cx1, cy1) = r.clip_bounds()
      let (ax, ay) = r.map_point(x, y)
      let (bx, by) = r.map_point(x + w, y + h)
      let x0 = ax.min(bx)
      let x1 = ax.max(bx)
      let y0 = ay.min(by)
      let y1 = ay.max(by)
      x1 <= cx0.to_double() ||
      x0 >= cx1.to_double() ||
      y1 <= cy0.to_double() ||
      y0 >= cy1.to_double()
    }
  }
}

// ---- 输入法面（宿主按焦点 id 投递；只有焦点控件参与，不冒泡）----

///|
/// 提交文本路由给焦点控件（沿祖先链冒泡，同指针事件的规则）。
pub fn Widget::dispatch_commit(
  self : Widget,
  focus_id : Int,
  text : String,
) -> Bool {
  let path = path_to_id(self, focus_id, [])
  let mut i = path.length()
  let mut handled = false
  while i > 0 && !handled {
    i = i - 1
    match path[i].on_commit {
      Some(f) => handled = f(text)
      None => ()
    }
  }
  handled
}

///|
/// 组合串投递给焦点控件（不冒泡：组合串属于正在编辑的那一个字段）。
pub fn Widget::dispatch_preedit(
  self : Widget,
  focus_id : Int,
  text : String,
  caret : Int,
) -> Unit {
  match self.find_by_focus_id(focus_id) {
    Some(w) =>
      match w.on_preedit {
        Some(f) => f(text, caret)
        None => ()
      }
    None => ()
  }
}

///|
/// 焦点控件的输入法上下文（None = 本轮不需要喂输入法）。
pub fn Widget::im_context_of(
  self : Widget,
  focus_id : Int,
) -> (String, Int)? {
  match self.find_by_focus_id(focus_id) {
    Some(w) =>
      match w.im_context {
        Some(f) => f()
        None => None
      }
    None => None
  }
}

///|
/// 焦点控件的插入符矩形（候选窗定位用）。
pub fn Widget::im_cursor_of(self : Widget, focus_id : Int) -> Rect? {
  match self.find_by_focus_id(focus_id) {
    Some(w) =>
      match w.im_cursor {
        Some(f) => f(w)
        None => None
      }
    None => None
  }
}
