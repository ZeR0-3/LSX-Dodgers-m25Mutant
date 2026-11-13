; ユーザの RST 18H (IOCS呼び出し)。CRT1C(関数03h)で 'Z' を出し、戻ってきてBDOSで IOC-OK を出せる(スタック・マップ・割り込みが戻る)。
; 40桁イメージでは画面1行目の先頭がIOCSの出力で "Z" になる。
	org 0100h
	ld a,'Z'
	rst 18h
	db 03h
	ld de,ok
	ld c,9
	call 5
	jp 0
ok:	defm "IOC-OK",13,10,"$"
