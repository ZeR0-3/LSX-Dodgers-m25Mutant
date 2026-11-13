; 26h/27h(ブロック書き込み/読み出し)。700Bを書き→読み戻して比較し、ランダムレコードが700進むこと。
; FCB を C000H(隠れる領域・37B)に置く。DMA は見える 4000H。成功で BLK-OK
	org 0100h
	ld hl,04000h
	ld b,0
	ld de,700
fil:	ld (hl),b
	inc hl
	inc b
	dec de
	ld a,d
	or e
	jr nz,fil
	call mkfcb
	ld de,0C000h
	ld c,016h		; make
	call 5
	or a
	jp nz,fail
	ld de,04000h
	ld c,01Ah
	call 5
	ld de,0C000h
	ld hl,700
	ld c,026h
	call 5
	or a
	jp nz,fail
	ld de,0C000h
	ld c,010h		; close
	call 5
	ld hl,04000h		; 消して読み戻す
	ld de,04001h
	ld bc,799
	ld (hl),0
	ldir
	call mkfcb
	ld de,0C000h
	ld c,00Fh
	call 5
	or a
	jp nz,fail
	ld de,0C000h
	ld hl,700
	ld c,027h
	call 5
	or a
	jp nz,fail
	ld de,700
	or a
	sbc hl,de
	jp nz,fail
	ld hl,04000h
	ld b,0
	ld de,700
cmp:	ld a,(hl)
	cp b
	jp nz,fail
	inc hl
	inc b
	dec de
	ld a,d
	or e
	jr nz,cmp
	ld a,(0C021h)		; ランダムレコードは読んだ分(02BCH)だけ進む
	cp 0BCh
	jp nz,fail
	ld a,(0C022h)
	cp 2
	jp nz,fail
	ld de,ok
	ld c,9
	call 5
	jp 0
fail:	ld de,ng
	ld c,9
	call 5
	jp 0
mkfcb:	ld hl,fcbt
	ld de,0C000h
	ld bc,37
	ldir
	ret
ok:	defm "BLK-OK",13,10,"$"
ng:	defm "BLK-NG",13,10,"$"
fcbt:	defb 0
	defm "BLKTEST TMP"
	defb 0,0
	defw 1
	defs 21,0
