#NoEnv
#NoTrayIcon
#Include, %A_ScriptDir%
#Include, gdip.ahk
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

global isShown := false
global game := new Game()
global pendingClicks := []

class Game {
    __New() {
        Gui, game:+AlwaysOnTop -Border -Caption +ToolWindow +E0x80000 +Hwndhwnd

        this.hwnd := hwnd
        this.pToken := Gdip_Startup()
        this.hdc := CreateCompatibleDC()
        this.hbm := CreateDIBSection(A_ScreenWidth, A_ScreenHeight)
        this.obm := SelectObject(this.hdc, this.hbm)
        this.G := Gdip_GraphicsFromHDC(this.hdc)
        this.brush := {clear: Gdip_BrushCreateSolid(0x00000000), black: Gdip_BrushCreateSolid(0xFF000000)
                    , black50: Gdip_BrushCreateSolid(0x77000000), white: Gdip_BrushCreateSolid(0xFFFFFFFF)
                    , green: Gdip_BrushCreateSolid(0xFF00FF00)}

        this.resetConfigs()

        this.state := "idle"
        this.player := {x:150,y:A_ScreenHeight/2,vy:0}
        this.pipes := []
        this.pipesGenerated := 0
        this.generatePipes := false
        this.round := 0
        this.deaths := 0
        this.highScore := 0
        this.lastScore := 0
        this.score := 0
        this.fpsCount := 0, this.fps := 0, this.lastFpsUpdate := 0
    }

    __Delete() {
        DeleteDC(this.hdc)
        DeleteObject(this.obm)
        for k, brush in this.brush
            Gdip_DeleteBrush(brush)
        Gdip_DeleteGraphics(this.G)
        Gdip_Shutdown(this.pToken)
        
        Gui, game:Destroy
    }

    GameLoop() {
        Gui, game:Show, NA
        while (isShown) {
            this.Tick()
        }
        if (this.state == "run")
            this.state := "pause"
        Gui, game:Hide
    }

    Tick() {
        startTick := QPC()
        Gdip_GraphicsClear(this.G)
    
        switch (this.state) {
            case "idle": this.idleTick()
            case "pause": this.pauseTick()
            case "hide": this.hideTick()
            case "run": this.runTick()
        }

        if (pendingClicks.count()) {
            Gdip_SetCompositingMode(this.G, 1)
            for k, click in pendingClicks {
                if (click.expire > A_TickCount)
                    Gdip_FillRectangle(this.G, this.brush.clear, click.x-3, click.y-3, 6, 6)
                else
                    pendingClicks.RemoveAt(k)
            }
            Gdip_SetCompositingMode(this.G, 0)
        }
    
        this.fpsCount++
        currentTick := QPC()
        if (currentTick > this.lastFpsUpdate)
            this.fps := this.fpsCount, this.fpsCount := 0, this.lastFpsUpdate := currentTick+1000
        Gdip_TextToGraphics(this.G, "FPS: " this.fps, "s30 x0 y0 cFFFFFFFF", "Arial", 200, 50)
    
        UpdateLayeredWindow(this.hwnd, this.hdc, 0, 0, A_ScreenWidth, A_ScreenHeight)
        interval := 1000/this.FRAMES_PER_SECOND+startTick
        while (QPC() < interval) {
        }
    }

    idleTick() {
        if GetKeyState("RAlt", "P")
            this.state := "run"
        if GetKeyState("LAlt", "P")
            this.state := "hide"

        Gdip_FillRectangle(this.G, this.brush.black, this.player.x, this.player.y, 50, 50)
        Gdip_FillRectangle(this.G, this.brush.white, this.player.x+5, this.player.y+5, 40, 40)

        Gdip_TextToGraphics(this.G, "Press/Hold RAlt to fly", "s40 x20 y" this.player.y+75 " cFFFFFFFF", "Arial", 500, 300)
        Gdip_TextToGraphics(this.G, "Press LAlt if you're not bored", "s40 x20 y" this.player.y+125 " cFFFFFFFF", "Arial", 600, 300)

        Gdip_FillRectangle(this.G, this.brush.black50, 0, 45, 380, 185)
        Gdip_TextToGraphics(this.G, "Score: " this.lastScore "`nHigh Score: " this.highScore "`nDeaths: " this.deaths, "s50 x0 y50 cFFFFFFFF", "Arial", 400, 300)
        UpdateLayeredWindow(this.hwnd, this.hdc, 0, 0, A_ScreenWidth, A_ScreenHeight)
    }

