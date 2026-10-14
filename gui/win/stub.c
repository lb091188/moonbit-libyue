// MoonBit 原生 GUI 栈的平台后端桩：一个文件、三条平台分支，对外是 ffi.mbt
// 那套 wm_* 统一 API（MoonBit 侧 window.mbt 平台无关，core 只认这一层）。
//
//   _WIN32        → Win32 真实现。由 moon 的 native-stub 自编（windows.h 走
//                    MSVC 自带 SDK 路径，实测可达，探针记录见 adaptation），
//                    系统库链接参数由 prebuild 的 Windows 分支下发。
//   WM_STUB_GTK   → GTK3 真实现（Linux）。仅 scripts/prebuild.py 带
//                    -DWM_STUB_GTK + pkg-config 头文件路径编译进
//                    build/libyue_win_stub.a；moon 的 native-stub 拿不到
//                    GTK 头路径（link_configs 只有链接期字段，G0 实测），
//                    所以不带宏的那次编译必须落不进这个分支。
//   其余（macOS） → 占位空实现，保证链接不断符号。
//
// 分支顺序有讲究：Linux 上 native-stub 也会编译本文件（不带宏），必须让
// 它编出空翻译单元——否则 wm_* 会与 prebuild 的 .a 双定义。空 TU 在本链
// 已验证可行（原 portable 文件在 Linux 上就是空编）。
//
// 形态约束（都来自本仓实测，docs/zh/adaptation.md）：
// - 循环归 MoonBit：这里只提供「等一等」与「跑已就绪的事件」两个动作，不自带
//   主循环；等待多久由 yue/core 的 Loop::wait_budget 给（负数即无限等，靠
//   wakeup 位回来）。
// - 不做 C→MoonBit 回调：事件以「每窗口标志位 + 消费式取事件」暴露，避开蹦床
//   形参错位那一类坑（docs/zh/adaptation.md「MoonBit ↔ C ABI」）。
// - 像素缓冲归 MoonBit：present 收到的就是 yue/render 的 Bitmap（ARGB32 预乘，
//   小端字节序 B,G,R,A），本层只负责贴屏，与离屏快照同源。

// MoonBit 运行时：造一个 Bytes 对象（桩里往外返回文本时用）。这里必须显式
// 声明——本文件由 prebuild 直接编，拿不到 moon 的 moonbit.h 包含路径；不声明
// 就是隐式声明，cc 会按「返回 int」假定，x86-64 下指针被截成 32 位，调用方拿
// 到的是垃圾地址（实测 SIGSEGV）。签名与 ~/.moon/include/moonbit.h 逐位对齐。
extern void *moonbit_make_bytes(int size, int value);

#if defined(_WIN32)

// ---------------- Win32 后端 ----------------

// 本 TU 全用 W 系 API：强制 UNICODE 让 IDC_* 等宏取宽字符变体（默认 ANSI
// 变体是 LPSTR，与 LoadCursorW 的 LPCWSTR 形参类型不合，MSVC C4133）
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
// WIN32_LEAN_AND_MEAN 会把 shellapi.h 一并裁掉，而托盘（W20c）要的
// Shell_NotifyIconW / NOTIFYICONDATAW / NIM_* / NIF_* 全在它里面，必须显式引。
#include <shellapi.h>
#include <imm.h> // IME 纯通道（W6）：ImmGetContext/ImmSet*Window/ImmNotifyIME
#include <stdint.h>
#include <string.h>
// 本分支用 snprintf 格式化注册表读出的主色（缺了它 MSVC 报 C4013 隐式声明，
// 默认返回 int 并与 varargs 混用，是「能编过但口径不可信」的形态）；
// IME 段的宽串转 UTF-8 走 malloc/free，故 stdlib 也要
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h> // 菜单标签拼接用 wcsncpy/wcslen/wcsncat（W20a）
// 图标加载（W20f）：PNG 无原生 Win32 入口，只能走 WIC 从内存解码；COM 初始化
// 与 CoCreateInstance 在 objbase.h。GUID 常量由 wincodec.h 声明、链接期取
// windowscodecs.lib / uuid.lib（C 模式用不了 __uuidof，与 W14 文件对话框同条坑）。
#include <objbase.h>
#include <wincodec.h>
// 任务栏进度（§6.3）：ITaskbarList3 与 TBPF_* 在 shobjidl.h；GUID 常量
// （CLSID_TaskbarList / IID_ITaskbarList3）经 uuid.lib 链接期取符号
#include <shobjidl.h>

#define WM_MAX_WINDOWS 32

typedef struct {
  uint32_t keysym;
  uint32_t code; // 0 键按下 1 键释放 2 按钮按下 3 按钮释放 4 指针移动 5 滚轮
  int32_t x;
  int32_t y;
  int32_t dx;
  int32_t dy;
  uint32_t mods;
} WmEv;

typedef struct {
  HWND hwnd;
  int need_draw;     // 需要重绘（WM_PAINT 或尺寸变化后置 1）
  int resized;       // 尺寸变了，本次取事件时回报新宽高
  int closing;       // WM_CLOSE / WM_DESTROY（MoonBit 驱动销毁）
  int width;         // 客户区物理像素（per-monitor v2，整栈物理像素口径）
  int height;
  int pending_w;
  int pending_h;
  // 帧拷贝：present 时把像素复制进来。**不能只存 MoonBit 的指针**——那是
  // paint_frame 里的局部 Bitmap，函数一返回就成了 GC 的猎物，WM_PAINT 晚些
  // 时候去贴读到的就是悬垂内存（实测：窗口内容整片纯黑，而绘制过程一切正常）。
  // 本缓冲归桩所有，按尺寸增长复用。
  unsigned char *frame;
  int frame_cap;
  int cursor_kind;   // 0 默认/1 手/2 文本/3 横向/4 纵向
  char commit[256];  // 已提交文本（UTF-8；WM_IME_COMPOSITION 的 GCS_RESULTSTR）
  int commit_len;
  char preedit[256]; // 组合串（UTF-8；GCS_COMPSTR，仅供自绘，不进文本状态）
  int preedit_len;
  int preedit_caret;
  int preedit_active;
  // 输入框光标的客户区矩形（wm_im_set_cursor 落点，IME 组合/候选窗按它摆）
  int im_cx;
  int im_cy;
  int im_cw;
  int im_ch;
  int im_cursor_set;
  // 窗口增强（W20e）：最小客户区尺寸（0 = 该轴不限制，WM_GETMINMAXINFO 拦）；
  // 自绘标题栏拖拽区（客户区像素矩形，w/h<=0 = 无，WM_NCHITTEST 内返回
  // HTCAPTION 交系统拖窗）；无边框开关（自绘标题栏形态）。
  int min_w;
  int min_h;
  int drag_x;
  int drag_y;
  int drag_w;
  int drag_h;
  int borderless;
  WmEv evs[64];
  WmEv last;
  int ev_head;
  int ev_count;
} WmWindow;

#define WM_MAX_SURFACES 64
typedef struct {
  HWND hwnd; // 面板子窗；非 NULL 即槽在用。窗随父销毁（Win32 父子关系），槽位由 wm_close 清
  int64_t window_id;
  int kind;
  int x, y, w, h;
} WmSurface;
static WmSurface wm_surfaces[WM_MAX_SURFACES]; // 槽 0 未用，句柄 = 槽号（1 起）

static WmWindow wm_windows[WM_MAX_WINDOWS]; // 槽 0 未用，句柄 = 槽号（1 起）
static int wm_next_id = 1;
static HWND wm_waker = NULL; // 仅消息窗口：wm_wakeup 的投递目标（跨线程叫醒）

/* 前置声明：UTF-8 → UTF-16 的公共转换（定义在文件后半），窗口增强（W20e）
 * 的改标题等入口在它之前定义。 */
static WCHAR *wm_utf8_to_wide(const char *s);
/* 前置声明：图标表取句柄（W20f 的图标表定义在窗口增强之后）。 */
static HICON wm_icon_get(int slot);

/* 菜单句柄表（W20a）：下标即对外句柄（1 起）。每个槽存一个 HMENU——菜单条或
 * 子菜单都占一个槽；子菜单的 HMENU 由 CreatePopupMenu 建、AppendMenuW(MF_POPUP)
 * 挂进父。槽 0 未用。命令 id 表与「可点击项前序序号」对齐，供回调对表。 */
#define WM_MAX_MENUS 32
static HMENU wm_menus[WM_MAX_MENUS];
static int wm_menus_next = 1;

/* ---- 全局快捷键（W20b）---------------------------------------------------
 * RegisterHotKey 注册的热键以 WM_HOTKEY 投给**线程消息队列**（hwnd 传 NULL
 * 时），所以不需要窗口槽：本文件另起一张进程级表，槽号即对外 id。命中时
 * WndProc 收不到（消息进的是注册线程队列），改由 wm_hotkey_poll 在 MoonBit
 * 的泵里主动抽——与 DBus 线「宿主周期 pump」同一形态，避免 C→MoonBit 回调。
 * 注册 id 与窗口无关（旧栈 register_global_shortcut 同语义）。
 * 表声明必须在 wm_pump 之前（pump 里要截 WM_HOTKEY 置位）。 */
#define WM_MAX_HOTKEYS 32
static int wm_hotkeys[WM_MAX_HOTKEYS]; // 1 = 已注册；下标即对外 id
static int wm_hotkey_fired[WM_MAX_HOTKEYS]; // 1 = 本轮已触发待取
static int wm_hotkey_fired_count = 0;

/* ---- 原生菜单（W20a）-----------------------------------------------------
 * 菜单是**每窗口一份**（HMENU 挂 SetMenu），菜单项点击经 WM_COMMAND 回来。
 * 与热键同一形态：C 侧不回调 MoonBit，命中时把「命令 id」压进进程级队列，
 * MoonBit 侧 `wm_menu_poll` 在泵里抽；回调（MenuItem::on_click）由模型层按
 * native_id 持表（见 yue/core/menu.mbt 与其翻译层）。
 * 句柄用「进程级表下标」表示（与窗口槽同制）：建菜单树是逐节点 FFI，节点句柄
 * 就是表下标，MoonBit 侧拿着它继续往下加子项。命令 id 从 1000 起递增分配，
 * 与「可点击项」一一对应。表要在 wm_pump/wm_wndproc 之前声明（两处都要用）。 */
#define WM_MENU_CMD_BASE 1000
// id 池大小。实测 Win32 单菜单项数上限约 1168（见 menu_backend_probe.c），池
// 取 2048 保证 > 单菜单上限 ⇒ 只填一个菜单绝不会回绕、也就不会自相撞 id。
#define WM_MENU_CMD_MAX 2048
static int wm_menu_cmd_next = WM_MENU_CMD_BASE; // 下一个待分配命令 id（成功才推进）
// 已触发待取的命令 id 队列（环形；满了丢最旧）
static int wm_menu_fired[64];
static int wm_menu_fired_head = 0;
static int wm_menu_fired_count = 0;

static void wm_menu_push(int cmd) {
  if (wm_menu_fired_count >= 64) {
    wm_menu_fired_head = (wm_menu_fired_head + 1) % 64;
    wm_menu_fired_count--;
  }
  wm_menu_fired[(wm_menu_fired_head + wm_menu_fired_count) % 64] = cmd;
  wm_menu_fired_count++;
}

void wm_pump(void); // wm_show 里要先跑一轮就绪消息，实现在下方

// 修饰位与 yue/core/keys.mbt 的 MOD_* 一致：1=shift 2=ctrl 4=alt 8=meta
// （meta 取 Win 键，不碰 NumLock——GTK 桩同一条教训）。
static uint32_t wm_mods(void) {
  uint32_t m = 0;
  if (GetKeyState(VK_SHIFT) & 0x8000) {
    m |= 1u;
  }
  if (GetKeyState(VK_CONTROL) & 0x8000) {
    m |= 2u;
  }
  if (GetKeyState(VK_MENU) & 0x8000) {
    m |= 4u;
  }
  if ((GetKeyState(VK_LWIN) | GetKeyState(VK_RWIN)) & 0x8000) {
    m |= 8u;
  }
  return m;
}

// VK → X11 keysym（GDK keyval 口径，与 yue/core/keys.mbt 的 KS_* 同源）。
// 只列特殊键与字母数字基准面；可打印字符优先走 wm_char_keysym 的布局换算。
static uint32_t wm_vk_keysym(WPARAM vk) {
  switch (vk) {
    case VK_BACK: return 0xff08;   // BackSpace
    case VK_TAB: return 0xff09;    // Tab
    case VK_RETURN: return 0xff0d; // Return
    case VK_ESCAPE: return 0xff1b; // Escape
    case VK_HOME: return 0xff50;
    case VK_LEFT: return 0xff51;
    case VK_UP: return 0xff52;
    case VK_RIGHT: return 0xff53;
    case VK_DOWN: return 0xff54;
    case VK_PRIOR: return 0xff55;  // Page_Up
    case VK_NEXT: return 0xff56;   // Page_Down
    case VK_END: return 0xff57;
    case VK_INSERT: return 0xff63;
    case VK_DELETE: return 0xffff;
    case VK_SHIFT: return 0xffe1;
    case VK_CONTROL: return 0xffe5;
    case VK_MENU: return 0xffe9;   // Alt_L
    case VK_LWIN: return 0xffeb;   // Super_L
    case VK_RWIN: return 0xffec;   // Super_R
    case VK_NUMPAD0: return 0xffb0;
    case VK_NUMPAD1: return 0xffb1;
    case VK_NUMPAD2: return 0xffb2;
    case VK_NUMPAD3: return 0xffb3;
    case VK_NUMPAD4: return 0xffb4;
    case VK_NUMPAD5: return 0xffb5;
    case VK_NUMPAD6: return 0xffb6;
    case VK_NUMPAD7: return 0xffb7;
    case VK_NUMPAD8: return 0xffb8;
    case VK_NUMPAD9: return 0xffb9;
    case VK_MULTIPLY: return 0xffaa;
    case VK_ADD: return 0xffab;
    case VK_SEPARATOR: return 0xffac;
    case VK_SUBTRACT: return 0xffad;
    case VK_DECIMAL: return 0xffae;
    case VK_DIVIDE: return 0xffaf;
    default: break;
  }
  if (vk >= 'A' && vk <= 'Z') {
    return (uint32_t)('a' + (vk - 'A'));
  }
  if (vk >= '0' && vk <= '9') {
    return (uint32_t)('0' + (vk - '0'));
  }
  if (vk == VK_SPACE) {
    return 0x20;
  }
  return 0;
}

// 按键的字符面：GDK keyval 同口径——ASCII/Latin-1 原值，其余 0x01000000|unicode
// （keysym_is_printable / keysym_to_text 只认前两段，与 GDK 行为一致，更宽的
// 语言字符走 IME 线）。死键（返回负）与多字符输出按无可打印字符处理，退回
// VK 表；Ctrl 组合键把控制位从状态副本里摘掉再换算，取基准字符（GDK 的
// Ctrl+A keyval 是 'a'，修饰走 mods，控制字符会让内核的 Ctrl+A 判定失效）。
static uint32_t wm_char_keysym(WPARAM vk, LPARAM lp) {
  BYTE ks[256];
  if (GetKeyboardState(ks) == FALSE) {
    return 0;
  }
  ks[VK_CONTROL] = 0;
  wchar_t buf[8];
  int n = ToUnicode((UINT)vk, (UINT)((lp >> 16) & 0xff), ks, buf, 8, 0);
  if (n != 1) {
    return 0;
  }
  uint32_t u = (uint32_t)buf[0];
  if (u >= 0x20) {
    return u; // 可打印（含中文）：Unicode 码点即内核口径
  }
  // 控制字符按 X11 口径给关键 keysym——内核的 KS_* 就是这一套（Tab=0xFF09、
  // Return=0xFF0D、Backspace=0xFF08、Escape=0xFF1B、Delete=0xFFFF）。早先按
  // GDK 约定给 0x01000000|u，宿主认不出 Tab/回车（实测：Tab 被当可打印字符
  // 插进输入框、回车提交失灵）
  switch (u) {
    case 0x08:
      return 0xff08;
    case 0x09:
      return 0xff09;
    case 0x0d:
      return 0xff0d;
    case 0x1b:
      return 0xff1b;
    case 0x7f:
      return 0xffff;
    default:
      break;
  }
  return 0;
}

// 滚轮跨 HWND 探针槽：web 能力桩（WebView2）在 create 时注册
// 「屏幕坐标是否落在网页上，是则返回该处理的引擎窗口」。函数指针而非
// 直接 extern 调 wb_*——不用 web 包的 app 链接不到那些符号。
static int64_t (*wm_wheel_probe)(int64_t sx, int64_t sy) = NULL;
void wm_set_wheel_probe(int64_t (*fn)(int64_t sx, int64_t sy)) {
  wm_wheel_probe = fn;
}

static void wm_push(WmWindow *w, const WmEv *ev) {
  // 指针移动先合并：队列里最后一条也是**未消费**的移动时直接替换（位置是状态、
  // 不是流水，只留最新一条语义不丢）。一帧（真机 300–500ms 量级）里能攒下上百条
  // 移动事件，64 槽的队列会被它们塞满，随后的抬起/滚轮就整批丢掉——真机表现正是
  // 「按钮点了没反应、表头点了不排序、滚轮不滚」。合并后队列里任何时刻最多一条
  // 移动，抬起与滚轮不会再被挤掉。只在「最后一条也是移动」时替换：中间夹着
  // 按下/抬起就不动它，FIFO 语义不破。
  if (ev->code == 4u && w->ev_count > 0) {
    int last = (w->ev_head + w->ev_count - 1) % 64;
    if (w->evs[last].code == 4u) {
      w->evs[last] = *ev;
      return;
    }
  }
  if (w->ev_count >= 64) {
    return; // 满了丢弃而不是覆盖：宁可丢一个事件，不能把 FIFO 打乱
  }
  int slot = (w->ev_head + w->ev_count) % 64;
  w->evs[slot] = *ev;
  w->ev_count++;
}

// ---------------------------------------------------------------------------
// IME 纯通道（W6）：组合串与提交串都走自绘（preedit 下划线由 MoonBit 侧画），
// 系统那份组合 UI 在 WM_IME_SETCONTEXT 里滤掉。缓冲口径与 GTK 分支逐条对齐：
// commit/preedit 都是 UTF-8 字节流、preedit_caret 也是字节偏移、容量 255。
// 平台差异（记档）：legacy IMM32 没有 surrounding-text 接口（那是 TSF 的），
// wm_im_set_surrounding 只能空操作——Windows 的 IME 从自身组合状态取上下文。
// ---------------------------------------------------------------------------

// 宽串 → UTF-8 存进定长缓冲（超 255 字节截断，与 GTK 侧上限同口径）
static void wm_store_wide(char *dst, int *dst_len, const wchar_t *src, int wlen) {
  int need = WideCharToMultiByte(CP_UTF8, 0, src, wlen, NULL, 0, NULL, NULL);
  if (need <= 0) {
    dst[0] = '\0';
    *dst_len = 0;
    return;
  }
  char *tmp = (char *)malloc((size_t)need + 1);
  if (tmp == NULL) {
    dst[0] = '\0';
    *dst_len = 0;
    return;
  }
  WideCharToMultiByte(CP_UTF8, 0, src, wlen, tmp, need, NULL, NULL);
  int n = need > 255 ? 255 : need;
  memcpy(dst, tmp, (size_t)n);
  dst[n] = '\0';
  *dst_len = n;
  free(tmp);
}

// 宽串前缀的 UTF-8 字节数（组合串的光标是字符偏移，MoonBit 侧口径是字节）
static int wm_wide_prefix_bytes(const wchar_t *src, int wchars) {
  if (wchars <= 0) {
    return 0;
  }
  int n = WideCharToMultiByte(CP_UTF8, 0, src, wchars, NULL, 0, NULL, NULL);
  return n > 0 ? n : 0;
}

// 把最近下发的输入框光标矩形喂给 IME：组合窗贴光标底边、候选窗同点
static void wm_im_apply_cursor(WmWindow *w) {
  HIMC himc = ImmGetContext(w->hwnd);
  if (himc == NULL) {
    return;
  }
  POINT pt;
  pt.x = w->im_cx;
  pt.y = w->im_cy + w->im_ch;
  COMPOSITIONFORM cf;
  cf.dwStyle = CFS_POINT;
  cf.ptCurrentPos = pt;
  ImmSetCompositionWindow(himc, &cf);
  CANDIDATEFORM cand;
  cand.dwIndex = 0;
  cand.dwStyle = CFS_CANDIDATEPOS;
  cand.ptCurrentPos = pt;
  ImmSetCandidateWindow(himc, &cand);
  ImmReleaseContext(w->hwnd, himc);
}

// WM_IME_COMPOSITION：GCS_RESULTSTR → commit（已提交，进文本状态）；
// GCS_COMPSTR → preedit（仅供自绘，绝不进文本状态），光标由字符偏移换字节偏移
static void wm_im_read_composition(WmWindow *w, LPARAM lp) {
  HIMC himc = ImmGetContext(w->hwnd);
  if (himc == NULL) {
    return;
  }
  if ((lp & GCS_RESULTSTR) != 0) {
    int n = ImmGetCompositionStringW(himc, GCS_RESULTSTR, NULL, 0);
    if (n > 0) {
      wchar_t *buf = (wchar_t *)malloc((size_t)n + sizeof(wchar_t));
      if (buf != NULL) {
        int got = ImmGetCompositionStringW(himc, GCS_RESULTSTR, buf, n);
        if (got > 0) {
          wm_store_wide(w->commit, &w->commit_len, buf,
                        got / (int)sizeof(wchar_t));
        }
        free(buf);
      }
    }
  }
  if ((lp & GCS_COMPSTR) != 0) {
    int n = ImmGetCompositionStringW(himc, GCS_COMPSTR, NULL, 0);
    if (n > 0) {
      wchar_t *buf = (wchar_t *)malloc((size_t)n + sizeof(wchar_t));
      if (buf != NULL) {
        int got = ImmGetCompositionStringW(himc, GCS_COMPSTR, buf, n);
        int wlen = got > 0 ? got / (int)sizeof(wchar_t) : 0;
        wm_store_wide(w->preedit, &w->preedit_len, buf, wlen);
        int caret_chars = ImmGetCompositionStringW(himc, GCS_CURSORPOS, NULL, 0);
        int caret_bytes = 0;
        if (caret_chars > 0) {
          caret_bytes = caret_chars > wlen ? w->preedit_len
                                           : wm_wide_prefix_bytes(buf, caret_chars);
        }
        w->preedit_caret = caret_bytes > w->preedit_len ? w->preedit_len
                                                        : caret_bytes;
        w->preedit_active = w->preedit_len > 0 ? 1 : 0;
        free(buf);
      }
    } else {
      w->preedit_len = 0;
      w->preedit[0] = '\0';
      w->preedit_caret = 0;
      w->preedit_active = 0;
    }
  }
  ImmReleaseContext(w->hwnd, himc);
}

static WmWindow *wm_of(HWND hwnd) {
  LONG_PTR slot = GetWindowLongPtrW(hwnd, GWLP_USERDATA);
  if (slot <= 0 || slot >= WM_MAX_WINDOWS) {
    return NULL;
  }
  return &wm_windows[slot];
}

static HCURSOR wm_load_cursor(int kind) {
  LPCWSTR name = IDC_ARROW;
  if (kind == 1) {
    name = IDC_HAND;
  } else if (kind == 2) {
    name = IDC_IBEAM;
  } else if (kind == 3) {
    name = IDC_SIZEWE;
  } else if (kind == 4) {
    name = IDC_SIZENS;
  }
  return LoadCursorW(NULL, name);
}

// pending 缓冲直贴：Bitmap 布局 = cairo ARGB32（小端字节 B,G,R,A），GDI 的
// 32bpp BI_RGB 顶底 DIB 字节口径完全一致，无需换序；负高 = 自上而下。
static void wm_blit(HDC dc, WmWindow *w) {
  if (w->frame == NULL || w->pending_w < 1 || w->pending_h < 1) {
    return;
  }
  BITMAPINFO bi;
  memset(&bi, 0, sizeof(bi));
  bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bi.bmiHeader.biWidth = w->pending_w;
  bi.bmiHeader.biHeight = -w->pending_h;
  bi.bmiHeader.biPlanes = 1;
  bi.bmiHeader.biBitCount = 32;
  bi.bmiHeader.biCompression = BI_RGB;
  StretchDIBits(dc, 0, 0, w->pending_w, w->pending_h, 0, 0, w->pending_w,
                w->pending_h, w->frame, &bi, DIB_RGB_COLORS, SRCCOPY);
}

static LRESULT CALLBACK wm_wndproc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
  switch (msg) {
    case WM_CREATE: {
      // CreateWindowW 期间就会来 WM_SIZE：槽号经 CREATESTRUCT 先行落位
      CREATESTRUCTW *cs = (CREATESTRUCTW *)lp;
      SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)(intptr_t)cs->lpCreateParams);
      return 0;
    }
    case WM_SIZE: {
      WmWindow *w = wm_of(hwnd);
      if (w != NULL && wp != SIZE_MINIMIZED) {
        int cw = (int)(int16_t)LOWORD(lp);
        int ch = (int)(int16_t)HIWORD(lp);
        if (cw > 0 && ch > 0 && (cw != w->width || ch != w->height)) {
          w->width = cw;
          w->height = ch;
          w->resized = 1;
          w->need_draw = 1;
        }
      }
      return 0;
    }
    case WM_PAINT: {
      // 有帧就贴帧、**不置 need_draw**。这条曾经置脏（「expose 即标脏，交 MoonBit
      // 重画」），但 present 自己每帧都 InvalidateRect，于是构成自维持环：
      // present → WM_PAINT → 置脏 → MoonBit 全帧重画 → present → …
      // 应用永不空闲，输入事件只能排在一帧之后（真机：1400×3520 的一帧 300–500ms，
      // 滚动/点击/悬浮全像卡住，且事件队列被鼠标移动塞满后开始丢抬起与滚轮）。
      // 重绘请求一律由 MoonBit 侧的 schedule_paint（`@core.invalidate`）发起；
      // 这里只在「还没有任何帧可贴」（首帧之前）时才要一次。
      WmWindow *w = wm_of(hwnd);
      PAINTSTRUCT ps;
      HDC dc = BeginPaint(hwnd, &ps);
      if (w != NULL) {
        if (w->frame != NULL && w->pending_w > 0 && w->pending_h > 0) {
          wm_blit(dc, w);
        } else {
          w->need_draw = 1;
          HBRUSH b = CreateSolidBrush(RGB(0, 0, 0));
          FillRect(dc, &ps.rcPaint, b);
          DeleteObject(b);
        }
      }
      EndPaint(hwnd, &ps);
      return 0;
    }
    case WM_ERASEBKGND:
      return 1; // 全窗自绘，不擦底防闪
    case WM_GETMINMAXINFO: {
      // 最小尺寸（W20e）：ptMinTrackSize 要的是**整窗**尺寸，按当前样式的
      // 非客户区把客户区最小尺寸外扩；某轴为 0 即该轴不限制（显式归 0，
      // 否则 AdjustWindowRect 会把零宽也算出 2×边框宽）。
      WmWindow *w = wm_of(hwnd);
      if (w != NULL && (w->min_w > 0 || w->min_h > 0)) {
        MINMAXINFO *mmi = (MINMAXINFO *)lp;
        DWORD st = (DWORD)GetWindowLongPtrW(hwnd, GWL_STYLE);
        DWORD ex = (DWORD)GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
        RECT r = {0, 0, w->min_w > 0 ? w->min_w : 0, w->min_h > 0 ? w->min_h : 0};
        AdjustWindowRectEx(&r, st, FALSE, ex);
        mmi->ptMinTrackSize.x = w->min_w > 0 ? (r.right - r.left) : 0;
        mmi->ptMinTrackSize.y = w->min_h > 0 ? (r.bottom - r.top) : 0;
      }
      return 0;
    }
    case WM_NCHITTEST: {
      // 自绘标题栏拖拽区（W20e）：命中即回 HTCAPTION，把拖窗交给系统；
      // 不在区内走默认（客户区/边框各自的原生语义）。
      WmWindow *w = wm_of(hwnd);
      if (w != NULL && w->drag_w > 0 && w->drag_h > 0) {
        POINT p;
        p.x = (LONG)(int16_t)LOWORD(lp);
        p.y = (LONG)(int16_t)HIWORD(lp);
        ScreenToClient(hwnd, &p);
        if (p.x >= w->drag_x && p.x < w->drag_x + w->drag_w &&
            p.y >= w->drag_y && p.y < w->drag_y + w->drag_h) {
          return HTCAPTION;
        }
      }
      break;
    }
    case WM_COMMAND: {
      // 菜单/加速键命令：LOWORD(wp) 是命令 id，HIWORD(wp) 为 0（菜单选择）
      // 或 1（加速键）。不论来源都压进队列，MoonBit 侧按 id 找回调。
      int cmd = (int)LOWORD(wp);
      if (cmd >= WM_MENU_CMD_BASE && cmd < WM_MENU_CMD_BASE + WM_MENU_CMD_MAX) {
        wm_menu_push(cmd);
      }
      return 0;
    }
    case WM_CLOSE: {
      WmWindow *w = wm_of(hwnd);
      if (w != NULL) {
        w->closing = 1;
      }
      return 0; // 不在此处销毁：先停派发、再拆对象由 MoonBit 侧驱动
    }
    case WM_DESTROY: {
      WmWindow *w = wm_of(hwnd);
      if (w != NULL) {
        w->hwnd = NULL;
        w->pending_w = 0;
        w->pending_h = 0;
        w->need_draw = 0;
        w->closing = 1; // 窗口没了也等于该退出了
      }
      return 0;
    }
    case WM_KEYDOWN:
    case WM_SYSKEYDOWN:
    case WM_KEYUP:
    case WM_SYSKEYUP: {
      // Alt+F4 放回系统：走默认派发生成 WM_CLOSE，与「窗口管理器请求关闭」
      // 同语义；其余系统键全部自己吃（F10 菜单栏、Alt+空格系统菜单本栈没有）
      if (msg == WM_SYSKEYDOWN && wp == VK_F4 && (GetKeyState(VK_MENU) & 0x8000)) {
        break;
      }
      WmWindow *w = wm_of(hwnd);
      if (w != NULL) {
        uint32_t ks = wm_char_keysym(wp, lp);
        if (ks == 0) {
          ks = wm_vk_keysym(wp);
        }
        if (ks != 0) {
          WmEv e;
          memset(&e, 0, sizeof(e));
          e.code = (msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN) ? 0u : 1u;
          e.keysym = ks;
          e.mods = wm_mods();
          wm_push(w, &e);
        }
      }
      return 0;
    }
    case WM_LBUTTONDOWN:
    case WM_MBUTTONDOWN:
    case WM_RBUTTONDOWN:
    case WM_LBUTTONUP:
    case WM_MBUTTONUP:
    case WM_RBUTTONUP:
    case WM_MOUSEMOVE: {
      WmWindow *w = wm_of(hwnd);
      if (w != NULL) {
        WmEv e;
        memset(&e, 0, sizeof(e));
        if (msg == WM_MOUSEMOVE) {
          e.code = 4u;
        } else if (msg == WM_LBUTTONDOWN || msg == WM_MBUTTONDOWN ||
                   msg == WM_RBUTTONDOWN) {
          e.code = 2u;
          SetCapture(hwnd); // 按住拖出窗沿仍收移动（GDK 按下期隐式抓取的等价物）
        } else {
          e.code = 3u;
          if ((wp & (MK_LBUTTON | MK_MBUTTON | MK_RBUTTON)) == 0) {
            ReleaseCapture();
          }
        }
        e.x = (int16_t)LOWORD(lp);
        e.y = (int16_t)HIWORD(lp);
        // 按钮号与 GDK 一致：1 左 2 中 3 右
        e.dx = (msg == WM_LBUTTONDOWN || msg == WM_LBUTTONUP) ? 1
             : (msg == WM_MBUTTONDOWN || msg == WM_MBUTTONUP) ? 2 : 3;
        e.mods = wm_mods();
        wm_push(w, &e);
      }
      return 0;
    }
    case WM_MOUSEWHEEL:
    case WM_MOUSEHWHEEL: {
      // 悬停在网页上时轮子归网页（GTK「悬停即滚」观感）：probe 说该点是
      // 引擎窗口就原样转过去。lp 是屏幕坐标，两边的分支各自做客户区换算。
      if (wm_wheel_probe != NULL) {
        int64_t target =
            wm_wheel_probe((int16_t)LOWORD(lp), (int16_t)HIWORD(lp));
        if (target != 0) {
          return SendMessageW((HWND)(intptr_t)target, msg, wp, lp);
        }
      }
      WmWindow *w = wm_of(hwnd);
      if (w != NULL) {
        WmEv e;
        memset(&e, 0, sizeof(e));
        e.code = 5u;
        POINT pt;
        pt.x = (int16_t)LOWORD(lp);
        pt.y = (int16_t)HIWORD(lp);
        ScreenToClient(hwnd, &pt); // 滚轮的 lParam 是屏幕坐标，其余是客户区
        e.x = pt.x;
        e.y = pt.y;
        short delta = (short)HIWORD(wp);
        // GTK 桩口径：上/左 = 1，下/右 = -1
        if (msg == WM_MOUSEWHEEL) {
          e.dy = delta > 0 ? 1 : -1;
        } else {
          e.dx = delta > 0 ? -1 : 1;
        }
        e.mods = wm_mods();
        wm_push(w, &e);
      }
      return 0;
    }
    case WM_SETCURSOR: {
      if (LOWORD(lp) == HTCLIENT) {
        WmWindow *w = wm_of(hwnd);
        if (w != NULL) {
          SetCursor(wm_load_cursor(w->cursor_kind));
          return 1;
        }
      }
      break; // 非客户区走默认
    }
    case WM_DPICHANGED: {
      // per-monitor v2：按系统建议矩形重摆，WM_SIZE 负责记账
      WmWindow *w = wm_of(hwnd);
      RECT *r = (RECT *)lp;
      if (w != NULL && r != NULL) {
        SetWindowPos(hwnd, NULL, r->left, r->top, r->right - r->left,
                     r->bottom - r->top, SWP_NOZORDER | SWP_NOACTIVATE);
      }
      return 0;
    }
    case WM_IME_SETCONTEXT:
      // 组合串与候选窗由本栈自绘（纯通道），别让系统再画一份：不滤掉
      // ISC_SHOWUICOMPOSITIONWINDOW 就会在窗口上叠出输入法自带的组合窗
      lp &= ~ISC_SHOWUICOMPOSITIONWINDOW;
      return DefWindowProcW(hwnd, msg, wp, lp);
    case WM_IME_STARTCOMPOSITION: {
      // 组合开始：把最近下发的光标矩形再喂一次（有些 IME 只在这时读位置）
      WmWindow *w = wm_of(hwnd);
      if (w != NULL && w->im_cursor_set) {
        wm_im_apply_cursor(w);
      }
      return 0;
    }
    case WM_IME_COMPOSITION: {
      WmWindow *w = wm_of(hwnd);
      if (w != NULL) {
        wm_im_read_composition(w, (LPARAM)lp);
      }
      return 0;
    }
    case WM_IME_ENDCOMPOSITION: {
      WmWindow *w = wm_of(hwnd);
      if (w != NULL) {
        w->preedit_active = 0;
        w->preedit_len = 0;
        w->preedit[0] = '\0';
        w->preedit_caret = 0;
      }
      return 0;
    }
    case WM_APP + 1:
      return 0; // wm_wakeup 的投递落点（仅 waker 窗口收）
    default:
      break;
  }
  return DefWindowProcW(hwnd, msg, wp, lp);
}

