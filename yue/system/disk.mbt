// 磁盘卷管理：枚举可挂载卷、挂载与卸载。Linux 优先走 udisks2 D-Bus
// （系统总线 org.freedesktop.UDisks2：Manager 列块设备、Block 取设备/
// 卷标/容量/可移动、Filesystem 的 Mount/Unmount）；udisks2 不在线时回退
// `lsblk --json` 子进程输出解析（经 procrun 的 pr_run 执行，仅枚举）。
// D-Bus 观测形状解析（Manager 应答、GetAll 属性字典含 aay 型挂载点）与
// lsblk JSON 文本解析都是纯函数，disk_wbtest.mbt 以真实输出样例白盒覆盖。
//
// 典型用法：
//   match dsk_volumes() {
//     Ok(vols) =>
//       for v in vols if v.removable && v.mountpoint is None {
//         let _ = dsk_mount(v) // 挂载后 mountpoint 即有值
//       }
//     Err(DiskError::Unsupported) => () // 无 udisks2 也无 lsblk
//     Err(e) => ()
//   }

///|
/// 单个可挂载卷的快照：device 为块设备文件（如 /dev/sda1），label 为卷标
/// （无卷标为空串），mountpoint 为已挂载路径（未挂载为 None），size_bytes
/// 为容量（字节），removable 指示可移动介质（U 盘/SD 卡 vs 内置盘），
/// path 为 udisks2 对象路径（lsblk 路线取不到为空串；供挂载/卸载内部
/// 定位，UI 展示用 device 即可）。
pub(all) struct DskVolume {
  device : String
  label : String
  mountpoint : String?
  size_bytes : Int64
  removable : Bool
  path : String
}

///|
pub impl Show for DskVolume with fn output(self, logger) {
  logger.write_string("DskVolume { device: ")
  logger.write_string(self.device)
  logger.write_string(", label: ")
  logger.write_string(self.label)
  logger.write_string(", mountpoint: ")
  match self.mountpoint {
    Some(p) => logger.write_string(p)
    None => logger.write_string("None")
  }
  logger.write_string(", size_bytes: ")
  logger.write_string(self.size_bytes.to_string())
  logger.write_string(", removable: ")
  logger.write_string(self.removable.to_string())
  logger.write_string(", path: ")
  logger.write_string(self.path)
  logger.write_string(" }")
}

///|
pub extend DskVolume with Show::{to_string, output}

///|
pub(all) enum DiskError {
  /// 平台/后端不支持（非 Linux；udisks2 不在线且 lsblk 命令不可用）
  Unsupported
  /// D-Bus 调用失败（udisks2 拒绝/应答超时等），带错误名与说明
  BusFailed(String)
  /// 命令执行失败（spawn 失败 / 非零退出码 / 超时 / 被信号终止）
  CommandFailed(String)
  /// 工具输出解析失败，带原文
  ParseFailed(String)
  /// 卷参数非法（设备文件名为空或不是 /dev/ 路径），带说明
  InvalidParam(String)
  /// 卷未挂载（卸载时）
  NotMounted(String)
  /// 卷已挂载（挂载时）
  AlreadyMounted(String)
}

///|
pub impl Show for DiskError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("DiskError::Unsupported")
    BusFailed(m) => logger.write_string("DiskError::BusFailed(\{m})")
    CommandFailed(m) => logger.write_string("DiskError::CommandFailed(\{m})")
    ParseFailed(m) => logger.write_string("DiskError::ParseFailed(\{m})")
    InvalidParam(m) => logger.write_string("DiskError::InvalidParam(\{m})")
    NotMounted(m) => logger.write_string("DiskError::NotMounted(\{m})")
    AlreadyMounted(m) => logger.write_string("DiskError::AlreadyMounted(\{m})")
  }
}

///|
pub extend DiskError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 常量与后端探测
// ---------------------------------------------------------------------------

///|
/// udisks2 服务名与 Manager 对象路径。
let dsk_dest : String = "org.freedesktop.UDisks2"

