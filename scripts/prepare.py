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
LIBYUE_VERSION = "v0.15.6-mbt.14"
RELEASES = f"https://github.com/lb091188/yue/releases/download/{LIBYUE_VERSION}"
# 发行包资产名与 platform.system() 不同名：mac 是 mac、Windows 是 win
ASSET_OS = {"Linux": "linux", "Darwin": "mac", "Windows": "win"}

SHA256 = {
    # 源码发行包（回退路径）
    "source:linux": "d888c6087c0ff9a7c75973b03659b34087161b94a705f77bb28068232b320c6a",
    "source:mac": "40facc51ae0df0e91d79cf5de456df8e62de03db9c887dcf9d7c6e83c47a9211",
    "source:win": "42dd0de3225f4a1a51ff4afc76d17479e501ed487631831acebfec9ad6bf847d",
    # 预构建静态库（优先路径）
    "prebuilt:linux_x64": "b57c0bc7b6e8a82f1bb37bccc9dd44c3dc92021fd1ca713bbf57e61822aabb0f",
    "prebuilt:mac_universal": "1b9ba6b3c85b607e26ca60dcb9aa7201dd1c523bf6dc85648a9f9379e6e8fe11",
    "prebuilt:win_x64": "d978472fdd64d1258b2202d11cf68404e7273bb91ddd52a435cf1610dcb1184c",
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


def split_browser_out_of_jumbo() -> bool:
    """把浏览器实现从 nativeui jumbo 单元抽成独立编译单元（仅 Linux）。

    发行包的 jumbo 把 browser.cc / browser_gtk.cc 与 PainterGtk/Font/
    Image 等混编在同一成员，非浏览器程序只要链接该成员就得解析
    webkit_* 符号。静态 weak stub 兜底在 moon 工具链下不成立：moon
    默认 --as-needed 且按依赖拓扑序拼接各包 flags，浏览器程序的
    stub 会先于真库绑定引用（ELF 静态绑定不可逆），实测浏览器页段
    错误。抽段后 libyue_mbt.a 中浏览器独立成成员，静态库按需拉取
    天然隔离，非浏览器程序链接期接触不到任何 webkit 符号。段按
    「// ../../nativeui/...」注释头定位，找不到（未来 fork 拆分后）
    即跳过，幂等。"""
    base = VENDOR_DIR / "libyue/src/linux/nativeui"
    targets = [
        (base / "nativeui_jumbo_1.cc", "// ../../nativeui/browser.cc"),
        (base / "nativeui_jumbo_2.cc",
         "// ../../nativeui/gtk/browser_gtk.cc"),
    ]
    segments: list[list[str]] = []
    for path, marker in targets:
        try:
            lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
        except OSError:
            return
        start = next((i for i, l in enumerate(lines) if l.rstrip("\n") == marker), None)
        if start is None:
            print("[prepare] jumbo 中未找到浏览器段（可能已拆分），跳过抽段",
                  file=sys.stderr)
            return
        end = next((i for i, l in enumerate(lines[start + 1:], start + 1)
                    if l.startswith("// ../../")), len(lines))
        segments.append(lines[start:end])
        del lines[start:end]
        path.write_text("".join(lines), encoding="utf-8")
    (base / "nativeui_browser.cc").write_text(
        "".join(segments[0]).rstrip("\n") + "\n\n" + "".join(segments[1]),
        encoding="utf-8")
    print("[prepare] 已把浏览器实现抽出为独立编译单元 nativeui_browser.cc",
          file=sys.stderr)
    return True


def decouple_menu_item_from_webkit() -> None:
    """menu_item_gtk 的角色项(剪切/粘贴等)对聚焦 WebView 执行编辑命令,
    与 webkit 有 2 个符号耦合(WEBKIT_IS_WEB_VIEW 宏展开引用
    webkit_web_view_get_type + webkit_web_view_execute_editing_command),
    jumbo 抽段后仍留在菜单成员里,非浏览器程序链接期就会碰到。改为
    运行时探测:类型查 GType 注册表(WebKitWebView 仅在其库加载后注册,
    非浏览器程序查不到即跳过),命令走 dlsym;浏览器程序两查全部命中,
    行为不变。文本替换幂等:目标文本不存在(已打补丁/fork 已改)即跳过。
    """
    path = VENDOR_DIR / "libyue/src/linux/nativeui/nativeui_jumbo_3.cc"
    try:
        s = path.read_text(encoding="utf-8")
    except OSError:
        return
    anchor = "// Handling role item clicking.\nvoid OnRoleClick(GtkWidget*, MenuItem* item) {"
    helpers = (
        "// 浏览器可选化补丁:非浏览器程序不链 webkit,WebView 类型探测改走\n"
        "// GType 注册表(WebKitWebView 类型仅在其库加载后注册),编辑命令运行时\n"
        "// dlsym 探测,双场景行为不变。\n"
        "#include <dlfcn.h>\n\n"
        "static bool yue_is_web_view(GtkWidget* widget) {\n"
        "  static GType type = g_type_from_name(\"WebKitWebView\");\n"
        "  return type != 0 && G_TYPE_CHECK_INSTANCE_TYPE(widget, type);\n"
        "}\n\n"
        "static void yue_web_view_execute_editing_command(WebKitWebView* view,\n"
        "                                                 const gchar* command) {\n"
        "  using Fn = void (*)(WebKitWebView*, const gchar*);\n"
        "  static Fn fn = reinterpret_cast<Fn>(\n"
        "      dlsym(RTLD_DEFAULT, \"webkit_web_view_execute_editing_command\"));\n"
        "  if (fn)\n"
        "    fn(view, command);\n"
        "}\n\n"
    )
    changed = False
    if anchor in s and "yue_is_web_view" not in s:
        s = s.replace(anchor, helpers + anchor, 1)
        changed = True
    old_call = (
        "  if (WEBKIT_IS_WEB_VIEW(widget)) {\n"
        "    webkit_web_view_execute_editing_command(\n"
        "        WEBKIT_WEB_VIEW(widget),\n"
        "        g_edit_map[static_cast<int>(item->GetRole())].webkit_command);\n"
        "  } else {"
    )
    new_call = (
        "  if (yue_is_web_view(widget)) {\n"
        "    yue_web_view_execute_editing_command(\n"
        "        reinterpret_cast<WebKitWebView*>(widget),\n"
        "        g_edit_map[static_cast<int>(item->GetRole())].webkit_command);\n"
        "  } else {"
    )
    if old_call in s:
        s = s.replace(old_call, new_call, 1)
        changed = True
    if changed:
        path.write_text(s, encoding="utf-8")
        print("[prepare] menu_item_gtk 的 webkit 耦合已改为运行时探测",
              file=sys.stderr)


def backport_fork_main() -> None:
    """把 fork main 领先当前发行版的补丁追打到解压后的源码上(幂等)。

    发行包钉版本滞后于 fork main 时,已合入 main 的小修正在这里以文本
    替换追打,避免为等一个补丁走一轮 tag/CI 出包;fork 发新版本后对应
    条目自然失配跳过。每条补丁:目标文本(来自 fork 提交的旧侧)必须
    精确命中一次,新文本(新侧)已存在则跳过。

    现有补丁(对照 fork main):
      ba479418  Container::UpdateChildBounds 递归下钻子容器——子容器尺寸
                未变时 SetBounds 早退,SizeAllocate→Layout 级联断,其子树
                整轮错过分配(set_visible 切页整块不再重绘,Windows 实测)
    """
    # 目标是 Windows 源码包的 nativeui jumbo(发行 zip 全为 jumbo 形态,
    # CRLF 行尾),替换做 LF/CRLF 双形态兼容,保持文件原行尾。
    patches = [
        (
            VENDOR_DIR / "libyue/src/win/nativeui/nativeui_jumbo_1.cc",
            """  for (int i = 0; i < ChildCount(); ++i) {
    View* child = ChildAt(i);
    if (child->IsVisibleInHierarchy())
      child->SetBounds(GetYGNodeBounds(child->node()));
  }""",
            """  for (int i = 0; i < ChildCount(); ++i) {
    View* child = ChildAt(i);
    if (child->IsVisibleInHierarchy()) {
      child->SetBounds(GetYGNodeBounds(child->node()));
      // Recurse unconditionally: a child container whose size did not
      // change early-returns from SetBounds and never cascades
      // SizeAllocate -> Layout, so its own subtree would miss this
      // allocation round entirely (measured: pages toggled via set_visible
      // stopped repainting as a whole block on Windows). The child bounds
      // read here always come from the latest root-level layout, so the
      // recursion only re-distributes fresh values and never invents
      // constraints of its own. Do NOT recalculate per-container here:
      // forcing YGNodeCalculateLayout with the container's own (possibly
      // still-zero) bounds as the owner size pushes zeros into the whole
      // subtree during early layout rounds (measured: freshly shown pages
      // rendered completely blank on Windows).
      if (child->IsContainer())
        static_cast<Container*>(child)->UpdateChildBounds();
    }
  }""",
        ),
    ]
    for path, old_lf, new_lf in patches:
        try:
            # newline="" 保留原行尾(zip 内 CRLF,写回不转 LF)
            with open(path, "r", encoding="utf-8", newline="") as f:
                content = f.read()
        except OSError:
            continue  # 平台不含该文件(非 win 源码包)
        old_text = old_lf.replace("\n", "\r\n") if "\r\n" in content else old_lf
        new_text = new_lf.replace("\n", "\r\n") if "\r\n" in content else new_lf
        if new_text in content:
            continue  # 已打过 / 新版本已含
        if old_text not in content:
            print(f"[prepare] 追补丁目标文本未命中(可能已更新),跳过: {path.name}",
                  file=sys.stderr)
            continue
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(content.replace(old_text, new_text, 1))
        print(f"[prepare] 已追打 fork main 补丁: {path.name}", file=sys.stderr)


def cmake_build(prebuilt: bool, browser_split: bool = False) -> None:
    configure = ["cmake", "-S", str(REPO_ROOT / "shim"), "-B", str(BUILD_DIR),
                 "-DCMAKE_BUILD_TYPE=Release"]
    # 两种模式都必须显式传:cmake -D 只在传了时覆盖,不传则沿用 CMakeCache
    # 残留值——prebuilt→source 切换时 ON 残留会让源码模式只编 shim,库内仅
    # 一个 yue_mbt.obj,链接期全库符号缺失。
    configure.append(f"-DYUE_MBT_PREBUILT={'ON' if prebuilt else 'OFF'}")
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
    # -split 后缀:浏览器已从 jumbo 抽成独立编译单元(仅 Linux 源码
    # 模式)——prebuild 据此判断主包条目是否可免 webkit flags
    mode = "prebuilt" if prebuilt else \
        ("source-split" if browser_split else "source")
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
    browser_split = False
    if asset is None:
        prepare_source(os_name)
        backport_fork_main()
        if os_name == "Linux":
            browser_split = split_browser_out_of_jumbo()
            if browser_split:
                decouple_menu_item_from_webkit()
    copy_webview2_loader()
    cmake_build(prebuilt=asset is not None, browser_split=browser_split)
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
