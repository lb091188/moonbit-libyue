// Cairo 光栅器桥：在调用方的像素缓冲上建 image surface，转调 cairo 的路径/变换/
// 裁剪/填充描边。缓冲归 MoonBit（yue/render 的 Bitmap，ARGB32 预乘布局与
// CAIRO_FORMAT_ARGB32 一致），本层不拥有内存、不 free 数据。
//
// 会话式句柄：cr_begin 拿缓冲地址建 surface+cr，后续调用都带句柄，cr_end 释放。
// 缓冲在会话期间由 MoonBit 侧持有（#borrow），不会因 GC 回收。

#include <cairo.h>
#include <math.h>
#include <stdint.h>
#include <string.h>

void cr_grad_drop(int64_t pid);

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

// 取整规则与纯矩形绘制器一致：+0.5 后向下取整（floor），且**在设备空间**取整
// （CTM 里的平移/缩放会改变设备坐标，用户空间取整后再变换会落在分数像素上产生
// 抗锯齿灰边，与纯实现分岔）。矩形类绘制因此不带抗锯齿；路径绘制才走抗锯齿。
static double cr_snap(double v) {
  return floor(v + 0.5);
}

// 用户矩形 → 设备空间取整矩形；含旋转/斜切（矩阵 off-diagonal 非零）时返回 0，
// 调用方按原样绘制（取整语义对旋转矩形无意义，交给抗锯齿）。
static int cr_rect_device(cairo_t *cr, double x, double y, double w, double h,
                          double *out) {
  cairo_matrix_t m;
  cairo_get_matrix(cr, &m);
  if (m.xy != 0.0 || m.yx != 0.0) {
    return 0;
  }
  double x0 = x, y0 = y, x1 = x + w, y1 = y + h;
  cairo_user_to_device(cr, &x0, &y0);
  cairo_user_to_device(cr, &x1, &y1);
  out[0] = cr_snap(x0);
  out[1] = cr_snap(y0);
  out[2] = cr_snap(x1);
  out[3] = cr_snap(y1);
  return 1;
}

// 用设备坐标填一个整数矩形（临时换单位矩阵，裁剪区与算子不受影响）。
static void cr_fill_device(cairo_t *cr, double x0, double y0, double x1,
                           double y1) {
  if (x1 <= x0 || y1 <= y0) {
    return;
  }
  cairo_save(cr);
  cairo_identity_matrix(cr);
  cairo_rectangle(cr, x0, y0, x1 - x0, y1 - y0);
  cairo_fill(cr);
  cairo_restore(cr);
}

void cr_fill_rect(int64_t id, double x, double y, double w, double h) {
  cairo_t *cr = CR_OF(id);
  if (!cr) {
    return;
  }
  double d[4];
  if (cr_rect_device(cr, x, y, w, h, d)) {
    cr_fill_device(cr, d[0], d[1], d[2], d[3]);
  } else {
    cairo_rectangle(cr, x, y, w, h);
    cairo_fill(cr);
  }
}

// 用户点 → 设备空间取整坐标（描边的内缘用）。
static double cr_snap_dev_x(cairo_t *cr, double x, double y) {
  cairo_user_to_device(cr, &x, &y);
  return cr_snap(x);
}

static double cr_snap_dev_y(cairo_t *cr, double x, double y) {
  cairo_user_to_device(cr, &x, &y);
  return cr_snap(y);
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
  double d[4];
  if (!cr_rect_device(cr, x, y, w, h, d)) {
    cairo_rectangle(cr, x, y, w, h);
    cairo_fill(cr);
    return;
  }
  double ox0 = d[0], oy0 = d[1], ox1 = d[2], oy1 = d[3];
  if (ox1 <= ox0 || oy1 <= oy0) {
    return;
  }
  if (w <= 2.0 * lw || h <= 2.0 * lw) {
    cr_fill_device(cr, ox0, oy0, ox1, oy1);
    return;
  }
  double ix0 = cr_snap_dev_x(cr, x + lw, y);
  double ix1 = cr_snap_dev_x(cr, x + w - lw, y);
  double iy0 = cr_snap_dev_y(cr, x, y + lw);
  double iy1 = cr_snap_dev_y(cr, x, y + h - lw);
  cr_fill_device(cr, ox0, oy0, ox1, iy0);
  cr_fill_device(cr, ox0, iy1, ox1, oy1);
  if (ix0 > ox0) {
    cr_fill_device(cr, ox0, iy0, ix0, iy1);
  }
  if (ix1 < ox1) {
    cr_fill_device(cr, ix1, iy0, ox1, iy1);
  }
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
  if (!cr) {
    return;
  }
  double d[4];
  int ok = cr_rect_device(cr, x, y, w, h, d);
  if (!ok) {
    cairo_rectangle(cr, x, y, w, h);
    cairo_clip(cr);
    cairo_new_path(cr);
    return;
  }
  // 空矩形不比「已无裁剪」更紧，与纯实现同口径（直接 clip 空区域会把整窗裁光）
  if (d[2] > d[0] && d[3] > d[1]) {
    // 裁剪区是图形状态的一部分：不能用 save/restore 包（restore 会把刚设的
    // 裁剪回退掉），改临时换单位矩阵、设完立刻还原（裁剪终值存设备空间，
    // 之后 CTM 再变也不影响已设的裁剪区）。
    cairo_matrix_t keep;
    cairo_get_matrix(cr, &keep);
    cairo_identity_matrix(cr);
    cairo_rectangle(cr, d[0], d[1], d[2] - d[0], d[3] - d[1]);
    cairo_clip(cr);
    cairo_set_matrix(cr, &keep);
    cairo_new_path(cr);
  }
}

