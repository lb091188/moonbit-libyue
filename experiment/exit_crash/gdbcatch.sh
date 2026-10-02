#!/usr/bin/env bash
# gdb 循环抓退出段错误栈:跑 prode_exit(主动 quit 路径),SIGSEGV 停住打全栈。
set -u
EXE="${1:-/home/lkyh/ownCode/moonbit-libyue/_build/native/debug/build/experiment/exit_crash/probe_exit/probe_exit.exe}"
MAX="${2:-30}"
for i in $(seq 1 "$MAX"); do
  timeout 60 gdb -batch \
    -ex 'set pagination off' -ex 'set disable-randomization off' \
    -ex 'handle SIGSEGV stop print' \
    -ex run \
    -ex 'printf "=== CRASH ===\n"' \
    -ex 'bt 40' \
    -ex 'info registers rip' \
    --args "$EXE" >"/tmp/gdbcrash_$i.txt" 2>&1
  if grep -q "=== CRASH ===" "/tmp/gdbcrash_$i.txt" && grep -q "SIGSEGV" "/tmp/gdbcrash_$i.txt"; then
    echo "[$i] 崩溃,日志 /tmp/gdbcrash_$i.txt"
    exit 0
  fi
done
echo "未抓到崩溃"
exit 1
