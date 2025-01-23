Class _Overlay {
    __New() {
        static init := new _Overlay()
        if init
            return
        classPath := StrSplit(this.base.__Class, ".")
        className := classPath.removeAt(1)
        if (classPath.length() > 0)
            %className%[classPath*] := this
        else
            %className% := this

        Gui, Overlay:+AlwaysOnTop -Border -Caption +LastFound +ToolWindow +E0x80000
        this.show()

        Gui, Overlay:+HwndOverlayHwnd
        this.hwnd := OverlayHwnd
        this.pToken := Gdip_Startup()
        this.hdc := CreateCompatibleDC()
        this.hbm := CreateDIBSection(A_ScreenWidth, A_ScreenHeight)
        this.obm := SelectObject(this.hdc, this.hbm)
        this.G := Gdip_GraphicsFromHDC(this.hdc)
        this.brush := {clear: Gdip_BrushCreateSolid(0x00000000), white: Gdip_BrushCreateSolid(0xFFFFFFFF)}
        this.hFormat := Gdip_StringFormatCreate(0x4000)
        this.fallbackFont := "Arial"
        this.hFallbackFamily := this.fetchFont(this.fallbackFont, 0).hFamily
        Gdip_SetSmoothingMode(this.G, 4)
        Gdip_SetTextRenderingHint(this.G, 4)
    }

    __Delete() {
        DeleteDC(this.hdc)
        DeleteObject(this.obm)
        for k, brush in this.brush
            Gdip_DeleteBrush(brush)
        this.flushCache()
        Gdip_DeleteStringFormat(this.hFormat)
        Gdip_DeleteGraphics(this.G)
        Gdip_Shutdown(this.pToken)

        Gui, Overlay:Destroy
    }

    show() {
        Gui, Overlay:Show, NA
        this.isShown := true
    }

    hide() {
        Gui, Overlay:Hide
        this.isShown := false
    }

    measureText(text, font, size) {
        CreateRectF(RectF, 0, 0, A_ScreenWidth, A_ScreenHeight)
        c := this.fetchFont(font, size)
        textSize := StrSplit(Gdip_MeasureString(this.G, text, c.hFont, this.hFormat, RectF), "|")

        return {width: textSize[3], height: textSize[4]}
    }

    getTextPosition(text, font, size, oWidth, anchor, x1, y1, x2, y2, offsetX:=0, offsetY:=0) {
        textSize := this.measureText(text, font, size)
        ; these are approximate values based on the Mojangles font
        padding := {top: size/5, left: size/4.7, right: size/4.3, bottom: size/3.1}

        switch (anchor)
        {
            case "TopLeft":
                anchorX := x1 + offsetX + oWidth/2 - padding.left
                anchorY := y1 + offsetY + oWidth/2 - padding.top
            case "TopRight":
                anchorX := x2 - offsetX - oWidth/2 + padding.right  - textSize.width
                anchorY := y1 + offsetY + oWidth/2 - padding.top
            case "BottomLeft":
                anchorX := x1 + offsetX + oWidth/2 - padding.left
                anchorY := y2 - offsetY - oWidth/2 + padding.bottom - textSize.height
            case "BottomRight":
                anchorX := x2 - offsetX - oWidth/2 + padding.right  - textSize.width
                anchorY := y2 - offsetY - oWidth/2 + padding.bottom - textSize.height
        }
        return {x1: anchorX, y1: anchorY, x2: anchorX+textSize.width, y2: anchorY+textSize.height
              , width: textSize.width, height: textSize.height}
    }

    drawText(text, anchor, offsetX, offsetY, brush, oWidth, oColour, font, size, moreOptions:="") {
        if this.fetchFont(font,size).fallback
            font := this.fallbackFont
        pos := this.getTextPosition(text, font, size, oWidth, anchor, 0, 0, A_ScreenWidth, workArea[2], offsetX, offsetY)

        alignment := (anchor == "BottomRight" || anchor == "TopRight") ? "Right" : "Left"
        options := "x" pos.x1 " y" pos.y1 " w" Ceil(pos.width) " h100p c" brush " ow" oWidth " oc" oColour " s" size " r4 " alignment " " moreOptions
        Gdip_TextToGraphics(this.G, text, options, font, A_ScreenWidth, workArea[2])
    }

    static cache := {hFamily: {}, hFont: {}}

    fetchFont(font, size) {
        if (this.cache["hFont"].count() > 100)
            this.flushCache()

        if this.cache["hFamily"].HasKey(font)
            hFamily := this.cache["hFamily"][font]
        else if (!hFamily := Gdip_FontFamilyCreate(font)) {
            if font
                LogF("WAR", "Failed to create font family """ font """, using fallback font; gdipLastError: " gdipLastError, A_ThisFunc ":FontFamilyFail:" font)
            fallback := true
            font := this.fallbackFont
            hFamily := this.hFallbackFamily
        } else
            this.cache["hFamily"][font] := hFamily

        key := font "|" size
        if this.cache["hFont"].HasKey(key)
            hFont := this.cache["hFont"][key]
        else {
            hFont := Gdip_FontCreate(hFamily, size)
            this.cache["hFont"][key] := hFont
        }

        return {hFamily: hFamily, hFont: hFont, fallback: fallback}
    }

    flushCache() {
        for k, v in this.cache["hFamily"]
            Gdip_DeleteFontFamily(v)
        this.cache["hFamily"] := {}

        for k, v in this.cache["hFont"]
            Gdip_DeleteFont(v)
        this.cache["hFont"] := {}
    }
}

UpdateOverlay() {
    Gdip_GraphicsClear(_Overlay.G)

    visibility := IsOverlayVisible()

    if (visibility[timerVisibility])
        TimerOverlay.draw()

    if (visibility[attemptsVisibility])
        AttemptsOverlay.draw()

    if (visibility[cumulativeVisibility] && resetMode == "cumulative")
        CumulativeOverlay.draw()

    UpdateLayeredWindow(_Overlay.hwnd, _Overlay.hdc, 0, 0, A_ScreenWidth, A_ScreenHeight)
}

UpdateOverlayInterval(interval) {
    static lastUpdateTick := 0
    if (lastUpdateTick+interval > A_TickCount)
        return
    UpdateOverlay()
    lastUpdateTick := A_TickCount
}

IsOverlayVisible(mode:="") {
    switch mode {
        case "none": return false
        case "running": return timer1.mcInstance && WinActive("Minecraft")
        case "minecraft": return WinActive("Minecraft")
        case "resetting": return IsResettingInstances()
        case "always", "preview": return true
    }

    winActive := WinActive("Minecraft")
    isResetting := IsResettingInstances()

    running := timer1.mcInstance && winActive
    minecraft := winActive
    resetting := isResetting

    return {None: false, Running: running, Minecraft: minecraft, Resetting: resetting, Preview: true, Always: true}
}

Class TimerOverlay {
    static lastUpdateTick := 0

    update() {
        if !timer1.isShown
            timer1.show()

        if (timer1.mcInstance == -1)
            return this.lastUpdateTick := A_TickCount

        if (timerVisibility == "preview") {
            if !timer1.tickFunction {
                timer1.reset()
                timer1.start()
            }
            return this.lastUpdateTick := A_TickCount
        }

        instance := timer1.mcInstance
        if !WinExist("ahk_id " instance.hwnd)
            timer1.mcInstance := ""

        if (!instance && timer1.elapsedTick) {
            timer1.reset()
        } else if (instance.isResetting == -1 && !timer1.startTick && !timer1.waitingForMovement && !IsResettingInstances()) {
            WaitForMovement := Func("WaitForMovement").Bind(instance)
            SetTimer, %WaitForMovement%, -0
        }

        this.lastUpdateTick := A_TickCount
    }

    draw() {
        if (this.lastUpdateTick+500 < A_TickCount)
            this.update()

        timer1.draw()
    }
}

Class CumulativeOverlay {
    static lastUpdateTick := 0

    updateText() {
        this.text := queuedInstances.count() "/" queueLimit "`n"

        if IsResettingInstances() {
            memory := GlobalMemoryStatusEx()
            usedGB := Format("{1:.1f}", (memory.TotalPhys-memory.AvailPhys)/1000000000)
            totalGB := Format("{1:.1f}", memory.TotalPhys/1000000000)
            physicalMemoryOut := usedGB "/" totalGB "GB (" memory.MemoryLoad "%)"

            usedCommitedGB := Format("{1:.1f}", (memory.TotalPageFile-memory.AvailPageFile)/1000000000)
            totalCommitedGB := Format("{1:.1f}", memory.TotalPageFile/1000000000)
            percentCommitedUsed := Format("{1:.0f}", usedCommitedGB*100//totalCommitedGB)
            committedMemoryOut := usedCommitedGB "/" totalCommitedGB "GB (" percentCommitedUsed "%)"

            this.text .= physicalMemoryOut "`n" committedMemoryOut
        }

        this.lastUpdateTick := A_TickCount
    }

    draw() {
        if (this.lastUpdateTick+500 < A_TickCount)
            this.updateText()

        _Overlay.drawText(this.text
                        , cumulativeAnchor, cumulativeOffset.x, cumulativeOffset.y, _Overlay.brush.white, 5*overlayScale, "FF000000", timer1.font, 30*overlayScale
                        , "")
    }
}

Class AttemptsOverlay {
    static lastUpdateTick, startedAttempts := UpdateResetAttempts(0)

    updateText() {
        currentAttempts := UpdateResetAttempts(0)
        sessionAttemptsOut := "Session: " currentAttempts - this.startedAttempts
        totalAttemptsOut := "Total: " currentAttempts
        this.text := sessionAttemptsOut "`n" totalAttemptsOut

        this.lastUpdateTick := A_TickCount
    }

    draw() {
        if (this.lastUpdateTick+1000 < A_TickCount)
            this.updateText()

        _Overlay.drawText(this.text
                        , attemptsAnchor, attemptsOffset.x, attemptsOffset.y, _Overlay.brush.white, 5*overlayScale, "FF000000", timer1.font, 30*overlayScale
                        , "")
    }
}
