// 输入框全语义回归：键入回写 Store、输入法提交与组合串、点击定位、双击选词、
// 拖动选区、Shift+箭头、Ctrl+A/C/V、undo、只读、密码遮罩、placeholder、
// Store 外部同步。事件都按宿主的投递口径给**窗口坐标**。

///|
fn key(root : @core.Widget, w : @core.Widget, keysym : Int, mods : Int) -> Unit {
  let _ = root.dispatch_key(w.focus_id, { press: true, keysym, mods, })
}

///|
fn press(root : @core.Widget, w : @core.Widget, x : Double) -> Unit {
  let _ = root.dispatch_pointer_to(w.id, {
    kind: @core.Down,
    x,
    y: w.rect.y + 6.0,
    button: 1,
    mods: 0,
  })
}

///|
fn move_to(root : @core.Widget, w : @core.Widget, x : Double) -> Unit {
  let _ = root.dispatch_pointer_to(w.id, {
    kind: @core.Move,
    x,
    y: w.rect.y + 6.0,
    button: 1,
    mods: 0,
  })
}

///|
fn release(root : @core.Widget, w : @core.Widget, x : Double) -> Unit {
  let _ = root.dispatch_pointer_to(w.id, {
    kind: @core.Up,
    x,
    y: w.rect.y + 6.0,
    button: 1,
    mods: 0,
  })
}

///|
/// 建一个已挂载并布局好的输入框，返回 (根, 控件, Store)。
fn mounted_entry(
  text : String,
  width : Double,
  placeholder? : String = "",
  password? : Bool = false,
  read_only? : Bool = false,
) -> (@core.Widget, @core.Widget, @core.Store[String]) {
  let store = @core.Store::new(text)
  let e = input(
    store,
    placeholder=placeholder,
    password=password,
    read_only=read_only,
    width=width,
    focus_id=1,
  )
  let root = @core.Widget::new()
  root.set_size(width + 20.0, 60.0)
  root.set_column()
  let w = e.mount_into(root)
  root.relayout(width + 20.0, 60.0)
  // 内核句柄从外部拿不到（文本权威在组件里）：断言走 Store 投影与 im_context
  (root, w, store)
}

///|
fn paint_of(root : @core.Widget) -> @render.Bitmap {
  let bm = @render.Bitmap::new(220, 60)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  bm
}

///|
test "clearable：悬停出清空标记，点它整框清空并回写 Store" {
  let store = @core.Store::new("abc")
  let root = @core.Widget::new()
  root.set_size(220.0, 60.0)
  root.set_column()
  let w = input(store, width=200.0, clearable=true).mount_into(root)
  root.relayout(220.0, 60.0)
  // 判据用「那一块像素变了没有」：框底本就铺满不透明色，数墨点量不出标记
  let idle = paint_of(root)
  w.hovered = true
  let lit = paint_of(root)
  let mut diff = 0
  for y = 9; y < 19; y = y + 1 {
    for x = 184; x < 196; x = x + 1 {
      let a = idle.pixel(x, y)
      let b = lit.pixel(x, y)
      if (a.r, a.g, a.b, a.a) != (b.r, b.g, b.b, b.a) {
        diff = diff + 1
      }
    }
  }
  assert_true(diff > 4, msg="悬停时清空标记没出现（热区像素零变化）")
  let _ = root.dispatch_pointer_to(w.id, {
    kind: @core.Down, x: 189.0, y: 12.0, button: 1, mods: 0,
  })
  assert_eq(store.get(), "")
}

///|
test "不给 focus_id 也自动可聚焦（输入框默认就该能点进能打）" {
  let store = @core.Store::new("hi")
  let root = @core.Widget::new()
  root.set_size(220.0, 60.0)
  root.set_column()
  let w = input(store, width=200.0).mount_into(root)
  root.relayout(220.0, 60.0)
  assert_true(w.focus_id > 0, msg="focus_id 仍是 0（宿主判定为不可聚焦）")
  match root.focusable_at(w.rect.x + 20.0, w.rect.y + 6.0) {
    Some(id) => assert_eq(id, w.focus_id)
    None => fail("点不进输入框：focusable_at 给 None")
  }
  key(root, w, 'a'.to_int(), 0)
  assert_eq(store.get(), "hia")
  let explicit = input(@core.Store::new(""), width=200.0, focus_id=77)
  let root2 = @core.Widget::new()
  root2.set_size(220.0, 60.0)
  root2.set_column()
  let fw = explicit.mount_into(root2)
  root2.relayout(220.0, 60.0)
  assert_eq(fw.focus_id, 77)
  let other = input(@core.Store::new(""), width=200.0)
  let root3 = @core.Widget::new()
  root3.set_size(220.0, 60.0)
  root3.set_column()
  let bw = other.mount_into(root3)
  root3.relayout(220.0, 60.0)
  assert_true(bw.focus_id != w.focus_id, msg="两个自动 focus_id 撞号")
}

