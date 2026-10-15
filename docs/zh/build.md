# 构建与链接

本库的链接参数**全权由 prebuild 托管**——普通使用者和贡献者都不手写链接参数。本文讲这套机制对你意味着什么，以及改原生桩后唯一的坑：不重链。原理与逐平台实测记录在 [adaptation.md](adaptation.md)「构建与链接」。

## 1. 链接从哪来（不用你管）

- **构建时**：moon 执行库模块的 `gui/scripts/prebuild.py`（在 `gui/moon.mod` 的 `options(--moonbit-unstable-prebuild)` 里挂上），它按**当前系统**输出 `link_configs`，并自动传播给依赖本库模块的所有 main 包。
- **探测与降级**：prebuild 探测系统库——Linux 找 GTK3 / Pango / FontConfig / X11，内嵌 WebView 找 `webkit2gtk-4.1`，媒体模块找 ffmpeg。探不到 GTK 就非零退出并给修复提示；探不到 webkit 则 `@web` 退成占位实现（能力报 `Unsupported`），不让整包链接失败。
- **你看到的**：`moon add NoahLiu/native-gui` 后 `moon run` 零配置——链接 flags 不用写、不该写。

## 2. 贡献者：任何 moon.pkg 都不写链接参数

- **库包不放 `link` 段**——moon 会为库包生成无 `main` 的 `.exe` 导致构建失败。
- **不手写 `cc-link-flags`**——链接一律由 prebuild 下发；手改会和它打架。
- **新增平台 C 能力**按「单一 `stub.c` 多分支 + prebuild 宏」组织（先例 `gui/win/stub.c`），链接参数仍归 prebuild。

（FFI 声明与蹦床对齐的规范见仓库根 [AGENTS.md](https://github.com/lb091188/moonbit-native-gui/blob/master/AGENTS.md) 与 `.agents/skills/moonbit-c-binding/`。）

## 3. 唯一的坑：改了 C 桩不重链

moon 把 `.c` / `.cpp` native-stub 编进静态库后，改桩代码**不一定触发重链**：`moon build` 可能报 `no work to do` 并继续用旧 exe；`moon test` 的测试二进制同理，会链接旧归档（改前改后症状都是「代码改了行为没变」，甚至旧崩溃还在）。

**判别**：改过 `gui/<包>/*.c` 或 `.cpp`，但 `moon build` 说没活干、跑出来还是老样子——即命中。

**处理**（二选一）：

```sh
moon clean                 # 全量重建，最省事
# 或只删对应产物（路径随构建布局与 target 变）：
rm -rf gui/_build/native/**/build/<包>/     # 该包重编
rm -rf _build/native/debug/build/examples/<示例>/<示例>   # 该示例重链
```

删完再 `moon build` / `moon test`，会重新编译桩并链新 exe。

**为什么值得先「改 main 目标复现一轮」**：新 target 每次都是新链接——若「main 正常、test 崩」，基本可断定是 test 二进制链了旧归档，不是代码逻辑问题。这条与更细的平台实测（GTK/Win32/macOS 各自踩过）都记在 [adaptation.md](adaptation.md)。

## 4. 相关

- 平台适配坑与验证：[adaptation.md](adaptation.md)
- 教程（环境准备与第一个工程）：[tutorial.md](tutorial.md)
- 组件与 API：[components.md](components.md)
