; DATE.COM - 日付と時刻の表示・設定 (RP5C15)。 date | date YYYY-MM-DD | date HH:MM[:SS] | 両方   MIT License
;   表示は YYYY-MM-DD HH:MM:SS。設定は 2000-2099 年のみ。24時間表示の前提 (実機は未確認)
	org 0100h
	ld sp,0A000h
	call tailinit
	call sk
	or a
	jp z,da_sh
da_lp:	call sk
	or a
	jp z,da_fin
	call atoi
	ld a,(hl)
	cp '-'
	jr z,da_d
	cp ':'
	jp z,da_t
da_us:	ld de,da_mus
	ld c,9
	call 5
	jp 0
da_d:	ld (da_y),de
	inc hl
	call atoi
	ld a,e
	ld (da_m),a
	ld a,(hl)
	cp '-'
	jr nz,da_us
	inc hl
	call atoi
	ld a,e
	ld (da_dd),a
	ld a,1
	ld (da_sd),a
	jr da_lp
da_t:	ld a,e
	ld (da_h),a
	inc hl
	call atoi
	ld a,e
	ld (da_mi),a
	xor a
	ld (da_s),a
	ld a,(hl)
	cp ':'
	jr nz,da_t2
	inc hl
	call atoi
	ld a,e
	ld (da_s),a
da_t2:	ld a,1
	ld (da_st),a
	jr da_lp
da_fin:	ld a,(da_sd)
	or a
	jr z,da_f2
	ld hl,(da_y)
	ld de,2000
	or a
	sbc hl,de
	jp c,da_us
	ld de,100
	or a
	sbc hl,de
	jp nc,da_us
	add hl,de
	ld a,l
	ld (da_yy),a
	ld a,(da_m)
	or a
	jp z,da_us
	cp 13
	jp nc,da_us
	ld a,(da_dd)
	or a
	jp z,da_us
	cp 32
	jp nc,da_us
da_f2:	ld a,(da_st)
	or a
	jr z,da_f3
	ld a,(da_h)
	cp 24
	jp nc,da_us
	ld a,(da_mi)
	cp 60
	jp nc,da_us
	ld a,(da_s)
	cp 60
	jp nc,da_us
da_f3:	call rtcbk0
	ld a,(da_sd)
	or a
	jp z,da_f4
	ld a,(da_yy)
	ld b,11
	call wr2
	ld a,(da_m)
	ld b,9
	call wr2
	ld a,(da_dd)
	ld b,7
	call wr2
	call dow
	ld b,6
	ld c,0CCh
	out (c),a
da_f4:	ld a,(da_st)
	or a
	jp z,da_sh
	ld a,(da_h)
	ld b,4
	call wr2
	ld a,(da_mi)
	ld b,2
	call wr2
	ld a,(da_s)
	ld b,0
	call wr2
da_sh:	ld c,2Ah
	call 5
	ld (da_yv),hl
	ld a,d
	ld (da_m),a
	ld a,e
	ld (da_dd),a
	ld c,2Ch
	call 5
	ld a,h
	ld (da_h),a
	ld a,l
	ld (da_mi),a
	ld a,d
	ld (da_s),a
	call da_pyr
	ld a,'-'
	call wrb
	ld a,(da_m)
	call p2
	ld a,'-'
	call wrb
	ld a,(da_dd)
	call p2
	ld a,' '
	call wrb
	ld a,(da_h)
	call p2
	ld a,':'
	call wrb
	ld a,(da_mi)
	call p2
	ld a,':'
	call wrb
	ld a,(da_s)
	call p2
	call wcrlf
	call flush
	jp 0
da_pyr:	ld hl,(da_yv)
	ld de,0
	ld b,4
	call pnum
	ret
; A=0..99 を2桁で出力
p2:	ld b,0
p2a:	cp 10
	jr c,p2b
	sub 10
	inc b
	jr p2a
p2b:	push af
	ld a,b
	add a,'0'
	call wrb
	pop af
	add a,'0'
	jp wrb
; A=0..99 を B=下位桁レジスタ(+1が上位桁)へ書く
wr2:	ld d,0
wr2a:	cp 10
	jr c,wr2b
	sub 10
	inc d
	jr wr2a
wr2b:	ld c,0CCh
	out (c),a
	inc b
	ld a,d
	out (c),a
	ret
rtcbk0:	ld b,0Dh
	ld c,0CCh
	in a,(c)
	and 0Eh
	out (c),a
	ret
; 曜日 A (0=日) を da_yy,da_m,da_dd から
dow:	ld a,(da_yy)
	ld b,a
	ld a,(da_m)
	cp 3
	jr nc,dw1
	ld a,b
	or a
	jr nz,dw0
	ld b,0FFh		; 1999 (a=-1): a+a/4 = -2 = 5 (mod 7)
	ld c,5
	jr dw2
dw0:	dec b
dw1:	ld a,b
	rrca
	rrca
	and 3Fh
	add a,b
	ld c,a
dw2:	ld a,(da_m)
	ld e,a
	ld d,0
	ld hl,da_tt-1
	add hl,de
	ld a,(hl)
	add a,c
	ld hl,da_dd
	add a,(hl)
	ld b,7
dw3:	cp 7
	jr c,dw4
	sub 7
	jr dw3
dw4:	ret
da_tt:	defb 0,3,2,5,0,3,5,1,4,6,2,4
da_y:	defw 0
da_yv:	defw 0
da_yy:	defb 0
da_m:	defb 0
da_dd:	defb 0
da_h:	defb 0
da_mi:	defb 0
da_s:	defb 0
da_sd:	defb 0
da_st:	defb 0
da_mus:	defm "usage: date [YYYY-MM-DD] [HH:MM[:SS]]",13,10,"$"

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
