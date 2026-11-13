;@cp932
; TREK.COM - 宇宙艦隊の戦術ゲーム(1970年代の古典的な「宇宙戦」ゲームの考え方による作り直し。名前・文章・コードはすべて独自)。   MIT License
;   64x64 の宇宙(8x8 区画 x 8x8 セクタ)に敵艦が散らばっている。日数切れまでに全部倒す。基地の隣でエネルギー補給。
	org 0100h
NEMAX	equ	12
gal	equ	endimg		; 宇宙の地図 64x64 (起動時に 0 で埋める): 0=空 1=星 2=敵 3=基地
	ld sp,0A000h
	ld hl,endimg
	ld de,endimg+1
	ld bc,4095
	ld (hl),0
	ldir
	call seedinit
	call kon
	call cls
	ld hl,mtitle
	call pstr
newgame:
	call setup
	call shortscan
cmdloop:
	ld hl,mcmd
	call pstr
	call getkey
	call lcase
	push af
	call pchr
	call pnl
	pop af
	cp 'm'
	jp z,cmove
	cp 's'
	jp z,cscan
	cp 'l'
	jp z,clong
	cp 'p'
	jp z,cphaser
	cp 't'
	jp z,ctorp
	cp 'h'
	jp z,cshield
	cp '?'
	jp z,chelp
	cp 'q'
	jp z,quit
	jr cmdloop
; ---------------------------------------------------------------- 準備
setup:	ld hl,gal
	ld de,gal+1
	ld bc,4095
	ld (hl),0
	ldir
	ld a,64
	call rndn
	ld (ppx),a
	ld a,64
	call rndn
	ld (ppy),a
	ld b,150		; 星
st1:	push bc
	call randempty
	ld (hl),1
	pop bc
	djnz st1
	ld b,3			; 基地
	ld a,b
	ld (nbase),a
sb1:	push bc
	call randempty
	ld (hl),3
	pop bc
	djnz sb1
	ld a,4
	call rndn
	add a,8
	ld (nenemy),a
	ld b,a
	ld hl,etab
	ld (eptr),hl
se1:	push bc
se2:	call randempty		; 自分のいる区画には置かない
	ld a,(rx)
	and 0F8h
	ld c,a
	ld a,(ppx)
	and 0F8h
	cp c
	jr nz,se3
	ld a,(ry)
	and 0F8h
	ld c,a
	ld a,(ppy)
	and 0F8h
	cp c
	jr z,se2
se3:	ld (hl),2
	ld ix,(eptr)
	ld a,(rx)
	ld (ix+0),a
	ld a,(ry)
	ld (ix+1),a
	ld (ix+2),200
	ld (ix+3),0
	ld (ix+4),1
	ld de,5
	add ix,de
	ld (eptr),ix
	pop bc
	djnz se1
	ld a,(nenemy)		; 残りの表の枠は使わない
	ld b,a
	ld a,NEMAX
	sub b
	jr z,se5
	ld b,a
se4:	ld ix,(eptr)
	ld (ix+4),0
	ld de,5
	add ix,de
	ld (eptr),ix
	djnz se4
se5:	ld hl,3000
	ld (energy),hl
	ld hl,0
	ld (shield),hl
	ld a,10
	ld (torp),a
	ld a,30
	ld (days),a
	ret
; 空いているセクタをでたらめに選ぶ -> HL=地図の番地 (rx, ry も)
randempty:
re1:	ld a,64
	call rndn
	ld (rx),a
	ld a,64
	call rndn
	ld (ry),a
	ld a,(ppx)
	ld b,a
	ld a,(rx)
	cp b
	jr nz,re2
	ld a,(ppy)
	ld b,a
	ld a,(ry)
	cp b
	jr z,re1
re2:	ld a,(rx)
	ld b,a
	ld a,(ry)
	ld c,a
	call cellptr
	ld a,(hl)
	or a
	jr nz,re1
	ret
; B=x C=y -> HL=gal+y*64+x
cellptr:ld l,c
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld e,b
	ld d,0
	add hl,de
	ld de,gal
	add hl,de
	ret
