///|
test "argb_hex 基本转换" {
  inspect(@yue.argb_hex(255, 0xD4, 0x6A, 0x6A), content="#ffd46a6a")
}

///|
test "argb_hex 通道为零" {
  inspect(@yue.argb_hex(255, 0, 0, 0), content="#ff000000")
}

///|
test "rgb_hex 默认不透明" {
  inspect(@yue.rgb_hex(255, 255, 255), content="#ffffffff")
}

///|
test "rgb_hex 与 drawing 示例的色块矩阵一致" {
  // drawing 示例 example1：i=j=0 时为纯黄 (255,255,0)
  inspect(@yue.rgb_hex(255, 255, 0), content="#ffffff00")
}

///|
test "parse_hex 全式/短式/ARGB/无#/非法" {
  debug_inspect(@yue.parse_hex("#009688"), content="Some((0, 150, 136))")
  debug_inspect(@yue.parse_hex("009688"), content="Some((0, 150, 136))")
  debug_inspect(@yue.parse_hex("#09C"), content="Some((0, 153, 204))")
  debug_inspect(@yue.parse_hex("#ffD46A6A"), content="Some((212, 106, 106))")
  debug_inspect(@yue.parse_hex("#12345"), content="None")
  debug_inspect(@yue.parse_hex("#12g456"), content="None")
}

///|
test "rgb_to_hsl 与 from_hsl 往返一致" {
  debug_inspect(@yue.rgb_to_hsl(255, 0, 0), content="(0, 1, 0.5)")
  debug_inspect(
    @yue.rgb_to_hsl(0, 150, 136),
    content="(174.4, 1, 0.29411764705882354)",
  )
  // 派生 → 解析往返:色值回到原串
  let (r, g, b) = @yue.parse_hex("#2D68C4").unwrap()
  let (h, s, l) = @yue.rgb_to_hsl(r, g, b)
  inspect(@yue.from_hsl(h, s, l), content="#2d68c4")
}

///|
test "mix_hex / lighten_hex / darken_hex" {
  // 向白混 50%:两端线性插值
  inspect(@yue.mix_hex("#000000", "#FFFFFF", 0.5), content="#808080")
  inspect(@yue.mix_hex("#009688", "#FFFFFF", 0.88), content="#1fa396")
  inspect(@yue.lighten_hex("#009688", 0.1), content="#00c9b6")
  inspect(@yue.darken_hex("#009688", 0.1), content="#00635a")
  // 非法输入原样返回
  inspect(@yue.mix_hex("oops", "#FFFFFF", 0.5), content="oops")
  inspect(@yue.lighten_hex("oops", 0.1), content="oops")
}
