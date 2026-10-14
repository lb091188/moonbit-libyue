#!/usr/bin/env python3
"""NoahLiu/ffmpeg-mbt 的链接预构建脚本（--moonbit-unstable-prebuild）。

给 ffmpeg FFI 桩下发编译/链接参数，按平台分三路：

- Linux：pkg-config 探测 libavformat/libavcodec/libswscale/libswresample/
  libavutil（系统 dev 包），输出 link_flags 传播给所有依赖本包的 main 包。
  缺 dev 包时给出行级安装提示并以非零退出。
- Windows：dev 内容 vendor 进仓库（`vendor/include` 头 + `vendor/*.lib`
  导入库，取自 BtbN win64-lgpl-shared 构建，LGPLv3，见 vendor/FFMPEG-LICENSE.txt）。
  输出 `vars.FFMPEG_INC`（供 moon.pkg 的 stub-cc-flags 引用 `-I${build.FFMPEG_INC}`）
  和 link_flags（导入库绝对路径）。运行期 dll 不进仓库：本地把
  avcodec-63.dll 等与 exe 同目录或放 PATH（口径见 README）。
- macOS：与 Linux 同一路——pkg-config 探测系统 ffmpeg（`brew install ffmpeg`），
  头与链接参数随构建注入；探不到给出行级 brew 提示并以非零退出（与 Linux 缺
  dev 包同口径：媒体线要求系统给得出 ffmpeg，不静默造一份假可用）。区别只在
  brew 的 `.pc` 与头不在默认搜索路径上（Apple Silicon 是 /opt/homebrew，Intel
  是 /usr/local），所以要显式拼 PKG_CONFIG_PATH，并把 includedir 喂给
  `vars.FFMPEG_INC`（桩里的 `#include <libavformat/avformat.h>` 靠它）。

约束：stdout 只能是 JSON；进度信息走 stderr。
"""

from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
import sys

LIBS = ["libavformat", "libavcodec", "libswscale", "libswresample", "libavutil"]
PKG = "NoahLiu/ffmpeg-mbt/src"

# 导入库文件名（BtbN 构建无 lib 前缀）；与 LIBS 顺序对应
WIN_LIBS = ["avformat.lib", "avcodec.lib", "swscale.lib", "swresample.lib", "avutil.lib"]


def win_vendor_dir() -> str:
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "vendor")


# brew 的两个前缀（Apple Silicon / Intel）。GUI 环境里 PKG_CONFIG_PATH 与
# /usr/local、/opt/homebrew 都不在默认搜索路径上，探测前显式拼进去。
BREW_PREFIXES = ["/opt/homebrew", "/usr/local"]


def mac_env() -> dict:
    parts = [os.path.join(p, "lib", "pkgconfig") for p in BREW_PREFIXES]
    cur = os.environ.get("PKG_CONFIG_PATH", "")
    if cur:
        parts.insert(0, cur)
    return dict(os.environ, PKG_CONFIG_PATH=":".join(parts))


def pkg_config(args: list[str], env: dict | None = None) -> str:
    """跑一次 pkg-config，成功给 stdout（按空白切分），失败给空串。"""
    run = subprocess.run(
        ["pkg-config", *args], capture_output=True, text=True, env=env
    )
    return " ".join(run.stdout.split()) if run.returncode == 0 else ""


def mac_includedir(fallback: str) -> str:
    """ffmpeg 头所在目录：先问 pkg-config 的 includedir，问不到就扫 brew 前缀
    （存在 libavformat/avformat.h 的那一个），再不行给占位值让后面报同一个错。"""
    got = pkg_config(["--cflags-only-I", "libavformat"])
    for tok in got.split():
        if tok.startswith("-I"):
            cand = tok[2:]
            if os.path.isfile(os.path.join(cand, "libavformat", "avformat.h")):
                return cand
    for p in BREW_PREFIXES:
        cand = os.path.join(p, "include")
        if os.path.isfile(os.path.join(cand, "libavformat", "avformat.h")):
            return cand
    return fallback


def emit(payload: dict) -> None:
    print(json.dumps(payload))


