; 未初期化領域(EFh = RST 28H)の実行: ユーザマップでも TRAP38 が "$アドレス" を出して warm boot する。成功で TRAP-OK(+$アドレス表示)
	org 0100h
	ld a,0EFh
	ld (08000h),a
	ld (0C000h),a
	ld de,m1
	ld c,9
	call 5
	jp 08000h
m1:	defm "TRAP-GO",13,10,"$"
