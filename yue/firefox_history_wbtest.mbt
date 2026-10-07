// Firefox 历史白盒测试：时间换算（µs → ms，Firefox 的 Unix 纪元）、
// INI 解析（profiles.ini 的 Path= 与 IsRelative 组合）、路径拼装、
// moz_places 行解析（公开 schema 列序、hidden 过滤、列数不足）。样例
// 取自 Firefox profiles.ini 与 places.sqlite 的公开 schema（本机未安装
// Firefox，端到端用例仅在探测到 places.sqlite 的环境执行，否则跳过）。

///|
test "ffx_time_to_unix_ms：基准换算/截断/未知值" {
  // 微秒 → 毫秒（截断）
  assert_eq(ffx_time_to_unix_ms(1791295963030519L), 1791295963030L)
  assert_eq(ffx_time_to_unix_ms(1791295963030599L), 1791295963030L)
  assert_eq(ffx_time_to_unix_ms(1000L), 1L)
  assert_eq(ffx_time_to_unix_ms(999L), 0L)
  assert_eq(ffx_time_to_unix_ms(1L), 0L)
  // 未知时间（0 / 负值）
  assert_eq(ffx_time_to_unix_ms(0L), 0L)
  assert_eq(ffx_time_to_unix_ms(-1L), 0L)
}

///|
test "ffx_trim：首尾空白/空白串" {
  assert_eq(ffx_trim("  Path  "), "Path")
  assert_eq(ffx_trim("\t a b \r\n"), "a b")
  assert_eq(ffx_trim(""), "")
  assert_eq(ffx_trim("   "), "")
  assert_eq(ffx_trim("x"), "x")
}

///|
test "ffx_split_lines：换行切分/丢回车/丢空行" {
  let lines = ffx_split_lines("a\r\nb\n\nc\n")
  assert_eq(lines.length(), 3)
  assert_eq(lines[0], "a")
  assert_eq(lines[1], "b")
  assert_eq(lines[2], "c")
  // 无换行的单行
  assert_eq(ffx_split_lines("solo").length(), 1)
  assert_eq(ffx_split_lines("").length(), 0)
}

///|
test "ffx_ini_split：键值/无等号/键为空" {
  match ffx_ini_split("Path=abc.default-release") {
    Some((k, v)) => {
      assert_eq(k, "Path")
      assert_eq(v, "abc.default-release")
    }
    None => fail("应解析出键值")
  }
  // 值内含等号按首个切分
  match ffx_ini_split("Url=a=b") {
    Some((k, v)) => {
      assert_eq(k, "Url")
      assert_eq(v, "a=b")
    }
    None => fail("应解析出键值")
  }
  // 两侧空白
  match ffx_ini_split("  IsRelative = 0  ") {
    Some((k, v)) => {
      assert_eq(k, "IsRelative")
      assert_eq(v, "0")
    }
    None => fail("应解析出键值")
  }
  // 无等号 / 键为空
  assert_true(ffx_ini_split("noequals") is None)
  assert_true(ffx_ini_split("=v") is None)
  assert_true(ffx_ini_split("") is None)
}

///|
test "ffx_profile_name：相对名/绝对路径/POSIX 与 Windows 分隔符" {
  // profiles.ini 的 Path= 相对名原样
  assert_eq(
    ffx_profile_name("abc123.default-release"),
    "abc123.default-release",
  )
  // 绝对路径取末段（POSIX）
  assert_eq(
    ffx_profile_name("/home/u/.mozilla/firefox/abc123.default"),
    "abc123.default",
  )
  // 绝对路径取末段（Windows 反斜杠）
  assert_eq(
    ffx_profile_name(
      "C:\\Users\\u\\AppData\\Roaming\\Mozilla\\Firefox\\9f8e.dev-edition-default",
    ),
    "9f8e.dev-edition-default",
  )
  // 末尾分隔符给空串
  assert_eq(ffx_profile_name("/a/b/"), "")
}

///|
/// profiles.ini 解析：公开格式样例（Install/两个 Profile 节/General，
/// 含注释行与绝对路径 Path）。
test "ffx_parse_profiles_ini：公开格式样例" {
  let sample = "[Install]\nDefault=abc123.default-release\nLocked=1\n\n[Profile0]\nName=default-release\nIsRelative=1\nPath=abc123.default-release\nDefault=1\n\n[Profile1]\nName=dev-edition-default\nIsRelative=0\nPath=C:\\Users\\u\\AppData\\Roaming\\Mozilla\\Firefox\\9f8e.dev-edition-default\n\n[General]\n; 注释行\nStartWithLastProfile=1\nVersion=2\n"
  let names = ffx_parse_profiles_ini(sample)
  assert_eq(names.length(), 2)
  // 相对路径 Path 原样收集
  assert_eq(names[0], "abc123.default-release")
  // 绝对路径取末段（IsRelative=0）
  assert_eq(names[1], "9f8e.dev-edition-default")
  // 无 Path 行的文本给空数组
  assert_eq(ffx_parse_profiles_ini("[General]\nVersion=2\n").length(), 0)
  // 首尾空白与 CRLF 行尾
  let crlf = "[Profile0]\r\n  Path =  spaced.default  \r\nIsRelative=1\r\n"
  let spaced = ffx_parse_profiles_ini(crlf)
  assert_eq(spaced.length(), 1)
  assert_eq(spaced[0], "spaced.default")
}

