#!/usr/bin/env python3
"""libyue MoonBit 封装的链接预构建脚本（--moonbit-unstable-prebuild）。

现状（MoonBit 原生 GUI 栈 G0b 起）：老的 `shim + libyue` 绑定链已从本分支摘除，
本脚本不再下载/构建/链接任何 libyue 产物，只保留两件事——

1. 把 G0 输入法探针的 C 端编成静态库（moon 的 link_configs 只有链接期字段、
   没有编译期字段，`c_flags` 会被静默忽略，故必须在脚本里编译，实测记录见
   docs/zh/adaptation.md「跨平台通用」节的 G1/G0 条）。
2. 输出 link_configs，按当前系统给出 pkg-config 探到的 GTK3/Pango/X11 参数。
   新栈自己的平台后端（yue/win）落地后，链接参数继续从这里传播。

约束：stdout 只允许输出 JSON，进度信息走 stderr。
"""

from __future__ import annotations

import json
import platform
import shutil
import subprocess
import sys
from pathlib import Path

MODULE_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = MODULE_ROOT / "build"

# Linux 系统库清单：GTK3 是新栈锁定的后端（零新增运行期依赖，本仓此前已在用），
# 探针与后续 yue/win 都从这里拿 cflags/libs。
LINUX_PKG_CONFIG_LIBS = ["gtk+-3.0", "pangoft2", "fontconfig", "x11"]

IME_PROBE_PACKAGE = "NoahLiu/moonbit-libyue/experiment/ime_probe"


def pkg_config(args: list[str], flag: str) -> list[str]:
    run = subprocess.run(
        ["pkg-config", flag] + args, capture_output=True, text=True
    )
    if run.returncode != 0:
        print(f"prebuild: pkg-config {flag} {' '.join(args)} 失败", file=sys.stderr)
        return []
    return run.stdout.split()


def build_ime_probe_stub() -> str:
    """G0 输入法探针（MoonBit 原生 GUI 栈首个 spike）的 C 端编译。"""
    src = MODULE_ROOT / "experiment" / "ime_probe" / "ime_probe_stub.c"
    if not src.exists():
        return ""
    obj = BUILD_DIR / "ime_probe_stub.o"
    lib = BUILD_DIR / "libime_probe_stub.a"  # ld 的 -l 命名约定
    if lib.exists() and lib.stat().st_mtime >= src.stat().st_mtime:
        return lib.as_posix()
    cflags: list[str] = []
    for name in LINUX_PKG_CONFIG_LIBS:
        got = pkg_config([name], "--cflags")
        if not got:
            print(f"ime_probe: 缺少 {name} 开发包", file=sys.stderr)
            return ""
        cflags.extend(got)
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    cc = shutil.which("cc") or shutil.which("gcc") or "cc"
    for cmd in (
        [cc, "-c", "-O0", "-fPIC", "-o", obj.as_posix(), src.as_posix()] + cflags,
        ["ar", "rcs", lib.as_posix(), obj.as_posix()],
    ):
        run = subprocess.run(cmd, capture_output=True, text=True)
        if run.returncode != 0:
            print(f"ime_probe: {' '.join(cmd)} 失败\n{run.stderr}", file=sys.stderr)
            return ""
    return lib.as_posix()


def link_configs() -> dict:
    entries: list[dict] = []
    if platform.system() == "Linux":
        libs = []
        for name in LINUX_PKG_CONFIG_LIBS:
            got = pkg_config([name], "--libs")
            if not got:
                print(f"prebuild: 缺少 {name} 开发包", file=sys.stderr)
                return {"link_configs": entries}
            libs.extend(got)
        # 系统库不会被自动带上，显式补（与旧链路同一口径）。
        sys_libs = ["-lpthread", "-ldl", "-lm", "-lstdc++", "-latomic"]
        stub = build_ime_probe_stub()
        if stub:
            entries.append({
                "package": IME_PROBE_PACKAGE,
                # 顺序要紧：先库后系统库（GNU ld 单遍扫描）。
                "link_flags": f"-L{BUILD_DIR.as_posix()} -lime_probe_stub "
                + " ".join([*libs, *sys_libs]),
            })
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