    pauseTick() {
        if GetKeyState("RAlt", "P")
            this.state := "run"

        Gdip_FillRectangle(this.G, this.brush.black, this.player.x, this.player.y, 50, 50)
        Gdip_FillRectangle(this.G, this.brush.white, this.player.x+5, this.player.y+5, 40, 40)

        for k, pipe in this.pipes {
            if (pipe.x-this.PIPE_SPEED*this.FRAMES_PER_SECOND*1 < this.player.x+50)
                this.pipes.RemoveAt(k), continue

            Gdip_FillRectangle(this.G, this.brush.green, pipe.x, 0, pipe.w, pipe.y)
            Gdip_FillRectangle(this.G, this.brush.green, pipe.x, pipe.y+pipe.spacing, pipe.w, A_ScreenHeight-pipe.y+pipe.spacing)
        }

        Gdip_TextToGraphics(this.G, "Press RAlt to resume", "s40 x20 y" this.player.y+75 " cFFFFFFFF", "Arial", 400, 300)
        UpdateLayeredWindow(this.hwnd, this.hdc, 0, 0, A_ScreenWidth, A_ScreenHeight)
    }

    hideTick() {
        if GetKeyState("RAlt", "P")
            this.state := "idle"

        if (!this.firstHide)
            this.firstHide := A_TickCount+1500

        if (this.firstHide > A_TickCount)
            Gdip_TextToGraphics(this.G, "Press RAlt to reshow", "s40 x20 y" this.player.y+75 " cFFFFFFFF", "Arial", 600, 300)
    }

    runTick() {
        if GetKeyState("RAlt", "P")
            this.player.vy := -20
    
        this.player.y += this.player.vy
        if (this.player.vy < 40)
            this.player.vy += this.GRAVITY
        if (this.player.y+50 < 0)
            this.player.y := A_ScreenHeight-50
        else if (this.player.y > A_ScreenHeight)
            this.player.y := 0
        Gdip_FillRectangle(this.G, this.brush.black, this.player.x, this.player.y, 50, 50)
        Gdip_FillRectangle(this.G, this.brush.white, this.player.x+5, this.player.y+5, 40, 40)


        if (!this.generatePipes && !this.pipes.count()) {
            this.generatePipes := true
            this.round++

            minLevel := 999
            maxLevel := 0
            numLevels := this.DIFFICULTY_LEVELS.count()
            buffs := {PIPE_SPACING:0, PIPE_SPEED:0, BETWEEN_PIPES:0}
            for buff, currentDifficultyLevel in buffs {
                currentValue := this[buff]

                prevDifficultyValue := 0
                currentDifficultyValue := 0
                for l, buffLevel in this.DIFFICULTY_LEVELS {
                    currentDifficultyValue := buffLevel[buff]
                    if (!prevDifficultyValue) {
                        prevDifficultyValue := currentDifficultyValue
                        continue
                    }

                    min := max := 0
                    if (prevDifficultyValue < currentDifficultyValue)
                        min := prevDifficultyValue, max := currentDifficultyValue
                    else
                        min := currentDifficultyValue, max := prevDifficultyValue

                    if (currentValue >= min && currentValue <= max) {
                        if (minLevel > l-1)
                            minLevel := l-1
                        else if (maxLevel < l-1)
                            maxLevel := l-1

                        buffs[buff] := l-1
                        break
                    }
                }

                ; checks if its above all levels
                dif := currentDifficultyValue-prevDifficultyValue
                if (dif > 0)
                    dif := currentDifficultyValue <= currentValue
                else
                    dif := currentDifficultyValue >= currentValue
                if (!buffs[buff] && !dif)
                    minLevel := 0
            }
            needsBuffing := []
            if (minLevel != numLevels)
                for buff, level in buffs
                    if (level == minLevel)
                        needsBuffing.push(buff)

            Random, randomBuffIndex, 1, needsBuffing.count()
            randomBuff := needsBuffing[randomBuffIndex]
            differenceLevelToLevel := this.DIFFICULTY_LEVELS[minLevel+1][randomBuff]-this.DIFFICULTY_LEVELS[minLevel][randomBuff]
            differenceToLevel := this.DIFFICULTY_LEVELS[minLevel+1][randomBuff]-this[randomBuff]
            Random, modifier, 4, 8
            modifiedValue := Ceil(differenceLevelToLevel*0.4+differenceToLevel*modifier/10)

            this.buff := ""
            switch (randomBuff) {
                case "PIPE_SPACING":
                    this.buff := "Passage spacing: " this.PIPE_SPACING " => " this.PIPE_SPACING += modifiedValue
                case "PIPE_SPEED":
                    this.buff := "Speed: " this.PIPE_SPEED " => " this.PIPE_SPEED += modifiedValue
                case "BETWEEN_PIPES":
                    this.buff := "Pipes spacing: " this.BETWEEN_PIPES " => " this.BETWEEN_PIPES += modifiedValue
            }
            levelCats := ["Easy", "Medium", "Hard", "Pro", "Death"]
            this.currentDifficulty := levelCats[minLevel]
        }

        if (this.pipes.count() == this.PIPES_PER_ROUND) {
            roundTextX := -A_ScreenWidth/2-this.BETWEEN_PIPES+this.pipes[1].x
            Gdip_TextToGraphics(this.G, this.round, "x" roundTextX " s50 cFFFFFFFF Centre vCentre", "Arial", A_ScreenWidth, A_ScreenHeight)
        }

        while ((count := this.pipes.count()) < 10 && this.generatePipes) {
            Random, height, 1, A_ScreenHeight-this.PIPE_SPACING
            if (count)
                this.pipes.push({x:this.pipes[count].x+this.pipes[count].w+this.BETWEEN_PIPES, y:height, w:this.PIPE_WIDTH, spacing:this.PIPE_SPACING})
            else
                this.pipes.push({x:A_ScreenWidth, y:height, w:this.PIPE_WIDTH, spacing:this.PIPE_SPACING})
            this.pipesGenerated++

            if (!Mod(this.pipesGenerated, this.PIPES_PER_ROUND)) {
                this.generatePipes := false
            }
        }

        for k, pipe in this.pipes {
            pipe.x -= this.PIPE_SPEED
            if (pipe.x < -pipe.w) {
                this.pipes.RemoveAt(k)
                continue
            }
            Gdip_FillRectangle(this.G, this.brush.green, pipe.x, 0, pipe.w, pipe.y)
            Gdip_FillRectangle(this.G, this.brush.green, pipe.x, pipe.y+pipe.spacing, pipe.w, A_ScreenHeight-pipe.y+pipe.spacing)
    
            if (pipe.x < this.player.x+50 && pipe.x+pipe.w > this.player.x) {
                if (pipe.y < this.player.y && pipe.y+pipe.spacing > this.player.y+50) {
    
                } else {
                    this.deaths++
                    if (this.highScore < this.score)
                        this.highScore := this.score
                    this.lastScore := this.score
                    this.score := 0
                    this.round := 0
                    this.player.y := A_ScreenHeight/2
                    this.player.vy := 0
                    this.pipes := []
                    this.state := "idle"
                    this.resetConfigs()
                }
            } else if (pipe.x < this.player.x && !pipe.passed) {
                pipe.passed := true
                this.score++
            }
        }

        if (this.buff)
            Gdip_TextToGraphics(this.G, this.buff, "s50 cFFFFFFFF Centre vTop", "Arial", A_ScreenWidth, A_ScreenHeight)
        Gdip_TextToGraphics(this.G, this.currentDifficulty, "y50 s50 cFFFFFFFF Centre", "Arial", A_ScreenWidth, A_ScreenHeight)
    }

