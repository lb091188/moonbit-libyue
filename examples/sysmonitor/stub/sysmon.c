/* sysmonitor 应用 native-stub：监控数据层与进程管理的系统调用入口。
   符号全在 libc / kernel32 默认链接范围内，零 shim / fork / vendored /
   链接参数改动；机制与实测见 docs/zh/adaptation.md。
   平台分工：Linux / macOS 读文件 / kill / 优先级 / 目录枚举 / sysconf 走
   POSIX；Windows 无 /proc、/sys，Win32 数据源（GetSystemTimes、
   GlobalMemoryStatusEx、PDH、DXGI、GetIfTable2、EnumProcesses 等）在
   读取入口虚拟出与 Linux 同构的文本，MoonBit 数据层与解析纯函数零改动；
   进程管理语义归一（SYS2）：Windows 侧 kill 映射 TerminateProcess 一档、
   优先级映射 IDLE/NORMAL/HIGH/REALTIME 四档，Win32 错误码先译成 errno
   编号再返回（errno_text 与 Result 形态在 MoonBit 层零改动）；
   非默认链接的系统库（pdh / dxgi / iphlpapi / psapi / ntdll）一律运行期
   LoadLibrary 取函数指针，不新增任何链接参数。 */

#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0A00
#endif
#ifndef WINVER
#define WINVER 0x0A00
#endif

#include <moonbit.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#define SYSMON_MAX_FILE_BYTES (16 * 1024 * 1024)

/* 通用 fopen 读取（三平台共用实现，定义在文件末尾）。 */
static moonbit_bytes_t sysmon_read_file_generic(moonbit_bytes_t path);

#if defined(_WIN32)

/* ===========================================================================
   Windows 分支：Win32 数据源 → 虚拟 /proc、/sys 文本。
   路由总表（MoonBit 数据层请求路径 → 数据源）：
     /proc/stat                              GetSystemTimes + ntdll 每核时间
     /proc/cpuinfo                           注册表型号/主频 + 逻辑核枚举
     /proc/meminfo                           GlobalMemoryStatusEx
     /proc/mounts                            GetLogicalDrives+卷信息
     /proc/diskstats                         PDH PhysicalDisk 原始累计字节
     /proc/[pid]/stat                        快照+GetProcessTimes+工作集
     /proc/[pid]/cmdline                     QueryFullProcessImageName
     /sys/class/net[/网卡/字节计数]           GetIfTable2
     /sys/class/hwmon[/hwmonN/...]           nvidia-smi 子进程
     /sys/bus/pci/devices[/地址/...]          DXGI 枚举 + PDH GPU Engine
   =========================================================================== */

#include <windows.h>
#include <pdh.h>
#include <tlhelp32.h>
#include <winreg.h>
#include <iphlpapi.h>

#define SYSMON_ERR_PENDING 0xC0000004UL /* STATUS_INFO_LENGTH_MISMATCH */

/* ---------------- 小工具：缓冲 / 宽窄转换 / 交付 ---------------- */

typedef struct {
  char *p;
  size_t len;
  size_t cap;
} SysmonBuf;

static int sysmon_buf_reserve(SysmonBuf *b, size_t extra) {
  if (b->len + extra + 1 <= b->cap) {
    return 1;
  }
  size_t next = b->cap ? b->cap : 4096;
  while (b->len + extra + 1 > next) {
    next *= 2;
  }
  char *grown = (char *)realloc(b->p, next);
  if (grown == NULL) {
    return 0;
  }
  b->p = grown;
  b->cap = next;
  return 1;
}

static int sysmon_buf_puts(SysmonBuf *b, const char *s) {
  size_t n = strlen(s);
  if (!sysmon_buf_reserve(b, n)) {
    return 0;
  }
  memcpy(b->p + b->len, s, n);
  b->len += n;
  b->p[b->len] = '\0';
  return 1;
}

static int sysmon_buf_putf(SysmonBuf *b, const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  int need = vsnprintf(NULL, 0, fmt, ap);
  va_end(ap);
  if (need < 0 || !sysmon_buf_reserve(b, (size_t)need)) {
    return 0;
  }
  va_start(ap, fmt);
  vsnprintf(b->p + b->len, (size_t)need + 1, fmt, ap);
  va_end(ap);
  b->len += (size_t)need;
  return 1;
}

static moonbit_bytes_t sysmon_bytes_take(SysmonBuf *b) {
  if (b->p == NULL) {
    return NULL;
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)b->len, 0);
  if (out == NULL) {
    free(b->p);
    b->p = NULL;
    return NULL;
  }
  memcpy(out, b->p, b->len);
  free(b->p);
  b->p = NULL;
  return out;
}

/* UTF-8 ↔ UTF-16；失败返回 NULL。返回 malloc 缓冲，调用方 free。 */
static wchar_t *sysmon_utf8_to_wide(const char *s) {
  int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
  if (n <= 0) {
    return NULL;
  }
  wchar_t *w = (wchar_t *)malloc((size_t)n * sizeof(wchar_t));
  if (w == NULL) {
    return NULL;
  }
  if (MultiByteToWideChar(CP_UTF8, 0, s, -1, w, n) <= 0) {
    free(w);
    return NULL;
  }
  return w;
}

static char *sysmon_wide_to_utf8(const wchar_t *w) {
  int n = WideCharToMultiByte(CP_UTF8, 0, w, -1, NULL, 0, NULL, NULL);
  if (n <= 0) {
    return NULL;
  }
  char *s = (char *)malloc((size_t)n);
  if (s == NULL) {
    return NULL;
  }
  if (WideCharToMultiByte(CP_UTF8, 0, w, -1, s, n, NULL, NULL) <= 0) {
    free(s);
    return NULL;
  }
  return s;
}

static void sysmon_dll_load(const char *name, HMODULE *out) {
  if (*out == NULL) {
    *out = LoadLibraryA(name);
  }
}

static FARPROC sysmon_sym(HMODULE mod, const char *name) {
  return mod ? GetProcAddress(mod, name) : NULL;
}

/* ---------------- 单调时钟（QueryPerformanceCounter，秒） ---------------- */

MOONBIT_FFI_EXPORT
double yue_sysmon_monotonic(void) {
  LARGE_INTEGER f, c;
  if (!QueryPerformanceFrequency(&f) || f.QuadPart <= 0 ||
      !QueryPerformanceCounter(&c)) {
    return 0.0;
  }
  return (double)c.QuadPart / (double)f.QuadPart;
}

/* ---------------- CPU：/proc/stat ---------------- */

static unsigned long long sysmon_ft_ticks(const FILETIME *ft) {
  /* FILETIME 100ns → 10ms tick（clk_tck=100，与虚拟 /proc/[pid]/stat 一致） */
  ULARGE_INTEGER u;
  u.LowPart = ft->dwLowDateTime;
  u.HighPart = ft->dwHighDateTime;
  return u.QuadPart / 100000ULL;
}

typedef LONG(WINAPI *NtQuerySystemInformationFn)(ULONG, void *, ULONG, ULONG *);

/* 每逻辑核时间（ntdll SystemProcessorPerformanceInformation=8，每项 6 个
   8 字节字段，stride 恒 48；kernel 同 GetSystemTimes 含 idle）。 */
typedef struct {
  LONGLONG idle;
  LONGLONG kernel;
  LONGLONG user;
  LONGLONG dpc;
  LONGLONG interrupt;
  ULONG interrupt_count;
} SysmonPerCoreTimes;

static moonbit_bytes_t sysmon_read_proc_stat(void) {
  FILETIME idle, kernel, user;
  if (!GetSystemTimes(&idle, &kernel, &user)) {
    return NULL;
  }
  SysmonBuf b = {0};
  unsigned long long t_idle = sysmon_ft_ticks(&idle);
  unsigned long long t_ker = sysmon_ft_ticks(&kernel);
  unsigned long long t_usr = sysmon_ft_ticks(&user);
  unsigned long long t_sys = t_ker > t_idle ? t_ker - t_idle : 0;
  /* nice / iowait / irq / softirq / steal 在 Windows 无对应，恒 0 */
  if (!sysmon_buf_putf(&b, "cpu %llu 0 %llu %llu 0 0 0 0 0 0\n", t_usr, t_sys,
                       t_idle)) {
    free(b.p);
    return NULL;
  }
  HMODULE ntdll = NULL;
  sysmon_dll_load("ntdll.dll", &ntdll);
  NtQuerySystemInformationFn qsi =
      (NtQuerySystemInformationFn)(uintptr_t)sysmon_sym(
          ntdll, "NtQuerySystemInformation");
  if (qsi != NULL) {
    ULONG cap = (ULONG)(sizeof(SysmonPerCoreTimes) * 256);
    for (;;) {
      SysmonPerCoreTimes *cores = (SysmonPerCoreTimes *)malloc(cap);
      if (cores == NULL) {
        break;
      }
      ULONG ret = 0;
      LONG st = qsi(8 /* SystemProcessorPerformanceInformation */, cores, cap,
                    &ret);
      if (st == (LONG)SYSMON_ERR_PENDING && ret > cap) {
        free(cores);
        cap = ret;
        continue;
      }
      if (st >= 0 && ret >= sizeof(SysmonPerCoreTimes)) {
        ULONG n = ret / (ULONG)sizeof(SysmonPerCoreTimes);
        for (ULONG i = 0; i < n; i++) {
          unsigned long long ci =
              (unsigned long long)cores[i].idle / 100000ULL;
          unsigned long long ck =
              (unsigned long long)cores[i].kernel / 100000ULL;
          unsigned long long cu = (unsigned long long)cores[i].user / 100000ULL;
          unsigned long long cs = ck > ci ? ck - ci : 0;
          if (!sysmon_buf_putf(&b, "cpu%lu %llu 0 %llu %llu 0 0 0 0 0 0\n",
                               (unsigned long)i, cu, cs, ci)) {
            break;
          }
        }
      }
      free(cores);
      break;
    }
  }
  return sysmon_bytes_take(&b);
}

