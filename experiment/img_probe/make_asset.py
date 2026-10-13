#!/usr/bin/env python3
"""重建 img_probe 的测试资产 assets/subrect.gif。

为什么需要它：WIC 的 GIF 解码器给的是**原始子矩形帧**（帧矩形 + `/imgdesc/Left|Top`
偏移），整幅合成是调用方的职责——而仓库里的 `examples/showcase/assets/dot.gif`
四帧都是整幅 120x120，验不出子矩形这条路径。这里用 ffmpeg 的 GIF 编码器造一个
「第二帧只覆盖一小块」的 GIF（编码器默认开 `+offsetting` 优化，会把差异区裁成
子矩形帧）。

生成结果（实测）：40x40 逻辑屏幕、2 帧；第 0 帧整幅黑、第 1 帧 12x12 @(14,14)
的红块，两帧 disposal 都是 1（do not dispose）——所以合成后 (0,0) 必须仍是第 0
帧的黑，这正是 img_backend_probe 的回归判据。

用法：
  python make_asset.py            # 需要 PATH 里有 ffmpeg
输出：assets/subrect.gif（与本脚本同目录）
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "assets", "subrect.gif")


def main() -> int:
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        print("找不到 ffmpeg，无法重建资产", file=sys.stderr)
        return 1
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    cmd = [
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
        "-f", "lavfi", "-i", "color=c=black:s=40x40:r=2:d=1",
        "-vf", "drawbox=enable='gte(t,0.5)':x=15:y=15:w=10:h=10:color=red:t=fill",
        "-loop", "0", OUT,
    ]
    subprocess.run(cmd, check=True)
    print(f"已写出 {OUT}（{os.path.getsize(OUT)} 字节）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
