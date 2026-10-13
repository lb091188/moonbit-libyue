// Windows 文本层的 DirectWrite 实现（C++ TU）。
//
// 为什么是 .cpp 而不是并入 stub.c：dwrite.h 在本 SDK 里是 C++ 专属——
// DWRITE_MAKE_OPENTYPE_TAG/DWRITE_MAKE_FONT_FEATURE_TAG 用 static_cast 展开
// 到枚举初值里，C 模式直接 C2275/C2065（实测）；而 moon 的 native-stub 认
// .cpp（实测，探针 experiment/cpp_probe 已验后删除）。于是平台分工：
//   · stub.c 的 Pango 分支（Linux，prebuild 带 -DWM_STUB_PANGO 编）；
//   · stub.c 的占位分支（macOS 等，native-stub 编）；
//   · 本文件（Windows，native-stub 编）——dwrite.h 是系统 SDK 头，直接可见。
//
// 与 Pango 分支逐条对齐的口径：字号按逻辑像素取绝对尺寸（DWrite 的 fontSize
// 就是 DIP，同义）；宽度约束只在「要换行或要省略」时下发（wrap=false 的单行
// 可溢出，靠不给布局设宽实现）；基线取首行 ascent（DWRITE_LINE_METRICS.baseline）；
// 行盒来自字体设计度量 × size/designUnitsPerEm；族名表排序去重后按 '\n'
// 拼接（同机两次跑要拿到同一张表，测试才写得了）。族名取 0 号 locale
// （en-us）：主题里钉的 Windows 族名用英文名（如 "Microsoft YaHei"）。

#if defined(_WIN32)

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <d2d1.h>
#include <d2d1helper.h> // D2D1::ColorF/Point2F/RenderTargetProperties（C++ 头）
#include <dwrite.h>
#include <wincodec.h> // WIC 位图渲染目标（比 DC 目标快：绑一次、不逐调用重绑）
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <unordered_map>

namespace {

IDWriteFactory *ptw_factory() {
  static IDWriteFactory *factory = nullptr;
  static int tried = 0;
  if (tried) {
    return factory;
  }
  tried = 1;
  HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
    return nullptr;
  }
  IDWriteFactory *f = nullptr;
  if (FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED,
                                 __uuidof(IDWriteFactory),
                                 reinterpret_cast<IUnknown **>(&f)))) {
    return nullptr;
  }
  factory = f;
  return factory;
}

// UTF-8 → 宽字符（len<0 按 NUL 结尾算）
wchar_t *ptw_wide(const char *s, int len) {
  if (s == nullptr) {
    return nullptr;
  }
  int n = MultiByteToWideChar(CP_UTF8, 0, s, len, nullptr, 0);
  if (n <= 0) {
    return nullptr;
  }
  wchar_t *w = static_cast<wchar_t *>(malloc(sizeof(wchar_t) * (size_t(n) + 1)));
  if (w == nullptr) {
    return nullptr;
  }
  MultiByteToWideChar(CP_UTF8, 0, s, len, w, n);
  w[n] = L'\0';
  return w;
}

// 宽字符 → UTF-8（malloc 串，调用方 free）
char *ptw_utf8(const wchar_t *w) {
  if (w == nullptr) {
    return nullptr;
  }
  int n = WideCharToMultiByte(CP_UTF8, 0, w, -1, nullptr, 0, nullptr, nullptr);
  if (n <= 0) {
    return nullptr;
  }
  char *s = static_cast<char *>(malloc(size_t(n)));
  if (s == nullptr) {
    return nullptr;
  }
  WideCharToMultiByte(CP_UTF8, 0, w, -1, s, n, nullptr, nullptr);
  return s;
}

DWRITE_FONT_WEIGHT ptw_weight(int weight) {
  return weight > 0 ? static_cast<DWRITE_FONT_WEIGHT>(weight)
                    : DWRITE_FONT_WEIGHT_NORMAL;
}

DWRITE_FONT_STYLE ptw_style(int italic) {
  return italic != 0 ? DWRITE_FONT_STYLE_ITALIC : DWRITE_FONT_STYLE_NORMAL;
}

// 字号 → 文本格式（family 空串给系统缺省；族名不认识时 DWrite 自身回落）
IDWriteTextFormat *ptw_format(const char *family, double size, int weight,
                              int italic) {
  IDWriteFactory *f = ptw_factory();
  if (f == nullptr) {
    return nullptr;
  }
  wchar_t *wfam = ptw_wide(family != nullptr ? family : "", -1);
  if (wfam == nullptr) {
    return nullptr;
  }
  IDWriteTextFormat *fmt = nullptr;
  HRESULT hr = f->CreateTextFormat(wfam, nullptr, ptw_weight(weight),
                                   ptw_style(italic), DWRITE_FONT_STRETCH_NORMAL,
                                   static_cast<FLOAT>(size), L"", &fmt);
  free(wfam);
  if (FAILED(hr)) {
    return nullptr;
  }
  return fmt;
}

// 省略号符号（进程级单例；CreateEllipsisTrimmingSign 给内联对象）
IDWriteInlineObject *ptw_ellipsis_sign() {
  static IDWriteInlineObject *sign = nullptr;
  static int tried = 0;
  if (tried) {
    return sign;
  }
  tried = 1;
  IDWriteFactory *f = ptw_factory();
  if (f == nullptr) {
    return nullptr;
  }
  IDWriteTextFormat *fmt = ptw_format("", 12.0, 0, 0);
  if (fmt == nullptr) {
    return nullptr;
  }
  IDWriteInlineObject *s = nullptr;
  if (SUCCEEDED(f->CreateEllipsisTrimmingSign(fmt, &s))) {
    sign = s;
  }
  fmt->Release();
  return sign;
}

