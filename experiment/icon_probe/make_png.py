#!/usr/bin/env python3
"""生成一个 8x8 的 RGBA PNG，供 experiment/icon_probe 的纯 C 探针验 WIC 解码路径。

用标准库 zlib 手写最小 PNG（IHDR + IDAT + IEND，逐行 filter 0），不依赖 Pillow。

用法：python3 experiment/icon_probe/make_png.py [输出路径]
默认输出到当前目录的 icon_probe_test.png。
"""
import struct
import sys
import zlib


def chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def main(out: str = "icon_probe_test.png", size: int = 8) -> None:
    raw = bytearray()
    for _y in range(size):
        raw.append(0)  # 每行的 filter 类型
        for _x in range(size):
            raw += bytes((255, 0, 0, 128))  # 半透明红（RGBA，直通 alpha）
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(out, "wb") as f:
        f.write(png)
    print(f"{out} ({len(png)} bytes, {size}x{size} RGBA)")


if __name__ == "__main__":
    main(*sys.argv[1:])
