global iniFile := A_ScriptDir "\configs\configs.ini"

global resetKey, stopresetKey, restartKey, starttimerKey, stoptimerKey, resettimerKey
IniRead, resetKey    , %iniFile%, Hotkeys, Reset
IniRead, stopresetKey, %iniFile%, Hotkeys, StopReset
IniRead, restartKey  , %iniFile%, Hotkeys, Restart
IniRead, starttimerKey, %iniFile%, Hotkeys, StartTimer
IniRead, stoptimerKey , %iniFile%, Hotkeys, StopTimer
IniRead, resettimerKey, %iniFile%, Hotkeys, ResetTimer

global timerPreview := new Timer()

global clickData := {}, screenClicks := [], worldcreationClicks := []

; i'll put all these definitions in a separate formatted file some day
global resetMode       , new Setting("resetMode", "Reset Mode", "Macro", 1, "select", ["auto", "cumulative", "setSeed", "manual", "manualWall"], "The type of resetting", [Func("OptResetModeHandler")])
global minCoords       , new Setting("minCoords", "Min Coordinate", "Macro", 1, "inputNumber", 700, "The minimum x-coordinate the macro auto-resets for", [Func("OptResetModeHandler"), "getSpawnChance();"])
global maxCoords       , new Setting("maxCoords", "Max Coordinate", "Macro", 1, "inputNumber", 1800, "The maximum x-coordinate the macro auto-resets for", [Func("OptResetModeHandler"), "getSpawnChance();"])
global originDistance  , new Setting("originDistance", "Distance from 0,0 (1.19.50)", "Macro", 1, "inputNumber", 400, "The minimum number of blocks from world origin", [Func("OptResetModeHandler")])
global queueLimit      , new Setting("queueLimit", "Queue Limit", "Macro", 1, "inputNumber", 100, "Limits the number of queued instances", [Func("OptResetModeHandler")])
global memoryLimit     , new Setting("memoryLimit", "Committed Memory Limit", "Macro", 1, "inputNumber", 40, "Will stop resetting if the total used memory (GB) exceeds the limit", [Func("OptResetModeHandler")])
global resetSeed       , new Setting("resetSeed", "Seed", "Macro", 1, "select", GetSeedsFromFile(), "", [Func("OptResetModeHandler")])
global setSeedMouseMove, new Setting("setSeedMouseMove", "Move Cursor", "Macro", 1, "inputCoords", "0,0", "Moves your cursor to a point (x,y) on your screen. Set to 0,0 to omit.", [Func("OptResetModeHandler")])
global autoRestart     , new Setting("autoRestart", "Auto Restart", "Macro", 2, "checkbox", false, "Automatically restarts instances`nDeprecated: Use 'Block Marketplace' to prevent the buildup of lag.", [Func("AutoRestartHandler")])
global seamlessRestarts, new Setting("seamlessRestarts", "Seamless", "Macro", 2, "checkbox", false, "Opens instances in the background before restarting", [Func("AutoRestartHandler")])
global resetThreshold  , new Setting("resetThreshold", "Reset Threshold", "Macro", 2, "inputNumber", 120, "Number of resets accumulated between instances to initiate an automatic restart", [Func("AutoRestartHandler")])
global numInstances    , new Setting("numInstances", "Number of Instances", "Macro", 3, "inputNumber", 4, "", 0)
global layoutDimensions, new Setting("layoutDimensions", "Layout", "Macro", 3, "inputCoords", "2,2", "The arrangement of instances (x, y)", 0)
global keyDelay        , new Setting("keyDelay", "Key Delay", "Macro", 4, "inputNumber", 50, "The delay between world creation clicks", 0)
global switchDelay     , new Setting("switchDelay", "Switch Delay", "Macro", 4, "inputNumber", 0, "The delay resetting in-between instances", 0)
global clickDuration   , new Setting("clickDuration", "Click Duration", "Macro", 4, "inputNumber", 30, "How long each mouse click is held down for; helps to register clicks", 0)

