#Include, functions/gdip.ahk

Class Timer
{
    static tInstances := 0 

    __New(Settings*) {
        this.tInstance := Timer.tInstances++

        tGui := "t" this.tInstance 
        Gui, %tGui%:+AlwaysOnTop -Border -Caption +LastFound +ToolWindow +E0x80000
        this.hide()

        Gui, %tGui%:+HwndTimerHwnd
        this.hwnd := TimerHwnd
        this.pToken := Gdip_Startup()
        this.hdc := CreateCompatibleDC()
        this.hbm := CreateDIBSection(A_ScreenWidth, A_ScreenHeight)
        this.obm := SelectObject(this.hdc, this.hbm)
        this.G := Gdip_GraphicsFromHDC(this.hdc)
        Gdip_SetSmoothingMode(this.G, 4)
        Gdip_SetTextRenderingHint(this.G, 4)

        this.setSettings(settings*)
        this.reset()
    }

    __Delete() {
        DeleteDC(this.hdc)
        DeleteObject(this.obm)
        Gdip_DeleteFont(this.hFont)
        Gdip_DeleteStringFormat(this.hFormat)
        Gdip_DeleteBrush(this.pBrush)
        Gdip_DeleteGraphics(this.G)
        Gdip_Shutdown(this.pToken)
        
        tGui := "t" this.tInstance 
        Gui, %tGui%:Destroy
    }

    show() {
        tGui := "t" this.tInstance
        Gui, %tGui%:Show, NA
        this.isShown := true
    }

    hide() {
        tGui := "t" this.tInstance
        Gui, %tGui%:Hide
        this.isShown := false
    }

    reset() {
        if this.tickFunction
            this.stop()
        Sleep, 1
        this.startTick := 0
        this.elapsedTick := 0

        this.UpdateTimerText(this.FormatTime(0))
    }

    start() {
        this.startTick := this.QPC()

        if this.tickFunction
            return
        this.tickFunction := this.Tick.bind(this)
        tickFunction := this.tickFunction
        SetTimer, % tickFunction, % this.refreshRate
    }

    stop() {
        if !this.tickFunction
            return 1
        tickFunction := this.tickFunction
        SetTimer, % tickFunction, off

        this.tickFunction:=""
    }

    Tick() {
        if (this.autoSplit == "true")
            this.CheckAutoSplit()

        this.elapsedTick := this.QPC() - this.startTick
        this.UpdateTimerText(this.FormatTime(this.elapsedTick))
    }

    QPC() {
        static freq, init := DllCall("QueryPerformanceFrequency", "Int64P", freq)
        
        DllCall("QueryPerformanceCounter", "Int64*", count)
        return Floor((count / freq)*1000)
    }

    UpdateTimerText(text) {
        CreateRectF(RectF, 0, 0, A_ScreenWidth, A_ScreenHeight)
        textSize := StrSplit(Gdip_MeasureString(this.G, text, this.hFont, this.hFormat, RectF), "|")
        textPosition := this.GetAnchorPosition(textSize[3], textSize[4])
        CreateRectF(RectF, textPosition.x, textPosition.y, textSize[3], textSize[4])

        x1 := textPosition.x
        y1 := textPosition.y
        x2 := textPosition.x + textSize[3]
        y2 := textPosition.y + textSize[4]
        gAngle := this.gradientAngle
        gPan := 0

        if (this.animationSpeed) {
            if (this.animationType == "panoramic") {
                gPan := Mod(A_TickCount/this.animationSpeed, textSize[3]*4)
            } else {
                rotationScaler := A_TickCount/(this.animationSpeed*1000)
                gAngle := 360*rotationScaler
            }
        }

        this.pBrush := Gdip_CreateLinearGrBrush(textPosition.x+gPan, textPosition.y, x2+gPan, y2, this.fontColour1, this.fontColour2)
        Gdip_RotateLinearGrBrushAtCenter(this.pBrush, gAngle)

        Gdip_GraphicsClear(this.G)
        options := "x" textPosition.x " y" textPosition.y " w100p h100p c" this.pBrush " ow" this.outlineWidth " oc" this.outlineColour " s" this.fontSize " r4"
        Gdip_TextToGraphics(this.G, text, options, this.font, A_ScreenWidth, A_ScreenHeight)
        UpdateLayeredWindow(this.hwnd, this.hdc, 0,0, A_ScreenWidth, A_ScreenHeight)
    }

    FormatTime(ms) {
        milliseconds := Mod(ms,1000)
        seconds := Mod(ms // 1000,60)
        minutes := ms // 60000

        if (milliseconds == 0)
            milliseconds := "000"
        else if (milliseconds < 10)
            milliseconds := "00" . milliseconds
        else if (milliseconds < 100)
            milliseconds := "0" . milliseconds
        
        milliseconds := SubStr(milliseconds, 1, this.decimalPlaces)
        if StrLen(milliseconds)
            milliseconds := "." milliseconds
        
        if seconds < 10
            seconds := "0" . seconds

        return this.timeDisplayed := minutes ":" seconds . milliseconds
    }

    GetAnchorPosition(textWidth, textHeight) {
        if (this.currentInstance)
            win := GetWindowDimensions("ahk_id " MCInstances[this.currentInstance].hwnd)
        else
            win := {x1: 0, y1: 0, x2: A_ScreenWidth, y2: A_ScreenHeight}

        switch (this.anchor)
        {
            case "TopLeft":
                anchorX := win.x1 + this.offsetX
                anchorY := win.y1 + this.offsetY
            case "TopRight": 
                anchorX := win.x2 - textWidth - this.offsetX
                anchorY := win.y1 + this.offsetY
            case "BottomLeft":
                anchorX := win.x1 + this.offsetX
                anchorY := win.y2 - textHeight - this.offsetY
            case "BottomRight":
                anchorX := win.x2 - textWidth - this.offsetX
                anchorY := win.y2 - textHeight - this.offsetY
        }
        return {x: anchorX, y: anchorY}
    }

    CheckAutoSplit() {
        baseOffset := ""
        if (MCversion == "1.16.10.2")
            baseOffset := 0x036AB670
        else if (MCversion == "1.16.1.2")
            baseOffset := 0x036A4B00

        instanceProc := MCInstances[this.currentInstance].proc
        if (baseOffset && instanceProc.read(instanceProc.baseAddress + baseOffset, "Char", 0x28, 0x198, 0x10, 0x150, 0x798) == 2)
            this.stop()
    }

    setSettings(anchor, offsetX, offsetY, font, fontSize, fontColour1, fontColour2, gradientAngle, animationType 
                , animationSpeed, outlineWidth, outlineColour, decimalPlaces, refreshRate, autoSplit) {
        Gdip_DeleteFont(this.hFont)
        Gdip_DeleteStringFormat(this.hFormat)
        
        this.anchor := anchor
        this.offsetX := offsetX
        this.offsetY := offsetY
        this.font := font
        this.fontSize := fontSize
        this.fontColour1 := InStr(fontColour1, "0x") ? fontColour1 : "0x" fontColour1
        this.fontColour2 := InStr(fontColour2, "0x") ? fontColour2 : "0x" fontColour2
        this.gradientAngle := gradientAngle
        this.animationType := animationType
        this.animationSpeed := animationSpeed
        this.outlineWidth := outlineWidth
        this.outlineColour := StrReplace(outlineColour, "0x", "")
        this.decimalPlaces := decimalPlaces
        this.refreshRate := refreshRate
        this.autoSplit := autoSplit

        hFamily := Gdip_FontFamilyCreate(this.font)
        this.hFont := Gdip_FontCreate(hFamily, this.fontSize)
        this.hFormat := Gdip_StringFormatCreate(0x4000)

        if !this.tickFunction
            this.reset()
    }
}

global FuncUpdateMainTimer := Func("UpdateMainTimer")
SetTimer, %FuncUpdateMainTimer%, 500

UpdateMainTimer() {
    if (timerActive == "false") {
        if timer1.isShown
            timer1.hide()
        return
    }

    if (!WinExist("ahk_id " MCInstances[timer1.currentInstance].hwnd))
        timer1.currentInstance := 0

    if (timer1.currentInstance && !IsResettingInstances() && !timer1.startTick) {
        timer1.show()
        timer1.reset()
        WaitForMovement := Func("WaitForMovement").Bind(MCInstances[timer1.currentInstance])
        SetTimer, %WaitForMovement%, -0
    }
    
    if (timer1.isShown) {
        if (!timer1.currentInstance) {
            timer1.hide()
            timer1.reset()
        } else if (!WinActive("ahk_id " MCInstances[timer1.currentInstance].hwnd)) {
            timer1.hide()
        }
    } else {
        if (WinActive("ahk_id " MCInstances[timer1.currentInstance].hwnd)) {
            timer1.show()
        }
    }
}

WaitForMovement(instance) {
    static waiting
    if (timer1.tickFunction || waiting)
        return
    waiting := true

    xCoord := ReadMemoryValue(instance.proc, "Float", offsetsX*)

    while (timer1.currentInstance && waiting)
    {
        newCoord := ReadMemoryValue(instance.proc, "Float", offsetsX*)
        hasInputted := (GetKeyState("W") || GetKeyState("A") || GetKeyState("S") || GetKeyState("D") || GetKeyState("Space")) && WinActive("Minecraft")
        if (xCoord != newCoord || hasInputted) {
            timer1.start()
            return waiting := false
        }
    }
}