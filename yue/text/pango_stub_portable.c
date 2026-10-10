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

int pt_font_line_height(double size, const char *family, int weight,
                        int italic, int32_t *out_h, int32_t *out_ascent) {
  (void)size; (void)family; (void)weight; (void)italic; (void)out_h;
  (void)out_ascent;
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

int pt_measure_font(const char *text, int len, double size, const char *family,
                    int weight, int italic, int max_width, int ellipsize,
                    int wrap, int32_t *out_w, int32_t *out_h,
                    int32_t *out_baseline) {
  (void)text; (void)len; (void)size; (void)family; (void)weight; (void)italic;
  (void)max_width; (void)ellipsize; (void)wrap; (void)out_w; (void)out_h;
  (void)out_baseline;
  return 0;
}

int pt_draw_box(unsigned char *data, int buf_w, int buf_h, double x, double y,
                double box_w, double box_h, const char *text, int len,
                double size, const char *family, int weight, int italic, int r,
                int g, int b, int a, int align, int valign, int ellipsize,
                int wrap) {
  (void)data; (void)buf_w; (void)buf_h; (void)x; (void)y; (void)box_w;
  (void)box_h; (void)text; (void)len; (void)size; (void)family; (void)weight;
  (void)italic; (void)r; (void)g; (void)b; (void)a; (void)align; (void)valign;
  (void)ellipsize; (void)wrap;
  return 0;
}


// 富文本会话占位（非 Linux 平台）
int64_t rt_new(const char *text, int tlen, double size, const char *family,
               int flen, int weight, int italic) {
  (void)text; (void)tlen; (void)size; (void)family; (void)flen; (void)weight;
  (void)italic; return 0;
}
void rt_free(int64_t h) { (void)h; }
void rt_set_text(int64_t h, const char *text, int len) { (void)h; (void)text; (void)len; }
void rt_set_font(int64_t h, const char *family, int flen, double size,
                 int weight, int italic) {
  (void)h; (void)family; (void)flen; (void)size; (void)weight; (void)italic;
}
void rt_set_format(int64_t h, int align, int valign, int wrap, int ellipsize) {
  (void)h; (void)align; (void)valign; (void)wrap; (void)ellipsize;
}
void rt_add_color(int64_t h, int start, int end, int r, int g, int b, int a) {
  (void)h; (void)start; (void)end; (void)r; (void)g; (void)b; (void)a;
}
void rt_add_font(int64_t h, int start, int end, const char *family, int flen,
                 double size, int weight, int italic) {
  (void)h; (void)start; (void)end; (void)family; (void)flen; (void)size;
  (void)weight; (void)italic;
}
int rt_measure(int64_t h, double box_w, int32_t *out_w, int32_t *out_h,
               int32_t *out_baseline) {
  (void)h; (void)box_w; (void)out_w; (void)out_h; (void)out_baseline;
  return 0;
}
int rt_draw(int64_t h, unsigned char *data, int buf_w, int buf_h, double x,
            double y, double box_w, double box_h, int r0, int g0, int b0,
            int a0) {
  (void)h; (void)data; (void)buf_w; (void)buf_h; (void)x; (void)y;
  (void)box_w; (void)box_h; (void)r0; (void)g0; (void)b0; (void)a0;
  return 0;
}

#endif
