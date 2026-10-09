// 浏览器书签白盒测试：数值字符串解析 / JSON 节点解析（folder 与 url
// 两类、children 递归、非法节点容错）/ 三根合并 / 扁平化 / 路径拼装。
// 样例取自本机真实 ~/.config/google-chrome/Default/Bookmarks（精简为
// bookmark_bar 下一个文件夹两个书签 + other/synced 空根）；端到端用例
// 仅在存在书签文件的环境执行，否则跳过。

///|
test "bm_digits_to_int64：普通/符号/截断/非数值" {
  // 本机实测 date_added（数值字符串，微秒）
  assert_eq(bm_digits_to_int64("13341227029000000"), 13341227029000000L)
  assert_eq(bm_digits_to_int64("0"), 0L)
  assert_eq(bm_digits_to_int64("42"), 42L)
  assert_eq(bm_digits_to_int64("-5"), -5L)
  // 前导零
  assert_eq(bm_digits_to_int64("007"), 7L)
  // 遇非数字字符即止
  assert_eq(bm_digits_to_int64("12ab"), 12L)
  assert_eq(bm_digits_to_int64("abc"), 0L)
  assert_eq(bm_digits_to_int64(""), 0L)
  assert_eq(bm_digits_to_int64("-"), 0L)
  assert_eq(bm_digits_to_int64(" 7"), 0L)
  // 超 Int64 范围截顶（18 位后不再累加）
  assert_eq(bm_digits_to_int64("99999999999999999999"), 999999999999999999L)
}

///|
test "bm_json_int：整数/数值字符串/缺失与非数值" {
  assert_eq(bm_json_int(Some(@yue.VscJInt(42L))), 42L)
  // Chrome 的 date_added 以数值字符串存储
  assert_eq(bm_json_int(Some(@yue.VscJStr("13341227029000000"))), 13341227029000000L)
  assert_eq(bm_json_int(Some(@yue.VscJStr("bad"))), 0L)
  assert_eq(bm_json_int(Some(@yue.VscJStr(""))), 0L)
  assert_eq(bm_json_int(Some(@yue.VscJNull)), 0L)
  assert_eq(bm_json_int(None), 0L)
}

///|
test "bm_parse_node：folder/url/未知类型/缺 url 字段" {
  // folder：children 里合法 url 收、未知类型与缺 url 字段的节点跳过
  let folder = @yue.vsc_json_parse(
    "{\"type\":\"folder\",\"name\":\"目录\",\"date_added\":\"13341227029000000\",\"children\":[{\"type\":\"url\",\"name\":\"甲\",\"url\":\"https://a.example/\",\"date_added\":\"1\"},{\"type\":\"url\",\"name\":\"坏节点\",\"date_added\":\"1\"},{\"type\":\"other\",\"name\":\"x\"}]}",
  )
  match folder {
    Some(f) =>
      match bm_parse_node(f, "bookmark_bar") {
        Some(node) => {
          assert_eq(node.name, "目录")
          assert_true(node.is_folder())
          assert_true(node.url is None)
          assert_eq(node.children.length(), 1)
          assert_eq(node.children[0].name, "甲")
          assert_eq(node.children[0].root, "bookmark_bar")
          assert_eq(node.added, 1696753429000L)
        }
        None => fail("folder 节点应解析成功")
      }
    None => fail("样例 JSON 应解析成功")
  }
  // url 节点：children 为空数组
  let url = @yue.vsc_json_parse(
    "{\"type\":\"url\",\"name\":\"乙\",\"url\":\"https://b.example/\",\"date_added\":\"13341227029000000\"}",
  )
  match url {
    Some(u) =>
      match bm_parse_node(u, "other") {
        Some(node) => {
          assert_true(node.is_url())
          assert_eq(node.url, Some("https://b.example/"))
          assert_eq(node.children.length(), 0)
          assert_eq(node.added, 1696753429000L)
        }
        None => fail("url 节点应解析成功")
      }
    None => fail("样例 JSON 应解析成功")
  }
  // 未知 type 不收
  let bad = @yue.vsc_json_parse("{\"type\":\"weird\",\"name\":\"x\"}")
  match bad {
    Some(b) => assert_true(bm_parse_node(b, "other") is None)
    None => fail("样例 JSON 应解析成功")
  }
  // 缺 type 不收；缺 name 名字给空串
  let no_type = @yue.vsc_json_parse("{\"name\":\"x\"}")
  match no_type {
    Some(n) => assert_true(bm_parse_node(n, "other") is None)
    None => fail("样例 JSON 应解析成功")
  }
  let no_name = @yue.vsc_json_parse(
    "{\"type\":\"url\",\"url\":\"https://c.example/\"}",
  )
  match no_name {
    Some(n) =>
      match bm_parse_node(n, "synced") {
        Some(node) => assert_eq(node.name, "")
        None => fail("缺 name 的 url 节点仍应收")
      }
    None => fail("样例 JSON 应解析成功")
  }
  // date_added 缺失给 0
  let no_time = @yue.vsc_json_parse(
    "{\"type\":\"url\",\"name\":\"丙\",\"url\":\"https://d.example/\"}",
  )
  match no_time {
    Some(n) =>
      match bm_parse_node(n, "other") {
        Some(node) => assert_eq(node.added, 0L)
        None => fail("url 节点应解析成功")
      }
    None => fail("样例 JSON 应解析成功")
  }
}

