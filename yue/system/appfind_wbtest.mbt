// 应用查找白盒测试：INI 子集解析（注释/空行/组切换/同名键）、条目过滤
// 与 zh_CN 回退、去重合并排序、目录拼装；扫描与可执行查找按真实文件
// 系统断言（不存在的目录/文件静默跳过）。

///|
test "appfind INI 子集解析：注释/空行/组切换/首等号拆分/同名键首个生效" {
  let content = "[Desktop Entry]\n# 井号注释\n\n; 分号注释\r\nName = 首个名字\nName=第二个名字\nName[zh_CN]=中文名\nGenericName=通用名\nExec=env FOO=a=b foo %U\nIcon=foo-icon\nCategories=Utility;FileTools;\r\nNoDisplay=false\nNoEqualsHere\n[Desktop Action New]\nName=动作名\nExec=action-exec\n"
  let pairs = appfind_parse_desktop_entry(content)
  // 收录：Name/Name[zh_CN]/GenericName/Exec/Icon/Categories/NoDisplay 共 7 对
  inspect(pairs.length(), content="7")
  // 同名键首个生效 + 键值首尾空白去除
  inspect(appfind_kv_get(pairs, "Name"), content="首个名字")
  inspect(appfind_kv_get(pairs, "Name[zh_CN]"), content="中文名")
  inspect(appfind_kv_get(pairs, "GenericName"), content="通用名")
  // 首个 = 拆键值：值内 = 保留
  inspect(appfind_kv_get(pairs, "Exec"), content="env FOO=a=b foo %U")
  // \r\n 行尾随空白去除（值尾分号保留）
  inspect(appfind_kv_get(pairs, "Categories"), content="Utility;FileTools;")
  inspect(appfind_kv_get(pairs, "NoDisplay"), content="false")
  // 无该键给空串
  inspect(appfind_kv_get(pairs, "Comment"), content="")
  // [Desktop Entry] 之外整组忽略
  inspect(appfind_pairs_has(pairs, "动作名") is false, content="true")
  // 无 [Desktop Entry] 组头：全不收录
  inspect(
    appfind_parse_desktop_entry("Name=孤儿\nExec=x\n").length(),
    content="0",
  )
}

///|
test "appfind 条目抽取：Type/NoDisplay/缺 Name 过滤与 zh_CN 回退" {
  let sample = "[Desktop Entry]\nType=Application\nName=Files\nName[zh_CN]=文件\nExec=nautilus %U\nIcon=org.gnome.Files\nCategories=System;FileTools;\n"
  match appfind_desktop_to_entry(sample, "org.gnome.Files") {
    Some(v) => {
      inspect(v.id, content="org.gnome.Files")
      inspect(v.name, content="Files")
      inspect(v.locale_name, content="文件")
      inspect(v.exec, content="nautilus %U")
      inspect(v.icon, content="org.gnome.Files")
      debug_inspect(v.categories, content="[\"System\", \"FileTools\"]")
    }
    None => inspect(false, content="true")
  }
  // 无 zh_CN：locale_name 回退 Name
  match
    appfind_desktop_to_entry("[Desktop Entry]\nName=Plain\nExec=p\n", "plain") {
    Some(v) => inspect(v.locale_name, content="Plain")
    None => inspect(false, content="true")
  }
  // NoDisplay=true：过滤
  inspect(
    appfind_desktop_to_entry(
      "[Desktop Entry]\nName=Hide\nNoDisplay=true\n", "hide",
    )
    is None,
    content="true",
  )
  // Type=Link：过滤；缺 Type 行视为 Application
  inspect(
    appfind_desktop_to_entry("[Desktop Entry]\nType=Link\nName=L\n", "l")
    is None,
    content="true",
  )
  inspect(
    appfind_desktop_to_entry("[Desktop Entry]\nName=T\n", "t") is Some(_),
    content="true",
  )
  // 缺 Name：过滤
  inspect(
    appfind_desktop_to_entry("[Desktop Entry]\nExec=only-exec\n", "x") is None,
    content="true",
  )
  // categories 全空/分号尾巴：空数组
  match
    appfind_desktop_to_entry("[Desktop Entry]\nName=C\nCategories=;; ;\n", "c") {
    Some(v) => debug_inspect(v.categories, content="[]")
    None => inspect(false, content="true")
  }
  debug_inspect(appfind_split_semi(";; ;"), content="[]")
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
  inspect(out.length(), content="3")
  inspect(out[0].id, content="a.app")
  inspect(out[1].id, content="b.app")
  inspect(out[2].id, content="dup.app")
  inspect(out[2].name, content="New")
  inspect(out[2].locale_name, content="新")
  // 入参数组不被修改
  inspect(sys[2].name, content="Old")
  inspect(sys.length(), content="3")
}

