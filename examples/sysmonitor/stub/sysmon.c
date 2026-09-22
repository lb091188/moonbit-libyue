/* sysmonitor 应用 native-stub：监控数据层与进程管理的系统调用入口。
   符号全在 libc 默认链接范围内，零 shim / fork / vendored / 链接参数改动；
   机制与实测见 docs/zh/adaptation.md。
   平台分工：读文件 / kill / 优先级 / 目录枚举 / sysconf 走 POSIX（Linux 与
   macOS 均可用）；Windows 无对应语义（无 /proc、无 nice），编译期保留同一
   ABI、运行期返回「不支持」哨兵，由 MoonBit 层语义化降级。 */
#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SYSMON_MAX_FILE_BYTES (16 * 1024 * 1024)
#define SYSMON_ERR_UNSUPPORTED (-1000)

#if defined(_WIN32)

/* Windows 分支：同 ABI 占位，全部返回「不支持」。 */
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_page_size(void) { return 4096; }
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_clk_tck(void) { return 100; }
MOONBIT_FFI_EXPORT
double yue_sysmon_monotonic(void) { return 0.0; }
MOONBIT_FFI_EXPORT
moonbit_bytes_t yue_sysmon_list_pids(void) { return NULL; }
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_kill(int32_t pid, int32_t sig) {
  (void)pid;
  (void)sig;
  return SYSMON_ERR_UNSUPPORTED;
}
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_get_priority(int32_t pid, int32_t *out_nice) {
  (void)pid;
  (void)out_nice;
  return SYSMON_ERR_UNSUPPORTED;
}
MOONBIT_FFI_EXPORT
int32_t yue_sysmon_set_priority(int32_t pid, int32_t nice) {
  (void)pid;
  (void)nice;
  return SYSMON_ERR_UNSUPPORTED;
}

#else

#include <dirent.h>
#include <errno.h>
#include <signal.h>
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>

MOONBIT_FFI_EXPORT
int32_t yue_sysmon_page_size(void) {
  long v = sysconf(_SC_PAGE_SIZE);
  return v > 0 ? (int32_t)v : 4096;
}

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

#endif /* _WIN32 */

/* 读整个文本文件为 MoonBit Bytes；失败（不存在 / 权限 / 超限 / 是目录）
   返回 NULL，MoonBit 侧映射为 None。/proc、/sys 伪文件 stat 尺寸为 0，
   必须循环增量读取。stdio 三平台一致，无平台分支。 */
MOONBIT_FFI_EXPORT
moonbit_bytes_t yue_sysmon_read_text_file(moonbit_bytes_t path) {
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
