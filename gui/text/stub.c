// MoonBit 原生 GUI 栈文本层的平台桩：一个文件、按平台分支，对外是 `pt_*` /
// `rt_*` 那一套测量与绘制 API（会话句柄归 MoonBit 侧持有）。
//
//   WM_STUB_PANGO → Pango + Cairo 真实现（Linux）。仅 scripts/prebuild.py 带
//                   -DWM_STUB_PANGO + pkg-config 头路径编进
//                   build/libyue_text_pango.a；moon 的 native-stub 拿不到 pango
//                   头（link_configs 只有链接期字段，实测同 render/G0），所以宏
//                   不传的那次编译必须落进别的分支，防与 .a 双定义。
//   其余平台      → Windows 走 DirectWrite（系统 SDK 头 dwrite.h，native-stub
//                   直接可见，不需要 prebuild）；macOS 的 CoreText 待真机，
//                   现在是占位 no-op。运行时探测选择（AGENTS 规则 11）：探到
//                   占位即退降级，不用编译指令。

#if defined(WM_STUB_PANGO)
// Pango 文本层：测量与绘制都走 Pango（老师 libyue 在 GTK 上同样是 Pango，
// 见 nativeui/gfx/gtk/attributed_text_gtk.cc:82/128-132 的 ellipsize /
// set_width / get_pixel_size 用法）。字号按**逻辑像素**取绝对尺寸，
// 绘制目标始终是 MoonBit 自己拥有的 RGBA 缓冲（ARGB32 布局，见 yue/render）。

#include <pango/pangocairo.h>
#include <cairo.h>
#include <stdint.h>

/* 文本渲染统计（性能诊断）：Pango 把文本直接画进 cairo 表面，没有 DWrite
 * 路径的「D2D 提交 / WIC 读回混合」两段，恒 0。 */
int pt_render_stats(int64_t *calls, int64_t *d2d_us, int64_t *read_us) {
  (void)calls;
  (void)d2d_us;
  (void)read_us;
  return 1;
}
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

// ---------------------------------------------------------------------------
// 布局缓存：pt_make_layout（itemize + shaping + 字体解析）是逐帧逐段的最大头，
// 而同参数的调用每帧重复。键 = 路径标记 + 文本 + 字体四要素 + 宽约束/换行/
// 省略/对齐——同键的布局配置完全一致、复用只读（颜色在 cairo 上设、几何偏移
// 逐调用现算，都不碰布局）。上限 768，超限整表清空：与 MoonBit 侧度量缓存同
// 口径（键访问有强局部性，整清比逐条 LRU 便宜），清空只发生在内容域异常膨胀
// 的场景。单线程 UI 循环内使用，无锁。
// ---------------------------------------------------------------------------

#define PT_CACHE_SLOTS 1024 /* 2 的幂 */
#define PT_CACHE_LIMIT 768

typedef struct {
  char *key;
  PangoLayout *layout; /* 缓存持满引用 */
} PtEntry;

static PtEntry pt_cache[PT_CACHE_SLOTS];
static int pt_cache_count = 0;

static unsigned pt_key_hash(const char *s) {
  unsigned h = 5381u;
  while (*s != '\0') {
    h = h * 33u + (unsigned char)*s;
    s++;
  }
  return h;
}

static PangoLayout *pt_cache_get(const char *key) {
  unsigned i = pt_key_hash(key) & (PT_CACHE_SLOTS - 1);
  for (int k = 0; k < PT_CACHE_SLOTS; k++) {
    if (pt_cache[i].key == NULL) {
      return NULL; /* 线性探测撞到空槽即不存在 */
    }
    if (strcmp(pt_cache[i].key, key) == 0) {
      return pt_cache[i].layout;
    }
    i = (i + 1) & (PT_CACHE_SLOTS - 1);
  }
  return NULL;
}

static void pt_cache_clear(void) {
  for (int i = 0; i < PT_CACHE_SLOTS; i++) {
    if (pt_cache[i].key != NULL) {
      free(pt_cache[i].key);
      g_object_unref(pt_cache[i].layout);
      pt_cache[i].key = NULL;
      pt_cache[i].layout = NULL;
    }
  }
  pt_cache_count = 0;
}

/* 拿走 layout 的满引用；同键已存在时丢掉多余布局。 */
static void pt_cache_put(const char *key, PangoLayout *layout) {
  if (pt_cache_count >= PT_CACHE_LIMIT) {
    pt_cache_clear();
  }
  unsigned i = pt_key_hash(key) & (PT_CACHE_SLOTS - 1);
  for (int k = 0; k < PT_CACHE_SLOTS; k++) {
    if (pt_cache[i].key == NULL) {
      pt_cache[i].key = g_strdup(key);
      pt_cache[i].layout = layout;
      pt_cache_count++;
      return;
    }
    if (strcmp(pt_cache[i].key, key) == 0) {
      g_object_unref(layout);
      return;
    }
    i = (i + 1) & (PT_CACHE_SLOTS - 1);
  }
}

/* 键 = 头部参数段 + 全量文本字节（动态分配，调用方 free）。path 区分测量("m")
 * 与盒绘制("b")两条配置路径，避免头部参数撞车。 */
static char *pt_cache_key(const char *path, const char *text, int len,
                          double size, const char *family, int weight,
                          int italic, int width_int, int wrap, int ellipsize,
                          int align) {
  char head[160];
  snprintf(head, sizeof(head), "%s|%g|%s|%d|%d|%d|%d|%d|%d|", path, size,
           family != NULL ? family : "", weight, italic, width_int, wrap,
           ellipsize, align);
  if (len < 0) {
    len = text != NULL ? (int)strlen(text) : 0;
  }
  if (len < 0 || text == NULL) {
    len = 0;
  }
  size_t hl = strlen(head);
  char *key = (char *)malloc(hl + (size_t)len + 1);
  if (key == NULL) {
    return NULL;
  }
  memcpy(key, head, hl);
  if (len > 0) {
    memcpy(key + hl, text, (size_t)len);
  }
  key[hl + (size_t)len] = '\0';
  return key;
}