int wm_init(void) {
  // 幂等：批 A 的多窗宿主每开一扇都调一次后端初始化，而 Win32 的窗口类**同名
  // 重复注册会失败**（ERROR_CLASS_ALREADY_EXISTS）——第一次成功之后就整段复用。
  // 不这么做的话第二扇窗永远开不出（本机实测 App::open_window 返回 None，
  // GTK 分支的 gtk_init_check 本来就幂等所以只在 Windows 露出来）。
  if (wm_waker != NULL) {
    return 1;
  }
  HINSTANCE inst = GetModuleHandleW(NULL);
  WNDCLASSEXW wc;
  memset(&wc, 0, sizeof(wc));
  wc.cbSize = sizeof(wc);
  wc.style = CS_HREDRAW | CS_VREDRAW;
  wc.lpfnWndProc = wm_wndproc;
  wc.hInstance = inst;
  wc.hCursor = LoadCursorW(NULL, IDC_ARROW);
  wc.lpszClassName = L"yue_wm_window";
  if (RegisterClassExW(&wc) == 0 &&
      GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
    return 0;
  }
  WNDCLASSEXW wk = wc;
  wk.lpfnWndProc = DefWindowProcW;
  wk.lpszClassName = L"yue_wm_waker";
  if (RegisterClassExW(&wk) == 0 &&
      GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
    return 0;
  }
  // 原生子件面板类（平台批）：DefWindowProc 即可——它只是 WebView2 等原生
  // 引擎的承载矩形，自绘不走它。背景刷 NULL 免建窗到首帧之间的闪白。
  WNDCLASSEXW wsf;
  memset(&wsf, 0, sizeof(wsf));
  wsf.cbSize = sizeof(wsf);
  wsf.lpfnWndProc = DefWindowProcW;
  wsf.hInstance = inst;
  wsf.lpszClassName = L"yue_wm_surface";
  if (RegisterClassExW(&wsf) == 0 &&
      GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
    return 0;
  }
  wm_waker = CreateWindowExW(0, L"yue_wm_waker", L"", 0, 0, 0, 0, 0,
                             HWND_MESSAGE, NULL, inst, NULL);
  if (wm_waker == NULL) {
    return 0;
  }
  // 整栈自绘走物理像素：per-monitor v2；经 GetProcAddress 取，老系统缺导出
  // 不至于加载失败（降级系统 DPI 一档，行为由 WM_DPICHANGED 之外的路径兜）
  HMODULE user32 = GetModuleHandleW(L"user32.dll");
  if (user32 != NULL) {
    typedef BOOL(WINAPI * WmSetDpiCtx)(HANDLE);
    WmSetDpiCtx set_ctx =
        (WmSetDpiCtx)GetProcAddress(user32, "SetProcessDpiAwarenessContext");
    if (set_ctx != NULL) {
      set_ctx((HANDLE)(intptr_t)-4); // DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
    }
  }
  return 1;
}

int64_t wm_window_new(int width, int height, const char *title) {
  // 槽位复用（与 GTK 桩同一条修法）：多窗口宿主下附窗反复开合不能把 32 个槽
  // 吃光，否则 open_window 静默返回 None。判据取 hwnd——建窗成功必设、wm_close
  // 里 memset 清零，于是拆过的槽与没用过的槽同样可取。
  int id = 0;
  for (int i = 1; i < WM_MAX_WINDOWS; i++) {
    if (wm_windows[i].hwnd == NULL) {
      id = i;
      break;
    }
  }
  if (id == 0) {
    return 0;
  }
  if (id >= wm_next_id) {
    wm_next_id = id + 1;
  }
  WmWindow *w = &wm_windows[id];
  memset(w, 0, sizeof(*w));
  w->width = width > 1 ? width : 1;
  w->height = height > 1 ? height : 1;
  wchar_t wtitle[256];
  int tn = MultiByteToWideChar(CP_UTF8, 0, title ? title : "MoonBit", -1,
                               wtitle, 256);
  if (tn <= 0) {
    wtitle[0] = L'\0';
  }
  DWORD style = WS_OVERLAPPEDWINDOW;
  RECT r = {0, 0, w->width, w->height};
  // 客户区口径：外框撑到客户区恰为 width×height（GTK 的 default size 同语义）
  AdjustWindowRect(&r, style, FALSE);
  HWND hwnd = CreateWindowExW(0, L"yue_wm_window", wtitle, style, CW_USEDEFAULT,
                              CW_USEDEFAULT, r.right - r.left, r.bottom - r.top,
                              NULL, NULL, GetModuleHandleW(NULL),
                              (LPVOID)(intptr_t)id);
  if (hwnd == NULL) {
    memset(w, 0, sizeof(*w));
    return 0;
  }
  w->hwnd = hwnd;
  return (int64_t)id;
}

void wm_show(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->hwnd != NULL) {
    ShowWindow(w->hwnd, SW_SHOW);
    SetFocus(w->hwnd);
    // 与 GTK 桩同口径：把 map 后已就绪的消息跑掉，再标首帧
    wm_pump();
    w->need_draw = 1;
  }
}

void wm_size(int64_t id, int32_t *out_w, int32_t *out_h) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (out_w != NULL) {
    *out_w = w->width;
  }
  if (out_h != NULL) {
    *out_h = w->height;
  }
}

// 消费式取事件：1 = 需要重绘，2 = 尺寸变化（宽高已更新），3 = 请求关闭，
// 4 = 有输入事件待取（wm_take_event），0 = 没有待处理事件。
int wm_event(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  WmWindow *w = &wm_windows[id];
  if (w->ev_count > 0) {
    return 4;
  }
  if (w->closing) {
    w->closing = 0;
    return 3;
  }
  if (w->resized) {
    w->resized = 0;
    return 2;
  }
  if (w->need_draw) {
    w->need_draw = 0;
    return 1;
  }
  return 0;
}

// 焦点在谁身上（口径见 GTK 分支）。Windows 侧保守报 1 = 「焦点仍在绘制区」，
// 也就是维持本改动之前的行为（失焦只交还输入法、不清控件焦点栈）；
// 真正的判定（GetFocus 与绘制区 hwnd 比较、webview 子 HWND 算 2）随 W 线接。
int wm_focus_owner(int64_t id) {
  (void)id;
  return 1;
}

// 与 GTK 分支同一条修复：present 的像素必须拷进桩自己的缓冲——贴像素在
// 下一次 WM_PAINT 里，那之间 MoonBit 侧那块局部 Bitmap 可能已被 GC 回收。
void wm_present(int64_t id, const unsigned char *rgba, int width, int height) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->hwnd == NULL || rgba == NULL || width < 1 || height < 1) {
    return;
  }
  // 复制进桩持有的帧缓冲（理由见 WmWindow.frame 的注释），再请一次重画；
  // 真正的贴像素发生在下一次 WM_PAINT 里，那时窗口一定活着
  size_t need = (size_t)width * (size_t)height * 4;
  if (w->frame == NULL || (size_t)w->frame_cap < need) {
    unsigned char *nb = (unsigned char *)realloc(w->frame, need);
    if (nb == NULL) {
      return; // 分配失败就当这次没贴，下一帧再来
    }
    w->frame = nb;
    w->frame_cap = (int)need;
  }
  memcpy(w->frame, rgba, need);
  w->pending_w = width;
  w->pending_h = height;
  InvalidateRect(w->hwnd, NULL, FALSE);
}

void wm_close(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  // 归属本窗的原生子件槽一起清：子 HWND 随 DestroyWindow 的 Win32 父子关系
  // 自动销毁，槽位必须空出来，否则能力层拿着悬垂 HWND 继续用就是未定义
  for (int i = 1; i < WM_MAX_SURFACES; i++) {
    if (wm_surfaces[i].hwnd != NULL && wm_surfaces[i].window_id == id) {
      memset(&wm_surfaces[i], 0, sizeof(WmSurface));
    }
  }
  if (w->hwnd != NULL) {
    HWND hwnd = w->hwnd;
    w->hwnd = NULL; // WM_DESTROY 里还会再清一次；先摘钩防重入
    DestroyWindow(hwnd);
  }
  // 拆掉本次会话建的所有菜单（W20a）：HMENU 归桩所有，随窗口销毁一起放
  for (int i = 1; i < WM_MAX_MENUS; i++) {
    if (wm_menus[i] != NULL) {
      DestroyMenu(wm_menus[i]);
      wm_menus[i] = NULL;
    }
  }
  // 帧拷贝归桩所有，拆窗前先放掉（memset 之后就拿不到指针了）
  free(w->frame);
  w->frame = NULL;
  w->frame_cap = 0;
  memset(w, 0, sizeof(*w));
}

// 跑掉队列里已就绪的消息；不阻塞。WM_CHAR 不用（字符面在 WM_KEYDOWN 里
// 经 ToUnicode 直取 keysym），故不做 TranslateMessage。
void wm_pump(void) {
  MSG msg;
  while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
    // 全局快捷键（W20b）：RegisterHotKey(NULL,...) 的 WM_HOTKEY 投的是线程
    // 队列，msg.hwnd 为 NULL，DispatchMessageW 会把它丢掉——必须在派发前
    // 截住置位，等 MoonBit 侧 wm_hotkey_poll 来取。
    if (msg.message == WM_HOTKEY) {
      int hid = (int)msg.wParam;
      if (hid > 0 && hid < WM_MAX_HOTKEYS && wm_hotkeys[hid]) {
        if (!wm_hotkey_fired[hid]) {
          wm_hotkey_fired[hid] = 1;
          wm_hotkey_fired_count++;
        }
      }
      continue;
    }
    // TranslateMessage 不能省：INPUT 法（IMM32）的组合处理就挂在这条路上——
    // 缺了它只会收到裸键，WM_IME_STARTCOMPOSITION/WM_IME_COMPOSITION 一条都
    // 收不到（实测：只来 WM_IME_SETCONTEXT，拼音永远组合不起来）
    TranslateMessage(&msg);
    DispatchMessageW(&msg);
  }
}

// timeout_ms < 0 表示无限等（MoonBit 侧无待办时用），必须有人 wm_wakeup 或
// 消息到达才能回来；否则就是死锁，这是漏唤醒的代价。
int wm_wait(int timeout_ms) {
  DWORD t = timeout_ms < 0 ? INFINITE : (DWORD)timeout_ms;
  DWORD r = MsgWaitForMultipleObjectsEx(0, NULL, t, QS_ALLINPUT,
                                        MWMO_INPUTAVAILABLE);
  // 等完必须把排队消息派发掉（与 GTK 分支 poll 完调 wm_pump 同口径）：
  // 不派发就没人调 WndProc——输入、WM_CLOSE、WM_PAINT 全部收不到，真机表现
  // 是「窗口未响应、点了没反应」（实测：优雅关窗拖到自杀计时器才退出）
  wm_pump();
  return r == WAIT_OBJECT_0 ? 1 : 0;
}

// 取一个输入事件，返回其 code（0 键按下 1 键释放 2 按钮按下 3 按钮释放
// 4 指针移动 5 滚轮），无事件返回 -1。字段随后用 wm_ev_* 读这一条——
// 「取一条 + 逐字段读」而不是七个出参（MoonBit 不能给 C 传可写数组）。
int wm_take_event(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return -1;
  }
  WmWindow *w = &wm_windows[id];
  if (w->ev_count == 0) {
    return -1;
  }
  w->last = w->evs[w->ev_head];
  w->ev_head = (w->ev_head + 1) % 64;
  w->ev_count--;
  return (int)w->last.code;
}

int32_t wm_ev_keysym(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? (int32_t)wm_windows[id].last.keysym : 0;
}
int32_t wm_ev_mods(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? (int32_t)wm_windows[id].last.mods : 0;
}
int32_t wm_ev_x(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? wm_windows[id].last.x : 0;
}
int32_t wm_ev_y(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? wm_windows[id].last.y : 0;
}
int32_t wm_ev_button(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? wm_windows[id].last.dx : 0;
}
int32_t wm_ev_axis(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? wm_windows[id].last.dy : 0;
}

int wm_pending_events(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].ev_count;
}

void wm_request_focus(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->hwnd != NULL) {
    SetFocus(w->hwnd);
  }
}

// 设绘图区光标形状：0 默认箭头 / 1 手型 / 2 文本 I 形 / 3 横向调整 / 4 纵向调整。
// 存下形状并立即生效一次，后续移动由 WM_SETCURSOR 按形状接管。
void wm_set_cursor(int64_t id, int kind) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->cursor_kind == kind) {
    return;
  }
  w->cursor_kind = kind;
  if (w->hwnd != NULL) {
    SetCursor(wm_load_cursor(kind));
  }
}

/* ---- 窗口增强（W20e）-----------------------------------------------------
 * 自绘栈下窗口外壳要能被 MoonBit 改：运行中改标题、设窗口图标（走 W20f 的
 * HICON）、最小尺寸、自绘标题栏拖拽区、无边框开关。均为常规 Win32 消息，逐条
 * 可探针验（SendMessageW(WM_GETMINMAXINFO/WM_NCHITTEST) 直接反读）。 */

/* 运行中改标题（SetWindowTextW）。 */
void wm_set_title(int64_t id, const char *title) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->hwnd == NULL || title == NULL) {
    return;
  }
  WCHAR *wt = wm_utf8_to_wide(title);
  if (wt != NULL) {
    SetWindowTextW(w->hwnd, wt);
    free(wt);
  }
}

/* 设窗口图标。`which`：0 = 大图标（Alt+Tab）、1 = 小图标（标题栏），
 * 2 = 两者。`icon_slot` 是 W20f 的图标句柄（0 = 清空图标）。句柄表归调用方，
 * 窗口只是「用」这个 HICON——调用方须保证图标在窗口显示期间不被 free。 */
void wm_set_icon(int64_t id, int icon_slot, int which) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->hwnd == NULL) {
    return;
  }
  HICON ic = wm_icon_get(icon_slot);
  if (which == 0 || which == 2) {
    SendMessageW(w->hwnd, WM_SETICON, ICON_BIG, (LPARAM)ic);
  }
  if (which == 1 || which == 2) {
    SendMessageW(w->hwnd, WM_SETICON, ICON_SMALL, (LPARAM)ic);
  }
}

/* 设最小客户区尺寸（像素；0 = 该轴不限制）。WM_GETMINMAXINFO 按此拦。 */
void wm_set_min_size(int64_t id, int wmin, int hmin) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  wm_windows[id].min_w = wmin > 0 ? wmin : 0;
  wm_windows[id].min_h = hmin > 0 ? hmin : 0;
}

/* 设自绘标题栏拖拽区（客户区像素矩形；w/h<=0 清空）。命中交系统拖窗。 */
void wm_set_drag_rect(int64_t id, int x, int y, int w, int h) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *win = &wm_windows[id];
  win->drag_x = x;
  win->drag_y = y;
  win->drag_w = w > 0 ? w : 0;
  win->drag_h = h > 0 ? h : 0;
}

/* 无边框开关：ON 去掉标题栏/边框并换 WS_POPUP（自绘标题栏形态），OFF 还原
 * WS_OVERLAPPEDWINDOW。**保持客户区尺寸不变**——改样式后按当前客户区重算外框，
 * 再 SWP_FRAMECHANGED 让非客户区重算（否则窗口尺寸会跳）。 */
void wm_set_borderless(int64_t id, int on) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->hwnd == NULL || (w->borderless ? 1 : 0) == (on ? 1 : 0)) {
    return;
  }
  LONG_PTR style = GetWindowLongPtrW(w->hwnd, GWL_STYLE);
  if (on) {
    style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX |
               WS_SYSMENU | WS_BORDER | WS_DLGFRAME);
    style |= WS_POPUP | WS_MINIMIZEBOX; // 仍允许最小化
  } else {
    style &= ~WS_POPUP;
    style |= WS_OVERLAPPEDWINDOW;
  }
  RECT cr;
  GetClientRect(w->hwnd, &cr);
  RECT r = {0, 0, cr.right - cr.left, cr.bottom - cr.top};
  LONG_PTR ex = GetWindowLongPtrW(w->hwnd, GWL_EXSTYLE);
  AdjustWindowRectEx(&r, (DWORD)style, FALSE, (DWORD)ex);
  SetWindowLongPtrW(w->hwnd, GWL_STYLE, style);
  SetWindowPos(w->hwnd, NULL, 0, 0, r.right - r.left, r.bottom - r.top,
               SWP_NOMOVE | SWP_NOZORDER | SWP_FRAMECHANGED);
  w->borderless = on ? 1 : 0;
}

/* 反读：当前最小尺寸（探针/测试用）。 */
void wm_get_min_size(int64_t id, int32_t *out_w, int32_t *out_h) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  if (out_w != NULL) {
    *out_w = wm_windows[id].min_w;
  }
  if (out_h != NULL) {
    *out_h = wm_windows[id].min_h;
  }
}

/* 反读：当前拖拽区（探针/测试用）。 */
void wm_get_drag_rect(int64_t id, int32_t *x, int32_t *y, int32_t *w,
                      int32_t *h) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *win = &wm_windows[id];
  if (x != NULL) {
    *x = win->drag_x;
  }
  if (y != NULL) {
    *y = win->drag_y;
  }
  if (w != NULL) {
    *w = win->drag_w;
  }
  if (h != NULL) {
    *h = win->drag_h;
  }
}

/* 反读：无边框开关（探针/测试用）。 */
int wm_is_borderless(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? wm_windows[id].borderless : 0;
}

/* 反读：当前窗口标题写进调用方缓冲（UTF-8，返回字节数；读不到给 0）。 */
int wm_window_title(int64_t id, char *out, int cap) {
  if (id <= 0 || id >= WM_MAX_WINDOWS || out == NULL || cap <= 1) {
    return 0;
  }
  WmWindow *w = &wm_windows[id];
  if (w->hwnd == NULL) {
    return 0;
  }
  WCHAR wbuf[512];
  int n = GetWindowTextW(w->hwnd, wbuf, 512);
  if (n <= 0) {
    out[0] = '\0';
    return 0;
  }
  int got = WideCharToMultiByte(CP_UTF8, 0, wbuf, n, out, cap - 1, NULL, NULL);
  if (got < 0) {
    got = 0;
  }
  out[got] = '\0';
  return got;
}

/* ---- 系统托盘（W20c）-----------------------------------------------------
 * 托盘 = Shell 通知图标，形态是「一个 HWND + 一个 uID」。本侧自建隐藏消息窗
 * wm_tray_hwnd 承接回调：Shell_NotifyIconW 把鼠标消息投给该窗的
 * uCallbackMessage（WM_TRAY_CB），wParam=uID（= 本表槽号）、lParam=鼠标消息。
 * 与菜单/热键同制：C 不回调 MoonBit，命中压进程级队列，MoonBit 泵里
 * wm_tray_poll 抽。右键菜单复用 W20a 的 HMENU 句柄表（wm_menu_popup_new 建
 * 弹出菜单根），弹出走 wm_tray_popup：TrackPopupMenuEx 带 TPM_RETURNCMD，
 * 选中项直接拿到命令 id 压进 wm_menu_push——于是 yue/core 的菜单回调表照常
 * 生效，托盘菜单与窗口菜单共用同一套回调派发。
 * 图标句柄归 W20f 的表（wm_icon_get），本表只引用，不释放。 */

#define WM_MAX_TRAYS 8
#define WM_TRAY_CB (WM_APP + 2) // 托盘回调消息（waker 占 WM_APP+1）
// 托盘事件队列容量（环形；满了丢最旧）。事件编码 slot*4+kind。
// kind：0 = 左键单击、1 = 右键单击。
#define WM_TRAY_EV_MAX 32

typedef struct {
  int used;
  int kind;        // 0 = 托盘图标（收点击）；1 = 通知气泡（只弹、不收点击）
  HICON icon;      // 当前图标（引用 W20f 句柄表的 HICON，本侧不释放）
  HMENU menu;      // 右键菜单（wm_menus 表里的 HMENU，NULL = 无）
  WCHAR tip[128];  // tooltip（反读用）
  WCHAR ntitle[64];// 通知气泡标题（反读用；仅 kind 1）
} WmTray;

static WmTray wm_trays[WM_MAX_TRAYS]; // 槽 0 未用，句柄 = 槽号（1 起）
static HWND wm_tray_hwnd = NULL;
static int wm_tray_events[WM_TRAY_EV_MAX];
static int wm_tray_ev_head = 0;
static int wm_tray_ev_count = 0;

static void wm_tray_push(int slot, int kind) {
  if (wm_tray_ev_count >= WM_TRAY_EV_MAX) {
    wm_tray_ev_head = (wm_tray_ev_head + 1) % WM_TRAY_EV_MAX;
    wm_tray_ev_count--;
  }
  wm_tray_events[(wm_tray_ev_head + wm_tray_ev_count) % WM_TRAY_EV_MAX] =
      slot * 4 + kind;
  wm_tray_ev_count++;
}

static LRESULT CALLBACK wm_tray_wndproc(HWND hwnd, UINT msg, WPARAM wp,
                                        LPARAM lp) {
  if (msg == WM_TRAY_CB) {
    int slot = (int)wp;
    int m = (int)lp;
    // 通知槽（kind 1）不收点击：它的存在只为弹气泡，点击语义未定义
    if (slot > 0 && slot < WM_MAX_TRAYS && wm_trays[slot].used &&
        wm_trays[slot].kind == 0) {
      if (m == WM_LBUTTONUP || m == WM_LBUTTONDBLCLK) {
        wm_tray_push(slot, 0);
      } else if (m == WM_RBUTTONUP) {
        wm_tray_push(slot, 1);
      }
    }
    return 0;
  }
  if (msg == WM_COMMAND) {
    // 菜单命令（含 TrackPopupMenuEx 未用 TPM_RETURNCMD 时的回退路径）：
    // 转发进菜单队列，与窗口菜单同一条派发链。
    int cmd = (int)LOWORD(wp);
    if (cmd >= WM_MENU_CMD_BASE && cmd < WM_MENU_CMD_BASE + WM_MENU_CMD_MAX) {
      wm_menu_push(cmd);
    }
    return 0;
  }
  return DefWindowProcW(hwnd, msg, wp, lp);
}

/* 惰性建托盘消息窗 + 注册其窗口类（幂等；wm_init 之后调用）。 */
static int wm_tray_ensure(void) {
  if (wm_tray_hwnd != NULL) {
    return 1;
  }
  HINSTANCE inst = GetModuleHandleW(NULL);
  WNDCLASSEXW wc;
  memset(&wc, 0, sizeof(wc));
  wc.cbSize = sizeof(wc);
  wc.lpfnWndProc = wm_tray_wndproc;
  wc.hInstance = inst;
  wc.lpszClassName = L"yue_wm_tray";
  if (RegisterClassExW(&wc) == 0 &&
      GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
    return 0;
  }
  wm_tray_hwnd = CreateWindowExW(0, L"yue_wm_tray", L"", 0, 0, 0, 0, 0,
                                 HWND_MESSAGE, NULL, inst, NULL);
  return wm_tray_hwnd != NULL;
}

/* 托盘后端是否可用（Win32 上 Shell_NotifyIcon 恒在，实质是「消息窗建得出否」）。 */
int wm_tray_supported(void) { return wm_tray_ensure(); }

/* 内部：分配一个托盘槽并 NIM_ADD。kind 0 = 托盘图标（收点击）、1 = 通知气泡
 * （只弹气泡、不收点击，见 W21a）。返回槽号（>=1）或 0（表满/NIM_ADD 失败），
 * 失败不占槽。 */
static int wm_tray_alloc(int kind, int icon_slot, const char *tip) {
  if (!wm_tray_ensure()) {
    return 0;
  }
  int slot = -1;
  for (int i = 1; i < WM_MAX_TRAYS; i++) {
    if (!wm_trays[i].used) {
      slot = i;
      break;
    }
  }
  if (slot < 0) {
    return 0;
  }
  NOTIFYICONDATAW nid;
  memset(&nid, 0, sizeof(nid));
  nid.cbSize = sizeof(nid);
  nid.hWnd = wm_tray_hwnd;
  nid.uID = (UINT)slot;
  nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  nid.uCallbackMessage = WM_TRAY_CB;
  nid.hIcon = wm_icon_get(icon_slot);
  WCHAR *wtip = wm_utf8_to_wide(tip);
  if (wtip != NULL) {
    wcsncpy_s(nid.szTip, 128, wtip, _TRUNCATE);
    free(wtip);
  }
  if (!Shell_NotifyIconW(NIM_ADD, &nid)) {
    return 0;
  }
  wm_trays[slot].used = 1;
  wm_trays[slot].kind = kind;
  wm_trays[slot].icon = nid.hIcon;
  wm_trays[slot].menu = NULL;
  memcpy(wm_trays[slot].tip, nid.szTip, sizeof(nid.szTip));
  return slot;
}

/* 建托盘图标：icon_slot 是 W20f 的图标句柄（0 = 无图标），tip 为 UTF-8。 */
int wm_tray_new(int icon_slot, const char *tip) {
  return wm_tray_alloc(0, icon_slot, tip);
}

/* 改 tooltip（NIM_MODIFY）。 */
void wm_tray_set_tooltip(int slot, const char *tip) {
  if (slot <= 0 || slot >= WM_MAX_TRAYS || !wm_trays[slot].used ||
      wm_tray_hwnd == NULL) {
    return;
  }
  NOTIFYICONDATAW nid;
  memset(&nid, 0, sizeof(nid));
  nid.cbSize = sizeof(nid);
  nid.hWnd = wm_tray_hwnd;
  nid.uID = (UINT)slot;
  nid.uFlags = NIF_TIP;
  WCHAR *wtip = wm_utf8_to_wide(tip);
  if (wtip != NULL) {
    wcsncpy_s(nid.szTip, 128, wtip, _TRUNCATE);
    free(wtip);
  }
  if (Shell_NotifyIconW(NIM_MODIFY, &nid)) {
    memcpy(wm_trays[slot].tip, nid.szTip, sizeof(nid.szTip));
  }
}

/* 换图标（NIM_MODIFY；icon_slot 是 W20f 句柄，0 = 清空图标）。 */
void wm_tray_set_icon(int slot, int icon_slot) {
  if (slot <= 0 || slot >= WM_MAX_TRAYS || !wm_trays[slot].used ||
      wm_tray_hwnd == NULL) {
    return;
  }
  HICON ic = wm_icon_get(icon_slot);
  NOTIFYICONDATAW nid;
  memset(&nid, 0, sizeof(nid));
  nid.cbSize = sizeof(nid);
  nid.hWnd = wm_tray_hwnd;
  nid.uID = (UINT)slot;
  nid.uFlags = NIF_ICON;
  nid.hIcon = ic;
  if (Shell_NotifyIconW(NIM_MODIFY, &nid)) {
    wm_trays[slot].icon = ic;
  }
}

/* 挂右键菜单：menu_handle 是 W20a 句柄表下标（wm_menu_popup_new 建的弹出根）。 */
void wm_tray_set_menu(int slot, int menu_handle) {
  if (slot <= 0 || slot >= WM_MAX_TRAYS || !wm_trays[slot].used) {
    return;
  }
  HMENU m = NULL;
  if (menu_handle > 0 && menu_handle < WM_MAX_MENUS) {
    m = wm_menus[menu_handle];
  }
  wm_trays[slot].menu = m;
}

/* 在光标处弹出右键菜单（TrackPopupMenuEx 阻塞到选中/取消）。选中项的命令 id
 * 压进 wm_menu_push 并返回 1；取消/无菜单返回 0。 */
int wm_tray_popup(int slot) {
  if (slot <= 0 || slot >= WM_MAX_TRAYS || !wm_trays[slot].used ||
      wm_tray_hwnd == NULL) {
    return 0;
  }
  HMENU m = wm_trays[slot].menu;
  if (m == NULL) {
    return 0;
  }
  POINT p;
  GetCursorPos(&p);
  // 微软约定：弹菜单前把 owner 设前台，弹完 PostMessage(WM_NULL) 收尾，
  // 否则菜单可能不消失（焦点不还给别的窗口）。
  SetForegroundWindow(wm_tray_hwnd);
  int cmd = (int)TrackPopupMenuEx(
      m, TPM_RIGHTBUTTON | TPM_RETURNCMD | TPM_NONOTIFY, p.x, p.y,
      wm_tray_hwnd, NULL);
  PostMessageW(wm_tray_hwnd, WM_NULL, 0, 0);
  if (cmd >= WM_MENU_CMD_BASE && cmd < WM_MENU_CMD_BASE + WM_MENU_CMD_MAX) {
    wm_menu_push(cmd);
    return 1;
  }
  return 0;
}

/* 移除托盘图标（NIM_DELETE，幂等）。 */
void wm_tray_remove(int slot) {
  if (slot <= 0 || slot >= WM_MAX_TRAYS || !wm_trays[slot].used) {
    return;
  }
  if (wm_tray_hwnd != NULL) {
    NOTIFYICONDATAW nid;
    memset(&nid, 0, sizeof(nid));
    nid.cbSize = sizeof(nid);
    nid.hWnd = wm_tray_hwnd;
    nid.uID = (UINT)slot;
    Shell_NotifyIconW(NIM_DELETE, &nid);
  }
  wm_trays[slot].used = 0;
  wm_trays[slot].icon = NULL;
  wm_trays[slot].menu = NULL;
  wm_trays[slot].tip[0] = L'\0';
}

/* 取一个待处理托盘事件：out_slot 收槽号、out_kind 收 0 左键 / 1 右键，
 * 返回 1 = 取到、0 = 队列空。宿主每拍调一次。 */
int wm_tray_poll(int32_t *out_slot, int32_t *out_kind) {
  if (wm_tray_ev_count <= 0) {
    return 0;
  }
  int ev = wm_tray_events[wm_tray_ev_head];
  wm_tray_ev_head = (wm_tray_ev_head + 1) % WM_TRAY_EV_MAX;
  wm_tray_ev_count--;
  if (out_slot != NULL) {
    *out_slot = ev / 4;
  }
  if (out_kind != NULL) {
    *out_kind = ev % 4;
  }
  return 1;
}

/* 反读：在用**托盘图标**槽数（通知槽不计，探针/测试用）。 */
int wm_tray_count(void) {
  int n = 0;
  for (int i = 1; i < WM_MAX_TRAYS; i++) {
    if (wm_trays[i].used && wm_trays[i].kind == 0) {
      n++;
    }
  }
  return n;
}

/* 反读：在用**通知气泡**槽数（探针/测试用）。 */
int wm_notify_count(void) {
  int n = 0;
  for (int i = 1; i < WM_MAX_TRAYS; i++) {
    if (wm_trays[i].used && wm_trays[i].kind == 1) {
      n++;
    }
  }
  return n;
}

/* 反读：托盘 tooltip 写进调用方缓冲（UTF-8，返回字节数）。 */
int wm_tray_tooltip(int slot, char *out, int cap) {
  if (slot <= 0 || slot >= WM_MAX_TRAYS || !wm_trays[slot].used ||
      out == NULL || cap <= 1) {
    return 0;
  }
  int n = WideCharToMultiByte(CP_UTF8, 0, wm_trays[slot].tip, -1, out, cap - 1,
                              NULL, NULL);
  if (n <= 0) {
    out[0] = '\0';
    return 0;
  }
  out[n] = '\0';
  return n - 1; // 不计结尾 NUL
}

/* ---- 桌面通知（W21a）Win32 后端：托盘气泡（NIF_INFO）---------------------
 * Windows 的「通知」挂在托盘图标上：先 NIM_ADD 建托盘项，再 NIM_MODIFY 带
 * NIF_INFO 与 szInfoTitle / szInfo 弹气泡（Vista 起这些气泡被系统转成 toast）。
 * 因此本段复用 W20c 的托盘槽表与消息窗，用 `kind == 1` 的槽区分「通知气泡」
 * （只弹、不收点击；点击语义未定义，wm_tray_wndproc 对 kind 1 不入队）。
 *
 * 两条平台差异（写进文档、不假装对齐）：
 *  - `uTimeout` 自 Vista 起被系统忽略：气泡时长由系统（辅助功能设置）定，故
 *    `timeout_ms` 只用于与 Linux 侧同签名，本侧不生效。
 *  - 没有「进度 hint」：Linux 的 `value` hint 传百分比，桌面端画进度条；Win32
 *    气泡无对应物，`progress` 由门面把百分比拼进正文（可见降级，不静默丢弃）。
 *
 * 关闭：Windows 没有「撤下气泡」的独立 API；官方约定的收起形态是再发一次
 * `NIF_INFO` 且 `szInfo` 置空——本侧先这么收，再 NIM_DELETE 摘掉托盘项。 */

/* 通知后端是否可用（同托盘：能建出消息窗即可）。 */
int wm_notify_supported(void) { return wm_tray_ensure(); }

/* 前置声明：wm_notify_send 在建项后要立刻用更新去填气泡（定义在其后）。 */
int wm_notify_update(int slot, const char *title, const char *text, int kind);

/* 弹一张气泡通知：icon_slot 是 W20f 图标句柄（0 = 用状态图标），kind 0/1/2
 * = 信息/警告/错误。返回通知 id（>=1，即所属托盘槽号）或 0（表满/失败）。 */
int wm_notify_send(int icon_slot, const char *title, const char *text,
                   int kind) {
  int slot = wm_tray_alloc(1, icon_slot, "");
  if (slot <= 0) {
    return 0;
  }
  if (!wm_notify_update(slot, title, text, kind)) {
    wm_tray_remove(slot); // 弹不出就还槽，别占着
    return 0;
  }
  return slot;
}

/* 更新（或替换）一张气泡通知：同一槽再发 NIF_INFO，系统即替换原气泡。 */
int wm_notify_update(int slot, const char *title, const char *text, int kind) {
  if (slot <= 0 || slot >= WM_MAX_TRAYS || !wm_trays[slot].used ||
      wm_trays[slot].kind != 1 || wm_tray_hwnd == NULL) {
    return 0;
  }
  NOTIFYICONDATAW nid;
  memset(&nid, 0, sizeof(nid));
  nid.cbSize = sizeof(nid);
  nid.hWnd = wm_tray_hwnd;
  nid.uID = (UINT)slot;
  nid.uFlags = NIF_INFO;
  nid.dwInfoFlags = kind == 2 ? NIIF_ERROR : (kind == 1 ? NIIF_WARNING : NIIF_INFO);
  WCHAR *wt = wm_utf8_to_wide(title);
  if (wt != NULL) {
    wcsncpy_s(nid.szInfoTitle, 64, wt, _TRUNCATE);
    free(wt);
  }
  WCHAR *wtxt = wm_utf8_to_wide(text);
  if (wtxt != NULL) {
    wcsncpy_s(nid.szInfo, 256, wtxt, _TRUNCATE);
    free(wtxt);
  }
  if (!Shell_NotifyIconW(NIM_MODIFY, &nid)) {
    return 0;
  }
  memcpy(wm_trays[slot].ntitle, nid.szInfoTitle, sizeof(nid.szInfoTitle));
  return 1;
}

