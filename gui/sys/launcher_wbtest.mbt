// 打开外部白盒测试：父目录与相对路径归一的纯函数、当前工作目录真实读数、
// 分离式启动的成功/失败/不阻塞三态。open_url 与 reveal_in_file_manager 会
// 真的把窗口交给桌面环境，用例只断平台门与错误归一，实际拉起由示例回证。

///|
test {
  // 父目录：多级/单级/根/无斜杠/空串
  assert_eq(parent_dir("/a/b/c"), "/a/b")
  assert_eq(parent_dir("/c"), "/")
  assert_eq(parent_dir("plain"), ".")
  assert_eq(parent_dir(""), ".")
  assert_eq(parent_dir("/a/b/"), "/a/b")
  // 相对路径归一：绝对路径与 cwd 缺失都原样，空串不拼
  assert_eq(launcher_abs_path("/a/b", "/cwd"), "/a/b")
  assert_eq(launcher_abs_path("b", "/cwd"), "/cwd/b")
  assert_eq(launcher_abs_path("b", ""), "b")
  assert_eq(launcher_abs_path("", "/cwd"), "")
}

///|
test {
  // 当前工作目录：真实读得到且是绝对路径。Windows 的绝对路径形如
  // "D:\code\…"（盘符 + 冒号）或 UNC "\\<主机>\共享"，POSIX 以 / 起。
  let cwd = current_dir()
  assert_true(cwd != "")
  if sys_platform() == "windows" {
    // 形如 "D:\…"：下标 0 是盘符、1 是冒号（0-based，别把冒号当成第 2 位）
    let drive_abs =
      cwd.length() > 2 &&
      cwd[1].to_int() == 58 && // ':'
      ((cwd[0].to_int() >= 65 && cwd[0].to_int() <= 90) ||
        (cwd[0].to_int() >= 97 && cwd[0].to_int() <= 122))
    assert_true(drive_abs || cwd.has_prefix("\\\\"), msg="非绝对路径: \{cwd}")
  } else {
    assert_true(cwd.has_prefix("/"))
  }
}

///|
test {
  // 分离式启动：命令名为空与命令不存在都失败，`true` 交得出去。
  // Windows 侧正例走 ShellExecuteW，成功即真的拉起一个进程（`true.exe` 在
  // PATH 里不一定存在，取决于是否从 Git Bash 起），故只断负例；正例与
  // 「不阻塞」由 examples/systemprobe 的按钮在真机回证（设置类动作归使用者）。
  assert_true(spawn_detached("", "x") is Err(_))
  assert_true(spawn_detached("launcher_no_such_bin_zzz", "x") is Err(_))
  if sys_platform() == "windows" {
    println("launcher: skip (posix-only 正例与不阻塞)")
  } else {
    assert_true(spawn_detached("true", "") is Ok(_))
  }
}

///|
test {
  // 不阻塞：`sleep 3` 交给系统后立即返回（等它退出才是这层要排除的行为）
  if sys_platform() == "windows" {
    println("launcher: skip (posix-only 不阻塞)")
  } else {
    let started = @env.now()
    assert_true(spawn_detached("sleep", "3") is Ok(_))
    let spent = (@env.now() - started).to_int()
    assert_true(spent < 500)
  }
}

///|
test {
  // 平台门：Linux 下两个入口都是语义化 Result；非 Linux 给 Unsupported
  assert_eq(OpenUrlError::Unsupported.to_string(), "OpenUrlError::Unsupported")
  assert_eq(OpenUrlError::SpawnFailed.to_string(), "OpenUrlError::SpawnFailed")
  assert_eq(
    FileManagerError::Unsupported.to_string(),
    "FileManagerError::Unsupported",
  )
  assert_eq(
    FileManagerError::SpawnFailed.to_string(),
    "FileManagerError::SpawnFailed",
  )
  if open_supported() {
    // 后端在（Windows 直调 / Linux xdg-open / macOS open）。**不在这里真调
    // open_url / open_file / reveal**：`ShellExecuteW` 对未注册的协议**不返错**，
    // 而是把系统「需要使用新应用以打开…」的选择器拉起来——旧版这里拿
    // `libyue-invalid-probe://` 当"无效目标探针"，注释写着「不弹窗」是错的，
    // 每跑一次 `moon test sys` 就在开发者机器上弹一次窗（用户实测）。
    // 真开动作有系统副作用，只归示例与真机复验（S28）；这里只断纯判据 + 负例。
    assert_true(open_supported())
    assert_true(open_file("") is Err(NotFound))
    // reveal 的 macOS 分支还没接（只 windows/linux），所以那里给 Unsupported
    assert_true(
      reveal_in_file_manager("") is Err(NotFound) ||
        reveal_in_file_manager("") is Err(Unsupported),
    )
    assert_true(open_file_with("", "TODO.md") is Err(SpawnFailed))
  } else {
    assert_true(open_url("https://libyue.com") is Err(Unsupported))
    assert_true(open_file("TODO.md") is Err(Unsupported))
    assert_true(reveal_in_file_manager("/tmp") is Err(Unsupported))
  }
}