///|
test "appfind 目录拼装：用户目录三态 + 扫描序 + bin 查找序" {
  // XDG_DATA_HOME 设且非空：优先
  inspect(
    appfind_user_apps_dir(Some("/xdg"), Some("/home/u"))
    is Some("/xdg/applications"),
    content="true",
  )
  // 空串：回退 HOME
  inspect(
    appfind_user_apps_dir(Some(""), Some("/home/u"))
    is Some("/home/u/.local/share/applications"),
    content="true",
  )
  // 未设：回退 HOME
  inspect(
    appfind_user_apps_dir(None, Some("/home/u"))
    is Some("/home/u/.local/share/applications"),
    content="true",
  )
  // 都没有：None
  inspect(appfind_user_apps_dir(None, None) is None, content="true")
  // 扫描序：系统两处 + 用户（低→高优先级）
  let scan = appfind_scan_dirs(None, Some("/home/u"))
  inspect(scan.length(), content="3")
  inspect(scan[0], content="/usr/share/applications")
  inspect(scan[1], content="/usr/local/share/applications")
  inspect(scan[2], content="/home/u/.local/share/applications")
  let scan2 = appfind_scan_dirs(None, None)
  inspect(scan2.length(), content="2")
  inspect(scan2[0], content="/usr/share/applications")
  inspect(scan2[1], content="/usr/local/share/applications")
  // bin 查找序：用户 bin 优先，再系统
  let bins = appfind_bin_dirs(Some("/home/u"))
  inspect(bins.length(), content="6")
  inspect(bins[0], content="/home/u/.local/bin")
  inspect(bins[1], content="/usr/local/bin")
  inspect(bins[2], content="/usr/bin")
  inspect(bins[3], content="/bin")
  inspect(bins[4], content="/usr/sbin")
  inspect(bins[5], content="/sbin")
  let bins2 = appfind_bin_dirs(None)
  inspect(bins2.length(), content="5")
  inspect(bins2[0], content="/usr/local/bin")
  inspect(bins2[4], content="/sbin")
  // 码点字典序：不按长度先排（String 默认 shortlex 会把 "New" 排在 "Beta" 前）
  inspect(appfind_str_cmp("Alpha", "Beta") < 0, content="true")
  inspect(appfind_str_cmp("New", "Beta") > 0, content="true")
  inspect(appfind_str_cmp("same", "same"), content="0")
  inspect(appfind_str_cmp("app", "apple") < 0, content="true")
}

///|
test "appfind_collect：真实读盘 + 非 .desktop 过滤 + 路径只留文件名" {
  let path = "/tmp/appfind_wbtest_sample.desktop"
  let written = @yue.write_text_file(
    path, "[Desktop Entry]\nType=Application\nName=Sample\nName[zh_CN]=示例\nExec=/opt/sample %U\nIcon=sample\nCategories=Development;\n",
  )
  inspect(written, content="true")
  let out = appfind_collect(["/tmp"], fn(dir) {
    if dir == "/tmp" {
      [
        "appfind_wbtest_sample.desktop", "not_desktop.txt", ".desktop", "/tmp/appfind_wbtest_sample.desktop",
      ]
    } else {
      []
    }
  })
  // 非 .desktop、名为 ".desktop"、带路径重复项：只剩 1 条
  inspect(out.length(), content="1")
  inspect(out[0].id, content="appfind_wbtest_sample")
  inspect(out[0].name, content="Sample")
  inspect(out[0].locale_name, content="示例")
  inspect(out[0].exec, content="/opt/sample %U")
  // 清理
  let ok = Ref(0)
  ignore(@yue.ffi_remove_file(@yue.utf8_bytes(path), ok))
}

