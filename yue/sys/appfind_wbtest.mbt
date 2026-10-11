// 应用查找白盒测试：INI 子集解析（注释/空行/组切换/同名键）、条目过滤
// 与 zh_CN 回退、去重合并排序、目录拼装；扫描与可执行查找按真实文件系统
// 断言（不存在的目录/文件静默跳过）。

///|
/// 真实读盘用例的样本落点。
fn af_tmp() -> String { "/tmp" }

///|
test "appfind INI 子集解析：注释/空行/组切换/首等号拆分/同名键首个生效" {
  let content = "[Desktop Entry]\n# 井号注释\n\n; 分号注释\r\nName = 首个名字\nName=第二个名字\nName[zh_CN]=中文名\nGenericName=通用名\nExec=env FOO=a=b foo %U\nIcon=foo-icon\nCategories=Utility;FileTools;\r\nNoDisplay=false\nNoEqualsHere\n[Desktop Action New]\nName=动作名\nExec=action-exec\n"
  let pairs = appfind_parse_desktop_entry(content)
  // 收录：Name/Name[zh_CN]/GenericName/Exec/Icon/Categories/NoDisplay 共 7 对
  assert_eq(pairs.length(), 7)
  // 同名键首个生效 + 键值首尾空白去除
  assert_eq(appfind_kv_get(pairs, "Name"), "首个名字")
  assert_eq(appfind_kv_get(pairs, "Name[zh_CN]"), "中文名")
  assert_eq(appfind_kv_get(pairs, "GenericName"), "通用名")
  // 首个 = 拆键值：值内 = 保留
  assert_eq(appfind_kv_get(pairs, "Exec"), "env FOO=a=b foo %U")
  // \r\n 行尾随空白去除（值尾分号保留）
  assert_eq(appfind_kv_get(pairs, "Categories"), "Utility;FileTools;")
  assert_eq(appfind_kv_get(pairs, "NoDisplay"), "false")
  // 无该键给空串
  assert_eq(appfind_kv_get(pairs, "Comment"), "")
  // [Desktop Entry] 之外整组忽略
  assert_true(!appfind_pairs_has(pairs, "动作名"))
  // 无 [Desktop Entry] 组头：全不收录
  assert_eq(appfind_parse_desktop_entry("Name=孤儿\nExec=x\n").length(), 0)
}

///|
test "appfind 条目抽取：Type/NoDisplay/缺 Name 过滤与 zh_CN 回退" {
  let sample = "[Desktop Entry]\nType=Application\nName=Files\nName[zh_CN]=文件\nExec=nautilus %U\nIcon=org.gnome.Files\nCategories=System;FileTools;\n"
  match appfind_desktop_to_entry(sample, "org.gnome.Files") {
    Some(v) => {
      assert_eq(v.id, "org.gnome.Files")
      assert_eq(v.name, "Files")
      assert_eq(v.locale_name, "文件")
      assert_eq(v.exec, "nautilus %U")
      assert_eq(v.icon, "org.gnome.Files")
      assert_eq(v.categories, ["System", "FileTools"])
    }
    None => assert_true(false)
  }
  // 无 zh_CN：locale_name 回退 Name
  match
    appfind_desktop_to_entry("[Desktop Entry]\nName=Plain\nExec=p\n", "plain") {
    Some(v) => assert_eq(v.locale_name, "Plain")
    None => assert_true(false)
  }
  // NoDisplay=true：过滤
  assert_true(
    appfind_desktop_to_entry("[Desktop Entry]\nName=Hide\nNoDisplay=true\n", "hide")
    is None,
  )
  // Type=Link：过滤；缺 Type 行视为 Application
  assert_true(
    appfind_desktop_to_entry("[Desktop Entry]\nType=Link\nName=L\n", "l") is None,
  )
  assert_true(
    appfind_desktop_to_entry("[Desktop Entry]\nName=T\n", "t") is Some(_),
  )
  // 缺 Name：过滤
  assert_true(
    appfind_desktop_to_entry("[Desktop Entry]\nExec=only-exec\n", "x") is None,
  )
  // categories 全空/分号尾巴：空数组
  match
    appfind_desktop_to_entry("[Desktop Entry]\nName=C\nCategories=;; ;\n", "c") {
    Some(v) => assert_eq(v.categories.length(), 0)
    None => assert_true(false)
  }
  assert_eq(appfind_split_semi(";; ;"), [])
  // 分号列表：去空项与首尾空白
  assert_eq(appfind_split_semi("A; B;;C ;"), ["A", "B", "C"])
}

