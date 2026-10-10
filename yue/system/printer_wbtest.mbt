// 打印机模块白盒测试：lpstat 输出解析（`-p` 打印列表 / `-d` 默认 /
// `-o` 队列，真实样例取自本机 CUPS 的 C locale 输出，队列行为 CUPS
// show_jobs 的 printf 形态构造）+ lp 参数构造 + prt_run_tool 的退出码
// 映射 + Show 文本。真实环境探测用 pr_available 守卫：装了 CUPS 的
// 宿主机真实执行只读查询（列打印机 / 读默认 / 读队列），未装的跳过；
// lp 有副作用（真实排队打印），全程只断言其参数表，不执行打印。

///|
/// 行数组拼多行文本（每行补换行，与命令行工具输出一致）。
fn prt_text(lines : Array[String]) -> String {
  let buf = StringBuilder()
  for l in lines {
    buf.write_string(l)
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
/// 非 Linux 或无 CUPS 跳过守卫（本仓库主链路 Linux + 本机装有 CUPS）。
fn prt_skip_guard() -> Bool {
  if !pr_available() {
    println("prt: skip (non-linux)")
    return false
  }
  if !prt_supported() {
    println("prt: skip (no lpstat)")
    return false
  }
  true
}

///|
/// 取最后一段 '/' 之后的文本（无 '/' 时为原串）：CUPS 类默认目标打印成
/// "类名/成员名"，回列表比对时取成员段。
fn prt_last_slash(s : String) -> String {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let mut at = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' {
      at = i
    }
  }
  if at < 0 {
    s
  } else {
    let buf = StringBuilder()
    let lo = at + 1
    for j in lo..<chars.length() {
      buf.write_char(chars[j])
    }
    buf.to_string()
  }
}

///|
test "prt_parse_printer_line：真实样例与四种状态" {
  // 本机 CUPS（C locale）真实输出
  let real = prt_parse_printer_line(
    "printer Gprinter-GP-9034T is idle.  enabled since Thu Sep 17 15:43:30 2026",
  )
  assert_true(real is Some({ name: "Gprinter-GP-9034T", status: Idle, }))
  let real2 = prt_parse_printer_line(
    "printer HP_LaserJet_Pro_M428_M429_F8B373 is idle.  enabled since Wed Oct  7 00:00:07 2026",
  )
  assert_true(
    real2 is Some({ name: "HP_LaserJet_Pro_M428_M429_F8B373", status: Idle, }),
  )
  // 其余三种状态（CUPS lpstat 的完整形态，构造样例）
  assert_true(
    prt_parse_printer_line(
      "printer InUse now printing InUse-8.  enabled since Wed Oct  7 00:00:07 2026",
    )
    is Some({ name: "InUse", status: Printing, }),
  )
  assert_true(
    prt_parse_printer_line(
      "printer Hold is holding new jobs.  enabled since Wed Oct  7 00:00:07 2026",
    )
    is Some({ name: "Hold", status: Paused, }),
  )
  assert_true(
    prt_parse_printer_line(
      "printer Off disabled since Wed Oct  7 00:00:07 2026 -",
    )
    is Some({ name: "Off", status: Disabled, }),
  )
  // 前导空白容忍（完整输出逐行喂进来前先 trim，此处单测再收一层）
  assert_true(
    prt_parse_printer_line("  printer Indented is idle.  enabled since x")
    is Some({ name: "Indented", status: Idle, }),
  )
  // 非打印机行 / 残缺行解析为 None 跳过
  assert_true(prt_parse_printer_line("") is None)
  assert_true(prt_parse_printer_line("printer") is None)
  assert_true(prt_parse_printer_line("printer ") is None)
  assert_true(
    prt_parse_printer_line(
      "Gprinter-GP-9034T accepting requests since Thu Sep 17 15:43:30 2026",
    )
    is None,
  )
  assert_true(
    prt_parse_printer_line("system default destination: Gprinter-GP-9034T")
    is None,
  )
}

///|
test "prt_parse_printer_list：真实两机样例与非打印机行混排" {
  let infos = prt_parse_printer_list(
    prt_text([
      "printer Gprinter-GP-9034T is idle.  enabled since Thu Sep 17 15:43:30 2026",
      "printer HP_LaserJet_Pro_M428_M429_F8B373 is idle.  enabled since Wed Oct  7 00:00:07 2026",
      "Gprinter-GP-9034T accepting requests since Thu Sep 17 15:43:30 2026", "HP_LaserJet_Pro_M428_M429_F8B373 accepting requests since Wed Oct  7 00:00:07 2026",
      "",
    ]),
  )
  assert_eq(infos.length(), 2)
  assert_eq(infos[0].name, "Gprinter-GP-9034T")
  assert_eq(infos[1].name, "HP_LaserJet_Pro_M428_M429_F8B373")
  // 空输出（未配置打印机）为空数组
  assert_eq(prt_parse_printer_list("").length(), 0)
}

