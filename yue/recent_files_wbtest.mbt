// 最近文件白盒测试：XML 实体解码、XBEL 薄扫描（转义 / 多 application /
// 缺属性容错 / 注释与声明跳过 / 自闭合）、URI 百分号解码与路径还原、
// ISO 8601 时间换算（闰年校验 / 小数秒 / 时区偏移）、排序与截断、数据
// 目录拼装；最后按真实 ~/.local/share/recently-used.xbel 冒烟（本机无
// 数据时自动跳过）。

///|
test "rf_xml_unescape：命名实体/字符引用/未知实体容错" {
  assert_eq(rf_xml_unescape("&amp;&lt;&gt;&apos;&quot;"), "&<>'\"")
  assert_eq(rf_xml_unescape("&#65;&#x42;&#x4e2d;"), "AB中")
  assert_eq(rf_xml_unescape("a&amp;b&lt;c&gt;d"), "a&b<c>d")
  assert_eq(rf_xml_unescape("普通&amp;文本"), "普通&文本")
  assert_eq(rf_xml_unescape(""), "")
  // 未知实体名：按字面保留（含 &）
  assert_eq(rf_xml_unescape("a &unknown; b"), "a &unknown; b")
  assert_eq(rf_xml_unescape("&#xZZ;"), "&#xZZ;")
  // 缺分号：按字面保留
  assert_eq(rf_xml_unescape("&amp"), "&amp")
  assert_eq(rf_xml_unescape("&"), "&")
  assert_eq(rf_xml_unescape("&#65"), "&#65")
  // 坏码点（越界 / 代理值）不收录，按字面保留
  assert_eq(rf_xml_unescape("&#x110000;"), "&#x110000;")
  assert_eq(rf_xml_unescape("&#xD800;"), "&#xD800;")
  assert_eq(rf_xml_unescape("&#0;"), "&#0;")
}

///|
test "rf_iso_to_unix_ms：基准/小数秒/时区/合法性" {
  // Unix 纪元
  assert_eq(rf_iso_to_unix_ms("1970-01-01T00:00:00Z"), Some(0L))
  assert_eq(rf_iso_to_unix_ms("1970-01-01T00:00:00"), Some(0L)) // 无时区按 UTC
  // 实测样本（XBEL 原文）
  assert_eq(
    rf_iso_to_unix_ms("2026-04-21T07:40:38.510353Z"),
    Some(1776757238510L),
  )
  // 小数秒毫秒去尾
  assert_eq(rf_iso_to_unix_ms("2026-04-21T07:40:38.5Z"), Some(1776757238500L))
  assert_eq(
    rf_iso_to_unix_ms("2026-04-21T07:40:38.9999Z"),
    Some(1776757238999L),
  )
  assert_eq(
    rf_iso_to_unix_ms("2026-04-21T07:40:38.0001Z"),
    Some(1776757238000L),
  )
  // 空格分隔符（宽容形态）
  assert_eq(rf_iso_to_unix_ms("2026-04-21 07:40:38Z"), Some(1776757238000L))
  // 时区偏移：+08:00 的 15:40:38 等价 UTC 07:40:38
  assert_eq(
    rf_iso_to_unix_ms("2026-04-21T15:40:38+08:00"),
    Some(1776757238000L),
  )
  assert_eq(
    rf_iso_to_unix_ms("2026-04-20T23:40:38-08:00"),
    Some(1776757238000L),
  )
  // 闰日：2024 有 2 月 29，2026 没有
  assert_eq(rf_iso_to_unix_ms("2024-02-29T00:00:00Z"), Some(1709164800000L))
  assert_true(rf_iso_to_unix_ms("2026-02-29T00:00:00Z") is None)
  assert_true(rf_iso_to_unix_ms("2026-02-30T00:00:00Z") is None)
  // 量程越界
  assert_true(rf_iso_to_unix_ms("2026-13-01T00:00:00Z") is None)
  assert_true(rf_iso_to_unix_ms("2026-00-01T00:00:00Z") is None)
  assert_true(rf_iso_to_unix_ms("2026-04-00T00:00:00Z") is None)
  assert_true(rf_iso_to_unix_ms("2026-04-21T24:00:00Z") is None)
  assert_true(rf_iso_to_unix_ms("2026-04-21T23:60:00Z") is None)
  // 形态错误
  assert_true(rf_iso_to_unix_ms("") is None)
  assert_true(rf_iso_to_unix_ms("not-a-time") is None)
  assert_true(rf_iso_to_unix_ms("2026-04-21X07:40:38Z") is None)
  assert_true(rf_iso_to_unix_ms("2026/04/21T07:40:38Z") is None)
  assert_true(rf_iso_to_unix_ms("2026-04-21T07:40:38+08:60") is None)
  assert_true(rf_iso_to_unix_ms("2026-04-21T07:40:38+8:00") is None)
}

