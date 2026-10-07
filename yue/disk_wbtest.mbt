// 磁盘卷模块白盒测试：udisks2 D-Bus 观测形状解析（GetBlockDevices 应答、
// Block/Filesystem GetAll 属性字典含 aay 挂载点）+ lsblk --json 真实输出
// 解析 + 后端路由与错误映射。样例值取自 gdbus/lsblk 在本机（Ubuntu 24.04
// XFCE）的真实应答形状；真机只读冒烟（枚举/探测）在无后端时跳过，挂载/
// 卸载属设置类动作不执行。

///|
/// GVDBus 字节数组（"y" 型）快捷构造：Int 列表 → GVArray("y", GVInt32...)。
fn dsk_yb(bytes : Array[Int]) -> @traybus.GDBusValue {
  let items : Array[@traybus.GDBusValue] = []
  for b in bytes {
    items.push(@traybus.GVInt32(b))
  }
  @traybus.GVArray("y", items)
}

///|
/// Block/Filesystem GetAll 属性字典快捷构造：(键, 值) 列表 → Map。
fn dsk_props_of(
  pairs : Array[(String, @traybus.GDBusValue)],
) -> Map[String, @traybus.GDBusValue] {
  let m : Map[String, @traybus.GDBusValue] = Map([])
  for pair in pairs {
    let (k, v) = pair
    m.set(k, v)
  }
  m
}

///|
test "dsk_paths_of_reply：GetBlockDevices 真实应答形状（ao）" {
  let reply = @traybus.GVArray("o", [
    @traybus.GVPath("/org/freedesktop/UDisks2/block_devices/nvme0n1p2"),
    @traybus.GVPath("/org/freedesktop/UDisks2/block_devices/sda1"),
  ])
  assert_eq(dsk_paths_of_reply(reply).length(), 2)
  assert_eq(
    dsk_paths_of_reply(reply)[0],
    "/org/freedesktop/UDisks2/block_devices/nvme0n1p2",
  )
  // 非路径元素安全跳过；畸形应答给空列表
  let mixed = @traybus.GVArray("o", [
    @traybus.GVPath("/a"),
    @traybus.GVString("not-a-path"),
  ])
  assert_eq(dsk_paths_of_reply(mixed), ["/a"])
  assert_eq(dsk_paths_of_reply(@traybus.GVString("garbage")), [])
  assert_eq(dsk_paths_of_reply(@traybus.GVNone), [])
}

///|
test "dsk_byte_array_text：aay 元素（NUL 结尾串）转文本" {
  // "/data\0"：挂载点是 NUL 结尾字节串，结尾符不进文本
  assert_eq(dsk_byte_array_text(dsk_yb([47, 100, 97, 116, 97, 0])), "/data")
  // 多字节 UTF-8 挂载点（中文卷标目录）
  assert_eq(
    dsk_byte_array_text(dsk_yb([47, 230, 149, 176, 230, 141, 174, 0])),
    "/数据",
  )
  // 空数组 / 全 NUL / 非法形状都为空串
  assert_eq(dsk_byte_array_text(dsk_yb([])), "")
  assert_eq(dsk_byte_array_text(dsk_yb([0])), "")
  assert_eq(dsk_byte_array_text(@traybus.GVString("/data")), "")
  assert_eq(dsk_byte_array_text(@traybus.GVNone), "")
}

///|
test "dsk_first_mountpoint：Filesystem.MountPoints（aay）真实应答形状" {
  // 实机 sda1 的 Filesystem 属性：MountPoints = [b'/data']
  let fs = dsk_props_of([
    ("MountPoints", @traybus.GVArray("ay", [dsk_yb([47, 100, 97, 116, 97, 0])])),
    ("Size", @traybus.GVU64(2000397885440L)),
  ])
  assert_eq(dsk_first_mountpoint(fs), Some("/data"))
  // 未挂载（空数组 / 只有一个 NUL 元素）与属性缺失均为 None
  assert_eq(
    dsk_first_mountpoint(
      dsk_props_of([("MountPoints", @traybus.GVArray("ay", []))]),
    ),
    None,
  )
  assert_eq(
    dsk_first_mountpoint(
      dsk_props_of([("MountPoints", @traybus.GVArray("ay", [dsk_yb([0])]))]),
    ),
    None,
  )
  assert_eq(
    dsk_first_mountpoint(dsk_props_of([("Size", @traybus.GVU64(1L))])),
    None,
  )
  // 多挂载点取首个
  let multi = dsk_props_of([
    (
      "MountPoints",
      @traybus.GVArray("ay", [
        dsk_yb([47, 109, 110, 116, 0]),
        dsk_yb([47, 100, 97, 116, 97, 0]),
      ]),
    ),
  ])
  assert_eq(dsk_first_mountpoint(multi), Some("/mnt"))
}