// 布局：宽与换行/省略按与 Pango 分支同一条规则下发
IDWriteTextLayout *ptw_layout(IDWriteTextFormat *fmt, const char *text, int len,
                              int max_width, int ellipsize, int wrap) {
  IDWriteFactory *f = ptw_factory();
  if (f == nullptr || fmt == nullptr || text == nullptr || len < 0) {
    return nullptr;
  }
  wchar_t *wtxt = ptw_wide(text, len);
  if (wtxt == nullptr) {
    return nullptr;
  }
  // CreateTextLayout 的 textLength 是宽字符个数（不是 UTF-8 字节数）
  IDWriteTextLayout *layout = nullptr;
  HRESULT hr = f->CreateTextLayout(wtxt, static_cast<UINT32>(wcslen(wtxt)), fmt,
                                   1.0e7f, 1.0e7f, &layout);
  free(wtxt);
  if (FAILED(hr) || layout == nullptr) {
    return nullptr;
  }
  layout->SetWordWrapping(wrap != 0 ? DWRITE_WORD_WRAPPING_WRAP
                                    : DWRITE_WORD_WRAPPING_NO_WRAP);
  if (max_width > 0 && (wrap != 0 || ellipsize != 0)) {
    layout->SetMaxWidth(static_cast<FLOAT>(max_width));
  }
  if (ellipsize != 0) {
    DWRITE_TRIMMING trimming;
    trimming.granularity = DWRITE_TRIMMING_GRANULARITY_CHARACTER;
    trimming.delimiter = 0;
    trimming.delimiterCount = 0;
    IDWriteInlineObject *sign = ptw_ellipsis_sign();
    if (sign != nullptr) {
      layout->SetTrimming(&trimming, sign);
    }
  }
  return layout;
}

// ---------------------------------------------------------------------------
// 布局缓存：CreateTextLayout（含整段 shaping）是画布资源缓存之后的剩余大头，
// 同参数的调用每帧重复。键 = 路径标记 + 文本 + 字体四要素 + 宽约束/换行/省略/
// 对齐——同键布局配置完全一致；复用只读（ptw_render 无区间时不改布局，区间
// 字体/颜色只属于富文本 rt_* 路径，不走这里）。上限 1024，超限整表清空（与
// MoonBit 侧度量缓存同口径：键访问有强局部性，整清比逐条 LRU 便宜）。单线程
// UI 循环内使用，无锁。
// ---------------------------------------------------------------------------
static std::unordered_map<std::string, IDWriteTextLayout *> g_layout_cache;
static int g_layout_cache_count = 0;

static std::string ptw_cache_key(const char *path, const char *text, int len,
                                 double size, const char *family, int weight,
                                 int italic, int width_int, int wrap,
                                 int ellipsize, int align) {
  char head[160];
  snprintf(head, sizeof(head), "%s|%g|%s|%d|%d|%d|%d|%d|%d|", path, size,
           family != nullptr ? family : "", weight, italic, width_int, wrap,
           ellipsize, align);
  std::string key(head);
  if (text != nullptr && len > 0) {
    key.append(text, static_cast<size_t>(len));
  }
  return key;
}

// 命中直接返回（缓存持有引用，调用方不 Release）；未命中建好配置入库。
// width_int 已按 wrapped_axis 归一化（<=0 = 不约束）；align 只在 width_int>0
// 时参与布局（与 Pango 分支 pt_render_box 同口径）。
static IDWriteTextLayout *ptw_cached_layout(const char *path, const char *text,
                                            int len, double size,
                                            const char *family, int weight,
                                            int italic, int width_int,
                                            int wrap, int ellipsize,
                                            int align) {
  const std::string key = ptw_cache_key(path, text, len, size, family, weight,
                                        italic, width_int, wrap, ellipsize,
                                        align);
  auto it = g_layout_cache.find(key);
  if (it != g_layout_cache.end()) {
    return it->second;
  }
  IDWriteTextFormat *fmt = ptw_format(family, size, weight, italic);
  if (fmt == nullptr) {
    return nullptr;
  }
  IDWriteTextLayout *layout =
      ptw_layout(fmt, text, len, width_int, ellipsize, wrap);
  fmt->Release();
  if (layout == nullptr) {
    return nullptr;
  }
  if (width_int > 0 && align != 0) {
    layout->SetTextAlignment(align == 1   ? DWRITE_TEXT_ALIGNMENT_CENTER
                             : align == 2 ? DWRITE_TEXT_ALIGNMENT_TRAILING
                                          : DWRITE_TEXT_ALIGNMENT_LEADING);
  }
  if (g_layout_cache_count >= 1024) {
    for (auto &kv : g_layout_cache) {
      kv.second->Release();
    }
    g_layout_cache.clear();
    g_layout_cache_count = 0;
  }
  g_layout_cache.emplace(key, layout);
  g_layout_cache_count++;
  return layout;
}

} // namespace

extern "C" int pt_measure_font(const char *text, int len, double size,
                               const char *family, int weight, int italic,
                               int max_width, int ellipsize, int wrap,
                               int32_t *out_w, int32_t *out_h,
                               int32_t *out_baseline);

extern "C" int pt_measure(const char *text, int len, double size,
                          const char *family, int max_width, int ellipsize,
                          int wrap, int32_t *out_w, int32_t *out_h,
                          int32_t *out_baseline) {
  return pt_measure_font(text, len, size, family, 400, 0, max_width, ellipsize,
                         wrap, out_w, out_h, out_baseline);
}

extern "C" int pt_measure_font(const char *text, int len, double size,
                               const char *family, int weight, int italic,
                               int max_width, int ellipsize, int wrap,
                               int32_t *out_w, int32_t *out_h,
                               int32_t *out_baseline) {
  if (text == nullptr || out_w == nullptr || out_h == nullptr ||
      out_baseline == nullptr) {
    return 0;
  }
  IDWriteTextLayout *layout = ptw_cached_layout("m", text, len, size, family,
                                                weight, italic, max_width,
                                                wrap, ellipsize, 0);
  if (layout == nullptr) {
    return 0;
  }
  DWRITE_TEXT_METRICS tm;
  if (FAILED(layout->GetMetrics(&tm))) {
    return 0;
  }
  FLOAT baseline = 0.0f;
  DWRITE_LINE_METRICS lm;
  UINT32 got = 0;
  if (SUCCEEDED(layout->GetLineMetrics(&lm, 1, &got)) && got >= 1) {
    baseline = lm.baseline;
  }
  *out_w = static_cast<int32_t>(tm.width + 0.5f);
  *out_h = static_cast<int32_t>(tm.height + 0.5f);
  *out_baseline = static_cast<int32_t>(baseline + 0.5f);
  return 1;
}