global timerActive    , new Setting("timerActive", "Timer", "Timer", 1, "checkbox", true, "", [Func("TimerSettingHandler")])
global tAnchor        , new Setting("tAnchor", "Anchor", "Timer", 2, "select", ["TopLeft", "TopRight", "BottomLeft", "BottomRight"], "Where the timer is relatively positioned on the instance", [Func("TimerSettingHandler")])
global tOffset        , new Setting("tOffset", "Offset", "Timer", 2, "inputCoords", "25,25", "Offset from the anchor point", [Func("TimerSettingHandler")])
global tFont          , new Setting("tFont", "Font", "Timer", 3, "inputFont", "Arial", "Any font installed", [Func("TimerSettingHandler")])
global tFontSize      , new Setting("tFontSize", "Size", "Timer", 3, "inputNumber", 50, "", [Func("TimerSettingHandler")])
global tFontColour1   , new Setting("tFontColour1", "Colour 1", "Timer", 3, "inputColour", "0xFFFFFFFF", "Hexadecimal Colour (0xAARRGGBB)", [Func("TimerSettingHandler")])
global tFontColour2   , new Setting("tFontColour2", "Colour 2", "Timer", 3, "inputColour", "0xFF737373", "Hexadecimal Colour (0xAARRGGBB)", [Func("TimerSettingHandler")])
global tOutlineWidth  , new Setting("tOutlineWidth", "Outline Width", "Timer", 3, "inputNumber", 10, "", [Func("TimerSettingHandler")])
global tOutlineColour , new Setting("tOutlineColour", "Outline Colour", "Timer", 3, "inputColour", "0xFF000000", "Hexadecimal Colour (0xAARRGGBB)", [Func("TimerSettingHandler")])
global tGradientAngle , new Setting("tGradientAngle", "Gradient Angle", "Timer", 3, "inputNumber", 60, "", [Func("TimerSettingHandler")])
global tAnimationType , new Setting("tAnimationType", "Animation Type", "Timer", 3, "select", ["rotatory", "panoramic"], "How the timer's colours are animated", [Func("TimerSettingHandler")])
global tAnimationSpeed, new Setting("tAnimationSpeed", "Animation Length", "Timer", 3, "inputNumber", 0, "", [Func("TimerSettingHandler")])
global tDecimalPlaces , new Setting("tDecimalPlaces", "Decimals", "Timer", 3, "select", [0, 1, 2, 3], "", [Func("TimerSettingHandler")])
global tAutoSplit     , new Setting("tAutoSplit", "Auto Split", "Timer", 4, "checkbox", true, "Automatically stops the timer when credits roll", [Func("TimerSettingHandler")])
global remindShowPacks, new Setting("remindShowPacks", "Remind: Show Packs", "Timer", 4, "checkbox", false, "After a completion, you can be reminded of", [Func("TimerSettingHandler")])
global tPreview       , new Setting("tPreview", "Show Preview", "Timer", 4, "checkbox", false, "", [Func("TimerSettingHandler"), Func("TimerPreviewHandler")])

