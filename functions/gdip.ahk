;==============================================================
; GDI+ Wrapper
; https://github.com/marius-sucan/AHK-GDIp-Library-Compilation
;==============================================================

Gdip_Startup(multipleInstances:=0) {
    pToken := 0
    If (multipleInstances=0)
    {
        if !DllCall("GetModuleHandle", "str", "gdiplus", "UPtr")
            DllCall("LoadLibrary", "str", "gdiplus")
    } Else DllCall("LoadLibrary", "str", "gdiplus")

    VarSetCapacity(si, A_PtrSize = 8 ? 24 : 16, 0), si := Chr(1)
    DllCall("gdiplus\GdiplusStartup", "UPtr*", pToken, "UPtr", &si, "UPtr", 0)
    return pToken
}

CreateCompatibleDC(hdc:=0) {
    return DllCall("CreateCompatibleDC", "UPtr", hdc)
}

GetDC(hwnd:=0) {
    return DllCall("GetDC", "UPtr", hwnd)
}

ReleaseDC(hdc, hwnd:=0) {
    return DllCall("ReleaseDC", "UPtr", hwnd, "UPtr", hdc)
}

CreateDIBSection(w, h, hdc:="", bpp:=32, ByRef ppvBits:=0, Usage:=0, hSection:=0, Offset:=0) {
    hdc2 := hdc ? hdc : GetDC()
    VarSetCapacity(bi, 40, 0)
    NumPut(40, bi, 0, "uint")
    NumPut(w, bi, 4, "uint")
    NumPut(h, bi, 8, "uint")
    NumPut(1, bi, 12, "ushort")
    NumPut(bpp, bi, 14, "ushort")
    NumPut(0, bi, 16, "uInt")

    hbm := DllCall("CreateDIBSection"
                , "UPtr", hdc2
                , "UPtr", &bi    ; BITMAPINFO
                , "UInt", Usage
                , "UPtr*", ppvBits
                , "UPtr", hSection
                , "UInt", OffSet, "UPtr")

    if !hdc
        ReleaseDC(hdc2)
    return hbm
}

SelectObject(hdc, hgdiobj) {
    return DllCall("SelectObject", "UPtr", hdc, "UPtr", hgdiobj)
}

Gdip_FontFamilyCreate(FontName) {
    hFontFamily := 0
    gdipLastError := DllCall("gdiplus\GdipCreateFontFamilyFromName"
                , "WStr", FontName, "uint", 0, "UPtr*", hFontFamily)
 
    Return hFontFamily
}

 Gdip_FontCreate(hFontFamily, Size, Style:=0, Unit:=0) {
    ; Font style options:
    ; Regular = 0
    ; Bold = 1
    ; Italic = 2
    ; BoldItalic = 3
    ; Underline = 4
    ; Strikeout = 8
    ; Unit options: see Gdip_SetPageUnit()
    hFont := 0
    gdipLastError := DllCall("gdiplus\GdipCreateFont", "UPtr", hFontFamily, "float", Size, "int", Style, "int", Unit, "UPtr*", hFont)
    Return hFont
}

Gdip_StringFormatCreate(FormatFlags:=0, LangID:=0) {
    ; Format options [StringFormatFlags]
    ; DirectionRightToLeft    = 0x00000001
    ; - Activates is right to left reading order. For horizontal text, characters are read from right to left. For vertical text, columns are read from right to left.
    ; DirectionVertical       = 0x00000002
    ; - Individual lines of text are drawn vertically on the display device.
    ; NoFitBlackBox           = 0x00000004
    ; - Parts of characters are allowed to overhang the string's layout rectangle.
    ; DisplayFormatControl    = 0x00000020
    ; - Unicode layout control characters are displayed with a representative character.
    ; NoFontFallback          = 0x00000400
    ; - Prevent using an alternate font  for characters that are not supported in the requested font.
    ; MeasureTrailingSpaces   = 0x00000800
    ; - The spaces at the end of each line are included in a string measurement.
    ; NoWrap                  = 0x00001000
    ; - Disable text wrapping
    ; LineLimit               = 0x00002000
    ; - Only entire lines are laid out in the layout rectangle.
    ; NoClip                  = 0x00004000
    ; - Characters overhanging the layout rectangle and text extending outside the layout rectangle are allowed to show.
    
    hStringFormat := 0
    gdipLastError := DllCall("gdiplus\GdipCreateStringFormat", "int", FormatFlags, "int", LangID, "UPtr*", hStringFormat)
    return hStringFormat
}
 
