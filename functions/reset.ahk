Reset:
    hasExited := ExitInstances()

    if (resetMode == "cumulative") {
        Critical, on
        while (nextInstance := queuedInstances.pop()) {
            ResumeProcess(nextInstance.pid)
            if RunInstance(nextInstance) {
                MCInstances.push(nextInstance)
                return
            }
        }
        Critical, Off
    }

    ResumeResettingState()

    if (resetMode == "manualWall" && !hasExited) {
        for k, instance in MCInstances
            if (instance.isResetting == -2)
                instance.isResetting := 1
    }

    ResetInstances()
return

StopReset:
    Critical, On
    if (timer1.mcInstance.suspended) {
        ResumeProcess(timer1.mcInstance.pid)
        timer1.mcInstance.suspended := false
        return
    }

    isResetting := IsResettingInstances()

    if (resetMode == "manualWall" && !isResetting) {
        EnterHoveredInstance()
        return
    }

    if isResetting {
        if (resetMode == "cumulative" && queuedInstances.count()) {
            Critical, Off
            StopCumulativeResets(false)
            return
        }

        for k, instance in MCInstances
            instance.isResetting := 0
    }
    Critical, Off
return

Restart:
    if (numInstances > 1 && !IsMultiRegistered()) {
        MsgBox, 4,, % "Warning: Multi-instance is not registered.`n`nDo you want to register multi?"
        IfMsgBox, Yes
            RunWait, % "configs\scripts\RegisterMulti.ahk 1"
    }

    LogF("INF", "Launching " numInstances " Instances...")
    CloseInstances()
    Loop, %numInstances%
        MCInstances[A_Index] := LaunchInstance(A_Index)
    ConfigureMinecraftPointers()
    lastRestart := UpdateResetAttempts(0)
    LogF("INF", "Launched " CountNonNull(MCInstances) " Instances with " layoutDimensions.x "," layoutDimensions.y " layout")
return

