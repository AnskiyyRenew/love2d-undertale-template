@echo off
setlocal
cd /d "%~dp0"

rem --- Locate a Python interpreter ------------------------------------------
set "PYEXE="
where python >nul 2>nul && set "PYEXE=python"
if not defined PYEXE (
    echo.
    echo [ERROR] Python 3 was not found on PATH.
    echo Please install it from https://www.python.org/downloads/
    echo and make sure "Add python.exe to PATH" is checked.
    echo.
    pause
    exit /b 1
)

rem --- Run the Lua compatibility checker ------------------------------------
rem 无参数时按"严格度 2 = exe / Linux"检查项目根目录（本工具上一级，含 main.lua）。
rem 注意 check_compat.py 自己的默认值是 3，这个 .bat 特意降到 2：
rem 本项目发布目标是桌面 exe，love.js 那套 5.1 语法限制用不上。
rem 也可以带参数，例如：
rem     check_compat.bat --strict 1         按 Windows 开发端检查
rem     check_compat.bat --strict 3         按 love.js 检查
rem     check_compat.bat --all              三种严格度全部输出
rem     check_compat.bat "D:\other\game"    检查其它项目目录

if "%~1"=="" (
    "%PYEXE%" "%~dp0check_compat.py" --strict 2
) else (
    "%PYEXE%" "%~dp0check_compat.py" %*
)
echo.
echo ---------------------------------------------------------------
pause
endlocal
