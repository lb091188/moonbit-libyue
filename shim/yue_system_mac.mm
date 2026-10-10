// system 子包 macOS 直连族（ObjC++ 翻译单元）。
// 与 Windows 直连族（yue_mbt.cpp OS_WIN 区）同 ABI：符号名沿用
// yue_mbt.h 的 win_/vol_/mon_/prt_/dsk_ 前缀（历史命名，非平台含义），
// 文本协议逐字段对齐 Windows 侧，MoonBit 层解析代码跨平台复用。
// 本文件仅在 APPLE 构建参与编译（CMakeLists APPLE 分支）；
// Linux 保留 yue_mbt.cpp 的哨兵桩（MoonBit 层走纯路由不经过这些符号）。
//
// 能力对照（Unsupported 明示，不做半吊子模拟）：
//   - win_reg_str / lnk_target / power 三 GUID 组：Windows 专属，哨兵
//   - win_ntp_running：macOS 无对等服务（systemsetup 需 root），哨兵
//   - session watch / connectivity / netwin 轮询线程：Windows 批次能力，
//     非本批范围，哨兵维持
//
// 权限边界（macOS 10.15+）：
//   - 窗口列表标题（kCGWindowName）与 AX 关窗需要"屏幕录制"/"辅助功能"
//     权限；未授权时列表行退化为仅本进程窗口、关窗返回 -1，见 MoonBit 文档
//   - 关机/重启/注销经 loginwindow Apple Event（osascript），无需 root
#include "yue_mbt_internal.h"

#import <Cocoa/Cocoa.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreServices/CoreServices.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <cups/cups.h>

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import <cerrno>
#import <cstdlib>
#import <cstring>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <sys/mount.h>
#import <sys/sysctl.h>
#import <sys/time.h>
#import <sys/wait.h>
#import <unistd.h>

// 事实标准的私有 API：AX window ↔ CGWindowID 对齐（无公开替代，
// Chromium/Qt 同款用法）；未声明于公开头，链接符号在 libAXRuntime
using yue_mbt::BytesFromString;

extern "C" int32_t _AXUIElementGetWindow(void *window, uint32_t *id);

namespace {

std::string NSStringToStd(NSString *s) {
  return std::string(s.UTF8String != nullptr ? s.UTF8String : "");
}

// 一律返回空 Bytes 而不是 nullptr（MoonBit 侧 decode_lossy 假定非空）
void *EmptyBytes() { return moonbit_make_bytes(0, 0); }

}  // namespace

// ---- sysinfo：内存 / 开机时长（注册表串 Windows 专属，mac 哨兵） ----

extern "C" void *yue_mbt_win_reg_str(int32_t, const char *, const char *,
                                     int32_t *ok) {
  *ok = -1000;
  return EmptyBytes();
}

extern "C" int32_t yue_mbt_win_memory(int64_t *total_kb, int64_t *avail_kb) {
  @autoreleasepool {
    int64_t total = 0;
    size_t len = sizeof(total);
    if (sysctlbyname("hw.memsize", &total, &len, nullptr, 0) != 0 ||
        total <= 0) {
      return 0;
    }
    vm_statistics64_data_t vm;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_statistics64(mach_host_self(), HOST_VM_INFO64,
                          reinterpret_cast<host_info64_t>(&vm),
                          &count) != KERN_SUCCESS) {
      return 0;
    }
    vm_size_t page = 0;
    len = sizeof(page);
    if (sysctlbyname("hw.pagesize", &page, &len, nullptr, 0) != 0 ||
        page == 0) {
      page = 4096;
    }
    // 可用 = free + inactive + purgeable（inactive 可回收，与 Windows
    // ullAvailPhys 的"当前可用物理内存"口径同族；不含 compressed）。
    int64_t avail = static_cast<int64_t>(vm.free_count + vm.inactive_count +
                                         vm.purgeable_count) *
                    static_cast<int64_t>(page);
    *total_kb = total / 1024;
    *avail_kb = avail / 1024;
    return 1;
  }
}

extern "C" int64_t yue_mbt_win_uptime_ms(void) {
  @autoreleasepool {
    struct timeval boot;
    size_t len = sizeof(boot);
    if (sysctlbyname("kern.boottime", &boot, &len, nullptr, 0) != 0 ||
        boot.tv_sec == 0) {
      return -1;
    }
    struct timeval now;
    gettimeofday(&now, nullptr);
    int64_t ms = (static_cast<int64_t>(now.tv_sec) - boot.tv_sec) * 1000 +
                 (static_cast<int64_t>(now.tv_usec) - boot.tv_usec) / 1000;
    return ms >= 0 ? ms : -1;
  }
}

// ---- 壁纸：NSWorkspace 桌面图（主屏；多屏差异文档化） ----

extern "C" void *yue_mbt_wallpaper_get(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    NSURL *url = [[NSWorkspace sharedWorkspace]
        desktopImageURLForScreen:[NSScreen mainScreen]];
    if (url == nil || url.path == nil) {
      return EmptyBytes();
    }
    *ok = 1;
    return BytesFromString(NSStringToStd(url.path));
  }
}

