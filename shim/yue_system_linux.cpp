// 系统能力直连组 · Linux 哨兵桩：Linux 侧由 MoonBit 走子进程解析文本
// （wpctl / xrandr / lpstat 等），不经过这些符号；桩仅为链接期符号存在
// （MoonBit 二进制所有平台都含 FFI 调用点，缺符号即链接失败）。
//
// 由 CMake 在「非 WIN32 且非 APPLE」时挂载，与 yue_system_win.cpp、
// yue_system_mac.mm 互斥——三份实现的符号集完全一致，挂载互斥故符号唯一
// 定义，不需要 #if 宏分支。

#include "yue_mbt.h"
#include "yue_mbt_internal.h"
       // 不经过这些符号，桩仅为链接期符号存在。macOS 直连实现见
       // yue_system_mac.mm——同名符号由该 TU 提供，此分支在 mac 下不编。

extern "C" void *yue_mbt_win_reg_str(int32_t, const char *, const char *,
                                     int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" int32_t yue_mbt_win_memory(int64_t *, int64_t *) { return -1000; }

extern "C" int64_t yue_mbt_win_uptime_ms(void) { return -1; }

extern "C" void *yue_mbt_wallpaper_get(int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" int32_t yue_mbt_wallpaper_set(const char *, int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" void *yue_mbt_win_tz_name(int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" void *yue_mbt_win_lang(int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" int32_t yue_mbt_win_ntp_running(int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" int32_t yue_mbt_win_shutdown(int32_t, int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" int32_t yue_mbt_power_active_guid(uint8_t *, int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" int32_t yue_mbt_power_set_guid(const uint8_t *, int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" int32_t yue_mbt_power_enumerate_guids(uint8_t *, int32_t,
                                                 int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" void *yue_mbt_brightness_devices(int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" int32_t yue_mbt_brightness_get(int32_t, int32_t *, int32_t *,
                                          int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" int32_t yue_mbt_brightness_set(int32_t, int32_t, int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" void *yue_mbt_wmi_brightness_devices(int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" int32_t yue_mbt_wmi_brightness_get(int32_t *, int32_t *,
                                              int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" int32_t yue_mbt_wmi_brightness_set(int32_t, int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" void *yue_mbt_bt_radio_info(int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" void *yue_mbt_bt_devices(int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" int32_t yue_mbt_vol_master(double *, int32_t *, int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" int32_t yue_mbt_vol_set_master(double, int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" int32_t yue_mbt_vol_set_mute(int32_t, int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" void *yue_mbt_mon_list(int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" void *yue_mbt_prt_list(int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" void *yue_mbt_prt_default(int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" void *yue_mbt_prt_queue(const char *, int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" int32_t yue_mbt_prt_print(const char *, int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" void *yue_mbt_clipboard_text(int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" void *yue_mbt_win_list_windows(int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" int32_t yue_mbt_win_activate_window(const char *, int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" int32_t yue_mbt_win_close_window(const char *, int32_t *ok) {
  *ok = 0;
  return -1000;
}

extern "C" void *yue_mbt_assoc_query(const char *, int32_t, int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" void *yue_mbt_lnk_target(const char *, int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

extern "C" void *yue_mbt_dsk_volumes(int32_t *ok) {
  *ok = -1000;
  return moonbit_make_bytes(0, 0);
}

