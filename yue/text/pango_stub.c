// Pango 文本层：测量与绘制都走 Pango（老师 libyue 在 GTK 上同样是 Pango，
// 见 nativeui/gfx/gtk/attributed_text_gtk.cc:82/128-132 的 ellipsize /
// set_width / get_pixel_size 用法）。字号按**逻辑像素**取绝对尺寸，
// 绘制目标始终是 MoonBit 自己拥有的 RGBA 缓冲（ARGB32 布局，见 yue/render）。

#include <pango/pangocairo.h>
#include <cairo.h>
#include <stdint.h>
#include <string.h>

static PangoLayout *pt_make_layout(const char *text, int len, double size,
                                   const char *family, int weight,
                                   int italic) {
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
  // Pango 的字重数值本身就是 CSS 口径（100..900），直传
  if (weight > 0) {
    pango_font_description_set_weight(desc, (PangoWeight)weight);
  }
  if (italic != 0) {
    pango_font_description_set_style(desc, PANGO_STYLE_ITALIC);
  }
  pango_layout_set_font_description(layout, desc);
  pango_font_description_free(desc);
  pango_layout_set_text(layout, text, len);
  return layout;
}

// 宽度约束只在「要换行」或「要省略」时交给 Pango：Pango 一旦拿到宽度就会按
// 默认 WRAP_WORD 折行，`wrap=false` 的语义（单行、可溢出）只能靠不设宽度实现
// （实测：设宽 + 不带 wrap 标志仍折成多行）。
static void pt_apply_width(PangoLayout *layout, int max_width, int wrap,
                           int ellipsize) {
  if (max_width > 0 && (wrap != 0 || ellipsize != 0)) {
    pango_layout_set_width(layout, max_width * PANGO_SCALE);
    if (wrap != 0) {
      pango_layout_set_wrap(layout, PANGO_WRAP_WORD_CHAR);
    }
  }
  if (ellipsize != 0) {
    pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END);
  }
}

