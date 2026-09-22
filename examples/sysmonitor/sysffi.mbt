// sysmonitor FFI 层：extern "c" 声明（仅 native 目标编译）。
// 安全封装与纯函数解析在 sysdata.mbt / sysproc.mbt / syshw.mbt。

///|
// 读整个文本文件；失败返回 None（C 侧 NULL 映射）。#borrow：C 仅在
// 调用期间读取 path，不存引用。
#borrow(path)
extern "c" fn ffi_read_text_file(path : Bytes) -> Bytes? = "yue_sysmon_read_text_file"
