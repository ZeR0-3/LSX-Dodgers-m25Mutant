; EGREP.COM - 行の検索(正規表現つき)。 egrep [-ivncl wohHn] [-A n] [-B n] [-C n] パターン [file ...]     MIT License
;   パターン: 文字 . [abc] [a-z] [^x] ^ $ * + ? | ( ) \x \< \>   (全角の Shift_JIS は2バイトで1文字)。空白を含むときは "..." で囲む。
;   -i 大文字小文字を無視  -v 一致しない行  -n 行番号  -c 一致した行数だけ  -l 一致したファイル名だけ
;   -w 単語として一致(\<( ... )\> で囲む)  -o 一致した部分だけ  -h ファイル名をつけない  -A n 後ろ n 行  -B n 前 n 行  -C n 前後 n 行(n は0-9)
;   file は複数、ワイルドカード(* ?)可(カレントまたは d:path\ の中)。省略=標準入力。複数ファイルのとき行頭に ファイル名: をつける。
;   終了コード $? : 一致あり 0 / なし 1 / 開けないファイルあり 2
	org 0100h
	ld sp,0A000h
	ld hl,0080h
	ld a,(hl)
	inc hl
	ld c,a
	ld b,0
	ld de,cmd
	or a
	jr z,nc0
	ldir
nc0:	xor a
	ld (de),a
	ld de,dtabuf
	ld c,1Ah
	call 5
	ld hl,cmd
; ---- オプション ----
opt:	call skip
	ld a,(hl)
	cp '-'
	jp nz,pat
	inc hl
	ld a,(hl)
	or a
	jp z,usage
	cp ' '
	jp z,usage
ol:	ld a,(hl)
	or a
	jr z,opt
	cp ' '
	jr z,opt
	inc hl
	ld de,fi
	cp 'i'
	jr z,osf
	ld de,fv
	cp 'v'
	jr z,osf
	ld de,fn
	cp 'n'
	jr z,osf
	ld de,fc
	cp 'c'
	jr z,osf
	ld de,fl
	cp 'l'
	jr z,osf
	ld de,fw
	cp 'w'
	jr z,osf
	ld de,fo
	cp 'o'
	jr z,osf
	ld de,fh
	cp 'h'
	jr z,osf
	cp 'A'
	jr z,oa
	cp 'B'
	jr z,ob
	cp 'C'
	jr z,oc2
	jp usage
osf:	ld (de),a
	jr ol
oa:	call getnum
	ld (ctxa),a
	jr ol
ob:	call getnum
	ld (ctxb),a
	jr ol
oc2:	call getnum
	ld (ctxa),a
	ld (ctxb),a
	jr ol
; 数字(0-9以上は9)を A に
getnum:	call skip
	ld a,(hl)
	sub '0'
	cp 10
	jp nc,usage
	ld c,a
	inc hl
gn1:	ld a,(hl)
	sub '0'
	cp 10
	jr nc,gn2
	inc hl
	ld c,9
	jr gn1
gn2:	ld a,c
	cp 10
	ret c
	ld a,9
	ret
; ---- パターン ----
pat:	ld a,(hl)
	or a
	jp z,usage
	ld de,pbuf2		; 取り出したパターン
	cp '"'
	jr nz,pl
	inc hl
	ld b,'"'
	jr pl2
pl:	ld b,' '
pl2:	ld a,(hl)
	or a
	jr z,pend
	cp b
	jr z,pend2
	ld (de),a
	inc de
	inc hl
	jr pl2
pend2:	ld a,b
	cp '"'
	jr nz,pend
	inc hl
pend:	xor a
	ld (de),a
	push hl
	ld hl,pbuf2
	ld de,pbuf
	ld a,(fw)
	or a
	jr z,pw1
	ld a,5Ch		; -w : \<( ... )\>
	ld (de),a
	inc de
	ld a,'<'
	ld (de),a
	inc de
	ld a,'('
	ld (de),a
	inc de
pw1:	ld a,(fi)
	or a
	jr z,pw2
	call lowcpy		; -i : 小文字化(全角の2バイト目は触らない)
	jr pw3
pw2:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,pw2
	dec de
pw3:	ld a,(fw)
	or a
	jr z,pw4
	ld a,')'
	ld (de),a
	inc de
	ld a,5Ch
	ld (de),a
	inc de
	ld a,'>'
	ld (de),a
	inc de
pw4:	xor a
	ld (de),a
	ld hl,pbuf
	call re_comp
	jp c,badpat
	pop hl