///|
test "dsk_prop_str/bool/u64：属性字典提取与缺省" {
  let props = dsk_props_of([
    ("Device", @traybus.GVString("/dev/sda1")),
    ("IdLabel", @traybus.GVString("")),
    ("Size", @traybus.GVU64(2000397885440L)),
    ("Removable", @traybus.GVBool(false)),
  ])
  assert_eq(dsk_prop_str(props, "Device"), "/dev/sda1")
  assert_eq(dsk_prop_str(props, "IdLabel"), "")
  // udisks2 的 Block.Device 等是 'ay' 字节串型（非 's'），按 UTF-8 解码
  let bytes_props = dsk_props_of([
    ("Device", dsk_yb([47, 100, 101, 118, 47, 115, 100, 98, 49, 0])),
  ])
  assert_eq(dsk_prop_str(bytes_props, "Device"), "/dev/sdb1")
  // 缺属性/类型不符走默认（字符串为空串、布尔为给定默认值、整数为 None）
  assert_eq(dsk_prop_str(props, "Nope"), "")
  assert_eq(dsk_prop_str(props, "Size"), "") // 整数不是文本
  assert_eq(dsk_prop_bool(props, "Removable", true), false)
  assert_eq(dsk_prop_bool(props, "Nope", true), true)
  assert_eq(dsk_prop_u64(props, "Size"), Some(2000397885440L))
  assert_true(dsk_prop_u64(props, "Nope") is None)
  // 窄整型按宽度换算（Volume 属性在其它形状下也能读）
  let narrow = dsk_props_of([
    ("Size", @traybus.GVUInt32(1024)),
    ("Depth", @traybus.GVInt32(3)),
  ])
  assert_eq(dsk_prop_u64(narrow, "Size"), Some(1024L))
  assert_eq(dsk_prop_u64(narrow, "Depth"), Some(3L))
}

///|
test "dsk_volume_from：sda1 实机属性 → 卷快照" {
  // 实机 Block 属性（sda1：/dev/sda1，无卷标，2TB，不可移动；Device 是
  // 'ay' 字节串型，与 gdbus 应答一致）
  let block = dsk_props_of([
    ("Device", dsk_yb([47, 100, 101, 118, 47, 115, 100, 97, 49, 0])),
    ("IdLabel", @traybus.GVString("")),
    ("Size", @traybus.GVU64(2000397885440L)),
    ("Removable", @traybus.GVBool(false)),
  ])
  let fs = dsk_props_of([
    ("MountPoints", @traybus.GVArray("ay", [dsk_yb([47, 100, 97, 116, 97, 0])])),
  ])
  let vol = dsk_volume_from(
    "/org/freedesktop/UDisks2/block_devices/sda1", block, fs,
  )
  assert_eq(vol is Some(_), true)
  if vol is Some(v) {
    assert_eq(v.device, "/dev/sda1")
    assert_eq(v.label, "")
    assert_eq(v.mountpoint, Some("/data"))
    assert_eq(v.size_bytes, 2000397885440L)
    assert_eq(v.removable, false)
    assert_eq(v.path, "/org/freedesktop/UDisks2/block_devices/sda1")
  }
  // 缺 Device 属性不建卷；缺 Size 记 0；IdType 带卷标（U 盘形态）
  let usb_block = dsk_props_of([
    ("Device", dsk_yb([47, 100, 101, 118, 47, 115, 100, 98, 49, 0])),
    ("IdLabel", @traybus.GVString("MY USB")),
    ("Removable", @traybus.GVBool(true)),
  ])
  let usb_fs = dsk_props_of([("MountPoints", @traybus.GVArray("ay", []))])
  let usb = dsk_volume_from(
    "/org/freedesktop/UDisks2/block_devices/sdb1", usb_block, usb_fs,
  )
  assert_eq(usb is Some(_), true)
  if usb is Some(v) {
    assert_eq(v.device, "/dev/sdb1")
    assert_eq(v.label, "MY USB")
    assert_eq(v.mountpoint, None)
    assert_eq(v.size_bytes, 0L)
    assert_eq(v.removable, true)
  }
  let no_dev = dsk_props_of([("Size", @traybus.GVU64(1L))])
  assert_true(dsk_volume_from("/p", no_dev, fs) is None)
}