// 混合模式：按旧契约 BlendMode 的枚举序（nu::BlendMode 数值直传）映射到
// Cairo 算子。pigment 系（乘/屏/叠加/HSL 等）在 image surface 上实测生效，
// 映射表与 libyue 一一对应，无需自实现混合。
void cr_set_operator(int64_t id, int mode) {
  cairo_t *cr = CR_OF(id);
  if (!cr) {
    return;
  }
  cairo_operator_t op;
  switch (mode) {
    case 0: op = CAIRO_OPERATOR_OVER; break;
    case 1: op = CAIRO_OPERATOR_MULTIPLY; break;
    case 2: op = CAIRO_OPERATOR_SCREEN; break;
    case 3: op = CAIRO_OPERATOR_OVERLAY; break;
    case 4: op = CAIRO_OPERATOR_DARKEN; break;
    case 5: op = CAIRO_OPERATOR_LIGHTEN; break;
    case 6: op = CAIRO_OPERATOR_COLOR_DODGE; break;
    case 7: op = CAIRO_OPERATOR_COLOR_BURN; break;
    case 8: op = CAIRO_OPERATOR_SOFT_LIGHT; break;
    case 9: op = CAIRO_OPERATOR_HARD_LIGHT; break;
    case 10: op = CAIRO_OPERATOR_DIFFERENCE; break;
    case 11: op = CAIRO_OPERATOR_EXCLUSION; break;
    case 12: op = CAIRO_OPERATOR_HSL_HUE; break;
    case 13: op = CAIRO_OPERATOR_HSL_SATURATION; break;
    case 14: op = CAIRO_OPERATOR_HSL_COLOR; break;
    case 15: op = CAIRO_OPERATOR_HSL_LUMINOSITY; break;
    case 16: op = CAIRO_OPERATOR_CLEAR; break;
    case 17: op = CAIRO_OPERATOR_SOURCE; break;
    case 18: op = CAIRO_OPERATOR_IN; break;
    case 19: op = CAIRO_OPERATOR_OUT; break;
    case 20: op = CAIRO_OPERATOR_ATOP; break;
    case 21: op = CAIRO_OPERATOR_DEST_OVER; break;
    case 22: op = CAIRO_OPERATOR_DEST_IN; break;
    case 23: op = CAIRO_OPERATOR_DEST_ATOP; break;
    case 24: op = CAIRO_OPERATOR_XOR; break;
    default: return;
  }
  cairo_set_operator(cr, op);
}

// 渐变 pattern 槽：创建 → 逐 stop 追加 → apply（设为 source 并释放）。
// pattern 由 Cairo 引用计数持有，apply 后本层不再保留句柄。
#define GRAD_MAX 16

typedef struct {
  cairo_pattern_t *pat;
  int in_use;
} GradSlot;

static GradSlot grad_slots[GRAD_MAX];

static int64_t grad_take(cairo_pattern_t *pat) {
  if (pat == NULL || cairo_pattern_status(pat) != CAIRO_STATUS_SUCCESS) {
    if (pat) {
      cairo_pattern_destroy(pat);
    }
    return 0;
  }
  for (int i = 1; i < GRAD_MAX; i++) {
    if (!grad_slots[i].in_use) {
      grad_slots[i].pat = pat;
      grad_slots[i].in_use = 1;
      return i;
    }
  }
  cairo_pattern_destroy(pat);
  return 0;
}

int64_t cr_grad_linear(double x0, double y0, double x1, double y1) {
  return grad_take(cairo_pattern_create_linear(x0, y0, x1, y1));
}

int64_t cr_grad_radial(double cx, double cy, double r0, double r1) {
  return grad_take(cairo_pattern_create_radial(cx, cy, r0, cx, cy, r1));
}

void cr_grad_stop(int64_t pid, double offset, int r, int g, int b, int a) {
  if (pid > 0 && pid < GRAD_MAX && grad_slots[pid].in_use) {
    cairo_pattern_add_color_stop_rgba(grad_slots[pid].pat, offset, r / 255.0,
                                      g / 255.0, b / 255.0, a / 255.0);
  }
}

// 设为当前 source 并释放句柄；之后 set_fill_color 等可正常覆盖。
void cr_grad_apply(int64_t id, int64_t pid) {
  cairo_t *cr = CR_OF(id);
  if (cr && pid > 0 && pid < GRAD_MAX && grad_slots[pid].in_use) {
    cairo_set_source(cr, grad_slots[pid].pat);
  }
  cr_grad_drop(pid);
}

void cr_grad_drop(int64_t pid) {
  if (pid > 0 && pid < GRAD_MAX && grad_slots[pid].in_use) {
    cairo_pattern_destroy(grad_slots[pid].pat);
    memset(&grad_slots[pid], 0, sizeof(GradSlot));
  }
}

void cr_flush(int64_t id) {
  cairo_t *cr = CR_OF(id);
  if (cr) {
    cairo_surface_flush(cairo_get_target(cr));
  }
}
