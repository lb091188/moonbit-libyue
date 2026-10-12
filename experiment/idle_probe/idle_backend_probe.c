/* W21e 用户空闲检测后端探针（纯 C，直接 #include sys_stub.c）。
 *
 * 动机：空闲的面在 MoonBit（`gui/sys/idle.mbt`），C 桩只做平台取数。要钉死
 * 三件事：
 *  1. **支持性**：Windows 恒 1（`GetLastInputInfo` 是 Win2000 起就有的稳定接口）；
 *  2. **取数口径**：返回值就是「自最后一次输入起的毫秒」——与独立重算一遍
 *     `GetTickCount() - li.dwTime` 的结果对齐（容许调用间隙与 GetTickCount
 *     ~10-16ms 的粒度），且非负、连续读单调不减；
 *  3. **回绕安全**：`GetTickCount()` 是 32 位且约 49.7 天回绕一次，差值必须用
 *     **无符号模减**（`now - then`），若先转 int64 再相减会在回绕点变负数。这
 *     里用合成值把模减语义钉死（桩里的表达式同此口径）。
 *
 * 本探针只读系统状态、不写任何东西；平台限 Windows（其余平台桩走对应分支，
 * 由 gui/sys 的白盒测试覆盖「不支持」档）。
 *
 * 编法（vcvars 被 reg 策略挡，手设 INCLUDE/LIB；/Fe 须 Windows 风格绝对路径）：
 *   cl /nologo /W4 /utf-8 /O2 /DWIN32 /D_WINDOWS /DUNICODE /D_UNICODE \
 *      idle_backend_probe.c /Fe:idle_backend_probe.exe \
 *      ole32.lib shell32.lib uuid.lib user32.lib
 *
 * 期望输出末行 IDLE-BACKEND-OK。
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../../gui/sys/sys_stub.c"

/* 探针自带 moonbit_make_bytes：sys_stub.c 的其它导出函数在链接期会引用它
 * （本探针不直接调那些函数，但同翻译单元里它们的函数体要能被链接）。布局只需
 * 自洽——长度存数据指针前 4 字节，与真运行的 moonbit_object 头口径同构。 */
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

/* 独立重算：与桩同口径，但**独立写一遍**，防「桩自洽但口径错」。 */
static DWORD indep_elapsed_ms(void) {
  LASTINPUTINFO li;
  li.cbSize = sizeof(LASTINPUTINFO);
  li.dwTime = 0;
  if (!GetLastInputInfo(&li)) {
    return 0;
  }
  return GetTickCount() - li.dwTime; /* DWORD 模减 */
}

/* 无符号模减：扛 GetTickCount 的 ~49.7 天回绕。 */
static DWORD modular_diff(DWORD now, DWORD then) { return now - then; }

int main(void) {
  /* ① 支持性：Windows 恒真 */
  check("yue_sys_idle_supported", (long long)yue_sys_idle_supported(), 1);

  /* ② 正常读数：ok=1 且非负 */
  int32_t ok = -7;
  int64_t ms = yue_sys_idle_seconds_ms(&ok);
  check("seconds_ms ok(1=成功)", ok, 1);
  check_true("读数为毫秒且非负", ms >= 0);
  check_true("读数在 int32 区间内(无误截断)", ms < 2147483647LL);

  /* ③ 与独立重算一致（±2000ms：容忍两次调用间隙 + GetTickCount 粒度） */
  {
    DWORD indep = indep_elapsed_ms();
    long long diff = (long long)ms - (long long)indep;
    if (diff < 0) {
      diff = -diff;
    }
    check_true("读数与独立计算一致(±2000ms)", diff <= 2000);
  }

  /* ④ 单调不减：自动化跑无输入时，空闲只会增长 */
  {
    int32_t ok2 = -7;
    int64_t ms2 = yue_sys_idle_seconds_ms(&ok2);
    check("第二次 ok", ok2, 1);
    check_true("空闲单调不减(ms2 >= ms)", ms2 >= ms);
  }

  /* ⑤ 模减语义（合成值，钉死回绕口径） */
  check("模减 0x10 - 0xFFFFFFF0 = 0x20",
        (long long)modular_diff(0x00000010u, 0xFFFFFFF0u), 0x20);
  check("模减 1000 - 500 = 500", (long long)modular_diff(1000u, 500u), 500);
  check("模减 500 - 1000 为回绕值",
        (long long)modular_diff(500u, 1000u), (long long)(DWORD)(500u - 1000u));

  /* ⑥ 连续 5 次读全成功且非负（接口可重复调用、无状态泄漏） */
  {
    int all_ok = 1;
    for (int i = 0; i < 5; i++) {
      int32_t o = -7;
      int64_t v = yue_sys_idle_seconds_ms(&o);
      if (o != 1 || v < 0) {
        all_ok = 0;
        break;
      }
    }
    check_true("连续 5 次读全成功且非负", all_ok);
  }

  /* ⑦ ok 出参每次都被写（不残留上一次的值）：先给个脏初值 */
  {
    int32_t o = 12345;
    int64_t v = yue_sys_idle_seconds_ms(&o);
    check("ok 出参被写为 0/1", (o == 0 || o == 1) ? 1 : 0, 1);
    check_true("配对读数非负", v >= 0);
  }

  if (g_fail == 0) {
    printf("IDLE-BACKEND-OK\n");
    return 0;
  }
  printf("IDLE-BACKEND-FAILED (%d)\n", g_fail);
  return 1;
}
