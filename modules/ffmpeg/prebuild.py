#!/usr/bin/env python3
"""NoahLiu/ffmpeg 的链接预构建脚本（--moonbit-unstable-prebuild）。

动态链系统 ffmpeg 库：构建期用 pkg-config 探测 libavformat/libavcodec/
libswscale/libavutil，输出 link_configs 传播给所有依赖本包的 main 包。
约束：stdout 只能是 JSON；进度信息走 stderr。

依赖：系统的 ffmpeg 开发包（Ubuntu: libavcodec-dev 等；运行期只需对应
运行库 libavcodec60 等，通常随 ffmpeg 安装）。缺 dev 包时给出行级安装
提示并以非零退出。
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys

LIBS = ["libavformat", "libavcodec", "libswscale", "libavutil"]


def main() -> int:
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
                        "package": "NoahLiu/ffmpeg/src",
                        "link_flags": " ".join(flags),
                    }
                ]
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
