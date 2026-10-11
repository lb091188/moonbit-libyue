// 开机自启动纯函数测试：Exec 转义、目录三态拼装、.desktop 启用位解析。

///|
test "Exec 转义" {
  // 空格：整体引号包裹即可
  inspect(escape_exec("/opt/my app/bin"), content="\"/opt/my app/bin\"")
  // 双引号：反斜杠转义
  inspect(escape_exec("/opt/a\"b"), content="\"/opt/a\\\"b\"")
  // 反斜杠：翻倍
  inspect(escape_exec("C:\\apps\\x.exe"), content="\"C:\\\\apps\\\\x.exe\"")
  // $：引号内原样合法（systemd xdg-autostart 生成器按桌面项规范解析）
  inspect(escape_exec("/opt/$HOME/bin"), content="\"/opt/$HOME/bin\"")
  // 中文：原样（UTF-8 直存）
  inspect(escape_exec("/opt/应用/程序"), content="\"/opt/应用/程序\"")
  // %：字段码转义翻倍
  inspect(escape_exec("/opt/100%/bin"), content="\"/opt/100%%/bin\"")
}

///|
test "自启动目录三态拼装" {
  // XDG_CONFIG_HOME 设且非空：优先
  inspect(
    autostart_dir_of(Some("/custom/cfg"), Some("/home/u"))
    is Some("/custom/cfg/autostart"),
    content="true",
  )
  // 空串：回退 HOME
  inspect(
    autostart_dir_of(Some(""), Some("/home/u"))
    is Some("/home/u/.config/autostart"),
    content="true",
  )
  // 未设：回退 HOME
  inspect(
    autostart_dir_of(None, Some("/home/u")) is Some("/home/u/.config/autostart"),
    content="true",
  )
  // 都没有：None
  inspect(autostart_dir_of(None, None) is None, content="true")
  inspect(autostart_dir_of(Some(""), Some("")) is None, content="true")
}

///|
test ".desktop 启用位解析" {
  // 正常写入：启用
  inspect(
    desktop_entry_enabled(
      "[Desktop Entry]\nType=Application\nName=x\nExec=\"/opt/x\"\nHidden=false\nX-GNOME-Autostart-enabled=true\n",
    ),
    content="true",
  )
  // Hidden=true（系统/用户侧禁用开关）：未启用
  inspect(
    desktop_entry_enabled(
      "[Desktop Entry]\nType=Application\nExec=\"/opt/x\"\nHidden=true\n",
    ),
    content="false",
  )
  // GNOME 禁用开关：未启用
  inspect(
    desktop_entry_enabled(
      "[Desktop Entry]\nType=Application\nExec=\"/opt/x\"\nX-GNOME-Autostart-enabled=false\n",
    ),
    content="false",
  )
  // 两开关位缺省（外来 .desktop）：视为启用
  inspect(
    desktop_entry_enabled(
      "[Desktop Entry]\nType=Application\nExec=\"/opt/x\"\n",
    ),
    content="true",
  )
}

///|
test "desktop_entry_content 往返" {
  let content = desktop_entry_content("/opt/my app/x", "com.example.app")
  inspect(desktop_entry_enabled(content), content="true")
  // Exec 行按转义规则可还原出带空格路径（引号包裹形态）
  inspect(content.contains("Exec=\"/opt/my app/x\""), content="true")
}

///|
/// macOS 路径的 LaunchAgent plist 生成与解析（纯函数白盒，无 macOS 真机
/// 也能测）：plist 是 XML，路径里的 & < > 必须转义才不破坏结构。
test "launch_agent_plist 往返" {
  let content = launch_agent_plist("/opt/my app/a&b", "com.example.app")
  inspect(launch_agent_enabled(content), content="true")
  inspect(content.contains("<string>com.example.app</string>"), content="true")
  // 路径按 XML 转义写入：& 变 &amp;，裸 & 不得出现
  inspect(content.contains("/opt/my app/a&amp;b"), content="true")
}

///|
test "launch_agent_enabled 解析" {
  // RunAtLoad 后紧跟 <false/> 是 launchd 的常见禁用写法
  let off =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<plist version="1.0"><dict>
    #|  <key>Label</key><string>com.example.app</string>
    #|  <key>RunAtLoad</key>
    #|  <false/>
    #|</dict></plist>
  inspect(launch_agent_enabled(off), content="false")
  // 有其它键在 RunAtLoad 之前时不能被误判
  let mixed =
    #|<dict>
    #|  <key>KeepAlive</key><true/>
    #|  <key>RunAtLoad</key><false/>
    #|</dict>
  inspect(launch_agent_enabled(mixed), content="false")
  // 没有 RunAtLoad 键 → 未启用
  inspect(launch_agent_enabled("<dict><key>Label</key></dict>"), content="false")
  inspect(launch_agent_enabled(""), content="false")
}

///|
test "xml_escape 转义四个 XML 保留字符" {
  inspect(xml_escape("a&b<c>d\"e"), content="a&amp;b&lt;c&gt;d&quot;e")
  // 中文与空格不是 XML 保留字符，原样保留
  inspect(xml_escape("/opt/中文 路径/x"), content="/opt/中文 路径/x")
}