///|
test {
  // 绝对判据要认三种写法：POSIX 的 /、Windows 的盘符与 UNC/当前盘根。
  // 只看前导 '/' 会把 "C:\a\b.txt" 当相对路径拼进 cwd，产出
  // "<cwd>/C:\a\b.txt" 这种垃圾（真机踩过：文件管理器定位与打开都不对）。
  assert_true(launcher_path_absolute("/etc/passwd"))
  assert_true(launcher_path_absolute("\\\\srv\\share\\x"))
  assert_true(launcher_path_absolute("\\当前盘根\\x"))
  assert_true(launcher_path_absolute("C:\\a\\b.txt"))
  assert_true(launcher_path_absolute("d:/a/b.txt"))
  assert_false(launcher_path_absolute("TODO.md"))
  assert_false(launcher_path_absolute("文档/报告.doc"))
  assert_false(launcher_path_absolute(""))
  assert_false(launcher_path_absolute("C:")) // 盘符相对不算绝对
  // 归一：已绝对的原样（含 Windows 三条），相对才拼 cwd
  assert_eq(launcher_abs_path("C:\\a\\b.txt", "D:\\w"), "C:\\a\\b.txt")
  assert_eq(launcher_abs_path("\\\\srv\\x", "/cwd"), "\\\\srv\\x")
  assert_eq(launcher_abs_path("/a/b", "/cwd"), "/a/b")
  assert_eq(launcher_abs_path("b", "/cwd"), "/cwd/b")
  assert_eq(launcher_abs_path("b", ""), "b")
  assert_eq(launcher_abs_path("", "/cwd"), "")
}

///|
test {
  // Windows 形态：分隔符统一成反斜杠，且中文与已正确的串都不被写坏
  // （混着给时 explorer 的 /select 不选中，所以交出去之前先统一）
  assert_eq(launcher_win_path("C:/Users/u/ proj/TODO.md"), "C:\\Users\\u\\ proj\\TODO.md")
  assert_eq(launcher_win_path("C:\\a\\b.txt"), "C:\\a\\b.txt")
  assert_eq(launcher_win_path("C:/文档/报告.doc"), "C:\\文档\\报告.doc")
  assert_eq(launcher_win_path(""), "")
  // 混合输入也一致（cwd 给反斜杠、用户给正斜杠）
  let mixed = launcher_abs_path("docs/zh/adaptation.md", "C:\\repo")
  assert_eq(launcher_win_path(mixed), "C:\\repo\\docs\\zh\\adaptation.md")
}

///|
test {
  // 路径存在判据：真实读数（工作目录必在、拼一个不存在的名字必不在）。
  // win_path 的回读只在 Windows 形态下断——它只在 Windows 平台分支交出去之前
  // 用，Linux 上把 POSIX 路径换成反斜杠串后 stat 本来就不认（非 Windows 改验
  // 绝对化归一不把存在的路径写坏）
  let cwd = current_dir()
  assert_true(cwd != "")
  assert_true(sys_path_exists(cwd))
  if sys_platform() == "windows" {
    assert_true(sys_path_exists(launcher_win_path(cwd)))
  } else {
    assert_true(sys_path_exists(launcher_abs_path(cwd, cwd)))
  }
  assert_false(sys_path_exists(cwd + "/launcher_no_such_file_zzz.md"))
  assert_false(sys_path_exists(""))
}

///|
test {
  // 打开面：只断「在交出去之前就能拦下的那些」——空路径、不存在的路径、空程序名，
  // 三条都不该产生系统副作用（真开浏览器/编辑器的事交给示例与真机）
  assert_true(open_file("") is Err(NotFound))
  assert_true(
    open_file("launcher_no_such_file_zzz.md") is Err(NotFound) ||
      open_file("launcher_no_such_file_zzz.md") is Err(Unsupported),
  )
  assert_true(open_file_with("", "TODO.md") is Err(SpawnFailed))
  assert_true(
    open_file_with("notepad.exe", "launcher_no_such_file_zzz.md") is Err(NotFound) ||
      open_file_with("notepad.exe", "launcher_no_such_file_zzz.md") is Err(Unsupported),
  )
  assert_eq(OpenFileError::Unsupported.to_string(), "OpenFileError::Unsupported")
  assert_eq(OpenFileError::NotFound.to_string(), "OpenFileError::NotFound")
  assert_eq(
    OpenFileError::SpawnFailed.to_string(),
    "OpenFileError::SpawnFailed",
  )
  assert_eq(FileManagerError::NotFound.to_string(), "FileManagerError::NotFound")
  // 定位面同一条口径：不存在的路径不假装「已交给系统」
  assert_true(reveal_in_file_manager("") is Err(NotFound) || reveal_in_file_manager("") is Err(Unsupported))
  assert_true(
    reveal_in_file_manager("launcher_no_such_file_zzz.md") is Err(NotFound) ||
      reveal_in_file_manager("launcher_no_such_file_zzz.md") is Err(Unsupported),
  )
}
