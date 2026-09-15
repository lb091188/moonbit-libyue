# AGENTS.md — moonbit-libyue AI 协作规则(ZCode 读取仓库根 AGENTS.md)

libyue(libyue.com)的 MoonBit 封装,跨平台原生桌面 GUI。
当前主链路:**Ubuntu 24.04 + X11 + XFCE**(其余平台状态见适配经验文档)。

三层架构: `examples/*`(纯 MoonBit,零平台代码)→ `yue/`(统一 API,平台探测与降级在此消化)→ `shim/ + vendor/libyue`(最薄 C ABI + 平台库)。
分层原则: 能用 MoonBit 解决的不进 C/C++;shim 只做 ABI 翻译无业务逻辑;libyue 没暴露的能力由 shim 补探测接口,MoonBit 层统一成语义化结果。

## 硬性规则

1. **链接参数由 `scripts/prebuild.py` 全权托管**——moon 构建时执行该脚本（`moon.mod` 的 `options(--moonbit-unstable-prebuild)`），按当前系统输出 link_configs 自动传播给所有依赖 yue 的 main 包；任何包的 `moon.pkg` 都不写链接参数，勿手改。脚本 stdout 只允许输出 JSON，进度信息走 stderr。
2. **库包(如 `yue/`)不得放 `link` 段**——moon 会生成无 main 的 `.exe` 导致构建失败;链接配置统一走 prebuild 传播,任何包都不写 `cc-link-flags`。
3. **FFI 改动必须对照 `.agents/skills/moonbit-c-binding/` 规范**;新增控件按固定流程:`shim/yue_mbt.cpp` 机械转换 → `shim/include/yue_mbt.h` 声明 → `yue/ffi.mbt` extern → `yue/<控件>.mbt` 类型与方法(字符串统一 `utf8_bytes()`,事件照抄 `yue/view.mbt` 注册表+蹦床模式)。
4. **extern 蹦床与 C 函数指针原型逐位对齐,含参数个数**——C 以 `(closure, args...)` 调用,蹦床首参收 closure;多带/少带一位会形参错位,部分接口"看似能跑"掩盖问题。案例与更多 ABI 坑见适配经验文档。
5. **协议级互操作(DBus/DBusMenu/SNI)必须上真实总线、真实面板验证**——单测自洽 ≠ 互操作通过(XFCE 只发批量版 `EventGroup`/`AboutToShowGroup` 就是 dbus-monitor 抓出来的)。
6. 验证 GUI 改动用真实启动:进程存活 + 退出行为是底线,涉及视觉/交互需真人或截图确认;`moon check` / `moon build` 全仓零错误零警告、`moon test` 全过是提交门槛。
7. **开发中积累的封装/适配经验必须回写 `docs/adaptation.md`**——每次真实环境实测/踩坑后,按其维护约定把「环境(发行版/桌面环境/版本)+ 现象 + 根因 + 修复 + 验证方式」写进对应小节,与对应代码改动同批提交;只留在提交说明或会话记忆里视为未完成。
8. **与用户交流必须全部使用中文**——所有回复、说明、总结、提问一律用中文书写,不夹杂英文段落(代码、命令、路径、专有名词除外)。
9. **每完成一个批次的需求就提交到仓库**——一个批次=一组内聚的改动(一个功能/一次修复/一批文档),完成即 `git commit` 并推送 origin,不积压到工作区;提交信息沿用「【标签】范围:说明」中文格式(【新增】/【修复】/【文档】/【构建】)。
10. **代码注释与使用文档只说内容**——注释、README、docs 使用类文档(components/declarative/layout/relink)只写「是什么/怎么用/怎么做」;原理、根因、实测过程一律写进专门文档(`docs/adaptation.md`、`docs/tray.md`),不在内容文档与注释里重复展开。
## 常用命令

```sh
python3 scripts/prepare.py    # 手动构建原生层:钉版本下载 libyue + CMake 静态库(需 GitHub 网络;)
moon clean                    # 清理缓存
moon run examples/hello       # 最小示例
moon run examples/showcase    # 全功能演示
moon check && moon test       # 纯 MoonBit 测试
```

## 文档地图

- 使用文档索引(内容类): `docs/README.md`
- **平台适配经验**(Windows/macOS 分版本,Linux 分发行版→桌面环境→版本,含全部实测坑与维护约定): `docs/adaptation.md`
- FFI 规范与坑清单:`.agents/skills/moonbit-c-binding/`、`.agents/skills/make-moonbit-c-bindings/`
- MoonBit 语言与工具链:`.agents/skills/moonbit-agent-guide/`
- 路线图与下一步: `TODO.md`
- 快速开始/架构说明: `README.md`(中文版 `README_ZH.md`)
