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
  inspect(
    seen.join(" "),
    content="NetworkStatus::Online NetworkStatus::Offline",
  )
  inspect(g_net_last.val is Some(_), content="true")
  g_net_cbs.clear()
  g_net_last.val = None
}

///|
/// macOS 路径的 ping 参数表（纯函数白盒，无 macOS 真机也能测）：BSD ping
/// 的 -c 是发包数、-t 是「秒」级超时，与 Linux 的 -W / -w 不同故独立构造。
test "net_mac_ping_args:BSD ping 参数形态" {
  assert_eq(net_mac_ping_args("8.8.8.8"), ["-c", "1", "-t", "2", "8.8.8.8"])
  assert_eq(net_mac_ping_args("1.1.1.1"), ["-c", "1", "-t", "2", "1.1.1.1"])
  assert_eq(NET_MAC_PROBE_HOST, "8.8.8.8") // 探测目标给 IP,不经域名解析
}

///|
/// macOS 路径的 ping 输出解析（真实形态样本）：有回复行即在线，只有汇总段
/// 即离线，两头都没有为 None。
test "net_parse_ping:回复行/汇总段/异常输出" {
  // macOS ping 成功样本
  let online = "PING 8.8.8.8 (8.8.8.8): 56 data bytes\n64 bytes from 8.8.8.8: icmp_seq=0 ttl=117 time=12.345 ms\n\n--- 8.8.8.8 ping statistics ---\n1 packets transmitted, 1 packets received, 0.0% packet loss\nround-trip min/avg/max/stddev = 12.345/12.345/12.345/0.000 ms\n"
  assert_eq(net_parse_ping(online), Some(true))
  // 零回复：有汇总段但无回复行
  let lost = "PING 8.8.8.8 (8.8.8.8): 56 data bytes\n\n--- 8.8.8.8 ping statistics ---\n1 packets transmitted, 0 packets received, 100.0% packet loss\n"
  assert_eq(net_parse_ping(lost), Some(false))
  // 只有一包回复、没有汇总段（进程被提前终止的形态）
  assert_eq(
    net_parse_ping("64 bytes from 8.8.8.8: icmp_seq=0 ttl=56 time=3.1 ms\r\n"),
    Some(true),
  )
  // 异常输出：无回复也无汇总（空输出 / 用法错误文本）
  assert_eq(net_parse_ping(""), None)
  assert_eq(net_parse_ping("ping: cannot resolve x: Unknown host\n"), None)
  assert_eq(net_parse_ping("usage: ping [-c count] host\n"), None)
}

///|
/// 行内子串判定与按行切分（[net_parse_ping] 的两个底层纯函数）。
test "net_line_has/net_split_lines:子串与行切分" {
  assert_true(net_line_has("64 bytes from 8.8.8.8", "bytes from"))
  assert_eq(net_line_has("1 packets transmitted", "bytes from"), false)
  assert_true(net_line_has("1 packets transmitted", "transmitted"))
  // 行尾/行首命中与短行不越界
  assert_true(net_line_has("bytes from", "bytes from"))
  assert_true(net_line_has("xbytes from", "bytes from"))
  assert_eq(net_line_has("byte", "bytes from"), false)
  assert_eq(net_line_has("", "bytes from"), false)
  assert_eq(net_line_has("abc", ""), false)
  // 切分：空行不保留、行尾回车丢弃
  assert_eq(net_split_lines("a\nb\n").length(), 2)
  assert_eq(net_split_lines("a\r\nb\r\n").length(), 2)
  assert_eq(net_split_lines("\n\n").length(), 0)
  assert_eq(net_split_lines("").length(), 0)
  assert_eq(net_split_lines("a\nb")[1], "b") // 末行无换行同样收录
}
