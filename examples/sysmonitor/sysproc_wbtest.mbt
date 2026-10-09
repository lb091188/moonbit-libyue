// S3 进程数据层 + F1 进程管理白盒测试：解析纯函数喂字面量；F1 与
// ProcMonitor 的真实调用仅在 Linux 宿主（/proc 存在）时断言，其余平台
// 容错跳过。kill 目标用 pid_max+1（永不存在的 pid）验证 ESRCH 路径。

///|
test "parse_proc_pid_stat：真实格式 / comm 含空格括号 / 字段不足" {
  // 真实 /proc/[pid]/stat 行（cat 进程，23 个后置字段）
  let text = "3206509 (cat) R 3206507 3206509 3206507 0 -1 4194304 91 0 0 0 0 0 0 0 20 0 1 0 70651522 8785920 447 18446744073709551615 106024627793920 106024627811505 140722929362560 0 0 0 0 0 0 0 0 0 17 19 0 0 0 0 0 106024627825296 106024627826792 106024826908672 140722929366280 140722929366300 140722929366300 140722929369067 0\n"
  let st = parse_proc_pid_stat(text).unwrap()
  assert_eq(st.pid, 3206509)
  assert_eq(st.comm, "cat")
  assert_eq(st.state, "R")
  assert_eq(st.ppid, 3206507)
  assert_eq(st.utime, 0)
  assert_eq(st.stime, 0)
  assert_eq(st.nice, 0)
  assert_eq(st.threads, 1)
  assert_eq(st.start_time, 70651522)
  assert_eq(st.rss_pages, 447)
  // comm 含空格与嵌套括号：按最后一个 ')' 切分
  let weird = "1234 (foo (bar) baz) S 1 1234 1234 0 -1 4194304 100 0 0 0 55 66 0 0 20 5 3 0 999 1000 200 18446744073709551615 0 0 0 0 0 0 0 0 0 3 0 0 0 0 0 0 0 0 0 0 0 0 0\n"
  let w = parse_proc_pid_stat(weird).unwrap()
  assert_eq(w.comm, "foo (bar) baz")
  assert_eq(w.ppid, 1)
  assert_eq(w.utime, 55)
  assert_eq(w.stime, 66)
  assert_eq(w.nice, 5)
  assert_eq(w.threads, 3)
  assert_eq(w.rss_pages, 200)
  // 后置字段不足 22 个
  assert_true(parse_proc_pid_stat("1 (init) S 0 1 0\n") is None)
  // 无 '(' 或 ')' 缺失
  assert_true(parse_proc_pid_stat("1234 cat R 1\n") is None)
  assert_true(parse_proc_pid_stat("1234 (cat R 1 2\n") is None)
  // pid 非法
  assert_true(
    parse_proc_pid_stat(
      "abc (cat) R 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22\n",
    )
    is None,
  )
}

///|
test "parse_proc_pid_stat：负 nice 真实样本(nice=-20 内核线程)" {
  // 真实 /proc/4/stat（kworker/R-rcu_gp，nice=-20）；本机 142 个负 nice
  // 进程，负号不能被当非法字符丢掉（否则负 nice 全显示 0、ByNice 排序失真）
  let kt = "4 (kworker/R-rcu_gp) I 2 0 0 0 -1 69238880 0 0 0 0 0 0 0 0 0 -20 1 0 9 0 0 18446744073709551615 0 0 0 0 0 0 0 2147483647 0 0 0 0 17 0 0 0 0 0 0 0 0 0 0 0 0 0\n"
  let st = parse_proc_pid_stat(kt).unwrap()
  assert_eq(st.pid, 4)
  assert_eq(st.comm, "kworker/R-rcu_gp")
  assert_eq(st.state, "I")
  assert_eq(st.ppid, 2)
  assert_eq(st.nice, -20)
  assert_eq(st.threads, 1)
  assert_eq(st.start_time, 9)
  assert_eq(st.rss_pages, 0)
  // nice=-1（合法普通用户值）：字段合法长度 22 个的紧凑行
  let renice = "42 (renice) S 1 42 42 0 -1 4194304 1 0 0 0 2 3 0 0 0 -1 2 0 30 100 5\n"
  let r = parse_proc_pid_stat(renice).unwrap()
  assert_eq(r.pid, 42)
  assert_eq(r.comm, "renice")
  assert_eq(r.utime, 2)
  assert_eq(r.stime, 3)
  assert_eq(r.nice, -1)
  assert_eq(r.threads, 2)
  assert_eq(r.start_time, 30)
  assert_eq(r.rss_pages, 5)
  // nice=19（最大谦让）正样本同样按有符号解析
  let idle = "7 (idle) S 1 7 7 0 -1 4194304 1 0 0 0 2 3 0 0 0 19 2 0 30 100 5\n"
  assert_eq(parse_proc_pid_stat(idle).unwrap().nice, 19)
  // 字段值非法（非数字、裸负号）按 0 兜底，不当解析失败
  let bad = "7 (bad) S 1 7 7 0 -1 4194304 1 0 0 0 2 3 0 0 0 - 2 0 30 100 5\n"
  assert_eq(parse_proc_pid_stat(bad).unwrap().nice, 0)
}

