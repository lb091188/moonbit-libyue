# 构建与链接

链接参数**全权由 prebuild 托管**——使用者和贡献者都不手写链接参数。本文讲这套机制对你意味着什么，以及改原生桩后唯一的坑：不重链。原理与逐平台实测记录在 [adaptation.md](adaptation.md)「构建与链接」。

## 1. 链接从哪来

- moon 在构建时执行库模块的 `gui/scripts/prebuild.py`，它由 `gui/moon.mod` 的 `options(--moonbit-unstable-prebuild)` 挂上，按当前系统输出 `link_configs`，并自动传播给依赖本库模块的所有 main 包。
- prebuild 同时探测系统库：Linux 找 GTK3 / Pango / FontConfig / X11，内嵌 WebView 找 `webkit2gtk-4.1`，媒体模块找 ffmpeg。探不到 GTK 就非零退出并给修复提示；探不到 webkit 则 `@web` 退成占位实现、能力报 `Unsupported`，不让整包链接失败。
- 结果：`moon add NoahLiu/native-gui` 后 `moon run` 零配置，链接 flags 不用写也不该写。

## 2. 贡献者须知

- 库包不放 `link` 段——moon 会为库包生成无 `main` 的 `.exe`，构建失败。
- 不手写 `cc-link-flags`——链接一律由 prebuild 下发，手改会与它冲突。
- 新增平台 C 能力按「单一 `stub.c` 多分支 + prebuild 宏」组织，先例见 `gui/win/stub.c`；链接参数仍归 prebuild。

FFI 声明与蹦床对齐的规范见仓库根 [AGENTS.md](https://github.com/lb091188/moonbit-native-gui/blob/master/AGENTS.md) 与 `.agents/skills/moonbit-c-binding/`。

## 3. 唯一的坑：改了 C 桩不重链

moon 把 `.c` / `.cpp` native-stub 编进静态库，改桩代码不一定触发重链：`moon build` 可能报 `no work to do` 并继续用旧 exe，`moon test` 的测试二进制同理会链旧归档。两种情况的表现都是「代码改了行为没变」，旧崩溃可能还在。

**判别**：改过 `gui/<包>/*.c` 或 `.cpp`，但 `moon build` 说没活干、跑出来还是老样子。

**处理**，二选一：

```sh
moon clean                 # 全量重建，最省事
# 或只删对应产物（路径随构建布局与 target 变）：
rm -rf gui/_build/native/**/build/<包>/     # 该包重编
rm -rf _build/native/debug/build/examples/<示例>/<示例>   # 该示例重链
```

删完再 `moon build` / `moon test`，会重新编译桩并链新 exe。

排查时先用新的 main 目标复现一轮：新 target 每次都是新链接，若 main 正常而 test 崩，基本可断定 test 二进制链了旧归档，不是代码逻辑问题。更细的平台实测记在 [adaptation.md](adaptation.md)。

## 4. vendor 大文件与镜像

`WebView2.h`、`WebView2LoaderStatic.lib`、`miniaudio.h` 三个第三方文件不入库，入库会永久占用 git 历史体积，改由 prebuild 在缺失时下载，合计约 18.6 MB。

- **校验优先**：sha256 与两处 prebuild 的常量一致才落盘，任何镜像都可验证。
- **镜像按序尝试**：GitHub → Gitee，不做延迟探测，避免两台机器从不同源取到不同内容。
- **单源超时 20 秒**：国内直连 GitHub Release 资产可能长时间零字节，快速换源比干等有效。
- **换源与加源**：改 `gui/scripts/prebuild.py` 与 `modules/gui-media/prebuild.py` 的 `VENDOR_BASES` 各一行；两处刻意各留一份，`gui-media` 要能独立发布。
- **内网与离线**：环境变量 `NATIVE_GUI_VENDOR_BASE` 接受单个 base 或逗号分隔列表，排在最前；也可手工把文件放到对应路径，prebuild 只在缺失时下载，已存在不动。
- 全部失败时 prebuild 不中断，只提示手工放置，把缺文件错误留给链接期给出。

授权与来源见仓库根 [THIRD-PARTY-NOTICES.md](../../THIRD-PARTY-NOTICES.md)。

## 5. 相关

- 平台适配坑与验证：[adaptation.md](adaptation.md)
- 环境准备与第一个工程：[tutorial.md](tutorial.md)
- 组件与 API：[components.md](components.md)
