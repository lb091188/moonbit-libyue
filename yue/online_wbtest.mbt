// 网络状态归一化纯函数与 NM "v"(u) 应答解析测试。

///|
test "NM State × Connectivity 归一化矩阵" {
  // 完全连通
  inspect(nm_normalize(70, 4) is Online, content="true")
  inspect(nm_normalize(50, 4) is Online, content="true")
  inspect(nm_normalize(70, 3) is Online, content="true")
  // 门户劫持(2)/无连通(1)/未知(0)按 Offline
  inspect(nm_normalize(70, 2) is Offline, content="true")
  inspect(nm_normalize(70, 1) is Offline, content="true")
  inspect(nm_normalize(70, 0) is Offline, content="true")
  // 未连接态(State 20/0)无论连通性如何都 Offline
  inspect(nm_normalize(20, 4) is Offline, content="true")
  inspect(nm_normalize(20, 2) is Offline, content="true")
  inspect(nm_normalize(0, 4) is Offline, content="true")
  inspect(nm_normalize(0, 0) is Offline, content="true")
}

///|
test "NLM 位掩码归一化" {
  // 仅本地网(0x20|0x4)/IPv6 无流量(0x2)/断开(0x0)→ Offline
  inspect(nlm_normalize(0x24) is Offline, content="true")
  inspect(nlm_normalize(0x02) is Offline, content="true")
  inspect(nlm_normalize(0x00) is Offline, content="true")
  // 含互联网位 → Online
  inspect(nlm_normalize(0x40) is Online, content="true")
  inspect(nlm_normalize(0x400) is Online, content="true")
  inspect(nlm_normalize(0x440) is Online, content="true")
  inspect(nlm_normalize(0x62) is Online, content="true")
}

///|
test "net_dispatch 去重与派发:初值未知首个必派发,后续仅变化派发" {
  // 全局态测试,末尾复位防跨测试污染
  let seen : Array[String] = []
  g_net_cbs.push(fn(s) { seen.push(s.to_string()) })
  net_dispatch(Online) // 初值未知(None) → 必派发
  net_dispatch(Online) // 相同 → 去重
  net_dispatch(Offline)
  inspect(seen.join(" "), content="NetworkStatus::Online NetworkStatus::Offline")
  inspect(g_net_last.val is Some(_), content="true")
  g_net_cbs.clear()
  g_net_last.val = None
}