extern "C" int pt_font_line_height(double size, const char *family, int weight,
                                   int italic, int32_t *out_h,
                                   int32_t *out_ascent) {
  if (out_h == nullptr || out_ascent == nullptr) {
    return 0;
  }
  // 行盒与上升高度取「单字布局的行度量」而不是字体设计度量：DWrite 真正排版
  // 时用的就是这条（line height = 字体 ascent+descent+lineGap 按整数像素取整，
  // 实测 14px 缺省族 = 19/15），拿设计度量的话会与 measure() 差 1~2px——
  // 实测踩过：族名空串时从集合取首族（不是系统缺省族）更会差出两 px，
  // 而混排行高的断言（行盒要盖得住绘制高度）吃的就是这个数。
  IDWriteTextFormat *fmt = ptw_format(family, size, weight, italic);
  if (fmt == nullptr) {
    return 0;
  }
  IDWriteTextLayout *layout = ptw_layout(fmt, "M", 1, 0, 0, 0);
  fmt->Release();
  if (layout == nullptr) {
    return 0;
  }
  DWRITE_LINE_METRICS lm;
  UINT32 got = 0;
  if (FAILED(layout->GetLineMetrics(&lm, 1, &got)) || got < 1) {
    layout->Release();
    return 0;
  }
  layout->Release();
  *out_ascent = static_cast<int32_t>(lm.baseline + 0.5f);
  *out_h = static_cast<int32_t>(lm.height + 0.5f);
  return 1;
}

// ---------------------------------------------------------------------------
// 字体族枚举：排序 + 相邻去重（大小写不敏感）后按 '\n' 拼接的扁平表，协议与
// Pango 分支逐条一致（len = 字节数，byte(i) 取第 i 个字节）。
// ---------------------------------------------------------------------------

namespace {

char *ptw_fam_buf = nullptr;
int ptw_fam_len = -1;

int ptw_cmp_narrow(const void *a, const void *b) {
  // 字节序（与 Pango 分支的 g_strcmp0 同口径——MoonBit 侧的严格递增断言
  // 就是按字节词法比；大小写不敏感只用在可用性判定那一处）
  return strcmp(*static_cast<const char *const *>(a),
                *static_cast<const char *const *>(b));
}

void ptw_fam_build() {
  if (ptw_fam_len >= 0) {
    return;
  }
  ptw_fam_len = 0;
  IDWriteFactory *f = ptw_factory();
  if (f == nullptr) {
    return;
  }
  IDWriteFontCollection *coll = nullptr;
  if (FAILED(f->GetSystemFontCollection(&coll, FALSE)) || coll == nullptr) {
    return;
  }
  const UINT32 n = coll->GetFontFamilyCount();
  char **names =
      n > 0 ? static_cast<char **>(malloc(sizeof(char *) * size_t(n))) : nullptr;
  if (names == nullptr) {
    coll->Release();
    return;
  }
  UINT32 kept = 0;
  for (UINT32 i = 0; i < n; i++) {
    IDWriteFontFamily *fam = nullptr;
    if (FAILED(coll->GetFontFamily(i, &fam)) || fam == nullptr) {
      continue;
    }
    IDWriteLocalizedStrings *ls = nullptr;
    if (SUCCEEDED(fam->GetFamilyNames(&ls)) && ls != nullptr) {
      UINT32 len = 0;
      if (SUCCEEDED(ls->GetStringLength(0, &len)) && len > 0) {
        wchar_t *w = static_cast<wchar_t *>(
            malloc(sizeof(wchar_t) * (size_t(len) + 1)));
        if (w != nullptr && SUCCEEDED(ls->GetString(0, w, len + 1))) {
          char *n8 = ptw_utf8(w);
          if (n8 != nullptr) {
            names[kept++] = n8;
          }
        }
        free(w);
      }
      ls->Release();
    }
    fam->Release();
  }
  coll->Release();
  qsort(names, kept, sizeof(char *), ptw_cmp_narrow);
  size_t total = 1;
  for (UINT32 i = 0; i < kept; i++) {
    total += strlen(names[i]) + 1;
  }
  char *buf = static_cast<char *>(malloc(total));
  if (buf != nullptr) {
    size_t at = 0;
    for (UINT32 i = 0; i < kept; i++) {
      if (i > 0 && strcmp(names[i], names[i - 1]) == 0) {
        free(names[i]);
        continue;
      }
      const size_t l = strlen(names[i]);
      memcpy(buf + at, names[i], l);
      at += l;
      buf[at++] = '\n';
      free(names[i]);
    }
    buf[at] = '\0';
    ptw_fam_buf = buf;
    ptw_fam_len = int(at);
  }
  free(names);
}

} // namespace

extern "C" int pt_families_len(void) {
  ptw_fam_build();
  return ptw_fam_len > 0 ? ptw_fam_len : 0;
}

extern "C" int pt_families_byte(int index) {
  ptw_fam_build();
  if (ptw_fam_buf == nullptr || index < 0 || index >= ptw_fam_len) {
    return 0;
  }
  return int(static_cast<unsigned char>(ptw_fam_buf[index]));
}

extern "C" int pt_family_available(const char *name, int len) {
  ptw_fam_build();
  if (name == nullptr || len <= 0 || ptw_fam_len <= 0) {
    return 0;
  }
  int i = 0;
  while (i < ptw_fam_len) {
    int j = i;
    while (j < ptw_fam_len && ptw_fam_buf[j] != '\n') {
      j++;
    }
    if (j - i == len && _strnicmp(ptw_fam_buf + i, name, size_t(len)) == 0) {
      return 1;
    }
    i = j + 1;
  }
  return 0;
}

