# G0 输入法探针（`experiment/ime_probe`）

MoonBit 原生 GUI 栈的第一个 spike：在真实 Linux 桌面上验证**两种输入法接入形态**哪种可用，为 `docs/zh/native-gui-plan.md` 第 3 节的后端表与 G5 提供实测依据。不经 libyue，只依赖系统 GTK3 / Cairo / Pango。

- **模式 B（默认，纯通道）**：`GtkIMContext` 只当输入法客户端——按键先问它要不要（`gtk_im_context_filter_keypress`），不要才转给 MoonBit；组合串（preedit）、提交文本（commit）、插入符矩形由 MoonBit 侧的文本状态驱动，文字全部自绘。**文本状态只有一份**。
- **模式 C（可见覆盖）**：放一个真的 `GtkEntry` 在 240×22 的盒子里并下发 CSS 主题，验两件事——原生外观能被 CSS 压到什么程度、控件自身请求高度与外层给的尺寸会不会冲突。

## 前置与跑法

依赖 `libgtk-3-dev`（`pkg-config --cflags gtk+-3.0` 能出结果即可）。缺它时 `scripts/prebuild.py` 会在 stderr 提示并跳过本包的库编译。

```sh
# 模式 B（自绘 + GtkIMContext）
~/.moon/bin/moon run experiment/ime_probe

# 模式 C（可见 GtkEntry + CSS）
~/.moon/bin/moon run experiment/ime_probe -- c

# 冒烟：1.5 秒后自动退出，无输入也可验证进程存活与干净退出
~/.moon/bin/moon run experiment/ime_probe -- --smoke
~/.moon/bin/moon run experiment/ime_probe -- c --smoke

# 换输入法客户端（其余环境照旧）
GTK_IM_MODULE=ibus ~/.moon/bin/moon run experiment/ime_probe
```

改过 `ime_probe_stub.c` 后**必须删产物强制重链**（`moon` 不感知 `-l` 静态库变化）：

```sh
rm -f build/libime_probe_stub.a _build/native/debug/build/NoahLiu/moonbit-libyue/experiment/ime_probe/ime_probe.exe
```

窗口里蓝色描边框 = 探针给输入区定的 240×22 盒子；绿色状态行实时显示 `commit / preedit / 输入法消费与放行 / 转给 MoonBit 的按键 / 文本字节数`；`Esc` 退出并在终端打印汇总（含事件流水最近 40 条）。

## 真机验收清单

按仓库纪律，视觉与交互项由执行人在真机跑并回反馈；结果回填 `docs/zh/adaptation.md`「MoonBit 原生 GUI 栈(G0 输入法探针)」小节与规划文档第 3 节。**模式 B 与模式 C 各跑一遍，`GTK_IM_MODULE=fcitx` 与 `GTK_IM_MODULE=ibus` 各跑一遍**（fcitx5 与 ibus 的守护进程需在运行）。

| # | 操作 | 期望（模式 B） | 要记录 |
|---|---|---|---|
| 1 | 打拼音 `zhongguo` 后按空格选词 | 组合串内联出现在插入符处并带下划线，选词后提交汉字进入文本 | 是否出现 preedit；候选窗是否贴在插入符上方而不是屏幕角落 |
| 2 | 组合中连续快速敲键、按退格 | 组合串跟着变、无丢字无重复；退格删的是组合串不是已提交文本 | `commit` 与 `MoonBit 收到` 次数是否相等 |
| 3 | 只打英文/数字 | 走「输入法未消费」通道直接进文本 | 状态行 `filter_used / filter_pass` 分配是否合理 |
| 4 | 按方向键 / Home / End | 光标在自绘文本内移动，插入符矩形跟着推给输入法 | 汇总里 `转给 MoonBit 的按键` 是否随之增加 |
| 5 | 组合中途点别处 / 切窗口 | 组合串被丢弃而不是残留或双份提交 | 是否出现残留 preedit |
| 6 | 中文标点、全角/半角切换、emoji 候选 | 提交文本按字节正确入列（探针按 UTF-8 字节管光标） | 有没有把多字节字符切碎 |
| 7 | `Esc` 关闭 | 进程立即退出并打印汇总，无段错误 | 退出码；`preedit-end` 是否触发 |
| 8 | 模式 C 下观察同一个盒子 | 控件是否超出给定的 22px；CSS 下发后颜色/边框/插入符/字号是否已贴合主题 | 汇总末行 `GtkEntry 请求高 22 → 实际分配高 N`（本机实测：无 CSS 33，加 `min-height: 0px` 后 24） |
| 9 | 模式 C 下打中文 | 原生控件自带输入法可用（对照基准），但文字由控件自己显示 | 与模式 B 的可用性差距，作为「兜底方案」的成本参照 |

## 说明

- 非 Linux 平台下本探针链接的是空实现（`ime_probe_stub_portable.c`，仅为让 CI 的三平台 `moon build --target native` 不断符号），运行会直接报告"本平台无探针"。
- GTK 端不由 `moon.pkg` 的 `native-stub` 编译：moon 的 `link_configs` 没有编译期字段，头文件搜索路径传不进去，故由 `scripts/prebuild.py` 编成 `build/libime_probe_stub.a` 后经 `link_flags` 传入（与 shim 同一形态，链接参数照仓库规则全部由 prebuild 托管）。