; ---- ファイル名を集める ----
	ld ix,ftab
	xor a
	ld (nfiles),a
fl0:	call skip
	ld a,(hl)
	or a
	jr z,fldone
	ld a,(nfiles)
	cp 16
	jp nc,usage
	inc a
	ld (nfiles),a
	ld (ix+0),l
	ld (ix+1),h
	inc ix
	inc ix
fl1:	ld a,(hl)
	or a
	jr z,fl2
	cp ' '
	jr z,fl3
	cp '*'
	jr z,flw
	cp '?'
	jr nz,fl4
flw:	ld (wild),a
fl4:	inc hl
	jr fl1
fl3:	ld (hl),0
	inc hl
	jr fl0
fl2:	jr fldone
fldone:	ld a,(fh)
	or a
	jr nz,nomulti
	ld a,(nfiles)
	cp 2
	jr nc,setmulti
	ld a,(wild)
	or a
	jr z,nomulti
setmulti:
	ld a,1
	ld (multi),a
nomulti:
	ld a,(nfiles)
	or a
	jr nz,files
	ld hl,0			; 標準入力
	call do_file
	jp fin
files:	ld ix,ftab
fnext:	ld l,(ix+0)
	ld h,(ix+1)
	inc ix
	inc ix
	push ix
	call do_one
	pop ix
	ld hl,nfiles
	dec (hl)
	jr nz,fnext
fin:	call flush
	ld a,(rc)
	cp 2
	jr z,fin2
	ld a,(anym)
	xor 1
fin2:	ld b,a
	ld c,62h
	call 5
	jp 0
; HL=ファイル指定。ワイルドカードがあれば展開して順に do_file
do_one:	ld (tokp),hl
	push hl
dw1:	ld a,(hl)
	or a
	jr z,dw2
	inc hl
	cp '*'
	jr z,dwx
	cp '?'
	jr nz,dw1
dwx:	pop hl
	jp expand
dw2:	pop hl
	jp do_file
; ---- ワイルドカード展開 ----
expand:	ld hl,(tokp)
	ld c,0
	ld b,0
xs1:	ld a,(hl)
	or a
	jr z,xs2
	inc hl
	inc b
	cp 5Ch
	jr z,xs3
	cp ':'
	jr z,xs3
	cp '/'
	jr nz,xs1
xs3:	ld c,b
	jr xs1
xs2:	ld a,c
	ld (pfxlen),a
	ld hl,fcbbuf
	ld d,h
	ld e,l
	inc de
	ld (hl),0
	ld bc,47
	ldir
	ld hl,fcbbuf
	ld de,(tokp)
	ld c,29h
	call 5
	ld a,0F1h
	ld (fcbbuf+13),a
	ld hl,(tokp)
xe1:	ld a,(hl)
	or a
	jr z,xe3
	inc hl
	cp '*'
	jr nz,xe1
	ld a,(fcbbuf+9)
	cp ' '
	jr nz,xe3
	ld hl,fcbbuf+9
	ld (hl),'?'
	inc hl
	ld (hl),'?'
	inc hl
	ld (hl),'?'
xe3:	ld a,(fcbbuf+1)
	cp ' '
	jr nz,xe4
	ld hl,fcbbuf+1
	ld de,fcbbuf+2
	ld (hl),'?'
	ld bc,10
	ldir
xe4:	xor a
	ld (nlist),a
	ld de,fcbbuf
	ld c,11h
xl:	call 5
	or a
	jr nz,xdone
	ld a,(dtabuf+12)
	and 18h			; ディレクトリ/ラベルは除く
	jr nz,xnext
	ld a,(nlist)
	cp 20
	jr nc,xnext
	ld l,a			; 一覧の位置 = nlist*16
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,nlbuf
	add hl,de
	ex de,hl
	ld hl,dtabuf+1		; NAME.EXT に整える
	ld b,8
xn1:	ld a,(hl)
	cp ' '
	jr z,xn3
	ld (de),a
	inc de
	inc hl
	djnz xn1
xn3:	ld a,b
	or a
	call z,ln_app
	ld hl,dtabuf+9
	ld a,(hl)
	cp ' '
	jr z,xn5
	ld a,'.'
	ld (de),a
	inc de
	ld b,3
xn4:	ld a,(hl)
	cp ' '
	jr z,xn5
	ld (de),a
	inc de
	inc hl
	djnz xn4
xn5:	xor a
	ld (de),a
	ld hl,nlist
	inc (hl)
xnext:	ld de,fcbbuf
	ld c,12h
	jr xl
xdone:	ld a,(nlist)
	or a
	ret z
	xor a
	ld (xi),a
