#SingleInstance, Force
SetBatchLines, -1
SetWorkingDir %A_ScriptDir%
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen

global scaleBy := A_ScreenDPI / 96
global currentID := 1
global IDENTIFIERS := ["Play","Heart","SaveAndQuit","CreateNew","CreateNewWorld","WorldCreation"]
global clickData := []
global screenClicks := []
global worldcreationClicks := []
global layoutDimensions, hwnd, win, mouseX, mouseY, atMouseColour, btnName

MsgBox % "Tab: Assign`n" "Shift + Esc: Finish Setup"

SetTitleMatchMode, 3
while WinExist("Minecraft")
    WinClose

Run, shell:AppsFolder\Microsoft.MinecraftUWP_8wekyb3d8bbwe!App
WinWait, Minecraft
hwnd := WinExist("Minecraft")
IniRead, layoutDimensions, configs.ini, Macro, layoutDimensions
dim := StrSplit(layoutDimensions, ",")
height := (A_ScreenHeight-40*scaleBy)/dim[2]
width := A_ScreenWidth/dim[1]
WinMove, % "ahk_id " hwnd,, (A_ScreenWidth-width-8)/2, (A_ScreenHeight-height+16)/2-40, width+16, height+8

global textMouseToolTip, textMouseColourTip, textButtonList
Gui, Setup:Show, % "x0 y0 w" A_ScreenWidth " h" A_ScreenHeight
Gui, Setup:Font, % "s25 cFFFFFF q4", Mojangles
Gui, Setup:Add , Text, x0 y0 w500 h150 vtextMouseToolTip
Gui, Setup:Add , Text, x0 y0 w200 h100 vtextMouseColourTip
Gui, Setup:Add , Text, x0 y0 w550 h300 vtextButtonList
Gui, Setup:         +AlwaysOnTop -Border -Caption +LastFound +ToolWindow
Gui, Setup:Color  , 000001
WinSet, TransColor, 000001
Gui, Setup:Show   , x0 y0

global isShown := false
SetTimer, updateSetupWindow, 8
SetTimer, getWindowPosition, 1000
Gosub, updateTextButtonList


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

    if(mouseX < 600 && mouseY < 350)
        GuiControl, Setup:Move, textButtonList, % "y" A_ScreenHeight-300
    Else
        GuiControl, Setup:Move, textButtonList, % "y" 0
return

updateTextButtonList:
    LoadButtons()
    buttonListString := ""
    for k, btn in screenClicks
    {
        paddingLength := 15-StrLen(btn.btn)
        padding := ""
        loop, %paddingLength%
            padding .= " "
        buttonListString .= btn.btn "" padding ": X:" btn.x " Y:" btn.y " pX:" btn.px " pY:" btn.py " Colour: " btn.colour "`n"
    }
    for k, btn in worldcreationClicks
        buttonListString .=  "WorldCreation" A_index " : X:" btn.x " Y:" btn.y "`n"

    Gui       , Setup:Font, % "s13 cFFFFFF q4", Consolas
    GuiControl, Setup:Font, textButtonList
    GuiControl, Setup:    , textButtonList, % buttonListString
return

GetWindowDimensions(Window)
{
    WinGetPos, winX, winY, winWidth, winHeight, %Window%

    return { x1    : winX + 8  * scaleBy
            ,y1    : winY + 30 * scaleBy
            ,x2    : winX + 8  * scaleBy + winWidth  - 16 * scaleBy
            ,y2    : winY + 30 * scaleBy + winHeight - 38 * scaleBy
            ,width : winWidth  - 16 * scaleBy
            ,height: winHeight - 38 * scaleBy }
}

LoadButtons()
{
    screenClicks := []
    worldcreationClicks := []

    clicksFile := FileOpen("clicks.txt", "r")
    clicksArray := StrSplit(clicksFile.read(), "`n")

    if (SubStr(clicksArray[1], 1, 1) == "#")
        clicksArray.RemoveAt(1)
    else
        return

    for k, click in clicksArray
    {
        clickObj := StrSplit(click,",")
        if !clickObj.count()
            continue

        if (clickObj[6])
            screenClicks.push({btn:clickObj[1], x:clickObj[2], y:clickObj[3], px:clickObj[4], py:clickObj[5], colour:clickObj[6]})
        else
            worldcreationClicks.push({x:clickObj[2], y:clickObj[3]})
    }
    clicksFile.close()
}

AssignButton()
{    
    if (IDENTIFIERS[currentID] == "Heart" || IDENTIFIERS[currentID] == "WorldCreation") {
        clickData[currentID] := IDENTIFIERS[currentID] ",,," Floor(mouseX-win.x1) "," Floor(mouseY-win.y1) "," atMouseColour
        currentID++
    } else if (currentID <= IDENTIFIERS.count()) {
        if (!clickData[currentID])
            clickData[currentID] := Floor(mouseX-win.x1) "," Floor(mouseY-win.y1) "," atMouseColour
        else {
            clickData[currentID] := IDENTIFIERS[currentID] "," Floor(mouseX-win.x1) "," Floor(mouseY-win.y1) "," . clickData[currentID]
            click
            currentID++
        }
    } else {
        clickData[currentID] := "WorldCreation," Floor(mouseX-win.x1) "," Floor(mouseY-win.y1)
        click
        currentID++
    }
}

FinishSetup()
{
    if (clickData.count() <= BUTTON_NAMES.count())
    {
        MsgBox % "Incomplete setup`nExiting without saving..."
        ExitApp
    }

    clickDataString := "#2," layoutDimensions "`n"
    for k, click in clickData
        clickDataString .= click "`n"
    txt := FileOpen("clicks.txt", "w")
    txt.write(clickDataString)
    txt.close()

    if WinExist("Multi-Resets")
        Run, %A_ScriptDir%/../Multi-Resets.ahk
    ExitApp
}

+Esc::FinishSetup()

#If WinActive("Minecraft")
    Tab::AssignButton()