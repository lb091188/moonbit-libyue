// sysinfo 模块白盒测试：os-release 键值解析（去引号/注释/缺键）、
// meminfo 行解析（kB 单位/缺键/非法值）、uptime 小数解析与截断、以及
// 本机真实数据的读取断言（存在才扫）。只读，无副作用。

///|
test "si_trim/si_split_lines:空白与换行" {
  assert_eq(si_trim("  Ubuntu 24.04 \n"), "Ubuntu 24.04")
  assert_eq(si_trim("\t x \r\n"), "x")
  assert_eq(si_trim(""), "")
  let lines = si_split_lines("a\nb\r\n\nc\n")
  assert_eq(lines.length(), 3)
  assert_eq(lines[0], "a")
  assert_eq(lines[1], "b")
  assert_eq(lines[2], "c")
}

///|
test "si_unquote:成对引号剥除/不成对原样" {
  assert_eq(si_unquote("\"Ubuntu 24.04.5 LTS\""), "Ubuntu 24.04.5 LTS")
  assert_eq(si_unquote("ubuntu"), "ubuntu")
  assert_eq(si_unquote("\"ubuntu"), "\"ubuntu") // 单边引号不剥
  assert_eq(si_unquote("ubuntu\""), "ubuntu\"")
  assert_eq(si_unquote("\"\""), "")
  assert_eq(si_unquote(""), "")
  assert_eq(si_unquote("  \"a b\"  "), "a b") // 先 trim 再剥引号
}

///|
test "si_split_kv:键值切分与非法行" {
  assert_true(si_split_kv("ID=ubuntu") is Some(("ID", "ubuntu")))
  assert_true(
    si_split_kv("VERSION_ID=\"24.04\"") is Some(("VERSION_ID", "24.04")),
  )
  assert_true(
    si_split_kv("PRETTY_NAME=\"Ubuntu 24.04.5 LTS\"")
    is Some(("PRETTY_NAME", "Ubuntu 24.04.5 LTS")),
  )
  assert_true(si_split_kv("NOEQUAL") is None) // 无 '='
  assert_true(si_split_kv("=novalue") is None) // 空键
  assert_true(si_split_kv("a=b=c") is Some(("a", "b=c"))) // 首个 '=' 切分
}

///|
test "si_parse_os_release:真实形态样例(引号/注释/缺键)" {
  let sample = "PRETTY_NAME=\"Ubuntu 24.04.5 LTS\"\nNAME=\"Ubuntu\"\nVERSION_ID=\"24.04\"\nVERSION=\"24.04.5 LTS (Noble Numbat)\"\nID=ubuntu\nID_LIKE=debian\nHOME_URL=\"https://www.ubuntu.com/\"\n# comment line\n\nUBUNTU_CODENAME=noble\n"
  assert_true(
    si_parse_os_release(sample)
    is Some(
      { pretty_name: "Ubuntu 24.04.5 LTS", id: "ubuntu", version_id: "24.04", }
    ),
  )
  // VERSION_ID 缺省留空串，其余照取
  let no_ver = "ID=arch\nPRETTY_NAME=\"Arch Linux\"\n"
  assert_true(
    si_parse_os_release(no_ver)
    is Some({ pretty_name: "Arch Linux", id: "arch", version_id: "", }),
  )
  // 无 PRETTY_NAME 视为非 os-release 格式
  assert_true(si_parse_os_release("ID=ubuntu\nVERSION_ID=\"24.04\"\n") is None)
  assert_true(si_parse_os_release("") is None)
  assert_true(si_parse_os_release("PRETTY_NAME=\n") is None) // 空值等同缺失
}

///|
test "si_parse_meminfo:kB 单位/缺键/非法值" {
  let sample = "MemTotal:       32665016 kB\nMemFree:          631032 kB\nMemAvailable:   25601576 kB\nBuffers:         2365056 kB\nCached:          6867276 kB\n"
  assert_true(
    si_parse_meminfo(sample)
    is Some({ total_kb: 32665016, available_kb: 25601576, }),
  )
  // 缺 MemAvailable → None
  let no_avail = "MemTotal:       32665016 kB\nMemFree:          631032 kB\n"
  assert_true(si_parse_meminfo(no_avail) is None)
  // 缺 MemTotal → None
  assert_true(si_parse_meminfo("MemAvailable: 123 kB\n") is None)
  // 非数值 → None
  assert_true(
    si_parse_meminfo("MemTotal: abc kB\nMemAvailable: 1 kB\n") is None,
  )
  assert_true(si_parse_meminfo("MemTotal:\nMemAvailable: 1 kB\n") is None)
  // 无单位后缀的裸数值容忍
  assert_true(
    si_parse_meminfo("MemTotal: 100\nMemAvailable: 50\n")
    is Some({ total_kb: 100, available_kb: 50, }),
  )
  // 多位数累加不回绕（Int 量级内的超大 kB 值）
  assert_true(
    si_parse_meminfo("MemTotal: 2000000000 kB\nMemAvailable: 1 kB\n")
    is Some({ total_kb: 2000000000, available_kb: 1, }),
  )
}

///|
test "si_line_key:冒号前的键" {
  assert_true(si_line_key("MemTotal:  1 kB") is Some("MemTotal"))
  assert_true(si_line_key("MemAvailable: 1 kB") is Some("MemAvailable"))
  assert_true(si_line_key("no colon") is None)
  assert_true(si_line_key(":leading") is None)
}

