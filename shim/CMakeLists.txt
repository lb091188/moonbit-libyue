# 构建 libyue_mbt 静态库 = vendored libyue 源码 + 本 shim。
# 平台源码分支与依赖完全对照 libyue 发行包自带的 CMakeLists.txt，
# 由 scripts/prepare.py 驱动，一般不手动调用。
# YUE_MBT_PREBUILT=ON 时只编译 shim（头文件来自预构建发行包），
# libyue 本体直接用 build/ 下解出的预构建静态库，链接期并入。
cmake_minimum_required(VERSION 3.13)
# 官方指定 Windows 10 SDK；须在 project() 之前设置
if(WIN32)
  set(CMAKE_SYSTEM_VERSION 10.0)
  # moon 侧固定用 /MT 静态 CRT 链接，shim 库必须一致，否则混入调试/动态
  # CRT 会在最终链接报 LNK4098 冲突与大量 __imp_ 未解析符号。
  # 须在 add_library 之前设置且显式启用 CMP0091（3.13 基线下默认为 OLD）
  cmake_policy(SET CMP0091 NEW)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
endif()
project(yue_mbt CXX C)

# ---------- Windows ----------
if(WIN32)
  enable_language(RC)
endif()

set(LIBYUE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../vendor/libyue")

option(YUE_MBT_PREBUILT "只编译 shim，libyue 用预构建静态库" OFF)

# ---------- libyue 平台源码（与官方 CMakeLists 一致） ----------
if(NOT YUE_MBT_PREBUILT)
  if(APPLE)
    file(GLOB_RECURSE YUE_SOURCES
         ${LIBYUE_DIR}/src/mac/*.cc ${LIBYUE_DIR}/src/mac/*.mm
         ${LIBYUE_DIR}/src/mac/*.S ${LIBYUE_DIR}/src/mac/*.c)
    set(YUE_NO_ARC_SOURCES ${YUE_SOURCES})
    list(FILTER YUE_SOURCES EXCLUDE REGEX "allocator|nativeui")
    list(FILTER YUE_NO_ARC_SOURCES INCLUDE REGEX "allocator|nativeui")
  elseif(WIN32)
    file(GLOB_RECURSE YUE_SOURCES
         ${LIBYUE_DIR}/src/win/*.cc ${LIBYUE_DIR}/src/win/*.c)
  else()
    file(GLOB_RECURSE YUE_SOURCES
         ${LIBYUE_DIR}/src/linux/*.cc ${LIBYUE_DIR}/src/linux/*.c)
  endif()
else()
  set(YUE_SOURCES "")
  set(YUE_NO_ARC_SOURCES "")
endif()

add_library(yue_mbt STATIC ${YUE_SOURCES} yue_mbt.cpp)

target_include_directories(yue_mbt PUBLIC
  ${LIBYUE_DIR}/include
  ${LIBYUE_DIR}/include/base/allocator/partition_allocator/src
  ${CMAKE_CURRENT_SOURCE_DIR}/include)

target_compile_features(yue_mbt PUBLIC cxx_std_20)

# 源码为无 BOM UTF-8 且含中文注释:MSVC 默认按系统代码页(如 cp936/GBK)
# 逐字节解码,中文双字节序列会吞掉后续字符(如下一行行首的 #),产生
# 「意外的 #endif」类假错误。/utf-8 强制按 UTF-8 解码源与执行字符集。
if(MSVC)
  target_compile_options(yue_mbt PRIVATE /utf-8)
  # MSVC 的标准库头(iosfwd/optional 等)经 INCLUDE 环境变量定位,该变量由
  # vcvars64 注入;未注入时 C1083 报标准库头找不到,难以直读根因,在此拦截。
  if("$ENV{INCLUDE}" STREQUAL "")
    message(FATAL_ERROR
      "未检测到 INCLUDE 环境变量:MSVC 标准库头无法定位。请在 x64 Native "
      "Tools Command Prompt 中执行,或先 call vcvars64.bat 再运行 cmake/moon:\n"
      "call \"C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools"
      "\\VC\\Auxiliary\\Build\\vcvars64.bat\"")
  endif()
endif()

# ---------- moonbit.h（moon 工具链自带） ----------
# Windows CI 的 cmd 环境无 HOME/常用 MOON_HOME，只有 USERPROFILE
find_path(MOONBIT_INCLUDE_DIR moonbit.h
  PATHS $ENV{MOON_HOME}/include $ENV{HOME}/.moon/include
        $ENV{USERPROFILE}/.moon/include
  REQUIRED)
target_include_directories(yue_mbt PRIVATE ${MOONBIT_INCLUDE_DIR})

# ---------- macOS ----------
if(APPLE)
  if(NOT YUE_MBT_PREBUILT)
    # 官方源码树含 .S 汇编单元（base_jumbo_S.S 定义 CallWithEHFrame 等，
    # ObjC 消息泵依赖）；不启用 ASM 语言时 CMake 静默跳过，链接期报
    # undefined symbol（CI 实测）
    enable_language(ASM)
  endif()
  find_library(APPKIT AppKit)
  find_library(CARBON Carbon)
  find_library(IOKIT IOKit)
  find_library(SECURITY Security)
  find_library(WEBKIT WebKit)
  find_library(OD OpenDirectory)
  target_link_libraries(yue_mbt PUBLIC
    ${APPKIT} ${CARBON} ${IOKIT} ${SECURITY} ${WEBKIT} ${OD})
  target_compile_definitions(yue_mbt PUBLIC SYSTEM_NATIVE_UTF8)
  target_compile_options(yue_mbt PRIVATE
    -Wno-deprecated-declarations -Wno-unguarded-availability-new)
  # 官方构建把禁用 ARC 的源文件单独编成第二个库，链接时两个都要。
  # 未在 macOS 上验证过，首次构建时按官方 CMakeLists 微调。
  if(NOT YUE_MBT_PREBUILT)
    set(LIBYUE_NO_ARC "yue_mbt_noarc")
    add_library(${LIBYUE_NO_ARC} STATIC ${YUE_NO_ARC_SOURCES})
    target_include_directories(${LIBYUE_NO_ARC} PUBLIC
      ${LIBYUE_DIR}/include
      ${LIBYUE_DIR}/include/base/allocator/partition_allocator/src)
    target_compile_features(${LIBYUE_NO_ARC} PUBLIC cxx_std_20)
    set_property(TARGET yue_mbt APPEND PROPERTY COMPILE_OPTIONS -fobjc-arc -fno-objc-arc-exceptions)
  endif()
endif()

# ---------- Windows ----------
# 对照官方 CMakeLists 的 win32 段；差异：不带 /SUBSYSTEM:WINDOWS——
# moon 生成的是控制台 main（无 WinMain），保持控制台子系统即可弹 GUI 窗口。
if(WIN32)
  # 应用清单编译成独立 .res：链接示例 exe 时作为输入嵌入（见 prepare.py
  # 的 Windows 链接参数），声明 Common-Controls v6——comctl32 的
  # TaskDialogIndirect 仅以序数 345 导出，缺清单时进程启动即失败。
  set(MANIFEST_RES "${CMAKE_BINARY_DIR}/yue_mbt_manifest.res")
  add_custom_command(OUTPUT ${MANIFEST_RES}
    COMMAND ${CMAKE_RC_COMPILER} /Fo ${MANIFEST_RES} "${CMAKE_CURRENT_SOURCE_DIR}/app.rc"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/app.rc" "${CMAKE_CURRENT_SOURCE_DIR}/app.manifest"
    VERBATIM)
  add_custom_target(yue_mbt_manifest ALL DEPENDS ${MANIFEST_RES})
  # MSVC 多配置生成器默认输出到 build/Release，平铺到 build/ 以匹配 -L build
  set_target_properties(yue_mbt PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}
    ARCHIVE_OUTPUT_DIRECTORY_RELEASE ${CMAKE_BINARY_DIR}
    ARCHIVE_OUTPUT_DIRECTORY_DEBUG ${CMAKE_BINARY_DIR})
  target_compile_definitions(yue_mbt PUBLIC
    _WINDOWS WIN32 WIN32_LEAN_AND_MEAN NOMINMAX _UNICODE UNICODE
    # base::StackContainer 在 Debug 下要求（官方注释）
    $<$<CONFIG:Debug>:_ITERATOR_DEBUG_LEVEL=0>)
  target_link_libraries(yue_mbt PUBLIC
    user32.lib gdi32.lib shell32.lib ole32.lib oleaut32.lib advapi32.lib
    comdlg32.lib imm32.lib msimg32.lib oleacc.lib usp10.lib
    setupapi.lib powrprof.lib ws2_32.lib dbghelp.lib shlwapi.lib version.lib
    winmm.lib wbemuuid.lib psapi.lib dwmapi.lib propsys.lib comctl32.lib
    gdiplus.lib urlmon.lib userenv.lib uxtheme.lib delayimp.lib
    runtimeobject.lib ntdll.lib shcore.lib pdh.lib)
  target_compile_options(yue_mbt PRIVATE /wd4005 /wd4101 /wd4244 /wd4267 /wd4996)

  # 浏览器优先 WebView2：需要发行包/预构建包自带的 SDK 头文件
  # （loader DLL 由 libyue 运行时动态加载，无需链接导入库）。
  # 版本号通配，跟随发行包内实际捆绑的 WebView2 SDK。
  file(GLOB WEBVIEW2_SDK_DIRS
       "${LIBYUE_DIR}/include/third_party/Microsoft.Web.WebView2.*")
  if(WEBVIEW2_SDK_DIRS)
    list(GET WEBVIEW2_SDK_DIRS 0 WEBVIEW2_SDK)
    target_compile_definitions(yue_mbt PUBLIC WEBVIEW2_SUPPORT)
    target_include_directories(yue_mbt PUBLIC "${WEBVIEW2_SDK}/build/native/include")
  else()
    message(FATAL_ERROR "缺少 WebView2 SDK：请先运行 python3 scripts/prepare.py")
  endif()
endif()

# ---------- Linux ----------
if(UNIX AND NOT APPLE)
  find_package(PkgConfig REQUIRED)
  pkg_search_module(FONTCONFIG REQUIRED fontconfig)
  pkg_search_module(PANGO REQUIRED pangoft2)
  pkg_search_module(GTK3 REQUIRED gtk+-3.0)
  pkg_search_module(X11 REQUIRED x11)
  # Ubuntu 22.04 及更早发行 webkit2gtk-4.0；24.04 起只有 4.1，两者头文件兼容
  pkg_search_module(WEBKIT2GTK REQUIRED webkit2gtk-4.0 webkit2gtk-4.1)
  target_include_directories(yue_mbt PUBLIC
    ${FONTCONFIG_INCLUDE_DIRS} ${PANGO_INCLUDE_DIRS} ${GTK3_INCLUDE_DIRS}
    ${X11_INCLUDE_DIRS} ${WEBKIT2GTK_INCLUDE_DIRS})
  target_compile_options(yue_mbt PRIVATE
    -Wno-deprecated-declarations -Wno-unknown-attributes)
  target_compile_definitions(yue_mbt PUBLIC USE_GLIB)
endif()
