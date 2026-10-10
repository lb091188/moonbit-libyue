// 自绘输入框的编辑内核：文本状态的**唯一权威**。输入法只是它的客户端之一，
// 所以形态是「内核提供编辑操作 + 通道问内核」，不是「通道持有文本」。
//
// 坐标一律按 **UTF-8 字节下标**，且 caret/anchor 永远落在码点边界上（0xC0..0xBF
// 是续字节，遇到就回退）——与 G0 探针同源。改成码点下标会同时断掉 Pango 量宽
// 与 IME preedit 偏移的口径。
//
// 内核不碰系统剪贴板：cut/copy 返回文本、paste 接收文本，剪贴板由 sys 层搬运
// （也让这块能在无显示环境下测试）。

///|
pub struct Editor {
  chars : Array[Byte]
  mut caret : Int
  mut anchor : Int?
  mut clip : String
  undo : Array[(Array[Byte], Int, Int?)]
  redo : Array[(Array[Byte], Int, Int?)]
}

fn is_cont(b : Byte) -> Bool {
  (b.to_int() & 0xc0) == 0x80
}

fn is_word_byte(b : Byte) -> Bool {
  let v = b.to_int()
  (v >= 48 && v <= 57) || (v >= 65 && v <= 90) || (v >= 97 && v <= 122) ||
    v == 95 || v >= 0x80
}

///|
pub fn Editor::new() -> Editor {
  { chars: [], caret: 0, anchor: None, clip: "", undo: [], redo: [] }
}

///|
/// 码点边界回退：落到续字节上就一直往前退。
pub fn Editor::floor_boundary(self : Editor, i : Int) -> Int {
  let n = self.chars.length()
  let mut k = if i > n { n } else { if i < 0 { 0 } else { i } }
  // k == n 是合法的「末尾边界」，不能拿去取字符
  while k > 0 && k < n && is_cont(self.chars[k]) {
    k = k - 1
  }
  k
}

///|
/// 码点边界前进：落到续字节上就一直往后走。
pub fn Editor::boundary_after(self : Editor, i : Int) -> Int {
  let n = self.chars.length()
  let mut k = if i > n { n } else { if i < 0 { 0 } else { i } }
  while k < n && is_cont(self.chars[k]) {
    k = k + 1
  }
  k
}

///|
pub fn Editor::caret_pos(self : Editor) -> Int {
  self.caret
}

///|
pub fn Editor::byte_len(self : Editor) -> Int {
  self.chars.length()
}

///|
/// 选区半开区间 [start,end)；无选区返回 None。
pub fn Editor::selection(self : Editor) -> (Int, Int)? {
  match self.anchor {
    Some(a) =>
      if a == self.caret {
        None
      } else if a < self.caret {
        Some((a, self.caret))
      } else {
        Some((self.caret, a))
      }
    None => None
  }
}

// Array[Byte] → String：手写 UTF-8 解码，逐码点拼接（不依赖具体 builder API，
// 只有测试与输入框尺度，成本可忽略）。
fn bytes_to_string(bs : Array[Byte]) -> String {
  let mut out = ""
  let n = bs.length()
  let mut i = 0
  while i < n {
    let b0 = bs[i].to_int()
    let len = if b0 < 0x80 { 1 } else if b0 >= 0xe0 { 3 } else if b0 >= 0xc0 { 2 } else { 1 }
    if i + len > n {
      i = n
    } else {
      let mut cp = if len == 1 { b0 } else { b0 & (0x7f >> len) }
      let mut j = 1
      while j < len {
        cp = (cp << 6) | (bs[i + j].to_int() & 0x3f)
        j = j + 1
      }
      match cp.to_char() {
        Some(c) => out = "\{out}\{c}"
        None => ()
      }
      i = i + len
    }
  }
  out
}

///|
pub fn Editor::get_text(self : Editor) -> String {
  bytes_to_string(self.chars)
}

///|
/// 取 [start,end) 的文本；越界钳制并对齐码点边界。
pub fn Editor::get_text_in_range(self : Editor, start : Int, end : Int) -> String {
  let s = self.floor_boundary(start)
  let e = self.boundary_after(end)
  if e <= s {
    ""
  } else {
    let out : Array[Byte] = []
    for i = s; i < e; i = i + 1 {
      out.push(self.chars[i])
    }
    bytes_to_string(out)
  }
}

fn Editor::snapshot(self : Editor) -> Unit {
  let copy : Array[Byte] = []
  for b in self.chars {
    copy.push(b)
  }
  self.undo.push((copy, self.caret, self.anchor))
  // 新的用户动作作废 redo 栈
  while self.redo.length() > 0 {
    let _ = self.redo.pop()
  }
}

fn Editor::restore(self : Editor, snap : (Array[Byte], Int, Int?)) -> Unit {
  let (text, c, a) = snap
  self.chars.clear()
  for b in text {
    self.chars.push(b)
  }
  self.caret = self.floor_boundary(c)
  self.anchor = a
}

