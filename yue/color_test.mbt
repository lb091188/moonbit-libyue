///|
test "argb_hex 基本转换" {
  inspect(argb_hex(255, 0xD4, 0x6A, 0x6A), content="#ffd46a6a")
}

///|
test "argb_hex 通道为零" {
  inspect(argb_hex(255, 0, 0, 0), content="#ff000000")
}

///|
test "rgb_hex 默认不透明" {
  inspect(rgb_hex(255, 255, 255), content="#ffffffff")
}

///|
test "rgb_hex 与 drawing 示例的色块矩阵一致" {
  // drawing 示例 example1：i=j=0 时为纯黄 (255,255,0)
  inspect(rgb_hex(255, 255, 0), content="#ffffff00")
}
