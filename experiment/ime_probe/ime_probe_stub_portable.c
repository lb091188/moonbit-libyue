// 非 Linux 平台的占位实现：本探针只服务 Linux（GTK3 输入法客户端），但 CI 在
// 三个平台都跑 `moon build --target native` 的全包链接，缺符号即红。故这里把
// 全部入口按同签名给出空实现——ip_init 返回 0，MoonBit 侧据此直接退出并说明
// 「本平台无探针」。Linux 上本文件整体为空（真正的实现由 scripts/prebuild.py
// 编成 build/libime_probe_stub.a 后按 link_flags 传入）。

#if !defined(__linux__)

typedef int ip_probe_portable_placeholder;  // 保证翻译单元非空

int ip_init(int mode) {
  (void)mode;
  return 0;
}

int ip_iterate(int blocking) {
  (void)blocking;
  return 0;
}

int ip_should_quit(void) { return 1; }

long long ip_now_ms(void) { return 0LL; }

int ip_counter(int idx) {
  (void)idx;
  return 0;
}

void ip_on_key(void (*invoke)(void *, int, int, int, int), void *closure) {
  (void)invoke;
  (void)closure;
}

void ip_on_commit(void (*invoke)(void *, void *), void *closure) {
  (void)invoke;
  (void)closure;
}

void ip_on_preedit(void (*invoke)(void *, void *, int, int), void *closure) {
  (void)invoke;
  (void)closure;
}

void ip_on_note(void (*invoke)(void *, void *, void *), void *closure) {
  (void)invoke;
  (void)closure;
}

void ip_set_display(void *text, int len, int caret_byte) {
  (void)text;
  (void)len;
  (void)caret_byte;
}

void ip_set_cursor_rect(int x, int y, int w, int h) {
  (void)x;
  (void)y;
  (void)w;
  (void)h;
}

double ip_measure(void *text, int len) {
  (void)text;
  (void)len;
  return 0.0;
}

double ip_line_height(void) { return 0.0; }

int ip_apply_css(void *css, int len) {
  (void)css;
  (void)len;
  return 0;
}

void ip_report_im_module(void) {}

#endif
