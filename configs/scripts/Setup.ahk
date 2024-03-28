; might wanna rewrite this whole thing, however it does the job

#SingleInstance, Force
SetBatchLines, -1
SetWorkingDir, % A_ScriptDir "/../"
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen

global CLICK_DATA_VERSION := 3
global scaleBy := A_ScreenDPI / 96
global currentID := 1
global IDENTIFIERS := ["Play","Heart","SaveAndQuit","CreateNew","CreateNewWorld","WorldCreation"]
global clickData := []
global screenClicks := []
global worldcreationClicks := []
global layoutDimensions, hwnd, workAreaWidth, workAreaHeight, win, mouseX, mouseY, atMouseColour, btnName
global mcVersion

MsgBox % "Tab: Assign`n" "Shift + Esc: Finish Setup"

SetTitleMatchMode, 3
while WinExist("Minecraft")
    WinClose

Run, shell:AppsFolder\Microsoft.MinecraftUWP_8wekyb3d8bbwe!App
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
WinMove, % "ahk_id " hwnd,, (workAreaWidth-width-8)/2, (workAreaHeight-height)/2, width+16, height+8

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
    win := getWindowDimensions("Minecraft")
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
        default: atMouseColour := atMouseRawColour
    }

    GuiControl, Setup:Move, textMouseToolTip  , % "x" mouseX "y" mouseY
    GuiControl, Setup:Move, textMouseColourTip, % "x" mouseX+135 "y" mouseY+75
    Gui       , Setup:Font, % "s" 25 " q4" " c" atMouseColour, Mojangles
    GuiControl, Setup:Font, textMouseColourTip
    currentType := !clickData[currentID] && IDENTIFIERS[currentID] ? "Identifier" : "Button"
    GuiControl, Setup:    , textMouseToolTip, % "X:" Floor(mouseX-win.x1) " Y:" Floor(mouseY-win.y1) "`n" currentType ": " btnName "`nColour: "
    GuiControl, Setup:    , textMouseColourTip, % atMouseColour
return


GetWindowDimensions(Window) {
    WinGetPos, winX, winY, winWidth, winHeight, %Window%
    return { x1    : winX + 8  * scaleBy
            ,y1    : winY + 30 * scaleBy
            ,x2    : winX + 8  * scaleBy + winWidth  - 16 * scaleBy
            ,y2    : winY + 30 * scaleBy + winHeight - 38 * scaleBy
            ,width : winWidth  - 16 * scaleBy
            ,height: winHeight - 38 * scaleBy }
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
            clickData[currentID] := "WorldCreation," Floor(mouseX-win.x1) "," Floor(mouseY-win.y1)
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
    for k, data in allClickData
        if (SubStr(data, 1, StrLen(metaData)) == metaData)
            allClickData[k] := clickDataString, updateExisting := true, break
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