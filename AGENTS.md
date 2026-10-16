# AGENTS.md — native-gui AI 协作规则(ZCode 读取仓库根 AGENTS.md)

native-gui(`NoahLiu/native-gui`,2026-10-12 前名 moonbit-libyue):MoonBit 的轻量跨平台桌面 **GUI 框架**——窗口原生直连、渲染管线自绘、界面组件齐全、系统接口完备(窗口/像素/事件循环/布局全自有,控件一律自绘,**不依赖 libyue**)。
当前主链路:**Ubuntu 24.04 + X11 + XFCE**(其余平台状态见适配经验文档)。

包布局(2026-10-12 定案): 库模块根 = `gui/`(`moon.mod` 在此,name 仍是 `NoahLiu/native-gui`,故 mooncakes 上包路径 `NoahLiu/native-gui/<包>` 与用户既有 import **全部不变**),14 个库包(`base`/`core`/`ui`/`render`/`text`/`theme`/`icons`/`sys`/`input`/`win`/`dbus`/`chart`/`mdview`/`style`)都在其下(web 已于 2026-10-16 G9 Batch 1 出成独立模块 `modules/gui-webview`;`base` 是 2026-10-17 Batch 2 第一刀从 `core` 提出的响应式/焦点/记账层,迁移期 `@base` 公开名仍经 `core/compat.mbt` 转发);`examples/`、`experiment/` 各为**独立模块**(`NoahLiu/native-gui-examples` / `NoahLiu/native-gui-experiment`),经 `moon.work` 本地解析依赖库模块——示例/探针的构建与测试不再牵连库门禁;重资产扩展独立模块 `modules/gui-media`(媒体)与 `modules/gui-webview`(WebView),均模块级可选;扩展示例模块 `modules/gui-examples`;旧链 `yue/` 已删除。libyue 只作**老师**(行为参考、可平移资产来源、`patches/` 的真实 bug 语料)。
分层原则: 能用 MoonBit 解决的不进 C/C++;平台 C 桩按「单一 stub.c 多分支 + prebuild 宏」组织(先例 `win/stub.c`);链接参数由 prebuild 全权托管。

## 硬性规则