global resetMethod       , new Setting("resetMethod", "Reset Method", "Other", 1, "select", ["setupless", "setup"], "The method the macro uses to figure out where to click", [Func("OptResetMethodHandler")])
global setupData         , new Setting("setupData", "Setup Data", "Other", 1, "select", LoadClickData(), "", [Func("OptResetMethodHandler")])
global coopMode          , new Setting("coopMode", "Coop Mode", "Other", 1, "checkbox", false, "Prevents the 0/8 bug", 0)
global findCoordsTextOnly, new Setting("findCoordsTextOnly", "Read Coordinates Text Only", "Other", 1, "checkbox", false, "Reads the ""Show Coordinates"" text only; does not attempt to read the game memory", 0)
global awaitWcColour     , new Setting("awaitWcColour", "Wait for World Creation Colours", "Other", 1, "checkbox", false, "Waits for the World Creation clicks' colour; useful for allowing the new World Creation UI to load", 0)
global readScreenMemory  , new Setting("readScreenMemory", "Read Screen Memory", "Other", 1, "checkbox", false, "Reads the game memory to get the current screen, relies on setup click data for the clicks [Not Recommended]", 0)
global threadsUsage      , new Setting("threadsUsage", "Threads Utilisation", "Other", 2, "inputNumber", 0.8, "The percentage of CPU threads the instances will utilise during resets", 0)
global hideOnMinimise    , new Setting("hideOnMinimise", "Minimise to Tray", "Other", 3, "checkbox", false, "When the GUI is minimised, the taskbar icon will disappear to the tray", 0)
global isBored           , new Setting("isBored", "are u bored?", "Other", 5, "checkbox", false, "fun lil game to play while resetting", 0)

class Setting {
    static map := {}
    static toInit := []

    __New(id,name,section,subsection,type,default,hint,method) {
        this.id := id
        this.name := name
        this.section := section
        this.subsection := subsection
        this.type := type
        this.default := default
        this.hint := hint
        this.method := method ? method : []

        this.value := this.GetIniValue()
        this.map[this.id] := this
        this.toInit.push(this.id)
    }
    
    Init() {
        this.CreateSetting()
        this.UpdateSettingValue(this.value)
    }