/* 测量与 pt_draw 共用的「无盒」取布局：命中直接用，未命中建好入库。 */
static PangoLayout *pt_plain_layout(const char *text, int len, double size,
                                    const char *family, int weight, int italic,
                                    int max_width, int wrap, int ellipsize) {
  char *key = pt_cache_key("m", text, len, size, family, weight, italic,
                           max_width, wrap, ellipsize, 0);
  if (key == NULL) {
    return NULL;
  }
  PangoLayout *layout = pt_cache_get(key);
  if (layout == NULL) {
    layout = pt_make_layout(text, len, size, family, weight, italic);
    if (layout != NULL) {
      pt_apply_width(layout, max_width, wrap, ellipsize);
      pt_cache_put(key, layout);
    }
  }
  free(key);
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
  PangoLayout *layout =
      pt_plain_layout(text, len, size, family, 400, 0, max_width, wrap,
                      ellipsize);
  if (layout == NULL) {
    return 0;
  }
  int w = 0, h = 0;
  pango_layout_get_pixel_size(layout, &w, &h);
  int baseline = pango_layout_get_baseline(layout);
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
  PangoLayout *layout =
      pt_plain_layout(text, len, size, family, 400, 0, max_width, wrap,
                      ellipsize);
  if (layout == NULL) {
    cairo_destroy(cr);
    cairo_surface_destroy(surf);
    return 0;
  }
  cairo_set_source_rgba(cr, r / 255.0, g / 255.0, b / 255.0, a / 255.0);
  cairo_move_to(cr, x, y);
  pango_cairo_show_layout(cr, layout);
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
  PangoLayout *layout =
      pt_plain_layout(text, len, size, family, weight, italic, max_width, wrap,
                      ellipsize);
  if (layout == NULL) {
    return 0;
  }
  int w = 0, h = 0;
  pango_layout_get_pixel_size(layout, &w, &h);
  int baseline = pango_layout_get_baseline(layout);
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
// 在给定 cairo_t 上画盒内文本（对齐/换行/省略口径见 pt_render_box）。
static int pt_render_box(cairo_t *cr, double x, double y, double box_w,
                         double box_h, const char *text, int len, double size,
                         const char *family, int weight, int italic, int r,
                         int g, int b, int a, int align, int valign,
                         int ellipsize, int wrap) {
  if (cr == NULL || text == NULL) {
    return 0;
  }
  // 宽约束/对齐是否交给布局由 wrapped_axis 决定，键里用同一归一化——同键的
  // 缓存布局配置必然与本次要设的一致
  int wrapped_axis = box_w > 0.0 && (wrap != 0 || ellipsize != 0);
  int width_int = wrapped_axis ? (int)(box_w + 0.5) : 0;
  int align_eff = wrapped_axis ? align : 0;
  char *key = pt_cache_key("b", text, len, size, family, weight, italic,
                           width_int, wrap, ellipsize, align_eff);
  if (key == NULL) {
    return 0;
  }
  PangoLayout *layout = pt_cache_get(key);
  if (layout == NULL) {
    layout = pt_make_layout(text, len, size, family, weight, italic);
    if (layout == NULL) {
      free(key);
      return 0;
    }
    if (wrapped_axis) {
      // 有宽度约束：换行/省略交给 Pango，水平对齐用布局对齐
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
    pt_cache_put(key, layout);
  }
  free(key);
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
  return 1;
}

int pt_draw_box(unsigned char *data, int buf_w, int buf_h, double x, double y,
                double box_w, double box_h, const char *text, int len,
                double size, const char *family, int weight, int italic, int r,
                int g, int b, int a, int align, int valign, int ellipsize,
                int wrap) {
  if (data == NULL || buf_w < 1 || buf_h < 1) {
    return 0;
  }
  cairo_surface_t *surf = cairo_image_surface_create_for_data(
      data, CAIRO_FORMAT_ARGB32, buf_w, buf_h, buf_w * 4);
  if (cairo_surface_status(surf) != CAIRO_STATUS_SUCCESS) {
    cairo_surface_destroy(surf);
    return 0;
  }
  cairo_t *cr = cairo_create(surf);
  int ok = pt_render_box(cr, x, y, box_w, box_h, text, len, size, family, weight,
                         italic, r, g, b, a, align, valign, ellipsize, wrap);
  cairo_destroy(cr);
  cairo_surface_flush(surf);
  cairo_surface_destroy(surf);
  return ok;
}

// 画在**调用方的 Cairo 会话**上：平移与裁剪由那侧的上下文带着走，控件里的
// 文本因此落在自己盒内、也不会画到邻居身上。会话号即 Painter 的 session id。
extern void *cr_session_context(int64_t id);

int pt_draw_box_cr(int64_t cr_id, double x, double y, double box_w,
                   double box_h, const char *text, int len, double size,
                   const char *family, int weight, int italic, int r, int g,
                   int b, int a, int align, int valign, int ellipsize,
                   int wrap) {
  cairo_t *cr = (cairo_t *)cr_session_context(cr_id);
  if (cr == NULL) {
    return 0;
  }
  cairo_save(cr);
  int ok = pt_render_box(cr, x, y, box_w, box_h, text, len, size, family, weight,
                         italic, r, g, b, a, align, valign, ellipsize, wrap);
  cairo_restore(cr);
  return ok;
}

// ---- 富文本会话（AttributedText 的 C 端）----
// 文本与字体名一律在入口拷进自有内存（MoonBit 交来的字节指针只在调用期有效）；
// 区间属性按 **UTF-8 字节下标** 存 [start, end) 再翻成 Pango attribute list。
// 旧链路的区间是字符区间，本栈统一字节下标（与编辑内核同口径）。
// 会话句柄与 cairo/win 侧同形：槽表 + 显式 free，不做引用计数。

#define RT_MAX 16
#define RT_MAX_ATTR 256

typedef struct {
  int start, end;
  int kind; /* 1 = 字体, 2 = 前景色 */
  char *family; /* 自有，可为 NULL */
  double size;
  int weight, italic;
  int r, g, b, a;
} RtAttr;

typedef struct {
  int used;
  char *text;
  int tlen;
  double size;
  char *family;
  int weight, italic;
  int align, valign, wrap, ellipsize;
  RtAttr attrs[RT_MAX_ATTR];
  int n_attrs;
} Rt;

static Rt rt_slots[RT_MAX];

static char *rt_strdup(const char *s, int len) {
  if (s == NULL || len <= 0) {
    return NULL;
  }
  char *out = (char *)g_malloc((gsize)len + 1);
  memcpy(out, s, (size_t)len);
  out[len] = '\0';
  return out;
}

static Rt *rt_of(int64_t h) {
  if (h > 0 && h < RT_MAX && rt_slots[h].used) {
    return &rt_slots[h];
  }
  return NULL;
}

static void rt_clear(Rt *r) {
  g_free(r->text);
  g_free(r->family);
  for (int i = 0; i < r->n_attrs; i++) {
    g_free(r->attrs[i].family);
  }
  memset(r, 0, sizeof(Rt));
}

int64_t rt_new(const char *text, int tlen, double size, const char *family,
               int flen, int weight, int italic);

int64_t rt_new(const char *text, int tlen, double size, const char *family,
               int flen, int weight, int italic) {
  for (int i = 1; i < RT_MAX; i++) {
    if (!rt_slots[i].used) {
      Rt *r = &rt_slots[i];
      memset(r, 0, sizeof(Rt));
      r->used = 1;
      r->text = rt_strdup(text, tlen);
      r->tlen = r->text ? tlen : 0;
      r->size = size;
      r->family = rt_strdup(family, flen);
      r->weight = weight;
      r->italic = italic;
      return i;
    }
  }
  return 0;
}

void rt_free(int64_t h);

void rt_free(int64_t h) {
  Rt *r = rt_of(h);
  if (r) {
    rt_clear(r);
  }
}

void rt_set_text(int64_t h, const char *text, int len);

void rt_set_text(int64_t h, const char *text, int len) {
  Rt *r = rt_of(h);
  if (!r) {
    return;
  }
  g_free(r->text);
  r->text = rt_strdup(text, len);
  r->tlen = r->text ? len : 0;
  /* 区间属性按旧语义保留（越界部分在建树时钳掉） */
}

void rt_set_font(int64_t h, const char *family, int flen, double size,
                 int weight, int italic);

void rt_set_font(int64_t h, const char *family, int flen, double size,
                 int weight, int italic) {
  Rt *r = rt_of(h);
  if (!r) {
    return;
  }
  g_free(r->family);
  r->family = rt_strdup(family, flen);
  r->size = size;
  r->weight = weight;
  r->italic = italic;
}

void rt_set_format(int64_t h, int align, int valign, int wrap, int ellipsize);

void rt_set_format(int64_t h, int align, int valign, int wrap, int ellipsize) {
  Rt *r = rt_of(h);
  if (!r) {
    return;
  }
  r->align = align;
  r->valign = valign;
  r->wrap = wrap;
  r->ellipsize = ellipsize;
}

void rt_add_color(int64_t h, int start, int end, int r, int g, int b, int a);

void rt_add_color(int64_t h, int start, int end, int r, int g, int b, int a) {
  Rt *rt = rt_of(h);
  if (!rt || rt->n_attrs >= RT_MAX_ATTR) {
    return;
  }
  RtAttr *at = &rt->attrs[rt->n_attrs++];
  memset(at, 0, sizeof(RtAttr));
  at->kind = 2;
  at->start = start;
  at->end = end;
  at->r = r;
  at->g = g;
  at->b = b;
  at->a = a;
}

void rt_add_font(int64_t h, int start, int end, const char *family, int flen,
                 double size, int weight, int italic);

void rt_add_font(int64_t h, int start, int end, const char *family, int flen,
                 double size, int weight, int italic) {
  Rt *rt = rt_of(h);
  if (!rt || rt->n_attrs >= RT_MAX_ATTR) {
    return;
  }
  RtAttr *at = &rt->attrs[rt->n_attrs++];
  memset(at, 0, sizeof(RtAttr));
  at->kind = 1;
  at->start = start;
  at->end = end;
  at->family = rt_strdup(family, flen);
  at->size = size;
  at->weight = weight;
  at->italic = italic;
}

static int rt_clamp(int v, int lo, int hi) {
  if (v < lo) {
    return lo;
  }
  if (v > hi) {
    return hi;
  }
  return v;
}

static PangoLayout *rt_build(Rt *r) {
  if (!r || !r->text) {
    return NULL;
  }
  PangoLayout *layout = pt_make_layout(r->text, r->tlen, r->size,
                                       r->family ? r->family : "", r->weight,
                                       r->italic);
  if (layout == NULL) {
    return NULL;
  }
  if (r->n_attrs == 0) {
    return layout;
  }
  PangoAttrList *list = pango_attr_list_new();
  for (int i = 0; i < r->n_attrs; i++) {
    RtAttr *a = &r->attrs[i];
    int s = rt_clamp(a->start, 0, r->tlen);
    int e = rt_clamp(a->end, s, r->tlen);
    if (e <= s) {
      continue;
    }
    PangoAttribute *pa = NULL;
    PangoAttribute *pa2 = NULL;
    if (a->kind == 2) {
      /* 前景色与前景 alpha 是两条属性（foreground_alpha_new 只收一个通道），
       * 半透明区间要两条一起插 */
      pa = pango_attr_foreground_new((guint16)(a->r * 65535 / 255),
                                     (guint16)(a->g * 65535 / 255),
                                     (guint16)(a->b * 65535 / 255));
      if (a->a != 255) {
        pa2 = pango_attr_foreground_alpha_new(
            (guint16)(a->a * 65535 / 255));
      }
    } else {
      PangoFontDescription *d = pango_font_description_new();
      if (a->family != NULL) {
        pango_font_description_set_family(d, a->family);
      }
      if (a->size > 0.0) {
        pango_font_description_set_absolute_size(d, a->size * PANGO_SCALE);
      }
      if (a->weight > 0) {
        pango_font_description_set_weight(d, (PangoWeight)a->weight);
      }
      if (a->italic != 0) {
        pango_font_description_set_style(d, PANGO_STYLE_ITALIC);
      }
      /* pango_attr_font_desc_new 会复制描述，之后即可释放本地那份 */
      pa = pango_attr_font_desc_new(d);
      pango_font_description_free(d);
    }
    if (pa != NULL) {
      pa->start_index = (guint)s;
      pa->end_index = (guint)e;
      /* pango_layout_insert_attr 要 1.52+，用 attr list 这条路（1.44 起可用） */
      pango_attr_list_insert(list, pa);
    }
    if (pa2 != NULL) {
      pa2->start_index = (guint)s;
      pa2->end_index = (guint)e;
      pango_attr_list_insert(list, pa2);
    }
  }
  pango_layout_set_attributes(layout, list);
  pango_attr_list_unref(list);
  return layout;
}

// 量尺寸：box_w > 0 时作为宽度约束（换行/省略的判定同 pt_apply_width）
int rt_measure(int64_t h, double box_w, int32_t *out_w, int32_t *out_h,
               int32_t *out_baseline);

int rt_measure(int64_t h, double box_w, int32_t *out_w, int32_t *out_h,
               int32_t *out_baseline) {
  Rt *r = rt_of(h);
  if (!r || out_w == NULL || out_h == NULL || out_baseline == NULL) {
    return 0;
  }
  PangoLayout *layout = rt_build(r);
  if (layout == NULL) {
    return 0;
  }
  pt_apply_width(layout, (int)(box_w > 0.0 ? box_w : 0.0), r->wrap,
                 r->ellipsize);
  int w = 0, bh = 0;
  pango_layout_get_pixel_size(layout, &w, &bh);
  int baseline = pango_layout_get_baseline(layout);
  g_object_unref(layout);
  *out_w = w;
  *out_h = bh;
  int bl = baseline / PANGO_SCALE;
  if (baseline % PANGO_SCALE >= PANGO_SCALE / 2) {
    bl += 1;
  }
  *out_baseline = bl;
  return 1;
}

// 绘制：盒内对齐与 pt_draw_box 同一套算法；r/g/b/a 是**基准色**，
// 被前景色区间覆盖的部分由 Pango 属性决定。
int rt_draw(int64_t h, unsigned char *data, int buf_w, int buf_h, double x,
            double y, double box_w, double box_h, int r0, int g0, int b0,
            int a0);

// 富文本画在给定 cairo_t 上（对齐/换行/省略口径同 rt_draw）。
static int rt_render(Rt *r, cairo_t *cr, double x, double y, double box_w,
                     double box_h, int r0, int g0, int b0, int a0) {
  if (r == NULL || cr == NULL) {
    return 0;
  }
  PangoLayout *layout = rt_build(r);
  if (layout == NULL) {
    return 0;
  }
  int wrapped_axis = 0;
  if (box_w > 0.0 && (r->wrap != 0 || r->ellipsize != 0)) {
    wrapped_axis = 1;
    pango_layout_set_width(layout, (int)(box_w * PANGO_SCALE + 0.5));
    if (r->wrap != 0) {
      pango_layout_set_wrap(layout, PANGO_WRAP_WORD_CHAR);
    }
    PangoAlignment pa = PANGO_ALIGN_LEFT;
    if (r->align == 1) {
      pa = PANGO_ALIGN_CENTER;
    } else if (r->align == 2) {
      pa = PANGO_ALIGN_RIGHT;
    }
    pango_layout_set_alignment(layout, pa);
  }
  if (r->ellipsize != 0) {
    pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END);
  }
  int lw = 0, lh = 0;
  pango_layout_get_pixel_size(layout, &lw, &lh);
  double dx = 0.0;
  if (box_w > 0.0 && wrapped_axis == 0) {
    double slack = box_w - (double)lw;
    if (slack > 0.0) {
      dx = r->align == 1 ? slack / 2.0 : (r->align == 2 ? slack : 0.0);
    }
  }
  double dy = 0.0;
  if (box_h > 0.0 && r->valign != 0) {
    double slack = box_h - (double)lh;
    if (slack > 0.0) {
      dy = r->valign == 1 ? slack / 2.0 : slack;
    }
  }
  cairo_set_source_rgba(cr, r0 / 255.0, g0 / 255.0, b0 / 255.0, a0 / 255.0);
  cairo_move_to(cr, x + dx, y + dy);
  pango_cairo_show_layout(cr, layout);
  g_object_unref(layout);
  return 1;
}

int rt_draw(int64_t h, unsigned char *data, int buf_w, int buf_h, double x,
            double y, double box_w, double box_h, int r0, int g0, int b0,
            int a0) {
  Rt *r = rt_of(h);
  if (!r || data == NULL || buf_w < 1 || buf_h < 1) {
    return 0;
  }
  cairo_surface_t *surf = cairo_image_surface_create_for_data(
      data, CAIRO_FORMAT_ARGB32, buf_w, buf_h, buf_w * 4);
  if (cairo_surface_status(surf) != CAIRO_STATUS_SUCCESS) {
    cairo_surface_destroy(surf);
    return 0;
  }
  cairo_t *cr = cairo_create(surf);
  int ok = rt_render(r, cr, x, y, box_w, box_h, r0, g0, b0, a0);
  cairo_destroy(cr);
  cairo_surface_flush(surf);
  cairo_surface_destroy(surf);
  return ok;
}

// 富文本画在**调用方的 Cairo 会话**上：控件原点与裁剪生效（组件里的富文本
// 标题、Markdown 段落都走这条，否则文字会跑到窗口左上角）。
int rt_draw_cr(int64_t cr_id, int64_t h, double x, double y, double box_w,
               double box_h, int r0, int g0, int b0, int a0) {
  extern void *cr_session_context(int64_t id);
  cairo_t *cr = (cairo_t *)cr_session_context(cr_id);
  if (cr == NULL) {
    return 0;
  }
  Rt *r = rt_of(h);
  if (!r) {
    return 0;
  }
  cairo_save(cr);
  int ok = rt_render(r, cr, x, y, box_w, box_h, r0, g0, b0, a0);
  cairo_restore(cr);
  return ok;
}

// ---- 字体族枚举与可用性 ----
// 整表构建一次，族名按 '\n' 拼进这份进程内缓存；MoonBit 只能逐字节读
// （本工具链不能把可写缓冲交给 C，见 adaptation「G3b」条那条 SIGSEGV）。
// 排序 + 相邻去重：fontconfig 的枚举次序随装载顺序变化，且同一族会带多个
// locale 名，不处理的话同机两次跑拿到的表不一样，测试就写不了。
static char *pt_fam_buf = NULL;
static int pt_fam_len = -1;

static void pt_fam_build(void) {
  if (pt_fam_len >= 0) {
    return;
  }
  pt_fam_len = 0;
  PangoFontMap *fm = pango_cairo_font_map_get_default();
  if (fm == NULL) {
    return;
  }
  PangoFontFamily **fams = NULL;
  int n = 0;
  pango_font_map_list_families(fm, &fams, &n);
  if (fams == NULL || n <= 0) {
    g_free(fams);
    return;
  }
  for (int i = 0; i < n; i++) {
    for (int j = i + 1; j < n; j++) {
      const char *a = pango_font_family_get_name(fams[i]);
      const char *b = pango_font_family_get_name(fams[j]);
      if (b != NULL && g_strcmp0(a, b) > 0) {
        PangoFontFamily *t = fams[i];
        fams[i] = fams[j];
        fams[j] = t;
      }
    }
  }
  GString *out = g_string_new(NULL);
  const char *prev = NULL;
  for (int i = 0; i < n; i++) {
    const char *name = pango_font_family_get_name(fams[i]);
    if (name == NULL || name[0] == '\0') {
      continue;
    }
    if (prev != NULL && g_strcmp0(prev, name) == 0) {
      continue;
    }
    if (out->len > 0) {
      g_string_append_c(out, '\n');
    }
    g_string_append(out, name);
    prev = name;
  }
  g_free(fams);
  pt_fam_len = (int)out->len;
  pt_fam_buf = g_string_free(out, FALSE);
}

int pt_families_len(void) {
  pt_fam_build();
  return pt_fam_len;
}

int pt_families_byte(int index) {
  pt_fam_build();
  if (index < 0 || index >= pt_fam_len) {
    return 0;
  }
  return (int)(guchar)pt_fam_buf[index];
}

// 族名可用性：与枚举表逐行比 ASCII 大小写不敏感（fontconfig/Pango 侧同口径，
// CSS 的 fontconfig 族名匹配本来不区分大小写）。1 = 表里有这个族。
int pt_family_available(const char *name, int len) {
  pt_fam_build();
  if (name == NULL || len <= 0 || pt_fam_len <= 0) {
    return 0;
  }
  int i = 0;
  while (i < pt_fam_len) {
    int j = i;
    while (j < pt_fam_len && pt_fam_buf[j] != '\n') {
      j++;
    }
    if (j - i == len && g_ascii_strncasecmp(pt_fam_buf + i, name, (gsize)len) == 0) {
      return 1;
    }
    i = j + 1;
  }
  return 0;
}

/* 帧级文本批的 Pango 侧：Pango 逐段即绘即混、没有攒批窗口，冲刷是空操作。
 * 刻意定义在本分支内而不是文件末尾：Linux 上这个文件被编两次（prebuild 带
 * -DWM_STUB_PANGO 编进 build/libyue_text_pango.a、moon 的 native-stub 不带宏
 * 再编一次），写在分支外（如 #ifndef _WIN32）两边各出一份，链接期即
 * multiple definition。 */
int pt_flush(void) {
  return 0;
}

int pt_flush_if_overlap(int x0, int y0, int x1, int y1) {
  (void)x0;
  (void)y0;
  (void)x1;
  (void)y1;
  return 0;
}

void pt_set_batching(int on) {
  (void)on;
}

#elif defined(_WIN32)

// Windows 的 DirectWrite 实现住在同包的 dwrite_text.cpp：dwrite.h 在本 SDK 是
// C++ 专属（DWRITE_MAKE_OPENTYPE_TAG 用了 static_cast，C TU 里编不过，实测
// C2275/C2065），而 moon 的 native-stub 认 .cpp（实测）。本分支故意留空——
// Windows 的 pt_*/rt_* 由那个 TU 提供，防双定义。
#elif defined(WM_STUB_MAC)

// ---------------- macOS 后端（CoreText，prebuild 专编） ----------------
//
// CoreText 是纯 C API，这一支没有 Objective-C 语法（prebuild 统一按 ObjC 编，
// 纯 C 源码同样过）。与 Pango/DWrite 的**根本差别**：CoreText 只排「一行」
// （CTLine），折行、省略号、对齐、行盒累加都不提供，所以本层自带一个小段落
// 排版器：
//   UTF-8 解码成码点数组 → 属性段（rt_* 的区间色/区间字体按「后设覆盖先设」
//   落到每个码点）→ 按词（CJK 按字、含超长词按字符断）贪心断行 → 每行一个
//   CTLine。
//
// 三条与另两平台对齐的口径：
// - 成功一律返回**恰好 1**（MoonBit 按 `!= 1` 判失败）；入参非法返回 0 且不写
//   出参。
// - 字号是**逻辑像素**：CGBitmapContext 一行一像素、文字矩阵不平铺 dpi，
//   CTFont 的 point size 在这里就是像素数，与 Pango 的 `size * PANGO_SCALE`
//   和 DWrite 的 DIP 同档。
// - (x,y) 是布局盒**左上角**、y 向下；而 CGContext 的用户空间原点在左下，
//   所以落笔前换一次：`y_ctx = buf_h - y_top - ascent`。不平铺 CTM（平铺会把
//   字面画倒），也不走「离屏 + 手工 over」的 Windows 路线——目标缓冲的字节
//   布局（预乘 BGRA 小端）与 CGBitmapContext 逐字节同构，CTLineDraw 的默认
//   Normal 混合就是 source-over，可以直接画进去。
// - 反锯齿固定灰度档（关 font smoothing）：与 DWrite 侧「ClearType 次像素在
//   透明底上出彩边」同一条避让。
//
// 行高 K 地板（LINE_HEIGHT_K=1.36）在 MoonBit 共享层，**不在这里**：C 侧只给
// 引擎自然行盒，套地板由 text.mbt 的 line_height_* 负责（回归断言钉死）。

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>

#define PT_MAX_LINES 512
#define PT_MAX_SEGS 1024
#define PT_MAX_RANGES 64

// ---- 码点与样式 ----

typedef struct {
  uint32_t cp; // 码点（无效字节按 U+FFFD）
  int b0;      // 在本串里的字节区间 [b0,b1)
  int b1;
} PtChar;

typedef struct {
  CTFontRef font; // +1，随段落下架释放
  CGColorRef color;
} PtStyle;

typedef struct {
  int c0;
  int c1;
  int style;
} PtSeg;

typedef struct {
  int c0;
  int c1;
  double width;
  double ascent;
  double descent;
  double leading;
} PtLine;

typedef struct {
  PtChar *chars;
  int nchar;
  PtStyle *styles;
  int nstyle;
  int style_cap;
  PtSeg *segs;
  int nseg;
  PtLine *lines;
  int nline;
  double total_w;
  double total_h;
  double baseline;
} PtPara;

// UTF-8 → 码点数组；非法字节给 U+FFFD 并前进一字节（不吞后面合法的续字节）
static int pt_decode(const char *s, int len, PtChar **out) {
  PtChar *arr = (PtChar *)calloc((size_t)len + 1u, sizeof(PtChar));
  if (arr == NULL || s == NULL || len < 0) {
    return 0;
  }
  int n = 0;
  int i = 0;
  while (i < len) {
    unsigned char c = (unsigned char)s[i];
    uint32_t cp = 0xFFFDu;
    int adv = 1;
    if (c < 0x80u) {
      cp = c;
    } else if ((c & 0xE0u) == 0xC0u && i + 1 < len &&
               ((unsigned char)s[i + 1] & 0xC0u) == 0x80u) {
      cp = ((uint32_t)(c & 0x1Fu) << 6) | (uint32_t)((unsigned char)s[i + 1] & 0x3Fu);
      adv = 2;
    } else if ((c & 0xF0u) == 0xE0u && i + 2 < len &&
               ((unsigned char)s[i + 1] & 0xC0u) == 0x80u &&
               ((unsigned char)s[i + 2] & 0xC0u) == 0x80u) {
      cp = ((uint32_t)(c & 0x0Fu) << 12) |
           ((uint32_t)((unsigned char)s[i + 1] & 0x3Fu) << 6) |
           (uint32_t)((unsigned char)s[i + 2] & 0x3Fu);
      adv = 3;
    } else if ((c & 0xF8u) == 0xF0u && i + 3 < len &&
               ((unsigned char)s[i + 1] & 0xC0u) == 0x80u &&
               ((unsigned char)s[i + 2] & 0xC0u) == 0x80u &&
               ((unsigned char)s[i + 3] & 0xC0u) == 0x80u) {
      cp = ((uint32_t)(c & 0x07u) << 18) |
           ((uint32_t)((unsigned char)s[i + 1] & 0x3Fu) << 12) |
           ((uint32_t)((unsigned char)s[i + 2] & 0x3Fu) << 6) |
           (uint32_t)((unsigned char)s[i + 3] & 0x3Fu);
      adv = 4;
    }
    arr[n].cp = cp;
    arr[n].b0 = i;
    arr[n].b1 = i + adv;
    n++;
    i += adv;
  }
  *out = arr;
  return n;
}

// ---- 字体 ----

static CFStringRef pt_cfstr(const char *s, int len) {
  if (s == NULL) {
    return NULL;
  }
  if (len < 0) {
    len = (int)strlen(s);
  }
  return CFStringCreateWithBytes(NULL, (const UInt8 *)s, (CFIndex)len,
                                 kCFStringEncodingUTF8, false);
}

// CSS 口径 100..900（0 = 缺省 400）→ CTFont。CoreText 的符号特征只有「粗/斜」
// 两档，细体与半粗拿不到真 weight，退化成常规/粗体（记档在 adaptation）。
static CTFontRef pt_font(const char *family, int flen, double size, int weight,
                         int italic) {
  CTFontRef base = NULL;
  CFStringRef name = NULL;
  int has_family = family != NULL && flen != 0 &&
                   !(flen == 1 && family[0] == '\0');
  if (has_family) {
    name = pt_cfstr(family, flen);
  }
  if (name != NULL) {
    base = CTFontCreateWithName(name, (CGFloat)size, NULL);
    CFRelease(name);
  }
  if (base == NULL) {
    // 空族名 = 跟随系统缺省（与 DWrite 把 L"" 直递同一口径；从字体集合里
    // 取「第一个族」不是系统缺省，会差两三像素——Windows 侧同条警告）
    base = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, (CGFloat)size,
                                         NULL);
  }
  if (base == NULL) {
    base = CTFontCreateWithName(CFSTR("Helvetica"), (CGFloat)size, NULL);
  }
  if (base == NULL) {
    return NULL;
  }
  CFOptionFlags want = 0;
  if (weight >= 600) {
    want |= kCTFontBoldTrait;
  }
  if (italic != 0) {
    want |= kCTFontItalicTrait;
  }
  CTFontRef tuned = NULL;
  if (want != 0) {
    CFOptionFlags cur = CTFontGetSymbolicTraits(base);
    if ((cur & want) != want) {
      tuned = CTFontCreateCopyWithSymbolicTraits(
          base, 0.0, NULL, want,
          (CFOptionFlags)(kCTFontBoldTrait | kCTFontItalicTrait));
    }
  }
  if (tuned != NULL) {
    CFRelease(base);
    return tuned;
  }
  return base;
}

