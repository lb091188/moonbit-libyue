// MoonBit 原生 GUI 栈 G0 探针的驱动端：文本状态的唯一权威在这里，C 侧只做
// 显示、输入法事件转发与观测。跑法见本目录 README.md。
//
// 模式 B（默认）：GtkIMContext 纯通道——验证「单状态 + 系统 IME 客户端」这条路。
// 模式 C：可见 GtkEntry + CSS 主题化——验证原生外观可压性与尺寸协商会不会咬。

///|
let text : Ref[Bytes] = Ref(Bytes::make(0, 0))

///|
let caret : Ref[Int] = Ref(0)

///|
let preedit : Ref[Bytes] = Ref(Bytes::make(0, 0))

///|
let preedit_active : Ref[Bool] = Ref(false)

///|
let notes : Ref[Array[(String, String)]] = Ref([])

///|
let seen_commit : Ref[Int] = Ref(0)

///|
let seen_preedit : Ref[Int] = Ref(0)

///|
let seen_key : Ref[Int] = Ref(0)

// 回调闭包保活：C 侧存的是函数指针 + 闭包指针，注册表按签名分表常驻
// （同 yue/view.mbt 的做法，进程级保活、不随窗口回收）

///|
let keep_key : Ref[Array[(Int, Int, Int, Int) -> Unit]] = Ref([])

///|
let keep_commit : Ref[Array[(Bytes) -> Unit]] = Ref([])

///|
let keep_preedit : Ref[Array[(Bytes, Int, Int) -> Unit]] = Ref([])

///|
let keep_note : Ref[Array[(Bytes, Bytes) -> Unit]] = Ref([])

///|
/// UTF-8 首字节 → 该码点占几字节；落在续字节上按 1 处理（只作兜底）
fn cp_len(b : Bytes, i : Int) -> Int {
  if i < 0 || i >= b.length() {
    1
  } else {
    let c = b[i].to_int()
    if c < 0x80 || c >= 0xc0 {
      if c < 0x80 {
        1
      } else if c < 0xe0 {
        2
      } else if c < 0xf0 {
        3
      } else {
        4
      }
    } else {
      1
    }
  }
}

///|
/// 拼接三段字节（前段 / 新增 / 后段），返回新 Bytes
fn splice(
  head : Bytes,
  head_len : Int,
  mid : Bytes,
  tail : Bytes,
  tail_from : Int,
) -> Bytes {
  let total = head_len + mid.length() + (tail.length() - tail_from)
  let out = FixedArray::make(total, b'\x00')
  for i = 0; i < head_len; i = i + 1 {
    out[i] = head[i]
  }
  for i = 0; i < mid.length(); i = i + 1 {
    out[head_len + i] = mid[i]
  }
  for i = tail_from; i < tail.length(); i = i + 1 {
    out[head_len + mid.length() + (i - tail_from)] = tail[i]
  }
  Bytes::from_array(out)
}

///|
fn insert_at_caret(add : Bytes) -> Unit {
  if add.length() > 0 {
    let t = text.val
    let c = caret.val
    text.val = splice(t, c, add, t, c)
    caret.val = c + add.length()
    clear_preedit()
    push_display()
  }
}

///|
fn clear_preedit() -> Unit {
  preedit.val = Bytes::make(0, 0)
  preedit_active.val = false
}

///|
/// 退一个码点（caret 左边）
fn backspace() -> Unit {
  let t = text.val
  let c = caret.val
  if c > 0 {
    let mut start = c - 1
    while start > 0 && (t[start].to_int() & 0xc0) == 0x80 {
      start = start - 1
    }
    text.val = splice(t, start, Bytes::make(0, 0), t, c)
    caret.val = start
    push_display()
  }
}

///|
/// 删一个码点（caret 右边）
fn delete_forward() -> Unit {
  let t = text.val
  let c = caret.val
  if c < t.length() {
    let n = cp_len(t, c)
    text.val = splice(t, c, Bytes::make(0, 0), t, c + n)
    push_display()
  }
}

///|
fn move_left() -> Unit {
  let t = text.val
  let c = caret.val
  if c > 0 {
    let mut start = c - 1
    while start > 0 && (t[start].to_int() & 0xc0) == 0x80 {
      start = start - 1
    }
    caret.val = start
    push_display()
  }
}

///|
fn move_right() -> Unit {
  let t = text.val
  let c = caret.val
  if c < t.length() {
    caret.val = c + cp_len(t, c)
    push_display()
  }
}