///|
/// bm_parse_bookmarks：本机实测样例（Chrome 书签栏 LLM 文件夹两个
/// 书签 + 空的其他书签/移动设备书签根）。时间按 Chrome 纪元换算。
test "bm_parse_bookmarks：本机实测样例三根结构" {
  let sample = "{\"checksum\":\"4bc89add657412ce9c965a18bef85499\",\"roots\":{\"bookmark_bar\":{\"type\":\"folder\",\"name\":\"书签栏\",\"date_added\":\"13423302367289006\",\"date_modified\":\"13425119758168249\",\"guid\":\"0bc5d13f-2cba-5d74-951f-3f233fe6c908\",\"id\":\"1\",\"children\":[{\"type\":\"folder\",\"name\":\"LLM\",\"date_added\":\"13350453640189287\",\"date_modified\":\"13409803457776611\",\"guid\":\"f84425a1-94c7-41b3-9a38-73cee2910599\",\"id\":\"5\",\"children\":[{\"date_added\":\"13341227029000000\",\"date_last_used\":\"13407863819033555\",\"guid\":\"f2880d89-8e9a-4008-8932-ef24f076a982\",\"id\":\"6\",\"name\":\"文心一言\",\"type\":\"url\",\"url\":\"https://yiyan.baidu.com/\"},{\"date_added\":\"13341547491000000\",\"date_last_used\":\"0\",\"guid\":\"5c0fc5b8-62a4-4b46-8692-f7fe5cf7581f\",\"id\":\"7\",\"name\":\"讯飞星火\",\"type\":\"url\",\"url\":\"https://xinghuo.xfyun.cn/desk\"}]}]},\"other\":{\"type\":\"folder\",\"name\":\"其他书签\",\"date_added\":\"13423302367289006\",\"guid\":\"82b081ec-3dd3-529c-8475-ab6c344590dd\",\"id\":\"2\",\"children\":[]},\"synced\":{\"type\":\"folder\",\"name\":\"移动设备书签\",\"date_added\":\"13423302367289006\",\"guid\":\"4cf2e351-0e85-532b-bb37-df045d8f8d0f\",\"id\":\"3\",\"children\":[]}}}"
  match bm_parse_bookmarks(sample, "google-chrome/Default") {
    Ok(root) => {
      // 虚拟根：label 命名、无 url、三根依序
      assert_eq(root.name, "google-chrome/Default")
      assert_true(root.is_folder())
      assert_eq(root.root, "")
      assert_eq(root.children.length(), 3)
      let bar = root.children[0]
      assert_eq(bar.name, "书签栏")
      assert_eq(bar.root, "bookmark_bar")
      assert_eq(bar.added, 1778828767289L)
      assert_eq(bar.children.length(), 1)
      // LLM 文件夹
      let llm = bar.children[0]
      assert_eq(llm.name, "LLM")
      assert_true(llm.is_folder())
      assert_eq(llm.added, 1705980040189L)
      assert_eq(llm.children.length(), 2)
      // 两个 url 书签（先序扁平化应对上）
      let yiyan = llm.children[0]
      assert_eq(yiyan.name, "文心一言")
      assert_eq(yiyan.url, Some("https://yiyan.baidu.com/"))
      assert_eq(yiyan.added, 1696753429000L)
      assert_eq(yiyan.root, "bookmark_bar")
      assert_eq(llm.children[1].name, "讯飞星火")
      // 另外两根为空但有根标注
      assert_eq(root.children[1].name, "其他书签")
      assert_eq(root.children[1].root, "other")
      assert_eq(root.children[1].children.length(), 0)
      assert_eq(root.children[2].name, "移动设备书签")
      assert_eq(root.children[2].root, "synced")
      // 扁平化：folder 不进列表，先序两条
      let urls = bm_flatten(root)
      assert_eq(urls.length(), 2)
      assert_eq(urls[0].name, "文心一言")
      assert_eq(urls[1].name, "讯飞星火")
    }
    Err(reason) => fail("实测样例应解析成功: \{reason}")
  }
}

