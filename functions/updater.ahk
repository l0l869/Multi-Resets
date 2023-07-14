checkUpdates()
{
    if(!DllCall("Wininet.dll\InternetGetConnectedState", "Str", 0x40, "Int", 0))
        return 0

    req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    req.Open("GET", "https://pastebin.com/raw/dbABGVM4", true) ; latest version
    req.Send()
    req.WaitForResponse()
    latestVersions := StrSplit(req.ResponseText, ",")

    if (SCRIPT_VERSION < latestVersions[1])
        MsgBox 4, Update,% "New Update Available!`n" . SCRIPT_VERSION . " => " . latestVersions[1] . "`n`nDo you want to update?",,

    IfMsgBox, Yes
        downloadLatest(latestVersions)

    return latestVersions
}

downloadLatest(latestVersions)
{
    scriptMainDir := RegExReplace(A_ScriptDir, "\\[^\\]*$", "")
    tempFolder := A_ScriptDir "\temp"
    RegExMatch(latestVersions[3], "Fastest\.Resets\.v[0-9]+\.[0-9]+\.zip", newVersionZipName)
    FileCreateDir, %tempFolder%
    UrlDownloadToFile % latestVersions[3], %tempFolder%\%newVersionZipName%
    if(ErrorLevel || !FileExist(tempFolder "\" newVersionZipName))
    {
        FileRemoveDir, %tempFolder%, 1
        MsgBox, Update Failed!
        return -1
    }
    sh := ComObjCreate("Shell.Application")
    sh.Namespace( tempFolder ).CopyHere( sh.Namespace( tempFolder . "\" . newVersionZipName ).items, 4|16 )
    FileDelete, %tempFolder%\%newVersionZipName%
    newVersionFolderName := StrReplace(RTrim(newVersionZipName, ".zip"), ".", A_Space,, 2)

    FileCopy, configs\configs.ini, %tempFolder%\%newVersionFolderName%\configs, 1
    FileCopy, configs\attempts.txt, %tempFolder%\%newVersionFolderName%\configs, 1
    FileCopy, configs\seeds.txt, %tempFolder%\%newVersionFolderName%\configs, 1
    FileCopy, configs\logs.txt, %tempFolder%\%newVersionFolderName%\configs, 1
    FileMoveDir, %tempFolder%\%newVersionFolderName%, %scriptMainDir%, 1
    FileRemoveDir, %A_ScriptDir%, 1

    MsgBox, Update Complete!
    Run, %scriptMainDir%\%newVersionFolderName%\Fastest-Resets.ahk
    ExitApp, 1
}