///|
test "appfind_collect：目录读不到静默跳过（空清单不报错）" {
  let out = appfind_collect(["/nonexistent-appfind-dir"], fn(_dir) {
    ["ghost.desktop"]
  })
  inspect(out.length(), content="0")
  // 解析后全被过滤（NoDisplay）：同样空清单
  let path = "/tmp/appfind_wbtest_hidden.desktop"
  ignore(@yue.write_text_file(path, "[Desktop Entry]\nName=H\nNoDisplay=true\n"))
  let out2 = appfind_collect(["/tmp"], fn(dir) {
    if dir == "/tmp" {
      ["appfind_wbtest_hidden.desktop"]
    } else {
      []
    }
  })
  inspect(out2.length(), content="0")
  let ok = Ref(0)
  ignore(@yue.ffi_remove_file(@yue.utf8_bytes(path), ok))
}

///|
test "appfind_installed_with：注入枚举" {
  // 注入空枚举：Ok 空清单
  inspect(appfind_installed_with(fn(_dir) { [] }) is Ok(_), content="true")
}

///|
test "appfind_installed_impl：目录全打不开 Err(NoScanDir)，部分存在只扫存在的" {
  // 全部目录都打不开：NoScanDir（不再伪装空清单）
  match
    appfind_installed_impl(
      ["/nonexistent-appfind-zz-1", "/nonexistent-appfind-zz-2"],
      fn(dir) { Err(@yue.OpenFailed(dir)) },
    ) {
    Err(NoScanDir) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
  // 部分目录打不开：跳过，存在的照扫
  let path = "/tmp/appfind_wbtest_real.desktop"
  ignore(
    @yue.write_text_file(
      path, "[Desktop Entry]\nType=Application\nName=RealScan\nExec=real %U\n",
    ),
  )
  match
    appfind_installed_impl(["/nonexistent-appfind-zz-1", "/tmp"], fn(dir) {
      if dir == "/tmp" {
        Ok(["appfind_wbtest_real.desktop"])
      } else {
        Err(@yue.OpenFailed(dir))
      }
    }) {
    Ok(entries) => {
      inspect(entries.length(), content="1")
      inspect(entries[0].id, content="appfind_wbtest_real")
      inspect(entries[0].name, content="RealScan")
    }
    Err(e) => {
      inspect(e.to_string(), content="<应成功>")
      inspect(false, content="true")
    }
  }
  ignore(@yue.ffi_remove_file(@yue.utf8_bytes(path), Ref(0)))
}

///|
test "appfind_installed：真实扫描（本链路宿主机 /usr/share/applications 必有）" {
  match appfind_installed() {
    Ok(entries) => inspect(entries.length() > 0, content="true")
    Err(e) => {
      inspect(e.to_string(), content="<应成功>")
      inspect(false, content="true")
    }
  }
}

///|
test "appfind_executable：真实目录探测" {
  // /usr/bin 先于 /bin：sh 命中 /usr/bin/sh（本链路宿主机必有）
  match appfind_executable("sh") {
    Ok(p) => inspect(p, content="/usr/bin/sh")
    Err(_) => inspect(false, content="true")
  }
  // 找不到：NotFound 带查找名
  match appfind_executable("appfind_no_such_bin_zzz") {
    Err(NotFound(n)) => inspect(n, content="appfind_no_such_bin_zzz")
    _ => inspect(false, content="true")
  }
  // 空名 / 含路径分隔符：直接 NotFound
  match appfind_executable("") {
    Err(NotFound(n)) => inspect(n, content="")
    _ => inspect(false, content="true")
  }
  match appfind_executable("a/b") {
    Err(NotFound(n)) => inspect(n, content="a/b")
    _ => inspect(false, content="true")
  }
}