///|
let dsk_root : String = "/org/freedesktop/UDisks2/Manager"

///|
let dsk_iface_manager : String = "org.freedesktop.UDisks2.Manager"

///|
let dsk_iface_block : String = "org.freedesktop.UDisks2.Block"

///|
let dsk_iface_filesystem : String = "org.freedesktop.UDisks2.Filesystem"

///|
let dsk_dbus_props : String = "org.freedesktop.DBus.Properties"

///|
/// 卷管理后端（内部探测结果）：枚举与挂载/卸载能力以 udisks2 D-Bus 为准，
/// lsblk 只提供枚举回退。
priv enum DskBackend {
  Udisks
  Lsblk
}

///|
/// D-Bus 错误名与说明 → DiskError：udisks2 服务不在线 / 总线不可达视为
/// Unsupported（等价于无此后端），其余（拒绝/超时/编码失败）为 BusFailed。
/// 入参拆成两项而非收 GDBusError 记录——映射是纯函数，白盒可直接喂样例。
fn dsk_bus_err(name : String, message : String) -> DiskError {
  if name == "org.freedesktop.DBus.Error.ServiceUnknown" || name == "gdbus.io" {
    Unsupported
  } else {
    BusFailed("\{name}: \{message}")
  }
}

///|
/// 挂载/卸载动作的错误名与说明 → DiskError：udisks2 的 AlreadyMounted /
/// NotMounted 给专属错误，其余同 [dsk_bus_err]。
fn dsk_action_err(name : String, message : String) -> DiskError {
  match name {
    "org.freedesktop.UDisks2.Error.AlreadyMounted" => AlreadyMounted(message)
    "org.freedesktop.UDisks2.Error.NotMounted" => NotMounted(message)
    _ => dsk_bus_err(name, message)
  }
}

///|
/// 系统总线守护名（NameHasOwner 的调用对象）。
let dsk_bus_daemon : String = "org.freedesktop.DBus"

///|
/// 系统总线守护对象路径。
let dsk_bus_daemon_path : String = "/org/freedesktop/DBus"

///|
/// udisks2 是否在系统总线上在线（系统总线守护的 NameHasOwner 真实探测，
/// 被查名是 udisks2）。每次调用真实探测，高频场景请调用方自行缓存结果。
fn dsk_udisks_available() -> Bool {
  if @yue.platform() != "linux" {
    return false
  }
  match
    @traybus.gdbus_call_system(
      dsk_bus_daemon,
      dsk_bus_daemon_path,
      dsk_bus_daemon,
      "NameHasOwner",
      [@traybus.GVString(dsk_dest)],
    ) {
    Ok(@traybus.GVBool(true)) => true
    _ => false
  }
}

///|
/// 后端探测：D-Bus（udisks2 在线）优先，否则 lsblk 命令；都没有为 None。
fn dsk_probe() -> DskBackend? {
  if dsk_udisks_available() {
    Some(Udisks)
  } else if dsk_lsblk_available() {
    Some(Lsblk)
  } else {
    None
  }
}

// ---------------------------------------------------------------------------
// 纯函数层：D-Bus 观测形状解析（Manager 应答 / GetAll 属性字典；不连总线，
// 样例值取自 gdbus 应答的真实线协议折叠形状）
// ---------------------------------------------------------------------------

///|
/// 属性字典取字符串：普通字符串与对象路径直取，D-Bus 字节串（udisks 的
/// Device 等 'ay' 型属性）按 UTF-8 解码；缺属性或类型不符为空串。
fn dsk_prop_str(
  props : Map[String, @traybus.GDBusValue],
  key : String,
) -> String {
  match props.get(key) {
    Some(@traybus.GVString(s)) => s
    Some(@traybus.GVPath(s)) => s
    Some(v) => dsk_byte_array_text(v)
    None => ""
  }
}

///|
/// 属性字典取布尔值（类型不符或缺属性为 default）。
fn dsk_prop_bool(
  props : Map[String, @traybus.GDBusValue],
  key : String,
  default : Bool,
) -> Bool {
  match props.get(key) {
    Some(@traybus.GVBool(b)) => b
    _ => default
  }
}

