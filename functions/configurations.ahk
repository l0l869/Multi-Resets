global maxCoords
global minCoords
global autoRestart
global resetThreshold
global keyDelay
global numInstances
global layoutDimensions
global threadsUsage
global readScreenMemory
global resetKey, stopresetKey, restartKey

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
        MsgBox, % "No Click Data: Make sure to do the setup."
        ExitApp
    }
}

LoadIniConfigurations()
{
    IniRead, resetKey    , %iniFile%, Hotkeys, Reset
    IniRead, stopresetKey, %iniFile%, Hotkeys, StopReset
    IniRead, restartKey  , %iniFile%, Hotkeys, Restart

    IniRead, maxCoords       , %iniFile%, Settings, maxCoords
    IniRead, minCoords       , %iniFile%, Settings, minCoords
    IniRead, autoRestart     , %iniFile%, Settings, autoRestart
    IniRead, resetThreshold  , %iniFile%, Settings, resetThreshold
    IniRead, keyDelay        , %iniFile%, Settings, keyDelay
    IniRead, numInstances    , %iniFile%, Settings, numInstances
    IniRead, layoutDimensions, %iniFile%, Settings, layoutDimensions
    IniRead, threadsUsage    , %iniFile%, Settings, threadsUsage
    IniRead, readScreenMemory, %iniFile%, Settings, readScreenMemory

    IniRead, timerActivated    , %iniFile%, Timer, timerActivated
    IniRead, timerAnchor       , %iniFile%, Timer, anchor
    IniRead, timerOffset       , %iniFile%, Timer, offset
    timerOffset := StrSplit(timerOffset, ",")
    IniRead, timerFont         , %iniFile%, Timer, font
    IniRead, timerSize         , %iniFile%, Timer, size
    IniRead, timerColour       , %iniFile%, Timer, colour
    IniRead, timerDecimalPlaces, %iniFile%, Timer, decimalPlaces
    IniRead, timerRefreshRate  , %iniFile%, Timer, refreshRate
    IniRead, timerAutoSplit    , %iniFile%, Timer, autoSplit
}