// 开机自启动（W21d）回归。分两档：
//   ① 纯函数（目录解析 / Exec 转义 / .desktop 内容与解析 / Run 值形态 /
//      app_id 校验 / 错误 Show）——无后端依赖，任何平台都可跑；
//   ② 生命周期（enable → is_enabled → 落点可读 → disable → 幂等再 disable）——
//      **真实落盘 / 真实写注册表**，只在 `autostart_supported()` 的平台上跑
//      （macOS 本批 Unsupported 时自动跳过，不造假）。
//
// 生命周期用的是探针专属 app_id，且**开头与结尾都先 disable**：开头那次是防
// 上一次跑到一半崩掉留下的陈旧条目，结尾那次是清场。

///|
const AUTOSTART_TEST_APP_ID : String = "com.moonbit.libyue.autostart_probe"

///|
fn autostart_show(e : AutostartError) -> String {
  e.to_string()
}

///|
test "autostart_dir_of：XDG 优先、HOME 回退、都没有给 None" {
  assert_eq(
    autostart_dir_of(Some("/tmp/xdg"), Some("/home/u")),
    Some("/tmp/xdg/autostart"),
  )
  // XDG 设了但为空串 → 视为未设，回退 HOME
  assert_eq(
    autostart_dir_of(Some(""), Some("/home/u")),
    Some("/home/u/.config/autostart"),
  )
  assert_eq(
    autostart_dir_of(None, Some("/home/u")),
    Some("/home/u/.config/autostart"),
  )
  assert_eq(autostart_dir_of(None, None), None)
  assert_eq(autostart_dir_of(Some(""), Some("")), None)
  assert_eq(autostart_dir_of(Some("/x"), None), Some("/x/autostart"))
}

///|
test "autostart_escape_exec：双引号包裹 + 反斜杠/引号转义 + % 翻倍" {
  assert_eq(autostart_escape_exec("/usr/bin/app"), "\"/usr/bin/app\"")
  // 空格在引号内原样
  assert_eq(
    autostart_escape_exec("/opt/my app/app"),
    "\"/opt/my app/app\"",
  )
  // 中文原样
  assert_eq(autostart_escape_exec("/opt/应用/app"), "\"/opt/应用/app\"")
  // 双引号与反斜杠转义
  assert_eq(autostart_escape_exec("a\"b"), "\"a\\\"b\"")
  assert_eq(autostart_escape_exec("a\\b"), "\"a\\\\b\"")
  // % 字段码翻倍
  assert_eq(autostart_escape_exec("a%b"), "\"a%%b\"")
}

///|
test "autostart_desktop_entry / desktop_enabled：内容与解析两态" {
  let input = autostart_desktop_entry("/usr/bin/app", "com.example.App")
  assert_true(input.has_prefix("[Desktop Entry]\n"))
  assert_true(input.contains("Type=Application"))
  assert_true(input.contains("Name=com.example.App"))
  assert_true(input.contains("Exec=\"/usr/bin/app\""))
  assert_true(input.contains("Hidden=false"))
  assert_true(input.contains("X-GNOME-Autostart-enabled=true"))
  // 默认形态判启用
  assert_true(autostart_desktop_enabled(input))
  // 系统侧开关位两态
  assert_false(autostart_desktop_enabled("Hidden=true\n"))
  assert_false(
    autostart_desktop_enabled("X-GNOME-Autostart-enabled=false\n"),
  )
  // 缺行不算禁用（宽松：老 .desktop 没有这些键）
  assert_true(autostart_desktop_enabled("[Desktop Entry]\nType=Application\n"))
  // Hidden=false 明确启用
  assert_true(autostart_desktop_enabled("Hidden=false\n"))
}

///|
test "autostart_run_value / run_value_exe：引号形态与反解" {
  assert_eq(autostart_run_value("C:/a b/app.exe"), "\"C:/a b/app.exe\"")
  assert_eq(
    autostart_run_value_exe("\"C:/a b/app.exe\""),
    Some("C:/a b/app.exe"),
  )
  // 裸路径（调用方自己写的）原样认
  assert_eq(
    autostart_run_value_exe("C:/app.exe"),
    Some("C:/app.exe"),
  )
  // 空 / 只有一对空引号 → None
  assert_eq(autostart_run_value_exe(""), None)
  assert_eq(autostart_run_value_exe("\"\""), None)
  // 往返：写进去的读回来等价
  assert_eq(
    autostart_run_value_exe(autostart_run_value("C:/x/y.exe")),
    Some("C:/x/y.exe"),
  )
}

///|
test "autostart_valid_app_id：点分元素与字符集" {
  assert_true(autostart_valid_app_id("com.example.app"))
  assert_true(autostart_valid_app_id("org.moonbit_libyue.Showcase"))
  assert_true(autostart_valid_app_id("a.b"))
  assert_true(autostart_valid_app_id("com.example.my-app2"))
  assert_false(autostart_valid_app_id("nodots"))
  assert_false(autostart_valid_app_id("com..app"))
  assert_false(autostart_valid_app_id(".com.app"))
  assert_false(autostart_valid_app_id("com.app."))
  assert_false(autostart_valid_app_id("com.2app")) // 元素不能以数字开头
  assert_false(autostart_valid_app_id("com.-app")) // 元素不能以 '-' 开头
  assert_false(autostart_valid_app_id("com.exa mple")) // 空格非法
  assert_false(autostart_valid_app_id(""))
}