Gdip_CreateLinearGrBrush(x1, y1, x2, y2, ARGB1, ARGB2, WrapMode:=1) {
    ; Linear gradient brush.
    ; WrapMode specifies how the pattern is repeated once it exceeds the defined space
    ; Tile [no flipping] = 0
    ; TileFlipX = 1
    ; TileFlipY = 2
    ; TileFlipXY = 3
    ; Clamp [no tiling] = 4
    CreatePointF(PointF1, x1, y1)
    CreatePointF(PointF2, x2, y2)
    pLinearGradientBrush := 0
    gdipLastError := DllCall("gdiplus\GdipCreateLineBrush", "UPtr", &PointF1, "UPtr", &PointF2, "Uint", ARGB1, "Uint", ARGB2, "int", WrapMode, "UPtr*", pLinearGradientBrush)
    return pLinearGradientBrush
}   

Gdip_GetLinearGrBrushRect(pLinearGradientBrush) {
    VarSetCapacity(RectF, 16, 0)
    E := DllCall("gdiplus\GdipGetLineRect", "UPtr", pLinearGradientBrush, "UPtr", &RectF)
    If !E
       Return RetrieveRectF(RectF)
    Else
       Return E
}

Gdip_RotateLinearGrBrushAtCenter(pLinearGradientBrush, Angle, MatrixOrder:=1) {
    Rect := Gdip_GetLinearGrBrushRect(pLinearGradientBrush) ; boundaries
    cX := Rect.x + (Rect.w / 2)
    cY := Rect.y + (Rect.h / 2)
    pMatrix := Gdip_CreateMatrix()
    Gdip_TranslateMatrix(pMatrix, -cX , -cY)
    Gdip_RotateMatrix(pMatrix, Angle, MatrixOrder)
    Gdip_TranslateMatrix(pMatrix, cX, cY, MatrixOrder)
    E := Gdip_SetLinearGrBrushTransform(pLinearGradientBrush, pMatrix)
    Gdip_DeleteMatrix(pMatrix)
    Return E
}

CreatePointF(ByRef PointF, x, y, dtype:="float", ds:=4) {
    VarSetCapacity(PointF, ds*2, 0)
    NumPut(x, PointF, 0, dtype)
    NumPut(y, PointF, ds, dtype)
}

CreateRectF(ByRef RectF, x, y, w, h, dtype:="float", ds:=4) {
    VarSetCapacity(RectF, ds*4, 0)
    NumPut(x, RectF, 0,    dtype), NumPut(y, RectF, ds,   dtype)
    NumPut(w, RectF, ds*2, dtype), NumPut(h, RectF, ds*3, dtype)
}

RetrieveRectF(ByRef RectF, dtype:="float", ds:=4) {
    rData := {}
    rData.x := NumGet(&RectF, 0, dtype)
    rData.y := NumGet(&RectF, ds, dtype)
    rData.w := NumGet(&RectF, ds*2, dtype)
    rData.h := NumGet(&RectF, ds*3, dtype)
    return rData
}

Gdip_CreateMatrix(mXel:=0) {
    ; if an object with six elements is provided as a parameter to this function
    ; Gdip_CreateAffineMatrix() is called
    ; function returns a Transformation Matrix
 
    if (IsObject(mXel) && mXel.Count()=6)
       return Gdip_CreateAffineMatrix(mXel[1], mXel[2], mXel[3], mXel[4], mXel[5], mXel[6])
 
    hMatrix := 0
    gdipLastError := DllCall("gdiplus\GdipCreateMatrix", "UPtr*", hMatrix)
    return hMatrix
}

Gdip_CreateAffineMatrix(m11, m12, m21, m22, dx, dy) {
    hMatrix := 0
    gdipLastError := DllCall("gdiplus\GdipCreateMatrix2", "float", m11, "float", m12, "float", m21, "float", m22, "float", dx, "float", dy, "UPtr*", hMatrix)
    return hMatrix
}

