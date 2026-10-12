#!/usr/bin/env bash
# 绕过 prebuild 跑任意 moon 子命令（本机 moon 的 prebuild 子进程 spawn 报
# os error 231，属环境限制而非代码问题）。用法：
#   scripts/wbrun.sh build ./experiment/menu_probe
#   scripts/wbrun.sh run ./experiment/menu_probe
# 只把 moon.mod / modules/ffmpeg-mbt/moon.mod 的 prebuild 行摘掉再跑，跑完
# 必还原（trap，异常也还原）。
#
# 注意：摘掉 prebuild 后链接期会缺 prebuild.py 下发的系统库（Windows 上表现为
# 一串 LNK2019 __imp_*），**编译期产物（.obj/.c/.core）照常生成**——所以这个
# 入口的用处是「先拿到编译产物，再手工链接」；`moon check --deny-warn` 才是
# 本机可靠的全量检查信号。
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
MODS=(moon.mod modules/ffmpeg-mbt/moon.mod)
BAK=""
restore() {
  if [ -n "$BAK" ] && [ -d "$BAK" ]; then
    for f in "${MODS[@]}"; do
      [ -f "$BAK/$f" ] && cp "$BAK/$f" "$f"
    done
    rm -rf "$BAK"
  fi
}
trap restore EXIT
BAK="$(mktemp -d)"
for f in "${MODS[@]}"; do
  mkdir -p "$BAK/$(dirname "$f")"
  cp "$f" "$BAK/$f"
done
python - <<'PY'
import re
for p in ("moon.mod", "modules/ffmpeg-mbt/moon.mod"):
    s = open(p, encoding="utf-8").read()
    s = re.sub(r'\n\s*"--moonbit-unstable-prebuild"[^\n]*\n', '\n', s)
    s = re.sub(r',\s*\n\s*\)', '\n)', s)
    open(p, "w", encoding="utf-8").write(s)
PY
moon "$@"
