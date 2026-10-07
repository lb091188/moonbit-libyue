// 系统时区与 NTP 开关状态（timedate1）：读走系统总线 D-Bus 属性
// org.freedesktop.timedate1 的 Timezone（字符串）/ NTP（布尔）（经
// @traybus 通用 D-Bus 层 [gdbus_get_property_system]），总线不可达或
// 服务不在线时回退 `timedatectl show` 的 KEY=VALUE 文本输出（经
// procrun 的 [pr_run]，子进程固定 C locale，输出恒定可解析）。写
// （[lc_set_timezone]）经 D-Bus 属性写 Timezone，有副作用，仅实现不
// 执行。本地语言（[lc_lang]）读 $LANG 环境变量（core/env）。
// timedatectl 输出解析与时区标识校验为纯函数（lc_ 前缀），
// locale_sys_wbtest.mbt 白盒覆盖。
//
// 典型用法：
//   let tz = lc_timezone()   // Ok("Asia/Shanghai")
//   let ntp = lc_ntp()       // Ok(true)
//   lc_set_timezone("Asia/Tokyo") // 需要认证，调用方自行走授权流程

///|
pub(all) enum LocaleError {
  /// 平台/服务不支持（非 Linux；系统总线不可达且 timedatectl 缺失；
  /// $LANG 未设置）
  LcUnsupported
  /// 总线调用失败（timedate1 拒绝 / 应答超时 / 总线不可达），带原因
  LcBusFailed(String)
  /// 命令执行失败（启动失败 / 非零退出码 / 超时 / 被信号终止），带原因
  LcCommandFailed(String)
  /// 输出解析失败（timedatectl 输出中无目标行），带说明
  LcParseFailed(String)
  /// 时区标识非法（空串 / 含空白 / 以 '/' 开头 / 含 '..'），带原值
  LcInvalidTimezone(String)
}

///|
pub impl Show for LocaleError with fn output(self, logger) {
  match self {
    LcUnsupported => logger.write_string("LocaleError::LcUnsupported")
    LcBusFailed(m) => logger.write_string("LocaleError::LcBusFailed(\{m})")
    LcCommandFailed(m) =>
      logger.write_string("LocaleError::LcCommandFailed(\{m})")
    LcParseFailed(m) => logger.write_string("LocaleError::LcParseFailed(\{m})")
    LcInvalidTimezone(m) =>
      logger.write_string("LocaleError::LcInvalidTimezone(\{m})")
  }
}

///|
pub extend LocaleError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层：文本切分 / timedatectl KEY=VALUE 解析 / 时区标识校验
// （locale_sys_wbtest.mbt 白盒覆盖）
// ---------------------------------------------------------------------------