/* 收起气泡并摘掉该通知的托盘项（幂等）。 */
void wm_notify_close(int slot) {
  if (slot <= 0 || slot >= WM_MAX_TRAYS || !wm_trays[slot].used ||
      wm_trays[slot].kind != 1) {
    return;
  }
  if (wm_tray_hwnd != NULL) {
    // 官方收气泡形态：NIF_INFO + 空 szInfo（没有独立的 dismiss API）
    NOTIFYICONDATAW nid;
    memset(&nid, 0, sizeof(nid));
    nid.cbSize = sizeof(nid);
    nid.hWnd = wm_tray_hwnd;
    nid.uID = (UINT)slot;
    nid.uFlags = NIF_INFO;
    nid.szInfo[0] = L'\0';
    nid.szInfoTitle[0] = L'\0';
    Shell_NotifyIconW(NIM_MODIFY, &nid);
  }
  wm_tray_remove(slot);
}

/* 反读：某通知槽当前的气泡标题（UTF-8，返回字节数；0 = 读不到）。 */
int wm_notify_title(int slot, char *out, int cap) {
  if (slot <= 0 || slot >= WM_MAX_TRAYS || !wm_trays[slot].used ||
      wm_trays[slot].kind != 1 || out == NULL || cap <= 1) {
    return 0;
  }
  int n = WideCharToMultiByte(CP_UTF8, 0, wm_trays[slot].ntitle, -1, out,
                              cap - 1, NULL, NULL);
  if (n <= 0) {
    out[0] = '\0';
    return 0;
  }
  out[n] = '\0';
  return n - 1;
}

/* ---- 任务栏进度（§6.3 接缝项：任务栏进度 / dock 徽标）-----------------------
 * ITaskbarList3 的 SetProgressValue / SetProgressState：任务栏按钮上的进度条
 * 与四种状态（无进度 / 正常 / 错误 / 暂停 / 不确定）。COM 实例进程级单例——
 * 接口本身与窗口无关，目标窗口按 hwnd 区分（句柄从窗口槽拿，与其它 wm_* 同口径
 * 的越界检查：id 越界或窗口未建给 0，不崩不写）。
 * 两条口径：① Win32 无 getter，TBPF_* 状态**不可反读**（与 notify 的 kind→NIIF_*
 * 映射同款），所以只给写入口；探测只报「COM 起没起来」。② GUID 常量
 * （CLSID_TaskbarList / IID_ITaskbarList3）走 uuid.lib 链接期取符号——C 模式
 * 用不了 __uuidof（同 W14 文件对话框、W20f 图标加载两条坑）。
 * Linux 的任务栏进度另有 Unity LauncherEntry（DBus）路径，归跨平台门面批；
 * 本段只管 Windows，其余平台走同族占位（supported 恒 0）。 */
static ITaskbarList3 *wm_taskbar = NULL; // 进程级单例
static int wm_taskbar_tried = 0;         // 探测过一次就不再重试

static int wm_taskbar_ensure(void) {
  if (wm_taskbar != NULL) {
    return 1;
  }
  if (wm_taskbar_tried) {
    return 0;
  }
  wm_taskbar_tried = 1;
  // 已被别的模式初始化过（RPC_E_CHANGED_MODE）不算失败：退回默认再试一次。
  // S_FALSE（本线程已初始化过）同样当成功——进程级单例，反复 CoInitialize
  // 没有副作用，退出时不 Uninitialize（COM 对象随进程收尾）。
  HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
  if (hr == RPC_E_CHANGED_MODE) {
    hr = CoInitialize(NULL);
  }
  if (FAILED(hr)) {
    return 0;
  }
  ITaskbarList3 *ptl = NULL;
  hr = CoCreateInstance(&CLSID_TaskbarList, NULL, CLSCTX_INPROC_SERVER,
                        &IID_ITaskbarList3, (void **)&ptl);
  if (FAILED(hr) || ptl == NULL) {
    return 0;
  }
  if (FAILED(ptl->lpVtbl->HrInit(ptl))) {
    ptl->lpVtbl->Release(ptl);
    return 0;
  }
  wm_taskbar = ptl;
  return 1;
}

int wm_taskbar_supported(void) { return wm_taskbar_ensure(); }

int wm_taskbar_set_progress(int64_t id, int64_t value, int64_t total) {
  if (!wm_taskbar_ensure()) {
    return 0;
  }
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  HWND h = wm_windows[id].hwnd;
  if (h == NULL) {
    return 0;
  }
  return SUCCEEDED(wm_taskbar->lpVtbl->SetProgressValue(
             wm_taskbar, h, (ULONGLONG)value, (ULONGLONG)total))
             ? 1
             : 0;
}

int wm_taskbar_set_state(int64_t id, int state) {
  if (!wm_taskbar_ensure()) {
    return 0;
  }
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  HWND h = wm_windows[id].hwnd;
  if (h == NULL) {
    return 0;
  }
  TBPFLAG flag;
  switch (state) {
    case 0:
      flag = TBPF_NOPROGRESS;
      break;
    case 1:
      flag = TBPF_NORMAL;
      break;
    case 2:
      flag = TBPF_ERROR;
      break;
    case 3:
      flag = TBPF_PAUSED;
      break;
    case 4:
      flag = TBPF_INDETERMINATE;
      break;
    default:
      return 0;
  }
  return SUCCEEDED(
             wm_taskbar->lpVtbl->SetProgressState(wm_taskbar, h, flag))
             ? 1
             : 0;
}

// ---- IME（W6 线实装 ImmAssociateContext / WM_IME_*，当前为占位：缓冲恒空，
// MoonBit 侧 pump_ime 读到空即无 preedit/commit，行为与非 Linux 占位一致）----

// legacy IMM32 没有 surrounding-text 接口（那是 TSF 的），这条空操作：
// Windows 的 IME 从自身组合状态取上下文；GTK 侧喂已提交文本是为了让
// IM context 推断上下文，两平台语义在此分叉（记档）。
void wm_im_set_surrounding(int64_t id, const char *text, int caret) {
  (void)id;
  (void)text;
  (void)caret;
}

void wm_im_set_cursor(int64_t id, int x, int y, int w, int h) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *wm = &wm_windows[id];
  if (wm->hwnd == NULL) {
    return;
  }
  wm->im_cx = x;
  wm->im_cy = y;
  wm->im_cw = w;
  wm->im_ch = h;
  wm->im_cursor_set = 1;
  wm_im_apply_cursor(wm);
}

// 逻辑焦点切换时清输入法侧未完成的组合串：不清的话前一个框攒下的拼音会在
// 后一个框拿到焦点后 commit 进去（GTK 侧同一条教训）；本侧缓存一并清。
void wm_im_reset(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *wm = &wm_windows[id];
  if (wm->hwnd != NULL) {
    HIMC himc = ImmGetContext(wm->hwnd);
    if (himc != NULL) {
      ImmNotifyIME(himc, NI_COMPOSITIONSTR, CPS_CANCEL, 0);
      ImmReleaseContext(wm->hwnd, himc);
    }
  }
  wm->preedit_active = 0;
  wm->preedit_len = 0;
  wm->preedit[0] = '\0';
  wm->preedit_caret = 0;
}

// 取一条已提交文本：返回字节数并把内容留在原处供逐字节读，
// 读完必须调 wm_im_commit_done 清零
int wm_im_commit_len(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].commit_len;
}
int wm_im_commit_byte(int64_t id, int index) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  WmWindow *w = &wm_windows[id];
  if (index < 0 || index >= w->commit_len) {
    return 0;
  }
  return (int)(unsigned char)w->commit[index];
}
void wm_im_commit_done(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  wm_windows[id].commit_len = 0;
  wm_windows[id].commit[0] = '\0';
}
// preedit（组合串）状态：仅供自绘显示，绝不计入文本状态
int wm_im_preedit_len(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].preedit_len;
}
int wm_im_preedit_byte(int64_t id, int index) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  WmWindow *w = &wm_windows[id];
  if (index < 0 || index >= w->preedit_len) {
    return 0;
  }
  return (int)(unsigned char)w->preedit[index];
}
int wm_im_preedit_caret(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].preedit_caret;
}
int wm_im_preedit_active(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].preedit_active;
}

void wm_wakeup(void) {
  if (wm_waker != NULL) {
    PostMessageW(wm_waker, WM_APP + 1, 0, 0);
  }
}

/* ---- 全局快捷键（W20b）实装在下方：表声明在文件头（pump 要用），这里只放
 * 注册/注销/抽取三个入口。 */
/* 注册全局快捷键：mods 用内核 MOD_* 位（1 shift/2 ctrl/4 alt/8 meta），
 * vk 是 Win32 虚拟键码。返回 id（>=1）或 0 失败（组合键被系统/别的程序占用、
 * 或表满）。RegisterHotKey 用 NULL hwnd = 线程队列。 */
int wm_hotkey_register(int mods, int vk) {
  int slot = -1;
  for (int i = 1; i < WM_MAX_HOTKEYS; i++) {
    if (!wm_hotkeys[i]) {
      slot = i;
      break;
    }
  }
  if (slot < 0) {
    return 0;
  }
  UINT m = 0;
  if (mods & 1) {
    m |= MOD_SHIFT;
  }
  if (mods & 2) {
    m |= MOD_CONTROL;
  }
  if (mods & 4) {
    m |= MOD_ALT;
  }
  if (mods & 8) {
    m |= MOD_WIN;
  }
  // 无修饰键的裸键 RegisterHotKey 会失败（系统拒绝），显式判掉给调用方
  if (m == 0) {
    return 0;
  }
  if (!RegisterHotKey(NULL, slot, m | MOD_NOREPEAT, (UINT)vk)) {
    return 0;
  }
  wm_hotkeys[slot] = 1;
  wm_hotkey_fired[slot] = 0;
  return slot;
}

/* 注销：幂等。 */
void wm_hotkey_unregister(int id) {
  if (id <= 0 || id >= WM_MAX_HOTKEYS || !wm_hotkeys[id]) {
    return;
  }
  UnregisterHotKey(NULL, id);
  wm_hotkeys[id] = 0;
  wm_hotkey_fired[id] = 0;
}

/* 取一个已触发的热键 id（无则 0）。每注册一个 WM_HOTKEY 只置位一次。 */
int wm_hotkey_poll(void) {
  if (wm_hotkey_fired_count < 1) {
    return 0;
  }
  for (int i = 1; i < WM_MAX_HOTKEYS; i++) {
    if (wm_hotkey_fired[i]) {
      wm_hotkey_fired[i] = 0;
      wm_hotkey_fired_count--;
      return i;
    }
  }
  return 0;
}

/* UTF-8 → UTF-16（W 系 API 用）；失败/空给 NULL，调用方自己兜空白串。 */
static WCHAR *wm_utf8_to_wide(const char *s) {
  if (s == NULL) {
    return NULL;
  }
  int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
  if (n <= 0) {
    return NULL;
  }
  WCHAR *w = (WCHAR *)malloc((size_t)n * sizeof(WCHAR));
  if (w == NULL) {
    return NULL;
  }
  MultiByteToWideChar(CP_UTF8, 0, s, -1, w, n);
  return w;
}

/* ---- 原生菜单（W20a）实装 -------------------------------------------------
 * 逐节点 FFI：MoonBit 侧持「菜单句柄」（本表下标），按模型树自顶向下建。
 *  - wm_menu_bar_new()            建菜单条 → 返回句柄
 *  - wm_menu_new_sub(parent,title) 在 parent 下加子菜单 → 返回子菜单句柄
 *  - wm_menu_add_item(parent,label,kind,role,acc,checked) 加项 → 返回命令 id（0=分隔线）
 * 命令 id 由本侧递增分配、回填给 MoonBit（模型侧 MenuItem.native_id）；点击经
 * WM_COMMAND → 队列 → wm_menu_poll 取回，MoonBit 用 native_id 找回调。
 * 挂窗用 wm_menu_apply(window_id, menu_handle)。 */
int wm_menu_bar_new(void) {
  int slot = -1;
  for (int i = 1; i < WM_MAX_MENUS; i++) {
    if (wm_menus[i] == NULL) {
      slot = i;
      break;
    }
  }
  if (slot < 0) {
    return 0;
  }
  HMENU h = CreateMenu();
  if (h == NULL) {
    return 0;
  }
  wm_menus[slot] = h;
  return slot;
}

/* 建一个弹出菜单根（W20c 托盘右键菜单用；与菜单条同表、同句柄口径）。
 * 与 wm_menu_bar_new 的唯一差别是 CreatePopupMenu 而非 CreateMenu。 */
int wm_menu_popup_new(void) {
  int slot = -1;
  for (int i = 1; i < WM_MAX_MENUS; i++) {
    if (wm_menus[i] == NULL) {
      slot = i;
      break;
    }
  }
  if (slot < 0) {
    return 0;
  }
  HMENU h = CreatePopupMenu();
  if (h == NULL) {
    return 0;
  }
  wm_menus[slot] = h;
  return slot;
}

/* 在父菜单下加子菜单；返回子菜单句柄（0=失败）。 */
int wm_menu_new_sub(int parent, const char *title) {
  if (parent <= 0 || parent >= WM_MAX_MENUS || wm_menus[parent] == NULL) {
    return 0;
  }
  int slot = -1;
  for (int i = 1; i < WM_MAX_MENUS; i++) {
    if (wm_menus[i] == NULL) {
      slot = i;
      break;
    }
  }
  if (slot < 0) {
    return 0;
  }
  HMENU sub = CreatePopupMenu();
  if (sub == NULL) {
    return 0;
  }
  WCHAR *w = wm_utf8_to_wide(title);
  UINT f = MF_POPUP | MF_STRING;
  if (!AppendMenuW(wm_menus[parent], f, (UINT_PTR)sub,
                   w != NULL ? w : L"")) {
    DestroyMenu(sub);
    free(w);
    return 0;
  }
  free(w);
  wm_menus[slot] = sub;
  return slot;
}

/* 在父菜单下加一项。kind: 0 command / 1 check / 2 radio / 3 separator。
 * role: -1 non-role（Win32 无 role，忽略）；acc 是加速键描述串（"" 或无）。
 * checked: check/radio 初值。返回命令 id（>=1000）；分隔线返回 0。 */
int wm_menu_add_item(int parent, const char *label, int kind, int role,
                     const char *acc, int checked) {
  if (parent <= 0 || parent >= WM_MAX_MENUS || wm_menus[parent] == NULL) {
    return 0;
  }
  (void)role; // Win32 无 role 概念：角色项按普通项建，行为由 MoonBit 回调给
  if (kind == 3) {
    AppendMenuW(wm_menus[parent], MF_SEPARATOR, 0, NULL);
    return 0;
  }
  // 先算出待分配的 id，但**成功挂上后才推进游标**：AppendMenuW 有单菜单项数
  // 上限（实测本机 ~1168，见 menu_backend_probe.c），失败还吃 id 会让配额提前
  // 耗尽并与其他菜单的在用 id 相撞。
  int cmd = wm_menu_cmd_next;
  UINT f = MF_STRING;
  if (kind == 1) { // check
    if (checked) {
      f |= MF_CHECKED;
    }
  } else if (kind == 2) { // radio
    if (checked) {
      f |= MF_CHECKED;
    }
  }
  // 标签 + 可选「\t加速键提示」：AppendMenuW 把 '\t' 后的部分右对齐显示
  WCHAR item_label[256];
  item_label[0] = L'\0';
  WCHAR *w = wm_utf8_to_wide(label);
  if (w != NULL) {
    wcsncpy(item_label, w, 200);
    item_label[200] = L'\0';
    free(w);
  }
  if (acc != NULL && acc[0] != '\0' && item_label[0] != L'\0') {
    // 直接当提示串（Win32 上真正生效的加速键表将来另行 RegisterAccelerator）
    size_t cur = wcslen(item_label);
    if (cur < 240) {
      item_label[cur] = L'\t';
      item_label[cur + 1] = L'\0';
      WCHAR *wa = wm_utf8_to_wide(acc);
      if (wa != NULL) {
        wcsncat(item_label, wa, 240 - (int)cur - 1);
        free(wa);
      }
    }
  }
  if (!AppendMenuW(wm_menus[parent], f, (UINT_PTR)cmd, item_label)) {
    return 0;
  }
  // 挂载成功，推进 id 游标；到池尾归位到 BASE（池大小 2048 > 单菜单上限，
  // 故单个菜单不可能自相撞 id）。
  wm_menu_cmd_next = cmd + 1;
  if (wm_menu_cmd_next >= WM_MENU_CMD_BASE + WM_MENU_CMD_MAX) {
    wm_menu_cmd_next = WM_MENU_CMD_BASE;
  }
  return cmd;
}

/* 把菜单条挂到窗口（SetMenu + DrawMenuBar）；bar=0 表示拆掉当前菜单。 */
void wm_menu_apply(int64_t id, int bar) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->hwnd == NULL) {
    return;
  }
  HMENU h = (bar > 0 && bar < WM_MAX_MENUS) ? wm_menus[bar] : NULL;
  SetMenu(w->hwnd, h);
  DrawMenuBar(w->hwnd);
}

/* 抽一个菜单命令 id（无则 0）。入队在 WM_COMMAND 里做。 */
int wm_menu_poll(void) {
  if (wm_menu_fired_count < 1) {
    return 0;
  }
  int cmd = wm_menu_fired[wm_menu_fired_head];
  wm_menu_fired_head = (wm_menu_fired_head + 1) % 64;
  wm_menu_fired_count--;
  return cmd;
}

/* ---- 图标加载（W20f）-----------------------------------------------------
 * 托盘 / 窗口 / 菜单三处的共同前置：把「磁盘图标文件」或「已在内存的像素」变成
 * 一个 HICON。三种入口覆盖三来源：
 *  - wm_icon_load_file(path, size) —— 按扩展名分派：`.ico`/`.bmp` 走
 *    `LoadImageW(LR_LOADFROMFILE)`（Win32 原生图标格式，不必解码），其余
 *    （PNG/JPEG/GIF…）读文件字节走 WIC；size>0 按该边长加载。
 *  - wm_icon_from_png(bytes, len) —— WIC 从**内存**解码 PNG/JPEG/GIF/BMP 到
 *    32bpp BGRA（PNG 没有原生 Win32 入口，只能走 WIC）。
 *  - wm_icon_from_bgra(px, w, h) —— 已是 BGRA（预乘）的像素直接建 icon；`yue/render`
 *    的 Bitmap 正是这个口径（小端 B,G,R,A 预乘），CreateIconIndirect 需要预乘
 *    alpha，两者天然对齐、逐字节直拷。
 * 句柄用进程级表下标（1 起，0 = 失败），与窗口/菜单同制；wm_icon_free 释放
 * HICON 与自建的位图，未释放的随进程退出由系统回收。
 * 表要在 wm_wndproc（WM_SETICON 用）/托盘批之前声明。 */
#define WM_MAX_ICONS 32
typedef struct {
  HICON hicon;
  HBITMAP color; // 自建的 32bpp 位图（LoadImageW 路径为 NULL，由 HICON 自持）
  HBITMAP mask;
} WmIcon;
static WmIcon wm_icons[WM_MAX_ICONS];

/* 前置声明：wm_icon_load_file 的 WIC 回退路径要调它（定义在其后）。 */
int wm_icon_from_png(const unsigned char *data, int len);

static int wm_icon_slot(void) {
  for (int i = 1; i < WM_MAX_ICONS; i++) {
    if (wm_icons[i].hicon == NULL) {
      return i;
    }
  }
  return 0;
}

/* 取槽里的真 HICON（越界/空槽给 NULL）。窗口增强（W20e）的 set_icon 也走它。 */
static HICON wm_icon_get(int slot) {
  if (slot <= 0 || slot >= WM_MAX_ICONS) {
    return NULL;
  }
  return wm_icons[slot].hicon;
}

static int wm_icon_store(HICON ic, HBITMAP color, HBITMAP mask) {
  if (ic == NULL) {
    return 0;
  }
  int slot = wm_icon_slot();
  if (slot == 0) {
    return 0; // 表满：不销毁，交调用方决定（此处调用方会自清）
  }
  wm_icons[slot].hicon = ic;
  wm_icons[slot].color = color;
  wm_icons[slot].mask = mask;
  return slot;
}

/* 32bpp BGRA（自顶向下）→ HICON。mask 用全 0 单色位图；CreateIconIndirect 在
 * 32bpp 颜色位图上认 alpha 通道做混合，故像素必须是**预乘** alpha（与 Bitmap 同）。 */
int wm_icon_from_bgra(const unsigned char *px, int w, int h) {
  if (px == NULL || w <= 0 || h <= 0) {
    return 0;
  }
  BITMAPV5HEADER bi;
  memset(&bi, 0, sizeof(bi));
  bi.bV5Size = sizeof(bi);
  bi.bV5Width = w;
  bi.bV5Height = -h; // 负高 = 自顶向下，与 Bitmap 行序一致
  bi.bV5Planes = 1;
  bi.bV5BitCount = 32;
  bi.bV5Compression = BI_BITFIELDS;
  bi.bV5RedMask = 0x00FF0000u;
  bi.bV5GreenMask = 0x0000FF00u;
  bi.bV5BlueMask = 0x000000FFu;
  bi.bV5AlphaMask = 0xFF000000u;
  HDC hdc = GetDC(NULL);
  void *bits = NULL;
  HBITMAP color =
      CreateDIBSection(hdc, (BITMAPINFO *)&bi, DIB_RGB_COLORS, &bits, NULL, 0);
  ReleaseDC(NULL, hdc);
  if (color == NULL || bits == NULL) {
    if (color != NULL) {
      DeleteObject(color);
    }
    return 0;
  }
  memcpy(bits, px, (size_t)w * (size_t)h * 4u);
  HBITMAP mask = CreateBitmap(w, h, 1, 1, NULL);
  ICONINFO ii;
  memset(&ii, 0, sizeof(ii));
  ii.fIcon = TRUE;
  ii.hbmColor = color;
  ii.hbmMask = mask;
  HICON ic = CreateIconIndirect(&ii);
  if (ic == NULL) {
    DeleteObject(color);
    if (mask != NULL) {
      DeleteObject(mask);
    }
    return 0;
  }
  int slot = wm_icon_store(ic, color, mask);
  if (slot == 0) {
    DestroyIcon(ic);
    DeleteObject(color);
    if (mask != NULL) {
      DeleteObject(mask);
    }
  }
  return slot;
}

/* 把整个文件读进 malloc 缓冲（returned 长度经 out_len）。读不到给 NULL。 */
static unsigned char *wm_read_file_all(const char *path, int *out_len) {
  FILE *f = fopen(path, "rb");
  if (f == NULL) {
    return NULL;
  }
  if (fseek(f, 0, SEEK_END) != 0) {
    fclose(f);
    return NULL;
  }
  long n = ftell(f);
  if (n <= 0 || n > (long)(64 * 1024 * 1024)) { // 64MB 上限防呆
    fclose(f);
    return NULL;
  }
  rewind(f);
  unsigned char *buf = (unsigned char *)malloc((size_t)n);
  if (buf == NULL) {
    fclose(f);
    return NULL;
  }
  size_t got = fread(buf, 1, (size_t)n, f);
  fclose(f);
  if (got != (size_t)n) {
    free(buf);
    return NULL;
  }
  *out_len = (int)n;
  return buf;
}

/* 路径扩展名是否为 ico/bmp（Win32 原生可加载的图标格式）。 */
static int wm_path_is_native_icon(const char *path) {
  const char *dot = strrchr(path, '.');
  if (dot == NULL) {
    return 0;
  }
  char ext[8];
  size_t n = strlen(dot + 1);
  if (n >= sizeof(ext)) {
    return 0;
  }
  for (size_t i = 0; i < n; i++) {
    char c = dot[1 + i];
    if (c >= 'A' && c <= 'Z') {
      c = (char)(c - 'A' + 'a');
    }
    ext[i] = c;
  }
  ext[n] = '\0';
  return strcmp(ext, "ico") == 0 || strcmp(ext, "bmp") == 0;
}

/* 磁盘图标：`.ico`/`.bmp` 走 LoadImageW（原生、最准）；其余（PNG/JPEG/GIF…）
 * 读文件字节走 WIC 解码。两条都失败给 0。size<=0 用系统默认大小。 */
int wm_icon_load_file(const char *path, int size) {
  if (path == NULL || path[0] == '\0') {
    return 0;
  }
  if (wm_path_is_native_icon(path)) {
    WCHAR *wp = wm_utf8_to_wide(path);
    if (wp != NULL) {
      UINT flags = LR_LOADFROMFILE;
      if (size <= 0) {
        flags |= LR_DEFAULTSIZE;
      }
      HICON ic =
          (HICON)LoadImageW(NULL, wp, IMAGE_ICON, size, size, flags);
      free(wp);
      if (ic != NULL) {
        int slot = wm_icon_store(ic, NULL, NULL);
        if (slot == 0) {
          DestroyIcon(ic);
        }
        return slot;
      }
    }
    // 落到 WIC 再试（例如把 PNG 命名成 .bmp 的怪文件）
  }
  int len = 0;
  unsigned char *buf = wm_read_file_all(path, &len);
  if (buf == NULL) {
    return 0;
  }
  int slot = wm_icon_from_png(buf, len);
  free(buf);
  return slot;
}

/* WIC 从内存解码 PNG/JPEG/GIF/BMP → 32bpp BGRA → HICON。COM 已初始化则复用
 * （RPC_E_CHANGED_MODE 说明别的套间先初始化过，WIC 仍可用）。 */
int wm_icon_from_png(const unsigned char *data, int len) {
  if (data == NULL || len <= 0) {
    return 0;
  }
  HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
  if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
    return 0;
  }
  IWICImagingFactory *factory = NULL;
  IWICStream *stream = NULL;
  IWICBitmapDecoder *decoder = NULL;
  IWICBitmapFrameDecode *frame = NULL;
  IWICFormatConverter *conv = NULL;
  int slot = 0;
  unsigned char *px = NULL;
  // 用 CLSID_WICImagingFactory1（Vista 起的 WIC 工厂）：头文件在
  // _WIN32_WINNT>=0x0602 时把 CLSID_WICImagingFactory 宏别名到 Win8 才有的
  // Factory2，显式取 1 号可兼容旧系统（vtable 前缀一致，IID 仍用 v1）。
  hr = CoCreateInstance(&CLSID_WICImagingFactory1, NULL, CLSCTX_INPROC_SERVER,
                        &IID_IWICImagingFactory, (void **)&factory);
  if (SUCCEEDED(hr)) {
    hr = factory->lpVtbl->CreateStream(factory, &stream);
  }
  if (SUCCEEDED(hr)) {
    hr = stream->lpVtbl->InitializeFromMemory(stream, (BYTE *)data, (DWORD)len);
  }
  if (SUCCEEDED(hr)) {
    hr = factory->lpVtbl->CreateDecoderFromStream(
        factory, (IStream *)stream, NULL, WICDecodeMetadataCacheOnDemand,
        &decoder);
  }
  if (SUCCEEDED(hr)) {
    hr = decoder->lpVtbl->GetFrame(decoder, 0, &frame);
  }
  if (SUCCEEDED(hr)) {
    hr = factory->lpVtbl->CreateFormatConverter(factory, &conv);
  }
  if (SUCCEEDED(hr)) {
    hr = conv->lpVtbl->Initialize(
        conv, (IWICBitmapSource *)frame, &GUID_WICPixelFormat32bppBGRA,
        WICBitmapDitherTypeNone, NULL, 0.0, WICBitmapPaletteTypeCustom);
  }
  if (SUCCEEDED(hr)) {
    UINT w = 0, h = 0;
    hr = conv->lpVtbl->GetSize(conv, &w, &h);
    if (SUCCEEDED(hr) && w > 0 && h > 0) {
      UINT stride = w * 4u;
      px = (unsigned char *)malloc((size_t)stride * h);
      if (px != NULL) {
        hr = conv->lpVtbl->CopyPixels(conv, NULL, stride, stride * h, px);
        if (SUCCEEDED(hr)) {
          slot = wm_icon_from_bgra(px, (int)w, (int)h);
        }
      } else {
        hr = E_OUTOFMEMORY;
      }
    }
  }
  if (px != NULL) {
    free(px);
  }
  if (conv != NULL) {
    conv->lpVtbl->Release(conv);
  }
  if (frame != NULL) {
    frame->lpVtbl->Release(frame);
  }
  if (decoder != NULL) {
    decoder->lpVtbl->Release(decoder);
  }
  if (stream != NULL) {
    stream->lpVtbl->Release(stream);
  }
  if (factory != NULL) {
    factory->lpVtbl->Release(factory);
  }
  return slot;
}

/* 释放一个图标句柄（幂等）。 */
void wm_icon_free(int slot) {
  if (slot <= 0 || slot >= WM_MAX_ICONS) {
    return;
  }
  if (wm_icons[slot].hicon != NULL) {
    DestroyIcon(wm_icons[slot].hicon);
  }
  if (wm_icons[slot].color != NULL) {
    DeleteObject(wm_icons[slot].color);
  }
  if (wm_icons[slot].mask != NULL) {
    DeleteObject(wm_icons[slot].mask);
  }
  memset(&wm_icons[slot], 0, sizeof(wm_icons[slot]));
}

/* 当前存活图标数（探针/测试用）。 */
int wm_icon_alive(void) {
  int n = 0;
  for (int i = 1; i < WM_MAX_ICONS; i++) {
    if (wm_icons[i].hicon != NULL) {
      n++;
    }
  }
  return n;
}

/* 取槽里的真 HICON（探针反读用；越界/空槽给 NULL）。 */
void *wm_icon_handle(int slot) {
  return (void *)wm_icon_get(slot);
}

/* ---- 原生消息框（W20d）---------------------------------------------------
 * MessageBoxW 一次调用就把框显示并**模态阻塞**到用户点按钮，返回按钮编号——
 * 没有回调、没有窗口槽，是最适合「阻塞式 FFI」的一条（与热键那种「寄存器 +
 * 泵里抽」不同）。uType 的四段位组合由 MoonBit 侧纯函数算好传进来（见
 * yue/win/message_box.mbt），这里只做宽串转换与调用。
 * hwnd 传 NULL：消息框为进程级（不隶属某窗口），与旧栈 MessageBox::show 同形；
 * show_for_window 的挂窗形态留待需要时补（传具体 HWND）。
 * 文本是 UTF-8 Bytes（#borrow），这里转 UTF-16 交给 W 系 API。 */
int wm_message_box(const char *title, const char *text, int utype) {
  WCHAR *wt = wm_utf8_to_wide(title);
  WCHAR *wx = wm_utf8_to_wide(text);
  int r = (int)MessageBoxW(NULL, wx != NULL ? wx : L"", wt != NULL ? wt : L"",
                           (UINT)utype);
  free(wt);
  free(wx);
  return r;
}

int64_t wm_now_ms(void) {
  return (int64_t)GetTickCount64(); // 开机起单调，与 CLOCK_MONOTONIC 同语义
}

/* ---- 系统深浅偏好与主色（主题跟随系统用，W13 的 Windows 读数先落这里）----
 * 深浅读 AppsUseLightTheme（0 = dark）；主色读 DWM 的 AccentColor
 * （0xAABBGGRR 口径），转 "#rrggbb"。读不到给空串，退路由 MoonBit 决定。 */
int wm_sys_color_scheme(char *out, int cap) {
  if (out == NULL || cap < 1) {
    return 0;
  }
  out[0] = '\0';
  HKEY key;
  if (RegOpenKeyExW(HKEY_CURRENT_USER,
                    L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
                    0, KEY_READ, &key) != ERROR_SUCCESS) {
    return 0;
  }
  DWORD v = 0;
  DWORD size = sizeof(v);
  DWORD type = 0;
  LSTATUS r = RegQueryValueExW(key, L"AppsUseLightTheme", NULL, &type,
                               (LPBYTE)&v, &size);
  RegCloseKey(key);
  if (r != ERROR_SUCCESS || type != REG_DWORD) {
    return 0;
  }
  const char *s = v == 0 ? "dark" : "light";
  int n = (int)strlen(s);
  if (n >= cap) {
    n = cap - 1;
  }
  memcpy(out, s, (size_t)n);
  out[n] = '\0';
  return n;
}

int wm_sys_accent(char *out, int cap) {
  if (out == NULL || cap < 1) {
    return 0;
  }
  out[0] = '\0';
  HKEY key;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\DWM",
                    0, KEY_READ, &key) != ERROR_SUCCESS) {
    return 0;
  }
  DWORD v = 0;
  DWORD size = sizeof(v);
  DWORD type = 0;
  LSTATUS r =
      RegQueryValueExW(key, L"AccentColor", NULL, &type, (LPBYTE)&v, &size);
  RegCloseKey(key);
  if (r != ERROR_SUCCESS || type != REG_DWORD || cap < 8) {
    return 0;
  }
  // 0xAABBGGRR：低三字节 B,G,R
  snprintf(out, (size_t)cap, "#%02x%02x%02x", (unsigned)(v & 0xff),
           (unsigned)((v >> 8) & 0xff), (unsigned)((v >> 16) & 0xff));
  return 7; // "#rrggbb"
}

int64_t wm_local_date(void) {
  SYSTEMTIME st;
  GetLocalTime(&st);
  return (int64_t)st.wYear * 10000 + (int64_t)st.wMonth * 100 + (int64_t)st.wDay;
}

// ---- 原生子件通道（方案 §4.7）——Windows 真实现（平台批）----
// 语义对齐 GTK 桩：surface = 一个 WS_CHILD 面板 HWND（父 = 宿主窗口），WebView2
// 等原生引擎以它为 parent；容器指针经 wm_surface_container() 交给能力层桩
// （C 之间传指针，MoonBit 只搬 int64）。矩形按窗口内容坐标给——整栈物理像素
// 口径（per-monitor v2），客户区坐标即物理像素，无需再换算。
int64_t wm_surface_new(int64_t window_id, int kind, int x, int y, int w,
                       int h) {
  if (window_id <= 0 || window_id >= WM_MAX_WINDOWS) {
    return 0;
  }
  WmWindow *win = &wm_windows[window_id];
  if (win->hwnd == NULL) {
    return 0;
  }
  int sid = 0;
  for (int i = 1; i < WM_MAX_SURFACES; i++) {
    if (wm_surfaces[i].hwnd == NULL) {
      sid = i;
      break;
    }
  }
  if (sid == 0) {
    return 0;
  }
  // 背景刷 NULL：原生引擎（WebView2）自己盖满，避免建窗到首帧之间的闪白；
  // 光标不设——页面内的手型/文本等由引擎自管，与 GTK 桩的容器同语义。
  HWND hwnd = CreateWindowExW(0, L"yue_wm_surface", L"", WS_CHILD | WS_VISIBLE,
                              x, y, w > 1 ? w : 1, h > 1 ? h : 1, win->hwnd,
                              NULL, GetModuleHandleW(NULL), NULL);
  if (hwnd == NULL) {
    return 0;
  }
  wm_surfaces[sid].hwnd = hwnd;
  wm_surfaces[sid].window_id = window_id;
  wm_surfaces[sid].kind = kind;
  wm_surfaces[sid].x = x;
  wm_surfaces[sid].y = y;
  wm_surfaces[sid].w = w;
  wm_surfaces[sid].h = h;
  return (int64_t)sid;
}