///|
test "appfind 去重合并：用户覆盖系统 + 按 name 排序" {
  let sys : Array[AppEntry] = [
    {
      id: "b.app",
      name: "Beta",
      locale_name: "Beta",
      exec: "beta",
      icon: "",
      categories: [],
    },
    {
      id: "a.app",
      name: "Alpha",
      locale_name: "Alpha",
      exec: "alpha",
      icon: "",
      categories: [],
    },
    {
      id: "dup.app",
      name: "Old",
      locale_name: "Old",
      exec: "old",
      icon: "",
      categories: [],
    },
  ]
  let user : Array[AppEntry] = [
    {
      id: "dup.app",
      name: "New",
      locale_name: "新",
      exec: "new",
      icon: "",
      categories: [],
    },
  ]
  let out = appfind_merge_entries([sys, user])
  assert_eq(out.length(), 3)
  assert_eq(out[0].id, "a.app")
  assert_eq(out[1].id, "b.app")
  assert_eq(out[2].id, "dup.app")
  assert_eq(out[2].name, "New")
  assert_eq(out[2].locale_name, "新")
  // 入参数组不被修改
  assert_eq(sys[2].name, "Old")
  assert_eq(sys.length(), 3)
}

///|
test "appfind 目录拼装：用户目录三态 + 扫描序 + bin 查找序" {
  // XDG_DATA_HOME 设且非空：优先
  assert_true(
    appfind_user_apps_dir(Some("/xdg"), Some("/home/u"))
    is Some("/xdg/applications"),
  )
  // 空串：回退 HOME
  assert_true(
    appfind_user_apps_dir(Some(""), Some("/home/u"))
    is Some("/home/u/.local/share/applications"),
  )
  // 未设：回退 HOME
  assert_true(
    appfind_user_apps_dir(None, Some("/home/u"))
    is Some("/home/u/.local/share/applications"),
  )
  // 都没有：None
  assert_true(appfind_user_apps_dir(None, None) is None)
  // 扫描序：系统两处 + 用户（低→高优先级）
  let scan = appfind_scan_dirs(None, Some("/home/u"))
  assert_eq(scan, [
    "/usr/share/applications",
    "/usr/local/share/applications",
    "/home/u/.local/share/applications",
  ])
  assert_eq(
    appfind_scan_dirs(None, None),
    ["/usr/share/applications", "/usr/local/share/applications"],
  )
  // bin 查找序：用户 bin 优先，再系统
  assert_eq(appfind_bin_dirs(Some("/home/u")), [
    "/home/u/.local/bin",
    "/usr/local/bin",
    "/usr/bin",
    "/bin",
    "/usr/sbin",
    "/sbin",
  ])
  assert_eq(
    appfind_bin_dirs(None),
    ["/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"],
  )
  // 码点字典序：不按长度先排（String 默认 shortlex 会把 "New" 排在 "Beta" 前）
  assert_true(appfind_str_cmp("Alpha", "Beta") < 0)
  assert_true(appfind_str_cmp("New", "Beta") > 0)
  assert_eq(appfind_str_cmp("same", "same"), 0)
  assert_true(appfind_str_cmp("app", "apple") < 0)
}

///|
test "appfind_collect：真实读盘 + 非 .desktop 过滤 + 路径只留文件名" {
  let path = af_tmp() + "/appfind_wbtest_sample.desktop"
  assert_true(
    sys_write_text_file(
      path, "[Desktop Entry]\nType=Application\nName=Sample\nName[zh_CN]=示例\nExec=/opt/sample %U\nIcon=sample\nCategories=Development;\n",
    ),
  )
  let dir = af_tmp()
  let fname = "appfind_wbtest_sample.desktop"
  let out = appfind_collect([dir], fn(d) {
    if d == dir {
      [fname, "not_desktop.txt", ".desktop", dir + "/" + fname]
    } else {
      []
    }
  })
  // 非 .desktop、名为 ".desktop"、带路径重复项：只剩 1 条
  assert_eq(out.length(), 1)
  assert_eq(out[0].id, "appfind_wbtest_sample")
  assert_eq(out[0].name, "Sample")
  assert_eq(out[0].locale_name, "示例")
  assert_eq(out[0].exec, "/opt/sample %U")
  assert_true(sys_remove_file(path))
}

