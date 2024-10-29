SetBatchLines, -1
SetWinDelay, -1
SetWorkingDir, %A_ScriptDir%
SendMode, Input
SetMouseDelay, -1
SetControlDelay, -1
EnvGet, A_LocalAppData, LocalAppData
Process, Priority,, High

initTick := QPC()
LogF("INF", "Initialising (" A_AhkVersion " " A_PtrSize*8 "-bit)")

#NoEnv
#SingleInstance, Force
#Include, %A_ScriptDir%
#Include, functions/configurations.ahk

global SCRIPT_VERSION := 20241002.23
global iniFile := A_ScriptDir "\configs\configs.ini"
global minecraftDir := A_LocalAppData "\Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe\LocalState\games\com.mojang"

EnvGet, threadCount, NUMBER_OF_PROCESSORS
global threadCount
global scaleBy := A_ScreenDPI / 96, workArea := GetWorkArea()
global SM_CXFRAME := DllCall("GetSystemMetrics", "Int", 32)
global SM_CYFRAME := DllCall("GetSystemMetrics", "Int", 33)
global SM_CYCAPTION := DllCall("GetSystemMetrics", "Int", 4)
global MCversion, isPre11830
global offsetsX, offsetsZ, offsetsAutoSplit, offsetsScreen
global lastRestart
global timer1
global MCInstances := [], replacementInstances := [], queuedInstances := []
global resetDll := DllCall("LoadLibrary", "Str", "functions/reset.dll", "Ptr")
global gameScript := LoadFile("functions/game.ahk")
if !resetDll
    LogF("WAR", "Failed to load reset.dll; setupless will not work")

Menu, Tray, Icon, assets/_Icon.ico
Menu, Tray, Add, MC Directory, OpenMinecraftDir
Menu, Tray, Add, Launch Instances, Restart
Menu, Tray, Add, Close Instances, CloseInstances

global WB, GuiHwnd
Gui, Main:Add, ActiveX, vWB x0 y0 w600 h400, shell.explorer
InitGui()
Gui, Main:Show, % "w" 600/scaleBy " h" 400/scaleBy, Multi-Resets
LogF("INF", "Initialised (" Floor(QPC()-initTick) "ms)")

CheckMinecraftSettings()
global latestFetchedVersion := FetchUpdates()

global FuncUpdateOverlay := Func("UpdateOverlay")
SetTimer, %FuncUpdateOverlay%, 0

Hotkey, IfWinActive, Minecraft
Hotkey, %resetKey%, Reset
Hotkey, %stopresetKey%, StopReset
if starttimerKey
    Hotkey, %starttimerKey%, StartTimer
if stoptimerKey
    Hotkey, %stoptimerKey%, StopTimer
if resettimerKey
    Hotkey, %resettimerKey%, ResetTimer

Hotkey, IfWinActive
Hotkey, %restartKey%, Restart
RCtrl::Goto, MainGuiClose
return

#Include, functions/memory.ahk
#Include, functions/loadfile.ahk
#Include, functions/functions.ahk
#Include, functions/updater.ahk
#Include, functions/overlay.ahk
#Include, functions/timer.ahk

InitGui() {
    WB.Silent := true
    WB.Navigate("about:<!DOCTYPE HTML><meta http-equiv='x-ua-compatible' content='IE=Edge'>")
    FileRead, html, assets/gui.html
    WB.Document.write(html)
    ; WB.Navigate("file:///" A_ScriptDir "\assets\gui.html") 
    WB.Document.parentWindow.AHK := Func("JS_AHK")
    Gui, Main:+HwndGuiHwnd

    ; dark mode title bar
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", GuiHwnd, "Int", 20, "Int*", true, "Int", 4)

    ; dark mode menu
    uxTheme := DllCall("GetModuleHandle", "Str", "uxTheme", "Ptr")
    setPreferredAppMode := DllCall("GetProcAddress", "Ptr", uxTheme, "Ptr", 135, "Ptr")
    flushMenuThemes := DllCall("GetProcAddress", "Ptr", uxTheme, "Ptr", 136, "Ptr")
    DllCall(setPreferredAppMode, "Int", 1)
    DllCall(flushMenuThemes)

    InitGuiElements()
}

Gui_UpdateProgress(show, percent := 0, text := "", buttonFunc := "") {
    static background_blur
        , progress_container
        , progress_slider    
        , progress_text
        , progress_button

    if (!background_blur) {
        background_blur := WB.document.getElementById("background-blur")
        progress_container := WB.document.getElementById("progress-container")
        progress_text := WB.document.getElementById("progress-text")
        progress_slider := WB.document.getElementById("progress-slider")
        progress_button := progress_container.querySelector("button")
    }

    background_blur.style.display := progress_container.style.display := show ? "block" : "none"
    if (!buttonFunc)
        progress_button.style.display := "none"
    else if (buttonFunc != 1) {
        progress_button.style.display := "block"
        progress_button.onclick := buttonFunc
    }
    progress_slider.style.width := percent "%"
    progress_text.textContent := text
}

