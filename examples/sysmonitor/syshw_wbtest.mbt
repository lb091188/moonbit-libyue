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
    read_bps: 0.0,
    write_bps: 0.0,
  }
  assert_eq(d.usage(), 0.7)
  let empty : DiskInfo = {
    mount: "/",
    device: "/dev/sda1",
    fstype: "ext4",
    total_bytes: 0,
    free_bytes: 0,
    avail_bytes: 0,
    read_bps: 0.0,
    write_bps: 0.0,
  }
  assert_eq(empty.usage(), 0.0)
}

///|
test "S4 真实采样：hwmon 传感器(Linux)" {
  match hwmon_sensors() {
    None => () // 非 Linux 宿主跳过
    Some(sensors) => {
      assert_true(sensors.length() > 0)
      for s in sensors {
        assert_true(s.chip.length() > 0)
        assert_true(s.label.length() > 0)
        // 合理温度区间(-50..200℃),防读到错误文件
        assert_true(s.celsius >= -50.0 && s.celsius <= 200.0)
      }
      // 本机 coretemp 必有 Package 传感器
      let mut has_package = false
      for s in sensors {
        if s.label.has_prefix("Package") {
          has_package = true
        }
      }
      assert_true(has_package)
    }
  }
}

///|
test "S6 真实采样：PCI 显示设备枚举(Linux)" {
  match gpu_list() {
    None => () // 非 Linux 宿主跳过
    Some(gpus) => {
      // 虚拟机可能无显示设备；有条目则字段须完整
      for g in gpus {
        assert_true(g.pci.length() > 0)
        assert_true(g.device.length() > 0)
        assert_true(g.vendor.length() > 0)
        match g.celsius {
          None => ()
          Some(c) => assert_true(c >= -50.0 && c <= 200.0)
        }
      }
    }
  }
}

///|
test "S5 真实采样：磁盘容量 + IO(Linux)" {
  let mon = DiskMonitor::new()
  match mon.tick() {
    None => () // 非 Linux 宿主跳过
    Some(disks) => {
      assert_true(disks.length() > 0)
      let mut has_root = false
      for d in disks {
        assert_true(d.total_bytes > 0)
        assert_true(d.avail_bytes >= 0 && d.avail_bytes <= d.total_bytes)
        assert_true(d.usage() >= 0.0 && d.usage() <= 1.0)
        assert_true(d.read_bps >= 0.0 && d.write_bps >= 0.0)
        if d.mount == "/" {
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
