// S4-S7 硬件数据层白盒测试：解析纯函数喂字面量；真实采样仅在 Linux
// 宿主（/sys 存在）时断言，其余平台容错跳过。

///|
test "parse_temp_input：毫摄氏度换算 / 负温度 / 非法" {
  assert_eq(parse_temp_input("41850"), Some(41.85))
  assert_eq(parse_temp_input("46000"), Some(46.0))
  assert_eq(parse_temp_input("0"), Some(0.0))
  assert_eq(parse_temp_input("-5000"), Some(-5.0))
  assert_eq(parse_temp_input("41850\n"), Some(41.85))
  assert_true(parse_temp_input("abc") is None)
  assert_true(parse_temp_input("") is None)
}

///|
test "temp_indices：跳号编号 / 忽略旁支条目 / 升序" {
  // coretemp 实测形态：编号跳号，label 与输入成对，另有 crit/alarm
  let entries = "name\ntemp1_input\ntemp1_label\ntemp2_input\ntemp10_input\ntemp10_label\ntemp14_crit\ntemp2_alarm\ntemp14_input\n"
  assert_eq(temp_indices(entries), [1, 2, 10, 14])
  // 空与无 temp 行
  assert_eq(temp_indices("name\n").length(), 0)
  assert_eq(temp_indices("").length(), 0)
}

///|
test "parse_mounts：/dev 真实行 / 伪文件系统跳过" {
  let text = "sysfs /sys sysfs rw 0 0\nproc /proc proc rw 0 0\nudev /dev devtmpfs rw 0 0\n/dev/nvme0n1p3 / ext4 rw,relatime 0 0\ntmpfs /run tmpfs rw 0 0\ncgroup2 /sys/fs/cgroup cgroup2 rw 0 0\n/dev/nvme0n1p1 /boot/efi vfat rw 0 0\n/dev/mapper/ubuntu--vg-ubuntu--lv / ext4 rw 0 0\n"
  let mounts = parse_mounts(text)
  assert_eq(mounts.length(), 3)
  assert_eq(mounts[0].device, "/dev/nvme0n1p3")
  assert_eq(mounts[0].mount, "/")
  assert_eq(mounts[0].fstype, "ext4")
  assert_eq(mounts[1].mount, "/boot/efi")
  assert_eq(mounts[2].device, "/dev/mapper/ubuntu--vg-ubuntu--lv")
  // 空行 / 字段不足（缺 fstype）
  assert_eq(parse_mounts("\n\n/dev/sda1 /\n").length(), 0)
  assert_eq(parse_mounts("").length(), 0)
}

///|
test "parse_diskstats：真实行 / 分区行 / 字段不足跳过" {
  let text = "   7       0 loop0 11 0 28 0 0 0 0 0 0 0 0 0 0 0 0 0 0\n 259       0 nvme0n1 15931997 4728053 1171159154 1006981555 14641078 19676602 987613010 2801371767 0 6570892 3809050375 202243 0 301237488 112131 631653 584920\n 259       3 nvme0n1p3 15930626 4724532 1171124018 1006980878 14640631 19676835 987452912 2801368439 0 7105049 3808461349 202185 0 295880208 112031 0 0\n"
  let stats = parse_diskstats(text)
  assert_eq(stats.length(), 3)
  assert_eq(stats[0].name, "loop0")
  assert_eq(stats[1].name, "nvme0n1")
  assert_eq(stats[1].sectors_read, 1171159154)
  assert_eq(stats[1].sectors_written, 987613010)
  assert_eq(stats[2].name, "nvme0n1p3")
  // 字段不足 14 个
  assert_eq(parse_diskstats(" 8 0 sda 1 2 3\n").length(), 0)
}

///|
test "byte_rate / sector_rate：差值 / 首帧 / 负增量 / 扇区换算" {
  assert_eq(byte_rate(1000, 3000, 2.0), 1000.0)
  assert_eq(byte_rate(1000, 3000, 0.0), 0.0)
  assert_eq(byte_rate(3000, 1000, 2.0), 0.0)
  assert_eq(sector_rate(0, 2048, 1.0), 1048576.0)
  assert_eq(sector_rate(0, 2048, 0.0), 0.0)
}

///|
test "is_display_class / vendor_name：PCI 分类与厂商映射" {
  assert_true(is_display_class("0x030000"))
  assert_true(is_display_class("0x038000"))
  assert_true(!is_display_class("0x020000")) // 网卡
  assert_true(!is_display_class("0x010802")) // NVM Express
  assert_eq(vendor_name("0x10de"), "NVIDIA")
  assert_eq(vendor_name("0x1002"), "AMD")
  assert_eq(vendor_name("0x8086"), "Intel")
  assert_eq(vendor_name("0x1a03"), "ASPEED")
  // 未收录厂商保留原始 id
  assert_eq(vendor_name("0xdead"), "0xdead")
}

