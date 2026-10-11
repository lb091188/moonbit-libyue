#!/usr/bin/env python3
"""守卫：仓内 MoonBit 源码不得出现 #cfg 编译期条件编译。

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

做法
----
扫描本仓 MoonBit 源码目录，凡出现 `#cfg` 一律判失败并打印文件行号；同时统计
运行时 `platform()` 判断的条数作为存量信息输出（不作为门禁）。

用法：python3 scripts/check-platform-dispatch.py [--root DIR]
退出码 0 通过，1 发现 #cfg。
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


def iter_mbt(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if name.endswith(".mbt"):
                yield os.path.join(dirpath, name)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".", help="仓根目录")
    args = ap.parse_args()

    repo = os.path.abspath(args.root)
    scanned = 0
    cfg_hits = []
    runtime_hits = 0

    for rel in SOURCE_ROOTS:
        base = os.path.join(repo, rel)
        if not os.path.isdir(base):
            continue
        for path in iter_mbt(base):
            scanned += 1
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                for lineno, line in enumerate(f, 1):
                    if CFG_RE.search(line):
                        cfg_hits.append((os.path.relpath(path, repo), lineno,
                                         line.strip()))
                    if PLATFORM_RE.search(line):
                        runtime_hits += 1

    print("扫描 {} 个 .mbt 文件，运行时 platform() 判断 {} 处".format(
        scanned, runtime_hits))

    if cfg_hits:
        print("\n发现 {} 处 #cfg 编译期条件编译（本仓平台分流统一走运行时判断）："
              .format(len(cfg_hits)))
        for path, lineno, text in cfg_hits:
            print("  {}:{}: {}".format(path, lineno, text[:80]))
        print("\n改为 @yue.platform() 的 if / match 运行时分支；"
              "确需编译期条件时请先在 docs/zh/adaptation.md 记录理由再改本脚本白名单。")
        return 1

    print("通过：未发现 #cfg，平台分流全部为运行时 platform() 判断。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
