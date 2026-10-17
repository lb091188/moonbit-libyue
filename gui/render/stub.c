// MoonBit 原生 GUI 栈渲染层的平台桩：一个文件、按平台分支，对外是 ffi 面那套
// cr_*/img_*/fsw_* 统一 API。
//
//   WM_STUB_CAIRO   → cairo 光栅 + GdkPixbuf 解码真实现（Linux）。仅
//                     scripts/prebuild.py 带 -DWM_STUB_CAIRO + pkg-config 头
//                     编进 build/librender_cairo_stub.a；moon 的 native-stub
//                     拿不到 cairo 头路径（link_configs 只有链接期字段，实测
//                     同 G0 探针），所以宏不传的那次编译必须编出空，防与
//                     .a 双定义。
//   其余平台        → 光栅部分占位 no-op（Windows/mac，moon native-stub 编）。
//                     Windows 的真渲染走 render 包的**纯 MoonBit 光栅器**（plan
//                     矩阵定案，零第三方依赖）：运行时探针（cr_begin 返回 0）
//                     探到占位即选纯路径，占位只保链接符号不断。图片解码则是
//                     例外——**Windows 已实装**（W9）：光栅器不负责解码，走
//                     WIC（系统组件）；macOS 仍占位，随 mac 窗口层落地。
//
// 像素缓冲归 MoonBit（yue/render 的 Bitmap，ARGB32 预乘布局与
// CAIRO_FORMAT_ARGB32 一致），本层不拥有内存、不 free 数据；PNG 编解码本体
// 在 yue/render/png.mbt（纯 MoonBit），不经本层。

#if defined(_WIN32)
// 占位分支用 fopen/memcpy 等标准名（MSVC 的「安全版」后缀只是告警不改语义），
// 必须在任何标准头之前定义才生效
#define _CRT_SECURE_NO_WARNINGS
#endif

#if defined(WM_STUB_CAIRO)

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

/* W35 line_cap / line_join / dash：Cairo 直连；纯软栅档占位（Painter state
 * 里保留字段，具体描边实现暂未吃这三个参数）。 */
void cr_set_line_cap(int64_t id, int cap) {
  cairo_t *cr = CR_OF(id);
  if (!cr) return;
  cairo_line_cap_t c = (cap == 1) ? CAIRO_LINE_CAP_ROUND
                   : (cap == 2) ? CAIRO_LINE_CAP_SQUARE
                   : CAIRO_LINE_CAP_BUTT;
  cairo_set_line_cap(cr, c);
}

void cr_set_line_join(int64_t id, int join) {
  cairo_t *cr = CR_OF(id);
  if (!cr) return;
  cairo_line_join_t j = (join == 1) ? CAIRO_LINE_JOIN_ROUND
                      : (join == 2) ? CAIRO_LINE_JOIN_BEVEL
                      : CAIRO_LINE_JOIN_MITER;
  cairo_set_line_join(cr, j);
}

