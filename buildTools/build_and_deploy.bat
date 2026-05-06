@echo off
setlocal

:: Build + Play Store deploy integrated script
:: Order: build_release.bat -> deploy_to_play.bat

cd /d "%~dp0"

echo ======================================
echo  BUILD + DEPLOY Options
echo ======================================
echo  [1] Version bump + Build + Play Store deploy
echo  [2] Version bump + Build only
echo  [3] Play Store deploy only ^(reuse existing AAB^)
echo ======================================
echo.

:ask_choice
set /p CHOICE=Select option (1/2/3):

if "%CHOICE%"=="1" goto mode_full
if "%CHOICE%"=="2" goto mode_build_only
if "%CHOICE%"=="3" goto mode_deploy_only

echo Invalid input. Please enter 1, 2, or 3.
echo.
goto ask_choice

:: ======================================
:: MODE 1: Version bump + Build + Deploy
:: ======================================
:mode_full
echo.
echo ======================================
echo  Mode: Version bump + Build + Play Store deploy
echo ======================================
echo.
echo ======================================
echo  STEP 1/2: Build (build_release.bat)
echo ======================================
echo.

call build_release.bat --no-pause
if errorlevel 1 (
    echo.
    echo [STEP 1/2 FAILED] Build error. Aborting deploy.
    pause
    exit /b 1
)

echo.
echo [STEP 1/2 DONE]
echo.
echo ======================================
echo  STEP 2/2: Play Store upload (deploy_to_play.bat)
echo ======================================
echo.

call deploy_to_play.bat --no-pause
if errorlevel 1 (
    echo.
    echo [STEP 2/2 FAILED] Play Store upload error.
    pause
    exit /b 1
)

echo.
echo [STEP 2/2 DONE]
echo.
echo ======================================
echo  ALL DONE: Build + Play Store deploy success!
echo ======================================
goto end

:: ======================================
:: MODE 2: Version bump + Build only
:: ======================================
:mode_build_only
echo.
echo ======================================
echo  Mode: Version bump + Build only
echo ======================================
echo.

call build_release.bat --no-pause
if errorlevel 1 (
    echo.
    echo [FAILED] Build error.
    pause
    exit /b 1
)

echo.
echo ======================================
echo  DONE: Build success. Deploy skipped.
echo ======================================
goto end

:: ======================================
:: MODE 3: Deploy only (reuse existing AAB)
:: ======================================
:mode_deploy_only
echo.
echo ======================================
echo  Mode: Play Store deploy only
echo ======================================
echo.
echo [WARNING] No version bump.
echo           If current version is already on Play Store, it will be rejected.
echo.

call deploy_to_play.bat --no-pause
if errorlevel 1 (
    echo.
    echo [FAILED] Play Store upload error.
    pause
    exit /b 1
)

echo.
echo ======================================
echo  DONE: Play Store deploy success!
echo ======================================
goto end

:end
pause
endlocal
