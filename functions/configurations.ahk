global iniFile := A_ScriptDir "\configs\configs.ini"

global resetKey, stopresetKey, restartKey, starttimerKey, stoptimerKey, resettimerKey
IniRead, resetKey    , %iniFile%, Hotkeys, Reset
IniRead, stopresetKey, %iniFile%, Hotkeys, StopReset
IniRead, restartKey  , %iniFile%, Hotkeys, Restart
IniRead, starttimerKey, %iniFile%, Hotkeys, StartTimer
IniRead, stoptimerKey , %iniFile%, Hotkeys, StopTimer
IniRead, resettimerKey, %iniFile%, Hotkeys, ResetTimer

global timerPreview := new Timer()


global resetMode, minCoords, maxCoords, originDistance, queueLimit, resetSeed, autoRestart, seamlessRestarts
     , resetThreshold, numInstances, layoutDimensions, keyDelay, switchDelay, clickDuration

global timerActive, tAnchor, tOffsetX, tOffsetY, tFont, tFontSize, tFontColour1, tFontColour2, tOutlineWidth
     , tOutlineColour, tGradientAngle, tAnimationType, tAnimationSpeed, tDecimalPlaces, tAutoSplit, remindShowPacks, tPreview

global resetMethod, readScreenMemory, coopMode, threadsUsage, hideOnMinimise, isBored

macroSection := [new Setting("resetMode", "Reset Mode", "Macro", 1, "select", ["auto", "cumulative", "setSeed", "manual"], "The type of resetting", [Func("OptResetModeHandler")])
                ,new Setting("minCoords", "Min Coordinate", "Macro", 1, "inputNumber", 700, "The minimum x-coordinate the macro auto-resets for", [Func("OptResetModeHandler"), "getSpawnChance();"])
                ,new Setting("maxCoords", "Max Coordinate", "Macro", 1, "inputNumber", 1800, "The maximum x-coordinate the macro auto-resets for", [Func("OptResetModeHandler"), "getSpawnChance();"])
                ,new Setting("originDistance", "Distance from 0,0 (1.19.50)", "Macro", 1, "inputNumber", 400, "The minimum number of blocks from world origin", [Func("OptResetModeHandler")])
                ,new Setting("queueLimit", "Queue Limit", "Macro", 1, "inputNumber", 100, "Limits the number of queued instances", [Func("OptResetModeHandler")])
                ,new Setting("resetSeed", "Seed", "Macro", 1, "select", {dir: "configs/seeds.txt", val: [564030617, 2425564754069582094, -990909152419832232, 1078231915]}, "", [Func("OptResetModeHandler")])
                ,new Setting("autoRestart", "Auto Restart", "Macro", 2, "checkbox", false, "Automatically restarts instances`nDeprecated: Use 'Block Marketplace' to prevent the buildup of lag.", [Func("AutoRestartHandler")])
                ,new Setting("seamlessRestarts", "Seamless", "Macro", 2, "checkbox", false, "Opens instances in the background before restarting", [Func("AutoRestartHandler")])
                ,new Setting("resetThreshold", "Reset Threshold", "Macro", 2, "inputNumber", 120, "Number of resets accumulated between instances to initiate an automatic restart", [Func("AutoRestartHandler")])
                ,new Setting("numInstances", "Number of Instances", "Macro", 3, "inputNumber", 4, "", 0)
                ,new Setting("layoutDimensions", "Layout", "Macro", 3, "inputText", "2,2", "The arrangement of instances (x, y)", 0)
                ,new Setting("keyDelay", "Key Delay", "Macro", 4, "inputNumber", 50, "The delay between world creation clicks", 0)
                ,new Setting("switchDelay", "Switch Delay", "Macro", 4, "inputNumber", 0, "The delay resetting in-between instances", 0)
                ,new Setting("clickDuration", "Click Duration", "Macro", 4, "inputNumber", 30, "How long each mouse click is held down for; helps to register clicks", 0)]

