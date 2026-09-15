#!/usr/bin/env python3
"""准备 libyue 原生构建：固定版本下载 → 校验 → 解压 → CMake 构建静态库。

产物：
  vendor/libyue/          libyue 发行包（头文件 + 平台源码）
  build/libyue_mbt.a      libyue + shim 的静态库（Windows 为 yue_mbt.lib 等）

调用方：scripts/postadd.py（moon add 自动触发）、scripts/prebuild.py
（产物缺失时自动补建），也可手动执行：python3 scripts/prepare.py。
链接参数由 scripts/prebuild.py 托管，网络走 http_proxy/https_proxy。
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
    """补齐 WebView2 SDK 头文件（发行包缺），loader DLL 复制到仓库根。"""
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
    """vendor 补丁：GDI+ 文本渲染 AntiAlias → ClearTypeGridFit（幂等）。
    原理见 docs/adaptation.md「运行期差异」。
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
    """vendor 补丁：修正 vendored 头两处上游笔误（幂等）：
    - no_destructor.h：PlacementStorage::get() const 改读 storage_；
    - id_map.h：operator= 改用 iter.map_/iter.iter_。
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
    """vendor 补丁：TaskDialogIndirect 改 GetProcAddress 动态解析，
    无 v6 comctl32 时按取消降级（幂等）。原理见 docs/adaptation.md「manifest」。
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


