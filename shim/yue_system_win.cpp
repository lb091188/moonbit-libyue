// 系统能力直连组 · Windows 实现：Win32 API 直连（sysinfo / wallpaper /
// locale / powerctl / powerprofile / brightness / volume / monitor /
// printer / clipboard / windowctl / defaultapps / recent / disk）。
//
// 与 Linux 侧「子进程解析文本」不同，Windows 一律 Win32 API 直连（CI 与
// 真机都没有可依赖的 POSIX 工具链）。除标注外全部形如
//   返回 Bytes 的：打不开/查不到 ok=0 返回空文本；
//   出参 int 的：ok=0 表示失败。
//
// 由 CMake 在 WIN32 下挂载，与 yue_system_mac.mm（APPLE）、
// yue_system_linux.cpp（Linux 哨兵桩）互斥——三份实现的符号集完全一致，
// 挂载互斥故符号唯一定义，不需要 #if 宏分支。

#if defined(_MSC_VER)
#define _USE_MATH_DEFINES
#endif
#include <windows.h>
#include <shobjidl.h>
#include <winreg.h>
#include <shellapi.h>
#include <richedit.h>
#include <commctrl.h>
#include <dwmapi.h>
#include <wtsapi32.h>

#include "yue_mbt.h"
#include "yue_mbt_internal.h"
#include "base/command_line.h"
#include "base/strings/sys_string_conversions.h"
#include "nativeui/nativeui.h"
#include "nativeui/win/window_win.h" // WindowImpl::hwnd()
#include "nativeui/win/subwin_view.h" // SubwinView::hwnd()
#include "nativeui/win/view_win.h" // ViewImpl::wheel_hook
#include "nativeui/win/util/tray_host.h" // TrayHost::hwnd()
#include "nativeui/gfx/win/double_buffer.h" // Canvas 位图导出

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

using yue_mbt::BytesFromString;
#include <endpointvolume.h>
#include <bluetoothapis.h> // 蓝牙无线电/已知设备枚举（经典 BluetoothAPIs）
#include <highlevelmonitorconfigurationapi.h> // Get/SetMonitorBrightness
#include <lowlevelmonitorconfigurationapi.h> // DDC 物理监视器 API
#include <mmdeviceapi.h>
#include <powrprof.h>
#include <shlwapi.h>
#include <string>
#include <wbemidl.h> // WMI 内屏亮度（WmiMonitorBrightness）
#include <winspool.h>

// ---- sysinfo：注册表字符串 / 内存 / 开机时长 ----

// root: 0=HKLM 1=HKCU；读 REG_SZ / REG_EXPAND_SZ（展开后）
extern "C" void *yue_mbt_win_reg_str(int32_t root, const char *path,
                                     const char *value, int32_t *ok) {
  *ok = 0;
  HKEY root_key = root == 1 ? HKEY_CURRENT_USER : HKEY_LOCAL_MACHINE;
  HKEY key = nullptr;
  if (::RegOpenKeyExW(root_key, base::SysUTF8ToWide(path).c_str(), 0,
                      KEY_QUERY_VALUE, &key) != ERROR_SUCCESS) {
    return moonbit_make_bytes(0, 0);
  }
  wchar_t buf[1024];
  DWORD size = sizeof(buf);
  DWORD type = 0;
  LSTATUS r = ::RegQueryValueExW(key, base::SysUTF8ToWide(value).c_str(),
                                 nullptr, &type,
                                 reinterpret_cast<LPBYTE>(buf), &size);
  ::RegCloseKey(key);
  if (r != ERROR_SUCCESS ||
      (type != REG_SZ && type != REG_EXPAND_SZ) || size < sizeof(wchar_t)) {
    return moonbit_make_bytes(0, 0);
  }
  buf[size / sizeof(wchar_t) - (size % sizeof(wchar_t) == 0 ? 1 : 0)] = 0;
  wchar_t expanded[1024];
  wchar_t *final_str = buf;
  if (type == REG_EXPAND_SZ) {
    DWORD n = ::ExpandEnvironmentStringsW(buf, expanded,
                                          static_cast<DWORD>(1024));
    if (n > 0 && n <= 1024) {
      final_str = expanded;
    }
  }
  *ok = 1;
  return BytesFromString(base::SysWideToUTF8(final_str));
}

extern "C" int32_t yue_mbt_win_memory(int64_t *total_kb, int64_t *avail_kb) {
  MEMORYSTATUSEX mem;
  mem.dwLength = sizeof(mem);
  if (::GlobalMemoryStatusEx(&mem) != TRUE) {
    return 0;
  }
  *total_kb = static_cast<int64_t>(mem.ullTotalPhys / 1024);
  *avail_kb = static_cast<int64_t>(mem.ullAvailPhys / 1024);
  return 1;
}

extern "C" int64_t yue_mbt_win_uptime_ms(void) {
  return static_cast<int64_t>(::GetTickCount64());
}

// ---- 壁纸 ----

extern "C" void *yue_mbt_wallpaper_get(int32_t *ok) {
  *ok = 0;
  wchar_t buf[MAX_PATH];
  // 第二参为缓冲字节大小（含结尾 NUL），返回 TRUE 即有效
  if (::SystemParametersInfoW(SPI_GETDESKWALLPAPER, MAX_PATH, buf, 0) != TRUE) {
    return moonbit_make_bytes(0, 0);
  }
  *ok = 1;
  return BytesFromString(base::SysWideToUTF8(buf));
}

