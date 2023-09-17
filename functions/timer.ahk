global timerActive
     , timerAnchor
     , timerOffsetX
     , timerOffsetY
     , timerFont
     , timerSize
     , timerColour
     , timerDecimalPlaces
     , timerRefreshRate
     , timerAutoSplit

Class Timer
{
    __New()
    {
        this.timeDisplayed := "0:00.000"

        global textTimer
        Gui, Timer:Font, % "s"timerSize " c"timerColour " q4", % timerFont
        Gui, Timer:Add, Text, x0 y0 w%A_ScreenWidth% vtextTimer, % this.timeDisplayed
        Gui, Timer:+AlwaysOnTop -Border -Caption +LastFound +ToolWindow
        Gui, Timer:Color, 000001
        WinSet, TransColor, 000001
        Gui, Timer:Show, % "x0 y0 w" A_ScreenWidth " h" A_ScreenHeight
        Gui, Timer:Hide

        this.reset()
        this.updateFunction := this.UpdateTimer.bind(this)
        FuncUpdateTimer := this.updateFunction
        SetTimer, %FuncUpdateTimer%, 500
    }

    __Delete()
    {
        Gui, Timer:Destroy
    }

    UpdateTimer()
    {
        this.currentInstance := this.FindCurrentInstance()

        if (!this.isShown && this.currentInstance){
            Gui, Timer:Maximize
            this.isShown := true
            this.reset()
            this.WaitForMovement(MCInstances[this.currentInstance])
        } else if (this.isShown && !this.currentInstance){
            Gui, Timer:Hide
            this.isShown := false
            this.reset()
        }
    }

    FindCurrentInstance()
    {
        for k, instance in MCInstances
            if (instance.isResetting == -1)
                return k

        if (MCInstances[this.currentInstance].isResetting != -1)
            return 0
    }

    WaitForMovement(instance)
    {
        if (waiting || this.tickFunction)
            return

        waiting := true
        xCoord := ReadMemoryValue(instance.proc, "Float", offsetsX*)

        while (waiting && this.currentInstance)
        {
            newCoord := ReadMemoryValue(instance.proc, "Float", offsetsX*)
            hasInputted := (GetKeyState("W") || GetKeyState("A") || GetKeyState("S") || GetKeyState("D") || GetKeyState("Space")) && WinActive("Minecraft")
            if (xCoord != newCoord || hasInputted)
            {
                this.start()
                return waiting := false
            }
        }
    }

    reset()
    {
        if this.tickFunction
            this.stop()
        Sleep, 1
        this.startTick := 0
        this.elapsedTick := 0
        Gui, Timer:Default
        GuiControl,, textTimer, % this.FormatTime(0)
    }

    start()
    {
        this.startTick := A_TickCount

        if this.tickFunction
            return
        this.tickFunction := this.tick.bind(this)
        tickFunction := this.tickFunction
        SetTimer, % tickFunction, % timerRefreshRate
    }

    stop()
    {
        if !this.tickFunction
            return 1
        tickFunction := this.tickFunction
        SetTimer, % tickFunction, Off

        this.tickFunction:=""
    }

    tick()
    {
        if timerAutoSplit
            this.checkAutoSplit()
        this.elapsedTick := A_TickCount-this.startTick
        GuiControl, Timer:, textTimer, % this.FormatTime(this.elapsedTick)
    }

    FormatTime(ms)
    {
        milliseconds := Mod(ms,1000)
        seconds := Mod(ms//1000,60)
        minutes := ms//60000

        if (milliseconds == 0)
            milliseconds := "000"
        else if (milliseconds < 10)
            milliseconds := "00" . milliseconds
        else if (milliseconds < 100)
            milliseconds := "0" . milliseconds
        
        milliseconds := SubStr(milliseconds, 1, timerDecimalPlaces)
        if StrLen(milliseconds)
            milliseconds := "." milliseconds
        
        if seconds < 10
            seconds := "0" . seconds

        return this.timeDisplayed := minutes ":" seconds . milliseconds, this.anchorTo()
    }

    anchorTo()
    {
        win := GetWindowDimensions("ahk_id " MCInstances[this.currentInstance].hwnd)

        textSize := this.getTextSize()
        switch (timerAnchor)
        {
            case "TopLeft":
                anchorX := win.x1+timerOffsetX
                anchorY := win.y1+timerOffsetY
            case "TopRight": 
                anchorX := win.x2-textSize.W-timerOffsetX
                anchorY := win.y1+timerOffsetY
            case "BottomLeft":
                anchorX := win.x1+timerOffsetX
                anchorY := win.y2-textSize.H-timerOffsetY
            case "BottomRight":
                anchorX := win.x2-textSize.W-timerOffsetX
                anchorY := win.y2-textSize.H-timerOffsetY
        }

        GuiControl, Timer:Move, textTimer, % "x" . anchorX " y" . anchorY
    }

    checkAutoSplit()
    {
        baseOffset := ""
        if (MCversion == "1.16.10.2")
            baseOffset := 0x036AB670
        else if (MCversion == "1.16.1.2")
            baseOffset := 0x036A4B00

        instanceProc := MCInstances[this.currentInstance].proc
        if (baseOffset && instanceProc.read(instanceProc.baseAddress + baseOffset, "Char", 0x28, 0x198, 0x10, 0x150, 0x798) == 2)
            this.stop()
    }

    getTextSize(){
        ; GuiControlGet textSize, Timer:Pos, textTimer
        Gui, textSizeGUI:Font, % "s"timerSize, % timerFont
        Gui, textSizeGUI:Add, Text,, % this.timeDisplayed
        GuiControlGet textSize, textSizeGUI:Pos, Static1
        Gui, textSizeGUI:Destroy

        return {W: textSizeW, H:textSizeH}
    }
}