void wm_surface_set_rect(int64_t surface_id, int x, int y, int w, int h) {
  if (surface_id <= 0 || surface_id >= WM_MAX_SURFACES) {
    return;
  }
  WmSurface *s = &wm_surfaces[surface_id];
  if (s->hwnd == NULL) {
    return;
  }
  if (s->x == x && s->y == y && s->w == w && s->h == h) {
    return; // 每帧都同步，位置没动就不重排
  }
  s->x = x;
  s->y = y;
  s->w = w;
  s->h = h;
  MoveWindow(s->hwnd, x, y, w > 1 ? w : 1, h > 1 ? h : 1, TRUE);
}

void wm_surface_close(int64_t surface_id) {
  if (surface_id <= 0 || surface_id >= WM_MAX_SURFACES) {
    return;
  }
  WmSurface *s = &wm_surfaces[surface_id];
  if (s->hwnd != NULL) {
    DestroyWindow(s->hwnd);
  }
  memset(s, 0, sizeof(WmSurface));
}

// 给能力层的桩用（web 的 WebView2 桩把它转 HWND 当 parentHWND）。
void *wm_surface_container(int64_t surface_id) {
  if (surface_id <= 0 || surface_id >= WM_MAX_SURFACES) {
    return NULL;
  }
  return (void *)wm_surfaces[surface_id].hwnd;
}
void wm_window_set_popup(int64_t id, int64_t owner_id) { (void)id; (void)owner_id; }
void wm_window_move(int64_t id, int x, int y) { (void)id; (void)x; (void)y; }
void wm_window_origin(int64_t id, int32_t *out_x, int32_t *out_y) {
  (void)id; (void)out_x; (void)out_y;
}

void wm_window_set_size(int64_t id, int w, int h) { (void)id; (void)w; (void)h; }
void wm_window_set_fullscreen(int64_t id, int on) { (void)id; (void)on; }
int wm_window_surface_count(int64_t id) {
  (void)id;
  return 0;
}

/* 剪贴板三符号：Windows 的真路径在 sys 桩自己的 CF_UNICODETEXT
 * （`sys/clipboard.mbt` 的 windows 分支不会调到这里），这里只保证符号不断。 */
int wm_clipboard_available(void) { return 0; }
void *wm_clipboard_get_text(int32_t *ok) {
  *ok = 0;
  return moonbit_make_bytes(0, 0);
}
int wm_clipboard_set_text(const char *text) {
  (void)text;
  return 0;
}

#elif defined(WM_STUB_GTK)

// ---------------- GTK3 后端（Linux，prebuild 专编） ----------------

#include <gtk/gtk.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define WM_MAX_WINDOWS 32
#define WM_MAX_FDS 64

typedef struct {
  guint32 keysym;
  guint32 code;    // 0 键 / 1 按下键 / 2 按下指针 / 3 释放指针 / 4 滚轮
  gint32 x;
  gint32 y;
  gint32 dx;
  gint32 dy;
  guint32 mods;
} WmEv;

typedef struct {
  GtkWidget *window;
  GtkWidget *area;
  // 内容容器：GtkFixed。绘制区固定在 (0,0) 并跟随窗口尺寸，原生子件（webview
  // 等不可自绘的东西）作为同级的可定位子件挂进来（方案 §4.7 的「容器里放一个
  // 原生子件」）。用 Fixed 而不是 Overlay 是为了事件路由不用做手脚：Fixed 是普通
  // 容器，指针落在子件上归子件、落在别处归绘制区，没有 Overlay 的 pass-through 语义。
  GtkWidget *fixed;
  int need_draw;   // 需要重绘（expose 或尺寸变化后置 1）
  int resized;     // 尺寸变了，本次取事件时回报新宽高
  int closing;     // 窗口管理器请求关闭
  int focus_lost;  // 刚失去键盘焦点（原生浮层据此「点外收起」）
  int width;
  int height;
  const unsigned char *pending; // 待贴的 ARGB32 缓冲（指向下面的 backing）
  int pending_w;
  int pending_h;
  unsigned char *backing; // 后端自己拥有的帧缓冲（跨到下一次 draw 回调仍有效）
  size_t backing_cap;
  GtkIMContext *im;
  int cursor_kind;   // 当前光标形状（0 默认/1 手/2 文本/3 横向/4 纵向），-1 未设过
  char commit[256]; // 已提交文本（UTF-8），MoonBit 逐字节读走后清零
  int commit_len;
  char preedit[256]; // 未提交的组合串，仅用于自绘显示
  int preedit_len;
  int preedit_caret;
  int preedit_active;
  WmEv evs[64];
  WmEv last;
  int ev_head;
  int ev_count;
} WmWindow;

static WmWindow wm_windows[WM_MAX_WINDOWS];
static int wm_next_id = 1;

// 原生子件槽：一个 GtkFixed 容器，能力层（yue/browser 的 webkit 桩等）通过
// wm_surface_container() 拿到它把自己的控件 put 进去。句柄 = 槽号（1 起）。
#define WM_MAX_SURFACES 64
typedef struct {
  GtkWidget *container;
  int64_t window_id;  // 归属窗口：窗口关闭时这些槽一起清
  int kind;
  int x, y, w, h;
} WmSurface;

static WmSurface wm_surfaces[WM_MAX_SURFACES];
static int wm_surface_next_id = 1;

// 修饰位必须与 MoonBit 侧 yue/core/keys.mbt 的 MOD_* 一致：
// 1=shift 2=ctrl 4=alt 8=meta（GTK 自身位值是 1/4/8/16，故显式重映射）。
// 这张表的**权威版本**在 yue/core/input_map.mbt 的 gtk_mods_to_mods（纯函数、有
// 回归钉住），改这里必须同批改那里——Windows/macOS 后端直接调那份表。
static guint32 wm_mods(guint state) {
  guint32 m = 0;
  if (state & GDK_SHIFT_MASK) {
    m |= 1u;
  }
  if (state & GDK_CONTROL_MASK) {
    m |= 2u;
  }
  if (state & GDK_MOD1_MASK) {
    m |= 4u;
  }
  // Meta/Super 只认这两个位；绝不能把 MOD2 当 Meta——MOD2 就是 NumLock，
  // 平时恒为亮，会让每个按键都带上 Meta，内核据此判定为组合键而丢弃可打印键
  // （实测 mods=8、字符全部打不进去）
  if (state & (GDK_META_MASK | GDK_SUPER_MASK)) {
    m |= 8u;
  }
  return m;
}

static void wm_push(WmWindow *w, const WmEv *ev) {
  // 指针移动先合并：队列里最后一条也是**未消费**的移动时直接替换（位置是状态、
  // 不是流水，只留最新一条语义不丢）。一帧（真机 300–500ms 量级）里能攒下上百条
  // 移动事件，64 槽的队列会被它们塞满，随后的抬起/滚轮就整批丢掉——真机表现正是
  // 「按钮点了没反应、表头点了不排序、滚轮不滚」。合并后队列里任何时刻最多一条
  // 移动，抬起与滚轮不会再被挤掉。只在「最后一条也是移动」时替换：中间夹着
  // 按下/抬起就不动它，FIFO 语义不破。
  if (ev->code == 4u && w->ev_count > 0) {
    int last = (w->ev_head + w->ev_count - 1) % 64;
    if (w->evs[last].code == 4u) {
      w->evs[last] = *ev;
      return;
    }
  }
  if (w->ev_count >= 64) {
    return; // 满了丢弃而不是覆盖：宁可丢一个事件，不能把 FIFO 打乱
  }
  int slot = (w->ev_head + w->ev_count) % 64;
  w->evs[slot] = *ev;
  w->ev_count++;
}

static void wm_store_text(char *dst, int *dst_len, const char *src) {
  int n = 0;
  if (src != NULL) {
    while (src[n] != '\0' && n < 255) {
      dst[n] = src[n];
      n++;
    }
  }
  dst[n] = '\0';
  *dst_len = n;
}

static void wm_on_im_commit(GtkIMContext *im, gchar *text, gpointer data) {
  (void)im;
  WmWindow *w = (WmWindow *)data;
  wm_store_text(w->commit, &w->commit_len, text);
  // 串的所有权在 GTK（信号返回后它自己释放），这里绝不能 g_free ——
  // 实测 free(): double free detected in tcache 2 直接 core dump。探针同此。
}

// 「commit」信号带文本；「preedit-changed」只带上下文，串要用
// gtk_im_context_get_preedit_string 取（探针里就是这个形态，签名照抄会错）
static void wm_on_preedit_changed(GtkIMContext *ctx, gpointer data) {
  WmWindow *w = (WmWindow *)data;
  gchar *str = NULL;
  PangoAttrList *attrs = NULL;
  gint caret = 0;
  gtk_im_context_get_preedit_string(ctx, &str, &attrs, &caret);
  wm_store_text(w->preedit, &w->preedit_len, str != NULL ? str : "");
  // caret 是组合串内的**字节**偏移（MoonBit 侧按 UTF-8 字节管光标，同口径）
  w->preedit_caret = caret > w->preedit_len ? w->preedit_len : caret;
  if (attrs != NULL) {
    pango_attr_list_unref(attrs);
  }
  g_free(str);
}

static void wm_on_preedit_start(GtkIMContext *im, gpointer data) {
  (void)im;
  ((WmWindow *)data)->preedit_active = 1;
}

static void wm_on_preedit_end(GtkIMContext *im, gpointer data) {
  (void)im;
  WmWindow *w = (WmWindow *)data;
  w->preedit_active = 0;
  w->preedit_len = 0;
  w->preedit[0] = '\0';
}

// 输入法上下文必须在 realize 之后才拿得到 client window：早于 realize 时
// gtk_widget_get_window 返回 NULL，set_client_window 等于没做，multicontext
// 就不会挂上任何输入法模块（实测表现为 filter_keypress 恒不消费、拼音原样进文本）
static void wm_on_realize(GtkWidget *area, gpointer data) {
  WmWindow *w = (WmWindow *)data;
  if (w->im == NULL) {
    return;
  }
  GdkWindow *gw = gtk_widget_get_window(area);
  if (gw != NULL) {
    gtk_im_context_set_client_window(w->im, gw);
  }
  gtk_im_context_focus_in(w->im);
}

static gboolean wm_on_area_focus_in(GtkWidget *area, GdkEventFocus *ev,
                                    gpointer data) {
  (void)area;
  (void)ev;
  WmWindow *w = (WmWindow *)data;
  if (w->im != NULL) {
    gtk_im_context_focus_in(w->im);
  }
  return FALSE;
}

// 失焦必须 focus_out，否则输入法侧残留未完成组合串（清单第 5 项）
static gboolean wm_on_area_focus_out(GtkWidget *area, GdkEventFocus *ev,
                                     gpointer data) {
  (void)area;
  (void)ev;
  WmWindow *w = (WmWindow *)data;
  if (w->im != NULL) {
    gtk_im_context_focus_out(w->im);
    w->preedit_active = 0;
    w->preedit_len = 0;
    w->preedit[0] = '\0';
  }
  // 原生浮层的「点外收起」只能靠这条：点网页区时按钮事件被 webview 子窗吃掉，
  // 只有焦点转移这件事会告诉我们「用户点了别处」
  w->focus_lost = 1;
  return FALSE;
}

static void wm_mark_draw(WmWindow *w) {
  w->need_draw = 1;
}

static gboolean wm_on_draw(GtkWidget *area, cairo_t *cr, gpointer data) {
  (void)area;
  WmWindow *w = (WmWindow *)data;
  // 只在这里贴像素：GdkWindow 的生命周期由 GTK/WM 管，在 draw 之外拿它的
  // cairo 画会在窗口被销毁后打到死窗口上（实测 X 错误 RenderBadPicture）
  if (w->pending != NULL && w->pending_w > 0 && w->pending_h > 0) {
    // 有帧就贴帧、**不置 need_draw**：present 自己每帧都 queue_draw，这里再置脏
    // 就成自维持环（present → draw → 置脏 → 全帧重画 → present → …），应用永不
    // 空闲、输入只能排在一帧之后。重绘请求一律由 MoonBit 侧 schedule_paint 发起。
    cairo_surface_t *surf = cairo_image_surface_create_for_data(
        (unsigned char *)w->pending, CAIRO_FORMAT_ARGB32, w->pending_w,
        w->pending_h, w->pending_w * 4);
    if (cairo_surface_status(surf) == CAIRO_STATUS_SUCCESS) {
      cairo_set_source_surface(cr, surf, 0, 0);
      cairo_paint(cr);
    }
    cairo_surface_destroy(surf);
  } else {
    w->need_draw = 1; // 还没有帧可贴：请 MoonBit 画第一帧
  }
  return FALSE;
}

static void wm_on_size_allocate(GtkWidget *area, GdkRectangle *alloc,
                                gpointer data) {
  (void)area;
  WmWindow *w = (WmWindow *)data;
  w->width = alloc->width;
  w->height = alloc->height;
  w->resized = 1;
  w->need_draw = 1;
}

static gboolean wm_on_key(GtkWidget *widget, GdkEventKey *ev, gpointer data) {
  (void)widget;
  WmWindow *w = (WmWindow *)data;
  if (ev->type == GDK_KEY_PRESS && w->im != NULL &&
      gtk_im_context_filter_keypress(w->im, ev)) {
    return TRUE; // 输入法吃掉了：不推按键事件，改由 commit/preedit 通道回报
  }
  WmEv e;
  memset(&e, 0, sizeof(e));
  e.code = ev->type == GDK_KEY_PRESS ? 0u : 1u;
  // keyval 本身已含 shift 语义（'a' 与 'A' 不同值），不能再小写化
  e.keysym = ev->keyval;
  e.mods = wm_mods(ev->state);
  wm_push(w, &e);
  return TRUE; // 已经交给 MoonBit，不再走 GTK 的控件级派发
}

static gboolean wm_on_button(GtkWidget *widget, GdkEventButton *ev,
                             gpointer data) {
  (void)widget;
  WmWindow *w = (WmWindow *)data;
  WmEv e;
  memset(&e, 0, sizeof(e));
  // code: 0 键按下 1 键释放 2 按钮按下 3 按钮释放 4 指针移动 5 滚轮
  if (ev->type == GDK_BUTTON_RELEASE) {
    e.code = 3u;
  } else {
    e.code = 2u; // 双击对上层同样先是一次按下，双击语义由上层按时间判
  }
  e.x = (gint32)ev->x;
  e.y = (gint32)ev->y;
  e.dx = ev->button;
  e.mods = wm_mods(ev->state);
  wm_push(w, &e);
  return TRUE;
}

static gboolean wm_on_motion(GtkWidget *widget, GdkEventMotion *ev,
                             gpointer data) {
  (void)widget;
  WmWindow *w = (WmWindow *)data;
  WmEv e;
  memset(&e, 0, sizeof(e));
  e.code = 4u;
  e.x = (gint32)ev->x;
  e.y = (gint32)ev->y;
  e.mods = wm_mods(ev->state);
  wm_push(w, &e);
  return TRUE;
}

static gboolean wm_on_scroll(GtkWidget *widget, GdkEventScroll *ev,
                             gpointer data) {
  (void)widget;
  WmWindow *w = (WmWindow *)data;
  WmEv e;
  memset(&e, 0, sizeof(e));
  e.code = 5u;
  e.x = (gint32)ev->x;
  e.y = (gint32)ev->y;
  e.dy = ev->direction == GDK_SCROLL_UP ? 1
                                       : (ev->direction == GDK_SCROLL_DOWN ? -1
                                                                           : 0);
  e.dx = ev->direction == GDK_SCROLL_LEFT
      ? 1
      : (ev->direction == GDK_SCROLL_RIGHT ? -1 : 0);
  e.mods = wm_mods(ev->state);
  wm_push(w, &e);
  return TRUE;
}

// 窗口被 WM/GTK 销毁时必须清空句柄：否则 present 会 queue_draw 到悬垂 widget
// （实测刷一串 gtk_widget_queue_draw: assertion 'GTK_IS_WIDGET' failed）
static void wm_on_destroy(GtkWidget *widget, gpointer data) {
  (void)widget;
  WmWindow *w = (WmWindow *)data;
  w->window = NULL;
  w->area = NULL;
  w->pending = NULL;
  w->need_draw = 0;
  w->closing = 1; // 窗口没了也等于该退出了
}

static gboolean wm_on_delete(GtkWidget *window, GdkEvent *event, gpointer data) {
  (void)window;
  (void)event;
  WmWindow *w = (WmWindow *)data;
  w->closing = 1;
  return TRUE; // 不在此处销毁：先停派发、再拆对象由 MoonBit 侧驱动
}

int wm_init(void) {
  static int argc = 0;
  char **argv = NULL;
  if (!gtk_init_check(&argc, &argv)) {
    return 0; // 没有可用的显示服务，MoonBit 侧据此降级
  }
  return 1;
}

int64_t wm_window_new(int width, int height, const char *title) {
  // 槽位复用：窗口多开多关（附窗反复开合）不能把 32 个槽吃光。判据是 area 为空
  // ——建窗时必设、wm_close 里 memset 清零，于是拆过的槽与从没用过的槽同样可取。
  int id = 0;
  for (int i = 1; i < WM_MAX_WINDOWS; i++) {
    if (wm_windows[i].area == NULL) {
      id = i;
      break;
    }
  }
  if (id == 0) {
    return 0;
  }
  if (id >= wm_next_id) {
    wm_next_id = id + 1;
  }
  WmWindow *w = &wm_windows[id];
  w->width = width > 1 ? width : 1;
  w->height = height > 1 ? height : 1;
  w->window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(w->window), title ? title : "MoonBit");
  gtk_window_set_default_size(GTK_WINDOW(w->window), w->width, w->height);
  w->area = gtk_drawing_area_new();
  gtk_widget_set_can_focus(w->area, TRUE);
  GdkWindow *top = gtk_widget_get_window(w->window);
  (void)top; // realized 之后再设事件掩码
  gtk_widget_add_events(w->area, GDK_KEY_PRESS_MASK | GDK_KEY_RELEASE_MASK |
                                   GDK_BUTTON_PRESS_MASK |
                                   GDK_BUTTON_RELEASE_MASK |
                                   GDK_POINTER_MOTION_MASK |
                                   GDK_SCROLL_MASK);
  // 结构：窗口 → GtkOverlay →{ 主件=绘制区，覆盖件=摆原生子件的 GtkFixed }。
  // 为什么不用「窗口→GtkFixed→绘制区」：Fixed 不拉伸子件，只能把绘制区的
  // size_request 顶到窗口大小，而那是**最小尺寸**，会顺着 Fixed→Window 传回 WM
  // 再把窗撑大一点——拖着右边沿放大时自激，每轮比上一轮宽，松手也不停；
  // libyue 在 window_gtk.cc 里正是靠「清掉 size_request 否则窗口会有最小尺寸」
  // 躲这件事，而它的内容件是 GtkBox 拉伸的，本栈要绝对摆位所以用 Overlay。
  // 绘制区是主件，GtkBin 一定给它整窗尺寸，于是全树不再有任何 size_request。
  GtkWidget *ov = gtk_overlay_new();
  gtk_container_add(GTK_CONTAINER(w->window), ov);
  gtk_container_add(GTK_CONTAINER(ov), w->area);
  w->fixed = gtk_fixed_new();
  // 覆盖件要铺满整窗才裁不掉里面的原生子件：FILL + expand 是 GtkOverlay 的口径
  gtk_widget_set_halign(w->fixed, GTK_ALIGN_FILL);
  gtk_widget_set_valign(w->fixed, GTK_ALIGN_FILL);
  gtk_widget_set_hexpand(w->fixed, TRUE);
  gtk_widget_set_vexpand(w->fixed, TRUE);
  gtk_overlay_add_overlay(GTK_OVERLAY(ov), w->fixed);
  // **必须穿透**：GtkOverlay 默认把落在覆盖件区域的输入路由给覆盖件本身，铺满
  // 整窗就等于把自绘区的点击与滚轮全截了（实测：native-app 里按钮点不动、滚轮
  // 不滚）。TRUE = 事件落到主件；webview 自己有 GdkWindow，照常收它那块的事件。
  gtk_overlay_set_overlay_pass_through(GTK_OVERLAY(ov), w->fixed, TRUE);
  g_signal_connect(w->area, "realize", G_CALLBACK(wm_on_realize), w);
  g_signal_connect(w->area, "focus-in-event", G_CALLBACK(wm_on_area_focus_in), w);
  g_signal_connect(w->area, "focus-out-event",
                   G_CALLBACK(wm_on_area_focus_out), w);
  g_signal_connect(w->area, "draw", G_CALLBACK(wm_on_draw), w);
  g_signal_connect(w->area, "size-allocate", G_CALLBACK(wm_on_size_allocate), w);
  w->im = gtk_im_multicontext_new();
  // use_preedit 语义是「用 preedit 串做内联反馈」：TRUE（默认）才是自绘内联那一档，
  // 填 FALSE 会让输入法改用自带子窗且本环境一条 preedit 信号都不推（G0 实测读反过）
  gtk_im_context_set_use_preedit(w->im, TRUE);
  g_signal_connect(w->im, "commit", G_CALLBACK(wm_on_im_commit), w);
  g_signal_connect(w->im, "preedit-changed", G_CALLBACK(wm_on_preedit_changed), w);
  g_signal_connect(w->im, "preedit-start", G_CALLBACK(wm_on_preedit_start), w);
  g_signal_connect(w->im, "preedit-end", G_CALLBACK(wm_on_preedit_end), w);
  w->ev_head = 0;
  w->ev_count = 0;
  memset(&w->last, 0, sizeof(WmEv));
  g_signal_connect(w->window, "delete-event", G_CALLBACK(wm_on_delete), w);
  g_signal_connect(w->window, "destroy", G_CALLBACK(wm_on_destroy), w);
  // 按键挂到「焦点控件」而不是顶层窗口：这是 G0 探针用真机定下来的挂法
  // （见 docs/zh/adaptation.md「G0 输入法探针纯通道」条——挂窗口层会让事件顺序
  // 与消费判定都不对，输入法接管后尤其明显）。失焦的 area 不接键。
  g_signal_connect(w->area, "key-press-event", G_CALLBACK(wm_on_key), w);
  g_signal_connect(w->area, "key-release-event", G_CALLBACK(wm_on_key), w);
  g_signal_connect(w->area, "button-press-event", G_CALLBACK(wm_on_button), w);
  g_signal_connect(w->area, "button-release-event", G_CALLBACK(wm_on_button),
                   w);
  g_signal_connect(w->area, "motion-notify-event", G_CALLBACK(wm_on_motion),
                   w);
  g_signal_connect(w->area, "scroll-event", G_CALLBACK(wm_on_scroll), w);
  return (int64_t)id;
}

void wm_show(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->window != NULL) {
    gtk_widget_show_all(w->window);
    gtk_widget_grab_focus(w->area);
    // 必须把 map 请求推出去并跑一轮就绪事件：GDK 输出缓冲不 flush 的话，
    // X 服务端收不到 map，poll 就只能等到超时（实测 frames=0 的原因）。
    gdk_display_flush(gdk_display_get_default());
    while (gtk_events_pending()) {
      gtk_main_iteration_do(FALSE);
    }
    wm_mark_draw(w);
  }
}

void wm_size(int64_t id, int32_t *out_w, int32_t *out_h) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (out_w != NULL) {
    *out_w = w->width;
  }
  if (out_h != NULL) {
    *out_h = w->height;
  }
}

// 键盘焦点现在在谁身上：0 = 本窗没有焦点（整窗失焦，切到别的应用/别的窗），
// 1 = 在绘制区，2 = 在本窗内的某个原生子件（webview）。
// 上层要这条是为了把两种「focus-out」分开：让位给本窗子件 = 用户点了别处，
// 该清掉自绘控件的焦点；整窗失焦 = 不该清，回到本窗时焦点照旧。
int wm_focus_owner(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  WmWindow *w = &wm_windows[id];
  if (w->window == NULL) {
    return 0;
  }
  GtkWidget *f = gtk_window_get_focus(GTK_WINDOW(w->window));
  if (f == NULL) {
    return 0;
  }
  return f == w->area ? 1 : 2;
}

// 消费式取事件：1 = 需要重绘，2 = 尺寸变化（宽高已更新），3 = 请求关闭，
// 0 = 没有待处理事件。一次返回一个，MoonBit 侧循环取到 0 为止。
int wm_event(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  WmWindow *w = &wm_windows[id];
  if (w->ev_count > 0) {
    return 4; // 有输入事件待取（wm_take_event）
  }
  if (w->closing) {
    w->closing = 0;
    return 3;
  }
  if (w->resized) {
    w->resized = 0;
    return 2;
  }
  if (w->focus_lost) {
    w->focus_lost = 0;
    return 5; // 失去键盘焦点（浮层收起用）
  }
  if (w->need_draw) {
    w->need_draw = 0;
    return 1;
  }
  return 0;
}

// 把这一帧拷进后端自己的缓冲。原先 pending 直接指 MoonBit 的 Bitmap，
// 而贴像素发生在**下一次** draw 回调里——那之间 Bitmap 已经没人引用，
// GC 一收就是读已释放内存（症状正是使用者报的：多开一扇大窗/动起来的窗
// 时花屏、自绘区闪烁；expose 每次都会重读那个悬垂指针）。
static void wm_store_frame(WmWindow *w, const unsigned char *rgba, int width,
                           int height) {
  size_t need = (size_t)width * (size_t)height * (size_t)4;
  if (need == 0) {
    return;
  }
  if (w->backing_cap < need) {
    unsigned char *nb = (unsigned char *)realloc(w->backing, need);
    if (nb == NULL) {
      return;
    }
    w->backing = nb;
    w->backing_cap = need;
  }
  memcpy(w->backing, rgba, need);
  w->pending = w->backing;
  w->pending_w = width;
  w->pending_h = height;
}

void wm_present(int64_t id, const unsigned char *rgba, int width, int height) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->area == NULL || rgba == NULL || width < 1 || height < 1) {
    return;
  }
  // 拷进后端缓冲后再请重画：真正的贴像素在下一次 draw 回调里，
  // 那时窗口一定活着、数据也一定还活着。
  wm_store_frame(w, rgba, width, height);
  gtk_widget_queue_draw(w->area);
}

void wm_close(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  // 归属本窗的原生子件槽一起清：容器随窗口销毁，槽位必须空出来，
  // 否则能力层拿着悬垂的 GtkWidget 指针继续画就是段错误
  for (int i = 1; i < WM_MAX_SURFACES; i++) {
    if (wm_surfaces[i].container != NULL && wm_surfaces[i].window_id == id) {
      memset(&wm_surfaces[i], 0, sizeof(WmSurface));
    }
  }
  // 已被 WM 销毁过则 window 为 NULL，只清记录即可
  if (w->window != NULL) {
    gtk_widget_destroy(w->window);
    w->window = NULL;
    w->area = NULL;
  }
  w->pending = NULL;
  // 帧缓冲是后端 malloc 的，槽位复用前必须还掉（memset 只会把指针清没、
  // 留下泄漏，下一扇窗复用同一槽时 cap 也一起归零）
  free(w->backing);
  memset(w, 0, sizeof(WmWindow));
}

// ---- 原生子件通道（方案 §4.7）----
// 语义：子件不被 Painter 绘制、恒覆盖在自绘像素之上、不吃 clip_rect；
// 矩形由 yoga 布局算出后按窗口内容坐标给过来，DPI 换算在后端。

int64_t wm_surface_new(int64_t window_id, int kind, int x, int y, int w,
                       int h) {
  if (window_id <= 0 || window_id >= WM_MAX_WINDOWS) {
    return 0;
  }
  WmWindow *win = &wm_windows[window_id];
  if (win->fixed == NULL) {
    return 0;
  }
  int sid = 0;
  for (int i = 1; i < WM_MAX_SURFACES; i++) {
    if (wm_surfaces[i].container == NULL) {
      sid = i;
      break;
    }
  }
  if (sid == 0) {
    return 0;
  }
  GtkWidget *c = gtk_fixed_new();
  gtk_fixed_put(GTK_FIXED(win->fixed), c, x, y);
  gtk_widget_set_size_request(c, w > 1 ? w : 1, h > 1 ? h : 1);
  gtk_widget_show_all(c);
  wm_surfaces[sid].container = c;
  wm_surfaces[sid].window_id = window_id;
  wm_surfaces[sid].kind = kind;
  wm_surfaces[sid].x = x;
  wm_surfaces[sid].y = y;
  wm_surfaces[sid].w = w;
  wm_surfaces[sid].h = h;
  return (int64_t)sid;
}

void wm_surface_set_rect(int64_t surface_id, int x, int y, int w, int h) {
  if (surface_id <= 0 || surface_id >= WM_MAX_SURFACES) {
    return;
  }
  WmSurface *s = &wm_surfaces[surface_id];
  if (s->container == NULL) {
    return;
  }
  if (s->x == x && s->y == y && s->w == w && s->h == h) {
    return; // 每帧都同步，位置没动就不重排
  }
  s->x = x;
  s->y = y;
  s->w = w;
  s->h = h;
  gtk_fixed_move(GTK_FIXED(wm_windows[s->window_id].fixed), s->container, x, y);
  gtk_widget_set_size_request(s->container, w > 1 ? w : 1, h > 1 ? h : 1);
}

void wm_surface_close(int64_t surface_id) {
  if (surface_id <= 0 || surface_id >= WM_MAX_SURFACES) {
    return;
  }
  WmSurface *s = &wm_surfaces[surface_id];
  if (s->container != NULL) {
    gtk_widget_destroy(s->container);
  }
  memset(s, 0, sizeof(WmSurface));
}

// 给能力层的桩用（yue/browser 的 webkit 桩把 WebKitWebView 放进这个容器）。
GtkWidget *wm_surface_container(int64_t surface_id) {
  if (surface_id <= 0 || surface_id >= WM_MAX_SURFACES) {
    return NULL;
  }
  return wm_surfaces[surface_id].container;
}

// ---- 原生弹层窗口（批 E）----
// 浮层（下拉/右键菜单/tooltip/toast/对话框）要能盖住 webview 区，就只能是真的
// 顶层窗口——自绘像素永远在原生子件之下（方案 §4.5 的浮层纪律）。
// 必须在 show 之前调：类型提示与 transient 关系在映射时才生效。
void wm_window_set_popup(int64_t id, int64_t owner_id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->window == NULL) {
    return;
  }
  gtk_window_set_decorated(GTK_WINDOW(w->window), FALSE);
  gtk_window_set_type_hint(
      GTK_WINDOW(w->window), GDK_WINDOW_TYPE_HINT_POPUP_MENU);
  gtk_window_set_skip_taskbar_hint(GTK_WINDOW(w->window), TRUE);
  gtk_window_set_skip_pager_hint(GTK_WINDOW(w->window), TRUE);
  // 不设 resizable(FALSE)：无边框窗用户本来就拖不动，而设了 FALSE 之后
  // gtk_window_resize 会被忽略——浮层「先开框、量完内容再收框」就收不了。
  gtk_window_set_resizable(GTK_WINDOW(w->window), TRUE);
  gtk_window_set_keep_above(GTK_WINDOW(w->window), TRUE);
  if (owner_id > 0 && owner_id < WM_MAX_WINDOWS &&
      wm_windows[owner_id].window != NULL) {
    gtk_window_set_transient_for(GTK_WINDOW(w->window),
                                 GTK_WINDOW(wm_windows[owner_id].window));
  }
}

void wm_window_move(int64_t id, int x, int y) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->window != NULL) {
    gtk_window_move(GTK_WINDOW(w->window), x, y);
  }
}

// 客户区在屏幕上的原点：弹层要按「owner 的原点 + 控件的窗口内矩形」摆位
void wm_window_origin(int64_t id, int32_t *out_x, int32_t *out_y) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->window == NULL) {
    return;
  }
  gint x = 0;
  gint y = 0;
  // gtk_window_get_position 给的是「相对父窗」的坐标，而窗口管理器会把顶层窗
  // reparent 进装饰框架里，于是它恒返回 (0,0)。要屏幕原点必须问 GdkWindow。
  GdkWindow *gw = gtk_widget_get_window(w->window);
  if (gw != NULL) {
    gdk_window_get_origin(gw, &x, &y);
  } else {
    gtk_window_get_position(GTK_WINDOW(w->window), &x, &y);
  }
  if (out_x != NULL) {
    *out_x = x;
  }
  if (out_y != NULL) {
    *out_y = y;
  }
}

// 改窗口尺寸（原生浮层要先量内容再定框，避免开一个空框再撑大）
void wm_window_set_size(int64_t id, int w, int h) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *win = &wm_windows[id];
  if (win->window == NULL) {
    return;
  }
  int ww = w > 1 ? w : 1;
  int hh = h > 1 ? h : 1;
  // 只 resize 窗口：绘制区是 overlay 的主件，尺寸恒等于窗口，没有要跟着改的请求。
  // （旧结构必须连绘制区的 size_request 一起改，那既是拖窗自增的回路源头，
  //  也是「浮层量完内容收框后缩不回初始大小、留一圈死边」的原因——两个坑同源）
  gtk_window_resize(GTK_WINDOW(win->window), ww, hh);
}

// 全屏开关（播放器要的「铺满整屏」是窗口级动作，不是把控件尺寸改大）
void wm_window_set_fullscreen(int64_t id, int on) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *win = &wm_windows[id];
  if (win->window == NULL) {
    return;
  }
  if (on) {
    gtk_window_fullscreen(GTK_WINDOW(win->window));
  } else {
    gtk_window_unfullscreen(GTK_WINDOW(win->window));
  }
}

// 本窗已挂的原生子件数：>0 说明这扇窗里有网页这类「自绘像素盖不住」的东西，
// 浮层就必须走真窗口（方案 §4.5 的浮层纪律）
int wm_window_surface_count(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  int n = 0;
  for (int i = 1; i < WM_MAX_SURFACES; i++) {
    if (wm_surfaces[i].container != NULL && wm_surfaces[i].window_id == id) {
      n++;
    }
  }
  return n;
}

// 跑掉主上下文里已经就绪的事件；不阻塞。
void wm_pump(void) {
  while (g_main_context_pending(NULL)) {
    g_main_context_iteration(NULL, FALSE);
  }
}

