; FIND.COM - サブディレクトリをたどってファイルを探す。 find [path] [-name pattern] [-type d|f]   MIT License
;   path 省略=カレント。pattern は DIR と同じワイルドカード(既定 *.*)。-type d:ディレクトリだけ f:ファイルだけ。
;   各行は path からの相対名(ディレクトリは \ つき)。深さは path から8階層、1つのディレクトリにつきサブディレクトリ40個まで。
	org 0100h
	ld sp,0A000h
	call tailinit
	xor a
	ld (f_ty),a
	ld (plen),a
	ld (dep),a
	ld (pbuf),a
	ld hl,f_dall
	ld de,patb
	ld bc,4
	ldir
	ld hl,0081h
f_ar:	call sk
	or a
	jp z,f_go
	cp '-'
	jr z,f_op
	ld d,h
	ld e,l
	call tokend
	push hl
	ex de,hl
	ld de,pbuf
	ld b,70
f_cp:	ld a,(hl)
	or a
	jr z,f_cd
	ld (de),a
	inc hl
	inc de
	djnz f_cp
f_cd:	ld hl,pbuf		; 先頭の ".\" は取り除く(BDOS の "." 成分は親を指す癖があるので、省略と同じカレントにする)
	ld a,(hl)
	cp '.'
	jr nz,f_cdx
	inc hl
	ld a,(hl)
	cp 5Ch
	jr z,f_ds
	cp '/'
	jr nz,f_cdx
f_ds:	ld hl,pbuf+2
	push de
	ex de,hl
	or a
	sbc hl,de
	ld b,h
	ld c,l
	ld a,b
	or c
	jr z,f_dz
	ld hl,pbuf+2
	ld de,pbuf
	ldir
f_dz:	pop de
	dec de
	dec de
	xor a
	ld (de),a
	jr f_cd
f_cdx:	ld hl,pbuf
	or a
	sbc hl,de
	jr z,f_pe
	ld a,l
	cp 0FFh
	jr nz,f_cd2
	ld a,(pbuf)
	cp '.'
	jr nz,f_cd2
	ld de,pbuf		; 起点が '.' だけならカレント(省略と同じ)
	jr f_pe
f_cd2:	dec de
	ld a,(de)
	inc de
	cp 5Ch
	jr z,f_pe
	cp ':'
	jr z,f_pe
	cp '/'
	jr z,f_pe
	ld a,5Ch
	ld (de),a
	inc de
f_pe:	xor a
	ld (de),a
	ld a,e
	ld (plen),a
	pop hl
	jp f_ar
f_op:	inc hl
	ld a,(hl)
	or 20h
	cp 'n'
	jr z,f_nm
	cp 't'
	jp nz,f_us
	call tokend
	call sk
	or 20h
	ld b,1
	cp 'd'
	jr z,f_t1
	inc b
	cp 'f'
	jp nz,f_us
f_t1:	ld a,b
	ld (f_ty),a
	call tokend
	jp f_ar
f_nm:	call tokend
	call sk
	or a
	jp z,f_us
	ld d,h
	ld e,l
	call tokend
	push hl
	ex de,hl
	ld de,patb
	ld b,30
f_n1:	ld a,(hl)
	ld (de),a
	or a
	jr z,f_n2
	inc hl
	inc de
	djnz f_n1
	xor a
	ld (de),a
f_n2:	pop hl
	jp f_ar
f_go:	ld de,dtabuf
	ld c,1Ah
	call 5
	call f_walk
	call flush
	jp 0
f_us:	ld de,f_mus
	ld c,9
	call 5
	jp 0
f_walk:	ld hl,patb
	call f_mk
	ld de,fcb
	ld c,11h
f_s1:	call 5
	or a
	jr nz,f_s1d
	call f_ent
	ld de,fcb
	ld c,12h
	jr f_s1
f_s1d:	call f_lvp
	ld (hl),0
	ld hl,f_dall
	call f_mk
	ld de,fcb
	ld c,11h
f_s2:	call 5
	or a
	jr nz,f_s2d
	call f_col
	ld de,fcb
	ld c,12h
	jr f_s2
f_s2d:	ld a,(dep)
	cp 8
	ret nc
	call f_lvp
	ld a,(hl)
	or a
	ret z
	ld b,a
	ld c,0
f_r1:	push bc
	call f_lvp
	inc hl
	ld de,21
	ld a,c
	or a
	jr z,f_r2
f_r3:	add hl,de
	dec a
	jr nz,f_r3
f_r2:	ld a,(plen)
	push af
	call f_app
	jr c,f_r4
	ld a,(dep)
	inc a
	ld (dep),a
	call f_walk
	ld a,(dep)
	dec a
	ld (dep),a
f_r4:	pop af
	ld (plen),a
	ld l,a
	ld h,pbuf>>8
	ld (hl),0
	pop bc
	inc c
	ld a,c
	cp b
	jr c,f_r1
	ret
; 現在の深さの収集領域 -> HL
f_lvp:	ld a,(dep)
	add a,a
	add a,50h
	ld h,a
	ld l,0
	ret
; HL=11バイト名 -> pbuf の後ろへ "NAME.EXT\" を足す。CF=1:長すぎ
f_app:	ld a,(plen)
	cp 70
	ccf
	ret c
	ld e,a
	ld d,pbuf>>8
	push hl
	ld b,8
