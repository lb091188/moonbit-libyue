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

import hashlib
import json
import os
import platform
import sys
import urllib.request
from pathlib import Path

MEDIA_PACKAGE = "NoahLiu/gui-media/media"
SYS_LIBS = ["-lpthread", "-ldl", "-lm", "-lstdc++", "-latomic"]

# macOS：miniaudio 的 CoreAudio 后端要的三个框架（AudioToolbox 供 AudioUnit 一族，
# CoreAudio 供 AudioObject*，Foundation 供它用到的 CF/NSObject 桥）。**没有**
# -ldl 与 -latomic——mac 的 dlopen 在 libSystem 里、-latomic 这个库压根不存在，
# 照抄 Linux 那一串会在链接期报 library not found（这是与 Linux 分支唯一的差别，
# 不是少装了东西）。
MAC_FRAMEWORKS = [
    "-framework", "CoreAudio",
    "-framework", "AudioToolbox",
    "-framework", "Foundation",
]
MAC_SYS_LIBS = ["-lpthread", "-lm"]

# miniaudio.h 自 2026-10-14 起不再入库，改挂 Release 资产：构建时缺失即下载并
# 校验 sha256；离线环境可提前手工放置（已存在不动）。
#
# 镜像按序尝试、不做延迟探测，单源超时 20 秒——理由与主模块
# `gui/scripts/prebuild.py` 的同名逻辑逐字相同（sha256 过了才落盘，任何镜像都
# 可验证；先测快慢会让两台机器从不同源取，丢掉可复现性）。两处**刻意各留一份**：
# 本模块要能独立发布，不能反向依赖主模块的 scripts/。
# 外部源用环境变量 NATIVE_GUI_VENDOR_BASE 覆盖（单个 base 或逗号分隔列表）。
_VENDOR_BASES = [
    "https://github.com/lb091188/moonbit-native-gui/releases/download/vendor-v1",
    "https://gitee.com/lb091188/moonbit-native-gui/releases/download/vendor-v1",
]

_VENDOR_TIMEOUT = 20

_VENDOR_MINIAUDIO = (
    "miniaudio.h",
    Path(__file__).resolve().parent / "media" / "miniaudio.h",
    "e9e742f8c4d7cdd0fc81ba7f1c47b719d98d45e0138849aa0ec1e574d554a1ee",
)


def ensure_miniaudio() -> None:
    name, dest, sha = _VENDOR_MINIAUDIO
    if dest.exists():
        return
    env = os.environ.get("NATIVE_GUI_VENDOR_BASE", "")
    bases = [b.strip().rstrip("/") for b in env.split(",") if b.strip()] + _VENDOR_BASES
    for base in bases:
        url = f"{base}/{name}"
        try:
            print(f"gui-media(prebuild): 取 vendor {url} ...", file=sys.stderr)
            data = urllib.request.urlopen(url, timeout=_VENDOR_TIMEOUT).read()
        except Exception as e:  # noqa: BLE001——网络/URL 错误换下一个镜像
            print(f"gui-media(prebuild): 镜像失败（{e}）", file=sys.stderr)
            continue
        if hashlib.sha256(data).hexdigest() != sha:
            print(
                f"gui-media(prebuild): {name} 在该镜像上 sha256 不符，换下一个",
                file=sys.stderr,
            )
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        print(f"gui-media(prebuild): 已就位 {dest}（sha256 校验通过）", file=sys.stderr)
        return
    print(
        f"gui-media(prebuild): 全部镜像都没取到 {name}\n"
        f"  离线环境可手工放置到 {dest}，或用 NATIVE_GUI_VENDOR_BASE 指到自己的源",
        file=sys.stderr,
    )


def link_configs() -> dict:
    ensure_miniaudio()
    system = platform.system()
    if system == "Darwin":
        print(
            "gui-media(prebuild): macOS 走 miniaudio 的 CoreAudio 后端"
            "（CoreAudio/AudioToolbox/Foundation，不链 dl/atomic）",
            file=sys.stderr,
        )
        return {
            "link_configs": [
                {
                    "package": MEDIA_PACKAGE,
                    "link_flags": " ".join([*MAC_SYS_LIBS, *MAC_FRAMEWORKS]),
                }
            ]
        }
    if system != "Linux":
        print(
            "gui-media(prebuild): 其余平台空 link_configs——Windows 实测 miniaudio 的"
            " WASAPI/COM 全走运行期加载（LoadLibrary），零额外库，不是降级",
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
