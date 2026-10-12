#!/usr/bin/env bash
# 临时绕过 prebuild 跑测试（本机 moon 的 prebuild 子进程 spawn 报 os error 231，
# 属环境限制而非代码问题）。用法：scripts/wbtest.sh ./yue/win
# 只动 moon.mod 的 prebuild 行，跑完必还原（含 trap，异常也还原）。
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
python - "$@" <<'PY'
import re, sys
for p in ("moon.mod", "modules/ffmpeg-mbt/moon.mod"):
    s = open(p, encoding="utf-8").read()
    s = re.sub(r'\n\s*"--moonbit-unstable-prebuild"[^\n]*\n', '\n', s)
    s = re.sub(r',\s*\n\s*\)', '\n)', s)
    open(p, "w", encoding="utf-8").write(s)
PY
moon test "$@"
