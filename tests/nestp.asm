; nestp - 入れ子の E5h: 親(NESTP) -> 子(NESTC) -> 孫(CHILD T)。親のパターンと子の終了が正しく戻ること。
;   空きページが14枚要るので、事前に `ramdisk 0` で F: を無効にすること。
	org 0100h
	ld sp,7F00h
	ld hl,8000h
	ld de,0DEFFh-8000h+1
pf:	ld a,l
	xor h
	add a,9
	ld (hl),a
	inc hl
	dec de
	ld a,d
	or e
	jr nz,pf
	ld de,c_nestc
	ld c,0E5h
	call 5
	or a
	jr nz,ng
	ld hl,8000h
	ld de,0DEFFh-8000h+1
cl:	ld a,l
	xor h
	add a,9
	cp (hl)
	jr nz,ng
	inc hl
	dec de
	ld a,d
	or e
	jr nz,cl
	ld de,m_ok
	ld c,9
	call 5
	jp 0
ng:	ld de,m_ng
	ld c,9
	call 5
	jp 0
c_nestc:	defm "NESTC",0
m_ok:	defm "NEST-P-OK",13,10,"$"
m_ng:	defm "NEST-P-NG",13,10,"$"