; ---------------------------------------------------------------- 表示
; 今の区画の地図と状態
shortscan:
	call pnl
	ld a,(ppy)
	and 0F8h
	ld (qy0),a
	ld a,(ppx)
	and 0F8h
	ld (qx0),a
	xor a
	ld (row),a
ss1:	ld a,(row)
	ld b,a
	ld a,(qy0)
	add a,b
	ld c,a
	xor a
	ld (col),a
ss2:	ld a,(col)
	ld b,a
	ld a,(qx0)
	add a,b
	ld b,a			; x
	push bc
	call cellptr
	pop bc
	ld a,(hl)
	ld hl,chars
	ld e,a
	ld d,0
	add hl,de
	ld a,(hl)
	ld d,a
	ld a,(ppx)
	cp b
	jr nz,ss3
	ld a,(ppy)
	cp c
	jr nz,ss3
	ld d,'E'
ss3:	ld a,d
	call pchr
	ld a,' '
	call pchr
	ld hl,col
	inc (hl)
	ld a,(hl)
	cp 8
	jr nz,ss2
	; 右側に状態
	ld a,(row)
	call statline
	call pnl
	ld hl,row
	inc (hl)
	ld a,(hl)
	cp 8
	jr nz,ss1
	ret
; A=行 : 状態を1行表示
statline:
	or a
	jr nz,sl1
	ld hl,mdays
	call pstr
	ld a,(days)
	jp pnum
sl1:	cp 1
	jr nz,sl2
	ld hl,menergy
	call pstr
	ld hl,(energy)
	jp pdec
sl2:	cp 2
	jr nz,sl3
	ld hl,mshield
	call pstr
	ld hl,(shield)
	bit 7,h
	jr z,sl2b
	ld hl,0
sl2b:	jp pdec
sl3:	cp 3
	jr nz,sl4
	ld hl,mtorp
	call pstr
	ld a,(torp)
	jp pnum
sl4:	cp 4
	jr nz,sl5
	ld hl,menemy
	call pstr
	ld a,(nenemy)
	jp pnum
sl5:	cp 5
	jr nz,sl6
	ld hl,mbase
	call pstr
	ld a,(nbase)
	jp pnum
sl6:	cp 6
	jr nz,sl7
	ld hl,mquad
	call pstr
	ld a,(ppx)
	rrca
	rrca
	rrca
	and 7
	inc a
	call pnum
	ld a,'-'
	call pchr
	ld a,(ppy)
	rrca
	rrca
	rrca
	and 7
	inc a
	jp pnum
sl7:	ld hl,mcond
	call pstr
	call isdocked
	jr nz,sl7b
	ld hl,mdocked
	jp pstr
sl7b:	call enemies_here	; A=敵の数
	or a
	jr z,sl7c
	ld hl,malert
	jp pstr
sl7c:	ld hl,mcalm
	jp pstr
; 基地の隣か -> Z で隣
isdocked:
	ld a,(ppx)
	dec a
	ld b,a
	ld a,(ppy)
	dec a
	ld c,a
	ld d,3
id1:	ld e,3
	push bc
id2:	push bc
	push de
	ld a,b
	cp 64
	jr nc,id3		; 範囲外(0未満は 255 になる)
	ld a,c
	cp 64
	jr nc,id3
	call cellptr
	ld a,(hl)
	cp 3
	jr nz,id3
	pop de
	pop bc
	pop bc
	xor a			; Z
	ret
id3:	pop de
	pop bc
	inc b
	dec e
	jr nz,id2
	pop bc
	inc c
	dec d
	jr nz,id1
	or 1			; NZ
	ret
; 今の区画にいる敵の数 -> A
enemies_here:
	ld hl,etab
	ld b,NEMAX
	ld c,0
eh1:	ld a,(hl)
	push hl
	inc hl
	inc hl
	inc hl
	inc hl
	ld a,(hl)
	pop hl
	or a
	jr z,eh9
	ld a,(hl)
	and 0F8h
	ld d,a
	ld a,(ppx)
	and 0F8h
	cp d
	jr nz,eh9
	inc hl
	ld a,(hl)
	dec hl
	and 0F8h
	ld d,a
	ld a,(ppy)
	and 0F8h
	cp d
	jr nz,eh9
	inc c