extern "C" int32_t yue_mbt_wallpaper_set(const char *path, int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    if (path == nullptr || path[0] == 0) {
      return -87;
    }
    NSString *p = [NSString stringWithUTF8String:path];
    NSURL *url = [NSURL fileURLWithPath:p];
    if (![url checkResourceIsReachableAndReturnError:nil]) {
      return -2;
    }
    NSError *err = nil;
    BOOL good = [[NSWorkspace sharedWorkspace]
        setDesktopImageURL:url
                 forScreen:[NSScreen mainScreen]
                   options:@{}
                     error:&err];
    if (good != YES) {
      return -1;
    }
    *ok = 1;
    return 0;
  }
}

// ---- locale：IANA 时区名 / 首选语言（与 Windows 键名语义差异由
//      MoonBit 层文档化；时间同步服务状态无对等，哨兵） ----

extern "C" void *yue_mbt_win_tz_name(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    NSString *name = [NSTimeZone localTimeZone].name;
    if (name == nil || name.length == 0) {
      return EmptyBytes();
    }
    *ok = 1;
    return BytesFromString(NSStringToStd(name));
  }
}

extern "C" void *yue_mbt_win_lang(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    NSString *lang = [NSLocale preferredLanguages].firstObject;
    if (lang == nil || lang.length == 0) {
      return EmptyBytes();
    }
    *ok = 1;
    return BytesFromString(NSStringToStd(lang));
  }
}

extern "C" int32_t yue_mbt_win_ntp_running(int32_t *ok) {
  *ok = 0;
  return -1000;
}

// ---- powerctl：loginwindow Apple Event（关机 aevtsdwn / 重启 aevtrlgo /
//      注销 aevtlout；osascript 承载避免手写 AppleEvent Manager 样板） ----

extern "C" int32_t yue_mbt_win_shutdown(int32_t how, int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    const char *evt = how == 0   ? "aevtsdwn"
                      : how == 1 ? "aevtrlgo"
                                 : "aevtlout";
    std::string script =
        "tell application \"loginwindow\" to «event " +
        std::string(evt) + "»";
    pid_t pid = fork();
    if (pid < 0) {
      return -errno;
    }
    if (pid == 0) {
      execlp("/usr/bin/osascript", "osascript", "-e", script.c_str(),
             static_cast<char *>(nullptr));
      _exit(127);
    }
    int status = 0;
    if (waitpid(pid, &status, 0) < 0) {
      return -errno;
    }
    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
      *ok = 1;
      return 0;
    }
    return WIFEXITED(status) ? -WEXITSTATUS(status) : -1;
  }
}

// ---- 电源计划三接口：Windows 专属，哨兵 ----

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

// ---- 亮度：IODisplay（内建面板走 CoreDisplay，外接屏走 DDC 桥接，
//      统一归一到 0..100 量纲；Windows DDC 是设备原始量纲——差异由
//      MoonBit 层按平台文档化） ----

namespace {

// 枚举支持亮度读写的显示器，index 命中时执行动作；与 devices 输出同序。
// 返回 1 命中，0 未命中，-1 错误。
int32_t mbt_bright_visit(int32_t index, int32_t *cur, int32_t *max_v,
                         int32_t set_value, bool do_set, int32_t *ok) {
  *ok = 0;
  uint32_t ids[16];
  uint32_t count = 0;
  if (CGGetOnlineDisplayList(16, ids, &count) != kCGErrorSuccess) {
    return -1;
  }
  int32_t hit = 0;
  for (uint32_t i = 0; i < count; i++) {
    // CGDisplayIOServicePort 自 10.9 deprecated 但仍是官方给出的
    // display → io_service_t 通道（IOMonitorPort 更新但 10.15 不可用）
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    io_service_t service = CGDisplayIOServicePort(ids[i]);
#pragma clang diagnostic pop
    if (service == MACH_PORT_NULL) {
      continue;
    }
    float level = 0.0f;
    kern_return_t kr = IODisplayGetFloatParameter(
        service, kNilOptions, CFSTR(kIODisplayBrightnessKey), &level);
    if (kr != KERN_SUCCESS) {
      continue;  // 无亮度通道（投影仪等），跳过不进清单
    }
    if (hit == index) {
      if (do_set) {
        float v = static_cast<float>(set_value) / 100.0f;
        if (v < 0.0f) v = 0.0f;
        if (v > 1.0f) v = 1.0f;
        if (IODisplaySetFloatParameter(service, kNilOptions,
                                       CFSTR(kIODisplayBrightnessKey),
                                       v) != KERN_SUCCESS) {
          return -1;
        }
        *ok = 1;
        return 0;
      }
      if (cur != nullptr) {
        *cur = static_cast<int32_t>(level * 100.0f + 0.5f);
      }
      if (max_v != nullptr) {
        *max_v = 100;
      }
      *ok = 1;
      return 0;
    }
    hit++;
  }
  return 0;
}

}  // namespace