static CGColorRef pt_color(int r, int g, int b, int a) {
  CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
  CGFloat comps[4] = {(CGFloat)r / 255.0, (CGFloat)g / 255.0,
                      (CGFloat)b / 255.0, (CGFloat)a / 255.0};
  CGColorRef c = CGColorCreate(cs, comps);
  if (cs != NULL) {
    CGColorSpaceRelease(cs);
  }
  return c;
}

// ---- 排版器 ----

static void pt_para_free(PtPara *p) {
  if (p == NULL) {
    return;
  }
  free(p->chars);
  for (int i = 0; i < p->nstyle; i++) {
    if (p->styles[i].font != NULL) {
      CFRelease(p->styles[i].font);
    }
    if (p->styles[i].color != NULL) {
      CGColorRelease(p->styles[i].color);
    }
  }
  free(p->styles);
  free(p->segs);
  free(p->lines);
  free(p);
}

// 一个样式槽（同 font/color 指针即同一条，rt 的重复区间因此不会撑爆表）
static int pt_style_add(PtPara *p, CTFontRef font, CGColorRef color) {
  for (int i = 0; i < p->nstyle; i++) {
    if (p->styles[i].font == font && p->styles[i].color == color) {
      return i;
    }
  }
  if (p->nstyle >= p->style_cap) {
    int cap = p->style_cap == 0 ? 16 : p->style_cap * 2;
    PtStyle *ns = (PtStyle *)realloc(p->styles, (size_t)cap * sizeof(PtStyle));
    if (ns == NULL) {
      return -1;
    }
    p->styles = ns;
    p->style_cap = cap;
  }
  if (font != NULL) {
    CFRetain(font);
  }
  if (color != NULL) {
    CGColorRetain(color);
  }
  p->styles[p->nstyle].font = font;
  p->styles[p->nstyle].color = color;
  return p->nstyle++;
}