eh9:	ld de,5
	add hl,de
	djnz eh1
	ld a,c
	ret
; A (0-255) を表示
pnum:	ld l,a
	ld h,0
	jp pdec
; ---------------------------------------------------------------- コマンド
cscan:	call shortscan
	jp cmdloop
chelp:	ld hl,mhelp
	call pstr
	jp cmdloop
; 長距離スキャン: 周りの 3x3 区画の「敵 基地 星」の数
clong:	ld hl,mlong
	call pstr
	ld a,(ppy)
	rrca
	rrca
	rrca
	and 7
	dec a
	ld (lqy),a
	ld a,3
	ld (row),a
cl1:	ld a,(ppx)
	rrca
	rrca
	rrca
	and 7
	dec a
	ld (lqx),a
	ld a,3
	ld (col),a
	ld a,' '
	call pchr
cl2:	ld a,(lqx)
	cp 8
	jr nc,cl3
	ld b,a
	ld a,(lqy)
	cp 8
	jr nc,cl3
	ld c,a
	call qcount
	ld a,(cnt_k)
	add a,'0'
	call pchr
	ld a,(cnt_b)
	add a,'0'
	call pchr
	ld a,(cnt_s)
	cp 10
	jr c,cl2b
	ld a,9
cl2b:	add a,'0'
	call pchr
	jr cl4
cl3:	ld a,'*'
	call pchr
	call pchr
	call pchr
cl4:	ld a,' '
	call pchr
	ld hl,lqx
	inc (hl)
	ld hl,col
	dec (hl)
	jr nz,cl2
	call pnl
	ld hl,lqy
	inc (hl)
	ld hl,row
	dec (hl)
	jr nz,cl1
	ld hl,mlong2
	call pstr
	jp cmdloop
; B=区画x C=区画y (0-7) -> cnt_k cnt_b cnt_s
qcount:	xor a
	ld (cnt_k),a
	ld (cnt_b),a
	ld (cnt_s),a
	ld a,c
	rlca
	rlca
	rlca
	ld c,a
	ld a,b
	rlca
	rlca
	rlca
	ld b,a
	call cellptr
	ld d,8
qc1:	ld e,8
	push hl
qc2:	ld a,(hl)
	inc hl
	cp 1
	jr nz,qc3
	push hl
	ld hl,cnt_s
	inc (hl)
	pop hl
	jr qc5
qc3:	cp 2
	jr nz,qc4
	push hl
	ld hl,cnt_k
	inc (hl)
	pop hl
	jr qc5
qc4:	cp 3
	jr nz,qc5
	push hl
	ld hl,cnt_b
	inc (hl)
	pop hl
qc5:	dec e
	jr nz,qc2
	pop hl
	ld bc,64
	add hl,bc
	dec d
	jr nz,qc1
	ret
; ---- 方向を聞く -> A=1..9(5以外) 0=取消 ----
readdir:ld hl,mdir
	call pstr
	call getkey
	push af
	call pchr
	call pnl
	pop af
	call isdigit
	jr nc,rd0
	sub '0'
	cp 5
	jr z,rd0
	or a
	jr z,rd0
	ret
rd0:	xor a
	ret
; 数を聞く: HL=聞く文字 -> HL=値(0 は無効)
readnum:call pstr
	ld hl,nbuf
	ld b,5
	call getline
	ld hl,nbuf
	ld de,0
rn_1:	ld a,(hl)
	or a
	jr z,rn_9
	call isdigit
	jr nc,rn_0
	sub '0'
	push hl
	ld h,d
	ld l,e
	add hl,hl
	add hl,hl
	add hl,de
	add hl,hl		; x10
	ld e,a
	ld d,0
	add hl,de
	ex de,hl
	pop hl
	inc hl
	jr rn_1
rn_9:	ex de,hl
	ret
rn_0:	ld hl,0
	ret