///|
test "rf_days_from_civil / 闰年：标准历法换算" {
  assert_eq(rf_days_from_civil(1970, 1, 1), 0)
  assert_eq(rf_days_from_civil(2000, 3, 1), 11017)
  assert_eq(rf_days_from_civil(2026, 10, 7), 20733)
  assert_eq(
    rf_days_from_civil(2024, 2, 29) - rf_days_from_civil(2024, 2, 28),
    1,
  )
  assert_eq(rf_days_from_civil(2100, 3, 1) - rf_days_from_civil(2100, 2, 28), 1) // 2100 非闰
  assert_eq(rf_days_from_civil(2000, 3, 1) - rf_days_from_civil(2000, 2, 28), 2) // 2000 闰
  // 月份天数表
  assert_eq(rf_days_in_month(2026, 2), Some(28))
  assert_eq(rf_days_in_month(2024, 2), Some(29))
  assert_eq(rf_days_in_month(2026, 4), Some(30))
  assert_eq(rf_days_in_month(2026, 12), Some(31))
  assert_true(rf_days_in_month(2026, 0) is None)
  assert_true(rf_days_in_month(2026, 13) is None)
}

///|
test "rf_percent_decode：UTF-8 组合/字面保留/残缺转义" {
  // 实测 XBEL 里的 %E4%B8%8B%E8%BD%BD → 下载
  assert_eq(rf_percent_decode("%E4%B8%8B%E8%BD%BD"), "下载")
  assert_eq(
    rf_percent_decode("%E4%B8%AD%E6%96%87%20%E8%B5%84%E6%96%99.txt"),
    "中文 资料.txt",
  )
  assert_eq(rf_percent_decode("/home/a%20b/c.txt"), "/home/a b/c.txt")
  assert_eq(rf_percent_decode("%23%3F%26"), "#?&")
  assert_eq(rf_percent_decode("plain/path"), "plain/path")
  assert_eq(rf_percent_decode(""), "")
  // 残缺：% 后不足两位十六进制按字面 '%' 保留
  assert_eq(rf_percent_decode("100%"), "100%")
  assert_eq(rf_percent_decode("%E"), "%E")
  assert_eq(rf_percent_decode("%zz"), "%zz")
  // %E4 是合法字节但与后续 '%B' 组不成完整 UTF-8 序列：单字节按替换字符
  assert_eq(rf_percent_decode("%E4%B"), "\u{FFFD}%B")
  // 多字节序列：三字节一码点，不按码元数错判
  assert_eq(rf_percent_decode("%E4%B8%8B"), "下")
  assert_eq(rf_percent_decode("%E4%B8%8B%E8%BD%BD"), "下载")
}

///|
test "rf_uri_to_path：file:// 还原/ authority / 非 file 方案" {
  assert_eq(
    rf_uri_to_path("file:///home/lkyh/下载/x.png"),
    Some("/home/lkyh/下载/x.png"),
  )
  assert_eq(
    rf_uri_to_path("file:///home/lkyh/%E4%B8%8B%E8%BD%BD/527f8e8a.png"),
    Some("/home/lkyh/下载/527f8e8a.png"),
  )
  assert_eq(rf_uri_to_path("file:///home/a%20b/c.txt"), Some("/home/a b/c.txt"))
  // 带 authority（SMB 共享形态）还原 //host/path
  assert_eq(
    rf_uri_to_path("file://host/share/x.txt"),
    Some("//host/share/x.txt"),
  )
  assert_eq(rf_uri_to_path("file://"), Some(""))
  // 非 file 方案
  assert_true(rf_uri_to_path("computer:///") is None)
  assert_true(rf_uri_to_path("http://example.com/") is None)
  assert_true(rf_uri_to_path("/home/abs/path") is None)
  assert_true(rf_uri_to_path("") is None)
}