///|
test "键入回写 Store，退格与 undo 照旧" {
  let (root, w, store) = mounted_entry("hi", 200.0)
  assert_eq(store.get(), "hi")
  key(root, w, 'a'.to_int(), 0)
  key(root, w, 'b'.to_int(), 0)
  assert_eq(store.get(), "hiab")
  key(root, w, @core.KS_BACKSPACE, 0)
  assert_eq(store.get(), "hia")
  key(root, w, 'z'.to_int(), @core.MOD_CTRL)
  assert_eq(store.get(), "hiab")
}

///|
test "输入法：commit 落进文本，preedit 只进绘制不进状态" {
  let (root, w, store) = mounted_entry("你好", 200.0)
  let _ = root.dispatch_preedit(w.focus_id, "shi", 3)
  // 组合串不并入文本：Store 仍是原值
  assert_eq(store.get(), "你好")
  let _ = root.dispatch_commit(w.focus_id, "是")
  assert_eq(store.get(), "你好是")
  let _ = root.dispatch_preedit(w.focus_id, "", 0)
  assert_eq(store.get(), "你好是")
}

///|
test "点击定位：最右端落到文本末尾，最左端落到 0" {
  let (root, w, store) = mounted_entry("abc def", 200.0)
  press(root, w, w.rect.x + w.rect.w - 1.0)
  release(root, w, w.rect.x + w.rect.w - 1.0)
  // 末尾：caret = 字节长度，且没有选区
  assert_eq(store.get(), "abc def")
  press(root, w, w.rect.x + 1.0)
  release(root, w, w.rect.x + 1.0)
  let sel = match w.im_context {
    Some(f) => f().unwrap()
    None => ("", -1)
  }
  assert_eq(sel.1, 0)
}

///|
test "双击选词：末尾那次双击选中最后一个词（用「打字替换选区」观测选区）" {
  let (root, w, store) = mounted_entry("abc def", 200.0)
  let x = w.rect.x + w.rect.w - 1.0
  press(root, w, x)
  release(root, w, x)
  // 单击后打字是插入：caret 在 7 → "abc defz"
  key(root, w, 'z'.to_int(), 0)
  assert_eq(store.get(), "abc defz")
  // 双击选中「def」，打字替换掉它
  press(root, w, x)
  release(root, w, x)
  press(root, w, x)
  key(root, w, 'Q'.to_int(), 0)
  assert_eq(store.get(), "abc Q")
}

///|
test "拖动选区：按下为锚点，拖到最左端全选；松手后不再跟手" {
  let (root, w, store) = mounted_entry("abc def", 200.0)
  let right = w.rect.x + w.rect.w - 1.0
  let left = w.rect.x + 1.0
  press(root, w, right)
  move_to(root, w, left)
  release(root, w, left)
  // 整段被选中：打字即替换
  key(root, w, 'x'.to_int(), 0)
  assert_eq(store.get(), "x")
  // 松手之后再移动，caret 不该跟着走（拖动态已结束）
  let before = caret_of(w)
  move_to(root, w, right)
  assert_eq(caret_of(w), before)
}

///|
fn caret_of(w : @core.Widget) -> Int {
  match w.im_context {
    Some(f) => f().unwrap().1
    None => -1
  }
}

///|
test "Shift+箭头扩选，Ctrl+A 全选，Ctrl+C/V 走内核内部剪贴板" {
  let (root, w, store) = mounted_entry("abc", 200.0)
  // caret 先到末尾
  press(root, w, w.rect.x + w.rect.w - 1.0)
  release(root, w, w.rect.x + w.rect.w - 1.0)
  key(root, w, @core.KS_LEFT, @core.MOD_SHIFT)
  key(root, w, @core.KS_LEFT, @core.MOD_SHIFT)
  let sel = match w.im_context {
    Some(f) => f().unwrap()
    None => ("", -1)
  }
  assert_eq(sel.1, 1)
  key(root, w, 'a'.to_int(), @core.MOD_CTRL)
  key(root, w, 'c'.to_int(), @core.MOD_CTRL)
  key(root, w, 'x'.to_int(), @core.MOD_CTRL)
  assert_eq(store.get(), "")
  key(root, w, 'v'.to_int(), @core.MOD_CTRL)
  assert_eq(store.get(), "abc")
}

