@echo off
setlocal
rem ===========================================================================
rem  Run the game with the portable LOVE installed by setup\install.bat.
rem
rem  Looks in this order: %SE_LOVE%, Packager\tools\love, then PATH.
rem  lovec.exe (the console build) is preferred so print() output stays
rem  visible; set SE_LOVE=...\love.exe to get rid of the console window.
rem
rem  Extra arguments are forwarded to LOVE, e.g.  play.bat --console
rem ===========================================================================

cd /d "%~dp0.."
set "ROOT=%CD%"
set "LOVE="

if defined SE_LOVE if exist "%SE_LOVE%" set "LOVE=%SE_LOVE%"
if not defined LOVE if exist "%~dp0tools\love\lovec.exe" set "LOVE=%~dp0tools\love\lovec.exe"
if not defined LOVE if exist "%~dp0tools\love\love.exe" set "LOVE=%~dp0tools\love\love.exe"
if not defined LOVE (
    for /f "delims=" %%P in ('where love.exe 2^>nul') do (
        if not defined LOVE set "LOVE=%%P"
    )
)

if not defined LOVE goto :nolove

rem %* forwards "--console", "--fused" and anything else to the game.
"%LOVE%" "%ROOT%" %*
exit /b %ERRORLEVEL%

:nolove
echo.
echo [ERROR] LOVE was not found.
echo   install it with:  Packager\setup\install.bat
echo   or point SE_LOVE at an existing love.exe:
echo       set SE_LOVE=D:\LOVE\love.exe
echo.
pause
exit /b 1