StartTimer:
    timer1.mcInstance := -1
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

    seamlessRestart := autoRestart && seamlessRestarts
    if (autoRestart && !seamlessRestarts)
        ShouldRestart(UpdateResetAttempts(0))

    if isBored
        gameScript.Show()

    for k, instance in MCInstances
        ResizeInstance(instance, k)

    Thread, Priority, 1
    while (IsResettingInstances()) {
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
            if !WinExist("ahk_id " instance.hwnd) {
                MCInstances[k] := LaunchInstance(k)
                MCInstances[k].isResetting := 1
                LogF("WAR", "Instance #" k " not found, relaunching...")
            }

            Critical, On
            if (instance.isResetting <= 0)
                continue
            IterateReset(instance)
            Critical, Off
            Sleep, -1
            UpdateOverlayInterval(500)
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

    if isBored
        gameScript.AllowClick({x:instance.x1+clickX,y:instance.y1+clickY})

    switch (currentScreen) {
        case "Play":
            if (instance.lastClick+3000 > A_TickCount)
                return
            instance.lastClick := A_TickCount
            MouseClick,, instance.x1 + clickX, instance.y1 + clickY,, 0, D
            Sleep, %clickDuration%
            MouseClick,, instance.x1 + clickX, instance.y1 + clickY,, 0, U
            return instance.isResetting := (instance.isResetting ? 3 : 0)

        case "Heart":
            if (instance.isResetting == 1) {
                Send, {Esc}
                Sleep, 100
                return instance.isResetting := 2
            }

            switch (resetMode) {
                case "auto":
                    if (ShouldAutoReset(instance))
                        return instance.isResetting := (instance.isResetting ? 1 : 0)
                case "cumulative":
                    if (ShouldAutoReset(instance))
                        return instance.isResetting := (instance.isResetting ? 1 : 0)

                    SaveInstance(instance)

                    memory := GlobalMemoryStatusEx()
                    usedMemory := (memory.TotalPageFile - memory.AvailPageFile) / 1000000000
                    if (queuedInstances.count() >= queueLimit || memoryLimit < usedMemory)
                        StopCumulativeResets(true)
                    return
                case "setSeed":
                    if (setSeedMouseMove.x || setSeedMouseMove.y) {
                        WinActivate, ahk_class Shell_TrayWnd
                        Sleep, 20
                        MouseMove, % setSeedMouseMove.x, % setSeedMouseMove.y
                    }
                    return RunInstance(instance)
                case "manual": return RunInstance(instance)
                case "manualWall": return instance.isResetting := (instance.isResetting ? -2 : 0)
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
                scale := GetMCScale(instance.width, instance.height)
                selector_area := [instance.width*.4-(3*scale), instance.height-26*scale]
                content_area := [instance.width*.6-(8*scale), instance.height-26*scale]
                create_button := [selector_area[1]/4+(2*scale), 22*scale + selector_area[1]*92/160 + 10*scale]
                xContent := instance.width - content_area[1] + 10*scale

                difficulty := 143*scale
                easy := (offset := instance.height - (difficulty + 60*scale)) > 0 ? difficulty+12*scale : difficulty+12*scale+offset ; difficulty menu is snapped up if it doesnt fit under
                wcClicks := [{x: xContent, y: difficulty}, {x: xContent, y: easy}]
                if (content_area[2] < 407*scale) {
                    scrollbar := [instance.width - 5*scale, instance.height-((28+2)*scale)]
                    scrollersize := content_area[2]/(870*scale)*scrollbar[2]

                    scrollend := {x: instance.width - 5*scale, y: instance.height - 5*scale}
                    scrollto := {x: instance.width - 5*scale, y: scrollbar[2]*(420/870)-scrollersize/2 +28*scale}
                    wcClicks.push(scrollend, scrollto)

                    seed := {x: xContent, y: instance.height-105*scale}
                    simulation := {x: xContent, y: instance.height-65*scale}
                    coordinates := {x: xContent, y: instance.height-5*scale}
                } else {
                    seed := {x: xContent, y: 340*scale, isSeedClick: resetSeed}
                    simulation := {x: xContent, y: 375*scale}
                    coordinates := {x: xContent, y: 433*scale}
                }
                ; when: content_area[1] < 223, text starts getting wrapped
                create_button := {x: create_button[1], y: create_button[2]}
                wcClicks.push(seed, simulation, coordinates, create_button)
            } else {
                wcClicks := worldcreationClicks
            }

            for k, click in wcClicks {
                if (click.isSeedClick && resetMode != "setSeed")
                    continue

                if (click.colour && awaitWcColour) {
                    pixelColour := 0
                    endTick := A_TickCount+5000
                    while (pixelColour != click.colour) {
                        if (A_TickCount > endTick) {
                            LogF("WAR", "Timed Out: Assuming enough time has passed; clicking.")
                            break
                        }
                        PixelGetColor, pixelColour, instance.x1+click.x, instance.y1+click.y, RGB
                    }
                }

                Sleep, %keyDelay%
                if isBored
                    gameScript.AllowClick({x:instance.x1+click.x,y:instance.y1+click.y})
                MouseClick,, instance.x1 + click.x, instance.y1 + click.y,,0

                if click.isSeedClick {
                    Sleep, %keyDelay%
                    Send, %resetSeed%
                }
            }
            Sleep, 25 ; click doesnt register with mousemove right after
            UpdateResetAttempts()
            return instance.isResetting := (instance.isResetting ? 6 : 0)
    }
}

ShouldAutoReset(instance) {
    if isPre11830 {
        xCoord := 0

        if offsetsX && !findCoordsTextOnly {
            startTick := A_TickCount
            while !xCoord := ReadMemoryValue(instance.proc, "Float", offsetsX*)
                if (A_TickCount - startTick > 500) {
                    LogF("WAR", "Timed Out: Couldn't get player coordinates from memory. A_LastError: " A_LastError)
                    break
                }
        }
        if !xCoord {
            VarSetCapacity(coordinates, 12)
            if !DllCall("reset\GetShownCoordinates", "Ptr", instance.hwnd, "UPtr", &coordinates) {
                LogF("WAR", "Couldn't get player coordinates on screen.")
                return true
            }
            xCoord := NumGet(coordinates, 0, "Int")
        }

        if (xCoord < minCoords || xCoord > maxCoords)
            return true
    }
    else {
        xCoord := zCoord := 0

        if offsetsZ && !findCoordsTextOnly {
            startTick := A_TickCount
            while !xCoord := ReadMemoryValue(instance.proc, "Float", offsetsX*)
                if (A_TickCount - startTick > 500) {
                    LogF("WAR", "Timed Out: Couldn't get player coordinates from memory. A_LastError: " A_LastError)
                    break
                }

            startTick := A_TickCount
            while !zCoord := ReadMemoryValue(instance.proc, "Float", offsetsZ*)
                if (A_TickCount - startTick > 100) {
                    LogF("WAR", "Timed Out: Couldn't get player coordinates from memory. A_LastError: " A_LastError)
                    break
                }
        }
        if !xCoord || !zCoord {
            VarSetCapacity(coordinates, 12)
            if !DllCall("reset\GetShownCoordinates", "Ptr", instance.hwnd, "UPtr", &coordinates) {
                LogF("WAR", "Couldn't get player coordinates on screen.")
                return true
            }
            xCoord := NumGet(coordinates, 0, "Int")
            zCoord := NumGet(coordinates, 8, "Int")
        }

        if (Sqrt(xCoord**2 + zCoord**2) < originDistance)
            return true
    }
}