// 码点样式表：初值 0（默认样式），区间按顺序覆写 → 天然「后设覆盖先设」
static void pt_apply_range(int *si, int n, int c0, int c1, int style) {
  if (c0 < 0) {
    c0 = 0;
  }
  if (c1 > n) {
    c1 = n;
  }
  for (int i = c0; i < c1; i++) {
    si[i] = style;
  }
}

// 码点数组 → CFString（自己配 UTF-16 代理对：CFStringCreateWithCharacters 只
// 认 16 位单元，把 UInt32 数组强转进去会按两字节读，非 BMP 字必错）
static CFStringRef pt_cfstr_cps(const uint32_t *cps, int n) {
  if (n <= 0) {
    return CFStringCreateWithCString(NULL, "", kCFStringEncodingUTF8);
  }
  UniChar *buf = (UniChar *)malloc((size_t)(2 * n + 1) * sizeof(UniChar));
  if (buf == NULL) {
    return NULL;
  }
  int k = 0;
  for (int i = 0; i < n; i++) {
    uint32_t c = cps[i];
    if (c <= 0xFFFFu) {
      buf[k++] = (UniChar)c;
    } else {
      c -= 0x10000u;
      buf[k++] = (UniChar)(0xD800u + (c >> 10));
      buf[k++] = (UniChar)(0xDC00u + (c & 0x3FFu));
    }
  }
  CFStringRef s = CFStringCreateWithCharacters(NULL, buf, (CFIndex)k);
  free(buf);
  return s;
}

