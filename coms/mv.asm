; MV.COM - ファイルの名前変更・移動。 mv from to     MIT License
;   from にも to にも \ : / が無ければ同じディレクトリ内の名前変更(内蔵 REN と同じで * ? は不可。ディレクトリ名も変えられる)。どちらかにあれば to へコピーして from を消す(* ? 不可)。
;   to が \ か : で終わるときはその中へ(名前は from のまま)。to が既にあるときは何もしない。
	org 0100h
	ld sp,0A000h
	call tailinit
	call sk
	or a
	jp z,m_us
	ld d,h
	ld e,l
	call tokend
	ld (m_s),de
	call sk
	or a
	jp z,m_us
	ld d,h
	ld e,l
	call tokend
	ld (m_d),de
	ld de,dtabuf
	ld c,1Ah
	call 5
	ld hl,(m_s)
	call m_pth
	jr c,m_cp
	ld hl,(m_d)
	call m_pth
	jr c,m_cp
m_rn:	call m_clr
	ld hl,fcb
	ld de,(m_s)
	ld c,29h
	call 5
	ld hl,fcb+16
	ld de,(m_d)
	ld c,29h
	call 5
	ld a,10h
	ld (fcb+13),a
	ld de,fcb
	ld c,17h
	call 5
	or a
	ld de,m_mrf
	jp nz,m_msg
m_ok:	ld b,0
	jr m_fin
m_msg:	ld c,9
	call 5
	ld b,1
m_fin:	ld c,62h
	call 5
	jp 0
; HL=文字列に \ / : があれば CF=1
m_pth:	ld a,(hl)
	or a
	ret z
	cp 5Ch
	jr z,m_p1
	cp '/'
	jr z,m_p1
	cp ':'
	jr z,m_p1
	inc hl
	jr m_pth
m_p1:	scf
	ret
m_clr:	ld hl,fcb
	ld de,fcb+1
	ld (hl),0
	ld bc,63
	ldir
	ret
m_cp:	ld hl,(m_d)
	ld de,tbuf
m_c1:	ld a,(hl)
	ld (de),a
	or a
	jr z,m_c2
	inc hl
	inc de
	jr m_c1
m_c2:	dec de
	ld a,(de)
	inc de
	cp 5Ch
	jr z,m_ap
	cp '/'
	jr z,m_ap
	cp ':'
	jr nz,m_c4
m_ap:	ld hl,(m_s)
	ld b,h
	ld c,l
m_b1:	ld a,(hl)
	or a
	jr z,m_b2
	inc hl
	cp 5Ch
	jr z,m_bs
	cp '/'
	jr z,m_bs
	cp ':'
	jr nz,m_b1
m_bs:	ld b,h
	ld c,l
	jr m_b1
m_b2:	ld h,b
	ld l,c
m_b3:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,m_b3
m_c4:	ld de,tbuf
	ld a,1
	ld c,43h
	call 5
	or a
	jr nz,m_c5
	ld c,45h
	call 5
	ld de,m_mex
	jp m_msg
m_c5:	ld de,(m_s)
	ld a,1
	ld c,43h
	call 5
	or a
	ld de,m_mos
	jp nz,m_msg
	ld a,b
	ld (m_h1),a
	ld de,tbuf
	xor a
	ld b,a
	ld c,44h
	call 5
	or a
	ld de,m_mcf
	jp nz,m_msg
	ld a,b
	ld (m_h2),a
m_lp:	ld a,(m_h1)
	ld b,a
	ld de,buf
	ld hl,1024
	ld c,48h
	call 5
	or a
	jr z,m_rk
	cp 0C7h
	jr z,m_dn
	ld de,m_mre
	jp m_msg
m_rk:	ld a,h
	or l
	jr z,m_dn
	ld a,(m_h2)
	ld b,a
	ld de,buf
	ld c,49h
	call 5
	or a
	jr z,m_lp
	ld de,m_mwe
	jp m_msg
m_dn:	ld a,(m_h1)
	ld b,a
	ld c,45h
	call 5
	ld a,(m_h2)
	ld b,a
	ld c,45h
	call 5
	call m_clr
	ld hl,fcb
	ld de,(m_s)
	ld c,29h
	call 5
	ld de,fcb
	ld c,13h
	call 5
	or a
	jp z,m_ok
	ld de,m_mdf
	jp m_msg
m_us:	ld de,m_mus
	ld c,9
	call 5
	jp 0
m_s:	defw 0
m_d:	defw 0
m_h1:	defb 0
m_h2:	defb 0
m_mus:	defm "usage: mv from to",13,10,"$"
m_mrf:	defm "mv: cannot rename",13,10,"$"
m_mex:	defm "mv: target exists",13,10,"$"
m_mos:	defm "mv: cannot open source",13,10,"$"
m_mcf:	defm "mv: cannot create target",13,10,"$"
m_mre:	defm "mv: read error (source kept)",13,10,"$"
m_mwe:	defm "mv: write error (source kept)",13,10,"$"
m_mdf:	defm "mv: copied, but cannot delete source",13,10,"$"
fcb	equ 4400h
dtabuf	equ 4440h
tbuf	equ 4470h
buf	equ 4500h

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
