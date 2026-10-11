// 网络在线状态。Linux 走 NetworkManager(系统总线,信号驱动);Windows
// 走 NLM 后台轮询线程(查询只在后台线程,UI 线程读缓存);macOS 走 ping
// 单次探测(查询可用;变化事件无源,仍不支持)。

///|
/// 网络在线状态(两值)。
pub enum NetworkStatus {
  /// 可达互联网(已连网且连通性为完全/受限)
  Online
  /// 离线 / 门户劫持 / 未知
  Offline
}

///|
pub impl Show for NetworkStatus with fn output(self, logger) {
  match self {
    Online => logger.write_string("NetworkStatus::Online")
    Offline => logger.write_string("NetworkStatus::Offline")
  }
}

///|
pub extend NetworkStatus with Show::{to_string, output}

///|
/// 用户可读文案(UI 显示用;Show/to_string 是调试格式,wbtest 有断言)。
pub fn NetworkStatus::label(self : NetworkStatus) -> String {
  match self {
    Online => "在线"
    Offline => "离线"
  }
}

///|
/// NetworkManager 原始码归一:State 70/50(全球/站点级连接)且
/// Connectivity 4/3(完全/受限)算 Online;门户劫持(2)按 Offline——
/// 「在线」取「可达互联网」口径。
fn nm_normalize(state : Int, connectivity : Int) -> NetworkStatus {
  let connected = state == 70 || state == 50
  let internet = connectivity == 4 || connectivity == 3
  if connected && internet {
    Online
  } else {
    Offline
  }
}

///|
/// Windows NLM 位掩码归一:含 IPV4_INTERNET(0x40)或 IPV6_INTERNET
/// (0x400)算 Online;仅本地网 / 无流量 / 断开均 Offline。
fn nlm_normalize(mask : Int) -> NetworkStatus {
  if (mask & 0x40) != 0 || (mask & 0x400) != 0 {
    Online
  } else {
    Offline
  }
}

///|
/// 当前平台是否支持网络状态查询(Linux 看 NM 是否在线;Windows 恒可用;
/// macOS 靠 ping 探测——/sbin/ping 随系统自带,子进程执行可用即支持)。
pub fn network_supported() -> Bool {
  match @yue.platform() {
    "linux" => @traybus.nm_available()
    "windows" => true
    "macos" => net_supported_mac()
    _ => false
  }
}

///|
/// 查询当前在线状态。首次调用在 Linux 上同步建总线缓存,最坏阻塞
/// 1.5s(call_sync 超时上限);回调与定时器内请用缓存语义的
/// on_network_status_change,勿反复 status()。macOS 走一次 ICMP 探测,
/// 最坏阻塞约 2s(ping 的 -t 超时),勿在 UI 线程高频调用。
pub fn network_status() -> Result[NetworkStatus, @yue.NetworkError] {
  match @yue.platform() {
    "linux" => {
      if !@traybus.nm_available() {
        return Err(@yue.Unsupported)
      }
      match @traybus.nm_state() {
        Err(e) => Err(@yue.QueryFailed(e))
        Ok(state) =>
          match @traybus.nm_connectivity() {
            Err(e) => Err(@yue.QueryFailed(e))
            Ok(conn) => Ok(nm_normalize(state, conn))
          }
      }
    }
    "windows" => {
      // 只读后台轮询缓存:GetConnectivity 在部分环境(代理/多虚拟网卡/
      // 网管服务迟滞)单次可达秒级,在 UI 线程同步查询会整段冻结主循环。
      // 首次调用先确保后台轮询已启动,轮询未就绪前返回查询失败。
      let _ = @yue.ffi_netwin_start(WIN_NET_POLL_MS)
      let mask = @yue.ffi_netwin_cached()
      if mask < 0 {
        return Err(@yue.QueryFailed("NLM 后台轮询尚未就绪"))
      }
      Ok(nlm_normalize(mask))
    }
    "macos" => net_status_mac()
    _ => Err(@yue.Unsupported)
  }
}

///|
/// Windows 轮询周期(毫秒);监听式事件接入后置。
const WIN_NET_POLL_MS : Int = 5000

///|
let g_net_cbs : Array[(NetworkStatus) -> Unit] = []