///|
test "appfind_collect：目录读不到静默跳过（空清单不报错）" {
  let out = appfind_collect(["/nonexistent-appfind-dir"], fn(_dir) {
    ["ghost.desktop"]
  })
  assert_eq(out.length(), 0)
  // 解析后全被过滤（NoDisplay）：同样空清单
  let path = af_tmp() + "/appfind_wbtest_hidden.desktop"
  assert_true(sys_write_text_file(path, "[Desktop Entry]\nName=H\nNoDisplay=true\n"))
  let dir = af_tmp()
  let out2 = appfind_collect([dir], fn(d) {
    if d == dir {
      ["appfind_wbtest_hidden.desktop"]
    } else {
      []
    }
  })
  assert_eq(out2.length(), 0)
  assert_true(sys_remove_file(path))
}

///|
test "appfind_installed_with：注入枚举" {
  // 注入空枚举：Ok 空清单（Linux 主链路）
  match appfind_installed_with(fn(_dir) { [] }) {
    Ok(entries) => assert_eq(entries.length(), 0)
    Err(_) => assert_true(sys_platform() != "linux")
  }
}

///|
test "appfind_installed_impl：目录全打不开 Err(NoScanDir)，部分存在只扫存在的" {
  // 全部目录都打不开：NoScanDir（不再伪装空清单）
  assert_true(
    appfind_installed_impl(
      ["/nonexistent-appfind-zz-1", "/nonexistent-appfind-zz-2"],
      fn(dir) { Err(OpenFailed(dir)) },
    )
    is Err(NoScanDir),
  )
  // 部分目录打不开：跳过，存在的照扫
  let path = af_tmp() + "/appfind_wbtest_real.desktop"
  assert_true(
    sys_write_text_file(
      path, "[Desktop Entry]\nType=Application\nName=RealScan\nExec=real %U\n",
    ),
  )
  let dir = af_tmp()
  match
    appfind_installed_impl(["/nonexistent-appfind-zz-1", dir], fn(d) {
      if d == dir {
        Ok(["appfind_wbtest_real.desktop"])
      } else {
        Err(OpenFailed(d))
      }
    }) {
    Ok(entries) => {
      assert_eq(entries.length(), 1)
      assert_eq(entries[0].id, "appfind_wbtest_real")
      assert_eq(entries[0].name, "RealScan")
    }
    Err(e) => {
      println("应成功，实得: \{e}")
      assert_true(false)
    }
  }
  assert_true(sys_remove_file(path))
}

///|
test "appfind_installed：真实扫描 /usr/share/applications 必有条目" {
  if sys_platform() != "linux" {
    println("appfind: skip (non-linux)")
    return
  }
  match appfind_installed() {
    Ok(entries) => assert_true(entries.length() > 0)
    Err(e) => {
      println("appfind_installed failed: \{e}")
      assert_true(false)
    }
  }
}

///|
test "appfind_executable：真实目录探测与参数防御" {
  if sys_platform() != "linux" {
    println("appfind: skip (non-linux)")
    return
  }
  // /usr/bin 先于 /bin：sh 命中 /usr/bin/sh（本链路宿主机必有）
  match appfind_executable("sh") {
    Ok(p) => assert_eq(p, "/usr/bin/sh")
    Err(e) => {
      println("appfind_executable sh failed: \{e}")
      assert_true(false)
    }
  }
  // 找不到：NotFound 带查找名
  assert_true(
    appfind_executable("appfind_no_such_bin_zzz")
    is Err(NotFound("appfind_no_such_bin_zzz")),
  )
  // 空名 / 含路径分隔符：直接 NotFound
  assert_true(appfind_executable("") is Err(NotFound("")))
  assert_true(appfind_executable("a/b") is Err(NotFound("a/b")))
}
