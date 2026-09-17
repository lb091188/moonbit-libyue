@echo off
chcp 65001 >nul
setlocal
rem ============================================================
rem 一键同步:共享盘仓库 -> 本地构建目录
rem 只覆盖源码,保留本地的 build(CMake 缓存)与 _build(moon 产物)
rem 用法: sync_to_test.bat [源目录] [构建: y/n]
rem   源目录默认 Z:\moonbit-libyue,按实际共享盘盘符修改或传参
rem ============================================================
set "SRC=%~1"
set "DST=C:\moon-libyue-test"
if "%SRC%"=="" set "SRC=Z:\moonbit-libyue"

if not exist "%SRC%\moon.mod" (
  echo [错误] 源目录不存在或不是仓库根: %SRC%
  echo 用法: sync_to_test.bat [源目录] [y/n]
  pause
  exit /b 1
)
if not exist "%DST%\moon.mod" (
  echo [错误] 目标目录不存在: %DST%
  pause
  exit /b 1
)

echo [1/2] 同步 %SRC% -^> %DST% ...
rem /E 含子目录; /XD 排除目录(.git/build/_build 不覆盖); /XF 排除文件
rem 不用 /MIR:不删除目标多余文件,保住 build/_build
robocopy "%SRC%" "%DST%" /E /XD .git build _build /XF prepare_log.txt probe.log /NJH /NP /NFL /NDL >nul
if errorlevel 8 (
  echo [错误] robocopy 失败, 退出码 %errorlevel%
  pause
  exit /b 1
)
echo     同步完成。

set "DOBUILD=%~2"
if "%DOBUILD%"=="" set /p DOBUILD=是否立即构建? y=构建, 其他=跳过:
if /i not "%DOBUILD%"=="y" (
  echo 完成。需要构建时在 %DST% 下执行: python scripts\prepare.py ^&^& moon build
  pause
  exit /b 0
)

echo [2/2] 构建中...
cd /d "%DST%"
python scripts\prepare.py
if errorlevel 1 (
  echo [错误] 原生层准备失败
  pause
  exit /b 1
)
moon build
if errorlevel 1 (
  echo [错误] moon build 失败, 见上方输出
  echo 若提示链接旧 exe, 删除 _build 下对应 exe 后重跑 moon build
  pause
  exit /b 1
)
echo 构建完成。示例: moon run examples\probe
pause
