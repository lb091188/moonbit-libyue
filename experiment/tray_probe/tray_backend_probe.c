/* W20c 系统托盘后端探针（纯 C，直接 #include stub.c）。
 *
 * 动机：托盘是「Shell_NotifyIconW 认不认 + 回调消息怎么回来」的事实问题。
 * 绕开 MoonBit 运行时后可以直喂 wm_tray_*，再用 Shell_NotifyIconW(NIM_MODIFY)
 * 的返回值、GetCursorPos 之外的静态表反读、以及**主动给托盘消息窗投 WM_TRAY_CB**
 * 来验证回调消息的落点与队列语义。右键弹出（TrackPopupMenuEx）是阻塞调用，
 * 需要真人点选，故只验「守卫路径」——无菜单/非法槽号必须立刻返回 0 不阻塞。
 *
 * 编法（见 docs/zh/adaptation.md「Windows 基础能力首批」节）：
 *   cl /nologo /W4 /utf-8 /O2 /DWIN32 /D_WINDOWS /DUNICODE /D_UNICODE \
 *      tray_backend_probe.c /Fe:tray_backend_probe.exe \
 *      user32.lib gdi32.lib imm32.lib advapi32.lib windowscodecs.lib \
 *      ole32.lib shell32.lib
 *
 * 期望输出末行 TRAY-BACKEND-OK。
 */
#include <windows.h>
#include <stdio.h>
#include <string.h>

#include "../../yue/win/stub.c"

static int g_fail = 0;