///|
test "dsk_bus_err/dsk_action_err：错误名映射" {
  // udisks2 不在线 / 总线不可达 → Unsupported（回退 lsblk 路线）
  assert_true(
    dsk_bus_err("org.freedesktop.DBus.Error.ServiceUnknown", "not running")
    is Unsupported,
  )
  assert_true(dsk_bus_err("gdbus.io", "connect failed") is Unsupported)
  // 其它错误保留原名与说明
  inspect(
    dsk_bus_err("org.freedesktop.UDisks2.Error.Failed", "io error"),
    content="DiskError::BusFailed(org.freedesktop.UDisks2.Error.Failed: io error)",
  )
  // 挂载/卸载专属错误
  inspect(
    dsk_action_err(
      "org.freedesktop.UDisks2.Error.AlreadyMounted", "已经挂着",
    ),
    content="DiskError::AlreadyMounted(已经挂着)",
  )
  inspect(
    dsk_action_err("org.freedesktop.UDisks2.Error.NotMounted", "没有挂着"),
    content="DiskError::NotMounted(没有挂着)",
  )
  inspect(
    dsk_action_err("org.freedesktop.UDisks2.Error.DeviceBusy", "busy"),
    content="DiskError::BusFailed(org.freedesktop.UDisks2.Error.DeviceBusy: busy)",
  )
}

