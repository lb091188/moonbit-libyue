/* W20e 窗口增强后端探针（纯 C，直接 #include stub.c）。
 *
 * 动机：改标题 / 设图标 / 最小尺寸 / 自绘标题栏拖拽区 / 无边框，全是「Win32
 * 收什么消息、回什么值」的事实；绕开 MoonBit 运行时后可以直建窗口、再用
 * SendMessageW 主动发 WM_GETMINMAXINFO / WM_NCHITTEST 反读，或用
 * GetWindowTextW / WM_GETICON / GetWindowLongPtrW 反读状态。
 *
 * 编法（见 experiment/window_probe/build.bat，或 docs/zh/adaptation.md
 * 「Windows 基础能力首批」节）：
 *   cl /nologo /W4 /utf-8 /O2 /DWIN32 /D_WINDOWS /DUNICODE /D_UNICODE \
 *      window_enhance_probe.c /Fe:window_enhance_probe.exe \
 *      user32.lib gdi32.lib imm32.lib advapi32.lib windowscodecs.lib ole32.lib \
 *      shell32.lib
 *
 * 期望输出末行 WIN-ENHANCE-OK。
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../../gui/win/stub.c"

/* 探针不连 MoonBit 运行时：wm_clipboard_get_text 的空壳引用运行时分配
 * 符号，这里给个 malloc 兜底（探针路径不会真走剪贴板）。 */
void *moonbit_make_bytes(int length, int unused) {
  (void)unused;
  return malloc(length > 0 ? (size_t)length : 1);
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

/* 把客户区尺寸换算成整窗尺寸（与生产实现同一套 AdjustWindowRectEx 口径）。 */
static void frame_size(HWND hwnd, int cw, int ch, int *out_w, int *out_h) {
  DWORD st = (DWORD)GetWindowLongPtrW(hwnd, GWL_STYLE);
  DWORD ex = (DWORD)GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
  RECT r = {0, 0, cw, ch};
  AdjustWindowRectEx(&r, st, FALSE, ex);
  *out_w = r.right - r.left;
  *out_h = r.bottom - r.top;
}

int main(void) {
  check_true("wm_init 成功（有显示服务）", wm_init() == 1);

  int64_t id = wm_window_new(640, 480, "probe");
  check_true("建窗拿到句柄", id > 0);
  HWND hwnd = wm_windows[id].hwnd;
  check_true("槽里是真 HWND", hwnd != NULL);

  /* ① 改标题（含中文，走 SetWindowTextW + UTF-8 读回） */
  wm_set_title(id, "窗口增强 · W20e");
  {
    WCHAR want[64];
    MultiByteToWideChar(CP_UTF8, 0, "窗口增强 · W20e", -1, want, 64);
    WCHAR got[64];
    int n = GetWindowTextW(hwnd, got, 64);
    check_true("SetWindowTextW 生效（中文）", n > 0 && wcscmp(got, want) == 0);
    char out[128];
    int got8 = wm_window_title(id, out, 128);
    check_true("wm_window_title 读回 UTF-8", got8 > 0 && strcmp(out, "窗口增强 · W20e") == 0);
  }

  /* ② 最小尺寸：WM_GETMINMAXINFO 回的 ptMinTrackSize 应是「客户区下限 + 边框」 */
  wm_set_min_size(id, 400, 300);
  {
    int32_t mw = 0, mh = 0;
    wm_get_min_size(id, &mw, &mh);
    check("读回 min_w == 400", mw, 400);
    check("读回 min_h == 300", mh, 300);
    MINMAXINFO mmi;
    memset(&mmi, 0, sizeof(mmi));
    SendMessageW(hwnd, WM_GETMINMAXINFO, 0, (LPARAM)&mmi);
    int ew = 0, eh = 0;
    frame_size(hwnd, 400, 300, &ew, &eh);
    check("ptMinTrackSize.x == 客户区 400 + 边框", mmi.ptMinTrackSize.x, ew);
    check("ptMinTrackSize.y == 客户区 300 + 边框", mmi.ptMinTrackSize.y, eh);
    check_true("整窗下限 > 客户区下限（确实加了非客户区）", ew > 400 && eh > 300);
    /* 某轴 0 = 不限制：两轴都清掉后 ptMinTrackSize 归 0 */
    wm_set_min_size(id, 0, 0);
    memset(&mmi, 0, sizeof(mmi));
    SendMessageW(hwnd, WM_GETMINMAXINFO, 0, (LPARAM)&mmi);
    check("清掉后 ptMinTrackSize.x == 0", mmi.ptMinTrackSize.x, 0);
    check("清掉后 ptMinTrackSize.y == 0", mmi.ptMinTrackSize.y, 0);
    /* 单轴 0：另一轴仍按客户区下限外扩 */
    wm_set_min_size(id, 0, 250);
    memset(&mmi, 0, sizeof(mmi));
    SendMessageW(hwnd, WM_GETMINMAXINFO, 0, (LPARAM)&mmi);
    check("单轴限制：x == 0", mmi.ptMinTrackSize.x, 0);
    frame_size(hwnd, 0, 250, &ew, &eh);
    check("单轴限制：y == 客户区 250 + 边框", mmi.ptMinTrackSize.y, eh);
    wm_set_min_size(id, 0, 0);
  }

  /* ③ 自绘标题栏拖拽区：WM_NCHITTEST 在区内回 HTCAPTION、区外回 HTCLIENT */
  wm_set_drag_rect(id, 0, 0, 200, 40);
  {
    int32_t dx = -1, dy = -1, dw = -1, dh = -1;
    wm_get_drag_rect(id, &dx, &dy, &dw, &dh);
    check("读回拖拽区 x", dx, 0);
    check("读回拖拽区 y", dy, 0);
    check("读回拖拽区 w", dw, 200);
    check("读回拖拽区 h", dh, 40);

    POINT p;
    p.x = 10;
    p.y = 10; /* 区内 */
    ClientToScreen(hwnd, &p);
    LRESULT hit_in = SendMessageW(hwnd, WM_NCHITTEST, 0, MAKELPARAM(p.x, p.y));
    check_true("区内命中回 HTCAPTION", hit_in == HTCAPTION);

    p.x = 300;
    p.y = 200; /* 区外（客户区） */
    ClientToScreen(hwnd, &p);
    LRESULT hit_out = SendMessageW(hwnd, WM_NCHITTEST, 0, MAKELPARAM(p.x, p.y));
    check_true("区外命中回 HTCLIENT", hit_out == HTCLIENT);

    p.x = 10;
    p.y = 39; /* 区内边界（含） */
    ClientToScreen(hwnd, &p);
    check_true("下边界内仍回 HTCAPTION",
               SendMessageW(hwnd, WM_NCHITTEST, 0, MAKELPARAM(p.x, p.y)) == HTCAPTION);

    p.x = 10;
    p.y = 40; /* 区间右下开区间 → 区外 */
    ClientToScreen(hwnd, &p);
    check_true("边界外（开区间）回 HTCLIENT",
               SendMessageW(hwnd, WM_NCHITTEST, 0, MAKELPARAM(p.x, p.y)) == HTCLIENT);

    /* 清空拖拽区后，原区内也应回落 HTCLIENT */
    wm_set_drag_rect(id, 0, 0, 0, 0);
    p.x = 10;
    p.y = 10;
    ClientToScreen(hwnd, &p);
    check_true("清空后原区内回 HTCLIENT",
               SendMessageW(hwnd, WM_NCHITTEST, 0, MAKELPARAM(p.x, p.y)) == HTCLIENT);
  }

  /* ④ 窗口图标：WM_SETICON 后 WM_GETICON 应读回同一个 HICON */
  {
    unsigned char px[16] = {
        0, 0, 255, 255, 0, 255, 0, 255, 255, 0, 0, 255, 128, 128, 128, 128};
    int slot = wm_icon_from_bgra(px, 2, 2);
    check_true("建测试图标成功", slot > 0);
    HICON want = (HICON)wm_icon_handle(slot);
    wm_set_icon(id, slot, 2);
    check_true("WM_GETICON(ICON_BIG) == 传入图标",
               (HICON)SendMessageW(hwnd, WM_GETICON, ICON_BIG, 0) == want);
    check_true("WM_GETICON(ICON_SMALL) == 传入图标",
               (HICON)SendMessageW(hwnd, WM_GETICON, ICON_SMALL, 0) == want);
    /* 传 0 清空图标 */
    wm_set_icon(id, 0, 2);
    check_true("清空图标后 WM_GETICON 不指向原 HICON",
               (HICON)SendMessageW(hwnd, WM_GETICON, ICON_BIG, 0) != want);
    wm_icon_free(slot);
  }

  /* ⑤ 无边框：去/还 WS_CAPTION，且客户区尺寸保持不变 */
  {
    RECT before;
    GetClientRect(hwnd, &before);
    check_true("初始有标题栏（WS_CAPTION）",
               (GetWindowLongPtrW(hwnd, GWL_STYLE) & WS_CAPTION) != 0);
    wm_set_borderless(id, 1);
    check("读回 borderless == 1", wm_is_borderless(id), 1);
    check_true("无边框后没有 WS_CAPTION",
               (GetWindowLongPtrW(hwnd, GWL_STYLE) & WS_CAPTION) == 0);
    check_true("无边框后没有 WS_THICKFRAME",
               (GetWindowLongPtrW(hwnd, GWL_STYLE) & WS_THICKFRAME) == 0);
    check_true("无边框后仍是 WS_POPUP 顶层窗",
               (GetWindowLongPtrW(hwnd, GWL_STYLE) & WS_POPUP) != 0);
    RECT after;
    GetClientRect(hwnd, &after);
    check("客户区宽不变", after.right - after.left, before.right - before.left);
    check("客户区高不变", after.bottom - after.top, before.bottom - before.top);

    wm_set_borderless(id, 0);
    check("读回 borderless == 0", wm_is_borderless(id), 0);
    check_true("还原后又有 WS_CAPTION",
               (GetWindowLongPtrW(hwnd, GWL_STYLE) & WS_CAPTION) != 0);
    RECT back;
    GetClientRect(hwnd, &back);
    check("还原后客户区宽不变", back.right - back.left, before.right - before.left);
    check("还原后客户区高不变", back.bottom - back.top, before.bottom - before.top);
    /* 幂等：重复设同值不折腾窗口 */
    wm_set_borderless(id, 0);
    check("重复关闭 borderless 幂等", wm_is_borderless(id), 0);
  }

  /* ⑥ wm_window_set_size：客户区收到目标尺寸（WM_SIZE 记账置 resized） */
  {
    wm_windows[id].resized = 0;
    wm_window_set_size(id, 800, 600);
    RECT cr;
    GetClientRect(hwnd, &cr);
    check("set_size 后客户区宽 800", cr.right - cr.left, 800);
    check("set_size 后客户区高 600", cr.bottom - cr.top, 600);
    check("WM_SIZE 记账置 resized", wm_windows[id].resized, 1);
    check("wm_size 读回宽 800", wm_windows[id].width, 800);
    check("wm_size 读回高 600", wm_windows[id].height, 600);
    /* 下限钳制：宽高 <1 收敛到 1（生产路径 MoonBit 侧 set_size_pixels 先拦，
     * 这里验 C 侧兜底；宽度会被系统「有标题栏的窗口最小宽」顶住，只验高）。 */
    wm_window_set_size(id, 0, 0);
    GetClientRect(hwnd, &cr);
    check("0 尺寸钳到客户区高 1", cr.bottom - cr.top, 1);
    wm_window_set_size(id, 640, 480);
  }

  /* ⑦ wm_window_set_fullscreen：进屏铺满最近显示器、退屏还原现场 */
  {
    RECT before;
    GetWindowRect(hwnd, &before);
    MONITORINFO mi;
    mi.cbSize = sizeof(mi);
    check_true("取最近显示器成功",
               GetMonitorInfoW(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                               &mi) != 0);
    wm_windows[id].resized = 0;
    wm_window_set_fullscreen(id, 1);
    check("进入全屏后 fullscreen == 1", wm_windows[id].fullscreen, 1);
    check_true("全屏样式无 WS_CAPTION",
               (GetWindowLongPtrW(hwnd, GWL_STYLE) & WS_CAPTION) == 0);
    check_true("全屏样式无 WS_THICKFRAME",
               (GetWindowLongPtrW(hwnd, GWL_STYLE) & WS_THICKFRAME) == 0);
    RECT wr;
    GetWindowRect(hwnd, &wr);
    check("全屏窗口 x == 显示器 x", wr.left, mi.rcMonitor.left);
    check("全屏窗口 y == 显示器 y", wr.top, mi.rcMonitor.top);
    check("全屏窗口宽 == 显示器宽", wr.right - wr.left,
          mi.rcMonitor.right - mi.rcMonitor.left);
    check("全屏窗口高 == 显示器高", wr.bottom - wr.top,
          mi.rcMonitor.bottom - mi.rcMonitor.top);
    check("全屏 WM_SIZE 记账置 resized", wm_windows[id].resized, 1);
    check("全屏客户区宽 == 显示器宽", wm_windows[id].width,
          mi.rcMonitor.right - mi.rcMonitor.left);
    check("全屏客户区高 == 显示器高", wm_windows[id].height,
          mi.rcMonitor.bottom - mi.rcMonitor.top);
    /* 幂等：重复进屏不折腾 */
    wm_window_set_fullscreen(id, 1);
    check("重复进全屏幂等", wm_windows[id].fullscreen, 1);
    /* 退屏：样式与位置现场还原 */
    wm_window_set_fullscreen(id, 0);
    check("退出全屏后 fullscreen == 0", wm_windows[id].fullscreen, 0);
    check_true("退出后有 WS_CAPTION",
               (GetWindowLongPtrW(hwnd, GWL_STYLE) & WS_CAPTION) != 0);
    RECT after;
    GetWindowRect(hwnd, &after);
    check("退出后窗口 x 还原", after.left, before.left);
    check("退出后窗口 y 还原", after.top, before.top);
    check("退出后窗口宽还原", after.right - after.left,
          before.right - before.left);
    check("退出后窗口高还原", after.bottom - after.top,
          before.bottom - before.top);
    /* 重复退屏幂等 */
    wm_window_set_fullscreen(id, 0);
    check("重复退全屏幂等", wm_windows[id].fullscreen, 0);
  }

  /* ⑨ 全局快捷键（W20b）：注册 → 线程队列投 WM_HOTKEY → wm_pump 截获 → poll
   * 取出。系统真实按键也是把 WM_HOTKEY 投到注册线程的队列（RegisterHotKey
   * 用 NULL hwnd），这里用 PostThreadMessageW 打同一条路，不依赖真按键。 */
  {
    int hid = wm_hotkey_register(2 | 4, 0x79); /* Ctrl+Alt+F9（内部位序 2=ctrl 4=alt）*/
    check_true("RegisterHotKey 成功（Ctrl+Alt+F9）", hid > 0);
    check("无触发时 poll 给 0", wm_hotkey_poll(), 0);
    /* 重复投两条只记一次（每注册一个 WM_HOTKEY 只置位一次） */
    PostThreadMessageW(GetCurrentThreadId(), WM_HOTKEY, (WPARAM)hid, 0);
    PostThreadMessageW(GetCurrentThreadId(), WM_HOTKEY, (WPARAM)hid, 0);
    wm_pump();
    check("wm_pump 截获后 poll 取出该 id", wm_hotkey_poll(), hid);
    check("同批第二条不重复报", wm_hotkey_poll(), 0);
    /* 系统排他：同一组合第二次注册必须失败 */
    check("同组合重复注册被系统拒绝", wm_hotkey_register(2 | 4, 0x79), 0);
    /* 注销后同 id 的 WM_HOTKEY 不再置位 */
    wm_hotkey_unregister(hid);
    PostThreadMessageW(GetCurrentThreadId(), WM_HOTKEY, (WPARAM)hid, 0);
    wm_pump();
    check("注销后同 id 的 WM_HOTKEY 不置位", wm_hotkey_poll(), 0);
  }

  /* ⑩ 非法句柄不崩、读回给 0 */
  wm_set_title(9999, "x");
  wm_set_icon(9999, 1, 2);
  wm_set_min_size(9999, 100, 100);
  wm_set_drag_rect(9999, 0, 0, 10, 10);
  wm_set_borderless(9999, 1);
  wm_window_set_size(9999, 100, 100);
  wm_window_set_fullscreen(9999, 1);
  check("越界 id 的 borderless 读回 0", wm_is_borderless(9999), 0);
  {
    int32_t mw = -1, mh = -1;
    wm_get_min_size(9999, &mw, &mh);
    check_true("越界 id 的 min_size 不写缓冲（保持初值）", mw == -1 && mh == -1);
    check("越界 id 的 title 读回 0 长度", wm_window_title(9999, NULL, 0), 0);
  }

  wm_close(id);
  printf(g_fail == 0 ? "WIN-ENHANCE-OK\n" : "WIN-ENHANCE-FAIL %d\n", g_fail);
  return g_fail == 0 ? 0 : 1;
}
