# 第三方授权与来源

本仓库自身是 **MIT**（见 [`LICENSE`](LICENSE)）。本文件登记**随我们分发的第三方资产**——判据只有一条：随源码或随预构建二进制出去的才需要随附授权文本；用户从发行版装的动态库不在其列，只记来源与许可性质。

| 资产 | 许可 | 在我们这里的形态 | 授权文本 |
|---|---|---|---|
| FFmpeg（Windows 开发包） | LGPL-3 | `modules/ffmpeg-mbt/vendor/`：5 个导入库 `.lib` + 头文件，**入库存档**；取自 BtbN/FFmpeg-Builds 的 win64 **lgpl-shared** 构建，版本串 `n9.0.2-27-g7e93014c5b-20261012` | ✅ `modules/ffmpeg-mbt/vendor/FFMPEG-LICENSE.txt` |
| FFmpeg（Linux / macOS 运行期） | LGPL-3 | **不随我们分发**——动态链系统包，构建期 pkg-config 探测 | 由发行版附带 |
| WebView2 SDK（Microsoft） | MIT | `modules/gui-webview/webview/include/WebView2.h` + `modules/gui-webview/webview/lib/WebView2LoaderStatic.lib`，**不入库**，构建时从 Release 资产 `vendor-v1` 下载并校验 sha256；NuGet 包 `Microsoft.Web.WebView2` 1.0.4258.31 | ✅ `modules/gui-webview/webview/include/SDK-LICENSE.txt`（入库） |
| miniaudio（mackron） | 公有领域（Unlicense / CC0）与 MIT 双许可 | `modules/gui-media/media/miniaudio.h`，**不入库**，构建时下载并校验 sha256 | 文件头即授权声明；此处登记 |
| `moonbitlang/x`、`moonbitlang/async` | Apache-2.0 | mooncakes 依赖（`moon install` 拉取，不入库） | 各自包内 `LICENSE` |
| `mizchi/markdown`、`mizchi/syntree` | MIT | 同上 | 包内 `LICENSE` |
| `mizchi/zlib` | Apache-2.0 | 同上 | 包内 `LICENSE` |
| `prowk/moonsqlitefile` | Apache-2.0 | 同上 | 包内 `LICENSE` |
| MoonBit 工具链与 `moonbitlang/core` | Apache-2.0 | 由 `~/.moon` 工具链分发，不入库 | 工具链自带 |
| GTK3 / Cairo / Pango / GdkPixbuf / WebKitGTK | LGPL-2.1 / LGPL-3（各自） | **不随我们分发**，发行版提供；构建期 pkg-config 探测，缺包即语义化降级 | 由发行版附带 |
| Yoga（Facebook） | MIT | **不使用其代码**：`modules/yoga-mbt` 按 W3C CSS Flexbox Layout Level 1 规范自写实现，只对齐规范与行为，不保留 Yoga 的双默认值 | 不适用（出处口径见该模块 README） |

## 对外发预构建二进制时的义务清单

上表里标「mooncakes 依赖」的行，在只发源码（mooncakes）时由包管理器负责；**一旦我们发编译好的二进制**（GitHub / Gitee Release），它们变成「我们的产物包含第三方代码」，需要：

1. 把各依赖的 `LICENSE` 原文收进发布包的 `licenses/` 目录——直接从 `.mooncakes/<作者>/<包>/LICENSE` 拷贝即可，别手抄；
2. 本文件随包一起发；
3. LGPL 线（FFmpeg、GTK 族）保持**动态链**并给出替换路径：Windows 侧 dll 放 exe 同目录或加进 `PATH`（口径见 [`modules/gui-examples/README.md`](modules/gui-examples/README.md) 的「Windows 运行前置」节），这已满足 LGPL 的「用户可换库」要求；
4. 静态入库的 Windows 导入库（`*.lib`）本身不含 FFmpeg 代码，只是链接期符号表——但**运行期 dll 必须与同一份 LGPL 构建配套**，发布说明里要写清版本串。

## vendor 大文件的取用与镜像

三个不入库的文件（WebView2 两件套 + `miniaudio.h`，合计约 10 MB）由 prebuild 在**缺失时**下载，**sha256 校验通过才落盘**；已存在不动，离线环境可手工放置。

- 镜像**按序尝试**（GitHub → Gitee），不做延迟探测：sha256 使得任何镜像都可验证，顺序只影响快慢；先测快慢会让两台机器从不同源取，丢掉可复现性。
- 单源超时 20 秒（不是 180）——实测国内直连 GitHub Release 资产可出现「15 秒 0 字节」，快速切下一个源比干等一个源有用。
- 加镜像 = 在 `VENDOR_BASES` 加一行；外部源（内网 / 离线目录）用环境变量 `NATIVE_GUI_VENDOR_BASE` 覆盖，接受单个 base 或逗号分隔列表，排在列表最前。
- 两处下载逻辑刻意各留一份（`gui/scripts/prebuild.py` 与 `modules/gui-media/prebuild.py`）：`gui-media` 要能独立发布，不能反向依赖主模块的 `scripts/`。
- 全失败时 prebuild **不中断**，只打印手工放置的提示，让链接期给出明确的缺文件错误。