fn Editor::replace_range(self : Editor, start : Int, end : Int, bytes : Array[Byte]) -> Unit {
  // 先删尾再插头，避免下标在删插之间漂移
  let mut i = end
  while i > start {
    i = i - 1
    let _ = self.chars.remove(i)
  }
  let mut at = start
  for b in bytes {
    self.chars.insert(at, b)
    at = at + 1
  }
}

fn to_bytes(text : String) -> Array[Byte] {
  let bs = @utf8.encode(text)
  let out : Array[Byte] = []
  for i = 0; i < bs.length(); i = i + 1 {
    out.push(bs[i])
  }
  out
}

///|
/// 设置整段文本（程序行为，清空撤销栈；caret 钳到末尾边界）。
pub fn Editor::set_text(self : Editor, text : String) -> Unit {
  self.chars.clear()
  for b in to_bytes(text) {
    self.chars.push(b)
  }
  self.caret = self.floor_boundary(self.chars.length())
  self.anchor = None
  while self.undo.length() > 0 {
    let _ = self.undo.pop()
  }
  while self.redo.length() > 0 {
    let _ = self.redo.pop()
  }
}

///|
/// 删除当前选区；返回是否删了东西。
pub fn Editor::delete_selection(self : Editor) -> Bool {
  match self.selection() {
    None => false
    Some((s, e)) => {
      self.snapshot()
      self.replace_range(s, e, [])
      self.caret = s
      self.anchor = None
      true
    }
  }
}

///|
/// 在 caret 插入文本（先替换选区），返回插入字节数。
pub fn Editor::insert_text(self : Editor, text : String) -> Int {
  let bs = to_bytes(text)
  if bs.length() == 0 {
    return 0
  }
  if self.selection() != None {
    // delete_selection 自带快照，不重复记点
    let _ = self.delete_selection()
  } else {
    self.snapshot()
  }
  let n = bs.length()
  self.replace_range(self.caret, self.caret, bs)
  self.caret = self.caret + n
  self.anchor = None
  n
}

///|
/// 选中 [start,end)（end 即 caret）；两端相同则视为折叠。
pub fn Editor::select_range(self : Editor, start : Int, end : Int) -> Unit {
  let a = self.floor_boundary(start)
  let c = self.boundary_after(end)
  self.caret = c
  if a == c {
    self.anchor = None
  } else {
    self.anchor = Some(a)
  }
}

///|
pub fn Editor::select_all(self : Editor) -> Unit {
  self.anchor = Some(0)
  self.caret = self.chars.length()
}

///|
/// 移动 caret。`shift` 延长选区，否则折叠。`unit`：0 码点 / 1 词 / 2 文本首末。
pub fn Editor::move_caret(self : Editor, dir : Int, unit : Int, shift : Bool) -> Unit {
  let n = self.chars.length()
  if !shift {
    match self.selection() {
      Some((s, e)) => self.caret = if dir < 0 { s } else { e }
      None => ()
    }
    self.anchor = None
  } else {
    match self.anchor {
      None => self.anchor = Some(self.caret)
      Some(_) => ()
    }
  }
  let mut k = self.caret
  if unit == 2 {
    k = if dir < 0 { 0 } else { n }
  } else if unit == 1 {
    if dir < 0 {
      k = self.floor_boundary(k)
      while k > 0 && !is_word_byte(self.chars[k - 1]) {
        k = self.floor_boundary(k - 1)
      }
      while k > 0 && is_word_byte(self.chars[k - 1]) {
        k = self.floor_boundary(k - 1)
      }
    } else {
      while k < n && !is_word_byte(self.chars[k]) {
        k = self.boundary_after(k + 1)
      }
      while k < n && is_word_byte(self.chars[k]) {
        k = self.boundary_after(k + 1)
      }
    }
  } else if dir < 0 {
    k = self.floor_boundary(k)
    if k > 0 {
      k = self.floor_boundary(k - 1)
    }
  } else {
    k = self.boundary_after(k)
    if k < n {
      k = self.boundary_after(k + 1)
    }
  }
  self.caret = k
  if !shift {
    self.anchor = None
  }
}

///|
/// 退格：有选区删选区，否则删前一个码点。
pub fn Editor::backspace(self : Editor) -> Unit {
  if self.selection() != None {
    let _ = self.delete_selection()
  } else if self.caret > 0 {
    self.snapshot()
    let from = self.floor_boundary(self.caret - 1)
    self.replace_range(from, self.caret, [])
    self.caret = from
  }
}

///|
/// 前向删除：有选区删选区，否则删后一个码点。
pub fn Editor::delete_forward(self : Editor) -> Unit {
  let n = self.chars.length()
  if self.selection() != None {
    let _ = self.delete_selection()
  } else if self.caret < n {
    self.snapshot()
    let to = self.boundary_after(self.caret + 1)
    self.replace_range(self.caret, to, [])
  }
}

