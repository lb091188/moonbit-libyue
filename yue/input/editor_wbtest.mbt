// 编辑内核的语义回归：一切下标按 UTF-8 字节，且 caret 不落续字节。

test "设置与取回文本，caret 落在末尾边界" {
  let ed = Editor::new()
  ed.set_text("中文ab")
  assert_eq(ed.get_text(), "中文ab")
  assert_eq(ed.byte_len(), 8) // 中文 2×3 + ab 2
  assert_eq(ed.caret_pos(), 8)
}

test "退格删整个汉字，不留半字" {
  let ed = Editor::new()
  ed.set_text("汉a")
  ed.backspace()
  assert_eq(ed.get_text(), "汉")
  ed.backspace()
  assert_eq(ed.get_text(), "")
  assert_eq(ed.caret_pos(), 0)
}

test "手工把 caret 摆到选区上再插入即替换" {
  let ed = Editor::new()
  ed.set_text("hello world")
  ed.select_range(0, 5)
  assert_eq(ed.selection(), Some((0, 5)))
  let n = ed.insert_text("abcde")
  assert_eq(n, 5)
  assert_eq(ed.get_text(), "abcde world")
  assert_eq(ed.selection(), None)
}

test "词跳转：ctrl+left/right 按词而非字符" {
  let ed = Editor::new()
  ed.set_text("foo bar baz")
  // caret 在末尾（11）
  ed.move_caret(-1, 1, false)
  assert_eq(ed.caret_pos(), 8) // 跳过 " baz" 到 baz 词首
  ed.move_caret(-1, 1, false)
  assert_eq(ed.caret_pos(), 4)
  ed.move_caret(1, 1, false)
  assert_eq(ed.caret_pos(), 7) // 词右移停在词尾（'r' 之后、空格之前）
}

test "shift 移动延长选区、不带 shift 折叠" {
  let ed = Editor::new()
  ed.set_text("abcd")
  ed.move_caret(-1, 2, false) // home
  assert_eq(ed.caret_pos(), 0)
  ed.move_caret(1, 0, true) // shift+right
  assert_eq(ed.selection(), Some((0, 1)))
  ed.move_caret(1, 0, false)
  assert_eq(ed.selection(), None)
  assert_eq(ed.caret_pos(), 2)
}

test "copy 不动状态、cut 删选区、粘贴走内核缓存" {
  let ed = Editor::new()
  ed.set_text("one two")
  ed.select_range(4, 7)
  assert_eq(ed.copy(), "two")
  assert_eq(ed.get_text(), "one two") // copy 不改文本
  assert_eq(ed.cut(), "two")
  assert_eq(ed.get_text(), "one ")
  ed.paste_text(ed.clip_text())
  assert_eq(ed.get_text(), "one two")
}

test "undo 与 redo 往返一致" {
  let ed = Editor::new()
  ed.set_text("start")
  let _ = ed.insert_text("-more")
  assert_eq(ed.get_text(), "start-more")
  assert_eq(ed.undo(), true)
  assert_eq(ed.get_text(), "start")
  assert_eq(ed.can_undo(), false)
  assert_eq(ed.redo(), true)
  assert_eq(ed.get_text(), "start-more")
}

test "handle_key：打字、退格、方向、Tab 归属" {
  let ed = Editor::new()
  assert_eq(ed.handle_key('a'.to_int(), 0), true)
  assert_eq(ed.handle_key('b'.to_int(), 0), true)
  assert_eq(ed.get_text(), "ab")
  assert_eq(ed.handle_key(@core.KS_LEFT, 0), true)
  assert_eq(ed.caret_pos(), 1)
  assert_eq(ed.handle_key(@core.KS_BACKSPACE, 0), true)
  assert_eq(ed.get_text(), "b")
  // Tab 属焦点导航，内核不消费
  assert_eq(ed.handle_key(@core.KS_TAB, 0), false)
  assert_eq(ed.handle_key(@core.KS_ESCAPE, 0), false)
}

test "handle_key：Ctrl+A 全选、Ctrl+Z 撤销、Ctrl+箭头按词" {
  let ed = Editor::new()
  ed.set_text("aa bb")
  assert_eq(ed.handle_key('a'.to_int(), @core.MOD_CTRL), true)
  assert_eq(ed.selection(), Some((0, 5)))
  // 全选状态下再打字符即替换
  assert_eq(ed.handle_key('x'.to_int(), 0), true)
  assert_eq(ed.get_text(), "x")
  assert_eq(ed.handle_key('z'.to_int(), @core.MOD_CTRL), true)
  assert_eq(ed.get_text(), "aa bb")
  ed.move_caret(1, 2, false) // 先跳到文末（5）
  assert_eq(ed.handle_key(@core.KS_LEFT, @core.MOD_CTRL), true)
  assert_eq(ed.caret_pos(), 3) // 按词回退到 "bb" 词首
}

test "区间取值不切碎多字节且越界钳制" {
  let ed = Editor::new()
  ed.set_text("αβγ") // 每个 2 字节
  assert_eq(ed.byte_len(), 6)
  // 对齐方向：起点回退、终点前进——宁可多含一个码点，也不返回半字
  assert_eq(ed.get_text_in_range(1, 3), "αβ")
  assert_eq(ed.get_text_in_range(-5, 999), "αβγ")
  assert_eq(ed.get_text_in_range(4, 2), "")
}
