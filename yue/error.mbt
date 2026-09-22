// 结构化错误：把平台失败原因翻译成统一枚举，消费方 match 即可，无需探平台。

///|
pub(all) enum TrayError {
  /// 系统缺少托盘后端（Linux 未安装 AppIndicator 运行库）
  Unsupported
  /// 图标文件读取或解码失败
  IconLoadFailed
}

///|
pub impl Show for TrayError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("TrayError::Unsupported")
    IconLoadFailed => logger.write_string("TrayError::IconLoadFailed")
  }
}

///|
pub extend TrayError with Show::{to_string, output}

///|
pub(all) enum SingleInstanceError {
  /// 平台不支持（macOS 暂缓）
  Unsupported
  /// app_id 不合法（DBus 知名名规则：≥2 点分元素、元素以字母/下划线开头）
  InvalidAppId
  /// 后端不可用（Linux 连不上会话总线 / Windows 互斥体创建失败）
  BackendUnavailable
}

///|
pub impl Show for SingleInstanceError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("SingleInstanceError::Unsupported")
    InvalidAppId => logger.write_string("SingleInstanceError::InvalidAppId")
    BackendUnavailable => logger.write_string("SingleInstanceError::BackendUnavailable")
  }
}

///|
pub extend SingleInstanceError with Show::{to_string, output}

///|
pub(all) enum AutostartError {
  /// 平台不支持（macOS 暂缓）
  Unsupported
  /// app_id 不合法（与 SingleInstance 同规：DBus 知名名规则）
  InvalidAppId
  /// 取不到本进程可执行文件路径（/proc/self/exe 读取失败等）
  NoExecutablePath
  /// 文件或注册表读写失败，带原因
  IoFailed(String)
}

///|
pub impl Show for AutostartError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("AutostartError::Unsupported")
    InvalidAppId => logger.write_string("AutostartError::InvalidAppId")
    NoExecutablePath => logger.write_string("AutostartError::NoExecutablePath")
    IoFailed(reason) => logger.write_string("AutostartError::IoFailed(\{reason})")
  }
}

///|
pub extend AutostartError with Show::{to_string, output}

///|
pub(all) enum OpenUrlError {
  /// 平台不支持（macOS 暂缓）
  Unsupported
  /// 交给系统的 spawn 失败
  SpawnFailed
}

///|
pub impl Show for OpenUrlError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("OpenUrlError::Unsupported")
    SpawnFailed => logger.write_string("OpenUrlError::SpawnFailed")
  }
}

///|
pub extend OpenUrlError with Show::{to_string, output}

///|
pub(all) enum FileManagerError {
  /// 平台不支持（macOS 暂缓）
  Unsupported
  /// 回退 spawn 也失败
  SpawnFailed
}

///|
pub impl Show for FileManagerError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("FileManagerError::Unsupported")
    SpawnFailed => logger.write_string("FileManagerError::SpawnFailed")
  }
}

///|
pub extend FileManagerError with Show::{to_string, output}