///|
/// 字符是否空白（空格 / 制表 / 换行 / 回车）。
fn lc_is_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
/// 去首尾空白。
fn lc_trim(s : String) -> String {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let n = chars.length()
  let mut i = 0
  let mut j = n - 1
  while i < n && lc_is_ws(chars[i]) {
    i = i + 1
  }
  while j >= i && lc_is_ws(chars[j]) {
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
fn lc_split_lines(s : String) -> Array[String] {
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
fn lc_first_line(s : String) -> String {
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
/// 剥指定前缀（s 以 prefix 开头返回剩余部分，否则 None）。
fn lc_strip_prefix(s : String, prefix : String) -> String? {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let pre : Array[Char] = []
  for ch in prefix {
    pre.push(ch)
  }
  if chars.length() < pre.length() {
    return None
  }
  for i in 0..<pre.length() {
    if chars[i] != pre[i] {
      return None
    }
  }
  let buf = StringBuilder()
  for i in pre.length()..<chars.length() {
    buf.write_char(chars[i])
  }
  Some(buf.to_string())
}

///|
/// timedatectl show 的 KEY=VALUE 行取值：整段文本中找到 `key=` 开头的
/// 首行，返回去空白后的值（`Timezone=Asia/Shanghai` → Asia/Shanghai）；
/// 无该键行为 None。
fn lc_parse_property(text : String, key : String) -> String? {
  let prefix = key + "="
  for line in lc_split_lines(text) {
    let t = lc_trim(line)
    match lc_strip_prefix(t, prefix) {
      None => ()
      Some(v) => return Some(lc_trim(v))
    }
  }
  None
}

///|
/// timedatectl show 输出的 Timezone 行 → IANA 时区标识（无该行为
/// None）。
fn lc_parse_timezone(text : String) -> String? {
  lc_parse_property(text, "Timezone")
}

///|
/// timedatectl show 输出的 NTP 行 → 布尔（"NTP=yes" → true，"NTP=no"
/// → false；无该行或值非 yes/no 为 None）。
fn lc_parse_ntp(text : String) -> Bool? {
  match lc_parse_property(text, "NTP") {
    None => None
    Some(v) =>
      match v {
        "yes" => Some(true)
        "no" => Some(false)
        _ => None
      }
  }
}

///|
/// 时区标识合法性：非空、不含空白、不以 '/' 开头、不含 ".."（拒绝
/// 路径穿越形态；"Asia/Shanghai" 与 "UTC" 均合法）。
fn lc_valid_timezone(tz : String) -> Bool {
  if tz == "" {
    return false
  }
  if tz.has_prefix("/") {
    return false
  }
  if tz.contains("..") {
    return false
  }
  let chars : Array[Char] = []
  for ch in tz {
    chars.push(ch)
  }
  for ch in chars {
    if lc_is_ws(ch) {
      return false
    }
  }
  true
}

// ---------------------------------------------------------------------------
// timedate1 服务定位与 D-Bus 读写（系统总线，@traybus 通用 D-Bus 层）
// ---------------------------------------------------------------------------

///|
/// timedate1 服务名（系统总线）。
fn lc_dest() -> String {
  "org.freedesktop.timedate1"
}

///|
/// timedate1 对象路径。
fn lc_path() -> String {
  "/org/freedesktop/timedate1"
}

///|
/// timedate1 接口名。
fn lc_iface() -> String {
  "org.freedesktop.timedate1"
}

///|
/// D-Bus 错误 → LocaleError：读取路径只归一为 BusFailed（由调用方决定
/// 是否回退命令）。
fn lc_bus_err(e : @traybus.GDBusError) -> LocaleError {
  LcBusFailed("\{e.name}: \{e.message}")
}

///|
/// D-Bus 读字符串属性（应答值已由通用层拆掉 variant 包裹）。
fn lc_dbus_string_prop(prop : String) -> Result[String, LocaleError] {
  match
    @traybus.gdbus_get_property_system(lc_dest(), lc_path(), lc_iface(), prop) {
    Ok(@traybus.GVString(s)) => Ok(s)
    Ok(_) => Err(LcParseFailed("timedate1.\{prop} 不是字符串属性"))
    Err(e) => Err(lc_bus_err(e))
  }
}

///|
/// D-Bus 读布尔属性。
fn lc_dbus_bool_prop(prop : String) -> Result[Bool, LocaleError] {
  match
    @traybus.gdbus_get_property_system(lc_dest(), lc_path(), lc_iface(), prop) {
    Ok(@traybus.GVBool(b)) => Ok(b)
    Ok(_) => Err(LcParseFailed("timedate1.\{prop} 不是布尔属性"))
    Err(e) => Err(lc_bus_err(e))
  }
}

// ---------------------------------------------------------------------------
// timedatectl 命令回退路径（复用 procrun 的 [pr_run]）
// ---------------------------------------------------------------------------

///|
/// 运行 `timedatectl show` 并捕获标准输出：退出码 0 → Ok(stdout)；
/// 127（shell 无此命令）→ LcUnsupported；其余错误按 ProcError 类型
/// 映射。
fn lc_timedatectl_show() -> Result[String, LocaleError] {
  match pr_run("timedatectl", ["show"], timeout_ms=4000) {
    Ok(o) => Ok(o.stdout)
    Err(NonZeroExit(127, _)) => Err(LcUnsupported)
    Err(NonZeroExit(code, err)) =>
      Err(
        LcCommandFailed(
          "timedatectl show: 退出码 \{code}（\{lc_first_line(err)}）",
        ),
      )
    Err(Timeout(m)) => Err(LcCommandFailed(m))
    Err(SpawnFailed(m)) => Err(LcCommandFailed(m))
    Err(Signaled(sig)) =>
      Err(LcCommandFailed("timedatectl: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(LcUnsupported)
  }
}

///|
/// 命令路径读时区：timedatectl show 的 Timezone 行。
fn lc_timezone_cmd() -> Result[String, LocaleError] {
  match lc_timedatectl_show() {
    Err(e) => Err(e)
    Ok(out) =>
      match lc_parse_timezone(out) {
        Some(tz) => Ok(tz)
        None => Err(LcParseFailed("timedatectl show: 无 Timezone 行"))
      }
  }
}

///|
/// 命令路径读 NTP：timedatectl show 的 NTP 行。
fn lc_ntp_cmd() -> Result[Bool, LocaleError] {
  match lc_timedatectl_show() {
    Err(e) => Err(e)
    Ok(out) =>
      match lc_parse_ntp(out) {
        Some(on) => Ok(on)
        None => Err(LcParseFailed("timedatectl show: 无 NTP 行"))
      }
  }
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 当前时区（IANA 标识，如 "Asia/Shanghai"）：优先 timedate1 的
/// Timezone 属性（系统总线）；总线调用失败（服务不在线 / 总线不可达 /
/// 应答超时）自动回退 `timedatectl show`；两条路都不可用 →
/// LcUnsupported。
pub fn lc_timezone() -> Result[String, LocaleError] {
  match platform() {
    "linux" =>
      match lc_dbus_string_prop("Timezone") {
        Ok(tz) => Ok(tz)
        Err(LcBusFailed(_)) => lc_timezone_cmd()
        Err(e) => Err(e)
      }
    _ => Err(LcUnsupported)
  }
}

///|
/// NTP 时间同步是否开启：优先 timedate1 的 NTP 属性；总线调用失败自动
/// 回退 `timedatectl show`；两条路都不可用 → LcUnsupported。
pub fn lc_ntp() -> Result[Bool, LocaleError] {
  match platform() {
    "linux" =>
      match lc_dbus_bool_prop("NTP") {
        Ok(on) => Ok(on)
        Err(LcBusFailed(_)) => lc_ntp_cmd()
        Err(e) => Err(e)
      }
    _ => Err(LcUnsupported)
  }
}

///|
/// 设置系统时区（IANA 标识，如 "Asia/Shanghai"）：写 timedate1 的
/// Timezone 属性（系统总线，需要认证，调用方自行走授权流程；有副作用，
/// 仅实现不执行）。标识非法先给 LcInvalidTimezone，不发起总线调用。
pub fn lc_set_timezone(tz : String) -> Result[Unit, LocaleError] {
  match platform() {
    "linux" => {
      if !lc_valid_timezone(tz) {
        return Err(LcInvalidTimezone(tz))
      }
      match
        @traybus.gdbus_set_property_system(
          lc_dest(),
          lc_path(),
          lc_iface(),
          "Timezone",
          @traybus.GVString(tz),
        ) {
        Ok(_) => Ok(())
        Err(e) => Err(lc_bus_err(e))
      }
    }
    _ => Err(LcUnsupported)
  }
}

///|
/// 当前本地语言（$LANG 环境变量，如 "zh_CN.UTF-8"；未设置或为空 →
/// LcUnsupported）。
pub fn lc_lang() -> Result[String, LocaleError] {
  match @env.get_env_var("LANG") {
    None => Err(LcUnsupported)
    Some(v) => {
      let t = lc_trim(v)
      if t == "" {
        Err(LcUnsupported)
      } else {
        Ok(t)
      }
    }
  }
}
