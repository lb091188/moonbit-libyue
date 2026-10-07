// 环境变量：读走 core/env（当前进程环境），写 / 删走 fsx 的
// [fsx_set_env] / [fsx_unset_env]（C 层 setenv / unsetenv）。语义为
// 「进程内生效」——读的是当前进程环境；写只改当前进程环境（之后 spawn
// 的子进程可见），不触碰系统持久配置，也不影响父进程。[envx_common]
// 汇总常用集合（PATH / HOME / LANG / SHELL / USER 固定读取加 XDG_*
// 前缀扫描，环境里存在才收入）。无文本解析，全部是真实环境读写，
// envx_wbtest.mbt 以本机真实环境覆盖存在性、读改写删环与错误分支。

///|
/// 环境变量操作错误（由 fsx 的 FsError 归一而来）。
pub(all) enum EnvxError {
  /// 参数非法（变量名为空串），带说明
  ExInvalidParam(String)
  /// 写 / 删被底层拒绝（变量名含 '=' 等），带变量名
  ExFailed(String)
}

///|
pub impl Show for EnvxError with fn output(self, logger) {
  match self {
    ExInvalidParam(m) => logger.write_string("EnvxError::ExInvalidParam(\{m})")
    ExFailed(n) => logger.write_string("EnvxError::ExFailed(\{n})")
  }
}

///|
pub extend EnvxError with Show::{to_string, output}

///|
/// [envx_common] 固定读取的常用变量名（XDG_* 另有前缀扫描，不在此列）。
let envx_common_names : Array[String] = [
  "PATH", "HOME", "LANG", "SHELL", "USER",
]

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 读环境变量值：不存在为 None（已存在但值为空串时返回 Some("")）。
pub fn envx_get(name : String) -> String? {
  @env.get_env_var(name)
}

///|
/// 写环境变量（覆盖写）：仅作用当前进程环境——本进程内后续 [envx_get]
/// 与本进程 spawn 的子进程可见，不影响父进程与系统持久配置。变量名为
/// 空串 → ExInvalidParam；名字含 '=' 等被底层拒绝 → ExFailed。
pub fn envx_set(name : String, value : String) -> Result[Unit, EnvxError] {
  match fsx_set_env(name, value, true) {
    Ok(_) => Ok(())
    Err(InvalidParam(m)) => Err(ExInvalidParam(m))
    Err(EnvFailed(n)) => Err(ExFailed(n))
    Err(_) => Err(ExFailed(name))
  }
}

///|
/// 删环境变量（幂等，本就不存在也视为成功）：仅作用当前进程环境，规则
/// 同 [envx_set]。变量名为空串 → ExInvalidParam。
pub fn envx_unset(name : String) -> Result[Unit, EnvxError] {
  match fsx_unset_env(name) {
    Ok(_) => Ok(())
    Err(InvalidParam(m)) => Err(ExInvalidParam(m))
    Err(EnvFailed(n)) => Err(ExFailed(n))
    Err(_) => Err(ExFailed(name))
  }
}

///|
/// 常用环境变量集合：固定名（PATH / HOME / LANG / SHELL / USER）逐个
/// 读，加全部 XDG_ 前缀变量的全环境扫描，环境里存在才收入（缺失的键
/// 不进结果）。键为变量名、值为变量值。
pub fn envx_common() -> Map[String, String] {
  let out : Map[String, String] = Map([])
  for name in envx_common_names {
    match envx_get(name) {
      Some(v) => out.set(name, v)
      None => ()
    }
  }
  for k, v in @env.get_env_vars().iter2() {
    if k.has_prefix("XDG_") && !out.contains(k) {
      out.set(k, v)
    }
  }
  out
}
