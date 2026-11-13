; AWKU.INC - awk.asm 用の基本ルーチン: 32ビット整数、文字列、値(cell)の変換。MIT License
; 値 (cell, 6バイト): +0 型  +1..+4 データ
;   型 0=数 (32ビット符号つき)  1=文字列 (+1,+2 に番地)  2=数字かもしれない文字列 (入力のフィールド。比較では数に見えれば数)  3=未設定 (0 でも "" でもある)
T_NUM	equ	0
T_STR	equ	1
T_SNUM	equ	2
T_UNK	equ	3

; ---- 32ビット (na, nb, nr は4バイトの作業領域) ----
add32:	ld hl,(na)
	ld de,(nb)
	add hl,de
	ld (na),hl
	ld hl,(na+2)
	ld de,(nb+2)
	adc hl,de
	ld (na+2),hl
	ret
sub32:	ld hl,(na)
	ld de,(nb)
	or a
	sbc hl,de
	ld (na),hl
	ld hl,(na+2)
	ld de,(nb+2)
	sbc hl,de
	ld (na+2),hl
	ret
neg32:	ld hl,(na)
	ld a,l
	cpl
	ld l,a
	ld a,h
	cpl
	ld h,a
	ld de,1
	add hl,de
	ld (na),hl
	ld hl,(na+2)
	ld a,l
	cpl
	ld l,a
	ld a,h
	cpl
	ld h,a
	ld de,0
	adc hl,de
	ld (na+2),hl
	ret
; nb も同様に符号を反転
negb:	ld hl,nb
	ld de,na
	ld bc,4
	ldir
	ld hl,na
	ld de,tmp4
	ld bc,4
	ldir
	ld hl,nb
	ld de,na
	ld bc,4
	ldir
	call neg32
	ld hl,na
	ld de,nb
	ld bc,4
	ldir
	ld hl,tmp4
	ld de,na
	ld bc,4
	ldir
	ret
shl32:	ld hl,(na)
	add hl,hl
	ld (na),hl
	ld hl,(na+2)
	adc hl,hl
	ld (na+2),hl
	ret
shr32b:	ld hl,(nb+2)
	srl h
	rr l
	ld (nb+2),hl
	ld hl,(nb)
	rr h
	rr l
	ld (nb),hl
	ret
; na = na * nb (下位32ビット)
mul32:	ld hl,0
	ld (nr),hl
	ld (nr+2),hl
	ld b,32
m32l:	push bc
	ld a,(nb)
	and 1
	jr z,m32s
	ld hl,(nr)
	ld de,(na)
	add hl,de
	ld (nr),hl
	ld hl,(nr+2)
	ld de,(na+2)
	adc hl,de
	ld (nr+2),hl
m32s:	call shl32
	call shr32b
	pop bc
	djnz m32l
	ld hl,(nr)
	ld (na),hl
	ld hl,(nr+2)
	ld (na+2),hl
	ret
; 符号なし na / nb -> 商 na, 余り nr   (nb=0 のときは商 0 余り 0)
udiv32:	ld hl,(nb)
	ld de,(nb+2)
	ld a,h
	or l
	or d
	or e
	jr nz,ud0
	ld hl,0
	ld (na),hl
	ld (na+2),hl
	ld (nr),hl
	ld (nr+2),hl
	ret
ud0:	ld hl,0
	ld (nr),hl
	ld (nr+2),hl
	ld b,32
udl:	push bc
	call shl32		; na を左へ。溢れたビット(CF)を nr の最下位へ
	ld hl,(nr)
	adc hl,hl
	ld (nr),hl
	ld hl,(nr+2)
	adc hl,hl
	ld (nr+2),hl
	; nr >= nb ?
	ld hl,(nr)
	ld de,(nb)
	or a
	sbc hl,de
	ld hl,(nr+2)
	ld de,(nb+2)
	sbc hl,de
	jr c,udn
	ld hl,(nr)
	ld de,(nb)
	or a
	sbc hl,de
	ld (nr),hl
	ld hl,(nr+2)
	ld de,(nb+2)
	sbc hl,de
	ld (nr+2),hl
	ld hl,na
	set 0,(hl)
udn:	pop bc
	djnz udl
	ret
; 符号つき割り算: na / nb -> 商 na、余り nr (余りは割られる数と同じ符号)
sdiv32:	xor a
	ld (sgn1),a
	ld (sgn2),a
	ld a,(na+3)
	bit 7,a
	jr z,sd1
	ld a,1
	ld (sgn1),a
	call neg32
sd1:	ld a,(nb+3)
	bit 7,a
	jr z,sd2
	ld a,1
	ld (sgn2),a
	call negb
sd2:	call udiv32
	ld a,(sgn1)
	ld hl,sgn2
	xor (hl)
	jr z,sd3
	call neg32		; 商の符号
sd3:	ld a,(sgn1)
	or a
	ret z
	ld hl,na		; 余りの符号 = 割られる数の符号
	ld de,tmp4
	ld bc,4
	ldir
	ld hl,nr
	ld de,na
	ld bc,4
	ldir
	call neg32
	ld hl,na
	ld de,nr
	ld bc,4
	ldir
	ld hl,tmp4
	ld de,na
	ld bc,4
	ldir
	ret
; 符号つき比較 na と nb -> A=-1/0/1 (Z=等しい)
cmp32:	ld hl,(na)
	ld de,(nb)
	or a
	sbc hl,de
	ld c,l
	ld b,h
	ld hl,(na+2)
	ld de,(nb+2)
	sbc hl,de
	push af
	ld a,h
	or l
	or b
	or c
	jr nz,cn1
	pop af
	xor a
	ret
