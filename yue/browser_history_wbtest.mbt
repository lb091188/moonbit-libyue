// 浏览器历史白盒测试：纯逻辑层（时间换算 / ASCII 折叠匹配 / 状态名 /
// 截断排序 / urls 与 downloads 行解析 / 目录拼装 / profile 候选）语义。
// 真实 History 库的读取不在测试内（依赖宿主浏览器数据，冒烟另行执行）。

///|
test "bh_chrome_time_to_unix_ms：基准换算/未知值" {
  // 1601-01-01 00:00:00 UTC（Chrome 纪元）→ Unix 0
  assert_eq(bh_chrome_time_to_unix_ms(11644473600000000L), 0L)
  // 1970-01-01 后 1 秒
  assert_eq(bh_chrome_time_to_unix_ms(11644473601000000L), 1000L)
  // 实测样本：13435769563030519 微秒 → 2026-10-06T14:12:43.030Z
  assert_eq(bh_chrome_time_to_unix_ms(13435769563030519L), 1791295963030L)
  // 微秒以下截断
  assert_eq(bh_chrome_time_to_unix_ms(11644473600001999L), 1L)
  // 未知时间（0 / 负值）
  assert_eq(bh_chrome_time_to_unix_ms(0L), 0L)
  assert_eq(bh_chrome_time_to_unix_ms(-5L), 0L)
}

///|
test "bh_lower_ascii：ASCII 折叠/非 ASCII 保留" {
  assert_eq(bh_lower_ascii("Hello World 12"), "hello world 12")
  assert_eq(bh_lower_ascii("ABC-Z"), "abc-z")
  // 非 ASCII（含中文）原样保留
  assert_eq(bh_lower_ascii("抖音 DouYin"), "抖音 douyin")
  assert_eq(bh_lower_ascii(""), "")
}

///|
test "bh_contains_fold：子串/大小写/空关键词" {
  assert_true(bh_contains_fold("https://Example.COM/a", "example.com"))
  assert_true(bh_contains_fold("ABC", "b"))
  assert_false(bh_contains_fold("abc", "x"))
  // 空关键词匹配一切
  assert_true(bh_contains_fold("", ""))
  assert_true(bh_contains_fold("abc", ""))
  assert_false(bh_contains_fold("", "a"))
  // 非 ASCII 关键词按原样精确匹配（不折叠）
  assert_true(bh_contains_fold("抖音-记录美好生活", "抖音"))
  assert_false(bh_contains_fold("douyin", "抖音"))
}

///|
test "bh_download_state_name：已知状态/未知值" {
  assert_eq(bh_download_state_name(0L), "进行中")
  assert_eq(bh_download_state_name(1L), "完成")
  assert_eq(bh_download_state_name(2L), "已取消")
  assert_eq(bh_download_state_name(3L), "中断")
  assert_eq(bh_download_state_name(4L), "中断")
  assert_eq(bh_download_state_name(9L), "未知(9)")
}

///|
test "bh_take：全收边界/截断" {
  let src = [1, 2, 3, 4, 5]
  debug_inspect(bh_take(src, 0), content="[1, 2, 3, 4, 5]") // <=0 全收
  debug_inspect(bh_take(src, -1), content="[1, 2, 3, 4, 5]")
  debug_inspect(bh_take(src, 5), content="[1, 2, 3, 4, 5]") // 恰等全收
  debug_inspect(bh_take(src, 99), content="[1, 2, 3, 4, 5]") // 超出全收
  debug_inspect(bh_take(src, 3), content="[1, 2, 3]")
  debug_inspect(bh_take(src, 1), content="[1]")
  // 空数组
  let empty : Array[Int] = []
  debug_inspect(bh_take(empty, 3), content="[]")
}

///|
test "bh_sort_history：时间降序/并列按 url" {
  let items = [
    {
      url: "https://b.example/",
      title: "b",
      visit_count: 1,
      last_visit_time: 100L,
    },
    {
      url: "https://a.example/",
      title: "a",
      visit_count: 2,
      last_visit_time: 300L,
    },
    {
      url: "https://c.example/",
      title: "c",
      visit_count: 3,
      last_visit_time: 100L,
    },
  ]
  let sorted = bh_sort_history(items)
  assert_eq(sorted[0].url, "https://a.example/")
  // 时间并列（100L）按 url 升序：b 在 c 前
  assert_eq(sorted[1].url, "https://b.example/")
  assert_eq(sorted[2].url, "https://c.example/")
  // 入参不被修改
  assert_eq(items[0].url, "https://b.example/")
}

