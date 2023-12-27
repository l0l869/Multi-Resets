LoadFile(path, exe:="", exception_level:=-1) {
    exe := """" (exe="" ? A_AhkPath : exe) """"
    exec := ComObjCreate("WScript.Shell")
        .Exec(exe " /ErrorStdOut /include """ A_LineFile """ """ path """")
    exec.StdIn.Close()
    err := exec.StdErr.ReadAll()
    if SubStr(err, 1, 8) = "LRESULT=" {
        hr := DllCall("oleacc\ObjectFromLresult", "ptr", SubStr(err, 9), "ptr", LoadFile.IID, "ptr", 0, "ptr*", pobj:=0)
        if hr >= 0
            return ComObj(9, pobj, 1)
        err := Format("ObjectFromLresult returned failure (0x{:x})", hr & 0xffffffff)
    }
    ex := Exception("Failed to load file", exception_level)
    if RegExMatch(err, "Os)(.*?) \((\d+)\) : ==> (.*?)(?:\s*Specifically: (.*?))?\R?$", m)
        ex.Message .= "`n`nReason:`t" m[3] "`nLine text:`t" m[4] "`nFile:`t" m[1] "`nLine:`t" m[2]
    else
        ex.Message .= "`n`nReason:`t" err
    ; throw ex
}

class LoadFile {
    Init() {
        static IID, _ := LoadFile.Init()
        VarSetCapacity(IID, 16), this.IID := &IID
        NumPut(0x46000000000000c0, NumPut(0x20400, IID, "int64"), "int64")
        if InStr(DllCall("GetCommandLine", "str"), " /include """ A_LineFile """ ")
            this.Serve()
    }
    Serve() {
        stderr := FileOpen("**", "w")
        try {
            proxy := new this.Proxy
            lResult := DllCall("oleacc\LresultFromObject", "ptr", this.IID, "ptr", 0, "ptr", &proxy, "ptr")
            if lResult < 0
                throw Exception(Format("LresultFromObject returned failure (0x{:x})", lResult))
            stderr.Write("LRESULT=" lResult)
            DllCall("CloseHandle", "ptr", stderr := stderr.__Handle)
        }
        catch ex {
            stderr.Write(Format("{} ({}) : ==> {}`n     Specifically: {}"
                                , ex.File, ex.Line, ex.Message, ex.Extra))
            stderr.Close()
            ExitApp
        }
        Hotkey IfWinActive, LoadFile:%A_ScriptHwnd%
        Hotkey vk07, #Persistent, Off
        Hotkey IfWinActive
        #Persistent:
    }
    class Proxy {
        __call(name, args*) {
            if (name != "G")
                return %name%(args*)
        }
        G[name] {
            get {
                global
                return ( %name% )
            }
            set {
                global
                return ( %name% := value )
            }
        }
        __delete() {
            ExitApp
        }
    }
}