extern "C" void *yue_mbt_brightness_devices(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    uint32_t ids[16];
    uint32_t count = 0;
    if (CGGetOnlineDisplayList(16, ids, &count) != kCGErrorSuccess) {
      return EmptyBytes();
    }
    std::string out;
    for (uint32_t i = 0; i < count; i++) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      io_service_t service = CGDisplayIOServicePort(ids[i]);
#pragma clang diagnostic pop
      if (service == MACH_PORT_NULL) {
        continue;
      }
      float level = 0.0f;
      if (IODisplayGetFloatParameter(service, kNilOptions,
                                     CFSTR(kIODisplayBrightnessKey),
                                     &level) != KERN_SUCCESS) {
        continue;
      }
      out += "display" + std::to_string(ids[i]);
      out += "\t100\t";
      out += std::to_string(
          static_cast<int32_t>(level * 100.0f + 0.5f));
      out += "\n";
    }
    *ok = 1;
    return BytesFromString(out);
  }
}

extern "C" int32_t yue_mbt_brightness_get(int32_t index, int32_t *cur,
                                          int32_t *max_v, int32_t *ok) {
  @autoreleasepool {
    return mbt_bright_visit(index, cur, max_v, 0, false, ok) == 1
               ? 0
               : -1;
  }
}

extern "C" int32_t yue_mbt_brightness_set(int32_t index, int32_t value,
                                          int32_t *ok) {
  @autoreleasepool {
    int32_t cur = 0;
    int32_t max_v = 0;
    int32_t r = mbt_bright_visit(index, &cur, &max_v, value, true, ok);
    return r == 1 ? 0 : -1;
  }
}

// ---- 音量：Core Audio 默认输出设备（kAudioDevicePropertyVolumeScalar /
//      Mute，master element；与 Windows 端点标量同语义） ----

namespace {

// 取默认输出设备；0 = 无设备/失败
AudioDeviceID mbt_default_output() {
  AudioDeviceID dev = kAudioObjectUnknown;
  UInt32 size = sizeof(dev);
  AudioObjectPropertyAddress addr = {
      kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal,
      kAudioElementMaster};
  OSStatus st = AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0,
                                           nullptr, &size, &dev);
  if (st != noErr || dev == kAudioObjectUnknown || dev == 0) {
    return 0;
  }
  return dev;
}

// 设备是否有 master 音量通道（部分 USB 设备只有分通道）
bool mbt_has_master_volume(AudioDeviceID dev) {
  UInt32 size = 0;
  AudioObjectPropertyAddress addr = {
      kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput,
      kAudioElementMaster};
  if (AudioObjectGetPropertyDataSize(dev, &addr, 0, nullptr, &size) !=
      noErr) {
    return false;
  }
  return size >= sizeof(Float32);
}

}  // namespace

extern "C" int32_t yue_mbt_vol_master(double *level_out, int32_t *muted_out,
                                      int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    AudioDeviceID dev = mbt_default_output();
    if (dev == 0 || !mbt_has_master_volume(dev)) {
      return -1;
    }
    Float32 level = 0.0f;
    UInt32 size = sizeof(level);
    AudioObjectPropertyAddress addr = {
        kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput,
        kAudioElementMaster};
    if (AudioObjectGetPropertyData(dev, &addr, 0, nullptr, &size,
                                   &level) != noErr) {
      return -1;
    }
    UInt32 mute = 0;
    size = sizeof(mute);
    addr.mSelector = kAudioDevicePropertyMute;
    // 无静音通道视为未静音（部分设备没有 mute element）
    if (AudioObjectGetPropertyData(dev, &addr, 0, nullptr, &size, &mute) !=
        noErr) {
      mute = 0;
    }
    *level_out = static_cast<double>(level);
    *muted_out = mute != 0 ? 1 : 0;
    *ok = 1;
    return 0;
  }
}

extern "C" int32_t yue_mbt_vol_set_master(double level, int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    AudioDeviceID dev = mbt_default_output();
    if (dev == 0 || !mbt_has_master_volume(dev)) {
      return -1;
    }
    if (level < 0.0) level = 0.0;
    if (level > 1.0) level = 1.0;
    Float32 v = static_cast<Float32>(level);
    AudioObjectPropertyAddress addr = {
        kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput,
        kAudioElementMaster};
    if (AudioObjectSetPropertyData(dev, &addr, 0, nullptr, sizeof(v), &v) !=
        noErr) {
      return -1;
    }
    *ok = 1;
    return 0;
  }
}

