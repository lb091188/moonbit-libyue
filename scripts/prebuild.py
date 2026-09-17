#!/usr/bin/env python3
"""moon 原生预构建脚本（--moonbit-unstable-prebuild）。

moon 每次构建执行本脚本，stdout 输出 link_configs 自动传播给所有依赖
yue 的 main 包。约束：stdout 只能是 JSON；定位自身用 __file__（cwd 是
moon 调用目录）；传播路径用绝对路径。

原生库来源级联：
  1. lib/<平台>/ 随包分发的 vendored 库（mooncakes 用户零 C++ 编译）；
  2. build/ 本地构建产物（仓库开发 / 无 vendored 库的平台），缺失时自动
     调 prepare.py 补建（预构建优先，源码回退）。
"""

from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare as _prepare  # noqa: E402  读取 LIBYUE_VERSION 做过期判断

MODULE_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = MODULE_ROOT / "build"
VENDOR_LIB_DIR = MODULE_ROOT / "lib"

# Linux 链接期系统库，与 shim/CMakeLists.txt 的依赖一致
LINUX_PKG_CONFIG_LIBS = [
    "gtk+-3.0",
    "pangoft2",
    "fontconfig",
    "x11",
]
# webkit2gtk 在不同发行版包名不同，4.0/4.1 任一存在即可
LINUX_PKG_CONFIG_LIBS_ANY = ["webkit2gtk-4.0", "webkit2gtk-4.1"]

# Windows 最终链接需要的系统库（cl 命令行风格），在官方 CMakeLists 清单
# 基础上补齐 GUI 基础库；多余的库链接器会忽略，无害。
WINDOWS_LINK_LIBS = [
    "user32.lib", "gdi32.lib", "shell32.lib", "ole32.lib", "oleaut32.lib",
    "advapi32.lib", "comdlg32.lib", "imm32.lib", "msimg32.lib", "oleacc.lib",
    "usp10.lib", "setupapi.lib", "powrprof.lib", "ws2_32.lib", "dbghelp.lib",
    "shlwapi.lib", "version.lib", "winmm.lib", "wbemuuid.lib", "psapi.lib",
    "dwmapi.lib", "propsys.lib", "comctl32.lib", "gdiplus.lib", "urlmon.lib",
    "userenv.lib", "uxtheme.lib", "delayimp.lib", "runtimeobject.lib",
    "ntdll.lib", "shcore.lib", "pdh.lib",
]


def _platform_dir() -> str | None:
    """vendored 库的平台目录名；无对应资产平台（如 linux/arm64）为 None。"""
    machine = platform.machine().lower()
    if sys.platform == "win32":
        return "windows-x64" if machine in ("x86_64", "amd64") else None
    if platform.system() == "Linux":
        return "linux-x64" if machine in ("x86_64", "amd64") else None
    if platform.system() == "Darwin":
        return "macos-universal"
    return None


def _shim_lib_name() -> str:
    return "yue_mbt.lib" if sys.platform == "win32" else "libyue_mbt.a"


def _sources_newer(vendored: Path) -> bool:
    """shim 源码比 vendored 库新 → 开发者在改 shim，回退 build/ 流程。"""
    lib_mtime = (vendored / _shim_lib_name()).stat().st_mtime
    for pattern in ("*.cpp", "*.h", "include/*.h"):
        for src in (MODULE_ROOT / "shim").glob(pattern):
            if src.stat().st_mtime > lib_mtime:
                return True
    return False


def _native_dir() -> Path:
    """原生库目录：vendored lib/<平台>/ 优先，否则 build/。"""
    plat = _platform_dir()
    if plat is not None:
        vendored = VENDOR_LIB_DIR / plat
        if (vendored / _shim_lib_name()).exists() and not _sources_newer(vendored):
            return vendored
    return BUILD_DIR


def _native_lib_path() -> Path:
    return _native_dir() / _shim_lib_name()


