// 图标系统白盒测试:全变体清单规模与代表性种类(覆盖各分类)。

test {
  assert_eq(all_icons().length(), 803)
  assert_true(all_icons().contains(YhSearch2))
  assert_true(all_icons().contains(YhDrag))
  assert_true(all_icons().contains(YhCode))
  assert_true(all_icons().contains(YhCode))
  assert_true(all_icons().contains(YhBranches))
  assert_true(all_icons().contains(YhMail1))
  assert_true(all_icons().contains(YhDatabase))
  assert_true(all_icons().contains(YhPieChart))
  // 清单无重复
  let mut uniq = 0
  for i, a in all_icons() {
    for j, b in all_icons() {
      if j > i && a == b {
        uniq += 1
      }
    }
  }
  assert_eq(uniq, 0)
}
