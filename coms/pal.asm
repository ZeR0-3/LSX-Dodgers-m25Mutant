; PAL.COM - 4096色パレットボード(MZ-1M10, オプション)の色1-15を書き換える。  MIT License
;   pal            標準(8色のデジタル)に戻す。OPN ポートA bit2 を1に戻す
;   OPN ポートA bit2: 0=ボードの16色パレット(RGB444)を使う 1=デジタル8色。書き換えるのは bit2 だけで、他のビット(FDドライブ切替 bit1 など)は読み出して保つ
;   pal soft       原色より柔らかい色(文字色 1-7)にする
;   pal N RGB      色N(1-15)を RGB(16進3桁 0-F。例 F88)にする
;   ボードが無い機械では何も起きない(ポートAEhへ書くだけ)。ESC b n の色番号は ANSI順(0黒 1赤 2緑 3黄 4青 5紫 6水色 7白)で、
;   ハードの色(GRB: 1青 2赤 3紫 4緑 5水色 6黄 7白)とは番号が違う。pal N の N はハードの色番号。
	org 0100h
	ld hl,0081h
	call skip
	jr z,normal
	ld a,(hl)
	and 0dfh
	cp 'S'
	jr z,soft
	cp 'N'
	jr z,normal
	; 色N RGB
	call dec
	jp c,usage
	or a
	jp z,usage
	cp 16
	jp nc,usage
	ld (cn),a
	call skip
	jp z,usage
	call hex
	jp c,usage
	ld (cr),a
	call hex
	jp c,usage
	ld (cg),a
	call hex
	jp c,usage
	ld (cb),a
	call skip
	jp nz,usage
	ld a,(cn)
	call setone
	xor a
	call opna
	jp 0
normal:	ld a,4
	call opna
	jp 0
soft:	ld hl,tsoft
all:	ld a,1
al1:	push af
	ld a,(hl)
	ld (cr),a
	inc hl
	ld a,(hl)
	ld (cg),a
	inc hl
	ld a,(hl)
	ld (cb),a
	inc hl
	pop af
	push af
	push hl
	call setone
	pop hl
	pop af
	inc a
	cp 16
	jr c,al1
	xor a
	call opna
	jp 0
; OPN レジスタ0Eh(ポートA)の bit2 を A(0 か 4)にする。他のビットは読み出した値のまま
opna:	ld e,a
	call opnw
	ld a,0eh
	out (0c8h),a
	call opnw
	in a,(0c9h)
	and 0fbh
	or e
	ld d,a
	call opnw
	ld a,0eh
	out (0c8h),a
	call opnw
	ld a,d
	out (0c9h),a
	ret
opnw:	in a,(0c8h)
	rlca
	jr c,opnw
	ret
; A=色番号 (cr,cg,cb) を書く: 偶数=R<<4|B (B=n*2)、奇数=G (B=n*2+1)
setone:	add a,a
	ld b,a
	ld a,(cr)
	add a,a
	add a,a
	add a,a
	add a,a
	ld hl,cb
	or (hl)
	ld c,0aeh
	out (c),a
	inc b
	ld a,(cg)
	out (c),a
	ret
; 空白を飛ばす。Z=行の終わり
skip:	ld a,(hl)
	cp ' '
	jr nz,sk1
	inc hl
	jr skip
sk1:	cp 0dh
	ret z
	or a
	ret
; 10進(1-2桁)を A へ。CF=失敗
dec:	ld a,(hl)
	sub '0'
	cp 10
	ccf
	ret c
	ld b,a
	inc hl
	ld a,(hl)
	sub '0'
	cp 10
	jr nc,dec1
	ld c,a
	ld a,b
	add a,a
	ld d,a
	add a,a
	add a,a
	add a,d
	add a,c
	inc hl
	or a
	ret
dec1:	ld a,b
	or a
	ret
; 16進1桁を A へ(HLを進める)。CF=失敗
hex:	ld a,(hl)
	inc hl
	cp 'a'
	jr c,hx1
	sub 20h
hx1:	sub '0'
	jr c,hxe
	cp 10
	jr c,hxok
	sub 7
	cp 10
	jr c,hxe
	cp 16
	jr nc,hxe
hxok:	or a
	ret
hxe:	scf
	ret
usage:	ld de,musage
	ld c,9
	call 5
	jp 0
musage:	defm "usage: pal [soft | N RGB]  (N=1-15, RGB=hex 3 digits)",13,10,"$"
cn:	defb 0
cr:	defb 0
cg:	defb 0
cb:	defb 0
; 色1-15の R,G,B (0-15)。文字は色9-15(強度ビット付き)を使うので、1-7 と 9-15 に同じ柔らかい色を入れる。8 は暗いグレー
tsoft:	defb 8,9,15, 15,8,8, 15,9,15, 9,15,9, 8,14,15, 15,15,8, 12,12,12
	defb 3,3,3
	defb 8,9,15, 15,8,8, 15,9,15, 9,15,9, 8,14,15, 15,15,8, 12,12,12
