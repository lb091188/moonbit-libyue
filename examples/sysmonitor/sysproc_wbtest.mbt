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
  assert_true(parse_proc_pid_stat("abc (cat) R 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22\n") is None)
}

///|
test "parse_cmdline：NUL 分隔转空格 / 去尾随 / 空串" {
  assert_eq(parse_cmdline("cat\u{0}/proc/self/stat\u{0}"), "cat /proc/self/stat")
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
test "F1 set_priority：越界nice参数(纯分支)" {
  assert_eq(set_priority(1, 20), Err(errno_text(22)))
  assert_eq(set_priority(1, -21), Err(errno_text(22)))
}

///|
test "F1 真实调用：自身 nice 读 / 不存在 pid kill(Linux)" {
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
      // 忙等 60ms 让本进程积累 tick，第三次采样后自身 CPU% 可非 0
      // （不强求非 0：调度窗口可能恰好未采到）
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
fn cell_text(c : @yue.TableCell) -> String {
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
  {
    pid,
    ppid,
    name,
    cmd,
    state,
    nice,
    threads,
    rss_kb,
    cpu_pct: cpu,
  }
}

///|
fn bench_procs() -> Array[ProcInfo] {
  [
    mk_proc(1, 0, "systemd", "/sbin/init", "S", 0.1, 20480, 0, 3),
    mk_proc(420, 1, "Firefox", "/usr/lib/firefox/firefox", "S", 12.5, 1835008, 0, 87),
    mk_proc(999, 420, "Web Content", "/usr/lib/firefox/firefox -contentproc", "R", 45.25, 2621440, 5, 12),
    mk_proc(1234, 1, "code", "/usr/share/code/code --type=renderer", "S", 3.0, 524288, -2, 30),
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
test "proc_row：列内容与格式(CPU 一位小数 / 内存人类可读)" {
  let p = mk_proc(999, 420, "Web Content", "/usr/lib/firefox", "R", 45.25, 2621440, 5, 12)
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