///|
test "AutostartError 的 Show：四档都能打出来" {
  assert_eq(autostart_show(Unsupported), "AutostartError::Unsupported")
  assert_eq(autostart_show(InvalidAppId), "AutostartError::InvalidAppId")
  assert_eq(
    autostart_show(NoExecutablePath),
    "AutostartError::NoExecutablePath",
  )
  assert_eq(
    autostart_show(IoFailed("x")),
    "AutostartError::IoFailed(x)",
  )
}

///|
test "非法 app_id 在任何平台都先被拒（不落盘/不写注册表）" {
  assert_true(autostart_is_enabled("nodots") is Err(InvalidAppId))
  assert_true(autostart_enable("nodots") is Err(InvalidAppId))
  assert_true(autostart_disable("nodots") is Err(InvalidAppId))
}

///|
test "生命周期：enable → is_enabled → disable → 幂等再 disable（无后端自动跳过）" {
  if !autostart_supported() {
    println("autostart: 本平台不支持，跳过生命周期")
    return
  }
  // 当前可执行文件路径必须拿得到（enable 依赖它）
  match autostart_exe_path() {
    Some(p) => assert_true(p.length() > 0)
    None => fail("autostart_exe_path() 取不到可执行文件路径")
  }
  // 落点可定位
  let path = match autostart_path(AUTOSTART_TEST_APP_ID) {
    Ok(p) => p
    Err(e) => fail("autostart_path 失败: " + autostart_show(e))
  }
  assert_true(path.length() > 0)
  // 清场（防上次残留）
  let _ = autostart_disable(AUTOSTART_TEST_APP_ID)
  // 未启用
  let before = match autostart_is_enabled(AUTOSTART_TEST_APP_ID) {
    Ok(b) => b
    Err(e) => fail("is_enabled 失败: " + autostart_show(e))
  }
  assert_false(before)
  // 启用
  match autostart_enable(AUTOSTART_TEST_APP_ID) {
    Ok(_) => ()
    Err(e) => fail("enable 失败: " + autostart_show(e))
  }
  let after = match autostart_is_enabled(AUTOSTART_TEST_APP_ID) {
    Ok(b) => b
    Err(e) => fail("is_enabled(启用后) 失败: " + autostart_show(e))
  }
  assert_true(after)
  // 落点可读回（Linux = .desktop 正文；Windows = Run 值）
  if sys_platform() == "linux" {
    match sys_read_text_file(path) {
      Some(content) => {
        assert_true(autostart_desktop_enabled(content))
        assert_true(
          content.contains("Exec=\"" + autostart_exe_path().unwrap() + "\""),
        )
      }
      None => fail("启用后读不到 .desktop: " + path)
    }
  } else if sys_platform() == "windows" {
    let value = match autostart_win_read(AUTOSTART_TEST_APP_ID) {
      Ok(Some(v)) => v
      Ok(None) => fail("启用后 Run 值读不到")
      Err(e) => fail("读 Run 值失败: " + autostart_show(e))
    }
    assert_eq(
      autostart_run_value_exe(value),
      autostart_exe_path(),
    )
  }
  // 启用幂等（重复 enable 不报错、状态不变）
  match autostart_enable(AUTOSTART_TEST_APP_ID) {
    Ok(_) => ()
    Err(e) => fail("重复 enable 失败: " + autostart_show(e))
  }
  // 禁用
  match autostart_disable(AUTOSTART_TEST_APP_ID) {
    Ok(_) => ()
    Err(e) => fail("disable 失败: " + autostart_show(e))
  }
  let off = match autostart_is_enabled(AUTOSTART_TEST_APP_ID) {
    Ok(b) => b
    Err(e) => fail("is_enabled(禁用后) 失败: " + autostart_show(e))
  }
  assert_false(off)
  // 再禁用：幂等成功
  match autostart_disable(AUTOSTART_TEST_APP_ID) {
    Ok(_) => ()
    Err(e) => fail("幂等 disable 失败: " + autostart_show(e))
  }
  assert_false(autostart_is_enabled(AUTOSTART_TEST_APP_ID).unwrap())
}

test "macOS 的 plist 正文：Label/ProgramArguments/RunAtLoad 与 XML 转义" {
  let p = autostart_mac_plist("com.example.my-app2", "/Applications/My App/a&b<c>.app/Contents/MacOS/x")
  assert_true(p.has_prefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"))
  assert_true(p.has_suffix("</plist>\n"))
  assert_true(p.contains("<string>com.example.my-app2</string>"))
  // & 与 < > 必须转义，否则 plist 不是合法 XML
  assert_true(p.contains("/Applications/My App/a&amp;b&lt;c&gt;.app"))
  assert_false(p.contains("a&b<c>"))
  // 落点：HOME 设了才给目录（本机与 CI 都设，别的读者也可能没设，两态都合法）
  match autostart_mac_dir() {
    None => ()
    Some(d) => assert_true(d.contains("/Library/LaunchAgents"))
  }
}
