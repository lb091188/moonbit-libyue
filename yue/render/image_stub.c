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
