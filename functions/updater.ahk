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

    if (SCRIPT_VERSION < latestVersions[1]) {
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
    SetTimer, %FuncUpdateOverlay%, off
    timer1.__Delete()
    timer1 := ""
    _Overlay.__Delete()
    gameScript := ""
    DllCall("FreeLibrary", "UPtr", resetDll)

    Gui_UpdateProgress(true, 25, "Downloading")
    scriptMainDir := RegExReplace(A_ScriptDir, "\\[^\\]*$", "")
    tempFolder := A_ScriptDir "\temp"
    RegExMatch(latestVersions[2], "Multi-Resets\.v[0-9]+\.[0-9]+(\.[0-9]+)?\.zip", newVersionZipName)
    FileCreateDir, %tempFolder%
    UrlDownloadToFile, % latestVersions[2], %tempFolder%\%newVersionZipName%
    if (ErrorLevel || !FileExist(tempFolder "\" newVersionZipName)) {
        FileRemoveDir, %tempFolder%, 1
        MsgBox, Update Failed!
        Run, Multi-Resets.ahk
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
    ExitApp, 0
}