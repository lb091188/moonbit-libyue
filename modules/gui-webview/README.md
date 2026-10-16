# NoahLiu/gui-webview

[native-gui](https://mooncakes.io/docs/NoahLiu/native-gui) 的 WebView 扩展：把网页渲染放进窗口层的原生子件槽（pane），Linux 走 WebKitGTK，Windows 走 WebView2。

## 为什么是独立模块

WebView 要链外部重资产——Windows 侧 WebView2 SDK（vendor 头 + 静态 Loader，约 14 MB，构建时按 sha256 从 Release 资产取），Linux 侧 WebKitGTK 的 pkg-config 探测。而绝大多数 native-gui 应用（纯自绘路线）根本不需要引擎。放在**独立模块**（G9 Batch 1，2026-10-16 从主模块 `gui/web` 出成）让主模块的依赖闭包里不出现这些——只要不 `moon add NoahLiu/gui-webview`，连它的 prebuild 都不会跑。

## 包布局

本模块只有一个包：

| 包 | 内容 |
|---|---|
| `NoahLiu/gui-webview/webview` | `Webview` 全包组件与 `Node` 形态挂载、自定义协议注册（`register_protocol`）、JS 桥与 DOM 抓取、导航事件流水（`WebEvent` 族）；契约方法名沿用旧链 `yue/browser/browser.mbt` |

## 用法

```moonbit
import "NoahLiu/gui-webview/webview" @web

let wv = web::Webview::new(app, "https://example.com")?
```

引擎不在位（缺 WebKitGTK 开发包 / 缺 WebView2 Runtime）时 `webview_supported()` 返回 false、`webview_new` 给 None——由调用方摆自绘说明板，不静默降级。

## 链接与降级口径

- **Linux**：prebuild 探 `webkit2gtk-4.1`，带 `-DWB_HAVE_WEBKIT` 把 `webkit_stub.c` 编成静态库。真实现引用主模块 win 桩的 `wm_surface_container()`，链接行按「workspace 兄弟目录 → 依赖缓存 → 当前工作区 `_build`」三处定位 `libyue_win_stub.a`；定位不到或缺开发包时退回占位分支（探测返回不可用，不断链）。
- **Windows**：`webview2_stub.c` 由 moon native-stub 自编（MIT 的 Microsoft.Web.WebView2 SDK 头相对路径自取），prebuild 只下发静态 Loader 与系统库；缺资产时同样走占位降级。
- **macOS**：WKWebView 后端未接，符号在、探测返回不可用；随 W22 mac 批落地。

## 依赖

`NoahLiu/native-gui`（core/win/render/sys 门面）与 `NoahLiu/yoga-mbt`。「出模块」与「去 GUI 核心依赖」是两件事：入口签名换 `ShellApp` 等形态归主模块 Batch 2 定案后再动。
