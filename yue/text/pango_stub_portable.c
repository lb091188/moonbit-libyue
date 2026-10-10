// 非 Linux 占位：真实现由 scripts/prebuild.py 编成 libyue_text_pango.a。
#if !defined(__linux__)
#include <stdint.h>

int pt_measure(const char *text, int len, double size, const char *family,
               int max_width, int ellipsize, int wrap, int32_t *out_w,
               int32_t *out_h, int32_t *out_baseline) {
  (void)text; (void)len; (void)size; (void)family; (void)max_width;
  (void)ellipsize; (void)wrap; (void)out_w; (void)out_h; (void)out_baseline;
  return 0;
}

int pt_font_line_height(double size, const char *family, int32_t *out_h,
                        int32_t *out_ascent) {
  (void)size; (void)family; (void)out_h; (void)out_ascent;
  return 0;
}

int pt_draw(unsigned char *data, int buf_w, int buf_h, double x, double y,
            const char *text, int len, double size, const char *family,
            int r, int g, int b, int a, int max_width, int ellipsize,
            int wrap) {
  (void)data; (void)buf_w; (void)buf_h; (void)x; (void)y; (void)text;
  (void)len; (void)size; (void)family; (void)r; (void)g; (void)b; (void)a;
  (void)max_width; (void)ellipsize; (void)wrap;
  return 0;
}
#endif
