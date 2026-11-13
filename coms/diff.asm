; DIFF.COM - 2つのテキストファイルを1行ずつ突き合わせ、違う行を出す。 diff file1 file2   MIT License
;   出力: "< 行番号: file1の行" / "> 行番号: file2の行"。行の挿入・削除を探し直さない簡易版(ずれると以降すべて違う行になる)。同じなら何も出さない。
;   終了コード $? : 同じ 0 / 違う 1 / 開けない 2。1行は250文字まで。
	org 0100h
	ld sp,0A000h
	call tailinit
	call sk
	or a
	jp z,d_us
	ld d,h
	ld e,l
	call tokend
	ld (d_n1),de
	call sk
	or a
	jp z,d_us
	ld d,h
	ld e,l
	call tokend
	ld (d_n2),de
	ld de,(d_n1)
	ld a,1
	ld c,43h
	call 5
	or a
	jp nz,d_oe1
	ld a,b
	ld (s1),a
	ld de,(d_n2)
	ld a,1
	ld c,43h
	call 5
	or a
	jp nz,d_oe2
	ld a,b
	ld (s2),a
	ld hl,s1buf
	ld (s1+5),hl
	ld hl,s2buf
	ld (s2+5),hl
	ld hl,0
	ld (d_ln),hl
d_lp:	ld ix,s1
	ld de,l1
	call d_rl
	sbc a,a
	ld (d_e1),a
	ld ix,s2
	ld de,l2
	call d_rl
	sbc a,a
	ld b,a
	ld (d_e2),a
	ld a,(d_e1)
	and b
	jr nz,d_end
	ld hl,(d_ln)
	inc hl
	ld (d_ln),hl
	ld a,(d_e1)
	or b
	jr nz,d_pr
	ld hl,l1
	ld de,l2
d_cm:	ld a,(de)
	cp (hl)
	jr nz,d_pr
	or a
	jr z,d_lp
	inc hl
	inc de
	jr d_cm
d_pr:	ld a,1
	ld (d_any),a
	ld a,(d_e1)
	or a
	jr nz,d_p2
	ld a,'<'
	ld hl,l1
	call d_out
d_p2:	ld a,(d_e2)
	or a
	jr nz,d_lp
	ld a,'>'
	ld hl,l2
	call d_out
	jr d_lp
d_out:	push hl
	call wrb
	ld a,' '
	call wrb
	ld hl,(d_ln)
	ld de,0
	ld b,1
	call pnum
	ld a,':'
	call wrb
	ld a,' '
	call wrb
	pop hl
	call wrs
	jp wcrlf
d_end:	call flush
	ld a,(d_any)
	ld b,a
d_ex:	ld c,62h
	call 5
	jp 0
d_oe1:	ld de,(d_n1)
	jr d_oe
d_oe2:	ld de,(d_n2)
d_oe:	push de
	ld de,d_mop
	ld c,9
	call 5
	pop hl
d_oe3:	ld a,(hl)
	or a
	jr z,d_oe4
	ld e,a
	ld c,2
	push hl
	call 5
	pop hl
	inc hl
	jr d_oe3
d_oe4:	ld de,d_mcr
	ld c,9
	call 5
	ld b,2
	jr d_ex
d_us:	ld de,d_mus
	ld c,9
	call 5
	jp 0
; IX=入力構造体 DE=行バッファ。CR は捨て、LF で終わり、0終端。CF=1:データなしの EOF
d_rl:	ld c,0
d_r1:	call d_rc
	jr c,d_re
	cp 0Ah
	jr z,d_rend
	cp 0Dh
	jr z,d_r1
	ld b,a
	ld a,c
	cp 250
	jr nc,d_r1
	ld a,b
	ld (de),a
	inc de
	inc c
	jr d_r1
d_rend:	xor a
	ld (de),a
	ret
d_re:	ld a,c
	or a
	jr nz,d_rend
	ld (de),a
	scf
	ret
; IX=入力構造体 -> A=1バイト、CF=1:EOF
d_rc:	ld l,(ix+1)
	ld h,(ix+2)
	ld a,h
	or l
	jr nz,d_c2
	push bc
	push de
	ld b,(ix+0)
	ld e,(ix+5)
	ld d,(ix+6)
	ld hl,256
	ld c,48h
	call 5
	pop de
	pop bc
	or a
	jr nz,d_ceof
	ld a,h
	or l
	jr z,d_ceof
	ld a,(ix+5)
	ld (ix+3),a
	ld a,(ix+6)
	ld (ix+4),a
d_c2:	dec hl
	ld (ix+1),l
	ld (ix+2),h
	ld l,(ix+3)
	ld h,(ix+4)
	ld a,(hl)
	inc hl
	ld (ix+3),l
	ld (ix+4),h
	or a
	ret
d_ceof:	scf
	ret
; 入力構造体: +0 ハンドル +1 残り(2) +3 位置(2) +5 バッファ(2)
s1:	defs 7
s2:	defs 7
d_n1:	defw 0
d_n2:	defw 0
d_ln:	defw 0
d_e1:	defb 0
d_e2:	defb 0
d_any:	defb 0
d_mop:	defm "diff: cannot open $"
d_mcr:	defm 13,10,"$"
d_mus:	defm "usage: diff file1 file2",13,10,"$"
s1buf	equ 3C00h
s2buf	equ 3D00h
l1	equ 4000h
l2	equ 4100h

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
