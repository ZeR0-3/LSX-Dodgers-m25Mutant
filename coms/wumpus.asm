;@cp932
; WUMPUS.COM - 怪物ワンプスを退治するゲーム(古典 "Hunt the Wumpus" 方式の作り直し)。     MIT License
;   20部屋の洞窟(各部屋は3つの部屋につながる)。穴(2)と コウモリ(2)と ワンプス(1)が隠れている。
;   隣の部屋の危険は においと音で分かる。矢は5本。矢は最大5部屋ぶん飛ばせる。
	org 0100h
	ld sp,0A000h
	call seedinit
	call kon
	call cls
	ld hl,mtitle
	call pstr
newgame:
	call setup
turn:	call showroom
ask:	ld hl,mcmd
	call pstr
	call getkey
	call lcase
	push af
	call pchr
	call pnl
	pop af
	cp 'm'
	jp z,domove
	cp 's'
	jp z,doshoot
	cp 'q'
	jp z,quit
	jr ask
; ---- 準備: 6か所(自分・ワンプス・穴2・コウモリ2)を重ならない部屋に ----
setup:	ld b,0
su1:	ld a,20
	call rndn
	inc a
	ld c,a
	ld hl,loc
	ld d,b
su2:	ld a,d
	or a
	jr z,su3
	ld a,(hl)
	cp c
	jr z,su1
	inc hl
	dec d
	jr su2
su3:	ld hl,loc
	ld e,b
	ld d,0
	add hl,de
	ld (hl),c
	inc b
	ld a,b
	cp 6
	jr nz,su1
	ld a,5
	ld (arrows),a
	ret
; ---- 今いる部屋を表示 ----
showroom:
	call pnl
	ld hl,mhere1
	call pstr
	ld a,(pos)
	call pnum
	ld hl,mhere2
	call pstr
	ld a,(pos)
	call adjptr		; HL=隣3部屋
	ld b,3
sr1:	ld a,(hl)
	inc hl
	push hl
	push bc
	call pnum
	ld a,' '
	call pchr
	pop bc
	pop hl
	djnz sr1
	call pnl
	; におい・音・風
	ld a,(pos)
	call adjptr
	ld b,3
sr2:	ld a,(hl)
	inc hl
	push hl
	push bc
	ld c,a
	ld a,(wum)
	cp c
	jr nz,sr3
	ld hl,mwum
	call pstr
sr3:	ld a,(pit1)
	cp c
	jr z,sr4
	ld a,(pit2)
	cp c
	jr nz,sr5
sr4:	ld hl,mpit
	call pstr
sr5:	ld a,(bat1)
	cp c
	jr z,sr6
	ld a,(bat2)
	cp c
	jr nz,sr7
sr6:	ld hl,mbat
	call pstr
sr7:	pop bc
	pop hl
	djnz sr2
	ld hl,marrow1
	call pstr
	ld a,(arrows)
	call pnum
	ld hl,marrow2
	call pstr
	ret
; A (0-255) を表示
pnum:	ld l,a
	ld h,0
	jp pdec
; A=部屋 -> HL=その部屋の隣3部屋の表
adjptr:	dec a
	ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	ld de,adj
	add hl,de
	ret
; 部屋番号を読む -> A (1-20、無効は0)
readroom:
	ld hl,ibuf
	ld b,3
	call getline
	ld hl,ibuf
	ld a,(hl)
	call isdigit
	jr nc,rr0
	sub '0'
	ld c,a
	inc hl
	ld a,(hl)
	or a
	jr z,rr1
	call isdigit
	jr nc,rr0
	ld a,c			; 2桁
	add a,a
	ld d,a
	add a,a
	add a,a
	add a,d			; c*10 (c*2*5)
	ld c,a
	ld a,(hl)
	sub '0'
	add a,c
	ld c,a
	inc hl
	ld a,(hl)
	or a
	jr nz,rr0
rr1:	ld a,c
	or a
	jr z,rr0
	cp 21
	jr nc,rr0
	ret
rr0:	xor a
	ret
; A が今の部屋(pos)の隣か -> Z で隣
isadj:	ld c,a
	ld a,(pos)
	call adjptr
	ld b,3
ia1:	ld a,(hl)
	cp c
	ret z
	inc hl
	djnz ia1
	or 1			; NZ
	ret
; ---- 移動 ----
domove:	ld hl,mwhere
	call pstr
	call readroom
	or a
	jp z,badroom
	push af
	call isadj
	jr z,mv1
	pop af
badroom:ld hl,mbadroom
	call pstr
	jp turn
mv1:	pop af
	ld (pos),a
enter:	ld a,(pos)
	ld c,a
	ld a,(wum)
	cp c
	jr nz,en1
	ld hl,mbump
	call pstr
	ld a,4
	call rndn
	or a
	jp z,eaten
	call wumflee
en1:	ld a,(pit1)
	cp c
	jr z,fell
	ld a,(pit2)
	cp c
	jr z,fell
	ld a,(bat1)
	cp c
	jr z,bat
	ld a,(bat2)
	cp c
	jr z,bat
	jp turn
fell:	ld hl,mfell
	call pstr
	jp lose
bat:	ld hl,mbatcarry
	call pstr
	ld a,20
	call rndn
	inc a
	ld (pos),a
	jp enter
eaten:	ld hl,meaten
	call pstr
	jp lose
