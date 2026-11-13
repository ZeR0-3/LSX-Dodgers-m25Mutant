#!/usr/bin/env python3
# coms/{wc,head,tail,tee,sort,uniq,hd,touch}.asm を共通部品つきで生成する
import os
OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','coms')
HDR='''	org 0100h
	ld sp,0A000h
'''
LIB=r'''
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
'''
def w(name,body,extra=''):
    open(os.path.join(OUT,name+'.asm'),'w',encoding='utf-8').write(body+LIB+extra)

# ---------------- wc ----------------
w('wc',r'''; WC.COM - 行数・語数・バイト数。 wc [-lwc] [file ...]  (file省略/-/con は標準入力)   MIT License
'''+HDR+r'''	call tailinit
	xor a
	ld (mask),a
	ld (nf),a
op1:	call sk
	or a
	jr z,opd
	cp '-'
	jr nz,opd
	inc hl
	ld a,(hl)
	cp ' '
	jr z,opd0		; 単独の - は標準入力名
	or a
	jr z,opd0
op2:	ld a,(hl)
	or a
	jr z,op1
	cp ' '
	jr z,op1
	or 20h
	ld b,1
	cp 'l'
	jr z,op3
	ld b,2
	cp 'w'
	jr z,op3
	ld b,4
	cp 'c'
	jr z,op3
	ld de,musage
	ld c,9
	call 5
	jp 0
op3:	ld a,(mask)
	or b
	ld (mask),a
	inc hl
	jr op2
opd0:	dec hl
opd:	ld a,(mask)
	or a
	jr nz,opm
	ld a,7
	ld (mask),a
opm:	ld (fp),hl
	push hl
	ld hl,tl
	ld de,tl+1
	ld (hl),0
	ld bc,11
	ldir
	pop hl
	ld a,(hl)
	or a
	jr nz,files
	; 標準入力
	xor a
	ld (inh),a
	ld hl,nostr
	ld (nmp),hl
	call count
	call report
	jp done
files:	ld hl,(fp)
	call sk
	or a
	jr z,fdone
	ld (nmp),hl
	call tokend
	ld (fp),hl
	ld de,(nmp)
	call openin
	jr nc,fo1
	ld de,mopen
	ld c,9
	call 5
	jr files
fo1:	ld a,b
	ld (inh),a
	call count
	call closein
	call report
	ld a,(nf)
	inc a
	ld (nf),a
	; 合計に足す
	ld hl,cl
	ld de,tl
	call add32
	jr files
fdone:	ld a,(nf)
	cp 2
	jr c,done
	ld hl,tl
	ld de,cl
	ld bc,12
	ldir
	ld hl,totstr
	ld (nmp),hl
	call report
done:	call flush
	jp 0
; cl,cw,cb(各4バイト)に tl,tw,tb を足し込む (HL=cl DE=tl の組を3つ)
add32:	ld b,3
a3:	push bc
	push hl
	push de
	ld b,4
	or a
a4:	ld a,(de)
	adc a,(hl)
	ld (de),a
	inc de
	inc hl
	djnz a4
	pop de
	pop hl
	ld bc,4
	add hl,bc
	ex de,hl
	add hl,bc
	ex de,hl
	pop bc
	djnz a3
	ret
; 現在の入力を数える
count:	ld hl,0
	ld (cl),hl
	ld (cl+2),hl
	ld (cw),hl
	ld (cw+2),hl
	ld (cb),hl
	ld (cb+2),hl
	xor a
	ld (inw),a
cn1:	call rdb
	ret c
	ld c,a
	ld hl,cb
	call inc32
	ld a,c
	cp 0Ah
	jr nz,cn2
	ld hl,cl
	call inc32
cn2:	ld a,c
	cp 21h
	jr c,cn3
	ld a,(inw)
	or a
	jr nz,cn1
	ld a,1
	ld (inw),a
	ld hl,cw
	call inc32
	jr cn1
cn3:	xor a
	ld (inw),a
	jr cn1
inc32:	inc (hl)
	ret nz
	inc hl
	inc (hl)
	ret nz
	inc hl
	inc (hl)
	ret nz
	inc hl
	inc (hl)
	ret
; DEHL=(HL)の32bit
ld32:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld h,d
	ld l,e
	ld d,b
	ld e,c
	ret
; 選ばれた数を出して名前
report:	ld a,(mask)
	and 1
	jr z,r1
	ld hl,cl
	call ld32
	ld b,7
	call pnum
r1:	ld a,(mask)
	and 2
	jr z,r2
	ld hl,cw
	call ld32
	ld b,8
	call pnum
r2:	ld a,(mask)
	and 4
	jr z,r3
	ld hl,cb
	call ld32
	ld b,8
	call pnum
r3:	ld a,' '
	call wrb
	ld hl,(nmp)
	call wrs
	call wcrlf
	ret
mask:	defb 0
nf:	defb 0
fp:	defw 0
nmp:	defw 0
inw:	defb 0
nostr:	defb 0
totstr:	defm "total"
	defb 0
mopen:	defm "wc: cannot open file",13,10,"$"
musage:	defm "usage: wc [-lwc] [file ...]",13,10,"$"
cl	equ 3E00h
cw	equ 3E04h
cb	equ 3E08h
tl	equ 3E0Ch
tw	equ 3E10h
tb	equ 3E14h
''')

