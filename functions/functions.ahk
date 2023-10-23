LaunchInstances()
{
    SetTitleMatchMode, 3
    CloseInstances()
    lastRestart := UpdateResetAttempts(0)
    usedPIDs := []
    threadsMask := (2 ** Ceil(threadCount * threadsUsage)) - 1
    WinActivate, ahk_class Shell_TrayWnd

    loop, %numInstances% {
        Run, shell:AppsFolder\Microsoft.MinecraftUWP_8wekyb3d8bbwe!App
        Sleep, 500

        PIDs := GetExcludedFromList(GetMinecraftProcesses(), usedPIDs)
        pid  := PIDs[1]
        hwnd := WinActive("Minecraft")
        proc := new _ClassMemory("ahk_pid " pid, "PROCESS_VM_READ")
        MCInstances.push({ hwnd: hwnd
                         , pid: pid
                         , proc: proc
                         , isResetting: 0
                         , x1: 0, y1: 0
                         , x2: 0, y2: 0
                         , width: 0, height: 0 })

        if (PIDs.count() > 1 || !pid)
        {
            if (!GetMultiState())
            {
                MsgBox, 4,, % "Error: Multi-instance is not registered.`nDo you want to register multi?"
                IfMsgBox, Yes
                    Run, configs\RegisterMulti.ahk
                return
            }

            MsgBox, 4,, % "Error: Failed to get process ID.`nDo you want to try and relaunch instances?"
            IfMsgBox, Yes
                LaunchInstances()
            return
        }

        usedPIDs.push(pid)

        SetAffinity(pid, threadsMask)
    }

    ConfigureMinecraftPointers()
    ResizeInstances()
}

ResizeInstances()
{
    dim := StrSplit(layoutDimensions, ",")
    height := (A_ScreenHeight - 40 * scaleBy) / dim[2]
    width := A_ScreenWidth / dim[1]

    for k, instance in MCInstances
    {
        positionIndex := Mod(A_Index - 1, dim[1] * dim[2]) + 1
        x := Mod(positionIndex, dim[1])
        y := Floor((positionIndex - 1) / dim[1])
        WinRestore, % "ahk_id " instance.hwnd
        WinMove, % "ahk_id " instance.hwnd,, width*x-8, height*y, width+16, height+8

        winDimensions := GetWindowDimensions("ahk_id " instance.hwnd)
        instance.x1     := winDimensions.x1
        instance.y1     := winDimensions.y1
        instance.x2     := winDimensions.x2
        instance.y2     := winDimensions.y2
        instance.width  := winDimensions.width
        instance.height := winDimensions.height
    }
}

GetWindowDimensions(Window)
{
    WinGet, style, Style, %Window%
    if (isFullscreen := !(style & 0x20800000))
        return {}

    WinGetPos, winX, winY, winWidth, winHeight, %Window%

    return { x1    : winX + 8  * scaleBy
           , y1    : winY + 30 * scaleBy
           , x2    : winX + 8  * scaleBy + winWidth  - 16 * scaleBy
           , y2    : winY + 30 * scaleBy + winHeight - 38 * scaleBy
           , width : winWidth  - 16 * scaleBy
           , height: winHeight - 38 * scaleBy }
}

GetMinecraftProcesses()
{
    local tPtr := 0, pPtr := 0, nTTL := 0, processName, processID, list := []
  
    if !DllCall("Wtsapi32\WTSEnumerateProcesses", "Ptr", 0, "Int", 0, "Int", 1, "PtrP", pPtr, "PtrP", nTTL)
      return "", DllCall("SetLastError", "Int", -1)        
    
    tPtr := pPtr
    loop, % nTTL {
        processName := StrGet(NumGet(tPtr + 8))
        processID   := NumGet(tPtr + 4, "UInt")
        if (processName == "Minecraft.Windows.exe")
            list.push(processID)

        tPtr += (A_PtrSize = 4 ? 16 : 24) 
    }
    DllCall("Wtsapi32\WTSFreeMemory","Ptr", pPtr)      
  
    return list, DllCall("SetLastError", "UInt", nTTL)
}