///|
/// 最近一次派发过的状态;None = 尚未知(Windows 后台轮询首查前),
/// 未知态首个到达值必派发,后续同值去重。
let g_net_last : Ref[NetworkStatus?] = Ref(None)

///|
let g_net_watched : Ref[Bool] = Ref(false)

///|
fn same_status(a : NetworkStatus, b : NetworkStatus) -> Bool {
  match (a, b) {
    (Online, Online) => true
    (Offline, Offline) => true
    _ => false
  }
}

///|
fn net_dispatch(status : NetworkStatus) -> Unit {
  match g_net_last.val {
    Some(prev) if same_status(status, prev) => return // 去重:仅变化派发
    _ => ()
  }
  g_net_last.val = Some(status)
  for cb in g_net_cbs {
    cb(status)
  }
}

///|
/// 注册在线状态变化回调(可多次注册;不支持的平台静默忽略,先以
/// network_supported 判定)。Linux 信号驱动(NM StateChanged 与
/// PropertiesChanged,回调内只读缓存);Windows 后台轮询线程刷缓存,
/// UI 定时器读缓存派发,UI 线程零阻塞;macOS 无变化事件源(见下方分支
/// 注释)。
pub fn on_network_status_change(cb : (NetworkStatus) -> Unit) -> Unit {
  // 登记统一放分支外:派发统一走 net_dispatch 遍历 g_net_cbs,Linux
  // 分支曾因只在 Windows 分支登记漏掉 push,信号全到而回调永不执行
  g_net_cbs.push(cb)
  match @yue.platform() {
    "linux" => {
      let _ = @traybus.nm_on_change(fn(state, conn) {
        net_dispatch(nm_normalize(state, conn))
      })
      // 注册时同步回填初值:新订阅者立即拿到当前状态(否则文案停在
      // 「探测中」直到网络真的变化);g_net_last 同步设为去重基准,
      // 后续信号只派发变化。逐个 cb 回填而非走 net_dispatch——多注册
      // 时后者会被去重吞掉第二个订阅者的初值
      match network_status() {
        Ok(s) => {
          g_net_last.val = Some(s)
          cb(s)
        }
        Err(_) => ()
      }
      ()
    }
    "windows" =>
      if !g_net_watched.val {
        g_net_watched.val = true
        // 初值不做同步回填:GetConnectivity 可能秒级阻塞,注册发生在
        // UI 线程。后台线程首查就绪后由下方轮询读缓存派发(g_net_last
        // 初值 Offline,实际 Online 时首轮即翻转派发;实际 Offline 与
        // 初值相同,静默不派发)
        let _ = @yue.ffi_netwin_start(WIN_NET_POLL_MS)
        @yue.set_timer(WIN_NET_POLL_MS, fn() {
          match network_status() {
            Ok(s) => net_dispatch(s)
            Err(_) => ()
          }
          true // 继续轮询
        })
        ()
      }
    // macOS:无变化事件源,保持静默忽略。探测是阻塞式子进程(ping 最长
    // 2s),放 UI 定时器会整段冻结主循环——与 Windows 侧「GetConnectivity
    // 单次可达秒级,UI 线程同步查询会冻结主循环」同因,而 mac 侧没有
    // 后台轮询线程可先把结果缓存下来,故不做「定时器 + 阻塞探测」的替代
    // 实现;需要变化通知的调用方自行按合适周期在后台侧调 network_status
    // 并比对。
    "macos" => ()
    _ => ()
  }
}

// ---------------------------------------------------------------------------
// macOS 实现:ping 单次探测(`ping -c 1 -t <秒> <host>`)
//
// macOS 没有 NetworkManager,连通性只能靠 ICMP 探测:给公网任播地址发一
// 包,收到回复即 Online。BSD ping 的 `-t` 单位是「秒」(GNU ping 的 -W
// 在部分实现里也是秒,但另有 -w 截止秒语义,两平台参数表不共用,各自构
// 造)。退出码按 BSD ping 文档语义:0 = 收到回复、2 = 发出成功但零回复,
// 其余为错误;命令缺失(退出码 127)→ Unsupported。输出解析
// [net_parse_ping] 为纯函数,online_wbtest.mbt 白盒覆盖(无 macOS 真机
// 也能测)。
// ---------------------------------------------------------------------------

