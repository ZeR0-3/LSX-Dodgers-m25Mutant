; DU.COM - ディレクトリごとのファイルサイズの合計。 du [-s] [-k] [path]   MIT License
;   path 省略=カレント。各ディレクトリ(サブも含む)の合計を、下のディレクトリから順に出す。 -s : 最後の合計だけ  -k : KB単位(切り上げ)。
;   単位は既定でバイト。ファイルの大きさの合計であり、クラスタ単位の使用量ではない。深さ8階層まで、1つのディレクトリにサブディレクトリ40個まで。
	org 0100h
	ld sp,0A000h
	call tailinit
	xor a
	ld (plen),a
	ld (dep),a
	ld (pbuf),a
	ld (d_s),a
	ld (d_k),a
	ld hl,f_dall
	ld de,patb
	ld bc,4
	ldir
	ld hl,0081h
d_ar:	call sk
	or a
	jp z,d_go
	cp '-'
	jr nz,d_pa
d_op:	inc hl
	ld a,(hl)
	or 20h
	cp 's'
	jr z,d_o1
	cp 'k'
	jp nz,d_us
	ld (d_k),a
	jr d_o2
d_o1:	ld (d_s),a
d_o2:	inc hl
	ld a,(hl)
	cp ' '
	jr z,d_ar
	or a
	jp z,d_go
	jr d_op
d_pa:
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
f_cd:	ld hl,pbuf
	or a
	sbc hl,de
	jr z,f_pe
	dec de
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
	jr d_ar
d_go:	ld de,dtabuf
	ld c,1Ah
	call 5
	ld hl,duacc
	ld (hl),0
	ld de,duacc+1
	ld bc,40
	ldir
	call f_walk
	xor a
	ld (dep),a
	call d_pr
	call flush
	jp 0
d_us:	ld de,d_mus
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
	call f_pre
	ld a,(dep)
	inc a
	ld (dep),a
	call f_walk
	ld a,(dep)
	dec a
	ld (dep),a
	call f_post
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

; 深さ dep の合計 -> HL
d_acc:	ld a,(dep)
	add a,a
	add a,a
	ld e,a
	ld d,0
	ld hl,duacc
	add hl,de
	ret
; サブディレクトリに入る前: 次の深さの合計を0に
f_pre:	ld a,(dep)
	inc a
	ld (dep),a
	call d_acc
	ld (hl),0
	inc hl
	ld (hl),0
	inc hl
	ld (hl),0
	inc hl
	ld (hl),0
	ld a,(dep)
	dec a
	ld (dep),a
	ret
; サブディレクトリから戻った後 (dep=親の深さ): 子の合計を出して親に足す
f_post:	ld a,(d_s)
	or a
	jr nz,fp1
	ld a,(dep)
	inc a
	ld (dep),a
	call d_pr
	ld a,(dep)
	dec a
	ld (dep),a
fp1:	ld a,(dep)
	inc a
	ld (dep),a
	call d_acc
	push hl
	ld a,(dep)
	dec a
	ld (dep),a
	call d_acc
	ex de,hl
	pop hl
	ld b,4
	or a
fp2:	ld a,(de)
	adc a,(hl)
	ld (de),a
	inc hl
	inc de
	djnz fp2
	ret
; 深さ dep の合計と pbuf を1行で出す
d_pr:	call d_acc
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	ex de,hl		; HL=下位16 BC=上位16
	ld d,b
	ld e,c			; DEHL
	ld a,(d_k)
	or a
	jr z,dp2
	ld bc,1023
	add hl,bc
	jr nc,dp1
	inc de
dp1:	ld b,10
dp3:	srl d
	rr e
	rr h
	rr l
	djnz dp3
dp2:	ld b,9
	call pnum
	ld a,' '
	call wrb
	ld a,(pbuf)
	or a
	jr nz,dp4
	ld a,'.'
	call wrb
	jp wcrlf
dp4:	ld hl,pbuf
	call wrs
	jp wcrlf
; 検索結果のファイルの大きさを深さ dep の合計に足す
f_ent:	ld a,(dtabuf+12)
	and 18h
	ret nz
	ld a,(dtabuf+1)
	cp '.'
	ret z
	call d_acc
	ld de,dtabuf+29
	ld b,4
	or a
fe1:	ld a,(de)
	adc a,(hl)
	ld (hl),a
	inc hl
	inc de
	djnz fe1
	ret
d_s:	defb 0
d_k:	defb 0
plen:	defb 0
dep:	defb 0
f_dall:	defm "*.*",0
d_mus:	defm "usage: du [-s] [-k] [path]",13,10,"$"
fcb	equ 4400h
dtabuf	equ 4440h
patb	equ 4480h
pbuf	equ 4500h
sbuf	equ 4560h
duacc	equ 4600h

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