void cr_set_dash(int64_t id, const double* dashes, int n, double offset) {
  cairo_t *cr = CR_OF(id);
  if (!cr) return;
  if (n <= 0) {
    cairo_set_dash(cr, NULL, 0, 0.0);
  } else {
    cairo_set_dash(cr, dashes, n, offset);
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

// 源位图（本栈 Bitmap 布局：ARGB32 预乘）的子矩形 → 目标矩形。目标矩形走
// **设备空间取整**（与 fill_rect 同口径），源矩形可为小数（像素中心采样）；
// 缩放由图案矩阵承担，混合算子与裁剪区沿用会话当前状态。
// 注意：不要把某位图画到它自己（同一块内存既当源又当目标）。
void cr_blit(int64_t id, unsigned char *src, int sw, int sh, double sx,
             double sy, double ssw, double ssh, double dx, double dy,
             double dw, double dh) {
  cairo_t *cr = CR_OF(id);
  if (!cr || src == NULL || sw < 1 || sh < 1) {
    return;
  }
  if (ssw <= 0.0 || ssh <= 0.0 || dw <= 0.0 || dh <= 0.0) {
    return;
  }
  cairo_surface_t *s = cairo_image_surface_create_for_data(
      src, CAIRO_FORMAT_ARGB32, sw, sh, sw * 4);
  if (cairo_surface_status(s) != CAIRO_STATUS_SUCCESS) {
    cairo_surface_destroy(s);
    return;
  }
  // 采样域收在源子矩形内：否则双线性会从子矩形外（邻块像素）取色——
  // 精灵图/图标拼接场景不可接受（子表面把取样空间平移到子矩形原点）。
  cairo_surface_t *sub = cairo_surface_create_for_rectangle(s, sx, sy, ssw, ssh);
  if (cairo_surface_status(sub) != CAIRO_STATUS_SUCCESS) {
    cairo_surface_destroy(sub);
    cairo_surface_destroy(s);
    return;
  }
  // 缩放映射走 CTM（translate + scale 后 set_source_surface），不走
  // `cairo_pattern_set_matrix`：后者的语义实测与直觉相反，缩放下会把内容
  // 推到目标矩形右下角并裁掉（C 层对照实验：源 120 的 (20,20)-(99,99) 方块
  // 缩到 72 时，pattern-matrix 路给出 (33,33)-(71,71)，CTM 路给出正确的
  // (12,12)-(59,59)）。子表面仍保留：它把双线性取样域收在源子矩形内。
  double d[4];
  int snapped = cr_rect_device(cr, dx, dy, dw, dh, d);
  double tx = snapped ? d[0] : dx;
  double ty = snapped ? d[1] : dy;
  double tw = snapped ? (d[2] - d[0]) : dw;
  double th = snapped ? (d[3] - d[1]) : dh;
  if (tw <= 0.0 || th <= 0.0) {
    // 取整后为空：什么都不画
  } else {
    cairo_save(cr);
    if (snapped) {
      cairo_identity_matrix(cr);
    }
    cairo_translate(cr, tx, ty);
    cairo_scale(cr, tw / ssw, th / ssh);
    cairo_set_source_surface(cr, sub, 0.0, 0.0);
    cairo_pattern_t *pat = cairo_get_source(cr);
    // 缩小走双线性避免最近邻锯齿；PAD 让边缘采样不越界成透明缝
    cairo_pattern_set_filter(pat, CAIRO_FILTER_BILINEAR);
    cairo_pattern_set_extend(pat, CAIRO_EXTEND_PAD);
    cairo_rectangle(cr, 0.0, 0.0, ssw, ssh);
    cairo_fill(cr);
    cairo_restore(cr);
  }
  // 图案由 cr 持有（cairo_get_source），不单独销毁
  cairo_surface_destroy(sub);
  cairo_surface_destroy(s);
}

// 把会话的 cairo_t 交给文本层复用：Pango 画在**调用方的上下文**上，Painter 的
// 平移与裁剪才会生效（自建 surface 画字会无视控件原点，整屏文字全跑到窗口左上角
// ——本仓真窗口截图实测）。跨静态库引用：text/stub.c 的 WM_STUB_PANGO 分支里声明同名符号。
void *cr_session_context(int64_t id) {
  return (void *)CR_OF(id);
}

// 图片解码与文件写入桥：解码走 GdkPixbuf（GTK3 的既有依赖，零新增运行期
// 依赖），输出**统一转成**本栈 Bitmap 的内部布局（ARGB32 预乘、小端 B,G,R,A），
// 由调用方给缓冲、本层不拥有内存。会话制句柄与 cairo_stub 同形（槽表）。
//
// 旧链路的 Image 是 GdkPixbufAnimation（GIF 会动）：本层静态解码仍只取首帧，
// 动图另走一组「迭代器 + 虚拟时钟」的动画接口（见下方 ImgAnim）。

#include <gdk-pixbuf/gdk-pixbuf.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define IMG_MAX 8
#define IMG_ANIM_MAX 8

static GdkPixbuf *img_slots[IMG_MAX];

static int64_t img_take(GdkPixbuf *pb) {
  if (pb == NULL) {
    return 0;
  }
  for (int i = 1; i < IMG_MAX; i++) {
    if (img_slots[i] == NULL) {
      img_slots[i] = pb;
      return i;
    }
  }
  g_object_unref(pb);
  return 0;
}

static GdkPixbuf *img_of(int64_t h) {
  if (h > 0 && h < IMG_MAX) {
    return img_slots[h];
  }
  return NULL;
}

int64_t img_decode_bytes(unsigned char *data, int len);

int64_t img_decode_bytes(unsigned char *data, int len) {
  if (data == NULL || len < 1) {
    return 0;
  }
  GdkPixbufLoader *loader = gdk_pixbuf_loader_new();
  if (loader == NULL) {
    return 0;
  }
  if (!gdk_pixbuf_loader_write(loader, data, (gsize)len, NULL) ||
      !gdk_pixbuf_loader_close(loader, NULL)) {
    g_object_unref(loader);
    return 0;
  }
  GdkPixbuf *pb = gdk_pixbuf_loader_get_pixbuf(loader);
  if (pb != NULL) {
    g_object_ref(pb);
  }
  g_object_unref(loader);
  return img_take(pb);
}

int64_t img_decode_file(const char *path, int len);

int64_t img_decode_file(const char *path, int len) {
  if (path == NULL || len < 1) {
    return 0;
  }
  char buf[4096];
  if (len >= (int)sizeof(buf)) {
    return 0;
  }
  for (int i = 0; i < len; i++) {
    buf[i] = path[i];
  }
  buf[len] = '\0';
  return img_take(gdk_pixbuf_new_from_file(buf, NULL));
}

int img_w(int64_t h) {
  GdkPixbuf *pb = img_of(h);
  return pb ? gdk_pixbuf_get_width(pb) : 0;
}

int img_h(int64_t h) {
  GdkPixbuf *pb = img_of(h);
  return pb ? gdk_pixbuf_get_height(pb) : 0;
}

// 拷进调用方缓冲：ARGB32 预乘小端（字节 B,G,R,A），预乘取整与 Bitmap::paint
// 同一口径（(c*a+127)/255），保证「编码→解码→再编码」字节稳定。
int img_copy(int64_t h, unsigned char *out);

int img_copy(int64_t h, unsigned char *out) {
  GdkPixbuf *pb = img_of(h);
  if (pb == NULL || out == NULL) {
    return 0;
  }
  int w = gdk_pixbuf_get_width(pb);
  int ht = gdk_pixbuf_get_height(pb);
  int nc = gdk_pixbuf_get_n_channels(pb);
  int rs = gdk_pixbuf_get_rowstride(pb);
  int has_a = gdk_pixbuf_get_has_alpha(pb);
  guchar *px = gdk_pixbuf_get_pixels(pb);
  if (px == NULL) {
    return 0;
  }
  for (int y = 0; y < ht; y++) {
    guchar *row = px + (gsize)y * (gsize)rs;
    unsigned char *d = out + (size_t)y * (size_t)w * 4;
    for (int x = 0; x < w; x++) {
      guchar r = row[(size_t)x * nc];
      guchar g = row[(size_t)x * nc + 1];
      guchar b = row[(size_t)x * nc + 2];
      guchar a = has_a ? row[(size_t)x * nc + 3] : 255;
      d[0] = (unsigned char)((b * a + 127) / 255);
      d[1] = (unsigned char)((g * a + 127) / 255);
      d[2] = (unsigned char)((r * a + 127) / 255);
      d[3] = a;
      d += 4;
    }
  }
  return 1;
}

// ---- 动图（GIF）：留一个迭代器句柄，按虚拟时钟逐帧前进 ----
// 旧链路的 Image 就是 GdkPixbufAnimation（GIF 会动），本层静态图仍取首帧，
// 动图改走这一组接口：解码时不前进，组件每拍 advance 一次再 copy 当前帧。
typedef struct {
  GdkPixbufAnimation *anim;
  GdkPixbufAnimationIter *iter;
  gint64 t_us;   // 虚拟时钟（微秒）：每帧按当前帧 delay 推进
  int w;
  int h;
  int index;     // 当前帧序号（从 0 起，advance 成功才 +1）
} ImgAnim;

static ImgAnim *img_anims[IMG_ANIM_MAX];

static int anim_slot(void) {
  for (int i = 1; i < IMG_ANIM_MAX; i++) {
    if (img_anims[i] == NULL) {
      return i;
    }
  }
  return -1;
}

static ImgAnim *anim_of(int64_t h) {
  if (h <= 0 || h >= IMG_ANIM_MAX) {
    return NULL;
  }
  return img_anims[h];
}

// 当前帧的 delay（毫秒）：GIF 加载器把它写在 pixbuf 的 "tDelay" 选项上，
// 读不到（静态图或加载器没给）时退回 100ms。
static int anim_delay(ImgAnim *a) {
  GdkPixbuf *pb = gdk_pixbuf_animation_iter_get_pixbuf(a->iter);
  if (pb != NULL) {
    const char *d = gdk_pixbuf_get_option(pb, "tDelay");
    if (d != NULL) {
      int ms = atoi(d);
      if (ms > 0) {
        return ms;
      }
    }
  }
  return 100;
}

int64_t img_anim_decode_file(const char *path, int len);

int64_t img_anim_decode_file(const char *path, int len) {
  if (path == NULL || len < 1 || len >= 4096) {
    return 0;
  }
  char buf[4096];
  for (int i = 0; i < len; i++) {
    buf[i] = path[i];
  }
  buf[len] = '\0';
  GdkPixbufAnimation *anim = gdk_pixbuf_animation_new_from_file(buf, NULL);
  if (anim == NULL) {
    return 0;
  }
  int slot = anim_slot();
  if (slot < 0) {
    g_object_unref(anim);
    return 0;
  }
  ImgAnim *a = g_new0(ImgAnim, 1);
  a->anim = anim;
  GTimeVal tv;
  tv.tv_sec = 0;
  tv.tv_usec = 0;
  a->iter = gdk_pixbuf_animation_get_iter(anim, &tv);
  a->t_us = 0;
  a->w = gdk_pixbuf_animation_get_width(anim);
  a->h = gdk_pixbuf_animation_get_height(anim);
  a->index = 0;
  img_anims[slot] = a;
  return (int64_t)slot;
}

int img_anim_is_static(int64_t h);

int img_anim_is_static(int64_t h) {
  ImgAnim *a = anim_of(h);
  return (a == NULL || gdk_pixbuf_animation_is_static_image(a->anim)) ? 1 : 0;
}

int img_anim_w(int64_t h) {
  ImgAnim *a = anim_of(h);
  return a == NULL ? 0 : a->w;
}

int img_anim_h(int64_t h) {
  ImgAnim *a = anim_of(h);
  return a == NULL ? 0 : a->h;
}

int img_anim_delay_ms(int64_t h) {
  ImgAnim *a = anim_of(h);
  return a == NULL ? 0 : anim_delay(a);
}

int img_anim_frame(int64_t h) {
  ImgAnim *a = anim_of(h);
  return a == NULL ? -1 : a->index;
}

// 前进一帧：把虚拟时钟推过当前帧的停留时长，再问迭代器要不要换帧。
// 返回 1 表示帧真的换了（GIF 加载器按累计时间决定，永不回绕，
// 循环与否由调用方看 `img_anim_frame` 归零判断）。
int img_anim_advance(int64_t h) {
  ImgAnim *a = anim_of(h);
  if (a == NULL) {
    return 0;
  }
  // 每次只把虚拟时钟推「一帧时长 + 1ms」（1ms 是为了不卡在整时长边界上）：
  // 时钟必须与真实时间同速，否则动画会比实际快若干倍。
  // 换不换帧由加载器判定，本层只如实回报——调用方按 `img_anim_delay_ms` 的
  // 节奏反复问即可（io-gif 的首次 advance 只把动画起点锚在当前时刻上，
  // 那一拍必然回报 0，属正常）。
  a->t_us += (gint64)anim_delay(a) * 1000 + 1000;
  GTimeVal tv;
  tv.tv_sec = (glong)(a->t_us / G_USEC_PER_SEC);
  tv.tv_usec = (glong)(a->t_us % G_USEC_PER_SEC);
  if (gdk_pixbuf_animation_iter_advance(a->iter, &tv)) {
    a->index = a->index + 1;
    return 1;
  }
  return 0;
}

int img_anim_copy(int64_t h, unsigned char *out);

int img_anim_copy(int64_t h, unsigned char *out) {
  ImgAnim *a = anim_of(h);
  if (a == NULL || out == NULL) {
    return 0;
  }
  GdkPixbuf *pb = gdk_pixbuf_animation_iter_get_pixbuf(a->iter);
  if (pb == NULL) {
    return 0;
  }
  // 逐帧尺寸可变，本层按解码时给定的整幅尺寸收：对不上就跳过这一帧
  if (gdk_pixbuf_get_width(pb) != a->w || gdk_pixbuf_get_height(pb) != a->h) {
    return 0;
  }
  int nc = gdk_pixbuf_get_n_channels(pb);
  int rs = gdk_pixbuf_get_rowstride(pb);
  int has_a = gdk_pixbuf_get_has_alpha(pb);
  guchar *px = gdk_pixbuf_get_pixels(pb);
  if (px == NULL) {
    return 0;
  }
  for (int y = 0; y < a->h; y++) {
    guchar *row = px + (gsize)y * (gsize)rs;
    unsigned char *d = out + (size_t)y * (size_t)a->w * 4;
    for (int x = 0; x < a->w; x++) {
      guchar r = row[(size_t)x * nc];
      guchar g = row[(size_t)x * nc + 1];
      guchar b = row[(size_t)x * nc + 2];
      guchar al = has_a ? row[(size_t)x * nc + 3] : 255;
      d[0] = (unsigned char)((b * al + 127) / 255);
      d[1] = (unsigned char)((g * al + 127) / 255);
      d[2] = (unsigned char)((r * al + 127) / 255);
      d[3] = al;
      d += 4;
    }
  }
  return 1;
}

void img_anim_free(int64_t h);

void img_anim_free(int64_t h) {
  ImgAnim *a = anim_of(h);
  if (a == NULL) {
    return;
  }
  g_object_unref(a->iter);
  g_object_unref(a->anim);
  g_free(a);
  img_anims[h] = NULL;
}

void img_free(int64_t h);

void img_free(int64_t h) {
  if (h > 0 && h < IMG_MAX && img_slots[h] != NULL) {
    g_object_unref(img_slots[h]);
    img_slots[h] = NULL;
  }
}

// 文件写入（PNG 出图用）。系统层落地前先在此兜底：路径按 UTF-8 字节收，
// 不做编码转换（Linux 上文件名即字节串）。
int fsw_write_file(const char *path, int plen, unsigned char *data, int dlen);

int fsw_write_file(const char *path, int plen, unsigned char *data, int dlen) {
  if (path == NULL || plen < 1 || dlen < 0) {
    return 0;
  }
  char buf[4096];
  if (plen >= (int)sizeof(buf)) {
    return 0;
  }
  for (int i = 0; i < plen; i++) {
    buf[i] = path[i];
  }
  buf[plen] = '\0';
  FILE *f = fopen(buf, "wb");
  if (f == NULL) {
    return 0;
  }
  size_t written = dlen > 0 ? fwrite(data, 1, (size_t)dlen, f) : 0;
  int ok = fclose(f) == 0 && written == (size_t)dlen;
  return ok ? 1 : 0;
}

#elif defined(WM_STUB_MAC)

// ---------------- macOS 后端（ImageIO 解码，prebuild 专编） ----------------
//
// 与 Windows 同一口径：光栅部分仍是纯 MoonBit 光栅器，`cr_*` 一族给「探测即
// 不可用」的桩（`cr_begin` 返回 0 → painter 选纯路径）；只有解码借系统能力，
// 走 ImageIO 的 `CGImageSource`（PNG/JPEG/GIF/WebP 随系统版本扩展，零第三方）。
//
// 一条与 Linux/Windows 不同的取整差（记档在 docs/zh/adaptation.md）：Quartz 的
// 合成分全在**预乘**空间里做，本层拿不到非预乘的 32bpp RGB 画布
// （CGBitmapContext 对 RGB 只认 Premultiplied*/NoneSkip*），所以像素直接以
// 预乘 BGRA 落缓冲，不再走各平台那句 `(c*a+127)/255`。字节序与语义不变，
// 只有预乘那一步的舍入归 Quartz——「编码→解码→再编码逐字节稳定」的判据在
// macOS 侧按「与 ImageIO 自身一致」看，不能与另两平台逐字节对齐。

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>

int64_t cr_begin(unsigned char *data, int width, int height) {
  (void)data; (void)width; (void)height; return 0;
}
void cr_end(int64_t id) { (void)id; }
void cr_begin_path(int64_t id) { (void)id; }
void cr_close_path(int64_t id) { (void)id; }
void cr_move_to(int64_t id, double x, double y) { (void)id; (void)x; (void)y; }
void cr_line_to(int64_t id, double x, double y) { (void)id; (void)x; (void)y; }
void cr_bezier_to(int64_t id, double a, double b, double c, double d, double e,
                  double f) {
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
void cr_set_operator(int64_t id, int mode) { (void)id; (void)mode; }
int64_t cr_grad_linear(double x0, double y0, double x1, double y1) {
  (void)x0; (void)y0; (void)x1; (void)y1; return 0;
}
int64_t cr_grad_radial(double cx, double cy, double r0, double r1) {
  (void)cx; (void)cy; (void)r0; (void)r1; return 0;
}
void cr_grad_stop(int64_t pid, double offset, int r, int g, int b, int a) {
  (void)pid; (void)offset; (void)r; (void)g; (void)b; (void)a;
}
void cr_grad_apply(int64_t id, int64_t pid) { (void)id; (void)pid; }
void cr_grad_drop(int64_t pid) { (void)pid; }
void cr_flush(int64_t id) { (void)id; }
void cr_blit(int64_t id, unsigned char *src, int sw, int sh, double sx,
             double sy, double ssw, double ssh, double dx, double dy,
             double dw, double dh) {
  (void)id; (void)src; (void)sw; (void)sh; (void)sx; (void)sy; (void)ssw;
  (void)ssh; (void)dx; (void)dy; (void)dw; (void)dh;
}

// ---- 静态图 ----

#define IMG_MAX 8

typedef struct {
  CGImageRef img; // +1 归本表，img_free 里 CGImageRelease
  int w;
  int h;
} MacImg;

static MacImg img_slots[IMG_MAX];

static int64_t img_take(CGImageRef img, int w, int h) {
  if (img == NULL || w < 1 || h < 1) {
    if (img != NULL) {
      CGImageRelease(img);
    }
    return 0;
  }
  for (int i = 1; i < IMG_MAX; i++) {
    if (img_slots[i].img == NULL) {
      img_slots[i].img = img;
      img_slots[i].w = w;
      img_slots[i].h = h;
      return (int64_t)i;
    }
  }
  CGImageRelease(img);
  return 0;
}

static CGImageSourceRef source_from_bytes(const void *data, size_t len) {
  CFDataRef d = CFDataCreate(NULL, (const UInt8 *)data, (CFIndex)len);
  if (d == NULL) {
    return NULL;
  }
  CGImageSourceRef s = CGImageSourceCreateWithData(d, NULL);
  CFRelease(d);
  return s;
}

static int64_t img_decode_with_source(CGImageSourceRef src) {
  if (src == NULL) {
    return 0;
  }
  CGImageRef img = CGImageSourceCreateImageAtIndex(src, 0, NULL);
  int64_t h = 0;
  if (img != NULL) {
    h = img_take(img, (int)CGImageGetWidth(img), (int)CGImageGetHeight(img));
  }
  CFRelease(src);
  return h;
}

int64_t img_decode_bytes(unsigned char *data, int len) {
  if (data == NULL || len < 1) {
    return 0;
  }
  return img_decode_with_source(source_from_bytes((const void *)data, (size_t)len));
}

int64_t img_decode_file(const char *path, int len) {
  if (path == NULL || len < 1) {
    return 0;
  }
  char buf[4096];
  if (len >= (int)sizeof(buf)) {
    return 0;
  }
  memcpy(buf, path, (size_t)len);
  buf[len] = '\0';
  CFStringRef p = CFStringCreateWithCString(NULL, buf, kCFStringEncodingUTF8);
  if (p == NULL) {
    return 0;
  }
  CFURLRef url = CFURLCreateWithFileSystemPath(NULL, p, kCFURLPOSIXPathStyle, false);
  CGImageSourceRef src = url != NULL ? CGImageSourceCreateWithURL(url, NULL) : NULL;
  if (url != NULL) {
    CFRelease(url);
  }
  CFRelease(p);
  return img_decode_with_source(src);
}

static CGImageRef img_of(int64_t h) {
  if (h <= 0 || h >= IMG_MAX) {
    return NULL;
  }
  return img_slots[h].img;
}

int img_w(int64_t h) {
  if (h <= 0 || h >= IMG_MAX) {
    return 0;
  }
  return img_slots[h].w;
}

int img_h(int64_t h) {
  if (h <= 0 || h >= IMG_MAX) {
    return 0;
  }
  return img_slots[h].h;
}

// 把 CGImage 画进调用方缓冲：预乘 BGRA（小端 B,G,R,A），与本栈 Bitmap 同源。
// CGBitmapContext 的数据顺序是「内存首行 = 顶行」，而用户空间原点在左下，
// 两者相互抵消，于是 CGContextDrawImage 直出正置像素（不需要翻 y）。
static int draw_cg_to_bgra(CGImageRef img, unsigned char *out, int w, int h) {
  if (img == NULL || out == NULL || w < 1 || h < 1) {
    return 0;
  }
  CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
  CGContextRef ctx = CGBitmapContextCreate(
      out, (size_t)w, (size_t)h, 8, (size_t)w * 4, cs,
      (CGBitmapInfo)(kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little));
  if (cs != NULL) {
    CGColorSpaceRelease(cs);
  }
  if (ctx == NULL) {
    return 0;
  }
  CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), img);
  CGContextFlush(ctx);
  CFRelease(ctx);
  return 1;
}

int img_copy(int64_t h, unsigned char *out) {
  if (h <= 0 || h >= IMG_MAX) {
    return 0;
  }
  return draw_cg_to_bgra(img_slots[h].img, out, img_slots[h].w, img_slots[h].h);
}

void img_free(int64_t h) {
  if (h > 0 && h < IMG_MAX && img_slots[h].img != NULL) {
    CGImageRelease(img_slots[h].img);
    img_slots[h].img = NULL;
    img_slots[h].w = 0;
    img_slots[h].h = 0;
  }
}

// ---- 动图（GIF）：macOS 本批退回静帧 ----
//
// ImageIO 给的是**原始子矩形帧**（与 WIC 同一条事实：它不替调用方合成），整幅
// 合成要逐帧读「帧矩形 + disposal」两项，而它们在 ImageIO 里的公开程度不够确定
// （disposal 不在 Apple 的 GIF 属性清单上）。没有真机可回证时硬写，错的形态是
// 「动图错位/残影」这类肉眼难判的画面问题，所以本批按平台既有降级口径走：
// `img_anim_decode_file` 给 0 = 解不出动图，`ui/gif` 组件退回**首帧静图**
// （静态解码那条路仍取首帧，图不丢）。缺口记 TODO.md「mac 平台批」，真机上用
// experiment 探针把属性键回证后再补。
int64_t img_anim_decode_file(const char *path, int len) {
  (void)path; (void)len; return 0;
}
int img_anim_is_static(int64_t h) { (void)h; return 1; }
int img_anim_w(int64_t h) { (void)h; return 0; }
int img_anim_h(int64_t h) { (void)h; return 0; }
int img_anim_delay_ms(int64_t h) { (void)h; return 0; }
int img_anim_frame(int64_t h) { (void)h; return -1; }
int img_anim_advance(int64_t h) { (void)h; return 0; }
int img_anim_copy(int64_t h, unsigned char *out) { (void)h; (void)out; return 0; }
void img_anim_free(int64_t h) { (void)h; }

// 落盘（PNG 导出用）：纯写字节，与后端无关，POSIX 路径即可。
int fsw_write_file(const char *path, int plen, unsigned char *data, int dlen) {
  if (path == NULL || plen < 1 || dlen < 0) {
    return 0;
  }
  char buf[4096];
  if (plen >= (int)sizeof(buf)) {
    return 0;
  }
  memcpy(buf, path, (size_t)plen);
  buf[plen] = '\0';
  FILE *f = fopen(buf, "wb");
  if (f == NULL) {
    return 0;
  }
  size_t written = dlen > 0 ? fwrite(data, 1, (size_t)dlen, f) : 0;
  int ok = fclose(f) == 0 && written == (size_t)dlen;
  return ok ? 1 : 0;
}

void *cr_session_context(int64_t id) {
  (void)id;
  return NULL;
}

#elif !defined(__linux__) && !defined(__APPLE__)

// 其余平台的后端随各自窗口层落地时补。

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h> // fsw_write_file 的宽字符路径路由
// 图片解码（W9）走 WIC：COM 初始化与 CoCreateInstance 在 objbase.h，GUID 常量由
// wincodec.h 声明、链接期取 windowscodecs.lib（C 模式用不了 __uuidof，同 W20f）
#include <objbase.h>
#include <wincodec.h>
#endif

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
void cr_set_line_cap(int64_t id, int cap) { (void)id; (void)cap; }
void cr_set_line_join(int64_t id, int join) { (void)id; (void)join; }
void cr_set_dash(int64_t id, const double* dashes, int n, double offset) {
  (void)id; (void)dashes; (void)n; (void)offset;
}
void cr_save(int64_t id) { (void)id; }
void cr_restore(int64_t id) { (void)id; }
void cr_translate(int64_t id, double dx, double dy) { (void)id; (void)dx; (void)dy; }
void cr_scale(int64_t id, double sx, double sy) { (void)id; (void)sx; (void)sy; }
void cr_rotate(int64_t id, double rad) { (void)id; (void)rad; }
void cr_clip_rect(int64_t id, double x, double y, double w, double h) {
  (void)id; (void)x; (void)y; (void)w; (void)h;
}
void cr_set_operator(int64_t id, int mode) { (void)id; (void)mode; }
int64_t cr_grad_linear(double x0, double y0, double x1, double y1) {
  (void)x0; (void)y0; (void)x1; (void)y1; return 0;
}
int64_t cr_grad_radial(double cx, double cy, double r0, double r1) {
  (void)cx; (void)cy; (void)r0; (void)r1; return 0;
}
void cr_grad_stop(int64_t pid, double offset, int r, int g, int b, int a) {
  (void)pid; (void)offset; (void)r; (void)g; (void)b; (void)a;
}
void cr_grad_apply(int64_t id, int64_t pid) { (void)id; (void)pid; }
void cr_grad_drop(int64_t pid) { (void)pid; }
void cr_flush(int64_t id) { (void)id; }
void cr_blit(int64_t id, unsigned char *src, int sw, int sh, double sx,
             double sy, double ssw, double ssh, double dx, double dy,
             double dw, double dh) {
  (void)id; (void)src; (void)sw; (void)sh; (void)sx; (void)sy; (void)ssw;
  (void)ssh; (void)dx; (void)dy; (void)dw; (void)dh;
}

// ---- 图片解码 ----
// Windows 走 WIC（windowscodecs.lib，系统组件，零第三方依赖），与平台矩阵定案
// 一致：渲染是纯 MoonBit 光栅器，只有解码借系统能力。macOS 仍占位（各自动图线
// 随 mac 窗口层落地）。
//
// 三条实测事实（`experiment/img_probe` 探针在真 Windows SDK 下回证）：
//  1. WIC 的 GIF 解码器给的是**原始子矩形帧**——`GetSize` 报帧矩形（实测
//     12x12）、偏移在 `/imgdesc/Left|Top`（实测 14/14），它不替调用方合成；
//     整幅合成是本层职责（Linux 侧 GdkPixbuf 的动画迭代器是替我们做了的）。
//  2. 透明索引**已由 WIC 应用**（帧像素 alpha 实测 0 与 255 两档），所以本层
//     只需「alpha==0 的像素不动画布」——GIF 的透明是「此处保留前帧」而非混合，
//     非透明像素则整像素覆盖。
//  3. `/grctlext/Delay` 单位是**厘秒**（GIF 规格），×10 才是毫秒。
#if defined(_WIN32)

#define IMG_MAX 8
#define IMG_ANIM_MAX 8
// 帧数上限只防病态文件：像素按需现解、不缓存，内存与帧数无关；但回绕时要从 0
// 重放合成，超大帧数的 GIF 会让那一拍变慢，故留一道闸。
#define IMG_MAX_FRAMES 4096

typedef struct {
  unsigned char *px; // straight BGRA（w*h*4），与 Linux 分支的 GdkPixbuf 中间态同形
  int w;
  int h;
} WicImg;

static WicImg img_slots[IMG_MAX];

// WIC 工厂：进程级单例。COM 已初始化则复用（RPC_E_CHANGED_MODE 说明别的套间
// 先初始化过，WIC 仍可用，同 W20f 图标加载）。
static IWICImagingFactory *g_wic = NULL;
static int g_wic_tried = 0;

static IWICImagingFactory *wic_factory(void) {
  if (g_wic != NULL) {
    return g_wic;
  }
  if (g_wic_tried) {
    return NULL;
  }
  g_wic_tried = 1;
  HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
  if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
    return NULL;
  }
  // 取 1 号工厂：头文件在 _WIN32_WINNT>=0x0602 时把 CLSID_WICImagingFactory
  // 宏别名到 Win8 才有的 Factory2，显式取 1 号兼容旧系统（vtable 前缀一致，
  // IID 仍用 v1）。C 模式用不了 __uuidof，GUID 常量链接期取（W20f 同款）。
  IWICImagingFactory *f = NULL;
  hr = CoCreateInstance(&CLSID_WICImagingFactory1, NULL, CLSCTX_INPROC_SERVER,
                        &IID_IWICImagingFactory, (void **)&f);
  if (FAILED(hr) || f == NULL) {
    return NULL;
  }
  g_wic = f;
  return g_wic;
}

