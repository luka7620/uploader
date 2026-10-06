param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'upload.config.json')
)

$resolvedConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
$startupDir = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupDir 'Yezi Uploader Tray.lnk'
$launcherPath = Join-Path $PSScriptRoot 'start-tray-hidden.vbs'

if (-not (Test-Path -LiteralPath $launcherPath)) {
    throw "Hidden launcher not found: $launcherPath"
}

$wscriptPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
$arguments = "`"$launcherPath`" `"$resolvedConfigPath`""

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $wscriptPath
$shortcut.Arguments = $arguments
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.IconLocation = "$wscriptPath,0"
$shortcut.Save()

Write-Output "Startup shortcut created: $shortcutPath"