Gdip_TranslateMatrix(hMatrix, offsetX, offsetY, MatrixOrder:=0) {
    return DllCall("gdiplus\GdipTranslateMatrix", "UPtr", hMatrix, "float", offsetX, "float", offsetY, "Int", MatrixOrder)
}

Gdip_RotateMatrix(hMatrix, Angle, MatrixOrder:=0) {
    return DllCall("gdiplus\GdipRotateMatrix", "UPtr", hMatrix, "float", Angle, "Int", MatrixOrder)
}

Gdip_SetLinearGrBrushTransform(pLinearGradientBrush, pMatrix) {
    return DllCall("gdiplus\GdipSetLineTransform", "UPtr", pLinearGradientBrush, "UPtr", pMatrix)
}

Gdip_DeleteMatrix(hMatrix) {
    If (hMatrix!="")
       return DllCall("gdiplus\GdipDeleteMatrix", "UPtr", hMatrix)
}

Gdip_GraphicsFromHDC(hDC, hDevice:="", SmoothingMode:="") {
    pGraphics := 0
    If hDevice
       gdipLastError := DllCall("Gdiplus\GdipCreateFromHDC2", "UPtr", hDC, "UPtr", hDevice, "UPtr*", pGraphics)
    Else
       gdipLastError := DllCall("gdiplus\GdipCreateFromHDC", "UPtr", hdc, "UPtr*", pGraphics)
 
    If (gdipLastError=1 && A_LastError=8) ; out of memory
       gdipLastError := 3
 
    If (pGraphics!="" && !gdipLastError)
    {
       If (SmoothingMode!="")
          Gdip_SetSmoothingMode(pGraphics, SmoothingMode)
    }
 
    return pGraphics
}

Gdip_SetSmoothingMode(pGraphics, SmoothingMode) {
    ; SmoothingMode options:
    ; Default = 0
    ; HighSpeed = 1
    ; HighQuality = 2
    ; None = 3
    ; AntiAlias = 4
    ; AntiAlias8x4 = 5
    ; AntiAlias8x8 = 6
    If !pGraphics
        Return 2

    Return DllCall("gdiplus\GdipSetSmoothingMode", "UPtr", pGraphics, "int", SmoothingMode)
}

Gdip_SetTextRenderingHint(pGraphics, RenderingHint) {
    ; RenderingHint options:
    ; SystemDefault = 0
    ; SingleBitPerPixelGridFit = 1
    ; SingleBitPerPixel = 2
    ; AntiAliasGridFit = 3
    ; AntiAlias = 4
    If !pGraphics
        Return 2

    Return DllCall("gdiplus\GdipSetTextRenderingHint", "UPtr", pGraphics, "int", RenderingHint)
}

Gdip_GraphicsClear(pGraphics, ARGB:=0x00ffffff) {
    If (pGraphics="")
       return 2
 
    return DllCall("gdiplus\GdipGraphicsClear", "UPtr", pGraphics, "int", ARGB)
}

Gdip_DrawString(pGraphics, sString, hFont, hStringFormat, pBrush, ByRef RectF) {
    return DllCall("gdiplus\GdipDrawString"
                , "UPtr", pGraphics
                , "WStr", sString
                , "int", -1
                , "UPtr", hFont
                , "UPtr", &RectF
                , "UPtr", hStringFormat
                , "UPtr", pBrush)
}

Gdip_MeasureString(pGraphics, sString, hFont, hStringFormat, ByRef RectF) {
    ; The function returns a string in the following format:
    ; "x|y|width|height|chars|lines"
    ; The first four elements represent the boundaries of the text
    
    VarSetCapacity(RC, 16, 0)
    Chars := 0, Lines := 0
    gdipLastError := DllCall("gdiplus\GdipMeasureString"
                , "UPtr", pGraphics
                , "WStr", sString
                , "int", -1
                , "UPtr", hFont
                , "UPtr", &RectF
                , "UPtr", hStringFormat
                , "UPtr", &RC
                , "uint*", Chars
                , "uint*", Lines)

    r := &RC ? NumGet(RC, 0, "float") "|" NumGet(RC, 4, "float") "|" NumGet(RC, 8, "float") "|" NumGet(RC, 12, "float") "|" Chars "|" Lines : 0
    RC := ""
    return r
}