extern "C" int32_t yue_mbt_vol_set_mute(int32_t mute, int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    AudioDeviceID dev = mbt_default_output();
    if (dev == 0) {
      return -1;
    }
    UInt32 m = mute != 0 ? 1 : 0;
    UInt32 size = 0;
    AudioObjectPropertyAddress addr = {
        kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput,
        kAudioElementMaster};
    // 设备无 mute 通道：不视为错误（Windows 端点恒有，这里如实降级）
    if (AudioObjectGetPropertyDataSize(dev, &addr, 0, nullptr, &size) !=
        noErr) {
      *ok = 1;
      return 0;
    }
    if (AudioObjectSetPropertyData(dev, &addr, 0, nullptr, sizeof(m), &m) !=
        noErr) {
      return -1;
    }
    *ok = 1;
    return 0;
  }
}

// ---- 显示器：CGDisplay 在线/激活两级（对应 Windows connected 与点亮），
//      物理毫米 ABI 无字段，恒 0 由 MoonBit 层文档化 ----
// 输出协议与 Windows 相同：
//   H|name|connected|primary|w|h|refresh_centi|pos_x|pos_y
//   M|w|h|refresh_centi|preferred|current

extern "C" void *yue_mbt_mon_list(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    uint32_t online[16];
    uint32_t online_n = 0;
    if (CGGetOnlineDisplayList(16, online, &online_n) != kCGErrorSuccess) {
      return EmptyBytes();
    }
    uint32_t active[16];
    uint32_t active_n = 0;
    CGGetActiveDisplayList(16, active, &active_n);
    CGDirectDisplayID cur_main = CGMainDisplayID();
    std::string out;
    for (uint32_t i = 0; i < online_n; i++) {
      CGDirectDisplayID did = online[i];
      bool is_active = false;
      for (uint32_t j = 0; j < active_n; j++) {
        if (active[j] == did) {
          is_active = true;
          break;
        }
      }
      out += "H|display" + std::to_string(did);
      out += "|1|";
      out += did == cur_main ? '1' : '0';
      out += '|';
      if (is_active) {
        CGDisplayModeRef mode = CGDisplayCopyDisplayMode(did);
        CGRect bounds = CGDisplayBounds(did);
        if (mode != nullptr) {
          double hz = CGDisplayModeGetRefreshRate(mode);
          out += std::to_string(CGDisplayModeGetPixelWidth(mode));
          out += '|';
          out += std::to_string(CGDisplayModeGetPixelHeight(mode));
          out += '|';
          out += std::to_string(static_cast<int64_t>(hz * 100.0 + 0.5));
          out += '|';
          out += std::to_string(static_cast<int64_t>(bounds.origin.x));
          out += '|';
          out += std::to_string(static_cast<int64_t>(bounds.origin.y));
          CGDisplayModeRelease(mode);
        } else {
          out += "0|0|0|0|0";
        }
      } else {
        // 连接未点亮：头行 0 值（Windows 同约定），无模式行
        out += "0|0|0|0|0";
      }
      out += "\n";
      if (!is_active) {
        continue;
      }
      CFArrayRef modes = CGDisplayCopyAllDisplayModes(did, nullptr);
      if (modes == nullptr) {
        continue;
      }
      CGDisplayModeRef current = CGDisplayCopyDisplayMode(did);
      for (CFIndex k = 0; k < CFArrayGetCount(modes); k++) {
        CGDisplayModeRef m =
            static_cast<CGDisplayModeRef>(CFArrayGetValueAtIndex(modes, k));
        double hz = CGDisplayModeGetRefreshRate(m);
        // preferred：IO 标志位 native（面板原生分辨率）近似 Windows 的
        // 首选概念；Windows 侧恒 0
        uint32_t io_flags = CGDisplayModeGetIOFlags(m);
        bool preferred = (io_flags & kDisplayModeNativeFlag) != 0;
        out += "M|";
        out += std::to_string(CGDisplayModeGetPixelWidth(m));
        out += '|';
        out += std::to_string(CGDisplayModeGetPixelHeight(m));
        out += '|';
        out += std::to_string(static_cast<int64_t>(hz * 100.0 + 0.5));
        out += '|';
        out += preferred ? '1' : '0';
        out += '|';
        out += (current != nullptr && CFEqual(m, current)) ? '1' : '0';
        out += "\n";
      }
      if (current != nullptr) {
        CGDisplayModeRelease(current);
      }
      CFRelease(modes);
    }
    *ok = 1;
    return BytesFromString(out);
  }
}

// ---- 打印机：CUPS（macOS 系统打印栈本体；状态映射 0=空闲 1=打印中
//      2=暂停(mac 无对应,不用) 3=不可用(stopped)） ----