///|
test "prt_status_available：四态可用性" {
  assert_true(prt_status_available(Idle))
  assert_true(prt_status_available(Printing))
  assert_true(!prt_status_available(Paused))
  assert_true(!prt_status_available(Disabled))
}

///|
test "prt_parse_default：真实样例/类默认/无默认/异常输出" {
  // 本机 CUPS（C locale）真实输出
  assert_eq(
    prt_parse_default("system default destination: Gprinter-GP-9034T\n"),
    Some("Gprinter-GP-9034T"),
  )
  // 类默认（CUPS 的 "系统默认目标: 类名/成员名" 形态）
  assert_eq(
    prt_parse_default("system default destination: Office/HP-LaserJet\n"),
    Some("Office/HP-LaserJet"),
  )
  // 无默认目标（CUPS 原文）
  assert_true(prt_parse_default("no system default destination\n") is None)
  // 空值与无法识别
  assert_true(prt_parse_default("") is None)
  assert_true(prt_parse_default("system default destination: \n") is None)
  assert_true(prt_parse_default("system default destination:\n") is None)
  assert_true(prt_parse_default("garbage output\n") is None)
}

///|
test "prt_after_colon：冒号切分" {
  assert_eq(prt_after_colon("a: b"), Some(" b"))
  assert_eq(prt_after_colon("system default destination: x"), Some(" x"))
  assert_true(prt_after_colon("no colon") is None)
}

///|
test "prt_parse_job_line：队列行（CUPS printf 形态）" {
  // CUPS show_jobs 短格式 "%-23s %-13s %8.0f   %s" 的忠实样例
  // （目标名不足 23 字符以空格补齐；打印机名本身含 '-' 也能正确拆号）
  assert_true(
    prt_parse_job_line(
      "Gprinter-GP-9034T-12    lkyh                31   Tue Oct  7 12:00:00 2026",
    )
    is Some({ name: "Gprinter-GP-9034T-12", id: 12, }),
  )
  // 目标名超长时列间只剩一个空格
  assert_true(
    prt_parse_job_line(
      "HP_LaserJet_Pro_M428_M429_F8B373-1348 lkyh               104   Wed Oct  7 09:15:02 2026",
    )
    is Some({ name: "HP_LaserJet_Pro_M428_M429_F8B373-1348", id: 1348, }),
  )
  // 提交用户缺失时 CUPS 打印 "unknown"
  assert_true(
    prt_parse_job_line(
      "HP-1                    unknown              0   Thu Oct  8 08:00:00 2026",
    )
    is Some({ name: "HP-1", id: 1, }),
  )
  // 残缺 / 非队列行为 None
  assert_true(prt_parse_job_line("") is None)
  assert_true(prt_parse_job_line("no-dash-here") is None)
  assert_true(prt_parse_job_line("printer-") is None)
  assert_true(prt_parse_job_line("printer-x") is None)
  assert_true(prt_parse_job_line("-12") is None)
}

///|
test "prt_parse_queue：多任务/空队列" {
  let jobs = prt_parse_queue(
    prt_text([
      "Gprinter-GP-9034T-12    lkyh                31   Tue Oct  7 12:00:00 2026",
      "Gprinter-GP-9034T-13    lkyh                31   Tue Oct  7 12:00:01 2026",
      "HP-1                    unknown              0   Thu Oct  8 08:00:00 2026",
      "",
    ]),
  )
  assert_eq(jobs.length(), 3)
  assert_eq(jobs[0].name, "Gprinter-GP-9034T-12")
  assert_eq(jobs[0].id, 12)
  assert_eq(jobs[2].id, 1)
  // 空输出（队列为空）为空数组
  assert_eq(prt_parse_queue("").length(), 0)
}

///|
test "prt_print_args：默认打印机/指定打印机/份数" {
  // 不指定打印机 → 只带份数与路径（默认打印机）
  assert_eq(prt_print_args(None, "/tmp/doc.pdf", 1), ["-n", "1", "/tmp/doc.pdf"])
  // 指定打印机 → -d 前置
  assert_eq(prt_print_args(Some("Gprinter-GP-9034T"), "/tmp/doc.pdf", 3), [
    "-d", "Gprinter-GP-9034T", "-n", "3", "/tmp/doc.pdf",
  ])
  // 空串打印机视同缺省
  assert_eq(prt_print_args(Some(""), "/tmp/a.txt", 2), ["-n", "2", "/tmp/a.txt"])
}

///|
test "prt_run_tool：退出码映射（真实命令，只读）" {
  if @yue.platform() == "windows" {
    println("prt: skip (Linux 子进程语义)")
    return
  }
  if !pr_available() {
    println("prt: skip (non-linux)")
    return
  }
  // 命令不存在 → 127 → PrtUnsupported（系统未装 CUPS 的合法降级路径）
  assert_true(
    prt_run_tool("yue-no-such-lpstat-xyz", ["-p"]) is Err(PrtUnsupported),
  )
  // true 退出码 0、空输出
  match prt_run_tool("true", []) {
    Ok(out) => assert_eq(out, "")
    other => {
      ignore(other)
      assert_true(false)
    }
  }
  // false 退出码 1 → PrtCommandFailed
  match prt_run_tool("false", []) {
    Err(PrtCommandFailed(_)) => ()
    other => {
      ignore(other)
      assert_true(false)
    }
  }
}

