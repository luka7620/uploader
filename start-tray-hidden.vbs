Option Explicit

Dim fso
Dim shell
Dim scriptDir
Dim configPath
Dim trayScriptPath
Dim powershellPath
Dim command

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)

If WScript.Arguments.Count > 0 Then
    configPath = WScript.Arguments(0)
Else
    configPath = fso.BuildPath(scriptDir, "upload.config.json")
End If

trayScriptPath = fso.BuildPath(scriptDir, "tray-launcher.ps1")
powershellPath = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"

command = """" & powershellPath & """ -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & trayScriptPath & """ -ConfigPath """ & configPath & """"

shell.CurrentDirectory = scriptDir
shell.Run command, 0, False
