;@cp932
; HITBLOW.COM - 数当てゲーム(ヒット&ブロー)。 コンピュータが決めた「重ならない4つの数字」を当てる。     MIT License
;   ヒット=数字も位置も合っている数  ブロー=数字は合っているが位置が違う数。 10回までに当てる。 q で降参。
	org 0100h
	ld sp,0A000h
	call seedinit
	call kon
	call cls
	ld hl,mtitle
	call pstr
newgame:
	call makesecret
	xor a
	ld (tries),a
turn:	ld a,(tries)
	cp 10
	jp nc,lose
	inc a
	ld (tries),a
	ld l,a
	ld h,0
	call pdec
	ld hl,mprompt
	call pstr
	ld hl,gbuf
	ld b,8
	call getline
	ld a,(gbuf)
	call lcase
	cp 'q'
	jp z,giveup
	ld a,(gbuf)
	or a
	jr z,badin
	; 4桁・数字・重なりなしを確かめる
	ld hl,gbuf
	ld b,4
chk1:	ld a,(hl)
	call isdigit
	jr nc,badin
	inc hl
	djnz chk1
	ld a,(hl)
	or a
	jr nz,badin
	ld hl,gbuf
	ld b,3
chk2:	ld a,(hl)
	inc hl
	push hl
	push bc
	ld c,a
chk3:	ld a,(hl)
	cp c
	jr z,badin2
	inc hl
	djnz chk3
	pop bc
	pop hl
	dec b
	jr nz,chk2
	jr judge
badin2:	pop bc
	pop hl
badin:	ld hl,mbad
	call pstr
	ld hl,tries
	dec (hl)
	jp turn
judge:	ld c,0			; ヒット
	ld d,0			; ブロー
	ld ix,gbuf
	ld b,0			; i
j1:	ld a,(ix+0)
	ld e,a
	ld iy,secret
	ld h,0			; j
j2:	ld a,(iy+0)
	cp e
	jr nz,j3
	ld a,b
	cp h
	jr nz,j4
	inc c
	jr j3
j4:	inc d
j3:	inc iy
	inc h
	ld a,h
	cp 4
	jr nz,j2
	inc ix
	inc b
	ld a,b
	cp 4
	jr nz,j1
	push bc
	push de
	ld hl,mhit
	call pstr
	pop de
	pop bc
	push de
	ld l,c
	ld h,0
	call pdec
	ld hl,mblow
	call pstr
	pop de
	ld l,d
	ld h,0
	call pdec
	call pnl
	ld a,c
	cp 4
	jp nz,turn
	ld hl,mwin1
	call pstr
	ld a,(tries)
	ld l,a
	ld h,0
	call pdec
	ld hl,mwin2
	call pstr
	jr again
lose:	ld hl,mlose
	call pstr
	call showans
	jr again
giveup:	ld hl,mgive
	call pstr
	call showans
again:	ld hl,magain
	call pstr
	call askyn
	or a
	jp nz,newgame
	call koff
	ld c,0
	jp 5
showans:ld hl,manswer
	call pstr
	ld hl,secret
	ld b,4
sa1:	ld a,(hl)
	inc hl
	call pchr
	djnz sa1
	jp pnl
; 重ならない数字4つを '0'-'9' で secret へ
makesecret:
	ld b,0
ms1:	ld a,10
	call rndn
	add a,'0'
	ld c,a
	ld hl,secret
	ld d,b
ms2:	ld a,d
	or a
	jr z,ms3
	ld a,(hl)
	cp c
	jr z,ms1
	inc hl
	dec d
	jr ms2
ms3:	ld hl,secret
	ld e,b
	ld d,0
	add hl,de
	ld (hl),c
	inc b
	ld a,b
	cp 4
	jr nz,ms1
	ret
	include "gamelib.inc"
tries:	defb 0
secret:	defs 4
gbuf:	defs 12
mtitle:	defm "== ヒット&ブロー ==",13,10
	defm "私が決めた4つの数字(0-9、重なりなし)を当ててください。",13,10
	defm "ヒット=数字も位置も合っている  ブロー=数字だけ合っている",13,10
	defm "10回までに当てれば勝ち。 q で降参。",13,10,13,10,0
mprompt: defm "回目 4つの数字? ",0
mbad:	defm "  4つの違う数字で入力してください",13,10,0
mhit:	defm "  ヒット ",0
mblow:	defm "  ブロー ",0
mwin1:	defm "正解です!  ",0
mwin2:	defm " 回で当てました。",13,10,0
mlose:	defm "残念、10回では当たりませんでした。",13,10,0
mgive:	defm "降参ですね。",13,10,0
manswer: defm "答えは ",0
magain:	defm "もう一度? (y/n) ",0
