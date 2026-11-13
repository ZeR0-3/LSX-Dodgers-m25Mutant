; TR.COM - 文字の置き換え・削除(標準入力 -> 標準出力)。 tr [-d] SET1 [SET2]   MIT License
;   SET は文字の並びと a-z 形式の範囲(空白は書けない)。SET1 の i 番目を SET2 の i 番目へ(SET2 が短ければ最後の文字)。 -d : SET1 の文字を消す
	org 0100h
	ld sp,0A000h
	call tailinit
	xor a
	ld (t_d),a
	call sk
	cp '-'
	jr nz,t_a
	inc hl
	ld a,(hl)
	or 20h
	cp 'd'
	jp nz,t_us
	ld a,1
	ld (t_d),a
	inc hl
	call sk
t_a:	or a
	jp z,t_us
	ld d,h
	ld e,l
	call tokend
	push hl
	ex de,hl
	ld de,l1buf
	ld a,46h
	ld (t_lim),a
	call t_exp
	ld (t_n1),bc
	pop hl
	call sk
	ld c,a
	ld a,(t_d)
	or a
	jr nz,t_init
	ld a,c
	or a
	jp z,t_us
	ld d,h
	ld e,l
	call tokend
	ex de,hl
	ld de,l2buf
	ld a,4Ah
	ld (t_lim),a
	call t_exp
	ld (t_n2),bc
	ld a,b
	or c
	jp z,t_us
t_init:	ld hl,tbl
	ld b,0
	xor a
t_i1:	ld (hl),a
	inc hl
	inc a
	djnz t_i1
	ld hl,del
	ld (hl),0
	ld de,del+1
	ld bc,255
	ldir
	ld bc,(t_n1)
	ld a,b
	or c
	jp z,t_us
	ld a,(t_d)
	or a
	jr nz,t_dl
	ld hl,(t_n1)
	ld de,(t_n2)
	or a
	sbc hl,de
	jr c,t_np
	jr z,t_np
	ld b,h
	ld c,l
	ld hl,l2buf
	add hl,de
	dec hl
	ld d,(hl)
	inc hl
t_pad:	ld (hl),d
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,t_pad
t_np:	ld hl,l1buf
	ld de,l2buf
	ld bc,(t_n1)
t_m:	ld a,(hl)
	inc hl
	push hl
	ld l,a
	ld h,tbl>>8
	ld a,(de)
	ld (hl),a
	pop hl
	inc de
	dec bc
	ld a,b
	or c
	jr nz,t_m
	jr t_run
t_dl:	ld hl,l1buf
t_dl1:	ld a,(hl)
	inc hl
	push hl
	ld l,a
	ld h,del>>8
	ld (hl),1
	pop hl
	dec bc
	ld a,b
	or c
	jr nz,t_dl1
t_run:	call rdb
	jr c,t_end
	ld l,a
	ld h,del>>8
	ld a,(hl)
	or a
	jr nz,t_run
	ld h,tbl>>8
	ld a,(hl)
	call wrb
	jr t_run
t_end:	call flush
	jp 0
t_us:	ld de,t_mus
	ld c,9
	call 5
	jp 0
; HL=文字列 DE=出力先 -> BC=個数(範囲 a-z を展開)
t_exp:	push de
t_e1:	ld a,(hl)
	or a
	jr z,t_ed
	ld c,a
	inc hl
	ld a,(hl)
	cp '-'
	jr nz,t_es
	inc hl
	ld a,(hl)
	or a
	jr z,t_eh
	cp c
	jp c,t_us
	inc hl
	ld b,a
t_er:	ld a,c
	call t_em
	ld a,c
	cp b
	jr z,t_e1
	inc c
	jr t_er
t_eh:	ld a,c
	call t_em
	ld a,'-'
	call t_em
	jr t_ed
t_es:	ld a,c
	call t_em
	jr t_e1
t_ed:	pop hl
	ex de,hl
	or a
	sbc hl,de
	ld b,h
	ld c,l
	ret
t_em:	push af
	ld a,(t_lim)
	cp d
	jr z,t_em1
	jr c,t_em1
	pop af
	ld (de),a
	inc de
	ret
t_em1:	pop af
	ret
t_d:	defb 0
t_lim:	defb 0
t_n1:	defw 0
t_n2:	defw 0
t_mus:	defm "usage: tr [-d] set1 [set2]   (ranges like a-z)",13,10,"$"
tbl	equ 4000h
del	equ 4100h
l1buf	equ 4200h
l2buf	equ 4600h

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
