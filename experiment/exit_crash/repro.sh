#!/usr/bin/env bash
# 退出段错误复现器:启动 exe → 等窗口 → wmctrl 发关闭请求(等价点关闭按钮)
# → 等进程退出,记录退出码。多次循环统计分布。
# 用法: repro.sh <exe路径> <次数> [等待秒]
set -u
EXE="$1"; N="${2:-10}"; WAIT="${3:-1.2}"
declare -A codes
crash_logs=""
for i in $(seq 1 "$N"); do
  "$EXE" >/tmp/exitcrash_out_$i.txt 2>&1 &
  pid=$!
  sleep "$WAIT"
  # 按 PID 配对窗口(adaptation.md 方法论:exe 路径过滤的 PID ↔ wmctrl 窗口)
  win=""
  for attempt in 1 2 3 4 5; do
    win=$(wmctrl -lp 2>/dev/null | awk -v p="$pid" '$3==p {print $1; exit}')
    [ -n "$win" ] && break
    sleep 0.4
  done
  if [ -z "$win" ]; then
    echo "[$i] 未找到窗口 pid=$pid"
    kill -9 "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    codes["NO_WINDOW"]=$(( ${codes["NO_WINDOW"]:-0} + 1 ))
    continue
  fi
  wmctrl -ic "$win" 2>/dev/null
  wait "$pid"; rc=$?
  codes["$rc"]=$(( ${codes["$rc"]:-0} + 1 ))
  if [ "$rc" -ge 128 ] || [ "$rc" -eq 139 ]; then
    crash_logs="$crash_logs $i"
    cp /tmp/exitcrash_out_$i.txt "/tmp/exitcrash_crash_$i.txt"
  fi
done
echo "=== 退出码分布(N=$N exe=$EXE) ==="
for k in "${!codes[@]}"; do echo "  rc=$k : ${codes[$k]} 次"; done
echo "崩溃日志(>=128)批次:$crash_logs"
