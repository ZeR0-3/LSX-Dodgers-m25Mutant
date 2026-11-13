; WC.COM - 行数・語数・バイト数。 wc [-lwc] [file ...]  (file省略/-/con は標準入力)   MIT License
	org 0100h
	ld sp,0A000h
	call tailinit
	xor a
	ld (mask),a
	ld (nf),a
op1:	call sk
	or a
	jr z,opd
	cp '-'
	jr nz,opd
	inc hl
	ld a,(hl)
	cp ' '
	jr z,opd0		; 単独の - は標準入力名
	or a
	jr z,opd0
op2:	ld a,(hl)
	or a
	jr z,op1
	cp ' '
	jr z,op1
	or 20h
	ld b,1
	cp 'l'
	jr z,op3
	ld b,2
	cp 'w'
	jr z,op3
	ld b,4
	cp 'c'
	jr z,op3
	ld de,musage
	ld c,9
	call 5
	jp 0
op3:	ld a,(mask)
	or b
	ld (mask),a
	inc hl
	jr op2
opd0:	dec hl
opd:	ld a,(mask)
	or a
	jr nz,opm
	ld a,7
	ld (mask),a
opm:	ld (fp),hl
	push hl
	ld hl,tl
	ld de,tl+1
	ld (hl),0
	ld bc,11
	ldir
	pop hl
	ld a,(hl)
	or a
	jr nz,files
	; 標準入力
	xor a
	ld (inh),a
	ld hl,nostr
	ld (nmp),hl
	call count
	call report
	jp done
files:	ld hl,(fp)
	call sk
	or a
	jr z,fdone
	ld (nmp),hl
	call tokend
	ld (fp),hl
	ld de,(nmp)
	call openin
	jr nc,fo1
	ld de,mopen
	ld c,9
	call 5
	jr files
fo1:	ld a,b
	ld (inh),a
	call count
	call closein
	call report
	ld a,(nf)
	inc a
	ld (nf),a
	; 合計に足す
	ld hl,cl
	ld de,tl
	call add32
	jr files
fdone:	ld a,(nf)
	cp 2
	jr c,done
	ld hl,tl
	ld de,cl
	ld bc,12
	ldir
	ld hl,totstr
	ld (nmp),hl
	call report
done:	call flush
	jp 0
; cl,cw,cb(各4バイト)に tl,tw,tb を足し込む (HL=cl DE=tl の組を3つ)
add32:	ld b,3
a3:	push bc
	push hl
	push de
	ld b,4
	or a
a4:	ld a,(de)
	adc a,(hl)
	ld (de),a
	inc de
	inc hl
	djnz a4
	pop de
	pop hl
	ld bc,4
	add hl,bc
	ex de,hl
	add hl,bc
	ex de,hl
	pop bc
	djnz a3
	ret
; 現在の入力を数える
count:	ld hl,0
	ld (cl),hl
	ld (cl+2),hl
	ld (cw),hl
	ld (cw+2),hl
	ld (cb),hl
	ld (cb+2),hl
	xor a
	ld (inw),a
cn1:	call rdb
	ret c
	ld c,a
	ld hl,cb
	call inc32
	ld a,c
	cp 0Ah
	jr nz,cn2
	ld hl,cl
	call inc32
cn2:	ld a,c
	cp 21h
	jr c,cn3
	ld a,(inw)
	or a
	jr nz,cn1
	ld a,1
	ld (inw),a
	ld hl,cw
	call inc32
	jr cn1
cn3:	xor a
	ld (inw),a
	jr cn1
inc32:	inc (hl)
	ret nz
	inc hl
	inc (hl)
	ret nz
	inc hl
	inc (hl)
	ret nz
	inc hl
	inc (hl)
	ret
; DEHL=(HL)の32bit
ld32:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld h,d
	ld l,e
	ld d,b
	ld e,c
	ret
; 選ばれた数を出して名前
report:	ld a,(mask)
	and 1
	jr z,r1
	ld hl,cl
	call ld32
	ld b,7
	call pnum
r1:	ld a,(mask)
	and 2
	jr z,r2
	ld hl,cw
	call ld32
	ld b,8
	call pnum
r2:	ld a,(mask)
	and 4
	jr z,r3
	ld hl,cb
	call ld32
	ld b,8
	call pnum
r3:	ld a,' '
	call wrb
	ld hl,(nmp)
	call wrs
	call wcrlf
	ret
mask:	defb 0
nf:	defb 0
fp:	defw 0
nmp:	defw 0
inw:	defb 0
nostr:	defb 0
totstr:	defm "total"
	defb 0
mopen:	defm "wc: cannot open file",13,10,"$"
musage:	defm "usage: wc [-lwc] [file ...]",13,10,"$"
cl	equ 3E00h
cw	equ 3E04h
cb	equ 3E08h
tl	equ 3E0Ch
tw	equ 3E10h
tb	equ 3E14h

; ===== 共通部品 =====
; 作業領域(ファイルに含めない): ibuf 3C00h(512) obuf 3F00h(256, 256境界) ほか各コマンド固有は 4000h 以降
ibuf	equ 3C00h
obuf	equ 3F00h
tailinit:
	ld hl,0080h
	ld a,(hl)
	inc hl
	ld e,a
	ld d,0
	add hl,de
	ld (hl),0
	ld hl,0081h
	ld a,obuf>>8
	ld (opos+1),a
	xor a
	ld (opos),a
	ld (outh2),a
	ld a,1
	ld (outh),a
	ld hl,0
	ld (icnt),hl
	ld hl,0081h
	ret
; HL の空白を飛ばす (A=次の文字)
sk:	ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr sk
; HL=トークン先頭 -> 終端(空白を0にする)して HL=次
tokend:	ld a,(hl)
	or a
	ret z
	cp ' '
	jr z,te1
	inc hl
	jr tokend