///|
test "Show 文本：PrinterStatus/PrinterInfo/PrinterJob/PrinterError" {
  assert_eq(Idle.to_string(), "PrinterStatus::Idle")
  assert_eq(Printing.to_string(), "PrinterStatus::Printing")
  assert_eq(Paused.to_string(), "PrinterStatus::Paused")
  assert_eq(Disabled.to_string(), "PrinterStatus::Disabled")
  let info : PrinterInfo = { name: "HP-1", status: Printing, }
  assert_eq(
    info.to_string(),
    "PrinterInfo { name: HP-1, status: PrinterStatus::Printing }",
  )
  let job : PrinterJob = { name: "HP-1", id: 42, }
  assert_eq(job.to_string(), "PrinterJob { name: HP-1, id: 42 }")
  let e1 : PrinterError = PrtUnsupported
  assert_eq(e1.to_string(), "PrinterError::PrtUnsupported")
  let e2 : PrinterError = PrtCommandFailed("lpstat: 退出码 1（x）")
  assert_eq(
    e2.to_string(),
    "PrinterError::PrtCommandFailed(lpstat: 退出码 1（x）)",
  )
  let e3 : PrinterError = PrtParseFailed("无默认")
  assert_eq(e3.to_string(), "PrinterError::PrtParseFailed(无默认)")
  let e4 : PrinterError = PrtInvalidParam("打印机名为空")
  assert_eq(e4.to_string(), "PrinterError::PrtInvalidParam(打印机名为空)")
}

// ---------------------------------------------------------------------------
// 真实环境探测（只读：存在 CUPS 的真实宿主机上真实执行查询）
// ---------------------------------------------------------------------------

///|
test "prt_supported/prt_list：本机真实打印机列表" {
  if !prt_skip_guard() {
    return
  }
  assert_true(prt_supported())
  match prt_list() {
    Err(e) => {
      println("prt_list failed: \{e}")
      assert_true(false)
    }
    Ok(infos) => {
      println("prt: \{infos.length()} printer(s)")
      // 本机装有 CUPS 且配置了两台打印机；名字必须非空
      assert_true(infos.length() > 0)
      for info in infos {
        assert_true(info.name.length() > 0)
      }
    }
  }
}

///|
test "prt_default：本机默认目标必在列表内" {
  if !prt_skip_guard() {
    return
  }
  match prt_default() {
    Err(e) => {
      println("prt_default failed: \{e}")
      assert_true(false)
    }
    Ok(name) =>
      match prt_list() {
        Err(e) => {
          println("prt_list failed: \{e}")
          assert_true(false)
        }
        Ok(infos) => {
          println("prt: default = \{name}")
          assert_true(name.length() > 0)
          // 默认目标必须是列表中的打印机（类默认为 "类名/成员名"，取成员段）
          let want = prt_last_slash(name)
          let mut found = false
          for info in infos {
            if info.name == want {
              found = true
            }
          }
          assert_true(found)
        }
      }
  }
}

///|
test "prt_queue：本机真实队列查询与未知目标" {
  if !prt_skip_guard() {
    return
  }
  match prt_default() {
    Err(e) => {
      println("prt_default failed: \{e}")
      assert_true(false)
    }
    Ok(name) =>
      match prt_queue(name) {
        Ok(jobs) => {
          // 队列可能为空（本机当前为空），有任务时任务名非空、编号为正
          println("prt: queue of \{name} has \{jobs.length()} job(s)")
          for job in jobs {
            assert_true(job.name.length() > 0)
            assert_true(job.id > 0)
          }
        }
        Err(e) => {
          println("prt_queue failed: \{e}")
          assert_true(false)
        }
      }
  }
  // 不存在的目标：lpstat 以退出码 1 报错 → PrtCommandFailed（真实行为）
  assert_true(prt_queue("yue-no-such-printer") is Err(PrtCommandFailed(_)))
  // 空名参数校验
  assert_true(prt_queue("") is Err(PrtInvalidParam(_)))
}

///|
test "prt_print：仅校验参数表，不真实执行打印" {
  // 只断言参数校验分支，真实 lp 调用（有副作用，真实排队打印）不执行
  assert_true(prt_print("") is Err(PrtInvalidParam(_)))
  assert_true(
    prt_print(printer="HP-1", "/tmp/doc.pdf", copies=0)
    is Err(PrtInvalidParam(_)),
  )
  assert_true(
    prt_print(printer="HP-1", "/tmp/doc.pdf", copies=-3)
    is Err(PrtInvalidParam(_)),
  )
}