UpdateLayeredWindow(hwnd, hdcSrc, x:="", y:="", w:="", h:="", Alpha:=255) {
    if (x!="" && y!="")
       CreatePointF(pt, x, y, "uint")
 
    if (w="" || h="")
       GetWindowRect(hwnd, W, H)
 
    return DllCall("UpdateLayeredWindow"
                , "UPtr", hwnd
                , "UPtr", 0
                , "UPtr", ((x = "") && (y = "")) ? 0 : &pt
                , "int64*", w|h<<32
                , "UPtr", hdcSrc
                , "Int64*", 0
                , "UInt", 0
                , "UInt*", Alpha<<16|1<<24
                , "UInt", 2)
}

GetWindowRect(hwnd, ByRef W, ByRef H) {
    If !hwnd
       Return
 
    size := VarSetCapacity(rect, 16, 0)
    er := DllCall("dwmapi\DwmGetWindowAttribute"
       , "UPtr", hWnd  ; HWND  hwnd
       , "UInt", 9     ; DWORD dwAttribute (DWMWA_EXTENDED_FRAME_BOUNDS)
       , "UPtr", &rect ; PVOID pvAttribute
       , "UInt", size  ; DWORD cbAttribute
       , "UInt")       ; HRESULT
 
    If er
       DllCall("GetWindowRect", "UPtr", hwnd, "UPtr", &rect, "UInt")
 
    r := []
    r.x1 := NumGet(rect, 0, "Int"), r.y1 := NumGet(rect, 4, "Int")
    r.x2 := NumGet(rect, 8, "Int"), r.y2 := NumGet(rect, 12, "Int")
    r.w := Abs(max(r.x1, r.x2) - min(r.x1, r.x2))
    r.h := Abs(max(r.y1, r.y2) - min(r.y1, r.y2))
    W := r.w
    H := r.h
    Return r
}

DeleteObject(hObject) {
    return DllCall("DeleteObject", "UPtr", hObject)
}

Gdip_DeleteFont(hFont) {
    If (hFont!="")
       return DllCall("gdiplus\GdipDeleteFont", "UPtr", hFont)
}

Gdip_DeleteStringFormat(hStringFormat) {
    return DllCall("gdiplus\GdipDeleteStringFormat", "UPtr", hStringFormat)
}

DeleteDC(hdc) {
    return DllCall("DeleteDC", "UPtr", hdc)
}

Gdip_DeleteGraphics(pGraphics) {
    If (pGraphics!="")
       return DllCall("gdiplus\GdipDeleteGraphics", "UPtr", pGraphics)
}

Gdip_DeleteBrush(pBrush) {
    If (pBrush!="")
       return DllCall("gdiplus\GdipDeleteBrush", "UPtr", pBrush)
}

Gdip_Shutdown(pToken) {
    DllCall("gdiplus\GdiplusShutdown", "UPtr", pToken)
    hModule := DllCall("GetModuleHandle", "Str", "gdiplus", "UPtr")
    if hModule
       DllCall("FreeLibrary", "UPtr", hModule)
    return 0
}

