#!/usr/bin/env python3
"""libyue MoonBit 封装的链接预构建脚本（--moonbit-unstable-prebuild）。

现状（MoonBit 原生 GUI 栈 G0b 起）：老的 `shim + libyue` 绑定链已从本分支摘除，
本脚本不再下载/构建/链接任何 libyue 产物，只保留两件事——

1. 把 G0 输入法探针的 C 端编成静态库（moon 的 link_configs 只有链接期字段、
   没有编译期字段，`c_flags` 会被静默忽略，故必须在脚本里编译，实测记录见
   docs/zh/adaptation.md「跨平台通用」节的 G1/G0 条）。
2. 输出 link_configs，按当前系统给出 pkg-config 探到的 GTK3/Pango/X11 参数。
   新栈自己的平台后端（yue/win）落地后，链接参数继续从这里传播。

约束：stdout 只允许输出 JSON，进度信息走 stderr。
"""

from __future__ import annotations

import json
import platform
import shutil
import subprocess
import sys
from pathlib import Path

MODULE_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = MODULE_ROOT / "build"

# Linux 系统库清单：GTK3 是新栈锁定的后端（零新增运行期依赖，本仓此前已在用），
# 探针与后续 yue/win 都从这里拿 cflags/libs。
LINUX_PKG_CONFIG_LIBS = ["gtk+-3.0", "pangoft2", "pangocairo", "fontconfig", "x11"]

IME_PROBE_PACKAGE = "NoahLiu/moonbit-libyue/experiment/ime_probe"
SYS_PACKAGE = "NoahLiu/moonbit-libyue/yue/sys"
WIN_PACKAGE = "NoahLiu/moonbit-libyue/yue/win"
RENDER_PACKAGE = "NoahLiu/moonbit-libyue/yue/render"
TEXT_PACKAGE = "NoahLiu/moonbit-libyue/yue/text"
WEB_PACKAGE = "NoahLiu/moonbit-libyue/yue/web"
# webview 引擎只能动态链（方案 §4.8：WebKitGTK 无静态库），运行期依赖发行版包。
# 缺包不算错：桩改编「无宏」的占位分支，wb_* 符号仍在、探测返回不可用。
WEBKIT_PKG_CONFIG = "webkit2gtk-4.1"


def pkg_config(args: list[str], flag: str) -> list[str] | None:
    """探包配置：返回 None 表示包不存在，返回空列表表示存在但该 flag 无输出
    （`--cflags x11` 就是合法的空输出，当成缺失会让所有主包退避）。"""
    run = subprocess.run(
        ["pkg-config", flag] + args, capture_output=True, text=True
    )
    if run.returncode != 0:
        return None
    return run.stdout.split()


def compile_stub(
    src: Path | list[Path], lib_name: str, extra_cflags: list[str] = []
) -> str:
    """把需要系统头文件的 C 端编成静态库（moon 的 link_configs 只有链接期字段、
    c_flags 会被静默忽略，实测），返回库路径；缺依赖或编译失败返回空串。
    可传多个源文件，编进同一个 .a（任一源更新即整体重编）。extra_cflags
    用于给「多平台合一的桩」开对应分支（如 stub.c 的 -DWM_STUB_GTK）。"""
    srcs = [src] if isinstance(src, Path) else list(src)
    srcs = [s for s in srcs if s.exists()]
    if not srcs:
        return ""
    cflags: list[str] = list(extra_cflags)
    for name in LINUX_PKG_CONFIG_LIBS:
        got = pkg_config([name], "--cflags")
        if got is None:
            print(f"stub: 缺少 {name} 开发包", file=sys.stderr)
            return ""
        cflags.extend(got)
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    lib = BUILD_DIR / lib_name  # ld 的 -l 命名约定：lib<name>.a
    newest = max(s.stat().st_mtime for s in srcs)
    if lib.exists() and lib.stat().st_mtime >= newest:
        return lib.as_posix()
    cc = shutil.which("cc") or shutil.which("gcc") or "cc"
    objs: list[str] = []
    for s in srcs:
        obj = BUILD_DIR / (s.stem + ".o")
        cmd = [cc, "-c", "-O2", "-fPIC", "-o", obj.as_posix(), s.as_posix()] + cflags
        run = subprocess.run(cmd, capture_output=True, text=True)
        if run.returncode != 0:
            print(f"stub: {' '.join(cmd)} 失败\n{run.stderr}", file=sys.stderr)
            return ""
        objs.append(obj.as_posix())
    # 先删旧归档再建：`ar rcs` 对同名成员是替换，但对改了名的成员是**追加**，
    # 源文件改名/拆分后会留下重名符号（multiple definition）。
    lib.unlink(missing_ok=True)
    cmd = ["ar", "rcs", lib.as_posix(), *objs]
    run = subprocess.run(cmd, capture_output=True, text=True)
    if run.returncode != 0:
        print(f"stub: {' '.join(cmd)} 失败\n{run.stderr}", file=sys.stderr)
        return ""
    return lib.as_posix()


