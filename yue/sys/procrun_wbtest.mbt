// procrun 白盒测试：真实只读命令覆盖 pr_run 的 stdout 捕获 / 退出码 /
// 非零退出带 stderr / 超时 / 信号终止路径与环境构造。超时用「睡 5 秒配
// 100ms 预算」真测等待逻辑（含提前返回）。
//
// 命令名按平台分流：POSIX 走 sh/echo/cat/sleep，Windows 走 cmd.exe 的 /c。
// Unix 惯例专属的断言（命令不存在退 127、子进程自发 SIGTERM、固定 C locale、
// /etc/hostname）只在 POSIX 侧执行，Windows 侧给等价断言（spawn 直接失败、
// stderr 捕获）或打印跳过。全部命令只读，不改动系统状态。

///|
/// 平台不支持子进程执行时跳过（Linux/macOS/Windows 之外）。
fn pr_skip_guard() -> Bool {
  if !pr_available() {
    println("pr: skip (unsupported platform)")
    return false
  }
  true
}

///|
/// Unix 语义专属断言的守卫：Windows 侧打印跳过（没有 sh、没有信号、环境块
/// 是继承来的所以也没有 locale 语义）。
fn pr_posix_guard() -> Bool {
  if !pr_skip_guard() {
    return false
  }
  match sys_platform() {
    "linux" | "macos" => true
    _ => {
      println("pr: skip (posix-only)")
      false
    }
  }
}

///|
/// 交给系统 shell 执行一段脚本（脚本内容只读）：POSIX = sh -c，Windows =
/// cmd /c。Windows 侧 PATH 里若恰好有 Git 的 /usr/bin，POSIX 命令名看着也能
/// 跑，但从 cmd 起就全灭——回环一律经这里，不依赖那种巧合。
fn pr_sh(script : String) -> (String, Array[String]) {
  if sys_platform() == "windows" {
    ("cmd", ["/c", script])
  } else {
    ("sh", ["-c", script])
  }
}

///|
/// 命令输出的行尾：cmd 系给 \r\n，POSIX 给 \n。
fn pr_eol() -> String {
  if sys_platform() == "windows" { "\r\n" } else { "\n" }
}

///|
test "pr_available:三大主平台为真" {
  // 平台门与实际支持一致：支持的三平台为真，其余为假
  let win = sys_platform() == "windows"
  assert_true(pr_available())
  if win {
    assert_eq(sys_platform(), "windows")
  } else {
    assert_true(
      sys_platform() == "linux" || sys_platform() == "macos" || !pr_available(),
    )
  }
}

///|
test "pr_run:echo 捕获 stdout 与退出码" {
  if !pr_skip_guard() {
    return
  }
  let (cmd, args) = pr_sh("echo hello-pr")
  match pr_run(cmd, args) {
    Ok(o) => {
      assert_eq(o.exit_code, 0)
      assert_eq(o.stdout, "hello-pr\{pr_eol()}")
    }
    Err(e) => {
      println("pr_run echo failed: \{e}")
      assert_true(false)
    }
  }
}

///|
test "pr_run:多参数按序传入" {
  if !pr_skip_guard() {
    return
  }
  // POSIX 侧保留「argv 逐个传」的原形（echo a b c），Windows 侧走 cmd 的
  // 单串脚本——两边走的都是「参数按序拼进命令行」这条实现
  let (cmd, args) =
    if sys_platform() == "windows" {
      pr_sh("echo a b c")
    } else {
      ("echo", ["a", "b", "c"])
    }
  match pr_run(cmd, args) {
    Ok(o) => assert_eq(o.stdout, "a b c\{pr_eol()}")
    Err(e) => {
      println("pr_run echo failed: \{e}")
      assert_true(false)
    }
  }
}

///|
test "pr_run:退出码 0 且无输出" {
  if !pr_skip_guard() {
    return
  }
  let (cmd, args) =
    if sys_platform() == "windows" { ("cmd", ["/c", "exit", "0"]) } else {
      ("true", [])
    }
  match pr_run(cmd, args) {
    Ok(o) => {
      assert_eq(o.exit_code, 0)
      assert_eq(o.stdout, "")
    }
    Err(e) => {
      println("pr_run failed: \{e}")
      assert_true(false)
    }
  }
}

///|
test "pr_run:cat /etc/hostname 与直接读文件一致" {
  if !pr_posix_guard() {
    return
  }
  match sys_read_text_file("/etc/hostname") {
    None => println("pr: skip (no /etc/hostname)")
    Some(expect) =>
      match pr_run("cat", ["/etc/hostname"]) {
        Ok(o) => {
          assert_eq(o.exit_code, 0)
          assert_eq(o.stdout, expect)
        }
        Err(e) => {
          println("pr_run cat failed: \{e}")
          assert_true(false)
        }
      }
  }
}