/* ---------------- CPU：/proc/cpuinfo ---------------- */

static moonbit_bytes_t sysmon_read_cpuinfo(void) {
  char model[256] = "(未知处理器)";
  unsigned long mhz = 0;
  DWORD name_len = (DWORD)sizeof(model);
  DWORD mhz_len = (DWORD)sizeof(mhz);
  RegGetValueA(HKEY_LOCAL_MACHINE,
               "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0",
               "ProcessorNameString", RRF_RT_REG_SZ, NULL, model, &name_len);
  RegGetValueA(HKEY_LOCAL_MACHINE,
               "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0", "~MHz",
               RRF_RT_REG_DWORD, NULL, &mhz, &mhz_len);
  /* 逻辑核数：默认 GetSystemInfo（≤64 组一次拿全），超 64 核按
     GetLogicalProcessorInformationEx 的活动处理器组求和修正 */
  SYSTEM_INFO si;
  GetSystemInfo(&si);
  int cores = (int)si.dwNumberOfProcessors;
  typedef BOOL(WINAPI * GetLogicalProcessorInformationExFn)(ULONG, void *,
                                                           DWORD *);
  HMODULE k32 = GetModuleHandleA("kernel32.dll");
  GetLogicalProcessorInformationExFn glpie =
      (GetLogicalProcessorInformationExFn)(uintptr_t)sysmon_sym(
          k32, "GetLogicalProcessorInformationEx");
  if (glpie != NULL) {
    DWORD need = 0;
    /* RelationGroup=3：活动组内活动逻辑处理器计数之和 */
    if (!glpie(3, NULL, &need) && need > 0) {
      unsigned char *buf = (unsigned char *)malloc(need);
      if (buf != NULL && glpie(3, buf, &need)) {
        unsigned char *it = buf;
        unsigned char *end = buf + need;
        int total = 0;
        while (it + 8 <= end) {
          ULONG rel = *(ULONG *)it;
          ULONG size = *(ULONG *)(it + 4);
          if (size == 0 || it + size > end) {
            break;
          }
          if (rel == 3) {
            /* GROUP_RELATIONSHIP：ActiveGroupCount 在 +8（WORD），
               PROCESSOR_GROUP_INFO[0].ActiveProcessorCount 在 +32+1；
               两处偏移按 winnt.h 固定布局 */
            unsigned short groups = *(unsigned short *)(it + 8);
            if (groups > 0 && it + size >= it + 32 + 64 * (size_t)groups) {
              for (unsigned short g = 0; g < groups; g++) {
                total += *(unsigned char *)(it + 32 + 64 * (size_t)g + 1);
              }
            }
          }
          it += size;
        }
        if (total > 0) {
          cores = total;
        }
      }
      free(buf);
    }
  }
  SysmonBuf b = {0};
  for (int i = 0; i < cores; i++) {
    if (!sysmon_buf_putf(&b,
                         "processor\t: %d\nmodel name\t: %s\ncpu MHz\t\t: %lu\n"
                         "cache size\t: 0 KB\n\n",
                         i, model, mhz)) {
      break;
    }
  }
  return sysmon_bytes_take(&b);
}

/* ---------------- 内存：/proc/meminfo ---------------- */

static moonbit_bytes_t sysmon_read_meminfo(void) {
  MEMORYSTATUSEX ms;
  memset(&ms, 0, sizeof(ms));
  ms.dwLength = sizeof(ms);
  if (!GlobalMemoryStatusEx(&ms)) {
    return NULL;
  }
  SysmonBuf b = {0};
  unsigned long long total_kb = ms.ullTotalPhys / 1024ULL;
  unsigned long long avail_kb = ms.ullAvailPhys / 1024ULL;
  unsigned long long swap_total_kb = ms.ullTotalPageFile / 1024ULL;
  unsigned long long swap_free_kb = ms.ullAvailPageFile / 1024ULL;
  if (!sysmon_buf_putf(
          &b,
          "MemTotal:       %llu kB\nMemFree:        %llu kB\n"
          "MemAvailable:   %llu kB\nBuffers:               0 kB\n"
          "Cached:                0 kB\nSwapTotal:      %llu kB\n"
          "SwapFree:       %llu kB\n",
          total_kb, avail_kb, avail_kb, swap_total_kb, swap_free_kb)) {
    free(b.p);
    return NULL;
  }
  return sysmon_bytes_take(&b);
}

/* ---------------- 磁盘：/proc/mounts ---------------- */

static moonbit_bytes_t sysmon_read_mounts(void) {
  SysmonBuf b = {0};
  DWORD drives = GetLogicalDrives();
  for (int i = 0; i < 26; i++) {
    if (!(drives & (1u << i))) {
      continue;
    }
    wchar_t root[4] = {L'A' + (wchar_t)i, L':', L'\\', 0};
    UINT t = GetDriveTypeW(root);
    /* 只收固定盘与可移动盘；光驱（读盘噪音）与网络映射盘跳过 */
    if (t != DRIVE_FIXED && t != DRIVE_REMOVABLE) {
      continue;
    }
    wchar_t fs[64] = L"unknown";
    DWORD fs_flags = 0;
    GetVolumeInformationW(root, NULL, 0, NULL, NULL, &fs_flags, fs, 64);
    char *fsu = sysmon_wide_to_utf8(fs);
    if (fsu == NULL) {
      continue;
    }
    int ok = sysmon_buf_putf(&b, "/dev/%c: %c:\\ %s rw 0 0 0 0\n", 'A' + i,
                             'A' + i, fsu);
    free(fsu);
    if (!ok) {
      break;
    }
  }
  return sysmon_bytes_take(&b);
}

/* ---------------- 磁盘：/proc/diskstats（PDH PhysicalDisk） ---------------- */

typedef struct {
  HMODULE pdh;
  LONG(WINAPI * open_query)(const wchar_t *, DWORD_PTR, void **);
  LONG(WINAPI * add_english)(void *, const wchar_t *, DWORD_PTR, void **);
  LONG(WINAPI * collect)(void *);
  LONG(WINAPI * get_raw_array)(void *, DWORD *, DWORD *, void *);
  LONG(WINAPI * get_fmt_array)(void *, DWORD, DWORD *, DWORD *, void *);
  LONG(WINAPI * close_query)(void *);
} SysmonPdh;

static SysmonPdh g_pdh = {0};

static int sysmon_pdh_ready(void) {
  if (g_pdh.open_query != NULL) {
    return 1;
  }
  sysmon_dll_load("pdh.dll", &g_pdh.pdh);
  g_pdh.open_query =
      (LONG(WINAPI *)(const wchar_t *, DWORD_PTR, void **))(uintptr_t)sysmon_sym(
          g_pdh.pdh, "PdhOpenQueryW");
  if (g_pdh.open_query == NULL) {
    return 0;
  }
  g_pdh.add_english =
      (LONG(WINAPI *)(void *, const wchar_t *, DWORD_PTR, void **))(uintptr_t)
          sysmon_sym(g_pdh.pdh, "PdhAddEnglishCounterW");
  g_pdh.collect = (LONG(WINAPI *)(void *))(uintptr_t)sysmon_sym(
      g_pdh.pdh, "PdhCollectQueryData");
  g_pdh.get_raw_array =
      (LONG(WINAPI *)(void *, DWORD *, DWORD *, void *))(uintptr_t)sysmon_sym(
          g_pdh.pdh, "PdhGetRawCounterArrayW");
  g_pdh.get_fmt_array = (LONG(WINAPI *)(void *, DWORD, DWORD *, DWORD *,
                                        void *))(uintptr_t)sysmon_sym(
      g_pdh.pdh, "PdhGetFormattedCounterArrayW");
  g_pdh.close_query = (LONG(WINAPI *)(void *))(uintptr_t)sysmon_sym(
      g_pdh.pdh, "PdhCloseQuery");
  return g_pdh.add_english != NULL && g_pdh.collect != NULL &&
         g_pdh.get_raw_array != NULL && g_pdh.get_fmt_array != NULL &&
         g_pdh.close_query != NULL;
}

/* PDH 通配计数器的实例值数组（PdhGetRawCounterArrayW 两段式取）。
   成功返回 malloc 数组，*count 为实例数；失败返回 NULL。 */
static void *sysmon_pdh_raw_array(void *counter, DWORD *count) {
  DWORD size = 0;
  if (g_pdh.get_raw_array(counter, &size, NULL, NULL) != PDH_MORE_DATA ||
      size == 0) {
    return NULL;
  }
  void *buf = malloc(size);
  if (buf == NULL) {
    return NULL;
  }
  if (g_pdh.get_raw_array(counter, &size, count, buf) != 0) {
    free(buf);
    return NULL;
  }
  return buf;
}

/* 实例名（如 "0 C:"）提取盘符名：取最后一个空格后的部分；无空格或为
   "_Total" 返回 NULL。返回 malloc 窄字符串。 */
static char *sysmon_pdh_disk_name(const wchar_t *instance) {
  const wchar_t *sp = NULL;
  for (const wchar_t *p = instance; *p; p++) {
    if (*p == L' ') {
      sp = p;
    }
  }
  if (sp == NULL || sp[1] == L'\0') {
    return NULL;
  }
  if (wcscmp(sp + 1, L"_Total") == 0) {
    return NULL;
  }
  return sysmon_wide_to_utf8(sp + 1);
}

typedef struct {
  DWORD count;
  PDH_RAW_COUNTER_ITEM_W *items;
} SysmonRawArray;