///|
test "DiskInfo::usage：df 口径(总-可用)" {
  let d : DiskInfo = {
    mount: "/",
    device: "/dev/sda1",
    fstype: "ext4",
    total_bytes: 1000,
    free_bytes: 100,
    avail_bytes: 300,
    read_bps: Some(0.0),
    write_bps: Some(0.0),
  }
  assert_eq(d.usage(), 0.7)
  let empty : DiskInfo = {
    mount: "/",
    device: "/dev/sda1",
    fstype: "ext4",
    total_bytes: 0,
    free_bytes: 0,
    avail_bytes: 0,
    read_bps: None,
    write_bps: None,
  }
  assert_eq(empty.usage(), 0.0)
}

///|
test "unescape_mount：内核八进制转义还原 / 无反斜杠原样 / 非法序列保留" {
  assert_eq(unescape_mount("/Volumes/My\\040Drive"), "/Volumes/My Drive")
  assert_eq(unescape_mount("/dev/disk1s1s1"), "/dev/disk1s1s1")
  assert_eq(unescape_mount("/"), "/")
  assert_eq(unescape_mount(""), "")
  assert_eq(unescape_mount("/Volumes/a\\134b"), "/Volumes/a\\b")
  assert_eq(unescape_mount("/Volumes/a\\040b\\040c"), "/Volumes/a b c")
  // 非八进制数字的 \xNN 与孤立反斜杠原样保留
  assert_eq(unescape_mount("/Volumes/a\\099b"), "/Volumes/a\\099b")
  assert_eq(unescape_mount("/Volumes/a\\04"), "/Volumes/a\\04")
  assert_eq(unescape_mount("/Volumes/a\\b"), "/Volumes/a\\b")
  // 中文卷名（非 ASCII）原样透过
  assert_eq(unescape_mount("/Volumes/移动硬盘"), "/Volumes/移动硬盘")
}

///|
test "parse_mounts：macOS getfsstat 形态(apfs 卷 / 转义空格 / BSD 伪文件系统)" {
  // stub 对 getfsstat 输出按 /proc/mounts 同构转写：设备 \t 挂载点 \t 类型
  let text = "/dev/disk1s1s1\t/\tapfs\trw 0 0\n/dev/disk1s5\t/System/Volumes/Data\tapfs\trw 0 0\n/dev/disk2s1\t/Volumes/My\\040Drive\thfs\trw 0 0\ndevfs\t/dev\tdevfs\trw 0 0\nmap\\040auto_home\t/System/Volumes/Data/home\tautofs\tautomounted\n"
  let mounts = parse_mounts(text)
  // devfs / autofs 伪文件系统被跳过；autofs 行设备名也无 /dev/ 前缀
  assert_eq(mounts.length(), 3)
  assert_eq(mounts[0].device, "/dev/disk1s1s1")
  assert_eq(mounts[0].mount, "/")
  assert_eq(mounts[0].fstype, "apfs")
  assert_eq(mounts[1].mount, "/System/Volumes/Data")
  // 含空格卷名经 \040 转义后还原（statvfs 才能对上位）
  assert_eq(mounts[2].mount, "/Volumes/My Drive")
  assert_eq(mounts[2].device, "/dev/disk2s1")
  assert_eq(mounts[2].fstype, "hfs")
  // Linux 原有形态不受影响（回归）
  let linux = "sysfs /sys sysfs rw 0 0\n/dev/nvme0n1p3 / ext4 rw,relatime 0 0\n"
  let lm = parse_mounts(linux)
  assert_eq(lm.length(), 1)
  assert_eq(lm[0].mount, "/")
}

///|
test "S4 真实采样：hwmon 传感器(Linux)" {
  match hwmon_sensors() {
    None => () // 非 Linux 宿主跳过
    Some(sensors) => {
      // 虚机/容器宿主可能无 hwmon(CI runner 即如此),空列表跳过
      if sensors.length() == 0 {
        return
      }
      for s in sensors {
        assert_true(s.chip.length() > 0)
        assert_true(s.label.length() > 0)
        // 合理温度区间(-50..200℃),防读到错误文件
        assert_true(s.celsius >= -50.0 && s.celsius <= 200.0)
      }
      // coretemp 的 Package 传感器仅物理真机必有,虚机会缺——不强制
    }
  }
}

