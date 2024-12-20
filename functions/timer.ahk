#Include, functions/gdip.ahk

Class Timer
{
    __New(Settings*) {
        this.isShown := false

        this.hwnd := _Overlay.hwnd
        this.hdc := _Overlay.hdc
        this.G := _Overlay.G

        this.setSettings(settings*)
        this.reset()
    }

    __Delete() {
        Gdip_DeleteBrush(this.pBrush)
    }

    show() {
        this.isShown := true
    }

    hide() {
        this.isShown := false
    }

    reset() {
        if this.tickFunction
            this.stop()
        this.startTick := 0
        this.elapsedTick := 0
    }

    start() {
        if this.tickFunction
            return

        this.startTick := QPC() - this.elapsedTick

        this.tickFunction := ObjBindMethod(this, "tick")
        tickFunction := this.tickFunction
        SetTimer, % tickFunction, % this.refreshRate
    }

    stop() {
        if !this.tickFunction
            return

        this.elapsedTick := QPC() - this.startTick
        tickFunction := this.tickFunction
        SetTimer, % tickFunction, off
        this.tickFunction := ""
    }

    tick() {
        if this.autoSplit
            this.checkAutoSplit()

        this.elapsedTick := QPC() - this.startTick
    }

    draw() {
        if !this.isShown
            return

        text := this.formatTime(this.elapsedTick)
        win := isObject(this.mcInstance) ? GetWindowDimensions("ahk_id " this.mcInstance.hwnd)
                : WinActive("Minecraft") ? GetWindowDimensions("Minecraft")
                : {x1: 0, y1: 0, x2: A_ScreenWidth, y2: A_ScreenHeight}
        pos := _Overlay.getTextPosition(text, this.font, this.fontSize, this.outlineWidth, this.anchor
              , win.x1, win.y1, win.x2, win.y2, this.offset.x, this.offset.y)
        gAngle := Mod(this.gradientAngle, 360)
        gPan := 0

        if (this.animationLength && this.animationType == "rotatory") {
            rotationScaler := Mod(A_TickCount/this.animationLength, 1000)/1000
            gAngle := 360*rotationScaler
        }

        midX := (pos.x2-this.padding.right  + pos.x1+this.padding.left)/2
        midY := (pos.y2-this.padding.bottom + pos.y1+this.padding.top )/2
        tx := pos.width/2 - this.padding.left
        ty := pos.height  - (this.padding.top + this.padding.bottom)
        m1 := Tan(gAngle*0.01745329252)
        m2 := m1 ? -1/m1 : -1048576

        if (Mod(gAngle//90, 2) == 0)
            gx := (-m2*tx + ty/2) / (m1-m2)
        else
            gx := (-m2*tx - ty/2) / (m1-m2)
        gy := m1 * gx

        if (gAngle < 90 || gAngle >= 270) {
            gx *= -1
            gy *= -1
        }

        if (this.animationLength && this.animationType == "panoramic") {
            gPan := Mod(A_TickCount/this.animationLength, 1000)/1000
            gLength := Sqrt(gx**2 + gy**2)*4
            halfLength := gLength/2
            slopeFactor := Sqrt(1 + m1**2)
            midX += gLength   /slopeFactor*gPan - halfLength
            midY += gLength*m1/slopeFactor*gPan - halfLength
        }

        Gdip_DeleteBrush(this.pBrush)
        this.pBrush := Gdip_CreateLinearGrBrush(midX+gx, midY+gy, midX-gx, midY-gy, this.fontColour1, this.fontColour2)
        options := "x" pos.x1 " y" pos.y1 " w100p h100p c" this.pBrush " ow" this.outlineWidth " oc" this.outlineColour " s" this.fontSize " r4"
        Gdip_TextToGraphics(this.G, text, options, this.font, A_ScreenWidth, A_ScreenHeight)

        if this.remindShowPacksTick > A_TickCount {
            options := "Centre vCentre w100p h100p c" _Overlay.brush.white " ow" this.outlineWidth " ocFF000000 s" this.fontSize " r4"
            Gdip_TextToGraphics(this.G, "show packs", options, this.font, A_ScreenWidth, A_ScreenHeight)
        }
    }

    formatTime(ms) {
        ms := Floor(ms)
        seconds := Mod(ms // 1000, 60)
        minutes := Mod(ms // 60000, 60)
        hours := ms // 3600000

        if this.decimalPlaces {
            milliseconds := Mod(ms, 1000)
            if (milliseconds < 10)
                milliseconds := "00" milliseconds
            else if (milliseconds < 100)
                milliseconds := "0" milliseconds
            milliseconds := "." SubStr(milliseconds, 1, this.decimalPlaces)
        }

        if seconds < 10
            seconds := "0" seconds

        if hours
            minutes := minutes < 10 ? hours ":0" minutes : hours ":" minutes

        return minutes ":" seconds . milliseconds
    }

    checkAutoSplit() {
        if !offsetsAutoSplit
            return

        value := ReadMemoryValue(this.mcInstance.proc, "Char", offsetsAutoSplit*)
        if (value == 2 || value == 3) {
            this.stop()
            if remindShowPacks {
                Sleep, 1000
                this.remindShowPacksTick := A_TickCount+3000
            }
            exit
        }
    }

    setSettings(anchor, offset, font, fontSize, fontColour1, fontColour2, gradientAngle, animationType
                , animationLength, outlineWidth, outlineColour, decimalPlaces, refreshRate, autoSplit) {
        this.anchor := anchor
        this.offset := offset
        this.font := font
        this.fontSize := fontSize
        this.fontColour1 := InStr(fontColour1, "0x") ? fontColour1 : "0x" fontColour1
        this.fontColour2 := InStr(fontColour2, "0x") ? fontColour2 : "0x" fontColour2
        this.gradientAngle := gradientAngle
        this.animationType := animationType
        this.animationLength := animationLength
        this.outlineWidth := outlineWidth
        this.outlineColour := StrReplace(outlineColour, "0x", "")
        this.decimalPlaces := decimalPlaces
        this.refreshRate := refreshRate
        this.autoSplit := autoSplit

        f := _Overlay.fetchFont(this.font, this.fontSize)
        if (f.fallback && this.font) {
            this.font := _Overlay.fallbackFont
            warningColour := "rgba(255,255,0,0.25)"
        }
        setting["map"]["tFont"]["rootDiv"]["style"]["background-color"] := warningColour

        ; these are approximate values based on the Mojangles font
        this.padding := {top: this.fontSize/5, left: this.fontSize/4.7, right: this.fontSize/4.3, bottom: this.fontSize/3.1}

        if !this.tickFunction
            this.reset()
    }
}

WaitForMovement(instance) {
    timer1.reset()
    timer1.show()

    xCoord := ReadMemoryValue(instance.proc, "Float", offsetsX*)

    while (timer1.mcInstance && instance.isResetting == -1) {
        newCoord := ReadMemoryValue(instance.proc, "Float", offsetsX*)
        hasInputted := (GetKeyState("W") || GetKeyState("A") || GetKeyState("S") || GetKeyState("D") || GetKeyState("Space")) && WinActive("Minecraft")
        if ((xCoord != newCoord && newCoord) || hasInputted) {
            timer1.start()
            break
        }
    }
}
