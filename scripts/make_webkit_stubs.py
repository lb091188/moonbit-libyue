#!/usr/bin/env python3
"""webkit 依赖隔离的探索产物：符号改名手术 + weak stub（未接入主链路）。

结论先行：静态 stub 兜底在 moon 工具链下不成立，本脚本保留作为机制
记录与「纯非浏览器分发」场景的手工工具，prebuild 不自动启用。

不成立的原因（全程实测）：libyue 预构建库把浏览器实现与 PainterGtk/
Font/Image 等编在同一个 jumbo 成员，非浏览器程序链接该成员就得解析
webkit_* 符号。任何静态定义（weak 与否）都会在链接期绑定引用且不可逆，
而 moon 对链接命令默认加 --as-needed 且按依赖拓扑序（yue → traybus →
browser）拼接各包 flags——浏览器程序的命令行里主包份的 stub 必然先于
browser 条目的真 webkit 库：
  1. 绑定后真库失效：调用点已指向空 stub，运行时浏览器页段错误；
  2. DT_NEEDED 被丢：处理 -lwebkit2gtk 时未定义引用已被 stub 消化，
     --as-needed 以「截至该库未被引用」为由不写 NEEDED；
  3. weak 不会被动态强符号覆盖：实测「可执行文件 weak 定义 + 共享库
     强定义」运行时绑定 weak（-1 而非 42）。
符号改名手术（本脚本：objcopy --redefine-syms 生成 libyue_nobrowser.a
+ y4b* weak stub）能精确服务非浏览器程序，但同一份 yue 条目 flags 无法
按 main 是否 import yue/browser 分叉，浏览器程序仍会踩上述 1/2。

正解（已落地）：prepare.py 源码模式把浏览器段从 jumbo 抽成独立编译
单元（split_browser_out_of_jumbo），静态库按需拉取天然隔离，无需任何
stub；预构建库的同等改造属 fork 发行脚本侧工作（4a，见
docs/adaptation.md「浏览器依赖按需化」一节）。
"""

from __future__ import annotations

import hashlib
import platform
import shutil
import subprocess
import sys
from pathlib import Path

MODULE_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = MODULE_ROOT / "build"

# 浏览器栈专属符号前缀：webkit2gtk + 其 cookie 依赖 libsoup +
# javascriptcore 的 C API（jsc_ 前缀的 GLib 绑定与 JSString/JSValue 开头
# 的 JSC C API，后者由 libjavascriptcoregtk 导出）。
STUB_PREFIXES = ("webkit_", "soup_", "jsc_", "javascriptcore_",
                 "JSString", "JSValue")

STUB_LIB = BUILD_DIR / "libwebkit_stubs.a"
NOBROWSER_LIB = BUILD_DIR / "libyue_nobrowser.a"
HASH_FILE = BUILD_DIR / "webkit_stub_hash"


def _native_lib() -> Path:
    """当前实际参与链接的原生库（与 prebuild._native_dir 同口径）。"""
    sys.path.insert(0, str(MODULE_ROOT / "scripts"))
    import prebuild  # noqa: PLC0415  复用 vendored/build 选择逻辑
    return prebuild._native_lib_path()


def _run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    proc = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if proc.returncode != 0:
        raise SystemExit(
            f"[webkit-stubs] {' '.join(cmd[:2])} 失败：{(proc.stderr or proc.stdout)[:500]}")
    return proc


def undefined_symbols(lib: Path) -> list[str]:
    """nm 列出库中未定义的浏览器栈符号（C 链接名，去重排序）。"""
    out = _run(["nm", str(lib)])
    syms = set()
    for line in out.stdout.splitlines():
        parts = line.split()
        # 未定义符号形如 "U name"（两列；已定义符号才是 "addr T name"）
        if len(parts) == 2 and parts[0] == "U" and parts[1].startswith(STUB_PREFIXES):
            syms.add(parts[1])
    return sorted(syms)


def tainted_members(lib: Path, syms: set[str]) -> list[str]:
    """列出含这些未定义引用的 archive 成员名。nm 对 archive 的输出以
    「成员名:」顶格行分节。"""
    out = _run(["nm", str(lib)])
    members: set[str] = set()
    current = None
    for line in out.stdout.splitlines():
        if line.endswith(":") and " " not in line:
            current = line[:-1]
            continue
        parts = line.split()
        if len(parts) == 2 and parts[0] == "U" and parts[1] in syms and current:
            members.add(current)
    return sorted(members)


