#!/usr/bin/env python3
"""NoahLiu/gui-webview 的链接预构建脚本（--moonbit-unstable-prebuild）。

只做一件事：给本模块包 `NoahLiu/gui-webview/webview` 下发 webview 引擎的编译与
链接参数——G9 Batch 1 起 web 出成独立模块，WebView2 vendor 资产与 WebKitGTK
探测不再由主仓 `gui/scripts/prebuild.py` 管。

Linux：pkg-config 探 `webkit2gtk-4.1`，带 `-DWB_HAVE_WEBKIT` 把 `webkit_stub.c`
编成静态库；缺开发包不算错——native-stub 那次无宏编译已给出占位符号，
MoonBit 侧按 `webview_supported()` 探测降级。真实现分支引用主模块 win 桩的
`wm_surface_container()`，所以链接行要带上主模块编好的 `libyue_win_stub.a`——
本脚本按「workspace 兄弟目录 → 依赖缓存 → 当前工作区 _build」三处定位，
定位不到时退回占位分支（宁可不链，不给断链的 exe）。

Windows：`webview2_stub.c` 由 moon native-stub 自编（vendor 头相对路径自取），
这里只下发静态 Loader（缺失时按 sha256 从 Release 资产下载，口径与主仓原
实现逐字相同——两模块刻意各留一份，本模块要能独立发布）。

macOS：不匹配任何分支（`webkit_stub.c` 的占位分支覆盖非 Linux 非 Windows），
符号不断、探测返回不可用；`orderOut:` 形态随 W22 mac 批。

约束：stdout 只能是 JSON；进度信息走 stderr。
"""

from __future__ import annotations

import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

MODULE_ROOT = Path(__file__).resolve().parent  # modules/gui-webview/
PKG = "NoahLiu/gui-webview/webview"
BUILD_DIR = MODULE_ROOT / "build"

WEBKIT_PKG_CONFIG = "webkit2gtk-4.1"

# ---------------------------------------------------------------------------
# vendor 大文件走 Release 资产（口径继承主仓 2026-10-14 的决定）：WebView2
# 静态 Loader 与 SDK 头体积大且基本不更新，不入库；构建时缺失即下载并校验
# sha256，离线环境可提前手工放置（已存在不动）。镜像按序尝试、不做延迟探测，
# 单源超时 20 秒。外部源用环境变量 NATIVE_GUI_VENDOR_BASE 覆盖。
# ---------------------------------------------------------------------------
VENDOR_BASES = [
    "https://github.com/lb091188/moonbit-native-gui/releases/download/vendor-v1",
    "https://gitee.com/lb091188/moonbit-native-gui/releases/download/vendor-v1",
]

VENDOR_TIMEOUT = 20

VENDOR_FILES = [
    (
        "webview/lib/WebView2LoaderStatic.lib",
        "e66284970876a616c82e7dcda75a17fd46d04827f9de81d4299b8862d34d25d6",
    ),
    (
        "webview/include/WebView2.h",
        "dff1e3181ec7ec203a34ef6efa966590e0ef0ba1a5c3fe3b69da6508c2f8a02e",
    ),
]


def vendor_bases() -> list[str]:
    env = os.environ.get("NATIVE_GUI_VENDOR_BASE", "")
    extra = [b.strip().rstrip("/") for b in env.split(",") if b.strip()]
    return extra + VENDOR_BASES


def fetch_vendor_file(name: str, sha: str) -> "bytes | None":
    for base in vendor_bases():
        url = f"{base}/{name}"
        try:
            print(f"prebuild: 取 vendor {url} ...", file=sys.stderr)
            data = urllib.request.urlopen(url, timeout=VENDOR_TIMEOUT).read()
        except Exception as e:  # noqa: BLE001——任何网络/URL 错误都换下一个镜像
            print(f"prebuild: 镜像失败（{e}）", file=sys.stderr)
            continue
        if hashlib.sha256(data).hexdigest() != sha:
            print(f"prebuild: {name} 在该镜像上 sha256 不符，换下一个", file=sys.stderr)
            continue
        return data
    return None


def ensure_release_files() -> None:
    for rel, sha in VENDOR_FILES:
        dest = MODULE_ROOT / rel
        if dest.exists():
            continue
        data = fetch_vendor_file(dest.name, sha)
        if data is None:
            print(
                f"prebuild: 全部镜像都没取到 {dest.name}\n"
                f"  离线环境可手工放置，或用 NATIVE_GUI_VENDOR_BASE 指到自己的源",
                file=sys.stderr,
            )
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        print(f"prebuild: 已就位 {dest}（sha256 校验通过）", file=sys.stderr)


def pkg_config(args: list[str], flag: str) -> list[str] | None:
    run = subprocess.run(["pkg-config", flag] + args, capture_output=True, text=True)
    if run.returncode != 0:
        return None
    return run.stdout.split()