static moonbit_bytes_t sysmon_read_diskstats(void) {
  if (!sysmon_pdh_ready()) {
    return NULL;
  }
  void *query = NULL;
  if (g_pdh.open_query(NULL, 0, &query) != 0) {
    return NULL;
  }
  void *cr = NULL;
  void *cw = NULL;
  moonbit_bytes_t out = NULL;
  if (g_pdh.add_english(query, L"\\PhysicalDisk(*)\\Disk Read Bytes", 0,
                        &cr) == 0 &&
      g_pdh.add_english(query, L"\\PhysicalDisk(*)\\Disk Write Bytes", 0,
                        &cw) == 0 &&
      g_pdh.collect(query) == 0) {
    SysmonRawArray ar = {0};
    SysmonRawArray aw = {0};
    ar.items = (PDH_RAW_COUNTER_ITEM_W *)sysmon_pdh_raw_array(cr, &ar.count);
    aw.items = (PDH_RAW_COUNTER_ITEM_W *)sysmon_pdh_raw_array(cw, &aw.count);
    if (ar.items != NULL && aw.items != NULL) {
      SysmonBuf b = {0};
      for (DWORD i = 0; i < ar.count; i++) {
        char *name = sysmon_pdh_disk_name(ar.items[i].szName);
        if (name == NULL) {
          continue;
        }
        /* 对位同实例的写计数（实例数小，线性查找足够） */
        LONGLONG written = 0;
        int found = 0;
        for (DWORD j = 0; j < aw.count; j++) {
          if (wcscmp(ar.items[i].szName, aw.items[j].szName) == 0) {
            written = aw.items[j].RawValue.FirstValue;
            found = 1;
            break;
          }
        }
        if (found) {
          LONGLONG read_sectors = ar.items[i].RawValue.FirstValue;
          if (!sysmon_buf_putf(&b,
                               "8 0 %s 0 0 %lld 0 0 0 %lld 0 0 0 0 0\n", name,
                               read_sectors / 512, written / 512)) {
            free(name);
            break;
          }
        }
        free(name);
      }
      out = sysmon_bytes_take(&b);
    }
    free(ar.items);
    free(aw.items);
  }
  g_pdh.close_query(query);
  return out;
}

/* ---------------- 磁盘：statvfs → GetDiskFreeSpaceExW ---------------- */

MOONBIT_FFI_EXPORT
int32_t yue_sysmon_statvfs(
    moonbit_bytes_t path,
    int64_t *out_total,
    int64_t *out_free,
    int64_t *out_avail) {
  wchar_t *w = sysmon_utf8_to_wide((const char *)path);
  if (w == NULL) {
    return 3; /* ENOENT */
  }
  ULARGE_INTEGER total, freeb, avail;
  int ok = GetDiskFreeSpaceExW(w, &avail, &total, &freeb);
  free(w);
  if (!ok) {
    return 2; /* ENOENT 类失败（盘不存在 / 无介质） */
  }
  *out_total = (int64_t)total.QuadPart;
  *out_free = (int64_t)freeb.QuadPart;
  *out_avail = (int64_t)avail.QuadPart;
  return 0;
}

/* ---------------- 网络：GetIfTable2 ---------------- */

typedef struct {
  HMODULE iphlpapi;
  ULONG(WINAPI * get_if_table2)(void **);
  void(WINAPI * free_mib_table)(void *);
} SysmonIpHelper;

static SysmonIpHelper g_iph = {0};

static int sysmon_iph_ready(void) {
  if (g_iph.get_if_table2 != NULL) {
    return 1;
  }
  sysmon_dll_load("iphlpapi.dll", &g_iph.iphlpapi);
  g_iph.get_if_table2 = (ULONG(WINAPI *)(void **))(uintptr_t)sysmon_sym(
      g_iph.iphlpapi, "GetIfTable2");
  g_iph.free_mib_table = (void(WINAPI *)(void *))(uintptr_t)sysmon_sym(
      g_iph.iphlpapi, "FreeMibTable");
  return g_iph.get_if_table2 != NULL && g_iph.free_mib_table != NULL;
}

/* 全接口表缓存（200ms TTL）：每块网卡的 rx/tx 各读一次路径，避免同拍
   反复全表拉取。仅主线程定时器访问，无需锁。 */
static void *g_if_table = NULL;
static ULONGLONG g_if_table_at = 0;

static void *sysmon_if_table_cached(void) {
  if (!sysmon_iph_ready()) {
    return NULL;
  }
  ULONGLONG now = GetTickCount64();
  if (g_if_table != NULL && now - g_if_table_at < 200) {
    return g_if_table;
  }
  if (g_if_table != NULL) {
    g_iph.free_mib_table(g_if_table);
    g_if_table = NULL;
  }
  void *tab = NULL;
  if (g_iph.get_if_table2(&tab) != 0 || tab == NULL) {
    return NULL;
  }
  g_if_table = tab;
  g_if_table_at = now;
  return g_if_table;
}

static moonbit_bytes_t sysmon_list_netifs(void) {
  MIB_IF_TABLE2 *tab = (MIB_IF_TABLE2 *)sysmon_if_table_cached();
  if (tab == NULL) {
    return NULL;
  }
  SysmonBuf b = {0};
  for (ULONG i = 0; i < tab->NumEntries; i++) {
    const MIB_IF_ROW2 *r = &tab->Table[i];
    char *name = NULL;
    if (r->Type == IF_TYPE_SOFTWARE_LOOPBACK) {
      name = sysmon_wide_to_utf8(L"lo");
    } else {
      name = sysmon_wide_to_utf8(r->InterfaceAlias);
    }
    if (name == NULL || name[0] == '\0') {
      free(name);
      continue;
    }
    int ok = sysmon_buf_puts(&b, name) && sysmon_buf_puts(&b, "\n");
    free(name);
    if (!ok) {
      break;
    }
  }
  return sysmon_bytes_take(&b);
}

/* /sys/class/net/<alias>/statistics/{rx,tx}_bytes → InOctets / OutOctets。 */
static moonbit_bytes_t sysmon_read_netif_bytes(const char *path) {
  const char *head = "/sys/class/net/";
  const char *p = strstr(path, head);
  if (p == NULL) {
    return NULL;
  }
  p += strlen(head);
  const char *dir = strstr(p, "/statistics/");
  if (dir == NULL || dir == p) {
    return NULL;
  }
  int rx = strcmp(dir, "/statistics/rx_bytes") == 0;
  if (!rx && strcmp(dir, "/statistics/tx_bytes") != 0) {
    return NULL;
  }
  size_t alen = (size_t)(dir - p);
  if (alen >= 256) {
    return NULL;
  }
  char alias[256];
  memcpy(alias, p, alen);
  alias[alen] = '\0';
  MIB_IF_TABLE2 *tab = (MIB_IF_TABLE2 *)sysmon_if_table_cached();
  if (tab == NULL) {
    return NULL;
  }
  for (ULONG i = 0; i < tab->NumEntries; i++) {
    const MIB_IF_ROW2 *r = &tab->Table[i];
    char *name = r->Type == IF_TYPE_SOFTWARE_LOOPBACK
                     ? sysmon_wide_to_utf8(L"lo")
                     : sysmon_wide_to_utf8(r->InterfaceAlias);
    int hit = name != NULL && strcmp(name, alias) == 0;
    free(name);
    if (hit) {
      SysmonBuf b = {0};
      if (!sysmon_buf_putf(&b, "%llu\n",
                           (unsigned long long)(rx ? r->InOctets
                                                   : r->OutOctets))) {
        free(b.p);
        return NULL;
      }
      return sysmon_bytes_take(&b);
    }
  }
  return NULL;
}

/* ---------------- 进程管理语义归一(SYS2) ----------------
   Windows 侧 kill 映射 TerminateProcess 一档、优先级映射
   IDLE/NORMAL/HIGH/REALTIME 四档;Win32 错误码先译成 errno 编号再
   返回,MoonBit 层 errno_text 与 Result 形态零改动。 */

/* Win32 错误码 → 同语义 Linux errno 编号;未列出的归 EIO 兜底。 */
static int32_t sysmon_winerr_to_errno(DWORD err) {
  switch (err) {
  case ERROR_ACCESS_DENIED:
    return 1; /* EPERM */
  case ERROR_FILE_NOT_FOUND:
  case ERROR_PATH_NOT_FOUND:
    return 2; /* ENOENT */
  case ERROR_NOT_ENOUGH_MEMORY:
  case ERROR_OUTOFMEMORY:
    return 12; /* ENOMEM */
  case ERROR_SHARING_VIOLATION:
    return 13; /* EACCES */
  case ERROR_PRIVILEGE_NOT_HELD:
    return 13; /* EACCES:需提权(如 REALTIME 档) */
  case ERROR_INVALID_HANDLE:
    return 9; /* EBADF */
  case ERROR_ALREADY_EXISTS:
    return 17; /* EEXIST */
  case ERROR_BROKEN_PIPE:
    return 32; /* EPIPE */
  case ERROR_INVALID_PARAMETER:
    return 22; /* EINVAL */
  default:
    return 5; /* EIO 兜底 */
  }
}

/* Windows 优先级类 → nice 档位代表值(离散档;BELOW/ABOVE_NORMAL 钳到
   邻档;代表值回设时落回同类或设计邻档)。 */
static int32_t sysmon_class_to_nice(DWORD cls) {
  switch (cls) {
  case IDLE_PRIORITY_CLASS:
    return 19;
  case BELOW_NORMAL_PRIORITY_CLASS:
    return 10;
  case ABOVE_NORMAL_PRIORITY_CLASS:
    return -10;
  case HIGH_PRIORITY_CLASS:
    return -13;
  case REALTIME_PRIORITY_CLASS:
    return -20;
  default:
    return 0; /* NORMAL 及未知类 */
  }
}

/* nice → 四档优先级类(就近钳制:10..19 IDLE / -9..9 NORMAL /
   -16..-10 HIGH / -20..-17 REALTIME)。 */
