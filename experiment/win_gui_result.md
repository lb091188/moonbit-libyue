# Windows GUI 子系统验证结果

- run: https://github.com/lb091188/moonbit-libyue/actions/runs/35564629198

| 例子 | PE Subsystem |
|---|---|
| hello | GUI(2) |
| hello-themed | GUI(2) |
| showcase | GUI(2) |

## 链接命令行摘录(围绕 /subsystem 与 win_gui 各取窗口)

```
runtime.c utf.c win_gui.c env.c sync_io.c backtrace.c hello.c    Creating library D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello\hello.lib and object D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello\hello.exp hello-themed.c    Creating library D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello-themed\hello-themed.lib and object
```
