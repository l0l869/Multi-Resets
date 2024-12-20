; might wanna rewrite this whole thing, however it does the job

#SingleInstance, Force
SetBatchLines, -1
SetWorkingDir, % A_ScriptDir "/../"
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen

global CLICK_DATA_VERSION := 4
global currentID := 1
global IDENTIFIERS := ["Play","Heart","SaveAndQuit","CreateNew","CreateNewWorld","WorldCreation"]
global clickData := []
global screenClicks := []
global worldcreationClicks := []
global layoutDimensions, hwnd, workAreaWidth, workAreaHeight, win, mouseX, mouseY, atMouseColour, btnName
global mcVersion
global SM_CXFRAME := DllCall("GetSystemMetrics", "Int", 32)
global SM_CYFRAME := DllCall("GetSystemMetrics", "Int", 33)
global SM_CYCAPTION := DllCall("GetSystemMetrics", "Int", 4)

MsgBox % "Tab: Assign`n" "Shift + Esc: Finish Setup"

SetTitleMatchMode, 3
while WinExist("Minecraft")
    WinClose

Run, shell:AppsFolder\Microsoft.MinecraftUWP_8wekyb3d8bbwe!App
SetTitleMatchMode, 1
WinWait, Minecraft
hwnd := WinExist("Minecraft")

IniRead, layoutDimensions, configs.ini, Macro, layoutDimensions
VarSetCapacity(workArea, 16, 0)
DllCall("SystemParametersInfo", "UInt", 0x0030, "UInt", 0, "UPtr", &rect, "UInt", 0)
workAreaWidth := NumGet(&rect, 8, "Int")
workAreaHeight := NumGet(&rect, 12, "Int")
dim := StrSplit(layoutDimensions, ",")
width := workAreaWidth / dim[1]
height := workAreaHeight / dim[2]
WinRestore, % "ahk_id " hwnd
DllCall("SetWindowPos", "Ptr", hwnd, "UInt", 0
        , "Int", (workAreaWidth-width-SM_CXFRAME)/2, "Int", (workAreaHeight-height)/2
        , "Int", width+SM_CXFRAME*2, "Int", height+SM_CYFRAME, "UInt", 0x0400)

mcVersion := GetMinecraftVersion()

GetMinecraftVersion() {
    Process, Exist, Minecraft.Windows.exe
    pid := ErrorLevel

    hProcess := DllCall("OpenProcess", "UInt", 0x10|0x400, "Int", 0, "UInt", pid)
    if (ErrorLevel || !hProcess)
        msgbox % "Failed to open process."

    VarSetCapacity(lpFilename, 2048 * (A_IsUnicode ? 2 : 1))
    DllCall("psapi\GetModuleFileNameEx"
            , "Ptr", hProcess
            , "Ptr", hModule
            , "Str", lpFilename
            , "Uint", 2048 / (A_IsUnicode ? 2 : 1))

    DllCall("CloseHandle", hProcess)
    FileGetVersion, version, %lpFilename%
    return version
}


global textMouseToolTip, textMouseColourTip
Gui, Setup:Show, % "x0 y0 w" A_ScreenWidth " h" A_ScreenHeight
Gui, Setup:Font, % "s25 cFFFFFF q4", Mojangles
Gui, Setup:Add , Text, x0 y0 w500 h150 vtextMouseToolTip
Gui, Setup:Add , Text, x0 y0 w200 h100 vtextMouseColourTip
Gui, Setup:         +AlwaysOnTop -Border -Caption +LastFound +ToolWindow
Gui, Setup:Color  , 000001
WinSet, TransColor, 000001
Gui, Setup:Show   , x0 y0

global isShown := false
SetTimer, updateSetupWindow, 8
SetTimer, getWindowPosition, 1000


getWindowPosition:
    win := GetWindowDimensions("Minecraft")
return

updateSetupWindow:
    MouseGetPos, mouseX, mouseY
    shouldShow := WinActive("Minecraft") && ( (mouseX >= win.x1 && mouseX <= win.x2) && (mouseY >= win.y1 && mouseY <= win.y2) )
    if (!shouldShow && isShown){
        Gui, Setup:Hide
        isShown := false
    } else if (shouldShow && !isShown){
        Gui, Setup:Maximize
        isShown := true
    }

    Gosub, updateTextMouseTip
return