///|
/// 码点 → UTF-8 字节（自实现，避免依赖未经核实的 std 入口）
fn encode_cp(u : Int) -> Bytes {
  if u < 0x80 {
    let a = FixedArray::make(1, b'\x00')
    a[0] = u.to_byte()
    Bytes::from_array(a)
  } else if u < 0x800 {
    let a = FixedArray::make(2, b'\x00')
    a[0] = (0xc0 | (u >> 6)).to_byte()
    a[1] = (0x80 | (u & 0x3f)).to_byte()
    Bytes::from_array(a)
  } else if u < 0x10000 {
    let a = FixedArray::make(3, b'\x00')
    a[0] = (0xe0 | (u >> 12)).to_byte()
    a[1] = (0x80 | ((u >> 6) & 0x3f)).to_byte()
    a[2] = (0x80 | (u & 0x3f)).to_byte()
    Bytes::from_array(a)
  } else {
    let a = FixedArray::make(4, b'\x00')
    a[0] = (0xf0 | (u >> 18)).to_byte()
    a[1] = (0x80 | ((u >> 12) & 0x3f)).to_byte()
    a[2] = (0x80 | ((u >> 6) & 0x3f)).to_byte()
    a[3] = (0x80 | (u & 0x3f)).to_byte()
    Bytes::from_array(a)
  }
}

///|
/// 光标前缀的字节切片（量宽与插入点定位都按它算）
fn caret_prefix() -> Bytes {
  let t = text.val
  let c = caret.val
  let out = FixedArray::make(c, b'\x00')
  for i = 0; i < c; i = i + 1 {
    out[i] = t[i]
  }
  Bytes::from_array(out)
}

///|
/// 把当前状态推给 C 显示，并把插入点矩形交给输入法（候选窗定位的关键）
fn push_display() -> Unit {
  let t = text.val
  let pre = if preedit_active.val { preedit.val } else { Bytes::make(0, 0) }
  let shown = splice(t, t.length(), pre, Bytes::make(0, 0), 0)
  ip_set_display(shown, shown.length(), caret.val)
  let pfx = caret_prefix()
  let px = ip_measure(pfx, pfx.length())
  let lh = ip_line_height()
  ip_set_cursor_rect(24 + px.to_int(), 22, 1, lh.to_int())
}

///|
/// GTK 的 preedit 光标索引按「字符数」给，这里换成字节偏移
fn preedit_caret_bytes(chars : Int) -> Int {
  let p = preedit.val
  let mut i = 0
  let mut k = 0
  while k < chars && i < p.length() {
    i = i + cp_len(p, i)
    k = k + 1
  }
  i
}

///|
fn on_commit_impl(content : Bytes) -> Unit {
  seen_commit.val = seen_commit.val + 1
  insert_at_caret(content)
}

///|
fn on_preedit_impl(content : Bytes, caret_char : Int, active : Int) -> Unit {
  seen_preedit.val = seen_preedit.val + 1
  preedit.val = content
  preedit_active.val = active != 0 && content.length() > 0
  if content.length() > 0 {
    let cb = preedit_caret_bytes(caret_char)
    notes.val.push(
      (
        "preedit-caret",
        "字符索引 \{caret_char.to_string()} → 字节 \{cb.to_string()} / 共 \{content.length().to_string()} 字节",
      ),
    )
  }
  push_display()
}

///|
/// 未被输入法消费的按键（模式 B 下即我们的编辑键通道）
/// keyval 用 X11 keysym 值：BackSpace 0xff08 Delete 0xffff Left 0xff51
/// Right 0xff53 Home 0xff50 End 0xff57
fn on_key_impl(
  keyval : Int,
  unicode : Int,
  state : Int,
  is_press : Int,
) -> Unit {
  seen_key.val = seen_key.val + 1
  if is_press != 1 {
    ()
  } else if keyval == 0xff08 {
    backspace()
  } else if keyval == 0xffff {
    delete_forward()
  } else if keyval == 0xff51 {
    move_left()
  } else if keyval == 0xff53 {
    move_right()
  } else if keyval == 0xff50 {
    caret.val = 0
    push_display()
  } else if keyval == 0xff57 {
    caret.val = text.val.length()
    push_display()
  } else if unicode > 0x20 {
    insert_at_caret(encode_cp(unicode))
  } else {
    ()
  }
  let _ = state
}

///|
fn on_note_impl(tag : Bytes, msg : Bytes) -> Unit {
  notes.val.push((@utf8.decode_lossy(tag), @utf8.decode_lossy(msg)))
}