; A=方向 -> dx,dy (符号付き)
dirvec:	ld e,a
	ld d,0
	ld hl,dxt
	add hl,de
	ld a,(hl)
	ld (dx),a
	ld hl,dyt
	add hl,de
	ld a,(hl)
	ld (dy),a
	ret
; ---- 移動 ----
cmove:	call readdir
	or a
	jp z,cmdloop
	call dirvec
	ld hl,mdist
	call readnum
	ld a,h
	or a
	jp nz,cmdloop
	ld a,l
	or a
	jp z,cmdloop
	cp 41
	jp nc,cmdloop
	ld (dist),a
	ld e,a			; 必要なエネルギー = 距離 x 2
	ld d,0
	sla e
	rl d
	ld hl,(energy)
	or a
	sbc hl,de
	jr nc,mv0
	ld hl,mnoenergy
	call pstr
	jp cmdloop
mv0:	xor a
	ld (moved),a
mv1:	ld a,(dist)
	or a
	jr z,mv9
	ld a,(dx)
	ld b,a
	ld a,(ppx)
	add a,b
	cp 64
	jr nc,mvedge		; 0 未満(255)も含む
	ld b,a
	ld a,(dy)
	ld c,a
	ld a,(ppy)
	add a,c
	cp 64
	jr nc,mvedge
	ld c,a
	push bc
	call cellptr
	pop bc
	ld a,(hl)
	or a
	jr nz,mvblock
	ld a,b
	ld (ppx),a
	ld a,c
	ld (ppy),a
	ld hl,moved
	inc (hl)
	ld hl,dist
	dec (hl)
	jr mv1
mvedge:	ld hl,medge
	call pstr
	jr mv9
mvblock:ld hl,mblock
	call pstr
mv9:	ld a,(moved)
	or a
	jr z,mv10
	ld e,a
	ld d,0
	sla e
	rl d
	ld hl,(energy)
	or a
	sbc hl,de
	ld (energy),hl
	ld a,(moved)
	add a,7
	rrca
	rrca
	rrca
	and 1Fh
	ld b,a			; 経過日数
	ld a,(days)
	sub b
	jr nc,mv11
	xor a
mv11:	ld (days),a
mv10:	call dock
	call shortscan
	call enemy_fire
	jp turnend
; 基地の隣ならエネルギーなどを補給
dock:	call isdocked
	ret nz
	ld hl,3000
	ld (energy),hl
	ld hl,0
	ld (shield),hl
	ld a,10
	ld (torp),a
	ld hl,mdock
	jp pstr
; ---- フェーザー ----
cphaser:ld hl,mph
	call readnum
	ld a,h
	or l
	jp z,cmdloop
	ld de,1001
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,ph0
	ld hl,1000
ph0:	ld (amount),hl
	ld de,(energy)
	or a
	sbc hl,de
	jr z,ph1
	jr c,ph1
	ld hl,mnoenergy
	call pstr
	jp cmdloop
ph1:	call enemies_here
	or a
	jr nz,ph2
	ld hl,mnoone
	call pstr
	jp cmdloop
ph2:	ld (ecount),a
	ld hl,(energy)
	ld de,(amount)
	or a
	sbc hl,de
	ld (energy),hl
	ld hl,(amount)	; 1隻あたり
	ld e,a
	ld d,0
	call divhl
	ld (per),hl
	ld hl,etab
	ld (eptr),hl
	ld a,NEMAX
	ld (ei),a
ph3:	ld ix,(eptr)
	ld a,(ix+4)
	or a
	jp z,ph8
	call inquad
	jp nz,ph8
	call eddist		; A=距離
	ld c,a
	ld hl,(per)
	ld e,c
	ld d,0
	push hl
	ld a,c
	add a,a
	add a,c			; 距離 x3
	ld e,a
	ld d,0
	call mul16		; HL = per * (距離x3)
	ld de,100
	call divhl
	ex de,hl
	pop hl
	or a
	sbc hl,de		; 命中 = per - per*距離*3/100
	jr nc,ph4
	ld hl,0
