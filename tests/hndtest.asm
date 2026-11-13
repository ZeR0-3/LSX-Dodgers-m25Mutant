; MSX-DOS2 ハンドル層(43h-4Bh)のテストCOM。各段階の結果を画面に出す。
	org 0100h
	ld sp,0A000h
	ld de,mhead
	ld c,9
	call 5
; ---- 1 create
	call step
	defb 1
	ld de,fn1
	ld a,0
	ld b,0
	ld c,44h
	call 5
	call chk0
	ld a,b
	cp 3
	call chkz            ; 最初のハンドルは3
	ld a,b
	ld (h1),a
; ---- 2 write HELLO WORLD
	call step
	defb 2
	ld a,(h1)
	ld b,a
	ld de,txt
	ld hl,11
	ld c,49h
	call 5
	call chk0
	ld a,l
	cp 11
	call chkz
; ---- 3 seek 0
	call step
	defb 3
	ld a,(h1)
	ld b,a
	ld a,0
	ld de,0
	ld hl,0
	ld c,4Ah
	call 5
	call chk0
; ---- 4 read 5
	call step
	defb 4
	ld a,(h1)
	ld b,a
	ld de,buf
	ld hl,5
	ld c,48h
	call 5
	call chk0
	ld a,l
	cp 5
	call chkz
	ld hl,buf
	ld de,txt
	ld b,5
	call cmpn
; ---- 5 seek cur+1, read 5 -> WORLD
	call step
	defb 5
	ld a,(h1)
	ld b,a
	ld a,1
	ld de,0
	ld hl,1
	ld c,4Ah
	call 5
	call chk0
	ld a,l
	cp 6
	call chkz
	ld a,(h1)
	ld b,a
	ld de,buf
	ld hl,5
	ld c,48h
	call 5
	call chk0
	ld hl,buf
	ld de,txt+6
	ld b,5
	call cmpn
; ---- 6 read at EOF -> 0 bytes, A=C7
	call step
	defb 6
	ld a,(h1)
	ld b,a
	ld de,buf
	ld hl,10
	ld c,48h
	call 5
	cp 0C7h
	call chkz
	ld a,h
	or l
	call chkz
; ---- 7 seek end
	call step
	defb 7
	ld a,(h1)
	ld b,a
	ld a,2
	ld de,0
	ld hl,0
	ld c,4Ah
	call 5
	call chk0
	ld a,l
	cp 11
	call chkz
; ---- 8 append !!! ; dup ; write Z via dup
	call step
	defb 8
	ld a,(h1)
	ld b,a
	ld de,ex3
	ld hl,3
	ld c,49h
	call 5
	call chk0
	ld a,(h1)
	ld b,a
	ld c,47h
	call 5
	call chk0
	ld a,b
	cp 4
	call chkz
	ld a,b
	ld (h2),a
	ld de,exz
	ld hl,1
	ld c,49h
	call 5
	call chk0
; ---- 9 ioctl
	call step
	defb 9
	ld a,(h1)
	ld b,a
	ld a,0
	ld c,4Bh
	call 5
	call chk0
	ld a,e
	and 80h
	call chkz            ; ファイルは bit7=0
	ld b,1
	ld a,0
	ld c,4Bh
	call 5
	call chk0
	ld a,e
	cp 0A3h
	call chkz
; ---- 10 close dup, close, close again
	call step
	defb 10
	ld a,(h2)
	ld b,a
	ld c,45h
	call 5
	call chk0
	ld a,(h1)
	ld b,a
	ld c,45h
	call 5
	call chk0
	ld a,(h1)
	ld b,a
	ld c,45h
	call 5
	cp 0C2h
	call chkz
; ---- 11 open and read back all -> 15 bytes
	call step
	defb 11
	ld de,fn1
	ld a,0
	ld c,43h
	call 5
	call chk0
	ld a,b
	ld (h1),a
	ld de,buf
	ld hl,40
	ld c,48h
	call 5
	call chk0
	ld a,l
	cp 15
	call chkz
	ld hl,buf
	ld de,expect
	ld b,15
	call cmpn
; print it via handle 1
	ld b,1
	ld de,buf
	ld hl,15
	ld c,49h
	call 5
	call crlf
	ld a,(h1)
	ld b,a
	ld c,45h
	call 5
	call chk0
; ---- 12 big file 1500 bytes pattern, write 300x5, read 512 chunks
	call step
	defb 12
	ld de,fn2
	ld a,0
	ld b,0
	ld c,44h
	call 5
	call chk0
	ld a,b
	ld (h1),a
	ld hl,buf          ; pattern 300 bytes
	ld b,0
	ld c,0
	ld e,3
fp:	ld (hl),e
	ld a,e
	add a,7
	ld e,a
	inc hl
	inc bc
	ld a,b
	cp 1
	jr nz,fp
	ld a,c
	cp 44
	jr nz,fp
	ld b,5
w5:	push bc
	ld a,(h1)
	ld b,a
	ld de,buf
	ld hl,300
	ld c,49h
	call 5
	call chk0
	pop bc
	djnz w5
	ld a,(h1)
	ld b,a
	ld c,45h
	call 5
	call chk0
	ld de,fn2
	ld a,0
	ld c,43h
	call 5
	call chk0
	ld a,b
	ld (h1),a
	ld hl,0
	ld (tot),hl
rd1:	ld a,(h1)
	ld b,a
	ld de,buf2
	ld hl,512
	ld c,48h
	call 5
	ld a,h
	or l
	jr z,rdend
	ld de,(tot)
	add hl,de
	ld (tot),hl
	jr rd1
rdend:	ld hl,(tot)
	ld de,1500
	or a
	sbc hl,de
	ld a,h
	or l
	call chkz
; ---- 13 console read (handle 0): type  AB<Enter>
	call step
	defb 13
	ld de,mtype
	ld c,9
	call 5
	ld b,0
	ld de,buf
	ld hl,20
	ld c,48h
	call 5
	call chk0
	ld a,l
	call phex
	ld a,(buf)
	ld e,a
	ld c,2
	call 5
	ld a,(buf+1)
	ld e,a
	ld c,2
	call 5
	call crlf
	ld de,mdone
	ld c,9
	call 5
	jp 0

	include "hndlib.inc"
mhead:	defm "HT:",13,10,"$"
mtype:	defm "type AB: $"
mdone:	defm "HT DONE",13,10,"$"
fn1:	defm "HT1.TXT",0
fn2:	defm "BIG.BIN",0
txt:	defm "HELLO WORLD"
ex3:	defm "!!!"
exz:	defm "Z"
expect:	defm "HELLO WORLD!!!Z"
h1:	defb 0
h2:	defb 0
tot:	defw 0
buf:	defs 512
buf2:	defs 512