static DWORD sysmon_nice_to_class(int32_t nice) {
  if (nice >= 10) {
    return IDLE_PRIORITY_CLASS;
  }
  if (nice <= -17) {
    return REALTIME_PRIORITY_CLASS;
  }
  if (nice <= -10) {
    return HIGH_PRIORITY_CLASS;
  }
  return NORMAL_PRIORITY_CLASS;
}

/* OpenProcess 失败统一入口:进程已退出时 Windows 恒报
   ERROR_INVALID_PARAMETER,kill/优先级语义归一为 ESRCH(3)。 */
static int32_t sysmon_openproc_err(void) {
  DWORD err = GetLastError();
  if (err == ERROR_INVALID_PARAMETER) {
    return 3; /* ESRCH:进程不存在或已退出 */
  }
  return sysmon_winerr_to_errno(err);
}

/* ---------------- 进程：枚举 / 快照 / 虚拟 stat 与 cmdline ---------------- */

typedef DWORD(WINAPI * K32EnumProcessesFn)(DWORD *, DWORD, DWORD *);

MOONBIT_FFI_EXPORT
moonbit_bytes_t yue_sysmon_list_pids(void) {
  HMODULE k32 = GetModuleHandleA("kernel32.dll");
  K32EnumProcessesFn ep =
      (K32EnumProcessesFn)(uintptr_t)sysmon_sym(k32, "K32EnumProcesses");
  if (ep == NULL) {
    return NULL;
  }
  DWORD cap = 1024;
  for (;;) {
    DWORD *pids = (DWORD *)malloc(cap * sizeof(DWORD));
    if (pids == NULL) {
      return NULL;
    }
    DWORD needed = 0;
    if (!ep(pids, cap * sizeof(DWORD), &needed)) {
      free(pids);
      return NULL;
    }
    if (needed < cap * sizeof(DWORD) || cap >= 65536) {
      SysmonBuf b = {0};
      for (DWORD i = 0; i < needed / sizeof(DWORD); i++) {
        if (!sysmon_buf_putf(&b, "%lu\n", (unsigned long)pids[i])) {
          break;
        }
      }
      free(pids);
      return sysmon_bytes_take(&b);
    }
    free(pids);
    cap *= 2;
  }
}

typedef struct {
  DWORD pid;
  DWORD ppid;
  DWORD threads;
  wchar_t exe[MAX_PATH];
} SysmonSnapEntry;

static SysmonSnapEntry *g_snap = NULL;
static int g_snap_n = 0;
static ULONGLONG g_snap_at = 0;
#define SYSMON_SNAP_TTL_MS 250

/* Toolhelp32 进程快照（pid / ppid / 线程数 / 镜像名），TTL 内复用。
   ppid 与镜像名单次查询拿不到的（GetProcessTimes 不含），快照一次全有。 */
static int sysmon_snap_refresh(void) {
  ULONGLONG now = GetTickCount64();
  if (g_snap != NULL && now - g_snap_at < SYSMON_SNAP_TTL_MS) {
    return 1;
  }
  free(g_snap);
  g_snap = NULL;
  g_snap_n = 0;
  HANDLE h = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (h == INVALID_HANDLE_VALUE) {
    return 0;
  }
  PROCESSENTRY32W e;
  memset(&e, 0, sizeof(e));
  e.dwSize = sizeof(e);
  int n = 0;
  int cap = 256;
  SysmonSnapEntry *arr = (SysmonSnapEntry *)malloc(
      (size_t)cap * sizeof(SysmonSnapEntry));
  if (arr == NULL) {
    CloseHandle(h);
    return 0;
  }
  if (Process32FirstW(h, &e)) {
    do {
      if (n == cap) {
        int next = cap * 2;
        SysmonSnapEntry *grown =
            (SysmonSnapEntry *)realloc(arr, (size_t)next * sizeof(SysmonSnapEntry));
        if (grown == NULL) {
          break;
        }
        arr = grown;
        cap = next;
      }
      arr[n].pid = e.th32ProcessID;
      arr[n].ppid = e.th32ParentProcessID;
      arr[n].threads = e.cntThreads;
      memset(arr[n].exe, 0, sizeof(arr[n].exe));
      for (int i = 0; i < MAX_PATH && e.szExeFile[i]; i++) {
        arr[n].exe[i] = e.szExeFile[i];
      }
      n++;
    } while (Process32NextW(h, &e));
  }
  CloseHandle(h);
  g_snap = arr;
  g_snap_n = n;
  g_snap_at = now;
  return 1;
}

static SysmonSnapEntry *sysmon_snap_lookup(DWORD pid) {
  for (int i = 0; i < g_snap_n; i++) {
    if (g_snap[i].pid == pid) {
      return &g_snap[i];
    }
  }
  return NULL;
}

typedef BOOL(WINAPI * K32GetProcessMemoryInfoFn)(HANDLE, void *, DWORD);

static moonbit_bytes_t sysmon_read_pid_stat(DWORD pid) {
  if (!sysmon_snap_refresh()) {
    return NULL;
  }
  SysmonSnapEntry *e = sysmon_snap_lookup(pid);
  if (e == NULL) {
    return NULL;
  }
  unsigned long long utime = 0, stime = 0, start_ticks = 0, rss_pages = 0;
  /* nice 取优先级类的档位代表值(离散档,SYS2 语义归一);系统进程
     OpenProcess 被拒时保持 0(=NORMAL 档) */
  int32_t nice_val = 0;
  HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (h != NULL) {
    FILETIME ct, et, kt, ut;
    if (GetProcessTimes(h, &ct, &et, &kt, &ut)) {
      utime = sysmon_ft_ticks(&ut);
      stime = sysmon_ft_ticks(&kt);
      /* starttime：进程创建时刻距系统启动（GetTickCount64 口径）的 tick 数 */
      ULARGE_INTEGER c64, now64;
      c64.LowPart = ct.dwLowDateTime;
      c64.HighPart = ct.dwHighDateTime;
      FILETIME nowft;
      GetSystemTimeAsFileTime(&nowft);
      now64.LowPart = nowft.dwLowDateTime;
      now64.HighPart = nowft.dwHighDateTime;
      unsigned long long boot64 =
          now64.QuadPart - GetTickCount64() * 10000ULL;
      if (c64.QuadPart > 0 && (unsigned long long)c64.QuadPart > boot64) {
        start_ticks = ((unsigned long long)c64.QuadPart - boot64) / 100000ULL;
      }
    }
    HMODULE k32 = GetModuleHandleA("kernel32.dll");
    K32GetProcessMemoryInfoFn pm =
        (K32GetProcessMemoryInfoFn)(uintptr_t)sysmon_sym(
            k32, "K32GetProcessMemoryInfo");
    if (pm != NULL) {
      /* PROCESS_MEMORY_COUNTERS 布局固定（psapi 自 XP 未变），自定义结构
         免链 psapi */
      typedef struct {
        DWORD cb;
        DWORD PageFaultCount;
        SIZE_T PeakWorkingSetSize;
        SIZE_T WorkingSetSize;
        SIZE_T QuotaPeakPagedPoolUsage;
        SIZE_T QuotaPagedPoolUsage;
        SIZE_T QuotaPeakNonPagedPoolUsage;
        SIZE_T QuotaNonPagedPoolUsage;
        SIZE_T PagefileUsage;
        SIZE_T PeakPagefileUsage;
      } SysmonPmc;
      SysmonPmc mc;
      memset(&mc, 0, sizeof(mc));
      mc.cb = sizeof(mc);
      if (pm(h, &mc, sizeof(mc))) {
        rss_pages = (unsigned long long)mc.WorkingSetSize / 4096ULL;
      }
    }
    DWORD cls = GetPriorityClass(h);
    if (cls != 0) {
      nice_val = sysmon_class_to_nice(cls);
    }
    CloseHandle(h);
  }
  char *name = sysmon_wide_to_utf8(e->exe);
  if (name == NULL) {
    return NULL;
  }
  SysmonBuf b = {0};
  /* 22 个状态后置字段:state ppid pgrp session tty tpgid flags minflt
     cminflt majflt cmajflt utime stime cutime cstime priority nice
     threads itreal starttime vsize rss;nice 为优先级类反查的档位代表
     值(OpenProcess 被拒的系统进程保持 0) */
  int ok = sysmon_buf_putf(
      &b,
      "%lu (%s) S %lu 0 0 0 0 0 0 0 0 0 %llu %llu 0 0 0 %d %lu 0 %llu 0 %llu 0\n",
      (unsigned long)pid, name, (unsigned long)e->ppid, utime, stime,
      nice_val, (unsigned long)e->threads, start_ticks, rss_pages);
  free(name);
  if (!ok) {
    free(b.p);
    return NULL;
  }
  return sysmon_bytes_take(&b);
}

/* /proc/[pid]/cmdline → 镜像全路径（权限不足返回 NULL，MoonBit 层回退
   [comm]）。 */
static moonbit_bytes_t sysmon_read_pid_cmdline(DWORD pid) {
  HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (h == NULL) {
    return NULL;
  }
  char path[MAX_PATH * 2];
  DWORD len = sizeof(path);
  moonbit_bytes_t out = NULL;
  if (QueryFullProcessImageNameA(h, 0, path, &len) && len > 0) {
    SysmonBuf b = {0};
    if (sysmon_buf_puts(&b, path)) {
      out = sysmon_bytes_take(&b);
    }
  }
  CloseHandle(h);
  return out;
}

/* ---------------- GPU：DXGI 枚举 + PDH GPU Engine ---------------- */

typedef struct {
  wchar_t Description[128];
  unsigned int VendorId;
  unsigned int DeviceId;
  unsigned int SubSysId;
  unsigned int Revision;
  unsigned long long DedicatedVideoMemory;
  unsigned long long SharedSystemMemory;
  struct {
    unsigned long LowPart;
    long HighPart;
  } AdapterLuid;
  unsigned int Flags;
} SysmonDxgiDesc1;

