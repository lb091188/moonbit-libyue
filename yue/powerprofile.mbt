// 电源计划（power-profiles-daemon）：经 procrun 的 [pr_run] 调
// powerprofilesctl 三条命令——list 读可用计划集、get 读当前计划、set
// 切换计划；计划三值 performance / balanced / power-saver 与后端内置
// 计划对齐。命令缺失（power-profiles-daemon 未安装，shell 以退出码 127
// 呈现）→ PpUnsupported，语义化不靠错误文本猜测。list 输出按后端返回
// 序（后端把推荐序排在前面时即推荐序）。list 输出解析与 set 参数构造
// 为纯函数（pp_ 前缀），powerprofile_wbtest.mbt 白盒覆盖；set 有副作用
// （切换系统电源计划），仅实现不执行，wbtest 只断言其参数表。
//
// 典型用法：
//   match pp_profiles() {
//     Ok(profiles) if profiles.contains(PBalanced) =>
//       pp_set(PBalanced) // 需要认证，调用方自行走授权流程
//     _ => ()
//   }

///|
/// 电源计划：PPowerSaver 省电、PBalanced 均衡、PPerformance 性能。
pub(all) enum PowerProfile {
  PPerformance
  PBalanced
  PPowerSaver
}

///|
pub impl Show for PowerProfile with fn output(self, logger) {
  logger.write_string("PowerProfile::")
  logger.write_string(pp_name_of(self))
}

///|
pub extend PowerProfile with Show::{to_string, output}

///|
pub(all) enum PowerProfileError {
  /// 平台不支持或 powerprofilesctl 缺失（power-profiles-daemon 未安装）
  PpUnsupported
  /// 命令执行失败（启动失败 / 非零退出码 / 超时 / 被信号终止），带原因
  PpCommandFailed(String)
  /// 工具输出解析失败，带原文
  PpParseFailed(String)
}

///|
pub impl Show for PowerProfileError with fn output(self, logger) {
  match self {
    PpUnsupported => logger.write_string("PowerProfileError::PpUnsupported")
    PpCommandFailed(m) =>
      logger.write_string("PowerProfileError::PpCommandFailed(\{m})")
    PpParseFailed(m) =>
      logger.write_string("PowerProfileError::PpParseFailed(\{m})")
  }
}

