// Windows GUI 子系统声明：链接本模块的 exe 免挂控制台黑框（双击运行不先弹
// 一个控制台窗口）。这是 **链接期政策**，与 stub.c 的后端实现无关，故单独成
// 一个翻译单元——谁链接了 gui/win，谁的 exe 就是 GUI 子系统，依赖方零配置。
//
// 机制（MSVC 专有）：
// - `#pragma comment(linker, ...)` 把参数写进本 TU 目标文件的 `.drectve` 段，
//   链接器读到该段就按「命令行参数」处理，效果等价于链接时显式传
//   `/SUBSYSTEM:WINDOWS`。换子系统后默认入口点变成 WinMainCRTStartup，而 moon
//   生成的是控制台形态的 `main()`，所以必须同时 `/ENTRY:mainCRTStartup` 把入口
//   钉回去，否则报 LNK2019 未解析的 WinMain。
// - 用户侧没有别的路可走：`cc-link-flags` 拼在 `/link` 之前，cl 把
//   `/SUBSYSTEM` 一类链接选项当编译选项直接丢弃（D9002），追加参数不生效
//   （实测记录见 docs/zh/adaptation.md「链接参数」节）。
//
// 归档抽取（关键约束）：moon 的 native-stub 把本文件编进包归档 `libwin.lib`，
// 而链接器只处理**被抽取的归档成员**的 `.drectve`——一个只有 pragma、没有
// 被引用符号的 TU 会被整体忽略，pragma 静默失效。故这里留一个 marker 符号，
// 并由 window.mbt 的 `init_backend()` 引用（`wm_win_gui_marker`），保证本成员
// 一定进链接。改本文件时别把 marker 删掉。
//
// 平台守卫：`#pragma comment(linker, ...)` 是 MSVC 专有；非 Windows（Linux 的
// GTK 分支、macOS 的占位分支）下本文件编成空翻译单元，不影响任何既有链路，
// Linux 上也不会与 prebuild 编出的 GTK 静态库双定义。

#if defined(_WIN32) && defined(_MSC_VER)
#pragma comment(linker, "/SUBSYSTEM:WINDOWS")
#pragma comment(linker, "/ENTRY:mainCRTStartup")
#endif

int wm_win_gui_marker(void) { return 42; }