// ---------------------------------------------------------------------------
// 绘制：同一份 IDWriteTextLayout 先画进 32bpp 预乘 BGRA 的 DIB（D2D 的 DC
// 渲染目标），再把预乘像素按 Porter-Duff over 合进 MoonBit 的像素缓冲
// （ARGB32 小端，分量序 B,G,R,A——与 DIB 同布局，逐分量合成即可）。
// 盒内对齐照 Pango 分支 pt_render_box 的规则：有宽约束（要换行或要省略）时
// 把宽与对齐交给布局，单行不省略时自己算 slack 偏移；垂直对齐同理算 dy。
// 文字反锯齿固定走灰度档（ClearType 是次像素渲染，落在透明底上会出彩边，
// 字母级灰度与 Cairo/Pango 侧的默认观感同档）。
// ---------------------------------------------------------------------------

namespace {

ID2D1Factory *ptw_d2d_factory() {
  static ID2D1Factory *factory = nullptr;
  static int tried = 0;
  if (tried) {
    return factory;
  }
  tried = 1;
  D2D1_FACTORY_OPTIONS opts;
  ZeroMemory(&opts, sizeof(opts));
  ID2D1Factory *f = nullptr;
  if (FAILED(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED,
                               __uuidof(ID2D1Factory), &opts,
                               reinterpret_cast<void **>(&f)))) {
    return nullptr;
  }
  factory = f;
  return factory;
}

struct PtwColorRange {
  int start;
  int end;
  int r, g, b, a;
};

struct PtwFontRange {
  int start;
  int end;
  const wchar_t *family; // 可为空串（跟基准字体）
  double size;           // <=0 表示不动
  int weight;
  int italic;
};

DWRITE_TEXT_RANGE ptw_range(int start, int end) {
  DWRITE_TEXT_RANGE r;
  r.startPosition = static_cast<UINT32>(start < 0 ? 0 : start);
  r.length = static_cast<UINT32>(end > start ? end - start : 0);
  return r;
}

// 字节下标（MoonBit 侧口径，与 Pango 分支一致）→ UTF-16 码元下标（DWrite
// 口径）：按前缀转宽字符数即得。切点落在多字节字符中间时向后找到下一个字符
// 起始（DWrite 的 range 越界会被吞掉，不能靠它兜底）。
UINT32 ptw_widx(const char *text, int byte_off) {
  if (text == nullptr || byte_off <= 0) {
    return 0;
  }
  int n = MultiByteToWideChar(CP_UTF8, 0, text, byte_off, nullptr, 0);
  if (n > 0) {
    return static_cast<UINT32>(n);
  }
  return 0;
}

// 进程级画布缓存：WIC 位图 + D2D 渲染目标 + 两支画笔各建一次（尺寸只增不减）。
// 实测背景：每调用新建一套资源是 ~2.6ms/段文本，DC 渲染目标逐调用 BindDC 还要
// 再花 ~0.4ms——一帧几十段文字会把窗口拖成「未响应」（真机反馈）。
// 陷阱：WIC 位图**不能**用 CreateBitmapFromMemory 包外部缓冲——那会走 WIC 的
// 内部缓存，D2D 画完读不回外部缓冲（实测 ink=0、返回还是成功）；改用自持位图
// 并在绘制后 Lock(WICBitmapLockRead) 读回像素。
struct PtwCanvas {
  int w;
  int h;
  IWICBitmap *wic;
  ID2D1RenderTarget *rt;
  ID2D1SolidColorBrush *brush; // 文本色（逐调用 SetColor）
};

PtwCanvas g_canvas = {0, 0, nullptr, nullptr, nullptr};

// ---------------------------------------------------------------------------
// 渲染统计（性能诊断）：ptw_render 的调用数与三段耗时（微秒）——prep（度量
// 与画笔准备）/ d2d（BeginDraw→EndDraw 提交）/ read（WIC 读回 + 逐像素混合）。
// 单线程无锁；宿主退出时经 pt_render_stats 读取。
// ---------------------------------------------------------------------------
static long long g_st_calls = 0;
static long long g_st_prep_us = 0;
static long long g_st_d2d_us = 0;
static long long g_st_read_us = 0;

static double ptw_now_us() {
  static LARGE_INTEGER f = [] {
    LARGE_INTEGER fr;
    QueryPerformanceFrequency(&fr);
    return fr;
  }();
  LARGE_INTEGER c;
  QueryPerformanceCounter(&c);
  return (double)c.QuadPart * 1e6 / (double)f.QuadPart;
}

void ptw_canvas_reset() {
  if (g_canvas.brush != nullptr) {
    g_canvas.brush->Release();
    g_canvas.brush = nullptr;
  }
  if (g_canvas.rt != nullptr) {
    g_canvas.rt->Release();
    g_canvas.rt = nullptr;
  }
  if (g_canvas.wic != nullptr) {
    g_canvas.wic->Release();
    g_canvas.wic = nullptr;
  }
  g_canvas.w = 0;
  g_canvas.h = 0;
}

IWICImagingFactory *ptw_wic_factory() {
  static IWICImagingFactory *factory = nullptr;
  static int tried = 0;
  if (tried) {
    return factory;
  }
  tried = 1;
  HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
    return nullptr;
  }
  IWICImagingFactory *f = nullptr;
  if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                              CLSCTX_INPROC_SERVER, __uuidof(IWICImagingFactory),
                              reinterpret_cast<void **>(&f)))) {
    return nullptr;
  }
  factory = f;
  return factory;
}

bool ptw_canvas_ensure(int w, int h) {
  if (g_canvas.rt != nullptr && g_canvas.w >= w && g_canvas.h >= h) {
    return true;
  }
  const int nw = w > g_canvas.w ? w : g_canvas.w;
  const int nh = h > g_canvas.h ? h : g_canvas.h;
  ptw_canvas_reset();
  ID2D1Factory *d2d = ptw_d2d_factory();
  IWICImagingFactory *wic = ptw_wic_factory();
  if (d2d == nullptr || wic == nullptr) {
    return false;
  }
  // 自持位图（WICBitmapCacheOnLoad）：不用 CreateBitmapFromMemory 包外部
  // 缓冲——那条路 D2D 画完读不回外部缓冲（实测 ink=0 且返回值是成功）
  IWICBitmap *wicbmp = nullptr;
  if (FAILED(wic->CreateBitmap(UINT(nw), UINT(nh),
                               GUID_WICPixelFormat32bppPBGRA,
                               WICBitmapCacheOnLoad, &wicbmp))) {
    return false;
  }
  D2D1_RENDER_TARGET_PROPERTIES props = D2D1::RenderTargetProperties(
      D2D1_RENDER_TARGET_TYPE_SOFTWARE,
      D2D1::PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM,
                        D2D1_ALPHA_MODE_PREMULTIPLIED),
      96.0f, 96.0f);
  ID2D1RenderTarget *rt = nullptr;
  if (FAILED(d2d->CreateWicBitmapRenderTarget(wicbmp, &props, &rt))) {
    wicbmp->Release();
    return false;
  }
  ID2D1SolidColorBrush *brush = nullptr;
  if (FAILED(rt->CreateSolidColorBrush(D2D1::ColorF(0.0f, 0.0f, 0.0f, 1.0f),
                                       &brush))) {
    rt->Release();
    wicbmp->Release();
    return false;
  }
  g_canvas.w = nw;
  g_canvas.h = nh;
  g_canvas.wic = wicbmp;
  g_canvas.rt = rt;
  g_canvas.brush = brush;
  return true;
}

