; TAIL.COM - 末尾の行を出す。 tail [-n N | -N] [file]   (既定10行。入力の最後の約20KBだけ見る)   MIT License
	org 0100h
	ld sp,0A000h
	call tailinit
	ld de,10
	ld (nl),de
tp1:	call sk
	cp '-'
	jr nz,tf
	inc hl
	ld a,(hl)
	cp ' '
	jr z,tdash
	or a
	jr z,tdash
	or 20h
	cp 'n'
	jr nz,tnum
	inc hl
	call sk
tnum:	call atoi
	ld (nl),de
	jr tp1
tdash:	dec hl
tf:	or a
	jr z,tstdin
	ld d,h
	ld e,l
	call tokend
	call openin
	jr nc,tgo
	ld de,mopen
	ld c,9
	call 5
	jp 0
tstdin:	ld de,dashs
	call openin
tgo:	ld a,b
	ld (inh),a
	ld hl,tbuf
	ld (tpos),hl
tl1:	call rdb
	jr c,tend
	ld hl,(tpos)
	ld de,tbuf+5000h
	or a
	push af
	ld a,h
	cp d
	jr c,tl2
	ld a,l			; 満杯: 後ろ半分を前へ詰める
	cp e
	jr c,tl2
	push bc
	ld hl,tbuf+2800h
	ld de,tbuf
	ld bc,2800h
	ldir
	ld hl,tbuf+2800h
	ld (tpos),hl
	pop bc
tl2:	pop af
	ld hl,(tpos)
	ld (hl),a
	inc hl
	ld (tpos),hl
	jr tl1
tend:	call closein
	ld hl,(nl)
	ld a,h
	or l
	jr z,tout0
	ld hl,(tpos)
	ld de,tbuf
	ld a,h			; 最後が改行なら数えない
	cp d
	jr nz,ta1
	ld a,l
	cp e
	jr z,tout0
ta1:	dec hl
	ld a,(hl)
	cp 0Ah
	jr z,ta2
	inc hl
ta2:	ld bc,(nl)		; BC=残りの行数
ta3:	ld de,tbuf
	ld a,h
	cp d
	jr nz,ta4
	ld a,l
	cp e
	jr z,tstart
ta4:	dec hl
	ld a,(hl)
	cp 0Ah
	jr nz,ta3
	dec bc
	ld a,b
	or c
	jr nz,ta3
	inc hl
tstart:	ex de,hl		; DE=開始
	ld hl,(tpos)
to1:	ld a,h
	cp d
	jr nz,to2
	ld a,l
	cp e
	jr z,tout0
to2:	ld a,(de)
	call wrb
	inc de
	jr to1
tout0:	call flush
	jp 0
nl:	defw 10
tpos:	defw 0
dashs:	defm "-"
	defb 0
mopen:	defm "tail: cannot open file",13,10,"$"
tbuf	equ 4000h

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
