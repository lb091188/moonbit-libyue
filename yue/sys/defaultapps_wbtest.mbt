// 默认应用查询白盒测试：mimeapps.list 段解析、默认应用合并改写、多文件
// 关联合并与分号拆分；写路径用 XDG_CONFIG_HOME 指到临时目录真读真写
// （不触碰用户真实配置）；xdg-mime 命令查询仅在本机存在该工具时断言。

///|
test "da mimeapps 解析：段/注释/段外行/首个等号/同名键不去重" {
  let content = "[Default Applications]\n# 井号注释\n\ntext/plain=sublime_text.desktop;org.gnome.gedit.desktop;\ntext/plain=second.desktop;\n孤儿行没有等号\n[Added Associations]\ntext/html=firefox.desktop;chromium.desktop;\n"
  let sections = da_parse_mimeapps(content)
  // 两个段
  assert_eq(sections.length(), 2)
  assert_eq(sections[0].0, "Default Applications")
  assert_eq(sections[1].0, "Added Associations")
  // text/plain 出现两次,mimeapps.list 同名键不去重(默认应用后写覆盖先写)
  let plains = da_section_values(sections, "Default Applications", "text/plain")
  assert_eq(plains, [
    "sublime_text.desktop;org.gnome.gedit.desktop;", "second.desktop;",
  ])
  // Added Associations 正常收录
  assert_eq(
    da_section_values(sections, "Added Associations", "text/html"),
    ["firefox.desktop;chromium.desktop;"],
  )
  // 无等号的杂行被跳过(只有合法键进段)
  assert_eq(sections[1].1.length(), 1)
  // 段外的键不收
  assert_eq(
    da_section_values(sections, "Default Applications", "孤儿行没有等号").length(),
    0,
  )
  // 未登记的 mime 给空表
  assert_eq(
    da_section_values(sections, "Default Applications", "text/html").length(),
    0,
  )
}

///|
test "da 合并默认应用行：替换已有/段内追加/无段补段/保留注释" {
  // 1) 已有段 + 已有 mime 行 → 替换
  let replaced = da_merge_default_line(
    "[Default Applications]\ntext/plain=old.desktop;",
    "text/plain",
    "new.desktop",
  )
  assert_true(replaced.contains("text/plain=new.desktop"))
  assert_true(!replaced.contains("old.desktop"))
  // 2) 已有段 + 无该行 → 段内追加（插在本段末尾、下一段之前）
  let appended = da_merge_default_line(
    "[Default Applications]\ntext/html=firefox.desktop;\n[Added Associations]\nx=1\n",
    "text/plain",
    "sublime_text.desktop",
  )
  assert_true(
    appended.contains(
      "[Default Applications]\ntext/html=firefox.desktop;\ntext/plain=sublime_text.desktop\n",
    ),
  )
  assert_true(appended.contains("[Added Associations]\nx=1\n"))
  // 3) 无目标段 → 文末补段,原内容保留
  let fresh = da_merge_default_line(
    "# 我的配置\n[Added Associations]\ntext/html=firefox.desktop;\n",
    "text/plain",
    "sublime_text.desktop",
  )
  assert_true(fresh.contains("# 我的配置"))
  assert_true(
    fresh.contains("[Default Applications]\ntext/plain=sublime_text.desktop\n"),
  )
  // 4) 空内容 → 只有新段
  assert_eq(
    da_merge_default_line("", "text/plain", "a.desktop"),
    "[Default Applications]\ntext/plain=a.desktop\n",
  )
}

///|
test "da 关联合并：默认应用排最前 + 分号拆分去重 + 多文件合并" {
  let texts : Array[String] = [
    "[Added Associations]\ntext/html=firefox.desktop;chromium.desktop;firefox.desktop;\n",
    "[Default Applications]\ntext/html=firefox.desktop;\ntext/html=brave.desktop;\n",
  ]
  let all = da_associations_of_texts(texts, "text/html")
  // 按文本顺序、同一文本内 Default 先于 Added，分号拆开后再去重：
  // 第一个文本只有 Added（firefox/chromium，重复的 firefox 被去掉），
  // 第二个文本 Default 两行 → firefox 已在表里，只剩 brave
  assert_eq(all, ["firefox.desktop", "chromium.desktop", "brave.desktop"])
  // 未登记的 mime 无关联
  assert_eq(da_associations_of_texts(texts, "application/x-none"), [])
  // 空文本表
  assert_eq(da_associations_of_texts([], "text/html"), [])
}