# ---------------- head ----------------
w('head',r'''; HEAD.COM - 先頭の行を出す。 head [-n N | -N] [file]   (既定10行。file省略/-/con は標準入力)   MIT License
'''+HDR+r'''	call tailinit
	ld de,10
	ld (nl),de
hp1:	call sk
	cp '-'
	jr nz,hf
	inc hl
	ld a,(hl)
	cp ' '
	jr z,hdash
	or a
	jr z,hdash
	or 20h
	cp 'n'
	jr nz,hnum
	inc hl
	call sk
hnum:	call atoi
	ld (nl),de
	jr hp1
hdash:	dec hl
hf:	or a
	jr z,hstdin
	ld d,h
	ld e,l
	call tokend
	call openin
	jr nc,hgo
	ld de,mopen
	ld c,9
	call 5
	jp 0
hstdin:	ld de,dashs
	call openin
hgo:	ld a,b
	ld (inh),a
hl1:	ld hl,(nl)
	ld a,h
	or l
	jr z,hend
hl2:	call rdb
	jr c,hend
	call wrb
	cp 0Ah
	jr nz,hl2
	ld hl,(nl)
	dec hl
	ld (nl),hl
	jr hl1
hend:	call closein
	call flush
	jp 0
nl:	defw 10
dashs:	defm "-"
	defb 0
mopen:	defm "head: cannot open file",13,10,"$"
''')

# ---------------- tail ----------------
w('tail',r'''; TAIL.COM - 末尾の行を出す。 tail [-n N | -N] [file]   (既定10行。入力の最後の約20KBだけ見る)   MIT License
'''+HDR+r'''	call tailinit
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
''')

# ---------------- tee ----------------
w('tee',r'''; TEE.COM - 標準入力を標準出力とファイルへ。 tee [-a] file   (-a は追記)   MIT License
'''+HDR+r'''	call tailinit
	xor a
	ld (app),a
	call sk
	cp '-'
	jr nz,ef
	inc hl
	ld a,(hl)
	or 20h
	cp 'a'
	jr nz,eus
	ld a,1
	ld (app),a
	inc hl
	call sk
ef:	or a
	jr z,eus
	ld d,h
	ld e,l
	call tokend
	push de
	ld a,(app)
	or a
	jr z,ecr
	pop de
	push de
	ld a,0
	ld c,43h
	call 5
	or a
	jr nz,ecr
	push bc
	ld a,2			; 末尾へ
	ld de,0
	ld hl,0
	ld c,4Ah
	call 5
	pop bc
	jr egot
ecr:	pop de
	ld a,0
	ld b,0
	ld c,44h
	call 5
	or a
	jr z,egot0
	ld de,mopen
	ld c,9
	call 5
	jp 0
egot:	pop de
egot0:	ld a,b
	ld (outh2),a
	ld (fh),a
	xor a
	ld (inh),a
el1:	call rdb
	jr c,eend
	call wrb
	jr el1
eend:	call flush
	ld a,(fh)
	ld b,a
	ld c,45h
	call 5
	jp 0
eus:	ld de,musage
	ld c,9
	call 5
	jp 0
app:	defb 0
fh:	defb 0
mopen:	defm "tee: cannot create file",13,10,"$"
musage:	defm "usage: tee [-a] file",13,10,"$"
''')

# ---------------- touch ----------------
w('touch',r'''; TOUCH.COM - ファイルが無ければ空で作る(日時は変えない)。 touch file ...   MIT License
'''+HDR+r'''	call tailinit
tl:	call sk
	or a
	jp z,0
	ld d,h
	ld e,l
	call tokend
	push hl
	push de
	ld a,1
	ld c,43h
	call 5
	or a
	jr nz,tcr
	ld c,45h
	call 5
	jr tnx
tcr:	pop de
	push de
	ld a,0
	ld b,0
	ld c,44h
	call 5
	or a
	jr nz,terr
	ld c,45h
	call 5
	jr tnx
terr:	ld de,mfail
	ld c,9
	call 5
tnx:	pop de
	pop hl
	jr tl
mfail:	defm "touch: cannot create file",13,10,"$"
''')

