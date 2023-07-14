Reset:
    if ExitIfRunning()
        return

    for k, instance in MCInstances
        if (instance.isResetting == 0)
            instance.isResetting := 1

    SetTimer, ResetInstances, -0
return

StopReset:
    SetTimer, ResetInstances, Off

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

    for k, btn in screenClicks
    {
        PixelGetColor, pixelColour, instance.x1+btn.x, instance.y1+btn.y, RGB
        if (pixelColour != btn.colour)
            continue

        switch (btn.btn)
        {
            case "Heart":
                Send, {Esc}
                if(instance.isResetting == 1)
                    return instance.isResetting := 2

                xCoord := ReadMemoryValue(instance.proc, "Float", offsetsCoords*)
                if (xCoord < minCoords || xCoord > maxCoords)
                    return instance.isResetting := (instance.isResetting ? 1 : 0) ;dumb fix for stop reset

                return RunInstance(instance)
    
            case "SaveAndQuit", "CreateNew", "CreateNewWorld":
                MouseClick,, instance.x1+btn.x, instance.y1+btn.y,,0
                Sleep, 50
                return instance.isResetting := (instance.isResetting ? 3 : 0)
    
            case "World":
                if (instance.isResetting == 4)
                    return

                for k, click in worldcreationClicks
                {
                    MouseClick,, instance.x1+click.x, instance.y1+click.y,,0
                    Sleep, %keyDelay%
                }
                Sleep, % 50-keyDelay ; click doesnt register with mousemove right after
                UpdateResetAttempts()
                return instance.isResetting := (instance.isResetting ? 4 : 0)
        }
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
    SetTimer, ResetInstances, -0
    return 1
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