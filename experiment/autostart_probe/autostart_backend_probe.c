/* W21d 开机自启动后端探针（纯 C，直接 #include sys_stub.c）。
 *
 * 动机：自启动的面在 MoonBit（Linux 拼 .desktop），**只有 Windows 的注册表
 * 写入需要 C**——HKCU 的 Run 键。要钉死四件事：
 *  1. 可执行文件路径取得对（`GetModuleFileNameW` 的截断判定：n == cap 才翻倍，
 *     n < cap-1 才算完整），且与独立调用逐字符一致；
 *  2. 值的读写**原样**——引号不加工（引号由 MoonBit 侧 `autostart_run_value`
 *     拼，路径含空格未加引号会被登录拉起截断成第一个词）；
 *  3. 落点就是约定的 `Software\Microsoft\Windows\CurrentVersion\Run`、类型
 *     REG_SZ（用探针**自己直读**一遍，绕开桩的路径，防「自洽但路径错」）；
 *  4. 幂等与防御：覆盖写、删除幂等（本就不在也算成功）、NULL 参数回失败档。
 *
 * 本探针**会真的写用户注册表**（这是它的意义），但起手与收尾都删自己的专属值
 * `com.moonbit.native-gui.autostart_cprobe`；无论中途成败都会清场。
 *
 * 编法（vcvars 被 reg 策略挡，手设 INCLUDE/LIB；/Fo 与 /Fe 须 Windows 风格绝对路径）：
 *   cl /nologo /W4 /utf-8 /O2 /DWIN32 /D_WINDOWS /DUNICODE /D_UNICODE \
 *      autostart_backend_probe.c /Fe:autostart_backend_probe.exe \
 *      ole32.lib shell32.lib uuid.lib user32.lib advapi32.lib
 *
 * 期望输出末行 AUTOSTART-BACKEND-OK。
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../../gui/sys/sys_stub.c"

/* 探针自带 moonbit_make_bytes：真实运行时里它是链接期符号，纯 C 探针自带一份
 * 就不必链 moon 运行时。布局只需**自洽**（本探针自己写、自己读；sys_stub.c 只
 * 把它当「能存 size 字节的缓冲」用，真 ABI 交互由 gui/sys 的白盒测试覆盖）。
 * 长度存在数据指针**前 4 字节**，与真运行的 moonbit_object 头口径同构。 */
void *moonbit_make_bytes(int size, int value) {
  int n = size < 0 ? 0 : size;
  unsigned char *blk = (unsigned char *)malloc((size_t)n + 4);
  if (blk == NULL) {
    return NULL;
  }
  *(int *)blk = n;
  unsigned char *data = blk + 4;
  memset(data, value, (size_t)n);
  return data;
}

static int mb_len(const void *p) { return p == NULL ? 0 : *(const int *)((const unsigned char *)p - 4); }

/* Bytes 与 C 串比较（Bytes 不带结尾 NUL，必须比长度）。 */
static int mb_eq(const void *p, const char *expect) {
  int n = mb_len(p);
  return n == (int)strlen(expect) && n >= 0 && memcmp((const char *)p, expect, (size_t)n) == 0;
}

#define PROBE_ID "com.moonbit.native-gui.autostart_cprobe"
#define RUN_PATH L"Software\\Microsoft\\Windows\\CurrentVersion\\Run"
#define RUN_NAME L"com.moonbit.native-gui.autostart_cprobe"

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

/* 探针自己的直读：绕开桩的 yue_sys_autostart_get，独立确认落点与类型。 */
static LONG direct_read(wchar_t *out, DWORD cap_wchars, DWORD *type) {
  HKEY key = NULL;
  LONG r = RegOpenKeyExW(HKEY_CURRENT_USER, RUN_PATH, 0, KEY_QUERY_VALUE, &key);
  if (r != ERROR_SUCCESS) {
    return r;
  }
  DWORD sz = cap_wchars * (DWORD)sizeof(wchar_t);
  r = RegQueryValueExW(key, RUN_NAME, NULL, type, (LPBYTE)out, &sz);
  RegCloseKey(key);
  return r;
}