// 把 layout 画进 dst（预乘 BGRA，buf_w×buf_h）；区间颜色在渲染目标上建画笔
int ptw_render(IDWriteTextLayout *layout, float ox, float oy,
               unsigned char *data, int buf_w, int buf_h, int r, int g, int b,
               int a, const PtwColorRange *cranges, int nc,
               const PtwFontRange *franges, int nf, int layout_w_int) {
  if (layout == nullptr || data == nullptr || buf_w < 1 || buf_h < 1) {
    return 0;
  }
  if (!ptw_canvas_ensure(buf_w, buf_h)) {
    return 0;
  }
  const double st_t0 = ptw_now_us();
  g_st_calls++;
  // 只清/画/读回/混合「文本自身那一小块」：Clear、WIC 读回与逐像素混合曾都
  // 吃全窗（每段文本一次 5MB 级读回+混合，一帧几百段就是几百次全窗——实测
  // native-app 一帧 paint 235ms 的真身）。布局度量已含墨迹范围（left/top 是
  // 相对布局原点的墨迹偏移），四周补 4px 防悬挂/下划线溢出。文本整块落在
  // 窗外时无墨可画，按成功处理。
  DWRITE_TEXT_METRICS tm;
  if (FAILED(layout->GetMetrics(&tm))) {
    return 0;
  }
  // 有宽约束（换行/省略）时对齐由布局管，墨迹分布在布局盒内——矩形直接取
  // 布局盒（layout_w_int 由调用方按 wrapped_axis 传入，0 = 无约束）；无约束
  // 用文本度量（left/top 是相对布局原点的墨迹偏移）。四周补 4px 防悬挂/
  // 下划线溢出。
  const int constrained = layout_w_int > 0;
  const double ink_x0 = constrained ? (double)ox : (double)(ox + tm.left);
  const double ink_x1 =
      constrained
          ? (double)(ox + layout_w_int)
          : (double)(ox + tm.left + tm.widthIncludingTrailingWhitespace);
  int rx0 = (int)floorf((float)ink_x0) - 4;
  int ry0 = (int)floorf(oy + tm.top) - 4;
  int rx1 = (int)ceilf((float)ink_x1) + 4;
  int ry1 = (int)ceilf(oy + tm.top + tm.height) + 4;
  if (rx0 < 0) {
    rx0 = 0;
  }
  if (ry0 < 0) {
    ry0 = 0;
  }
  if (rx1 > buf_w) {
    rx1 = buf_w;
  }
  if (ry1 > buf_h) {
    ry1 = buf_h;
  }
  if (rx1 <= rx0 || ry1 <= ry0) {
    return 1;
  }
  const D2D1_RECT_F box = D2D1::RectF(static_cast<FLOAT>(rx0),
                                      static_cast<FLOAT>(ry0),
                                      static_cast<FLOAT>(rx1),
                                      static_cast<FLOAT>(ry1));
  HRESULT hr = S_OK;
  g_canvas.brush->SetColor(
      D2D1::ColorF(r / 255.0f, g / 255.0f, b / 255.0f, a / 255.0f));
  // 区间字体（后设覆盖先设由 DWrite 的范围语义保证）
  for (int i = 0; i < nf; i++) {
    DWRITE_TEXT_RANGE range = ptw_range(franges[i].start, franges[i].end);
    if (franges[i].family != nullptr && franges[i].family[0] != L'\0') {
      layout->SetFontFamilyName(franges[i].family, range);
    }
    if (franges[i].size > 0.0) {
      layout->SetFontSize(static_cast<FLOAT>(franges[i].size), range);
    }
    layout->SetFontWeight(ptw_weight(franges[i].weight), range);
    layout->SetFontStyle(ptw_style(franges[i].italic), range);
  }
  // 区间颜色：D2D 画笔是设备相关对象，必须在渲染目标上建、画完再放
  ID2D1SolidColorBrush *cbrushes[32];
  int nb = 0;
  for (int i = 0; i < nc && nb < 32; i++) {
    ID2D1SolidColorBrush *cb = nullptr;
    if (SUCCEEDED(g_canvas.rt->CreateSolidColorBrush(
            D2D1::ColorF(cranges[i].r / 255.0f, cranges[i].g / 255.0f,
                         cranges[i].b / 255.0f, cranges[i].a / 255.0f),
            &cb))) {
      layout->SetDrawingEffect(cb, ptw_range(cranges[i].start, cranges[i].end));
      cbrushes[nb++] = cb;
    }
  }
  const double st_t1 = ptw_now_us();
  g_st_prep_us += (long long)(st_t1 - st_t0);
  g_canvas.rt->BeginDraw();
  // 清本次要用的那块：**必须用 Clear**——「透明色 FillRectangle」在源覆盖语义
  // 下是空操作（实测：缓存画布上旧内容累积，Center/End 对齐的墨迹从 x=0 起）。
  // 画布可能比这次大，靠轴对齐裁剪把 Clear 限制在本次区域内（Clear 吃裁剪）。
  g_canvas.rt->PushAxisAlignedClip(box, D2D1_ANTIALIAS_MODE_ALIASED);
  g_canvas.rt->Clear(D2D1::ColorF(0.0f, 0.0f, 0.0f, 0.0f));
  g_canvas.rt->SetTextAntialiasMode(D2D1_TEXT_ANTIALIAS_MODE_GRAYSCALE);
  g_canvas.rt->DrawTextLayout(D2D1::Point2F(ox, oy), layout, g_canvas.brush,
                              D2D1_DRAW_TEXT_OPTIONS_NONE);
  g_canvas.rt->PopAxisAlignedClip();
  hr = g_canvas.rt->EndDraw();
  for (int i = 0; i < nb; i++) {
    cbrushes[i]->Release();
  }
  const double st_t2 = ptw_now_us();
  g_st_d2d_us += (long long)(st_t2 - st_t1);
  const int ok = SUCCEEDED(hr) ? 1 : 0;
  if (ok) {
    // 读回 WIC 位图（绘制后必须走 Lock；自持位图的内容就在这里）并做
    // 预乘 BGRA over：out = src + dst·(1 − srcA)（两缓冲同为预乘域）。
    // 只读回文本矩形，混合落在 data 的同一绝对坐标上。
    const double st_t3 = ptw_now_us();
    WICRect wr = {rx0, ry0, rx1 - rx0, ry1 - ry0};
    IWICBitmapLock *lock = nullptr;
    if (SUCCEEDED(g_canvas.wic->Lock(&wr, WICBitmapLockRead, &lock))) {
      UINT stride = 0;
      UINT cb = 0;
      BYTE *pixels = nullptr;
      if (SUCCEEDED(lock->GetStride(&stride)) &&
          SUCCEEDED(lock->GetDataPointer(&cb, &pixels)) && pixels != nullptr) {
        const int rw = rx1 - rx0;
        const int rh = ry1 - ry0;
        for (int y = 0; y < rh; y++) {
          const unsigned char *srow = pixels + size_t(y) * stride;
          unsigned char *drow =
              data + size_t(ry0 + y) * size_t(buf_w) * 4 + size_t(rx0) * 4;
          for (int x = 0; x < rw; x++) {
            const unsigned sa = srow[x * 4 + 3];
            if (sa == 0) {
              continue;
            }
            const unsigned inv = 255u - sa;
            drow[x * 4 + 0] = static_cast<unsigned char>(
                srow[x * 4 + 0] + (unsigned(drow[x * 4 + 0]) * inv + 127) / 255);
            drow[x * 4 + 1] = static_cast<unsigned char>(
                srow[x * 4 + 1] + (unsigned(drow[x * 4 + 1]) * inv + 127) / 255);
            drow[x * 4 + 2] = static_cast<unsigned char>(
                srow[x * 4 + 2] + (unsigned(drow[x * 4 + 2]) * inv + 127) / 255);
            drow[x * 4 + 3] = static_cast<unsigned char>(
                sa + (unsigned(drow[x * 4 + 3]) * inv + 127) / 255);
          }
        }
      }
      lock->Release();
      g_st_read_us += (long long)(ptw_now_us() - st_t3);
    } else {
      g_st_read_us += (long long)(ptw_now_us() - st_t3);
      return 0;
    }
  }
  return ok;
}