// UTF-8 → UTF-16：WIC 的文件入口要宽字符，A 版按 ANSI 代码页解中文路径会错
// （同 W14 sys 侧「路径一律 UTF-8 进、宽字符 API 出」的口径）。调用方 free。
static wchar_t *wic_wide(const char *s, int len) {
  if (s == NULL || len < 1) {
    return NULL;
  }
  int n = MultiByteToWideChar(CP_UTF8, 0, s, len, NULL, 0);
  if (n <= 0) {
    return NULL;
  }
  wchar_t *w = (wchar_t *)malloc(((size_t)n + 1) * sizeof(wchar_t));
  if (w == NULL) {
    return NULL;
  }
  MultiByteToWideChar(CP_UTF8, 0, s, len, w, n);
  w[n] = L'\0';
  return w;
}

// PROPVARIANT → int；非整型变体给 -1。
static int wic_prop_int(PROPVARIANT *v) {
  switch (v->vt) {
  case VT_UI1: return (int)v->bVal;
  case VT_UI2: return (int)v->uiVal;
  case VT_UI4: return (int)v->ulVal;
  case VT_I1: return (int)v->cVal;
  case VT_I2: return (int)v->iVal;
  case VT_I4: return (int)v->lVal;
  default: return -1;
  }
}

static int wic_query_int(IWICMetadataQueryReader *r, const wchar_t *name, int *out) {
  PROPVARIANT v;
  PropVariantInit(&v);
  HRESULT hr = r->lpVtbl->GetMetadataByName(r, name, &v);
  int val = SUCCEEDED(hr) ? wic_prop_int(&v) : -1;
  PropVariantClear(&v);
  if (val < 0) {
    return 0;
  }
  *out = val;
  return 1;
}