///|
test "S6 真实采样：GPU 枚举(Linux sysfs / macOS system_profiler)" {
  let mon = GpuMonitor::new()
  match mon.tick() {
    None => () // 枚举失败宿主跳过
    Some(gpus) =>
      // 虚拟机可能无显示设备；有条目则字段须完整（macOS 路径为
      // system_profiler 解析结果，pci / device / vendor 同样非空）
      for g in gpus {
        assert_true(g.pci.length() > 0)
        assert_true(g.device.length() > 0)
        assert_true(g.vendor.length() > 0)
        match g.celsius {
          None => ()
          Some(c) => assert_true(c >= -50.0 && c <= 200.0)
        }
        // 占用：nvidia-smi / sysfs gpu_busy_percent / DRM fdinfo 任一
        // 来源有值即在 0..100；全部不可用（老驱动 / 无来源）为 None
        match g.busy {
          None => ()
          Some(b) => assert_true(b >= 0.0 && b <= 100.0)
        }
      }
  }
}

///|
test "parse_drm_fdinfo：amdgpu 形态(drm-pdev / 多引擎求和 / ns 后缀)" {
  // 形态照内核源码（amdgpu_fdinfo.c + drm_file.c 的 drm_show_fdinfo）：
  // Tab 分隔、引擎值带 " ns" 后缀、零用量引擎不打印、另有 pasid /
  // drm-memory-* 等旁支键（值带 KiB 单位，不能被当引擎时间）
  let text = "pos:\t0\nflags:\t02102002\nmnt_id:\t22\nino:\t2665\ndrm-driver:\tamdgpu\ndrm-client-id:\t16\ndrm-pdev:\t0000:0c:00.0\npasid:\t32769\ndrm-memory-vram:\t1024 KiB\ndrm-memory-gtt: \t0 KiB\namd-requested-vram:\t0 KiB\ndrm-engine-gfx:\t914633 ns\ndrm-engine-compute:\t250000 ns\ndrm-engine-dec:\t1000 ns\n"
  let e = parse_drm_fdinfo(text).unwrap()
  assert_eq(e.driver, "amdgpu")
  assert_eq(e.pdev, "0000:0c:00.0")
  assert_eq(e.client_id, 16L)
  assert_eq(e.engine_ns, 1165633L) // 914633+250000+1000
}

///|
test "parse_drm_fdinfo：i915 形态(无 pdev / capacity 键排除)" {
  // 老内核（<6.5）无 drm-pdev；i915 多视频引擎时打 capacity 键
  // （并行引擎数，不是时间，不能计入）
  let text = "pos:\t0\nflags:\t02102002\nmnt_id:\t22\nino:\t1001\ndrm-driver:\ti915\ndrm-client-id:\t5\ndrm-engine-render:\t123456 ns\ndrm-engine-video:\t0 ns\ndrm-engine-video-enhance:\t0 ns\ndrm-engine-capacity-video:\t2\n"
  let e = parse_drm_fdinfo(text).unwrap()
  assert_eq(e.driver, "i915")
  assert_eq(e.pdev, "")
  assert_eq(e.client_id, 5L)
  assert_eq(e.engine_ns, 123456L)
  // 无单位后缀的裸数值也要认（规范允许单位可缺）
  let bare = "drm-driver:\ti915\ndrm-client-id:\t9\ndrm-engine-render:\t42\n"
  assert_eq(parse_drm_fdinfo(bare).unwrap().engine_ns, 42L)
}

///|
test "parse_drm_fdinfo：非 DRM fd 与无引擎统计的老驱动 → None" {
  // 普通文件 fd：只有 pos/flags/mnt_id/ino
  assert_true(parse_drm_fdinfo("pos:\t0\nflags:\t02\nmnt_id:\t11\nino:\t4026531841\n") is None)
  // i915 gen<8 早退：有 drm-driver/client-id 但无引擎键
  let old_i915 = parse_drm_fdinfo("pos:\t0\nflags:\t02\nmnt_id:\t11\nino:\t123\ndrm-driver:\ti915\ndrm-client-id:\t3\n")
  assert_true(old_i915 is None)
  assert_true(parse_drm_fdinfo("") is None)
}

///|
test "is_drm_engine_key / drm_device_key：引擎键判定与设备键选择" {
  assert_true(is_drm_engine_key("drm-engine-gfx"))
  assert_true(is_drm_engine_key("drm-engine-video-enhance"))
  // capacity 是并行引擎数不是时间；total / cycles / memory 都不是引擎时间
  assert_true(!is_drm_engine_key("drm-engine-capacity-video"))
  assert_true(!is_drm_engine_key("drm-total-gfx"))
  assert_true(!is_drm_engine_key("drm-cycles-gfx"))
  assert_true(!is_drm_engine_key("drm-memory-vram"))
  assert_true(!is_drm_engine_key("drm-driver"))
  // 设备键：pdev（与 sysfs 设备目录名同形）优先，缺失回退驱动名
  let amd : DrmFdinfo = {
    driver: "amdgpu",
    pdev: "0000:0c:00.0",
    client_id: 7,
    engine_ns: 100,
  }
  assert_eq(drm_device_key(amd), "0000:0c:00.0")
  let old : DrmFdinfo = { driver: "i915", pdev: "", client_id: 5, engine_ns: 100 }
  assert_eq(drm_device_key(old), "i915")
}

