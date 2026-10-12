/* W20f 图标加载后端探针（纯 C，直接 #include stub.c 读内部句柄表）。
 *
 * 动机：图标段（BGRA→HICON、.ico 原生加载、PNG 走 WIC 解码）是纯 Win32/GDI/WIC
 * 事实，与 MoonBit 运行时无关；include 进同一翻译单元即可直喂 wm_icon_* 入口，
 * 再用 Win32 自己的 GetIconInfo/GetObject/GetDIBits 反读建出来的图标。
 *
 * 用法：
 *   icon_backend_probe.exe [png_path]
 *   png_path 可选；给了就顺带验 PNG 的 WIC 解码路径（用 make_png.py 生成）。
 *
 * 编法（见 docs/zh/adaptation.md「Windows 基础能力首批」节；独立于 moon 工具链）：
 *   cl /nologo /W4 /utf-8 /O2 /DWIN32 /D_WINDOWS /DUNICODE /D_UNICODE \
 *      icon_backend_probe.c /Fe:icon_backend_probe.exe \
 *      user32.lib gdi32.lib imm32.lib advapi32.lib windowscodecs.lib ole32.lib
 *
 * 期望输出末行 ICON-BACKEND-OK。
 */
#include <windows.h>
#include <stdio.h>
#include <string.h>

/* stub.c 三条分支：_WIN32 真实现 / WM_STUB_GTK / 其余占位。本探针只验 _WIN32。 */
#include "../../gui/win/stub.c"

static int g_fail = 0;