def patch_linux_container_events() -> None:
    """vendor 补丁（Linux/GTK）：事件窗口不抬高、yoga 布局时机、Scroll
    size_request、GifPlayer map 信号/自建窗口、Slider SetValue 标记（幂等）。
    逐条原理见 docs/adaptation.md「GTK 相关」。
    """
    container_src = VENDOR_DIR / "libyue/src/linux/nativeui/nativeui_jumbo_2.cc"
    scroll_src = VENDOR_DIR / "libyue/src/linux/nativeui/nativeui_jumbo_3.cc"
    root_src = VENDOR_DIR / "libyue/src/linux/nativeui/nativeui_jumbo_1.cc"
    patches = [
        (scroll_src,
         "  g_signal_connect(GetNative(), \"show\", G_CALLBACK(OnShow), this);\n"
         "  g_signal_connect(GetNative(), \"hide\", G_CALLBACK(OnHide), this);\n",
         "  g_signal_connect(GetNative(), \"show\", G_CALLBACK(OnShow), this);\n"
         "  g_signal_connect(GetNative(), \"hide\", G_CALLBACK(OnHide), this);\n"
         "  // moonbit-libyue 补丁:补连 map 信号\n"
         "  g_signal_connect(GetNative(), \"map\", G_CALLBACK(OnShow), this);\n"),
        (scroll_src,
         "GifPlayer::GifPlayer() {\n"
         "  TakeOverView(gtk_drawing_area_new());\n",
         "GifPlayer::GifPlayer() {\n"
         "  // moonbit-libyue 补丁:drawing area 自建 GdkWindow\n"
         "  GtkWidget* area = gtk_drawing_area_new();\n"
         "  gtk_widget_set_has_window(area, TRUE);\n"
         "  TakeOverView(area);\n"),
        (root_src,
         "void Container::UpdateChildBounds() {\n"
         "  dirty_ = false;\n"
         "  if (!IsVisibleInHierarchy())\n"
         "    return;\n"
         "  // For root CSS node, calculate the layout before setting bounds.\n"
         "  if (IsRootYGNode(this)) {\n"
         "    SizeF size = GetBounds().size();\n"
         "    YGNodeCalculateLayout(node(), size.width(), size.height(), YGDirectionLTR);\n"
         "  }\n",
         "void Container::UpdateChildBounds() {\n"
         "  dirty_ = false;\n"
         "  // moonbit-libyue 补丁:布局总是执行,孩子传播仍受可见性限制\n"
         "  if (IsRootYGNode(this)) {\n"
         "    SizeF size = GetBounds().size();\n"
         "    YGNodeCalculateLayout(node(), size.width(), size.height(), YGDirectionLTR);\n"
         "  }\n"),
        (container_src,
         "  if (priv->event_window)\n    gdk_window_show(priv->event_window);\n\n"
         "  GTK_WIDGET_CLASS(nu_container_parent_class)->map(widget);",
         "  if (priv->event_window)\n"
         "    gdk_window_show_unraised(priv->event_window);  // moonbit-libyue 补丁:映射不抬高\n\n"
         "  GTK_WIDGET_CLASS(nu_container_parent_class)->map(widget);"),
        (container_src,
         "  attributes.y = allocation.x;",
         "  attributes.y = allocation.y;  // moonbit-libyue 补丁:上游笔误 y 误用 x"),
        # nu_container_get_preferred_width/height 保持上游 0/0 不动
        # (原因见 docs/adaptation.md「GTK 相关」)。
        (scroll_src,
         "void Scroll::PlatformSetContentView(View* view) {\n"
         "  // Receive the content size from current content view.\n"
         "  Size csize = view->GetPixelBounds().size();\n"
         "  if (content_view_) {\n"
         "    int w, h;\n"
         "    gtk_widget_get_size_request(content_view_->GetNative(), &w, &h);\n"
         "    csize = Size(w, h);\n"
         "  }\n",
         "void Scroll::PlatformSetContentView(View* view) {\n"
         "  // moonbit-libyue 补丁:宽度保持 -1,高度取内容 yoga 自然高度\n"
         "  int req_w = -1, req_h = -1;\n"
         "  if (content_view_) {\n"
         "    gtk_widget_get_size_request(content_view_->GetNative(), &req_w, &req_h);\n"
         "    if (req_w == 0 && req_h == 0)  // 上游写入过的 0×0 视为未设置\n"
         "      req_w = req_h = -1;\n"
         "  }\n"
         "  if (req_w == -1 && req_h == -1 && view->IsContainer()) {\n"
         "    SizeF natural = static_cast<Container*>(view)->GetPreferredSize();\n"
         "    if (natural.height() > 0)\n"
         "      req_h = static_cast<int>(natural.height());\n"
         "  }\n"),
        (scroll_src,
         "  gtk_container_add(GTK_CONTAINER(viewport), view->GetNative());\n"
         "  gtk_widget_set_size_request(view->GetNative(), csize.width(), csize.height());\n"
         "}",
         "  gtk_container_add(GTK_CONTAINER(viewport), view->GetNative());\n"
         "  gtk_widget_set_size_request(view->GetNative(), req_w, req_h);\n"
         "}"),
        (scroll_src,
         "void Slider::SetValue(float value) {\n"
         "  g_object_set_data(G_OBJECT(GetNative()), \"ignore-value-change\", this);\n"
         "  gtk_range_set_value(GTK_RANGE(GetNative()), value);\n"
         "}",
         "void Slider::SetValue(float value) {\n"
         "  // moonbit-libyue 补丁:仅当值变化才设 ignore 标记\n"
         "  if (GetValue() != value)\n"
         "    g_object_set_data(G_OBJECT(GetNative()), \"ignore-value-change\", this);\n"
         "  gtk_range_set_value(GTK_RANGE(GetNative()), value);\n"
         "}"),
    ]
    texts: dict[Path, str] = {}
    for path, old, new in patches:
        if path not in texts:
            texts[path] = path.read_text(encoding="utf-8")
        if new in texts[path]:
            continue  # 已应用（理论不可达：extract 每次还原原文件）
        if old not in texts[path]:
            raise SystemExit(f"vendor 补丁目标文本未找到（上游可能已变）：{path}")
        texts[path] = texts[path].replace(old, new)
        print(f"已应用 GTK 容器事件补丁：{path.name}")
    for path, text in texts.items():
        path.write_text(text, encoding="utf-8")