///|
/// 属性字典取无符号 64 位整数（udisks 的 Size/Time 为 't'；其它整型按
/// 宽度换算）。
fn dsk_prop_u64(
  props : Map[String, @traybus.GDBusValue],
  key : String,
) -> Int64? {
  match props.get(key) {
    Some(@traybus.GVU64(n)) => Some(n)
    Some(@traybus.GVInt64(n)) => Some(n)
    Some(@traybus.GVUInt32(n)) => Some(n.to_int64())
    Some(@traybus.GVInt32(n)) => Some(n.to_int64())
    _ => None
  }
}

///|
/// D-Bus 字节串（"y" 数组元素） → 文本：NUL 结尾符不计（udisks 的 aay
/// 挂载点是 NUL 结尾串）；非法形状与空串为空串。
fn dsk_byte_array_text(v : @traybus.GDBusValue) -> String {
  match v {
    @traybus.GVArray("y", items) => {
      let bytes : Array[Byte] = []
      for it in items {
        match it {
          @traybus.GVInt32(b) => if b > 0 { bytes.push((b & 255).to_byte()) }
          _ => ()
        }
      }
      @utf8.decode_lossy(Bytes::makei(bytes.length(), fn(i) { bytes[i] }))
    }
    _ => ""
  }
}

///|
/// Filesystem.MountPoints（aay） → 首个非空挂载点；未挂载或属性缺失为
/// None（多挂载点卷取首个）。
fn dsk_first_mountpoint(fs : Map[String, @traybus.GDBusValue]) -> String? {
  match fs.get("MountPoints") {
    Some(@traybus.GVArray(_, items)) => {
      let found : String? = for it in items {
        let text = dsk_byte_array_text(it)
        if text != "" {
          break Some(text)
        }
      } nobreak {
        None
      }
      found
    }
    _ => None
  }
}

///|
/// Manager.GetBlockDevices 应答（ao） → 块设备对象路径列表；非路径元素
/// 安全跳过，总返回合法子集。
fn dsk_paths_of_reply(v : @traybus.GDBusValue) -> Array[String] {
  let out : Array[String] = []
  match v {
    @traybus.GVArray(_, items) =>
      for it in items {
        match it {
          @traybus.GVPath(p) => out.push(p)
          _ => ()
        }
      }
    _ => ()
  }
  out
}

///|
/// （对象路径, Block 属性, Filesystem 属性） → 卷快照。Filesystem 属性由
/// 调用方先取：无该接口（无文件系统的整盘/RAID 成员等）不建卷。
fn dsk_volume_from(
  path : String,
  block : Map[String, @traybus.GDBusValue],
  fs : Map[String, @traybus.GDBusValue],
) -> DskVolume? {
  let device = dsk_prop_str(block, "Device")
  if device == "" {
    return None
  }
  let size = match dsk_prop_u64(block, "Size") {
    Some(v) => v
    None => 0L
  }
  Some({
    device,
    label: dsk_prop_str(block, "IdLabel"),
    mountpoint: dsk_first_mountpoint(fs),
    size_bytes: size,
    removable: dsk_prop_bool(block, "Removable", false),
    path,
  })
}

// ---------------------------------------------------------------------------
// 纯函数层：lsblk JSON 解析（--json 输出 → 卷列表）
// ---------------------------------------------------------------------------

///|
/// lsblk 数值字段（--bytes 输出为 JSON number） → Int64；非数值与非正数为
/// 0。
fn dsk_json_size(v : Json?) -> Int64 {
  match v {
    Some(Json::Number(n, ..)) => if n > 0.0 { n.to_int64() } else { 0L }
    _ => 0L
  }
}

///|
/// lsblk 字符串字段（无卷标时 lsblk 输出 JSON null，按空串处理）。
fn dsk_json_str(v : Json?) -> String {
  match v {
    Some(Json::String(s)) => s
    _ => ""
  }
}

