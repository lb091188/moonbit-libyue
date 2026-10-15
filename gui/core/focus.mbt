// 焦点栈：逻辑焦点在 MoonBit 侧，平台只提供一个「谁能收键」的入口
// （`Window::request_focus`）。参照 libyue 的 FocusManager 形态——容器不持有
// 真实系统焦点，由我们记「当前聚焦的是第几个可聚焦对象」。
//
// id 由上层分配（控件句柄/序号都行），栈只负责次序与环绕跳转；
// 环绕语义与 Web 一致：Tab 到末尾回第一个，Shift+Tab 到首位回最后一个。
//
// 两条喂 id 的路：宿主每回合用 `sync` 按控件树对齐（声明了 `focus_id` 即在栈
// 里，调用方不必注册），以及 `register`/`unregister` 手动插拔（不在树里的临时
// 焦点，如消息框浮层）。

///|
pub struct FocusStack {
  ids : Array[Int]
  mut cur : Int
}

///|
pub fn FocusStack::new() -> FocusStack {
  { ids: [], cur: -1 }
}

///|
/// 注册可聚焦对象（重复 id 忽略），返回是否新增。
pub fn FocusStack::register(self : FocusStack, id : Int) -> Bool {
  for v in self.ids {
    if v == id {
      return false
    }
  }
  self.ids.push(id)
  if self.cur < 0 && self.ids.length() > 0 {
    self.cur = 0 // 第一个注册项默认获得焦点
  }
  true
}

///|
/// 注销对象；被注销的正是当前焦点时，焦点交给下一个（或置空）。
pub fn FocusStack::unregister(self : FocusStack, id : Int) -> Unit {
  let mut i = 0
  let mut found = -1
  for v in self.ids {
    if v == id {
      found = i
    }
    i = i + 1
  }
  if found < 0 {
    return ()
  }
  let _ = self.ids.remove(found)
  let n = self.ids.length()
  if n == 0 {
    self.cur = -1
  } else if self.cur >= n {
    self.cur = n - 1
  } else if found < self.cur {
    self.cur = self.cur - 1
  }
}

///|
pub fn FocusStack::current(self : FocusStack) -> Int? {
  if self.cur < 0 || self.cur >= self.ids.length() {
    None
  } else {
    Some(self.ids[self.cur])
  }
}

///|
pub fn FocusStack::count(self : FocusStack) -> Int {
  self.ids.length()
}

///|
/// 显式聚焦某项；不在栈里返回 false。
pub fn FocusStack::focus(self : FocusStack, id : Int) -> Bool {
  let mut i = 0
  for v in self.ids {
    if v == id {
      self.cur = i
      return true
    }
    i = i + 1
  }
  false
}

///|
/// 只读判定某个 id 是不是当前焦点。**绘制时判高亮要用这个**——`focus`
/// 是设焦点，在 `on_draw` 里调它会把焦点抢给自己。
pub fn FocusStack::is_focused(self : FocusStack, id : Int) -> Bool {
  match self.current() {
    Some(c) => c == id
    None => false
  }
}

///|
/// Tab / Shift+Tab：返回跳转后的焦点 id（无项则 None）。
pub fn FocusStack::move_focus(self : FocusStack, backward : Bool) -> Int? {
  let n = self.ids.length()
  if n == 0 {
    self.cur = -1
    return None
  }
  if self.cur < 0 {
    self.cur = 0
  } else if backward {
    self.cur = if self.cur == 0 { n - 1 } else { self.cur - 1 }
  } else {
    self.cur = if self.cur + 1 >= n { 0 } else { self.cur + 1 }
  }
  Some(self.ids[self.cur])
}

///|
/// 只放掉「当前焦点」，**保留注册表**。用于焦点让给本窗外的东西（原生子件、
/// 别的窗）：控件的高亮与光标该消失，但注册项必须在——用户点回来时
/// `focus(id)` 才找得到项。与 `clear` 的区别就在这里，`clear` 是拆对象用的。
pub fn FocusStack::drop_current(self : FocusStack) -> Unit {
  self.cur = -1
}

///|
/// 用「当前该 Tab 到的号」整体对齐注册表（宿主在按下与 Tab 之前喂
/// `Widget::focus_ids` 的读数）：树序即 Tab 序，掉出树的号随之注销。
/// **当前焦点按号保留**——号还在列表里就还是它，被摘掉才置空；列表非空但
/// 本来没有焦点时**不抢焦点**（`drop_current` 让位给网页子件之后，不能下一拍
/// 又抢回来）。手动 `register` 的号若不在这一份列表里会被对齐掉，那是「焦点
/// 归控件树」这条口径的代价：不在树里的临时焦点要每次对齐后再 `focus` 一次。
pub fn FocusStack::sync(self : FocusStack, ids : Array[Int]) -> Unit {
  let cur_id = match self.current() {
    Some(v) => v
    None => 0
  }
  while self.ids.length() > 0 {
    let _ = self.ids.pop()
  }
  for v in ids {
    if v > 0 {
      let mut dup = false
      for u in self.ids {
        if u == v {
          dup = true
        }
      }
      if !dup {
        self.ids.push(v)
      }
    }
  }
  self.cur = -1
  if cur_id > 0 {
    let mut i = 0
    for v in self.ids {
      if v == cur_id {
        self.cur = i
      }
      i = i + 1
    }
  }
}

///|
/// 清空焦点（拆对象前调用，避免指向已注销项）。
pub fn FocusStack::clear(self : FocusStack) -> Unit {
  self.cur = -1
  while self.ids.length() > 0 {
    let _ = self.ids.pop()
  }
}
