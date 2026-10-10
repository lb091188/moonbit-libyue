// procrun 白盒测试：真实只读命令覆盖 pr_run 的 stdout 捕获 / 退出码 /
// 非零退出 / 超时 / 信号终止路径与环境构造，Linux 与 Windows 双平台
// 真实执行（macOS 跳过）。超时用 ~5 秒命令配 100ms 预算真测等待逻辑
// （含提前返回）；命令不存在按平台断言：Unix 惯例子进程退出码 127，
// Windows 为 CreateProcessW 失败（SpawnFailed）。全部命令只读，不改动
// 系统状态。

///|
/// 平台助手：Windows 分支命令与 Linux 不同。
fn pr_win() -> Bool {
  @yue.platform() == "windows"
}

///|
/// 非 Linux / Windows 跳过守卫（macOS 无 procrun）。
fn pr_skip_guard() -> Bool {
  if !pr_available() {
    println("pr: skip (no procrun on this platform)")
    return false
  }
  true
}

///|
test "pr_available:Linux / Windows 为真" {
  if !pr_skip_guard() {
    return
  }
  assert_true(pr_available())
  assert_true(@yue.platform() == "linux" || @yue.platform() == "windows")
}

///|
test "pr_run:echo 捕获 stdout 与退出码" {
  if !pr_skip_guard() {
    return
  }
  let ans = if pr_win() {
      pr_run("cmd", ["/c", "echo", "hello-pr"])
    } else {
      pr_run("echo", ["hello-pr"])
    }
  match ans {
    Ok(o) => {
      assert_eq(o.exit_code, 0)
      if pr_win() {
        assert_eq(o.stdout, "hello-pr\r\n")
      } else {
        assert_eq(o.stdout, "hello-pr\n")
      }
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
  let ans = if pr_win() {
      pr_run("cmd", ["/c", "echo", "a", "b", "c"])
    } else {
      pr_run("echo", ["a", "b", "c"])
    }
  match ans {
    Ok(o) =>
      if pr_win() {
        assert_eq(o.stdout, "a b c\r\n")
      } else {
        assert_eq(o.stdout, "a b c\n")
      }
    Err(e) => {
      println("pr_run echo failed: \{e}")
      assert_true(false)
    }
  }
}

///|
test "pr_run:无输出命令空 stdout" {
  if !pr_skip_guard() {
    return
  }
  let ans = if pr_win() {
      pr_run("cmd", ["/c", "exit", "0"])
    } else {
      pr_run("true", [])
    }
  match ans {
    Ok(o) => {
      assert_eq(o.exit_code, 0)
      assert_eq(o.stdout, "")
    }
    Err(e) => {
      println("pr_run true failed: \{e}")
      assert_true(false)
    }
  }
}

///|
test "pr_run:cat /etc/hostname 与直接读文件一致" {
  if !pr_skip_guard() || pr_win() {
    return
  }
  match @yue.read_text_file("/etc/hostname") {
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
test "pr_run:非零退出携带退出码" {
  if !pr_skip_guard() {
    return
  }
  let ans = if pr_win() {
      pr_run("cmd", ["/c", "exit", "3"])
    } else {
      pr_run("cat", ["/yue-pr-no-such-file"])
    }
  match ans {
    Err(NonZeroExit(code, _)) => {
      if pr_win() {
        assert_eq(code, 3)
      } else {
        assert_eq(code, 1)
      }
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

///|
test "pr_run:命令不存在（Unix 退出码 127 / Windows SpawnFailed）" {
  if !pr_skip_guard() {
    return
  }
  match pr_run("yue-pr-no-such-cmd-xyz", []) {
    Err(NonZeroExit(code, _)) => {
      assert_eq(code, 127)
      assert_true(!pr_win())
    }
    Err(SpawnFailed(_)) => assert_true(pr_win())
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
test "pr_run:超时真测（~5s 命令配 100ms 预算）" {
  if !pr_skip_guard() {
    return
  }
  let t0 = @env.now()
  let ans = if pr_win() {
      pr_run("ping", ["-n", "6", "127.0.0.1"], timeout_ms=100)
    } else {
      pr_run("sleep", ["5"], timeout_ms=100)
    }
  let spent = @env.now() - t0
  assert_true(ans is Err(Timeout(_)))
  // 真实等待过预算时长，且未等满命令全程（超时提前强制终止返回）
  assert_true(spent >= 100UL)
  assert_true(spent < 5000UL)
}

///|
test "pr_run:被信号终止（子进程自发 TERM，仅 Unix）" {
  if !pr_skip_guard() || pr_win() {
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
test "pr_run:子进程环境（Linux 固定 C locale / Windows 继承父环境）" {
  if !pr_skip_guard() {
    return
  }
  let ans = if pr_win() {
      pr_run("cmd", ["/c", "echo", "%SystemRoot%"])
    } else {
      pr_run("sh", ["-c", "printf %s \"$LC_ALL\""])
    }
  match ans {
    Ok(o) =>
      if pr_win() {
        assert_true(o.stdout.trim(chars="\r\n").length() > 0)
      } else {
        assert_eq(o.stdout, "C")
      }
    Err(e) => {
      println("pr_run env failed: \{e}")
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
