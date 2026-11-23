@echo off
setlocal
rem ===========================================================================
rem  Clone this repository and install LOVE, for a machine that has neither.
rem
rem      bootstrap.bat                  clone into .\love2d-undertale-template
rem      bootstrap.bat -Dir D:\dev\se   clone somewhere else
rem      bootstrap.bat -Update          pull --ff-only in an existing clone
rem      bootstrap.bat -Zip             snapshot download, works without git
rem      bootstrap.bat -SkipLOVE        clone only
rem
rem  Nothing else is needed up front: PowerShell 5.1 ships with Windows, and if
rem  git is missing the script falls back to a zip snapshot.
rem ===========================================================================

set "PS=powershell.exe"
where pwsh.exe >nul 2>nul && set "PS=pwsh.exe"

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" %*
set "RC=%ERRORLEVEL%"

set "PAUSE_AT_END=0"
if not "%~1"=="" goto :after_pause_check
echo %cmdcmdline% | find /i "%~nx0" >nul && set "PAUSE_AT_END=1"
:after_pause_check
if not "%RC%"=="0" echo [ERROR] bootstrap failed with exit code %RC%
if "%PAUSE_AT_END%"=="1" pause
exit /b %RC%
