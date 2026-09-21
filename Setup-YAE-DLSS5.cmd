@echo off
setlocal
title You Are Empty - DLSS 5 Setup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-YAE-DLSS5.ps1" %*
set "YAE_SETUP_EXIT=%ERRORLEVEL%"
echo.
if not "%YAE_SETUP_EXIT%"=="0" (
    echo Setup failed. Read the error message above.
) else (
    echo Setup completed.
)
pause
exit /b %YAE_SETUP_EXIT%
