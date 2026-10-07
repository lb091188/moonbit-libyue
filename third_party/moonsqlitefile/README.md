# moonsqlitefile（vendored fork）

纯 MoonBit 的只读 SQLite 文件格式解析器，vendored 自
[prowk/MoonSQLiteFile](https://github.com/prowk/MoonSQLiteFile) v0.8.0
（Apache-2.0，LICENSE 原样保留）。上游要求更新 toolchain 的
`Bytes::exact_view`，本仓库按「shim 补探测、能用 MoonBit 解决的不进 C」
原则收编为进程内子包，唯一改动：`record.mbt` 的
`payload.exact_view(start, end)` 换成等价的字节切片语法
`payload[start:end]`（本机 core 0.10.12 即可用）。上游修复跟进时以
diff 最小化同步。
