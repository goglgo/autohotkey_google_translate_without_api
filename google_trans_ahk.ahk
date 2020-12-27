#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%
#Include %A_ScriptDir%\lib\URLBase.ahk
#Include %A_ScriptDir%\lib\URL_Encoder.ahk
#Include %A_ScriptDir%\lib\Json.ahk
; #Include %A_ScriptDir%\lib\Euc-kr.ahk
; #Include %A_ScriptDir%\lib\create_form_data.ahk

; Refereced From:
; https://github.com/ssut/py-googletrans/tree/master

; ///////
; 사용 예시:
; want_text := "안녕하세요"
; tl := "en" ; or en. it means target_language

; translator := new Translate(tl)
; res := translator.translate(want_text)
; Msgbox,% res
; ///////



global tl



gui, add, edit, w200 vTranslateText, 안녕하세요
gui, add, radio, w200 r2 vToKor_is_checked, 한국어로
gui, add, radio, w200 vToENG_is_checked Checked, 영어로
gui, add, button, w200 gdo_translate, 번역
gui, show
return 


do_translate:
Gui, Submit, Nohide

if ToKor_is_checked
{
    tl := "ko"
}
if ToENG_is_checked
{
    tl := "en"
}
translator := new Translate(tl)

res := translator.translate(TranslateText)
Msgbox,% res

translator := ""
return


f2::
GuiClose:
Exitapp


class Translate
{
    __New(target_language)
    {
        ; > maybe deprecate TokenAcquirer class
        ; this.acquirer := new TokenAcquirer()

        this.httpobj := ""
        this.RPC_ID := "MkEWBc"
        this.URL_BASE := ""
        this.ua := "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        this.tl := target_language

        this.httpobj_set()

        this.TRANSLATE_RPC := "/_/TranslateWebserverUi/data/batchexecute"

    }

    httpobj_set()
    {
        this.httpobj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    }
    
    _translate(text)
    {
        ; TRANSLATE = 'https://{host}/translate_a/single'
        ; TRANSLATE_RPC = '/_/TranslateWebserverUi/data/batchexecute'
        ; translate.google.com
        ; params = {
        ;     'rpcids': RPC_ID,
        ;     'bl': 'boq_translate-webserver_20201207.13_p0',
        ;     'soc-app': 1,
        ;     'soc-platform': 1,
        ;     'soc-device': 1,
        ;     'rt': 'c',
        ; }

        this.URL_BASE := new ServiceURL()

        url := this.URL_BASE . this.TRANSLATE_RPC

        t := [this.RPC_ID, "boq_translate-webserver_20201207.13_p0", 1, 1, 1, "c"]
        parameter := Format("?rpcids={1}&bl={2}&soc-app={3}&soc-platform={4}&soc-device={5}&rt={6}", t*)

        completed_url := url . parameter
        completed_url := completed_url . "&f.req=" . this._build_rpc_request(text, this.tl, "auto")
        completed_url := URLEncode(completed_url)

        this.httpobj.Open("POST", completed_url)
        this.httpobj.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        this.httpobj.SetRequestHeader("Referer", "translate.google.com")
        this.httpobj.SetRequestHeader("User-Agent", this.ua)
        this.httpobj.Send()

        this.httpobj.WaitForResponse
        res := this.httpobj
        return res
    }

    translate(text)
    {
        ; // Todo: 예외처리 추가 필요
        origin := text
        data := this._translate(text)
        data_txt := data.Responsetext()

        Loop, Parse, data_txt, `n, `r
        {
            ; Msgbox,% A_LoopField
            IfInString, A_LoopField, % this.RPC_ID
            {
                result_text := A_LoopField
                break
            }
        }
        
        res := Jxon_Load(result_text)
        ; final_result : json format
        ; it needs to be reload with Jxon_load function.
        final_result := res[1][3]
        return final_result
    }

    trasnlate_not_work(text)
    {
        tk := this.acquirer.acquire(text, host=this.URL_base)
        URL := this.URL_base . "/translate_a/single?client=webapp&sl=auto&tl=" . this.tl . "&hl=ko&dt=at&dt=bd&dt=ex&dt=ld&dt=md&dt=qca&dt=rw&dt=rm&dt=sos&dt=ss&dt=t&otf=1&ssel=0&tsel=0&tk=" . tk . "&q=" . text
        URL := URLEncode(URL)

        httpobj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        httpobj.Open("get", URL)
        httpobj.SetRequestHeader("Accept", "*/*")
        httpobj.SetRequestHeader("Connection", "keep-alive")
        httpobj.SetRequestHeader("Referer", this.URL_base . "/?hl=ko")
        httpobj.SetRequestHeader("TE","Trailers")
        httpobj.SetRequestHeader("User-Agent", this.ua)
        httpobj.Send()
        httpobj.WaitForResponse
        res_txt := httpobj.Responsetext()
        httpobj := ""
        return res_txt
    }