///|
test "drm_clients_total：同 client 归并 / 跨进程共享 fd / 按设备分键" {
  fn e(
    driver : String,
    pdev : String,
    cid : Int64,
    ns : Int64,
  ) -> DrmFdinfo {
    { driver, pdev, client_id: cid, engine_ns: ns }
  }

  // 同一客户端（client 16）在两个 fd（dup）里重复出现：只计一次
  let entries = [
    e("amdgpu", "0000:0c:00.0", 16, 1000),
    e("amdgpu", "0000:0c:00.0", 16, 1000),
    e("amdgpu", "0000:0c:00.0", 17, 500),
    // 老内核无 pdev：同驱动按驱动名归并，client-id 是该设备计数器
    e("i915", "", 5, 2000),
    e("i915", "", 5, 2000),
    e("i915", "", 6, 300),
  ]
  let total = drm_clients_total(entries)
  assert_eq(total.get("0000:0c:00.0"), Some(1500L)) // 1000 + 500
  assert_eq(total.get("i915"), Some(2300L)) // 2000 + 300
  // 同驱动两个设备（6.5+ 有 pdev）：按 PCI 地址分开，不合并
  let dual = [
    e("amdgpu", "0000:03:00.0", 9, 100),
    e("amdgpu", "0000:0c:00.0", 9, 400),
  ]
  let dt = drm_clients_total(dual)
  assert_eq(dt.get("0000:03:00.0"), Some(100L))
  assert_eq(dt.get("0000:0c:00.0"), Some(400L))
  // 缺 client-id（-1）：不归并，每条独立计数
  let nocid = [e("xe", "", -1, 100), e("xe", "", -1, 250)]
  assert_eq(drm_clients_total(nocid).get("xe"), Some(350L))
  // 后出现同 client 的更高累计值：增量并入（非单调更新取较高值）
  let grow = [e("i915", "", 5, 1000), e("i915", "", 5, 1800)]
  assert_eq(drm_clients_total(grow).get("i915"), Some(1800L))
  assert_eq(drm_clients_total([]).length(), 0)
}

///|
test "drm_busy_percent：差值利用率 / 首帧 / 回落钳 0 / 并行超墙钟钳 100" {
  // 1 秒墙钟内忙 0.5s → 50%
  assert_eq(drm_busy_percent(1_000_000_000L, 1_500_000_000L, 1.0), 50.0)
  assert_eq(drm_busy_percent(0, 250_000_000L, 1.0), 25.0)
  // 首帧（墙钟 ≤ 0）按 0
  assert_eq(drm_busy_percent(0, 1_000_000_000L, 0.0), 0.0)
  assert_eq(drm_busy_percent(0, 1_000_000_000L, -1.0), 0.0)
  // 累计值回落（客户端退出重开 / 计数器重置）按 0
  assert_eq(drm_busy_percent(2_000_000_000L, 1_000_000_000L, 1.0), 0.0)
  // 多引擎并行（gfx + compute 同时跑）合计可超墙钟：钳到 100
  assert_eq(drm_busy_percent(0, 2_000_000_000L, 1.0), 100.0)
  // 墙钟极短（采样间隔 << 忙增量）：同样钳 100 不出界
  assert_eq(drm_busy_percent(0, 1_000_000_000L, 0.001), 100.0)
}

///|
test "is_pid_entry：纯数字 pid / 过滤非进程条目" {
  assert_true(is_pid_entry("1234"))
  assert_true(is_pid_entry("0"))
  assert_true(!is_pid_entry("self"))
  assert_true(!is_pid_entry("cpuinfo"))
  assert_true(!is_pid_entry("meminfo"))
  assert_true(!is_pid_entry("irq"))
  assert_true(!is_pid_entry(""))
  assert_true(!is_pid_entry("12a"))
}

///|
test "parse_uevent_driver：DRIVER= 提取 / 缺失回退空串" {
  // 真实 /sys/bus/pci/devices/<addr>/uevent 形态
  let text = "DRIVER=i915\nPCI_CLASS=030000\nPCI_ID=8086:9A49\nPCI_SLOT_NAME=0000:00:02.0\nMODALIAS=pci:v00008086d00009A49sv00001043sd00008761bc03sc00i00\n"
  assert_eq(parse_uevent_driver(text), "i915")
  // 尾换行 / 首尾空白容忍
  assert_eq(parse_uevent_driver("PCI_CLASS=030000\nDRIVER=amdgpu\n"), "amdgpu")
  assert_eq(parse_uevent_driver("DRIVER=xe"), "xe")
  // 未绑定驱动（无 DRIVER 行）与非 uevent 文本 → 空串
  assert_eq(parse_uevent_driver("PCI_CLASS=030000\n"), "")
  assert_eq(parse_uevent_driver(""), "")
  assert_eq(parse_uevent_driver("no-equal-sign\n"), "")
}

