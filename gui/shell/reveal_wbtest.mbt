///|
/// 「打开并选中」的 URI 拼装：相对路径要按 cwd 解析成绝对路径再百分号编码，
/// 给相对路径或漏了编码，面板只会开父目录（选中态丢失）。
test "reveal_uri 绝对化并编码" {
  assert_eq(reveal_uri("TODO.md", "/home/u/proj"), "file:///home/u/proj/TODO.md")
  assert_eq(reveal_uri("/etc/my app/x.txt", "/tmp"), "file:///etc/my%20app/x.txt")
  assert_eq(reveal_uri("文档/报告.doc", "/home/u"), "file:///home/u/%E6%96%87%E6%A1%A3/%E6%8A%A5%E5%91%8A.doc")
}