// timeout_ms < 0 表示无限等（MoonBit 侧无待办时用），此时必须有人调 wm_wakeup
// 或事件到达才能回来；否则就是死锁，这是漏唤醒的代价。
int wm_wait(int timeout_ms) {
  GMainContext *ctx = g_main_context_default();
  gint priority = 0;
  gint gtimeout = 0;
  GPollFD fds[WM_MAX_FDS];
  gint n;

  // 本机 glib 的加固签名：query 末位要传缓冲区容量、check 末位是 n_fds
  // （与多数文档示例的四参形态不同，实测按 /usr/include/glib-2.0/glib/gmain.h）
  (void)g_main_context_prepare(ctx, &priority);
  n = (gint)g_main_context_query(ctx, priority, &gtimeout, fds, WM_MAX_FDS);
  if (n > WM_MAX_FDS) {
    n = WM_MAX_FDS;
  }
  // -1 = 无限等；否则取「MoonBit 给的预算」与「GLib 自己要求的超时」中较短者
  gint wait_ms;
  if (timeout_ms < 0) {
    wait_ms = gtimeout;
  } else if (gtimeout < 0) {
    wait_ms = (gint)timeout_ms;
  } else {
    wait_ms = timeout_ms < gtimeout ? timeout_ms : gtimeout;
  }

  struct pollfd pf[WM_MAX_FDS];
  for (gint i = 0; i < n; i++) {
    pf[i].fd = fds[i].fd;
    pf[i].events = 0;
    if (fds[i].events & G_IO_IN) {
      pf[i].events |= POLLIN;
    }
    if (fds[i].events & G_IO_OUT) {
      pf[i].events |= POLLOUT;
    }
    if (fds[i].events & G_IO_PRI) {
      pf[i].events |= POLLPRI;
    }
    pf[i].revents = 0;
    fds[i].revents = 0;
  }
  // 注意：这里绝不能再调 g_main_context_wakeup —— 它会把 GLib 内部的唤醒
  // 管道置为可读，poll 立刻返回，外层退化成忙轮询（实测 dt=0、占满 CPU）。
  // 跨线程唤醒由外部调 wm_wakeup() 触发，效果就是让本次 poll 提前返回。
  gint got = poll(pf, n, wait_ms);
  gint ready = 0;
  for (gint i = 0; i < n; i++) {
    fds[i].revents = pf[i].revents;
    if (pf[i].revents != 0) {
      ready++;
    }
  }
  g_main_context_check(ctx, priority, fds, n);
  if (ready > 0 || g_main_context_pending(ctx)) {
    wm_pump();
    return 1;
  }
  (void)got;
  (void)ready;
  return 0;
}

// 取一个输入事件，返回其 code（0 键按下 1 键释放 2 按钮按下 3 按钮释放
// 4 指针移动 5 滚轮），无事件返回 -1。字段随后用 wm_ev_* 读这一条——
// MoonBit 侧不能给 C 传可写数组（传过去的是对象头，写 out[0] 会踩坏它），
// 所以走「取一条 + 逐字段读」而不是七个出参。
int wm_take_event(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return -1;
  }
  WmWindow *w = &wm_windows[id];
  if (w->ev_count == 0) {
    return -1;
  }
  w->last = w->evs[w->ev_head];
  w->ev_head = (w->ev_head + 1) % 64;
  w->ev_count--;
  return (int)w->last.code;
}

gint32 wm_ev_keysym(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? (gint32)wm_windows[id].last.keysym : 0;
}
gint32 wm_ev_mods(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? (gint32)wm_windows[id].last.mods : 0;
}
gint32 wm_ev_x(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? wm_windows[id].last.x : 0;
}
gint32 wm_ev_y(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? wm_windows[id].last.y : 0;
}
gint32 wm_ev_button(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? wm_windows[id].last.dx : 0;
}
gint32 wm_ev_axis(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? wm_windows[id].last.dy : 0;
}

int wm_pending_events(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].ev_count;
}

void wm_request_focus(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->area != NULL) {
    gtk_widget_grab_focus(w->area);
  }
}

void wm_im_set_surrounding(int64_t id, const char *text, int caret) {
  if (text == NULL) {
    return;
  }
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->im == NULL) {
    return;
  }
  // 只喂已提交文本：组合串不进 surrounding，否则输入法按错上下文推断。
  // 用探针验证过的四参形态（text, len, cursor 为字节偏移），不走带 SelectionData 的新接口。
  gtk_im_context_set_surrounding(w->im, text, (gint)strlen(text), caret);
}

// 逻辑焦点从一个输入控件切到另一个时清掉输入法侧未完成的组合串：
// 不清的话，前一个框攒下的拼音会在后一个框拿到焦点后 commit 进去。
// 一并清本侧缓存——输入法在 reset 后不一定再推 preedit-changed，
// 旧串留在缓存里就会被继续画出来。
void wm_im_reset(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->im == NULL) {
    return;
  }
  gtk_im_context_reset(w->im);
  w->preedit_len = 0;
  w->preedit[0] = '\0';
}

// 设绘图区光标形状：0 默认箭头 / 1 手型 / 2 文本 I 形 / 3 横向调整 / 4 纵向调整。
// 自绘栈没有原生控件，悬停在手型件上时形状只能由宿主按命中路径下发；
// 未 realize（还没有 GdkWindow）或形状没变时什么都不做。
void wm_set_cursor(int64_t id, int kind) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->area == NULL || w->cursor_kind == kind) {
    return;
  }
  GdkWindow *gw = gtk_widget_get_window(w->area);
  if (gw == NULL) {
    return;
  }
  const char *name = "default";
  if (kind == 1) {
    name = "pointer";
  } else if (kind == 2) {
    name = "text";
  } else if (kind == 3) {
    name = "ew-resize";
  } else if (kind == 4) {
    name = "ns-resize";
  }
  GdkDisplay *dpy = gtk_widget_get_display(w->area);
  GdkCursor *cur = gdk_cursor_new_from_name(dpy, name);
  if (cur == NULL) {
    cur = gdk_cursor_new_from_name(dpy, "default");
  }
  if (cur == NULL) {
    return;
  }
  gdk_window_set_cursor(gw, cur);
  g_object_unref(cur);
  w->cursor_kind = kind;
  gdk_display_flush(dpy);
}

void wm_im_set_cursor(int64_t id, int x, int y, int w_, int h_) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->im == NULL) {
    return;
  }
  GdkRectangle r;
  r.x = x;
  r.y = y;
  r.width = w_;
  r.height = h_;
  gtk_im_context_set_cursor_location(w->im, &r);
}

// 取一条已提交文本：返回字节数并把内容留在原处供逐字节读，
// 读完必须调 wm_im_commit_done 清零
int wm_im_commit_len(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].commit_len;
}

int wm_im_commit_byte(int64_t id, int index) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  WmWindow *w = &wm_windows[id];
  if (index < 0 || index >= w->commit_len) {
    return 0;
  }
  return (int)(guchar)w->commit[index];
}

void wm_im_commit_done(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  wm_windows[id].commit_len = 0;
  wm_windows[id].commit[0] = '\0';
}

// preedit（组合串）状态：仅供自绘显示，绝不计入文本状态
int wm_im_preedit_len(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].preedit_len;
}

int wm_im_preedit_byte(int64_t id, int index) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  WmWindow *w = &wm_windows[id];
  if (index < 0 || index >= w->preedit_len) {
    return 0;
  }
  return (int)(guchar)w->preedit[index];
}

int wm_im_preedit_caret(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].preedit_caret;
}

int wm_im_preedit_active(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].preedit_active;
}

void wm_wakeup(void) {
  g_main_context_wakeup(g_main_context_default());
}

/* ---- 全局快捷键（W20b）GTK 分支占位：X11 用 XGrabKey 排他注册、Xkb 映射
 * 加速键串，属 Linux 后端内部事务（按新口径不进路线图）；先给可编译的失败
 * 桩，让 MoonBit 层走「注册失败」语义化路径（返回 -1）。 */
int wm_hotkey_register(int mods, int vk) {
  (void)mods;
  (void)vk;
  return 0;
}

void wm_hotkey_unregister(int id) { (void)id; }

int wm_hotkey_poll(void) { return 0; }

/* ---- 原生菜单（W20a）GTK 分支占位：GTK 端的 GtkMenuBar 属 Linux 后端内部
 * 事务（按新口径不进路线图）；这里给可编译的失败桩，让 MoonBit 侧走「建菜单
 * 失败」语义化路径（句柄 0）。真 GTK 实现将来在 prebuild 的 -DWM_STUB_GTK 侧补。 */
int wm_menu_bar_new(void) { return 0; }
int wm_menu_new_sub(int parent, const char *title) {
  (void)parent;
  (void)title;
  return 0;
}
int wm_menu_add_item(int parent, const char *label, int kind, int role,
                     const char *acc, int checked) {
  (void)parent;
  (void)label;
  (void)kind;
  (void)role;
  (void)acc;
  (void)checked;
  return 0;
}
void wm_menu_apply(int64_t id, int bar) {
  (void)id;
  (void)bar;
}
int wm_menu_poll(void) { return 0; }

/* ---- 图标加载（W20f）GTK 分支占位：HICON 是 Win32 概念，托盘在 Linux 走 SNI
 * 的图标名/像素通道（yue/dbus/sni.mbt），不需要本层转换；给可编译的失败桩，
 * MoonBit 侧走「图标不可用」语义化路径（句柄 0）。 */
int wm_icon_from_bgra(const unsigned char *px, int w, int h) {
  (void)px;
  (void)w;
  (void)h;
  return 0;
}
int wm_icon_load_file(const char *path, int size) {
  (void)path;
  (void)size;
  return 0;
}
int wm_icon_from_png(const unsigned char *data, int len) {
  (void)data;
  (void)len;
  return 0;
}
void wm_icon_free(int slot) { (void)slot; }
int wm_icon_alive(void) { return 0; }
void *wm_icon_handle(int slot) {
  (void)slot;
  return NULL;
}

/* ---- 窗口增强（W20e）GTK 分支：改标题与无边框已实做（下面这两条）；
 * 图标（GdkPixbuf 的源与 Windows 的 HICON 句柄不同宗）、最小尺寸
 * （gtk_window_set_geometry_hints）、自绘标题栏拖拽（gtk_window_begin_move_drag
 * 要按下时的指针与按钮号，本栈还没把这条请求送到窗口层）仍是可编译的空实现，
 * MoonBit 侧调用无害、反读恒 0/false。 */
void wm_set_title(int64_t id, const char *title) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *win = &wm_windows[id];
  if (win->window == NULL || title == NULL) {
    return;
  }
  gtk_window_set_title(GTK_WINDOW(win->window), title);
}
void wm_set_icon(int64_t id, int icon_slot, int which) {
  (void)id;
  (void)icon_slot;
  (void)which;
}
void wm_set_min_size(int64_t id, int wmin, int hmin) {
  (void)id;
  (void)wmin;
  (void)hmin;
}
void wm_set_drag_rect(int64_t id, int x, int y, int w, int h) {
  (void)id;
  (void)x;
  (void)y;
  (void)w;
  (void)h;
}
void wm_set_borderless(int64_t id, int on) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *win = &wm_windows[id];
  if (win->window == NULL) {
    return;
  }
  gtk_window_set_decorated(GTK_WINDOW(win->window), on ? FALSE : TRUE);
}
void wm_get_min_size(int64_t id, int32_t *out_w, int32_t *out_h) {
  (void)id;
  if (out_w != NULL) {
    *out_w = 0;
  }
  if (out_h != NULL) {
    *out_h = 0;
  }
}
void wm_get_drag_rect(int64_t id, int32_t *x, int32_t *y, int32_t *w,
                      int32_t *h) {
  (void)id;
  if (x != NULL) {
    *x = 0;
  }
  if (y != NULL) {
    *y = 0;
  }
  if (w != NULL) {
    *w = 0;
  }
  if (h != NULL) {
    *h = 0;
  }
}
int wm_is_borderless(int64_t id) {
  (void)id;
  return 0;
}
int wm_window_title(int64_t id, char *out, int cap) {
  (void)id;
  if (out != NULL && cap > 0) {
    out[0] = '\0';
  }
  return 0;
}

/* ---- 系统托盘（W20c）GTK 分支占位：Linux 的托盘走纯 MoonBit 的 SNI 协议栈
 * （yue/dbus/sni.mbt，会话总线直连面板），不经 GTK 的 GtkStatusIcon（GTK3 里
 * 已弃用且面板不认）。这里给可编译的失败桩：supported 恒 0、建项恒 0，让
 * 门面走「SNI 优先、回退原生」里的原生分支判不可用，最终 user 拿到 SNI。 */
int wm_tray_supported(void) { return 0; }
int wm_tray_new(int icon_slot, const char *tip) {
  (void)icon_slot;
  (void)tip;
  return 0;
}
void wm_tray_set_tooltip(int slot, const char *tip) {
  (void)slot;
  (void)tip;
}
void wm_tray_set_icon(int slot, int icon_slot) {
  (void)slot;
  (void)icon_slot;
}
void wm_tray_set_menu(int slot, int menu_handle) {
  (void)slot;
  (void)menu_handle;
}
int wm_tray_popup(int slot) {
  (void)slot;
  return 0;
}
void wm_tray_remove(int slot) { (void)slot; }
int wm_tray_poll(int32_t *out_slot, int32_t *out_kind) {
  (void)out_slot;
  (void)out_kind;
  return 0;
}
int wm_tray_count(void) { return 0; }
int wm_tray_tooltip(int slot, char *out, int cap) {
  (void)slot;
  if (out != NULL && cap > 0) {
    out[0] = '\0';
  }
  return 0;
}
int wm_menu_popup_new(void) { return 0; }

/* ---- 桌面通知（W21a）GTK 分支占位：Linux 的通知走纯 MoonBit 的
 * org.freedesktop.Notifications（yue/dbus/notify.mbt），不经 GTK；
 * 可编译的失败桩让门面走 DBus 分支（supported 恒 0）。 */
int wm_notify_supported(void) { return 0; }
int wm_notify_send(int icon_slot, const char *title, const char *text,
                   int kind) {
  (void)icon_slot;
  (void)title;
  (void)text;
  (void)kind;
  return 0;
}
/* 任务栏进度（§6.3）占位：Linux 的任务栏进度另有 Unity LauncherEntry（DBus）
 * 路径、macOS 是 dock 徽标（NSDockTile），都归跨平台门面批；这里的失败桩让
 * 门面走 unsupported 降级，不断链接符号。 */
int wm_taskbar_supported(void) { return 0; }
int wm_taskbar_set_progress(int64_t id, int64_t value, int64_t total) {
  (void)id;
  (void)value;
  (void)total;
  return 0;
}
int wm_taskbar_set_state(int64_t id, int state) {
  (void)id;
  (void)state;
  return 0;
}
int wm_notify_update(int slot, const char *title, const char *text, int kind) {
  (void)slot;
  (void)title;
  (void)text;
  (void)kind;
  return 0;
}
void wm_notify_close(int slot) { (void)slot; }
int wm_notify_count(void) { return 0; }
int wm_notify_title(int slot, char *out, int cap) {
  (void)slot;
  if (out != NULL && cap > 0) {
    out[0] = '\0';
  }
  return 0;
}

/* ---- 原生消息框（W20d）GTK 分支：GtkMessageDialog 跑模态 run()，返回
 * GtkResponseType；MoonBit 侧返回值编号口径与 Win32 对齐（1 OK/2 CANCEL/
 * 3 ABORT/4 RETRY/5 IGNORE/6 YES/7 NO）。uType 里的图标/按钮段由 MoonBit 纯
 * 函数给出，这里反解成 GtkMessageType 与按钮集——各平台映射同一套语义常量，
 * 故两端的「错误 + 是/否/取消」落到各自的等价控件。 */
int wm_message_box(const char *title, const char *text, int utype) {
  GtkMessageType mt = GTK_MESSAGE_INFO;
  switch (utype & 0xF0) {
    case 0x10:
      mt = GTK_MESSAGE_ERROR;
      break;
    case 0x20:
      mt = GTK_MESSAGE_QUESTION;
      break;
    case 0x30:
      mt = GTK_MESSAGE_WARNING;
      break;
    default:
      mt = GTK_MESSAGE_INFO;
      break;
  }
  GtkButtonsType bt = GTK_BUTTONS_OK;
  switch (utype & 0xF) {
    case 0x1:
      bt = GTK_BUTTONS_OK_CANCEL;
      break;
    case 0x2:
      bt = GTK_BUTTONS_NONE; // 中止/重试/忽略：GTK 无常量表，自加按钮
      break;
    case 0x3:
      bt = GTK_BUTTONS_NONE; // 是/否/取消
      break;
    case 0x4:
      bt = GTK_BUTTONS_YES_NO;
      break;
    case 0x5:
      bt = GTK_BUTTONS_NONE; // 重试/取消
      break;
    default:
      bt = GTK_BUTTONS_OK;
      break;
  }
  GtkWidget *dlg =
      gtk_message_dialog_new(NULL, GTK_DIALOG_MODAL, mt, bt, "%s",
                             text != NULL ? text : "");
  if (title != NULL) {
    gtk_window_set_title(GTK_WINDOW(dlg), title);
  }
  // GTK_BUTTONS_NONE 的三组手工补按钮（response 用 Win32 编号语义）
  if ((utype & 0xF) == 0x2) {
    gtk_dialog_add_button(GTK_DIALOG(dlg), "_Abort", 3);
    gtk_dialog_add_button(GTK_DIALOG(dlg), "_Retry", 4);
    gtk_dialog_add_button(GTK_DIALOG(dlg), "_Ignore", 5);
  } else if ((utype & 0xF) == 0x3) {
    gtk_dialog_add_button(GTK_DIALOG(dlg), "_Yes", 6);
    gtk_dialog_add_button(GTK_DIALOG(dlg), "_No", 7);
    gtk_dialog_add_button(GTK_DIALOG(dlg), "_Cancel", 2);
  } else if ((utype & 0xF) == 0x5) {
    gtk_dialog_add_button(GTK_DIALOG(dlg), "_Retry", 4);
    gtk_dialog_add_button(GTK_DIALOG(dlg), "_Cancel", 2);
  }
  gint r = gtk_dialog_run(GTK_DIALOG(dlg));
  gtk_widget_destroy(dlg);
  return (int)r;
}

int64_t wm_now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}


/* ---- 系统深浅偏好与主色（主题跟随系统用） ----
 * 读 gsettings（GNOME 的 org.gnome.desktop.interface）：color-scheme 优先，
 * 老版本退回 gtk-theme 名字里的 "-dark"。字符串写进调用方给的缓冲并返回长度，
 * 0 表示读不到（非 GNOME 桌面、schema 不存在）——由 MoonBit 侧决定退路。
 * GSettings 对象建一次常驻（每拍轮询新建/销毁会反复走 dconf）。 */
typedef struct {
  GSettings *s;
  GSettingsSchema *schema;
} GsHolder;

static GsHolder gs_iface = { NULL, NULL };
static GsHolder gs_prefs = { NULL, NULL };

/* schema 存在才建 GSettings（非 GNOME 桌面上这些 schema 根本没有）；
 * 建好就常驻，每拍轮询不重复走 dconf。 */
static void gs_open(GsHolder *h, const char *name) {
  if (h->schema != NULL) {
    return;
  }
  GSettingsSchemaSource *src = g_settings_schema_source_get_default();
  if (src == NULL) {
    return;
  }
  h->schema = g_settings_schema_source_lookup(src, name, TRUE);
  if (h->schema != NULL) {
    h->s = g_settings_new(name);
  }
}

static int gs_read(GsHolder *h, const char *key, char *out, int cap) {
  if (out == NULL || cap < 1) {
    return 0;
  }
  out[0] = '\0';
  gs_open(h, h == &gs_iface ? "org.gnome.desktop.interface"
                            : "org.gnome.desktop.wm.preferences");
  if (h->s == NULL || !g_settings_schema_has_key(h->schema, key)) {
    return 0;
  }
  gchar *v = g_settings_get_string(h->s, key);
  if (v == NULL) {
    return 0;
  }
  int n = (int)strlen(v);
  if (n >= cap) {
    n = cap - 1;
  }
  memcpy(out, v, (size_t)n);
  out[n] = '\0';
  g_free(v);
  return n;
}

/* "dark" / "light" / ""（未知）。color-scheme 优先，老版本退回 gtk-theme 名。 */
int wm_sys_color_scheme(char *out, int cap) {
  if (out == NULL || cap < 1) {
    return 0;
  }
  out[0] = '\0';
  char buf[64];
  if (gs_read(&gs_iface, "color-scheme", buf, (int)sizeof(buf)) > 0) {
    if (strstr(buf, "dark") != NULL) {
      return (int)strlen(strcpy(out, "dark"));
    }
    if (strstr(buf, "light") != NULL) {
      return (int)strlen(strcpy(out, "light"));
    }
  }
  if (gs_read(&gs_iface, "gtk-theme", buf, (int)sizeof(buf)) > 0) {
    // 主题名里的 dark/light 大小写不一（Adwaita-dark、Orchis-Teal-Light-Compact）
    for (int i = 0; buf[i] != '\0'; i++) {
      buf[i] = (char)g_ascii_tolower(buf[i]);
    }
    if (strstr(buf, "dark") != NULL) {
      return (int)strlen(strcpy(out, "dark"));
    }
    if (strstr(buf, "light") != NULL) {
      return (int)strlen(strcpy(out, "light"));
    }
  }
  return 0;
}

/* "#rrggbb" / ""（系统没有主色概念）。GNOME 的 accent-color 是**名字**
 * （blue/teal…），查表转 hex；button-settings 里若直接写了十六进制就用它。 */
int wm_sys_accent(char *out, int cap) {
  if (out == NULL || cap < 1) {
    return 0;
  }
  out[0] = '\0';
  char buf[64];
  int n = gs_read(&gs_prefs, "button-settings", buf, (int)sizeof(buf));
  if (n > 0 && buf[0] == '#') {
    return (int)strlen(strcpy(out, buf));
  }
  if (gs_read(&gs_iface, "accent-color", buf, (int)sizeof(buf)) > 0) {
    struct Pair { const char *name; const char *hex; };
    static const struct Pair table[] = {
        { "blue", "#3584e4" },        { "teal", "#2190a4" },
        { "green", "#3a944a" },       { "yellow", "#c88800" },
        { "orange", "#ed5b00" },      { "red", "#da3450" },
        { "pink", "#d56199" },        { "purple", "#9141ac" },
        { "slate", "#6e7688" },       { "violet", "#7d6db8" },
        { "summer-blue", "#6cb5d6" }, { "forest-green", "#6d8762" },
        { "magenta", "#a1529c" },     { NULL, NULL },
    };
    for (int i = 0; table[i].name != NULL; i++) {
      if (strcmp(buf, table[i].name) == 0) {
        return (int)strlen(strcpy(out, table[i].hex));
      }
    }
  }
  return 0;
}

/* 本地时区的今天，打包成 年*10000 + 月*100 + 日（月/日 1 起始）。
 * 用日历时间 + localtime_r 走系统时区；失败返回 0，由 MoonBit 侧决定退路。 */
int64_t wm_local_date(void) {
  time_t now = time(NULL);
  struct tm tm_buf;
  if (now == (time_t)-1 || localtime_r(&now, &tm_buf) == NULL) {
    return 0;
  }
  return (int64_t)(tm_buf.tm_year + 1900) * 10000 +
         (int64_t)(tm_buf.tm_mon + 1) * 100 + (int64_t)tm_buf.tm_mday;
}

// ---------- 文件对话框（sys 线：yue/sys/dialog.mbt 的 GTK 端） ----------

#define WM_DLG_MAX 8
static GtkWidget *wm_dialogs[WM_DLG_MAX];
static int wm_dlg_accepted[WM_DLG_MAX]; // run 后用户确认过才允许取结果

static int64_t wm_dlg_put(GtkWidget *dlg) {
  for (int i = 0; i < WM_DLG_MAX; i++) {
    if (wm_dialogs[i] == NULL) {
      // 槽位号 +1 作句柄（0 保留为无效）
      wm_dialogs[i] = dlg;
      return (int64_t)(i + 1);
    }
  }
  gtk_widget_destroy(dlg);
  return 0;
}

static GtkWidget *wm_dlg_of(int64_t id) {
  if (id <= 0 || id > WM_DLG_MAX) {
    return NULL;
  }
  return wm_dialogs[id - 1];
}

static void wm_dlg_free(int64_t id) {
  if (id <= 0 || id > WM_DLG_MAX) {
    return;
  }
  wm_dlg_accepted[id - 1] = 0;
  if (wm_dialogs[id - 1] != NULL) {
    gtk_widget_destroy(wm_dialogs[id - 1]);
    wm_dialogs[id - 1] = NULL;
  }
}

/* 建 GtkFileChooserDialog：save=0 打开（OPEN）/1 保存（SAVE）。
 * 无显示连接（无头测试环境）时返回 0——句柄无效，各接口安全退化。 */
static int64_t wm_file_dialog_new(int save) {
  if (!gtk_init_check(NULL, NULL)) {
    return 0;
  }
  GtkWidget *dlg = gtk_file_chooser_dialog_new(
      save ? "保存文件" : "打开文件", NULL, save ? GTK_FILE_CHOOSER_ACTION_SAVE
                                                        : GTK_FILE_CHOOSER_ACTION_OPEN,
      "_取消", GTK_RESPONSE_CANCEL, save ? "_保存" : "_打开",
      GTK_RESPONSE_ACCEPT, NULL);
  if (dlg == NULL) {
    return 0;
  }
  return wm_dlg_put(dlg);
}

int64_t wm_file_open_dialog_new(void) { return wm_file_dialog_new(0); }

int64_t wm_file_save_dialog_new(void) { return wm_file_dialog_new(1); }

/* 选项位：1<<0 选文件夹 1<<1 多选 1<<2 显示隐藏。 */
void wm_file_dialog_set_options(int64_t id, int32_t options) {
  GtkFileChooser *fc = GTK_FILE_CHOOSER(wm_dlg_of(id));
  if (fc == NULL) {
    return;
  }
  if (options & 1) {
    gtk_file_chooser_set_action(fc, GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER);
  }
  gtk_file_chooser_set_select_multiple(fc, (options & 2) != 0);
  gtk_file_chooser_set_show_hidden(fc, (options & 4) != 0);
}

/* filters 打包："描述:扩展1,扩展2|描述2:扩展3"（'*' 匹配全部）。 */
void wm_file_dialog_set_filters(int64_t id, const char *filters) {
  GtkFileChooser *fc = GTK_FILE_CHOOSER(wm_dlg_of(id));
  if (fc == NULL || filters == NULL) {
    return;
  }
  // 清旧过滤器（GTK 无清空 API，逐个 remove）
  GSList *old = gtk_file_chooser_list_filters(fc);
  for (GSList *p = old; p != NULL; p = p->next) {
    gtk_file_chooser_remove_filter(fc, GTK_FILE_FILTER(p->data));
  }
  if (old != NULL) {
    g_slist_free(old);
  }
  const char *pos = filters;
  while (*pos != '\0') {
    const char *bar = strchr(pos, '|');
    size_t glen = bar != NULL ? (size_t)(bar - pos) : strlen(pos);
    char group[256];
    if (glen >= sizeof(group)) {
      glen = sizeof(group) - 1;
    }
    memcpy(group, pos, glen);
    group[glen] = '\0';
    const char *colon = strchr(group, ':');
    if (colon != NULL) {
      GtkFileFilter *f = gtk_file_filter_new();
      char desc[128];
      size_t dl = (size_t)(colon - group);
      if (dl >= sizeof(desc)) {
        dl = sizeof(desc) - 1;
      }
      memcpy(desc, group, dl);
      desc[dl] = '\0';
      gtk_file_filter_set_name(f, desc);
      const char *ep = colon + 1;
      while (*ep != '\0') {
        const char *comma = strchr(ep, ',');
        size_t el = comma != NULL ? (size_t)(comma - ep) : strlen(ep);
        char pat[64];
        if (el >= sizeof(pat)) {
          el = sizeof(pat) - 1;
        }
        memcpy(pat, ep, el);
        pat[el] = '\0';
        if (strcmp(pat, "*") == 0) {
          gtk_file_filter_add_pattern(f, "*");
        } else {
          char dotpat[68];
          snprintf(dotpat, sizeof(dotpat), "*.%s", pat);
          gtk_file_filter_add_pattern(f, dotpat);
        }
        ep = comma != NULL ? comma + 1 : ep + el;
      }
      gtk_file_chooser_add_filter(fc, f);
    }
    pos = bar != NULL ? bar + 1 : pos + glen;
  }
}

void wm_file_dialog_set_folder(int64_t id, const char *folder) {
  GtkFileChooser *fc = GTK_FILE_CHOOSER(wm_dlg_of(id));
  if (fc != NULL && folder != NULL) {
    gtk_file_chooser_set_current_folder_uri(fc, folder);
  }
}

void wm_file_dialog_set_filename(int64_t id, const char *filename) {
  GtkFileChooser *fc = GTK_FILE_CHOOSER(wm_dlg_of(id));
  if (fc != NULL && filename != NULL) {
    gtk_file_chooser_set_current_name(fc, filename);
  }
}

/* 模态运行：parent_id 是 wm 窗口槽 id（0 = 无父窗口）。返回 1=确认。 */
int32_t wm_file_dialog_run_for_window(int64_t id, int64_t parent_id) {
  GtkWidget *dlg = wm_dlg_of(id);
  if (dlg == NULL) {
    return 0;
  }
  GtkWidget *parent = parent_id > 0 && parent_id <= WM_MAX_WINDOWS
                          ? wm_windows[(int)parent_id - 1].window
                          : NULL;
  if (parent != NULL) {
    gtk_window_set_transient_for(GTK_WINDOW(dlg), GTK_WINDOW(parent));
  }
  gint resp = gtk_dialog_run(GTK_DIALOG(dlg));
  wm_dlg_accepted[id - 1] = resp == GTK_RESPONSE_ACCEPT;
  return resp == GTK_RESPONSE_ACCEPT ? 1 : 0;
}

/* 用户选中的路径（未确认/多选时取首个；空串 = 无）。
 * 只在 run 后用户确认过才查——未 run 的 chooser 内部文件系统模型
 * 未初始化，get_uri 会段错误（本机实测），提前返回空串。 */
void *wm_file_dialog_get_result(int64_t id) {
  GtkFileChooser *fc = GTK_FILE_CHOOSER(wm_dlg_of(id));
  if (fc == NULL || !wm_dlg_accepted[id - 1]) {
    return moonbit_make_bytes(0, 0);
  }
  gchar *uri = gtk_file_chooser_get_uri(fc);
  if (uri == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  // file:// 前缀剥除（与 master 的 FilePath 语义一致，返回本地路径）
  const char *p = uri;
  if (g_str_has_prefix(p, "file://")) {
    p += 7;
  }
  size_t len = strlen(p);
  void *out = moonbit_make_bytes((int)len, 0);
  if (len > 0) {
    memcpy(out, p, len);
  }
  g_free(uri);
  return out;
}

/* ---------- 剪贴板（sys/clipboard.mbt 的 Linux 落点）----------
 * GtkClipboard 直接用：本归档已链 GTK3，sys 的 extern 直链 win 桩与
 * `wm_file_*` 是同一条先例。没跑过 gtk_init 的纯命令行消费者（无头测试）
 * 探测给 0，MoonBit 侧退回命令线 xclip——不在这里替宿主 gdk_init。 */
int wm_clipboard_available(void) {
  return gdk_display_get_default() != NULL ? 1 : 0;
}

// 读剪贴板文本（UTF-8）：没有显示服务或没有文本时 *ok=0、给空 Bytes。
void *wm_clipboard_get_text(int32_t *ok) {
  *ok = 0;
  if (!wm_clipboard_available()) {
    return moonbit_make_bytes(0, 0);
  }
  GtkClipboard *cb = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
  gchar *t = gtk_clipboard_wait_for_text(cb);
  if (t == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  size_t len = strlen(t);
  void *out = moonbit_make_bytes((int)len, 0);
  if (len > 0) {
    memcpy(out, t, len);
  }
  g_free(t);
  *ok = 1;
  return out;
}

// 写剪贴板。set_text 只登记本进程为选区主人，所以紧跟一次 store 把内容
// 交给会话里的剪贴板管理器——少了它，应用退出后别处就再也读不到。
int wm_clipboard_set_text(const char *text) {
  if (text == NULL || !wm_clipboard_available()) {
    return 0;
  }
  GtkClipboard *cb = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
  gtk_clipboard_set_text(cb, text, -1);
  gtk_clipboard_store(cb);
  return 1;
}

/* 关闭并释放对话框（run 之后调用；未 run 过也能安全释放）。 */
void wm_file_dialog_destroy(int64_t id) { wm_dlg_free(id); }

#elif defined(WM_STUB_MAC)

// ---------------- macOS 后端（Cocoa，prebuild 带 -x objective-c 专编） ----------------
//
// 这一支是 Objective-C：本文件由 scripts/prebuild.py 的 Darwin 分支带
// `-x objective-c -fobjc-arc -DWM_STUB_MAC` 编成 build/libyue_win_stub_mac.a，
// 经 link_flags 传给 win/sys/web 三个包。moon 的 native-stub 在 macOS 上编本
// 文件时不带这个宏、且落不进 `!defined(__linux__) && !defined(__APPLE__)`
// 那条占位分支，于是编出空翻译单元——与 Linux 的 GTK 完全同一套路（防双定义）。
//
// 三条与 GTK/Win32 支不同的形态约束（都写进 docs/zh/adaptation.md）：
// - **循环归 MoonBit**：不自带 `[NSApp run]`。等待用 `nextEventMatchingMask:
//   untilDate:`（AppKit 自己的阻塞取事件），跑事件用 `sendEvent:` 派给
//   NSView 子类；跨线程唤醒走 `postEvent:` 投一个 NSApplicationDefined 事件，
//   取到它就只当「醒了」、不进队列。
// - **坐标与尺度**：整栈物理像素口径，Cocoa 侧一律点（point）。点↔像素的
//   比例取窗口所在屏的 backingScaleFactor，进出边界各换算一次。绘制区视图
//   **不设 isFlipped**：非翻转视图里 `CGContextDrawImage` 的图像第一行正好
//   落在矩形顶边（与本栈 Bitmap 同向），鼠标 y 用 `bounds.height - p.y` 换。
// - **菜单/托盘/通知是 App 级**：NSMenu 挂 `[NSApp setMainMenu:]`（macOS 的
//   菜单条属于应用不属于窗口），NSStatusItem 属于状态栏。

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>

// 这两个 setter 在新 SDK（macOS 26 的构建机）上不再公开声明，clang 直接报
// 「no visible @interface / no known instance method」，而旧 SDK 上它们是真实
// 存在的。这里只给 NSObject 做 informal 声明让 selector 在编译期可见，调用点
// 一律先 respondsToSelector: 再发：SDK 真没有这一口时退回默认行为，不硬写。
@interface NSObject (WMAppKitOptionalSetters)
- (void)setCanShowHiddenFiles:(BOOL)flag;
- (void)setSendActionOn:(NSUInteger)mask;
@end

#define WM_MAX_WINDOWS 32
#define WM_MAX_SURFACES 64
#define WM_MAX_MENUS 128
#define WM_MAX_ICONS 32
#define WM_MAX_TRAYS 16
#define WM_TRAY_EV_MAX 32
#define WM_DLG_MAX 16
#define WM_MENU_CMD_BASE 1000
#define WM_MENU_CMD_MAX 2048

// 唤醒事件的标记值（NSApplicationDefined 的 data1，别的来源给不到这个数）
#define WM_WAKE_TOKEN 0x77416BUL

typedef struct {
  uint32_t keysym;
  uint32_t code; // 0 键按下 1 键释放 2 按钮按下 3 按钮释放 4 指针移动 5 滚轮
  int32_t x;
  int32_t y;
  int32_t dx;
  int32_t dy;
  uint32_t mods;
} WmEv;

@class WMState;
@class WMView;

// 绘制区视图：收键鼠、实现 NSTextInputClient（输入法通道）、贴像素。
@interface WMView : NSView <NSTextInputClient> {
@public
  int vsid; // 槽号，一切状态经 wm_state(vsid) 取（不持对象指针，免得拆窗后悬垂）
}
- (void)setSlot:(int)sid;
@end

// 每窗状态：ARC 管理的对象，槽表 strong 引用；拆窗时置 nil 一起回收。
@interface WMState : NSObject <NSWindowDelegate> {
@public
  int sid;
  int need_draw;
  int resized;
  int closing;
  int focus_lost;
  int width;  // 物理像素
  int height;
  WmEv evs[64];
  WmEv last;
  int ev_head;
  int ev_count;
  char commit[256];
  int commit_len;
  char preedit[256];
  int preedit_len;
  int preedit_caret;
  int preedit_active;
  int im_cx; // 输入光标矩形（物理像素，wm_im_set_cursor 落点）
  int im_cy;
  int im_cw;
  int im_ch;
  int cursor_kind; // 0 默认 1 手 2 文本 3 横向 4 纵向
  int min_w;
  int min_h;
  int drag_x;
  int drag_y;
  int drag_w;
  int drag_h;
  int borderless;
  unsigned char *backing; // 本层拥有的帧缓冲（present 拷进来，drawRect 贴它）
  int backing_w;
  int backing_h;
  size_t backing_cap;
}
@property(nonatomic, strong) NSWindow *win;
@property(nonatomic, strong) WMView *view;
- (void)pushEv:(const WmEv *)e;
- (void)syncSize;
@end

static WMState *wm_windows[WM_MAX_WINDOWS];
static NSView *wm_surf_views[WM_MAX_SURFACES];
static int64_t wm_surf_win[WM_MAX_SURFACES];
static int wm_surf_kind[WM_MAX_SURFACES];
static int wm_surf_x[WM_MAX_SURFACES];
static int wm_surf_y[WM_MAX_SURFACES];
static int wm_surf_w[WM_MAX_SURFACES];
static int wm_surf_h[WM_MAX_SURFACES];

// ---- 小工具 ----

void wm_pump(void); // wm_show 里要先跑一轮就绪事件，实现在下方

static WMState *wm_state(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return nil;
  }
  WMState *s = wm_windows[(int)id];
  return s.view != nil ? s : nil; // 槽已拆：与 GTK 的 area==NULL 同判据
}

static WMState *wm_state_alive(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return nil;
  }
  return wm_windows[(int)id];
}

