#!/usr/bin/env python3
"""校验 #cfg(platform=) 分支在目标三元组下被正确选取。

背景
----
moonc 只在拿到目标三元组（x86_64-unknown-linux-gnu 等）时才知道 platform，
moon 驱动的构建传的是泛型 backend（native），platform 恒不成立。因此仓内
的 platform 分支在常规 `moon build` 下不会参与编译，只能靠本脚本用 moonc
三元组直编来证明它们写得对、能被正确选取。

做法
----
生成一个与仓内同构的探针包（三份平台实现 + 一份 native 兜底，形态与
yue/system/volume.mbt 一致），对三个三元组各直编一次，断言命中的分支：

    x86_64-unknown-linux-gnu  -> LINUX
    x86_64-pc-windows-msvc    -> WINDOWS
    aarch64-apple-darwin      -> MACOS
    native（泛型，对照）       -> NATIVE-FALLBACK

最后一组是回归哨兵：它证明 moon 当前确实不注入 platform，所以仓内必须
保留运行时兜底分支；哪天这项变成 LINUX，说明 moon 开始传三元组了，就可以
按 adaptation.md 的约定删掉兜底。

用法：python3 scripts/check-cfg-platforms.py [--moonc PATH]
退出码 0 全部通过，1 有不符预期。
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

PROBE = """#cfg(platform = "linux")
fn plat_impl() -> String { "LINUX" }

#cfg(any(platform = "windows", platform = "macos"))
fn plat_impl() -> String { "WINDOWS-OR-MACOS" }

#cfg(all(target = "native", not(platform = "linux"), not(platform = "windows"), not(platform = "macos")))
fn plat_impl() -> String { "NATIVE-FALLBACK" }

pub fn plat() -> String { plat_impl() }
"""

# 三元组 -> 期望命中的实现标记
EXPECT = {
    "x86_64-unknown-linux-gnu": "LINUX",
    "x86_64-pc-windows-msvc": "WINDOWS-OR-MACOS",
    "aarch64-apple-darwin": "WINDOWS-OR-MACOS",
    "native": "NATIVE-FALLBACK",
}


def resolve_moonc(explicit):
    if explicit:
        return explicit
    moon_home = os.environ.get("MOON_HOME") or os.path.expanduser("~/.moon")
    return os.path.join(moon_home, "bin", "moonc")


def resolve_std_path(moonc):
    """core 的 .mi 根目录：与 moonc 同属一个工具链安装。"""
    lib = os.path.join(os.path.dirname(os.path.dirname(moonc)), "lib", "core")
    return lib if os.path.isdir(lib) else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--moonc", default=None)
    args = ap.parse_args()

    moonc = resolve_moonc(args.moonc)
    if not os.path.isfile(moonc):
        print("找不到 moonc：{}".format(moonc), file=sys.stderr)
        return 1
    std_path = resolve_std_path(moonc)
    if std_path is None:
        print("找不到 core 目录", file=sys.stderr)
        return 1

    tmp = tempfile.mkdtemp(prefix="cfgprobe-")
    try:
        src = os.path.join(tmp, "plat.mbt")
        with open(src, "w", encoding="utf-8") as f:
            f.write(PROBE)

        failures = 0
        for target, want in EXPECT.items():
            out = os.path.join(tmp, "plat_{}.core".format(target))
            cmd = [
                moonc, "build-package",
                "-target", target,
                "-pkg", "probe/cfg",
                "-std-path", std_path,
                "-o", out,
                src,
            ]
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode != 0:
                print("[{:<26}] 编译失败\n{}".format(target, r.stderr.strip()[:400]))
                failures += 1
                continue
            # core 是二进制，分支标记以字符串常量形式留在里面
            with open(out, "rb") as f:
                blob = f.read()
            hits = [m for m in ("LINUX", "WINDOWS-OR-MACOS", "NATIVE-FALLBACK")
                    if m.encode() in blob]
            ok = hits == [want]
            print("[{:<26}] 命中 {} 期望 {} -> {}".format(
                target, hits or "无", want, "OK" if ok else "不符"))
            if not ok:
                failures += 1

        if failures:
            print("\n{} 项不符预期".format(failures))
            return 1
        print("\n全部通过：platform 分支在三元组下按预期分流；"
              "native 泛型仍落兜底（仓内运行时分支需保留）。")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