te1:	ld (hl),0
	inc hl
	ret
; HL=10進数 -> DE=値, HL=次
atoi:	ld de,0
at1:	ld a,(hl)
	sub '0'
	cp 10
	ret nc
	push hl
	ld h,d
	ld l,e
	add hl,hl
	add hl,hl
	add hl,de
	add hl,hl
	ld e,a
	ld d,0
	add hl,de
	ex de,hl
	pop hl
	inc hl
	jr at1
; DE=名前: "con" か "-" なら Z
iscon:	push de
	ld a,(de)
	cp '-'
	jr nz,ic0
	inc de
	ld a,(de)
	or a
	jr ic2
ic0:	ld b,3
	ld hl,conn
ic1:	ld a,(de)
	or 20h
	cp (hl)
	jr nz,ic2
	inc de
	inc hl
	djnz ic1
	ld a,(de)
	or a
ic2:	pop de
	ret
conn:	defm "con"
; DE=名前 -> 入力を開く。B=ハンドル、CF=1 エラー。(con/- は標準入力 B=0)
openin:	push de
	call iscon
	pop de
	jr nz,oi1
	ld b,0
	or a
	ret
oi1:	ld a,1
	ld c,43h
	call 5
	or a
	ret z
	scf
	ret
; (inh) の入力を閉じる(B=0 のときは何もしない)
closein:ld a,(inh)
	or a
	ret z
	ld b,a
	ld c,45h
	jp 5
; 1バイト読む: A=バイト, CF=1 EOF。(inh)=ハンドル。全レジスタ破壊
rdb:	ld hl,(icnt)
	ld a,h
	or l
	jr nz,rd2
	ld a,(inh)
	ld b,a
	ld de,ibuf
	ld hl,512
	ld c,48h
	call 5
	or a
	jr nz,rdeof
	ld a,h
	or l
	jr z,rdeof
	ld (icnt),hl
	ld hl,ibuf
	ld (ipos),hl
rd2:	ld hl,(icnt)
	dec hl
	ld (icnt),hl
	ld hl,(ipos)
	ld a,(hl)
	inc hl
	ld (ipos),hl
	or a
	ret
rdeof:	scf
	ret
; 1行読む: DE=バッファ(最大254文字)。CRは捨て、LFで終わり、0終端。CF=1 でデータなしのEOF
rdline:	ld hl,254
	ld (rlmax),hl
	ld (rlp),de
	ld bc,0			; BC=文字数
rl1:	push bc
	call rdb
	pop bc
	jr c,rleof
	cp 0Ah
	jr z,rlend
	cp 0Dh
	jr z,rl1
	ld d,a
	ld a,c
	cp 254
	jr nc,rl1
	ld hl,(rlp)
	ld (hl),d
	inc hl
	ld (rlp),hl
	inc c
	jr rl1
rlend:	ld hl,(rlp)
	ld (hl),0
	or a
	ret
rleof:	ld a,c
	or a
	jr z,rle2
	jr rlend
rle2:	ld hl,(rlp)
	ld (hl),0
	scf
	ret
rlmax:	defw 0
rlp:	defw 0
; 出力(バッファ付き)。A=バイト
wrb:	push hl
	ld hl,(opos)
	ld (hl),a
	inc l
	ld (opos),hl
	pop hl
	ret nz
	push af
	push bc
	push de
	push hl
	ld hl,256
	jr fl0
flush:	push af
	push bc
	push de
	push hl
	ld hl,(opos)
	ld h,0
	ld a,l
	or a
	jr z,flx
fl0:	push hl
	ld a,(outh)
	ld b,a
	ld de,obuf
	ld c,49h
	call 5
	pop hl
	ld a,(outh2)
	or a
	jr z,flx
	ld b,a
	ld de,obuf
	ld c,49h
	call 5
flx:	ld hl,obuf
	ld (opos),hl
	pop hl
	pop de
	pop bc
	pop af
	ret
; HL=0終端文字列を出力
wrs:	ld a,(hl)
	or a
	ret z
	call wrb
	inc hl
	jr wrs
wcrlf:	ld a,0Dh
	call wrb
	ld a,0Ah
	jp wrb
; DEHL(DE=上位) を B桁の右詰め10進で出力
pnum:	push bc
	push hl
	ld hl,nbuf
	ld b,11
	ld a,' '
pn1:	ld (hl),a
	inc hl
	djnz pn1
	pop hl
	ld a,10
	ld (pnp),a
pn2:	xor a
	ld b,32
pn3:	add hl,hl
	rl e
	rl d
	rla
	cp 10
	jr c,pn4
	sub 10
	inc l
pn4:	djnz pn3
	add a,'0'
	push hl
	push af
	ld a,(pnp)
	ld c,a
	ld b,0
	ld hl,nbuf
	add hl,bc
	pop af
	ld (hl),a
	pop hl
	ld a,h
	or l
	or d
	or e
	jr z,pn5
	ld a,(pnp)
	dec a
	ld (pnp),a
	jr pn2
pn5:	pop bc
	ld a,11
	sub b
	jr nc,pn6
	xor a
pn6:	ld c,a
	ld a,(pnp)
	cp c
	jr nc,pn7
	ld c,a
pn7:	ld b,0
	ld hl,nbuf
	add hl,bc
	ld a,11
	sub c
	ld b,a
pn8:	ld a,(hl)
	call wrb
	inc hl
	djnz pn8
	ret
pnp:	defb 0
inh:	defb 0
outh:	defb 1
outh2:	defb 0
opos:	defw 0
icnt:	defw 0
ipos:	defw 0
nbuf	equ 3EE0h
