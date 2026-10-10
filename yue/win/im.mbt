// 输入法通道（Linux = GtkIMContext 纯通道）：文本状态的唯一权威仍在
// `yue/input` 的编辑内核，这里只做四件事——喂 surrounding、报光标位、
// 取提交文本、取组合串。四条件出自 G0 探针的真机闭环（见
// docs/zh/adaptation.md「G0 输入法探针纯通道」条）：
// ①上下文要 focus_in（否则落回内建 Simple 上下文，每键直 commit）；
// ②按键先 filter_keypress，被消费就不进内核；③use_preedit=TRUE 且
// 组合串由我们自绘、只画一份；④光标一动就重报插入符矩形。
//
// 取回文本一律逐字节读：MoonBit 不能给 C 可写缓冲（写 out[0] 会踩坏对象头，
// 见 adaptation G3b 条那条 SIGSEGV）。

///|
pub struct PreeditState {
  text : String
  caret : Int
  active : Bool
}

///|
/// 把「已提交文本 + 字节光标」喂给输入法（组合串不喂，否则它会按错上下文推断）。
pub fn Window::set_im_surrounding(self : Window, text : String, caret : Int) -> Unit {
  wm_im_set_surrounding(self.id, @utf8.encode(text), caret)
}

///|
/// 报插入符矩形（窗口坐标、设备像素），候选窗据此定位。
pub fn Window::set_im_cursor(
  self : Window,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Unit {
  wm_im_set_cursor(self.id, x, y, w, h)
}

///|
/// 取一条已提交文本；没有则 None。取到即清后端缓冲（一次一条，循环调用排空）。
pub fn Window::take_commit(self : Window) -> String? {
  let n = wm_im_commit_len(self.id)
  if n <= 0 {
    None
  } else {
    let buf = FixedArray::make(n, b'\x00')
    for i = 0; i < n; i = i + 1 {
      buf[i] = wm_im_commit_byte(self.id, i).to_byte()
    }
    wm_im_commit_done(self.id)
    Some(@utf8.decode_lossy(FixedArray::unsafe_reinterpret_as_bytes(buf)))
  }
}

///|
/// 当前组合串（仅供自绘显示；不进文本状态）。
pub fn Window::preedit(self : Window) -> PreeditState {
  let n = wm_im_preedit_len(self.id)
  if n <= 0 {
    { text: "", caret: 0, active: wm_im_preedit_active(self.id) == 1 }
  } else {
    let buf = FixedArray::make(n, b'\x00')
    for i = 0; i < n; i = i + 1 {
      buf[i] = wm_im_preedit_byte(self.id, i).to_byte()
    }
    {
      text: @utf8.decode_lossy(FixedArray::unsafe_reinterpret_as_bytes(buf)),
      caret: wm_im_preedit_caret(self.id),
      active: true,
    }
  }
}