ph4:	ld (dmg),hl
	ld hl,mhitE
	call pstr
	call epos
	ld hl,mdmg1
	call pstr
	ld hl,(dmg)
	call pdec
	ld hl,mdmg2
	call pstr
	ld ix,(eptr)
	ld l,(ix+2)
	ld h,(ix+3)
	ld de,(dmg)
	or a
	sbc hl,de
	jr z,phk
	jr nc,phs
phk:	call killenemy
	jr ph8
phs:	ld ix,(eptr)
	ld (ix+2),l
	ld (ix+3),h
ph8:	ld hl,(eptr)
	ld de,5
	add hl,de
	ld (eptr),hl
	ld hl,ei
	dec (hl)
	jp nz,ph3
	call enemy_fire
	jp turnend
; HL = HL*DE (16ビット)
mul16:	ld b,h
	ld c,l
	ld hl,0
	ld a,16
m16a:	add hl,hl
	rl e
	rl d
	jr nc,m16b
	add hl,bc
m16b:	dec a
	jr nz,m16a
	ret
; IX=敵 : 今の区画にいれば Z
inquad:	ld a,(ix+0)
	and 0F8h
	ld b,a
	ld a,(ppx)
	and 0F8h
	cp b
	ret nz
	ld a,(ix+1)
	and 0F8h
	ld b,a
	ld a,(ppy)
	and 0F8h
	cp b
	ret
; IX=敵 -> A=距離(大きい方の差)
eddist:	ld a,(ix+0)
	ld b,a
	ld a,(ppx)
	sub b
	jr nc,ed1
	neg
ed1:	ld c,a
	ld a,(ix+1)
	ld b,a
	ld a,(ppy)
	sub b
	jr nc,ed2
	neg
ed2:	cp c
	ret nc
	ld a,c
	ret
; (eptr) の敵のセクタ位置 (x,y) を表示
epos:	ld ix,(eptr)
	ld a,'('
	call pchr
	ld ix,(eptr)
	ld a,(ix+0)
	and 7
	inc a
	call pnum
	ld a,','
	call pchr
	ld ix,(eptr)
	ld a,(ix+1)
	and 7
	inc a
	call pnum
	ld a,')'
	jp pchr
; (eptr) の敵を倒す
killenemy:
	ld ix,(eptr)
	ld (ix+4),0
	ld b,(ix+0)
	ld c,(ix+1)
	call cellptr
	ld (hl),0
	ld hl,nenemy
	dec (hl)
	ld hl,mkill
	jp pstr
; ---- 魚雷 ----
ctorp:	ld a,(torp)
	or a
	jr nz,tp0
	ld hl,mnotorp
	call pstr
	jp cmdloop
tp0:	call readdir
	or a
	jp z,cmdloop
	call dirvec
	ld hl,torp
	dec (hl)
	ld a,(ppx)
	ld (tx),a
	ld a,(ppy)
	ld (ty),a
	ld a,10
	ld (tn),a
tp1:	ld a,(dx)
	ld b,a
	ld a,(tx)
	add a,b
	ld (tx),a
	ld b,a
	ld a,(dy)
	ld c,a
	ld a,(ty)
	add a,c
	ld (ty),a
	ld c,a
	ld a,b
	cp 64
	jr nc,tpmiss
	ld a,c
	cp 64
	jr nc,tpmiss
	ld a,b			; 同じ区画の中だけ
	and 0F8h
	ld d,a
	ld a,(ppx)
	and 0F8h
	cp d
	jr nz,tpmiss
	ld a,c
	and 0F8h
	ld d,a
	ld a,(ppy)
	and 0F8h
	cp d
	jr nz,tpmiss
	call cellptr
	ld a,(hl)
	or a
	jr z,tp2
	cp 1
	jr z,tpstar
	cp 3
	jr z,tpbase
	; 敵
	call findenemy
	ld hl,mtkill
	call pstr
	call killenemy
	jr tp9
tp2:	ld hl,tn
	dec (hl)
	jr nz,tp1
tpmiss:	ld hl,mtmiss
	call pstr
	jr tp9
tpstar:	ld hl,mtstar
	call pstr
	jr tp9
