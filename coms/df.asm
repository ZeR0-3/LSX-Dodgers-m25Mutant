; DF.COM - ドライブの容量。 df [d: ...]   MIT License
;   引数なし=カレントドライブ。 d: を並べればそれぞれ。 全体・使用中・空き (KB)。 df * で A:-H: のうち使えるもの全部。
	org 0100h
	ld sp,0A000h
	call tailinit
	ld de,hdr
	ld c,9
	call 5
	call sk
	or a
	jr nz,g_ar
	ld c,19h		; 現在のドライブ
	call 5
	inc a
	call g_one
	jp g_end
g_ar:	call sk
	or a
	jp z,g_end
	cp '*'
	jr z,g_all
	or 20h
	sub 'a'-1
	jp c,g_us
	cp 9
	jp nc,g_us
	call g_one
	inc hl
	ld a,(hl)
	cp ':'
	jr nz,g_ar
	inc hl
	jr g_ar
g_all:	inc hl
	push hl
	ld a,1
g_a1:	push af
	call g_one
	pop af
	inc a
	cp 9
	jr c,g_a1
	pop hl
	jr g_ar
g_end:	call flush
	jp 0
g_us:	ld de,g_mus
	ld c,9
	call 5
	jp 0
; A=ドライブ(1=A) の1行 (使えなければ何も出さない)。HL を保つ
g_one:	push hl
	ld (g_dr),a
	ld e,a
	ld c,1Bh
	call 5
	cp 0FFh
	jp z,g_ret
	or a
	jp z,g_ret
	ld (g_sc),a
	ld a,b
	ld (g_ssz),a		; 論理セクタの大きさ/256
	ld (g_tot),de
	ld (g_fre),hl
	ld a,(g_sc)
	ld b,a
	ld a,(g_ssz)
	ld c,a			; C=セクタ/256
	xor a
	ld d,a
g_m1:	add a,c			; A = クラスタあたりの 256B 単位数
	djnz g_m1
	ld (g_u),a
	ld a,(g_dr)
	add a,'A'-1
	call wrb
	ld a,':'
	call wrb
	ld hl,(g_tot)
	call g_kb		; DEHL = KB
	push de
	push hl
	ld b,9
	call pnum
	ld hl,(g_fre)
	call g_kb		; DEHL = 空きKB
	ld (g_f1),hl
	ld (g_f2),de
	pop hl
	pop de			; DEHL = 全体
	ld bc,(g_f1)
	or a
	sbc hl,bc
	ex de,hl
	ld bc,(g_f2)
	sbc hl,bc
	ex de,hl		; DEHL = 使用中
	ld b,9
	call pnum
	ld hl,(g_f1)
	ld de,(g_f2)
	ld b,9
	call pnum
	call wcrlf
g_ret:	pop hl
	ret
; HL=クラスタ数 -> DEHL = HL * (g_u) / 4
g_kb:	ld de,0
	ld b,h
	ld c,l
	ld hl,0
	ld a,(g_u)
	or a
	jr z,gk2
gk1:	add hl,bc
	jr nc,gk0
	inc de
gk0:	dec a
	jr nz,gk1
gk2:	srl d
	rr e
	rr h
	rr l
	srl d
	rr e
	rr h
	rr l
	ret
g_dr:	defb 0
g_sc:	defb 0
g_ssz:	defb 0
g_u:	defb 0
g_tot:	defw 0
g_fre:	defw 0
g_f1:	defw 0
g_f2:	defw 0
hdr:	defm "KB       Total     Used     Free",13,10,"$"
g_mus:	defm "usage: df [d: ... | *]",13,10,"$"

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
