param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'upload.config.json')
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:ConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
$script:UploaderScript = Join-Path $PSScriptRoot 'upload-data.mjs'
$script:RuntimeDir = Join-Path $PSScriptRoot 'runtime'
$script:StdoutLog = Join-Path $script:RuntimeDir 'uploader.stdout.log'
$script:StderrLog = Join-Path $script:RuntimeDir 'uploader.stderr.log'
$script:UploaderProcess = $null
$script:LastRunning = $false
$script:ConfigData = $null

function Ensure-RuntimeDir {
    if (-not (Test-Path -LiteralPath $script:RuntimeDir)) {
        New-Item -ItemType Directory -Path $script:RuntimeDir | Out-Null
    }
}

function Get-NodePath {
    $nodeCommand = Get-Command node -ErrorAction Stop
    return $nodeCommand.Source
}

function Test-UploaderRunning {
    return $script:UploaderProcess -and -not $script:UploaderProcess.HasExited
}

function Load-ConfigData {
    if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
        $script:ConfigData = $null
        return
    }

    try {
        $script:ConfigData = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json
    } catch {
        $script:ConfigData = $null
    }
}

function Show-Balloon {
    param(
        [string]$Title,
        [string]$Text,
        [System.Windows.Forms.ToolTipIcon]$Icon = [System.Windows.Forms.ToolTipIcon]::Info
    )

    $script:NotifyIcon.BalloonTipTitle = $Title
    $script:NotifyIcon.BalloonTipText = $Text
    $script:NotifyIcon.BalloonTipIcon = $Icon
    $script:NotifyIcon.ShowBalloonTip(3000)
}

function Update-Ui {
    $running = Test-UploaderRunning
    $script:StatusItem.Text = if ($running) { 'Status: Running' } else { 'Status: Stopped' }
    $script:NotifyIcon.Text = if ($running) { 'Uploader running' } else { 'Uploader stopped' }
    $script:ConfigPathItem.Text = "Config: $($script:ConfigPath)"
    $script:UrlItem.Text = if ($script:ConfigData -and $script:ConfigData.url) { "Server: $($script:ConfigData.url)" } else { 'Server: (not set)' }
    $script:AccountsItem.Text = if ($script:ConfigData -and $script:ConfigData.accountsPath) { "Accounts: $($script:ConfigData.accountsPath)" } else { 'Accounts: (not set)' }
    $script:LogItem.Text = if ($script:ConfigData -and $script:ConfigData.logPath) { "Log: $($script:ConfigData.logPath)" } else { 'Log: (not set)' }
    $script:StartItem.Enabled = -not $running
    $script:StopItem.Enabled = $running
    $script:RestartItem.Enabled = $true

    if ($running -ne $script:LastRunning) {
        if ($running) {
            Show-Balloon -Title 'Uploader' -Text 'Upload watcher is running.'
        } else {
            Show-Balloon -Title 'Uploader' -Text 'Upload watcher stopped. Check logs.' -Icon ([System.Windows.Forms.ToolTipIcon]::Warning)
        }
        $script:LastRunning = $running
    }
}

function Start-Uploader {
    if (Test-UploaderRunning) {
        return
    }

    if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
        throw "Config file not found: $($script:ConfigPath)"
    }

    Load-ConfigData
    Ensure-RuntimeDir
    $nodePath = Get-NodePath
    $script:UploaderProcess = Start-Process `
        -FilePath $nodePath `
        -ArgumentList @($script:UploaderScript, '--watch', '--config', $script:ConfigPath) `
        -WorkingDirectory $PSScriptRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $script:StdoutLog `
        -RedirectStandardError $script:StderrLog `
        -PassThru
}

function Stop-Uploader {
    if ($script:UploaderProcess -and -not $script:UploaderProcess.HasExited) {
        Stop-Process -Id $script:UploaderProcess.Id -Force -ErrorAction SilentlyContinue
        $null = $script:UploaderProcess.WaitForExit(5000)
    }
    $script:UploaderProcess = $null
}

function Restart-Uploader {
    Stop-Uploader
    Start-Sleep -Milliseconds 500
    Start-Uploader
    Update-Ui
}

function Open-Config {
    if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
        Show-Balloon -Title 'Uploader' -Text 'Config file not found.' -Icon ([System.Windows.Forms.ToolTipIcon]::Warning)
        return
    }
    Start-Process -FilePath notepad.exe -ArgumentList $script:ConfigPath | Out-Null
}

function Open-Logs {
    Ensure-RuntimeDir
    Start-Process -FilePath explorer.exe -ArgumentList $script:RuntimeDir | Out-Null
}

function Exit-Tray {
    $script:Timer.Stop()
    Stop-Uploader
    $script:NotifyIcon.Visible = $false
    $script:NotifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
}

$script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:NotifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$script:NotifyIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$script:StatusItem = $contextMenu.Items.Add('Status: Starting')
$script:StatusItem.Enabled = $false
$script:ConfigPathItem = $contextMenu.Items.Add('Config: (loading)')
$script:ConfigPathItem.Enabled = $false
$script:UrlItem = $contextMenu.Items.Add('Server: (loading)')
$script:UrlItem.Enabled = $false
$script:AccountsItem = $contextMenu.Items.Add('Accounts: (loading)')
$script:AccountsItem.Enabled = $false
$script:LogItem = $contextMenu.Items.Add('Log: (loading)')
$script:LogItem.Enabled = $false
$null = $contextMenu.Items.Add('-')
$script:StartItem = $contextMenu.Items.Add('Start Upload Watcher')
$script:RestartItem = $contextMenu.Items.Add('Restart Upload Watcher')
$script:StopItem = $contextMenu.Items.Add('Stop Upload Watcher')
$null = $contextMenu.Items.Add('-')
$script:OpenConfigItem = $contextMenu.Items.Add('Open Config')
$script:OpenLogsItem = $contextMenu.Items.Add('Open Runtime Folder')
$null = $contextMenu.Items.Add('-')
$script:ExitItem = $contextMenu.Items.Add('Exit')

$script:NotifyIcon.ContextMenuStrip = $contextMenu

$script:StartItem.Add_Click({
    try {
        Start-Uploader
    } catch {
        Show-Balloon -Title 'Uploader' -Text $_.Exception.Message -Icon ([System.Windows.Forms.ToolTipIcon]::Error)
    }
    Update-Ui
})

$script:RestartItem.Add_Click({
    try {
        Restart-Uploader
    } catch {
        Show-Balloon -Title 'Uploader' -Text $_.Exception.Message -Icon ([System.Windows.Forms.ToolTipIcon]::Error)
    }
    Update-Ui
})

$script:StopItem.Add_Click({
    Stop-Uploader
    Update-Ui
})

$script:OpenConfigItem.Add_Click({ Open-Config })
$script:OpenLogsItem.Add_Click({ Open-Logs })
$script:ExitItem.Add_Click({ Exit-Tray })
$script:NotifyIcon.Add_DoubleClick({ Open-Logs })

$script:Timer = New-Object System.Windows.Forms.Timer
$script:Timer.Interval = 5000
$script:Timer.Add_Tick({ Update-Ui })

try {
    Start-Uploader
} catch {
    Show-Balloon -Title 'Uploader' -Text $_.Exception.Message -Icon ([System.Windows.Forms.ToolTipIcon]::Error)
}

Update-Ui
$script:Timer.Start()
[System.Windows.Forms.Application]::Run()