def main() -> int:
    system = platform.system()

    if system == "Windows":
        vendor = win_vendor_dir()
        inc = os.path.join(vendor, "include")
        missing = [l for l in WIN_LIBS if not os.path.isfile(os.path.join(vendor, l))]
        has_headers = os.path.isfile(os.path.join(inc, "libavformat", "avformat.h"))
        if not has_headers or missing:
            # vendor 内容缺失：降级为空 link_configs 保可构建（与 macOS 同口径）
            print(
                "ffmpeg(prebuild): vendor dev 内容缺失"
                f"（{'缺头文件' if not has_headers else ''}"
                f"{' 缺 ' + ' '.join(missing) if missing else ''}），"
                "ffmpeg 后端降级——请按 README 恢复 vendor/",
                file=sys.stderr,
            )
            emit({"vars": {"FFMPEG_INC": ".", "FFMPEG_STUB_CC": "/utf-8"}, "link_configs": []})
            return 0
        # 路径一律正斜杠（cl 对两种都接受，还免去 JSON 转义）
        inc_norm = inc.replace("\\", "/")
        link_flags = " ".join(
            os.path.join(vendor, l).replace("\\", "/") for l in WIN_LIBS
        )
        print(
            "ffmpeg(prebuild): Windows 走 vendor 导入库（BtbN lgpl-shared）",
            file=sys.stderr,
        )
        emit(
            {
                "vars": {"FFMPEG_INC": inc_norm, "FFMPEG_STUB_CC": "/utf-8"},
                "link_configs": [{"package": PKG, "link_flags": link_flags}],
            }
        )
        return 0

    if system == "Darwin":
        # 与 Linux 同一路：探测系统 ffmpeg（brew 的 lgpl-shared 构建给得出 .pc）。
        # 探不到就非零退出并给 brew 提示——媒体线要求系统给得出 ffmpeg，
        # 静默编一支「看着能链、跑起来没解码器」的桩更坏。
        env = mac_env()
        if shutil.which("pkg-config") is None:
            print(
                "ffmpeg(prebuild): macOS 需要 pkg-config 定位 ffmpeg"
                "（brew install pkg-config ffmpeg）",
                file=sys.stderr,
            )
            return 1
        flags: list[str] = []
        for lib in LIBS:
            out = pkg_config(["--libs", lib], env)
            if not out:
                print(
                    f"ffmpeg(prebuild): 缺少 {lib}（macOS: brew install ffmpeg），"
                    "ffmpeg 后端不可用",
                    file=sys.stderr,
                )
                return 1
            flags.extend(out.split())
        inc = mac_includedir(BREW_PREFIXES[0] + "/include")
        # brew 的 .pc 一般已在 Libs 里展开过 -L，这里再问一次 libdir 兜底
        # （Apple Silicon 是 /opt/homebrew/lib、Intel 是 /usr/local/lib，写死任
        # 一个都会在另一类机器上链不到）。
        libdir = pkg_config(["--variable=libdir", "libavformat"], env) or os.path.join(
            os.path.dirname(inc), "lib"
        )
        print(
            f"ffmpeg(prebuild): macOS 走 brew 的 ffmpeg（include={inc} lib={libdir}）",
            file=sys.stderr,
        )
        emit(
            {
                "vars": {
                    "FFMPEG_INC": inc,
                    "FFMPEG_STUB_CC": "-finput-charset=UTF-8",
                },
                "link_configs": [
                    {
                        "package": PKG,
                        "link_flags": f"-L{libdir} " + " ".join(flags),
                    }
                ],
            }
        )
        return 0

    if system != "Linux":
        print(
            "ffmpeg(prebuild): 其余平台降级为空 link_configs（Linux/Windows/macOS 之外的目标）",
            file=sys.stderr,
        )
        emit({"vars": {"FFMPEG_INC": ".", "FFMPEG_STUB_CC": "-finput-charset=UTF-8"}, "link_configs": []})
        return 0

    if shutil.which("pkg-config") is None:
        print("ffmpeg(prebuild): 缺少 pkg-config，请先安装", file=sys.stderr)
        return 1
    flags: list[str] = []
    for lib in LIBS:
        probe = subprocess.run(
            ["pkg-config", "--libs", lib], capture_output=True, text=True
        )
        if probe.returncode != 0:
            print(
                f"ffmpeg(prebuild): 缺少 {lib} 开发包"
                f"（Ubuntu: sudo apt install -y {' '.join(l + '-dev' for l in LIBS)}）",
                file=sys.stderr,
            )
            return 1
        flags.extend(probe.stdout.split())
    emit(
        {
            "vars": {
                "FFMPEG_INC": "/usr/include",
                # gcc/clang 默认按 UTF-8 读源，显式声明与 Windows 的 /utf-8 同义
                "FFMPEG_STUB_CC": "-finput-charset=UTF-8",
            },
            "link_configs": [{"package": PKG, "link_flags": " ".join(flags)}],
        }
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