// GIF 的**逻辑屏幕**尺寸（`/logscrdesc/*`）；非 GIF（PNG/JPEG…）没有这两个
// 属性，给 0 让调用方退回帧尺寸。
static void wic_screen_size(IWICBitmapDecoder *dec, UINT *w, UINT *h) {
  *w = 0;
  *h = 0;
  IWICMetadataQueryReader *r = NULL;
  if (FAILED(dec->lpVtbl->GetMetadataQueryReader(dec, &r)) || r == NULL) {
    return;
  }
  int v = 0;
  if (wic_query_int(r, L"/logscrdesc/Width", &v)) {
    *w = (UINT)v;
  }
  if (wic_query_int(r, L"/logscrdesc/Height", &v)) {
    *h = (UINT)v;
  }
  r->lpVtbl->Release(r);
}

// 一帧 → straight BGRA（w*h*4，行距 w*4）。失败给 NULL。
static unsigned char *wic_frame_bgra(IWICImagingFactory *f,
                                     IWICBitmapFrameDecode *frame, UINT *out_w,
                                     UINT *out_h) {
  IWICFormatConverter *conv = NULL;
  unsigned char *px = NULL;
  HRESULT hr = f->lpVtbl->CreateFormatConverter(f, &conv);
  if (SUCCEEDED(hr)) {
    hr = conv->lpVtbl->Initialize(conv, (IWICBitmapSource *)frame,
                                  &GUID_WICPixelFormat32bppBGRA,
                                  WICBitmapDitherTypeNone, NULL, 0.0,
                                  WICBitmapPaletteTypeCustom);
  }
  if (SUCCEEDED(hr)) {
    UINT w = 0;
    UINT h = 0;
    hr = conv->lpVtbl->GetSize(conv, &w, &h);
    if (SUCCEEDED(hr) && w > 0 && h > 0) {
      UINT stride = w * 4u;
      px = (unsigned char *)malloc((size_t)stride * (size_t)h);
      if (px != NULL) {
        if (FAILED(conv->lpVtbl->CopyPixels(conv, NULL, stride, stride * h, px))) {
          free(px);
          px = NULL;
        } else {
          *out_w = w;
          *out_h = h;
        }
      }
    }
  }
  if (conv != NULL) {
    conv->lpVtbl->Release(conv);
  }
  return px;
}

