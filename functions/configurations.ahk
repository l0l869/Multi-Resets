global resetMode
     , maxCoords
     , minCoords
     , originDistance
     , autoRestart
     , resetThreshold
     , keyDelay
     , switchDelay
     , numInstances
     , layoutDimensions
     , threadsUsage
     , readScreenMemory
     , resetMethod
     , coopMode
     , hideOnMinimise
     , resetKey, stopresetKey, restartKey
     , starttimerKey, stoptimerKey, resettimerKey

global timerActive
     , tAnchor
     , tOffsetX
     , tOffsetY
     , tFont
     , tFontSize
     , tFontColour1
     , tFontColour2
     , tGradientAngle
     , tAnimationType
     , tAnimationSpeed
     , tOutlineWidth
     , tOutlineColour
     , tDecimalPlaces
     , tRefreshRate
     , tAutoSplit
     , tPreview

global timerPreview

LoadClickData() {
    screenClicks := []
    worldcreationClicks := []

    clicksFile := FileOpen("configs/clicks.txt", "r")
    clicksArray := StrSplit(clicksFile.read(), "`n")

    if (SubStr(clicksArray[1], 1, 1) == "#") {
        clicksArray.RemoveAt(1)
    } else if (SubStr(clicksArray[1], 1, 5) == "Heart") {
        Msgbox,4,, % "Outdated click data.`n" "V1.0+ uses identifiers to determine the current button to click, rather than using the colour of the text on the button.`n`n" "Yes: Do the setup`n" "No: Opt in for setupless resets"
        IfMsgBox, Yes
            Run, configs\Setup.ahk    
        IfMsgBox, No
            Gui_UpdateSetting("Other", "resetMethod", "setupless")
        
        return
    }

    for k, click in clicksArray
    {
        clickObj := StrSplit(click, ",")
        if !clickObj.count()
            continue

        if (clickObj[6])
            screenClicks.push({btn:clickObj[1], x:clickObj[2], y:clickObj[3], px:clickObj[4], py:clickObj[5], colour:clickObj[6]})
        else
            worldcreationClicks.push({x:clickObj[2], y:clickObj[3]})
    }
    clicksFile.close()

    if !worldcreationClicks.count()
    {
        MsgBox,4,, % "Insufficient Click Data. Do you want to do the setup?"
        IfMsgBox, Yes
            Run, configs\Setup.ahk

        return
    }
}