///|
test "da_set_default：XDG_CONFIG_HOME 指到临时目录真写读回" {
  if !pr_available() {
    println("da: skip (not linux)")
    return
  }
  let saved = envx_get("XDG_CONFIG_HOME")
  let dir = "/tmp/da_wbtest_config"
  let _ = pr_run("mkdir", ["-p", dir])
  let _ = envx_set("XDG_CONFIG_HOME", dir)
  let file = dir + "/mimeapps.list"
  let _ = sys_remove_file(file)
  // 1) 文件不存在 → 新建段并落第一行
  assert_true(da_set_default("text/plain", "gedit.desktop") is Ok(_))
  assert_eq(
    sys_read_text_file(file),
    Some("[Default Applications]\ntext/plain=gedit.desktop\n"),
  )
  // 2) 同一 mime 再设 → 原行替换（不留第二行）
  assert_true(da_set_default("text/plain", "nvim.desktop") is Ok(_))
  match sys_read_text_file(file) {
    Some(c) => {
      assert_true(c.contains("text/plain=nvim.desktop"))
      assert_true(!c.contains("gedit.desktop"))
    }
    None => assert_true(false)
  }
  // 3) 另一个 mime → 段内追加
  assert_true(da_set_default("inode/directory", "thunar.desktop") is Ok(_))
  match sys_read_text_file(file) {
    Some(c) => {
      assert_true(c.contains("text/plain=nvim.desktop"))
      assert_true(c.contains("inode/directory=thunar.desktop"))
      // 读回来即认得出（回退解析链路用的就是这张表）
      assert_eq(
        da_section_values(
          da_parse_mimeapps(c),
          "Default Applications",
          "inode/directory",
        ),
        ["thunar.desktop"],
      )
    }
    None => assert_true(false)
  }
  // 4) 非 .desktop 的 id：参数即拒（不写盘）
  assert_true(da_set_default("text/plain", "gedit") is Err(QueryFailed(_)))
  // 复原环境并清临时文件
  match saved {
    Some(v) => {
      let _ = envx_set("XDG_CONFIG_HOME", v)
    }
    None => {
      let _ = envx_unset("XDG_CONFIG_HOME")
    }
  }
  let _ = sys_remove_file(file)
  let _ = pr_run("rmdir", [dir])
}

///|
test "da 本机探测：xdg-mime 文件类型与默认应用查询（有该工具才断言）" {
  if !da_supported() {
    println("da: skip (no xdg-mime)")
    return
  }
  match da_file_type("/etc/hostname") {
    Ok(mime) => assert_true(mime.contains("/"))
    Err(e) => {
      println("da_file_type failed: \{e}")
      assert_true(false)
    }
  }
  // 本机已有默认应用登记(装过编辑器);无登记则 NoDefault,不判失败
  match da_default_for("text/plain") {
    Ok(name) => assert_true(name.has_suffix(".desktop"))
    Err(NoDefault(_)) => println("da: 本机未登记 text/plain 默认应用（合法）")
    Err(e) => {
      println("da_default_for 报了其他错: \{e}")
      assert_true(false)
    }
  }
  // 关联枚举走 mimeapps.list：本机没登记时是空表而不是报错（冒烟读数）
  println("da associations for text/plain: \{da_associations_for("text/plain").length()}")
  // 不支持的平台才给 Unsupported；本机有 xdg-mime 时不该出现
  assert_eq(
    DefaultAppError::Unsupported.to_string(),
    "当前环境不支持默认应用查询（缺少 xdg-mime）",
  )
  assert_eq(
    DefaultAppError::NoDefault("x/y").to_string(),
    "MIME 类型未登记默认应用: x/y",
  )
  assert_eq(
    DefaultAppError::IoFailed("p").to_string(),
    "读写 mimeapps.list 失败: p",
  )
}
