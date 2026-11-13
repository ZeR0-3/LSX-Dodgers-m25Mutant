; SORT.COM - 行を並べ替える(文字コード順)。 sort [-r] [-u] [file]   -r:逆順 -u:同じ行を1つに   最大約1000行/20KB   MIT License
	org 0100h
	ld sp,0A000h
	call tailinit
	xor a
	ld (fr),a
	ld (fu),a
so1:	call sk
	cp '-'
	jr nz,sf
	inc hl
	ld a,(hl)
	cp ' '
	jr z,sdash
	or a
	jr z,sdash
so2:	ld a,(hl)
	or a
	jr z,so1
	cp ' '
	jr z,so1
	or 20h
	cp 'r'
	jr nz,so3
	ld a,1
	ld (fr),a
	inc hl
	jr so2
so3:	cp 'u'
	jp nz,sus
	ld a,1
	ld (fu),a
	inc hl
	jr so2
sdash:	dec hl
sf:	or a
	jr z,sstd
	ld d,h
	ld e,l
	call tokend
	call openin
	jr nc,sgo
	ld de,mopen
	ld c,9
	call 5
	jp 0
sstd:	ld de,dashs
	call openin
sgo:	ld a,b
	ld (inh),a
	ld hl,sbuf
	ld (spos),hl
	ld hl,0
	ld (nl),hl
sl1:	ld hl,(nl)		; 行数の上限
	ld de,1000
	or a
	sbc hl,de
	jr nc,sfull
	ld hl,(spos)		; 容量: 行は最大254+1
	ld de,sbuf+4F00h
	or a
	sbc hl,de
	jr nc,sfull
	ld de,(spos)
	call rdline
	jr c,sdone
	; 行末の位置 = DE?  rdline は呼び出し側のバッファに書く。長さを数える
	ld hl,(spos)
	push hl
sl2:	ld a,(hl)
	inc hl
	or a
	jr nz,sl2
	ld (spos),hl		; 次の行の先頭
	pop de			; DE=この行
	call insert
	jr sl1
sfull:	ld a,1
	ld (ovf),a
sdone:	call closein
	; 出力
	ld hl,(nl)
	ld a,h
	or l
	jr z,sout9
	ld bc,0			; BC=i
so4:	ld a,(fr)
	or a
	jr z,so5
	ld hl,(nl)		; 逆順: index = n-1-i
	dec hl
	or a
	sbc hl,bc
	jr so6
so5:	ld h,b
	ld l,c
so6:	add hl,hl
	ld de,parr
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)		; DE=行
	ld a,(fu)
	or a
	jr z,so8
	ld a,b
	or c
	jr z,so8
	ld hl,(last)		; 直前に出した行と同じなら出さない
	push de
so7:	ld a,(de)
	cp (hl)
	jr nz,so7d
	or a
	jr z,so7s
	inc de
	inc hl
	jr so7
so7s:	pop de
	jr so9
so7d:	pop de
so8:	ld (last),de
	ex de,hl
	push bc
	call wrs
	call wcrlf
	pop bc
so9:	inc bc
	ld hl,(nl)
	ld a,b
	cp h
	jr nz,so4
	ld a,c
	cp l
	jr nz,so4
sout9:	call flush
	ld a,(ovf)
	or a
	jp z,0
	ld de,mfull
	ld c,9
	call 5
	jp 0
sus:	ld de,musage
	ld c,9
	call 5
	jp 0
; DE=新しい行を、parr[0..nl) (昇順に並んだ行へのポインタ)へ挿入する。安定(同じ行は後ろへ)
insert:	ld (newp),de
	ld bc,0
	ld hl,(nl)
ins1:	ld a,b
	cp h
	jr nz,ins2
	ld a,c
	cp l
	jr z,ins9
ins2:	push bc
	push hl
	add hl,bc
	srl h
	rr l
	ld (mid),hl
	add hl,hl
	ld de,parr
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld hl,(newp)
ins3:	ld a,(de)
	cp (hl)
	jr nz,ins4
	or a
	jr z,ins4
	inc hl
	inc de
	jr ins3
ins4:	pop hl
	pop bc
	jr c,ins5
	ld hl,(mid)
	jr ins1
ins5:	ld bc,(mid)
	inc bc
	jr ins1
ins9:	ld hl,(nl)
	or a
	sbc hl,bc
	jr z,ins10
	push bc
	add hl,hl
	ld b,h
	ld c,l
	ld hl,(nl)
	add hl,hl
	ld de,parr
	add hl,de
	dec hl
	ld d,h
	ld e,l
	inc de
	inc de
	lddr
	pop bc
ins10:	ld h,b
	ld l,c
	add hl,hl
	ld de,parr
	add hl,de
	ld de,(newp)
	ld (hl),e
	inc hl
	ld (hl),d
	ld hl,(nl)
	inc hl
	ld (nl),hl
	ret

fr:	defb 0
fu:	defb 0
ovf:	defb 0
nl:	defw 0
spos:	defw 0
newp:	defw 0
mid:	defw 0
last:	defw 0
dashs:	defm "-"
	defb 0
mopen:	defm "sort: cannot open file",13,10,"$"
mfull:	defm "sort: input too large (partial)",13,10,"$"
musage:	defm "usage: sort [-r] [-u] [file]",13,10,"$"
sbuf	equ 4000h
parr	equ 9000h

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