Gdip_TextToGraphics(pGraphics, Text, Options, Font="Arial", Width="", Height="", Measure=0){
	IWidth := Width, IHeight:= Height
	
	RegExMatch(Options, "i)X([\-\d\.]+)(p*)", xpos)
	RegExMatch(Options, "i)Y([\-\d\.]+)(p*)", ypos)
	RegExMatch(Options, "i)W([\-\d\.]+)(p*)", Width)
	RegExMatch(Options, "i)H([\-\d\.]+)(p*)", Height)
	RegExMatch(Options, "i)OC([a-f\d]+)", OutlineColour)
	RegExMatch(Options, "i)OW([\d\.]+)", OutlineWidth)
	RegExMatch(Options, "i)OF(0|1)", OutlineUseFill)
	RegExMatch(Options, "i)C(?!(entre|enter))([a-f\d]+)", Colour)
	RegExMatch(Options, "i)Top|Up|Bottom|Down|vCentre|vCenter", vPos)
	RegExMatch(Options, "i)NoWrap", NoWrap)
	RegExMatch(Options, "i)R(\d)", Rendering)
	RegExMatch(Options, "i)S(\d+)(p*)", Size)

	if !Gdip_DeleteBrush(Gdip_CloneBrush(Colour2))
		PassBrush := 1, pBrush := Colour2
	
	if !(IWidth && IHeight) && (xpos2 || ypos2 || Width2 || Height2 || Size2)
		return -1

	Style := 0, Styles := "Regular|Bold|Italic|BoldItalic|Underline|Strikeout"
	Loop, Parse, Styles, |
	{
		if RegExMatch(Options, "\b" A_loopField)
		Style |= (A_LoopField != "StrikeOut") ? (A_Index-1) : 8
	}
  
	Align := 0, Alignments := "Near|Left|Centre|Center|Far|Right"
	Loop, Parse, Alignments, |
	{
		if RegExMatch(Options, "\b" A_loopField)
			Align |= A_Index//2.1      ; 0|0|1|1|2|2
	}

	xpos := (xpos1 != "") ? xpos2 ? IWidth*(xpos1/100) : xpos1 : 0
	ypos := (ypos1 != "") ? ypos2 ? IHeight*(ypos1/100) : ypos1 : 0
	Width := Width1 ? Width2 ? IWidth*(Width1/100) : Width1 : IWidth
	Height := Height1 ? Height2 ? IHeight*(Height1/100) : Height1 : IHeight
	if !PassBrush
		Colour := "0x" (Colour2 ? Colour2 : "ff000000")
	Rendering := ((Rendering1 >= 0) && (Rendering1 <= 5)) ? Rendering1 : 4
	Size := (Size1 > 0) ? Size2 ? IHeight*(Size1/100) : Size1 : 12

	hFamily := Gdip_FontFamilyCreate(Font)
	hFont := Gdip_FontCreate(hFamily, Size, Style)
	FormatStyle := NoWrap ? 0x4000 | 0x1000 : 0x4000
	hFormat := Gdip_StringFormatCreate(FormatStyle)
	pBrush := PassBrush ? pBrush : Gdip_BrushCreateSolid(Colour)
	if !(hFamily && hFont && hFormat && pBrush && pGraphics)
		return !pGraphics ? -2 : !hFamily ? -3 : !hFont ? -4 : !hFormat ? -5 : !pBrush ? -6 : 0
   
	CreateRectF(RC, xpos, ypos, Width, Height)
	Gdip_SetStringFormatAlign(hFormat, Align)
	Gdip_SetTextRenderingHint(pGraphics, Rendering)
	ReturnRC := Gdip_MeasureString(pGraphics, Text, hFont, hFormat, RC)

	if vPos
	{
		StringSplit, ReturnRC, ReturnRC, |
		
		if (vPos = "vCentre") || (vPos = "vCenter")
			ypos += (Height-ReturnRC4)//2
		else if (vPos = "Top") || (vPos = "Up")
			ypos := 0
		else if (vPos = "Bottom") || (vPos = "Down")
			ypos := Height-ReturnRC4
		
		CreateRectF(RC, xpos, ypos, Width, ReturnRC4)
		ReturnRC := Gdip_MeasureString(pGraphics, Text, hFont, hFormat, RC)
	}

	if(!Measure){
		if(OutlineWidth1){
			; With antialiasing turned on the path and the text do not line up perfectly, shifting the path slightly up and left will improve it slightly
			; The offset is caused by the differences in the way text and paths rendered/antialiased, so the OF option will draw the text using FillPath instead of DrawText
			; Because the outline and the fill are both drawn using the path the outline will match the text better
			if(!OutlineUseFill1){
				RC_x := NumGet(RC, 0, "float")
				RC_y := NumGet(RC, 4, "float")
				NumPut(RC_x - 1, RC, 0, "float")
				NumPut(RC_y - 0.5, RC, 4, "float")
			}
			
			; Create a path to draw the outline with
			OutlineColour := "0x" (OutlineColour1 ? OutlineColour1 : "ff000000")
			pOutlinePath := Gdip_CreatePath(1)
			pOutlinePen := Gdip_CreatePen(OutlineColour, OutlineWidth1)
			Gdip_AddPathString(pOutlinePath, Text, hFamily, Style, Size, RC, hFormat)
			Gdip_DrawPath(pGraphics, pOutlinePen, pOutlinePath)
			
			if(!OutlineUseFill1){
				NumPut(RC_x, RC, 0, "float") ; Reset RC x and y
				NumPut(RC_y, RC, 4, "float")
				E := Gdip_DrawString(pGraphics, Text, hFont, hFormat, pBrush, RC)
			}
			else{
				E := Gdip_FillPath(pGraphics, pBrush, pOutlinePath)
			}
			
			Gdip_DeletePath(pOutlinePath)
			Gdip_DeletePen(pOutlinePen)
		}
		else
			E := Gdip_DrawString(pGraphics, Text, hFont, hFormat, pBrush, RC)
	}

	if !PassBrush
		Gdip_DeleteBrush(pBrush)
	Gdip_DeleteStringFormat(hFormat)   
	Gdip_DeleteFont(hFont)
	Gdip_DeleteFontFamily(hFamily)
	return E ? E : ReturnRC
}