///|
/// 剪切：返回选区文本并删除它（剪贴板搬运在 sys 层）。
pub fn Editor::cut(self : Editor) -> String {
  match self.selection() {
    None => ""
    Some((s, e)) => {
      let t = self.get_text_in_range(s, e)
      self.clip = t
      let _ = self.delete_selection()
      t
    }
  }
}

///|
/// 复制：返回选区文本，不动 caret。
pub fn Editor::copy(self : Editor) -> String {
  match self.selection() {
    Some((s, e)) => {
      let t = self.get_text_in_range(s, e)
      self.clip = t
      t
    }
    None => ""
  }
}

///|
/// 粘贴（文本由上层从剪贴板取来）。
pub fn Editor::paste_text(self : Editor, text : String) -> Unit {
  let _ = self.insert_text(text)
}

///|
/// 内核内缓存（Ctrl+V 在没有 sys 剪贴板时的回退源）。
pub fn Editor::clip_text(self : Editor) -> String {
  self.clip
}

///|
pub fn Editor::can_undo(self : Editor) -> Bool {
  self.undo.length() > 0
}

///|
pub fn Editor::can_redo(self : Editor) -> Bool {
  self.redo.length() > 0
}

///|
/// 撤销一步；返回是否真的撤了。
pub fn Editor::undo(self : Editor) -> Bool {
  match self.undo.pop() {
    None => false
    Some(snap) => {
      let copy : Array[Byte] = []
      for b in self.chars {
        copy.push(b)
      }
      self.redo.push((copy, self.caret, self.anchor))
      self.restore(snap)
      true
    }
  }
}

///|
pub fn Editor::redo(self : Editor) -> Bool {
  match self.redo.pop() {
    None => false
    Some(snap) => {
      let copy : Array[Byte] = []
      for b in self.chars {
        copy.push(b)
      }
      self.undo.push((copy, self.caret, self.anchor))
      self.restore(snap)
      true
    }
  }
}

///|
/// keysym → 可直接插入的字符（Latin-1 与 UCS keysym 两条路；其余交给 IME）。
pub fn keysym_to_text(keysym : Int) -> String? {
  let cp = if keysym >= 32 && keysym <= 126 {
    keysym
  } else if keysym >= 0xa0 && keysym <= 0xff {
    keysym
  } else if keysym >= 0x01000000 && keysym <= 0x110ffff {
    keysym - 0x01000000
  } else {
    -1
  }
  if cp < 0 {
    None
  } else {
    match cp.to_char() {
      Some(c) => Some("\{c}")
      None => None
    }
  }
}

///|
/// 把编辑控制键喂给内核；可打印键走 `keysym_to_text` 插入。
/// 返回 false 表示这键该由上层处理（Tab 焦点跳转、未识别组合等）。
/// IME 通道应先问输入法、未消费才调这里（G5）。
pub fn Editor::handle_key(
  self : Editor,
  keysym : Int,
  modifiers : Int,
) -> Bool {
  let shift = (modifiers & @core.MOD_SHIFT) != 0
  let ctrl = (modifiers & @core.MOD_CTRL) != 0
  let alt = (modifiers & (@core.MOD_ALT | @core.MOD_META)) != 0
  let mut handled = false
  if keysym == @core.KS_BACKSPACE {
    self.backspace()
    handled = true
  } else if keysym == @core.KS_DELETE {
    self.delete_forward()
    handled = true
  } else if keysym == @core.KS_LEFT {
    self.move_caret(-1, if ctrl { 1 } else { 0 }, shift)
    handled = true
  } else if keysym == @core.KS_RIGHT {
    self.move_caret(1, if ctrl { 1 } else { 0 }, shift)
    handled = true
  } else if keysym == @core.KS_HOME {
    self.move_caret(-1, 2, shift)
    handled = true
  } else if keysym == @core.KS_END {
    self.move_caret(1, 2, shift)
    handled = true
  } else if ctrl && !alt && keysym == 'a'.to_int() {
    self.select_all()
    handled = true
  } else if ctrl && keysym == 'z'.to_int() {
    if shift {
      let _ = self.redo()
    } else {
      let _ = self.undo()
    }
    handled = true
  } else if ctrl && keysym == 'y'.to_int() {
    let _ = self.redo()
    handled = true
  } else if ctrl && keysym == 'x'.to_int() {
    self.clip = self.cut()
    handled = true
  } else if ctrl && keysym == 'c'.to_int() {
    self.clip = self.copy()
    handled = true
  } else if ctrl && keysym == 'v'.to_int() {
    let t = self.clip
    if t.length() > 0 {
      self.paste_text(t)
    }
    handled = true
  } else if ctrl || alt {
    handled = false
  } else {
    match keysym_to_text(keysym) {
      Some(s) => {
        let _ = self.insert_text(s)
        handled = true
      }
      // Tab / 其它功能键 / 需 IME 的键：不消费，交回上层
      None => handled = false
    }
  }
  handled
}
