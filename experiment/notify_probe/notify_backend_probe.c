/* W21a 桌面通知后端探针（纯 C，直接 #include stub.c）。
 *
 * 动机：Win32 的「通知」没有独立 API，它挂在托盘图标上（NIM_ADD 建项 +
 * NIM_MODIFY 带 NIF_INFO 弹气泡）。要钉死三件事：
 *  1. 气泡确实发得出去（Shell_NotifyIconW(NIM_MODIFY) 的返回值）；
 *  2. 通知槽与托盘图标槽**共用同一张 WM_MAX_TRAYS 表**，但计数互不污染
 *     （wm_notify_count 只数 kind 1，wm_tray_count 只数 kind 0）；
 *  3. 通知槽**不入托盘点击队列**（点击语义未定义，wm_tray_wndproc 对 kind 1 丢）。
 *
 * Win32 没有读回 dwInfoFlags / uTimeout 的接口，故 kind→NIIF_* 的映射无法在
 * 探针里反读，只能验三个 kind 下发都返回成功（映射写死在 stub.c 一行三元式，
 * 由代码评审兜底）。气泡的「收」同样没有独立 API，走后端约定的「NIF_INFO 且
 * szInfo 置空」+ NIM_DELETE（wm_notify_close），探针验其幂等不崩。
 *
 * 编法（同 experiment/tray_probe，见 docs/zh/adaptation.md W21a 节）：
 *   cl /nologo /W4 /utf-8 /O2 /DWIN32 /D_WINDOWS /DUNICODE /D_UNICODE \
 *      notify_backend_probe.c /Fe:notify_backend_probe.exe \
 *      user32.lib gdi32.lib imm32.lib advapi32.lib windowscodecs.lib \
 *      ole32.lib shell32.lib
 *
 * 期望输出末行 NOTIFY-BACKEND-OK。
 */
#include <windows.h>
#include <stdio.h>
#include <string.h>

#include "../../yue/win/stub.c"

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

/* 通知槽是否落进了托盘点击队列（收一条就给 1，空给 0）。 */
static int poll_has_event(void) {
  int32_t s = 0, k = 0;
  return wm_tray_poll(&s, &k);
}