///|
test "S6 真实采样：DRM fdinfo 聚合(Linux)" {
  let mon = GpuMonitor::new()
  // 首帧无前样本：利用率表为空（次帧起出数），但前样本要记下
  let first = mon.fdinfo_usage()
  assert_true(first.is_empty())
  // 二帧：宿主有本用户的 DRM 客户端（i915 / xe / amdgpu）时非空；
  // NVIDIA 专有驱动机器无 fdinfo 用量统计，空表合法
  let second = mon.fdinfo_usage()
  for k, v in second.iter2() {
    assert_true(k.length() > 0)
    assert_true(v >= 0.0 && v <= 100.0)
  }
}

///|
test "S5 真实采样：磁盘容量 + IO(Linux / macOS)" {
  let mon = DiskMonitor::new()
  match mon.tick() {
    None => () // 无挂载表宿主跳过
    Some(disks) => {
      assert_true(disks.length() > 0)
      let mut has_root = false
      for d in disks {
        assert_true(d.total_bytes > 0)
        assert_true(d.avail_bytes >= 0 && d.avail_bytes <= d.total_bytes)
        assert_true(d.usage() >= 0.0 && d.usage() <= 1.0)
        // 速率：来源可用时有定义且非负；macOS 无 IO 来源为 None
        // （UI 显示「—」），两种形态都合法
        match d.read_bps {
          None => ()
          Some(v) => assert_true(v >= 0.0)
        }
        match d.write_bps {
          None => ()
          Some(v) => assert_true(v >= 0.0)
        }
        if d.mount == "/" {
          has_root = true
        }
        // Windows 虚拟 mounts 无 "/"，盘符根（"C:\"）等价于根卷
        if on_windows() && d.mount.length() == 3 && d.mount[1] == ':' {
          has_root = true
        }
      }
      assert_true(has_root)
      // 二次采样：速率有定义(不强求非 0,磁盘可能静置)
      let second = mon.tick()
      assert_true(second is Some(_))
    }
  }
}

///|
test "S7 真实采样：网卡速率(Linux)" {
  let mon = NetMonitor::new()
  match mon.tick() {
    None => () // 非 Linux 宿主跳过
    Some(nets) => {
      assert_true(nets.length() > 0)
      let mut has_lo = false
      for n in nets {
        assert_true(n.name.length() > 0)
        assert_true(n.rx_bytes >= 0 && n.tx_bytes >= 0)
        assert_true(n.rx_bps >= 0.0 && n.tx_bps >= 0.0)
        if n.name == "lo" {
          has_lo = true
        }
      }
      assert_true(has_lo)
      let second = mon.tick()
      assert_true(second is Some(_))
    }
  }
}

///|
test "is_system_mount：/boot 等系统挂载排除,/run/media 与自定义挂载保留" {
  assert_true(is_system_mount("/boot"))
  assert_true(is_system_mount("/boot/efi"))
  assert_true(is_system_mount("/snap/snapd/200"))
  assert_true(is_system_mount("/var/lib/docker"))
  assert_true(is_system_mount("/run/user/1000"))
  assert_true(is_system_mount("/run"))
  assert_false(is_system_mount("/"))
  assert_false(is_system_mount("/bootstrap"))
  assert_false(is_system_mount("/run/media/user/USB"))
  assert_false(is_system_mount("/data"))
  // macOS 系统宗卷：/private（swap 后备）与 /System/Volumes 下非数据卷
  assert_true(is_system_mount("/private"))
  assert_true(is_system_mount("/private/var/vm"))
  assert_true(is_system_mount("/System/Volumes/Preboot"))
  assert_true(is_system_mount("/System/Volumes/Update"))
  assert_true(is_system_mount("/System/Volumes/VM"))
  assert_true(is_system_mount("/System/Volumes/Hardware"))
  assert_true(is_system_mount("/System/Volumes/iSCPreboot"))
  // 用户数据卷与用户挂载保留（macOS 的 "Macintosh HD" 是 /System/Volumes/Data）
  assert_false(is_system_mount("/System/Volumes/Data"))
  assert_false(is_system_mount("/Volumes/My Drive"))
  assert_false(is_system_mount("/System"))
}

