# Linux 托盘方案

托盘是 moonbit-libyue 平台差异最大的一块:Linux 没有可直接依赖的托盘运行库,
本项目为此用纯 MoonBit 实现了 StatusNotifierItem(SNI)协议栈,会话总线直连
面板,不依赖任何 AppIndicator 运行库。本文讲清方案的设计动机、架构分层、
后端降级与桌面兼容性;API 用法速查见 [docs/components.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/components.md) 的
「菜单 / 托盘」一节,真实桌面实测出的坑与验证结论统一记录在
[docs/adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/adaptation.md)。

## 背景与约束

- Ubuntu 24.04 已移除传统 `libappindicator3` 运行库;ayatana 分支装了也不被
  libyue 认可,其探测列表只认 `libappindicator3`。
- libyue 内置托盘在运行库加载失败时**只打日志、对象静默失效**,消费方拿不到
  任何错误——这正是本方案要消灭的行为。
- 设计底线:后端缺失必须给出**结构化结果**(`Err(Unsupported)` /
  `is_supported() == false`),绝不静默失效。

## 方案总览

```
Tray 统一 API（yue/tray.mbt）              消费方零平台代码
  │ 后端选择与降级
  ├─ Sni（@traybus.Item）                  watcher 在线（Linux 主路径）
  │   └─ yue/traybus/  纯 MoonBit 协议栈
  │     ├─ wire.mbt    DBus 线路格式编解码（小端；对齐零点随作用域）
  │     ├─ bus.mbt     会话总线：地址解析、SASL EXTERNAL 握手、Hello、
  │     │              消息收发分发（glib fd 监视接入 GTK 主循环）
  │     ├─ sni.mbt     SNI 属性/信号/Activate 分发 + DBusMenu 菜单
  │     ├─ detect.mbt  桌面环境识别（XDG_CURRENT_DESKTOP，仅辅助诊断）
  │     ├─ icon.mbt    程序内置生成托盘位图（32×32 月牙，ARGB 大端序）
  │     └─ sys.mbt     fd 级系统调用面（8 个，全部经 shim 转发）
  └─ Native（NativeTray）                  回退：libyue 原生 AppIndicator
```

shim 只转发 8 个 fd 级系统调用:unix connect / read / write / poll / close /
watch_fd / getuid / getenv,非 Linux 平台为失败桩,traybus 据此优雅降级,
绝不触碰真实系统调用。除这 8 个入口外,托盘全链路(编解码、握手、协议状态机、
菜单模型)都在 MoonBit 层完成。

### 主循环接入

单进程一条会话总线连接,全部运行在主线程。`sys_watch_fd` 经 shim 挂到 glib
fd 监视源接入 GTK 主循环,DBus 消息到达后按接口与方法名分发到 SNI /
DBusMenu 处理器;应答经串号(pending map)回配。

## 后端选择与降级

`Tray::new` 按以下优先级选后端:

1. **SNI watcher 在线 → 纯 MoonBit 托盘**。能连上会话总线只算候选,watcher
   是否存在以注册时的 `NameHasOwner(org.kde.StatusNotifierWatcher)` 为准;
   注册成功即用 `@traybus.Item`。失败(watcher 不在线等)继续向下回退。
2. **watcher 不在线 → 回退 nativeui AppIndicator**(libyue 原生托盘;shim
   侧已加空指针防御,探测失败不崩)。此路径仅作回退。
3. **两者皆无 → `Err(Unsupported)`**。`Tray::is_supported()` 同口径,消费方
   可据此决定是否展示托盘相关功能。

`desktop_environment()` 返回识别出的桌面环境名(XFCE / GNOME / KDE…,识别不出
为 "unknown"),仅作诊断与降级提示;运行时真伪始终以 watcher 是否在线为准,
环境名不参与后端选择。

## 统一 API 与平台差异

消费方 API 三大平台完全一致:`Tray::new / is_supported / set_title / set_icon /
set_icon_name / set_tooltip / on_click / set_menu / remove`。平台差异在库内
消化,对外的可见表现:

| 方法 | Linux SNI 后端 | Windows / macOS 原生后端 |
| --- | --- | --- |
| `set_title` | 支持(部分面板不渲染,属面板表现) | 同左,部分面板不渲染 |
| `set_icon` | 空操作(PNG 像素解码未内置,保持现有图标) | 支持 |
| `set_icon_name` | 支持,跟随系统主题(如 "utilities-terminal") | 空操作 |
| `set_tooltip` | 支持 | 空操作 |
| `on_click` | 面板 Activate 信号 | 图标点击 |
| `set_menu` | 构建 DBusMenu + ContextMenu 自绘回退 | 原生 SetMenu |

Linux 图标说明:`Tray::new` 传入的图片路径只用于取文件名作托盘 Id,位图由
`icon.mbt` 程序内置生成(外圆与偏移挖空圆构成月牙,2×2 超采样抗锯齿,输出
SNI 规范要求的 ARGB 大端序),不依赖任何图片资源与解码器;要跟随系统主题
换图标用 `set_icon_name`。

## 菜单:set_menu 的两条通路

不同面板消费托盘菜单的方式不同,SNI 后端同时备好两条通路:

- **面板镜像 DBusMenu 渲染**(XFCE 4.18 实测走这条):`set_menu` 遍历统一
  `Menu` 模型的一级项与分隔线构建 DBusMenu(id = 数组下标 + 1,0 为根),
  点击菜单项经 `MenuItem::Click` 触发原回调;子菜单暂不支持。DBusMenu 的
  `AboutToShow` 恒回 false——回 true 会让面板把左键当菜单键、不再发
  Activate(ksni 同款语义)。
- **ContextMenu(x, y) → 应用自绘**(Qt 模式):面板调 `ContextMenu` 带图标
  屏幕坐标,应用用 `Menu::popup_at(x, y)` 在该点弹出自己的菜单,回调经
  `set_context_menu_handler` 注册。

XFCE 的 libdbusmenu 客户端只发批量版 `EventGroup` / `AboutToShowGroup`,
单条版会被 UnknownMethod 静默拒掉——traybus 单条、批量两组方法都有实现。
抓包定位过程见 [docs/adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/adaptation.md)。

## 桌面环境兼容性

| 桌面环境 | 状态 | 说明 |
| --- | --- | --- |
| XFCE 4.18 | ✅ 实测 | 图标、Activate 点击、右键菜单贯通 |
| KDE / MATE / Cinnamon / Budgie / LXQt | ❓ 待实测 | 协议层原生支持 SNI,预期可用 |
| GNOME + AppIndicator 扩展 | ❓ 待实测 | 协议层可用,待真机验证 |
| 纯净 GNOME | ❌ | 无托盘协议,`Err(Unsupported)` 属预期行为 |
| Windows 10 / 11 | ✅ 实测 | 原生 `Shell_NotifyIconW` 后端 |
| macOS | ❓ 未实测 | 原生后端 |

状态标记与 [docs/adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/adaptation.md) 一致:
✅ 实测通过 / ⚠️ 部分可用或带条件 / ❌ 不可用 / ❓ 未实测。
逐一真机实测后,把版本号与差异按维护约定回写 adaptation.md 并更新本表。

## 调试与验证

- 协议互操作问题首选 `dbus-monitor` 抓**真实会话总线**:判据与案例
  (批量版信号、通知 `Notify` 未发出等)见 adaptation.md 的
  「DBus 线路协议坑」「桌面环境」两节。
- 单测只证编解码自洽(对齐、签名、长度前缀等线路层规则有独立测试),
  **互操作结论必须来自真总线、真面板**——这是仓库级验证规则,不是本模块
  的可选要求。
