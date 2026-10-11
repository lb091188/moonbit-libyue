// 系统剪贴板白盒测试：真写-读回环（Windows 走 CF_UNICODETEXT，Linux/mac 走
// xclip/pbpaste）。写入前先把原内容存档、断言完还原——探针不该在使用者的
// 剪贴板里留痕；不可用的环境（无 xclip、剪贴板被别家占着）只打印跳过。

///|
test "clipboard：set → get 回环（含中文与换行，写完还原）" {
  if !clipboard_available() {
    println("clipboard: skip (无系统剪贴板)")
    return
  }
  let saved = clipboard_get_text()
  let probe = "yue-clip 探针·第一行\n第二行"
  if !clipboard_set_text(probe) {
    println("clipboard: skip (写入失败，可能被别的进程占着)")
    return
  }
  let got = clipboard_get_text()
  // 还原：原本为空就写回空串（Windows 的 CF_UNICODETEXT 没有「清空」语义，
  // 空串是它的最近似）
  match saved {
    Some(s) => {
      let _ = clipboard_set_text(s)
    }
    None => {
      let _ = clipboard_set_text("")
    }
  }
  assert_eq(got, Some(probe))
}

///|
test "clipboard：探测结果与平台一致" {
  match sys_platform() {
    // Win32 API 恒在
    "windows" => assert_true(clipboard_available())
    "linux" | "macos" =>
      // 命令线不可用时读也必须为空（探测与行为自洽）
      if !clipboard_available() {
        assert_true(clipboard_get_text() is None)
      }
    _ => assert_true(!clipboard_available())
  }
}