///|
test "parse_vram：system_profiler 显存文本转字节" {
  assert_eq(parse_vram("16 GB"), Some(16L * 1024 * 1024 * 1024))
  assert_eq(parse_vram("1536 MB"), Some(1536L * 1024 * 1024))
  assert_eq(parse_vram("1.5 GB"), Some(1610612736L))
  assert_eq(parse_vram("128 MB"), Some(128L * 1024 * 1024))
  assert_eq(parse_vram("8 KB"), Some(8192L))
  assert_eq(parse_vram("512"), Some(512L)) // 无单位按字节
  assert_eq(parse_vram(""), None)
  assert_eq(parse_vram("abc"), None)
  assert_eq(parse_vram("16 XB"), None) // 未知单位
}

///|
test "json_string_value：键值提取 / 嵌套键 / 数字值 / 转义" {
  let obj = "{\"sppci_model\" : \"Apple M1 Pro\", \"sppci_cores\" : 16, \"spdisplays_vram\" : \"16 GB\"}"
  assert_eq(json_string_value(obj, "sppci_model"), Some("Apple M1 Pro"))
  assert_eq(json_string_value(obj, "spdisplays_vram"), Some("16 GB"))
  // 数字值不是字符串 → None
  assert_eq(json_string_value(obj, "sppci_cores"), None)
  // 键缺失
  assert_eq(json_string_value(obj, "nope"), None)
  // 值内含转义引号
  assert_eq(
    json_string_value("{\"k\" : \"a\\\"b\"}", "k"),
    Some("a\"b"),
  )
  // 键名是其它键值的前缀也不能误配（带引号整键匹配）
  assert_eq(json_string_value("{\"ab\" : \"1\", \"a\" : \"2\"}", "a"), Some("2"))
}

///|
test "json_items_objects：_items 顶层对象切分 / 嵌套 / 字符串内括号" {
  let json = "{\"_items\" : [ {\"a\" : \"1\"}, {\"b\" : {\"c\" : \"{\"}}, {\"d\" : \"}\"} ], \"_other\" : 1}"
  let objs = json_items_objects(json)
  assert_eq(objs.length(), 3)
  assert_eq(json_string_value(objs[0], "a"), Some("1"))
  assert_eq(json_string_value(objs[1], "c"), Some("{"))
  assert_eq(json_string_value(objs[2], "d"), Some("}"))
  // 无 _items / 空数组 / 非 JSON
  assert_eq(json_items_objects("{\"x\" : 1}").length(), 0)
  assert_eq(json_items_objects("").length(), 0)
  assert_eq(json_items_objects("{\"_items\" : []}").length(), 0)
}

///|
test "parse_system_profiler_gpu：Apple Silicon 单卡 / Intel 双卡 / 宽容口径" {
  // Apple Silicon（system_profiler -json 实测形态：sppci_model 芯片名，
  // spdisplays_vram 显存，无 spdisplays_vendor）
  let m1 = "{\"_items\" : [{\"_name\" : \"Apple M1 Pro\", \"sppci_model\" : \"Apple M1 Pro\", \"spdisplays_vram\" : \"16 GB\", \"spdisplays_vendor\" : \"sppci_vendor_apple\"}], \"_detailLevel\" : 0}"
  let g1 = parse_system_profiler_gpu(m1)
  assert_eq(g1.length(), 1)
  assert_eq(g1[0].model, "Apple M1 Pro")
  assert_eq(g1[0].vendor, "Apple")
  assert_eq(g1[0].vram_total, Some(16.0 * 1024 * 1024 * 1024))
  // 利用率与温度无来源 → None（UI 按位显示「—」）
  assert_eq(g1[0].busy, None)
  assert_eq(g1[0].celsius, None)
  assert_eq(g1[0].vram_used, None)
  assert_true(g1[0].pci.length() > 0)
  assert_true(g1[0].device.length() > 0)
  // Intel 集显 + AMD 独显双卡：厂商按型号名嗅探
  let dual = "{\"_items\" : [{\"sppci_model\" : \"Intel UHD Graphics 630\"}, {\"sppci_model\" : \"AMD Radeon Pro 5500M\", \"spdisplays_vram\" : \"8 GB\"}]}"
  let g2 = parse_system_profiler_gpu(dual)
  assert_eq(g2.length(), 2)
  assert_eq(g2[0].vendor, "Intel")
  assert_eq(g2[0].model, "Intel UHD Graphics 630")
  assert_eq(g2[0].vram_total, None) // 集显无显存字段 → None
  assert_eq(g2[1].vendor, "AMD")
  assert_eq(g2[1].vram_total, Some(8.0 * 1024 * 1024 * 1024))
  // 宽容口径：键缺失 / _items 为空 / 型号缺失回退 _name
  assert_eq(parse_system_profiler_gpu("{\"_items\" : []}").length(), 0)
  assert_eq(parse_system_profiler_gpu("{}").length(), 0)
  let noname = parse_system_profiler_gpu("{\"_items\" : [{\"_name\" : \"Fallback GPU\"}]}")
  assert_eq(noname.length(), 1)
  assert_eq(noname[0].model, "Fallback GPU")
}