///|
/// 容器型文件系统判定：swap、LVM/RAID/LUKS 成员、zfs 成员这些自身不是可
/// 挂载卷（其上是逻辑卷/映射设备或只是保留区），枚举时跳过。
fn dsk_fstype_is_container(fstype : String) -> Bool {
  fstype == "swap" ||
  fstype == "LVM2_member" ||
  fstype == "crypto_LUKS" ||
  fstype == "linux_raid_member" ||
  fstype == "zfs_member"
}

///|
/// 单个 lsblk 块设备对象 → 卷；无文件系统、容器型文件系统、loop 镜像、
/// 带 children 的整盘均跳过（返回 None，children 由递归单独处理）。
fn dsk_lsblk_volume(m : Map[String, Json]) -> DskVolume? {
  let fstype = dsk_json_str(m.get("fstype"))
  if fstype == "" {
    return None
  }
  if dsk_fstype_is_container(fstype) {
    return None
  }
  match m.get("type") {
    Some(Json::String(t)) => if t == "loop" { return None }
    _ => ()
  }
  match m.get("children") {
    Some(Json::Array(kids)) =>
      if kids.length() > 0 {
        return None // 整盘：卷在 children 里
      }
    _ => ()
  }
  let device = dsk_json_str(m.get("name"))
  if device == "" {
    return None
  }
  let mps = match m.get("mountpoints") {
    Some(Json::Array(arr)) => arr
    _ => []
  }
  let mountpoint : String? = for p in mps {
    match p {
      Json::String(s) => if s != "" { break Some(s) }
      _ => continue
    }
  } nobreak {
    None
  }
  Some({
    device,
    label: dsk_json_str(m.get("label")),
    mountpoint,
    size_bytes: dsk_json_size(m.get("size")),
    removable: match m.get("rm") {
      Some(Json::True) => true
      _ => false
    },
    path: "",
  })
}

///|
/// 递归收集一个块设备对象（含其 children）中的卷。
fn dsk_lsblk_collect(dev : Json, out : Array[DskVolume]) -> Unit {
  match dev {
    Json::Object(m) => {
      match dsk_lsblk_volume(m) {
        Some(v) => out.push(v)
        None => ()
      }
      match m.get("children") {
        Some(Json::Array(kids)) =>
          for k in kids {
            dsk_lsblk_collect(k, out)
          }
        _ => ()
      }
    }
    _ => ()
  }
}

///|
/// `lsblk --paths --json --bytes ...` 输出 → 卷列表。顶层 blockdevices
/// 逐个深入 children（分区/LV 都在 children 里）。
fn dsk_parse_lsblk(text : String) -> Result[Array[DskVolume], DiskError] {
  let root = @json.parse(text) catch {
    _ => return Err(ParseFailed("lsblk 输出不是合法 JSON"))
  }
  let devices = match root {
    Json::Object(m) =>
      match m.get("blockdevices") {
        Some(Json::Array(arr)) => arr
        _ => []
      }
    _ => []
  }
  if devices.length() == 0 {
    return Err(ParseFailed("lsblk 输出缺少 blockdevices 数组"))
  }
  let out : Array[DskVolume] = []
  for dev in devices {
    dsk_lsblk_collect(dev, out)
  }
  Ok(out)
}

// ---------------------------------------------------------------------------
// 命令执行封装（复用 procrun 的 pr_run：spawn → 限时回收 → 读临时文件输出）
// ---------------------------------------------------------------------------

