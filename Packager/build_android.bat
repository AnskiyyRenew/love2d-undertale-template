@echo off
setlocal enabledelayedexpansion
rem ===========================================================================
rem  Rebuild the Android APK in one step: game.love -> Gradle -> zipalign -> sign.
rem
rem  Run it from a normal cmd window / double-click. Do NOT launch it from
rem  Git Bash: MSYS leaks pipe handles into Gradle's native builds and ninja
rem  then hangs forever with zero child compilers (seen on this machine).
rem
rem  First run compiles liblove/SDL3/LuaJIT for two ABIs (10-30 min).
rem  Later runs only relink and repackage (about a minute).
rem ===========================================================================

cd /d "%~dp0.."
set "ROOT=%CD%"
set "TOOL=%ROOT%\Packager"
set "TEMPLATE=%TOOL%\love-android"
set "SDK=C:\Users\anski\AppData\Local\Android\Sdk"
set "JDK=C:\Users\anski\jdk17"
set "BT=%SDK%\build-tools\35.0.0"
set "KS=%TOOL%\android\soulengine.keystore"
set "KSPROP=%TOOL%\android\keystore.properties"
set "NAME=soulengine"
set "APK=%TEMPLATE%\app\build\outputs\apk\embedNoRecord\release\app-embed-noRecord-release-unsigned.apk"

if not exist "%TEMPLATE%\gradlew.bat" (
    echo [ERROR] love-android template missing: %TEMPLATE%
    pause
    exit /b 1
)
if not exist "%BT%\apksigner.bat" (
    echo [ERROR] build-tools 35.0.0 missing under %SDK%
    pause
    exit /b 1
)

rem --- 1. pack the game ------------------------------------------------------
echo.
echo [1/4] Packing game.love ...
where python >nul 2>nul
if errorlevel 1 (
    echo [ERROR] python not found on PATH.
    pause
    exit /b 1
)
python "%TOOL%\make_love.py" --name %NAME% || (echo [ERROR] packing failed & pause & exit /b 1)

rem --- 2. drop it into the template's embed assets ---------------------------
echo.
echo [2/4] Copying game.love into app\src\embed\assets ...
copy /y "%ROOT%\Export\%NAME%.love" "%TEMPLATE%\app\src\embed\assets\game.love" >nul || (
    echo [ERROR] copy failed & pause & exit /b 1
)

rem --- 3. gradle -------------------------------------------------------------
echo.
echo [3/4] Running gradlew assembleEmbedNoRecordRelease (this is the slow part) ...
set "JAVA_HOME=%JDK%"
pushd "%TEMPLATE%"
call gradlew.bat assembleEmbedNoRecordRelease --console=plain
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" (
    echo.
    echo [ERROR] Gradle failed with exit code %RC%
    pause
    exit /b 1
)
if not exist "%APK%" (
    echo [ERROR] APK not found: %APK%
    pause
    exit /b 1
)

rem --- 4. align + sign -------------------------------------------------------
echo.
echo [4/4] Aligning and signing ...
if not exist "%KS%" (
    echo [WARN] keystore missing, leaving the APK unsigned: %KS%
    copy /y "%APK%" "%ROOT%\Export\%NAME%-unsigned.apk" >nul
    echo        %ROOT%\Export\%NAME%-unsigned.apk
    pause
    exit /b 0
)
for /f "tokens=1,* delims==" %%A in ('findstr /b "storePassword=" "%KSPROP%"') do set "PW=%%B"

"%BT%\zipalign.exe" -p -f 4 "%APK%" "%ROOT%\Export\%NAME%-aligned.apk" || (
    echo [ERROR] zipalign failed & pause & exit /b 1
)
call "%BT%\apksigner.bat" sign --ks "%KS%" --ks-key-alias soulengine ^
    --ks-pass "pass:%PW%" --key-pass "pass:%PW%" ^
    --out "%ROOT%\Export\%NAME%.apk" "%ROOT%\Export\%NAME%-aligned.apk" || (
    echo [ERROR] apksigner failed & pause & exit /b 1
)
del /q "%ROOT%\Export\%NAME%-aligned.apk" >nul 2>nul

echo.
echo Done.
echo   signed APK: %ROOT%\Export\%NAME%.apk
for %%F in ("%ROOT%\Export\%NAME%.apk") do echo   size:       %%~zF bytes
echo.
echo Install with:  "%SDK%\platform-tools\adb.exe" install -r "%ROOT%\Export\%NAME%.apk"
endlocal
exit /b 0
