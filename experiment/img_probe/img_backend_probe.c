/* W9 图片解码后端探针（纯 C，直接 #include render/stub.c 直喂 img_* 入口）。
 *
 * 动机：WIC 解码是纯 Win32 事实，与 MoonBit 运行时无关——include 进同一翻译
 * 单元即可直调，无需 moon 工具链（本机 moon 的 prebuild spawn 故障会挡死
 * moon build/test，探针是唯一能自证的回证通道）。
 *
 * 覆盖：
 *   静态解码（PNG/GIF 首帧）、内存解码、空图/坏图语义、预乘口径、
 *   GIF 动图（帧数/尺寸/延时/逐帧前进/当前帧成图/释放幂等）、
 *   子矩形帧合成（assets/subrect.gif：第二帧 12x12@(14,14)，必须叠在整幅
 *   画布上而不是当成 12x12 的整图——这是 WIC「给原始子帧、不替调用方合成」
 *   的直接回归）。
 *
 * 用法：
 *   img_backend_probe.exe [repo_root]
 *   repo_root 默认取编译期工作目录，缺省回退到相对路径（须在仓库根下跑）。
 *
 * 编法（独立于 moon 工具链，同 experiment/icon_probe 先例）：
 *   cl /nologo /W4 /utf-8 /O2 img_backend_probe.c /Fe:img_backend_probe.exe \
 *      windowscodecs.lib ole32.lib user32.lib
 *
 * 期望输出末行 IMG-BACKEND-OK。
 */
/* 必须早于任何标准头：stub.c 自己也定义它，但探针先引 stdio.h 会让那条 define
 * 太晚生效（W21d/W21e 探针同款 include 顺序坑），于是 _wfopen 报 C4996。 */
#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../../gui/render/stub.c"

static int g_fail = 0;

static void check(const char *what, long long got, long long want) {
  if (got == want) {
    printf("PROBE ok   %-52s = %lld\n", what, got);
  } else {
    printf("PROBE FAIL %-52s = %lld (want %lld)\n", what, got, want);
    g_fail++;
  }
}

static void check_true(const char *what, int cond) {
  if (cond) {
    printf("PROBE ok   %s\n", what);
  } else {
    printf("PROBE FAIL %s\n", what);
    g_fail++;
  }
}

static unsigned char *read_file(const char *path, int *out_len) {
  FILE *f = fopen(path, "rb");
  if (f == NULL) {
    return NULL;
  }
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  fseek(f, 0, SEEK_SET);
  if (n <= 0) {
    fclose(f);
    return NULL;
  }
  unsigned char *buf = (unsigned char *)malloc((size_t)n);
  if (buf == NULL) {
    fclose(f);
    return NULL;
  }
  size_t got = fread(buf, 1, (size_t)n, f);
  fclose(f);
  if (got != (size_t)n) {
    free(buf);
    return NULL;
  }
  *out_len = (int)n;
  return buf;
}

/* 取一张图的预乘像素（w*h*4）。调用方 free。 */
static unsigned char *grab(int64_t h, int *out_w, int *out_h) {
  int w = img_w(h);
  int ht = img_h(h);
  if (w <= 0 || ht <= 0) {
    return NULL;
  }
  unsigned char *px = (unsigned char *)malloc((size_t)w * (size_t)ht * 4);
  if (px == NULL) {
    return NULL;
  }
  if (img_copy(h, px) == 0) {
    free(px);
    return NULL;
  }
  *out_w = w;
  *out_h = ht;
  return px;
}

/* 取动图当前帧的预乘像素。动图与静图是两套入口（img_anim_w/copy vs img_w/copy），
 * 句柄表也各自独立，别混用。调用方 free。 */
static unsigned char *grab_anim(int64_t h, int *out_w, int *out_h) {
  int w = img_anim_w(h);
  int ht = img_anim_h(h);
  if (w <= 0 || ht <= 0) {
    return NULL;
  }
  unsigned char *px = (unsigned char *)malloc((size_t)w * (size_t)ht * 4);
  if (px == NULL) {
    return NULL;
  }
  if (img_anim_copy(h, px) == 0) {
    free(px);
    return NULL;
  }
  *out_w = w;
  *out_h = ht;
  return px;
}

static int px_diff(const unsigned char *a, const unsigned char *b, int n) {
  for (int i = 0; i < n; i++) {
    if (a[i] != b[i]) {
      return 1;
    }
  }
  return 0;
}