///|
/// 运行命令并捕获标准输出：底层走 [pr_run]，把非零退出还原为
/// (退出码, stdout) 正常返回（工具不存在以 127 呈现，由调用方判码），
/// 其余错误映射为 DiskError。
fn dsk_run_capture(
  prog : String,
  args : Array[String],
  timeout_ms? : Int = 4000,
) -> Result[(Int, String), DiskError] {
  match pr_run(prog, args, timeout_ms~) {
    Ok(o) => Ok((o.exit_code, o.stdout))
    Err(NonZeroExit(code, _)) => Ok((code, ""))
    Err(Timeout(m)) => Err(CommandFailed(m))
    Err(SpawnFailed(m)) => Err(CommandFailed(m))
    Err(Signaled(sig)) => Err(CommandFailed("\{prog}: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(CommandFailed("\{prog}: 子进程执行不可用"))
  }
}

///|
/// lsblk 命令是否可用（--version 退出码 0 即存在）。每次调用真实探测。
fn dsk_lsblk_available() -> Bool {
  match dsk_run_capture("lsblk", ["--version"], timeout_ms=2000) {
    Ok((0, _)) => true
    _ => false
  }
}

///|
/// lsblk 参数表：--paths 给全设备路径、--bytes 给原始字节容量、
/// --json 给可解析输出；显式列只取需要的字段（--fs 会把默认列整组换掉，
/// 显式 -o 列不受影响）。
fn dsk_lsblk_args() -> Array[String] {
  [
    "--paths", "--json", "--bytes", "--fs", "-o", "NAME,TYPE,RM,SIZE,MOUNTPOINTS,FSTYPE,LABEL",
  ]
}

// ---------------------------------------------------------------------------
// D-Bus 调用（真实查询；wbtest 不连总线）
// ---------------------------------------------------------------------------

///|
/// Manager.GetBlockDevices 的全部块设备对象路径（应答签名 ao）。udisks2
/// 2.10 起该方法要 a{sv} 位置参数，传空 options。
fn dsk_block_paths() -> Result[Array[String], DiskError] {
  match
    @traybus.gdbus_call_system(
      dsk_dest,
      dsk_root,
      dsk_iface_manager,
      "GetBlockDevices",
      [@traybus.GVDict(Map([]))],
    ) {
    Ok(v) => Ok(dsk_paths_of_reply(v))
    Err(e) => Err(dsk_bus_err(e.name, e.message))
  }
}

///|
/// Properties.GetAll 的属性字典；接口不存在（该设备无此接口）或调用失败
/// 为 None。
fn dsk_props(
  path : String,
  iface : String,
) -> Map[String, @traybus.GDBusValue]? {
  match
    @traybus.gdbus_call_system(dsk_dest, path, dsk_dbus_props, "GetAll", [
      @traybus.GVString(iface),
    ]) {
    Ok(@traybus.GVDict(props)) => Some(props)
    _ => None
  }
}

///|
/// 设备文件 → udisks2 对象路径（Manager.ResolveDevice，devspec 按
/// {"path": <设备文件>} 入参；设备文件不被 udisks2 识别给 BusFailed）。
fn dsk_resolve_path(device : String) -> Result[String, DiskError] {
  let devspec : Map[String, @traybus.GDBusValue] = Map([])
  devspec.set("path", @traybus.GVString(device))
  match
    @traybus.gdbus_call_system(
      dsk_dest,
      dsk_root,
      dsk_iface_manager,
      "ResolveDevice",
      [@traybus.GVDict(devspec), @traybus.GVDict(Map([]))],
    ) {
    Ok(v) =>
      match dsk_paths_of_reply(v) {
        [] => Err(BusFailed("ResolveDevice: udisks2 不认识设备 \{device}"))
        [first, ..] => Ok(first)
      }
    Err(e) => Err(dsk_bus_err(e.name, e.message))
  }
}

///|
/// Filesystem 接口的挂载/卸载动作（无位置参数，仅空 options；成功无
/// 返回值）。
fn dsk_fs_action(path : String, action : String) -> Result[Unit, DiskError] {
  match
    @traybus.gdbus_call_system(dsk_dest, path, dsk_iface_filesystem, action, [
      @traybus.GVDict(Map([])),
    ]) {
    Ok(_) => Ok(())
    Err(e) => Err(dsk_action_err(e.name, e.message))
  }
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 当前系统是否支持磁盘卷管理：udisks2 在线（完整能力）或 lsblk 命令可用
/// （仅枚举）。每次调用真实探测，高频场景请调用方自行缓存结果。
pub fn dsk_supported() -> Bool {
  dsk_probe() is Some(_)
}

///|
/// 枚举可挂载卷（device/label/mountpoint/size_bytes/removable）。探测
/// 优先级：udisks2 D-Bus 通 → 用 D-Bus；否则回退 lsblk 输出解析。系统无
/// 任何卷（台式机）返回 Ok(空列表)。
pub fn dsk_volumes() -> Result[Array[DskVolume], DiskError] {
  match dsk_probe() {
    None => Err(Unsupported)
    Some(Udisks) => dsk_volumes_udisks()
    Some(Lsblk) => dsk_volumes_lsblk()
  }
}

///|
/// udisks2 路线：Manager 列块设备，每设备取 Block + Filesystem 两组
/// GetAll，有 Filesystem 接口（即有文件系统的可挂载卷）才收录。
fn dsk_volumes_udisks() -> Result[Array[DskVolume], DiskError] {
  match dsk_block_paths() {
    Err(e) => Err(e)
    Ok(paths) => {
      let out : Array[DskVolume] = []
      for path in paths {
        match dsk_props(path, dsk_iface_block) {
          Some(block) =>
            match dsk_props(path, dsk_iface_filesystem) {
              Some(fs) =>
                match dsk_volume_from(path, block, fs) {
                  Some(v) => out.push(v)
                  None => ()
                }
              None => ()
            }
          None => ()
        }
      }
      Ok(out)
    }
  }
}

///|
/// lsblk 路线：跑真命令解析输出（仅枚举，无挂载/卸载能力）。
fn dsk_volumes_lsblk() -> Result[Array[DskVolume], DiskError] {
  match dsk_run_capture("lsblk", dsk_lsblk_args(), timeout_ms=4000) {
    Err(e) => Err(e)
    Ok((0, out)) => dsk_parse_lsblk(out)
    Ok((code, _)) => Err(CommandFailed("lsblk: 退出码 \{code}"))
  }
}

///|
/// 卷参数校验：device 非空且是 /dev/ 路径（挂载/卸载的总线定位用）。
fn dsk_check_volume(volume : DskVolume) -> Result[String, DiskError] {
  if volume.device == "" {
    return Err(InvalidParam("卷设备文件名为空"))
  }
  if !volume.device.has_prefix("/dev/") {
    return Err(
      InvalidParam("卷设备文件名不是 /dev/ 路径: \{volume.device}"),
    )
  }
  Ok(volume.device)
}

///|
/// 挂载/卸载所用 udisks2 对象路径：卷自带 path（D-Bus 路线枚举所得）直接
/// 用，否则（lsblk 路线或手工构造）按设备文件 ResolveDevice 定位。
fn dsk_action_path(
  volume : DskVolume,
  device : String,
) -> Result[String, DiskError] {
  if volume.path != "" {
    return Ok(volume.path)
  }
  dsk_resolve_path(device)
}

///|
/// 挂载/卸载公共流程：校验卷 → 取对象路径 → Filesystem 接口动作。
fn dsk_fs_apply(volume : DskVolume, action : String) -> Result[Unit, DiskError] {
  match dsk_check_volume(volume) {
    Err(e) => Err(e)
    Ok(device) =>
      match dsk_action_path(volume, device) {
        Err(e) => Err(e)
        Ok(path) => dsk_fs_action(path, action)
      }
  }
}

///|
/// 挂载卷（udisks2 在系统总线上 Filesystem.Mount；不可用时返回
/// Unsupported）。已挂载返回 AlreadyMounted。
pub fn dsk_mount(volume : DskVolume) -> Result[Unit, DiskError] {
  dsk_fs_apply(volume, "Mount")
}

///|
/// 卸载卷（Filesystem.Unmount）。未挂载返回 NotMounted。
pub fn dsk_unmount(volume : DskVolume) -> Result[Unit, DiskError] {
  dsk_fs_apply(volume, "Unmount")
}