///|
test "si_parse_seconds:十进制小数/整数/非法" {
  // 双精度小误差容忍：与字面值差 < 1e-6
  let d = match si_parse_seconds("84088.08") {
    Some(v) => v
    None => -1.0
  }
  let diff = if d > 84088.08 { d - 84088.08 } else { 84088.08 - d }
  assert_true(diff < 0.000001)
  let d2 = match si_parse_seconds("123") {
    Some(v) => v
    None => -1.0
  }
  assert_true(d2 == 123.0)
  assert_true(si_parse_seconds("0.5") is Some(_))
  assert_true(si_parse_seconds("") is None)
  assert_true(si_parse_seconds("abc") is None)
  assert_true(si_parse_seconds("1.2.3") is None) // 多个小数点
  assert_true(si_parse_seconds("12a") is None)
  assert_true(si_parse_seconds("-1.5") is None) // uptime 恒非负，负号为非法字符
}

///|
test "si_parse_uptime:首列秒数/idle 忽略/空输出" {
  let u = match si_parse_uptime("84088.08 1645099.16\n") {
    Some(v) => v
    None => -1.0
  }
  assert_true(u > 84088.0 && u < 84089.0)
  assert_true(si_parse_uptime("0.00 0.00\n") is Some(_))
  assert_true(si_parse_uptime("") is None)
  assert_true(si_parse_uptime("   \n") is None)
  assert_true(si_parse_uptime("abc 1.0\n") is None)
}

///|
test "si_dmi_path/si_read_dmi:路径拼装与只读行为" {
  assert_eq(si_dmi_path("sys_vendor"), "/sys/class/dmi/id/sys_vendor")
  assert_eq(si_dmi_path("product_name"), "/sys/class/dmi/id/product_name")
  // 不存在的属性读不到给 None（不崩）
  assert_true(si_read_dmi("no_such_attribute") is None)
}

///|
test "Show 输出:结构体与错误枚举" {
  let os : OsInfo = {
    pretty_name: "Ubuntu 24.04.5 LTS",
    id: "ubuntu",
    version_id: "24.04",
  }
  assert_eq(
    os.to_string(),
    "OsInfo { pretty_name: Ubuntu 24.04.5 LTS, id: ubuntu, version_id: 24.04 }",
  )
  let m : MachineInfo = {
    vendor: "ASUS",
    product: "System Product Name",
    serial: "X1",
  }
  assert_eq(
    m.to_string(),
    "MachineInfo { vendor: ASUS, product: System Product Name, serial: X1 }",
  )
  let mem : MemoryInfo = { total_kb: 1000, available_kb: 500, }
  assert_eq(mem.to_string(), "MemoryInfo { total_kb: 1000, available_kb: 500 }")
  let e1 : SysInfoError = SiUnsupported
  assert_eq(e1.to_string(), "SysInfoError::SiUnsupported")
  let e2 : SysInfoError = SiReadFailed("/etc/os-release")
  assert_eq(e2.to_string(), "SysInfoError::SiReadFailed(/etc/os-release)")
  let e3 : SysInfoError = SiParseFailed("/proc/uptime")
  assert_eq(e3.to_string(), "SysInfoError::SiParseFailed(/proc/uptime)")
}

// ---------------------------------------------------------------------------
// 本机真实数据（存在才扫；读不到不阻塞）
// ---------------------------------------------------------------------------

///|
test "本机 /etc/os-release:解析关键键存在" {
  match read_text_file("/etc/os-release") {
    None => () // 非 Linux 或读不到：跳过
    Some(text) =>
      match si_parse_os_release(text) {
        None =>
          assert_true(false, msg="本机 os-release 应解析出 PRETTY_NAME")
        Some(info) => {
          assert_true(info.pretty_name != "")
          assert_true(info.id != "")
        }
      }
  }
}

///|
test "本机 /proc/meminfo:总量/可用为正且可用不超总量" {
  match read_text_file("/proc/meminfo") {
    None => ()
    Some(text) =>
      match si_parse_meminfo(text) {
        None =>
          assert_true(
            false,
            msg="本机 meminfo 应解析出 MemTotal/MemAvailable",
          )
        Some(m) => {
          assert_true(m.total_kb > 0)
          assert_true(m.available_kb >= 0)
          assert_true(m.available_kb <= m.total_kb)
        }
      }
  }
}

///|
test "本机 /proc/uptime:秒数为正且量级合理" {
  match read_text_file("/proc/uptime") {
    None => ()
    Some(text) =>
      match si_parse_uptime(text) {
        None => assert_true(false, msg="本机 uptime 应解析出秒数")
        Some(secs) => {
          assert_true(secs > 0.0)
          // < 几年量级（10^9 秒 ≈ 31 年），防解析错位把 idle 列当秒数
          assert_true(secs < 1000000000.0)
        }
      }
  }
}

///|
test "本机 DMI:sys_vendor/product_name 可读,product_serial 可缺" {
  // 多数发行版 product_serial 仅 root 可读,读不到给 Err 不糊弄;可读
  // 时三项均应为非空
  match si_machine() {
    Ok(m) => {
      assert_true(m.vendor != "")
      assert_true(m.product != "")
      assert_true(m.serial != "")
    }
    Err(SiReadFailed(_)) => ()
    Err(_) => assert_true(false, msg="si_machine 只应给 ReadFailed 或 Ok")
  }
}