tpbase:	ld (hl),0
	ld hl,nbase
	dec (hl)
	ld hl,mtbase
	call pstr
tp9:	call enemy_fire
	jp turnend
; (tx,ty) にいる敵を探して eptr に
findenemy:
	ld hl,etab
	ld b,NEMAX
fe1:	ld a,(hl)
	ld d,a
	inc hl
	ld a,(hl)
	inc hl
	inc hl
	inc hl
	ld c,a
	ld a,(hl)
	or a
	jr z,fe2
	ld a,(tx)
	cp d
	jr nz,fe2
	ld a,(ty)
	cp c
	jr nz,fe2
	ld de,-4
	add hl,de
	ld (eptr),hl
	ret
fe2:	inc hl
	djnz fe1
	ld hl,etab
	ld (eptr),hl
	ret
; ---- シールド ----
cshield:ld hl,(shield)
	bit 7,h
	jr z,sh1
	ld hl,0
sh1:	ld de,(energy)
	add hl,de
	ld (total),hl
	ld hl,mshq
	call readnum
	ld de,(total)
	push hl
	ex de,hl
	or a
	sbc hl,de		; total - 入力
	pop de
	jr nc,sh2
	ld hl,mnoenergy
	call pstr
	jp cmdloop
sh2:	ld (energy),hl
	ld (shield),de
	ld hl,mshok
	call pstr
	call shortscan
	jp cmdloop
; ---- 敵の攻撃 ----
enemy_fire:
	call enemies_here
	or a
	ret z
	call isdocked
	jr nz,ef0
	ld hl,mprot
	jp pstr
ef0:	ld hl,etab
	ld (eptr),hl
	ld a,NEMAX
	ld (ei),a
ef1:	ld ix,(eptr)
	ld a,(ix+4)
	or a
	jr z,ef8
	call inquad
	jr nz,ef8
	call eddist
	ld (edist),a
	ld a,100
	call rndn
	add a,50
	ld e,a
	ld d,0
	ld ix,(eptr)
	ld l,(ix+2)
	ld h,(ix+3)
	call mul16
	ld de,100
	call divhl
	ld a,(edist)
	add a,2
	ld e,a
	ld d,0
	call divhl
	ld (dmg),hl
	ld hl,mEatk
	call pstr
	call epos
	ld hl,mdmg1
	call pstr
	ld hl,(dmg)
	call pdec
	ld hl,mdmg2
	call pstr
	ld hl,(shield)
	ld de,(dmg)
	or a
	sbc hl,de
	ld (shield),hl
ef8:	ld hl,(eptr)
	ld de,5
	add hl,de
	ld (eptr),hl
	ld hl,ei
	dec (hl)
	jr nz,ef1
	ret
; ---- ターンの終わり ----
turnend:ld a,(nenemy)
	or a
	jp z,win
	ld hl,(shield)
	bit 7,h
	jp nz,lose_dead
	ld hl,(energy)
	ld de,(shield)
	add hl,de
	ld a,h
	or l
	jp z,lose_energy
	ld a,(days)
	or a
	jp z,lose_time
	jp cmdloop
win:	ld hl,mwin1
	call pstr
	ld a,(days)
	call pnum
	ld hl,mwin2
	call pstr
	jr again
lose_dead:
	ld hl,mdead
	call pstr
	jr again
lose_energy:
	ld hl,mnoeng
	call pstr
	jr again
