; pgwin f|v : 物理ページ 07h-09h をバンク3(6000H)の窓に出して、パターンを書く(f)/確かめる(v)。
; ページを予約せずに直接 MMU を触る例でもある。 OS/IOCS/他のコマンドがこのページを壊さないことの試験用。
	org 0100h
	ld sp,0A000h
	ld hl,0081h
pw0:	ld a,(hl)
	cp ' '
	jr nz,pw1
	inc hl
	jr pw0
pw1:	or 20h
	ld (mode),a
	ld b,7
pw_lp:	ld a,b
	ld (pg),a
	call opn
	ld a,(pg)
	ld e,a
	add a,a
	add a,a
	add a,a
	add a,e
	ld c,a
	ld hl,06000h
	ld de,02000h
pw_b:	ld a,l
	xor h
	add a,c
	ld b,a
	ld a,(mode)
	cp 'f'
	ld a,b
	jr nz,pw_v
	ld (hl),a
	jr pw_n
pw_v:	cp (hl)
	jr nz,pw_bad
pw_n:	inc hl
	dec de
	ld a,d
	or e
	jr nz,pw_b
	call cls
	ld a,(pg)
	ld b,a
	inc b
	ld a,b
	cp 0Ah
	jr c,pw_lp
	ld de,(mode)
	ld a,(mode)
	cp 'f'
	ld de,m_f
	jr z,pw_out
	ld de,m_v
pw_out:	ld c,9
	call 5
	jp 0
pw_bad:	call cls
	ld de,m_ng
	ld c,9
	call 5
	ld a,(pg)
	add a,'0'
	ld e,a
	ld c,2
	call 5
	jp 0
opn:	di
	ld a,3
	out (0B4h),a
	in a,(0B5h)
	ld (orig),a
	ld a,3
	out (0B4h),a
	ld a,(pg)
	out (0B5h),a
	ret
cls:	ld a,3
	out (0B4h),a
	ld a,(orig)
	out (0B5h),a
	ei
	ret
mode:	defb 0
pg:	defb 0
orig:	defb 0
m_f:	defm "FILL-OK",13,10,"$"
m_v:	defm "VERIFY-OK",13,10,"$"
m_ng:	defm "NG page $"