// 盒内对齐（先量后偏），与 Pango 分支 pt_render_box 的规则逐条对应
void ptw_box_offsets(IDWriteTextLayout *layout, int align, int valign,
                     double box_w, double box_h, int wrapped_axis, double *dx,
                     double *dy) {
  *dx = 0.0;
  *dy = 0.0;
  if (box_w <= 0.0 && box_h <= 0.0) {
    return;
  }
  DWRITE_TEXT_METRICS tm;
  if (FAILED(layout->GetMetrics(&tm))) {
    return;
  }
  if (box_w > 0.0 && wrapped_axis == 0) {
    const double slack = box_w - tm.width;
    if (slack > 0.0) {
      *dx = align == 1 ? slack / 2.0 : (align == 2 ? slack : 0.0);
    }
  }
  if (box_h > 0.0 && valign != 0) {
    const double slack = box_h - tm.height;
    if (slack > 0.0) {
      *dy = valign == 1 ? slack / 2.0 : slack;
    }
  }
}

} // namespace

extern "C" int pt_draw(unsigned char *data, int buf_w, int buf_h, double x,
                       double y, const char *text, int len, double size,
                       const char *family, int r, int g, int b, int a,
                       int max_width, int ellipsize, int wrap) {
  if (data == nullptr || text == nullptr || buf_w < 1 || buf_h < 1) {
    return 0;
  }
  IDWriteTextLayout *layout = ptw_cached_layout("m", text, len, size, family,
                                                400, 0, max_width, wrap,
                                                ellipsize, 0);
  if (layout == nullptr) {
    return 0;
  }
  return ptw_render(layout, static_cast<float>(x), static_cast<float>(y), data,
                    buf_w, buf_h, r, g, b, a, nullptr, 0, nullptr, 0,
                    max_width > 0 && (wrap != 0 || ellipsize != 0) ? max_width
                                                                   : 0);
}

extern "C" int pt_draw_box(unsigned char *data, int buf_w, int buf_h, double x,
                           double y, double box_w, double box_h,
                           const char *text, int len, double size,
                           const char *family, int weight, int italic, int r,
                           int g, int b, int a, int align, int valign,
                           int ellipsize, int wrap) {
  if (data == nullptr || text == nullptr || buf_w < 1 || buf_h < 1) {
    return 0;
  }
  const int wrapped_axis = box_w > 0.0 && (wrap != 0 || ellipsize != 0);
  IDWriteTextLayout *layout = ptw_cached_layout(
      "b", text, len, size, family, weight, italic,
      wrapped_axis ? static_cast<int>(box_w) : 0, wrap, ellipsize,
      wrapped_axis ? align : 0);
  if (layout == nullptr) {
    return 0;
  }
  double dx = 0.0;
  double dy = 0.0;
  ptw_box_offsets(layout, align, valign, box_w, box_h, wrapped_axis, &dx, &dy);
  return ptw_render(layout, static_cast<float>(x + dx),
                    static_cast<float>(y + dy), data, buf_w, buf_h, r, g, b, a,
                    nullptr, 0, nullptr, 0,
                    wrapped_axis ? static_cast<int>(box_w) : 0);
}