static void check(const char *what, long long got, long long want) {
  if (got == want) {
    printf("PROBE ok   %-50s = %lld\n", what, got);
  } else {
    printf("PROBE FAIL %-50s = %lld (want %lld)\n", what, got, want);
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

  /* ① 后端可用性：Win32 上 Shell_NotifyIcon 恒在，消息窗应建得出 */
  check("wm_tray_supported == 1", wm_tray_supported(), 1);
  check_true("托盘消息窗已建", wm_tray_hwnd != NULL);

  /* ② 建托盘图标（tooltip 走 UTF-8→UTF-16 往返） */
  int slot = wm_tray_new(0, "托盘探针 · W20c");
  check_true("wm_tray_new 拿到槽号", slot >= 1 && slot < WM_MAX_TRAYS);
  check("wm_tray_count == 1", wm_tray_count(), 1);
  {
    char out[256];
    int n = wm_tray_tooltip(slot, out, 256);
    check_true("tooltip 读回 UTF-8 一致",
               n > 0 && strcmp(out, "托盘探针 · W20c") == 0);
  }

  /* ③ NIM_MODIFY：改 tooltip 生效 */
  wm_tray_set_tooltip(slot, "改过的提示");
  {
    char out[256];
    int n = wm_tray_tooltip(slot, out, 256);
    check_true("改 tooltip 后读回一致",
               n > 0 && strcmp(out, "改过的提示") == 0);
  }

  /* ④ tooltip 超长截断（szTip 128 宽字符），不越界 */
  {
    char big[300];
    memset(big, 'x', sizeof(big) - 1);
    big[sizeof(big) - 1] = '\0';
    wm_tray_set_tooltip(slot, big);
    char out[512];
    int n = wm_tray_tooltip(slot, out, 512);
    check_true("超长 tooltip 截断在 127 以内", n > 0 && n <= 127);
  }
  wm_tray_set_tooltip(slot, "托盘探针 · W20c");

  /* ⑤ 换图标：非法图标句柄给 NULL 不崩（后端收 NIM_MODIFY） */
  wm_tray_set_icon(slot, 0);
  wm_tray_set_icon(slot, 999); // 越界图标槽 → NULL
  check_true("set_icon 非法槽不崩", 1);

  /* ⑥ 挂右键菜单：用 W20a 句柄表（wm_menu_popup_new 建弹出根） */
  int menu = wm_menu_popup_new();
  check_true("wm_menu_popup_new 拿到句柄", menu >= 1 && menu < WM_MAX_MENUS);
  check_true("弹出根是真 HMENU", wm_menus[menu] != NULL);
  int cmd_open = wm_menu_add_item(menu, "打开", 0, -1, "", 0);
  int cmd_quit = wm_menu_add_item(menu, "退出", 0, -1, "", 0);
  check_true("菜单项拿到命令 id", cmd_open >= WM_MENU_CMD_BASE &&
                                       cmd_quit == cmd_open + 1);
  wm_tray_set_menu(slot, menu);
  check_true("托盘挂上了菜单 HMENU", wm_trays[slot].menu == wm_menus[menu]);

  /* ⑦ 回调消息落点：给托盘消息窗投 WM_TRAY_CB，事件进队列 */
  {
    SendMessageW(wm_tray_hwnd, WM_TRAY_CB, (WPARAM)slot, (LPARAM)WM_LBUTTONUP);
    int32_t got_slot = 0, got_kind = -1;
    int got = wm_tray_poll(&got_slot, &got_kind);
    check("左键事件取到 1 条", got, 1);
    check("左键事件槽号对", got_slot, slot);
    check("左键事件 kind == 0", got_kind, 0);

    SendMessageW(wm_tray_hwnd, WM_TRAY_CB, (WPARAM)slot, (LPARAM)WM_RBUTTONUP);
    got = wm_tray_poll(&got_slot, &got_kind);
    check("右键事件取到 1 条", got, 1);
    check("右键事件 kind == 1", got_kind, 1);

    // 队列已空
    check("队列空后 poll 给 0", wm_tray_poll(&got_slot, &got_kind), 0);
  }

  /* ⑧ 非鼠标消息不进队列（WM_MOUSEMOVE 之类） */
  {
    SendMessageW(wm_tray_hwnd, WM_TRAY_CB, (WPARAM)slot, (LPARAM)WM_MOUSEMOVE);
    int32_t s = 0, k = 0;
    check("非点击消息不入队", wm_tray_poll(&s, &k), 0);
  }

  /* ⑨ 弹菜单的守卫路径：非法槽号 / 无菜单都立刻返回 0（不阻塞） */
  check("wm_tray_popup(非法槽) == 0", wm_tray_popup(9999), 0);
  {
    int slot2 = wm_tray_new(0, "无菜单托盘");
    check_true("第二项建成功", slot2 >= 1);
    check("无菜单时 popup 不阻塞、返回 0", wm_tray_popup(slot2), 0);
    wm_tray_remove(slot2);
  }

  /* ⑩ 槽表用尽：WM_MAX_TRAYS = 8（槽 1..7），再建给 0 */
  {
    int extra[8];
    int n = 0;
    for (int i = 0; i < 8; i++) {
      extra[i] = wm_tray_new(0, "填满");
      if (extra[i] > 0) {
        n++;
      }
    }
    check("当前在用槽数达上限 7", wm_tray_count(), WM_MAX_TRAYS - 1);
    check_true("表满后再建给 0", n == 6); // 已有 1（slot），共补 6
    for (int i = 0; i < 8; i++) {
      if (extra[i] > 0) {
        wm_tray_remove(extra[i]);
      }
    }
  }

  /* ⑪ 移除幂等 + 越界读回安全 */
  wm_tray_remove(slot);
  wm_tray_remove(slot);
  check("移除后计数归 0", wm_tray_count(), 0);
  check("移除后 tooltip 读回 0", wm_tray_tooltip(slot, NULL, 0), 0);
  wm_tray_set_tooltip(9999, "x");
  wm_tray_set_icon(9999, 0);
  wm_tray_set_menu(9999, menu);
  wm_tray_remove(9999);
  check("越界槽的 popup 给 0", wm_tray_popup(9999), 0);

  printf(g_fail == 0 ? "TRAY-BACKEND-OK\n" : "TRAY-BACKEND-FAIL %d\n", g_fail);
  return g_fail == 0 ? 0 : 1;
}
