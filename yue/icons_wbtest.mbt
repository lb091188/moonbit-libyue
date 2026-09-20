// 图标系统白盒测试:全变体清单规模与代表性种类(覆盖各分类)。

test {
  assert_eq(all_icons().length(), 136)
  assert_true(all_icons().contains(Search))
  assert_true(all_icons().contains(Grip))
  assert_true(all_icons().contains(FileCode))
  assert_true(all_icons().contains(Terminal))
  assert_true(all_icons().contains(GitBranch))
  assert_true(all_icons().contains(Mail))
  assert_true(all_icons().contains(Database))
  assert_true(all_icons().contains(PieChart))
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