static CFStringRef pt_ellipsis(void) {
  static const UniChar e = 0x2026u; // '…'
  return CFStringCreateWithCharacters(NULL, &e, 1);
}

// [c0,c1) 的码点 → CTLine（属性按 segs 切段挂上）
static CTLineRef pt_line_create(PtPara *p, int with_ellipsis, int c0, int c1) {
  if (c1 <= c0 && !with_ellipsis) {
    return NULL;
  }
  CFMutableAttributedStringRef str = CFAttributedStringCreateMutable(
      NULL, (CFIndex)(c1 - c0) + 8);
  if (str == NULL) {
    return NULL;
  }
  for (int i = 0; i < p->nseg; i++) {
    PtSeg *sg = &p->segs[i];
    int a = sg->c0 > c0 ? sg->c0 : c0;
    int b = sg->c1 < c1 ? sg->c1 : c1;
    if (b <= a) {
      continue;
    }
    uint32_t *cps = (uint32_t *)malloc((size_t)(b - a) * sizeof(uint32_t));
    if (cps == NULL) {
      continue;
    }
    for (int k = 0; k < b - a; k++) {
      cps[k] = p->chars[a + k].cp;
    }
    CFStringRef piece = pt_cfstr_cps(cps, b - a);
    free(cps);
    if (piece == NULL) {
      continue;
    }
    CFIndex at = CFStringGetLength(str);
    CFAttributedStringReplaceString(str, at, at, piece);
    CFRelease(piece);
    PtStyle *st = &p->styles[sg->style < p->nstyle ? sg->style : 0];
    CFIndex piece_len = CFStringGetLength(str) - at;
    if (st->font != NULL && piece_len > 0) {
      CFAttributedStringSetAttribute(str, at, piece_len, kCTFontAttributeName,
                                     st->font);
    }
    if (st->color != NULL && piece_len > 0) {
      CFAttributedStringSetAttribute(str, at, piece_len,
                                     kCTForegroundColorAttributeName, st->color);
    }
  }
  // 省略号接在截断段之后（挂默认样式，与 Pango 的观察一致）
  if (with_ellipsis) {
    CFIndex at = CFStringGetLength(str);
    CFStringRef e = pt_ellipsis();
    if (e != NULL) {
      CFAttributedStringReplaceString(str, at, at, e);
      PtStyle *st = p->nstyle > 0 ? &p->styles[0] : NULL;
      if (st != NULL && st->font != NULL) {
        CFAttributedStringSetAttribute(str, at, 1, kCTFontAttributeName,
                                       st->font);
      }
      if (st != NULL && st->color != NULL) {
        CFAttributedStringSetAttribute(str, at, 1,
                                       kCTForegroundColorAttributeName,
                                       st->color);
      }
      CFRelease(e);
    }
  }
  CTLineRef line = CTLineCreateWithAttributedString(str);
  CFRelease(str);
  return line;
}

// 宽度（不给画就顺手释放）
static double pt_range_width(PtPara *p, int c0, int c1, int with_ellipsis) {
  CTLineRef l = pt_line_create(p, with_ellipsis, c0, c1);
  if (l == NULL) {
    return 0.0;
  }
  double w = CTLineGetTypographicBounds(l, NULL, NULL, NULL);
  CFRelease(l);
  return w;
}

static int pt_is_cjk(uint32_t cp) {
  return (cp >= 0x2E80u && cp <= 0x9FFFu) || (cp >= 0xAC00u && cp <= 0xD7AFu) ||
         (cp >= 0xF900u && cp <= 0xFAFFu) || (cp >= 0xFF00u && cp <= 0xFF60u) ||
         (cp >= 0x20000u && cp <= 0x2FA1Fu);
}

// 断行机会点：词后、空格后、CJK 字后（与 Pango 的 WORD_CHAR 同档）
static int pt_unit_end(PtPara *p, int start) {
  uint32_t cp = p->chars[start].cp;
  if (cp == '\n' || cp == '\r') {
    return start + 1;
  }
  if (cp == ' ' || cp == 0x3000u) {
    int i = start;
    while (i < p->nchar && p->chars[i].cp == ' ') {
      i++;
    }
    return i > start ? i : start + 1;
  }
  if (pt_is_cjk(cp)) {
    return start + 1;
  }
  int i = start;
  while (i < p->nchar) {
    uint32_t c = p->chars[i].cp;
    if (c == '\n' || c == '\r' || c == ' ' || c == 0x3000u || pt_is_cjk(c)) {
      break;
    }
    i++;
  }
  return i > start ? i : start + 1;
}

// 排版：max_width<=0 不约束；wrap=0 单行（可溢出），wrap=1 断行；
// ellipsize=1 且 wrap=0 时尾端省略号截断（与「无高度上限就不截多行」的
// Pango/DWrite 观察同档）。
static void pt_layout(PtPara *p, int max_width, int ellipsize, int wrap) {
  p->nline = 0;
  p->total_w = 0.0;
  p->total_h = 0.0;
  p->baseline = 0.0;
  if (p->nchar == 0) {
    return;
  }
  if (p->lines == NULL) {
    p->lines = (PtLine *)calloc(PT_MAX_LINES, sizeof(PtLine));
    if (p->lines == NULL) {
      return;
    }
  }
  double lim = max_width > 0 ? (double)max_width : 0.0;
  int i = 0;
  while (i < p->nchar && p->nline < PT_MAX_LINES) {
    if (!wrap) {
      // 单行：到第一个硬换行为止；要省略就把整行截到「加得上省略号」的最长前缀
      int hard = i;
      while (hard < p->nchar && p->chars[hard].cp != '\n' &&
             p->chars[hard].cp != '\r') {
        hard++;
      }
      int cut = hard;
      int ell = 0;
      if (lim > 0.0 && ellipsize && pt_range_width(p, i, hard, 0) > lim) {
        int lo = i;
        int hi = hard;
        cut = i;
        while (lo <= hi) {
          int mid = lo + (hi - lo) / 2;
          if (pt_range_width(p, i, mid, 1) <= lim) {
            cut = mid;
            lo = mid + 1;
          } else {
            hi = mid - 1;
          }
        }
        ell = 1;
      }
      CTLineRef l = pt_line_create(p, ell, i, cut);
      if (l != NULL) {
        double asc = 0, desc = 0, lead = 0;
        double w = CTLineGetTypographicBounds(l, &asc, &desc, &lead);
        CFRelease(l);
        p->lines[p->nline].c0 = i;
        p->lines[p->nline].c1 = cut;
        p->lines[p->nline].width = w;
        p->lines[p->nline].ascent = asc;
        p->lines[p->nline].descent = desc;
        p->lines[p->nline].leading = lead;
        p->nline++;
      }
      i = hard;
      if (i < p->nchar && p->chars[i].cp == '\r') {
        i++;
      }
      if (i < p->nchar && p->chars[i].cp == '\n') {
        i++;
      }
      continue;
    }
    // 折行档：贪心装「断行单元」；单元本身超宽且行首空着时按字符断
    // （Pango 的 WORD_CHAR 与 DWrite 的 WORD_WRAPPING_WRAP 都有这条）
    int line_start = i;
    int line_end = i;
    double line_w = 0.0;
    while (i < p->nchar && p->nline < PT_MAX_LINES - 1) {
      if (p->chars[i].cp == '\n' || p->chars[i].cp == '\r') {
        break;
      }
      int uend = pt_unit_end(p, i);
      double uw = pt_range_width(p, i, uend, 0);
      if (lim > 0.0 && line_end > line_start && line_w + uw > lim) {
        break;
      }
      if (lim > 0.0 && line_end == line_start && uw > lim && uend > i + 1) {
        int one = i + 1;
        double ow = pt_range_width(p, i, one, 0);
        line_end = one;
        line_w += ow;
        i = one;
        continue;
      }
      line_end = uend;
      line_w += uw;
      i = uend;
    }
    if (line_end <= line_start) {
      line_end = i > line_start ? i : line_start + 1;
    }
    CTLineRef l = pt_line_create(p, 0, line_start, line_end);
    if (l != NULL) {
      double asc = 0, desc = 0, lead = 0;
      double w = CTLineGetTypographicBounds(l, &asc, &desc, &lead);
      CFRelease(l);
      p->lines[p->nline].c0 = line_start;
      p->lines[p->nline].c1 = line_end;
      p->lines[p->nline].width = w;
      p->lines[p->nline].ascent = asc;
      p->lines[p->nline].descent = desc;
      p->lines[p->nline].leading = lead;
      p->nline++;
    }
    if (i < line_end) {
      i = line_end;
    }
    if (i < p->nchar && (p->chars[i].cp == '\n' || p->chars[i].cp == '\r')) {
      if (p->chars[i].cp == '\r') {
        i++;
      }
      if (i < p->nchar && p->chars[i].cp == '\n') {
        i++;
      }
      continue;
    }
    if (i >= p->nchar) {
      break;
    }
  }
  double acc = 0.0;
  double maxw = 0.0;
  for (int k = 0; k < p->nline; k++) {
    double lh = p->lines[k].ascent + p->lines[k].descent + p->lines[k].leading;
    if (lh < 1.0) {
      lh = 1.0;
    }
    acc += lh;
    if (p->lines[k].width > maxw) {
      maxw = p->lines[k].width;
    }
  }
  p->total_h = acc;
  p->total_w = maxw;
  p->baseline = p->nline > 0 ? p->lines[0].ascent : 0.0;
}

