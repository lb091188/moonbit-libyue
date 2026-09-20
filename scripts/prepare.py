#!/usr/bin/env python3
"""准备 libyue 原生层：优先下载 fork（lb091188/yue）的预构建静态库，
无对应资产或设 LIBYUE_FORCE_SOURCE=1 时，回退源码发行包 + 本地 CMake 构建。

产物：
  vendor/libyue/          发行包内容（头文件 + 源码，或预构建 lib）
  build/libyue_mbt.a      shim 静态库；源码模式含全部 libyue，预构建模式
                          仅含 shim，链接期与 build/libyue_prebuilt.a 一起
                          传入（Windows 为 yue_mbt.lib / yue_prebuilt.lib）
  build/libyue_prebuilt.a 预构建模式下解出的 libyue 静态库

调用方：scripts/postadd.py（moon add 自动触发）、scripts/prebuild.py
（产物缺失时自动补建），也可手动执行：python3 scripts/prepare.py。
链接参数由 scripts/prebuild.py 托管，网络走 http_proxy/https_proxy。
"""

from __future__ import annotations

import hashlib
import os
import platform
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
VENDOR_DIR = REPO_ROOT / "vendor"
BUILD_DIR = REPO_ROOT / "build"
CACHE_DIR = REPO_ROOT / ".prepare"

# 固定版本：fork 的 v*-mbt* 标签，升级时同步更新 sha256。
# 平台修复补丁已提交进 fork，发行包自带，无需本地打补丁。
LIBYUE_VERSION = "v0.15.6-mbt.10"
RELEASES = f"https://github.com/lb091188/yue/releases/download/{LIBYUE_VERSION}"
# 发行包资产名与 platform.system() 不同名：mac 是 mac、Windows 是 win
ASSET_OS = {"Linux": "linux", "Darwin": "mac", "Windows": "win"}

SHA256 = {
    # 源码发行包（回退路径）
    "source:linux": "841ce7caa93d2111ac1ededdebb7ad76e637079ef8f000c783488f95be87fd8f",
    "source:mac": "4c22d992a1600b28549b996bad58fe4a4bca9d3d8c77117e49502094f62e2f60",
    "source:win": "5b062f8dc65587b597d046586308dc48339f550f80c295dc519c1b18d9b59eb2",
    # 预构建静态库（优先路径）
    "prebuilt:linux_x64": "99dd7198062066e04da18e6731e5b10bb0cab913b3b44815593b9054201f04de",
    "prebuilt:mac_universal": "8cc95f1e06d137b35b2af30339d5b93248536651135d7d1c1d7ac4fe2e191210",
    "prebuilt:win_x64": "e6e1548463fdf3b00ed260d8b58a24a2fb36428f6c1dae39dadf60b92b6e4137",
}


def system() -> str:
    return platform.system()


