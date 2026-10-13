#!/usr/bin/env python3
"""NoahLiu/native-gui-experiment 的链接预构建脚本（--moonbit-unstable-prebuild）。

只做一件事：给本模块的输入法探针 `ime_probe` 编 C 端静态库并下发链接参数——
G0 输入法探针的桩要 GTK3/X11 头与库，moon 的 link_configs 只有链接期字段、
c_flags 会被静默忽略，所以必须在脚本里编译。

（这条目原本写在 gui 模块的 prebuild 里、按包名跨模块下发；experiment 拆成
独立模块后，moon 对 link_configs 按模块校验包名归属，跨模块条目在 gui 侧
报「does not match any package in module」、堵死所有 moon test——条目随包
搬回本模块，与 gui-media 的先例同一口径。）

约束：stdout 只能是 JSON；进度信息走 stderr。
非 Linux：Windows 实测走 ime_probe_stub_portable.c（moon native-stub 自编）
零额外链接库即归零（63c84d9 实测），空 link_configs 即正确形态。
"""

from __future__ import annotations

import json
import platform
import shutil
import subprocess
import sys
from pathlib import Path

MODULE_ROOT = Path(__file__).resolve().parent.parent  # experiment/（模块根）
IME_PROBE_PACKAGE = "NoahLiu/native-gui-experiment/ime_probe"
BUILD_DIR = MODULE_ROOT / "build"

# 与 gui 模块 prebuild 同一套系统库清单：探针桩直接吃 GTK3/X11 头。
LINUX_PKG_CONFIG_LIBS = ["gtk+-3.0", "pangoft2", "pangocairo", "fontconfig", "x11"]
SYS_LIBS = ["-lpthread", "-ldl", "-lm", "-lstdc++", "-latomic"]


def pkg_config(args: list[str], flag: str) -> list[str] | None:
    """探包配置：None = 包不存在；空列表 = 存在但该 flag 无合法空输出。"""
    run = subprocess.run(["pkg-config", flag] + args, capture_output=True, text=True)
    if run.returncode != 0:
        return None
    return run.stdout.split()


def link_configs() -> dict:
    if platform.system() != "Linux":
        print(
            "experiment(prebuild): 非 Linux 平台降级为空 link_configs（ime_probe Windows 走 portable 桩零额外库）",
            file=sys.stderr,
        )
        return {"link_configs": []}
    libs = []
    for name in LINUX_PKG_CONFIG_LIBS:
        got = pkg_config([name], "--libs")
        if got is None:
            print(
                f"experiment(prebuild): 缺少 {name} 开发包，ime_probe 链接条目不下发",
                file=sys.stderr,
            )
            return {"link_configs": []}
        libs.extend(got)
    src = MODULE_ROOT / "ime_probe" / "ime_probe_stub.c"
    if not src.exists():
        print(f"experiment(prebuild): 源文件不存在，跳过：{src}", file=sys.stderr)
        return {"link_configs": []}
    cflags: list[str] = []
    for name in LINUX_PKG_CONFIG_LIBS:
        got = pkg_config([name], "--cflags")
        if got is None:
            print(f"experiment(prebuild): 缺少 {name} 开发包", file=sys.stderr)
            return {"link_configs": []}
        cflags.extend(got)
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    obj = BUILD_DIR / "ime_probe_stub.o"
    lib = BUILD_DIR / "libime_probe_stub.a"  # ld 的 -l 命名约定
    cc = shutil.which("cc") or shutil.which("gcc") or "cc"
    if not (lib.exists() and lib.stat().st_mtime >= src.stat().st_mtime):
        for cmd in (
            [cc, "-c", "-O0", "-fPIC", "-o", obj.as_posix(), src.as_posix()] + cflags,
            ["ar", "rcs", lib.as_posix(), obj.as_posix()],
        ):
            run = subprocess.run(cmd, capture_output=True, text=True)
            if run.returncode != 0:
                print(
                    f"experiment(prebuild): {' '.join(cmd)} 失败\n{run.stderr}",
                    file=sys.stderr,
                )
                return {"link_configs": []}
    return {
        "link_configs": [
            {
                "package": IME_PROBE_PACKAGE,
                # 顺序要紧：先库后系统库（GNU ld 单遍扫描）。
                "link_flags": f"-L{BUILD_DIR.as_posix()} -lime_probe_stub "
                + " ".join([*libs, *SYS_LIBS]),
            }
        ]
    }


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