def _stamp() -> str:
    """prepare.py 落盘的「版本 模式」戳；旧版本构建无戳视为有效。"""
    try:
        return (BUILD_DIR / "prepare_stamp").read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def _stamp_stale() -> bool:
    """build/ 产物与当前版本/模式不符 → 需重跑 prepare（防误链旧产物）。"""
    stamp = _stamp()
    if not stamp:
        return False
    version, _, mode = stamp.partition(" ")
    if version != _prepare.LIBYUE_VERSION:
        return True
    # 只在环境显式强制源码模式而现有产物是预构建时重建；反向不重建，
    # 否则无预构建资产的平台（如 linux/arm64）会每次构建都重跑 prepare。
    return os.environ.get("LIBYUE_FORCE_SOURCE") == "1" and mode != "source"


def _shim_newer_than_lib() -> bool:
    """shim 源码比静态库新 → 需要增量重编（防止链接旧库误判修复无效）。"""
    lib = _native_lib_path()
    if not lib.exists():
        return False
    lib_mtime = lib.stat().st_mtime
    for pattern in ("shim/*.cpp", "shim/*.h", "shim/include/*.h"):
        for src in (MODULE_ROOT / "shim").glob(pattern.removeprefix("shim/")):
            if src.stat().st_mtime > lib_mtime:
                return True
    return False


def _copy_webview2_loader() -> None:
    """Windows：把 loader DLL 复制到 moon 调用目录（用户工程根），
    供 LoadLibrary 按工作目录搜索（moon run 的工作目录即工程根）。"""
    if sys.platform != "win32":
        return
    plat = _platform_dir()
    sources = [VENDOR_LIB_DIR / plat / "WebView2Loader.dll" if plat else None,
               MODULE_ROOT / "WebView2Loader.dll"]
    target = Path.cwd() / "WebView2Loader.dll"
    for src in sources:
        if src is not None and src.exists():
            # 先删目标再复制：共享卷上 os.path.samefile 会把独立文件误判
            # 为同一文件(SameFileError)。
            if target.exists():
                target.unlink()
            shutil.copyfile(src, target)
            return


def ensure_native_artifacts() -> None:
    """原生库缺失或过期时现场调 prepare.py 构建；shim 源码更新时增量重编；
    进度一律走 stderr。vendored 库就位时直接返回（零编译）。"""
    if _native_dir() != BUILD_DIR:
        _copy_webview2_loader()
        return
    ready = _native_lib_path().exists() and not _stamp_stale()
    if ready and _shim_newer_than_lib():
        print("[moonbit-libyue] shim 源码已更新，增量重编原生库；"
              "编完请删除 _build 下已生成的 exe 以触发重链…", file=sys.stderr)
        build_cmd = ["cmake", "--build", str(BUILD_DIR), "--parallel"]
        if sys.platform == "win32":
            # VS 多配置生成器必须显式 --config，与 prepare.py 的 cmake_build 一致
            build_cmd += ["--config", "Release"]
        proc = subprocess.run(build_cmd, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True)
        sys.stderr.write(proc.stdout or "")
        if proc.returncode != 0:
            raise SystemExit(
                f"[moonbit-libyue] 原生库增量重编失败（退出码 {proc.returncode}）；"
                "可手动执行 python3 scripts/prepare.py 排查")
        _copy_webview2_loader()
        return
    if ready:
        _copy_webview2_loader()
        return
    reason = "版本或模式已变化" if _native_lib_path().exists() else "缺失"
    print(f"[moonbit-libyue] 原生库{reason}，开始自动准备（首次需 GitHub 网络）…",
          file=sys.stderr)
    prepare = Path(__file__).resolve().parent / "prepare.py"
    proc = subprocess.run([sys.executable, str(prepare)],
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True)
    sys.stderr.write(proc.stdout or "")
    if proc.returncode != 0:
        raise SystemExit(f"[moonbit-libyue] 原生层自动构建失败（退出码 {proc.returncode}）")
    _copy_webview2_loader()


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


