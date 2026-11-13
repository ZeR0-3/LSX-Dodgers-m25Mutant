; lnreg - BDOS E4h (長いファイル名の登録) の試験。
;   lnreg   : FCB に LONGNAME.TXT を入れ、name2 "ISHERE" を登録して開く -> "OK" または "NG"
;   lnreg n : 登録せずに開く(長い名前のファイルしか無ければ開けないはず)
	org 0100h
	ld sp,0A000h
	ld hl,fcb
	ld de,fcb+1
	ld (hl),0
	ld bc,35
	ldir
	ld hl,fn
	ld de,fcb+1
	ld bc,11
	ldir
	ld a,(0082h)
	cp 'n'
	jr z,op
	ld de,fcb
	ld hl,n2
	ld c,0E4h
	call 5
op:	ld de,fcb
	ld c,0Fh
	call 5
	ld a,(fcb+28)
	cp 0FFh
	ld de,mok
	jr z,pr
	ld de,mng
pr:	ld c,9
	call 5
	jp 0
fn:	defm "LONGNAMETXT"
n2:	defm "ISHERE",0,0,0,0
mok:	defm "OK",13,10,"$"
mng:	defm "NG",13,10,"$"
fcb:	defs 37