extern "C" void *yue_mbt_prt_list(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    cups_dest_t *dests = nullptr;
    int n = cupsGetDests(&dests);
    std::string out;
    for (int i = 0; i < n; i++) {
      const char *name = dests[i].name;
      if (name == nullptr) {
        continue;
      }
      int32_t code = 0;
      cups_dest_t *d = cupsGetNamedDest(CUPS_HTTP_DEFAULT, name, nullptr);
      if (d != nullptr) {
        const char *state =
            cupsGetOption("printer-state", d->num_options, d->options);
        if (state != nullptr) {
          if (strcmp(state, "4") == 0) {
            code = 1;  // printing
          } else if (strcmp(state, "5") == 0) {
            code = 3;  // stopped → 不可用
          }
        }
        cupsFreeDests(1, d);
      }
      out += name;
      out += '\t';
      out += std::to_string(code);
      out += '\n';
    }
    if (dests != nullptr) {
      cupsFreeDests(n, dests);
    }
    *ok = 1;
    return BytesFromString(out);
  }
}

extern "C" void *yue_mbt_prt_default(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    cups_dest_t *d = cupsGetNamedDest(CUPS_HTTP_DEFAULT, nullptr, nullptr);
    if (d == nullptr || d->name == nullptr) {
      return EmptyBytes();
    }
    *ok = 1;
    void *r = BytesFromString(std::string(d->name));
    cupsFreeDests(1, d);
    return r;
  }
}

extern "C" void *yue_mbt_prt_queue(const char *printer, int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    if (printer == nullptr || printer[0] == 0) {
      return EmptyBytes();
    }
    cups_job_t *jobs = nullptr;
    int n = cupsGetJobs(CUPS_HTTP_DEFAULT, printer, 0,
                        CUPS_WHICHJOBS_ACTIVE, &jobs);
    std::string out;
    for (int i = 0; i < n; i++) {
      out += std::to_string(jobs[i].id);
      out += '\t';
      out += jobs[i].title != nullptr ? jobs[i].title : "";
      out += '\n';
    }
    if (jobs != nullptr) {
      cupsFreeJobs(n, jobs);
    }
    *ok = 1;
    return BytesFromString(out);
  }
}

extern "C" int32_t yue_mbt_prt_print(const char *path, int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    if (path == nullptr || path[0] == 0) {
      return -87;
    }
    if (access(path, R_OK) != 0) {
      return -2;
    }
    cups_dest_t *d = cupsGetNamedDest(CUPS_HTTP_DEFAULT, nullptr, nullptr);
    if (d == nullptr || d->name == nullptr) {
      return -1;
    }
    int job_id =
        cupsPrintFile(d->name, path, "libyue", d->num_options, d->options);
    cupsFreeDests(1, d);
    if (job_id <= 0) {
      return -1;
    }
    *ok = 1;
    return 0;
  }
}

// ---- 剪贴板文本读（NSPasteboardTypeString；无文本 ok=0） ----

extern "C" void *yue_mbt_clipboard_text(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSString *text = [pb stringForType:NSPasteboardTypeString];
    if (text == nil || text.length == 0) {
      return EmptyBytes();
    }
    *ok = 1;
    return BytesFromString(NSStringToStd(text));
  }
}

// ---- 窗口管理：CGWindowList 列表 / NSRunningApplication 置前 /
//      AXUIElement 关窗（需辅助功能权限） ----

namespace {

// on_screen 且 layer==0（常规层，跳过菜单栏/Dock 附件）
NSArray *mbt_window_list() {
  return CFBridgingRelease(CGWindowListCopyWindowInfo(
      kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
      kCGNullWindowID));
}

}  // namespace

extern "C" void *yue_mbt_win_list_windows(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    NSArray *list = mbt_window_list();
    std::string out;
    for (NSDictionary *w in list) {
      NSNumber *layer = w[(__bridge NSString *)kCGWindowLayer];
      if (layer == nil || layer.intValue != 0) {
        continue;
      }
      NSString *title = w[(__bridge NSString *)kCGWindowName];
      if (title == nil || title.length == 0) {
        continue;  // 无标题跳过（与 Windows 一致）；跨应用标题需屏幕录制权限
      }
      NSNumber *num = w[(__bridge NSString *)kCGWindowNumber];
      if (num == nil) {
        continue;
      }
      char hex[32];
      snprintf(hex, sizeof(hex), "0x%x", num.unsignedIntValue);
      out += hex;
      out += '\t';
      out += NSStringToStd(title);
      out += '\n';
    }
    *ok = 1;
    return BytesFromString(out);
  }
}

namespace {

// 从窗口清单按 id 或标题精确定位，出参 CGWindowID 与 OwnerPID
bool mbt_find_window(const char *id_or_title, uint32_t *out_id,
                     int32_t *out_pid) {
  *out_pid = -1;
  *out_id = 0;
  const char *s = id_or_title != nullptr ? id_or_title : "";
  if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
    *out_id = static_cast<uint32_t>(strtoul(s + 2, nullptr, 16));
  }
  NSString *want = nil;
  if (*out_id == 0) {
    want = [NSString stringWithUTF8String:s];
    if (want.length == 0) {
      return false;
    }
  }
  for (NSDictionary *w in mbt_window_list()) {
    NSNumber *num = w[(__bridge NSString *)kCGWindowNumber];
    if (num == nil) {
      continue;
    }
    if (*out_id != 0) {
      if (num.unsignedIntValue == *out_id) {
        NSNumber *pid = w[(__bridge NSString *)kCGWindowOwnerPID];
        *out_pid = pid != nil ? pid.intValue : -1;
        return true;
      }
      continue;
    }
    NSString *title = w[(__bridge NSString *)kCGWindowName];
    if (title != nil && [title isEqualToString:want]) {
      *out_id = num.unsignedIntValue;
      NSNumber *pid = w[(__bridge NSString *)kCGWindowOwnerPID];
      *out_pid = pid != nil ? pid.intValue : -1;
      return true;
    }
  }
  return false;
}

}  // namespace