def build_ime_probe_stub() -> str:
    """G0 输入法探针（MoonBit 原生 GUI 栈首个 spike）的 C 端编译。"""
    src = MODULE_ROOT / "experiment" / "ime_probe" / "ime_probe_stub.c"
    if not src.exists():
        return ""
    obj = BUILD_DIR / "ime_probe_stub.o"
    lib = BUILD_DIR / "libime_probe_stub.a"  # ld 的 -l 命名约定
    if lib.exists() and lib.stat().st_mtime >= src.stat().st_mtime:
        return lib.as_posix()
    cflags: list[str] = []
    for name in LINUX_PKG_CONFIG_LIBS:
        got = pkg_config([name], "--cflags")
        # 空输出是合法的（`--cflags x11` 就是空），只有 None 才是包不存在
        if got is None:
            print(f"ime_probe: 缺少 {name} 开发包", file=sys.stderr)
            return ""
        cflags.extend(got)
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    cc = shutil.which("cc") or shutil.which("gcc") or "cc"
    for cmd in (
        [cc, "-c", "-O0", "-fPIC", "-o", obj.as_posix(), src.as_posix()] + cflags,
        ["ar", "rcs", lib.as_posix(), obj.as_posix()],
    ):
        run = subprocess.run(cmd, capture_output=True, text=True)
        if run.returncode != 0:
            print(f"ime_probe: {' '.join(cmd)} 失败\n{run.stderr}", file=sys.stderr)
            return ""
    return lib.as_posix()


