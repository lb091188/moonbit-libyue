// 自绘控件宿主：控件树 ↔ yoga-mbt 布局树的映射、绝对矩形折算、命中测试、
// 事件路由与绘制遍历。方案 §2 把这一层划给 `yue/core`（循环/焦点栈同在 core，
// 渲染契约在 render，平台后端在 win），本层不认识任何平台句柄——输入事件由
// 上层（应用宿主）从 `yue/win` 的原始事件翻译后投递进来。
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
/// 按键事件（`keysym` 为平台虚拟键码，修饰键位取 `yue/core/keys.mbt` 的 MOD_*）。
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
  /// 绘制回调：入参是**已平移到本控件原点、已裁剪到本控件矩形**的绘制器，
  /// 以及本控件的绝对矩形（取宽高用；坐标请一律按本地写）。
  mut on_draw : Option[(@render.Painter, Rect) -> Unit]
  mut on_pointer : Option[(PointerEvent) -> Bool]
  mut on_key : Option[(KeyEvent) -> Bool]
  mut on_scroll : Option[(ScrollEvent) -> Bool]
  /// 输入法提交文本到达本控件（宿主按焦点 id 路由）；返回是否消费。
  mut on_commit : Option[(String) -> Bool]
  /// 组合串更新（文本 + 串内字节光标）；宿主每拍投给焦点控件。
  mut on_preedit : Option[(String, Int) -> Unit]
  /// 输入法需要的上下文（已提交文本 + 字节光标）；给 None 表示本控件不吃
  /// 输入法，宿主于是本轮不喂 surrounding、也不取 commit。
  mut im_context : Option[() -> (String, Int)?]
  /// 插入符矩形（窗口坐标），候选窗据此定位。
  mut im_cursor : Option[() -> Rect?]
  /// 焦点栈里的 id（0 = 不参与键盘焦点）
  mut focus_id : Int
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
    on_draw: None,
    on_pointer: None,
    on_key: None,
    on_scroll: None,
    on_commit: None,
    on_preedit: None,
    im_context: None,
    im_cursor: None,
    focus_id: 0,
  }
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
/// 指针事件路由：命中控件起沿祖先链向上，第一个返回 true 的处理器消费掉事件。
/// 交给处理器前把窗口坐标平移为该控件的本地坐标。返回是否被消费。
pub fn Widget::dispatch_pointer(self : Widget, ev : PointerEvent) -> Bool {
  let path = self.hit_path(ev.x, ev.y)
  let mut i = path.length()
  let mut handled = false
  while i > 0 && !handled {
    i = i - 1
    let w = path[i]
    let at_local = {
      kind: ev.kind,
      x: ev.x - w.rect.x,
      y: ev.y - w.rect.y,
      button: ev.button,
      mods: ev.mods,
    }
    match w.on_pointer {
      Some(f) => handled = f(at_local)
      None => ()
    }
  }
  handled
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
/// 外边距（上/下/左/右），逻辑像素。
pub fn Widget::set_margin(self : Widget, top : Double, bottom : Double, left : Double, right : Double) -> Unit {
  self.node.set_margin_top(@yoga.fixed(top))
  self.node.set_margin_bottom(@yoga.fixed(bottom))
  self.node.set_margin_left(@yoga.fixed(left))
  self.node.set_margin_right(@yoga.fixed(right))
}

///|
/// 内边距（左/上），逻辑像素。
pub fn Widget::set_padding(self : Widget, left : Double, top : Double) -> Unit {
  self.node.set_padding_left(@yoga.fixed(left))
  self.node.set_padding_top(@yoga.fixed(top))
}

///|
/// 绘制遍历：逐层平移到控件原点并裁剪到控件矩形，先画自己再画子控件
/// （后画的覆盖在前，与命中优先级同一口径）。整窗共用一个绘制器会话。
pub fn Widget::paint(self : Widget, p : @render.Painter) -> Unit {
  if !self.visible {
    return ()
  }
  p.save()
  p.translate(self.rect.x, self.rect.y)
  p.clip_rect(0.0, 0.0, self.rect.w, self.rect.h)
  match self.on_draw {
    Some(f) => f(p, self.rect)
    None => ()
  }
  for k in self.kids {
    k.paint(p)
  }
  p.restore()
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
        Some(f) => f()
        None => None
      }
    None => None
  }
}