    _build_rpc_request(text, dest="en", src="auto")
    {
        ; build_rpc_res : 안녕하세요 >> 
        ; [[["MkEWBc","[[\"\\uc548\\ub155\\ud558\\uc138\\uc694\",\"auto\",\"en\",true],[null]]",null,"generic"]]]
        this.RPC_ID := "MkEWBc"
        ; Msgbox,% dest
        data1 := Array(Array(text, src, dest, "{%escape true%}"), "{%escape [null]%}")
        data2 := Array(Array(Array(this.RPC_ID, Jxon_Dump(data1), "{%escape null%}", "generic")))
        
        res := Jxon_Dump(data2)
        
        StringReplace, res, res, `\`"{`%escape true`%}`\`", true, All
        StringReplace, res, res, `\`"{`%escape [null]`%}`\`", [null], All
        StringReplace, res, res, "{`%escape null`%}`", null, All

        return res
    }

    __delete()
    {
        this.acquirer := ""
    }
}


; Not working Now.
class TokenAcquirer
{
    __New(tkk=0, host="https://translate.google.co.kr", client=""){
        if (client="")
        {
            throw, "Need http client to get the tkk value."
            ; this.client := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        }
        this.tkk := tkk
        this.host := host
        this.ua := "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    }

    _xr(a,b){
        size_b := StrLen(b)
        c := 0
        b_split := StrSplit(b)
        while c < size_b -1
        {
            ; autohotkey > array begin 1 ( +1 )
            d := b_split[c+3]
            if d is Integer
            {   
                d := d*1
            }
            else
            {
                d:= Ord(d) - 87
            }

            if b_split[c+2] == "+"
                d := a >> d
            else 
                d := a << d
            if "+" = b_split[c+1]
                a := a + d & 4294967295
            else
                a := a^d
            
            c+=3
        }
        return a
    }

    _update(){
        ; T := 31536000*(A_YYYY-1970) + (A_Yday+Floor((A_YYYY-1972)/4))*86400 + A_Hour*3600 + A_Min*60 + A_Sec
        ; now := (T*1000)//3600000 - 33 ; ?????? ??????? ??? 33??? ?? ?±淡 ????????
        UnixTime := A_Now
        UnixTime -= 19700101000000, Sec
        if (Floor(this.tkk // 1) == UnixTime){
            return
        }

        this.client.Open("get", this.host)
        this.client.SetRequestHeader("User-Agent",this.ua)
        this.client.Send()
        this.client.WaitForResponse
        r := this.client.Responsetext()
        ; tkk:\'(.+?)\'
        RegexMatch(r, "tkk:\'(.+?)\'", raw_tkk)
        OutputDebug,raw_tkk %raw_tkk1%
        this.tkk := raw_tkk1
        
    }

    acquire(text){
        this._update()
        a := []
        Loop, Parse, text
        {
            val := Ord(A_LoopField)
            if(val < 0x10000){
                a.Push(val)
            }
            else{
                a.Push(floor((val - 0x10000) / 0x400 + 0xD800))
                a.Push(floor(mod((val - 0x10000) , 0x400) + 0xDC00))
            }
            
        }

        if this.tkk != 0
            b:= this.tkk
        else 
            b:=""
        
        ; autohotkey?? 13131.1111 ?? ????????? ?ν????? ??????..
        d := Floor(b // 1)
        d0 := Floor(b // 1)
        d1 := round((b-d0)*10000000000)
        if(mod(200,10) = 0) {
            d1 := d1 // 10
        }
        b := d
        e := []
        g := 0

        size := a.MaxIndex()
        while g<size+1
        {
            l := a[g]
            if l < 128
            {
                e.Push(l)
            }
            else
            {
                if l < 2048
                {
                    e.Push(l >> 6 | 192)
                }

                else
                {
                    if (l & 64512 = 55296) && (g + 1 < size) && (a[g + 1] & 64512 = 56320)
                    {
                        g := g+1
                        l := 65536 + ((l & 1023) << 10) + (a[g] & 1023)
                        e.Push(l >> 18 | 240)
                        e.Push(l >> 12 & 63 | 128)
                    }
                    else
                    {
                        e.Push(l >> 12 | 224)
                    }
                    e.Push(l >> 6 & 63 | 128)
                }
                e.Push(l & 63 | 128)
            }
            g += 1
        }

        a := d0
        for value in e
        {
            if e[value] = ""
                continue
            a += e[value]
            a := this._xr(a, "+-a^+6")
        }
        OutputDebug, % "alalalmost before:" . a
        a := this._xr(a, "+-3^+b+-f")
        OutputDebug, % "before a^ before:" . a
        a ^= d1
        OutputDebug, % "almost last a_val:" . a . " d1_val:" . d1
        ; a += 1
        
        if a<0
        {
            a := (a & 2147483647) + 2147483648
        }

        a := mod(a, 1000000)
        OutputDebug,% "total_result:" . a . "." a^b
        return a . "." a^b
    }

    __Delete()
    {
        this.client := ""
    }


}




