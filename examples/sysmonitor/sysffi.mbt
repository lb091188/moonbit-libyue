// sysmonitor FFI 层：extern "c" 声明（仅 native 目标编译）。
// 安全封装与纯函数解析在 sysdata.mbt / sysproc.mbt / syshw.mbt。
// Windows 侧 stub 为同 ABI 占位（返回「不支持」哨兵），封装层统一语义化。

///|
// 读整个文本文件；失败返回 None（C 侧 NULL 映射）。#borrow：C 仅在
// 调用期间读取 path，不存引用。
#borrow(path)
extern "c" fn ffi_read_text_file(path : Bytes) -> Bytes? = "yue_sysmon_read_text_file"

///|
// 列出 /proc 下全部 pid（换行分隔）；失败或平台不支持返回 None。
extern "c" fn ffi_list_pids() -> Bytes? = "yue_sysmon_list_pids"

///|
// kill(pid, sig)；成功返回 0，失败返回 errno（负数为「不支持」哨兵）。
extern "c" fn ffi_kill(pid : Int, sig : Int) -> Int = "yue_sysmon_kill"

///|
// getpriority(PRIO_PROCESS, pid)；成功写 out 并返回 0，失败返回 errno。
// nice = -1 是合法值，成败不能靠返回值歧义表达，故用出参。
#borrow(out)
extern "c" fn ffi_get_priority(pid : Int, out : Ref[Int]) -> Int = "yue_sysmon_get_priority"

///|
// setpriority(PRIO_PROCESS, pid, nice)；成功返回 0，失败返回 errno。
extern "c" fn ffi_set_priority(pid : Int, nice : Int) -> Int = "yue_sysmon_set_priority"

///|
extern "c" fn ffi_page_size() -> Int = "yue_sysmon_page_size"

///|
// USER_HZ：/proc 时间片的每秒 tick 数（Linux 通常 100）。
extern "c" fn ffi_clk_tck() -> Int = "yue_sysmon_clk_tck"

///|
// 单调时钟秒（CLOCK_MONOTONIC）；平台不支持时恒 0。
extern "c" fn ffi_monotonic() -> Double = "yue_sysmon_monotonic"

///|
// 列出目录条目名（跳过 . 与 ..），换行分隔；失败或平台不支持返回 None。
#borrow(path)
extern "c" fn ffi_list_dir(path : Bytes) -> Bytes? = "yue_sysmon_list_dir"

///|
// statvfs(path)：成功写 total/free/avail（字节）返回 0，失败返回 errno。
#borrow(path, out_total, out_free, out_avail)
extern "c" fn ffi_statvfs(
  path : Bytes,
  out_total : Ref[Int64],
  out_free : Ref[Int64],
  out_avail : Ref[Int64],
) -> Int = "yue_sysmon_statvfs"