lose_time:
	ld hl,mtime
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
chars:	defm ".*KB"
dxt:	defb 0,-1,0,1,-1,0,1,-1,0,1
dyt:	defb 0,1,1,1,0,0,0,-1,-1,-1
ppx:	defb 0
ppy:	defb 0
rx:	defb 0
ry:	defb 0
qx0:	defb 0
qy0:	defb 0
row:	defb 0
col:	defb 0
lqx:	defb 0
lqy:	defb 0
cnt_k:	defb 0
cnt_b:	defb 0
cnt_s:	defb 0
dx:	defb 0
dy:	defb 0
dist:	defb 0
moved:	defb 0
energy:	defw 0
shield:	defw 0
torp:	defb 0
days:	defb 0
nenemy:	defb 0
nbase:	defb 0
amount:	defw 0
per:	defw 0
dmg:	defw 0
total:	defw 0
ecount:	defb 0
ei:	defb 0
edist:	defb 0
eptr:	defw 0
tx:	defb 0
ty:	defb 0
tn:	defb 0
nbuf:	defs 8
etab:	defs NEMAX*5
mtitle:	defm "== 宇宙艦隊戦 ==",13,10
	defm "広い宇宙(8x8 の区画、各区画は 8x8 のセクタ)に敵艦(K)が隠れています。",13,10
	defm "30日以内に敵を全部倒してください。基地(B)の隣ではエネルギーが補給できます。",13,10
	defm "E=自分の艦  K=敵艦  B=基地  *=星   (? で操作の一覧)",13,10,0
mcmd:	defm "命令 (M移動 S地図 L遠望 P砲 T魚雷 H盾 ?一覧 Q終了) ? ",0
mhelp:	defm "M 移動(方向と距離)  S 今の区画の地図  L 周りの区画の「敵 基地 星」の数",13,10
	defm "P フェーザー砲(エネルギーを撃つ。近いほど効く)  T 光子魚雷(まっすぐ飛ぶ。同じ区画内)",13,10
	defm "H シールドへエネルギーを回す  Q 終了",13,10
	defm "方向はテンキーの並び:  7 8 9 / 4 . 6 / 1 2 3  (8=上 2=下 4=左 6=右)",13,10
	defm "敵は同じ区画にいるあいだ攻撃してきます。シールドがマイナスになると負け。",13,10,0
mdays:	defm " 残り日数 ",0
menergy: defm " エネルギー ",0
mshield: defm " シールド ",0
mtorp:	defm " 魚雷 ",0
menemy:	defm " 敵艦の数 ",0
mbase:	defm " 基地の数 ",0
mquad:	defm " 区画 ",0
mcond:	defm " 状態 ",0
mdocked: defm "ドック中",0
malert:	defm "警戒!",0
mcalm:	defm "異常なし",0
mdir:	defm "方向 (1-9 テンキー配置) ? ",0
mdist:	defm "距離 (1-40) ? ",0
mph:	defm "撃つエネルギー (1-1000) ? ",0
mshq:	defm "シールドへ回すエネルギー ? ",0
mshok:	defm "シールドを設定しました。",13,10,0
mnoenergy: defm "エネルギーが足りません。",13,10,0
medge:	defm "宇宙の果てです。そこで止まります。",13,10,0
mblock:	defm "進路に何かあるため手前で止まりました。",13,10,0
mdock:	defm "ドックに入りました。エネルギーと魚雷を補給しました。",13,10,0
mnoone:	defm "この区画に敵はいません。",13,10,0
mnotorp: defm "魚雷がありません。",13,10,0
mhitE:	defm "フェーザーが敵艦 ",0
mEatk:	defm "敵艦 ",0
mdmg1:	defm " に",0
mdmg2:	defm " の損害。",13,10,0
mkill:	defm "  敵艦を撃破しました!",13,10,0
mtkill:	defm "魚雷が敵艦に命中!",13,10,0
mtmiss:	defm "魚雷は外れました。",13,10,0
mtstar:	defm "魚雷は星に吸い込まれました。",13,10,0
mtbase:	defm "魚雷が味方の基地に当たってしまった!",13,10,0
mprot:	defm "基地に守られて、敵は攻撃できません。",13,10,0
mlong:	defm "遠望(周りの区画。 敵 基地 星 の順に並べた数)",13,10,0
mlong2:	defm "(*** は宇宙の外)",13,10,0
mwin1:	defm "おめでとう! 敵艦をすべて倒しました。 残り日数 ",0
mwin2:	defm " 日。",13,10,0
mdead:	defm "シールドが破られ、艦は沈みました...",13,10,0
mnoeng:	defm "エネルギーが尽きました...",13,10,0
mtime:	defm "日数切れです。敵を倒しきれませんでした...",13,10,0
magain:	defm "もう一度? (y/n) ",0
endimg:
