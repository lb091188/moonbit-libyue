// Pango 文本层：测量与绘制都走 Pango（老师 libyue 在 GTK 上同样是 Pango，
// 见 nativeui/gfx/gtk/attributed_text_gtk.cc:82/128-132 的 ellipsize /
// set_width / get_pixel_size 用法）。字号按**逻辑像素**取绝对尺寸，
// 绘制目标始终是 MoonBit 自己拥有的 RGBA 缓冲（ARGB32 布局，见 yue/render）。

#include <pango/pangocairo.h>
#include <cairo.h>
#include <stdint.h>
#include <string.h>

static PangoLayout *pt_make_layout(const char *text, int len, double size,
                                   const char *family) {
  PangoFontMap *fm = pango_cairo_font_map_get_default();
  if (fm == NULL) {
    return NULL;
  }
  PangoContext *ctx = pango_font_map_create_context(fm);
  if (ctx == NULL) {
    return NULL;
  }
  PangoLayout *layout = pango_layout_new(ctx);
  g_object_unref(ctx);
  if (layout == NULL) {
    return NULL;
  }
  PangoFontDescription *desc = pango_font_description_new();
  if (family != NULL && family[0] != '\0') {
    pango_font_description_set_family(desc, family);
  }
  pango_font_description_set_absolute_size(desc, size * PANGO_SCALE);
  pango_layout_set_font_description(layout, desc);
  pango_font_description_free(desc);
  pango_layout_set_text(layout, text, len);
  return layout;
}

// 测量：out = [width, height, baseline]（像素）。max_width <= 0 不约束；
// ellipsize != 0 尾端省略；wrap != 0 按词断行。
int pt_measure(const char *text, int len, double size, const char *family,
               int max_width, int ellipsize, int wrap, int32_t *out_w,
               int32_t *out_h, int32_t *out_baseline) {
  if (text == NULL || out_w == NULL || out_h == NULL || out_baseline == NULL) {
    return 0;
  }
  PangoLayout *layout = pt_make_layout(text, len, size, family);
  if (layout == NULL) {
    return 0;
  }
  if (max_width > 0) {
    pango_layout_set_width(layout, max_width * PANGO_SCALE);
    if (wrap != 0) {
      pango_layout_set_wrap(layout, PANGO_WRAP_WORD_CHAR);
    }
  }
  if (ellipsize != 0) {
    pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END);
  }
  int w = 0, h = 0;
  pango_layout_get_pixel_size(layout, &w, &h);
  int baseline = pango_layout_get_baseline(layout);
  g_object_unref(layout);
  *out_w = w;
  *out_h = h;
  // Pango 基线是 Pango units，四舍五入到整像素
  int bl = baseline / PANGO_SCALE;
  if (baseline % PANGO_SCALE >= PANGO_SCALE / 2) {
    bl += 1;
  }
  *out_baseline = bl;
  return 1;
}

// 在调用方缓冲上画文本：(x,y) 是布局盒左上角；返回 0 表示后端不可用。
int pt_draw(unsigned char *data, int buf_w, int buf_h, double x, double y,
            const char *text, int len, double size, const char *family,
            int r, int g, int b, int a, int max_width, int ellipsize,
            int wrap) {
  if (data == NULL || text == NULL || buf_w < 1 || buf_h < 1) {
    return 0;
  }
  cairo_surface_t *surf = cairo_image_surface_create_for_data(
      data, CAIRO_FORMAT_ARGB32, buf_w, buf_h, buf_w * 4);
  if (cairo_surface_status(surf) != CAIRO_STATUS_SUCCESS) {
    cairo_surface_destroy(surf);
    return 0;
  }
  cairo_t *cr = cairo_create(surf);
  PangoLayout *layout = pt_make_layout(text, len, size, family);
  if (layout == NULL) {
    cairo_destroy(cr);
    cairo_surface_destroy(surf);
    return 0;
  }
  if (max_width > 0) {
    pango_layout_set_width(layout, max_width * PANGO_SCALE);
    if (wrap != 0) {
      pango_layout_set_wrap(layout, PANGO_WRAP_WORD_CHAR);
    }
  }
  if (ellipsize != 0) {
    pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END);
  }
  cairo_set_source_rgba(cr, r / 255.0, g / 255.0, b / 255.0, a / 255.0);
  cairo_move_to(cr, x, y);
  pango_cairo_show_layout(cr, layout);
  g_object_unref(layout);
  cairo_destroy(cr);
  cairo_surface_flush(surf);
  cairo_surface_destroy(surf);
  return 1;
}
