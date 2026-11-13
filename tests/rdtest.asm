; 標準入出力のリダイレクト用テスト: $0A で行を読み "[行]" と出力し、Q の行で止まる。その後 $07 で1AHまで文字を読んで出力。
	org 0100h
	ld sp,0A000h
loop:	ld hl,buf
	ld (hl),40
	ex de,hl
	ld e,l
	ld d,h
	ld de,buf
	ld c,0Ah
	call 5
	ld a,(buf+1)
	cp 1
	jr nz,pr
	ld a,(buf+2)
	cp 'Q'
	jr z,rest
pr:	ld e,'['
	ld c,2
	call 5
	ld a,(buf+1)
	ld b,a
	ld hl,buf+2
pl:	ld a,b
	or a
	jr z,pe
	ld e,(hl)
	inc hl
	push bc
	push hl
	ld c,2
	call 5
	pop hl
	pop bc
	dec b
	jr pl
pe:	ld e,']'
	ld c,2
	call 5
	jr loop
rest:	ld e,'|'
	ld c,2
	call 5
	ld b,20
r1:	push bc
	ld c,7
	call 5
	pop bc
	cp 1Ah
	jr z,done
	cp 0Dh
	jr z,r2
	cp 0Ah
	jr z,r2
	ld e,a
	push bc
	ld c,2
	call 5
	pop bc
r2:	djnz r1
done:	ld de,mend
	ld c,9
	call 5
	jp 0
mend:	defm "<END>",13,10,"$"
buf:	defs 64
