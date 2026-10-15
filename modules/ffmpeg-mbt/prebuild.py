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
- macOS：ffmpeg 后端随 macOS 线落地时再接，优雅降级为空 link_configs
  保可构建（vars 仍给占位值，避免 moon.pkg 的 ${build.FFMPEG_INC} 落空）。

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
        # 各库路径单独加双引号：link_flags 会被按 shell 词法拆分，而用户名含
        # 单引号的机器（如 noah'liu）里路径自带未配对引号，整条 link_flags 会被
        # 静默丢弃（与 gui/web 的 WEB_PACKAGE 同一个坑，根因与判据见
        # docs/zh/adaptation.md「同族第二条·撇号路径让整条 link_flags 静默消失」）。
        link_flags = " ".join(
            f'"{p}"'
            for p in (os.path.join(vendor, l).replace("\\", "/") for l in WIN_LIBS)
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

    if system != "Linux":
        print(
            "ffmpeg(prebuild): 非 Linux/Windows 平台降级为空 link_configs（媒体线随平台落地再接）",
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