int main(void) {
  int32_t ok = -7;
  int32_t rc = 0;

  /* 清场：防上一次跑到一半留下的条目 */
  yue_sys_autostart_remove(PROBE_ID, &ok);

  /* ① 可执行文件路径 */
  {
    void *ex = yue_sys_exe_path(&ok);
    check("yue_sys_exe_path ok", ok, 1);
    check_true("exe 路径非空", mb_len(ex) > 0);
    wchar_t direct[MAX_PATH * 2];
    DWORD dn = GetModuleFileNameW(NULL, direct, (DWORD)(sizeof(direct) / sizeof(wchar_t)));
    char direct_utf8[4096];
    int n = WideCharToMultiByte(CP_UTF8, 0, direct, (int)dn, direct_utf8,
                                (int)sizeof(direct_utf8), NULL, NULL);
    if (n > 0 && n < (int)sizeof(direct_utf8)) {
      direct_utf8[n] = '\0';
    } else {
      direct_utf8[0] = '\0';
    }
    check_true("exe 路径与 GetModuleFileNameW 一致", mb_eq(ex, direct_utf8));
    {
      int len = mb_len(ex);
      const char *s = (const char *)ex;
      check_true("exe 路径以 .exe 结尾",
                 len >= 4 && _strnicmp(s + len - 4, ".exe", 4) == 0);
      check_true("exe 路径含反斜杠", memchr(s, '\\', (size_t)len) != NULL);
    }
  }

  /* ② 未写时读回「不存在」（ok = 0） */
  {
    void *g = yue_sys_autostart_get(PROBE_ID, &ok);
    check("未写时 ok(0=不存在)", ok, 0);
    check("未写时长度 0", mb_len(g), 0);
  }

  /* ③ 写入带引号的路径形态 */
  const char *v1 = "\"C:/probe/my app.exe\"";
  rc = yue_sys_autostart_set(PROBE_ID, v1, &ok);
  check("set rc", rc, 0);
  check("set ok", ok, 1);

  /* ④ 独立直读：约定路径 + REG_SZ + 值与写入逐字符一致 */
  {
    wchar_t raw[1024];
    DWORD type = 0;
    LONG r = direct_read(raw, 1024, &type);
    check("独立 RegQueryValueExW 成功", (long long)r, (long long)ERROR_SUCCESS);
    check("类型 REG_SZ", (long long)type, (long long)REG_SZ);
    char raw_utf8[2048];
    int n = WideCharToMultiByte(CP_UTF8, 0, raw, -1, raw_utf8,
                                (int)sizeof(raw_utf8), NULL, NULL);
    check_true("独立直读值与写入一致", n > 0 && strcmp(raw_utf8, v1) == 0);
  }

  /* ⑤ 走桩读回：原样（含引号，不做二次加工） */
  {
    void *g = yue_sys_autostart_get(PROBE_ID, &ok);
    check("写入后 ok", ok, 1);
    check_true("读回 == 写入（含引号）", mb_eq(g, v1));
  }

  /* ⑥ 覆盖写（幂等） */
  const char *v2 = "\"C:/probe/other.exe\" --flag";
  rc = yue_sys_autostart_set(PROBE_ID, v2, &ok);
  check("覆盖写 rc", rc, 0);
  check_true("覆盖后读回 == 新值", mb_eq(yue_sys_autostart_get(PROBE_ID, &ok), v2));

  /* ⑦ 非 ASCII 路径往返（UTF-8 → UTF-16 → UTF-8） */
  const char *v3 = "\"C:/探针/应用.exe\"";
  rc = yue_sys_autostart_set(PROBE_ID, v3, &ok);
  check("中文值 set rc", rc, 0);
  check_true("中文值往返一致", mb_eq(yue_sys_autostart_get(PROBE_ID, &ok), v3));

  /* ⑧ 空串也是合法 REG_SZ（存在但长度为 0） */
  rc = yue_sys_autostart_set(PROBE_ID, "", &ok);
  check("空值 set rc", rc, 0);
  {
    void *g = yue_sys_autostart_get(PROBE_ID, &ok);
    check("空值 ok(1=存在)", ok, 1);
    check("空值长度 0", mb_len(g), 0);
  }

  /* ⑨ 长值（>512，逼出动态缓冲与 sz 两段式查询） */
  {
    char longv[1300];
    longv[0] = '"';
    memset(longv + 1, 'a', 1200);
    memcpy(longv + 1201, "x.exe\"", 6);
    longv[1207] = '\0';
    rc = yue_sys_autostart_set(PROBE_ID, longv, &ok);
    check("长值 set rc", rc, 0);
    {
      void *g = yue_sys_autostart_get(PROBE_ID, &ok);
      check("长值长度", mb_len(g), 1207);
      check_true("长值往返一致", mb_eq(g, longv));
    }
  }

  /* ⑩ NULL 参数防御 */
  check("set(NULL,v) rc = -1", yue_sys_autostart_set(NULL, "x", &ok), -1);
  check("set(id,NULL) rc = -1", yue_sys_autostart_set(PROBE_ID, NULL, &ok), -1);
  check("remove(NULL) rc = -1", yue_sys_autostart_remove(NULL, &ok), -1);
  {
    void *g = yue_sys_autostart_get(NULL, &ok);
    check("get(NULL) ok = -1(失败档)", ok, -1);
    check("get(NULL) 长度 0", mb_len(g), 0);
  }

  /* ⑪ 删除 + 读回不存在 + 幂等 */
  rc = yue_sys_autostart_remove(PROBE_ID, &ok);
  check("remove rc", rc, 0);
  check("remove ok", ok, 1);
  {
    void *g = yue_sys_autostart_get(PROBE_ID, &ok);
    check("删除后 ok(0=不存在)", ok, 0);
    check("删除后长度 0", mb_len(g), 0);
  }
  rc = yue_sys_autostart_remove(PROBE_ID, &ok);
  check("幂等 remove rc", rc, 0);
  check("幂等 remove ok", ok, 1);
  {
    wchar_t raw[64];
    DWORD type = 0;
    check("独立直读：删除后确实不在",
          (long long)direct_read(raw, 64, &type), (long long)ERROR_FILE_NOT_FOUND);
  }

  /* 收尾清场（无论成败） */
  yue_sys_autostart_remove(PROBE_ID, &ok);

  if (g_fail == 0) {
    printf("AUTOSTART-BACKEND-OK\n");
    return 0;
  }
  printf("AUTOSTART-BACKEND-FAILED (%d)\n", g_fail);
  return 1;
}