LoadIniConfigs() {
    IniRead, resetKey    , %iniFile%, Hotkeys, Reset
    IniRead, stopresetKey, %iniFile%, Hotkeys, StopReset
    IniRead, restartKey  , %iniFile%, Hotkeys, Restart
    IniRead, starttimerKey, %iniFile%, Hotkeys, StartTimer
    IniRead, stoptimerKey , %iniFile%, Hotkeys, StopTimer
    IniRead, resettimerKey, %iniFile%, Hotkeys, ResetTimer

    IniRead, resetMode       , %iniFile%, Macro, resetMode
    IniRead, maxCoords       , %iniFile%, Macro, maxCoords
    IniRead, minCoords       , %iniFile%, Macro, minCoords
    IniRead, originDistance  , %iniFile%, Macro, originDistance
    IniRead, autoRestart     , %iniFile%, Macro, autoRestart
    IniRead, resetThreshold  , %iniFile%, Macro, resetThreshold
    IniRead, keyDelay        , %iniFile%, Macro, keyDelay
    IniRead, switchDelay     , %iniFile%, Macro, switchDelay
    IniRead, numInstances    , %iniFile%, Macro, numInstances
    IniRead, layoutDimensions, %iniFile%, Macro, layoutDimensions

    IniRead, timerActive    , %iniFile%, Timer, timerActive
    IniRead, tAnchor        , %iniFile%, Timer, anchor
    IniRead, tOffsetX       , %iniFile%, Timer, offsetX
    IniRead, tOffsetY       , %iniFile%, Timer, offsetY
    IniRead, tFont          , %iniFile%, Timer, font
    IniRead, tFontSize      , %iniFile%, Timer, fontSize
    IniRead, tFontColour1   , %iniFile%, Timer, fontColour1
    IniRead, tFontColour2   , %iniFile%, Timer, fontColour2
    IniRead, tGradientAngle , %iniFile%, Timer, gradientAngle
    IniRead, tAnimationType , %iniFile%, Timer, animationType
    IniRead, tAnimationSpeed, %iniFile%, Timer, animationSpeed
    IniRead, tOutlineWidth  , %iniFile%, Timer, outlineWidth
    IniRead, tOutlineColour , %iniFile%, Timer, outlineColour
    IniRead, tDecimalPlaces , %iniFile%, Timer, decimalPlaces
    IniRead, tRefreshRate   , %iniFile%, Timer, refreshRate
    IniRead, tAutoSplit     , %iniFile%, Timer, autoSplit
    IniRead, tPreview       , %iniFile%, Timer, preview

    IniRead, threadsUsage    , %iniFile%, Other, threadsUsage
    IniRead, readScreenMemory, %iniFile%, Other, readScreenMemory
    IniRead, resetMethod     , %iniFile%, Other, resetMethod
    IniRead, coopMode        , %iniFile%, Other, coopMode
    IniRead, hideOnMinimise  , %iniFile%, Other, hideOnMinimise

    timerOptions := [tAnchor, tOffsetX, tOffsetY, tFont, tFontSize, tFontColour1, tFontColour2, tGradientAngle, tAnimationType, tAnimationSpeed, tOutlineWidth, tOutlineColour, tDecimalPlaces, tRefreshRate, tAutoSplit]
    if !timer1
        timer1 := new Timer(timerOptions*)
    else
        timer1.setSettings(timerOptions*)

    if (tPreview == "true" && !timerPreview) {
        timerPreview := new Timer(timerOptions*)
        timerPreview.show()
        timerPreview.start()
    } else if (tPreview == "false" && timerPreview) {
        timerPreview.__Delete()
        timerPreview := ""
    } else if (tPreview == "true" && timerPreview) {
        timerPreview.setSettings(timerOptions*)
    }

    if (resetMethod == "setup" && !worldcreationClicks.count()) {
        f := Func("LoadClickData")
        SetTimer, %f%, -500
    }

    ; checks invalid value. Mainly because i messed merging configs from older versions to newer
    if (resetKey == "" || restartKey == "" || stopresetKey == "")
        return SetDefaultConfigs(), LoadIniConfigs()
}

UpdateGuiElements() {
    WB.document.getElementById("resetMode").value := resetMode
    WB.document.getElementById("maxCoords").value := maxCoords
    WB.document.getElementById("minCoords").value := minCoords
    WB.document.getElementById("originDistance").value := originDistance
    WB.document.getElementById("autoRestart").checked := autoRestart == "true" ? 1 : 0
    WB.document.getElementById("resetThreshold").value := resetThreshold
    WB.document.getElementById("keyDelay").value := keyDelay
    WB.document.getElementById("switchDelay").value := switchDelay
    WB.document.getElementById("numInstances").value := numInstances
    WB.document.getElementById("layoutDimensions").value := layoutDimensions
    WB.document.getElementById("threadsUsage").value := threadsUsage
    WB.document.getElementById("readScreenMemory").checked := readScreenMemory == "true" ? 1 : 0
    WB.document.getElementById("resetMethod").value := resetMethod
    WB.document.getElementById("coopMode").checked := coopMode == "true" ? 1 : 0
    WB.document.getElementById("hideOnMinimise").checked := hideOnMinimise == "true" ? 1 : 0

    WB.document.getElementById("tActive").checked := timerActive == "true" ? 1 : 0
    WB.document.getElementById("tAnchor").value := tAnchor
    WB.document.getElementById("tOffsetX").value := tOffsetX
    WB.document.getElementById("tOffsetY").value := tOffsetY
    WB.document.getElementById("tFont").value := tFont
    WB.document.getElementById("tFontSize").value := tFontSize
    WB.document.getElementById("tFontColour1").value := tFontColour1
    WB.document.getElementById("tFontColour2").value := tFontColour2
    WB.document.getElementById("tGradientAngle").value := tGradientAngle
    WB.document.getElementById("tAnimationType").value := tAnimationType
    WB.document.getElementById("tAnimationSpeed").value := tAnimationSpeed
    WB.document.getElementById("tOutlineWidth").value := tOutlineWidth
    WB.document.getElementById("tOutlineColour").value := tOutlineColour
    WB.document.getElementById("tDecimalPlaces").value := tDecimalPlaces
    WB.document.getElementById("tAutoSplit").checked := tAutoSplit == "true" ? 1 : 0
    WB.document.getElementById("tPreview").checked := tPreview == "true" ? 1 : 0

    hex := "0x" SubStr(tFontColour1, StrLen(tFontColour1)-5, 6)
    WB.document.getElementById("btn-colour1").style.color := hex+0
    hex := "0x" SubStr(tFontColour2, StrLen(tFontColour2)-5, 6)
    WB.document.getElementById("btn-colour2").style.color := hex+0
    hex := "0x" SubStr(tOutlineColour, StrLen(tOutlineColour)-5, 6)
    WB.document.getElementById("btn-colour3").style.color := hex+0
}

