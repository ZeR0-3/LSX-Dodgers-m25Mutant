; RST 18H の振り分け表で未実装(0000)の関数を呼ぶと "No IOCS (IPL ROM)" を出してウォームブートで戻る(暴走しない)
; IOCT = FDC4h+19 = FDD7h。関数03hのエントリは +6 = FDDDh
	org 0100h
	ld hl,0
	ld (0FDDDh),hl		; IOCT[03h] = 0000 (未実装)
	rst 18h
	db 03h
	ld de,after
	ld c,9
	call 5
	jp 0
after:	defm "SHOULD-NOT-PRINT",13,10,"$"
