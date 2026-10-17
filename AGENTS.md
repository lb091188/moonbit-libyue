# AGENTS.md — native-gui AI 协作规则

native-gui(`NoahLiu/native-gui`): MoonBit 的跨平台桌面 GUI 框架——一套代码直出 Windows / Linux / macOS 原生窗口，系统能力开箱即用，`moon add` 后零配置。详见 [README](README.md)。
当前主链路: **Ubuntu 24.04 + X11 + XFCE**。

## 硬性规则

1. **链接参数由 prebuild 全权托管**——任何 `moon.pkg` 都不写链接参数，勿手改。详见 `gui/scripts/prebuild.py`。
2. **库包不得放 `link` 段**——moon 会生成无 main 的 `.exe` 导致构建失败；链接配置统一走 prebuild。
3. **FFI 改动必须对照 `.agents/skills/moonbit-c-binding/` 规范**——平台 C 按「单一 stub.c 多分支」组织；不做 C→MoonBit 回调；链接参数一律由 prebuild 托管。
4. **extern 蹦床与 C 函数指针原型逐位对齐，含参数个数**——案例与 ABI 坑见 `docs/zh/adaptation.md`。
5. **协议级互操作(DBus/DBusMenu/SNI)必须上真实总线、真实面板验证**——单测自洽 ≠ 互操作通过。
6. **真机 GUI 测试由用户执行**——助手负责代码修复与 `moon check`/`moon test`/`moon build` 零错误零警告；视觉与交互验证给出操作步骤清单，由用户在真机执行并反馈，助手不得自行远程驱动，不得在反馈前下结论。
7. **封装/适配经验必须回写 `docs/zh/adaptation.md`**——环境 + 现象 + 根因 + 修复 + 验证方式，与代码改动同批提交；只留在提交说明或会话记忆里视为未完成。
8. **与用户交流全部使用中文**——代码、命令、路径、专有名词除外。
9. **每完成一个功能或修复即提交并推送**——提交信息只写「【标签】做了什么」(如【修复】输入框焦点丢失)，一个功能一次提交；原理、原因、解释一概不写，归专门文档。
10. **代码注释与使用文档只说内容**——只写「是什么/怎么用/怎么做」；原理、根因写进 `docs/zh/adaptation.md` 等专门文档，不在内容文档与注释里展开。
11. **MoonBit 侧跨平台分派一律运行时探测 + 模式匹配**——禁用 `#cfg(platform=)` 等编译指令，三平台同构优先。

## 常用命令

```sh
moon clean                    # 清理缓存
cd gui && moon check           # 库模块门禁:静态检查(要求零错误零警告)
cd gui && moon test ui render text theme icons sys input win dbus chart mdview web style base shell widget   # 库测试(按包限定)
moon run examples/hello         # 最小窗口
moon run examples/hello-themed  # 主题控件集
moon run examples/showcase      # 完整演示板
```

门禁口径: 库门禁在 `gui/` 下按包限定跑。裸 `moon test` 会连带 examples / experiment / 媒体模块，其中含平台适配缺口(非库缺陷)，不作库门禁使用。

## 文档地图

- 使用文档索引: `docs/README.md`
- 平台适配经验: `docs/zh/adaptation.md`
- FFI 规范: `.agents/skills/moonbit-c-binding/`、`.agents/skills/make-moonbit-c-bindings/`
- MoonBit 语言与工具链: `.agents/skills/moonbit-agent-guide/`
- 路线图: `TODO.md`
- 快速开始/架构: `README.md`(中文 `README_ZH.md`)
