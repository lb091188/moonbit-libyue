#!/usr/bin/env python3
"""准备 libyue 原生构建：固定版本下载 → 校验 → 解压 → CMake 构建静态库。

产物：
  vendor/libyue/          libyue 发行包（头文件 + 平台源码）
  build/libyue_mbt.a      libyue + shim 的静态库
  yue/moon.pkg.json       自动回写 cc-link-flags（托管字段，勿手改）

用法：python3 scripts/prepare.py
网络走标准环境变量 http_proxy/https_proxy。
缓存包 sha256 不匹配（如上次下载被中断截断）时自动删除重下；
下载先写临时文件，校验通过才原子落盘，坏包不会进缓存。
回写的库路径是仓库根相对的 -L build（链接器按 moon 的调用目录解析
相对路径），因此 moon 命令必须在仓库根目录执行。
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
# 发行包资产名与 platform.system() 不同名：mac 是 mac、Windows 是 win
ASSET_OS = {"Linux": "linux", "Darwin": "mac", "Windows": "win"}

# Linux 最终链接需要的系统库，与 shim/CMakeLists.txt 的依赖一致
LINUX_PKG_CONFIG_LIBS = [
    "gtk+-3.0",
    "pangoft2",
    "fontconfig",
    "x11",
]
# webkit2gtk 在不同发行版包名不同，4.0/4.1 任一存在即可
LINUX_PKG_CONFIG_LIBS_ANY = ["webkit2gtk-4.0", "webkit2gtk-4.1"]

# Windows 最终链接需要的系统库。在官方 CMakeLists 清单基础上补齐
# user32/ole32/oleaut32/shell32 等 GUI 基础库（官方清单缺项，实测链接
# 大量 user32/COM 符号未解析）；多余的库链接器会忽略，无害。
WINDOWS_LINK_LIBS = [
    "user32.lib", "gdi32.lib", "shell32.lib", "ole32.lib", "oleaut32.lib",
    "advapi32.lib", "comdlg32.lib", "imm32.lib", "msimg32.lib", "oleacc.lib",
    "usp10.lib", "setupapi.lib", "powrprof.lib", "ws2_32.lib", "dbghelp.lib",
    "shlwapi.lib", "version.lib", "winmm.lib", "wbemuuid.lib", "psapi.lib",
    "dwmapi.lib", "propsys.lib", "comctl32.lib", "gdiplus.lib", "urlmon.lib",
    "userenv.lib", "uxtheme.lib", "delayimp.lib", "runtimeobject.lib",
    "ntdll.lib", "shcore.lib", "pdh.lib",
]


def system() -> str:
    return platform.system()


def download(url: str, expected_sha256: str) -> Path:
    """取回发行包并校验 sha256；坏缓存自动重下，网络错误重试一次。"""
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
        raise SystemExit(f"下载失败（检查网络或 http_proxy/https_proxy）：{last_err}")
    actual = sha256(partial)
    if actual != expected_sha256:
        raise SystemExit(f"下载后 sha256 仍不匹配：期望 {expected_sha256}，实际 {actual}")
    partial.replace(archive)  # 校验通过才落盘，缓存里永远只放完整包
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
    if system() == "Windows":
        # VS 多配置生成器忽略 CMAKE_BUILD_TYPE，必须显式 --config；
        # 且默认按 Debug（/MDd）构建会与 moon 的 /MT 链接冲突
        build += ["--config", "Release"]
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


def link_flags() -> str:
    """各平台链接参数：Linux/macOS 为 GNU ld 风格，Windows 为 cl 命令行风格。

    moon 在 Windows 把 cc-link-flags 原样拼进 cl 命令行（实测 -L/-l 报
    D9002/D9024，/LIBPATH: 报 D9002 且不转发给 link）。因此静态库直接以
    相对路径作为链接输入（cl 会把 .lib 传给 link），系统库不写参数、
    由 vcvars64 注入的 LIB 环境变量解析；相对路径按 moon 的调用目录
    （仓库根）解析。注意分隔符必须用正斜杠：moon 的参数解析会把
    反斜杠当转义吃掉（实测 `build\yue_mbt.lib` 变成 `buildyue_mbt.lib`）。
    """
    if system() == "Linux":
        extra = pkg_config_libs() + ["-lpthread", "-ldl", "-lm", "-lstdc++"]
        return "-L build -lyue_mbt " + " ".join(extra)
    if system() == "Darwin":
        return "-L build -lyue_mbt -lpthread"
    if system() == "Windows":
        # yue_mbt_manifest.res 是嵌入 exe 的应用清单（comctl32 v6 依赖），
        # 由 shim/CMakeLists 的 rc 编译产出；cl 会把 .res 输入转发给 link
        return ("build/yue_mbt_manifest.res build/yue_mbt.lib "
                + " ".join(WINDOWS_LINK_LIBS))
    raise SystemExit(f"暂不支持的平台：{system()}")


def patch_moon_pkg() -> None:
    """把链接参数写回仓库内所有 moon.pkg.json 的 cc-link-flags。

    moon 的 link 段只作用于所在包，且只对 main 包的最终二进制生效，
    因此只给 is-main 的包回写（库包 yue/ 放 link 段会让 moon 生成
    无 main 的 yue.exe 导致构建失败）。

    库路径写仓库根相对（`-L build` / `/LIBPATH:build`）：链接器按 moon
    的调用目录解析相对路径，所以 moon 命令必须在仓库根执行。好处是
    回写结果与机器无关，换机重跑不再产生绝对路径噪音 diff。同一仓库
    在不同平台切换时重跑本脚本即可换到对应平台的链接参数。
    """
    flags = link_flags()
    for pkg_path in sorted(REPO_ROOT.rglob("moon.pkg.json")):
        if any(part in {"vendor", "build", ".prepare", "_build", "target"} for part in pkg_path.parts):
            continue
        old_text = pkg_path.read_text()
        pkg = json.loads(old_text)
        if not pkg.get("is-main"):
            pkg.pop("link", None)
        else:
            pkg.setdefault("link", {}).setdefault("native", {})["cc-link-flags"] = flags
        new_text = json.dumps(pkg, indent=2, ensure_ascii=False) + "\n"
        if new_text == old_text:
            continue  # 内容未变不回写，避免改动 mtime 触发 moon 无谓重链
        pkg_path.write_text(new_text)
        print(f"已写入链接参数：{pkg_path.relative_to(REPO_ROOT)}")


def main() -> None:
    os_name = system()
    if os_name not in SHA256:
        raise SystemExit(f"暂不支持的平台：{os_name}")
    url = URL.format(v=LIBYUE_VERSION, os=ASSET_OS[os_name])
    archive = download(url, SHA256[os_name])
    extract(archive)
    cmake_build()
    patch_moon_pkg()
    print("prepare 完成")


if __name__ == "__main__":
    main()
