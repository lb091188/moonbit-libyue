#!/usr/bin/env python3
"""moon 原生预构建脚本（--moonbit-unstable-prebuild，实验性机制）。

moon 每次构建都会执行本脚本（stdin 为构建环境 JSON），stdout 输出的
link_configs 会被 moon 自动传播给所有依赖 yue 包的 main 包——包括
本仓 examples 与 mooncakes 使用方。链接参数因此只存在于此处，按当前
系统生成，使用方零配置、零平台感知。

注意：
- 脚本 cwd 是 moon 的调用目录（使用方项目根），定位自身必须用
  __file__，不能用相对路径。
- 传播的搜索路径必须用绝对路径：链接命令的 cwd 是使用方项目根，
  相对路径会错位。
- 静态库缺失时现场调用 prepare.py 构建（首次使用需 GitHub 网络），
  产物齐备时本脚本毫秒级返回，不影响增量构建。
"""

from __future__ import annotations

import json
import platform
import subprocess
import sys
from pathlib import Path

MODULE_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = MODULE_ROOT / "build"

# Linux 链接期系统库，与 shim/CMakeLists.txt 的依赖一致
LINUX_PKG_CONFIG_LIBS = [
    "gtk+-3.0",
    "pangoft2",
    "fontconfig",
    "x11",
]
# webkit2gtk 在不同发行版包名不同，4.0/4.1 任一存在即可
LINUX_PKG_CONFIG_LIBS_ANY = ["webkit2gtk-4.0", "webkit2gtk-4.1"]

# Windows 最终链接需要的系统库（cl 命令行风格）。在官方 CMakeLists 清单
# 基础上补齐 user32/ole32/oleaut32/shell32 等 GUI 基础库（官方清单缺项，
# 实测链接大量 user32/COM 符号未解析）；多余的库链接器会忽略，无害。
WINDOWS_LINK_LIBS = [
    "user32.lib", "gdi32.lib", "shell32.lib", "ole32.lib", "oleaut32.lib",
    "advapi32.lib", "comdlg32.lib", "imm32.lib", "msimg32.lib", "oleacc.lib",
    "usp10.lib", "setupapi.lib", "powrprof.lib", "ws2_32.lib", "dbghelp.lib",
    "shlwapi.lib", "version.lib", "winmm.lib", "wbemuuid.lib", "psapi.lib",
    "dwmapi.lib", "propsys.lib", "comctl32.lib", "gdiplus.lib", "urlmon.lib",
    "userenv.lib", "uxtheme.lib", "delayimp.lib", "runtimeobject.lib",
    "ntdll.lib", "shcore.lib", "pdh.lib",
]


def ensure_native_artifacts() -> None:
    """静态库缺失时现场构建原生层（下载 libyue + CMake）。

    moon 只把本脚本的 stdout 当 JSON 解析，构建进度必须全部改道
    stderr，否则混入文本会导致 moon 反序列化失败。
    """
    if sys.platform == "win32":
        ready = (BUILD_DIR / "yue_mbt.lib").exists()
    else:
        ready = (BUILD_DIR / "libyue_mbt.a").exists()
    if ready:
        return
    print("[moonbit-libyue] 原生库缺失，开始自动构建（首次需 GitHub 网络）…",
          file=sys.stderr)
    prepare = Path(__file__).resolve().parent / "prepare.py"
    proc = subprocess.run([sys.executable, str(prepare)],
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True)
    sys.stderr.write(proc.stdout or "")
    if proc.returncode != 0:
        raise SystemExit(f"[moonbit-libyue] 原生层自动构建失败（退出码 {proc.returncode}）")


def pkg_config_libs() -> list[str]:
    """Linux 链接期系统库（pkg-config 原样输出）。webkit 包名做 4.0/4.1 兼容。"""
    flags: list[str] = []
    for pkg in LINUX_PKG_CONFIG_LIBS:
        out = subprocess.run(["pkg-config", "--libs", pkg],
                             capture_output=True, text=True)
        if out.returncode != 0:
            raise SystemExit(f"缺少系统依赖：请安装 {pkg} 的开发包（pkg-config 找不到）")
        flags += out.stdout.split()
    for pkg in LINUX_PKG_CONFIG_LIBS_ANY:
        out = subprocess.run(["pkg-config", "--libs", pkg],
                             capture_output=True, text=True)
        if out.returncode == 0:
            flags += out.stdout.split()
            break
    else:
        raise SystemExit("缺少系统依赖：webkit2gtk-4.0 或 4.1 的开发包至少装一个")
    if "-lwebkit2gtk-4.1" in flags and "-ljavascriptcoregtk-4.1" not in flags:
        flags.append("-ljavascriptcoregtk-4.1")
    return flags


def link_configs() -> dict:
    """各平台链接配置：Linux/macOS 为 GNU ld 风格，Windows 为 cl 命令行风格。

    全部参数放 link_flags 单一字符串并自控顺序：moon 组装命令行时
    link_flags 在 link_libs 之前，而 GNU ld 从左到右解析——libyue_mbt.a
    里的 C++ 符号必须由其右侧的 -lstdc++ 满足，故 -lyue_mbt 不能走
    link_libs（会被排到系统库之前导致 undefined reference）。
    Linux/macOS 为 GNU ld 风格；Windows 为 cl 命令行风格：moon 把链接
    参数原样拼进 cl 命令行（实测 -L/-l 报 D9002/D9024），静态库与
    manifest.res 以绝对路径作为链接输入（cl 把 .lib/.res 位置参数转交
    link），系统库由 vcvars64 注入的 LIB 环境变量解析；分隔符必须用
    正斜杠（cl/link 均接受）。
    """
    build = str(BUILD_DIR.resolve()).replace("\\", "/")
    if sys.platform == "win32":
        return {"link_configs": [{
            "package": "lkyh/moonbit-libyue/yue",
            "link_flags": (
                f"{build}/yue_mbt_manifest.res {build}/yue_mbt.lib "
                + " ".join(WINDOWS_LINK_LIBS)
            ),
        }]}
    if platform.system() == "Linux":
        extra = pkg_config_libs() + ["-lpthread", "-ldl", "-lm", "-lstdc++"]
    else:  # Darwin
        extra = ["-lpthread"]
    return {"link_configs": [{
        "package": "lkyh/moonbit-libyue/yue",
        "link_flags": f"-L{build} -lyue_mbt " + " ".join(extra),
    }]}


def main() -> None:
    try:
        json.load(sys.stdin)  # moon 传入构建环境，当前无需使用
    except json.JSONDecodeError:
        pass
    ensure_native_artifacts()
    print(json.dumps(link_configs()))


if __name__ == "__main__":
    main()
