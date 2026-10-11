#!/usr/bin/env python3
"""NoahLiu/ffmpeg 的链接预构建脚本（--moonbit-unstable-prebuild）。

动态链系统 ffmpeg 库：构建期用 pkg-config 探测 libavformat/libavcodec/
libswscale/libswresample/libavutil，输出 link_configs 传播给所有依赖本包
的 main 包。
约束：stdout 只能是 JSON；进度信息走 stderr。

依赖：系统的 ffmpeg 开发包（Ubuntu: libavcodec-dev 等；运行期只需对应
运行库 libavcodec60 等，通常随 ffmpeg 安装）。缺 dev 包时给出行级安装
提示并以非零退出。

非 Linux（Windows/macOS）：ffmpeg 后端随各自媒体线落地时再接，这里
优雅降级为空 link_configs 保 workspace 可构建（与主 prebuild 的
非 Linux 口径一致）；Linux 行为不变。
"""

from __future__ import annotations

import json
import platform
import shutil
import subprocess
import sys

LIBS = ["libavformat", "libavcodec", "libswscale", "libswresample", "libavutil"]


def main() -> int:
    if platform.system() != "Linux":
        print("ffmpeg(prebuild): 非 Linux 平台降级为空 link_configs（媒体线随平台落地再接）", file=sys.stderr)
        print(json.dumps({"link_configs": []}))
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
    print(
        json.dumps(
            {
                "link_configs": [
                    {
                        "package": "NoahLiu/ffmpeg-mbt/src",
                        "link_flags": " ".join(flags),
                    }
                ]
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
