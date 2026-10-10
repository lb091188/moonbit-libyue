// 打印机：Linux（CUPS）经 procrun 的 [pr_run] 调 lpstat 三条只读命令——
// `-p` 打印机列表（名称 / 可用状态）、`-d` 默认打印机、`-o <打印机>`
// 任务队列——以及 lp 提交打印任务的命令构造；子进程环境由 procrun 固定
// C locale，lpstat 输出语言恒定可解析。lpstat 缺失（系统未装 CUPS，
// shell 以退出码 127 呈现）→ PrtUnsupported，属合法降级。
// Windows 走 winspool 直连（EnumPrinters / GetDefaultPrinter / EnumJobs），
// 提交打印用文件的 "print" 动词（默认打印机）。lp 有副作用（真实提交
// 打印任务），仅实现不执行，wbtest 只断言其参数表。文本解析与命令构造
// 为纯函数（prt_ 前缀），printer_wbtest.mbt 白盒覆盖（真实样例取自本机
// CUPS 的 C locale 输出）。
//
// 典型用法：
//   match prt_default() {
//     Ok(name) => prt_print(printer=name, "/tmp/doc.pdf") // 有副作用：真实排队打印
//     Err(_) => () // 未装 CUPS 或无默认打印机
//   }

///|
/// 打印机可用状态：Idle 空闲可用、Printing 正在打印、
/// Paused 暂停接新任务（lpstat 的 "is holding new jobs"）、
/// Disabled 已禁用。
pub(all) enum PrinterStatus {
  Idle
  Printing
  Paused
  Disabled
}

///|
pub impl Show for PrinterStatus with fn output(self, logger) {
  match self {
    Idle => logger.write_string("PrinterStatus::Idle")
    Printing => logger.write_string("PrinterStatus::Printing")
    Paused => logger.write_string("PrinterStatus::Paused")
    Disabled => logger.write_string("PrinterStatus::Disabled")
  }
}

///|
pub extend PrinterStatus with Show::{to_string, output}

///|
/// 打印机信息：name 为 CUPS 目标名（队列名），status 为可用状态。
pub(all) struct PrinterInfo {
  name : String
  status : PrinterStatus
}

///|
pub impl Show for PrinterInfo with fn output(self, logger) {
  logger.write_string("PrinterInfo { name: ")
  logger.write_string(self.name)
  logger.write_string(", status: ")
  logger.write_string(self.status.to_string())
  logger.write_string(" }")
}

///|
pub extend PrinterInfo with Show::{to_string, output}

///|
/// 任务队列项：name 为 CUPS 作业名（"目标名-编号" 形态，如
/// "Gprinter-GP-9034T-12"），id 为作业编号。
pub(all) struct PrinterJob {
  name : String
  id : Int
}

///|
pub impl Show for PrinterJob with fn output(self, logger) {
  logger.write_string("PrinterJob { name: ")
  logger.write_string(self.name)
  logger.write_string(", id: ")
  logger.write_string(self.id.to_string())
  logger.write_string(" }")
}

///|
pub extend PrinterJob with Show::{to_string, output}

///|
pub(all) enum PrinterError {
  /// 系统未装 CUPS（lpstat 缺失）或平台不支持子进程执行
  PrtUnsupported
  /// 命令执行失败（启动失败 / 非零退出码 / 超时 / 被信号终止），带原因
  PrtCommandFailed(String)
  /// 工具输出解析失败，带原文
  PrtParseFailed(String)
  /// 调用参数非法（打印机名 / 文件路径为空、份数小于 1），带说明
  PrtInvalidParam(String)
}

///|
pub impl Show for PrinterError with fn output(self, logger) {
  match self {
    PrtUnsupported => logger.write_string("PrinterError::PrtUnsupported")
    PrtCommandFailed(m) =>
      logger.write_string("PrinterError::PrtCommandFailed(\{m})")
    PrtParseFailed(m) =>
      logger.write_string("PrinterError::PrtParseFailed(\{m})")
    PrtInvalidParam(m) =>
      logger.write_string("PrinterError::PrtInvalidParam(\{m})")
  }
}