// 一帧的 GIF 元数据：帧停留（毫秒，缺省/0 统一成 100，与 Linux 分支同口径）、
// disposal 方式、帧在逻辑屏幕里的偏移与尺寸。
static void wic_frame_meta(IWICBitmapFrameDecode *frame, int *delay_ms,
                           int *disposal, int *left, int *top, UINT *fw,
                           UINT *fh) {
  *delay_ms = 100;
  *disposal = 0;
  *left = 0;
  *top = 0;
  UINT w = 0;
  UINT h = 0;
  frame->lpVtbl->GetSize(frame, &w, &h);
  *fw = w;
  *fh = h;
  IWICMetadataQueryReader *r = NULL;
  if (FAILED(frame->lpVtbl->GetMetadataQueryReader(frame, &r)) || r == NULL) {
    return;
  }
  int v = 0;
  if (wic_query_int(r, L"/grctlext/Delay", &v) && v > 0) {
    *delay_ms = v * 10; // 厘秒 → 毫秒
  }
  if (wic_query_int(r, L"/grctlext/Disposal", &v)) {
    *disposal = v;
  }
  if (wic_query_int(r, L"/imgdesc/Left", &v)) {
    *left = v;
  }
  if (wic_query_int(r, L"/imgdesc/Top", &v)) {
    *top = v;
  }
  r->lpVtbl->Release(r);
}

