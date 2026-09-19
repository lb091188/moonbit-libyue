// 图标系统白盒测试:全变体清单规模与代表性种类。

test {
  assert_eq(all_icons().length(), 37)
  assert_true(all_icons().contains(Search))
  assert_true(all_icons().contains(Grip))
}