///|
/// 多行文本拼接（每行补换行，与命令行工具输出一致）。
fn dsk_lines(lines : Array[String]) -> String {
  let buf = StringBuilder()
  for l in lines {
    buf.write_string(l)
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
/// 实机 lsblk 输出样例（Ubuntu 24.04，`lsblk --paths --json --bytes --fs
/// -o NAME,TYPE,RM,SIZE,MOUNTPOINTS,FSTYPE,LABEL` 的真实记录：SATA 数据盘
/// 一个分区、NVMe 系统盘三个分区含 LVM 成员与逻辑卷）。
fn dsk_real_lsblk() -> String {
  dsk_lines([
    "{", "   \"blockdevices\": [", "      {", "         \"name\": \"/dev/sda\",",
    "         \"type\": \"disk\",", "         \"rm\": false,", "         \"size\": 2000398934016,",
    "         \"mountpoints\": [", "             null", "         ],", "         \"fstype\": null,",
    "         \"label\": null,", "         \"children\": [", "            {", "               \"name\": \"/dev/sda1\",",
    "               \"type\": \"part\",", "               \"rm\": false,", "               \"size\": 2000397885440,",
    "               \"mountpoints\": [", "                   \"/data\"", "               ],",
    "               \"fstype\": \"ext4\",", "               \"label\": null", "            }",
    "         ]", "      },{", "         \"name\": \"/dev/nvme0n1\",", "         \"type\": \"disk\",",
    "         \"rm\": false,", "         \"size\": 500107862016,", "         \"mountpoints\": [",
    "             null", "         ],", "         \"fstype\": null,", "         \"label\": null,",
    "         \"children\": [", "            {", "               \"name\": \"/dev/nvme0n1p1\",",
    "               \"type\": \"part\",", "               \"rm\": false,", "               \"size\": 1127219200,",
    "               \"mountpoints\": [", "                   \"/boot/efi\"", "               ],",
    "               \"fstype\": \"vfat\",", "               \"label\": null", "            },{",
    "               \"name\": \"/dev/nvme0n1p2\",", "               \"type\": \"part\",",
    "               \"rm\": false,", "               \"size\": 2147483648,", "               \"mountpoints\": [",
    "                   \"/boot\"", "               ],", "               \"fstype\": \"ext4\",",
    "               \"label\": null", "            },{", "               \"name\": \"/dev/nvme0n1p3\",",
    "               \"type\": \"part\",", "               \"rm\": false,", "               \"size\": 496831037440,",
    "               \"mountpoints\": [", "                   null", "               ],",
    "               \"fstype\": \"LVM2_member\",", "               \"label\": null,",
    "               \"children\": [", "                  {", "                     \"name\": \"/dev/mapper/ubuntu--vg-ubuntu--lv\",",
    "                     \"type\": \"lvm\",", "                     \"rm\": false,",
    "                     \"size\": 496827891712,", "                     \"mountpoints\": [",
    "                         \"/\"", "                     ],", "                     \"fstype\": \"ext4\",",
    "                     \"label\": null", "                  }", "               ]",
    "            }", "         ]", "      }", "   ]", "}",
  ])
}

///|
test "dsk_parse_lsblk：实机输出样例（分区/LV 全收，整盘与容器不收）" {
  let vols = dsk_parse_lsblk(dsk_real_lsblk())
  assert_eq(vols is Ok(_), true)
  if vols is Ok(list) {
    assert_eq(list.length(), 4)
    // sda1：数据盘分区（挂 /data）
    assert_eq(list[0].device, "/dev/sda1")
    assert_eq(list[0].mountpoint, Some("/data"))
    assert_eq(list[0].size_bytes, 2000397885440L)
    assert_eq(list[0].removable, false)
    // nvme0n1p1/p2：ESP 与引导分区
    assert_eq(list[1].device, "/dev/nvme0n1p1")
    assert_eq(list[1].mountpoint, Some("/boot/efi"))
    assert_eq(list[1].size_bytes, 1127219200L)
    assert_eq(list[2].device, "/dev/nvme0n1p2")
    assert_eq(list[2].mountpoint, Some("/boot"))
    // LVM 逻辑卷：children 里的 dm 设备，挂在 /
    assert_eq(list[3].device, "/dev/mapper/ubuntu--vg-ubuntu--lv")
    assert_eq(list[3].mountpoint, Some("/"))
    assert_eq(list[3].size_bytes, 496827891712L)
    // 命令路线无 D-Bus 对象路径
    assert_eq(list[0].path, "")
    // 解析与 lsblk 文档语义对齐：整盘（有 children）、LVM 成员（容器型
    // 文件系统）、无文件系统的设备都不成卷
    let devices = list.map(fn(v) { v.device })
    assert_false(devices.contains("/dev/sda"))
    assert_false(devices.contains("/dev/nvme0n1"))
    assert_false(devices.contains("/dev/nvme0n1p3"))
  }
}

///|
test "dsk_parse_lsblk：U 盘与 loop/swap/LUKS 样例（只收用户卷）" {
  let usb = dsk_lines([
    "{", "   \"blockdevices\": [", "      {", "         \"name\": \"/dev/sdb\",",
    "         \"type\": \"disk\",", "         \"rm\": true,", "         \"size\": 30031254400,",
    "         \"mountpoints\": [ null ],", "         \"fstype\": null,", "         \"label\": null,",
    "         \"children\": [", "            {", "               \"name\": \"/dev/sdb1\",",
    "               \"type\": \"part\",", "               \"rm\": true,", "               \"size\": 30031254400,",
    "               \"mountpoints\": [ null ],", "               \"fstype\": \"exfat\",",
    "               \"label\": \"MY USB\"", "            }", "         ]", "      },{",
    "         \"name\": \"/dev/loop0\",", "         \"type\": \"loop\",", "         \"rm\": false,",
    "         \"size\": 68157440,", "         \"mountpoints\": [ \"/snap/core22/1033\" ],",
    "         \"fstype\": \"squashfs\",", "         \"label\": null", "      },{",
    "         \"name\": \"/dev/nvme0n1p3\",", "         \"type\": \"part\",", "         \"rm\": false,",
    "         \"size\": 496831037440,", "         \"mountpoints\": [ null ],", "         \"fstype\": \"LVM2_member\",",
    "         \"label\": null", "      },{", "         \"name\": \"/dev/nvme0n1p5\",",
    "         \"type\": \"part\",", "         \"rm\": false,", "         \"size\": 8589934592,",
    "         \"mountpoints\": [ null ],", "         \"fstype\": \"swap\",", "         \"label\": null",
    "      }", "   ]", "}",
  ])
  let vols = dsk_parse_lsblk(usb)
  assert_eq(vols is Ok(_), true)
  if vols is Ok(list) {
    assert_eq(list.length(), 1)
    assert_eq(list[0].device, "/dev/sdb1")
    assert_eq(list[0].label, "MY USB")
    assert_eq(list[0].mountpoint, None) // 未挂载
    assert_eq(list[0].size_bytes, 30031254400L)
    assert_eq(list[0].removable, true) // 分区继承盘的 rm
  }
}

///|
test "dsk_parse_lsblk：畸形输出给 ParseFailed" {
  assert_true(dsk_parse_lsblk("not json") is Err(ParseFailed(_)))
  assert_true(dsk_parse_lsblk("{\"blockdevices\": []}") is Err(ParseFailed(_)))
  assert_true(dsk_parse_lsblk("[1,2]") is Err(ParseFailed(_)))
  assert_true(dsk_parse_lsblk("") is Err(ParseFailed(_)))
}

///|
test "dsk_fstype_is_container/dsk_json_str/dsk_json_size：判定工具" {
  assert_true(dsk_fstype_is_container("swap"))
  assert_true(dsk_fstype_is_container("LVM2_member"))
  assert_true(dsk_fstype_is_container("crypto_LUKS"))
  assert_true(dsk_fstype_is_container("zfs_member"))
  assert_false(dsk_fstype_is_container("ext4"))
  assert_false(dsk_fstype_is_container("vfat"))
  assert_false(dsk_fstype_is_container(""))
  // JSON 值提取：null/非目标类型走空串与 0
  let obj = match
    @json.parse("{\"label\": \"MY USB\", \"size\": 68157440, \"rm\": true}") {
    Json::Object(m) => m
    _ => Map([])
  }
  assert_eq(dsk_json_str(obj.get("label")), "MY USB")
  assert_eq(dsk_json_size(obj.get("size")), 68157440L)
  assert_eq(dsk_json_size(obj.get("rm")), 0L) // 布尔不是容量
  assert_eq(dsk_json_size(obj.get("nope")), 0L)
  assert_eq(dsk_json_str(obj.get("nope")), "")
}

///|
test "dsk_lsblk_args：命令构造（只读枚举参数）" {
  let args = dsk_lsblk_args()
  assert_eq(args.length(), 6)
  assert_eq(args[0], "--paths")
  assert_eq(args[1], "--json")
  assert_eq(args[2], "--bytes")
  assert_eq(args[3], "--fs")
  assert_eq(args[4], "-o")
  assert_eq(args[5], "NAME,TYPE,RM,SIZE,MOUNTPOINTS,FSTYPE,LABEL")
}

///|
test "dsk_volumes 真机只读冒烟（无后端时跳过）" {
  if !dsk_supported() {
    println("dsk: skip (no udisks2/lsblk)")
    return
  }
  match dsk_volumes() {
    Err(e) => {
      println("dsk_volumes failed: \{e}")
      assert_true(false)
    }
    Ok(vols) => {
      for v in vols {
        assert_true(v.device.has_prefix("/dev/"))
        assert_true(v.size_bytes >= 0L)
        println("dsk: \{v}")
      }
      // 本机（udisks2 在线 + lsblk 在）两条路线枚举结果应一致：lsblk 路线
      // 强制跑一遍命令解析，与 D-Bus 路线对比。设备文件名两条路线形态不同
      // （LVM 卷 D-Bus 给 /dev/dm-N、lsblk --paths 给 /dev/mapper/…），
      // 因此比对稳定的挂载点集合（未挂载记空串）。
      if dsk_lsblk_available() {
        match dsk_volumes_lsblk() {
          Err(e) => {
            println("dsk_volumes_lsblk failed: \{e}")
            assert_true(false)
          }
          Ok(other) => {
            let mp = fn(v : DskVolume) -> String {
              match v.mountpoint {
                Some(p) => p
                None => ""
              }
            }
            let a = vols.map(mp)
            let b = other.map(mp)
            for d in a {
              assert_true(b.contains(d))
            }
            for d in b {
              assert_true(a.contains(d))
            }
          }
        }
      } else {
        println("dsk: lsblk route skip")
      }
    }
  }
}

///|
test "dsk_mount/dsk_unmount：设置类动作不执行（仅校验参数路径）" {
  // 空设备名与非法设备路径都应在调用侧即被拒（不会走到总线）
  let empty : DskVolume = {
    device: "",
    label: "",
    mountpoint: None,
    size_bytes: 0L,
    removable: false,
    path: "",
  }
  assert_true(dsk_mount(empty) is Err(InvalidParam(_)))
  assert_true(dsk_unmount(empty) is Err(InvalidParam(_)))
  let bogus : DskVolume = {
    device: "sdb1",
    label: "",
    mountpoint: None,
    size_bytes: 0L,
    removable: true,
    path: "",
  }
  assert_true(dsk_unmount(bogus) is Err(InvalidParam(_)))
}

