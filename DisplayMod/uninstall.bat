@echo off
rem DisplayMod uninstaller for BLACK SOULS II
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer.ps1" -Uninstall
echo.
pause
