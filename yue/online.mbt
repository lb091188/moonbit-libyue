// 网络在线状态。Linux 走 NetworkManager(系统总线,信号驱动);Windows
// 走 NLM 后台轮询线程(查询只在后台线程,UI 线程读缓存);macOS 暂缓。

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
/// 当前平台是否支持网络状态查询(macOS 暂缓;Linux 看 NM 是否在线)。
pub fn network_supported() -> Bool {
  match platform() {
    "linux" => @traybus.nm_available()
    "windows" => true
    _ => false
  }
}

///|
/// 查询当前在线状态。首次调用在 Linux 上同步建总线缓存,最坏阻塞
/// 1.5s(call_sync 超时上限);回调与定时器内请用缓存语义的
/// on_network_status_change,勿反复 status()。
pub fn network_status() -> Result[NetworkStatus, NetworkError] {
  match platform() {
    "linux" => {
      if !@traybus.nm_available() {
        return Err(Unsupported)
      }
      match @traybus.nm_state() {
        Err(e) => Err(QueryFailed(e))
        Ok(state) =>
          match @traybus.nm_connectivity() {
            Err(e) => Err(QueryFailed(e))
            Ok(conn) => Ok(nm_normalize(state, conn))
          }
      }
    }
    "windows" => {
      // 只读后台轮询缓存:GetConnectivity 在部分环境(代理/多虚拟网卡/
      // 网管服务迟滞)单次可达秒级,在 UI 线程同步查询会整段冻结主循环。
      // 首次调用先确保后台轮询已启动,轮询未就绪前返回查询失败。
      let _ = ffi_netwin_start(WIN_NET_POLL_MS)
      let mask = ffi_netwin_cached()
      if mask < 0 {
        return Err(QueryFailed("NLM 后台轮询尚未就绪"))
      }
      Ok(nlm_normalize(mask))
    }
    _ => Err(Unsupported)
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
/// UI 定时器读缓存派发,UI 线程零阻塞。
pub fn on_network_status_change(cb : (NetworkStatus) -> Unit) -> Unit {
  // 登记统一放分支外:派发统一走 net_dispatch 遍历 g_net_cbs,Linux
  // 分支曾因只在 Windows 分支登记漏掉 push,信号全到而回调永不执行
  g_net_cbs.push(cb)
  match platform() {
    "linux" => {
      let _ = @traybus.nm_on_change(fn(state, conn) {
        net_dispatch(nm_normalize(state, conn))
      })
      // 注册时同步回填初值(缓存语义)
      match network_status() {
        Ok(s) => g_net_last.val = Some(s)
        Err(_) => ()
      }
      ()
    }
    "windows" => {
      if !g_net_watched.val {
        g_net_watched.val = true
        // 初值不做同步回填:GetConnectivity 可能秒级阻塞,注册发生在
        // UI 线程。后台线程首查就绪后由下方轮询读缓存派发(g_net_last
        // 初值 Offline,实际 Online 时首轮即翻转派发;实际 Offline 与
        // 初值相同,静默不派发)
        let _ = ffi_netwin_start(WIN_NET_POLL_MS)
        set_timer(WIN_NET_POLL_MS, fn() {
          match network_status() {
            Ok(s) => net_dispatch(s)
            Err(_) => ()
          }
          true // 继续轮询
        })
        ()
      }
    }
    _ => ()
  }
}
