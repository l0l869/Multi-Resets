Reset:
    if ExitIfRunning()
        return

    for k, instance in MCInstances
        if (instance.isResetting == 0)
            instance.isResetting := 1

    ResetInstances()
return

StopReset:
    for k, instance in MCInstances
        instance.isResetting := 0
return

Restart:
    LaunchInstances(numInstances)
return

ResetInstances()
{
    CoordMode, Mouse, Screen
    CoordMode, Pixel, Screen
    
    if (autoRestart == "true")
        ShouldRestart(UpdateResetAttempts(0))

    while (IsResettingInstances())
        for k, instance in MCInstances
        {
            if (!instance.isResetting)
                Continue

            IterateReset(instance)
        }
}

IterateReset(instance)
{
    MouseMove, % instance.x1+instance.width/2, % instance.y1+instance.height/2
    Sleep, 10
    WinActivate, % "ahk_id " instance.hwnd

    ; safer
    ; if WinActive("Minecraft")
    ;     WinActivate, ahk_class Shell_TrayWnd
    ; MouseMove, % instance.x1+instance.width/2, % instance.y1+instance.height/2

    ; WinActivate, % "ahk_id " instance.hwnd

    switch GetCurrentScreen(instance)
    {
        case "Heart":
            Send, {Esc}
            if(instance.isResetting == 1)
                return instance.isResetting := 2

            startTick := A_TickCount
            while !xCoord := ReadMemoryValue(instance.proc, "Float", offsetsCoords*)
                if (A_TickCount - startTick > 2000)
                    return

            if (xCoord < minCoords || xCoord > maxCoords)
                return instance.isResetting := (instance.isResetting ? 1 : 0) ;dumb fix for stop reset

            return RunInstance(instance)

        case "SaveAndQuit":
            MouseClick,, instance.x1+screenClicks[2].x, instance.y1+screenClicks[2].y,,0
            return instance.isResetting := (instance.isResetting ? 3 : 0)

        case "CreateNew":
            MouseClick,, instance.x1+screenClicks[3].x, instance.y1+screenClicks[3].y,,0
            return instance.isResetting := (instance.isResetting ? 4 : 0)

        case "CreateNewWorld":
            MouseClick,, instance.x1+screenClicks[4].x, instance.y1+screenClicks[4].y,,0
            return instance.isResetting := (instance.isResetting ? 5 : 0)

        case "World":
            if (instance.isResetting == 6)
                return

            for k, click in worldcreationClicks
            {
                MouseClick,, instance.x1+click.x, instance.y1+click.y,,0
                Sleep, %keyDelay%
            }
            Sleep, % 50-keyDelay ; click doesnt register with mousemove right after
            UpdateResetAttempts()
            return instance.isResetting := (instance.isResetting ? 6 : 0)
    }
}

IsResettingInstances(){
    for k, instance in MCInstances
        if (instance.isResetting > 0)
            return true

    return false
}

ExitIfRunning() {
    for k, instance in MCInstances
        if (instance.isResetting == -1)
            return ExitInstance()
}

RunInstance(instance)
{
    if (instance.isResetting == -1)
        return
    
    instance.isResetting := -1

    for k, inst in MCInstances
    {
        if (inst.isResetting >= 0)
        {
            inst.isResetting -= 100
            SuspendProcess(inst.pid)
        }
    }

    SetAffinity(instance.pid, 2 ** threadCount - 1)
    WinMaximize, % "ahk_id " instance.hwnd
    exit
}

ExitInstance()
{
    for k, instance in MCInstances
    {
        if (instance.isResetting == -1) {
            WinRestore, % "ahk_id " instance.hwnd
            instance.isResetting := 1
        } else if (instance.isResetting < -10) {
            ResumeProcess(instance.pid)
            instance.isResetting += 100
        }
    }
    Sleep, 100

    threadsMask := (2 ** Ceil(threadCount * threadsUsage)) - 1
    SetAffinity(instance.pid, threadsMask)
    ResetInstances()
    return 1
}

GetCurrentScreen(instance)
{
    currentScreen := ""

    if (readScreenMemory == "true"){

        startTick := A_TickCount
        while !valueUI := ReadMemoryValue(instance.proc, "Int", offsetsScreen*)
        {
            if (A_TickCount-startTick > 3000){
                MsgBox, % "failed to get current screen from memory: " valueUI
                Exit
            }
        }

        if (offsetsScreen[1] == 0x036A4B00) ; 1.16.1.2
        {
            switch (valueUI)
            {
                case 3: currentScreen := "Heart"
                case 5: currentScreen := "CreateNew"
                case 6: currentScreen := "CreateNewWorld"
                case 7: currentScreen := "World"
            }
        } else { ; 1.2.13.54
            switch (valueUI)
            {
                case 4: currentScreen := "Heart"
                case 6: currentScreen := "CreateNew"
                case 7: currentScreen := "CreateNewWorld"
                case 8: currentScreen := "World"
            }
        }

        if (currentScreen == "Heart" && instance.isResetting == 2)
            currentScreen := "SaveAndQuit"

        if (currentScreen == "CreateNewWorld" && instance.isResetting == 3)
            currentScreen := "" ; exiting world

    } else { ; pixel search

        for k, btn in screenClicks
        {
            PixelGetColor, pixelColour, instance.x1+btn.x, instance.y1+btn.y, RGB
            if (pixelColour == btn.colour){
                currentScreen := btn.btn
                break
            }
        }
    }

    return currentScreen
}

ReadMemoryValue(process, dataType, baseOffset, offsets*)
{
    return process.read(process.baseAddress + baseOffset, dataType, offsets*)
}

SuspendProcess(pid) {
    if (hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid))
    {
        DllCall("ntdll.dll\NtSuspendProcess", "Int", hProcess)
        DllCall("CloseHandle", "Int", hProcess)
    }
}

ResumeProcess(pid) {
    if (hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid))
    {
        DllCall("ntdll.dll\NtResumeProcess", "Int", hProcess)
        DllCall("CloseHandle", "Int", hProcess)
    }
}