updateTextMouseTip:
    btnName := IDENTIFIERS[currentID] ? IDENTIFIERS[currentID] : "WorldCreation"
    if (currentID == IDENTIFIERS.MaxIndex()+1)
        btnName := "Seed"
    PixelGetColor, atMouseRawColour, mouseX, mouseY, RGB
    switch atMouseRawColour ;hover colour to unhover colour
    {
        case 0x218306: atMouseColour := 0xC6C6C6
        case 0x43A01C: atMouseColour := 0xC6C6C6
        case 0x177400: atMouseColour := 0x979797
        case 0x025F00: atMouseColour := 0x404040
        case 0x037300: atMouseColour := 0x7F7F7F
        case 0xFFFFFF: atMouseColour := 0x4C4C4C
        case 0x4E8836: atMouseColour := 0x808080
        case 0xB1B2B5: atMouseColour := 0xD0D1D4
        case 0x2A641C: atMouseColour := 0x3C8527
        default: atMouseColour := atMouseRawColour
    }

    GuiControl, Setup:Move, textMouseToolTip  , % "x" mouseX+10 "y" mouseY
    GuiControl, Setup:Move, textMouseColourTip, % "x" mouseX+145 "y" mouseY+75
    Gui       , Setup:Font, % "s" 25 " q4" " c" atMouseColour, Mojangles
    GuiControl, Setup:Font, textMouseColourTip
    currentType := !clickData[currentID] && IDENTIFIERS[currentID] ? "Identifier" : "Button"
    GuiControl, Setup:    , textMouseToolTip, % "X:" Floor(mouseX-win.x1) " Y:" Floor(mouseY-win.y1) "`n" currentType ": " btnName "`nColour: "
    GuiControl, Setup:    , textMouseColourTip, % atMouseColour . (atMouseColour != atMouseRawColour ? "*" : "")
return


GetWindowDimensions(Window) {
    WinGet, style, Style, %Window%
    if (isFullscreen := !(style & 0x20800000))
        return {}

    WinGetPos, winX, winY, winWidth, winHeight, %Window%
    if (isMaximised := style & 0x1000000)
        winY := 0, winHeight -= SM_CYFRAME

    return { x1    : winX + SM_CXFRAME
           , y1    : winY + SM_CYFRAME + SM_CYCAPTION
           , x2    : winX + winWidth  - SM_CXFRAME
           , y2    : winY + winHeight - SM_CYFRAME
           , width : winWidth  - SM_CXFRAME*2
           , height: winHeight - SM_CYFRAME*2 - SM_CYCAPTION}
}

AssignButton() {
    if (IDENTIFIERS[currentID] == "Heart" || IDENTIFIERS[currentID] == "WorldCreation") {
        clickData[currentID] := IDENTIFIERS[currentID] ",,," Floor(mouseX-win.x1) "," Floor(mouseY-win.y1) "," atMouseColour
        currentID++
    } else if (currentID <= IDENTIFIERS.count()) {
        if (!clickData[currentID])
            clickData[currentID] := Floor(mouseX-win.x1) "," Floor(mouseY-win.y1) "," atMouseColour
        else {
            clickData[currentID] := IDENTIFIERS[currentID] "," Floor(mouseX-win.x1) "," Floor(mouseY-win.y1) "," clickData[currentID]
            currentID++
            click
        }
    } else {
        if (currentID == IDENTIFIERS.MaxIndex()+1) ; first world creation click is seed
            clickData[currentID] := "WorldCreation," Floor(mouseX-win.x1) "," Floor(mouseY-win.y1) ",,,,Seed"
        else
            clickData[currentID] := "WorldCreation," Floor(mouseX-win.x1) "," Floor(mouseY-win.y1) "," atMouseColour
        currentID++
        click
    }
}

FinishSetup() {
    if (currentID <= IDENTIFIERS.MaxIndex()+1) {
        MsgBox % "Incomplete setup`nExiting without saving..."
        ExitApp
    }

    metaData := "#" CLICK_DATA_VERSION "," layoutDimensions "," mcVersion "," workAreaWidth "," workAreaHeight "," A_ScreenDPI "`n"

    FileRead, fileClickData, clicks.txt
    for k, click in clickData
        clickDataString .= click "`n"
    clickDataString := metaData . clickDataString

    fileClickDataLines := StrSplit(fileClickData, "`n")
    start := ""
    allClickData := []
    for k, line in fileClickDataLines {
        if !line
            continue

        if (SubStr(line, 1, 1) == "#") {
            if start
                allClickData.push(start)
            start := line "`n"
            continue
        }

        if start
            start .= line "`n"
    }
    if start
        allClickData.push(start)

    updateExisting := false
    for k, data in allClickData {
        meta1 := RegExReplace(data, "^#\d+,") ; remove version for comparison
        meta2 := RegExReplace(metaData, "^#\d+,")
        if (meta1 == meta2)
            allClickData[k] := clickDataString, updateExisting := true, break
    }
    if !updateExisting
        allClickData.push(clickDataString)

    allClickDataString := ""
    for k, data in allClickData
        allClickDataString .= data "`n"
    txt := FileOpen("clicks.txt", "w")
    txt.write(allClickDataString)
    txt.close()

    setupDataValue := StrReplace(layoutDimensions, ",", "x") ", " mcVersion
    IniWrite, %setupDataValue%, configs.ini, Other, setupData

    if WinExist("Multi-Resets")
        Run, %A_WorkingDir%/../Multi-Resets.ahk
    ExitApp
}

+Esc::FinishSetup()

#If WinActive("Minecraft")
    Tab::AssignButton()