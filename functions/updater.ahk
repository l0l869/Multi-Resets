global latestFetchedVersion

FetchUpdates() {
    if (!DllCall("Wininet.dll\InternetGetConnectedState", "Str", 0x40, "Int", 0))
        return 0

    req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    req.Open("GET", "https://pastebin.com/raw/cXy1hnQa", true)
    req.Send()
    req.WaitForResponse()
    data := StrSplit(req.ResponseText, "`n")
    latestVersions := StrSplit(data[1], ",")
    changelogArray := StrSplit(data[2], ",")
    RegexMatch(latestVersions[2], "/v([\d.]+)/", versionTag)
    versionTag := StrReplace(versionTag, "/")

    if (SCRIPT_VERSION < latestVersions[1])
    {
        WB.document.getElementById("script-version").textContent := "Current Version: " SCRIPT_VERSION
        WB.document.getElementById("new-script-version").textContent := "New Version: " latestVersions[1]
        WB.document.getElementById("new-tag-version").textContent := "New Tag Version: " versionTag
        WB.document.getElementById("changelog-new-update").textContent := "Changelog " versionTag
        changelog_list := WB.document.getElementById("changes-list")
        currentList := changelog_list, nested := false, nest_list := ""
        for k, change in changelogArray {
            if (SubStr(change, 1, 1) == "-") {
                if (!nested) {
                    nest_list := WB.document.createElement("ul")
                    currentList := nest_list
                }
                change := StrReplace(change, "-", "",, 1)
                nested := true
            } else if (nested) {
                changelog_list.appendChild(nest_list)
                currentList := changelog_list
                nested := false
            }

            change_element := WB.document.createElement("li")
            change_element.textContent := change
            currentList.appendChild(change_element)
        }
        if (nested)
            changelog_list.appendChild(nest_list)

        update_btn := WB.document.getElementById("update-btn")
        update_btn.style.display := "block"
        update_btn.style.opacity := 1
    }

    return latestVersions
}

DownloadLatest(latestVersions) {
    Gui_UpdateProgress(true, 0, "Releasing Objects")
    if (timerPreview) {
        timerPreview.__Delete()
        timerPreview := ""
    }
    SetTimer, %FuncUpdateMainTimer%, Off
    timer1.__Delete()
    timer1 := ""
    DllCall("FreeLibrary", "UPtr", resetDll)
    DllCall("gdi32\RemoveFontResource", "Str", A_ScriptDir "\assets\Mojangles.ttf")

    Gui_UpdateProgress(true, 25, "Downloading")
    scriptMainDir := RegExReplace(A_ScriptDir, "\\[^\\]*$", "")
    tempFolder := A_ScriptDir "\temp"
    RegExMatch(latestVersions[2], "Multi-Resets\.v[0-9]+\.[0-9]+(\.[0-9]+)?\.zip", newVersionZipName)
    FileCreateDir, %tempFolder%
    UrlDownloadToFile, % latestVersions[2], %tempFolder%\%newVersionZipName%
    if (ErrorLevel || !FileExist(tempFolder "\" newVersionZipName)) {
        FileRemoveDir, %tempFolder%, 1
        MsgBox, Update Failed!
        return
    }
    Gui_UpdateProgress(true, 50, "Unzipping")
    sh := ComObjCreate("Shell.Application")
    sh.Namespace(tempFolder).CopyHere(sh.Namespace(tempFolder "\" newVersionZipName).items, 4|16 )
    FileDelete, %tempFolder%\%newVersionZipName%
    newVersionFolderName := StrReplace(RTrim(newVersionZipName, ".zip"), ".", A_Space,, 1)

    Gui_UpdateProgress(true, 75, "Merging Configs")
    MergeConfigs("configs", tempFolder "\" newVersionFolderName "\configs")
    FileMoveDir, %tempFolder%\%newVersionFolderName%, %scriptMainDir%, 1
    FileRemoveDir, %A_ScriptDir%, 1

    Gui_UpdateProgress(true, 100, "Done")
    Run, %scriptMainDir%\%newVersionFolderName%\Multi-Resets.ahk
    ExitApp
}

MergeConfigs(source, destination) {
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
    IniWrite, %switchDelay%     , %newIniFile%, Macro, switchDelay
    IniWrite, %clickDuration%   , %newIniFile%, Macro, clickDuration
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