static NSString *wm_str(const char *s) {
  if (s == NULL) {
    return nil;
  }
  return [[NSString alloc] initWithBytes:s
                                  length:strlen(s)
                                encoding:NSUTF8StringEncoding];
}

// UTF-8 字节 → moonbit 的 Bytes 对象（返回给 MoonBit 的文本都走这条）
static void *wm_bytes(const char *s) {
  size_t len = s != NULL ? strlen(s) : 0;
  void *out = moonbit_make_bytes((int)len, 0);
  if (len > 0 && out != NULL) {
    memcpy(out, s, len);
  }
  return out;
}

static int wm_clamp_cap(char *out, int cap, const char *s) {
  if (out == NULL || cap < 1) {
    return 0;
  }
  size_t n = s != NULL ? strlen(s) : 0;
  if (n >= (size_t)cap) {
    n = (size_t)(cap - 1);
  }
  if (n > 0 && s != NULL) {
    memcpy(out, s, n);
  }
  out[n] = '\0';
  return (int)n;
}

// 窗口所在屏的点↔像素比例（无窗退回主屏）
static CGFloat wm_scale_of(WMState *s) {
  // win/view 是 ObjC 属性（ARC 管理的对象引用），只能用点取，不能 `->`——
  // 桩里其余 C 字段是 @public 裸字段，两种取法在同一个函数里并存，容易看串
  NSScreen *sc = (s != nil && s.win != nil) ? [s.win screen] : nil;
  if (sc == nil) {
    sc = [NSScreen mainScreen];
  }
  CGFloat f = sc != nil ? [sc backingScaleFactor] : 1.0;
  return f > 0 ? f : 1.0;
}

// 主屏的 Cocoa frame（屏幕坐标换算的基准：Cocoa 是 y 向上、主屏原点在左下）
static NSRect wm_primary_frame(void) {
  NSArray<NSScreen *> *all = [NSScreen screens];
  return all.count > 0 ? [[all firstObject] frame]
                       : NSMakeRect(0, 0, 1920, 1080);
}

// 修饰位必须与 core/keys.mbt 的 MOD_* 一致（1 shift / 2 ctrl / 4 alt / 8 meta）。
// mac 的主修饰是 Command，按 core/win/hotkey.mbt 的口径（is_mac 时 CmdOrCtrl → 8）
// 映射到 META；Control 键本身给 CTRL，Option 给 ALT。
static uint32_t wm_cocoa_mods(NSUInteger flags) {
  uint32_t m = 0;
  if ((flags & NSEventModifierFlagShift) != 0) {
    m |= 1u;
  }
  if ((flags & NSEventModifierFlagControl) != 0) {
    m |= 2u;
  }
  if ((flags & NSEventModifierFlagOption) != 0) {
    m |= 4u;
  }
  if ((flags & NSEventModifierFlagCommand) != 0) {
    m |= 8u;
  }
  return m;
}

// kVK_*（硬件键位）→ X11 keysym。表与 core/input_map.mbt 的 mac_vk_to_keysym
// 同值同源（那份是纯函数、有回归钉住），字母/数字不在这里——它们由事件带的
// Unicode 文本给（键盘布局归系统解析）。
static uint32_t wm_mac_vk_keysym(uint16_t code) {
  switch (code) {
    case 36: return 65293u; // kVK_Return → XK_Return
    case 48: return 65289u; // kVK_Tab
    case 49: return 32u;    // kVK_Space
    case 51: return 65288u; // kVK_Delete（退格）
    case 53: return 65307u; // kVK_Escape
    case 76: return 65421u; // KeypadEnter
    case 65: return 65454u; // KeypadDecimal
    case 67: return 65450u; // KeypadMultiply
    case 69: return 65451u; // KeypadPlus
    case 78: return 65453u; // KeypadMinus
    case 75: return 65455u; // KeypadDivide
    case 117: return 65535u; // ForwardDelete → XK_Delete
    case 115: return 65360u; // Home
    case 119: return 65367u; // End
    case 116: return 65365u; // PageUp
    case 121: return 65366u; // PageDown
    case 123: return 65361u; // Left
    case 124: return 65363u; // Right
    case 125: return 65364u; // Down
    case 126: return 65362u; // Up
    case 122: return 65470u; // F1
    case 120: return 65471u;
    case 99: return 65472u;
    case 118: return 65473u;
    case 96: return 65474u;
    case 97: return 65475u;
    case 98: return 65476u;
    case 100: return 65477u;
    case 101: return 65478u;
    case 109: return 65479u;
    case 103: return 65480u;
    case 111: return 65481u; // F12
    default: return 0u;
  }
}

// 事件 → keysym：特判表优先，其余取 charactersIgnoringModifiers 的码点
// （X11 的 Latin-1 段 keysym == 码点，段外按 XK_UNICODE 的 0x01000000+cp）。
static uint32_t wm_keysym_of(NSEvent *ev) {
  uint32_t ks = wm_mac_vk_keysym([ev keyCode]);
  if (ks != 0u) {
    return ks;
  }
  NSString *chars = [ev charactersIgnoringModifiers];
  if ([chars length] == 0u) {
    return 0u;
  }
  unichar c = [chars characterAtIndex:0u];
  if (c == 0x1B) {
    return 65307u; // Escape 在 characters 里是控制字符，按 keysym 给
  }
  if (c < 32u) {
    return 0u; // 其余控制字符：不是可打印键
  }
  if (c < 0x100u) {
    return (uint32_t)c;
  }
  return 0x01000000u + (uint32_t)c;
}

// NSStatusItem / NSMenu / NSImage / 热键的表在下方各自段落里声明。

@implementation WMState
- (void)pushEv:(const WmEv *)e {
  // 指针移动先合并（与 GTK/Win32 支同一条：位置是状态不是流水，只留最新一条）。
  if (e->code == 4u && ev_count > 0) {
    int prev = (ev_head + ev_count - 1) % 64;
    if (evs[prev].code == 4u) {
      evs[prev] = *e;
      return;
    }
  }
  if (ev_count >= 64) {
    return; // 满了丢弃而不是覆盖：宁可丢一个事件,不能把 FIFO 打乱
  }
  int slot = (ev_head + ev_count) % 64;
  evs[slot] = *e;
  ev_count++;
}

// 尺寸同步：从 contentView 的边界点尺寸 × 所在屏缩放算出物理像素。
// 全屏切换通知也走这里（那条同样带非空 note，但复用逻辑比 nil 参数干净）。
- (void)syncSize {
  if (self.view == nil) {
    return;
  }
  CGFloat sc = wm_scale_of(self);
  NSSize pts = [[self.view window] contentView].bounds.size;
  self->width = (int)(pts.width * sc + 0.5);
  self->height = (int)(pts.height * sc + 0.5);
  self->resized = 1;
  self->need_draw = 1;
  [self.view updateTrackingAreas];
}

- (void)windowDidResize:(NSNotification *)note {
  (void)note;
  [self syncSize];
}

- (void)windowDidExitFullScreen:(NSNotification *)note {
  (void)note;
  [self syncSize];
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
  (void)sender;
  self->closing = 1; // 不在这里销毁：拆对象由 MoonBit 侧看到事件 3 后调 wm_close
  return NO;
}

- (void)dealloc {
  if (self->backing != NULL) {
    free(self->backing);
    self->backing = NULL;
    self->backing_cap = 0;
  }
}
@end

@implementation WMView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self != nil) {
    vsid = 0;
  }
  return self;
}

- (void)setSlot:(int)sid {
  vsid = sid;
}

- (BOOL)acceptsFirstResponder {
  return YES;
}

// 不设 isFlipped：见文件头「坐标与尺度」。绘制与鼠标换算都按非翻转视图来。

- (void)updateTrackingAreas {
  [super updateTrackingAreas];
  // 自绘 UI 要 hover，就得自己声明 tracking area（GTK 侧是 motion mask 申请）
  for (NSTrackingArea *old in self.trackingAreas) {
    [self removeTrackingArea:old];
  }
  NSTrackingArea *ta = [[NSTrackingArea alloc]
      initWithRect:self.bounds
           options:(NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited |
                    NSTrackingActiveAlways | NSTrackingInVisibleRect)
             owner:self
           userInfo:nil];
  [self addTrackingArea:ta];
}

- (void)resetCursorRects {
  [super resetCursorRects];
  WMState *s = wm_state(vsid);
  if (s == nil) {
    return;
  }
  NSCursor *cur = nil;
  switch (s->cursor_kind) {
    case 1: cur = [NSCursor pointingHandCursor]; break;
    case 2: cur = [NSCursor IBeamCursor]; break;
    case 3: cur = [NSCursor resizeLeftRightCursor]; break;
    case 4: cur = [NSCursor resizeUpDownCursor]; break;
    default: cur = [NSCursor arrowCursor]; break;
  }
  [self addCursorRect:self.bounds cursor:cur];
}

// 事件 → 队列。坐标：视图内点坐标（左下原点）→ 本栈的左上原点物理像素。
- (void)pushPointer:(NSEvent *)ev code:(uint32_t)code button:(int32_t)button {
  WMState *s = wm_state(vsid);
  if (s == nil) {
    return;
  }
  CGFloat sc = wm_scale_of(s);
  NSPoint p = [self convertPoint:[ev locationInWindow] fromView:nil];
  WmEv e;
  memset(&e, 0, sizeof(e));
  e.code = code;
  e.x = (int32_t)(p.x * sc + 0.5);
  e.y = (int32_t)((self.bounds.size.height - p.y) * sc + 0.5);
  e.dx = button;
  e.mods = wm_cocoa_mods([ev modifierFlags]);
  [s pushEv:&e];
}

// 自绘标题栏的拖拽区：落在区内就交系统拖窗，并且**不入队**按下事件
// （与 Win32 支的 WM_NCHITTEST → HTCAPTION 同语义：应用看不到这一击）。
- (BOOL)tryDragRect:(NSEvent *)ev {
  WMState *s = wm_state(vsid);
  if (s == nil || s->drag_w <= 0 || s->drag_h <= 0) {
    return NO;
  }
  CGFloat sc = wm_scale_of(s);
  NSPoint p = [self convertPoint:[ev locationInWindow] fromView:nil];
  int px = (int)(p.x * sc + 0.5);
  int py = (int)((self.bounds.size.height - p.y) * sc + 0.5);
  if (px < s->drag_x || py < s->drag_y || px >= s->drag_x + s->drag_w ||
      py >= s->drag_y + s->drag_h) {
    return NO;
  }
  [[self window] performWindowDragWithEvent:ev];
  return YES;
}

- (void)mouseDown:(NSEvent *)ev {
  if ([self tryDragRect:ev]) {
    return;
  }
  [self pushPointer:ev code:2u button:1];
}

- (void)mouseUp:(NSEvent *)ev {
  [self pushPointer:ev code:3u button:1];
}

- (void)rightMouseDown:(NSEvent *)ev {
  [self pushPointer:ev code:2u button:3];
}

- (void)rightMouseUp:(NSEvent *)ev {
  [self pushPointer:ev code:3u button:3];
}

- (void)otherMouseDown:(NSEvent *)ev {
  // NSMouseEvent.buttonNumber：0 左 1 右 2 中 → 本栈按钮号 1/3/2
  NSInteger n = [ev buttonNumber];
  [self pushPointer:ev code:2u button:(n == 1 ? 3 : (n == 2 ? 2 : 1))];
}

- (void)otherMouseUp:(NSEvent *)ev {
  NSInteger n = [ev buttonNumber];
  [self pushPointer:ev code:3u button:(n == 1 ? 3 : (n == 2 ? 2 : 1))];
}

- (void)mouseMoved:(NSEvent *)ev {
  [self pushPointer:ev code:4u button:0];
}

- (void)mouseDragged:(NSEvent *)ev {
  [self pushPointer:ev code:4u button:0];
}

- (void)rightMouseDragged:(NSEvent *)ev {
  [self pushPointer:ev code:4u button:0];
}

- (void)scrollWheel:(NSEvent *)ev {
  WMState *s = wm_state(vsid);
  if (s == nil) {
    return;
  }
  CGFloat sc = wm_scale_of(s);
  NSPoint p = [self convertPoint:[ev locationInWindow] fromView:nil];
  WmEv e;
  memset(&e, 0, sizeof(e));
  e.code = 5u;
  e.x = (int32_t)(p.x * sc + 0.5);
  e.y = (int32_t)((self.bounds.size.height - p.y) * sc + 0.5);
  // deltaY 单位是点、正数=向上滚；本栈给「每档 ±1」的方向（与 GTK 支同口径）
  e.dy = [ev deltaY] > 0 ? 1 : ([ev deltaY] < 0 ? -1 : 0);
  e.dx = [ev deltaX] > 0 ? -1 : ([ev deltaX] < 0 ? 1 : 0);
  e.mods = wm_cocoa_mods([ev modifierFlags]);
  [s pushEv:&e];
}

- (void)keyDown:(NSEvent *)ev {
  NSTextInputContext *ic = [self inputContext];
  if (ic != nil && [ic handleEvent:ev]) {
    // 输入法吃掉了：不推按键，改由 insertText:/setMarkedText: 通道回报
    WMState *s = wm_state(vsid);
    if (s != nil) {
      s->need_draw = 1;
    }
    [self setNeedsDisplay:YES];
    return;
  }
  WMState *s = wm_state(vsid);
  if (s == nil) {
    return;
  }
  WmEv e;
  memset(&e, 0, sizeof(e));
  e.code = 0u;
  e.keysym = wm_keysym_of(ev);
  e.mods = wm_cocoa_mods([ev modifierFlags]);
  [s pushEv:&e];
}

- (void)keyUp:(NSEvent *)ev {
  WMState *s = wm_state(vsid);
  if (s == nil) {
    return;
  }
  WmEv e;
  memset(&e, 0, sizeof(e));
  e.code = 1u;
  e.keysym = wm_keysym_of(ev);
  e.mods = wm_cocoa_mods([ev modifierFlags]);
  [s pushEv:&e];
}

- (void)flagsChanged:(NSEvent *)ev {
  // 修饰键自身的按下/释放： keycode 查表给 keysym，让上层能识别「只按了 Cmd」
  WMState *s = wm_state(vsid);
  if (s == nil) {
    return;
  }
  WmEv e;
  memset(&e, 0, sizeof(e));
  e.mods = wm_cocoa_mods([ev modifierFlags]);
  uint32_t ks = 0u;
  // 修饰键自身的按下/释放：kVK 值与 X11 keysym 都按 Events.h / Xutil 的表给。
  // 按下还是释放看**这一个键自己的位**在不在 flags 里——不能拿合成后的 mods
  // 判（按住 Cmd 再松开 Shift，mods 仍非零，按 mods 判会把释放报成按下）。
  NSUInteger flags = [ev modifierFlags];
  NSUInteger own = 0;
  switch ([ev keyCode]) {
    case 0x37: ks = 65515u; own = NSEventModifierFlagCommand; break; // Super_L
    case 0x36: ks = 65516u; own = NSEventModifierFlagCommand; break; // Super_R
    case 0x38: ks = 65505u; own = NSEventModifierFlagShift; break;   // Shift_L
    case 0x3C: ks = 65506u; own = NSEventModifierFlagShift; break;   // Shift_R
    case 0x3B: ks = 65507u; own = NSEventModifierFlagControl; break; // Control_L
    case 0x3E: ks = 65508u; own = NSEventModifierFlagControl; break; // Control_R
    case 0x3A: ks = 65406u; own = NSEventModifierFlagOption; break;  // Alt_L
    case 0x3D: ks = 65407u; own = NSEventModifierFlagOption; break;  // Alt_R
    default: break;
  }
  if (ks == 0u) {
    return;
  }
  e.keysym = ks;
  e.code = (flags & own) != 0 ? 0u : 1u; // 自己的位还亮着 = 按下，灭了 = 释放
  [s pushEv:&e];
}

// ---- NSTextInputClient（输入法通道）----
//
// 本栈不持文档，所以「选区/已有文本」一类查询按空答复；实际要用的两件事
// 都在这里落地：组合串（setMarkedText → preedit）与上屏文本
// （insertText → commit），口径与 GTK 支一样是 UTF-8 字节 + 字节偏移光标。

- (BOOL)hasMarkedText {
  WMState *s = wm_state(vsid);
  return s != nil && s->preedit_len > 0;
}

- (NSRange)markedRange {
  WMState *s = wm_state(vsid);
  if (s == nil || s->preedit_len == 0) {
    return NSMakeRange(NSNotFound, 0);
  }
  return NSMakeRange(0, s->preedit_len);
}

- (NSRange)selectedRange {
  return NSMakeRange(NSNotFound, 0);
}

- (NSAttributedString *)attributedSubstringForProposedRange:(NSRange)range
                                                 actualRange:(NSRangePointer)actualRange {
  (void)range;
  (void)actualRange;
  return nil; // 无文档可查：输入法的「取周围文本」按空处理
}

- (NSUInteger)characterIndexForPoint:(NSPoint)point {
  (void)point;
  return NSNotFound; // 无文档模型：给不到字符索引
}

// 候选窗落点：wm_im_set_cursor 给的像素矩形换算成屏幕坐标点
- (NSRect)firstRectForCharacterRange:(NSRange)range
                         actualRange:(NSRangePointer)actualRange {
  (void)range;
  (void)actualRange;
  WMState *s = wm_state(vsid);
  if (s == nil || self.window == nil) {
    return NSZeroRect;
  }
  CGFloat sc = wm_scale_of(s);
  NSRect r = [self convertRect:NSMakeRect(s->im_cx / sc,
                                           self.bounds.size.height -
                                               (s->im_cy + s->im_ch) / sc,
                                           s->im_cw / sc, s->im_ch / sc)
                        toView:nil];
  return [[self window] convertRectToScreen:r];
}

- (void)insertText:(id)str replacementRange:(NSRange)replacementRange {
  (void)replacementRange;
  WMState *s = wm_state(vsid);
  if (s == nil) {
    return;
  }
  NSString *text = nil;
  if ([str isKindOfClass:[NSAttributedString class]]) {
    text = [(NSAttributedString *)str string];
  } else if ([str isKindOfClass:[NSString class]]) {
    text = (NSString *)str;
  }
  if (text == nil) {
    return;
  }
  const char *utf8 = [text UTF8String];
  int n = 0;
  if (utf8 != NULL) {
    while (utf8[n] != '\0' && n < 255) {
      s->commit[n] = utf8[n];
      n++;
    }
  }
  s->commit[n] = '\0';
  s->commit_len = n;
  s->preedit_active = 0;
  s->preedit_len = 0;
  s->preedit[0] = '\0';
  s->need_draw = 1;
}

- (void)doCommandBySelector:(SEL)selector {
  (void)selector; // 组合中的回车/退格由输入法定，本层不额外投键（与 GTK 一致）
}

- (void)setMarkedText:(id)markedText
                 selectedRange:(NSRange)selRange
            replacementRange:(NSRange)replacementRange {
  (void)replacementRange; // 本层没有选区可替换：组合串总是整体覆写 preedit
  WMState *s = wm_state(vsid);
  if (s == nil) {
    return;
  }
  NSString *str = nil;
  if ([markedText isKindOfClass:[NSAttributedString class]]) {
    str = [(NSAttributedString *)markedText string];
  } else if ([markedText isKindOfClass:[NSString class]]) {
    str = (NSString *)markedText;
  }
  if (str == nil) {
    s->preedit_len = 0;
    s->preedit[0] = '\0';
    s->preedit_active = 1;
    s->need_draw = 1;
    return;
  }
  const char *utf8 = [str UTF8String];
  int n = 0;
  if (utf8 != NULL) {
    while (utf8[n] != '\0' && n < 255) {
      s->preedit[n] = utf8[n];
      n++;
    }
  }
  s->preedit[n] = '\0';
  s->preedit_len = n;
  s->preedit_active = 1;
  // selRange.location 是 UTF-16 单元位置，MoonBit 侧按 UTF-8 字节管光标，
  // 这里换算成字节偏移（与 GTK 支的 caret 同口径）
  NSUInteger cut = selRange.location;
  if (cut > [str length]) {
    cut = [str length];
  }
  if (cut > 0) {
    NSString *head = [str substringToIndex:cut];
    long bl = (long)[head lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    s->preedit_caret = bl > n ? n : (bl < 0 ? 0 : (int)bl);
  } else {
    s->preedit_caret = 0;
  }
  s->need_draw = 1;
}

- (void)unmarkText {
  WMState *s = wm_state(vsid);
  if (s == nil) {
    return;
  }
  s->preedit_active = 0;
  s->preedit_len = 0;
  s->preedit[0] = '\0';
  s->need_draw = 1;
}

- (NSArray *)validAttributesForMarkedText {
  return @[];
}

- (BOOL)resignFirstResponder {
  WMState *s = wm_state(vsid);
  if (s != nil && [self.window isKeyWindow]) {
    // 焦点还在本窗内转移（用户点了本窗的网页子件）→ 浮层「点外收起」
    s->focus_lost = 1;
  }
  if (s != nil) {
    s->preedit_active = 0;
    s->preedit_len = 0;
    s->preedit[0] = '\0';
  }
  return [super resignFirstResponder];
}

- (void)drawRect:(NSRect)dirtyRect {
  (void)dirtyRect;
  WMState *s = wm_state(vsid);
  if (s == nil) {
    return;
  }
  if (s->backing == NULL || s->backing_w < 1 || s->backing_h < 1) {
    s->need_draw = 1; // 还没有帧可贴：请 MoonBit 画第一帧
    return;
  }
  NSGraphicsContext *gc = [NSGraphicsContext currentContext];
  CGContextRef ctx = [gc CGContext];
  if (ctx == NULL) {
    s->need_draw = 1;
    return;
  }
  size_t len = (size_t)s->backing_w * (size_t)s->backing_h * 4u;
  CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
  CGDataProviderRef dp = CGDataProviderCreateWithData(NULL, s->backing, len, NULL);
  CGImageRef img = NULL;
  if (dp != NULL) {
    img = CGImageCreate(s->backing_w, s->backing_h, 8, 32,
                        (size_t)s->backing_w * 4u, cs,
                        (CGBitmapInfo)(kCGImageAlphaPremultipliedFirst |
                                       kCGBitmapByteOrder32Little),
                        dp, NULL, kCGInterpolationNone,
                        kCGRenderingIntentDefault);
  }
  if (img != NULL) {
    CGContextDrawImage(ctx, self.bounds, img);
    CGImageRelease(img);
  } else {
    s->need_draw = 1;
  }
  if (dp != NULL) {
    CGDataProviderRelease(dp);
  }
  if (cs != NULL) {
    CGColorSpaceRelease(cs);
  }
}
@end

// 应用级委托：最后一扇窗关掉**不能**终结进程（循环归 MoonBit）。
@interface WMAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation WMAppDelegate
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)sender {
  (void)sender;
  return NO;
}
@end

static WMAppDelegate *wm_app_delegate = nil;

int wm_init(void) {
  @autoreleasepool {
    // 手工跑循环（不用 [NSApp run]），但必须先让 AppKit 建出共享应用对象，
    // 之后所有事件与窗口都挂在这个单例上（NSApp 就是它的宏）
    [NSApplication sharedApplication];
    if (![NSThread isMainThread]) {
      return 0; // AppKit 的类方法要从主线程调（MoonBit 宿主就在主线程，这条是护栏）
    }
    // 非 bundle 的裸二进制也要能被窗口服务接受：Regular 策略让本进程进
    // Dock 与菜单栏（不设为 Regular，NSWindow 建得出来但不会显示）。
    if ([NSApp activationPolicy] == NSApplicationActivationPolicyProhibited) {
      [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    }
    if (wm_app_delegate == nil) {
      wm_app_delegate = [[WMAppDelegate alloc] init];
      [NSApp setDelegate:wm_app_delegate];
    }
    [NSApp finishLaunching];
    return 1;
  }
}

int64_t wm_window_new(int width, int height, const char *title) {
  @autoreleasepool {
    int id = 0;
    for (int i = 1; i < WM_MAX_WINDOWS; i++) {
      if (wm_windows[i] == nil || wm_windows[i].view == nil) {
        id = i;
        break;
      }
    }
    if (id == 0) {
      return 0;
    }
    WMState *s = [[WMState alloc] init];
    s->sid = id;
    CGFloat sc = wm_scale_of(s); // 还没挂屏：退回主屏比例
    double pw = (double)(width > 1 ? width : 1) / (double)sc;
    double ph = (double)(height > 1 ? height : 1) / (double)sc;
    s->width = width > 1 ? width : 1;
    s->height = height > 1 ? height : 1;
    NSWindowStyleMask mask =
        NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
        NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    NSWindow *win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, pw, ph)
                  styleMask:mask
                    backing:NSBackingStoreBuffered
                      defer:NO];
    if (win == nil) {
      return 0;
    }
    [win setReleasedWhenClosed:NO];
    [win setTitle:(wm_str(title) ?: @"MoonBit")];
    WMView *view = [[WMView alloc]
        initWithFrame:NSMakeRect(0, 0, pw, ph)];
    [view setSlot:id];
    [view setWantsLayer:NO]; // 走 CGContext 直贴（drawRect 里取当前上下文）
    [win setContentView:view];
    [win setDelegate:s];
    [win setAcceptsMouseMovedEvents:YES];
    [win makeFirstResponder:view];
    s.win = win;
    s.view = view;
    wm_windows[id] = s;
    return (int64_t)id;
  }
}

void wm_show(int64_t id) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil) {
      return;
    }
    [s.win makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [s.view updateTrackingAreas];
    [s.win invalidateCursorRectsForView:s.view];
    s->need_draw = 1;
    wm_pump(); // 把映射请求推出去，别让首帧等到下一次 wait
  }
}

void wm_size(int64_t id, int32_t *out_w, int32_t *out_h) {
  WMState *s = wm_state(id);
  if (s == nil) {
    return;
  }
  if (out_w != NULL) {
    *out_w = s->width;
  }
  if (out_h != NULL) {
    *out_h = s->height;
  }
}

// 形参不叫 id：ObjC 里 `id` 是类型名，占用它会让下面的对象转型读成变量。
int wm_focus_owner(int64_t wid) {
  @autoreleasepool {
    WMState *s = wm_state(wid);
    if (s == nil) {
      return 0;
    }
    if ([NSApp keyWindow] != s.win) {
      return 0; // 整窗失焦：上层不该清自绘控件的焦点
    }
    NSResponder *fr = [s.win firstResponder];
    if (fr == nil || (NSObject *)fr == (NSObject *)s.win) {
      return 0;
    }
    return (NSObject *)fr == (NSObject *)s.view ? 1 : 2;
  }
}

// 消费式取事件：1 重绘 / 2 尺寸变化 / 3 请求关闭 / 4 有输入事件 / 5 失去焦点，
// 0 没有。优先级与 GTK/Win32 支一致（输入事件最先）。
int wm_event(int64_t id) {
  WMState *s = wm_state(id);
  if (s == nil) {
    return 0;
  }
  if (s->ev_count > 0) {
    return 4;
  }
  if (s->closing) {
    s->closing = 0;
    return 3;
  }
  if (s->resized) {
    s->resized = 0;
    return 2;
  }
  if (s->focus_lost) {
    s->focus_lost = 0;
    return 5;
  }
  if (s->need_draw) {
    s->need_draw = 0;
    return 1;
  }
  return 0;
}

int wm_take_event(int64_t id) {
  WMState *s = wm_state(id);
  if (s == nil || s->ev_count == 0) {
    return -1;
  }
  s->last = s->evs[s->ev_head];
  s->ev_head = (s->ev_head + 1) % 64;
  s->ev_count--;
  return (int)s->last.code;
}

int wm_pending_events(int64_t id) {
  WMState *s = wm_state(id);
  return s == nil ? 0 : s->ev_count;
}

int32_t wm_ev_keysym(int64_t id) {
  WMState *s = wm_state(id);
  return s == nil ? 0 : (int32_t)s->last.keysym;
}
int32_t wm_ev_mods(int64_t id) {
  WMState *s = wm_state(id);
  return s == nil ? 0 : (int32_t)s->last.mods;
}
int32_t wm_ev_x(int64_t id) {
  WMState *s = wm_state(id);
  return s == nil ? 0 : s->last.x;
}
int32_t wm_ev_y(int64_t id) {
  WMState *s = wm_state(id);
  return s == nil ? 0 : s->last.y;
}
int32_t wm_ev_button(int64_t id) {
  WMState *s = wm_state(id);
  return s == nil ? 0 : s->last.dx;
}
int32_t wm_ev_axis(int64_t id) {
  WMState *s = wm_state(id);
  return s == nil ? 0 : s->last.dy;
}

static BOOL wm_is_wake(NSEvent *ev) {
  return ev != nil && [ev type] == NSApplicationDefined &&
         [ev data1] == (NSInteger)WM_WAKE_TOKEN;
}

// 跑掉已就绪的事件，不阻塞。
void wm_pump(void) {
  @autoreleasepool {
    NSEvent *ev;
    while ((ev = [NSApp nextEventMatchingMask:NSEventMaskAny
                                    untilDate:[NSDate distantPast]
                                       inMode:NSDefaultRunLoopMode
                                      dequeue:YES]) != nil) {
      if (wm_is_wake(ev)) {
        continue; // 唤醒位：不进派发
      }
      [NSApp sendEvent:ev];
    }
  }
}

// 等平台事件。timeout_ms < 0 = 无限等（只能靠事件或 wm_wakeup 回来）。
// 这里用 AppKit 自己的阻塞取事件：它内部会跑主 run loop，跨线程
// postEvent:（wm_wakeup）能让它立刻返回——这正是本栈需要的唤醒位。
int wm_wait(int timeout_ms) {
  @autoreleasepool {
    NSDate *until = timeout_ms < 0
                        ? [NSDate distantFuture]
                        : [NSDate dateWithTimeIntervalSinceNow:
                                                  (double)timeout_ms / 1000.0];
    NSEvent *ev = [NSApp nextEventMatchingMask:NSEventMaskAny
                                     untilDate:until
                                        inMode:NSDefaultRunLoopMode
                                       dequeue:YES];
    if (ev == nil) {
      return 0;
    }
    if (!wm_is_wake(ev)) {
      [NSApp sendEvent:ev];
    }
    wm_pump(); // 同批剩下的也一并派发
    return 1;
  }
}

void wm_wakeup(void) {
  @autoreleasepool {
    NSEvent *ev = [NSEvent otherEventWithType:NSApplicationDefined
                                     location:NSZeroPoint
                                modifierFlags:0
                                    timestamp:0
                                 windowNumber:0
                                      context:nil
                                      subtype:0
                                        data1:(NSInteger)WM_WAKE_TOKEN
                                        data2:0];
    if (ev != nil) {
      [NSApp postEvent:ev atStart:NO];
    }
  }
}

void wm_request_focus(int64_t id) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil) {
      return;
    }
    [s.win makeKeyWindow];
    [s.win makeFirstResponder:s.view];
  }
}

// present：把帧拷进本层缓冲再请重画（真正的贴像素在下一次 drawRect:，
// 那时窗口与数据都一定还活着——与 GTK 支同一条实测结论）。
void wm_present(int64_t id, const unsigned char *rgba, int width, int height) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil || rgba == NULL || width < 1 || height < 1) {
      return;
    }
    size_t need = (size_t)width * (size_t)height * (size_t)4;
    if (s->backing_cap < need) {
      unsigned char *nb = (unsigned char *)realloc(s->backing, need);
      if (nb == NULL) {
        return;
      }
      s->backing = nb;
      s->backing_cap = need;
    }
    memcpy(s->backing, rgba, need);
    s->backing_w = width;
    s->backing_h = height;
    [s.view setNeedsDisplay:YES];
  }
}

void wm_close(int64_t id) {
  @autoreleasepool {
    WMState *s = wm_state_alive(id);
    if (s == nil) {
      return;
    }
    // 归属本窗的原生子件槽一起清（视图随窗口销毁）
    for (int i = 1; i < WM_MAX_SURFACES; i++) {
      if (wm_surf_views[i] != nil && wm_surf_win[i] == id) {
        wm_surf_views[i] = nil;
        wm_surf_win[i] = 0;
        wm_surf_kind[i] = 0;
        wm_surf_x[i] = wm_surf_y[i] = wm_surf_w[i] = wm_surf_h[i] = 0;
      }
    }
    if (s.win != nil) {
      [s.win setDelegate:nil];
      [s.win close];
    }
    s.win = nil;
    s.view = nil;
    wm_windows[(int)id] = nil; // 置 nil：ARC 释放对象，dealloc 里还帧缓冲
  }
}

// ---- IME（自绘内联档：MoonBit 拿 preedit 自画、拿 commit 进文本状态）----

void wm_im_set_surrounding(int64_t id, const char *text, int caret) {
  (void)text;
  WMState *s = wm_state(id);
  if (s == nil) {
    return;
  }
  // 本层无文档模型，候选窗位置只靠 wm_im_set_cursor 的矩形；这里 caret
  // 仅用于「输入法问周边文本」时的字节偏移提示，不落状态。
  (void)caret;
}

