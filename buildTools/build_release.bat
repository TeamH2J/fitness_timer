@echo off
setlocal

:: ======================================
:: Flutter Release Build Script
:: Builds AAB (Android)
:: ======================================

:: Change to project root (script lives in buildTools\ subfolder)
cd /d "%~dp0.."

:: Check Flutter is available in PATH
where flutter >nul 2>&1
if errorlevel 1 (
    echo ERROR: Flutter not found in PATH.
    echo Please install Flutter and add flutter\bin to your system PATH.
    if not "%~1"=="--no-pause" pause
    exit /b 1
)

:: Read version from pubspec.yaml
for /f "tokens=2 delims=: " %%v in ('findstr /r "^version:" pubspec.yaml') do set FULL_VERSION=%%v
for /f "tokens=1 delims=+" %%v in ("%FULL_VERSION%") do set VERSION=%%v
for /f "tokens=2 delims=+" %%v in ("%FULL_VERSION%") do set BUILD_NUMBER=%%v

echo Current version: %VERSION%+%BUILD_NUMBER%

:: Increment patch version
for /f "tokens=1 delims=." %%a in ("%VERSION%") do set MAJOR=%%a
for /f "tokens=2 delims=." %%b in ("%VERSION%") do set MINOR=%%b
for /f "tokens=3 delims=." %%c in ("%VERSION%") do set PATCH=%%c

set /a NEW_PATCH=%PATCH%+1
set /a NEW_BUILD=%BUILD_NUMBER%+1
set NEW_VERSION=%MAJOR%.%MINOR%.%NEW_PATCH%

echo New version: %NEW_VERSION%+%NEW_BUILD%

:: Update pubspec.yaml
powershell -Command "$content = (Get-Content pubspec.yaml -Raw -Encoding UTF8) -replace '(?m)^version: .*', 'version: %NEW_VERSION%+%NEW_BUILD%'; [System.IO.File]::WriteAllText((Resolve-Path pubspec.yaml), $content, [System.Text.UTF8Encoding]::new($false))"

echo.
echo [1/3] Running flutter pub get...
call flutter pub get
if errorlevel 1 goto error

echo.
echo [2/3] Building Android AAB...
call flutter build appbundle --release
if errorlevel 1 goto error

echo.
echo [3/3] Copying artifacts...

set AAB_SRC=build\app\outputs\bundle\release\app-release.aab
set AAB_DST=build\app\outputs\bundle\release\fitness_timer-v%NEW_VERSION%.aab

if exist "%AAB_SRC%" (
    :: Clean up old versioned .aab files
    del /q build\app\outputs\bundle\release\fitness_timer-v*.aab 2>nul
    copy "%AAB_SRC%" "%AAB_DST%"
    echo AAB: %AAB_DST%
) else (
    echo WARNING: AAB not found at %AAB_SRC%
)

echo.
echo ======================================
echo Build complete: v%NEW_VERSION%+%NEW_BUILD%
echo ======================================
goto end

:error
echo.
echo ERROR: Build failed. Check the output above.
if not "%~1"=="--no-pause" pause
exit /b 1

:end
endlocal
if not "%~1"=="--no-pause" pause