GetMinecraftVersion()
{
    if WinExist("Minecraft")
        exeDir := new _ClassMemory("ahk_exe Minecraft.Windows.exe", "PROCESS_VM_READ").GetModuleFileNameEx()
    else {
        cmd := "(Get-AppxPackage -Name Microsoft.MinecraftUWP).InstallLocation > '" A_ScriptDir "\configs\installdir.txt'"
        RunWait, PowerShell.exe -Command &{%cmd%},, Hide
        FileRead, exeDir, configs\installdir.txt
        FileDelete, configs\installdir.txt
        exeDir := Trim(exeDir, "`r`n") . "\Minecraft.Windows.exe"
    }

    FileGetVersion, MCversion, %exeDir%
    return MCversion
}

ConfigureMinecraftPointers()
{
    switch GetMinecraftVersion()
    {
        case "1.19.50.2": offsetsX      := [0x048E3910, 0x10, 0x128, 0x0, 0xF8, 0x398, 0x18, 0x0, 0x8] 
                          offsetsZ      := [0x048E3910, 0x10, 0x128, 0x0, 0xF8, 0x398, 0x18, 0x0, 0x10]
        case "1.16.10.2": offsetsX      := [0x036A3C18, 0xA8, 0x10, 0x954]
        case "1.16.1.2" : offsetsX      := [0x0369D0A8, 0xA8, 0x10, 0x954]
                          offsetsScreen := [0x036A4B00, 0x28, 0x198, 0x10, 0x210, 0x18]
        case "1.16.0.58": offsetsX      := [0x038464D8, 0x190, 0x20, 0x0, 0x2C]
        case "1.16.0.57": offsetsX      := [0x03846490, 0x190, 0x20, 0x0, 0x2C]
        case "1.16.0.51": offsetsX      := [0x035C6298, 0x190, 0x20, 0x0, 0x2C]
        case "1.14.60.5": offsetsX      := [0x0307D3A0, 0x30, 0xF0, 0x110]
        case "1.2.13.54": offsetsX      := [0x01FA1888, 0x0, 0x10, 0x10, 0x20, 0x0, 0x2C]
                          offsetsScreen := [0x01F2F5F8, 0xD0, 0x58]

        default: Msgbox, Auto-reset is not supported for this version: %MCversion%.
    }
}

SetAffinity(pid, mask) 
{
    if (hProcess := DllCall("OpenProcess", "UInt", 0x0200, "Int", 0, "Int", pid))
    {
        DllCall("SetProcessAffinityMask", "Ptr", hProcess, "Ptr", mask)
        DllCall("CloseHandle", "Ptr", hProcess)
    }
}

CloseInstances()
{
    MCInstances := []

    SetTitleMatchMode, 3
    while WinExist("Minecraft")
        Process, Close, Minecraft.Windows.exe
}

OpenMinecraftDir()
{
    Run, %minecraftDir%
}

UpdateResetAttempts(amount := 1)
{
    txt := FileOpen("configs/attempts.txt", "r") ; open/reads txt
    attempts := txt.read() + amount
    if amount {
        txt := FileOpen("configs/attempts.txt", "w") ; overwrites txt
        txt.write(attempts)
    }
    txt.close()

    return attempts
}

ShouldRestart(resetCounter)
{
    if !lastRestart {
        lastRestart := resetCounter
        return false
    }

    if (lastRestart + resetThreshold <= resetCounter) {
        Gosub, Restart
        Exit
    }
}

GetMultiState()
{
    cmd := "(Get-AppxPackage -Name Microsoft.MinecraftUWP).'PackageFullName' > '" A_ScriptDir "\configs\mcpackage.txt'"
    RunWait, PowerShell.exe -Command &{%cmd%},, Hide
    FileRead, mcpackage, configs\mcpackage.txt
    FileDelete, configs\mcpackage.txt
    mcpackage := Trim(mcpackage, "`r`n")

    RegRead, multiState, HKCU, % "SOFTWARE\Classes\Extensions\ContractId\Windows.Launch\PackageId\" mcpackage "\ActivatableClassId\App\CustomProperties", SupportsMultipleInstances
    return multiState
}

GetExcludedFromList(list, excludeList)
{
    returnList := []

    for i, item in list
    {
        for ii, excludeItem in excludeList
        {
            if (item == excludeItem)
                continue, 2
        }
        returnList.push(item)
    }

    return returnList
}