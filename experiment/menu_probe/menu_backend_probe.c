/* W20a 原生菜单后端探针（纯 C，直接 #include stub.c 拿到内部句柄表）。
 *
 * 动机：本机 moon 的 prebuild spawn 报 os error 231，`moon run`/`moon test` 走不通。
 * 菜单的 **MoonBit 模型侧**已由 experiment/menu_probe 的 main.mbt 在真机跑通，
 * 但 **C 后端**（CreateMenu/AppendMenuW/命令 id 分配）缺运行时回证。这里绕开
 * MoonBit 运行时，直喂 stub.c 的 wm_menu_* 入口，再用 Win32 自己的
 * GetMenuItemCount / GetMenuItemID / GetMenuState / GetMenuItemInfoW 反读结构。
 *
 * 为什么 include 而不是链接：wm_menu_bar_new 返回的是**句柄表下标**（1..31），
 * 真正的 HMENU 存在 stub.c 的静态表 wm_menus[] 里。反读菜单结构必须拿到真
 * HMENU；include 进同一翻译单元即可读静态表，不必为测试改生产代码。
 *
 * 编法（见 scripts/wbtest.sh 的说明；本文件独立于 moon 工具链）：
 *   cl /nologo /W4 /utf-8 /O2 /DWIN32 /D_WINDOWS menu_backend_probe.c
 *      /Fe:menu_backend_probe.exe user32.lib gdi32.lib imm32.lib advapi32.lib
 */
#include <windows.h>
#include <stdio.h>

/* stub.c 一个文件三条分支：_WIN32 真 Win32 实现 / WM_STUB_GTK / 其余占位。
 * 本探针只验 _WIN32 分支，故直接 include（拿静态句柄表）。 */
#include "../../yue/win/stub.c"

static int g_fail = 0;