///|
test "norm_pci_id / is_hex4：PCI id 归一化与四位十六进制判定" {
  // sysfs 形态：0x 前缀 + 小写四位；pci.ids 形态：无前缀
  assert_eq(norm_pci_id("0x10de"), "10de")
  assert_eq(norm_pci_id("0x1002"), "1002")
  assert_eq(norm_pci_id("0x8086"), "8086")
  // 无前缀 / 大写 0X / 大小写混写都归一为小写
  assert_eq(norm_pci_id("7480"), "7480")
  assert_eq(norm_pci_id("0X10DE"), "10de")
  assert_eq(norm_pci_id("0xAbCd"), "abcd")
  // 位数不足左补零到四位；首尾空白裁剪
  assert_eq(norm_pci_id("0x2"), "0002")
  assert_eq(norm_pci_id(" 0x10de\n"), "10de")
  // 四位十六进制判定：非十六进制 / 占位串 / 空串 / 长短不一都不算
  assert_true(is_hex4(norm_pci_id("0x10de")))
  assert_true(!is_hex4(norm_pci_id("0xzzzz")))
  assert_true(!is_hex4(norm_pci_id("(未知)")))
  assert_true(!is_hex4(norm_pci_id("")))
  assert_true(!is_hex4("12345"))
  assert_true(!is_hex4("abc"))
}

///|
test "pci_ids_device_name：缩进层级解析(subsystem 跳过 / 出节提前返回 / class 节)" {
  // 形态照真实 pci.ids（2024.03.31）：'#' 注释、无缩进 vendor、单 Tab
  // device、双 Tab subsystem；末尾 class 节与 vendor 行同形
  let ids = "#\n#\tList of PCI ID's\n#\n\n0001  SafeNet (wrong ID)\n0010  Allied Telesis, Inc (Wrong ID)\n# This is a relabelled RTL-8139\n\t8139  AT-2500TX V3 Ethernet\n\t\tdead beef  Subsystem Name\n1002  Advanced Micro Devices, Inc. [AMD/ATI]\n\t1304  Kaveri\n\t1309  Kaveri [Radeon R6/R7 Graphics]\n\t\t17aa 3830  Z50-75\n\t7480  Navi 33 [Radeon RX 7700S/7600/7600S/7600M XT/PRO W7600]\n\t9999\n8086  Intel Corporation\n\t3ea0  WhiskeyLake-U GT2 [UHD Graphics 620]\nC 00  Unclassified device\n\t00  Non-VGA unclassified device\n"
  // 命中：型号名整段保留（内部空格 / 方括号 / 斜杠）
  assert_eq(
    pci_ids_device_name(ids, "0x1002", "0x7480"),
    Some("Navi 33 [Radeon RX 7700S/7600/7600S/7600M XT/PRO W7600]"),
  )
  assert_eq(
    pci_ids_device_name(ids, "0x8086", "0x3ea0"),
    Some("WhiskeyLake-U GT2 [UHD Graphics 620]"),
  )
  // 前导零 vendor id 与无前缀 device id 都认（归一化）
  assert_eq(pci_ids_device_name(ids, "0x0010", "8139"), Some("AT-2500TX V3 Ethernet"))
  assert_eq(pci_ids_device_name(ids, "0X1002", "7480"), pci_ids_device_name(ids, "0x1002", "0x7480"))
  // 同 vendor 下查无此 device：扫到下一 vendor 行即出节返回 None；
  // 9999 有条目但无名称（真实库不出现），同样按查不到处理
  assert_true(pci_ids_device_name(ids, "0x1002", "0x9999") is None)
  // 跨 vendor 不串：7480 是 AMD 的，查 Intel 查不到
  assert_true(pci_ids_device_name(ids, "0x8086", "0x7480") is None)
  // 无 device 行的 vendor（0001）：8139 属于 0010，不跨节误配
  assert_true(pci_ids_device_name(ids, "0x0001", "0x8139") is None)
  // subsystem 行（双 Tab）不当 device：dead 只是 0010 的子系统 id
  assert_true(pci_ids_device_name(ids, "0x0010", "0xdead") is None)
  // class 节（"C 00" 行与 class 子行）不产生误配
  assert_true(pci_ids_device_name(ids, "0x0000", "0x0000") is None)
  assert_true(pci_ids_device_name(ids, "0x0000", "0x00") is None)
  // 不存在的 vendor / id 非法（非四位十六进制）→ None
  assert_true(pci_ids_device_name(ids, "0xdead", "0xbeef") is None)
  assert_true(pci_ids_device_name(ids, "0xzzzz", "0x0001") is None)
  assert_true(pci_ids_device_name(ids, "", "") is None)
  // 空数据库 / 空文本
  assert_true(pci_ids_device_name("", "0x1002", "0x7480") is None)
}

