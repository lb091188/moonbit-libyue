// 结构化错误：把平台失败原因翻译成统一枚举，消费方 match 即可，无需探平台。

///|
pub(all) enum TrayError {
  /// 系统缺少托盘后端（Linux 未安装 AppIndicator 运行库）
  Unsupported
  /// 图标文件读取或解码失败
  IconLoadFailed
}