///|
test "parse_cmdline：NUL 分隔转空格 / 去尾随 / 空串" {
  assert_eq(
    parse_cmdline("cat\u{0}/proc/self/stat\u{0}"),
    "cat /proc/self/stat",
  )
  assert_eq(parse_cmdline("sleep\u{0}100\u{0}"), "sleep 100")
  assert_eq(parse_cmdline(""), "")
  assert_eq(parse_cmdline("\u{0}"), "")
  // 非 ASCII 参数原样保留
  assert_eq(parse_cmdline("echo\u{0}中文\u{0}"), "echo 中文")
}

///|
test "proc_cpu_pct：单核满负荷 / 半负荷 / 首帧 / 多线程钳制 / 负增量" {
  // 1 秒墙钟内 100 tick（clk_tck=100）= 单核 100%
  assert_eq(proc_cpu_pct(1000, 1100, 100, 1.0, 4), 100.0)
  assert_eq(proc_cpu_pct(1000, 1050, 100, 1.0, 4), 50.0)
  // 首帧（墙钟增量 0）
  assert_eq(proc_cpu_pct(0, 500, 100, 0.0, 4), 0.0)
  // 2 线程各跑满一核：200%，不超钳制
  assert_eq(proc_cpu_pct(0, 200, 100, 1.0, 2), 200.0)
  // 4 线程满负荷 400% 按 cores×100 钳制
  assert_eq(proc_cpu_pct(0, 500, 100, 1.0, 2), 200.0)
  // 计数回绕式负增量 → 0
  assert_eq(proc_cpu_pct(1100, 1000, 100, 1.0, 4), 0.0)
  // clk_tck 非法
  assert_eq(proc_cpu_pct(0, 100, 0, 1.0, 4), 0.0)
}

///|
test "proc_tick_cpu_pct：无前样本当拍置 0(不拿开机累计当增量)" {
  // 新出现 pid：prev 缺失，cur 已是开机以来累计 tick。旧实现按 prev=0
  // 取差值会把全部累计算成本拍增量，CPU% 钉满格一拍；现在直接给 0，
  // 下一拍建立前样本后才出真实差值
  assert_eq(proc_tick_cpu_pct(None, 12_345_678, 100, 1.0, 4), 0.0)
  assert_eq(proc_tick_cpu_pct(None, 0, 100, 1.0, 4), 0.0)
  assert_eq(proc_tick_cpu_pct(None, 500, 100, 1.0, 8), 0.0)
  // 有前样本：与 proc_cpu_pct 同口径（满负荷 / 半负荷 / 钳制）
  assert_eq(proc_tick_cpu_pct(Some(1000), 1100, 100, 1.0, 4), 100.0)
  assert_eq(proc_tick_cpu_pct(Some(1000), 1050, 100, 1.0, 4), 50.0)
  assert_eq(proc_tick_cpu_pct(Some(0), 500, 100, 1.0, 2), 200.0)
  // 墙钟增量无效（同拍重采）仍为 0，与 proc_cpu_pct 一致
  assert_eq(proc_tick_cpu_pct(Some(1000), 5000, 100, 0.0, 4), 0.0)
  // 计数回绕式负增量 → 0
  assert_eq(proc_tick_cpu_pct(Some(1100), 1000, 100, 1.0, 4), 0.0)
}

///|
test "proc_children：ppid 构树 / 父不在列表 / 自父跳过 / 升序" {
  fn mk(pid : Int, ppid : Int) -> ProcInfo {
    {
      pid,
      ppid,
      name: "p\{pid}",
      cmd: "p\{pid}",
      state: "S",
      nice: 0,
      threads: 1,
      rss_kb: 0,
      cpu_pct: 0.0,
    }
  }

  let procs = [mk(1, 0), mk(10, 1), mk(11, 1), mk(100, 999), mk(7, 7)]
  let tree = proc_children(procs)
  assert_eq(tree.length(), 1)
  assert_eq(tree.get(1).unwrap(), [10, 11])
  // 父不在列表（999）与自父（7）都不建边
  assert_true(tree.get(100) is None)
  assert_true(tree.get(7) is None)
}

