#!/usr/bin/env python3
"""moon add 安装本模块后自动执行（moon.mod.json scripts.postadd）。

作用是触发原生层一次性构建（下载 libyue + CMake 静态库），使用方
`moon add lkyh/moonbit-libyue` 之后即可直接 `moon run`，无需手动跑
prepare.py。后续构建由 prebuild.py 的产物检查兜底。

注意：moon add 从 registry 安装时触发；path/git 依赖与模块自身构建
不触发，此时由 prebuild.py 在产物缺失时自动补建。
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

prepare = Path(__file__).resolve().parent / "prepare.py"
subprocess.run([sys.executable, str(prepare)], check=True)