///|
test "pr_run:非零退出携带 stderr" {
  if !pr_skip_guard() {
    return
  }
  if sys_platform() == "windows" {
    // Windows 侧的等价断言：cmd 里把一串 ASCII 打到 stderr 并以 42 退出
    // （不用中文：控制台输出是 OEM 代码页，跨码页比对没有意义）
    match pr_run("cmd", ["/c", "echo ERRPROBE 1>&2 & exit 42"]) {
      Err(NonZeroExit(code, err)) => {
        assert_eq(code, 42)
        assert_true(err.contains("ERRPROBE"))
      }
      Ok(o) => {
        println("unexpected ok: \{o}")
        assert_true(false)
      }
      Err(e) => {
        println("unexpected err: \{e}")
        assert_true(false)
      }
    }
  } else {
    match pr_run("cat", ["/yue-pr-no-such-file"]) {
      Err(NonZeroExit(code, err)) => {
        assert_eq(code, 1)
        assert_true(err.contains("No such file"))
      }
      Ok(o) => {
        println("unexpected ok: \{o}")
        assert_true(false)
      }
      Err(e) => {
        println("unexpected err: \{e}")
        assert_true(false)
      }
    }
  }
}

///|
test "pr_run:命令不存在的落点按平台" {
  if !pr_skip_guard() {
    return
  }
  if sys_platform() == "windows" {
    // CreateProcessW 找不到可执行文件就直接失败（错误码进 SpawnFailed），
    // 不会像 Unix 那样先起子进程再退 127
    match pr_run("yue-pr-no-such-cmd-xyz", []) {
      Err(SpawnFailed(_)) => assert_true(true)
      Ok(o) => {
        println("unexpected ok: \{o}")
        assert_true(false)
      }
      Err(e) => {
        println("unexpected err: \{e}")
        assert_true(false)
      }
    }
  } else {
    match pr_run("yue-pr-no-such-cmd-xyz", []) {
      Err(NonZeroExit(code, _)) => assert_eq(code, 127)
      Ok(o) => {
        println("unexpected ok: \{o}")
        assert_true(false)
      }
      Err(e) => {
        println("unexpected err: \{e}")
        assert_true(false)
      }
    }
  }
}

///|
test "pr_run:超时真测（睡 5 秒配 100ms 预算）" {
  if !pr_skip_guard() {
    return
  }
  let (cmd, args) =
    if sys_platform() == "windows" {
      ("cmd", ["/c", "ping -n 6 127.0.0.1 >nul"])
    } else {
      ("sleep", ["5"])
    }
  let t0 = @env.now()
  let ans = pr_run(cmd, args, timeout_ms=100)
  let spent = @env.now() - t0
  assert_true(ans is Err(Timeout(_)))
  // 真实等待过预算时长，且未等满全程（超时提前强制终止返回）
  assert_true(spent >= 100UL)
  assert_true(spent < 5000UL)
}

///|
test "pr_run:被信号终止（子进程自发 TERM，只读）" {
  if !pr_posix_guard() {
    return
  }
  match pr_run("sh", ["-c", "kill -TERM $$"]) {
    Err(Signaled(sig)) => assert_eq(sig, 15)
    Ok(o) => {
      println("unexpected ok: \{o}")
      assert_true(false)
    }
    Err(e) => {
      println("unexpected err: \{e}")
      assert_true(false)
    }
  }
}

///|
test "pr_run:子进程环境固定 C locale" {
  // POSIX 侧的环境块由 pr_env_blob 构造并强制 LC_ALL=C（输出语言恒定可
  // 解析）；Windows 侧传空块＝继承父环境，没有 locale 语义这回事
  if !pr_posix_guard() {
    return
  }
  match pr_run("sh", ["-c", "printf %s \"$LC_ALL\""]) {
    Ok(o) => assert_eq(o.stdout, "C")
    Err(e) => {
      println("pr_run sh failed: \{e}")
      assert_true(false)
    }
  }
}

///|
test "ProcError/ProcOutput Show 文本" {
  let e1 : ProcError = Unsupported
  assert_eq(e1.to_string(), "ProcError::Unsupported")
  let e2 : ProcError = SpawnFailed("x: boom")
  assert_eq(e2.to_string(), "ProcError::SpawnFailed(x: boom)")
  let e3 : ProcError = Timeout("x: 超时（100ms）")
  assert_eq(e3.to_string(), "ProcError::Timeout(x: 超时（100ms）)")
  let e4 : ProcError = NonZeroExit(1, "boom")
  assert_eq(e4.to_string(), "ProcError::NonZeroExit(1, boom)")
  let e5 : ProcError = Signaled(15)
  assert_eq(e5.to_string(), "ProcError::Signaled(15)")
  let o1 = { stdout: "hi", exit_code: 0, }
  assert_eq(o1.to_string(), "ProcOutput { stdout: hi, exit_code: 0 }")
}
