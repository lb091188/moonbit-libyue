/* sysmonitor 应用 native-stub：监控数据层与进程管理的系统调用入口。
   符号全在 libc 默认链接范围内，零 shim / fork / vendored / 链接参数改动；
   机制与实测见 docs/zh/adaptation.md。 */
#include <moonbit.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SYSMON_MAX_FILE_BYTES (16 * 1024 * 1024)

/* 读整个文本文件为 MoonBit Bytes；失败（不存在 / 权限 / 超限 / 是目录）
   返回 NULL，MoonBit 侧映射为 None。/proc、/sys 伪文件 stat 尺寸为 0，
   必须循环增量读取。 */
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
