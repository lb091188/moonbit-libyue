#!/usr/bin/env python3
"""moon add 安装后自动触发（moon.mod.json scripts.postadd）：执行
prepare.py 构建原生层。仅 registry 安装触发；path/git 依赖与模块自身
构建由 prebuild.py 的产物检查兜底。
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

prepare = Path(__file__).resolve().parent / "prepare.py"
subprocess.run([sys.executable, str(prepare)], check=True)
