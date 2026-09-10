#!/usr/bin/env python3
"""准备 libyue 原生构建：固定版本下载 → 校验 → 解压 → CMake 构建静态库。

产物：
  vendor/libyue/          libyue 发行包（头文件 + 平台源码）
  build/libyue_mbt.a      libyue + shim 的静态库
  yue/moon.pkg.json       自动回写 cc-link-flags（托管字段，勿手改）

用法：python3 scripts/prepare.py
网络走标准环境变量 http_proxy/https_proxy。
"""

from __future__ import annotations

import hashlib
import json
import platform
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
VENDOR_DIR = REPO_ROOT / "vendor"
BUILD_DIR = REPO_ROOT / "build"
CACHE_DIR = REPO_ROOT / ".prepare"
MOON_PKG = REPO_ROOT / "yue" / "moon.pkg.json"

# 固定版本：升级时同步更新三个 sha256
LIBYUE_VERSION = "v0.15.6"
SHA256 = {
    "Linux": "27bc4df5b8c95e41ade7564f43068bce911c701bbba27d605a9a0eaa5738c510",
    "Darwin": "4ddb4a276fc1ea360278136620701ee69decbc2cf9165e8bfe152f2a61879b9e",
    "Windows": "7e65b85b27e14ec097e866956a4ac9283ae4455eb296f89d86d106796385f846",
}
URL = "https://github.com/yue/yue/releases/download/{v}/libyue_{v}_{os}.zip"

# Linux 最终链接需要的系统库，与 shim/CMakeLists.txt 的依赖一致
LINUX_PKG_CONFIG_LIBS = [
    "gtk+-3.0",
    "pangoft2",
    "fontconfig",
    "x11",
]
# webkit2gtk 在不同发行版包名不同，4.0/4.1 任一存在即可
LINUX_PKG_CONFIG_LIBS_ANY = ["webkit2gtk-4.0", "webkit2gtk-4.1"]


def system() -> str:
    return platform.system()


def download(url: str, expected_sha256: str) -> Path:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    archive = CACHE_DIR / url.rsplit("/", 1)[-1]
    if archive.exists():
        print(f"已存在缓存 {archive}")
    else:
        print(f"下载 {url}")
        urllib.request.urlretrieve(url, archive)
    actual = sha256(archive)
    if actual != expected_sha256:
        raise SystemExit(f"sha256 不匹配：期望 {expected_sha256}，实际 {actual}")
    return archive


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def extract(archive: Path) -> Path:
    target = VENDOR_DIR / "libyue"
    if target.exists():
        shutil.rmtree(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as zf:
        zf.extractall(target)
    print(f"解压至 {target}")
    return target


def cmake_build() -> Path:
    configure = ["cmake", "-S", str(REPO_ROOT / "shim"), "-B", str(BUILD_DIR),
                 "-DCMAKE_BUILD_TYPE=Release"]
    build = ["cmake", "--build", str(BUILD_DIR), "--parallel"]
    print(" ".join(configure))
    subprocess.run(configure, check=True)
    print(" ".join(build))
    subprocess.run(build, check=True)
    return BUILD_DIR


def pkg_config_libs() -> list[str]:
    """Linux 链接期系统库（-l 形式）。webkit 包名做 4.0/4.1 兼容。"""
    flags: list[str] = []
    for pkg in LINUX_PKG_CONFIG_LIBS:
        out = subprocess.run(["pkg-config", "--libs", pkg],
                             capture_output=True, text=True)
        if out.returncode != 0:
            raise SystemExit(f"缺少系统依赖：请安装 {pkg} 的开发包（pkg-config 找不到）")
        flags += out.stdout.split()
    for pkg in LINUX_PKG_CONFIG_LIBS_ANY:
        out = subprocess.run(["pkg-config", "--libs", pkg],
                             capture_output=True, text=True)
        if out.returncode == 0:
            flags += out.stdout.split()
            break
    else:
        raise SystemExit("缺少系统依赖：webkit2gtk-4.0 或 4.1 的开发包至少装一个")
    if "-lwebkit2gtk-4.1" in flags and "-ljavascriptcoregtk-4.1" not in flags:
        flags.append("-ljavascriptcoregtk-4.1")
    return flags


def patch_moon_pkg(lib_path: Path) -> None:
    """把绝对库路径与系统库写回仓库内所有 moon.pkg.json 的 cc-link-flags。

    moon 的 link 段只作用于所在包，且只对 main 包的最终二进制生效，
    因此只给 is-main 的包回写（库包 yue/ 放 link 段会让 moon 生成
    无 main 的 yue.exe 导致构建失败）。
    """
    if system() == "Linux":
        extra = pkg_config_libs() + ["-lpthread", "-ldl", "-lm", "-lstdc++"]
    elif system() == "Darwin":
        extra = ["-lpthread"]
    else:
        print("Windows 平台链接参数暂未自动化，请手工核对各 moon.pkg.json")
        return
    flags = f"-L {lib_path.parent} -lyue_mbt " + " ".join(extra)
    for pkg_path in sorted(REPO_ROOT.rglob("moon.pkg.json")):
        if any(part in {"vendor", "build", ".prepare", "_build", "target"} for part in pkg_path.parts):
            continue
        pkg = json.loads(pkg_path.read_text())
        if not pkg.get("is-main"):
            pkg.pop("link", None)
            pkg_path.write_text(json.dumps(pkg, indent=2, ensure_ascii=False) + "\n")
            continue
        pkg.setdefault("link", {}).setdefault("native", {})["cc-link-flags"] = flags
        pkg_path.write_text(json.dumps(pkg, indent=2, ensure_ascii=False) + "\n")
        print(f"已写入链接参数：{pkg_path.relative_to(REPO_ROOT)}")


def main() -> None:
    os_name = system()
    if os_name not in SHA256:
        raise SystemExit(f"暂不支持的平台：{os_name}")
    url = URL.format(v=LIBYUE_VERSION, os=os_name.lower())
    archive = download(url, SHA256[os_name])
    extract(archive)
    lib_dir = cmake_build()
    patch_moon_pkg(next(lib_dir.glob("libyue_mbt*.a"), lib_dir / "libyue_mbt.a"))
    print("prepare 完成")


if __name__ == "__main__":
    main()
