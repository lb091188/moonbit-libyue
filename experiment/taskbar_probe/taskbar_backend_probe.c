/* 任务栏进度后端探针（纯 C，直接 #include stub.c）。TODO §6.3 接缝项。
 *
 * 动机：ITaskbarList3 是「COM 起不起 + GUID 符号链不链得上 + hwnd 句柄从
 * 窗口槽拿得对不对」的事实问题。绕开 MoonBit 运行时后直喂 wm_taskbar_*，
 * 用返回值与「不存在的窗口/非法状态必须给 0」的守卫路径验证；任务栏按钮
 * 的真实观感（绿条/红条/黄条）只能人看，归 _人工测试清单.md。
 *
 * Win32 无 getter：TBPF_* 状态不可反读（与 notify 的 kind→NIIF_* 同款），
 * 所以本探针只验写路径与守卫，不断言回读。
 *
 * 编法（见 docs/zh/adaptation.md「Windows 基础能力」节）：
 *   cl /nologo /W4 /utf-8 /O2 /DWIN32 /D_WINDOWS /DUNICODE /D_UNICODE \
 *      taskbar_backend_probe.c /Fe:taskbar_backend_probe.exe \
 *      user32.lib gdi32.lib imm32.lib advapi32.lib windowscodecs.lib \
 *      ole32.lib shell32.lib uuid.lib
 *
 * 期望输出末行 TASKBAR-BACKEND-OK。
 */
#include <windows.h>
#include <stdio.h>

#include "../../gui/win/stub.c"

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

int main(void) {
  check_true("wm_init 成功（有显示服务）", wm_init() == 1);

  /* ① 后端可用性：COM 实例与 HrInit 必须起得来（uuid.lib 的 GUID 符号
   *    解析 + CoCreateInstance 两步都在这里被验证） */
  check("wm_taskbar_supported == 1", wm_taskbar_supported(), 1);
  check_true("ITaskbarList3 单例已建", wm_taskbar != NULL);

  /* ② 建一个真窗口（探针自用，测完即关）：任务栏进度按 hwnd 区分目标 */
  int64_t id = wm_window_new(320, 200, "任务栏进度探针");
  check_true("wm_window_new 拿到窗口句柄", id >= 1 && id < WM_MAX_WINDOWS);
  wm_show(id);
  wm_pump();

  /* ③ 写路径：五种 state 编号 + 一次 value/total 都必须成功 */
  check("set_state(NoProgress=0) 成功", wm_taskbar_set_state(id, 0), 1);
  check("set_progress(1,10) 成功", wm_taskbar_set_progress(id, 1, 10), 1);
  check("set_state(Normal=1) 成功", wm_taskbar_set_state(id, 1), 1);
  check("set_progress(10,10) 满格", wm_taskbar_set_progress(id, 10, 10), 1);
  check("set_state(Error=2) 成功", wm_taskbar_set_state(id, 2), 1);
  check("set_state(Paused=3) 成功", wm_taskbar_set_state(id, 3), 1);
  check("set_state(Indeterminate=4) 成功", wm_taskbar_set_state(id, 4), 1);

  /* ④ 大值：ULONGLONG 透传（下载字节数一类的进度值会超 32 位） */
  check("set_progress(4GB-1, 8GB) 成功",
        wm_taskbar_set_progress(id, 4294967295LL, 8589934592LL), 1);

  /* ⑤ 守卫路径：越界窗口 / 未建窗口 / 非法 state 一律给 0，不崩不写 */
  check("越界 id=0 给 0", wm_taskbar_set_state(0, 1), 0);
  check("越界 id=9999 给 0", wm_taskbar_set_state(9999, 1), 0);
  check("越界 id 的 progress 给 0", wm_taskbar_set_progress(9999, 1, 2), 0);
  check("未建窗口（槽在但 hwnd 空）给 0", wm_taskbar_set_state(31, 1), 0);
  check("非法 state=5 给 0", wm_taskbar_set_state(id, 5), 0);
  check("非法 state=-1 给 0", wm_taskbar_set_state(id, -1), 0);

  /* ⑥ 收尾：清回无进度再关窗（观感上不留残条） */
  check("set_state(NoProgress) 收尾", wm_taskbar_set_state(id, 0), 1);
  wm_close(id);
  wm_pump();
  check("关窗后同 id 给 0（hwnd 已置空）", wm_taskbar_set_state(id, 1), 0);

  printf(g_fail == 0 ? "TASKBAR-BACKEND-OK\n" : "TASKBAR-BACKEND-FAIL %d\n",
         g_fail);
  return g_fail == 0 ? 0 : 1;
}
