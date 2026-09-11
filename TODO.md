# 下一步操作指南

当前状态（2026-09）：Ubuntu 24.04 / X11 主链路已跑通——13 个 `examples/*` 全部构建并试跑存活，封装面约 250 个 ABI 函数，Linux 托盘为纯 MoonBit SNI 直连（XFCE 实测图标与点击回调贯通），`moon check` / `moon build` 全仓零错误零警告，`moon test` 18/18。

从零搭建环境请看 `README` 的「快速开始」。

## 近期

- [ ] GNOME (X11) 下人工确认托盘/菜单/对话框/WebView 的视觉与交互表现，差异入档 README「已知边界」（程序化验证已覆盖：进程存活 + 退出行为）
- [ ] 回调注册表（`yue/view.mbt`）在窗口销毁后回收条目
- [ ] 托盘图标支持自定义位图/文件路径的更多形态，补 `traybus` 对 icon 主题名的解析
- [ ] 发布 mooncakes 包（API 面稳定后）
- [ ] Wayland 支持（当前仅 X11）

## 中期

- [ ] macOS 实测（CMake 已备 ARC/no-ARC 双库分支，未验证）
- [ ] Windows 链接参数自动化（`prepare.py` 当前对 Windows 直接跳过回写，需手工核对）
- [ ] Image/图片编码类 API（editor 示例的图片按钮现为文字按钮替代，就是为了绕开这块）

## 扩展模式（每加一个控件同一模式）

1. `shim/yue_mbt.cpp` 加机械转换函数（对照 `vendor/libyue/include/nativeui/` 头文件签名）
2. `shim/include/yue_mbt.h` 加 C 声明
3. `yue/ffi.mbt` 加 extern
4. 新建 `yue/<控件>.mbt` 写类型和方法，字符串统一走 `utf8_bytes()`
5. 有事件的控件：照抄 `yue/view.mbt` 的注册表 + trampoline 模式
6. 新增示例放 `examples/<name>/`（`is-main` 包，`prepare.py` 会自动回写链接参数）

## 随手可查

- FFI 规范、坑清单：`.agents/skills/moonbit-c-binding/`
- 完整 API 对照：libyue TS 声明（github.com/yue/yue releases 里的 `yue_typescript_declarations`）
- Lua 绑定实现参考：github.com/yue/yue 的 `lua_yue/`（类绑定、信号、平台 gate 的写法）
