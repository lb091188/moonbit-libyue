// 打开外部纯函数测试:父目录解析。

///|
test "parent_dir" {
  inspect(parent_dir("/a/b/c.txt"), content="/a/b")
  inspect(parent_dir("/c"), content="/")
  inspect(parent_dir("/"), content="/")
  inspect(parent_dir("a.txt"), content=".")
  inspect(parent_dir(""), content=".")
  // 多级深路径取最近一层
  inspect(parent_dir("/opt/my app/bin/run.exe"), content="/opt/my app/bin")
}
