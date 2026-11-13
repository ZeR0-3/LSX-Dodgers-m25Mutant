; WHICH.COM - コマンドがどこにあるか。 which name ...   MIT License
;   内蔵コマンドか、カレントディレクトリか、PATH のどのディレクトリの .COM / .BAT か(コマンドの探し順と同じ)。終了コード $? : 全部見つかった 0 / 無いものがあった 1
	org 0100h
	ld sp,0A000h
	call tailinit
	ld de,dtabuf
	ld c,1Ah
	call 5
	xor a
	ld (w_bad),a
	ld (w_any),a
	ld hl,w_pn
	ld de,penv
	ld c,6Bh
	call 5
w_nx:	ld hl,0081h
	ld a,(w_any)
	or a
	jr z,w_f
	ld hl,(w_nxt)
w_f:	call sk
	or a
	jp z,w_end
	ld a,1
	ld (w_any),a
	ld d,h
	ld e,l
	call tokend
	ld (w_nxt),hl
	ex de,hl
	ld de,nm
	ld b,12
	xor a
	ld (w_dot),a
w_c1:	ld a,(hl)
	or a
	jr z,w_c3
	cp 'a'
	jr c,w_c2
	cp '{'
	jr nc,w_c2
	sub 20h
w_c2:	cp '.'
	jr nz,w_c4
	ld (w_dot),a
w_c4:	ld (de),a
	inc hl
	inc de
	djnz w_c1
w_c3:	xor a
	ld (de),a
	ld a,(nm)
	or a
	jp z,w_nx
	ld a,(w_dot)
	or a
	jr nz,w_cwd
	ld hl,nm
	ld de,w_pad
	ld b,4
w_p1:	ld a,(hl)
	or a
	jr z,w_p2
	ld (de),a
	inc hl
	inc de
	djnz w_p1
	ld a,(hl)
	or a
	jr nz,w_cwd
	jr w_p3
w_p2:	ld a,' '
w_p4:	ld (de),a
	inc de
	djnz w_p4
w_p3:	ld hl,w_tbl
	ld b,14
w_t1:	push bc
	ld de,w_pad
	ld b,4
w_t2:	ld a,(de)
	cp (hl)
	jr nz,w_t3
	inc de
	inc hl
	djnz w_t2
	pop bc
	ld hl,nm
	call w_pr
	ld hl,w_mbi
	call wrs
	call wcrlf
	jp w_nx
w_t3:	ld a,b
	ld c,a
	ld b,0
	add hl,bc
	pop bc
	djnz w_t1
w_cwd:	xor a
	ld (pfx),a
	call w_srch
	jr c,w_pth
	ld hl,w_mcw
	call wrs
	call wcrlf
	jp w_nx
w_pth:	ld hl,penv
w_e1:	ld a,(hl)
	cp ';'
	jr nz,w_e2
	inc hl
	jr w_e1
w_e2:	or a
	jr z,w_nf
	ld de,pfx
	ld b,70
w_e3:	ld a,(hl)
	or a
	jr z,w_e4
	cp ';'
	jr z,w_e4
	ld (de),a
	inc hl
	inc de
	djnz w_e3
w_e4:	push hl
	ld hl,pfx
	or a
	sbc hl,de
	jr z,w_e6
	dec de
	ld a,(de)
	inc de
	cp 5Ch
	jr z,w_e6
	cp ':'
	jr z,w_e6
	ld a,5Ch
	ld (de),a
	inc de
w_e6:	xor a
	ld (de),a
	call w_srch
	pop hl
	jr c,w_e1
	call wcrlf
	jp w_nx
w_nf:	ld hl,w_mnf1
	call wrs
	ld hl,nm
	call wrs
	ld hl,w_mnf2
	call wrs
	call wcrlf
	ld a,1
	ld (w_bad),a
	jp w_nx
w_end:	call flush
	ld a,(w_bad)
	ld b,a
	ld c,62h
	call 5
	jp 0
; 出力: HL=0終端文字列を出して ": " を足す
w_pr:	call wrs
	ld a,':'
	call wrb
	ld a,' '
	jp wrb
; pfx + nm (拡張子なしなら .???) を検索。見つかれば (名前を出力して) CF=0 / 無ければ CF=1
w_srch:	ld hl,pfx
	ld de,sbuf
w_s1:	ld a,(hl)
	ld (de),a
	or a
	jr z,w_s2
	inc hl
	inc de
	jr w_s1
w_s2:	ld hl,nm
w_s3:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,w_s3
	ld a,(w_dot)
	or a
	jr nz,w_s5
	dec de
	ld hl,w_ext
	ld bc,5
	ldir
w_s5:	ld hl,fcb
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
	ld de,fcb
	ld c,11h
w_s6:	call 5
	or a
	jr nz,w_sn
	ld a,(dtabuf+12)
	and 18h
	jr nz,w_s7
	ld a,(w_dot)
	or a
	jr nz,w_s8
	ld a,(dtabuf+9)
	or 20h
	cp 'b'
	jr z,w_s8
	cp 'c'
	jr z,w_s8
w_s7:	ld de,fcb
	ld c,12h
	jr w_s6
w_s8:	ld hl,pfx
	call wrs
	ld hl,dtabuf+1
	push hl
	ld b,8
w_f1:	ld a,(hl)
	cp ' '
	jr z,w_f3
	call wrb
	inc hl
	djnz w_f1
w_f3:	ld a,b
	or a
	call z,w_w7
	pop hl
	ld de,8
	add hl,de
	ld a,(hl)
	cp ' '
	jr z,w_f5
	ld a,'.'
	call wrb
	ld b,3
w_f4:	ld a,(hl)
	cp ' '
	jr z,w_f5
	call wrb
	inc hl
	djnz w_f4
w_f5:	ld a,(pfx)
	or a
	jr nz,w_f6
	ld a,' '
	call wrb
w_f6:	or a
	ret
; 名前が8文字そろっているとき、検索結果の name2 を出力へ足す
w_w7:	call ln_ok
	ret z
	push hl
	push bc
	ld hl,dtabuf+13
	ld b,10
w_w8:	ld a,(hl)
	or a
	jr z,w_w9
	call wrb
	inc hl
	djnz w_w8
w_w9:	pop bc
	pop hl
	ret
w_sn:	scf
	ret
w_pn:	defm "PATH",0
w_ext:	defm ".???",0
w_tbl:	defm "D   DIR COPYCD  DEL PATHREN REM MON SET ENV GOTOIF  MODE"
w_mbi:	defm "built-in command",0
w_mcw:	defm "(current directory)",0
w_mnf1:	defm "which: ",0
w_mnf2:	defm " not found",0
w_bad:	defb 0
w_any:	defb 0
w_dot:	defb 0
w_nxt:	defw 0
w_pad:	defm "    "
nm	equ 4400h
pfx	equ 4410h
penv	equ 4460h
sbuf	equ 44B0h
fcb	equ 4520h
dtabuf	equ 4550h

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
