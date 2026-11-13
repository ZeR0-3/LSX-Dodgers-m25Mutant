; SJIS.COM - Shift_JIS のテキストを UTF-8 へ変えて標準出力へ。MIT License
;   sjis [-l] [file ...]      引数なしなら標準入力から EOF まで。-l : CR LF の CR を取る(LF だけにする)
;   例) sjis -l note.sjs > note.txt     変換できない文字(表に無い拡張記号など)は ? になる
;   表(coms/sjistab.inc)は tools/gen_utf8tab.py が作る(約6900文字、2分探索)。utf8.COM の逆。～ は U+FF5E、¥(5Ch)は \ のまま。
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
	cp 'l'
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
; A=1バイトを処理
proc:	ld c,a
	ld a,(lead)
	or a
	jr nz,second
	ld a,c
	cp 80h
	jr c,asc
	cp 0A0h
	jr c,islead
	cp 0E0h
	jr c,kana
	cp 0FDh
	jr c,islead
	jr qm
islead:	cp 0A0h
	jr nc,chk2
	cp 81h
	jr c,qm			; 80h
chk2:	ld (lead),a
	ret
asc:	cp 0Dh			; -l: CR を捨てる
	jr nz,asc1
	ld a,(crf)
	or a
	ret nz
	ld a,c
asc1:	jp put
kana:	cp 0A1h			; A1-DF → U+FF61-FF9F
	jr c,qm
	sub 0A1h
	ld l,a
	ld h,0
	ld de,0FF61h
	add hl,de
	jp emit
qm:	ld a,'?'
	jp put
second:	ld d,a			; 2バイト目: 先頭 D=lead, C=2バイト目
	xor a
	ld (lead),a
	ld a,c
	ld e,c
	ld (key),de
	ld hl,0
	ld (slo),hl
	ld hl,NSTAB
	ld (shi),hl
bs:	ld hl,(slo)
	ld de,(shi)
	or a
	sbc hl,de
	jr nc,qm
	ld hl,(slo)
	add hl,de
	srl h
	rr l
	ld (smid),hl
	add hl,hl
	add hl,hl
	ld de,stab
	add hl,de
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld (sptr),hl
	ld hl,(key)
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
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	jr emit
; HL=Unicode を UTF-8 で出す
emit:	ld a,h
	or a
	jr nz,e2
	ld a,l
	cp 80h
	jp c,put1
e2:	ld a,h
	cp 8
	jr nc,e3
	; 2バイト: 110xxxxx 10xxxxxx (U+0080-07FF)
	ld a,l
	and 3Fh
	or 80h
	ld c,a
	add hl,hl
	add hl,hl
	ld a,h
	and 1Fh
	or 0C0h
	push bc
	call put
	pop bc
	ld a,c
	jp put
e3:
	jp e3b
put1:	ld a,l
	jp put
e3b:	; 3バイト目の組み立て(HL=cp): b1=E0|(H>>4) b2=80|((H<<2)&3C | L>>6) b3=80|(L&3F)。put が HL を壊すので先に全部作る
	ld a,l
	and 3Fh
	or 80h
	ld (lobyte),a
	ld a,h
	add a,a
	add a,a
	and 3Ch
	ld c,a
	ld a,l
	rlca
	rlca
	and 03h
	or c
	or 80h
	ld (lobyte+1),a
	ld a,h
	rrca
	rrca
	rrca
	rrca
	and 0Fh
	or 0E0h
	call put
	ld a,(lobyte+1)
	call put
	ld a,(lobyte)
	jp put
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
lead:	defb 0
crf:	defb 0
more:	defb 0
hnd:	defb 0
key:	defw 0
slo:	defw 0
shi:	defw 0
smid:	defw 0
sptr:	defw 0
lobyte:	defw 0
optr:	defw 0
mopen:	defm "sjis: cannot open file",13,10,"$"
musage:	defm "usage: sjis [-l] [file ...]",13,10,"$"
	include "sjistab.inc"
ibuf	equ 8000h
optrb	equ 8400h
oend	equ 8C00h