///|
pub extend PrinterError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层：lpstat 输出解析 / 状态判定 / lp 参数构造（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 字符是否空白（空格 / 制表 / 换行 / 回车）。
fn prt_is_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
/// 按换行切分文本（丢弃行尾回车，空行不保留）。
fn prt_split_lines(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut cur = StringBuilder()
  let mut has = false
  for ch in s {
    if ch == '\n' {
      if has {
        out.push(cur.to_string())
        cur = StringBuilder()
        has = false
      }
    } else if ch != '\r' {
      cur.write_char(ch)
      has = true
    }
  }
  if has {
    out.push(cur.to_string())
  }
  out
}

///|
/// 按空白切分 token（连续空白视为一个分隔符，首尾空白忽略）。
fn prt_split_ws(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut cur = StringBuilder()
  let mut has = false
  for ch in s {
    if prt_is_ws(ch) {
      if has {
        out.push(cur.to_string())
        cur = StringBuilder()
        has = false
      }
    } else {
      cur.write_char(ch)
      has = true
    }
  }
  if has {
    out.push(cur.to_string())
  }
  out
}

///|
/// 去首尾空白。
fn prt_trim(s : String) -> String {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let n = chars.length()
  let mut i = 0
  let mut j = n - 1
  while i < n && prt_is_ws(chars[i]) {
    i = i + 1
  }
  while j >= i && prt_is_ws(chars[j]) {
    j = j - 1
  }
  let buf = StringBuilder()
  let mut k = i
  while k <= j {
    buf.write_char(chars[k])
    k = k + 1
  }
  buf.to_string()
}

///|
/// 截取文本首行（超长按 120 字符封顶，供错误消息回显）。
fn prt_first_line(s : String) -> String {
  let buf = StringBuilder()
  let mut n = 0
  for ch in s {
    if ch == '\n' || n >= 120 {
      break
    }
    buf.write_char(ch)
    n = n + 1
  }
  buf.to_string()
}

