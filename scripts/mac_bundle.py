#!/usr/bin/env python3
"""把 moon 构建出的可执行文件包成 macOS .app 骨架并 ad-hoc 签名。

为什么需要：macOS 的系统通知（以及其它要求「应用身份」的能力）只对带
Info.plist / CFBundleIdentifier 且经过签名的 .app 生效。`moon build` 直接
产出的裸可执行文件没有 bundle identifier，系统不会把它登记为可通知应用，
调用通知 API 只会静默失败——这是系统限制，不是库的问题。

用法：
  python3 scripts/mac_bundle.py examples/showcase
  python3 scripts/mac_bundle.py examples/showcase --name Showcase \\
      --id com.example.showcase --version 0.1.0
  python3 scripts/mac_bundle.py --exe _build/native/release/build/examples/hello/hello.exe

产物：dist/<名字>.app（可用 `open` 或 Finder 双击启动）。

注意：打包与 plist 生成在任何平台都能跑（便于核对骨架），但 ad-hoc 签名
依赖 macOS 自带的 codesign，非 macOS 上会跳过并提示。
"""

from __future__ import annotations

import argparse
import plistlib
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# 与预构建静态库的部署目标一致（fork 的 CMAKE_OSX_DEPLOYMENT_TARGET）。
DEFAULT_MIN_SYSTEM = "11.0"
# 默认标识符前缀；正式应用应换成自己的反向域名。
DEFAULT_ID_PREFIX = "com.example"


def find_exe(target: Path, modes: list[str]) -> Path:
    """按目标名在 moon 的构建目录里找可执行文件。

    产物在模块路径下（`_build/native/release/build/<模块>/examples/<名>/<名>.exe`），
    模块层级随工作区配置变化，所以按后缀递归匹配而不是写死路径。
    """
    name = target.name
    # 目标名可能带包路径（examples/showcase），也可能只有示例名（showcase）。
    suffixes = {str(target), name, f"examples/{name}"}
    for mode in modes:
        root = REPO_ROOT / "_build/native" / mode / "build"
        if not root.is_dir():
            continue
        found: list[Path] = []
        for suffix in sorted(suffixes):
            found.extend(root.glob(f"**/{suffix}/{name}.exe"))
        if found:
            # 路径层级少的更接近直接产物，优先。
            found.sort(key=lambda p: (len(p.parts), str(p)))
            return found[0]
    raise SystemExit(
        f"找不到 {name} 的构建产物，先执行 moon build（或在命令里用 --exe 指定路径）"
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="把 moon 产物包成 macOS .app 骨架并 ad-hoc 签名",
    )
    parser.add_argument(
        "target",
        nargs="?",
        help="示例名或包路径（如 showcase、examples/showcase）",
    )
    parser.add_argument("--exe", help="直接指定可执行文件路径，跳过自动查找")
    parser.add_argument("--name", help="应用显示名（默认取目标名）")
    parser.add_argument("--id", dest="bundle_id", help="CFBundleIdentifier")
    parser.add_argument("--version", default="0.1.0", help="CFBundleVersion（默认 0.1.0）")
    parser.add_argument("--icon", help=".icns 图标文件，复制进 Resources")
    parser.add_argument("--out", default="dist", help="输出目录（默认 dist）")
    parser.add_argument(
        "--min-system",
        default=DEFAULT_MIN_SYSTEM,
        help=f"LSMinimumSystemVersion（默认 {DEFAULT_MIN_SYSTEM}）",
    )
    parser.add_argument(
        "--mode",
        choices=("release", "debug", "auto"),
        default="auto",
        help="查找产物用的构建模式（默认 auto：先 release 后 debug）",
    )
    parser.add_argument("--no-sign", action="store_true", help="跳过 ad-hoc 签名")
    parser.add_argument("--open", action="store_true", help="打包完成后启动应用")
    args = parser.parse_args()

    if not args.exe and not args.target:
        parser.error("需要给出目标名，或用 --exe 指定可执行文件")

    if args.exe:
        exe = Path(args.exe).resolve()
        if not exe.is_file():
            raise SystemExit(f"可执行文件不存在：{exe}")
        default_name = exe.stem
    else:
        modes = ["release", "debug"] if args.mode == "auto" else [args.mode]
        exe = find_exe(Path(args.target), modes)
        default_name = Path(args.target).name

    name = args.name or default_name
    bundle_id = args.bundle_id or f"{DEFAULT_ID_PREFIX}.{name.lower().replace(' ', '-')}"

    app = (REPO_ROOT / args.out / f"{name}.app").resolve()
    macos_dir = app / "Contents/MacOS"
    resources_dir = app / "Contents/Resources"
    if app.exists():
        shutil.rmtree(app)
    macos_dir.mkdir(parents=True)
    resources_dir.mkdir(parents=True)

    inner = macos_dir / name
    shutil.copy2(exe, inner)
    inner.chmod(0o755)

    info = {
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundlePackageType": "APPL",
        "CFBundleName": name,
        "CFBundleDisplayName": name,
        "CFBundleExecutable": name,
        "CFBundleIdentifier": bundle_id,
        "CFBundleVersion": args.version,
        "CFBundleShortVersionString": args.version,
        "LSMinimumSystemVersion": args.min_system,
        # Retina 图形按点缩放渲染，桌面应用默认打开。
        "NSHighResolutionCapable": True,
    }
    if args.icon:
        icon = Path(args.icon).resolve()
        if not icon.is_file():
            raise SystemExit(f"图标文件不存在：{icon}")
        shutil.copy2(icon, resources_dir / icon.name)
        info["CFBundleIconFile"] = icon.name
    with open(app / "Contents/Info.plist", "wb") as f:
        plistlib.dump(info, f)
    # 传统 Mac OS 的文件类型标记，缺失不影响运行但 Finder 会用来做图标缓存。
    (app / "Contents/PkgInfo").write_text("APPL????", encoding="ascii")

    print(f"已生成骨架：{app}")
    print(f"  可执行文件：Contents/MacOS/{name}")
    print(f"  标识符：{bundle_id}")
    print(f"  最低系统：{args.min_system}")

    if args.no_sign:
        print("按要求跳过签名；未签名的 .app 仍然拿不到通知授权。")
    elif sys.platform == "darwin":
        subprocess.run(
            ["codesign", "--force", "--sign", "-", str(app)],
            check=True,
        )
        print("已 ad-hoc 签名（codesign --force --sign -）")
    else:
        print("当前不是 macOS，跳过 ad-hoc 签名；请在 macOS 上重新执行本脚本再验证通知。")

    if args.open:
        if sys.platform != "darwin":
            print("当前不是 macOS，跳过启动。")
        else:
            subprocess.run(["open", str(app)], check=True)
            print("已启动应用")
    return 0


if __name__ == "__main__":
    sys.exit(main())