def _member_extract(archive: Path, member: str, dest: Path) -> None:
    proc = subprocess.run(["ar", "p", str(archive), member],
                          capture_output=True)
    if proc.returncode != 0:
        raise SystemExit(f"[webkit-stubs] ar p {member} 失败：{proc.stderr[:300]}")
    dest.write_bytes(proc.stdout)  # .o 是二进制，不走文本通道


def surgery(lib: Path, syms: list[str]) -> None:
    """生成改名手术版 libyue_nobrowser.a 与 stub 库。"""
    BUILD_DIR.mkdir(exist_ok=True)
    mapping = {sym: f"y4b{i}" for i, sym in enumerate(syms)}
    map_file = BUILD_DIR / "webkit_stub_redefine.txt"
    map_file.write_text(
        "".join(f"{old} {new}\n" for old, new in mapping.items()),
        encoding="utf-8")

    members = tainted_members(lib, set(syms))
    if not members:
        raise SystemExit("[webkit-stubs] 有浏览器符号却找不到携带成员，中止")

    # 复制整库后逐成员替换：原库（vendored 入库文件）绝不可被改动。
    # ar r 以「文件 basename」匹配成员名，故改名产物须重命名成原成员名。
    shutil.copy2(lib, NOBROWSER_LIB)
    workdir = BUILD_DIR / "webkit_stub_work"
    workdir.mkdir(exist_ok=True)
    for member in members:
        raw = workdir / "m.o"
        _member_extract(lib, member, raw)
        fixed = workdir / member  # 与原成员同名，ar r 才是替换而非追加
        _run(["objcopy", f"--redefine-syms={map_file}", str(raw), str(fixed)])
        _run(["ar", "r", str(NOBROWSER_LIB), str(fixed)])
        fixed.unlink()
    shutil.rmtree(workdir, ignore_errors=True)

    # stub 库：weak 空定义（符号名与改名后的引用一致）
    source = (
        "/* 由 scripts/make_webkit_stubs.py 生成，勿手改。\n"
        f" * 符号源自 nm {lib.name}（{len(syms)} 个浏览器栈符号，已改名）。\n"
        " * 每个 weak 空定义只服务于「引用被改成 y4b* 的手术版库」：非\n"
        " * browser 程序（未 import yue/browser）链接手术版 jumbo 成员时\n"
        " * 由此消化改名引用，浏览器代码路径不可达故无执行可能。机制与\n"
        " * 安全性论证见 docs/adaptation.md。\n"
        " */\n"
        + "".join(
            f'__attribute__((weak)) void {new}(void) {{ }}\n'
            for new in mapping.values())
    )
    src_c = BUILD_DIR / "webkit_stubs.c"
    src_c.write_text(source, encoding="utf-8")
    obj = BUILD_DIR / "webkit_stubs.o"
    _run(["gcc", "-c", str(src_c), "-o", str(obj)])
    STUB_LIB.unlink(missing_ok=True)
    _run(["ar", "rcs", str(STUB_LIB), str(obj)])
    obj.unlink(missing_ok=True)

    digest = hashlib.sha256(
        lib.read_bytes()[:1 << 20] + ("\n".join(syms)).encode()).hexdigest()
    HASH_FILE.write_text(digest, encoding="utf-8")
    print(f"[moonbit-libyue] webkit 手术完成：手术版库 {NOBROWSER_LIB.name}"
          f"（改 {len(members)} 成员/{len(syms)} 符号）+ stub {STUB_LIB.name}",
          file=sys.stderr)


def ensure() -> tuple[Path, Path] | None:
    """返回 (手术版原生库, stub 库)；非 Linux 返回 None。缓存命中跳过。"""
    if platform.system() != "Linux":
        return None
    lib = _native_lib()
    if not lib.exists():
        return None
    syms = undefined_symbols(lib)
    if not syms:
        # 库已无浏览器符号（未来 fork 拆分后的产物）→ 移除手术产物
        for p in (NOBROWSER_LIB, STUB_LIB, HASH_FILE, BUILD_DIR / "webkit_stub_redefine.txt"):
            p.unlink(missing_ok=True)
        return None
    digest = hashlib.sha256(
        lib.read_bytes()[:1 << 20] + ("\n".join(syms)).encode()).hexdigest()
    if (HASH_FILE.exists() and HASH_FILE.read_text() == digest
            and NOBROWSER_LIB.exists() and STUB_LIB.exists()):
        return NOBROWSER_LIB, STUB_LIB
    surgery(lib, syms)
    return NOBROWSER_LIB, STUB_LIB


if __name__ == "__main__":
    result = ensure()
    print(result[0] if result else "（非 Linux 或无符号，未生成）")