// 把一帧画到整幅画布：alpha==0 的像素跳过（GIF 透明 = 保留前帧），其余整像素
// 覆盖。越界像素丢弃（帧矩形允许超出逻辑屏幕）。
static void wic_draw_frame(unsigned char *canvas, UINT cw, UINT ch,
                           const unsigned char *px, UINT fw, UINT fh, int left,
                           int top) {
  for (UINT y = 0; y < fh; y++) {
    int cy = top + (int)y;
    if (cy < 0 || cy >= (int)ch) {
      continue;
    }
    for (UINT x = 0; x < fw; x++) {
      int cx = left + (int)x;
      if (cx < 0 || cx >= (int)cw) {
        continue;
      }
      const unsigned char *s = px + ((size_t)y * (size_t)fw + (size_t)x) * 4;
      if (s[3] == 0) {
        continue;
      }
      unsigned char *d = canvas + ((size_t)cy * (size_t)cw + (size_t)cx) * 4;
      d[0] = s[0];
      d[1] = s[1];
      d[2] = s[2];
      d[3] = s[3];
    }
  }
}

// disposal==2（restore to background）：把帧矩形清成全透明。
static void wic_clear_rect(unsigned char *canvas, UINT cw, UINT ch, int left,
                           int top, UINT fw, UINT fh) {
  for (UINT y = 0; y < fh; y++) {
    int cy = top + (int)y;
    if (cy < 0 || cy >= (int)ch) {
      continue;
    }
    for (UINT x = 0; x < fw; x++) {
      int cx = left + (int)x;
      if (cx < 0 || cx >= (int)cw) {
        continue;
      }
      unsigned char *d = canvas + ((size_t)cy * (size_t)cw + (size_t)cx) * 4;
      d[0] = 0;
      d[1] = 0;
      d[2] = 0;
      d[3] = 0;
    }
  }
}

// 解码第一帧（静态图入口）。GIF 按**逻辑屏幕**尺寸合成——与 Linux 的
// GdkPixbuf 一致（GdkPixbuf 的 gif 加载器给的就是屏幕尺寸的第一帧），
// 首帧是子矩形时不会被裁成帧矩形大小。
static unsigned char *wic_decode_first(IWICBitmapDecoder *dec, UINT *out_w,
                                       UINT *out_h) {
  IWICImagingFactory *f = wic_factory();
  if (f == NULL) {
    return NULL;
  }
  IWICBitmapFrameDecode *frame = NULL;
  if (FAILED(dec->lpVtbl->GetFrame(dec, 0, &frame)) || frame == NULL) {
    return NULL;
  }
  UINT fw = 0;
  UINT fh = 0;
  unsigned char *px = wic_frame_bgra(f, frame, &fw, &fh);
  int delay = 0;
  int disposal = 0;
  int left = 0;
  int top = 0;
  wic_frame_meta(frame, &delay, &disposal, &left, &top, &fw, &fh);
  frame->lpVtbl->Release(frame);
  if (px == NULL) {
    return NULL;
  }
  UINT sw = 0;
  UINT sh = 0;
  wic_screen_size(dec, &sw, &sh);
  if (sw == 0 || sh == 0) {
    sw = fw;
    sh = fh;
    left = 0;
    top = 0;
  }
  if (left == 0 && top == 0 && sw == fw && sh == fh) {
    *out_w = fw;
    *out_h = fh;
    return px; // 整幅即帧矩形，省一次拷贝
  }
  unsigned char *canvas = (unsigned char *)calloc((size_t)sw * (size_t)sh * 4, 1);
  if (canvas == NULL) {
    free(px);
    return NULL;
  }
  wic_draw_frame(canvas, sw, sh, px, fw, fh, left, top);
  free(px);
  *out_w = sw;
  *out_h = sh;
  return canvas;
}

static int64_t img_take_px(unsigned char *px, UINT w, UINT h) {
  if (px == NULL || w == 0 || h == 0) {
    free(px);
    return 0;
  }
  for (int i = 1; i < IMG_MAX; i++) {
    if (img_slots[i].px == NULL) {
      img_slots[i].px = px;
      img_slots[i].w = (int)w;
      img_slots[i].h = (int)h;
      return i;
    }
  }
  free(px);
  return 0;
}

static WicImg *img_of(int64_t h) {
  if (h > 0 && h < IMG_MAX && img_slots[h].px != NULL) {
    return &img_slots[h];
  }
  return NULL;
}

int64_t img_decode_bytes(unsigned char *data, int len) {
  if (data == NULL || len < 1) {
    return 0;
  }
  IWICImagingFactory *f = wic_factory();
  if (f == NULL) {
    return 0;
  }
  IWICStream *st = NULL;
  IWICBitmapDecoder *dec = NULL;
  unsigned char *px = NULL;
  UINT w = 0;
  UINT h = 0;
  if (SUCCEEDED(f->lpVtbl->CreateStream(f, &st)) && st != NULL &&
      SUCCEEDED(st->lpVtbl->InitializeFromMemory(st, (BYTE *)data, (DWORD)len)) &&
      SUCCEEDED(f->lpVtbl->CreateDecoderFromStream(
          f, (IStream *)st, NULL, WICDecodeMetadataCacheOnDemand, &dec)) &&
      dec != NULL) {
    px = wic_decode_first(dec, &w, &h);
  }
  if (dec != NULL) {
    dec->lpVtbl->Release(dec);
  }
  if (st != NULL) {
    st->lpVtbl->Release(st);
  }
  return img_take_px(px, w, h);
}

