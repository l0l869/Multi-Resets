FetchUpdates()
{
    if(!DllCall("Wininet.dll\InternetGetConnectedState", "Str", 0x40, "Int", 0))
        return 0

    req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    req.Open("GET", "https://pastebin.com/raw/cXy1hnQa", true) ; latest version
    req.Send()
    req.WaitForResponse()
    latestVersions := StrSplit(req.ResponseText, ",")

    if (SCRIPT_VERSION < latestVersions[1])
        MsgBox 4, Update?, % "New Update Available!`n" SCRIPT_VERSION " => " latestVersions[1] "`n`nDo you want to update?"

    IfMsgBox, Yes
        downloadLatest(latestVersions)

    return latestVersions
}

DownloadLatest(latestVersions)
{
    scriptMainDir := RegExReplace(A_ScriptDir, "\\[^\\]*$", "")
    tempFolder := A_ScriptDir "\temp"
    RegExMatch(latestVersions[2], "Multi\-Resets\.v[0-9]+\.[0-9]+\.zip", newVersionZipName)
    FileCreateDir, %tempFolder%
    UrlDownloadToFile % latestVersions[2], %tempFolder%\%newVersionZipName%
    if(ErrorLevel || !FileExist(tempFolder "\" newVersionZipName))
    {
        FileRemoveDir, %tempFolder%, 1
        MsgBox, Update Failed!
        return
    }
    sh := ComObjCreate("Shell.Application")
    sh.Namespace( tempFolder ).CopyHere( sh.Namespace( tempFolder "\" newVersionZipName ).items, 4|16 )
    FileDelete, %tempFolder%\%newVersionZipName%
    newVersionFolderName := StrReplace(RTrim(newVersionZipName, ".zip"), ".", A_Space,, 1)

    MergeConfigs("configs", tempFolder "\" newVersionFolderName "\configs")
    FileMoveDir, %tempFolder%\%newVersionFolderName%, %scriptMainDir%, 1
    FileRemoveDir, %A_ScriptDir%, 1

    MsgBox, Update Complete!
    Run, %scriptMainDir%\%newVersionFolderName%
    ExitApp, 1
}

MergeConfigs(source, destination)
{
    ; may result in unexpected consequences when new options are implemented
    ; FileCopy, %source%\configs.ini, %destination%, 1
    newIniFile := destination "\configs.ini"
    IniWrite, %resetKey%    , %newIniFile%, Hotkeys, Reset
    IniWrite, %stopresetKey%, %newIniFile%, Hotkeys, StopReset
    IniWrite, %restartKey%  , %newIniFile%, Hotkeys, Restart
    
    IniWrite, %maxCoords%       , %newIniFile%, Settings, maxCoords
    IniWrite, %minCoords%       , %newIniFile%, Settings, minCoords
    IniWrite, %autoRestart%     , %newIniFile%, Settings, autoRestart
    IniWrite, %resetThreshold%  , %newIniFile%, Settings, resetThreshold
    IniWrite, %keyDelay%        , %newIniFile%, Settings, keyDelay
    IniWrite, %numInstances%    , %newIniFile%, Settings, numInstances
    IniWrite, %layoutDimensions%, %newIniFile%, Settings, layoutDimensions
    IniWrite, %threadsUsage%    , %newIniFile%, Settings, threadsUsage
    IniWrite, %readScreenMemory%, %newIniFile%, Settings, readScreenMemory

    IniWrite, %timerActivated%    , %newIniFile%, Timer, timerActivated
    IniWrite, %timerAnchor%       , %newIniFile%, Timer, anchor
    IniWrite, %timerOffset%       , %newIniFile%, Timer, offset
    IniWrite, %timerFont%         , %newIniFile%, Timer, font
    IniWrite, %timerSize%         , %newIniFile%, Timer, size
    IniWrite, %timerColour%       , %newIniFile%, Timer, colour
    IniWrite, %timerDecimalPlaces%, %newIniFile%, Timer, decimalPlaces
    IniWrite, %timerRefreshRate%  , %newIniFile%, Timer, refreshRate
    IniWrite, %timerAutoSplit%    , %newIniFile%, Timer, autoSplit

    FileCopy, %source%\attempts.txt, %destination%, 1
    FileCopy, %source%\clicks.txt, %destination%, 1
}