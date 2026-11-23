@echo off
setlocal
rem ===========================================================================
rem  One-click LOVE setup for Windows: downloads the build configured in
rem  setup.conf and unpacks it into Packager\tools\love (portable, no system
rem  install). Double-click to install, or pass flags:
rem
rem      install.bat              install or refresh
rem      install.bat -Check       environment report only
rem      install.bat -Force       reinstall
rem      install.bat -Url <url>   use a different download URL this time
rem ===========================================================================

set "PS=powershell.exe"
where pwsh.exe >nul 2>nul && set "PS=pwsh.exe"

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "RC=%ERRORLEVEL%"

rem Keep the window open when the batch file was launched by double-click,
rem otherwise the report flashes past and the user sees nothing. Runs that
rem came from a console or a script are left alone so exit codes stay usable.
set "PAUSE_AT_END=0"
if not "%~1"=="" goto :after_pause_check
echo %cmdcmdline% | find /i "%~nx0" >nul && set "PAUSE_AT_END=1"
:after_pause_check
if not "%RC%"=="0" echo [ERROR] setup failed with exit code %RC%
if "%PAUSE_AT_END%"=="1" pause
exit /b %RC%