def link_configs() -> dict:
    entries: list[dict] = []
    system = platform.system()
    if system == "Linux":
        libs = []
        for name in LINUX_PKG_CONFIG_LIBS:
            got = pkg_config([name], "--libs")
            if got is None:
                print(f"prebuild: 缺少 {name} 开发包", file=sys.stderr)
                return {"link_configs": entries}
            libs.extend(got)
        # 系统库不会被自动带上，显式补（与旧链路同一口径）。
        sys_libs = ["-lpthread", "-ldl", "-lm", "-lstdc++", "-latomic"]
        win_lib = compile_stub(
            MODULE_ROOT / "yue" / "win" / "stub.c",
            "libyue_win_stub.a",
            extra_cflags=["-DWM_STUB_GTK"],
        )
        if win_lib:
            entries.append({
                "package": WIN_PACKAGE,
                "link_flags": f"-L{BUILD_DIR.as_posix()} -lyue_win_stub "
                + " ".join([*libs, *sys_libs]),
            })
        # sys 包的文件对话框（yue/sys/dialog.mbt）extern 直链 win 桩的
        # wm_file_* 符号：MoonBit 层不引 yue/win（parent 是纯句柄 id），
        # 链接由此处单独下发（GTK 库同 win 一套）。
        if win_lib:
            entries.append({
                "package": SYS_PACKAGE,
                "link_flags": f"-L{BUILD_DIR.as_posix()} -lyue_win_stub "
                + " ".join([*libs, *sys_libs]),
            })
        # webview（yue/web）：WebKitGTK 只能动态链。缺开发包时不报错——编「无宏」
        # 的占位分支（wb_available() 返回 0），于是 MoonBit 层按探测降级，
        # 而不是链接期缺一堆符号。顺序上 -lyue_web 在前：它引用 win 桩的
        # wm_surface_container。
        webkit_cflags = pkg_config([WEBKIT_PKG_CONFIG], "--cflags")
        webkit_libs = pkg_config([WEBKIT_PKG_CONFIG], "--libs")
        if webkit_cflags is None or webkit_libs is None:
            print(
                f"prebuild: 缺 {WEBKIT_PKG_CONFIG}，webview 走占位实现（探测返回不可用）",
                file=sys.stderr,
            )
            webkit_cflags = []
            webkit_libs = []
        if win_lib:
            web_lib = compile_stub(
                MODULE_ROOT / "yue" / "web" / "webkit_stub.c",
                "libyue_web.a",
                extra_cflags=[
                    *(["-DWB_HAVE_WEBKIT"] if webkit_cflags else []),
                    *webkit_cflags,
                ],
            )
            if web_lib:
                entries.append({
                    "package": WEB_PACKAGE,
                    "link_flags": f"-L{BUILD_DIR.as_posix()} -lyue_web -lyue_win_stub "
                    + " ".join([*libs, *webkit_libs, *sys_libs]),
                })
        # 媒体引擎已迁出主模块（本仓 `modules/yue-media/media`）：它要的
        # 系统库链接参数（miniaudio 的设备线程与 dlopen 后端）不再由这里下发，
        # 改由该模块自己的 prebuild 按包名 `NoahLiu/yue-media/media` 下发。
        # 这样主模块的依赖闭包里不再有 ffmpeg-mbt——媒体对主模块消费者
        # 回到「模块级可选」。
        cairo_lib = compile_stub(
            MODULE_ROOT / "yue" / "render" / "stub.c",
            "librender_cairo_stub.a",
            extra_cflags=["-DWM_STUB_CAIRO"],
        )
        if cairo_lib:
            entries.append({
                "package": RENDER_PACKAGE,
                "link_flags": f"-L{BUILD_DIR.as_posix()} -lrender_cairo_stub "
                + " ".join([*libs, *sys_libs]),
            })
        text_lib = compile_stub(
            MODULE_ROOT / "yue" / "text" / "stub.c",
            "libyue_text_pango.a",
            extra_cflags=["-DWM_STUB_PANGO"],
        )
        if text_lib:
            # 文本层要复用 Painter 的 Cairo 会话（cr_session_context 定义在
            # render 的桩库里），所以 text 的链接行也要带上 render 的归档。
            entries.append({
                "package": TEXT_PACKAGE,
                "link_flags": f"-L{BUILD_DIR.as_posix()} -lyue_text_pango "
                "-lrender_cairo_stub "
                + " ".join([*libs, *sys_libs]),
            })
        stub = build_ime_probe_stub()
        if stub:
            entries.append({
                "package": IME_PROBE_PACKAGE,
                # 顺序要紧：先库后系统库（GNU ld 单遍扫描）。
                "link_flags": f"-L{BUILD_DIR.as_posix()} -lime_probe_stub "
                + " ".join([*libs, *sys_libs]),
            })
    elif system == "Windows":
        # Win32 桩（yue/win/stub.c 的 _WIN32 分支）由 moon native-stub 自编
        # （windows.h 走 MSVC 自带 SDK 路径，实测可达），这里只下发系统库：
        # MSVC 口径的链接输入用位置参数直拼 .lib 名——GNU 的 -L/-l 会报
        # D9002（docs/zh/adaptation.md「链接参数」节）。user32/gdi32 建窗贴屏，
        # imm32 随 IME 线（W6）预留，advapi32 供深浅/主色注册表读。
        # W20f 图标加载要 WIC（PNG 只能走它解码，windowscodecs.lib 里同时导出
        # CLSID_WICImagingFactory1 / IID_IWICImagingFactory /
        # GUID_WICPixelFormat32bppBGRA 三个 GUID 常量，故不必再链 uuid.lib）
        # 与 COM 初始化（ole32）；W20c 托盘要 Shell_NotifyIconW（shell32）。
        entries.append({
            "package": WIN_PACKAGE,
            "link_flags": "user32.lib gdi32.lib imm32.lib advapi32.lib "
            "windowscodecs.lib ole32.lib shell32.lib",
        })
        # sys 桩（yue/sys/sys_stub.c 的 _WIN32 分支）要 COM：文件对话框走
        # IFileDialog（ole32 的 CoCreateInstance + shell32 的
        # SHCreateItemFromParsingName），GUID 常量 CLSID_FileOpenDialog /
        # IID_IFileDialog / IID_IShellItem 全在 uuid.lib——C 模式用不了
        # __uuidof，只能链库取 extern 符号（记档于 docs/zh/adaptation.md）。
        # ShellExecuteW 在 shell32，子进程与文件函数属 kernel32（默认已链）。
        # W21d 自启动写 HKCU Run 键要 advapi32（Reg* 一组）。
        entries.append({
            "package": SYS_PACKAGE,
            "link_flags": "ole32.lib shell32.lib uuid.lib user32.lib advapi32.lib",
        })
        # 文本层（yue/text/dwrite_text.cpp 的 Windows 分支）走系统 DirectWrite：
        # dwrite.lib 供 DWriteCreateFactory、d2d1.lib 供 D2D 的 DC 渲染目标
        # （文字画进 32bpp DIB 再合成），GUID 常量取头文件 extern 符号要
        # uuid.lib，COM 初始化要 ole32。native-stub 侧由 moon 编 .cpp，此处只
        # 下发链接输入。
        entries.append({
            "package": TEXT_PACKAGE,
            "link_flags": "dwrite.lib d2d1.lib windowscodecs.lib ole32.lib uuid.lib gdi32.lib",
        })
    return {"link_configs": entries}


def main() -> None:
    # Windows 控制台常为 cp1252，stderr 打中文会 UnicodeEncodeError；转 UTF-8。
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass
    try:
        json.load(sys.stdin)  # moon 传入构建环境，当前无需使用
    except json.JSONDecodeError:
        pass
    print(json.dumps(link_configs()))


if __name__ == "__main__":
    main()
