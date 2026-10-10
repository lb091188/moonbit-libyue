// 默认应用查询白盒测试：mimeapps.list 段解析、默认应用合并改写、多文件
// 关联合并与分号拆分；xdg-mime 命令查询仅在本机存在该工具时断言。

///|
test "da mimeapps 解析：段/注释/段外行/首个等号/同名键首个" {
  let content = "[Default Applications]\n# 井号注释\n\ntext/plain=sublime_text.desktop;org.gnome.gedit.desktop;\ntext/plain=second.desktop;\n孤儿行没有等号\n[Added Associations]\ntext/html=firefox.desktop;chromium.desktop;\n"
  let sections = da_parse_mimeapps(content)
  // 两个段
  inspect(sections.length(), content="2")
  inspect(sections[0].0, content="Default Applications")
  inspect(sections[1].0, content="Added Associations")
  // text/plain 出现两次,mimeapps.list 同名键不去重(默认应用后写覆盖先写)
  let plains = da_section_values(sections, "Default Applications", "text/plain")
  inspect(plains.length(), content="2")
  inspect(plains[0], content="sublime_text.desktop;org.gnome.gedit.desktop;")
  inspect(plains[1], content="second.desktop;")
  // Added Associations 正常收录
  let htmls = da_section_values(sections, "Added Associations", "text/html")
  inspect(htmls.length(), content="1")
  // 无等号的段外/段内杂行被跳过(只有合法键进段)
  inspect(sections[1].1.length(), content="1")
}

///|
test "da 合并默认应用行：替换已有/段内追加/无段补段/保留注释" {
  // 1) 已有段 + 已有 mime 行 → 替换
  let replaced = da_merge_default_line(
    "[Default Applications]\ntext/plain=old.desktop;",
    "text/plain",
    "new.desktop",
  )
  inspect(replaced.contains("text/plain=new.desktop") is true, content="true")
  inspect(replaced.contains("old.desktop") is false, content="true")
  // 2) 已有段 + 无该行 → 段内追加
  let appended = da_merge_default_line(
    "[Default Applications]\ntext/html=firefox.desktop;\n[Added Associations]\nx=1\n",
    "text/plain",
    "sublime_text.desktop",
  )
  inspect(
    appended.contains("[Default Applications]\ntext/html=firefox.desktop;\ntext/plain=sublime_text.desktop\n")
      is true,
    content="true",
  )
  // 3) 无目标段 → 文末补段,原内容保留
  let fresh = da_merge_default_line(
    "# 我的配置\n[Added Associations]\ntext/html=firefox.desktop;\n",
    "text/plain",
    "sublime_text.desktop",
  )
  inspect(fresh.contains("# 我的配置") is true, content="true")
  inspect(fresh.contains("[Default Applications]\ntext/plain=sublime_text.desktop\n") is true, content="true")
  // 4) 空内容 → 只有新段
  let empty = da_merge_default_line("", "text/plain", "a.desktop")
  inspect(empty, content="[Default Applications]\ntext/plain=a.desktop\n")
}

///|
test "da 关联合并：默认应用排最前 + 分号拆分去重 + 多文件合并" {
  let texts : Array[String] = [
    "[Added Associations]\ntext/html=firefox.desktop;chromium.desktop;firefox.desktop;\n",
    "[Default Applications]\ntext/html=firefox.desktop;\ntext/html=brave.desktop;\n",
  ]
  let all = da_associations_of_texts(texts, "text/html")
  // 第一个文本的 Added(去重后 two 个),第二个文本的 Default 排前:文件序处理
  // ——当前实现按文本顺序、段内(Died 先 Added 后 Default? 否,Default 先于
  // Added),故:第一个文本 Added 两个 + 第二个文本 Default 去重后只剩 brave
  inspect(all.length(), content="3")
  inspect(all[0], content="firefox.desktop")
  inspect(all[1], content="chromium.desktop")
  inspect(all[2], content="brave.desktop")
  // 未登记的 mime 无关联
  inspect(da_associations_of_texts(texts, "application/x-none").length(), content="0")
}

///|
test "da 真机探测：xdg-mime 文件类型与默认应用查询（存在该工具才断言）" {
  if da_supported() {
    match da_file_type("/etc/hostname") {
      Ok(mime) => inspect(mime.contains("/") is true, content="true")
      Err(e) => inspect(e.to_string(), content="本机 xdg-mime 应能查询 /etc/hostname")
    }
    // 本机已有默认应用登记(装过编辑器);无登记则 NoDefault,不判失败
    match da_default_for("text/plain") {
      Ok(name) => inspect(name.has_suffix(".desktop") is true, content="true")
      Err(NoDefault(_)) => inspect("no default", content="no default（本机未登记默认应用,合法）")
      Err(e) => inspect(e.to_string(), content="查询链路不应报其他错")
    }
  } else {
    // 无 xdg-mime 的平台（Windows / 最小系统）走此分支
    inspect("skipped", content="skipped")
  }
}
