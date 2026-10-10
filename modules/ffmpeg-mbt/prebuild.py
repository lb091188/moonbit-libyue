#!/usr/bin/env python3
"""NoahLiu/ffmpeg 的链接预构建脚本（--moonbit-unstable-prebuild）。

动态链系统 ffmpeg 库：构建期用 pkg-config 探测 libavformat/libavcodec/
libswscale/libswresample/libavutil，把探测到的库拼进 link_configs 传播给
所有依赖本包的 main 包。
约束：stdout 只能是 JSON；进度信息走 stderr。

依赖：系统的 ffmpeg 开发包（Ubuntu: libavcodec-dev 等；macOS: brew
install ffmpeg，自带 pkg-config 文件；运行期只需对应运行库
libavcodec60 等，通常随 ffmpeg 安装）。

缺包行为：stderr 告警 + 对应链接参数留空，以零退出。硬失败会让没有
ffmpeg 的平台连 moon check / moon test 都跑不了；真实缺库由链接期的
未定义符号报错给出（只发生在确实用到解码的 main 包上）。
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys

LIBS = ["libavformat", "libavcodec", "libswscale", "libswresample", "libavutil"]


def main() -> int:
    flags: list[str] = []
    missing: list[str] = []
    if shutil.which("pkg-config") is None:
        missing = list(LIBS)
    else:
        for lib in LIBS:
            probe = subprocess.run(
                ["pkg-config", "--libs", lib], capture_output=True, text=True
            )
            if probe.returncode != 0:
                missing.append(lib)
            else:
                flags.extend(probe.stdout.split())
    if missing:
        print(
            "ffmpeg(prebuild): 未探测到 "
            + " ".join(missing)
            + " 开发包，对应链接参数留空"
            "（链接期如真实用到会报未定义符号；Ubuntu: sudo apt install -y "
            + " ".join(l + "-dev" for l in LIBS)
            + "；macOS: brew install ffmpeg）",
            file=sys.stderr,
        )
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