typedef struct {
  long long Budget;
  long long CurrentUsage;
  long long AvailableForReservation;
  long long ReservedForReservation;
} SysmonVideoMemoryInfo;

/* COM 接口只取用到的槽位（vtable 前缀按接口继承序固定，二进制 ABI 稳定）；
   IID 为 SDK 公开常量值，自定义免依赖 dxgi.h 版本差异。 */
static const GUID sysmon_IID_IDXGIFactory1 = {
    0x770aae78, 0xf26f, 0x4dba, {0x83, 0xa9, 0x50, 0xbc, 0x11, 0xd9, 0xee, 0x9b}};
static const GUID sysmon_IID_IDXGIAdapter1 = {
    0x290462f0, 0xac1e, 0x4212, {0xaa, 0x25, 0x4f, 0x95, 0xb4, 0x96, 0x8b, 0x12}};
static const GUID sysmon_IID_IDXGIAdapter3 = {
    0x645967a4, 0x1392, 0x4316, {0x9c, 0xec, 0x9c, 0xaf, 0x71, 0x13, 0xf4, 0x20}};

typedef struct {
  LONG(WINAPI *QueryInterface)(void *, const GUID *, void **);
  ULONG(WINAPI *AddRef)(void *);
  ULONG(WINAPI *Release)(void *);
  LONG(WINAPI *SetPrivateData)(void *, const GUID *, unsigned int,
                                  const void *);
  LONG(WINAPI *SetPrivateDataInterface)(void *, const GUID *, const void *);
  LONG(WINAPI *GetPrivateData)(void *, const GUID *, unsigned int *, void *);
  LONG(WINAPI *GetParent)(void *, const GUID *, void **);
  LONG(WINAPI *EnumAdapters)(void *, unsigned int, void **);
  LONG(WINAPI *GetWindowAssociation)(void *, void **);
  LONG(WINAPI *MakeWindowAssociation)(void *, void *, unsigned int);
  LONG(WINAPI *CreateSwapChain)(void *, void *, void *, void **);
  LONG(WINAPI *EnumAdapters1)(void *, unsigned int, void **);
  int(WINAPI *IsCurrent)(void *);
} SysmonFactory1Vtbl;

typedef struct {
  LONG(WINAPI *QueryInterface)(void *, const GUID *, void **);
  ULONG(WINAPI *AddRef)(void *);
  ULONG(WINAPI *Release)(void *);
  LONG(WINAPI *SetPrivateData)(void *, const GUID *, unsigned int,
                                  const void *);
  LONG(WINAPI *SetPrivateDataInterface)(void *, const GUID *, const void *);
  LONG(WINAPI *GetPrivateData)(void *, const GUID *, unsigned int *, void *);
  LONG(WINAPI *GetParent)(void *, const GUID *, void **);
  LONG(WINAPI *GetEnumOutputs)(void *, unsigned int, void **);
  LONG(WINAPI *GetDesc)(void *, void *);
  LONG(WINAPI *CheckInterfaceSupport)(void *, const GUID *, LONGLONG *);
  LONG(WINAPI *GetDesc1)(void *, SysmonDxgiDesc1 *);
  LONG(WINAPI *GetDesc2)(void *, void *);
  LONG(WINAPI *RegisterVideoMemoryBudget)(void *, void *, unsigned int *);
  LONG(WINAPI *UnregisterVideoMemoryBudget)(void *, unsigned int);
  LONG(WINAPI *QueryVideoMemoryInfo)(void *, unsigned int, unsigned int,
                                        SysmonVideoMemoryInfo *);
} SysmonAdapterVtbl;

#define SYSMON_MAX_GPUS 16
#ifndef PDH_MORE_DATA
#define PDH_MORE_DATA 0x800007D2L
#endif
#define SYSMON_DXGI_ADAPTER_FLAG_SOFTWARE 1u

typedef struct {
  unsigned int vendor;
  unsigned int device;
  unsigned long long ded_bytes;
  unsigned long luid_lo;
  long luid_hi;
  char addr[16]; /* 虚拟 pci 地址，如 "0000:00:00.0" */
  char name[256];
} SysmonGpuEntry;

static SysmonGpuEntry g_gpus[SYSMON_MAX_GPUS];
static int g_gpu_n = 0;
static int g_gpu_done = 0;

/* DXGI 适配器枚举（进程内一次，适配件集启动后稳定；软件适配器跳过）。 */
static void sysmon_gpu_enum(void) {
  if (g_gpu_done) {
    return;
  }
  g_gpu_done = 1;
  HMODULE dxgi = NULL;
  sysmon_dll_load("dxgi.dll", &dxgi);
  FARPROC create = sysmon_sym(dxgi, "CreateDXGIFactory1");
  if (create == NULL) {
    return;
  }
  typedef LONG(WINAPI * CreateDXGIFactory1Fn)(const GUID *, void **);
  void *factory = NULL;
  if (((CreateDXGIFactory1Fn)(uintptr_t)create)(
          &sysmon_IID_IDXGIFactory1, &factory) != 0 ||
      factory == NULL) {
    return;
  }
  SysmonFactory1Vtbl *fv = *(SysmonFactory1Vtbl **)factory;
  for (unsigned int i = 0; i < SYSMON_MAX_GPUS; i++) {
    void *adapter = NULL;
    if (fv->EnumAdapters1(factory, i, &adapter) != 0 || adapter == NULL) {
      break;
    }
    SysmonAdapterVtbl *av = *(SysmonAdapterVtbl **)adapter;
    SysmonDxgiDesc1 desc;
    memset(&desc, 0, sizeof(desc));
    if (av->GetDesc1(adapter, &desc) == 0 &&
        !(desc.Flags & SYSMON_DXGI_ADAPTER_FLAG_SOFTWARE)) {
      SysmonGpuEntry *e = &g_gpus[g_gpu_n];
      memset(e, 0, sizeof(*e));
      e->vendor = desc.VendorId;
      e->device = desc.DeviceId;
      e->ded_bytes = desc.DedicatedVideoMemory;
      e->luid_lo = desc.AdapterLuid.LowPart;
      e->luid_hi = desc.AdapterLuid.HighPart;
      snprintf(e->addr, sizeof(e->addr), "0000:00:%02x.0", g_gpu_n);
      char *nm = sysmon_wide_to_utf8(desc.Description);
      if (nm != NULL) {
        snprintf(e->name, sizeof(e->name), "%s", nm);
        free(nm);
      }
      g_gpu_n++;
    }
    av->Release(adapter);
  }
  fv->Release(factory);
}

static SysmonGpuEntry *sysmon_gpu_by_addr(const char *addr) {
  for (int i = 0; i < g_gpu_n; i++) {
    if (strcmp(g_gpus[i].addr, addr) == 0) {
      return &g_gpus[i];
    }
  }
  return NULL;
}

/* /sys/bus/pci/devices/<addr>/{class,vendor,device} */
static moonbit_bytes_t sysmon_read_gpu_id(const char *addr, const char *what) {
  sysmon_gpu_enum();
  SysmonGpuEntry *e = sysmon_gpu_by_addr(addr);
  if (e == NULL) {
    return NULL;
  }
  SysmonBuf b = {0};
  if (strcmp(what, "class") == 0) {
    sysmon_buf_puts(&b, "0x030000\n");
  } else if (strcmp(what, "vendor") == 0) {
    sysmon_buf_putf(&b, "0x%04x\n", e->vendor);
  } else if (strcmp(what, "device") == 0) {
    sysmon_buf_putf(&b, "0x%04x\n", e->device);
  } else {
    free(b.p);
    return NULL;
  }
  return sysmon_bytes_take(&b);
}

static moonbit_bytes_t sysmon_list_gpu_devices(void) {
  sysmon_gpu_enum();
  if (g_gpu_n == 0) {
    return NULL;
  }
  SysmonBuf b = {0};
  for (int i = 0; i < g_gpu_n; i++) {
    if (!sysmon_buf_puts(&b, g_gpus[i].addr) || !sysmon_buf_puts(&b, "\n")) {
      break;
    }
  }
  return sysmon_bytes_take(&b);
}

/* GPU Engine 利用率（PDH，静态查询句柄跨拍保持：Utilization Percentage
   需两次采样才出有效格式化值，首拍全 0）。按适配器 LUID 过滤实例求和。 */
static double sysmon_gpu_engine_util(unsigned long luid_lo, long luid_hi) {
  if (!sysmon_pdh_ready()) {
    return -1.0;
  }
  static void *query = NULL;
  static void *counter = NULL;
  if (query == NULL) {
    if (g_pdh.open_query(NULL, 0, &query) != 0 ||
        g_pdh.add_english(query, L"\\GPU Engine(*)\\Utilization Percentage", 0,
                          &counter) != 0) {
      query = NULL;
      return -1.0;
    }
  }
  if (g_pdh.collect(query) != 0) {
    return -1.0;
  }
  DWORD size = 0;
  DWORD count = 0;
  if (g_pdh.get_fmt_array(counter, PDH_FMT_DOUBLE, &size, NULL, NULL) !=
          PDH_MORE_DATA ||
      size == 0) {
    return -1.0;
  }
  PDH_FMT_COUNTERVALUE_ITEM_W *items =
      (PDH_FMT_COUNTERVALUE_ITEM_W *)malloc(size);
  if (items == NULL) {
    return -1.0;
  }
  double sum = -1.0;
  if (g_pdh.get_fmt_array(counter, PDH_FMT_DOUBLE, &size, &count, items) == 0) {
    for (DWORD i = 0; i < count; i++) {
      if (items[i].FmtValue.CStatus != 0 || items[i].szName == NULL) {
        continue;
      }
      const wchar_t *p = wcsstr(items[i].szName, L"luid_");
      if (p == NULL) {
        continue;
      }
      unsigned int hi = 0, lo = 0;
      if (swscanf(p, L"luid_%x_%x", &hi, &lo) != 2) {
        continue;
      }
      if ((long)hi == luid_hi && lo == luid_lo) {
        sum = sum < 0.0 ? items[i].FmtValue.doubleValue
                        : sum + items[i].FmtValue.doubleValue;
      }
    }
  }
  free(items);
  if (sum < 0.0) {
    return -1.0;
  }
  return sum > 100.0 ? 100.0 : sum;
}

