// Cairo 光栅器桥：在调用方的像素缓冲上建 image surface，转调 cairo 的路径/变换/
// 裁剪/填充描边。缓冲归 MoonBit（yue/render 的 Bitmap，ARGB32 预乘布局与
// CAIRO_FORMAT_ARGB32 一致），本层不拥有内存、不 free 数据。
//
// 会话式句柄：cr_begin 拿缓冲地址建 surface+cr，后续调用都带句柄，cr_end 释放。
// 缓冲在会话期间由 MoonBit 侧持有（#borrow），不会因 GC 回收。

#include <cairo.h>
#include <stdint.h>
#include <string.h>

#define CR_MAX 16

typedef struct {
  cairo_surface_t *surface;
  cairo_t *cr;
  int in_use;
} CrSlot;

static CrSlot cr_slots[CR_MAX];

int64_t cr_begin(unsigned char *data, int width, int height);

int64_t cr_begin(unsigned char *data, int width, int height) {
  if (data == NULL || width < 1 || height < 1) {
    return 0;
  }
  for (int i = 1; i < CR_MAX; i++) {
    if (!cr_slots[i].in_use) {
      cairo_surface_t *s = cairo_image_surface_create_for_data(
          data, CAIRO_FORMAT_ARGB32, width, height, width * 4);
      if (cairo_surface_status(s) != CAIRO_STATUS_SUCCESS) {
        cairo_surface_destroy(s);
        return 0;
      }
      cairo_t *cr = cairo_create(s);
      if (cairo_status(cr) != CAIRO_STATUS_SUCCESS) {
        cairo_destroy(cr);
        cairo_surface_destroy(s);
        return 0;
      }
      cr_slots[i].surface = s;
      cr_slots[i].cr = cr;
      cr_slots[i].in_use = 1;
      return i;
    }
  }
  return 0;
}

void cr_end(int64_t id) {
  if (id > 0 && id < CR_MAX && cr_slots[id].in_use) {
    cairo_destroy(cr_slots[id].cr);
    cairo_surface_destroy(cr_slots[id].surface); // 只销毁 surface 对象，不碰数据
    memset(&cr_slots[id], 0, sizeof(CrSlot));
  }
}

#define CR_OF(id) \
  ((id) > 0 && (id) < CR_MAX && cr_slots[id].in_use ? cr_slots[id].cr : NULL)

void cr_begin_path(int64_t id) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_new_path(cr);
  }
}

void cr_close_path(int64_t id) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_close_path(cr);
  }
}

void cr_move_to(int64_t id, double x, double y) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_move_to(cr, x, y);
  }
}

void cr_line_to(int64_t id, double x, double y) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_line_to(cr, x, y);
  }
}

void cr_bezier_to(int64_t id, double x1, double y1, double x2, double y2,
                  double x3, double y3) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_curve_to(cr, x1, y1, x2, y2, x3, y3);
  }
}

void cr_arc(int64_t id, double cx, double cy, double r, double a0, double a1) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_arc(cr, cx, cy, r, a0, a1);
  }
}

void cr_fill(int64_t id) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_fill(cr);
  }
}

void cr_stroke(int64_t id) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_stroke(cr);
  }
}

void cr_fill_rect(int64_t id, double x, double y, double w, double h) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_rectangle(cr, x, y, w, h);
    cairo_fill(cr);
  }
}

void cr_stroke_rect(int64_t id, double x, double y, double w, double h) {
  cairo_t *cr = CR_OF(id);
  if (!cr) {
    return;
  }
  // 内侧描边：与 Painter 同口径（Cairo 的 stroke 是居中，不能直接用）
  double lw = cairo_get_line_width(cr);
  if (lw <= 0.0) {
    return;
  }
  if (w <= 2.0 * lw || h <= 2.0 * lw) {
    cairo_rectangle(cr, x, y, w, h);
    cairo_fill(cr);
    return;
  }
  cairo_rectangle(cr, x, y, w, lw);
  cairo_fill(cr);
  cairo_rectangle(cr, x, y + h - lw, w, lw);
  cairo_fill(cr);
  cairo_rectangle(cr, x, y + lw, lw, h - 2.0 * lw);
  cairo_fill(cr);
  cairo_rectangle(cr, x + w - lw, y + lw, lw, h - 2.0 * lw);
  cairo_fill(cr);
}

void cr_set_fill_rgba(int64_t id, int r, int g, int b, int a) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_set_source_rgba(cr, r / 255.0, g / 255.0, b / 255.0, a / 255.0);
  }
}

void cr_set_stroke_rgba(int64_t id, int r, int g, int b, int a) {
  // Cairo 只有单一 source：描边前调用方自己切 source，这里与填充同实现
  cr_set_fill_rgba(id, r, g, b, a);
}

void cr_set_line_width(int64_t id, double w) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_set_line_width(cr, w);
  }
}

void cr_save(int64_t id) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_save(cr);
  }
}

void cr_restore(int64_t id) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_restore(cr);
  }
}

void cr_translate(int64_t id, double dx, double dy) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_translate(cr, dx, dy);
  }
}

void cr_scale(int64_t id, double sx, double sy) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_scale(cr, sx, sy);
  }
}

void cr_rotate(int64_t id, double rad) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_rotate(cr, rad);
  }
}

void cr_clip_rect(int64_t id, double x, double y, double w, double h) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_rectangle(cr, x, y, w, h);
    cairo_clip(cr);
    cairo_new_path(cr);
  }
}

void cr_flush(int64_t id) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_surface_flush(cairo_get_target(cr));
  }
}