def find_win_stub_archive() -> Path | None:
    """定位主模块 win 桩的静态库（webkit 真实现引用其 wm_surface_container）。

    候选按构建现实排序：本仓 workspace（modules/gui-webview 与 gui 同级）→
    moon 依赖缓存里的 native-gui（registry 消费方在 workspace 外时）→
    当前工作区 _build（prebuild 产物目录里找同名归档）。"""
    home = Path(os.environ.get("MOON_HOME", str(Path.home() / ".moon")))
    candidates = [
        MODULE_ROOT.parent.parent / "gui" / "build" / "libyue_win_stub.a",
        home / "packages" / "NoahLiu" / "native-gui" / "gui" / "build" / "libyue_win_stub.a",
        home / "deps" / "NoahLiu" / "native-gui" / "gui" / "build" / "libyue_win_stub.a",
    ]
    if candidates[0].exists():
        return candidates[0]
    for base in candidates[1:]:
        if base.exists():
            return base
    # _build 兜底：cwd 或 module_root 上溯两级的 _build 里 glob（hash 目录名不猜）
    for root in (Path.cwd(), MODULE_ROOT.parent, MODULE_ROOT.parent.parent):
        blob = root / "_build" / "native"
        if not blob.is_dir():
            continue
        hits = sorted(
            blob.glob(f"*/build/prebuild/*/libyue_win_stub.a"),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )
        if hits:
            return hits[0]
    return None


def compile_webkit_stub(win_archive: Path) -> str:
    """把 webkit_stub.c 带 -DWB_HAVE_WEBKIT 编成静态库，返回库路径；失败给空串。"""
    cflags = pkg_config([WEBKIT_PKG_CONFIG], "--cflags")
    if cflags is None:
        print(
            f"prebuild: 缺 {WEBKIT_PKG_CONFIG}，webview 走占位实现（探测返回不可用）",
            file=sys.stderr,
        )
        return ""
    src = MODULE_ROOT / "webview" / "webkit_stub.c"
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    lib = BUILD_DIR / "libgui_webview.a"
    if lib.exists() and lib.stat().st_mtime >= src.stat().st_mtime:
        return lib.as_posix()
    cc = shutil.which("cc") or shutil.which("gcc") or "cc"
    obj = BUILD_DIR / "webkit_stub.o"
    cmd = [cc, "-c", "-O2", "-fPIC", "-DWB_HAVE_WEBKIT", "-o", obj.as_posix(),
           src.as_posix(), *cflags]
    run = subprocess.run(cmd, capture_output=True, text=True)
    if run.returncode != 0:
        print(f"stub: {' '.join(cmd)} 失败\n{run.stderr}", file=sys.stderr)
        return ""
    # 先删旧归档再建：`ar rcs` 对改了名的成员是追加，会留重复符号
    lib.unlink(missing_ok=True)
    run = subprocess.run(["ar", "rcs", lib.as_posix(), obj.as_posix()],
                         capture_output=True, text=True)
    if run.returncode != 0:
        print(f"stub: ar 失败\n{run.stderr}", file=sys.stderr)
        return ""
    return lib.as_posix()


def link_configs() -> dict:
    entries: list[dict] = []
    ensure_release_files()
    system = platform.system()
    if system == "Linux":
        win_archive = find_win_stub_archive()
        webkit_libs = pkg_config([WEBKIT_PKG_CONFIG], "--libs")
        if win_archive is None or webkit_libs is None:
            reason = (
                "找不到主模块 win 桩归档 gui/build/libyue_win_stub.a"
                if win_archive is None
                else f"缺 {WEBKIT_PKG_CONFIG} 开发包"
            )
            print(f"prebuild: {reason}，webview 走占位实现（探测返回不可用）", file=sys.stderr)
            return {"link_configs": entries}
        web_lib = compile_webkit_stub(win_archive)
        if not web_lib:
            return {"link_configs": entries}
        sys_libs = ["-lpthread", "-ldl", "-lm", "-lstdc++", "-latomic"]
        win_dir = win_archive.parent
        entries.append({
            "package": PKG,
            # 路径整体加双引号：撇号用户名会按 shell 词法拆碎整条 link_flags
            # （主仓 adaptation.md「同族第二条·撇号路径」教训，同口径预防）
            "link_flags": (
                f"-L{BUILD_DIR.as_posix()} -lgui_webview "
                f'-L"{win_dir.as_posix()}" -lyue_win_stub '
                + " ".join([*webkit_libs, *sys_libs])
            ),
        })
    elif system == "Windows":
        # 静态 Loader 免运行期分发 DLL（Evergreen Runtime 本机已有，探测在 C 桩做）。
        # 依赖的 win 桩符号（wm_surface_container 等）由 moon native-stub 的归档
        # 提供——主包链 win 桩，同一个 exe 链接行里符号天然可见。
        wv2_lib = MODULE_ROOT / "webview" / "lib" / "WebView2LoaderStatic.lib"
        if wv2_lib.exists():
            entries.append({
                "package": PKG,
                "link_flags": f'"{wv2_lib.as_posix()}" shlwapi.lib ole32.lib '
                "oleaut32.lib uuid.lib user32.lib gdi32.lib advapi32.lib",
            })
        else:
            print(
                "prebuild: 缺 webview/lib/WebView2LoaderStatic.lib，webview 走占位实现（探测返回不可用）",
                file=sys.stderr,
            )
    return {"link_configs": entries}


def main() -> None:
    # Windows 控制台常为 cp1252，stderr 打中文会 UnicodeEncodeError；转 UTF-8。
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    try:
        json.load(sys.stdin)  # moon 传入构建环境，当前无需使用
    except json.JSONDecodeError:
        pass
    print(json.dumps(link_configs()))


if __name__ == "__main__":
    main()
