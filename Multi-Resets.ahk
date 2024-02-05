#NoEnv
#SingleInstance, Force
#Include, %A_ScriptDir%
#Include, functions/configurations.ahk
#Include, functions/timer.ahk
#Include, functions/updater.ahk
#Include, functions/loadfile.ahk

SetBatchLines, -1
SetWinDelay, -1
SetWorkingDir, %A_ScriptDir%
SendMode, Input
SetMouseDelay, -1
EnvGet, A_LocalAppData, LocalAppData

global SCRIPT_VERSION := 20231227.21
global iniFile := A_ScriptDir "\configs\configs.ini"
global minecraftDir := A_LocalAppData "\Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe\LocalState\games\com.mojang"

EnvGet, threadCount, NUMBER_OF_PROCESSORS
global threadCount
global scaleBy := A_ScreenDPI / 96
global MCversion
global offsetsX, offsetsZ, offsetsScreen
global lastRestart
global timer1
global screenClicks := [], worldcreationClicks := []
global MCInstances := [], replacementInstances := []
global resetDll := DllCall("LoadLibrary", "Str", "functions/reset.dll", "Ptr")
global gameScript := LoadFile("functions/game.ahk")
DllCall("gdi32\AddFontResource", "Str", A_ScriptDir "\assets\Mojangles.ttf")

LoadIniConfigs()

Menu, Tray, Icon, assets/_Icon.ico
Menu, Tray, Add, MC Directory, OpenMinecraftDir
Menu, Tray, Add, Launch Instances, Restart
Menu, Tray, Add, Close Instances, CloseInstances

global WB, GuiHwnd
Gui, Main:Add, ActiveX, vWB x0 y0 w600 h400, shell.explorer
InitGui()
Gui, Main:Show, % "w" 600/scaleBy " h" 400/scaleBy, Multi-Resets

latestFetchedVersion := FetchUpdates()

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

#Include functions/memory.ahk
#Include functions/functions.ahk

InitGui() {
    WB.Silent := true
    WB.Navigate("about:<!DOCTYPE HTML><meta http-equiv='x-ua-compatible' content='IE=Edge'>")
    FileRead, html, assets/gui.html
    WB.Document.write(html)
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

    fonts := GetFontNames(0)
    select := WB.document.getElementById("font-list")
    for k, font in fonts {
        newOption := WB.document.createElement("option")
        optionText := WB.document.createTextNode(k)
        textStyle := newOption.style
        textStyle["font-family"] := k
        newOption.appendChild(optionText)
        select.appendChild(newOption)
    }
    s := WB.document.getElementById("tFont").style, s["font-family"] := tFont

    UpdateGuiElements()
}

Gui_UpdateSetting(section, key, value) {
    IniWrite, %value%, %iniFile%, %section%, %key%
    LoadIniConfigs()
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
    Run, configs\RegisterMulti.ahk
}

Gui_Setup() {
    Run, configs\Setup.ahk
}

Gui_UpdateToLatest() {
    DownloadLatest(latestFetchedVersion)
}

JS_AHK(func, prms*) {
    return %func%(prms*)
}

MainGuiSize:
if (A_EventInfo != 1 || hideOnMinimise == "false")
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
SetTimer, %FuncUpdateMainTimer%, Off
timer1 := ""
timerPreview := ""
DllCall("FreeLibrary", "UPtr", resetDll)
DllCall("gdi32\RemoveFontResource", "Str", A_ScriptDir "\assets\Mojangles.ttf")
ExitApp

#Include functions/reset.ahk