IsResettingInstances() {
    for k, instance in MCInstances
        if (instance.isResetting > 0)
            return true

    return false
}

PauseResettingState() {
    for k, instance in MCInstances {
        if (instance.isResetting > 0 || instance.isResetting == -2) {
            instance.isResetting -= 100
            SuspendProcess(instance.pid)
        }
    }
}

PauseResettingStateUntilWorldCreation() {
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
}

ResumeResettingState() {
    for k, instance in MCInstances {
        if (instance.isResetting == 0) {
            instance.isResetting := 1
        } else if (instance.isResetting < -10) {
            ResumeProcess(instance.pid)
            instance.isResetting += 100
        }
    }
}

StopCumulativeResets(automaticStop := false) {
    PauseResettingState()
    Gosub, Reset
    if automaticStop {
        instance := timer1.mcInstance
        SuspendProcess(instance.pid)
        instance.suspended := true
    }
}

RunInstance(instance) {
    if (instance.isResetting == -1)
        return true

    if !WinExist("ahk_id " instance.hwnd)
        return false

    instance.isResetting := -1
    SetAffinity(instance.pid, 2**threadCount - 1)
    gameScript.Hide()
    timer1.reset()
    timer1.mcInstance := instance

    if coopMode {
        PauseResettingStateUntilWorldCreation()
    } else {
        PauseResettingState()
    }

    WinActivate, ahk_class Shell_TrayWnd
    timeoutTick := A_TickCount + 3000
    while (!WinActive("ahk_id " instance.hwnd) && A_TickCount < timeoutTick) { ; might not be necessary idk
        WinMaximize, % "ahk_id " instance.hwnd
        WinActivate, % "ahk_id " instance.hwnd
        Sleep, 100
    }

    return true
}

ExitInstances() {
    wasRunning := false

    timer1.mcInstance := ""
    timer1.reset()

    for k, instance in MCInstances {
        if (instance.isResetting == -1) {
            wasRunning := true
            excessInstances := MCInstances.count() > numInstances
            if excessInstances {
                WinClose, % "ahk_id " instance.hwnd
                MCInstances.RemoveAt(k, 1)
            } else {
                WinRestore, % "ahk_id " instance.hwnd
                Sleep, 100
                instance.isResetting := 0
                threadsMask := (2 ** Ceil(threadCount * threadsUsage)) - 1
                SetAffinity(instance.pid, threadsMask)
            }
        }
    }

    return wasRunning
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
        DllCall("reset\GetCurrentClick", "UPtr", instance.hwnd, "Int*", returnedCode, "Int*", clickX, "Int*", clickY)

        switch returnedCode {
            case -1: return
            case 0: currentScreen := "Heart"
            case 1: currentScreen := "SaveAndQuit"
            case 2: currentScreen := "CreateNew"
            case 3: currentScreen := "CreateNewWorld"
            case 4: currentScreen := "WorldCreation"
            case 5: currentScreen := "Play"
        }
        if (currentScreen == "SaveAndQuit" && instance.isResetting == 6) { ; if it skips checking coords
            currentScreen := "Heart"
            Send, {Esc}
            Sleep, 100
        }
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

    if readScreenMemory {

        startTick := A_TickCount
        while !valueUI := ReadMemoryValue(instance.proc, "Int", offsetsScreen*) {
            if (A_TickCount-startTick > 3000) {
                MsgBox, % "failed to get current screen from memory: " valueUI
                LogF("WAR", "Timed Out: Failed to get current screen from memory")
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

    if (currentScreen == "SaveAndQuit" && instance.isResetting == 6) { ; if it skips checking coords
        currentScreen := "Heart"
        Send, {Esc}
        Sleep, 100
    }

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
