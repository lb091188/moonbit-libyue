// 文件系统与环境变量白盒测试：扁平文本解码为纯函数断言；目录枚举与
// 环境变量写删按真实环境断言（临时文件建在平台临时目录：POSIX 的
// $TMPDIR、Windows 的 %TEMP%，清理命令按平台选；环境变量写的是测试
// 进程自身环境，随进程退出即逝，不触碰系统配置）。

///|
test "fsx 扁平文本解码：按 '\\n' 拆分去空行" {
  debug_inspect(
    fsx_decode_names(@utf8.encode("a.desktop\nb.desktop\n")),
    content="[\"a.desktop\", \"b.desktop\"]",
  )
  debug_inspect(fsx_decode_names(@utf8.encode("")), content="[]")
  debug_inspect(
    fsx_decode_names(@utf8.encode("唯一\n")),
    content="[\"唯一\"]",
  )
  debug_inspect(fsx_decode_names(@utf8.encode("\n\n")), content="[]")
}

///|
test "fsx_list_dir：真实目录枚举（临时文件可见，不含 . ..）" {
  let f1 = "/tmp/fsx_wbtest_a.txt"
  let f2 = "/tmp/fsx_wbtest_b.txt"
  inspect(sys_write_text_file(f1, "x"), content="true")
  inspect(sys_write_text_file(f2, "y"), content="true")
  match fsx_list_dir("/tmp") {
    Ok(names) => {
      let mut has_a = false
      let mut has_b = false
      let mut dot_entries = false
      for n in names {
        if n == "fsx_wbtest_a.txt" {
          has_a = true
        } else if n == "fsx_wbtest_b.txt" {
          has_b = true
        } else if n == "." || n == ".." {
          dot_entries = true
        }
      }
      inspect(has_a, content="true")
      inspect(has_b, content="true")
      inspect(dot_entries, content="false")
    }
    Err(e) => {
      inspect(e.to_string(), content="<应成功>")
      inspect(false, content="true")
    }
  }
  ignore(sys_remove_file(f1))
  ignore(sys_remove_file(f2))
}

///|
test "fsx_list_dir：打不开/空串/非目录" {
  // 不存在的目录：OpenFailed 带原路径
  match fsx_list_dir("/nonexistent-fsx-dir-zz") {
    Err(OpenFailed(p)) => inspect(p, content="/nonexistent-fsx-dir-zz")
    _ => inspect(false, content="true")
  }
  // 空串：InvalidParam
  match fsx_list_dir("") {
    Err(InvalidParam(m)) => inspect(m, content="路径为空")
    _ => inspect(false, content="true")
  }
  // 指向普通文件（非目录）：OpenFailed
  let f = "/tmp/fsx_wbtest_notdir.txt"
  ignore(sys_write_text_file(f, "x"))
  match fsx_list_dir(f) {
    Err(OpenFailed(p)) => inspect(p, content=f)
    _ => inspect(false, content="true")
  }
  ignore(sys_remove_file(f))
}