///|
test "ffx_places_path：路径拼装" {
  assert_eq(
    ffx_places_path("/home/u/.mozilla/firefox", "abc123.default-release"),
    "/home/u/.mozilla/firefox/abc123.default-release/places.sqlite",
  )
}

///|
test "ffx_parse_places_row：正常/隐藏过滤/列数不足" {
  // moz_places 公开 schema 列序：id/url/title/rev_host/visit_count/
  // hidden/typed/frecency/last_visit_date/guid/…
  let mk = fn(hidden : Int64) -> Array[@moonsqlitefile.Value] {
    [
      @moonsqlitefile.Null, // id：INTEGER PRIMARY KEY 磁盘存 Null
      @moonsqlitefile.Text("https://www.mozilla.org/"),
      @moonsqlitefile.Text("Mozilla - 歌颂互联网自由"),
      @moonsqlitefile.Text("moc.ellooz.www."),
      @moonsqlitefile.Integer(12L), // visit_count
      @moonsqlitefile.Integer(hidden),
      @moonsqlitefile.Integer(1L), // typed
      @moonsqlitefile.Integer(60L), // frecency
      @moonsqlitefile.Integer(1791295963030519L), // last_visit_date（µs）
      @moonsqlitefile.Text("{guid}"),
    ]
  }
  match ffx_parse_places_row(mk(0L)) {
    Some(item) => {
      assert_eq(item.url, "https://www.mozilla.org/")
      assert_eq(item.title, "Mozilla - 歌颂互联网自由")
      assert_eq(item.visit_count, 12)
      // µs → ms 换算
      assert_eq(item.last_visit_time, 1791295963030L)
    }
    None => fail("正常行应解析成功")
  }
  // hidden=1（书签等非历史条目）不收
  assert_true(ffx_parse_places_row(mk(1L)) is None)
  // 列数不足（需至少 9 列才能取到 last_visit_date）
  assert_true(
    ffx_parse_places_row([
      @moonsqlitefile.Null,
      @moonsqlitefile.Text("https://x.example/"),
      @moonsqlitefile.Text("t"),
      @moonsqlitefile.Text("rev"),
      @moonsqlitefile.Integer(1L),
      @moonsqlitefile.Integer(0L),
      @moonsqlitefile.Integer(0L),
      @moonsqlitefile.Integer(0L),
    ])
    is None,
  )
  // 空库行：全 Null 也给一条（url/title 空串、时间 0）
  let nulls : Array[@moonsqlitefile.Value] = [
    @moonsqlitefile.Null,
    @moonsqlitefile.Null,
    @moonsqlitefile.Null,
    @moonsqlitefile.Null,
    @moonsqlitefile.Null,
    @moonsqlitefile.Null,
    @moonsqlitefile.Null,
    @moonsqlitefile.Null,
    @moonsqlitefile.Null,
    @moonsqlitefile.Null,
  ]
  match ffx_parse_places_row(nulls) {
    Some(item) => {
      assert_eq(item.url, "")
      assert_eq(item.title, "")
      assert_eq(item.visit_count, 0)
      assert_eq(item.last_visit_time, 0L)
    }
    None => fail("全 Null 行应解析成功")
  }
}

///|
test "ffx_supported：与平台一致的探测口径" {
  assert_eq(
    ffx_supported(),
    platform() == "linux" || platform() == "macos" || platform() == "windows",
  )
}

///|
/// 端到端探测与读取：仅在本机存在 Firefox places.sqlite 时执行。
test "ffx_history：本机 Firefox 端到端（存在才跑）" {
  match ffx_profiles() {
    Ok(profiles) => {
      assert_true(profiles.length() > 0)
      for p in profiles {
        assert_true(p.places_path.has_suffix("/places.sqlite"))
        assert_true(p.profile != "")
      }
      match ffx_history(limit=1) {
        Ok(items) =>
          // limit=1 最多一条
          assert_true(items.length() <= 1)
        Err(e) =>
          fail("已探测到 places.sqlite 但读取失败: \{e.to_string()}")
      }
    }
    Err(FfxNoProfile) => () // 本机未安装 Firefox：合法降级跳过
    Err(e) => fail("探测 Firefox profile 失败: \{e.to_string()}")
  }
}
