test "define_class + lookup_class：注册与回读" {
  reset_class_registry()
  let s = style(padding_left=8.0, padding_right=8.0, cursor=@widget.CURSOR_HAND)
  define_class("btn-base", s)
  match lookup_class("btn-base") {
    Some(c) => {
      assert_eq(c.name, "btn-base")
      assert_true(c.style.cursor == Some(@widget.CURSOR_HAND))
    }
    None => assert_eq(true, false)
  }
  reset_class_registry()
}

test "class_of：按名数组解析、未注册跳过" {
  reset_class_registry()
  define_class("a", style(padding_left=10.0))
  define_class("b", style(padding_top=4.0))
  let arr = class_of(["a", "missing", "b"])
  assert_eq(arr.length(), 2)
  reset_class_registry()
}

test "同名覆盖：后 define 生效" {
  reset_class_registry()
  define_class("x", style(padding_left=1.0))
  define_class("x", style(padding_left=99.0))
  match lookup_class("x") {
    Some(c) => assert_true(c.style.padding_left == Some(99.0))
    None => assert_eq(true, false)
  }
  reset_class_registry()
}

test "registered_classes 列出已注册名" {
  reset_class_registry()
  define_class("p", style())
  define_class("q", style())
  let names = registered_classes()
  assert_true(names.length() == 2)
  reset_class_registry()
}
