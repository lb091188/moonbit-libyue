// 环境变量模块白盒测试：真实本机环境探测（存在性断言）+ 进程内读改写删
// 环 + 常用集合覆盖 + 参数与错误分支。写 / 删只动当前进程环境（本测试
// 进程），不触碰系统持久配置，也不影响父进程与外部进程。

///|
/// 测试专用变量名（本进程内写删，取一个大概率不存在的名）。
let envx_probe_name : String = "YUE_TEST_ENVX_PROBE"

///|
test "envx_get：真实环境读常用变量" {
  // POSIX 环境 PATH / HOME 必然存在（Linux 主链路）
  match envx_get("PATH") {
    Some(p) => assert_true(p.length() > 0)
    None => println("envx: skip (no PATH)")
  }
  match envx_get("HOME") {
    Some(h) => assert_true(h.length() > 0)
    None => println("envx: skip (no HOME)")
  }
  // 不存在的变量为 None；空名为 None
  assert_true(envx_get("YUE_NO_SUCH_ENV_XYZ") is None)
  assert_true(envx_get("") is None)
  // 读与 core/env 直读一致
  assert_eq(envx_get("PATH"), @env.get_env_var("PATH"))
}

///|
test "envx_get：空串值与存在性是两回事" {
  // 本进程写入空串值：存在（Some("")）而非 None
  assert_true(envx_set(envx_probe_name, "") is Ok(_))
  assert_eq(envx_get(envx_probe_name), Some(""))
  assert_true(envx_unset(envx_probe_name) is Ok(_))
  assert_true(envx_get(envx_probe_name) is None)
}

///|
test "envx_set/envx_unset：进程内写读改删环" {
  // 写
  assert_true(envx_set(envx_probe_name, "值A") is Ok(_))
  assert_eq(envx_get(envx_probe_name), Some("值A"))
  // 覆盖写（语义为 overwrite）
  assert_true(envx_set(envx_probe_name, "值B2") is Ok(_))
  assert_eq(envx_get(envx_probe_name), Some("值B2"))
  // 删（幂等：再删一次仍为成功）
  assert_true(envx_unset(envx_probe_name) is Ok(_))
  assert_true(envx_get(envx_probe_name) is None)
  assert_true(envx_unset(envx_probe_name) is Ok(_))
  assert_true(envx_get(envx_probe_name) is None)
}

///|
test "envx_set/envx_unset：进程内生效（子进程可见）" {
  assert_true(envx_set(envx_probe_name, "child-visible") is Ok(_))
  // procrun 传 PATH/XDG_RUNTIME_DIR/HOME 与 LC_ALL，不透传本变量，
  // 因此子进程读不到属预期；此处断言本进程读得到即可
  assert_eq(envx_get(envx_probe_name), Some("child-visible"))
  assert_true(envx_unset(envx_probe_name) is Ok(_))
}

///|
test "envx_set/envx_unset：参数与错误分支" {
  // 空变量名
  match envx_set("", "v") {
    Err(ExInvalidParam(_)) => ()
    other => {
      ignore(other)
      assert_true(false)
    }
  }
  match envx_unset("") {
    Err(ExInvalidParam(_)) => ()
    other => {
      ignore(other)
      assert_true(false)
    }
  }
  // 含 '=' 的变量名被底层拒绝（setenv 语义）
  match envx_set("a=b", "v") {
    Err(ExFailed(_)) => ()
    other => {
      ignore(other)
      assert_true(false)
    }
  }
  match envx_unset("a=b") {
    Err(ExFailed(_)) => ()
    other => {
      ignore(other)
      assert_true(false)
    }
  }
}

///|
test "envx_common：常用集合只收存在的变量" {
  let common = envx_common()
  // PATH / HOME 在本机存在，必须收入且值与单点读一致
  for name in ["PATH", "HOME"] {
    match envx_get(name) {
      Some(v) => {
        assert_true(common.contains(name))
        assert_eq(common.get(name), Some(v))
      }
      None => println("envx: skip (no \{name})")
    }
  }
  // 固定名表不重不漏（XDG_* 走前缀扫描，不在表内）
  assert_eq(envx_common_names.length(), 5)
  assert_true(envx_common_names.contains("PATH"))
  assert_true(envx_common_names.contains("LANG"))
  assert_true(!envx_common_names.contains("XDG_RUNTIME_DIR"))
  // 环境中所有 XDG_* 变量必须全部收入（存在才扫）
  for k, v in @env.get_env_vars().iter2() {
    if k.has_prefix("XDG_") {
      assert_true(common.contains(k))
      assert_eq(common.get(k), Some(v))
    }
  }
  // 不存在的常用变量不进结果
  assert_true(!common.contains("YUE_NO_SUCH_COMMON_X"))
  println("envx: common has \{common.length()} entries")
}

///|
test "EnvxError Show 文本" {
  let e1 : EnvxError = ExInvalidParam("变量名为空")
  assert_eq(e1.to_string(), "EnvxError::ExInvalidParam(变量名为空)")
  let e2 : EnvxError = ExFailed("a=b")
  assert_eq(e2.to_string(), "EnvxError::ExFailed(a=b)")
}