///|
test "rf_parse_xbel：完整样例（转义/多 application/缺属性/自闭合/注释）" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<!DOCTYPE xbel PUBLIC \"-//freedesktop//DTD XBEL 1.0//EN\" \"http://example/xbel-1.0.dtd\">\n" +
    "<xbel version=\"1.0\"\n" +
    "      xmlns:bookmark=\"http://www.freedesktop.org/standards/desktop-bookmarks\"\n" +
    "      xmlns:mime=\"http://www.freedesktop.org/standards/shared-mime-info\"\n" +
    ">\n" +
    "  <!-- 注释里藏一个 <bookmark href=\"file:///ghost.txt\"> 不该收 -->\n" +
    "  <bookmark href=\"file:///home/u/a.txt\" added=\"2026-04-21T07:40:38.510353Z\" modified=\"2026-09-30T12:00:00Z\" visited=\"2026-04-21T07:40:38.510353Z\">\n" +
    "    <info>\n" +
    "      <metadata owner=\"http://freedesktop.org\">\n" +
    "        <mime:mime-type type=\"text/plain\"/>\n" +
    "        <bookmark:applications>\n" +
    "          <bookmark:application name=\"Thunar\" exec=\"&apos;Thunar %u&apos;\" modified=\"2026-09-30T12:00:00Z\" count=\"3\"/>\n" +
    "          <bookmark:application name=\"org.gnome.Nautilus\" exec=\"&apos;org.gnome.Nautilus %u&apos;\" modified=\"2026-04-21T07:40:38.510353Z\" count=\"1\"/>\n" +
    "        </bookmark:applications>\n" +
    "      </metadata>\n" +
    "    </info>\n" +
    "  </bookmark>\n" +
    "  <bookmark href='file:///home/u/%E4%B8%AD%E6%96%87%20%E8%B5%84%E6%96%99.txt' added='2026-05-01T00:00:00Z' modified='2026-09-20T00:00:00Z'>\n" +
    "    <info><metadata owner=\"http://freedesktop.org\">\n" +
    "      <bookmark:applications>\n" +
    "        <bookmark:application name=\"Thunar\" exec=\"x\" count=\"bad\"/>\n" +
    "      </bookmark:applications>\n" +
    "    </metadata></info>\n" +
    "  </bookmark>\n" +
    "  <bookmark href=\"computer:///\" added=\"2026-06-01T00:00:00Z\" modified=\"2026-09-25T00:00:00Z\"/>\n" +
    "  <bookmark href=\"file:///home/u/b.txt\" added=\"2026-06-05T00:00:00Z\" modified=\"2026-09-25T00:00:00Z\">\n" +
    "    <info><metadata owner=\"http://freedesktop.org\">\n" +
    "      <mime:mime-type type=\"text/plain\"/>\n" +
    "      <mime:mime-type type=\"second/should-not-win\"/>\n" +
    "    </metadata></info>\n" +
    "  </bookmark>\n" +
    "  <bookmark href=\"&amp;&lt;weird&gt;\" modified=\"2026-09-10T00:00:00Z\"/>\n" +
    "  <bookmark added=\"2026-06-04T00:00:00Z\"/>\n" +
    "</xbel>"
  match rf_parse_xbel(xml) {
    Err(reason) => {
      inspect(reason, content="<应解析成功>")
      inspect(false, content="true")
    }
    Ok(entries) => {
      // 6 个 bookmark 起始标签：无 href 的那条整条跳过 → 5 条
      inspect(entries.length(), content="5")
      // ① 双引号 + mime + 两个 application（exec 里 &apos; 实体不影响属性切分）
      inspect(entries[0].uri, content="file:///home/u/a.txt")
      assert_eq(entries[0].mime, Some("text/plain"))
      inspect(entries[0].added, content="1776757238510")
      inspect(entries[0].modified, content="1790769600000")
      assert_eq(entries[0].apps, ["Thunar", "org.gnome.Nautilus"])
      // ② 单引号属性 + 无 mime 节点 + application 缺 count（仍按名计数）
      inspect(
        entries[1].uri,
        content="file:///home/u/%E4%B8%AD%E6%96%87%20%E8%B5%84%E6%96%99.txt",
      )
      assert_eq(entries[1].mime, None)
      inspect(entries[1].modified, content="1789862400000") // 2026-09-20T00:00:00Z
      assert_eq(entries[1].apps, ["Thunar"])
      // ③ 自闭合 non-file href：条目保留（path 为空由映射层处理）
      inspect(entries[2].uri, content="computer:///")
      inspect(entries[2].apps.length(), content="0")
      inspect(entries[2].modified, content="1790294400000")
      // ④ 同名 mime 首个生效
      inspect(entries[3].uri, content="file:///home/u/b.txt")
      assert_eq(entries[3].mime, Some("text/plain"))
      // ⑤ 实体转义后的 href（&amp;&lt;weird&gt; → &<weird>）
      inspect(entries[4].uri, content="&<weird>")
      // 注释里的假 bookmark 未收录（总数 5 已覆盖）
    }
  }
}

