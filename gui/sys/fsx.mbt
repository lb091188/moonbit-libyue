// 文件系统探测与环境变量（sys 线，与 master 的 yue/fsx.mbt 同源平移）：
// 目录枚举与环境变量写删（fsx_ 前缀）。作用范围都是当前进程：目录
// 枚举真实读文件系统（存在才扫，打不开报错）；环境变量只改本进程
// 环境（之后 spawn 的子进程可见），不触碰系统持久配置。C ABI 返回
// 扁平文本（子项名 '\n' 分行），桩在 sys_stub.c（标准头直走
// native-stub）。

///|
pub(all) enum FsError {
  /// 参数非法（路径/变量名为空），带说明
  InvalidParam(String)
  /// 目录打不开（不存在/非目录/无权限），带路径
  OpenFailed(String)
  /// 环境变量操作失败（名字含 '=' 等，C 层拒绝），带变量名
  EnvFailed(String)
}

///|
pub impl Show for FsError with fn output(self, logger) {
  match self {
    InvalidParam(m) => logger.write_string("FsError::InvalidParam(\{m})")
    OpenFailed(p) => logger.write_string("FsError::OpenFailed(\{p})")
    EnvFailed(n) => logger.write_string("FsError::EnvFailed(\{n})")
  }
}

///|
pub extend FsError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// FFI（桩：sys_stub.c）
// ---------------------------------------------------------------------------

///|
#borrow(path, ok)
extern "c" fn ffi_sys_list_dir(path : Bytes, ok : Ref[Int]) -> Bytes = "yue_sys_list_dir"

///|
#borrow(name, value, ok)
extern "c" fn ffi_sys_set_env(
  name : Bytes,
  value : Bytes,
  overwrite : Int,
  ok : Ref[Int],
) -> Int = "yue_sys_setenv"

///|
#borrow(name, ok)
extern "c" fn ffi_sys_unset_env(name : Bytes, ok : Ref[Int]) -> Int = "yue_sys_unsetenv"

