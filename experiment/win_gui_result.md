# Windows GUI pragma 实测结果

- run: https://github.com/lb091188/moonbit-libyue/actions/runs/35563010335

| 例子 | stub | PE Subsystem |
|---|---|---|
| hello | 无(对照组) | CONSOLE(3) |
| hello-themed | 纯 pragma(A) | CONSOLE(3) |
| showcase | pragma+被引用符号(B) | GUI(2) |

## 链接命令行摘录(围绕 /subsystem 与 win_gui 各取窗口)

```
runtime.c utf.c win_gui.c win_gui.c sync_io.c env.c backtrace.c cl : Command line warning D9002 : ignoring unknown option '/SUBSYSTEM:WINDOWS' hello.c    Creating library D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello\hello.lib and object D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello\hello.exp cl : Command line warning D9002 : ignoring unknown option 
```
```
runtime.c utf.c win_gui.c win_gui.c sync_io.c env.c backtrace.c cl : Command line warning D9002 : ignoring unknown option '/SUBSYSTEM:WINDOWS' hello.c    Creating library D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello\hello.lib and object D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello\hello.exp cl : Command line warning D9002 : ignoring unknown option '/SUBSYSTE
```
```
runtime.c utf.c win_gui.c win_gui.c sync_io.c env.c backtrace.c cl : Command line warning D9002 : ignoring unknown option '/SUBSYSTEM:WINDOWS' hello.c    Creating library D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello\hello.lib and object D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello\hello.exp cl : Command line warning D9002 : ignoring unknown option '/SUBSYSTEM:WINDOWS' hello-themed.c    Creating library D:\a\moonbit-libyue\moonbit-libyue\_build\native\re
```
```
in_gui.c win_gui.c sync_io.c env.c backtrace.c cl : Command line warning D9002 : ignoring unknown option '/SUBSYSTEM:WINDOWS' hello.c    Creating library D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello\hello.lib and object D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello\hello.exp cl : Command line warning D9002 : ignoring unknown option '/SUBSYSTEM:WINDOWS' hello-themed.c    Creating library D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello-themed\hello-themed.lib and object D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello-themed\hello-themed.exp cl : Command line warning D9002 : ignoring unknown option '/SUBSYSTEM:WINDOWS' showcase.c    Creating library D:\a\moonbit-libyue\
```
```
o\hello.exp cl : Command line warning D9002 : ignoring unknown option '/SUBSYSTEM:WINDOWS' hello-themed.c    Creating library D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello-themed\hello-themed.lib and object D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\hello-themed\hello-themed.exp cl : Command line warning D9002 : ignoring unknown option '/SUBSYSTEM:WINDOWS' showcase.c    Creating library D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\showcase\showcase.lib and object D:\a\moonbit-libyue\moonbit-libyue\_build\native\release\build\examples\showcase\showcase.exp Finished. moon: ran 21 tasks, now up to date 
```