xp1:	ld a,(xi)		; 一覧の i 番目を ファイル名 = 接頭辞 + 名前 にして開く
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,nlbuf
	add hl,de
	push hl
	ld hl,(tokp)
	ld de,fnbuf
	ld a,(pfxlen)
	or a
	jr z,xp2
	ld c,a
	ld b,0
	ldir
xp2:	pop hl
xp3:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,xp3
	ld hl,fnbuf
	call do_file
	ld hl,xi
	inc (hl)
	ld a,(nlist)
	cp (hl)
	jr nz,xp1
	ret
; ---- 1ファイル (HL=名前、0=標準入力) ----
do_file:
	ld (curname),hl
	ld b,0
	ld a,h
	or l
	jr z,df_in
	ex de,hl
	ld a,1
	ld c,43h
	call 5
	or a
	jr z,df_in
	ld de,mopen
	call puts
	ld hl,(curname)
	call putstr
	ld a,13
	call putch
	ld a,10
	call putch
	ld a,2
	ld (rc),a
	ret
df_in:	ld a,b
	ld (inh),a
	ld hl,lbuf
	ld (lp),hl
	ld hl,0
	ld (lno),hl
	ld (cnt),hl
	ld (lastpr),hl
	xor a
	ld (aft),a
	ld (rcnt),a
	ld (ridx),a
	ld (stopf),a
rdlp:	ld a,(stopf)
	or a
	jr nz,eof
	ld a,(inh)
	ld b,a
	ld de,ibuf
	ld hl,512
	ld c,48h
	call 5
	or a
	jr nz,eof
	ld a,h
	or l
	jr z,eof
	ld (icnt),hl
	ld hl,ibuf
chl:	ld a,(hl)
	inc hl
	push hl
	call addc
	pop hl
	ld a,(stopf)
	or a
	jr nz,eof
	ld de,(icnt)
	dec de
	ld (icnt),de
	ld a,d
	or e
	jr nz,chl
	jr rdlp
eof:	ld a,(stopf)
	or a
	jr nz,eof2
	ld hl,(lp)
	ld de,lbuf
	or a
	sbc hl,de
	call nz,endline
eof2:	ld a,(fc)
	or a
	jr z,nocnt
	ld a,(multi)
	or a
	jr z,cn0
	call pname
	ld a,':'
	call putch
cn0:	ld hl,(cnt)
	call putdec
	ld a,13
	call putch
	ld a,10
	call putch
nocnt:	call flush
	ld a,(inh)
	or a
	ret z
	ld b,a
	ld c,45h
	call 5
	ret
; A=1文字を行バッファへ。LFで行を処理
addc:	cp 0Ah
	jr z,endline
	ld hl,(lp)
	ld de,lbuf+250
	or a
	sbc hl,de
	ret nc			; 長すぎる行は残りを捨てる
	ld hl,(lp)
	ld (hl),a
	inc hl
	ld (lp),hl
	ret
; 行を終端して照合・出力
endline:
	ld hl,(lp)
	ld de,lbuf
	or a
	sbc hl,de
	ld hl,(lp)
	jr z,el1
	dec hl
	ld a,(hl)
	cp 0Dh
	jr nz,el1
	ld (lp),hl		; 末尾の CR を落とす
el1:	ld hl,(lp)
	ld (hl),0
	ld hl,lbuf
	ld (lp),hl		; 次の行用に戻す
	ld hl,(lno)
	inc hl
	ld (lno),hl
	ld hl,lbuf
	ld a,(fi)
	or a
	jr z,el2
	ld de,mbuf		; -i: 小文字化した写しで照合
	call lowcpy
	ld hl,mbuf
el2:	ld (mtext),hl
	call rx_find
	ld a,0
	rla			; A = 一致(1)/不一致(0)
	ld b,a
	ld a,(fv)
	or a
	jr z,el5
	ld a,b
	xor 1
	ld b,a
el5:	ld a,b
	or a
	jp z,notsel
; ---- 選ばれた行 ----
	ld a,1
	ld (anym),a
	ld hl,(cnt)
	inc hl
	ld (cnt),hl
	ld a,(fl)
	or a
	jr z,sl1
	ld a,(fc)		; -l : ファイル名を出して、このファイルは終わり
	or a
	ret nz
	ld hl,(curname)
	ld a,h
	or l
	jr nz,sl0
	ld hl,mstdin
sl0:	call putstr
	ld a,13
	call putch
	ld a,10
	call putch
	ld a,1
	ld (stopf),a
	ret
