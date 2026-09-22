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