/* /sys/bus/pci/devices/<addr>/gpu_busy_percent */
static moonbit_bytes_t sysmon_read_gpu_busy(const char *addr) {
  sysmon_gpu_enum();
  SysmonGpuEntry *e = sysmon_gpu_by_addr(addr);
  if (e == NULL) {
    return NULL;
  }
  double util = sysmon_gpu_engine_util(e->luid_lo, e->luid_hi);
  if (util < 0.0) {
    return NULL;
  }
  SysmonBuf b = {0};
  if (!sysmon_buf_putf(&b, "%d\n", (int)(util + 0.5))) {
    free(b.p);
    return NULL;
  }
  return sysmon_bytes_take(&b);
}

/* /sys/bus/pci/devices/<addr>/mem_info_vram_{used,total} */
static moonbit_bytes_t sysmon_read_gpu_vram(const char *addr, int total) {
  sysmon_gpu_enum();
  SysmonGpuEntry *e = sysmon_gpu_by_addr(addr);
  if (e == NULL) {
    return NULL;
  }
  if (total) {
    if (e->ded_bytes == 0) {
      return NULL; /* 集显无专用显存段：不虚拟该文件 */
    }
    SysmonBuf b = {0};
    if (!sysmon_buf_putf(&b, "%llu\n", e->ded_bytes)) {
      free(b.p);
      return NULL;
    }
    return sysmon_bytes_take(&b);
  }
  HMODULE dxgi = NULL;
  sysmon_dll_load("dxgi.dll", &dxgi);
  FARPROC create = sysmon_sym(dxgi, "CreateDXGIFactory1");
  if (create == NULL) {
    return NULL;
  }
  typedef LONG(WINAPI * CreateDXGIFactory1Fn)(const GUID *, void **);
  void *factory = NULL;
  if (((CreateDXGIFactory1Fn)(uintptr_t)create)(&sysmon_IID_IDXGIFactory1,
                                                &factory) != 0 ||
      factory == NULL) {
    return NULL;
  }
  SysmonFactory1Vtbl *fv = *(SysmonFactory1Vtbl **)factory;
  moonbit_bytes_t out = NULL;
  for (unsigned int i = 0; i < SYSMON_MAX_GPUS; i++) {
    void *adapter = NULL;
    if (fv->EnumAdapters1(factory, i, &adapter) != 0 || adapter == NULL) {
      break;
    }
    SysmonAdapterVtbl *av = *(SysmonAdapterVtbl **)adapter;
    SysmonDxgiDesc1 desc;
    memset(&desc, 0, sizeof(desc));
    void *a3 = NULL;
    if (av->GetDesc1(adapter, &desc) == 0 &&
        desc.AdapterLuid.LowPart == e->luid_lo &&
        desc.AdapterLuid.HighPart == e->luid_hi &&
        av->QueryInterface(adapter, &sysmon_IID_IDXGIAdapter3, &a3) == 0 &&
        a3 != NULL) {
      SysmonAdapterVtbl *v3 = *(SysmonAdapterVtbl **)a3;
      SysmonVideoMemoryInfo info;
      memset(&info, 0, sizeof(info));
      /* DXGI_MEMORY_SEGMENT_GROUP_LOCAL = 0 */
      if (v3->QueryVideoMemoryInfo(a3, 0, 0, &info) == 0) {
        SysmonBuf b = {0};
        if (sysmon_buf_putf(&b, "%lld\n", info.CurrentUsage)) {
          out = sysmon_bytes_take(&b);
        }
      }
      v3->Release(a3);
    }
    av->Release(adapter);
    if (out != NULL) {
      break;
    }
  }
  fv->Release(factory);
  return out;
}

/* ---------------- NVIDIA：nvidia-smi 子进程 + hwmon 虚拟 ---------------- */

#define SYSMON_NVSMI_TTL_MS 500

static char *g_nvsmi = NULL; /* 重写地址后的 CSV 原文 */
static ULONGLONG g_nvsmi_at = 0;

/* 行列提取：第 idx 个逗号字段（0 基），去首尾空白与 \r；返回区间长度。 */
static const char *sysmon_csv_field(const char *line, int idx,
                                    const char **out, int *len) {
  const char *p = line;
  for (int i = 0; i < idx; i++) {
    p = strchr(p, ',');
    if (p == NULL) {
      return NULL;
    }
    p++;
  }
  const char *end = strchr(p, ',');
  if (end == NULL) {
    end = p + strlen(p);
  }
  while (*p == ' ' || *p == '\t') {
    p++;
  }
  while (end > p &&
         (end[-1] == ' ' || end[-1] == '\t' || end[-1] == '\r' ||
          end[-1] == '\n')) {
    end--;
  }
  *out = p;
  *len = (int)(end - p);
  return p;
}

/* 跑一次 nvidia-smi（CREATE_NO_WINDOW + 匿名管道，不用 _popen——控制台
   程序在 GUI 进程下会闪窗），输出 CSV 按型号名对位 DXGI 适配器重写首列
   总线地址为虚拟地址。 */
static char *sysmon_run_nvidia_smi(void) {
  SysmonBuf out = {0};
  SECURITY_ATTRIBUTES sa;
  memset(&sa, 0, sizeof(sa));
  sa.nLength = sizeof(sa);
  sa.bInheritHandle = TRUE;
  HANDLE rd = NULL, wr = NULL;
  if (!CreatePipe(&rd, &wr, &sa, 0)) {
    return NULL;
  }
  SetHandleInformation(rd, HANDLE_FLAG_INHERIT, 0);
  STARTUPINFOA si;
  memset(&si, 0, sizeof(si));
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESTDHANDLES;
  si.hStdOutput = wr;
  si.hStdError = wr;
  PROCESS_INFORMATION pi;
  memset(&pi, 0, sizeof(pi));
  char cmd[] = "nvidia-smi --query-gpu=pci.bus_id,utilization.gpu,memory.used,"
               "memory.total,temperature.gpu,name --format=csv,noheader,nounits";
  BOOL spawned = CreateProcessA(NULL, cmd, NULL, NULL, TRUE, CREATE_NO_WINDOW,
                                NULL, NULL, &si, &pi);
  CloseHandle(wr);
  if (!spawned) {
    CloseHandle(rd);
    return NULL;
  }
  DWORD wait = WaitForSingleObject(pi.hProcess, 3000);
  if (wait != WAIT_OBJECT_0) {
    TerminateProcess(pi.hProcess, 1);
    WaitForSingleObject(pi.hProcess, 1000);
    CloseHandle(rd);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return NULL;
  }
  DWORD code = 1;
  GetExitCodeProcess(pi.hProcess, &code);
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  if (code != 0) {
    CloseHandle(rd);
    return NULL;
  }
  char chunk[4096];
  DWORD got = 0;
  while (ReadFile(rd, chunk, sizeof(chunk), &got, NULL) && got > 0) {
    if (!sysmon_buf_reserve(&out, got)) {
      break;
    }
    memcpy(out.p + out.len, chunk, got);
    out.len += got;
    out.p[out.len] = '\0';
  }
  CloseHandle(rd);
  if (out.p == NULL) {
    return NULL;
  }
  /* 首列重写：按第 6 列型号名与 DXGI 适配器名匹配（nvidia-smi 的总线
     地址前缀格式与我们的虚拟地址不同，型号名是两者共同来源） */
  sysmon_gpu_enum();
  SysmonBuf fixed = {0};
  char *line = out.p;
  while (*line) {
    char *nl = strchr(line, '\n');
    char *next = nl ? nl + 1 : line + strlen(line);
    if (nl) {
      *nl = '\0';
    }
    const char *nm = NULL;
    int nmlen = 0;
    if (sysmon_csv_field(line, 5, &nm, &nmlen) != NULL) {
      for (int i = 0; i < g_gpu_n; i++) {
        size_t gl = strlen(g_gpus[i].name);
        if (gl == (size_t)nmlen && strncmp(g_gpus[i].name, nm, nmlen) == 0) {
          const char *rest = strchr(line, ',');
          sysmon_buf_puts(&fixed, g_gpus[i].addr);
          sysmon_buf_puts(&fixed, rest ? rest : "");
          sysmon_buf_puts(&fixed, "\n");
          break;
        }
      }
    }
    line = next;
  }
  free(out.p);
  return fixed.p;
}

static const char *sysmon_nvsmi_cached(void) {
  ULONGLONG now = GetTickCount64();
  if (g_nvsmi != NULL || now - g_nvsmi_at < SYSMON_NVSMI_TTL_MS) {
    return g_nvsmi;
  }
  g_nvsmi_at = now;
  char *fresh = sysmon_run_nvidia_smi();
  if (fresh != NULL) {
    g_nvsmi = fresh;
  }
  return g_nvsmi;
}