// 测量：out = [width, height, baseline]（像素）。max_width <= 0 不约束；
// ellipsize != 0 尾端省略；wrap != 0 按词断行。
int pt_measure(const char *text, int len, double size, const char *family,
               int max_width, int ellipsize, int wrap, int32_t *out_w,
               int32_t *out_h, int32_t *out_baseline) {
  if (text == NULL || out_w == NULL || out_h == NULL || out_baseline == NULL) {
    return 0;
  }
  PangoLayout *layout = pt_make_layout(text, len, size, family, 400, 0);
  if (layout == NULL) {
    return 0;
  }
  pt_apply_width(layout, max_width, wrap, ellipsize);
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

// 字体行高：ascent + descent（像素），与样例文本无关。out = [height, ascent]
int pt_font_line_height(double size, const char *family, int weight,
                        int italic, int32_t *out_h, int32_t *out_ascent) {
  if (out_h == NULL || out_ascent == NULL) {
    return 0;
  }
  PangoFontMap *fm = pango_cairo_font_map_get_default();
  if (fm == NULL) {
    return 0;
  }
  PangoContext *ctx = pango_font_map_create_context(fm);
  if (ctx == NULL) {
    return 0;
  }
  PangoFontDescription *desc = pango_font_description_new();
  if (family != NULL && family[0] != '\0') {
    pango_font_description_set_family(desc, family);
  }
  pango_font_description_set_absolute_size(desc, size * PANGO_SCALE);
  if (weight > 0) {
    pango_font_description_set_weight(desc, (PangoWeight)weight);
  }
  if (italic != 0) {
    pango_font_description_set_style(desc, PANGO_STYLE_ITALIC);
  }
  PangoFontMetrics *m = pango_context_get_metrics(ctx, desc, NULL);
  g_object_unref(ctx);
  pango_font_description_free(desc);
  if (m == NULL) {
    return 0;
  }
  int ascent = pango_font_metrics_get_ascent(m);
  int descent = pango_font_metrics_get_descent(m);
  // PangoFontMetrics 不是 GObject，必须用 pango_font_metrics_unref；
  // 误用 g_object_unref 会 SIGSEGV（实测）。
  pango_font_metrics_unref(m);
  *out_ascent = (ascent + PANGO_SCALE / 2) / PANGO_SCALE;
  *out_h = (ascent + descent + PANGO_SCALE / 2) / PANGO_SCALE;
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
  PangoLayout *layout = pt_make_layout(text, len, size, family, 400, 0);
  if (layout == NULL) {
    cairo_destroy(cr);
    cairo_surface_destroy(surf);
    return 0;
  }
  pt_apply_width(layout, max_width, wrap, ellipsize);
  cairo_set_source_rgba(cr, r / 255.0, g / 255.0, b / 255.0, a / 255.0);
  cairo_move_to(cr, x, y);
  pango_cairo_show_layout(cr, layout);
  g_object_unref(layout);
  cairo_destroy(cr);
  cairo_surface_flush(surf);
  cairo_surface_destroy(surf);
  return 1;
}

// 带字重/斜体的测量：签名与 pt_measure 同形，外加 weight/italic。
// weight 为 0 时用 Pango 默认（Normal=400）；此函数与 pt_measure 的差异
// 只在字体描述上，布局与换行/省略语义完全一致。
int pt_measure_font(const char *text, int len, double size, const char *family,
                    int weight, int italic, int max_width, int ellipsize,
                    int wrap, int32_t *out_w, int32_t *out_h,
                    int32_t *out_baseline) {
  if (text == NULL || out_w == NULL || out_h == NULL || out_baseline == NULL) {
    return 0;
  }
  PangoLayout *layout = pt_make_layout(text, len, size, family, weight, italic);
  if (layout == NULL) {
    return 0;
  }
  pt_apply_width(layout, max_width, wrap, ellipsize);
  int w = 0, h = 0;
  pango_layout_get_pixel_size(layout, &w, &h);
  int baseline = pango_layout_get_baseline(layout);
  g_object_unref(layout);
  *out_w = w;
  *out_h = h;
  int bl = baseline / PANGO_SCALE;
  if (baseline % PANGO_SCALE >= PANGO_SCALE / 2) {
    bl += 1;
  }
  *out_baseline = bl;
  return 1;
}

// 盒内对齐绘制：box_w/box_h 为对齐容器（<=0 表示该轴不约束/不对齐），
// align/valign：0=start 1=center 2=end。水平对齐用 Pango 的布局宽度 +
// pango_layout_set_alignment；垂直对齐按布局量得的高度做偏移。省略/换行
// 语义与 pt_draw 相同，宽度约束取 box_w（>0 时）。
int pt_draw_box(unsigned char *data, int buf_w, int buf_h, double x, double y,
                double box_w, double box_h, const char *text, int len,
                double size, const char *family, int weight, int italic, int r,
                int g, int b, int a, int align, int valign, int ellipsize,
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
  PangoLayout *layout = pt_make_layout(text, len, size, family, weight, italic);
  if (layout == NULL) {
    cairo_destroy(cr);
    cairo_surface_destroy(surf);
    return 0;
  }
  int wrapped_axis = 0;
  if (box_w > 0.0 && (wrap != 0 || ellipsize != 0)) {
    // 有宽度约束：换行/省略交给 Pango，水平对齐用布局对齐
    wrapped_axis = 1;
    pango_layout_set_width(layout, (int)(box_w * PANGO_SCALE + 0.5));
    if (wrap != 0) {
      pango_layout_set_wrap(layout, PANGO_WRAP_WORD_CHAR);
    }
    PangoAlignment pa = PANGO_ALIGN_LEFT;
    if (align == 1) {
      pa = PANGO_ALIGN_CENTER;
    } else if (align == 2) {
      pa = PANGO_ALIGN_RIGHT;
    }
    pango_layout_set_alignment(layout, pa);
  }
  if (ellipsize != 0) {
    pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END);
  }
  int lw = 0, lh = 0;
  pango_layout_get_pixel_size(layout, &lw, &lh);
  double dx = 0.0;
  if (box_w > 0.0 && wrapped_axis == 0) {
    // 单行且不省略：不设宽度（否则 Pango 会折行），对齐自己算偏移
    double slack = box_w - (double)lw;
    if (slack > 0.0) {
      dx = align == 1 ? slack / 2.0 : (align == 2 ? slack : 0.0);
    }
  }
  double dy = 0.0;
  if (box_h > 0.0 && valign != 0) {
    double slack = box_h - (double)lh;
    if (slack > 0.0) {
      dy = valign == 1 ? slack / 2.0 : slack;
    }
  }
  cairo_set_source_rgba(cr, r / 255.0, g / 255.0, b / 255.0, a / 255.0);
  cairo_move_to(cr, x + dx, y + dy);
  pango_cairo_show_layout(cr, layout);
  g_object_unref(layout);
  cairo_destroy(cr);
  cairo_surface_flush(surf);
  cairo_surface_destroy(surf);
  return 1;
}
