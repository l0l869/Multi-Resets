#NoEnv
#SingleInstance, Force
#Include, %A_ScriptDir%
#Include, functions/configurations.ahk
#Include, functions/timer.ahk
#Include, functions/updater.ahk

SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%
SendMode, Input
SetMouseDelay, -1
EnvGet, A_LocalAppData, LocalAppData

global SCRIPT_VERSION := 20230917.22
global iniFile := A_ScriptDir "\configs\configs.ini"
global minecraftDir := A_LocalAppData "\Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe\LocalState\games\com.mojang"

EnvGet, threadCount, NUMBER_OF_PROCESSORS
global threadCount
global scaleBy := A_ScreenDPI / 96
global MCversion
global offsetsCoords
global offsetsScreen
global lastRestart
global timer1
global screenClicks := []
global worldcreationClicks := []
global MCInstances := []

LoadIniConfigs()
LoadClickData()
FetchUpdates()

Menu, Tray, Icon, assets/_Icon.ico
Menu, Tray, Add, MC Directory, OpenMinecraftDir
Menu, Tray, Add, Launch Instances, LaunchInstances
Menu, Tray, Add, Close Instances, CloseInstances

global WB
Gui, Main:Add, ActiveX, vWB x0 y0 w600 h400, shell.explorer
WB.Silent := true
; slow but if you ever want to utilise directory within html
; WB.Navigate("file:///" A_ScriptDir "\assets\gui.html") 
; while (WB.readystate != 4 || WB.busy)
; 	Sleep, 10
WB.Navigate("about:<!DOCTYPE HTML><meta http-equiv='x-ua-compatible' content='IE=Edge'>")
FileRead, html, assets/gui.html
WB.Document.write(html)
WB.Document.parentWindow.AHK := Func("JS_AHK")

Gui, Main:+HwndGuiHwnd

; dark mode title bar
DllCall("dwmapi\DwmSetWindowAttribute", "ptr", GuiHwnd, "int", 20, "int*", true, "int", 4)

; dark mode menu
uxtheme := DllCall("GetModuleHandle", "str", "uxtheme", "ptr")
SetPreferredAppMode := DllCall("GetProcAddress", "ptr", uxtheme, "ptr", 135, "ptr")
FlushMenuThemes := DllCall("GetProcAddress", "ptr", uxtheme, "ptr", 136, "ptr")
DllCall(SetPreferredAppMode, "int", 1)
DllCall(FlushMenuThemes)

Gui, Main:Show, w600 h400, Multi-Resets
UpdateGuiElements()

#If WinActive("Minecraft")
    Hotkey, %resetKey%, Reset
    Hotkey, %stopresetKey%, StopReset
    if starttimerKey
        Hotkey, %starttimerKey%, StartTimer
    if stoptimerKey
        Hotkey, %stoptimerKey%, StopTimer
    if resettimerKey
        Hotkey, %resettimerKey%, ResetTimer
#If
Hotkey, %restartKey%, Restart
RCtrl::ExitApp
return

#Include functions/memory.ahk
#Include functions/functions.ahk

Gui_UpdateSetting(section, key, value){
    IniWrite, %value%, %iniFile%, %section%, %key%
    LoadIniConfigs()
}

Gui_EditHotkeys(){
    global hotkeyboxReset, hotkeyboxStopReset, hotkeyboxRestart
    global hotkeyboxStartTimer, hotkeyboxStopTimer, hotkeyboxResetTimer
    Gui, hotkeysWin:Color, 0x323232
    Gui, hotkeysWin:Font, cWhite
    WinGetPos, X, Y, W, H, Multi-Resets
    Gui, hotkeysWin:Show, % "w330 " "h180 " "x" X+W/2-330/2 " y" Y+H/2-180/2
    Gui, hotkeysWin:add, Hotkey, x10 y20 w150 vhotkeyboxReset
    Gui, hotkeysWin:add, Hotkey, x10 y65 w150 vhotkeyboxStopReset
    Gui, hotkeysWin:add, Hotkey, x10 y110 w150 vhotkeyboxRestart
    Gui, hotkeysWin:add, Text  , x10 y5,Reset
    Gui, hotkeysWin:add, Text  , x10 y50,Stop Reset
    Gui, hotkeysWin:add, Text  , x10 y95,Restart MC
    Gui, hotkeysWin:add, Hotkey, x170 y20 w150 vhotkeyboxStartTimer
    Gui, hotkeysWin:add, Hotkey, x170 y65 w150 vhotkeyboxStopTimer
    Gui, hotkeysWin:add, Hotkey, x170 y110 w150 vhotkeyboxResetTimer
    Gui, hotkeysWin:add, Text  , x170 y5,Start Timer
    Gui, hotkeysWin:add, Text  , x170 y50,Stop Timer
    Gui, hotkeysWin:add, Text  , x170 y95,Reset Timer
    Gui, hotkeysWin:add, Button, x10 y140 w310 h30 gSaveHotkeys,Save

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

Gui_RegisterMulti(){
    Run, configs\RegisterMulti.ahk
}

Gui_Setup(){
    Run, configs\Setup.ahk
}

JS_AHK(func, prms*) {
    %func%(prms*)
}

MainGuiClose:
    ExitApp

#Include functions/reset.ahk