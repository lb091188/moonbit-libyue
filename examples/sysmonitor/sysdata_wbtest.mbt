// 监控数据层白盒测试（S0-S2）：解析原语与 /proc 纯函数语义，全部喂
// 字面量文本；S0 真实文件读取仅在本机存在 /proc 时断言（Linux 宿主外
// 自动跳过）。基准与长跑内存随 UI 批次（U5）补。

///|
test "split_fields：单空格 / 制表 / 连续空白 / 首尾空白 / 空串" {
  let basic = split_fields("cpu  100 200 300")
  assert_eq(basic.length(), 4)
  assert_eq(basic[0].to_owned(), "cpu")
  assert_eq(basic[3].to_owned(), "300")
  let tabs = split_fields("MemTotal:\t32665012\tkB")
  assert_eq(tabs.length(), 3)
  assert_eq(tabs[1].to_owned(), "32665012")
  // 连续空白视为一个分隔，首尾空白跳过
  let mixed = split_fields("  a \t\t b   c  ")
  assert_eq(mixed.length(), 3)
  assert_eq(mixed[0].to_owned(), "a")
  assert_eq(mixed[2].to_owned(), "c")
  assert_eq(split_fields("").length(), 0)
  assert_eq(split_fields("   ").length(), 0)
}

///|
test "parse_u64：正常 / 空 / 非数字 / 大数" {
  assert_eq(parse_u64("0"), Some(0))
  assert_eq(parse_u64("1370226960"), Some(1370226960))
  assert_eq(parse_u64("9007199254740993"), Some(9007199254740993))
  assert_eq(parse_u64(""), None)
  assert_eq(parse_u64("12a"), None)
  assert_eq(parse_u64("a12"), None)
  assert_eq(parse_u64("-5"), None)
  assert_eq(parse_u64(" 5"), None)
}

///|
test "parse_double：整数 / 小数 / 负 / 前导点 / 非法" {
  assert_eq(parse_double("4500"), Some(4500.0))
  assert_eq(parse_double("4500.000"), Some(4500.0))
  assert_eq(parse_double("2.60"), Some(2.6))
  assert_eq(parse_double("-1.5"), Some(-1.5))
  assert_eq(parse_double(".5"), Some(0.5))
  assert_eq(parse_double("5."), Some(5.0))
  assert_eq(parse_double(""), None)
  assert_eq(parse_double("1.2.3"), None)
  assert_eq(parse_double("1,5"), None)
  assert_eq(parse_double("abc"), None)
}

///|
test "parse_proc_stat：真实格式总行 + 各核 / intr 行忽略 / 缺字段补 0" {
  let text = "cpu  25586524 6831 11878653 1370226960 1000270 0 43051 0 10055821 0\ncpu0 852902 194 414831 69006982 28214 0 857 0 247428 0\ncpu1 284887 92 78634 70056474 104221 0 478 0 58746 0\nintr 123456 0 0 0\nctxt 987654321\n"
  let (total, cores) = parse_proc_stat(text).unwrap()
  assert_eq(total.user, 25586524)
  // 列序 user nice system idle iowait irq softirq steal guest guest_nice：
  // 第 9 列 guest 由内核计入 user，不单独解析
  assert_eq(total.softirq, 43051)
  assert_eq(total.steal, 0)
  assert_eq(cores.length(), 2)
  assert_eq(cores[0].user, 852902)
  assert_eq(cores[1].iowait, 104221)
  // 缺 steal 及以后字段（旧内核 7 列）：补 0 不炸
  let short = parse_proc_stat("cpu 100 0 50 800 50 0 0\n").unwrap().0
  assert_eq(short.softirq, 0)
  assert_eq(short.steal, 0)
  assert_eq(short.total(), 1000)
  // 无 cpu 总行
  assert_true(parse_proc_stat("cpu0 1 2 3 4\n") is None)
  assert_true(parse_proc_stat("") is None)
}