extern "C" int32_t yue_mbt_wallpaper_set(const char *path, int32_t *ok) {
  *ok = 0;
  std::wstring p = base::SysUTF8ToWide(path);
  BOOL r = ::SystemParametersInfoW(SPI_SETDESKWALLPAPER, 0, &p[0],
                                   SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
  if (r != TRUE) {
    return -1;
  }
  *ok = 1;
  return 0;
}

// ---- locale：时区名 / 界面语言 / W32Time 服务在跑 ----

extern "C" void *yue_mbt_win_tz_name(int32_t *ok) {
  *ok = 0;
  // 动态时区信息带 TimeZoneKeyName（如 "China Standard Time"，Windows
  // 时区键名，非 IANA 名——语义差异由 MoonBit 层文档化）
  // 所需 _WIN32_WINNT 在 libyue 构建链恒 >= 0x0600
  DYNAMIC_TIME_ZONE_INFORMATION tz;
  ZeroMemory(&tz, sizeof(tz));
  DWORD r = ::GetDynamicTimeZoneInformation(&tz);
  if (r == TIME_ZONE_ID_INVALID || tz.TimeZoneKeyName[0] == 0) {
    return moonbit_make_bytes(0, 0);
  }
  *ok = 1;
  return BytesFromString(base::SysWideToUTF8(tz.TimeZoneKeyName));
}

extern "C" void *yue_mbt_win_lang(int32_t *ok) {
  *ok = 0;
  wchar_t buf[LOCALE_NAME_MAX_LENGTH];
  int n = ::GetUserDefaultLocaleName(buf, LOCALE_NAME_MAX_LENGTH);
  if (n <= 0) {
    return moonbit_make_bytes(0, 0);
  }
  *ok = 1;
  return BytesFromString(base::SysWideToUTF8(buf));
}

extern "C" int32_t yue_mbt_win_ntp_running(int32_t *ok) {
  *ok = 0;
  SC_HANDLE scm = ::OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
  if (scm == nullptr) {
    return -1;
  }
  SC_HANDLE svc =
      ::OpenServiceW(scm, L"W32Time", SERVICE_QUERY_STATUS);
  if (svc == nullptr) {
    ::CloseServiceHandle(scm);
    return -1;
  }
  SERVICE_STATUS_PROCESS status;
  DWORD needed = 0;
  BOOL good = ::QueryServiceStatusEx(
      svc, SC_STATUS_PROCESS_INFO,
      reinterpret_cast<LPBYTE>(&status), sizeof(status), &needed);
  ::CloseServiceHandle(svc);
  ::CloseServiceHandle(scm);
  if (good != TRUE) {
    return -1;
  }
  *ok = 1;
  return status.dwCurrentState == SERVICE_RUNNING ? 1 : 0;
}

// ---- powerctl：关机 / 重启 / 注销（当前用户） ----

namespace {

// ExitWindowsEx 需要 SE_SHUTDOWN_NAME 特权（默认不持有），临时开通
bool mbt_enable_shutdown_privilege() {
  HANDLE token = nullptr;
  if (::OpenProcessToken(::GetCurrentProcess(),
                         TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
                         &token) != TRUE) {
    return false;
  }
  TOKEN_PRIVILEGES tp;
  tp.PrivilegeCount = 1;
  tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
  if (::LookupPrivilegeValueW(nullptr, SE_SHUTDOWN_NAME,
                              &tp.Privileges[0].Luid) != TRUE) {
    ::CloseHandle(token);
    return false;
  }
  BOOL ok = ::AdjustTokenPrivileges(token, FALSE, &tp, sizeof(tp), nullptr,
                                    nullptr);
  ::CloseHandle(token);
  return ok == TRUE && ::GetLastError() == ERROR_SUCCESS;
}

}  // namespace

// how: 0=关机 1=重启 2=注销当前用户（温和模式：EWX_FORCEIFHUNG 只杀挂起
// 进程，不像 EWX_FORCE 无差别强杀）
extern "C" int32_t yue_mbt_win_shutdown(int32_t how, int32_t *ok) {
  *ok = 0;
  UINT flags = 0;
  if (how == 0) {
    flags = EWX_POWEROFF | EWX_FORCEIFHUNG;
  } else if (how == 1) {
    flags = EWX_REBOOT | EWX_FORCEIFHUNG;
  } else if (how == 2) {
    flags = EWX_LOGOFF | EWX_FORCEIFHUNG;
  } else {
    return -87;
  }
  if (!mbt_enable_shutdown_privilege()) {
    return -static_cast<int32_t>(::GetLastError());
  }
  if (::ExitWindowsEx(flags, SHTDN_REASON_FLAG_PLANNED) != TRUE) {
    return -static_cast<int32_t>(::GetLastError());
  }
  *ok = 1;
  return 0;
}

// ---- 亮度：物理监视器 DDC/CI（Dxva2） ----
// 设备枚举输出 '\n' 分行的 "name\tmax\tcur" 文本（name 为 \\.\DISPLAYn）；
// get/set 按 index 重新枚举物理监视器（与 devices 同序，每次调用自洽，
// 不跨调用持句柄）。内建面板通常不走 DDC/CI（走 WMI，本批不实现）。

namespace {

struct MbMonitorList {
  HMONITOR handles[16];
  std::wstring devices[16];
  int count;
};

BOOL CALLBACK mbt_monitor_enum(HMONITOR mon, HDC, LPRECT, LPARAM lparam) {
  auto *list = reinterpret_cast<MbMonitorList *>(lparam);
  if (list->count >= 16) {
    return FALSE;
  }
  MONITORINFOEXW info;
  ZeroMemory(&info, sizeof(info));
  info.cbSize = sizeof(info);
  if (::GetMonitorInfoW(mon, &info) == TRUE) {
    list->handles[list->count] = mon;
    list->devices[list->count] = info.szDevice;
    list->count++;
  }
  return TRUE;
}

int mbt_collect_monitors(MbMonitorList *list) {
  list->count = 0;
  ::EnumDisplayMonitors(nullptr, nullptr, mbt_monitor_enum,
                        reinterpret_cast<LPARAM>(list));
  return list->count;
}

// 枚举序第 index 个 DDC 可读监视器：out_cur/max 为量程，返回 1 命中
int mbt_ddc_at(int32_t index, DWORD *out_cur, DWORD *out_max,
               std::wstring *out_name) {
  MbMonitorList list;
  mbt_collect_monitors(&list);
  int hit = 0;
  for (int i = 0; i < list.count; i++) {
    DWORD n = 0;
    if (::GetNumberOfPhysicalMonitorsFromHMONITOR(list.handles[i], &n) != TRUE ||
        n == 0) {
      continue;
    }
    DWORD got = n < 8 ? n : 8;
    PHYSICAL_MONITOR mons[8];
    if (::GetPhysicalMonitorsFromHMONITOR(list.handles[i], got, mons) != TRUE) {
      continue;
    }
    for (DWORD m = 0; m < got; m++) {
      DWORD min_v = 0, cur = 0, max_v = 0;
      if (::GetMonitorBrightness(mons[m].hPhysicalMonitor, &min_v, &cur,
                                 &max_v) == TRUE &&
          max_v > min_v) {
        if (hit == index) {
          *out_cur = cur;
          *out_max = max_v;
          *out_name = list.devices[i];
          ::DestroyPhysicalMonitors(got, mons);
          return 1;
        }
        hit++;
      }
    }
    ::DestroyPhysicalMonitors(got, mons);
  }
  return 0;
}

}  // namespace

extern "C" void *yue_mbt_brightness_devices(int32_t *ok) {
  *ok = 0;
  std::string out;
  MbMonitorList list;
  mbt_collect_monitors(&list);
  for (int i = 0; i < list.count; i++) {
    DWORD n = 0;
    if (::GetNumberOfPhysicalMonitorsFromHMONITOR(list.handles[i], &n) != TRUE ||
        n == 0) {
      continue;
    }
    DWORD got = n < 8 ? n : 8;
    PHYSICAL_MONITOR mons[8];
    if (::GetPhysicalMonitorsFromHMONITOR(list.handles[i], got, mons) != TRUE) {
      continue;
    }
    for (DWORD m = 0; m < got; m++) {
      DWORD min_v = 0, cur = 0, max_v = 0;
      if (::GetMonitorBrightness(mons[m].hPhysicalMonitor, &min_v, &cur,
                                 &max_v) == TRUE &&
          max_v > min_v) {
        out += base::SysWideToUTF8(list.devices[i]);
        out += '\t';
        out += std::to_string(max_v);
        out += '\t';
        out += std::to_string(cur);
        out += '\n';
      }
    }
    ::DestroyPhysicalMonitors(got, mons);
  }
  *ok = 1;
  return BytesFromString(out);
}

// set 的 value 为设备量纲原始值（MoonBit 侧按 percent×max 换算）
extern "C" int32_t yue_mbt_brightness_set(int32_t index, int32_t value,
                                          int32_t *ok) {
  *ok = 0;
  MbMonitorList list;
  mbt_collect_monitors(&list);
  int hit = 0;
  for (int i = 0; i < list.count; i++) {
    DWORD n = 0;
    if (::GetNumberOfPhysicalMonitorsFromHMONITOR(list.handles[i], &n) != TRUE ||
        n == 0) {
      continue;
    }
    DWORD got = n < 8 ? n : 8;
    PHYSICAL_MONITOR mons[8];
    if (::GetPhysicalMonitorsFromHMONITOR(list.handles[i], got, mons) != TRUE) {
      continue;
    }
    for (DWORD m = 0; m < got; m++) {
      DWORD min_v = 0, cur = 0, max_v = 0;
      if (::GetMonitorBrightness(mons[m].hPhysicalMonitor, &min_v, &cur,
                                 &max_v) == TRUE &&
          max_v > min_v) {
        if (hit == index) {
          DWORD v = static_cast<DWORD>(value);
          if (v < min_v) v = min_v;
          if (v > max_v) v = max_v;
          BOOL good = ::SetMonitorBrightness(mons[m].hPhysicalMonitor, v);
          ::DestroyPhysicalMonitors(got, mons);
          if (good != TRUE) {
            return -1;
          }
          *ok = 1;
          return 0;
        }
        hit++;
      }
    }
    ::DestroyPhysicalMonitors(got, mons);
  }
  return -1;
}

// ---- 亮度：笔记本内屏 WMI（WmiMonitorBrightness / WmiSetBrightness）----
// DDC/CI 只覆盖外接显示器，内屏亮度走 WMI ROOT\WMI 命名空间。
// CurrentBrightness 语义就是 0-100 百分比（Levels 为灰阶级数）。

namespace {

// 连接 ROOT\WMI；调用方 Release
int mbt_wmi_services(IWbemServices **out_svc, bool *out_uninit) {
  *out_uninit = false;
  HRESULT hr = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (SUCCEEDED(hr)) {
    *out_uninit = true;
  } else if (hr != RPC_E_CHANGED_MODE) {
    return -1;
  }
  IWbemLocator *loc = nullptr;
  hr = ::CoCreateInstance(__uuidof(WbemLocator), nullptr, CLSCTX_INPROC_SERVER,
                          __uuidof(IWbemLocator),
                          reinterpret_cast<void **>(&loc));
  if (FAILED(hr) || loc == nullptr) {
    if (*out_uninit) {
      ::CoUninitialize();
    }
    return -1;
  }
  hr = loc->ConnectServer(
      ::SysAllocString(L"ROOT\\WMI"), nullptr, nullptr, nullptr, 0, nullptr,
      nullptr, out_svc);
  loc->Release();
  if (FAILED(hr) || *out_svc == nullptr) {
    if (*out_uninit) {
      ::CoUninitialize();
    }
    return -1;
  }
  // root\wmi 这类受保护命名空间必须显式设代理毯，否则 ExecQuery 得
  // WBEM_E_ACCESS_DENIED（80041003）
  hr = ::CoSetProxyBlanket(*out_svc, RPC_C_AUTHN_WINNT, RPC_C_AUTHN_NONE,
                           nullptr, RPC_C_AUTHN_LEVEL_CALL,
                           RPC_C_IMP_LEVEL_IMPERSONATE, nullptr, EOAC_NONE);
  hr = ::CoSetProxyBlanket(*out_svc, RPC_C_AUTHN_WINNT, RPC_C_AUTHN_NONE,
                           nullptr, RPC_C_AUTHN_LEVEL_CALL,
                           RPC_C_IMP_LEVEL_IMPERSONATE, nullptr, EOAC_NONE);
  if (FAILED(hr)) {
    (*out_svc)->Release();
    *out_svc = nullptr;
    if (*out_uninit) {
      ::CoUninitialize();
    }
    return -1;
  }
  return 0;
}

// 执行 WQL 查询并取首个对象；调用方 Release
int mbt_wmi_query_one(IWbemServices *svc, const wchar_t *wql,
                      IWbemClassObject **out_obj) {
  IEnumWbemClassObject *en = nullptr;
  BSTR lang = ::SysAllocString(L"WQL");
  BSTR q = ::SysAllocString(wql);
  HRESULT hr = svc->ExecQuery(lang, q, WBEM_FLAG_FORWARD_ONLY, nullptr, &en);
  ::SysFreeString(lang);
  ::SysFreeString(q);
  if (FAILED(hr) || en == nullptr) {
    return -1;
  }
  *out_obj = nullptr;
  ULONG got = 0;
  hr = en->Next(WBEM_INFINITE, 1, out_obj, &got);
  en->Release();
  if (FAILED(hr) || got == 0 || *out_obj == nullptr) {
    return -1;
  }
  return 0;
}

// 读对象整型属性；缺属性 / 类型不符返回 0 并置 ok=0
int32_t mbt_wmi_get_int(IWbemClassObject *obj, const wchar_t *prop,
                        int32_t *ok) {
  *ok = 0;
  VARIANT v;
  VariantInit(&v);
  HRESULT hr = obj->Get(prop, 0, &v, nullptr, nullptr);
  int32_t out = 0;
  if (SUCCEEDED(hr) && (v.vt == VT_I4 || v.vt == VT_UI4 || v.vt == VT_I2 ||
                        v.vt == VT_UI1)) {
    out = static_cast<int32_t>(v.lVal);
    *ok = 1;
  }
  VariantClear(&v);
  return out;
}

}  // namespace

// 内屏亮度枚举：查 WmiMonitorBrightness，输出 InstanceName（'\n' 分行，
// 每行一个名字）；无内屏 / WMI 不可用为空文本。
extern "C" void *yue_mbt_wmi_brightness_devices(int32_t *ok) {
  *ok = 0;
  bool uninit = false;
  IWbemServices *svc = nullptr;
  if (mbt_wmi_services(&svc, &uninit) != 0) {
    if (uninit) {
      ::CoUninitialize();
    }
    return BytesFromString("");
  }
  std::string out;
  IWbemClassObject *obj = nullptr;
  if (mbt_wmi_query_one(svc,
                        L"SELECT InstanceName FROM WmiMonitorBrightness",
                        &obj) == 0) {
    VARIANT v;
    VariantInit(&v);
    HRESULT gr = obj->Get(L"InstanceName", 0, &v, nullptr, nullptr);
    if (SUCCEEDED(gr) && v.vt == VT_BSTR && v.bstrVal != nullptr) {
      out = base::SysWideToUTF8(v.bstrVal);
    }
    VariantClear(&v);
    obj->Release();
  }
  svc->Release();
  if (uninit) {
    ::CoUninitialize();
  }
  *ok = 1;
  return BytesFromString(out);
}

// 内屏亮度读：CurrentBrightness（0-100）与 Levels（灰阶级数）
extern "C" int32_t yue_mbt_wmi_brightness_get(int32_t *cur, int32_t *levels,
                                              int32_t *ok) {
  *ok = 0;
  bool uninit = false;
  IWbemServices *svc = nullptr;
  if (mbt_wmi_services(&svc, &uninit) != 0) {
    if (uninit) {
      ::CoUninitialize();
    }
    return -1;
  }
  int32_t rc = -1;
  IWbemClassObject *obj = nullptr;
  if (mbt_wmi_query_one(svc, L"SELECT CurrentBrightness, Levels FROM WmiMonitorBrightness",
                        &obj) == 0) {
    int32_t c_ok = 0, l_ok = 0;
    int32_t c = mbt_wmi_get_int(obj, L"CurrentBrightness", &c_ok);
    int32_t l = mbt_wmi_get_int(obj, L"Levels", &l_ok);
    if (c_ok == 1) {
      *cur = c;
      *levels = l_ok == 1 ? l : 100;
      *ok = 1;
      rc = 0;
    }
    obj->Release();
  }
  svc->Release();
  if (uninit) {
    ::CoUninitialize();
  }
  return rc;
}

// 内屏亮度写：WmiMonitorBrightnessMethods 实例的 WmiSetBrightness(
// Timeout, Brightness)（Brightness 语义即 0-100）
extern "C" int32_t yue_mbt_wmi_brightness_set(int32_t percent, int32_t *ok) {
  *ok = 0;
  if (percent < 0) {
    percent = 0;
  }
  if (percent > 100) {
    percent = 100;
  }
  bool uninit = false;
  IWbemServices *svc = nullptr;
  if (mbt_wmi_services(&svc, &uninit) != 0) {
    if (uninit) {
      ::CoUninitialize();
    }
    return -1;
  }
  int32_t rc = -1;
  do {
    // 取 WmiMonitorBrightnessMethods 实例路径
    IWbemClassObject *obj = nullptr;
    if (mbt_wmi_query_one(
            svc, L"SELECT __PATH FROM WmiMonitorBrightnessMethods",
            &obj) != 0) {
      break;
    }
    VARIANT pv;
    VariantInit(&pv);
    bool have_path =
        obj->Get(L"__PATH", 0, &pv, nullptr, nullptr) == WBEM_S_NO_ERROR &&
        pv.vt == VT_BSTR && pv.bstrVal != nullptr;
    obj->Release();
    if (!have_path) {
      VariantClear(&pv);
      break;
    }
    // 类对象 → 方法入参模板 → 实例 → 填参 → 执行
    IWbemClassObject *cls = nullptr;
    BSTR cls_name = ::SysAllocString(L"WmiMonitorBrightnessMethods");
    HRESULT hr = svc->GetObject(cls_name, 0, nullptr, &cls, nullptr);
    ::SysFreeString(cls_name);
    if (FAILED(hr) || cls == nullptr) {
      VariantClear(&pv);
      break;
    }
    IWbemClassObject *in_def = nullptr;
    BSTR m_name = ::SysAllocString(L"WmiSetBrightness");
    hr = cls->GetMethod(m_name, 0, &in_def, nullptr);
    cls->Release();
    if (FAILED(hr) || in_def == nullptr) {
      ::SysFreeString(m_name);
      VariantClear(&pv);
      break;
    }
    IWbemClassObject *in_inst = nullptr;
    hr = in_def->SpawnInstance(0, &in_inst);
    in_def->Release();
    if (FAILED(hr) || in_inst == nullptr) {
      ::SysFreeString(m_name);
      VariantClear(&pv);
      break;
    }
    VARIANT arg;
    VariantInit(&arg);
    arg.vt = VT_I4;
    arg.lVal = 0;  // Timeout
    in_inst->Put(L"Timeout", 0, &arg, 0);
    arg.lVal = percent;  // Brightness
    in_inst->Put(L"Brightness", 0, &arg, 0);
    hr = svc->ExecMethod(pv.bstrVal, m_name, 0, nullptr, in_inst, nullptr,
                         nullptr);
    in_inst->Release();
    ::SysFreeString(m_name);
    VariantClear(&pv);
    VariantClear(&arg);
    if (SUCCEEDED(hr)) {
      *ok = 1;
      rc = 0;
    }
  } while (false);
  svc->Release();
  if (uninit) {
    ::CoUninitialize();
  }
  return rc;
}



extern "C" int32_t yue_mbt_power_active_guid(uint8_t *out16, int32_t *ok) {
  *ok = 0;
  GUID *guid = nullptr;
  DWORD r = ::PowerGetActiveScheme(nullptr, &guid);
  if (r != ERROR_SUCCESS || guid == nullptr) {
    return -static_cast<int32_t>(r);
  }
  memcpy(out16, guid, 16);
  ::LocalFree(guid);
  *ok = 1;
  return 0;
}

extern "C" int32_t yue_mbt_power_set_guid(const uint8_t *guid16, int32_t *ok) {
  *ok = 0;
  GUID guid;
  memcpy(&guid, guid16, 16);
  DWORD r = ::PowerSetActiveScheme(nullptr, &guid);
  if (r != ERROR_SUCCESS) {
    return -static_cast<int32_t>(r);
  }
  *ok = 1;
  return 0;
}

// out 每方案 16 字节；返回方案数（<0 错误），cap 上限防溢出（迭代到
// ERROR_NO_MORE_ITEMS 自然结束）
extern "C" int32_t yue_mbt_power_enumerate_guids(uint8_t *out,
                                                 int32_t cap_guids,
                                                 int32_t *ok) {
  *ok = 0;
  int32_t count = 0;
  for (int32_t i = 0; i < cap_guids; i++) {
    DWORD size = 16;
    DWORD r = ::PowerEnumerate(
        nullptr, nullptr, nullptr, ACCESS_SCHEME, static_cast<ULONG>(i),
        out + static_cast<size_t>(i) * 16, &size);
    if (r != ERROR_SUCCESS) {
      break;  // ERROR_NO_MORE_ITEMS：枚举结束
    }
    count++;
  }
  *ok = 1;
  return count;
}

// get：index → (cur, max)（与 devices 同序；ok=0 表示无此设备/不可读）
extern "C" int32_t yue_mbt_brightness_get(int32_t index, int32_t *cur,
                                          int32_t *max_v, int32_t *ok) {
  *ok = 0;
  DWORD c = 0;
  DWORD m = 0;
  std::wstring name;
  if (mbt_ddc_at(index, &c, &m, &name) != 1) {
    return -1;
  }
  *cur = static_cast<int32_t>(c);
  *max_v = static_cast<int32_t>(m);
  *ok = 1;
  return 0;
}

// ---- 音量：Core Audio 默认输出端点（IAudioEndpointVolume） ----
// 每次 COM 调用自带按需 CoInitializeEx（UI 线程已 STA 时得
// RPC_E_CHANGED_MODE，此时不再配对 CoUninitialize）。

namespace {

// 打开默认输出端点的音量接口；out_volume 生命周期由调用方 Release
int mbt_open_endpoint_volume(IAudioEndpointVolume **out_volume,
                             bool *out_uninit) {
  *out_uninit = false;
  HRESULT hr = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (SUCCEEDED(hr)) {
    *out_uninit = true;
  } else if (hr != RPC_E_CHANGED_MODE) {
    return -1;
  }
  IMMDeviceEnumerator *enumerator = nullptr;
  hr = ::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                          __uuidof(IMMDeviceEnumerator),
                          reinterpret_cast<void **>(&enumerator));
  if (FAILED(hr) || enumerator == nullptr) {
    if (*out_uninit) {
      ::CoUninitialize();
    }
    return -1;
  }
  IMMDevice *device = nullptr;
  hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
  enumerator->Release();
  if (FAILED(hr) || device == nullptr) {
    if (*out_uninit) {
      ::CoUninitialize();
    }
    return -1;
  }
  IAudioEndpointVolume *volume = nullptr;
  hr = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr,
                        reinterpret_cast<void **>(&volume));
  device->Release();
  if (FAILED(hr) || volume == nullptr) {
    if (*out_uninit) {
      ::CoUninitialize();
    }
    return -1;
  }
  *out_volume = volume;
  return 0;
}

}  // namespace

