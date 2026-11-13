; UTF8.COM - UTF-8 のテキストを Shift_JIS(JIS X 0208 + 半角カナ)へ変えて標準出力へ。MIT License
;   utf8 [-c] [file ...]      引数なしなら標準入力から EOF まで。-c : LF だけの改行を CR LF にする
;   例) utf8 -c note.txt > note.sjs     変換できない文字は ? になる(4バイトのUTF-8 =絵文字など、表に無い文字)
;   表(coms/utf8tab.inc)は tools/gen_utf8tab.py が作る(約6900文字、2分探索)。NEC/IBM拡張の記号は含めない。
	org 0100h
	ld sp,0A000h
	ld hl,0080h
	ld a,(hl)
	inc hl
	ld e,a
	ld d,0
	add hl,de
	ld (hl),0
	ld hl,optrb
	ld (optr),hl
	ld hl,0081h
	call skip
	cp '-'
	jr nz,noopt
	inc hl
	ld a,(hl)
	or 20h
	cp 'c'
	jp nz,usage
	ld a,1
	ld (crf),a
	inc hl
	ld a,(hl)
	cp ' '
	jp nz,usage
	call skip
noopt:	or a
	jr nz,files
	ld a,0			; 引数なし: 標準入力
	ld (hnd),a
	call copy
	jp finish
files:	call skip
	or a
	jp z,finish
	push hl
fe:	ld a,(hl)
	or a
	jr z,fend
	cp ' '
	jr z,fend
	inc hl
	jr fe
fend:	ld c,a
	ld (hl),0
	ld a,c
	ld (more),a
	pop de
	push hl
	ld a,1			; 読み込み専用で開く
	ld c,43h
	call 5
	or a
	jr nz,operr
	ld a,b
	ld (hnd),a
	call copy
	ld a,(hnd)
	ld b,a
	ld c,45h
	call 5
	pop hl
	ld a,(more)
	or a
	jp z,finish
	inc hl
	jr files
operr:	pop hl
	ld de,mopen
	ld c,9
	call 5
	jp finish
usage:	ld de,musage
	ld c,9
	call 5
	jp 0
finish:	call flush
	jp 0
skip:	ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr skip
; hnd のハンドルを EOF まで読んで変換する
copy:	ld a,(hnd)
	ld b,a
	ld de,ibuf
	ld hl,1024
	ld c,48h
	call 5
	or a
	ret nz
	ld a,h
	or l
	ret z
	ld b,h
	ld c,l
	ld hl,ibuf
nxt:	ld a,b
	or c
	jr z,copy
	ld a,(hl)
	inc hl
	dec bc
	push hl
	push bc
	call proc
	pop bc
	pop hl
	jr nxt
; A=1バイトを処理(UTF-8 の途中状態は need/cpv に持つ)
proc:	ld c,a
	ld a,(need)
	or a
	jr z,fresh
	ld a,c
	and 0C0h
	cp 80h
	jr nz,badseq
	ld hl,(cpv)
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,c
	and 3Fh
	or l
	ld l,a
	ld (cpv),hl
	ld a,(need)
	dec a
	ld (need),a
	ret nz
	jp emitcp
badseq:	xor a			; 途中で壊れた: ? を出して、このバイトを先頭として処理し直す
	ld (need),a
	ld (bad),a
	push bc
	call qm
	pop bc
fresh:	ld a,c
	cp 80h
	jr nc,notasc
	cp 0Ah
	jr nz,asc1
	ld a,(crf)
	or a
	jr z,asc0
	ld a,(prev)
	cp 0Dh
	jr z,asc0
	ld a,0Dh
	call put
asc0:	ld a,c
asc1:	ld (prev),a
	jp put
notasc:	cp 0C0h
	jr c,qm
	cp 0E0h
	jr nc,not2
	and 1Fh
	ld l,a
	ld a,1
	jr setn
not2:	cp 0F0h
	jr nc,not3
	and 0Fh
	ld l,a
	ld a,2
	jr setn
not3:	cp 0F8h
	jr nc,qm
	ld l,0
	ld a,3
	ld (need),a
	ld a,1
	ld (bad),a
	ld h,0
	ld (cpv),hl
	ret
setn:	ld (need),a
	xor a
	ld (bad),a
	ld h,0
	ld (cpv),hl
	ret
qm:	xor a
	ld (prev),a
	ld a,'?'
	jp put
; 完成した符号位置 cpv を変換して出す
emitcp:	ld a,(bad)
	or a
	jr z,e1
	xor a
	ld (bad),a
	jr qm
e1:	ld hl,(cpv)
	ld de,0FF61h		; 半角カナ FF61-FF9F → A1-DF
	or a
	sbc hl,de
	jr c,tbl
	ld a,h
	or a
	jr nz,tbl
	ld a,l
	cp 63
	jr nc,tbl
	add a,0A1h
	ld c,a
	xor a
	ld (prev),a
	ld a,c
	jp put
tbl:	ld hl,0
	ld (slo),hl
	ld hl,NTAB
	ld (shi),hl
bs:	ld hl,(slo)
	ld de,(shi)
	or a
	sbc hl,de
	jr nc,qm		; 見つからない
	ld hl,(slo)
	add hl,de
	srl h
	rr l
	ld (smid),hl
	add hl,hl
	add hl,hl
	ld de,tab
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (sptr),hl
	ld hl,(cpv)
	or a
	sbc hl,de
	jr z,found
	jr c,less
	ld hl,(smid)
	inc hl
	ld (slo),hl
	jr bs
less:	ld hl,(smid)
	ld (shi),hl
	jr bs
found:	ld hl,(sptr)
	ld a,(hl)
	inc hl
	ld c,(hl)
	ld (lobyte),a		; 上位バイト(0 なら1バイト文字)
	ld a,c
	ld (lobyte+1),a
	xor a
	ld (prev),a
	ld a,(lobyte)
	or a
	jr z,f1
	call put
f1:	ld a,(lobyte+1)
	jp put
; A=出力バッファへ1バイト(満杯の手前で書き出す)
put:	ld hl,(optr)
	ld (hl),a
	inc hl
	ld (optr),hl
	ld de,oend
	or a
	sbc hl,de
	ret c
flush:	ld hl,(optr)
	ld de,optrb
	or a
	sbc hl,de
	ld a,h
	or l
	ret z
	ld b,1
	ld de,optrb
	ld c,49h
	call 5
	ld hl,optrb
	ld (optr),hl
	ret
need:	defb 0
bad:	defb 0
crf:	defb 0
prev:	defb 0
more:	defb 0
hnd:	defb 0
cpv:	defw 0
slo:	defw 0
shi:	defw 0
smid:	defw 0
sptr:	defw 0
lobyte:	defw 0
optr:	defw 0
mopen:	defm "utf8: cannot open file",13,10,"$"
musage:	defm "usage: utf8 [-c] [file ...]",13,10,"$"
	include "utf8tab.inc"
ibuf	equ 8000h
optrb	equ 8400h
oend	equ 8C00h