int main(void) {
  check_true("wm_init 成功（有显示服务）", wm_init() == 1);

  /* ① 后端可用性：Win32 上消息窗建得出即可。 */
  check("wm_notify_supported == 1", wm_notify_supported(), 1);
  check("初始通知数 0", wm_notify_count(), 0);
  check("初始托盘数 0", wm_tray_count(), 0);

  /* ② 发一张气泡：拿到 id（>=1），count 加一，标题 UTF-8 往返读回一致。 */
  int n1 = wm_notify_send(0, "构建完成", "3 个目标已产出", 0);
  check_true("wm_notify_send 拿到 id", n1 >= 1 && n1 < WM_MAX_TRAYS);
  check("发一张后通知数 1", wm_notify_count(), 1);
  check("发通知不影响托盘计数", wm_tray_count(), 0);
  {
    char out[256];
    int n = wm_notify_title(n1, out, 256);
    check_true("气泡标题读回 UTF-8 一致",
               n > 0 && strcmp(out, "构建完成") == 0);
  }

  /* ③ 通知槽不入托盘点击队列：给消息窗投左键/右键，队列应仍为空。 */
  {
    SendMessageW(wm_tray_hwnd, WM_TRAY_CB, (WPARAM)n1, (LPARAM)WM_LBUTTONUP);
    SendMessageW(wm_tray_hwnd, WM_TRAY_CB, (WPARAM)n1, (LPARAM)WM_RBUTTONUP);
    check("通知槽点击不入托盘队列", poll_has_event(), 0);
  }

  /* ④ 更新（替换）同槽气泡：标题读回变新值，id 不变、count 不变。 */
  check("wm_notify_update 成功", wm_notify_update(n1, "构建失败", "详见日志", 2), 1);
  check("更新后通知数仍 1", wm_notify_count(), 1);
  {
    char out[256];
    int n = wm_notify_title(n1, out, 256);
    check_true("更新后标题读回一致", n > 0 && strcmp(out, "构建失败") == 0);
  }

  /* ⑤ 三个 kind 下发都返回成功（映射本身不可反读，代码评审兜底）。 */
  check("kind 0（信息）发得出", wm_notify_update(n1, "信息", "body0", 0), 1);
  check("kind 1（警告）发得出", wm_notify_update(n1, "警告", "body1", 1), 1);
  check("kind 2（错误）发得出", wm_notify_update(n1, "错误", "body2", 2), 1);

  /* ⑥ 标题超 63 字截断（szInfoTitle 64 宽字符），不越界。 */
  {
    char big[400];
    memset(big, 'x', sizeof(big) - 1);
    big[sizeof(big) - 1] = '\0';
    check("超长标题仍发得出", wm_notify_update(n1, big, "b", 0), 1);
    char out[512];
    int n = wm_notify_title(n1, out, 512);
    check_true("超长标题截断在 63 以内", n > 0 && n <= 63);
  }
  wm_notify_update(n1, "构建完成", "3 个目标已产出", 0);

  /* ⑦ 多张气泡并存 + 与托盘图标共表：托盘 1 + 通知 3 = 占用 4 槽。 */
  int tray1 = wm_tray_new(0, "托盘图标");
  check_true("建一个托盘图标", tray1 >= 1);
  int n2 = wm_notify_send(0, "第二张", "t2", 1);
  int n3 = wm_notify_send(0, "第三张", "t3", 2);
  check_true("再发两张气泡", n2 >= 1 && n3 >= 1 && n2 != n1 && n3 != n2);
  check("通知数 3", wm_notify_count(), 3);
  check("托盘数 1", wm_tray_count(), 1);
  check_true("槽号互不相同", n1 != tray1 && n2 != tray1 && n3 != tray1);

  /* ⑧ 表满：共 8 槽（1..7 可用），已用 4，再要 4 只有 3 能成，最后一张给 0。 */
  {
    int extra[4];
    int ok = 0;
    for (int i = 0; i < 4; i++) {
      extra[i] = wm_notify_send(0, "填满", "x", 0);
      if (extra[i] > 0) {
        ok++;
      }
    }
    check_true("表满后再发只成 3 张", ok == 3);
    check("通知数达 6", wm_notify_count(), 6);
    check("占用槽数达上限 7", wm_notify_count() + wm_tray_count(), WM_MAX_TRAYS - 1);
    for (int i = 0; i < 4; i++) {
      if (extra[i] > 0) {
        wm_notify_close(extra[i]);
      }
    }
  }

  /* ⑨ 关闭：气泡收起 + 摘托盘项，count 减一；幂等（再关不崩、不起负）。 */
  wm_notify_close(n2);
  check("关一张后通知数 2", wm_notify_count(), 2);
  wm_notify_close(n2);
  check("重复关闭幂等（仍 2）", wm_notify_count(), 2);

  /* ⑩ 守卫：非法槽 / 普通托盘槽 对通知 API 无效。 */
  check("update 非法槽给 0", wm_notify_update(9999, "x", "y", 0), 0);
  check("update 托盘槽给 0", wm_notify_update(tray1, "x", "y", 0), 0);
  check("title 非法槽给 0", wm_notify_title(9999, NULL, 0), 0);
  check("title 托盘槽给 0", wm_notify_title(tray1, (char[8]){0}, 8), 0);
  wm_notify_close(9999);
  wm_notify_close(tray1);
  check("close 非法/托盘槽后计数不变", wm_notify_count(), 2);
  check("托盘图标还在", wm_tray_count(), 1);

  /* ⑪ 摘掉托盘图标后通知照在（两套计数解耦）。 */
  wm_tray_remove(tray1);
  check("摘托盘后托盘数 0", wm_tray_count(), 0);
  check("摘托盘不影响通知数", wm_notify_count(), 2);

  /* ⑫ 清空并读回为 0。 */
  wm_notify_close(n1);
  wm_notify_close(n3);
  check("全关后通知数 0", wm_notify_count(), 0);
  check("全关后 title 读回 0", wm_notify_title(n1, (char[8]){0}, 8), 0);

  printf(g_fail == 0 ? "NOTIFY-BACKEND-OK\n" : "NOTIFY-BACKEND-FAIL %d\n",
         g_fail);
  return g_fail == 0 ? 0 : 1;
}
