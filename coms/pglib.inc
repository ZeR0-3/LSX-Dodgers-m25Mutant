; pglib.inc - 物理ページ(8KB)との読み書き(窓の開閉を1つの呼び出しに閉じ込める)    MIT License
;   docs/app-memory-guide.md の 4 節の規則を守る。 BDOS で E2h(PAGEALLOC)したページ、または 07h-09h など予約したページに使う。
;
;   PGBANK  窓にするCPUのバンク(既定 3 = 6000H-7FFFH)。 include の前に equ で替えられる。
;           プログラムのコード・データ(pg_pg/pg_orig を含む)・スタック・転送元/転送先のバッファは、窓のバンクに置かないこと。
;   pgread   A=物理ページ  HL=ページ内オフセット(0-1FFFH)  DE=読み込み先  BC=バイト数
;   pgwrite  A=物理ページ  HL=ページ内オフセット(0-1FFFH)  DE=書き込み元  BC=バイト数
;            戻り: CF=0 成功 / CF=1 失敗(オフセット+バイト数が 2000H を越える。何もしない)。 BC=0 は成功。
;            割り込みは呼び出し前の状態(許可/禁止)に戻る。 呼んでいる間(LDIR の間だけ)は禁止。
;            壊すレジスタ: AF BC DE HL。 スタックは窓を開ける前に使うだけ。
	ifndef PGBANK
PGBANK	equ 3
	endif
PGWINH	equ PGBANK*20h		; 窓の先頭アドレスの上位バイト

pg_chk:				; HL=オフセット BC=長さ -> CF=1:範囲外。 HL,DE,BC保存
	push hl
	push de
	add hl,bc
	ld de,2001h
	or a
	sbc hl,de		; オフセット+長さ < 2001h なら CF=1(範囲内)
	pop de
	pop hl
	ccf			; CF=1:範囲外
	ret

pgread:
	ld (pg_pg),a
	call pg_chk
	ret c
	ld a,b
	or c
	ret z			; 長さ0 (CF=0)
	ld a,i
	push af			; P/V = 割り込み許可(IFF2)
	ld a,h
	add a,PGWINH
	ld h,a			; HL = 窓 + オフセット (読み出し元)
	di
	ld a,PGBANK
	out (0B4h),a
	in a,(0B5h)
	ld (pg_orig),a		; 窓にするバンクの元のページ
	ld a,PGBANK
	out (0B4h),a		; B5h は読んでもバンク選択が進むので選び直す
	ld a,(pg_pg)
	out (0B5h),a
	ldir
	jr pg_close

pgwrite:
	ld (pg_pg),a
	call pg_chk
	ret c
	ld a,b
	or c
	ret z
	ld a,i
	push af
	ex de,hl		; HL=書き込み元 DE=オフセット
	ld a,d
	add a,PGWINH
	ld d,a			; DE = 窓 + オフセット (書き込み先)
	di
	ld a,PGBANK
	out (0B4h),a
	in a,(0B5h)
	ld (pg_orig),a
	ld a,PGBANK
	out (0B4h),a
	ld a,(pg_pg)
	out (0B5h),a
	ldir
pg_close:			; 窓を閉じて、割り込み状態を戻す
	ld a,PGBANK
	out (0B4h),a
	ld a,(pg_orig)
	out (0B5h),a
	pop af
	jp po,pg_noei
	ei
pg_noei:
	or a			; CF=0
	ret

pg_pg:	defb 0
pg_orig: defb 0
