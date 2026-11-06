@echo off
rem Double-click installer for Windows + Kiro IDE.
rem Runs setup.ps1 with the execution policy bypassed for this one run only.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
echo.
pause