int main(int argc, char **argv) {
  const char *root = argc > 1 ? argv[1] : ".";
  char png[1024];
  char gif[1024];
  char sub[1024];
  snprintf(png, sizeof(png), "%s/examples/showcase/assets/icon.png", root);
  snprintf(gif, sizeof(gif), "%s/examples/showcase/assets/dot.gif", root);
  snprintf(sub, sizeof(sub), "%s/experiment/img_probe/assets/subrect.gif", root);
  printf("root: %s\n", root);

  /* ---- 1. 静态解码：文件入口（PNG） ---- */
  int64_t h1 = img_decode_file(png, (int)strlen(png));
  check_true("img_decode_file(icon.png) > 0", h1 > 0);
  int w1 = img_w(h1);
  int hh1 = img_h(h1);
  check_true("icon.png 尺寸非零", w1 > 0 && hh1 > 0);
  printf("           icon.png = %dx%d\n", w1, hh1);
  int gw = 0;
  int gh = 0;
  unsigned char *px1 = grab(h1, &gw, &gh);
  check_true("img_copy(icon.png) 成功", px1 != NULL);
  if (px1 != NULL) {
    /* 预乘不变量：alpha==255 的像素预乘后与 straight 相同、且不会超过 alpha */
    int bad = 0;
    int opaque = 0;
    for (int i = 0; i < gw * gh * 4; i += 4) {
      if (px1[i + 3] == 255) {
        opaque++;
      }
      if (px1[i] > px1[i + 3] || px1[i + 1] > px1[i + 3] || px1[i + 2] > px1[i + 3]) {
        bad++;
      }
    }
    check("icon.png 预乘越界像素数", bad, 0);
    check_true("icon.png 有不透明像素", opaque > 0);
    free(px1);
  }
  img_free(h1);
  img_free(h1); /* 幂等 */
  check("释放后 img_w", img_w(h1), 0);

  /* ---- 2. 静态解码：内存入口（同一份 PNG 字节） ---- */
  int plen = 0;
  unsigned char *pbytes = read_file(png, &plen);
  check_true("读到 icon.png 字节", pbytes != NULL);
  if (pbytes != NULL) {
    int64_t h2 = img_decode_bytes(pbytes, plen);
    check_true("img_decode_bytes(icon.png) > 0", h2 > 0);
    check("内存入口与文件入口尺寸一致", (long long)img_w(h2) * 100000 + img_h(h2),
          (long long)w1 * 100000 + hh1);
    img_free(h2);
    free(pbytes);
  }

  /* ---- 3. 坏图 / 空图语义 ---- */
  unsigned char junk[16];
  memcpy(junk, "not a png at all", 16);
  unsigned char scratch[16];
  memset(scratch, 0, sizeof(scratch));
  check("img_decode_bytes(垃圾字节)", img_decode_bytes(junk, 16), 0);
  check("img_decode_bytes(NULL)", img_decode_bytes(NULL, 10), 0);
  check("img_decode_bytes(len=0)", img_decode_bytes(junk, 0), 0);
  const char *missing = "Z:/definitely-missing-moonbit-native-gui.png";
  check("img_decode_file(不存在)", img_decode_file(missing, (int)strlen(missing)), 0);
  check("img_w(0)", img_w(0), 0);
  check("img_h(0)", img_h(0), 0);
  check("img_copy(0)", img_copy(0, scratch), 0);
  check("img_w(越界句柄)", img_w(999), 0);

  /* ---- 4. GIF 静态首帧：按逻辑屏幕尺寸，不是帧矩形 ---- */
  int64_t h3 = img_decode_file(gif, (int)strlen(gif));
  check_true("img_decode_file(dot.gif) > 0", h3 > 0);
  check("dot.gif 首帧宽", img_w(h3), 120);
  check("dot.gif 首帧高", img_h(h3), 120);
  img_free(h3);

  /* ---- 5. 动图：帧数/尺寸/延时/逐帧前进 ---- */
  int64_t a = img_anim_decode_file(gif, (int)strlen(gif));
  check_true("img_anim_decode_file(dot.gif) > 0", a > 0);
  check("dot.gif 动图 is_static", img_anim_is_static(a), 0);
  check("dot.gif 动图宽", img_anim_w(a), 120);
  check("dot.gif 动图高", img_anim_h(a), 120);
  check("dot.gif 首帧延时(ms)", img_anim_delay_ms(a), 400);
  check("dot.gif 初始帧号", img_anim_frame(a), 0);
  int fw = 0;
  int fh = 0;
  unsigned char *f0 = grab_anim(a, &fw, &fh);
  check_true("动图首帧 img_anim_copy 成功", f0 != NULL);
  check("动图帧尺寸", (long long)fw * 100000 + fh, 120LL * 100000 + 120);

  /* 前进 3 帧（dot.gif 共 4 帧）：帧号单调、每帧都换 */
  int flips = 0;
  for (int i = 0; i < 3; i++) {
    if (img_anim_advance(a)) {
      flips++;
    }
  }
  check("前进 3 次成功次数", flips, 3);
  check("帧号等于成功次数", img_anim_frame(a), flips);
  check("换帧后延时仍为 400", img_anim_delay_ms(a), 400);
  int fw2 = 0;
  int fh2 = 0;
  unsigned char *f1 = grab_anim(a, &fw2, &fh2);
  check_true("第 4 帧成图", f1 != NULL);
  if (f0 != NULL && f1 != NULL) {
    check_true("不同帧像素不同（dot.gif 是动的）",
               px_diff(f0, f1, 120 * 120 * 4) != 0);
  }
  /* 回绕一拍：帧号继续涨（单调口径），显示帧回到第 0 帧 */
  check("再前进一次", img_anim_advance(a), 1);
  check("回绕后帧号继续单调", img_anim_frame(a), 4);
  int fw3 = 0;
  int fh3 = 0;
  unsigned char *f2 = grab_anim(a, &fw3, &fh3);
  check_true("回绕后成图", f2 != NULL);
  if (f0 != NULL && f2 != NULL) {
    check_true("回绕后显示帧与首帧一致", px_diff(f0, f2, 120 * 120 * 4) == 0);
  }
  free(f0);
  free(f1);
  free(f2);

  /* ---- 6. 释放幂等 + 释放后全空操作 ---- */
  img_anim_free(a);
  img_anim_free(a);
  check("释放后 frame()", img_anim_frame(a), -1);
  check("释放后 delay_ms()", img_anim_delay_ms(a), 0);
  check("释放后 advance()", img_anim_advance(a), 0);
  check("释放后 w()", img_anim_w(a), 0);
  check("释放后 copy()", img_anim_copy(a, scratch), 0);

  /* ---- 7. 静图走同一入口：is_static 为真、永不换帧 ---- */
  int64_t sp = img_anim_decode_file(png, (int)strlen(png));
  check_true("PNG 也能开动图句柄", sp > 0);
  check("PNG is_static", img_anim_is_static(sp), 1);
  check("PNG advance()", img_anim_advance(sp), 0);
  check("PNG frame() 恒 0", img_anim_frame(sp), 0);
  int sw = 0;
  int sh = 0;
  unsigned char *spx = grab_anim(sp, &sw, &sh);
  check_true("静图经动图入口成图", spx != NULL);
  free(spx);
  img_anim_free(sp);

  check("img_anim_decode_file(不存在)", img_anim_decode_file(missing,
                                                            (int)strlen(missing)), 0);

  /* ---- 8. 子矩形帧合成：WIC 给原始子帧，叠在整幅画布上是本层职责 ---- */
  int64_t sub_a = img_anim_decode_file(sub, (int)strlen(sub));
  if (sub_a <= 0) {
    printf("PROBE SKIP assets/subrect.gif 未找到（%s）\n", sub);
  } else {
    check("subrect 逻辑屏幕宽", img_anim_w(sub_a), 40);
    check("subrect 逻辑屏幕高", img_anim_h(sub_a), 40);
    check("subrect is_static", img_anim_is_static(sub_a), 0);
    /* 第 0 帧：整幅黑（不透明） */
    int cw = 0;
    int chh = 0;
    unsigned char *c0 = grab_anim(sub_a, &cw, &chh);
    check_true("subrect 第 0 帧成图", c0 != NULL);
    if (c0 != NULL) {
      check("subrect 第 0 帧 (0,0) alpha", c0[3], 255);
      check("subrect 第 0 帧 (0,0) 亮度", c0[0] + c0[1] + c0[2], 0);
    }
    /* 第 1 帧是 12x12@(14,14)：画布必须仍是 40x40，(0,0) 保留第 0 帧的黑 */
    check("subrect 前进", img_anim_advance(sub_a), 1);
    int cw2 = 0;
    int ch2 = 0;
    unsigned char *c1 = grab_anim(sub_a, &cw2, &ch2);
    check_true("subrect 第 1 帧成图", c1 != NULL);
    if (c1 != NULL && c0 != NULL) {
      check("subrect 第 1 帧画布宽", cw2, 40);
      check("subrect 第 1 帧 (0,0) 仍是第 0 帧的黑", c1[0] + c1[1] + c1[2], 0);
      check("subrect 第 1 帧 (0,0) alpha", c1[3], 255);
      /* (20,20) 落在 14..25 的框内，应是红（ffmpeg 量化后 R=180） */
      int off = (20 * 40 + 20) * 4;
      check_true("subrect 第 1 帧框内偏红", c1[off + 2] > 100);
      check_true("subrect 两帧确有差异", px_diff(c0, c1, 40 * 40 * 4) != 0);
    }
    free(c0);
    free(c1);
    img_anim_free(sub_a);
  }

  printf("\n%s (fail=%d)\n", g_fail == 0 ? "IMG-BACKEND-OK" : "IMG-BACKEND-FAILED",
         g_fail);
  return g_fail == 0 ? 0 : 1;
}
