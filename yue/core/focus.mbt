// 焦点栈：逻辑焦点在 MoonBit 侧，平台只提供一个「谁能收键」的入口
// （`Window::request_focus`）。参照 libyue 的 FocusManager 形态——容器不持有
// 真实系统焦点，由我们记「当前聚焦的是第几个可聚焦对象」。
//
// id 由上层分配（控件句柄/序号都行），栈只负责次序与环绕跳转；
// 环绕语义与 Web 一致：Tab 到末尾回第一个，Shift+Tab 到首位回最后一个。

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
/// 清空焦点（拆对象前调用，避免指向已注销项）。
pub fn FocusStack::clear(self : FocusStack) -> Unit {
  self.cur = -1
  while self.ids.length() > 0 {
    let _ = self.ids.pop()
  }
}
