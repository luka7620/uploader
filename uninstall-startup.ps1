$startupDir = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupDir 'Yezi Uploader Tray.lnk'

if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
    Write-Output "Startup shortcut removed: $shortcutPath"
} else {
    Write-Output "Startup shortcut not found: $shortcutPath"
}