/* 第 n 行（0 基）的字段提取：temp（第 5 列）与 name（第 6 列）。 */
static int sysmon_nvsmi_line(int n, char *name_out, size_t name_cap,
                             double *temp_out) {
  const char *text = sysmon_nvsmi_cached();
  if (text == NULL) {
    return 0;
  }
  const char *p = text;
  for (int i = 0; i < n; i++) {
    p = strchr(p, '\n');
    if (p == NULL) {
      return 0;
    }
    p++;
  }
  const char *nl = strchr(p, '\n');
  size_t ll = nl ? (size_t)(nl - p) : strlen(p);
  if (ll == 0) {
    return 0;
  }
  char *line = (char *)malloc(ll + 1);
  if (line == NULL) {
    return 0;
  }
  memcpy(line, p, ll);
  line[ll] = '\0';
  int ok = 0;
  const char *f = NULL;
  int flen = 0;
  if (sysmon_csv_field(line, 4, &f, &flen) != NULL) {
    char tmp[32];
    if (flen > 0 && flen < (int)sizeof(tmp)) {
      memcpy(tmp, f, (size_t)flen);
      tmp[flen] = '\0';
      *temp_out = atof(tmp);
      if (sysmon_csv_field(line, 5, &f, &flen) != NULL && flen > 0 &&
          (size_t)flen < name_cap) {
        memcpy(name_out, f, (size_t)flen);
        name_out[flen] = '\0';
        ok = 1;
      }
    }
  }
  free(line);
  return ok;
}

static int sysmon_nvsmi_card_count(void) {
  const char *text = sysmon_nvsmi_cached();
  if (text == NULL) {
    return 0;
  }
  int n = 0;
  for (const char *p = text; (p = strchr(p, '\n')) != NULL; p++) {
    n++;
  }
  return n;
}

/* /sys/class/hwmon：nvidia-smi 有输出时每卡一个 hwmonN（temp1_input）；
   无 N 卡返回 NULL（传感器页自然为空，属合法状态）。 */
static moonbit_bytes_t sysmon_list_hwmon(void) {
  int n = sysmon_nvsmi_card_count();
  if (n == 0) {
    return NULL;
  }
  SysmonBuf b = {0};
  for (int i = 0; i < n; i++) {
    if (!sysmon_buf_putf(&b, "hwmon%d\n", i)) {
      break;
    }
  }
  return sysmon_bytes_take(&b);
}

static moonbit_bytes_t sysmon_list_hwmon_entries(int idx) {
  if (idx < 0 || idx >= sysmon_nvsmi_card_count()) {
    return NULL;
  }
  SysmonBuf b = {0};
  if (!sysmon_buf_puts(&b, "temp1_input\ntemp1_label\n")) {
    free(b.p);
    return NULL;
  }
  return sysmon_bytes_take(&b);
}

static moonbit_bytes_t sysmon_read_hwmon(int idx, const char *what) {
  char name[256];
  double temp = 0.0;
  if (!sysmon_nvsmi_line(idx, name, sizeof(name), &temp)) {
    return NULL;
  }
  SysmonBuf b = {0};
  if (strcmp(what, "name") == 0) {
    if (!sysmon_buf_puts(&b, "nvidia\n")) {
      free(b.p);
      return NULL;
    }
  } else if (strcmp(what, "temp1_input") == 0) {
    if (!sysmon_buf_putf(&b, "%d\n", (int)(temp * 1000.0 + 0.5))) {
      free(b.p);
      return NULL;
    }
  } else if (strcmp(what, "temp1_label") == 0) {
    if (!sysmon_buf_putf(&b, "%s\n", name)) {
      free(b.p);
      return NULL;
    }
  } else {
    free(b.p);
    return NULL;
  }
  return sysmon_bytes_take(&b);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t yue_sysmon_nvidia_smi(void) {
  const char *text = sysmon_nvsmi_cached();
  if (text == NULL) {
    return NULL;
  }
  SysmonBuf b = {0};
  if (!sysmon_buf_puts(&b, text)) {
    return NULL;
  }
  return sysmon_bytes_take(&b);
}

/* ---------------- 目录枚举路由 ---------------- */

MOONBIT_FFI_EXPORT
moonbit_bytes_t yue_sysmon_list_dir(moonbit_bytes_t path) {
  const char *p = (const char *)path;
  if (strcmp(p, "/sys/class/net") == 0) {
    return sysmon_list_netifs();
  }
  if (strcmp(p, "/sys/class/hwmon") == 0) {
    return sysmon_list_hwmon();
  }
  if (strcmp(p, "/sys/bus/pci/devices") == 0) {
    return sysmon_list_gpu_devices();
  }
  /* /sys/class/hwmon/hwmonN → temp 条目 */
  if (strncmp(p, "/sys/class/hwmon/hwmon", 22) == 0) {
    int idx = atoi(p + 22);
    const char *rest = strchr(p + 22, '/');
    if (rest == NULL) {
      return sysmon_list_hwmon_entries(idx);
    }
  }
  return NULL;
}

/* ---------------- 读文件路由 ---------------- */

static moonbit_bytes_t sysmon_virtual_read(const char *p) {
  if (strcmp(p, "/proc/stat") == 0) {
    return sysmon_read_proc_stat();
  }
  if (strcmp(p, "/proc/cpuinfo") == 0) {
    return sysmon_read_cpuinfo();
  }
  if (strcmp(p, "/proc/meminfo") == 0) {
    return sysmon_read_meminfo();
  }
  if (strcmp(p, "/proc/mounts") == 0) {
    return sysmon_read_mounts();
  }
  if (strcmp(p, "/proc/diskstats") == 0) {
    return sysmon_read_diskstats();
  }
  /* /proc/[pid]/{stat,cmdline} */
  if (strncmp(p, "/proc/", 6) == 0) {
    char *end = NULL;
    unsigned long pid = strtoul(p + 6, &end, 10);
    if (end != p + 6 && pid > 0 && pid <= 0xFFFFFFFFUL) {
      if (strcmp(end, "/stat") == 0) {
        return sysmon_read_pid_stat((DWORD)pid);
      }
      if (strcmp(end, "/cmdline") == 0) {
        return sysmon_read_pid_cmdline((DWORD)pid);
      }
    }
  }
  /* /sys/class/net/<alias>/statistics/{rx,tx}_bytes */
  if (strncmp(p, "/sys/class/net/", 15) == 0) {
    return sysmon_read_netif_bytes(p);
  }
  /* /sys/class/hwmon/hwmonN/{name,temp1_input,temp1_label} */
  if (strncmp(p, "/sys/class/hwmon/hwmon", 22) == 0) {
    char *end = NULL;
    long idx = strtol(p + 22, &end, 10);
    if (end != p + 22 && idx >= 0 && *end == '/') {
      return sysmon_read_hwmon((int)idx, end + 1);
    }
  }
  /* /sys/bus/pci/devices/<addr>/{class,vendor,device,gpu_busy_percent,
     mem_info_vram_used,mem_info_vram_total} */
  if (strncmp(p, "/sys/bus/pci/devices/", 21) == 0) {
    const char *addr = p + 21;
    const char *slash = strchr(addr, '/');
    if (slash != NULL && slash > addr) {
      char a[16];
      size_t al = (size_t)(slash - addr);
      if (al < sizeof(a)) {
        memcpy(a, addr, al);
        a[al] = '\0';
        const char *what = slash + 1;
        if (strcmp(what, "class") == 0 || strcmp(what, "vendor") == 0 ||
            strcmp(what, "device") == 0) {
          return sysmon_read_gpu_id(a, what);
        }
        if (strcmp(what, "gpu_busy_percent") == 0) {
          return sysmon_read_gpu_busy(a);
        }
        if (strcmp(what, "mem_info_vram_total") == 0) {
          return sysmon_read_gpu_vram(a, 1);
        }
        if (strcmp(what, "mem_info_vram_used") == 0) {
          return sysmon_read_gpu_vram(a, 0);
        }
      }
    }
  }
  return NULL;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t yue_sysmon_read_text_file(moonbit_bytes_t path) {
  moonbit_bytes_t v = sysmon_virtual_read((const char *)path);
  if (v != NULL) {
    return v;
  }
  /* 未命中虚拟路径：回退真实文件读取（Windows 同样可用 fopen） */
  return sysmon_read_file_generic(path);
}

/* ---------------- 进程管理:kill / 优先级(SYS2 语义归一) ---------------- */

/* kill:首版一律 TerminateProcess 强杀一档(SIGTERM / SIGKILL 同映射,
   温和结束 WM_CLOSE 方案后置)。发起后退出异步,短等让返回时进程确
   已退出(等不到仍算发起成功)。 */
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_kill(int32_t pid, int32_t sig) {
  (void)sig; /* 首版无温和档,两信号同走强杀 */
  HANDLE h = OpenProcess(PROCESS_TERMINATE | SYNCHRONIZE, FALSE, (DWORD)pid);
  if (h == NULL) {
    return sysmon_openproc_err();
  }
  if (!TerminateProcess(h, 1)) {
    int32_t rc = sysmon_winerr_to_errno(GetLastError());
    CloseHandle(h);
    return rc;
  }
  WaitForSingleObject(h, 3000);
  CloseHandle(h);
  return 0;
}

/* 取优先级(读 nice 档位代表值);成功写 *out_nice 返回 0,失败返回
   errno(已退出进程归一 ESRCH)。 */
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_get_priority(int32_t pid, int32_t *out_nice) {
  HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)pid);
  if (h == NULL) {
    return sysmon_openproc_err();
  }
  DWORD cls = GetPriorityClass(h);
  int32_t rc = 0;
  if (cls == 0) {
    rc = sysmon_winerr_to_errno(GetLastError());
  } else {
    *out_nice = sysmon_class_to_nice(cls);
  }
  CloseHandle(h);
  return rc;
}

/* 设优先级:nice 就近钳制到 IDLE/NORMAL/HIGH/REALTIME 四档
   (REALTIME 需管理员提权,不足时报 EACCES)。 */
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_set_priority(int32_t pid, int32_t nice) {
  if (nice < -20 || nice > 19) {
    return 22; /* EINVAL 越界双保险(MoonBit 层已预钳) */
  }
  HANDLE h = OpenProcess(PROCESS_SET_INFORMATION, FALSE, (DWORD)pid);
  if (h == NULL) {
    return sysmon_openproc_err();
  }
  int ok = SetPriorityClass(h, sysmon_nice_to_class(nice));
  int32_t rc = ok ? 0 : sysmon_winerr_to_errno(GetLastError());
  CloseHandle(h);
  return rc;
}