void wm_im_set_cursor(int64_t id, int x, int y, int w, int h) {
  WMState *s = wm_state(id);
  if (s == nil) {
    return;
  }
  s->im_cx = x;
  s->im_cy = y;
  s->im_cw = w;
  s->im_ch = h;
}

void wm_im_reset(int64_t id) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil) {
      return;
    }
    s->preedit_active = 0;
    s->preedit_len = 0;
    s->preedit[0] = '\0';
    s->commit_len = 0;
    [[s.view inputContext] invalidateCharacterCoordinates];
  }
}

int wm_im_commit_len(int64_t id) {
  WMState *s = wm_state(id);
  return s == nil ? 0 : s->commit_len;
}

int wm_im_commit_byte(int64_t id, int index) {
  WMState *s = wm_state(id);
  if (s == nil || index < 0 || index >= s->commit_len) {
    return 0;
  }
  return (int)(unsigned char)s->commit[index];
}

void wm_im_commit_done(int64_t id) {
  WMState *s = wm_state(id);
  if (s == nil) {
    return;
  }
  s->commit_len = 0;
  s->commit[0] = '\0';
}

int wm_im_preedit_len(int64_t id) {
  WMState *s = wm_state(id);
  return s == nil ? 0 : s->preedit_len;
}

int wm_im_preedit_byte(int64_t id, int index) {
  WMState *s = wm_state(id);
  if (s == nil || index < 0 || index >= s->preedit_len) {
    return 0;
  }
  return (int)(unsigned char)s->preedit[index];
}

int wm_im_preedit_caret(int64_t id) {
  WMState *s = wm_state(id);
  return s == nil ? 0 : s->preedit_caret;
}

int wm_im_preedit_active(int64_t id) {
  WMState *s = wm_state(id);
  return s == nil ? 0 : s->preedit_active;
}

// ---- 光标 ----

void wm_set_cursor(int64_t id, int kind) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil) {
      return;
    }
    if (s->cursor_kind == kind) {
      return;
    }
    s->cursor_kind = kind;
    [s.win invalidateCursorRectsForView:s.view];
  }
}

// ---- 窗口属性 ----

void wm_set_title(int64_t id, const char *title) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil) {
      return;
    }
    [s.win setTitle:(wm_str(title) ?: @"")];
  }
}

int wm_window_title(int64_t id, char *out, int cap) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil) {
      return wm_clamp_cap(out, cap, "");
    }
    NSString *t = [s.win title];
    return wm_clamp_cap(out, cap, t != nil ? [t UTF8String] : "");
  }
}

void wm_set_min_size(int64_t id, int wmin, int hmin) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil) {
      return;
    }
    CGFloat sc = wm_scale_of(s);
    s->min_w = wmin;
    s->min_h = hmin;
    [s.win setContentMinSize:NSMakeSize(wmin > 0 ? wmin / sc : 0,
                                        hmin > 0 ? hmin / sc : 0)];
  }
}

void wm_get_min_size(int64_t id, int32_t *out_w, int32_t *out_h) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil) {
      if (out_w != NULL) {
        *out_w = 0;
      }
      if (out_h != NULL) {
        *out_h = 0;
      }
      return;
    }
    CGFloat sc = wm_scale_of(s);
    NSSize m = [s.win contentMinSize];
    if (out_w != NULL) {
      *out_w = (int)(m.width * sc + 0.5);
    }
    if (out_h != NULL) {
      *out_h = (int)(m.height * sc + 0.5);
    }
  }
}

void wm_set_drag_rect(int64_t id, int x, int y, int w, int h) {
  WMState *s = wm_state(id);
  if (s == nil) {
    return;
  }
  s->drag_x = x;
  s->drag_y = y;
  s->drag_w = w;
  s->drag_h = h;
}

void wm_get_drag_rect(int64_t id, int32_t *x, int32_t *y, int32_t *w,
                      int32_t *h) {
  WMState *s = wm_state(id);
  if (s == nil) {
    if (x != NULL) { *x = 0; }
    if (y != NULL) { *y = 0; }
    if (w != NULL) { *w = 0; }
    if (h != NULL) { *h = 0; }
    return;
  }
  if (x != NULL) { *x = s->drag_x; }
  if (y != NULL) { *y = s->drag_y; }
  if (w != NULL) { *w = s->drag_w; }
  if (h != NULL) { *h = s->drag_h; }
}

void wm_set_borderless(int64_t id, int on) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil || s->borderless == (on ? 1 : 0)) {
      return;
    }
    s->borderless = on ? 1 : 0;
    NSWindowStyleMask mask = on
        ? NSWindowStyleMaskBorderless
        : (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
           NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable);
    [s.win setStyleMask:mask];
    [s.win setMovableByWindowBackground:!on];
    s->resized = 1;
    s->need_draw = 1;
  }
}

int wm_is_borderless(int64_t id) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil) {
      return 0;
    }
    return ([s.win styleMask] & NSWindowStyleMaskBorderless) != 0 ? 1 : 0;
  }
}

void wm_window_set_size(int64_t id, int w, int h) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil) {
      return;
    }
    CGFloat sc = wm_scale_of(s);
    int ww = w > 1 ? w : 1;
    int hh = h > 1 ? h : 1;
    [s.win setContentSize:NSMakeSize(ww / sc, hh / sc)];
    s->width = ww;
    s->height = hh;
    s->resized = 1;
    s->need_draw = 1;
  }
}

// 内容区左上角在屏幕上的原点（物理像素，y 从主屏顶向下）——弹层按
// 「owner 原点 + 控件窗口内矩形」摆位，两侧口径必须一致。
void wm_window_origin(int64_t id, int32_t *out_x, int32_t *out_y) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil || s.view == nil) {
      return;
    }
    CGFloat sc = wm_scale_of(s);
    NSRect content =
        [s.win convertRectToScreen:[s.view convertRect:s.view.bounds toView:nil]];
    NSRect pf = wm_primary_frame();
    if (out_x != NULL) {
      *out_x = (int)(content.origin.x * sc + 0.5);
    }
    if (out_y != NULL) {
      *out_y = (int)(((pf.origin.y + pf.size.height) - NSMaxY(content)) * sc +
                     0.5);
    }
  }
}

void wm_window_move(int64_t id, int x, int y) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil || s.view == nil) {
      return;
    }
    CGFloat sc = wm_scale_of(s);
    NSRect content = [s.win convertRectToScreen:
                      [s.view convertRect:s.view.bounds toView:nil]];
    NSRect pf = wm_primary_frame();
    CGFloat cur_top = (pf.origin.y + pf.size.height) - NSMaxY(content);
    CGFloat dx = (CGFloat)x / sc - content.origin.x;
    CGFloat dy = (CGFloat)y / sc - cur_top; // 向下为正
    NSRect fr = [s.win frame];
    [s.win setFrameTopLeftPoint:NSMakePoint(fr.origin.x + dx,
                                            NSMaxY(fr) - dy)];
    s->resized = 1;
    s->need_draw = 1;
  }
}

void wm_window_set_fullscreen(int64_t id, int on) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil) {
      return;
    }
    BOOL is_fs = ([s.win styleMask] & NSWindowStyleMaskFullScreen) != 0;
    if (on && !is_fs) {
      [s.win toggleFullScreen:nil];
    } else if (!on && is_fs) {
      [s.win toggleFullScreen:nil];
    }
  }
}

// 浮层窗：无边框 + 不抢主窗焦点 + 挂在 owner 之上随其移动。
void wm_window_set_popup(int64_t id, int64_t owner_id) {
  @autoreleasepool {
    WMState *s = wm_state(id);
    if (s == nil) {
      return;
    }
    [s.win setStyleMask:NSWindowStyleMaskBorderless];
    [s.win setLevel:NSFloatingWindowLevel];
    [s.win setHasShadow:NO];
    [s.win setHidesOnDeactivate:NO];
    s->borderless = 1;
    WMState *owner = wm_state_alive(owner_id);
    if (owner != nil && owner.win != nil && owner != s) {
      [owner.win addChildWindow:s.win ordered:NSWindowAbove];
    }
  }
}

// ---- 原生子件通道（方案 §4.7）----

int64_t wm_surface_new(int64_t window_id, int kind, int x, int y, int w,
                       int h) {
  @autoreleasepool {
    WMState *win = wm_state(window_id);
    if (win == nil) {
      return 0;
    }
    int sid = 0;
    for (int i = 1; i < WM_MAX_SURFACES; i++) {
      if (wm_surf_views[i] == nil) {
        sid = i;
        break;
      }
    }
    if (sid == 0) {
      return 0;
    }
    CGFloat sc = wm_scale_of(win);
    NSRect parent = win.view.bounds;
    double pw = (w > 1 ? w : 1) / sc;
    double ph = (h > 1 ? h : 1) / sc;
    // 内容坐标（左上原点、物理像素）→ 视图 frame（左下原点、点）
    NSView *v = [[NSView alloc] initWithFrame:NSMakeRect(
                    x / sc, parent.size.height - (y / sc) - ph, pw, ph)];
    [v setWantsLayer:YES];
    [win.view addSubview:v];
    wm_surf_views[sid] = v;
    wm_surf_win[sid] = window_id;
    wm_surf_kind[sid] = kind;
    wm_surf_x[sid] = x;
    wm_surf_y[sid] = y;
    wm_surf_w[sid] = w;
    wm_surf_h[sid] = h;
    return (int64_t)sid;
  }
}

void wm_surface_set_rect(int64_t surface_id, int x, int y, int w, int h) {
  @autoreleasepool {
    if (surface_id <= 0 || surface_id >= WM_MAX_SURFACES) {
      return;
    }
    NSView *v = wm_surf_views[(int)surface_id];
    if (v == nil) {
      return;
    }
    if (wm_surf_x[(int)surface_id] == x && wm_surf_y[(int)surface_id] == y &&
        wm_surf_w[(int)surface_id] == w && wm_surf_h[(int)surface_id] == h) {
      return; // 每帧都同步，位置没动就不重排
    }
    WMState *win = wm_state(wm_surf_win[(int)surface_id]);
    if (win == nil) {
      return;
    }
    CGFloat sc = wm_scale_of(win);
    NSRect parent = win.view.bounds;
    double pw = (w > 1 ? w : 1) / sc;
    double ph = (h > 1 ? h : 1) / sc;
    wm_surf_x[(int)surface_id] = x;
    wm_surf_y[(int)surface_id] = y;
    wm_surf_w[(int)surface_id] = w;
    wm_surf_h[(int)surface_id] = h;
    [v setFrame:NSMakeRect(x / sc, parent.size.height - (y / sc) - ph, pw, ph)];
  }
}

void wm_surface_close(int64_t surface_id) {
  @autoreleasepool {
    if (surface_id <= 0 || surface_id >= WM_MAX_SURFACES) {
      return;
    }
    NSView *v = wm_surf_views[(int)surface_id];
    if (v != nil) {
      [v removeFromSuperview];
    }
    wm_surf_views[(int)surface_id] = nil;
    wm_surf_win[(int)surface_id] = 0;
    wm_surf_kind[(int)surface_id] = 0;
    wm_surf_x[(int)surface_id] = wm_surf_y[(int)surface_id] =
        wm_surf_w[(int)surface_id] = wm_surf_h[(int)surface_id] = 0;
  }
}

// 给能力层的桩用（WebKit 支把 WKWebView 加进这个视图）
void *wm_surface_container(int64_t surface_id) {
  if (surface_id <= 0 || surface_id >= WM_MAX_SURFACES) {
    return NULL;
  }
  return (__bridge void *)wm_surf_views[(int)surface_id];
}

int wm_window_surface_count(int64_t id) {
  int n = 0;
  for (int i = 1; i < WM_MAX_SURFACES; i++) {
    if (wm_surf_views[i] != nil && wm_surf_win[i] == id) {
      n++;
    }
  }
  return n;
}

// ---- 时间 ----

int64_t wm_now_ms(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return 0;
  }
  return (int64_t)ts.tv_sec * 1000 + (int64_t)(ts.tv_nsec / 1000000);
}

int64_t wm_local_date(void) {
  time_t now = time(NULL);
  struct tm tm_local;
  if (localtime_r(&now, &tm_local) == NULL) {
    return 0;
  }
  return (int64_t)(tm_local.tm_year + 1900) * 10000 +
         (int64_t)(tm_local.tm_mon + 1) * 100 + (int64_t)tm_local.tm_mday;
}

// ---- 系统外观（深浅与主色）----

int wm_sys_color_scheme(char *out, int cap) {
  @autoreleasepool {
    if (out == NULL || cap < 1) {
      return 0;
    }
    out[0] = '\0';
    NSAppearance *ap = [NSApp effectiveAppearance];
    if (ap == nil) {
      return 0;
    }
    BOOL dark = NO;
    if (@available(macOS 10.14, *)) {
      dark = [ap bestMatchFromAppearancesWithNames:
                     @[ NSAppearanceNameDarkAqua,
                        NSAppearanceNameAqua ]] == NSAppearanceNameDarkAqua;
    }
    return wm_clamp_cap(out, cap, dark ? "dark" : "light");
  }
}

int wm_sys_accent(char *out, int cap) {
  @autoreleasepool {
    if (out == NULL || cap < 8) {
      return wm_clamp_cap(out, cap, "");
    }
    NSColor *c = nil;
    if (@available(macOS 10.14, *)) {
      c = [NSColor controlAccentColor];
    }
    if (c == nil) {
      c = [NSColor selectedContentBackgroundColor];
    }
    if (c == nil) {
      return wm_clamp_cap(out, cap, "");
    }
    NSColor *rgb = [c colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (rgb == nil) {
      return wm_clamp_cap(out, cap, "");
    }
    int r = (int)([rgb redComponent] * 255.0 + 0.5);
    int g = (int)([rgb greenComponent] * 255.0 + 0.5);
    int b = (int)([rgb blueComponent] * 255.0 + 0.5);
    char buf[8];
    snprintf(buf, sizeof(buf), "#%02x%02x%02x", r, g, b);
    return wm_clamp_cap(out, cap, buf);
  }
}

// ---- 剪贴板（sys/clipboard.mbt 的 mac 分支走 pbpaste/pbcopy 命令线；
// 这三条符号是 sys 链接 win 归档时必须存在的，这里给 NSPasteboard 真实现）----

int wm_clipboard_available(void) {
  @autoreleasepool {
    return [NSPasteboard generalPasteboard] != nil ? 1 : 0;
  }
}

void *wm_clipboard_get_text(int32_t *ok) {
  @autoreleasepool {
    if (ok != NULL) {
      *ok = 0;
    }
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    if (pb == nil) {
      return wm_bytes(NULL);
    }
    NSString *t = [pb stringForType:NSPasteboardTypeString];
    if (t == nil) {
      return wm_bytes(NULL);
    }
    if (ok != NULL) {
      *ok = 1;
    }
    return wm_bytes([t UTF8String]);
  }
}

int wm_clipboard_set_text(const char *text) {
  @autoreleasepool {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    if (pb == nil || text == NULL) {
      return 0;
    }
    NSString *t = wm_str(text);
    if (t == nil) {
      return 0;
    }
    [pb clearContents];
    return [pb setString:t forType:NSPasteboardTypeString] ? 1 : 0;
  }
}

// ---- 文件对话框（NSOpenPanel / NSSavePanel）----

static NSSavePanel *wm_dialogs[WM_DLG_MAX];
static int wm_dlg_accepted[WM_DLG_MAX];
static int wm_dlg_is_open[WM_DLG_MAX];

static int64_t wm_dlg_put(NSSavePanel *panel, int is_open) {
  for (int i = 0; i < WM_DLG_MAX; i++) {
    if (wm_dialogs[i] == nil) {
      wm_dialogs[i] = panel;
      wm_dlg_accepted[i] = 0;
      wm_dlg_is_open[i] = is_open;
      return (int64_t)(i + 1);
    }
  }
  return 0;
}

static NSSavePanel *wm_dlg_of(int64_t id) {
  if (id <= 0 || id > WM_DLG_MAX) {
    return nil;
  }
  return wm_dialogs[(int)id - 1];
}

static void wm_dlg_free(int64_t id) {
  if (id <= 0 || id > WM_DLG_MAX) {
    return;
  }
  wm_dlg_accepted[(int)id - 1] = 0;
  wm_dlg_is_open[(int)id - 1] = 0;
  wm_dialogs[(int)id - 1] = nil;
}

static int64_t wm_file_dialog_new(int save) {
  @autoreleasepool {
    if (![NSThread isMainThread]) {
      return 0; // AppKit 面板必须在主线程建
    }
    if (save) {
      return wm_dlg_put([NSSavePanel savePanel], 0);
    }
    return wm_dlg_put([NSOpenPanel openPanel], 1);
  }
}

int64_t wm_file_open_dialog_new(void) { return wm_file_dialog_new(0); }
int64_t wm_file_save_dialog_new(void) { return wm_file_dialog_new(1); }

// 选项位：1 选文件夹、2 多选、4 显示隐藏文件。
void wm_file_dialog_set_options(int64_t id, int32_t options) {
  @autoreleasepool {
    NSSavePanel *p = wm_dlg_of(id);
    if (p == nil) {
      return;
    }
    // 三个开关都只在「打开面板」上声明（NSSavePanel 天生单选、也没有
    // canShowHiddenFiles）：多选/选文件夹/显示隐藏对保存面板无意义，
    // 于是保存对话框只吃 FILE_OPTION_SHOW_HIDDEN 之外的语义（按 API 事实给）
    if (wm_dlg_is_open[(int)id - 1]) {
      NSOpenPanel *op = (NSOpenPanel *)p;
      [op setAllowsMultipleSelection:(options & 2) != 0];
      [op setCanChooseFiles:(options & 1) == 0];
      [op setTreatsFilePackagesAsDirectories:YES];
      // canShowHiddenFiles 在 macOS 26 的 SDK 上不再随 NSOpenPanel 公开声明
      // （clang 报 no visible @interface），故按运行时能力设：上面的 informal
      // 声明只让 selector 可见，SDK 里没有这一口就跳过（隐藏文件开关失灵,
      // 其余选项不受影响）。
      if ([op respondsToSelector:@selector(setCanShowHiddenFiles:)]) {
        [op setCanShowHiddenFiles:(options & 4) != 0];
      }
    }
  }
}

// filters 打包："描述:扩展1,扩展2|描述2:扩展3"（'*' 匹配全部）
void wm_file_dialog_set_filters(int64_t id, const char *filters) {
  @autoreleasepool {
    NSSavePanel *p = wm_dlg_of(id);
    if (p == nil || filters == NULL) {
      return;
    }
    NSMutableArray<NSString *> *types = [NSMutableArray array];
    BOOL all = NO;
    const char *pos = filters;
    while (*pos != '\0') {
      const char *bar = strchr(pos, '|');
      size_t glen = bar != NULL ? (size_t)(bar - pos) : strlen(pos);
      char group[256];
      if (glen >= sizeof(group)) {
        glen = sizeof(group) - 1;
      }
      memcpy(group, pos, glen);
      group[glen] = '\0';
      const char *colon = strchr(group, ':');
      if (colon != NULL) {
        const char *ep = colon + 1;
        while (*ep != '\0') {
          const char *comma = strchr(ep, ',');
          size_t el = comma != NULL ? (size_t)(comma - ep) : strlen(ep);
          char pat[64];
          if (el >= sizeof(pat)) {
            el = sizeof(pat) - 1;
          }
          memcpy(pat, ep, el);
          pat[el] = '\0';
          if (strcmp(pat, "*") == 0) {
            all = YES;
          } else if ([types count] < 64) {
            NSString *ext = wm_str(pat);
            if (ext != nil) {
              [types addObject:ext];
            }
          }
          ep = comma != NULL ? comma + 1 : ep + el;
        }
      }
      pos = bar != NULL ? bar + 1 : pos + glen;
    }
    if (all || [types count] == 0) {
      [p setAllowedFileTypes:nil];
    } else {
      [p setAllowedFileTypes:types];
    }
  }
}

// folder 可以是 file:// URI 或本地路径（与 GTK 支同口径）。
void wm_file_dialog_set_folder(int64_t id, const char *folder) {
  @autoreleasepool {
    NSSavePanel *p = wm_dlg_of(id);
    if (p == nil || folder == NULL) {
      return;
    }
    const char *path = folder;
    if (strncmp(path, "file://", 7) == 0) {
      path += 7;
    }
    NSString *s = wm_str(path);
    if (s != nil) {
      [p setDirectoryURL:[NSURL fileURLWithPath:s]];
    }
  }
}

void wm_file_dialog_set_filename(int64_t id, const char *filename) {
  @autoreleasepool {
    NSSavePanel *p = wm_dlg_of(id);
    if (p == nil || filename == NULL) {
      return;
    }
    NSString *s = wm_str(filename);
    if (s != nil) {
      [p setNameFieldStringValue:s];
    }
  }
}

// 模态运行。parent 是 win 的窗口 id——macOS 的应用级模态面板不挂父窗
// （挂窗要走异步 beginSheet，与本栈「一次调用拿到结果」的契约不合），
// 这里按应用级模态跑，parent 只用于把那一侧的窗先带到前台。
int32_t wm_file_dialog_run_for_window(int64_t id, int64_t parent_id) {
  @autoreleasepool {
    NSSavePanel *p = wm_dlg_of(id);
    if (p == nil) {
      return 0;
    }
    WMState *par = wm_state_alive(parent_id);
    if (par != nil && par.win != nil) {
      [NSApp activateIgnoringOtherApps:YES];
      [par.win makeKeyWindow];
    }
    NSInteger r = [p runModal];
    if ((int64_t)(id - 1) >= 0 && id <= WM_DLG_MAX) {
      wm_dlg_accepted[(int)id - 1] = (r == NSModalResponseOK) ? 1 : 0;
    }
    return r == NSModalResponseOK ? 1 : 0;
  }
}

// 选中路径（file:// 已剥；未确认/无结果给空串；多选取首个，与 GTK 支同口径）
void *wm_file_dialog_get_result(int64_t id) {
  @autoreleasepool {
    NSSavePanel *p = wm_dlg_of(id);
    if (p == nil || id < 1 || id > WM_DLG_MAX || !wm_dlg_accepted[(int)id - 1]) {
      return wm_bytes(NULL);
    }
    // URLs 只在 NSOpenPanel 上声明（多选），保存面板退回单值 URL
    NSURL *url = nil;
    if (wm_dlg_is_open[(int)id - 1]) {
      url = [[(NSOpenPanel *)p URLs] firstObject];
    }
    if (url == nil) {
      url = [p URL];
    }
    if (url == nil) {
      return wm_bytes(NULL);
    }
    return wm_bytes([[url path] UTF8String]);
  }
}

void wm_file_dialog_destroy(int64_t id) { wm_dlg_free(id); }

// ---- 全局快捷键（Carbon RegisterEventHotKey）----------------------------
//
// macOS 没有 Win32 的 RegisterHotKey：全局热键的现役公开入口仍是 Carbon 那三个
// 函数（libyue/Chromium 同一条路），事件经 Carbon 事件管理器进 Cocoa 的 run
// loop，所以照旧走「注册 + 泵里抽」，不蹦床回 MoonBit。
//
// 一条必须写出来的平台差异：Carbon 热键认的是 **kVK_*（硬件键位）**，US 布局下
// 与字母/数字一一对应，非 US 布局（Dvorak、法语等）同一物理键的字符不同——这是
// Carbon 自身的语义，不做布局层换算。表外的 vk 返回 0（注册失败），由门面降级。
#import <Carbon/Carbon.h>

#define WM_HOTKEY_MAX 32

typedef struct {
  EventHotKeyRef ref;
  int used;
  int id;
} WmHotkey;

static WmHotkey wm_hotkeys[WM_HOTKEY_MAX];
static int wm_hotkey_fired[WM_HOTKEY_MAX];
static int wm_hotkey_fired_head = 0;
static int wm_hotkey_fired_count = 0;
static EventHandlerRef wm_hotkey_handler = NULL;

// Win32 vk → kVK_*（`Events.h` 的硬件键位值，ANSI 名按 US 布局标注）。
// 未知给 -1（0 是 kVK_ANSI_A，不能当「没查到」用）。
static int wm_vk_to_mac_keycode(int vk) {
  switch (vk) {
    // 字母（kVK 的编号顺序是物理键位顺序，不是字母表顺序）
    case 0x41: return 0x00;  // A
    case 0x42: return 0x0B;  // B
    case 0x43: return 0x08;  // C
    case 0x44: return 0x02;  // D
    case 0x45: return 0x0E;  // E
    case 0x46: return 0x03;  // F
    case 0x47: return 0x05;  // G
    case 0x48: return 0x04;  // H
    case 0x49: return 0x22;  // I
    case 0x4A: return 0x26;  // J
    case 0x4B: return 0x28;  // K
    case 0x4C: return 0x25;  // L
    case 0x4D: return 0x2E;  // M
    case 0x4E: return 0x2D;  // N
    case 0x4F: return 0x1F;  // O
    case 0x50: return 0x23;  // P
    case 0x51: return 0x0C;  // Q
    case 0x52: return 0x0F;  // R
    case 0x53: return 0x01;  // S
    case 0x54: return 0x11;  // T
    case 0x55: return 0x20;  // U
    case 0x56: return 0x09;  // V
    case 0x57: return 0x0D;  // W
    case 0x58: return 0x07;  // X
    case 0x59: return 0x10;  // Y
    case 0x5A: return 0x06;  // Z
    // 数字
    case 0x30: return 0x1D; // 0
    case 0x31: return 0x12; // 1
    case 0x32: return 0x13;
    case 0x33: return 0x14;
    case 0x34: return 0x15;
    case 0x35: return 0x17;
    case 0x36: return 0x16;
    case 0x37: return 0x1A;
    case 0x38: return 0x1C;
    case 0x39: return 0x19;
    // 编辑与导航
    case 0x08: return 0x33; // Backspace（kVK_Delete）
    case 0x09: return 0x30; // Tab
    case 0x0D: return 0x24; // Return
    case 0x1B: return 0x35; // Escape
    case 0x20: return 0x31; // Space
    case 0x21: return 0x74; // PageUp
    case 0x22: return 0x79; // PageDown
    case 0x23: return 0x77; // End
    case 0x24: return 0x73; // Home
    case 0x25: return 0x7B; // Left
    case 0x26: return 0x7E; // Up
    case 0x27: return 0x7C; // Right
    case 0x28: return 0x7D; // Down
    case 0x2E: return 0x75; // Delete（前向删除）
    // 功能键
    case 0x70: return 0x7A; // F1
    case 0x71: return 0x78;
    case 0x72: return 0x63;
    case 0x73: return 0x76;
    case 0x74: return 0x60;
    case 0x75: return 0x61;
    case 0x76: return 0x62;
    case 0x77: return 0x64;
    case 0x78: return 0x65;
    case 0x79: return 0x6D;
    case 0x7A: return 0x67;
    case 0x7B: return 0x6F; // F12
    // US 布局标点（OEM 键）
    case 0xBC: return 0x2B; // ,
    case 0xBE: return 0x2F; // .
    case 0xBF: return 0x2C; // /
    case 0xBA: return 0x29; // ;
    case 0xDE: return 0x27; // '
    case 0xDB: return 0x21; // [
    case 0xDD: return 0x1E; // ]
    case 0xDC: return 0x2A; // \
    case 0xBD: return 0x1B; // -
    case 0xBB: return 0x18; // =
    case 0xC0: return 0x32; // `
    default: return -1;
  }
}

static void wm_hotkey_push(int id);
static OSStatus wm_hotkey_dispatch(EventHandlerCallRef next_handler,
                                   EventRef event, void *user_data);

static int wm_hotkey_ensure(void) {
  if (wm_hotkey_handler != NULL) {
    return 1;
  }
  EventTypeSpec spec;
  spec.eventClass = kEventClassKeyboard;
  spec.eventKind = kEventHotKeyPressed;
  OSStatus st = InstallApplicationEventHandler(
      NewEventHandlerUPP(wm_hotkey_dispatch), 1, &spec, NULL,
      &wm_hotkey_handler);
  return st == noErr ? 1 : 0;
}

static OSStatus wm_hotkey_dispatch(EventHandlerCallRef next_handler,
                                   EventRef event, void *user_data) {
  (void)next_handler;
  (void)user_data;
  EventHotKeyID hkid;
  OSStatus st = GetEventParameter(event, kEventParamDirectObject,
                                  typeEventHotKeyID, NULL, sizeof(hkid), NULL,
                                  &hkid);
  if (st == noErr) {
    wm_hotkey_push((int)hkid.id);
  }
  return noErr;
}

static void wm_hotkey_push(int id) {
  if (wm_hotkey_fired_count >= WM_HOTKEY_MAX) {
    return;
  }
  wm_hotkey_fired[(wm_hotkey_fired_head + wm_hotkey_fired_count) %
                  WM_HOTKEY_MAX] = id;
  wm_hotkey_fired_count++;
}

int wm_hotkey_register(int mods, int vk) {
  if (!wm_hotkey_ensure()) {
    return 0;
  }
  int code = wm_vk_to_mac_keycode(vk);
  if (code < 0) {
    return 0;
  }
  int slot = -1;
  for (int i = 1; i < WM_HOTKEY_MAX; i++) {
    if (!wm_hotkeys[i].used) {
      slot = i;
      break;
    }
  }
  if (slot < 0) {
    return 0;
  }
  // 修饰位：1 shift / 2 ctrl / 4 alt / 8 meta（mac 的 meta 就是 Command）
  UInt32 cm = 0;
  if (mods & 1) {
    cm |= shiftKey;
  }
  if (mods & 2) {
    cm |= controlKey;
  }
  if (mods & 4) {
    cm |= optionKey;
  }
  if (mods & 8) {
    cm |= cmdKey;
  }
  EventHotKeyID hkid;
  hkid.signature = FOUR_CHAR_CODE('mbtg');
  hkid.id = (UInt32)slot;
  EventHotKeyRef ref = NULL;
  OSStatus st = RegisterEventHotKey((UInt32)code, cm, hkid,
                                    GetApplicationEventTarget(), 0, &ref);
  if (st != noErr || ref == NULL) {
    return 0;
  }
  wm_hotkeys[slot].ref = ref;
  wm_hotkeys[slot].used = 1;
  wm_hotkeys[slot].id = slot;
  return slot;
}

void wm_hotkey_unregister(int hk_id) {
  if (hk_id <= 0 || hk_id >= WM_HOTKEY_MAX || !wm_hotkeys[hk_id].used) {
    return;
  }
  if (wm_hotkeys[hk_id].ref != NULL) {
    UnregisterEventHotKey(wm_hotkeys[hk_id].ref);
  }
  wm_hotkeys[hk_id].ref = NULL;
  wm_hotkeys[hk_id].used = 0;
  wm_hotkeys[hk_id].id = 0;
}

int wm_hotkey_poll(void) {
  if (wm_hotkey_fired_count <= 0) {
    return 0;
  }
  int id = wm_hotkey_fired[wm_hotkey_fired_head];
  wm_hotkey_fired_head = (wm_hotkey_fired_head + 1) % WM_HOTKEY_MAX;
  wm_hotkey_fired_count--;
  return id;
}

// ---- 图标表（NSImage）----------------------------------------------------

static NSImage *wm_icons[WM_MAX_ICONS];

static void wm_free_buf(void *info, const void *data, size_t size) {
  (void)info;
  (void)size;
  free((void *)data);
}

static int wm_icon_put(NSImage *img) {
  if (img == nil) {
    return 0;
  }
  for (int i = 1; i < WM_MAX_ICONS; i++) {
    if (wm_icons[i] == nil) {
      wm_icons[i] = img;
      return i;
    }
  }
  return 0;
}

static NSImage *wm_icon_of(int slot) {
  if (slot <= 0 || slot >= WM_MAX_ICONS) {
    return nil;
  }
  return wm_icons[slot];
}

// BGRA 预乘像素（本栈 Bitmap 口径）→ NSImage：与 Win32 支的
// CreateIconIndirect 同一份像素，逐字节直拷。
int wm_icon_from_bgra(const unsigned char *px, int w, int h) {
  @autoreleasepool {
    if (px == NULL || w < 1 || h < 1) {
      return 0;
    }
    size_t len = (size_t)w * (size_t)h * 4u;
    void *copy = malloc(len);
    if (copy == NULL) {
      return 0;
    }
    memcpy(copy, px, len);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef dp = CGDataProviderCreateWithData(NULL, copy, len, wm_free_buf);
    if (dp == NULL) {
      free(copy);
      if (cs != NULL) {
        CGColorSpaceRelease(cs);
      }
      return 0;
    }
    CGImageRef img = CGImageCreate(
        w, h, 8, 32, (size_t)w * 4u, cs,
        (CGBitmapInfo)(kCGImageAlphaPremultipliedFirst |
                       kCGBitmapByteOrder32Little),
        dp, NULL, kCGInterpolationNone, kCGRenderingIntentDefault);
    NSImage *out = nil;
    if (img != NULL) {
      out = [[NSImage alloc] initWithCGImage:img size:NSMakeSize(w, h)];
      CGImageRelease(img);
    }
    CGDataProviderRelease(dp); // 触发 wm_free_buf，copy 在这里归还
    if (cs != NULL) {
      CGColorSpaceRelease(cs);
    }
    return wm_icon_put(out);
  }
}

int wm_icon_from_png(const unsigned char *data, int len) {
  @autoreleasepool {
    if (data == NULL || len < 1) {
      return 0;
    }
    NSData *d = [NSData dataWithBytes:(const void *)data length:(size_t)len];
    if (d == nil) {
      return 0;
    }
    return wm_icon_put([[NSImage alloc] initWithData:d]);
  }
}

int wm_icon_load_file(const char *path, int size) {
  @autoreleasepool {
    NSString *p = wm_str(path);
    if (p == nil) {
      return 0;
    }
    NSImage *img = [[NSImage alloc] initWithContentsOfFile:p];
    if (img == nil) {
      return 0;
    }
    if (size > 0) {
      [img setSize:NSMakeSize(size, size)];
    }
    return wm_icon_put(img);
  }
}

void wm_icon_free(int slot) {
  if (slot > 0 && slot < WM_MAX_ICONS) {
    wm_icons[slot] = nil;
  }
}

int wm_icon_alive(void) {
  int n = 0;
  for (int i = 1; i < WM_MAX_ICONS; i++) {
    if (wm_icons[i] != nil) {
      n++;
    }
  }
  return n;
}

void *wm_icon_handle(int slot) {
  return (__bridge void *)wm_icon_of(slot);
}

// which：0 大图标 / 1 小图标 / 2 两者。macOS 只有应用图标一档（Dock 与
// 窗口代理图标同源），三档都落到 applicationIconImage。
void wm_set_icon(int64_t wid, int icon_slot, int which) {
  @autoreleasepool {
    (void)wid;
    (void)which;
    NSImage *img = wm_icon_of(icon_slot);
    if (img == nil) {
      return;
    }
    [NSApp setApplicationIconImage:img];
  }
}

// ---- 原生菜单（NSMenu）---------------------------------------------------
//
// macOS 的菜单条属于 App 不属于窗口：wm_menu_apply 落到 setMainMenu:，多窗
// 共用一份（后挂的赢）。命令一律回本层队列由 MoonBit 按 native_id 派发，
// 不用原生 role——这样三平台的菜单行为是同一条链（与 Win32 支同口径）。

static NSMenu *wm_menus[WM_MAX_MENUS];
static int wm_menu_cmd_next = WM_MENU_CMD_BASE;
static int wm_menu_fired[64];
static int wm_menu_fired_head = 0;
static int wm_menu_fired_count = 0;

static void wm_menu_push(int cmd);

@interface WMMenuTarget : NSObject
- (void)wmMenuItemFired:(NSMenuItem *)sender;
@end

static WMMenuTarget *wm_menu_target = nil;

@implementation WMMenuTarget
- (void)wmMenuItemFired:(NSMenuItem *)sender {
  // NSMenuItem 没有 tag：命令 id 放 representedObject
  id obj = [sender representedObject];
  if ([obj isKindOfClass:[NSNumber class]]) {
    int cmd = (int)[(NSNumber *)obj integerValue];
    if (cmd >= WM_MENU_CMD_BASE && cmd < WM_MENU_CMD_BASE + WM_MENU_CMD_MAX) {
      wm_menu_push(cmd);
    }
  }
}
@end

static void wm_menu_push(int cmd) {
  if (wm_menu_fired_count >= 64) {
    return;
  }
  wm_menu_fired[(wm_menu_fired_head + wm_menu_fired_count) % 64] = cmd;
  wm_menu_fired_count++;
}

static int wm_menu_slot_put(NSMenu *m) {
  if (m == nil) {
    return 0;
  }
  for (int i = 1; i < WM_MAX_MENUS; i++) {
    if (wm_menus[i] == nil) {
      wm_menus[i] = m;
      return i;
    }
  }
  return 0;
}

// 加速键串（"CmdOrCtrl+Shift+Z" 那套语法）→ keyEquivalent + 修饰位。
// 功能键（F1..F12）在本栈的菜单里不给原生快捷键：AppKit 的 function-key
// 快捷键要配额外的 keyEquivalentModifierMask 语义，跨布局不可靠，交给
// MoonBit 侧的按键派发。
static void wm_apply_accel(NSMenuItem *item, const char *acc) {
  if (item == nil || acc == NULL || acc[0] == '\0') {
    return;
  }
  NSString *s = wm_str(acc);
  if (s == nil) {
    return;
  }
  NSUInteger mask = 0;
  unichar key = 0;
  for (NSString *part in [s componentsSeparatedByString:@"+"]) {
    NSString *t = [part stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceCharacterSet]];
    NSString *low = [t lowercaseString];
    if ([low isEqualToString:@"ctrl"] || [low isEqualToString:@"control"]) {
      mask |= NSEventModifierFlagControl;
    } else if ([low isEqualToString:@"shift"]) {
      mask |= NSEventModifierFlagShift;
    } else if ([low isEqualToString:@"alt"] || [low isEqualToString:@"option"] ||
               [low isEqualToString:@"opt"]) {
      mask |= NSEventModifierFlagOption;
    } else if ([low isEqualToString:@"cmd"] || [low isEqualToString:@"command"] ||
               [low isEqualToString:@"super"] || [low isEqualToString:@"win"] ||
               [low isEqualToString:@"meta"] ||
               [low isEqualToString:@"cmdorctrl"] ||
               [low isEqualToString:@"cmdorctl"] ||
               [low isEqualToString:@"commandorcontrol"]) {
      // mac 的主修饰是 Command（core/win/hotkey.mbt 的 is_mac 口径）
      mask |= NSEventModifierFlagCommand;
    } else if ([t length] == 1u) {
      key = [t characterAtIndex:0u];
    }
  }
  if (key == 0u) {
    return;
  }
  NSString *ks = [[NSString stringWithFormat:@"%C", key] lowercaseString];
  [item setKeyEquivalent:ks];
  [item setKeyEquivalentModifierMask:mask];
}

