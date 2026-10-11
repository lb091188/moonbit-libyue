#!/usr/bin/env python3
"""守卫：仓内 MoonBit 源码的平台分流必须统一为运行时 `match platform()`。

背景
----
平台分流统一走运行时判断（`@yue.platform()`），不用 `#cfg(platform=...)`。

原因不是语言层不支持：moonc 确实实现了 `#cfg(platform="windows"/"linux"/"macos")`
并可按 `-target` 三元组求值；但 moon 构建层没有传递通道——它给 moonc 的永远是
无 OS 信息的泛型 backend（native），四条注入通道全部堵死（`--target` 只收
wasm/wasm-gc/js/native/llvm/all；`preferred_target` 填三元组报 not a valid
backend；`moon.pkg` 的 `targets` 解析不了 OS 条件；`moon.pkg`/`moon.mod` 没有
cfg 字段）。结论是：`#cfg(platform=)` 在 moon 驱动的构建下恒为假，写了等于没写，
还要靠额外脚手架（moonc wrapper）才能验证，收益不抵复杂度。见
docs/zh/adaptation.md 的「MoonBit cfg(platform=)」小节。

C/C++ shim 层不受此约束：那里是 `#if defined(OS_WIN)` / 独立平台 TU + CMake
互斥挂载，本来就是编译期隔离，本脚本只扫 .mbt。

三条规则
--------
1. 禁 `#cfg`——编译期条件在本仓构建链下恒假。
2. 平台分流一律 `match platform() { "windows" => ...; _ => ... }`：
   禁止 `if platform() == "..."` 与 `platform() == "..." || ...` 这类比较式。
   比较式的 `else` 会隐含某个平台（历史上是 Linux），未知平台静默走 Linux
   专用实现（读 /proc、调 systemctl/wpctl），属真实隐患；match 的 `_ =>`
   把这种情况变成显式的「不支持」。
3. 每个 `match platform()` 必须有 `_ =>` 兜底分支。

例外（本脚本不检查）
--------------------
- 测试文件 `*_wbtest.mbt`：那里的平台判断是测试跳过守卫，属测试控制流。
- `yue/app.mbt` 的 `pub fn platform()` 本身：它是平台查询入口，用
  `match ffi_platform() { 0 => "linux"; ... }`，不是分流。
- UI 层的布局特化（Windows 特化 vs 其它平台通用）同样写 `match`，只是
  `_ =>` 走通用实现而非 Unsupported。

用法：python3 scripts/check-platform-dispatch.py [--root DIR]
退出码 0 通过，1 有违规。
"""

import argparse
import os
import re
import sys

# 需要扫描的源码根（相对仓根）；_build / .mooncakes 等一律跳过
SOURCE_ROOTS = ["yue", "src", "examples", "cmd"]

# 目录名黑名单：构建产物、依赖、版本控制
SKIP_DIRS = {"_build", ".mooncakes", ".git", "node_modules", ".workbuddy"}

CFG_RE = re.compile(r"#cfg")
PLATFORM_RE = re.compile(r"platform\s*\(")
# 禁止的比较式：platform() == / != ；前缀 (?<![A-Za-z0-9_]) 排除 ffi_platform()
CMP_RE = re.compile(r"(?<![A-Za-z0-9_])platform\s*\(\s*\)\s*(?:==|!=)")
# 禁止的 if 式：if platform( / if @yue.platform(
IF_RE = re.compile(r"\bif\s+(?:@?yue\.)?platform\s*\(")
# 合法的 match 开头
MATCH_RE = re.compile(r"\bmatch\s+(?:@?yue\.)?platform\s*\(\s*\)\s*\{")


def iter_mbt(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if name.endswith(".mbt"):
                yield os.path.join(dirpath, name)


def strip_comment(line):
    """去掉行内 // 注释，保留 `://`（URL 等）。"""
    return re.split(r"(?<!:)//", line)[0]


def check_match_has_fallback(src):
    """返回缺 `_ =>` 兜底的 match platform 所在行号列表。"""
    missing = []
    for m in MATCH_RE.finditer(src):
        i = m.end()
        depth = 1
        while i < len(src) and depth > 0:
            if src[i] == "{":
                depth += 1
            elif src[i] == "}":
                depth -= 1
            i += 1
        body = src[m.end():i]
        if not re.search(r"^\s*_ =>", body, re.M):
            missing.append(src[:m.start()].count("\n") + 1)
    return missing


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".", help="仓根目录")
    args = ap.parse_args()

    repo = os.path.abspath(args.root)
    scanned = 0
    cfg_hits = []
    cmp_hits = []
    if_hits = []
    no_fb_hits = []
    runtime_hits = 0

    for rel in SOURCE_ROOTS:
        base = os.path.join(repo, rel)
        if not os.path.isdir(base):
            continue
        for path in iter_mbt(base):
            relpath = os.path.relpath(path, repo)
            is_test = relpath.endswith("_wbtest.mbt")
            scanned += 1
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                src = f.read()
            for lineno, line in enumerate(src.split("\n"), 1):
                if CFG_RE.search(line):
                    cfg_hits.append((relpath, lineno, line.strip()))
                if PLATFORM_RE.search(line):
                    runtime_hits += 1
                if is_test:
                    continue  # 测试文件的平台跳过守卫属控制流
                code = strip_comment(line)
                if CMP_RE.search(code):
                    cmp_hits.append((relpath, lineno, line.strip()))
                elif IF_RE.search(code):
                    if_hits.append((relpath, lineno, line.strip()))
            if not is_test:
                for lineno in check_match_has_fallback(src):
                    no_fb_hits.append((relpath, lineno, "match platform() 缺 _ 兜底"))

    print("扫描 {} 个 .mbt 文件，运行时 platform() 判断 {} 处".format(
        scanned, runtime_hits))

    problems = []
    if cfg_hits:
        problems.append(("发现 {} 处 #cfg 编译期条件编译".format(len(cfg_hits)),
                         cfg_hits))
    if cmp_hits:
        problems.append((
            "发现 {} 处 platform() 比较式（应改为 match）".format(len(cmp_hits)),
            cmp_hits))
    if if_hits:
        problems.append((
            "发现 {} 处 if platform(...) 式（应改为 match）".format(len(if_hits)),
            if_hits))
    if no_fb_hits:
        problems.append((
            "发现 {} 处 match platform() 缺 `_ =>` 兜底".format(len(no_fb_hits)),
            no_fb_hits))

    if problems:
        for title, hits in problems:
            print("\n" + title + "：")
            for path, lineno, text in hits:
                print("  {}:{}: {}".format(path, lineno, text[:90]))
        print("\n统一写法：\n"
              "  match @yue.platform() {\n"
              '    "linux" => xxx_linux()\n'
              '    "windows" | "macos" => xxx_direct()\n'
              "    _ => Err(Unsupported)   // Bool 型给 false，数组/串按文件惯例\n"
              "  }")
        return 1

    print("通过：无 #cfg，平台分流全部为 match platform() 且有 _ 兜底。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
