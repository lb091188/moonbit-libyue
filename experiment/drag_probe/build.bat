@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
cd /d "%~dp0"
cl /nologo /W4 /utf-8 /O2 /DWIN32 /D_WINDOWS /DUNICODE /D_UNICODE dragdnd_probe.c /Fe:dragdnd_probe.exe user32.lib gdi32.lib imm32.lib advapi32.lib windowscodecs.lib ole32.lib shell32.lib uuid.lib