# ---------------- uniq ----------------
w('uniq',r'''; UNIQ.COM - 隣り合う同じ行をまとめる。 uniq [-c] [file]   (-c は回数つき)   MIT License
'''+HDR+r'''	call tailinit
	xor a
	ld (cflag),a
	call sk
	cp '-'
	jr nz,uf
	inc hl
	ld a,(hl)
	cp ' '
	jr z,udash
	or a
	jr z,udash
	or 20h
	cp 'c'
	jp nz,uus
	ld a,1
	ld (cflag),a
	inc hl
	call sk
	jr uf
udash:	dec hl
uf:	or a
	jr z,ustd
	ld d,h
	ld e,l
	call tokend
	call openin
	jr nc,ugo
	ld de,mopen
	ld c,9
	call 5
	jp 0
ustd:	ld de,dashs
	call openin
ugo:	ld a,b
	ld (inh),a
	ld de,pbuf
	call rdline
	jr c,uend0
	ld hl,1
	ld (cnt),hl
ul1:	ld de,cbuf
	call rdline
	jr c,uend
	ld hl,pbuf
	ld de,cbuf
uc1:	ld a,(de)
	cp (hl)
	jr nz,udiff
	or a
	jr z,usame
	inc de
	inc hl
	jr uc1
usame:	ld hl,(cnt)
	inc hl
	ld (cnt),hl
	jr ul1
udiff:	call pline
	ld hl,cbuf
	ld de,pbuf
	ld bc,255
	ldir
	ld hl,1
	ld (cnt),hl
	jr ul1
uend:	call pline
uend0:	call closein
	call flush
	jp 0
pline:	ld a,(cflag)
	or a
	jr z,pl1
	ld hl,(cnt)
	ld de,0
	ld b,7
	call pnum
	ld a,' '
	call wrb
pl1:	ld hl,pbuf
	call wrs
	jp wcrlf
uus:	ld de,musage
	ld c,9
	call 5
	jp 0
cflag:	defb 0
cnt:	defw 0
dashs:	defm "-"
	defb 0
mopen:	defm "uniq: cannot open file",13,10,"$"
musage:	defm "usage: uniq [-c] [file]",13,10,"$"
pbuf	equ 4000h
cbuf	equ 4100h
''')

# ---------------- hd ----------------
w('hd',r'''; HD.COM - 16進ダンプ(オフセット 16バイトの16進 |文字|)。 hd [file]   MIT License
'''+HDR+r'''	call tailinit
	call sk
	or a
	jr z,hstd
	ld d,h
	ld e,l
	call tokend
	call openin
	jr nc,hgo
	ld de,mopen
	ld c,9
	call 5
	jp 0
hstd:	ld de,dashs
	call openin
hgo:	ld a,b
	ld (inh),a
	ld hl,0
	ld (hoff),hl
	ld (hoff+2),hl
hl1:	ld hl,hbuf
	ld b,0			; B=読めたバイト数
hl2:	push bc
	push hl
	call rdb
	pop hl
	pop bc
	jr c,hl3
	ld (hl),a
	inc hl
	inc b
	ld a,b
	cp 16
	jr nz,hl2
hl3:	ld a,b
	or a
	jp z,hend
	ld (got),a
	; オフセット(8桁16進の下位6桁)
	ld hl,(hoff+1)		; 上位16bit=hoff+2,hoff+3? 3バイト目から
	ld a,(hoff+2)
	call phex
	ld a,(hoff+1)
	call phex
	ld a,(hoff)
	call phex
	ld a,' '
	call wrb
	ld c,0
hx1:	ld a,c
	cp 8
	jr nz,hx2
	ld a,' '
	call wrb
hx2:	ld a,(got)
	cp c
	jr z,hxs
	jr c,hxs
	ld hl,hbuf
	ld b,0
	add hl,bc
	ld a,(hl)
	call phex
	jr hx3
hxs:	ld a,' '
	call wrb
	ld a,' '
	call wrb
hx3:	ld a,' '
	call wrb
	inc c
	ld a,c
	cp 16
	jr nz,hx1
	ld a,' '
	call wrb
	ld a,'|'
	call wrb
	ld c,0
ha1:	ld a,(got)
	cp c
	jr z,ha9
	ld hl,hbuf
	ld b,0
	add hl,bc
	ld a,(hl)
	cp 20h
	jr c,ha2
	cp 7Fh
	jr c,ha3
ha2:	ld a,'.'
ha3:	call wrb
	inc c
	jr ha1
ha9:	ld a,'|'
	call wrb
	call wcrlf
	; hoff += got
	ld a,(got)
	ld c,a
	ld hl,(hoff)
	ld b,0
	add hl,bc
	ld (hoff),hl
	jr nc,hl4
	ld hl,hoff+2
	inc (hl)
	jr nz,hl4
	inc hl
	inc (hl)
hl4:	ld a,(got)
	cp 16
	jp z,hl1
hend:	call closein
	call flush
	jp 0
phex:	push af
	rrca
	rrca
	rrca
	rrca
	call phx
	pop af
phx:	and 0Fh
	add a,'0'
	cp '9'+1
	jr c,phx2
	add a,7+20h
phx2:	jp wrb
dashs:	defm "-"
	defb 0
mopen:	defm "hd: cannot open file",13,10,"$"
got:	defb 0
hbuf	equ 4000h
hoff	equ 4020h
''')

# ---------------- sort ----------------
w('sort',r"""; SORT.COM - 行を並べ替える(文字コード順)。 sort [-r] [-u] [file]   -r:逆順 -u:同じ行を1つに   最大約1000行/20KB   MIT License
"""+HDR+r"""	call tailinit
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
"""+"""
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
""")
