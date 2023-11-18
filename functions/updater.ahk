FetchUpdates()
{
    if (!DllCall("Wininet.dll\InternetGetConnectedState", "Str", 0x40, "Int", 0))
        return 0

    req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    req.Open("GET", "https://pastebin.com/raw/cXy1hnQa", true) ; latest version
    req.Send()
    req.WaitForResponse()
    latestVersions := StrSplit(req.ResponseText, ",")

    if (SCRIPT_VERSION < latestVersions[1])
    {
        MsgBox, 4, Update?, % "New Update Available!`n" SCRIPT_VERSION " => " latestVersions[1] "`n`nDo you want to update?"
        IfMsgBox, Yes
            DownloadLatest(latestVersions)
    }

    return latestVersions
}

DownloadLatest(latestVersions)
{
    scriptMainDir := RegExReplace(A_ScriptDir, "\\[^\\]*$", "")
    tempFolder := A_ScriptDir "\temp"
    RegExMatch(latestVersions[2], "Multi-Resets\.v[0-9]+\.[0-9]+(\.[0-9]+)?\.zip", newVersionZipName)
    FileCreateDir, %tempFolder%
    UrlDownloadToFile, % latestVersions[2], %tempFolder%\%newVersionZipName%
    if (ErrorLevel || !FileExist(tempFolder "\" newVersionZipName))
    {
        FileRemoveDir, %tempFolder%, 1
        MsgBox, Update Failed!
        return
    }
    sh := ComObjCreate("Shell.Application")
    sh.Namespace(tempFolder).CopyHere(sh.Namespace(tempFolder "\" newVersionZipName).items, 4|16 )
    FileDelete, %tempFolder%\%newVersionZipName%
    newVersionFolderName := StrReplace(RTrim(newVersionZipName, ".zip"), ".", A_Space,, 1)

    MergeConfigs("configs", tempFolder "\" newVersionFolderName "\configs")
    FileMoveDir, %tempFolder%\%newVersionFolderName%, %scriptMainDir%, 1
    FileRemoveDir, %A_ScriptDir%, 1

    MsgBox, Update Complete!
    Run, %scriptMainDir%\%newVersionFolderName%
    ExitApp
}

MergeConfigs(source, destination)
{
    newIniFile := destination "\configs.ini"
    IniWrite, %resetKey%     , %newIniFile%, Hotkeys, Reset
    IniWrite, %stopresetKey% , %newIniFile%, Hotkeys, StopReset
    IniWrite, %restartKey%   , %newIniFile%, Hotkeys, Restart
    IniWrite, %starttimerKey%, %newIniFile%, Hotkeys, StartTimer
    IniWrite, %stoptimerKey% , %newIniFile%, Hotkeys, StopTimer
    IniWrite, %resettimerKey%, %newIniFile%, Hotkeys, ResetTimer
    
    IniWrite, %resetMode%       , %newIniFile%, Macro, resetMode
    IniWrite, %maxCoords%       , %newIniFile%, Macro, maxCoords
    IniWrite, %minCoords%       , %newIniFile%, Macro, minCoords
    IniWrite, %originDistance%  , %newIniFile%, Macro, originDistance
    IniWrite, %autoRestart%     , %newIniFile%, Macro, autoRestart
    IniWrite, %resetThreshold%  , %newIniFile%, Macro, resetThreshold
    IniWrite, %keyDelay%        , %newIniFile%, Macro, keyDelay
    IniWrite, %numInstances%    , %newIniFile%, Macro, numInstances
    IniWrite, %layoutDimensions%, %newIniFile%, Macro, layoutDimensions

    IniWrite, %timerActivated%, %newIniFile%, Timer, timerActive
    IniWrite, %tAnchor%       , %newIniFile%, Timer, anchor
    IniWrite, %tOffsetX%      , %newIniFile%, Timer, offsetX
    IniWrite, %tOffsetY%      , %newIniFile%, Timer, offsetY
    IniWrite, %tFont%         , %newIniFile%, Timer, font
    IniWrite, %tFontSize%     , %newIniFile%, Timer, fontSize
    IniWrite, %tFontColour1%  , %newIniFile%, Timer, fontColour1
    IniWrite, %tFontColour2%  , %newIniFile%, Timer, fontColour2
    IniWrite, %tGradientAngle%, %newIniFile%, Timer, gradientAngle
    IniWrite, %tAnimationType%, %newIniFile%, Timer, animationType
    IniWrite, %tOutlineWidth% , %newIniFile%, Timer, outlineWidth
    IniWrite, %tOutlineColour%, %newIniFile%, Timer, outlineColour
    IniWrite, %tDecimalPlaces%, %newIniFile%, Timer, decimalPlaces
    IniWrite, %tRefreshRate%  , %newIniFile%, Timer, refreshRate
    IniWrite, %tAutoSplit%    , %newIniFile%, Timer, autoSplit
    IniWrite, %tPreview%      , %newIniFile%, Timer, preview

    IniWrite, %threadsUsage%    , %newIniFile%, Other, threadsUsage
    IniWrite, %readScreenMemory%, %newIniFile%, Other, readScreenMemory
    IniWrite, %resetMethod%     , %newIniFile%, Other, resetMethod
    IniWrite, %coopMode%        , %newIniFile%, Other, coopMode
    IniWrite, %hideOnMinimise%  , %newIniFile%, Other, hideOnMinimise

    FileCopy, %source%\attempts.txt, %destination%, 1
    FileCopy, %source%\clicks.txt, %destination%, 1
}