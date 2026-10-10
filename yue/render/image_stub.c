// 图片解码与文件写入桥：解码走 GdkPixbuf（GTK3 的既有依赖，零新增运行期
// 依赖），输出**统一转成**本栈 Bitmap 的内部布局（ARGB32 预乘、小端 B,G,R,A），
// 由调用方给缓冲、本层不拥有内存。会话制句柄与 cairo_stub 同形（槽表）。
//
// 旧链路的 Image 是 GdkPixbufAnimation（GIF 会动），本层只取静态首帧；
// 动画留作缺口记档，不在这里假装支持。

#include <gdk-pixbuf/gdk-pixbuf.h>
#include <stdint.h>
#include <stdio.h>

#define IMG_MAX 8

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