// level_out: 0..1 标量音量（MoonBit 侧 Double，与 Ref[Double] 的槽位宽
// 一致——extern 参数宽度必须逐位对齐，float 会只写一半）；muted_out: 0/1
extern "C" int32_t yue_mbt_vol_master(double *level_out, int32_t *muted_out,
                                      int32_t *ok) {
  *ok = 0;
  IAudioEndpointVolume *volume = nullptr;
  bool uninit = false;
  if (mbt_open_endpoint_volume(&volume, &uninit) != 0) {
    return -1;
  }
  float level = 0.0f;
  BOOL muted = FALSE;
  BOOL good = volume->GetMasterVolumeLevelScalar(&level);
  if (good == TRUE) {
    good = volume->GetMute(&muted);
  }
  volume->Release();
  if (uninit) {
    ::CoUninitialize();
  }
  if (good != TRUE) {
    return -1;
  }
  *level_out = static_cast<double>(level);
  *muted_out = muted ? 1 : 0;
  *ok = 1;
  return 0;
}

extern "C" int32_t yue_mbt_vol_set_master(double level, int32_t *ok) {
  *ok = 0;
  IAudioEndpointVolume *volume = nullptr;
  bool uninit = false;
  if (mbt_open_endpoint_volume(&volume, &uninit) != 0) {
    return -1;
  }
  if (level < 0.0) {
    level = 0.0;
  }
  if (level > 1.0) {
    level = 1.0;
  }
  HRESULT hr = volume->SetMasterVolumeLevelScalar(
      static_cast<float>(level), nullptr);
  volume->Release();
  if (uninit) {
    ::CoUninitialize();
  }
  if (FAILED(hr)) {
    return -1;
  }
  *ok = 1;
  return 0;
}

