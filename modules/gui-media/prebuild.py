#!/usr/bin/env python3
"""NoahLiu/gui-media 的链接预构建脚本（--moonbit-unstable-prebuild）。

只做一件事：给新栈媒体包 `NoahLiu/gui-media/media` 下发系统库链接参数——
miniaudio 的设备线程与运行期 dlopen 后端要 pthread/dl/m/lstdc++/atomic。
（这条目原本写在主仓 `scripts/prebuild.py` 里、按包名下发给
`NoahLiu/gui-media/media`；媒体包迁到本模块后，条目随包名一起搬来，
主仓 prebuild 不再碰媒体。）

媒体解码链（libav* 一组）的 flags 由 `ffmpeg-mbt` 自己的 prebuild 按包名
`NoahLiu/ffmpeg-mbt/src` 下发，本脚本不重复。

约束：stdout 只能是 JSON；进度信息走 stderr。
非 Linux：Windows 实测 miniaudio 的 WASAPI/COM 全走运行期加载（LoadLibrary
ole32 等），零额外链接库——空 link_configs 即正确形态，不是降级；macOS
（CoreAudio）待 macOS 线落地时再核对口径。
"""

from __future__ import annotations

import json
import platform
import sys

MEDIA_PACKAGE = "NoahLiu/gui-media/media"
SYS_LIBS = ["-lpthread", "-ldl", "-lm", "-lstdc++", "-latomic"]


def link_configs() -> dict:
    if platform.system() != "Linux":
        print(
            "gui-media(prebuild): 非 Linux 平台降级为空 link_configs（媒体线随平台落地）",
            file=sys.stderr,
        )
        return {"link_configs": []}
    return {
        "link_configs": [
            {"package": MEDIA_PACKAGE, "link_flags": " ".join(SYS_LIBS)}
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
