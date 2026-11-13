; KMODE [ON|OFF]  漢字モード(Shift_JIS の全角表示)を切り替える。引数なしはON。
; コンソールに ESC k 1 / ESC k 0 を出すだけ(本体の画面出力が受ける)。
	org 0100h
	ld hl,0081h
ks:	ld a,(hl)
	cp ' '
	jr nz,k1
	inc hl
	jr ks
k1:	ld e,'1'
	cp '0'
	jr z,off
	and 0dfh		; 大文字化
	cp 'O'
	jr nz,go
	inc hl
	ld a,(hl)
	and 0dfh
	cp 'F'
	jr nz,go
off:	ld e,'0'
go:	push de
	ld e,27
	ld c,2
	call 5
	ld e,'k'
	ld c,2
	call 5
	pop de
	ld c,2
	call 5
	jp 0
