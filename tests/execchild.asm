; execchild - E5h EXEC のテスト用の子。0100H から動く。2000H-DEFFH を 0CCH で埋める(親のメモリを壊したら親が気づく)。
;   コマンド行に I があれば IOCS(RST 18H)を呼ぶ。T があれば 62h(_TERM) で B=7 を返して終わる。なければ jp 0。
	org 0100h
	ld sp,0DF00h
	ld a,(0004h)		; カレントドライブは親から引き継ぐ
	add a,'A'
	ld (drv),a
	ld hl,2000h
	ld de,0DEFFh-2000h
fill:	ld (hl),0CCh
	inc hl
	dec de
	ld a,d
	or e
	jr nz,fill
	ld de,m_ok
	ld c,9
	call 5
	ld hl,0081h
	ld b,16
sc:	ld a,(hl)
	cp 'T'
	jr z,term
	cp 'I'
	jr z,iocs
	inc hl
	djnz sc
	jp 0
iocs:	ld a,'Z'		; IOCS(RST 18H)。IOCS無しのイメージではメッセージを出してウォームブート(=子の終了)になる
	rst 18h
	db 03h
	ld de,m_io
	ld c,9
	call 5
	jp 0
term:	ld c,62h
	ld b,7
	call 5
	jp 0
m_io:	defm "CHILD-IOCS-BACK",13,10,"$"
m_ok:	defm "CHILD-OK drive "
drv:	defm "?",13,10,"$"