///|
test "rf_parse_xbel：非 XBEL 文本给 Err / 空文本给 Err" {
  match
    rf_parse_xbel(
      "<?xml version=\"1.0\"?>\n<html><body>no xbel here</body></html>",
    ) {
    Ok(_) => inspect(false, content="true")
    Err(reason) => inspect(reason.length() > 0, content="true")
  }
  match rf_parse_xbel("") {
    Ok(_) => inspect(false, content="true")
    Err(reason) => inspect(reason.length() > 0, content="true")
  }
  // 截断的 XBEL（写到一半）：根在，收已闭合的条目
  let truncated = "<xbel>\n<bookmark href=\"file:///a\" modified=\"2026-01-01T00:00:00Z\" >\n</bookmark>\n<bookmark href=\"file:///b\""
  match rf_parse_xbel(truncated) {
    Ok(entries) => inspect(entries.length(), content="1")
    Err(_) => inspect(false, content="true")
  }
}

///|
test "rf_entry_to_item 与 rf_sort_recent：映射/倒序/并列序" {
  let xml = "<xbel>\n" +
    "<bookmark href=\"file:///home/u/a.txt\" added=\"2026-04-21T07:40:38.510353Z\" modified=\"2026-09-30T12:00:00Z\">\n" +
    "  <mime:mime-type type=\"text/plain\"/>\n" +
    "  <bookmark:application name=\"Thunar\" exec=\"x\" count=\"3\"/>\n" +
    "</bookmark>\n" +
    "<bookmark href=\"file:///home/u/%E4%B8%AD%E6%96%87.txt\" modified=\"2026-09-20T00:00:00Z\"/>\n" +
    "<bookmark href=\"computer:///\" modified=\"2026-09-25T00:00:00Z\"/>\n" +
    "</xbel>"
  let entries = match rf_parse_xbel(xml) {
    Ok(e) => e
    Err(_) => {
      inspect(false, content="true")
      []
    }
  }
  let items = rf_sort_recent(entries.map(rf_entry_to_item))
  // modified 倒序：09-30 > 09-25 > 09-20
  inspect(items.length(), content="3")
  inspect(items[0].path, content="/home/u/a.txt")
  assert_eq(items[0].mime, Some("text/plain"))
  inspect(items[0].app_count, content="1")
  inspect(items[1].path, content="") // computer:/// 无本地路径
  inspect(items[1].uri, content="computer:///")
  inspect(items[1].app_count, content="0")
  inspect(items[2].path, content="/home/u/中文.txt")
  inspect(items[2].added, content="0") // 缺 added 按 0
  // 并列 modified：path 升序（"" 先于 "/home/..."）
  let tie = rf_sort_recent([
    {
      uri: "file:///z",
      path: "/z",
      mime: None,
      added: 0L,
      modified: 100L,
      app_count: 0,
    },
    {
      uri: "file:///a",
      path: "/a",
      mime: None,
      added: 0L,
      modified: 100L,
      app_count: 0,
    },
    {
      uri: "file:///e",
      path: "",
      mime: None,
      added: 0L,
      modified: 100L,
      app_count: 0,
    },
    {
      uri: "file:///m",
      path: "/m",
      mime: None,
      added: 0L,
      modified: 200L,
      app_count: 0,
    },
  ])
  inspect(tie[0].path, content="/m") // modified 最大
  inspect(tie[1].path, content="") // 并列时空路径在前
  inspect(tie[2].path, content="/a")
  inspect(tie[3].path, content="/z")
}

