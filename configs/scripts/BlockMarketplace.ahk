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

if A_Args[1] {
    silent := true
    blockMarketplace := A_Args[1]
    if (blockMarketplace < 0 || blockMarketplace > 2) {
        blockMarketplace := 0
    }
} else {
    MsgBox, 3, Block Marketplace, % ""
        . "Yes: Block All Connections`n"
        . "No: Block Marketplace`n"
        . "Cancel: Restore Connections`n`n"
        . "Note:`n"
        . "- By blocking all connections, you will lose the ability to log in, etc.`n"
        . "- If the Minecraft installation path changes, you will need to rerun this script.`n"
        . "- The marketplace IP address may change; rerun the script to re-block it."
    IfMsgBox, Yes
        blockMarketplace := 2
    IfMsgBox, No
        blockMarketplace := 1
    IfMsgbox, Cancel
        blockMarketplace := 0
}

DetectHiddenWindows, On
Run, %ComSpec%,, Hide, cPid
WinWait, ahk_pid %cPid%,, 5
if ErrorLevel {
    if !silent
        Msgbox, % "Failed to initialise shell"
    ExitApp, -1
}
DllCall("AttachConsole", "UInt", cPid)

applicationName := ""
remoteAddress := ""
if (blockMarketplace > 0) {
    packages := GetAppxPackagesByFamilyName("Microsoft.MinecraftUWP_8wekyb3d8bbwe")
    applicationName := GetPackagePathByFullName(packages[1]) "\Minecraft.Windows.exe"
    if !applicationName {
        if !silent
            MsgBox, % "Failed to get Minecraft executable path."
        ExitApp, -1
    }
    if (blockMarketplace == 2) {
        remoteAddress := "0.0.0.0-255.255.255.255"
    } else if (blockMarketplace == 1) {
        sh := ComObjCreate("WScript.Shell")
        exec := sh.Exec("nslookup https://b980a380.minecraft.playfabapi.com")
        RegExMatch(exec.StdOut.ReadAll(), "\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b", remoteAddress)
        if !remoteAddress {
            if !silent
                Msgbox, % "Failed to get resolved IP"
            ExitApp, -1
        }

        exec := sh.Exec(ComSpec " /c powershell -NoProfile -Command ""Get-DnsClientCache -Type A -Name '*playfab*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Data""")
        if ((cachedIp := Trim(exec.StdOut.ReadAll(), "`r`n")) && cachedIp != remoteAddress)
            remoteAddress .= "," cachedIp
    }
}

if err1 := SetFirewallRuleViaCom(ruleName, applicationName, remoteAddress, blockMarketplace) {
    if err2 := SetFirewallRuleViaPowershell(ruleName, applicationName, remoteAddress, blockMarketplace) {
        if !silent
            Msgbox, % "Failed to set firewall rule.`n`nCOM Error:`n" err1 "`n`nPowershell Error:`n" err2
        ExitApp, -1
    }
}

DllCall("FreeConsole")
Process, Close, %cPid%

if !silent {
    switch (blockMarketplace) {
        case 0: MsgBox, % "All connections have been restored."
        case 1: MsgBox, % "Marketplace is now blocked."
        case 2: MsgBox, % "All connections are now blocked."
    }
}
ExitApp, 0


SetFirewallRuleViaCom(ruleName, applicationName, remoteAddress, enable) {
    static NEW_FW_IP_ANY := 256
    static NET_FW_ACTION_BLOCK := 0
    static NET_FW_ACTION_ALLOW := 1
    static NET_FW_RULE_DIR_OUT := 2

    fwPolicy2 := ComObjCreate("HNetCfg.FwPolicy2")
    fwRules := fwPolicy2.Rules

    if !applicationName
        applicationName := "None" ; unsure how to set to null

    try {
        rule := fwRules.Item(ruleName)
        rule.ApplicationName := applicationName
        rule.remoteAddresses := remoteAddress
        rule.Direction := NET_FW_RULE_DIR_OUT
        rule.Enabled := enable
        return 0
    }

    newRule := ComObjCreate("HNetCfg.FWRule")
    newRule.Name := ruleName
    newRule.ApplicationName := applicationName
    newRule.Protocol := NEW_FW_IP_ANY
    newRule.RemoteAddresses := remoteAddress
    newRule.Action := NET_FW_ACTION_BLOCK
    newRule.Direction := NET_FW_RULE_DIR_OUT
    newRule.Enabled := enable

    try {
        fwRules.Add(newRule)
    } catch err {
        return err.Message
    }

    return 0
}

SetFirewallRuleViaPowershell(ruleName, applicationName, remoteAddress, enable) {
    if !applicationName
        applicationName := "None"

    cmd =
    (
        $enable = if (%enable%) {'True'} Else {'False'}
        $ruleExist = (Get-NetFirewallRule -DisplayName '%ruleName%' -ErrorAction SilentlyContinue)
        if ($ruleExist) {
            Set-NetFirewallRule -DisplayName '%ruleName%' -Direction Outbound -Program '%applicationName%' \
                                -RemoteAddress '%remoteAddress%' -Action Block -Enabled $enable
        } else {
            New-NetFirewallRule -DisplayName '%ruleName%' -Direction Outbound -Program '%applicationName%' \
                                -RemoteAddress '%remoteAddress%' -Action Block -Enabled $enable
        }
    )
    cmd := StrReplace(cmd, "\`n", "")
    cmd := StrReplace(cmd, "`n", "; ")

    shell := ComObjCreate("WScript.Shell")
    exec := shell.Exec(ComSpec " /C powershell " cmd)
    output := exec.StdErr.ReadAll()

    if RegexMatch(output, "FullyQualifiedErrorId\s+:\s+(.+)", errorId)
        return errorId1
    return 0
}

GetAppxPackagesByFamilyName(familyName) {
    static ERROR_INSUFFICIENT_BUFFER := 0x7A

    packageCount := 0
    bufferLength := 0
    err := DllCall("GetPackagesByPackageFamily", "WStr", familyName, "UInt*", packageCount, "Ptr", 0, "UInt*", bufferLength, "UInt")
    if (err != ERROR_INSUFFICIENT_BUFFER)
        return ""

    VarSetCapacity(packageFullNames, bufferLength * 2)
    if err := DllCall("GetPackagesByPackageFamily", "WStr", familyName, "UInt*", packageCount, "Ptr*", packageFullNames, "UInt*", bufferLength, "UInt")
        return ""

    if (packageCount == 1)
        return [StrGet(packageFullNames, "UTF-16")]

    packageFullNamesArr := []
    offset := 2
    Loop, % packageCount {
        packageFullName := StrGet(&packageFullNames + offset, "UTF-16")
        packageFullNamesArr.Push(packageFullName)
        offset += (StrLen(packageFullName) + 1) * 2
    }

    return packageFullNamesArr
}

GetPackagePathByFullName(packageFullName) {
    pathLength := 1024
    VarSetCapacity(installationPath, pathLength)
    if err := DllCall("GetPackagePathByFullName", "WStr", packageFullName, "UInt*", pathLength, "WStr", installationPath)
        return ""

    return installationPath
}