///|
pub extend PowerProfileError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层：计划名映射 / list 输出解析 / set 参数构造（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 字符是否空白（空格 / 制表 / 换行 / 回车）。
fn pp_is_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
/// 去首尾空白。
fn pp_trim(s : String) -> String {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let n = chars.length()
  let mut i = 0
  let mut j = n - 1
  while i < n && pp_is_ws(chars[i]) {
    i = i + 1
  }
  while j >= i && pp_is_ws(chars[j]) {
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
/// 按换行切分文本（丢弃行尾回车，空行不保留）。
fn pp_split_lines(s : String) -> Array[String] {
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
/// stderr 诊断文本压成单行并截断（错误消息只取首行前 120 字符，
/// 避免刷屏）。
fn pp_first_line(s : String) -> String {
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
/// 计划 → powerprofilesctl 侧名字（"performance" / "balanced" /
/// "power-saver"）。
fn pp_name_of(profile : PowerProfile) -> String {
  match profile {
    PPerformance => "performance"
    PBalanced => "balanced"
    PPowerSaver => "power-saver"
  }
}

///|
/// powerprofilesctl 侧名字 → 计划（未知名字为 None）。
fn pp_profile_of(name : String) -> PowerProfile? {
  match name {
    "performance" => Some(PPerformance)
    "balanced" => Some(PBalanced)
    "power-saver" => Some(PPowerSaver)
    _ => None
  }
}

///|
/// 判定 `powerprofilesctl list` 的「计划名行」并取计划名：行形如
/// `  balanced:`（恰好两空格缩进）或 `* balanced:`（活动计划带 '\*'
/// 标记），计划名后带冒号且不含空白；属性行（更深缩进的
/// `    Driver: x`）、无缩进行与其他杂行一律 None。
fn pp_line_profile(line : String) -> String? {
  let chars : Array[Char] = []
  for ch in line {
    chars.push(ch)
  }
  let n = chars.length()
  let mut i = 2
  if n < 3 {
    return None
  }
  if chars[0] == '*' && chars[1] == ' ' {
    i = 2 // 活动计划行 "* balanced:"
  } else if chars[0] == ' ' && chars[1] == ' ' {
    i = 2 // 普通计划行 "  balanced:"
  } else {
    return None // 缩进不符：属性行/杂行
  }
  if chars[n - 1] != ':' {
    return None // 计划名行以冒号结尾
  }
  let buf = StringBuilder()
  let mut k = i
  while k < n - 1 {
    if pp_is_ws(chars[k]) {
      return None // 属性行等含空白，排除
    }
    buf.write_char(chars[k])
    k = k + 1
  }
  let name = buf.to_string()
  if name == "" {
    None
  } else {
    Some(name)
  }
}

///|
/// 解析 `powerprofilesctl list` 输出：取全部计划名行映射为计划值，
/// 按输出序返回（未知计划名跳过，属性行不误收）。样例：
///   `* power-saver:` / `    Driver: x` / `  balanced:` / `  performance:`.
fn pp_parse_profile_list(out : String) -> Array[PowerProfile] {
  let profiles : Array[PowerProfile] = []
  for line in pp_split_lines(out) {
    match pp_line_profile(line) {
      None => ()
      Some(name) =>
        match pp_profile_of(name) {
          Some(p) => profiles.push(p)
          None => ()
        }
    }
  }
  profiles
}

///|
/// 解析 `powerprofilesctl get` 输出：整段trim 后按计划名匹配（"balanced"
/// → Some(PBalanced)；未知名字或空输出为 None）。
fn pp_parse_current(out : String) -> PowerProfile? {
  pp_profile_of(pp_trim(out))
}

///|
/// set 子命令的参数表（set <计划名>）。
fn pp_set_args(profile : PowerProfile) -> Array[String] {
  ["set", pp_name_of(profile)]
}

// ---------------------------------------------------------------------------
// 命令执行封装（复用 procrun 的 [pr_run]：spawn → 限时回收 → 临时文件
// 读回；shell 退出码 127 = 命令缺失 → PpUnsupported，其余非零退出为
// PpCommandFailed）
// ---------------------------------------------------------------------------

///|
/// 运行 powerprofilesctl 并捕获标准输出：退出码 0 → Ok(stdout)；127
/// （shell 无此命令，即 power-profiles-daemon 未安装）→ PpUnsupported；
/// 其余错误按 ProcError 类型映射。
fn pp_run(args : Array[String]) -> Result[String, PowerProfileError] {
  match pr_run("powerprofilesctl", args, timeout_ms=4000) {
    Ok(o) => Ok(o.stdout)
    Err(NonZeroExit(127, _)) => Err(PpUnsupported)
    Err(NonZeroExit(code, err)) =>
      Err(
        PpCommandFailed(
          "powerprofilesctl: 退出码 \{code}（\{pp_first_line(err)}）",
        ),
      )
    Err(Timeout(m)) => Err(PpCommandFailed(m))
    Err(SpawnFailed(m)) => Err(PpCommandFailed(m))
    Err(Signaled(sig)) =>
      Err(PpCommandFailed("powerprofilesctl: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(PpUnsupported)
  }
}

///|
/// powerprofilesctl 可用性：能跑通只读查询（get 退出 0）即可用；
/// 每次调用真实探测，高频场景请调用方自行缓存结果。
fn pp_available() -> Bool {
  if !pr_available() {
    return false
  }
  match pr_run("powerprofilesctl", ["get"], timeout_ms=3000) {
    Ok(_) => true
    Err(_) => false
  }
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 当前系统是否支持电源计划（powerprofilesctl 存在且可查询）。每次调用
/// 真实探测，高频场景请调用方自行缓存结果。
pub fn pp_supported() -> Bool {
  pp_available()
}

///|
/// 可用电源计划列表（按 `powerprofilesctl list` 输出序；power-profiles-
/// daemon 未安装 → PpUnsupported；查询失败 → PpCommandFailed；输出中
/// 解析不到任何计划 → PpParseFailed）。
pub fn pp_profiles() -> Result[Array[PowerProfile], PowerProfileError] {
  if !pr_available() {
    return Err(PpUnsupported)
  }
  match pp_run(["list"]) {
    Err(e) => Err(e)
    Ok(out) => {
      let profiles = pp_parse_profile_list(out)
      if profiles.length() == 0 {
        Err(PpParseFailed("powerprofilesctl list: \{pp_first_line(out)}"))
      } else {
        Ok(profiles)
      }
    }
  }
}

///|
/// 当前电源计划（`powerprofilesctl get`；power-profiles-daemon 未安装
/// → PpUnsupported；查询失败 → PpCommandFailed；输出不是已知计划名 →
/// PpParseFailed）。
pub fn pp_current() -> Result[PowerProfile, PowerProfileError] {
  if !pr_available() {
    return Err(PpUnsupported)
  }
  match pp_run(["get"]) {
    Err(e) => Err(e)
    Ok(out) =>
      match pp_parse_current(out) {
        Some(p) => Ok(p)
        None =>
          Err(PpParseFailed("powerprofilesctl get: \{pp_first_line(out)}"))
      }
  }
}

///|
/// 切换电源计划（`powerprofilesctl set <计划>`；有副作用，需要认证，
/// 调用方自行走授权流程）。power-profiles-daemon 未安装 → PpUnsupported；
/// 查询与执行失败 → PpCommandFailed。
pub fn pp_set(profile : PowerProfile) -> Result[Unit, PowerProfileError] {
  if !pr_available() {
    return Err(PpUnsupported)
  }
  match pr_run("powerprofilesctl", pp_set_args(profile), timeout_ms=4000) {
    Ok(_) => Ok(())
    Err(NonZeroExit(127, _)) => Err(PpUnsupported)
    Err(NonZeroExit(code, err)) =>
      Err(
        PpCommandFailed(
          "powerprofilesctl set: 退出码 \{code}（\{pp_first_line(err)}）",
        ),
      )
    Err(Timeout(m)) => Err(PpCommandFailed(m))
    Err(SpawnFailed(m)) => Err(PpCommandFailed(m))
    Err(Signaled(sig)) =>
      Err(PpCommandFailed("powerprofilesctl set: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(PpUnsupported)
  }
}