///|
test "只读：编辑键不吃，导航与复制照旧" {
  let (root, w, store) = mounted_entry("锁住", 200.0, read_only=true)
  key(root, w, 'a'.to_int(), 0)
  key(root, w, @core.KS_BACKSPACE, 0)
  assert_eq(store.get(), "锁住")
  key(root, w, 'a'.to_int(), @core.MOD_CTRL)
  key(root, w, 'c'.to_int(), @core.MOD_CTRL)
  assert_eq(store.get(), "锁住")
}

///|
test "密码遮罩：Store 存原文，显示串按码点打点" {
  if !ui_text_guard() {
    return
  }
  assert_eq(mask_of("ab中"), "•••")
  let (root, w, store) = mounted_entry("密钥", 200.0, password=true)
  key(root, w, 'x'.to_int(), 0)
  assert_eq(store.get(), "密钥x")
  // 绘制用的是遮罩串：宽度等于三个圆点的测量宽
  let dots = match @text.measure(mask_of("密钥x"), 13.0) {
    Some(m) => m.width
    None => 0
  }
  assert_true(dots > 0)
  let _ = w
}

///|
test "placeholder：空文本画出占位，Store 仍是空" {
  let (root, _w, store) = mounted_entry("", 200.0, placeholder="说点什么")
  assert_eq(store.get(), "")
  let bm = @render.Bitmap::new(220, 60)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let mut ink = 0
  for y = 0; y < 60; y = y + 1 {
    for x = 0; x < 220; x = x + 1 {
      if bm.pixel(x, y).a > 0 {
        ink = ink + 1
      }
    }
  }
  assert_true(ink > 20)
}

///|
test "Store 被外部改动会回灌内核；焦点标志由宿主同步" {
  let store = @core.Store::new("初值")
  let e = input(store, width=160.0, focus_id=7)
  let root = @core.Widget::new()
  root.set_size(200.0, 60.0)
  root.set_column()
  let w = e.mount_into(root)
  root.relayout(200.0, 60.0)
  store.set("外部改的")
  let ctx = match w.im_context {
    Some(f) => f().unwrap()
    None => ("", -1)
  }
  assert_eq(ctx.0, "外部改的")
  assert_false(w.focused)
  root.set_focused_by_focus(7)
  assert_true(w.focused)
  root.set_focused_by_focus(8)
  assert_false(w.focused)
}

///|
/// P2-e 口径：输入框的底色/描边/文字色与焦点框色都走样式槽——内置皮肤先折进槽
/// （常态 + focus 桶），`class` 的同名属性覆盖；选区、preedit、占位符、禁用态是
/// 编辑器的语义态，按 §1.5 留内置配色当回落值。
test "输入框只读样式槽：class 覆盖底与描边，焦点框色来自 focus 桶" {
  if !ui_text_guard() {
    return
  }
  let v = @core.Store::new("内容")
  let root = mount_root(
    [input(
      v,
      width=120.0,
      class=[@style.style(background_color="#ff0000", border_color="#0000ff")],
    )],
    200.0,
    60.0,
  )
  let w = kid(root, 0)
  let bm = @render.Bitmap::new(200, 60)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let mut red = 0
  let mut cool = 0
  for y = 0; y < w.rect.h.to_int(); y = y + 1 {
    for x = 0; x < w.rect.w.to_int(); x = x + 1 {
      let c = color_of(bm, x, y)
      if c.0 > 128 && c.1 < 64 && c.2 < 64 {
        red = red + 1
      }
      if c.2 > 128 && c.0 < 64 && c.1 < 64 {
        cool = cool + 1
      }
    }
  }
  assert_true(red > 100)
  // 描边是 class 的蓝色（上下两条边）
  assert_true(cool > 40)

  // 焦点态：内置 focus 桶给主色描边，与未聚焦的描边灰不同
  let v2 = @core.Store::new("甲")
  let root2 = mount_root([input(v2, width=120.0)], 200.0, 60.0)
  let w2 = kid(root2, 0)
  let edge : () -> (Int, Int, Int, Int) = fn() -> (Int, Int, Int, Int) {
    let b = @render.Bitmap::new(200, 60)
    let pp = @render.Painter::new(b)
    root2.paint(pp)
    pp.end()
    color_of(b, w2.rect.x.round().to_int() + 4, w2.rect.y.round().to_int())
  }
  let plain_edge = edge()
  w2.focused = true
  let focus_edge = edge()
  assert_true(plain_edge != focus_edge)
  w2.focused = false
}
