// 文件系统探测与环境变量：目录枚举与环境变量写删（fsx_ 前缀）。
// 作用范围都是当前进程：目录枚举真实读文件系统（存在才扫，打不开
// 报错）；环境变量只改本进程环境（之后 spawn 的子进程可见），不触碰
// 系统持久配置。C ABI 返回扁平文本（子项名 '\n' 分行），与本包多
// 字符串返回惯例一致（同 browser cookie / clipboard get_data 的编码）。

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
// 纯逻辑层：扁平文本解码（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 扁平文本（'\n' 分行）拆子项名数组，去空行。
fn fsx_decode_names(flat : Bytes) -> Array[String] {
  let out : Array[String] = []
  for line in from_utf8_bytes(flat).split("\n") {
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
  let flat = ffi_list_dir(utf8_bytes(path), ok)
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
  let r = ffi_set_env(
    utf8_bytes(name),
    utf8_bytes(value),
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
  let r = ffi_unset_env(utf8_bytes(name), ok)
  if r == 0 && ok.val == 1 {
    Ok(())
  } else {
    Err(EnvFailed(name))
  }
}
