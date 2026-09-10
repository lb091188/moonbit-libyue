/*
 * moonbit-libyue 的 C ABI 边界（唯一稳定接口）。
 *
 * 分层约定：
 *   MoonBit 层(yue/*.mbt)  --extern-->  本头文件  --C++-->  libyue
 * 本层之上只有 MoonBit；本层之下是 libyue 吸收三大平台差异。
 * 所有句柄参数均为 shim 分配的外部对象（内部持有 scoped_refptr），
 * 生命周期由 MoonBit GC finalizer 管理，C 侧不提供 destroy。
 * 字符串一律 UTF-8（MoonBit 侧负责 UTF-16 转换）。
 */
#ifndef YUE_MBT_H
#define YUE_MBT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---------- 应用生命周期 ---------- */

/* 初始化 CommandLine + Lifetime + State。成功返回 1。 */
int32_t yue_mbt_app_init(void);

/* 进入平台消息循环，阻塞至 yue_mbt_quit。 */
void yue_mbt_run(void);

/* 请求退出消息循环。 */
void yue_mbt_quit(void);

/* 平台标识：0=linux 1=macos 2=windows */
int32_t yue_mbt_platform(void);

/* ---------- 窗口 ---------- */

void *yue_mbt_window_new(void);
void yue_mbt_window_set_content(void *window, const void *content);
void yue_mbt_window_set_content_size(void *window, double width, double height);
void yue_mbt_window_center(void *window);
void yue_mbt_window_activate(void *window);

/* 注册关闭回调。invoke(closure) 由 C 在事件触发时调用；
 * closure 由 MoonBit 侧注册表保活，本层只存指针、不持有引用。 */
void yue_mbt_window_on_close(void *window,
                             void (*invoke)(void *closure),
                             void *closure);

/* ---------- 标签 ---------- */

/* text 为 UTF-8。失败返回 NULL（外部对象分配失败，极罕见）。 */
void *yue_mbt_label_new(const char *text);
void yue_mbt_label_set_text(void *label, const char *text);

/* ---------- 托盘 ---------- */

/* 托盘后端是否可用。Linux 检查 AppIndicator 运行库能否 dlopen，
 * Windows/macOS 恒返回 1。 */
int32_t yue_mbt_tray_supported(void);

/* icon_path 为 UTF-8 图片路径。后端缺失或图标读取失败返回 NULL。 */
void *yue_mbt_tray_new(const char *icon_path);

/* title 为 UTF-8。Linux 上映射为 AppIndicator label。 */
void yue_mbt_tray_set_title(void *tray, const char *title);
void yue_mbt_tray_remove(void *tray);

#ifdef __cplusplus
}
#endif

#endif /* YUE_MBT_H */
