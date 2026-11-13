; COLOR [0-7] [R] [N]  文字色(ANSI順 0黒 1赤 2緑 3黄 4青 5紫 6水色 7白)を ESC b n で、R で反転ON(ESC p)、N で反転OFF(ESC q)。
; 引数なしは白・反転OFFに戻す。例: color 2   color 1 r   color
	org 0100h
	ld hl,0081h
	ld c,0			; 0:指定なし
cl:	ld a,(hl)
	inc hl
	cp 0dh
	jr z,fin
	or a
	jr z,fin
	cp '0'
	jr c,cl
	cp '8'
	jr nc,cl2
	ld c,1
	ld b,a
	ld e,27
	call pc
	ld e,'b'
	call pc
	ld e,b
	call pc
	jr cl
cl2:	and 0dfh
	ld e,'p'
	cp 'R'
	jr z,esc
	ld e,'q'
	cp 'N'
	jr nz,cl
esc:	ld c,1
	push de
	ld e,27
	call pc
	pop de
	call pc
	jr cl
fin:	ld a,c
	or a
	jp nz,0
	ld e,27			; 引数なし: 白・反転OFF
	call pc
	ld e,'b'
	call pc
	ld e,'7'
	call pc
	ld e,27
	call pc
	ld e,'q'
	call pc
	jp 0
pc:	push bc
	push hl
	ld c,2
	call 5
	pop hl
	pop bc
	ret