    CreateSetting() {
        this.rootDiv := WB.document.createElement("div")
        this.rootDiv.className := "tab-content__row " this.subsection
        switch this.type {
            case "checkbox":
                this.attributeType := "checked"
                
                div := WB.document.createElement("div")

                checkbox := WB.document.createElement("input")
                checkbox.type := "checkbox"
                checkbox.id := this.id
                checkbox.onchange := ObjBindMethod(this, "EventHandler")
                this.element := checkbox
                
                h3 := WB.document.createElement("h3")
                h3.innerText := this.name
                h3.onclick := Func("RunJS").bind("document.getElementById(""" this.id """).click()")

                div.appendChild(checkbox)
                div.appendChild(h3)
                this.rootDiv.appendChild(div)
            
            case "select":
                this.attributeType := "value"

                div := WB.document.createElement("div")

                h3 := WB.document.createElement("h3")
                h3.innerText := this.name
                
                select := WB.document.createElement("select")
                select.id := this.id
                select.onchange := ObjBindMethod(this, "EventHandler")
                for k, value in this.default {
                    option := WB.document.createElement("option")
                    option.innerText := FormatOptionName(value)
                    option.value := value
                    select.appendChild(option)
                }
                this.element := select
                
                div.appendChild(h3)
                div.appendChild(select)
                this.rootDiv.appendChild(div)

            case "inputNumber", "inputText":
                if (this.type == "inputNumber")
                    this.InputRetriever := ObjBindMethod(this, "InputNumberRetriever")
                this.attributeType := "value"

                div := WB.document.createElement("div")

                h3 := WB.document.createElement("h3")
                h3.innerText := this.name

                input := WB.document.createElement("input")
                input.id := this.id
                input.oninput := ObjBindMethod(this, "EventHandler")
                input.type := "text"
                this.element := input

                div.appendChild(h3)
                div.appendChild(input)
                this.rootDiv.appendChild(div)

            case "inputCoords":
                this.InputRetriever := ObjBindMethod(this, "InputCoordsRetriever")
                this.attributeType := "value"

                div := WB.document.createElement("div")

                h3 := WB.document.createElement("h3")
                h3.innerText := this.name

                inputX := WB.document.createElement("input")
                inputX.id := this.id "x"
                inputX.oninput := ObjBindMethod(this, "EventHandler")
                inputX.type := "text"
                this.elementX := inputX

                inputY := WB.document.createElement("input")
                inputY.id := this.id "y"
                inputY.oninput := ObjBindMethod(this, "EventHandler")
                inputY.type := "text"
                this.elementY := inputY

                div.appendChild(h3)
                div.appendChild(inputX)
                div.appendChild(inputY)
                this.rootDiv.appendChild(div)
            
            case "inputColour":
                this.attributeType := "value"

                div := WB.document.createElement("div")

                h3 := WB.document.createElement("h3")
                h3.innerText := this.name

                input := WB.document.createElement("input")
                input.type := "text"
                input.id := this.id
                input.oninput := ObjBindMethod(this, "EventHandler")
                this.method.InsertAt(1, ObjBindMethod(this, "InputColourHandler"))
                input.style.width := "150px"
                this.element := input

                div.appendChild(h3)
                div.appendChild(input)
                this.rootDiv.appendChild(div)

                div := WB.document.createElement("div")
                div.className := "colour-picker"

                button := WB.document.createElement("button")
                button.id := this.id "-colour-btn"
                button.innerText := Chr(9608) . Chr(9608)
                func1 := Func("RunJS").Bind("var c = document.getElementById('colourDialog').ChooseColorDlg(); document.getElementById('" this.id "').value = decToARGB(c);")
                func2 := ObjBindMethod(this, "EventHandler")
                button.onclick := Func("CoupleFunctions").Bind(func1, func2)
                
                div.appendChild(button)
                this.rootDiv.appendChild(div)

            case "inputFont":
                this.attributeType := "value"

                div := WB.document.createElement("div")
                div.className := "picker"

                h3 := WB.document.createElement("h3")
                h3.innerText := this.name

                input := WB.document.createElement("input")
                input.type := "text"
                input.id := this.id
                input.oninput := ObjBindMethod(this, "EventHandler")
                this.method.InsertAt(1, ObjBindMethod(this, "InputFontHandler"))
                input.style.width := "150px"
                this.element := input

                button := WB.document.createElement("button")
                button.innerText := Chr(9776)
                button.onclick := Func("RunJS").Bind("fontlist = document.getElementById('" this.id "-font-list'); fontlist.style.display = fontlist.style.display == 'none' ? 'block' : 'none';")
                
                div.appendChild(h3)
                div.appendChild(input)
                div.appendChild(button)
                this.rootDiv.appendChild(div)
                
                select := WB.document.createElement("select")
                select.id := this.id "-font-list"
                select.style.display := "none"
                select.style.margin := "5px 0px"
                func1 := Func("RunJS").Bind("document.getElementById('" this.id "').value = document.getElementById('" this.id "-font-list').value.replace(/@/, '');")
                func2 := ObjBindMethod(this, "EventHandler")
                select.onchange := Func("CoupleFunctions").Bind(func1, func2) 

                fonts := GetFontNames(0)
                for k, font in fonts {
                    newOption := WB.document.createElement("option")
                    optionText := WB.document.createTextNode(k)
                    textStyle := newOption.style
                    textStyle["font-family"] := k
                    newOption.appendChild(optionText)
                    select.appendChild(newOption)
                }
                this.rootDiv.appendChild(select)
        }
        if (!this.InputRetriever)
            this.InputRetriever := ObjBindMethod(this, "DefaultInputRetriever")

        if (this.hint) {
            hint := WB.document.createElement("span")
            hint.className := "hint"
            hint.innerText := this.hint
            h3.appendChild(hint)
        }

        this.InsertToSection()
    }

    InsertToSection() {
        section := WB.document.getElementById(this.section)
        
        atSub := 0
        subExist := false
        count := section["children"].length
        Loop, %count% {
            atIndex := A_Index-1
            element := section["children"][atIndex]
            atSub := StrSplit(element.className, A_Space)[2]

            if (!subExist && Floor(atSub) > Floor(this.subsection)) {
                section.insertBefore(this.rootDiv, element)
                hr := WB.document.createElement("hr")
                section.insertBefore(hr, element)
                return
            } else if (Floor(atSub) == Floor(this.subsection))
                subExist := true

            if (subExist && (atSub > this.subsection || !atSub)) {
                section.insertBefore(this.rootDiv, element)
                return
            }
        }
        if !subExist && atSub {
            hr := WB.document.createElement("hr")
            section.appendChild(hr, element)
        }
        section.appendChild(this.rootDiv)
    }

    GetIniValue() {
        IniRead, value, %iniFile%, % this.section, % this.id

        if (this.type == "inputCoords") {
            values := StrSplit(value, ",")
            valid := StrLen(values[1]) && StrLen(values[2])
            if !valid
                value := ""
        }
        if (!value || value == "ERROR") {
            if value is number ; only allow empty strings
                return 0
            if (this.section == "Timer") { ; backwards compatibility, i know this looks bad
                oldID := RegExReplace(this.id, "^.(.)", "$1")
                IniRead, value, %iniFile%, % this.section, % oldID
                if (value != "ERROR") {
                    if (value == "false")
                        value := false
                    IniDelete, %iniFile%, % this.section, % oldID
                    IniWrite, %value%, %iniFile%, % this.section, % this.id
                    return value
                }
            }

            value := this.default.count() ? this.default[1] : this.default
            IniWrite, %value%, %iniFile%, % this.section, % this.id
            LogF("WAR", "Invalid value for """ this.id """. Setting to default: " value)
        } else if (this.type == "checkbox" && value == "false") { ; more backwards compatibility
            value := false
        }

        return value
    }

    UpdateSettingValue(value, invokeEventHandler:=true) {
        if (this.type == "inputCoords") {
            values := StrSplit(value, ",")
            this.elementX["value"] := values[1]
            this.elementY["value"] := values[2]
        } else {
            this.element[this.attributeType] := value ? "" value : 0
        }

        if invokeEventHandler
            this.EventHandler()
    }

    DefaultInputRetriever() {
        return this.element[this.attributeType]
    }

    InputNumberRetriever() {
        input := this.DefaultInputRetriever()
        
        RegExMatch(input, "-?[\d.]+", filteredInput)
        if (input != filteredInput)
            this.UpdateSettingValue(filteredInput, false)

        return filteredInput
    }

    InputCoordsRetriever() {
        inputX := this.elementX["value"]
        inputY := this.elementY["value"]
        RegExMatch(inputX, "-?[\d.]+", filteredInputX)
        RegExMatch(inputY, "-?[\d.]+", filteredInputY)
        filteredInput := filteredInputX "," filteredInputY

        if (inputX != filteredInputX || inputY != filteredInputY)
            this.UpdateSettingValue(filteredInput, false)

        return {string: filteredInput, object: {x: filteredInputX, y: filteredInputY}}
    }

    EventHandler() {
        input := this.InputRetriever.call()
        globalVar := this.id
        
        if IsObject(input) {
            this.value := Trim(input.string)
            (%globalVar%) := input.object
        } else {
            input := Trim(input)
            this.value := input
            (%globalVar%) := input
        }

        IniWrite, % this.value, %iniFile%, % this.section, % this.id

        for k, func in this.method
            IsObject(func) ? func.call() : RunJS(func)
    }

    InputFontHandler() {
        this.element["style"]["font-family"] := this.value
    }
    
    InputColourHandler() {
        WB.document.getElementById(this.id "-colour-btn")["style"]["color"] := this.value & 0x00FFFFFF
    }
}

FormatOptionName(name) {
    name := RegExReplace(name, "(?<=[a-z])(?=[A-Z])", " ")
    StringUpper, name, name, T
    return name
}

RunJS(code) {
    WB.document.parentWindow.execScript(code)
}

CoupleFunctions(functions*) {
    for k, func in functions
        func.call()
}

OptResetModeHandler() {
    switch resetMode {
        case "cumulative":
            Setting["map"]["minCoords"]["rootDiv"]["style"]["display"] := "flex"
            Setting["map"]["maxCoords"]["rootDiv"]["style"]["display"] := "flex"
            Setting["map"]["originDistance"]["rootDiv"]["style"]["display"] := "flex"
            Setting["map"]["queueLimit"]["rootDiv"]["style"]["display"] := "flex"
            Setting["map"]["memoryLimit"]["rootDiv"]["style"]["display"] := "flex"
            Setting["map"]["resetSeed"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["setSeedMouseMove"]["rootDiv"]["style"]["display"] := "none"

        case "auto":
            Setting["map"]["minCoords"]["rootDiv"]["style"]["display"] := "flex"
            Setting["map"]["maxCoords"]["rootDiv"]["style"]["display"] := "flex"
            Setting["map"]["originDistance"]["rootDiv"]["style"]["display"] := "flex"
            Setting["map"]["queueLimit"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["memoryLimit"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["resetSeed"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["setSeedMouseMove"]["rootDiv"]["style"]["display"] := "none"

        case "manual", "manualWall":
            Setting["map"]["minCoords"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["maxCoords"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["originDistance"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["queueLimit"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["memoryLimit"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["resetSeed"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["setSeedMouseMove"]["rootDiv"]["style"]["display"] := "none"

        case "setSeed":
            Setting["map"]["minCoords"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["maxCoords"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["originDistance"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["queueLimit"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["memoryLimit"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["resetSeed"]["rootDiv"]["style"]["display"] := "flex"
            Setting["map"]["setSeedMouseMove"]["rootDiv"]["style"]["display"] := "flex"
    }
}

AutoRestartHandler() {
    display := autoRestart ? "flex" : "none"
    Setting["map"]["seamlessRestarts"]["rootDiv"]["style"]["display"] := display
    Setting["map"]["resetThreshold"]["rootDiv"]["style"]["display"] := display
}

TimerSettingHandler() {
    tRefreshRate := 0
    timerOptions := [tAnchor, tOffset, tFont, tFontSize, tFontColour1, tFontColour2, tGradientAngle
                    , tAnimationType, tAnimationSpeed, tOutlineWidth, tOutlineColour, tDecimalPlaces, tRefreshRate, tAutoSplit]
    if !timer1
        timer1 := new Timer(timerOptions*)
    else
        timer1.setSettings(timerOptions*)
    
    if tPreview {
        timerPreview.setSettings(timerOptions*)
        if (!timerPreview.isShown) {
            timerPreview.show()
            timerPreview.start()
        }
    } else if (!tPreview && timerPreview.isShown) {
        timerPreview.hide()
        timerPreview.reset()
    }
}

TimerPreviewHandler() {
    Setting["map"]["tPreview"]["rootDiv"]["className"] := ""
    Setting["map"]["tPreview"]["rootDiv"]["children"][0]["style"]["display"] := "flex"
    style := Setting["map"]["tPreview"]["rootDiv"]["style"]
    style.position := "absolute"
    style.right := "0px"
    style.bottom := "0px"
}

OptResetMethodHandler() {
    if (resetMethod == "setup")
        Setting["map"]["setupData"]["rootDiv"]["style"]["display"] := "flex"
    else
        Setting["map"]["setupData"]["rootDiv"]["style"]["display"] := "none"

    if setupData {
        if !clickData[setupData]
            return LogF("WAR", "No setup data", A_ThisFunc ":NoSetupData")

        screenClicks := clickData[setupData]["screenClicks"]
        worldcreationClicks := clickData[setupData]["worldcreationClicks"]

        if (clickData[setupData]["metadata"]["clickVersion"] < 3)
            return

        if (clickData[setupData]["metadata"]["dpi"] != A_ScreenDPI) {
            LogF("WAR", "Screen DPI does not match with setup data", A_ThisFunc ":" setupData ":DifferentScreenDPI")
            warningColour := "rgba(255,255,0,0.25)"
        }

        setupWorkArea := clickData[setupData]["metadata"]["workArea"]
        if (setupWorkArea[1] != workArea[1] || setupWorkArea[2] != workArea[2]) {
            LogF("WAR", "Working area does not match with setup data", A_ThisFunc ":" setupData ":DifferentWorkArea")
            warningColour := "rgba(255,255,0,0.25)"
        }
        Setting["map"]["setupData"]["rootDiv"]["style"]["background-color"] := warningColour
    }
}

InitGuiElements() {
    for k, v in Setting["toInit"]
        if (!(s := Setting["map"][v]).HasKey("rootDiv"))
            s.Init()

    Setting["toInit"] := []
}

MergeConfigs(source, destination) {
    newIniFile := destination "\configs.ini"
    IniWrite, %resetKey%     , %newIniFile%, Hotkeys, Reset
    IniWrite, %stopresetKey% , %newIniFile%, Hotkeys, StopReset
    IniWrite, %restartKey%   , %newIniFile%, Hotkeys, Restart
    IniWrite, %starttimerKey%, %newIniFile%, Hotkeys, StartTimer
    IniWrite, %stoptimerKey% , %newIniFile%, Hotkeys, StopTimer
    IniWrite, %resettimerKey%, %newIniFile%, Hotkeys, ResetTimer
    
    for k, v in Setting["map"]
        IniWrite, % v.value, %newIniFile%, % v.section, % v.id

    FileCopy, %source%\attempts.txt, %destination%, 1
    FileCopy, %source%\clicks.txt, %destination%, 1
    FileCopy, %source%\seeds.txt, %destination%, 1
}

GetSeedsFromFile() {
    FileRead, fileData, configs/seeds.txt
    if ErrorLevel {
        LogF("WAR", "Couldn't read file: ""configs/seeds.txt""; A_LastError: " A_LastError ". Using fallback values...")
        return [564030617, 2425564754069582094, -990909152419832232, 1078231915]
    }
    return StrSplit(fileData, ",")
}

LoadClickData() {
    FileRead, clickFileData, configs/clicks.txt
    clicksArray := StrSplit(clickFileData, "`n")

    if !clickFileData
        return ["none"]

    currentV := ""
    for k, line in clicksArray {
        if (SubStr(line, 1, 1) == "#") {
            metadata := StrSplit(line, ",")
            clickVersion := StrReplace(metadata[1], "#")
            if (clickVersion < 3)
                currentV := metadata[2] "x" metadata[3] " (Old Data)"
            else
                currentV := metadata[2] "x" metadata[3] ", " metadata[4]
            clickData[currentV] := {}
            clickData[currentV]["raw"] := []
            clickData[currentV]["metadata"] := {clickVersion: clickVersion
                                              , layoutDimensions: [metadata[2], metadata[3]]
                                              , mcVersion: metadata[4]
                                              , workArea: [metadata[5], metadata[6]]
                                              , dpi: metadata[7]}
            continue
        }

        if currentV
            clickData[currentV]["raw"].push(line)
    }
    for k, clickV in clickData {
        clickV["screenClicks"] := []
        clickV["worldcreationClicks"] := []
        for k, click in clickV["raw"] {
            clickObj := StrSplit(click, ",")
            if !clickObj.count()
                continue
    
            if (clickObj[6])
                clickV["screenClicks"].push({btn:clickObj[1], x:clickObj[2], y:clickObj[3], px:clickObj[4], py:clickObj[5], colour:clickObj[6]})
            else
                clickV["worldcreationClicks"].push({x:clickObj[2], y:clickObj[3], colour:clickObj[4], isSeedClick: clickObj[7] == "Seed"})
        }
    }
    clickDataOptions := []
    for option, value in clickData
        clickDataOptions.push(option)
    return clickDataOptions
}