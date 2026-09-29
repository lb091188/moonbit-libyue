// 图标系统白盒测试:全变体清单规模与代表性种类(覆盖各分类)。

test {
  assert_eq(all_icons().length(), 803)
  assert_true(all_icons().contains(Search2))
  assert_true(all_icons().contains(Drag))
  assert_true(all_icons().contains(Code))
  assert_true(all_icons().contains(Code))
  assert_true(all_icons().contains(Branches))
  assert_true(all_icons().contains(Mail1))
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

test {
  // 路径数据与索引、清单三者对齐:kind_index 是 all_icons 序的双射,
  // 每条定点路径串非空且以 M 开头(M 命令不可缺,首点决定子路径起点)
  assert_eq(icon_path_data.length(), all_icons().length())
  for i, k in all_icons() {
    assert_eq(kind_index(k), i)
    let d = icon_path_data[i]
    assert_true(d.length() > 10)
    assert_eq(d.unsafe_get(0).to_int(), 77) // 'M'
  }
  // 解释器冒烟:首图标路径串逐字符可解析到底(无悬异数字/未知命令崩解)
  let mut letters = 0
  let d = icon_path_data[0]
  for i in 0..<d.length() {
    let c = d.unsafe_get(i).to_int()
    if c == 77 || c == 76 || c == 67 || c == 90 {
      letters += 1
    } else {
      assert_true((c >= 48 && c <= 57) || c == 44 || c == 45)
    }
  }
  assert_true(letters >= 2)
}
