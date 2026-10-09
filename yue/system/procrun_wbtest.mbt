// procrun 白盒测试：真实只读命令覆盖 pr_run 的 stdout 捕获 / 退出码 /
// 非零退出带 stderr / 超时 / 信号终止路径与 C locale 环境构造。超时用
// sleep 5 配 100ms 预算真测等待逻辑（含提前返回）；命令不存在按 Unix
// 惯例断言退出码 127。全部命令只读，不改动系统状态。

///|
/// 非 Linux 跳过守卫（本仓库主链路 Linux，套件真实执行）。
fn pr_skip_guard() -> Bool {
  if !pr_available() {
    println("pr: skip (non-linux)")
    return false
  }
  true
}

///|
test "pr_available:主链路 Linux 为真" {
  if !pr_skip_guard() {
    return
  }
  assert_true(pr_available())
  assert_eq(@yue.platform(), "linux")
}

///|
test "pr_run:echo 捕获 stdout 与退出码" {
  if !pr_skip_guard() {
    return
  }
  match pr_run("echo", ["hello-pr"]) {
    Ok(o) => {
      assert_eq(o.exit_code, 0)
      assert_eq(o.stdout, "hello-pr\n")
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
  match pr_run("echo", ["a", "b", "c"]) {
    Ok(o) => assert_eq(o.stdout, "a b c\n")
    Err(e) => {
      println("pr_run echo failed: \{e}")
      assert_true(false)
    }
  }
}

///|
test "pr_run:无参数命令空输出" {
  if !pr_skip_guard() {
    return
  }
  match pr_run("true", []) {
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
  if !pr_skip_guard() {
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
test "pr_run:非零退出携带 stderr（C locale）" {
  if !pr_skip_guard() {
    return
  }
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

///|
test "pr_run:命令不存在按 Unix 惯例退出码 127" {
  if !pr_skip_guard() {
    return
  }
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

///|
test "pr_run:超时真测（sleep 5 配 100ms 预算）" {
  if !pr_skip_guard() {
    return
  }
  let t0 = @env.now()
  let ans = pr_run("sleep", ["5"], timeout_ms=100)
  let spent = @env.now() - t0
  assert_true(ans is Err(Timeout(_)))
  // 真实等待过预算时长，且未等满 sleep 全程（超时提前强制终止返回）
  assert_true(spent >= 100UL)
  assert_true(spent < 5000UL)
}

///|
test "pr_run:被信号终止（子进程自发 TERM，只读）" {
  if !pr_skip_guard() {
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
  if !pr_skip_guard() {
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
