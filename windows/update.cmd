@echo off
rem Re-installs the skills after "git pull". Your config files are not touched.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -UpdateSkillsOnly %*
echo.
pause
