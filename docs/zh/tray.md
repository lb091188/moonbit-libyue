# Linux 托盘方案

托盘是 moonbit-libyue 平台差异最大的一块：Linux 没有可直接依赖的托盘运行库，本项目为此用纯 MoonBit 实现了 StatusNotifierItem（SNI）协议栈（`dbus/sni.mbt`），会话总线直连面板，不依赖任何 AppIndicator 运行库。本文讲清方案的设计、后端选择、菜单处理与桌面兼容性；真实桌面实测出的坑与验证结论统一记录在 [docs/adaptation.md](adaptation.md)。

## 背景与约束

- Ubuntu 24.04 已移除传统 `libappindicator3` 运行库。本方案一个都不依赖：托盘走 SNI 直连会话总线，根本不需要 AppIndicator 运行库——GNOME 装 AppIndicator 扩展后 SNI 即可用。
- 设计底线：后端缺失必须给出**结构化结果**（`Err(TrayError::Unsupported)` / `is_supported() == false`），绝不静默失效。

## 方案总览

```
Tray 统一 API（core/tray.mbt）             消费方零平台代码
  │ 后端选择
  ├─ SNI（@dbus.Item）                     watcher 在线（Linux 主路径）
  │   └─ dbus/  纯 MoonBit 协议栈
  │     ├─ wire.mbt    DBus 线路格式编解码（小端；对齐零点随作用域）
  │     ├─ bus.mbt     会话总线：地址解析、SASL EXTERNAL 握手、Hello、消息收发分发
  │     ├─ sni.mbt     SNI 属性/信号/Activate 分发 + DBusMenu 菜单
  │     ├─ icon.mbt    程序内置生成托盘位图（32×32 月牙，ARGB 大端序）
  │     └─ …           图标、通知、logind/upower、媒体、网络等
  └─ Win32（win/tray.mbt + stub.c 的 Shell_NotifyIconW）   Windows 原生托盘
```

单进程一条会话总线连接，全部运行在主线程。

## 后端选择

1. **SNI watcher 在线 → 纯 MoonBit 托盘**。能连上会话总线只算候选，watcher 是否存在以注册时的 `NameHasOwner(org.kde.StatusNotifierWatcher)`（`sni_watcher_present()`）为准，比只看连得上总线的 `sni_available()` 强。
2. **否则 → Win32 原生托盘**（`@win.tray_supported()`）。
3. **两者皆无 → `Err(TrayError::Unsupported)`**，结构化结果，消费方可据此决定是否展示托盘相关功能。**Linux 端不再回退 AppIndicator。**

## 统一 API 与平台差异

消费方 API 各平台完全一致：`Tray::new / is_supported / set_title / set_icon / set_icon_name / set_tooltip / on_click / set_menu / remove`。平台差异在库内消化，对外的可见表现：

| 方法 | Linux SNI 后端 | Windows 原生后端 |
| --- | --- | --- |
| `set_title` | 支持（部分面板不渲染，属面板表现） | 同左 |
| `set_icon` | 空操作（任意 PNG 像素解码未内置，保持现有图标） | 支持（`.ico` 原生 / PNG 走 WIC / 像素直建） |
| `set_icon_name` | 支持，跟随面板主题（如 "utilities-terminal"） | 空操作 |
| `set_tooltip` | 支持 | 支持 |
| `on_click` | 面板 Activate 信号 | 图标点击 |
| `set_menu` | 构建 DBusMenu（平铺一级） | 原生 `TrackPopupMenuEx` |

Linux 图标说明：位图由 `dbus/icon.mbt` 程序内置生成（外圆与偏移挖空圆构成月牙，2×2 超采样抗锯齿，输出 SNI 规范要求的 ARGB 大端序），不依赖任何图片资源与解码器；要跟随系统主题换图标用 `set_icon_name`。

## 回调与菜单

- **回调**：Win32 侧左键/右键经进程级队列，宿主每拍调 `dispatch_tray_event()` 抽（Win32 上右键无回调时**自动弹已挂的菜单**）；SNI 侧由 DBus 信号直达回调，不经队列。
- **菜单**：`Tray::set_menu(Menu)` 复用 `core/menu.mbt` 的同一套模型——Win32 走 `TrackPopupMenuEx` + `TPM_RETURNCMD`（选中项回到同一条菜单派发链）；SNI 走 DBusMenu，**本实现是平铺一级菜单，子菜单被展平**（前置一条分隔线）。

## 桌面环境兼容性

| 桌面环境 | 状态 | 说明 |
| --- | --- | --- |
| XFCE 4.18 | ✅ 实测 | 图标、Activate 点击、右键菜单贯通 |
| KDE / MATE / Cinnamon / Budgie / LXQt | ❓ 待实测 | 协议层原生支持 SNI，预期可用 |
| GNOME + AppIndicator 扩展 | ❓ 待实测 | 协议层可用，待真机验证 |
| 纯净 GNOME | ❌ | 无托盘协议，`Err(Unsupported)` 属预期行为 |
| Windows 10 / 11 | ✅ 实测 | 原生 `Shell_NotifyIconW` 后端 |
| macOS | 🚧 后端暂未开发 | |

状态标记与 [docs/adaptation.md](adaptation.md) 一致：✅ 实测通过 / ⚠️ 部分可用或带条件 / ❌ 不可用 / ❓ 未实测。

## 调试与验证

- 协议互操作问题首选 `dbus-monitor` 抓**真实会话总线**（批量版信号等）：判据与案例见 adaptation.md 的「DBus 线路协议坑」「桌面环境」两节。
- 单测只证编解码自洽（对齐、签名、长度前缀等线路层规则有独立测试），**互操作结论必须来自真总线、真面板**——这是仓库级验证规则，不是本模块的可选要求。
- 后端由纯 C 探针 `experiment/tray_probe`（末行 `TRAY-BACKEND-OK`）回证；门面由 `core/tray_wbtest.mbt` 的纯函数 + 生命周期用例（无托盘后端的机器自动跳过而非造假）回证。**真面板观感（图标是否显示、菜单弹出位置、左键行为）仍归人工测试清单。**

[English](/tray)
