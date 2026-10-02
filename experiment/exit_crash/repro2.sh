#!/usr/bin/env bash
# 退出段错误复现器 v2:启动 → 激活窗口 → Tab 键把焦点移到可聚焦控件
# (entry/button)→ 关窗 → 记录退出码。
# 依据 adaptation.md:78:XTEST(不带 --window)才能让 GTK 收到键盘事件。
# 用法: repro2.sh <exe路径> <次数> <Tab次数>
set -u
EXE="$1"; N="${2:-10}"; TABS="${3:-2}"
declare -A codes
for i in $(seq 1 "$N"); do
  "$EXE" >/tmp/exitcrash2_out_$i.txt 2>&1 &
  pid=$!
  win=""
  for attempt in 1 2 3 4 5 6; do
    sleep 0.5
    win=$(wmctrl -lp 2>/dev/null | awk -v p="$pid" '$3==p {print $1; exit}')
    [ -n "$win" ] && break
  done
  if [ -z "$win" ]; then
    echo "[$i] 未找到窗口 pid=$pid"
    kill -9 "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
    codes["NO_WINDOW"]=$(( ${codes["NO_WINDOW"]:-0} + 1 ))
    continue
  fi
  wmctrl -ia "$win" 2>/dev/null   # 激活
  sleep 0.4
  for t in $(seq 1 "$TABS"); do xdotool key Tab; sleep 0.15; done
  sleep 0.2
  wmctrl -ic "$win" 2>/dev/null   # 关闭请求 → on_close → quit
  wait "$pid"; rc=$?
  codes["$rc"]=$(( ${codes["$rc"]:-0} + 1 ))
  if [ "$rc" -ne 0 ]; then
    echo "[$i] rc=$rc:"; tail -3 /tmp/exitcrash2_out_$i.txt
    cp /tmp/exitcrash2_out_$i.txt "/tmp/exitcrash2_crash_$i.txt"
  fi
done
echo "=== 退出码分布(N=$N tabs=$TABS exe=$EXE) ==="
for k in "${!codes[@]}"; do echo "  rc=$k : ${codes[$k]} 次"; done