///|
test "cpu_usage：差值占用 / 零增量 / 负增量钳制 / 全空闲" {
  let prev : CpuTimes = {
    user: 100,
    nice: 0,
    system: 50,
    idle: 800,
    iowait: 50,
    irq: 0,
    softirq: 0,
    steal: 0,
  }
  let cur : CpuTimes = {
    user: 120,
    nice: 0,
    system: 60,
    idle: 860,
    iowait: 60,
    irq: 0,
    softirq: 0,
    steal: 0,
  }
  // dt=100, db=(180-150)=30 → 0.3
  let u = cpu_usage(prev, cur)
  assert_true((u - 0.3).abs() < 1.0e-12)
  // 同一份采样：增量为 0 → 0
  assert_eq(cpu_usage(prev, prev), 0.0)
  // 计数回绕式负增量 → 钳到 0
  let wrap_prev : CpuTimes = {
    user: 100,
    nice: 0,
    system: 0,
    idle: 0,
    iowait: 0,
    irq: 0,
    softirq: 0,
    steal: 0,
  }
  let wrap_cur : CpuTimes = {
    user: 0,
    nice: 0,
    system: 0,
    idle: 50,
    iowait: 60,
    irq: 0,
    softirq: 0,
    steal: 0,
  }
  assert_eq(cpu_usage(wrap_prev, wrap_cur), 0.0)
  // 全空闲区间 → 0
  let idle_cur : CpuTimes = {
    user: prev.user,
    nice: 0,
    system: prev.system,
    idle: prev.idle + 110,
    iowait: prev.iowait,
    irq: 0,
    softirq: 0,
    steal: 0,
  }
  assert_eq(cpu_usage(prev, idle_cur), 0.0)
}

///|
test "parse_cpuinfo：型号 / 核数 / 主频 / ARM 回退 / 无 processor 行" {
  let x86 = "processor\t: 0\nmodel name\t: 12th Gen Intel(R) Core(TM) i7-12700F\ncpu MHz\t\t: 4500.000\n\nprocessor\t: 1\nmodel name\t: 12th Gen Intel(R) Core(TM) i7-12700F\ncpu MHz\t\t: 4500.000\n"
  let info = parse_cpuinfo(x86).unwrap()
  assert_eq(info.model, "12th Gen Intel(R) Core(TM) i7-12700F")
  assert_eq(info.cores, 2)
  assert_eq(info.mhz, 4500.0)
  // ARM 开发板：无 model name，回退 Processor
  let arm = "processor\t: 0\nProcessor\t: ARMv7 Cortex-A53\n"
  let arm_info = parse_cpuinfo(arm).unwrap()
  assert_eq(arm_info.model, "ARMv7 Cortex-A53")
  assert_eq(arm_info.mhz, 0.0)
  // 非 Linux 文本
  assert_true(parse_cpuinfo("model name: nothing\n") is None)
  assert_true(parse_cpuinfo("") is None)
}

///|
test "parse_meminfo：全字段 / MemAvailable 回退 / 缺 MemTotal / 派生量" {
  let text = "MemTotal:       32665012 kB\nMemFree:          785316 kB\nMemAvailable:   20532740 kB\nBuffers:         1820824 kB\nSwapTotal:       8388604 kB\nSwapFree:        8000000 kB\n"
  let mem = parse_meminfo(text).unwrap()
  assert_eq(mem.total_kb, 32665012)
  assert_eq(mem.available_kb, 20532740)
  assert_eq(mem.swap_total_kb, 8388604)
  assert_eq(mem.swap_free_kb, 8000000)
  assert_eq(mem.used_kb(), 32665012 - 20532740)
  assert_true((mem.usage() - (32665012 - 20532740).to_double() / 32665012.0).abs() < 1.0e-12)
  assert_true((mem.swap_usage() - 388604.0 / 8388604.0).abs() < 1.0e-12)
  // 老内核无 MemAvailable：回退 MemFree
  let old = parse_meminfo("MemTotal: 1000 kB\nMemFree: 200 kB\n").unwrap()
  assert_eq(old.available_kb, 200)
  // 无 swap 行：swap 指标为 0
  assert_eq(old.swap_total_kb, 0)
  assert_eq(old.swap_usage(), 0.0)
  // 缺 MemTotal
  assert_true(parse_meminfo("MemFree: 200 kB\n") is None)
  assert_true(parse_meminfo("") is None)
}

///|
test "S0 read_text_file：不存在路径 None + /proc 真实读取（仅 Linux 宿主）" {
  assert_eq(read_text_file("/sysmonitor/definitely/not/exist"), None)
  // 目录按失败处理
  assert_eq(read_text_file("/proc"), None)
  match read_text_file("/proc/stat") {
    None => () // 非 Linux 宿主无 /proc，跳过真实断言
    Some(text) => {
      let (total, cores) = parse_proc_stat(text).unwrap()
      assert_true(total.total() > 0)
      assert_true(cores.length() > 0)
      // 两次采样（间隔 120ms）差值占用率落在 0..1
      let (t2, _c2) = parse_proc_stat(read_text_file("/proc/stat").unwrap()).unwrap()
      let u = cpu_usage(total, t2)
      assert_true(u >= 0.0 && u <= 1.0)
    }
  }
  match read_text_file("/proc/meminfo") {
    None => ()
    Some(text) => assert_true(parse_meminfo(text).unwrap().total_kb > 0)
  }
  match read_text_file("/proc/cpuinfo") {
    None => ()
    Some(text) => assert_true(parse_cpuinfo(text).unwrap().cores > 0)
  }
}