///|
test "fsx_set_env / fsx_unset_env：进程内写读改删回环" {
  let name = "FSX_WBTEST_VAR"
  // 写入后立即可读（仅本进程）
  inspect(fsx_set_env(name, "值42", true) is Ok(_), content="true")
  assert_eq(sys_getenv(name), Some("值42"))
  // overwrite=false：已存在保持原值，仍 Ok
  inspect(fsx_set_env(name, "other", false) is Ok(_), content="true")
  assert_eq(sys_getenv(name), Some("值42"))
  // 删除后读不到（ok=0）
  inspect(fsx_unset_env(name) is Ok(_), content="true")
  assert_eq(sys_getenv(name), None)
  // 幂等：再删一次仍 Ok
  inspect(fsx_unset_env(name) is Ok(_), content="true")
  // 空名：InvalidParam
  match fsx_set_env("", "v", true) {
    Err(InvalidParam(_)) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
  match fsx_unset_env("") {
    Err(InvalidParam(_)) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
  // 名字含 '='：C 层拒绝为 EnvFailed
  match fsx_set_env("a=b", "v", true) {
    Err(EnvFailed(n)) => inspect(n, content="a=b")
    _ => inspect(false, content="true")
  }
  match fsx_unset_env("a=b") {
    Err(EnvFailed(n)) => inspect(n, content="a=b")
    _ => inspect(false, content="true")
  }
}

///|
/// 平台临时目录根：Windows 读 %TEMP%/%TMP%（回退当前目录，分隔符 `\`），
/// 其余读 $TMPDIR（回退 /tmp，分隔符 `/`）。口径与 `procrun.mbt` 的
/// `pr_tmp_path` 一致，但按平台取变量名而不是依次回退——Windows 上
/// `TMPDIR` 可能被 POSIX 侧工具设成 `/tmp` 这类非本机路径。
fn fsx_tmp_root() -> String {
  if sys_platform() == "windows" {
    for name in ["TEMP", "TMP"] {
      match sys_getenv(name) {
        Some(v) => if v.length() > 0 { return v }
        None => ()
      }
    }
    "."
  } else {
    match sys_getenv("TMPDIR") {
      Some(v) => if v.length() > 0 { return v }
      None => ()
    }
    "/tmp"
  }
}

///|
/// 递归删树的跨平台清理（用例自建自清）：POSIX 用 `rm -rf`，Windows 用
/// `cmd /c rmdir /s /q`（参数由 proc_spawn 逐个 quoting，路径含空格安全）。
/// 失败（例如本就不存在）忽略——清理不是断言目标。
fn fsx_remove_tree(root : String) -> Unit {
  if sys_platform() == "windows" {
    ignore(pr_run("cmd", ["/c", "rmdir", "/s", "/q", root]))
  } else {
    ignore(pr_run("rm", ["-rf", root]))
  }
}

///|
test "sys_make_dirs：逐级建目录后写文件才有着落" {
  let sep = if sys_platform() == "windows" { "\\" } else { "/" }
  let root = fsx_tmp_root() + sep + "sys_make_dirs_wbtest"
  let nested = "\{root}\{sep}a\{sep}b\{sep}c"
  let f = "\{nested}\{sep}note.txt"
  // 清理要子进程通道（rm / rmdir）；没有通道的平台这条用例整体跳过。
  // 注意被测能力本身**不再**依赖子进程通道——`sys_make_dirs` 已是 C 薄 FFI。
  if !pr_available() {
    println("sys_make_dirs: skip (无子进程通道，清理不便)")
    return
  }
  fsx_remove_tree(root)
  assert_true(sys_make_dirs(nested))
  assert_true(sys_write_text_file(f, "内容在里层"))
  assert_eq(sys_read_text_file(f), Some("内容在里层"))
  // 目录已存在仍算成功（幂等）
  assert_true(sys_make_dirs(nested))
  assert_true(sys_make_dirs(root))
  // 空串拒绝
  assert_false(sys_make_dirs(""))
  // 父目录不存在时写文件失败：这条正是 make_dirs 要挡住的坑
  assert_false(sys_write_text_file("\{root}\{sep}gone\{sep}deep\{sep}x.txt", "x"))
  fsx_remove_tree(root)
}

///|
test "FileDialog：建/配/释放（run 与取结果留真机）" {
  // 本机有显示：桩侧 gtk_init_check 初始化后真建对象（不显示、不模态）；
  // 无显示环境（CI）同一入口返回 0 句柄、全接口退化不崩。
  // get_result 只在 run_for_window 确认后合法（桩拦未确认调用），
  // 模态 run 无头跑不了，走真机复验。
  let d = FileDialog::new_open()
  if d.id > 0 {
    d.set_filters("文本:txt,md|图片:png,jpg|全部:*")
    d.set_options(FILE_OPTION_MULTI_SELECT | FILE_OPTION_SHOW_HIDDEN)
    d.set_folder("file:///tmp")
    d.destroy()
    let s = FileDialog::new_save()
    assert_true(s.id > 0)
    s.set_filename("a.txt") // set_filename 只对保存对话框合法
    s.destroy()
  } else {
    d.set_filters("*:*")
    d.destroy()
  }
}
