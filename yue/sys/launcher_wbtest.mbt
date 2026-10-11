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
  // 当前工作目录：真实读得到且是绝对路径
  let cwd = current_dir()
  assert_true(cwd != "")
  assert_true(cwd.has_prefix("/"))
}

///|
test {
  // 分离式启动：命令名为空与命令不存在都失败，`true` 交得出去
  assert_true(spawn_detached("", "x") is Err(_))
  assert_true(spawn_detached("launcher_no_such_bin_zzz", "x") is Err(_))
  assert_true(spawn_detached("true", "") is Ok(_))
}

///|
test {
  // 不阻塞：`sleep 3` 交给系统后立即返回（等它退出才是这层要排除的行为）
  let started = @env.now()
  assert_true(spawn_detached("sleep", "3") is Ok(_))
  let spent = (@env.now() - started).to_int()
  assert_true(spent < 500)
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
  if sys_platform() != "linux" {
    assert_true(open_url("https://libyue.com") is Err(Unsupported))
    assert_true(reveal_in_file_manager("/tmp") is Err(Unsupported))
  }
}
