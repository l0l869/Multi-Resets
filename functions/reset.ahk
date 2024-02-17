Reset:
    hasExited := ExitIfRunning()

    if (resetMode == "manual") {
        if !hasExited
            for k, instance in MCInstances
                if (instance.isResetting <= 0)
                    instance.isResetting := 1
        ResetInstances()
    } else if (resetMode == "cumulative" && queuedInstances.count()) {
        nextInstance := queuedInstances.MaxIndex()
        ResumeProcess(queuedInstances[nextInstance].pid)
        MCInstances.push(queuedInstances[nextInstance])
        queuedInstances.RemoveAt(nextInstance, 1)
        RunInstance(MCInstances[MCInstances.MaxIndex()])
    } else {
        for k, instance in MCInstances
            if (instance.isResetting == 0)
                instance.isResetting := 1
        ResetInstances()
    }
return

StopReset:
    isResetting := IsResettingInstances()

    if (resetMode == "manual" && !isResetting) {
        EnterHoveredInstance()
        return
    }
    
    if isResetting {
        Critical
        for k, instance in MCInstances
            instance.isResetting := 0
        Critical, Off

        if (resetMode == "cumulative" && queuedInstances.count())
            Gosub, Reset
    }
return

Restart:
CloseInstances()
Loop, %numInstances%
    MCInstances[A_Index] := LaunchInstance(A_Index)
ConfigureMinecraftPointers()
lastRestart := UpdateResetAttempts(0)
return

StartTimer:
timer1.start()
return

StopTimer:
timer1.stop()
Return

ResetTimer:
timer1.reset()
return

ResetInstances() {
    CoordMode, Mouse, Screen
    CoordMode, Pixel, Screen
    
    seamlessRestart := autoRestart == "true" && seamlessRestarts == "true"
    if (autoRestart == "true" && seamlessRestarts == "false")
        ShouldRestart(UpdateResetAttempts(0))

    if (isBored == "true")
        gameScript.Show()

    while (IsResettingInstances())
    {
        if (seamlessRestart) {
            currentResetAttempts := UpdateResetAttempts(0)
            if (!lastRestart)
                lastRestart := currentResetAttempts

            if (!replacementInstances.count()) {
                Loop, %numInstances%
                    replacementInstances[A_Index] := LaunchInstance(A_Index)
                SuspendInstancesFunc := Func("SuspendInstances").bind(replacementInstances)
                SetTimer, %SuspendInstancesFunc%, -40000
            }
            else if (lastRestart+resetThreshold <= currentResetAttempts) {
                lastRestart := currentResetAttempts

                for k, instance in MCInstances {
                    while WinExist("ahk_id " instance.hwnd)
                        Process, Close, % instance.pid
                }
                for k, instance in replacementInstances {
                    ResumeProcess(instance.pid)
                    instance.isResetting := 1
                }

                MCInstances := replacementInstances
                replacementInstances := []
            }
        }

        for k, instance in MCInstances {
            if (instance.isResetting <= 0)
                continue

            IterateReset(instance)
        }
    }
    gameScript.Hide()
}