///|
test "gpu_model_name：smi 优先 / pci.ids 命中 / 回退 device id / 占位留空" {
  let ids = "1002  Advanced Micro Devices, Inc. [AMD/ATI]\n\t7480  Navi 33 [Radeon RX 7700S/7600]\n"
  // nvidia-smi 命中优先（其型号名比 pci.ids 更具体），不经数据库
  assert_eq(gpu_model_name("NVIDIA GeForce RTX 3070", "0x10de", "0x2488", ids), "NVIDIA GeForce RTX 3070")
  // AMD / Intel 走 pci.ids 商业型号名
  assert_eq(gpu_model_name("", "0x1002", "0x7480", ids), "Navi 33 [Radeon RX 7700S/7600]")
  // 数据库不可达（空文本）与库内无该条目：回退 device id 原文
  assert_eq(gpu_model_name("", "0x1002", "0x7480", ""), "0x7480")
  assert_eq(gpu_model_name("", "0x1002", "0x9999", ids), "0x9999")
  // id 本身不可用（sysfs 读取失败的占位串）：空型号，UI 不显示型号位
  assert_eq(gpu_model_name("", "0x1002", "(未知)", ids), "")
}

///|
test "GpuMonitor::gpu_model：pci.ids 常驻缓存 / smi 优先 / 占位 id" {
  let mon = GpuMonitor::new()
  let row : GpuRow = {
    addr: "0000:01:00.0",
    vendor: "0x1002",
    device: "0x7480",
    busy: None,
    vram_used: None,
    vram_total: None,
    celsius: None,
    model: "",
  }
  // 有 pci.ids 的宿主给出商业型号名，没有的宿主回退 device id——
  // 两种形态都要求非空（UI 型号位有东西可显示）
  let m1 = mon.gpu_model(row)
  assert_true(m1.length() > 0)
  // 二次调用走常驻缓存（不再扫全文），结果一致
  assert_eq(mon.gpu_model(row), m1)
  // nvidia-smi 命中优先，不进缓存
  let smi : GpuRow = {
    addr: "0000:01:00.0",
    vendor: "0x10de",
    device: "0x2488",
    busy: Some(35.0),
    vram_used: None,
    vram_total: None,
    celsius: None,
    model: "NVIDIA GeForce RTX 3070",
  }
  assert_eq(mon.gpu_model(smi), "NVIDIA GeForce RTX 3070")
  // device id 读不到（占位串）：空型号
  let unknown : GpuRow = {
    addr: "0000:02:00.0",
    vendor: "0x1002",
    device: "(未知)",
    busy: None,
    vram_used: None,
    vram_total: None,
    celsius: None,
    model: "",
  }
  assert_eq(mon.gpu_model(unknown), "")
}

///|
test "SYS5 真实采样：pci.ids 商业型号名(Linux)" {
  match read_pci_ids() {
    None => () // 无 pci.ids 数据库宿主(虚机 / Flatpak 沙箱)跳过
    Some(text) => {
      // 从原文动态取第一对 vendor / device 做正向断言：具体名称随
      // 数据库版本变化，口径是「返回该行 id 之后的整段名称」
      let mut vendor = ""
      let mut device = ""
      let mut raw = ""
      for line in text.split("\n") {
        if line.is_empty() || line.has_prefix("#") || line.has_prefix("\t\t") {
          continue
        }
        if line.has_prefix("\t") {
          if vendor == "" {
            continue
          }
          let f = split_fields(line[1:])
          if f.length() >= 2 && is_hex4(norm_pci_id(f[0].to_owned())) {
            device = f[0].to_owned()
            raw = line.to_owned()
            break
          }
          continue
        }
        // vendor 行：持续更新为最近一个（0001 无 device 行，8139 属 0010）
        let f = split_fields(line)
        if f.length() >= 2 && is_hex4(norm_pci_id(f[0].to_owned())) {
          vendor = f[0].to_owned()
        }
      }
      if device != "" {
        let got = pci_ids_device_name(text, vendor, device)
        assert_true(got is Some(_))
        match got {
          Some(name) => {
            assert_true(name.length() > 0)
            // 名称须是原行 id 之后的尾部（整段保留，内部空格不塌陷）
            assert_true(raw.trim().has_suffix(name))
          }
          None => ()
        }
      }
      // 负向：无 device 行的 vendor（dead = Indigita）扫到出节即 None；
      // 非法 id 不过归一化校验，直接 None
      assert_true(pci_ids_device_name(text, "0xdead", "0xbeef") is None)
      assert_true(pci_ids_device_name(text, "0x1002", "0xzzzz") is None)
    }
  }
}

