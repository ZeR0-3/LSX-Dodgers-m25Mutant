; MAN.COM - 簡易マニュアル。 man [名前]   \MAN\名前.TXT を探して1画面ずつ表示する(名前なし=INDEX)。MIT License
; 探す順: カレントドライブ、A:、H:、B: の \MAN。表示のあいだだけ漢字モードON(標準出力がコンソールのとき)。
; ページ送りの部分は more.asm と同じ。キー: SPACE=次の画面  ENTER=1行  Q/ESC/Ctrl-C=終了。
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
sk:	ld a,(hl)
	cp ' '
	jr nz,sk2
	inc hl
	jr sk
sk2:	ld de,nmbuf		; 名前(8文字まで、大文字)を nmbuf へ
	ld b,8
	or a
	jr nz,cp1
	ld hl,dfl		; 引数なし = INDEX
cp1:	ld a,(hl)
	or a
	jr z,cpe
	cp ' '
	jr z,cpe
	cp 'a'
	jr c,cp2
	cp 'z'+1
	jr nc,cp2
	and 0DFh
cp2:	ld (de),a
	inc hl
	inc de
	djnz cp1
cpe:	ld hl,ext		; ".TXT",0
	ld bc,5
	ldir
	ld hl,drvs		; 探す順
	ld (dp),hl
	ld a,2
	ld (skipd),a
try:	ld a,(skipd)		; 最初はドライブ指定なし(buf+2)
	or a
	jr z,tdrv
	xor a
	ld (skipd),a
	ld de,pbuf+2
	jr topen
tdrv:	ld hl,(dp)
	ld a,(hl)
	or a
	jr z,nofound
	inc hl
	ld (dp),hl
	dec hl
	ld (pbuf),a
	ld de,pbuf
topen:	ld a,1
	ld c,43h
	call 5
	or a
	jr nz,try
	jr gotin
nofound:ld de,mnf
	ld c,9
	call 5
	ld hl,nmbuf
pn:	ld a,(hl)
	cp '.'
	jr z,pnx
	ld e,a
	push hl
	ld c,2
	call 5
	pop hl
	inc hl
	jr pn
pnx:	ld de,mcrlf
	ld c,9
	call 5
	jp 0
gotin:	ld a,b
	ld (inh),a
	; 標準出力がコンソールか(IOCTL 0: E bit7 = デバイス)
	ld b,1
	xor a
	ld c,4Bh
	call 5
	ld a,e
	and 80h
	ld (paging),a
	or a
	jr z,nokon
	ld de,kon
	ld c,9
	call 5
nokon:
	; 画面サイズ
	ld b,2
	ld a,4
	ld c,4Bh
	call 5
	ld a,d
	dec a
	ld (page),a
	ld a,e
	ld (width),a
	xor a
	ld (lines),a
	ld (col),a
	ld hl,obuf
	ld (op),hl
rdlp:	ld a,(inh)
	ld b,a
	ld de,ibuf
	ld hl,512
	ld c,48h
	call 5
	or a
	jr nz,fin
	ld a,h
	or l
	jr z,fin
	ld (icnt),hl
	ld hl,ibuf
chl:	ld a,(hl)
	inc hl
	push hl
	call putc
	pop hl
	ret_q:
	ld a,(quit)
	or a
	jr nz,fin
	ld de,(icnt)
	dec de
	ld (icnt),de
	ld a,d
	or e
	jr nz,chl
	jr rdlp
fin:	call flush
	ld a,(paging)
	or a
	jr z,nokoff
	push af
	ld de,koff
	ld c,9
	call 5
	pop af
nokoff:
	ld a,(inh)
	or a
	jr z,ex
	ld b,a
	ld c,45h
	call 5
ex:	jp 0
; A=文字 を出力バッファへ。行末/バッファ満杯で書き出し、必要ならページ送り待ち
putc:	ld hl,(op)
	ld (hl),a
	inc hl
	ld (op),hl
	cp 0Ah
	jr z,pnl
	cp 0Dh
	jr z,pcr
	cp 09h
	jr z,ptab
	ld hl,col
	inc (hl)
	ld a,(width)
	cp (hl)
	jr nz,pchk
	ld (hl),0		; 折り返し=1行増える
	jr pline
ptab:	ld a,(col)
	or 7
	inc a
	ld (col),a
	jr pchk
pcr:	xor a
	ld (col),a
	jr pchk
pnl:	xor a
	ld (col),a
pline:	ld a,(paging)
	or a
	jr z,pchk
	ld hl,lines
	inc (hl)
	call flush
	ld a,(page)
	ld hl,lines
	cp (hl)
	ret nz
	jr prompt
pchk:	ld hl,(op)
	ld de,obuf+250
	or a
	sbc hl,de
	ret c
flush:	ld hl,(op)
	ld de,obuf
	or a
	sbc hl,de
	ret z
	ld b,1
	ld de,obuf
	ld c,49h
	call 5
	ld hl,obuf
	ld (op),hl
	ret
prompt:	ld b,2
	ld de,mmore
	ld hl,8
	ld c,49h
	call 5
	ld b,2
	ld a,0F0h
	ld c,4Bh
	call 5
	ld a,e
	push af
	ld b,2
	ld de,merase
	ld hl,10
	ld c,49h
	call 5
	pop af
	cp 'q'
	jr z,pq
	cp 'Q'
	jr z,pq
	cp 1Bh
	jr z,pq
	cp 03h
	jr z,pq
	cp 0Dh
	jr z,pone
	xor a
	ld (lines),a
	ret
pone:	ld a,(page)
	dec a
	ld (lines),a
	ret
pq:	ld a,1
	ld (quit),a
	ret
inh:	defb 0
paging:	defb 0
page:	defb 20
width:	defb 80
lines:	defb 0
col:	defb 0
quit:	defb 0
icnt:	defw 0
op:	defw 0
mmore:	defm "--More--"
merase:	defb 13
	defm "        "
	defb 13
kon:	defb 1Bh
	defm "k1$"
koff:	defb 1Bh
	defm "k0$"
mcrlf:	defb 13,10,"$"
mnf:	defm "man: no manual entry for $"
skipd:	defb 0
dp:	defw 0
drvs:	defm "AHB",0
dfl:	defm "INDEX",0
ext:	defm ".TXT",0
pbuf:	defm "?:"
	defb 5Ch
	defm "MAN"
	defb 5Ch
nmbuf:	defs 16
ibuf:	defs 512
obuf:	defs 256
