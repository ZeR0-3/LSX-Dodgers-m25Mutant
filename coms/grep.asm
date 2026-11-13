; GREP.COM - 行の検索。 grep [-ivnc] pattern [file]   (file 省略時は標準入力)。MIT License
; パターン: 文字 / . (任意の1文字) / * (直前の1文字の0回以上の繰り返し) / ^ (行頭) / $ (行末)。空白を含むときは "..." で囲む。
; オプション: -i 大文字小文字を無視  -v 一致しない行  -n 行番号を付ける  -c 一致した行数だけ出す
; Kernighan & Pike の再帰マッチャ(「プログラミング作法」の match/matchhere/matchstar)に基づく簡易実装。\ によるエスケープ・[...] は未対応。
	org 0100h
	ld sp,0A000h
	ld hl,0080h
	ld a,(hl)
	inc hl
	ld e,a
	ld d,0
	add hl,de
	ld (hl),0
	ld hl,0081h
; ---- オプション ----
opt:	call skip
	ld a,(hl)
	cp '-'
	jr nz,pat
	inc hl
ol:	ld a,(hl)
	or a
	jr z,opt
	cp ' '
	jr z,opt
	inc hl
	cp 'i'
	jr z,oi
	cp 'v'
	jr z,ov
	cp 'n'
	jr z,on
	cp 'c'
	jr z,oc
	jp usage
oi:	ld (fi),a
	jr ol
ov:	ld (fv),a
	jr ol
on:	ld (fn),a
	jr ol
oc:	ld (fc),a
	jr ol
; ---- パターン ----
pat:	ld a,(hl)
	or a
	jp z,usage
	ld de,pbuf
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
	ld c,a
	ld a,(fi)
	or a
	ld a,c
	call nz,lower
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
; ---- ファイル ----
	call skip
	ld a,(hl)
	or a
	ld b,0
	jr z,gotin
	ld d,h
	ld e,l
fe:	ld a,(hl)
	or a
	jr z,fe2
	cp ' '
	jr z,fe2
	inc hl
	jr fe
fe2:	ld (hl),0
	ld a,1
	ld c,43h
	call 5
	or a
	jr z,gotin
	ld de,mopen
	ld c,9
	call 5
	jp 0
gotin:	ld a,b
	ld (inh),a
	ld hl,lbuf
	ld (lp),hl
; ---- 読み込みループ ----
rdlp:	ld a,(inh)
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
	ld de,(icnt)
	dec de
	ld (icnt),de
	ld a,d
	or e
	jr nz,chl
	jr rdlp
eof:	ld hl,(lp)		; 改行で終わらない最後の行
	ld de,lbuf
	or a
	sbc hl,de
	call nz,endline
	ld a,(fc)
	or a
	jr z,fin
	ld hl,(cnt)
	call putdec
	ld a,13
	call putch
	ld a,10
	call putch
	call flush
fin:	ld a,(inh)
	or a
	jr z,ex
	ld b,a
	ld c,45h
	call 5
ex:	jp 0
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
el3:	ld a,(hl)
	call lower
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,el3
	ld de,mbuf
	jr el4
el2:	ld de,lbuf
el4:	ld hl,pbuf
	call match
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
	ret z
	ld hl,(cnt)
	inc hl
	ld (cnt),hl
	ld a,(fc)
	or a
	ret nz
	ld a,(fn)
	or a
	jr z,el6
	ld hl,(lno)
	call putdec
	ld a,':'
	call putch
el6:	ld hl,lbuf
el7:	ld a,(hl)
	or a
	jr z,el8
	inc hl
	call putch
	jr el7
el8:	ld a,13
	call putch
	ld a,10
	call putch
	jp flush
; ---- 出力バッファ ----
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
; HL を10進で出力
putdec:	ld de,dbuf+5
	xor a
	ld (de),a
pd1:	call div10		; HL=商 A=余り
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
; ---- 照合 (K&P) ----  HL=パターン DE=テキスト  -> CF=1:一致
match:	ld a,(hl)
	cp '^'
	jr nz,mt1
	inc hl
	jr mh
mt1:	push hl
	push de
	call mh
	pop de
	pop hl
	ret c
	ld a,(de)
	or a
	ret z
	inc de
	jr mt1
mh:	ld a,(hl)
	or a
	jr z,yes
	ld c,a
	inc hl
	ld b,(hl)
	dec hl
	ld a,b
	cp '*'
	jr z,star
	ld a,c
	cp '$'
	jr nz,mh2
	ld a,b
	or a
	jr nz,mh2
	ld a,(de)
	or a
	jr z,yes
	jr no
mh2:	ld a,(de)
	or a
	jr z,no
	ld a,c
	cp '.'
	jr z,adv
	ld a,(de)
	cp c
	jr nz,no
adv:	inc hl
	inc de
	jr mh
yes:	scf
	ret
no:	and a
	ret
star:	inc hl
	inc hl
ms:	push bc
	push hl
	push de
	call mh
	pop de
	pop hl
	pop bc
	ret c
	ld a,(de)
	or a
	jr z,no
	ld a,c
	cp '.'
	jr z,ms2
	ld a,(de)
	cp c
	jr nz,no
ms2:	inc de
	jr ms
; A を小文字に
lower:	cp 'A'
	ret c
	cp 'Z'+1
	ret nc
	add a,20h
	ret
skip:	ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr skip
usage:	ld de,musage
	ld c,9
	call 5
	jp 0
fi:	defb 0
fv:	defb 0
fn:	defb 0
fc:	defb 0
inh:	defb 0
icnt:	defw 0
lp:	defw 0
lno:	defw 0
cnt:	defw 0
op:	defw obuf
dbuf:	defs 6
musage:	defm "usage: grep [-ivnc] pattern [file]",13,10,"$"
mopen:	defm "grep: cannot open file",13,10,"$"
pbuf:	defs 130
lbuf:	defs 256
mbuf:	defs 256
ibuf:	defs 512
obuf:	defs 256