SetDefaultConfigs() {
    IniWrite, ^r  , %iniFile%, Hotkeys, Reset
    IniWrite, ^tab, %iniFile%, Hotkeys, StopReset
    IniWrite, ^!r , %iniFile%, Hotkeys, Restart
    IniWrite, "", %iniFile%, Hotkeys, StartTimer
    IniWrite, "", %iniFile%, Hotkeys, StopTimer
    IniWrite, "", %iniFile%, Hotkeys, ResetTimer

    IniWrite, auto , %iniFile%, Macro, resetMode
    IniWrite, 1800 , %iniFile%, Macro, maxCoords
    IniWrite, 700  , %iniFile%, Macro, minCoords
    IniWrite, 400  , %iniFile%, Macro, originDistance
    IniWrite, false, %iniFile%, Macro, autoRestart
    IniWrite, 120  , %iniFile%, Macro, resetThreshold
    IniWrite, 50   , %iniFile%, Macro, keyDelay
    IniWrite, 4    , %iniFile%, Macro, numInstances
    layout := "2,2"
    IniWrite, %layout%, %iniFile%, Macro, layoutDimensions

    IniWrite, true     , %iniFile%, Timer, timerActive
    IniWrite, TopRight , %iniFile%, Timer, anchor
    IniWrite, 25       , %iniFile%, Timer, offsetX
    IniWrite, 25       , %iniFile%, Timer, offsetY
    IniWrite, Mojangles, %iniFile%, Timer, font
    IniWrite, 50       , %iniFile%, Timer, fontsize
    IniWrite, FFFFFFFF , %iniFile%, Timer, fontColour1
    IniWrite, FF737373 , %iniFile%, Timer, fontColour2
    IniWrite, 60       , %iniFile%, Timer, gradientAngle
    IniWrite, rotatory , %iniFile%, Timer, animationType
    IniWrite, 0        , %iniFile%, Timer, animationSpeed
    IniWrite, 10       , %iniFile%, Timer, outlineWidth
    IniWrite, 00000000 , %iniFile%, Timer, outlineColour
    IniWrite, 3        , %iniFile%, Timer, decimalPlaces
    IniWrite, 0        , %iniFile%, Timer, refreshRate
    IniWrite, true     , %iniFile%, Timer, autoSplit
    IniWrite, false    , %iniFile%, Timer, preview

    IniWrite, 0.8  , %iniFile%, Other, threadsUsage
    IniWrite, false, %iniFile%, Other, readScreenMemory
    IniWrite, setup, %iniFile%, Other, resetMethod
    IniWrite, false, %iniFile%, Other, coopMode
    IniWrite, false, %iniFile%, Other, hideOnMinimise
}