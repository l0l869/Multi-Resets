#NoEnv
#SingleInstance, Force
SetBatchLines, -1

if A_Args[1] {
    silent := true
    enableMultiInstance := A_Args[1] == 1 ? true : false
} else {
    MsgBox, 4, Register Multi Instance, % "Yes: Enable Multi Instance`nNo: Disable Multi Instance"
    IfMsgBox, Yes
        enableMultiInstance := true
    IfMsgBox, No
        enableMultiInstance := false
}

packageName := "Microsoft.MinecraftUWP"
getPackageCommand := "powershell.exe (Get-AppxPackage -Name " packageName ").'PackageFullName'"

DetectHiddenWindows, On
Run, %ComSpec%,, Hide, cPID
WinWait, ahk_pid %cPID%
DllCall("AttachConsole", "UInt", cPID)
shell := ComObjCreate("WScript.Shell")
exec := shell.Exec(ComSpec " /C " getPackageCommand)
fullPackageName := Trim(exec.StdOut.ReadAll(), "`r`n")

if !fullPackageName {
    if !silent
        MsgBox, % "Couldn't get package name."
    ExitApp, -1
}

packagePropertiesRegPath := "SOFTWARE\Classes\Extensions\ContractId\Windows.Launch\PackageId\" fullPackageName "\ActivatableClassId\App\CustomProperties"
RegWrite, REG_DWORD, HKCU, %packagePropertiesRegPath%, SupportsMultipleInstances, %enableMultiInstance%
RegRead, confirmValue, HKCU, %packagePropertiesRegPath%, SupportsMultipleInstances

if !silent {
    if (confirmValue != enableMultiInstance)
        MsgBox, % "Failed to register value."
    MsgBox, % "Multi Instance is now " (confirmValue ? "enabled." : "disabled.")
}

DllCall("FreeConsole")
Process, Close, %cPID%