int wm_menu_bar_new(void) {
  @autoreleasepool {
    if (wm_menu_target == nil) {
      wm_menu_target = [[WMMenuTarget alloc] init];
    }
    return wm_menu_slot_put([[NSMenu alloc] initWithTitle:@""]);
  }
}

int wm_menu_popup_new(void) {
  @autoreleasepool {
    if (wm_menu_target == nil) {
      wm_menu_target = [[WMMenuTarget alloc] init];
    }
    return wm_menu_slot_put([[NSMenu alloc] initWithTitle:@""]);
  }
}

int wm_menu_new_sub(int parent, const char *title) {
  @autoreleasepool {
    if (parent <= 0 || parent >= WM_MAX_MENUS || wm_menus[parent] == nil) {
      return 0;
    }
    NSString *t = wm_str(title) ?: @"";
    NSMenu *sub = [[NSMenu alloc] initWithTitle:t];
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:t
                                                 action:nil
                                          keyEquivalent:@""];
    [item setSubmenu:sub];
    [wm_menus[parent] addItem:item];
    return wm_menu_slot_put(sub);
  }
}

// kind：0 command / 1 check / 2 radio / 3 separator。role 在 mac 侧不映射成
// 原生动作（见本节头），只由 MoonBit 的默认标签/加速键表达。
int wm_menu_add_item(int parent, const char *label, int kind, int role,
                     const char *acc, int checked) {
  @autoreleasepool {
    (void)role;
    if (parent <= 0 || parent >= WM_MAX_MENUS || wm_menus[parent] == nil) {
      return 0;
    }
    if (kind == 3) {
      [wm_menus[parent] addItem:[NSMenuItem separatorItem]];
      return 0;
    }
    int cmd = wm_menu_cmd_next;
    NSString *t = wm_str(label) ?: @"";
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:t
                                                 action:@selector(wmMenuItemFired:)
                                          keyEquivalent:@""];
    [item setTarget:wm_menu_target];
    [item setRepresentedObject:@(cmd)];
    if (kind == 1 || kind == 2) {
      [item setState:checked ? NSControlStateValueOn : NSControlStateValueOff];
    }
    [item setEnabled:YES];
    wm_apply_accel(item, acc);
    if ([[wm_menus[parent] itemArray] count] >= 4096) {
      return 0; // 与 Win32 支同一条「挂载失败不吃 id」的口径
    }
    [wm_menus[parent] addItem:item];
    wm_menu_cmd_next = cmd + 1;
    if (wm_menu_cmd_next >= WM_MENU_CMD_BASE + WM_MENU_CMD_MAX) {
      wm_menu_cmd_next = WM_MENU_CMD_BASE;
    }
    return cmd;
  }
}

void wm_menu_apply(int64_t wid, int bar) {
  @autoreleasepool {
    (void)wid; // 菜单属于 App：窗口 id 在此不参与
    NSMenu *m = (bar > 0 && bar < WM_MAX_MENUS) ? wm_menus[bar] : nil;
    [NSApp setMainMenu:m];
  }
}

int wm_menu_poll(void) {
  if (wm_menu_fired_count <= 0) {
    return 0;
  }
  int cmd = wm_menu_fired[wm_menu_fired_head];
  wm_menu_fired_head = (wm_menu_fired_head + 1) % 64;
  wm_menu_fired_count--;
  return cmd;
}

// ---- 托盘（NSStatusItem）-------------------------------------------------
//
// Windows 的托盘是「隐藏消息窗 + Shell_NotifyIcon」，macOS 是状态栏项：
// 点击经 NSStatusBarButton 的 action 进本层队列（0 左 / 1 右），右键菜单不在
// 按钮上常驻——`wm_tray_set_menu` 只登记句柄，弹出由宿主调 `wm_tray_popup`
// （与 Win32 支同一条派发链，选中项照样进菜单队列）。

static NSStatusItem *wm_tray_items[WM_MAX_TRAYS];
static NSMenu *wm_tray_menus[WM_MAX_TRAYS];
static int wm_tray_kind[WM_MAX_TRAYS];
static char wm_tray_tips[WM_MAX_TRAYS][128];
static int wm_tray_events[WM_TRAY_EV_MAX];
static int wm_tray_ev_head = 0;
static int wm_tray_ev_count = 0;

@interface WMTrayTarget : NSObject
- (void)wmTrayClicked:(NSView *)sender;
@end

static WMTrayTarget *wm_tray_target = nil;

static void wm_tray_push(int slot, int kind) {
  if (wm_tray_ev_count >= WM_TRAY_EV_MAX) {
    wm_tray_ev_head = (wm_tray_ev_head + 1) % WM_TRAY_EV_MAX;
    wm_tray_ev_count--;
  }
  wm_tray_events[(wm_tray_ev_head + wm_tray_ev_count) % WM_TRAY_EV_MAX] =
      slot * 4 + kind;
  wm_tray_ev_count++;
}

@implementation WMTrayTarget
- (void)wmTrayClicked:(NSView *)sender {
  for (int i = 1; i < WM_MAX_TRAYS; i++) {
    if (wm_tray_items[i] != nil && [wm_tray_items[i] button] == sender) {
      if (wm_tray_kind[i] != 0) {
        return; // 通知槽不收点击（与 Win32 支同语义）
      }
      NSEvent *ev = [NSApp currentEvent];
      int kind = ([ev type] == NSEventTypeRightMouseUp ||
                  [ev type] == NSEventTypeRightMouseDown)
                     ? 1
                     : 0;
      wm_tray_push(i, kind);
      return;
    }
  }
}
@end

int wm_tray_supported(void) {
  @autoreleasepool {
    if ([NSStatusBar systemStatusBar] == nil) {
      return 0;
    }
    if (wm_tray_target == nil) {
      wm_tray_target = [[WMTrayTarget alloc] init];
    }
    return wm_tray_target != nil ? 1 : 0;
  }
}

// 内部：分配槽并落到状态栏。kind 0 托盘图标 / 1 通知槽（mac 的通知另走
// NSUserNotification，本函数只服务 kind 0）。
static int wm_tray_alloc(int kind, int icon_slot, const char *tip) {
  if (!wm_tray_supported()) {
    return 0;
  }
  if (kind != 0) {
    return 0;
  }
  int slot = -1;
  for (int i = 1; i < WM_MAX_TRAYS; i++) {
    if (wm_tray_items[i] == nil) {
      slot = i;
      break;
    }
  }
  if (slot < 0) {
    return 0;
  }
  NSStatusItem *item = [[NSStatusBar systemStatusBar]
      statusItemWithLength:NSVariableStatusItemLength];
  if (item == nil) {
    return 0;
  }
  [item setHighlightMode:YES];
  NSStatusBarButton *btn = [item button];
  if (btn == nil) {
    [[NSStatusBar systemStatusBar] removeStatusItem:item];
    return 0;
  }
  [btn setImage:wm_icon_of(icon_slot)];
  [btn setImagePosition:NSImageOnly];
  [btn setTitle:@""];
  NSString *tipstr = wm_str(tip);
  if (tipstr != nil) {
    [btn setToolTip:tipstr];
  }
  [btn setTarget:wm_tray_target];
  [btn setAction:@selector(wmTrayClicked:)];
  // 触发掩码：不给就只在左键抬起时发动作，右键那条永远收不到。
  // sendActionOn 在 macOS 26 的 SDK 上无公开声明（见文件头 informal 声明），
  // 故按运行时能力设——设不上的话托盘只有左键可用。
  id cell = [btn cell];
  if ([cell respondsToSelector:@selector(setSendActionOn:)]) {
    [cell setSendActionOn:(NSUInteger)(NSEventMaskLeftMouseUp |
                                       NSEventMaskRightMouseUp)];
  }
  wm_clamp_cap(wm_tray_tips[slot], 128, tip != NULL ? tip : "");
  wm_tray_items[slot] = item;
  wm_tray_menus[slot] = nil;
  wm_tray_kind[slot] = kind;
  return slot;
}

int wm_tray_new(int icon_slot, const char *tip) {
  @autoreleasepool {
    return wm_tray_alloc(0, icon_slot, tip);
  }
}

void wm_tray_set_tooltip(int slot, const char *tip) {
  @autoreleasepool {
    if (slot <= 0 || slot >= WM_MAX_TRAYS || wm_tray_items[slot] == nil) {
      return;
    }
    NSString *s = wm_str(tip);
    if (s == nil) {
      return;
    }
    [[wm_tray_items[slot] button] setToolTip:s];
    wm_clamp_cap(wm_tray_tips[slot], 128, tip);
  }
}

void wm_tray_set_icon(int slot, int icon_slot) {
  if (slot <= 0 || slot >= WM_MAX_TRAYS || wm_tray_items[slot] == nil) {
    return;
  }
  [[wm_tray_items[slot] button] setImage:wm_icon_of(icon_slot)];
}

void wm_tray_set_menu(int slot, int menu_handle) {
  if (slot <= 0 || slot >= WM_MAX_TRAYS || wm_tray_items[slot] == nil) {
    return;
  }
  wm_tray_menus[slot] =
      (menu_handle > 0 && menu_handle < WM_MAX_MENUS) ? wm_menus[menu_handle]
                                                      : nil;
}

// 在状态栏项处弹出登记的菜单。AppKit 的菜单在自己的事件循环里跑完，
// 选中项的 action 已经把命令压进菜单队列，这里只报「弹没弹起来」。
int wm_tray_popup(int slot) {
  @autoreleasepool {
    if (slot <= 0 || slot >= WM_MAX_TRAYS || wm_tray_items[slot] == nil) {
      return 0;
    }
    NSMenu *m = wm_tray_menus[slot];
    if (m == nil) {
      return 0;
    }
    NSStatusBarButton *btn = [wm_tray_items[slot] button];
    if (btn == nil) {
      return 0;
    }
    BOOL ok = [m popUpMenuPositioningItem:nil
                               atLocation:NSMakePoint(0, btn.bounds.size.height)
                                   inView:btn];
    return ok ? 1 : 0;
  }
}

void wm_tray_remove(int slot) {
  @autoreleasepool {
    if (slot <= 0 || slot >= WM_MAX_TRAYS || wm_tray_items[slot] == nil) {
      return;
    }
    NSStatusItem *item = wm_tray_items[slot];
    [[item button] setTarget:nil];
    [[item button] setAction:nil];
    [[NSStatusBar systemStatusBar] removeStatusItem:item];
    wm_tray_items[slot] = nil;
    wm_tray_menus[slot] = nil;
    wm_tray_kind[slot] = 0;
    wm_tray_tips[slot][0] = '\0';
  }
}

int wm_tray_poll(int32_t *out_slot, int32_t *out_kind) {
  if (wm_tray_ev_count <= 0) {
    return 0;
  }
  int ev = wm_tray_events[wm_tray_ev_head];
  wm_tray_ev_head = (wm_tray_ev_head + 1) % WM_TRAY_EV_MAX;
  wm_tray_ev_count--;
  if (out_slot != NULL) {
    *out_slot = ev / 4;
  }
  if (out_kind != NULL) {
    *out_kind = ev % 4;
  }
  return 1;
}

int wm_tray_count(void) {
  int n = 0;
  for (int i = 1; i < WM_MAX_TRAYS; i++) {
    if (wm_tray_items[i] != nil && wm_tray_kind[i] == 0) {
      n++;
    }
  }
  return n;
}

int wm_tray_tooltip(int slot, char *out, int cap) {
  if (slot <= 0 || slot >= WM_MAX_TRAYS || wm_tray_items[slot] == nil) {
    return wm_clamp_cap(out, cap, "");
  }
  return wm_clamp_cap(out, cap, wm_tray_tips[slot]);
}

// ---- 桌面通知（NSUserNotification）--------------------------------------
//
// 与 Win32 支的托盘气泡不同，macOS 有系统级通知中心；UNUserNotificationCenter
// 要求调用者是**已签名的 bundle**（裸二进制拿不到授权），所以这里用仍在
// SDK 里的 NSUserNotification 一档（deprecated 但可用），`kind` 只映射到
// 提示音：>=2 响一声，其余静默（mac 没有「进度/严重程度」的原生对位）。
//
// 一条待真机确认的口径：非 bundle 进程投递的通知可能被系统丢弃。这里
// 如实返回槽号（表示「已交给系统」），是否弹出由 `docs/zh/adaptation.md`
// 的 macOS 复验清单目视定。

static NSUserNotification *wm_notifs[WM_MAX_TRAYS];

int wm_notify_supported(void) {
  @autoreleasepool {
    return [NSUserNotificationCenter defaultUserNotificationCenter] != nil ? 1
                                                                           : 0;
  }
}

static int wm_notify_slot_of(int slot) {
  return slot > 0 && slot < WM_MAX_TRAYS ? slot : 0;
}

static int wm_notify_alloc(const char *title, const char *text, int kind) {
  NSUserNotificationCenter *nc = [NSUserNotificationCenter defaultUserNotificationCenter];
  if (nc == nil) {
    return 0;
  }
  int slot = -1;
  for (int i = 1; i < WM_MAX_TRAYS; i++) {
    if (wm_notifs[i] == nil) {
      slot = i;
      break;
    }
  }
  if (slot < 0) {
    return 0;
  }
  NSUserNotification *n = [[NSUserNotification alloc] init];
  NSString *t = wm_str(title);
  NSString *b = wm_str(text);
  if (t != nil) {
    [n setTitle:t];
  }
  if (b != nil) {
    [n setInformativeText:b];
  }
  [n setIdentifier:[NSString stringWithFormat:@"native-gui-%d", slot]];
  [n setSoundName:kind >= 2 ? NSUserNotificationDefaultSoundName : nil];
  [n setDeliveryDate:[NSDate distantFuture]]; // 停在通知中心直到本层收起
  [nc deliverNotification:n];
  wm_notifs[slot] = n;
  return slot;
}

int wm_notify_send(int icon_slot, const char *title, const char *text,
                   int kind) {
  @autoreleasepool {
    (void)icon_slot; // mac 的通知不带自定义图标（NSUserNotification 无此入口）
    return wm_notify_alloc(title, text, kind);
  }
}

int wm_notify_update(int slot, const char *title, const char *text, int kind) {
  @autoreleasepool {
    slot = wm_notify_slot_of(slot);
    if (slot == 0) {
      return wm_notify_alloc(title, text, kind);
    }
    NSUserNotification *n = wm_notifs[slot];
    if (n == nil) {
      return 0;
    }
    NSString *t = wm_str(title);
    NSString *b = wm_str(text);
    if (t != nil) {
      [n setTitle:t];
    }
    if (b != nil) {
      [n setInformativeText:b];
    }
    [n setSoundName:kind >= 2 ? NSUserNotificationDefaultSoundName : nil];
    [[NSUserNotificationCenter defaultUserNotificationCenter]
        deliverNotification:n]; // 同 identifier 即替换
    return 1;
  }
}

void wm_notify_close(int slot) {
  @autoreleasepool {
    slot = wm_notify_slot_of(slot);
    if (slot == 0) {
      return;
    }
    NSUserNotification *n = wm_notifs[slot];
    if (n != nil) {
      NSUserNotificationCenter *nc =
          [NSUserNotificationCenter defaultUserNotificationCenter];
      [nc removeDeliveredNotification:n];
      [nc removeScheduledNotification:n];
    }
    wm_notifs[slot] = nil;
  }
}

int wm_notify_count(void) {
  int n = 0;
  for (int i = 1; i < WM_MAX_TRAYS; i++) {
    if (wm_notifs[i] != nil) {
      n++;
    }
  }
  return n;
}

int wm_notify_title(int slot, char *out, int cap) {
  @autoreleasepool {
    slot = wm_notify_slot_of(slot);
    NSUserNotification *n = slot == 0 ? nil : wm_notifs[slot];
    if (n == nil) {
      return wm_clamp_cap(out, cap, "");
    }
    return wm_clamp_cap(out, cap, [[n title] UTF8String]);
  }
}

// ---- 任务栏进度 -----------------------------------------------------------
//
// macOS 没有任务栏按钮：dock 徽标只有一枚文本角标，画不出「进度条 + 状态色」
// 那一档语义。按跨平台门面口径给 supported = 0，让门面走 unsupported 降级，
// 不拿角标冒充进度。
int wm_taskbar_supported(void) { return 0; }
int wm_taskbar_set_progress(int64_t wid, int64_t value, int64_t total) {
  (void)wid;
  (void)value;
  (void)total;
  return 0;
}
int wm_taskbar_set_state(int64_t wid, int state) {
  (void)wid;
  (void)state;
  return 0;
}

// ---- 原生消息框（NSAlert）------------------------------------------------
//
// MoonBit 侧把「图标段 ∪ 按钮段 ∪ 默认钮段」按 Win32 的 uType 口径算好传过来
// （core 的门面跨平台同签名），这里按段还原成 NSAlert 的按钮与图标样式，
// 返回值给回 Win32 的 ID* 编号（1 OK / 2 Cancel / 3 Abort / 4 Retry /
// 5 Ignore / 6 Yes / 7 No），门面按同一张表解释。
int wm_message_box(const char *title, const char *text, int utype) {
  @autoreleasepool {
    NSAlert *alert = [[NSAlert alloc] init];
    NSString *t = wm_str(title);
    NSString *x = wm_str(text);
    [alert setMessageText:(t != nil ? t : @"")];
    [alert setInformativeText:(x != nil ? x : @"")];
    // 按钮段 → 按 Win32 的按钮顺序建（NSAlert 的第 N 个钮对应第 N 个返回档）
    int btns = utype & 0xf;
    switch (btns) {
      case 1: // MB_OKCANCEL
        [alert addButtonWithTitle:@"OK"];
        [alert addButtonWithTitle:@"Cancel"];
        break;
      case 2: // MB_ABORTRETRYIGNORE
        [alert addButtonWithTitle:@"Abort"];
        [alert addButtonWithTitle:@"Retry"];
        [alert addButtonWithTitle:@"Ignore"];
        break;
      case 3: // MB_YESNOCANCEL
        [alert addButtonWithTitle:@"Yes"];
        [alert addButtonWithTitle:@"No"];
        [alert addButtonWithTitle:@"Cancel"];
        break;
      case 4: // MB_YESNO
        [alert addButtonWithTitle:@"Yes"];
        [alert addButtonWithTitle:@"No"];
        break;
      case 5: // MB_RETRYCANCEL
        [alert addButtonWithTitle:@"Retry"];
        [alert addButtonWithTitle:@"Cancel"];
        break;
      default: // MB_OK
        [alert addButtonWithTitle:@"OK"];
        break;
    }
    switch ((utype >> 4) & 0xf) {
      case 1: [alert setAlertStyle:NSAlertStyleCritical]; break; // MB_ICONHAND
      case 2: [alert setAlertStyle:NSAlertStyleInformational]; break; // QUESTION
      case 3: [alert setAlertStyle:NSAlertStyleWarning]; break;  // WARNING
      case 4: [alert setAlertStyle:NSAlertStyleInformational]; break; // ASTERISK
      default: break;
    }
    NSInteger r = [alert runModal];
    int index = 0; // 0 第一钮 / 1 第二钮 / 2 第三钮
    if (r == NSAlertSecondButtonReturn) {
      index = 1;
    } else if (r == NSAlertThirdButtonReturn) {
      index = 2;
    }
    // 位置 → Win32 返回值编号（IDOK 1 / IDCANCEL 2 / IDABORT 3 / IDRETRY 4 /
    // IDIGNORE 5 / IDYES 6 / IDNO 7）。默认钮位（MB_DEFBUTTON2/3/4）不映射：
    // NSAlert 的首钮就是默认钮，改顺序会破坏「返回值按段序解释」这条口径，
    // 记档在 docs/zh/adaptation.md 的 macOS 差异里。
    static const int id_map[6][3] = {
        {1, 1, 1}, // OK
        {1, 2, 2}, // OKCancel
        {3, 4, 5}, // AbortRetryIgnore
        {6, 7, 2}, // YesNoCancel
        {6, 7, 7}, // YesNo
        {4, 2, 2}, // RetryCancel
    };
    return id_map[btns > 5 ? 0 : btns][index];
  }
}

#elif !defined(__linux__) && !defined(__APPLE__)

/* 剪贴板三符号（占位）：macOS 走 sys 自己的 pbpaste/pbcopy 命令线。 */
int wm_clipboard_available(void) { return 0; }
void *wm_clipboard_get_text(int32_t *ok) {
  *ok = 0;
  return moonbit_make_bytes(0, 0);
}
int wm_clipboard_set_text(const char *text) {
  (void)text;
  return 0;
}

// ---------------- 其余平台（macOS 等）占位 ----------------
// 保证 `moon build --target native` 的符号不断；真后端随各自窗口层落地补。

#include <stdint.h>

int wm_init(void) {
  return 0;
}

int64_t wm_window_new(int width, int height, const char *title) {
  (void)width;
  (void)height;
  (void)title;
  return 0;
}

void wm_show(int64_t id) {
  (void)id;
}

void wm_size(int64_t id, int32_t *out_w, int32_t *out_h) {
  (void)id;
  (void)out_w;
  (void)out_h;
}

int wm_event(int64_t id) {
  (void)id;
  return 0;
}

// 占位分支没有窗口，也就没有焦点可言：一律 0（= 整窗无焦点，上层不清焦点栈）
int wm_focus_owner(int64_t id) {
  (void)id;
  return 0;
}

int wm_take_event(int64_t id) {
  (void)id;
  return -1;
}

int wm_pending_events(int64_t id) {
  (void)id;
  return 0;
}

int32_t wm_ev_keysym(int64_t id) { (void)id; return 0; }
int32_t wm_ev_mods(int64_t id) { (void)id; return 0; }
int32_t wm_ev_x(int64_t id) { (void)id; return 0; }
int32_t wm_ev_y(int64_t id) { (void)id; return 0; }
int32_t wm_ev_button(int64_t id) { (void)id; return 0; }
int32_t wm_ev_axis(int64_t id) { (void)id; return 0; }

void wm_present(int64_t id, const unsigned char *rgba, int width, int height) {
  (void)id;
  (void)rgba;
  (void)width;
  (void)height;
}

void wm_close(int64_t id) {
  (void)id;
}

void wm_pump(void) {}

int wm_wait(int timeout_ms) {
  (void)timeout_ms;
  return 0;
}

void wm_request_focus(int64_t id) { (void)id; }

void wm_im_set_surrounding(int64_t id, const char *text, int caret) {
  (void)id; (void)text; (void)caret;
}
int wm_sys_color_scheme(char *out, int cap) { (void)out; (void)cap; return 0; }
int wm_sys_accent(char *out, int cap) { (void)out; (void)cap; return 0; }

void wm_set_cursor(int64_t id, int kind) {
  (void)id; (void)kind;
}
void wm_im_set_cursor(int64_t id, int x, int y, int w, int h) {
  (void)id; (void)x; (void)y; (void)w; (void)h;
}
void wm_im_reset(int64_t id) { (void)id; }
int wm_im_commit_len(int64_t id) { (void)id; return 0; }
int wm_im_commit_byte(int64_t id, int index) { (void)id; (void)index; return 0; }
void wm_im_commit_done(int64_t id) { (void)id; }
int wm_im_preedit_len(int64_t id) { (void)id; return 0; }
int wm_im_preedit_byte(int64_t id, int index) { (void)id; (void)index; return 0; }
int wm_im_preedit_caret(int64_t id) { (void)id; return 0; }
int wm_im_preedit_active(int64_t id) { (void)id; return 0; }

void wm_wakeup(void) {}

int wm_hotkey_register(int mods, int vk) {
  (void)mods;
  (void)vk;
  return 0;
}

void wm_hotkey_unregister(int id) { (void)id; }

int wm_hotkey_poll(void) { return 0; }

/* W20a 菜单占位（macOS 等）：句柄 0 = 建失败，MoonBit 层走语义化降级。
 * macOS 原生档是 NSMenu（ObjectC++ 单独 TU，将来随 mac 平台批补）。*/
int wm_menu_bar_new(void) { return 0; }
int wm_menu_new_sub(int parent, const char *title) {
  (void)parent;
  (void)title;
  return 0;
}
int wm_menu_add_item(int parent, const char *label, int kind, int role,
                     const char *acc, int checked) {
  (void)parent;
  (void)label;
  (void)kind;
  (void)role;
  (void)acc;
  (void)checked;
  return 0;
}
void wm_menu_apply(int64_t id, int bar) {
  (void)id;
  (void)bar;
}
int wm_menu_poll(void) { return 0; }

/* W20f 图标加载占位（macOS 等）：HICON 是 Win32 概念，句柄 0 = 不可用。 */
int wm_icon_from_bgra(const unsigned char *px, int w, int h) {
  (void)px;
  (void)w;
  (void)h;
  return 0;
}
int wm_icon_load_file(const char *path, int size) {
  (void)path;
  (void)size;
  return 0;
}
int wm_icon_from_png(const unsigned char *data, int len) {
  (void)data;
  (void)len;
  return 0;
}
void wm_icon_free(int slot) { (void)slot; }
int wm_icon_alive(void) { return 0; }
void *wm_icon_handle(int slot) {
  (void)slot;
  return NULL;
}

/* W20e 窗口增强占位（macOS 等）：空实现 + 反读恒 0。 */
void wm_set_title(int64_t id, const char *title) {
  (void)id;
  (void)title;
}
void wm_set_icon(int64_t id, int icon_slot, int which) {
  (void)id;
  (void)icon_slot;
  (void)which;
}
void wm_set_min_size(int64_t id, int wmin, int hmin) {
  (void)id;
  (void)wmin;
  (void)hmin;
}
void wm_set_drag_rect(int64_t id, int x, int y, int w, int h) {
  (void)id;
  (void)x;
  (void)y;
  (void)w;
  (void)h;
}
void wm_set_borderless(int64_t id, int on) {
  (void)id;
  (void)on;
}
void wm_get_min_size(int64_t id, int32_t *out_w, int32_t *out_h) {
  (void)id;
  if (out_w != NULL) {
    *out_w = 0;
  }
  if (out_h != NULL) {
    *out_h = 0;
  }
}
void wm_get_drag_rect(int64_t id, int32_t *x, int32_t *y, int32_t *w,
                      int32_t *h) {
  (void)id;
  if (x != NULL) {
    *x = 0;
  }
  if (y != NULL) {
    *y = 0;
  }
  if (w != NULL) {
    *w = 0;
  }
  if (h != NULL) {
    *h = 0;
  }
}
int wm_is_borderless(int64_t id) {
  (void)id;
  return 0;
}
int wm_window_title(int64_t id, char *out, int cap) {
  (void)id;
  if (out != NULL && cap > 0) {
    out[0] = '\0';
  }
  return 0;
}

/* W20c 托盘占位（macOS 等）：supported 恒 0、建项恒 0 = 不可用，MoonBit 层
 * 走语义化降级（macOS 原生档是 NSStatusItem，ObjectC++ 单独 TU，将来随 mac
 * 平台批补）。 */
int wm_tray_supported(void) { return 0; }
int wm_tray_new(int icon_slot, const char *tip) {
  (void)icon_slot;
  (void)tip;
  return 0;
}
void wm_tray_set_tooltip(int slot, const char *tip) {
  (void)slot;
  (void)tip;
}
void wm_tray_set_icon(int slot, int icon_slot) {
  (void)slot;
  (void)icon_slot;
}
void wm_tray_set_menu(int slot, int menu_handle) {
  (void)slot;
  (void)menu_handle;
}
int wm_tray_popup(int slot) {
  (void)slot;
  return 0;
}
void wm_tray_remove(int slot) { (void)slot; }
int wm_tray_poll(int32_t *out_slot, int32_t *out_kind) {
  (void)out_slot;
  (void)out_kind;
  return 0;
}
int wm_tray_count(void) { return 0; }
int wm_tray_tooltip(int slot, char *out, int cap) {
  (void)slot;
  if (out != NULL && cap > 0) {
    out[0] = '\0';
  }
  return 0;
}
int wm_menu_popup_new(void) { return 0; }

/* W21a 通知占位（macOS 等）：supported 恒 0、发/更新恒 0 = 不可用，MoonBit 层
 * 走语义化降级（macOS 原生档是 NSUserNotification/UNUserNotificationCenter，
 * 将来随 mac 平台批补）。 */
int wm_notify_supported(void) { return 0; }
int wm_notify_send(int icon_slot, const char *title, const char *text,
                   int kind) {
  (void)icon_slot;
  (void)title;
  (void)text;
  (void)kind;
  return 0;
}
/* 任务栏进度（§6.3）占位：Linux 的任务栏进度另有 Unity LauncherEntry（DBus）
 * 路径、macOS 是 dock 徽标（NSDockTile），都归跨平台门面批；这里的失败桩让
 * 门面走 unsupported 降级，不断链接符号。 */
int wm_taskbar_supported(void) { return 0; }
int wm_taskbar_set_progress(int64_t id, int64_t value, int64_t total) {
  (void)id;
  (void)value;
  (void)total;
  return 0;
}
int wm_taskbar_set_state(int64_t id, int state) {
  (void)id;
  (void)state;
  return 0;
}
int wm_notify_update(int slot, const char *title, const char *text, int kind) {
  (void)slot;
  (void)title;
  (void)text;
  (void)kind;
  return 0;
}
void wm_notify_close(int slot) { (void)slot; }
int wm_notify_count(void) { return 0; }
int wm_notify_title(int slot, char *out, int cap) {
  (void)slot;
  if (out != NULL && cap > 0) {
    out[0] = '\0';
  }
  return 0;
}

/* W20d 消息框占位（macOS 等）：返回 0 = 失败，MoonBit 层走语义化降级。
 * macOS 原生档是 NSAlert（ObjectC++ 单独 TU，将来随 mac 平台批补）。*/
int wm_message_box(const char *title, const char *text, int utype) {
  (void)title;
  (void)text;
  (void)utype;
  return 0;
}

int64_t wm_now_ms(void) {
  return 0;
}

int64_t wm_local_date(void) {
  return 0;
}

// 原生子件通道占位（同上：符号必须在，实现随平台批）
int64_t wm_surface_new(int64_t window_id, int kind, int x, int y, int w,
                       int h) {
  (void)window_id; (void)kind; (void)x; (void)y; (void)w; (void)h;
  return 0;
}
void wm_surface_set_rect(int64_t surface_id, int x, int y, int w, int h) {
  (void)surface_id; (void)x; (void)y; (void)w; (void)h;
}
void wm_surface_close(int64_t surface_id) { (void)surface_id; }
void wm_window_set_popup(int64_t id, int64_t owner_id) { (void)id; (void)owner_id; }
void wm_window_move(int64_t id, int x, int y) { (void)id; (void)x; (void)y; }
void wm_window_origin(int64_t id, int32_t *out_x, int32_t *out_y) {
  (void)id; (void)out_x; (void)out_y;
}

void wm_window_set_size(int64_t id, int w, int h) { (void)id; (void)w; (void)h; }
void wm_window_set_fullscreen(int64_t id, int on) { (void)id; (void)on; }
int wm_window_surface_count(int64_t id) {
  (void)id;
  return 0;
}
void *wm_surface_container(int64_t surface_id) {
  (void)surface_id;
  return NULL;
}

#endif
// Linux 上 native-stub 的那次编译（无 _WIN32、无 WM_STUB_GTK）落不进任何
// 分支，编出空翻译单元——GTK 实现由 prebuild 的 libyue_win_stub.a 提供，
// 这里绝不能再定义一份（双定义）。