cn1:	pop af
	jp pe,cn2
	jp m,cn_lt
	jr cn_gt
cn2:	jp m,cn_gt
cn_lt:	ld a,0FFh
	or a
	ret
cn_gt:	ld a,1
	or a
	ret

; ---- 文字列 ----
; HL=文字列 -> BC=長さ (HL保存)
slen:	push hl
	ld bc,0
sl_1:	ld a,(hl)
	or a
	jr z,sl_9
	inc hl
	inc bc
	jr sl_1
sl_9:	pop hl
	ret
; HL=元 DE=先 : 0まで写す。戻りは DE=先の0の位置
scpy:	ld a,(hl)
	ld (de),a
	or a
	ret z
	inc hl
	inc de
	jr scpy
; HL=a DE=b : 比較 -> A=-1/0/1 (Z=等しい)
scmp:	ld a,(de)
	cp (hl)
	jr nz,sc_n
	or a
	ret z
	inc hl
	inc de
	jr scmp
sc_n:	jr c,sc_gt
	ld a,0FFh
	or a
	ret
sc_gt:	ld a,1
	or a
	ret
upper:	cp 'a'
	ret c
	cp 'z'+1
	ret nc
	sub 20h
	ret
lower:	cp 'A'
	ret c
	cp 'Z'+1
	ret nc
	add a,20h
	ret
; A が数字か (CF=1:そう)
isdig:	cp '0'
	jr c,id_n
	cp '9'+1
	ret
id_n:	and a
	ret
; 一時領域から BC バイト取る -> HL
talloc:	ld hl,(tmpp)
	push hl
	add hl,bc
	ld de,tmpend
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,ta1
	ld hl,tmpbuf		; あふれたら先頭へ戻る(古い一時値は壊れうる)
	push hl
	add hl,bc
ta1:	ld (tmpp),hl
	pop hl
	ret

; ---- 文字列 <-> 数 ----
; HL=文字列 -> na (先頭の空白、符号、数字を読む。小数点以下は捨てる)。 HL は読み終わりの位置
s2n:	ld de,0
	ld (na),de
	ld (na+2),de
	xor a
	ld (sgn1),a
s2a:	ld a,(hl)
	cp ' '
	jr z,s2b
	cp 09h
	jr nz,s2c
s2b:	inc hl
	jr s2a
s2c:	cp '-'
	jr nz,s2d
	ld a,1
	ld (sgn1),a
	inc hl
	jr s2e
s2d:	cp '+'
	jr nz,s2e
	inc hl
s2e:	ld a,(hl)
	call isdig
	jr nc,s2f
	sub '0'
	push hl
	push af
	call shl32		; na = na*10 + 数字
	ld hl,(na)
	ld de,(na+2)
	push de
	push hl
	call shl32
	call shl32
	pop de
	ld hl,(na)
	add hl,de
	ld (na),hl
	ld hl,(na+2)
	pop de
	adc hl,de
	ld (na+2),hl
	pop af
	ld e,a
	ld d,0
	ld hl,(na)
	add hl,de
	ld (na),hl
	ld hl,(na+2)
	ld de,0
	adc hl,de
	ld (na+2),hl
	pop hl
	inc hl
	jr s2e
s2f:	ld a,(sgn1)
	or a
	call nz,neg32
	ret
; HL=文字列: 数に見えるか (CF=1:そう)。 空白、符号、数字(1つ以上)、小数、空白、終わり
looksnum:
ln0:	ld a,(hl)
	cp ' '
	jr z,ln1
	cp 09h
	jr nz,ln2
ln1:	inc hl
	jr ln0
ln2:	cp '-'
	jr z,ln3
	cp '+'
	jr nz,ln4
ln3:	inc hl
ln4:	ld b,0
ln5:	ld a,(hl)
	call isdig
	jr nc,ln6
	inc hl
	inc b
	jr ln5
ln6:	cp '.'
	jr nz,ln8
	inc hl
ln7:	ld a,(hl)
	call isdig
	jr nc,ln8
	inc hl
	inc b
	jr ln7
ln8:	ld a,b
	or a
	jr z,ln_n
ln9:	ld a,(hl)
	cp ' '
	jr z,lna
	cp 09h
	jr nz,lnb
lna:	inc hl
	jr ln9
lnb:	or a
	jr nz,ln_n
	scf
	ret
ln_n:	and a
	ret
; na (符号つき32ビット) -> 10進文字列を一時領域に作る。 HL=文字列 (na は保存)
n2s:	ld hl,na
	ld de,tmp4
	ld bc,4
	ldir			; 元の値を保存
	ld hl,dbuf2+14
	ld (n2p),hl
	xor a
	ld (hl),a
	ld a,(na+3)
	bit 7,a
	ld a,0
	jr z,n2a
	call neg32
	ld a,1
n2a:	ld (sgn1),a
n2b:	ld hl,10
	ld (nb),hl
	ld hl,0
	ld (nb+2),hl
	call udiv32
	ld a,(nr)
	add a,'0'
	ld hl,(n2p)
	dec hl
	ld (hl),a
	ld (n2p),hl
	ld hl,(na)
	ld a,h
	or l
	ld hl,(na+2)
	or h
	or l
	jr nz,n2b
	ld a,(sgn1)
	or a
	jr z,n2c
	ld hl,(n2p)
	dec hl
	ld (hl),'-'
	ld (n2p),hl
n2c:	ld bc,16
	call talloc
	push hl
	ex de,hl
	ld hl,(n2p)
	call scpy
	ld hl,tmp4
	ld de,na
	ld bc,4
	ldir
	pop hl
	ret