def _prebuilt(name: str) -> str:
    """预构建模式下解出的 libyue 静态库绝对路径；不存在返回空串。"""
    p = _native_dir() / name
    if not p.exists():
        return ""
    return str(p.resolve()).replace("\\", "/")


def link_configs() -> dict:
    """各平台链接配置：Linux/macOS 为 GNU ld 风格，Windows 为 cl 命令行风格。

    全部参数放 link_flags 单一字符串自控顺序（-lyue_mbt 必须排在
    -lstdc++ 之前；预构建模式下 libyue_prebuilt 必须排在 shim 之后，
    GNU ld 单遍扫描依赖先序）；Windows 的静态库与 manifest.res 以绝对
    路径作为链接输入，分隔符用正斜杠。实测细节见 docs/adaptation.md。
    """
    build = str(_native_dir().resolve()).replace("\\", "/")
    if sys.platform == "win32":
            # YUE_MBT_SKIP_MANIFEST=1:不传 manifest.res（规避与 moon 自带
            # MANIFEST 的同名冲突）；真机不设则保留。
        manifest = "" if os.environ.get("YUE_MBT_SKIP_MANIFEST") == "1" \
            else f"{build}/yue_mbt_manifest.res "
        prebuilt = _prebuilt("yue_prebuilt.lib")
        return {"link_configs": [{
            "package": "NoahLiu/moonbit-libyue/yue",
            "link_flags": (
                f"{manifest}{build}/yue_mbt.lib"
                + (f" {prebuilt}" if prebuilt else "")
                + " " + " ".join(WINDOWS_LINK_LIBS)
            ),
        }]}
    if platform.system() == "Linux":
        arc = _prebuilt("libyue_prebuilt.a")
        core = f"-L{build} -lyue_mbt" + (f" {arc}" if arc else "")
        # -latomic：预构建库(官方 CMakeLists 清单也链 atomic)引用
        # __atomic_store，Ubuntu 22.04 工具链产物在最终链接必须显式给出
        extra = pkg_config_libs() + ["-lpthread", "-ldl", "-lm", "-lstdc++",
                                     "-latomic"]
    else:  # Darwin
        # macOS 双库结构（no-ARC 排其后）；源码模式第二库是 cmake 产出的
        # yue_mbt_noarc（-l 搜索），vendored/预构建模式第二库是随包的
        # libyue_noarc_prebuilt.a（绝对路径）。系统框架与运行时库不会自动
        # 传播到 moon 的链接命令行，必须显式给出（与 Linux 侧 pkg-config
        # 补系统库同构）。
        arc = _prebuilt("libyue_prebuilt.a")
        noarc = _prebuilt("libyue_noarc_prebuilt.a")
        core = f"-L{build} -lyue_mbt" + (f" {arc}" if arc else "")
        if (_native_dir() / "libyue_mbt_noarc.a").exists():
            core += " -lyue_mbt_noarc"
        if noarc:
            core += f" {noarc}"
        extra = [
            "-framework", "AppKit",
            "-framework", "Carbon",
            "-framework", "IOKit",
            "-framework", "Security",
            "-framework", "WebKit",
            "-framework", "OpenDirectory",
            # audit_token_to_pid（MachPortRendezvous）在 libbsm；
            # -Wl,-dead_strip 为官方构建的链接选项（CI 实测缺失即 undefined）
            "-lbsm", "-Wl,-dead_strip",
            "-lobjc", "-lc++", "-lpthread",
        ]
    return {"link_configs": [{
        "package": "NoahLiu/moonbit-libyue/yue",
        "link_flags": core + " " + " ".join(extra),
    }]}


def main() -> None:
    # Windows CI/控制台常为 cp1252 等无法编码中文的代码页，stderr 进度
    # 输出会 UnicodeEncodeError；转 UTF-8（stdout 是纯 ASCII JSON，不受影响）。
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    try:
        json.load(sys.stdin)  # moon 传入构建环境，当前无需使用
    except json.JSONDecodeError:
        pass
    ensure_native_artifacts()
    print(json.dumps(link_configs()))


if __name__ == "__main__":
    main()