static void check(const char *what, long long got, long long want) {
  if (got == want) {
    printf("PROBE ok   %-46s = %lld\n", what, got);
  } else {
    printf("PROBE FAIL %-46s = %lld (want %lld)\n", what, got, want);
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

/* 写一个 2x2 32bpp 的 .ico 到磁盘（ICONDIR + ICONDIRENTRY + DIB）。 */
static int write_test_ico(const char *path, const unsigned char xor_px[16]) {
  unsigned char buf[6 + 16 + 40 + 16 + 8];
  memset(buf, 0, sizeof(buf));
  int n = 0;
  /* ICONDIR */
  buf[n] = 0; buf[n + 1] = 0;         /* reserved */
  buf[n + 2] = 1; buf[n + 3] = 0;     /* type = icon */
  buf[n + 4] = 1; buf[n + 5] = 0;     /* count = 1 */
  n += 6;
  /* ICONDIRENTRY */
  int img_off = 6 + 16;
  int img_size = 40 + 16 + 8; /* DIB header + XOR(2*2*4) + AND(2 行 × 4 字节) */
  buf[n + 0] = 2;   /* width */
  buf[n + 1] = 2;   /* height */
  buf[n + 2] = 0;   /* colorCount */
  buf[n + 3] = 0;   /* reserved */
  buf[n + 4] = 1; buf[n + 5] = 0;     /* planes */
  buf[n + 6] = 32; buf[n + 7] = 0;    /* bitCount */
  buf[n + 8] = (unsigned char)(img_size & 0xFF);
  buf[n + 9] = (unsigned char)((img_size >> 8) & 0xFF);
  buf[n + 10] = 0; buf[n + 11] = 0;
  buf[n + 12] = (unsigned char)(img_off & 0xFF);
  buf[n + 13] = (unsigned char)((img_off >> 8) & 0xFF);
  buf[n + 14] = 0; buf[n + 15] = 0;
  n += 16;
  /* BITMAPINFOHEADER：高 = 2*height（XOR 与 AND 上下叠放） */
  #define PUT32LE(off, v) do { \
    buf[n + (off)] = (unsigned char)((v) & 0xFF); \
    buf[n + (off) + 1] = (unsigned char)(((v) >> 8) & 0xFF); \
    buf[n + (off) + 2] = (unsigned char)(((v) >> 16) & 0xFF); \
    buf[n + (off) + 3] = (unsigned char)(((v) >> 24) & 0xFF); \
  } while (0)
  PUT32LE(0, 40);   /* biSize */
  PUT32LE(4, 2);    /* biWidth */
  PUT32LE(8, 4);    /* biHeight = 2*h */
  buf[n + 12] = 1; buf[n + 13] = 0;   /* biPlanes */
  buf[n + 14] = 32; buf[n + 15] = 0;  /* biBitCount */
  PUT32LE(16, 0);   /* biCompression = BI_RGB */
  PUT32LE(20, 16);  /* biSizeImage */
  n += 40;
  /* XOR 位图：自底向上，故行序反转 */
  for (int row = 1; row >= 0; row--) {
    memcpy(buf + n, xor_px + row * 8, 8);
    n += 8;
  }
  /* AND 掩码：2 行 × 4 字节（1bpp，行对齐 4 字节），全 0 = 不透明 */
  n += 8;
  #undef PUT32LE
  FILE *f = fopen(path, "wb");
  if (f == NULL) {
    return 0;
  }
  size_t wrote = fwrite(buf, 1, (size_t)n, f);
  fclose(f);
  return wrote == (size_t)n;
}

int main(int argc, char **argv) {
  /* 2x2 图案：预乘 BGRA（左上不透明红、右上不透明绿、左下不透明蓝、右下半透明白）
   * 预乘：alpha=128 的白 = (128,128,128,128)。 */
  unsigned char px[16] = {
      0, 0, 255, 255,   /* B,G,R,A = 红 */
      0, 255, 0, 255,   /* 绿 */
      255, 0, 0, 255,   /* 蓝 */
      128, 128, 128, 128, /* 半透明白（预乘） */
  };

  /* ① BGRA → HICON，并用 Win32 反读尺寸/位深/像素 */
  int i1 = wm_icon_from_bgra(px, 2, 2);
  check_true("from_bgra 返回有效句柄", i1 > 0);
  check("存活图标数 == 1", wm_icon_alive(), 1);
  HICON h1 = (HICON)wm_icon_handle(i1);
  check_true("槽里是真 HICON", h1 != NULL);
  {
    ICONINFO ii;
    memset(&ii, 0, sizeof(ii));
    check_true("GetIconInfo 成功", GetIconInfo(h1, &ii) == TRUE);
    BITMAP bm;
    memset(&bm, 0, sizeof(bm));
    GetObject(ii.hbmColor, (int)sizeof(bm), &bm);
    check("颜色位图宽 == 2", bm.bmWidth, 2);
    check("颜色位图高 == 2", bm.bmHeight, 2);
    check("位深 == 32", bm.bmBitsPixel, 32);
    check_true("单色掩码位图存在", ii.hbmMask != NULL);
    /* 像素往返：GetObject 对 DIB section 的 bmBits 不保证可读，改用 GetDIBits
     * 反读（biHeight 负 = 请求自顶向下，与输入行序一致）。 */
    if (ii.hbmColor != NULL) {
      BITMAPINFO bi;
      memset(&bi, 0, sizeof(bi));
      bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
      bi.bmiHeader.biWidth = 2;
      bi.bmiHeader.biHeight = -2;
      bi.bmiHeader.biPlanes = 1;
      bi.bmiHeader.biBitCount = 32;
      bi.bmiHeader.biCompression = BI_RGB;
      unsigned char out[16];
      memset(out, 0, sizeof(out));
      HDC dc = GetDC(NULL);
      int lines = GetDIBits(dc, ii.hbmColor, 0, 2, out, &bi, DIB_RGB_COLORS);
      ReleaseDC(NULL, dc);
      check("GetDIBits 取回 2 行", lines, 2);
      check_true("像素逐字节直拷（BGRA 往返）", memcmp(out, px, 16) == 0);
    }
    if (ii.hbmColor != NULL) {
      DeleteObject(ii.hbmColor);
    }
    if (ii.hbmMask != NULL) {
      DeleteObject(ii.hbmMask);
    }
  }

  /* ② 释放：alive 归零、句柄失效；重复释放不崩（幂等） */
  wm_icon_free(i1);
  check("free 后存活数归零", wm_icon_alive(), 0);
  check_true("释放后槽里不再是 HICON", wm_icon_handle(i1) == NULL);
  wm_icon_free(i1);
  check("重复 free 幂等", wm_icon_alive(), 0);

  /* ③ 非法入参不崩、返回 0 */
  check("from_bgra(NULL,2,2) == 0", wm_icon_from_bgra(NULL, 2, 2), 0);
  check("from_bgra(px,0,0) == 0", wm_icon_from_bgra(px, 0, 0), 0);
  check("load_file(NULL) == 0", wm_icon_load_file(NULL, 0), 0);
  check("load_file(空串) == 0", wm_icon_load_file("", 0), 0);
  check("load_file(不存在) == 0", wm_icon_load_file("no-such-file.png", 0), 0);
  check("from_png(NULL,0) == 0", wm_icon_from_png(NULL, 0), 0);

  /* ④ .ico 磁盘加载（LoadImageW 原生路径） */
  {
    const char *ico = "icon_probe_test.ico";
    check_true("写出测试 .ico", write_test_ico(ico, px) != 0);
    int i2 = wm_icon_load_file(ico, 0);
    check_true("load_file(.ico) 返回有效句柄", i2 > 0);
    check("加载 .ico 后存活数 == 1", wm_icon_alive(), 1);
    HICON h2 = (HICON)wm_icon_handle(i2);
    check_true("槽里是真 HICON（.ico）", h2 != NULL);
    if (h2 != NULL) {
      ICONINFO ii;
      memset(&ii, 0, sizeof(ii));
      check_true("GetIconInfo(.ico) 成功", GetIconInfo(h2, &ii) == TRUE);
      if (ii.hbmColor != NULL) {
        DeleteObject(ii.hbmColor);
      }
      if (ii.hbmMask != NULL) {
        DeleteObject(ii.hbmMask);
      }
    }
    wm_icon_free(i2);
    check(".ico 释放后存活数归零", wm_icon_alive(), 0);
    remove(ico);
  }

  /* ⑤ 句柄表容量：WM_MAX_ICONS=32（槽 1..31）用尽后返回 0，不越界 */
  {
    int slots[64];
    int n = 0;
    for (int i = 0; i < 64; i++) {
      slots[n++] = wm_icon_from_bgra(px, 2, 2);
    }
    int ok = 0;
    for (int i = 0; i < n; i++) {
      if (slots[i] > 0) {
        ok++;
      }
    }
    check("句柄表上限 == 31 个图标", ok, WM_MAX_ICONS - 1);
    check_true("表满后返回 0", slots[n - 1] == 0);
    check("表满时存活数 == 31", wm_icon_alive(), WM_MAX_ICONS - 1);
    for (int i = 0; i < n; i++) {
      wm_icon_free(slots[i]);
    }
    check("全释放后存活数归零", wm_icon_alive(), 0);
  }

  /* ⑥ PNG 走 WIC 解码（可选：命令行给路径） */
  if (argc > 1 && argv[1] != NULL && argv[1][0] != '\0') {
    int i3 = wm_icon_load_file(argv[1], 0);
    check_true("load_file(PNG) 走 WIC 返回有效句柄", i3 > 0);
    HICON h3 = (HICON)wm_icon_handle(i3);
    check_true("槽里是真 HICON（PNG）", h3 != NULL);
    if (h3 != NULL) {
      ICONINFO ii;
      memset(&ii, 0, sizeof(ii));
      check_true("GetIconInfo(PNG) 成功", GetIconInfo(h3, &ii) == TRUE);
      BITMAP bm;
      memset(&bm, 0, sizeof(bm));
      if (ii.hbmColor != NULL) {
        GetObject(ii.hbmColor, (int)sizeof(bm), &bm);
        check("PNG 解码后位深 == 32", bm.bmBitsPixel, 32);
        check("PNG 解码后宽 == 8", bm.bmWidth, 8);
        check("PNG 解码后高 == 8", bm.bmHeight, 8);
        DeleteObject(ii.hbmColor);
      }
      if (ii.hbmMask != NULL) {
        DeleteObject(ii.hbmMask);
      }
    }
    wm_icon_free(i3);
    check("PNG 图标释放后存活数归零", wm_icon_alive(), 0);
  } else {
    printf("PROBE info 未给 PNG 路径，跳过 WIC 解码用例（make_png.py 可生成）\n");
  }

  printf(g_fail == 0 ? "ICON-BACKEND-OK\n" : "ICON-BACKEND-FAIL %d\n", g_fail);
  return g_fail == 0 ? 0 : 1;
}