sl1:	ld a,(fc)
	or a
	ret nz
	; 区切り "--" (前後の行を出すとき、グループが離れていれば)
	ld a,(ctxa)
	ld hl,ctxb
	or (hl)
	jr z,sl3
	ld a,(rcnt)
	or a
	jr z,sl2
	call oldnum		; HL = 一番古い行番号
	jr sl2b
sl2:	ld hl,(lno)
sl2b:	ld de,(lastpr)
	ld a,d
	or e
	jr nz,sl2c
	ld a,(anyp)
	or a
	jr z,sl3
	jr sl2d
sl2c:	inc de
	or a
	sbc hl,de
	jr c,sl3
	jr z,sl3
sl2d:	ld hl,msep
	call putstr
sl3:	call flushring
	ld a,(fo)
	ld hl,fv
	or a
	jr z,sl4
	ld a,(hl)
	or a
	jp z,onlym
sl4:	ld hl,lbuf
	ld a,':'
	call pline
	ld hl,(lno)
	ld (lastpr),hl
	ld a,(ctxa)
	ld (aft),a
	ld a,1
	ld (anyp),a
	jp flush
; ---- 選ばれなかった行 ----
notsel:	ld a,(fc)
	ld hl,fl
	or (hl)
	ret nz
	ld a,(aft)
	or a
	jr z,ns1
	dec a
	ld (aft),a
	ld hl,lbuf
	ld a,'-'
	call pline
	ld hl,(lno)
	ld (lastpr),hl
	ld a,1
	ld (anyp),a
	jp flush
ns1:	ld a,(ctxb)
	or a
	ret z
	; リングへ保存
	ld a,(ridx)
	call slot		; HL = スロット
	ex de,hl
	ld hl,lbuf
ns2:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,ns2
	ld a,(ridx)
	call slot
	ld de,256
	add hl,de
	ld de,(lno)
	ld (hl),e
	inc hl
	ld (hl),d
	ld a,(ridx)
	inc a
	ld hl,ctxb
	cp (hl)
	jr c,ns3
	xor a
ns3:	ld (ridx),a
	ld a,(rcnt)
	ld hl,ctxb
	cp (hl)
	jr nc,ns4
	inc a
	ld (rcnt),a
ns4:	ret
; A=番号 -> HL=スロットの番地 (リング + 番号*260)
slot:	ld l,a
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl		; *256
	ex de,hl
	add hl,hl
	add hl,hl		; *4
	add hl,de
	ld de,ringbuf
	add hl,de
	ret
; 一番古いスロットの番号 -> A
oldidx:	ld a,(ridx)
	ld hl,rcnt
	sub (hl)
	jr nc,oi1
	ld hl,ctxb
	add a,(hl)
oi1:	ret
; 一番古い行番号 -> HL
oldnum:	call oldidx
	call slot
	ld de,256
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ret
; リングの行を前の行(文脈)として古い順に出して空にする
flushring:
	ld a,(rcnt)
	or a
	ret z
	call oldidx
	ld (fri),a
fr1:	ld a,(fri)
	call slot
	push hl
	ld de,256
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (ctxno),de
	pop hl
	ld a,'-'
	call plinen
	ld a,(fri)
	inc a
	ld hl,ctxb
	cp (hl)
	jr c,fr2
	xor a
fr2:	ld (fri),a
	ld hl,rcnt
	dec (hl)
	jr nz,fr1
	xor a
	ld (ridx),a
	ld hl,(ctxno)
	ld (lastpr),hl
	ret
; HL=テキスト A=区切り文字 : 行(lno)を出力
pline:	ld de,(lno)
	ld (ctxno),de
plinen:	ld (psep),a		; ctxno の行番号で
	push hl
	ld a,(multi)
	or a
	jr z,pl9
	call pname
	ld a,(psep)
	call putch
pl9:	ld a,(fn)
	or a
	jr z,pl8
	ld hl,(ctxno)
	call putdec
	ld a,(psep)
	call putch
pl8:	pop hl
	call putstr
	ld a,13
	call putch
	ld a,10
	jp putch
; -o : 一致した部分を1行ずつ (最初の一致は rx_find 済み)
onlym:
om1:	ld hl,(mend)
	ld de,(mstart)
	or a
	sbc hl,de
	jr z,om2		; 空の一致は出さない
	ld b,h
	ld c,l
	ld hl,(mstart)
	ld de,(mtext)
	or a
	sbc hl,de
	ld de,lbuf
	add hl,de		; 元の行の同じ位置
	ld de,obuf2
	ldir
	xor a
	ld (de),a
	ld hl,obuf2
	ld a,':'
	call pline
