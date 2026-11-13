; 隠れる領域(A000H-DFFF=ゲート経由で渡す所)にある FCB/DMA/文字列/ハンドル用バッファが BDOS で使えること
; 成功なら HID1-OK / HID2-OK を出す。tests/ はテスト専用で配布ディスクには入れない
	org 0100h
	; ---- 1: FCB/DMA が C000H以上(隠れる領域)
	ld hl,fcbt
	ld de,0C000h
	ld bc,36
	ldir
	ld hl,fcbt
	ld de,01000h
	ld bc,36
	ldir
	ld de,0C100h
	ld c,01Ah
	call 5
	ld de,0C000h
	ld c,00Fh
	call 5
	or a
	jp nz,fail1
	ld de,0C000h
	ld c,014h
	call 5
	or a
	jp nz,fail1
	; 同じレコードを見える領域で読む
	ld de,02000h
	ld c,01Ah
	call 5
	ld de,01000h
	ld c,00Fh
	call 5
	ld de,01000h
	ld c,014h
	call 5
	ld hl,0C100h
	ld de,02000h
	ld b,128
cmp1:	ld a,(de)
	cp (hl)
	jp nz,fail2
	inc hl
	inc de
	djnz cmp1
	ld hl,m1
	ld de,0C300h
	ld bc,mend-m1
	ldir
	ld de,0C300h
	ld c,9
	call 5
	; ---- 2: ハンドル読み(隠れるバッファ)
	ld hl,path
	ld de,0C400h
	ld bc,10
	ldir
	ld de,0C400h
	ld c,043h
	ld a,1
	call 5
	or a
	jp nz,fail3
	ld de,0C600h
	ld hl,300
	ld c,048h
	call 5
	or a
	jp nz,fail3
	ld de,hlmsg
	ld a,h
	or a
	ld c,9
	call 5
	ld hl,0C600h
	ld de,02000h
	ld b,128
cmp2:	ld a,(de)
	cp (hl)
	jp nz,fail4
	inc hl
	inc de
	djnz cmp2
	ld de,m2
	ld c,9
	call 5
	ret
fail1:	ld de,f1
	jr pf
fail2:	ld de,f2
	jr pf
fail3:	ld de,f3
	jr pf
fail4:	ld de,f4
pf:	ld c,9
	call 5
	ret
fcbt:	defb 0
	defm "TYPE    COM"
	defs 24,0
m1:	defm "HID1-OK",13,10,"$"
mend:
m2:	defm "HID2-OK",13,10,"$"
hlmsg:	defm "R",13,10,"$"
path:	defm "TYPE.COM",0,0
f1:	defm "F1$"
f2:	defm "F2$"
f3:	defm "F3$"
f4:	defm "F4$"