///|
test "errno_text：语义映射 / 不支持哨兵 / 未知码" {
  assert_eq(errno_text(1), "权限不足(EPERM:非属主且非 root)")
  assert_eq(errno_text(3), "进程不存在或已退出(ESRCH)")
  assert_eq(errno_text(13), "权限不足(EACCES)")
  assert_eq(errno_text(22), "参数非法(EINVAL:nice 需在 -20..19)")
  assert_eq(errno_text(-1000), "当前平台不支持(仅 Linux)")
  assert_eq(errno_text(999), "系统调用失败(errno 999)")
}

///|
test "errno_text:Windows 错误码翻译表目标值(SYS2 语义归一)" {
  // stub 内 Win32 → errno 翻译表的目标编号(ERROR_ACCESS_DENIED→1、
  // ERROR_INVALID_PARAMETER→22、ERROR_PRIVILEGE_NOT_HELD/
  // ERROR_SHARING_VIOLATION→13、ERROR_FILE_NOT_FOUND→2、
  // ERROR_NOT_ENOUGH_MEMORY/ERROR_OUTOFMEMORY→12、ERROR_INVALID_HANDLE→9、
  // ERROR_ALREADY_EXISTS→17、ERROR_BROKEN_PIPE→32、未列出归 EIO=5);
  // 翻译在 stub 内完成,MoonBit 侧 errno_text 与 Result 形态零改动,
  // 此处断言翻译目标值都产出语义正确的文案
  assert_eq(errno_text(1), "权限不足(EPERM:非属主且非 root)")
  assert_eq(errno_text(2), "系统调用失败(errno 2)")
  assert_eq(errno_text(3), "进程不存在或已退出(ESRCH)")
  assert_eq(errno_text(5), "系统调用失败(errno 5)")
  assert_eq(errno_text(9), "系统调用失败(errno 9)")
  assert_eq(errno_text(12), "系统调用失败(errno 12)")
  assert_eq(errno_text(13), "权限不足(EACCES)")
  assert_eq(errno_text(17), "系统调用失败(errno 17)")
  assert_eq(errno_text(22), "参数非法(EINVAL:nice 需在 -20..19)")
  assert_eq(errno_text(32), "系统调用失败(errno 32)")
}

///|
test "on_windows:平台探测(Linux 宿主恒 false)" {
  // 编译期由 stub 定;Linux / macOS 宿主上恒 false
  assert_eq(on_windows(), false)
}

///|
test "priority_level_name:四档档界与 stub sysmon_nice_to_class 一致" {
  assert_eq(priority_level_name(19), "空闲(IDLE)")
  assert_eq(priority_level_name(10), "空闲(IDLE)")
  assert_eq(priority_level_name(9), "正常(NORMAL)")
  assert_eq(priority_level_name(0), "正常(NORMAL)")
  assert_eq(priority_level_name(-9), "正常(NORMAL)")
  assert_eq(priority_level_name(-10), "高(HIGH)")
  assert_eq(priority_level_name(-16), "高(HIGH)")
  assert_eq(priority_level_name(-17), "实时(REALTIME)")
  assert_eq(priority_level_name(-20), "实时(REALTIME)")
}

///|
test "kill_button_labels:Windows 单按钮强杀 / Linux 两档" {
  let (win_end, win_force) = kill_button_labels("windows")
  assert_eq(win_end, "结束进程(立即终止)")
  assert_true(win_force is None)
  let (lin_end, lin_force) = kill_button_labels("linux")
  assert_eq(lin_end, "结束进程")
  assert_eq(lin_force.unwrap(), "强制结束")
  // 未知平台按 Linux 两档兜底
  assert_true(kill_button_labels("macos").1 is Some("强制结束"))
}

///|
test "priority_ui:Windows 四档说明 / Linux nice 说明" {
  let (wbtn, whint) = priority_ui("windows")
  assert_eq(wbtn, "设优先级")
  assert_true(whint.contains("离散档"))
  assert_true(whint.contains("实时"))
  let (lbtn, lhint) = priority_ui("linux")
  assert_eq(lbtn, "设 nice")
  assert_true(lhint.contains("-20..19"))
}

///|
test "priority_result:Windows 档位名+代表值 / Linux nice 原值 / 失败附因" {
  assert_eq(
    priority_result("windows", 0, 3, ""),
    "优先级已设为 正常(NORMAL)(代表值 0)(3 个进程)",
  )
  assert_eq(
    priority_result("windows", -20, 1, ""),
    "优先级已设为 实时(REALTIME)(代表值 -20)(1 个进程)",
  )
  assert_eq(priority_result("linux", 10, 2, ""), "nice 已设为 10(2 个进程)")
  let fail = priority_result("linux", 5, 1, ",[42]权限不足(EACCES)")
  assert_true(fail.contains("nice 已设为 5"))
  assert_true(fail.contains("1 个成功"))
  assert_true(fail.contains("[42]"))
}

///|
test "priority_col_header:Windows 标优先级 / Linux 标 nice" {
  assert_eq(priority_col_header("windows"), "优先级")
  assert_eq(priority_col_header("linux"), "nice")
}

///|
test "with_temp:有传感器给℃ / 来源不可用给「—」/ CPU 空值不追加" {
  let s = { chip: "coretemp", label: "Package id 0", celsius: 45.7 }
  assert_eq(with_temp("12%", Some(s)), "12% · 45℃")
  // hwmon 读不到(None)与列表为空( hottest None 同形):显示「—」占位
  assert_eq(with_temp("12%", None), "12% · —")
  // CPU 采样失败(值行本身为空)时整体不追加
  assert_eq(with_temp("", None), "")
}

///|
test "F1 set_priority：越界nice参数(纯分支)" {
  assert_eq(set_priority(1, 20), Err(errno_text(22)))
  assert_eq(set_priority(1, -21), Err(errno_text(22)))
}

///|
test "F1 真实调用：自身 nice 读 / 不存在 pid kill/get/set(Linux)" {
  // 读自身 pid（/proc/self/stat 是当前进程）
  let self_pid = match read_text_file("/proc/self/stat") {
    None => -1
    Some(t) => parse_proc_pid_stat(t).map(fn(s) { s.pid }).unwrap_or(-1)
  }
  if self_pid > 0 {
    // 读 nice：普通进程为 0，容器内可能不同，只验证 Ok 且值域合法
    match get_priority(self_pid) {
      Ok(v) => assert_true(v >= -20 && v <= 19)
      Err(_) => () // 权限受限环境跳过
    }
    // 对自身设 nice 10 再还原（非 root 允许变谦让）
    match set_priority(self_pid, 10) {
      Ok(_) => {
        assert_eq(get_priority(self_pid), Ok(10))
        ignore(set_priority(self_pid, 0))
      }
      Err(_) => ()
    }
    // pid_max+1 永不存在的 pid：ESRCH
    // signal 0 探活：自身 pid 必存在，走通成功路径
    assert_eq(kill_signal(self_pid, 0), Ok(()))
    // pid_max 内核上限 4194304，+1 永不存在的 pid：走通 errno 失败路径
    assert_eq(kill_signal(4194305, SIGTERM), Err(errno_text(3)))
    // get/set 对不存在 pid 同样归一 ESRCH（Windows 侧 OpenProcess 的
    // ERROR_INVALID_PARAMETER 特判同此语义）
    assert_eq(get_priority(4194305), Err(errno_text(3)))
    assert_eq(set_priority(4194305, 5), Err(errno_text(3)))
  }
}

///|
test "S3 ProcMonitor：真实 /proc 全量采样 + 二次差值(Linux)" {
  let mon = ProcMonitor::new(4)
  match mon.tick() {
    None => () // 非 Linux 宿主（stub 占位）跳过
    Some(procs) => {
      assert_true(procs.length() > 0)
      // 含 pid 1（init/systemd），按 pid 升序
      assert_eq(procs[0].pid <= procs[procs.length() - 1].pid, true)
      let mut has_init = false
      for p in procs {
        assert_true(p.pid > 0)
        assert_true(p.ppid >= 0)
        assert_true(p.threads >= 1)
        assert_true(p.rss_kb >= 0)
        assert_true(p.cpu_pct >= 0.0 && p.cpu_pct <= 400.0)
        assert_true(p.name.length() > 0)
        assert_true(p.cmd.length() > 0)
        if p.pid == 1 {
          has_init = true
        }
      }
      assert_true(has_init)
      // 二次采样：前样本已建立，墙钟增量有效
      let second = mon.tick()
      assert_true(second is Some(_))
      // 新出现 pid 当拍 CPU% 置 0（端到端）：忙等 200ms 让系统起新进程，
      // 之后凡前样本没有的 pid，本拍必须是 0——旧逻辑按 prev=0 取差值会
      // 拿开机累计 tick 当增量钉满格一拍。窗口内没有新进程时这组断言空转，
      // 不构成 flaky。
      let seen : Array[Int] = []
      for p in procs {
        seen.push(p.pid)
      }
      let ts = mono_start()
      while mono_end(ts) < 200_000.0 {
        continue
      }
      match mon.tick() {
        None => ()
        Some(after) =>
          for p in after {
            if !seen.contains(p.pid) {
              assert_eq(p.cpu_pct, 0.0)
            }
          }
      }
    }
  }
}

