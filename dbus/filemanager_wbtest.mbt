// FileManager1 客户端纯函数测试:file URI 百分号编码。

///|
test "file_uri:普通路径原样" {
  assert_eq(file_uri("/opt/app/x.txt"), "file:///opt/app/x.txt")
}

///|
test "file_uri:空格与中文按 UTF-8 字节编码" {
  assert_eq(file_uri("/opt/my app/x"), "file:///opt/my%20app/x")
  assert_eq(file_uri("/home/u/文档/报告.doc"), // 文=E69687 档=E6A1A3 报=E68AA5 告=E5918A
    "file:///home/u/%E6%96%87%E6%A1%A3/%E6%8A%A5%E5%91%8A.doc")
}

///|
test "file_uri:保留字符 %XX" {
  assert_eq(file_uri("/a/b&c?d=e%f"), "file:///a/b%26c%3Fd%3De%25f")
  assert_eq(file_uri("/a+b=c"), "file:///a%2Bb%3Dc")
}

///|
test "file_uri:unreserved 不编码" {
  assert_eq(file_uri("/a-Z_9.~x/file.name"), "file:///a-Z_9.~x/file.name")
}