Gdip_AddPathString(Path, sString, FontFamily, Style, Size, ByRef RectF, Format){
	Ptr := A_PtrSize ? "UPtr" : "UInt"
	
	if (!A_IsUnicode)
	{
		nSize := DllCall("MultiByteToWideChar", "uint", 0, "uint", 0, Ptr, &sString, "int", -1, Ptr, 0, "int", 0)
		VarSetCapacity(wString, nSize*2)
		DllCall("MultiByteToWideChar", "uint", 0, "uint", 0, Ptr, &sString, "int", -1, Ptr, &wString, "int", nSize)
	}
	
	return DllCall("gdiplus\GdipAddPathString"
					, Ptr, Path
					, Ptr, A_IsUnicode ? &sString : &wString
					, "int", -1
					, Ptr, FontFamily
					, "int", Style
					, "float", Size
					, Ptr, &RectF
					, Ptr, Format)
}

Gdip_GetPathWorldBounds(Path){
	Ptr := A_PtrSize ? "UPtr" : "UInt"
	VarSetCapacity(RectF, 16)
	DllCall("gdiplus\GdipGetPathWorldBounds", Ptr, Path, Ptr, &RectF)
	
	return &RectF ? NumGet(RectF, 0, "float") "|" NumGet(RectF, 4, "float") "|" NumGet(RectF, 8, "float") "|" NumGet(RectF, 12, "float") : 0
}

Gdip_GetPathPoints(Path){
	Ptr := A_PtrSize ? "UPtr" : "UInt"
	PointCount := Gdip_GetPointCount(Path)
	if(PointCount = 0)
		return "Count: " 0
	VarSetCapacity(Points, PointCount * 8)
	DllCall("gdiplus\GdipGetPathPoints", Ptr, Path, Ptr, &Points, "Int", PointCount)
	Offset = 0
	Loop %PointCount%{
		if(A_Index > 5)
			break
		Offset += 8
	}
	;~ return PointCount
	return "Count: " . PointCount
}

Gdip_GetPointCount(Path){
	VarSetCapacity(PointCount, 8)
	DllCall("gdiplus\GdipGetPointCount", A_PtrSize ? "UPtr" : "UInt", Path, "Int*", PointCount)
	return PointCount
}

Gdip_DrawPath(pGraphics, pPen, pPath){
	Ptr := A_PtrSize ? "UPtr" : "UInt"
	return DllCall("gdiplus\GdipDrawPath", Ptr, pGraphics, Ptr, pPen, Ptr, pPath)
}

Gdip_AddPathBeziers(pPath, Points) {
	StringSplit, Points, Points, |
	VarSetCapacity(PointF, 8*Points0)   
	Loop, %Points0%
	{
		StringSplit, Coord, Points%A_Index%, `,
		NumPut(Coord1, PointF, 8*(A_Index-1), "float"), NumPut(Coord2, PointF, (8*(A_Index-1))+4, "float")
	}
	return DllCall("gdiplus\GdipAddPathBeziers", "uint", pPath, "uint", &PointF, "int", Points0)
}

Gdip_AddPathBezier(pPath, x1, y1, x2, y2, x3, y3, x4, y4) {	; Adds a B�zier spline to the current figure of this path
	return DllCall("gdiplus\GdipAddPathBezier", "uint", pPath
	, "float", x1, "float", y1, "float", x2, "float", y2
	, "float", x3, "float", y3, "float", x4, "float", y4)
}

Gdip_AddPathLines(pPath, Points) {
	StringSplit, Points, Points, |
	VarSetCapacity(PointF, 8*Points0)   
	Loop, %Points0%
	{
		StringSplit, Coord, Points%A_Index%, `,
		NumPut(Coord1, PointF, 8*(A_Index-1), "float"), NumPut(Coord2, PointF, (8*(A_Index-1))+4, "float")
	}
	return DllCall("gdiplus\GdipAddPathLine2", "uint", pPath, "uint", &PointF, "int", Points0)
}

