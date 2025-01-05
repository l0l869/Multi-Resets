#NoEnv
#SingleInstance, Force
SetBatchLines, -1

arg1 := A_Args[1]

if !A_IsAdmin {
    try {
        Run *RunAs "%A_ScriptFullPath%" "%arg1%"
    } catch {
        MsgBox, 48,, % "The script needs to be run as administrator in order to configure firewall settings."
        ExitApp, -1
    }
}

ruleName := "Minecraft Marketplace"
remoteAddress := "20.112.54.230-20.120.129.75"

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

if err1 := SetFirewallRuleViaCom(ruleName, remoteAddress, blockMarketplace) {
    if err2 := SetFirewallRuleViaPowershell(ruleName, remoteAddress, blockMarketplace) {
        Msgbox, % "Failed to set firewall rule.`n`nCOM Error:`n" err1 "`n`nPowershell Error:`n" err2
        ExitApp, -1
    }
}

MsgBox, % "Marketplace is now " (blockMarketplace ? "blocked." : "allowed.")
ExitApp, 0


SetFirewallRuleViaCom(ruleName, remoteAddress, enable) {
    static NEW_FW_IP_ANY := 256
    static NET_FW_ACTION_BLOCK := 0
    static NET_FW_ACTION_ALLOW := 1
    static NET_FW_RULE_DIR_OUT := 2

    fwPolicy2 := ComObjCreate("HNetCfg.FwPolicy2")
    fwRules := fwPolicy2.Rules

    try {
        rule := fwRules.Item(ruleName)
        rule.remoteAddresses := remoteAddress
        rule.Enabled := enable
        return 0
    }

    newRule := ComObjCreate("HNetCfg.FWRule")
    newRule.Name := ruleName
    newRule.Protocol := NEW_FW_IP_ANY
    newRule.RemoteAddresses := remoteAddress
    newRule.Action := NET_FW_ACTION_BLOCK
    newRule.Enabled := enable
    newRule.Direction := NET_FW_RULE_DIR_OUT

    try {
        fwRules.Add(newRule)
    } catch err {
        return err.Message
    }

    return 0
}

SetFirewallRuleViaPowershell(ruleName, remoteAddress, enable) {
    cmd =
    (
        $enable = if (%enable%) {'True'} Else {'False'}
        $ruleExist = (Get-NetFirewallRule -DisplayName '%ruleName%' -ErrorAction SilentlyContinue)
        if ($ruleExist) {
            Set-NetFirewallRule -DisplayName '%ruleName%' -Direction Outbound -RemoteAddress '%remoteAddress%' -Action Block -Enabled $enable
        } else {
            New-NetFirewallRule -DisplayName '%ruleName%' -Direction Outbound -RemoteAddress '%remoteAddress%' -Action Block -Enabled $enable
        }
    )
    cmd := StrReplace(cmd, "`n", "; ")

    DetectHiddenWindows, On
    Run, %ComSpec%,, Hide, cPID
    WinWait, ahk_pid %cPID%,, 10
    if ErrorLevel
        return -1
    DllCall("AttachConsole", "UInt", cPID)

    shell := ComObjCreate("WScript.Shell")
    exec := shell.Exec(ComSpec " /C powershell.exe " cmd)
    output := exec.StdErr.ReadAll()

    DllCall("FreeConsole")
    Process, Close, %cPID%

    if RegexMatch(output, "FullyQualifiedErrorId\s+:\s+(.+)", errorId)
        return errorId1
    return 0
}
