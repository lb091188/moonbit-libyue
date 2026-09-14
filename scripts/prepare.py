#!/usr/bin/env python3
"""准备 libyue 原生构建：固定版本下载 → 校验 → 解压 → CMake 构建静态库。

产物：
  vendor/libyue/          libyue 发行包（头文件 + 平台源码）
  build/libyue_mbt.a      libyue + shim 的静态库（Windows 为 yue_mbt.lib 等）

链接参数不落盘：由 scripts/prebuild.py 在 moon 构建时按当前系统输出
link_configs 传播给依赖方（使用方零配置）。本脚本只负责产出静态库，
可由 scripts/postadd.py（moon add 自动触发）或 prebuild.py（产物缺失
时自动补建）调用，也可手动执行。

用法：python3 scripts/prepare.py
网络走标准环境变量 http_proxy/https_proxy。
缓存包 sha256 不匹配（如上次下载被中断截断）时自动删除重下；
下载先写临时文件，校验通过才原子落盘，坏包不会进缓存。
"""

from __future__ import annotations

import hashlib
import platform
import re
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

# 固定版本：升级时同步更新 sha256
LIBYUE_VERSION = "v0.15.6"
SHA256 = {
    "Linux": "27bc4df5b8c95e41ade7564f43068bce911c701bbba27d605a9a0eaa5738c510",
    "Darwin": "4ddb4a276fc1ea360278136620701ee69decbc2cf9165e8bfe152f2a61879b9e",
    "Windows": "7e65b85b27e14ec097e866956a4ac9283ae4455eb296f89d86d106796385f846",
}
URL = "https://github.com/yue/yue/releases/download/{v}/libyue_{v}_{os}.zip"
# 发行包资产名与 platform.system() 不同名：mac 是 mac、Windows 是 win
ASSET_OS = {"Linux": "linux", "Darwin": "mac", "Windows": "win"}

# Windows 浏览器优先 WebView2：发行包只带 loader DLL 不带头文件，
# 头文件由 NuGet 包补齐（版本与发行包 vendor 的一致），loader 复制到
# 仓库根供 LoadLibrary 按工作目录搜索（moon run 的工作目录即仓库根）
WEBVIEW2_NUGET_URL = ("https://api.nuget.org/v3-flatcontainer/"
                      "microsoft.web.webview2/1.0.2903.40/"
                      "microsoft.web.webview2.1.0.2903.40.nupkg")
WEBVIEW2_NUGET_SHA256 = "ef128016dd1e51c59178c827ed5b8aa3322c57afa8675d930f8109505542ad74"


def system() -> str:
    return platform.system()


def download(url: str, expected_sha256: str) -> Path:
    """取回发行包并校验 sha256；坏缓存自动重下，网络错误重试一次。

    urllib 在 Windows 会读注册表代理（如已失效的系统代理），连接被拒时
    回退直连再试。
    """
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


def fetch_webview2_sdk() -> None:
    """补齐 WebView2 SDK 头文件并把 loader DLL 复制到仓库根。

    libyue 的 WEBVIEW2_SUPPORT 路径编译需要 WebView2.h，发行包 vendor 里只有
    loader DLL；头文件来自固定版本的 NuGet 包。loader DLL 复制到仓库根：
    libyue 运行时按「exe 目录 → 工作目录」搜索 WebView2Loader.dll，
    moon run 的工作目录即仓库根。
    """
    archive = download(WEBVIEW2_NUGET_URL, WEBVIEW2_NUGET_SHA256)
    sdk_dir = VENDOR_DIR / "libyue/include/third_party/Microsoft.Web.WebView2.1.0.2903.40"
    with zipfile.ZipFile(archive) as zf:
        for name in zf.namelist():
            if name.startswith("build/native/") and (
                name.endswith(".h") or name.endswith(".dll") or name.endswith(".lib")
            ):
                dest = sdk_dir / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(zf.read(name))
    loader = sdk_dir / "build/native/x64/WebView2Loader.dll"
    shutil.copyfile(loader, REPO_ROOT / "WebView2Loader.dll")
    print("WebView2 SDK 头文件已补齐，loader DLL 已复制到仓库根")


def patch_win_text_rendering() -> None:
    """vendor 补丁：GDI+ 文本从灰度 AntiAlias 换 ClearType。

    libyue 的 GDI+ 画笔写死 TextRenderingHintAntiAlias（灰度抗锯齿），
    Windows 上自绘的 Tab/按钮/标签小字明显发虚；ClearType 才与系统
    原生控件观感一致。上游无配置项，只能在解压后做等价文本替换
    （幂等；vendor 目录不进版本库，重跑本脚本自动重新应用）。
    """
    pattern = re.compile(r"Gdiplus::TextRenderingHint(?!ClearTypeGridFit)"
                         r"(?:AntiAlias|ClearType)\b")
    for source in (VENDOR_DIR / "libyue/src/win/nativeui").glob("*.cc"):
        text = source.read_text(encoding="utf-8", errors="replace")
        patched = pattern.sub("Gdiplus::TextRenderingHintClearTypeGridFit", text)
        if patched != text:
            source.write_text(patched, encoding="utf-8")
            print(f"已应用文本渲染补丁：{source.name}")


