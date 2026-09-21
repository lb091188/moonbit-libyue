/* Windows GUI 子系统声明:moon 链接的 exe 免挂控制台黑框。
   约束:pragma 存于本文件目标文件的 drectve 段,链接器只处理被抽取的
   归档成员,故 yue_mbt_win_gui_marker 必须保持被引用(现由 initialize
   保证);机制与实测见 docs/zh/adaptation.md。 */
#if defined(_WIN32) && defined(_MSC_VER)
#pragma comment(linker, "/SUBSYSTEM:WINDOWS")
#pragma comment(linker, "/ENTRY:mainCRTStartup")
#endif

int yue_mbt_win_gui_marker(void) { return 42; }