extern "C" int pt_draw_box_cr(int64_t cr_id, double x, double y, double box_w,
                              double box_h, const char *text, int len,
                              double size, const char *family, int weight,
                              int italic, int r, int g, int b, int a, int align,
                              int valign, int ellipsize, int wrap) {
  (void)cr_id; (void)x; (void)y; (void)box_w; (void)box_h; (void)text;
  (void)len; (void)size; (void)family; (void)weight; (void)italic; (void)r;
  (void)g; (void)b; (void)a; (void)align; (void)valign; (void)ellipsize;
  (void)wrap;
  return 0; // Windows 无 cairo 会话：MoonBit 侧按 cairo_id()==None 走光栅路径
}

// ---------------------------------------------------------------------------
// 富文本会话（rt_*）：基准格式 + 文本 + 区间表住在句柄里，measure/draw 时
// 现搭一份 IDWriteTextLayout（区间字体在布局上设属性、区间颜色在渲染目标上
// 建画笔再 SetDrawingEffect——画笔设备相关，所以颜色只在绘制那趟生效）。
// 槽表制与 Pango 分支同规：容量 64、句柄 = 槽号 1 起、无效句柄安全退化。
// ---------------------------------------------------------------------------

#define PTW_RT_MAX 64
#define PTW_RT_RANGES 32

struct PtwSession {
  char *text;
  int tlen;
  char *family;
  double size;
  int weight;
  int italic;
  int align;
  int valign;
  int wrap;
  int ellipsize;
  PtwColorRange colors[PTW_RT_RANGES];
  int nc;
  PtwFontRange font_ranges[PTW_RT_RANGES];
  wchar_t *font_fam_storage[PTW_RT_RANGES];
  int nf;
};

PtwSession *ptw_sessions[PTW_RT_MAX];

PtwSession *ptw_session_of(int64_t h) {
  if (h <= 0 || h > PTW_RT_MAX) {
    return nullptr;
  }
  return ptw_sessions[h - 1];
}

int64_t ptw_session_put(PtwSession *s) {
  for (int i = 0; i < PTW_RT_MAX; i++) {
    if (ptw_sessions[i] == nullptr) {
      ptw_sessions[i] = s;
      return int64_t(i + 1);
    }
  }
  return 0;
}

void ptw_session_drop(PtwSession *s) {
  free(s->text);
  free(s->family);
  for (int i = 0; i < s->nf; i++) {
    free(s->font_fam_storage[i]);
  }
  free(s);
}

// 由会话现搭布局；with_align 为真时把对齐与盒宽交给布局（绘制那趟）
IDWriteTextLayout *ptw_session_layout(PtwSession *s, int box_w,
                                      bool with_align) {
  IDWriteTextFormat *fmt = ptw_format(s->family, s->size, s->weight, s->italic);
  if (fmt == nullptr) {
    return nullptr;
  }
  const int wrapped_axis = box_w > 0 && (s->wrap != 0 || s->ellipsize != 0);
  IDWriteTextLayout *layout = ptw_layout(fmt, s->text, s->tlen,
                                         wrapped_axis ? box_w : 0,
                                         s->ellipsize, s->wrap);
  fmt->Release();
  if (layout == nullptr) {
    return nullptr;
  }
  if (wrapped_axis && with_align) {
    layout->SetTextAlignment(s->align == 1   ? DWRITE_TEXT_ALIGNMENT_CENTER
                             : s->align == 2 ? DWRITE_TEXT_ALIGNMENT_TRAILING
                                             : DWRITE_TEXT_ALIGNMENT_LEADING);
  }
  for (int i = 0; i < s->nf; i++) {
    // 存的是字节下标，落进布局前换成 UTF-16 码元下标（DWrite 口径）
    DWRITE_TEXT_RANGE range =
        ptw_range(static_cast<int>(ptw_widx(s->text, s->font_ranges[i].start)),
                  static_cast<int>(ptw_widx(s->text, s->font_ranges[i].end)));
    const wchar_t *fam = s->font_fam_storage[i];
    if (fam != nullptr && fam[0] != L'\0') {
      layout->SetFontFamilyName(fam, range);
    }
    if (s->font_ranges[i].size > 0.0) {
      layout->SetFontSize(static_cast<FLOAT>(s->font_ranges[i].size), range);
    }
    layout->SetFontWeight(ptw_weight(s->font_ranges[i].weight), range);
    layout->SetFontStyle(ptw_style(s->font_ranges[i].italic), range);
  }
  return layout;
}

extern "C" int64_t rt_new(const char *text, int tlen, double size,
                          const char *family, int flen, int weight, int italic) {
  if (text == nullptr || tlen < 0 || family == nullptr || flen < 0) {
    return 0;
  }
  PtwSession *s = static_cast<PtwSession *>(calloc(1, sizeof(PtwSession)));
  if (s == nullptr) {
    return 0;
  }
  s->text = static_cast<char *>(malloc(size_t(tlen) + 1));
  s->family = static_cast<char *>(malloc(size_t(flen) + 1));
  if (s->text == nullptr || s->family == nullptr) {
    ptw_session_drop(s);
    return 0;
  }
  memcpy(s->text, text, size_t(tlen));
  s->text[tlen] = '\0';
  s->tlen = tlen;
  memcpy(s->family, family, size_t(flen));
  s->family[flen] = '\0';
  s->size = size;
  s->weight = weight;
  s->italic = italic;
  s->align = 0;
  s->valign = 0;
  s->wrap = 1;
  s->ellipsize = 0;
  const int64_t h = ptw_session_put(s);
  if (h == 0) {
    ptw_session_drop(s);
  }
  return h;
}

extern "C" void rt_free(int64_t h) {
  if (h <= 0 || h > PTW_RT_MAX || ptw_sessions[h - 1] == nullptr) {
    return;
  }
  ptw_session_drop(ptw_sessions[h - 1]);
  ptw_sessions[h - 1] = nullptr;
}