///|
/// 文本是否无符号十进制整数（"12" 为真；空串 / 负号 / 非数字为假）。
fn prt_is_digits(s : String) -> Bool {
  if s == "" {
    return false
  }
  for ch in s {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
/// 无符号十进制整数文本 → 整数（空串或含非数字为 None）。
fn prt_parse_uint(s : String) -> Int? {
  if !prt_is_digits(s) {
    return None
  }
  let mut v = 0
  for ch in s {
    v = v * 10 + (ch.to_int() - 48)
  }
  Some(v)
}

///|
/// 该状态是否可提交任务（Idle 空闲 / Printing 打印中均可送纸）。
pub fn prt_status_available(status : PrinterStatus) -> Bool {
  match status {
    Idle | Printing => true
    Paused | Disabled => false
  }
}

///|
/// 解析 `lpstat -p` 单行："printer NAME <状态描述>." → 打印机信息。
/// 状态描述取 CUPS 的四类形态（is idle / now printing / is holding new
/// jobs / disabled since），其余形态（类成员 "printer 类/机..."、`-a`
/// 的 "NAME accepting requests..." 行等）返回 None 跳过。
fn prt_parse_printer_line(line : String) -> PrinterInfo? {
  let toks = prt_split_ws(line)
  if toks.length() < 2 || toks[0] != "printer" {
    return None
  }
  let name = toks[1]
  if name == "" {
    return None
  }
  // 名字之后的 token 拼回状态描述（"is idle. enabled since ..."）
  let desc = StringBuilder()
  for i in 2..<toks.length() {
    if i > 2 {
      desc.write_char(' ')
    }
    desc.write_string(toks[i])
  }
  let tail = desc.to_string()
  let status = if tail.has_prefix("is idle") {
    Idle
  } else if tail.has_prefix("now printing") {
    Printing
  } else if tail.has_prefix("is holding new jobs") {
    Paused
  } else if tail.has_prefix("disabled") {
    Disabled
  } else {
    return None
  }
  Some({ name, status, })
}

///|
/// 解析 `lpstat -p` 全文：逐行取打印机信息，跳过空行与非打印机行，
/// 顺序保持 lpstat 返回序。空输出（未配置任何打印机）为空数组。
fn prt_parse_printer_list(out : String) -> Array[PrinterInfo] {
  let infos : Array[PrinterInfo] = []
  for line in prt_split_lines(out) {
    match prt_parse_printer_line(prt_trim(line)) {
      Some(info) => infos.push(info)
      None => ()
    }
  }
  infos
}

///|
/// 取第一个 ':' 之后的文本（无冒号为 None；不做 trim，由调用方处理）。
fn prt_after_colon(s : String) -> String? {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let mut at = -1
  for i in 0..<chars.length() {
    if chars[i] == ':' {
      at = i
      break
    }
  }
  if at < 0 {
    None
  } else {
    let buf = StringBuilder()
    let lo = at + 1
    for j in lo..<chars.length() {
      buf.write_char(chars[j])
    }
    Some(buf.to_string())
  }
}

///|
/// 解析 `lpstat -d` 输出："system default destination: NAME" → NAME
/// （类默认为 "类名/成员名" 形态，原样返回）。无默认目标
/// （"no system default destination"）、空值与无法识别的输出 → None。
fn prt_parse_default(out : String) -> String? {
  for line in prt_split_lines(out) {
    let t = prt_trim(line)
    if t.has_prefix("system default destination:") {
      match prt_after_colon(t) {
        Some(v) if prt_trim(v) != "" => return Some(prt_trim(v))
        _ => return None // 冒号后为空视为无默认
      }
    } else if t.has_prefix("no system default destination") {
      return None
    }
  }
  None
}

///|
/// 解析 `lpstat -o` 单行："NAME-ID USER SIZE DATE" → 任务项，
/// 其中 NAME-ID 为 CUPS 作业名（目标名与编号以最后一段 '-' 分隔，
/// 打印机名本身可含 '-'，如 Gprinter-GP-9034T-12 拆出作业 12）。
/// 无 '-' 分隔或编号非数字的行返回 None 跳过。
fn prt_parse_job_line(line : String) -> PrinterJob? {
  let toks = prt_split_ws(line)
  if toks.length() == 0 {
    return None
  }
  let label = toks[0]
  // 找最后一个 '-'，其后必须是全数字作业编号
  let chars : Array[Char] = []
  for ch in label {
    chars.push(ch)
  }
  let mut split = -1
  for i in 0..<chars.length() {
    if chars[i] == '-' {
      split = i
    }
  }
  if split <= 0 || split >= chars.length() - 1 {
    return None
  }
  let digits = StringBuilder()
  let lo = split + 1
  for j in lo..<chars.length() {
    digits.write_char(chars[j])
  }
  match prt_parse_uint(digits.to_string()) {
    None => None
    Some(id) => Some({ name: label, id, })
  }
}

///|
/// 解析 `lpstat -o` 全文：逐行取任务项，空输出（队列为空）为空数组。
fn prt_parse_queue(out : String) -> Array[PrinterJob] {
  let jobs : Array[PrinterJob] = []
  for line in prt_split_lines(out) {
    match prt_parse_job_line(prt_trim(line)) {
      Some(job) => jobs.push(job)
      None => ()
    }
  }
  jobs
}

///|
/// 构造 lp 打印任务参数表：printer 为 None 或空串表示用系统默认打印机；
/// path 为待打印文件路径；copies 为份数（≥ 1）。
/// 假设入参已通过参数校验（路径非空、份数 ≥ 1）。
fn prt_print_args(
  printer : String?,
  path : String,
  copies : Int,
) -> Array[String] {
  let args : Array[String] = []
  match printer {
    Some(p) if p != "" => {
      args.push("-d")
      args.push(p)
    }
    _ => ()
  }
  args.push("-n")
  args.push(copies.to_string())
  args.push(path)
  args
}

// ---------------------------------------------------------------------------
// 命令执行封装（复用 procrun 的 [pr_run]：spawn → 限时回收 → 读临时文件
// 输出；shell 退出码 127 = 命令缺失 → PrtUnsupported，其余非零退出为
// PrtCommandFailed）
// ---------------------------------------------------------------------------

///|
/// 运行命令行工具并捕获标准输出（prog 独立传入，便于缺失路径与真实命令
/// 走同一映射）：退出码 0 → Ok(stdout)；127（shell 无此命令）→
/// PrtUnsupported；其余非零退出 / 启动失败 / 超时 / 信号终止 /
/// 平台不支持为对应 Err。
fn prt_run_tool(
  prog : String,
  args : Array[String],
  timeout_ms? : Int = 4000,
) -> Result[String, PrinterError] {
  match pr_run(prog, args, timeout_ms~) {
    Ok(o) => Ok(o.stdout)
    Err(NonZeroExit(127, _)) => Err(PrtUnsupported)
    Err(NonZeroExit(code, err)) =>
      Err(
        PrtCommandFailed(
          "\{prog}: 退出码 \{code}（\{prt_first_line(err)}）",
        ),
      )
    Err(Timeout(m)) => Err(PrtCommandFailed(m))
    Err(SpawnFailed(m)) => Err(PrtCommandFailed(m))
    Err(Signaled(sig)) =>
      Err(PrtCommandFailed("\{prog}: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(PrtUnsupported)
  }
}

///|
/// 运行 lpstat 并捕获标准输出。
fn prt_lpstat(
  args : Array[String],
  timeout_ms? : Int = 4000,
) -> Result[String, PrinterError] {
  prt_run_tool("lpstat", args, timeout_ms~)
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 当前系统是否支持打印机查询（Linux 跑通只读的 lpstat -p；Windows
/// winspool 枚举成功）。每次调用真实探测，高频场景请调用方自行缓存。
pub fn prt_supported() -> Bool {
  if @yue.platform() == "windows" || @yue.platform() == "macos" {
    let ok = Ref(0)
    let _ = @yue.ffi_prt_list(ok)
    return ok.val == 1
  }
  match prt_lpstat(["-p"], timeout_ms=3000) {
    Ok(_) => true
    Err(PrtUnsupported) => false
    Err(_) => true // 工具存在但配置/服务异常，不算缺失
  }
}

///|
/// 列出全部打印机（队列名 + 可用状态）；Linux 未装 CUPS →
/// PrtUnsupported。顺序保持返回序；空数组表示未配置任何打印机。
pub fn prt_list() -> Result[Array[PrinterInfo], PrinterError] {
  if @yue.platform() == "windows" || @yue.platform() == "macos" {
    let ok = Ref(0)
    let text = @utf8.decode_lossy(@yue.ffi_prt_list(ok))
    if ok.val != 1 {
      return Err(PrtCommandFailed("打印机枚举失败"))
    }
    return Ok(prt_parse_win_list(text))
  }
  match prt_lpstat(["-p"]) {
    Ok(out) => Ok(prt_parse_printer_list(out))
    Err(e) => Err(e)
  }
}

///|
/// Windows 状态码 → PrinterStatus（shim 已归并：0 空闲 1 打印中 2 暂停
/// 3 不可用）。
pub fn prt_win_status_of(code : Int) -> PrinterStatus {
  match code {
    1 => Printing
    2 => Paused
    3 => Disabled
    _ => Idle
  }
}

///|
/// 解析 Windows 直连列表文本（"name\tstatus_code" 行）。
pub fn prt_parse_win_list(text : String) -> Array[PrinterInfo] {
  let infos : Array[PrinterInfo] = []
  for line in prt_split_lines(text) {
    let fields = sys_split_fields(line, '\t')
    if fields.length() == 2 {
      match prt_parse_uint(fields[1]) {
        Some(code) =>
          infos.push({ name: fields[0], status: prt_win_status_of(code) })
        None => ()
      }
    }
  }
  infos
}

///|
/// 读默认打印机名；Linux 未装 CUPS → PrtUnsupported；未设默认目标或无
/// 输出 → PrtParseFailed。
pub fn prt_default() -> Result[String, PrinterError] {
  if @yue.platform() == "windows" || @yue.platform() == "macos" {
    let ok = Ref(0)
    let name = prt_trim(@utf8.decode_lossy(@yue.ffi_prt_default(ok)))
    if ok.val != 1 || name == "" {
      return Err(PrtParseFailed("无默认打印机"))
    }
    return Ok(name)
  }
  match prt_lpstat(["-d"]) {
    Err(e) => Err(e)
    Ok(out) =>
      match prt_parse_default(out) {
        Some(name) => Ok(name)
        None => Err(PrtParseFailed("lpstat -d: \{prt_first_line(out)}"))
      }
  }
}

///|
/// 列出指定打印机队列上的任务（作业名 + 编号）；printer 为空串
/// → PrtInvalidParam；Linux 未装 CUPS → PrtUnsupported；目标不存在等
/// 非零退出 → PrtCommandFailed；空数组表示队列为空。Windows 的任务名
/// 为文档名（CUPS 的 "目标名-编号" 形态无对应）。
pub fn prt_queue(printer : String) -> Result[Array[PrinterJob], PrinterError] {
  if printer == "" {
    return Err(PrtInvalidParam("打印机名为空"))
  }
  if @yue.platform() == "windows" {
    let ok = Ref(0)
    let text = @utf8.decode_lossy(
      @yue.ffi_prt_queue(@yue.utf8_bytes(printer), ok),
    )
    if ok.val != 1 {
      return Err(PrtCommandFailed("打印队列查询失败"))
    }
    return Ok(prt_parse_win_queue(text))
  }
  // mac 不走 FFI（cupsGetJobs SDK 形态漂移，FFI 留哨兵），直接用 lpstat
  match prt_lpstat(["-o", printer]) {
    Ok(out) => Ok(prt_parse_queue(out))
    Err(e) => Err(e)
  }
}

///|
/// 解析 Windows 队列文本（"job_id\tdoc_name" 行）。
pub fn prt_parse_win_queue(text : String) -> Array[PrinterJob] {
  let jobs : Array[PrinterJob] = []
  for line in prt_split_lines(text) {
    let fields = sys_split_fields(line, '\t')
    if fields.length() == 2 {
      match prt_parse_uint(fields[0]) {
        Some(id) => jobs.push({ name: fields[1], id, })
        None => ()
      }
    }
  }
  jobs
}

///|
/// 提交打印任务（真实排队打印，有副作用，调用方自行确认时机）：Linux
/// 走 `lp [-d 打印机] -n 份数 文件`；Windows 用文件的 "print" 动词走
/// 默认打印机（显式 printer 必须与默认打印机一致，份数按动作次数实现）。
/// path 空串 / copies < 1 → PrtInvalidParam。
pub fn prt_print(
  printer? : String,
  path : String,
  copies? : Int = 1,
) -> Result[Unit, PrinterError] {
  if path == "" {
    return Err(PrtInvalidParam("文件路径为空"))
  }
  if copies < 1 {
    return Err(PrtInvalidParam("份数必须 ≥ 1：\{copies}"))
  }
  if @yue.platform() == "windows" || @yue.platform() == "macos" {
    match printer {
      Some(p) if p != "" =>
        match prt_default() {
          Ok(def) if def == p => ()
          _ =>
            return Err(
              PrtInvalidParam("仅支持默认打印机提交（传入 \{p}）"),
            )
        }
      _ => ()
    }
    for i = 0; i < copies; i = i + 1 {
      let ok = Ref(0)
      if @yue.ffi_prt_print(@yue.utf8_bytes(path), ok) != 0 || ok.val != 1 {
        return Err(PrtCommandFailed("打印提交失败"))
      }
    }
    return Ok(())
  }
  match
    prt_run_tool("lp", prt_print_args(printer, path, copies), timeout_ms=10000) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}