///|
test "rf_filter_apps：按应用名精确过滤" {
  let xml = "<xbel>\n" +
    "<bookmark href=\"file:///a\" modified=\"2026-01-02T00:00:00Z\">\n" +
    "  <bookmark:application name=\"Thunar\" exec=\"x\" count=\"3\"/>\n" +
    "  <bookmark:application name=\"org.gnome.Nautilus\" exec=\"y\" count=\"1\"/>\n" +
    "</bookmark>\n" +
    "<bookmark href=\"file:///b\" modified=\"2026-01-03T00:00:00Z\">\n" +
    "  <bookmark:application name=\"Thunar\" exec=\"x\" count=\"9\"/>\n" +
    "</bookmark>\n" +
    "<bookmark href=\"file:///c\" modified=\"2026-01-04T00:00:00Z\"/>\n" +
    "</xbel>"
  let entries = match rf_parse_xbel(xml) {
    Ok(e) => e
    Err(_) => {
      inspect(false, content="true")
      []
    }
  }
  let thunar = rf_filter_apps(entries, "Thunar")
  inspect(thunar.length(), content="2")
  inspect(rf_filter_apps(entries, "org.gnome.Nautilus").length(), content="1")
  // 精确匹配：大小写不敏感不做
  inspect(rf_filter_apps(entries, "thunar").length(), content="0")
  inspect(rf_filter_apps(entries, "不存在的应用").length(), content="0")
  inspect(rf_filter_apps(entries, "").length(), content="0")
}

///|
test "rf_take：全收边界/截断（私有泛型）" {
  let src = [1, 2, 3, 4, 5]
  debug_inspect(rf_take(src, 0), content="[1, 2, 3, 4, 5]") // <=0 全收
  debug_inspect(rf_take(src, -3), content="[1, 2, 3, 4, 5]")
  debug_inspect(rf_take(src, 5), content="[1, 2, 3, 4, 5]") // 恰等全收
  debug_inspect(rf_take(src, 99), content="[1, 2, 3, 4, 5]") // 超出全收
  debug_inspect(rf_take(src, 2), content="[1, 2]")
}

///|
test "rf_data_dir：XDG 优先/回退 HOME/都空给 None" {
  assert_eq(rf_data_dir(Some("/opt/data"), Some("/home/u")), Some("/opt/data"))
  assert_eq(
    rf_data_dir(Some(""), Some("/home/u")),
    Some("/home/u/.local/share"),
  ) // 空串回退
  assert_eq(rf_data_dir(None, Some("/home/u")), Some("/home/u/.local/share"))
  assert_eq(rf_data_dir(Some("/opt/data"), None), Some("/opt/data"))
  assert_true(rf_data_dir(None, None) is None)
  assert_true(rf_data_dir(Some(""), None) is None)
}

///|
test "rf_recent：本机真实 recently-used.xbel 冒烟（有数据才断言）" {
  match rf_recent(limit=0) {
    Err(_) => () // 非 Linux / 本机未记录过最近文件：跳过
    Ok(items) =>
      if items.length() > 0 {
        // 记录非空
        inspect(items.length() > 0, content="true")
        // 排序不变式：modified 非递增
        let mut ordered = true
        for i in 1..<items.length() {
          if items[i].modified > items[i - 1].modified {
            ordered = false
          }
        }
        inspect(ordered, content="true")
        // 至少一条 file:// 且解码出本地路径
        let mut has_path = false
        for item in items {
          if item.path != "" {
            has_path = true
          }
        }
        inspect(has_path, content="true")
        // 时间字段已换算（真实文件里近期条目应为 2026 年量级）
        inspect(items[0].modified > 1767225600000L, content="true")
      }
  }
}

///|
test "rf_by_app：本机真实文件按应用过滤冒烟（有数据才断言）" {
  match rf_by_app("Thunar", limit=0) {
    Err(_) => ()
    Ok(items) =>
      if items.length() > 0 {
        inspect(items[0].app_count > 0, content="true")
        let mut ordered = true
        for i in 1..<items.length() {
          if items[i].modified > items[i - 1].modified {
            ordered = false
          }
        }
        inspect(ordered, content="true")
      }
  }
}