// 把 [0,nchar) 铺成 segs（默认样式 0）
static void pt_segs_from_style_index(PtPara *p, const int *si) {
  p->nseg = 0;
  int start = 0;
  for (int i = 1; i <= p->nchar; i++) {
    if (i == p->nchar || si[i] != si[start]) {
      PtSeg *ns = (PtSeg *)realloc(p->segs, (size_t)(p->nseg + 1) * sizeof(PtSeg));
      if (ns == NULL) {
        break;
      }
      p->segs = ns;
      p->segs[p->nseg].c0 = start;
      p->segs[p->nseg].c1 = i;
      p->segs[p->nseg].style = si[start];
      p->nseg++;
      start = i;
    }
  }
}

// ---- 绘制 ----

static void pt_draw_para(PtPara *p, unsigned char *data, int buf_w, int buf_h,
                         double x, double y, double box_w, int align) {
  CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
  CGContextRef ctx = CGBitmapContextCreate(
      data, (size_t)buf_w, (size_t)buf_h, 8, (size_t)buf_w * 4, cs,
      (CGBitmapInfo)(kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little));
  if (cs != NULL) {
    CGColorSpaceRelease(cs);
  }
  if (ctx == NULL) {
    return;
  }
  CGContextSetShouldAntialias(ctx, true);
  CGContextSetShouldSmoothFonts(ctx, false);
  CGContextSetAllowsFontSmoothing(ctx, false);
  CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
  double acc = 0.0;
  for (int k = 0; k < p->nline; k++) {
    double dx = 0.0;
    if (box_w > 0.0) {
      double slack = box_w - p->lines[k].width;
      if (slack < 0.0) {
        slack = 0.0;
      }
      if (align == 1) {
        dx = slack / 2.0;
      } else if (align == 2) {
        dx = slack;
      }
    }
    CTLineRef l = pt_line_create(p, 0, p->lines[k].c0, p->lines[k].c1);
    if (l != NULL) {
      // 顶原点的 (x,y) → CGContext 的底原点
      double base_top = y + acc + p->lines[k].ascent;
      CGContextSetTextPosition(ctx, (CGFloat)(x + dx), (CGFloat)((double)buf_h - base_top));
      CTLineDraw(ctx, l);
      CFRelease(l);
    }
    double lh = p->lines[k].ascent + p->lines[k].descent + p->lines[k].leading;
    if (lh < 1.0) {
      lh = 1.0;
    }
    acc += lh;
  }
  CGContextFlush(ctx);
  CFRelease(ctx);
}

// 通用入口：单样式段落（pt_* 一族）
static PtPara *pt_para_simple(const char *text, int len, double size,
                              const char *family, int weight, int italic, int r,
                              int g, int b, int a) {
  PtPara *p = (PtPara *)calloc(1, sizeof(PtPara));
  if (p == NULL) {
    return NULL;
  }
  p->nchar = pt_decode(text, len, &p->chars);
  if (p->nchar == 0) {
    return p;
  }
  // family 是 MoonBit 的 Bytes：与 Pango/DWrite 两支同一假设，按 NUL 结尾串取长
  int fl = family != NULL ? (int)strlen(family) : 0;
  CTFontRef f = pt_font(family, fl, size, weight, italic);
  CGColorRef c = pt_color(r, g, b, a);
  int si0 = pt_style_add(p, f, c);
  if (f != NULL) {
    CFRelease(f);
  }
  if (c != NULL) {
    CGColorRelease(c);
  }
  if (si0 < 0) {
    pt_para_free(p);
    return NULL;
  }
  int *si = (int *)calloc((size_t)p->nchar, sizeof(int));
  if (si == NULL) {
    pt_para_free(p);
    return NULL;
  }
  pt_segs_from_style_index(p, si);
  free(si);
  return p;
}

static int pt_write_metrics(int32_t *out_w, int32_t *out_h,
                            int32_t *out_baseline, PtPara *p) {
  if (out_w != NULL) {
    *out_w = (int32_t)(p->total_w + 0.5);
  }
  if (out_h != NULL) {
    *out_h = (int32_t)(p->total_h + 0.5);
  }
  if (out_baseline != NULL) {
    *out_baseline = (int32_t)(p->baseline + 0.5);
  }
  return 1;
}

// ---- pt_* 对外入口 ----

int pt_measure_font(const char *text, int len, double size,
                    const char *family, int weight, int italic, int max_width,
                    int ellipsize, int wrap, int32_t *out_w, int32_t *out_h,
                    int32_t *out_baseline) {
  if (text == NULL || out_w == NULL || out_h == NULL || out_baseline == NULL) {
    return 0;
  }
  PtPara *p = pt_para_simple(text, len, size, family, weight, italic, 0, 0, 0, 255);
  if (p == NULL) {
    return 0;
  }
  pt_layout(p, max_width, ellipsize, wrap);
  int ok = pt_write_metrics(out_w, out_h, out_baseline, p);
  pt_para_free(p);
  return ok;
}

int pt_measure(const char *text, int len, double size, const char *family,
               int max_width, int ellipsize, int wrap, int32_t *out_w,
               int32_t *out_h, int32_t *out_baseline) {
  return pt_measure_font(text, len, size, family, 400, 0, max_width, ellipsize,
                         wrap, out_w, out_h, out_baseline);
}

int pt_font_line_height(double size, const char *family, int weight,
                        int italic, int32_t *out_h, int32_t *out_ascent) {
  if (out_h == NULL || out_ascent == NULL) {
    return 0;
  }
  // 与 Windows 同口径：取「单字 M 的排版行盒」，不取字体设计度量——后者与
  // measure() 差一两个像素，会让 line_height 低于 measure 的行高而违反契约。
  const char *probe = "Mg";
  PtPara *p = pt_para_simple(probe, 2, size, family, weight, italic, 0, 0, 0, 255);
  if (p == NULL) {
    return 0;
  }
  pt_layout(p, 0, 0, 0);
  if (p->nline < 1) {
    pt_para_free(p);
    return 0;
  }
  *out_ascent = (int32_t)(p->lines[0].ascent + 0.5);
  *out_h = (int32_t)(p->lines[0].ascent + p->lines[0].descent +
                     p->lines[0].leading + 0.5);
  pt_para_free(p);
  return 1;
}

int pt_draw(unsigned char *data, int buf_w, int buf_h, double x, double y,
            const char *text, int len, double size, const char *family, int r,
            int g, int b, int a, int max_width, int ellipsize, int wrap) {
  if (data == NULL || text == NULL || buf_w < 1 || buf_h < 1) {
    return 0;
  }
  PtPara *p = pt_para_simple(text, len, size, family, 400, 0, r, g, b, a);
  if (p == NULL) {
    return 0;
  }
  pt_layout(p, max_width, ellipsize, wrap);
  pt_draw_para(p, data, buf_w, buf_h, x, y, max_width > 0 ? (double)max_width : 0.0,
               0);
  pt_para_free(p);
  return 1;
}

// 盒内排版：wrapped_axis 规则与 DWrite/Pango 逐字同式（见文件头契约段）
int pt_draw_box(unsigned char *data, int buf_w, int buf_h, double x, double y,
                double box_w, double box_h, const char *text, int len,
                double size, const char *family, int weight, int italic, int r,
                int g, int b, int a, int align, int valign, int ellipsize,
                int wrap) {
  if (data == NULL || text == NULL || buf_w < 1 || buf_h < 1) {
    return 0;
  }
  PtPara *p = pt_para_simple(text, len, size, family, weight, italic, r, g, b, a);
  if (p == NULL) {
    return 0;
  }
  int wrapped_axis = box_w > 0.0 && (wrap != 0 || ellipsize != 0);
  int mw = wrapped_axis ? (int)box_w : 0;
  pt_layout(p, mw, ellipsize, wrap);
  double dx = 0.0;
  double dy = 0.0;
  if (!wrapped_axis && box_w > 0.0) {
    double slack = box_w - p->total_w;
    if (slack < 0.0) {
      slack = 0.0;
    }
    dx = align == 1 ? slack / 2.0 : (align == 2 ? slack : 0.0);
  }
  if (valign != 0 && box_h > 0.0) {
    double slack = box_h - p->total_h;
    if (slack < 0.0) {
      slack = 0.0;
    }
    dy = valign == 1 ? slack / 2.0 : slack;
  }
  pt_draw_para(p, data, buf_w, buf_h, x + dx, y + dy,
               wrapped_axis ? box_w : (box_w > 0.0 ? box_w : 0.0),
               wrapped_axis ? align : 0);
  pt_para_free(p);
  return 1;
}

// macOS 无 Cairo 会话（cr_begin 探针即不可用），上层靠 Painter::cairo_id()
// 给 None 短路根本不会调到这里——与 Windows 分支同款空桩。
int pt_draw_box_cr(int64_t cr_id, double x, double y, double box_w,
                   double box_h, const char *text, int len, double size,
                   const char *family, int weight, int italic, int r, int g,
                   int b, int a, int align, int valign, int ellipsize,
                   int wrap) {
  (void)cr_id; (void)x; (void)y; (void)box_w; (void)box_h; (void)text;
  (void)len; (void)size; (void)family; (void)weight; (void)italic; (void)r;
  (void)g; (void)b; (void)a; (void)align; (void)valign; (void)ellipsize;
  (void)wrap;
  return 0;
}

