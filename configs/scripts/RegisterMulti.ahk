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

fullPackageName := GetAppxPackagesByFamilyName("Microsoft.MinecraftUWP_8wekyb3d8bbwe")[1]
if !fullPackageName {
    if !silent
        MsgBox, % "Failed to get package name."
    ExitApp, -1
}

packagePropertiesRegPath := "SOFTWARE\Classes\Extensions\ContractId\Windows.Launch\PackageId\" fullPackageName "\ActivatableClassId\App\CustomProperties"
RegWrite, REG_DWORD, HKCU, %packagePropertiesRegPath%, SupportsMultipleInstances, %enableMultiInstance%
RegRead, confirmValue, HKCU, %packagePropertiesRegPath%, SupportsMultipleInstances

if (confirmValue != enableMultiInstance) {
    if !silent
        MsgBox, % "Failed to register value."
    ExitApp, -1
}

if !silent
    MsgBox, % "Multi Instance is now " (confirmValue ? "enabled." : "disabled.")

ExitApp, 0


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
