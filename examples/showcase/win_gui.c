/* 实验组 B:pragma + 被引用符号。yue_mbt_gui_marker 被 showcase 的
   MoonBit 代码引用,保证归档成员被链接器抽取,再观察 drectve 是否生效
   ——与实验组 A(纯 pragma)对照,隔离「成员未被抽取」这一变量。 */
#if defined(_MSC_VER)
#pragma comment(linker, "/SUBSYSTEM:WINDOWS")
#pragma comment(linker, "/ENTRY:mainCRTStartup")
#endif

int yue_mbt_gui_marker(void) { return 42; }
