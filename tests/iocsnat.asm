; RST 18H の振り分け表に自前ハンドラ(UI_CRT, アドレスはビルドのmapから差し込む)を入れて CRT1C を呼ぶ → 'Y' が出て戻る
	org 0100h
	ld hl,UICRT
	ld (0FDDDh),hl		; IOCT[03h] = 自前ハンドラ
	ld a,'Y'
	rst 18h
	db 03h
	ld de,ok
	ld c,9
	call 5
	jp 0
ok:	defm "NAT-OK",13,10,"$"
UICRT	equ 0
