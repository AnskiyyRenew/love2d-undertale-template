@echo off
setlocal
cd /d "%~dp0"

rem --- Locate a Python launcher -------------------------------------------
set "PYEXE="
where pythonw >nul 2>nul && set "PYEXE=pythonw"
if not defined PYEXE where python >nul 2>nul && set "PYEXE=python"

if not defined PYEXE (
    echo.
    echo [ERROR] Python 3 was not found on PATH.
    echo Please install it from https://www.python.org/downloads/
    echo and make sure "Add python.exe to PATH" is checked.
    echo.
    pause
    exit /b 1
)

rem --- Run -----------------------------------------------------------------
if "%PYEXE%"=="pythonw" (
    rem Launch without a console window. If the tool crashes, the traceback
    rem is saved to "error.log" next to this file.
    start "" pythonw "%~dp0build_tool.py"
) else (
    python "%~dp0build_tool.py"
    if errorlevel 1 (
        echo.
        echo [ERROR] The packager exited with an error.
        echo Details were written to "error.log" next to this file.
        echo Run manually to see the full error:
        echo     python "%~dp0build_tool.py"
        echo.
        pause
    )
)
endlocal
