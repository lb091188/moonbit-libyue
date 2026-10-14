// 壁纸模块白盒测试：XFCE/GNOME/KDE 三路输出解析与参数构造（XFCE 属性
// 清单为本机真实 xfconf-query -l 输出样例）+ 目录/路径解析纯函数 +
// 真机只读冒烟。wp_set 属设置类，本测试只验参数构造、不真实执行；
// 真机只读项为 wp_get（XFCE 下读当前壁纸属性值）与已连接输出枚举。

///|
/// 行数组拼多行文本（每行补换行，与命令行工具输出一致）。
fn wp_lines(lines : Array[String]) -> String {
  let buf = StringBuilder()
  for l in lines {
    buf.write_string(l)
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
/// 本机真实 xfconf-query -c xfce4-desktop -l 输出样例（截取自
/// Ubuntu 24.04 + X11 + XFCE 实机；仅保留 backdrop 相关属性）。
fn wp_real_xfce_props() -> Array[String] {
  let all = wp_lines([
    "/backdrop/screen0/monitorHDMI-0/workspace0/color-style", "/backdrop/screen0/monitorHDMI-0/workspace0/image-style",
    "/backdrop/screen0/monitorHDMI-0/workspace0/last-image", "/backdrop/screen0/monitorHDMI-0/workspace1/color-style",
    "/backdrop/screen0/monitorHDMI-0/workspace1/image-style", "/backdrop/screen0/monitorHDMI-0/workspace1/last-image",
    "/backdrop/screen0/monitorHDMI-0/workspace2/last-image", "/backdrop/screen0/monitorHDMI-0/workspace3/last-image",
    "/backdrop/screen0/monitorHDMI-2/workspace0/last-image", "/backdrop/screen0/monitorHDMI-2/workspace1/last-image",
    "/backdrop/screen0/monitorHDMI-2/workspace2/last-image", "/backdrop/screen0/monitorHDMI-2/workspace3/last-image",
    "/backdrop/screen0/monitorNone-1/workspace0/color-style", "/backdrop/screen0/monitorNone-1/workspace0/image-style",
    "/backdrop/screen0/monitorNone-1/workspace0/last-image",
  ])
  let props : Array[String] = []
  for line in wp_split_lines(all) {
    if wp_is_last_image_prop(line) {
      props.push(wp_trim(line))
    }
  }
  props
}

///|
test "wp_parse_backdrop_prop：真实属性路径解析" {
  match
    wp_parse_backdrop_prop(
      "/backdrop/screen0/monitorHDMI-0/workspace0/last-image",
    ) {
    Some(p) => {
      assert_eq(p.monitor, "HDMI-0")
      assert_eq(p.workspace, 0)
    }
    None => assert_true(false)
  }
  // monitorNone-1 为未单独配置输出的兜底项
  match
    wp_parse_backdrop_prop(
      "/backdrop/screen0/monitorNone-1/workspace0/last-image",
    ) {
    Some(p) => {
      assert_eq(p.monitor, "None-1")
      assert_eq(p.workspace, 0)
    }
    None => assert_true(false)
  }
  // 非 0 工作区
  match
    wp_parse_backdrop_prop(
      "/backdrop/screen0/monitorHDMI-0/workspace3/last-image",
    ) {
    Some(p) => assert_eq(p.workspace, 3)
    None => assert_true(false)
  }
  // 首尾空白容忍
  match
    wp_parse_backdrop_prop(
      "  /backdrop/screen0/monitorDP-1/workspace1/last-image  ",
    ) {
    Some(p) => assert_eq(p.monitor, "DP-1")
    None => assert_true(false)
  }
  // 形态不符：空监控名 / 工作区无数字 / 段数不对 / 非 last-image
  assert_true(
    wp_parse_backdrop_prop("/backdrop/screen0/monitor/workspace0/last-image")
    is None,
  )
  assert_true(
    wp_parse_backdrop_prop("/backdrop/screen0/monitorA/workspace/last-image")
    is None,
  )
  assert_true(
    wp_parse_backdrop_prop("/backdrop/screen0/monitorA/last-image") is None,
  )
  assert_true(
    wp_parse_backdrop_prop("/backdrop/screen0/monitorA/workspace0/image-style")
    is None,
  )
  assert_true(wp_parse_backdrop_prop("") is None)
}

///|
test "wp_is_last_image_prop：属性行筛选（剔除 color/image-style）" {
  assert_true(
    wp_is_last_image_prop(
      "/backdrop/screen0/monitorHDMI-0/workspace0/last-image",
    ),
  )
  assert_true(
    wp_is_last_image_prop(
      "  /backdrop/screen0/monitorHDMI-0/workspace0/last-image  ",
    ),
  )
  assert_false(
    wp_is_last_image_prop(
      "/backdrop/screen0/monitorHDMI-0/workspace0/color-style",
    ),
  )
  assert_false(
    wp_is_last_image_prop(
      "/backdrop/screen0/monitorHDMI-0/workspace0/image-style",
    ),
  )
  assert_false(wp_is_last_image_prop(""))
}

///|
test "wp_select_last_image_prop：真实属性清单 + 已连接输出" {
  // 本机真实清单（已过滤 color-style/image-style），已连接输出取自
  // xrandr：HDMI-0（主输出）与 HDMI-2；应首选 HDMI-0 的 workspace0
  let props = wp_real_xfce_props()
  assert_eq(props.length(), 9)
  assert_eq(
    wp_select_last_image_prop(props, ["HDMI-0", "HDMI-2"]),
    Some("/backdrop/screen0/monitorHDMI-0/workspace0/last-image"),
  )
  // 已连接输出不含任何候选（拔掉显示器留下的陈旧项全排除）→ 退化为
  // 首个 workspace0 项
  assert_eq(
    wp_select_last_image_prop(props, ["eDP-9"]),
    Some("/backdrop/screen0/monitorHDMI-0/workspace0/last-image"),
  )
  // 已连接列表为空（xrandr 不可用）同样退化首个 workspace0
  assert_eq(
    wp_select_last_image_prop(props, []),
    Some("/backdrop/screen0/monitorHDMI-0/workspace0/last-image"),
  )
  // 只有非 0 工作区 → 取首个可解析项
  let ws3only = ["/backdrop/screen0/monitorHDMI-0/workspace3/last-image"]
  assert_eq(
    wp_select_last_image_prop(ws3only, ["HDMI-0"]),
    Some("/backdrop/screen0/monitorHDMI-0/workspace3/last-image"),
  )
  // 候选里没有 workspace0：前两轮都落空，第三轮只按清单顺序取首个可解析
  // 项（不再看已连接）——DP-9 那条虽未连接仍在前
  let no_ws0 = [
    "/backdrop/screen0/monitorDP-9/workspace2/last-image",
    "/backdrop/screen0/monitorHDMI-0/workspace1/last-image",
  ]
  assert_eq(
    wp_select_last_image_prop(no_ws0, ["HDMI-0"]),
    Some("/backdrop/screen0/monitorDP-9/workspace2/last-image"),
  )
  // 无候选
  assert_true(wp_select_last_image_prop([], ["HDMI-0"]) is None)
  assert_true(wp_select_last_image_prop(["/garbage"], ["HDMI-0"]) is None)
}

///|
test "wp_parse_uint / wp_parse_gsettings_uri / wp_unquote" {
  assert_eq(wp_parse_uint("workspace0", "workspace"), Some(0))
  assert_eq(wp_parse_uint("workspace12", "workspace"), Some(12))
  assert_true(wp_parse_uint("workspace", "workspace") is None)
  assert_true(wp_parse_uint("workspacex", "workspace") is None)
  assert_true(wp_parse_uint("other0", "workspace") is None)
  // gsettings get 输出：单引号包裹的 file:// URI
  assert_eq(
    wp_parse_gsettings_uri("'file:///usr/share/a.png'"),
    Some("/usr/share/a.png"),
  )
  assert_eq(
    wp_parse_gsettings_uri("'file:///usr/share/a.png'\n"),
    Some("/usr/share/a.png"),
  )
  assert_true(wp_parse_gsettings_uri("''") is None) // 未设置
  assert_true(wp_parse_gsettings_uri("'file://'") is None) // 空路径
  assert_eq(
    wp_parse_gsettings_uri("'/plain/path.png'"),
    Some("/plain/path.png"),
  )
  assert_true(wp_parse_gsettings_uri("") is None)
  // 去引号
  assert_eq(wp_unquote("'x'"), "x")
  assert_eq(wp_unquote("x"), "x")
  assert_eq(wp_unquote("'"), "'")
  assert_eq(wp_unquote(""), "")
}

///|
test "wp_xfce_set_args / wp_gnome_set_args：写路径参数" {
  // XFCE：-n 属性不存在则创建，-t string 显式类型
  let xfce = wp_xfce_set_args(
    "/backdrop/screen0/monitorNone-1/workspace0/last-image", "/a.png",
  )
  assert_eq(xfce, [
    "-c", "xfce4-desktop", "-p",
    "/backdrop/screen0/monitorNone-1/workspace0/last-image", "-n", "-t",
    "string", "-s", "/a.png",
  ])
  // GNOME：写 picture-uri，值转 file:// URI
  assert_eq(wp_gnome_set_args("picture-uri", "/a.png"), [
    "set", "org.gnome.desktop.background", "picture-uri", "file:///a.png",
  ])
  assert_eq(wp_gnome_set_args("picture-uri-dark", "/b.png"), [
    "set", "org.gnome.desktop.background", "picture-uri-dark",
    "file:///b.png",
  ])
}

///|
test "wp_kde 脚本 / wp_escape_js_squote：Plasma evaluateScript" {
  let read = wp_kde_read_script()
  assert_true(read.contains("desktops()"))
  assert_true(read.contains("readConfig"))
  assert_true(read.contains("print(img)"))
  // 写脚本：切 org.kde.image 插件并写 file:// URI
  let write = wp_kde_write_script("/a.png")
  assert_true(write.contains("d.wallpaperPlugin = 'org.kde.image'"))
  assert_true(write.contains("d.writeConfig('Image'"))
  assert_true(write.contains("'file:///a.png'"))
  // JS 单引号字面量转义：路径含单引号时前置反斜杠
  assert_eq(wp_escape_js_squote("/a.png"), "/a.png")
  assert_eq(wp_escape_js_squote("/a'b.png"), "/a\\'b.png")
  assert_true(wp_kde_write_script("/a'b.png").contains("file:///a\\'b.png"))
}

///|
test "wp_split_lines / wp_trim / wp_strip_prefix / wp_first_line：文本工具" {
  assert_eq(wp_split_lines("a\nb\r\n\nc"), ["a", "b", "c"])
  assert_eq(wp_split_lines(""), [])
  assert_eq(wp_trim("  /a.png \n"), "/a.png")
  assert_eq(wp_trim(""), "")
  assert_eq(wp_strip_prefix("file:///a", "file://"), Some("/a"))
  assert_eq(wp_strip_prefix("file://", "file://"), Some(""))
  assert_true(wp_strip_prefix("/a", "file://") is None)
  assert_eq(wp_first_line("err1\nerr2"), "err1")
  assert_eq(wp_first_line(""), "")
}

///|
test "wp 参数防御与平台门错误文案" {
  // 空路径：不落子进程就 InvalidParam
  match wp_set("") {
    Err(InvalidParam(m)) => assert_eq(m, "壁纸路径为空")
    _ => assert_true(false)
  }
  match wp_set("   ") {
    Err(InvalidParam(_)) => assert_true(true)
    _ => assert_true(false)
  }
  // 错误枚举的 Show 文案（诊断面）
  assert_eq(
    WallpaperError::UnknownDesktop("Hyprland").to_string(),
    "WallpaperError::UnknownDesktop(Hyprland)",
  )
  assert_eq(
    WallpaperError::CommandFailed("x").to_string(),
    "WallpaperError::CommandFailed(x)",
  )
  assert_eq(
    WallpaperError::ParseFailed("y").to_string(),
    "WallpaperError::ParseFailed(y)",
  )
  assert_eq(
    WallpaperError::Unsupported.to_string(),
    "WallpaperError::Unsupported",
  )
}

///|
test "wp 真机只读冒烟：已连接输出与 XFCE 读当前壁纸" {
  if !pr_available() {
    println("wp: skip (not linux)")
    return
  }
  // xrandr 可用时（子进程环境带 DISPLAY）应枚举到已连接输出
  let connected = wp_connected_outputs()
  println("wp connected outputs: \{connected.length()}")
  match desktop_detect() {
    Xfce =>
      match wp_get() {
        Ok(path) => {
          // 本机当前壁纸（真机实测 2026-10-07：
          // /usr/share/xfce4/backdrops/Dolomites_by_Felix_Hartlieb.jpg）
          println("wp: \{path}")
          assert_true(path.length() > 0)
          assert_true(path.has_prefix("/"))
        }
        Err(e) => {
          println("wp_get failed: \{e}")
          assert_true(false)
        }
      }
    _ => println("wp: 读壁纸跳过（desktop = \{desktop_name()}）")
  }
}

///|
test "wp Windows 直调读数环：get 非空路径 + 原值 round-trip set" {
  if sys_platform() != "windows" {
    println("wp: skip (windows-only 读数环)")
    return
  }
  match wp_get() {
    Ok(path) => {
      assert_true(path.length() > 0)
      // round-trip：写回当前壁纸（视觉无变化）验证 SPI_SET 通道
      match wp_set(path) {
        Ok(_) => println("wp: set round-trip ok")
        Err(e) => {
          println("wp_set failed: \{e}")
          assert_true(false)
        }
      }
    }
    Err(e) => {
      println("wp_get failed: \{e}")
      assert_true(false)
    }
  }
}
