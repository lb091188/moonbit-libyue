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


def patch_linux_container_events() -> None:
    """vendor 补丁（Linux/GTK）：容器事件窗口不再拦截子控件鼠标 + 自然尺寸感知。

    三处都出在 GTK 后端把 yoga 布局嫁接到 GTK 上的接缝（幂等；vendor 目录
    不进版本库，重跑本脚本自动重新应用）：
    - nu_container_map 里 gdk_window_show（=map+raise）会把覆盖整个容器
      区域的 INPUT_ONLY 事件窗口抬到子原生控件（GtkNotebook 页签头、
      GtkScrolledWindow 滚动区）之上，X/GDK 命中被它截走——页签点不动、
      滚轮失效，键盘走焦点不受影响。改用 show_unraised：仅映射不抬高，
      子控件窗口随后 raise 天然盖在其上，容器空白区域仍可命中。
    - CreateEventWindow 的 attributes.y 误写成 allocation.x（笔误，无实害
      但顺手修正）。
    - nu_container_get_preferred_width/height 硬编码返回 0：GtkScrolledWindow
      等原生容器完全感知不到内容大小，滚动范围恒 0（无法滚动）、Notebook
      页与 Group 的自然尺寸塌缩。改为向 yoga 询问自然尺寸（GetPreferredSize）。
    - Scroll::PlatformSetContentView 对未挂载视图取 GetPixelBounds()=0×0
      强制写入 size_request，声明式整页滚动（高度动态、未调 SetContentSize）
      的滚动范围因此恒 0。改为仅延续显式设置过的 size_request，否则复位
      -1 让 viewport 按（补丁修正后的）自然尺寸计算。
    - Container::UpdateChildBounds 开头的 IsVisibleInHierarchy 守卫整体
      return：GTK 首次 size-allocate 在 map 之前发生，此时被跳过后 map 后
      无人再以真实分配尺寸重跑 yoga 布局，独立 yoga 根（Scroll 内容/Tab 页
      容器）永久停留在挂载时的自然尺寸布局——页内容时不占满容器宽。
      改为布局总是执行（GetBounds() 即 GTK allocation），孩子传播仍受可见性限制。
    - GifPlayer 动画只在 "show" 信号补启动：挂载时（如 Notebook 非当前页）
      SetAnimating 因 IsVisibleInHierarchy=false 跳过启动，而 show 信号只在
      gtk_widget_show 时发射一次（时机早于 SetImage 时再次错过），切页 map
      后无人再触发 ScheduleFrame——GIF 永停第一帧。补连接 "map" 信号（每次
      实际映射都发射，与 "unmap"→OnHide 停 timer 对称；OnShow 幂等）。
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
         "  // moonbit-libyue 补丁:补连 map 信号。挂载时不可见(SetAnimating 跳过)\n"
         "  // 且 show 信号早于 SetImage 的情况下,切页 map 后无人再启动动画。\n"
         "  g_signal_connect(GetNative(), \"map\", G_CALLBACK(OnShow), this);\n"),
        (scroll_src,
         "GifPlayer::GifPlayer() {\n"
         "  TakeOverView(gtk_drawing_area_new());\n",
         "GifPlayer::GifPlayer() {\n"
         "  // moonbit-libyue 补丁:drawing area 自建 GdkWindow(默认 no-window)。\n"
         "  // no-window 自绘控件嵌 NUContainer 链再进 Scroll 视口时,queue_draw 的\n"
         "  // 失效区域沿父链上传的坐标归属错位——静止时投到视口外(画面不动、\n"
         "  // 甚至整段空白),滚动时才重绘出一帧(留下多帧残影)。自建窗口后绘制与\n"
         "  // 失效都相对自身 window,彻底绕开 NUContainer 链的坐标问题。\n"
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
         "  // moonbit-libyue 补丁:去掉整体 IsVisibleInHierarchy 守卫。GTK 的首次\n"
         "  // size-allocate 发生在 map 之前,原实现此时整体 return,map 后无人再以\n"
         "  // 真实分配尺寸重跑 yoga 布局,独立 yoga 根(Scroll 内容/Tab 页容器)便\n"
         "  // 永久停留在挂载时的自然尺寸布局,内容不占满容器宽。GetBounds() 读的\n"
         "  // 就是 GTK allocation(size_allocate vfunc 里已先更新),提前布局总是\n"
         "  // 安全的;GTK 本身也允许对未映射 widget 预分配,映射后即按此生效。\n"
         "  if (IsRootYGNode(this)) {\n"
         "    SizeF size = GetBounds().size();\n"
         "    YGNodeCalculateLayout(node(), size.width(), size.height(), YGDirectionLTR);\n"
         "  }\n"),
        (container_src,
         "  if (priv->event_window)\n    gdk_window_show(priv->event_window);\n\n"
         "  GTK_WIDGET_CLASS(nu_container_parent_class)->map(widget);",
         "  if (priv->event_window)\n"
         "    gdk_window_show_unraised(priv->event_window);  // moonbit-libyue 补丁:映射但不抬高,避免盖住子原生控件拦截鼠标\n\n"
         "  GTK_WIDGET_CLASS(nu_container_parent_class)->map(widget);"),
        (container_src,
         "  attributes.y = allocation.x;",
         "  attributes.y = allocation.y;  // moonbit-libyue 补丁:上游笔误 y 误用 x"),
        # nu_container_get_preferred_width/height 保持上游 0/0 不动:实测
        # (2026-09-15)向 GTK 报告 yoga 动态自然尺寸会让尺寸协商震荡
        # (allocate 污染 yoga 状态 → requisition 漂移 365→466→598→907
        # 不收敛,布局停在中间帧)。滚动范围改由 Scroll 补丁以内容自然
        # 高度显式给出(见 Scroll::PlatformSetContentView)。
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
         "  // moonbit-libyue 补丁:无显式 SetContentSize 时,宽度保持 -1(随视口\n"
         "  // 拉伸),高度取内容 yoga 自然高度并固化为 size_request——GtkViewport\n"
         "  // 以 child 的 size_request 计算滚动范围,动态高度内容(声明式整页\n"
         "  // 滚动)由此获得正确滚动范围;原实现对未挂载视图取 GetPixelBounds()\n"
         "  // =0×0 强制写入,滚动范围恒 0。固定值也让 GTK 尺寸协商一次收敛,\n"
         "  // 避免动态 requisition 反复震荡。\n"
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
         "  // moonbit-libyue 补丁:仅当值真的变化才设 ignore 标记。原实现无条件设,\n"
         "  // 而 GTK 对\"设置相同值\"(如初始化 value=0)不发 value-changed,标记残留\n"
         "  // ——用户此后第一次拖动的首个 on_value_change 被吞,滑块联动失效。\n"
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
    """vendor 补丁（Windows）：Scroll 滚动范围跟随内容自然尺寸。

    Windows 的 ScrollImpl 用自绘滚动条，滚动范围只来自 content_size_，而它
    只能经 Scroll::SetContentSize 显式写入（初值 0×0）。声明式整页滚动
    （内容高度动态、从不 SetContentSize）的范围因此恒 0，滚轮/滚动条全
    失效——与 Linux 端 nu_container preferred 尺寸 + size_request 两处补丁
    同一根因的 Windows 版（幂等；vendor 不进版本库，重跑本脚本自动重新
    应用）。改为：未显式 SetContentSize 过（打补丁新增标记位）时，Layout
    里实时向内容视图的 yoga 树查自然尺寸，尺寸变化时重建滚动条。
    """
    header = VENDOR_DIR / "libyue/include/nativeui/win/scroll_win.h"
    source = VENDOR_DIR / "libyue/src/win/nativeui/nativeui_jumbo_4.cc"
    patches = [
        (header,
         "  Size content_size_;\n  Vector2d origin_;",
         "  Size content_size_;\n"
         "  // moonbit-libyue 补丁:是否显式 SetContentSize 过;false 时滚动范围\n"
         "  // 跟随内容自然尺寸(Layout 时实时向 yoga 查询)。\n"
         "  bool content_size_explicit_ = false;\n"
         "  Vector2d origin_;"),
        (source,
         "void ScrollImpl::SetContentSize(const Size& size) {\n"
         "  content_size_ = size;",
         "void ScrollImpl::SetContentSize(const Size& size) {\n"
         "  content_size_ = size;\n"
         "  content_size_explicit_ = true;  // moonbit-libyue 补丁:显式设置过,Layout 不再用自然尺寸覆盖"),
        (source,
         "void ScrollImpl::Layout() {\n"
         "  if (h_scrollbar_)\n"
         "    h_scrollbar_->SizeAllocate(GetScrollbarRect(false) +\n"
         "                               size_allocation().OffsetFromOrigin());",
         "void ScrollImpl::Layout() {\n"
         "  // moonbit-libyue 补丁:未显式 SetContentSize 时滚动范围跟随内容自然\n"
         "  // 尺寸。上游 content_size_ 初值 0×0 且只能经 SetContentSize 写入,\n"
         "  // 声明式整页滚动(高度动态)的范围恒 0,滚轮/滚动条全失效;内容是\n"
         "  // yoga 容器时向其查自然尺寸,尺寸变化时重建滚动条。\n"
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
    """vendor 补丁（Windows）：环境变量 LIBYUE_WEBVIEW2_ARGS 追加浏览器参数。

    WebView2（Chromium）默认跟随系统代理，系统代理指向的本地进程不在时
    （如 Clash 退出未还原代理设置）所有页面一律报「无网络」错误页，而应用
    直连正常，IE 回退路径也会因 WinInet 同样配置受影响。libyue 未暴露
    AdditionalBrowserArguments，故在此补丁里支持经环境变量注入：如设
    LIBYUE_WEBVIEW2_ARGS=--no-proxy-server 强制直连（幂等；vendor 不进版本
    库，重跑本脚本自动重新应用）。
    """
    source = VENDOR_DIR / "libyue/src/win/nativeui/nativeui_jumbo_4.cc"
    old = ("Microsoft::WRL::ComPtr<CoreWebView2EnvironmentOptions> GetWebView2Options() {\n"
           "  auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();\n"
           "  Microsoft::WRL::ComPtr<ICoreWebView2EnvironmentOptions4> options4;")
    new = ("Microsoft::WRL::ComPtr<CoreWebView2EnvironmentOptions> GetWebView2Options() {\n"
           "  auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();\n"
           "  // moonbit-libyue 补丁:环境变量 LIBYUE_WEBVIEW2_ARGS 追加 WebView2 浏览器\n"
           "  // 参数。典型用途:系统代理失效时设 --no-proxy-server 直连(WebView2\n"
           "  // 默认跟随系统代理,代理进程不在时页面一律报「无网络」)。\n"
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