static void check(const char *what, long long got, long long want) {
  if (got == want) {
    printf("PROBE ok   %-44s = %lld\n", what, got);
  } else {
    printf("PROBE FAIL %-44s = %lld (want %lld)\n", what, got, want);
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

/* 反读：把真实 HMENU 从内部表里取出来（下标越界给 NULL，调用方自己判） */
static HMENU real_menu(int slot) {
  if (slot <= 0 || slot >= WM_MAX_MENUS) {
    return NULL;
  }
  return wm_menus[slot];
}

int main(void) {
  /* ① 菜单条：句柄非 0、两枚不同，且内部表确实存了真 HMENU */
  int bar1 = wm_menu_bar_new();
  int bar2 = wm_menu_bar_new();
  check("bar1 handle > 0", bar1 > 0, 1);
  check("bar2 handle > 0", bar2 > 0, 1);
  check_true("bar1 != bar2 (slot 递增)", bar1 != bar2);
  check_true("bar1 内部表存了真 HMENU", real_menu(bar1) != NULL);
  HMENU hbar1 = real_menu(bar1);

  /* ② 顶级菜单（子菜单）挂在菜单条下 */
  int file = wm_menu_new_sub(bar1, "文件");
  check("new_sub(bar1,'文件') > 0", file > 0, 1);
  check("GetMenuItemCount(bar1) == 1", GetMenuItemCount(hbar1), 1);
  check("GetSubMenu(bar1,0) == file",
        (int)(intptr_t)GetSubMenu(hbar1, 0), (int)(intptr_t)real_menu(file));

  /* ③ 命令 id 从 1000 起顺序分配 */
  int i1 = wm_menu_add_item(file, "新建", 0, -1, "CmdOrCtrl+N", 0);
  int i2 = wm_menu_add_item(file, "打开", 0, -1, "", 0);
  int i3 = wm_menu_add_item(file, "保存", 0, -1, "CmdOrCtrl+S", 0);
  check("item 1 id == 1000", i1, 1000);
  check("item 2 id == 1001", i2, 1001);
  check("item 3 id == 1002", i3, 1002);
  {
    HMENU hf = real_menu(file);
    check("file item count == 3", GetMenuItemCount(hf), 3);
    check("GetMenuItemID(file,0) == 1000", GetMenuItemID(hf, 0), 1000);
    check("GetMenuItemID(file,2) == 1002", GetMenuItemID(hf, 2), 1002);
  }

  /* ④ 分隔线：返回 0，但确实占一个位置，且 Win32 侧认出 MF_SEPARATOR */
  int sep = wm_menu_add_item(file, "", 3, -1, "", 0);
  check("separator returns 0", sep, 0);
  {
    HMENU hf = real_menu(file);
    check("file item count == 4 after sep", GetMenuItemCount(hf), 4);
    check_true("pos 3 是 MF_SEPARATOR",
               (GetMenuState(hf, 3, MF_BYPOSITION) & MF_SEPARATOR) != 0);
    check_true("pos 3 的 id == 0（分隔线不占命令 id）",
               GetMenuItemID(hf, 3) == 0);
  }

  /* ⑤ check 项：kind=1 + checked → Win32 侧应置 MF_CHECKED */
  int chk = wm_menu_add_item(file, "自动换行", 1, -1, "", 1);
  check("check item id == 1003", chk, 1003);
  {
    HMENU hf = real_menu(file);
    check("file item count == 5 after check", GetMenuItemCount(hf), 5);
    check_true("check 项带 MF_CHECKED",
               (GetMenuState(hf, 4, MF_BYPOSITION) & MF_CHECKED) != 0);
  }

  /* ⑥ radio 项：kind=2 + checked → 同样置 MF_CHECKED（Win32 无独立 radio 位） */
  int rad = wm_menu_add_item(file, "深色主题", 2, -1, "", 1);
  check("radio item id == 1004", rad, 1004);
  {
    HMENU hf = real_menu(file);
    check_true("radio 项带 MF_CHECKED",
               (GetMenuState(hf, 5, MF_BYPOSITION) & MF_CHECKED) != 0);
  }
  /* 未勾选的同族项：不带 MF_CHECKED（变量名避开 Windows 头里的 rad2 宏） */
  {
    int radio_off = wm_menu_add_item(file, "浅色主题", 2, -1, "", 0);
    check("radio(off) id == 1005", radio_off, 1005);
    HMENU hf = real_menu(file);
    check("file item count == 7 after radios",
          GetMenuItemCount(hf), 7);
    check_true("radio(off) 不带 MF_CHECKED",
               (GetMenuState(hf, 6, MF_BYPOSITION) & MF_CHECKED) == 0);
  }

  /* ⑦ 嵌套子菜单：挂在 file 下，父菜单对应位置是 MF_POPUP 且指向真句柄 */
  int sub = wm_menu_new_sub(file, "更多");
  check("nested submenu > 0", sub > 0, 1);
  {
    HMENU hf = real_menu(file);
    check("file item count == 8 with submenu", GetMenuItemCount(hf), 8);
    check_true("pos 7 是 MF_POPUP",
               (GetMenuState(hf, 7, MF_BYPOSITION) & MF_POPUP) != 0);
    check("GetSubMenu(file,7) == sub",
          (int)(intptr_t)GetSubMenu(hf, 7), (int)(intptr_t)real_menu(sub));
    HMENU hs = real_menu(sub);
    int s1 = wm_menu_add_item(sub, "子项一", 0, -1, "", 0);
    check("nested item id == 1006", s1, 1006);
    check("sub item count == 1", GetMenuItemCount(hs), 1);
    check("GetMenuItemID(sub,0) == 1006", GetMenuItemID(hs, 0), 1006);
  }

  /* ⑧ 中文标签：UTF-8 → UTF-16 走 wm_utf8_to_wide；AppendMenuW 不应失败。
   * 同时验「\t 加速键提示」拼进标签（Win32 右对齐显示加速键）。 */
  int cn = wm_menu_add_item(file, "中文菜单项", 0, -1, "Ctrl+Alt+Q", 0);
  check("CJK label item id == 1007", cn, 1007);
  {
    HMENU hf = real_menu(file);
    wchar_t buf[256];
    MENUITEMINFOW mi;
    ZeroMemory(&mi, sizeof(mi));
    mi.cbSize = sizeof(mi);
    mi.fMask = MIIM_STRING;
    mi.dwTypeData = buf;
    mi.cch = 256;
    BOOL ok = GetMenuItemInfoW(hf, 8, TRUE, &mi);
    check_true("GetMenuItemInfoW 取到 CJK 项", ok == TRUE);
    check_true("CJK 标签 UTF-8→UTF-16 往返正确", wcsstr(buf, L"中文菜单项") != NULL);
    check_true("标签带 \\t + 加速键提示", wcsstr(buf, L"Ctrl+Alt+Q") != NULL);
  }

  /* ⑨ 非法父句柄：越界 / 空槽 / 负数都应返回 0，不能崩 */
  check("add_item(bad parent 99) == 0",
        wm_menu_add_item(99, "x", 0, -1, "", 0), 0);
  check("add_item(parent 0) == 0", wm_menu_add_item(0, "x", 0, -1, "", 0), 0);
  check("add_item(parent -1) == 0", wm_menu_add_item(-1, "x", 0, -1, "", 0), 0);
  check("new_sub(bad parent 99) == 0", wm_menu_new_sub(99, "x"), 0);

  /* ⑩ 空队列：还没任何 WM_COMMAND 时 poll 取回 0 */
  check("poll() == 0 when queue empty", wm_menu_poll(), 0);

  /* ⑪ 挂到不存在的窗口：wm_apply 应静默返回（不崩、不改菜单条）。
   * bar1 上只挂过「文件」一个顶级菜单 ⇒ 计数恒为 1。 */
  wm_menu_apply(9999, bar1);
  check("apply(bad window id) 后 bar1 计数不变",
        GetMenuItemCount(hbar1), 1);
  /* 卸载：bar=0 走 SetMenu(hwnd, NULL) 分支（同样对不存在的窗静默） */
  wm_menu_apply(9999, 0);
  check("apply(bar=0) 同样静默", wm_menu_poll(), 0);

  /* ⑫ 句柄表容量：WM_MAX_MENUS=32 个槽用尽后必须返回 0（不能越界写表） */
  {
    int ok_bars = 0;
    int slots[WM_MAX_MENUS * 2];
    int n = 0;
    for (int i = 0; i < WM_MAX_MENUS * 2; i++) {
      int h = wm_menu_bar_new();
      if (h > 0) {
        ok_bars++;
      }
      if (n < WM_MAX_MENUS * 2) {
        slots[n++] = h;
      }
    }
    check("句柄表用尽后 bar 返回 0（ok 数 == 31 - 已用）", ok_bars < WM_MAX_MENUS, 1);
    /* 释放刚建的，避免影响后续 slots 分配 */
    for (int i = 0; i < n; i++) {
      if (slots[i] > 0) {
        wm_menus[slots[i]] = NULL;
      }
    }
    (void)ok_bars;
  }

  /* ⑬ 命令 id 回绕：把 id 池用到底，验证 next 归位到 BASE 而不是溢出。
   * 关键事实：**Win32 单菜单项数上限 < id 池大小**（本机实测 ~1168 vs 池 2048），
   * 所以单靠一个菜单永远耗不尽池子——本用例跨多个菜单填满池，再在**有空间的
   * 新菜单**上加一项，观察它是否拿到归位后的 BASE。 */
  {
    int drain = wm_menu_bar_new();
    int bulk = wm_menu_new_sub(drain, "批量");
    HMENU hb = real_menu(bulk);
    check("bulk 初始为空", GetMenuItemCount(hb), 0);
    int cursor_before = wm_menu_cmd_next; // 前面用例已用掉若干 id，不假定起点
    int appended = 0;
    while (wm_menu_add_item(bulk, "项", 0, -1, "", 0) != 0) {
      appended++;
    }
    printf("PROBE info Win32 单菜单项数实测上限            = %d\n", appended);
    check_true("AppendMenuW 上限 > 1000（远大于一度菜单 30 项）", appended > 1000);
    check("到达上限后再加返回 0", wm_menu_add_item(bulk, "溢出", 0, -1, "", 0), 0);
    check("失败不消耗 id（游标仍指向未用 id）", wm_menu_cmd_next, cursor_before + appended);

    /* 跨菜单填满池：从当前游标一直填到归位回 BASE。 */
    int need = (WM_MENU_CMD_BASE + WM_MENU_CMD_MAX) - wm_menu_cmd_next;
    int filled = 0;
    int bar = wm_menu_bar_new();
    int slot = wm_menu_new_sub(bar, "填池");
    while (filled < need) {
      if (wm_menu_add_item(slot, "项", 0, -1, "", 0) == 0) {
        // 当前菜单满了：开新菜单接着填
        slot = wm_menu_new_sub(bar, "填池");
        if (slot == 0) {
          break;
        }
        continue;
      }
      filled++;
    }
    check("填满 id 池后 next 归位到 BASE", wm_menu_cmd_next, WM_MENU_CMD_BASE);
    int wrap = wm_menu_add_item(slot, "回绕", 0, -1, "", 0);
    check("配额耗尽后 id 归位到 1000", wrap, 1000);
    /* 顶层的句柄表项释放掉（drain 的菜单随进程退出销毁，无需手动） */
  }

  printf(g_fail == 0 ? "MENU-BACKEND-OK\n" : "MENU-BACKEND-FAIL %d\n", g_fail);
  return g_fail == 0 ? 0 : 1;
}