int64_t img_decode_file(const char *path, int len) {
  if (path == NULL || len < 1) {
    return 0;
  }
  IWICImagingFactory *f = wic_factory();
  if (f == NULL) {
    return 0;
  }
  wchar_t *w = wic_wide(path, len);
  if (w == NULL) {
    return 0;
  }
  IWICBitmapDecoder *dec = NULL;
  unsigned char *px = NULL;
  UINT iw = 0;
  UINT ih = 0;
  if (SUCCEEDED(f->lpVtbl->CreateDecoderFromFilename(
          f, w, NULL, GENERIC_READ, WICDecodeMetadataCacheOnDemand, &dec)) &&
      dec != NULL) {
    px = wic_decode_first(dec, &iw, &ih);
  }
  if (dec != NULL) {
    dec->lpVtbl->Release(dec);
  }
  free(w);
  return img_take_px(px, iw, ih);
}

int img_w(int64_t h) {
  WicImg *s = img_of(h);
  return s == NULL ? 0 : s->w;
}

int img_h(int64_t h) {
  WicImg *s = img_of(h);
  return s == NULL ? 0 : s->h;
}

// 拷进调用方缓冲：ARGB32 预乘小端（字节 B,G,R,A），预乘取整与 Bitmap::paint
// 同一口径（(c*a+127)/255）——与 Linux 分支逐字同式，保证「编码→解码→再编码」
// 字节稳定。
int img_copy(int64_t h, unsigned char *out) {
  WicImg *s = img_of(h);
  if (s == NULL || out == NULL) {
    return 0;
  }
  for (int y = 0; y < s->h; y++) {
    const unsigned char *src = s->px + (size_t)y * (size_t)s->w * 4;
    unsigned char *d = out + (size_t)y * (size_t)s->w * 4;
    for (int x = 0; x < s->w; x++) {
      unsigned a = src[3];
      d[0] = (unsigned char)((src[0] * a + 127) / 255);
      d[1] = (unsigned char)((src[1] * a + 127) / 255);
      d[2] = (unsigned char)((src[2] * a + 127) / 255);
      d[3] = (unsigned char)a;
      src += 4;
      d += 4;
    }
  }
  return 1;
}

void img_free(int64_t h) {
  if (h > 0 && h < IMG_MAX && img_slots[h].px != NULL) {
    free(img_slots[h].px);
    img_slots[h].px = NULL;
    img_slots[h].w = 0;
    img_slots[h].h = 0;
  }
}

// ---- 动图（GIF）----
// 与 Linux 分支同接口同语义：解码时留在第一帧，组件每拍 advance 一次再取当前帧。
// 像素**按需现解**（不把 N 帧全缓进内存），合成结果缓在 canvas 上——同一帧被反复
// 取（每拍重绘）时不重复解码。
typedef struct {
  IWICBitmapDecoder *dec; // 持有文件句柄，帧现解；释放时一并关掉
  int count;
  int w;
  int h;                 // 逻辑屏幕尺寸
  unsigned char *canvas; // 当前合成结果（straight BGRA）
  int canvas_frame;      // canvas 反映的帧号（-1 = 空）
  unsigned char *snap;   // disposal==3（还原到前一帧）的快照
  int64_t index;         // 单调递增的对外帧号（与 Linux 分支同口径，见 img_anim_frame）
} WicAnim;

static WicAnim *img_anims[IMG_ANIM_MAX];

static int anim_slot(void) {
  for (int i = 1; i < IMG_ANIM_MAX; i++) {
    if (img_anims[i] == NULL) {
      return i;
    }
  }
  return -1;
}

static WicAnim *anim_of(int64_t h) {
  if (h <= 0 || h >= IMG_ANIM_MAX) {
    return NULL;
  }
  return img_anims[h];
}

// 第 k 帧的元数据（不取像素，便宜）。
static int anim_frame_info(WicAnim *a, int k, int *delay_ms, int *disposal,
                           int *left, int *top, UINT *fw, UINT *fh) {
  IWICBitmapFrameDecode *fr = NULL;
  if (FAILED(a->dec->lpVtbl->GetFrame(a->dec, (UINT)k, &fr)) || fr == NULL) {
    return 0;
  }
  wic_frame_meta(fr, delay_ms, disposal, left, top, fw, fh);
  fr->lpVtbl->Release(fr);
  return 1;
}

static unsigned char *anim_frame_px(WicAnim *a, int k, UINT *fw, UINT *fh) {
  IWICImagingFactory *f = wic_factory();
  if (f == NULL) {
    return NULL;
  }
  IWICBitmapFrameDecode *fr = NULL;
  if (FAILED(a->dec->lpVtbl->GetFrame(a->dec, (UINT)k, &fr)) || fr == NULL) {
    return NULL;
  }
  unsigned char *px = wic_frame_bgra(f, fr, fw, fh);
  fr->lpVtbl->Release(fr);
  return px;
}

// 把 canvas 推进到显示帧 idx。逐帧前进走增量（只收尾上一帧的 disposal 再画本帧）；
// 跳帧/回绕则从 0 重放（disposal==3 要「画本帧之前的画布」，重放天然给出）。
static void anim_render(WicAnim *a, int idx) {
  if (a->canvas_frame == idx) {
    return;
  }
  size_t bytes = (size_t)a->w * (size_t)a->h * 4;
  int k_first;
  if (a->canvas_frame >= 0 && a->canvas_frame + 1 == idx) {
    k_first = idx; // 本帧已在画布上，只需先按上一帧的 disposal 收尾
  } else {
    memset(a->canvas, 0, bytes);
    a->canvas_frame = -1;
    k_first = 0;
  }
  for (int k = k_first; k <= idx; k++) {
    if (k > 0) {
      // 上一帧（k-1）的收尾：只要 disposal 与矩形，延时用不上
      int prev_delay = 0;
      int d = 0;
      int l = 0;
      int t = 0;
      UINT fw = 0;
      UINT fh = 0;
      if (anim_frame_info(a, k - 1, &prev_delay, &d, &l, &t, &fw, &fh)) {
        if (d == 2) {
          wic_clear_rect(a->canvas, (UINT)a->w, (UINT)a->h, l, t, fw, fh);
        } else if (d == 3) {
          memcpy(a->canvas, a->snap, bytes);
        }
      }
    }
    int delay = 0;
    int disposal = 0;
    int left = 0;
    int top = 0;
    UINT fw = 0;
    UINT fh = 0;
    if (!anim_frame_info(a, k, &delay, &disposal, &left, &top, &fw, &fh)) {
      continue;
    }
    if (disposal == 3) {
      memcpy(a->snap, a->canvas, bytes); // 要在画本帧**之前**存
    }
    UINT pw = 0;
    UINT ph = 0;
    unsigned char *px = anim_frame_px(a, k, &pw, &ph);
    if (px != NULL) {
      wic_draw_frame(a->canvas, (UINT)a->w, (UINT)a->h, px, pw, ph, left, top);
      free(px);
    }
    a->canvas_frame = k;
  }
}