// id_or_title：以 "0x" 开头按窗口 id，否则按标题精确匹配
extern "C" int32_t yue_mbt_win_activate_window(const char *id_or_title,
                                               int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    uint32_t wid = 0;
    int32_t pid = -1;
    if (!mbt_find_window(id_or_title, &wid, &pid) || pid <= 0) {
      return -1;
    }
    NSRunningApplication *app =
        [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    if (app == nil) {
      return -1;
    }
    // 10.14+ 激活策略：IgnoringOtherApps 抢前台（与 Windows
    // SetForegroundWindow 退路同族）
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
#pragma clang diagnostic pop
    *ok = 1;
    return 0;
  }
}

// AX 关窗：kAXCloseButtonAttribute → AXPress；需辅助功能权限
// （AXIsProcessTrusted 为假时返回 -99，MoonBit 层文档化该错误码）
extern "C" int32_t yue_mbt_win_close_window(const char *id_or_title,
                                            int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    if (!AXIsProcessTrusted()) {
      return -99;
    }
    uint32_t wid = 0;
    int32_t pid = -1;
    if (!mbt_find_window(id_or_title, &wid, &pid) || pid <= 0) {
      return -1;
    }
    AXUIElementRef app = AXUIElementCreateApplication(pid);
    if (app == nullptr) {
      return -1;
    }
    CFArrayRef ax_windows = nullptr;
    OSStatus st = AXUIElementCopyAttributeValue(
        app, kAXWindowsAttribute, (CFTypeRef *)&ax_windows);
    int32_t r = -1;
    if (st == kAXErrorSuccess && ax_windows != nullptr) {
      for (CFIndex i = 0; i < CFArrayGetCount(ax_windows); i++) {
        AXUIElementRef axw =
            static_cast<AXUIElementRef>(CFArrayGetValueAtIndex(
                ax_windows, i));
        // 私有但事实标准的 CGWindowID 对齐通道（无替代公开 API）
        uint32_t ax_id = 0;
        if (_AXUIElementGetWindow(axw, &ax_id) == 0 && ax_id == wid) {
          AXUIElementRef btn = nullptr;
          if (AXUIElementCopyAttributeValue(axw, kAXCloseButtonAttribute,
                                            (CFTypeRef *)&btn) ==
                  kAXErrorSuccess &&
              btn != nullptr) {
            if (AXUIElementPerformAction(btn, kAXPressAction) ==
                kAXErrorSuccess) {
              r = 0;
              *ok = 1;
            }
            CFRelease(btn);
          }
          break;
        }
      }
      CFRelease(ax_windows);
    }
    CFRelease(app);
    return r;
  }
}

// ---- 默认应用：LaunchServices（扩展名走 UTI → 角色句柄 → 应用路径；
//      协议走 URL 直查；kind=1 命令行 mac 无对应，恒返回可执行路径） ----

extern "C" void *yue_mbt_assoc_query(const char *assoc, int32_t kind,
                                     int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    (void)kind;  // 命令行形态 macOS 无对应，kind 0/1 同返回应用路径
    if (assoc == nullptr || assoc[0] == 0) {
      return EmptyBytes();
    }
    NSString *a = [NSString stringWithUTF8String:assoc];
    NSURL *app_url = nil;
    if ([a hasPrefix:@"."]) {
      // 扩展名：UTI → 默认角色句柄（bundle id）→ 应用 URL
      CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(
          kUTTagClassFilenameExtension,
          (__bridge CFStringRef)[a substringFromIndex:1], nullptr);
      if (uti != nullptr) {
        CFStringRef bundle_id = LSCopyDefaultRoleHandlerForContentType(
            uti, kLSRolesAll);
        if (bundle_id != nullptr) {
          app_url = [NSWorkspace sharedWorkspace]
                        URLForApplicationWithBundleIdentifier:
                            (__bridge NSString *)bundle_id];
          CFRelease(bundle_id);
        }
        CFRelease(uti);
      }
    } else {
      // 协议：构造规范 URL 直查默认处理应用
      NSString *probe =
          [a hasSuffix:@"://"] ? [a stringByAppendingString:@"x"]
                               : [a stringByAppendingString:@"://x"];
      NSURL *url = [NSURL URLWithString:probe];
      if (url != nil) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        app_url = LSCopyDefaultApplicationURLForURL(url, kLSRolesAll,
                                                    nullptr);
#pragma clang diagnostic pop
      }
    }
    if (app_url == nil || app_url.path == nil) {
      return EmptyBytes();
    }
    *ok = 1;
    return BytesFromString(NSStringToStd(app_url.path));
  }
}

