// VS Code 本地历史/最近工作区白盒测试：JSON 解析（转义/数字/容错）、
// URI 编码解码、资源 URI → 历史目录名哈希、时间戳换算。样例取自本机
// 真实 ~/.config/Code/User 数据（entries.json 与 storage.json 实测结构）；
// 端到端用例仅在存在 VS Code 用户数据的环境执行，否则跳过。

///|
/// entries.json 解析：本机实测样例（含无 source 字段的条目）。
test "vsc_json_parse：entries.json 实测样例" {
  let sample = "{\"version\":1,\"resource\":\"file:///home/lkyh/code/EMS-CP/web/src/view/ems/components/pointSelect.vue\",\"entries\":[{\"id\":\"mzv0.vue\",\"source\":\"searchReplace.source\",\"timestamp\":1780041766190},{\"id\":\"cnqS.vue\",\"source\":\"searchReplace.source\",\"timestamp\":1780042445877},{\"id\":\"wmV7.vue\",\"timestamp\":1780305446898}]}"
  let j = vsc_json_parse(sample)
  assert_true(j is Some(_))
  match j {
    Some(root) => {
      assert_eq(vsc_json_get(root, "version") |> vsc_json_int64, Some(1L))
      assert_eq(
        vsc_json_get(root, "resource") |> vsc_json_str,
        Some(
          "file:///home/lkyh/code/EMS-CP/web/src/view/ems/components/pointSelect.vue",
        ),
      )
      match vsc_json_get(root, "entries") {
        Some(VscJArr(entries)) => {
          assert_eq(entries.length(), 3)
          assert_eq(
            vsc_json_get(entries[0], "id") |> vsc_json_str,
            Some("mzv0.vue"),
          )
          assert_eq(
            vsc_json_get(entries[1], "timestamp") |> vsc_json_int64,
            Some(1780042445877L),
          )
          // 末条无 source 字段也能解析
          assert_eq(
            vsc_json_get(entries[2], "id") |> vsc_json_str,
            Some("wmV7.vue"),
          )
          assert_eq(
            vsc_json_get(entries[2], "timestamp") |> vsc_json_int64,
            Some(1780305446898L),
          )
          assert_true(vsc_json_get(entries[2], "source") is None)
        }
        _ => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
/// storage.json windowsState 解析：本机实测样例 + 带 workspaceUri 的
/// openedWindows 合成样例。
test "vsc_json_parse：storage.json windowsState 实测样例" {
  let sample = "{\"windowsState\":{\"lastActiveWindow\":{\"folder\":\"file:///home/lkyh/ownCode/steel-front\",\"backupPath\":\"/home/lkyh/.config/Code/Backups/575b8b90282ed2604fc34b0719168ea4\",\"uiState\":{\"mode\":0,\"x\":635,\"y\":76,\"width\":1200,\"height\":800}},\"openedWindows\":[]}}"
  match vsc_json_parse(sample) {
    Some(root) => {
      let recent = vsc_recent_paths_of(root)
      assert_eq(recent.length(), 1)
      assert_eq(recent[0], "/home/lkyh/ownCode/steel-front")
    }
    None => assert_true(false)
  }
  // openedWindows 含 folder（带空格）与 workspaceUri 两种形态
  let sample2 = "{\"windowsState\":{\"openedWindows\":[{\"folder\":\"file:///home/lkyh/my%20proj\"},{\"workspaceUri\":\"file:///home/lkyh/ownCode/demo.code-workspace\"}]}}"
  match vsc_json_parse(sample2) {
    Some(root) => {
      let recent = vsc_recent_paths_of(root)
      assert_eq(recent.length(), 2)
      assert_eq(recent[0], "/home/lkyh/my proj")
      assert_eq(recent[1], "/home/lkyh/ownCode/demo.code-workspace")
    }
    None => assert_true(false)
  }
  // 无 windowsState（全新安装）→ 空
  match vsc_json_parse("{\"theme\":\"dark\"}") {
    Some(root) => assert_eq(vsc_recent_paths_of(root).length(), 0)
    None => assert_true(false)
  }
}

///|
/// 字符串转义：\" \\ \/ \b \f \n \r \t \uXXXX 与代理对合并。
test "vsc_json_parse：字符串转义" {
  let sample = "{\"s\":\"a\\nb\\\"q\\\"\\u4e2d\\\\z\\ud83d\\ude00!/\"}"
  match vsc_json_parse(sample) {
    Some(root) =>
      assert_eq(
        vsc_json_get(root, "s") |> vsc_json_str,
        Some("a\nb\"q\"中\\z😀!/"),
      )
    None => assert_true(false)
  }
  // 原样 UTF-8 字符直通
  let sample2 = "{\"s\":\"中文😀\"}"
  match vsc_json_parse(sample2) {
    Some(root) =>
      assert_eq(vsc_json_get(root, "s") |> vsc_json_str, Some("中文😀"))
    None => assert_true(false)
  }
}

///|
/// 数字：整数（负数/Int64 大值）、浮点、指数；畸形 JSON 一律 None。
test "vsc_json_parse：数字与容错" {
  match vsc_json_parse("{\"n\":-7}") {
    Some(root) =>
      assert_eq(vsc_json_get(root, "n") |> vsc_json_int64, Some(-7L))
    None => assert_true(false)
  }
  match vsc_json_parse("{\"n\":9223372036854775807}") {
    Some(root) =>
      assert_eq(
        vsc_json_get(root, "n") |> vsc_json_int64,
        Some(9223372036854775807L),
      )
    None => assert_true(false)
  }
  match vsc_json_parse("{\"f\":12.5}") {
    Some(root) =>
      match vsc_json_get(root, "f") {
        Some(VscJFloat(f)) => assert_true((f - 12.5).abs() < 1.0e-9)
        _ => assert_true(false)
      }
    None => assert_true(false)
  }
  match vsc_json_parse("{\"f\":1e3}") {
    Some(root) =>
      match vsc_json_get(root, "f") {
        Some(VscJFloat(f)) => assert_true((f - 1000.0).abs() < 1.0e-6)
        _ => assert_true(false)
      }
    None => assert_true(false)
  }
  // 整值浮点兜底转 Int64；带小数返回 None
  assert_eq(vsc_json_int64(Some(VscJFloat(1.0))), Some(1L))
  assert_true(vsc_json_int64(Some(VscJFloat(1.5))) is None)
  // 字面量 true / null
  assert_true(vsc_json_parse("true") is Some(VscJBool))
  assert_true(vsc_json_parse("null") is Some(VscJNull))
  // 畸形：未闭合/截断字面量/尾逗号/缺值/尾随内容/空文本
  assert_true(vsc_json_parse("{") is None)
  assert_true(vsc_json_parse("tru") is None)
  assert_true(vsc_json_parse("[1,]") is None)
  assert_true(vsc_json_parse("{\"a\":}") is None)
  assert_true(vsc_json_parse("1 2") is None)
  assert_true(vsc_json_parse("") is None)
  assert_true(vsc_json_parse("\"unterminated") is None)
}

///|
/// URI 路径编码：保留字符集、空格与中文转义、与 VS Code 同形。
test "vsc_uri_encode_path：保留集与转义" {
  assert_eq(
    vsc_uri_encode_path("/home/u/a b/中文.vue"),
    "/home/u/a%20b/%E4%B8%AD%E6%96%87.vue",
  )
  assert_eq(
    vsc_uri_encode_path("/tmp/a-b_c.d~e(f)g+h;j,k'm"),
    "/tmp/a-b_c.d~e%28f%29g%2Bh%3Bj%2Ck%27m",
  )
  assert_eq(
    vsc_uri_encode_path("/plain/path-1.2_v~.txt"),
    "/plain/path-1.2_v~.txt",
  )
  // 回环：编码 → 解码还原
  let enc = vsc_uri_encode_path("/home/u/a b/中文.vue")
  assert_eq(
    vsc_uri_percent_decode(enc, 0, enc.length()),
    "/home/u/a b/中文.vue",
  )
}

///|
/// URI → 本地路径：file:/// 直取、%XX 解码、非 file 方案 None。
test "vsc_uri_to_path：形态与解码" {
  assert_eq(
    vsc_uri_to_path("file:///home/lkyh/ownCode/steel-front"),
    Some("/home/lkyh/ownCode/steel-front"),
  )
  assert_eq(
    vsc_uri_to_path("file:///home/lkyh/my%20proj"),
    Some("/home/lkyh/my proj"),
  )
  assert_true(vsc_uri_to_path("https://example.com/y") is None)
  assert_eq(
    vsc_uri_to_path("vscode-userdata:/home/x/.config/Code/User/settings.json"),
    Some("/home/x/.config/Code/User/settings.json"),
  )
}

///|
/// 资源 URI 构造：普通文件、User 目录内配置文件、特殊字符。
test "vsc_resource_uri：普通文件与 User 内配置" {
  assert_eq(
    vsc_resource_uri("/home/x/.config/Code", "/home/x/prj/a b.vue"),
    "file:///home/x/prj/a%20b.vue",
  )
  assert_eq(
    vsc_resource_uri(
      "/home/x/.config/Code", "/home/x/.config/Code/User/settings.json",
    ),
    "vscode-userdata:/home/x/.config/Code/User/settings.json",
  )
  assert_eq(
    vsc_resource_uri(
      "/home/x/.config/Code", "/home/x/.config/Code/User/中文目录/xx.json",
    ),
    "vscode-userdata:/home/x/.config/Code/User/%E4%B8%AD%E6%96%87%E7%9B%AE%E5%BD%95/xx.json",
  )
}

///|
/// 历史目录名哈希：本机实测三例（正数/负数/vscode-userdata）与
/// 有符号十六进制格式。
test "vsc_history_folder：真实目录名复算" {
  assert_eq(
    vsc_history_folder(
      "file:///home/lkyh/code/EMS-CP/web/src/view/ems/components/pointSelect.vue",
    ),
    "100bdcaa",
  )
  assert_eq(
    vsc_history_folder(
      "file:///home/lkyh/code/BASE/forntEnd/web-new/src/view/eam/api/datasourceApi.js",
    ),
    "-10b5e510",
  )
  assert_eq(
    vsc_history_folder(
      "vscode-userdata:/home/lkyh/.config/Code/User/settings.json",
    ),
    "4180635d",
  )
  // 有符号十六进制：无补零、负号、边界值
  assert_eq(vsc_i64_hex32(0L), "0")
  assert_eq(vsc_i64_hex32(-6L), "-6")
  assert_eq(vsc_i64_hex32(-1L), "-1")
  assert_eq(vsc_i64_hex32(1411501619L), "5421ce33")
  assert_eq(vsc_i64_hex32(2147483647L), "7fffffff")
  assert_eq(vsc_i64_hex32(-2147483648L), "-80000000")
}

///|
/// 时间戳换算：毫秒 → 秒去尾。
test "VscHistoryEntry::timestamp_seconds：毫秒转秒" {
  let e : VscHistoryEntry = { path: "/x/abc.vue", timestamp: 1780041766190L, }
  assert_eq(e.timestamp_seconds(), 1780041766L)
  let e2 : VscHistoryEntry = { path: "/x/abc.vue", timestamp: 999L, }
  assert_eq(e2.timestamp_seconds(), 0L)
}

///|
/// 端到端：真实 VS Code 用户数据环境跑公开 API；无数据环境跳过
/// （与 charts_wbtest 的 DISPLAY 门控同法）。
test "vsc_local_history / vsc_recent：真实环境端到端（无 VS Code 数据时跳过）" {
  if !vsc_supported() {
    println("vscode: skip (no local VS Code user data)")
    return
  }
  match vsc_recent() {
    Ok(list) => println("vscode: recent=\{list.length()}")
    Err(_) => assert_true(false)
  }
  match
    vsc_local_history(
      "/home/lkyh/code/EMS-CP/web/src/view/ems/components/pointSelect.vue",
    ) {
    Ok(entries) => {
      println("vscode: history entries=\{entries.length()}")
      if entries.length() > 0 {
        // 倒序 + 快照与 entries.json 同目录
        assert_true(entries[0].path.has_prefix("/home/"))
        for i in 1..<entries.length() {
          assert_true(entries[i - 1].timestamp >= entries[i].timestamp)
        }
      }
    }
    Err(_) => assert_true(false)
  }
  // 无历史记录的文件 → 空列表（非错误）
  match vsc_local_history("/tmp/vsc-no-such-history/file.mbt") {
    Ok(entries) => assert_eq(entries.length(), 0)
    Err(_) => assert_true(false)
  }
}
