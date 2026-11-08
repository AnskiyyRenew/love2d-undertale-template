@echo off
setlocal
cd /d "%~dp0"

rem --- Locate a Python that actually has tkinter ---------------------------
rem build_tool.py is a tkinter GUI. Some Python installs on PATH (embedded or
rem trimmed builds) ship without tkinter, and the tool then dies with
rem     ModuleNotFoundError: No module named 'tkinter'
rem A candidate is therefore only accepted after the import really succeeds.
rem Force a specific interpreter with:  set SE_PYTHON=D:\some\python.exe

set "PYFULL="
set "PYW="

if defined SE_PYTHON if exist "%SE_PYTHON%" (
    "%SE_PYTHON%" -c "import tkinter" >nul 2>nul && set "PYFULL=%SE_PYTHON%"
)

if not defined PYFULL call :pick python.exe
if not defined PYFULL call :pick python3.exe
if not defined PYFULL call :pick python3.13.exe
if not defined PYFULL goto :nopython
rem pythonw keeps the console hidden; it sits next to the chosen python.exe.
for %%I in ("%PYFULL%") do if exist "%%~dpIpythonw.exe" set "PYW=%%~dpIpythonw.exe"

if exist "%~dp0error.log" del /q "%~dp0error.log" >nul 2>nul

rem --- Run -----------------------------------------------------------------
if defined PYW (
    start "" "%PYW%" "%~dp0build_tool.py"
) else (
    "%PYFULL%" "%~dp0build_tool.py"
    if errorlevel 1 (
        echo.
        echo [ERROR] The packager exited with an error.
        echo Details were written to "error.log" next to this file.
        echo Run manually to see the full error:
        echo     "%PYFULL%" "%~dp0build_tool.py"
        echo.
        pause
    )
)
endlocal
exit /b 0

rem --- Helpers -------------------------------------------------------------
:pick
rem %1 = exe name. Scan EVERY match on PATH in order: the first python.exe is
rem often a bundled/embedded build without tkinter, while a full install
rem further down PATH has it.
for /f "delims=" %%P in ('where %1 2^>nul') do (
    if not defined PYFULL (
        "%%P" -c "import tkinter" >nul 2>nul && set "PYFULL=%%P"
    )
)
goto :eof

:nopython
echo.
echo [ERROR] No Python 3 with tkinter was found on PATH.
echo Python without tkinter cannot run this GUI tool.
echo Install it from https://www.python.org/downloads/ and tick
echo "Add python.exe to PATH", or point this script at one directly:
echo.
echo     set SE_PYTHON=D:\Python313\python.exe
echo     run.bat
echo.
pause
exit /b 1
