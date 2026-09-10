# 构建 libyue_mbt 静态库 = vendored libyue 源码 + 本 shim。
# 平台源码分支与依赖完全对照 libyue 发行包自带的 CMakeLists.txt，
# 由 scripts/prepare.py 驱动，一般不手动调用。
cmake_minimum_required(VERSION 3.13)
project(yue_mbt CXX C)

set(LIBYUE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../vendor/libyue")

# ---------- libyue 平台源码（与官方 CMakeLists 一致） ----------
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

add_library(yue_mbt STATIC ${YUE_SOURCES} yue_mbt.cpp)

target_include_directories(yue_mbt PUBLIC
  ${LIBYUE_DIR}/include
  ${LIBYUE_DIR}/include/base/allocator/partition_allocator/src
  ${CMAKE_CURRENT_SOURCE_DIR}/include)

target_compile_features(yue_mbt PUBLIC cxx_std_20)

# ---------- moonbit.h（moon 工具链自带） ----------
find_path(MOONBIT_INCLUDE_DIR moonbit.h
  PATHS $ENV{MOON_HOME}/include $ENV{HOME}/.moon/include
  REQUIRED)
target_include_directories(yue_mbt PRIVATE ${MOONBIT_INCLUDE_DIR})

# ---------- macOS ----------
if(APPLE)
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
  set(LIBYUE_NO_ARC "yue_mbt_noarc")
  add_library(${LIBYUE_NO_ARC} STATIC ${YUE_NO_ARC_SOURCES})
  target_include_directories(${LIBYUE_NO_ARC} PUBLIC
    ${LIBYUE_DIR}/include
    ${LIBYUE_DIR}/include/base/allocator/partition_allocator/src)
  target_compile_features(${LIBYUE_NO_ARC} PUBLIC cxx_std_20)
  set_property(TARGET yue_mbt APPEND PROPERTY COMPILE_OPTIONS -fobjc-arc)
endif()

# ---------- Windows ----------
if(WIN32)
  target_compile_definitions(yue_mbt PUBLIC
    _WINDOWS WIN32 WIN32_LEAN_AND_MEAN NOMINMAX _UNICODE UNICODE)
  target_link_libraries(yue_mbt PUBLIC
    setupapi.lib powrprof.lib ws2_32.lib dbghelp.lib shlwapi.lib version.lib
    winmm.lib wbemuuid.lib psapi.lib dwmapi.lib propsys.lib comctl32.lib
    gdi32.lib gdiplus.lib urlmon.lib userenv.lib uxtheme.lib delayimp.lib
    runtimeobject.lib ntdll.lib shcore.lib pdh.lib)
  target_compile_options(yue_mbt PRIVATE /wd4005 /wd4101 /wd4244 /wd4267 /wd4996)
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