def patch_vendor_headers() -> None:
    """vendor 补丁：修复 vendored 头里两处上游笔误（clang 实例化即报错）。

    libyue 的发行包头文件在 GCC/MSVC 下碰巧未被实例化而"看似能编译"，
    AppleClang（Xcode 16/26 实测）在实例化处直接报错，只能解压后修正
    （幂等；vendor 目录不进版本库，重跑本脚本自动重新应用）：
    - partition_alloc 的 no_destructor.h：PlacementStorage::get() const
      调用了不存在的 storage()，按同类非 const 版本改为读 storage_ 成员；
    - base/containers/id_map.h：operator= 写成 iter.map/iter.iter，
      按同类拷贝构造改为 iter.map_/iter.iter_。
    """
    patches = [
        (VENDOR_DIR / "libyue/include/base/allocator/partition_allocator/src"
         "/partition_alloc/partition_alloc_base/no_destructor.h",
         "return const_cast<PlacementStorage*>(this)->storage();",
         "return reinterpret_cast<const T*>(storage_);"),
        (VENDOR_DIR / "libyue/include/base/containers/id_map.h",
         "      map_ = iter.map;\n      iter_ = iter.iter;",
         "      map_ = iter.map_;\n      iter_ = iter.iter_;"),
    ]
    for path, old, new in patches:
        text = path.read_text(encoding="utf-8")
        if new in text:
            continue  # 已应用（理论不可达：extract 每次还原原文件）
        if old not in text:
            raise SystemExit(f"vendor 补丁目标文本未找到（上游可能已变）：{path}")
        path.write_text(text.replace(old, new), encoding="utf-8")
        print(f"已应用 vendor 头补丁：{path.name}")


def patch_win_task_dialog() -> None:
    """vendor 补丁：TaskDialogIndirect 改为 GetProcAddress 动态解析。

    libyue 的 Windows 消息框静态导入 comctl32 的 TaskDialogIndirect（仅以
    序数 345 导出，v6 才有）。exe 无 Common-Controls v6 清单时加载旧版
    comctl32，解析静态导入阶段即崩（0xc0000138 ENTRYPOINT_NOT_FOUND，
    CI 的 moon 测试驱动实测）——moon 新版给链接的 exe 自带的清单不含
    Common-Controls，故不能依赖链接期清单兜底。改为运行时动态解析：
    有 v6（真机，带我们的 manifest）行为不变；无 v6 按取消降级。
    幂等；vendor 目录不进版本库，重跑本脚本自动重新应用。
    """
    helper = (
        "static const auto task_dialog_indirect =\n"
        "    reinterpret_cast<decltype(&::TaskDialogIndirect)>(\n"
        "        ::GetProcAddress(::GetModuleHandleW(L\"comctl32.dll\"),\n"
        "                         MAKEINTRESOURCEA(345)));"
    )
    patches = [
        # MessageBoxImpl::ThreadMain：后台线程模态弹窗
        ("    BOOL flag = FALSE;\n"
         "    int res = 0;\n"
         "    ::TaskDialogIndirect(&config, &res, nullptr, &flag);",
         "    BOOL flag = FALSE;\n"
         "    int res = 0;\n"
         "    // moonbit-libyue 补丁：动态解析序数 345，无 v6 清单的 exe 加载期不再崩\n"
         f"    {helper.replace(chr(10), chr(10) + '    ')}\n"
         "    if (task_dialog_indirect == nullptr) {  // 无 v6 comctl32：按取消关闭\n"
         "      box->OnClose();\n"
         "      return;\n"
         "    }\n"
         "    task_dialog_indirect(&config, &res, nullptr, &flag);"),
        # MessageBox::PlatformRunForWindow：同步模态弹窗
        ("  int res = cancel_response_;\n"
         "  BOOL flag = FALSE;\n"
         "  ::TaskDialogIndirect(&box_->config, &res, nullptr, &flag);",
         "  int res = cancel_response_;\n"
         "  BOOL flag = FALSE;\n"
         "    // moonbit-libyue 补丁：动态解析序数 345，无 v6 时返回取消响应\n"
         f"    {helper.replace(chr(10), chr(10) + '    ')}\n"
         "    if (task_dialog_indirect != nullptr)\n"
         "      task_dialog_indirect(&box_->config, &res, nullptr, &flag);"),
    ]
    patched = False
    for source in (VENDOR_DIR / "libyue/src/win/nativeui").glob("*.cc"):
        text = source.read_text(encoding="utf-8", errors="replace")
        for old, new in patches:
            if new in text:
                patched = True  # 已应用（理论不可达：extract 每次还原原文件）
                continue
            if old in text:
                text = text.replace(old, new)
                patched = True
                print(f"已应用 TaskDialog 补丁：{source.name}")
        source.write_text(text, encoding="utf-8")
    if not patched:
        raise SystemExit("TaskDialog 补丁未命中任何目标（上游源码可能已变）")


def cmake_build() -> None:
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


def main() -> None:
    # Windows CI/控制台常为 cp1252 等无法编码中文的代码页，print 直接崩
    # （UnicodeEncodeError）；统一转 UTF-8，无法表示的字符替换而非报错。
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    os_name = system()
    if os_name not in SHA256:
        raise SystemExit(f"暂不支持的平台：{os_name}")
    url = URL.format(v=LIBYUE_VERSION, os=ASSET_OS[os_name])
    archive = download(url, SHA256[os_name])
    extract(archive)
    patch_vendor_headers()
    if os_name == "Windows":
        patch_win_text_rendering()
        patch_win_task_dialog()
        fetch_webview2_sdk()
    cmake_build()
    print("prepare 完成")


if __name__ == "__main__":
    main()