extern "C" int32_t yue_mbt_vol_set_mute(int32_t mute, int32_t *ok) {
  *ok = 0;
  IAudioEndpointVolume *volume = nullptr;
  bool uninit = false;
  if (mbt_open_endpoint_volume(&volume, &uninit) != 0) {
    return -1;
  }
  HRESULT hr = volume->SetMute(mute != 0 ? TRUE : FALSE, nullptr);
  volume->Release();
  if (uninit) {
    ::CoUninitialize();
  }
  if (FAILED(hr)) {
    return -1;
  }
  *ok = 1;
  return 0;
}

// ---- 显示器配置：EnumDisplayDevices/EnumDisplaySettingsEx ----
// 输出文本协议（UTF-8，'\n' 分行）：
//   H|name|connected|primary|w|h|refresh_centi|pos_x|pos_y   当前输出头行
//   M|w|h|refresh_centi|preferred|current                    模式行（随其头行）
// 连接未点亮的输出只有头行（connected=1 且 w=0）；物理毫米尺寸 Windows 无
// 直接对应（EDID 才有），恒 0 由 MoonBit 层文档化。

extern "C" void *yue_mbt_mon_list(int32_t *ok) {
  *ok = 0;
  std::string out;
  for (DWORD dev = 0;; dev++) {
    DISPLAY_DEVICEW adapter;
    ZeroMemory(&adapter, sizeof(adapter));
    adapter.cb = sizeof(adapter);
    if (::EnumDisplayDevicesW(nullptr, dev, &adapter, 0) != TRUE) {
      break;
    }
    if ((adapter.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) == 0) {
      continue;
    }
    DISPLAY_DEVICEW monitor;
    ZeroMemory(&monitor, sizeof(monitor));
    monitor.cb = sizeof(monitor);
    BOOL connected =
        ::EnumDisplayDevicesW(adapter.DeviceName, 0, &monitor, 0);
    // 当前模式（ EnumDisplaySettingsEx with ENUM_CURRENT_SETTINGS ）
    DEVMODEW mode;
    ZeroMemory(&mode, sizeof(mode));
    mode.dmSize = sizeof(mode);
    BOOL has_mode = ::EnumDisplaySettingsExW(
        adapter.DeviceName, ENUM_CURRENT_SETTINGS, &mode, 0);
    out += "H|";
    out += base::SysWideToUTF8(adapter.DeviceName);
    out += '|';
    out += connected ? '1' : '0';
    out += '|';
    out += (adapter.StateFlags & DISPLAY_DEVICE_PRIMARY_DEVICE) ? '1' : '0';
    out += '|';
    if (has_mode && (mode.dmFields & DM_PELSWIDTH) != 0) {
      out += std::to_string(mode.dmPelsWidth);
      out += '|';
      out += std::to_string(mode.dmPelsHeight);
      out += '|';
      out += std::to_string(mode.dmDisplayFrequency * 100);
      out += '|';
      out += std::to_string(mode.dmPosition.x);
      out += '|';
      out += std::to_string(mode.dmPosition.y);
    } else {
      out += "0|0|0|0|0";
    }
    out += '\n';
    // 模式表（ENUM_CURRENT_SETTINGS 后从 0 枚举到失败）
    DWORD i = 0;
    DEVMODEW m;
    ZeroMemory(&m, sizeof(m));
    m.dmSize = sizeof(m);
    while (::EnumDisplaySettingsExW(adapter.DeviceName, i, &m, 0) == TRUE) {
      out += "M|";
      out += std::to_string(m.dmPelsWidth);
      out += '|';
      out += std::to_string(m.dmPelsHeight);
      out += '|';
      out += std::to_string(m.dmDisplayFrequency * 100);
      out += '|';
      // preferred：Windows 无首选模式标记（EDID 才有），恒 0
      out += '0';
      out += '|';
      // current：与 ENUM_CURRENT_SETTINGS 的分辨率/刷新率一致
      out += (has_mode && m.dmPelsWidth == mode.dmPelsWidth &&
              m.dmPelsHeight == mode.dmPelsHeight &&
              m.dmDisplayFrequency == mode.dmDisplayFrequency)
                 ? '1'
                 : '0';
      out += '\n';
      i++;
      ZeroMemory(&m, sizeof(m));
      m.dmSize = sizeof(m);
    }
  }
  *ok = 1;
  return BytesFromString(out);
}