// 统计与批：macOS 走「即绘即混」的直画路线（无 D2D 提交/读回两段），
// 与 Linux 分支同档；出参按 .mbt 的四个写零，返回 1。
int pt_render_stats(int64_t *calls, int64_t *prep_us, int64_t *d2d_us,
                    int64_t *read_us) {
  if (calls != NULL) {
    *calls = 0;
  }
  if (prep_us != NULL) {
    *prep_us = 0;
  }
  if (d2d_us != NULL) {
    *d2d_us = 0;
  }
  if (read_us != NULL) {
    *read_us = 0;
  }
  return 1;
}

void pt_set_batching(int on) { (void)on; }
int pt_flush(void) { return 0; }
int pt_flush_if_overlap(int x0, int y0, int x1, int y1) {
  (void)x0; (void)y0; (void)x1; (void)y1;
  return 0;
}

// ---- 字族表 ----
//
// 形态与另两平台逐字一致：进程内缓存一条 UTF-8 串，族名以 '\n' 连接、无尾随
// 分隔符；按字节 strcmp 升序 + 相邻去重（MoonBit 侧的有序/去重断言按这套写）。
static char *pt_families_buf = NULL;
static int pt_families_len_v = -1;

static int pt_str_cmp(const void *a, const void *b) {
  return strcmp(*(const char *const *)a, *(const char *const *)b);
}

static void pt_families_build(void) {
  if (pt_families_len_v >= 0) {
    return;
  }
  pt_families_len_v = 0;
  CFArrayRef names = CTFontManagerCopyAvailableFontFamilyNames();
  if (names == NULL) {
    return;
  }
  CFIndex n = CFArrayGetCount(names);
  char **list = (char **)calloc((size_t)n + 1u, sizeof(char *));
  if (list == NULL) {
    CFRelease(names);
    return;
  }
  CFIndex kept = 0;
  for (CFIndex i = 0; i < n; i++) {
    CFStringRef s = (CFStringRef)CFArrayGetValueAtIndex(names, i);
    if (s == NULL || CFGetTypeID(s) != CFStringGetTypeID()) {
      continue;
    }
    CFIndex ul = CFStringGetLength(s);
    if (ul <= 0) {
      continue;
    }
    CFIndex bytes = CFStringGetMaximumSizeForEncoding(ul, kCFStringEncodingUTF8) + 1;
    char *dst = (char *)malloc((size_t)bytes);
    if (dst == NULL) {
      continue;
    }
    if (!CFStringGetCString(s, dst, bytes, kCFStringEncodingUTF8)) {
      free(dst);
      continue;
    }
    list[kept++] = dst;
  }
  CFRelease(names);
  if (kept == 0) {
    free(list);
    return;
  }
  qsort(list, (size_t)kept, sizeof(char *), pt_str_cmp);
  size_t total = 1;
  for (CFIndex i = 0; i < kept; i++) {
    total += strlen(list[i]) + 1;
  }
  char *buf = (char *)malloc(total);
  if (buf == NULL) {
    for (CFIndex i = 0; i < kept; i++) {
      free(list[i]);
    }
    free(list);
    return;
  }
  size_t at = 0;
  CFIndex prev = -1;
  for (CFIndex i = 0; i < kept; i++) {
    if (prev >= 0 && strcmp(list[prev], list[i]) == 0) {
      continue; // 相邻去重（大小写敏感，同 Windows/Linux）
    }
    if (at > 0) {
      buf[at++] = '\n';
    }
    size_t l = strlen(list[i]);
    memcpy(buf + at, list[i], l);
    at += l;
    prev = i;
  }
  buf[at] = '\0';
  pt_families_buf = buf;
  pt_families_len_v = (int)at;
  for (CFIndex i = 0; i < kept; i++) {
    free(list[i]);
  }
  free(list);
}

int pt_families_len(void) {
  pt_families_build();
  return pt_families_len_v;
}

int pt_families_byte(int index) {
  pt_families_build();
  if (index < 0 || index >= pt_families_len_v) {
    return 0;
  }
  return (int)(unsigned char)pt_families_buf[index];
}

int pt_family_available(const char *name, int len) {
  if (name == NULL || len <= 0) {
    return 0;
  }
  pt_families_build();
  if (pt_families_len_v <= 0) {
    return 0;
  }
  const char *p = pt_families_buf;
  while (*p != '\0') {
    const char *e = strchr(p, '\n');
    size_t l = e != NULL ? (size_t)(e - p) : strlen(p);
    if ((int)l == len) {
      int same = 1;
      for (int i = 0; i < len; i++) {
        char a = p[i];
        char c = name[i];
        if (a >= 'A' && a <= 'Z') {
          a = (char)(a + 32);
        }
        if (c >= 'A' && c <= 'Z') {
          c = (char)(c + 32);
        }
        if (a != c) {
          same = 0;
          break;
        }
      }
      if (same) {
        return 1;
      }
    }
    if (e == NULL) {
      break;
    }
    p = e + 1;
  }
  return 0;
}

// ---- rt_* 富文本会话 ----

#define RT_MAX 16

typedef struct {
  int used;
  char *text;
  int len;
  double size;
  char *family;
  int flen;
  int weight;
  int italic;
  int align;
  int valign;
  int wrap;
  int ellipsize;
  struct {
    int b0, b1;
    int r, g, b, a;
    int used;
  } colors[PT_MAX_RANGES];
  struct {
    int b0, b1;
    char *family;
    int flen;
    double size;
    int weight;
    int italic;
    int used;
  } fonts[PT_MAX_RANGES];
} MacRT;

static MacRT rt_slots[RT_MAX];

static MacRT *rt_of(int64_t h) {
  if (h <= 0 || h >= RT_MAX || !rt_slots[h].used) {
    return NULL;
  }
  return &rt_slots[h];
}

static char *rt_copy(const char *s, int len, int *out_len) {
  if (s == NULL || len < 0) {
    if (out_len != NULL) {
      *out_len = 0;
    }
    char *e = (char *)calloc(1, 1);
    return e;
  }
  char *buf = (char *)malloc((size_t)len + 1u);
  if (buf == NULL) {
    return NULL;
  }
  memcpy(buf, s, (size_t)len);
  buf[len] = '\0';
  if (out_len != NULL) {
    *out_len = len;
  }
  return buf;
}

int64_t rt_new(const char *text, int tlen, double size, const char *family,
               int flen, int weight, int italic) {
  if (text == NULL || tlen < 0) {
    return 0;
  }
  for (int i = 1; i < RT_MAX; i++) {
    if (!rt_slots[i].used) {
      MacRT *s = &rt_slots[i];
      memset(s, 0, sizeof(MacRT));
      s->text = rt_copy(text, tlen, &s->len);
      s->family = rt_copy(family, flen, &s->flen);
      if (s->text == NULL || s->family == NULL) {
        free(s->text);
        free(s->family);
        memset(s, 0, sizeof(MacRT));
        return 0;
      }
      s->size = size;
      s->weight = weight;
      s->italic = italic;
      s->wrap = 1; // 缺省档与 Windows 同（MoonBit 必调 set_format，值不外露）
      s->used = 1;
      return (int64_t)i;
    }
  }
  return 0;
}

void rt_free(int64_t h) {
  MacRT *s = rt_of(h);
  if (s == NULL) {
    return;
  }
  free(s->text);
  free(s->family);
  for (int i = 0; i < PT_MAX_RANGES; i++) {
    if (s->fonts[i].used) {
      free(s->fonts[i].family);
    }
  }
  memset(s, 0, sizeof(MacRT));
}

void rt_set_text(int64_t h, const char *text, int len) {
  MacRT *s = rt_of(h);
  if (s == NULL || text == NULL || len < 0) {
    return;
  }
  char *nc = rt_copy(text, len, NULL);
  if (nc == NULL) {
    return;
  }
  free(s->text);
  s->text = nc;
  s->len = len;
}

void rt_set_font(int64_t h, const char *family, int flen, double size,
                 int weight, int italic) {
  MacRT *s = rt_of(h);
  if (s == NULL) {
    return;
  }
  char *nf = rt_copy(family, flen, NULL);
  if (nf == NULL) {
    return;
  }
  free(s->family);
  s->family = nf;
  s->flen = flen < 0 ? (int)strlen(nf) : flen;
  s->size = size;
  s->weight = weight;
  s->italic = italic;
}

void rt_set_format(int64_t h, int align, int valign, int wrap, int ellipsize) {
  MacRT *s = rt_of(h);
  if (s == NULL) {
    return;
  }
  s->align = align;
  s->valign = valign;
  s->wrap = wrap;
  s->ellipsize = ellipsize;
}

void rt_add_color(int64_t h, int start, int end, int r, int g, int b, int a) {
  MacRT *s = rt_of(h);
  if (s == NULL) {
    return;
  }
  for (int i = 0; i < PT_MAX_RANGES; i++) {
    if (!s->colors[i].used) {
      s->colors[i].used = 1;
      s->colors[i].b0 = start;
      s->colors[i].b1 = end;
      s->colors[i].r = r;
      s->colors[i].g = g;
      s->colors[i].b = b;
      s->colors[i].a = a;
      return;
    }
  }
  // 区间表满：这条静默丢弃（与 Windows/Linux 同档）
}

void rt_add_font(int64_t h, int start, int end, const char *family, int flen,
                 double size, int weight, int italic) {
  MacRT *s = rt_of(h);
  if (s == NULL) {
    return;
  }
  for (int i = 0; i < PT_MAX_RANGES; i++) {
    if (!s->fonts[i].used) {
      s->fonts[i].used = 1;
      s->fonts[i].b0 = start;
      s->fonts[i].b1 = end;
      s->fonts[i].family = rt_copy(family, flen, &s->fonts[i].flen);
      s->fonts[i].size = size;
      s->fonts[i].weight = weight;
      s->fonts[i].italic = italic;
      return;
    }
  }
}