int64_t img_anim_decode_file(const char *path, int len) {
  if (path == NULL || len < 1) {
    return 0;
  }
  IWICImagingFactory *f = wic_factory();
  if (f == NULL) {
    return 0;
  }
  wchar_t *w = wic_wide(path, len);
  if (w == NULL) {
    return 0;
  }
  IWICBitmapDecoder *dec = NULL;
  HRESULT hr = f->lpVtbl->CreateDecoderFromFilename(
      f, w, NULL, GENERIC_READ, WICDecodeMetadataCacheOnDemand, &dec);
  free(w);
  if (FAILED(hr) || dec == NULL) {
    return 0;
  }
  UINT count = 0;
  dec->lpVtbl->GetFrameCount(dec, &count);
  if (count < 1 || count > (UINT)IMG_MAX_FRAMES) {
    dec->lpVtbl->Release(dec);
    return 0;
  }
  UINT sw = 0;
  UINT sh = 0;
  wic_screen_size(dec, &sw, &sh);
  if (sw == 0 || sh == 0) {
    IWICBitmapFrameDecode *fr = NULL;
    if (FAILED(dec->lpVtbl->GetFrame(dec, 0, &fr)) || fr == NULL) {
      dec->lpVtbl->Release(dec);
      return 0;
    }
    fr->lpVtbl->GetSize(fr, &sw, &sh);
    fr->lpVtbl->Release(fr);
  }
  if (sw == 0 || sh == 0) {
    dec->lpVtbl->Release(dec);
    return 0;
  }
  int slot = anim_slot();
  if (slot < 0) {
    dec->lpVtbl->Release(dec);
    return 0;
  }
  WicAnim *a = (WicAnim *)calloc(1, sizeof(WicAnim));
  if (a == NULL) {
    dec->lpVtbl->Release(dec);
    return 0;
  }
  size_t bytes = (size_t)sw * (size_t)sh * 4;
  a->dec = dec;
  a->count = (int)count;
  a->w = (int)sw;
  a->h = (int)sh;
  a->canvas = (unsigned char *)calloc(bytes, 1);
  a->snap = (unsigned char *)malloc(bytes);
  a->canvas_frame = -1;
  a->index = 0;
  if (a->canvas == NULL || a->snap == NULL) {
    free(a->canvas);
    free(a->snap);
    free(a);
    dec->lpVtbl->Release(dec);
    return 0;
  }
  img_anims[slot] = a;
  return (int64_t)slot;
}

// 单帧（PNG/JPEG 或单帧 GIF）算静图：组件按静帧画，不排自转。
int img_anim_is_static(int64_t h) {
  WicAnim *a = anim_of(h);
  return (a == NULL || a->count <= 1) ? 1 : 0;
}

int img_anim_w(int64_t h) {
  WicAnim *a = anim_of(h);
  return a == NULL ? 0 : a->w;
}

int img_anim_h(int64_t h) {
  WicAnim *a = anim_of(h);
  return a == NULL ? 0 : a->h;
}

int img_anim_delay_ms(int64_t h) {
  WicAnim *a = anim_of(h);
  if (a == NULL) {
    return 0;
  }
  int delay = 100;
  int d = 0;
  int l = 0;
  int t = 0;
  UINT fw = 0;
  UINT fh = 0;
  anim_frame_info(a, (int)(a->index % (int64_t)a->count), &delay, &d, &l, &t, &fw,
                  &fh);
  return delay;
}

// 单调递增、不回绕：与 Linux 分支同口径（GdkPixbuf 的迭代器同样只加不减），
// 组件侧 `looping=false` 的「帧号回到 0」判据因此在两平台都不触发——本批不改
// 这条既有语义，见 docs/zh/adaptation.md。
int img_anim_frame(int64_t h) {
  WicAnim *a = anim_of(h);
  return a == NULL ? -1 : (int)a->index;
}

// 前进一帧：帧号 +1，显示帧取模。多帧动画每次都是真换帧（模空间里相邻两帧
// 必不同），故恒回报 1；单帧恒 0。
int img_anim_advance(int64_t h) {
  WicAnim *a = anim_of(h);
  if (a == NULL || a->count <= 1) {
    return 0;
  }
  a->index = a->index + 1;
  return 1;
}

int img_anim_copy(int64_t h, unsigned char *out) {
  WicAnim *a = anim_of(h);
  if (a == NULL || out == NULL) {
    return 0;
  }
  int idx = (int)(a->index % (int64_t)a->count);
  anim_render(a, idx);
  if (a->canvas_frame != idx) {
    return 0;
  }
  // straight BGRA → 预乘，与 img_copy 同式
  for (int y = 0; y < a->h; y++) {
    const unsigned char *src = a->canvas + (size_t)y * (size_t)a->w * 4;
    unsigned char *d = out + (size_t)y * (size_t)a->w * 4;
    for (int x = 0; x < a->w; x++) {
      unsigned al = src[3];
      d[0] = (unsigned char)((src[0] * al + 127) / 255);
      d[1] = (unsigned char)((src[1] * al + 127) / 255);
      d[2] = (unsigned char)((src[2] * al + 127) / 255);
      d[3] = (unsigned char)al;
      src += 4;
      d += 4;
    }
  }
  return 1;
}

void img_anim_free(int64_t h) {
  WicAnim *a = anim_of(h);
  if (a == NULL) {
    return;
  }
  if (a->dec != NULL) {
    a->dec->lpVtbl->Release(a->dec);
  }
  free(a->canvas);
  free(a->snap);
  free(a);
  img_anims[h] = NULL;
}

#else

// 其余平台（macOS）：各自动图线随 mac 窗口层落地时补。
int64_t img_decode_bytes(unsigned char *data, int len) {
  (void)data; (void)len; return 0;
}
int64_t img_decode_file(const char *path, int len) {
  (void)path; (void)len; return 0;
}
int img_w(int64_t h) { (void)h; return 0; }
int img_h(int64_t h) { (void)h; return 0; }
int img_copy(int64_t h, unsigned char *out) { (void)h; (void)out; return 0; }
void img_free(int64_t h) { (void)h; }

// 动图（GIF）：无后端，一律「解不出动图」，组件退回静帧
int64_t img_anim_decode_file(const char *path, int len) { (void)path; (void)len; return 0; }
int img_anim_is_static(int64_t h) { (void)h; return 1; }
int img_anim_w(int64_t h) { (void)h; return 0; }
int img_anim_h(int64_t h) { (void)h; return 0; }
int img_anim_delay_ms(int64_t h) { (void)h; return 0; }
int img_anim_frame(int64_t h) { (void)h; return -1; }
int img_anim_advance(int64_t h) { (void)h; return 0; }
int img_anim_copy(int64_t h, unsigned char *out) { (void)h; (void)out; return 0; }
void img_anim_free(int64_t h) { (void)h; }

#endif
// 落盘（PNG 导出用）：把内存里的字节写进 path（UTF-8 字节串）。这条路径
// 不依赖任何图形后端——纯 MoonBit 的 png.mbt 出字节，本函数只管写字节，
// 所以占位分支也要真实现（写死 return 0 会让图表导出在 Windows 上恒失败）。
int fsw_write_file(const char *path, int plen, unsigned char *data, int dlen) {
  if (path == NULL || plen < 1 || dlen < 0) {
    return 0;
  }
  char buf[4096];
  if (plen >= (int)sizeof(buf)) {
    return 0;
  }
  memcpy(buf, path, (size_t)plen);
  buf[plen] = '\0';
  FILE *f;
#if defined(_WIN32)
  // 宽字符路由：A 版按 ANSI 代码页解路径，中文用户名目录（%TEMP% 常见）
  // 会写到错的地方甚至失败
  int n = MultiByteToWideChar(CP_UTF8, 0, buf, -1, NULL, 0);
  if (n <= 0) {
    return 0;
  }
  wchar_t *wp = (wchar_t *)malloc(sizeof(wchar_t) * (size_t)n);
  if (wp == NULL) {
    return 0;
  }
  MultiByteToWideChar(CP_UTF8, 0, buf, -1, wp, n);
  f = _wfopen(wp, L"wb");
  free(wp);
#else
  f = fopen(buf, "wb");
#endif
  if (f == NULL) {
    return 0;
  }
  size_t written = dlen > 0 ? fwrite(data, 1, (size_t)dlen, f) : 0;
  return (fclose(f) == 0 && written == (size_t)dlen) ? 1 : 0;
}


void *cr_session_context(int64_t id) {
  (void)id;
  return 0;
}


#endif
// Linux 上 native-stub 的那次编译（无宏）落不进任何分支，编出空翻译单元——
// 真实现由 prebuild 的归档提供，这里绝不能再定义一份（双定义）。