// ---- 打印机：EnumPrinters / GetDefaultPrinter / EnumJobs ----
// 列表输出 "name\tstatus_code" 行（status_code：0=空闲 1=打印中 2=暂停
// 3=不可用，映射在 MoonBit 层）；default 出参给默认打印机名。

extern "C" void *yue_mbt_prt_list(int32_t *ok) {
  *ok = 0;
  DWORD needed = 0;
  DWORD returned = 0;
  DWORD flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
  // level 2：pPrinterName + Status 都在（level 4 无 Status 成员）
  ::EnumPrintersW(flags, nullptr, 2, nullptr, 0, &needed, &returned);
  if (needed == 0) {
    *ok = 1;
    return BytesFromString("");
  }
  std::vector<BYTE> buf(needed);
  if (::EnumPrintersW(flags, nullptr, 2, buf.data(), needed, &needed,
                      &returned) != TRUE) {
    return moonbit_make_bytes(0, 0);
  }
  std::string out;
  auto *infos = reinterpret_cast<PRINTER_INFO_2W *>(buf.data());
  for (DWORD i = 0; i < returned; i++) {
    DWORD s = infos[i].Status;
    int32_t code = 0;
    if ((s & PRINTER_STATUS_PRINTING) != 0 ||
        (s & PRINTER_STATUS_PROCESSING) != 0) {
      code = 1;
    } else if ((s & PRINTER_STATUS_PAUSED) != 0) {
      code = 2;
    } else if ((s & (PRINTER_STATUS_ERROR | PRINTER_STATUS_OFFLINE |
                     PRINTER_STATUS_PAPER_JAM | PRINTER_STATUS_PAPER_OUT |
                     PRINTER_STATUS_PENDING_DELETION)) != 0) {
      code = 3;
    }
    out += base::SysWideToUTF8(infos[i].pPrinterName != nullptr
                                   ? infos[i].pPrinterName
                                   : L"");
    out += '\t';
    out += std::to_string(code);
    out += '\n';
  }
  *ok = 1;
  return BytesFromString(out);
}