    resetConfigs() {
        this.FRAMES_PER_SECOND := 60
        this.PIPES_PER_ROUND := 5
        this.BETWEEN_PIPES := 700
        this.PIPE_SPACING := 260
        this.PIPE_WIDTH := 100
        this.PIPE_SPEED := 14
        this.GRAVITY := 2

        this.DIFFICULTY_LEVELS := [{PIPE_SPACING: 260, PIPE_SPEED: 14, BETWEEN_PIPES: 700}
                                , {PIPE_SPACING: 240, PIPE_SPEED: 17, BETWEEN_PIPES: 800}
                                , {PIPE_SPACING: 210, PIPE_SPEED: 20, BETWEEN_PIPES: 960}
                                , {PIPE_SPACING: 190, PIPE_SPEED: 23, BETWEEN_PIPES: 1100}
                                , {PIPE_SPACING: 170, PIPE_SPEED: 26, BETWEEN_PIPES: 1220}
                                , {PIPE_SPACING: 140, PIPE_SPEED: 30, BETWEEN_PIPES: 1350}]
                                
        for config, value in this.DIFFICULTY_LEVELS[1]
            this[config] := value
    }
}

Show() {
    if isShown
        return
    isShown := true
    func := game.GameLoop.bind(game)
    SetTimer, %func%, -0
}

Hide() {
    isShown := false
}

AllowClick(click, expire := 300) {
    Gdip_SetCompositingMode(game.G, 1)
    Gdip_FillRectangle(game.G, game.brush["clear"], click.x-3, click.y-3, 6, 6)
    UpdateLayeredWindow(game.hwnd, game.hdc, 0, 0, A_ScreenWidth, A_ScreenHeight)
    Gdip_SetCompositingMode(game.G, 0)
    if expire
        pendingClicks.push({x: click.x, y: click.y, expire: A_TickCount+expire})
    return
}

QPC() {
    static freq, init := DllCall("QueryPerformanceFrequency", "Int64P", freq)
    
    DllCall("QueryPerformanceCounter", "Int64*", count)
    return (count / freq)*1000
}