Gdip_AddPathLine(pPath, x1, y1, x2, y2) {
	return DllCall("gdiplus\GdipAddPathLine", "uint", pPath
	, "float", x1, "float", y1, "float", x2, "float", y2)
}

Gdip_AddPathArc(pPath, x, y, w, h, StartAngle, SweepAngle) {
	return DllCall("gdiplus\GdipAddPathArc", "uint", pPath, "float", x, "float", y, "float", w, "float", h, "float", StartAngle, "float", SweepAngle)
}

Gdip_AddPathPie(pPath, x, y, w, h, StartAngle, SweepAngle) {
	return DllCall("gdiplus\GdipAddPathPie", "uint", pPath, "float", x, "float", y, "float", w, "float", h, "float", StartAngle, "float", SweepAngle)
}

Gdip_StartPathFigure(pPath) {	; Starts a new figure without closing the current figure. Subsequent points added to this path are added to the new figure.
	return DllCall("gdiplus\GdipStartPathFigure", "uint", pPath)
}

Gdip_ClosePathFigure(pPath) {	; Closes the current figure of this path.
	return DllCall("gdiplus\GdipClosePathFigure", "uint", pPath)
}

Gdip_WidenPath(pPath, pPen, Matrix=0, Flatness=1) {	; Replaces this path with curves that enclose the area that is filled when this path is drawn by a specified pen. This method also flattens the path.
	return DllCall("gdiplus\GdipWidenPath", "uint", pPath, "uint", pPen, "uint", Matrix, "float", Flatness)
}

Gdip_ClonePath(pPath) {
	DllCall("gdiplus\GdipClonePath", "uint", pPath, "uint*", pPathClone)
	return pPathClone
}

Gdip_CloneBrush(pBrush) {
    pBrushClone := 0
    gdipLastError := DllCall("gdiplus\GdipCloneBrush", "UPtr", pBrush, "UPtr*", pBrushClone)
    return pBrushClone
}

Gdip_BrushCreateSolid(ARGB:=0xff000000) {
    pBrush := 0
    E := DllCall("gdiplus\GdipCreateSolidFill", "UInt", ARGB, "UPtr*", pBrush)
    return pBrush
}

Gdip_SetStringFormatAlign(hStringFormat, Align, LineAlign:="") {
    ; Text alignments:
    ; 0 - [Near / Left] Alignment is towards the origin of the bounding rectangle
    ; 1 - [Center] Alignment is centered between origin and extent (width) of the formatting rectangle
    ; 2 - [Far / Right] Alignment is to the far extent (right side) of the formatting rectangle
    If (LineAlign!="")
        Gdip_SetStringFormatLineAlign(hStringFormat, LineAlign)
    return DllCall("gdiplus\GdipSetStringFormatAlign", "UPtr", hStringFormat, "int", Align)
}


Gdip_SetStringFormatLineAlign(hStringFormat, StringAlign) {
    ; The line alignment setting specifies how to align the string vertically in the layout rectangle.
    ; The layout rectangle is used to position the displayed string
    ; StringAlign  - Type of vertical line alignment to use:
    ; 0 - Top
    ; 1 - Center
    ; 2 - Bottom
    
    Return DllCall("gdiplus\GdipSetStringFormatLineAlign", "UPtr", hStringFormat, "int", StringAlign)
}

