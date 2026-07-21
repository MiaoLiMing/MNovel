@echo off
setlocal EnableExtensions
chcp 65001 >nul
cd /d "%~dp0"

echo [1/4] Resolving Flutter dependencies...
call powershell.exe -NoProfile -ExecutionPolicy Bypass -File "scripts\flutter.ps1" pub get
if errorlevel 1 goto :failed

echo [2/4] Running static analysis...
call powershell.exe -NoProfile -ExecutionPolicy Bypass -File "scripts\flutter.ps1" analyze --no-pub
if errorlevel 1 goto :failed

echo [3/4] Running tests...
call powershell.exe -NoProfile -ExecutionPolicy Bypass -File "scripts\flutter.ps1" test --no-pub
if errorlevel 1 goto :failed

echo [4/4] Building release APK...
pushd "apps\mobile"
call powershell.exe -NoProfile -ExecutionPolicy Bypass -File "..\..\scripts\flutter.ps1" build apk --release --no-pub
set "BUILD_EXIT=%ERRORLEVEL%"
popd
if not "%BUILD_EXIT%"=="0" goto :failed

set "APK=%~dp0apps\mobile\build\app\outputs\flutter-apk\app-release.apk"
echo.
echo APK build completed:
echo %APK%
if exist "%APK%" explorer.exe /select,"%APK%"
pause
exit /b 0

:failed
echo.
echo APK build failed. Review the output above.
pause
exit /b 1