///|
test "bh_sort_downloads：开始时间降序/并列按路径" {
  let items = [
    { target_path: "/tmp/b", received_bytes: 1L, total_bytes: 1L, start_time: 50L, end_time: 60L, state: 1L },
    { target_path: "/tmp/a", received_bytes: 2L, total_bytes: 2L, start_time: 90L, end_time: 95L, state: 1L },
    { target_path: "/tmp/c", received_bytes: 3L, total_bytes: 3L, start_time: 50L, end_time: 70L, state: 1L },
  ]
  let sorted = bh_sort_downloads(items)
  assert_eq(sorted[0].target_path, "/tmp/a")
  assert_eq(sorted[1].target_path, "/tmp/b")
  assert_eq(sorted[2].target_path, "/tmp/c")
}

///|
test "bh_parse_history_row：正常/隐藏过滤/列数不足" {
  let mk = fn(hidden : Int64) -> Array[@moonsqlitefile.Value] {
    [
      @moonsqlitefile.Null, // id：INTEGER PRIMARY KEY 磁盘存 Null
      @moonsqlitefile.Text("https://www.example.com/"),
      @moonsqlitefile.Text("示例站"),
      @moonsqlitefile.Integer(7L),
      @moonsqlitefile.Integer(1L),
      @moonsqlitefile.Integer(13435769563030519L),
      @moonsqlitefile.Integer(hidden),
    ]
  }
  match bh_parse_history_row(mk(0L)) {
    Some(item) => {
      assert_eq(item.url, "https://www.example.com/")
      assert_eq(item.title, "示例站")
      assert_eq(item.visit_count, 7)
      assert_eq(item.last_visit_time, 1791295963030L)
    }
    None => fail("正常行应解析成功")
  }
  // hidden=1（重定向等）不收
  assert_true(bh_parse_history_row(mk(1L)) is None)
  // 列数不足
  assert_true(bh_parse_history_row([
      @moonsqlitefile.Null,
      @moonsqlitefile.Text("u"),
    ]) is None)
}

///|
test "bh_parse_download_row：正常/列数不足" {
  let values = [
    @moonsqlitefile.Null, // id
    @moonsqlitefile.Text("guid"),
    @moonsqlitefile.Text("/tmp/part.crdownload"),
    @moonsqlitefile.Text("/home/u/下载/a.png"),
    @moonsqlitefile.Integer(13435419645089193L), // start_time
    @moonsqlitefile.Integer(575469L), // received_bytes
    @moonsqlitefile.Integer(575469L), // total_bytes
    @moonsqlitefile.Integer(1L), // state
    @moonsqlitefile.Integer(0L), // danger_type
    @moonsqlitefile.Integer(0L), // interrupt_reason
    @moonsqlitefile.Blob(b""), // hash
    @moonsqlitefile.Integer(13435419646000000L), // end_time
  ]
  match bh_parse_download_row(values) {
    Some(d) => {
      assert_eq(d.target_path, "/home/u/下载/a.png")
      assert_eq(d.received_bytes, 575469L)
      assert_eq(d.total_bytes, 575469L)
      assert_eq(d.start_time, 13435419645089L - 11644473600000L)
      assert_eq(d.end_time, 13435419646000L - 11644473600000L)
      assert_eq(d.state, 1L)
      assert_eq(bh_download_state_name(d.state), "完成")
    }
    None => fail("正常行应解析成功")
  }
  // 列数不足（downloads 需至少 12 列）
  assert_true(bh_parse_download_row([
      @moonsqlitefile.Null,
      @moonsqlitefile.Text("guid"),
    ]) is None)
}

///|
test "bh_config_root：XDG 优先/回退 HOME/都缺" {
  assert_eq(bh_config_root(Some("/xdg"), Some("/home/u")), Some("/xdg"))
  // XDG 为空串回退 HOME
  assert_eq(bh_config_root(Some(""), Some("/home/u")), Some("/home/u/.config"))
  assert_eq(bh_config_root(None, Some("/home/u")), Some("/home/u/.config"))
  assert_eq(bh_config_root(None, None), None)
  assert_eq(bh_config_root(Some(""), None), None)
}

///|
test "bh_profile_candidates：Default 在前/连续编号/容量" {
  let cands = bh_profile_candidates()
  assert_eq(cands[0], "Default")
  assert_eq(cands[1], "Profile 1")
  assert_eq(cands[2], "Profile 2")
  assert_eq(cands.length(), 1 + bh_profile_probe_max)
  assert_eq(cands[cands.length() - 1], "Profile \{bh_profile_probe_max}")
}
