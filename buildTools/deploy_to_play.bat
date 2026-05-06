@echo off
setlocal

:: ======================================
:: Google Play Internal Testing Upload Script
:: Uploads existing AAB to Play Store only.
:: Prerequisite: run build_release.bat first.
:: ======================================

:: Change to project root (script lives in buildTools\ subfolder)
cd /d "%~dp0.."

set AAB=build\app\outputs\bundle\release\app-release.aab

:: ======================================
:: [1/3] Check AAB exists
:: ======================================
echo.
echo [1/3] Checking AAB file...

if not exist "%AAB%" (
    echo.
    echo ERROR: AAB file not found. Expected: build\app\outputs\bundle\release\app-release.aab
    echo Please run build_release.bat first.
    if not "%~1"=="--no-pause" pause
    exit /b 1
)

echo   AAB found: %AAB%

:: ======================================
:: [2/3] Read current version (display only)
:: ======================================
echo.
echo [2/3] Reading version...

for /f "tokens=2 delims=: " %%v in ('findstr /r "^version:" pubspec.yaml') do set FULL_VERSION=%%v
for /f "tokens=1 delims=+" %%v in ("%FULL_VERSION%") do set VERSION=%%v
for /f "tokens=2 delims=+" %%v in ("%FULL_VERSION%") do set BUILD_NUMBER=%%v

echo   Upload version: v%VERSION%+%BUILD_NUMBER%

:: ======================================
:: [3/3] Upload via Fastlane
:: ======================================
echo.
echo [3/3] Uploading to Play Store...

if not exist "android\fastlane\play-store-credentials.json" (
    echo.
    echo ERROR: play-store-credentials.json not found. Place your service-account JSON at android\fastlane\play-store-credentials.json
    if not "%~1"=="--no-pause" pause
    exit /b 1
)

if not exist "android\Gemfile" (
    echo.
    echo ERROR: android\Gemfile not found. Fastlane scaffolding is missing -- check the repository setup.
    if not "%~1"=="--no-pause" pause
    exit /b 1
)

cd android
call bundle exec fastlane upload_internal
if errorlevel 1 (
    cd ..
    goto error
)
cd ..

echo.
echo ======================================
echo Upload complete: v%VERSION%+%BUILD_NUMBER%
echo Check Google Play Console:
echo https://play.google.com/console
echo ======================================
goto end

:error
echo.
echo ERROR: Upload failed. Check the output above.
if not "%~1"=="--no-pause" pause
exit /b 1

:end
endlocal
if not "%~1"=="--no-pause" pause
