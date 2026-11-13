; MORE.COM - 1画面ずつ表示する。 more [file]  /  引数なしなら標準入力(ハンドル0)から。MIT License
; キー: SPACE=次の画面  ENTER=1行  Q/ESC/Ctrl-C=終了。標準出力がファイルのときはページ送りせずそのまま出す。
; キーは LSX独自の IOCTL 副機能 F0h でキーボードから直接読む(標準入力がファイル/パイプでも使える)。
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
sk2:	or a
	ld b,0			; 入力ハンドル(既定=標準入力)
	jr z,gotin
	ld d,h			; ファイル名の終わりを探して 0 にする
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
	; 標準出力がコンソールか(IOCTL 0: E bit7 = デバイス)
	ld b,1
	xor a
	ld c,4Bh
	call 5
	ld a,e
	and 80h
	ld (paging),a
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
mopen:	defm "more: cannot open file",13,10,"$"
ibuf:	defs 512
obuf:	defs 256
