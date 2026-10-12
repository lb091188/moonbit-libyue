// W20f 图标加载：扩展名判定与格式分派的纯函数回归。
// 只钉「路径 → 格式」这一段；真正的解码/HICON 建法由平台桩负责，其运行时
// 回证走纯 C 探针 `experiment/icon_probe/icon_backend_probe.c`（真机跑）。

///|
test "icon_ext: 常见扩展名取小写、不含点" {
  assert_eq(icon_ext_of("a/b/c.ico"), "ico")
  assert_eq(icon_ext_of("C:\\icons\\App.PNG"), "png")
  assert_eq(icon_ext_of("x.jpeg"), "jpeg")
}

///|
test "icon_ext: 无扩展名与尾点给空串" {
  assert_eq(icon_ext_of("noext"), "")
  assert_eq(icon_ext_of("trailing."), "")
  assert_eq(icon_ext_of(""), "")
}

///|
test "icon_ext: 目录名带点不算扩展名" {
  // 点在尾段之前（被 '/' 拦住）→ 无扩展名
  assert_eq(icon_ext_of("/home/u.name/icon"), "")
  assert_eq(icon_ext_of("dir.v2/logo.svg"), "svg")
}

///|
test "icon_format_of: 五种已知格式 + Other" {
  assert_true(icon_format_of("a.ico") is Ico)
  assert_true(icon_format_of("a.BMP") is Bmp)
  assert_true(icon_format_of("a.Png") is Png)
  assert_true(icon_format_of("a.jpg") is Jpeg)
  assert_true(icon_format_of("a.JPEG") is Jpeg)
  assert_true(icon_format_of("a.GIF") is Gif)
  assert_true(icon_format_of("a.svg") is Other)
  assert_true(icon_format_of("noext") is Other)
}

///|
test "icon: 句柄 0 视同不可用" {
  let ic : Icon = { handle: 0 }
  assert_false(ic.is_valid())
  // free 幂等：无效句柄上再释放不改变状态
  ic.free()
  assert_false(ic.is_valid())
}

///|
test "icon_from_bgra: 尺寸非正或像素不足给 None" {
  let px = FixedArray::make(4 * 4 * 4, b'\x00')
  assert_true(icon_from_bgra(px, 0, 4) is None)
  assert_true(icon_from_bgra(px, 4, 0) is None)
  assert_true(icon_from_bgra(px, 8, 8) is None) // 只有 4x4 的像素
}