timerSection := [new Setting("timerActive", "Timer", "Timer", 1, "checkbox", true, "", [Func("TimerSettingHandler")])
                ,new Setting("tAnchor", "Anchor", "Timer", 2, "select", ["TopLeft", "TopRight", "BottomLeft", "BottomRight"], "Where the timer is relatively positioned on the instance", [Func("TimerSettingHandler")])
                ,new Setting("tOffsetX", "Offset-X", "Timer", 2, "inputNumber", 25, "Offset from the anchor point", [Func("TimerSettingHandler")])
                ,new Setting("tOffsetY", "Offset-Y", "Timer", 2, "inputNumber", 25, "Offset from the anchor point", [Func("TimerSettingHandler")])
                ,new Setting("tFont", "Font", "Timer", 3, "inputFont", "Mojangles", "Any font installed", [Func("TimerSettingHandler")])
                ,new Setting("tFontSize", "Size", "Timer", 3, "inputNumber", 50, "", [Func("TimerSettingHandler")])
                ,new Setting("tFontColour1", "Colour 1", "Timer", 3, "inputColour", "0xFFFFFFFF", "Hexadecimal Colour (0xAARRGGBB)", [Func("TimerSettingHandler")])
                ,new Setting("tFontColour2", "Colour 2", "Timer", 3, "inputColour", "0xFF737373", "Hexadecimal Colour (0xAARRGGBB)", [Func("TimerSettingHandler")])
                ,new Setting("tOutlineWidth", "Outline Width", "Timer", 3, "inputNumber", 10, "", [Func("TimerSettingHandler")])
                ,new Setting("tOutlineColour", "Outline Colour", "Timer", 3, "inputColour", "0xFF000000", "Hexadecimal Colour (0xAARRGGBB)", [Func("TimerSettingHandler")])
                ,new Setting("tGradientAngle", "Gradient Angle", "Timer", 3, "inputNumber", 60, "", [Func("TimerSettingHandler")])
                ,new Setting("tAnimationType", "Animation Type", "Timer", 3, "select", ["rotatory", "panoramic"], "How the timer's colours are animated", [Func("TimerSettingHandler")])
                ,new Setting("tAnimationSpeed", "Animation Length", "Timer", 3, "inputNumber", 0, "", [Func("TimerSettingHandler")])
                ,new Setting("tDecimalPlaces", "Decimals", "Timer", 3, "select", [0, 1, 2, 3], "", [Func("TimerSettingHandler")])
                ,new Setting("tAutoSplit", "Auto Split", "Timer", 4, "checkbox", true, "Automatically stops the timer when credits roll", [Func("TimerSettingHandler")])
                ,new Setting("remindShowPacks", "Remind: Show Packs", "Timer", 4, "checkbox", false, "After a completion, you can be reminded of", [Func("TimerSettingHandler")])
                ,new Setting("tPreview", "Show Preview", "Timer", 4, "checkbox", false, "", [Func("TimerSettingHandler"), Func("TimerPreviewHandler")])]

otherSection := [new Setting("resetMethod", "Reset Method", "Other", 1, "select", ["setupless", "setup"], "The method the macro uses to figure out where to click", [Func("OptResetMethodHandler")])
                ,new Setting("readScreenMemory", "Read Screen Memory", "Other", 1, "checkbox", false, "Reads the game memory to get the current screen, relies on setup click data for the clicks", 0)
                ,new Setting("coopMode", "Coop Mode", "Other", 1, "checkbox", false, "Prevents the 0/8 bug", 0)
                ,new Setting("threadsUsage", "Threads Utilisation", "Other", 2, "inputNumber", 0.8, "The percentage of CPU threads the instances will utilise during resets", 0)
                ,new Setting("hideOnMinimise", "Minimise to Tray", "Other", 3, "checkbox", false, "When the GUI is minimised, the taskbar icon will disappear to the tray", 0)
                ,new Setting("isBored", "are u bored?", "Other", 5, "checkbox", false, "fun lil game to play while resetting", 0)]

class Setting {
    static map := {}
    static toInit := []