1. **链接参数由库模块的 `gui/scripts/prebuild.py` 全权托管**——moon 构建时执行该脚本（`gui/moon.mod` 的 `options(--moonbit-unstable-prebuild)`），按当前系统输出 link_configs，自动传播给依赖库模块的所有 main 包；任何包的 `moon.pkg` 都不写链接参数，勿手改。**prebuild 只能给自己模块内的包下发配置**：moon 拒绝外部模块的包名（实测报 `cannot apply config to an external package`），故 examples/experiment 不配 prebuild、也不能配——它们构建时会自动继承库模块的链接参数（实测 `cd examples && moon build hello --target native` 链接通过）。脚本 stdout 只允许输出 JSON，进度信息走 stderr。
2. **库包不得放 `link` 段**——moon 会生成无 main 的 `.exe` 导致构建失败;链接配置统一走 prebuild 传播,任何包都不写 `cc-link-flags`。
3. **FFI 改动必须对照 `.agents/skills/moonbit-c-binding/` 规范**;平台 C 一律按「单一 stub.c 多分支」组织(先例 `gui/win/stub.c`),新增能力按固定流程:C 实做落在对应平台分支 → `gui/<包>/ffi.mbt` 写 `extern "c"` 声明(非原始参数标 `#borrow`、文本一律 `Bytes`、出参用 `Ref[Int]`)→ `gui/<包>/<能力>.mbt` 提供平台无关类型与方法;**不做 C→MoonBit 回调**(事件用「每窗口标志位 + 消费式取事件」暴露,见 `gui/win/stub.c` 头注释);链接参数一律由 prebuild 托管,任何 `moon.pkg` 都不写。
4. **extern 蹦床与 C 函数指针原型逐位对齐,含参数个数**——C 以 `(closure, args...)` 调用,蹦床首参收 closure;多带/少带一位会形参错位,部分接口"看似能跑"掩盖问题。案例与更多 ABI 坑见适配经验文档。
5. **协议级互操作(DBus/DBusMenu/SNI)必须上真实总线、真实面板验证**——单测自洽 ≠ 互操作通过(XFCE 只发批量版 `EventGroup`/`AboutToShowGroup` 就是 dbus-monitor 抓出来的)。
6. **真机 GUI 测试由用户执行,助手只提供操作步骤并等待反馈**——助手负责:代码修复、`moon check`/`moon test`/`moon build` 全仓零错误零警告通过(提交门槛)、启动冒烟(进程存活 + 退出行为,仅限助手所在宿主机);涉及虚拟机/其他桌面环境的视觉与交互验证,一律给出明确的操作步骤清单,由用户在真机执行并回反馈结果,助手不得自行远程驱动 GUI 测试,也不得在用户反馈前下结论。
7. **开发中积累的封装/适配经验必须回写 `docs/zh/adaptation.md`**——每次真实环境实测/踩坑后,按其维护约定把「环境(发行版/桌面环境/版本)+ 现象 + 根因 + 修复 + 验证方式」写进对应小节,与对应代码改动同批提交;只留在提交说明或会话记忆里视为未完成。
8. **与用户交流必须全部使用中文**——所有回复、说明、总结、提问一律用中文书写,不夹杂英文段落(代码、命令、路径、专有名词除外)。
9. **每完成一个批次的需求就提交到仓库**——一个批次=一组内聚的改动(一个功能/一次修复/一批文档),完成即 `git commit` 并推送 origin,不积压到工作区;单批改动过大时按内聚单元拆成多批(一批一个主题,代码权责清晰),逐批提交,避免多主题挤进一条;提交信息沿用「【标签】范围:说明」中文格式(【新增】/【修复】/【文档】/【构建】),主题行控制在百字上下:改动内容一句 + 验证结果一句,原理/根因/实测过程以专门文档为准,不在提交信息里复述。发布:二进制产物推 `bin-*` 标签,由 GitHub Actions 自动构建(原生层已不再随包 vendored,`vendor-*` 线随旧链清理)。
10. **代码注释与使用文档只说内容**——注释、README、docs 使用类文档(components/declarative/layout/relink)只写「是什么/怎么用/怎么做」;原理、根因、实测过程一律写进专门文档(`docs/zh/adaptation.md`、`docs/tray.md`),不在内容文档与注释里重复展开。
11. **MoonBit 侧跨平台分派一律运行时探测 + 模式匹配,禁用 `#cfg(platform=)` 等编译指令**——即便工具链条件编译可用也维持运行时探测口径,三平台同构优先(2026-10-11 定案);探测形态照 `render` 既有的降级探针(画一笔验像素、会话句柄非零)。平台 C 桩按「单一 stub.c 多分支 + prebuild 宏」组织(先例 `win/stub.c`)。

## 常用命令

```sh
moon clean                    # 清理缓存
cd gui && moon check           # 库模块门禁:静态检查(要求零错误零警告)
cd gui && moon test core ui render text theme icons sys input win dbus chart mdview web style   # 库测试(按包限定)
moon run examples/hello         # 原版控件最小示例
moon run examples/hello-themed  # 主题组件库最小示例
moon run examples/showcase      # 全功能演示板(现代主题,组件库+系统能力)
```

门禁口径:库门禁在 `gui/` 下按包限定跑(如上)。裸 `moon test` 在 workspace 里会连带 examples / experiment / 媒体模块,其中含既有的平台适配缺口(非库缺陷),不作库门禁使用。

## 文档地图

- 使用文档索引(内容类): `docs/README.md`
- **平台适配经验**(Windows/macOS 分版本,Linux 分发行版→桌面环境→版本,含全部实测坑与维护约定): `docs/zh/adaptation.md`
- FFI 规范与坑清单:`.agents/skills/moonbit-c-binding/`、`.agents/skills/make-moonbit-c-bindings/`
- MoonBit 语言与工具链:`.agents/skills/moonbit-agent-guide/`
- 路线图与下一步: `TODO.md`
- 快速开始/架构说明: `README.md`(中文版 `README_ZH.md`)
