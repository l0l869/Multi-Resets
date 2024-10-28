LaunchInstance(index) {
    existingPIDs := GetMinecraftProcesses()
    existingHWNDs := GetMinecraftHwnds()

    Run, shell:AppsFolder\Microsoft.MinecraftUWP_8wekyb3d8bbwe!App
    timeoutTick := A_TickCount + 5000
    while !GetExcludedFromList(GetMinecraftHwnds(), existingHWNDs).count() {
        if (timeoutTick < A_TickCount) {
            LogF("ERR", "Timed Out: Failed to open an instance.")
            return {}
        }
    }

    PIDs := GetMinecraftProcesses()
    filteredPIDs := GetExcludedFromList(PIDs, existingPIDs)
    pid := filteredPIDs[1]
    if (!pid || filteredPIDs.count() > 1) {
        LogF("ERR", "Failed to get process ID")
        MsgBox, % "Error: Failed to get process ID."
        return {}
    }

    HWNDs := GetMinecraftHwnds()
    filteredHWNDs := GetExcludedFromList(HWNDs, existingHWNDs)
    hwnd := filteredHWNDs[1]
    if (!hwnd || filteredHWNDs.count() > 1) {
        LogF("ERR", "Failed to get window handle")
        MsgBox, % "Error: Failed to get window handle."
        return {}
    }

    proc := new _ClassMemory("ahk_pid " pid, "PROCESS_VM_READ")
    if !proc
        LogF("WAR", "Failed to create a memory class instance; A_LastError: " A_LastError)

    instance := { hwnd: hwnd
                , pid: pid
                , proc: proc
                , isResetting: 0
                , x1: 0, y1: 0
                , x2: 0, y2: 0
                , width: 0, height: 0 }

    ResizeInstance(instance, index)

    threadsMask := (2 ** Ceil(threadCount * threadsUsage)) - 1
    SetAffinity(pid, threadsMask)

    return instance
}

ResizeInstance(instance, index) {
    workArea := GetWorkArea()
    width := workArea[1] / layoutDimensions.x
    height := workArea[2] / layoutDimensions.y

    positionIndex := Mod(index-1, layoutDimensions.x * layoutDimensions.y)
    x := Mod(positionIndex, layoutDimensions.x)
    y := positionIndex // layoutDimensions.x
    WinRestore, % "ahk_id " instance.hwnd
    WinMove, % "ahk_id " instance.hwnd,, width*x-SM_CXFRAME, height*y, width+SM_CXFRAME*2, height+SM_CYFRAME

    winDimensions := GetWindowDimensions("ahk_id " instance.hwnd)
    instance.x1     := winDimensions.x1
    instance.y1     := winDimensions.y1
    instance.x2     := winDimensions.x2
    instance.y2     := winDimensions.y2
    instance.width  := winDimensions.width
    instance.height := winDimensions.height
}

SaveInstance(instance) {
    SuspendProcess(instance.pid)
    queuedInstances.push(instance)

    index := 0
    For k, v in MCInstances {
        if (v.hwnd == instance.hwnd) {
            index := k
            break
        }
    }
    MCInstances[index] := LaunchInstance(index)
    MCInstances[index].isResetting := 1
}

SuspendInstances(instances) {
    for k, instance in instances
        SuspendProcess(instance.pid)
}

GetWorkArea() {
    VarSetCapacity(workArea, 16, 0)
    DllCall("SystemParametersInfo", "UInt", 0x0030, "UInt", 0, "UPtr", &workArea, "UInt", 0)
    workAreaWidth := NumGet(&workArea, 8, "Int")
    workAreaHeight := NumGet(&workArea, 12, "Int")
    LogF("INF", "Working Area: " workAreaWidth "x" workAreaHeight ", Screen DPI: " A_ScreenDPI, A_ThisFunc ":WorkArea")
    return [workAreaWidth, workAreaHeight]
}

GetWindowDimensions(Window) {
    WinGet, style, Style, %Window%
    if (isFullscreen := !(style & 0x20800000))
        return {}

    WinGetPos, winX, winY, winWidth, winHeight, %Window%
    if (isMaximised := style & 0x1000000)
        winY := 0, winHeight -= SM_CYFRAME

    return { x1    : winX + SM_CXFRAME
           , y1    : winY + SM_CYFRAME + SM_CYCAPTION
           , x2    : winX + winWidth  - SM_CXFRAME
           , y2    : winY + winHeight - SM_CYFRAME
           , width : winWidth  - SM_CXFRAME*2
           , height: winHeight - SM_CYFRAME*2 - SM_CYCAPTION}
}