IterateReset(instance) {
    if (WinActive("ahk_id " instance.hwnd))
       WinActivate, ahk_class Shell_TrayWnd
    MouseMove, % instance.x1 + instance.width/2, % instance.y1 + instance.height/2
    Sleep, % 10 + switchDelay
    WinActivate, % "ahk_id " instance.hwnd
    Sleep, %switchDelay%

    currentClick := GetCurrentClick(instance, resetMethod)
    currentScreen := currentClick[1]
    clickX := currentClick[2]
    clickY := currentClick[3]

    if (isBored == "true")
        gameScript.AllowClick({x:instance.x1+clickX,y:instance.y1+clickY})

    switch (currentScreen)
    {
        case "Play":
            if (instance.lastClick+3000 > A_TickCount)
                return
            instance.lastClick := A_TickCount
            MouseClick,, instance.x1 + clickX, instance.y1 + clickY,, 0, D
            Sleep, %clickDuration%
            MouseClick,, instance.x1 + clickX, instance.y1 + clickY,, 0, U
            return instance.isResetting := (instance.isResetting ? 3 : 0)

        case "Heart":
            Send, {Esc}
            Sleep, 100
            if (instance.isResetting == 1)
                return instance.isResetting := 2

            if (resetMode == "manual")
                return instance.isResetting := (instance.isResetting ? -2 : 0)
            else if (ShouldAutoReset(instance))
                return instance.isResetting := (instance.isResetting ? 1 : 0)
            else if (resetMode == "cumulative") {
                SaveInstance(instance)
                if (queuedInstances.count() >= queueLimit)
                    Gosub, StopReset
                return
            }

            return RunInstance(instance)

        case "SaveAndQuit":
            MouseClick,, instance.x1 + clickX, instance.y1 + clickY,, 0, D
            Sleep, %clickDuration%
            MouseClick,, instance.x1 + clickX, instance.y1 + clickY,, 0, U
            return instance.isResetting := (instance.isResetting ? 3 : 0)

        case "CreateNew":
            if (instance.isResetting == 4 && instance.lastClick+2000 > A_TickCount)
                return
            instance.lastClick := A_TickCount
            MouseClick,, instance.x1 + clickX, instance.y1 + clickY,, 0, D
            Sleep, %clickDuration%
            MouseClick,, instance.x1 + clickX, instance.y1 + clickY,, 0, U
            return instance.isResetting := (instance.isResetting ? 4 : 0)

        case "CreateNewWorld":
            MouseClick,, instance.x1 + clickX, instance.y1 + clickY,, 0, D
            Sleep, %clickDuration%
            MouseClick,, instance.x1 + clickX, instance.y1 + clickY,, 0, U
            return instance.isResetting := (instance.isResetting ? 5 : 0)

        case "WorldCreation":
            if (instance.isResetting == 6 && instance.lastClick+5000 > A_TickCount)
                return
            instance.lastClick := A_TickCount

            if (resetMethod == "setupless") {
                scale := GetMCScale(instance.width, instance.height, true)
                selector_area := [instance.width*.4-(3*scale), instance.height-26*scale]
                content_area := [instance.width*.6-(8*scale), instance.height-26*scale]
                create_button := [selector_area[1]/4+(2*scale), 22*scale + selector_area[1]*92/160 + 10*scale]
                xContent := instance.width - content_area[1] + 10*scale

                difficulty := 155*scale
                wcClicks := [{x: xContent, y: difficulty}, {x: xContent, y: difficulty+5*scale}]
                if (content_area[2] < 407*scale) {
                    scrollbar := [instance.width - 5*scale, instance.height-((28+2)*scale)]
                    scrollersize := content_area[2]/(870*scale)*scrollbar[2]

                    scrollend := {x: instance.width - 5*scale, y: instance.height - 5*scale}
                    scrollto := {x: instance.width - 5*scale, y: scrollbar[2]*(420/870)-scrollersize/2 +28*scale}
                    wcClicks.push(scrollend, scrollto)

                    simulation := {x: xContent, y: instance.height-5*scale}
                    coordinates := {x: xContent, y: instance.height-65*scale}
                } else {
                    simulation := {x: xContent, y: 380*scale}
                    coordinates := {x: xContent, y: 433*scale}
                }
                create_button := {x: create_button[1], y: create_button[2]}
                wcClicks.push(simulation, coordinates, create_button)
            } else {
                wcClicks := worldcreationClicks
            }

            for k, click in wcClicks {
                Sleep, %keyDelay%
                if (isBored == "true")
                    gameScript.AllowClick({x:instance.x1+click.x,y:instance.y1+click.y})
                MouseClick,, instance.x1 + click.x, instance.y1 + click.y,,0
            }
            Sleep, 25 ; click doesnt register with mousemove right after
            UpdateResetAttempts()
            return instance.isResetting := (instance.isResetting ? 6 : 0)
    }
}

ShouldAutoReset(instance) {
    if (MCversion == "1.19.50.2")
    {
        startTick := A_TickCount
        while !xCoord := ReadMemoryValue(instance.proc, "Float", offsetsX*)
            if (A_TickCount - startTick > 2000)
                return true

        startTick := A_TickCount
        while !zCoord := ReadMemoryValue(instance.proc, "Float", offsetsZ*)
            if (A_TickCount - startTick > 2000)
                return true

        if (Sqrt(xCoord**2 + zCoord**2) < originDistance)
            return true
    }
    else {
        startTick := A_TickCount
        while !xCoord := ReadMemoryValue(instance.proc, "Float", offsetsX*)
            if (A_TickCount - startTick > 2000)
                return true

        if (xCoord < minCoords || xCoord > maxCoords)
            return true
    }
}

IsResettingInstances() {
    for k, instance in MCInstances
        if (instance.isResetting > 0)
            return true

    return false
}

ExitIfRunning() {
    for k, instance in MCInstances
        if (instance.isResetting == -1)
            return ExitInstance()

    return false
}

RunInstance(instance) {
    if (instance.isResetting == -1)
        return
    SetAffinity(instance.pid, 2**threadCount - 1)
    instance.isResetting := -1
    For k, v in MCInstances {
        if (v.hwnd == instance.hwnd) {
            timer1.currentInstance := k
            break
        }
    }

    if (coopMode == "true") {
        while (isResettingInstances()) {
            for k, inst in MCInstances {
                if (inst.isResetting == 5) {
                    inst.isResetting -= 100
                    SuspendProcess(inst.pid)
                } else if (inst.isResetting == 6)
                    inst.isResetting := 1
                else if (inst.isResetting > 0)
                    IterateReset(inst)
            }
        }
        WinActivate, ahk_class Shell_TrayWnd
        while !WinActive("ahk_id " instance.hwnd) {
            WinMaximize, % "ahk_id " instance.hwnd
            WinActivate, % "ahk_id " instance.hwnd
            Sleep, 100
        }
    } else {
        WinActivate, ahk_class Shell_TrayWnd
        while !WinActive("ahk_id " instance.hwnd) {
            WinMaximize, % "ahk_id " instance.hwnd
            WinActivate, % "ahk_id " instance.hwnd
            Sleep, 100
        }

        for k, inst in MCInstances {
            if (inst.isResetting >= 0 || inst.isResetting == -2) {
                inst.isResetting -= 100
                SuspendProcess(inst.pid)
            }
        }
    }
}

