// MoonBit 原生 GUI 栈渲染层的平台桩：一个文件、按平台分支，对外是 ffi 面那套
// cr_*/img_*/fsw_* 统一 API。
//
//   WM_STUB_CAIRO   → cairo 光栅 + GdkPixbuf 解码真实现（Linux）。仅
//                     scripts/prebuild.py 带 -DWM_STUB_CAIRO + pkg-config 头
//                     编进 build/librender_cairo_stub.a；moon 的 native-stub
//                     拿不到 cairo 头路径（link_configs 只有链接期字段，实测
//                     同 G0 探针），所以宏不传的那次编译必须编出空，防与
//                     .a 双定义。
//   其余平台        → 占位 no-op（Windows/mac，moon native-stub 编）。Windows
//                     的真渲染走 yue/render 的**纯 MoonBit 光栅器**（plan 矩阵
//                     定案，零第三方依赖）：运行时探针（cr_begin 返回 0）探到
//                     占位即选纯路径，占位只保链接符号不断。图片解码占位至
//                     W9 用 WIC（系统组件）实装。
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

#elif !defined(__linux__)

// 其余平台的后端随各自窗口层落地时补。

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h> // fsw_write_file 的宽字符路径路由
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

// 图片解码与文件写入在其余平台同样占位（各自后端随窗口层落地时补）。
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

// 动图（GIF）：非 Linux 平台没有 GdkPixbuf，一律「解不出动图」，组件退回静帧
int64_t img_anim_decode_file(const char *path, int len) { (void)path; (void)len; return 0; }
int img_anim_is_static(int64_t h) { (void)h; return 1; }
int img_anim_w(int64_t h) { (void)h; return 0; }
int img_anim_h(int64_t h) { (void)h; return 0; }
int img_anim_delay_ms(int64_t h) { (void)h; return 0; }
int img_anim_frame(int64_t h) { (void)h; return -1; }
int img_anim_advance(int64_t h) { (void)h; return 0; }
int img_anim_copy(int64_t h, unsigned char *out) { (void)h; (void)out; return 0; }
void img_anim_free(int64_t h) { (void)h; }
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
