#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%
#Include %A_ScriptDir%\lib\URLBase.ahk
#Include %A_ScriptDir%\lib\URL_Encoder.ahk

; 예시: 
want_text := "masterpiece"
tl := "ko" ; or en. it means target_language

translator := new Translate(tl)
res := translator.trnaslate(want_text)
msgbox,% res
return 


f2::exitapp


class Translate
{
    __New(target_language)
    {
        this.tl := target_language
        this.acquirer := new TokenAcquirer()
        this.URL_base := new ServiceURL()
        this.ua := "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    }
    
    trnaslate(text)
    {
        tk := this.acquirer.acquire(text, host=this.URL_base)
        URL := this.URL_base . "/translate_a/single?client=webapp&sl=auto&tl=" . this.tl . "&hl=ko&dt=at&dt=bd&dt=ex&dt=ld&dt=md&dt=qca&dt=rw&dt=rm&dt=sos&dt=ss&dt=t&otf=1&ssel=0&tsel=0&tk=" . tk . "&q=" . text
        URL := URLEncode(URL)

        httpobj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        httpobj.Open("get", URL)
        httpobj.SetRequestHeader("Accept", "*/*")
        httpobj.SetRequestHeader("Connection", "keep-alive")
        ; httpobj.SetRequestHeader("HOST", this.URL_base)
        httpobj.SetRequestHeader("Referer", this.URL_base . "/?hl=ko")
        httpobj.SetRequestHeader("TE","Trailers")
        httpobj.SetRequestHeader("User-Agent", this.ua)
        httpobj.Send()
        httpobj.WaitForResponse
        return httpobj.Responsetext()
    }
}


class TokenAcquirer
{
    __New(tkk=0, host="https://translate.google.co.kr"){
        this.client := ComObjCreate("WinHttp.WinHttpRequest.5.1")
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
        T := 31536000*(A_YYYY-1970) + (A_Yday+Floor((A_YYYY-1972)/4))*86400 + A_Hour*3600 + A_Min*60 + A_Sec
        now := (T*1000)//3600000 - 33 ; 왜인지 모르겠지만 항상 33만큼 안 맞길래 끼워맞춤
        if (Floor(this.tkk // 1) == now){
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
        
        ; autohotkey는 13131.1111 을 스트링으로 인식하지 못하네요..
        d := Floor(b // 1)
        d0 := Floor(b // 1)
        d1 := round((b-d0)*10000000000)
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


}