extern "C" void *yue_mbt_prt_default(int32_t *ok) {
  *ok = 0;
  wchar_t name[512];
  DWORD size = 512;
  if (::GetDefaultPrinterW(name, &size) != TRUE) {
    return moonbit_make_bytes(0, 0);
  }
  *ok = 1;
  return BytesFromString(base::SysWideToUTF8(name));
}

// 队列输出 "job_id\tdoc_name" 行
extern "C" void *yue_mbt_prt_queue(const char *printer, int32_t *ok) {
  *ok = 0;
  std::wstring name = base::SysUTF8ToWide(printer);
  HANDLE handle = nullptr;
  if (::OpenPrinterW(const_cast<LPWSTR>(name.c_str()), &handle, nullptr) != TRUE) {
    return moonbit_make_bytes(0, 0);
  }
  DWORD needed = 0;
  DWORD returned = 0;
  ::EnumJobsW(handle, 0, 999, 1, nullptr, 0, &needed, &returned);
  std::string out;
  if (needed > 0) {
    std::vector<BYTE> buf(needed);
    if (::EnumJobsW(handle, 0, 999, 1, buf.data(), needed, &needed,
                    &returned) == TRUE) {
      auto *jobs = reinterpret_cast<JOB_INFO_1W *>(buf.data());
      for (DWORD i = 0; i < returned; i++) {
        out += std::to_string(jobs[i].JobId);
        out += '\t';
        out += base::SysWideToUTF8(jobs[i].pDocument != nullptr
                                       ? jobs[i].pDocument
                                       : L"");
        out += '\n';
      }
    }
  }
  ::ClosePrinter(handle);
  *ok = 1;
  return BytesFromString(out);
}

// 提交打印：交给文件的 "print" 动词（默认打印机；printer 非空时忽略——
// Windows 逐打印机提交需 printto 动词，本批只走默认打印机）
extern "C" int32_t yue_mbt_prt_print(const char *path, int32_t *ok) {
  *ok = 0;
  HINSTANCE r = ::ShellExecuteW(nullptr, L"print",
                                base::SysUTF8ToWide(path).c_str(), nullptr,
                                nullptr, SW_HIDE);
  if (reinterpret_cast<intptr_t>(r) <= 32) {
    return -1;
  }
  *ok = 1;
  return 0;
}

// ---- 剪贴板文本读（CF_UNICODETEXT） ----

extern "C" void *yue_mbt_clipboard_text(int32_t *ok) {
  *ok = 0;
  if (::OpenClipboard(nullptr) != TRUE) {
    return moonbit_make_bytes(0, 0);
  }
  HANDLE data = ::GetClipboardData(CF_UNICODETEXT);
  std::string out;
  if (data != nullptr) {
    auto *wide = static_cast<const wchar_t *>(::GlobalLock(data));
    if (wide != nullptr) {
      out = base::SysWideToUTF8(wide);
      ::GlobalUnlock(data);
    }
  }
  ::CloseClipboard();
  if (data == nullptr) {
    return moonbit_make_bytes(0, 0);  // 无文本：ok=0 空文本
  }
  *ok = 1;
  return BytesFromString(out);
}

// ---- 窗口管理：EnumWindows 列表 / 置前 / 关闭 ----

namespace {

struct MbWinListCtx {
  std::string *out;
};

BOOL CALLBACK mbt_win_enum(HWND hwnd, LPARAM lparam) {
  auto *ctx = reinterpret_cast<MbWinListCtx *>(lparam);
  if (::IsWindowVisible(hwnd) != TRUE) {
    return TRUE;
  }
  wchar_t title[512];
  int n = ::GetWindowTextW(hwnd, title, 512);
  if (n <= 0) {
    return TRUE;  // 无标题的工具窗口跳过
  }
  char hex[32];
  snprintf(hex, sizeof(hex), "0x%llx",
           static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(hwnd)));
  ctx->out->append(hex);
  ctx->out->append(1, '\t');
  ctx->out->append(base::SysWideToUTF8(title));
  ctx->out->append(1, '\n');
  return TRUE;
}

}  // namespace