// ---------------------------------------------------------------------------
// 纯逻辑层：扁平文本解码（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 扁平文本（'\n' 分行）拆子项名数组，去空行。
fn fsx_decode_names(flat : Bytes) -> Array[String] {
  let out : Array[String] = []
  for line in @utf8.decode_lossy(flat).split("\n") {
    if line.length() > 0 {
      out.push(line.to_owned())
    }
  }
  out
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 枚举目录子项名（不含 . ..，不做递归，含隐藏项）。
/// 目录打不开（不存在/非目录/无权限）为 OpenFailed；路径为空串为
/// InvalidParam。子项名本身含 '\n' 的极端文件名会被拆开（扁平文本
/// 编码的已知边界，与既有 cookie 等编码一致）。
pub fn fsx_list_dir(path : String) -> Result[Array[String], FsError] {
  if path == "" {
    return Err(InvalidParam("路径为空"))
  }
  let ok = Ref(0)
  let flat = ffi_sys_list_dir(@utf8.encode(path), ok)
  if ok.val == 1 {
    Ok(fsx_decode_names(flat))
  } else {
    Err(OpenFailed(path))
  }
}

///|
/// 写环境变量：overwrite=false 且变量已存在时保持原值（仍为 Ok）。
/// 变量名为空串为 InvalidParam；名字含 '=' 等被 C 层拒绝时为
/// EnvFailed。仅作用当前进程环境。
pub fn fsx_set_env(
  name : String,
  value : String,
  overwrite : Bool,
) -> Result[Unit, FsError] {
  if name == "" {
    return Err(InvalidParam("变量名为空"))
  }
  let ok = Ref(0)
  let r = ffi_sys_set_env(
    @utf8.encode(name),
    @utf8.encode(value),
    if overwrite {
      1
    } else {
      0
    },
    ok,
  )
  if r == 0 && ok.val == 1 {
    Ok(())
  } else {
    Err(EnvFailed(name))
  }
}

///|
/// 删环境变量：本就不存在也视为成功（幂等）。变量名为空串为
/// InvalidParam；C 层拒绝时为 EnvFailed。仅作用当前进程环境。
pub fn fsx_unset_env(name : String) -> Result[Unit, FsError] {
  if name == "" {
    return Err(InvalidParam("变量名为空"))
  }
  let ok = Ref(0)
  let r = ffi_sys_unset_env(@utf8.encode(name), ok)
  if r == 0 && ok.val == 1 {
    Ok(())
  } else {
    Err(EnvFailed(name))
  }
}

// ---------------------------------------------------------------------------
// 文本文件读 / 删（procrun 等模块共用的薄 FFI；桩：sys_stub.c）
// ---------------------------------------------------------------------------

///|
#borrow(path, ok)
extern "c" fn ffi_sys_read_text_file(path : Bytes, ok : Ref[Int]) -> Bytes = "yue_sys_read_text_file"

///|
#borrow(path, ok)
extern "c" fn ffi_sys_remove_file(path : Bytes, ok : Ref[Int]) -> Int = "yue_sys_remove_file"

extern "c" fn ffi_sys_platform() -> Int = "yue_sys_platform"

///|
/// 平台标识（桩编译期判定）："linux" / "windows" / "macos"。
pub fn sys_platform() -> String {
  match ffi_sys_platform() {
    1 => "windows"
    2 => "macos"
    _ => "linux"
  }
}

///|
/// 读文本文件全文（UTF-8 解码，损失式）；打不开（不存在/无权限）为
/// None。二进制读整段，文件含 NUL 时 NUL 之后的字节保留在返回串里
/// （decode_lossy 语义）。
pub fn sys_read_text_file(path : String) -> String? {
  if path == "" {
    return None
  }
  let ok = Ref(0)
  let data = ffi_sys_read_text_file(@utf8.encode(path), ok)
  if ok.val == 1 {
    Some(@utf8.decode_lossy(data))
  } else {
    None
  }
}

///|
/// 读文件原始字节（同 [sys_read_text_file] 的读盘路径，不做解码）：
/// SQLite 库这类二进制文件要走这条入口——文本版遇 NUL 之后的内容虽保留，
/// 但按码点重排过，字节序不可依赖。
pub fn sys_read_bytes_file(path : String) -> Bytes? {
  if path == "" {
    return None
  }
  let ok = Ref(0)
  let data = ffi_sys_read_text_file(@utf8.encode(path), ok)
  if ok.val == 1 { Some(data) } else { None }
}

///|
/// 删文件（幂等：本就不存在也算成功）。
pub fn sys_remove_file(path : String) -> Bool {
  if path == "" {
    return false
  }
  let ok = Ref(0)
  let _ = ffi_sys_remove_file(@utf8.encode(path), ok)
  ok.val == 1
}

///|
/// C 层 getenv（进程实时环境——core/env 的表在部分实现里是启动快照，
/// setenv 后读不到；此入口反映进程内写删的最新状态，测试与需要
/// 「写后立即可见」语义的调用方用）。
#borrow(name, ok)
extern "c" fn ffi_sys_getenv(name : Bytes, ok : Ref[Int]) -> Bytes = "yue_sys_getenv"

///|
/// 读环境变量原文（进程实时环境）；不存在为 None。
pub fn sys_getenv(name : String) -> String? {
  if name == "" {
    return None
  }
  let ok = Ref(0)
  let v = ffi_sys_getenv(@utf8.encode(name), ok)
  if ok.val == 1 {
    Some(@utf8.decode_lossy(v))
  } else {
    None
  }
}

///|
#borrow(path, data, ok)
extern "c" fn ffi_sys_write_text_file(
  path : Bytes,
  data : Bytes,
  ok : Ref[Int],
) -> Int = "yue_sys_write_text_file"

///|
/// 写文本文件全文（存在覆盖，不存在新建；父目录须已存在）。
pub fn sys_write_text_file(path : String, text : String) -> Bool {
  if path == "" {
    return false
  }
  let ok = Ref(0)
  let _ = ffi_sys_write_text_file(@utf8.encode(path), @utf8.encode(text), ok)
  ok.val == 1
}

///|
/// 逐级创建目录（已存在的每一层都算成功）。`sys_write_text_file` 不会顺手
/// 建父目录，所以要先建目录再写；少了这一步时症状是「写的文件根本不在」，
/// 而不是「目录不存在」。
///
/// 纯 MoonBit 实现：调系统 `mkdir -p` 子进程（见 `pr_run`），所以只在
/// `pr_available()` 为真的平台上可能成功；调用方要区分「建不了」与
/// 「本平台没有子进程通道」时先探测。
pub fn sys_make_dirs(path : String) -> Bool {
  if path == "" {
    return false
  }
  match pr_run("mkdir", ["-p", path]) {
    Ok(_) => true
    Err(_) => false
  }
}