ExitInstance() {
    timer1.currentInstance := 0
    timer1.reset()
    if (resetMode == "cumulative" && MCInstances[numInstances+1].isResetting == -1) {
        for k, instance in MCInstances
            if (instance.isResetting == -1)
                WinClose, % "ahk_id " instance.hwnd
        MCInstances.pop()

        if (queuedInstances.count())
            return true
    }
    for k, instance in MCInstances {
        if (instance.isResetting == -1) {
            WinRestore, % "ahk_id " instance.hwnd
            Sleep, 100
            instance.isResetting := 1
            threadsMask := (2 ** Ceil(threadCount * threadsUsage)) - 1
            SetAffinity(instance.pid, threadsMask)
        }
        else if (instance.isResetting < -10) {
            ResumeProcess(instance.pid)
            instance.isResetting += 100
        }
    }
    Sleep, 100
    return true
}

EnterHoveredInstance() {
    CoordMode, Mouse, Screen
    MouseGetPos, mX, mY
    for k, instance in MCInstances
        if ((mX > instance.x1 && mX < instance.x2) && (mY > instance.y1 && mY < instance.y2))
            return RunInstance(instance)
}

GetCurrentClick(instance, method) {
    currentScreen := ""
    clickX := -1
    clickY := -1
    if (method == "setupless") {
        returnedCode := -1
        DllCall("reset\GetCurrentClick", "UPtr", instance.hwnd, "Int", scaleBy, "Int*", returnedCode, "Int*", clickX, "Int*", clickY)

        switch returnedCode {
            case -1: return
            case 0: currentScreen := "Heart"
            case 1: currentScreen := "SaveAndQuit"
            case 2: currentScreen := "CreateNew"
            case 3: currentScreen := "CreateNewWorld"
            case 4: currentScreen := "WorldCreation"
            case 5: currentScreen := "Play"
        }
        if (currentScreen == "SaveAndQuit" && instance.isResetting == 6) ; if it skips checking coords
            currentScreen := "Heart"
    } else { 
        currentScreen := GetCurrentScreen(instance)
        switch currentScreen {
            case "Play": index := 1
            case "SaveAndQuit": index := 3
            case "CreateNew": index := 4
            case "CreateNewWorld": index := 5
        }
        clickX := screenClicks[index].x
        clickY := screenClicks[index].y
    }
    return [currentScreen, clickX, clickY]
}

GetCurrentScreen(instance) {
    currentScreen := ""

    if (readScreenMemory == "true") {

        startTick := A_TickCount
        while !valueUI := ReadMemoryValue(instance.proc, "Int", offsetsScreen*) {
            if (A_TickCount-startTick > 3000) {
                MsgBox, % "failed to get current screen from memory: " valueUI
                Exit
            }
        }

        if (offsetsScreen[1] == 0x036A4B00) { ; 1.16.1.2
            switch (valueUI) {
                case 3: currentScreen := "Heart"
                case 5: currentScreen := "CreateNew"
                case 6: currentScreen := "CreateNewWorld"
                case 7: currentScreen := "WorldCreation"
            }
        }
        else { ; 1.2.13.54
            switch (valueUI) {
                case 4: currentScreen := "Heart"
                case 6: currentScreen := "CreateNew"
                case 7: currentScreen := "CreateNewWorld"
                case 8: currentScreen := "WorldCreation"
            }
        }

        if (currentScreen == "Heart" && instance.isResetting == 2)
            currentScreen := "SaveAndQuit"

        if (currentScreen == "CreateNewWorld" && instance.isResetting == 3)
            currentScreen := "" ; exiting world

    }
    else { ; pixel search
        for k, btn in screenClicks {
            if (!instance.clicksAllowed)
                gameScript.AllowClick({x:instance.x1+btn.px, y:instance.y1+btn.py}, 99999999)
            PixelGetColor, pixelColour, instance.x1+btn.px, instance.y1+btn.py, RGB
            if (pixelColour == btn.colour) {
                currentScreen := btn.btn
                break
            }
        }
        instance.clicksAllowed := true
    }

    if (currentScreen == "SaveAndQuit" && instance.isResetting == 6) ; if it skips checking coords
        currentScreen := "Heart"

    return currentScreen
}

ReadMemoryValue(process, dataType, baseOffset, offsets*) {
    return process.read(process.baseAddress + baseOffset, dataType, offsets*)
}

SuspendProcess(pid) {
    if (hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)) {
        DllCall("ntdll.dll\NtSuspendProcess", "Int", hProcess)
        DllCall("CloseHandle", "Int", hProcess)
    }
}

ResumeProcess(pid) {
    if (hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)) {
        DllCall("ntdll.dll\NtResumeProcess", "Int", hProcess)
        DllCall("CloseHandle", "Int", hProcess)
    }
}