# Windows GUI 子系统验证

要解决的问题：MoonBit native 后端产出的 exe 默认是控制台（CONSOLE(3)）子系统，
双击会先弹一个控制台窗口。机制与实现细节见 `docs/zh/adaptation.md`「链接参数」节；
本文件只留可复核的读数。

## 本地实测（2026-10-12，Windows + MSVC）

```
moon build examples/hello examples/hello-themed examples/showcase --target native --release --strip
```

| 例子 | PE OptionalHeader.Subsystem | 结论 |
|---|---|---|
| hello | 2 | GUI —— 双击不弹控制台黑框 |
| hello-themed | 2 | 同上 |
| showcase | 2 | 同上 |

- **无任何后处理**：PE 头没有被改写，2 这个值直接来自 `gui/win/win_gui.c` 的链接
  pragma（`/SUBSYSTEM:WINDOWS` + `/ENTRY:mainCRTStartup`）。
- 读法：`PE = u32@0x3C`，`Subsystem = u16@(PE + 4 + 20 + 68)`（2 = GUI，3 = CONSOLE）。
- 链接命令行里能看到 `win_gui.c` 与示例的 `hello.c` 一起被编进本次 exe 构建。
- 测试 exe 对照：只有代码路径走到 `init_backend()` 的才变 GUI(2)
  （实测 `core.whitebox_test.exe`、`ui.whitebox_test.exe`），其余仍为 CONSOLE(3)；
  库门禁 830 条 / 825 过（5 条红是既有的 dbus 会话总线与 `fsx_wbtest.mbt:109`），
  说明 GUI 子系统不影响测试框架经管道读取 stdout。
- CI（`.github/workflows/release-bin.yml` 的「校验 PE 子系统为 GUI(去黑框)」步骤）
  对同一字段断言 `== 2`，不满足即让构建失败——机制回归要立刻可见。