om2:	ld hl,(mend)
	ld de,(mstart)
	or a
	sbc hl,de
	ld hl,(mend)
	jr nz,om3
	ld a,(hl)		; 空の一致は1文字進める
	or a
	jr z,om9
	inc hl
om3:	ld a,(hl)
	or a
	jr z,om9
	call rx_from
	jr c,om1
om9:	ld hl,(lno)
	ld (lastpr),hl
	ld a,(ctxa)
	ld (aft),a
	ld a,1
	ld (anyp),a
	jp flush
; ---- 出力 ----
pname:	ld hl,(curname)
	ld a,h
	or l
	jr nz,putstr
	ld hl,mstdin
putstr:	ld a,(hl)
	or a
	ret z
	inc hl
	call putch
	jr putstr
puts:	ld c,9
	jp 5
putch:	push hl
	push de
	ld hl,(op)
	ld (hl),a
	inc hl
	ld (op),hl
	ld de,obuf+250
	or a
	sbc hl,de
	call nc,flush
	pop de
	pop hl
	ret
flush:	push af
	push bc
	push de
	push hl
	ld hl,(op)
	ld de,obuf
	or a
	sbc hl,de
	jr z,fl9
	ld b,1
	ld de,obuf
	ld c,49h
	call 5
	ld hl,obuf
	ld (op),hl
fl9:	pop hl
	pop de
	pop bc
	pop af
	ret
putdec:	ld de,dbuf+5
	xor a
	ld (de),a
pd1:	call div10
	add a,'0'
	dec de
	ld (de),a
	ld a,h
	or l
	jr nz,pd1
pd2:	ld a,(de)
	or a
	ret z
	call putch
	inc de
	jr pd2
div10:	ld b,16
	xor a
dv1:	add hl,hl
	rla
	cp 10
	jr c,dv2
	sub 10
	inc l
dv2:	djnz dv1
	ret
; HL(0終端) を DE へ小文字にして写す(全角の2バイト目はそのまま)。 DE は終端の0の位置で戻る
lowcpy:	ld a,(hl)
	or a
	jr z,lc9
	inc hl
	call islead
	jr c,lc2
	cp 'A'
	jr c,lc1
	cp 'Z'+1
	jr nc,lc1
	add a,20h
lc1:	ld (de),a
	inc de
	jr lowcpy
lc2:	ld (de),a
	inc de
	ld a,(hl)
	or a
	jr z,lc9
	inc hl
	ld (de),a
	inc de
	jr lowcpy
lc9:	ld (de),a
	ret
skip:	ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr skip
usage:	ld de,musage
	call puts
	ld b,2
	ld c,62h
	call 5
	jp 0
badpat:	ld de,mbad
	call puts
	ld b,2
	ld c,62h
	call 5
	jp 0
	include "re.inc"
	include "lnd.inc"
fi:	defb 0
fv:	defb 0
fn:	defb 0
fc:	defb 0
fl:	defb 0
fw:	defb 0
fo:	defb 0
fh:	defb 0
ctxa:	defb 0
ctxb:	defb 0
multi:	defb 0
wild:	defb 0
nfiles:	defb 0
rc:	defb 1
anym:	defb 0
anyp:	defb 0
stopf:	defb 0
aft:	defb 0
rcnt:	defb 0
ridx:	defb 0
fri:	defb 0
psep:	defb 0
xi:	defb 0
nlist:	defb 0
pfxlen:	defb 0
inh:	defb 0
icnt:	defw 0
lp:	defw 0
lno:	defw 0
cnt:	defw 0
lastpr:	defw 0
ctxno:	defw 0
moff:	defw 0
mtext:	defw 0
tokp:	defw 0
curname: defw 0
op:	defw obuf
dbuf:	defs 6
musage:	defm "usage: egrep [-ivnclwoh] [-A n] [-B n] [-C n] pattern [file ...]",13,10,"$"
mopen:	defm "egrep: cannot open $"
mbad:	defm "egrep: bad pattern",13,10,"$"
msep:	defm "--",13,10,0
mstdin:	defm "(standard input)",0
ftab:	defs 32
pbuf2:	defs 130
pbuf:	defs 140
cmd:	defs 130
lbuf:	defs 256
mbuf:	defs 256
obuf2:	defs 256
ibuf:	defs 512
obuf:	defs 260
fcbbuf:	defs 48
dtabuf:	defs 32
fnbuf:	defs 80
nlbuf:	defs 640
ringbuf:	defs 2340