///|
fn register_callbacks() -> Unit {
  let k : (Int, Int, Int, Int) -> Unit = fn(a, b, c, d) {
    on_key_impl(a, b, c, d)
  }
  keep_key.val.push(k)
  ip_on_key(
    fn(f : (Int, Int, Int, Int) -> Unit, a : Int, b : Int, c : Int, d : Int) {
      f(a, b, c, d)
    },
    k,
  )
  let cm : (Bytes) -> Unit = fn(b) { on_commit_impl(b) }
  keep_commit.val.push(cm)
  ip_on_commit(fn(f : (Bytes) -> Unit, b : Bytes) { f(b) }, cm)
  let pe : (Bytes, Int, Int) -> Unit = fn(b, c, a) { on_preedit_impl(b, c, a) }
  keep_preedit.val.push(pe)
  ip_on_preedit(
    fn(f : (Bytes, Int, Int) -> Unit, b : Bytes, c : Int, a : Int) {
      f(b, c, a)
    },
    pe,
  )
  let nt : (Bytes, Bytes) -> Unit = fn(t, m) { on_note_impl(t, m) }
  keep_note.val.push(nt)
  ip_on_note(
    fn(f : (Bytes, Bytes) -> Unit, t : Bytes, m : Bytes) { f(t, m) },
    nt,
  )
}

///|
fn report(mode_c : Bool) -> Unit {
  let mode_name = if mode_c {
    "C 可见 GtkEntry"
  } else {
    "B 纯通道 GtkIMContext"
  }
  let im = @env.get_env_var("GTK_IM_MODULE")
  let im_text = match im {
    Some(v) => v
    None => "(未设置)"
  }
  let used = ip_counter(0).to_string()
  let passed = ip_counter(1).to_string()
  let to_mb = ip_counter(6).to_string()
  let got_key = seen_key.val.to_string()
  let nc = ip_counter(2).to_string()
  let nc_mb = seen_commit.val.to_string()
  let ps = ip_counter(4).to_string()
  let pc = ip_counter(3).to_string()
  let pe = ip_counter(5).to_string()
  let pe_mb = seen_preedit.val.to_string()
  let tlen = text.val.length().to_string()
  let ttext = @utf8.decode_lossy(text.val)
  let lh = ip_line_height().to_string()
  println("")
  println("== G0 输入法探针 · 退出汇总 ==")
  println("模式: " + mode_name)
  println("GTK_IM_MODULE = " + im_text)
  println(
    "输入法消费/放行按键 = " +
    used +
    "/" +
    passed +
    "，转给 MoonBit 的按键 = " +
    to_mb +
    "（MoonBit 收到 " +
    got_key +
    "）",
  )
  println("commit：C 侧 " + nc + " 次，MoonBit 收到 " + nc_mb + " 次")
  println(
    "preedit：start/changed/end = " +
    ps +
    "/" +
    pc +
    "/" +
    pe +
    "，MoonBit 收到 " +
    pe_mb +
    " 次",
  )
  println("最终文本（" + tlen + " 字节）= " + ttext)
  println("行高 = " + lh + " px")
  if mode_c {
    let alloc = ip_counter(7).to_string()
    println("GtkEntry 请求高 22 → 实际分配高 " + alloc)
  }
  println("事件流水（最近 40 条）：")
  let n = notes.val.length()
  let from = if n > 40 { n - 40 } else { 0 }
  for i = from; i < n; i = i + 1 {
    let item = notes.val[i]
    println("  [" + item.0 + "] " + item.1)
  }
}

///|
fn main {
  let argv = @env.args()
  let mode_c = argv.length() > 1 && argv[1] == "c"
  let last = argv[argv.length() - 1]
  let smoke = last == "--smoke"
  let ok = ip_init(if mode_c { 1 } else { 0 })
  if ok == 0 {
    println("gtk_init_check 失败（无 X 显示？）")
  } else {
    register_callbacks()
    ip_report_im_module()
    if mode_c {
      let css_text = "entry { color: #eceff4; background-color: #2b2f36; background-image: none; border: 1px solid #4c9ef0; caret-color: #ffffff; font-size: 14px; padding: 0px 4px; min-height: 0px; min-width: 0px; } entry selection { background-color: #3b5f8a; }"
      let css = @utf8.encode(css_text)
      let applied = ip_apply_css(css, css.length())
      let _ = applied
    }
    let seed = @utf8.encode("已有文本 ")
    insert_at_caret(seed)
    let mode_name = if mode_c { "模式 C" } else { "模式 B" }
    println(
      "探针已启动（" +
      mode_name +
      "）：请用输入法打中文，观察 preedit 是否内联、候选窗是否贴在插入符上、Esc 退出",
    )
    if smoke {
      let start = ip_now_ms()
      let mut running = true
      while running && ip_should_quit() == 0 {
        let got = ip_iterate(0)
        let _ = got
        let now = ip_now_ms()
        if now - start > 1500L {
          running = false
        }
      }
    } else {
      while ip_should_quit() == 0 {
        let got = ip_iterate(1)
        let _ = got
      }
    }
    report(mode_c)
  }
}