GetMinecraftProcesses() {
    local tPtr := 0, pPtr := 0, nTTL := 0, processName, processID, list := []
  
    if !DllCall("Wtsapi32\WTSEnumerateProcesses", "Ptr", 0, "Int", 0, "Int", 1, "PtrP", pPtr, "PtrP", nTTL)
        return "", DllCall("SetLastError", "Int", -1)        
    
    tPtr := pPtr
    loop, % nTTL {
        processName := StrGet(NumGet(tPtr + 8))
        processID   := NumGet(tPtr + 4, "UInt")
        if (processName == "Minecraft.Windows.exe")
            list.push(processID)

        tPtr += (A_PtrSize == 4 ? 16 : 24)
    }
    DllCall("Wtsapi32\WTSFreeMemory","Ptr", pPtr)      
  
    return list, DllCall("SetLastError", "UInt", nTTL)
}

GetMinecraftHwnds() {
    hwnds := []
    WinGet, var, List, Minecraft
    Loop, % var
        hwnds.push(var%A_Index%)
    return hwnds
}

GetMinecraftVersion() {
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
    return MCversion, LogF("INF", "Current Minecraft Version: " MCversion)
}

ConfigureMinecraftPointers() {
    offsetsX := offsetsZ := offsetsAutoSplit := offsetsScreen := ""

    switch MCversion := GetMinecraftVersion() {
        case "1.19.50.2": offsetsX          := [0x048E3910, 0x10, 0x128, 0x0, 0xF8, 0x398, 0x18, 0x0, 0x8] 
                          offsetsZ          := [0x048E3910, 0x10, 0x128, 0x0, 0xF8, 0x398, 0x18, 0x0, 0x10]
                        ;   offsetsAutoSplit  := [0x04974880, 0x0, 0x28, 0xA0]
        case "1.19.0.5" : offsetsX          := [0x0411B880, 0x10, 0x1F0, 0x0, 0x150, 0x0, 0x20, 0xA0, 0x48, 0x0, 0xE8]
                          offsetsZ          := [0x0411B880, 0x10, 0x1F0, 0x0, 0x150, 0x0, 0x20, 0xA0, 0x48, 0x0, 0xEA]
                          offsetsAutoSplit  := [0x041C51B8, 0x0, 0x28, 0x88]
        case "1.16.221.1":offsetsX          := [0x0360A218, 0x30, 0x70, 0x0, 0x30, 0x8, 0x2C]
                          offsetsAutoSplit  := [0x0394BFA8, 0x0, 0xC0, 0x7B0]
        case "1.16.10.2": offsetsX          := [0x036A3C18, 0xA8, 0x10, 0x954]
                          offsetsAutoSplit  := [0x036AB670, 0x28, 0x198, 0x10, 0x150, 0x798]
        case "1.16.1.2" : offsetsX          := [0x0369D0A8, 0xA8, 0x10, 0x954]
                          offsetsAutoSplit  := [0x036A4B00, 0x28, 0x198, 0x10, 0x150, 0x798]
                          offsetsScreen     := [0x036A4B00, 0x28, 0x198, 0x10, 0x210, 0x18]
        case "1.16.0.58": offsetsX          := [0x038464D8, 0x190, 0x20, 0x0, 0x2C]
        case "1.16.0.57": offsetsX          := [0x03846490, 0x190, 0x20, 0x0, 0x2C]
        case "1.16.0.51": offsetsX          := [0x035C6298, 0x190, 0x20, 0x0, 0x2C]
        case "1.14.60.5": offsetsX          := [0x0307D3A0, 0x30, 0xF0, 0x110]
        case "1.2.13.54": offsetsX          := [0x01FA1888, 0x0, 0x10, 0x10, 0x20, 0x0, 0x2C]
                          offsetsScreen     := [0x01F2F5F8, 0xD0, 0x58]

        default:
            LogF("INF", "Auto-reset through memory is not supported")
    }
    isPre11830 := VerCompare(MCversion, "1.18.30") < 0
}

