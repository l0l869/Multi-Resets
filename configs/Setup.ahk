#SingleInstance, Force
SetBatchLines, -1
SetWorkingDir %A_ScriptDir%
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen

global currentButton := 1
global BUTTON_NAMES := ["Heart","SaveAndQuit","CreateNew","CreateNewWorld","World"]
global clickData := []
global screenClicks := []
global worldcreationClicks := []
global hwnd, win, mouseX, mouseY, atMouseColour, btnName

MsgBox % "Tab: Assign Button`n" "Shift + Esc: Finish Setup"

SetTitleMatchMode, 3
while WinExist("Minecraft")
    WinClose

Run, shell:AppsFolder\Microsoft.MinecraftUWP_8wekyb3d8bbwe!App
WinWait, Minecraft
hwnd := WinExist("Minecraft")
IniRead, layoutDimensions, configs.ini, Settings, layoutDimensions
dim := StrSplit(layoutDimensions, ",")
height := (A_ScreenHeight-40*A_ScreenDPI/96)/dim[2]
width := A_ScreenWidth/dim[1]
WinMove, % "ahk_id " hwnd,, (A_ScreenWidth-width-8)/2, (A_ScreenHeight-height+16)/2-40, width+16, height+8

global textMouseToolTip, textMouseColourTip, textButtonList
Gui, Setup:Show, % "x0 y0 w" A_ScreenWidth " h" A_ScreenHeight
Gui, Setup:Font, % "s25 cFFFFFF q4", Mojangles
Gui, Setup:Add , Text, x0 y0 w400 h150 vtextMouseToolTip
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
    btnName := BUTTON_NAMES[currentButton] ? BUTTON_NAMES[currentButton] : "worldcreation"
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
    GuiControl, Setup:    , textMouseToolTip, % "X:" Floor(mouseX-win.x1) " Y:" Floor(mouseY-win.y1) "`nButton: " btnName "`nColour: "
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
        buttonListString .= btn.btn "" padding ": X:" btn.x " Y:" btn.y " Colour: " btn.colour "`n"
    }
    for k, btn in worldcreationClicks
        buttonListString .=  "worldcreation" A_index " : X:" btn.x " Y:" btn.y "`n"

    Gui       , Setup:Font, % "s15 cFFFFFF q4", Consolas
    GuiControl, Setup:Font, textButtonList
    GuiControl, Setup:    , textButtonList, % buttonListString
return

GetWindowDimensions(Window)
{
    WinGetPos, winX, winY, winWidth, winHeight, %Window%

    return { x1    : winX + 8
            ,y1    : winY + 30
            ,x2    : winX + 8 + winWidth - 16
            ,y2    : winY + 30 + winHeight - 38
            ,width : winWidth - 16
            ,height: winHeight - 38 }
}

LoadButtons()
{
    screenClicks := []
    worldcreationClicks := []

    clicksFile := FileOpen("clicks.txt", "r")
    clickList := StrSplit(clicksFile.read(), "`n")
    for k, click in clickList
    {
        objClick := StrSplit(click,",")

        if !objClick.count()
            continue

        if (objClick[4])
            screenClicks.push({btn:objClick[1],x:objClick[2],y:objClick[3],colour:objClick[4]})
        else
            worldcreationClicks.push({x:objClick[2],y:objClick[3]})
    }
    clicksFile.close()
}

AssignButton()
{
    data := BUTTON_NAMES[currentButton] ? BUTTON_NAMES[currentButton] "," mouseX-win.x1 "," mouseY-win.y1 "," atMouseColour : "worldcreation," mouseX-win.x1 "," mouseY-win.y1
    clickData[currentButton] := data
    currentButton += 1
    Click
}

FinishSetup()
{
    if (clickData.count() <= BUTTON_NAMES.count())
    {
        MsgBox % "Incomplete setup`nExiting without saving..."
        ExitApp
    }

    clickDataString := ""
    for k, click in clickData
        clickDataString .= click "`n"
    txt := FileOpen("clicks.txt", "w")
    txt.write(clickDataString)
    txt.close()
    ExitApp
}

+Esc::FinishSetup()

#If WinActive("Minecraft")
    Tab::AssignButton()