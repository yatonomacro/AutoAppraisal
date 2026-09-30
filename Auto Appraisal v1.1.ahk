;====================================================================================================;
;
;   Auto Appraisal v1.1
;   Copyright (c) 2026 Yato and Lolzzn. All rights reserved.
;
;   CREDITS
;     Yato and Lolzzn   the macro
;     Descolada         the OCR library for AutoHotkey v2 that reads the appraisal text
;                       (https://github.com/Descolada/OCR)
;     malcev            the original UWP OCR function for AHK v1 that the OCR library is based on
;
;   YOU MAY:
;     - Use this macro for your own personal use.
;
;   YOU MAY NOT, without permission from Yato or Lolzzn:
;     - Edit or modify this code, in whole or in part.
;     - Take, copy or reuse any part of it in another project.
;     - Redistribute this macro, modified or unmodified, in whole or in part.
;     - Present it, or any part of it, as your own work.
;     - Remove, hide or alter these credits or the credits shown in the macro.
;     - Sell it, or put it behind payment, subscription or paid access of any kind.
;
;   PORTIONS FROM OTHER PROJECTS
;     The OCR class at the top of this file is the OCR library for AutoHotkey v2 by Descolada
;     (https://github.com/Descolada/OCR), itself based on the UWP OCR function for AHK v1 by
;     malcev. That portion remains under its own MIT License, reproduced below. The
;     restrictions above apply to Yato's and Lolzzn's original work and cannot and do not
;     override the MIT License for that portion.
;
;       MIT License
;
;       Copyright (c) 2023 Descolada
;
;       Permission is hereby granted, free of charge, to any person obtaining a copy
;       of this software and associated documentation files (the "Software"), to deal
;       in the Software without restriction, including without limitation the rights
;       to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;       copies of the Software, and to permit persons to whom the Software is
;       furnished to do so, subject to the following conditions:
;
;       The above copyright notice and this permission notice shall be included in all
;       copies or substantial portions of the Software.
;
;       THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;       IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;       FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;       AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;       LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;       OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;       SOFTWARE.
;
;   NO WARRANTY
;     Provided "as is", without warranty of any kind. Automating a game may breach its rules.
;     You use this at your own risk, and the authors accept no responsibility for any
;     consequence to your account.
;
;====================================================================================================;

#Requires AutoHotkey v2

/**
 * OCR library: a wrapper for the the UWP Windows.Media.Ocr library.
 * Based on the UWP OCR function for AHK v1 by malcev.
 */
class OCR {
    static IID_IRandomAccessStream := "{905A0FE1-BC53-11DF-8C49-001E4FC686DA}"
         , IID_IPicture            := "{7BF80980-BF32-101A-8BBB-00AA00300CAB}"
         , IID_IAsyncInfo          := "{00000036-0000-0000-C000-000000000046}"
         , IID_IAsyncOperation_OcrResult        := "{c7d7118e-ae36-59c0-ac76-7badee711c8b}"
         , IID_IAsyncOperation_SoftwareBitmap   := "{c4a10980-714b-5501-8da2-dbdacce70f73}"
         , IID_IAsyncOperation_BitmapDecoder    := "{aa94d8e9-caef-53f6-823d-91b6e8340510}"
         , IID_IAsyncOperationCompletedHandler_OcrResult        := "{989c1371-444a-5e7e-b197-9eaaf9d2829a}"
         , IID_IAsyncOperationCompletedHandler_SoftwareBitmap   := "{b699b653-33ed-5e2d-a75f-02bf90e32619}"
         , IID_IAsyncOperationCompletedHandler_BitmapDecoder    := "{bb6514f2-3cfb-566f-82bc-60aabd302d53}"
         , IID_IPdfDocumentStatics := "{433A0B5F-C007-4788-90F2-08143D922599}"
         , Vtbl_GetDecoder := {bmp:6, jpg:7, jpeg:7, png:8, tiff:9, gif:10, jpegxr:11, ico:12}
         , PerformanceMode := 0
         , DisplayImage := 0

    class IBase {
        __New(ptr?) {
            if IsSet(ptr) && !ptr
                throw ValueError('Invalid IUnknown interface pointer', -2, this.__Class)
            this.DefineProp("ptr", {Value:ptr ?? 0})
        }
        __Delete() => this.ptr ? ObjRelease(this.ptr) : 0
    }

    static __New() {
        this.prototype.__OCR := this
        this.IBase.prototype.__OCR := this
        this.OCRLine.base := this.IBase, this.OCRLine.prototype.base := this.IBase.prototype
        this.OCRWord.base := this.IBase, this.OCRWord.prototype.base := this.IBase.prototype
        this.LanguageFactory := this.CreateClass("Windows.Globalization.Language", ILanguageFactory := "{9B0252AC-0C27-44F8-B792-9793FB66C63E}")
        this.SoftwareBitmapFactory := this.CreateClass("Windows.Graphics.Imaging.SoftwareBitmap", "{c99feb69-2d62-4d47-a6b3-4fdb6a07fdf8}")
        this.BitmapTransform := this.CreateClass("Windows.Graphics.Imaging.BitmapTransform")
        this.BitmapDecoderStatics := this.CreateClass("Windows.Graphics.Imaging.BitmapDecoder", IBitmapDecoderStatics := "{438CCB26-BCEF-4E95-BAD6-23A822E58D01}")
        this.BitmapEncoderStatics := this.CreateClass("Windows.Graphics.Imaging.BitmapEncoder", IBitmapDecoderStatics := "{a74356a7-a4e4-4eb9-8e40-564de7e1ccb2}")
        this.SoftwareBitmapStatics := this.CreateClass("Windows.Graphics.Imaging.SoftwareBitmap", ISoftwareBitmapStatics := "{df0385db-672f-4a9d-806e-c2442f343e86}")
        this.OcrEngineStatics := this.CreateClass("Windows.Media.Ocr.OcrEngine", IOcrEngineStatics := "{5BFFA85A-3384-3540-9940-699120D428A8}")
        ComCall(6, this.OcrEngineStatics, "uint*", &MaxImageDimension:=0)
        this.MaxImageDimension := MaxImageDimension
        DllCall("Dwmapi\DwmIsCompositionEnabled", "Int*", &compositionEnabled:=0)
        this.CAPTUREBLT := compositionEnabled ? 0 : 0x40000000
        this.GrayScaleMCode := this.MCode((A_PtrSize = 4) 
        ? "2,x86:VVdWU4PsCIt0JCiLVCQki0QkIMHuAok0JIXSD4SDAAAAhcB0f408tQAAAAAx9ol8JASLfCQcjRyHMf+NdCYAkItEJByNDLiNtCYAAAAAZpCLEYPBBInQD7buwegQae1OAgAAD7bAacAsAQAAAegPtuqB4gAAAP9r7W4B6MHoConFCcLB4AjB5RAJ6gnQiUH8Odl1vIPGAQM8JANcJAQ5dCQkdZyDxAgxwFteX13D" 
        : "2,x64:QVZVV1ZTRInOSYnLQYnSRYnGwe4CRYXAdHJFMclFMcCF0nRoDx9AAESJyg8fRAAAidCDwgFJjQyDizmJ+In7wegQD7bvD7bAae1OAgAAacAsAQAAAehAD7bvgecAAAD/a+1uAejB6AqJxQnHweAIweUQCe8Jx4k5RDnSdbNBg8ABQQHxQQHyRTnGdZwxwFteX11BXsM=")
        this.InvertColorsMCode := this.MCode((A_PtrSize = 4)
        ? "2,x86:VVdWU4PsCIt8JCiLVCQki0QkIMHvAok8JIXSdF+FwHRbwecCMe2JfCQEi3wkHI00hzH/jXQmAJCLRCQcjQyokIsRg8EEidCJ04Hi/wAA//fQ99OA8v8lAAD/AIHjAP8AAAnYCdCJQfw58XXUg8cBAywkA3QkBDl8JCR1vIPECDHAW15fXcM="
        : "2,x64:VVdWU0SJz0iJy0GJ00SJxsHvAkWFwHRbRTHJRTHAhdJ0UWYPH0QAAESJyQ8fRAAAiciDwQFMjRSDQYsSidCJ1YHi/wAA//fQ99WA8v8lAAD/AIHlAP8AAAnoCdBBiQJBOct1zEGDwAFBAflBAftEOcZ1tTHAW15fXcM=")
    }

    __New(RandomAccessStreamOrSoftwareBitmap, lang := "FirstFromAvailableLanguages", transform := 1, decoder := "") {
        local SoftwareBitmap := 0, RandomAccessStream := 0, width, height, x, y, w, h, __OCR := this.__OCR, scale, grayscale, invertcolors
        __OCR.__ExtractTransformParameters(RandomAccessStreamOrSoftwareBitmap, &transform)
        scale := transform.scale, grayscale := transform.grayscale, invertcolors := transform.invertcolors, rotate := transform.rotate, flip := transform.flip
        __OCR.__ExtractNamedParameters(RandomAccessStreamOrSoftwareBitmap, "x", &x, "y", &y, "w", &w, "h", &h, "lang", &lang, "decoder", &decoder, "RandomAccessStream", &RandomAccessStreamOrSoftwareBitmap, "RAS", &RandomAccessStreamOrSoftwareBitmap, "SoftwareBitmap", &RandomAccessStreamOrSoftwareBitmap)
        __OCR.LoadLanguage(lang)

        try SoftwareBitmap := ComObjQuery(RandomAccessStreamOrSoftwareBitmap, "{689e0708-7eef-483f-963f-da938818e073}")
        if SoftwareBitmap {
            ComCall(8, SoftwareBitmap, "uint*", &width:=0)
            ComCall(9, SoftwareBitmap, "uint*", &height:=0)
            this.ImageWidth := width, this.ImageHeight := height
            if (Floor(width*scale) > __OCR.MaxImageDimension) or (Floor(height*scale) > __OCR.MaxImageDimension)
               throw ValueError("Image is too big - " width "x" height ".`nIt should be maximum - " __OCR.MaxImageDimension " pixels (with scale applied)")
            if scale != 1 || IsSet(x) || rotate || flip
                SoftwareBitmap := __OCR.TransformSoftwareBitmap(SoftwareBitmap, &width, &height, scale, rotate, flip, x?, y?, w?, h?)
            goto SoftwareBitmapCommon
        }
        RandomAccessStream := RandomAccessStreamOrSoftwareBitmap

        if decoder {
            ComCall(__OCR.Vtbl_GetDecoder.%decoder%, __OCR.BitmapDecoderStatics, "ptr", DecoderGUID:=Buffer(16))
            ComCall(15, __OCR.BitmapDecoderStatics, "ptr", DecoderGUID, "ptr", RandomAccessStream, "ptr*", BitmapDecoder:=ComValue(13,0))
        } else
            ComCall(14, __OCR.BitmapDecoderStatics, "ptr", RandomAccessStream, "ptr*", BitmapDecoder:=ComValue(13,0))
        __OCR.WaitForAsync(&BitmapDecoder)

        BitmapFrame := ComObjQuery(BitmapDecoder, IBitmapFrame := "{72A49A1C-8081-438D-91BC-94ECFC8185C6}")
        ComCall(12, BitmapFrame, "uint*", &width:=0)
        ComCall(13, BitmapFrame, "uint*", &height:=0)
        if (width > __OCR.MaxImageDimension) or (height > __OCR.MaxImageDimension)
            throw ValueError("Image is too big - " width "x" height ".`nIt should be maximum - " __OCR.MaxImageDimension " pixels")

        BitmapFrameWithSoftwareBitmap := ComObjQuery(BitmapDecoder, IBitmapFrameWithSoftwareBitmap := "{FE287C9A-420C-4963-87AD-691436E08383}")
       if !IsSet(x) && (width < 40 || height < 40 || scale != 1) {
            scale := scale = 1 ? 40.0 / Min(width, height) : scale, this.ImageWidth := Floor(width*scale), this.ImageHeight := Floor(height*scale)
            ComCall(7, __OCR.BitmapTransform, "int", this.ImageWidth)
            ComCall(9, __OCR.BitmapTransform, "int", this.ImageHeight)
            ComCall(8, BitmapFrame, "uint*", &BitmapPixelFormat:=0)
            ComCall(9, BitmapFrame, "uint*", &BitmapAlphaMode:=0)
            ComCall(8, BitmapFrameWithSoftwareBitmap, "uint", BitmapPixelFormat, "uint", BitmapAlphaMode, "ptr", __OCR.BitmapTransform, "uint", IgnoreExifOrientation := 0, "uint", DoNotColorManage := 0, "ptr*", SoftwareBitmap:=ComValue(13,0))
        } else {
            this.ImageWidth := width, this.ImageHeight := height
            ComCall(6, BitmapFrameWithSoftwareBitmap, "ptr*", SoftwareBitmap:=ComValue(13,0))
        }
        __OCR.WaitForAsync(&SoftwareBitmap)
        if IsSet(x) || rotate || flip
            SoftwareBitmap := __OCR.TransformSoftwareBitmap(SoftwareBitmap, &width, &height, scale, rotate, flip, x?, y?, w?, h?)

        SoftwareBitmapCommon:

        if (grayscale || invertcolors || __OCR.DisplayImage) {
            ComCall(15, SoftwareBitmap, "int", 2, "ptr*", BitmapBuffer := ComValue(13,0))
            MemoryBuffer := ComObjQuery(BitmapBuffer, "{fbc4dd2a-245b-11e4-af98-689423260cf8}")
            ComCall(6, MemoryBuffer, "ptr*", MemoryBufferReference := ComValue(13,0))
            BufferByteAccess := ComObjQuery(MemoryBufferReference, "{5b0d3235-4dba-4d44-865e-8f1d0e4fd04d}")
            ComCall(3, BufferByteAccess, "ptr*", &SoftwareBitmapByteBuffer:=0, "uint*", &BufferSize:=0)

            if invertcolors
                DllCall(__OCR.InvertColorsMCode, "ptr", SoftwareBitmapByteBuffer, "uint", width, "uint", height, "uint", (width*4+3) // 4 * 4, "cdecl uint")
            
            if grayscale
                DllCall(__OCR.GrayScaleMCode, "ptr", SoftwareBitmapByteBuffer, "uint", width, "uint", height, "uint", (width*4+3) // 4 * 4, "cdecl uint")
    
            if __OCR.DisplayImage {
                local hdc := DllCall("GetDC", "ptr", 0, "ptr"), bi := Buffer(40, 0), hbm
                NumPut("uint", 40, "int", width, "int", -height, "ushort", 1, "ushort", 32, bi)
                hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &ppvBits:=0, "ptr", 0, "uint", 0, "ptr")
                DllCall("ntdll\memcpy", "ptr", ppvBits, "ptr", SoftwareBitmapByteBuffer, "uint", BufferSize, "cdecl")
                __OCR.DisplayHBitmap(hbm)
            }
            BufferByteAccess := "", MemoryBufferReference := "", MemoryBuffer := "", BitmapBuffer := ""
        }

        ComCall(6, __OCR.OcrEngine, "ptr", SoftwareBitmap, "ptr*", OcrResult:=ComValue(13,0))
        __OCR.WaitForAsync(&OcrResult)
        this.ptr := OcrResult.ptr, ObjAddRef(OcrResult.ptr)

        if RandomAccessStream is __OCR.IBase
            __OCR.CloseIClosable(RandomAccessStream)
        if SoftwareBitmap is __OCR.IBase
            __OCR.CloseIClosable(SoftwareBitmap)

        if scale != 1
            __OCR.NormalizeCoordinates(this, scale)
    }

    __Delete() => this.ptr ? ObjRelease(this.ptr) : 0

    Text {
        get {
            ComCall(8, this, "ptr*", &hAllText:=0)
            buf := DllCall("Combase.dll\WindowsGetStringRawBuffer", "ptr", hAllText, "uint*", &length:=0, "ptr")
            this.DefineProp("Text", {Value:StrGet(buf, "UTF-16")})
            this.__OCR.DeleteHString(hAllText)
            return this.Text
        }
    }

    TextAngle {
        get => (ComCall(7, this, "double*", &value:=0), value)
    }

    Lines {
        get {
            ComCall(6, this, "ptr*", LinesList:=this.__OCR.IBase())
            ComCall(7, LinesList, "int*", &count:=0)
            lines := []
            loop count {
                ComCall(6, LinesList, "int", A_Index-1, "ptr*", OcrLine:=this.__OCR.OCRLine())                
                lines.Push(OcrLine)
            }
            this.DefineProp("Lines", {Value:lines})
            return lines
        }
    }

    Words {
        get {
            local words := [], line, word
            for line in this.Lines
                for word in line.Words
                    words.Push(word)
            this.DefineProp("Words", {Value:words})
            return words
        }
    }

    Click(Obj, WhichButton?, ClickCount?, DownOrUp?) {
        if !obj.HasProp("x") && InStr(Type(obj), "OCR")
            obj := this.__OCR.WordsBoundingRect(obj.Words)
        local x := obj.x, y := obj.y, w := obj.w, h := obj.h, mode := "Screen", hwnd
        if this.HasProp("Relative") {
            if this.Relative.HasOwnProp("Window")
                mode := "Window", hwnd := this.Relative.Window.Hwnd
            else if this.Relative.HasOwnProp("Client")
                mode := "Client", hwnd := this.Relative.Client.Hwnd
            if IsSet(hwnd) && !WinActive(hwnd) {
                WinActivate(hwnd)
                WinWaitActive(hwnd,,1)
            }
            x += this.Relative.%mode%.x, y += this.Relative.%mode%.y
        }
        oldCoordMode := A_CoordModeMouse
        CoordMode "Mouse", mode
        Click(x+w//2, y+h//2, WhichButton?, ClickCount?, DownOrUp?)
        CoordMode "Mouse", oldCoordMode
    }

    ControlClick(obj, WinTitle?, WinText?, WhichButton?, ClickCount?, Options?, ExcludeTitle?, ExcludeText?) {
        if !obj.HasProp("x") && InStr(Type(obj), "OCR")
            obj := this.__OCR.WordsBoundingRect(obj.Words)
        local x := obj.x, y := obj.y, w := obj.w, h := obj.h, hWnd
        if this.HasProp("Relative") && (this.Relative.HasOwnProp("Client") || this.Relative.HasOwnProp("Window")) {
            mode := this.Relative.HasOwnProp("Client") ? "Client" : "Window"
            , obj := this.Relative.%mode%, x += obj.x, y += obj.y, hWnd := obj.hWnd
            if mode = "Window" {
                RECT := Buffer(16, 0), pt := Buffer(8, 0)
                DllCall("user32\GetWindowRect", "Ptr", hWnd, "Ptr", RECT)
                winX := NumGet(RECT, 0, "Int"), winY := NumGet(RECT, 4, "Int")
                NumPut("int", winX+x, "int", winY+y, pt)
                DllCall("user32\ScreenToClient", "Ptr", hWnd, "Ptr", pt)
                x := NumGet(pt,0,"int"), y := NumGet(pt,4,"int")
            }
        } else if IsSet(WinTitle) {
            hWnd := WinExist(WinTitle, WinText?, ExcludeTitle?, ExcludeText?)
            pt := Buffer(8), NumPut("int",x,pt), NumPut("int", y,pt,4)
            DllCall("ScreenToClient", "Int", Hwnd, "Ptr", pt)
            x := NumGet(pt,0,"int"), y := NumGet(pt,4,"int")
        } else
            throw TargetError("ControlClick needs to be called either after a OCR.FromWindow result or with a WinTitle argument")
            
        ControlClick("X" (x+w//2) " Y" (y+h//2), hWnd,, WhichButton?, ClickCount?, Options?)
    }

    Highlight(obj?, showTime?, color:="Red", d:=2) {
        static Guis := Map()
        local x, y, w, h, key, resultObjs, key2, oObj, rect, ResultGuis, GuiObj, iw, ih
        if IsSet(showTime) && showTime = "clearall" {
            for key, resultObjs in Guis {
                for key2, oObj in resultObjs {
                    try oObj.GuiObj.Destroy()
                    SetTimer(oObj.TimerObj, 0)
                }
            }
            Guis := Map()
            return this
        }
        if !Guis.Has(this.ptr)
            Guis[this.ptr] := Map()

        if !IsSet(obj) {
            for key, oObj in Guis[this.ptr] {
                try oObj.GuiObj.Destroy()
                SetTimer(oObj.TimerObj, 0)
            }
            Guis.Delete(this.ptr)
            return this
        }
        if !IsObject(obj)
            throw ValueError("First argument 'obj' must be an object", -1)
        ResultGuis := Guis[this.ptr]

        if (!IsSet(showTime) && ResultGuis.Has(obj)) || (IsSet(showTime) && showTime = "clear") {
                try ResultGuis[obj].GuiObj.Destroy()
                SetTimer(ResultGuis[obj].TimerObj, 0)
                ResultGuis.Delete(obj)
                return this
        } else if !IsSet(showTime)
            showTime := 2000

        if Type(obj) = this.__OCR.prototype.__Class ".OCRLine" || Type(obj) = this.__OCR.prototype.__Class
            rect := this.__OCR.WordsBoundingRect(obj.Words*)
        else 
            rect := obj
        x := rect.x, y := rect.y, w := rect.w, h := rect.h
        if this.HasProp("Relative") {
            if this.Relative.HasOwnProp("Client")
                WinGetClientPos(&rX, &rY,,, this.Relative.Client.hWnd), x += rX + this.Relative.Client.x, y += rY + this.Relative.Client.y
            else if this.Relative.HasOwnProp("Window")
                WinGetPos(&rX, &rY,,, this.Relative.Window.hWnd), x += rX + this.Relative.Window.x, y += rY + this.Relative.Window.y
            else if this.Relative.HasOwnProp("Screen")
                x += this.Relative.Screen.X, y += this.Relative.Screen.Y
        }

        if !ResultGuis.Has(obj) {
            ResultGuis[obj] := {}
            ResultGuis[obj].GuiObj := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")
            ResultGuis[obj].TimerObj := ObjBindMethod(this, "Highlight", obj, "clear")
        }
        GuiObj := ResultGuis[obj].GuiObj
        GuiObj.BackColor := color
        iw:= w+d, ih:= h+d, w:=w+d*2, h:=h+d*2, x:=x-d, y:=y-d
        WinSetRegion("0-0 " w "-0 " w "-" h " 0-" h " 0-0 " d "-" d " " iw "-" d " " iw "-" ih " " d "-" ih " " d "-" d, GuiObj.Hwnd)
        GuiObj.Show("NA x" . x . " y" . y . " w" . w . " h" . h)

        if showTime > 0 {
            Sleep(showTime)
            this.Highlight(obj)
        } else if showTime < 0
            SetTimer(ResultGuis[obj].TimerObj, -Abs(showTime))
        return this
    }
    ClearHighlight(obj) => this.Highlight(obj, "clear")
    static ClearAllHighlights() => this.Prototype.Highlight(,"clearall")

    FindString(needle, i:=1, casesense:=False, wordCompareFunc?, searchArea?) {
        local line, counter, found, x1, y1, x2, y2, splitNeedle, result, word
        if !(needle is String)
            throw TypeError("Needle is required to be a string, not type " Type(needle), -1)
        if needle == ""
            throw ValueError("Needle cannot be an empty string", -1)
        splitNeedle := StrSplit(RegExReplace(needle, " +", " "), " "), needleLen := splitNeedle.Length
        if !IsSet(wordCompareFunc)
            wordCompareFunc := casesense ? ((arg1, arg2) => arg1 == arg2) : ((arg1, arg2) => arg1 = arg2)
        If IsSet(searchArea) {
            x1 := searchArea.HasOwnProp("x1") ? searchArea.x1 : -100000
            y1 := searchArea.HasOwnProp("y1") ? searchArea.y1 : -100000
            x2 := searchArea.HasOwnProp("x2") ? searchArea.x2 : 100000
            y2 := searchArea.HasOwnProp("y2") ? searchArea.y2 : 100000
        }
        for line in this.Lines {
            if IsSet(wordCompareFunc) || InStr(l := line.Text, needle, casesense) {
                counter := 0, found := []
                for word in line.Words {
                    If IsSet(searchArea) && (word.x < x1 || word.y < y1 || word.x+word.w > x2 || word.y+word.h > y2)
                        continue
                    t := word.Text, len := StrLen(t)
                    if wordCompareFunc(t, splitNeedle[found.Length+1]) {
                        found.Push(word)
                        if found.Length == needleLen {
                            if ++counter == i {
                                result := this.__OCR.WordsBoundingRect(found*)
                                result.Words := found
                                return result
                            } else
                                found := []
                        }
                    } else
                        found := []
                }
            }
        }
        throw TargetError('The target string "' needle '" was not found', -1)
    }

    FindStrings(needle, casesense:=False, wordCompareFunc?, searchArea?) {
        local line, counter, found, x1, y1, x2, y2, splitNeedle, result, word
        if !(needle is String)
            throw TypeError("Needle is required to be a string, not type " Type(needle), -1)
        if needle == ""
            throw ValueError("Needle cannot be an empty string", -1)
        splitNeedle := StrSplit(RegExReplace(needle, " +", " "), " "), needleLen := splitNeedle.Length
        if !IsSet(wordCompareFunc)
            wordCompareFunc := casesense ? ((arg1, arg2) => arg1 == arg2) : ((arg1, arg2) => arg1 = arg2)
        If IsSet(searchArea) {
            x1 := searchArea.HasOwnProp("x1") ? searchArea.x1 : -100000
            y1 := searchArea.HasOwnProp("y1") ? searchArea.y1 : -100000
            x2 := searchArea.HasOwnProp("x2") ? searchArea.x2 : 100000
            y2 := searchArea.HasOwnProp("y2") ? searchArea.y2 : 100000
        }
        results := []
        for line in this.Lines {
            if IsSet(wordCompareFunc) || InStr(l := line.Text, needle, casesense) {
                counter := 0, found := []
                for word in line.Words {
                    If IsSet(searchArea) && (word.x < x1 || word.y < y1 || word.x+word.w > x2 || word.y+word.h > y2)
                        continue
                    t := word.Text, len := StrLen(t)
                    if wordCompareFunc(t, splitNeedle[found.Length+1]) {
                        found.Push(word)
                        if found.Length == needleLen {
                            result := this.__OCR.WordsBoundingRect(found*)
                            result.Words := found
                            results.Push(result)
                            counter := 0, found := [], result := unset
                        }
                    } else
                        found := []
                }
            }
        }
        return results
    }

    Filter(callback) {
        if !HasMethod(callback)
            throw ValueError("Filter callback must be a function", -1)
        local result := this.Clone(), line, croppedLines := [], croppedText := "", croppedWords := [], lineText := "", word
        ObjAddRef(result.ptr)
        for line in result.Lines {
            croppedWords := [], lineText := ""
            for word in line.Words {
                if callback(word)
                    croppedWords.Push(word), lineText .= word.Text " "
            }
            if croppedWords.Length {
                line := {Text:Trim(lineText), Words:croppedWords}
                line.base.__Class := this.__OCR.prototype.__Class ".OCRLine"
                croppedLines.Push(line)
                croppedText .= lineText
            }
        }
        result.DefineProp("Lines", {Value:croppedLines})
        result.DefineProp("Text", {Value:Trim(croppedText)})
        result.DefineProp("Words", this.__OCR.Prototype.GetOwnPropDesc("Words"))
        return result
    }

    Crop(x1:=-100000, y1:=-100000, x2:=100000, y2:=100000) => this.Filter((word) => word.x >= x1 && word.y >= y1 && (word.x+word.w) <= x2 && (word.y+word.h) <= y2)

    class OCRLine {
        Text {
            get {
                ComCall(7, this, "ptr*", &hText:=0)
                buf := DllCall("Combase.dll\WindowsGetStringRawBuffer", "ptr", hText, "uint*", &length:=0, "ptr")
                text := StrGet(buf, "UTF-16")
                this.__OCR.DeleteHString(hText)
                this.DefineProp("Text", {Value:text})
                return text
            }
        }

        Words {
            get {
                ComCall(6, this, "ptr*", WordsList:=this.__OCR.IBase())
                ComCall(7, WordsList, "int*", &WordsCount:=0)
                words := []
                loop WordsCount {
                   ComCall(6, WordsList, "int", A_Index-1, "ptr*", OcrWord:=this.__OCR.OCRWord())
                   words.Push(OcrWord)
                }
                this.DefineProp("Words", {Value:words})
                return words
            }
        }

        BoundingRect {
            get => this.DefineProp("BoundingRect", {Value:this.__OCR.WordsBoundingRect(this.Words*)}).BoundingRect
        }
        
        x {
            get => this.BoundingRect.x
        } 
        y {
            get => this.BoundingRect.y
        }
        w {
            get => this.BoundingRect.w
        }
        h {
            get => this.BoundingRect.h
        }
    }

    class OCRWord {
        Text {
            get {
                ComCall(7, this, "ptr*", &hText:=0)
                buf := DllCall("Combase.dll\WindowsGetStringRawBuffer", "ptr", hText, "uint*", &length:=0, "ptr")
                text := StrGet(buf, "UTF-16")
                this.__OCR.DeleteHString(hText)
                this.DefineProp("Text", {Value:text})
                return text
            }
        }

        BoundingRect {
            get {
                ComCall(6, this, "ptr", RECT := Buffer(16, 0))
                this.DefineProp("x", {Value:Integer(NumGet(RECT, 0, "float"))})
                , this.DefineProp("y", {Value:Integer(NumGet(RECT, 4, "float"))})
                , this.DefineProp("w", {Value:Integer(NumGet(RECT, 8, "float"))})
                , this.DefineProp("h", {Value:Integer(NumGet(RECT, 12, "float"))})
                return this.DefineProp("BoundingRect", {Value:{x:this.x, y:this.y, w:this.w, h:this.h}}).BoundingRect
            }
        }
        
        x {
            get => this.BoundingRect.x
        }
        y {
            get => this.BoundingRect.y
        }
        w {
            get => this.BoundingRect.w
        }
        h {
            get => this.BoundingRect.h
        }
    }

    static FromFile(FileName, lang?, transform:=1) {
        this.__ExtractTransformParameters(FileName, &transform)
        this.__ExtractNamedParameters(FileName, "lang", &lang, "FileName", &FileName)
        if !(fe := FileExist(FileName)) or InStr(fe, "D")
            throw TargetError("File `"" FileName "`" doesn't exist", -1)
        GUID := this.CLSIDFromString(this.IID_IRandomAccessStream)
        DllCall("ShCore\CreateRandomAccessStreamOnFile", "wstr", FileName, "uint", Read := 0, "ptr", GUID, "ptr*", IRandomAccessStream:=this.IBase())
        return this(IRandomAccessStream, lang?, transform, this.Vtbl_GetDecoder.HasOwnProp(ext := StrSplit(FileName, ".")[-1]) ? ext : "")
    }

    static FromPDF(FileName, lang?, transform:=1, start:=1, end?) {
        this.__ExtractTransformParameters(FileName, &transform)
        this.__ExtractNamedParameters(FileName, "lang", &lang, "start", &start, "end", &end, "FileName", &FileName)
        if !(fe := FileExist(FileName)) or InStr(fe, "D")
            throw TargetError("File `"" FileName "`" doesn't exist", -1)

        DllCall("ShCore\CreateRandomAccessStreamOnFile", "wstr", FileName, "uint", Read := 0, "ptr", GUID := this.CLSIDFromString(this.IID_IRandomAccessStream), "ptr*", IRandomAccessStream:=ComValue(13,0))
        PdfDocumentStatics := this.CreateClass("Windows.Data.Pdf.PdfDocument", this.IID_IPdfDocumentStatics)
        ComCall(8, PdfDocumentStatics, "ptr", IRandomAccessStream, "ptr*", PdfDocument:=this.IBase())
        this.WaitForAsync(&PdfDocument)
        this.CloseIClosable(IRandomAccessStream)
        if !IsSet(end) {
            ComCall(7, PdfDocument, "uint*", &end:=0)
            if !end
                throw Error("Unable to get PDF page count", -1)
        }
        local results := []
        Loop (end+1-start)
            results.Push(this.FromPDFPage(PdfDocument, start+(A_Index-1), lang?, transform))
        return results
    }

    static FromPDFPage(FileName, page:=1, lang?, transform:=1) {
        this.__ExtractTransformParameters(FileName, &transform)
        this.__ExtractNamedParameters(FileName, "page", page, "lang", &lang, "FileName", &FileName)
        if FileName is String {
            if !(fe := FileExist(FileName)) or InStr(fe, "D")
                throw TargetError("File `"" FileName "`" doesn't exist", -1)
            GUID := OCR.CLSIDFromString(OCR.IID_IRandomAccessStream)
            DllCall("ShCore\CreateRandomAccessStreamOnFile", "wstr", FileName, "uint", Read := 0, "ptr", GUID, "ptr*", IRandomAccessStream:=OCR.IBase())
            PdfDocumentStatics := this.CreateClass("Windows.Data.Pdf.PdfDocument", this.IID_IPdfDocumentStatics)
            ComCall(8, PdfDocumentStatics, "ptr", IRandomAccessStream, "ptr*", PdfDocument:=this.IBase())
            this.WaitForAsync(&PdfDocument)
        } else
            PdfDocument := FileName
        ComCall(6, PdfDocument, "uint", page-1, "ptr*", PdfPage:=this.IBase())
        InMemoryRandomAccessStream := this.CreateClass("Windows.Storage.Streams.InMemoryRandomAccessStream")
        ComCall(6, PdfPage, "ptr", InMemoryRandomAccessStream, "ptr*", asyncInfo:=this.IBase())
        this.WaitForAsync(&asyncInfo)
        if FileName is String
            this.CloseIClosable(IRandomAccessStream)
        PdfPage := "", PdfDocument := "", IRandomAccessStream := ""
        return this(InMemoryRandomAccessStream, lang?, transform)   
    }

    static FromWindow(WinTitle:="", lang?, transform:=1, onlyClientArea:=0, mode:=4) {
        this.__ExtractTransformParameters(WinTitle, &transform)
        local result, X := 0, Y := 0, W := 0, H := 0, sX, sY, hBitMap, hwnd, customRect := 0, scale := transform.scale
        this.__ExtractNamedParameters(WinTitle, "x", &x, "y", &y, "w", &w, "h", &h, "onlyClientArea", &onlyClientArea, "mode", &mode, "lang", &lang, "WinTitle", &Wintitle)
        this.__ExtractNamedParameters(onlyClientArea, "x", &x, "y", &y, "w", &w, "h", &h, "onlyClientArea", &onlyClientArea)
        if (x !=0 || y != 0 || w != 0 || h != 0)
            customRect := 1
        if IsObject(WinTitle)
            WinTitle := ""
        if !(hWnd := WinExist(WinTitle))
            throw TargetError("Target window not found", -1)
        if DllCall("IsIconic", "uptr", hwnd)
            DllCall("ShowWindow", "uptr", hwnd, "int", 4)
        if mode < 4 && mode&1 {
            oldStyle := WinGetExStyle(hwnd), i := 0
            WinSetTransparent(255, hwnd)
            While (WinGetTransparent(hwnd) != 255 && ++i < 30)
                Sleep 100
        }

        WinGetPos(&wX, &wY, &wW, &wH, hWnd)
        If onlyClientArea = 1 {
            WinGetClientPos(&cX, &cY, &cW, &cH, hWnd)
            W := W || cW, H := H || cH, sX := X + cX, sY := Y + cY
        } else {
            W := W || wW, H := H || wH, sX := X + wX, sY := Y + wY
        }

        if mode = 5 {
            SoftwareBitmap := this.CreateDirect3DSoftwareBitmapFromWindow(hWnd)

            local offsetX := 0, offsetY := 0, sbW := SoftwareBitmap.W, sbH := SoftwareBitmap.H, sbX := SoftwareBitmap.X, sbY := SoftwareBitmap.Y

            if scale != 1 || transform.rotate || transform.flip || customRect || onlyClientArea {
                local tX := X, tY := Y, tW := W, tH := H
                if onlyClientArea
                    tX -= SoftwareBitmap.X-cX, tY -= SoftwareBitmap.Y-cY
                else
                    tX -= SoftwareBitmap.X-wX, tY -= SoftwareBitmap.Y-wY
                if tX < 0
                    tW += tX, offsetX := -tX, tX := 0
                if tY < 0
                    tH += tY, offsetY := -tY, tY := 0
                tW := Min(sbW-tX, tW), tH := Min(sbH-tY, tH)

                SoftwareBitmap := this.TransformSoftwareBitmap(SoftwareBitmap, &sbW, &sbH, scale, transform.rotate, transform.flip, tX, tY, tW, tH)
                transform.scale := 1, transform.rotate := 0, transform.flip := 0
            }
            result := this(SoftwareBitmap, lang?, transform)
        } else {
            hBitMap := this.CreateHBitmap(X, Y, W, H, {hWnd:hWnd, onlyClientArea:onlyClientArea, mode:(mode//2)}, scale)
            if mode&1
                WinSetExStyle(oldStyle, hwnd)
            result := this(this.HBitmapToSoftwareBitmap(hBitMap,, transform), lang?)
        }

        result.Relative := {Screen:{X:sX, Y:sY, W:W, H:H}}
        , result.Relative.%(onlyClientArea = 1 ? "Client" : "Window")% := {X:X, Y:Y, W:W, H:H, hWnd:hWnd}
        this.NormalizeCoordinates(result, scale)
        if mode = 5 && !onlyClientArea
            result.OffsetCoordinates(offsetX, offsetY)
        return result
    }

    static FromDesktop(lang?, transform:=1, monitor?) {
        if IsSet(lang) {
            this.__ExtractTransformParameters(lang, &transform)
            lang := lang.HasProp("lang") ? lang : unset
        }
        MonitorGet(monitor?, &Left, &Top, &Right, &Bottom)
        return this.FromRect(Left, Top, Right-Left, Bottom-Top, lang?, transform)
    }

    static FromRect(x, y?, w?, h?, lang?, transform:=1) {
        this.__ExtractTransformParameters(x, &transform)
        this.__ExtractNamedParameters(x, "y", &y, "w", &w, "h", &h, "lang", &lang, "x", &x)
        local scale := transform.scale
            , hBitmap := this.CreateHBitmap(X, Y, W, H,, scale)
            , result := this(this.HBitmapToSoftwareBitmap(hBitmap,, transform), lang?)
        result.Relative := {Screen:{x:x, y:y, w:w, h:h}}
        return this.NormalizeCoordinates(result, scale)
    }

    static FromBitmap(bitmap, lang?, transform:=1, hDC?) {
        this.__ExtractTransformParameters(bitmap, &transform)
        local result, pDC, hBitmap, hBM2, oBM, oBM2, pBitmapInfo := Buffer(32, 0), W, H, scale := transform.scale
        this.__ExtractNamedParameters(bitmap, "hDC", &hDC, "lang", &lang, "hBitmap", &bitmap, "pBitmap", &bitmap, "bitmap", &bitmap)
        if !DllCall("GetObject", "ptr", bitmap, "int", pBitmapInfo.Size, "ptr", pBitmapInfo) {
            DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "UPtr", bitmap, "UPtr*", &hBitmap:=0, "Int", 0xffffffff)
            DllCall("GetObject", "ptr", hBitmap, "int", pBitmapInfo.Size, "ptr", pBitmapInfo)
        } else
            hBitmap := bitmap

        W := NumGet(pBitmapInfo, 4, "int"), H := NumGet(pBitmapInfo, 8, "int")

        if scale != 1 || (W && H && (W < 40 || H < 40)) {
            sW := Ceil(W * scale), sH := Ceil(H * scale)

            hDC := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
            , oBM := DllCall("SelectObject", "Ptr", hDC, "Ptr", hBitmap, "Ptr")
            , pDC := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
            , hBM2 := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", Max(40, sW), "Int", Max(40, sH), "Ptr")
            , oBM2 := DllCall("SelectObject", "Ptr", pDC, "Ptr", hBM2, "Ptr")
            if sW < 40 || sH < 40
                DllCall("StretchBlt", "Ptr", pDC, "Int", 0, "Int", 0, "Int", Max(40,sW), "Int", Max(40,sH), "Ptr", hDC, "Int", 0, "Int", 0, "Int", 1, "Int", 1, "UInt", 0x00CC0020 | this.CAPTUREBLT)
            PrevStretchBltMode := DllCall("SetStretchBltMode", "Ptr", PDC, "Int", 3, "Int")
            , DllCall("StretchBlt", "Ptr", pDC, "Int", 0, "Int", 0, "Int", sW, "Int", sH, "Ptr", hDC, "Int", 0, "Int", 0, "Int", W, "Int", H, "UInt", 0x00CC0020 | this.CAPTUREBLT)
            , DllCall("SetStretchBltMode", "Ptr", PDC, "Int", PrevStretchBltMode)
            , DllCall("SelectObject", "Ptr", pDC, "Ptr", oBM2)
            , DllCall("SelectObject", "Ptr", hDC, "Ptr", oBM)
            , DllCall("DeleteDC", "Ptr", hDC)
            result := this(this.HBitmapToSoftwareBitmap(hBM2, pDC, transform), lang?)
            this.NormalizeCoordinates(result, scale)
            DllCall("DeleteDC", "Ptr", pDC)
            , DllCall("DeleteObject", "UPtr", hBM2)
            return result
        } 
        return this(this.HBitmapToSoftwareBitmap(hBitmap, hDC?, transform), lang?)
    } 

    static GetAvailableLanguages() {
        ComCall(7, this.OcrEngineStatics, "ptr*", &LanguageList := 0)
        ComCall(7, LanguageList, "int*", &count := 0)
        Loop count {
            ComCall(6, LanguageList, "int", A_Index - 1, "ptr*", &Language := 0)
            ComCall(6, Language, "ptr*", &hText := 0)
            buf := DllCall("Combase.dll\WindowsGetStringRawBuffer", "ptr", hText, "uint*", &length := 0, "ptr")
            text .= StrGet(buf, "UTF-16") "`n"
            this.DeleteHString(hText)
            ObjRelease(Language)
        }
        ObjRelease(LanguageList)
        return text
    }

    static LoadLanguage(lang:="FirstFromAvailableLanguages") {
        local hString, Language:=this.IBase(), OcrEngine:=this.IBase()
        if this.HasOwnProp("CurrentLanguage") && this.HasOwnProp("OcrEngine") && this.CurrentLanguage = lang
            return
        if (lang = "FirstFromAvailableLanguages")
            ComCall(10, this.OcrEngineStatics, "ptr*", OcrEngine)
        else {
            hString := this.CreateHString(lang)
            , ComCall(6, this.LanguageFactory, "ptr", hString, "ptr*", Language)
            , this.DeleteHString(hString)
            , ComCall(9, this.OcrEngineStatics, "ptr", Language, "ptr*", OcrEngine)
        }
        if (OcrEngine.ptr = 0) {
            msgbox((lang = "FirstFromAvailableLanguages") ? "Failed to use FirstFromAvailableLanguages for OCR:`nmake sure the primary language pack has OCR capabilities installed.`n`nAlternatively try `"en-us`" as the language." : "Can not use language `"" lang "`" for OCR, please install language pack.", "OCR Error", "0x40030")
            OcrInstallationGuide := msgbox("Do you want to try and install language pack?`n`nPressing `"Yes`" will run powershell on admin", "Confirmation", "0x40044")
            if (OcrInstallationGuide == "No") {
                exitapp
            }
            run "ms-settings:regionlanguage"
            msgbox("Press something that says `"Add Language`", It's usually a button with blue background`n`nPress `"Ok`" to Continue", "Guide", "0x40040")
            msgbox("Search for `"English (United States)`" at the searchbar.`n`nPress `"Ok`" to Continue", "Guide", "0x40040")
            msgbox("Press `"Next`", Enable all of them and then click install`n`nPress `"Ok`" to Continue", "Guide", "0x40040")
            msgbox("That should be all, wait for the download to finish and run the macro again.", "Guide", "0x40040")
            exitapp
        }
        this.OcrEngine := OcrEngine, this.CurrentLanguage := lang
    }

    static WordsBoundingRect(words*) {
        if !words.Length
            throw ValueError("This function requires at least one argument")
        local X1 := 100000000, Y1 := 100000000, X2 := -100000000, Y2 := -100000000, word
        for word in words {
            X1 := Min(word.x, X1), Y1 := Min(word.y, Y1), X2 := Max(word.x+word.w, X2), Y2 := Max(word.y+word.h, Y2)
        }
        return {X:X1, Y:Y1, W:X2-X1, H:Y2-Y1, X2:X2, Y2:Y2}
    }
    
    static WaitText(needle, timeout:=-1, func?, casesense:=False, comparefunc?) {
        local endTime := A_TickCount+timeout, result, line, total
        if !IsSet(func)
            func := this.FromDesktop
        if !IsSet(comparefunc)
            comparefunc := InStr.Bind(,,casesense)
        While timeout > 0 ? (A_TickCount < endTime) : 1 {
            result := func(), total := ""
            for line in result.Lines
                total .= line.Text "`n"
            if comparefunc(Trim(total, "`n"), needle)
                return result
        }
        return
    }

    static Cluster(objs, eps_x:=-1, eps_y:=-1, minPts:=1, compareFunc?, &noise?) {
        local clusters := [], start := 0, cluster, word
        visited := Map(), clustered := Map(), C := [], c_n := 0, sum := 0, noise := IsSet(noise) && (noise is Array) ? noise : []
        if !IsObject(objs) || !(objs is Array)
            throw ValueError("objs argument must be an Array", -1)
        if !objs.Length
            return []
        if IsSet(compareFunc) && !HasMethod(compareFunc)
            throw ValueError("compareFunc must be a valid function", -1)

        if !IsSet(compareFunc) {
            if (eps_y < 0) {
                for point in objs
                    sum += point.h
                eps_y := (sum // objs.Length) // 2
            }
            compareFunc := (p1, p2) => Abs(p1.y+p1.h//2-p2.y-p2.h//2)<eps_y && (eps_x < 0 || (Abs(p1.x+p1.w-p2.x)<eps_x || Abs(p1.x-p2.x-p2.w)<eps_x))
        }

        for point in objs {
            visited[point] := 1, neighbourPts := [], RegionQuery(point)
            if !clustered.Has(point) {
                C.Push([]), c_n += 1, C[c_n].Push(point), clustered[point] := 1
                ExpandCluster(point)
            }
            if C[c_n].Length < minPts
                noise.Push(C[c_n]), C.RemoveAt(c_n), c_n--
        }

        for cluster in C {
            OCR.SortArray(cluster,,"x")
            br := OCR.WordsBoundingRect(cluster*), br.Words := cluster, br.Text := ""
            for word in cluster
                br.Text .= word.Text " "
            br.Text := RTrim(br.Text)
            clusters.Push(br)
        }
        OCR.SortArray(clusters,,"y")
        return clusters

        ExpandCluster(P) {
            local point
            for point in neighbourPts {
                if !visited.Has(point) {
                    visited[point] := 1, RegionQuery(point)
                    if !clustered.Has(point)
                        C[c_n].Push(point), clustered[point] := 1
                }
            }
        }

        RegionQuery(P) {
            local point
            for point in objs
                if !visited.Has(point)
                    if compareFunc(P, point)
                        neighbourPts.Push(point)
        }
    }

    static SortArray(arr, optionsOrCallback:="N", key?) {
        static sizeofFieldType := 16
        if HasMethod(optionsOrCallback)
            pCallback := CallbackCreate(CustomCompare.Bind(optionsOrCallback), "F Cdecl", 2), optionsOrCallback := ""
        else {
            if InStr(optionsOrCallback, "N")
                pCallback := CallbackCreate(IsSet(key) ? NumericCompareKey.Bind(key) : NumericCompare, "F CDecl", 2)
            if RegExMatch(optionsOrCallback, "i)C(?!0)|C1|COn")
                pCallback := CallbackCreate(IsSet(key) ? StringCompareKey.Bind(key,,True) : StringCompare.Bind(,,True), "F CDecl", 2)
            if RegExMatch(optionsOrCallback, "i)C0|COff")
                pCallback := CallbackCreate(IsSet(key) ? StringCompareKey.Bind(key) : StringCompare, "F CDecl", 2)
            if InStr(optionsOrCallback, "Random")
                pCallback := CallbackCreate(RandomCompare, "F CDecl", 2)
            if !IsSet(pCallback)
                throw ValueError("No valid options provided!", -1)
        }
        mFields := NumGet(ObjPtr(arr) + (8 + (VerCompare(A_AhkVersion, "<2.1-") > 0 ? 3 : 5)*A_PtrSize), "Ptr")
        DllCall("msvcrt.dll\qsort", "Ptr", mFields, "UInt", arr.Length, "UInt", sizeofFieldType, "Ptr", pCallback, "Cdecl")
        CallbackFree(pCallback)
        if RegExMatch(optionsOrCallback, "i)R(?!a)")
            this.ReverseArray(arr)
        if InStr(optionsOrCallback, "U")
            arr := this.Unique(arr)
        return arr

        CustomCompare(compareFunc, pFieldType1, pFieldType2) => (ValueFromFieldType(pFieldType1, &fieldValue1), ValueFromFieldType(pFieldType2, &fieldValue2), compareFunc(fieldValue1, fieldValue2))
        NumericCompare(pFieldType1, pFieldType2) => (ValueFromFieldType(pFieldType1, &fieldValue1), ValueFromFieldType(pFieldType2, &fieldValue2), fieldValue1 - fieldValue2)
        NumericCompareKey(key, pFieldType1, pFieldType2) => (ValueFromFieldType(pFieldType1, &fieldValue1), ValueFromFieldType(pFieldType2, &fieldValue2), fieldValue1.%key% - fieldValue2.%key%)
        StringCompare(pFieldType1, pFieldType2, casesense := False) => (ValueFromFieldType(pFieldType1, &fieldValue1), ValueFromFieldType(pFieldType2, &fieldValue2), StrCompare(fieldValue1 "", fieldValue2 "", casesense))
        StringCompareKey(key, pFieldType1, pFieldType2, casesense := False) => (ValueFromFieldType(pFieldType1, &fieldValue1), ValueFromFieldType(pFieldType2, &fieldValue2), StrCompare(fieldValue1.%key% "", fieldValue2.%key% "", casesense))
        RandomCompare(pFieldType1, pFieldType2) => (Random(0, 1) ? 1 : -1)

        ValueFromFieldType(pFieldType, &fieldValue?) {
            static SYM_STRING := 0, PURE_INTEGER := 1, PURE_FLOAT := 2, SYM_MISSING := 3, SYM_OBJECT := 5
            switch SymbolType := NumGet(pFieldType + 8, "Int") {
                case PURE_INTEGER: fieldValue := NumGet(pFieldType, "Int64") 
                case PURE_FLOAT: fieldValue := NumGet(pFieldType, "Double") 
                case SYM_STRING: fieldValue := StrGet(NumGet(pFieldType, "Ptr")+2*A_PtrSize)
                case SYM_OBJECT: fieldValue := ObjFromPtrAddRef(NumGet(pFieldType, "Ptr")) 
                case SYM_MISSING: return        
            }
        }
    }
    static ReverseArray(arr) {
        local len := arr.Length + 1, max := (len // 2), i := 0
        while ++i <= max
            temp := arr[len - i], arr[len - i] := arr[i], arr[i] := temp
        return arr
    }
    static UniqueArray(arr) {
        local unique := Map()
        for v in arr
            unique[v] := 1
        return [unique*]
    }

    static FlattenArray(arr) {
        local r := []
        for v in arr {
            if v is Array
                r.Push(this.FlattenArray(v)*)
            else
                r.Push(v)
        }
        return r
    }

    static TransformSoftwareBitmap(SoftwareBitmap, &sbW, &sbH, scale:=1, rotate:=0, flip:=0, X?, Y?, W?, H?) {
        InMemoryRandomAccessStream := this.SoftwareBitmapToRandomAccessStream(SoftwareBitmap)

        ComCall(this.Vtbl_GetDecoder.png, this.BitmapDecoderStatics, "ptr", DecoderGUID:=Buffer(16))
        ComCall(15, this.BitmapDecoderStatics, "ptr", DecoderGUID, "ptr", InMemoryRandomAccessStream, "ptr*", BitmapDecoder:=ComValue(13,0))
        this.WaitForAsync(&BitmapDecoder)

        BitmapFrameWithSoftwareBitmap := ComObjQuery(BitmapDecoder, IBitmapFrameWithSoftwareBitmap := "{FE287C9A-420C-4963-87AD-691436E08383}")
        BitmapFrame := ComObjQuery(BitmapDecoder, IBitmapFrame := "{72A49A1C-8081-438D-91BC-94ECFC8185C6}")

        BitmapTransform := this.CreateClass("Windows.Graphics.Imaging.BitmapTransform")

        local sW := Floor(sbW*scale), sH := Floor(sbH*scale), intermediate
        if scale != 1 {
            ComCall(7, BitmapTransform, "uint", sW)
            ComCall(9, BitmapTransform, "uint", sH)
        }
        if rotate {
            ComCall(15, BitmapTransform, "uint", rotate//90)
            if rotate = 90 || rotate = 270
                intermediate := sW, sW := sH, sH := intermediate
        }
        if flip
            ComCall(13, BitmapTransform, "uint", flip)

        if IsSet(X) {
            bounds := Buffer(16,0), NumPut("int", Floor(X*scale), "int", Floor(Y*scale), "int", Floor(Min(sbW-X, W)*scale), "int", Floor(Min(sbH-Y, H)*scale), bounds)
            ComCall(17, BitmapTransform, "ptr", bounds)
        }
        ComCall(8, BitmapFrame, "uint*", &BitmapPixelFormat:=0)
        ComCall(9, BitmapFrame, "uint*", &BitmapAlphaMode:=0)
        ComCall(8, BitmapFrameWithSoftwareBitmap, "uint", BitmapPixelFormat, "uint", BitmapAlphaMode, "ptr", BitmapTransform, "uint", IgnoreExifOrientation := 0, "uint", DoNotColorManage := 0, "ptr*", SoftwareBitmap:=ComValue(13,0))

        this.WaitForAsync(&SoftwareBitmap)
        this.CloseIClosable(InMemoryRandomAccessStream)
        sbW := sW, sbH := sH
        return SoftwareBitmap
    }

    static CreateDIBSection(w, h, hdc?, bpp:=32, &ppvBits:=0) {
        local hdc2 := IsSet(hdc) ? hdc : DllCall("GetDC", "Ptr", 0, "UPtr")
        , bi := Buffer(40, 0), hbm
        NumPut("int", 40, "int", w, "int", h, "ushort", 1, "ushort", bpp, "int", 0, bi)
        hbm := DllCall("CreateDIBSection", "uint", hdc2, "ptr" , bi, "uint" , 0, "uint*", &ppvBits:=0, "uint" , 0, "uint" , 0)
        if !IsSet(hdc)
            DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc2)
        return hbm
    }

    static CreateHBitmap(X, Y, W, H, hWnd:=0, scale:=1) {
        local sW := Ceil(W*scale), sH := Ceil(H*scale), onlyClientArea := 0, mode := 2, HDC, obm, hbm, pdc, hbm2
        if hWnd {
            if IsObject(hWnd)
                onlyClientArea := hWnd.HasOwnProp("onlyClientArea") ? hWnd.onlyClientArea : onlyClientArea, mode := hWnd.HasOwnProp("mode") ? hWnd.mode : mode, hWnd := hWnd.hWnd
            HDC := DllCall("GetDCEx", "Ptr", hWnd, "Ptr", 0, "Int", 2|!onlyClientArea, "Ptr")
            if mode > 0 {
                PDC := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
                HBM := DllCall("CreateCompatibleBitmap", "Ptr", HDC, "Int", Max(40,X+W), "Int", Max(40,Y+H), "Ptr")
                , OBM := DllCall("SelectObject", "Ptr", PDC, "Ptr", HBM, "Ptr")
                , DllCall("PrintWindow", "Ptr", hWnd, "Ptr", PDC, "UInt", (mode=2?2:0)|!!onlyClientArea)
                if scale != 1 || X != 0 || Y != 0 {
                    PDC2 := DllCall("CreateCompatibleDC", "Ptr", PDC, "Ptr")
                    , HBM2 := DllCall("CreateCompatibleBitmap", "Ptr", PDC, "Int", Max(40,sW), "Int", Max(40,sH), "Ptr")
                    , OBM2 := DllCall("SelectObject", "Ptr", PDC2, "Ptr", HBM2, "Ptr")
                    , PrevStretchBltMode := DllCall("SetStretchBltMode", "Ptr", PDC, "Int", 3, "Int")
                    , DllCall("StretchBlt", "Ptr", PDC2, "Int", 0, "Int", 0, "Int", sW, "Int", sH, "Ptr", PDC, "Int", X, "Int", Y, "Int", W, "Int", H, "UInt", 0x00CC0020 | this.CAPTUREBLT)
                    , DllCall("SetStretchBltMode", "Ptr", PDC, "Int", PrevStretchBltMode)
                    , DllCall("SelectObject", "Ptr", PDC2, "Ptr", obm2)
                    , DllCall("DeleteDC", "Ptr", PDC)
                    , DllCall("DeleteObject", "UPtr", HBM)
                    , hbm := hbm2, pdc := pdc2
                }
                DllCall("SelectObject", "Ptr", PDC, "Ptr", OBM)
                , DllCall("DeleteDC", "Ptr", HDC)
                , oHBM := this.IBase(HBM), oHBM.DC := PDC
                return oHBM.DefineProp("__Delete", {call:(this, *)=>(DllCall("DeleteObject", "Ptr", this), DllCall("DeleteDC", "Ptr", this.DC))})
            }
        } else {
            HDC := DllCall("GetDC", "Ptr", 0, "Ptr")
        }
        PDC := DllCall("CreateCompatibleDC", "Ptr", HDC, "Ptr")
        , HBM := DllCall("CreateCompatibleBitmap", "Ptr", HDC, "Int", Max(40,sW), "Int", Max(40,sH), "Ptr")
        , OBM := DllCall("SelectObject", "Ptr", PDC, "Ptr", HBM, "Ptr")
        if sW < 40 || sH < 40
            DllCall("StretchBlt", "Ptr", PDC, "Int", 0, "Int", 0, "Int", Max(40,sW), "Int", Max(40,sH), "Ptr", HDC, "Int", X, "Int", Y, "Int", 1, "Int", 1, "UInt", 0x00CC0020 | this.CAPTUREBLT)
        PrevStretchBltMode := DllCall("SetStretchBltMode", "Ptr", PDC, "Int", 3, "Int")
        , DllCall("StretchBlt", "Ptr", PDC, "Int", 0, "Int", 0, "Int", sW, "Int", sH, "Ptr", HDC, "Int", X, "Int", Y, "Int", W, "Int", H, "UInt", 0x00CC0020 | this.CAPTUREBLT)
        , DllCall("SetStretchBltMode", "Ptr", PDC, "Int", PrevStretchBltMode)
        , DllCall("SelectObject", "Ptr", PDC, "Ptr", OBM)
        , DllCall("DeleteDC", "Ptr", HDC)
        , oHBM := this.IBase(HBM), oHBM.DC := PDC
        return oHBM.DefineProp("__Delete", {call:(this, *)=>(DllCall("DeleteObject", "Ptr", this), DllCall("ReleaseDC", "Ptr", 0, "Ptr", this.DC))})
    }

    static CreateDirect3DSoftwareBitmapFromWindow(hWnd) {
        static init := 0, DXGIDevice, Direct3DDevice, Direct3D11CaptureFramePoolStatics, GraphicsCaptureItemInterop, GraphicsCaptureItemGUID, D3D_Device, D3D_Context
        local x, y, w, h, rect
        if !init {
            DllCall("LoadLibrary","str","DXGI")
            DllCall("LoadLibrary","str","D3D11")
            DllCall("LoadLibrary","str","Dwmapi")
            DllCall("D3D11\D3D11CreateDevice", "ptr", 0, "int", D3D_DRIVER_TYPE_HARDWARE := 1, "ptr", 0, "uint", D3D11_CREATE_DEVICE_BGRA_SUPPORT := 0x20, "ptr", 0, "uint", 0, "uint", D3D11_SDK_VERSION := 7, "ptr*", D3D_Device:=ComValue(13, 0), "ptr*", 0, "ptr*", D3D_Context:=ComValue(13, 0))
            DXGIDevice := ComObjQuery(D3D_Device, IID_IDXGIDevice := "{54ec77fa-1377-44e6-8c32-88fd5f44c84c}")
            DllCall("D3D11\CreateDirect3D11DeviceFromDXGIDevice", "ptr", DXGIDevice, "ptr*", GraphicsDevice:=ComValue(13, 0))
            Direct3DDevice := ComObjQuery(GraphicsDevice, IDirect3DDevice := "{A37624AB-8D5F-4650-9D3E-9EAE3D9BC670}")
            Direct3D11CaptureFramePoolStatics := this.CreateClass("Windows.Graphics.Capture.Direct3D11CaptureFramePool", IDirect3D11CaptureFramePoolStatics := "{7784056a-67aa-4d53-ae54-1088d5a8ca21}")
            GraphicsCaptureItemStatics := this.CreateClass("Windows.Graphics.Capture.GraphicsCaptureItem", IGraphicsCaptureItemStatics := "{A87EBEA5-457C-5788-AB47-0CF1D3637E74}")
            GraphicsCaptureItemInterop := ComObjQuery(GraphicsCaptureItemStatics, IGraphicsCaptureItemInterop := "{3628E81B-3CAC-4C60-B7F4-23CE0E0C3356}")
            GraphicsCaptureItemGUID := Buffer(16,0)
            DllCall("ole32\CLSIDFromString", "wstr", IGraphicsCaptureItem := "{79c3f95b-31f7-4ec2-a464-632ef5d30760}", "ptr", GraphicsCaptureItemGUID)
            init := 1
        }

        DllCall("Dwmapi.dll\DwmGetWindowAttribute", "ptr", hWnd, "uint", DWMWA_EXTENDED_FRAME_BOUNDS := 9, "ptr", rect := Buffer(16,0), "uint", 16)
        x := NumGet(rect, 0, "int"), y := NumGet(rect, 4, "int"), w := NumGet(rect, 8, "int") - x, h := NumGet(rect, 12, "int") - y
        ComCall(6, Direct3D11CaptureFramePoolStatics, "ptr", Direct3DDevice, "int", B8G8R8A8UIntNormalized := 87, "int", numberOfBuffers := 2, "int64", (h << 32) | w, "ptr*", Direct3D11CaptureFramePool:=ComValue(13, 0))
        if ComCall(3, GraphicsCaptureItemInterop, "ptr", hWnd, "ptr", GraphicsCaptureItemGUID, "ptr*", GraphicsCaptureItem:=ComValue(13, 0), "uint") {
            this.CloseIClosable(Direct3D11CaptureFramePool)
            throw Error("Failed to capture GraphicsItem of window",, -1)
        }
        ComCall(10, Direct3D11CaptureFramePool, "ptr", GraphicsCaptureItem, "ptr*", GraphicsCaptureSession:=ComValue(13, 0))

        GraphicsCaptureSession2 := ComObjQuery(GraphicsCaptureSession, IGraphicsCaptureSession2 := "{2c39ae40-7d2e-5044-804e-8b6799d4cf9e}")
        ComCall(7, GraphicsCaptureSession2, "int", 0)

        if (Integer(StrSplit(A_OSVersion, ".")[3]) >= 20348) {
            GraphicsCaptureSession3 := ComObjQuery(GraphicsCaptureSession, IGraphicsCaptureSession3 := "{f2cdd966-22ae-5ea1-9596-3a289344c3be}")
            ComCall(7, GraphicsCaptureSession3, "int", 0)
        }
        ComCall(6, GraphicsCaptureSession)
        Loop {
            ComCall(7, Direct3D11CaptureFramePool, "ptr*", Direct3D11CaptureFrame:=ComValue(13, 0))
            if (Direct3D11CaptureFrame.ptr != 0)
                break
        }
        ComCall(6, Direct3D11CaptureFrame, "ptr*", Direct3DSurface:=ComValue(13, 0))

        ComCall(11, this.SoftwareBitmapStatics, "ptr", Direct3DSurface, "ptr*", SoftwareBitmap:=ComValue(13, 0))
        OCR.WaitForAsync(&SoftwareBitmap)

        this.CloseIClosable(Direct3D11CaptureFramePool)
        this.CloseIClosable(GraphicsCaptureSession)
        if GraphicsCaptureSession2 {
            this.CloseIClosable(GraphicsCaptureSession2)
        }
        if IsSet(GraphicsCaptureSession3) {
            this.CloseIClosable(GraphicsCaptureSession3)
        }
        this.CloseIClosable(Direct3D11CaptureFrame)
        this.CloseIClosable(Direct3DSurface)

        SoftwareBitmap.x := x, SoftwareBitmap.y := y, SoftwareBitmap.w := w, SoftwareBitmap.h := h
        return SoftwareBitmap
    }

    static HBitmapToRandomAccessStream(hBitmap) {
        static PICTYPE_BITMAP := 1
             , BSOS_DEFAULT   := 0
             , sz := 8 + A_PtrSize*2
        local PICTDESC, riid, size, pIRandomAccessStream
             
        DllCall("Ole32\CreateStreamOnHGlobal", "Ptr", 0, "UInt", true, "Ptr*", pIStream:=ComValue(13,0), "UInt")
        , PICTDESC := Buffer(sz, 0)
        , NumPut("uint", sz, "uint", PICTYPE_BITMAP, "ptr", IsInteger(hBitmap) ? hBitmap : hBitmap.ptr, PICTDESC)
        , riid := this.CLSIDFromString(this.IID_IPicture)
        , DllCall("OleAut32\OleCreatePictureIndirect", "Ptr", PICTDESC, "Ptr", riid, "UInt", 0, "Ptr*", pIPicture:=ComValue(13,0), "UInt")
        , ComCall(15, pIPicture, "Ptr", pIStream, "UInt", true, "uint*", &size:=0, "UInt")
        , riid := this.CLSIDFromString(this.IID_IRandomAccessStream)
        , DllCall("ShCore\CreateRandomAccessStreamOverStream", "Ptr", pIStream, "UInt", BSOS_DEFAULT, "Ptr", riid, "Ptr*", pIRandomAccessStream:=this.IBase(), "UInt")
        Return pIRandomAccessStream
    }

    static HBitmapToSoftwareBitmap(hBitmap, hDC?, transform?) {
        local bi := Buffer(40, 0), W, H, BitmapBuffer, MemoryBuffer, MemoryBufferReference, BufferByteAccess, BufferSize
        hDC := (hBitmap is OCR.IBase ? hBitmap.DC : (hDC ?? dhDC := DllCall("GetDC", "Ptr", 0, "UPtr")))

        NumPut("uint", 40, bi, 0)
        DllCall("GetDIBits", "ptr", hDC, "ptr", hBitmap, "uint", 0, "uint", 0, "ptr", 0, "ptr", bi, "uint", 0)
        W := NumGet(bi, 4, "int"), H := NumGet(bi, 8, "int")

        ComCall(7, this.SoftwareBitmapFactory, "int", 87, "int", W, "int", H, "int", 0, "ptr*", SoftwareBitmap := ComValue(13,0))
        ComCall(15, SoftwareBitmap, "int", 2, "ptr*", BitmapBuffer := ComValue(13,0))
        MemoryBuffer := ComObjQuery(BitmapBuffer, "{fbc4dd2a-245b-11e4-af98-689423260cf8}")
        ComCall(6, MemoryBuffer, "ptr*", MemoryBufferReference := ComValue(13,0))
        BufferByteAccess := ComObjQuery(MemoryBufferReference, "{5b0d3235-4dba-4d44-865e-8f1d0e4fd04d}")
        ComCall(3, BufferByteAccess, "ptr*", &SoftwareBitmapByteBuffer:=0, "uint*", &BufferSize:=0)

        NumPut("short", 32, "short", 0, bi, 14), NumPut("int", -H, bi, 8)
        DllCall("GetDIBits", "ptr", hDC, "ptr", hBitmap, "uint", 0, "uint", H, "ptr", SoftwareBitmapByteBuffer, "ptr", bi, "uint", 0)
        
        if IsSet(transform) {
            if (transform.HasProp("grayscale") && transform.grayscale)
                DllCall(this.GrayScaleMCode, "ptr", SoftwareBitmapByteBuffer, "uint", w, "uint", h, "uint", (w*4+3) // 4 * 4, "cdecl uint")
            if (transform.HasProp("invertcolors") && transform.invertcolors)
                DllCall(this.InvertColorsMCode, "ptr", SoftwareBitmapByteBuffer, "uint", w, "uint", h, "uint", (w*4+3) // 4 * 4, "cdecl uint")
            
            if (transform.HasProp("threshold") && transform.threshold) {
                local p := SoftwareBitmapByteBuffer
                local pxCount := W * H
                local thresh := transform.threshold
                Loop pxCount {
                    local b := NumGet(p, 0, "UChar")
                    local g := NumGet(p, 1, "UChar")
                    local r := NumGet(p, 2, "UChar")
                    local lum := (r * 77 + g * 150 + b * 29) >> 8
                    local col := (lum >= thresh) ? 0xFFFFFFFF : 0xFF000000
                    NumPut("UInt", col, p)
                    p += 4
                }
            }
        }
        
        if IsSet(dhDC)
            DllCall("DeleteDC", "ptr", dhDC)
        BufferByteAccess := "", MemoryBufferReference := "", MemoryBuffer := "", BitmapBuffer := ""

        return SoftwareBitmap
    }

    static MCode(mcode) {
        static e := Map('1', 4, '2', 1), c := (A_PtrSize=8) ? "x64" : "x86"
        if (!regexmatch(mcode, "^([0-9]+),(" c ":|.*?," c ":)([^,]+)", &m))
          return
        if (!DllCall("crypt32\CryptStringToBinary", "str", m.3, "uint", 0, "uint", e[m.1], "ptr", 0, "uint*", &s := 0, "ptr", 0, "ptr", 0))
          return
        p := DllCall("GlobalAlloc", "uint", 0, "ptr", s, "ptr")
        if (c="x64")
          DllCall("VirtualProtect", "ptr", p, "ptr", s, "uint", 0x40, "uint*", &op := 0)
        if (DllCall("crypt32\CryptStringToBinary", "str", m.3, "uint", 0, "uint", e[m.1], "ptr", p, "uint*", &s, "ptr", 0, "ptr", 0))
          return p
        DllCall("GlobalFree", "ptr", p)
      }

    static DisplayHBitmap(hBitmap) {
        local gImage := Gui("-DPIScale"), W, H
        , hPic := gImage.Add("Text", "0xE w640 h640")
        SendMessage(0x172, 0, hBitmap,, hPic.hWnd)
        hPic.GetPos(,,&W, &H)
        gImage.Show("w" (W+20) " H" (H+20))
        WinWaitClose gImage
    }

    static SoftwareBitmapToRandomAccessStream(SoftwareBitmap) {
        InMemoryRandomAccessStream := this.CreateClass("Windows.Storage.Streams.InMemoryRandomAccessStream")
        ComCall(8, this.BitmapEncoderStatics, "ptr", encoderId := Buffer(16, 0))
        ComCall(13, this.BitmapEncoderStatics, "ptr", encoderId, "ptr", InMemoryRandomAccessStream, "ptr*", BitmapEncoder:=ComValue(13,0))
        this.WaitForAsync(&BitmapEncoder)
        BitmapEncoderWithSoftwareBitmap := ComObjQuery(BitmapEncoder, "{686cd241-4330-4c77-ace4-0334968b1768}")
        ComCall(6, BitmapEncoderWithSoftwareBitmap, "ptr", SoftwareBitmap)
        ComCall(19, BitmapEncoder, "ptr*", asyncAction:=ComValue(13,0))
        this.WaitForAsync(&asyncAction)
        ComCall(11, InMemoryRandomAccessStream, "int64", 0)
        return InMemoryRandomAccessStream
    }

    static CreateClass(str, interface?) {
        local hString := this.CreateHString(str), result
        if !IsSet(interface) {
            result := DllCall("Combase.dll\RoActivateInstance", "ptr", hString, "ptr*", cls:=this.IBase(), "uint")
        } else {
            GUID := this.CLSIDFromString(interface)
            result := DllCall("Combase.dll\RoGetActivationFactory", "ptr", hString, "ptr", GUID, "ptr*", cls:=this.IBase(), "uint")
        }
        if (result != 0) {
            if (result = 0x80004002)
                throw Error("No such interface supported", -1, interface)
            else if (result = 0x80040154)
                throw Error("Class not registered", -1)
            else
                throw Error(result)
        }
        this.DeleteHString(hString)
        return cls
    }
    
    static CreateHString(str) => (DllCall("Combase.dll\WindowsCreateString", "wstr", str, "uint", StrLen(str), "ptr*", &hString:=0), hString)
    
    static DeleteHString(hString) => DllCall("Combase.dll\WindowsDeleteString", "ptr", hString)
    
    static WaitForAsync(&obj) {
        local AsyncInfo := ComObjQuery(obj, this.IID_IAsyncInfo), status, ErrorCode
        Loop {
            ComCall(7, AsyncInfo, "uint*", &status:=0)
            if (status != 0) {
                if (status != 1) {
                    ComCall(8, ASyncInfo, "uint*", &ErrorCode:=0)
                    throw Error("AsyncInfo failed with status error " ErrorCode, -1)
                }
                break
            }
            Sleep this.PerformanceMode ? -1 : 1
        }
        ComCall(8, obj, "ptr*", ObjectResult:=this.IBase())
        obj := ObjectResult
    }

    static CloseIClosable(pClosable) {
        static IClosable := "{30D5A829-7FA4-4026-83BB-D75BAE4EA99E}"
        local Close := ComObjQuery(pClosable, IClosable)
        ComCall(6, Close)
    }

    static CLSIDFromString(IID) {
        local CLSID := Buffer(16), res
        if res := DllCall("ole32\CLSIDFromString", "WStr", IID, "Ptr", CLSID, "UInt")
           throw Error("CLSIDFromString failed. Error: " . Format("{:#x}", res))
        Return CLSID
    }

    static NormalizeCoordinates(result, scale) {
        local word
        if scale != 1 {
            for word in result.Words
                word.x := Integer(word.x / scale), word.y := Integer(word.y / scale), word.w := Integer(word.w / scale), word.h := Integer(word.h / scale), word.BoundingRect := {X:word.x, Y:word.y, W:word.w, H:word.h}
        }
        return result
    }

    static __ExtractNamedParameters(obj, params*) {
        local i := 0
        if !IsObject(obj) || Type(obj) != "Object"
            return 0
        Loop params.Length // 2 {
            name := params[++i], value := params[++i]
            if obj.HasProp(name)
                %value% := obj.%name%
        }
        return 1
    }

    static __ExtractTransformParameters(obj, &transform) {
        local scale := 1, grayscale := 0, invertcolors := 0, rotate := 0, flip := 0
        if IsObject(obj)
            this.__ExtractNamedParameters(obj, "scale", &scale, "grayscale", &grayscale, "invertcolors", &invertcolors, "rotate", &rotate, "flip", &flip, "transform", &transform)

        if IsObject(transform) {
            for prop in ["scale", "grayscale", "invertcolors", "rotate", "flip"]
                if !transform.HasProp(prop)
                    transform.%prop% := %prop%
        } else
            transform := {scale:scale, grayscale:grayscale, invertcolors:invertcolors, rotate:rotate, flip:flip}
    
        transform.flip := transform.flip = "y" ? 1 : transform.flip = "x" ? 2 : transform.flip
    }

    OffsetCoordinates(offsetX?, offsetY?) {
        if !IsSet(offsetX) || !IsSet(offsetY) {
            if this.HasOwnProp("Relative") {
                if this.Relative.HasOwnProp("Client")
                    offsetX := this.Relative.Client.x, offsetY := this.Relative.Client.x
                else if this.Relative.HasOwnProp("Window")
                    offsetX := this.Relative.Window.x, offsetY := this.Relative.Window.y
                else
                    throw Error("No appropriate Relative property found",, -1)
            } else
                throw Error("No Relative property found",, -1)
        }
        if offsetX = 0 && offsetY = 0
            return this
        local word
        for word in this.Words
            word.x += offsetX, word.y += offsetY, word.BoundingRect := {X:word.x, Y:word.y, W:word.w, H:word.h}
        return this
    }

    static ConvertWinPos(X, Y, &outX, &outY, relativeFrom:="", relativeTo:="screen", winTitle?, winText?, excludeTitle?, excludeText?) {
        relativeFrom := relativeFrom || A_CoordModeMouse
        if relativeFrom = relativeTo {
            outX := X, outY := Y
            return
        }
        local hWnd := WinExist(winTitle?, winText?, excludeTitle?, excludeText?)

        switch relativeFrom, 0 {
            case "screen", "s":
                if relativeTo = "window" || relativeTo = "w" {
                    DllCall("user32\GetWindowRect", "Int", hWnd, "Ptr", RECT := Buffer(16))
                    outX := X-NumGet(RECT, 0, "Int"), outY := Y-NumGet(RECT, 4, "Int")
                } else { 
                    pt := Buffer(8), NumPut("int",X,pt), NumPut("int",Y,pt,4)
                    DllCall("ScreenToClient", "Int", hWnd, "Ptr", pt)
                    outX := NumGet(pt,0,"int"), outY := NumGet(pt,4,"int")
                }
            case "window", "w":
                WinGetPos(&outX, &outY,,,hWnd)
                outX += X, outY += Y
                if relativeTo = "client" || relativeTo = "c" {
                    pt := Buffer(8), NumPut("int",outX,pt), NumPut("int",outY,pt,4)
                    DllCall("ScreenToClient", "Int", hWnd, "Ptr", pt)
                    outX := NumGet(pt,0,"int"), outY := NumGet(pt,4,"int")
                }
            case "client", "c":
                pt := Buffer(8), NumPut("int",X,pt), NumPut("int",Y,pt,4)
                DllCall("ClientToScreen", "Int", hWnd, "Ptr", pt)
                outX := NumGet(pt,0,"int"), outY := NumGet(pt,4,"int")
                if relativeTo = "window" || relativeTo = "w" { 
                    DllCall("user32\GetWindowRect", "Int", hWnd, "Ptr", RECT := Buffer(16))
                    outX -= NumGet(RECT, 0, "Int"), outY -= NumGet(RECT, 4, "Int")
                }
        }
    }
}

#warn all, off
#singleinstance force
setkeydelay -1
setmousedelay -1
SetTitleMatchMode 2
CoordMode("Tooltip", "Screen")
CoordMode("Pixel", "Screen")
CoordMode("Mouse", "Screen")
SendMode("Event")
OnMessage("0x201", WM_LBUTTONDOWN)
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd)
{
PostMessage "0xA1", 2
}
ttp(text := "", XPos := "", YPos := "", ToolPos := "1") {
	if !(XPos and YPos) {
		mousegetpos &XPos, &YPos
	}
	tooltip text, XPos, YPos, ToolPos
	hwndList := WinGetList("ahk_class tooltips_class32")
	for hwnd in hwndList {
		DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr", DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr") | 0x80000 | 0x20)
	}
}

; ============================== Settings ==============================
global ResultWaitMs := 3000
global StopOnUnreadable := 1

GdipStart() {
	static token := 0
	if (token) {
		return token
	}
	if !DllCall("GetModuleHandle", "str", "gdiplus", "ptr") {
		DllCall("LoadLibrary", "str", "gdiplus")
	}
	si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
	NumPut("uint", 1, si, 0)
	if DllCall("gdiplus\GdiplusStartup", "ptr*", &token, "ptr", si, "ptr", 0) {
		token := 0
	}
	return token
}

global FishPicked := 0
global KillTask := 0, File1 := "CordsSaveForAutoAppraisal.txt", File2 := "MutationSaveForAutoAppraisal.txt", YHalf := "", XHalf := "", HighlightStatus := 0, IsStoppingNoYes := 0
global ScanBusy := 0
global ScanCount := 0, LastScanEnd := 0, ScanBusySince := 0
global LastMatchName := "", LastMatchReason := ""
global ScriptStart := A_TickCount
global LastScan := 0
global CycleCounter := -1
global CycleName := ""
global NewResultSeen := 0
global LastResultFresh := 0
global CycleSig := "", PrevSig := ""
global CycleKind := "", PrevKind := ""
global PrevName := ""
global ScanLight := 0
global CycleWhy := ""
global CycleNote := ""
global FocusRect := 0
global LastCap := 0
global MutDeepWanted := 1
global UnreadStopSig := "", UnreadStopTick := 0
global MutChecked := Map()
global LVRowNames := []
global LVFilling := 0
global Appraiseable := []
global SettingsFile := A_ScriptDir "\AutoAppraisalSettings.ini"
global xxxxxxxx := "", yyyyyyyy := "", wwwwwwww := "", hhhhhhhh := ""
if (!FileExist(SettingsFile) and FileExist(A_ScriptDir "\AutoAppraisalHotkeys.ini")) {
	try FileMove(A_ScriptDir "\AutoAppraisalHotkeys.ini", SettingsFile)
}
global StartStopKey := "F3", FishBoxKey := "F4", KeyQuietUntil := 0

if !(fileexist(File1)) {
	FileAppend
	(
	"xxxxxxxx=" xxxxxxxx "`n"
	"yyyyyyyy=" yyyyyyyy "`n"
	"wwwwwwww=" wwwwwwww "`n"
	"hhhhhhhh=" hhhhhhhh "`n"
	"AAO=0
	theappraiseanywherex=686
	theappraiseanywherey=596
	theyesclickx=1008
	theyesclicky=804
	thenoclickx=894
	thenoclicky=804
	thenofishconfirmationx=961
	thenofishconfirmationy=800
	thetolerancesettingsyeah=25
	thecolorforthenumberthing=0xFFF4B3`n"
	), File1
}
readthemfile(fileread(File1))

try {
randomahhstringthatidontevenuse := thecolorforthenumberthing
}catch{
msgbox "Config File Outdated, Deleting old config...", "ERROR", "0x40030"
filedelete File1
reload
}

if !(FileExist(File2)) {
	fileappend
	(
	"Abyssal`n"
	"Albino`n"
	"Amber`n"
	"Big/Giant`n"
	"Bioluminescent`n"
	"Boreal`n"
	"Coral`n"
	"Crimson`n"
	"Darkened`n"
	"Decayed`n"
	"Electric`n"
	"Entrenched`n"
	"Fallen`n"
	"Fossilized`n"
	"Frozen`n"
	"Glossy`n"
	"Greedy`n"
	"Gusty`n"
	"Hexed`n"
	"Honey`n"
	"Lunar`n"
	"Midas`n"
	"Mosaic`n"
	"Mourned`n"
	"Mythical`n"
	"Negative`n"
	"Petrified`n"
	"Poisoned`n"
	"Scorched`n"
	"Shiny`n"
	"Shrouded`n"
	"Silver`n"
	"Sparkling`n"
	"Spirit`n"
	"Translucent`n"
	"Vined"
	), File2
}
readthemfile2(fileread(File2))
MergeKnownNames()
for name in Appraiseable {
	MutChecked[name] := 0
}
global LV_Mutations, SearchBox, thegui, thegui2, AppraiseAnywhereOption, thepixelcolor, thetolerancething, HkStartCtrl, HkFishCtrl, HelpTextCtrl, OcrStatusCtrl, FishStatusCtrl
LoadHotkeys()
FirstRunGate()

MakeTheEntireGUI()
MakeSettingsGUI()
RegisterHotkeys()
UpdateBoxStatus()

return

;==========================================
;            GUI CONSTRUCTION
;==========================================

MakeTheEntireGUI(px := "", py := "") {
    global
    thegui := Gui("+AlwaysOnTop +SysMenu", "Auto Appraisal v1.1")
    thegui.BackColor := "0x1E1E1E"

    ; --- SIDEBAR (Controls & Configs) ---
    thegui.SetFont("s16 w700 c55AAFF", "Segoe UI")
    thegui.Add("Text", "x20 y15 w180 h35", "Auto Appraisal")
    thegui.SetFont("s9 w400 c888888", "Segoe UI")
    thegui.Add("Text", "x20 y45 w180", "v1.1 by Yato, Lolzzn")

    thegui.Add("Text", "x20 y70 w180 h1 Background333333")

    thegui.SetFont("s10 w600 cFFFFFF", "Segoe UI")
    thegui.Add("Text", "x20 y85 w180", "Hotkeys")
    thegui.SetFont("s9 w400 cCCCCCC", "Segoe UI")
    thegui.Add("Text", "x20 y110 w85", "Start / Stop")
    thegui.Add("Text", "x20 y135 w85", "Fish Box")
    thegui.SetFont("s9 w400 c000000", "Segoe UI")
    HkStartCtrl := thegui.Add("Hotkey", "x110 y106 w90 h22 -Tabstop", StartStopKey)
    HkStartCtrl.OnEvent("Change", (ctrl, *) => HotkeyBoxChanged(ctrl, "start"))
    HkFishCtrl := thegui.Add("Hotkey", "x110 y131 w90 h22 -Tabstop", FishBoxKey)
    HkFishCtrl.OnEvent("Change", (ctrl, *) => HotkeyBoxChanged(ctrl, "fish"))

    thegui.Add("Text", "x20 y160 w180 h1 Background333333")

    thegui.SetFont("s10 w600 cFFFFFF", "Segoe UI")
    thegui.Add("Text", "x20 y175 w180", "Macro Settings")

    thegui.SetFont("s10 w400 cFFFFFF", "Segoe UI")
    AppraiseAnywhereOption := thegui.Add("Checkbox", "x20 y205 w180 Background1E1E1E", "Appraise Anywhere")
    AppraiseAnywhereOption.value := AAO
    AppraiseAnywhereOption.OnEvent("Click", UpdateFile1Thing)

    thegui.SetFont("s10 w400 cFFFFFF", "Segoe UI")
    btnAppraiseSettings := thegui.Add("Button", "x20 y240 w180 h30 Background2D2D2D", "⚙️ Change Coords")
    btnAppraiseSettings.OnEvent("Click", (*) => TakeAppraiseAnywhereSettings())

    btnRetakeBox := thegui.Add("Button", "x20 y275 w180 h30 Background2D2D2D", "📐 Retake OCR Box")
    btnRetakeBox.OnEvent("Click", takeocrbox)

    btnColorTol := thegui.Add("Button", "x20 y310 w180 h30 Background2D2D2D", "🎨 Color && Tolerance")
    btnColorTol.OnEvent("Click", (*) => ShowAnotherUI())

    btnToggleHighlight := thegui.Add("Button", "x20 y345 w180 h30 Background2D2D2D", "👁️ Toggle Highlight")
    btnToggleHighlight.OnEvent("Click", (*) => ToggleHighlight())

    thegui.Add("Text", "x20 y385 w180 h1 Background333333")

    thegui.SetFont("s9 w400 cCCCCCC", "Segoe UI")
    thegui.Add("Text", "x20 y398 w70", "OCR Box")
    thegui.Add("Text", "x20 y418 w70", "Fish Box")
    thegui.SetFont("s9 w600 cFF6666", "Segoe UI")
    OcrStatusCtrl := thegui.Add("Text", "x92 y398 w118", "Not set")
    FishStatusCtrl := thegui.Add("Text", "x92 y418 w118", "Not set")
    thegui.SetFont("s8 w400 c888888", "Segoe UI")
    HelpTextCtrl := thegui.Add("Text", "x20 y442 w190 h30", HelpLine())

    thegui.Add("Text", "x220 y20 w1 h455 Background333333")

    ; --- MAIN CONTENT (Mutations Checkboxes) ---
    thegui.SetFont("s14 w600 cFFFFFF", "Segoe UI")
    thegui.Add("Text", "x240 y20 w200", "Target Mutations")

    thegui.SetFont("s9 w400 cFFFFFF", "Segoe UI")
    btnCheckAll := thegui.Add("Button", "x240 y45 w80 h26 Background2D2D2D", "Check All")
    btnCheckAll.OnEvent("Click", (*) => dosomethingtoboxes(1))

    btnUncheckAll := thegui.Add("Button", "x325 y45 w80 h26 Background2D2D2D", "Uncheck")
    btnUncheckAll.OnEvent("Click", (*) => dosomethingtoboxes(0))

    btnReloadMut := thegui.Add("Button", "x410 y45 w80 h26 Background2D2D2D", "Reload List")
    btnReloadMut.OnEvent("Click", (*) => ReloadMutationList())

    btnOpenTxt := thegui.Add("Button", "x495 y45 w25 h26 Background2D2D2D", "📝")
    btnOpenTxt.OnEvent("Click", (*) => run(file2))

    thegui.SetFont("s10 w400 c000000", "Segoe UI")
    SearchBox := thegui.Add("Edit", "x240 y80 w280 h24 BackgroundFFFFFF -Multi")
    SendMessage(0x1501, 1, StrPtr("Search mutations..."), SearchBox)
    SearchBox.OnEvent("Change", (*) => FillMutationList(SearchBox.Value))

    thegui.SetFont("s12 w400", "Segoe UI")
    LV_Mutations := thegui.Add("ListView", "x240 y110 w280 h330 Checked -Hdr Background1E1E1E cFFFFFF", ["Mutation"])
    LV_Mutations.OnEvent("ItemCheck", MutItemCheck)
    OnMessage(0x4E, LV_CustomDraw)
    FillMutationList("")

    thegui.SetFont("s9 w600 cFF6666", "Segoe UI")
    thegui.Add("Text", "x240 y447 w280 h32", "Put the OCR box over the appraisal result")

    thegui.OnEvent("Close", (*) => exitapp())
    posStr := (px != "" && py != "") ? ("x" px " y" py " ") : ""
    thegui.Show(posStr "w550 h485")
}

MakeSettingsGUI() {
    global
    thegui2 := Gui("+AlwaysOnTop +SysMenu +ToolWindow", "Detection Config")
    thegui2.BackColor := "0x1E1E1E"

    thegui2.SetFont("s12 w600 cFFFFFF", "Segoe UI")
    thegui2.Add("Text", "x20 y15 w200", "Detection Config")

    thegui2.SetFont("s10 w400 cCCCCCC", "Segoe UI")
    thegui2.Add("Text", "x20 y55 w200", "Target Number Color (Hex):")
    thegui2.SetFont("s10 w400 cFFFFFF", "Segoe UI")
    thepixelcolor := thegui2.Add("Edit", "x20 y75 w130 Background333333", thecolorforthenumberthing)

    btnGetColor := thegui2.Add("Button", "x160 y74 w70 h26 Background2D2D2D", "Pick 🖱️")
    btnGetColor.OnEvent("Click", (*) => GetTheColorForSomething())

    thegui2.SetFont("s10 w400 cCCCCCC", "Segoe UI")
    thegui2.Add("Text", "x20 y115 w200", "Color Match Tolerance:")
    thegui2.SetFont("s10 w400 cFFFFFF", "Segoe UI")
    thetolerancething := thegui2.Add("Edit", "x20 y135 w130 Background333333", thetolerancesettingsyeah)

    thegui2.SetFont("s10 w600", "Segoe UI")
    btnSaveSet := thegui2.Add("Button", "x20 y185 w210 h35 Background55AAFF", "Save Configuration")
    btnSaveSet.OnEvent("Click", (*) => UpdateOtherSettings())
}

ShowAnotherUI() {
    global
    WinGetPos(&Xx2, &Yy2, &Width, &Height, thegui)
    thegui2.Show("x" (Xx2 + (Width/2) - 125) " y" (Yy2 + 50) " w250 h240")
}

; ---- the mutation list ----------------------------------------------------------------

FillMutationList(filter := "") {
    global LV_Mutations, LVRowNames, LVFilling, Appraiseable, MutChecked
    local name, label, mult
    LVFilling := 1
    LV_Mutations.Opt("-Redraw")
    LV_Mutations.Delete()
    LVRowNames := []
    filter := Trim(filter)
    for name in Appraiseable {
        if (filter != "" and !InStr(name, filter)) {
            continue
        }
        label := name
        mult := MutMult(name)
        if (mult != "") {
            label .= "   (" mult ")"
        }
        LVRowNames.Push(name)
        LV_Mutations.Add((MutChecked.Has(name) and MutChecked[name]) ? "Check" : "", label)
    }
    LV_Mutations.Opt("+Redraw")
    LVFilling := 0
}

MutItemCheck(ctrl, item, checked) {
    global LVRowNames, MutChecked, LVFilling
    if (LVFilling or item < 1 or item > LVRowNames.Length) {
        return
    }
    MutChecked[LVRowNames[item]] := checked ? 1 : 0
}

LV_CustomDraw(wParam, lParam, msg, hwnd) {
    global LV_Mutations, LVRowNames
    static hdrSize := (A_PtrSize = 8) ? 24 : 12
    local stage, row, col, bgr, itemOff, clrOff, c
    if (!IsSet(LV_Mutations) or !IsObject(LV_Mutations)) {
        return
    }
    if (NumGet(lParam, 0, "ptr") != LV_Mutations.Hwnd or NumGet(lParam, 2*A_PtrSize, "int") != -12) {
        return
    }
    stage := NumGet(lParam, hdrSize, "uint")
    if (stage = 1) {
        return 0x20
    }
    if (stage = 0x10001) {
        itemOff := hdrSize + 2*A_PtrSize + 16
        row := NumGet(lParam, itemOff, "uptr") + 1
        col := 0xFFFFFF
        if (row >= 1 and row <= LVRowNames.Length) {
            col := -1
            for c in MutColours(LVRowNames[row]) {
                if (col < 0 or ((c >> 16) & 0xFF) + ((c >> 8) & 0xFF) + (c & 0xFF) > ((col >> 16) & 0xFF) + ((col >> 8) & 0xFF) + (col & 0xFF)) {
                    col := c
                }
            }
            if (col < 0) {
                col := 0xFFFFFF
            }
        }
        bgr := ((col & 0xFF) << 16) | (col & 0xFF00) | (col >> 16)
        clrOff := itemOff + 3*A_PtrSize
        NumPut("uint", bgr, lParam, clrOff)
        NumPut("uint", 0x1E1E1E, lParam, clrOff + 4)
        return 0x02
    }
    return 0
}

SumVar() {
    global MutChecked
    local n := 0, k, v
    for k, v in MutChecked {
        n += v ? 1 : 0
    }
    return n
}

dosomethingtoboxes(whattodo) {
    global LV_Mutations, LVRowNames, MutChecked
    local name
    for name in LVRowNames {
        MutChecked[name] := whattodo ? 1 : 0
    }
    LV_Mutations.Modify(0, whattodo ? "Check" : "-Check")
}

ReloadMutationList() {
    global Appraiseable, MutChecked, SearchBox
    local old := MutChecked, name
    Appraiseable := []
    readthemfile2(fileread(File2))
    MergeKnownNames()
    MutChecked := Map()
    for name in Appraiseable {
        MutChecked[name] := (old.Has(name) and old[name]) ? 1 : 0
    }
    FillMutationList(SearchBox.Value)
    msgbox("Mutations reloaded from file!", "Success", "0x40000")
}

;==========================================
;            FUNCTIONS & LOGIC
;==========================================

GetTheColorForSomething() {
global
local pickX := 0, pickY := 0
	thething := msgbox("Are you sure you want to change the color settings?`nIf the new color doesn't work, revert back", "Confirmation", "0x40044")
	if (thething == "No") {
	return
	}
	fatarrowsettimer := (*) => ttp("Press `"U`" once your done`n`n(put your mouse in the color)`n(you want the numbers color)",,, 1)
	settimer fatarrowsettimer, 150
	keywait "U", "D"
	mousegetpos &pickX, &pickY
	thepixelcolor.value := PixelGetColor(pickX, pickY)
	keywait "U"
	settimer fatarrowsettimer, 0
	ttp ,,, 1
}

FirstRunGate() {
	global SettingsFile
	local done := 0, r, X := 0, Y := 0, W := 0, H := 0
	try done := IniRead(SettingsFile, "Meta", "FirstRunDone", 0)
	if (done = 1) {
		return
	}
	r := MsgBox("IMPORTANT DISCLAIMER`n`nThis will Auto-Subscribe you to the channel.`n`nOK  =  I understand, continue`nCancel  =  Exit", "Auto Appraisal v1.1 — First Time Setup", 0x2021)
	if (r = "Cancel") {
		ExitApp
	}
	Run "https://www.youtube.com/@yatoark?sub_confirmation=1"
	Sleep 3000
	try {
		WinGetPos(&X, &Y, &W, &H, "A")
		Click X + W // 2, Y + H // 2
	}
	Sleep 100
	Send "{Tab}"
	Sleep 100
	Send "{Tab}"
	Sleep 300
	Send "{Enter}"
	Sleep 500
	Send "{Enter}"
	try IniWrite(1, SettingsFile, "Meta", "FirstRunDone")
}

OcrBoxSet() {
	global xxxxxxxx, yyyyyyyy, wwwwwwww, hhhhhhhh
	return (IsNumber(xxxxxxxx) and IsNumber(yyyyyyyy) and IsNumber(wwwwwwww) and IsNumber(hhhhhhhh) and wwwwwwww >= 8 and hhhhhhhh >= 4) ? 1 : 0
}

FishBoxSet() {
	global XHalf, YHalf
	return (XHalf or YHalf) ? 1 : 0
}

UpdateBoxStatus() {
	global OcrStatusCtrl, FishStatusCtrl, FishBoxKey
	try {
		OcrStatusCtrl.Value := OcrBoxSet() ? "Set" : "Not set"
		OcrStatusCtrl.SetFont(OcrBoxSet() ? "c66DD88" : "cFF6666")
		FishStatusCtrl.Value := FishBoxSet() ? "Set" : "Not set"
		FishStatusCtrl.SetFont(FishBoxSet() ? "c66DD88" : "cFF6666")
	}
}

StartStopPressed(*) {
global
	if (IsStoppingNoYes and !KillTask) {
		StopMacro()
		return
	}
	if (A_TickCount < KeyQuietUntil or HotkeyBoxFocused()) {
		return
	}
	StartMacro()
}

FishBoxPressed(*) {
global
	if (A_TickCount < KeyQuietUntil or HotkeyBoxFocused()) {
		return
	}
	fishgui()
}

HotkeyBoxFocused() {
	global thegui, HkStartCtrl, HkFishCtrl
	local f := 0
	try {
		if (!WinActive("ahk_id " thegui.Hwnd)) {
			return 0
		}
		f := ControlGetFocus("ahk_id " thegui.Hwnd)
	}
	return (f and (f = HkStartCtrl.Hwnd or f = HkFishCtrl.Hwnd)) ? 1 : 0
}

HelpLine() {
	global FishBoxKey
	return "Fish Box (" KeyText(FishBoxKey) ") goes over the fish in your hotbar."
}

KeyText(k) {
	local m, mods := "", ch
	if (!RegExMatch(k, "^([\^\!\+\#]*)(.*)$", &m)) {
		return k
	}
	for ch in StrSplit(m[1]) {
		mods .= (ch = "^") ? "Ctrl+" : (ch = "!") ? "Alt+" : (ch = "+") ? "Shift+" : "Win+"
	}
	return mods ((StrLen(m[2]) = 1) ? StrUpper(m[2]) : m[2])
}

HotkeyNorm(k) {
	local m, n := "", mods := "", ch
	if (!RegExMatch(k, "^([\^\!\+\#]*)(.+)$", &m)) {
		return k
	}
	for ch in ["^", "!", "+", "#"] {
		if (InStr(m[1], ch)) {
			mods .= ch
		}
	}
	try n := GetKeyName(m[2])
	return mods ((n != "") ? n : m[2])
}

HotkeyProblem(key, other) {
	local m, plain
	if (key = "" or RegExMatch(key, "^[\^\!\+\#]*$")) {
		return "no key"
	}
	RegExMatch(key, "^([\^\!\+\#]*)(.+)$", &m)
	plain := StrLower(m[2])
	if (m[1] = "") {
		if (plain = "e" or plain = "g" or plain = "2") {
			return "the macro presses " StrUpper(plain) " itself"
		}
		if (plain = "u") {
			return "U is pressed while setting coordinates"
		}
		if (plain = "f1") {
			return "F1 closes the macro"
		}
		if (plain = "f2") {
			return "F2 reloads the macro"
		}
	}
	if (other != "" and StrLower(key) = StrLower(other)) {
		return "it is the other hotkey"
	}
	if (!GetKeyVK(m[2]) and !GetKeySC(m[2])) {
		return "it is not a key AutoHotkey knows"
	}
	return ""
}

LoadHotkeys() {
	global StartStopKey, FishBoxKey, SettingsFile
	local k1 := "F3", k2 := "F4"
	try k1 := HotkeyNorm(Trim(IniRead(SettingsFile, "Hotkeys", "StartStop", "F3")))
	try k2 := HotkeyNorm(Trim(IniRead(SettingsFile, "Hotkeys", "FishBox", "F4")))
	StartStopKey := (HotkeyProblem(k1, "") = "") ? k1 : "F3"
	FishBoxKey := (HotkeyProblem(k2, StartStopKey) = "") ? k2 : ((StrLower(StartStopKey) != "f4") ? "F4" : "F3")
}

SaveHotkeys() {
	global StartStopKey, FishBoxKey, SettingsFile
	try {
		IniWrite(StartStopKey, SettingsFile, "Hotkeys", "StartStop")
		IniWrite(FishBoxKey, SettingsFile, "Hotkeys", "FishBox")
	}
}

BindHotkey(key, fn) {
	try {
		Hotkey(key, fn, "On")
		return true
	}
	return false
}

UnbindHotkey(key) {
	try Hotkey(key, "Off")
}

RegisterHotkeys() {
	global
	if (!BindHotkey(StartStopKey, StartStopPressed)) {
		StartStopKey := "F3"
		BindHotkey(StartStopKey, StartStopPressed)
	}
	if (!BindHotkey(FishBoxKey, FishBoxPressed)) {
		FishBoxKey := (StrLower(StartStopKey) != "f4") ? "F4" : "F3"
		BindHotkey(FishBoxKey, FishBoxPressed)
	}
	try HkStartCtrl.Value := StartStopKey
	try HkFishCtrl.Value := FishBoxKey
	try HelpTextCtrl.Value := HelpLine()
}

ApplyHotkeyChange(which, newKey) {
	global
	local oldKey := (which = "start") ? StartStopKey : FishBoxKey
	local otherKey := (which = "start") ? FishBoxKey : StartStopKey, why
	if (newKey != "" and RegExMatch(newKey, "^[\^\!\+\#]+$")) {
		return "incomplete"
	}
	newKey := HotkeyNorm(newKey)
	if (newKey != "" and StrLower(newKey) = StrLower(oldKey)) {
		return "same"
	}
	why := HotkeyProblem(newKey, otherKey)
	if (why != "") {
		return why
	}
	if (!BindHotkey(newKey, (which = "start") ? StartStopPressed : FishBoxPressed)) {
		return "it can't be used as a hotkey"
	}
	UnbindHotkey(oldKey)
	if (which = "start") {
		StartStopKey := newKey
	} else {
		FishBoxKey := newKey
	}
	KeyQuietUntil := A_TickCount + 1000
	SaveHotkeys()
	try HelpTextCtrl.Value := HelpLine()
	UpdateBoxStatus()
	return "ok"
}

HotkeyBoxChanged(ctrl, which) {
	global
	local tried := ctrl.Value, r := ApplyHotkeyChange(which, tried), name := (which = "start") ? "Start / Stop" : "Fish Box"
	if (r = "incomplete" or r = "same") {
		return
	}
	if (r != "ok") {
		ctrl.Value := (which = "start") ? StartStopKey : FishBoxKey
		ttp((tried = "" ? "A hotkey is needed" : KeyText(tried) " can't be the " name " key: " r), , , 5)
		SetTimer(ClearKeyTip, -3000)
		return
	}
	DllCall("SetFocus", "ptr", 0)
	ttp(name ": " KeyText((which = "start") ? StartStopKey : FishBoxKey), , , 5)
	SetTimer(ClearKeyTip, -2000)
}

ClearKeyTip() {
	ttp("",,, 5)
}

f1::exitapp
f2::reload

StartMacro() {
global
	if (ScanBusy) {
		ttp("Close the message box first, then press " KeyText(StartStopKey), A_ScreenWidth // 2 - 150, 40, 4)
		settimer ClearStopTip, -2000
		return
	}
	MouseGetPos(&clickX ,&clickY)
	KillTask := 0
	IsStoppingNoYes := 1
	theclickxbuffer := 60
	theclickybuffer := 140
	if (!OcrBoxSet()) {
		IsStoppingNoYes := 0
		msgbox "Set the OCR Box first: click `"Retake OCR Box`" and drag the red box over the appraisal result at the bottom right.", "ERROR", "0x40030"
		try winactivate("Roblox")
	} else if (XHalf or YHalf) {
		if (SumVar() >= 1) {
			Highlight(xxxxxxxx, yyyyyyyy, wwwwwwww, hhhhhhhh)
			if (AppraiseAnywhereOption.value == 0) {
			Highlight2(clickX-60, clickY-140, theclickxbuffer*2, theclickybuffer*2)
			}
			ScanBusy := 0, ScanCount := 0, LastScanEnd := A_TickCount, LastScan := 0, LastResultFresh := 0, FocusRect := 0, CycleWhy := ""
			FishPicked := 0
			settimer NormalRun, 1
		}else{
			IsStoppingNoYes := 0
			msgbox "Please select a mutation first", "ERROR", "0x40030"
			try winactivate("Roblox")
		}
	}else{
		IsStoppingNoYes := 0
		msgbox "Press `"" KeyText(FishBoxKey) "`" first to set a box over the fish in your hotbar", "ERROR", "0x40030"
		try winactivate("Roblox")
	}
}

StopMacro() {
global
	IsStoppingNoYes := 0
	KillTask := 1
	settimer NormalRun, 0
	ScanBusy := 0
	Highlight()
	Highlight2()
	ttp("",,, 2)
	ttp("Auto Appraisal stopped (" KeyText(StartStopKey) " starts it again)", A_ScreenWidth // 2 - 150, 40, 4)
	settimer ClearStopTip, -2000
}

ClearStopTip() {
	ttp("",,, 4)
}

class StopSignal extends Error {
}

AbortableSleep(ms, scan := 0) {
    global IsStoppingNoYes, KillTask
    local deadline := A_TickCount + ms, remaining
    loop {
        if (IsStoppingNoYes == 0 or KillTask == 1) {
            throw StopSignal("stopped")
        }
        remaining := deadline - A_TickCount
        if (remaining <= 0) {
            return
        }
        if (!scan or !ScanOnce()) {
            Sleep (remaining > 15) ? 15 : remaining
        }
    }
}

NormalRun() {
    global

    if (killtask == 1) {
        Highlight()
        Highlight2()
        ttp("",,, 2)
        settimer NormalRun, 0
        return
    }

    try {
        if (AppraiseAnywhereOption.value == 0) {
            ClickTheButton()
        } else {
            AppraiseAnywhereClick()
        }
    } catch StopSignal {
    }
}

ScanOnce() {
    global

    if (IsStoppingNoYes == 0 or KillTask == 1 or ScanBusy) {
        return 0
    }

    ScanBusy := 1, ScanBusySince := A_TickCount
    try {
        scanStart := A_TickCount
        MutDeepWanted := AnyHardTicked()
        cap := MutCapture(xxxxxxxx, yyyyyyyy, wwwwwwww, hhhhhhhh)
        LastCap := cap
        LastScan := 0
        if (IsObject(cap) and IsObject(FocusRect)) {
            capF := MutCrop(cap, FocusRect.x, FocusRect.y, FocusRect.w, FocusRect.h)
            if (IsObject(capF)) {
                LastScan := MutScan(capF, ScanLight)
            }
            if (!IsObject(LastScan) or !(LastScan.appraised or LastScan.anchor)) {
                FocusRect := 0
                LastScan := 0
            }
        }
        if (!IsObject(LastScan)) {
            LastScan := MutScan(cap, ScanLight)
            if (LastScan.appraised and IsObject(LastScan.focus)) {
                FocusRect := LastScan.focus
            }
        }
        ScanCount += 1
        LastScanEnd := A_TickCount
        CheckForMutation(LastScan)
    } catch {
    }
    ScanBusy := 0
    return 1
}

ScanAttrText(scan) {
    local t := "", a
    if (IsObject(scan)) {
        for a in scan.attrs {
            t .= (t != "" ? ", " : "") a
        }
    }
    return (t != "") ? t : "-"
}

CheckForMutation(scan) {
    global
    local found := "", reason := "", row, name, a

    if (IsObject(scan) and scan.name != "" and MutChecked.Has(scan.name) and MutChecked[scan.name]) {
        found := scan.name, reason := scan.how
    }
    if (found = "" and IsObject(scan)) {
        for a in scan.attrs {
            if (MutChecked.Has(a) and MutChecked[a]) {
                found := a, reason := "first line"
                break
            }
        }
    }
    if (found = "" and MutChecked.Has("Big/Giant") and MutChecked["Big/Giant"] and IsSet(Left) and IsSet(Top) and IsSet(Right) and IsSet(Bottom)) {
        if PixelSearch(&cc, &kk, Left, Top, Right, Bottom, 0x87ED86, 10) {
            found := "Big/Giant", reason := "fish box colour"
        }
    }
    if (found = "") {
        return false
    }
    LastMatchName := found, LastMatchReason := reason
    KillTask := 1
    IsStoppingNoYes := 0
    settimer NormalRun, 0
    MutChecked[found] := 0
    for row, name in LVRowNames {
        if (name = found) {
            LV_Mutations.Modify(row, "-Check")
        }
    }
    Highlight()
    Highlight2()
    msgbox found " is Found!", "Success", "0x40000"
    return true
}

fishgui() {
global
	ScaleGUI := Gui("+ToolWindow +Resize -Caption +AlwaysOnTop -Border")
	ScaleGUI.backcolor := "0x00ff00"
	ScaleGUI.Show()
	MouseGetPos(&xxxxx1, &yyyyy1)

	TemporaryLength := 80
	TemporaryWidth := 80

	whereitwouldbe := xxxxx1-TemporaryLength//2
	whereitactuallyis := yyyyy1-TemporaryWidth//2
	ScaleGUI.Opt("+LastFound")
	WinMove(whereitwouldbe, whereitactuallyis, TemporaryLength, TemporaryWidth, ScaleGUI)
	WinSetTransparent(90)

	MsgBox("Drag this green box over the fish in your hotbar, then click OK.`n`n⚠️ Keep it on that one slot only - if it overlaps other fish they get scanned too.", "Fish Box", "0x40000")

	WinGetPos( &Xx, &Yy, &Width, &Height, ScaleGUI)
	Left := Xx
	Right := Xx + Width
	Top := Yy
	Bottom := Yy + Height
	XHalf := round(Left+Width/2)
	YHalf := round(Top+Height/2)
	ScaleGUI.destroy()
	UpdateBoxStatus()
	try winactivate("Roblox")
}

SetOcrRange(*) {
global
	ScaleGUI := Gui("+ToolWindow +Resize -Caption +AlwaysOnTop +Border")
	ScaleGUI.backcolor := "ff0000"
	TemporaryLength := 350
	TemporaryWidth := 110

	whereitwouldbe := A_ScreenWidth - TemporaryLength - 10
	whereitactuallyis := Round(A_ScreenHeight * 0.70)

	ScaleGUI.Show("x" whereitwouldbe " y" whereitactuallyis " w" TemporaryLength " h" TemporaryWidth)
	WinSetTransparent(90, ScaleGUI.Hwnd)

	TheFatRetakeBoxUI := (*) => ttp("Drag this red box over the appraisal result at the bottom right:`nthe lines that start with `"Appraised`" and `"Mutation Changed`".`nInclude all three lines with a little room around them.`nPress `"U`" when you are done adjusting!",,,1)
	settimer TheFatRetakeBoxUI, 100
	keywait "U", "D"
	keywait "U"
	settimer TheFatRetakeBoxUI, 0
	ttp "",,, 1
	WinGetPos(&xxxxxxxx, &yyyyyyyy, &wwwwwwww, &hhhhhhhh, ScaleGUI)
	ScaleGUI.Hide()
}

readthemfile(yeah) {
	global
	for i, v in strsplit(yeah, "`n") {
		if (trim(v) != "") {
			try {
				IHATEARRAYS := strsplit(v, "=")
				arr1 := trim(IHATEARRAYS[1])
				arr2 := trim(IHATEARRAYS[2])
				%arr1% := arr2
			}catch as ermmm {
				if (ermmm.Message == "Variable not found.") {
					ermmmresult := msgbox(ermmm.Message "Do you want to delete old config file?`nIf you choose not to, this version of the macro won't work/run.", "ERROR", "0x40034")
					if (ermmmresult == "No") {
						exitapp
					}else{
						filedelete File1
						FileAppend
						(
						"xxxxxxxx=" xxxxxxxx "`n"
						"yyyyyyyy=" yyyyyyyy "`n"
						"wwwwwwww=" wwwwwwww "`n"
						"hhhhhhhh=" hhhhhhhh "`n"
						"AAO=0
						theappraiseanywherex=686
						theappraiseanywherey=596
						theyesclickx=1008
						theyesclicky=804
						thenoclickx=894
						thenoclicky=804
						thenofishconfirmationx=961
						thenofishconfirmationy=800
						thetolerancesettingsyeah=25
						thecolorforthenumberthing=0xFFF4B3`n"
						), File1
						sleep 200
						readthemfile(fileread(File1))
						break
					}
				}else{
				msgbox "Something is wrong with the fileread`nERROR MESSAGE: " ermmm.Message, "ERROR" , "0x40030"
				exitapp
				}
			}
		}
	}
}

readthemfile2(yeah) {
global
	for i, v in strsplit(yeah, "`n") {
		if (trim(v) != "") {
			Appraiseable.push(trim(v))
		}
	}
}

MergeKnownNames() {
	global Appraiseable, MutNameList
	local name, have := Map(), n
	MutInit()
	for n in Appraiseable {
		have[n] := 1
	}
	for name in MutNameList {
		if (!have.Has(name)) {
			Appraiseable.Push(name)
		}
	}
}

takeocrbox(*) {
global
	if (OcrBoxSet()) {
		thething := msgbox("Are you sure you wanted to retake the OCR box settings?", "Confirmation", "0x40044")
		if (thething == "No") {
		return
		}
	}
	SetOcrRange()
	UpdateFile1Thing()
	sleep 250
	readthemfile(fileread(File1))
	FocusRect := 0
	UpdateBoxStatus()
}

UpdateFile1Thing(*) {
global
	try filedelete file1
	FileAppend
	(
	"xxxxxxxx=" xxxxxxxx "`n"
	"yyyyyyyy=" yyyyyyyy "`n"
	"wwwwwwww=" wwwwwwww "`n"
	"hhhhhhhh=" hhhhhhhh "`n"
	"AAO=" AppraiseAnywhereOption.value "`n"
	"theappraiseanywherex=" theappraiseanywherex "`n"
	"theappraiseanywherey=" theappraiseanywherey "`n"
	"theyesclickx=" theyesclickx "`n"
	"theyesclicky=" theyesclicky "`n"
	"thenoclickx=" thenoclickx "`n"
	"thenoclicky=" thenoclicky "`n"
	"thenofishconfirmationx=" thenofishconfirmationx "`n"
	"thenofishconfirmationy=" thenofishconfirmationy "`n"
	"thetolerancesettingsyeah=" thetolerancething.value "`n"
	"thecolorforthenumberthing=" thepixelcolor.value "`n"
	), File1
}

Highlight(x?, y?, w?, h?, showTime:=0, color:="Red", d:=2) {
	static guis := []
	if !IsSet(x) {
        for _, r in guis
            r.Destroy()
        guis := []
		global HighlightStatus := 0
		return
    }
	global HighlightStatus := 1
    if !guis.Length {
        Loop 4
            guis.Push(Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000"))
    }
	Loop 4 {
		i:=A_Index
		, x1:=(i=2 ? x+w : x-d)
		, y1:=(i=3 ? y+h : y-d)
		, w1:=(i=1 or i=3 ? w+2*d : d)
		, h1:=(i=2 or i=4 ? h+2*d : d)
		guis[i].BackColor := color
		guis[i].Show("NA x" . x1 . " y" . y1 . " w" . w1 . " h" . h1)
	}
	if showTime > 0 {
		Sleep(showTime)
		Highlight()
	} else if showTime < 0
		SetTimer(Highlight, -Abs(showTime))
}

Highlight2(x?, y?, w?, h?, showTime:=0, color:="0x1F84FF", d:=2) {
	static guis232 := []
	if !IsSet(x) {
        for _, r in guis232
            r.Destroy()
        guis232 := []
		return
    }
    if !guis232.Length {
        Loop 4
            guis232.Push(Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000"))
    }
	Loop 4 {
		i:=A_Index
		, x1:=(i=2 ? x+w : x-d)
		, y1:=(i=3 ? y+h : y-d)
		, w1:=(i=1 or i=3 ? w+2*d : d)
		, h1:=(i=2 or i=4 ? h+2*d : d)
		guis232[i].BackColor := color
		guis232[i].Show("NA x" . x1 . " y" . y1 . " w" . w1 . " h" . h1)
	}
	if showTime > 0 {
		Sleep(showTime)
		Highlight2()
	} else if showTime < 0
		SetTimer(Highlight2, -Abs(showTime))
}

ReadResultFully() {
    global
    local tries := 0, unread := 0, unreadScan := 0, unreadCap := 0
    loop {
        ScanOnce()
        tries += 1
        if (KillTask == 1 or !IsObject(LastScan)) {
            return
        }
        if (LastScan.anchor and LastScan.kind != "") {
            unread := (LastScan.kind = "changed" and LastScan.name = "")
            unreadScan := unread ? LastScan : 0, unreadCap := unread ? LastCap : 0
        }
        if (LastScan.complete or !LastScan.anchor or tries >= 3) {
            if (unread and !(LastScan.anchor and LastScan.name != "")) {
                UnreadableChange(unreadScan, unreadCap)
            }
            return
        }
        AbortableSleep(300)
    }
}

IsDarkMutation(name) {
    return MutIsHard(name)
}

AnyHardTicked() {
    global MutChecked
    local name, v
    for name, v in MutChecked {
        if (v and MutIsHard(name)) {
            return 1
        }
    }
    return 0
}

UnreadableChange(scan, cap := 0) {
    global
    local name, v, dark := "", wOld
    CycleNote := "a changed mutation could not be read"
    if (!StopOnUnreadable or !IsObject(scan)) {
        return
    }
    wOld := SubStr(CycleSig, InStr(CycleSig, "|") + 1)
    if (CycleKind = "changed" and CycleName != "" and ((scan.counter >= 0 and CycleCounter >= 0 and scan.counter = CycleCounter)
        or (CycleCounter < 0 and scan.sig == CycleSig and wOld != ""))) {
        CycleNote := "old Mutation line fading (it was " CycleName ")"
        return
    }
    if (UnreadStopTick and scan.sig == UnreadStopSig) {
        CycleNote := "unreadable name already shown to you"
        return
    }
    for name, v in MutChecked {
        if (v and IsDarkMutation(name)) {
            dark .= (dark != "" ? ", " : "") name
        }
    }
    if (dark = "") {
        return
    }
    UnreadStopSig := scan.sig, UnreadStopTick := A_TickCount
    KillTask := 1
    IsStoppingNoYes := 0
    settimer NormalRun, 0
    Highlight()
    Highlight2()
    ScanBusy := 1
    try {
        msgbox "The mutation changed, but its name could not be read (dark text on a dark background).`n`n"
            . "It may be one you ticked: " dark "`n`nCheck the fish, then press " KeyText(StartStopKey) " to carry on.", "Check the fish", "0x40030"
    } finally {
        ScanBusy := 0
    }
}

RebaselineBeforeConfirm() {
    global
    local wNow, wOld, late := 0
    ScanLight := (CycleWhy = "counter") ? 1 : 0
    try {
        ScanOnce()
    } finally {
        ScanLight := 0
    }
    if (KillTask == 1 or !IsObject(LastScan) or !LastScan.appraised) {
        return
    }
    if (LastScan.counter >= 0 and CycleCounter >= 0) {
        late := (LastScan.counter = CycleCounter + 1)
    } else {
        wNow := SubStr(LastScan.sig, InStr(LastScan.sig, "|") + 1), wOld := SubStr(CycleSig, InStr(CycleSig, "|") + 1)
        late := (wNow != "" and wNow != wOld) or (LastScan.kind != "" and LastScan.kind != CycleKind) or (LastScan.kind = "changed" and LastScan.name != "" and LastScan.name != CycleName)
    }
    if (!late) {
        return
    }
    ReadResultFully()
    if (KillTask == 1 or !IsObject(LastScan) or !LastScan.appraised) {
        return
    }
    CycleCounter := LastScan.counter, CycleSig := LastScan.sig, CycleKind := LastScan.kind, CycleName := LastScan.name
    CycleNote := "late reply re-baselined before the confirm"
}

ReadBeforeActing() {
    global
    CycleNote := ""
    if (!(LastResultFresh and IsObject(LastScan) and LastScan.complete and A_TickCount - LastScanEnd < 2000
        and (LastScan.kind != "changed" or LastScan.name != "" or AnyHardTicked() = MutDeepWanted))) {
        ReadResultFully()
    }
    LastResultFresh := 0
    if (KillTask == 1) {
        return
    }
    if (!(IsObject(LastScan) and LastScan.appraised and LastScan.name = "" and LastScan.kind = "changed" and CycleKind = "changed"
        and CycleCounter >= 0 and LastScan.counter = CycleCounter)) {
        CycleName := IsObject(LastScan) ? LastScan.name : ""
    }
    CycleCounter := (IsObject(LastScan) and LastScan.appraised) ? LastScan.counter : -1
    CycleSig := (IsObject(LastScan) and LastScan.appraised) ? LastScan.sig : ""
    CycleKind := (IsObject(LastScan) and LastScan.appraised) ? LastScan.kind : ""
    NewResultSeen := 0
}

WaitForNewResult(maxMs) {
    global
    local deadline := A_TickCount + maxMs, fresh, why := "timeout", sigOk, wNow, wOld, wPrev, prevCounter := -1, gone := 0, goneN := 0
    local waitStart := A_TickCount
    LastResultFresh := 0
    PrevSig := "", PrevKind := "", PrevName := ""
    ScanLight := 1
    try {
        AbortableSleep(250, 1)
        loop {
            fresh := 0
            if (IsObject(LastScan) and LastScan.appraised) {
                wNow := SubStr(LastScan.sig, InStr(LastScan.sig, "|") + 1), wOld := SubStr(CycleSig, InStr(CycleSig, "|") + 1)
                wPrev := SubStr(PrevSig, InStr(PrevSig, "|") + 1)
                sigOk := (wNow != "" and wNow != wOld and wNow == wPrev)
                if (CycleKind != "" and LastScan.kind = "") {
                    goneN += 1
                    if (goneN >= 2) {
                        gone := 1
                    }
                } else {
                    goneN := 0
                }
                if (LastScan.counter >= 0 and CycleCounter >= 0) {
                    if (LastScan.counter = CycleCounter + 1 and prevCounter = LastScan.counter) {
                        fresh := 1, why := "counter"
                    }
                } else if (CycleSig = "" and LastScan.counter >= 0 and prevCounter = LastScan.counter) {
                    fresh := 1, why := "first counter"
                } else if (sigOk) {
                    fresh := 1, why := "digits"
                } else if (LastScan.kind != "" and LastScan.kind != CycleKind and LastScan.kind == PrevKind) {
                    fresh := 1, why := "mutation line"
                } else if (LastScan.kind = "changed" and LastScan.name != "" and LastScan.name != CycleName and LastScan.name == PrevName) {
                    fresh := 1, why := "new name"
                } else if (gone and LastScan.kind = "changed" and LastScan.kind == PrevKind and !(LastScan.name != "" and LastScan.name == CycleName)) {
                    fresh := 1, why := "mutation line back"
                }
                PrevSig := LastScan.sig, PrevKind := LastScan.kind, PrevName := LastScan.name, prevCounter := LastScan.counter
            }
            if (fresh) {
                break
            }
            if (A_TickCount > deadline) {
                why := "timeout"
                CycleWhy := why " | before: counter=" CycleCounter " digits=" CycleSig " | last read: " (IsObject(LastScan) ? "appraised=" LastScan.appraised " counter=" LastScan.counter " digits=" LastScan.sig " kind=" LastScan.kind " name=" LastScan.name " text=" StrReplace(LastScan.allText, "`n", " / ") : "none")
                ScanLight := 0
                ReadResultFully()
                if (IsObject(LastScan) and LastScan.complete) {
                    LastResultFresh := 1
                }
                return 0
            }
            if (ScanLight and A_TickCount - waitStart > 1500) {
                ScanLight := 0, gone := 0, goneN := 0
            }
            AbortableSleep(25, 1)
        }
    } finally {
        ScanLight := 0
    }
    AbortableSleep(200)
    ReadResultFully()
    if (IsObject(LastScan) and LastScan.complete) {
        LastResultFresh := 1
    }
    CycleWhy := why
    return 1
}

ClickTheButton() {
    global

    t0 := A_TickCount
    ReadBeforeActing()
    if (KillTask == 1) {
        return
    }
    t1 := A_TickCount

    if (!FishPicked) {
        send "{2}"
        AbortableSleep(100)
    }

    send "{e}"
    AbortableSleep(250)

    deadline := A_TickCount + 3750
    if (!FishPicked) {
        click(XHalf, YHalf)
        FishPicked := 1
    } else {
        mousemove(XHalf, YHalf)
    }
    AbortableSleep(250)

    loop {
        if (pixelsearch(&actuallyusefulyellowone, &actuallyusefulyellowone2, clickX-theclickxbuffer, clickY-theclickybuffer, clickX+theclickxbuffer, clickY+theclickybuffer, thecolorforthenumberthing, thetolerancesettingsyeah) and pixelsearch(&template, &template, clickX-theclickxbuffer, clickY-theclickybuffer, clickX+theclickxbuffer, clickY+theclickybuffer, 0xECECEC, thetolerancesettingsyeah)) {
            break
        }
        if (A_TickCount > deadline) {
            break
        }
        if (IsStoppingNoYes == 0 or KillTask == 1) {
            return
        }
        AbortableSleep(50)
    }

    click(actuallyusefulyellowone ,actuallyusefulyellowone2)
    AbortableSleep(200)
    deadline := A_TickCount + 3750

    loop {
        if (pixelsearch(&actuallyusefulyellowone, &actuallyusefulyellowone2, clickX-theclickxbuffer, clickY-theclickybuffer, clickX+theclickxbuffer, clickY+theclickybuffer, thecolorforthenumberthing, thetolerancesettingsyeah) and pixelsearch(&template, &template, clickX-theclickxbuffer, clickY-theclickybuffer, clickX+theclickxbuffer, clickY+theclickybuffer, 0xECECEC, thetolerancesettingsyeah)) {
            break
        }
        if (A_TickCount > deadline) {
            break
        }
        if (IsStoppingNoYes == 0 or KillTask == 1) {
            return
        }
        AbortableSleep(50)
    }

    RebaselineBeforeConfirm()
    if (KillTask == 1) {
        return
    }
    click(actuallyusefulyellowone ,actuallyusefulyellowone2)
    t2 := A_TickCount
    UnreadStopSig := "", UnreadStopTick := 0

    WaitForNewResult(ResultWaitMs)
    t3 := A_TickCount

    if (IsStoppingNoYes == 0) {
        return
    }
    AbortableSleep(400)
}

AppraiseAnywhereClick() {
    global
    local okX, okY

    t0 := A_TickCount
    ReadBeforeActing()
    if (KillTask == 1) {
        return
    }
    t1 := A_TickCount

    if (!FishPicked) {
        send "{g}"
        AbortableSleep(100)
        send "{2}"
        AbortableSleep(100)
        send "{g}"
    }

    mousemove(XHalf, YHalf)
    AbortableSleep(300)

    okX := (thenoclickx + theyesclickx) // 2, okY := (thenoclicky + theyesclicky) // 2
    if (pixelsearch(&template, &template, okX-40, okY-20, okX+40, okY+20, 0xA8FF95, thetolerancesettingsyeah) and !(pixelsearch(&template, &template, thenoclickx-40, thenoclicky-20, thenoclickx+40, thenoclicky+20, 0xD43D00, thetolerancesettingsyeah) and pixelsearch(&template, &template, theyesclickx-40, theyesclicky-20, theyesclickx+40, theyesclicky+20, 0xA8FF95, thetolerancesettingsyeah)) and RobloxActive()) {
        send "{Enter}"
        AbortableSleep(200)
    }

    if (!FishPicked) {
        mousemove(XHalf, YHalf)
        AbortableSleep(50)
        Critical "On"
        send "{LButton down}"
        sleep 50
        send "{LButton up}"
        Critical "Off"
        FishPicked := 1
    }
    AbortableSleep(300)
    click theappraiseanywherex, theappraiseanywherey

    deadline := A_TickCount + 2500
    loop {
        if (pixelsearch(&template, &template, thenoclickx-40, thenoclicky-20, thenoclickx+40, thenoclicky+20, 0xD43D00, thetolerancesettingsyeah) and pixelsearch(&template, &template, theyesclickx-40, theyesclicky-20, theyesclickx+40, theyesclicky+20, 0xA8FF95, thetolerancesettingsyeah)) {
            break
        }
        if (A_TickCount > deadline) {
            break
        }
        if (IsStoppingNoYes == 0 or KillTask == 1) {
            return
        }
        AbortableSleep(25)
    }

    RebaselineBeforeConfirm()
    if (KillTask == 1) {
        return
    }
    click theyesclickx, theyesclicky
    t2 := A_TickCount
    UnreadStopSig := "", UnreadStopTick := 0

    WaitForNewResult(ResultWaitMs)
    t3 := A_TickCount

    if (IsStoppingNoYes == 0) {
        return
    }
    AbortableSleep(400)
}

RobloxActive() {
    try {
        return WinGetTitle("A") == "Roblox" or WinActive("ahk_exe RobloxPlayerBeta.exe")
    }
    return 0
}

TakeAppraiseAnywhereSettings() {
global
	fatarrowsettimer := (*) => ttp("Press `"U`" on `"Appraise Fish`"",,, 1)
	result := msgbox("Are you sure you wanted to change the position settings for `"Appraise Anywhere`" option in the macro?", "Confirmation", "0x40004")
	if (result == "No") {
		return
	}
	try winactivate("Roblox")
	settimer fatarrowsettimer, 150
	keywait "U", "D"
	mousegetpos &theappraiseanywherex, &theappraiseanywherey
	keywait "U"
	settimer fatarrowsettimer, 0
	ttp ,,, 1
	fatarrowsettimer := (*) => ttp("Press `"U`" on the middle of `"Cancel`"`n(appraise while holding a fish)",,, 1)
	settimer fatarrowsettimer, 150
	keywait "U", "D"
	mousegetpos &thenoclickx, &thenoclicky
	keywait "U"
	settimer fatarrowsettimer, 0
	ttp ,,, 1
	fatarrowsettimer := (*) => ttp("Press `"U`" on the middle of `"Confirm`"`n(appraise while holding a fish)",,, 1)
	settimer fatarrowsettimer, 150
	keywait "U", "D"
	mousegetpos &theyesclickx, &theyesclicky
	keywait "U"
	settimer fatarrowsettimer, 0
	ttp ,,, 1
	thenofishconfirmationx := (thenoclickx + theyesclickx) // 2, thenofishconfirmationy := (thenoclicky + theyesclicky) // 2
	UpdateFile1Thing()
	readthemfile(fileread(File1))
	msgbox "Settings have been succesfully saved`nValues:`nAppraise Anywhere:" theappraiseanywherex ", " theappraiseanywherey "`nCancel Button: " thenoclickx ", " thenoclicky "`nConfirm Button: " theyesclickx ", " theyesclicky, "Settings Saved", "0x40040"
	try winactivate("Roblox")
}

UpdateOtherSettings() {
global
	thething := msgbox("Are you sure you want to save the settings?", "Confirmation", "0x40044")
	if (thething == "No") {
	return
	}
	UpdateFile1Thing()
	readthemfile(fileread(File1))
}

ToggleHighlight() {
global
if (HighlightStatus == 0 and !OcrBoxSet()) {
ttp("Set the OCR Box first (Retake OCR Box)",,, 5)
SetTimer(ClearKeyTip, -2000)
return
}
if (HighlightStatus == 0) {
Highlight(xxxxxxxx, yyyyyyyy, wwwwwwww, hhhhhhhh)
HighlightStatus := 1
}else{
Highlight()
HighlightStatus := 0
}
}

; ============================== Mutation detection ==============================

MutInit() {
	global MutInfo, MutNameList
	if (IsSet(MutInfo)) {
		return
	}
	MutInfo := Map(), MutNameList := []
	rows := [
		["Abyssal", 0x0C0FD4, "5.5x"], ["Albino", 0xFCFEFF, "1.2x"], ["Amber", 0xFF7433, "1.2x"],
		["Big/Giant", 0x8BFF89, ">2x"], ["Bioluminescent", [0x254A1F, 0x7EE3FF], "6x"],
		["Boreal", 0x362E27, "4x"], ["Coral", 0xDE9BFF, "1.8x"], ["Crimson", 0x912222, "6x"],
		["Darkened", 0x3A3D3E, "1.5x"], ["Decayed", 0x3F3B4B, "0.45x"], ["Electric", 0xFFF563, "2.1x"],
		["Entrenched", [0x28314A, 0x333C73], "4x"], ["Fallen", 0x626056, "6x"], ["Fossilized", 0xD0B5FF, "3.3x"],
		["Frozen", 0x83FFE6, "1.5x"], ["Glossy", 0x92E2FF, "1.6x"], ["Greedy", 0xFFC226, "5x"], ["Gusty", 0xC6E9FF, "7.5x"],
		["Hexed", 0xA60000, "3x"], ["Honey", 0xFFB433, "2.6x"], ["Lunar", 0xBDA9FF, "2.5x"],
		["Midas", 0xFF9A47, "2.5x"], ["Mosaic", 0xFBC1FF, "1.5x"], ["Mourned", 0x0A1427, "7.5x"],
		["Mythical", 0xFF5294, "5.5x"], ["Negative", 0x7567E2, "1.3x"],
		["Petrified", 0x8C8880, "8x"], ["Poisoned", 0x674991, "0.9x"], ["Scorched", 0x471E11, "3x"], ["Shiny", 0xFFF0BC, "1.85x"],
		["Shrouded", 0x364335, "7x"], ["Silver", 0xCEEEFF, "1.8x"], ["Sparkling", 0xFFF0BC, "1.85x"],
		["Spirit", 0x625195, "5.2x"],
		["Translucent", 0x87FFBF, "1.3x"], ["Vined", 0x78CE7A, "3.5x"]]
	for row in rows {
		keys := (row[1] = "Big/Giant") ? ["big", "giant"] : [MutKey(row[1])]
		cols := IsObject(row[2]) ? row[2] : ((row[2] < 0) ? [] : [row[2]])
		MutInfo[row[1]] := {col: cols.Length ? cols[1] : -1, cols: cols, mult: row[3], keys: keys}
		MutNameList.Push(row[1])
	}
}

MutColour(name) {
	global MutInfo
	MutInit()
	return MutInfo.Has(name) ? MutInfo[name].col : -1
}

MutIsHard(name) {
	local c
	if (!MutColours(name).Length) {
		return 1
	}
	for c in MutColours(name) {
		if (0.299 * ((c >> 16) & 0xFF) + 0.587 * ((c >> 8) & 0xFF) + 0.114 * (c & 0xFF) < 140) {
			return 1
		}
	}
	return 0
}

MutDeepOn() {
	global MutDeepWanted
	return IsSet(MutDeepWanted) ? MutDeepWanted : 1
}

MutColours(name) {
	global MutInfo
	MutInit()
	return MutInfo.Has(name) ? MutInfo[name].cols : []
}

MutGradientSamples(cols) {
	local out := [], a, b, i, f
	if (cols.Length < 2) {
		return cols
	}
	a := cols[1], b := cols[2]
	loop 5 {
		f := (A_Index - 1) / 4
		out.Push((Round(((a >> 16) & 0xFF) + f * (((b >> 16) & 0xFF) - ((a >> 16) & 0xFF))) << 16)
			| (Round(((a >> 8) & 0xFF) + f * (((b >> 8) & 0xFF) - ((a >> 8) & 0xFF))) << 8)
			| Round((a & 0xFF) + f * ((b & 0xFF) - (a & 0xFF))))
	}
	return out
}

MutMult(name) {
	global MutInfo
	MutInit()
	return MutInfo.Has(name) ? MutInfo[name].mult : ""
}

MutKey(s) {
	s := RegExReplace(StrLower(s), "[^a-z0-9]+", "")
	for pair in [["rn","m"], ["cl","d"], ["1","i"], ["l","i"], ["0","o"], ["5","s"], ["8","b"], ["2","z"], ["6","g"], ["9","g"]] {
		s := StrReplace(s, pair[1], pair[2])
	}
	return s
}

MutEditDistance(a, b, maxd) {
	local la := StrLen(a), lb := StrLen(b), prev := [], cur := [], i, j, ca, cost, v, best
	if (Abs(la - lb) > maxd) {
		return maxd + 1
	}
	loop lb + 1 {
		prev.Push(A_Index - 1)
	}
	loop la {
		i := A_Index, ca := SubStr(a, i, 1), cur := [i], best := i
		loop lb {
			j := A_Index
			cost := (ca == SubStr(b, j, 1)) ? 0 : 1
			v := Min(prev[j+1] + 1, cur[j] + 1, prev[j] + cost)
			cur.Push(v)
			if (v < best) {
				best := v
			}
		}
		if (best > maxd) {
			return maxd + 1
		}
		prev := cur
	}
	return prev[lb+1]
}

MutFuzzBudget(key) {
	local L := StrLen(key)
	return (L < 5) ? 0 : ((L < 8) ? 1 : 2)
}

MutMatchText(text, allowBig := 1, allowFrag := 0) {
	global MutInfo, MutNameList
	MutInit()
	local words := [], w, joined := "", name, key, budget, lw, i, best := "", bestD := 99
	for w in StrSplit(RegExReplace(text, "[\r\n\t]+", " "), " ") {
		key := MutKey(w)
		if (key != "") {
			words.Push(key), joined .= key
		}
	}
	if (joined = "") {
		return ""
	}
	words.Push(joined)
	for name in MutNameList {
		if (!allowBig and name = "Big/Giant") {
			continue
		}
		for key in MutInfo[name].keys {
			budget := MutFuzzBudget(key)
			for w in words {
				lw := StrLen(w)
				if (w == key) {
					return name
				}
				if (budget < 1) {
					continue
				}
				if (Abs(lw - StrLen(key)) <= budget) {
					d := MutEditDistance(w, key, budget)
					if (d <= budget and d < bestD) {
						bestD := d, best := name
					}
				} else if (allowFrag and lw >= 9 and lw >= StrLen(key) - 4 and lw < StrLen(key) and InStr(key, w) and bestD > 1) {
					bestD := 1, best := name
				} else if (lw > StrLen(key) + budget) {
					i := 1
					while (i <= lw - StrLen(key) + 1) {
						d := MutEditDistance(SubStr(w, i, StrLen(key)), key, budget)
						if (d <= budget and d < bestD) {
							bestD := d, best := name
						}
						i += 1
					}
				}
			}
		}
	}
	return best
}

; ---- capture ----------------------------------------------------------------------

MutCapture(x, y, w, h) {
	local hdc, cdc, hbm, obm, bi, bits
	x := Integer(x), y := Integer(y), w := Integer(w), h := Integer(h)
	if (w < 8 or h < 4) {
		return 0
	}
	hdc := DllCall("GetDC", "ptr", 0, "ptr")
	cdc := DllCall("CreateCompatibleDC", "ptr", hdc, "ptr")
	hbm := DllCall("CreateCompatibleBitmap", "ptr", hdc, "int", w, "int", h, "ptr")
	obm := DllCall("SelectObject", "ptr", cdc, "ptr", hbm, "ptr")
	DllCall("BitBlt", "ptr", cdc, "int", 0, "int", 0, "int", w, "int", h, "ptr", hdc, "int", x, "int", y, "uint", 0x00CC0020 | OCR.CAPTUREBLT)
	DllCall("SelectObject", "ptr", cdc, "ptr", obm)
	bi := Buffer(40, 0)
	NumPut("uint", 40, "int", w, "int", -h, "ushort", 1, "ushort", 32, bi)
	bits := Buffer(w*h*4, 0)
	DllCall("GetDIBits", "ptr", cdc, "ptr", hbm, "uint", 0, "uint", h, "ptr", bits, "ptr", bi, "uint", 0)
	DllCall("DeleteObject", "ptr", hbm)
	DllCall("DeleteDC", "ptr", cdc)
	DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)
	return {bits: bits, w: w, h: h}
}

MutCaptureFromFile(path) {
	local pBmp := 0, w := 0, h := 0, bits, rect, data, cap := 0
	if !GdipStart() {
		return 0
	}
	DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", path, "ptr*", &pBmp)
	if (!pBmp) {
		return 0
	}
	DllCall("gdiplus\GdipGetImageWidth", "ptr", pBmp, "uint*", &w)
	DllCall("gdiplus\GdipGetImageHeight", "ptr", pBmp, "uint*", &h)
	bits := Buffer(w*h*4, 0)
	rect := Buffer(16, 0), NumPut("int", 0, "int", 0, "int", w, "int", h, rect)
	data := Buffer(32, 0)
	NumPut("uint", w, "uint", h, "int", w*4, "int", 0x26200A, "ptr", bits.Ptr, data)
	if !DllCall("gdiplus\GdipBitmapLockBits", "ptr", pBmp, "ptr", rect, "uint", 5, "int", 0x26200A, "ptr", data) {
		DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", pBmp, "ptr", data)
		cap := {bits: bits, w: w, h: h}
	}
	DllCall("gdiplus\GdipDisposeImage", "ptr", pBmp)
	return cap
}

MutPad(cap, pad, col := 0xFFFFFF) {
	local w := cap.w + 2*pad, h := cap.h + 2*pad, bits := Buffer(w*h*4, 0), p := 0, row := 0
	loop w*h {
		NumPut("uint", 0xFF000000 | col, bits, p)
		p += 4
	}
	loop cap.h {
		DllCall("ntdll\memcpy", "ptr", bits.Ptr + ((row + pad) * w + pad) * 4, "ptr", cap.bits.Ptr + row * cap.w * 4, "uptr", cap.w*4, "cdecl")
		row += 1
	}
	return {bits: bits, w: w, h: h}
}

MutCrop(cap, x, y, w, h) {
	local bits, row := 0, src, dst
	x := Max(0, Integer(x)), y := Max(0, Integer(y))
	w := Min(Integer(w), cap.w - x), h := Min(Integer(h), cap.h - y)
	if (w < 1 or h < 1) {
		return 0
	}
	bits := Buffer(w*h*4, 0)
	loop h {
		src := cap.bits.Ptr + ((y + row) * cap.w + x) * 4
		dst := bits.Ptr + row * w * 4
		DllCall("ntdll\memcpy", "ptr", dst, "ptr", src, "uptr", w*4, "cdecl")
		row += 1
	}
	return {bits: bits, w: w, h: h}
}

; ---- OCR of a buffer ------------------------------------------------------------------

MutIdentityMatrix() {
	static mat := 0
	if (!mat) {
		mat := Buffer(100, 0)
		NumPut("float", 1.0, mat, 0), NumPut("float", 1.0, mat, 24), NumPut("float", 1.0, mat, 48)
		NumPut("float", 1.0, mat, 92), NumPut("float", 1.0, mat, 96)
	}
	return mat
}

MutOcr(cap, scale, gray := 0, tag := "") {
	local pSrc := 0, pDst := 0, gfx := 0, attr := 0, hbm := 0, r := ""
	local sw := Ceil(cap.w * scale), sh := Ceil(cap.h * scale)
	if !GdipStart() {
		return ""
	}
	if (sw > OCR.MaxImageDimension or sh > OCR.MaxImageDimension) {
		scale := Min(OCR.MaxImageDimension / cap.w, OCR.MaxImageDimension / cap.h)
		sw := Floor(cap.w * scale), sh := Floor(cap.h * scale)
	}
	try {
		DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", cap.w, "int", cap.h, "int", cap.w*4, "int", 0x26200A, "ptr", cap.bits, "ptr*", &pSrc)
		DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", sw, "int", sh, "int", 0, "int", 0x26200A, "ptr", 0, "ptr*", &pDst)
		DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", pDst, "ptr*", &gfx)
		DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gfx, "int", 7)
		DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gfx, "int", 2)
		DllCall("gdiplus\GdipCreateImageAttributes", "ptr*", &attr)
		DllCall("gdiplus\GdipSetImageAttributesColorMatrix", "ptr", attr, "int", 0, "int", 1, "ptr", MutIdentityMatrix(), "ptr", 0, "int", 0)
		DllCall("gdiplus\GdipSetImageAttributesWrapMode", "ptr", attr, "int", 3, "uint", 0, "int", 0)
		DllCall("gdiplus\GdipDrawImageRectRectI", "ptr", gfx, "ptr", pSrc
			, "int", 0, "int", 0, "int", sw, "int", sh, "int", 0, "int", 0, "int", cap.w, "int", cap.h
			, "int", 2, "ptr", attr, "ptr", 0, "ptr", 0)
		DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "ptr", pDst, "ptr*", &hbm, "int", 0xFFFFFFFF)
		r := OCR.FromBitmap(hbm, "en-us", {scale: 1, grayscale: gray})
	}
	if (hbm) {
		DllCall("DeleteObject", "ptr", hbm)
	}
	if (attr) {
		DllCall("gdiplus\GdipDisposeImageAttributes", "ptr", attr)
	}
	if (gfx) {
		DllCall("gdiplus\GdipDeleteGraphics", "ptr", gfx)
	}
	if (pDst) {
		DllCall("gdiplus\GdipDisposeImage", "ptr", pDst)
	}
	if (pSrc) {
		DllCall("gdiplus\GdipDisposeImage", "ptr", pSrc)
	}
	return r
}

MutSaveBitmap(pBitmap, file) {
	local n := 0, sz := 0, buf, off
	DllCall("gdiplus\GdipGetImageEncodersSize", "uint*", &n, "uint*", &sz)
	buf := Buffer(sz, 0)
	DllCall("gdiplus\GdipGetImageEncoders", "uint", n, "uint", sz, "ptr", buf)
	loop n {
		off := (A_Index-1) * (48 + 7*A_PtrSize)
		if InStr(StrGet(NumGet(buf, off + 32 + 3*A_PtrSize, "ptr"), "UTF-16"), "PNG") {
			DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", file, "ptr", buf.Ptr + off, "ptr", 0)
			return
		}
	}
}

MutSaveCapture(cap, file) {
	local pBmp := 0
	if !GdipStart() {
		return
	}
	DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", cap.w, "int", cap.h, "int", cap.w*4, "int", 0x26200A, "ptr", cap.bits, "ptr*", &pBmp)
	if (pBmp) {
		MutSaveBitmap(pBmp, file)
		DllCall("gdiplus\GdipDisposeImage", "ptr", pBmp)
	}
}

MutWords(ocrRes, scale) {
	local out := [], li := 0, line, word
	if (!IsObject(ocrRes)) {
		return out
	}
	try {
		for line in ocrRes.Lines {
			li += 1
			for word in line.Words {
				out.Push({x: word.x / scale, y: word.y / scale, w: word.w / scale, h: word.h / scale, t: word.Text, k: MutKey(word.Text), li: li})
			}
		}
	}
	return out
}

MutIsAnchorWord(k, which) {
	if (StrLen(k) < 5) {
		return 0
	}
	if (InStr(k, which)) {
		return 1
	}
	return MutEditDistance(k, which, 2) <= 2
}

; ---- pixel work on a capture -------------------------------------------------------

MutCountColour(cap, x, y, w, h, col, tol, skipWhite := 0) {
	local n := 0, p, c, yy := 0, xx, tr := (col >> 16) & 0xFF, tg := (col >> 8) & 0xFF, tb := col & 0xFF
	x := Max(0, Integer(x)), y := Max(0, Integer(y))
	w := Min(Integer(w), cap.w - x), h := Min(Integer(h), cap.h - y)
	if (w < 1 or h < 1) {
		return 0
	}
	loop h {
		p := ((y + yy) * cap.w + x) * 4
		xx := 0
		loop w {
			c := NumGet(cap.bits, p, "uint") & 0xFFFFFF
			if (Abs(((c >> 16) & 0xFF) - tr) <= tol and Abs(((c >> 8) & 0xFF) - tg) <= tol and Abs((c & 0xFF) - tb) <= tol and !(skipWhite and c = 0xFFFFFF)) {
				n += 1
			}
			p += 4
		}
		yy += 1
	}
	return n
}

MutSceneColour(cap, edgeRows := 0) {
	local hist := Buffer(3*256*4, 0), p := 0, c, ch, v, n := cap.w * cap.h, out := [0, 0, 0], acc, i, y := 0
	if (edgeRows > 0 and cap.h > 3 * edgeRows) {
		n := 0
		loop cap.h {
			if (y >= edgeRows and y < cap.h - edgeRows) {
				y += 1, p += cap.w * 4
				continue
			}
			loop cap.w {
				c := NumGet(cap.bits, p, "uint")
				NumPut("uint", NumGet(hist, (c & 0xFF)*4, "uint") + 1, hist, (c & 0xFF)*4)
				NumPut("uint", NumGet(hist, 1024 + ((c >> 8) & 0xFF)*4, "uint") + 1, hist, 1024 + ((c >> 8) & 0xFF)*4)
				NumPut("uint", NumGet(hist, 2048 + ((c >> 16) & 0xFF)*4, "uint") + 1, hist, 2048 + ((c >> 16) & 0xFF)*4)
				p += 4, n += 1
			}
			y += 1
		}
	} else {
		loop n {
			c := NumGet(cap.bits, p, "uint")
			NumPut("uint", NumGet(hist, (c & 0xFF)*4, "uint") + 1, hist, (c & 0xFF)*4)
			NumPut("uint", NumGet(hist, 1024 + ((c >> 8) & 0xFF)*4, "uint") + 1, hist, 1024 + ((c >> 8) & 0xFF)*4)
			NumPut("uint", NumGet(hist, 2048 + ((c >> 16) & 0xFF)*4, "uint") + 1, hist, 2048 + ((c >> 16) & 0xFF)*4)
			p += 4
		}
	}
	loop 3 {
		ch := A_Index, acc := 0, i := 0
		while (i < 255) {
			acc += NumGet(hist, (ch-1)*1024 + i*4, "uint")
			if (acc * 2 >= n) {
				break
			}
			i += 1
		}
		out[ch] := i
	}
	return {b: out[1], g: out[2], r: out[3]}
}

MutKeyed(cap, cols) {
	local out := Buffer(cap.w * cap.h * 4, 0), p := 0, c, v, vs, sc := MutSceneColour(cap, 3), ink := 0
	local ks := [], col, dr, dg, db, L2, cosb, f, pTol, k, er, eg, eb, t, perp2
	local kdr, kdg, kdb, kL2, kp2, klo, khi, kspan, scr, scg, scb
	local br := -sc.r, bg := -sc.g, bb := -sc.b, B2 := br*br + bg*bg + bb*bb
	for col in MutGradientSamples(cols) {
		dr := ((col >> 16) & 0xFF) - sc.r, dg := ((col >> 8) & 0xFF) - sc.g, db := (col & 0xFF) - sc.b
		L2 := dr*dr + dg*dg + db*db
		if (L2 < 400) {
			continue
		}
		cosb := (B2 > 0) ? (dr*br + dg*bg + db*bb) / Sqrt(L2 * B2) : 0
		f := (cosb - 0.6) / 0.3
		f := (f < 0) ? 0 : ((f > 1) ? 1 : f)
		pTol := 0.15 * Sqrt(L2)
		pTol := (pTol < 16) ? 16 : ((pTol > 40) ? 40 : pTol)
		ks.Push({dr: dr, dg: dg, db: db, L2: L2, p2: pTol * pTol, lo: 0.3 + 0.52 * f, hi: 0.7 + 0.25 * f})
	}
	if (ks.Length = 1) {
		k := ks[1]
		kdr := k.dr, kdg := k.dg, kdb := k.db, kL2 := k.L2, kp2 := k.p2, klo := k.lo, khi := k.hi, kspan := k.hi - k.lo
		scr := sc.r, scg := sc.g, scb := sc.b
		loop cap.w * cap.h {
			v := 255
			c := NumGet(cap.bits, p, "uint")
			er := ((c >> 16) & 0xFF) - scr, eg := ((c >> 8) & 0xFF) - scg, eb := (c & 0xFF) - scb
			t := (er*kdr + eg*kdg + eb*kdb) / kL2
			if (t > klo and t <= 1.2) {
				perp2 := er*er + eg*eg + eb*eb - t*t*kL2
				if (perp2 <= kp2) {
					vs := (t >= khi) ? 0 : Round(255 * (khi - t) / kspan)
					if (vs < v) {
						v := vs
					}
				}
			}
			if (v < 128) {
				ink += 1
			}
			NumPut("uint", 0xFF000000 | (v << 16) | (v << 8) | v, out, p)
			p += 4
		}
	} else {
		loop cap.w * cap.h {
			v := 255
			if (ks.Length) {
				c := NumGet(cap.bits, p, "uint")
				er := ((c >> 16) & 0xFF) - sc.r, eg := ((c >> 8) & 0xFF) - sc.g, eb := (c & 0xFF) - sc.b
				for k in ks {
					t := (er*k.dr + eg*k.dg + eb*k.db) / k.L2
					if (t <= k.lo or t > 1.2) {
						continue
					}
					perp2 := er*er + eg*eg + eb*eb - t*t*k.L2
					if (perp2 > k.p2) {
						continue
					}
					vs := (t >= k.hi) ? 0 : Round(255 * (k.hi - t) / (k.hi - k.lo))
					if (vs < v) {
						v := vs
					}
				}
			}
			if (v < 128) {
				ink += 1
			}
			NumPut("uint", 0xFF000000 | (v << 16) | (v << 8) | v, out, p)
			p += 4
		}
	}
	if (ink * 3 > cap.w * cap.h) {
		p := 0
		loop cap.w * cap.h {
			NumPut("uint", 0xFFFFFFFF, out, p)
			p += 4
		}
		ink := 0
	}
	return {bits: out, w: cap.w, h: cap.h, ink: ink}
}

MutThicken(img) {
	local out := Buffer(img.w * img.h * 4, 0), x, y := 0, p := 0, v, a, b
	loop img.h {
		x := 0
		loop img.w {
			v := NumGet(img.bits, p, "uint") & 0xFF
			if (x > 0) {
				a := NumGet(img.bits, p - 4, "uint") & 0xFF
				v := (a < v) ? a : v
			}
			if (y > 0) {
				b := NumGet(img.bits, p - img.w * 4, "uint") & 0xFF
				v := (b < v) ? b : v
			}
			NumPut("uint", 0xFF000000 | (v << 16) | (v << 8) | v, out, p)
			p += 4, x += 1
		}
		y += 1
	}
	return {bits: out, w: img.w, h: img.h}
}

MutSceneLevel(cap) {
	local hist := Buffer(256*4, 0), p := 0, c, r, g, b, v, acc := 0, i := 0, n := cap.w * cap.h
	loop n {
		c := NumGet(cap.bits, p, "uint")
		r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
		v := (r > g) ? ((r > b) ? r : b) : ((g > b) ? g : b)
		NumPut("uint", NumGet(hist, v*4, "uint") + 1, hist, v*4)
		p += 4
	}
	while (i < 255) {
		acc += NumGet(hist, i*4, "uint")
		if (acc * 2 >= n) {
			break
		}
		i += 1
	}
	return i
}

MutContrast(cap, mode) {
	local out := Buffer(cap.w * cap.h * 4, 0), p := 0, c, r, g, b, v, d, lvl := MutSceneLevel(cap), o
	local t0 := Max(10, Round(lvl * 0.18)), t1 := Max(24, Round(lvl * 0.42))
	loop cap.w * cap.h {
		c := NumGet(cap.bits, p, "uint")
		r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
		v := (r > g) ? ((r > b) ? r : b) : ((g > b) ? g : b)
		d := (mode = "dark") ? (lvl - v) : (v - lvl)
		o := (d <= t0) ? 255 : ((d >= t1) ? 0 : Round(255 - 255 * (d - t0) / (t1 - t0)))
		NumPut("uint", 0xFF000000 | (o << 16) | (o << 8) | o, out, p)
		p += 4
	}
	return {bits: out, w: cap.w, h: cap.h}
}

MutColoursPresent(cap, x, y, w, h, tol) {
	global MutInfo, MutNameList
	local out := [], seen := Map(), name, col, n, c
	MutInit()
	for name in MutNameList {
		col := MutInfo[name].col
		if (col < 0 or seen.Has(col)) {
			continue
		}
		seen[col] := 1
		n := 0
		if (name = "Albino") {
			n := MutCountColour(cap, x, y, w, h, col, 6, 1)
		} else {
			for c in MutGradientSamples(MutInfo[name].cols) {
				n := Max(n, MutCountColour(cap, x, y, w, h, c, tol))
			}
		}
		if (n > 0) {
			out.Push({name: name, n: n})
		}
	}
	local i := 2, j, v
	while (i <= out.Length) {
		v := out[i], j := i - 1
		while (j >= 1 and out[j].n < v.n) {
			out[j+1] := out[j], j -= 1
		}
		out[j+1] := v
		i += 1
	}
	return out
}

MutColourAgrees(cap, x, y, w, h, name, minPx) {
	local col := MutColour(name), c
	if (col < 0) {
		return 1
	}
	if (name = "Albino") {
		return MutCountColour(cap, x, y, w, h, col, 6, 1) >= minPx
	}
	for c in MutGradientSamples(MutColours(name)) {
		if (MutCountColour(cap, x, y, w, h, c, 24) >= minPx) {
			return 1
		}
	}
	return 0
}

; ---- the scan ---------------------------------------------------------------------

MutIsAttr(name) {
	return (name = "Shiny" or name = "Sparkling" or name = "Big/Giant")
}

MutLineWords(words, li) {
	local out := [], w, i, j, v
	for w in words {
		if (w.li = li) {
			out.Push(w)
		}
	}
	i := 2
	while (i <= out.Length) {
		v := out[i], j := i - 1
		while (j >= 1 and out[j].x > v.x) {
			out[j+1] := out[j], j -= 1
		}
		out[j+1] := v
		i += 1
	}
	return out
}

MutStack(images, gap, pad) {
	local w := images[1].w + 2*pad, h := 2*pad - gap, img, bits, p := 0, rows := [], y := pad, row
	for img in images {
		h += img.h + gap
	}
	bits := Buffer(w*h*4, 0)
	loop w*h {
		NumPut("uint", 0xFFFFFFFF, bits, p)
		p += 4
	}
	for img in images {
		rows.Push({y0: y, h: img.h})
		row := 0
		loop img.h {
			DllCall("ntdll\memcpy", "ptr", bits.Ptr + ((y + row) * w + pad) * 4, "ptr", img.bits.Ptr + row * img.w * 4, "uptr", img.w*4, "cdecl")
			row += 1
		}
		y += img.h + gap
	}
	return {bits: bits, w: w, h: h, rows: rows, pad: pad}
}

MutCounterOf(t) {
	local m, u
	if (RegExMatch(t, "i)kg")) {
		return -1
	}
	u := RegExReplace(t, "[lI|]", "1"), u := StrReplace(u, "S", "5"), u := StrReplace(u, "O", "0"), u := StrReplace(u, "B", "8")
	if (RegExMatch(u, "i)[x×]\s*(\d+)\s*\)", &m) or RegExMatch(u, "\(\s*[x×]?\s*(\d+)\s*\)", &m)) {
		return Integer(m[1])
	}
	if (RegExMatch(u, "^\W*8(\d+)\)", &m) or RegExMatch(u, "^\W*(\d+)\)", &m)) {
		return Integer(m[1])
	}
	return -1
}

MutTakeName(cap, text, x, y, w, h, th, seen, attrs, best, how, wide := 0, trust := 0) {
	global MutInfo
	local m := MutMatchText(text, 1, best.frag), exact := 0, k
	if (m = "") {
		return ""
	}
	if (seen.Has(m) or (wide and best.rejected.Has(m))) {
		return "seen"
	}
	if (!MutColourAgrees(cap, x - 2, y - 2, w + 4, h + 4, m, Max(3, MutMinPixels(th) // 2))) {
		if (trust and !wide) {
			for k in MutInfo[m].keys {
				if (MutKey(text) == k) {
					exact := 1
				}
			}
		}
		if (!exact) {
			best.dbg .= "(" m " wrong colour) "
			if (!wide) {
				best.rejected[m] := 1
			}
			return "rejected"
		}
		best.dbg .= "(" m " by text alone) "
		how .= ", colour unseen"
	}
	seen[m] := 1
	if (MutIsAttr(m)) {
		attrs.Push(m)
	} else if (best.name = "") {
		best.name := m, best.how := how
	}
	return "taken"
}

MutRegionRead(cap, words, li, xLeft, xRight, th, lineTop, lineBot, textOnly, deep, attrs, trust := 0) {
	local best := {name: "", how: "", text: "", dbg: "", rejected: Map(), frag: trust}, w, m, joined := "", seen := Map(), st
	local sub, subScale, images, hows, cand, sc, stack, ocrRes2, ws, row, ri, rowText, pad, img
	if (xRight - xLeft < 4) {
		return best
	}
	for w in MutLineWords(words, li) {
		if (w.x + w.w <= xLeft or w.x >= xRight) {
			continue
		}
		if (StrLen(w.k) < 3 or RegExMatch(w.t, "\d")) {
			continue
		}
		st := MutTakeName(cap, w.t, w.x, w.y, w.w, w.h, th, seen, attrs, best, "text", 0, trust)
		if (st != "taken" and st != "seen") {
			joined .= w.t " "
		}
	}
	best.text := Trim(joined)
	if (best.name = "" and joined != "") {
		MutTakeName(cap, joined, xLeft, lineTop, xRight - xLeft, lineBot - lineTop, th, seen, attrs, best, "text", 1)
	}
	if (best.name != "" or textOnly or th <= 0 or lineBot <= lineTop) {
		return best
	}
	sub := MutCrop(cap, Round(xLeft), Max(0, Round(lineTop - 3)), Round(xRight - xLeft), Round(lineBot - lineTop + 6))
	if (!IsObject(sub)) {
		return best
	}
	images := [MutContrast(sub, "bright")], hows := ["bright"]
	for cand in MutColoursPresent(sub, 0, 0, sub.w, sub.h, 10) {
		best.dbg .= cand.name ":" cand.n " "
		if (cand.n >= MutMinPixels(th) and cand.n * 2 <= sub.w * sub.h and images.Length < 6 and (MutDeepOn() or !MutIsHard(cand.name))) {
			images.Push(MutKeyed(sub, MutColours(cand.name))), hows.Push("keyed " cand.name)
		}
	}
	if (deep) {
		images.Push(MutContrast(sub, "dark")), hows.Push("dark")
	}
	pad := Max(6, Round(th))
	stack := MutStack(images, pad, pad)
	subScale := Max(4, Min(10, Round(100 / Max(6, th))))
	for sc in [subScale, Max(3, subScale // 2)] {
		ocrRes2 := MutOcr(stack, sc, 0, "stack")
		ws := MutWords(ocrRes2, sc)
		for ri, row in stack.rows {
			rowText := ""
			for w in ws {
				if (w.y + w.h / 2 < row.y0 or w.y + w.h / 2 >= row.y0 + row.h) {
					continue
				}
				rowText .= w.t " "
				if (StrLen(w.k) < 3 or RegExMatch(w.t, "\d")) {
					continue
				}
				MutTakeName(sub, w.t, w.x - pad, w.y - row.y0, w.w, w.h, th, seen, attrs, best, hows[ri])
			}
			best.dbg .= "| " hows[ri] "@" sc "=" Trim(rowText) " "
			if (best.name = "" and rowText != "") {
				MutTakeName(sub, rowText, 0, 0, sub.w, sub.h, th, seen, attrs, best, hows[ri], 1)
			}
		}
		if (best.name != "") {
			return best
		}
	}
	if (!deep or !MutDeepOn()) {
		return best
	}
	for ri, img in images {
		if (img.HasOwnProp("ink") and img.ink < MutMinPixels(th)) {
			continue
		}
		for sc in [subScale, Max(3, subScale // 2)] {
			ocrRes2 := MutOcr(MutPad(img, pad), sc, 0, "single")
			rowText := ""
			for w in MutWords(ocrRes2, sc) {
				rowText .= w.t " "
				if (StrLen(w.k) < 3 or RegExMatch(w.t, "\d")) {
					continue
				}
				MutTakeName(sub, w.t, w.x - pad, w.y - pad, w.w, w.h, th, seen, attrs, best, hows[ri] " alone")
			}
			best.dbg .= "| " hows[ri] " alone@" sc "=" Trim(rowText) " "
			if (best.name = "" and rowText != "") {
				MutTakeName(sub, rowText, 0, 0, sub.w, sub.h, th, seen, attrs, best, hows[ri] " alone", 1)
			}
			if (best.name != "") {
				return best
			}
		}
	}
	for ri, img in images {
		if (SubStr(hows[ri], 1, 5) != "keyed" or !img.HasOwnProp("ink") or img.ink < MutMinPixels(th)) {
			continue
		}
		for sc in [subScale, Max(3, subScale // 2)] {
			ocrRes2 := MutOcr(MutPad(MutThicken(img), pad), sc, 0, "thick")
			rowText := ""
			for w in MutWords(ocrRes2, sc) {
				rowText .= w.t " "
				if (StrLen(w.k) < 3 or RegExMatch(w.t, "\d")) {
					continue
				}
				MutTakeName(sub, w.t, w.x - pad, w.y - pad, w.w, w.h, th, seen, attrs, best, hows[ri] " thick")
			}
			best.dbg .= "| " hows[ri] " thick@" sc "=" Trim(rowText) " "
			if (best.name = "" and rowText != "") {
				MutTakeName(sub, rowText, 0, 0, sub.w, sub.h, th, seen, attrs, best, hows[ri] " thick", 1)
			}
			if (best.name != "") {
				return best
			}
		}
	}
	return best
}

MutScan(cap, light := 0) {
	local res := {name: "", how: "", kind: "", before: "", attrs: [], appraised: 0, anchor: 0, complete: 0, counter: -1, sig: "", focus: 0, th: 0, nameBox: 0, nameText: "", allText: "", words: [], dbg: ""}
	local ocrRes, words, w, pass, scale, anchorLi := 0, changedLi := 0, appraisedLi := 0, weightLi := 0, lastLi
	local lw, lineTop, lineBot, ths, th1 := 0, th3 := 0, xLeft, xRight, aRight, nameLeft, m, r, gluedX
	local fMinX, fMinY, fMaxY, removed := 0, changed := 0, wd
	local plain := {words: [], anchorLi: 0, changedLi: 0, appraisedLi: 0, weightLi: 0}, plainCounter := -1, realAnchor := 0, changedRight := 0
	local redrawn := 0, l1Words, l1Li, l1WeightLi, l1AnchorLi, src
	if (!IsObject(cap)) {
		return res
	}
	scale := 3
	for pass in ["plain", "bright", "white", "dark"] {
		if ((pass = "bright" or pass = "white") and (anchorLi or (light and appraisedLi))) {
			break
		}
		if (pass = "dark" and (anchorLi or appraisedLi or plain.appraisedLi or IsObject(redrawn))) {
			break
		}
		ocrRes := MutOcr((pass = "plain") ? cap : (pass = "white") ? MutKeyed(cap, [0xFFFFFF]) : MutContrast(cap, pass), scale, 0, pass)
		words := MutWords(ocrRes, scale)
		anchorLi := 0, changedLi := 0, appraisedLi := 0, weightLi := 0, changedRight := 0
		for w in words {
			if (weightLi = 0 and (MutIsAnchorWord(w.k, "weight") or MutIsAnchorWord(w.k, "depressed") or RegExMatch(w.t, "i)\d\s*kg$"))) {
				weightLi := w.li
			}
		}
		for w in words {
			if (anchorLi = 0 and MutIsAnchorWord(w.k, "mutation")) {
				anchorLi := w.li
			}
			if (MutIsAnchorWord(w.k, "changed")) {
				changedLi := w.li, changedRight := w.x + w.w
			}
			if (appraisedLi = 0 and w.li != weightLi and MutIsAnchorWord(w.k, "appraised")) {
				appraisedLi := w.li
			}
		}
		realAnchor := anchorLi
		if (!anchorLi) {
			anchorLi := changedLi
		}
		if (!appraisedLi) {
			for w in words {
				if (w.li != weightLi and (w.li != anchorLi or (!realAnchor and w.x > changedRight + 2 * w.h)) and MutCounterOf(w.t) >= 0) {
					appraisedLi := w.li
					break
				}
			}
		}
		if (!appraisedLi and weightLi > 1) {
			appraisedLi := (weightLi - 1 = anchorLi) ? weightLi - 2 : weightLi - 1
		}
		if (appraisedLi and anchorLi and anchorLi <= appraisedLi) {
			anchorLi := 0
		}
		if (pass = "plain") {
			res.words := words
			try res.allText := IsObject(ocrRes) ? ocrRes.Text : ""
			plain := {words: words, anchorLi: anchorLi, changedLi: changedLi, appraisedLi: appraisedLi, weightLi: weightLi}
			for w in words {
				if (w.li != anchorLi and w.li != weightLi and (!appraisedLi or w.li = appraisedLi) and MutCounterOf(w.t) >= 0) {
					plainCounter := MutCounterOf(w.t)
				}
			}
		}
		if (pass != "plain" and appraisedLi and !IsObject(redrawn)) {
			redrawn := {words: words, anchorLi: anchorLi, changedLi: changedLi, appraisedLi: appraisedLi, weightLi: weightLi}
		}
		if (anchorLi or appraisedLi) {
			res.dbg .= "read:" pass " "
		}
	}
	if (!anchorLi) {
		src := plain.appraisedLi ? plain : (IsObject(redrawn) ? redrawn : plain)
		words := src.words, anchorLi := src.anchorLi, changedLi := src.changedLi, appraisedLi := src.appraisedLi, weightLi := src.weightLi
	}
	l1Words := words, l1Li := appraisedLi, l1WeightLi := weightLi, l1AnchorLi := anchorLi
	if (anchorLi and words != plain.words) {
		src := plain.appraisedLi ? plain : ((IsObject(redrawn) and redrawn.words != words) ? redrawn : 0)
		if (IsObject(src)) {
			l1Words := src.words, l1Li := src.appraisedLi, l1WeightLi := src.weightLi, l1AnchorLi := src.anchorLi
		}
	}
	; ---- third line ----
	if (anchorLi) {
		res.anchor := 1
		lw := MutLineWords(words, anchorLi)
		lineTop := cap.h, lineBot := 0, ths := [], aRight := 0, gluedX := -1
		for w in lw {
			lineTop := Min(lineTop, w.y), lineBot := Max(lineBot, w.y + w.h), ths.Push(w.h)
			if (MutIsAnchorWord(w.k, "mutation") or MutIsAnchorWord(w.k, "changed") or MutIsAnchorWord(w.k, "removed")) {
				if (InStr(w.k, "changed") and StrLen(w.k) - InStr(w.k, "changed") - StrLen("changed") + 1 >= 4) {
					gluedX := w.x
				} else {
					aRight := Max(aRight, w.x + w.w)
				}
			}
			if (MutIsAnchorWord(w.k, "removed")) {
				removed := 1
			}
			if (MutIsAnchorWord(w.k, "changed")) {
				changed := 1
			}
		}
		res.kind := removed ? "removed" : (changed ? "changed" : "")
		th3 := MutMedian(ths)
		nameLeft := aRight + 2
		for w in lw {
			if (w.x >= aRight - 2 and StrLen(w.k) <= 1 and w.x + w.w + 2 > nameLeft and w.x < nameLeft + th3 * 1.5) {
				nameLeft := w.x + w.w + 2
			}
		}
		if (gluedX >= 0) {
			nameLeft := Min(nameLeft, gluedX)
		}
		res.nameBox := {x: Round(nameLeft), y: Max(0, Round(lineTop - 3)), w: Round(cap.w - nameLeft), h: Round(lineBot - lineTop + 6)}
		if (!removed) {
			r := MutRegionRead(cap, words, anchorLi, nameLeft, cap.w, th3, lineTop, lineBot, light, 1, res.attrs, 1)
			res.name := r.name, res.how := r.how, res.nameText := r.text, res.dbg .= "L3 " r.dbg
		}
	}
	; ---- first line ----
	if (l1Li) {
		res.appraised := 1
		lw := MutLineWords(l1Words, l1Li)
		lineTop := cap.h, lineBot := 0, ths := [], xLeft := 0, xRight := cap.w
		for w in lw {
			lineTop := Min(lineTop, w.y), lineBot := Max(lineBot, w.y + w.h), ths.Push(w.h)
			if (MutIsAnchorWord(w.k, "appraised")) {
				xLeft := (StrLen(w.k) >= StrLen("appraised") + 4) ? w.x : w.x + w.w + 2
			}
			if (MutCounterOf(w.t) >= 0) {
				res.counter := MutCounterOf(w.t), xRight := Min(xRight, w.x - 1)
			}
		}
		if (res.counter < 0) {
			res.counter := plainCounter
		}
		th1 := MutMedian(ths)
		lastLi := (l1AnchorLi or l1WeightLi) ? Max(l1Li + 1, l1AnchorLi, l1WeightLi) : l1Li + 2
		fMinX := cap.w, fMinY := cap.h, fMaxY := 0, wd := ""
		for w in l1Words {
			if (w.li >= l1Li and w.li <= lastLi) {
				fMinX := Min(fMinX, w.x), fMinY := Min(fMinY, w.y), fMaxY := Max(fMaxY, w.y + w.h)
				if (w.li = (l1WeightLi ? l1WeightLi : l1Li + 1) and RegExMatch(w.t, "\d")) {
					wd .= RegExReplace(w.t, "[^0-9]+", "")
				}
			}
		}
		res.sig := ((res.counter >= 0) ? res.counter : "") "|" RegExReplace(wd, "^0+")
		if (fMaxY > fMinY and th1 > 0) {
			res.focus := {x: Max(0, Floor(fMinX - 5 * th1)), y: Max(0, Floor(fMinY - th1))}
			res.focus.w := cap.w - res.focus.x
			res.focus.h := Min(cap.h, Ceil(fMaxY + th1 + (l1AnchorLi ? 0 : 1.6 * th1))) - res.focus.y
		}
		r := MutRegionRead(cap, l1Words, l1Li, xLeft, xRight, th1, lineTop, lineBot, light or anchorLi, 0, res.attrs)
		res.before := r.name, res.dbg .= "L1 " r.dbg
		if (!anchorLi) {
			res.name := r.name, res.how := r.how, res.nameText := r.text
		}
	}
	res.th := th3 ? th3 : th1
	res.complete := res.appraised and (!res.anchor or res.kind = "removed" or res.name != "" or !MutDeepOn())
	if (res.appraised or res.anchor) {
		return res
	}
	m := MutMatchText(res.allText, 0)
	if (m != "" and MutColourAgrees(cap, 0, 0, cap.w, cap.h, m, 8)) {
		res.name := m, res.how := "loose"
	}
	return res
}

MutMinPixels(th) {
	local n := Round(th * th * 0.06)
	return (n < 4) ? 4 : n
}

MutMedian(arr) {
	local a := [], i := 2, j, v
	if (!arr.Length) {
		return 0
	}
	for v in arr {
		a.Push(v)
	}
	while (i <= a.Length) {
		v := a[i], j := i - 1
		while (j >= 1 and a[j] > v) {
			a[j+1] := a[j], j -= 1
		}
		a[j+1] := v
		i += 1
	}
	return a[(a.Length + 1) // 2]
}
; ============================ End mutation detection ============================
