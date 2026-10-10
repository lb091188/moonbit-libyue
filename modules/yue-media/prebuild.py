#!/usr/bin/env python3
"""NoahLiu/yue-media 的预构建脚本（--moonbit-unstable-prebuild）。

唯一职责：在编译 native-stub 之前确保 `src/miniaudio.h` 在场且与钉死版本
一致——`src/audio_stub.c` 里有 `#define MINIAUDIO_IMPLEMENTATION` +
`#include "miniaudio.h"`，miniaudio 的实现就是在这里被编进本模块的
native-stub 翻译单元，所以「取回头文件」是唯一的准备工作，无需 clone 上游
仓库、也无需单独编译 miniaudio。

行为：

  - `src/miniaudio.h` 已存在且 sha256 相符 → 直接跳过（幂等；离线环境可
    预先放好该文件，构建零网络）；
  - 缺失或 sha256 不符 → 从钉死 URL 下载到临时文件，校验后原子替换。

约束：stdout 只能是 JSON（本模块无链接参数，输出空 link_configs）；进度与
错误信息一律走 stderr；失败以非零退出。升级 miniaudio 时同步改
`MINIAUDIO_VERSION` 与 `MINIAUDIO_SHA256` 两处（sha256 用 `sha256sum` 取）。
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import urllib.request
from pathlib import Path

MODULE_ROOT = Path(__file__).resolve().parent
TARGET = MODULE_ROOT / "src" / "miniaudio.h"

MINIAUDIO_VERSION = "0.11.25"
MINIAUDIO_SHA256 = "ac7af4de748b7e26b777f37e01cee313a308a7296a3eb080e2906b320cc55c89"
MINIAUDIO_URL = (
    "https://raw.githubusercontent.com/mackron/miniaudio/"
    f"{MINIAUDIO_VERSION}/miniaudio.h"
)


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def ensure_header() -> int:
    if TARGET.exists():
        actual = sha256_of(TARGET)
        if actual == MINIAUDIO_SHA256:
            print(
                f"[yue-media] miniaudio.h 已就绪（{MINIAUDIO_VERSION}，sha256 相符），跳过下载",
                file=sys.stderr,
            )
            return 0
        print(
            f"[yue-media] miniaudio.h sha256 不符（期望 {MINIAUDIO_SHA256[:12]}…，"
            f"实际 {actual[:12]}…），重新下载",
            file=sys.stderr,
        )
    else:
        print(
            f"[yue-media] 缺少 src/miniaudio.h，从上游取回 {MINIAUDIO_VERSION}"
            "（首次需 GitHub 网络）…",
            file=sys.stderr,
        )

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    partial = TARGET.with_suffix(".h.partial")
    try:
        urllib.request.urlretrieve(MINIAUDIO_URL, partial)
    except Exception as exc:  # noqa: BLE001
        partial.unlink(missing_ok=True)
        print(
            f"[yue-media] 下载失败：{exc}\n"
            f"[yue-media] 可手动放置后重试：把 miniaudio {MINIAUDIO_VERSION} 的 miniaudio.h\n"
            f"            放到 {TARGET}\n"
            f"            （sha256 应为 {MINIAUDIO_SHA256}）",
            file=sys.stderr,
        )
        return 1

    actual = sha256_of(partial)
    if actual != MINIAUDIO_SHA256:
        partial.unlink(missing_ok=True)
        print(
            f"[yue-media] 下载后 sha256 不匹配：期望 {MINIAUDIO_SHA256}，实际 {actual}",
            file=sys.stderr,
        )
        return 1

    os.replace(partial, TARGET)
    print(
        f"[yue-media] 已取回 miniaudio.h（{MINIAUDIO_VERSION}，sha256 校验通过）",
        file=sys.stderr,
    )
    return 0


def main() -> int:
    # Windows 控制台可能是 cp1252 等代码页，中文 stderr 会 UnicodeEncodeError；
    # 转 UTF-8（stdout 是纯 ASCII JSON，不受影响）。
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    try:
        json.load(sys.stdin)  # moon 传入构建环境，当前无需使用
    except (json.JSONDecodeError, ValueError):
        pass

    code = ensure_header()
    if code != 0:
        return code
    print(json.dumps({"link_configs": []}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
