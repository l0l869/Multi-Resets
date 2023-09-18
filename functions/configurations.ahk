global resetMode
global maxCoords
global minCoords
global originDistance
global autoRestart
global resetThreshold
global keyDelay
global numInstances
global layoutDimensions
global threadsUsage
global readScreenMemory
global resetKey, stopresetKey, restartKey
global starttimerKey, stoptimerKey, resettimerKey

LoadClickData()
{
    screenClicks := []
    worldcreationClicks := []

    clicksFile := FileOpen("configs/clicks.txt", "r")
    clicksArray := StrSplit(clicksFile.read(), "`n")
    for k, click in clicksArray
    {
        clickObj := StrSplit(click, ",")

        if !clickObj.count()
            continue

        if (clickObj[4])
            screenClicks.push({ btn: clickObj[1], x: clickObj[2], y: clickObj[3], colour: clickObj[4] })
        else
            worldcreationClicks.push({ x: clickObj[2], y: clickObj[3] })
    }
    clicksFile.close()

    if !worldcreationClicks.count()
    {
        MsgBox, % "Insufficient Click Data: Make sure to do the setup."
        ExitApp
    }
}

LoadIniConfigs()
{
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
    IniRead, numInstances    , %iniFile%, Macro, numInstances
    IniRead, layoutDimensions, %iniFile%, Macro, layoutDimensions

    IniRead, timerActive       , %iniFile%, Timer, timerActive
    IniRead, timerAnchor       , %iniFile%, Timer, anchor
    IniRead, timerOffsetX      , %iniFile%, Timer, offsetX
    IniRead, timerOffsetY      , %iniFile%, Timer, offsetY
    IniRead, timerFont         , %iniFile%, Timer, font
    IniRead, timerSize         , %iniFile%, Timer, size
    IniRead, timerColour       , %iniFile%, Timer, colour
    IniRead, timerDecimalPlaces, %iniFile%, Timer, decimalPlaces
    IniRead, timerRefreshRate  , %iniFile%, Timer, refreshRate
    IniRead, timerAutoSplit    , %iniFile%, Timer, autoSplit

    IniRead, threadsUsage    , %iniFile%, Other, threadsUsage
    IniRead, readScreenMemory, %iniFile%, Other, readScreenMemory

    if (!timer1 && timerActive == "true")
    {
        timer1 := new Timer()
    } else if (timer1 && timerActive == "false") {
        updateFunction := timer1.updateFunction
        SetTimer, % updateFunction, off
        timer1.updateFunction := ""
        timer1.reset()
        timer1.__Delete()
        timer1 := ""
    }

    ; checks invalid value. Mainly because i messed merging configs from older versions to newer
    if (resetKey == "" || restartKey == "" || stopresetKey == "")
        return SetDefaultConfigs(), LoadIniConfigs()
}

UpdateGuiElements()
{
    WB.document.getElementById("resetMode").value := resetMode
    WB.document.getElementById("maxCoords").value := maxCoords
    WB.document.getElementById("minCoords").value := minCoords
    WB.document.getElementById("originDistance").value := originDistance
    WB.document.getElementById("autoRestart").checked := autoRestart == "true" ? 1 : 0
    WB.document.getElementById("resetThreshold").value := resetThreshold
    WB.document.getElementById("keyDelay").value := keyDelay
    WB.document.getElementById("numInstances").value := numInstances
    WB.document.getElementById("layoutDimensions").value := layoutDimensions
    WB.document.getElementById("threadsUsage").value := threadsUsage
    WB.document.getElementById("readScreenMemory").checked := readScreenMemory == "true" ? 1 : 0

    WB.document.getElementById("timerActive").checked := timerActive == "true" ? 1 : 0
    WB.document.getElementById("timerAnchor").value := timerAnchor
    WB.document.getElementById("timerOffsetX").value := timerOffsetX
    WB.document.getElementById("timerOffsetY").value := timerOffsetY
    WB.document.getElementById("timerFont").value := timerFont
    WB.document.getElementById("timerSize").value := timerSize
    WB.document.getElementById("timerColour").value := timerColour
    WB.document.getElementById("timerDecimalPlaces").value := timerDecimalPlaces
    WB.document.getElementById("timerAutoSplit").checked := timerAutoSplit == "true" ? 1 : 0
}

SetDefaultConfigs()
{
    IniWrite, ^r  , %iniFile%, Hotkeys, Reset
    IniWrite, ^tab, %iniFile%, Hotkeys, StopReset
    IniWrite, ^!r , %iniFile%, Hotkeys, Restart
    IniWrite, "", %iniFile%, Hotkeys, StartTimer
    IniWrite, "", %iniFile%, Hotkeys, StopTimer
    IniWrite, "", %iniFile%, Hotkeys, ResetTimer

    resetMode := "auto"
    IniWrite, resetMode, %iniFile%, Macro, resetMode
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
    IniWrite, 35       , %iniFile%, Timer, size
    IniWrite, FFFFFF   , %iniFile%, Timer, colour
    IniWrite, 3        , %iniFile%, Timer, decimalPlaces
    IniWrite, 0        , %iniFile%, Timer, refreshRate
    IniWrite, 1        , %iniFile%, Timer, autoSplit

    IniWrite, 0.8  , %iniFile%, Other, threadsUsage
    IniWrite, false, %iniFile%, Other, readScreenMemory
}