; ワンプスが隣の部屋のどれかへ逃げる
wumflee:ld hl,mflee
	call pstr
	ld a,(wum)
	call adjptr
	ld a,3
	call rndn
	ld e,a
	ld d,0
	add hl,de
	ld a,(hl)
	ld (wum),a
	ret
; ---- 射撃 ----
doshoot:ld hl,mhow
	call pstr
sh0:	call getkey
	call isdigit
	jr nc,sh0
	sub '0'
	jr z,sh0
	cp 6
	jr nc,sh0
	ld (nroom),a
	push af
	call pchr
	call pnl
	pop af
	ld b,a
	ld hl,path
sh1:	push hl
	push bc
	ld hl,mroomq
	call pstr
	call readroom
	pop bc
	pop hl
	or a
	jr nz,sh2
	push hl
	push bc
	ld hl,mbadroom
	call pstr
	pop bc
	pop hl
	jr sh1
sh2:	ld (hl),a
	inc hl
	djnz sh1
	; 飛ぶ
	ld a,(pos)
	ld (cur),a
	ld hl,path
	ld a,(nroom)
	ld b,a
sh3:	push hl
	push bc
	ld a,(hl)
	ld c,a
	ld a,(cur)
	call adjptr
	ld b,3
sh4:	ld a,(hl)
	cp c
	jr z,sh5
	inc hl
	djnz sh4
	ld a,3			; 隣でなければ でたらめに
	call rndn
	ld e,a
	ld d,0
	ld a,(cur)
	call adjptr
	add hl,de
	ld a,(hl)
	ld c,a
sh5:	ld a,c
	ld (cur),a
	ld a,(wum)
	cp c
	jr z,hitw
	ld a,(pos)
	cp c
	jr z,hitme
	pop bc
	pop hl
	inc hl
	djnz sh3
	; はずれ
	ld hl,mmiss
	call pstr
	ld hl,arrows
	dec (hl)
	ld a,4
	call rndn
	or a
	jr z,sh6		; 4回に1回は動かない
	call wumflee
	ld a,(wum)
	ld c,a
	ld a,(pos)
	cp c
	jp z,eaten
sh6:	ld a,(arrows)
	or a
	jp nz,turn
	ld hl,mnoarrow
	call pstr
	jp lose
hitw:	pop bc
	pop hl
	ld hl,mkill
	call pstr
	jp win
hitme:	pop bc
	pop hl
	ld hl,mself
	call pstr
	jp lose
; ---- 終わり ----
win:	ld hl,mwin
	call pstr
	jr again
lose:	ld hl,mlose
	call pstr
again:	ld hl,magain
	call pstr
	call askyn
	or a
	jp nz,newgame
quit:	call koff
	ld c,0
	jp 5
	include "gamelib.inc"
adj:	defb 2,5,8, 1,3,10, 2,4,12, 3,5,14, 1,4,6
	defb 5,7,15, 6,8,17, 1,7,9, 8,10,18, 2,9,11
	defb 10,12,19, 3,11,13, 12,14,20, 4,13,15, 6,14,16
	defb 15,17,20, 7,16,18, 9,17,19, 11,18,20, 13,16,19
loc:
pos:	defb 0
wum:	defb 0
pit1:	defb 0
pit2:	defb 0
bat1:	defb 0
bat2:	defb 0
arrows:	defb 5
nroom:	defb 0
cur:	defb 0
path:	defs 6
ibuf:	defs 6
mtitle:	defm "== ワンプス退治 ==",13,10
	defm "20部屋の洞窟のどこかに怪物ワンプスがいます。矢(5本)で退治してください。",13,10
	defm "穴に落ちるか、ワンプスに食べられたら負け。コウモリは別の部屋へ運びます。",13,10
	defm "M=隣の部屋へ移動  S=矢を射る(部屋の番号を最大5つ)  Q=終了",13,10,0
mhere1:	defm "あなたは ",0
mhere2:	defm " 号室にいます。  つながる部屋: ",0
mwum:	defm "  ワンプスのにおいがする!",13,10,0
mpit:	defm "  冷たい風を感じる。",13,10,0
mbat:	defm "  コウモリの羽音が聞こえる。",13,10,0
marrow1: defm "  (矢 ",0
marrow2: defm " 本)",13,10,0
mcmd:	defm "移動(M) 射撃(S) 終了(Q) ? ",0
mwhere:	defm "どの部屋へ? ",0
mbadroom: defm "  そこへは行けません。",13,10,0
mbump:	defm "ワンプスの部屋に入ってしまった!",13,10,0
mflee:	defm "ワンプスは隣の部屋へ移った。",13,10,0
mfell:	defm "足元に穴が! 落ちてしまった...",13,10,0
mbatcarry: defm "コウモリにつかまれて別の部屋へ運ばれた!",13,10,0
meaten:	defm "ワンプスに食べられてしまった...",13,10,0
mhow:	defm "何部屋ぶん飛ばす(1-5)? ",0
mroomq:	defm "  部屋の番号? ",0
mmiss:	defm "矢ははずれた。",13,10,0
mkill:	defm "矢が命中! ワンプスを倒した!",13,10,0
mself:	defm "矢が戻ってきて自分に当たってしまった...",13,10,0
mnoarrow: defm "矢がなくなってしまった。",13,10,0
mwin:	defm "おめでとう! あなたの勝ちです。",13,10,0
mlose:	defm "あなたの負けです。",13,10,0
magain:	defm "もう一度? (y/n) ",0