///|
#external
type Timestamp

///|
extern "C" fn mono_start() -> Timestamp = "moonbit_monotonic_clock_start"

///|
extern "C" fn mono_end(ts : Timestamp) -> Double = "moonbit_monotonic_clock_stop"

///|
/// 全量进程采样耗时（release 计时，数值记入 docs/zh/adaptation.md）：
/// 与 1Hz 刷新同路径（枚举 /proc + 逐进程读 stat/cmdline + 差值）。
test "bench: ProcMonitor 全量采样耗时(release 计时)" {
  let cores = match cpu_info() {
    None => 1
    Some(info) => info.cores
  }
  let mon = ProcMonitor::new(cores)
  match mon.tick() {
    None => () // 非 Linux 宿主跳过
    Some(first) => {
      let rounds = 20
      let ts = mono_start()
      let mut count = 0
      for _i in 0..<rounds {
        match mon.tick() {
          None => ()
          Some(procs) => count = procs.length()
        }
      }
      let ms = mono_end(ts) / rounds.to_double() / 1000.0
      println(
        "sysmonitor: proc tick=\{ms}ms procs=\{count} (first=\{first.length()})",
      )
    }
  }
}

///|
/// 取单元格文本（非文本单元格给占位，测试断言用）。
fn cell_text(c : @components.TableCell) -> String {
  match c {
    CellText(t) => t
    _ => "(non-text)"
  }
}

///|
/// 构造测试进程行（字段序同 ProcInfo）。
fn mk_proc(
  pid : Int,
  ppid : Int,
  name : String,
  cmd : String,
  state : String,
  cpu : Double,
  rss_kb : Int64,
  nice : Int,
  threads : Int,
) -> ProcInfo {
  { pid, ppid, name, cmd, state, nice, threads, rss_kb, cpu_pct: cpu, }
}

///|
fn bench_procs() -> Array[ProcInfo] {
  [
    mk_proc(1, 0, "systemd", "/sbin/init", "S", 0.1, 20480, 0, 3),
    mk_proc(
      420, 1, "Firefox", "/usr/lib/firefox/firefox", "S", 12.5, 1835008, 0, 87,
    ),
    mk_proc(
      999, 420, "Web Content", "/usr/lib/firefox/firefox -contentproc", "R", 45.25,
      2621440, 5, 12,
    ),
    mk_proc(
      1234, 1, "code", "/usr/share/code/code --type=renderer", "S", 3.0, 524288,
      -2, 30,
    ),
  ]
}

///|
test "filter_procs：空 query 全收 / pid / 名称 / 命令行 / 大小写 / 无匹配" {
  let procs = bench_procs()
  // 空 query：全收且返回新数组
  let all = filter_procs(procs, "  ")
  assert_eq(all.length(), 4)
  // pid 子串
  assert_eq(filter_procs(procs, "42").length(), 1)
  assert_eq(filter_procs(procs, "42")[0].pid, 420)
  assert_eq(filter_procs(procs, "999").length(), 1)
  // 名称（大小写不敏感）
  assert_eq(filter_procs(procs, "firefox").length(), 2)
  assert_eq(filter_procs(procs, "FIREFOX").length(), 2)
  // 命令行
  assert_eq(filter_procs(procs, "contentproc").length(), 1)
  assert_eq(filter_procs(procs, "contentproc")[0].pid, 999)
  // 无匹配
  assert_eq(filter_procs(procs, "nonexistent-xyz").length(), 0)
  // 入参不被修改
  assert_eq(procs.length(), 4)
}

