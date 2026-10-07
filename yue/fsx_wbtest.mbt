// 文件系统与环境变量白盒测试：扁平文本解码为纯函数断言；目录枚举与
// 环境变量写删按真实环境断言（临时文件建在 /tmp；环境变量写的是测试
// 进程自身环境，随进程退出即逝，不触碰系统配置）。

///|
test "fsx 扁平文本解码：按 '\\n' 拆分去空行" {
  debug_inspect(
    fsx_decode_names(utf8_bytes("a.desktop\nb.desktop\n")),
    content="[\"a.desktop\", \"b.desktop\"]",
  )
  debug_inspect(fsx_decode_names(utf8_bytes("")), content="[]")
  debug_inspect(
    fsx_decode_names(utf8_bytes("唯一\n")),
    content="[\"唯一\"]",
  )
  debug_inspect(fsx_decode_names(utf8_bytes("\n\n")), content="[]")
}

///|
test "fsx_list_dir：真实目录枚举（临时文件可见，不含 . ..）" {
  let f1 = "/tmp/fsx_wbtest_a.txt"
  let f2 = "/tmp/fsx_wbtest_b.txt"
  inspect(write_text_file(f1, "x"), content="true")
  inspect(write_text_file(f2, "y"), content="true")
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
  ignore(ffi_remove_file(utf8_bytes(f1), Ref(0)))
  ignore(ffi_remove_file(utf8_bytes(f2), Ref(0)))
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
  ignore(write_text_file(f, "x"))
  match fsx_list_dir(f) {
    Err(OpenFailed(p)) => inspect(p, content=f)
    _ => inspect(false, content="true")
  }
  ignore(ffi_remove_file(utf8_bytes(f), Ref(0)))
}

///|
test "fsx_set_env / fsx_unset_env：进程内写读改删回环" {
  let name = "FSX_WBTEST_VAR"
  // 写入后立即可读（仅本进程）
  inspect(fsx_set_env(name, "值42", true) is Ok(_), content="true")
  let ok = Ref(0)
  inspect(
    from_utf8_bytes(ffi_getenv_bytes(utf8_bytes(name), ok)),
    content="值42",
  )
  inspect(ok.val, content="1")
  // overwrite=false：已存在保持原值，仍 Ok
  inspect(fsx_set_env(name, "other", false) is Ok(_), content="true")
  let ok2 = Ref(0)
  inspect(
    from_utf8_bytes(ffi_getenv_bytes(utf8_bytes(name), ok2)),
    content="值42",
  )
  // 删除后读不到（ok=0）
  inspect(fsx_unset_env(name) is Ok(_), content="true")
  let ok3 = Ref(0)
  ignore(ffi_getenv_bytes(utf8_bytes(name), ok3))
  inspect(ok3.val, content="0")
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
