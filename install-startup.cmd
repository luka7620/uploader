@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-startup.ps1" -ConfigPath "%~dp0upload.config.json"
pause
endlocal