/* 平台探测(编译期定):UI 文案按平台收敛。 */
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_is_windows(void) { return 1; }

MOONBIT_FFI_EXPORT
int32_t yue_sysmon_page_size(void) { return 4096; }

MOONBIT_FFI_EXPORT
int32_t yue_sysmon_clk_tck(void) { return 100; }

#else /* !_WIN32 */

#include <dirent.h>
#include <errno.h>
#include <signal.h>
#include <sys/resource.h>
#include <sys/statvfs.h>
#include <time.h>
#include <unistd.h>

MOONBIT_FFI_EXPORT
int32_t yue_sysmon_page_size(void) {
  long v = sysconf(_SC_PAGE_SIZE);
  return v > 0 ? (int32_t)v : 4096;
}

/* 平台探测(编译期定):UI 文案按平台收敛。 */
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_is_windows(void) { return 0; }

MOONBIT_FFI_EXPORT
int32_t yue_sysmon_clk_tck(void) {
  long v = sysconf(_SC_CLK_TCK);
  return v > 0 ? (int32_t)v : 100;
}

/* 单调时钟（CLOCK_MONOTONIC，不受墙钟调整影响），单位秒。 */
MOONBIT_FFI_EXPORT
double yue_sysmon_monotonic(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return 0.0;
  }
  return (double)ts.tv_sec + (double)ts.tv_nsec * 1.0e-9;
}

/* 列出 /proc 下全部纯数字目录名（pid），换行分隔；失败返回 NULL。 */
MOONBIT_FFI_EXPORT
moonbit_bytes_t yue_sysmon_list_pids(void) {
  DIR *d = opendir("/proc");
  if (d == NULL) {
    return NULL;
  }
  size_t cap = 8192;
  size_t len = 0;
  char *buf = (char *)malloc(cap);
  if (buf == NULL) {
    closedir(d);
    return NULL;
  }
  struct dirent *e;
  while ((e = readdir(d)) != NULL) {
    const char *n = e->d_name;
    int numeric = n[0] != '\0';
    for (const char *p = n; *p != '\0'; p++) {
      if (*p < '0' || *p > '9') {
        numeric = 0;
        break;
      }
    }
    if (!numeric) {
      continue;
    }
    size_t nl = strlen(n);
    while (len + nl + 1 > cap) {
      size_t next = cap * 2;
      char *grown = (char *)realloc(buf, next);
      if (grown == NULL) {
        free(buf);
        closedir(d);
        return NULL;
      }
      buf = grown;
      cap = next;
    }
    memcpy(buf + len, n, nl);
    len += nl;
    buf[len++] = '\n';
  }
  closedir(d);
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  if (out == NULL) {
    free(buf);
    return NULL;
  }
  memcpy(out, buf, len);
  free(buf);
  return out;
}

/* 发信号；成功返回 0，失败返回 errno。 */
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_kill(int32_t pid, int32_t sig) {
  if (kill((pid_t)pid, sig) == 0) {
    return 0;
  }
  return (int32_t)errno;
}

/* 取 nice 值；成功写 *out_nice 返回 0，失败返回 errno。nice = -1 是合法
   值，不能像 getpriority 那样用返回值歧义表达成败。 */
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_get_priority(int32_t pid, int32_t *out_nice) {
  errno = 0;
  int v = getpriority(PRIO_PROCESS, (id_t)pid);
  if (v == -1 && errno != 0) {
    return (int32_t)errno;
  }
  *out_nice = (int32_t)v;
  return 0;
}

/* 设 nice 值；成功返回 0，失败返回 errno。 */
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_set_priority(int32_t pid, int32_t nice) {
  if (setpriority(PRIO_PROCESS, (id_t)pid, nice) == 0) {
    return 0;
  }
  return (int32_t)errno;
}

/* 列出目录条目名（跳过 . 与 ..），换行分隔；失败返回 NULL。 */
MOONBIT_FFI_EXPORT
moonbit_bytes_t yue_sysmon_list_dir(moonbit_bytes_t path) {
  DIR *d = opendir((const char *)path);
  if (d == NULL) {
    return NULL;
  }
  size_t cap = 4096;
  size_t len = 0;
  char *buf = (char *)malloc(cap);
  if (buf == NULL) {
    closedir(d);
    return NULL;
  }
  struct dirent *e;
  while ((e = readdir(d)) != NULL) {
    const char *n = e->d_name;
    if (n[0] == '.' && (n[1] == '\0' || (n[1] == '.' && n[2] == '\0'))) {
      continue;
    }
    size_t nl = strlen(n);
    while (len + nl + 1 > cap) {
      size_t next = cap * 2;
      char *grown = (char *)realloc(buf, next);
      if (grown == NULL) {
        free(buf);
        closedir(d);
        return NULL;
      }
      buf = grown;
      cap = next;
    }
    memcpy(buf + len, n, nl);
    len += nl;
    buf[len++] = '\n';
  }
  closedir(d);
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  if (out == NULL) {
    free(buf);
    return NULL;
  }
  memcpy(out, buf, len);
  free(buf);
  return out;
}

/* statvfs 容量；成功写三个出参（字节）返回 0，失败返回 errno。
   结构体跨 ABI 拆成扁平出参（f_blocks/f_bfree/f_bavail × f_frsize）。 */
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_statvfs(
    moonbit_bytes_t path,
    int64_t *out_total,
    int64_t *out_free,
    int64_t *out_avail) {
  struct statvfs st;
  if (statvfs((const char *)path, &st) != 0) {
    return (int32_t)errno;
  }
  *out_total = (int64_t)st.f_blocks * (int64_t)st.f_frsize;
  *out_free = (int64_t)st.f_bfree * (int64_t)st.f_frsize;
  *out_avail = (int64_t)st.f_bavail * (int64_t)st.f_frsize;
  return 0;
}

/* ---- NVIDIA GPU 采样（popen nvidia-smi，进程内不加载 NVML）----
   dlopen nvmlInit_v2 与宿主运行时存在偶发堆冲突（本机 RTX 3070 +
   Ubuntu 24.04 实测 5/6 启动段错误，dlopen 不 init 则干净），改为每
   次采样 popen 一次 nvidia-smi 批量查询全部卡（含 pci 总线地址可与
   sysfs 枚举对位）。nvidia-smi 不存在（无 N 卡 / 未装驱动）返回 NULL。
   成功输出每卡一行 CSV：pci_bus_id, util%, mem_used(MiB), mem_total
   (MiB), temp(C), name（CSV, noheader, nounits）。 */
MOONBIT_FFI_EXPORT
moonbit_bytes_t yue_sysmon_nvidia_smi(void) {
  FILE *f = popen(
      "nvidia-smi --query-gpu=pci.bus_id,utilization.gpu,memory.used,"
      "memory.total,temperature.gpu,name --format=csv,noheader,nounits",
      "r");
  if (f == NULL) {
    return NULL;
  }
  size_t cap = 4096;
  size_t len = 0;
  char *buf = (char *)malloc(cap);
  if (buf == NULL) {
    pclose(f);
    return NULL;
  }
  for (;;) {
    if (len == cap) {
      if (cap >= 64 * 1024) {
        break;
      }
      size_t next = cap * 2;
      char *grown = (char *)realloc(buf, next);
      if (grown == NULL) {
        free(buf);
        pclose(f);
        return NULL;
      }
      buf = grown;
      cap = next;
    }
    size_t n = fread(buf + len, 1, cap - len, f);
    len += n;
    if (n == 0) {
      break;
    }
  }
  int failed = ferror(f);
  int status = pclose(f);
  if (failed || status != 0) {
    free(buf);
    return NULL;
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  if (out == NULL) {
    free(buf);
    return NULL;
  }
  memcpy(out, buf, len);
  free(buf);
  return out;
}

#endif /* _WIN32 */

/* 读整个文本文件为 MoonBit Bytes；失败（不存在 / 权限 / 超限 / 是目录）
   返回 NULL，MoonBit 侧映射为 None。/proc、/sys 伪文件 stat 尺寸为 0，
   必须循环增量读取。三平台共用实现；Windows 读取入口先查虚拟 /proc、
   /sys 路由，未命中再落此处。 */
static moonbit_bytes_t sysmon_read_file_generic(moonbit_bytes_t path) {
  FILE *f = fopen((const char *)path, "rb");
  if (f == NULL) {
    return NULL;
  }
  size_t cap = 8192;
  size_t len = 0;
  char *buf = (char *)malloc(cap);
  if (buf == NULL) {
    fclose(f);
    return NULL;
  }
  for (;;) {
    if (len == cap) {
      if (cap >= SYSMON_MAX_FILE_BYTES) {
        break;
      }
      size_t next = cap * 2;
      char *grown = (char *)realloc(buf, next);
      if (grown == NULL) {
        free(buf);
        fclose(f);
        return NULL;
      }
      buf = grown;
      cap = next;
    }
    size_t n = fread(buf + len, 1, cap - len, f);
    len += n;
    if (n == 0) {
      break;
    }
  }
  int failed = ferror(f);
  fclose(f);
  if (failed) {
    free(buf);
    return NULL;
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  if (out == NULL) {
    free(buf);
    return NULL;
  }
  memcpy(out, buf, len);
  free(buf);
  return out;
}

#ifndef _WIN32
MOONBIT_FFI_EXPORT
moonbit_bytes_t yue_sysmon_read_text_file(moonbit_bytes_t path) {
  return sysmon_read_file_generic(path);
}
#endif