extern "C" void rt_set_text(int64_t h, const char *text, int len) {
  PtwSession *s = ptw_session_of(h);
  if (s == nullptr || text == nullptr || len < 0) {
    return;
  }
  char *copy = static_cast<char *>(malloc(size_t(len) + 1));
  if (copy == nullptr) {
    return;
  }
  memcpy(copy, text, size_t(len));
  copy[len] = '\0';
  free(s->text);
  s->text = copy;
  s->tlen = len;
}

extern "C" void rt_set_font(int64_t h, const char *family, int flen, double size,
                            int weight, int italic) {
  PtwSession *s = ptw_session_of(h);
  if (s == nullptr || family == nullptr || flen < 0) {
    return;
  }
  char *copy = static_cast<char *>(malloc(size_t(flen) + 1));
  if (copy == nullptr) {
    return;
  }
  memcpy(copy, family, size_t(flen));
  copy[flen] = '\0';
  free(s->family);
  s->family = copy;
  s->size = size;
  s->weight = weight;
  s->italic = italic;
}

extern "C" void rt_set_format(int64_t h, int align, int valign, int wrap,
                              int ellipsize) {
  PtwSession *s = ptw_session_of(h);
  if (s == nullptr) {
    return;
  }
  s->align = align;
  s->valign = valign;
  s->wrap = wrap;
  s->ellipsize = ellipsize;
}

extern "C" void rt_add_color(int64_t h, int start, int end, int r, int g, int b,
                             int a) {
  PtwSession *s = ptw_session_of(h);
  if (s == nullptr || s->nc >= PTW_RT_RANGES) {
    return;
  }
  PtwColorRange *c = &s->colors[s->nc++];
  c->start = start;
  c->end = end;
  c->r = r;
  c->g = g;
  c->b = b;
  c->a = a;
}

extern "C" void rt_add_font(int64_t h, int start, int end, const char *family,
                            int flen, double size, int weight, int italic) {
  PtwSession *s = ptw_session_of(h);
  if (s == nullptr || s->nf >= PTW_RT_RANGES || family == nullptr || flen < 0) {
    return;
  }
  wchar_t *wfam = ptw_wide(family, flen);
  PtwFontRange *fr = &s->font_ranges[s->nf];
  fr->start = start;
  fr->end = end;
  fr->family = wfam;
  fr->size = size;
  fr->weight = weight;
  fr->italic = italic;
  s->font_fam_storage[s->nf] = wfam;
  s->nf++;
}

extern "C" int rt_measure(int64_t h, double box_w, int32_t *out_w,
                          int32_t *out_h, int32_t *out_baseline) {
  PtwSession *s = ptw_session_of(h);
  if (s == nullptr || out_w == nullptr || out_h == nullptr ||
      out_baseline == nullptr) {
    return 0;
  }
  IDWriteTextLayout *layout =
      ptw_session_layout(s, static_cast<int>(box_w), false);
  if (layout == nullptr) {
    return 0;
  }
  DWRITE_TEXT_METRICS tm;
  if (FAILED(layout->GetMetrics(&tm))) {
    layout->Release();
    return 0;
  }
  FLOAT baseline = 0.0f;
  DWRITE_LINE_METRICS lm;
  UINT32 got = 0;
  if (SUCCEEDED(layout->GetLineMetrics(&lm, 1, &got)) && got >= 1) {
    baseline = lm.baseline;
  }
  layout->Release();
  *out_w = static_cast<int32_t>(tm.width + 0.5f);
  *out_h = static_cast<int32_t>(tm.height + 0.5f);
  *out_baseline = static_cast<int32_t>(baseline + 0.5f);
  return 1;
}

extern "C" int rt_draw(int64_t h, unsigned char *data, int buf_w, int buf_h,
                       double x, double y, double box_w, double box_h, int r0,
                       int g0, int b0, int a0) {
  PtwSession *s = ptw_session_of(h);
  if (s == nullptr || data == nullptr || buf_w < 1 || buf_h < 1) {
    return 0;
  }
  IDWriteTextLayout *layout =
      ptw_session_layout(s, static_cast<int>(box_w), true);
  if (layout == nullptr) {
    return 0;
  }
  double dx = 0.0;
  double dy = 0.0;
  const int wrapped_axis = box_w > 0.0 && (s->wrap != 0 || s->ellipsize != 0);
  ptw_box_offsets(layout, s->align, s->valign, box_w, box_h, wrapped_axis, &dx,
                  &dy);
  // 区间颜色同样要把字节下标换成 UTF-16 码元下标（DWRITE_TEXT_RANGE 口径）
  PtwColorRange wcolors[PTW_RT_RANGES];
  const int nc = s->nc < PTW_RT_RANGES ? s->nc : PTW_RT_RANGES;
  for (int i = 0; i < nc; i++) {
    wcolors[i] = s->colors[i];
    wcolors[i].start = static_cast<int>(ptw_widx(s->text, s->colors[i].start));
    wcolors[i].end = static_cast<int>(ptw_widx(s->text, s->colors[i].end));
  }
  const int ok = ptw_render(layout, static_cast<float>(x + dx),
                            static_cast<float>(y + dy), data, buf_w, buf_h, r0,
                            g0, b0, a0, nc > 0 ? wcolors : nullptr, nc, nullptr,
                            0, 0);
  layout->Release();
  return ok;
}

extern "C" int rt_draw_cr(int64_t cr_id, int64_t h, double x, double y,
                          double box_w, double box_h, int r0, int g0, int b0,
                          int a0) {
  (void)cr_id; (void)h; (void)x; (void)y; (void)box_w; (void)box_h; (void)r0;
  (void)g0; (void)b0; (void)a0;
  return 0; // Windows 无 cairo 会话（同 pt_draw_box_cr）
}

extern "C" int pt_render_stats(int64_t *calls, int64_t *prep_us,
                               int64_t *d2d_us, int64_t *read_us) {
  if (calls != nullptr) {
    *calls = g_st_calls;
  }
  if (prep_us != nullptr) {
    *prep_us = g_st_prep_us;
  }
  if (d2d_us != nullptr) {
    *d2d_us = g_st_d2d_us;
  }
  if (read_us != nullptr) {
    *read_us = g_st_read_us;
  }
  return 1;
}

#endif // _WIN32