// 字节下标 → 码点下标（[b0,b1) 与文本取交，越界与倒序钳成空段）
static void rt_byte_range_to_cp(MacRT *s, PtPara *p, int b0, int b1, int *c0,
                                int *c1) {
  *c0 = 0;
  *c1 = 0;
  if (b0 < 0) {
    b0 = 0;
  }
  if (b1 > s->len) {
    b1 = s->len;
  }
  if (b1 <= b0) {
    return;
  }
  for (int i = 0; i < p->nchar; i++) {
    if (p->chars[i].b0 >= b0 && *c0 == 0 && *c1 == 0) {
      *c0 = i;
      break;
    }
  }
  for (int i = 0; i < p->nchar; i++) {
    if (p->chars[i].b1 > b1) {
      *c1 = i;
      return;
    }
    if (p->chars[i].b1 == b1) {
      *c1 = i + 1;
      return;
    }
  }
  *c1 = p->nchar;
}

// 会话 → 段落（默认样式 + 区间覆写）
static PtPara *rt_para(MacRT *s, int r, int g, int b, int a) {
  PtPara *p = (PtPara *)calloc(1, sizeof(PtPara));
  if (p == NULL) {
    return NULL;
  }
  p->nchar = pt_decode(s->text, s->len, &p->chars);
  if (p->nchar == 0) {
    return p;
  }
  CTFontRef f0 = pt_font(s->family, s->flen, s->size, s->weight, s->italic);
  CGColorRef c0 = pt_color(r, g, b, a);
  if (pt_style_add(p, f0, c0) < 0) {
    if (f0 != NULL) {
      CFRelease(f0);
    }
    if (c0 != NULL) {
      CGColorRelease(c0);
    }
    pt_para_free(p);
    return NULL;
  }
  if (f0 != NULL) {
    CFRelease(f0);
  }
  if (c0 != NULL) {
    CGColorRelease(c0);
  }
  int *si = (int *)calloc((size_t)p->nchar, sizeof(int));
  if (si == NULL) {
    pt_para_free(p);
    return NULL;
  }
  // 按登记顺序覆写：后设的赢（与另两平台同一条观察语义）
  for (int i = 0; i < PT_MAX_RANGES; i++) {
    if (s->colors[i].used) {
      int c0i, c1i;
      rt_byte_range_to_cp(s, p, s->colors[i].b0, s->colors[i].b1, &c0i, &c1i);
      if (c1i <= c0i) {
        continue;
      }
      CTFontRef inherit = NULL; // 颜色区间不改字体：沿用当前码点的字体
      CGColorRef col = pt_color(s->colors[i].r, s->colors[i].g,
                                s->colors[i].b, s->colors[i].a);
      for (int k = c0i; k < c1i; k++) {
        // 逐码点找它当下的字体（字体区间可能已覆写过），组合成新样式槽
        CTFontRef fk = NULL;
        for (int j = 0; j < PT_MAX_RANGES; j++) {
          if (!s->fonts[j].used) {
            continue;
          }
          int f0i, f1i;
          rt_byte_range_to_cp(s, p, s->fonts[j].b0, s->fonts[j].b1, &f0i, &f1i);
          if (k >= f0i && k < f1i) {
            fk = pt_font(s->fonts[j].family, s->fonts[j].flen,
                         s->fonts[j].size, s->fonts[j].weight,
                         s->fonts[j].italic);
            break;
          }
        }
        if (fk == NULL) {
          fk = pt_font(s->family, s->flen, s->size, s->weight, s->italic);
        }
        int slot = pt_style_add(p, fk, col);
        if (fk != NULL) {
          CFRelease(fk);
        }
        if (slot >= 0) {
          si[k] = slot;
        }
      }
      if (col != NULL) {
        CGColorRelease(col);
      }
      (void)inherit;
    }
  }
  for (int i = 0; i < PT_MAX_RANGES; i++) {
    if (s->fonts[i].used) {
      int c0i, c1i;
      rt_byte_range_to_cp(s, p, s->fonts[i].b0, s->fonts[i].b1, &c0i, &c1i);
      if (c1i <= c0i) {
        continue;
      }
      CTFontRef fk = pt_font(s->fonts[i].family, s->fonts[i].flen,
                             s->fonts[i].size, s->fonts[i].weight,
                             s->fonts[i].italic);
      // 只换字体、保留各码点当下的颜色：逐码点建新槽
      for (int k = c0i; k < c1i; k++) {
        CGColorRef keep = p->styles[si[k]].color;
        int slot = pt_style_add(p, fk, keep);
        if (slot >= 0) {
          si[k] = slot;
        }
      }
      if (fk != NULL) {
        CFRelease(fk);
      }
    }
  }
  pt_segs_from_style_index(p, si);
  free(si);
  return p;
}

int rt_measure(int64_t h, double box_w, int32_t *out_w, int32_t *out_h,
               int32_t *out_baseline) {
  MacRT *s = rt_of(h);
  if (s == NULL || out_w == NULL || out_h == NULL || out_baseline == NULL) {
    return 0;
  }
  PtPara *p = rt_para(s, 0, 0, 0, 255);
  if (p == NULL) {
    return 0;
  }
  int wrapped = box_w > 0.0 && (s->wrap != 0 || s->ellipsize != 0);
  pt_layout(p, wrapped ? (int)box_w : 0, s->ellipsize, s->wrap);
  int ok = pt_write_metrics(out_w, out_h, out_baseline, p);
  pt_para_free(p);
  return ok;
}

int rt_draw(int64_t h, unsigned char *data, int buf_w, int buf_h, double x,
            double y, double box_w, double box_h, int r, int g, int b, int a) {
  MacRT *s = rt_of(h);
  if (s == NULL || data == NULL || buf_w < 1 || buf_h < 1) {
    return 0;
  }
  PtPara *p = rt_para(s, r, g, b, a);
  if (p == NULL) {
    return 0;
  }
  int wrapped_axis = box_w > 0.0 && (s->wrap != 0 || s->ellipsize != 0);
  pt_layout(p, wrapped_axis ? (int)box_w : 0, s->ellipsize, s->wrap);
  double dx = 0.0;
  double dy = 0.0;
  if (!wrapped_axis && box_w > 0.0) {
    double slack = box_w - p->total_w;
    if (slack < 0.0) {
      slack = 0.0;
    }
    dx = s->align == 1 ? slack / 2.0 : (s->align == 2 ? slack : 0.0);
  }
  if (s->valign != 0 && box_h > 0.0) {
    double slack = box_h - p->total_h;
    if (slack < 0.0) {
      slack = 0.0;
    }
    dy = s->valign == 1 ? slack / 2.0 : slack;
  }
  pt_draw_para(p, data, buf_w, buf_h, x + dx, y + dy,
               wrapped_axis ? box_w : 0.0, wrapped_axis ? s->align : 0);
  pt_para_free(p);
  return 1;
}

int rt_draw_cr(int64_t cr_id, int64_t h, double x, double y, double box_w,
               double box_h, int r0, int g0, int b0, int a0) {
  (void)cr_id; (void)h; (void)x; (void)y; (void)box_w; (void)box_h; (void)r0;
  (void)g0; (void)b0; (void)a0;
  return 0; // 同 pt_draw_box_cr：macOS 无 Cairo 会话
}
#elif !defined(__linux__) && !defined(__APPLE__)

// 非 Linux 的文本层：macOS 的 CoreText 待真机，现在是占位 no-op（探到占位
// 即退降级）；Windows 分支见上面的 _WIN32 段。占位只保链接符号不断。
#include <stdint.h>

int pt_measure(const char *text, int len, double size, const char *family,
               int max_width, int ellipsize, int wrap, int32_t *out_w,
               int32_t *out_h, int32_t *out_baseline) {
  (void)text; (void)len; (void)size; (void)family; (void)max_width;
  (void)ellipsize; (void)wrap; (void)out_w; (void)out_h; (void)out_baseline;
  return 0;
}

int pt_render_stats(int64_t *calls, int64_t *d2d_us, int64_t *read_us) {
  (void)calls; (void)d2d_us; (void)read_us;
  return 1;
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

int pt_families_len(void) { return 0; }
int pt_families_byte(int index) { (void)index; return 0; }
int pt_family_available(const char *name, int len) {
  (void)name; (void)len; return 0;
}


int pt_draw_box_cr(int64_t cr_id, double x, double y, double box_w,
                   double box_h, const char *text, int len, double size,
                   const char *family, int weight, int italic, int r, int g,
                   int b, int a, int align, int valign, int ellipsize,
                   int wrap) {
  (void)cr_id; (void)x; (void)y; (void)box_w; (void)box_h; (void)text;
  (void)len; (void)size; (void)family; (void)weight; (void)italic;
  (void)r; (void)g; (void)b; (void)a; (void)align; (void)valign;
  (void)ellipsize; (void)wrap;
  return 0;
}


int rt_draw_cr(int64_t cr_id, int64_t h, double x, double y, double box_w,
               double box_h, int r0, int g0, int b0, int a0) {
  (void)cr_id; (void)h; (void)x; (void)y; (void)box_w; (void)box_h;
  (void)r0; (void)g0; (void)b0; (void)a0;
  return 0;
}


/* 占位三件：与上面 pt_* 占位同性质（CoreText 侧待真机）。同样必须落在分支内。 */
int pt_flush(void) {
  return 0;
}

int pt_flush_if_overlap(int x0, int y0, int x1, int y1) {
  (void)x0;
  (void)y0;
  (void)x1;
  (void)y1;
  return 0;
}

void pt_set_batching(int on) {
  (void)on;
}

#endif

// Linux 上 native-stub 的那次编译（无 WM_STUB_PANGO、且 __linux__ 成立）落不进任何分支，
// 编出空翻译单元——真实现由 prebuild 的归档提供，这里绝不能再定义一份（双定义）。