///|
test "sort_procs：各列升降序 + 名称大小写不敏感 + 空数组" {
  let procs = bench_procs()
  // CPU 降序（默认监控视图）
  let by_cpu = sort_procs(procs, ByCpu, false)
  assert_eq(by_cpu[0].pid, 999)
  assert_eq(by_cpu[3].pid, 1)
  // CPU 升序
  let by_cpu_asc = sort_procs(procs, ByCpu, true)
  assert_eq(by_cpu_asc[0].pid, 1)
  assert_eq(by_cpu_asc[3].pid, 999)
  // PID 升序
  let by_pid = sort_procs(procs, ByPid, true)
  assert_eq(by_pid[0].pid, 1)
  assert_eq(by_pid[3].pid, 1234)
  // 名称（code < Firefox < systemd < Web Content，大小写不敏感）
  let by_name = sort_procs(procs, ByName, true)
  assert_eq(by_name[0].name, "code")
  assert_eq(by_name[1].name, "Firefox")
  assert_eq(by_name[2].name, "systemd")
  assert_eq(by_name[3].name, "Web Content")
  // 内存 / nice / 线程
  let by_mem = sort_procs(procs, ByMem, false)
  assert_eq(by_mem[0].pid, 999)
  let by_nice = sort_procs(procs, ByNice, false)
  assert_eq(by_nice[0].pid, 999)
  let by_threads = sort_procs(procs, ByThreads, false)
  assert_eq(by_threads[0].pid, 420)
  // 空数组不炸
  assert_eq(sort_procs([], ByCpu, false).length(), 0)
  // 入参不被修改
  assert_eq(procs[0].pid, 1)
}

///|
test "sort_procs：ByNice 负值排序(负 nice 不再被钳成 0)" {
  // nice=-20 的进程（内核 worker / 提权进程）解析回归后不再是 0，
  // 否则降序时与普通进程混在一档、排不出真实优先级
  let procs = [
    mk_proc(101, 1, "kworker", "[kworker]", "I", 0.0, 0, -20, 1),
    mk_proc(102, 1, "normal", "/bin/normal", "S", 0.0, 0, 0, 1),
    mk_proc(103, 1, "idle", "/bin/idle", "S", 0.0, 0, 19, 1),
  ]
  // 降序：nice 越大越谦让 → 19 / 0 / -20
  let desc = sort_procs(procs, ByNice, false)
  assert_eq(desc[0].pid, 103)
  assert_eq(desc[1].pid, 102)
  assert_eq(desc[2].pid, 101)
  // 升序：-20 / 0 / 19
  let asc = sort_procs(procs, ByNice, true)
  assert_eq(asc[0].pid, 101)
  assert_eq(asc[1].pid, 102)
  assert_eq(asc[2].pid, 103)
  // 入参不被修改
  assert_eq(procs[0].pid, 101)
}

///|
test "proc_row：列内容与格式(CPU 一位小数 / 内存人类可读)" {
  let p = mk_proc(
    999, 420, "Web Content", "/usr/lib/firefox", "R", 45.25, 2621440, 5, 12,
  )
  let row = proc_row(p)
  assert_eq(row.cells.length(), 8)
  assert_eq(cell_text(row.cells[0]), "999")
  assert_eq(cell_text(row.cells[1]), "Web Content")
  assert_eq(cell_text(row.cells[2]), "R")
  assert_eq(cell_text(row.cells[3]), "45.3")
  assert_eq(cell_text(row.cells[4]), "2.5 GB")
  assert_eq(cell_text(row.cells[5]), "5")
  assert_eq(cell_text(row.cells[6]), "12")
  assert_eq(cell_text(row.cells[7]), "/usr/lib/firefox")
  // 一位小数取整
  let p2 = mk_proc(1, 0, "init", "/sbin/init", "S", 0.04, 1024, 0, 1)
  assert_eq(cell_text(proc_row(p2).cells[3]), "0.0")
  assert_eq(cell_text(proc_row(p2).cells[4]), "1 MB")
}

///|
test "sort_of_col：列号映射(状态/命令行不参与)" {
  assert_true(sort_of_col(0) is Some(ByPid))
  assert_true(sort_of_col(1) is Some(ByName))
  assert_true(sort_of_col(2) is None)
  assert_true(sort_of_col(3) is Some(ByCpu))
  assert_true(sort_of_col(4) is Some(ByMem))
  assert_true(sort_of_col(5) is Some(ByNice))
  assert_true(sort_of_col(6) is Some(ByThreads))
  assert_true(sort_of_col(7) is None)
  assert_true(sort_of_col(-1) is None)
}
