#NoEnv
#SingleInstance, Force
SetBatchLines, -1

arg1 := A_Args[1]

if !A_IsAdmin
    Run *RunAs "%A_ScriptFullPath%" "%arg1%"

if A_Args[1] {
    silent := true
    blockMarketplace := A_Args[1] == 1 ? true : false
} else {
    MsgBox, 4, Block Marketplace, % "Yes: Block Marketplace`nNo: Allow Marketplace`n`nNote: Some versions of Minecraft, if it cannot connect to the marketplace, will give a ""Cauldron"" error when logging in."
    IfMsgBox, Yes
        blockMarketplace := true
    IfMsgBox, No
        blockMarketplace := false
}
blockMarketplaceT := blockMarketplace ? "True" : "False"

getRuleCmd := "Get-NetFirewallRule -DisplayName 'Minecraft Marketplace' -ErrorAction SilentlyContinue"
setRuleCmd := "Set-NetFirewallRule -DisplayName 'Minecraft Marketplace' -Direction Outbound -RemoteAddress '20.112.54.230-20.120.129.75' -Action Block -Enabled " blockMarketplaceT
newRuleCmd := "New-NetFirewallRule -DisplayName 'Minecraft Marketplace' -Direction Outbound -RemoteAddress '20.112.54.230-20.120.129.75' -Action Block -Enabled " blockMarketplaceT

DetectHiddenWindows, On
Run, %ComSpec%,, Hide, cPID
WinWait, ahk_pid %cPID%
DllCall("AttachConsole", "UInt", cPID)
shell := ComObjCreate("WScript.Shell")
exec := shell.Exec(ComSpec " /C powershell.exe " getRuleCmd)
ruleExist := exec.StdOut.ReadAll()

exec := shell.Exec(ComSpec " /C powershell.exe " (ruleExist ? setRuleCmd : newRuleCmd))
exec.StdOut.ReadAll()

if !silent
    MsgBox, % "Marketplace is now " (blockMarketplace ? "blocked." : "allowed.")

DllCall("FreeConsole")
Process, Close, %cPID%