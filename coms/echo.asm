; ECHO.COM - 引数を標準出力(BDOS 02h。`>` でファイルにも書ける)へ出して改行する。 MIT License
; 使い方: echo [-n] 文字列 ...     ダブルクォート(")は取り除く(シェル風)。-n は改行しない
; BAT 内で使う想定。sh.COM が作る BAT も echo を使う。
	org 0100h
	ld sp,0A000h
	ld hl,0080h
	ld a,(hl)
	inc hl
	ld e,a
	ld d,0
	add hl,de
	ld (hl),0		; 引数文字列を 0 で終端
	ld hl,0081h
	call skip
	ld b,1			; B=1:改行する
	ld a,(hl)
	cp '-'
	jr nz,loop
	inc hl
	ld a,(hl)
	cp 'n'
	jr nz,back
	inc hl
	ld a,(hl)
	or a
	jr z,nonl
	cp ' '
	jr nz,back
nonl:	ld b,0
	call skip
	jr loop
back:	dec hl			; "-x" は普通の文字として出す
loop:	ld a,(hl)
	or a
	jr z,fin
	inc hl
	cp '"'
	jr z,loop
	ld e,a
	push hl
	push bc
	ld c,2
	call 5
	pop bc
	pop hl
	jr loop
fin:	ld a,b
	or a
	jp z,0
	ld e,13
	ld c,2
	call 5
	ld e,10
	ld c,2
	call 5
	jp 0
skip:	ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr skip
