#NoEnv
#SingleInstance, Force
SetBatchLines, -1

MsgBox, 4, Register Multi Instance, % "Yes: Enable Multi Instance`nNo: Disable Multi Instance"
IfMsgBox, Yes
    isMultiInstanceEnabled := true
IfMsgBox, No
    isMultiInstanceEnabled := false


PackageName := "Microsoft.MinecraftUWP"
getPackageCommand := "powershell.exe Get-AppxPackage -Name " PackageName

shell := ComObjCreate("WScript.Shell")
exec := shell.Exec(ComSpec " /C " getPackageCommand)
output := exec.StdOut.ReadAll()

fullPackageName := ""
RegExMatch(output, "PackageFullName\s*:\s*(\S+)", returnMatches)
fullPackageName := returnMatches1

if !fullPackageName {
    MsgBox, % "Couldn't get package name."
    ExitApp, -1
}

packagePropertiesRegPath := "SOFTWARE\Classes\Extensions\ContractId\Windows.Launch\PackageId\" fullPackageName "\ActivatableClassId\App\CustomProperties"
RegWrite, REG_DWORD, HKCU, %packagePropertiesRegPath%, SupportsMultipleInstances, %isMultiInstanceEnabled%
RegRead, confirmValue, HKCU, %packagePropertiesRegPath%, SupportsMultipleInstances

if (confirmValue != isMultiInstanceEnabled)
    MsgBox, % "Failed to register value."

MsgBox, % "Multi Instance is now " (confirmValue ? "enabled." : "disabled.")