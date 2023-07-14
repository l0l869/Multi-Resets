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

    FileCopy, configs\configs.ini, %tempFolder%\%newVersionFolderName%\configs, 1
    FileCopy, configs\attempts.txt, %tempFolder%\%newVersionFolderName%\configs, 1
    FileCopy, configs\clicks.txt, %tempFolder%\%newVersionFolderName%\configs, 1
    FileMoveDir, %tempFolder%\%newVersionFolderName%, %scriptMainDir%, 1
    FileRemoveDir, %A_ScriptDir%, 1

    MsgBox, Update Complete!
    Run, %scriptMainDir%\%newVersionFolderName%\Multi-Resets.ahk
    ExitApp, 1
}