///|
/// macOS 连通性探测目标:公网 DNS 任播地址(直接给 IP,不经域名解析,避免
/// 把 DNS 解析失败误判成断网)。
const NET_MAC_PROBE_HOST : String = "8.8.8.8"

///|
/// macOS ping 的整体超时秒数(`-t`:到点未收到回复即退出;探测预算 4s 留
/// 有余量)。
const NET_MAC_PING_TIMEOUT_S : Int = 2

///|
/// macOS 路径支持性:ping 随系统自带(/sbin/ping),子进程执行可用即可探测。
fn net_supported_mac() -> Bool {
  pr_available()
}

///|
/// macOS 路径在线状态:ping 一次探测地址。退出码 0 再看输出里有没有回复行
/// (有 → Online);退出码 2(发出成功但零回复)→ Offline;其余非零退出 →
/// QueryFailed(带退出码与 stderr 首行);ping 缺失(127)→ Unsupported;
/// 启动失败 / 超时 / 被信号终止为对应 QueryFailed。
fn net_status_mac() -> Result[NetworkStatus, @yue.NetworkError] {
  if !pr_available() {
    return Err(@yue.Unsupported)
  }
  match pr_run("ping", net_mac_ping_args(NET_MAC_PROBE_HOST), timeout_ms=4000) {
    Ok(o) =>
      Ok(
        match net_parse_ping(o.stdout) {
          Some(true) => Online
          // 有汇总段但零回复 / 输出异常:一律按离线,不猜错误语义
          Some(false) => Offline
          None => Offline
        },
      )
    Err(NonZeroExit(127, _)) => Err(@yue.Unsupported)
    Err(NonZeroExit(2, _)) => Ok(Offline)
    Err(NonZeroExit(code, err)) =>
      Err(@yue.QueryFailed("ping: 退出码 \{code}（\{net_first_line(err)}）"))
    Err(Timeout(m)) => Err(@yue.QueryFailed(m))
    Err(SpawnFailed(m)) => Err(@yue.QueryFailed(m))
    Err(Signaled(sig)) => Err(@yue.QueryFailed("ping: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(@yue.Unsupported)
  }
}

///|
/// macOS ping 参数表:`-c 1` 只发一包、`-t <秒>` 整体超时(BSD ping 的 -t
/// 是秒;Linux 的 -W / -w 语义不同,故分平台构造,不并入公共参数表)。
fn net_mac_ping_args(host : String) -> Array[String] {
  ["-c", "1", "-t", NET_MAC_PING_TIMEOUT_S.to_string(), host]
}

///|
/// 解析 ping 输出是否收到回复:任一行含 "bytes from"(两平台回复行同形:
/// `64 bytes from 8.8.8.8: icmp_seq=0 ...`)即 Some(true);只有汇总段
/// (含 "transmitted")而无回复行即 Some(false);两者都没有(空输出 / 用法
/// 错误文本)为 None。纯函数,online_wbtest.mbt 白盒覆盖。
fn net_parse_ping(out : String) -> Bool? {
  let mut replied = false
  let mut summarized = false
  for line in net_split_lines(out) {
    if net_line_has(line, "bytes from") {
      replied = true
    }
    if net_line_has(line, "transmitted") {
      summarized = true
    }
  }
  if replied {
    Some(true)
  } else if summarized {
    Some(false)
  } else {
    None
  }
}

///|
/// 按换行切分文本(丢弃行尾回车,空行不保留)。
fn net_split_lines(s : String) -> Array[String] {
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
/// 行内是否含子串(朴素逐位比对,不依赖 String::contains 的语义)。
fn net_line_has(line : String, key : String) -> Bool {
  let n = line.length()
  let m = key.length()
  if m == 0 || n < m {
    return false
  }
  let mut i = 0
  let mut found = false
  while !found && i + m <= n {
    let mut k = 0
    while k < m && line.unsafe_get(i + k) == key.unsafe_get(k) {
      k = k + 1
    }
    if k == m {
      found = true
    }
    i = i + 1
  }
  found
}

///|
/// stderr 诊断文本压成单行并截断(错误消息只取首行前 120 字符,避免刷屏)。
fn net_first_line(s : String) -> String {
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
