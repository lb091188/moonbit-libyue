// 非 Linux 占位：Linux 的真实现由 scripts/prebuild.py 编成 librender_cairo_stub.a。
// 其余平台的后端随各自窗口层落地时补。

#if !defined(__linux__)

#include <stdint.h>

int64_t cr_begin(unsigned char *data, int width, int height) {
  (void)data; (void)width; (void)height; return 0;
}
void cr_end(int64_t id) { (void)id; }
void cr_begin_path(int64_t id) { (void)id; }
void cr_close_path(int64_t id) { (void)id; }
void cr_move_to(int64_t id, double x, double y) { (void)id; (void)x; (void)y; }
void cr_line_to(int64_t id, double x, double y) { (void)id; (void)x; (void)y; }
void cr_bezier_to(int64_t id, double a, double b, double c, double d, double e, double f) {
  (void)id; (void)a; (void)b; (void)c; (void)d; (void)e; (void)f;
}
void cr_arc(int64_t id, double cx, double cy, double r, double a0, double a1) {
  (void)id; (void)cx; (void)cy; (void)r; (void)a0; (void)a1;
}
void cr_fill(int64_t id) { (void)id; }
void cr_stroke(int64_t id) { (void)id; }
void cr_fill_rect(int64_t id, double x, double y, double w, double h) {
  (void)id; (void)x; (void)y; (void)w; (void)h;
}
void cr_stroke_rect(int64_t id, double x, double y, double w, double h) {
  (void)id; (void)x; (void)y; (void)w; (void)h;
}
void cr_set_fill_rgba(int64_t id, int r, int g, int b, int a) {
  (void)id; (void)r; (void)g; (void)b; (void)a;
}
void cr_set_stroke_rgba(int64_t id, int r, int g, int b, int a) {
  (void)id; (void)r; (void)g; (void)b; (void)a;
}
void cr_set_line_width(int64_t id, double w) { (void)id; (void)w; }
void cr_save(int64_t id) { (void)id; }
void cr_restore(int64_t id) { (void)id; }
void cr_translate(int64_t id, double dx, double dy) { (void)id; (void)dx; (void)dy; }
void cr_scale(int64_t id, double sx, double sy) { (void)id; (void)sx; (void)sy; }
void cr_rotate(int64_t id, double rad) { (void)id; (void)rad; }
void cr_clip_rect(int64_t id, double x, double y, double w, double h) {
  (void)id; (void)x; (void)y; (void)w; (void)h;
}
void cr_flush(int64_t id) { (void)id; }

#endif