extern "C" void *yue_mbt_win_list_windows(int32_t *ok) {
  *ok = 0;
  std::string out;
  MbWinListCtx ctx{&out};
  ::EnumWindows(mbt_win_enum, reinterpret_cast<LPARAM>(&ctx));
  *ok = 1;
  return BytesFromString(out);
}

// id_or_title：以 "0x" 开头按窗口句柄，否则按标题精确匹配
extern "C" int32_t yue_mbt_win_activate_window(const char *id_or_title,
                                               int32_t *ok) {
  *ok = 0;
  const char *s = id_or_title != nullptr ? id_or_title : "";
  HWND target = nullptr;
  if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
    target = reinterpret_cast<HWND>(
        static_cast<uintptr_t>(strtoull(s + 2, nullptr, 16)));
  }
  if (target == nullptr) {
    std::wstring want = base::SysUTF8ToWide(s);
    struct FindCtx {
      std::wstring want;
      HWND found;
    } fc{want, nullptr};
    ::EnumWindows(
        [](HWND hwnd, LPARAM lparam) -> BOOL {
          auto *c = reinterpret_cast<FindCtx *>(lparam);
          if (::IsWindowVisible(hwnd) != TRUE) {
            return TRUE;
          }
          wchar_t title[512];
          int n = ::GetWindowTextW(hwnd, title, 512);
          if (n > 0 && c->want == title) {
            c->found = hwnd;
            return FALSE;
          }
          return TRUE;
        },
        reinterpret_cast<LPARAM>(&fc));
    target = fc.found;
  }
  if (target == nullptr || ::IsWindow(target) != TRUE) {
    return -1;
  }
  if (::IsIconic(target) == TRUE) {
    ::ShowWindow(target, SW_RESTORE);
  }
  // 前台互斥下 SetForegroundWindow 可能被拒，退而 BringWindowToTop +
  // SetWindowPos TOPMOST→NOTOPMOST 抢一次前台（Shell 的通用替代法）
  if (::SetForegroundWindow(target) != TRUE) {
    ::BringWindowToTop(target);
    ::SetWindowPos(target, HWND_TOP, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
  }
  *ok = 1;
  return 0;
}

// id_or_title：以 "0x" 开头按窗口句柄，否则按标题精确匹配
// 按 "0x" 句柄或标题精确匹配关闭窗口（WM_CLOSE）
extern "C" int32_t yue_mbt_win_close_window(const char *id_or_title,
                                            int32_t *ok) {
  *ok = 0;
  const char *s = id_or_title != nullptr ? id_or_title : "";
  HWND target = nullptr;
  if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
    target = reinterpret_cast<HWND>(
        static_cast<uintptr_t>(strtoull(s + 2, nullptr, 16)));
  }
  if (target == nullptr) {
    std::wstring want = base::SysUTF8ToWide(s);
    struct FindCtx {
      std::wstring want;
      HWND found;
    } fc{want, nullptr};
    ::EnumWindows(
        [](HWND hwnd, LPARAM lparam) -> BOOL {
          auto *c = reinterpret_cast<FindCtx *>(lparam);
          if (::IsWindowVisible(hwnd) != TRUE) {
            return TRUE;
          }
          wchar_t title[512];
          int n = ::GetWindowTextW(hwnd, title, 512);
          if (n > 0 && c->want == title) {
            c->found = hwnd;
            return FALSE;
          }
          return TRUE;
        },
        reinterpret_cast<LPARAM>(&fc));
    target = fc.found;
  }
  if (target == nullptr || ::IsWindow(target) != TRUE) {
    return -1;
  }
  ::PostMessageW(target, WM_CLOSE, 0, 0);
  *ok = 1;
  return 0;
}

// ---- 默认应用查询：AssocQueryString ----
// kind: 0=可执行文件路径(ASSOCSTR_EXECUTABLE) 1=完整命令行(ASSOCSTR_COMMAND)
// assoc：文件扩展名（".txt"）或协议（"http"）
extern "C" void *yue_mbt_assoc_query(const char *assoc, int32_t kind,
                                     int32_t *ok) {
  *ok = 0;
  wchar_t buf[1024];
  DWORD size = 1024;
  HRESULT hr = ::AssocQueryStringW(
      ASSOCF_NONE,
      kind == 1 ? ASSOCSTR_COMMAND : ASSOCSTR_EXECUTABLE,
      base::SysUTF8ToWide(assoc).c_str(), L"open", buf, &size);
  if (FAILED(hr) || size == 0) {
    return moonbit_make_bytes(0, 0);
  }
  *ok = 1;
  return BytesFromString(base::SysWideToUTF8(buf));
}

// ---- 最近文件：.lnk 目标路径解析（IShellLink） ----
// 返回 "mtime_ms\t目标路径" 文本（mtime 为 .lnk 文件自身的修改时间——
// Windows 以 Recent 目录 .lnk 的 mtime 作为最近使用序，毫秒 Unix 纪元）。

extern "C" void *yue_mbt_lnk_target(const char *path, int32_t *ok) {
  *ok = 0;
  bool uninit = false;
  HRESULT hr = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (SUCCEEDED(hr)) {
    uninit = true;
  } else if (hr != RPC_E_CHANGED_MODE) {
    return moonbit_make_bytes(0, 0);
  }
  IShellLinkW *link = nullptr;
  hr = ::CoCreateInstance(__uuidof(ShellLink), nullptr, CLSCTX_INPROC_SERVER,
                          __uuidof(IShellLinkW),
                          reinterpret_cast<void **>(&link));
  if (FAILED(hr) || link == nullptr) {
    if (uninit) {
      ::CoUninitialize();
    }
    return moonbit_make_bytes(0, 0);
  }
  IPersistFile *file = nullptr;
  hr = link->QueryInterface(__uuidof(IPersistFile),
                            reinterpret_cast<void **>(&file));
  if (FAILED(hr) || file == nullptr) {
    link->Release();
    if (uninit) {
      ::CoUninitialize();
    }
    return moonbit_make_bytes(0, 0);
  }
  std::wstring wide_path = base::SysUTF8ToWide(path);
  hr = file->Load(wide_path.c_str(), STGM_READ);
  file->Release();
  if (FAILED(hr)) {
    link->Release();
    if (uninit) {
      ::CoUninitialize();
    }
    return moonbit_make_bytes(0, 0);
  }
  wchar_t target[MAX_PATH];
  WIN32_FIND_DATAW find;
  ZeroMemory(&find, sizeof(find));
  hr = link->GetPath(target, MAX_PATH, &find, SLGP_UNCPRIORITY);
  link->Release();
  // .lnk 文件自身 mtime（最近使用序的依据）
  WIN32_FILE_ATTRIBUTE_DATA attr;
  ZeroMemory(&attr, sizeof(attr));
  ULARGE_INTEGER mtime;
  mtime.QuadPart = 0;
  if (::GetFileAttributesExW(wide_path.c_str(), GetFileExInfoStandard, &attr) ==
      TRUE) {
    mtime.HighPart = attr.ftLastWriteTime.dwHighDateTime;
    mtime.LowPart = attr.ftLastWriteTime.dwLowDateTime;
  }
  if (uninit) {
    ::CoUninitialize();
  }
  if (FAILED(hr) || target[0] == 0) {
    return moonbit_make_bytes(0, 0);
  }
  // FILETIME(1601 纪元 100ns) → Unix 毫秒
  int64_t unix_ms =
      (static_cast<int64_t>(mtime.QuadPart) - 116444736000000000LL) / 10000;
  std::string out = std::to_string(unix_ms);
  out += '\t';
  out += base::SysWideToUTF8(target);
  *ok = 1;
  return BytesFromString(out);
}

