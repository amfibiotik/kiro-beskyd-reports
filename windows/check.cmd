@echo off
rem Read-only health check of the installation (nothing is changed).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check.ps1" %*
echo.
pause