f_a1:	ld a,(hl)
	cp ' '
	jr z,f_a3
	ld (de),a
	inc de
	inc hl
	djnz f_a1
f_a3:	ld a,b
	or a
	call z,f_a7
	pop hl
	push de
	ld de,8
	add hl,de
	pop de
	ld a,(hl)
	cp ' '
	jr z,f_a5
	ld a,'.'
	ld (de),a
	inc de
	ld b,3
f_a4:	ld a,(hl)
	cp ' '
	jr z,f_a5
	ld (de),a
	inc de
	inc hl
	djnz f_a4
f_a5:	ld a,5Ch
	ld (de),a
	inc de
	xor a
	ld (de),a
	ld a,e
	ld (plen),a
	or a
	ret
; 名前が8文字そろっているとき、記録(スタックの上から2つ目=記録の先頭)の +11 から name2 を DE へ足す
f_a7:	ld hl,2
	add hl,sp
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld hl,11
	add hl,bc
	ld b,10
f_a8:	ld a,(hl)
	or a
	ret z
	ld (de),a
	inc de
	inc hl
	djnz f_a8
	ret
; HL=接尾の文字列: sbuf = pbuf + HL を FCB に解析して検索の準備
f_mk:	push hl
	ld hl,pbuf
	ld de,sbuf
f_m1:	ld a,(hl)
	ld (de),a
	or a
	jr z,f_m2
	inc hl
	inc de
	jr f_m1
f_m2:	pop hl
f_m3:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,f_m3
	ld hl,fcb
	ld de,fcb+1
	ld (hl),0
	ld bc,47
	ldir
	ld hl,fcb
	ld de,sbuf
	ld c,29h
	call 5
	ld a,0F1h
	ld (fcb+13),a
	ld hl,sbuf
f_m4:	ld a,(hl)
	or a
	jr z,f_m6
	inc hl
	cp '*'
	jr nz,f_m4
	ld a,(fcb+9)
	cp ' '
	jr nz,f_m6
	ld hl,fcb+9
	ld (hl),'?'
	inc hl
	ld (hl),'?'
	inc hl
	ld (hl),'?'
f_m6:	ld a,(fcb+1)
	cp ' '
	ret nz
	ld hl,fcb+1
	ld de,fcb+2
	ld (hl),'?'
	ld bc,10
	ldir
	ret
; 現在のサブディレクトリ(検索結果 dtabuf)を収集領域へ
f_col:	ld a,(dtabuf+12)
	and 10h
	ret z
	ld a,(dtabuf+1)
	cp '.'
	ret z
	call f_lvp
	ld a,(hl)
	cp 20
	ret nc
	ld c,a
	inc a
	ld (hl),a
	inc hl
	ld de,21
	ld a,c
	or a
	jr z,f_c2
f_c1:	add hl,de
	dec a
	jr nz,f_c1
f_c2:	ex de,hl
	ld hl,dtabuf+1
	ld bc,11
	ldir
	ex de,hl
	call ln_ok
	ld b,10
	jr z,f_c5
	ld de,dtabuf+13
f_c6:	ld a,(de)
	ld (hl),a
	inc de
	inc hl
	djnz f_c6
	ret
f_c5:	xor a
f_c7:	ld (hl),a
	inc hl
	djnz f_c7
	ret
; 検索結果が条件に合えば出力
f_ent:	ld a,(dtabuf+12)
	and 08h
	ret nz
	ld a,(dtabuf+1)
	cp '.'
	ret z
	ld a,(f_ty)
	or a
	jr z,f_e1
	ld b,a
	ld a,(dtabuf+12)
	and 10h
	jr z,f_e0
	ld a,b
	cp 2
	ret z
	jr f_e1
f_e0:	ld a,b
	cp 1
	ret z
f_e1:	ld hl,pbuf
	call wrs
	ld hl,dtabuf+1
	push hl
	ld b,8
f_f1:	ld a,(hl)
	cp ' '
	jr z,f_f3
	call wrb
	inc hl
	djnz f_f1
f_f3:	ld a,b
	or a
	call z,f_w7
	pop hl
	ld de,8
	add hl,de
	ld a,(hl)
	cp ' '
	jr z,f_f5
	ld a,'.'
	call wrb
	ld b,3
f_f4:	ld a,(hl)
	cp ' '
	jr z,f_f5
	call wrb
	inc hl
	djnz f_f4
f_f5:	ld a,(dtabuf+12)
	and 10h
	jr z,f_e2
	ld a,5Ch
	call wrb
f_e2:	jp wcrlf
; 名前が8文字そろっているとき、検索結果の name2 を出力へ足す
f_w7:	call ln_ok
	ret z
	push hl
	push bc
	ld hl,dtabuf+13
	ld b,10
f_w8:	ld a,(hl)
	or a
	jr z,f_w9
	call wrb
	inc hl
	djnz f_w8
f_w9:	pop bc
	pop hl
	ret
f_ty:	defb 0
plen:	defb 0
dep:	defb 0
f_dall:	defm "*.*",0
f_mus:	defm "usage: find [path] [-name pattern] [-type d|f]",13,10,"$"
fcb	equ 4400h
dtabuf	equ 4440h
patb	equ 4480h
pbuf	equ 4500h
sbuf	equ 4560h

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
	include "lnd.inc"