Gui_EditHotkeys() {
    global hotkeyboxReset, hotkeyboxStopReset, hotkeyboxRestart
    global hotkeyboxStartTimer, hotkeyboxStopTimer, hotkeyboxResetTimer
    Gui, hotkeysWin:Color, 0x323232
    Gui, hotkeysWin:Font, cWhite
    WinGetPos, X, Y, W, H, Multi-Resets
    Gui, hotkeysWin:Show, % "w330 h180 x" X + W/2 - 330/2 " y" Y + H/2 - 180/2
    Gui, hotkeysWin:add, Hotkey, x10 y20 w150 vhotkeyboxReset
    Gui, hotkeysWin:add, Hotkey, x10 y65 w150 vhotkeyboxStopReset
    Gui, hotkeysWin:add, Hotkey, x10 y110 w150 vhotkeyboxRestart
    Gui, hotkeysWin:add, Text  , x10 y5, Reset
    Gui, hotkeysWin:add, Text  , x10 y50, Stop Reset
    Gui, hotkeysWin:add, Text  , x10 y95, Restart MC
    Gui, hotkeysWin:add, Hotkey, x170 y20 w150 vhotkeyboxStartTimer
    Gui, hotkeysWin:add, Hotkey, x170 y65 w150 vhotkeyboxStopTimer
    Gui, hotkeysWin:add, Hotkey, x170 y110 w150 vhotkeyboxResetTimer
    Gui, hotkeysWin:add, Text  , x170 y5, Start Timer
    Gui, hotkeysWin:add, Text  , x170 y50, Stop Timer
    Gui, hotkeysWin:add, Text  , x170 y95, Reset Timer
    Gui, hotkeysWin:add, Button, x10 y140 w310 h30 gSaveHotkeys, Save

    IniRead, iniKey, %iniFile%, Hotkeys, Reset
    GuiControl, hotkeysWin:, hotkeyboxReset, %iniKey%
        
    IniRead, iniKey, %iniFile%, Hotkeys, StopReset
    GuiControl, hotkeysWin:, hotkeyboxStopReset, %iniKey%

    IniRead, iniKey, %iniFile%, Hotkeys, Restart
    GuiControl, hotkeysWin:, hotkeyboxRestart, %iniKey%

    IniRead, iniKey, %iniFile%, Hotkeys, StartTimer
    GuiControl, hotkeysWin:, hotkeyboxStartTimer, %iniKey%
        
    IniRead, iniKey, %iniFile%, Hotkeys, StopTimer
    GuiControl, hotkeysWin:, hotkeyboxStopTimer, %iniKey%

    IniRead, iniKey, %iniFile%, Hotkeys, ResetTimer
    GuiControl, hotkeysWin:, hotkeyboxResetTimer, %iniKey%

    return

    SaveHotkeys:
        Gui, hotkeysWin:Submit
        Gui, hotkeysWin:Destroy

        IniWrite, %hotkeyboxReset%, %iniFile%, Hotkeys, Reset
        IniWrite, %hotkeyboxStopReset%, %iniFile%, Hotkeys, StopReset
        IniWrite, %hotkeyboxRestart%, %iniFile%, Hotkeys, Restart

        IniWrite, %hotkeyboxStartTimer%, %iniFile%, Hotkeys, StartTimer
        IniWrite, %hotkeyboxStopTimer%, %iniFile%, Hotkeys, StopTimer
        IniWrite, %hotkeyboxResetTimer%, %iniFile%, Hotkeys, ResetTimer

        Run, Multi-Resets.ahk
    return
}

Gui_RegisterMulti() {
    Run, configs\scripts\RegisterMulti.ahk
}

Gui_Setup() {
    Run, configs\scripts\Setup.ahk
}

Gui_BlockMarketplace() {
    Run, configs\scripts\BlockMarketplace.ahk
}

Gui_UpdateToLatest() {
    DownloadLatest(latestFetchedVersion)
}

JS_AHK(func, prms*) {
    return %func%(prms*)
}

MainGuiSize:
    if (A_EventInfo != 1 || !hideOnMinimise)
        return
    WinHide, % "ahk_id " GuiHwnd
    Menu, Tray, Add, Open GUI, RestoreGui
return

RestoreGui:
    WinShow, % "ahk_id " GuiHwnd
    WinRestore, % "ahk_id " GuiHwnd
    Menu, Tray, Delete, Open GUI
return

MainGuiClose:
    DllCall("FreeLibrary", "UPtr", resetDll)
    LogF("INF", "App Exit")
    ExitApp

#Include, functions/reset.ahk