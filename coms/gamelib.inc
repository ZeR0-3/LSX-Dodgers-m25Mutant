; GAMELIB.INC - ゲーム共通ルーチン(コンソール入出力・乱数・10進表示)。MIT License
; 文字は BDOS 02h、キーは BDOS 06h(待たずに調べる)。画面は ESC E(消去) ESC Y 行+20h 桁+20h(位置)
pchr:	push hl
	push de
	push bc
	ld e,a
	ld c,2
	call 5
	pop bc
	pop de
	pop hl
	ret
pstr:	ld a,(hl)
	or a
	ret z
	inc hl
	call pchr
	jr pstr
pnl:	ld a,13
	call pchr
	ld a,10
	jp pchr
cls:	ld a,27
	call pchr
	ld a,'E'
	jp pchr
; 行 B 桁 C (0から) へカーソル
at:	ld a,27
	call pchr
	ld a,'Y'
	call pchr
	ld a,b
	add a,20h
	call pchr
	ld a,c
	add a,20h
	jp pchr
kon:	ld a,27			; 漢字モード ON
	call pchr
	ld a,'k'
	call pchr
	ld a,'1'
	jp pchr
koff:	ld a,27
	call pchr
	ld a,'k'
	call pchr
	ld a,'0'
	jp pchr
; HL=0..65535 を10進で表示
pdec:	ld de,pdbuf+6
	xor a
	ld (de),a
pd1:	call div10
	add a,'0'
	dec de
	ld (de),a
	ld a,h
	or l
	jr nz,pd1
	ex de,hl
	jp pstr
; HL を 10 で割る -> HL=商 A=あまり
div10:	xor a
	ld b,16
d10:	add hl,hl
	rla
	cp 10
	jr c,d10b
	sub 10
	inc l
d10b:	djnz d10
	ret
; HL=HL/DE (16ビット) -> HL=商 DE=あまり  (DE=0 なら HL=0FFFFh)
divhl:	ld a,d
	or e
	jr nz,dv0
	ld hl,0FFFFh
	ret
dv0:	ld b,h
	ld c,l
	ld hl,0
	ld a,16
dv1:	sla c
	rl b
	adc hl,hl
	or a
	sbc hl,de
	jr nc,dv2
	add hl,de
	jr dv3
dv2:	inc c
dv3:	dec a
	jr nz,dv1
	ex de,hl
	ld h,b
	ld l,c
	ret
; 1文字(待つ) -> A。待っているあいだに乱数の種を進める
getkey:	push hl
	ld hl,(rseed)
gk1:	inc hl
	push hl
	ld e,0FFh
	ld c,6
	call 5
	pop hl
	or a
	jr z,gk1
	ld (rseed),hl
	pop hl
	ret
; HL=バッファ B=最大文字数: 1行読む(エコーあり BSあり) -> NUL終わり, A=文字数
getline:ld c,0
gl1:	push hl
	push bc
	call getkey
	pop bc
	pop hl
	cp 13
	jr z,gl9
	cp 08h
	jr z,gl_bs
	cp 7Fh
	jr z,gl_bs
	cp 20h
	jr c,gl1
	push af
	ld a,c
	cp b
	jr nc,gl_full
	pop af
	ld (hl),a
	inc hl
	inc c
	call pchr
	jr gl1
gl_full:pop af
	jr gl1
gl_bs:	ld a,c
	or a
	jr z,gl1
	dec hl
	dec c
	ld a,8
	call pchr
	ld a,' '
	call pchr
	ld a,8
	call pchr
	jr gl1
gl9:	ld (hl),0
	call pnl
	ld a,c
	ret
; 乱数 (xorshift 16ビット) -> HL
rnd16:	ld hl,(rseed)
	ld a,h
	or l
	jr nz,rn1
	inc hl
rn1:	ld d,h
	ld e,l
	ld b,7
rn2:	add hl,hl
	djnz rn2
	ld a,h
	xor d
	ld h,a
	ld a,l
	xor e
	ld l,a
	ld a,h
	srl a
	xor l
	ld l,a
	ld a,h
	xor l
	ld h,a
	ld (rseed),hl
	ret
; A=n -> A=0..n-1
rndn:	push bc
	push de
	push hl
	ld c,a
	call rnd16
	ld a,h
	ld e,c
	ld d,0
	ld hl,0
	ld b,8
rm1:	add hl,hl
	rlca
	jr nc,rm2
	add hl,de
rm2:	djnz rm1
	ld a,h
	pop hl
	pop de
	pop bc
	ret
; 起動: 乱数の種 (Rレジスタ) と SP
seedinit:
	ld a,r
	ld h,a
	ld a,r
	xor 5Ah
	ld l,a
	ld (rseed),hl
	ret
rseed:	defw 1234h
pdbuf:	defs 8
; 数字(0-9)なら CF=1
isdigit:cp '0'
	jr c,idn
	cp '9'+1
	ret
idn:	and a
	ret
; 小文字にする
lcase:	cp 'A'
	ret c
	cp 'Z'+1
	ret nc
	or 20h
	ret
; yes/no を聞く: A=1 ならはい
askyn:	call getkey
	call lcase
	cp 'y'
	jr z,ayy
	cp 'n'
	jr z,ayn
	jr askyn
ayy:	ld a,'y'
	call pchr
	call pnl
	ld a,1
	ret
ayn:	ld a,'n'
	call pchr
	call pnl
	xor a
	ret