    __New(id,name,section,subsection,type,default,hint,method) {
        this.id := id
        this.name := name
        this.section := section
        this.subsection := subsection
        this.type := type
        this.default := this.ParseDefaultValue(default)
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

    ParseDefaultValue(value) {
        if value.HasKey("dir") {
            FileRead, fileData, % value.dir
            if ErrorLevel
                return value.val, LogF("ERR", "Couldn't load file: """ value.dir """; A_LastError: " A_LastError)
            return StrSplit(fileData, ",")
        }
        return value
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
                this.attributeType := "value"

                div := WB.document.createElement("div")

                h3 := WB.document.createElement("h3")
                h3.innerText := this.name

                input := WB.document.createElement("input")
                input.id := this.id
                input.oninput := ObjBindMethod(this, "EventHandler")
                input.type := "text"
                if (this.type == "inputNumber")
                    this.method.InsertAt(1, ObjBindMethod(this, "InputNumberHandler"))
                this.element := input

                div.appendChild(h3)
                div.appendChild(input)
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
        
        isSubExist := false
        insertBeforeIndex := 0
        count := section["children"].length
        Loop, %count% {
            element := section["children"][A_Index-1]
            atSub := StrSplit(element.className, A_Space)[2]
            insertBeforeIndex := A_Index == count ? 0 : A_Index-1
            if !atSub
                continue
            else if (atSub == this.subsection)
                isSubExist := true
            else if (atSub > this.subsection)
                break
        }
        if (!insertBeforeIndex) {
            if (!isSubExist) {
                hr := WB.document.createElement("hr")
                section.appendChild(hr)
            }
            section.appendChild(this.rootDiv)
        } else {
            section.insertBefore(this.rootDiv, section.children[insertBeforeIndex])
            if (!isSubExist) {
                hr := WB.document.createElement("hr")
                section.insertBefore(hr, section.children[insertBeforeIndex])
                ; need to add ending subsection line, e.g. "minimise to tray" 
                ; hr := WB.document.createElement("hr")
                ; section.insertBefore(hr, section.children[insertBeforeIndex+2])
            }
        }
    }

    GetIniValue() {
        IniRead, value, %iniFile%, % this.section, % this.id
        if (value == "ERROR") {
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
            LogF("WAR", "Invalid value for " this.id ". Setting to default: " value)
        }
        if (this.type == "checkbox" && value == "false") ;more backwards compatibility
            value := false
        return value
    }

    UpdateSettingValue(value) {
        this.element[this.attributeType] := value ? "" value : 0
        this.EventHandler()
    }

    EventHandler() {
        this.value := this.element[this.attributeType]
        IniWrite, % this.value, %iniFile%, % this.section, % this.id
        globalVar := this.id, (%globalVar%) := this.value

        for k, func in this.method
            IsObject(func) ? func.call() : RunJS(func)
    }

    InputNumberHandler() {
        filteredInput := RegExReplace(this.value, "[^\d.]",, hasChanged)
        if hasChanged
            this.UpdateSettingValue(filteredInput)
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
            Setting["map"]["resetSeed"]["rootDiv"]["style"]["display"] := "none"

        case "auto":
            Setting["map"]["minCoords"]["rootDiv"]["style"]["display"] := "flex"
            Setting["map"]["maxCoords"]["rootDiv"]["style"]["display"] := "flex"
            Setting["map"]["originDistance"]["rootDiv"]["style"]["display"] := "flex"
            Setting["map"]["queueLimit"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["resetSeed"]["rootDiv"]["style"]["display"] := "none"

        case "manual":
            Setting["map"]["minCoords"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["maxCoords"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["originDistance"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["queueLimit"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["resetSeed"]["rootDiv"]["style"]["display"] := "none"

        case "setSeed":
            Setting["map"]["minCoords"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["maxCoords"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["originDistance"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["queueLimit"]["rootDiv"]["style"]["display"] := "none"
            Setting["map"]["resetSeed"]["rootDiv"]["style"]["display"] := "flex"
    }
}

AutoRestartHandler() {
    display := autoRestart ? "flex" : "none"
    Setting["map"]["seamlessRestarts"]["rootDiv"]["style"]["display"] := display
    Setting["map"]["resetThreshold"]["rootDiv"]["style"]["display"] := display
}

TimerSettingHandler() {
    timerOptions := [tAnchor, tOffsetX, tOffsetY, tFont, tFontSize, tFontColour1, tFontColour2, tGradientAngle
                    , tAnimationType, tAnimationSpeed, tOutlineWidth, tOutlineColour, tDecimalPlaces, 0, tAutoSplit]
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
    if (resetMethod == "setup" && !worldcreationClicks.count()) {
        f := Func("LoadClickData")
        SetTimer, %f%, -500
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

LoadClickData() {
    screenClicks := []
    worldcreationClicks := []

    clicksFile := FileOpen("configs/clicks.txt", "r")
    clicksArray := StrSplit(clicksFile.read(), "`n")

    metaData := StrSplit(clicksArray[1], ",")

    if (SubStr(metaData[1], 1, 1) == "#") {
        clicksArray.RemoveAt(1)
    } else if (SubStr(clicksArray[1], 1, 5) == "Heart") {
        Msgbox,4,, % "Outdated click data.`n" "V1.0+ uses identifiers to determine the current button to click, rather than using the colour of the text on the button.`n`n" "Yes: Do the setup`n" "No: Opt in for setupless resets"
        IfMsgBox, Yes
            Run, configs\scripts\Setup.ahk    
        IfMsgBox, No
            Setting["map"]["resetMethod"].UpdateSettingValue("setupless")
        
        return
    }

    clickDataVersion := StrReplace(metaData[1], "#")
    if (clickDataVersion == 1) {
        Msgbox,4,, % "V2 Click Data Update:`n- Macro can now look for the " """Play""" " button`n- Necessary for seamless restarts`n`nRedo the setup?"
        IfMsgBox, Yes
            Run, configs\scripts\Setup.ahk    
    } else if (clickDataVersion == 2) {
        Msgbox,4,, % "V3 Click Data Update:`n- Clicks the seed box for the reset mode " """Set Seed""" "`n`nRedo the setup?"
        IfMsgBox, Yes
            Run, configs\scripts\Setup.ahk
    }

    for k, click in clicksArray {
        clickObj := StrSplit(click, ",")
        if !clickObj.count()
            continue

        if (clickObj[6])
            screenClicks.push({btn:clickObj[1], x:clickObj[2], y:clickObj[3], px:clickObj[4], py:clickObj[5], colour:clickObj[6]})
        else
            worldcreationClicks.push({x:clickObj[2], y:clickObj[3], isSeedClick: clickObj[7] == "Seed"})
    }
    clicksFile.close()

    if !worldcreationClicks.count() {
        MsgBox,4,, % "Insufficient Click Data. Do you want to do the setup?"
        IfMsgBox, Yes
            Run, configs\scripts\Setup.ahk

        return
    }
}