def download(url: str, expected_sha256: str) -> Path:
    """取回发行包并校验 sha256：坏缓存删除重下，重试一次后回退直连。"""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    archive = CACHE_DIR / url.rsplit("/", 1)[-1]
    if archive.exists():
        if sha256(archive) == expected_sha256:
            print(f"复用缓存 {archive}")
            return archive
        print(f"缓存 sha256 不匹配，多半是上次下载被中断，删除后重新下载")
        archive.unlink()
    partial = archive.with_suffix(archive.suffix + ".part")
    last_err: Exception | None = None
    for attempt in (1, 2):
        try:
            print(f"下载 {url}" + ("（重试）" if attempt > 1 else ""))
            urllib.request.urlretrieve(url, partial)
            break
        except OSError as e:
            last_err = e
    else:
        try:
            print(f"代理/默认下载失败（{last_err}），回退直连重试")
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            with opener.open(url) as resp, open(partial, "wb") as out:
                out.write(resp.read())
        except OSError as e:
            raise SystemExit(f"下载失败（检查网络或 http_proxy/https_proxy）：{e}")
    if expected_sha256:
        digest = sha256(partial)
        if digest != expected_sha256:
            raise SystemExit(f"下载后 sha256 不匹配：期望 {expected_sha256}，实际 {digest}")
    else:
        print("警告：该资产尚未钉 sha256，跳过校验", file=sys.stderr)
    partial.replace(archive)  # 校验通过才落盘，缓存里永远只放完整包
    return archive


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def extract(archive: Path, target: Path) -> Path:
    if target.exists():
        shutil.rmtree(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as zf:
        zf.extractall(target)
    print(f"解压至 {target}")
    return target


def copy_webview2_loader() -> None:
    """Windows：loader DLL 复制到仓库根（fork 发行包自带，位于 lib/），
    供 LoadLibrary 按工作目录搜索（moon run 的工作目录即仓库根）。"""
    loader = VENDOR_DIR / "libyue/lib/WebView2Loader.dll"
    if loader.exists():
        target = REPO_ROOT / "WebView2Loader.dll"
        # hostshare 等共享卷的 st_ino/st_dev 不可靠,os.path.samefile 会把
        # 两个独立文件误判为同一文件(SameFileError);先删目标再复制绕开该判定。
        if target.exists():
            target.unlink()
        shutil.copyfile(loader, target)
        print("WebView2Loader.dll 已复制到仓库根")


def prebuilt_asset(os_name: str) -> str | None:
    """当前平台可用的预构建资产后缀；无则走源码回退。"""
    machine = platform.machine().lower()
    if os_name == "Linux":
        return "linux_x64" if machine in ("x86_64", "amd64") else None
    if os_name == "Darwin":
        return "mac_universal"  # lipo 合一的通用二进制
    if os_name == "Windows":
        return "win_x64" if machine in ("x86_64", "amd64") else None
    return None


def prepare_prebuilt(asset: str) -> None:
    """预构建路径：头文件进 vendor，静态库解到 build/。"""
    url = f"{RELEASES}/libyue_prebuilt_{LIBYUE_VERSION}_{asset}.zip"
    archive = download(url, SHA256[f"prebuilt:{asset}"])
    extract(archive, VENDOR_DIR / "libyue")
    src = VENDOR_DIR / "libyue/lib"
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    moves = {
        "libyue.a": "libyue_prebuilt.a",
        "libyue_noarc.a": "libyue_noarc_prebuilt.a",  # macOS ARC 拆分库
        "yue.lib": "yue_prebuilt.lib",
    }
    for name, dest in moves.items():
        if (src / name).exists():
            shutil.copyfile(src / name, BUILD_DIR / dest)
            print(f"预构建库就位：build/{dest}")


def prepare_source(os_name: str) -> None:
    """源码回退路径：解压源码发行包（fork 已带全部平台补丁）。"""
    url = f"{RELEASES}/libyue_{LIBYUE_VERSION}_{ASSET_OS[os_name]}.zip"
    archive = download(url, SHA256[f"source:{ASSET_OS[os_name]}"])
    extract(archive, VENDOR_DIR / "libyue")
    # 清掉预构建模式残留的独立库，避免链接期与全量 libyue_mbt 重复符号
    for stale in ("libyue_prebuilt.a", "libyue_noarc_prebuilt.a", "yue_prebuilt.lib"):
        (BUILD_DIR / stale).unlink(missing_ok=True)


def cmake_build(prebuilt: bool) -> None:
    configure = ["cmake", "-S", str(REPO_ROOT / "shim"), "-B", str(BUILD_DIR),
                 "-DCMAKE_BUILD_TYPE=Release"]
    if prebuilt:
        configure.append("-DYUE_MBT_PREBUILT=ON")
    build = ["cmake", "--build", str(BUILD_DIR), "--parallel"]
    if system() == "Windows":
        # VS 多配置生成器忽略 CMAKE_BUILD_TYPE，必须显式 --config；
        # 且默认按 Debug（/MDd）构建会与 moon 的 /MT 链接冲突
        build += ["--config", "Release"]
    print(" ".join(configure))
    subprocess.run(configure, check=True)
    print(" ".join(build))
    subprocess.run(build, check=True)
    stamp = BUILD_DIR / "prepare_stamp"
    mode = "prebuilt" if prebuilt else "source"
    stamp.write_text(f"{LIBYUE_VERSION} {mode}\n", encoding="utf-8")


def prepare(force_source: bool = False) -> None:
    os_name = system()
    if os_name not in ASSET_OS:
        raise SystemExit(f"暂不支持的平台：{os_name}")
    asset = None if force_source else prebuilt_asset(os_name)
    if asset is not None:
        try:
            prepare_prebuilt(asset)
        except SystemExit as e:
            print(f"[moonbit-libyue] 预构建资产不可用（{e}），回退源码构建",
                  file=sys.stderr)
            asset = None
    if asset is None:
        prepare_source(os_name)
    copy_webview2_loader()
    cmake_build(prebuilt=asset is not None)
    print("prepare 完成")


def main() -> None:
    # Windows CI/控制台常为 cp1252 等无法编码中文的代码页，print 直接崩
    # （UnicodeEncodeError）；统一转 UTF-8，无法表示的字符替换而非报错。
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    prepare(force_source=os.environ.get("LIBYUE_FORCE_SOURCE") == "1"
            or "--force-source" in sys.argv[1:])


if __name__ == "__main__":
    main()
