// 非 Linux 平台的占位实现：保证三平台 `moon build --target native` 的符号不断
// （Linux 上本文件整体为空，真实现由 scripts/prebuild.py 编成
// build/libyue_win_stub.a 提供）。Windows/Cocoa 后端在 G7 之后各自补。

#if !defined(__linux__)

#include <stdint.h>

int wm_init(void) {
  return 0;
}

int64_t wm_window_new(int width, int height, const char *title) {
  (void)width;
  (void)height;
  (void)title;
  return 0;
}

void wm_show(int64_t id) {
  (void)id;
}

void wm_size(int64_t id, int32_t *out_w, int32_t *out_h) {
  (void)id;
  (void)out_w;
  (void)out_h;
}

int wm_event(int64_t id) {
  (void)id;
  return 0;
}

int wm_take_event(int64_t id) {
  (void)id;
  return -1;
}

int wm_pending_events(int64_t id) {
  (void)id;
  return 0;
}

gint32 wm_ev_keysym(int64_t id) { (void)id; return 0; }
gint32 wm_ev_mods(int64_t id) { (void)id; return 0; }
gint32 wm_ev_x(int64_t id) { (void)id; return 0; }
gint32 wm_ev_y(int64_t id) { (void)id; return 0; }
gint32 wm_ev_button(int64_t id) { (void)id; return 0; }
gint32 wm_ev_axis(int64_t id) { (void)id; return 0; }

void wm_present(int64_t id, const unsigned char *rgba, int width, int height) {
  (void)id;
  (void)rgba;
  (void)width;
  (void)height;
}

void wm_close(int64_t id) {
  (void)id;
}

void wm_pump(void) {}

int wm_wait(int timeout_ms) {
  (void)timeout_ms;
  return 0;
}

void wm_request_focus(int64_t id) { (void)id; }

void wm_im_set_surrounding(int64_t id, const char *text, int caret) {
  (void)id; (void)text; (void)caret;
}
void wm_im_set_cursor(int64_t id, int x, int y, int w, int h) {
  (void)id; (void)x; (void)y; (void)w; (void)h;
}
int wm_im_commit_len(int64_t id) { (void)id; return 0; }
int wm_im_commit_byte(int64_t id, int index) { (void)id; (void)index; return 0; }
void wm_im_commit_done(int64_t id) { (void)id; }
int wm_im_preedit_len(int64_t id) { (void)id; return 0; }
int wm_im_preedit_byte(int64_t id, int index) { (void)id; (void)index; return 0; }
int wm_im_preedit_caret(int64_t id) { (void)id; return 0; }
int wm_im_preedit_active(int64_t id) { (void)id; return 0; }

void wm_wakeup(void) {}

int64_t wm_now_ms(void) {
  return 0;
}

#endif
