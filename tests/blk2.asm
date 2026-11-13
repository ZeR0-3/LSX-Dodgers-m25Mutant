; 26h/27h で DMA が隠れる領域(C000H)・FCB も隠れる領域(C800H)。700Bを書いて読み戻し、一致とランダムレコードの進みを見る。成功で BLK2-OK
	org 0100h
	ld hl,0C000h
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
	ld de,0C800h
	ld c,016h		; make
	call 5
	or a
	jp nz,f1
	ld de,0C000h
	ld c,01Ah
	call 5
	ld de,0C800h
	ld hl,700
	ld c,026h
	call 5
	or a
	jp nz,f2
	ld de,0C800h
	ld c,010h		; close
	call 5
	ld hl,0C000h		; 消す
	ld de,0C001h
	ld bc,799
	ld (hl),0
	ldir
	call mkfcb
	ld de,0C800h
	ld c,00Fh
	call 5
	or a
	jp nz,f3
	ld de,0C800h
	ld hl,700
	ld c,027h
	call 5
	or a
	jp nz,f4
	ld de,700
	or a
	sbc hl,de
	jp nz,f5
	ld hl,0C000h
	ld b,0
	ld de,700
cmp:	ld a,(hl)
	cp b
	jp nz,f6
	inc hl
	inc b
	dec de
	ld a,d
	or e
	jr nz,cmp
	ld a,(0C821h)
	cp 0BCh
	jp nz,f7
	ld a,(0C822h)
	cp 2
	jp nz,f7
	; 見える領域のFCBに後続の1Ah(DMAを戻す)と、隠れDMAのままの短い読み(EOF超え)も確認: 先頭から800B読む→700Bだけ読めてA=1
	call mkfcb
	ld de,0C800h
	ld c,00Fh
	call 5
	ld de,0C000h
	ld c,01Ah
	call 5
	ld de,0C800h
	ld hl,800
	ld c,027h
	call 5
	cp 1
	jp nz,f8
	ld de,700
	or a
	sbc hl,de
	jp nz,f9
	ld de,ok
	ld c,9
	call 5
	jp 0
f1:	ld e,'1'
	jr fail
f2:	ld e,'2'
	jr fail
f3:	ld e,'3'
	jr fail
f4:	ld e,'4'
	jr fail
f5:	ld e,'5'
	jr fail
f6:	ld e,'6'
	jr fail
f7:	ld e,'7'
	jr fail
f8:	ld e,'8'
	jr fail
f9:	ld e,'9'
fail:	ld c,2
	call 5
	ld de,ng
	ld c,9
	call 5
	jp 0
mkfcb:	ld hl,fcbt
	ld de,0C800h
	ld bc,37
	ldir
	ret
ok:	defm "BLK2-OK",13,10,"$"
ng:	defm "BLK2-NG",13,10,"$"
fcbt:	defb 0
	defm "BLKTEST TM2"
	defb 0,0
	defw 1
	defs 21,0