CheckMinecraftSettings() {
    txtOptions := minecraftDir "\minecraftpe\options.txt"
    if !FileExist(txtOptions)
        return LogF("WAR", "File doesn't exist at """ txtOptions """; Unable to check MC settings", A_ThisFunc ":NoOptionsFile")

    optionsToUpdate := {}
    FileRead, settingsData, %txtOptions%
    RegExMatch(settingsData, "(gfx_fullscreen:)\K.*", gfx_fullscreen)
    RegExMatch(settingsData, "(screen_animations:)\K.*", screen_animations)
    RegExMatch(settingsData, "(gfx_guiscale_offset:)\K.*", gfx_guiscale_offset)
    RegExMatch(settingsData, "(gfx_safe_zone_x:)\K.*", gfx_safe_zone_x)
    RegExMatch(settingsData, "(gfx_safe_zone_y:)\K.*", gfx_safe_zone_y)

    if gfx_fullscreen {
        LogF("WAR", "gfx_fullscreen is enabled", A_ThisFunc ":gfx_fullscreen")
        optionsToUpdate["gfx_fullscreen"] := 0
    }

    if screen_animations {
        LogF("WAR", "screen_animations is enabled", A_ThisFunc ":screen_animations")
        optionsToUpdate["screen_animations"] := 0
    }

    if gfx_guiscale_offset
        LogF("WAR", "gfx_guiscale_offset is enabled; setupless will not work", A_ThisFunc ":gfx_guiscale_offset")

    if (gfx_safe_zone_x + gfx_safe_zone_y - 2) ; gfx_safe_zone_x != 1 || gfx_safe_zone_y != 1
        LogF("WAR", "gfx_safe_zone is set; setupless will not work", A_ThisFunc ":gfx_safe_zone")
    
    if optionsToUpdate.count() {
        optionsToUpdateString := ""
        for option, value in optionsToUpdate
            optionsToUpdateString .= option " = " value "`n"
        MsgBox, 4,, % "Apply Minecraft settings to suit Multi-Resets?`n`n" optionsToUpdateString
        IfMsgBox, No
            return

        for option, value in optionsToUpdate
            settingsData := RegExReplace(settingsData, "(" option ":)\K.*", value)
        txt := FileOpen(txtOptions, "w")
        txt.write(settingsData)
        txt.close()

        if WinExist("Minecraft")
            MsgBox, % "Restart Minecraft to apply."
    }
}

GetMCScale(w, h, applyDPI:=false) {
    if applyDPI {
        w += SM_CXFRAME*2
        h += SM_CYFRAME*2 + SM_CYCAPTION
    }
    x := 1 + (w-394+0.8) // 375.3333 ; approximate
    y := 1 + (h-290-1  ) // 250

    return x < y ? x : y
}

SetAffinity(pid, mask) {
    if (hProcess := DllCall("OpenProcess", "UInt", 0x0200, "Int", 0, "Int", pid)) {
        DllCall("SetProcessAffinityMask", "Ptr", hProcess, "Ptr", mask)
        DllCall("CloseHandle", "Ptr", hProcess)
    }
}

CloseInstances() {
    MCInstances := []
    replacementInstances := []
    queuedInstances := []

    Process, Exist, Minecraft.Windows.exe
    while ErrorLevel {
        Process, Close, Minecraft.Windows.exe
        Process, Exist, Minecraft.Windows.exe
    }
}

OpenMinecraftDir() {
    Run, %minecraftDir%
}

UpdateResetAttempts(amount := 1) {
    txt := FileOpen("configs/attempts.txt", "r") ; open/reads txt
    attempts := txt.read() + amount
    if amount {
        txt := FileOpen("configs/attempts.txt", "w") ; overwrites txt
        txt.write(attempts)
    }
    txt.close()

    return attempts
}

ShouldRestart(resetCounter) {
    if !lastRestart {
        lastRestart := resetCounter
        return false
    }

    if (lastRestart + resetThreshold <= resetCounter) {
        Gosub, Restart
        Exit
    }
}

WorldBopper(action := "r", targetWorldName := "My World", daysBefore := 512) {
    static isDeleting := false
    static isCalculating := false

    if isCalculating
        return
    isCalculating := true
    WB.document.getElementById("bopToBeDeleted").textContent := "Worlds to be deleted: Calculating..."

    daysBefore := daysBefore == "" ? 2048 : daysBefore
    Worlds := []
    Loop, Files, % minecraftDir "\minecraftWorlds\*", D
    {
        FileRead, worldName, % A_LoopFileFullPath "\levelname.txt"
        FileGetTime, lastPlayed, % A_LoopFileFullPath "\level.dat"

        Worlds.push({ folder: A_LoopFileName, lastPlayed: lastPlayed, worldName: worldName })
    }
    
    selectedWorlds := []
    For k, world in Worlds
        if ((world.worldName == targetWorldName || targetWorldName == "") && DateToSeconds(A_NOW)-DateToSeconds(world.lastPlayed) < daysBefore*86400)
            selectedWorlds.push(world)
    isCalculating := false

    if (action == "r") {
        inputName := WB.document.getElementById("bopName").value, inputName := inputName == "" ? "My World" : inputName
        inputDays := WB.document.getElementById("bopDays").value, inputDays := inputDays == "" ? 2048 : inputDays
        if (inputName != targetWorldName || inputDays != daysBefore)
            return WorldBopper("r", inputName, inputDays)

        WB.document.getElementById("bopToBeDeleted").textContent := "Worlds to be deleted: " selectedWorlds.count() " out of " Worlds.count()
        return selectedWorlds
    }
    else if (action == "d") {
        isDeleting := true
        total := selectedWorlds.count()

        Gui_UpdateProgress(true, 0, "0%", Func("JS_AHK").bind("WorldBopper", "c"))
        For k, world in selectedWorlds
        {
            if !isDeleting
                break
            FileRemoveDir, % minecraftDir "\minecraftWorlds\" world.folder, 1
            precentageDone := Floor(k / total * 100)
            Gui_UpdateProgress(true, precentageDone, precentageDone "% (" k "/" total ")", 1)
        }
        Gui_UpdateProgress(false, 0, "0%")
        
        return WorldBopper("r", WB.document.getElementById("bopName").value, WB.document.getElementById("bopDays").value)
    }
    else if (action == "da") {
        MsgBox, 4, % "World Bopper", % "Are you sure you want to delete all worlds?"
        IfMsgBox, No
            return

        FileRemoveDir, % minecraftDir "\minecraftWorlds", 1
        
        Loop, 15 {
            folder := minecraftDir "\minecraftWorlds\placeholder" A_Index
            FileCreateDir, %folder%
            FileCopy, assets/placeholderlevel.dat, % folder "\level.dat"
        }
        MsgBox,, % "World Bopper", % "Done deleting all worlds."
        return WorldBopper("r", WB.document.getElementById("bopName").value, WB.document.getElementById("bopDays").value)
    }
    else if (action == "c") {
        isDeleting := false
    }
}

DateToSeconds(date) {
    ; ignoring leap stuff because too much work
    ; also this will break if year >= 10000, just a reminder for anyone in the year 10000

    year := SubStr(date, 1, 4)
    month := SubStr(date, 5, 2)
    day := SubStr(date, 7, 2)
    hour := SubStr(date, 9, 2)
    minute := SubStr(date, 11, 2)
    second := SubStr(date, 13, 2)

    return year*31536000+month*2629800+day*86400+hour*3600+minute*60+second
}

IsMultiRegistered() {
    foundPackageName := ""
    Loop, Reg, % "HKCU\SOFTWARE\Classes\Extensions\ContractId\Windows.Launch\PackageId\", K
    {
        if (SubStr(A_LoopRegName, 1, 23) == "Microsoft.MinecraftUWP_") {
            if foundPackageName
                break
            foundPackageName := A_LoopRegName
        } else if foundPackageName { ; since it iterates alphabetically, we can assume we found the only and correct package name
            RegRead, multiState, HKCU, % "SOFTWARE\Classes\Extensions\ContractId\Windows.Launch\PackageId\" foundPackageName "\ActivatableClassId\App\CustomProperties", SupportsMultipleInstances
            return multiState
        }
    }

    ; backup method; slower (~500ms)
    cmd := "(Get-AppxPackage -Name Microsoft.MinecraftUWP).'PackageFullName' > '" A_ScriptDir "\configs\mc-package-name.txt'"
    RunWait, PowerShell.exe -Command &{%cmd%},, Hide
    FileRead, packageName, configs\mc-package-name.txt
    FileDelete, configs\mc-package-name.txt
    packageName := Trim(packageName, "`r`n")

    RegRead, multiState, HKCU, % "SOFTWARE\Classes\Extensions\ContractId\Windows.Launch\PackageId\" packageName "\ActivatableClassId\App\CustomProperties", SupportsMultipleInstances
    return multiState
}

GetSpawnChance(min, max) {
    if (min > max)
        return 0
    FileRead, data, assets/spawn_data.txt
    dataArray := StrSplit(data, "`n")
    total := 9999251
    totalInRange := 0
    iMin := Ceil((min-44)/4)
    iMax := (max-44)//4
    it := (iMax-iMin)+1
    Loop, % it {
        totalInRange += dataArray[iMin+A_Index]
    }
    return Floor(totalInRange/total*100*100)/100
}

LogF(level, msg, id:=0) {
    static cleared, logText, loggedIDs := {}, guiLogQueue := []
    if !cleared {
        cleared := true
        FileDelete, assets/log.txt
    }
    if id {
        if loggedIDs[id]
            return
        loggedIDs[id] := true
    }

    out := "[" A_Hour ":" A_Min ":" A_Sec "] [" level "] " msg "`n"
    FileAppend, %out%, assets/log.txt

    if !logText { ; so goofy
        logText := WB.document.getElementById("logText")
        if !logText
            guiLogQueue.push(out)
    }
    if logText {
        logText["value"] .= out
        if guiLogQueue {
            missedLogs := ""
            for k, log in guiLogQueue
                missedLogs .= log
            logText["value"] := missedLogs . logText["value"]
            guiLogQueue := []
        }
    }
}

GlobalMemoryStatusEx() {
    static MEMORYSTATUSEX, init := VarSetCapacity(MEMORYSTATUSEX, 64, 0) && NumPut(64, MEMORYSTATUSEX, "UInt")
    if !DllCall("kernel32.dll\GlobalMemoryStatusEx", "Ptr", &MEMORYSTATUSEX)
		return DllCall("kernel32.dll\GetLastError")

    return { Lenght:        NumGet(MEMORYSTATUSEX,  0, "UInt"  ), MemoryLoad:    NumGet(MEMORYSTATUSEX,  4, "UInt")
           , TotalPhys:     NumGet(MEMORYSTATUSEX,  8, "UInt64"), AvailPhys:     NumGet(MEMORYSTATUSEX, 16, "UInt64")
           , TotalPageFile: NumGet(MEMORYSTATUSEX, 24, "UInt64"), AvailPageFile: NumGet(MEMORYSTATUSEX, 32, "UInt64")
           , TotalVirtual:  NumGet(MEMORYSTATUSEX, 40, "UInt64"), AvailVirtual:  NumGet(MEMORYSTATUSEX, 48, "UInt64")
           , AvailExtendedVirtual: NumGet(MEMORYSTATUSEX, 56, "UInt64") }
}

GetFontNames(charset) {
   hDC := DllCall("GetDC", "UInt", 0, "Ptr")
   VarSetCapacity(LOGFONT, 92, 0)
   NumPut(charset, &LOGFONT + 23, "UChar")
   DllCall("EnumFontFamiliesEx", "Ptr", hDC, "Ptr", 0
                               , "Ptr", RegisterCallback("EnumFontFamExProc", "F", 4)
                               , "Ptr", pFonts := Object(Fonts := {}), "UInt", 0)
   ObjRelease(pFonts), DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
   return Fonts
}

EnumFontFamExProc(lpelfe, lpntme, FontType, lParam) {
   font := StrGet(lpelfe + 28)
   Object(lParam)[font] := 1
   return true
}

GetExcludedFromList(list, excludeList) {
    returnList := []
    for i, item in list {
        for ii, excludeItem in excludeList {
            if (item == excludeItem)
                continue, 2
        }
        returnList.push(item)
    }
    return returnList
}

CountNonNull(array) {
    count := 0

    for k, v in array {
        if ((!IsObject(v) && v) || v.count())
            count++
    }

    return count
}