// ---- 最近文件 .lnk 解析：Windows 专属，哨兵 ----

extern "C" void *yue_mbt_lnk_target(const char *, int32_t *ok) {
  *ok = -1000;
  return EmptyBytes();
}

// ---- 磁盘卷：NSFileManager 挂载卷 + statfs（"dev|mount|label|total|
//      free|kind" 行——比 Windows 多挂载点列，解析在 MoonBit mac 分支；
//      kind：0=固定 1=可移除 3=网络；光驱/虚拟盘 mac 无对应归 0） ----

extern "C" void *yue_mbt_dsk_volumes(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *urls = [fm mountedVolumeURLsIncludingResourceValuesForKeys:@[
      NSURLVolumeNameKey, NSURLVolumeTotalCapacityKey,
      NSURLVolumeAvailableCapacityKey, NSURLVolumeIsInternalKey,
      NSURLVolumeIsEjectableKey
    ]
                                            options:0];
    std::string out;
    for (NSURL *url in urls) {
      NSString *path = url.path;
      if (path == nil || path.length == 0) {
        continue;
      }
      struct statfs sfs;
      if (statfs(path.fileSystemRepresentation, &sfs) != 0) {
        continue;
      }
      bool local = (sfs.f_flags & MNT_LOCAL) != 0;
      NSNumber *internal_n = nil;
      NSNumber *ejectable_n = nil;
      NSNumber *total_n = nil;
      NSNumber *avail_n = nil;
      NSString *label = nil;
      [url getResourceValue:&internal_n forKey:NSURLVolumeIsInternalKey
                      error:nil];
      [url getResourceValue:&ejectable_n forKey:NSURLVolumeIsEjectableKey
                      error:nil];
      [url getResourceValue:&total_n forKey:NSURLVolumeTotalCapacityKey
                      error:nil];
      [url getResourceValue:&avail_n forKey:NSURLVolumeAvailableCapacityKey
                      error:nil];
      [url getResourceValue:&label forKey:NSURLVolumeNameKey error:nil];
      int kind = 0;
      if (!local) {
        kind = 3;
      } else if ((ejectable_n != nil && ejectable_n.boolValue) ||
                 (internal_n != nil && !internal_n.boolValue)) {
        kind = 1;
      }
      // mac 行比 Windows 多一列挂载点：device 与 mountpoint 不像 Windows
      // 盘符那样同一（/dev/diskXsY vs /、/Volumes/X）
      out += std::string(sfs.f_mntfromname);
      out += '|';
      out += NSStringToStd(path);
      out += '|';
      out += label != nil ? NSStringToStd(label) : "";
      out += '|';
      out += total_n != nil ? std::to_string(total_n.longLongValue) : "0";
      out += '|';
      out += avail_n != nil ? std::to_string(avail_n.longLongValue) : "0";
      out += '|';
      out += std::to_string(kind);
      out += '\n';
    }
    *ok = 1;
    return BytesFromString(out);
  }
}

// ---- 电量：IOKit 电源源（AC 在线 / 百分比 / 充电中 / 有无电池） ----
// 口径对齐 Windows GetSystemPowerStatus：percent 未知 -1（mac 读得到即
// 0..100）；无电池（台式机）has_battery=0 且返回 0 成功。

