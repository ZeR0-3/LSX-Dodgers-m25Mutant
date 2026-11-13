; pgtest - coms/pglib.inc の試験。 空きページを予約して pgwrite/pgread で往復し、BDOS を呼んだ後でも残ることを確かめる。
	org 0100h
	ld sp,0A000h
	ld e,0FFh
	ld c,0E2h
	call 5
	or a
	jp nz,t_ng
	ld a,b
	ld (page),a
	; 1. 先頭256B・中間・末尾16B にパターンを書く
	ld hl,buf1
	ld b,0
t_f1:	ld a,l
	xor 5Ah
	ld (hl),a
	inc hl
	djnz t_f1		; buf1 = 256B (L が一周)
	ld a,(page)
	ld hl,0
	ld de,buf1
	ld bc,256
	call pgwrite
	jp c,t_ng
	ld a,(page)
	ld hl,1F00h
	ld de,buf1
	ld bc,256		; 1F00h+256 = 2000h ちょうどで範囲内
	call pgwrite
	jp c,t_ng
	; 2. 範囲外は CF=1 で何もしない
	ld a,(page)
	ld hl,1F01h
	ld de,buf1
	ld bc,256
	call pgwrite
	jp nc,t_ng
	; 3. BDOS を呼ぶ(窓は閉じている)
	ld de,m_mid
	ld c,9
	call 5
	; 4. 読み戻して比較
	ld a,(page)
	ld hl,0
	ld de,buf2
	ld bc,256
	call pgread
	jp c,t_ng
	ld hl,buf1
	ld de,buf2
	ld b,0
t_c1:	ld a,(de)
	cp (hl)
	jp nz,t_ng
	inc hl
	inc de
	djnz t_c1
	ld a,(page)
	ld hl,1F00h
	ld de,buf2
	ld bc,256
	call pgread
	jp c,t_ng
	ld hl,buf1
	ld de,buf2
	ld b,0
t_c2:	ld a,(de)
	cp (hl)
	jp nz,t_ng
	inc hl
	inc de
	djnz t_c2
	; 5. 割り込み状態が保たれる(許可 -> 許可、禁止 -> 禁止)
	ei
	ld a,(page)
	ld hl,0
	ld de,buf2
	ld bc,1
	call pgread
	ld a,i
	jp po,t_ng
	di
	ld a,(page)
	ld hl,0
	ld de,buf2
	ld bc,1
	call pgread
	ld a,i
	jp pe,t_ng
	ei
	; 6. 解放
	ld a,(page)
	ld e,a
	ld c,0E3h
	call 5
	or a
	jp nz,t_ng
	ld de,m_ok
	ld c,9
	call 5
	jp 0
t_ng:	ld de,m_ng
	ld c,9
	call 5
	jp 0
	include "pglib.inc"
page:	defb 0
m_mid:	defm "mid",13,10,"$"
m_ok:	defm "PGLIB-OK",13,10,"$"
m_ng:	defm "PGLIB-NG",13,10,"$"
buf1:	defs 256
buf2:	defs 256
