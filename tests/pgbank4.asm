; pgbank4 - バンク4(8000H-9FFFH)を窓にしたまま BDOS を呼んでも窓が保たれるか(UCPIN は COM ロード専用)。
; 割り込みは許可のまま。 コード・スタック・DMA・FCB は窓の外(0000H-7FFFH)。
	org 0100h
	ld sp,7F00h
	ld e,0FFh
	ld c,0E2h
	call 5
	or a
	jp nz,t_ng
	ld a,b
	ld (pg),a
	di
	ld a,4
	out (0B4h),a
	in a,(0B5h)
	ld (orig),a
	ld a,4
	out (0B4h),a
	ld a,(pg)
	out (0B5h),a
	ei
	ld hl,8000h
	ld de,2000h
t_f:	ld a,l
	xor h
	add a,3
	ld (hl),a
	inc hl
	dec de
	ld a,d
	or e
	jr nz,t_f
	; BDOS を何度か呼ぶ(出力、ドライブ選択、ディレクトリ検索、ファイルを開いて読む)
	ld de,m_mid
	ld c,9
	call 5
	ld de,5Ch
	ld c,11h		; search first (FCB=5Ch は引数のファイル名。無ければ空白のまま)
	call 5
	ld de,fcb
	ld c,0Fh		; open
	call 5
	ld de,0200h
	ld c,1Ah		; set DMA (窓の外)
	call 5
	ld de,fcb
	ld c,14h		; read sequential
	call 5
	ld c,0Bh		; console status
	call 5
	; 窓がまだ保たれているか(B5h を読む -> ページが pg か)、中身が残っているか
	di
	ld a,4
	out (0B4h),a
	in a,(0B5h)
	ld b,a
	ld a,(pg)
	cp b
	jr nz,t_bad
	ld hl,8000h
	ld de,2000h
t_v:	ld a,l
	xor h
	add a,3
	cp (hl)
	jr nz,t_bad
	inc hl
	dec de
	ld a,d
	or e
	jr nz,t_v
	ld a,4
	out (0B4h),a
	ld a,(orig)
	out (0B5h),a
	ei
	ld a,(pg)
	ld e,a
	ld c,0E3h
	call 5
	ld de,m_ok
	ld c,9
	call 5
	jp 0
t_bad:	ld a,4
	out (0B4h),a
	ld a,(orig)
	out (0B5h),a
	ei
t_ng:	ld de,m_ng
	ld c,9
	call 5
	jp 0
pg:	defb 0
orig:	defb 0
fcb:	defb 0,"PGBANK4 COM"
	defs 24
m_mid:	defm "mid",13,10,"$"
m_ok:	defm "BANK4-OK",13,10,"$"
m_ng:	defm "BANK4-NG",13,10,"$"
