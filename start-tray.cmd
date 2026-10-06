@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0tray-launcher.ps1" -ConfigPath "%~dp0upload.config.json"
endlocal