extern "C" int32_t yue_mbt_win_power_status(
    int32_t *ac_online, int32_t *percent, int32_t *charging,
    int32_t *has_battery) {
  @autoreleasepool {
    *ac_online = 0;
    *percent = -1;
    *charging = 0;
    *has_battery = 0;
    CFTypeRef blob = IOPSCopyPowerSourcesInfo();
    if (blob == nullptr) {
      return -1;
    }
    // 全局电源状态：AC / Battery / UPS
    CFStringRef src = IOPSGetPowerSourceState(blob);
    *ac_online = src != nullptr &&
                         CFEqual(src, CFSTR(kIOPSACPowerValue))
                     ? 1
                     : 0;
    CFArrayRef list = IOPSCopyPowerSourcesList(blob);
    if (list == nullptr) {
      CFRelease(blob);
      return 0;  // 无电源源条目：无电池台式机形态，成功
    }
    bool have_battery = false;
    for (CFIndex i = 0; i < CFArrayGetCount(list); i++) {
      CFTypeRef ps = CFArrayGetValueAtIndex(list, i);
      CFDictionaryRef desc = IOPSGetPowerSourceDescription(blob, ps);
      if (desc == nullptr) {
        continue;
      }
      CFBooleanRef present =
          static_cast<CFBooleanRef>(CFDictionaryGetValue(
              desc, CFSTR(kIOPSIsPresentKey)));
      if (present == nullptr || !CFBooleanGetValue(present)) {
        continue;
      }
      CFStringRef type = static_cast<CFStringRef>(CFDictionaryGetValue(
          desc, CFSTR(kIOPSTypeKey)));
      if (type == nullptr ||
          !CFEqual(type, CFSTR(kIOPSInternalBatteryType))) {
        continue;
      }
      have_battery = true;
      CFNumberRef cur = static_cast<CFNumberRef>(CFDictionaryGetValue(
          desc, CFSTR(kIOPSCurrentCapacityKey)));
      CFNumberRef max_v = static_cast<CFNumberRef>(CFDictionaryGetValue(
          desc, CFSTR(kIOPSMaxCapacityKey)));
      CFBooleanRef chg = static_cast<CFBooleanRef>(CFDictionaryGetValue(
          desc, CFSTR(kIOPSIsChargingKey)));
      if (cur != nullptr && max_v != nullptr) {
        int c = 0;
        int m = 0;
        CFNumberGetValue(cur, kCFNumberIntType, &c);
        CFNumberGetValue(max_v, kCFNumberIntType, &m);
        if (m > 0) {
          int pct = static_cast<int>(1.0 * c / m * 100 + 0.5);
          *percent = pct < 0 ? 0 : (pct > 100 ? 100 : pct);
        }
      }
      if (chg != nullptr && CFBooleanGetValue(chg)) {
        *charging = 1;
      }
    }
    CFRelease(list);
    CFRelease(blob);
    *has_battery = have_battery ? 1 : 0;
    return 0;
  }
}

// ---- 屏幕常亮与空闲时长（IOPMAssertion / CGEventSource） ----

namespace {
IOPMAssertionID mbt_sleep_assertion = 0;
bool mbt_sleep_assertion_on = false;
}  // namespace

// 空闲时长毫秒（全会话任意输入起算；上限口径与 Windows 一致）
extern "C" int32_t yue_mbt_idle_seconds_ms(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    double secs = CGEventSourceSecondsSinceLastEventType(
        kCGEventSourceStateCombinedSessionState, kCGAnyInputEventType);
    if (secs < 0) {
      return -1;
    }
    double ms = secs * 1000.0;
    *ok = 1;
    return ms > 2147483647.0 ? 0x7fffffff : static_cast<int32_t>(ms);
  }
}

extern "C" int32_t yue_mbt_win_keep_awake_enable(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    if (mbt_sleep_assertion_on) {
      return -1;  // 重复开启：与 Windows g_keep_awake_on 同口径
    }
    // 只防闲置睡眠，不锁硬睡眠（对齐 Windows ES_DISPLAY_REQUIRED）
    if (IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleDisplaySleep, kIOPMAssertionLevelOn,
            CFSTR("libyue keep awake"), &mbt_sleep_assertion) !=
        KERN_SUCCESS) {
      return -1;
    }
    mbt_sleep_assertion_on = true;
    *ok = 1;
    return 0;
  }
}

extern "C" int32_t yue_mbt_win_keep_awake_restore(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    if (!mbt_sleep_assertion_on) {
      return -1;
    }
    if (IOPMAssertionRelease(mbt_sleep_assertion) != KERN_SUCCESS) {
      return -1;
    }
    mbt_sleep_assertion_on = false;
    *ok = 1;
    return 0;
  }
}

// ---- 机器标识：IOPlatformExpertDevice（型号/序列号） ----
// 输出 "vendor\tproduct\tserial"（vendor 恒 "Apple Inc."——IORegistry 无
// 制造商键，Apple 自产硬件；product=hw.model 如 "MacBookPro18,3"；
// serial=IOPlatformSerialNumber，读不到给空字段）。行格式同系统能力组
// '\t' 分隔约定。

extern "C" void *yue_mbt_mac_machine_info(int32_t *ok) {
  @autoreleasepool {
    *ok = 0;
    std::string product;
    char buf[256] = {0};
    size_t len = sizeof(buf) - 1;
    if (sysctlbyname("hw.model", buf, &len, nullptr, 0) == 0) {
      product = buf;
    }
    std::string serial;
    // IOServiceGetMatchingService 主端口常量：10.15 后 kIOMainPortDefault
    // 才有名，用 0（旧名 kIOMasterPortDefault 的值，语义相同）
    io_service_t platform = IOServiceGetMatchingService(
        0, IOServiceMatching("IOPlatformExpertDevice"));
    if (platform != MACH_PORT_NULL) {
      CFTypeRef sn = IORegistryEntryCreateCFProperty(
          platform, CFSTR("IOPlatformSerialNumber"), kCFAllocatorDefault, 0);
      if (sn != nullptr) {
        serial = NSStringToStd(
            (__bridge NSString *)sn);
        CFRelease(sn);
      }
      IOObjectRelease(platform);
    }
    std::string out = "Apple Inc.\t" + product + "\t" + serial;
    *ok = 1;
    return BytesFromString(out);
  }
}