def patch_win_scroll_natural_size() -> None:
    """vendor 补丁（Windows）：Scroll 滚动范围跟随内容自然尺寸（幂等）。
    原理见 docs/adaptation.md「运行期差异」。
    """
    header = VENDOR_DIR / "libyue/include/nativeui/win/scroll_win.h"
    source = VENDOR_DIR / "libyue/src/win/nativeui/nativeui_jumbo_4.cc"
    patches = [
        (header,
         "  Size content_size_;\n  Vector2d origin_;",
         "  Size content_size_;\n"
         "  // moonbit-libyue 补丁:false 时滚动范围跟随内容自然尺寸\n"
         "  bool content_size_explicit_ = false;\n"
         "  Vector2d origin_;"),
        (source,
         "void ScrollImpl::SetContentSize(const Size& size) {\n"
         "  content_size_ = size;",
         "void ScrollImpl::SetContentSize(const Size& size) {\n"
         "  content_size_ = size;\n"
         "  content_size_explicit_ = true;  // moonbit-libyue 补丁:显式设置过"),
        (source,
         "void ScrollImpl::Layout() {\n"
         "  if (h_scrollbar_)\n"
         "    h_scrollbar_->SizeAllocate(GetScrollbarRect(false) +\n"
         "                               size_allocation().OffsetFromOrigin());",
         "void ScrollImpl::Layout() {\n"
         "  // moonbit-libyue 补丁:未显式 SetContentSize 时滚动范围跟随内容自然尺寸\n"
         "  if (delegate_->GetContentView() && !content_size_explicit_ &&\n"
         "      delegate_->GetContentView()->IsContainer()) {\n"
         "    const SizeF pref = static_cast<Container*>(\n"
         "        delegate_->GetContentView())->GetPreferredSize();\n"
         "    const Size natural = ToCeiledSize(ScaleSize(pref, scale_factor()));\n"
         "    if (natural != content_size_) {\n"
         "      content_size_ = natural;\n"
         "      UpdateScrollbar();\n"
         "    }\n"
         "  }\n"
         "  if (h_scrollbar_)\n"
         "    h_scrollbar_->SizeAllocate(GetScrollbarRect(false) +\n"
         "                               size_allocation().OffsetFromOrigin());"),
    ]
    texts: dict[Path, str] = {}
    for path, old, new in patches:
        if path not in texts:
            texts[path] = path.read_text(encoding="utf-8")
        if new in texts[path]:
            continue  # 已应用（理论不可达：extract 每次还原原文件）
        if old not in texts[path]:
            raise SystemExit(f"vendor 补丁目标文本未找到（上游可能已变）：{path}")
        texts[path] = texts[path].replace(old, new)
        print(f"已应用 Windows 滚动自然尺寸补丁：{path.name}")
    for path, text in texts.items():
        path.write_text(text, encoding="utf-8")


def patch_win_webview2_args() -> None:
    """vendor 补丁（Windows）：环境变量 LIBYUE_WEBVIEW2_ARGS 追加
    WebView2 浏览器参数，如 --no-proxy-server 直连（幂等）。
    原理见 docs/adaptation.md「运行期差异」。
    """
    source = VENDOR_DIR / "libyue/src/win/nativeui/nativeui_jumbo_4.cc"
    old = ("Microsoft::WRL::ComPtr<CoreWebView2EnvironmentOptions> GetWebView2Options() {\n"
           "  auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();\n"
           "  Microsoft::WRL::ComPtr<ICoreWebView2EnvironmentOptions4> options4;")
    new = ("Microsoft::WRL::ComPtr<CoreWebView2EnvironmentOptions> GetWebView2Options() {\n"
           "  auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();\n"
           "  // moonbit-libyue 补丁:环境变量 LIBYUE_WEBVIEW2_ARGS 追加浏览器参数\n"
           "  {\n"
           "    wchar_t extra_args[2048] = L\"\";\n"
           "    if (::GetEnvironmentVariableW(L\"LIBYUE_WEBVIEW2_ARGS\", extra_args, 2048) > 0)\n"
           "      options->put_AdditionalBrowserArguments(extra_args);\n"
           "  }\n"
           "  Microsoft::WRL::ComPtr<ICoreWebView2EnvironmentOptions4> options4;")
    text = source.read_text(encoding="utf-8")
    if new in text:
        return  # 已应用（理论不可达：extract 每次还原原文件）
    if old not in text:
        raise SystemExit(f"vendor 补丁目标文本未找到（上游可能已变）：{source}")
    source.write_text(text.replace(old, new), encoding="utf-8")
    print("已应用 WebView2 浏览器参数补丁：nativeui_jumbo_4.cc")


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
        patch_win_scroll_natural_size()
        patch_win_webview2_args()
        fetch_webview2_sdk()
    if os_name == "Linux":
        patch_linux_container_events()
    cmake_build()
    print("prepare 完成")


if __name__ == "__main__":
    main()
