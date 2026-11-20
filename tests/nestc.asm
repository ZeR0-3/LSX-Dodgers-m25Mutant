; nestc - nestp の子。自分のメモリに印を書いて孫(CHILD T)を起動し、孫の終了コード 7 と印の無事を確かめる。
	org 0100h
	ld sp,7F00h
	ld hl,4000h
	ld b,0
mk:	ld (hl),0A7h
	inc hl
	djnz mk
	ld de,c_child
	ld c,0E5h
	call 5
	cp 7
	jr nz,ng
	ld hl,4000h
	ld b,0
ck:	ld a,(hl)
	cp 0A7h
	jr nz,ng
	inc hl
	djnz ck
	ld de,m_ok
	ld c,9
	call 5
	jp 0
ng:	ld de,m_ng
	ld c,9
	call 5
	jp 0
c_child:	defm "CHILD T",0
m_ok:	defm "NEST-C-OK",13,10,"$"
m_ng:	defm "NEST-C-NG",13,10,"$"