// ---- 磁盘卷：GetLogicalDrives / GetVolumeInformation / GetDiskFreeSpaceEx ----
// 输出 "C:|label|total_bytes|free_bytes|kind" 行（kind：0=固定 1=可移除
// 2=光驱 3=网络 4=虚拟盘）；Windows 卷恒处于挂载态（根路径即挂载点）。

extern "C" void *yue_mbt_dsk_volumes(int32_t *ok) {
  *ok = 0;
  std::string out;
  DWORD mask = ::GetLogicalDrives();
  for (int i = 0; i < 26; i++) {
    if ((mask & (1u << i)) == 0) {
      continue;
    }
    wchar_t root[4] = {static_cast<wchar_t>(L'A' + i), L':', L'\\', 0};
    wchar_t label[256];
    wchar_t fs[64];
    DWORD serial = 0;
    DWORD max_comp = 0;
    DWORD flags = 0;
    BOOL has_info = ::GetVolumeInformationW(root, label, 256, &serial,
                                            &max_comp, &flags, fs, 64);
    ULARGE_INTEGER total;
    ULARGE_INTEGER free_b;
    ULARGE_INTEGER total_free;
    BOOL has_space =
        ::GetDiskFreeSpaceExW(root, &free_b, &total, &total_free);
    UINT type = ::GetDriveTypeW(root);
    int kind = 0;
    if (type == DRIVE_REMOVABLE) {
      kind = 1;
    } else if (type == DRIVE_CDROM) {
      kind = 2;
    } else if (type == DRIVE_REMOTE) {
      kind = 3;
    } else if (type == DRIVE_RAMDISK) {
      kind = 4;
    }
    out += base::SysWideToUTF8(root);
    // 根路径带尾 '\'，行内字段以 '|' 分隔——去掉尾分隔符保持字段干净
    if (!out.empty() && out.back() == '\\') {
      out.pop_back();
    }
    out += '|';
    out += has_info ? base::SysWideToUTF8(label) : "";
    out += '|';
    out += has_space ? std::to_string(total.QuadPart) : "0";
    out += '|';
    out += has_space ? std::to_string(total_free.QuadPart) : "0";
    out += '|';
    out += std::to_string(kind);
    out += '\n';
  }
  *ok = 1;
  return BytesFromString(out);
}

// ---- 蓝牙：经典 BluetoothAPIs 无线电/已知设备快照 ----
// 动作族（扫描/配对/连接/电源）需 WinRT 或 UI 向导，不在本层——MoonBit
// 侧对 Windows 的动作族直接 Unsupported。radio 行 "name\tmac"；devices
// 行 "name\tmac\tconnected\tremembered\tauthenticated"。

namespace {

std::string mbt_bt_mac(const unsigned char *b) {
  char buf[18];
  snprintf(buf, sizeof(buf), "%02X:%02X:%02X:%02X:%02X:%02X", b[5], b[4], b[3],
           b[2], b[1], b[0]);
  return std::string(buf);
}

}  // namespace

extern "C" void *yue_mbt_bt_radio_info(int32_t *ok) {
  *ok = 0;
  BLUETOOTH_FIND_RADIO_PARAMS p;
  p.dwSize = sizeof(p);
  HANDLE radio = nullptr;
  HBLUETOOTH_RADIO_FIND find = ::BluetoothFindFirstRadio(&p, &radio);
  if (find == nullptr) {
    if (::GetLastError() != ERROR_NO_MORE_ITEMS) {
      return moonbit_make_bytes(0, 0); // 服务未运行等真故障：ok=0
    }
    *ok = 1; // 无可用无线电（硬件缺席/禁用/飞行模式）：ok=1 空文本
    return BytesFromString("");
  }
  BLUETOOTH_RADIO_INFO info;
  memset(&info, 0, sizeof(info));
  info.dwSize = sizeof(info);
  std::string out;
  while (radio != nullptr) {
    if (::BluetoothGetRadioInfo(radio, &info) == ERROR_SUCCESS) {
      if (!out.empty()) {
        out += '\n';
      }
      out += base::SysWideToUTF8(info.szName);
      out += '\t';
      out += mbt_bt_mac(&info.address.rgBytes[0]);
    }
    ::CloseHandle(radio);
    radio = nullptr;
    if (!::BluetoothFindNextRadio(find, &radio)) {
      break;
    }
  }
  ::BluetoothFindRadioClose(find);
  *ok = 1;
  return BytesFromString(out);
}

extern "C" void *yue_mbt_bt_devices(int32_t *ok) {
  *ok = 0;
  BLUETOOTH_DEVICE_SEARCH_PARAMS sp;
  memset(&sp, 0, sizeof(sp));
  sp.dwSize = sizeof(sp);
  sp.fReturnAuthenticated = TRUE;
  sp.fReturnRemembered = TRUE;
  sp.fReturnUnknown = TRUE;
  sp.fReturnConnected = TRUE;
  sp.fIssueInquiry = FALSE; // 只列已知设备缓存，不触发扫描
  sp.cTimeoutMultiplier = 0;
  sp.hRadio = nullptr; // 全部无线电
  BLUETOOTH_DEVICE_INFO di;
  memset(&di, 0, sizeof(di));
  di.dwSize = sizeof(di);
  HBLUETOOTH_DEVICE_FIND find = ::BluetoothFindFirstDevice(&sp, &di);
  if (find == nullptr) {
    if (::GetLastError() != ERROR_NO_MORE_ITEMS) {
      return moonbit_make_bytes(0, 0); // 服务未运行等真故障：ok=0
    }
    *ok = 1; // 无已知设备：ok=1 空文本
    return BytesFromString("");
  }
  std::string out;
  while (true) {
    if (!out.empty()) {
      out += '\n';
    }
    out += base::SysWideToUTF8(di.szName);
    out += '\t';
    out += mbt_bt_mac(&di.Address.rgBytes[0]);
    out += '\t';
    out += di.fConnected ? "1" : "0";
    out += '\t';
    out += di.fRemembered ? "1" : "0";
    out += '\t';
    out += di.fAuthenticated ? "1" : "0";
    if (!::BluetoothFindNextDevice(find, &di)) {
      break;
    }
  }
  ::BluetoothFindDeviceClose(find);
  *ok = 1;
  return BytesFromString(out);
}

