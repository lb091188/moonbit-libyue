/* 实验组 A(官方建议原味):纯 pragma,文件内无任何符号。
   验证点:moon 把本文件编进 hello-themed 的 CStubLibrary 静态归档并放在
   MSVC 链接命令 sources 段(硬编码 /subsystem:console 之前);成员不被
   任何符号引用时,链接器是否仍处理其 drectve 指令。 */
#if defined(_WIN32) && defined(_MSC_VER)
#pragma comment(linker, "/SUBSYSTEM:WINDOWS")
#pragma comment(linker, "/ENTRY:mainCRTStartup")
#endif

typedef int yue_win_gui_tu_guard_t;