///|
test "bm_parse_bookmarks：错误形态" {
  // 非 JSON
  match bm_parse_bookmarks("not json", "x") {
    Err(reason) => assert_eq(reason, "JSON 解析失败")
    Ok(_) => fail("非 JSON 应报错")
  }
  // 缺 roots 对象
  match bm_parse_bookmarks("{\"a\":1}", "x") {
    Err(reason) => assert_eq(reason, "缺少 roots 对象")
    Ok(_) => fail("缺 roots 应报错")
  }
  // roots 下无三根中任何一根
  match
    bm_parse_bookmarks(
      "{\"roots\":{\"custom\":{\"type\":\"folder\",\"name\":\"c\"}}}", "x",
    ) {
    Err(reason) => assert_eq(reason, "roots 下无 bookmark_bar/other/synced")
    Ok(_) => fail("三根全缺应报错")
  }
  // roots 不是对象（缺失或非对象值均归 缺少 roots 对象）
  match bm_parse_bookmarks("{\"roots\":[1,2]}", "x") {
    Err(reason) => assert_eq(reason, "缺少 roots 对象")
    Ok(_) => fail("roots 非对象应报错")
  }
  // 只有 other 一根时收一根
  match
    bm_parse_bookmarks(
      "{\"roots\":{\"other\":{\"type\":\"folder\",\"name\":\"其他\",\"children\":[{\"type\":\"url\",\"name\":\"n\",\"url\":\"https://e.example/\"}]}}}",
      "x",
    ) {
    Ok(root) => {
      assert_eq(root.children.length(), 1)
      assert_eq(root.children[0].root, "other")
      assert_eq(bm_flatten(root).length(), 1)
    }
    Err(reason) => fail("单根应解析成功: \{reason}")
  }
}

///|
test "bm_flatten：先序/folder 不入表" {
  // 手工构造三层树：根(虚拟) → [folder A] → [url 1, folder B] → [url 2]
  let tree = {
    name: "root",
    url: None,
    children: [
      {
        name: "A",
        url: None,
        added: 0L,
        root: "bookmark_bar",
        children: [
          {
            name: "1",
            url: Some("https://1.example/"),
            children: [],
            added: 0L,
            root: "bookmark_bar",
          },
          {
            name: "B",
            url: None,
            added: 0L,
            root: "bookmark_bar",
            children: [
              {
                name: "2",
                url: Some("https://2.example/"),
                children: [],
                added: 0L,
                root: "bookmark_bar",
              },
            ],
          },
        ],
      },
      {
        name: "3",
        url: Some("https://3.example/"),
        children: [],
        added: 0L,
        root: "other",
      },
    ],
    added: 0L,
    root: "",
  }
  let urls = bm_flatten(tree)
  assert_eq(urls.length(), 3)
  assert_eq(urls[0].url, Some("https://1.example/"))
  assert_eq(urls[1].url, Some("https://2.example/"))
  assert_eq(urls[2].url, Some("https://3.example/"))
  // 空树
  let empty : BookmarkNode = {
    name: "e",
    url: None,
    children: [],
    added: 0L,
    root: "",
  }
  assert_eq(bm_flatten(empty).length(), 0)
}

///|
test "bm_bookmarks_path：子目录拼装" {
  assert_eq(
    bm_bookmarks_path("/home/u/.config", "google-chrome", "", "Default"),
    "/home/u/.config/google-chrome/Default/Bookmarks",
  )
  assert_eq(
    bm_bookmarks_path("/home/u/.config", "chromium", "", "Profile 3"),
    "/home/u/.config/chromium/Profile 3/Bookmarks",
  )
  // Brave 的 profile 在 BraveSoftware/Brave-Browser 下一层
  assert_eq(
    bm_bookmarks_path(
      "/home/u/.config", "BraveSoftware", "Brave-Browser", "Default",
    ),
    "/home/u/.config/BraveSoftware/Brave-Browser/Default/Bookmarks",
  )
}

///|
test "bm_supported：与平台一致的探测口径" {
  assert_eq(bm_supported(), @yue.platform() == "linux")
}

///|
/// 端到端探测与解析：仅在本机存在 Chrome 书签文件时执行。
test "bm_bookmarks：本机 Chrome 书签端到端（存在才跑）" {
  match bm_browsers() {
    Ok(profiles) => {
      assert_true(profiles.length() > 0)
      let first = profiles[0]
      // 探测结果应与书签文件路径对应
      assert_true(first.bookmarks_path.has_suffix("/Bookmarks"))
      match bm_bookmarks(first.browser) {
        Ok(root) => {
          // 虚拟根名 "<浏览器>/<profile>"
          assert_true(root.name.has_prefix(first.browser + "/"))
          assert_true(root.children.length() > 0)
          // 三根标注只允许三个合法键名
          for child in root.children {
            assert_true(
              child.root == "bookmark_bar" ||
              child.root == "other" ||
              child.root == "synced",
              msg="root 标注非法: \{child.root}",
            )
          }
          // 有可扁平化的 url 书签（本机实测 166 条 > 0）
          assert_true(bm_flatten(root).length() > 0)
        }
        Err(e) =>
          fail(
            "已探测到 \{first.browser} 书签文件但解析失败: \{e.to_string()}",
          )
      }
    }
    Err(BmNoBrowser) => () // 本机无书签文件：合法跳过
    Err(e) => fail("探测书签文件失败: \{e.to_string()}")
  }
}
