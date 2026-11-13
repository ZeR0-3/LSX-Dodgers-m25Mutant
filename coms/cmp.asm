; CMP.COM - 2つのファイルをバイト単位で比べる。 cmp file1 file2   (終了コード $? : 同じ 0 / 違う 1 / 開けない 2)   MIT License
	org 0100h
	ld sp,0A000h
	call tailinit
	call sk
	or a
	jp z,c_us
	ld d,h
	ld e,l
	call tokend
	ld (c_n1),de
	call sk
	or a
	jp z,c_us
	ld d,h
	ld e,l
	call tokend
	ld (c_n2),de
	ld de,(c_n1)
	ld a,1
	ld c,43h
	call 5
	or a
	jp nz,c_oe1
	ld a,b
	ld (c_h1),a
	ld de,(c_n2)
	ld a,1
	ld c,43h
	call 5
	or a
	jp nz,c_oe2
	ld a,b
	ld (c_h2),a
	ld hl,0
	ld (c_blk),hl
	inc hl
	ld (c_ln),hl
c_lp:	ld a,(c_h1)
	ld b,a
	ld de,b1
	call c_rd
	ld (c_c1),hl
	ld a,(c_h2)
	ld b,a
	ld de,b2
	call c_rd
	ld (c_c2),hl
	ld hl,(c_c1)
	ld de,(c_c2)
	or a
	sbc hl,de
	jr c,c_m1
	ld bc,(c_c2)
	jr c_m2
c_m1:	ld bc,(c_c1)
c_m2:	ld a,b
	or c
	jr z,c_cd
	ld hl,b1
	ld de,b2
c_cl:	ld a,(de)
	cp (hl)
	jr nz,c_df
	ld a,(hl)
	cp 0Ah
	jr nz,c_c3
	push hl
	ld hl,(c_ln)
	inc hl
	ld (c_ln),hl
	pop hl
c_c3:	inc hl
	inc de
	dec bc
	ld a,b
	or c
	jr nz,c_cl
c_cd:	ld hl,(c_c1)
	ld de,(c_c2)
	or a
	sbc hl,de
	jr z,c_eq
	jr c,c_s1
	ld hl,(c_n2)
	jr c_s2
c_s1:	ld hl,(c_n1)
c_s2:	push hl
	ld hl,c_meof
	call wrs
	pop hl
	call wrs
	call wcrlf
	ld b,1
	jr c_ex
c_eq:	ld hl,(c_c1)
	ld a,h
	cp 1
	jr nz,c_ok
	ld hl,(c_blk)
	inc hl
	ld (c_blk),hl
	jp c_lp
c_ok:	ld b,0
c_ex:	call flush
	ld c,62h
	call 5
	jp 0
c_df:	ld bc,b1
	or a
	sbc hl,bc
	ld c,l
	ld hl,(c_blk)
	ld a,h
	ld h,l
	ld l,c
	inc hl
	ld e,a
	ld a,h
	or l
	jr nz,c_d1
	inc e
c_d1:	ld d,0
	push de
	push hl
	ld hl,(c_n1)
	call wrs
	ld a,' '
	call wrb
	ld hl,(c_n2)
	call wrs
	ld hl,c_mdif
	call wrs
	pop hl
	pop de
	ld b,1
	call pnum
	ld hl,c_mln
	call wrs
	ld hl,(c_ln)
	ld de,0
	ld b,1
	call pnum
	call wcrlf
	ld b,1
	jr c_ex
c_oe1:	ld hl,(c_n1)
	jr c_oe
c_oe2:	ld hl,(c_n2)
c_oe:	push hl
	ld hl,c_mop
	call wrs
	pop hl
	call wrs
	call wcrlf
	ld b,2
	jr c_ex
c_us:	ld de,c_mus
	ld c,9
	call 5
	jp 0
c_rd:	ld hl,256
	ld c,48h
	call 5
	or a
	ret z
	ld hl,0
	ret
c_n1:	defw 0
c_n2:	defw 0
c_h1:	defb 0
c_h2:	defb 0
c_blk:	defw 0
c_ln:	defw 0
c_c1:	defw 0
c_c2:	defw 0
c_mdif:	defm " differ: byte ",0
c_mln:	defm ", line ",0
c_meof:	defm "cmp: EOF on ",0
c_mop:	defm "cmp: cannot open ",0
c_mus:	defm "usage: cmp file1 file2",13,10,"$"
b1	equ 3C00h
b2	equ 3D00h

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