Gdip_CreatePath(fillMode:=0, Points:=0, PointTypes:=0) {
    ; Points: the coordinates of all the points passed as x1,y1|x2,y2|x3,y3..... [minimum three points must be given]; the parameter can also be a flat array object
    ; PointTypes: the point types passed as p1|p2|p3..... [minimum three points must be given]; the parameter can also be a flat array object
          ; Types:
          ;   0x00 - Start of a figure;
          ;   0x01 - Start/end of a straight line;
          ;   0x03 - Bezier control/end point; usually in groups of 3 (C, C, E);
          ;   0x10 - DashMode; undocumented and probably not implemented;
          ;   0x20 - Marker;
          ;   0x80 - Close subpath.
    
    ; FillModes:
    ; Alternate = 0
    ; Winding = 1
    
    pPath := 0
    If !Points
    {
        gdipLastError := DllCall("gdiplus\GdipCreatePath", "int", fillMode, "UPtr*", pPath)
    } Else
    {
        iCount := CreatePointsF(PointsF, Points)
        If !PointTypes
        {
            PointTypes := []
            Loop % iCount
            PointTypes[A_Index] := 1
        }
        yCount := AllocateBinArray(PointsTF, PointTypes, "UChar", 1)
        fCount := min(iCount, yCount)
        gdipLastError := DllCall("gdiplus\GdipCreatePath2", "UPtr", &PointsF, "UPtr", &PointsTF, "Int", fCount, "UInt", fillMode, "UPtr*", pPath)
    }
    return pPath
}

AllocateBinArray(ByRef BinArray, inArray, dtype:="float", ds:=4) {
    ; ds = data size
    ; dtypes and their corresponding ds
      ;    "Int64" : 8, "Char"  : 1
      ; , "UChar"  : 1, "Short" : 2
      ; , "UShort" : 2, "Int"   : 4
      ; , "UInt"   : 4, "Float" : 4
      ; , "Double" : 8, "UPtr"  : A_PtrSize
      ;  , "UPtr"  : A_PtrSize
    ; function inspired by MCL's CreateBinArray()
 
    If IsObject(inArray)
    {
       totals := inArray.Length()
       VarSetCapacity(BinArray, ds * totals, 0)
       Loop %totals%
          NumPut(inArray[A_Index], &BinArray, ds * (A_Index - 1), dtype)
    } Else 
    {
       arrayElements := StrSplit(inArray, "|")
       totals := arrayElements.Length()
       VarSetCapacity(BinArray, ds * totals, 0)
       Loop %totals%
          NumPut(arrayElements[A_Index], &BinArray, ds * (A_Index - 1), dtype)
    }
    Return totals
}

CreatePointsF(ByRef PointsF, inPoints, dtype:="float", ds:=4) {
    If IsObject(inPoints)
    {
       PointsCount := inPoints.Length()
       VarSetCapacity(PointsF, ds * PointsCount, 0)
       Loop % PointsCount
           NumPut(inPoints[A_Index], &PointsF, ds * (A_Index-1), dtype)
       Return PointsCount//2
    } Else 
    {
       dss := ds*2
       Points := StrSplit(inPoints, "|")
       PointsCount := Points.Length()
       VarSetCapacity(PointsF, dss * PointsCount, 0)
       for eachPoint, Point in Points
       {
           Coord := StrSplit(Point, ",")
           NumPut(Coord[1], &PointsF, dss * (A_Index-1), dtype)
           NumPut(Coord[2], &PointsF, (dss * (A_Index-1)) + ds, dtype)
       }
       Return PointsCount
    }
}

Gdip_CreatePen(ARGB, w, Unit:=2) {
    pPen := 0
    gdipLastError := DllCall("gdiplus\GdipCreatePen1", "UInt", ARGB, "float", w, "int", Unit, "UPtr*", pPen)
    return pPen
}

 
Gdip_FillPath(pGraphics, pBrush, pPath) {
    If (!pGraphics || !pBrush || !pPath)
       Return 2
 
    Return DllCall("gdiplus\GdipFillPath", "UPtr", pGraphics, "UPtr", pBrush, "UPtr", pPath)
}

Gdip_DeletePath(pPath) {
    If pPath
       return DllCall("gdiplus\GdipDeletePath", "UPtr", pPath)
}

Gdip_DeletePen(pPen) {
    If (pPen!="")
       return DllCall("gdiplus\GdipDeletePen", "UPtr", pPen)
}

Gdip_DeleteFontFamily(hFontFamily) {
    If (hFontFamily!="")
       return DllCall("gdiplus\GdipDeleteFontFamily", "UPtr", hFontFamily)
}