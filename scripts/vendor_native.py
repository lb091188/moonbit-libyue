#!/usr/bin/env python3
"""固化原生层产物到 lib/<平台>/（mooncakes 随包分发的 vendored 库）。

两种用法：
  python3 scripts/vendor_native.py
      在对应平台的机器上执行（通常是 CI 的分平台 job）：走 prepare 的
      预构建路径，把 build/ 下的 shim 静态库与解出的预构建 libyue 拷进
      lib/<平台>/；要求 prepare 实际走了预构建模式（stamp 校验）。
  python3 scripts/vendor_native.py --fetch <vendor-tag>
      从本仓库 vendor-* release 资产拉齐三平台目录（在维护机执行后
      提交进仓库，再走 moon publish）。

vendored 布局（仿 justjavac/quickjs）：
  lib/linux-x64/       libyue_mbt.a libyue_prebuilt.a
  lib/macos-universal/  上述 + libyue_noarc_prebuilt.a
  lib/windows-x64/      yue_mbt.lib yue_prebuilt.lib
                       yue_mbt_manifest.res WebView2Loader.dll
用户 moon add 后 prebuild.py 直接引用这些库，零 C++ 编译。
"""

from __future__ import annotations

import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare as _prepare  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
LIB_DIR = REPO_ROOT / "lib"

PLATFORM_DIR = {"Linux": "linux-x64", "Darwin": "macos-universal",
                "Windows": "windows-x64"}
RELEASES = "https://github.com/lb091188/moonbit-libyue/releases/download"

ARTIFACTS = {
    "Linux": ["libyue_mbt.a", "libyue_prebuilt.a"],
    "Darwin": ["libyue_mbt.a", "libyue_prebuilt.a", "libyue_noarc_prebuilt.a"],
    "Windows": ["yue_mbt.lib", "yue_prebuilt.lib", "yue_mbt_manifest.res"],
}
ZIP_NAME = {"linux-x64": "lib-linux-x64.zip",
            "macos-universal": "lib-macos-universal.zip",
            "windows-x64": "lib-windows-x64.zip"}


def vendor_current_platform() -> None:
    os_name = _prepare.system()
    if os_name not in PLATFORM_DIR:
        raise SystemExit(f"暂不支持的平台：{os_name}")
    _prepare.prepare()
    stamp = (_prepare.BUILD_DIR / "prepare_stamp").read_text(encoding="utf-8")
    if stamp.partition(" ")[2].strip() != "prebuilt":
        raise SystemExit(
            "prepare 未走预构建路径（无资产或强制了源码模式），vendored 布局"
            "需要 shim 与 libyue 分离的产物，请确认 fork release 已发布")
    plat = PLATFORM_DIR[os_name]
    target = LIB_DIR / plat
    target.mkdir(parents=True, exist_ok=True)
    for name in ARTIFACTS[os_name]:
        src = _prepare.BUILD_DIR / name
        if not src.exists():
            raise SystemExit(f"产物缺失：{src}")
        shutil.copyfile(src, target / name)
        print(f"vendor：{target / name}")
    if os_name == "Windows":
        dll = REPO_ROOT / "WebView2Loader.dll"  # prepare 已复制到仓库根
        shutil.copyfile(dll, target / "WebView2Loader.dll")
        print(f"vendor：{target / 'WebView2Loader.dll'}")
    (target / "NATIVE_VERSION").write_text(
        f"{_prepare.LIBYUE_VERSION}\n", encoding="utf-8")


def fetch_all(tag: str) -> None:
    """从 vendor-* release 拉三平台资产解到 lib/。"""
    for plat, name in ZIP_NAME.items():
        url = f"{RELEASES}/{tag}/{name}"
        print(f"下载 {url}")
        archive = LIB_DIR / name
        archive.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(url, archive)
        with zipfile.ZipFile(archive) as zf:
            zf.extractall(LIB_DIR / plat)
        archive.unlink()
        print(f"解压至 {LIB_DIR / plat}")


def main() -> None:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    if len(sys.argv) >= 3 and sys.argv[1] == "--fetch":
        fetch_all(sys.argv[2])
        return
    vendor_current_platform()


if __name__ == "__main__":
    main()
